################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Utils/CourseManagement.pm,v 1.23 2005/08/04 22:45:34 sh002i Exp $
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

package WeBWorK::Utils::CourseManagement;
use base qw(Exporter);

=head1 NAME

WeBWorK::Utils::CourseManagement - create, rename, and delete courses.

=cut

use strict;
use warnings;
use Carp;
use DBI;
use File::Path qw(rmtree);
use WeBWorK::CourseEnvironment;
use WeBWorK::Debug;
use WeBWorK::Utils qw(runtime_use readDirectory);

our @EXPORT    = ();
our @EXPORT_OK = qw(
	listCourses
	addCourse
	renameCourse
	deleteCourse
	archiveCourse
	dbLayoutSQLSources
);

=head1 FUNCTIONS

=over

=item listCourses($ce)

Lists the courses defined. 

=cut

sub listCourses {
	my ($ce) = @_;
	my $coursesDir = $ce->{webworkDirs}->{courses};
	return grep { not (m/^\./ or m/^CVS$/) and -d "$coursesDir/$_" } readDirectory($coursesDir);
}

=item addCourse(%options)

%options must contain:

 courseID => $courseID,
 ce => $ce,
 courseOptions => $courseOptions, 
 dbOptions => $dbOptions,
 users => $users

%options may contain:

 templatesFrom => $templatesCourseID,

Create a new course named $courseID.

$ce is a WeBWorK::CourseEnvironment object that describes the new course's
environment.

$courseOptions is a reference to a hash containing the following options:

 dbLayoutName         => $dbLayoutName
 globalUserID         => $dbLayouts{gdbm}->{set}->{params}->{globalUserID}
                         $dbLayouts{gdbm}->{problem}->{params}->{globalUserID}
 allowedRecipients    => $mail{allowedRecipients}
 feedbackRecipients   => $mail{feedbackRecipients}
 PRINT_FILE_NAMES_FOR => $pg{specialPGEnvironmentVars}->{PRINT_FILE_NAMES_FOR}

C<dbLayoutName> is required. C<allowedRecipients>, C<feedbackRecipients>, and
C<PRINT_FILE_NAMES_FOR> are references to arrays.

$dbOptions is a reference to a hash containing information required to create a
database for the course.

 if dbLayout == "sql":
 
 	host     => host to connect to
 	port     => port to connect to
 	username => user to connect as (must have CREATE, DELETE, FILE, INSERT,
 	            SELECT, UPDATE privileges, WITH GRANT OPTION.)
 	password => password to supply
 	database => the name of the database to create
 	wwhost   => the host from which the webwork database users will be allowed
 	            to connect. (if host is set to localhost, this should be set to
 	            localhost too.)

These values must match the information given in the selected dbLayout. If
$dbOptions is undefined, addCourse() assumes that the database has already been
created, and skips that step in the course creation process.

$users is a list of arrayrefs, each containing a User, Password, and
PermissionLevel record for a single user:

 $users = [ $User, $Password, $PermissionLevel ]

These users are added to the course.

$templatesCourseID indicates the ID of a course from which the contents of the
templates directory will be copied to the new course.

=cut

