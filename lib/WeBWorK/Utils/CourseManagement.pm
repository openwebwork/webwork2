################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/CourseManagement.pm,v 1.39 2007/03/06 01:33:53 sh002i Exp $
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
use File::Spec;
use String::ShellQuote;
use WeBWorK::CourseEnvironment;
use WeBWorK::Debug;
use WeBWorK::Utils qw(runtime_use readDirectory);

our @EXPORT    = ();
our @EXPORT_OK = qw(
	listCourses
	listArchivedCourses
	addCourse
	renameCourse
	deleteCourse
	archiveCourse
	unarchiveCourse
	dbLayoutSQLSources
);

=head1 FUNCTIONS

=over

=cut

################################################################################

=item listCourses($ce)

Lists the courses defined. 

=cut

sub listCourses {
	my ($ce) = @_;
	my $coursesDir = $ce->{webworkDirs}->{courses};
	return grep { not (m/^\./ or m/^CVS$/) and -d "$coursesDir/$_" } readDirectory($coursesDir);
}

=item listArchivedCourses($ce)

Lists the courses which have been archived (end in .tar.gz). 

=cut

sub listArchivedCourses {
	my ($ce) = @_;
	my $coursesDir = $ce->{webworkDirs}->{courses};
	return grep { m/\.tar\.gz$/ } readDirectory($coursesDir);
}

################################################################################

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
 allowedRecipients    => $mail{allowedRecipients}
 feedbackRecipients   => $mail{feedbackRecipients}
 PRINT_FILE_NAMES_FOR => $pg{specialPGEnvironmentVars}->{PRINT_FILE_NAMES_FOR}

C<dbLayoutName> is required. C<allowedRecipients>, C<feedbackRecipients>, and
C<PRINT_FILE_NAMES_FOR> are references to arrays.

$dbOptions is a reference to a hash containing information required to create a
database for the course. Current database layouts do not require additional
information, so specify a reference to an empty hash. If $dbOptions is
undefined, addCourse() assumes that the database has already been created, and
skips that step in the course creation process.

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
	# DO NOT CHANGE THE DIE MESSAGE -- CourseAdmin checks it to determine whether
	# a course was partially created and should be deleted!
	# FIXME -- this is bad, and addCourse should deal with cleaning up partially
	# created courses itself
	if (-e $courseDir) {
		croak "$courseID: course exists";
	}
	
	# fail if the course ID contains invalid characters
	croak "Invalid characters in course ID: '$courseID' (valid characters are [-A-Za-z0-9_])"
		unless $courseID =~ m/^[-A-Za-z0-9_]*$/;
	
	# if we didn't get a database layout, use the default one
	if (not defined $dbLayoutName) {
		$dbLayoutName = $ce->{dbLayoutName};
	}
	
	# fail if the database layout is invalid
	if (not exists $ce->{dbLayouts}->{$dbLayoutName}) {
		croak "$dbLayoutName: not found in \%dbLayouts";
	}
	
	##### step 1: create course directory structure #####
	
	my %courseDirs = %{$ce->{courseDirs}};
	
	# deal with root directory first -- if we can't create it, we have to give up.
	
	exists $courseDirs{root} or croak "Can't create the course '$courseID' because no root directory is specified in the '%courseDirs' hash.";
	my $root = $courseDirs{root};
	delete $courseDirs{root};
	{
		# does the directory already exist?
		-e $root and croak "Can't create the course '$courseID' because the root directory '$root' already exists.";
		# is the parent directory writeable?
		my @rootElements = File::Spec->splitdir($root);
		pop @rootElements;
		my $rootParent = File::Spec->catdir(@rootElements);
		-w $rootParent or croak "Can't create the course '$courseID' because the courses directory '$rootParent' is not writeable.";
		# try to create it
		mkdir $root or croak "Can't create the course '$courseID' becasue the root directory '$root' could not be created: $!.";
	}
	
	# deal with the rest of the directories
	
	my @courseDirNames = sort { $courseDirs{$a} cmp $courseDirs{$b} } keys %courseDirs;
	foreach my $courseDirName (@courseDirNames) {
		my $courseDir = File::Spec->canonpath($courseDirs{$courseDirName});
		
		# does the directory already exist?
		if (-e $courseDir) {
			warn "Can't create $courseDirName directory '$courseDir', since it already exists. Using existing directory.\n";
			next;
		}
		
		# is the parent directory writeable?
		my @courseDirElements = File::Spec->splitdir($courseDir);
		pop @courseDirElements;
		my $courseDirParent = File::Spec->catdir(@courseDirElements);
		unless (-w $courseDirParent) {
			warn "Can't create $courseDirName directory '$courseDir', since the parent directory is not writeable. You will have to create this directory manually.\n";
			next;
		}
		
		# try to create it
		mkdir $courseDir or warn "Failed to create $courseDirName directory '$courseDir': $!. You will have to create this directory manually.\n";
	}
	
	##### step 2: create course database #####
	
	my $db = new WeBWorK::DB($ce->{dbLayouts}->{$dbLayoutName});
	my $create_db_result = $db->create_tables;
	die "$courseID: course database creation failed.\n" unless $create_db_result;
	
	##### step 3: populate course database #####
	
	if ($ce->{dbLayouts}{$dbLayoutName}{user}{params}{non_native}) {
		debug("not adding users to the course database: 'user' table is non-native.\n");
	} else {
		# see above
		#my $db = WeBWorK::DB->new($ce->{dbLayouts}->{$dbLayoutName});
		
		foreach my $userTriple (@users) {
			my ($User, $Password, $PermissionLevel) = @$userTriple;
			
			eval { $db->addUser($User)                       }; warn $@ if $@;
			eval { $db->addPassword($Password)               }; warn $@ if $@;
			eval { $db->addPermissionLevel($PermissionLevel) }; warn $@ if $@;
		}
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
			my $destDir = $ce->{courseDirs}{templates};
			my $cp_cmd = "2>&1 " . $ce->{externalPrograms}{cp} . " -R " . shell_quote($sourceDir) . "/* " . shell_quote($destDir);
			my $cp_out = readpipe $cp_cmd;
			if ($?) {
				my $exit = $? >> 8;
				my $signal = $? & 127;
				my $core = $? & 128;
				warn "Failed to copy templates from course '$sourceCourse' with command '$cp_cmd' (exit=$exit signal=$signal core=$core): $cp_out\n";
			}
		} else {
			warn "Failed to copy templates from course '$sourceCourse': templates directory '$sourceDir' does not exist.\n";
		}
	}
}

