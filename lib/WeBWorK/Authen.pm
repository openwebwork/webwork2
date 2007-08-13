################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen.pm,v 1.62 2007/03/06 22:03:15 glarose Exp $
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
 my $authen = $class_name->new($r);
 
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
use WeBWorK::Cookie;
use Date::Format;
use Socket qw/unpack_sockaddr_in inet_ntoa/; # for logging
use WeBWorK::Debug;
use WeBWorK::Utils qw/writeCourseLog/;

use constant COOKIE_LIFESPAN => 60*60*24*30; # 30 days
use constant GENERIC_ERROR_MESSAGE => "Invalid user ID or password.";

use mod_perl;
use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

BEGIN {
	if (MP2) {
		require APR::SockAddr;
		APR::SockAddr->import();
		require Apache2::Connection;
		Apache2::Connection->import();
	}
}

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
		if (ref $ce->{authen}{$type} eq "HASH") {
			if (exists $ce->{authen}{$type}{$ce->{dbLayoutName}}) {
				return $ce->{authen}{$type}{$ce->{dbLayoutName}};
			} elsif (exists $ce->{authen}{$type}{"*"}) {
				return $ce->{authen}{$type}{"*"};
			} else {
				die "authentication type '$type' in %authen hash in course environemnt has no entry for db layout '", $ce->{dbLayoutName}, "' and no default entry (*)";
			}
		} else {
			return $ce->{authen}{$type};
		}
	} else {
		die "authentication type '$type' not found in course environment \%authen hash";
	}
}

=back

=cut

=head1 CONSTRUCTOR

=over

=item new($r)

Instantiates a new WeBWorK::Authen object for the given WeBWorK::Requst ($r).

=cut

sub new {
	my ($invocant, $r) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
		r => $r,
	};
	bless $self, $class;
	return $self;
}

=back

=cut

=head1 METHODS

=over

=cut

sub verify {
	debug("BEGIN VERIFY");
	my $self = shift;
	my $r = $self->{r};
	
	my $result = $self->do_verify;
	my $error = $self->{error};
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
		if ($error) {
			MP2 ? $r->notes->set(authen_error => $error) : $r->notes("authen_error" => $error);
		}
	}
	
	debug("END VERIFY");
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
	
	$self->{was_verified} = 0;
}

=back

=cut

################################################################################
# Helper functions (called by verify)
################################################################################

sub do_verify {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	
	return 0 unless $db;
	
	return 0 unless $self->get_credentials;
	
	return 0 unless $self->check_user;
	
	my $practiceUserPrefix = $ce->{practiceUserPrefix};
	if (defined($self->{login_type}) && $self->{login_type} eq "guest"){
		return $self->verify_practice_user;
	} else {
		return $self->verify_normal_user;
	}
}

sub get_credentials {
	my ($self) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	
	# allow guest login: if the "Guest Login" button was clicked, we find an unused
	# practice user and create a session for it.
	if ($r->param("login_practice_user")) {
		my $practiceUserPrefix = $ce->{practiceUserPrefix};
		# DBFIX search should happen in database
		my @guestUserIDs = grep m/^$practiceUserPrefix/, $db->listUsers;
		my @GuestUsers = $db->getUsers(@guestUserIDs);
		my @allowedGuestUsers = grep { $ce->status_abbrev_has_behavior($_->status, "allow_course_access") } @GuestUsers;
		my @allowedGestUserIDs = map { $_->user_id } @allowedGuestUsers;
		
		foreach my $userID (@allowedGestUserIDs) {
			if (not $self->unexpired_session_exists($userID)) {
				my $newKey = $self->create_session($userID);
				$self->{initial_login} = 1;
				
				$self->{user_id} = $userID;
				$self->{session_key} = $newKey;
				$self->{login_type} = "guest";
				$self->{credential_source} = "none";
				debug("guest user '", $userID. "' key '", $newKey. "'");
				return 1;
			}
		}
		
		$self->{log_error} = "no guest logins are available";
		$self->{error} = "No guest logins are available. Please try again in a few minutes.";
		return 0;
	}
	
	# at least the user ID is available in request parameters
	if (defined $r->param("user")) {
		$self->{user_id} = $r->param("user");
		$self->{session_key} = $r->param("key");
		$self->{password} = $r->param("passwd");
		$self->{login_type} = "normal";
		$self->{credential_source} = "params";
		debug("params user '", $self->{user_id}, "' password '", $self->{password}, "' key '", $self->{session_key}, "'");
		return 1;
	}
	
	my ($cookieUser, $cookieKey) = $self->fetchCookie;
	if (defined $cookieUser) {
		$self->{user_id} = $cookieUser;
		$self->{session_key} = $cookieKey;
		$self->{login_type} = "normal";
		$self->{credential_source} = "cookie";
		debug("cookie user '", $self->{user_id}, "' key '", $self->{session_key}, "'");
		return 1;
	}
}

