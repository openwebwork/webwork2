################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Authen.pm,v 1.20 2003/12/09 01:12:30 sh002i Exp $
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
	
	my $error;
	my $failWithoutError = 0;
	
	VERIFY: {
		# This block is here so we can "last" out of it when we've
		# decided whether we're going to succeed or fail.
		
		# no authentication data was given. this is OK.
		unless (defined $user or defined $passwd or defined $key) {
			$failWithoutError = 1;
			last VERIFY;
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
		return 1;
	}
	
	# Whatever you do, don't delete this!
	critical($r);
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu, and Sam
Hathaway, sh002i (at) math.rochester.edu.

=cut