sub addCourse {
	my (%options) = @_;
	
	my $courseID = $options{courseID};
	my $ce = $options{ce};
	my %courseOptions = %{ $options{courseOptions} };
	my %dbOptions = defined $options{dbOptions} ? %{ $options{dbOptions} } : ();
	my @users = exists $options{users} ? @{ $options{users} } : ();
	
	# get the database layout out of the options hash
	my $dbLayoutName = $courseOptions{dbLayoutName};
	
	# collect some data
	my $coursesDir = $ce->{webworkDirs}->{courses};
	my $courseDir = "$coursesDir/$courseID";
	
	# fail if the course already exists
	# IMPORTANT: this must be the first check! if any check other than this one
	# fails, CourseAdmin deletes the course!! Oh no!!!
	if (-e $courseDir) {
		croak "$courseID: course exists";
	}
	
	# FIXME: is hyphen ok? signs point to "no"
	croak "Invalid characters in course ID: '$courseID' (valid characters are [A-Za-z0-9_])"
		unless $courseID =~ m/^[\w-]*$/;
	
	# fail if the database layout is invalid
	if (defined $dbLayoutName and not exists $ce->{dbLayouts}->{$dbLayoutName}) {
		croak "$dbLayoutName: not found in \%dbLayouts";
	}
	
	# if we didn't get a database layout, use the default one
	if (not defined $dbLayoutName) {
		$dbLayoutName = $ce->{dbLayoutName};
	}
	
	##### step 1: create course directory structure #####
	
	my @subDirs = sort values %{ $ce->{courseDirs} };
	foreach my $subDir (@subDirs) {
		mkdir "$subDir"
			or die "Failed to create course directory $subDir: $!\n";
	}
	
	##### step 2: create course database (if necessary) #####
	
	my $createHelperResult = addCourseHelper($courseID, $ce, $dbLayoutName, %dbOptions);
	die "$courseID: course database creation failed.\n" unless $createHelperResult;
	
	##### step 3: populate course database #####
	
	my $db = WeBWorK::DB->new($ce->{dbLayouts}->{$dbLayoutName});
	
	# make sure we add the global user
	if (exists $courseOptions{globalUserID}) {
		unless (grep { $_->[0]->user_id eq $courseOptions{globalUserID} } @users) {
			push @users, [
				$db->newUser(user_id => $courseOptions{globalUserID}),
				$db->newPassword(user_id => $courseOptions{globalUserID}),
				$db->newPermissionLevel(user_id => $courseOptions{globalUserID}),
			];
		}
	}
	
	# apparently never used:
	#my @professors; # user ID of any user whose permission level == 10
	
	foreach my $userTriple (@users) {
		my ($User, $Password, $PermissionLevel) = @$userTriple;
		
		# apparently never used:
		#if (defined $PermissionLevel->permission and $PermissionLevel->permission == 10) {
		#	push @professors, $PermissionLevel->user_id;
		#}
		
		eval { $db->addUser($User)                       }; warn $@ if $@;
		eval { $db->addPassword($Password)               }; warn $@ if $@;
		eval { $db->addPermissionLevel($PermissionLevel) }; warn $@ if $@;
	}
	
	##### step 4: write course.conf file #####
	
	my $courseEnvFile = $ce->{courseFiles}->{environment};
	open my $fh, ">", $courseEnvFile
		or die "failed to open $courseEnvFile for writing.\n";
	writeCourseConf($fh, $ce, %courseOptions);
	close $fh;
	
	##### step 5: copy templates #####
	
	if (exists $options{templatesFrom}) {
		my $sourceCourse = $options{templatesFrom};
		my $sourceCE = new WeBWorK::CourseEnvironment(
			$ce->{webworkDirs}->{root},
			$ce->{webworkURLs}->{root},
			$ce->{pg}->{directories}->{root},
			$sourceCourse,
		);
		my $sourceDir = $sourceCE->{courseDirs}->{templates};
		
		if (-d $sourceDir) {
			my $destDir = $ce->{courseDirs}->{templates};
			my $errno = system "/bin/cp -R $sourceDir/* $destDir";
			if ($errno) {
				warn "Failed to copy templates from course '$sourceCourse' (errno=$errno): $!\n";
			}
		} else {
			warn "Failed to copy templates from course '$sourceCourse': templates directory '$sourceDir' does not exist.\n";
		}
	}
	
}

=item renameCourse(%options)

%options must contain:

 courseID => $courseID,
 ce => $ce,
 dbOptions => $dbOptions,
 newCourseID => $newCourseID,

Rename the course named $courseID to $newCourseID.

$ce is a WeBWorK::CourseEnvironment object that describes the existing course's
environment.

