################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen/Moodle.pm,v 1.5 2006/06/08 23:27:02 sh002i Exp $
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

package WeBWorK::Authen::Moodle;
use base qw/WeBWorK::Authen/;

=head1 NAME

WeBWorK::Authen::Moodle - Allow moodle cookies to be used for WeBWorK authentication.

=cut

=for comment

TODO

* I'm not altogether comfortable with the moodle sesion table being wired up as an additional
"moodleKey" WWDBv2 table. The API presented is non-standard, and it doesn't really take advantage or
any existing DB infrastructure (except maybe the "tablePrefix" param). I'm thinking there should be
a separate toplevel Moodle::Session module? The other moodle Schema modules (User, Password,
Permission) are OK, since they "fit" into the WWDBv2 stack appropriately and don't require changes
to DB.pm.

* However, those three schema modules could probably be replaced with a single schema module that's a
sublcass of WeBWorK::DB::Schema::SQL.

* Modules that modify data that's being taken from moodle should check for "alternative URLs" in the
CE that can point back to the moodle installation. operations include: change password, change user
data, change permission level, add user, delete user. Run this for a rough estimate:
	pcregrep -r '\$db->(add|put)(User|Password|PermissionLevel)\b' lib

=cut

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use WeBWorK::Cookie;
use WeBWorK::Debug;

use mod_perl;
use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

# call superclass get_credentials. if no credentials were found, look for a moodle cooke.
# if a moodle cookie is found, a new webwork session is created and the session key is used.
# (this is similar to what happens when a guest user is selected.)
sub get_credentials {
	my $self = shift;
	my $r = $self->{r};
	
	my $super_result = $self->SUPER::get_credentials;
	if ($super_result) {
		debug("Superclass's get_credentials found credentials. Using them.\n");
		return $super_result;
	}
	
	my ($moodle_user_id, $moodle_expiration_time) = $self->fetch_moodle_session;
	debug("fetch_moodle_session returned: moodle_user_id='$moodle_user_id' moodle_expiration_time='$moodle_expiration_time'.\n");
	
	if (defined $moodle_user_id and defined $moodle_expiration_time and time <= $moodle_expiration_time) {
		my $newKey = $self->create_session($moodle_user_id);
		debug("Unexpired moodle session found. Created new WeBWorK session with newKey='$newKey'.\n");
		
		$self->{user_id} = $moodle_user_id;
		$self->{session_key} = $newKey;
		$self->{credential_source} = "moodle";
		return 1;
	} else {
		debug("No moodle session found or moodle session expired. No credentials to be had.\n");
	}
	
	return 0;
}

# extend the moodle session if authentication succeeded
sub site_fixup {
	my $self = shift;
	
	if ($self->was_verified) {
		debug("User was verified, updating moodle session.\n");
		$self->update_moodle_session;
	}
}

# we assume that the database is set up to use the moodle password table, which uses MD5 passwords.
# this is overridden to accommodate this.
sub checkPassword {
	my ($self, $userID, $possibleClearPassword) = @_;
	my $db = $self->{r}->db;
	
	debug("Moodle module is doing the password checking.\n");
	
	my $Password = $db->getPassword($userID); # checked
	return 0 unless defined $Password;
	
	debug("Hashed password from Password record: '", $Password->password, "'.\n");
	
	# check against Moodle password database
	my $possibleMD5Password = md5_hex($possibleClearPassword);
	debug("Hashed password from supplied cleartext: '$possibleMD5Password'.\n");
	return 1 if $possibleMD5Password eq $Password->password;
	
	# check site-specific verification method
	# FIXME do we really want to call this here?
	return 1 if $self->site_checkPassword($userID, $possibleClearPassword);
	
	# fail by default
	return 0;
}

sub check_session {
	my ($self, $user_id, $session_key, $update_timestamp) = @_;
	
	my ($sessionExists, $keyMatches, $timestampValid) = $self->SUPER::check_session($user_id, $session_key, $update_timestamp);
	debug("SUPER::check_session returned: sessionExists='", $sessionExists, "' keyMatches='", $keyMatches, "' timestampValid='", $timestampValid, "'");
	
	if ($update_timestamp and $sessionExists and $keyMatches and not $timestampValid) {
		debug("special case: webwork key matches an expired session (check for a unexpired moodle session)");
		my ($moodle_user_id, $moodle_expiration_time) = $self->fetch_moodle_session;
		debug("fetch_moodle_session returned: moodle_user_id='$moodle_user_id' moodle_expiration_time='$moodle_expiration_time'.\n");
		if (defined $moodle_user_id and $moodle_user_id eq $user_id
				and defined $moodle_expiration_time and time <= $moodle_expiration_time) {
			$self->{session_key} = $self->create_session($moodle_user_id);
			$timestampValid = 1;
		}
	}
	
	return $sessionExists, $keyMatches, $timestampValid;
}

################################################################################

sub fetch_moodle_session {
	# fetches the basic information from the moodle session.
	# returns the user name and expiration time of the moodle session
	# Note that we don't worry about the user being in this course at this point. That is taken care of in Schema::Moodle::User.
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $r->db;
	
	my %cookies = WeBWorK::Cookie->fetch( MP2 ? $r : () );
	my $cookie = $cookies{"MoodleSession"};
	
	if( $cookie ) {
		# grab the session details from the database
		return $db->getMoodleSession($cookie->value);
	}
	else {
		return;
	}
}

sub update_moodle_session {
	# extend the timeout of the current moodle session, if one exists.
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $r->db;
	
	my %cookies = WeBWorK::Cookie->fetch( MP2 ? $r : () );
	my $cookie = $cookies{"MoodleSession"};
	if( $cookie ) {
		# update the session with the new expiration time:
		$db->extendMoodleSession($cookie->value);
	}
}

#sub moodle_session_expired {
#	# determine if the moodle session is expired
#	my ($self) = @_;
#	
#	my ($moodleUser, $moodleExpires) = $self->fetchMoodleSession;
#	return time > $moodleExpires;
#}

1;
