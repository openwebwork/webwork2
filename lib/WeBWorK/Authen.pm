################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Authen.pm,v 1.34 2004/10/09 03:03:13 gage Exp $
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

=cut

use strict;
use warnings;
use Apache::Cookie;
use Date::Format;

use constant COOKIE_LIFESPAN => 60*60*24*30; # 30 days

sub new {
	my ($invocant, $r) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
		r => $r,
	};
	bless $self, $class;
	return $self;
}

sub checkPassword($$$) {
	my ($self, $userID, $possibleClearPassword) = @_;
	my $db = $self->{r}->db;
	
	my $Password = $db->getPassword($userID); # checked
	return 0 unless defined $Password;
	
	my $possibleCryptPassword = crypt($possibleClearPassword, $Password->password());
	return $possibleCryptPassword eq $Password->password();
}

sub generateKey($$) {
	my ($self, $userID) = @_;
	my $ce = $self->{r}->ce;
	
	my @chars = @{ $ce->{sessionKeyChars} };
	my $length = $ce->{sessionKeyLength};
	
	srand;
	my $key = join ("", @chars[map rand(@chars), 1 .. $length]);
	return WeBWorK::DB::Record::Key->new(user_id=>$userID, key=>$key, timestamp=>time);
}

sub checkKey($$$) {
	my ($self, $userID, $possibleKey) = @_;
	my $ce = $self->{r}->ce;
	my $db = $self->{r}->db;
	
	my $Key = $db->getKey($userID); # checked
	return 0 unless defined $Key;
	if (time <= $Key->timestamp()+$ce->{sessionKeyTimeout}) {
		if ($possibleKey eq $Key->key()) {
			# unexpired and matches -- update timestamp
			$Key->timestamp(time);
			$db->putKey($Key);
			return 1;
		} else {
			# unexpired but doesn't match -- leave timestamp alone
			# we do this to keep an attacker from keeping someone's session
			# alive. (yeah, we don't match IPs.)
			return 0;
		}
	} else {
		# expired -- delete key
		$db->deleteKey($userID);
		return 0;
	}
}

sub unexpiredKeyExists($$) {
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
		$db->deleteKey($userID);
		return 0;
	}
}

sub fetchCookie {
	my ($self, $user, $key) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $urlpath = $r->urlpath;
	
	my $courseID = $urlpath->arg("courseID");
	
	my %cookies = Apache::Cookie->fetch;
	my $cookie = $cookies{"WeBWorKCourseAuthen.$courseID"};
	
	if ($cookie) {
		#warn __PACKAGE__, ": fetchCookie: found a cookie for this course: \"", $cookie->as_string, "\"\n";
		#warn __PACKAGE__, ": fetchCookie: cookie has this value: \"", $cookie->value, "\"\n";
		my ($userID, $key) = split "\t", $cookie->value;
		if (defined $userID and defined $key and $userID ne "" and $key ne "") {
			#warn __PACKAGE__, ": fetchCookie: looks good, returning userID=$userID key=$key\n";
			return $userID, $key;
		} else {
			#warn __PACKAGE__, ": fetchCookie: malformed cookie. returning empty strings.\n";
			return "", "";
		}
	} else {
		#warn __PACKAGE__, ": fetchCookie: found no cookie for this course. returning empty strings.\n";
		return "", "";
	}
}

sub sendCookie {
	my ($self, $userID, $key) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	
	my $courseID = $r->urlpath->arg("courseID");
	
	my $expires = time2str("%a, %d-%h-%Y %H:%M:%S %Z", time+COOKIE_LIFESPAN, "GMT");
	my $cookie = Apache::Cookie->new($r,
		-name    => "WeBWorKCourseAuthen.$courseID",
		-value   => "$userID\t$key",
		-expires => $expires,
		-domain  => $r->hostname,
		-path    => $ce->{webworkURLRoot},
		-secure  => 0,
	);
	my $cookieString = $cookie->as_string;
	
	#warn __PACKAGE__, ": sendCookie: about to add Set-Cookie header with this string: \"", $cookie->as_string, "\"\n";
	$r->headers_out->set("Set-Cookie" => $cookie->as_string);
}

