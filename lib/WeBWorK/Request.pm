################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::Request;
use Mojo::Base 'Mojolicious::Controller', -signatures;

=head1 NAME

WeBWorK::Request - a request to the WeBWorK system, a subclass of
Mojolicious::Controller with additional WeBWorK-specific fields.

=cut

use Encode;

use WeBWorK::Localize;

# The Mojolicous::Controller param method does not work quite the same as the previous WeBWorK::Request method did. So
# this override method emulates the old behavior.
# FIXME: This override should be dropped and the Mojolicious::Controller param and every_param methods used directly.
# Mojolicious already keeps a cache of parameter values and also allows setting of parameters.  So everything done here
# is redundant.
sub param ($self, $name = undef, $val = undef) {
	if (!defined $self->{paramcache}) {
		for my $name (@{ $self->req->params->names }) {
			$self->{paramcache}{$name} = $self->req->every_param($name);
		}
	}

	return keys %{ $self->{paramcache} } unless $name;

	if (@_ == 3) {
		if (!defined $val) {
			$self->{paramcache}{$name} = [];
		} elsif (ref $val eq 'ARRAY') {
			$self->{paramcache}{$name} = [@$val];    # Make a copy
		} else {
			$self->{paramcache}{$name} = [$val];
		}
		# Set the Mojo::Message::Request param value to the same thing as the paramcache value.
		# This ensures that the values set via this method are picked up in forms.
		$self->req->param($name, $self->{paramcache}{$name});
	}
	return unless exists $self->{paramcache}{$name};
	return wantarray ? @{ $self->{paramcache}{$name} } : $self->{paramcache}{$name}[0];
}

=head1 METHODS

=over

=item $r->ce([$new])

Return the course environment (WeBWorK::CourseEnvironment) associated with this
request. If $new is specified, set the course environment to $new before
returning the value.  In this case the value of $new is also saved to the stash
as 'ce'.  This means that this value is available as $ce in the templates.

=cut

sub ce ($self, $new = undef) {
	$self->stash->{ce} = $self->{ce} = $new if defined $new;
	return $self->{ce};
}

=item $r->db([$new])

Return the database (WeBWorK::DB) associated with this request. If $new is
specified, set the database to $new before returning the value.  In this case
the value of $new is also saved to the stash as 'db'.  This means that this is
available as $db in the templates.

=cut

sub db ($self, $new = undef) {
	$self->stash->{db} = $self->{db} = $new if defined $new;
	return $self->{db};
}

=item $r->authen([$new])

Return the authenticator (WeBWorK::Authen) associated with this request. If $new
is specified, set the authenticator to $new before returning the value.  In this
case the value of $new is also saved to the stash as 'authen'.  This means that
this value is available as $authen in the templates.

=cut

sub authen ($self, $new = undef) {
	$self->stash->{authen} = $self->{authen} = $new if defined $new;
	return $self->{authen};
}

=item $r->authz([$new])

Return the authorizer (WeBWorK::Authz) associated with this request. If $new is
specified, set the authorizer to $new before returning the value.  In this case
the value of $new is also saved to the stash as 'authz'.  This means that this
value is available as $authz in the templates.

=cut

sub authz ($self, $new = undef) {
	$self->stash->{authz} = $self->{authz} = $new if defined $new;
	return $self->{authz};
}

=item urlpath([$new])

Return the URL path (WeBWorK::URLPath) associated with this request. If $new is
specified, set the URL path to $new before returning the value.  In this case
the value of $new is also saved to the stash as 'urlpath'.  This means that this
value is available as $urlpath in the templates.

=cut

sub urlpath ($self, $new = undef) {
	$self->stash->{urlpath} = $self->{urlpath} = $new if defined $new;
	return $self->{urlpath};
}

=item $r->submitTime([$new])

Return the time this request was received for processing, which we refer
to as the submitTime. The time is recorded very early on in the processing
of the request. If $new is specified, set submitTime to $new before returning
the value.

=cut

sub submitTime ($self, $new = undef) {
	$self->stash->{submitTime} = $self->{submitTime} = $new if defined $new;
	return $self->{submitTime};
}

sub language_handle ($self, $new = undef) {
	$self->{language_handle} = $new if defined $new;
	return $self->{language_handle};
}

=item Other methods

    uri
    headers_in
    useragent_ip
    remote_port

These convenience methods map Mojolicious methods to Apache2::Request methods
that were used previously.

=back

=cut

sub uri ($self) {
	return $self->req->url->path->to_string;
}

sub headers_in ($self) {
	return $self->req->headers->to_hash;
}

sub useragent_ip ($self) {
	return $self->tx->remote_address;
}

sub remote_port ($self) {
	return $self->tx->remote_port;
}

=head1 adaptLegacyParameters

This provides compatibility for legacy html2xml parameters.

This should be deleted when the html2xml endpoint is removed.

=cut

sub adaptLegacyParameters ($self) {
	for ([ 'userID', 'user' ], [ 'courseName', 'courseID' ], [ 'course_password', 'passwd' ], [ 'session_key', 'key' ])
	{
		$self->param($_->[1], $self->param($_->[0])) if defined $self->param($_->[0]) && !defined $self->param($_->[1]);
	}

	return;
}

1;
