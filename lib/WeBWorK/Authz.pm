################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::Authz;

=head1 NAME

WeBWorK::Authz - check user permissions.

=cut

use strict;
use warnings;

# WeBWorK::Authz->new($r, $ce, $db)
sub new($$$$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	($self->{r}, $self->{ce}, $self->{db}) = @_;
	bless $self, $class;
	return $self;
}

# This currently only uses two of it's arguments, but it accepts any number, in
# case in the future calculating certain permissions requires more information.
sub hasPermissions {
	my ($self, $user, $activity) = @_;
	my $r = $self->{r};
	my $courseEnvironment = $self->{ce};
	my $permissionLevels = $courseEnvironment->{permissionLevels};
	
	my $permissionLevel = $self->{db}->getPermissionLevel($user)->permission();
	if (defined $permissionLevels->{$activity}
	    and $permissionLevel >= $permissionLevels->{$activity}) {
		return 1;
	} else {
		return 0;
	}
}

1;
