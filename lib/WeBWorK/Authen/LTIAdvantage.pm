###############################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::Authen::LTIAdvantage;
use parent qw(WeBWorK::Authen);

=head1 NAME

WeBWorK::Authen::LTIAdvantage - Authenticate from a Learning Management System
via the IMS LTI v1.3 protocol.

=cut

use strict;
use warnings;
use experimental 'signatures';

use WeBWorK::Debug;
use WeBWorK::Localize;
use WeBWorK::Utils::DateTime qw(formatDateTime);
use WeBWorK::Utils::Instructor qw(assignSetToUser);
use WeBWorK::Authen::LTIAdvantage::SubmitGrade;

=head1 CONSTRUCTOR

=over

=item new($c)

Instantiates a new WeBWorK::Authen object for the given WeBWorK::Controller ($c).

=back

=cut

sub new ($invocant, $c) {
	return bless { c => $c }, ref($invocant) || $invocant;
}

sub request_has_data_for_this_verification_module ($self) {
	debug('LTIAdvantage has been called for data verification');
	my $c = $self->{c};

	# This module insists that the course is configured for LTI 1.3.
	if (!$c->ce->{LTIVersion} || $c->ce->{LTIVersion} ne 'v1p3') {
		debug('LTIAdvantage returning that it is not configured for this course');
		return 0;
	}

	# LTI 1.3 authentication requests are exactly those that go through these routes.
	if ($c->current_route eq 'ltiadvantage_login' || $c->current_route eq 'ltiadvantage_launch') {
		debug('LTIAdvantage returning that it has sufficient data');
		return 1;
	}

	debug('LTIAdvantage returning that it has insufficent data');
	return 0;
}

sub verify ($self) {
	my $c  = $self->{c};
	my $ce = $c->ce;

	# This happens before the parent class calls request_has_data_for_this_verification_module,
	# so make sure to check the LTIVersion to ensure the course is configured for LTI 1.3.
	if ($ce->{LTIVersion} && $ce->{LTIVersion} eq 'v1p3' && $c->current_route eq 'ltiadvantage_login') {
		unless ($c->param('iss')
			&& $ce->{LTI}{v1p3}{PlatformID} eq $c->param('iss')
			&& $c->param('client_id')
			&& $ce->{LTI}{v1p3}{ClientID} eq $c->param('client_id')
			&& $c->param('lti_message_hint')
			&& $c->param('login_hint'))
		{
			warn "The LTI Advantage login route was accessed with invalid or missing parameters.\n"
				if $ce->{debug_lti_parameters};
			debug('The LTI Advantage login route was accessed with invalid or missing parameters.');
			return 0;
		}

		warn "The LTI Advantage login route was accessed with the appropriate parameters.\n"
			if $ce->{debug_lti_parameters};
		debug('The LTI Advantage login route was accessed with the appropriate parameters.');

		return 1;
	}

	return $self->SUPER::verify;
}

