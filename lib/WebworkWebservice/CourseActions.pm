# Course manipulation functions for webwork webservices
package WebworkWebservice::CourseActions;

use strict;
use warnings;

use Time::HiRes qw/gettimeofday/;
use Date::Format;
use Data::Structure::Util qw(unbless);

use WeBWorK::DB;
use WeBWorK::DB::Utils               qw(initializeUserProblem);
use WeBWorK::Utils                   qw(cryptPassword);
use WeBWorK::Utils::CourseManagement qw(addCourse);
use WeBWorK::Utils::Files            qw(surePathToFile path_is_subdir);
use WeBWorK::ConfigValues            qw(getConfigValues);
use WeBWorK::Debug;

sub createCourse {
	my ($invocant, $self, $params) = @_;

	my $admin_ce = $self->ce;
	my $db       = $self->db;
	my $authz    = $self->authz;

	# Make sure course actions are enabled
	die "Course actions disabled by configuration.\n" unless $admin_ce->{webservices}{enableCourseActions};

	# Only users from the admin course with appropriate permissions are allowed to create a course.
	die "Course creation allowed only for admin course users.\n"
		unless $admin_ce->{courseName} eq $admin_ce->{admin_course_id};

	die "Course ID cannot exceed $admin_ce->{maxCourseIdLength} characters.\n"
		if length($params->{name}) > $admin_ce->{maxCourseIdLength};

	# Bring up a minimal course environment for the new course.
	my $ce = WeBWorK::CourseEnvironment->new({ courseName => $params->{name} });

	# Copy user from admin course.
	# Modified from do_add_course in WeBWorK::ContentGenerator::CourseAdmin.
	my @users;
	for my $userID ($db->listUsers) {
		push @users, [ $db->getUser($userID), $db->getPassword($userID), $db->getPermissionLevel($userID) ]
			if $authz->hasPermissions($userID, 'create_and_delete_courses');
	}

	# Try to actually create the course.
	eval {
		addCourse(
			courseID      => $params->{name},
			ce            => $ce,
			courseOptions => { dbLayoutName => $ce->{dbLayoutName} },
			users         => \@users
		);
		addLog($ce, "New course created: $params->{name}");
		return 1;
	} or die "$@\n";

	return { text => "New course $params->{name} created." };
}

sub listUsers {
	my ($invocant, $self, $params) = @_;
	my $db = $self->db;
	my $ce = $self->ce;

	my @userInfo      = map { unbless($_) } $db->getUsersWhere({ user_id => { not_like => 'set_id:%' } });
	my $numGlobalSets = $db->countGlobalSets;

	for my $user (@userInfo) {
		my $permissionLevel = $db->getPermissionLevel($user->{user_id});
		$user->{permission} = $permissionLevel->{permission};

		$user->{num_user_sets} = $db->countUserSets($user->{user_id}) . '/' . $numGlobalSets;

		my $Key = $db->getKey($user->{user_id});
		$user->{login_status} = $Key && time <= $Key->timestamp + $ce->{sessionTimeout} ? 'active' : 'inactive';
	}

	return {
		ra_out => \@userInfo,
		text   => "Users for course: $ce->{courseName}"
	};
}

