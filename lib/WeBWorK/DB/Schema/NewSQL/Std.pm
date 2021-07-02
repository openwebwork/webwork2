################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Schema/NewSQL/Std.pm,v 1.22 2009/02/02 03:18:09 gage Exp $
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

package WeBWorK::DB::Schema::NewSQL::Std;
use base qw(WeBWorK::DB::Schema::NewSQL);

=head1 NAME

WeBWorK::DB::Schema::NewSQL - support SQL access to single tables.

=cut

use strict;
use warnings;
use Carp qw(croak);
use Iterator;
use Iterator::Util;
use File::Temp;
use String::ShellQuote;
use WeBWorK::DB::Utils::SQLAbstractIdentTrans;
use WeBWorK::Debug;

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item tableOverride

Alternate name for this table, to satisfy SQL naming requirements.

=item fieldOverride

A reference to a hash mapping field names to alternate names, to satisfy SQL
naming requirements.

=back

=cut

################################################################################
# constructor for SQL-specific behavior
################################################################################

sub new {    
	my $self = shift->SUPER::new(@_);
		# effectively calls WeBWorK::DB::Schema::new
		
	$self->sql_init;
	
	# provide a custom error handler
	$self->dbh->{HandleError} = \&handle_error;
	
	return $self;
}

sub sql_init {
	my $self = shift;
	
	# transformation functions for table and field names: these allow us to pass
	# the WeBWorK table/field names to SQL::Abstract::Classic, and have it translate them
	# to the SQL table/field names from tableOverride and fieldOverride.
	# (Without this, it would be hard to translate field names in WHERE
	# structures, since they're so convoluted.)
	my ($transform_table, $transform_field);
	if (defined $self->{params}{tableOverride}) {
		$transform_table = sub {
			my $label = shift;
			if ($label eq $self->{table}) {
				return $self->{params}{tableOverride};
			} else {
				#warn "can't transform unrecognized table name '$label'";
				return $label;
			}
		};
	}
	if (defined $self->{params}{fieldOverride}) {
		$transform_field = sub {
			my $label = shift;
			return defined $self->{params}{fieldOverride}{$label}
				? $self->{params}{fieldOverride}{$label}
				: $label;
		};
	}
	
	# add SQL statement generation object
	$self->{sql} = new WeBWorK::DB::Utils::SQLAbstractIdentTrans(
		quote_char => "`",
		name_sep => ".",
		transform_table => $transform_table,
		transform_field => $transform_field,
	);
}

################################################################################
# table creation
################################################################################

sub create_table {
	my ($self) = @_;
	my $stmt = $self->_create_table_stmt;
	$self->dbh->do($stmt);
	my @fields = $self->fields;
	my @rows = map { [ @$_{@fields} ] } $self->initial_records;
	return $self->insert_fields(\@fields, \@rows);
}

