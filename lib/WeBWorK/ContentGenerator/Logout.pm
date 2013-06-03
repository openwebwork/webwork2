################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Logout.pm,v 1.17 2012/06/08 22:50:50 wheeler Exp $
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

package WeBWorK::ContentGenerator::Logout;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Logout - invalidate key and display logout message.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Cookie;
use WeBWorK::Localize;


sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authen = $r->authen;
	
	# get rid of stored authentication info (this is kind of a hack. i have a better way
	# in mind but it requires pretty much rewriting Authen/Login/Logout. :-( FIXME)
#	$authen->forget_verification;
#	
#	my $cookie = WeBWorK::Cookie->new($r,
#		-name => "WeBWorKAuthentication",
#		-value => "",
#		-expires => "-1D",
#		-domain => $r->hostname,
#		-path => $ce->{webworkURLRoot},
#		-secure => 0,
#	);
#	$r->headers_out->set("Set-Cookie" => $cookie->as_string);
#
	my $userID = $r->param("user_id");
	my $keyError = '';
#	eval { $db->deleteKey($userID) };
#	if ($@) {
#		$keyError .= "Something went wrong while logging out of " .
#			"WeBWorK: $@";
#	}

	$authen -> killSession;

	# also check to see if there is a proctor key associated with this 
	#    login.  if there is a proctor user, then we must have a 
	#    proctored test, so we try and delete the key
	my $proctorID = defined($r->param("proctor_user")) ? 
	    $r->param("proctor_user") : '';
	if ( $proctorID ) {
		eval { $db->deleteKey( "$userID,$proctorID" ); };
		if ( $@ ) {
			$keyError .= CGI::p( 
				"Error when clearing proctor key: $@");
		}
	# we may also have a proctor key from grading the test
		eval { $db->deleteKey( "$userID,$proctorID,g" ); };
		if ( $@ ) {
			$keyError .= CGI::p( 
				"Error when clearing proctor grading key: $@");
		}
	}
	$self->{keyError} = $keyError;

	# Do any special processing needed by external authentication
	$authen->logout_user() if $authen->can('logout_user');

	# if we have an authen redirect, all of those errors may be 
	#    moot, but I think that's unavoidable (-glarose)
	if ( defined($authen->{redirect}) && $authen->{redirect} ) {
		$self->reply_with_redirect( $authen->{redirect} );
	}
}

## This content generator is NOT logged in,
## but must return a 1 to get messages.
sub if_loggedin {
	my ($self, $arg) = @_;
#	return !$arg;
	return 1;
}

## suppress links
sub links {
	return "";
}

sub path {
	my ($self, $args) = @_;
	my $r = $self->r;
	my $urlpath = $r->urlpath;
	my $ce = $r->{ce};
	my $authen = $r -> {authen};

	if ((defined($ce -> {external_auth}) and $ce -> {external_auth})
		or (defined($authen -> {external_auth}) and $authen -> {external_auth}) ) {
		my $courseID = $urlpath -> arg("courseID");	
		if (defined($courseID)) {
			print $courseID;
		}
		else {
		$self -> SUPER::path($args);
		}
	}
	return "";
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	my $auth = $r->authen;

	# The following line may not work when a sequence of authentication modules
    # are used, because the preferred module might be external, e.g., LTIBasic,
    # but a non-external one, e.g., Basic_TheLastChance or 
    # even just WeBWorK::Authen, might handle the ongoing session management.
    # So this should be set in the course environment when a sequence of
	# authentication modules is used..
	#my $externalAuth = (defined($auth->{external_auth}) && $auth->{external_auth} ) ? 1 : 0;
	my $externalAuth = ((defined($ce->{external_auth}) && $ce->{external_auth})
 		or (defined($auth->{external_auth}) && $auth->{external_auth}) ) ? 1 : 0;
	
	my $courseID = $urlpath->arg("courseID");
	my $userID = $r->param("user");

	if ( $self->{keyError} ) { 
		print CGI::div({class=>"ResultsWithError"}, $self->{keyError});
	}
	
	my $problemSets = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => $courseID);
	my $loginURL = $r->location . $problemSets->path;
	
	print CGI::p($r->maketext("You have been logged out of WeBWorK."));

	if ( $externalAuth ) {
	   	print 
		CGI::p({}, CGI::b($courseID), "uses an external", 
		"authentication system.  Please go there to login again.");
	} else {
		print CGI::start_form(-method=>"POST", -action=>$loginURL);
	#	print CGI::hidden("user", $userID);  ### Line Commented out to suppress error message when this button is used.  WHW
		print CGI::hidden("force_passwd_authen", 1);
		print CGI::p({align=>"center"}, CGI::submit(-name=>"submit", -label=>$r->maketext("Log In Again")));
		print CGI::end_form();
	}
	return "";
}

1;
