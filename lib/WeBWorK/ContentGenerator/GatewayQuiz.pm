################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/GatewayQuiz.pm,v 1.39 2007/03/13 15:44:21 glarose Exp $
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

package WeBWorK::ContentGenerator::GatewayQuiz;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::GatewayQuiz - display a quiz of problems on one page,
deal with versioning sets

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use File::Path qw(rmtree);
use WeBWorK::Form;
use WeBWorK::PG;
use WeBWorK::PG::ImageGenerator;
use WeBWorK::PG::IO;
use WeBWorK::Utils qw(writeLog writeCourseLog encodeAnswers decodeAnswers
	ref2string makeTempDirectory before after between);
use WeBWorK::DB::Utils qw(global2user user2global);
use WeBWorK::Debug;
use WeBWorK::ContentGenerator::Instructor qw(assignSetVersionToUser);
use PGrandom;

# template method
sub templateName {
    return "gateway";
}


################################################################################
# "can" methods
################################################################################

# Subroutines to determine if a user "can" perform an action. Each subroutine is
# called with the following arguments:
# 
#     ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem)

# *** The "can" routines are taken from Problem.pm, with small modifications
# *** to look at number of attempts per version, not per set, and to allow
# *** showing of correct answers after all attempts at a version are used

sub can_showOldAnswers {
	my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem, $tmplSet ) = @_;
	my $authz = $self->r->authz;
# we'd like to use "! $Set->hide_work()", but that hides students' work 
# as they're working on the set, which isn't quite right.  so use instead:
	return( before( $Set->due_date() ) || 
		
		$authz->hasPermissions($User->user_id,"view_hidden_work") ||
		( $Set->hide_work() eq 'N' || 
		  ( $Set->hide_work() eq 'BeforeAnswerDate' && time > $tmplSet->answer_date ) ) );
}

# gateway change here: add $submitAnswers as an optional additional argument
#   to be included if it's defined
sub can_showCorrectAnswers {
	my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem, 
	    $tmplSet, $submitAnswers) = @_;
	my $authz = $self->r->authz;
	
# gateway change here to allow correct answers to be viewed after all attempts
#   at a version are exhausted as well as if it's after the answer date
# $addOne allows us to count the current submission
	my $addOne = defined( $submitAnswers ) ? $submitAnswers : 0;
	my $maxAttempts = $Set->attempts_per_version();
	my $attemptsUsed = $Problem->num_correct + $Problem->num_incorrect + 
	    $addOne;

	return ( ( ( after( $Set->answer_date ) || 
		     ( $attemptsUsed >= $maxAttempts && 
		       $Set->due_date() == $Set->answer_date() ) ) ||
		   $authz->hasPermissions($User->user_id, 
				"show_correct_answers_before_answer_date") ) &&
		 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
		   ( $Set->hide_score eq 'N' || 
		     ( $Set->hide_score eq 'BeforeAnswerDate' && 
		       time > $tmplSet->answer_date ) ) ) );
}

sub can_showHints {
	#my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem) = @_;
	
	return 1;
}

# gateway change here: add $submitAnswers as an optional additional argument
#   to be included if it's defined
sub can_showSolutions {
	my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem, 
	    $tmplSet, $submitAnswers) = @_;
	my $authz = $self->r->authz;

# this is the same as can_showCorrectAnswers	
# gateway change here to allow correct answers to be viewed after all attempts
#   at a version are exhausted as well as if it's after the answer date
# $addOne allows us to count the current submission
	my $addOne = defined( $submitAnswers ) ? $submitAnswers : 0;
	my $maxAttempts = $Set->attempts_per_version();
	my $attemptsUsed = $Problem->num_correct+$Problem->num_incorrect+$addOne;

	return ( ( ( after( $Set->answer_date ) || 
		     ( $attemptsUsed >= $maxAttempts && 
		       $Set->due_date() == $Set->answer_date() ) ) ||
		   $authz->hasPermissions($User->user_id, 
				"show_correct_answers_before_answer_date") ) &&
		 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
		   ( $Set->hide_score eq 'N' || 
		     ( $Set->hide_score eq 'BeforeAnswerDate' && 
		       time > $tmplSet->answer_date ) ) ) );
}

# gateway change here: add $submitAnswers as an optional additional argument
#   to be included if it's defined
# we also allow for a version_last_attempt_time which is the time the set was
#   submitted; if that's present we use that instead of the current time to 
#   decide if we can record the answers.  this deals with the time between the 
#   submission time and the proctor authorization.
sub can_recordAnswers {
	my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem, 
	    $tmplSet, $submitAnswers) = @_;
	my $authz = $self->r->authz;

	my $timeNow = ( defined($self->{timeNow}) ) ? $self->{timeNow} : time();
   # get the sag time after the due date in which we'll still grade the test
	my $grace = $self->{ce}->{gatewayGracePeriod};

	my $submitTime = ( defined($Set->version_last_attempt_time()) &&
			   $Set->version_last_attempt_time() ) ? 
			   $Set->version_last_attempt_time() : $timeNow;

	if ($User->user_id ne $EffectiveUser->user_id) {
		return $authz->hasPermissions($User->user_id, "record_answers_when_acting_as_student");
	}

	if (before($Set->open_date, $submitTime)) {
		    warn("case 0\n");
		return $authz->hasPermissions($User->user_id, "record_answers_before_open_date");
	} elsif (between($Set->open_date, ($Set->due_date + $grace), $submitTime)) {

# gateway change here; we look at maximum attempts per version, not for the set,
#   to determine the number of attempts allowed
# $addOne allows us to count the current submission
	    my $addOne = ( defined( $submitAnswers ) && $submitAnswers ) ? 
		1 : 0;
	    my $max_attempts = $Set->attempts_per_version();
	    my $attempts_used = $Problem->num_correct+$Problem->num_incorrect+$addOne;
		if ($max_attempts == -1 or $attempts_used < $max_attempts) {
			return $authz->hasPermissions($User->user_id, "record_answers_after_open_date_with_attempts");
		} else {
			return $authz->hasPermissions($User->user_id, "record_answers_after_open_date_without_attempts");
		}
	} elsif (between(($Set->due_date + $grace), $Set->answer_date, $submitTime)) {
		return $authz->hasPermissions($User->user_id, "record_answers_after_due_date");
	} elsif (after($Set->answer_date, $submitTime)) {
		return $authz->hasPermissions($User->user_id, "record_answers_after_answer_date");
	}
}

# gateway change here: add $submitAnswers as an optional additional argument
#   to be included if it's defined
# we also allow for a version_last_attempt_time which is the time the set was
#   submitted; if that's present we use that instead of the current time to 
#   decide if we can check the answers.  this deals with the time between the 
#   submission time and the proctor authorization.
sub can_checkAnswers {
	my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem,
	    $tmplSet, $submitAnswers) = @_;
	my $authz = $self->r->authz;

	my $timeNow = ( defined($self->{timeNow}) ) ? $self->{timeNow} : time();
   # get the sag time after the due date in which we'll still grade the test
	my $grace = $self->{ce}->{gatewayGracePeriod};
	
	my $submitTime = ( defined($Set->version_last_attempt_time()) &&
			   $Set->version_last_attempt_time() ) ? 
			   $Set->version_last_attempt_time() : $timeNow;

	if (before($Set->open_date, $submitTime)) {
		return $authz->hasPermissions($User->user_id, "check_answers_before_open_date");
	} elsif (between($Set->open_date, ($Set->due_date + $grace), $submitTime)) {

# gateway change here; we look at maximum attempts per version, not for the set,
#   to determine the number of attempts allowed
# $addOne allows us to count the current submission
	    my $addOne = (defined( $submitAnswers ) && $submitAnswers) ? 
		1 : 0;
	    my $max_attempts = $Set->attempts_per_version();
	    my $attempts_used = $Problem->num_correct+$Problem->num_incorrect+$addOne;

		if ($max_attempts == -1 or $attempts_used < $max_attempts) {
			return ( $authz->hasPermissions($User->user_id, "check_answers_after_open_date_with_attempts") &&
				 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
				   $Set->hide_score eq 'N' ||
				   ( $Set->hide_score eq 'BeforeAnswerDate' &&
				     $timeNow > $tmplSet->answer_date ) ) );
		} else {
			return ( $authz->hasPermissions($User->user_id, "check_answers_after_open_date_without_attempts") && 
				 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
				   $Set->hide_score eq 'N' ||
				   ( $Set->hide_score eq 'BeforeAnswerDate' &&
				     $timeNow > $tmplSet->answer_date ) ) );
		}
	} elsif (between(($Set->due_date + $grace), $Set->answer_date, $submitTime)) {
		return ( $authz->hasPermissions($User->user_id, "check_answers_after_due_date")  &&
			 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
			   $Set->hide_score eq 'N' ||
			   ( $Set->hide_score eq 'BeforeAnswerDate' &&
			     $timeNow > $tmplSet->answer_date ) ) );
	} elsif (after($Set->answer_date, $submitTime)) {
		return ( $authz->hasPermissions($User->user_id, "check_answers_after_answer_date") &&
			 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
			   $Set->hide_score eq 'N' || 
			   ( $Set->hide_score eq 'BeforeAnswerDate' &&
			     $timeNow > $tmplSet->answer_date ) ) );
	}
}

sub can_showScore {
	my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem,
	    $tmplSet, $submitAnswers) = @_;
	my $authz = $self->r->authz;

	my $timeNow = ( defined($self->{timeNow}) ) ? $self->{timeNow} : time();

	return( $authz->hasPermissions($User->user_id,"view_hidden_work") ||
		$Set->hide_score eq 'N' ||
		( $Set->hide_score eq 'BeforeAnswerDate' && 
		  $timeNow > $tmplSet->answer_date ) );
}

################################################################################
# output utilities
################################################################################

