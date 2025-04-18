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

package WeBWorK::Controller;
use Mojo::Base 'Mojolicious::Controller', -signatures;

=head1 NAME

WeBWorK::Controller - a controller for the WeBWorK Mojolicious app.  It is a
subclass of the Mojolicious::Controller class with additional WeBWorK-specific
fields.

=cut

use Encode;
use Mojo::JSON qw(encode_json);

use WeBWorK::Localize;

# The Mojolicous::Controller param method does not work quite the same as the previous WeBWorK::Controller method did.
# So this override method emulates the old behavior.
# FIXME: This override should be dropped and the Mojolicious::Controller param and every_param methods used directly.
# Mojolicious already keeps a cache of parameter values and also allows setting of parameters.  So everything done here
# is redundant.
sub param ($c, @opts) {
	my ($name, $val) = @opts;
	if (!defined $c->{paramcache}) {
		for my $name (@{ $c->req->params->names }) {
			$c->{paramcache}{$name} = $c->req->every_param($name);
		}
	}

	return keys %{ $c->{paramcache} } unless $name;

	if (@opts == 2) {
		if (!defined $val) {
			$c->{paramcache}{$name} = [];
		} elsif (ref $val eq 'ARRAY') {
			$c->{paramcache}{$name} = [@$val];    # Make a copy
		} else {
			$c->{paramcache}{$name} = [$val];
		}
		# Set the Mojo::Message::Request param value to the same thing as the paramcache value.
		# This ensures that the values set via this method are picked up in forms.
		$c->req->param($name, $c->{paramcache}{$name});
	}
	return unless exists $c->{paramcache}{$name};
	return wantarray ? @{ $c->{paramcache}{$name} } : $c->{paramcache}{$name}[0];
}

sub setSessionParams ($c) {
	$c->app->sessions->cookie_name(
		$c->stash('courseID') ? 'WeBWorKCourseSession.' . $c->stash('courseID') : 'WeBWorKGeneralSession');

	# If the hostname is 'localhost' or '127.0.0.1', then the cookie domain must be omitted.
	my $hostname = $c->req->url->to_abs->host;
	$c->app->sessions->cookie_domain($hostname) if $hostname ne 'localhost' && $hostname ne '127.0.0.1';

	$c->app->sessions->cookie_path($c->ce->{webworkURLRoot});
	$c->app->sessions->secure($c->ce->{CookieSecure});

	# If this is a session for LTI content selection, then always use SameSite None. Otherwise cookies will not be
	# sent since this is in an iframe embedded in the LMS.
	$c->app->sessions->samesite($c->stash->{isContentSelection} ? 'None' : $c->ce->{CookieSameSite});

	return;
}

# Override the Mojolicious::Controller session method to set the cookie parameters
# from the course environment the first time it is called.
sub session ($c, @args) {
	return {} if $c->stash('disable_cookies');

	# Initialize the cookie session the first time this is called.
	unless ($c->stash->{'webwork2.cookie_session_initialized'}) {
		$c->stash->{'webwork2.cookie_session_initialized'} = 1;
		$c->setSessionParams;
	}

	return $c->SUPER::session(@args);
}

=head1 METHODS

=over

=item $c->ce([$new])

Return the course environment (WeBWorK::CourseEnvironment) associated with this
request. If $new is specified, set the course environment to $new before
returning the value.  In this case the value of $new is also saved to the stash
as 'ce'.  This means that this value is available as $ce in the templates.

=cut

sub ce ($c, $new = undef) {
	$c->stash->{ce} = $c->{ce} = $new if defined $new;
	return $c->stash->{ce};
}

=item $c->db([$new])

Return the database (WeBWorK::DB) associated with this request. If $new is
specified, set the database to $new before returning the value.  In this case
the value of $new is also saved to the stash as 'db'.  This means that this is
available as $db in the templates.

=cut

sub db ($c, $new = undef) {
	$c->stash->{db} = $c->{db} = $new if defined $new;
	return $c->stash->{db};
}

=item $c->authen([$new])

Return the authenticator (WeBWorK::Authen) associated with this request. If $new
is specified, set the authenticator to $new before returning the value.  In this
case the value of $new is also saved to the stash as 'authen'.  This means that
this value is available as $authen in the templates.

=cut

sub authen ($c, $new = undef) {
	$c->stash->{authen} = $c->{authen} = $new if defined $new;
	return $c->stash->{authen};
}

=item $c->authz([$new])

Return the authorizer (WeBWorK::Authz) associated with this request. If $new is
specified, set the authorizer to $new before returning the value.  In this case
the value of $new is also saved to the stash as 'authz'.  This means that this
value is available as $authz in the templates.

=cut

sub authz ($c, $new = undef) {
	$c->stash->{authz} = $c->{authz} = $new if defined $new;
	return $c->stash->{authz};
}

=item $c->submitTime([$new])

Return the time this request was received for processing, which we refer
to as the submitTime. The time is recorded very early on in the processing
of the request. If $new is specified, set submitTime to $new before returning
the value.

=cut

sub submitTime ($c, $new = undef) {
	$c->stash->{submitTime} = $c->{submitTime} = $new if defined $new;
	return $c->stash->{submitTime};
}

sub language_handle ($c, $new = undef) {
	$c->stash->{language_handle} = $c->{language_handle} = $new if defined $new;
	return $c->stash->{language_handle};
}

=head1 ERROR OUTPUT FUNCTIONS

=over

=item textMessage($c, $exception, $uuid, $time)

Format a message for HTML output reporting an exception and any
associated warnings.

=cut

sub textMessage ($c, $uuid, $time) {
	my $uri = $c->req->url->to_abs->to_string;

	my $exception = $c->stash->{exception} // '';

	my %headers = %{ $c->req->headers->to_hash };
	# Avoid JSON errors for the value of 'sec-ch-ua'.
	if (defined($headers{'sec-ch-ua'})) {
		$headers{'sec-ch-ua'} = join('', $headers{'sec-ch-ua'});
		$headers{'sec-ch-ua'} =~ s/\"//g;
	}

	my $additional_json = encode_json({
		'Error record identifier' => $uuid,
		Time                      => $time,
		Method                    => $c->req->method,
		URI                       => $uri,
		'HTTP Headers'            => {%headers},
		Warnings                  => [ defined $c->stash->{warnings} ? split m/\n+/, $c->stash->{warnings} : () ],
	});

	return "[$uuid] [$uri] $additional_json $exception";
}

=item jsonMessage($c, $uuid, $time)

Format a JSON message for log output reporting an exception and any
associated warnings.

=cut

sub jsonMessage ($c, $uuid, $time) {
	my %headers = %{ $c->req->headers->to_hash };
	# Avoid JSON errors for the value of 'sec-ch-ua'.
	if (defined($headers{'sec-ch-ua'})) {
		$headers{'sec-ch-ua'} = join('', $headers{'sec-ch-ua'});
		$headers{'sec-ch-ua'} =~ s/\"//g;
	}

	return encode_json({
		'Error record identifier' => $uuid,
		Time                      => $time,
		Method                    => $c->req->method,
		URI                       => $c->req->url->to_abs->to_string,
		'HTTP Headers'            => {%headers},
		Warnings                  => [ defined $c->stash->{warnings} ? split m/\n+/, $c->stash->{warnings} : () ],
		Exception                 => $c->stash->{exception} ? $c->stash->{exception}->to_string : ''
	});
}

=back

=cut

1;
