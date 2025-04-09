################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::Utils::CourseDBIntegrityCheck;

=head1 NAME

WeBWorK::Utils::CourseDBIntegrityCheck - Check that course database tables agree
with database schema.

=cut

use strict;
use warnings;

use WeBWorK::Utils::CourseManagement qw(listCourses);

# Developer note:  This file should not format messages in html.  Instead return an array of tuples.  Each tuple should
# contain the message components, and the last element of the tuple should be 0 or 1 to indicate failure or success
# respectively.  See the updateCourseTables and updateTableFields.

# Constants describing the comparison of two hashes.
use constant {
	ONLY_IN_A         => 0,
	ONLY_IN_B         => 1,
	DIFFER_IN_A_AND_B => 2,
	SAME_IN_A_AND_B   => 3
};

sub new {
	my ($invocant, $ce) = @_;
	return bless {
		dbh => DBI->connect(
			$ce->{database_dsn},
			$ce->{database_username},
			$ce->{database_password},
			{
				PrintError => 0,
				RaiseError => 1
			}
		),
		ce => $ce,
		db => WeBWorK::DB->new($ce)
		},
		ref $invocant || $invocant;
}

sub ce  { return shift->{ce} }
sub db  { return shift->{db} }
sub dbh { return shift->{dbh} }

sub DESTROY {
	my ($self) = @_;
	$self->unlock_database if $self->{db_locked};
	return;
}

=head2 checkCourseTables

Usage: C<< $CIchecker->checkCourseTables($courseName); >>

Checks the course tables in the mysql database and ensures that they are the
same as the ones specified by the databaseLayout

=cut

sub checkCourseTables {
	my ($self, $courseName) = @_;
	my $tables_ok = 1;
	my %dbStatus;

	# Fetch schema from course environment and search database for corresponding tables.
	my $db = $self->db;
	my $ce = $self->{ce};

	$self->lock_database;

	for my $table (sort keys %$db) {
		next if $db->{$table}{params}{non_native};

		# Exists means the table can be described
		if ($db->{$table}->tableExists) {
			my ($fields_ok, $fieldStatus) = $self->checkTableFields($courseName, $table);
			if ($fields_ok) {
				$dbStatus{$table} = [SAME_IN_A_AND_B];
			} else {
				$dbStatus{$table} = [ DIFFER_IN_A_AND_B, $fieldStatus ];
				$tables_ok = 0;
			}
		} else {
			$dbStatus{$table} = [ONLY_IN_A];
			$tables_ok = 0;
		}
	}

	# Fetch fetch corresponding tables in the database and search for corresponding schema entries.
	# _ represents any single character in the MySQL like statement so we escape it
	my $result     = $self->dbh->selectall_arrayref("show tables like '${courseName}\\_%'");
	my @tableNames = map {@$_} @$result;    # Drill down in the result to the table name level

	# Table names are of the form courseID_table (with an underscore). So if we have two courses mth101 and
	# mth101_fall09 when we check the tables for mth101 we will inadvertantly pick up the tables for mth101_fall09.
	# Thus we find all courseID's and exclude the extraneous tables.
	my @courseIDs = listCourses($ce);
	my @similarIDs;
	for my $courseID (@courseIDs) {
		next unless $courseID =~ /^${courseName}\_(.*)/;
		push(@similarIDs, $courseID);
	}

OUTER_LOOP:
	for my $table (sort @tableNames) {
		# Double check that we only have our course tables and similar ones.
		next unless $table =~ /^${courseName}\_(.*)/;

		for my $courseID (@similarIDs) {    # Exclude tables with similar but wrong names.
			next OUTER_LOOP if $table =~ /^${courseID}\_(.*)/;
		}

		my $schema_name = $1;
		unless (exists($db->{$schema_name})) {
			$dbStatus{$schema_name} = [ONLY_IN_B];
			$tables_ok = 0;
		}
	}

	$self->unlock_database;

	return ($tables_ok, \%dbStatus);
}

