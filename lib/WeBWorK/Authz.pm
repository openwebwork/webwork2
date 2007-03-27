################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authz.pm,v 1.26 2006/02/02 22:29:43 sh002i Exp $
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
%permissionLevels, in the file F<conf/global.conf.dist>.

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
		my $PermissionLevel = $db->getPermissionLevel($userID); # checked
		if (defined $PermissionLevel) {
			# store permission level record in database to avoid later database calls
			$self->{PermissionLevel} = $PermissionLevel;
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
	if (@_ != 3) {
		shift @_; # get rid of self
		my $nargs = @_;
		croak "hasPermissions called with $nargs arguments instead of the expected 2: '@_'"
	}
	
	my ($self, $userID, $activity) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	
	# this may need to be changed if we get other permission level data sources
	return 0 unless defined $db;
	
	# this may need to be changed if we want to control what unauthenticated users
	# can do with the permissions system
	return 0 unless defined $userID and $userID ne "";
	
	my $PermissionLevel;
	
	my $cachedUserID = $self->{userID};
	if (defined $cachedUserID and $cachedUserID ne "" and $cachedUserID eq $userID) {
		# this is the same user -- we can skip the database call
		$PermissionLevel = $self->{PermissionLevel};
	} else {
		# a different user, or no user was defined before
		#my $prettyCachedUserID = defined $cachedUserID ? "'$cachedUserID'" : "undefined";
		#warn "hasPermissions called with user '$userID', but cached user is $prettyCachedUserID. Accessing database.\n";
		$PermissionLevel = $db->getPermissionLevel($userID); # checked
	}
	
	my $permission_level;
	
	if (defined $PermissionLevel) {
		$permission_level = $PermissionLevel->permission;
	} else {
		# uh, oh. this user has no permission level record!
		warn "User '$userID' has no PermissionLevel record -- assuming no permission.";
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
					return $permission_level >= $role_permlevel;
				} else {
					warn "Role '$activity_role' has undefined permisison level -- assuming no permission.";
					return 0;
				}
			} else {
				warn "Role '$activity_role' for activity '$activity' not found in \%userRoles -- assuming no permission.";
				return 0;
			}
		} else {
			return 0; # undefiend $activity_role, no one has permission to perform $activity
		}
	} else {
		warn "Activity '$activity' not found in \%permissionLevels -- assuming no permission.";
		return 0;
	}
}

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
			     proctored_gateway_quiz hardcopy_preselect_set)));

	# to check set restrictions we need a set and a user
	my $setName = $urlPath->arg("setID");
	my $userName = $r->param("user");
	my $effectiveUserName = $r->param("effectiveUser");

	my $set;
	if ( $setName =~ /,v(\d+)$/ ) {
		my $verNum = $1;
		$setName =~ s/,v\d+$//;
		if ($db->existsSetVersion($userName,$setName,$verNum)) {
			$set = $db->getMergedSetVersion($userName,$setName,$verNum);
		} else {
			return "Requested version ($verNum) of set " .
				"'$setName' is not assigned to user " .
				"$userName.";
		}
		if ( ! $set ) {
			return "Requested set '$setName' could not be found " .
				"in the database for user $userName.";
		}
	} else {
		if ( $db->existsUserSet($userName,$setName) ) {
			$set = $db->getMergedSet($userName,$setName);
		} else {
			return "Requested set '$setName' is not assigned " .
				"to user $userName.";
		}
		if ( ! $set ) {
			return "Requested set '$setName' could not be found " .
				"in the database for user $userName.";
		}
	}
	# cache the set for future use as needed.  this should probably 
	#    be more sophisticated than this
	$self->{merged_set} = $set;

	# now we know that the set is assigned to the appropriate user; 
	#    check to see if we're trying to access a set that's not open
	if ( before($set->open_date) && 
	     ! $self->hasPermissions($effectiveUserName, "view_unopened_sets") ) {
		return "Requested set '$setName' is not yet open.";
	} 

	# also check to make sure that the set is published, or that we're
	#    allowed to view unpublished setes
	# (do we need to worry about published not being set at this point?)
	my $published = ( $set && $set->published ne '0' && 
			  $set->published ne '1' ) ? 1 : $set->published;
	if ( ! $published && 
	     ! $self->hasPermissions($effectiveUserName, "view_unpublished_sets") ) { 
		return "Requested set '$setName' is not available yet.";
	}

	# check to be sure that gateways are being sent to the correct
	#    content generator
	if (defined($set->assignment_type) && 
	    $set->assignment_type =~ /gateway/ && 
	    ($node_name eq 'problem_list' || $node_name eq 'problem_detail')) {
		return "Requested set '$setName' is a test/quiz assignment " . 
			"but the regular homework assignment content " .
			"generator $node_name was called.";
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
	if ( $set->restrict_ip ne 'No' && ! $self->hasPermissions($effectiveUserName, 'view_ip_restricted_sets') ) {

		my $clientIP = new Net::IP($r->connection->remote_ip);

		my $restrictType = $set->restrict_ip;
		my @restrictLocations = $db->getAllMergedSetLocations($userName,$setName);
		my @locationIDs = ( map {$_->location_id} @restrictLocations );
		my @restrictAddresses = ( map {$db->listLocationAddresses($_)} @locationIDs );

		# build a set of IP objects to match against
		my @restrictIPs = ( map {new Net::IP($_)} @restrictAddresses );

		# and check the clientAddress against these: is $clientIP
		#    in @restrictIPs?
		my $inRestrict = 0;
		foreach my $rIP ( @restrictIPs ) {
			if ($rIP->overlaps($clientIP) == $IP_B_IN_A_OVERLAP ||
			    $rIP->overlaps($clientIP) == $IP_IDENTICAL) {
				$inRestrict = 1;
				last;
			}
		}

		if ( $restrictType eq 'RestrictTo' && ! $inRestrict ) {
			return "Client ip address " . $clientIP->ip() . 
				" is not in the list of addresses from " .
				"which this assignment may be worked.";
		} elsif ( $restrictType eq 'DenyFrom' && $inRestrict ) {
			return "Client ip address " . $clientIP->ip() . 
				" is in the list of addresses from " .
				"which this assignment may not be worked.";		
		}
	}
}

=back

=cut

=head1 AUTHOR

Written by Dennis Lambe, malsyned at math.rochester.edu. Modified by Sam
Hathaway, sh002i at math.rochester.edu.

=cut

1;