$dbOptions is a reference to a hash containing information required to create
the course's new database and delete the course's old database.

 if dbLayout == "sql":
 
 	host         => host to connect to
 	port         => port to connect to
 	username     => user to connect as (must have CREATE, DELETE, FILE, INSERT,
 	                SELECT, UPDATE privileges, WITH GRANT OPTION.)
 	password     => password to supply
 	old_database => the name of the database to delete
 	new_database => the name of the database to create
 	wwhost       => the host from which the webwork database users will be allowed
 	                to connect. (if host is set to localhost, this should be set to
 	                localhost too.)

The name of the course's directory is changed to $newCourseID.

If the course's database layout is C<sql_single>, new tables are created in the
current database, course data is copied from the old tables to the new tables,
and the old tables are deleted.

If the course's database layout is C<sql>, a new database is created, course
data is copied from the old database to the new database, and the old database
is deleted.

If the course's database layout is C<gdbm>, the DBM files are simply renamed on
disk.

If the course's database layout is something else, no database changes are made.

Any errors encountered while renaming the course are returned.

=cut

sub renameCourse {
	my (%options) = @_;
	
	# renameCourseHelper needs:
	#    $fromCourseID ($oldCourseID)
	#    $fromCE ($oldCE)
	#    $toCourseID ($newCourseID)
	#    $toCE (construct from $oldCE)
	#    $dbLayoutName ($oldCE->{dbLayoutName})
	#    %options ($dbOptions)
	
	my $oldCourseID = $options{courseID};
	my $oldCE = $options{ce};
	my %dbOptions = defined $options{dbOptions} ? %{ $options{dbOptions} } : ();
	my $newCourseID = $options{newCourseID};
	
	# get the database layout out of the options hash
	my $dbLayoutName = $oldCE->{dbLayoutName};
	
	die "I happen to know that renameCourse() will only succeed for sql_single courses. Bug sam to write support for gdbm and sql courses.\n"
		unless $dbLayoutName eq "sql_single";
	
	# collect some data
	my $coursesDir = $oldCE->{webworkDirs}->{courses};
	my $oldCourseDir = "$coursesDir/$oldCourseID";
	my $newCourseDir = "$coursesDir/$newCourseID";
	
	# fail if the target course already exists
	if (-e $newCourseDir) {
		croak "$newCourseID: course exists";
	}
	
	# fail if the source course does not exist
	unless (-e $oldCourseDir) {
		croak "$oldCourseID: course not found";
	}
	
	##### step 1: move course directory #####
	
	# move top-level course directory
	my $mvCmd = $oldCE->{externalPrograms}->{mv};
	debug("moving course dir: $mvCmd $oldCourseDir $newCourseDir\n");
	my $mvResult = system $mvCmd, $oldCourseDir, $newCourseDir;
	$mvResult and die "failed to move course directory with command: '$mvCmd $oldCourseDir $newCourseDir' (errno: $mvResult): $!\n";
	
	# get new course environment
	my $newCE = $oldCE->new(
		$oldCE->{webworkDirs}->{root},
		$oldCE->{webworkURLs}->{root},
		$oldCE->{pg}->{directories}->{root},
		$newCourseID,
	);
	
	# find the course dirs that still exist in their original locations
	# (i.e. are not subdirs of $courseDir)
	my %oldCourseDirs = %{ $oldCE->{courseDirs} };
	my %newCourseDirs = %{ $newCE->{courseDirs} };
	my @courseDirNames = sort { $oldCourseDirs{$a} cmp $oldCourseDirs{$b} } keys %oldCourseDirs;
	foreach my $courseDirName (@courseDirNames) {
		my $oldDir = $oldCourseDirs{$courseDirName};
		my $newDir = $newCourseDirs{$courseDirName};
		if (-e $oldDir) {
			debug("oldDir $oldDir still exists. might move it...\n");
			if (-e $newDir) {
				warn "Can't move '$oldDir' to '$newDir', since the target already exists";
			} else {
				debug("Going to move $oldDir to $newDir...\n");
				my $mvResult = system $mvCmd, $oldDir, $newDir;
				$mvResult and die "failed to move directory with command: '$mvCmd $oldDir $newDir' (errno: $mvResult): $!\n";
			}
		} else {
			debug("oldDir $oldDir was already moved.\n");
		}
	}
	
	##### step 2: create new database #####
	
	# munge DB options to move new_database => database
	my %createDBOptions = %dbOptions;
	if (exists $createDBOptions{new_database}) {
		$createDBOptions{database} = $createDBOptions{new_database};
		delete $createDBOptions{new_database};
	}
	
	my $createHelperResult = addCourseHelper($oldCourseID, $newCE, $dbLayoutName, %dbOptions);
	die "$oldCourseID: course database creation failed.\n" unless $createHelperResult;
	
	##### step 3: copy course data #####
	
	my $copyCourseDataResult = copyCourseDataHelper($oldCourseID, $oldCE, $newCourseID, $newCE, $dbLayoutName, %dbOptions);
	die "$oldCourseID: failed to copy course data from $oldCourseID to $newCourseID.\n" unless $copyCourseDataResult;
	
	##### step 4: delete old database #####
	
	# munge DB options to move old_database => database
	my %deleteDBOptions = %dbOptions;
	if (exists $deleteDBOptions{old_database}) {
		$deleteDBOptions{database} = $deleteDBOptions{old_database};
		delete $deleteDBOptions{old_database};
	}
	
	my $deleteHelperResult = deleteCourseHelper($oldCourseID, $oldCE, $dbLayoutName, %dbOptions);
	die "$oldCourseID: course database creation failed.\n" unless $deleteHelperResult;
}

