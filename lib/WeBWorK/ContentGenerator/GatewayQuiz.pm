################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/GatewayQuiz.pm,v 1.13 2005/09/21 18:25:52 sh002i Exp $
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
use CGI qw();
use File::Path qw(rmtree);
use WeBWorK::Form;
use WeBWorK::PG;
use WeBWorK::PG::ImageGenerator;
use WeBWorK::PG::IO;
use WeBWorK::Utils qw(writeLog writeCourseLog encodeAnswers decodeAnswers ref2string makeTempDirectory);
use WeBWorK::DB::Utils qw(global2user user2global findDefaults);
use WeBWorK::Debug;
use WeBWorK::ContentGenerator::Instructor qw(assignSetVersionToUser);

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
	#my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem) = @_;
	
	return 1;
}

# gateway change here: add $submitAnswers as an optional additional argument
#   to be included if it's defined
sub can_showCorrectAnswers {
	my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem, 
	    $submitAnswers) = @_;
	my $authz = $self->r->authz;
	
# gateway change here to allow correct answers to be viewed after all attempts
#   at a version are exhausted as well as if it's after the answer date
# $addOne allows us to count the current submission
	my $addOne = defined( $submitAnswers ) ? $submitAnswers : 0;
	my $maxAttempts = $Set->attempts_per_version();
	my $attemptsUsed = $Problem->num_correct + $Problem->num_incorrect + 
	    $addOne;

	return ( ( after( $Set->answer_date ) || 
		   $attemptsUsed >= $maxAttempts ) ||
		 $authz->hasPermissions($User->user_id, 
				"show_correct_answers_before_answer_date") )
		 ;
}

sub can_showHints {
	#my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem) = @_;
	
	return 1;
}

# gateway change here: add $submitAnswers as an optional additional argument
#   to be included if it's defined
sub can_showSolutions {
	my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem, 
	    $submitAnswers) = @_;
	my $authz = $self->r->authz;

# this is the same as can_showCorrectAnswers	
# gateway change here to allow correct answers to be viewed after all attempts
#   at a version are exhausted as well as if it's after the answer date
# $addOne allows us to count the current submission
	my $addOne = defined( $submitAnswers ) ? $submitAnswers : 0;
	my $maxAttempts = $Set->attempts_per_version();
	my $attemptsUsed = $Problem->num_correct+$Problem->num_incorrect+$addOne;

	return ( ( after( $Set->answer_date ) || 
		   $attemptsUsed >= $maxAttempts ) ||
		 $authz->hasPermissions($User->user_id, 
				"show_correct_answers_before_answer_date") );
}

