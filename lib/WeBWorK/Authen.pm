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

package WeBWorK::Authen;

=head1 NAME

WeBWorK::Authen - Check user identity, manage session keys.

=head1 SYNOPSIS

    # Get the name of the appropriate Authen class, based on the %authen hash in $ce.
    my $class_name = WeBWorK::Authen::class($ce, "user_module");

    # Load that class.
    runtime_use $class_name;

    # Create an authen object.
    my $authen = $class_name->new($c);

    # Verify credentials.
    $authen->verify or die "Authentication failed";

    # Verification status is stored for quick retrieval later.
    my $auth_ok = $authen->was_verified;

    # For some reason, you might want to clear that cache.
    $authen->forget_verification;

=head1 DESCRIPTION

WeBWorK::Authen is the base class for all WeBWorK authentication classes. It
provides default authentication behavior which can be selectively overridden in
subclasses.

=cut

use strict;
use warnings;

use Date::Format;
use Scalar::Util qw(weaken);

use WeBWorK::Debug;
use WeBWorK::Utils qw(x writeCourseLog runtime_use);
use WeBWorK::Utils::TOTP;
use WeBWorK::Localize;
use Caliper::Sensor;
use Caliper::Entity;

use constant GENERIC_ERROR_MESSAGE => x('Invalid user ID or password.');

=head1 CONSTRUCTOR

Instantiates a new WeBWorK::Authen object for the given WeBWorK::Controller C<$c>.

=cut

sub new {
	my ($invocant, $c) = @_;
	my $self = { c => $c };
	weaken $self->{c};
	return bless $self, ref($invocant) || $invocant;
}

=head1 METHODS

=head2 class

Usage: C<class($ce, $type)>

This subroutine consults the given WeBWorK::CourseEnvironment object to
determine which WeBWorK::Authen subclass should be used. C<$type> can be any key
given in the C<%authen> hash in the course environment. If the type is not found in
the C<%authen> hash, an exception is thrown.

=cut

sub class {
	my ($ce, $type) = @_;

	if (exists $ce->{authen}{$type}) {
		if (ref $ce->{authen}{$type} eq "ARRAY") {
			my $authen_type = shift @{ $ce->{authen}{$type} };
			if (ref($authen_type) eq "HASH") {
				if (exists $authen_type->{ $ce->{dbLayoutName} }) {
					return $authen_type->{ $ce->{dbLayoutName} };
				} elsif (exists $authen_type->{"*"}) {
					return $authen_type->{"*"};
				} else {
					die "authentication type '$type' in the course environment has no entry for db layout '",
						$ce->{dbLayoutName}, "' and no default entry (*)";
				}
			} else {
				return $authen_type;
			}
		} elsif (ref $ce->{authen}{$type} eq "HASH") {
			if (exists $ce->{authen}{$type}{ $ce->{dbLayoutName} }) {
				return $ce->{authen}{$type}{ $ce->{dbLayoutName} };
			} elsif (exists $ce->{authen}{$type}{"*"}) {
				return $ce->{authen}{$type}{"*"};
			} else {
				die "authentication type '$type' in the course environment has no entry for db layout '",
					$ce->{dbLayoutName}, "' and no default entry (*)";
			}
		} else {
			return $ce->{authen}{$type};
		}
	} else {
		die "authentication type '$type' not found in course environment";
	}
}

sub call_next_authen_method {
	my $self = shift;
	my $c    = $self->{c};
	my $ce   = $c->{ce};

	my $user_authen_module = WeBWorK::Authen::class($ce, "user_module");
	if (!defined $user_authen_module || $user_authen_module eq '') {
		$self->{error} = $c->maketext(
			"No authentication method found for your request.  If this recurs, please speak with your instructor.");
		$self->{log_error} .= "None of the specified authentication modules could handle the request.";
		return 0;
	} else {
		runtime_use $user_authen_module;
		my $authen = $user_authen_module->new($c);
		$c->authen($authen);
		return $authen->verify;
	}
}

sub request_has_data_for_this_verification_module {
	return 1;
}

