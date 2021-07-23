################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Utils/CourseManagement.pm,v 1.48 2009/10/01 21:28:46 gage Exp $
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
use WeBWorK::Debug;
use File::Path qw(rmtree);
use File::Spec;
use String::ShellQuote;
use WeBWorK::CourseEnvironment;
use WeBWorK::Debug;
use WeBWorK::Utils qw(runtime_use readDirectory pretty_print_rh);
use UUID::Tiny qw(create_uuid_as_string);
#use WeBWorK::Utils::DBUpgrade;
use PGUtil; # for not_null() macro

our @EXPORT    = ();
our @EXPORT_OK = qw(
	listCourses
	listArchivedCourses
	addCourse
	renameCourse
	retitleCourse
	deleteCourse
	archiveCourse
	unarchiveCourse
	dbLayoutSQLSources
	initNonNativeTables

);

use constant {             # constants describing the comparison of two hashes.
           ONLY_IN_A=>0, 
           ONLY_IN_B=>1,
           DIFFER_IN_A_AND_B=>2, 
           SAME_IN_A_AND_B=>3
};
################################################################################


# 	checkCourseTables
# 	updateCourseTables
# 	checkCourseDirectories

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

	# We connect to the database and collect table names which end in "_user":
	my $dbh = DBI->connect(
		$ce->{database_dsn},
		$ce->{database_username},
		$ce->{database_password},
		{
			PrintError => 0,
			RaiseError => 1,
		},
        );

	my $dbname = ${ce}->{database_name};
	my $stmt_bad = 0;
	my $stmt = $dbh->prepare("show tables") or ( $stmt_bad = 1 );
	my %user_tables_seen; # Will also include problem_user, set_user, achievement_user, set_locations_user
	if ( ! $stmt_bad ) {
		$stmt->execute() or ( $stmt_bad = 1 );
		my @row;
		while (@row = $stmt->fetchrow_array) {
			if ( $row[0] =~  /_user$/ ) {
				$user_tables_seen{ $row[0] } = 1;
			}
		}
		$stmt->finish();
	}
	$dbh->disconnect();

	# Collect directories which may be course directories
	my @cdirs = grep { not (m/^\./ or m/^CVS$/) and -d "$coursesDir/$_" } readDirectory($coursesDir);
	if ( $stmt_bad ) {
		# Fall back to old method listing all directories.
		return @cdirs;
	} else {
		my @courses;
		foreach my $cname ( @cdirs ) {
			push(@courses,$cname) if $user_tables_seen{"${cname}_user"};
		}
		return @courses;
	}
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
 courseTitle => $courseTitle
 courseInstitution => $courseInstitution

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
	
	for my $key (keys(%options)){
		  	my $value = '####UNDEF###';
		  	$value = $options{$key} if (defined($options{$key}));
		  	debug("$key  : $value");
		  }


	my $courseID = $options{courseID};
	my $ce = $options{ce};
	my %courseOptions = %{ $options{courseOptions} };
	my %dbOptions = defined $options{dbOptions} ? %{ $options{dbOptions} } : ();
	my @users = exists $options{users} ? @{ $options{users} } : ();
	
	debug \@users;

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
	
	# fail if requested course ID is too long
	croak "Course ID cannot exceed " . $ce->{maxCourseIdLength} . " characters."
		if ( length($courseID) > $ce->{maxCourseIdLength} );

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

	if (exists $options{courseTitle}) {
	    $db->setSettingValue('courseTitle',$options{courseTitle});
	}
	if (exists $options{courseInstitution}) {
	    $db->setSettingValue('courseInstitution',$options{courseInstitution});
	}

	
	##### step 4: write course.conf file #####
	
	my $courseEnvFile = $ce->{courseFiles}->{environment};
	open my $fh, ">:utf8", $courseEnvFile
		or die "failed to open $courseEnvFile for writing.\n";
	writeCourseConf($fh, $ce, %courseOptions);
	close $fh;
	
	##### step 5: copy templates and html #####
	
	if (exists $options{templatesFrom}) {
		my $sourceCourse = $options{templatesFrom};
		my $sourceCE = new WeBWorK::CourseEnvironment({
			get_SeedCE($ce),
			courseName => $sourceCourse,        # override courseName
		});
		my $sourceDir = $sourceCE->{courseDirs}->{templates};
		## copy templates ##
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
		## copy html ##
		## this copies the html/tmp directory as well which is not optimal
		$sourceDir = $sourceCE->{courseDirs}->{html};
		if (-d $sourceDir) {
			my $destDir = $ce->{courseDirs}{html};
			my $cp_cmd = "2>&1 " . $ce->{externalPrograms}{cp} . " -R " . shell_quote($sourceDir) . "/* " . shell_quote($destDir);
			my $cp_out = readpipe $cp_cmd;
			if ($?) {
				my $exit = $? >> 8;
				my $signal = $? & 127;
				my $core = $? & 128;
				warn "Failed to copy html from course '$sourceCourse' with command '$cp_cmd' (exit=$exit signal=$signal core=$core): $cp_out\n";
			}
		} else {
			warn "Failed to copy html from course '$sourceCourse': html directory '$sourceDir' does not exist.\n";
		}
		## copy config files ##
		#  this copies the simple.conf file if desired
		if (exists $options{copySimpleConfig}) {
			my $sourceFile = $sourceCE->{courseFiles}->{simpleConfig};
			if (-e $sourceFile) {
				my $destFile = $ce->{courseFiles}{simpleConfig};
				my $cp_cmd = join(" ", ("2>&1", $ce->{externalPrograms}{cp}, shell_quote($sourceFile), shell_quote($destFile)));
				my $cp_out = readpipe $cp_cmd;
				if ($?) {
					my $exit = $? >> 8;
					my $signal = $? & 127;
					my $core = $? & 128;
					warn "Failed to copy simple.conf from course '$sourceCourse' with command '$cp_cmd' (exit=$exit signal=$signal core=$core): $cp_out\n";
				}
			}
		}

	}
	######## set 6: copy html/achievements contents ##############
}