=head2 updateCourseTables

Usage: C<< $CIchecker-> updateCourseTables($courseName, $table_names); >>

Adds schema tables to the database that had been missing from the database.

=cut

sub updateCourseTables {
	my ($self, $courseName, $schema_table_names, $delete_table_names) = @_;
	my $db = $self->db;

	$self->lock_database;

	warn 'Pass reference to the array of table names to be updated.' unless ref($schema_table_names) eq 'ARRAY';

	my @messages;

	# Add tables
	for my $schema_table_name (sort @$schema_table_names) {
		next if $db->{$schema_table_name}{params}{non_native};
		my $schema_obj = $db->{$schema_table_name};
		my $database_table_name =
			exists $schema_obj->{params}{tableOverride} ? $schema_obj->{params}{tableOverride} : $schema_table_name;

		if ($schema_obj->can('create_table')) {
			$schema_obj->create_table;
			push(@messages, [ "Table $schema_table_name created as $database_table_name in database.", 1 ]);
		} else {
			push(@messages, [ "Skipping creation of '$schema_table_name' table: no create_table method", 0 ]);
		}
	}

	# Delete tables
	for my $delete_table_name (@$delete_table_names) {
		# There is no schema for these tables, so just prepend the course name that was stripped
		# from the table when the database was checked in checkCourseTables and try that.
		eval { $self->dbh->do("DROP TABLE `${courseName}_$delete_table_name`") };
		if ($@) {
			push(@messages, [ "Unable to delete table '$delete_table_name' from database: $@", 0 ]);
		} else {
			push(@messages, [ "Table '$delete_table_name' deleted from database.", 1 ]);
		}
	}

	$self->unlock_database;

	return @messages;
}

=head2 checkTableFields

Usage: C<< $CIchecker->checkTableFields($courseName, $table); >>

Checks the course tables in the mysql database and insures that they are the
same as the ones specified by the databaseLayout

=cut

