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

package WeBWorK::Authz;

=head1 NAME

WeBWorK::Authz - check user permissions.

=head1 SYNOPSIS

 # create new authorizer -- $c is a WeBWorK::Controller object.
 my $authz = new WeBWorK::Authz($c);

 # tell authorizer to cache permission level of user spammy.
 $authz->setCachedUser("spammy");

 # this call will use the cached data.
 if ($authz->hasPermissions("spammy", "eat_breakfast")) {
 	eat_breakfast();
 }

 # this call will not use the cached data, and will cause a database lookup.
 if ($authz->hasPermissions("hammy", "go_to_bed")) {
 	go_to_bed();
 }

=head1 DESCRIPTION

WeBWorK::Authen determines if a user is authorized to perform a specific
activity, based on the user's PermissionLevel record in the WeBWorK database and
the contents of the %permissionLevels hash in the course environment.

=head2 Format of the %permissionLevels hash

%permissionLevels maps text strings describing activities to numeric permission
levels. The definitive list of activities is contained in the default version of
%permissionLevels, in the file F<conf/defaults.config>.

A user is able to engage in an activity if their permission level is greater
than or equal to the level associated with the activity. If the level associated
with an activity is undefiend, then no user is permitted to perform the
activity, regardless of their permission level.

=cut

use strict;
use warnings;
use Carp qw/croak/;

use WeBWorK::Utils::DateTime qw(before);
use WeBWorK::Utils::Sets     qw(is_restricted);
use WeBWorK::Authen::Proctor;
use Net::IP;
use Scalar::Util qw(weaken);
use version;

################################################################################

=head1 CONSTRUCTOR

=over

=item WeBWorK::Authz->new($c)

Creates a new authorizer instance. $c is a WeBWorK::Controller object. It must
already have its C<ce> and C<db> fields set.

=cut

sub new {
	my ($invocant, $c) = @_;
	my $class = ref($invocant) || $invocant;
	my $self  = { c => $c, };
	weaken $self->{c};

	$c->{permission_retrieval_error} = 0;
	bless $self, $class;
	return $self;
}

=back

=cut

################################################################################

=head1 METHODS

=over

=item setCachedUser($userID)

Caches the PermissionLevel of the user $userID in an existing authorizer. If a
user's PermissionLevel is cached, it will be used whenever hasPermissions() is
called on the same user. Only one user can be cached at a time. This is used by
WeBWorK to cache the "real" user.

=cut

sub setCachedUser {
	my ($self, $userID) = @_;
	my $c  = $self->{c};
	my $db = $c->db;

	delete $self->{userID};
	delete $self->{PermissionLevel};

	if (defined $userID) {
		$self->{userID} = $userID;
		if (!$db->existsUser($userID) && defined($c->param("lis_person_sourcedid"))) {
			# This is a new user referred via an LTI link.
			# Do not attempt to cache the permission here.
			# Rather, the LTI authentication module should cache the permission.
			return 1;
		}
		my $PermissionLevel;
		my $tryAgain = 1;
		my $count    = 0;
		while ($tryAgain && $count < 2) {
			eval {
				$PermissionLevel = $db->getPermissionLevel($userID);    # checked
			};
			if ($@) {
				$count++;
			} else {
				$tryAgain = 0;
			}
		}
		if (defined $PermissionLevel
			and defined $PermissionLevel->permission
			and $PermissionLevel->permission ne "")
		{
			# cache the  permission level record in this request to avoid later database calls
			$self->{PermissionLevel} = $PermissionLevel;
		} elsif (defined($c->param("lis_person_sourcedid"))
			or defined($c->param("lis_person_sourced_id"))
			or defined($c->param("lis_person_source_id"))
			or defined($c->param("lis_person_sourceid"))
			or defined($c->param("lis_person_contact_email_primary")))
		{
			# This is a new user referred via an LTI link.
			# Do not attempt to cache the permission here.
			# Rather, the LTI authentication module should cache the permission.
			return 1;
		} elsif (defined($c->param("oauth_nonce"))) {
			# This is a LTI attempt that doesn't have an lis_person_sourcedid username.
			croak(
				"Your request did not specify your username.  Perhaps you were attempting to authenticate via LTI but the LTI tool did not transmit "
					. "any variant of the lis_person_sourced_id parameter and did not transmit the lis_person_contact_email_primary parameter."
			);

		} else {
			if ($c->{permission_retrieval_error} == 0) {
				$c->{permission_retrieval_error} = 1;
				croak "Unable to retrieve your permissions, perhaps due to a collision "
					. "between your request and that of another user "
					. "(or possibly an unfinished request of yours). "
					. "Please press the BACK button on your browser and try again.";
			}
		}
	} else {
		warn "setCachedUser() called with userID undefined.";
	}
}