# this is mostly ripped off from wwdb_check, which is pretty much a per-table
# version of the table creation code in sql_single.pm. wwdb_check is going away
# after 2.3.x, and sql_single.pm is being replaced by this code.
sub _create_table_stmt {
	my ($self) = @_;
	
	my $sql_table_name = $self->sql_table_name;
	
    # insure correct syntax if $engine or $character_set is empty. Can't have ENGINE = in mysql stmt.
    my $engine = $self->engine;
    my $ENGINE_CLAUSE = ($engine)? "ENGINE=$engine" : "";
    my $character_set= $self->character_set;
    my $CHARACTER_SET_CLAUSE = ($character_set)? "DEFAULT CHARACTER SET = $character_set": "";

	my @field_list;
	
	# generate a column specification for each field
	foreach my $field ($self->fields) {
		my $sql_field_name = $self->sql_field_name($field);
		my $sql_field_type = $self->field_data->{$field}{type};
		
		push @field_list, "`$sql_field_name` $sql_field_type";
	}
	
	# generate an INDEX specification for each all possible sets of keyfields (i.e. 0+1+2, 1+2, 2)
	my @keyfields = $self->keyfields;
	foreach my $start (0 .. $#keyfields) {
		my @index_components;
		
		foreach my $component (@keyfields[$start .. $#keyfields]) {
			my $sql_field_name = $self->sql_field_name($component);
			my $sql_field_type = $self->field_data->{$component}{type};
			my $length_specifier = $sql_field_type =~ /(text|blob)/i ? "(100)" : "";
			if ($start == 0 and $length_specifier and $sql_field_type !~ /tiny/i) {
				warn "warning: UNIQUE KEY component $sql_field_name is a $sql_field_type, which can"
					. " hold values longer than 100 characters. However, in order to support utf8"
					. " we limit the key prefix for text/blob fields to 100. Therefore, uniqueness"
					.  "must occur within the first 100 characters of this field.";
			}
			push @index_components, "`$sql_field_name`$length_specifier";
		}
		
		my $index_string = join(", ", @index_components);
		my $index_type = $start == 0 ? "UNIQUE KEY" : "KEY";
		push @field_list, "$index_type ( $index_string )";
	}
	
	my $field_string = join(", ", @field_list);
	return "CREATE TABLE `$sql_table_name` ( $field_string ) $ENGINE_CLAUSE $CHARACTER_SET_CLAUSE";
}

################################################################################
# table renaming
################################################################################

sub rename_table {
	my ($self, $new_sql_table_name) = @_;
	
	my $stmt = $self->_rename_table_stmt($new_sql_table_name);
	return $self->dbh->do($stmt);
}

sub _rename_table_stmt {
	my ($self, $new_sql_table_name) = @_;
	
	my $sql_table_name = $self->sql_table_name;
	return "RENAME TABLE `$sql_table_name` TO `$new_sql_table_name`";
}

################################################################################
# table deletion
################################################################################

sub delete_table {
	my ($self) = @_;
	
	my $stmt = $self->_delete_table_stmt;
	return $self->dbh->do($stmt);
}

sub _delete_table_stmt {
	my ($self) = @_;
	
	my $sql_table_name = $self->sql_table_name;
	return "DROP TABLE IF EXISTS `$sql_table_name`";
}

################################################################################
# table dumping and restoring
################################################################################

# These are limited to mysql, since they use the mysql monitor and mysqldump.
# An exception will be thrown if the table in question doesn't use mysql.
# It also requires some additions to the params:
#     mysqldump_path - path to mysqldump(1)
#     mysql_path - path to mysql(1)

sub dump_table {
	my ($self, $dumpfile_path) = @_;
	
	my ($my_cnf, $database) = $self->_get_db_info;
	my $mysqldump = $self->{params}{mysqldump_path};
	
	# 2>&1 is specified first, which apparently makes stderr go to stdout
	# and stdout (not including stderr) go to the dumpfile. see bash(1).
	my $dump_cmd = "2>&1 " . shell_quote($mysqldump)
# 		. " --defaults-extra-file=" . shell_quote($my_cnf->filename)
		. " --defaults-file=" . shell_quote($my_cnf->filename) # work around for mysqldump bug
		. " " . shell_quote($database)
		. " " . shell_quote($self->sql_table_name)
		. " > " . shell_quote($dumpfile_path);
	my $dump_out = readpipe $dump_cmd;
	if ($?) {
		my $exit = $? >> 8;
		my $signal = $? & 127;
		my $core = $? & 128;
		warn "Warning: Failed to dump table '".$self->sql_table_name."' with command '$dump_cmd' (exit=$exit signal=$signal core=$core): $dump_out\n";
		warn "This can be expected if the course was created with an earlier version of WeBWorK.";
	}
	
	return 1;
}

sub restore_table {
	my ($self, $dumpfile_path) = @_;
	
	my ($my_cnf, $database) = $self->_get_db_info;
	my $mysql = $self->{params}{mysql_path};
	
	my $restore_cmd = "2>&1 " . shell_quote($mysql)
# 		. " --defaults-extra-file=" . shell_quote($my_cnf->filename)
		. " --defaults-file=" . shell_quote($my_cnf->filename) # work around for mysqldump bug
		. " " . shell_quote($database)
		. " < " . shell_quote($dumpfile_path);
	my $restore_out = readpipe $restore_cmd;
	if ($?) {
		my $exit = $? >> 8;
		my $signal = $? & 127;
		my $core = $? & 128;
		warn "Failed to restore table '".$self->sql_table_name."' with command '$restore_cmd' (exit=$exit signal=$signal core=$core): $restore_out\n";
	}
	
	return 1;
}

sub _get_db_info {
	my ($self) = @_;
	my $dsn = $self->{driver}{source};
	my $username = $self->{params}{username};
	my $password = $self->{params}{password};

	my %dsn;
	if ($dsn =~ m/^dbi:mariadb:/i || $dsn =~ m/^dbi:mysql:/i) {
		# Expect DBI:MariaDB:database=webwork;host=db;port=3306
		# or DBI:mysql:database=webwork;host=db;port=3306
		# The host and port are optional.
		my ($dbi, $dbtype, $dsn_opts) = split(':', $dsn);
		while (length($dsn_opts)) {
			if ($dsn_opts =~ /^([^=]*)=([^;]*);(.*)$/) {
				$dsn{$1} = $2;
				$dsn_opts = $3;
			} else {
				my ($var, $val) = $dsn_opts =~ /^([^=]*)=([^;]*)$/;
				$dsn{$var} = $val;
				$dsn_opts = '';
			}
		}
	} else {
		die "Can't call dump_table or restore_table on a table with a non-MySQL/MariaDB source";
	}

	die "no database specified in DSN!" unless defined $dsn{database};

	my $mysqldump = $self->{params}{mysqldump_path};
	# Conditionally add column-statistics=0 as MariaDB databases do not support it
	# see: https://serverfault.com/questions/912162/mysqldump-throws-unknown-table-column-statistics-in-information-schema-1109
	#      https://github.com/drush-ops/drush/issues/4410

	my $column_statistics_off = "";
	my $test_for_column_statistics = `$mysqldump --help | grep 'column-statistics'`;
	if ( $test_for_column_statistics ) {
		$column_statistics_off = "[mysqldump]\ncolumn-statistics=0\n";
		#warn "Setting in the temporary mysql config file for table dump/restore:\n$column_statistics_off\n\n";
	}

	# doing this securely is kind of a hassle...

	my $my_cnf = new File::Temp;
	$my_cnf->unlink_on_destroy(1);
	chmod 0600, $my_cnf or die "failed to chmod 0600 $my_cnf: $!"; # File::Temp objects stringify with ->filename
	print $my_cnf "[client]\n";

	# note: the quotes below are needed for special characters (and others) so they are passed to the database correctly. 

	print $my_cnf "user=\"$username\"\n" if defined $username and length($username) > 0;
	print $my_cnf "password=\"$password\"\n" if defined $password and length($password) > 0;
	print $my_cnf "host=\"$dsn{host}\"\n" if defined $dsn{host} and length($dsn{host}) > 0;
	print $my_cnf "port=\"$dsn{port}\"\n" if defined $dsn{port} and length($dsn{port}) > 0;
	print $my_cnf "$column_statistics_off" if $test_for_column_statistics;

	return ($my_cnf, $dsn{database});
}

####################################################
# checking Fields
####################################################

sub tableFieldExists {
	my $self = shift;
	my $field_name = shift;
	my $stmt = $self->_exists_field_stmt($field_name);
	my $result = $self->dbh->do($stmt);
	return  ($result eq "1") ? 1 : 0;    # failed result is 0E0
}

sub _exists_field_stmt {
	my $self = shift;	
	my $field_name=shift;
	my $sql_table_name = $self->sql_table_name;
	return "Describe `$sql_table_name` `$field_name`";
}
####################################################
# adding Field column
####################################################

sub add_column_field {
	my $self = shift;
	my $field_name = shift;
	my $stmt = $self->_add_column_field_stmt($field_name);
	#warn "database command $stmt";
	my $result = $self->dbh->do($stmt);
	#warn "result of add column is $result";
	#return  ($result eq "0E0") ? 0 : 1;    # failed result is 0E0
	return 1;   #FIXME  how to determine if database update was successful???
}

sub _add_column_field_stmt {
	my $self = shift;	
	my $field_name=shift;
	my $sql_table_name = $self->sql_table_name;
	my $sql_field_name = $self->sql_field_name($field_name);
	my $sql_field_type = $self->field_data->{$field_name}{type};		
	return "Alter table `$sql_table_name` add column `$sql_field_name` $sql_field_type";
}

####################################################
# deleting Field column
####################################################

sub drop_column_field {
	my $self = shift;
	my $field_name = shift;
	my $stmt = $self->_drop_column_field_stmt($field_name);
	#warn "database command $stmt";
	my $result = $self->dbh->do($stmt);
	#warn "result of add column is $result";
	#return  ($result eq "0E0") ? 0 : 1;    # failed result is 0E0
	return 1;   #FIXME  how to determine if database update was successful???
}

sub _drop_column_field_stmt {
	my $self = shift;	
	my $field_name=shift;
	my $sql_table_name = $self->sql_table_name;
	my $sql_field_name = $self->sql_field_name($field_name);		
	return "Alter table `$sql_table_name` drop column `$sql_field_name` ";
}
####################################################
# checking Tables
####################################################
sub tableExists {
	my $self = shift;
	my $stmt = $self->_exists_table_stmt;
	my $result = eval { $self->dbh->do($stmt); };
	( caught WeBWorK::DB::Ex::TableMissing ) ? 0:1;
}

sub _exists_table_stmt {
	my $self = shift;	
	my $sql_table_name = $self->sql_table_name;
	return "Describe `$sql_table_name` ";
}


################################################################################
# counting/existence
################################################################################

# returns the number of matching rows
sub count_where {
	my ($self, $where) = @_;
	$where = $self->conv_where($where);
	
	my ($stmt, @bind_vals) = $self->sql->select($self->table, "COUNT(*)", $where);
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3 -- see DBI docs
	$self->debug_stmt($sth, @bind_vals);
	$sth->execute(@bind_vals);
	my ($result) = $sth->fetchrow_array;
	$sth->finish;
	
	return $result;
}

# returns true iff there is at least one matching row
sub exists_where {
	my ($self, $where) = @_;
	return $self->count_where($where) > 0;
}

################################################################################
# lowlevel get
################################################################################

# returns a list of refs to arrays containing field values for each matching row
sub get_fields_where {
	my ($self, $fields, $where, $order) = @_;
	$fields ||= [$self->fields];
	
	my $sth = $self->_get_fields_where_prepex($fields, $where, $order);
	my @results = @{ $sth->fetchall_arrayref };
	$sth->finish;
	return @results;
}

# returns an Iterator that generates refs to arrays containg field values for each matching row
sub get_fields_where_i {
	my ($self, $fields, $where, $order) = @_;
	$fields ||= [$self->fields];
	
	my $sth = $self->_get_fields_where_prepex($fields, $where, $order);
	return new Iterator sub {
		my @row = $sth->fetchrow_array;
		if (@row) {
			return \@row;
		} else {
			$sth->finish; # let the server know we're done getting values
			undef $sth; # allow the statement handle to get garbage-collected
			Iterator::is_done();
		}
	};
}

# helper, returns a prepared statement handle
sub _get_fields_where_prepex {
	my ($self, $fields, $where, $order) = @_;
	$where = $self->conv_where($where);
	
	my ($stmt, @bind_vals) = $self->sql->select($self->table, $fields, $where, $order);
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	$self->debug_stmt($sth, @bind_vals);
	$sth->execute(@bind_vals);	
	return $sth;
}

################################################################################
# getting keyfields (a.k.a. listing)
################################################################################

# returns a list of refs to arrays containing keyfield values for each matching row
sub list_where {
	my ($self, $where, $order) = @_;
	return $self->get_fields_where([$self->keyfields], $where, $order);
}

# returns an iterator that generates refs to arrays containing keyfield values for each matching row
sub list_where_i {
	my ($self, $where, $order) = @_;
	return $self->get_fields_where_i([$self->keyfields], $where, $order);
}

################################################################################
# getting records
################################################################################

# returns a record objects for each matching row
sub get_records_where {
	my ($self, $where, $order) = @_;
	
	return map { $self->box($_) }
		$self->get_fields_where([$self->fields], $where, $order);
}

# returns an iterator that generates a record object for each matching row
sub get_records_where_i {
	my ($self, $where, $order) = @_;
	
	return imap { $self->box($_) }
		$self->get_fields_where_i([$self->fields], $where, $order);
}

################################################################################
# lowlevel insert
################################################################################

# returns the number of rows affected by inserting each row
sub insert_fields {
	my ($self, $fields, $rows) = @_;
	
	my ($sth, @order) = $self->_insert_fields_prep($fields);
	my @results;
	foreach my $row (@$rows) {
		my @bind_vals = @$row[@order];
		$self->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# returns the number of rows affected by inserting each row
sub insert_fields_i {
	my ($self, $fields, $rows_i) = @_;
	
	my ($sth, @order) = $self->_insert_fields_prep($fields);
	my @results;
	until ($rows_i->is_exhausted) {
		my @bind_vals = @{$rows_i->value}[@order];
		$self->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# helper, returns a prepared statement handle
sub _insert_fields_prep {
	my ($self, $fields) = @_;
	
	# we'll use dummy values to determine bind order
	my %values;
	@values{@$fields} = (0..@$fields-1);
	
	my ($stmt, @order) = $self->sql->insert($self->table, \%values);
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	return $sth, @order;
}

################################################################################
# inserting records
################################################################################

# returns the number of rows affected by inserting each record
sub insert_records {
	my ($self, $Records) = @_;
	return $self->insert_fields_i([$self->fields], imap { $self->unbox($_) } iarray $Records);
}

# returns the number of rows affected by inserting each record
sub insert_records_i {
	my ($self, $Records_i) = @_;
	return $self->insert_fields_i([$self->fields], imap { $self->unbox($_) } $Records_i);
}

################################################################################
# lowlevel update-where
################################################################################

# execute a single UPDATE by passing a ref to a hash mapping field names to new
# values and a reference to a hash specifying a where clause

# returns number of rows affected by update
sub update_where {
	my ($self, $fieldvals, $where) = @_;
	$where = $self->conv_where($where);
	
	my ($stmt, @bind_vals) = $self->sql->update($self->table, $fieldvals, $where);
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3 -- see DBI docs
	$self->debug_stmt($sth, @bind_vals);
	my $result = $sth->execute(@bind_vals);
	$sth->finish;
	
	return $result;
}

################################################################################
# lowlevel update-fields
################################################################################

# rather than allowing an unrestrained where clause here, we generate one based
# on the value of the keyfields in each row. in this respect, the behavior is
# more like "REPLACE INTO", except that a record with matching keys must already
# exist.

# returns the number of rows affected by updating each row
sub update_fields {
	my ($self, $fields, $rows) = @_;
	
	my ($sth, $val_order, $where_order) = $self->_update_fields_prep($fields);
	my @results;
	foreach my $row (@$rows) {
		my @bind_vals = @$row[@$val_order,@$where_order];
		$self->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# returns the number of rows affected by updating each row
sub update_fields_i {
	my ($self, $fields, $rows_i) = @_;
	
	my ($sth, $val_order, $where_order) = $self->_update_fields_prep($fields);
	my @results;
	until ($rows_i->is_exhausted) {
		my @bind_vals = @{$rows_i->value}[@$val_order,@$where_order];
		$self->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# helper, returns a prepared statement handle
sub _update_fields_prep {
	my ($self, $fields) = @_;
	
	# get hashes to pass to update() and where()
	# (dies if any keyfield is missing from @$fields)
	my ($values, $where) = $self->gen_update_hashes($fields);
	
	# do the where clause separately so we get a separate bind list (cute substr trick, huh?)
	my ($stmt, @val_order) = $self->sql->update($self->table, $values);
	(substr($stmt,length($stmt),0), my @where_order) = $self->sql->where($where);
	
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	return $sth, \@val_order, \@where_order;
}

################################################################################
# updating records
################################################################################

# returns the number of rows affected by updating each record
sub update_records {
	my ($self, $Records) = @_;
	return $self->update_fields_i([$self->fields], imap { $self->unbox($_) } iarray $Records);
}

# returns the number of rows affected by updating each record
sub update_records_i {
	my ($self, $Records_i) = @_;
	return $self->update_fields_i([$self->fields], imap { $self->unbox($_) } $Records_i);
}

################################################################################
# lowlevel delete-where
################################################################################

# execute a single DELETE by passing a ref to a hash specifying a where clause

# returns number of rows affected by delete
sub delete_where {
	my ($self, $where) = @_;
	$where = $self->conv_where($where);
	
	my ($stmt, @bind_vals) = $self->sql->delete($self->table, $where);
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3 -- see DBI docs
	$self->debug_stmt($sth, @bind_vals);
	my $result = $sth->execute(@bind_vals);
	$sth->finish;
	
	return $result;
}

################################################################################
# lowlevel delete-fields
################################################################################

# rather than allowing an unrestrained where clause here, we generate one based
# on the value of the keyfields in each row. this allows us to delete a bunch
# of records with a single statement handle, if what we have is a big list of
# record IDs (i.e. keyfields)

# an alternate approach would be to generate one big WHERE clause by ORing
# together the ANDed keyfields for each record to delete. This has the potential
# to accumulate a huge stmt string, but it's just one execute.

# this doesn't support NULL in keyfields, because the WHERE clause is
# constructed differently for NULL and non-NULL values. use delete_where.

# returns the number of rows affected by deleting each row
sub delete_fields {
	my ($self, $fields, $rows) = @_;
	
	my ($sth, @order) = $self->_delete_fields_prep($fields);
	my @results;
	foreach my $row (@$rows) {
		my @bind_vals = @$row[@order];
		$self->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# returns the number of rows affected by deleting each row
sub delete_fields_i {
	my ($self, $fields, $rows_i) = @_;
	
	my ($sth, @order) = $self->_delete_fields_prep($fields);
	
	my @results;
	until ($rows_i->is_exhausted) {
		my @bind_vals = @{$rows_i->value}[@order];
		$self->debug_stmt($sth, @bind_vals);
		push @results, $sth->execute(@bind_vals);
	}
	$sth->finish;
	return @results;
}

# helper, returns a prepared statement handle
sub _delete_fields_prep {
	my ($self, $fields) = @_;
	
	# get hashes to pass to update() and where()
	# (dies if any keyfield is missing from @$fields)
	my (undef, $where) = $self->gen_update_hashes($fields);
	
	# do the where clause separately so we get a separate bind list (cute substr trick, huh?)
	my ($stmt, @order) = $self->sql->delete($self->table, $where);
	
	my $sth = $self->dbh->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	return $sth, @order;
}

################################################################################
# deleting records
################################################################################

# we can pass whole records in here, even though all that's needed to delete is
# the keyfields. will be unboxed, and then _delete_fields_prep will ignore the
# non-keyfields when generating the WHERE clause template.

# returns the number of rows affected by deleting each record
sub delete_records {
	my ($self, $Records) = @_;
	return $self->delete_fields_i([$self->fields], imap { $self->unbox($_) } iarray $Records);
}

# returns the number of rows affected by deleting each record
sub delete_records_i {
	my ($self, $Records_i) = @_;
	return $self->delete_fields_i([$self->fields], imap { $self->unbox($_) } $Records_i);
}

################################################################################
# compatibility methods for old API
################################################################################

# oldapi
sub count {
	my ($self, @keyparts) = @_;
	return $self->count_where($self->keyparts_to_where(@keyparts));
}

# oldapi
sub list {
	my ($self, @keyparts) = @_;
	return $self->list_where($self->keyparts_to_where(@keyparts));
}

# oldapi
sub exists {
	my ($self, @keyparts) = @_;
	return $self->exists_where($self->keyparts_to_where(@keyparts));
}

# oldapi
sub get {
	my ($self, @keyparts) = @_;
	return ( $self->get_records_where($self->keyparts_to_where(@keyparts)) )[0];
}

# oldapi
sub gets {
	my ($self, @keypartsRefList) = @_;
	return map { $self->get_records_where($self->keyparts_to_where(@$_)) } @keypartsRefList;
}

# oldapi
sub add {
	my ($self, $Record) = @_;
	return ( $self->insert_records([$Record]) )[0];
}

# oldapi
sub put {
	my ($self, $Record) = @_;
	return ( $self->update_records([$Record]) )[0];
}

# oldapi
sub delete {
	my ($self, @keyparts) = @_;
	return $self->delete_where($self->keyparts_to_where(@keyparts));
}

################################################################################
# utility methods
################################################################################

sub sql {
	return shift->{sql};
}

# returns non-quoted SQL name of current table
sub sql_table_name {
	my ($self) = @_;
	return defined $self->{params}{tableOverride}
		? $self->{params}{tableOverride}
		: $self->table;
}

sub engine {
  my ($self) = @_;
  return defined $self->{engine}
    ? $self->{engine}
    : 'MYISAM';
}

sub character_set {
	my $self = shift;
	return (defined $self->{character_set} and $self->{character_set})
		? $self->{character_set}
		: 'latin1';
}
# returns non-quoted SQL name of given field
sub sql_field_name {
	my ($self, $field) = @_;
	return defined $self->{params}{fieldOverride}{$field}
		? $self->{params}{fieldOverride}{$field}
		: $field;
}

# returns fully quoted expression refering to the specified field
# if $include_table is true, the field name is prefixed with the table name
sub sql_field_expression {
	my ($self, $field, $table) = @_;
	
	# _quote will do native-to-SQL table/field name translation
	if (defined $table) {
		return $self->sql->_quote("$table.$field");
	} else {
		return $self->sql->_quote($field);
	}
}

# maps error numbers to exception classes for MySQL
our %MYSQL_ERROR_CODES = (
	1062 => 'WeBWorK::DB::Ex::RecordExists',
	1146 => 'WeBWorK::DB::Ex::TableMissing',
);

# turns MySQL error codes into exceptions -- WeBWorK::DB::Schema::Ex objects
# for known error types, and normal die STRING exceptions for unknown errors.
# This is one method you'd want to override if you were writing a subclass for
# another RDBMS.
sub handle_error {
	my ($errmsg, $handle, $returned) = @_;
	if (exists $MYSQL_ERROR_CODES{$handle->err}) {
		$MYSQL_ERROR_CODES{$handle->err}->throw;
	} else {

	    if ($errmsg =~ /Unknown column/) {
		warn("It looks like the database is missing a column.  You may need to upgrade your course tables.  If this is the admin course then you will need to upgrade the admin tables using the upgrade_admin_db.pl script.");
	    }
	    
	    die $errmsg ;
	}
}

sub DESTROY {
}
1;