# gateway change here: add $submitAnswers as an optional additional argument
#   to be included if it's defined
# we also allow for a version_last_attempt_time which is the time the set was
#   submitted; if that's present we use that instead of the current time to 
#   decide if we can record the answers.  this deals with the time between the 
#   submission time and the proctor authorization.
sub can_recordAnswers {
	my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem, 
	    $submitAnswers) = @_;
	my $authz = $self->r->authz;

	my $submitTime = ( defined($Set->version_last_attempt_time()) &&
			   $Set->version_last_attempt_time() ) ? 
			   $Set->version_last_attempt_time() : time();

	if ($User->user_id ne $EffectiveUser->user_id) {
		return $authz->hasPermissions($User->user_id, "record_answers_when_acting_as_student");
	}
	if (before($Set->open_date, $submitTime)) {
		return $authz->hasPermissions($User->user_id, "record_answers_before_open_date");
	} elsif (between($Set->open_date, $Set->due_date, $submitTime)) {

# gateway change here; we look at maximum attempts per version, not for the set,
#   to determine the number of attempts allowed
# $addOne allows us to count the current submission
	    my $addOne = defined( $submitAnswers ) ? $submitAnswers : 0;
	    my $max_attempts = $Set->attempts_per_version();
	    my $attempts_used = $Problem->num_correct+$Problem->num_incorrect+$addOne;
		if ($max_attempts == -1 or $attempts_used < $max_attempts) {
			return $authz->hasPermissions($User->user_id, "record_answers_after_open_date_with_attempts");
		} else {
			return $authz->hasPermissions($User->user_id, "record_answers_after_open_date_without_attempts");
		}
	} elsif (between($Set->due_date, $Set->answer_date, $submitTime)) {
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
	    $submitAnswers) = @_;
	my $authz = $self->r->authz;
	
	my $submitTime = ( defined($Set->version_last_attempt_time()) &&
			   $Set->version_last_attempt_time() ) ? 
			   $Set->version_last_attempt_time() : time();

	if (before($Set->open_date, $submitTime)) {
		return $authz->hasPermissions($User->user_id, "check_answers_before_open_date");
	} elsif (between($Set->open_date, $Set->due_date, $submitTime)) {

# gateway change here; we look at maximum attempts per version, not for the set,
#   to determine the number of attempts allowed
# $addOne allows us to count the current submission
	    my $addOne = defined( $submitAnswers ) ? $submitAnswers : 0;
	    my $max_attempts = $Set->attempts_per_version();
	    my $attempts_used = $Problem->num_correct+$Problem->num_incorrect+$addOne;

		if ($max_attempts == -1 or $attempts_used < $max_attempts) {
			return $authz->hasPermissions($User->user_id, "check_answers_after_open_date_with_attempts");
		} else {
			return $authz->hasPermissions($User->user_id, "check_answers_after_open_date_without_attempts");
		}
	} elsif (between($Set->due_date, $Set->answer_date, $submitTime)) {
		return $authz->hasPermissions($User->user_id, "check_answers_after_due_date");
	} elsif (after($Set->answer_date, $submitTime)) {
		return $authz->hasPermissions($User->user_id, "check_answers_after_answer_date");
	}
}

# Helper functions for calculating times
# gateway change here: we allow an optional additional argument to use as the
#   time to check rather than time()
sub before  { return (@_==2) ? $_[1] <= $_[0] : time <= $_[0] }
sub after   { return (@_==2) ? $_[1] >= $_[0] : time >= $_[0] }
sub between { my $t = (@_==3) ? $_[2] : time; return $t > $_[0] && $t < $_[1] }

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
		$resultsRows{'Results'} = '';
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
	    ($showSummary ? CGI::p({class=>'emphasis'},$summary) : "");
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
		return '<DIV CLASS="math">'.$tex.'</DIV>' ;
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

# this is a horrible hack to allow use of a javascript link to trigger
# the preview of the page: set previewAnswers to yes if either the 
# "previewAnswers" or "previewhack" inputs are set
    my $prevOr = $r->param('previewAnswers') || $r->param('previewHack');
    $r->param('previewAnswers', $prevOr) if ( defined( $prevOr ) );

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
    my $requestedVersion = ( $setName =~ /,v(\d+)$/ ) ? $1 : '';
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

# ok, get the version number if we should be required to stay with a version
    $requestedVersion = 
	$db->getUserSetVersionNumber($effectiveUserName, $setName)
	if ( ( $r->param("previewAnswers") || $r->param("checkAnswers") ||
	       $r->param("submitAnswers") ) && ! $requestedVersion );
    die("Requested version 0 when returning to problem?!") 
	if ( ( $r->param("previewAnswers") || $r->param("checkAnswers") ||
	       $r->param("submitAnswers") ) && ! $requestedVersion );

# FIXME should we be more subtle than just die()ing here?  c.f. Problem.pm 
#    $self->{invalidSet}  FIXME  (also, if getMergedSet() returns undef for
#    sets not assigned to users, why does Problem.pm resort to the logic
#    (grep /^$setName/, $db->listUserSets($effectiveUserName)) == 0)?
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

