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

package WeBWorK::Utils::CourseManagement;
use base qw(Exporter);

=head1 NAME

WeBWorK::Utils::CourseManagement - create, rename, and delete courses.

=cut

use strict;
use warnings;

use Carp;
use DBI;
use String::ShellQuote;
use UUID::Tiny            qw(create_uuid_as_string);
use Mojo::File            qw(path);
use File::Copy::Recursive qw(dircopy);
use File::Spec;
use Archive::Tar;

use WeBWorK::Debug;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Utils             qw(runtime_use);
use WeBWorK::Utils::Files      qw(surePathToFile);
use WeBWorK::Utils::Instructor qw(assignSetsToUsers);

our @EXPORT_OK = qw(
	listCourses
	listArchivedCourses
	addCourse
	renameCourse
	retitleCourse
	deleteCourse
	archiveCourse
	unarchiveCourse
	initNonNativeTables

);

use constant {    # constants describing the comparison of two hashes.
	ONLY_IN_A         => 0,
	ONLY_IN_B         => 1,
	DIFFER_IN_A_AND_B => 2,
	SAME_IN_A_AND_B   => 3
};

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

	my $dbname   = ${ce}->{database_name};
	my $stmt_bad = 0;
	my $stmt     = $dbh->prepare("show tables") or ($stmt_bad = 1);
	my %user_tables_seen;    # Will also include problem_user, set_user, achievement_user, set_locations_user
	if (!$stmt_bad) {
		$stmt->execute() or ($stmt_bad = 1);
		my @row;
		while (@row = $stmt->fetchrow_array) {
			if ($row[0] =~ /_user$/) {
				$user_tables_seen{ $row[0] } = 1;
			}
		}
		$stmt->finish();
	}
	$dbh->disconnect();

	# Collect directories which may be course directories
	my @cdirs =
		@{ path($coursesDir)->list({ dir => 1 })->grep(sub { -d $_ && $_->basename ne 'modelCourse' })->map('basename')
		};
	if ($stmt_bad) {
		# Fall back to old method listing all directories.
		return @cdirs;
	} else {
		my @courses;
		for my $cname (@cdirs) {
			push(@courses, $cname) if $user_tables_seen{"${cname}_user"};
		}
		return @courses;
	}
}

=item listArchivedCourses($ce)

Lists the courses which have been archived (end in .tar.gz).

=cut

sub listArchivedCourses {
	my ($ce) = @_;
	my $archivesDir = path("$ce->{webworkDirs}{courses}/$ce->{admin_course_id}/archives");
	surePathToFile($ce->{webworkDirs}{courses}, "$archivesDir/test");    # Ensure archives directory exists.
	return @{ $archivesDir->list->grep(qr/\.tar\.gz$/)->map('basename') };
}

################################################################################

=item addCourse(%options)

%options must contain:

 courseID      => course ID for the new course,
 ce            => a course environment for the new course,
 courseOptions => hash ref explained below
 users         => array ref explained below

%options may contain:

 copyFrom          => some course ID to copy things from,
 courseTitle       => a title for the new course
 courseInstitution => institution for the new course
 copyTemplatesHtml => boolean
 copySimpleConfig  => boolean
 copyConfig        => boolean
 copyNonStudents   => boolean
 copySets          => boolean
 copyAchievements  => boolean
 copyTitle         => boolean
 copyInstitution   => boolean

Create a new course with ID $courseID.

$ce is a WeBWorK::CourseEnvironment object that describes the new course's
environment.

$courseOptions is a reference to a hash containing the following options:

    PRINT_FILE_NAMES_FOR => $pg{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR}

C<PRINT_FILE_NAMES_FOR> is a reference to an array.

$users is a list of arrayrefs, each containing a User, Password, and
PermissionLevel record for a single user:

 $users = [ $User, $Password, $PermissionLevel ]

These users are added to the course.

C<copyFrom> indicates the ID of a course from which various things may be
copied into the new course. Which things are copied are controlled by the
boolean options:

 * copyTemplatesHtml (contents of Templates and HTML folders)
 * copySimpleConfig  (simple.conf file)
 * copyConfig        (course.conf file)
 * copyNonStudents   (all non-student users, their permission level, and password)
 * copySets          (all global sets, global set locations, and global problems)
 * copyAchievements  (all achievements)
 * copyTitle         (the course title, which will override courseTitle)
 * copyInstitution   (the course institution, which will override courseInstitution)

=cut

