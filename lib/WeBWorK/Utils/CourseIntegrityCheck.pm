################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/CourseIntegrityCheck.pm,v 1.8 2010/06/12 01:44:33 gage Exp $
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
use WeBWorK::PG::IO;

use constant {             # constants describing the comparison of two hashes.
           ONLY_IN_A=>0, 
           ONLY_IN_B=>1,
           DIFFER_IN_A_AND_B=>2, 
           SAME_IN_A_AND_B=>3
};
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

##################################################################



=item $CIchecker->checkCourseTables($courseName);

Checks the course tables in the mysql database and ensures that they are the 
same as the ones specified by the databaseLayout


=cut

sub checkCourseTables {
	my ($self, $courseName) = @_;
	my $str='';
    my $tables_ok = 1;
    my %dbStatus = ();
    #################################
	# fetch schema from course environment and search database
	# for corresponding tables.
	##########################################################
	my $db = $self->db;
	my $ce = $self->{ce};
	$self->lock_database;
	foreach my $table (sort keys %$db) {
	    next if $db->{$table}{params}{non_native}; # skip non-native tables
	    my $table_name = (exists $db->{$table}->{params}->{tableOverride})? $db->{$table}->{params}->{tableOverride}:$table;
	    my $database_table_exists = ($db->{$table}->tableExists) ? 1:0;
	    if ($database_table_exists ) { # exists means the table can be described;
	       my( $fields_ok, $fieldStatus) = $self->checkTableFields($courseName, $table);
	       if ($fields_ok) {
	       	     $dbStatus{$table} = [SAME_IN_A_AND_B()];
	       } else {
	       		$dbStatus{$table} = [DIFFER_IN_A_AND_B(),$fieldStatus];
	       		$tables_ok=0;
	       }
	    } else {
	    	$tables_ok=0;
	    	$dbStatus{$table}=[ONLY_IN_A(),];
	    }
	}
	##########################################################
	# fetch fetch corresponding tables in the database and
	# search for corresponding schema entries.
	##########################################################
 
	my $dbh = $self->dbh;
	my $tablePrefix = "${courseName}\\_";   # _ represents any single character in the MySQL like statement so we escape it
	my $stmt = "show tables like '${tablePrefix}%'";    # mysql request
	my $result = $dbh->selectall_arrayref($stmt) ;
	my @tableNames = map {@$_} @$result;             # drill down in the result to the table name level

#  Table names are of the form courseID_table (with an underscore). So if we have two courses mth101 and mth101_fall09
#  when we check the tables for mth101 we will inadvertantly pick up the tables for mth101_fall09.  Thus we find all 
#  courseID's and exclude the extraneous tables.

	my @courseIDs = listCourses($ce);
	my @similarIDs =();
	foreach my $courseID (@courseIDs) {
	    next unless $courseID =~/^${courseName}\_(.*)/;
	    push(@similarIDs, $courseID);
	}

	OUTER_LOOP:
	foreach my $table (sort @tableNames) {
	    next unless $table =~/^${courseName}\_(.*)/;  #double check that we only have our course tables and similar ones

	    foreach my $courseID (@similarIDs) {          #exclude tables with similar but wrong names
		next OUTER_LOOP if $table =~/^${courseID}\_(.*)/;
	    }

	    my $schema_name = $1;
		my $exists = exists($db->{$schema_name});
        $tables_ok = 0 unless exists($db->{$schema_name});
		$dbStatus{$schema_name} =[ONLY_IN_B] unless $exists;
	}
	$self->unlock_database;
	return ($tables_ok,\%dbStatus); # table in both schema & database; found in schema only; found in database only
}

=item $CIchecker-> updateCourseTables($courseName,  $table_names);

Adds schema tables to the database that had been missing from the database.

=cut

sub updateCourseTables {
	my ($self, $courseName, $schema_table_names) = @_;
	my $db = $self->db;
	$self->lock_database;
	warn "Programmers: Pass reference to the array of table names to be updated." unless ref($schema_table_names)=~/ARRAY/;
	# warn "table names are ".join(" ", @$schema_table_names);
	my $str='';
	foreach my $schema_table_name (sort @$schema_table_names) {    # remainder copied from db->create_table
		# next if $table =~ /^_/; # skip non-table self fields (none yet)
		# warn "not a non-table self field";
		next if $db->{$schema_table_name}{params}{non_native}; # skip non-native tables
		my $schema_obj = $db->{$schema_table_name};
		my $database_table_name = (exists $db->{$schema_table_name}->{params}->{tableOverride})? 
		                   $db->{$schema_table_name}->{params}->{tableOverride}:$schema_table_name;
		if ($schema_obj->can("create_table")) {
		   # warn "creating table $schema_obj";
			$schema_obj->create_table;
			$str .= "Table $schema_table_name created as $database_table_name in database.".CGI::br();
		} else {
			warn "Skipping creation of '$schema_table_name' table: no create_table method\n";
		}
	}
	$self->unlock_database;
	$str;
	
}

