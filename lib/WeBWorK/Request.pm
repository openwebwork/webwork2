################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Request.pm,v 1.1 2004/03/05 04:16:19 sh002i Exp $
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
use base qw(Apache::Request);

=head1 NAME

WeBWorK::Request - a request to the WeBWorK system, a subclass of
Apache::Request with additional WeBWorK-specific fields.

=cut

use strict;
use warnings;

=head1 CONSTRUCTOR

=over

=item new(@args)

Creates an new WeBWorK::Request. All arguments are passed to Apache::Request's
constructor. You must specify at least an Apache request_rec object.

=for comment

From: http://search.cpan.org/~joesuf/libapreq-1.3/Request/Request.pm#SUBCLASSING_Apache::Request

If the instances of your subclass are hash references then you can actually
inherit from Apache::Request as long as the Apache::Request object is stored in
an attribute called "r" or "_r". (The Apache::Request class effectively does the
delegation for you automagically, as long as it knows where to find the
Apache::Request object to delegate to.)

=cut

sub new {
	my ($invocant, @args) = @_;
	my $class = ref $invocant || $invocant;
	return bless { r => Apache::Request->new(@args) }, $class;
}

=back

=cut

=head1 METHODS

=over

=item ce([$new])

Return the course environment (WeBWorK::CourseEnvironment) associated with this
request. If $new is specified, set the course environment to $new before
returning the value.

=cut

sub ce {
	my $self = shift;
	$self->{ce} = shift if @_;
	return $self->{ce};
}

=item db([$new])

Return the database (WeBWorK::DB) associated with this request. If $new is
specified, set the database to $new before returning the value.

=cut

sub db {
	my $self = shift;
	$self->{db} = shift if @_;
	return $self->{db};
}

=item authz([$new])

Return the authorizer (WeBWorK::Authz) associated with this request. If $new is
specified, set the authorizer to $new before returning the value.

=cut

sub authz {
	my $self = shift;
	$self->{authz} = shift if @_;
	return $self->{authz};
}

=item urlpath([$new])

Return the URL path (WeBWorK::URLPath) associated with this request. If $new is
specified, set the URL path to $new before returning the value.

=cut

sub urlpath {
	my $self = shift;
	$self->{urlpath} = shift if @_;
	return $self->{urlpath};
}

=back

=cut

1;