=item deleteCourse(%options)

Options must contain:

 courseID => $courseID,
 ce => $ce,
 dbOptions => $dbOptions,

$ce is a WeBWorK::CourseEnvironment object that describes the course's
environment. It is your responsability to pass a course environment object that
describes the course to be deleted. Do not pass the course environment object
associated with the request, unless you are deleting the course you're currently
using.

$dbOptions is a reference to a hash containing information required to create a
database for the course.

 if dbLayout == "sql":
 
 	host     => host to connect to
 	port     => port to connect to
 	username => user to connect as (must have CREATE, DELETE, FILE, INSERT,
 	            SELECT, UPDATE privileges, WITH GRANT OPTION.)
 	password => password to supply
 	database => the name of the database to delete

Deletes the course named $courseID. The course directory is removed.

If the course's database layout is C<sql>, the course database is dropped.

If the course's database layout is something else, no databases are removed.

Any errors encountered while deleting the course are returned.

=cut

sub deleteCourse {
	my (%options) = @_;
	
	my $courseID = $options{courseID};
	my $ce = $options{ce};
	my %dbOptions = defined $options{dbOptions} ? %{ $options{dbOptions} } : ();
	
	# make sure the user isn't brain damaged
	die "the course environment supplied doesn't appear to describe the course $courseID. can't proceed."
		unless $ce->{courseName} eq $courseID;
	
	##### step 1: delete course database (if necessary) #####
	
	my $dbLayoutName = $ce->{dbLayoutName};
	my $deleteHelperResult = deleteCourseHelper($courseID, $ce, $dbLayoutName, %dbOptions);
	debug("deleteHelper returned '$deleteHelperResult'.");
	unless ($deleteHelperResult) {
		die "Failed to delete course database. Does the database exist? Were proper admin credentials given?\n";
	}
	
	##### step 2: delete course directory structure #####
	
	# my $courseDir = $ce->{courseDirs}->{root};
	# the tmp file might be in a different tree
	my @courseDirs = keys %{ $ce->{courseDirs} };
	foreach my $key (@courseDirs) {
	    my $courseDir = $ce->{courseDirs}->{$key};
		rmtree($courseDir, 0, 0) if -e $courseDir;
	}
}


