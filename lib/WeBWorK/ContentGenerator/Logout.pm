################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader$
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
use CGI qw();

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
	my $cookie = Apache::Cookie->new($r,
		-name => "WeBWorKAuthentication",
		-value => "",
		-expires => "-1D",
		-domain => $r->hostname,
		-path => $ce->{webworkURLRoot},
		-secure => 0,
	);
	$r->headers_out->set("Set-Cookie" => $cookie->as_string);
}

# This content generator is NOT logged in.
sub if_loggedin {
	my ($self, $arg) = @_;
	
	return !$arg;
}

# suppress links
sub links {
	return "";
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	my $courseID = $urlpath->arg("courseID");
	my $userID = $r->param("user");
	
	eval { $db->deleteKey($userID) };
	if ($@) {
		print CGI::div({class=>"ResultsWithError"},
			CGI::p("Something went wrong while logging out of WeBWorK: $@")
		);
	}

# also check to see if there is a proctor key associated with this login.  if
#    there is a proctor user, then we must have a proctored test, so we try 
#    and delete the key
	my $proctorID = defined($r->param("proctor_user")) ? 
	    $r->param("proctor_user") : '';
	if ( $proctorID ) {
	    eval { $db->deleteKey( "$userID,$proctorID" ); };
	    if ( $@ ) {
		print CGI::div({ class=> "ResultsWithError" }, 
			       CGI::p("Error when clearing proctor key: $@"));
	    }
# we may also have a proctor key from grading the test
	    eval { $db->deleteKey( "$userID,$proctorID,g" ); };
	    if ( $@ ) {
		print CGI::div({ class=> "ResultsWithError" }, 
			       CGI::p("Error when clearing proctor grading " .
				      "key: $@"));
	    }
	}
	
	my $problemSets = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", courseID => $courseID);
	my $loginURL = $r->location . $problemSets->path;
	
	print CGI::p("You have been logged out of WeBWorK.");
	
	print CGI::start_form(-method=>"POST", -action=>$loginURL);
	print CGI::hidden("user", $userID);
	print CGI::hidden("force_passwd_authen", 1);
	print CGI::p({align=>"center"}, CGI::submit("submit", "Log In Again"));
	print CGI::end_form();
	
	return "";
}

1;