################################################################################

=item renameCourse(%options)

%options must contain:

 courseID => $courseID,
 ce => $ce,
 dbOptions => $dbOptions,
 newCourseID => $newCourseID,

%options may also contain:

 skipDBRename => $skipDBRename,
 courseTitle => $courseTitle
 courseInstitution => $courseInstitution


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

If $skipDBRename is true, no database changes are made. This is useful if a
course is being unarchived and no database was found, or for renaming the
modelCourse.

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
	my $skipDBRename = $options{skipDBRename} || 0;
	
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

	# fail if the target courseID is too long
	croak "New course ID cannot exceed " . $oldCE->{maxCourseIdLength} . " characters."
		if ( length($newCourseID) > $oldCE->{maxCourseIdLength} );
	
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
	
	unless ($skipDBRename) {
		my $oldDB = new WeBWorK::DB($oldCE->{dbLayouts}{$dbLayoutName});
		
		my $rename_db_result = $oldDB->rename_tables($newCE->{dbLayouts}{$dbLayoutName});
		die "$oldCourseID: course database renaming failed.\n" unless $rename_db_result;
		#update title and institution
		my $newDB = new WeBWorK::DB($newCE->{dbLayouts}{$dbLayoutName});
		eval {
			if (exists( $options{courseTitle}) and $options{courseTitle}) {
				$newDB->setSettingValue('courseTitle',$options{courseTitle});
			}
			if (exists( $options{courseInstitution}) and $options{courseInstitution}) {
				$newDB->setSettingValue('courseInstitution',$options{courseInstitution});
			}
		};  warn "Problems from resetting course title and institution = $@" if $@;
	}
}

################################################################################
=item retitleCourse

	Simply changes the title and institution of the course. 

Options must contain:

 courseID => $courseID,
 ce => $ce,
 dbOptions => $dbOptions,
 
 
Options may contain
 newCourseTitle => $courseTitle,
 newCourseInstitution => $courseInstitution,


=cut 

