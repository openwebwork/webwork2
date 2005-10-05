################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen.pm,v 1.44 2005/09/27 21:46:50 sh002i Exp $
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
use WeBWorK::Utils qw(writeCourseLog);

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
	
	# check against WW password database
	my $possibleCryptPassword = crypt($possibleClearPassword, $Password->password());
	return 1 if $possibleCryptPassword eq $Password->password;
	
	# check site-specific verification method
	return 1 if $self->site_checkPassword($userID, $possibleClearPassword);
	
	# fail by default
	return 0;
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
# 	sub site_checkPassword($$) {
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
# 
# 
# The default site_checkPassword always fails:
sub site_checkPassword {
	my ($self, $userID, $clearTextPassword) = @_;
	return 0;
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

sub record_login($$) {
	my ($self, $userID) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $timestamp = localtime;
	($timestamp) = $timestamp =~ /^\w+\s(.*)\s/;
	my $remote_host = $r->get_remote_host || "(cannot get host)";
	my $user_agent = $r->header_in("User-Agent");
	writeCourseLog($ce, "login_log", "$userID on $remote_host ($user_agent)");
}

# verify will return 1 if the person is who they say the are. If the
# verification failed because of of invalid authentication data, a note will be
# written in the request explaining why it failed. If the request failed because
# no authentication data was provided, however, no note will be written, as this
# is expected to happen whenever someone types in a URL manually, and is not
# considered an error condition.

# much of the code in verify() is duplicated in verifyProctor(), below.  any 
# changes that are made to this subroutine should be checked against 
# verifyProctor() to ensure that the the two routines continue to work in 
# approximately the same manner.
sub verify($) {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	
	my $practiceUserPrefix = $ce->{practiceUserPrefix};
	my $debugPracticeUser = $ce->{debugPracticeUser};
	
	my $force_passwd_authen = $r->param('force_passwd_authen');
	my $login_practice_user = $r->param('login_practice_user');
	my $send_cookie = $r->param("send_cookie");
	my @temp_users = $r->param("user");
	warn "users start out as ", join(" ", @temp_users) if @temp_users >1;
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
					$self->record_login($userID);
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
				#$r->args->{user} = $user;
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
		
		# Make sure user is in the database
		my $User = $db->getUser($user); # checked
		unless (defined $User) {
			# FIXME too much information!
			$error = "There is no account for $user in this course.";
			last VERIFY;
		}
		
		# fix invalid status values (FIXME this should be in DB!)
		if (not defined $User->status or not defined $ce->status_abbrev_to_name($User->status)) {
			my $default_status = $ce->{default_status};
			die "default_status not defined in course environment" unless defined $default_status;
			my ($default_abbrev) = $ce->status_name_to_abbrevs($default_status);
			die "default status has no abbrevs in course environment" unless defined $default_abbrev;
			$User->status($default_abbrev);
			$db->putUser($User);
			warn "Setting status for user $user to '$default_abbrev'. It was previously unset or set to an invalid value.";
		}
		
		# make sure users with this user's status are allowed to access the course (jeez...)
		unless ($ce->status_abbrev_has_behavior($User->status, "allow_course_access")) {
			# FIXME too much information!
			$error = "The user $user has been dropped from this course.";
			last VERIFY;
		}
		
		# make sure the user is allowed to login
		unless ($authz->hasPermissions($user, "login")) {
			# FIXME too much information?
			$error = "The user $user is not allowed to log in.";
			last VERIFY;
		}
		
		# it's a practice user.
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
				$self->record_login($user); 
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
	
	# check for multiply defined users
	my @test_users = $r->param("user");
	if (@test_users>1)    {
		warn "User has been multiply defined in Authen.pm ", join(" ", @test_users)  ;
		$r->param("user"=>$test_users[0]);
		@test_users = $r->param("user");
		warn "New value of user is ", join(" ", @test_users);
	}
	
	if (defined $error) {
		# authentication failed, store the error message
		$r->notes("authen_error", $error);
		
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
}

# verifyProctor will return 1 if the proctor is who they say they are.  It is 
# essentially the same as verify(), but pulls out the proctor data from the 
# form input and uses that with the appropriate database entry names to determine
# whether the proctor is valid.
sub verifyProctor {
	my $self = shift();
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	
	my $user          = $r->param('effectiveUser');
	my $proctorUser   = $r->param('proctor_user');
	my $proctorPasswd = $r->param('proctor_passwd');
	my $proctorKey    = $r->param('proctor_key');
	
	# we use the following to require a second proctor authorization to grade the test
	my $submitAnswers = defined($r->param('submitAnswers'))
		? $r->param('submitAnswers')
		: '';
	
	my $failWithoutError = 0;
	my $error = '';
	
	# we define a key for "effectiveuser,proctoruser" to authorize a test, and 
	# "effectiveuser,proctoruser,g" to authorize grading.
	my $prKeyIndex = '';
	
	VERIFY: {
		unless(
			defined $proctorUser && $proctorUser
				or
			defined $proctorPasswd && $proctorPasswd
				or 
			defined $proctorKey && $proctorKey
		) {
			$failWithoutError = 1;
			last VERIFY;
		}
		
		unless(defined $proctorUser) {
			$error = 'Proctor username must be specified.';
			last VERIFY;
		}
		
		my $Proctor = $db->getUser($proctorUser);
		unless(defined $Proctor) {
			# FIXME too much information
			$error = "There is no proctor account for $proctorUser in this course";
			last VERIFY;
		}
		
		unless( !defined($Proctor->status) or $Proctor->status() eq 'C' ) {
			# FIXME too much information
			$error = "Proctor user $proctorUser does not have a valid status in this course.";
			last VERIFY;
		}
		
		# make sure proctor has valid status
		unless($ce->status_abbrev_has_behavior($Proctor->status, "allow_course_access")) {
			# FIXME too much information
			$error = "Proctor user $proctorUser does not have a valid status in this course.";
			last VERIFY;
		}
		
		if ($proctorKey) {
			$r->param('proctor_password', '');
			
			$prKeyIndex = "$user,$proctorUser" . (($submitAnswers) ? ',g' : '');
			if ($self->checkKey($prKeyIndex, $proctorKey)) {
				last VERIFY;
			} else {
				if ($submitAnswers) {
					$error = 'Assignment requires valid proctor authorization for grading';
				} else {
					$error = "Invalid or expired proctor session key.";
				}
				last VERIFY;
			}
		}
		
		if ($proctorPasswd) {
			if ($self->checkPassword($proctorUser, $proctorPasswd)) {
				$prKeyIndex = "$user,$proctorUser" . (($submitAnswers) ? ',g' : '');
				my $newKeyObject = $self->generateKey( $prKeyIndex );
				$r->param('proctor_passwd', '');
				
				eval{ $db->deleteKey($prKeyIndex); };
				$db->addKey($newKeyObject);
				
				$r->param('proctor_key', $newKeyObject->key);
				
				last VERIFY;
			}  else {
				$error = 'Incorrect proctor username or password.';
				last VERIFY;
			}
		}
	}
	
	if (defined $error and $error) {
		$r->notes("authen_error", $error);
		return 0;
	} elsif ($failWithoutError) {
		return 0;
	} else {
		return 1;
	}
}

1;
