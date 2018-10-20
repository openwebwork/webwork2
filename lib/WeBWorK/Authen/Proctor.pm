################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen/Proctor.pm,v 1.5 2007/04/04 15:05:27 glarose Exp $
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
use WeBWorK::DB::Utils qw(grok_vsetID);

use constant GENERIC_ERROR_MESSAGE => "Invalid user ID or password.";

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
	my $db = $r->db;

	my $urlpath = $r->urlpath;
	my ($set_id, $version_id) = grok_vsetID( $urlpath->arg('setID') );
	
	# at least the user ID is available in request parameters
	if (defined $r->param("proctor_user")) {
		my $student_user_id = $r->param("effectiveUser");
		$self->{user_id} = $r->param("proctor_user");
		if ( $self->{user_id} eq $set_id ) {
			$self->{user_id} = "set_id:$set_id";
		}
		$self->{session_key} = $r->param("proctor_key");
		$self->{password} = $r->param("proctor_passwd");
		$self->{login_type} = $r->param("submitAnswers") 
			? "proctor_grading:$student_user_id" 
			: "proctor_login:$student_user_id";
		$self->{credential_source} = "params";
		return 1;
	}
}

# duplicates method in superclass, adding additional check for permission 
#    to proctor quizzes
sub check_user {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;

	my $submitAnswers = $r->param("submitAnswers");
	my $user_id = $self->{user_id};
	my $past_proctor_id = $r->param("past_proctor_user") || $user_id;

	# for set-level authentication we prepended "set_id:"
	my $show_user_id = $user_id;
	$show_user_id =~ s/^set_id://;

	if (defined $user_id and ($user_id eq "" || $show_user_id eq "")) {
		$self->{log_error} = "no user id specified";
		$self->{error} = "You must specify a user ID.";
		return 0;
	}
	
	my $User = $db->getUser($user_id);
	
	unless ($User) {
		$self->{log_error} = "user unknown";
		$self->{error} = GENERIC_ERROR_MESSAGE;
		return 0;
	}
	
	# proctors may be tas, instructors, or proctors; if the last, they
	#    do not have the behavior course_access, so we don't bother to 
	#    check that here.  they must, however, be able to login, which 
	#    it seems to me is an overlap between course permissions and 
	#    course status behaviors.

	unless ($authz->hasPermissions($user_id, "login")) {
		$self->{log_error} = "user not permitted to login";
		$self->{error} = GENERIC_ERROR_MESSAGE;
		return 0;
	}

	if ( $submitAnswers ) {
		unless ($authz->hasPermissions($user_id,"proctor_quiz_grade")) {
			# only set the error if this proctor is different 
			#    than the past proctor, implying that we have
			#    tried to grade with a new proctor id
			if ( $past_proctor_id ne $user_id ) {
				$self->{log_error} = "user not permitted " .
				    "to proctor quiz grading.";
				$self->{error} = "User $show_user_id is not " .
				    "authorized to proctor test grade " .
				    "submissions in this course.";
			}
				
			return 0;
		}
	} else {
		unless ($authz->hasPermissions($user_id,"proctor_quiz_login")) {
			$self->{log_error} =  "user not permitted to proctor " .
				"quiz logins.";
			$self->{error} = "User $show_user_id is not " .
				"authorized to proctor test logins in this " .
				"course.";
			return 0;
		}
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
	$proctor_key_id .= ",g" if $self->{login_type} =~ /^proctor_grading/;
	
	return $proctor_key_id;
}

# disable cookie functionality for proctors
sub maybe_send_cookie {}
sub fetchCookie {}
sub sendCookie {}
sub killCookie {}

1;