sub retitleCourse {
	my %options = @_;
	# renameCourseHelper needs:
	#    $courseID ($oldCourseID)
	#    $ce ($oldCE)
	#    $dbLayoutName ($ce->{dbLayoutName})
	#    %options ($dbOptions)
	#    courseTitle
	#    courseInstitution
	my $courseID = $options{courseID};
	my $ce       = $options{ce};
	my %dbOptions = defined $options{dbOptions} ? %{ $options{dbOptions} } : ();

	# get the database layout out of the options hash
	my $dbLayoutName = $ce->{dbLayoutName};
	my $db = new WeBWorK::DB($ce->{dbLayouts}{$dbLayoutName});
		eval {
			if (exists( $options{courseTitle}) and $options{courseTitle}) {
				$db->setSettingValue('courseTitle',$options{courseTitle});
			}
			if (exists( $options{courseInstitution}) and $options{courseInstitution}) {
				$db->setSettingValue('courseInstitution',$options{courseInstitution});
			}
		};  warn "Problems from resetting course title and institution = $@" if $@;

	


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

 courseID  => $courseID,
 ce        => $ce,

Creates a gzipped tar archive (.tar.gz) of the course $courseID in the WeBWorK
courses directory. Before archiving, the course database is dumped into a
subdirectory of the course's DATA directory.

Only files and directories stored directly in the course directory are archived.
The contents of linked files is not archived although the symbolic links
themselves are saved.

$courseID is the name of the course to archive.

$ce is a WeBWorK::CourseEnvironment object that describes the course's
environment. (This is used to access the course database and get path
information.)

If an error occurs, an exception is thrown.

=cut

sub archiveCourse {
	my (%options) = @_;
	my $courseID = $options{courseID};
	my $ce = $options{ce};
	
	# make sure the user isn't brain damaged
	croak "The course environment supplied doesn't appear to match the course $courseID. Can't proceed"
		unless $ce->{courseName} eq $courseID;
	
	# grab some values we'll need
	my $course_dir = $ce->{courseDirs}{root};
	
	# tmp_archive_path is used as the target of the tar.gz operation
	# After this is done the final tar.gz file is moved either to the course directory
	# or the course/myCourse/templates   directory (when saving individual courses)
	# this prevents us from tarring a directory to which we have just added a file
	# see bug #2022 -- for error messages on some operating systems
	my $uuidStub = create_uuid_as_string();
	my $tmp_archive_path = $ce->{webworkDirs}{courses} . "/ ${uuidStub}_$courseID.tar.gz";
	my $data_dir = $ce->{courseDirs}{DATA};
	my $dump_dir = "$data_dir/mysqldump";
	my $archive_path;
	if ( PGUtil::not_null( $options{archive_path} ) ) {
		$archive_path = $options{archive_path};
	} else {
		$archive_path = $ce->{webworkDirs}{courses} . "/$courseID.tar.gz";
	}
	
	
	# fail if the source course does not exist
	unless (-e $course_dir) {
		croak "$courseID: course not found";
	}
	
    # replace previous archived file if it exists.
	if (-e $archive_path) {
		unlink($archive_path) if (-w $archive_path);
		unless (-e $archive_path) {
			print CGI::p({-style=>'color:red; font-weight:bold'}, "The archival version of '$courseID' has been replaced'.\n");
		} else {
			croak "Unable to replace the archival version of '$courseID'";
		}
	}
	
	#### step 1: dump tables #####
	
	unless (-e $dump_dir) {
		mkdir $dump_dir or croak "Failed to create course database dump directory '$dump_dir': $!";
	}
	
	my $db = new WeBWorK::DB($ce->{dbLayout});
	my $dump_db_result = $db->dump_tables($dump_dir);
	unless ($dump_db_result) {
		_archiveCourse_remove_dump_dir($ce, $dump_dir);
		croak "$courseID: course database dump failed.\n";
	}
	
	##### step 2: tar and gzip course directory (including dumped database) #####
	
	# we want tar to run from the parent directory of the course directory
	my $chdir_to = "$course_dir/..";
	
	my $tar_cmd = "2>&1 " . $ce->{externalPrograms}{tar}
		. " -C " . shell_quote($chdir_to)
		. " -czf " . shell_quote($tmp_archive_path)
		. " " . shell_quote($courseID);
	my $tar_out = readpipe $tar_cmd;
	if ($?) {
		my $exit = $? >> 8;
		my $signal = $? & 127;
		my $core = $? & 128;
		_archiveCourse_remove_dump_dir($ce, $dump_dir);
		croak "Failed to archive course directory '$course_dir' with command '$tar_cmd' (exit=$exit signal=$signal core=$core): $tar_out\n";
	}
	
	##### step 3: cleanup -- remove database dump files from course directory #####
	
	unless (-e $archive_path) {
		rename $tmp_archive_path, $archive_path;
	} else {  
		croak "Failed to create archived file at  '$archive_path'. File already exists.";
		unlink($tmp_archive_path);  #clean up	
	}
	_archiveCourse_remove_dump_dir($ce, $dump_dir);
}

sub _archiveCourse_remove_dump_dir {
	my ($ce, $dump_dir) = @_;
	my $rm_cmd = "2>&1 " . $ce->{externalPrograms}{rm}
		. " -rf " . shell_quote($dump_dir);
	my $rm_out = readpipe $rm_cmd;
	if ($?) {
		my $exit = $? >> 8;
		my $signal = $? & 127;
		my $core = $? & 128;
		carp "Failed to remove course database dump directory '$dump_dir' with command '$rm_cmd' (exit=$exit signal=$signal core=$core): $rm_out\n";
	}
}

################################################################################

=item unarchiveCourse(%options)

%options must contain:

 oldCourseID => $oldCourseID,
 archivePath => $archivePath,
 ce          => $ce,

%options may also contain:

 newCourseID => $newCourseID,

Restores course $oldCourseID from a gzipped tar archive (.tar.gz) located at
$archivePath. After unarchiving, the course database is restored from a
subdirectory of the course's DATA directory.

If $newCourseID is defined and differs from $oldCourseID, the course is renamed
after unarchiving.

$ce is a WeBWorK::CourseEnvironment object that describes the some course's
environment. (Usually this would be the admin course.) This is used to access
the course database and get path information.

If an error occurs, an exception is thrown.

=cut

sub unarchiveCourse {
	my (%options) = @_;
	
	my $newCourseID = $options{newCourseID};
	my $currCourseID = $options{oldCourseID};
	my $archivePath = $options{archivePath};
	my $ce = $options{ce};
	
	my $coursesDir  = $ce->{webworkDirs}{courses};
	
	# Double check that the new course does not exist
	if (-e "$coursesDir/$newCourseID") {
		die "Cannot overwrite existing course $coursesDir/$newCourseID";
	}
	
	# fail if the target courseID is too long
	croak "New course ID cannot exceed " . $ce->{maxCourseIdLength} . " characters."
		if ( length($newCourseID) > $ce->{maxCourseIdLength} );


	##### step 1: move a conflicting course away #####
	
	# if this function returns undef, it means there was no course in the way
	my $restoreCourseData = _unarchiveCourse_move_away($ce, $currCourseID);
	
	##### step 2: crack open the tarball #####
	
	my $tar_cmd = "2>&1 " . $ce->{externalPrograms}{tar}
		. " -C " . shell_quote($coursesDir)
		. " -xzf " . shell_quote($archivePath);
	my $tar_out = readpipe $tar_cmd;
	if ($?) {
		my $exit = $? >> 8;
		my $signal = $? & 127;
		my $core = $? & 128;
		_unarchiveCourse_move_back($restoreCourseData);
		die "Failed to unarchive course directory with command '$tar_cmd' (exit=$exit signal=$signal core=$core): $tar_out\n";
	}
	
	##### step 3: read the course environment for this course #####
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		get_SeedCE($ce),
		courseName => $currCourseID,
	});
	
	# pull out some useful stuff
	my $course_dir = $ce2->{courseDirs}{root};
	my $data_dir = $ce2->{courseDirs}{DATA};
	my $dump_dir = "$data_dir/mysqldump";
	my $old_dump_file = "$data_dir/${currCourseID}_mysql.database";
	
	##### step 4: restore the database tables #####
	
	my $no_database;
	my $restore_db_result = 1;
	if (-e $dump_dir) {
		my $db = new WeBWorK::DB($ce2->{dbLayout});
		$restore_db_result = $db->restore_tables($dump_dir);
	} elsif (-e $old_dump_file) {
		my $dbLayoutName = $ce2->{dbLayoutName};
		if (ref getHelperRef("unarchiveCourseHelper", $dbLayoutName)) {
			eval {
				$restore_db_result = unarchiveCourseHelper($currCourseID, $ce2, $dbLayoutName,
					unarchiveDatabasePath=>$old_dump_file);
			};
			if ($@) {
				warn "failed to unarchive course database from dump file '$old_dump_file: $@\n";
			}
		} else {
			warn "course '$currCourseID' uses dbLayout '$dbLayoutName', which doesn't support restoring database tables. database tables will not be restored.\n";
			$no_database = 1;
		}
	} else {
		warn "course '$currCourseID' has no database dump in its data directory (checked for $dump_dir and $old_dump_file). database tables will not be restored.\n";
		$no_database = 1;
	}
	
	unless ($restore_db_result) {
		warn "database restore of course '$currCourseID' failed: the course will probably not be usable.\n";
	}
	
	##### step 5: delete dump_dir and/or old_dump_file #####
	
	if (-e $dump_dir) {
		_archiveCourse_remove_dump_dir($ce, $dump_dir);
	}
	if (-e $old_dump_file) {
		unlink $old_dump_file or carp "Failed to unlink course database dump file '$old_dump_file: $_\n";
	}

	# Create the html_temp folder (since it isn't included in the
	# tarball
	my $tmpDir = $ce2->{courseDirs}->{html_temp};
	if (! -e $tmpDir) {
	  mkdir $tmpDir or warn "Failed to create html_temp directory '$tmpDir': $!. You will have to create this directory manually.\n";
	}
	
	##### step 6: rename course #####
	
	if (defined $newCourseID and $newCourseID ne $currCourseID) {
		renameCourse(
			courseID     => $currCourseID,
			ce           => $ce2,
			newCourseID  => $newCourseID,
			skipDBRename => $no_database,
		);
	}
	
	##### step 7: return conflicting course to its rightful place #####
	
	_unarchiveCourse_move_back($restoreCourseData);
}