=cut



=item  $CIchecker->checkTableFields($courseName, $table);

Checks the course tables in the mysql database and insures that they are the same as the ones specified by the databaseLayout


=cut


sub checkTableFields {
	my ($self,$courseName, $table) = @_;
	my $fields_ok = 1;
	my %fieldStatus = ();
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
	    	$fieldStatus{$field} =[SAME_IN_A_AND_B]
	    } else {
            $fields_ok = 0;
	    	$fieldStatus{$field} =[ONLY_IN_A];
	    }
	       
	}
	##########################################################
	# fetch fetch corresponding tables in the database and
	# search for corresponding schema entries.
	##########################################################
    
    my $dbh =$self->dbh;                        # grab any database handle
 	my $stmt = "SHOW COLUMNS FROM `$table_name`";    # mysql request
 	my $result = $dbh->selectall_arrayref($stmt) ;
 	my %database_field_names =  map {${$_}[0]=>[$_]} @$result;             # drill down in the result to the field name level
                                                           #  result is array:  Field      | Type     | Null | Key | Default | Extra 
 	foreach my $field_name (sort keys %database_field_names) {
 	    if ($field_name eq "published") {  #hack to stop warning about residual "published" fields.
 	    	warn "Harmless: $table_name has extra column 'published' for older course. \n";
 	        next;
 	    }
 		my $exists = exists($schema_override_field_names{$field_name} );
 		$fields_ok=0 unless $exists;
 		$fieldStatus{$field_name} = [ONLY_IN_B] unless $exists;
 	}
 	

 	return ($fields_ok, \%fieldStatus); # table in both schema & database; found in schema only; found in database only
}


=item  $CIchecker->updateTableFields($courseName, $table);

Checks the fields in the table in the mysql database and insures that they are the same as the ones specified by the databaseLayout


=cut


sub updateTableFields {
	my ($self,$courseName, $table) = @_;
	my $msg='';
	##########################################################
	# fetch schema from course environment and search database
	# for corresponding tables.
	##########################################################
	my $db = $self->db;
	my $table_name = (exists $db->{$table}->{params}->{tableOverride})? $db->{$table}->{params}->{tableOverride}:$table;
	warn "$table_name is a non native table" if $db->{$table}{params}{non_native}; # skip non-native tables
    my ($fields_ok, $fieldStatus) = $self->checkTableFields($courseName,$table);
    # add fields
    foreach my $field_name (keys %$fieldStatus) {
     	next unless $fieldStatus->{$field_name}->[0] == ONLY_IN_A; 
     	my $schema_obj = $db->{$table};
     	if ( $schema_obj->can("add_column_field") ) {
     		$msg.= "Added column '$field_name' to table '$table'".CGI::br() if $schema_obj->add_column_field($field_name);
     	}
    }
	return $msg;
	
}





=item $CIchecker->checkCourseDirectories($courseName);

Checks the course directories to make sure they exist and have the correct
permissions.


=cut

sub checkCourseDirectories {
	my ($self) = @_;
	my $ce = $self->{ce};
	my @webworkDirectories = keys %{$ce->{webworkDirs}};
    my @courseDirectories = keys %{$ce->{courseDirs}};
    my $str = '';
    my @results;
    my $directories_ok =1;
    foreach my $dir (sort @courseDirectories) {
        my $path = $ce->{courseDirs}->{$dir};
        my $status = (-e $path) ? 
          ((-r $path)?'r':'-') . 
    	  ((-w _ )?'w':'-'   ) .
    	  ((-x _ )?'x':'-'   )    : "missing";
 
    	#all directories should be readable, writable and executable
    	my $style;
	    if ($status eq 'rwx') {
	    	$style = "color:green";
	    } else {
	    	$directories_ok = 0;
	    	$style = "color:red";
	    }
	    	
    	push @results, CGI::li( "$dir =>".CGI::span({style=>$style}," $path $status <br/>\n")  );
    }
    $str = CGI::start_ul(). join(" ",@results) .  CGI::end_ul();
    return ( $directories_ok, $str);
}

