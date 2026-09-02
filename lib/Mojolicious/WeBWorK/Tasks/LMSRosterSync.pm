package Mojolicious::WeBWorK::Tasks::LMSRosterSync;
use Mojo::Base 'Minion::Job', -signatures, -async_await;

use Mojo::UserAgent;
use Mojo::Date;

use WeBWorK::Authen::LTIAdvantage::SubmitGrade;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Utils::DateTime   qw(formatDateTime);
use WeBWorK::Utils::Instructor qw(assignSetsToUsers);

# Synchronize requested set dates to the LMS.
sub run ($job) {
	# Establish a lock guard that only allows 1 job at a time (technically more than one could run at a time if a job
	# takes more than an hour to complete).  As soon as a job completes (or fails) the lock is released and a new job
	# can start.  New jobs retry every minute until they can acquire their own lock.
	return $job->retry({ delay => 60 }) unless my $guard = $job->minion->guard('lms_roster_sync', 3600);

	# Minion does not support asynchronous jobs with notification of job completion, and so the Mojolicious::Promise
	# wait method must be used. The synchronizeSetDates method is used so that the async/await syntax can be used
	# instead of using the wait method on each method that needs to be awaited which would be tedious.  So the wait
	# method only needs to be used once here.
	$job->synchronizeRoster->wait();

	return;
}

