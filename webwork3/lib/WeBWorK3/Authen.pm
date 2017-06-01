################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen.pm,v 1.63 2012/06/06 22:03:15 wheeler Exp $
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

package WeBWorK3::Authen;

use base qw (WeBWorK::Authen);
use strict;
use warnings;
#use Carp::Always;
use Dancer2;

use WeBWorK::Utils qw/writeCourseLog runtime_use/;

our $GENERIC_ERROR_MESSAGE = "";  # define in new

#
#################################################################################
## Public API
#################################################################################
#
#=head1 FACTORY
#
#=over
#
#=item class($ce, $type)
#
#This is a subclass of the WebWork::Authen class.  It overrides methods necessary to run Dancer.
#
#=cut
#
#sub class {
#	my ($ce, $type) = @_;
#
#	if (exists $ce->{authen}{$type}) {
#		if (ref $ce->{authen}{$type} eq "ARRAY") {
#			my $authen_type = shift @{$ce ->{authen}{$type}};
#			#debug("ref of authen_type = |" . ref($authen_type) . "|");
#			if (ref ($authen_type) eq "HASH") {
#				if (exists $authen_type->{$ce->{dbLayoutName}}) {
#					return $authen_type->{$ce->{dbLayoutName}};
#				} elsif (exists $authen_type->{"*"}) {
#					return $authen_type->{"*"};
#				} else {
#					die "authentication type '$type' in the course environment has no entry for db layout '", $ce->{dbLayoutName}, "' and no default entry (*)";
#				}
#			} else {
#					return $authen_type;
#			}
#		} elsif (ref $ce->{authen}{$type} eq "HASH") {
#			if (exists $ce->{authen}{$type}{$ce->{dbLayoutName}}) {
#				return $ce->{authen}{$type}{$ce->{dbLayoutName}};
#			} elsif (exists $ce->{authen}{$type}{"*"}) {
#				return $ce->{authen}{$type}{"*"};
#			} else {
#				die "authentication type '$type' in the course environment has no entry for db layout '", $ce->{dbLayoutName}, "' and no default entry (*)";
#			}
#		} else {
#			return $ce->{authen}{$type};
#		}
#	} else {
#		die "authentication type '$type' not found in course environment";
#	}
#}
#
#sub call_next_authen_method {
#	my ($self,$ce) = shift;
#
#	my $user_authen_module = WeBWorK::Authen::class($ce, "user_module");
#	#debug("user_authen_module = |$user_authen_module|");
#	if (!defined($user_authen_module) or ($user_authen_module eq "")) {
#		$self->{error} = "No authentication method found for your request.  "
#			. "If this recurs, please speak with your instructor.";
#		$self->{log_error} .= "None of the specified authentication modules could handle the request.";
#		return(0);
#	} else {
#
#		# not sure what to do here without a Request Object
#
#		#runtime_use $user_authen_module;
#		# my $authen = $user_authen_module->new($r);
#		#debug("Using user_authen_module $user_authen_module: $authen\n");
#	 	# $r->authen($authen);
#
#		return;
#	}
#}
#
#
#=back
#
#=cut
#
#=head1 CONSTRUCTOR
#
#=over
#
#=item new($r)
#
#Instantiates a new WeBWorK::Authen object for the given WeBWorK::CourseEnvironment ($ce).
#
#=cut
#
sub new {
	my ($invocant,$ce) = @_;
	my $class = ref($invocant) || $invocant;
	my $self = {
	 	ce => $ce,
	 	db => new WeBWorK::DB($ce->{dbLayout}),
	 	params => {}
	};

	# weaken $self -> {r};
	#initialize
	$GENERIC_ERROR_MESSAGE = "Invalid user ID or password.";
	bless $self, $class;
	return $self;
}
#
#
##  0 == required data was present, but authentication failed
## -1 == required data was not present (i.e. password missing)
#sub authenticate {
#	my $self = shift;
#	# my $r = $self->{r};
#
#	my $user_id = $self->{params}->{user};
#	my $password = $self->{params}->{password};
#
#	if (defined $password) {
#		return $self->checkPassword($user_id, $password);
#	} else {
#		return -1;
#	}
#}
#
sub set_params {
	my ($self,$params) = @_;
	$self->{params} = $params;

}
#
#################################################################################
## Password management
#################################################################################
#
sub checkPassword {
	my ($self, $userID, $possibleClearPassword) = @_;

	my $Password = $self->{db}->getPassword($userID); # checked
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

sub verify {

	my $self = shift;

	if (! ($self-> request_has_data_for_this_verification_module)) {
		return ( $self -> call_next_authen_method());
	}

	my $result = $self->do_verify;
	my $error = $self->{error};


	my $log_error = $self->{log_error};

	$self->{was_verified} = $result ? 1 : 0;



	if ($self->can("site_fixup")) {
		$self->site_fixup;
	}

	if ($result) {
		$self->write_log_entry("LOGIN OK") if $self->{initial_login};
	} else {
		if (defined $log_error) {
			$self->write_log_entry("LOGIN FAILED $log_error");
		}
		if (defined($error) and $error=~/\S/) { # if error message has a least one non-space character.

			#if (defined($r->param("user")) or defined($r->param("user_id"))) {
			if(defined($self->{params}->{user_id})){
				$error = "Your authentication failed.  Please try again."
					. "  Please speak with your instructor if you need help.";
			}

		}
	}

   return {result => $result, error=>$error};

	# 		debug $result;
	# 		debug $error;
	# 		debug $log_error;
	#
	# 	#$self->maybe_kill_cookie;
	# 	if (defined($error) and $error=~/\S/) { # if error message has a least one non-space character.
	# 		return $error;
	# 		# MP2 ? $r->notes->set(authen_error => $error) : $r->notes("authen_error" => $error);
	# 	}
	# }
	#
	# debug $result;
	# debug $error;
	# debug $log_error;
	#
	# return $result;
}

#
#################################################################################
## Helper functions (called by verify)
#################################################################################
#
sub do_verify {
	my $self = shift;
	my $ce = $self->{ce};
	my $db = $self->{db};

	return 0 unless $db;

	return 0 unless $self->get_credentials;


#	return 0 unless $self->check_user;

	my $practiceUserPrefix = $ce->{practiceUserPrefix};
	if (defined($self->{login_type}) && $self->{login_type} eq "guest"){
		return $self->verify_practice_user;
	} else {
		return $self->verify_normal_user;
	}

}

sub verify_practice_user {
	my $self = shift;
	my $ce = $self->{ce};

	my $user_id = $self->{user_id};
	my $session_key = $self->{session_key};

	my ($sessionExists, $keyMatches, $timestampValid) = $self->check_session($user_id, $session_key, 1);
	#debug("sessionExists='". $sessionExists.  "' keyMatches='". $keyMatches.  "' timestampValid='". $timestampValid. "'");

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

	my $user_id = $self->{user_id};
	my $session_key = $self->{session_key};

	my ($sessionExists, $keyMatches, $timestampValid) = $self->check_session($user_id, $session_key, 1);
	#debug("sessionExists='". $sessionExists. "' keyMatches='".$keyMatches. "' timestampValid='". $timestampValid. "'");

	if ($sessionExists and $keyMatches and $timestampValid) {
		return 1;
	} else {
		my $auth_result = $self->authenticate;

		if ($auth_result > 0) {
			$self->{session_key} = $self->create_session($user_id);
			$self->{initial_login} = 1;
			return 1;
		} elsif ($auth_result == 0) {
			$self->{log_error} = "authentication failed";
			$self->{error} = $GENERIC_ERROR_MESSAGE;
			return 0;
		} else { # ($auth_result < 0) => required data was not present
			if ($keyMatches and not $timestampValid) {
				$self->{log_error} = "inactivity timeout";
				$self->{error} .= "Your session has timed out due to inactivity. Please log in again.";
			}
			return 0;
		}
	}
}

#
### pass all of the parameters as a reference to a has
#
#
sub get_credentials {
	my $self = shift;
	my $ce = $self->{ce};
	my $db = $self->{db};


	# allow guest login: if the "Guest Login" button was clicked, we find an unused
	# practice user and create a session for it.
	if ($self->{params}->{login_practice_user}) {
		my $practiceUserPrefix = $ce->{practiceUserPrefix};
		# DBFIX search should happen in database
		my @guestUserIDs = grep m/^$practiceUserPrefix/, $db->listUsers;
		my @GuestUsers = $db->getUsers(@guestUserIDs);
		my @allowedGuestUsers = grep { $ce->status_abbrev_has_behavior($_->status, "allow_course_access") } @GuestUsers;
		my @allowedGuestUserIDs = map { $_->user_id } @allowedGuestUsers;

		foreach my $userID (@allowedGuestUserIDs) {
			if (not $self->unexpired_session_exists($userID)) {
				my $newKey = $self->create_session($userID);
				$self->{initial_login} = 1;
				$self->{user_id} = $userID;
				$self->{session_key} = $newKey;
				$self->{login_type} = "guest";
				$self->{credential_source} = "none";
				return 1;
			}
		}

		$self->{log_error} = "no guest logins are available";
		$self->{error} = "No guest logins are available. Please try again in a few minutes.";
		return 0;
	}


		if (defined $self->{params}->{key}) {
			$self->{user_id} = $self->{params}->{user};
			$self->{session_key} = $self->{params}->{key};
			$self->{password} = $self->{params}->{password};
			$self->{login_type} = "normal";
			$self->{credential_source} = "params";
			#debug("params user '", $self->{user_id}, "' password '", $self->{password}, "' key '", $self->{session_key}, "'");
			return 1;
		}

    if (defined $self->{params}->{user}) {
		$self->{user_id} = $self->{params}->{user};
		$self->{session_key} = $self->{params}->{key};
		$self->{password} = $self->{params}->{password};
		$self->{login_type} = "normal";
		$self->{credential_source} = "params";
		return 1;
	}

}
#
#
#################################################################################
## Session key management
#################################################################################
#
#
## clobbers any existing session for this $userID
## if $newKey is not specified, a random key is generated
## the key is returned
sub create_session {
	my ($self, $userID, $newKey) = @_;
	my $ce = $self->{ce};
	my $db = $self->{db};

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

	#if ($ce -> {session_management_via} eq "session_cookie"),
	#    then the subroutine maybe_send_cookie should send a cookie.

	return $newKey;
}

## returns ($sessionExists, $keyMatches, $timestampValid)
## if $updateTimestamp is true, the timestamp on a valid session is updated
sub check_session {
	my ($self, $userID, $possibleKey, $updateTimestamp) = @_;
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $Key = $db->getKey($userID); # checked

	return 0 unless defined $Key;
	my $keyMatches = (defined $possibleKey and $possibleKey eq $Key->key);

	my $timestampValid=0;
	if ($ce -> {session_management_via} eq "session_cookie" and defined($self->{cookie_timestamp})) {
		$timestampValid = (time <= $self -> {cookie_timestamp} + $ce->{sessionKeyTimeout});
	} else {
		$timestampValid = (time <= $Key->timestamp()+$ce->{sessionKeyTimeout});
		if ($keyMatches and $timestampValid and $updateTimestamp) {
			$Key->timestamp(time);
			$db->putKey($Key);
		}
	}
	return (1, $keyMatches, $timestampValid);
}

sub maybe_kill_cookie {
	my $self = shift;
	#$self->killCookie(@_);
}


#
#
#################################################################################
## Utilities
#################################################################################
#
sub write_log_entry {
	my ($self, $message) = @_;

	my $user_id = defined $self->{user_id} ? $self->{user_id} : "";
	my $login_type = defined $self->{login_type} ? $self->{login_type} : "";
	my $credential_source = defined $self->{credential_source} ? $self->{credential_source} : "";

	my ($remote_host, $remote_port) = ('','');

	my $log_msg = "$message user_id=$user_id login_type=$login_type credential_source=$credential_source host=$remote_host port=$remote_port";

	writeCourseLog($self->{ce}, "login_log", $log_msg);
}

1;