################################################################################

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
the course's new database and delete the course's old database. Current database
layouts do not require additional information, so specify a reference to an
empty hash.

The name of the course's directory is changed to $newCourseID.

If the course's database layout is C<sql_single> or C<sql_moodle>, new tables
are created in the current database, course data is copied from the old tables
to the new tables, and the old tables are deleted.

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
	my $mv_cmd = "2>&1"." ".$oldCE->{externalPrograms}{mv}." ".shell_quote($oldCourseDir)." ".shell_quote($newCourseDir);
	debug("moving course dir: $mv_cmd");
	my $mv_out = readpipe $mv_cmd;
	if ($?) {
		my $exit = $? >> 8;
		my $signal = $? & 127;
		my $core = $? & 128;
		die "Failed to move course directory with command '$mv_cmd' (exit=$exit signal=$signal core=$core): $mv_out\n";
	}
	
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
		my $oldDir = File::Spec->canonpath($oldCourseDirs{$courseDirName});
		my $newDir = File::Spec->canonpath($newCourseDirs{$courseDirName});
		if (-e $oldDir) {
			debug("oldDir $oldDir still exists. might move it...\n");
			
			# check for a few likely error conditions, since the mv error is not that helpful
			
			# is the source really a directory
			unless (-d $oldDir) {
				warn "$courseDirName: Can't move '$oldDir' to '$newDir', since the source is not a directory. You will have to move this directory manually.\n";
				next;
			}
			
			# does the destination already exist?
			# (this should only happen on extra-coursedir directories, since we make sure the root dir doesn't exist above.)
			if (-e $newDir) {
				warn "$courseDirName: Can't move '$oldDir' to '$newDir', since the target already exists. You will have to move this directory manually.\n";
				next;
			}
			
			# is oldDir's parent writeable
			my @oldDirElements = File::Spec->splitdir($oldDir);
			pop @oldDirElements;
			my $oldDirParent = File::Spec->catdir(@oldDirElements);
			unless (-w $oldDirParent) {
				warn "$courseDirName: Can't move '$oldDir' to '$newDir', since the source parent directory is not writeable. You will have to move this directory manually.\n";
				next;
			}
			
			# is newDir's parent writeable?
			my @newDirElements = File::Spec->splitdir($newDir);
			pop @newDirElements;
			my $newDirParent = File::Spec->catdir(@newDirElements);
			unless (-w $newDirParent) {
				warn "$courseDirName: Can't move '$oldDir' to '$newDir', since the destination parent directory is not writeable. You will have to move this directory manually.\n";
				next;
			}
			
			# try to move the directory
			debug("Going to move $oldDir to $newDir...\n");
			my $mv_cmd = "2>&1"." ".$oldCE->{externalPrograms}{mv}." ".shell_quote($oldDir)." ".shell_quote($newDir);
			my $mv_out = readpipe $mv_cmd;
			if ($?) {
				my $exit = $? >> 8;
				my $signal = $? & 127;
				my $core = $? & 128;
				warn "Failed to move directory with command '$mv_cmd' (exit=$exit signal=$signal core=$core): $mv_out\n";
			}
		} else {
			debug("oldDir $oldDir was already moved.\n");
		}
	}
	
	##### step 2: rename database #####
	
	my $oldDB = new WeBWorK::DB($oldCE->{dbLayouts}{$dbLayoutName});
	my $rename_db_result = $oldDB->rename_tables($newCE->{dbLayouts}{$dbLayoutName});
	die "$oldCourseID: course database renaming failed.\n" unless $rename_db_result;
}

