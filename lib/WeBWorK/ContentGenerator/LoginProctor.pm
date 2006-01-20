################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
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

package WeBWorK::ContentGenerator::LoginProctor;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::LoginProctor - display a login form for 
GatewayQuiz proctored tests.

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readFile dequote);
use WeBWorK::ContentGenerator::GatewayQuiz qw(can_recordAnswers);

# This content generator is NOT logged in.
# FIXME  I'm not sure this is really what we want for the proctor login,
# FIXME  but I also don't know what this actually does, so I'm ignoring it
# FIXME  for now.
sub if_loggedin {
	my ($self, $arg) = @_;
	
	return !$arg;
}

# FIXME  This needs to be updated for LoginProctor
sub info {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
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
				print CGI::h2("Login Info");
				print $text;
			}
		}
		
		return "";
	}
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
  # convenient data variables
	my $effectiveUser = $r->param("effectiveUser") || "";
	my $user = $r->param("user");
	my $proctorUser = $r->param("proctor_user") || "";
	my $key = $r->param("proctor_key");
	my $passwd = $r->param("proctor_passwd") || "";
	my $course = $urlpath->arg("courseID");
	my $setID = $urlpath->arg("setID");
	my $timeNow = time();

  # data collection
	my $submitAnswers = $r->param("submitAnswers");
	my $EffectiveUser = $db->getUser($effectiveUser);
	my $User = $db->getUser($user);

	my $effectiveUserFullName = $EffectiveUser->first_name() . " " . 
	    $EffectiveUser->last_name();

  # save the userset for use below
	my $UserSet;  
  # version_last_attempt_time conditional: if we're submitting the set
  # for the last time we need to save the submission time.
	if ( $submitAnswers ) {

    # getMergedVersionedSet returns either the set requested (if the setID
    #   is versioned, "setName,vN") or the latest set (if not).  This should
    #   be by default the set we want.  
	    $UserSet = $db->getMergedVersionedSet($effectiveUser, $setID);
    # this should never error out, but we'll check anyway
	    die("Proctor login generated for grade attempt on a nonexistent " .
		"set?!\n") if ( ! defined($UserSet) );

    # we need these to get a problem from the set
	    my $setVersionName = ( $setID =~ /,v(\d+)$/ ) ? $setID : 
		$UserSet->set_id();
	    $setID =~ s/,v\d+$//;

    # we only save the submission time if the attempt will be recorded,
    #   so we have to do some research to determine if that's the case
	    my $PermissionLevel = $db->getPermissionLevel($user);
	    my $Problem = 
		$db->getMergedVersionedProblem($effectiveUser, $setID, 
					       $setVersionName, 1);
    # set last_attempt_time if appropriate
	    if ( WeBWorK::ContentGenerator::GatewayQuiz::can_recordAnswers($self,$User, $PermissionLevel, 
			$EffectiveUser, $UserSet, $Problem) ) {
		$UserSet->version_last_attempt_time( $timeNow );
		$db->putVersionedUserSet( $UserSet );
	    }
	}

	
	print CGI::p(CGI::strong("Proctor authorization required."), "\n\n");
    # WeBWorK::Authen::verifyProctor will set the note "authen_error" 
    # if invalid authentication is found.  If this is done, it's a signal to
    # us to yell at the user for doing that, since Authen isn't a content-
    # generating module.
	if ($r->notes("authen_error")) {
		print CGI::div({class=>"ResultsWithError"},
			CGI::p($r->notes("authen_error"))
		);
	}
	
    # also print a message about submission times if we're submitting 
    # an answer
	if ( $submitAnswers ) {
	    my $dueTime = $UserSet->due_date();
	    my $timeLimit = $UserSet->version_time_limit();
	    my ($color, $msg) = ("#ddddff", "");

	    if ( $dueTime < $timeNow ) {
		$color = "#ffffaa";
		$msg = CGI::br() . "\nThe time limit on this assignment " .
		    "was exceeded.\nThe assignment may be checked, but " .
		    "the result will not be counted.\n";
	    }
	    my $style = "background-color: $color; color: black; " .
		"border: solid black 1px; padding: 2px;";
	    print CGI::div({-style=>$style}, 
			   CGI::strong("Grading assignment: ", CGI::br(), 
				       "Submission time: ", 
				       scalar(localtime($timeNow)), CGI::br(),
				       "Due: ",
				       scalar(localtime($dueTime)), $msg));
	}

	print CGI::div({style=>"background-color:#ddddff;"},
		       CGI::p("User's uniqname is: ", 
			      CGI::strong("$effectiveUser"),"\n",
			      CGI::br(),"User's name is: ", 
			      CGI::strong("$effectiveUserFullName"),"\n")),"\n";

	print CGI::startform({-method=>"POST", -action=>$r->uri});

	# write out the form data posted to the requested URI
#	print $self->print_form_data('<input type="hidden" name="','" value="',"\"/>\n",qr/^(user|passwd|key|force_passwd_authen|procter_user|proctor_key|proctor_password)$/);
	my @fields_to_print = 
	    grep { ! /^(user)|(effectiveUser)|(passwd)|(key)|(force_password_authen)|(proctor_user)|(proctor_key)|(proctor_passwd)$/ } $r->param();

	print $self->hidden_fields(@fields_to_print) if ( @fields_to_print );
	print $self->hidden_authen_fields,"\n";
	
	print CGI::table({class=>"FormLayout"}, 
	  CGI::Tr([
		CGI::td([
		  "Proctor username:",
		  CGI::input({-type=>"text", -name=>"proctor_user", -value=>""}),
		]),
		CGI::td([
		  "Proctor password:",
		  CGI::input({-type=>"password", -name=>"proctor_passwd", -value=>""}),
		]),
	 ])
	);
	
	print CGI::input({-type=>"submit", -value=>"Continue"});
	print CGI::endform();
	
	return "";
}

1;