# subroutine is modified from that in Problem.pm to produce a different 
#    table format
sub attemptResults {
	my $self = shift;
	my $pg = shift;
	my $showAttemptAnswers = shift;
	my $showCorrectAnswers = shift;
	my $showAttemptResults = $showAttemptAnswers && shift;
	my $showSummary = shift;
	my $showAttemptPreview = shift || 0;
	
	my $r = $self->{r};
	my $setName = $r->urlpath->arg("setID");
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my @links = ("Homework Sets" , "$root/$courseName", "navUp");
	my $tail = "";
	
	my $problemResult = $pg->{result}; # the overall result of the problem
	my @answerNames = @{ $pg->{flags}->{ANSWER_ENTRY_ORDER} };
	
	my $showMessages = $showAttemptAnswers && grep { $pg->{answers}->{$_}->{ans_message} } @answerNames;

  # present in ver 1.10; why is this checked here?
	#	return CGI::p(CGI::font({-color=>"red"}, "This problem is not available because the homework set that contains it is not yet open."))
	#	unless $self->{isOpen};

	my $basename = "equation-" . $self->{set}->psvn. "." . $self->{problem}->problem_id . "-preview";

	# to make grabbing these options easier, we'll pull them out now...
	my %imagesModeOptions = %{$ce->{pg}->{displayModeOptions}->{images}};
	
	my $imgGen = WeBWorK::PG::ImageGenerator->new(
		tempDir         => $ce->{webworkDirs}->{tmp},
		latex	        => $ce->{externalPrograms}->{latex},
		dvipng          => $ce->{externalPrograms}->{dvipng},
		useCache        => 1,
		cacheDir        => $ce->{webworkDirs}->{equationCache},
		cacheURL        => $ce->{webworkURLs}->{equationCache},
		cacheDB         => $ce->{webworkFiles}->{equationCacheDB},
		dvipng_align    => $imagesModeOptions{dvipng_align},
		dvipng_depth_db => $imagesModeOptions{dvipng_depth_db},
	);

	my %resultsData = ();
	$resultsData{'Entered'}  = CGI::td({-class=>"label"}, "Your answer parses as:");
	$resultsData{'Preview'}  = CGI::td({-class=>"label"}, "Your answer previews as:");
	$resultsData{'Correct'}  = CGI::td({-class=>"label"}, "The correct answer is:");
	$resultsData{'Results'}  = CGI::td({-class=>"label"}, "Result:");
	$resultsData{'Messages'} = CGI::td({-class=>"label"}, "Messages:");

	my %resultsRows = ();
	foreach ( qw( Entered Preview Correct Results Messages ) ) {
	    $resultsRows{$_} = "";
	}

	my $numCorrect = 0;
	my $numAns = 0;
	foreach my $name (@answerNames) {
		my $answerResult  = $pg->{answers}->{$name};
		my $studentAnswer = $answerResult->{student_ans}; # original_student_ans
		my $preview       = ($showAttemptPreview
		                    	? $self->previewAnswer($answerResult, $imgGen)
		                    	: "");
		my $correctAnswer = $answerResult->{correct_ans};
		my $answerScore   = $answerResult->{score};
		my $answerMessage = $showMessages ? $answerResult->{ans_message} : "";
		#FIXME  --Can we be sure that $answerScore is an integer-- could the problem give partial credit?
		$numCorrect += $answerScore > 0;
		my $resultString = $answerScore == 1 ? "correct" : "incorrect";
		
		# get rid of the goofy prefix on the answer names (supposedly, the format
		# of the answer names is changeable. this only fixes it for "AnSwEr"
		#$name =~ s/^AnSwEr//;
		
		my $pre = $numAns ? CGI::td("&nbsp;") : "";

		$resultsRows{'Entered'} .= $showAttemptAnswers ? 
		    CGI::Tr( $pre . $resultsData{'Entered'} . 
			     CGI::td({-class=>"output"}, $self->nbsp($studentAnswer))) : "";
		$resultsData{'Entered'} = '';
		$resultsRows{'Preview'} .= $showAttemptPreview ? 
		    CGI::Tr( $pre . $resultsData{'Preview'} . 
			     CGI::td({-class=>"output"}, $self->nbsp($preview)) ) : "";
		$resultsData{'Preview'} = '';
		$resultsRows{'Correct'} .= $showCorrectAnswers ? 
		    CGI::Tr( $pre . $resultsData{'Correct'} . 
			     CGI::td({-class=>"output"}, $self->nbsp($correctAnswer)) ) : "";
		$resultsData{'Correct'} = '';
		$resultsRows{'Results'} .= $showAttemptResults ? 
		    CGI::Tr( $pre . $resultsData{'Results'} . 
			     CGI::td({-class=>"output"}, $self->nbsp($resultString)) )  : "";
		$resultsData{'Results'} = '';
		$resultsRows{'Messages'} .= $showMessages ? 
		    CGI::Tr( $pre . $resultsData{'Messages'} . 
			     CGI::td({-class=>"output"}, $self->nbsp($answerMessage)) ) : "";

		$numAns++;
	}
	
	# render equation images
	$imgGen->render(refresh => 1);
	
#	my $numIncorrectNoun = scalar @answerNames == 1 ? "question" : "questions";
	my $scorePercent = sprintf("%.0f%%", $problemResult->{score} * 100);
#   FIXME  -- I left the old code in in case we have to back out.
#	my $summary = "On this attempt, you answered $numCorrect out of "
#		. scalar @answerNames . " $numIncorrectNoun correct, for a score of $scorePercent.";

	my $summary = ""; 
	if (scalar @answerNames == 1) {
			if ($numCorrect == scalar @answerNames) {
				$summary .= CGI::div({class=>"gwCorrect"},"This answer is correct.");
			 } else {
			 	 $summary .= CGI::div({class=>"gwIncorrect"},"This answer is NOT correct.");
			 }
	} else {
			if ($numCorrect == scalar @answerNames) {
				$summary .= CGI::div({class=>"gwCorrect"},"All of these answers are correct.");
			 } else {
			 	 $summary .= CGI::div({class=>"gwIncorrect"},"At least one of these answers is NOT correct.");
			 }
	}
	
	return
#	    CGI::table({-class=>"attemptResults"}, $resultsRows{'Entered'}, 
	    CGI::table({-class=>"gwAttemptResults"}, $resultsRows{'Entered'}, 
		       $resultsRows{'Preview'}, $resultsRows{'Correct'}, 
		       $resultsRows{'Results'}, $resultsRows{'Messages'}) .
	    ($showSummary ? CGI::p({class=>'attemptResultsSummary'},$summary) : "");
#		CGI::table({-class=>"attemptResults"}, CGI::Tr(\@tableRows))
#		. ($showSummary ? CGI::p({class=>'emphasis'},$summary) : "");
}

# *BeginPPM* ###################################################################
# this code taken from Problem.pm; excerpted section ends at *EndPPM*
# modifications are flagged with comments *GW*

sub previewAnswer {
	my ($self, $answerResult, $imgGen) = @_;
	my $ce            = $self->r->ce;
	my $EffectiveUser = $self->{effectiveUser};
	my $set           = $self->{set};
	my $problem       = $self->{problem};
	my $displayMode   = $self->{displayMode};
	
	# note: right now, we have to do things completely differently when we are
	# rendering math from INSIDE the translator and from OUTSIDE the translator.
	# so we'll just deal with each case explicitly here. there's some code
	# duplication that can be dealt with later by abstracting out tth/dvipng/etc.
	
	my $tex = $answerResult->{preview_latex_string};
	
	return "" unless defined $tex and $tex ne "";
	
	if ($displayMode eq "plainText") {
		return $tex;
	} elsif ($displayMode eq "formattedText") {
		my $tthCommand = $ce->{externalPrograms}->{tth}
			. " -L -f5 -r 2> /dev/null <<END_OF_INPUT; echo > /dev/null\n"
			. "\\(".$tex."\\)\n"
			. "END_OF_INPUT\n";
		
		# call tth
		my $result = `$tthCommand`;
		if ($?) {
			return "<b>[tth failed: $? $@]</b>";
		} else {
			return $result;
		}
	} elsif ($displayMode eq "images") {
		$imgGen->add($tex);
	} elsif ($displayMode eq "jsMath") {
		$tex =~ s/</&lt;/g; $tex =~ s/>/&gt;/g;
		return '<SPAN CLASS="math">\\displaystyle{'.$tex.'}</SPAN>';
	}
}

# *EndPPM ######################################################################

################################################################################
# Template escape implementations
################################################################################

# FIXME need to make $Set and $set be used consistently

