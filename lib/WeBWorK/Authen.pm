################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Authen.pm,v 1.22 2003/12/23 06:03:33 sh002i Exp $
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
use Data::Dumper;

sub new($$$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	($self->{r}, $self->{ce}, $self->{db}) = @_;
	bless $self, $class;
	return $self;
}

sub checkPassword($$$) {
	my ($self, $userID, $possibleClearPassword) = @_;
	my $Password = $self->{db}->getPassword($userID); # checked
	return 0 unless defined $Password;
	my $possibleCryptPassword = crypt($possibleClearPassword, $Password->password());
	return $possibleCryptPassword eq $Password->password();
}

sub generateKey($$) {
	my ($self, $userID) = @_;
	my @chars = @{ $self->{ce}->{sessionKeyChars} };
	my $length = $self->{ce}->{sessionKeyLength};
	srand;
	my $key = join ("", @chars[map rand(@chars), 1 .. $length]);
	return WeBWorK::DB::Record::Key->new(user_id=>$userID, key=>$key, timestamp=>time);
}

sub checkKey($$$) {
	my ($self, $userID, $possibleKey) = @_;
	my $Key = $self->{db}->getKey($userID); # checked
	return 0 unless defined $Key;
	if (time <= $Key->timestamp()+$self->{ce}->{sessionKeyTimeout}) {
		if ($possibleKey eq $Key->key()) {
			# unexpired and matches -- update timestamp
			$Key->timestamp(time);
			$self->{db}->putKey($Key);
			return 1;
		} else {
			# unexpired but doesn't match -- leave timestamp alone
			# we do this to keep an attacker from keeping someone's session
			# alive. (yeah, we don't match IPs.)
			return 0;
		}
	} else {
		# expired -- delete key
		$self->{db}->deleteKey($userID);
		return 0;
	}
}

sub unexpiredKeyExists($$) {
	my ($self, $userID) = @_;
	my $Key = $self->{db}->getKey($userID); # checked
	return 0 unless defined $Key;
	if (time <= $Key->timestamp()+$self->{ce}->{sessionKeyTimeout}) {
		# unexpired, but leave timestamp alone
		return 1;
	} else {
		# expired -- delete key
		$self->{db}->deleteKey($userID);
		return 0;
	}
}

sub checkCookie {
	my ($self, $user, $key) = @_;
	my $r = $self->{r};
	my %cookies = Apache::Cookie->fetch;
	my $cookie = $cookies{WeBWorKAuthentication};
	if ($cookie) {
		my ($user, $key) = $cookie->value =~ m/^user=([^&]*)&key=([^&]*)$/;
		return $user, $key;
	}
}

sub sendCookie {
	my ($self, $user, $key) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $cookie = Apache::Cookie->new($r,
		-name => "WeBWorKAuthentication",
		-value => "user=$user&key=$key",
		-expires => "+30D",
		-domain => $r->hostname,
		-path => $ce->{webworkURLRoot},
		-secure => 0,
	);
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
	my $ce = $self->{ce};
	my $db = $self->{db};
	
	my $practiceUserPrefix = $ce->{practiceUserPrefix};
	my $debugPracticeUser = $ce->{debugPracticeUser};
	
	my $user = $r->param('user');
	my $passwd = $r->param('passwd');
	my $key = $r->param('key');
	my $force_passwd_authen = $r->param('force_passwd_authen');
	my $login_practice_user = $r->param('login_practice_user');
	my $send_cookie = $r->param("send_cookie");
	my $error;
	my $failWithoutError = 0;
	
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
			my ($cookieUser, $cookieKey) = $self->checkCookie;
			if ($cookieUser and $cookieKey) {
				$user = $cookieUser;
				$key = $cookieKey;
				$r->param("user", $user);
				$r->param("key", $key);
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
		
		# it's a practice user.
		if ($practiceUserPrefix and $user =~ /^$practiceUserPrefix/) {
			# we're not interested in a practice user's password
			$r->param("passwd", "");
			
			# it's a practice user that doesn't exist.
			unless (defined $db->getUser($user)) { # checked
				$error = "That practice account does not exist.";
				last VERIFY;
			}
			
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
			# supplying a key
			$r->param("passwd", "");
			
			if ($self->checkKey($user, $key)) {
				# valid key, so succeed.
				last VERIFY;
			} else {
				# invalid key. the login page doesn't propogate the key,
				# so we know this is an expired session.
				$error = "Your session has timed out due to inactivity. You must login again.";
				last VERIFY;
			}
		}
		
		# a password was supplied.
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
		# authentication failed, in a bad way
		$r->notes("authen_error",$error);
		return 0;
	} elsif ($failWithoutError) {
		# authentication failed, but not in a bad way
		return 0;
	} else {
		# autentication succeeded!
		# send a cookie with the user and key that were accepted.
		if ($send_cookie and not $login_practice_user) {
			$self->sendCookie($r->param("user"), $r->param("key"));
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
