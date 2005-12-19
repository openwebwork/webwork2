################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authz.pm,v 1.23 2005/09/30 19:16:52 sh002i Exp $
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
		warn "setCachedUser() called with userID undefined.\n";
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
		warn "User '$userID' has no PermissionLevel record -- assuming no permission.\n";
		return 0;
	}
	
	unless (defined $permission_level and $permission_level ne "") {
		warn "User '$userID' has empty permission level -- assuming no permission.\n";
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
					warn "Role '$activity_role' has undefined permisison level -- assuming no permission.\n";
					return 0;
				}
			} else {
				warn "Role '$activity_role' for activity '$activity' not found in \%userRoles -- assuming no permission.\n";
				return 0;
			}
		} else {
			return 0; # undefiend $activity_role, no one has permission to perform $activity
		}
	} else {
		warn "Activity '$activity' not found in \%permissionLevels -- assuming no permission.\n";
		return 0;
	}
}

=back

=cut

=head1 AUTHOR

Written by Dennis Lambe, malsyned at math.rochester.edu. Modified by Sam
Hathaway, sh002i at math.rochester.edu.

=cut

1;