sub pre_header_initialize {
    my ($self)     = @_;
    
    my $r = $self->r;
    my $ce = $r->ce;
    my $db = $r->db;
    my $authz = $r->authz;
    my $urlpath = $r->urlpath;

    my $setName = $urlpath->arg("setID");
    my $userName = $r->param('user');
    my $effectiveUserName = $r->param('effectiveUser');
    my $key = $r->param('key');

# this is a hack manage previewing a page.  we set previewAnswers to 
# yes if any of the following are true:
#  1. the "previewAnswers" input is set (the "preview" button was clicked),
#  2. the "previewHack" input is set (a preview link was used), or 
#  3. the "previewingAnswersNow" and "newPage" inputs are set (the page
#     is currently being previewed, and we're switching pages)
    my $prevOr = $r->param('previewAnswers') || $r->param('previewHack') ||
	($r->param('previewingAnswersNow') && $r->param('newPage'));
    $r->param('previewAnswers', $prevOr) if ( defined( $prevOr ) );

# we similarly hack checkAnswers, below

    my $User = $db->getUser($userName);
    die "record for user $userName (real user) does not exist." 
	unless defined $User;
    my $EffectiveUser = $db->getUser($effectiveUserName);
    die "record for user $effectiveUserName (effective user) does not exist." 
	unless defined $EffectiveUser;

    my $PermissionLevel = $db->getPermissionLevel($userName);
    die "permission level record for $userName does not exist (but the " .
	"user does? odd...)" unless defined($PermissionLevel);
    my $permissionLevel = $PermissionLevel->permission;

# we could be coming in with $setName = the versioned or nonversioned set
# deal with that first
    my $requestedVersion = ( $setName =~ /,v(\d+)$/ ) ? $1 : 0;
    $setName =~ s/,v\d+$//;
# note that if we're already working with a version we want to be sure to stick
# with that version.  we do this after we've validated that the user is 
# assigned the set, below

###################################
# gateway content generator tests
###################################

# get template set: the non-versioned set that's assigned to the user
    my $tmplSet = $db->getMergedSet( $effectiveUserName, $setName );
    die( "Set $setName hasn't been assigned to effective user " .
	 $effectiveUserName ) unless( defined( $tmplSet ) );

# FIXME should we be more subtle than just die()ing here?  c.f. Problem.pm, 
#    which sets $self->{invalidSet} and lets body() deal with it.  for 
#    gateways I think we need to die() or skip the version creation 
#    conditional, or else we could get user versions of an unpublished
#    set. FIXME
    die( "Invalid set $setName requested" ) 
	if ( ! ( $tmplSet->published || 
		 $authz->hasPermissions($userName,"view_unpublished_sets") ) );

# if this set isn't a gateway test, we're in the wrong content generator
    die("Set $setName isn't a gateway test.  Error in ContentGenerator " .
	"call.") if ( ! defined( $tmplSet->assignment_type() ) ||
		      $tmplSet->assignment_type() !~ /gateway/i );

# now we know that we're in a gateway test, save the assignment test for
#    the processing of proctor keys for graded proctored tests
    $self->{'assignment_type'} = $tmplSet->assignment_type();


# next, get the latest (current) version of the set if we don't have a 
# requested version number
    my @allVersionIds = $db->listSetVersions($effectiveUserName, $setName);
    my $latestVersion = ( @allVersionIds ? $allVersionIds[-1] : 0 );

# double check that any requested version makes sense
    $requestedVersion = $latestVersion if ($requestedVersion !~ /^\d+$/ ||
					   $requestedVersion > $latestVersion ||
					   $requestedVersion < 0);

    die("No requested version when returning to problem?!") 
	if ( ( $r->param("previewAnswers") || $r->param("checkAnswers") ||
	       $r->param("submitAnswers") || $r->param("newPage") ) 
	     && ! $requestedVersion );

# to test for a proctored test, we need the set version, not the template,
#    to allows a finished proctored test to be checked as an 
#    unproctored test.  so we get the versioned set here
    my $set;
    if ( $requestedVersion ) { 
# if a specific set version was requested, get that set
	$set = $db->getMergedSetVersion($effectiveUserName, $setName, 
					$requestedVersion);
    } elsif ( $latestVersion ) {
# otherwise, if there's a current version, which we take to be the 
# latest version taken, we use that
	$set = $db->getMergedSetVersion($effectiveUserName, $setName,
					$latestVersion);
    } else {
# and if neither of those work, get a dummy set so that we have something
# to work with
	my $userSetClass = $ce->{dbLayout}->{set_version}->{record};
# FIXME RETURN TO: should this be global2version?
	$set = global2user($userSetClass, $db->getGlobalSet($setName));
	die "set  $setName  not found."  unless $set;
	$set->user_id($effectiveUserName);
	$set->psvn('000');
	$set->set_id("$setName");  # redundant?
	$set->version_id(0);
    }
    my $setVersionNumber = $set->version_id();

# proctor check to be sure that no one is trying to abuse the url path to sneak 
#    in the back door on a proctored test
# in the dispatcher we make sure that every call with a proctored url has a 
#    valid proctor authentication.  so if we're here either we were called with
#    an unproctored url, or we have a valid proctor authentication.
# this check is to be sure we have a valid proctor authentication for any test 
#    that has a proctored assignment type, preventing someone from trying to 
#    go to a proctored test with a hacked unproctored URL
    if ( ( $requestedVersion && $set->assignment_type() =~ /proctored/i ) ||
	 ( ! $requestedVersion && $tmplSet->assignment_type() =~ /proctored/i ) 
	 ) {
# check against the requested set, if that is the one we're using, or against
#    the template if no version was specified.
	die("Set $setName requires a valid proctor login.") 
	    if ( ! WeBWorK::Authen::Proctor->new($r, $ce, $db)->verify() );
    }

#################################
# assemble gateway parameters
#################################

# we get the open/close dates for the gateway from the template set.
# note $isOpen/Closed give the open/close dates for the gateway as a whole
# (that is, the merged user|global set)
    my $isOpen = after($tmplSet->open_date()) || 
	$authz->hasPermissions($userName, "view_unopened_sets");

# FIXME for $isClosed, "record_answers_after_due_date" isn't quite the 
#    right description, but it's probably reasonable for our purposes FIXME
    my $isClosed = after($tmplSet->due_date()) &&
	! $authz->hasPermissions($userName, "record_answers_after_due_date");

# to determine if we need a new version, we need to know whether this 
#    version exceeds the number of attempts per version.  (among other
#    things,) the number of attempts is a property of the problem, so 
#    get a problem to check that.  note that for a gateway/quiz all 
#    problems will have the same number of attempts.  This means that if 
#    the set doesn't have any problems we're up a creek, so check for that
#    here and bail if it's the case
    my @setPNum = $db->listUserProblems($EffectiveUser->user_id, $setName);
    die("Set $setName contains no problems.") if ( ! @setPNum );

# the Problem here can be undefined, if the set hasn't been versioned 
#    to the user yet--this gets fixed when we assign the setVersion
    my $Problem = $setVersionNumber ? 
	$db->getMergedProblemVersion($EffectiveUser->user_id, $setName, 
				     $setVersionNumber, $setPNum[0]) :
				     undef;

# note that having $maxAttemptsPerVersion set to an infinite/0 value is
#    nonsensical; if we did that, why have versions?
    my $maxAttemptsPerVersion = $tmplSet->attempts_per_version();
    my $timeInterval          = $tmplSet->time_interval();
    my $versionsPerInterval   = $tmplSet->versions_per_interval();
    my $timeLimit             = $tmplSet->version_time_limit();

# what happens if someone didn't set one of these?  I think this can 
# happen if we're handed a malformed set, where the values in the database
# are null.
    $timeInterval = 0 if ( ! defined($timeInterval) || $timeInterval eq '' );
    $versionsPerInterval = 0 if ( ! defined($versionsPerInterval) ||
				  $versionsPerInterval eq '' );

# every problem in the set must have the same submission characteristics
    my $currentNumAttempts    = ( defined($Problem) ? $Problem->num_correct() +
				  $Problem->num_incorrect() : 0 );

# $maxAttempts turns into the maximum number of versions we can create; 
#    if $Problem isn't defined, we can't have made any attempts, so it 
#    doesn't matter
    my $maxAttempts           = ( defined($Problem) && 
				  defined($Problem->max_attempts()) ? 
				  $Problem->max_attempts() : -1 );

# finding the number of versions per time interval is a little harder.  we
#    interpret the time interval as a rolling interval: that is, if we allow
#    two sets per day, that's two sets in any 24 hour period.  this is 
#    probably not what we really want, but it's more extensible to a
#    limitation like "one version per hour", and we can set it to two sets
#    per 12 hours for most "2ce daily" type applications
    my $timeNow = time();
    my $grace = $ce->{gatewayGracePeriod};

    my $currentNumVersions = 0;  # this is the number of versions in the last
                                 #    time interval
    my $totalNumVersions = 0;

    if ( $setVersionNumber ) {
	my @setVersionIDs = $db->listSetVersions($effectiveUserName, $setName);
	my @setVersions = $db->getSetVersions(map {[$effectiveUserName, $setName,, $_]} @setVersionIDs);
	foreach ( @setVersions ) {
	    $totalNumVersions++;
	    $currentNumVersions++
		if ( ! $timeInterval ||
		     $_->version_creation_time() > ($timeNow - $timeInterval) );
	}
    }

####################################
# new version creation conditional
####################################

    my $versionIsOpen = 0;  # can we do anything to this version?

# recall $isOpen = timeNow > openDate and $isClosed = timeNow > dueDate
    if ( $isOpen && ! $isClosed ) {

# if no specific version is requested, we can create a new one if 
#    need be
	if ( ! $requestedVersion ) { 
	    if ( 
		 ( $maxAttempts == -1 || $totalNumVersions < $maxAttempts )
		 &&
		 ( $setVersionNumber == 0 ||
		   ( 
		     ( $currentNumAttempts >= $maxAttemptsPerVersion 
		       ||
		       $timeNow >= $set->due_date + $grace )
		     &&
		     ( ! $versionsPerInterval 
		       ||
		       $currentNumVersions < $versionsPerInterval ) 
		   ) 
		 )
		 &&
		 ( $effectiveUserName eq $userName ||
		   $authz->hasPermissions($effectiveUserName,
				"record_answers_when_acting_as_student") )
	       ) {

    # assign set, get the right name, version number, etc., and redefine
    #    the $set and $Problem we're working with
		my $setTmpl = $db->getUserSet($effectiveUserName,$setName);
		WeBWorK::ContentGenerator::Instructor::assignSetVersionToUser(
				$self, $effectiveUserName, $setTmpl);
		$setVersionNumber++;
		$set = $db->getMergedSetVersion($userName, $setName,
						$setVersionNumber);

		$Problem = $db->getMergedProblemVersion($userName, $setName,
							$setVersionNumber, 1);
    # because we're creating this on the fly, it should be published
		$set->published(1);
    # set up creation time, open and due dates
		my $ansOffset = $set->answer_date() - $set->due_date();
		$set->version_creation_time( $timeNow );
		$set->open_date( $timeNow );
		$set->due_date( $timeNow+$timeLimit ) if ( ! $set->time_limit_cap || $timeNow + $timeLimit < $set->due_date );
		$set->answer_date( $set->due_date + $ansOffset );
		$set->version_last_attempt_time( 0 );
    # put this new info into the database.  note that this means that -all- of
    #    the merged information gets put back into the database.  as long as
    #    the version doesn't have a long lifespan, this is ok...
		$db->putSetVersion( $set );

    # we have a new set version, so it's open
		$versionIsOpen = 1;

    # also reset the number of attempts for this set to zero
		$currentNumAttempts = 0;

	    } elsif ( $maxAttempts != -1 && $totalNumVersions > $maxAttempts ) {
		$self->{invalidSet} = "No new versions of this assignment " .
		    "are available,\nbecause you have already taken the " .
		    "maximum number\nallowed.";

	    } elsif ( $currentNumAttempts < $maxAttemptsPerVersion &&
		      $timeNow < $set->due_date() + $grace ) {

		if ( between($set->open_date(), $set->due_date() + $grace, $timeNow) ) {
		    $versionIsOpen = 1;
		} else {
		    $versionIsOpen = 0;  # redundant; default is 0
		    $self->{invalidSet} = "No new versions of this assignment" .
			"are available,\nbecause the set is not open or its" .
			"time limit has expired.\n";
		}

	    } elsif ( $versionsPerInterval && 
		      ( $currentNumVersions >= $versionsPerInterval ) ) {
		$self->{invalidSet} = "You have already taken all available " .
		    "versions of this\ntest in the current time interval.  " .
		    "You may take the\ntest again after the time interval " .
		    "has expired.";

	    }

	} else {
# (we're still in the $isOpen && ! $isClosed conditional here)
# if a specific version is requested, then we only check to see if it's open
	    if ( 
		 ( $currentNumAttempts < $maxAttemptsPerVersion )
		 && 
		 ( $effectiveUserName eq $userName ||
		   $authz->hasPermissions($effectiveUserName,
				"record_answers_when_acting_as_student") )
	       ) {
		if ( between($set->open_date(), $set->due_date() + $grace, $timeNow) ) {
		    $versionIsOpen = 1;
		} else {
		    $versionIsOpen = 0;  # redundant; default is 0
		}
	    }
	}

# set isn't available.  
    } elsif ( ! $isOpen ) {
	$self->{invalidSet} = "This assignment is not open.";

    } elsif ( ! $requestedVersion ) { # closed set, with attempt at a new one
	$self->{invalidSet} = "This set is closed.  No new set versions may " .
	    "be taken.";
    }


####################################
# save problem and user data
####################################

    my $psvn = $set->psvn();
    $self->{tmplSet} = $tmplSet;
    $self->{set} = $set;
    $self->{problem} = $Problem;
    $self->{requestedVersion} = $requestedVersion;
	
    $self->{userName} = $userName;
    $self->{effectiveUserName} = $effectiveUserName;
    $self->{user} = $User;
    $self->{effectiveUser}   = $EffectiveUser;
    $self->{permissionLevel} = $permissionLevel;

    $self->{isOpen} = $isOpen;
    $self->{isClosed} = $isClosed;
    $self->{versionIsOpen} = $versionIsOpen;

    $self->{timeNow} = $timeNow;
	
####################################
# form processing
####################################

  # this is the same as the following, but doesn't appear in Problem.pm
    my $newPage = $r->param("newPage");
    $self->{newPage} = $newPage;

# *BeginPPM* ###################################################################

  # set options from form fields (see comment at top of file for names)
    my $displayMode      = $r->param("displayMode") || 
	                   $ce->{pg}->{options}->{displayMode};
    my $redisplay        = $r->param("redisplay");
    my $submitAnswers    = $r->param("submitAnswers");
    my $checkAnswers     = $r->param("checkAnswers");
    my $checkingAnswersNow = $r->param("checkingAnswersNow") || 0;
    my $previewAnswers   = $r->param("previewAnswers");

    my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
    $self->{displayMode}    = $displayMode;
    $self->{redisplay}      = $redisplay;
    $self->{submitAnswers}  = $submitAnswers;
    $self->{checkAnswers}   = $checkAnswers;
    $self->{previewAnswers} = $previewAnswers;
    $self->{formFields}     = $formFields;

  # get result and send to message
    my $success	       = $r->param("sucess");
    my $failure	       = $r->param("failure");
    $self->addbadmessage(CGI::p($failure)) if $failure;
    $self->addgoodmessage(CGI::p($success)) if $success;

  # now that we've set all the necessary variables quit out if the set or 
  #    problem is invalid
    return if $self->{invalidSet} || $self->{invalidProblem};

# *EndPPM* #####################################################################

####################################
# permissions
####################################
	
# bail without doing anything if the set isn't yet open for this user
    return unless $self->{isOpen};

  # what does the user want to do?
    my %want = 
	(showOldAnswers     => $r->param("showOldAnswers") || 
	                       $ce->{pg}->{options}->{showOldAnswers},
  	 showCorrectAnswers => $r->param("showCorrectAnswers") || 
 	                       $ce->{pg}->{options}->{showCorrectAnswers},
	 showHints          => $r->param("showHints") || 
		               $ce->{pg}->{options}->{showHints},
	 showSolutions      => $r->param("showSolutions") || 
		               $ce->{pg}->{options}->{showSolutions},
	 recordAnswers      => $submitAnswers,
  # we also want to check answers if we were checking answers and are
  #    switching between pages
	 checkAnswers       => $checkAnswers || ($checkingAnswersNow && $newPage),
	 );

  # are certain options enforced?
    my %must = 
	(showOldAnswers     => 0,
	 showCorrectAnswers => 0,
	 showHints          => 0,
	 showSolutions      => 0,
	 recordAnswers      => ! $authz->hasPermissions($userName, 
						"avoid_recording_answers"),
	 checkAnswers       => 0,
	 );

    # does the user have permission to use certain options?
    my @args = ($User, $PermissionLevel, $EffectiveUser, $set, $Problem, $tmplSet);
    my $sAns = ( $submitAnswers ? 1 : 0 );
    my %can = 
	(showOldAnswers     => $self->can_showOldAnswers(@args), 
	 showCorrectAnswers => $self->can_showCorrectAnswers(@args, $sAns),
	 showHints          => $self->can_showHints(@args),
	 showSolutions      => $self->can_showSolutions(@args, $sAns),
	 recordAnswers      => $self->can_recordAnswers(@args),
	 checkAnswers       => $self->can_checkAnswers(@args),
	 recordAnswersNextTime => $self->can_recordAnswers(@args, $sAns),
	 checkAnswersNextTime  => $self->can_checkAnswers(@args, $sAns),
	 showScore          => $self->can_showScore(@args),
	);

  # final values for options
#     warn("back - next time, " . $can{recordAnswersNextTime} . "\n");
    my %will;
    foreach (keys %must) {
	$will{$_} = $can{$_} && ($must{$_} || $want{$_}) ;
    }

  ##### store fields #####

## FIXME: the following is present in Problem.pm, but missing here.  how do we 
##   deal with it in the context of multiple problems with possible hints?
## ##### fix hint/solution options #####
## $can{showHints}     &&= $pg->{flags}->{hintExists}  
##                     &&= $pg->{flags}->{showHintLimit}<=$pg->{state}->{num_of_incorrect_ans};
## $can{showSolutions} &&= $pg->{flags}->{solutionExists};
	
    $self->{want} = \%want;
    $self->{must} = \%must;
    $self->{can}  = \%can;
    $self->{will} = \%will;


####################################
# set up problem numbering and multipage variables
####################################

    my @problemNumbers = $db->listProblemVersions($effectiveUserName, 
						  $setName, $setVersionNumber);

# to speed up processing of long (multi-page) tests, we want to only 
#    translate those problems that are being submitted or are currently 
#    being displayed.  so work out here which problems are on the current
#    page.
    my ( $numPages, $pageNumber, $numProbPerPage ) = ( 1, 0, 0 );
    my ( $startProb, $endProb ) = ( 0, $#problemNumbers );

 # update startProb and endProb for multipage tests
    if ( defined($set->problems_per_page) && $set->problems_per_page ) {
	$numProbPerPage = $set->problems_per_page;
	$pageNumber = ($newPage) ? $newPage : 1;

	$numPages = scalar(@problemNumbers)/$numProbPerPage;
	$numPages = int($numPages) + 1 if ( int($numPages) != $numPages );

	$startProb = ($pageNumber - 1)*$numProbPerPage;
	$startProb = 0 if ( $startProb < 0 || $startProb > $#problemNumbers );
	$endProb = ($startProb + $numProbPerPage > $#problemNumbers) ? 
	    $#problemNumbers : $startProb + $numProbPerPage - 1;
    }


# set up problem list for randomly ordered tests
    my @probOrder = (0..$#problemNumbers);

# there's a routine to do this somewhere, I think...
    if ( defined( $set->problem_randorder ) && $set->problem_randorder ) {
	my @newOrder = ();
# we need to keep the random order the same each time the set is loaded!
#    this requires either saving the order in the set definition, or being 
#    sure that the random seed that we use is the same each time the same 
#    set is called.  we'll do the latter by setting the seed to the psvn
#    of the problem set.  we use a local PGrandom object to avoid mucking
#    with the system seed.
	my $pgrand = PGrandom->new();
	$pgrand->srand( $set->psvn );
	while ( @probOrder ) { 
	    my $i = int($pgrand->rand(scalar(@probOrder)));
	    push( @newOrder, $probOrder[$i] );
	    splice(@probOrder, $i, 1);
	}
	@probOrder = @newOrder;
    }
# now $probOrder[i] = the problem number, numbered from zero, that's 
#    displayed in the ith position on the test

# make a list of those problems we're displaying
    my @probsToDisplay = ();
    for ( my $i=0; $i<@probOrder; $i++ ) {
	push(@probsToDisplay, $probOrder[$i]) 
	    if ( $i >= $startProb && $i <= $endProb );
    }
# FIXME: debug code
#     warn("Start, end = $startProb, $endProb\n",
# 	 "ProbOrder = @probOrder\n",
# 	 "Probs to display = @probsToDisplay\n");

####################################
# process problems
####################################

    my @problems = ();
    my @pg_results = ();
# pg errors are stored here; initialize it to empty to start
    $self->{errors} = [ ];

#
# process the problems as needed
    foreach my $problemNumber (sort {$a<=>$b } @problemNumbers) {
	my $ProblemN = $db->getMergedProblemVersion($effectiveUserName,
						    $setName,
						    $setVersionNumber,
						    $problemNumber);
    # pIndex numbers from zero
	my $pIndex = $problemNumber - 1;

    # sticky answers are set up here
	if ( not ( $submitAnswers or $previewAnswers or $checkAnswers or 
		   $newPage ) and $will{showOldAnswers} ) {

	    my %oldAnswers = decodeAnswers( $ProblemN->last_answer );
	    $formFields->{$_} = $oldAnswers{$_} foreach ( keys %oldAnswers );
	}
	push( @problems, $ProblemN );

    # if we don't have to translate this problem, just save the problem object
	my $pg = $ProblemN;
    # this is the actual translation of each problem.  errors are stored in 
    #    @{$self->{errors}} in each case
	if ( (grep /^$pIndex$/, @probsToDisplay) || $submitAnswers || 
	     $checkAnswers ) {
# FIXME: debug code
#	    warn("translating problem $pIndex (number $problemNumber)\n");
	    $pg = $self->getProblemHTML($self->{effectiveUser}, $setName,
					$setVersionNumber, $formFields, 
					$ProblemN);
	}
	push(@pg_results, $pg);
    }
    $self->{ra_problems} = \@problems;
    $self->{ra_pg_results}=\@pg_results;

    $self->{startProb} = $startProb;
    $self->{endProb} = $endProb;
    $self->{numPages} = $numPages;
    $self->{pageNumber} = $pageNumber;
    $self->{ra_probOrder} = \@probOrder;
}

sub path {
    my ( $self, $args ) = @_;

    my $r = $self->{r};
    my $setName = $r->urlpath->arg("setID");
    my $ce = $self->{ce};
    my $root = $ce->{webworkURLs}->{root};
    my $courseName = $ce->{courseName};
 
    return $self->pathMacro( $args, "Home" => "$root", 
			     $courseName => "$root/$courseName",
			     $setName => "" );
}

sub nav {
    my ($self, $args) = @_;
	
    my $r = $self->{r};
    my $setName = $r->urlpath->arg("setID");
    my $ce = $self->{ce};
    my $root = $ce->{webworkURLs}->{root};
    my $courseName = $ce->{courseName};
    my @links = ("Problem Sets" , "$root/$courseName", "navUp");
    my $tail = "";
	
    return $self->navMacro($args, $tail, @links);
}

sub options {
	my ($self) = @_;
	#warn "doing options in GatewayQuiz";
	
	# don't show options if we don't have anything to show
	return if $self->{invalidSet} or $self->{invalidProblem};
	return unless $self->{isOpen};
	
	my $displayMode = $self->{displayMode};
	my %can = %{ $self->{can} };
	
	my @options_to_show = "displayMode";
	push @options_to_show, "showOldAnswers" if $can{showOldAnswers};
	push @options_to_show, "showHints" if $can{showHints};
	push @options_to_show, "showSolutions" if $can{showSolutions};
	
	return $self->optionsMacro(
		options_to_show => \@options_to_show,
	);
}

sub body {
    my $self = shift();
    my $r = $self->r;
    my $ce = $r->ce;
    my $db = $r->db;
    my $authz = $r->authz;
    my $urlpath = $r->urlpath;
    my $user = $r->param('user');
    my $effectiveUser = $r->param('effectiveUser');

# report everything with the same time that we started with
    my $timeNow = $self->{timeNow};
    my $grace = $ce->{gatewayGracePeriod};

#########################################
# preliminary error checking and output
#########################################

# basic error checking: is the set actually open?
    unless ( $self->{isOpen} ) {
	return CGI::div({class=>"ResultsWithError"},
			CGI::p("This assignment is not open yet, and " .
			       "therefore is not yet available"));
    }
# if we set the invalid flag, we may want this too
    if ($self->{invalidSet}) {
# delete any proctor keys that are floating around
	if ( $self->{'assignment_type'} eq 'proctored_gateway' ) {
	    my $proctorID = $r->param('proctor_user');
	    eval{ $db->deleteKey( "$effectiveUser,$proctorID" ); };
	    eval{ $db->deleteKey( "$effectiveUser,$proctorID,g" ); };
	}

	return CGI::div({class=>"ResultsWithError"},
			CGI::p("The selected problem set (" . 
			       $urlpath->arg("setID") . ") is not a valid set" .
			       " for $effectiveUser."),
			CGI::p("This is because: " . $self->{invalidSet}));
    }
	
    my $tmplSet = $self->{tmplSet};
    my $set = $self->{set};
    my $Problem = $self->{problem};
    my $permissionLevel = $self->{permissionLevel};
    my $submitAnswers = $self->{submitAnswers};
    my $checkAnswers = $self->{checkAnswers};
    my $previewAnswers = $self->{previewAnswers};
    my $newPage = $self->{newPage};
    my %want = %{ $self->{want} };
    my %can = %{ $self->{can} };
    my %must = %{ $self->{must} };
    my %will = %{ $self->{will} };

    my @problems = @{ $self->{ra_problems} };
    my @pg_results = @{ $self->{ra_pg_results} };
    my @pg_errors = @{ $self->{errors} };
    my $requestedVersion = $self->{requestedVersion};

    my $startProb = $self->{startProb};
    my $endProb = $self->{endProb};
    my $numPages = $self->{numPages};
    my $pageNumber = $self->{pageNumber};
    my @probOrder = @{$self->{ra_probOrder}};

    my $setName  = $set->set_id;
    my $versionNumber = $set->version_id;
    my $numProbPerPage = $set->problems_per_page;

# translation errors -- we use the same output routine as Problem.pm, but 
#    play around to allow for errors on multiple translations because we 
#    have an array of problems to deal with.
    if ( @pg_errors ) {
	my $errorNum = 1;
	my ( $message, $context ) = ( '', '' );
	foreach ( @pg_errors ) {

	    $message .= "$errorNum. " if ( @pg_errors > 1 );
	    $message .= $_->{message} . CGI::br() . "\n";

	    $context .= CGI::p( (@pg_errors > 1 ? "$errorNum." : '') . 
				$_->{context} ) . "\n\n" . CGI::hr() . "\n\n";
	}
	return $self->errorOutput( $message, $context );
    }

####################################
# answer processing
####################################

    debug("begin answer processing"); 

    my @scoreRecordedMessage = ('') x scalar(@problems);

    if ( $submitAnswers ) {

# if we're submitting answers for a proctored exam, we want to delete
#    the proctor keys that authorized that grading, so that it isn't possible
#    to just log in and take another proctored test without getting 
#    reauthorized
	if ( $self->{'assignment_type'} eq 'proctored_gateway' ) {
	    my $proctorID = $r->param('proctor_user');
	    eval{ $db->deleteKey( "$effectiveUser,$proctorID" ); };
    # we should be more subtle than die()ing, but this is a potentially 
    #    big problem
	    if ( $@ ) {
		die("ERROR RESETTING PROCTOR KEY: $@\n");
	    }
	    eval{ $db->deleteKey( "$effectiveUser,$proctorID,g" ); };
	    if ( $@ ) {
		die("ERROR RESETTING PROCTOR GRADING KEY: $@\n");
	    }
	}

	foreach my $i ( 0 .. $#problems ) {  # process each problem in g/w
    # this code is essentially that from Problem.pm
	    my $pureProblem = $db->getProblemVersion($problems[$i]->user_id,
						     $setName, $versionNumber,
						     $problems[$i]->problem_id);
    # this should be defined unless it's not assigned yet, in which case 
    #    we should have die()ed earlier, but what's an extra conditional 
    #    between friends?
	    if ( defined( $pureProblem ) ) {
        # store answers in problem for sticky answers later
		my %answersToStore;
		my %answerHash = %{$pg_results[$i]->{answers}};
		$answersToStore{$_} = 
		    $self->{formFields}->{$_} foreach ( keys %answerHash );
	# check for extra answers that slipped by---e.g. for matrices, and get
        #    them from the original input form
		my @extra_answer_names = 
		    @{ $pg_results[$i]->{flags}->{KEPT_EXTRA_ANSWERS} };
		$answersToStore{$_} = 
		    $self->{formFields}->{$_} foreach ( @extra_answer_names );
        # now encode all answers
		my @answer_order = 
		    ( @{$pg_results[$i]->{flags}->{ANSWER_ENTRY_ORDER}}, 
		      @extra_answer_names );
		my $answerString = encodeAnswers( %answersToStore, 
						  @answer_order );
        # and get the last answer 
		$problems[$i]->last_answer( $answerString );
		$pureProblem->last_answer( $answerString );
        # this results in us saving the last answer by clicking 'back'
        # and then 'submit answers' even when we're out of attempts; we 
	# therefore comment it out here
	#	$db->putUserProblem( $pureProblem, $versioned );

        # next, store the state in the database if that makes sense
		if ( $will{recordAnswers} ) {
  $problems[$i]->status($pg_results[$i]->{state}->{recorded_score});
  $problems[$i]->attempted(1);
  $problems[$i]->num_correct($pg_results[$i]->{state}->{num_of_correct_ans});
  $problems[$i]->num_incorrect($pg_results[$i]->{state}->{num_of_incorrect_ans});
  $pureProblem->status($pg_results[$i]->{state}->{recorded_score});
  $pureProblem->attempted(1);
  $pureProblem->num_correct($pg_results[$i]->{state}->{num_of_correct_ans});
  $pureProblem->num_incorrect($pg_results[$i]->{state}->{num_of_incorrect_ans});

                    if ( $db->putProblemVersion( $pureProblem ) ) {
			$scoreRecordedMessage[$i] = "Your score on this " .
			    "problem was recorded.";
		    } else {
			$scoreRecordedMessage[$i] = "Your score was not " .
			    "recorded because there was a failure in storing " .
			    "the problem record to the database.";
		    }
            # write the transaction log
                    writeLog( $self->{ce}, "transaction",
			      $problems[$i]->problem_id . "\t" .
			      $problems[$i]->set_id . "\t" .
			      $problems[$i]->user_id . "\t" .
			      $problems[$i]->source_file . "\t" .
			      $problems[$i]->value . "\t" .
			      $problems[$i]->max_attempts . "\t" .
			      $problems[$i]->problem_seed . "\t" .
			      $problems[$i]->status . "\t" .
			      $problems[$i]->attempted . "\t" .
			      $problems[$i]->last_answer . "\t" .
			      $problems[$i]->num_correct . "\t" .
			      $problems[$i]->num_incorrect
			    );
                } else {

		    if ($self->{isClosed}) {
			$scoreRecordedMessage[$i] = "Your score was not " .
			    "recorded because this problem set version is " .
			    "not open.";
		    } elsif ( $problems[$i]->num_correct + 
			      $problems[$i]->num_incorrect >= 
			      $set->attempts_per_version ) {
			$scoreRecordedMessage[$i] = "Your score was not " .
			    "recorded because you have no attempts " .
			    "remaining on this set version.";
		    } elsif ( ! $self->{versionIsOpen} ) {
			my $endTime = ( $set->version_last_attempt_time ) ? 
			    $set->version_last_attempt_time : $timeNow;
			if ( $endTime > $set->due_date && 
			     $endTime < $set->due_date + $grace ) {
			    $endTime = $set->due_date;
			}
# sprintf forces two decimals, which we don't like
#			my $elapsed = sprintf("%4.2f",($endTime - 
#						       $set->open_date)/60);
			my $elapsed = 
			    int(($endTime - $set->open_date)/0.6 + 0.5)/100;
                    # we assume that allowed is an even number of minutes
			my $allowed = ($set->due_date - $set->open_date)/60;
			$scoreRecordedMessage[$i] = "Your score was not " .
			    "recorded because you have exceeded the time " .
			    "limit for this test. (Time taken: $elapsed min;" .
			    " allowed: $allowed min.)";
		    } else {
			$scoreRecordedMessage[$i] = "Your score was not " .
			    "recorded.";
		    }
		}
	    } else {
# I don't think this should ever happen, because we die() out of the 
#    pre_header_initialize routine when we have the same situation
		$scoreRecordedMessage[$i] = "Your score was not recorded, " .
		    "because this problem set has not been assigned to you.";
	    }
        # log student answers
	    my $answer_log = $self->{ce}->{courseFiles}->{logs}->{'answer_log'};

	# this is carried over from Problem.pm
	    if ( defined( $answer_log ) && defined( $pureProblem ) ) {
		if ( $submitAnswers ) {
		    my $answerString = '';
		    my %answerHash = %{ $pg_results[$i]->{answers} };
            # FIXME fix carried over from Problem.pm for "line 552 error"

		    foreach ( sort keys %answerHash ) {
			my $student_ans = 
			    $answerHash{$_}->{original_student_ans} || '';
			$answerString .= $student_ans . "\t";
		    }
		    $answerString = '' unless defined( $answerString );

		    writeCourseLog( $self->{ce}, "answer_log",
				    join("", '|', $problems[$i]->user_id,
					     '|', $problems[$i]->set_id,
					     '|', $problems[$i]->problem_id,
					     '|', "\t$timeNow\t",
					     $answerString), 
				    );
		}
	    }
	} # end loop through problems

    } # end if submitAnswers conditional
    debug("end answer processing");

# additional set-level database manipulation: we want to save the time 
#    that a set was submitted, and for proctored tests we want to reset 
#    the assignment type after a set is submitted for the last time so 
#    that it's possible to look at it later without getting proctor 
#    authorization
    if ( ( $submitAnswers && 
	   ( $will{recordAnswers} || 
	     ( ! $set->version_last_attempt_time() &&
	       $timeNow > $set->due_date + $grace ) ) ) ||
	 ( ! $can{recordAnswersNextTime} && 
	   $set->assignment_type() eq 'proctored_gateway' ) ) {

	my $setName = $set->set_id();

# save the submission time if we're recording the answer, or if the 
# first submission occurs after the due_date
	if ( $submitAnswers && 
	     ( $will{recordAnswers} || 
	       ( ! $set->version_last_attempt_time() &&
		 $timeNow > $set->due_date + $grace ) ) ) {
	    $set->version_last_attempt_time( $timeNow );
	}
	if ( ! $can{recordAnswersNextTime} && 
	     $set->assignment_type() eq 'proctored_gateway' ) {
	    $set->assignment_type( 'gateway' );
	}
	$db->putSetVersion( $set );
    }



####################################
# output
####################################

# some convenient output variables
    my $canShowScores = $authz->hasPermissions($user, "view_hidden_work") || ( $set->hide_score eq 'N' || ($set->hide_score eq 'BeforeAnswerDate' && $timeNow>$tmplSet->answer_date) );
    my $canShowWork = $authz->hasPermissions($user, "view_hidden_work") || ($set->hide_work eq 'N' || ($set->hide_work eq 'BeforeAnswerDate' && $timeNow>$tmplSet->answer_date));

#     warn("canshowscores = $canShowScores; set->hide_score =", $set->hide_score, "\n");
#     warn("canshowwork = $canShowWork; set->hide_work =", $set->hide_work, "\n");

# figure out recorded score for the set, if any, and score on this attempt
    my $recordedScore = 0;
    my $totPossible = 0;
    foreach ( @problems ) {
	$totPossible += $_->value();
	$recordedScore += $_->{status}*$_->value() if ( defined( $_->status ) );
    }

# a handy noun for when referring to a test
    my $testNoun = ( $set->attempts_per_version > 1 ) ? "submission" : "test";
    my $testNounNum = ( $set->attempts_per_version > 1 ) ? 
	"submission (test " : "test (";

# to get the attempt score, we have to figure out what the score on each
# part of each problem is, and multiply the total for the problem by the 
# weight (value) of the problem.  it seems this should be easier to work 
# out than this.
    my $attemptScore = 0;
# FIXME: debug.  should this be if ( submit || check ) or if (will...)?
#     it gets the case of checking answers and then switching pages of a 
#     multipage test
#    if ( $submitAnswers || $checkAnswers ) {
    if ( $submitAnswers || ( $checkAnswers || $will{checkAnswers} ) ) {
	my $i=0;
	foreach my $pg ( @pg_results ) {
	    my $pValue = $problems[$i]->value();
	    my $pScore = 0;
	    my $numParts = 0;
	    foreach ( @{$pg->{flags}->{ANSWER_ENTRY_ORDER}} ) {
		$pScore += $pg->{answers}->{$_}->{score};
		$numParts++;
	    }
	    $attemptScore += $pScore*$pValue/($numParts > 0 ? $numParts : 1);
	    $i++;
	}
    }

# we want to print elapsed and allowed times; allowed is easy (we assume
# this is an even number of minutes)
    my $allowed = ($set->due_date - $set->open_date)/60;
# elapsed is a little harder; we're counting to the last submission 
# time, or to the current time if the test hasn't been submitted, and if the
# submission fell in the grace period round it to the due_date
    my $exceededAllowedTime = 0;
    my $endTime = ( $set->version_last_attempt_time ) ? 
	$set->version_last_attempt_time : $timeNow;
    if ( $endTime > $set->due_date && $endTime < $set->due_date + $grace ) {
	$endTime = $set->due_date;
    } elsif ( $endTime > $set->due_date ) {
	$exceededAllowedTime = 1;
    }
    my $elapsedTime = int(($endTime - $set->open_date)/0.6 + 0.5)/100;

# also get number of remaining attempts (important for sets with multiple
# attempts per version)
    my $numLeft = $set->attempts_per_version - $Problem->num_correct - 
	$Problem->num_incorrect - 
	($submitAnswers && $will{recordAnswers} ? 1 : 0);
    my $attemptNumber = $Problem->num_correct + $Problem->num_incorrect;

##### start output of test headers: 
##### display information about recorded and checked scores
    if ( $submitAnswers ) {
	# the distinction between $can{recordAnswers} and ! $can{} has 
	#    been dealt with above and recorded in @scoreRecordedMessage
	my $divClass = 'ResultsWithoutError';
	my $recdMsg = '';
	foreach ( @scoreRecordedMessage ) {
	    if ( $_ ne 'Your score on this problem was recorded.' ) {
		$recdMsg = $_;
		$divClass = 'ResultsWithError';
		last;
	    }
	}
	print CGI::start_div({class=>$divClass});

	if ( $recdMsg ) {
	    # then there was an error when saving the results
	    print CGI::strong("Your score on this $testNounNum ",
			      "$versionNumber) was NOT recorded.  ",
			      $recdMsg), CGI::br();
	} else {
	    # no error; print recorded message
	    print CGI::strong("Your score on this $testNounNum ",
			      "$versionNumber) WAS recorded."), 
	    	CGI::br();

	    # and show the score if we're allowed to do that
	    if ( $canShowScores ) {
		print CGI::strong("Your score on this $testNoun is ",
				  "$attemptScore/$totPossible.");
	    }
	}

	# finally, if there is another, recorded message, print that 
	#    too so that we know what's going on
	print CGI::end_div();
	if ( $set->attempts_per_version > 1 && $attemptNumber > 1 &&
	     $recordedScore != $attemptScore && $canShowScores ) {
	    print CGI::start_div({class=>'gwMessage'});
	    print "The recorded score for this test is ",
	    	"$recordedScore/$totPossible.";
	    print CGI::end_div();
	}

# FIXME: debug.  do we want || will{checkanswers} too?  it gets the case
#    of checking answers and then switching pages of a multipage test
    } elsif ( $checkAnswers || $will{checkAnswers} ) {
	if ( $canShowScores ) {
	    print CGI::start_div({class=>'gwMessage'});
	    print CGI::strong("Your score on this (checked, not ",
			      "recorded) submission is ",
			      "$attemptScore/$totPossible."), CGI::br();
	    print "The recorded score for this test is $recordedScore/" .
		"$totPossible.  ";
	    print CGI::end_div();
	}
    }

##### remaining output of test headers:
##### display timer or information about elapsed time, "printme" link,
##### and information about any recorded score if not submitAnswers or 
##### checkAnswers
    if ( $can{recordAnswersNextTime} ) {

	# print timer
	# FIXME: in the long run, we want to allow a test to not be
	#    timed.  This does not allow for that possibility
	my $timeLeft = $set->due_date() - $timeNow;  # this is in seconds
	print CGI::div({-id=>"gwTimer"},"\n");
	print CGI::startform({-name=>"gwTimeData", -method=>"POST",
			      -action=>$r->uri});
	print CGI::hidden({-name=>"serverTime", -value=>$timeNow}), "\n";
	print CGI::hidden({-name=>"serverDueTime", -value=>$set->due_date()}),
		"\n";
	print CGI::endform();

	if ( $timeLeft < 1 && $timeLeft > 0 ) {
	    print CGI::span({-class=>"resultsWithError"}, 
			    CGI::b("You have less than 1 minute to ",
				   "complete this test.\n"));
	} elsif ( $timeLeft <= 0 ) { 
	    print CGI::span({-class=>"resultsWithError"}, 
			    CGI::b("You are out of time.  Press grade now!\n"));
	}
	# if there are multiple attempts per version, indicate the number
	#    remaining
	if ( $set->attempts_per_version > 1 ) {
	    print CGI::em("You have $numLeft attempt(s) remaining on this ",
			  "test.");
	}
    } else {
    # FIXME: debug.  should this include the will{checkAnswers}?  this gets
    #    the case of going between pages of a multipage test

	print CGI::start_div({class=>'gwMessage'});

	if ( ! ($checkAnswers || $will{checkAnswers}) && ! $submitAnswers ) {

	    if ( $canShowScores ) {
		my $scMsg = "Your recorded score on this test (number " .
		    "$versionNumber) is $recordedScore/" .
		    "$totPossible";
		if ( $exceededAllowedTime && $recordedScore == 0 ) {
		    $scMsg .= ", because you exceeded the allowed time.";
		} else {
		    $scMsg .= ".  ";
		}
		print CGI::strong($scMsg), CGI::br();
	    }
	}

	if ( $set->version_last_attempt_time ) {
	    print "Time taken on test: $elapsedTime min ($allowed min " .
		"allowed).";
	} elsif ( $exceededAllowedTime && $recordedScore != 0 ) {
	    print "(This test is overtime because it was not " .
		"submitted in the allowed time.)";
	}
	print CGI::end_div();

	if ( $canShowWork ) {
	    print "The test (which is number $versionNumber) may no " .
		"longer be submitted for a grade";
	    print "" . (($canShowScores) ? ", but you may still " .
		"check your answers." : ".") ;

	# print a "printme" link if we're allowed to see our work
	    my $link = $ce->{webworkURLs}->{root} . '/' . $ce->{courseName} . 
		'/hardcopy/' . $set->set_id . ',v' . $set->version_id . '/?' . 
		$self->url_authen_args;
	    my $printmsg = CGI::div({-class=>'gwPrintMe'}, 
				    CGI::a({-href=>$link}, "Print Test"));
	    print $printmsg;
	}

    }

# this is a hack to get a URL that won't require a proctor login if we've
# submitted a proctored test for the last time.  above we've reset the 
# assignment_type in this case, so we'll use that to decide if we should 
# give a path to an unproctored test.
    my $action = $r->uri();
    $action =~ s/proctored_quiz_mode/quiz_mode/ 
	if ( $set->assignment_type() eq 'gateway' );
# we also want to be sure that if we're in a set, the 'action' in the form
# points us to the same set.  
    my $setname = $set->set_id;
    my $setvnum = $set->version_id;
    $action =~ s/(quiz_mode\/$setname)\//$1,v$setvnum\//;

# now, we print out the rest of the page if we're not hiding submitted
# answers
    if ( ! $can{recordAnswersNextTime} && ! $canShowWork ) {
	print CGI::start_div({class=>"gwProblem"});
	print CGI::strong("Completed results for this assignment are " .
			  "not available.");
	print CGI::end_div();

# else: we're not hiding answers
    } else {

	print CGI::startform({-name=>"gwquiz", -method=>"POST", 
			      -action=>$action}), 
	    $self->hidden_authen_fields, $self->hidden_proctor_authen_fields;

# hacks to use a javascript link to trigger previews and jump to 
# subsequent pages of a multipage test
	print CGI::hidden({-name=>'previewHack', -value=>''}), CGI::br();
	print CGI::hidden({-name=>'newPage', -value=>''}) 
	    if ( $numProbPerPage && $numPages > 1 );

# the link for a preview; for a multipage test, this also needs to 
# keep track of what page we're on
	my $jsprevlink = 'javascript:document.gwquiz.previewHack.value="1";';
	$jsprevlink .= "document.gwquiz.newPage.value=\"$pageNumber\";"
	    if ( $numProbPerPage && $numPages > 1 );
	$jsprevlink .= 'document.gwquiz.submit();';

# set up links between problems and, for multi-page tests, pages
	my $jumpLinks = '';
	my $probRow = [ CGI::b("Problem") ];
	for my $i ( 0 .. $#pg_results ) {
	    
	    my $pn = $i + 1;
	    if ( $i >= $startProb && $i <= $endProb ) {
		push( @$probRow, CGI::b(" [ ") ) if ( $i == $startProb );
		push( @$probRow, " &nbsp;" . 
		      CGI::a({-href=>".", 
			      -onclick=>"jumpTo($pn);return false;"},
			     "$pn") . "&nbsp; " );
		push( @$probRow, CGI::b(" ] ") ) if ( $i == $endProb );
	    } elsif ( ! ($i % $numProbPerPage) ) {
		push( @$probRow, " &nbsp;&nbsp; ", " &nbsp;&nbsp; ", 
		      " &nbsp;&nbsp; " );
	    }
	}
	if ( $numProbPerPage && $numPages > 1 ) {
	    my $pageRow = [ CGI::td([ CGI::b('Jump to: '), CGI::b('Page '),
				      CGI::b(' [ ' ) ]) ];
	    for my $i ( 1 .. $numPages ) {
		my $pn = ( $i == $pageNumber ) ? $i : 
		    CGI::a({-href=>'javascript:' .
				"document.gwquiz.newPage.value=\"$i\";" .
				'document.gwquiz.submit();'}, 
			   "&nbsp;$i&nbsp;");
# this doesn't quite preserve preview/etc. as we'd like
# 	    my $pn = ( $i == $pageNumber ) ? $i : 
# 		CGI::a({-href=>'javascript:' .
# 			    "document.gwquiz.newPage.value=\"$i\";" .
# 			    ($previewAnswers ? 
# 			     'document.gwquiz.previewHack.value="1";' : '') .
# 			    'document.gwquiz.submit();'}, "$i");
		my $colspan =  0;
		if ( $i == $pageNumber ) {
		    $colspan = 
			($#pg_results - ($i-1)*$numProbPerPage > $numProbPerPage) ?
			$numProbPerPage : 
			$#pg_results - ($i-1)*$numProbPerPage + 1;
		} else {
		    $colspan = 1;
		}
		push( @$pageRow, CGI::td({-colspan=>$colspan, 
					  -align=>'center'}, $pn) );
		push( @$pageRow, CGI::td( [CGI::b(' ] '), CGI::b(' [ ')] ) )
		    if ( $i != $numPages );
	    }
	    push( @$pageRow, CGI::td(CGI::b(' ] ')) );
	    unshift( @$probRow, ' &nbsp; ' );
	    $jumpLinks = CGI::table( CGI::Tr(@$pageRow), 
				     CGI::Tr( CGI::td($probRow) ) );
	} else {
	    unshift( @$probRow, CGI::b('Jump to: ') );
	    $jumpLinks = CGI::table( CGI::Tr( CGI::td($probRow) ) );
	}
	
	print $jumpLinks,"\n";

# print out problems and attempt results, as appropriate
# note: args to attemptResults are (self,) $pg, $showAttemptAnswers,
#    $showCorrectAnswers, $showAttemptResults (and-ed with 
#    $showAttemptAnswers), $showSummary, $showAttemptPreview (or-ed with zero)
	my $problemNumber = 0;

	foreach my $i ( 0 .. $#pg_results ) {
	    my $pg = $pg_results[$probOrder[$i]];
	    $problemNumber++;

	    if ( $i >= $startProb && $i <= $endProb ) { 

		my $recordMessage = '';
		my $resultsTable = '';

		if ($pg->{flags}->{showPartialCorrectAnswers}>=0 && $submitAnswers){
		    if ( $scoreRecordedMessage[$probOrder[$i]] ne 
			 "Your score on this problem was recorded." ) {
			$recordMessage = CGI::span({class=>"resultsWithError"},
						   "ANSWERS NOT RECORDED --", 
						   $scoreRecordedMessage[$probOrder[$i]]);

		    }
		    $resultsTable = 
			$self->attemptResults($pg, 1, $will{showCorrectAnswers},
					      $pg->{flags}->{showPartialCorrectAnswers} && $can{showScore},
					      $can{showScore}, 1);
		
            # FIXME: debug.  do we want || will{checkanswers} too?  it gets 
            #    the case of checking answers and then switching pages of a 
	    #    multipage test
		} elsif ( $checkAnswers || $will{checkAnswers} ) {
		    $recordMessage = CGI::span({class=>"resultsWithError"},
					       "ANSWERS ONLY CHECKED -- ", 
					       "ANSWERS NOT RECORDED");

		    $resultsTable = 
			$self->attemptResults($pg, 1, $will{showCorrectAnswers},
					      $pg->{flags}->{showPartialCorrectAnswers} && $can{showScore},
					      $can{showScore}, 1);

		} elsif ( $previewAnswers ) {
		    $recordMessage = 
			CGI::span({class=>"resultsWithError"},
				  "PREVIEW ONLY -- ANSWERS NOT RECORDED");
		    $resultsTable = $self->attemptResults($pg, 1, 0, 0, 0, 1);
 
		}	    

		print CGI::start_div({class=>"gwProblem"});
		my $i1 = $i+1;
		my $points = ( $problems[$probOrder[$i]]->value() > 1 ) ? 
		    " (" . $problems[$probOrder[$i]]->value() . " points)" : 
		    " (1 point)";
		print CGI::a({-name=>"#$i1"},"");
		print CGI::strong("Problem $problemNumber."), "$points\n", $recordMessage;
		print CGI::p($pg->{body_text}),
		CGI::p($pg->{result}->{msg} ? CGI::b("Note: ") : "", 
		       CGI::i($pg->{result}->{msg}));
		print CGI::p({class=>"gwPreview"}, 
			     CGI::a({-href=>"$jsprevlink"}, "preview problems"));
# 	print CGI::end_div();

		print $resultsTable if $resultsTable; 

		print CGI::end_div();

		print "\n", CGI::hr(), "\n";
	    } else {
		my $i1 = $i+1;
# keep the jump to anchors so that jumping to problem number 6 still
# works, even if we're viewing only problems 5-7, etc.
		print CGI::a({-name=>"#$i1"},""), "\n";
		my $curr_prefix = 'Q' . sprintf("%04d", $probOrder[$i]+1) . '_';
		my @curr_fields = grep /^$curr_prefix/, keys %{$self->{formFields}};
		foreach my $curr_field ( @curr_fields ) {
		    print CGI::hidden({-name=>$curr_field, 
				       -value=>$self->{formFields}->{$curr_field}});
		}
# 	    my $probid = 'Q' . sprintf("%04d", $probOrder[$i]+1) . "_AnSwEr1";
# 	    my $probval = $self->{formFields}->{$probid};
# 	    print CGI::hidden({-name=>$probid, -value=>$probval}), "\n";
	    }
	}
	print CGI::p($jumpLinks, "\n");
	print "\n",CGI::hr(), "\n";

	if ($can{showCorrectAnswers}) {
	    print CGI::checkbox(-name    => "showCorrectAnswers",
#				-checked => $will{showCorrectAnswers},
				-checked => $want{showCorrectAnswers},
				-label   => "Show correct answers",
				);
	}
#     if ($can{showHints}) {
# 	print CGI::div({style=>"color:red"},
# 		       CGI::checkbox(-name    => "showHints",
# 				     -checked => $will{showHints},
# 				     -label   => "Show Hints",
# 				     )
# 		       );
#     }
	if ($can{showSolutions}) {
	    print CGI::checkbox(-name    => "showSolutions",
				-checked => $will{showSolutions},
				-label   => "Show Solutions",
				);
	}

# this solution results in not being able to turn off preview or whatever
# should we be previewing or checking answers too?  we need this to 
# preserve state when viewing multiple page tests
	if ( $numProbPerPage && $numPages > 1 ) {
	    print "\n";
	    print CGI::hidden({-name=>"previewingAnswersNow", 
			       -value=>"1"}), "\n" if $previewAnswers;
	    print CGI::hidden({-name=>"checkingAnswersNow", 
			       -value=>"1"}), "\n" if $checkAnswers || $submitAnswers;
# should we allow this too?
# 	print CGI::hidden({-name=>"submittingAnswersNow", 
#                          -value=>"1"}), "\n" if $submitAnswers;
	}
	
	if ($can{showCorrectAnswers} or $can{showHints} or $can{showSolutions}) {
	    print CGI::br();
	}

# Note: because of the way these things are grouped, the submit/et al buttons
# in this form are getting put outside of the problem div, while on a regular
# problem they'd fall inside.  Does this matter?  We shall see.
	print CGI::p( CGI::submit( -name=>"previewAnswers", 
				   -label=>"Preview Test" ),
		      ($can{recordAnswersNextTime} ? 
		       CGI::submit( -name=>"submitAnswers",
				    -label=>"Grade Test" ) : " "),
		      ($can{checkAnswersNextTime} && ! $can{recordAnswersNextTime} ?
		       CGI::submit( -name=>"checkAnswers",
				    -label=>"Check Test" ) : " "),
		      ($numProbPerPage && $numPages > 1 && 
		       $can{recordAnswersNextTime} ? CGI::br() . 
		       CGI::em("Note: grading the test grades " . 
			       CGI::b("all") . " problems, not just those " . 
			       "on this page.") : " ") );

	print CGI::endform();
    }

# debugging verbiage
#     if ( $can{checkAnswersNextTime} ) {
# 	print "Can check answers next time\n";
#     } else {
# 	print "Can NOT check answers next time\n";
#     }
#     if ( $can{recordAnswersNextTime} ) {
# 	print "Can record answers next time\n";
#     } else {
# 	print "Can NOT record answers next time\n";
#     }

  # we exclude the feedback form from gateway tests.  they can use the feedback
  #   button on the preceding or following pages
#     my $ce = $r->ce;
#     my $root = $ce->{webworkURLs}->{root};
#     my $courseName = $ce->{courseName};
#     my $feedbackURL = "$root/$courseName/feedback/";
#     print CGI::startform("POST", $feedbackURL),
#           $self->hidden_authen_fields,
#           CGI::hidden("module", __PACKAGE__),
#           CGI::hidden("set",    $self->{set}->set_id),
#           CGI::p({-align=>"right"},
# 		 CGI::submit(-name=>"feedbackForm", -label=>"Send Feedback")
# 		 ),
# 	  CGI::endform();
	
    return "";

}


###########################################################################
# Evaluation utilities
############################################################################

sub getProblemHTML {
    my ( $self, $EffectiveUser, $setName, $setVersionNumber, $formFields, 
	 $mergedProblem, $pgFile ) = @_;
# in:  $EffectiveUser is the effective user we're working as, $setName
#      the set name, $setVersionNumber the version number, %$formFields 
#      the form fields from the input form that we need to worry about 
#      putting into the HTML we're generating, and $mergedProblem and 
#      $pgFile are what we'd expect.
#      $pgFile is optional
# out: the translated problem is returned

    my $r = $self->r;
    my $ce = $r->ce;
    my $db = $r->db;
    my $key =  $r->param('key');

# this isn't good because it doesn't include the sticky answers that we 
#    might want.  so off with its head!
##    my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };

    my $permissionLevel = $self->{permissionLevel};
    my $set  = $db->getMergedSetVersion( $EffectiveUser->user_id, 
					 $setName, $setVersionNumber );

# should this ever happen?  I think we should have die()ed way earlier than
#    this if the set doesn't exist, but it can't hurt to try and die() here 
#    too
    die "set $setName,v$setVersionNumber for effectiveUser " . 
	$EffectiveUser->user_id . " not found." unless $set;

    my $psvn = $set->psvn();

    if ( defined($mergedProblem) && $mergedProblem->problem_id ) {
# nothing needs to be done

    } elsif ($pgFile) {
	$mergedProblem = 
	    WeBWorK::DB::Record::ProblemVersion->new(
			set_id => $set->set_id,
			version_id => $set->version_id,
			problem_id => 0,
			login_id => $EffectiveUser->user_id,
			source_file => $pgFile,
			# the rest of Problem's fields are not needed, i think
		);
    }
# figure out if we're allowed to get solutions and call PG->new accordingly.
    my $showCorrectAnswers = $self->{will}->{showCorrectAnswers};
    my $showHints          = $self->{will}->{showHints};
    my $showSolutions      = $self->{will}->{showSolutions};
    my $processAnswers     = $self->{will}->{checkAnswers};

# FIXME  I'm not sure that problem_id is what we want here  FIXME
    my $problemNumber = $mergedProblem->problem_id;

    my $pg = 
	WeBWorK::PG->new(
			 $ce,
			 $EffectiveUser,
			 $key,
			 $set,
			 $mergedProblem,
			 $psvn,
			 $formFields, 
			 { # translation options
			     displayMode     => $self->{displayMode},
			     showHints       => $showHints,
			     showSolutions   => $showSolutions,
			     refreshMath2img => $showHints || $showSolutions,
			     processAnswers  => 1,
			     QUIZ_PREFIX     => 'Q' . 
				 sprintf("%04d",$problemNumber) . '_',
			     },
			 );
	
# FIXME  is problem_id the correct thing in the following two stanzas?
# FIXME  the original version had "problem number", which is what we want.  
# FIXME  I think problem_id will work, too
    if ($pg->{warnings} ne "") {
	push @{$self->{warnings}}, {
	    set     => "$setName,v$setVersionNumber",
	    problem => $mergedProblem->problem_id,
	    message => $pg->{warnings},
	};
    }
	
    if ($pg->{flags}->{error_flag}) {
	push @{$self->{errors}}, {
	    set     => "$setName,v$setVersionNumber",
	    problem => $mergedProblem->problem_id,
	    message => $pg->{errors},
	    context => $pg->{body_text},
	};
	# if there was an error, body_text contains
	# the error context, not TeX code
	$pg->{body_text} = undef;
    }

    return    $pg;
}

##### output utilities #####
sub problemListRow($$$) {
	my $self = shift;
	my $set = shift;
	my $Problem = shift;
	
	my $name = $Problem->problem_id;
	my $interactiveURL = "$name/?" . $self->url_authen_args;
	my $interactive = CGI::a({-href=>$interactiveURL}, "Problem $name");
	my $attempts = $Problem->num_correct + $Problem->num_incorrect;
	my $remaining = $Problem->max_attempts < 0
		? "unlimited"
		: $Problem->max_attempts - $attempts;
	my $status = sprintf("%.0f%%", $Problem->status * 100); # round to whole number
	
	return CGI::Tr(CGI::td({-nowrap=>1}, [
		$interactive,
		$attempts,
		$remaining,
		$status,
	]));
}
# sub nbsp {
# 	my $str = shift;
# 	($str) ? $str : '&nbsp;';  # returns non-breaking space for empty strings
# }

##### logging subroutine ####




1;
