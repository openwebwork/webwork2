package WeBWorK::Authz;
use Mojo::Base -signatures;

=head1 NAME

WeBWorK::Authz - check user permissions.

=head1 SYNOPSIS

Create a new authorizer object. A WeBWorK::Controller object must be provided.

    my $authz = new WeBWorK::Authz($c);

Cache the permission level for the user spammy.

    $authz->setCachedUser('spammy');

This call will use the cached data.

    if ($authz->hasPermissions('spammy', 'eat_breakfast')) {
    	eat_breakfast();
    }

This call will not use the cached data, and will cause a database lookup.

    if ($authz->hasPermissions('hammy', 'go_to_bed')) {
    	go_to_bed();
    }

=head1 DESCRIPTION

C<WeBWorK::Authen> determines if a user is authorized to perform a specific
activity, based on the user's PermissionLevel record in the WeBWorK database and
the contents of the C<%permissionLevels> hash in the course environment.

The C<%permissionLevels> hash in the course environment maps text strings
describing activities to numeric permission levels. The definitive list of
activities is contained in the default version of the C<%permissionLevels> hash
defined in the file F<conf/defaults.config>.

A user is able to engage in an activity if their permission level is greater
than or equal to the level associated with the activity. If the level associated
with an activity is undefined, then no user is permitted to perform the
activity, regardless of their permission level.

=cut

use Net::IP;
use Scalar::Util qw(weaken);

use WeBWorK::Utils::DateTime qw(before);
use WeBWorK::Utils::Sets     qw(restricted_set_message);
use WeBWorK::Authen::Proctor;

=head1 CONSTRUCTOR

Usage: C<< WeBWorK::Authz->new($c) >>

Creates a new authorizer instance. C<$c> is a C<WeBWorK::Controller> object. It
must already have its C<ce> and C<db> fields set.

=cut

sub new ($invocant, $c) {
	my $self = bless { c => $c }, ref($invocant) || $invocant;
	weaken $self->{c};
	return $self;
}

=head1 METHODS

=head2 setCachedUser

Usage: C<< $authz->setCachedUser($userID) >>

Caches the PermissionLevel of the user C<$userID> in an existing authorizer. If
a user's PermissionLevel is cached, it will be used whenever C<hasPermissions>
is called on the same user. Only one user can be cached at a time.

=cut

sub setCachedUser ($self, $userID) {
	my $c  = $self->{c};
	my $db = $c->db;

	delete $self->{userID};
	delete $self->{PermissionLevel};

	if (defined $userID) {
		$self->{userID} = $userID;
		my $permissionLevel = $db->getPermissionLevel($userID);
		$self->{PermissionLevel} = $permissionLevel
			if defined $permissionLevel && defined $permissionLevel->permission && $permissionLevel->permission ne '';
	}

	return;
}

=head2 hasPermissions

Usage: C<< $authz->hasPermissions($userID, $activity, $exactness) >>

Checks the C<%permissionLevels> hash in the course environment to determine if
the user C<$userID> has permission to engage in the activity C<$activity>. If
the user's permission level is greater than or equal to the level associated
with C<$activity>, a true value is returned. Otherwise, a false value is
returned.

If C<$userID> has been cached using the C<setCachedUser> call, the cached data
is used. Otherwise, the user's permission level is looked up in the database.

If the user does not have a PermissionLevel record, the permission level record
is empty, or the activity does not appear in C<%permissionLevels>,
C<hasPermissions> assumes that the user does not have permission.

If the optional C<$exactness> argument is provided it must be S<'equal'>, and in
that case C<hasPermissions> will only return true if the user's permission level
is equal to the level associated with C<$activity>.

=cut

sub hasPermissions ($self, $userID, $activity, $exactness = undef) {
	$exactness //= 'ge';

	my $c  = $self->{c};
	my $ce = $c->ce;
	my $db = $c->db;

	return 0 unless defined $db && defined $userID && $userID ne '';

	my $permissionLevelRecord;

	$self->setCachedUser($userID) unless defined $self->{userID};

	my $cachedUserID = $self->{userID};
	if (defined $cachedUserID && $cachedUserID ne '' && $cachedUserID eq $userID) {
		$permissionLevelRecord = $self->{PermissionLevel};
	} else {
		$permissionLevelRecord = $db->getPermissionLevel($userID);
	}

	return 0 unless defined $permissionLevelRecord;

	my $permissionLevel = $permissionLevelRecord->permission;
	return 0 unless defined $permissionLevel && $permissionLevel ne '';

	my $userRoles        = $ce->{userRoles};
	my $permissionLevels = $ce->{permissionLevels};

	if (exists $permissionLevels->{$activity}) {
		my $activityRole = $permissionLevels->{$activity};
		if (defined $activityRole && exists $userRoles->{$activityRole}) {
			my $rolePermissionLevel = $userRoles->{$activityRole};
			# Elevate all permissions greater than a student in the admin course to the
			# create_and_delete_courses level.  This way a user either has access to all
			# or only student level permissions tools in the admin course.
			if (defined $ce->{courseName} && $ce->{courseName} eq $ce->{admin_course_id}) {
				my $admin_permlevel = $userRoles->{ $permissionLevels->{create_and_delete_courses} };
				$rolePermissionLevel = $admin_permlevel
					if $rolePermissionLevel > $userRoles->{student} && $rolePermissionLevel < $admin_permlevel;
			}
			if (defined $rolePermissionLevel) {
				if ($exactness eq 'ge') {
					return $permissionLevel >= $rolePermissionLevel;
				} elsif ($exactness eq 'equal') {
					return $permissionLevel == $rolePermissionLevel;
				} else {
					return 0;
				}
			} else {
				return 0;
			}
		} else {
			return 0;
		}
	} else {
		return 0;
	}
}