=item $CIchecker->updateCourseDirectories($courseName);

Creates some course directories automatically.


=cut

sub updateCourseDirectories {
	my $self = shift;
	my $ce = $self->{ce};
	my @webworkDirectories = keys %{$ce->{webworkDirs}};
    my @courseDirectories = keys %{$ce->{courseDirs}};
    my %updateable_directories = (html_temp=>1,mailmerge=>1,tmpEditFileDir=>1);  #FIXME this is hardwired for the time being.
    foreach my $dir (sort @courseDirectories) {
    	#HACK for upgrading the achievements directory
    	if ($dir eq "achievements") {
    		my $modelCourseAchievementsDir = $ce->{webworkDirs}{courses}."/modelCourse/templates/achievements";
    		my $modelCourseAchievementsHtmlDir = $ce->{webworkDirs}{courses}."/modelCourse/html/achievements";
    		my $courseAchievementsDir = $ce->{courseDirs}{achievements};
    		my $courseAchievementsHtmlDir = $ce->{courseDirs}{achievements_html};
    		my $courseTemplatesDir = $ce->{courseDirs}{templates};
    		my $courseHtmlDir = $ce->{courseDirs}{html};
    		unless  (-e $modelCourseAchievementsDir and -e $modelCourseAchievementsHtmlDir ) {
    			print CGI::p( {style=>"color:red"},"Your modelCourse in the 'courses' directory is out of date or missing.
    			 Please update it from webwork/webwork2/courses.dist directory before upgrading the other courses. Cannot find
    			 MathAchievements directory $modelCourseAchievementsDir nor MathAchievements picture directory $modelCourseAchievementsHtmlDir");
			} else {
				unless (-e $courseAchievementsDir and -e $courseAchievementsHtmlDir ) {
					print CGI::p( {style=>"color:green"},"we'll try to update the achievements 
					   directory for ".$ce->{courseDirs}{root});
					if (-e $courseAchievementsDir) {
						print CGI::p({style=>"color:green"}, "Achievements directory is already present");
					} else {
						system "cp -RPpi $modelCourseAchievementsDir $courseTemplatesDir ";
						print CGI::p({style=>"color:green"}, "Achievements directory created");
					}
					if (-e $courseAchievementsHtmlDir) {
						print CGI::p({style=>"color:green"}, "Achievements html directory is already present");
					} else {
						system "cp -RPpi $modelCourseAchievementsHtmlDir $courseHtmlDir ";
						print CGI::p({style=>"color:green"}, "Achievements html directory created");
					}
    			}
    				
			}
			#print "done with achievements for ",$ce->{courseDirs}{root},"<br/>";
     	} # end HACK for upgrading achivements
        next unless exists $updateable_directories{$dir};
        my $path = $ce->{courseDirs}->{$dir};
        unless ( -e $path) {   # if by some unlucky chance the tmpDirectory hasn't been created, create it.
			my $parentDirectory =  $path;
			$parentDirectory =~s|/$||;  # remove a trailing /
			$parentDirectory =~s|/[^/]*$||; # remove last node
			my ($perms, $groupID) = (stat $parentDirectory)[2,5];
			if (-w $parentDirectory) {
				WeBWorK::PG::IO::createDirectory($path, $perms, $groupID)
					or warn "Failed to create directory at $path.\n";
			} else {
				warn "Permissions error. Can't create directory at $path. Lack write permission on $parentDirectory.\n"
			}
		
		}
	}

    return ( );
}




##############################################################################
# Database utilities -- borrowed from DBUpgrade.pm ??use or modify??? --MEG
##############################################################################

sub lock_database {   # lock named 'webwork.dbugrade' times out after 10 seconds
	my $self =shift;
	my $dbh = $self->dbh; 
	my ($lock_status) = $dbh->selectrow_array("SELECT GET_LOCK('webwork.dbupgrade', 10)");
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
	my ($lock_status) = $dbh->selectrow_array("SELECT RELEASE_LOCK('webwork.dbupgrade')");
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


# 
# 
# =item checkCourseDirectories($courseName)
# 
# Checks the course files and directories to make sure they exist and have the correct permissions.
# 
# =cut
# 
# 
# 



1;
