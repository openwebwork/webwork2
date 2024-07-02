################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::Authen::CAS;
use base qw/WeBWorK::Authen/;

use strict;
use warnings;
use AuthCAS;

use WeBWorK::Debug;
#$WeBWorK::Debug::Enabled = 1;
#$WeBWorK::Debug::Logfile = "/opt/webwork/webwork2/logs/cas-debug.log";
#$WeBWorK::Debug::AllowSubroutineOutput = "get_credentials";

sub checkSetUser {
	my ($self, $user_id, $new_id) = @_;
	my $ce = $self->{c}->ce;

	unless (defined $ce->{authen}{cas_options}{sudoers}) {
		$self->{error} = "Set-user capability is not enabled.";
		$self->write_log_entry("User $user_id tried to use setUser, which is turned off");
		return 0;
	}

	my $allowed_targets = $ce->{authen}{cas_options}{sudoers}{$user_id};
	unless (defined $allowed_targets) {
		$self->{error} = "User is $user_id is not authorized for setUser.";
		$self->write_log_entry("User $user_id tried to use setUser, which is not authorized for that user");
		return 0;
	}

	if (ref $allowed_targets eq 'ARRAY') {
		foreach my $x (@{$allowed_targets}) {
			return 1 if $x =~ m/(.*)\*$/ ? $new_id =~ m/^$1/ : $new_id eq $x;
		}
	} elsif (not ref $allowed_targets) {
		return 1 if $allowed_targets =~ m/(.*)\*$/ ? $new_id =~ m/^$1/ : $new_id eq $allowed_targets;
	} else {
		$self->{error} = "Malformed sudoers data structure.";
		$self->write_log_entry("Malformed sudoers data structure.");
		return 0;
	}

	$self->{error} = "User $user_id is not allowed to set user to $new_id.";
	$self->write_log_entry("User $user_id made invalid attempt to set user to $new_id");
	return 0;
}

sub get_credentials {
	my $self = shift;
	my $c    = $self->{c};
	my $ce   = $c->ce;

	# Disable password authentication
	$self->{external_auth} = 1;

	# This next part is necessary because some parts of webwork (e.g.,
	# WebworkWebservice.pm) need to replace the get_credentials() routine,
	# but only replace the one in the parent class (out of caution,
	# presumably).  Therefore, we end up here even when authenticating
	# for WebworkWebservice.pm.  This would cause authentication failures
	# when authenticating javascript web service requests (e.g., the
	# Library Browser).

	if ($c->{rpc}) {
		debug("falling back to superclass get_credentials (rpc call)");
		return $self->SUPER::get_credentials(@_);
	}

	# if we come in with a user_id, then we've already authenticated
	#    through the CAS.  So just check the provided user and session key.
	if (defined $c->param('key') && defined $c->param('user')) {
		# These lines were copied from the superclass get_credentials.
		$self->{session_key}       = $c->param('key');
		$self->{user_id}           = $c->param('user');
		$self->{login_type}        = 'normal';
		$self->{credential_source} = 'params';
		debug("CAS params user '", $self->{user_id}, "' key '", $self->{session_key}, "'");
		# Check session key and user here.  Otherwise, a student can
		#    determine the enrollment status of any other student if
		#    they know the userid (which is public information at
		#    Berkeley).  That would be a privacy violation.
		my $Key = $c->db->getKey($self->{user_id});
		unless (defined $Key && $Key->key eq $self->{session_key}) {
			debug(
				'undefined or invalid session key:  $Key->key = ',
				defined $Key ? $Key->key : undef,
				', user value = ',
				$self->{session_key}
			);
			$self->{error} = "Invalid session key";
			$c->param('key' => undef);
			return $self->get_credentials();
		}
		return 1;
		#debug("falling back to superclass get_credentials");
		#return $self->SUPER::get_credentials( @_ );
	} else {
		#my $cas_url = $ce->{authen}{cas_options}{url};
		#my $cas_certs = $ce->{authen}{cas_options}{certs};
		#my $cas = new AuthCAS(casUrl => $cas_url,
		#    CAFile => $cas_certs);
		my $cas = new AuthCAS(%{ $ce->{authen}{cas_options}{AuthCAS_opts} });

		my $service = $c->req->url->to_string;
		# Remove the "ticket=..." parameter that the CAS server added
		# (Not sure if the second test is really needed.)
		$service =~ s/[?&]ticket=[^&]*$//
			or $service =~ s/([?&])ticket=[^&]*&/$1/;
		$service = $ce->{server_root_url} . $service;
		debug("service = $service");
		my $ticket = $c->param('ticket');
		unless (defined $ticket) {
			# there's no ticket, so redirect to get one
			#
			my $go_to = $cas->getServerLoginURL($service);
			#$go_to = 'http://math.berkeley.edu/'; # for debugging
			debug("no ticket.  Redirecting to $go_to");
			$self->{redirect} = $go_to;
			return 0;
		}
		# We have a ticket.  Validate it.
		my $user_id = $cas->validateST($service, $ticket);
		if (!defined $user_id) {
			my $err = $cas->get_errors();
			$err = '<undef>' unless defined $err;
			$self->{error} = $err;
			debug("ticket error $err");
			#return $self->SUPER::get_credentials( @_ );
			return 0;
		} else {
			debug("ticket is good, user is $user_id");
			my $new_id = $c->param('setUser');
			if (defined $new_id) {
				return 0
					unless checkSetUser($self, $user_id, $new_id);
				$self->write_log_entry("setUser: user $user_id logged in as $new_id");
				$user_id = $new_id;
			}
			$self->{'user_id'} = $user_id;
			$self->{c}->param('user', $user_id);
			$self->{session_key}       = undef;
			$self->{password}          = "not\tvalid";
			$self->{login_type}        = 'normal';
			$self->{credential_source} = 'cas';
			return 1;
		}
	}
}

# There's no need to provide site_checkPassword, since it's only accessed
# from checkPassword, which we're replacing.

sub checkPassword {
	my ($self, $userID, $clearTextPassword) = @_;
	# if we got here, we know we've already successfully authenticated
	# against the CAS
	return 1;
}

# Handle logout by redirecting to the relevant CAS url.

sub logout_user {
	my ($self) = @_;

	my $ce = $self->{c}->ce;

	# Using AuthCAS::getServerLogoutURL($service) would be overkill,
	# and (more important) it would send us back here after logging out,
	# so we'd end up back at the CAS login screen.

	my $go_to = $ce->{authen}{cas_options}{AuthCAS_opts}{casUrl} . '/logout';
	debug("logging out.  Redirecting to $go_to");
	$self->{redirect} = $go_to;
}

1;
