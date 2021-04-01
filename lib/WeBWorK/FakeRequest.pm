################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/Authen/Proctor.pm,v 1.5 2007/04/04 15:05:27 glarose Exp $
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
use parent WeBWorK::Request;

=head1 NAME

	WeBWorK::FakeRequest 

=head1 SYNPOSIS

 	$fake_r = WeBWorK::FakeRequest->new ($input_hash, 'xmlrpc_module')
 
=head1 DESCRIPTION

- Imitate WeBWorK::Request behavior without benefit of Apache::Request

This module is used in the WebworkWebservice suite, specifically by the WebworkXMLRPC, to facilitate
authorization and authentication when the input hash is not an WeBWorK::Request object but does
contain the authorization and authentication data. 

It might be applicable for use elsewhere.

=cut
use strict;
use warnings;
use WeBWorK::Debug;
use WeBWorK::Utils qw(runtime_use);

# Instead of being called with an apache request object $r 
# this RequestObject  gets its data  
# from an HTML data form.  It creates a WeBWorK::FakeRequest object  
# which fakes the essential properties of the WeBWorK::Request object needed for authentication

=head1 METHODS overriding those of WeBWorK::Request


=over

=item new (input, authen_module_name)

Typically authen_module_name would be xmlrpc_module

The  items userID session_key courseID course_password are taken from input
and added to the FakeRequest instance variables as user, key, courseName and passwd.
	
=cut

sub new {
	my $class = shift;    
	my ($rh_input,$authen_module_name) = @_;  #rh_input is required; ce is optional
	my $self = {
		user      		    => $rh_input ->{userID},
		key	 		        => $rh_input ->{session_key},
		courseName   		=> $rh_input ->{courseID},
		passwd              => $rh_input ->{course_password},
		# backwards compatible names
		user_id             => $rh_input ->{userID},
		password    =>  $rh_input ->{course_password},
		session_key =>  $rh_input ->{session_key},

		authen				=> '',
		authz               => '',
		urlpath             => '',
		xmlrpc              => 1,
		%$rh_input,
	};
	#warn "FakeRequest $class, authen_module_name $authen_module_name";
	$self = bless $self, $class;
	debug( "self has type ",ref($self),);
	
	# now we need to finish initializing $fake_r;
	# create CourseEnvironment 
	my $ce = $self->ce( $self->create_course_environment() );
	
	# create database object
	$self->db( WeBWorK::DB->new($ce->{dbLayout}) );
	
	# store Localization subroutine
	my $language= $ce->{language} || "en";
	$self->language_handle(  WeBWorK::Localize::getLoc($language) );
	
	# create, initialize and store authen object
	my $user_authen_module = WeBWorK::Authen::class($ce, $authen_module_name); #default: xmlrpc_module
    runtime_use $user_authen_module;
	my $authen = $user_authen_module->new($self);
	$self->authen($authen);    

	# create and store authz object
	my $authz  =  WeBWorK::Authz->new($self);
	$self->authz($authz); 
	return $self;     	
}

=item param

Imitate get behavior of the Apache::Request object params method

=cut

sub param {    # imitate get behavior of the request object params method
	my $self =shift;
	my $param = shift;
	$self->{$param};
}

=back

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
specified, set the URL path to $new before returning the value. (Does this need modification
from the WeBWorK::Request version???)

=cut

# sub urlpath {
# 	my $self = shift;
# 	$self->{urlpath} = shift if @_;
# 	return $self->{urlpath};
# }

=item language_handle([$new])

Return the URL path (WeBWorK::URLPath) associated with this request. If $new is
specified, set the URL path to $new before returning the value.

=cut

=item maketext([$new])

Return the subroutine that translates phrases (defined in WeBWorK::Localization)

=cut

=item location()

Overrides the location() method in Apache::Request (or Apache2::Request) so that
if the location is "/", the empty string is returned.

=cut

=item create_course_environment()

A method that reads the configuration files and returns the course environment.
It uses the $self->{courseName}  variable.

=cut 

sub create_course_environment {
	my $self = shift;
	my $courseName = $self->{courseName};
	my $ce = WeBWorK::CourseEnvironment->new( 
				{webwork_dir		=>		$WeBWorK::Constants::WEBWORK_DIRECTORY, 
				 courseName         =>      $courseName
				 });
	warn "Unable to find environment for course: |$courseName|" unless ref($ce);
	return ($ce);
}

=back

=cut

1;
