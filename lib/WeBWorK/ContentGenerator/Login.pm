################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Login.pm,v 1.47 2012/06/08 22:59:55 wheeler Exp $
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
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Login - display a login form.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Utils qw(readFile dequote);

use mod_perl;
use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

# This content generator is NOT logged in.
# BUT one must return a 1 so that error messages can be displayed.
sub if_loggedin {
	my ($self, $arg) = @_;
#	return !$arg;
	return 1;
}

sub info {

	######### NOTES ON TRANSLATION
	# -translation of the content found in the info panel.  Since most of this content is in fact read from files, a simple use of maketext would be too limited to translate these types of content efficiently.

	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
	my $result;
	# This section should be kept in sync with the Home.pm version
	# list the login info first.
	
	# FIXME this is basically the same code as below... TIME TO REFACTOR!
	my $login_info = $ce->{courseFiles}->{login_info};

	if (defined $login_info and $login_info) {
		# login info is relative to the templates directory, apparently
		$login_info = $ce->{courseDirs}->{templates} . "/$login_info";
		
		# deal with previewing a temporary file
		# FIXME: DANGER: this code allows viewing of any file
		# FIXME: this code is disabled because PGProblemEditor no longer uses editFileSuffix
		#if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile"
		#		and defined $r->param("editFileSuffix")) {
		#	$login_info .= $r->param("editFileSuffix");
		#}
		
		if (-f $login_info) {
			my $text = eval { readFile($login_info) };
			if ($@) {
				$result .= CGI::h2($r->maketext("Login Info"));
				$result .= CGI::div({class=>"ResultsWithError"}, $@);
			} elsif ($text =~ /\S/) {
				$result .= CGI::h2($r->maketext("Login Info"));
				$result .= $text;
			}
		}
	}

	my $site_info = $ce->{webworkFiles}->{site_info};
	if (defined $site_info and $site_info) {
		# deal with previewing a temporary file
		# FIXME: DANGER: this code allows viewing of any file
		# FIXME: this code is disabled because PGProblemEditor no longer uses editFileSuffix
		#if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile"
		#		and defined $r->param("editFileSuffix")) {
		#	$site_info .= $r->param("editFileSuffix");
		#}
		
		if (-f $site_info) {
			my $text = eval { readFile($site_info) };
			if ($@) {
				$result .= CGI::h2($r->maketext("Site Information"));
				$result .= CGI::div({class=>"ResultsWithError"}, $@);
			} elsif ($text =~ /\S/) {
				$result .= CGI::h2($r->maketext("Site Information"));
				$result .= $text;
			}
		}
	}
	

	
	if (defined $result and $result ne "") {
		return CGI::div({-class=>"info-wrapper"},CGI::div({class=>"info-box", id=>"InfoPanel"}, $result));
	} else {
		return "";
	}
}

sub links {
	my @return = (" ");
	return( @return);
}

sub pre_header_initialize {
	my ($self) = @_;
	my $authen = $self->r->authen;
	
	if ( defined($authen->{redirect}) && $authen->{redirect} ) {
		$self->reply_with_redirect($authen->{redirect});
	}
}


sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;

	# get the authen object to make sure that we should print
	#    a login form or not
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
	my $authen_error = MP2 ? $r->notes->get("authen_error") : $r->notes("authen_error");
	if ($authen_error) {
		print CGI::div({class=>"ResultsWithError"},
			CGI::p($authen_error)
		);
	}

	if ( $externalAuth ) {
		if ($authen_error) {
			if ($r -> authen() eq "WeBWorK::Authen::LTIBasic") {
				print CGI::div({class=>"ResultsWithError"},
				CGI::p({}, CGI::b($course), "uses an external", 
				"authentication system.  Please go there to try again."));
			} else {
				print CGI::p({}, $r->maketext("_EXTERNAL_AUTH_MESSAGE", CGI::strong($r->maketext($course))));
			}
		} else {
	    	print CGI::p({}, "Your session has expired due to inactivity.  ",
			CGI::b($course), "uses an external", 
			"authentication system (e.g., Oncourse,  CAS,  Blackboard, Moodle, Canvas, etc.).  ",
			"Please return to system you used and enter WeBWorK anew.");
		} 
	} else {
		print CGI::p($r->maketext("Please enter your username and password for [_1] below:", CGI::b($r->maketext($course))));
		if ($ce -> {session_management_via} ne "session_cookie") {
			print CGI::p($r->maketext("_LOGIN_MESSAGE", CGI::b($r->maketext("Remember Me"))));
		}
	
		print CGI::startform({-method=>"POST", -action=>$r->uri, -id=>"login_form"});

	
		# preserve the form data posted to the requested URI
		my @fields_to_print = grep { not m/^(user|passwd|key|force_passwd_authen)$/ } $r->param;
	
		#FIXME:  This next line can be removed in time.  MEG 1/27/2005
		# warn "Error in filtering fields : |", join("|",@fields_to_print),"|" if grep {m/user/} @fields_to_print;
		# the above test was an attempt to discover why "user" was 
		# being multiply defined.  We caught that error, but this 
		# warning causes trouble with UserList.pm which now has 
		# fields visible_users and prev_visible_users
	
	
		# Important note. If hidden_fields is passed an empty array 
		# it prints ALL parameters as hidden fields.  That is not 
		# what we want in this case, so we don't print at all if 
		# @fields_to_print is empty.
		print $self->hidden_fields(@fields_to_print) if @fields_to_print > 0;
	
	
		# print CGI::table({class=>"FormLayout"}, 
			# CGI::Tr([
				# CGI::td([
		  		# "Username:",
		  		# CGI::input({-type=>"text", -name=>"user", -value=>"$user"}),
				# ]),CGI::br(),
				# CGI::td([
		  		# "Password:",
		  		# CGI::input({-type=>"password", -name=>"passwd", -value=>"$passwd"}),
				# ]),CGI::br(),
				# CGI::td([
		  		# "",
		  		# CGI::checkbox(
				# -name=>"send_cookie",
				# -label=>"Remember Me",
		  		# ),
				# ]),
	  		# ])
		# );
		
		print CGI::br(),CGI::br();
		print WeBWorK::CGI_labeled_input(-type=>"text", -id=>"uname", -label_text=>$r->maketext("Username").": ", -input_attr=>{-name=>"user", -value=>"$user"}, -label_attr=>{-id=>"uname_label"});
		print CGI::br();
		print WeBWorK::CGI_labeled_input(-type=>"password", -id=>"pswd", -label_text=>$r->maketext("Password").": ", -input_attr=>{-name=>"passwd", -value=>"$passwd"}, -label_attr=>{-id=>"pswd_label"});
		print CGI::br();
		if ($ce -> {session_management_via} ne "session_cookie") {
			print WeBWorK::CGI_labeled_input(-type=>"checkbox", -id=>"rememberme", -label_text=>$r->maketext("Remember Me"), -input_attr=>{-name=>"send_cookie", -value=>"on"});
		}
		print CGI::br();
		print WeBWorK::CGI_labeled_input(-type=>"submit", -input_attr=>{-value=>$r->maketext("Continue")});
		print CGI::br();
		print CGI::endform();
	
		# figure out if there are any valid practice users
		# DBFIXME do this with a WHERE clause
		my @guestUserIDs = grep m/^$practiceUserPrefix/, $db->listUsers;
		my @GuestUsers = $db->getUsers(@guestUserIDs);
		my @allowedGuestUsers;
		foreach my $GuestUser (@GuestUsers) {
			next unless defined $GuestUser->status;
			next unless $GuestUser->status ne "";
			push @allowedGuestUsers, $GuestUser
				if $ce->status_abbrev_has_behavior($GuestUser->status, "allow_course_access");
		}
	
		# form for guest login
		if (@allowedGuestUsers) {
			print CGI::startform({-method=>"POST", -action=>$r->uri});
		
			# preserve the form data posted to the requested URI
			my @fields_to_print = grep { not m/^(user|passwd|key|force_passwd_authen)$/ } $r->param;
			print $self->hidden_fields(@fields_to_print);
		
			print CGI::p($r->maketext("_GUEST_LOGIN_MESSAGE", CGI::b($r->maketext("Guest Login"))));
			print CGI::input({-type=>"submit", -name=>"login_practice_user", -value=>$r->maketext("Guest Login")});
	    
	    		print CGI::endform();
		}
	}
	return "";
}

1;
