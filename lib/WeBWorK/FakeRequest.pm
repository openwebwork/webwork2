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

package WeBWorK::FakeRequest;
use parent qw(WeBWorK::Request);

=head1 NAME

WeBWorK::FakeRequest

=head1 SYNPOSIS

 	$fake_r = WeBWorK::FakeRequest->new ($input_hash, 'rpc_module')

=head1 DESCRIPTION

Imitate WeBWorK::Request behavior without an actual Mojolicious::Controller
object.

This module is not actually used by webwork2 anymore.  It can be used to
facilitate authorization and authentication when the input hash is not a
WeBWorK::Request object but does contain the authorization and authentication
data.

It might be applicable for use elsewhere.

Instead of being called with a Mojolicious::Controller object, this request
object gets its data from an HTML data form.  It fakes the essential properties
of the WeBWorK::Request object needed for authentication.

=cut

use strict;
use warnings;

use WeBWorK::Utils qw(runtime_use);

=over

=item new (input, authen_module_name)

Typically authen_module_name would be the rpc_module.

The items userID, session_key, courseID, course_password, are taken from input
and added to the FakeRequest instance variables as user, key, courseName and
passwd.

=cut

sub new {
	my ($class, $rh_input, $authen_module_name) = @_;

	my $self = bless {
		user       => $rh_input->{userID},
		key        => $rh_input->{session_key},
		courseName => $rh_input->{courseID},
		passwd     => $rh_input->{course_password},
		# backwards compatible names
		user_id     => $rh_input->{userID},
		password    => $rh_input->{course_password},
		session_key => $rh_input->{session_key},

		authen  => '',
		authz   => '',
		urlpath => '',
		xmlrpc  => 1,
		%$rh_input,
	}, $class;

	# Create CourseEnvironment
	my $ce = $self->ce(WeBWorK::CourseEnvironment->new({
		webwork_dir => $WeBWorK::Constants::WEBWORK_DIRECTORY,
		courseName  => $self->{courseName}
	}));
	warn "Unable to find environment for course: |$self->{courseName}|" unless ref $ce;

	# Create database object
	$self->db(WeBWorK::DB->new($ce->{dbLayout}));

	# Store Localization subroutine
	$self->language_handle(WeBWorK::Localize::getLoc($ce->{language} || 'en'));

	# Create, initialize, and store authen object
	my $user_authen_module = WeBWorK::Authen::class($ce, $authen_module_name);
	runtime_use $user_authen_module;
	$self->authen($user_authen_module->new($self));

	# Create and store authz object
	$self->authz(WeBWorK::Authz->new($self));
	return $self;
}

=item METHODS that emulate WeBWorK::Request methods

    param
    useragent_ip
    remote_port
    headers_in

These methods imitate behavior of the corresponding WeBWorK::Request method, but
don't do the things that require an actual network request.

=back

=cut

sub param {
	my ($self, $param) = @_;
	return $self->{$param};
}

sub useragent_ip {
	return 'fake ip';
}

sub remote_port {
	return;
}

sub headers_in {
	return { 'User-Agent' => 'fake user agent' };
}

=head1 METHODS inherited from WeBWorK::Request

=over

=item ce([$new])

Return the course environment (WeBWorK::CourseEnvironment) associated with this
request. If $new is specified, set the course environment to $new before
returning the value.

=item db([$new])

Return the database (WeBWorK::DB) associated with this request. If $new is
specified, set the database to $new before returning the value.

=item authen([$new])

Return the authenticator (WeBWorK::Authen) associated with this request. If $new
is specified, set the authenticator to $new before returning the value.

=item authz([$new])

Return the authorizer (WeBWorK::Authz) associated with this request. If $new is
specified, set the authorizer to $new before returning the value.

=item urlpath([$new])

Return the URL path (WeBWorK::URLPath) associated with this request. If $new is
specified, set the URL path to $new before returning the value. (Does this need
modification from the WeBWorK::Request version???)

=item language_handle([$new])

Return the URL path (WeBWorK::URLPath) associated with this request. If $new is
specified, set the URL path to $new before returning the value.

=item maketext([$new])

Return the subroutine that translates phrases (defined in WeBWorK::Localization)

=cut

1;
