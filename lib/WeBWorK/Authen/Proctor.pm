package WeBWorK::Authen::Proctor;
use parent 'WeBWorK::Authen';

=head1 NAME

WeBWorK::Authen::Proctor - Authenticate gateway test proctors.

=cut

use strict;
use warnings;

use WeBWorK::Utils       qw(x utf8Crypt isCryptedPassword);
use WeBWorK::Utils::Sets qw(test_version_is_complete);
use WeBWorK::Debug       qw(debug);

use constant GENERIC_ERROR_MESSAGE => x('Invalid user ID or password.');

# Note that throughout this module only parameters in the request body_params are accepted (other than the
# effectiveUser).  This means that only parameters for a POST request are allowed.  GET request parameters are ignored.
# This is a security measure as it is more difficult to engineer a fake POST request than a GET request.

sub verify {
	my $self = shift;
	my $c    = $self->{c};

	# At this point the usual authentication has already occurred and the user has been verified.  Note that this
	# checks the permissions of the real user, not the effective user, since it is the real user who is attempting
	# to access the proctored test (e.g., an instructor acting as a student, or a student grading their own test).
	if ($c->req->body_params->param('submitAnswers')) {
		# If the use_grade_auth_proctor option is set to 'No', then proctor authorization is not needed.  So return
		# 1 here to skip proctor authorization and proceed on to the GatewayQuiz module which will grade the test.
		my $userSet =
			$c->db->getMergedSetVersion($c->param('effectiveUser'), $c->stash->{setID}, $c->stash->{versionID});
		return 1 if $userSet && $userSet->use_grade_auth_proctor eq 'No';

		# A user with the proctor_quiz_grade permission does not need
		# separate proctor authorization to grade a proctored test.
		return 1 if $c->authz->hasPermissions($c->authen->{user_id}, 'proctor_quiz_grade');
	} else {
		# A user with the proctor_quiz_login permission does not need separate proctor authorization to enter
		# (or view) a proctored test. They can simply use their own login.
		return 1 if $c->authz->hasPermissions($c->authen->{user_id}, 'proctor_quiz_login');

		# Proctor authorization is not needed to view a version that is not a proctored test or that is complete.  For
		# the proctored routes this method is called twice in a request, once during authentication and again by
		# Authz::checkSet, so the result is saved for the second call.  The set version is also saved in the Authz
		# merged set cache so that Authz::checkSet does not need to obtain it again from the database.
		if (defined $c->stash('versionID')) {
			$c->{proctorNotRequired} //= do {
				my $setVersion = $c->authz->{merged_set};
				unless ($setVersion
					&& $setVersion->set_id eq $c->stash('setID')
					&& $setVersion->user_id eq $c->param('effectiveUser')
					&& ($setVersion->version_id // 0) == $c->stash('versionID'))
				{
					$setVersion = $c->db->getMergedSetVersion($c->param('effectiveUser'),
						$c->stash('setID'), $c->stash('versionID'));
					$c->authz->{merged_set} = $setVersion if $setVersion;
				}
				$setVersion
					&& ($setVersion->assignment_type ne 'proctored_gateway'
						|| test_version_is_complete($c, $setVersion)) ? 1 : 0;
			};
			return 1 if $c->{proctorNotRequired};
		}
	}

	return $self->SUPER::verify(@_);
}

sub get_credentials {
	my ($self) = @_;
	my $c = $self->{c};

	if (defined $c->req->body_params->param('proctor_user') || $c->req->body_params->param('set_level_proctor')) {
		$self->{user_id}           = $c->req->body_params->param('proctor_user') // '';
		$self->{set_level_proctor} = 1 if $c->req->body_params->param('set_level_proctor');
		$self->{password}          = $c->req->body_params->param('proctor_passwd');
		$self->{login_type}        = $c->req->body_params->param('submitAnswers') ? 'proctor_grading' : 'proctor_login';
		$self->{credential_source} = 'params';
		debug('proctor credential source: "params", ',
			$self->{set_level_proctor} ? 'using set level proctor' : qq{user: "$self->{user_id}"});
		return 1;
	} elsif ($c->authen->session('proctor_authorization_granted') && !$c->req->body_params->param('submitAnswers')) {
		$self->{login_type}        = 'proctor_login';
		$self->{credential_source} = 'session';
		debug('proctor credential source: "session"');
		return 1;
	}

	return 0;
}

# If proctor authorization is granted or if a set level proctor password is used then a proctor user is not needed.
# So skip checking the user.
sub check_user {
	my $self = shift;
	return 1 if $self->{credential_source} eq 'session' || $self->{set_level_proctor};
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
	if (
		$self->{login_type} eq 'proctor_login'
		&& $c->authen->session('proctor_authorization_granted')
		&& $c->authen->session('proctor_authorization_granted') eq $c->stash('setID')
		&& (
			(
				defined $c->stash('versionID')
				&& defined $c->authen->session('proctor_authorization_version')
				&& $c->authen->session('proctor_authorization_version') == $c->stash('versionID')
			)
			|| $c->authen->session('acting_proctor')
		)
		)
	{
		return 1;
	} else {
		my $auth_result = $self->authenticate;

		if ($auth_result > 0) {
			my $db    = $c->db;
			my $authz = $c->authz;

			# A proctor user may have the Proctor status which does not have the course_access behavior.
			# So don't check that here.  However, the user must be able to login.
			unless ($self->{set_level_proctor} || $authz->hasPermissions($self->{user_id}, 'login')) {
				$self->{log_error} = 'user not permitted to login';
				$self->{error}     = $c->maketext(GENERIC_ERROR_MESSAGE);
				return 0;
			}

			# As mentioned above the setID will not have the set version number if a new version is being opened.  That
			# will be added to the proctor session key by the GatewayQuiz module later.
			if ($self->{login_type} eq 'proctor_grading') {
				unless ($authz->hasPermissions($self->{user_id}, 'proctor_quiz_grade')) {
					$self->{log_error} = 'user not permitted to proctor test grade submissions';
					$self->{error} =
						$c->maketext('User [_1] is not authorized to proctor test grade submissions in this course.',
							$self->{user_id});
					return 0;
				}
				$c->authen->session('proctor_authorization_granted' => $c->stash('setID'));
				$c->authen->session('proctor_authorization_version' => $c->stash('versionID'));
			} else {
				# A UserSet is needed to determine if it is configured to skip grade proctor authorization.  Require a
				# grade_proctor permission level to start a quiz that skips authorization to grade it. This ensures that
				# a grade proctor level of authorization is always required.
				my $userSet = $self->{userSet} // $db->getMergedSet($c->param('effectiveUser'), $c->stash('setID'));

				# Only accept the set level proctor password if set, and reject any other credentials.
				if ($userSet->restricted_login_password ne '' && !$self->{set_level_proctor}) {
					$self->{log_error} = 'invalid set password to start quiz.';
					$self->{error}     = $c->maketext(GENERIC_ERROR_MESSAGE);
					return 0;
				}

				if (
					$userSet->restricted_login_password eq ''
					&& !$authz->hasPermissions($self->{user_id}, 'proctor_quiz_grade')
					&& ($userSet->use_grade_auth_proctor eq 'No'
						|| !$authz->hasPermissions($self->{user_id}, 'proctor_quiz_login'))

					)
				{
					# Set the error based on if a grade proctor was required to start, or a login proctor was required.
					if ($userSet->use_grade_auth_proctor eq 'No') {
						$self->{log_error} =
							'grade proctor required to login and user is not permitted to proctor quiz grading.';
						$self->{error} = $c->maketext(
							'This quiz requires a grade proctor to start, and user [_1] is '
								. 'not authorized to proctor test grade submissions in this course.',
							$self->{user_id}
						);
					} else {
						$self->{log_error} = 'user not permitted to proctor quiz logins.';
						$self->{error} =
							$c->maketext('User [_1] is not authorized to proctor test logins in this course.',
								$self->{user_id});
					}
					return 0;
				}
				$c->authen->session('proctor_authorization_granted' => $c->stash('setID'));
				$c->authen->session('proctor_authorization_version' => $c->stash('versionID'));
			}
			return 1;
		} else {
			delete $c->authen->session->{'proctor_authorization_granted'};
			delete $c->authen->session->{'proctor_authorization_version'};
			if ($auth_result == 0) {
				$self->{log_error} = 'authentication failed';
				$self->{error}     = $c->maketext(GENERIC_ERROR_MESSAGE);
			}
			return 0;
		}
	}
}

# This checks the password for the set level proctor if the set is configured for that.
# Otherwise it checks the password using the base class.
sub authenticate {
	my $self = shift;

	return -1 unless defined $self->{password};

	if ($self->{set_level_proctor}) {
		my $c = $self->{c};

		# First verify that this set is configured to use a set level proctor.
		my $userSet = $c->db->getMergedSet($c->param('effectiveUser'), $c->stash('setID'));
		if (!$userSet || $userSet->restricted_login_password eq '') {
			$self->write_log_entry('SET LEVEL PROCTOR: set does not have a set level proctor password');
			return 0;
		}

		debug('Checking set level proctor password.');
		my $setPassword = $userSet->restricted_login_password;
		my $password    = $self->{password} =~ s/^\s*|\s*$//gr;

		# Set level proctor passwords migrated from courses created before these passwords were stored in the set are
		# crypt hashes.
		if ($setPassword eq $password
			|| (isCryptedPassword($setPassword) && utf8Crypt($password, $setPassword) eq $setPassword))
		{
			$self->write_log_entry('SET LEVEL PROCTOR: password accepted');
			$self->{userSet} = $userSet;
			return 1;
		} else {
			$self->write_log_entry('SET LEVEL PROCTOR: password rejected');
			return 0;
		}
	}

	debug('Checking proctor password.');
	return $self->SUPER::authenticate;
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