sub get_credentials ($self) {
	my $c = $self->{c};

	my $ce = $c->ce;

	debug('LTIAdvantage::get_credentials has been called');

	# Disable password login
	$self->{external_auth} = 1;

	# If there was an error during the extraction of the JWT, then authentication fails here.
	if ($c->stash->{LTIAuthenError}) {
		$self->{error} = $c->maketext(
			'There was an error during the login process.  Please speak to your instructor or system administrator.');
		warn $c->stash->{LTIAuthenError} . "\n" if $ce->{debug_lti_parameters};
		debug($c->stash->{LTIAuthenError});
		return 0;
	}

	my $claims = $c->stash->{lti_jwt_claims};

	# Get the target_link_uri from the claims.
	$c->stash->{LTILaunchRedirect} = $claims->{'https://purl.imsglobal.org/spec/lti/claim/target_link_uri'};

	unless (defined $c->stash->{LTILaunchRedirect}) {
		$self->{error} = $c->maketext(
			'There was an error during the login process.  Please speak to your instructor or system administrator.');
		warn 'LTI is not properly configured (failed to obtain target_link_uri). '
			. "Please contact your instructor or system administrator.\n";
		debug('Failed to obtain target_link_uri so LTIAdvantage::get_credentials is returning 0.');
		return 0;
	}

	# Determine the user_id to use, if possible.
	if (!$ce->{LTI}{v1p3}{preferred_source_of_username}) {
		warn 'LTI is not properly configured (no preferred_source_of_username). '
			. "Please contact your instructor or system administrator.\n";
		$self->{error} = $c->maketext(
			'There was an error during the login process.  Please speak to your instructor or system administrator.');
		debug("No preferred_source_of_username in $ce->{courseName} so LTIAdvantage::get_credentials is returning 0.");
		return 0;
	}

	my $user_id_source = '';
	my $type_of_source = '';

	$self->{email} = $claims->{email} // '';

	my $extract_claim = sub ($key) {
		my $value = $claims;
		for (split '#', $key) {
			if (defined $value->{$_}) {
				$value = $value->{$_};
			} else {
				return;
			}
		}
		return $value;
	};

	if (my $user_id = $extract_claim->($ce->{LTI}{v1p3}{preferred_source_of_username})) {
		$user_id_source  = $ce->{LTI}{v1p3}{preferred_source_of_username};
		$type_of_source  = 'preferred_source_of_username';
		$self->{user_id} = $user_id;
	}

	# Fallback if necessary
	if (!defined $self->{user_id} && (my $user_id = $extract_claim->($ce->{LTI}{v1p3}{fallback_source_of_username}))) {
		$user_id_source  = $ce->{LTI}{v1p3}{fallback_source_of_username};
		$type_of_source  = 'fallback_source_of_username';
		$self->{user_id} = $user_id;
	}

	if ($self->{user_id}) {
		# Strip off the part of the address after @ if the email address was used and it was requested to do so.
		$self->{user_id} =~ s/@.*$// if $user_id_source eq 'email' && $ce->{LTI}{v1p3}{strip_domain_from_email};

		# Make user_id lowercase for consistency in naming if configured.
		$self->{user_id} = lc($self->{user_id}) if $ce->{LTI}{v1p3}{lowercase_username};

		$self->{ $_->[0] } = $extract_claim->($_->[1])
			for (
				[ roles      => 'https://purl.imsglobal.org/spec/lti/claim/roles' ],
				[ last_name  => 'family_name' ],
				[ first_name => 'given_name' ],
				[ section    => 'https://purl.imsglobal.org/spec/lti/claim/custom#section' ],
				[ recitation => 'https://purl.imsglobal.org/spec/lti/claim/custom#recitation' ],
			);

		$self->{student_id} =
			$ce->{LTI}{v1p3}{preferred_source_of_student_id}
			? ($extract_claim->($ce->{LTI}{v1p3}{preferred_source_of_student_id}) // '')
			: '';

		# For setting up it is helpful to print out what is believed to be the user id and address is at this point.
		if ($ce->{debug_lti_parameters}) {
			warn "=========== SUMMARY ============\n";
			warn "User id is |$self->{user_id}| (obtained from $user_id_source which was $type_of_source)\n";
			warn "User email address is |$self->{email}|\n";
			warn "strip_domain_from_email is |", $ce->{LTI}{v1p3}{strip_domain_from_email} // 0, "|\n";
			warn "Student id is |$self->{student_id}|\n";
			warn "preferred_source_of_username is |$ce->{LTI}{v1p3}{preferred_source_of_username}|\n";
			warn "fallback_source_of_username is |", $ce->{LTI}{v1p3}{fallback_source_of_username} // 'undefined',
				"|\n";
			warn "preferred_source_of_student_id is |",
				$ce->{LTI}{v1p3}{preferred_source_of_student_id} // 'undefined', "|\n";
			warn "================================\n";
		}
		if (!defined($self->{user_id})) {
			die 'LTIAdvantage was unable to create a username from the data provided with the current settings. '
				. "Set \$debug_lti_parameters=1 in authen_LTI.conf to debug.\n";
		}

		# Save these for later if they are available in the JWT.  It is important that the lti_lms_user_id be updated
		# with the 'sub' value from the claim.  The value from the state can not entirely be trusted.  In addition, this
		# may not be the same as the original login_hint (it is different for Canvas, but the same for Moodle).
		$c->stash->{lti_lms_user_id} = $claims->{sub};
		$c->stash->{lti_lms_lineitem} =
			$extract_claim->('https://purl.imsglobal.org/spec/lti-ags/claim/endpoint#lineitem');

		# Extract a possible setID from the target_link_uri.  This may not be an actual setID.
		# That will be verified later in WeBWorK::Authen::LTIAdvantage::SubmitGrade::update_sourcedid.
		my $location = $c->location;
		my $target   = $c->url_for($c->stash->{LTILaunchRedirect})->path;
		$c->stash->{setID} = $1 if $target =~ m|$location/$ce->{courseName}/([^/]*)|;

		$self->{login_type}        = 'normal';
		$self->{credential_source} = 'LTIAdvantage';
		debug('LTIAdvantange::get_credentials is returning 1.');
		return 1;
	}

	$self->{error} = $c->maketext(
		'There was an error during the login process.  Please speak to your instructor or system administrator.');
	warn 'LTI is not properly configured. Unable to determine username. '
		. "Please contact your instructor or system administrator.\n";
	debug('LTIAdvantange::get_credentials is returning 0.');
	return 0;
}

# Minor modification of method in superclass.
sub check_user ($self) {
	my $c     = $self->{c};
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;

	my $user_id = $self->{user_id};

	debug("LTIAdvantange::check_user has been called for user_id = |$user_id|");

	if (!defined $user_id || $user_id eq '') {
		$self->{log_error} .= 'no user id specified';
		$self->{error} = $c->maketext(
			'There was an error during the login process.  Please speak to your instructor or system administrator.');
		return 0;
	}

	my $User = $db->getUser($user_id);

	if (!$User) {
		debug("User |$user_id| is unknown but may be an new user from an LMS via LTI.");
		return 1;
	}

	unless ($ce->status_abbrev_has_behavior($User->status, 'allow_course_access')) {
		$self->{log_error} .= "LOGIN FAILED $user_id - course access denied";
		$self->{error} = $c->maketext('Authentication failed.  Please speak to your instructor.');
		return 0;
	}

	unless ($authz->hasPermissions($user_id, 'login')) {
		$self->{log_error} .= "LOGIN FAILED $user_id - no permission to login";
		$self->{error} = $c->maketext('Authentication failed.  Please speak to your instructor.');
		return 0;
	}

	debug('LTIAdvantange::check_user is about to return a 1.');
	return 1;
}

# Disable practice users.  This shouldn't actually be called in any case.
sub verify_practice_user ($self) { return 0; }

sub verify_normal_user ($self) {
	my ($c, $user_id, $session_key) = map { $self->{$_}; } ('c', 'user_id', 'session_key');

	debug("LTIAdvantage::verify_normal_user called for user |$user_id|");

	my $auth_result = $self->authenticate;

	debug("auth_result=|${auth_result}|");

	$c->param("user" => $user_id);

	if ($auth_result eq '1') {
		$self->{session_key} = $self->create_session($user_id);
		debug("session_key=|" . $self->{session_key} . "|.");
		return 1;
	} else {
		$self->{error} = $auth_result;
		$self->{log_error} .= "$user_id - authentication failed: " . $self->{error};
		return 0;
	}
}

sub authenticate ($self) {
	my ($c, $user) = map { $self->{$_}; } ('c', 'user_id');

	debug("LTIAdvantange::authenticate called for user |$user|");

	# The actual authentication for this module has already been done.  This just creates and updates users if needed.

	my $ce         = $c->ce;
	my $db         = $c->db;
	my $courseName = $c->ce->{courseName};

	if (!$db->existsUser($self->{user_id})) {
		# New User. Create User record.
		if ($ce->{block_lti_create_user}) {
			$self->{log_error} .=
				"Account creation blocked by block_lti_create_user setting. Did not create user $self->{user_id}.";
			if ($ce->{debug_lti_parameters}) {
				warn $c->maketext('Account creation is currently disabled in this course.  '
						. 'Please speak to your instructor or system administrator.')
					. "\n";
			}
			return 0;
		} else {
			# Attempt to create the user, and warn if that fails.
			unless ($self->create_user) {
				$self->{log_error} .= "Failed to create user $self->{user_id}.";
				warn "Failed to create user $self->{user_id}.\n" if ($ce->{debug_lti_parameters});
			}
		}
	} elsif ($ce->{LMSManageUserData}) {
		# Existing user. Possibly modify demographic information and permission level.
		# Set here so login gets logged, even for accounts which maybe_update_user would
		# not modify or if it fails to update.
		$self->{initial_login} = 1;
		unless ($self->maybe_update_user) {
			# Do not fail the login if data update failed.
			warn 'The system failed to update some of your account information. '
				. "Please speak to your instructor or system administrator.\n";
		}
	} else {
		# Set here so login gets logged when $ce->{LMSManageUserData} is false.
		$self->{initial_login} = 1;
	}

	# If we are using grade passback then make sure the data we need to submit the grade is kept up to date.
	my $LTIGradeMode = $ce->{LTIGradeMode} // '';
	if ($LTIGradeMode eq 'course' || $LTIGradeMode eq 'homework') {
		WeBWorK::Authen::LTIAdvantage::SubmitGrade->new($c)->update_passback_data($self->{user_id});
	}

	return 1;
}

# Create a new user trying to log in for the first time.
sub create_user ($self) {
	my $c          = $self->{c};
	my $ce         = $c->ce;
	my $db         = $c->db;
	my $userID     = $self->{user_id};
	my $courseName = $c->ce->{courseName};

	# Determine the roles defined for this user defined in the LTI request and assign a permission level on that basis.
	my @LTIroles = @{ $self->{roles} };

	# Restrict to institution and context roles and remove the purl link portion (ignore system roles).
	@LTIroles =
		map {s|^[^#]*#||r}
		grep {m!^http://purl.imsglobal.org/vocab/lis/v2/(membership|institution\/person)#!} @LTIroles;

	if ($ce->{debug_lti_parameters}) {
		warn "The adjusted LTI roles defined for this user are: \n-- " . join("\n-- ", @LTIroles),
			"\n" . "The user will be assigned the highest role defined for them.\n";
	}

	if (!defined($ce->{userRoles}{ $ce->{LTI}{v1p3}{LMSrolesToWeBWorKroles}{ $LTIroles[0] } })) {
		die "Cannot find a WeBWorK role that corresponds to the LMS role of $LTIroles[0].\n";
	}

	my $LTI_webwork_permissionLevel = $ce->{userRoles}{ $ce->{LTI}{v1p3}{LMSrolesToWeBWorKroles}{ $LTIroles[0] } };
	if (@LTIroles > 1) {
		for (@LTIroles[ 1 .. $#LTIroles ]) {
			my $wwRole = $ce->{LTI}{v1p3}{LMSrolesToWeBWorKroles}{$_};
			next unless defined $wwRole;
			$LTI_webwork_permissionLevel = $ce->{userRoles}{$wwRole}
				if ($LTI_webwork_permissionLevel < $ce->{userRoles}{$wwRole});
		}
	}

	warn "New user: $userID -- requested permission level is $LTI_webwork_permissionLevel.\n"
		if $ce->{debug_lti_parameters};

	# We dont create users with too high of a permission level for security reasons.
	if ($LTI_webwork_permissionLevel > $ce->{userRoles}{ $ce->{LTIAccountCreationCutoff} }) {
		die $c->maketext(
			'The instructor account with user id [_1] does not exist.  '
				. 'Instructor accounts must be created manually.',
			$userID
		) . "\n";
	}

	my $newUser = $db->newUser;
	$newUser->user_id($userID);
	$newUser->last_name($self->{last_name}   =~ s/\+/ /gr);
	$newUser->first_name($self->{first_name} =~ s/\+/ /gr);
	$newUser->email_address($self->{email});
	$newUser->status('C');
	$newUser->section($self->{section}       // '');
	$newUser->recitation($self->{recitation} // '');
	$newUser->comment(formatDateTime(time, 0, $ce->{siteDefaults}{timezone}, $ce->{language}));
	$newUser->student_id($self->{student_id} // '');

	# Allow sites to customize the user.
	$ce->{LTI}{v1p3}{modify_user}($self, $newUser) if ref($ce->{LTI}{v1p3}{modify_user}) eq 'CODE';

	$db->addUser($newUser);
	$self->write_log_entry("New user $userID added via LTIAdvantange login");

	# Set permission level.
	my $newPermissionLevel = $db->newPermissionLevel();
	$newPermissionLevel->user_id($userID);
	$newPermissionLevel->permission($LTI_webwork_permissionLevel);
	$db->addPermissionLevel($newPermissionLevel);
	$c->authz->{PermissionLevel} = $newPermissionLevel;

	# Assign existing sets.
	my @setsToAssign;

	my @globalSetIDs = $db->listGlobalSets;
	my @GlobalSets   = $db->getGlobalSets(@globalSetIDs);
	for my $globalSet (@GlobalSets) {
		# Assign all visible or "published" sets
		if ($globalSet->visible) {
			push @setsToAssign, $globalSet;
			assignSetToUser($db, $userID, $globalSet);
		}
	}
	$self->{numberOfSetsAssigned} = scalar @setsToAssign;

	# Assign all existing achievements.
	my @achievementIDs = $db->listAchievements;
	for my $achievementID (@achievementIDs) {
		my $achievement = $db->getAchievement($achievementID);
		if ($achievement->enabled) {
			my $userAchievement = $db->newUserAchievement();
			$userAchievement->user_id($userID);
			$userAchievement->achievement_id($achievementID);
			$db->addUserAchievement($userAchievement);
		}
	}
	# Initialize global achievement data.
	my $globalUserAchievement = $db->newGlobalUserAchievement;
	$globalUserAchievement->user_id($userID);
	$globalUserAchievement->achievement_points(0);
	$db->addGlobalUserAchievement($globalUserAchievement);

	# Give schools the chance to modify newly added sets
	if (ref($ce->{LTI}{v1p3}{modify_user_set}) eq 'CODE') {
		for my $globalSet (@setsToAssign) {
			my $userSet = $db->getUserSet($userID, $globalSet->set_id);
			next unless $userSet;

			$ce->{LTI}{v1p3}{modify_user_set}($self, $globalSet, $userSet);
			$db->putUserSet($userSet);
		}
	}

	$self->{initial_login} = 1;

	return 1;
}

# possibly update a user logging in
sub maybe_update_user ($self) {
	my $c  = $self->{c};
	my $ce = $c->ce;
	my $db = $c->db;

	my $userID     = $self->{user_id};
	my $courseName = $ce->{courseName};

	my $user            = $db->getUser($userID);
	my $permissionLevel = $db->getPermissionLevel($userID);

	# We don't alter records of users with too high a permission.
	if (defined($permissionLevel->permission)
		&& $permissionLevel->permission > $ce->{userRoles}{ $ce->{LTIAccountCreationCutoff} })
	{
		return 1;
	} else {
		# Create a temp user and run it through the create process
		my $tempUser = $db->newUser();
		$tempUser->user_id($userID);
		$tempUser->last_name(($self->{last_name}   // '') =~ s/\+/ /gr);
		$tempUser->first_name(($self->{first_name} // '') =~ s/\+/ /gr);
		$tempUser->email_address($self->{email});
		$tempUser->status('C');
		$tempUser->section($self->{section}       // '');
		$tempUser->recitation($self->{recitation} // '');
		$tempUser->student_id($self->{student_id} // '');

		# Allow sites to customize the temp user
		$ce->{LTI}{v1p3}{modify_user}($self, $tempUser) if ref($ce->{LTI}{v1p3}{modify_user}) eq 'CODE';

		my $change_made = 0;
		for my $element (qw(last_name first_name email_address status section recitation student_id)) {
			if ($user->$element ne $tempUser->$element) {
				$change_made = 1;
				warn "WeBWorK User has $element: "
					. $user->$element
					. " but LMS user has $element "
					. $tempUser->$element . "\n"
					if ($ce->{debug_lti_parameters});
			}
		}

		if ($change_made) {
			$tempUser->comment(formatDateTime(time, 0, $ce->{siteDefaults}{timezone}, $ce->{language}));
			eval { $db->putUser($tempUser) };
			if ($@) {
				$self->write_log_entry("Failed to update user $userID in LTIAdvantange login: $@");
				warn "Failed to update user $userID in LTIAdvantange login.\n" if ($ce->{debug_lti_parameters});
				return 0;
			} else {
				$self->write_log_entry("Demographic data for user $userID modified via LTIAdvantange login");
				warn "Existing user: $userID updated.\n" if ($ce->{debug_lti_parameters});
				return 1;
			}
		} else {
			return 1;
		}
	}
}

1;
