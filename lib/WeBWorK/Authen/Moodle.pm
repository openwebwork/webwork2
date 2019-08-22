################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen/Moodle.pm,v 1.14 2007/02/14 19:08:46 gage Exp $
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

* Modules that modify data that's being taken from moodle should check for "alternative URLs" in the
CE that can point back to the moodle installation. operations include: change password, change user
data, change permission level, add user, delete user. Run this for a rough estimate:
	pcregrep -r '\$db->(add|put)(User|Password|PermissionLevel)\b' lib

=cut

use strict;
use warnings;
use Digest::MD5 qw/md5_hex/;
use WeBWorK::Cookie;
use WeBWorK::Debug;
use Date::Parse; # for moodle 1.7 date parsing


use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

sub new {
	my $self = shift->SUPER::new(@_);
	
	$self->init_mdl_session;
	
	return $self;
}

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
	#debug("fetch_moodle_session returned: moodle_user_id='$moodle_user_id' moodle_expiration_time='$moodle_expiration_time'.\n"); # causes errors when undefined
	
	if (defined $moodle_user_id and defined $moodle_expiration_time and time <= $moodle_expiration_time) {
		my $newKey = $self->create_session($moodle_user_id);
		debug("Unexpired moodle session found. Created new WeBWorK session with newKey='$newKey'.\n");
		
		$self->{user_id} = $moodle_user_id;
		$self->{session_key} = $newKey;
		$self->{login_type} = "normal";
		$self->{credential_source} = "moodle";
		return 1;
	} else {
		debug("No moodle session found or moodle session expired. No credentials to be had.\n");
		warn("No moodle session found or moodle sessioin expired.  If this happens repeatedly and you are constantly being asked
		      to log back in ask your moodle admin to check that the Moodle item: 
		      Server -> Session Handling -> dbsessions (Use database for session information) has been checked.");
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
	if (defined $Password) {
		# check against Moodle password database
		my $possibleMD5Password = md5_hex($possibleClearPassword);
		debug("Hashed password from supplied cleartext: '$possibleMD5Password'.\n");
		debug("Hashed password from Password record: '", $Password->password, "'.\n");
		if ($possibleMD5Password eq $Password->password) {
			$self->write_log_entry("AUTH MDL: password accepted");
			return 1;
		} else {
			if ($self->can("site_checkPassword")) {
				$self->write_log_entry("AUTH MDL: password rejected, deferring to site_checkPassword");
				return $self->site_checkPassword($userID, $possibleClearPassword);
			} else {
				$self->write_log_entry("AUTH MDL: password rejected");
				return 0;
			}
		}
		
	}
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

use DBI;
use PHP::Serialization qw/unserialize/;

use constant DEFAULT_EXPIRY => 7200;

sub init_mdl_session {
	my $self = shift;
	
	# version-specific stuff
	$self->{moodle17} = $self->{r}->ce->{authen}{moodle_options}{moodle17};
	$self->{sql_session_table} = $self->{moodle17} ? "sessions2" : "sessions";
	$self->{sql_data_field} = $self->{moodle17} ? "sessdata" : "data";
	
	$self->{mdl_dbh} = DBI->connect_cached(
		$self->{r}->ce->{authen}{moodle_options}{dsn},
		$self->{r}->ce->{authen}{moodle_options}{username},
		$self->{r}->ce->{authen}{moodle_options}{password},
		{
			PrintError => 0,
			RaiseError => 1,
		},
	);
	die $DBI::errstr unless defined $self->{mdl_dbh};
}

sub fetch_moodle_session {
	# fetches the basic information from the moodle session.
	# returns the user name and expiration time of the moodle session
	# Note that we don't worry about the user being in this course at this point.
	# That is taken care of in Schema::Moodle::User.
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $r->db;
	
	my %cookies = WeBWorK::Cookie->fetch( MP2 ? $r : () );
	my $cookie = $cookies{"MoodleSession"};
	return unless $cookie;
	
	my $session_table = $self->prefix_table($self->{sql_session_table});
	my $data_field = $self->{sql_data_field};
	my $stmt = "SELECT `expiry`,`$data_field` FROM `$session_table` WHERE `sesskey`=?";
	my @bind_vals = $cookie->value;
	
	my $sth = $self->{mdl_dbh}->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	$sth->execute(@bind_vals);
	my $row = $sth->fetchrow_arrayref;
	$sth->finish;
	return unless defined $row;
	
	my ($expires, $data_string) = @$row;
	
	# Moodle 1.7 stores expiry as a DATETIME, but WeBWorK wants a UNIX timestamp.
	$expires = str2time($expires) if $self->{moodle17};
	
	my $data = unserialize_session($data_string);
	my $username = $data->{"USER"}{"username"};
	
	return $username, $expires;
}

sub update_moodle_session {
	# extend the timeout of the current moodle session, if one exists.
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $r->db;
	
	my %cookies = WeBWorK::Cookie->fetch( MP2 ? $r : () );
	my $cookie = $cookies{"MoodleSession"};
	return unless $cookie;
	
	my $config_table = $self->prefix_table("config");
	my $value = "IFNULL((SELECT `value` FROM `$config_table` WHERE `name`=?),?)+?";
	
	# Moodle 1.7 stores expiry as a DATETIME, but WeBWorK supplies a UNIX timestamp.
	$value = "FROM_UNIXTIME($value)" if $self->{moodle17};
	
	my $session_table = $self->prefix_table($self->{sql_session_table});
	my $stmt = "UPDATE `$session_table` SET `expiry`=$value WHERE `sesskey`=?";
	my @bind_vals = ("sessiontimeout", DEFAULT_EXPIRY, time, $cookie->value);
	
	my $sth = $self->{mdl_dbh}->prepare_cached($stmt, undef, 3); # 3: see DBI docs
	my $result = $sth->execute(@bind_vals);
	$sth->finish;
	
	return defined $result;
}

sub prefix_table {
	my ($self, $base) = @_;
	if (defined $self->{r}->ce->{authen}{moodle_options}{table_prefix}) {
		return $self->{r}->ce->{authen}{moodle_options}{table_prefix} . $base;
	} else {
		return $base;
	}
}

sub unserialize_session {
	my $serialData = shift;
	# first, url decode:
	$serialData =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
	# then, split it up by |, it's some ADODB sillyness
	my @serialArray = split(/(\w+)\|/, $serialData);
	my %variables;
	# finally, actually deserialize it:
	for( my $i = 1; $i < $#serialArray; $i += 2 ) {
		$variables{$serialArray[$i]} = unserialize($serialArray[$i+1]);
	}
	return \%variables;
}

1;
