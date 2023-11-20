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

 # get the name of the appropriate Authen class, based on the %authen hash in $ce
 my $class_name = WeBWorK::Authen::class($ce, "user_module");

 # load that class
 require $class_name;

 # create an authen object
 my $authen = $class_name->new($c);

 # verify credentials
 $authen->verify or die "Authentication failed";

 # verification status is stored for quick retrieval later
 my $auth_ok = $authen->was_verified;

 # for some reason, you might want to clear that cache
 $authen->forget_verification;

=head1 DESCRIPTION

WeBWorK::Authen is the base class for all WeBWorK authentication classes. It
provides default authentication behavior which can be selectively overridden in
subclasses.

=cut

use strict;
use warnings;
use version;

use Date::Format;
use Socket qw/unpack_sockaddr_in inet_ntoa/;    # for logging
use Carp;
use Scalar::Util qw(weaken);
use Mojo::Util qw(url_escape url_unescape);

use WeBWorK::Debug;
use WeBWorK::Utils qw/writeCourseLog runtime_use/;
use WeBWorK::Localize;
use Caliper::Sensor;
use Caliper::Entity;

our $GENERIC_ERROR_MESSAGE = "";                # define in new

################################################################################
# Public API
################################################################################

=head1 FACTORY

=over

=item class($ce, $type)

This subroutine consults the given WeBWorK::CourseEnvironment object to
determine which WeBWorK::Authen subclass should be used. $type can be any key
given in the %authen hash in the course environment. If the type is not found in
the %authen hash, an exception is thrown.

=cut

