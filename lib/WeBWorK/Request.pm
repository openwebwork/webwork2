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

use strict;
use warnings;

use Encode;

use WeBWorK::Localize;

=head1 CONSTRUCTOR

=over

=item WeBWorK::Request->new($controller)

Creates a new WeBWorK::Request. A Mojolicious::Controller object must be passed.

=back

=cut

sub new {
	my ($invocant, $controller) = @_;
	my $class = ref $invocant || $invocant;
	# Construct the superclass instance
	my $self = $controller;
	return bless $self, $class;
}

# The Mojolicous::Controller param method does not work quite the same as the previous WeBWorK::Request method did. So
# this override method emulates the old behavior.
sub param {
	my ($self, $name, $val) = @_;

	if (!defined $self->{paramcache}) {
		for my $name (@{ $self->SUPER::req->params->names }) {
			$self->{paramcache}{$name} = $self->SUPER::req->every_param($name);
		}
	}

	return keys %{ $self->{paramcache} } unless $name;

	if (defined $val) {
		if (ref $val eq 'ARRAY') {
			$self->{paramcache}{$name} = [@$val];    # make a copy
		} else {
			$self->{paramcache}{$name} = [$val];
		}
	}
	return unless exists $self->{paramcache}{$name};
	return wantarray ? @{ $self->{paramcache}{$name} } : $self->{paramcache}{$name}->[0];
}

=head1 METHODS

=over

=item $r->ce([$new])

Return the course environment (WeBWorK::CourseEnvironment) associated with this
request. If $new is specified, set the course environment to $new before
returning the value.

=cut

sub ce {
	my ($self, $new) = @_;
	$self->{ce} = $new if defined $new;
	return $self->{ce};
}

=item $r->db([$new])

Return the database (WeBWorK::DB) associated with this request. If $new is
specified, set the database to $new before returning the value.

=cut

sub db {
	my ($self, $new) = @_;
	$self->{db} = $new if defined $new;
	return $self->{db};
}

=item $r->authen([$new])

Return the authenticator (WeBWorK::Authen) associated with this request. If $new
is specified, set the authenticator to $new before returning the value.

=cut

sub authen {
	my ($self, $new) = @_;
	$self->{authen} = $new if defined $new;
	return $self->{authen};
}

=item $r->authz([$new])

Return the authorizer (WeBWorK::Authz) associated with this request. If $new is
specified, set the authorizer to $new before returning the value.

=cut

sub authz {
	my ($self, $new) = @_;
	$self->{authz} = $new if defined $new;
	return $self->{authz};
}

=item urlpath([$new])

Return the URL path (WeBWorK::URLPath) associated with this request. If $new is
specified, set the URL path to $new before returning the value.

=cut

sub urlpath {
	my ($self, $new) = @_;
	$self->{urlpath} = $new if defined $new;
	return $self->{urlpath};
}

=item $r->submitTime([$new])

Return the time this request was received for processing, which we refer
to as the submitTime. The time is recorded very early on in the processing
of the request. If $new is specified, set submitTime to $new before returning
the value.

=cut

sub submitTime {
	my ($self, $new) = @_;
	$self->{submitTime} = $new if defined $new;
	return $self->{submitTime};
}

sub language_handle {
	my ($self, $new) = @_;
	$self->{language_handle} = $new if defined $new;
	return $self->{language_handle};
}

sub maketext {
	my ($self, @args) = @_;
	return &{ $self->{language_handle} }(@args);
	# Comment out the above line and uncomment below to check that your strings are run through maketext.
	# return 'xXx'.&{ $self->{language_handle} }(@_).'xXx';
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

sub uri {
	my $self = shift;
	return $self->SUPER::req->url->path->to_string;
}

sub headers_in {
	my $self = shift;
	return $self->SUPER::req->headers->to_hash;
}

sub useragent_ip {
	my $self = shift;
	return $self->SUPER::tx->remote_address;
}

sub remote_port {
	my $self = shift;
	return $self->SUPER::tx->remote_port;
}

=head1 adaptLegacyParameters

This provides compatibility for legacy html2xml parameters.

This should be deleted when the html2xml endpoint is removed.

=cut

sub adaptLegacyParameters {
	my $self = shift;

	for ([ 'userID', 'user' ], [ 'courseName', 'courseID' ], [ 'course_password', 'passwd' ], [ 'session_key', 'key' ])
	{
		$self->param($_->[1], $self->param($_->[0])) if defined $self->param($_->[0]) && !defined $self->param($_->[1]);
	}

	return;
}

1;