sub killCookie {
	my ($self) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	
	my $courseID = $r->urlpath->arg("courseID");
	
	my $expires = time2str("%a, %d-%h-%Y %H:%M:%S %Z", time-60*60*24, "GMT");
	my $cookie = Apache::Cookie->new($r,
		-name => "WeBWorKCourseAuthen.$courseID",
		-value => "\t",
		-expires => $expires,
		-domain => $r->hostname,
		-path => $ce->{webworkURLRoot},
		-secure => 0,
	);
	my $cookieString = $cookie->as_string;
	
	#warn __PACKAGE__, ": killCookie: about to add Set-Cookie header with this string: \"", $cookie->as_string, "\"\n";
	$r->headers_out->set("Set-Cookie" => $cookie->as_string);
}

# verify will return 1 if the person is who they say the are. If the
# verification failed because of of invalid authentication data, a note will be
# written in the request explaining why it failed. If the request failed because
# no authentication data was provided, however, no note will be written, as this
# is expected to happen whenever someone types in a URL manually, and is not
# considered an error condition.
sub verify($) {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	
	my $practiceUserPrefix = $ce->{practiceUserPrefix};
	my $debugPracticeUser = $ce->{debugPracticeUser};
	
	my $force_passwd_authen = $r->param('force_passwd_authen');
	my $login_practice_user = $r->param('login_practice_user');
	my $send_cookie = $r->param("send_cookie");
	
	my $error;
	my $failWithoutError = 0;
	my $credentialSource = "params";
	
	my $user = $r->param('user');
	my $passwd = $r->param('passwd');
	my $key = $r->param('key');
	
	my ($cookieUser, $cookieKey) = $self->fetchCookie;
	#warn __PACKAGE__, ": verify: cookieUser=$cookieUser cookieKey=$cookieKey\n";
	
	VERIFY: {
		# This block is here so we can "last" out of it when we've
		# decided whether we're going to succeed or fail.
		
		if ($login_practice_user) {
			# ignore everything else, find an unused practice user
			my $found = 0;
			foreach my $userID (sort grep m/^$practiceUserPrefix/, $db->listUsers) {
				if (not $self->unexpiredKeyExists($userID)) {
					my $Key = $self->generateKey($userID);
					$db->addKey($Key);
					$r->param("user", $userID);
					$r->param("key", $Key->key);
					$found = 1;
					last;
				}
			}
			unless ($found) {
				$error = "No practice users are available. Please try again in a few minutes.";
			}
			last VERIFY;
		}
		
		# no authentication data was given. this is OK.
		unless (defined $user or defined $passwd or defined $key) {
			# check to see if a cookie was sent by the browser. if so, use the
			# user and key from the cookie for authentication. note that the
			# cookie is only used if no credentials are sent as parameters.
			if ($cookieUser and $cookieKey) {
				$user = $cookieUser;
				$key = $cookieKey;
				$r->param("user", $user);
				$r->param("key", $key);
				$credentialSource = "cookie";
			} else {
				$failWithoutError = 1;
				last VERIFY;
			}
		}
		
		if (defined $user and $force_passwd_authen) {
			$failWithoutError = 1;
			last VERIFY;
		}
		
		# no user was supplied.  somebody's building their own GET
		unless ($user) {
			$error = "You must specify a username.";
			last VERIFY;
		}
		########################################################
		# Make sure user is in the database
		########################################################

		my $userRecord    =   $db->getUser($user);
		unless (defined $userRecord) { # checked
			$error = "There is no account for $user in this course.";
			last VERIFY;
		}
		########################################################
		# Make sure the user's status is defined.
		########################################################
		unless (defined $userRecord->status and 
		        defined($ce->{siteDefaults}->{status}->{$userRecord->status})
		        ) {
			$userRecord-> status('C');
			#FIXME -- still need to save this value to the database.
			$db->putUser($userRecord);
			warn "Setting status for user $user to C.  It was previously undefined or miss defined.";
		}
		if ($ce->{siteDefaults}->{status}->{$userRecord->status} eq "Drop") {
			$error  = "The user $user has been dropped from this course. ";
			last VERIFY;
		}
		########################################################
		# it's a practice user.
		########################################################
		if ($practiceUserPrefix and $user =~ /^$practiceUserPrefix/) {
			# we're not interested in a practice user's password
			$r->param("passwd", "");
	

			# we've got a key.
			if ($key) {
				if ($self->checkKey($user, $key)) {
					# they key was valid.
					last VERIFY;
				} else {
					# the key was invalid.
					$error = "Your session has timed out due to inactivity. You must login again.";
					last VERIFY;
				}
			}
			
			# -- here we know that a key was not supplied. --
			
			# it's the debug user.
			if ($debugPracticeUser and $user eq $debugPracticeUser) {
				# clobber any existing session, valid or not.
				my $Key = $self->generateKey($user);
				eval { $db->deleteKey($user) };
				$db->addKey($Key);
				$r->param("key", $Key->key());
				last VERIFY;
			}
			
			# an unexpired key exists -- the account is in use.
			if ($self->unexpiredKeyExists($user)) {
				$error = "That practice account is in use.";
				last VERIFY;
			}
			
			# here we know the account is not in use, so we
			# generate a new  session key (unexpiredKeyExists
			# deleted any expired key) and succeed!
			my $Key = $self->generateKey($user);
			$db->addKey($Key);
			$r->param("key", $Key->key());
			last VERIFY;
		}
		
		# -- here we know it's a regular user. --
	
		
		# a key was supplied.
		if ($key) {
			# we're not interested in a user's password if they're
			# supplying a key unless that key comes from a cookie in which case
			# the key could be expired but the password good.
			$r->param("passwd", "") unless $cookieKey;
			
			if ($self->checkKey($user, $key)) {
				# valid key, so succeed.
				last VERIFY;
			} else {
				# invalid key. the login page doesn't propogate the key,
				# so we know this is an expired session.
				unless ($passwd) {
					$error = "Your session has timed out due to inactivity. You must login again.";
					last VERIFY;
				}
			}
		}

		#########################################################
		# a password was supplied.
		#########################################################
		if ($passwd) {

			if ($self->checkPassword($user, $passwd)) {
				# valid password, so create a new session. (we don't want
				# to reuse an old one, duh.)
				my $Key = $self->generateKey($user);
				eval { $db->deleteKey($user) };
				$db->addKey($Key);
				$r->param("key", $Key->key());
				# also delete the password
				$r->param("passwd", "");
				last VERIFY;
			} else {
				# incorrect password. fail.
				$error = "Incorrect username or password.";
				last VERIFY;
			}
		}
		
		# neither a key or a password were supplied.
		$error = "You must enter a password."
	}
	
	if (defined $error) {
		# authentication failed, store the error message
		$r->notes("authen_error",$error);
		
		# if we got a cookie, it probably has incorrect information in it. so
		# we want to get rid of it
		if ($cookieUser or $cookieKey) {
			#warn "fail with error: killing cookie";
			$self->killCookie;
		}
		
		return 0;
	} elsif ($failWithoutError) {
		# authentication failed, but we don't have any error message to report
		
		# if we got a cookie, it probably has incorrect information in it. so
		# we want to get rid of it
		if ($cookieUser or $cookieKey) {
			#warn "fail without error: killing cookie";
			$self->killCookie;
		}
		
		return 0;
	} else {
		# autentication succeeded!
		
		# we send a cookie if any of these conditions are met:
		# (a) a cookie was used for authentication
		# (b) a cookie was sent but not used for authentication, and the
		#     credentials used for authentication were the same as those in
		#     the cookie
		# (c) the user asked to have a cookie sent and is not a guest user.
		my $usedCookie = ($credentialSource eq "cookie") || 0;

		my $unusedCookieMatched = (defined($key) and defined($cookieUser) and defined($cookieKey) and 
		                            $user eq $cookieUser and $key eq $cookieKey) || 0;
		my $userRequestsCookie = ($send_cookie and not $login_practice_user) || 0;
		#warn "usedCookie=$usedCookie\n";
		#warn "unusedCookieMatched=$unusedCookieMatched\n";
		#warn "userRequestsCookie=$userRequestsCookie\n";
		if ($usedCookie or $unusedCookieMatched or $userRequestsCookie) {
			#warn "succeed: sending cookie";
			$self->sendCookie($r->param("user"), $r->param("key"));
		} elsif ($cookieUser or $cookieKey) {
			# otherwise, we don't want any bad cookies sticking around
			#warn "succeed: killing cookie";
			$self->killCookie;
		}
		return 1;
	}
	
	# Whatever you do, don't delete this!
	critical($r);
	# One time, I deleted it, and my mother broke her back, my cat died, and
	# the Pope got a tummy ache. When I replaced the line, I received eternal
	# salvation and a check for USD 500.
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu, and Sam
Hathaway, sh002i (at) math.rochester.edu.

=cut