sub verify {
	my $self = shift;
	my $c    = $self->{c};

	debug('BEGIN VERIFY');

	return $self->call_next_authen_method if !$self->request_has_data_for_this_verification_module;
	my $authen_ref = ref($self);
	if ($c->ce->{courseName} eq $c->ce->{admin_course_id}
		&& !(grep {/^$authen_ref$/} @{ $c->ce->{authen}{admin_module} }))
	{
		$self->write_log_entry("Cannot authenticate into admin course using $authen_ref.");
		$c->stash(
			authen_error => $c->maketext(
				'There was an error during the login process.  Please speak to your instructor or system administrator.'
			)
		);
		return $self->call_next_authen_method();
	}

	$self->{was_verified} = $self->do_verify;

	my $remember_2fa = $c->signed_cookie('WeBWorK.2FA.' . $c->ce->{courseName});

	if ($self->{was_verified}
		&& $self->{login_type} eq 'normal'
		&& !$self->{external_auth}
		&& (!$c->{rpc} || ($c->{rpc} && !$c->stash->{disable_cookies}))
		&& $remember_2fa
		&& !$c->db->getPassword($self->{user_id})->otp_secret)
	{
		# If there is not a otp secret saved in the database, and there is a cookie saved to skip two factor
		# authentication, then delete it.  The user needs to set up two factor authentication again.
		$c->signed_cookie(
			'WeBWorK.2FA.' . $c->ce->{courseName} => 1,
			{
				max_age  => 0,
				expires  => 1,
				path     => $c->ce->{webworkURLRoot},
				samesite => $c->ce->{CookieSameSite},
				secure   => $c->ce->{CookieSecure},
				httponly => 1
			}
		);
		$remember_2fa = 0;
	}

	if ($self->{was_verified}
		&& $self->{login_type} eq 'normal'
		&& !$self->{external_auth}
		&& (!$c->{rpc} || ($c->{rpc} && !$c->stash->{disable_cookies}))
		&& $c->ce->two_factor_authentication_enabled
		&& ($self->{initial_login} || $self->session->{two_factor_verification_needed})
		&& !$remember_2fa)
	{
		$self->{was_verified} = 0;
		$self->session(two_factor_verification_needed => 1);
		$self->maybe_send_cookie;
		$self->set_params;
	} elsif ($self->{was_verified}) {
		$self->site_fixup                  if $self->can('site_fixup');
		$self->write_log_entry("LOGIN OK") if $self->{initial_login};
		$self->maybe_send_cookie;
		$self->set_params;
	} else {
		$self->write_log_entry("LOGIN FAILED $self->{log_error}") if defined $self->{log_error};
		$self->maybe_kill_cookie;
		$c->stash(authen_error => $self->{error}) if $self->{error} && $self->{error} =~ /\S/;
	}

	my $caliper_sensor = Caliper::Sensor->new($c->ce);
	if ($caliper_sensor->caliperEnabled && $self->{was_verified} && $self->{initial_login}) {
		$caliper_sensor->sendEvents(
			$c,
			[ {
				'type'    => 'SessionEvent',
				'action'  => 'LoggedIn',
				'profile' => 'SessionProfile',
				'object'  => Caliper::Entity::webwork_app()
			} ]
		);
	}

	debug("END VERIFY");
	debug("result $self->{was_verified}");
	return $self->{was_verified};
}

=head2 was_verified

Returns true if C<verify> returned true the last time it was called.

=cut

sub was_verified {
	my $self = shift;
	return $self->{was_verified};
}

=head2 forget_verification

Future calls to C<was_verified> will return false, until C<verify> is called again and succeeds.

=cut

sub forget_verification {
	my $self = shift;
	$self->{was_verified} = 0;
	return;
}

# Helper functions (called by verify)

sub do_verify {
	my $self = shift;
	my $c    = $self->{c};
	my $db   = $c->db;

	return 0 unless $db;
	debug("db ok");

	return 0 unless $self->get_credentials;
	debug("credentials ok");

	return 0 unless $self->check_user;
	debug("check user ok");

	if (defined $self->{login_type} && $self->{login_type} eq 'guest') {
		return $self->verify_practice_user;
	} else {
		return $self->verify_normal_user;
	}
}