async sub synchronizeRoster ($job) {
	my $courseID = $job->info->{notes}{courseID};
	return $job->fail('The course id was not passed when this job was enqueued.') unless $courseID;

	my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $courseID }) };
	return $job->fail('Could not construct course environment.') unless $ce;

	$job->{language_handle} = WeBWorK::Localize::getLoc($ce->{language} || 'en');

	return $job->fail($job->maketext('This course is not configured to import users from the LMS via LTI.'))
		if !$ce->{LTIVersion}
		|| $ce->{LTIVersion} ne 'v1p3'
		|| !$ce->{LTI}{v1p3}{preferred_source_of_username};

	my $db = WeBWorK::DB->new($ce);
	return $job->fail($job->maketext('Could not obtain database connection.')) unless $db;

	my $namesRolesServiceURL = $db->getSettingValue('LTINamesRolesServiceURL');
	return $job->fail($job->maketext('The LTI names/roles service URL is not available.')) unless $namesRolesServiceURL;

	my $accessToken =
		await WeBWorK::Authen::LTIAdvantage::SubmitGrade->new(({ ce => $ce, db => $db, app => $job->app }, 1))
		->get_access_token;
	return $job->fail($job->maketext('Unable to obtain access token.')) unless $accessToken;

	my @namesRoles;

	while (1) {
		my $namesRolesServiceRequest = await Mojo::UserAgent->new->get_p($namesRolesServiceURL,
			{ Authorization => "$accessToken->{token_type} $accessToken->{access_token}" })->catch(sub ($err) {
			return $err;
			});
		return $job->fail(
			$job->maketext("Error communicating with the names and roles service URL: $namesRolesServiceRequest\n"))
			unless ref $namesRolesServiceRequest;

		my $namesRolesServiceResult = $namesRolesServiceRequest->result;
		if ($namesRolesServiceResult->is_success) {
			my $namesRoles = $namesRolesServiceResult->json->{members};
			return $job->fail($job->maketext('Invalid data received from the LMS.')) unless ref $namesRoles eq 'ARRAY';
			push(@namesRoles, @$namesRoles);

			if ($namesRolesServiceResult->headers->link
				&& $namesRolesServiceResult->headers->link =~ /<([^>]*)>;\s*rel="next"/)
			{
				$namesRolesServiceURL = $1;
			} else {
				last;
			}
		} else {
			return $job->fail($job->maketext(
				'There was an error obtaining the list of users from the LMS: [_1]',
				$namesRolesServiceResult->message
			));
		}
	}

	my (@messages, @addedUsers, @userAchievementRecordsToAdd, @globalAchievementRecordsToAdd, %usersInLMSCourse);
	my $updatedUsers = 0;

	my %users = map { $_->user_id => $_ } $db->getUsersWhere({ user_id => { not_like => 'set_id:%' } });

	my @achievements = $db->getAchievementsWhere({ enabled => 1 }, ['achievement_id']);

	my $preferredSourceOfUsername = $ce->{LTI}{v1p3}{namesroles_service_preferred_source_of_username}
		|| $ce->{LTI}{v1p3}{preferred_source_of_username};
	my $fallbackPasswordSource = $ce->{LTI}{v1p3}{namesroles_service_fallback_source_of_username}
		|| $ce->{LTI}{v1p3}{fallback_source_of_username};
	my $preferredSourceOfStudentId = $ce->{LTI}{v1p3}{namesroles_service_preferred_source_of_student_id}
		|| $ce->{LTI}{v1p3}{preferred_source_of_student_id};

	for my $user (@namesRoles) {
		my ($userIdSource, $typeOfSource) = ('', '');
		my $userId = $user->{$preferredSourceOfUsername};
		if (defined $userId) {
			$userIdSource = $preferredSourceOfUsername;
			$typeOfSource =
				"$userIdSource which was "
				. ($ce->{LTI}{v1p3}{namesroles_service_preferred_source_of_username}
					? 'namesroles_service_preferred_source_of_username'
					: 'preferred_source_of_username');
		} elsif ($fallbackPasswordSource && !defined $userId && defined $user->{$fallbackPasswordSource}) {
			$userIdSource = $fallbackPasswordSource;
			$typeOfSource =
				"$userIdSource which was"
				. ($ce->{LTI}{v1p3}{namesroles_service_fallback_source_of_username}
					? 'namesroles_service_fallback_source_of_username'
					: 'fallback_source_of_username');
			$userId = $user->{$fallbackPasswordSource};
		}

		unless (defined $userId) {
			$job->app->log->info("\n=====================================\n"
					. "Unable to determine a webwork user id for LMS user:\n"
					. $job->app->dumper($user)
					. "\n=====================================")
				if $ce->{debug_lti_parameters};
			next;
		}

		$userId =~ s/@.*$//   if $userIdSource eq 'email' && $ce->{LTI}{v1p3}{strip_domain_from_email};
		$userId = lc($userId) if $ce->{LTI}{v1p3}{lowercase_username};

		my $studentId = $preferredSourceOfStudentId ? ($user->{$preferredSourceOfStudentId} // '') : '';

		if ($ce->{debug_lti_parameters}) {
			$job->app->log->info("\n=========== USER SUMMARY ============\n"
					. "----------- LMS USER DATA -----------\n"
					. $job->app->dumper($user)
					. "-------------------------------------\n"
					. "User id is |$userId| (obtained from $typeOfSource)\n"
					. "User email address is |$user->{email}|\n"
					. "Student id is |$studentId|\n"
					. "=====================================");
		}

		$usersInLMSCourse{$userId} = 1;

		# Note that the only reliably obtained roles here are the membership roles. The issue is that these roles
		# are allowed to be abbreviated (i.e., the http://purl.imsglobal.org/... part may be entirely omitted
		# according to the specification). Moodle does this, but Canvas does not. However, both seem to add a prefix
		# for non-membership roles. Also, "institution" roles are not sent, so it is not even possible to honor the
		# $ce->{LTI}{v1p3}{AllowInstitutionRoles} setting.
		my @LTIroles = map {s|^http://purl.imsglobal.org/vocab/lis/v2/membership#||r} @{ $user->{roles} };

		$job->app->log->info("The LTI roles defined for $userId are: \n-- " . join("\n-- ", @LTIroles))
			if $ce->{debug_lti_parameters};

		if (!defined($ce->{userRoles}{ $ce->{LTI}{v1p3}{LMSrolesToWeBWorKroles}{ $LTIroles[0] } })) {
			$job->app->log->info("Skipping $userId. Cannot find a WeBWorK role that corresponds to the "
					. "LMS role of $LTIroles[0] for this user.")
				if $ce->{debug_lti_parameters};
			next;
		}

		my $permissionLevel = $ce->{userRoles}{ $ce->{LTI}{v1p3}{LMSrolesToWeBWorKroles}{ $LTIroles[0] } };
		if (@LTIroles > 1) {
			for (@LTIroles[ 1 .. $#LTIroles ]) {
				my $wwRole = $ce->{LTI}{v1p3}{LMSrolesToWeBWorKroles}{$_};
				next unless defined $wwRole;
				$permissionLevel = $ce->{userRoles}{$wwRole} if $permissionLevel < $ce->{userRoles}{$wwRole};
			}
		}
		if ($permissionLevel > $ce->{userRoles}{ $ce->{LTIAccountCreationCutoff} }) {
			$job->app->log->info("Skipping $userId. User has a role above the LTI "
					. "account creation cutoff of $ce->{LTIAccountCreationCutoff}.")
				if $ce->{debug_lti_parameters};
			next;
		}

		if ($users{$userId}) {
			next unless $ce->{LMSManageUserData};

			# Create a temporary user with the LMS credentials and compare the user to the existing user.
			my $tempUser = $db->newUser(
				user_id        => $userId,
				lis_source_did => $user->{user_id},
				last_name      => $user->{family_name} =~ s/\+/ /gr,
				first_name     => $user->{given_name}  =~ s/\+/ /gr,
				email_address  => $user->{email},
				status         => $user->{status} eq 'Active' ? 'C' : 'D',
				comment        =>
					formatDateTime(time, 'datetime_format_short', $ce->{siteDefaults}{timezone}, $ce->{language}),
				student_id => $studentId,
				section    => '',
				recitation => ''
			);

			my $change_made = 0;
			for my $element (qw(last_name first_name email_address status student_id)) {
				if ($users{$userId}->$element ne $tempUser->$element) {
					$change_made = 1;
					$job->app->log->info("WeBWorK user has $element: "
							. $users{$userId}->$element
							. ", but LMS user has $element: "
							. $tempUser->$element)
						if $ce->{debug_lti_parameters};
					$users{$userId}->$element($tempUser->$element);
				}
			}

			if ($change_made) {
				++$updatedUsers;
				$tempUser->comment(
					formatDateTime(time, 'datetime_format_short', $ce->{siteDefaults}{timezone}, $ce->{language}));
				eval { $db->putUser($tempUser) };
				if ($@) {
					$job->app->log->error("Failed to update user $userId when importing LMS user: $@");
					push(@messages, $job->maketext('Failed to update user [_1].', $userId));
				} else {
					push(@messages, $job->maketext('Updated user [_1].', $userId));
				}
			} else {
				push(@messages, $job->maketext("[_1] not changed.", $userId));
			}
		} else {
			push(@messages,   $job->maketext('Added user [_1] with permission level [_2].', $userId, $permissionLevel));
			push(@addedUsers, $userId);

			my $newUser = $db->newUser(
				user_id        => $userId,
				lis_source_did => $user->{user_id},
				last_name      => $user->{family_name} =~ s/\+/ /gr,
				first_name     => $user->{given_name}  =~ s/\+/ /gr,
				email_address  => $user->{email},
				status         => $user->{status} eq 'Active' ? 'C' : 'D',
				comment        =>
					formatDateTime(time, 'datetime_format_short', $ce->{siteDefaults}{timezone}, $ce->{language}),
				student_id => $studentId,
				section    => '',
				recitation => ''
			);
			$db->addUser($newUser);

			$db->addPermissionLevel($db->newPermissionLevel(user_id => $userId, permission => $permissionLevel));

			for (@achievements) {
				push(@userAchievementRecordsToAdd,
					$db->newUserAchievement(user_id => $userId, achievement_id => $_->achievement_id));
			}
			push(@globalAchievementRecordsToAdd,
				$db->newGlobalUserAchievement(user_id => $userId, achievement_points => 0));

			$users{$userId} = $newUser;
		}
	}

	# Assign visible sets to the added users.
	assignSetsToUsers($db, $ce, [ map { $_->[0] } $db->listGlobalSetsWhere({ visible => 1 }) ], \@addedUsers)
		if @addedUsers;

	# Assign achievements to the added users.
	$db->UserAchievement->insert_records(\@userAchievementRecordsToAdd) if @userAchievementRecordsToAdd;
	$db->GlobalUserAchievement->insert_records(\@globalAchievementRecordsToAdd)
		if @globalAchievementRecordsToAdd;

	my %permissionLevels =
		map { $_->user_id => $_->permission } $db->getPermissionLevelsWhere({ user_id => { not_like => 'set_id:%' } });

	# Mark all users not in the LMS roster and at or below the LTIAccountCreationCutoff as dropped.
	my @droppedUsers;
	for my $user (values %users) {
		next
			if $usersInLMSCourse{ $user->user_id }
			|| ($permissionLevels{ $user->user_id } // 0) > $ce->{userRoles}{ $ce->{LTIAccountCreationCutoff} }
			|| $user->status eq 'D';
		$user->status('D');
		push(@messages,     $job->maketext('Dropped user [_1]', $user->user_id));
		push(@droppedUsers, $user);
	}
	$db->User->update_records(\@droppedUsers) if @droppedUsers;

	push(
		@messages,
		$ce->{LMSManageUserData}
		? $job->maketext(
			'[_1] [plural,_1,user] added, [_2] [plural,_2,user] updated, '
				. '[_3] [plural,_3,user] not in LMS [plural,_3,was,were] dropped',
			scalar(@addedUsers),
			$updatedUsers,
			scalar(@droppedUsers)
			)
		: $job->maketext(
			'[_1] [plural,_1,user] added, [_2] [plural,_2,user] not in LMS [plural,_2,was,were] dropped',
			scalar(@addedUsers), scalar(@droppedUsers)
		)
	);
	return $job->finish(@messages > 1 ? \@messages : $messages[0]);
}

sub maketext ($job, @args) {
	return &{ $job->{language_handle} }(@args);
}

1;