################################################################################

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

$dbOptions is a reference to a hash containing information required to delete
the database for the course. Current database layouts do not require additional
information, so specify a reference to an empty hash. If $dbOptions is
undefined, addCourse() assumes that the database has already been deleted, and
skips that step in the course deletion process.

Deletes the course named $courseID. The course directory is removed.

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
	
	my %courseDirs = %{$ce->{courseDirs}};
	
	##### step 0: make sure course directory is deleteable #####
	
	# deal with root directory first -- if we won't be able to delete it, we have to give up.
	
	exists $courseDirs{root} or croak "Can't delete the course '$courseID' because no root directory is specified in the '%courseDirs' hash.";
	my $root = $courseDirs{root};
	if (-e $root) {
		# is the parent directory writeable?
		my @rootElements = File::Spec->splitdir($root);
		pop @rootElements;
		my $rootParent = File::Spec->catdir(@rootElements);
		-w $rootParent or croak "Can't delete the course '$courseID' because the courses directory '$rootParent' is not writeable.";
	} else {
		warn "Warning: the course root directory '$root' does not exist. Attempting to delete the course database and other course directories...\n";
	}
	
	##### step 1: delete course database (if necessary) #####
	
	my $dbLayoutName = $ce->{dbLayoutName};
	my $db = new WeBWorK::DB($ce->{dbLayouts}->{$dbLayoutName});
	my $create_db_result = $db->delete_tables;
	die "$courseID: course database deletion failed.\n" unless $create_db_result;
	
	##### step 2: delete course directory structure #####
	
	my @courseDirNames = sort { $courseDirs{$a} cmp $courseDirs{$b} } keys %courseDirs;
	foreach my $courseDirName (@courseDirNames) {
		my $courseDir = File::Spec->canonpath($courseDirs{$courseDirName});
		if (-e $courseDir) {
			debug("courseDir $courseDir still exists. might delete it...\n");
			
			# check for a few likely error conditions, since the mv error is not that helpful
			
			# is it really a directory
			unless (-d $courseDir) {
				warn "Can't delete $courseDirName directory '$courseDir', since is not a directory. If it is not wanted, you will have to delete it manually.\n";
				next;
			}
			
			# is the parent writeable
			my @courseDirElements = File::Spec->splitdir($courseDir);
			pop @courseDirElements;
			my $courseDirParent = File::Spec->catdir(@courseDirElements);
			unless (-w $courseDirParent) {
				warn "Can't delete $courseDirName directory '$courseDir', since its parent directory is not writeable. If it is not wanted, you will have to delete it manually.\n";
				next;
			}
			
			# try to delete the directory
			debug("Going to delete $courseDir...\n");
			rmtree($courseDir, 0, 1);
		} else {
			debug("courseDir $courseDir was already deleted.\n");
		}
	}
}

################################################################################

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

$dbOptions is a reference to a hash containing information required to create
the course's new database and delete the course's old database. (Currently,
no information is needed, so this should be an empty hash.)

If the course's database layout is C<sql_single>, the contents of 
the courses database tables are exported to text files using the sql database's
export facility.  Then the tables are deleted from the database.

