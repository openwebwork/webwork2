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
use base 'WeBWorK::Authen';

=head1 NAME

WeBWorK::Authen::Proctor - Authenticate gateway test proctors.

=cut

use strict;
use warnings;

use WeBWorK::Utils qw(x);
use WeBWorK::DB::Utils qw(grok_vsetID);

use constant GENERIC_ERROR_MESSAGE => x('Invalid user ID or password.');

# Note that throughout this module only parameters in the request body_params are accepted (other than the
# effectiveUser).  This means that only parameters for a POST request are allowed.  GET request parameters are ignored.
# This is a security measure as it is more difficult to engineer a fake POST request than a GET request.

sub verify {
	my $self = shift;
	my $c    = $self->{c};

	# At this point the usual authentication has already occurred and the user has been verified.  If the
	# use_grade_auth_proctor option is set to 'No', then proctor authorization is not not needed.  So return
	# 1 here to skip proctor authorization and proceed on to the GatewayQuiz module which will grade the test.
	if ($c->req->body_params->param('submitAnswers')) {
		my ($setName, $versionNum) = grok_vsetID($c->stash('setID'));
		my $userSet = $c->db->getMergedSetVersion($c->param('effectiveUser'), $setName, $versionNum);
		return 1 if $userSet && $userSet->use_grade_auth_proctor eq 'No';
	}

	return $self->SUPER::verify(@_);
}

# This is similar to the method in the base class, with these differences:
#  1. no guest logins
#  2. no cookie
#  3. no session key
#  4. user_id/password come from POST request params proctor_user/proctor_passwd
sub get_credentials {
	my ($self) = @_;
	my $c = $self->{c};

	my ($set_id, $version_id) = grok_vsetID($c->stash('setID'));

	if (defined $c->req->body_params->param('proctor_user')) {
		$self->{user_id}           = $c->req->body_params->param('proctor_user');
		$self->{user_id}           = "set_id:$set_id" if $self->{user_id} eq $set_id;
		$self->{password}          = $c->req->body_params->param('proctor_passwd');
		$self->{login_type}        = $c->req->body_params->param('submitAnswers') ? 'proctor_grading' : 'proctor_login';
		$self->{credential_source} = 'params';
		return 1;
	} elsif ($c->authen->session('proctor_authorization_granted') && !$c->req->body_params->param('submitAnswers')) {
		$self->{login_type}        = 'proctor_login';
		$self->{credential_source} = 'session';
		return 1;
	}

	return 0;
}

# If proctor authorization is granted a proctor user is not needed.  So skip checking the user.
sub check_user {
	my $self = shift;
	return 1 if $self->{credential_source} eq 'session';
	return $self->SUPER::check_user;
}

# This is similar to the method in the base class except that instead of creating a session, this just sets the
# "proctor_authorization_granted" value in the session.  Note that the session used is the session of the original
# authentication module for this request.  Furthermore it checks the proctor user permissions instead of the usual user
# login permissions.
sub verify_normal_user {
	my $self = shift;
	my $c    = $self->{c};

	# If the test is being submitted, then proctor credentials are always required.  Note that if use_grade_auth_proctor
	# is 'No', then the verify method will have returned 1, and this never happens.  For an ongoing login session, only
	# a key with versioned set information is accepted, and that version must match the requested set version.  The set
	# id will not have a version when opening a new version. For that new proctor credentials are required.
	if ($self->{login_type} eq 'proctor_login'
		&& $c->stash('setID') =~ /,v\d+$/
		&& $c->authen->session('proctor_authorization_granted')
		&& $c->authen->session('proctor_authorization_granted') eq $c->stash('setID'))
	{
		return 1;
	} else {
		my $auth_result = $self->authenticate;

		if ($auth_result > 0) {
			my $db    = $c->db;
			my $authz = $c->authz;

			my $user_id = $self->{user_id};

			# Prepended "set_id:" for set-level authentication.
			my $show_user_id = $user_id;
			$show_user_id =~ s/^set_id://;

			# A proctor user may have the Proctor status which does not have the course_access behavior.
			# So don't check that here.  However, the user must be able to login.
			unless ($authz->hasPermissions($user_id, 'login')) {
				$self->{log_error} = 'user not permitted to login';
				$self->{error}     = $c->maketext(GENERIC_ERROR_MESSAGE);
				return 0;
			}

			# As mentioned above the setID will not have the set version number if a new version is being opened.  That
			# will be added to the proctor session key by the GatewayQuiz module later.
			if ($self->{login_type} eq 'proctor_grading') {
				unless ($authz->hasPermissions($user_id, 'proctor_quiz_grade')) {
					$self->{log_error} = 'user not permitted to proctor test grade submissions';
					$self->{error} =
						$c->maketext('User [_1] is not authorized to proctor test grade submissions in this course.',
							$show_user_id);
					return 0;
				}
				$c->authen->session('proctor_authorization_granted' => $c->stash('setID'));
			} else {
				# A UserSet is needed to determine if it is configured to skip grade proctor authorization.  Require a
				# grade_proctor permission level to start a quiz that skips authorization to grade it. This ensures that
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
					# proctor was required to start, or a login proctor was required.
					if ($userSet->restricted_login_proctor eq 'Yes') {
						$self->{log_error} = 'invalid set password to start quiz.';
						$self->{error} =
							$c->maketext('This quiz requires a set password to start, and the password was invalid.');
					} elsif ($userSet->use_grade_auth_proctor ne 'Yes') {
						$self->{log_error} =
							'grade proctor required to login and user is not permitted to proctor quiz grading.';
						$self->{error} = $c->maketext(
							'This quiz requires a grade proctor to start, and user [_1] is '
								. 'not authorized to proctor test grade submissions in this course.',
							$show_user_id
						);
					} else {
						$self->{log_error} = 'user not permitted to proctor quiz logins.';
						$self->{error} =
							$c->maketext("User [_1] is not authorized to proctor test logins in this course.",
								$show_user_id);
					}
					return 0;
				}
				$c->authen->session('proctor_authorization_granted' => $c->stash('setID'));
			}
			return 1;
		} else {
			delete $c->authen->session->{'proctor_authorization_granted'};
			if ($auth_result == 0) {
				$self->{log_error} = "authentication failed";
				$self->{error}     = $c->maketext(GENERIC_ERROR_MESSAGE);
			}
			return 0;
		}
	}
}

# This is similar to the method in the base class, except that the parameters
# proctor_user and proctor_passwd are used and there is no session_key.
sub set_params {
	my $self = shift;
	my $c    = $self->{c};

	$c->param('proctor_user',   $self->{user_id});
	$c->param('proctor_passwd', '');

	return;
}

# Disable the session for proctors (instead use the session of the user authentication module).
sub create_session { }
sub check_session  { }

# Prevent this module from setting or using cookie authentication parameters. This does not disable cookies.
# Don't set the disable_cookies stash value for this because cookie session values still need to be set and used,
# just not the authentication parameters user_id, key, and timestamp.
sub maybe_send_cookie { }
sub maybe_kill_cookie { }
sub fetchCookie       { }
sub sendCookie        { }
sub killCookie        { }

1;
