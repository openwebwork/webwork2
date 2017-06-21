################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/GatewayQuiz.pm,v 1.54 2008/07/01 13:12:56 glarose Exp $
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
	ref2string makeTempDirectory path_is_subdir sortByName before after
	between wwRound is_restricted);  # use the ContentGenerator formatDateTime, not the version in Utils
use WeBWorK::DB::Utils qw(global2user user2global);
use WeBWorK::Utils::Tasks qw(fake_set fake_set_version fake_problem);
use WeBWorK::Debug;
use WeBWorK::ContentGenerator::Instructor qw(assignSetVersionToUser);
use WeBWorK::Authen::LTIAdvanced::SubmitGrade;
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
	return 0 unless $authz->hasPermissions($User->user_id,"can_show_old_answers");

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
	my $maxAttempts = $Set->attempts_per_version() || 0;
	my $attemptsUsed = $Problem->num_correct + $Problem->num_incorrect + 
	    $addOne || 0;

# this is complicated by trying to address hiding scores by problem---that
#    is, if $set->hide_score_by_problem and $set->hide_score are both set, 
#    then we should allow scores to be shown, but not show the score on 
#    any individual problem.  to deal with this, we make 
#    can_showCorrectAnswers give the least restrictive view of hiding, and 
#    then filter scores for the problems themselves later

#    showing correcrt answers but not showing scores doesn't make sense
#    so we should hide the correct answers if we aren not showing
#    scores GG.

	my $canShowScores = $Set->hide_score_by_problem eq 'N' &&
	  ( $Set->hide_score eq 'N' ||
	    ( $Set->hide_score eq 'BeforeAnswerDate' &&
	      after($tmplSet->answer_date) ) );

	return ( ( ( after( $Set->answer_date ) || 
		     ( $attemptsUsed >= $maxAttempts && 
		       $maxAttempts != 0 &&
		       $Set->due_date() == $Set->answer_date() ) ) ||
		   $authz->hasPermissions($User->user_id, 
				"show_correct_answers_before_answer_date") ) &&
		 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
		   $canShowScores ) );
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
	my $attempts_per_version = $Set->attempts_per_version() || 0;
	my $attemptsUsed = $Problem->num_correct+$Problem->num_incorrect+$addOne || 0;

# this is complicated by trying to address hiding scores by problem---that
#    is, if $set->hide_score_by_problem and $set->hide_score are both set, 
#    then we should allow scores to be shown, but not show the score on 
#    any individual problem.  to deal with this, we make can_showSolutions 
#    give the least restrictive view of hiding, and then filter scores for 
#    the problems themselves later
#    showing correcrt answers but not showing scores doesn't make sense
#    so we should hide the correct answers if we aren not showing
#    scores GG.

	my $canShowScores = $Set->hide_score_by_problem eq 'N' &&
	  ( $Set->hide_score eq 'N' ||
	    ( $Set->hide_score eq 'BeforeAnswerDate' &&
	      after($tmplSet->answer_date) ) );

	return ( ( ( after( $Set->answer_date ) || 
		     ( $attemptsUsed >= $attempts_per_version &&
		       $attempts_per_version != 0 &&
		       $Set->due_date() == $Set->answer_date() ) ) ||
		   $authz->hasPermissions($User->user_id, 
				"show_correct_answers_before_answer_date") ) &&
		 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
		   $canShowScores ) );
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

# easy first case: never record answers for undefined sets
	return 0 if ( $Set->set_id eq "Undefined_Set" );

	my $timeNow = ( defined($self->{timeNow}) ) ? $self->{timeNow} : time();
   # get the sag time after the due date in which we'll still grade the test
	my $grace = $self->{ce}->{gatewayGracePeriod};

	my $submitTime = ( defined($Set->version_last_attempt_time()) &&
			   $Set->version_last_attempt_time() ) ? 
			   $Set->version_last_attempt_time() : $timeNow;

	if ($User->user_id ne $EffectiveUser->user_id) {
		my $recordAsOther = $authz->hasPermissions($User->user_id, "record_answers_when_acting_as_student");
		my $recordVersionsAsOther = $authz->hasPermissions($User->user_id, "record_set_version_answers_when_acting_as_student");

		if ( $recordAsOther ) {
			return $recordAsOther;
		} elsif ( ! $recordVersionsAsOther ) {
			return $recordVersionsAsOther;
		}
		## if we're not allowed to record answers as another user,
		##    return that permission.  if we're allowed to record
		##    only set version answers, then we allow that between
		##    the open and close dates, and so drop out of this
		##    conditional to the usual one.
		## it isn't clear if this is the correct behavior, but I
		##    think it's probably reasonable.
	}

	if (before($Set->open_date, $submitTime)) {
		#    warn("case 0\n");
		return $authz->hasPermissions($User->user_id, "record_answers_before_open_date");
	} elsif (between($Set->open_date, ($Set->due_date + $grace), $submitTime)) {

# gateway change here; we look at maximum attempts per version, not for the set,
#   to determine the number of attempts allowed
# $addOne allows us to count the current submission
	    my $addOne = ( defined( $submitAnswers ) && $submitAnswers ) ? 
		1 : 0;
	    my $attempts_per_version = $Set->attempts_per_version() || 0;
	    my $attempts_used = $Problem->num_correct+$Problem->num_incorrect+$addOne;
		if ($attempts_per_version == 0 or $attempts_used < $attempts_per_version) {
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

	# if we can record answers then we dont need to be able to check them
	# unless we have that specific permission. 
	if ($self->can_recordAnswers($User,$PermissionLevel,$EffectiveUser,
				     $Set,$Problem,$tmplSet,$submitAnswers) 
	    && !$authz->hasPermissions($User->user_id, "can_check_and_submit_answers")) {
	    return 0;
	}

	my $timeNow = ( defined($self->{timeNow}) ) ? $self->{timeNow} : time();
   # get the sag time after the due date in which we'll still grade the test
	my $grace = $self->{ce}->{gatewayGracePeriod};
	
	my $submitTime = ( defined($Set->version_last_attempt_time()) &&
			   $Set->version_last_attempt_time() ) ? 
			   $Set->version_last_attempt_time() : $timeNow;

	# this is further complicated by trying to address hiding scores by 
	#    problem---that is, if $set->hide_score_by_problem and 
	#    $set->hide_score are both set, then we should allow scores to 
	#    be shown, but not show the score on any individual problem.  
	#    to deal with this, we use the least restrictive view of hiding 
	#    here, and then filter for the problems themselves later
	#    showing correcrt answers but not showing scores doesn't make sense
	#    so we should hide the correct answers if we aren not showing
	#    scores GG.

	my $canShowScores = $Set->hide_score_by_problem eq 'N' &&
	  ( $Set->hide_score eq 'N' ||
	    ( $Set->hide_score eq 'BeforeAnswerDate' &&
	      after($tmplSet->answer_date) ) );

	if (before($Set->open_date, $submitTime)) {
		return $authz->hasPermissions($User->user_id, "check_answers_before_open_date");
	} elsif (between($Set->open_date, ($Set->due_date + $grace), $submitTime)) {

# gateway change here; we look at maximum attempts per version, not for the set,
#   to determine the number of attempts allowed
# $addOne allows us to count the current submission
	    my $addOne = (defined( $submitAnswers ) && $submitAnswers) ? 
		1 : 0;
	    my $attempts_per_version = $Set->attempts_per_version()||0;
	    my $attempts_used = $Problem->num_correct+$Problem->num_incorrect+$addOne;

		if ($attempts_per_version == -1 or $attempts_used < $attempts_per_version) {
			return ( $authz->hasPermissions($User->user_id, "check_answers_after_open_date_with_attempts") &&
				 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
				   $canShowScores ) );
		} else {
			return ( $authz->hasPermissions($User->user_id, "check_answers_after_open_date_without_attempts") && 
				 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
				   $canShowScores ) );
		}
	} elsif (between(($Set->due_date + $grace), $Set->answer_date, $submitTime)) {
		return ( $authz->hasPermissions($User->user_id, "check_answers_after_due_date")  &&
			 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
			   $canShowScores ) );
	} elsif (after($Set->answer_date, $submitTime)) {
		return ( $authz->hasPermissions($User->user_id, "check_answers_after_answer_date") &&
			 ( $authz->hasPermissions($User->user_id, "view_hidden_work") ||
			   $canShowScores ) );
	}
}

sub can_showScore {
	my ($self, $User, $PermissionLevel, $EffectiveUser, $Set, $Problem,
	    $tmplSet, $submitAnswers) = @_;
	my $authz = $self->r->authz;

	my $timeNow = ( defined($self->{timeNow}) ) ? $self->{timeNow} : time();

	# address hiding scores by problem
	my $canShowScores = ( $Set->hide_score eq 'N' ||
			      ( $Set->hide_score eq 'BeforeAnswerDate' &&
				after($tmplSet->answer_date) ) );

	return( $authz->hasPermissions($User->user_id,"view_hidden_work") ||
		$canShowScores );
}

