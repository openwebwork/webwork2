################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Request.pm,v 1.10 2007/07/23 04:06:32 sh002i Exp $
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

=head1 NAME

WeBWorK::Request - a request to the WeBWorK system, a subclass of
Apache::Request with additional WeBWorK-specific fields.

=cut

use strict;
use warnings;

use mod_perl;
use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );


use WeBWorK::Localize;

# This class inherits from Apache::Request under mod_perl and Apache2::Request under mod_perl2
BEGIN {
    push @WeBWorK::Request::ISA, "WeBWorK::Localize";
	if (MP2) {
		require Apache2::Request;
		Apache2::Request->import;
		push @WeBWorK::Request::ISA, "Apache2::Request";
	} else {
		require Apache::Request;
		Apache::Request->import;
		push @WeBWorK::Request::ISA, "Apache::Request";
	}
}

# Apache2::Request's param method doesn't support setting parameters, so we need to provide the
# behavior in this class if we're running under mod_perl2.
BEGIN {
	if (MP2) {
		*param = *mutable_param;
	}
}

sub mutable_param {
	my $self = shift;
	
	if (not defined $self->{paramcache}) {
		my @names = $self->SUPER::param;
		@{$self->{paramcache}}{@names} = map { [ $self->SUPER::param($_) ] } @names;
	}
	
	@_ or return keys %{$self->{paramcache}};
	
	my $name = shift;
	if (@_) {
		my $val = shift;
		if (ref $val eq "ARRAY") {
			$self->{paramcache}{$name} = [@$val]; # make a copy
		} else {
			$self->{paramcache}{$name} = [$val];
		}
	}
	return unless exists $self->{paramcache}{$name};
	return wantarray ? @{$self->{paramcache}{$name}} : $self->{paramcache}{$name}->[0];
}

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
	# construct the appropriate superclass instance depending on mod_perl version
	my $apreq_class = MP2 ? "Apache2::Request" : "Apache::Request";
	return bless { r => $apreq_class->new(@args) }, $class;
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

=item authen([$new])

Return the authenticator (WeBWorK::Authen) associated with this request. If $new
is specified, set the authenticator to $new before returning the value.

=cut

sub authen {
	my $self = shift;
	$self->{authen} = shift if @_;
	return $self->{authen};
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

sub language_handle {
	my $self = shift;
	$self->{language_handle} = shift if @_;
	return $self->{language_handle};
}

sub maketext {
	my $self = shift;
	&{ $self->{language_handle} }(@_);
	# uncomment to check that your strings are run through maketext
	# return 'xXx'.&{ $self->{language_handle} }(@_).'xXx';
}

=item location()

Overrides the location() method in Apache::Request (or Apache2::Request) so that
if the location is "/", the empty string is returned.

=cut

sub location {
	my $self = shift;
	my $location = $self->SUPER::location;
	return $location eq "/" ? "" : $location;
}

=back

=cut

1;

