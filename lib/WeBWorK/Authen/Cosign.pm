################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen/Cosign.pm,v 1.2 2007/03/27 17:06:04 glarose Exp $
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

package WeBWorK::Authen::Cosign;
use base qw/WeBWorK::Authen/;

=head1 NAME

WeBWorK::Authen::Cosign - Authentication plug in for cosign

to use: include in localOverrides.conf or course.conf
  $authen{user_module} = "WeBWorK::Authen::Cosign";
and add /webwork2 or /webwork2/courseName as a CosignProtected
Location

if $r->ce->{cosignoff} is set for a course, authentication reverts
to standard WeBWorK authentication.

=cut

use strict;
use warnings;
use WeBWorK::Debug;

# this is similar to the method in the base class, except that cosign 
# ensures that we don't get to the address without a login.  this means
# that we can't allow guest logins, but don't have to do any password
# checking or cookie management.

sub get_credentials {
	my ($self) = @_;
	my $r = $self->{r};
	my $ce = $r->ce;
	my $db = $r->db;
	
	if ( $ce->{cosignoff} ) {
		return $self->SUPER::get_credentials( );
	} else {
		if ( defined( $ENV{'REMOTE_USER'} ) ) {
			$self->{'user_id'} = $ENV{'REMOTE_USER'};
			$self->{r}->param("user", $ENV{'REMOTE_USER'});
		} else {
			return 0;
		}
		# set external auth parameter so that Login.pm knows
		#    not to rely on internal logins if there's a check_user
		#    failure.
		$self->{external_auth} = 1;

		# the session key isn't used (cosign is managing this 
		#    for us), and we want to force checking against the 
		#    site_checkPassword
		$self->{'session_key'} = undef;
		$self->{'password'} = 1;
		$self->{'credential_source'} = "params";
		$self->{login_type} = "cosign";
		
		return 1;
	}
}

sub site_checkPassword { 
	my ( $self, $userID, $clearTextPassword ) = @_;

	if ( $self->{r}->ce->{cosignoff} ) {
	    return 0;
		#return $self->SUPER::checkPassword( $userID, $clearTextPassword );
	} else {
		# this is easy; if we're here at all, we've authenticated
		# through cosign
		return 1;
	}
}

# disable cookie functionality
sub maybe_send_cookie {
	my ($self, @args) = @_;
	if ( $self->{r}->ce->{cosignoff} ) {
		return $self->SUPER::maybe_send_cookie( @args );
	} else {
		# nothing to do here
	}
}
sub fetchCookie {
	my ($self, @args) = @_;
	if ( $self->{r}->ce->{cosignoff} ) {
		return $self->SUPER::fetchCookie( @args );
	} else {
		# nothing to do here
	}
}
sub sendCookie {
	my ($self, @args) = @_;
	if ( $self->{r}->ce->{cosignoff} ) {
		return $self->SUPER::sendCookie( @args);
	} else {
		# nothing to do here
	}
}
sub killCookie {
	my ($self, @args) = @_;
	if ( $self->{r}->ce->{cosignoff} ) {
		return $self->SUPER::killCookie( @args );
	} else {
		# nothing to do here
	}
}

# this is a bit of a cheat, because it does the redirect away from the
#   logout script or what have you, but I don't see a way around that.
sub forget_verification { 
	my ($self, @args) = @_;
	my $r = $self->{r};

	if ( $r->ce->{cosignoff} ) {
		return $self->SUPER::forget_verification( @args);
	} else {
		$self->{was_verified} = 0;
#		$r->headers_out->{"Location"} = $r->ce->{cosign_logout_script};
#		$r->send_http_header;
#		return;
		$self->{redirect} = $r->ce->{cosign_logout_script};
	}
}

1;