# Set level authorization routines.

sub checkSet ($self) {
	my $c  = $self->{c};
	my $ce = $c->ce;
	my $db = $c->db;

	my $node_name = $c->current_route;

	# First check to see if we have to worried about set-level access restrictions.
	return 0 unless grep {/^$node_name$/} (qw(problem_list problem_detail gateway_quiz proctored_gateway_quiz));

	# To check set restrictions we need a set and a user.
	my $setName           = $c->stash('setID');
	my $userName          = $c->param('user');
	my $effectiveUserName = $c->param('effectiveUser');

	# If there is no input userName, then the content generator will be forcing a login, so just bail.
	return 0 if !$userName || !$effectiveUserName;

	# Do we have a cached set that we can use?
	my $set = $self->{merged_set};

	if ($setName =~ /,v(\d+)$/) {
		my $verNum = $1;
		$setName =~ s/,v\d+$//;

		if ($set && $set->set_id eq $setName && $set->user_id eq $effectiveUserName && $set->version_id eq $verNum) {
			# If we have all of this, then we can just use this set and skip the rest.
		} elsif ($setName eq 'Undefined_Set' && $self->hasPermissions($userName, 'access_instructor_tools')) {
			# This is the case of previewing a problem from a 'try it' link.
			return 0;
		} else {
			if ($db->existsSetVersion($effectiveUserName, $setName, $verNum)) {
				$set = $db->getMergedSetVersion($effectiveUserName, $setName, $verNum);
			} else {
				return $c->maketext('Requested version ([_1]) of set "[_2]" is not assigned to user [_3].',
					$verNum, $setName, $effectiveUserName);
			}
		}
		if (!$set) {
			return $c->maketext('Requested set "[_1]" could not be found in the database for user [_2].',
				$setName, $effectiveUserName);
		}
		# Don't allow versioned sets to be viewed from the problem-list page.
		if ($node_name eq 'problem_list') {
			return $c->maketext('Requested version ([_1]) of set "[_2]" cannot be directly accessed.', $verNum,
				$setName);
		}
	} else {
		if ($set && $set->set_id eq $setName && $set->user_id eq $effectiveUserName) {
			# If we have all of this, then we can just use this set and skip the rest.
		} else {
			if ($db->existsUserSet($effectiveUserName, $setName)) {
				$set = $db->getMergedSet($effectiveUserName, $setName);
			} elsif ($setName eq 'Undefined_Set' && $self->hasPermissions($userName, 'access_instructor_tools')) {
				# This is the case of the library browser, when we don't actually have a set to look at. This only
				# happens for instructor tool users.
				return 0;
			} else {
				return $c->maketext('Requested set "[_1]" is not assigned to user [_2].', $setName, $effectiveUserName);
			}
		}
		if (!$set) {
			return $c->maketext('Requested set "[_1]" could not be found in the database for user [_2].',
				$setName, $effectiveUserName);
		}
	}
	# Cache the set for future use as needed.  This should probably be more sophisticated than this.
	$self->{merged_set} = $set;

	# Save restricted set messages to show to instructors if they exist.
	my $canViewUnopened = $self->hasPermissions($userName, 'view_unopened_sets');
	my @restrictedSetMessages;

	# Now we know that the set is assigned to the appropriate user.
	# $c->{viewSetCheck} is used to configure what is shown on ProblemSet page.

	# Check to make sure that the set is visible, and that the user is allowed to view hidden sets.
	my $visible = $set && $set->visible ne '0' && $set->visible ne '1' ? 1 : $set->visible;
	if (!$visible && !$self->hasPermissions($userName, 'view_hidden_sets')) {
		$c->{viewSetCheck} = 'hidden';
		return $c->maketext('Requested set "[_1]" is not available.', $setName);
	}

	# Check to see if the user is trying to access a set that is not open.
	if (before($set->open_date) && !$canViewUnopened) {
		$c->{viewSetCheck} = 'not-open';
		return $c->maketext('Requested set "[_1]" is not available yet.', $setName);
	}

	# Check to see if conditional release conditions have been met.
	my $conditional_msg = restricted_set_message($c, $set, 'conditional');
	if ($conditional_msg) {
		if ($canViewUnopened) {
			push(@restrictedSetMessages, $conditional_msg);
		} else {
			$c->{viewSetCheck} = 'restricted';
			return $conditional_msg;
		}
	}

	# Check to be sure that gateways are being sent to the correct content generator.
	if (defined $set->assignment_type && $set->assignment_type =~ /gateway/ && $node_name eq 'problem_detail') {
		return $c->maketext(
			'Requested set "[_1]" is a test but the regular homework assignment content '
				. 'generator [_2] was called.  Try re-entering the set from the problem sets listing page.',
			$setName, $node_name
		);
	} elsif ((!defined $set->assignment_type || $set->assignment_type eq 'default') && $node_name =~ /gateway/) {
		return $c->maketext(
			'Requested set "[_1]" is a homework assignment but the test content generator [_2] was called.  '
				. 'Try re-entering the set from the problem sets listing page.',
			$setName, $node_name
		);
	}

	# Check if the user is entering a proctored assignment that the proctor has authenticated.  This is necessary to
	# make sure that someone doesn't use the unproctored url path to obtain access to a proctored assignment.
	# Allow ProblemSet.pm to list the proctored quiz versions.
	if (defined $set->assignment_type
		&& $set->assignment_type =~ /proctored/
		&& $node_name ne 'problem_list'
		&& !WeBWorK::Authen::Proctor->new($c, $ce, $db)->verify)
	{
		return $c->maketext(
			'Requested set "[_1]" is a proctored test, but no valid proctor authorization has been obtained.',
			$setName);
	}

	# Check for ip restrictions.
	my $badIP = $self->invalidIPAddress($set);
	if ($badIP) {
		if ($self->hasPermissions($userName, 'view_ip_restricted_sets')) {
			push(@restrictedSetMessages, $badIP);
		} else {
			$c->{viewSetCheck} = 'restricted';
			return $badIP;
		}
	}

	# Check for lis_source_did if LTI grade passback is 'homework'.
	my $lti_msg = restricted_set_message($c, $set, 'lti');
	if ($lti_msg) {
		if ($canViewUnopened) {
			push(@restrictedSetMessages, $lti_msg);
		} else {
			$c->{viewSetCheck} = 'restricted';
			return $lti_msg;
		}
	}

	$c->{restrictedSetMessages} = \@restrictedSetMessages if @restrictedSetMessages;
	return 0;
}