sub addCourse {
	my (%options) = @_;

	for my $key (keys(%options)) {
		my $value = '####UNDEF###';
		$value = $options{$key} if (defined($options{$key}));
		debug("$key  : $value");
	}

	my $courseID      = $options{courseID};
	my $sourceCourse  = $options{copyFrom} // '';
	my $ce            = $options{ce};
	my %courseOptions = %{ $options{courseOptions} // {} };
	my @users         = exists $options{users} ? @{ $options{users} } : ();

	debug \@users;

	my @initialUsers = @users;
	my %user_args    = map { $_->[0]{user_id} => 1 } @users;

	# collect some data
	my $coursesDir = $ce->{webworkDirs}->{courses};
	my $courseDir  = "$coursesDir/$courseID";

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
		if (length($courseID) > $ce->{maxCourseIdLength});

	##### step 1: create course directory structure #####

	my %courseDirs = %{ $ce->{courseDirs} };

	# deal with root directory first -- if we can't create it, we have to give up.

	exists $courseDirs{root}
		or croak
		"Can't create the course '$courseID' because no root directory is specified in the '%courseDirs' hash.";
	my $root = $courseDirs{root};
	delete $courseDirs{root};
	{
		# does the directory already exist?
		-e $root and croak "Can't create the course '$courseID' because the root directory '$root' already exists.";
		# is the parent directory writeable?
		my @rootElements = File::Spec->splitdir($root);
		pop @rootElements;
		my $rootParent = File::Spec->catdir(@rootElements);
		-w $rootParent
			or croak
			"Can't create the course '$courseID' because the courses directory '$rootParent' is not writeable.";
		# try to create it
		eval { path($root)->make_path };
		croak "Can't create the course '$courseID' because the root directory '$root' could not be created: $@." if $@;
	}

	# deal with the rest of the directories

	my @courseDirNames = sort { $courseDirs{$a} cmp $courseDirs{$b} } keys %courseDirs;
	foreach my $courseDirName (@courseDirNames) {
		my $courseDir = File::Spec->canonpath($courseDirs{$courseDirName});

		# does the directory already exist?
		if (-e $courseDir) {
			warn "Can't create $courseDirName directory '$courseDir', "
				. "since it already exists. Using existing directory.\n";
			next;
		}

		# is the parent directory writeable?
		my @courseDirElements = File::Spec->splitdir($courseDir);
		pop @courseDirElements;
		my $courseDirParent = File::Spec->catdir(@courseDirElements);
		unless (-w $courseDirParent) {
			warn "Can't create $courseDirName directory '$courseDir', since the parent directory is not writeable. "
				. "You will have to create this directory manually.\n";
			next;
		}

		# try to create it
		eval { path($courseDir)->make_path };
		warn "Failed to create $courseDirName directory '$courseDir': $@. "
			. "You will have to create this directory manually."
			if $@;
	}

	# hide the new course?

	if (defined $ce->{new_courses_hidden_status} && $ce->{new_courses_hidden_status} eq 'hidden') {
		my $hideDirFile = "$ce->{webworkDirs}{courses}/$courseID/hide_directory";
		open(my $HIDEFILE, '>', $hideDirFile);
		print $HIDEFILE 'Place a file named "hide_directory" in a course or other directory and it will not show up '
			. 'in the courses list on the WeBWorK home page. It will still appear in the '
			. 'Course Administration listing.';
		close $HIDEFILE;
	}

	##### step 2: create course database #####

	my $db               = WeBWorK::DB->new($ce);
	my $create_db_result = $db->create_tables;
	die "$courseID: course database creation failed.\n" unless $create_db_result;

	##### step 3: populate course database #####

	# database and course environment objects for the course to copy things from.
	my ($db0, $ce0);
	if (
		$sourceCourse ne ''
		&& !(grep { $sourceCourse eq $_ } @{ $ce->{modelCoursesForCopy} })
		&& ($options{copyNonStudents}
			|| $options{copySets}
			|| $options{copyAchievements}
			|| $options{copyTitle}
			|| $options{copyInstitution})
		)
	{
		$ce0 = WeBWorK::CourseEnvironment->new({ courseName => $sourceCourse });
		$db0 = WeBWorK::DB->new($ce0);
	}

	# add users (users that were directly passed to addCourse() as well as those copied from a source course)
	if ($db0 && $options{copyNonStudents}) {
		# If the course.conf file is being copied, then the student role from the source course needs to be used,
		# as the role might be customized in that file.
		my @non_student_ids =
			map {@$_} ($db0->listPermissionLevelsWhere({
				permission => { '!=' => $options{copyConfig} ? $ce0->{userRoles}{student} : $ce->{userRoles}{student} },
				user_id    => { not_like => 'set_id:%' }
			}));

		for my $user_id (@non_student_ids) {
			next if $user_args{$user_id};
			my @User            = $db0->getUsersWhere({ user_id => $user_id });
			my @Password        = $db0->getPasswordsWhere({ user_id => $user_id });
			my @PermissionLevel = $db0->getPermissionLevelsWhere({ user_id => $user_id });
			push @users, [ $User[0], $Password[0], $PermissionLevel[0] ];
		}
	}

	foreach my $userTriple (@users) {
		my ($User, $Password, $PermissionLevel) = @$userTriple;
		eval { $db->addUser($User) };
		warn $@                              if $@;
		eval { $db->addPassword($Password) } if $Password;
		warn $@                              if $@;
		eval { $db->addPermissionLevel($PermissionLevel) };
		warn $@ if $@;
	}

	# add sets
	if ($db0 && $options{copySets}) {
		my @sets = $db0->getGlobalSetsWhere;
		for my $set (@sets) {
			$set->lis_source_did(undef);
			eval { $db->addGlobalSet($set) };
			warn $@ if $@;

			my @Problem = $db0->getGlobalProblemsWhere({ set_id => $set->set_id });
			for my $problem (@Problem) {
				eval { $db->addGlobalProblem($problem) };
				warn $@ if $@;
			}

			my @Location = $db0->getGlobalSetLocationsWhere({ set_id => $set->set_id });
			for my $location (@Location) {
				eval { $db->addGlobalSetLocation($location) };
				warn $@ if $@;
			}

			# Copy the set level proctor user for this set if there is one (despite the for loop there can only be one).
			for my $setProctor ($db0->getUsersWhere({ user_id => 'set_id:' . $set->set_id })) {
				eval { $db->addUser($setProctor) };
				warn $@ if $@;

				my $password = $db0->getPassword($setProctor->user_id);
				eval { $db->addPassword($password) } if $password;
				warn $@                              if $@;

				my $permission = $db0->getPermissionLevel($setProctor->user_id);
				eval { $db->addPermissionLevel($permission) } if $permission;
				warn $@                                       if $@;
			}
		}
		if ($options{copyNonStudents}) {
			foreach my $userTriple (@users) {
				my $user_id = $userTriple->[0]{user_id};
				next if $user_args{$user_id};    # Initial users will be assigned to everything below.
				my @user_sets = $db0->listUserSets($user_id);
				assignSetsToUsers($db, $ce, \@user_sets, [$user_id]);
			}
		}
		assignSetsToUsers($db, $ce, [ map { $_->set_id } @sets ], [ map { $_->[0]{user_id} } @initialUsers ])
			if @initialUsers;
	}

	# add achievements
	if ($db0 && $options{copyAchievements}) {
		my @achievement = $db0->getAchievementsWhere;
		for my $achievement (@achievement) {
			eval { $db->addAchievement($achievement) };
			warn $@ if $@;
			for (@initialUsers) {
				my $userAchievement = $db->newUserAchievement();
				$userAchievement->user_id($_->[0]{user_id});
				$userAchievement->achievement_id($achievement->achievement_id);
				$db->addUserAchievement($userAchievement);
			}
		}
		if ($options{copyNonStudents}) {
			foreach my $userTriple (@users) {
				my $user_id = $userTriple->[0]{user_id};
				next if $user_args{$user_id};    # Initial users were assigned to all achievements above.
				my @user_achievements = $db0->listUserAchievements($user_id);
				for my $achievement_id (@user_achievements) {
					my $userAchievement = $db->newUserAchievement();
					$userAchievement->user_id($user_id);
					$userAchievement->achievement_id($achievement_id);
					$db->addUserAchievement($userAchievement);
				}
			}
		}
	}

	# copy title and/or institution if requested
	for my $setting ('Title', 'Institution') {
		if ($db0 && $options{"copy$setting"}) {
			my $settingValue = $db0->getSettingValue("course$setting");
			$db->setSettingValue("course$setting", $settingValue) if defined $settingValue && $settingValue ne '';
		} else {
			$db->setSettingValue("course$setting", $options{"course$setting"})
				if defined $options{"course$setting"} && $options{"course$setting"} ne '';
		}
	}

##### step 4: write course.conf file (unless that is going to be copied from a source course) #####

	unless ($sourceCourse ne '' && $options{copyConfig}) {
		my $courseEnvFile = $ce->{courseFiles}{environment};
		open my $fh, ">:utf8", $courseEnvFile
			or die "failed to open $courseEnvFile for writing.\n";
		writeCourseConf($fh, $ce, %courseOptions);
		close $fh;
	}

##### step 5: copy templates, html, simple.conf, course.conf if desired #####

	if ($sourceCourse ne '') {
		my $sourceCE = WeBWorK::CourseEnvironment->new({ get_SeedCE($ce), courseName => $sourceCourse });

		if ($options{copyTemplatesHtml}) {
			my $sourceDir = $sourceCE->{courseDirs}{templates};

			## copy templates ##
			if (-d $sourceDir) {
				my $destDir = $ce->{courseDirs}{templates};
				warn "Failed to copy templates from course '$sourceCourse': $! " unless dircopy("$sourceDir", $destDir);
			} else {
				warn "Failed to copy templates from course '$sourceCourse': "
					. "templates directory '$sourceDir' does not exist.\n";
			}

			## copy html ##
			$sourceDir = $sourceCE->{courseDirs}{html};
			if (-d $sourceDir) {
				warn "Failed to copy html from course '$sourceCourse': $!"
					unless dircopy($sourceDir, $ce->{courseDirs}{html});
			} else {
				warn "Failed to copy html from course '$sourceCourse': html directory '$sourceDir' does not exist.\n";
			}
		}

		## copy config files ##

		# this copies the simple.conf file if desired
		if ($options{copySimpleConfig}) {
			my $sourceFile = $sourceCE->{courseFiles}{simpleConfig};
			if (-e $sourceFile) {
				eval { path($sourceFile)->copy_to($ce->{courseDirs}{root}) };
				warn "Failed to copy simple.conf from course '$sourceCourse': $@" if $@;
			}
		}

		# this copies the course.conf file if desired
		if ($options{copyConfig}) {
			my $sourceFile = $sourceCE->{courseFiles}{environment};
			if (-e $sourceFile) {
				eval { path($sourceFile)->copy_to($ce->{courseDirs}{root}) };
				warn "Failed to copy course.conf from course '$sourceCourse': $@" if $@;
			}
		}
	}
}

################################################################################

=item renameCourse(%options)

%options must contain:

 courseID => $courseID,
 ce => $ce,
 newCourseID => $newCourseID,

%options may also contain:

 skipDBRename => $skipDBRename,
 courseTitle => $courseTitle
 courseInstitution => $courseInstitution


Rename the course named $courseID to $newCourseID.

$ce is a WeBWorK::CourseEnvironment object that describes the existing course's
environment.

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

	my $oldCourseID  = $options{courseID};
	my $oldCE        = $options{ce};
	my $newCourseID  = $options{newCourseID};
	my $skipDBRename = $options{skipDBRename} || 0;

	# collect some data
	my $coursesDir   = $oldCE->{webworkDirs}->{courses};
	my $oldCourseDir = "$coursesDir/$oldCourseID";
	my $newCourseDir = "$coursesDir/$newCourseID";

	# fail if the target course already exists
	if (-e $newCourseDir) {
		croak "$newCourseID: course exists";
	}

	# fail if the target courseID is too long
	croak "New course ID cannot exceed " . $oldCE->{maxCourseIdLength} . " characters."
		if (length($newCourseID) > $oldCE->{maxCourseIdLength});

	# fail if the source course does not exist
	unless (-e $oldCourseDir) {
		croak "$oldCourseID: course not found";
	}

	##### step 1: move course directory #####

	# move top-level course directory
	debug("moving course dir from $oldCourseDir to $newCourseDir");
	eval { path($oldCourseDir)->move_to($newCourseDir) };
	die "Failed to move course directory:  $@" if ($@);

	# get new course environment
	my $newCE = $oldCE->new({ courseName => $newCourseID });

	# find the course dirs that still exist in their original locations
	# (i.e. are not subdirs of $courseDir)
	my %oldCourseDirs  = %{ $oldCE->{courseDirs} };
	my %newCourseDirs  = %{ $newCE->{courseDirs} };
	my @courseDirNames = sort { $oldCourseDirs{$a} cmp $oldCourseDirs{$b} } keys %oldCourseDirs;
	foreach my $courseDirName (@courseDirNames) {
		my $oldDir = File::Spec->canonpath($oldCourseDirs{$courseDirName});
		my $newDir = File::Spec->canonpath($newCourseDirs{$courseDirName});
		if (-e $oldDir) {
			debug("oldDir $oldDir still exists. might move it...\n");

			# check for a few likely error conditions, since the mv error is not that helpful

			# is the source really a directory
			unless (-d $oldDir) {
				warn "$courseDirName: Can't move '$oldDir' to '$newDir', since the source is not a directory. "
					. "You will have to move this directory manually.\n";
				next;
			}

		# does the destination already exist?
		# (this should only happen on extra-coursedir directories, since we make sure the root dir doesn't exist above.)
			if (-e $newDir) {
				warn "$courseDirName: Can't move '$oldDir' to '$newDir', since the target already exists. "
					. "You will have to move this directory manually.\n";
				next;
			}

			# is oldDir's parent writeable
			my @oldDirElements = File::Spec->splitdir($oldDir);
			pop @oldDirElements;
			my $oldDirParent = File::Spec->catdir(@oldDirElements);
			unless (-w $oldDirParent) {
				warn "$courseDirName: Can't move '$oldDir' to '$newDir', since the source parent directory is not "
					. "writeable. You will have to move this directory manually.\n";
				next;
			}

			# is newDir's parent writeable?
			my @newDirElements = File::Spec->splitdir($newDir);
			pop @newDirElements;
			my $newDirParent = File::Spec->catdir(@newDirElements);
			unless (-w $newDirParent) {
				warn "$courseDirName: Can't move '$oldDir' to '$newDir', since the destination parent directory is "
					. "not writeable. You will have to move this directory manually.\n";
				next;
			}

			# try to move the directory
			debug("Going to move $oldDir to $newDir...\n");
			eval { path($oldDir)->move_to($newDir) };
			warn "Failed to move directory from $oldDir to $newDir with error: $@" if $@;
		} else {
			debug("oldDir $oldDir was already moved.\n");
		}
	}

	##### step 2: rename database #####

	unless ($skipDBRename) {
		my $oldDB = WeBWorK::DB->new($oldCE);

		my $rename_db_result = $oldDB->rename_tables($newCE);
		die "$oldCourseID: course database renaming failed.\n" unless $rename_db_result;
		#update title and institution
		my $newDB = WeBWorK::DB->new($newCE);
		eval {
			if (defined $options{courseTitle} && $options{courseTitle} ne '') {
				$newDB->setSettingValue('courseTitle', $options{courseTitle});
			}
			if (defined $options{courseInstitution} && $options{courseInstitution} ne '') {
				$newDB->setSettingValue('courseInstitution', $options{courseInstitution});
			}
		};
		warn "Problems from resetting course title and institution = $@" if $@;
	}
}

