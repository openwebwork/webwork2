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

package WeBWorK::Authen::Shibboleth;
use base qw/WeBWorK::Authen/;

=head1 NAME

WeBWorK::Authen::Shibboleth - Authentication plug in for Shibboleth.
This is basd on Cosign.pm

For documentation, please refer to http://webwork.maa.org/wiki/External_(Shibboleth)_Authentication

to use: include in localOverrides.conf or course.conf
  $authen{user_module} = "WeBWorK::Authen::Shibboleth";
and add /webwork2/courseName as a Shibboleth Protected
Location or enable lazy session.

if $c->ce->{shiboff} is set for a course, authentication reverts
to standard WeBWorK authentication.

add the following to localOverrides.conf to setup the Shibboleth

$shibboleth{login_script} = "/Shibboleth.sso/Login"; # login handler
$shibboleth{logout_script} = "/Shibboleth.sso/Logout?return=".$server_root_url.$webwork_url; # return URL after logout
$shibboleth{manage_session_timeout} = 1; # allow shib to manage session time instead of webwork
$shibboleth{hash_user_id_method} = "MD5"; # possible values none, MD5. Use it when you want to hide real user_ids from showing in url.
$shibboleth{hash_user_id_salt} = ""; # salt for hash function
#define mapping between shib and webwork
$shibboleth{mapping}{user_id} = "username";

=cut

use strict;
use warnings;

use WeBWorK::Debug;

# this is similar to the method in the base class, except that Shibboleth
# ensures that we don't get to the address without a login.  this means
# that we can't allow guest logins, but don't have to do any password
# checking or cookie management.

sub get_credentials {
	my ($self) = @_;
	my $c      = $self->{c};
	my $ce     = $c->ce;
	my $db     = $c->db;

	if ($ce->{shiboff} || $c->param('bypassShib')) {
		return $self->SUPER::get_credentials(@_);
	}

	$c->stash(disable_cookies => 1);

	debug("Shib is on!");

	# set external auth parameter so that Login.pm knows
	#    not to rely on internal logins if there's a check_user
	#    failure.
	$self->{external_auth} = 1;

	if ($c->param("user") && !$c->param("force_passwd_authen")) {
		return $self->SUPER::get_credentials(@_);
	}

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

	my $user_id     = "";
	my $shib_header = $ce->{shibboleth}{mapping}{user_id};

	if ($shib_header ne "") {
		$user_id = $c->req->headers->header($shib_header);
	}

	if ($user_id ne "") {
		debug("Got shib header ($shib_header) and user_id ($user_id)");
		if (defined($ce->{shibboleth}{hash_user_id_method})
			&& $ce->{shibboleth}{hash_user_id_method} ne "none"
			&& $ce->{shibboleth}{hash_user_id_method} ne "")
		{
			use Digest;
			my $digest = Digest->new($ce->{shibboleth}{hash_user_id_method});
			$digest->add(
				uc($user_id)
					. (defined $ce->{shibboleth}{hash_user_id_salt} ? $ce->{shibboleth}{hash_user_id_salt} : ""));
			$user_id = $digest->hexdigest;
		}
		$self->{'user_id'} = $user_id;
		$self->{c}->param("user", $user_id);

		# the session key isn't used (Shibboleth is managing this
		#    for us), and we want to force checking against the
		#    site_checkPassword
		$self->{'session_key'}       = undef;
		$self->{'password'}          = 1;
		$self->{login_type}          = "normal";
		$self->{'credential_source'} = "params";

		return 1;
	}

	debug("Couldn't shib header or user_id");
	my $go_to = $ce->{shibboleth}{login_script} . "?target=" . $c->url_for->to_abs;
	$self->{redirect} = $go_to;
	$c->redirect_to($go_to);
	return 0;
}

sub site_checkPassword {
	my ($self, $userID, $clearTextPassword) = @_;

	if ($self->{c}->ce->{shiboff} || $self->{c}->param('bypassShib')) {
		return $self->SUPER::checkPassword(@_);
	} else {
		# this is easy; if we're here at all, we've authenticated
		# through shib
		return 1;
	}
}

# this is a bit of a cheat, because it does the redirect away from the
#   logout script or what have you, but I don't see a way around that.
sub forget_verification {
	my ($self, @args) = @_;
	my $c = $self->{c};

	if ($c->ce->{shiboff}) {
		return $self->SUPER::forget_verification(@_);
	} else {
		$self->{was_verified} = 0;
		$self->{redirect}     = $c->ce->{shibboleth}{logout_script};
	}
}

# returns ($sessionExists, $keyMatches, $timestampValid)
# if $updateTimestamp is true, the timestamp on a valid session is updated
# override function: allow shib to handle the session time out
sub check_session {
	my ($self, $userID, $possibleKey, $updateTimestamp) = @_;
	my $ce = $self->{c}->ce;
	my $db = $self->{c}->db;

	if ($ce->{shiboff}) {
		return $self->SUPER::check_session(@_);
	} else {
		my $Key = $db->getKey($userID);    # checked
		return 0 unless defined $Key;

		my $keyMatches     = (defined $possibleKey and $possibleKey eq $Key->key);
		my $timestampValid = (time <= $Key->timestamp() + $ce->{sessionTimeout});
		if ($ce->{shibboleth}{manage_session_timeout}) {
			# always valid to allow shib to take control of timeout
			$timestampValid = 1;
		}

		if ($keyMatches and $timestampValid and $updateTimestamp) {
			$Key->timestamp(time);
			$db->putKey($Key);
		}
		return (1, $keyMatches, $timestampValid);
	}
}

1;