If the course's database layout is something else, no database changes are made.

Any errors encountered while renaming the course are returned.

=cut

sub archiveCourse {
	my (%options) = @_;
	
	# archiveCourseHelper needs:
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
	
	if (not ref getHelperRef("archiveCourseHelper", $dbLayoutName)) {
		die "This database layout doesn't support course archiving. Sorry!\n"
	}
	
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
	my $tar_cmd = "2>&1"." ".$ce->{externalPrograms}{tar}
		. " -C " . shell_quote($coursesDir)
		. " -czf " . shell_quote($archivePath)
		. " " . shell_quote($courseID);
	debug("archiving course dir: $tar_cmd\n");
	my $tar_out = readpipe $tar_cmd;
	if ($?) {
		my $exit = $? >> 8;
		my $signal = $? & 127;
		my $core = $? & 128;
		die "Failed to archive course directory with command '$tar_cmd' (exit=$exit signal=$signal core=$core): $tar_out\n";
	}
}

################################################################################

sub unarchiveCourse {
	my (%options) = @_;
	
	# renameCourseHelper needs:
	#    $fromCourseID ($oldCourseID)
	#    $fromCE ($ce)
	#    $toCourseID ($newCourseID)
	#    $toCE (construct from $ce)
	#    $dbLayoutName ($ce->{dbLayoutName})
	#    %options ($dbOptions)
	
	my $newCourseID = $options{newCourseID};
	my $oldCourseID = $options{oldCourseID};
	my $archivePath = $options{archivePath};
	my $ce = $options{ce};
	my %dbOptions = defined $options{dbOptions} ? %{ $options{dbOptions} } : ();
	my $coursesDir  = $ce->{webworkDirs}->{courses};
	
	# Double check that the new course does not exist
	if (-e "$coursesDir/$newCourseID") {
		die "Cannot overwrite existing course $coursesDir/$newCourseID";
	}
	my $restoreCourseData = undef;
	##
	# Temporarily rename the old course if it exists  -- saving data
	##
	if (-e "$coursesDir/$oldCourseID") {
		my $tmpCourseID = "${oldCourseID}_tmp";
		
		debug("Moving $oldCourseID to $tmpCourseID");
		my  $tmpce = WeBWorK::CourseEnvironment->new(
			$ce->{webworkDirs}->{root},
			$ce->{webworkURLs}->{root},
			$ce->{pg}->{directories}->{root},
			$tmpCourseID,
		);
		$restoreCourseData = {
		                courseID    => $tmpCourseID,    # data for restoring from tmpCourse
		                ce          => $tmpce,
		                dbOptions   => undef,
		                newCourseID => $oldCourseID,
	    }; 
	    renameCourse(
	    	courseID    => $oldCourseID,
	    	ce          => WeBWorK::CourseEnvironment->new(
	    	                  $ce->{webworkDirs}->{root},
							  $ce->{webworkURLs}->{root},
							  $ce->{pg}->{directories}->{root},$oldCourseID,
						  ),
			dbOptions   => undef,
			newCourseID => $tmpCourseID,	
		);
	}
	##
	# Unarchive the old course 
	##
	
	
	my $courseID = $oldCourseID;
	###############################################################
	# RPC call to tar and gzip the courses directory
	###############################################################	
	my $tar_cmd = "2>&1"." ".$ce->{externalPrograms}{tar}
		. " -C " . shell_quote($coursesDir)
		. " -xzf " . shell_quote($archivePath);
	debug("unarchiving course dir: $tar_cmd\n");
	my $tar_out = readpipe $tar_cmd;
	if ($?) {
		my $exit = $? >> 8;
		my $signal = $? & 127;
		my $core = $? & 128;
		die "Failed to unarchive course directory with command '$tar_cmd' (exit=$exit signal=$signal core=$core): $tar_out\n";
	}
	###############################################################
	# End RPC call to tar and gzip the courses directory
	###############################################################	
	
	# read the global.conf and course.conf files for the newly created course
	debug( "Checking that course directory is at $coursesDir/$courseID: = ", -e "$coursesDir/$courseID");
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		$courseID,
	);
	my $courseDir   = "$coursesDir/$courseID";
	my $dataDir     = "$courseDir/DATA";

	#get the database layout out of the options hash
    my $dbLayoutName = $ce2->{dbLayoutName};
    	
 	if (not ref getHelperRef("unarchiveCourseHelper", $dbLayoutName)) {
 		die "This database layout doesn't support course archiving. Sorry!\n"
 	}
 	$dbOptions{unarchiveDatabasePath}   =  "$dataDir/${courseID}_mysql.database";
    # import database tables
 	my $unarchiveHelperResult = unarchiveCourseHelper($courseID, $ce, $dbLayoutName, %dbOptions);
 	die "$courseID: unable to import tables into database.\n" unless $unarchiveHelperResult;
	
	##
	# Change the unarchived course to the new course name if they are different
	##
	if ($courseID ne $newCourseID) {

		debug("rename $courseID to $newCourseID");
		my  $oldce = WeBWorK::CourseEnvironment->new(
			$ce->{webworkDirs}->{root},
			$ce->{webworkURLs}->{root},
			$ce->{pg}->{directories}->{root},
			$courseID,
		);
		renameCourse(
			courseID     => $courseID,
			ce           => $oldce,
			dbOptions    => undef,
			newCourseID  => $newCourseID,
		);
	}
	if (defined($restoreCourseData) ) { 		
	
	##
	# Rename the temporary old course back to old course
 	##
		debug("rename ".$restoreCourseData->{courseID}. " to ". $restoreCourseData->{newCourseID});
 		renameCourse(
 			%{$restoreCourseData}
 		);

	}
}