# Used to trim leading and trailing white space from user_id and password in get_credentials.
sub trim {
	my $s = shift;
	# If the value was NOT defined, we want to leave it undefined, so we can still catch session-timeouts and report
	# them properly.  Thus we only do the following substitution if $s is defined.  Otherwise return the undefined value
	# so a non-defined password can be caught later by authenticate() for the case of a session-timeout.
	$s =~ s/(^\s+|\s+$)//g if defined $s;
	return $s;
}

sub get_credentials {
	my ($self) = @_;
	my $c      = $self->{c};
	my $ce     = $c->ce;
	my $db     = $c->db;

	debug("self is $self");

	# Allow guest login: If the "Guest Login" button was clicked, we find an unused
	# practice user and create a session for it.
	if ($c->param("login_practice_user")) {
		my @allowedGuestUserIDs =
			map  { $_->user_id }
			grep { $ce->status_abbrev_has_behavior($_->status, "allow_course_access") }
			$db->getUsersWhere({ user_id => { like => "$ce->{practiceUserPrefix}\%" } });

		for my $userID (List::Util::shuffle(@allowedGuestUserIDs)) {
			if (!$self->unexpired_session_exists($userID)) {
				$self->{user_id}           = $userID;
				$self->{login_type}        = "guest";
				$self->{credential_source} = "none";
				debug("guest user: $userID");
				return 1;
			}
		}

		$self->{log_error} = "no guest logins are available";
		$self->{error}     = $c->maketext("No guest logins are available. Please try again in a few minutes.");
		return 0;
	}

	my ($cookieUser, $cookieKey, $cookieTimeStamp) = $self->fetchCookie;

	if (defined $cookieUser && defined $c->param('user')) {
		$self->maybe_kill_cookie if $cookieUser ne $c->param('user');

		# If the "key" parameter is defined, then use the session key for verification.  Next, use the cookie key for
		# verification if that is defined.  Finally, use the cookie user name with the password provided by request.

		if (defined $c->param("key")) {
			$self->{user_id}           = trim($c->param("user"));
			$self->{session_key}       = $c->param("key");
			$self->{password}          = trim($c->param("passwd"));
			$self->{login_type}        = "normal";
			$self->{credential_source} = "params";
			debug('credential source: "params", user: "', $self->{user_id}, '" key: "', $self->{session_key}, '"');
			return 1;
		} elsif (defined $cookieKey) {
			$self->{user_id}           = $cookieUser;
			$self->{session_key}       = $cookieKey;
			$self->{cookie_timestamp}  = $cookieTimeStamp;
			$self->{login_type}        = "normal";
			$self->{credential_source} = "cookie";
			debug(
				'credential source: "cookie", user: "',
				$self->{user_id}, '", key: "', $self->{session_key},
				'", timestamp: "',
				$self->{cookie_timestamp}, '"'
			);
			return 1;
		} else {
			$self->{user_id}           = $cookieUser;
			$self->{session_key}       = $cookieKey;                  # will be undefined
			$self->{password}          = trim($c->param("passwd"));
			$self->{cookie_timestamp}  = $cookieTimeStamp;
			$self->{login_type}        = "normal";
			$self->{credential_source} = "params_and_cookie";
			debug(
				'credential soure: "cookie (password from params)", user: "',
				$self->{user_id}, '", key: "', $self->{session_key},
				'", timestamp = "',
				$self->{cookie_timestamp}, '"'
			);
			return 1;
		}
	}

	if (defined $c->param("user")) {
		$self->{user_id}           = trim($c->param("user"));
		$self->{session_key}       = $c->param("key");
		$self->{password}          = trim($c->param("passwd"));
		$self->{login_type}        = "normal";
		$self->{credential_source} = "params";
		debug('credential source: "params", user: "', $self->{user_id}, '" key: "', $self->{session_key}, '"');
		return 1;
	}

	if (defined $cookieUser) {
		$self->{user_id}           = $cookieUser;
		$self->{session_key}       = $cookieKey;
		$self->{cookie_timestamp}  = $cookieTimeStamp;
		$self->{login_type}        = "normal";
		$self->{credential_source} = "cookie";
		debug(
			'credential source: "cookie", user: "',
			$self->{user_id}, '", key: "', $self->{session_key},
			'", timestamp: "',
			$self->{cookie_timestamp}, '"'
		);
		return 1;
	}

	return 0;
}