# to test for a proctored test, we need the set version, not the template,
#    which allows for a finished proctored test to be checked as an 
#    unproctored test.  so we get the versioned set here
    my $set = $db->getMergedVersionedSet($effectiveUserName, $setName, 
					 $requestedVersion);

    unless (defined $set) {
	my $userSetClass = $ce->{dbLayout}->{set_user}->{record};
	$set = global2user($userSetClass, $db->getGlobalSet($setName));
	die "set  $setName  not found."  unless $set;
	$set->user_id($effectiveUserName);
	$set->psvn('000');
	$set->set_id("$setName,v0"); # set to establish the version number only
    }
    my $setVersionName = $set->set_id();
    my ($setVersionNumber) = ($setVersionName =~ /.*,v(\d+)$/);

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
	    if ( ! WeBWorK::Authen->new($r, $ce, $db)->verifyProctor() );
    }

#################################
# assemble gateway parameters
#################################

# we get the open/close dates for the gateway from the template set.
# note $isOpen/Closed give the open/close dates for the gateway as a whole
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
#    problems will have the same number of attempts.
# note that this might not be defined, if the set hasn't been versioned 
#    to the user yet--this gets fixed when we assign the setVersion
    my $Problem = 
	$db->getMergedVersionedProblem($EffectiveUser->user_id, 
				       $setName, $setVersionName, 1);

# FIXME: is there any case where $maxAttemptsPerVersion shouldn't be 
#    finite?  For the moment we don't deal with this here  FIXME
    my $maxAttemptsPerVersion = $tmplSet->attempts_per_version();
    my $timeInterval          = $tmplSet->time_interval();
    my $versionsPerInterval   = $tmplSet->versions_per_interval();
    my $timeLimit             = $tmplSet->version_time_limit();

# these both work because every problem in the set must have the same
#    submission characteristics
    my $currentNumAttempts    = ( defined($Problem) ? $Problem->num_correct() +
				  $Problem->num_incorrect() : 0 );

# $maxAttempts turns into the maximum number of versions we can create; 
#    if $Problem isn't defined, we can't have made any attempts, so it 
#    doesn't matter
# FIXME: I'm using max_attempts == 0, instead of -1; does this matter?
    my $maxAttempts           = ( defined($Problem) && 
				  defined($Problem->max_attempts()) &&
				  $Problem->max_attempts() != -1 ? 
				  $Problem->max_attempts() : 0 );

# finding the number of versions per time interval is a little harder.  we
#    interpret the time interval as a rolling interval: that is, if we allow
#    two sets per day, that's two sets in any 24 hour period.  this is 
#    probably not what we really want, but it's more extensible to a
#    limitation like "one version per hour", and we can set it to two sets
#    per 12 hours for most "2ce daily" type applications
    my $timeNow = time();
    my $currentNumVersions = 0;  # this is the number of versions in the last
                                 #    time interval
    my $totalNumVersions = 0;

    if ( $setVersionNumber ) {
	my @setVersions = $db->getUserSetVersions($effectiveUserName,$setName,
						  $setVersionNumber);
	foreach ( @setVersions ) {
	    $totalNumVersions++;
	    $currentNumVersions++
		if ( $_->version_creation_time() > ($timeNow - $timeInterval) );
	}
    }

