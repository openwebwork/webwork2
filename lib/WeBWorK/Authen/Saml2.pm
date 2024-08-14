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

package WeBWorK::Authen::Saml2;
use Mojo::Base 'WeBWorK::Authen', -strict, -signatures;

use WeBWorK::Debug;

=head1 NAME

WeBWorK::Authen::Saml2 - Sends everyone to the SAML2 IdP to authenticate.

Requires the Saml2 plugin to be loaded and configured.

=cut

sub request_has_data_for_this_verification_module ($self) {
	my $c = $self->{c};
	$self->setIsLoggedIn(0);

	# skip if Saml2 plugin config is missing, this means the plugin isn't loaded
	if (!-e "$ENV{WEBWORK_ROOT}/conf/authen_saml2.yml") {
		debug('Saml2 Authen Module requires Saml2 plugin to be configured');
		return 0;
	}
	# skip if we have the param that indicates we want to bypass SAML2
	my $bypassQuery = $c->saml2->getConf->{bypass_query};
	if ($bypassQuery && $c->param($bypassQuery)) {
		debug('Saml2 Authen module bypass detected, going to next module');
		return 0;
	}
	# handle as existing session if we have cookie or if it's a rpc
	my ($cookieUser, $cookieKey, $cookieTimeStamp) = $self->fetchCookie;
	if (defined $cookieUser || defined $c->{rpc}) {
		$self->setIsLoggedIn(1);
	}

	return 1;
}

sub do_verify ($self) {
	if ($self->{saml2UserId} || $self->{isLoggedIn}) {
		# successful saml response/already logged in, hand off to the parent
		# to create/read the session
		$self->{external_auth} = 1;    # so we skip internal 2fa
		return $self->SUPER::do_verify();
	}
	# user doesn't have an existing session, send them to IdP for login
	my $c  = $self->{c};
	my $ce = $c->{ce};
	debug('User needs to go to the IdP for login');
	debug('If login successful, user should be in course: ' . $ce->{courseName});
	debug('With the URL ' . $c->req->url);
	$c->saml2->sendLoginRequest($c->req->url->to_string, $ce->{courseName});

	# we fail verify for this request but doesn't matter cause the user gets
	# redirected to the IdP
	return 0;
}

sub get_credentials ($self) {
	if ($self->{saml2UserId}) {
		# user has been authed by the IdP
		$self->{user_id}           = $self->{saml2UserId};
		$self->{login_type}        = "normal";
		$self->{credential_source} = "SAML2";
		$self->{session_key}       = undef;
		$self->{initial_login}     = 1;
		return 1;
	}
	if ($self->{isLoggedIn}) {
		return $self->SUPER::get_credentials();
	}
	return 0;
}

sub authenticate ($self) {
	# idp has authenticated us, so we can just return 1
	return 1;
}

sub setSaml2UserId ($self, $userId) {
	$self->{saml2UserId} = $userId;
}

sub setIsLoggedIn ($self, $val) {
	$self->{isLoggedIn} = $val;
}

1;
