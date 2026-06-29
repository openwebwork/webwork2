package WeBWorK::ContentGenerator::API::CourseActions;
use Mojo::Base 'WeBWorK::ContentGenerator::API', -signatures;

use Time::HiRes qw(gettimeofday);
use Date::Format;
use Data::Structure::Util qw(unbless);
use Mojo::JSON            qw(false true);

use WeBWorK::DB;
use WeBWorK::DB::Utils               qw(initializeUserProblem);
use WeBWorK::Utils                   qw(cryptPassword);
use WeBWorK::Utils::CourseManagement qw(addCourse);
use WeBWorK::Utils::Files            qw(surePathToFile path_is_subdir);
use WeBWorK::ConfigValues            qw(getConfigValues);
use WeBWorK::Debug                   qw(debug);

our @apiCalls = qw(
	createCourse
	listUsers
	addUser
	dropUser
	deleteUser
	editUser
	changeUserPassword
	getCourseSettings
	updateSetting
	saveFile
	getCurrentServerTime
);

sub apiCall ($invocant, $command) {
	return (grep { $_ eq $command } @apiCalls) && $invocant->can($command);
}

sub createCourse ($c) {
	return $c->renderError('You do not have permission for the createCourse API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'create_and_delete_courses');

	my $admin_ce = $c->ce;
	my $db       = $c->db;
	my $authz    = $c->authz;

	return $c->renderError('Course actions disabled by configuration.')
		unless $admin_ce->{webservices}{enableCourseActions};

	return $c->renderError('Course creation allowed only for admin course users.')
		unless $admin_ce->{courseName} eq $admin_ce->{admin_course_id};

	return $c->renderError("Course ID cannot exceed $admin_ce->{maxCourseIdLength} characters.")
		if length($c->req->param('name')) > $admin_ce->{maxCourseIdLength};

	# Bring up a minimal course environment for the new course.
	my $ce = WeBWorK::CourseEnvironment->new({ courseName => $c->req->param('name') });

	# Copy users from the admin course.
	my @users;
	for my $userID ($db->listUsers) {
		push @users, [ $db->getUser($userID), $db->getPassword($userID), $db->getPermissionLevel($userID) ]
			if $authz->hasPermissions($userID, 'create_and_delete_courses');
	}

	# Try to actually create the course.
	eval {
		addCourse(
			courseID => $c->req->param('name'),
			ce       => $ce,
			users    => \@users
		);
		addLog($ce, 'New course created: ' . $c->req->param('name'));
	};
	return $c->renderError("Unable to create course: $@") if $@;

	return $c->render(json => { message => 'New course ' . $c->req->param('name') . ' created.' });
}

sub listUsers ($c) {
	return $c->renderError('You do not have permission for the listUsers API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	my $db = $c->db;
	my $ce = $c->ce;

	my @userInfo      = map { unbless($_) } $db->getUsersWhere({ user_id => { not_like => 'set_id:%' } });
	my $numGlobalSets = $db->countGlobalSets;

	for my $user (@userInfo) {
		my $permissionLevel = $db->getPermissionLevel($user->{user_id});
		$user->{permission} = $permissionLevel->{permission};

		$user->{num_user_sets} = $db->countUserSets($user->{user_id}) . '/' . $numGlobalSets;

		my $Key = $db->getKey($user->{user_id});
		$user->{login_status} = $Key && time <= $Key->timestamp + $ce->{sessionTimeout} ? 'active' : 'inactive';
	}

	return $c->render(json => \@userInfo);
}

sub addUser ($c) {
	return $c->renderError('You do not have permission for the addUser API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data');

	my $db = $c->db;
	my $ce = $c->ce;

	return $c->renderError('Course actions disabled by configuration.')
		unless $ce->{webservices}{enableCourseActions};

	return $c->renderError('The user_id parameter is required.')
		unless $c->req->param('user_id') && $c->req->param('user_id') =~ /\S/;

	my $user_id = $c->req->param('user_id') =~ s/^\s*|\s*$//gr;

	my $response = {};

	my $olduser = $db->getUser($c->req->param('user_id'));
	my $permission;
	if ($olduser) {
		if ($olduser->status ne $ce->{statuses}{Enrolled}{abbrevs}[0]) {
			# Re-enroll the existing user.
			$olduser->status($ce->{statuses}{Enrolled}{abbrevs}[0]);
			$db->putUser($olduser);
			addLog($ce, 'User ' . $c->req->param('user_id') . " re-enrolled in $ce->{courseName}");

			$permission = $db->getPermissionLevel($c->req->param('user_id'));

			$response->{user_added} = true;
			$response->{message}    = 'User ' . $c->req->param('user_id') . " re-enrolled in $ce->{courseName}.";
		} else {
			$response->{message} = 'User ' . $c->req->param('user_id') . " already enrolled in $ce->{courseName}.";
		}
	} else {
		# Add a new user.
		my $ce = $c->ce;

		my $new_student =
			$db->newUser(user_id => $c->req->param('user_id'), status => $ce->{statuses}{Enrolled}{abbrevs}[0]);
		$new_student->first_name($c->req->param('first_name'))       if $c->req->param('first_name');
		$new_student->last_name($c->req->param('last_name'))         if $c->req->param('last_name');
		$new_student->student_id($c->req->param('student_id'))       if defined $c->req->param('student_id');
		$new_student->email_address($c->req->param('email_address')) if $c->req->param('email_address');
		$new_student->recitation($c->req->param('recitation'))       if defined $c->req->param('recitation');
		$new_student->section($c->req->param('section'))             if defined $c->req->param('section');
		$new_student->comment($c->req->param('comment'))             if $c->req->param('comment');

		my $cryptedpassword = '';
		if ($c->req->param('password')) {
			$cryptedpassword = cryptPassword($c->req->param('password') =~ s/^\s*|\s*$//gr);
		} elsif ($new_student->student_id) {
			$cryptedpassword = cryptPassword($new_student->student_id);
		}
		my $password = $db->newPassword(user_id => $c->req->param('user_id'));
		$password->password($cryptedpassword);

		$permission = $c->req->param('permission') // 0;
		if (defined($ce->{userRoles}{$permission})) {
			$permission = $db->newPermissionLevel(
				user_id    => $c->req->param('user_id'),
				permission => $ce->{userRoles}{$permission}
			);
		} else {
			$permission = $db->newPermissionLevel(
				user_id    => $c->req->param('user_id'),
				permission => $ce->{userRoles}{student}
			);
		}

		# Commit changes to db
		$db->addUser($new_student);
		$db->addPassword($password);
		eval { $db->addPermissionLevel($permission); };

		$response->{user_added} = true;
		$response->{message}    = 'User ' . $c->req->param('user_id') . " added to $ce->{courseName}.";
		addLog($ce, 'User ' . $c->req->param('user_id') . " added to $ce->{courseName}");
	}

	# Assign all visible sets to the user if requested.
	if ($c->req->param('assign_visible_sets')) {
		$response->{sets_assigned} = assignVisibleSets($db, $c->req->param('user_id')) ? false : true;
		$response->{message} .= ' Visible sets assigned to ' . $c->req->param('user_id') . '.';
	}

	return $c->render(json => $response);
}

sub dropUser ($c) {
	return $c->renderError('You do not have permission for the dropUser API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data');

	my $db = $c->db;
	my $ce = $c->ce;

	return $c->renderError('Course actions disabled by configuration.') unless $ce->{webservices}{enableCourseActions};

	return $c->renderError('The user_id parameter is required.')
		unless $c->req->param('user_id') && $c->req->param('user_id') =~ /\S/;

	my $user = $db->getUser($c->req->param('user_id'));
	return $c->renderError('Could not find ' . $c->req->param('user_id') . " in $ce->{courseName}.")
		unless $user;

	$user->status($ce->{statuses}{Drop}{abbrevs}[0]);
	$db->putUser($user);
	addLog($ce, 'User ' . $c->req->param('user_id') . " dropped from $ce->{courseName}");

	return $c->render(json => { message => 'User ' . $c->req->param('user_id') . " dropped from $ce->{courseName}" });
}

sub deleteUser ($c) {
	return $c->renderError('You do not have permission for the deleteUser API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data');

	my $db = $c->db;
	my $ce = $c->ce;

	return $c->renderError('Course actions disabled by configuration.') unless $ce->{webservices}{enableCourseActions};

	return $c->renderError('The user_id parameter is required.')
		unless $c->req->param('user_id') && $c->req->param('user_id') =~ /\S/;

	return $c->renderError('Could not find ' . $c->req->param('user_id') . " in $ce->{courseName}.")
		unless $db->getUser($c->req->param('user_id'));

	return $c->renderError('You cannot delete yourself from the course.')
		if $c->req->param('user_id') eq $c->req->param('user');

	my $del = $db->deleteUser($c->req->param('user_id'));
	return $c->renderError('User ' . $c->req->param('user_id') . ' could not be deleted.') unless $del;

	addLog($ce, 'User ' . $c->req->param('user_id') . " deleted from $ce->{courseName}");
	return $c->render(json => { message => 'User ' . $c->req->param('user_id') . " deleted from $ce->{courseName}" });
}

sub editUser ($c) {
	return $c->renderError('You do not have permission for the editUser API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data');

	my $db = $c->db;
	my $ce = $c->ce;

	return $c->renderError('Course actions disabled by configuration.') unless $ce->{webservices}{enableCourseActions};

	return $c->renderError('The user_id parameter is required.')
		unless $c->req->param('user_id') && $c->req->param('user_id') =~ /\S/;

	my $user = $db->getUser($c->req->param('user_id'));
	return $c->renderError('User ' . $c->req->param('user_id') . ' not found.') unless $user;

	# Get the permission level, so that it can be verified that the permission level of the
	# user being edited is less than or equal to that of the one doing the editing.
	my $callerPermission = $db->getPermissionLevel($c->req->param('user'));
	my $permissionLevel  = $db->getPermissionLevel($c->req->param('user_id'));

	return $c->renderError('You do not have permission to edit ' . $c->req->param('user_id'))
		unless $callerPermission && $permissionLevel && $callerPermission->permission >= $permissionLevel->permission;

	my $response = {};

	for my $field ($user->NONKEYFIELDS()) {
		$user->$field($c->req->param($field)) if defined $c->req->param($field);
	}
	$db->putUser($user);
	$response->{message} = 'User data updated.';
	$response->{user}    = unbless($user);

	if (defined $c->req->param('permission') && $c->req->param('permission') =~ /\d*/) {
		if ($c->req->param('user_id') eq $c->req->param('user')) {
			$response->{message} .= ' You cannot change your own permissions.';
			$response->{permission_changed} = false;
		} else {
			$permissionLevel->permission($c->req->param('permission'));
			$db->putPermissionLevel($permissionLevel);
			$response->{message} .= ' Permissions updated.';
			$response->{user}{permission} = $permissionLevel->{permission};
		}
	} else {
		$response->{permission_changed} = false;
	}

	$response->{password_changed} = false;

	# If the new_password parameter is set and not equal to the empty string and not all spaces,
	# then change the password or set the password if it is not set.
	if (defined $c->req->param('new_password') && $c->req->param('new_password') =~ /\S/) {
		my $password   = cryptPassword($c->req->param('new_password') =~ s/^\s*|\s*$//gr);
		my $dbPassword = $db->getPassword($c->req->param('user_id'));
		if ($dbPassword) {
			$dbPassword->password($password);
			$db->putPassword($dbPassword);
		} else {
			$dbPassword = $db->newPassword(user_id => $c->req->param('user_id'), password => $password);
			$db->addPassword($dbPassword);
		}
		$response->{message} .= ' Password changed.';
		$response->{password_changed} = true;
	}

	addLog($ce, "User edited: $response->{message}");
	return $c->render(json => $response);
}

sub changeUserPassword ($c) {
	return $c->renderError('You do not have permission for the changeUserPassword API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data');

	my $db = $c->db;
	my $ce = $c->ce;

	return $c->renderError('Course actions disabled by configuration.') unless $ce->{webservices}{enableCourseActions};

	return $c->renderError('The user_id parameter is required.')
		unless $c->req->param('user_id') && $c->req->param('user_id') =~ /\S/;
	return $c->renderError('The new_password parameter is required.')
		unless $c->req->param('new_password') && $c->req->param('new_password') =~ /\S/;

	my $user = $db->getUser($c->req->param('user_id'));
	return $c->renderError('User ' . $c->req->param('user_id') . ' not found.') unless $user;

	# Get the permission level, so that it can be verified that the permission level of the user being edited is less
	# than or equal to that of the one doing the editing.
	my $callerPermission = $db->getPermissionLevel($c->req->param('user'));
	my $permissionLevel  = $db->getPermissionLevel($c->req->param('user_id'));
	return $c->renderError('You do not have permission to change the password for ' . $c->req->param('user_id'))
		unless $callerPermission
		&& $permissionLevel
		&& $callerPermission->{permission} >= $permissionLevel->{permission};

	my $password = cryptPassword($c->req->param('new_password') =~ s/^\s*|\s*$//gr);

	my $dbPassword = $db->getPassword($user->user_id);
	if ($dbPassword) {
		$dbPassword->password($password);
		$db->putPassword($dbPassword);
	} else {
		$dbPassword = $db->newPassword(user_id => $c->req->param('user_id'), password => $password);
		$db->addPassword($dbPassword);
	}

	addLog($ce, 'New password set for ' . $c->req->param('user_id'));
	return $c->render(json => { message => 'New password set for ' . $c->req->param('user_id') });
}

sub addLog ($ce, $msg) {
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

		my $setID   = $GlobalSet->set_id;
		my $UserSet = $db->newUserSet;
		$UserSet->user_id($userID);
		$UserSet->set_id($setID);
		my @results;
		my $set_assigned = 0;
		eval { $db->addUserSet($UserSet) };

		return 0 if $@ && !WeBWorK::DB::Ex::RecordExists->caught;

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

sub getCourseSettings ($c) {
	return $c->renderError('You do not have permission for the getCourseSettings API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	my $ce           = $c->ce;
	my $ConfigValues = getConfigValues($ce);

	for my $oneConfig (@$ConfigValues) {
		for my $hash (@$oneConfig) {
			next unless ref $hash eq 'HASH';
			my $value;
			if ($hash->{type} eq 'setting') {
				$value = $c->db->getSettingValue($hash->{var});
			} elsif (defined $hash->{var}) {
				my @keys = $hash->{var} =~ m/([^{}]+)/g;
				next unless @keys;

				$value = $ce;
				for (@keys) { $value = $value->{$_}; }
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

	return $c->render(json => $ConfigValues);
}

sub updateSetting ($c) {
	return $c->renderError('You do not have permission for the updateSetting API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'manage_course_files');

	my $ce = $c->ce;

	# FIXME: There is no check in this method that the var and value passed in are valid.
	my $setVar   = $c->req->param('var');
	my $setValue = $c->req->param('value');

	my $filename = "$ce->{courseDirs}{root}/simple.conf";

	my $fileoutput = "#!perl
# This file is automatically generated by WeBWorK's web-based
# configuration module.  Do not make changes directly to this
# file.  It will be overwritten the next time configuration
# changes are saved.\n\n";

	# Read in the file
	open(my $DAT, '<', $filename)
		or return $c->renderError("Unable to read $filename. "
			. "Ensure that the file exists and the server has write permission for this file.");
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

	$fileoutput .= "\$$setVar = $setValue;\n" unless $varFound;

	open(my $OUTPUTFILE, '>', $filename)
		or return $c->renderError(
			"Unable to write to $filename. Ensure that the server has write permission for this file.");
	print $OUTPUTFILE $fileoutput;
	close $OUTPUTFILE;

	return $c->render(json => { message => 'Successfully updated course setting' });
}

# This saves a file to the course's templates directory.
sub saveFile ($c) {
	return $c->renderError('You do not have permission for the saveFile API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_problem_sets');

	my $ce = $c->ce;

	my $outputFilePath = $c->req->param('outputFilePath');

	if ($outputFilePath && $outputFilePath =~ /\S/) {
		return $c->renderError($c->maketext(
			'File not saved. The file "[_1]" is not contained in the templates directory!',
			$outputFilePath
		))
			unless path_is_subdir($outputFilePath, $ce->{courseDirs}{templates}, 1);

		$outputFilePath = "$ce->{courseDirs}{templates}/$outputFilePath" unless $outputFilePath =~ m|^/|;

		# Make sure any missing directories are created.
		surePathToFile($ce->{courseDirs}{templates}, $outputFilePath);

		# Save the file.
		open(my $outfile, '>:encoding(UTF-8)', $outputFilePath)
			or
			return $c->renderError($c->maketext('File not saved. Failed to open "[_1]" for writing.', $outputFilePath));
		print $outfile $c->req->param('fileContents');
		close $outfile;
	}

	return $c->render(
		json => {
			message =>
				$c->maketext('Saved to file "[_1]"', $outputFilePath =~ s/$ce->{courseDirs}{templates}/[TMPL]/r)
		}
	);
}

# Note that no permission is required to get the current server time. The user only needs to be authenticated.
sub getCurrentServerTime ($c) {
	return $c->render(json => { currentServerTime => $c->submitTime });
}

1;