sub class {
	my ($ce, $type) = @_;

	if (exists $ce->{authen}{$type}) {
		if (ref $ce->{authen}{$type} eq "ARRAY") {
			my $authen_type = shift @{ $ce->{authen}{$type} };
			#debug("ref of authen_type = |" . ref($authen_type) . "|");
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
	#debug("user_authen_module = |$user_authen_module|");
	if (!defined($user_authen_module) or ($user_authen_module eq "")) {
		$self->{error} = $c->maketext(
			"No authentication method found for your request.  If this recurs, please speak with your instructor.");
		$self->{log_error} .= "None of the specified authentication modules could handle the request.";
		return (0);
	} else {
		runtime_use $user_authen_module;
		my $authen = $user_authen_module->new($c);
		#debug("Using user_authen_module $user_authen_module: $authen\n");
		$c->authen($authen);

		return $authen->verify;
	}
}

=back

=cut

=head1 CONSTRUCTOR

=over

=item new($c)

Instantiates a new WeBWorK::Authen object for the given WeBWorK::Controller ($c).

=cut

sub new {
	my ($invocant, $c) = @_;
	my $class = ref($invocant) || $invocant;
	my $self  = { c => $c, };
	weaken $self->{c};
	#initialize
	$GENERIC_ERROR_MESSAGE = $c->maketext("Invalid user ID or password.");
	bless $self, $class;
	return $self;
}

=back

=cut

=head1 METHODS

=over

=cut

sub request_has_data_for_this_verification_module {
	#debug("Authen::request_has_data_for_this_verification_module will return a 1");
	return (1);
}

sub verify {
	debug("BEGIN VERIFY");
	my $self = shift;
	my $c    = $self->{c};

	if (!($self->request_has_data_for_this_verification_module)) {
		return ($self->call_next_authen_method());
	}

	my $result    = $self->do_verify;
	my $error     = $self->{error};
	my $log_error = $self->{log_error};

	$self->{was_verified} = $result ? 1 : 0;

	if ($self->can("site_fixup")) {
		$self->site_fixup;
	}

	if ($result) {
		$self->write_log_entry("LOGIN OK") if $self->{initial_login};
		$self->maybe_send_cookie;
		$self->set_params;
	} else {
		if (defined $log_error) {
			$self->write_log_entry("LOGIN FAILED $log_error");
		}
		$self->maybe_kill_cookie;
		# if error message has a least one non-space character.
		if (defined($error) and $error =~ /\S/) {
			$c->stash(authen_error => $error);
			# FIXME this is a hack to accomodate the webworkservice remixes
		}
	}

	my $caliper_sensor = Caliper::Sensor->new($self->{c}->ce);
	if ($caliper_sensor->caliperEnabled() && $result && $self->{initial_login}) {
		my $login_event = {
			'type'    => 'SessionEvent',
			'action'  => 'LoggedIn',
			'profile' => 'SessionProfile',
			'object'  => Caliper::Entity::webwork_app()
		};
		$caliper_sensor->sendEvents($self->{c}, [$login_event]);
	}

	debug("END VERIFY");
	debug("result $result");
	return $result;
}

=item was_verified()

Returns true if verify() returned true the last time it was called.

=cut

sub was_verified {
	my ($self) = @_;

	return 1 if exists $self->{was_verified} and $self->{was_verified};
	return 0;
}

=item forget_verification()

Future calls to was_verified() will return false, until verify() is called again and succeeds.

=cut

sub forget_verification {
	my ($self) = @_;
	my $c      = $self->{c};
	my $ce     = $c->ce;

	$self->{was_verified} = 0;

}

=back

=cut

################################################################################
# Helper functions (called by verify)
################################################################################

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
	if (defined($self->{login_type}) && $self->{login_type} eq "guest") {
		return $self->verify_practice_user;
	} else {
		return $self->verify_normal_user;
	}
}

sub trim {    # used to trim leading and trailing white space from user_id and password
			  # in get_credentials
	my $s = shift;
	# If the value was NOT defined, we want to leave it undefined, so
	# we can still catch session-timeouts and report them properly.
	# Thus we only do the following substitution if $s is defined.
	# Otherwise return the undefined value so a non-defined password
	# can be caught later by authenticate() for the case of a
	# session-timeout.
	$s =~ s/(^\s+|\s+$)//g if (defined($s));
	return $s;
}

sub get_credentials {
	my ($self) = @_;
	my $c      = $self->{c};
	my $ce     = $c->ce;
	my $db     = $c->db;
	debug("self is $self ");
	# allow guest login: if the "Guest Login" button was clicked, we find an unused
	# practice user and create a session for it.
	if ($c->param("login_practice_user")) {
		my @allowedGuestUserIDs =
			map  { $_->user_id }
			grep { $ce->status_abbrev_has_behavior($_->status, "allow_course_access") }
			$db->getUsersWhere({ user_id => { like => "$ce->{practiceUserPrefix}\%" } });

		for my $userID (List::Util::shuffle(@allowedGuestUserIDs)) {
			if (not $self->unexpired_session_exists($userID)) {
				my $newKey = $self->create_session($userID);
				$self->{initial_login} = 1;

				$self->{user_id}           = $userID;
				$self->{session_key}       = $newKey;
				$self->{login_type}        = "guest";
				$self->{credential_source} = "none";
				debug("guest user '", $userID . "' key '", $newKey . "'");
				return 1;
			}
		}

		$self->{log_error} = "no guest logins are available";
		$self->{error}     = $c->maketext("No guest logins are available. Please try again in a few minutes.");
		return 0;
	}

	my ($cookieUser, $cookieKey, $cookieTimeStamp) = $self->fetchCookie;

	if (defined $cookieUser and defined $c->param("user")) {
		if ($cookieUser ne $c->param("user")) {
			#croak ("cookieUser = $cookieUser and paramUser = ". $c->param("user") . " are different.");
			$self->maybe_kill_cookie;    # use parameter "user" rather than cookie "user";
		}
		# Use session key for verification
		# else   use cookieKey for verification
		# else    use cookie user name but use password provided by request.

		if (defined $c->param("key")) {
			$self->{user_id}           = $c->param("user");
			$self->{session_key}       = $c->param("key");
			$self->{password}          = $c->param("passwd");
			$self->{login_type}        = "normal";
			$self->{credential_source} = "params";
			$self->{user_id}           = trim($self->{user_id});
			$self->{password}          = trim($self->{password});
			debug("params user '", $self->{user_id}, "' key '", $self->{session_key}, "'");
			return 1;
		} elsif (defined $cookieKey) {
			$self->{user_id}           = $cookieUser;
			$self->{session_key}       = $cookieKey;
			$self->{cookie_timestamp}  = $cookieTimeStamp;
			$self->{login_type}        = "normal";
			$self->{credential_source} = "cookie";
			$self->{user_id}           = trim($self->{user_id});
			debug(
				"cookie user '",
				$self->{user_id}, "' key '", $self->{session_key},
				"' cookie_timestamp '",
				$self->{cookieTimeStamp}, "' "
			);
			return 1;
		} else {
			$self->{user_id}           = $cookieUser;
			$self->{session_key}       = $cookieKey;                # will be undefined
			$self->{password}          = $c->param("passwd");
			$self->{cookie_timestamp}  = $cookieTimeStamp;
			$self->{login_type}        = "normal";
			$self->{credential_source} = "params_and_cookie";
			$self->{user_id}           = trim($self->{user_id});
			$self->{password}          = trim($self->{password});
			debug(
				"params and cookie user '",
				$self->{user_id}, "' params and cookie session key = '",
				$self->{session_key},
				"' cookie_timestamp '",
				$self->{cookieTimeStamp}, "' "
			);
			return 1;
		}
	}
	# at least the user ID is available in request parameters
	if (defined $c->param("user")) {
		$self->{user_id}           = $c->param("user");
		$self->{session_key}       = $c->param("key");
		$self->{password}          = $c->param("passwd");
		$self->{login_type}        = "normal";
		$self->{credential_source} = "params";
		$self->{user_id}           = trim($self->{user_id});
		$self->{password}          = trim($self->{password});
		debug("params user '",     $self->{user_id},  "' key '", $self->{session_key}, "'");
		debug("params password '", $self->{password}, "' key '", $self->{session_key}, "'");
		return 1;
	}

	if (defined $cookieUser) {
		$self->{user_id}           = $cookieUser;
		$self->{session_key}       = $cookieKey;
		$self->{cookie_timestamp}  = $cookieTimeStamp;
		$self->{login_type}        = "normal";
		$self->{credential_source} = "cookie";
		$self->{user_id}           = trim($self->{user_id});
		debug(
			"cookie user '",
			$self->{user_id}, "' key '", $self->{session_key},
			"' cookie_timestamp '",
			$self->{cookieTimeStamp}, "' "
		);
		return 1;
	}
}

sub check_user {
	my $self  = shift;
	my $c     = $self->{c};
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;

	my $user_id = $self->{user_id};

	if (defined $user_id and $user_id eq "") {
		$self->{log_error} = "no user id specified";
		$self->{error} .= $c->maketext("You must specify a user ID.");
		return 0;
	}

	my $User = $db->getUser($user_id);

	unless ($User) {
		$self->{log_error} = "user unknown";
		$self->{error}     = $GENERIC_ERROR_MESSAGE;
		return 0;
	}

	# FIXME "fix invalid status values" used to be here, but it needs to move to $db->getUser

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
				my $debugPracticeUser = $ce->{debugPracticeUser};
				if (defined $debugPracticeUser and $user_id eq $debugPracticeUser) {
					$self->{session_key}   = $self->create_session($user_id);
					$self->{initial_login} = 1;
					return 1;
				} else {
					$self->{log_error} = "guest account in use";
					$self->{error}     = "That guest account is in use.";
					return 0;
				}
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

	if ($sessionExists and $keyMatches and $timestampValid) {
		return 1;
	} else {
		my $auth_result = $self->authenticate;

		if ($auth_result > 0) {
			$self->{session_key}   = $self->create_session($user_id);
			$self->{initial_login} = 1;
			# deny certain roles (dropped students, proctor roles)
			unless ($c->ce->status_abbrev_has_behavior($c->db->getUser($user_id)->status, "allow_course_access")) {
				$self->{log_error} = "user not allowed course access";
				$self->{error}     = "This user is not allowed to log in to this course";
				return 0;
			}
			# deny permission levels below "login" permission level
			unless ($c->authz->hasPermissions($user_id, "login")) {
				$self->{log_error} = "user not permitted to login";
				$self->{error}     = "This user is not allowed to log in to this course";
				return 0;
			}
			return 1;
		} elsif ($auth_result == 0) {
			$self->{log_error} = "authentication failed";
			$self->{error}     = $GENERIC_ERROR_MESSAGE;
			return 0;
		} else {    # ($auth_result < 0) => required data was not present
			if ($keyMatches and not $timestampValid) {
				$self->{log_error} = "inactivity timeout";
				$self->{error} .= $c->maketext("Your session has timed out due to inactivity. Please log in again.");
			}
			return 0;
		}
	}
}

#  1 == authentication succeeded
#  0 == required data was present, but authentication failed
# -1 == required data was not present (i.e. password missing)
sub authenticate {
	my $self = shift;
	my $c    = $self->{c};

	my $user_id  = $self->{user_id};
	my $password = $self->{password};

	if (defined $password) {
		return $self->checkPassword($user_id, $password);
	} else {
		return -1;
	}
}

sub maybe_send_cookie {
	my $self = shift;
	my $c    = $self->{c};
	my $ce   = $c->{ce};

	return if $c->{rpc};

	my ($cookie_user, $cookie_key, $cookie_timestamp, $setID) = $self->fetchCookie;

	# we send a cookie if any of these conditions are met:

	# (a) a cookie was used for authentication
	my $used_cookie = ($self->{credential_source} eq "cookie");

	# (b) a cookie was sent but not used for authentication, and the
	#     credentials used for authentication were the same as those in
	#     the cookie
	my $unused_valid_cookie =
		($self->{credential_source} ne "cookie"
			and defined $cookie_user
			and $self->{user_id} eq $cookie_user
			and defined $cookie_key
			and $self->{session_key} eq $cookie_key);

	# (c) the user asked to have a cookie sent and is not a guest user.
	my $user_requests_cookie = ($self->{login_type} ne "guest" and ($c->param("send_cookie") // 0))
		;    # prevent warning if "send_cookie" param is not defined.

	# (d) session management is done via cookies.
	my $session_management_via_cookies = $ce->{session_management_via} eq "session_cookie";

	debug(
		"used_cookie='",                       $used_cookie,
		"' unused_valid_cookie='",             $unused_valid_cookie,
		"' user_requests_cookie='",            $user_requests_cookie,
		"' session_management_via_cookies ='", $session_management_via_cookies,
		"'"
	);

	if ($used_cookie or $unused_valid_cookie or $user_requests_cookie or $session_management_via_cookies) {
		#debug("Authen::maybe_send_cookie is sending a cookie");
		$self->sendCookie($self->{user_id}, $self->{session_key}, $setID);
	} else {
		$self->killCookie;
	}
}

sub maybe_kill_cookie {
	my $self = shift;

	return if $self->{c}{rpc};

	$self->killCookie(@_);
}

sub set_params {
	my $self = shift;
	my $c    = $self->{c};

	# A2 - params are not non-modifiable, with no explanation or workaround given in docs. WTF!
	$c->param("user",   $self->{user_id});
	$c->param("key",    $self->{session_key});
	$c->param("passwd", "") unless $c->{rpc};

	debug("params user='", $c->param("user"), "' key='", $c->param("key"), "'");
}

################################################################################
# Password management
################################################################################

sub checkPassword {
	my ($self, $userID, $possibleClearPassword) = @_;
	my $db = $self->{c}->db;

	my $Password = $db->getPassword($userID);    # checked
	if (defined $Password) {
		# check against WW password database
		my $possibleCryptPassword = crypt $possibleClearPassword, $Password->password;
		my $dbPassword            = $Password->password;
		# This next line explicitly insures that
		# blank or null passwords from the database can never
		# succeed in matching an entered password
		# Use case: Moodle wwassignment stores null passwords and forces the creation
		# of a key -- Moodle wwassignment does not use  passwords for authentication, only keys.
		# The following line was modified to also reject cases when the database has a crypted password
		# which matches a submitted all white-space or null password by requiring that the
		# $possibleClearPassword contain some non-space character. This is intended to address
		# the issue raised in http://webwork.maa.org/moodle/mod/forum/discuss.php?d=4529 .
		# Since several authentication modules fall back to calling this function without
		# trimming the possibleClearPassword as done during get_credentials() here in
		# lib/WeBWorK/Authen.pm we do not assume that an all-white space password would have
		# already been converted to an empty string and instead explicitly test it for a non-space
		# character.
		if (($possibleClearPassword =~ /\S/) && ($dbPassword =~ /\S/) && $possibleCryptPassword eq $Password->password)
		{
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
# 		my $realCryptPassword = (getpwnam $userID)[1] or return 0;
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

################################################################################
# Session key management
################################################################################

sub unexpired_session_exists {
	my ($self, $userID) = @_;
	my $ce = $self->{c}->ce;
	my $db = $self->{c}->db;

	my $Key = $db->getKey($userID);    # checked
	return 0 unless defined $Key;
	if (time <= $Key->timestamp() + $ce->{sessionKeyTimeout}) {
		# unexpired, but leave timestamp alone
		return 1;
	} else {
		# expired -- delete key
		# NEW: no longer delete the key here -- a user re-visiting with a formerly-valid key should
		# always get a "session expired" message. formerly, if they i.e. reload the login screen
		# the message disappears, which is confusing (i claim ;)
		#$db->deleteKey($userID);
		return 0;
	}
}

# clobbers any existing session for this $userID
# if $newKey is not specified, a random key is generated
# the key is returned
# When this is called in Proctor.pm, the actual user id is passed in via $trueUserID.
# The $userID is modified in that case and will not work in the hasPermissions call.
sub create_session {
	my ($self, $userID, $newKey, $trueUserID) = @_;
	my $c  = $self->{c};
	my $ce = $c->ce;
	my $db = $c->db;

	my $timestamp = time;
	unless ($newKey) {
		my @chars  = @{ $ce->{sessionKeyChars} };
		my $length = $ce->{sessionKeyLength};

		srand;
		$newKey = join("", @chars[ map rand(@chars), 1 .. $length ]);
	}

	my $setID = !$c->authz->hasPermissions($trueUserID // $userID, 'navigation_allowed') ? $c->stash('setID') : '';

	my $Key = $db->newKey(user_id => $userID, key => $newKey, timestamp => $timestamp, set_id => $setID);

	# DBFIXME this should be a REPLACE
	eval { $db->deleteKey($userID) };
	eval { $db->addKey($Key) };
	my $fail_to_addKey = 1 if $@;
	if ($fail_to_addKey) {
		warn "Difficulty adding key for userID $userID: $@ ";
	}
	if ($fail_to_addKey) {
		eval { $db->putKey($Key) };
		warn "Couldn't put key for userid $userID either: $@" if $@;
	}

	#if ($ce -> {session_management_via} eq "session_cookie"),
	#    then the subroutine maybe_send_cookie should send a cookie.

	return $newKey;
}

# returns ($sessionExists, $keyMatches, $timestampValid)
# if $updateTimestamp is true, the timestamp on a valid session is updated
sub check_session {
	my ($self, $userID, $possibleKey, $updateTimestamp) = @_;
	my $ce = $self->{c}->ce;
	my $db = $self->{c}->db;

	my $Key = $db->getKey($userID);    # checked
	return 0 unless defined $Key;

	my $keyMatches = (defined $possibleKey and $possibleKey eq $Key->key);

	my $time_now = time();

	# Want key not be too old. Use timestamp from DB and
	# sessionKeyTimeout to determine this even when using cookies
	# as we do not trust the timestamp provided by a user's browser.
	my $timestampValid = ($time_now <= $Key->timestamp() + $ce->{sessionKeyTimeout});

	# first part of if clause is disabled for now until we figure out long term fix for using cookies
	# safely (see pull request #576)   This means that the database key time is always being used
	# even when in "session_cookie" mode
	#	if ($ce -> {session_management_via} eq "session_cookie" and defined($self->{cookie_timestamp})) {
	#		$timestampValid = (time <= $self -> {cookie_timestamp} + $ce->{sessionKeyTimeout});
	#	} else {
	if ($keyMatches and $timestampValid and $updateTimestamp) {
		$Key->timestamp(time);
		$db->putKey($Key);
	}
	#	}
	return (1, $keyMatches, $timestampValid);
}

sub killSession {
	my $self = shift;

	my $c  = $self->{c};
	my $ce = $c->{ce};
	my $db = $c->{db};

	my $caliper_sensor = Caliper::Sensor->new($ce);
	if ($caliper_sensor->caliperEnabled()) {
		my $login_event = {
			'type'    => 'SessionEvent',
			'action'  => 'LoggedOut',
			'profile' => 'SessionProfile',
			'object'  => Caliper::Entity::webwork_app()
		};
		$caliper_sensor->sendEvents($self->{c}, [$login_event]);
	}

	$self->forget_verification;
	if ($ce->{session_management_via} eq "session_cookie") {
		$self->killCookie();
	}

	my $userID = $c->param("user");
	if (defined($userID)) {
		$db->deleteKey($userID);
	}
}

################################################################################
# Cookie management
################################################################################

sub fetchCookie {
	my $self = shift;
	my $c    = $self->{c};
	my $ce   = $c->ce;

	return if $c->{rpc};

	my $cookie = $c->cookie('WeBWorKCourseAuthen.' . $c->stash('courseID'));

	if ($cookie) {
		$cookie = url_unescape($cookie);
		debug("cookie has this value: '", $cookie, "'");
		my ($userID, $key, $timestamp, $setID) = split "\t", $cookie;
		if (defined $userID and defined $key and $userID ne "" and $key ne "") {
			debug("looks good, returning userID='$userID' key='$key'");
			return ($userID, $key, $timestamp, $setID);
		} else {
			debug("malformed cookie. returning nothing.");
			return;
		}
	} else {
		debug("found no cookie for this course. returning nothing.");
		return;
	}
}

sub sendCookie {
	my ($self, $userID, $key, $setID) = @_;
	my $c  = $self->{c};
	my $ce = $c->ce;

	return if $c->{rpc};

	my $courseID = $c->stash('courseID');

	# This sets the setID in the cookie on initial login.
	$setID = $c->stash('setID')
		if !$setID
		&& $c->authen->was_verified
		&& !$c->authz->hasPermissions($userID, 'navigation_allowed');

	my $timestamp = time;

	my $cookie_params = {
		path     => $ce->{webworkURLRoot},
		samesite => $ce->{CookieSameSite},
		secure   => $ce->{CookieSecure}
	};

	# Set how long the browser should retain the cookie. Using max_age is now recommended,
	# and overrides expires, but some very old browsers only support expires.
	my $lifetime = $ce->{CookieLifeTime};
	if ($lifetime ne 'session') {
		$cookie_params->{expires} = $timestamp + $lifetime;
		$cookie_params->{max_age} = $lifetime;
	}
	# When $lifetime eq 'session' the cookie will be a "session cookie" and expire when the browser session is closed.
	# At present the CookieLifeTime setting only effects how long the browser is to told to retain the cookie.
	# Ideally, when $ce->{session_management_via} eq "session_cookie", and if the timestamp in the cookie was
	# secured again client-side tampering, the timestamp and lifetime could be used to provide ongoing session
	# authentication.

	# If the hostname is 'localhost' or '127.0.0.1', then the cookie domain must be omitted.
	my $hostname = $c->req->url->to_abs->host;
	$cookie_params->{domain} = $hostname if ($hostname ne 'localhost' && $hostname ne '127.0.0.1');

	$c->cookie(
		"WeBWorKCourseAuthen.$courseID" => url_escape("$userID\t$key\t$timestamp" . ($setID ? "\t$setID" : '')),
		$cookie_params
	);
}

sub killCookie {
	my ($self) = @_;
	my $c      = $self->{c};
	my $ce     = $c->ce;

	my $courseID = $c->stash('courseID') // '';

	my $cookie_params = {
		max_age  => 0,
		expires  => 0,
		path     => $ce->{webworkURLRoot},
		samesite => $ce->{CookieSameSite},
		secure   => $ce->{CookieSecure}
	};

	# If the hostname is 'localhost' or '127.0.0.1', then the cookie domain must be omitted.
	my $hostname = $c->req->url->to_abs->host;
	$cookie_params->{domain} = $hostname if ($hostname ne 'localhost' && $hostname ne '127.0.0.1');

	$c->cookie("WeBWorKCourseAuthen.$courseID" => '', $cookie_params);
}

# This method is only used for a user that does not have the navigation_allowed permission,
# and is used to restrict that user to a specific set that the user is authenticated with.
sub get_session_set_id {
	my $self = shift;
	my $setID;

	if ($self->{c}->ce->{session_management_via} eq 'key') {
		my $Key = $self->{c}->db->getKey($self->{c}->param('user'));
		return $Key->set_id;
	} else {
		my $setID;
		(undef, undef, undef, $setID) = $self->fetchCookie;
		return $setID;
	}
}

################################################################################
# Utilities
################################################################################

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
}

1;