sub addUser {
	my ($invocant, $self, $params) = @_;
	my $db = $self->db;
	my $ce = $self->ce;

	# Make sure course actions are enabled
	die "Course actions disabled by configuration.\n" unless $ce->{webservices}{enableCourseActions};

	# Check parameters.
	die "The user_id parameter is required\n" unless $params->{user_id} && $params->{user_id} =~ /\S/;

	my $user_id = $params->{user_id} =~ s/^\s*|\s*$//g;

	my $out = { ra_out => {} };

	my $olduser = $db->getUser($params->{user_id});
	my $permission;
	if ($olduser) {
		if ($olduser->status != $ce->{statuses}{Enrolled}{abbrevs}[0]) {
			# Re-enroll the existing user.
			$olduser->status($ce->{statuses}{Enrolled}{abbrevs}[0]);
			$db->putUser($olduser);
			addLog($ce, "User $params->{user_id} re-enrolled in $ce->{courseName}");

			$permission = $db->getPermissionLevel($params->{user_id});

			$out->{ra_out}{user_added} = \1;
			$out->{text} = "User $params->{user_id} re-enrolled in $ce->{courseName}.";
		} else {
			$out->{text} = "User $params->{user_id} already enrolled in $ce->{courseName}.";
		}
	} else {
		# Add a new user.
		my $ce = $self->ce;

		# student record
		my $enrolled    = $ce->{statuses}->{Enrolled}->{abbrevs}->[0];
		my $new_student = $db->{user}->{record}->new();
		$new_student->user_id($params->{user_id});
		$new_student->first_name($params->{first_name}) if $params->{first_name};
		$new_student->last_name($params->{last_name})   if $params->{last_name};
		$new_student->status($enrolled);
		$new_student->student_id($params->{student_id})       if defined $params->{student_id};
		$new_student->email_address($params->{email_address}) if $params->{email_address};
		$new_student->recitation($params->{recitation})       if defined $params->{recitation};
		$new_student->section($params->{section})             if defined $params->{section};
		$new_student->comment($params->{comment})             if $params->{comment};

		# Password record
		my $cryptedpassword = '';
		if ($params->{password}) {
			$cryptedpassword = cryptPassword($params->{password} =~ s/^\s*|\s*$//gr);
		} elsif ($new_student->student_id) {
			$cryptedpassword = cryptPassword($new_student->student_id);
		}
		my $password = $db->newPassword(user_id => $params->{user_id});
		$password->password($cryptedpassword);

		# Permission record
		$permission = $params->{permission} // 0;
		if (defined($ce->{userRoles}{$permission})) {
			$permission = $db->newPermissionLevel(
				user_id    => $params->{user_id},
				permission => $ce->{userRoles}{$permission}
			);
		} else {
			$permission = $db->newPermissionLevel(
				user_id    => $params->{user_id},
				permission => $ce->{userRoles}{student}
			);
		}

		# Commit changes to db
		$db->addUser($new_student);
		$db->addPassword($password);
		eval { $db->addPermissionLevel($permission); };

		$out->{ra_out}{user_added} = \1;
		$out->{text} = "User $params->{user_id} added to $ce->{courseName}.";
		addLog($ce, "User $params->{user_id} added to $ce->{courseName}");
	}

	# Assign all visible sets to the user if requested.
	if ($params->{assign_visible_sets}) {
		$out->{ra_out}{sets_assigned} = assignVisibleSets($db, $params->{user_id}) ? \0 : \1;
		$out->{text} .= " Visible sets assigned to $params->{user_id}.";
	}

	return $out;
}

sub dropUser {
	my ($invocant, $self, $params) = @_;
	my $db = $self->db;
	my $ce = $self->ce;

	# Make sure course actions are enabled
	die "Course actions disabled by configuration.\n" unless $ce->{webservices}{enableCourseActions};

	# Check parameters.
	die "The user_id parameter is required\n" unless $params->{user_id} && $params->{user_id} =~ /\S/;

	# Mark user as dropped
	my $user = $db->getUser($params->{user_id});

	die "Could not find $params->{user_id} in $ce->{courseName}\n" unless $user;

	$user->status($ce->{statuses}{Drop}{abbrevs}[0]);
	$db->putUser($user);
	addLog($ce, "User $params->{user_id} dropped from $ce->{courseName}");
	return { text => "User $params->{user_id} dropped from $ce->{courseName}" };
}

sub deleteUser {
	my ($invocant, $self, $params) = @_;
	my $db = $self->db;
	my $ce = $self->ce;

	# Make sure course actions are enabled
	die "Course actions disabled by configuration.\n" unless $ce->{webservices}{enableCourseActions};

	die "The user_id parameter is required\n" unless $params->{user_id} && $params->{user_id} =~ /\S/;

	my $User = $db->getUser($params->{user_id});
	die "Record for user $params->{user_id} not found\n" unless $User;

	die q{You can't delete yourself from the course.} if ($params->{user_id} eq $params->{user});

	my $del = $db->deleteUser($params->{user_id});
	die "User $params->{user_id} could not be deleted\n" unless $del;

	addLog($ce, "User $params->{user_id} deleted from $ce->{courseName}");
	return { text => "User $params->{user_id} deleted from $ce->{courseName}" };
}

sub editUser {
	my ($invocant, $self, $params) = @_;
	my $db = $self->db;
	my $ce = $self->ce;

	# Make sure course actions are enabled
	die "Course actions disabled by configuration.\n" unless $ce->{webservices}{enableCourseActions};

	die "The user_id parameter is required\n" unless ($params->{user_id} && $params->{user_id} =~ /\S/);

	my $User = $db->getUser($params->{user_id});
	die "User $params->{user_id} not found.\n" unless ($User);

	# It has already been checked that the user has permission to modify user data.  Get the permission level here, so
	# that it can be verified that the permission level of the user being edited is less than or equal to that of the
	# one doing the editing.
	my $callerPermission = $db->getPermissionLevel($params->{user});
	my $permissionLevel  = $db->getPermissionLevel($params->{user_id});

	die "You do not have permission to edit $params->{user_id}\n"
		unless $callerPermission && $permissionLevel && $callerPermission->permission >= $permissionLevel->permission;

	my $out = { text => '', ra_out => {} };

	for my $field ($User->NONKEYFIELDS()) {
		$User->$field($params->{$field}) if defined $params->{$field};
	}
	$db->putUser($User);
	$out->{text} = 'User data updated.';
	$out->{ra_out}{user} = unbless($User);

	if (defined $params->{permission} && $params->{permission} =~ /\d*/) {
		if ($params->{user_id} eq $params->{user}) {
			$out->{text} .= ' You cannot change your own permissions.';
			$out->{ra_out}{permission_changed} = \0;
		} else {
			$permissionLevel->permission($params->{permission});
			$db->putPermissionLevel($permissionLevel);
			$out->{text} .= ' Permissions updated.';
			$out->{ra_out}{user}{permission} = $permissionLevel->{permission};
		}
	} else {
		$out->{ra_out}{permission_changed} = \0;
	}

	$out->{ra_out}{password_changed} = \0;

	# If the new_password param is set and not equal to the empty string and not all spaces,
	# then change the password or set the password if it is not set.
	if (defined $params->{new_password} && $params->{new_password} =~ /\S/) {
		my $password   = cryptPassword($params->{new_password} =~ s/^\s*|\s*$//gr);
		my $dbPassword = $db->getPassword($params->{user_id});
		if ($dbPassword) {
			$dbPassword->password($password);
			$db->putPassword($dbPassword);
		} else {
			$dbPassword = $db->newPassword(user_id => $params->{user_id}, password => $password);
			$db->addPassword($dbPassword);
		}
		$out->{text} .= ' Password changed.';
		$out->{ra_out}{password_changed} = \1;
	}

	addLog($ce, "User edited: $out->{text}");
	return $out;
}

sub changeUserPassword {
	my ($invocant, $self, $params) = @_;
	my $db = $self->db;
	my $ce = $self->ce;

	# Make sure course actions are enabled
	die "Course actions disabled by configuration.\n" unless $ce->{webservices}{enableCourseActions};

	# Check parameters.
	die "The user_id parameter is required\n" unless ($params->{user_id} && $params->{user_id} =~ /\S/);
	die "The new_password parameter is required\n"
		unless defined $params->{new_password} && $params->{new_password} =~ /\S/;

	my $User = $db->getUser($params->{user_id});
	die "User $params->{user_id} not found.\n" unless $User;

	# It has already been checked that the user has permission to modify user data.  Get the permission level here, so
	# that it can be verified that the permission level of the user being edited is less than or equal to that of the
	# one doing the editing.
	my $callerPermission = $db->getPermissionLevel($params->{user});
	my $permissionLevel  = $db->getPermissionLevel($params->{user_id});
	die "You do not have permission to change the password for $params->{user_id}\n"
		unless ($callerPermission
			&& $permissionLevel
			&& $callerPermission->{permission} >= $permissionLevel->{permission});

	my $password = cryptPassword($params->{new_password} =~ s/^\s*|\s*$//gr);

	# Change the password or set the password if it is not set.
	my $dbPassword = $db->getPassword($User->user_id);
	if ($dbPassword) {
		$dbPassword->password($password);
		$db->putPassword($dbPassword);
	} else {
		$dbPassword = $db->newPassword(user_id => $params->{user_id}, password => $password);
		$db->addPassword($dbPassword);
	}

	addLog($ce, "New password set for $params->{user_id}");
	return { text => "New password set for $params->{user_id}" };
}

sub addLog {
	my ($ce, $msg) = @_;
	return unless $ce->{webservices}{enableCourseActionsLog};

	my ($sec, $msec) = gettimeofday;
	my $date = time2str("%a %b %d %H:%M:%S.$msec %Y", $sec);

	if (open my $f, '>>', $ce->{webservices}{courseActionsLogfile}) {
		print $f "[$date] $msg\n";
		close $f;
	} else {
		debug(qq{Error: Unable to open web services log file "$ce->{webservices}{courseActionsLogfile}": $!});
	}
	return;
}

sub assignVisibleSets {
	my ($db, $userID) = @_;
	my @globalSetIDs = $db->listGlobalSets;
	my @GlobalSets   = $db->getGlobalSets(@globalSetIDs);

	my $i = -1;
	for my $GlobalSet (@GlobalSets) {
		$i++;
		if (not defined $GlobalSet) {
			debug("Record not found for global set $globalSetIDs[$i]");
			next;
		}
		if (!$GlobalSet->visible) {
			next;
		}

		# assign set to user
		my $setID   = $GlobalSet->set_id;
		my $UserSet = $db->newUserSet;
		$UserSet->user_id($userID);
		$UserSet->set_id($setID);
		my @results;
		my $set_assigned = 0;
		eval { $db->addUserSet($UserSet) };

		return 0 if $@ && !WeBWorK::DB::Ex::RecordExists->caught;

		# assign problem
		my @GlobalProblems = grep { defined $_ } $db->getAllGlobalProblems($setID);
		for my $GlobalProblem (@GlobalProblems) {
			my $seed        = int(rand(2423)) + 36;
			my $UserProblem = $db->newUserProblem;
			$UserProblem->user_id($userID);
			$UserProblem->set_id($GlobalProblem->set_id);
			$UserProblem->problem_id($GlobalProblem->problem_id);
			initializeUserProblem($UserProblem, $seed);
			eval { $db->addUserProblem($UserProblem) };
			return 0 if $@ && !WeBWorK::DB::Ex::RecordExists->caught;
		}
	}

	return 0;
}

sub getCourseSettings {
	my ($invocant, $self, $params) = @_;
	my $ce           = $self->ce;
	my $ConfigValues = getConfigValues($ce);

	for my $oneConfig (@$ConfigValues) {
		for my $hash (@$oneConfig) {
			next unless ref $hash eq 'HASH';
			my $value;
			if (defined $hash->{var}) {
				my @keys = $hash->{var} =~ m/([^{}]+)/g;
				next unless @keys;

				$value = $ce;
				for (@keys) { $value = $value->{$_}; }
			} else {
				$value = $self->db->getSettingValue($self->{setting});
			}
			$hash->{value} = $value if defined $value;
		}
	}

	push(
		@$ConfigValues,
		[
			'tz_abbr',
			DateTime::TimeZone->new(name => $ce->{siteDefaults}->{timezone})->short_name_for_datetime(DateTime->now)
		]
	);

	return {
		ra_out => $ConfigValues,
		text   => 'Successfully found the course settings'
	};
}

sub updateSetting {
	my ($invocant, $self, $params) = @_;
	my $ce = $self->ce;

	# FIXME: There is no check in this method that the var and value passed in are valid.
	my $setVar   = $params->{var};
	my $setValue = $params->{value};

	my $filename = "$ce->{courseDirs}{root}/simple.conf";

	my $fileoutput = "#!perl
# This file is automatically generated by WeBWorK's web-based
# configuration module.  Do not make changes directly to this
# file.  It will be overwritten the next time configuration
# changes are saved.\n\n";

	# Read in the file
	open(my $DAT, '<', $filename)
		or die "Unable to read $filename. "
		. "Ensure that the file exists and the server has write permission for this file.\n";
	my @raw_data = <$DAT>;
	close($DAT);

	my $varFound = 0;

	for my $line (@raw_data) {
		chomp $line;
		if ($line =~ /^\$/) {
			my @tmp = split(/\$/, $line);
			my ($var, $value) = split(/\s+=\s+/, $tmp[1]);
			if ($var eq $setVar) {
				$fileoutput .= "\$$var = $setValue;\n";
				$varFound = 1;
			} else {
				# The value includes the semicolon that hopefully was in the file.
				$fileoutput .= "\$$var = $value\n";
			}
		}
	}

	if (!$varFound) {
		$fileoutput .= "\$$setVar = $setValue;\n";
	}

	open(my $OUTPUTFILE, '>', $filename)
		or die "Unable to write to $filename. Ensure that the server has write permission for this file.\n";
	print $OUTPUTFILE $fileoutput;
	close $OUTPUTFILE;

	return { text => 'Successfully updated course setting' };
}

# This saves a file to the course's templates directory.
sub saveFile {
	my ($invocant, $self, $params) = @_;

	my $c  = $self->c;
	my $ce = $self->ce;

	my $outputFilePath = $params->{outputFilePath};

	my $writeFileErrors;
	if ($outputFilePath && $outputFilePath =~ /\S/) {
		return {
			ra_out => 0,
			text   => $c->maketext(
				'File not saved. The file "[_1]" is not contained in the templates directory!',
				$outputFilePath
			)
			}
			unless path_is_subdir($outputFilePath, $ce->{courseDirs}{templates}, 1);

		$outputFilePath = "$ce->{courseDirs}{templates}/$outputFilePath" unless $outputFilePath =~ m|^/|;

		# Make sure any missing directories are created.
		surePathToFile($ce->{courseDirs}{templates}, $outputFilePath);

		# Save the file.
		open(my $outfile, '>:encoding(UTF-8)', $outputFilePath)
			or return {
				ra_out => 0,
				text   => $c->maketext('File not saved. Failed to open "[_1]" for writing.', $outputFilePath)
			};
		print $outfile $params->{fileContents};
		close $outfile;
	}

	return {
		ra_out => 1,
		text   => $c->maketext('Saved to file "[_1]"', $outputFilePath =~ s/$ce->{courseDirs}{templates}/[TMPL]/r)
	};
}

sub getCurrentServerTime {
	my ($invocant, $self, $params) = @_;

	return {
		ra_out => { currentServerTime => $self->c->submitTime },
		text   => 'Current server time'
	};
}

1;
