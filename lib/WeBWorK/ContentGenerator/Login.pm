################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Login.pm,v 1.20 2004/01/25 15:53:07 gage Exp $
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

package WeBWorK::ContentGenerator::Login;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Login - display a login form.

=cut

use strict;
use warnings;
use CGI qw();

sub title {
	my  $self   = shift;
	my  $r      = $self->{r};
	my  $ce     = $self->{ce};
	my  $courseName  = $ce->{courseName};
	return "Login to $courseName";
}

sub links {
	return "";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $course_env = $self->{ce};
	my $db = $self->{db};
	# get some stuff together
	my $user = $r->param("user") || "";
	my $key = $r->param("key");
	my $passwd = $r->param("passwd") || "";
	my $course = $course_env->{"courseName"};
	my $practiceUserPrefix = $course_env->{practiceUserPrefix};
	
	# don't fill in the user ID for practice users
	# (they should use the "Guest Login" button)
	$user = "" if $user =~ m/^$practiceUserPrefix/;
	
	# WeBWorK::Authen::verify will set the note "authen_error" 
	# if invalid authentication is found.  If this is done, it's a signal to
	# us to yell at the user for doing that, since Authen isn't a content-
	# generating module.
	if ($r->notes("authen_error")) {
		print CGI::p(CGI::font({-color => 'red'},
			CGI::b($r->notes("authen_error"))));
	}
	
	print CGI::p("Please enter your username and password for ",CGI::b($course)," below:");
	print CGI::p(
		"If you check \"Remember Me\", your session key will be stored in a"
		. " browser cookie for later use. This feature is not safe for public"
		. " workstations, untrusted machines, and machines over which you do"
		. " not have direct control."
	);
	
	print CGI::startform({-method=>"POST", -action=>$r->uri});

	# write out the form data posted to the requested URI
	print $self->print_form_data('<input type="hidden" name="','" value="',"\"/>\n",qr/^(user|passwd|key|force_passwd_authen)$/);
	
	print
		CGI::table({-border => 0}, 
		  CGI::Tr([
		    CGI::td([
		      "Username:",
		      CGI::input({-type=>"text", -name=>"user", -value=>"$user"}),
		    ]),
		    CGI::td([
		      "Password:",
		      CGI::input({-type=>"password", -name=>"passwd", -value=>"$passwd"}),
		    ]),
		    CGI::td([
		      "",
			  CGI::checkbox(
			    -name=>"send_cookie",
				-label=>"Remember Me",
			  ),
		    ]),
		 ])
		)
	;
	
	print CGI::input({-type=>"submit", -value=>"Continue"});
	print CGI::endform();
	
	if (grep m/^$practiceUserPrefix/, $db->listUsers) {
	    print CGI::startform({-method=>"POST", -action=>$r->uri});
	    print $self->print_form_data('<input type="hidden" name="','" value="',"\"/>\n",qr/^(user|passwd|key|force_passwd_authen)$/);
		print CGI::p(
			"This course supports guest logins. Click " . CGI::b("Guest Login")
			. " to log into this course as a guest.",
			CGI::br(),
			CGI::input({-type=>"submit", -name=>"login_practice_user", -value=>"Guest Login"}),
		);
	    print CGI::endform();
	}
	return "";
}

sub info {
	my $self = shift;
	my $r    = $self->{r};
	my $ce   = $self->{ce};
	my $db   = $self->{db};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};


	if (defined $ce->{courseFiles}->{login_info}
		and $ce->{courseFiles}->{login_info}) {
		my $login_info_path  = $ce->{courseDirs}->{templates}
		                     .'/'. $ce->{courseFiles}->{login_info};
		$login_info_path    .= '.'.$r->param("editFileSuffix") 
		        if defined($r->param("editMode") ) and $r->param("editMode") eq 'temporaryFile'  and defined($r->param("editFileSuffix"));

		my $login_info = eval { WeBWorK::Utils::readFile($login_info_path) };
		$@ or print $login_info;
		
# 		my $user            = $r->param("user");
# 		my $permissionLevel = $db->getPermissionLevel($user)->permission(); # checked???
# 		$permissionLevel    = 0 unless defined $permissionLevel;
# 		if ($permissionLevel) {
# 			my $editURL = "$root/$courseName/instructor/pgProblemEditor/?"
# 						  .$self->url_authen_args
# 						  ."&file_type=other&edit_file_path="
# 						  .$ce->{courseFiles}->{course_info}
# 			;
# 			my $editText      = "Edit file";
# 			$editText         = "Edit temporary file" if $r->param("editMode") eq 'temporaryFile';
# 			print CGI::br(), CGI::a({-href=>$editURL}, $editText);
# 	    }
	}
	'';
}
# This content generator is NOT logged in.
sub if_loggedin($$) {
	my ($self, $arg) = (@_);
	
	return !$arg;
}

1;
