################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/DBUpgrade.pm,v 1.4 2007/08/13 22:59:59 sh002i Exp $
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

package WeBWorK::Utils::CourseIntegrityCheck;

=head1 NAME

WeBWorK::Utils::CourseIntegrityCheck - check that course  database tables agree with database schema and
that course directory structure is correct.

=cut

use strict;
use warnings;
use WeBWorK::Debug;
use WeBWorK::Utils::CourseManagement qw/listCourses/;

################################################################################

sub new {
	my $invocant = shift;
	my $class = ref $invocant || $invocant;
	my $self = bless {}, $class;
	$self->init(@_);
	return $self;
}

sub init {
	my ($self, %options) = @_;
	
	$self->{dbh} = DBI->connect(
		$options{ce}{database_dsn},
		$options{ce}{database_username},
		$options{ce}{database_password},
		{
			PrintError => 0,
			RaiseError => 1,
		},
	);
	
	$self->{verbose_sub} = $options{verbose_sub} || \&debug;
	$self->{confirm_sub} = $options{confirm_sub} || \&ask_permission_stdio;
	$self->{ce} = $options{ce};
    my $dbLayoutName = $self->{ce}->{dbLayoutName};
	$self->{db} =new WeBWorK::DB($self->{ce}->{dbLayouts}->{$dbLayoutName});
}

sub ce { return shift->{ce} }
sub db { return shift->{db} }
sub dbh { return shift->{dbh} }
sub verbose { my $sub = shift->{verbose_sub}; return &$sub(@_) }
sub confirm { my $sub = shift->{confirm_sub}; return &$sub(@_) }

sub DESTROY {
	my ($self) = @_;
	$self->unlock_database;
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}

################################################################################
=item checkCourseDirectories($courseName)

Checks the course files and directories to make sure they exist and have the correct permissions.

=cut



=item checkCourseTables($courseName, $dbLayoutName, $ce);

Checks the course tables in the mysql database and ensures that they are the 
same as the ones specified by the databaseLayout


=cut

sub checkCourseTables {
	my ($self, $courseName) = @_;
	my $str='';
	my %ok_tables = ();
	my %schema_only = ();
	my %database_only = ();
	my %update_fields = ();
	##########################################################
	# fetch schema from course environment and search database
	# for corresponding tables.
	##########################################################
	my $db = $self->db;
	$self->lock_database;
	foreach my $table (sort keys %$db) {
	    next if $db->{$table}{params}{non_native}; # skip non-native tables
	    my $table_name = (exists $db->{$table}->{params}->{tableOverride})? $db->{$table}->{params}->{tableOverride}:$table;
	    my $database_table_exists = ($db->{$table}->tableExists) ? 1:0;
	    if ($database_table_exists ) { # exists means the table can be described;
	       my( $fields_ok, $field_str,$fields_both, $fields_schema_only, $fields_database_only) = $self->checkTableFields($courseName, $table);
	       if ($fields_ok) {
	       	     $ok_tables{$table_name} = 1;
	       } else {
	       		$update_fields{$table_name}=[$fields_ok,$fields_both,$fields_schema_only,$fields_database_only]; 
	       }
	    } else {
	    	$schema_only{$table_name} = 1;
	    }
	}
	##########################################################
	# fetch fetch corresponding tables in the database and
	# search for corresponding schema entries.
	##########################################################

    my $dbh = $self->dbh;                            
	my $stmt = "show tables like '${courseName}%'";    # mysql request
	my $result = $dbh->selectall_arrayref($stmt) ;
	my @tableNames = map {@$_} @$result;             # drill down in the result to the table name level
	foreach my $table (sort @tableNames) {
	    next unless $table =~/^${courseName}\_(.*)/;  #double check that we only have our course tables
	    my $schema_name = $1;
		my $exists = exists($db->{$schema_name});
		$database_only{$table}=1 unless $exists;
	}
	my $tables_ok = (  scalar(%schema_only) || scalar(%database_only) ||scalar(%update_fields) ) ?0 :1; # count number of extraneous tables; no such tables makes $tables_ok true
	$self->unlock_database;
	return ($tables_ok,\%ok_tables, \%schema_only, \%database_only, \%update_fields); # table in both schema & database; found in schema only; found in database only
}

=item updateCourseTables($courseName, $dbLayoutName, $ce, $table_names);

Adds schema tables to the database that had been missing from the database.

=cut

sub updateCourseTables {
	my ($self, $courseName, $table_names) = @_;
	my $db = $self->db;
	$self->lock_database;
	warn "Programmers: Pass reference to the array of table names to be updated." unless ref($table_names)=~/ARRAY/;
	#warn "table names are ".join(" ", @$table_names);
	my $str='';
	foreach my $table (sort @$table_names) {    # remainder copied from db->create_table
		next if $table =~ /^_/; # skip non-table self fields (none yet)
		#warn "not a non-table self field";
		$table =~ /${courseName}_(.*)/;
		my $schema_table_name = $1;
		next if $db->{$schema_table_name}{params}{non_native}; # skip non-native tables
		#warn "not a non_native table";
		my $schema_obj = $db->{$schema_table_name};
		if ($schema_obj->can("create_table")) {
		   # warn "creating table $schema_obj";
			$schema_obj->create_table;
			$str .= "Table $table created".CGI::br();
		} else {
			warn "Skipping creation of '$table' table: no create_table method\n";
		}
	}
	$self->unlock_database;
	$str;
	
}