=item archiveCourse(%options)

%options must contain:

 courseID    => $courseID,
 ce          => $ce,
 dbOptions   => $dbOptions,
 newCourseID => $newCourseID,

Archive the course named $courseID  in the $webworkDirs{courses} directory
as $webworkDirs{courses}/$courseID.tar.gz.  The data from the database is
stored in several files at $courseID/DATA/$table_name.txt before the course's directories
are tarred and gzipped.  The table names are $courseID_user, $courseID_set
and so forth.  Only files and directories stored directly in the course directory
are archived.  The contents of linked files is not archived although the symbolic links
themselves are saved.

$ce is a WeBWorK::CourseEnvironment object that describes the existing course's
environment.

# $dbOptions is a reference to a hash containing information required to create
# the course's new database and delete the course's old database.
# 
#  if dbLayout == "sql":
#  
#  	host         => host to connect to
#  	port         => port to connect to
#  	username     => user to connect as (must have CREATE, DELETE, FILE, INSERT,
#  	                SELECT, UPDATE privileges, WITH GRANT OPTION.)
#  	password     => password to supply
#  	old_database => the name of the database to delete
#  	new_database => the name of the database to create
#  	wwhost       => the host from which the webwork database users will be allowed
#  	                to connect. (if host is set to localhost, this should be set to
#  	                localhost too.)
# 
# The name of the course's directory is changed to $newCourseID.

If the course's database layout is C<sql_single>, the contents of 
the courses database tables are exported to text files using the sql database's
export facility.  Then the tables are deleted from the database.

# If the course's database layout is C<sql>, a new database is created, course
# data is copied from the old database to the new database, and the old database
# is deleted.
# 
# If the course's database layout is C<gdbm>, the DBM files are simply renamed on
# disk.

If the course's database layout is something else, no database changes are made.

Any errors encountered while renaming the course are returned.

=cut

sub archiveCourse {
	my (%options) = @_;
	
	# renameCourseHelper needs:
	#    $fromCourseID ($oldCourseID)
	#    $fromCE ($ce)
	#    $toCourseID ($newCourseID)
	#    $toCE (construct from $ce)
	#    $dbLayoutName ($ce->{dbLayoutName})
	#    %options ($dbOptions)
	
	my $courseID = $options{courseID};
	my $ce = $options{ce};
	my %dbOptions = defined $options{dbOptions} ? %{ $options{dbOptions} } : ();

	
	# get the database layout out of the options hash
	my $dbLayoutName = $ce->{dbLayoutName};
	
	die "I happen to know that renameCourse() will only succeed for sql_single courses. Bug Mike to write support for gdbm and sql courses.\n"
		unless $dbLayoutName eq "sql_single";
	
	# collect some data
	my $coursesDir  = $ce->{webworkDirs}->{courses};
	my $courseDir   = "$coursesDir/$courseID";
	my $dataDir     = "$courseDir/DATA";
	my $archivePath = "$coursesDir/$courseID.tar.gz";
	
	# create DATA directory if it does not exist.
	unless (-e $dataDir) {
		mkdir "$dataDir" or die "Failed to create course directory $dataDir";
	}
	# fail if the target file already exists
	if (-e $archivePath) {
		croak "The course $courseID has already been archived at $archivePath";
	}
	
	# fail if the source course does not exist
	unless (-e $courseDir) {
		croak "$courseID: course not found";
	}
	
	$dbOptions{archiveDatabasePath}   =  "$dataDir/${courseID}_mysql.database";
	##### step 1: export database contents ######
	# munge DB options to move new_database => database

	
	my $archiveHelperResult = archiveCourseHelper($courseID, $ce, $dbLayoutName, %dbOptions);
	die "$courseID: course database dump failed.\n" unless $archiveHelperResult;
		
	##### step 2: tar and gzip course directory #####
	
	# archive top-level course directory
	#FIXME (check) don't follow links
	my $tarCmd = $ce->{externalPrograms}->{tar};
	debug("archiving course dir: $tarCmd $archivePath $courseDir \n");
	my $tarStatement = "$tarCmd  -zcf   $archivePath  $courseDir";
	my $tarResult = system $tarStatement ;
	$tarResult and die "failed to tar course directory with command: '$tarStatement ' (errno: $tarResult): $!\n";
	
}


