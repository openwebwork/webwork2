################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen/Proctor.pm,v 1.1 2006/04/12 18:50:11 sh002i Exp $
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

package WeBWorK::Authen::Proctor;
use base qw/WeBWorK::Authen/;

=head1 NAME

WeBWorK::Authen::Proctor - Authenticate gateway test proctors.

=cut

use strict;
use warnings;
use WeBWorK::Debug;

## this is only overridden for debug logging
#sub verify {
#	debug("BEGIN PROCTOR VERIFY");
#	my $result = $_[0]->SUPER::verify(@_[1..$#_]);
#	debug("END PROCTOR VERIFY");
#	return $result;
#}

# this is similar to the method in the base class, with these differences:
#  1. no guest logins
#  2. no cookie
#  3. user_id/session_key/password come from params proctor_user/proctor_key/proctor_passwd
sub get_credentials {
	my ($self) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	
	# at least the user ID is available in request parameters
	if (defined $r->param("proctor_user")) {
		$self->{user_id} = $r->param("proctor_user");
		$self->{session_key} = $r->param("proctor_key");
		$self->{password} = $r->param("proctor_passwd");
		$self->{credential_source} = "params";
		return 1;
	}
}

# calls method in superclass, adding additional check for permission to proctor quizzes
sub check_user {
	my $self = shift;
	my $r = $self->{r};
	my $authz = $r->authz;
	
	my $super_result = $self->SUPER::check_user;
	
	return $super_result if not $super_result;
	
	my $user_id = $self->{user_id};
	
	if ($authz->hasPermissions($user_id, "proctor_quiz")) {
		return $super_result;
	} else {
		$self->write_log_entry("LOGIN FAILED $user_id - no permission to proctor");
		$self->{error} = "User $user_id is not authorized to proctor tests in this course.";
		return 0;
	}
}

# this is similar to the method in the base class, excpet that the parameters
# proctor_user, proctor_key, and proctor_passwd are used
sub set_params {
	my $self = shift;
	my $r = $self->{r};
	
	$r->param("proctor_user", $self->{user_id});
	$r->param("proctor_key", $self->{session_key});
	$r->param("proctor_passwd", "");
}

# rewrite the userID to include both the proctor's and the student's user ID
# and then call the default create_session method.
sub create_session {
	my ($self, $userID, $newKey) = @_;
	
	return $self->SUPER::create_session($self->proctor_key_id($userID), $newKey);
}

# rewrite the userID to include bith the proctor's and the student's user ID
# and then call the default check_session method.
sub check_session {
	my ($self, $userID, $possibleKey, $updateTimestamp) = @_;
	
	return $self->SUPER::check_session($self->proctor_key_id($userID), $possibleKey, $updateTimestamp);
}

# proctor key ID rewriting helper
sub proctor_key_id {
	my ($self, $userID, $newKey) = @_;
	my $r = $self->{r};
	
	my $proctor_key_id = $r->param("effectiveUser") . "," . $userID;
	$proctor_key_id .= ",g" if $r->param("submitAnswers");
	
	return $proctor_key_id;
}

# disable cookie functionality for proctors
sub maybe_send_cookie {}
sub fetchCookie {}
sub sendCookie {}
sub killCookie {}

1;
