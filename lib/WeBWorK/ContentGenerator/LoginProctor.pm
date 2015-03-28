################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/LoginProctor.pm,v 1.10 2007/04/04 15:05:26 glarose Exp $
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
use CGI qw(-nosticky );
use WeBWorK::Utils qw(readFile dequote);
use WeBWorK::DB::Utils qw(grok_vsetID);
use WeBWorK::ContentGenerator::GatewayQuiz qw(can_recordAnswers);

use mod_perl;
use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

# This content generator is NOT logged in.
# FIXME  I'm not sure this is really what we want for the proctor login,
# FIXME  but I also don't know what this actually does, so I'm ignoring it
# FIXME  for now.
sub if_loggedin {
	my ($self, $arg) = @_;
	
	return !$arg;
}

sub info {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
	my $result;
	
	# This section should be kept in sync with the Home.pm version
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
				$result .= CGI::h2("Site Information");
				$result .= CGI::div({class=>"ResultsWithError"}, $@);
			} elsif ($text =~ /\S/) {
				$result .= CGI::h2("Site Information");
				$result .= $text;
			}
		}
	}
	
	# FIXME this is basically the same code as above... TIME TO REFACTOR!
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
				$result .= CGI::h2("Login Info");
				$result .= CGI::div({class=>"ResultsWithError"}, $@);
			} elsif ($text =~ /\S/) {
				$result .= CGI::h2("Login Info");
				$result .= $text;
			}
		}
	}
	
	if (defined $result and $result ne "") {
#		return CGI::div({class=>"info-box", id=>"InfoPanel"}, $result);
                return $result;
	} else {
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

  # these are to manage the transition to, and possibly back from,
  #    the grading proctor
	my $pastProctorUser = $r->param("past_proctor_user") || $proctorUser;
	my $pastProctorKey = $r->param("past_proctor_key") || $key;

  # data collection
	my $submitAnswers = $r->param("submitAnswers");
	my $EffectiveUser = $db->getUser($effectiveUser);
	my $User = $db->getUser($user);

	my $effectiveUserFullName = $EffectiveUser->first_name() . " " . 
	    $EffectiveUser->last_name();

	# we need the UserSet to check for a set-restricted login proctor,
	#    and to show and possibly save the submission time.
	#    and to get the UserSet, we need to know what set and version
	#    we're working with.  if the setName and versionName come in 
	#    with the setID, we're ok; otherwise, get the highest version
	#    number available and go with that
	my ($setName, $versionNum) = grok_vsetID($setID);
	my $noSetVersions = 0;
	if ( ! $versionNum ) {
		# get a list of all available versions
		my @setVersions = $db->listSetVersions($effectiveUser,
						       $setName);
		if ( @setVersions ) {
			$versionNum = $setVersions[-1];
		} else {
			# if there are no versions yet, we must be starting
			#    the first one
			$versionNum = 1;
			$noSetVersions = 1;
		}
	}
	# get the merged set; if we're not grading a test, 
	#    get the merged template set instead
	my $UserSet;
	if ( $noSetVersions || ! $submitAnswers ) {
		$UserSet = $db->getMergedSet($effectiveUser, $setName);
	} else {
		$UserSet = $db->getMergedSetVersion($effectiveUser, $setName,
						    $versionNum);
	}

	# let's just make sure that worked
	die("Proctor authorization requested for a nonexistent " .
	    "set?\n") if ( ! defined( $UserSet ) );
  
	# now, if we're submitting the set we need to save the 
	#    submission time.
	if ( $submitAnswers ) {
		# this shouldn't ever happen
		if ( $noSetVersions ) {
			die("Request to grade a set version before " .
			    "any tests have been taken.");
		}
		# we save the submission time if the attempt will be recorded,
		#   so we have to do some research to determine if that's 
		#   the case
		my $PermissionLevel = $db->getPermissionLevel($user);
		my $Problem = 
		    $db->getMergedProblemVersion($effectiveUser, $setName,
						 $versionNum, 1);
		# set last_attempt_time if appropriate
		if ( WeBWorK::ContentGenerator::GatewayQuiz::can_recordAnswers($self, $User, $PermissionLevel, 
			$EffectiveUser, $UserSet, $Problem) ) {
			$UserSet->version_last_attempt_time( $timeNow );
			# FIXME: this saves all of the merged set data into 
			#    the set_user table.  we live with this in other
			#    places for versioned sets, but it's not ideal
			$db->putSetVersion( $UserSet );
		}
	}

	
	print CGI::p(CGI::strong("Proctor authorization required."), "\n\n");
    # WeBWorK::Authen::verifyProctor will set the note "authen_error" 
    # if invalid authentication is found.  If this is done, it's a signal to
    # us to yell at the user for doing that, since Authen isn't a content-
    # generating module.
	my $authen_error = MP2 ? $r->notes->get("authen_error") : $r->notes("authen_error");
	if ($authen_error) {
		print CGI::div({class=>"ResultsWithError"},
			CGI::p($authen_error)
		);
	}
	
    # also print a message about submission times if we're submitting 
    # an answer
	if ( $submitAnswers ) {
	    my $dueTime = $UserSet->due_date();
	    my $timeLimit = $UserSet->version_time_limit();
	    my ($color, $msg) = ("#ddddff", "");

	    if ( $dueTime + $ce->{gatewayGracePeriod} < $timeNow ) {
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

	# start printing the form
	print CGI::start_form({-method=>"POST", -action=>$r->uri});
	# write out the form data posted to the requested URI
	my @fields_to_print = 
	    grep { ! /^(user)|(effectiveUser)|(passwd)|(key)|(force_password_authen)|(proctor_user)|(proctor_key)|(proctor_password)$/ } $r->param();

	print $self->hidden_fields(@fields_to_print) if ( @fields_to_print );
	print $self->hidden_authen_fields,"\n";

	print CGI::hidden(-name=>"past_proctor_user",
			  -value=>$pastProctorUser);
	print CGI::hidden(-name=>"past_proctor_key",
			  -value=>$pastProctorKey);

	# skip printing the user's name and all if we're doing a restricted
	#    set login
	my $userNameFields = '';
	if ( $submitAnswers || 
	     ( $UserSet->restricted_login_proctor eq '' ||
	       $UserSet->restricted_login_proctor eq 'No' ) ) {
		print CGI::div({style=>"background-color:#ddddff;"},
			       CGI::p("User's username is: ", 
				      CGI::strong("$effectiveUser"),"\n",
				      CGI::br(),"User's name is: ", 
				      CGI::strong("$effectiveUserFullName"),
				      "\n")),"\n";
		$userNameFields = CGI::td([
		  CGI::label(
					"Proctor username:",
					CGI::input({-type=>"text", 
						    -name=>"proctor_user", 
						    -value=>""})),
					]);
	} else {
		print CGI::start_div({style=>"background-color:#ddddff;"});
		print CGI::em("This set has a set-level proctor ",
			      "password to authorize logins. ",
			      "Enter the password below.");
		print CGI::end_div();
		print CGI::hidden(-name=>'proctor_user',
				  -value=>"set_id:$setName");
	}

	# then print out the table for the username, if needed, and 
	#    password for the proctor
	print CGI::start_table({class=>"FormLayout"});
	print CGI::Tr( $userNameFields ) if ( $userNameFields );
	print CGI::Tr( CGI::td([
			 CGI::label(
				"Proctor password:",
				CGI::input({-type=>"password", 
					    -name=>"proctor_passwd", 
					    -value=>""})),
				])
		       );
	print CGI::end_table();
	
	print CGI::input({-type=>"submit", -value=>"Continue"});
	print CGI::end_form();
	
	return "";
}

1;
