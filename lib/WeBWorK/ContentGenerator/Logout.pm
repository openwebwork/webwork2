################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::Logout;
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Logout - invalidate key and display logout message.

=cut

use strict;
use warnings;

use WeBWorK::Localize;
use WeBWorK::Authen qw(write_log_entry);

async sub pre_header_initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;
	my $authen = $r->authen;

	my $userID = $r->param('user_id');

	$authen->killSession;
	$authen->WeBWorK::Authen::write_log_entry('LOGGED OUT');

	# Check to see if there is a proctor key associated with this login.  If there is a proctor user, then there must be
	# a proctored test.  So try and delete the key.
	my $proctorID = $r->param('proctor_user');
	if ($proctorID) {
		eval { $db->deleteKey("$userID,$proctorID"); };
		if ($@) {
			$self->addbadmessage("Error when clearing proctor key: $@");
		}
		# There may also be a proctor key from grading the test.
		eval { $db->deleteKey("$userID,$proctorID,g"); };
		if ($@) {
			$self->addbadmessage("Error when clearing proctor grading key: $@");
		}
	}

	# Do any special processing needed by external authentication.
	$authen->logout_user if $authen->can('logout_user');

	$self->reply_with_redirect($authen->{redirect}) if $authen->{redirect};

	return;
}

# Override the can method to disable links for the logout page.
sub can {
	my ($self, $arg) = @_;
	return $arg eq 'links' ? 0 : $self->SUPER::can($arg);
}

sub path {
	my ($self, $args) = @_;
	my $r = $self->r;

	return $r->urlpath->arg('courseID')
		if (($r->ce->{external_auth} || $r->authen->{external_auth}) && defined $r->urlpath->arg('courseID'));
	return $self->SUPER::path($args);
}

1;
