################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen.pm,v 1.51 2006/02/21 22:00:29 glarose Exp $
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

=for comment



=cut

# call superclass get_credentials. if no credentials were found, look for a moodle cooke.
# if a moodle cookie is found, a new webwork session is created and the session key is used.
# (this is similar to what happens when a guest user is selected.)
sub get_credentials {
	my $self = shift;
	my $r = $self->{r};
	
	my $super_result = $self->SUPER::get_credentials;
	return $super_result if $super_result;
	
	my ($moodle_user_id, $moodle_expiration_time) = $self->fetch_moodle_cookie;
	
	if (defined $moodle_user_id and defined $moodle_expiration_time and time <= $moodle_expiration_time) {
		my $newKey = $self->create_session($moodle_user_id);
		
		$self->{user_id} = $moodle_user_id;
		$self->{session_key} = $newKey;
		$self->{credential_source} = "moodle";
		return 1;
	}
	
	return 0;
}

# FIXME: original moodle bridge would take a request with a user ID and an expired but matching
# session key, and check to see if there was an unexpired moodle cookie around. if there was, the
# existing webwork session would be updated.
# 
# this can happen in the following situation:
#  1. log in to moodle, click on webwork link
#  2. webwork authenticates with moodle cookie due to lack of userID/key in URL
#  3. wait... depending on settings, webwork session might expire before moodle session
#  4. click on an internal webwork link -- userID/key will match, but session is expired
#  5. should fall back on moodle cookie (but doesn't in this implementation)
# 
# currently, this implementation doesn't do that. here, the moodle cookie is never checked if a
# user ID was found in the request (i.e. if it was an internal link)

# extend the moodle session if authentication succeeded
sub site_fixup {
	my $self = shift;
	
	if ($self->was_verified) {
		$self->extendMoodleSession;
	} else {
		# ***
	}
}

# we assume that the database is set up to use the moodle password table, which uses MD5 passwords.
# this is overridden to accommodate this.
sub checkPassword {
	my ($self, $userID, $possibleClearPassword) = @_;
	my $db = $self->{r}->db;
	
	my $Password = $db->getPassword($userID); # checked
	return 0 unless defined $Password;
	
	# check against Moodle password database
	my $possibleMD5Password = md5_hex($possibleClearPassword, $Password->password());
	return 1 if $possibleMD5Password eq $Password->password;
	
	# check site-specific verification method
	return 1 if $self->site_checkPassword($userID, $possibleClearPassword);
	
	# fail by default
	return 0;
}

sub fetchMoodleSession {
	# fetches the basic information from the moodle session.
	# returns the user name and expiration time of the moodle session
	# Note that we don't worry about the user being in this course at this point. That is taken care of in Schema::Moodle::User.
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $r->db;
	
	my %cookies = Apache::Cookie->fetch;
	my $cookie = $cookies{"MoodleSession"};
	
	if( $cookie ) {
		# grab the session details from the database
		return $db->getMoodleSession($cookie->value);
	}
	else {
		return undef, undef;
	}
}

sub extendMoodleSession {
	# extend the timeout of the current moodle session, if one exists.
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $r->db;
	
	my %cookies = Apache::Cookie->fetch;
	my $cookie = $cookies{"MoodleSession"};
	if( $cookie ) {
		# update the session with the new expiration time:
		$db->extendMoodleSession($cookie->value);
	}
}

sub moodleSessionExpired {
	# determine if the moodle session is expired
	my ($self) = @_;
	
	my ($moodleUser, $moodleExpires) = $self->fetchMoodleSession;
	return time > $moodleExpires;
}

1;