################################################################################

=item retitleCourse

	Simply changes the title and institution of the course.

Options must contain:

 courseID => $courseID,
 ce => $ce,

Options may contain
 newCourseTitle => $courseTitle,
 newCourseInstitution => $courseInstitution,

=cut

sub retitleCourse {
	my %options = @_;

	my $courseID = $options{courseID};
	my $ce       = $options{ce};

	# get the database layout out of the options hash
	my $db = WeBWorK::DB->new($ce);
	eval {
		if (defined $options{courseTitle} && $options{courseTitle} ne '') {
			$db->setSettingValue('courseTitle', $options{courseTitle});
		}
		if (defined $options{courseInstitution} && $options{courseInstitution} ne '') {
			$db->setSettingValue('courseInstitution', $options{courseInstitution});
		}
	};
	warn "Problems from resetting course title and institution = $@" if $@;

}

=item deleteCourse(%options)

Options must contain:

 courseID => $courseID,
 ce => $ce,

$ce is a WeBWorK::CourseEnvironment object that describes the course's
environment. It is your responsability to pass a course environment object that
describes the course to be deleted. Do not pass the course environment object
associated with the request, unless you are deleting the course you're currently
using.

Deletes the course named $courseID. The course directory is removed.

Any errors encountered while deleting the course are returned.