sub checkTableFields {
	my ($self, $courseName, $table) = @_;
	my $fields_ok = 1;
	my %fieldStatus;

	# Fetch schema from course environment and search database for corresponding tables.
	my $db = $self->db;
	my $table_name =
		exists $db->{$table}{params}{tableOverride} ? $db->{$table}{params}{tableOverride} : $table;
	warn "$table_name is a non native table" if $db->{$table}{params}{non_native};
	my @schema_field_names = $db->{$table}{record}->FIELDS;
	my %schema_field_names = map { $_ => 1 } @schema_field_names;
	for my $field (@schema_field_names) {
		if ($db->{$table}->tableFieldExists($field)) {
			$fieldStatus{$field} = [SAME_IN_A_AND_B];
		} else {
			$fieldStatus{$field} = [ONLY_IN_A];
			$fields_ok = 0;
		}
	}

	# Fetch corresponding tables in the database and search for corresponding schema entries.
	# result is array:  Field | Type | Null | Key | Default | Extra
	my $result          = $self->dbh->selectall_arrayref("SHOW COLUMNS FROM `$table_name`");
	my %database_fields = map { ${$_}[0] => $_ } @$result;    # Construct a hash of field names to field data.

	for my $field_name (keys %database_fields) {
		unless (exists($schema_field_names{$field_name})) {
			$fields_ok = 0;
			$fieldStatus{$field_name} = [ONLY_IN_B];
			push(@{ $fieldStatus{$field_name} }, 1) if $database_fields{$field_name}[3];
		} else {
			my $data_type = $database_fields{$field_name}[1];
			$data_type =~ s/\(\d*\)$// if $data_type =~ /^(big|small)?int\(\d*\)$/;
			$data_type = uc($data_type);
			my $schema_data_type = uc($db->{$table}{record}->FIELD_DATA->{$field_name}{type} =~ s/ .*$//r);
			if ($data_type ne $schema_data_type) {
				$fieldStatus{$field_name} = [ DIFFER_IN_A_AND_B, $data_type, $schema_data_type ];
				$fields_ok = 0;
			}
		}
	}

	return ($fields_ok, \%fieldStatus);
}

=head2 updateTableFields

Usage: C<< $CIchecker->updateTableFields($courseName, $table); >>

Checks the fields in the table in the mysql database and insures that they are
the same as the ones specified by the databaseLayout

=cut

sub updateTableFields {
	my ($self, $courseName, $table, $delete_field_names, $fix_type_field_names) = @_;
	my @messages;

	# Fetch schema from course environment and search database for corresponding tables.
	my $db         = $self->db;
	my $table_name = exists $db->{$table}{params}{tableOverride} ? $db->{$table}{params}{tableOverride} : $table;
	warn "$table_name is a non native table" if $db->{$table}{params}{non_native};    # skip non-native tables
	my ($fields_ok, $fieldStatus) = $self->checkTableFields($courseName, $table);

	my $schema_obj = $db->{$table};

	# Add fields
	for my $field_name (keys %$fieldStatus) {
		if ($fieldStatus->{$field_name}[0] == ONLY_IN_A) {
			if ($schema_obj->can('add_column_field') && $schema_obj->add_column_field($field_name)) {
				push(@messages, [ "Added column '$field_name' to table '$table'", 1 ]);
			}
		}
	}

	# Rebuild indexes for the table if a previous key field column is going to be dropped.
	if ($schema_obj->can('rebuild_indexes')
		&& (grep { $fieldStatus->{$_} && $fieldStatus->{$_}[1] } @$delete_field_names))
	{
		my $result = eval { $schema_obj->rebuild_indexes };
		if ($@ || !$result) {
			push(@messages, [ "There was an error rebuilding indexes for table '$table'", 0 ]);
		} else {
			push(@messages, [ "Rebuilt indexes for table '$table'", 1 ]);
		}
	}

	# Drop fields if listed in $delete_field_names.
	for my $field_name (@$delete_field_names) {
		if ($fieldStatus->{$field_name} && $fieldStatus->{$field_name}[0] == ONLY_IN_B) {
			if ($schema_obj->can('drop_column_field') && $schema_obj->drop_column_field($field_name)) {
				push(@messages, [ "Dropped column '$field_name' from table '$table'", 1 ]);
			}
		}
	}

	# Change types of fields list in $fix_type_field_names to the type defined in the schema.
	for my $field_name (@$fix_type_field_names) {
		if ($fieldStatus->{$field_name} && $fieldStatus->{$field_name}[0] == DIFFER_IN_A_AND_B) {
			if ($schema_obj->can('change_column_field_type') && $schema_obj->change_column_field_type($field_name)) {
				push(@messages, [ "Changed type of column '$field_name' from table '$table'", 1 ]);
			} else {
				push(
					@messages,
					[
						"Failed to changed type of column '$field_name' from table '$table'. "
							. 'It is recommended that you delete this course and restore it from an archive.',
						0
					]
				);
			}
		}
	}

	return @messages;
}

# Database locking utilities

# Create a lock named 'webwork.dbugrade' that times out after 10 seconds.
sub lock_database {
	my $self = shift;
	my ($lock_status) = $self->dbh->selectrow_array("SELECT GET_LOCK('webwork.dbupgrade', 10)");
	if (!defined $lock_status) {
		die "Couldn't obtain lock because a database error occurred.\n";
	} elsif (!$lock_status) {
		die "Timed out while waiting for lock.\n";
	}
	$self->{db_locked} = 1;
	return;
}

# Release the lock named 'webwork.dbugrade'.
sub unlock_database {
	my $self = shift;
	my ($lock_status) = $self->dbh->selectrow_array("SELECT RELEASE_LOCK('webwork.dbupgrade')");
	if ($lock_status) {
		delete $self->{db_locked};
	} elsif (defined $lock_status) {
		warn "Couldn't release lock because the lock is not held by this thread.\n";
	} else {
		warn "Unable to release lock because a database error occurred.\n";
	}
	return;
}

1;