=item hasPermissions($userID, $activity)

Checks the %permissionLevels hash in the course environment to determine if the
user $userID has permission to engage in the activity $activity. If the user's
permission level is greater than or equal to the level associated with $activty,
a true value is returned. Otherwise, a false value is returned.

If $userID has been cached using the setCachedUser() call, the cached data is
used. Otherwise, the user's PermissionLevel is looked up in the WeBWorK
database.

If the user does not have a PermissionLevel record, the permission level record
is empty, or the activity does not appear in %permissionLevels, hasPermissions()
assumes that the user does not have permission.

=cut

# This currently only uses two of it's arguments, but it accepts any number, in
# case in the future calculating certain permissions requires more information.
sub hasPermissions {
	if (@_ != 3 and not(@_ == 4 and $_[3] eq 'equal')) {
		shift @_;    # get rid of self
		my $nargs = @_;
		croak "hasPermissions called with $nargs arguments instead of the expected 2: '@_'";
	}

	my ($self, $userID, $activity, $exactness) = @_;
	if (!defined($exactness)) { $exactness = 'ge'; }
	my $c  = $self->{c};
	my $ce = $c->ce;
	my $db = $c->db;

	# this may need to be changed if we get other permission level data sources
	return 0 unless defined $db;

	# this may need to be changed if we want to control what unauthenticated users
	# can do with the permissions system
	return 0 unless defined $userID and $userID ne "";

	my $PermissionLevel;

	if (not defined($self->{userID})) {
		#warn "self->{userID} is undefined";
		$self->setCachedUser($userID);
	}

	my $cachedUserID = $self->{userID};
	if (defined $cachedUserID and $cachedUserID ne "" and $cachedUserID eq $userID) {
		# this is the same user -- we can skip the database call
		$PermissionLevel = $self->{PermissionLevel};
	} else {
	   # a different user, or no user was defined before
	   #my $prettyCachedUserID = defined $cachedUserID ? "'$cachedUserID'" : "undefined";
	   #warn "hasPermissions called with user  $userID , but cached user is $prettyCachedUserID. Accessing database.\n";
		$PermissionLevel = $db->getPermissionLevel($userID);    # checked
	}

	my $permission_level;

	if (defined $PermissionLevel) {
		$permission_level = $PermissionLevel->permission;
	} elsif (defined($c->param("lis_person_sourcedid"))) {
		# This is an LTI login.  Let's see if the LITBasic authentication module will handle this.
		#return 1;
	} else {
		# uh, oh. this user has no permission level record!
		if ($c->{permission_retrieval_error} != 1) {
			warn "User '$userID' has no PermissionLevel record -- assuming no permission.";
		}
		return 0;
	}

	unless (defined $permission_level and $permission_level ne "") {
		warn "User '$userID' has empty permission level -- assuming no permission.";
		return 0;
	}

	my $userRoles        = $ce->{userRoles};
	my $permissionLevels = $ce->{permissionLevels};

	if (exists $permissionLevels->{$activity}) {
		my $activity_role = $permissionLevels->{$activity};
		if (defined $activity_role) {
			if (exists $userRoles->{$activity_role}) {
				my $role_permlevel = $userRoles->{$activity_role};
				# Elevate all permissions greater than a student in the admin course to the
				# create_and_delete_courses level.  This way a user either has access to all
				# or only student level permissions tools in the admin course.
				if (defined($ce->{courseName}) && $ce->{courseName} eq $ce->{admin_course_id}) {
					my $admin_permlevel = $userRoles->{ $permissionLevels->{create_and_delete_courses} };
					$role_permlevel = $admin_permlevel
						if $role_permlevel > $userRoles->{student} && $role_permlevel < $admin_permlevel;
				}
				if (defined $role_permlevel) {
					if ($exactness eq 'ge') {
						return $permission_level >= $role_permlevel;
					} elsif ($exactness eq 'equal') {
						return $permission_level == $role_permlevel;
					} else {
						return 0;
					}
				} else {
					#					warn "Role '$activity_role' has undefined permission level -- assuming no permission.";
					return 0;
				}
			} else {
		 #				warn "Role '$activity_role' for activity '$activity' not found in \%userRoles -- assuming no permission.";
				return 0;
			}
		} else {
			#			warn "Undefined Role, -- assuming no one has permission to perform $activity.";
			return 0;    # undefiend $activity_role, no one has permission to perform $activity
		}
	} else {
		#		warn "Activity '$activity' not found in \%permissionLevels -- assuming no permission.";
		return 0;
	}
}