sub check_user {
	my $self = shift;
	my $c    = $self->{c};
	my $db   = $c->db;

	my $user_id = $self->{user_id};

	if (defined $user_id && $user_id eq '') {
		$self->{log_error} = "no user id specified";
		$self->{error} .= $c->maketext("You must specify a user ID.");
		return 0;
	}

	my $User = $db->getUser($user_id);

	unless ($User) {
		$self->{log_error} = "user unknown";
		$self->{error}     = $c->maketext(GENERIC_ERROR_MESSAGE);
		return 0;
	}

	return 1;
}

sub verify_practice_user {
	my $self = shift;
	my $c    = $self->{c};
	my $ce   = $c->ce;

	my $user_id     = $self->{user_id};
	my $session_key = $self->{session_key};

	my ($sessionExists, $keyMatches, $timestampValid) = $self->check_session($user_id, $session_key, 1);
	debug("sessionExists='", $sessionExists, "' keyMatches='", $keyMatches, "' timestampValid='", $timestampValid, "'");

	if ($sessionExists) {
		if ($keyMatches) {
			if ($timestampValid) {
				return 1;
			} else {
				$self->{session_key}   = $self->create_session($user_id);
				$self->{initial_login} = 1;
				return 1;
			}
		} else {
			if ($timestampValid) {
				$self->{log_error} = "guest account in use";
				$self->{error}     = "That guest account is in use.";
				return 0;
			} else {
				$self->{session_key}   = $self->create_session($user_id);
				$self->{initial_login} = 1;
				return 1;
			}
		}
	} else {
		$self->{session_key}   = $self->create_session($user_id);
		$self->{initial_login} = 1;
		return 1;
	}
}