sub check_user {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	
	my $user_id = $self->{user_id};
	
	if (defined $user_id and $user_id eq "") {
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
	
	# FIXME "fix invalid status values" used to be here, but it needs to move to $db->getUser
	
	unless ($ce->status_abbrev_has_behavior($User->status, "allow_course_access")) {
		$self->{log_error} = "user not allowed course access";
		$self->{error} = GENERIC_ERROR_MESSAGE;
		return 0;
	}
	
	unless ($authz->hasPermissions($user_id, "login")) {
		$self->{log_error} = "user not permitted to login";
		$self->{error} = GENERIC_ERROR_MESSAGE;
		return 0;
	}
	
	return 1;
}

sub verify_practice_user {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $r->ce;
	
	my $user_id = $self->{user_id};
	my $session_key = $self->{session_key};
	
	my ($sessionExists, $keyMatches, $timestampValid) = $self->check_session($user_id, $session_key, 1);
	debug("sessionExists='", $sessionExists, "' keyMatches='", $keyMatches, "' timestampValid='", $timestampValid, "'");
	
	if ($sessionExists) {
		if ($keyMatches) {
			if ($timestampValid) {
				return 1;
			} else {
				$self->{session_key} = $self->create_session($user_id);
				$self->{initial_login} = 1;
				return 1;
			}
		} else {
			if ($timestampValid) {
				my $debugPracticeUser = $ce->{debugPracticeUser};
				if (defined $debugPracticeUser and $user_id eq $debugPracticeUser) {
					$self->{session_key} = $self->create_session($user_id);
					$self->{initial_login} = 1;
					return 1;
				} else {
					$self->{log_error} = "guest account in use";
					$self->{error} = "That guest account is in use.";
					return 0;
				}
			} else {
				$self->{session_key} = $self->create_session($user_id);
				$self->{initial_login} = 1;
				return 1;
			}
		}
	} else {
		$self->{session_key} = $self->create_session($user_id);
		$self->{initial_login} = 1;
		return 1;
	}
}

sub verify_normal_user {
	my $self = shift;
	my $r = $self->{r};
	
	my $user_id = $self->{user_id};
	my $session_key = $self->{session_key};
	
	my ($sessionExists, $keyMatches, $timestampValid) = $self->check_session($user_id, $session_key, 1);
	debug("sessionExists='", $sessionExists, "' keyMatches='", $keyMatches, "' timestampValid='", $timestampValid, "'");
	
	if ($keyMatches and $timestampValid) {
		return 1;
	} else {
		my $auth_result = $self->authenticate;
		
		if ($auth_result > 0) {
			$self->{session_key} = $self->create_session($user_id);
			$self->{initial_login} = 1;
			return 1;
		} elsif ($auth_result == 0) {
			$self->{log_error} = "authentication failed";
			$self->{error} = GENERIC_ERROR_MESSAGE;
			return 0;
		} else { # ($auth_result < 0) => required data was not present
			if ($keyMatches and not $timestampValid) {
				$self->{error} = "Your session has timed out due to inactivity. Please log in again.";
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
	my $r = $self->{r};
	
	my $user_id = $self->{user_id};
	my $password = $self->{password};
	
	if (defined $password) {
		return $self->checkPassword($user_id, $password);
	} else {
		return -1;
	}
}

sub maybe_send_cookie {
	my $self = shift;
	my $r = $self->{r};
	
	my ($cookie_user, $cookie_key) = $self->fetchCookie;
	
	# we send a cookie if any of these conditions are met:
	
	# (a) a cookie was used for authentication
	my $used_cookie = ($self->{credential_source} eq "cookie");
	
	# (b) a cookie was sent but not used for authentication, and the
	#     credentials used for authentication were the same as those in
	#     the cookie
	my $unused_valid_cookie = ($self->{credential_source} ne "cookie"
		and defined $cookie_user and $self->{user_id} eq $cookie_user
		and defined $cookie_key and $self->{session_key} eq $cookie_key);
	
	# (c) the user asked to have a cookie sent and is not a guest user.
	my $user_requests_cookie = ($self->{login_type} ne "guest"
		and $r->param("send_cookie"));
	
	debug("used_cookie='", $used_cookie, "' unused_valid_cookie='", $unused_valid_cookie, "' user_requests_cookie='", $user_requests_cookie, "'");
	
	if ($used_cookie or $unused_valid_cookie or $user_requests_cookie) {
		$self->sendCookie($self->{user_id}, $self->{session_key});
	} else {
		$self->killCookie;
	}
}

sub maybe_kill_cookie {
	my $self = shift;
	$self->killCookie(@_);
}

sub set_params {
	my $self = shift;
	my $r = $self->{r};
	
	# A2 - params are not non-modifiable, with no explanation or workaround given in docs. WTF!
	$r->param("user", $self->{user_id});
	$r->param("key", $self->{session_key});
	$r->param("passwd", "");
	
	debug("params user='", $r->param("user"), "' key='", $r->param("key"), "' passwd='", $r->param("passwd"), "'");
}

################################################################################
# Password management
################################################################################

sub checkPassword {
	my ($self, $userID, $possibleClearPassword) = @_;
	my $db = $self->{r}->db;
	
	my $Password = $db->getPassword($userID); # checked
	if (defined $Password) {
		# check against WW password database
		my $possibleCryptPassword = crypt $possibleClearPassword, $Password->password;
		if ($possibleCryptPassword eq $Password->password) {
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
# 			my $db = $self->{r}->db;
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
	my $ce = $self->{r}->ce;
	my $db = $self->{r}->db;
	
	my $Key = $db->getKey($userID); # checked
	return 0 unless defined $Key;
	if (time <= $Key->timestamp()+$ce->{sessionKeyTimeout}) {
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
sub create_session {
	my ($self, $userID, $newKey) = @_;
	my $ce = $self->{r}->ce;
	my $db = $self->{r}->db;
	
	my $timestamp = time;
	unless ($newKey) {
		my @chars = @{ $ce->{sessionKeyChars} };
		my $length = $ce->{sessionKeyLength};
		
		srand;
		$newKey = join ("", @chars[map rand(@chars), 1 .. $length]);
	}
	
	my $Key = $db->newKey(user_id=>$userID, key=>$newKey, timestamp=>$timestamp);
	# DBFIXME this should be a REPLACE
	eval { $db->deleteKey($userID) };
	$db->addKey($Key);
	return $newKey;
}

# returns ($sessionExists, $keyMatches, $timestampValid)
# if $updateTimestamp is true, the timestamp on a valid session is updated
sub check_session {
	my ($self, $userID, $possibleKey, $updateTimestamp) = @_;
	my $ce = $self->{r}->ce;
	my $db = $self->{r}->db;
	
	my $Key = $db->getKey($userID); # checked
	return 0 unless defined $Key;
	
	my $keyMatches = (defined $possibleKey and $possibleKey eq $Key->key);
	my $timestampValid = (time <= $Key->timestamp()+$ce->{sessionKeyTimeout});
	
	if ($keyMatches and $timestampValid and $updateTimestamp) {
		$Key->timestamp(time);
		$db->putKey($Key);
	}
	
	return (1, $keyMatches, $timestampValid);
}

################################################################################
# Cookie management
################################################################################

sub fetchCookie {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $urlpath = $r->urlpath;
	
	my $courseID = $urlpath->arg("courseID");
	
	# AP2 - Apache2::Cookie needs $r, Apache::Cookie doesn't
	my %cookies = WeBWorK::Cookie->fetch( MP2 ? $r : () );
	my $cookie = $cookies{"WeBWorKCourseAuthen.$courseID"};
	
	if ($cookie) {
		debug("found a cookie for this course: '", $cookie->as_string, "'");
		debug("cookie has this value: '", $cookie->value, "'");
		my ($userID, $key) = split "\t", $cookie->value;
		if (defined $userID and defined $key and $userID ne "" and $key ne "") {
			debug("looks good, returning userID='$userID' key='$key'");
			return $userID, $key;
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
	my ($self, $userID, $key) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	
	my $courseID = $r->urlpath->arg("courseID");
	
	my $expires = time2str("%a, %d-%h-%Y %H:%M:%S %Z", time+COOKIE_LIFESPAN, "GMT");
	my $cookie = WeBWorK::Cookie->new($r,
		-name    => "WeBWorKCourseAuthen.$courseID",
		-value   => "$userID\t$key",
		-expires => $expires,
		-domain  => $r->hostname,
		-path    => $ce->{webworkURLRoot},
		-secure  => 0,
	);
	
	debug("about to add Set-Cookie header with this string: '", $cookie->as_string, "'");
	$r->headers_out->set("Set-Cookie" => $cookie->as_string);
}

sub killCookie {
	my ($self) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	
	my $courseID = $r->urlpath->arg("courseID");
	
	my $expires = time2str("%a, %d-%h-%Y %H:%M:%S %Z", time-60*60*24, "GMT");
	my $cookie = WeBWorK::Cookie->new($r,
		-name => "WeBWorKCourseAuthen.$courseID",
		-value => "\t",
		-expires => $expires,
		-domain => $r->hostname,
		-path => $ce->{webworkURLRoot},
		-secure => 0,
	);
	
	debug("about to add Set-Cookie header with this string: '", $cookie->as_string, "'");
	$r->headers_out->set("Set-Cookie" => $cookie->as_string);
}

################################################################################
# Utilities
################################################################################

sub write_log_entry {
	my ($self, $message) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	
	my $user_id = defined $self->{user_id} ? $self->{user_id} : "";
	my $login_type = defined $self->{login_type} ? $self->{login_type} : "";
	my $credential_source = defined $self->{credential_source} ? $self->{credential_source} : "";
	
	my ($remote_host, $remote_port);
	if (MP2) {
		$remote_host = $r->connection->remote_addr->ip_get || "UNKNOWN";
		$remote_port = $r->connection->remote_addr->port || "UNKNOWN";
	} else {
		($remote_port, $remote_host) = unpack_sockaddr_in($r->connection->remote_addr);
		$remote_host = defined $remote_host ? inet_ntoa($remote_host) : "UNKNOWN";
		$remote_port = "UNKNOWN" unless defined $remote_port;
	}
	my $user_agent = $r->headers_in->{"User-Agent"};
	
	my $log_msg = "$message user_id=$user_id login_type=$login_type credential_source=$credential_source host=$remote_host port=$remote_port UA=$user_agent";
	debug("Writing to login log: '$log_msg'.\n");
	writeCourseLog($ce, "login_log", $log_msg);
}

1;