=item dbLayoutSQLSources($dbLayout)

Retrun a hash of database sources for the sql and sql_single database layouts.
Each element of the hash takes this form:

 dbi_source => {
     tables => [ 'table1', 'table2', ... ],
     username => 'username',
     password => 'password',
 }

In the common case, there will only be one source returned.

=cut

sub dbLayoutSQLSources {
	my ($dbLayout) = @_;
	
	my %dbLayout = %$dbLayout;
	my @tables = keys %dbLayout;
	
	my %sources;
	
	foreach my $table (@tables) {
		my %table = %{ $dbLayout{$table} };
		my %params = %{ $table{params} };
		
		my $source = $table{source};
		my $username = $params{usernameRW};
		my $password = $params{passwordRW};
		
		push @{$sources{$source}{tables}}, $table;
		
		if (defined $sources{$source}{username}) {
			if ($sources{$source}{username} ne $username) {
				warn "conflicting usernames for source '$source':",
					" '$sources{$source}{username}', '$username'\n";
			} else {
				# it's all good
			}
		} else {
			$sources{$source}{username} = $username;
		}
		
		if (defined $sources{$source}{password}) {
			if ($sources{$source}{password} ne $password) {
				warn "conflicting passwords for source '$source':",
					" '$sources{$source}{password}', '$password'\n";
			} else {
				# it's all good
			}
		} else {
			$sources{$source}{password} = $password;
		}
	}
	
	return %sources;
}

=back

=cut

################################################################################

=head1 DATABASE-LAYOUT SPECIFIC HELPER FUNCTIONS

The addCourseHelper(), copyCourseDataHelper(), and deleteCourseHelper()
functions are used to perform database-layout specific operations, such as
creating a database.

The implementations in this class do nothing, but if an appropriate function
exists in a class with the name
WeBWorK::Utils::CourseManagement::I<$dbLayoutName>, it will be used instead.

=over

=item addCourseHelper($courseID, $ce, $dbLayoutName, %options)

Perform database-layout specific operations for adding a course.

=cut

sub addCourseHelper {
	my ($courseID, $ce, $dbLayoutName, %options) = @_;
	my $result = callHelperIfExists("addCourseHelper", $dbLayoutName, @_);
	return $result;
}

=item archiveCourseHelper($courseID, $ce, $dbLayoutName, %options)

Perform database-layout specific operations for archiving the data in a course.

=cut

sub archiveCourseHelper {
	my ($courseID, $ce, $dbLayoutName, %options) = @_;
	my $result = callHelperIfExists("archiveCourseHelper", $dbLayoutName, @_);
	return $result;
}

=item copyCourseDataHelper($fromCourseID, $fromCE, $toCourseID, $toCE, $dbLayoutName, %options)

Perform database-layout specific operations for copying a course's data from one
database to another.

=cut

sub copyCourseDataHelper {
	my ($fromCourseID, $fromCE, $toCourseID, $toCE, $dbLayoutName, %options) = @_;
	return callHelperIfExists("copyCourseDataHelper", $dbLayoutName, @_);
}

=item deleteCourseHelper($courseID, $ce, $dbLayoutName, %options)

Perform database-layout specific operations for renaming a course.

=cut

sub deleteCourseHelper {
	my ($courseID, $ce, $dbLayoutName, %options) = @_;
	return callHelperIfExists("deleteCourseHelper", $dbLayoutName, @_);
}

=back

=cut

################################################################################