sub verify_normal_user {
	my $self = shift;
	my $c    = $self->{c};

	my $user_id     = $self->{user_id};
	my $session_key = $self->{session_key};

	my ($sessionExists, $keyMatches, $timestampValid) = $self->check_session($user_id, $session_key, 1);
	debug("sessionExists='", $sessionExists, "' keyMatches='", $keyMatches, "' timestampValid='", $timestampValid, "'");

	if ($sessionExists && $keyMatches && $timestampValid) {
		if ($self->session->{two_factor_verification_needed}) {
			if ($c->param('cancel_otp_verification') || !$c->param('verify_otp')) {
				delete $self->session->{two_factor_verification_needed};
				delete $c->stash->{'webwork2.database_session'};
				return 0;
			}
			# All of the below falls through to below and returns 1.  That only lets the user into the course once
			# two_factor_verification_needed is deleted from the session.
			my $otp_code = trim($c->param('otp_code'));
			if (defined $otp_code && $otp_code ne '') {
				my $password = $c->db->getPassword($self->{user_id});
				if (WeBWorK::Utils::TOTP->new(secret => $self->session->{otp_secret} // $password->otp_secret)
					->validate_otp($otp_code))
				{
					delete $self->session->{two_factor_verification_needed};

					# Store a cookie that signifies this devices skips two factor
					# authentication if the skip_2fa checkbox was checked.
					$c->signed_cookie(
						'WeBWorK.2FA.' . $c->ce->{courseName} => 1,
						{
							max_age  => 3600 * 24 * 365,            # This cookie is valid for one year.
							expires  => time + 3600 * 24 * 365,
							path     => $c->ce->{webworkURLRoot},
							samesite => $c->ce->{CookieSameSite},
							secure   => $c->ce->{CookieSecure},
							httponly => 1
						}
					) if $c->param('skip_2fa');

					# This is the case of initial setup. Save the secret from the session to the database.
					if ($self->session->{otp_secret}) {
						$password->otp_secret($self->session->{otp_secret});
						$c->db->putPassword($password);
						delete $self->session->{otp_secret};
					}
				} else {
					$c->stash(authen_error => $c->maketext('Invalid security code.'));
				}
			} else {
				$c->stash(authen_error => $c->maketext('The security code is required.'));
			}
		}
		return 1;
	} else {
		my $auth_result = $self->authenticate;

		# Don't try to obtain two factor verification in this case! Two factor authentication can only be done with an
		# existing session.  This can still be set if a session times out, for example.
		delete $self->session->{two_factor_verification_needed};

		if ($auth_result > 0) {
			# Deny certain roles (dropped students, proctor roles).
			unless ($self->{login_type} =~ /^proctor/
				|| $c->ce->status_abbrev_has_behavior($c->db->getUser($user_id)->status, "allow_course_access"))
			{
				$self->{log_error} = "user not allowed course access";
				$self->{error}     = $c->maketext('This user is not allowed to log in to this course');
				return 0;
			}
			# Deny permission levels below "login" permission level.
			unless ($c->authz->hasPermissions($user_id, "login")) {
				$self->{log_error} = "user not permitted to login";
				$self->{error}     = $c->maketext('This user is not allowed to log in to this course');
				return 0;
			}
			$self->{session_key}   = $self->create_session($user_id);
			$self->{initial_login} = 1;
			return 1;
		} elsif ($auth_result == 0) {
			$self->{log_error} = "authentication failed";
			$self->{error}     = $c->maketext(GENERIC_ERROR_MESSAGE);
			return 0;
		} else {
			# Required data was not present.
			if ($keyMatches && !$timestampValid) {
				$self->{log_error} = "inactivity timeout";
				$self->{error} .= $c->maketext("Your session has timed out due to inactivity. Please log in again.");
			}
			return 0;
		}
	}
}

# Returns 1 if authentication succeeded, returns 0 if required data was present but authentication failed,
# and returns -1 if the password is missing.
sub authenticate {
	my $self = shift;
	return defined $self->{password} ? $self->checkPassword($self->{user_id}, $self->{password}) : -1;
}

sub maybe_send_cookie {
	my $self = shift;
	my $c    = $self->{c};
	my $ce   = $c->{ce};

	return if $c->stash('disable_cookies');

	my ($cookie_user, $cookie_key, $cookie_timestamp) = $self->fetchCookie;

	# Send a cookie if any of these conditions are met:

	# (a) a cookie was used for authentication
	my $used_cookie = $self->{credential_source} eq "cookie";

	# (b) a cookie was sent but not used for authentication, and the credentials used for
	# authentication were the same as those in the cookie
	my $unused_valid_cookie =
		$self->{credential_source} ne "cookie"
		&& defined $cookie_user
		&& $self->{user_id} eq $cookie_user
		&& defined $cookie_key
		&& $self->{session_key} eq $cookie_key;

	# (c) the user asked to have a cookie sent and is not a guest user.
	my $user_requests_cookie = $self->{login_type} ne "guest" && ($c->param("send_cookie") // 0);

	# (d) session management is done via cookies.
	my $session_management_via_cookies = $ce->{session_management_via} eq "session_cookie";

	debug(
		"used_cookie='",                       $used_cookie,
		"' unused_valid_cookie='",             $unused_valid_cookie,
		"' user_requests_cookie='",            $user_requests_cookie,
		"' session_management_via_cookies ='", $session_management_via_cookies,
		"'"
	);

	if ($used_cookie || $unused_valid_cookie || $user_requests_cookie || $session_management_via_cookies) {
		$self->sendCookie($self->{user_id}, $self->{session_key});
	} else {
		$self->killCookie;
	}

	return;
}

sub maybe_kill_cookie {
	my $self = shift;
	return if $self->{c}->stash('disable_cookies');
	$self->killCookie;
	return;
}

sub set_params {
	my $self = shift;
	my $c    = $self->{c};

	$c->param('user',   $self->{user_id});
	$c->param('key',    $self->{session_key});
	$c->param('passwd', '') unless $c->{rpc} && $c->stash->{disable_cookies};

	debug("params user='", $c->param("user"), "' key='", $c->param("key"), "'");

	return;
}

# Password management

sub checkPassword {
	my ($self, $userID, $possibleClearPassword) = @_;
	my $db = $self->{c}->db;

	my $Password = $db->getPassword($userID);
	if (defined $Password) {
		# Check against the password in the database.
		my $possibleCryptPassword = crypt $possibleClearPassword, $Password->password;
		my $dbPassword            = $Password->password;
		# This next line explicitly insures that blank or null passwords from the database can never succeed in matching
		# an entered password.  This also rejects cases when the database has a crypted password which matches a
		# submitted all white-space or null password by requiring that the $possibleClearPassword contain some non-space
		# character.  Since several authentication modules fall back to calling this function without trimming the
		# possibleClearPassword as is done during get_credentials in this module, we do not assume that an all-white
		# space password would have already been converted to an empty string and instead explicitly test it for a
		# non-space character.
		if ($possibleClearPassword =~ /\S/ && $dbPassword =~ /\S/ && $possibleCryptPassword eq $Password->password) {
			$self->write_log_entry("AUTH WWDB: password accepted");
			return 1;
		} else {
			if ($self->can("site_checkPassword")) {
				$self->write_log_entry("AUTH WWDB: password rejected, deferring to site_checkPassword");
				return $self->site_checkPassword($userID, $possibleClearPassword);
			} else {
				$self->write_log_entry("AUTH WWDB: password rejected");
				return 0;
			}
		}
	} else {
		$self->write_log_entry("AUTH WWDB: user has no password record");
		return 0;
	}
}

# Site-specific password checking
#
# The site_checkPassword routine can be used to provide a hook to your institution's
# authentication system. If authentication against the  course's password database, the
# method $self->site_checkPassword($userID, $clearTextPassword) is called. If this
# method returns a true value, authentication succeeds.
#
# Here is an example site_checkPassword which checks the password against the Ohio State
# popmail server:
# 	sub site_checkPassword {
# 		my ($self, $userID, $clearTextPassword) = @_;
# 		use Net::POP3;
# 		my $pop = Net::POP3->new('pop.service.ohio-state.edu', Timeout => 60);
# 		if ($pop->login($userID, $clearTextPassword)) {
# 			return 1;
# 		}
# 		return 0;
# 	}
#
# Since you have access to the WeBWorK::Authen object, the possibilities are limitless!
# This example checks the password against the system password database and updates the
# user's password in the course database if it succeeds:
# 	sub site_checkPassword {
# 		my ($self, $userID, $clearTextPassword) = @_;
# 		my $realCryptPassword = (getpwnam $userID)[1] || return 0;
# 		my $possibleCryptPassword = crypt($possibleClearPassword, $realCryptPassword); # user real PW as salt
# 		if ($possibleCryptPassword eq $realCryptPassword) {
# 			# update WeBWorK password
# 			use WeBWorK::Utils qw(cryptPassword);
# 			my $db = $self->{c}->db;
# 			my $Password = $db->getPassword($userID);
# 			my $pass = cryptPassword($clearTextPassword);
# 			$Password->password($pass);
# 			$db->putPassword($Password);
# 			return 1;
# 		} else {
# 			return 0;
# 		}
# 	}

# Session key management

sub unexpired_session_exists {
	my ($self, $userID) = @_;
	my $Key = $self->{c}->db->getKey($userID);
	return defined $Key && time <= $Key->timestamp + $self->{c}->ce->{sessionKeyTimeout};
}

# Uses an existing session and session key if a key was found previously with a valid timestamp. Otherwise a random key
# is generated, and a new session and session key created. The key from the session is returned in any case.
sub create_session {
	my ($self, $userID) = @_;
	my $c  = $self->{c};
	my $ce = $c->ce;
	my $db = $c->db;
	my $newKey;

	if (!$c->stash->{'webwork2.database_session'} || !$c->stash->{'webwork2.database_session'}{user_id}) {
		my @chars = @{ $ce->{sessionKeyChars} };
		srand;
		$newKey = join('', @chars[ map rand(@chars), 1 .. $ce->{sessionKeyLength} ]);
		$c->stash->{'webwork2.database_session'} =
			{ user_id => $userID, key => $newKey, timestamp => time, session => {} };
	} else {
		$newKey = $c->stash->{'webwork2.database_session'}{key};
	}

	# If navigation is restricted, then set the set_id in the session.
	$self->session(set_id => $c->stash->{setID})
		if $c->stash->{setID} && !$c->authz->hasPermissions($userID, 'navigation_allowed');

	return $newKey;
}

=head2 session

This method can be used to get or set values in the session. Note that if
C<session_management_via> is "session_cookie" then the Mojolicous cookie session
is used. If C<session_management_via> is "key", then only the session in the
database is used. Note that database session is really a hash stored in
C<< $c->stash->{'webwork2.database_session} >> that has the following structure:

    { user_id => $userID, key => $key, timestamp => $timestamp, session => {} }

Only keys in the C<session> sub-hash can be set with this method. The
C<user_id>, C<key>, and C<timestamp> should be set directly in the
C<webwork2.database_session> hash.

A single value from the session can be obtained as follows.

    $authen->session('key1');

Values can be set as in the following examples.

    $authen->session(key1 => 'value 1', key2 => 'value 2');
    $authen->session({ key1 => 'value 1', key2 => 'value 2' });

The entire session can be obtained as a hash reference as follows.

    my $session = $authen->session;

=cut

sub session {
	my ($self, @params) = @_;
	my $c = $self->{c};

	# If session_management_via is not "session_cookie" (so should be "key"), then use the database session.
	if ($c->ce->{session_management_via} ne 'session_cookie' || $c->stash('disable_cookies')) {
		my $session = $c->stash->{'webwork2.database_session'} ? $c->stash->{'webwork2.database_session'}{session} : {};

		# Note that the return values are the same as those returned by the
		# Mojolicious::Controller::session method in the following cases.

		# Return the session hash.
		return $session unless @params;

		# Get session values.
		return $session->{ $params[0] } unless @params > 1 || ref $params[0];

		# Set session values.
		my $values = ref $params[0] ? $params[0] : {@params};
		@$session{ keys %$values } = values %$values;

		return $c;
	}

	# If session_management_via is "session_cookie", then use the Mojolicious cookie session.
	return $c->session(@params);
}

=head2 store_session

Store the database session. This is called after the current request has been
dispatched (in the C<after_dispatch> hook). This allows database session values
to be set or modified at any point before that is done.

=cut

sub store_session {
	my $self = shift;
	my $db   = $self->{c}->db;

	if (my $session = $self->{c}->stash->{'webwork2.database_session'}) {
		debug("Saving database session.  The database session contains\n", $self->{c}->dumper($session));

		my $key = $db->newKey($session);
		# DBFIXME:  This should be a REPLACE (but SQL::Abstract does not have REPLACE -- SQL::Abstract::mysql does!).
		eval { $db->deleteKey($session->{user_id}) };
		eval { $db->addKey($key) };
		if ($@) {
			warn "Difficulty adding key for userID $session->{user_id}: $@";
			eval { $db->putKey($key) };
			warn "Couldn't put key for userid $session->{user_id} either: $@" if $@;
		}
	} elsif ($self->{user_id}) {
		debug('Deleting database session.');
		eval { $db->deleteKey($self->{user_id}) };
	}

	return if $self->{c}->ce->{session_management_via} ne 'session_cookie' || $self->{c}->stash('disable_cookies');

	# The cookie will actually be sent by the next line of the Mojolcious::Controller::rendered method after the
	# after_dispatch hook in which this method is called.
	my $cookieSession = $self->{c}->session;
	if (keys %$cookieSession) {
		if ($cookieSession->{expires} && $cookieSession->{expires} == 1) {
			debug('The cookie session is expired.');
		} else {
			debug("The cookie session contains\n", $self->{c}->dumper($cookieSession));
		}
	}

	return;
}

=head2 check_session

Usage: C<< $authen->check_session($userID, $possibleKey, $updateTimestamp) >>

This method returns 0 if no session is found for the given C<$useriD>.  If a
session is found, then this method returns a list of three boolean values. The
first will be 1 in this case and indicates the existence of the session, the
second whether the given C<$possibleKey> matches the stored key, and the third
whether the time stamp is valid.  If C<$updateTimestamp> is true, the session
time stamp is updated.

=cut

sub check_session {
	my ($self, $userID, $possibleKey, $updateTimestamp) = @_;
	my $ce = $self->{c}->ce;
	my $db = $self->{c}->db;

	my $Key = $db->getKey($userID);
	return 0 unless defined $Key;

	my $keyMatches = defined $possibleKey && $possibleKey eq $Key->key;

	my $currentTime = time;

	my $timestampValid =
		$ce->{session_management_via} eq 'session_cookie' && defined $self->{cookie_timestamp}
		? $currentTime <= $self->{cookie_timestamp} + $ce->{sessionKeyTimeout}
		: $currentTime <= $Key->timestamp + $ce->{sessionKeyTimeout};

	if ($keyMatches && $timestampValid && $updateTimestamp) {
		$Key->timestamp($currentTime);
		$self->{c}->stash->{'webwork2.database_session'} = { $Key->toHash };
	}

	return (1, $keyMatches, $timestampValid);
}

sub killSession {
	my $self = shift;
	my $c    = $self->{c};
	my $ce   = $c->{ce};

	my $caliper_sensor = Caliper::Sensor->new($ce);
	if ($caliper_sensor->caliperEnabled) {
		$caliper_sensor->sendEvents(
			$c,
			[ {
				'type'    => 'SessionEvent',
				'action'  => 'LoggedOut',
				'profile' => 'SessionProfile',
				'object'  => Caliper::Entity::webwork_app()
			} ]
		);
	}

	$self->forget_verification;
	$self->killCookie;
	delete $c->stash->{'webwork2.database_session'};

	return;
}

# Cookie management

# Note that this does not really "fetch" the session cookie. It just gets
# the user_id, key, and timestamp from the session cookie.
sub fetchCookie {
	my $self = shift;
	my $c    = $self->{c};
	my $ce   = $c->ce;

	return if $c->stash('disable_cookies');

	my $userID    = $c->session->{user_id};
	my $key       = $c->session->{key};
	my $timestamp = $c->session->{timestamp};

	if ($userID && $key) {
		debug(qq{fetchCookie: Returning userID="$userID", key="$key", timestamp="}, $timestamp, '"');
		return ($userID, $key, $timestamp);
	} else {
		debug('fetchCookie: Session cookie does not contain valid information. Returning nothing.');
		return;
	}
}

# Note that this does not actually "send" the cookie.  It merely sets the default session values in the cookie.
# The session cookie is actually sent by Mojolicious when the response is rendered.
sub sendCookie {
	my ($self, $userID, $key) = @_;
	my $c  = $self->{c};
	my $ce = $c->ce;

	return if $c->stash('disable_cookies');

	my $courseID = $c->stash('courseID');

	$c->session(
		user_id   => $userID,
		key       => $key,
		timestamp => time,
		# Set how long the browser should retain the cookie.
		expiration => $ce->{CookieLifeTime} eq 'session' ? 0 : $ce->{CookieLifeTime}
	);

	return;
}

sub killCookie {
	my ($self) = @_;
	$self->{c}->session(expires => 1);
	return;
}

# Utilities

sub write_log_entry {
	my ($self, $message) = @_;
	my $c = $self->{c};

	my $user_id           = $self->{user_id}           // '';
	my $login_type        = $self->{login_type}        // '';
	my $credential_source = $self->{credential_source} // '';

	my $remote_host = $c->tx->remote_address || 'UNKNOWN';
	my $remote_port = $c->tx->remote_port    || 'UNKNOWN';
	my $user_agent  = $c->req->headers->user_agent;

	my $log_msg = "$message user_id=$user_id login_type=$login_type credential_source=$credential_source "
		. "host=$remote_host port=$remote_port UA=$user_agent";
	debug("Writing to login log: '$log_msg'.\n");
	writeCourseLog($c->ce, 'login_log', $log_msg);

	return;
}

1;