####################################
# new version creation conditional
####################################

    my $versionIsOpen = 0;  # can we do anything to this version?
    $timeNow -= 5;          # be safe with $timeNow

    if ( $isOpen && ! $isClosed ) {  # this makes sense, really

# if no specific version is requested, we can create a new one if 
#    need be
	if ( ! $requestedVersion ) { 
	    if ( 
		 ( ! $maxAttempts || $totalNumVersions < $maxAttempts )
		 &&
		 ( $setVersionNumber == 0 ||
		   ( 
		     ( $currentNumAttempts >= $maxAttemptsPerVersion 
		       ||
		       $timeNow >= $set->due_date )
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
		$setVersionName = "$setName,v$setVersionNumber";
		$set = $db->getMergedVersionedSet($userName,$setName,
						  $setVersionNumber);

		$Problem = $db->getMergedVersionedProblem($userName,$setName,
							  $setVersionName,1);
    # because we're creating this on the fly, it should be published
		$set->published(1);
    # set up creation time, open and due dates
		$set->version_creation_time( $timeNow );
		$set->open_date( $timeNow );
		$set->due_date( $timeNow+$timeLimit );
		$set->answer_date( $timeNow+$timeLimit );
		$set->version_last_attempt_time( 0 );
    # put this new info into the database.  note that this means that -all- of
    #    the merged information gets put back into the database.  as long as
    #    the version doesn't have a long lifespan, this is ok...
		$db->putVersionedUserSet( $set );

    # we have a new set version, so it's open
		$versionIsOpen = 1;

    # also reset the number of attempts for this set; this will be zero
		$currentNumAttempts = $Problem->num_correct() + 
		    $Problem->num_incorrect();

	    } elsif ( $maxAttempts && $totalNumVersions > $maxAttempts ) {
		$self->{invalidSet} = "No new versions of this assignment " .
		    "are available,\nbecause you have already taken the " .
		    "maximum number\nallowed.";

	    } elsif ( $currentNumAttempts < $maxAttemptsPerVersion &&
		      $timeNow < $set->due_date() ) {

		if ( between($set->open_date(), $set->due_date(), $timeNow) ) {
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
		if ( between($set->open_date(), $set->due_date(), $timeNow) ) {
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
	
####################################
# form processing
####################################

# *BeginPPM* ###################################################################

  # set options from form fields (see comment at top of file for names)
    my $displayMode      = $r->param("displayMode") || 
	                   $ce->{pg}->{options}->{displayMode};
    my $redisplay        = $r->param("redisplay");
    my $submitAnswers    = $r->param("submitAnswers");
    my $checkAnswers     = $r->param("checkAnswers");
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
	 checkAnswers       => $checkAnswers,
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
    my @args = ($User, $PermissionLevel, $EffectiveUser, $set, $Problem );
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
# process problems
####################################

    my @problemNumbers = $db->listUserProblems($effectiveUserName, 
					       $setVersionName);
    my @problems = ();
    my @pg_results = ();

    foreach my $problemNumber (sort {$a<=>$b } @problemNumbers) {
	my $ProblemN = $db->getMergedVersionedProblem($effectiveUserName,
						      $setName,
						      $setVersionName,
						      $problemNumber);

    # sticky answers are set up here
	if ( not ( $submitAnswers or $previewAnswers or $checkAnswers ) 
	     and $will{showOldAnswers} ) {
	    my %oldAnswers = decodeAnswers( $ProblemN->last_answer );
	    $formFields->{$_} = $oldAnswers{$_} foreach ( keys %oldAnswers );
	}
	push( @problems, $ProblemN );

    # this is the actual translation of each problem.  errors are stored in 
    #    @{$self->{errors}} in each case
	my $pg = $self->getProblemHTML( $self->{effectiveUser}, $setVersionName,
					$formFields, $ProblemN );
	push(@pg_results, $pg);
    }
    $self->{ra_problems} = \@problems;
    $self->{ra_pg_results}=\@pg_results;

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
		extra_params => ["editMode", "sourceFilePath"],
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

    my $timeNow = time();

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
	
    my $set = $self->{set};
    my $Problem = $self->{problem};
    my $permissionLevel = $self->{permissionLevel};
    my $submitAnswers = $self->{submitAnswers};
    my $checkAnswers = $self->{checkAnswers};
    my $previewAnswers = $self->{previewAnswers};
    my %want = %{ $self->{want} };
    my %can = %{ $self->{can} };
    my %must = %{ $self->{must} };
    my %will = %{ $self->{will} };
    my @problems = @{ $self->{ra_problems} };
    my @pg_results = @{ $self->{ra_pg_results} };
    my @pg_errors = @{ $self->{errors} };
    my $requestedVersion = $self->{requestedVersion};

    my $setVersionName  = $set->set_id;
    my ( $setName ) = ( $setVersionName =~ /(.*),v\d+$/ );
    my ( $versionNumber ) = ( $setVersionName =~ /.*,v(\d+)$/ );

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
	    my $pureProblem = $db->getUserProblem( $problems[$i]->user_id,
						   $setVersionName,
						   $problems[$i]->problem_id );
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
        # and store the last answer to the database
		$problems[$i]->last_answer( $answerString );
		$pureProblem->last_answer( $answerString );
		my $versioned = 1;
		$db->putUserProblem( $pureProblem, $versioned );

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

                    if ( $db->putUserProblem( $pureProblem, $versioned ) ) {
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
			$scoreRecordedMessage[$i] = "Your score was not " .
			    "recorded because you have exceeded the time " .
			    "limit for this test.";
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

# warn("in submitanswers conditional\n");

    } # end if submitAnswers conditional
    debug("end answer processing");

# additional set-level database manipulation: this is all for versioned 
#    sets/gateway tests
# we want to save the time that a set was submitted, and for proctored 
#    tests we want to reset the assignment type after a set is submitted 
#    for the last time so that it's possible to look at it later without 
#    getting proctor authorization
    if ( ( $submitAnswers && $will{recordAnswers} ) ||
	 ( ! $can{recordAnswersNextTime} && 
	   $set->assignment_type() eq 'proctored_gateway' ) ) {

# warn("in put set conditional\n");

	my $setName = $set->set_id();

	if ( $submitAnswers && $will{recordAnswers} ) {
	    $set->version_last_attempt_time( $timeNow );
	}
	if ( ! $can{recordAnswersNextTime} && 
	     $set->assignment_type() eq 'proctored_gateway' ) {
	    $set->assignment_type( 'gateway' );
	}
	$db->putVersionedUserSet( $set );
    }



####################################
# output
####################################

    my $overallScore = -1;  # is there a total score we should be reporting?
    my $totPossible = 0;
    if ( $submitAnswers ) {
	$overallScore = 0;
	foreach ( @pg_results ) {
	    $overallScore += $_->{state}->{recorded_score};
# FIXME  we need to worry about weight, both for score and total possible
#	    $totPossible += $_->value;
	    $totPossible++;
	}
    }

    if ( $overallScore > -1 ) {
	my $divClass = '';
	my $ansRecorded = 1;
	my $recdMsg = '';
	foreach ( @scoreRecordedMessage ) { 
	    if ( $_ ne 'Your score on this problem was recorded.' ) {
		$ansRecorded = 0;
		$recdMsg = $_;
		last;
	    }
	}
	if ( $ansRecorded ) {
	    $divClass = 'ResultsWithoutError';
	    $recdMsg = "Your score on this test was recorded.";
	} else {
	    $divClass = 'ResultsWithError';
# inherit saved value from above
	    $recdMsg = "Your score on this test was NOT recorded.  " . $recdMsg;
	}

	print CGI::div({class=>"$divClass"}, 
		       CGI::strong("Score on this attempt (test number " .
				   "$versionNumber) = " .
				   "$overallScore / $totPossible"),
		       CGI::br(),
		       CGI::strong("$recdMsg")),"\n\n";
    }

    if ( ! $can{recordAnswersNextTime} ) {
# if we can't record answers any more, then we're finished with this set
#   version.  print the appropriate message to that effect.
	print CGI::start_div({class=>"gwMessage"});
	my $mesg = ( $requestedVersion ) ? '' : 
	    ", because you have used all available attempts on it or " .
	    "because its time limit has expired.\n" .
	    "To attempt the set again, please try again after the time " .
	    "limit between versions has expired.\n";
	print CGI::p(CGI::strong("Note: this set version (number " .
			 "$versionNumber) can no longer be submitted for a" .
			 " grade"),"\n",$mesg,"\n",
	    "You may, however, check your answers to see what you did" .
	    " right or wrong."), "\n\n";
	print CGI::end_div();

    } else {

# FIXME: This assumes that there IS a time limit!
# FIXME: We need to drop this out gracefully if there isn't!
# set up a timer
	my $timeLeft = $set->due_date() - $timeNow;  # this is in seconds
	print CGI::start_div({class=>"gwTiming"});
	print CGI::startform({-name=>"gwtimer", -method=>"POST", 
			      -action=>$r->uri}), "\n";
	print CGI::hidden({-name=>"gwpagetimeleft", -value=>$timeLeft}), "\n";
	print CGI::strong("Time Remaining:");
	print CGI::textfield({-name=>'gwtime', -default=>0, -size=>8}),
	      CGI::strong("min:sec"), CGI::br(), "\n";
	print CGI::endform();
	if ( $timeLeft < 1 ) {
	    print CGI::span({-class=>"resultsWithError"}, 
			    CGI::b("You have less than 1 minute to ",
				   "complete this test.\n"));
	}
	print CGI::end_div();
#       print CGI::strong("Time Remaining:
#                         scalar(localtime($set->open_date())), 
#                         CGI::br(),"\nTime limit : ", 
#                         ($set->version_time_limit()/60), 
#                         " minutes (must be completed by: ", 
#                         scalar(localtime($set->due_date())), ")", CGI::br(), 
#                         "The current time is ", scalar(localtime())), "\n\n";
    }

# this is a brutal hack to get a URL that won't require a proctor login if
# we've submitted a proctored test for the last time.  above we've reset the 
# assignment_type in this case, so we'll use that to decide if we should 
# give a path to an unproctored test.  note that this substitution leaves 
# unproctored test URLs unchanged
    my $action = $r->uri();
    $action =~ s/proctored_quiz_mode/quiz_mode/ 
	if ( $set->assignment_type() eq 'gateway' );

    print CGI::startform({-name=>"gwquiz", -method=>"POST", -action=>$action}), $self->hidden_authen_fields,
        $self->hidden_proctor_authen_fields;

# FIXME RETURNTO
# this is a horrible hack to try and let us use a javascript link to 
# trigger previews
    print CGI::hidden({-name=>'previewHack', -value=>''}), CGI::br();
# and the text for the link
    my $jsprevlink = 'javascript:document.gwquiz.previewHack.value="1";' .
	'document.gwquiz.submit();';

# some links to easily move between problems
    my $jumpLinks = "Jump to problem: ";
    for my $i ( 0 .. $#pg_results ) {
	my $pn = $i+1;
	$jumpLinks .= "/ " . CGI::a({-href=>".", -onclick=>"jumpTo($pn);return false;"}, "$pn") . " /";
    }
    print CGI::p($jumpLinks,"\n");

# print out problems and attempt results, as appropriate
# note: args to attemptResults are (self,) $pg, $showAttemptAnswers,
#    $showCorrectAnswers, $showAttemptResults (and-ed with 
#    $showAttemptAnswers), $showSummary, $showAttemptPreview (or-ed with zero)
    my $problemNumber = 0;

# deal with ordering
    my @probOrder = ( 0 .. $#pg_results );

# there's a routine to do this somewhere, I think...
    if ( defined( $set->problem_randorder ) && $set->problem_randorder ) {
	my @newOrder = ();
# we need to keep the random order the same each time the set is loaded!
#    this requires either saving the order in the set definition, or being 
#    sure that the random seed that we use is the same each time the same 
#    set is called.  we'll do the latter by setting the seed to the psvn
#    of the problem set
	srand( $set->psvn );
	while ( @probOrder ) { 
	    my $i = int(rand(@probOrder));
	    push( @newOrder, $probOrder[$i] );
	    splice(@probOrder, $i, 1);
	}
	@probOrder = @newOrder;
    }
	
    foreach my $i ( 0 .. $#pg_results ) {
	my $pg = $pg_results[$probOrder[$i]];
	$problemNumber++;

	my $recordMessage = '';
	my $resultsTable = '';

	if ($pg->{flags}->{showPartialCorrectAnswers} >= 0 && $submitAnswers) {
	    if ( $scoreRecordedMessage[$probOrder[$i]] ne 
		 "Your score on this problem was recorded." ) {
		$recordMessage = CGI::span({class=>"resultsWithError"},
					   "ANSWERS NOT RECORDED --", 
			       $scoreRecordedMessage[$probOrder[$i]]);

	    }
	    $resultsTable = 
		$self->attemptResults($pg, 1, $will{showCorrectAnswers},
				      $pg->{flags}->{showPartialCorrectAnswers},
				      1, 1);
		
	} elsif ( $checkAnswers ) {
	    $recordMessage = CGI::span({class=>"resultsWithError"},
			   "ANSWERS ONLY CHECKED -- ", 
			   "ANSWERS NOT RECORDED");

	    $resultsTable = 
		$self->attemptResults($pg, 1, $will{showCorrectAnswers},
				      $pg->{flags}->{showPartialCorrectAnswers},
				      1, 1);

	} elsif ( $previewAnswers ) {
	    $recordMessage = CGI::span({class=>"resultsWithError"},
			   "PREVIEW ONLY -- ANSWERS NOT RECORDED");

	    $resultsTable = $self->attemptResults($pg, 1, 0, 0, 0, 1);
 
	}	    

	print CGI::start_div({class=>"gwProblem"});
	my $i1 = $i+1;
	print CGI::a({-name=>"#$i1"},"");
	print CGI::strong("Problem $problemNumber."), "\n", $recordMessage;
	print CGI::p($pg->{body_text}),
	      CGI::p($pg->{result}->{msg} ? CGI::b("Note: ") : "", 
		     CGI::i($pg->{result}->{msg}));
	print CGI::p({class=>"gwPreview"}, 
		     CGI::a({-href=>"$jsprevlink"}, "preview problems"));
# 	print CGI::end_div();

	print $resultsTable if $resultsTable; 

	print CGI::end_div();

	print "\n", CGI::hr(), "\n";
    }
    print CGI::p($jumpLinks, "\n");

    if ($can{showCorrectAnswers}) {
	print CGI::checkbox(-name    => "showCorrectAnswers",
			    -checked => $will{showCorrectAnswers},
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
	
    if ($can{showCorrectAnswers} or $can{showHints} or $can{showSolutions}) {
	print CGI::br();
    }

# Note: because of the way these things are grouped, the submit/et al buttons
# in this form are getting put outside of the problem div, while on a regular
# problem they'd fall inside.  Does this matter?  We shall see.
    print CGI::p( CGI::submit( -name=>"previewAnswers", 
			       -label=>"Preview Answers" ),
		  ($can{recordAnswersNextTime} ? 
		      CGI::submit( -name=>"submitAnswers",
				   -label=>"Grade Gateway" ) : " "),
		  ($can{checkAnswersNextTime} && ! $can{recordAnswersNextTime} ?
		      CGI::submit( -name=>"checkAnswers",
				   -label=>"Check Answers" ) : " ") );

    print CGI::endform();

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
    my ( $self, $EffectiveUser, $setVersionName, $formFields, 
	 $mergedProblem, $pgFile ) = @_;
# in:  $EffectiveUser is the effective user we're working as, $setVersionName
#      the versioned set name (setID,vN), %$formFields the form fields from
#      the input form that we need to worry about putting into the HTML we're
#      generating, and $mergedProblem and $pgFile are what we'd expect.
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
    my $set  = $db->getMergedVersionedSet( $EffectiveUser->user_id, 
					   $setVersionName );

# should this ever happen?  I think we should have die()ed way earlier than
#    this if the set doesn't exist, but it can't hurt to try and die() here 
#    too
    die "set $setVersionName for effectiveUser " . $EffectiveUser->user_id . 
	" not found." unless $set;

    my $psvn = $set->psvn();
    my ($setName) = ($setVersionName =~ /^(.*),v\d+/);

    if ( defined($mergedProblem) && $mergedProblem->problem_id ) {
# nothing needs to be done

    } elsif ($pgFile) {
	$mergedProblem = 
	    WeBWorK::DB::Record::UserProblem->new(
			set_id => $set->set_id,
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
	    set     => $setVersionName,
	    problem => $mergedProblem->problem_id,
	    message => $pg->{warnings},
	};
    }
	
    $self->{errors} = [];  # initialize this to no errors
    if ($pg->{flags}->{error_flag}) {
	push @{$self->{errors}}, {
	    set     => $setVersionName,
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
