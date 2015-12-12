################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authz.pm,v 1.37 2012/06/08 22:59:54 wheeler Exp $
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

 # create new authorizer -- $r is a WeBWorK::Request object.
 my $authz = new WeBWorK::Authz($r);
 
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
# FIXME SET: set-level auth add
use WeBWorK::Utils qw(before after between);
use WeBWorK::Authen::Proctor;
use Net::IP;
use Scalar::Util qw(weaken);
use version;

################################################################################

=head1 CONSTRUCTOR

=over

=item WeBWorK::Authz->new($r)

Creates a new authorizer instance. $r is a WeBWorK::Request object. It must
already have its C<ce> and C<db> fields set.

=cut

sub new {
	my ($invocant, $r) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
		r => $r,
	};
	weaken $self -> {r};
	
	$r -> {permission_retrieval_error} = 0;
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
	my $r = $self->{r};
	my $db = $r->db;
	
	delete $self->{userID};
	delete $self->{PermissionLevel};
	
	if (defined $userID) {
		$self->{userID} = $userID;
		if (! $db -> existsUser($userID) && defined($r -> param("lis_person_sourcedid"))) {
			# This is a new user referred via an LTI link.
			# Do not attempt to cache the permission here.
			# Rather, the LTIBasic authentication module should cache the permission.
			return 1;
		}
		my $PermissionLevel;
		my $tryAgain=1;
		my $count=0;
		while ($tryAgain && $count < 2) {
			eval {$PermissionLevel = $db->getPermissionLevel($userID); # checked
				};
			if ($@) {
				$count++;
			}
			else {
				$tryAgain=0;
			}
		}
		if (defined $PermissionLevel and defined $PermissionLevel -> permission
			and $PermissionLevel -> permission ne "") {
			# cache the  permission level record in this request to avoid later database calls
			$self->{PermissionLevel} = $PermissionLevel;
		}
		elsif (defined($r -> param("lis_person_sourcedid"))
				or defined($r -> param("lis_person_sourced_id"))
				or defined($r -> param("lis_person_source_id"))
				or defined($r -> param("lis_person_sourceid"))
				or defined($r -> param("lis_person_contact_email_primary")) ) {
			# This is a new user referred via an LTI link.
			# Do not attempt to cache the permission here.
			# Rather, the LTIBasic authentication module should cache the permission.
			return 1;
		}
		elsif (defined($r -> param("oauth_nonce"))) {
			# This is a LTI attempt that doesn't have an lis_person_sourcedid username.
			croak ("Your request did not specify your username.  Perhaps you were attempting to authenticate via LTI but the LTI tool did not transmit "
				. "any variant of the lis_person_sourced_id parameter and did not transmit the lis_person_contact_email_primary parameter.");
		}
			
		else {
			if ($r->{permission_retrieval_error} == 0) {
				$r->{permission_retrieval_error}=1;
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
	if (@_ != 3 and not( @_==4 and $_[3] eq 'equal') ) {
		shift @_; # get rid of self
		my $nargs = @_;
		croak "hasPermissions called with $nargs arguments instead of the expected 2: '@_'"
	}

	my ($self, $userID, $activity, $exactness) = @_;
	if (!defined($exactness) ) {$exactness='ge';}
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	
	# this may need to be changed if we get other permission level data sources
	return 0 unless defined $db;
	
	# this may need to be changed if we want to control what unauthenticated users
	# can do with the permissions system
	return 0 unless defined $userID and $userID ne "";
	
	my $PermissionLevel;

	if (not defined($self->{userID})) { 
		#warn "self->{userID} is undefined";
		$self-> setCachedUser($userID);
	}
	
	my $cachedUserID = $self->{userID};
	if (defined $cachedUserID and $cachedUserID ne "" and $cachedUserID eq $userID) {
		# this is the same user -- we can skip the database call
		$PermissionLevel = $self->{PermissionLevel};
	} else {
		# a different user, or no user was defined before
		#my $prettyCachedUserID = defined $cachedUserID ? "'$cachedUserID'" : "undefined";
		#warn "hasPermissions called with user  $userID , but cached user is $prettyCachedUserID. Accessing database.\n";
		$PermissionLevel = $db->getPermissionLevel($userID); # checked
	}
	
	my $permission_level;
	
	if (defined $PermissionLevel) {
		$permission_level = $PermissionLevel->permission;
	} 
	elsif (defined($r -> param("lis_person_sourcedid"))){
		# This is an LTI login.  Let's see if the LITBasic authentication module will handle this.
		#return 1;
	}
	else {
		# uh, oh. this user has no permission level record!
		if ($r -> {permission_retrieval_error} != 1) {
			warn "User '$userID' has no PermissionLevel record -- assuming no permission.";
		}
		return 0;
	}
	
	unless (defined $permission_level and $permission_level ne "") {
		warn "User '$userID' has empty permission level -- assuming no permission.";
		return 0;
	}
	
	my $userRoles = $ce->{userRoles};
	my $permissionLevels = $ce->{permissionLevels};
	
	if (exists $permissionLevels->{$activity}) {
		my $activity_role = $permissionLevels->{$activity};
		if (defined $activity_role) {
			if (exists $userRoles->{$activity_role}) {
				my $role_permlevel = $userRoles->{$activity_role};
				if (defined $role_permlevel) {
 					if ($exactness eq 'ge') {
 						return $permission_level >= $role_permlevel;
 					}
 					elsif ($exactness eq 'equal') {
 						return $permission_level == $role_permlevel;
 					}
 					else {
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
			return 0; # undefiend $activity_role, no one has permission to perform $activity
		}
	} else {
#		warn "Activity '$activity' not found in \%permissionLevels -- assuming no permission.";
		return 0;
	}
}

#########################  IU Addition  ###############
sub hasExactPermissions {
	my ($self, $userID, $activity) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	
#	my $Permission = $db->getPermissionLevel($user); # checked
#	return 0 unless defined $Permission;
#	my $permissionLevel = $Permission->permission();

##
	my $PermissionLevel;

	if (not defined($self->{userID})) { 
		#warn "self->{userID} is undefined";
		$self-> setCachedUser($userID);
	}
	
	my $cachedUserID = $self->{userID};
	if (defined $cachedUserID and $cachedUserID ne "" and $cachedUserID eq $userID) {
		# this is the same user -- we can skip the database call
		$PermissionLevel = $self->{PermissionLevel};
	} else {
		# a different user, or no user was defined before
		#my $prettyCachedUserID = defined $cachedUserID ? "'$cachedUserID'" : "undefined";
		#warn "hasPermissions called with user  $userID , but cached user is $prettyCachedUserID. Accessing database.\n";
		$PermissionLevel = $db->getPermissionLevel($userID); # checked
	}
	
	my $permission_level;
	
	if (defined $PermissionLevel) {
		$permission_level = $PermissionLevel->permission;
	} else {
		# uh, oh. this user has no permission level record!
		if ($r -> {permission_retrieval_error} != 1) {
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
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlPath = $r->urlpath;

	my $node_name = $urlPath->type;

	# first check to see if we have to worried about set-level access
	#    restrictions
	return 0 unless (grep {/^$node_name$/} 
			 (qw(problem_list problem_detail gateway_quiz
			     proctored_gateway_quiz)));

	# to check set restrictions we need a set and a user
	my $setName = $urlPath->arg("setID");
	my $userName = $r->param("user");
	my $effectiveUserName = $r->param("effectiveUser");

	# if there is no input userName, then the content generator will 
	#    be forcing a login, so just bail 
	return 0 if ( ! $userName || ! $effectiveUserName );

	# do we have a cached set that we can use?
	my $set = $self->{merged_set};

	if ( $setName =~ /,v(\d+)$/ ) {
		my $verNum = $1;
		$setName =~ s/,v\d+$//;

		if ( $set && $set->set_id eq $setName && 
		     $set->user_id eq $effectiveUserName &&
		     $set->version_id eq $verNum ) {
			# then we can just use this set and skip the rest

		} elsif ( $setName eq 'Undefined_Set' and 
			  $self->hasPermissions($userName, "access_instructor_tools") ) {
				# this is the case of previewing a problem
				#    from a 'try it' link
			return 0;
		} else {
			if ($db->existsSetVersion($effectiveUserName,$setName,$verNum)) {
				$set = $db->getMergedSetVersion($effectiveUserName,$setName,$verNum);
			} else {
				return "Requested version ($verNum) of set " .
					"'$setName' is not assigned to user " .
					"$effectiveUserName.";
			}
		}
		if ( ! $set ) {
			return "Requested set '$setName' could not be found " .
				"in the database for user $effectiveUserName.";
		}
	} else {

		if ( $set && $set->set_id eq $setName &&
		     $set->user_id eq $effectiveUserName ) {
			# then we can just use this set, and skip the rest

		} else {
			if ( $db->existsUserSet($effectiveUserName,$setName) ) {
				$set = $db->getMergedSet($effectiveUserName,$setName);
			} elsif ( $setName eq 'Undefined_Set' and 
				$self->hasPermissions($userName, "access_instructor_tools") ) {
				# this is the weird case of the library
				#   browser, when we don't actually have
				#   a set to look at, but this only happens among
				#   instructor tool users.
				return 0;
			} else {
				return "Requested set '$setName' is not " .
					"assigned to user $effectiveUserName.";
			}
		}
		if ( ! $set ) {
			return "Requested set '$setName' could not be found " .
				"in the database for user $effectiveUserName.";
		}
	}
	# cache the set for future use as needed.  this should probably 
	#    be more sophisticated than this
	$self->{merged_set} = $set;

	# now we know that the set is assigned to the appropriate user; 
	#    check to see if we're trying to access a set that's not open
	if ( before($set->open_date) && 
	     ! $self->hasPermissions($userName, "view_unopened_sets") ) {
		return "Requested set '$setName' is not yet open.";
	} 

	# also check to make sure that the set is visible, or that we're
	#    allowed to view hidden sets
	# (do we need to worry about visible not being set at this point?)
	my $visible = ( $set && $set->visible ne '0' && 
			  $set->visible ne '1' ) ? 1 : $set->visible;
	if ( ! $visible && 
	     ! $self->hasPermissions($userName, "view_hidden_sets") ) { 
		return "Requested set '$setName' is not available yet.";
	}

	# check to be sure that gateways are being sent to the correct
	#    content generator
	if (defined($set->assignment_type) && 
	    $set->assignment_type =~ /gateway/ && 
	    ($node_name eq 'problem_list' || $node_name eq 'problem_detail')) {
		return "Requested set '$setName' is a test/quiz assignment " . 
			"but the regular homework assignment content " .
			"generator $node_name was called.  Try re-entering " .
			"the set from the problem sets listing page.";
	} elsif ( (! defined($set->assignment_type) ||
#		   $set->assignment_type eq 'homework') &&
		   $set->assignment_type eq 'default') &&
		  $node_name =~ /gateway/ ) {
		return "Requested set '$setName' is a homework assignment " . 
			"but the gateway/quiz content " .
			"generator $node_name was called.  Try re-entering " .
			"the set from the problem sets listing page.";
	}
		
	# and check that if we're entering a proctored assignment that we 
	#    have a valid proctor login; this is necessary to make sure that
	#    someone doesn't use the unproctored url path to obtain access
	#    to a proctored assignment.
	if (defined($set->assignment_type) && 
	    $set->assignment_type =~ /proctored/ &&
	    ! WeBWorK::Authen::Proctor->new($r,$ce,$db)->verify() ) {
		return "Requested set '$setName' is a proctored test/quiz " .
			"assignment, but no valid proctor authorization " .
			"has been obtained.";
	}

	# and whether there are ip restrictions that we need to check
	my $badIP = $self->invalidIPAddress($set);
	return $badIP if $badIP;

	return 0;
}

sub invalidIPAddress { 
# this exists as a separate routine because we need to check multiple
#    sets in Hardcopy; having this routine to check the set allows us to do
#    that for all sets individually there.

	my $self = shift;
	my $set = shift;

	my $r = $self->{r};
	my $db = $r->db;
	my $ce = $r->ce;
	my $urlPath = $r->urlpath;
#	my $setName = $urlPath->arg("setID");  # not always defined
	my $setName = $set->set_id;
	my $userName = $r->param("user");
	my $effectiveUserName = $r->param("effectiveUser");

	return 0 if (!defined($set->restrict_ip) ||
			$set->restrict_ip eq '' || $set->restrict_ip eq 'No' ||
		     $self->hasPermissions($userName,'view_ip_restricted_sets'));

	my $APACHE24 = 0;
	my $version;

	# check to see if the version is manually defined
	if (defined($ce->{server_apache_version}) &&
	    $ce->{server_apache_version}) {
	  $version = $ce->{server_apache_version};
	  # otherwise try and get it from the banner
	} elsif (Apache2::ServerUtil::get_server_banner() =~ 
		 m:^Apache/(\d\.\d+):) {
	  $version = $1;
	}

	if ($version) {
	  $APACHE24 = version->parse($version) >= version->parse('2.4');
	}

	# If its apache 2.4 then the API has changed
	my $clientIP;
	
	if ($APACHE24) {
	  $clientIP = new Net::IP($r->useragent_ip);
	} else { 	
	  $clientIP = new Net::IP($r->connection->remote_ip);
	}

	# make sure that we're using the non-versioned set name
	$setName =~ s/,v\d+$//;

	my $restrictType = $set->restrict_ip;
	my @restrictLocations = $db->getAllMergedSetLocations($effectiveUserName,$setName);
	my @locationIDs = ( map {$_->location_id} @restrictLocations );
	my @restrictAddresses = ( map {$db->listLocationAddresses($_)} @locationIDs );

	# if there are no addresses in the locations, return an error that
	#    says this
	return "Client ip address " . $clientIP->ip() . " is not allowed to " .
	    "work this assignment, because the assignment has ip address " .
	    "restrictions and there are no allowed locations associated " .
	    "with the restriction.  Contact your professor to have this " .
	    "problem resolved." if ( ! @restrictAddresses );

	# build a set of IP objects to match against
	my @restrictIPs = ( map {new Net::IP($_)} @restrictAddresses );

	# and check the clientAddress against these: is $clientIP
	#    in @restrictIPs?
	my $inRestrict = 0;
	foreach my $rIP ( @restrictIPs ) {
		if ($rIP->overlaps($clientIP) == $IP_B_IN_A_OVERLAP ||
		    $rIP->overlaps($clientIP) == $IP_IDENTICAL) {
			$inRestrict = $rIP->ip();
			last;
		}
	}

	# this is slightly complicated by having to check relax_restrict_ip
	my $badIP = '';
	if ( $restrictType eq 'RestrictTo' && ! $inRestrict ) {
		$badIP = "Client ip address " . $clientIP->ip() . 
			" is not in the list of addresses from " .
			"which this assignment may be worked.";
	} elsif ( $restrictType eq 'DenyFrom' && $inRestrict ) {
		$badIP = "Client ip address " . $clientIP->ip() . 
			" is in the list of addresses from " .
			"which this assignment may not be worked.";		
	} else {
		return 0;
	}

	# if we're here, we failed the IP check, and so need to consider
	#    if ip restrictions were relaxed.  the set we were passed in 
	#    is either the merged userset or the merged versioned userset,
	#    depending on whether the set is versioned or not

	my $relaxRestrict = $set->relax_restrict_ip;
	return $badIP if ( $relaxRestrict eq 'No' );

	if ( $set->assignment_type =~ /gateway/ ) {
		if ( $relaxRestrict eq 'AfterAnswerDate' ) {
			# in this case we need to go and get the userset,
			#    not the versioned set (which we already have)
			#    drat!
			my $userset = $db->getMergedSet($set->user_id,$setName);
			return( ! $userset || before($userset->answer_date) 
				? $badIP : 0 );
		} else {
			# this is easier; just look at the current answer date
			return( before($set->answer_date) ? $badIP : 0 );
		}
	} else {
		# the set isn't versioned, so assume that $relaxRestrict
		#    is 'AfterAnswerDate', regardless of what it actually
		#    is; 'AfterVersionAnswerDate' doesn't make sense in 
		#    this case
		return( before($set->answer_date) ? $badIP : 0 );
	}
}

=back

=cut

=head1 AUTHOR

Written by Dennis Lambe, malsyned at math.rochester.edu. Modified by Sam
Hathaway, sh002i at math.rochester.edu.

=cut


1;