sub can_useMathView {
    my ($self, $User, $EffectiveUser, $Set, $Problem, $submitAnswers) = @_;
    my $ce= $self->r->ce;

    return $ce->{pg}->{specialPGEnvironmentVars}->{MathView};
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
	my $colorAnswers = $showAttemptResults;

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

	# for color coding the responses.
	$self->{correct_ids} = [] unless $self->{correct_ids};
	$self->{incorrect_ids} = [] unless $self->{incorrect_ids};

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

	my @rows;
	my @row;
	
	push @row, CGI::th({scope=>"col"},$r->maketext('Entered')) if $showAttemptAnswers;
	push @row, CGI::th({scope=>"col"},$r->maketext('Answer Preview')) if $showAttemptPreview;
	push @row, CGI::th({scope=>"col"},$r->maketext('Correct')) if $showCorrectAnswers;
	push @row, CGI::th({scope=>"col"},$r->maketext('Result')) if $showAttemptResults;
	push @row, CGI::th({scope=>"col"},$r->maketext('Messages')) if $showMessages;

	push @rows, CGI::Tr(@row);

	my $answerScore = 0;
	my $numCorrect = 0;
	my $numAns = 0;
	my $numBlanks = 0;
	my $numEssay = 0;
	foreach my $name (@answerNames) {

	    @row = ();
	    my $answerResult  = $pg->{answers}->{$name};
	    my $studentAnswer = $answerResult->{student_ans}//''; # original_student_ans
	    my $preview       = ($showAttemptPreview
				 ? $self->previewAnswer($answerResult, $imgGen)
				 : "");
	    my $correctAnswer = $answerResult->{correct_ans};
	    $answerScore = $answerResult->{score}//0;
	    my $answerMessage = $showMessages ? $answerResult->{ans_message} : "";
	    $numCorrect += $answerScore > 0;
	    $numEssay += ($answerResult->{type}//'') eq 'essay';
	    $numBlanks++ unless $studentAnswer =~/\S/ || $answerScore >= 1;
	    
	    my $resultString;
	    if ($answerScore >= 1) {
		$resultString = $r->maketext("correct");
		push @{$self->{correct_ids}}, $name if $colorAnswers;
	    } elsif (($answerResult->{type}//'') eq 'essay') {
		$resultString =  $r->maketext("Ungraded");
		$self->{essayFlag} = 1;
	    } elsif (defined($answerScore) and $answerScore == 0) {
		$resultString = $r->maketext("incorrect");
		push @{$self->{incorrect_ids}}, $name if $colorAnswers;
	    } else {
		$resultString =  $r->maketext("[_1]% correct", int($answerScore*100));
		push @{$self->{incorrect_ids}}, $name if $colorAnswers;
	    }
	    
	    push @row, CGI::td({scope=>"col"},$self->nbsp($studentAnswer)) if $showAttemptAnswers;
	    push @row, CGI::td({scope=>"col"}, $self->nbsp($preview)) if $showAttemptPreview;
	    push @row, CGI::td({scope=>"col"}, $self->nbsp($correctAnswer)) if $showCorrectAnswers;
	    push @row, CGI::td({scope=>"col"}, $self->nbsp($resultString)) if $showAttemptResults;
	    push @row, CGI::td({scope=>"col"},  $self->nbsp($answerMessage)) if $showMessages;
	    
	    push @rows, CGI::Tr(@row);
	    $numAns++;

	}

	# render equation images
	$imgGen->render(refresh => 1);

	my $summary = "";
	if (scalar @answerNames == 1) { #Here there is just one answer blank
		if ($numCorrect == 1) { #The student might be totally right
			$summary .= CGI::div({class=>"gwCorrect"},$r->maketext("This answer is correct."));
		} elsif ($self->{essayFlag}) {
			$summary .= $r->maketext("The answer will be graded later.");
		} elsif ($answerScore > 0 && $answerScore < 1) { #The student might be partially right
			$summary .= CGI::div({class=>"gwIncorrect"},$r->maketext("This answer is NOT completely correct."));
		} else { #The student might be completely wrong.
		 	 $summary .= CGI::div({class=>"gwIncorrect"},$r->maketext("This answer is NOT correct."));
		}
	} else {
		if ($numCorrect + $numEssay == scalar @answerNames) {
			$summary .= CGI::div({class=>"gwCorrect"},$r->maketext(
				$numEssay ? "All of the gradeable answers are correct." :
					    "All of the answers are correct."));
		} elsif ($numBlanks + $numEssay != scalar(@answerNames)) {
			$summary .= CGI::div({class=>"gwIncorrect"},$r->maketext(
				$answerScore > 0 && $answerScore < 1 ?
				      "At least one of these answers is NOT completely correct." :
				      "At least one of these answers is NOT correct."));
		}
	}

	return

	    CGI::table({-class=>"gwAttemptResults"}, @rows).

	    ($showSummary ? CGI::p({class=>'attemptResultsSummary'},$summary) : "");
}

sub handle_input_colors {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $site_url = $ce->{webworkURLs}{htdocs};

	return if $self->{previewAnswers};  # don't color previewed answers

	# The color.js file, which uses javascript to color the input fields based on whether they are correct or incorrect.
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/InputColor/color.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript"}),
	        "color_inputs([\n  ",
		  join(",\n  ",map {"'$_'"} @{$self->{correct_ids}||[]}),
	        "\n],[\n  ",
                  join(",\n  ",map {"'$_'"} @{$self->{incorrect_ids}||[]}),
	        "]\n);",
	      CGI::end_script();
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
	} elsif ($displayMode eq "images") {
		$imgGen->add($tex);
	} elsif ($displayMode eq "MathJax") {
		return '<span class="MathJax_Preview">[math]</span><script type="math/tex; mode=display">'.$tex.'</script>';
	} elsif ($displayMode eq "jsMath") {
		$tex =~ s/&/&amp;/g; $tex =~ s/</&lt;/g; $tex =~ s/>/&gt;/g;
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

	# should we allow a new version to be created when
	#    acting as a user?
	my $verCreateOK = ( defined( $r->param('createnew_ok') ) ) ?
		$r->param('createnew_ok') : 0;

	# user checks
	my $User = $db->getUser($userName);
	die "record for user $userName (real user) does not exist." 
		unless defined $User;
	my $EffectiveUser = $db->getUser($effectiveUserName);
	die "record for user $effectiveUserName (effective user) does " .
		"not exist." unless defined $EffectiveUser;

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
# gateway set and problem collection
###################################

# we need the template (user) set, the merged set-version, and a 
#    problem from the set to be able to test whether we're creating a 
#    new set version.  assemble these
	my ( $tmplSet, $set, $Problem ) = ( 0, 0, 0 );

# if the set comes in as "Undefined_Set", then we're trying/editing a 
#    single problem in a set, and so create a fake set with which to work
#    if the user has the authorization to do that.
	if ( $setName eq "Undefined_Set" ) {

		# make sure these are defined
		$requestedVersion = 1;
		$self->{assignment_type} = 'gateway';

		if ( ! $authz->hasPermissions($userName,
					      "modify_problem_sets") ) {
			$self->{invalidSet} = "You do not have the " .
				"authorization level required to view/" .
				"edit undefined sets.";

			# define these so that we can drop through
			#    to report the error in body()
			$tmplSet = fake_set( $db );
			$set     = fake_set_version( $db );
			$Problem = fake_problem( $db );
		} else {
	# in this case we're creating a fake set from the input, so
	#    the input must include a source file.
			if ( ! $r->param("sourceFilePath") ) {
				$self->{invalidSet} = "An Undefined_Set " .
					"was requested, but no source " .
					"file for the contained problem " .
					"was provided.";

				# define these so that we can drop through
				#    to report the error in body()
				$tmplSet = fake_set( $db );
				$set     = fake_set_version( $db );
				$Problem = fake_problem( $db );

			} else {
				my $sourceFPath = $r->param("sourceFilePath");
				die("sourceFilePath is unsafe!") unless
					path_is_subdir($sourceFPath,
						$ce->{courseDirs}->{templates},
						1);

				$tmplSet = fake_set( $db );
				$set     = fake_set_version( $db );
				$Problem = fake_problem( $db );

				$tmplSet->assignment_type( "gateway" );
				$tmplSet->attempts_per_version( 0 );
				$tmplSet->time_interval( 0 );
				$tmplSet->versions_per_interval(1);
				$tmplSet->version_time_limit( 0 );
				$tmplSet->version_creation_time( time() );
				$tmplSet->problem_randorder( 0 );
				$tmplSet->problems_per_page( 1 );
				$tmplSet->hide_score('N');
				$tmplSet->hide_score_by_problem('N');
				$tmplSet->hide_work('N');
				$tmplSet->time_limit_cap('0');
				$tmplSet->restrict_ip('No');

				$set->assignment_type( "gateway" );
				$set->time_interval( 0 );
				$set->versions_per_interval(1);
				$set->version_time_limit( 0 );
				$set->version_creation_time( time() );
				$set->time_limit_cap('0');

				$Problem->problem_id(1);
				$Problem->source_file($sourceFPath);
				$Problem->user_id($effectiveUserName);
				$Problem->value(1);
				$Problem->problem_seed( $r->param("problemSeed") ) if ( $r->param("problemSeed") );
			}
		}
	} else {

# get template set: the non-versioned set that's assigned to the user
#    if this fails/failed in authz->checkSet, then $self->{invalidSet} is
#    set
		$tmplSet = $db->getMergedSet( $effectiveUserName, $setName );
		
		$self->{isOpen} = $authz->hasPermissions($userName, "view_unopened_sets") || (time >= $tmplSet->open_date && !(
			  $ce->{options}{enableConditionalRelease} && 
			  is_restricted($db, $tmplSet, $effectiveUserName)));
		
		die("You do not have permission to view unopened sets") unless $self->{isOpen};	
		

	# now we know that we're in a gateway test, save the assignment test 
	#    for the processing of proctor keys for graded proctored tests; 
	#    if we failed to get the set from the database, we store a fake 
	#    value here to be able to continue
		$self->{'assignment_type'} = $tmplSet->assignment_type() ||
			'gateway';

	# next, get the latest (current) version of the set if we don't have a 
	#     requested version number
		my @allVersionIds = $db->listSetVersions($effectiveUserName,
							 $setName);
		my $latestVersion = (@allVersionIds ? $allVersionIds[-1] : 0);

	# double check that any requested version makes sense
		$requestedVersion = $latestVersion 
		  if ( $requestedVersion !~ /^\d+$/ ||
		       $requestedVersion > $latestVersion ||
		       $requestedVersion < 0 );

		die("No requested version when returning to problem?!") 
			if ( ( $r->param("previewAnswers") ||
			       $r->param("checkAnswers") ||
			       $r->param("submitAnswers") ||
			       $r->param("newPage") ) && ! $requestedVersion );

	# to test for a proctored test, we need the set version, not the 
	#    template, to allow a finished proctored test to be checked as an 
	#    unproctored test.  so we get the versioned set here
		if ( $requestedVersion ) {
	# if a specific set version was requested, it was stored in the $authz
	#    object when we did the set check
			$set = $db->getMergedSetVersion($effectiveUserName,
							$setName,
							$requestedVersion);
		} elsif ( $latestVersion ) {
	# otherwise, if there's a current version, which we take to be the 
	#    latest version taken, we use that
			$set = $db->getMergedSetVersion($effectiveUserName,
							$setName,
							$latestVersion);
		} else {
	# and if neither of those work, get a dummy set so that we have 
	#    something to work with
			my $userSetClass = $ce->{dbLayout}->{set_version}->{record};
# FIXME RETURN TO: should this be global2version?
			$set = global2user($userSetClass, 
					   $db->getGlobalSet($setName));
			die "set  $setName  not found."  unless $set;
			$set->user_id($effectiveUserName);
			$set->psvn('000');
			$set->set_id("$setName");  # redundant?
			$set->version_id(0);
		}
	}
	my $setVersionNumber = ($set) ? $set->version_id() : 0;

	#################################
	# assemble gateway parameters
	#################################

	# we get the open/close dates for the gateway from the template set.
	#    note $isOpen/Closed give the open/close dates for the gateway
	#    as a whole (that is, the merged user|global set).  because the
	#    set could be bad (if $self->{invalidSet}), we check ->open_date
	#    before actually testing the date
	my $isOpen = $tmplSet && $tmplSet->open_date && 
		( after($tmplSet->open_date()) || 
		  $authz->hasPermissions($userName, "view_unopened_sets") );

	# FIXME for $isClosed, "record_answers_after_due_date" isn't quite
	#    the right description, but it seems reasonable
	my $isClosed = $tmplSet && $tmplSet->due_date &&
		( after($tmplSet->due_date()) &&
		  ! $authz->hasPermissions($userName, "record_answers_after_due_date") );

	# to determine if we need a new version, we need to know whether this 
	#    version exceeds the number of attempts per version.  (among other
	#    things,) the number of attempts is a property of the problem, so 
	#    get a problem to check that.  note that for a gateway/quiz all 
	#    problems will have the same number of attempts.  This means that 
	#    if the set doesn't have any problems we're up a creek, so check 
	#    for that here and bail if it's the case
	my @setPNum = $setName eq "Undefined_Set" ? ( 1 ) :
		$db->listUserProblems($EffectiveUser->user_id, $setName);
	die("Set $setName contains no problems.") if ( ! @setPNum );

	# if we assigned a fake problem above, $Problem is already defined.
	#    otherwise, we get the Problem, or define it to be undefined if
	#    the set hasn't been versioned to the user yet--this gets fixed
	#    when we assign the setVersion
	if ( ! $Problem ) {
		$Problem = $setVersionNumber ?
			$db->getMergedProblemVersion($EffectiveUser->user_id,
				$setName, $setVersionNumber, $setPNum[0]) :
				undef;
	}

	# note that having $maxAttemptsPerVersion set to an infinite/0 value is
	#    nonsensical; if we did that, why have versions? (might want to do it for one individual?)
	# Its actually a good thing for "repeatable" practice sets
	my $maxAttemptsPerVersion = $tmplSet->attempts_per_version() || 0;
	my $timeInterval          = $tmplSet->time_interval() || 0;
	my $versionsPerInterval   = $tmplSet->versions_per_interval() || 0;
	my $timeLimit             = $tmplSet->version_time_limit() || 0;

	# what happens if someone didn't set one of these?  I think this can
	# happen if we're handed a malformed set, where the values in the
	# database are null.
	$timeInterval = 0 if (! defined($timeInterval) || $timeInterval eq '');
	$versionsPerInterval = 0 if (! defined($versionsPerInterval) ||
				     $versionsPerInterval eq '');

	# every problem in the set must have the same submission characteristics
	my $currentNumAttempts    = ( defined($Problem) && 
				      $Problem->num_correct() ne '' ) ? 
				      $Problem->num_correct() +
				      $Problem->num_incorrect() : 0;

	# $maxAttempts turns into the maximum number of versions we can create;
	#    if $Problem isn't defined, we can't have made any attempts, so it
	#    doesn't matter
	my $maxAttempts           = ( defined($Problem) && 
				      defined($Problem->max_attempts()) &&
				      $Problem->max_attempts() ) ? 
				      $Problem->max_attempts() : -1;

	# finding the number of versions per time interval is a little harder.
	#    we interpret the time interval as a rolling interval: that is,
	#    if we allow two sets per day, that's two sets in any 24 hour
	#    period.  this is probably not what we really want, but it's
	#    more extensible to a limitation like "one version per hour",
	#    and we can set it to two sets per 12 hours for most "2ce daily"
	#    type applications
	my $timeNow = time();
	my $grace = $ce->{gatewayGracePeriod};

	my $currentNumVersions = 0;  # this is the number of versions in the
	                             #    time interval
	my $totalNumVersions = 0;

	# we don't need to check this if $self->{invalidSet} is already set,
	#    or if we're working with an Undefined_Set
	if ( $setVersionNumber && ! $self->{invalidSet} &&
	     $setName ne "Undefined_Set" ) {
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

	# recall $isOpen = timeNow > openDate [for the merged userset] and 
	#    $isClosed = timeNow > dueDate [for the merged userset]
	#    again, if $self->{invalidSet} is already set, we don't need to 
	#    to check this
	if ( $isOpen && ! $isClosed && ! $self->{invalidSet} ) {

	# if no specific version is requested, we can create a new one if 
	#    need be
		if ( ! $requestedVersion ) {
			if ( ( $maxAttempts == -1 ||
			       $totalNumVersions < $maxAttempts )
			     &&
			     ( $setVersionNumber == 0 ||
			       (
				 ( $currentNumAttempts>=$maxAttemptsPerVersion
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
			        ( $authz->hasPermissions($userName, "record_answers_when_acting_as_student") ||
				  ( $authz->hasPermissions($userName, "create_new_set_version_when_acting_as_student") && $verCreateOK ) ) )

			   ) {
				# assign set, get the right name, version 
				#    number, etc., and redefine the $set 
				#    and $Problem we're working with
				my $setTmpl = $db->getUserSet($effectiveUserName,$setName);
				WeBWorK::ContentGenerator::Instructor::assignSetVersionToUser($self, $effectiveUserName, $setTmpl);
				$setVersionNumber++;

				# get a clean version of the set to save,
				#    and the merged version to use in the 
				#    rest of the routine
				my $cleanSet = $db->getSetVersion(
					$effectiveUserName, $setName,
					$setVersionNumber);
				$set = $db->getMergedSetVersion(
					$effectiveUserName, $setName,
					$setVersionNumber );

				$Problem = $db->getMergedProblemVersion(
					$effectiveUserName, $setName, 
					$setVersionNumber, 1);

				# because we're creating this on the fly, 
				#    it should be visible
				$set->visible(1);
				# set up creation time, open and due dates
				my $ansOffset = $set->answer_date() - 
					$set->due_date();
				$set->version_creation_time( $timeNow );
				$set->open_date( $timeNow );
				# figure out the due date, taking into account
				#    any time limit cap
				my $dueTime = 
				    ( $timeLimit == 0 || ($set->time_limit_cap &&
				      $timeNow+$timeLimit > $set->due_date) ) ?
				      $set->due_date : $timeNow+$timeLimit;

				$set->due_date( $dueTime );
				$set->answer_date($set->due_date + $ansOffset);
				$set->version_last_attempt_time( 0 );

				# put this new info into the database.  we 
				#    put back that data which we need for the
				#    version, and leave blank any information
				#    that we'd like to inherit from the user
				#    set or global set.  we set the data which
				#    determines if a set is open, because we
				#    don't want the set version to reopen after
				#    it's complete
				$cleanSet->version_creation_time( $set->version_creation_time );
				$cleanSet->open_date( $set->open_date );
				$cleanSet->due_date( $set->due_date );
				$cleanSet->answer_date( $set->answer_date );
				$cleanSet->version_last_attempt_time( $set->version_last_attempt_time );
				$cleanSet->version_time_limit( $set->version_time_limit );
				$cleanSet->attempts_per_version( $set->attempts_per_version );
				$cleanSet->assignment_type( $set->assignment_type );
				$db->putSetVersion( $cleanSet );

				# we have a new set version, so it's open
				$versionIsOpen = 1;

				# also reset the number of attempts for this 
				#    set to zero
				$currentNumAttempts = 0;

			} elsif ( $maxAttempts != -1 && 
				  $totalNumVersions > $maxAttempts ) {
				$self->{invalidSet} = "No new versions of " .
					"this assignment are available,\n" .
					"because you have already taken the " .
					"maximum number\nallowed.";

			} elsif ( $effectiveUserName ne $userName &&
				  $authz->hasPermissions($userName, "create_new_set_version_when_acting_as_student") ) {
				$self->{invalidSet} = "User " .
					"$effectiveUserName is being acted " .
					"as.  If you continue, you will " .
					"create a new version of this set " .
					"for that user, which will count " .
					"against their allowed maximum " .
					"number of versions for the current " .
					"time interval.  IN GENERAL, THIS " .
					"IS NOT WHAT YOU WANT TO DO.  " .
					"Please be sure that you want to " .
					"do this before clicking the \"" .
					"Create new set version\" link " .
					"below.  Alternately, PRESS THE " .
					"\"BACK\" BUTTON and continue.";
				$self->{invalidVersionCreation} = 1;

			} elsif ( $effectiveUserName ne $userName ) {
				$self->{invalidSet} = "User " .
					"$effectiveUserName is being acted " .
					"as.  When acting as another user, " .
					"new versions of the set cannot be " .
					"created.";
				$self->{invalidVersionCreation} = 2;

			} elsif (($maxAttemptsPerVersion == 0 || $currentNumAttempts < $maxAttemptsPerVersion) &&
				 $timeNow < $set->due_date() + $grace ) {
				if ( between($set->open_date(), 
					     $set->due_date() + $grace, 
					     $timeNow) ) {
					$versionIsOpen = 1;
				} else {
					$versionIsOpen = 0;  # redundant
					$self->{invalidSet} = "No new " .
						" versions of this assignment" .
						" are available,\nbecause the" .
						" set is not open or its time" .
						" limit has expired.\n";
				}

			} elsif ($versionsPerInterval && 
				 ($currentNumVersions >= $versionsPerInterval)){
				$self->{invalidSet} = "You have already taken" .
					" all available versions of this\n" .
					"test in the current time interval.  " .
					"You may take the\ntest again after " .
					"the time interval has expired.";

			}

		} else {
		# (we're still in the $isOpen && ! $isClosed conditional here)
		#    if a specific version is requested, then we only check to 
		#    see if it's open
			if ( 
			     ( $currentNumAttempts < $maxAttemptsPerVersion )
			     && 
			     ( $effectiveUserName eq $userName ||
			       $authz->hasPermissions($userName,
						      "record_set_version_answers_when_acting_as_student") )
			   ) {
				if ( between($set->open_date(), 
					     $set->due_date() + $grace,
					     $timeNow) ) {
					$versionIsOpen = 1;
				} else {
					$versionIsOpen = 0;  # redundant
				}
			}
		}

	# closed set, with attempt at a new one
	} elsif ( ! $self->{invalidSet} && ! $requestedVersion ) {
		$self->{invalidSet} = "This set is closed.  No new set " .
			"versions may be taken.";
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

	# also get the current page, if it's given
	my $currentPage = $r->param("currentPage") || 1;

	# this is a hack manage previewing a page.  we set previewAnswers to 
	# yes if either of the following are true:
	#  1. the "previewAnswers" input is set (the "preview" button was
	#     clicked), or 
	#  2. the "previewHack" input is set (a preview link was used)
	my $prevOr = $r->param('previewAnswers') || $r->param('previewHack');
	$r->param('previewAnswers', $prevOr) if ( defined( $prevOr ) );

        # [This section lifted from Problem.pm] ##############################

	# set options from form fields (see comment at top of file for names)
	my $displayMode      = $User->displayMode || 
		$ce->{pg}->{options}->{displayMode};
	my $redisplay        = $r->param("redisplay");
	my $submitAnswers    = $r->param("submitAnswers") // 0;
	my $checkAnswers     = $r->param("checkAnswers") // 0;
	my $previewAnswers   = $r->param("previewAnswers") // 0;

	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };

	$self->{displayMode}    = $displayMode;
	$self->{redisplay}      = $redisplay;
	$self->{submitAnswers}  = $submitAnswers;
	$self->{checkAnswers}   = $checkAnswers;
	$self->{previewAnswers} = $previewAnswers;
	$self->{formFields}     = $formFields;

	# now that we've set all the necessary variables quit out if the set or 
	#    problem is invalid

	return if $self->{invalidSet} || $self->{invalidProblem};

	# [End lifted section] ###############################################

	####################################
	# permissions
	####################################

	# bail without doing anything if the set isn't yet open for this user
	if ( ! ( $self->{isOpen} ||
		 $authz->hasPermissions($userName,"view_unopened_sets") ) ) {
		$self->{invalidSet} = "This set is not yet open.";
		return;
	}

	# what does the user want to do?
	my %want = 
	    (showOldAnswers     => $User->showOldAnswers ne '' ?
	     $User->showOldAnswers : $ce->{pg}->{options}->{showOldAnswers},
	     showCorrectAnswers => ($r->param("showCorrectAnswers") || 
 	                       	   $ce->{pg}->{options}->{showCorrectAnswers}) &&
                                   ($submitAnswers || $checkAnswers),
	     showHints          => $r->param("showHints") || 
		                   $ce->{pg}->{options}->{showHints},
	     showSolutions      => ($r->param("showSolutions") || 
		                   $ce->{pg}->{options}->{showSolutions}) &&
                                   ($submitAnswers || $checkAnswers),
	     recordAnswers      => $submitAnswers && !$authz->hasPermissions($userName, 
							    "avoid_recording_answers"),
	# we also want to check answers if we were checking answers and are
	#    switching between pages
	     checkAnswers       => $checkAnswers,
	     useMathView        => $User->useMathView ne '' ? $User->useMathView : $ce->{pg}->{options}->{useMathView},
	     );

	# are certain options enforced?
	my %must = 
	    (showOldAnswers     => 0,
	     showCorrectAnswers => 0,
	     showHints          => 0,
	     showSolutions      => 0,
	     recordAnswers      => 0,
	     checkAnswers       => 0,
	     useMathView        => 0,
	     );

	# does the user have permission to use certain options?
	my @args = ($User, $PermissionLevel, $EffectiveUser, $set, $Problem, 
		    $tmplSet);
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
	     useMathView              => $self->can_useMathView(@args)
	     );

	# final values for options
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
##    $can{showSolutions} &&= $pg->{flags}->{solutionExists};
	
	$self->{want} = \%want;
	$self->{must} = \%must;
	$self->{can}  = \%can;
	$self->{will} = \%will;


	####################################
	# set up problem numbering and multipage variables
	####################################

	my @problemNumbers;
	if ( $setName eq "Undefined_Set" ) {
		@problemNumbers = ( 1 );
	} else {
		@problemNumbers = $db->listProblemVersions($effectiveUserName,
							   $setName,
							   $setVersionNumber);
	}

	# to speed up processing of long (multi-page) tests, we want to only 
	#    translate those problems that are being submitted or are currently 
	#    being displayed.  so work out here which problems are on the 
	#    current page.
	my ( $numPages, $pageNumber, $numProbPerPage ) = ( 1, 0, 0 );
	my ( $startProb, $endProb ) = ( 0, $#problemNumbers );

	# update startProb and endProb for multipage tests
	if ( defined($set->problems_per_page) && $set->problems_per_page ) {
		$numProbPerPage = $set->problems_per_page;
		$pageNumber = ($newPage) ? $newPage : $currentPage;

		$numPages = scalar(@problemNumbers)/$numProbPerPage;
		$numPages = int($numPages) + 1 if (int($numPages) != $numPages);

		$startProb = ($pageNumber - 1)*$numProbPerPage;
		$startProb = 0 if ( $startProb < 0 || 
				    $startProb > $#problemNumbers );
		$endProb = ($startProb + $numProbPerPage > $#problemNumbers) ? 
		    $#problemNumbers : $startProb + $numProbPerPage - 1;
	}


	# set up problem list for randomly ordered tests
	my @probOrder = (0..$#problemNumbers);

	# there's a routine to do this somewhere, I think...
	if ( $set->problem_randorder ) {
		my @newOrder = ();
	# we need to keep the random order the same each time the set is loaded!
	#    this requires either saving the order in the set definition, or 
	#    being sure that the random seed that we use is the same each time 
	#    the same set is called.  we'll do the latter by setting the seed 
	#    to the psvn of the problem set.  we use a local PGrandom object 
	#    to avoid mucking with the system seed.
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

	####################################
	# process problems
	####################################

	my @problems = ();
	my @pg_results = ();
	# pg errors are stored here; initialize it to empty to start
	$self->{errors} = [ ];

	# process the problems as needed
	my @mergedProblems;
	if ( $setName eq "Undefined_Set" ) {
		@mergedProblems = ( $Problem );
	} else {
		@mergedProblems = $db->getAllMergedProblemVersions($effectiveUserName, $setName, $setVersionNumber);
	}

	foreach my $problemNumber (sort {$a<=>$b } @problemNumbers) {

		# pIndex numbers from zero
		my $pIndex = $problemNumber - 1;
		if ( ! defined( $mergedProblems[$pIndex] ) ) {
			$self->{invalidSet} = "One or more of the problems " .
				"in this set have not been assigned to you.";
			return;
		}
		my $ProblemN = $mergedProblems[$pIndex];

		# sticky answers are set up here
		if ( not ( $submitAnswers or $previewAnswers or $checkAnswers or
			   $newPage ) and $will{showOldAnswers} ) {

			my %oldAnswers = decodeAnswers( $ProblemN->last_answer);
			$formFields->{$_} = $oldAnswers{$_} foreach ( keys %oldAnswers );
		}
		
		push( @problems, $ProblemN );

		# if we don't have to translate this problem, just save the 
		#    problem number
		my $pg = $problemNumber;
		# this is the actual translation of each problem.  errors are 
		#    stored in @{$self->{errors}} in each case
		if ( (grep /^$pIndex$/, @probsToDisplay) || $submitAnswers ) {
			$pg = $self->getProblemHTML($self->{effectiveUser},
						    $set, $formFields,
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

sub head {
        my ($self) = @_;
        my $ce = $self->r->ce;
        my $webwork_htdocs_url = $ce->{webwork_htdocs_url};
        return $self->{pg}->{head_text} if defined($self->{pg}->{head_text});
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

sub body {
	my $self = shift();
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	my $user = $r->param('user');
	my $effectiveUser = $r->param('effectiveUser');
	my $courseID = $urlpath->arg("courseID");

	# report everything with the same time that we started with
	my $timeNow = $self->{timeNow};
	my $grace = $ce->{gatewayGracePeriod};

	#########################################
	# preliminary error checking and output
	#########################################

	# if $self->{invalidSet} is set, then we have an error and should
	#    just bail with the appropriate error message

	if ($self->{invalidSet} || $self->{invalidProblem}) {
	    # delete any proctor keys that are floating around
		if ( $self->{'assignment_type'} eq 'proctored_gateway' ) {
			my $proctorID = $r->param('proctor_user');
			if ( $proctorID ) {
				eval{ $db->deleteKey("$effectiveUser,$proctorID"); };
				eval{ $db->deleteKey("$effectiveUser,$proctorID,g"); };
			}
		}

		my $newlink = '';
		my $usernote = '';
		if ( defined( $self->{invalidVersionCreation} ) &&
		     $self->{invalidVersionCreation} == 1 ) {
			my $gwpage = $urlpath->newFromModule($urlpath->module,$r,
				courseID=>$urlpath->arg("courseID"),
				setID=>$urlpath->arg("setID"));
			my $link = $self->systemLink( $gwpage,
				params=>{effectiveUser => $effectiveUser,
					 user => $user,
					 createnew_ok => 1} );
			$newlink = CGI::p(CGI::a({href=>$link},
				"Create new set version."));
			$usernote = " (acted as by $user)";
		} elsif ( defined( $self->{invalidVersionCreation} ) &&
			  $self->{invalidVersionCreation} == 2 ) {
			$usernote = " (acted as by $user)";
		}

		return CGI::div({class=>"ResultsWithError"},
				CGI::p("The selected problem set (" . 
				       $urlpath->arg("setID") . ") is not " .
				       "a valid set for $effectiveUser" .
				       "$usernote:"),
				CGI::p($self->{invalidSet}),
				$newlink);
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
	my $setVName = "$setName,v$versionNumber";
	my $numProbPerPage = $set->problems_per_page;

	# translation errors -- we use the same output routine as Problem.pm, 
	#    but play around to allow for errors on multiple translations 
	#    because we have an array of problems to deal with.
	if ( @pg_errors ) {
		my $errorNum = 1;
		my ( $message, $context ) = ( '', '' );
		foreach ( @pg_errors ) {

			$message .= "$errorNum. " if ( @pg_errors > 1 );
			$message .= $_->{message} . CGI::br() . "\n";

			$context .= CGI::p((@pg_errors > 1? "$errorNum.": '') . 
					   $_->{context} ) . "\n\n" . 
					   CGI::hr() . "\n\n";
		}
		return $self->errorOutput( $message, $context );
	}

	####################################
	# answer processing
	####################################

	debug("begin answer processing"); 

	my @scoreRecordedMessage = ('') x scalar(@problems);
	my $LTIGradeResult = -1;

	####################################
	# save results to database as appropriate
	####################################

	if ( $submitAnswers || ( ($previewAnswers || $newPage) &&
				 $can{recordAnswers} ) ) {
		# if we're submitting answers, we have to save the problems
		#    to the database.
		# if we're previewing or switching pages and can still
		#    record answers, we save the last answer for future 
		#    reference

		# first, if we're submitting answers for a proctored exam, 
		#    we want to delete the proctor keys that authorized 
		#    that grading, so that it isn't possible to just log 
		#    in and take another proctored test without getting 
		#    reauthorized
		if ( $submitAnswers && 
		     $self->{'assignment_type'} eq 'proctored_gateway' ) {
			my $proctorID = $r->param('proctor_user');

			# if we don't have attempts left, delete all
			#    proctor keys for this user
			if ( $set->attempts_per_version - 1 -
			     $Problem->num_correct - $Problem->num_incorrect 
			     <= 0 ) {	
				eval{ $db->deleteAllProctorKeys( $effectiveUser ); };
			} else {
				# otherwise, delete only the grading key
				eval{ $db->deleteKey("$effectiveUser,$proctorID,g"); };
				# in this case we may have a past, login, 
				#    proctor key that we can keep so that 
				#    we don't have to get another login to
				#    continue working the test
				if ( $r->param("past_proctor_user") &&
				     $r->param("past_proctor_key") ) {
					$r->param("proctor_user", $r->param("past_proctor_user"));
					$r->param("proctor_key", $r->param("past_proctor_key"));
				}
			}
			# this is unsubtle, but we'd rather not have bogus 
			#    keys sitting around
			if ( $@ ) {
				die("ERROR RESETTING PROCTOR GRADING KEY(S): $@\n");
			}

		}
		
		# The following arrays cache results obtained in the two passes through 
		# the collection of problems in the quiz
		# This might save some time.
		# This refactoring hasn't taken place yet
		# because I don't yet understand why the ordering 
		# for creating past answers was chosen as it is, different from creating sticky answers
#		my @answerString = (); 
#		my @encoded_ans_string = ();
#		my @scores = ();
#		my @isEssay = ();
		
		my @pureProblems = $db->getAllProblemVersions($effectiveUser,
							      $setName,
							      $versionNumber);
		foreach my $i ( 0 .. $#problems ) {  # process each problem
			# this code is essentially that from Problem.pm
# begin problem loop for sticky answers
			my $pureProblem = $pureProblems[$i];

			# store answers in problem for sticky answers later
			# my %answersToStore;

			# we have to be a little careful about getting the
			#    answers that we're saving, because we don't have
			#    a pg_results object for all problems if we're not 
			#    submitting
			my %answerHash = ();
			my @answer_order = ();
			my $encoded_ans_string;
			if ( ref( $pg_results[$i] ) ) {
# 				%answerHash = %{$pg_results[$i]->{answers}};
# 				$answersToStore{$_} = $self->{formFields}->{$_} 
# 					foreach (keys %answerHash);
# 				# check for extra answers that slipped 
# 				#    by---e.g. for matrices, and get them 
# 				#    from the original input form
# 				my @extra_answer_names = 
# 				    @{ $pg_results[$i]->{flags}->{KEPT_EXTRA_ANSWERS} };
# 				$answersToStore{$_} = 
# 				    $self->{formFields}->{$_} foreach (@extra_answer_names);
# 				@answer_order = 
# 				    ( @{$pg_results[$i]->{flags}->{ANSWER_ENTRY_ORDER}}, 
# 				      @extra_answer_names );
                my ($answerString, $scores,$isEssay); #not used here
				($answerString,$encoded_ans_string,$scores,$isEssay) =
				WeBWorK::ContentGenerator::ProblemUtil::ProblemUtil::create_ans_str_from_responses(
					$self, $pg_results[$i]
				);  # ref($self) eq WeBWorK::ContentGenerator::Problem
					# ref($pg) eq "WeBWorK::PG::Local";
			} else {
				my $prefix = sprintf('Q%04d_',$i+1);
				my @fields = sort grep {/^$prefix/} (keys %{$self->{formFields}});
				my %answersToStore = map {$_ => $self->{formFields}->{$_}} @fields;
				my @answer_order = @fields;
				$encoded_ans_string = encodeAnswers( %answersToStore, 
 							  @answer_order );
 						
			}
# 				my $answerString = encodeAnswers( %answersToStore, 
# 							  @answer_order );
# 			
			# and get the last answer 
			$problems[$i]->last_answer( $encoded_ans_string );
			$pureProblem->last_answer( $encoded_ans_string );

			# next, store the state in the database if that makes 
			#    sense
			if ( $submitAnswers && $will{recordAnswers} ) {
  $problems[$i]->status(wwRound(2,$pg_results[$i]->{state}->{recorded_score}));
  $problems[$i]->attempted(1);
  $problems[$i]->num_correct($pg_results[$i]->{state}->{num_of_correct_ans});
  $problems[$i]->num_incorrect($pg_results[$i]->{state}->{num_of_incorrect_ans});
  $pureProblem->status(wwRound(2,$pg_results[$i]->{state}->{recorded_score}));
  $pureProblem->attempted(1);
  $pureProblem->num_correct($pg_results[$i]->{state}->{num_of_correct_ans});
  $pureProblem->num_incorrect($pg_results[$i]->{state}->{num_of_incorrect_ans});

				if ( $db->putProblemVersion( $pureProblem ) ) {
					$scoreRecordedMessage[$i] = $r->maketext("Your score on this problem was recorded.");
				} else {
					$scoreRecordedMessage[$i] = $r->maketext("Your score was not recorded because there was a failure in storing the problem record to the database.");
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
			} elsif ( $submitAnswers ) {
				# this is the case where we submitted answers
				#    but can't save them; report an error 
				#    message

				if ($self->{isClosed}) {
					$scoreRecordedMessage[$i] = $r->maketext("Your score was not recorded because this problem set version is not open.");
				} elsif ( $problems[$i]->num_correct + 
					  $problems[$i]->num_incorrect >= 
					  $set->attempts_per_version ) {
					$scoreRecordedMessage[$i] = $r->maketext("Your score was not recorded because you have no attempts remaining on this set version.");
				} elsif ( ! $self->{versionIsOpen} ) {
					my $endTime = ( $set->version_last_attempt_time ) ? $set->version_last_attempt_time : $timeNow;
					if ($endTime > $set->due_date && 
					    $endTime < $set->due_date + $grace){
						$endTime = $set->due_date;
					}
					my $elapsed = 
					    int(($endTime - $set->open_date)/0.6 + 0.5)/100;
					# we assume that allowed is an even 
					#    number of minutes
					my $allowed = ($set->due_date - $set->open_date)/60;
					$scoreRecordedMessage[$i] = $r->maketext("Your score was not recorded because you have exceeded the time limit for this test. (Time taken: [_1] min; allowed: [_2] min.)", $elapsed, $allowed);
				} else {
					$scoreRecordedMessage[$i] = $r->maketext("Your score was not recorded.");
				}
			} else {
				# finally, we must be previewing or switching
				#    pages.  save only the last answer for the
				#    problems
				$db->putProblemVersion( $pureProblem );
			}
		} # end loop through problems
# end loop through problems for sticky answer 

		#Try to update the student score on the LMS
		# if that option is enabled.
		my $LTIGradeMode = $self->{ce}->{LTIGradeMode} // '';
		if ($submitAnswers && $will{recordAnswers} && $LTIGradeMode
		   && $self->{ce}->{LTIGradeOnSubmit}) {
		  my $grader = WeBWorK::Authen::LTIAdvanced::SubmitGrade->new($r);
		  if ($LTIGradeMode eq 'course') {
		    $LTIGradeResult = $grader->submit_course_grade($effectiveUser);
		  } elsif ($LTIGradeMode eq 'homework') {
		    $LTIGradeResult = $grader->submit_set_grade($effectiveUser, $setName);
		  }
		}
		
		## finally, log student answers if we're submitting, 
		##    previewing, or changing pages, provided that we can 
		##    record answers.  note that this will log an overtime 
		##    submission (or any case where someone submits the 
		##    test, or spoofs a request to submit a test)

		my $answer_log = 
			$self->{ce}->{courseFiles}->{logs}->{'answer_log'};

		# this is carried over from Problem.pm
		if ( defined( $answer_log ) ) {
			foreach my $i ( 0 .. $#problems ) {
# begin problem loop for passed answers
				my $answerString = '';
				my $scores = '';
				my $isEssay = 0;
				# note that we store these answers in the 
				#    order that they are presented, not the 
				#    actual problem order
				if ( ref( $pg_results[$probOrder[$i]] ) ) {
					my %answerHash = %{ $pg_results[$probOrder[$i]]->{answers} };
# 					foreach ( sortByName(undef, keys %answerHash) ) {
# 						my $sAns = defined($answerHash{$_}->{original_student_ans}) ? $answerHash{$_}->{original_student_ans} : '';
# 						$answerString .= $sAns . "\t";
# 						$scores .= $answerHash{$_}->{score}>=1 ? "1" : "0" if ( $submitAnswers );
# 					}
                   	my ($encoded_ans_string, ); #not used here
					($answerString,$encoded_ans_string,$scores,$isEssay) =
					WeBWorK::ContentGenerator::ProblemUtil::ProblemUtil::create_ans_str_from_responses(
						$self, $pg_results[$probOrder[$i]]
					);  # ref($self) eq WeBWorK::ContentGenerator::Problem
						# ref($pg) eq "WeBWorK::PG::Local";
					$answerString =~ s/\t+$/\t/;
				} else {
					my $prefix = sprintf('Q%04d_', ($probOrder[$i]+1));
					my @fields = sort grep {/^$prefix/} (keys %{$self->{formFields}});
					foreach ( @fields ) {
						$answerString .= $self->{formFields}->{$_} . "\t";
						$scores .= $self->{formFields}->{"probstatus" . ($probOrder[$i]+1)} >= 1 ? "1" : "0" if ( $submitAnswers );
					}
					$answerString =~ s/\t+$/\t/;
				}
				
				
		# Prefix answer string with submission type
				my $answerPrefix;
				if ( $submitAnswers ) { 
					$answerPrefix = "[submit] ";  
				} elsif ( $previewAnswers ) { 
					$answerPrefix = "[preview] "; 
				} else { 
					$answerPrefix = "[newPage] "; 
				}

				if ( ! $answerString || 
				     $answerString =~ /^\t$/ ) {
					$answerString = "$answerPrefix" . 
						"No answer entered\t";
				} else {
					$answerString = "$answerPrefix" .
						"$answerString";
				}
				
		#Write to courseLog
				writeCourseLog( $self->{ce}, "answer_log",
						join("", '|', 
						     $problems[$i]->user_id,
						     '|', $setVName,
						     '|', ($i+1), '|', $scores, 
						     "\t$timeNow\t",
						     "$answerString"), 
						);
		#add to PastAnswer db
				my $pastAnswer = $db->newPastAnswer();
				$pastAnswer->course_id($courseID);
				$pastAnswer->user_id($problems[$i]->user_id);
				$pastAnswer->set_id($setVName);
				$pastAnswer->problem_id($problems[$i]->problem_id);
				$pastAnswer->timestamp($timeNow);
				$pastAnswer->scores($scores);
				$pastAnswer->answer_string($answerString);
				$pastAnswer->source_file($problems[$i]->source_file);
				
				$db->addPastAnswer($pastAnswer);

			}
		}
	}
	debug("end answer processing");
# end problem loop
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
	#     first submission occurs after the due_date
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
	# again, we save only parameters that are determine access to the
	#    set version
		my $cleanSet = $db->getSetVersion($effectiveUser,
						$setName,
						$versionNumber);
		$cleanSet->assignment_type( $set->assignment_type );
		$cleanSet->version_last_attempt_time( $set->version_last_attempt_time );
		$db->putSetVersion( $cleanSet );
	}


	####################################
	# output
	####################################

	# some convenient output variables
	my $canShowProblemScores = $can{showScore} && 
	    ($set->hide_score_by_problem eq 'N' ||
	     $authz->hasPermissions($user, "view_hidden_work"));

	my $canShowWork = $authz->hasPermissions($user, "view_hidden_work") || ($set->hide_work eq 'N' || ($set->hide_work eq 'BeforeAnswerDate' && $timeNow>$tmplSet->answer_date));

	# for nicer answer checking on multi-page tests, we want to keep 
	#    track of any changes that someone made to a different page, 
	#    and what their score was.  we use @probStatus to do this.  we 
	#    initialize this to any known scores, and then update this when 
	#    calculating the score for checked or submitted tests
	my @probStatus = ();
	# we also figure out recorded score for the set, if any, and score 
	#    on this attempt
	my $recordedScore = 0;
	my $totPossible = 0;
	foreach ( @problems ) {
		my $pv = ( $_->value() ) ? $_->value() : 1;
		$totPossible += $pv;
		$recordedScore += $_->status*$pv if (defined($_->status));
		push( @probStatus, ($r->param("probstatus" . $_->problem_id) ||
				    $_->status || 0) );
	}

	# to get the attempt score, we have to figure out what the score on 
	#    each part of each problem is, and multiply the total for the 
	#    problem by the weight (value) of the problem.  to make things 
	#    even more interesting, we are avoiding translating all of the 
	#    problems when checking answers
	my $attemptScore = 0;
	if ( $will{recordAnswers} || $will{checkAnswers} ) {
		my $i=0;
		foreach my $pg ( @pg_results ) {
			my $pValue = $problems[$i]->value() ? $problems[$i]->value() : 1;
			my $pScore = 0;
			my $numParts = 0;
			if ( ref( $pg ) ) {  # then we have a pg object
###
				$pScore = $pg->{state}->{recorded_score};
				$probStatus[$i] = $pScore;
				$numParts = 1;
###

			} else {
				# if we don't have a pg object, use any known 
				#    problem status (this defaults to zero)
				$pScore = $probStatus[$i];
			}
			$attemptScore += $pScore*$pValue/($numParts > 0 ? $numParts : 1);
			$i++;
		}
	}

	# we want to print elapsed and allowed times; allowed is easy
	my $allowed = sprintf( "%.0f", 10*($set->due_date - $set->open_date)/6 )/100;
	# elapsed is a little harder; we're counting to the last submission 
	#    time, or to the current time if the test hasn't been submitted, 
	#    and if the submission fell in the grace period round it to the 
	#    due_date
	my $exceededAllowedTime = 0;
	my $endTime = ( $set->version_last_attempt_time ) ? 
	    $set->version_last_attempt_time : $timeNow;
	if ( $endTime > $set->due_date && $endTime < $set->due_date + $grace ) {
		$endTime = $set->due_date;
	} elsif ( $endTime > $set->due_date ) {
		$exceededAllowedTime = 1;
	}
	my $elapsedTime = int(($endTime - $set->open_date)/0.6 + 0.5)/100;

	# also get number of remaining attempts (important for sets with 
	#    multiple attempts per version)
	my $numLeft = ($set->attempts_per_version ||0 )- $Problem->num_correct - 
		$Problem->num_incorrect - 
		($submitAnswers && $will{recordAnswers} ? 1 : 0);
	my $attemptNumber = $Problem->num_correct + $Problem->num_incorrect;

	# a handy noun for when referring to a test
	my $testNoun = (( $set->attempts_per_version || 0 ) > 1) ? $r->maketext("submission") : $r->maketext("test");
	my $testNounNum = ( ( $set->attempts_per_version ||0 ) > 1 ) ? 
		$r->maketext("submission (test [_1])",$versionNumber) : $r->maketext("test ([_1])",$versionNumber);

	##### start output of test headers: 
	##### display information about recorded and checked scores
	$attemptScore = wwRound(2,$attemptScore);
	if ( $will{recordAnswers} ) {
		# the distinction between $can{recordAnswers} and ! $can{} has 
		#    been dealt with above and recorded in @scoreRecordedMessage
		my $divClass = 'ResultsWithoutError';
		my $recdMsg = '';
		foreach ( @scoreRecordedMessage ) {
			if ($_ !~ $r->maketext('Your score on this problem was recorded.')) {
				$recdMsg = $_;
				$divClass = 'ResultsWithError';
				last;
			}
		}
		print CGI::start_div({class=>$divClass});

		if ( $recdMsg ) {
			# then there was an error when saving the results
			print CGI::strong($r->maketext("Your score on this [_1] was NOT recorded.",$testNounNum),
					  $recdMsg), CGI::br();
		} else {
			# no error; print recorded message
			print CGI::strong($r->maketext("Your score on this [_1] WAS recorded.",$testNounNum)), 
			  CGI::br();

			# and show the score if we're allowed to do that
			if ( $can{showScore} ) {
			  print CGI::strong($r->maketext("Your score on this [_1] is [_2]/[_3].", $testNoun,$attemptScore,$totPossible));
			} else {
			  if ($set->hide_score eq 'BeforeAnswerDate') {
			    print $r->maketext("(Your score on this [_1] is not available until [_2].)",$testNoun, $self->formatDateTime($set->answer_date));
			  } else {
			    print $r->maketext("(Your score on this [_1] is not available.)",$testNoun);
			  }
			}

			
			# Print a message if we are trying to send the score to
			# an LMS
			if ($LTIGradeResult != -1) {
			  print CGI::br();
			  print $LTIGradeResult ?
			    $r->maketext("Your score was successfully sent to the LMS") :
			    $r->maketext("Your score was not successfully sent to the LMS");
			}
			
		}

		# finally, if there is another, recorded message, print that 
		#    too so that we know what's going on
		print CGI::end_div();
		if ( $set->attempts_per_version > 1 && $attemptNumber > 1 &&
		     $recordedScore != $attemptScore && $can{showScore} ) {
			print CGI::start_div({class=>'gwMessage'});
			my $recScore = wwRound(2,$recordedScore);
			print $r->maketext("The recorded score for this test is  [_1]/[_2].",$recScore,$totPossible);
			print CGI::end_div();
		}

	} elsif ( $will{checkAnswers} ) {
		if ( $can{showScore} ) {
			print CGI::start_div({class=>'gwMessage'});
			print CGI::strong($r->maketext("Your score on this (checked, not recorded) submission is [_1]/[_2].",$attemptScore,$totPossible)), 
				CGI::br();
			my $recScore = wwRound(2,$recordedScore);
			print $r->maketext("The recorded score for this test is [_1]/[_2].",$recScore, $totPossible);
			print CGI::end_div();
		}
	}

	##### remaining output of test headers:
	##### display timer or information about elapsed time, "printme" link,
	##### and information about any recorded score if not submitAnswers or 
	##### checkAnswers
	if ( $can{recordAnswersNextTime} ) {

		# print timer
		my $timeLeft = $set->due_date() - $timeNow;  # this is in secs
		# dont print the timer if there is over 24 hours because its kind of silly
		if ($timeLeft < 86400) {
		    print CGI::div({-id=>"gwTimer"},"\n");
		    print CGI::start_form({-name=>"gwTimeData", -method=>"POST",
					  -action=>$r->uri});
		    print CGI::hidden({-name=>"serverTime", -value=>$timeNow}), 
		    "\n";
		    print CGI::hidden({-name=>"serverDueTime", 
				       -value=>$set->due_date()}), "\n";
		    print CGI::end_form();
		}
		if ( $timeLeft < 1 && $timeLeft > 0 &&
		     ! $authz->hasPermissions($user, "record_answers_when_acting_as_student")) {
			print CGI::span({-class=>"resultsWithError"}, 
					CGI::b($r->maketext("You have less than 1 minute to complete this test.")."\n"));
		} elsif ( $timeLeft <= 0 &&
			  ! $authz->hasPermissions($user, "record_answers_when_acting_as_student") ) {
			print CGI::span({-class=>"resultsWithError"}, 
					CGI::b($r->maketext("You are out of time.  Press grade now!")."\n"));
		}
		# if there are multiple attempts per version, indicate the 
		#    number remaining, and if we've submitted a multiple 
		#    attempt multi-page test, show the score on the previous
		#    submission
		if ( $set->attempts_per_version > 1 ) {
			print CGI::em($r->maketext("You have [_1] attempt(s) remaining on this test.",$numLeft));
			if ( $numLeft < $set->attempts_per_version &&
			     $numPages > 1 &&
			     $can{showScore} ) {
				print CGI::start_div({-id=>"gwScoreSummary"}),
					CGI::strong({},$r->maketext("Score summary for last submit:"));
				print CGI::start_table();
				print CGI::Tr({},CGI::th({-align=>"left"},$r->maketext("Prob")), CGI::td(""), CGI::th($r->maketext("Status")), CGI::td(""), CGI::th($r->maketext("Result")));
				for ( my $i=0; $i<@probStatus; $i++ ) {
					print CGI::Tr({},
						CGI::td({},[($i+1),"",int(100*$probStatus[$probOrder[$i]]+0.5) . "%","", $probStatus[$probOrder[$i]] == 1 ? $r->maketext("Correct") : $r->maketext("Incorrect")]));
				}
				print CGI::end_table(), CGI::end_div();
			}
		}
	} else {
		if ( ! $checkAnswers && ! $submitAnswers ) {
			if ( $can{showScore} ) {
			    print CGI::start_div({class=>'gwMessage'});
			    
			    my $scMsg = $r->maketext("Your recorded score on this test (number [_1]) is [_2]/[_3].", $versionNumber, wwRound(2,$recordedScore), $totPossible);
			    if ( $exceededAllowedTime && 
				 $recordedScore == 0 ) {
				$scMsg .= $r->maketext("You exceeded the allowed time.");
			    } else {
				$scMsg .= ".  ";
			    }
			    print CGI::strong($scMsg), CGI::br();
			    print CGI::end_div();
			}
		}

		if ( $set->version_last_attempt_time ) {
			print CGI::start_div({class=>'gwMessage'});
			print $r->maketext("Time taken on test: [_1] min ([_2] min allowed).",$elapsedTime,$allowed);
			print CGI::end_div();
		} elsif ( $exceededAllowedTime && $recordedScore != 0 ) {
			print CGI::start_div({class=>'gwMessage'});
			print $r->maketext("(This test is overtime because it was not submitted in the allowed time.)");
			print CGI::end_div();
		}

		if ( $canShowWork && $set->set_id ne "Undefined_Set" ) {
			print $r->maketext("The test (which is number [_1]) may  no longer be submitted for a grade.",$versionNumber);
			print "" . (($can{showScore}) ? $r->maketext("You may still check your answers.") : ".") ;

			# print a "printme" link if we're allowed to see our 
			#    work
			my $link = $ce->{webworkURLs}->{root} . '/' . 
				$ce->{courseName} . '/hardcopy/' . 
				$set->set_id . ',v' . $set->version_id . '/?' . 
				$self->url_authen_args;
			my $printmsg = CGI::div({-class=>'gwPrintMe'}, 
						CGI::a({-href=>$link}, 
						       $r->maketext("Print Test")));
			print $printmsg;
		}
	}

	# this is a hack to get a URL that won't require a proctor login if 
	#    we've submitted a proctored test for the last time.  above we've 
	#    reset the assignment_type in this case, so we'll use that to 
	#    decide if we should give a path to an unproctored test.
	my $action = $r->uri();
	$action =~ s/proctored_quiz_mode/quiz_mode/ 
		if ( $set->assignment_type() eq 'gateway' );
	# we also want to be sure that if we're in a set, the 'action' in the 
	#    form points us to the same set.  
	my $setname = $set->set_id;
	my $setvnum = $set->version_id;
	$action =~ s/(quiz_mode\/$setname)\/?$/$1,v$setvnum\//;  #"

	# now, we print out the rest of the page if we're not hiding submitted
	#    answers
	if ( ! $can{recordAnswersNextTime} && ! $canShowWork ) {
		print CGI::start_div({class=>"gwProblem"});
		if ( $set->hide_work eq 'BeforeAnswerDate' ) {
		  print CGI::strong($r->maketext("Completed results for this assignment are not available until [_1]",$self->formatDateTime($set->answer_date)));
		} else {
		  print CGI::strong($r->maketext("Completed results for this assignment are not available."));
		}
		print CGI::end_div();

	# else: we're not hiding answers
	} else {

		print CGI::start_form({-name=>"gwquiz", -method=>"POST", 
				      -action=>$action}), 
			$self->hidden_authen_fields, 
			$self->hidden_proctor_authen_fields;

	# hacks to use a javascript link to trigger previews and jump to 
	#    subsequent pages of a multipage test
		print CGI::hidden({-name=>'previewHack', -value=>''}), 
			CGI::br();
		if ( $numProbPerPage && $numPages > 1 ) { 
			print CGI::hidden({-name=>'newPage', -value=>''});
			print CGI::hidden({-name=>'currentPage',
					   -value=>$pageNumber});
		}

	# the link for a preview; for a multipage test, this also needs to 
	#    keep track of what page we're on
		my $jsprevlink = 'javascript:document.gwquiz.previewHack.value="1";';
		$jsprevlink .= "document.gwquiz.newPage.value=\"$pageNumber\";"
			if ( $numProbPerPage && $numPages > 1 );
		$jsprevlink .= 'document.gwquiz.submit();';

	# set up links between problems and, for multi-page tests, pages
		my $jumpLinks = '';
		my $probRow = [ ];
		for my $i ( 0 .. $#pg_results ) {
	    
			my $pn = $i + 1;
			if ( $i >= $startProb && $i <= $endProb ) {
				push(@$probRow, CGI::b(" [ ")) if ($i == $startProb);
				push( @$probRow, " &nbsp;" . 
				      CGI::a({-href=>"#", 
					      -onclick=>"jumpTo($pn);return false;"},
					     "$pn") . "&nbsp; " );
				push(@$probRow, CGI::b(" ] ")) if ($i == $endProb);
			} elsif ( ! ($i % $numProbPerPage) ) {
				push(@$probRow, " &nbsp;&nbsp; ", 
				     " &nbsp;&nbsp; ", " &nbsp;&nbsp; ");
			}
		}
		if ( $numProbPerPage && $numPages > 1 ) {
			my $pageRow = [ CGI::th( {scope=>"row"}, CGI::b($r->maketext('Jump to Page:'))),
					CGI::td(CGI::b(' [ ' )) ];
			for my $i ( 1 .. $numPages ) {
				my $pn = ( $i == $pageNumber ) ? $i : 
				    CGI::a({-href=>'javascript:' .
						"document.gwquiz.newPage.value=\"$i\";" .
						'document.gwquiz.submit();'}, 
					   "&nbsp;$i&nbsp;");

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
							  -align=>'center'}, 
							 $pn) );
				push( @$pageRow, CGI::td( [CGI::b(' ] '), 
							   CGI::b(' [ ')] ) )
					if ( $i != $numPages );
			}
			push( @$pageRow, CGI::td(CGI::b(' ] ')) );
			$jumpLinks = CGI::table( {class=>"gwNavigation", role=>"navigation", 'aria-label'=>"problem navigation"}, CGI::Tr(@$pageRow), 
						 CGI::Tr( CGI::th(CGI::b($r->maketext("Jump to Problem:"))), CGI::td($probRow) ) );
		} else {
			$jumpLinks = CGI::table({class=>"gwNavigation", role=>"navigation", 'aria-label'=>"problem navigation"}, CGI::Tr(CGI::th(CGI::b($r->maketext("Jump to Problem:"))), CGI::td($probRow) ) );
		}
	
		print $jumpLinks,"\n";

	# print out problems and attempt results, as appropriate
	# note: args to attemptResults are (self,) $pg, $showAttemptAnswers,
	#    $showCorrectAnswers, $showAttemptResults (and-ed with 
	#    $showAttemptAnswers), $showSummary, $showAttemptPreview (or-ed 
	#    with zero)
		my $problemNumber = 0;

		foreach my $i ( 0 .. $#pg_results ) {
			my $pg = $pg_results[$probOrder[$i]];
			$problemNumber++;

			if ( $i >= $startProb && $i <= $endProb ) { 
				
				my $recordMessage = '';
				my $resultsTable = '';

				if ($pg->{flags}->{showPartialCorrectAnswers}>=0 && $submitAnswers){
					if ( $scoreRecordedMessage[$probOrder[$i]] !~ 
					     $r->maketext("Your score on this problem was recorded.") ) {
						$recordMessage = CGI::span({class=>"resultsWithError"},
									   $r->maketext("ANSWERS NOT RECORDED --"), 
									   $scoreRecordedMessage[$probOrder[$i]]);

					}
					$resultsTable = 
					    $self->attemptResults($pg, 1, $will{showCorrectAnswers},
								  $pg->{flags}->{showPartialCorrectAnswers} && $canShowProblemScores,
								  $canShowProblemScores, 1);
					
				} elsif ( $will{checkAnswers} ) {
					$recordMessage = CGI::span({class=>"resultsWithError"},
								   $r->maketext("ANSWERS ONLY CHECKED -- "), 
								   $r->maketext("ANSWERS NOT RECORDED"));
					
					$resultsTable = 
					    $self->attemptResults($pg, 1, $will{showCorrectAnswers},
								  $pg->{flags}->{showPartialCorrectAnswers} && $canShowProblemScores,
								  $canShowProblemScores, 1);

				} elsif ( $previewAnswers ) {
					$recordMessage = 
					    CGI::span({class=>"resultsWithError"},
						      $r->maketext("PREVIEW ONLY -- ANSWERS NOT RECORDED"));
					$resultsTable = $self->attemptResults($pg, 1, 0, 0, 0, 1);
 
				}	    
				
				print CGI::start_div({class=>"gwProblem"});
				my $i1 = $i+1;
				my $pv = $problems[$probOrder[$i]]->value() ? $problems[$probOrder[$i]]->value() : 1;
				print CGI::div({-id=>"prob$i"},"");
				print CGI::h2($r->maketext("Problem [_1].",$problemNumber)), 
					$recordMessage;
				print CGI::div({class=>"problem-content"}, $pg->{body_text}),
				CGI::p($pg->{result}->{msg} ? 
				       CGI::b($r->maketext("Note")).': ' : "", 
				       CGI::i($pg->{result}->{msg}));
				print CGI::p({class=>"gwPreview"}, 
					     CGI::a({-href=>"$jsprevlink"}, 
						    $r->maketext("preview answers")));

				print $resultsTable if $resultsTable; 

				print CGI::end_div();
				# finally, store the problem status for 
				#    continued attempts recording
				my $pNum = $probOrder[$i] + 1;
				print CGI::hidden({-name=>"probstatus$pNum",
						   -value=>$probStatus[$probOrder[$i]]});

				print "\n", CGI::hr(), "\n";
			} else {
				my $i1 = $i+1;
				# keep the jump to anchors so that jumping to 
				#    problem number 6 still works, even if 
				#    we're viewing only problems 5-7, etc.
				print CGI::div({-id=>"prob$i"},""), "\n";
				# and print out hidden fields with the current 
				#    last answers
				my $curr_prefix = 'Q' . sprintf("%04d", $probOrder[$i]+1) . '_';
				my @curr_fields = grep /^$curr_prefix/, keys %{$self->{formFields}};
				foreach my $curr_field ( @curr_fields ) {
 					foreach ( split(/\0/, $self->{formFields}->{$curr_field} // '') ) {
 						print CGI::hidden({-name=>$curr_field, 
 							   	   -value=>$_});
 					}
				}
				# finally, store the problem status for 
				#    continued attempts recording
				my $pNum = $probOrder[$i] + 1;
				print CGI::hidden({-name=>"probstatus$pNum",
						   -value=>$probStatus[$probOrder[$i]]});
# 	    my $probid = 'Q' . sprintf("%04d", $probOrder[$i]+1) . "_AnSwEr1";
# 	    my $probval = $self->{formFields}->{$probid};
# 	    print CGI::hidden({-name=>$probid, -value=>$probval}), "\n";
			}
		}

		$self->handle_input_colors;

		print CGI::div($jumpLinks, "\n");
		print "\n",CGI::hr(), "\n";

		if ($can{showCorrectAnswers}) {
			print CGI::checkbox(-name   =>"showCorrectAnswers",
#				-checked => $will{showCorrectAnswers},
					    -checked=>$want{showCorrectAnswers},
					    -label  =>$r->maketext("Show correct answers"),
					    );
		}
		if ($can{showSolutions}) {
			print CGI::checkbox(-name    => "showSolutions",
					    -checked => $will{showSolutions},
					    -label   => $r->maketext("Show Solutions"),
					    );
		}

		print CGI::p( CGI::submit( -name=>"previewAnswers", 
					   -label=>$r->maketext("Preview Test") ),
			      ($can{recordAnswersNextTime} ? 
			       CGI::submit( -name=>"submitAnswers",
					    -label=>$r->maketext("Grade Test") ) : " "),
			      ($can{checkAnswersNextTime} && ! $can{recordAnswersNextTime} ?
			       CGI::submit( -name=>"checkAnswers",
					    -label=>$r->maketext("Check Test") ) : " "),
			      ($numProbPerPage && $numPages > 1 && 
			       $can{recordAnswersNextTime} ? CGI::br() . 
			       CGI::em($r->maketext("Note: grading the test grades all problems, not just those on this page.")) : " ") );

		print( CGI::hidden(
				   -name   => 'sourceFilePath',
				   -value  =>  $r->param("sourceFilePath")
				  ))  if defined($r->param("sourceFilePath"));
		print( CGI::hidden(
				   -name   => 'problemSeed',
				   -value  =>  $r->param("problemSeed")
				  ))  if defined($r->param("problemSeed"));

		print CGI::end_form();
	}

	# finally, put in a show answers option if appropriate
	# print answer inspection button
	if ($authz->hasPermissions($user, "view_answers")) {
	    my $hiddenFields = $self->hidden_authen_fields;
	    my $firstProb = $startProb+1;
	    my $lastProb = $endProb+1;
	    $hiddenFields =~ s/\"hidden_/\"pastans-hidden_/g;
		my $pastAnswersPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::ShowAnswers", $r, courseID => $ce->{courseName});
		my $showPastAnswersURL = $self->systemLink($pastAnswersPage, authen => 0); # no authen info for form action
		print "\n", CGI::start_form(-method=>"POST",-action=>$showPastAnswersURL,-target=>"WW_Info"),"\n",
			$hiddenFields,"\n",
			CGI::hidden(-name => 'courseID',  -value=>$ce->{courseName}), "\n",
			CGI::hidden(-name => 'selected_sets',  -value=>$setVName), "\n",
			  CGI::hidden(-name => 'selected_users',    -value=>$effectiveUser), "\n";
	    for (my $prob=$firstProb; $prob <= $lastProb; $prob++) {
	      print CGI::hidden(-name => 'selected_problems', -value=>"$prob"), "\n";
	    }

	    print CGI::p(
				CGI::submit(-name => 'action',  -value=>$r->maketext('Show Past Answers'))
				), "\n",
			CGI::end_form();
	}

	# prints the achievement message if there is one
	#If achievements enabled, and if we are not in a try it page, check to see if there are new ones.and print them.  
	#Gateways are special.  We only provide the first problem just to seed the data, but all of the problems from the gateway will be provided to the achievement evaluator
	if ($ce->{achievementsEnabled} && $will{recordAnswers} 
	    && $submitAnswers && $set->set_id ne 'Undefined_Set') {
	    print  WeBWorK::AchievementEvaluator::checkForAchievements($problems[0], $pg_results[0], $r, setVersion=>$versionNumber);
	    
	}
	
	return "";

}


###########################################################################
# Evaluation utilities
############################################################################

sub getProblemHTML {
	my ( $self, $EffectiveUser, $set, $formFields,
	     $mergedProblem, $pgFile ) = @_;
# in:  $EffectiveUser is the effective user we're working as, $set is the
#      merged set version, %$formFields the form fields from the input form
#      that we need to worry about putting into the HTML we're generating,
#      and $mergedProblem and $pgFile are what we'd expect.
#      $pgFile is optional
# out: the translated problem is returned

	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $key =  $r->param('key');
	my $setName = $set->set_id;
	my $setVersionNumber = $set->version_id;
	my $permissionLevel = $self->{permissionLevel};
	my $psvn = $set->psvn();

	if ( defined($mergedProblem) && $mergedProblem->problem_id ) {
# nothing needs to be done

	} elsif ($pgFile) {
		$mergedProblem = 
		    WeBWorK::DB::Record::ProblemVersion->new(
					set_id => $setName,
					version_id => $setVersionNumber,
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

sub output_JS{
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};

	# The Base64.js file, which handles base64 encoding and decoding
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/Base64/Base64.js"}), CGI::end_script();

		# This is for MathView.  
	if ($self->{will}->{useMathView}) {
	    if ((grep(/MathJax/,@{$ce->{pg}->{displayModes}}))) {
		print CGI::start_script({type=>"text/javascript", src=>"$ce->{webworkURLs}->{MathJax}"}), CGI::end_script();
		
		print "<link href=\"$site_url/js/apps/MathView/mathview.css\" rel=\"stylesheet\" />";
		print CGI::start_script({type=>"text/javascript"});
		print "mathView_basepath = \"$site_url/images/mathview/\";";
		print CGI::end_script();
		print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/MathView/$ce->{pg}->{options}->{mathViewLocale}"}), CGI::end_script();
		print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/MathView/mathview.js"}), CGI::end_script();
	    } else {
		warn ("MathJax must be installed and enabled as a display mode for the math viewer to work");
	    }
	}

	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/vendor/other/knowl.js"}),CGI::end_script();
	#This is for page specfific js
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/GatewayQuiz/gateway.js"}), CGI::end_script();
	
	return "";
}

sub output_achievement_CSS {
    return "";
}

1;