################################################################################

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
		
		if ($params{non_native}) {
			debug("$table: marked non-native, skipping\n");
			next;
		}
		
		my $source = $table{source};
		my $username = $params{username};
		my $password = $params{password};
		
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
# database helpers
################################################################################

=head1 DATABASE-LAYOUT SPECIFIC HELPER FUNCTIONS

These functions are used to perform database-layout specific operations.

The implementations in this class do nothing, but if an appropriate function
exists in a class with the name
WeBWorK::Utils::CourseManagement::I<$dbLayoutName>, it will be used instead.

=over

=item archiveCourseHelper($courseID, $ce, $dbLayoutName, %options)

Perform database-layout specific operations for archiving the data in a course.

=cut

sub archiveCourseHelper {
	my ($courseID, $ce, $dbLayoutName, %options) = @_;
	my $result = callHelperIfExists("archiveCourseHelper", $dbLayoutName, @_);
	return $result;
}

=item unarchiveCourseHelper($courseID, $ce, $dbLayoutName, %options)

Perform database-layout specific operations for unarchiving the data in a course
and placing it in the database.

=cut

sub unarchiveCourseHelper {
	my ($courseID, $ce, $dbLayoutName, %options) = @_;
	my $result = callHelperIfExists("unarchiveCourseHelper", $dbLayoutName, @_);
	return $result;
}

=back

=cut

################################################################################
# utilities
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
	
	my $helperRef = getHelperRef($helperName, $dbLayoutName);
	if (ref $helperRef) {
		return $helperRef->(@args);
	} else {
		return $helperRef;
	}
}

sub getHelperRef {
	my ($helperName, $dbLayoutName) = @_;
	
	my $result;
	
	my $package = __PACKAGE__ . "::$dbLayoutName";
	
	eval { runtime_use $package };
	if ($@) {
		if ($@ =~ /^Can't locate/) {
			debug("No database-layout specific library for layout '$dbLayoutName'.\n");
			$result = 1;
		} else {
			warn "Failed to load database-layout specific library: $@\n";
			$result = 0;
		}
	} else {
		my %syms = do { no strict 'refs'; %{$package."::"} };
		if (exists $syms{$helperName}) {
			$result = do { no strict 'refs'; \&{$package."::".$helperName} };
		} else {
			debug("No helper defined for operation '$helperName'.\n");
			$result = 1;
		}
	}
	
	#warn "getHelperRef = '$result'\n";
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
	
	print $fh <<'EOF';
#!perl
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
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
# By default, feeback is sent to all users who have permission to
# receive_feedback. If this list is non-empty, feedback is also sent to the
# addresses specified here.
# 
# * If you want to disable feedback altogether, leave this empty and set
#   $permissionLevels{submit_feeback} = undef;
#   This will cause the
#   feedback button to go away as well.
# 
# * If you want to send email ONLY to addresses in this list, set
#   $permissionLevels{receive_feedback} = undef; 
# 
# It's often useful to set this in the course.conf to change the behavior of
# feedback for a specific course.
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
