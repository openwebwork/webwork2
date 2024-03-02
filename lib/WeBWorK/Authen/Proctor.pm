################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

use constant GENERIC_ERROR_MESSAGE => 'Invalid user ID or password.';

sub verify {
	my $self = shift;
	my $c    = $self->{c};

	# At this point the usual authentication has already occurred and the user has been verified.  If the
	# use_grade_auth_proctor option is set to 'No', then proctor authorization is not not needed.  So return
	# 1 here to skip proctor authorization and proceed on to the GatewayQuiz module which will grade the test.
	if ($c->param('submitAnswers')) {
		my ($setName, $versionNum) = grok_vsetID($c->stash('setID'));
		my $userSet = $c->db->getMergedSetVersion($c->param('effectiveUser'), $setName, $versionNum);
		return 1 if $userSet && $userSet->use_grade_auth_proctor eq 'No';
	}

	return $self->SUPER::verify(@_);
}

# this is similar to the method in the base class, with these differences:
#  1. no guest logins
#  2. no cookie
#  3. user_id/session_key/password come from params proctor_user/proctor_key/proctor_passwd
sub get_credentials {
	my ($self) = @_;
	my $c      = $self->{c};
	my $ce     = $c->ce;
	my $db     = $c->db;

	my ($set_id, $version_id) = grok_vsetID($c->stash('setID'));

	# at least the user ID is available in request parameters
	if (defined $c->param('proctor_user')) {
		my $student_user_id = $c->param('effectiveUser');
		$self->{user_id} = $c->param('proctor_user');
		if ($self->{user_id} eq $set_id) {
			$self->{user_id} = "set_id:$set_id";
		}
		$self->{session_key} = $c->param('proctor_key');
		$self->{password}    = $c->param('proctor_passwd');
		$self->{login_type} =
			$c->param('submitAnswers') ? "proctor_grading:$student_user_id" : "proctor_login:$student_user_id";
		$self->{credential_source} = 'params';
		return 1;
	}
}

# duplicates method in superclass, adding additional check for permission
#    to proctor quizzes
sub check_user {
	my $self  = shift;
	my $c     = $self->{c};
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;

	my $submitAnswers   = $c->param('submitAnswers');
	my $user_id         = $self->{user_id};
	my $past_proctor_id = $c->param('past_proctor_user') || $user_id;

	# for set-level authentication we prepended "set_id:"
	my $show_user_id = $user_id;
	$show_user_id =~ s/^set_id://;

	if (defined $user_id and ($user_id eq '' || $show_user_id eq '')) {
		$self->{log_error} = 'no user id specified';
		$self->{error}     = 'You must specify a user ID.';
		return 0;
	}

	my $User = $db->getUser($user_id);

	unless ($User) {
		$self->{log_error} = 'user unknown';
		$self->{error}     = GENERIC_ERROR_MESSAGE;
		return 0;
	}

	# proctors may be tas, instructors, or proctors; if the last, they
	#    do not have the behavior course_access, so we don't bother to
	#    check that here.  they must, however, be able to login, which
	#    it seems to me is an overlap between course permissions and
	#    course status behaviors.

	unless ($authz->hasPermissions($user_id, 'login')) {
		$self->{log_error} = 'user not permitted to login';
		$self->{error}     = GENERIC_ERROR_MESSAGE;
		return 0;
	}

	if ($submitAnswers) {
		unless ($authz->hasPermissions($user_id, 'proctor_quiz_grade')) {
			# only set the error if this proctor is different
			#    than the past proctor, implying that we have
			#    tried to grade with a new proctor id
			if ($past_proctor_id ne $user_id) {
				$self->{log_error} = 'user not permitted to proctor quiz grading.';
				$self->{error} =
					"User $show_user_id is not authorized to proctor test grade submissions in this course.";
			}

			return 0;
		}
	} else {
		# Need a UserSet to determine if it is configured to skip grade proctor
		# authorization to grade the quiz. Require a grade proctor permission level
		# to start a quiz that skips authorization to grade it. This ensures that
		# a grade proctor level of authorization is always required.
		my ($setName, $versionNum) = grok_vsetID($c->stash('setID'));
		my $userSet = $db->getMergedSet($c->param('effectiveUser'), $setName);
		unless (
			$authz->hasPermissions($user_id, 'proctor_quiz_grade')
			|| (($userSet->use_grade_auth_proctor eq 'Yes' || $userSet->restricted_login_proctor eq 'Yes')
				&& $authz->hasPermissions($user_id, 'proctor_quiz_login'))
			)
		{
			# Set the error based on if a single set password was required, a grade
			# grade proctor was required to start, or a login proctor was required.
			if ($userSet->restricted_login_proctor eq 'Yes') {
				$self->{log_error} = 'invalid set password to start quiz.';
				$self->{error}     = 'This quiz requires a set password to start, and the password was invalid.';
			} elsif ($userSet->use_grade_auth_proctor ne 'Yes') {
				$self->{log_error} =
					'grade proctor required to login and user is not permitted to proctor quiz grading.';
				$self->{error} = "This quiz requires a grade proctor to start, and user $show_user_id is not "
					. 'authorized to proctor test grade submissions in this course.';
			} else {
				$self->{log_error} = 'user not permitted to proctor quiz logins.';
				$self->{error}     = "User $show_user_id is not authorized to proctor test logins in this course.";
			}
			return 0;
		}
	}
}

# this is similar to the method in the base class, excpet that the parameters
# proctor_user, proctor_key, and proctor_passwd are used
sub set_params {
	my $self = shift;
	my $c    = $self->{c};

	$c->param('proctor_user',   $self->{user_id});
	$c->param('proctor_key',    $self->{session_key});
	$c->param('proctor_passwd', '');
}

# rewrite the userID to include both the proctor's and the student's user ID
# and then call the default create_session method.
sub create_session {
	my ($self, $userID) = @_;

	return $self->SUPER::create_session($self->proctor_key_id($userID), $userID);
}

# rewrite the userID to include both the proctor's and the student's user ID
# and then call the default check_session method.
sub check_session {
	my ($self, $userID, $possibleKey, $updateTimestamp) = @_;

	return $self->SUPER::check_session($self->proctor_key_id($userID), $possibleKey, $updateTimestamp);
}

# proctor key ID rewriting helper
sub proctor_key_id {
	my ($self, $userID, $newKey) = @_;
	my $c = $self->{c};

	my $proctor_key_id = $c->param('effectiveUser') . ',' . $userID;
	$proctor_key_id .= ',g' if $self->{login_type} =~ /^proctor_grading/;

	return $proctor_key_id;
}

# disable cookie functionality for proctors
sub maybe_send_cookie { }
sub fetchCookie       { }
sub sendCookie        { }
sub killCookie        { }

1;