#########################  IU Addition  ###############
sub hasExactPermissions {
	my ($self, $userID, $activity) = @_;
	my $c  = $self->{c};
	my $ce = $c->ce;
	my $db = $c->db;

	#	my $Permission = $db->getPermissionLevel($user); # checked
	#	return 0 unless defined $Permission;
	#	my $permissionLevel = $Permission->permission();

##
	my $PermissionLevel;

	if (not defined($self->{userID})) {
		#warn "self->{userID} is undefined";
		$self->setCachedUser($userID);
	}

	my $cachedUserID = $self->{userID};
	if (defined $cachedUserID and $cachedUserID ne "" and $cachedUserID eq $userID) {
		# this is the same user -- we can skip the database call
		$PermissionLevel = $self->{PermissionLevel};
	} else {
	   # a different user, or no user was defined before
	   #my $prettyCachedUserID = defined $cachedUserID ? "'$cachedUserID'" : "undefined";
	   #warn "hasPermissions called with user  $userID , but cached user is $prettyCachedUserID. Accessing database.\n";
		$PermissionLevel = $db->getPermissionLevel($userID);    # checked
	}

	my $permission_level;

	if (defined $PermissionLevel) {
		$permission_level = $PermissionLevel->permission;
	} else {
		# uh, oh. this user has no permission level record!
		if ($c->{permission_retrieval_error} != 1) {
			warn "User '$userID' has no PermissionLevel record -- assuming no permission.";
		}
		return 0;
	}

	unless (defined $permission_level and $permission_level ne "") {
		warn "User '$userID' has empty permission level -- assuming no permission.";
		return 0;
	}

##

	my $permissionLevels = $ce->{permissionLevels};
	if (exists $permissionLevels->{$activity}) {
		if (defined $permissionLevels->{$activity}) {
			return $permission_level == $permissionLevels->{$activity};
		} else {
			return 0;
		}
	} else {
		die "Activity '$activity' not found in %permissionLevels. Can't continue.\n";
	}
}
#######################################################

#### set-level authorization routines