=cut

sub deleteCourse {
	my (%options) = @_;

	my $courseID = $options{courseID};
	my $ce       = $options{ce};

	# make sure the user isn't brain damaged
	die "the course environment supplied doesn't appear to describe the course $courseID. can't proceed."
		unless $ce->{courseName} eq $courseID;

	my %courseDirs = %{ $ce->{courseDirs} };

	##### step 0: make sure course directory is deleteable #####

	# deal with root directory first -- if we won't be able to delete it, we have to give up.

	exists $courseDirs{root}
		or croak
		"Can't delete the course '$courseID' because no root directory is specified in the '%courseDirs' hash.";
	my $root = $courseDirs{root};
	if (-e $root) {
		# is the parent directory writeable?
		my @rootElements = File::Spec->splitdir($root);
		pop @rootElements;
		my $rootParent = File::Spec->catdir(@rootElements);
		-w $rootParent
			or croak
			"Can't delete the course '$courseID' because the courses directory '$rootParent' is not writeable.";
	} else {
		warn "Warning: the course root directory '$root' does not exist. "
			. "Attempting to delete the course database and other course directories...\n";
	}

	##### step 1: delete course database (if necessary) #####

	my $db               = WeBWorK::DB->new($ce);
	my $create_db_result = $db->delete_tables;
	die "$courseID: course database deletion failed.\n" unless $create_db_result;

	# If this course has an entry in the LTI course map, then delete it also.
	$db->deleteLTICourseMapWhere({ course_id => $courseID });

	##### step 2: delete course directory structure #####

	my @courseDirNames = sort { $courseDirs{$a} cmp $courseDirs{$b} } keys %courseDirs;
	foreach my $courseDirName (@courseDirNames) {
		my $courseDir = File::Spec->canonpath($courseDirs{$courseDirName});
		if (-e $courseDir) {
			debug("courseDir $courseDir still exists. might delete it...\n");

			# check for a few likely error conditions, since the mv error is not that helpful

			# is it really a directory
			unless (-d $courseDir) {
				warn "Can't delete $courseDirName directory '$courseDir', since is not a directory. "
					. "If it is not wanted, you will have to delete it manually.\n";
				next;
			}

			# is the parent writeable
			my @courseDirElements = File::Spec->splitdir($courseDir);
			pop @courseDirElements;
			my $courseDirParent = File::Spec->catdir(@courseDirElements);
			unless (-w $courseDirParent) {
				warn "Can't delete $courseDirName directory '$courseDir', since its parent directory is not "
					. "writeable. If it is not wanted, you will have to delete it manually.\n";
				next;
			}

			# try to delete the directory
			debug("Going to delete $courseDir...\n");
			eval { path($courseDir)->remove_tree };
			warn "An error occurred when deleting $courseDir" if $@;
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

Creates a gzipped tar archive (.tar.gz) of the course $courseID and places it in the
archives directory of the admin course or in the location given in the optional archive_path
option.  Before archiving, the course database is dumped into a subdirectory of the course's
DATA directory.

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
	my $courseID  = $options{courseID};
	my $ce        = $options{ce};

	# make sure the user isn't brain damaged
	croak "The course environment supplied doesn't appear to match the course $courseID. Can't proceed"
		unless $ce->{courseName} eq $courseID;

	# grab some values we'll need
	my $course_dir = $ce->{courseDirs}{root};

	# tmp_archive_path is used as the target of the tar.gz operation.
	# After this is done the final tar.gz file is moved either to the admin course archives directory
	# course/$ce->{admin_course_id}/archives or the supplied archive_path option if it is present.
	# This prevents us from tarring a directory to which we have just added a file
	# see bug #2022 -- for error messages on some operating systems
	my $uuidStub         = create_uuid_as_string();
	my $tmp_archive_path = $ce->{webworkDirs}{courses} . "/${uuidStub}_$courseID.tar.gz";
	my $data_dir         = $ce->{courseDirs}{DATA};
	my $dump_dir         = "$data_dir/mysqldump";
	my $archive_path;
	if (defined $options{archive_path} && $options{archive_path} =~ /\S/) {
		$archive_path = $options{archive_path};
	} else {
		$archive_path = "$ce->{webworkDirs}{courses}/$ce->{admin_course_id}/archives/$courseID.tar.gz";
		surePathToFile($ce->{webworkDirs}{courses}, $archive_path);
	}

	# fail if the source course does not exist
	unless (-e $course_dir) {
		croak "$courseID: course not found";
	}

	my $message = '';

	# replace previous archived file if it exists.
	if (-e $archive_path) {
		unlink($archive_path) if (-w $archive_path);
		unless (-e $archive_path) {
			$message .= "The archival version of '$courseID' has been replaced'.";
		} else {
			croak "Unable to replace the archival version of '$courseID'";
		}
	}

	#### step 1: dump tables #####

	unless (-e $dump_dir) {
		eval { path($dump_dir)->make_path };
		croak "Failed to create course database dump directory '$dump_dir': $@" if $@;
	}

	my $db             = WeBWorK::DB->new($ce);
	my $dump_db_result = $db->dump_tables($dump_dir);
	unless ($dump_db_result) {
		_archiveCourse_remove_dump_dir($ce, $dump_dir);
		croak "$courseID: course database dump failed.\n";
	}

	##### step 2: tar and gzip course directory (including dumped database) #####

	my $parent_dir = $ce->{webworkDirs}{courses};
	my $files      = path($course_dir)->list_tree({ dir => 1, hidden => 1 })->map('to_abs');
	my $tar        = Archive::Tar->new;
	$tar->add_files($course_dir, @$files);
	for ($tar->get_files) {
		$tar->rename($_->full_path, $_->full_path =~ s!^$parent_dir/!!r);
	}
	my $ok = $tar->write($tmp_archive_path, COMPRESS_GZIP);

	unless ($ok) {
		_archiveCourse_remove_dump_dir($ce, $dump_dir);
		croak "Failed to archive course directory '$course_dir': $!";
	}

	##### step 3: cleanup -- remove database dump files from course directory #####

	unless (-e $archive_path) {
		eval { path($tmp_archive_path)->move_to($archive_path) };
		if ($@) {
			eval { path($tmp_archive_path)->remove };
			croak "Failed to rename archived file to '$archive_path': $@";
		}
	} else {
		eval { path($tmp_archive_path)->remove };
		croak "Failed to create archived file at '$archive_path'. File already exists.";
	}
	_archiveCourse_remove_dump_dir($ce, $dump_dir);

	return $message;
}

sub _archiveCourse_remove_dump_dir {
	my ($ce, $dump_dir) = @_;
	path($dump_dir)->remove_tree({ error => \my $err });

	if ($err && @$err) {
		for my $diag (@$err) {
			my ($file, $message) = %$diag;
			warn "Failed to remove course database dump directory: $file with message: $message ";
		}
	}
	return;
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

	my $newCourseID  = $options{newCourseID};
	my $currCourseID = $options{oldCourseID};
	my $archivePath  = $options{archivePath};
	my $ce           = $options{ce};

	my $coursesDir = $ce->{webworkDirs}{courses};

	# Double check that the new course does not exist
	if (-e "$coursesDir/$newCourseID") {
		die "Cannot overwrite existing course $coursesDir/$newCourseID";
	}

	# fail if the target courseID is too long
	croak "New course ID cannot exceed " . $ce->{maxCourseIdLength} . " characters."
		if (length($newCourseID) > $ce->{maxCourseIdLength});

	##### step 1: move a conflicting course away #####

	# if this function returns undef, it means there was no course in the way
	my $restoreCourseData = _unarchiveCourse_move_away($ce, $currCourseID);

	##### step 2: crack open the tarball #####

	my $arch = Archive::Tar->new($archivePath);
	die "The tar file $archivePath is not valid." unless $arch;
	$arch->setcwd($coursesDir);
	$arch->extract();

	if ($arch->error) {
		_unarchiveCourse_move_back($restoreCourseData);
		die "Failed to unarchive course directory for course $newCourseID: $arch->error";
	}

	##### step 3: read the course environment for this course #####

	my $ce2 = WeBWorK::CourseEnvironment->new({ get_SeedCE($ce), courseName => $currCourseID });

	# pull out some useful stuff
	my $course_dir = $ce2->{courseDirs}{root};
	my $data_dir   = $ce2->{courseDirs}{DATA};
	my $dump_dir   = "$data_dir/mysqldump";

	##### step 4: restore the database tables #####

	my $no_database;
	my $restore_db_result = 1;
	if (-e $dump_dir) {
		my $db = WeBWorK::DB->new($ce2);
		$restore_db_result = $db->restore_tables($dump_dir);
	} else {
		warn "course '$currCourseID' has no database dump in its data directory "
			. "(checked for $dump_dir). database tables will not be restored.\n";
		$no_database = 1;
	}

	unless ($restore_db_result) {
		warn "database restore of course '$currCourseID' failed: the course will probably not be usable.\n";
	}

	##### step 5: delete dump_dir #####

	_archiveCourse_remove_dump_dir($ce, $dump_dir) if -e $dump_dir;

	# Create the html_temp folder (since it isn't included in the tarball)
	my $tmpDir = $ce2->{courseDirs}->{html_temp};
	if (!-e $tmpDir) {
		eval { path($tmpDir)->make_path };
		warn "Failed to create html_temp directory '$tmpDir': $@. You will have to create this directory manually."
			if $@;
	}

	# If the course was given a new name, honor $ce->{new_courses_hidden_status}
	if (defined $newCourseID
		&& $newCourseID ne $currCourseID
		&& defined $ce->{new_courses_hidden_status}
		&& $ce->{new_courses_hidden_status} =~ /^(hidden|visible)$/)
	{
		my $hideDirFile = "$ce->{webworkDirs}{courses}/$currCourseID/hide_directory";
		if ($ce->{new_courses_hidden_status} eq 'hidden' && !(-f $hideDirFile)) {
			open(my $HIDEFILE, '>', $hideDirFile);
			print $HIDEFILE
				'Place a file named "hide_directory" in a course or other directory and it will not show up '
				. 'in the courses list on the WeBWorK home page. It will still appear in the '
				. 'Course Administration listing.';
			close $HIDEFILE;
		} elsif ($ce->{new_courses_hidden_status} eq 'visible' && -f $hideDirFile) {
			unlink $hideDirFile;
		}
	}

	##### step 6: rename course #####

	if (defined $newCourseID && $newCourseID ne $currCourseID) {
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
	my $ce2 = WeBWorK::CourseEnvironment->new({ get_SeedCE($ce), courseName => $courseID });

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
	my $ce3 = WeBWorK::CourseEnvironment->new({ get_SeedCE($ce), courseName => $tmpCourseID });

	# data to pass to renameCourse when moving the course back to it's original name
	my $restore_course_data = {
		courseID    => $tmpCourseID,
		ce          => $ce3,           # course environment for moved course
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

=item initNonNativeTables($ce, $db, %options)

Perform database-layout specific operations for initializing non-native database tables
that are not associated with a particular course

=back

=cut

sub initNonNativeTables {
	my ($ce, %options) = @_;
	my @messages;

	# Create a database handler
	my $db = WeBWorK::DB->new($ce);

	# Find the names of the non-native database tables
	for my $table (sort keys %$db) {
		next unless $db->{$table}{params}{non_native};    # Only look at non-native tables.

		# Hack: These two tables are virtual and don't need to be created.  If they were created in earlier versions for
		# the admin course you can use mysql to drop the field version_id manually.
		next if $table eq 'problem_version' or $table eq 'set_version';

		my $database_table_name =
			exists $db->{$table}{params}{tableOverride} ? $db->{$table}{params}{tableOverride} : $table;

		if (!$db->{$table}->tableExists) {
			if ($db->{$table}->can('create_table')) {
				$db->{$table}->create_table;
				push(@messages, "Table '$table' created as '$database_table_name' in database.");
			}
		} else {
			my %fieldStatus;
			my $fields_ok          = 1;
			my @schema_field_names = $db->{$table}->{record}->FIELDS;
			foreach my $field_name (sort @schema_field_names) {
				my $database_field_exists = $db->{$table}->tableFieldExists($field_name);
				#if the field doesn't exist then try to add it...
				if (!$database_field_exists) {
					$fields_ok = 0;
					$fieldStatus{$field_name} = [ONLY_IN_A];
					warn "$field_name from $database_table_name (aka |$table|) is only in schema, "
						. "not in database, so adding it ... ";
					if ($db->{$table}->can("add_column_field")) {
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

	return @messages;
}

################################################################################
# utilities
################################################################################

=head1 UTILITIES

These functions are used by this class's public functions and should not be
called directly.

=over

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

	print $fh <<'EOF';
#!perl

# This file is used to override the global WeBWorK course environment for this course.

EOF

	print $fh <<'EOF';
# Users for whom to label problems with the PG file name (global value typically "professor")
# For users in this list, PG will display the source file name when rendering a problem.
# defaults.config values:
EOF

	if (defined $ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR}) {
		print $fh "# \t", '$pg{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} = [',
			join(", ",
			map { "'" . protectQString($_) . "'" } @{ $ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} }),
			'];', "\n";
	} else {
		print $fh "# \t", '$pg{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} = [ ];', "\n";
	}

	if (defined $options{PRINT_FILE_NAMES_FOR}) {
		print $fh '$pg{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} = [',
			join(", ", map { "'" . protectQString($_) . "'" } @{ $options{PRINT_FILE_NAMES_FOR} }), '];', "\n";
	}
}

sub get_SeedCE
{    # helper subroutine to produce a stripped down seed Course Environment from an arbitrary course environment
	my $ce = shift;
	warn "get_SeedCE needs current Course environment to create seed CE" unless ref($ce);
	my %seedCE     = ();
	my @conf_items = qw( webwork_dir webwork_url pg_dir courseName); # items to transfer. courseName is often overridden
	foreach my $item (@conf_items) {
		$seedCE{$item} = $ce->{$item};
	}
	return (%seedCE);
}
1;
