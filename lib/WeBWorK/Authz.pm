################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Authz.pm,v 1.13 2003/12/09 01:12:30 sh002i Exp $
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
	my ($invocant, $r) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
		r => $r,
	};
	bless $self, $class;
	return $self;
}

# This currently only uses two of it's arguments, but it accepts any number, in
# case in the future calculating certain permissions requires more information.
sub hasPermissions {
	my ($self, $user, $activity) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	
	my $permissionLevels = $ce->{permissionLevels};
	
	my $Permission = $db->getPermissionLevel($user); # checked
	return 0 unless defined $Permission;
	my $permissionLevel = $Permission->permission();
	if (defined $permissionLevels->{$activity}
	    and $permissionLevel >= $permissionLevels->{$activity}) {
		return 1;
	} else {
		return 0;
	}
}

1;