=head1 UTILITIES

These functions are used by this class's public functions and should not be
called directly.

=over

=item callHelperIfExists($helperName, $dbLayoutName, @args)

Call a database-specific helper function, if a database-layout specific helper
class exists and contains a function named "${helperName}Helper".

=cut

sub callHelperIfExists {
	my ($helperName, $dbLayoutName, @args) = @_;
	
	my $result;
	
	my $package = __PACKAGE__ . "::$dbLayoutName";
	
	eval { runtime_use $package };
	if ($@) {
		if ($@ =~ /^Can't locate/) {
			#warn "No database-layout specific library for layout '$dbLayoutName'.\n";
			$result = 1;
		} else {
			warn "Failed to load database-layout specific library: $@\n";
			$result = 0;
		}
	} else {
		my %syms = do { no strict 'refs'; %{$package."::"} };
		if (exists $syms{$helperName}) {
			my $func = do { no strict 'refs'; \&{$package."::".$helperName} };
			$result = $func->(@args);
		} else {
			#warn "No helper defined for operation '$helperName'.\n";
			$result = 1;
		}
	}
	
	return $result;
}

=item protectQString($string)

Protects the contents of a single-quoted Perl string.

=cut

sub protectQString {
	my ($string) = @_;
	$string =~ s/'/\'/g;
	return $string;
}

=item writeCourseConf($fh, $ce, %options)

Writes a course.conf file to $fh, a file handle, using defaults from the course
environment object $ce and overrides from %options. %options can contain any of
the pairs accepted in %courseOptions by addCourse(), above.

=cut

