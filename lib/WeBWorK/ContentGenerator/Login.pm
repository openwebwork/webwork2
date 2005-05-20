################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Login.pm,v 1.25 2005/05/17 18:40:12 apizer Exp $
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
use WeBWorK::Utils qw(readFile dequote);

# This content generator is NOT logged in.
sub if_loggedin {
	my ($self, $arg) = @_;
	
	return !$arg;
}

sub info {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
	
	my $site_info = $ce->{webworkFiles}->{site_info};
	
	if (defined $site_info and $site_info) {
		my $site_info_path = $site_info;
		
		# deal with previewing a temporary file
		if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile"
				and defined $r->param("editFileSuffix")) {
			$site_info_path .= $r->param("editFileSuffix");
		}
		
		if (-f $site_info_path) {
			my $text = eval { readFile($site_info_path) };
			if ($@) {
				print CGI::div({class=>"ResultsWithError"},
					CGI::p("$@"),
				);
			} else {
				print CGI::p(CGI::b("Important Message")), $text,CGI::hr();
			}
		}
		
		
	}
	my $login_info = $ce->{courseFiles}->{login_info};
	
	if (defined $login_info and $login_info) {
		my $login_info_path = $ce->{courseDirs}->{templates} . "/$login_info";
		
		# deal with previewing a temporary file
		if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile"
				and defined $r->param("editFileSuffix")) {
			$login_info_path .= $r->param("editFileSuffix");
		}
		
		if (-f $login_info_path) {
			my $text = eval { readFile($login_info_path) };
			if ($@) {
				print CGI::div({class=>"ResultsWithError"},
					CGI::p("$@"),
				);
			} else {
				print CGI::p(CGI::b("Login Info")), $text;
			}
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
	
	# get some stuff together
	my $user = $r->param("user") || "";
	my $key = $r->param("key");
	my $passwd = $r->param("passwd") || "";
	my $course = $urlpath->arg("courseID");
	my $practiceUserPrefix = $ce->{practiceUserPrefix};
	
	# don't fill in the user ID for practice users
	# (they should use the "Guest Login" button)
	$user = "" if $user =~ m/^$practiceUserPrefix/;
	
	# WeBWorK::Authen::verify will set the note "authen_error" 
	# if invalid authentication is found.  If this is done, it's a signal to
	# us to yell at the user for doing that, since Authen isn't a content-
	# generating module.
	if ($r->notes("authen_error")) {
		print CGI::div({class=>"ResultsWithError"},
			CGI::p($r->notes("authen_error"))
		);
	}
	
	print CGI::p("Please enter your username and password for ",CGI::b($course)," below:");
	print CGI::p(dequote <<"	EOT");
		If you check ${\( CGI::b("Remember Me") )} &nbsp;your login information will
		be remembered by the browser you are using, allowing you to visit
		WeBWorK pages without typing your user name and password (until your
		session expires). This feature is not safe for public workstations,
		untrusted machines, and machines over which you do not have direct
		control.
	EOT
	
	print CGI::startform({-method=>"POST", -action=>$r->uri});

	
	# preserve the form data posted to the requested URI
	my @fields_to_print = grep { not m/^(user|passwd|key|force_passwd_authen)$/ } $r->param;
	
	#FIXME:  This next line can be removed in time.  MEG 1/27/2005
	warn "Error in filtering fields : |", join("|",@fields_to_print),"|" if grep {m/user/} @fields_to_print;
	
	# Important note. If hidden_fields is passed an empty array it prints ALL parameters as hidden fields.
	# That is not what we want in this case, so we don't print at all if @fields_to_print is empty.
	print $self->hidden_fields(@fields_to_print) if @fields_to_print > 0;
	
	print CGI::table({class=>"FormLayout"}, 
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
	);
	
	print CGI::input({-type=>"submit", -value=>"Continue"});
	print CGI::endform();
	
	# form for guest login
	if (grep m/^$practiceUserPrefix/, $db->listUsers) {
		print CGI::startform({-method=>"POST", -action=>$r->uri});
		
		# preserve the form data posted to the requested URI
		my @fields_to_print = grep { not m/^(user|passwd|key|force_passwd_authen)$/ } $r->param;
		print $self->hidden_fields(@fields_to_print);
		
		print CGI::p(dequote <<"		EOT");
			This course supports guest logins. Click ${\( CGI::b("Guest Login") )}
			&nbsp;to log into this course as a guest.
		EOT
		print CGI::input({-type=>"submit", -name=>"login_practice_user", -value=>"Guest Login"});
	    
	    print CGI::endform();
	}
	
	return "";
}

1;