sub _unarchiveCourse_move_away {
	my ($ce, $courseID) = @_;
	
	# course environment for before the course is moved
	my $ce2 = new WeBWorK::CourseEnvironment({
		get_SeedCE($ce),
		courseName => $courseID,
	});
	
	# if course directory doesn't exist, we don't have to do anything
	return unless -e $ce2->{courseDirs}{root};
	
	# temporary name for course
	my $tmpCourseID = "${courseID}_tmp";
	
	debug("Temporarily moving $courseID to $tmpCourseID to make room for course unarchiving");
	renameCourse(
		courseID    => $courseID,
		ce          => $ce2,
		newCourseID => $tmpCourseID,
	);
	
	# course environment for after the course is moved
	my $ce3 = new WeBWorK::CourseEnvironment({
		get_SeedCE($ce),
		courseName => $tmpCourseID,
	});
	
	# data to pass to renameCourse when moving the course back to it's original name
	my $restore_course_data = {
		courseID    => $tmpCourseID,
		ce          => $ce3, # course environment for moved course
		newCourseID => $courseID,
	};
	
	return $restore_course_data;
}

sub _unarchiveCourse_move_back {
	my ($restore_course_data) = @_;
	
	return unless $restore_course_data;
	
	debug("Moving $$restore_course_data{courseID} back to $$restore_course_data{newCourseID} after course unarchiving");
	renameCourse(%$restore_course_data);
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

=item initNonNativeTables($ce, $db, $dbLayoutName, %options)

Perform database-layout specific operations for initializing non-native database tables
that are not associated with a particular course

=back

=cut

sub initNonNativeTables {
	my($ce, $dbLayoutName, %options) = @_;
	my $str = '';
	# Create a database handler
	my $db = new WeBWorK::DB($ce->{dbLayouts}->{$dbLayoutName});
	
	 # lock database
	 
	# Find the names of the non-native database tables 
	foreach my $table (sort keys %$db) {
	    next unless $db->{$table}{params}{non_native}; # only look at non-native tables
	    # hack: these two tables are virtual and don't need to be created 
	    # for the admin course or in the database in general
	    # if they were created in earlier versions for the admin course 
	    # you can use mysql to drop the field version_id manually
	    # this will get rid of a spurious error
	    next if $table eq 'problem_version' or $table eq 'set_version';
	   
	    my $database_table_name = (exists $db->{$table}->{params}->{tableOverride})? $db->{$table}->{params}->{tableOverride}:$table;
	    #warn "table is $table";
	    #warn "checking $database_table_name";
	    my $database_table_exists = ($db->{$table}->tableExists) ? 1:0;
	    if  (!$database_table_exists ) { # exists means the table can be described;
	    	my $schema_obj = $db->{$table};
	    	if ($schema_obj->can("create_table")) {
			    #warn "creating table $database_table_name  with object $schema_obj";
				$schema_obj->create_table;
				$str .= "Table '$table' created as '$database_table_name' in database.".CGI::br();
			} else {
				# warn "Skipping creation of '$table' table: no create_table method\n";
			}
	    #if table exists then we need to check its fields, we only check if it is missing
	    #fields in the schema.  Its not a huge issue if the database table has extra columns.
	    } else {
		my %fieldStatus;
		my $fields_ok=1;
		my @schema_field_names =  $db->{$table}->{record}->FIELDS;
		my %schema_override_field_names=();
		foreach my $field (sort @schema_field_names) {
		    my $field_name  = $db->{$table}->{params}->{fieldOverride}->{$field} ||$field;
		    $schema_override_field_names{$field_name}=$field;	
		    my $database_field_exists = $db->{$table}->tableFieldExists($field_name);
		    #if the field doesn't exist then try to add it... 
		    if (!$database_field_exists) { 
			$fields_ok = 0;
			$fieldStatus{$field} =[ONLY_IN_A];
			warn "$field from $database_table_name (aka |$table|) is only in schema, not in database, so adding it ... ";
			if ( $db->{$table}->can("add_column_field") ) {
			    if ($db->{$table}->add_column_field($field_name)) {
				warn "added column $field_name to table $database_table_name";
			    } else {
				warn "couldn't add column $field_name to table $database_table_name";
			    }
		    }
			
		}
	       
		}
			
	    }
	    
	   
	}
	
	# unlock database
	$str;


}



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

=item getHelperRef($helperName, $dbLayoutName)

Call a database-specific helper function, if a database-layout specific helper
class exists and contains a function named "${helperName}Helper".

=cut

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

=back

=cut

sub writeCourseConf {
	my ($fh, $ce, %options) = @_;
	
	# several options should be defined no matter what
	$options{dbLayoutName} = $ce->{dbLayoutName} unless defined $options{dbLayoutName};
	
	print $fh <<'EOF';
#!perl
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright 2000-2016 The WeBWorK Project, http://openwebwork.sf.net/
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
# Database Layout (global value typically defined in defaults.config)
# 
# Several database are defined in the file conf/database.conf and stored in the
# hash %dbLayouts.
# 
# The database layout is always set here, since one should be able to change the
# default value in localOverrides.conf without disrupting existing courses.
# 
# defaults.config values:
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
# defaults.config values:
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
# By default, feedback is sent to all users who have permission to
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
# defaults.config values:
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
# defaults.config values:
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


sub get_SeedCE {     # helper subroutine to produce a stripped down seed Course Environment from an arbitrary course environment
	my $ce = shift;
	warn "get_SeedCE needs current Course environment to create seed CE" unless ref($ce) ;
	my %seedCE=();
	my @conf_items = qw( webwork_dir webwork_url pg_dir courseName)   ;  # items to transfer. courseName is often overridden
	foreach my $item (@conf_items) {
			$seedCE{$item} = $ce->{$item};
	}
    return( %seedCE);
}
1;