sub writeCourseConf {
	my ($fh, $ce, %options) = @_;
	
	# several options should be defined no matter what
	$options{dbLayoutName} = $ce->{dbLayoutName} unless defined $options{dbLayoutName};
	$options{globalUserID} = $ce->{dbLayouts}->{gdbm}->{set}->{params}->{globalUserID}
		unless defined $options{globalUserID};
	
	print $fh <<'EOF';
#!perl
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
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

# This file is used to override the global WeBWorK course environment for
# requests to this course. All package variables set in this file are added to
# the course environment. If you wish to set a variable here but omit it from
# the course environment,  use the "my" keyword. Commonly changed configuration
# options are noted below.

EOF
	
	print $fh <<'EOF';
# Database Layout (global value typically defined in global.conf)
# 
# Several database are defined in the file conf/database.conf and stored in the
# hash %dbLayouts.
# 
# The database layout is always set here, since one should be able to change the
# default value in global.conf without disrupting existing courses.
# 
# global.conf values:
EOF
	
	print $fh "# \t", '$dbLayoutName = \'', protectQString($ce->{dbLayoutName}), '\';', "\n";
	print $fh "# \t", '*dbLayout = $dbLayouts{$dbLayoutName};', "\n";
	print $fh "\n";
	
	if (defined $options{dbLayoutName}) {
		print $fh '$dbLayoutName = \'', protectQString($options{dbLayoutName}), '\';', "\n";
		print $fh '*dbLayout = $dbLayouts{$dbLayoutName};', "\n";
		print $fh "\n";
	} else {
		print $fh "\n\n\n";
	}
	
	print $fh <<'EOF';
# Global User ID (global value typically defined in database.conf)
# 
# The globalUserID parameter given for the set and problem tables denotes the ID
# of the user that the GlobalTableEmulator will use to store data for the set
# and problem tables.
# 
# If a course will be used under WeBWorK 1.x, this value should be overridden on
# a course-by-course basis to the ID of the professor who is most likely to be
# involved in creating new problem sets. Sets which have not been assigned will
# only be visible to this user when logging into WeBWorK 1.x.
# 
# The global user ID is always set here, since one should be able to change the
# default value in database.conf without disrupting existing courses.
# 
# global.conf values:
EOF
	
	print $fh "# \t", '$dbLayouts{gdbm}->{set}->{params}->{globalUserID} = \'',
			protectQString($ce->{dbLayouts}->{gdbm}->{set}->{params}->{globalUserID}), '\';', "\n";
	print $fh "# \t", '$dbLayouts{gdbm}->{problem}->{params}->{globalUserID} = \'',
			protectQString($ce->{dbLayouts}->{gdbm}->{problem}->{params}->{globalUserID}), '\';', "\n";
	print $fh "\n";
	
	if (defined $options{globalUserID} or defined $options{globalUserID}) {
		if (defined $options{globalUserID}) {
			print $fh '$dbLayouts{gdbm}->{set}->{params}->{globalUserID} = \'',
					protectQString($options{globalUserID}), '\';', "\n";
		}
		if (defined $options{globalUserID}) {
			print $fh '$dbLayouts{gdbm}->{problem}->{params}->{globalUserID} = \'',
					protectQString($options{globalUserID}), '\';', "\n";
		}
		print $fh "\n";
	} else {
		print $fh "\n\n\n";
	}
	
	print $fh <<'EOF';
# Allowed Mail Recipients (global value typically not defined)
# 
# Defines addresses to which the PG system is allowed to send mail. This should
# probably be set to the addresses of professors of this course. Sending mail
# from the PG system (i.e. questionaires, essay questions) will fail if this is
# not set.
# 
# global.conf values:
EOF
	
	if (defined $ce->{mail}->{allowedRecipients}) {
		print $fh "# \t", '$mail{allowedRecipients} = [',
				join(", ", map { "'" . protectQString($_) . "'" } @{ $ce->{mail}->{allowedRecipients} }), '];', "\n";
	} else {
		print $fh "# \t", '$mail{allowedRecipients} = [  ];', "\n";
	}
	print $fh "\n";
	
	if (defined $options{allowedRecipients}) {
		print $fh '$mail{allowedRecipients} = [',
				join(", ", map { "'" . protectQString($_) . "'" } @{ $options{allowedRecipients} }), '];', "\n";
		print $fh "\n";
	} else {
		print $fh "\n\n\n";
	}
	
	print $fh <<'EOF';
# Feedback Mail Recipients (global value typically not defined)
# 
# Defines recipients for feedback mail. If not defined, mail is sent to all
# instructors and TAs.
# 
# global.conf values:
EOF
	
	if (defined $ce->{mail}->{feedbackRecipients}) {
		print $fh "# \t", '$mail{feedbackRecipients} = [',
				join(", ", map { "'" . protectQString($_) . "'" } @{ $ce->{mail}->{feedbackRecipients} }), '];', "\n";
	} else {
		print $fh "# \t", '$mail{feedbackRecipients} = [  ];', "\n";
	}
	print $fh "\n";
	
	if (defined $options{feedbackRecipients}) {
		print $fh '$mail{feedbackRecipients} = [',
				join(", ", map { "'" . protectQString($_) . "'" } @{ $options{feedbackRecipients} }), '];', "\n";
		print $fh "\n";
	} else {
		print $fh "\n\n\n";
	}
	
	print $fh <<'EOF';
# Users for whom to label problems with the PG file name (global value typically "professor")
# 
# For users in this list, PG will display the source file name when rendering a problem.
# 
# global.conf values:
EOF
	
	if (defined $ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR}) {
		print $fh "# \t", '$pg{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} = [',
				join(", ", map { "'" . protectQString($_) . "'" } @{ $ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} }), '];', "\n";
	} else {
		print $fh "# \t", '$pg{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} = [  ];', "\n";
	}
	print $fh "\n";
	
	if (defined $options{PRINT_FILE_NAMES_FOR}) {
		print $fh '$pg{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} = [',
				join(", ", map { "'" . protectQString($_) . "'" } @{ $options{PRINT_FILE_NAMES_FOR} }), '];', "\n";
		print $fh "\n";
	} else {
		print $fh "\n\n\n";
	}
}

1;