=cut



=item checkTableFields($courseName, $dbLayoutName, $ce, $table);

Checks the course tables in the mysql database and insures that they are the same as the ones specified by the databaseLayout


=cut


sub checkTableFields {
	my ($self,$courseName, $table) = @_;
	my $str='&nbsp;&nbsp;';
	my %both = ();
	my %schema_only = ();
	my %database_only = ();
	##########################################################
	# fetch schema from course environment and search database
	# for corresponding tables.
	##########################################################
	my $db = $self->db;
	my $table_name = (exists $db->{$table}->{params}->{tableOverride})? $db->{$table}->{params}->{tableOverride}:$table;
	warn "$table_name is a non native table" if $db->{$table}{params}{non_native}; # skip non-native tables
	my @schema_field_names =  $db->{$table}->{record}->FIELDS;
	my %schema_override_field_names=();
	foreach my $field (sort @schema_field_names) {
	    my $field_name  = $db->{$table}->{params}->{fieldOverride}->{$field} ||$field;
	    $schema_override_field_names{$field_name}=$field;	
	    my $database_field_exists = $db->{$table}->tableFieldExists($field_name);
	    if ($database_field_exists) {
	    	$str.="$field =>$field_name, "; 
	    	$both{$field}=1;
	    } else {
	    	$str.="$field =>MISSING, ";
	    	$schema_only{$field}=1;
	    }
	       
	}
	##########################################################
	# fetch fetch corresponding tables in the database and
	# search for corresponding schema entries.
	##########################################################
    
    my $dbh =$self->dbh;                        # grab any database handle
 	my $stmt = "SHOW COLUMNS FROM $table_name";    # mysql request
 	my $result = $dbh->selectall_arrayref($stmt) ;
 	my %database_field_names =  map {${$_}[0]=>[$_]} @$result;             # drill down in the result to the field name level
                                                           #  result is array:  Field      | Type     | Null | Key | Default | Extra 
 	foreach my $field_name (sort keys %database_field_names) {
 		my $exists = exists($schema_override_field_names{$field_name} );
 		$database_only{$table}=1 unless $exists;
 	}
 	my $fields_ok = not (  %schema_only || %database_only ); # count number of extraneous tables; no such tables makes $fields_ok true
 	return ($fields_ok, $str."<br/>",\%both, \%schema_only, \%database_only); # table in both schema & database; found in schema only; found in database only
}

##############################################################################
# Database utilities -- borrowed from DBUpgrade.pm ??use or modify??? --MEG
##############################################################################

sub lock_database {
	my $self =shift;
	my $dbh = $self->dbh; 
	my ($lock_status) = $dbh->selectrow_array("SELECT GET_LOCK('dbupgrade', 10)");
	if (not defined $lock_status) {
		die "Couldn't obtain lock because an error occurred.\n";
	}
	if ($lock_status) {
	} else {
		die "Timed out while waiting for lock.\n";
	}
}

sub unlock_database {
	my $self =shift;
	my $dbh = $self->dbh;
	my ($lock_status) = $dbh->selectrow_array("SELECT RELEASE_LOCK('dbupgrade')");
	if (not defined $lock_status) {
		# die "Couldn't release lock because the lock does not exist.\n";
	}elsif ($lock_status) {
	    return;
	} else {
		die "Couldn't release lock because the lock is not held by this thread.\n";
	}
}

##############################################################################

sub load_sql_table_list {
	my $self =shift;
	my $dbh = $self->dbh;
	my $sql_tables_ref = $dbh->selectcol_arrayref("SHOW TABLES");
	$self->{sql_tables} = {}; @{$self->{sql_tables}}{@$sql_tables_ref} = ();
}

sub register_sql_table {
	my $self =shift;
	my $table = shift;
	my $dbh = $self->dbh;
	$self->{sql_tables}{$table} = ();
}

sub unregister_sql_table {
	my $self =shift;
	my $table = shift;
	my $dbh = $self->dbh;
	delete $self->{sql_tables}{$table};
}

sub sql_table_exists {
	my $self =shift;
	my $table=shift;
	my $dbh = $self->dbh;
	return exists $self->{sql_tables}{$table};
}


################################################################################

sub ask_permission_stdio {
	my ($prompt, $default) = @_;
	
	$default = 1 if not defined $default;
	my $options = $default ? "[Y/n]" : "[y/N]";
	
	while (1) {
		print "$prompt $options ";
		my $resp = <STDIN>;
		chomp $resp;
		return $default if $resp eq "";
		return 1 if lc $resp eq "y";
		return 0 if lc $resp eq "n";
		$prompt = 'Please enter "y" or "n".';
	}
}


1;