sub checkSet {
	my $self = shift;
	my $c    = $self->{c};
	my $ce   = $c->ce;
	my $db   = $c->db;

	my $node_name = $c->current_route;

	# First check to see if we have to worried about set-level access restrictions.
	return 0 unless (grep {/^$node_name$/} (qw(problem_list problem_detail gateway_quiz proctored_gateway_quiz)));

	# To check set restrictions we need a set and a user.
	my $setName           = $c->stash('setID');
	my $userName          = $c->param("user");
	my $effectiveUserName = $c->param("effectiveUser");

	# If there is no input userName, then the content generator will be forcing a login, so just bail.
	return 0 if (!$userName || !$effectiveUserName);

	# Do we have a cached set that we can use?
	my $set = $self->{merged_set};

	if ($setName =~ /,v(\d+)$/) {
		my $verNum = $1;
		$setName =~ s/,v\d+$//;

		if ($set && $set->set_id eq $setName && $set->user_id eq $effectiveUserName && $set->version_id eq $verNum) {
			# If we have all of this, then we can just use this set and skip the rest.
		} elsif ($setName eq 'Undefined_Set' && $self->hasPermissions($userName, "access_instructor_tools")) {
			# This is the case of previewing a problem from a 'try it' link.
			return 0;
		} else {
			if ($db->existsSetVersion($effectiveUserName, $setName, $verNum)) {
				$set = $db->getMergedSetVersion($effectiveUserName, $setName, $verNum);
			} else {
				return $c->maketext("Requested version ([_1]) of set '[_2]' is not assigned to user [_3].",
					$verNum, $setName, $effectiveUserName);
			}
		}
		if (!$set) {
			return $c->maketext("Requested set '[_1]' could not be found in the database for user [_2].",
				$setName, $effectiveUserName);
		}
		# Don't allow versioned sets to be viewed from the problem-list page.
		if ($node_name eq 'problem_list') {
			return $c->maketext("Requested version ([_1]) of set '[_2]' cannot be directly accessed.", $verNum,
				$setName);
		}
	} else {
		if ($set && $set->set_id eq $setName && $set->user_id eq $effectiveUserName) {
			# If we have all of this, then we can just use this set and skip the rest.
		} else {
			if ($db->existsUserSet($effectiveUserName, $setName)) {
				$set = $db->getMergedSet($effectiveUserName, $setName);
			} elsif ($setName eq 'Undefined_Set' && $self->hasPermissions($userName, "access_instructor_tools")) {
				# This is the case of the library browser, when we don't actually have a set to look at. This only
				# happens for instructor tool users.
				return 0;
			} else {
				return $c->maketext("Requested set '[_1]' is not assigned to user [_2].", $setName, $effectiveUserName);
			}
		}
		if (!$set) {
			return $c->maketext("Requested set '[_1]' could not be found in the database for user [_2].",
				$setName, $effectiveUserName);
		}
	}
	# Cache the set for future use as needed.  This should probably be more sophisticated than this.
	$self->{merged_set} = $set;

	# Now we know that the set is assigned to the appropriate user.
	# Check to see if the user is trying to access a set that is not open.
	if (
		before($set->open_date)
		&& !$self->hasPermissions($userName, "view_unopened_sets")
		&& !(
			defined $set->assignment_type
			&& $set->assignment_type =~ /gateway/
			&& $node_name eq 'problem_list'
			&& $db->countSetVersions($effectiveUserName, $set->set_id)
		)
		)
	{
		return $c->maketext("Requested set '[_1]' is not yet open.", $setName);
	}

	# Check to make sure that the set is visible, and that the user is allowed to view hidden sets.
	my $visible = $set && $set->visible ne '0' && $set->visible ne '1' ? 1 : $set->visible;
	if (!$visible && !$self->hasPermissions($userName, "view_hidden_sets")) {
		return $c->maketext("Requested set '[_1]' is not available yet.", $setName);
	}

	# Check to see if conditional release conditions have been met.
	if ($ce->{options}{enableConditionalRelease}
		&& is_restricted($db, $set, $effectiveUserName)
		&& !$self->hasPermissions($userName, "view_unopened_sets"))
	{
		return $c->maketext("The prerequisite conditions have not been met for set '[_1]'.", $setName);
	}

	# Check to be sure that gateways are being sent to the correct content generator.
	if (defined($set->assignment_type) && $set->assignment_type =~ /gateway/ && $node_name eq 'problem_detail') {
		return $c->maketext(
			"Requested set '[_1]' is a test but the regular homework assignment content "
				. 'generator [_2] was called.  Try re-entering the set from the problem sets listing page.',
			$setName, $node_name
		);
	} elsif ((!defined($set->assignment_type) || $set->assignment_type eq 'default') && $node_name =~ /gateway/) {
		return $c->maketext(
			"Requested set '[_1]' is a homework assignment but the test content generator [_2] was called.  "
				. 'Try re-entering the set from the problem sets listing page.',
			$setName, $node_name
		);
	}

	# Check if the user is entering a proctored assignment that the proctor has authenticated.  This is necessary to
	# make sure that someone doesn't use the unproctored url path to obtain access to a proctored assignment.
	# Allow ProblemSet.pm to list the proctored quiz versions.
	if (defined($set->assignment_type)
		&& $set->assignment_type =~ /proctored/
		&& $node_name ne 'problem_list'
		&& !WeBWorK::Authen::Proctor->new($c, $ce, $db)->verify())
	{
		return $c->maketext(
			'Requested set "[_1]" is a proctored test, but no valid proctor authorization has been obtained.',
			$setName);
	}

	# Check for ip restrictions.
	my $badIP = $self->invalidIPAddress($set);
	return $badIP if $badIP;

	# If LTI grade passback is enabled and set to 'homework' mode then we need to make sure that there is a sourcedid
	# for this set before students access it.
	my $LTIGradeMode = $ce->{LTIGradeMode} // '';

	if ($LTIGradeMode eq 'homework' && !$self->hasPermissions($userName, "view_unopened_sets")) {
		my $LMS =
			$ce->{LTI}{ $ce->{LTIVersion} }{LMS_url}
			? $c->link_to($ce->{LTI}{ $ce->{LTIVersion} }{LMS_name} => $ce->{LTI}{ $ce->{LTIVersion} }{LMS_url})
			: $ce->{LTI}{ $ce->{LTIVersion} }{LMS_name};
		return $c->b($c->maketext(
			'You must use your Learning Management System ([_1]) to access this set.  '
				. 'Try logging in to the Learning Management System and visiting the set from there.',
			$LMS
		))
			unless $set->lis_source_did;
	}

	return 0;
}