sub invalidIPAddress ($self, $set) {
	return 0 if !defined $set->restrict_ip || $set->restrict_ip eq '' || $set->restrict_ip eq 'No';

	my $c  = $self->{c};
	my $db = $c->db;

	# Make sure that the non-versioned set name is used.
	my $setName = $set->set_id =~ s/,v\d+$//r;

	my $restrictType      = $set->restrict_ip;
	my @restrictAddresses = map { $db->listLocationAddresses($_) }
		map { $_->location_id } $db->getAllMergedSetLocations($c->param('effectiveUser'), $setName);

	my $clientIP = Net::IP->new($c->tx->remote_address);

	# If there are no addresses in the locations, return an error.
	return $c->maketext(
		'Client ip address [_1] is not allowed to work this assignment, because the assignment has ip address '
			. 'restrictions and there are no allowed locations associated with the restriction.  Contact your '
			. 'professor to have this problem resolved.',
		$clientIP->ip
	) unless @restrictAddresses;

	# Check to see if the clientAddress is a restricted IP address.
	my $inRestrict = 0;
	for my $rIP (map { Net::IP->new($_) } @restrictAddresses) {
		if ($rIP->overlaps($clientIP) == $IP_B_IN_A_OVERLAP || $rIP->overlaps($clientIP) == $IP_IDENTICAL) {
			$inRestrict = $rIP->ip;
			last;
		}
	}

	# This is slightly complicated by having to check relax_restrict_ip.
	my $badIP = '';
	if ($restrictType eq 'RestrictTo' && !$inRestrict) {
		$badIP = $c->maketext(
			'Client ip address [_1] is not in the list of addresses from which this assignment may be worked.',
			$clientIP->ip);
	} elsif ($restrictType eq 'DenyFrom' && $inRestrict) {
		$badIP = $c->maketext(
			'Client ip address [_1] is in the list of addresses from which this assignment may not be worked.',
			$clientIP->ip);
	} else {
		return 0;
	}

	# If this is reached, then the IP check failed. Now determine if ip restrictions were relaxed.
	my $relaxRestrict = $set->relax_restrict_ip;
	return $badIP if $relaxRestrict eq 'No';

	if ($set->assignment_type =~ /gateway/) {
		if ($relaxRestrict eq 'AfterAnswerDate') {
			my $userset = $db->getMergedSet($set->user_id, $setName);
			return !$userset || before($userset->answer_date) ? $badIP : 0;
		} else {
			return before($set->answer_date) ? $badIP : 0;
		}
	} else {
		# The set isn't versioned, so assume that $relaxRestrict is 'AfterAnswerDate', regardless of what it actually
		# is. 'AfterVersionAnswerDate' doesn't make sense in this case.
		return before($set->answer_date) ? $badIP : 0;
	}
}

1;
