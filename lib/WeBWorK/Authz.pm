################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Authz.pm,v 1.17 2004/09/02 22:52:02 sh002i Exp $
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

=cut

use strict;
use warnings;


sub new {
	my ($invocant, $r, $ce, $db) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
		r => $r,
	};
	
	my $user = $r->param("user");   
	return 0 unless defined($user);
	my $Permission = $db->getPermissionLevel($user); # checked
	return 0 unless defined $Permission;
	my $permissionLevel = $Permission->permission();
	return 0 unless defined $permissionLevel and $permissionLevel ne "";
	
	my $permissionLevels = $ce->{permissionLevels};
	$self->{permissionLevels} = $permissionLevels;
	$self->{permissionLevel}  = $permissionLevel;
	bless $self, $class;
	return $self;
}

# This module assumes that neither the permissionLevels nor the permissionLevel
# changes between the time an authz module is created and the time it's used.

# This currently only uses two of it's arguments, but it accepts any number, in
# case in the future calculating certain permissions requires more information.
sub hasPermissions {
	my ($self, $user, $activity) = @_;
	my $permissionLevels = $self->{permissionLevels};
	my $permissionLevel = $self->{permissionLevel};
	if (exists $permissionLevels->{$activity}) {
		if (defined $permissionLevels->{$activity}) {
			return $permissionLevel >= $permissionLevels->{$activity};
		} else {
			return 0;
		}
	} else {
		die "Activity '$activity' not found in %permissionLevels. Can't continue.\n";
	}

}

1;