sub invalidIPAddress {
	# this exists as a separate routine because we need to check multiple
	#    sets in Hardcopy; having this routine to check the set allows us to do
	#    that for all sets individually there.

	my $self = shift;
	my $set  = shift;

	my $c                 = $self->{c};
	my $db                = $c->db;
	my $ce                = $c->ce;
	my $setName           = $set->set_id;
	my $userName          = $c->param("user");
	my $effectiveUserName = $c->param("effectiveUser");

	return 0
		if (!defined($set->restrict_ip)
			|| $set->restrict_ip eq ''
			|| $set->restrict_ip eq 'No'
			|| $self->hasPermissions($userName, 'view_ip_restricted_sets'));

	my $clientIP = new Net::IP($c->tx->remote_address);

	# make sure that we're using the non-versioned set name
	$setName =~ s/,v\d+$//;

	my $restrictType      = $set->restrict_ip;
	my @restrictLocations = $db->getAllMergedSetLocations($effectiveUserName, $setName);
	my @locationIDs       = (map { $_->location_id } @restrictLocations);
	my @restrictAddresses = (map { $db->listLocationAddresses($_) } @locationIDs);

	# if there are no addresses in the locations, return an error that
	#    says this
	return $c->maketext(
		"Client ip address [_1] is not allowed to work this assignment, because the assignment has ip address restrictions and there are no allowed locations associated with the restriction.  Contact your professor to have this problem resolved.",
		$clientIP->ip()
	) if (!@restrictAddresses);

	# build a set of IP objects to match against
	my @restrictIPs = (map { new Net::IP($_) } @restrictAddresses);

	# and check the clientAddress against these: is $clientIP
	#    in @restrictIPs?
	my $inRestrict = 0;
	foreach my $rIP (@restrictIPs) {
		if ($rIP->overlaps($clientIP) == $IP_B_IN_A_OVERLAP
			|| $rIP->overlaps($clientIP) == $IP_IDENTICAL)
		{
			$inRestrict = $rIP->ip();
			last;
		}
	}

	# this is slightly complicated by having to check relax_restrict_ip
	my $badIP = '';
	if ($restrictType eq 'RestrictTo' && !$inRestrict) {
		$badIP =
			"Client ip address "
			. $clientIP->ip()
			. " is not in the list of addresses from "
			. "which this assignment may be worked.";
	} elsif ($restrictType eq 'DenyFrom' && $inRestrict) {
		$badIP =
			"Client ip address "
			. $clientIP->ip()
			. " is in the list of addresses from "
			. "which this assignment may not be worked.";
	} else {
		return 0;
	}

	# if we're here, we failed the IP check, and so need to consider
	#    if ip restrictions were relaxed.  the set we were passed in
	#    is either the merged userset or the merged versioned userset,
	#    depending on whether the set is versioned or not

	my $relaxRestrict = $set->relax_restrict_ip;
	return $badIP if ($relaxRestrict eq 'No');

	if ($set->assignment_type =~ /gateway/) {
		if ($relaxRestrict eq 'AfterAnswerDate') {
			# in this case we need to go and get the userset,
			#    not the versioned set (which we already have)
			#    drat!
			my $userset = $db->getMergedSet($set->user_id, $setName);
			return (!$userset || before($userset->answer_date) ? $badIP : 0);
		} else {
			# this is easier; just look at the current answer date
			return (before($set->answer_date) ? $badIP : 0);
		}
	} else {
		# the set isn't versioned, so assume that $relaxRestrict
		#    is 'AfterAnswerDate', regardless of what it actually
		#    is; 'AfterVersionAnswerDate' doesn't make sense in
		#    this case
		return (before($set->answer_date) ? $badIP : 0);
	}
}

=back

=cut

=head1 AUTHOR

Written by Dennis Lambe, malsyned at math.rochester.edu. Modified by Sam
Hathaway, sh002i at math.rochester.edu.

=cut

1;
