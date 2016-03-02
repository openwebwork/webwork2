################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Problem.pm,v 1.225 2010/05/28 21:29:48 gage Exp $
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

package WeBWorK::ContentGenerator::Problem;
use base qw(WeBWorK);
#use base qw(WeBWorK::ContentGenerator);
use base qw(WeBWorK::ContentGenerator::ProblemUtil::ProblemUtil);  # not needed?

=head1 NAME
 
WeBWorK::ContentGenerator::Problem - Allow a student to interact with a problem.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use File::Path qw(rmtree);
use WeBWorK::Debug;
use WeBWorK::Form;
use WeBWorK::PG;
use WeBWorK::PG::ImageGenerator;
use WeBWorK::PG::IO;
use WeBWorK::Utils qw(readFile writeLog writeCourseLog encodeAnswers decodeAnswers is_restricted
	ref2string makeTempDirectory path_is_subdir sortByName before after between wwRound is_jitar_problem_closed is_jitar_problem_hidden jitar_problem_adjusted_status jitar_id_to_seq seq_to_jitar_id jitar_problem_finished);
use WeBWorK::DB::Utils qw(global2user user2global);
require WeBWorK::Utils::ListingDB;
use URI::Escape;
use WeBWorK::Localize;
use WeBWorK::Utils::Tasks qw(fake_set fake_problem);
use WeBWorK::AchievementEvaluator;
use WeBWorK::Utils::AttemptsTable;

################################################################################
# CGI param interface to this module (up-to-date as of v1.153)
################################################################################

# Standard params:
# 
#     user - user ID of real user
#     key - session key
#     effectiveUser - user ID of effective user
# 
# Integration with PGProblemEditor:
# 
#     editMode - if set, indicates alternate problem source location.
#                can be "temporaryFile" or "savedFile".
# 
#     sourceFilePath - path to file to be edited
#     problemSeed - force problem seed to value
#     success - success message to display
#     failure - failure message to display
# 
# Rendering options:
# 
#     displayMode - name of display mode to use
#     
#     showOldAnswers - request that last entered answer be shown (if allowed)
#     showCorrectAnswers - request that correct answers be shown (if allowed)
#     showHints - request that hints be shown (if allowed)
#     showSolutions - request that solutions be shown (if allowed)
# 
# Problem interaction:
# 
#     AnSwEr# - answer blanks in problem
#     
#     redisplay - name of the "Redisplay Problem" button
#     submitAnswers - name of "Submit Answers" button
#     checkAnswers - name of the "Check Answers" button
#     showMeAnother - name of the "Show me another" button
#     previewAnswers - name of the "Preview Answers" button

################################################################################
# "can" methods
################################################################################

# Subroutines to determine if a user "can" perform an action. Each subroutine is
# called with the following arguments:
# 
#     ($self, $User, $EffectiveUser, $Set, $Problem)

# Note that significant parts of the "can" methods are lifted into the 
# GatewayQuiz module.  It isn't direct, however, because of the necessity
# of dealing with versioning there.

sub can_showOldAnswers {
	my ($self, $User, $EffectiveUser, $Set, $Problem) = @_;
	my $authz = $self->r->authz;

	return $authz->hasPermissions($User->user_id, "can_show_old_answers");
}

sub can_showCorrectAnswers {
	my ($self, $User, $EffectiveUser, $Set, $Problem) = @_;
	my $authz = $self->r->authz;
	
	return
		after($Set->answer_date)
			||
		$authz->hasPermissions($User->user_id, "show_correct_answers_before_answer_date")
		;
}
sub can_showAnsGroupInfo {
	my ($self, $User, $EffectiveUser, $Set, $Problem) = @_;
	my $authz = $self->r->authz;
#FIXME -- may want to adjust this
	return
		$authz->hasPermissions($User->user_id, "show_answer_group_info_checkbox")
		;
}

sub can_showAnsHashInfo {
	my ($self, $User, $EffectiveUser, $Set, $Problem) = @_;
	my $authz = $self->r->authz;
#FIXME -- may want to adjust this
	return
		$authz->hasPermissions($User->user_id, "show_answer_hash_info_checkbox")
		;
}

sub can_showPGInfo {
	my ($self, $User, $EffectiveUser, $Set, $Problem) = @_;
	my $authz = $self->r->authz;
#FIXME -- may want to adjust this
	return
		$authz->hasPermissions($User->user_id, "show_pg_info_checkbox")
		;
}

sub can_showResourceInfo {
	my ($self, $User, $EffectiveUser, $Set, $Problem) = @_;
	my $authz = $self->r->authz;
	
	return
		$authz->hasPermissions($User->user_id, "show_resource_info")
		;
}

sub can_showHints {
	my ($self, $User, $EffectiveUser, $Set, $Problem) = @_;
	my $authz = $self->r->authz;
	
	return !$Set->hide_hint;
}

sub can_showSolutions {
	my ($self, $User, $EffectiveUser, $Set, $Problem) = @_;
	my $authz = $self->r->authz;
	
	return
		after($Set->answer_date)
			||
		$authz->hasPermissions($User->user_id, "show_solutions_before_answer_date")
		;
}


sub can_recordAnswers {
	my ($self, $User, $EffectiveUser, $Set, $Problem, $submitAnswers) = @_;
	my $authz = $self->r->authz;
	my $thisAttempt = $submitAnswers ? 1 : 0;
	if ($User->user_id ne $EffectiveUser->user_id) {
		return $authz->hasPermissions($User->user_id, "record_answers_when_acting_as_student");
	}
	if (before($Set->open_date)) {
		return $authz->hasPermissions($User->user_id, "record_answers_before_open_date");
	} elsif (between($Set->open_date, $Set->due_date)) {
		my $max_attempts = $Problem->max_attempts;
		my $attempts_used = $Problem->num_correct + $Problem->num_incorrect + $thisAttempt;
		if ($max_attempts == -1 or $attempts_used < $max_attempts) {
			return $authz->hasPermissions($User->user_id, "record_answers_after_open_date_with_attempts");
		} else {
			return $authz->hasPermissions($User->user_id, "record_answers_after_open_date_without_attempts");
		}
	} elsif (between($Set->due_date, $Set->answer_date)) {
		return $authz->hasPermissions($User->user_id, "record_answers_after_due_date");
	} elsif (after($Set->answer_date)) {
		return $authz->hasPermissions($User->user_id, "record_answers_after_answer_date");
	}
}

sub can_checkAnswers {
	my ($self, $User, $EffectiveUser, $Set, $Problem, $submitAnswers) = @_;
	my $authz = $self->r->authz;
	my $thisAttempt = $submitAnswers ? 1 : 0;
	
	# if we can record answers then we dont need to be able to check them
	# unless we have that specific permission. 
	if ($self->can_recordAnswers($User,$EffectiveUser,$Set,$Problem,$submitAnswers) 
	    && !$authz->hasPermissions($User->user_id, "can_check_and_submit_answers")) {
	    return 0;
	}
	
	if (before($Set->open_date)) {
		return $authz->hasPermissions($User->user_id, "check_answers_before_open_date");
	} elsif (between($Set->open_date, $Set->due_date)) {
		my $max_attempts = $Problem->max_attempts;
		my $attempts_used = $Problem->num_correct + $Problem->num_incorrect + $thisAttempt;
		if ($max_attempts == -1 or $attempts_used < $max_attempts) {
			return $authz->hasPermissions($User->user_id, "check_answers_after_open_date_with_attempts");
		} else {
			return $authz->hasPermissions($User->user_id, "check_answers_after_open_date_without_attempts");
		}
	} elsif (between($Set->due_date, $Set->answer_date)) {
		return $authz->hasPermissions($User->user_id, "check_answers_after_due_date");
	} elsif (after($Set->answer_date)) {
		return $authz->hasPermissions($User->user_id, "check_answers_after_answer_date");
	}
}

sub can_useMathView {
    my ($self, $User, $EffectiveUser, $Set, $Problem, $submitAnswers) = @_;
    my $ce= $self->r->ce;

    return $ce->{pg}->{specialPGEnvironmentVars}->{MathView};
}
    

sub can_showMeAnother {
    # PURPOSE: subroutine to check if showMeAnother 
    #          button should be allowed; note that this is done
    #          *before* the check to see if showMeAnother is 
    #          possible.
	my ($self, $User, $EffectiveUser, $Set, $Problem, $submitAnswers) = @_;
    my $ce = $self->r->ce;

    # if the showMeAnother button isn't enabled in the course configuration, 
    # don't show it under any circumstances (not even for the instructor)
    return 0 unless($ce->{pg}->{options}->{enableShowMeAnother});

    # get the hash of information about showMeAnother
	my %showMeAnother = %{ $self->{showMeAnother} };

    if (after($Set->open_date)) {
        # if $showMeAnother{TriesNeeded} is somehow not an integer or if its -2, use the default value 
        $showMeAnother{TriesNeeded} = $ce->{pg}->{options}->{showMeAnotherDefault} if ($showMeAnother{TriesNeeded} !~ /^[+-]?\d+$/ || $showMeAnother{TriesNeeded} == -2);

	    # if SMA is just not permitted for the problem, don't show it
	    return 0 unless ($showMeAnother{TriesNeeded} > -1);

        my $thisAttempt = $submitAnswers ? 1 : 0;
	    my $attempts_used = $Problem->num_correct + $Problem->num_incorrect + $thisAttempt;

        # if $showMeAnother{Count} is somehow not an integer, it probably means that the database was never
	    # inititialized meaning that the student hasn't pushed it yet and it should be 0
        $showMeAnother{Count} = 0 unless ($showMeAnother{Count} =~ /^[+-]?\d+$/);

	 # if the student is *preview*ing or *check*ing their answer to SMA then showMeAnother{Count} IS ALLOWED
        # to be equal to showMeAnother{MaxReps}
        $showMeAnother{Count}-- if(defined($showMeAnother{CheckAnswers} && $showMeAnother{CheckAnswers}) or (defined($showMeAnother{Preview}) && $showMeAnother{Preview}));

	    # if we've gotten this far, the button is enabled globally and for the problem; check if the student has either
	    # not submitted enough answers yet or has used the SMA button too many times
	    if ($attempts_used < $showMeAnother{TriesNeeded} 
	        or ($showMeAnother{Count}>=$showMeAnother{MaxReps} and $showMeAnother{MaxReps}>-1)) {
          return 0;
        } else {
          return 1;
        }
    } else {
      # otherwise the set hasn't been opened yet, so we can't use showMeAnother 
      return 0;}
}

################################################################################
# output utilities
################################################################################

# Note: the substance of attemptResults is lifted into GatewayQuiz.pm,
# with some changes to the output format
sub attemptResults {
	my $self = shift;
	my $r = $self->r;
	my $pg = shift;
	my $showAttemptAnswers = shift//0;
	my $showCorrectAnswers = shift;
	my $showAttemptResults = $showAttemptAnswers && shift;
	my $showSummary = shift;
	my $showAttemptPreview = shift // 1;
	my $ce = $self->r->ce;
	
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

	my $answers = $pg->{answers};
	my $showEvaluatedAnswers = $ce->{pg}->{options}->{showEvaluatedAnswers}//'';

# Create AttemptsTable object	
	my $tbl = WeBWorK::Utils::AttemptsTable->new(
		$answers,
		answersSubmitted       => 1,
		answerOrder            => $pg->{flags}->{ANSWER_ENTRY_ORDER},
		displayMode            => $self->{displayMode},
		showAnswerNumbers      => 0,
		showAttemptAnswers     => $showAttemptAnswers && $showEvaluatedAnswers,
		showAttemptPreviews    => $showAttemptPreview,
		showAttemptResults     => $showAttemptResults,
		showCorrectAnswers     => $showCorrectAnswers,
		showMessages           => $showAttemptAnswers, # internally checks for messages
		showSummary            => $showSummary,
		imgGen                 => $imgGen, # not needed if ce is present ,
		ce                     => '',	   # not needed if $imgGen is present
		maketext               => WeBWorK::Localize::getLoc($ce->{language}),
	);
	# render equation images
	my $answerTemplate = $tbl->answerTemplate; 
	   # answerTemplate collects all the formulas to be displayed in the attempts table  
	   # answerTemplate also collects the correct_ids and incorrect_ids
	$tbl->imgGen->render(refresh => 1) if $tbl->displayMode eq 'images';
	    # after all of the formulas have been collected the render command creates png's for them
	    # refresh=>1 insures that we never reuse old images -- since the answers change frequently
	$self->{correct_ids}   = $tbl->correct_ids;
	$self->{incorrect_ids} = $tbl->incorrect_ids;
	return $answerTemplate;

}

################################################################################
# Template escape implementations
################################################################################
sub templateName {
	my $self = shift;
	my $r = $self->r;
	my $templateName = $r->param('templateName')//'system';
	$self->{templateName}= $templateName;
	$templateName;
}
sub content {
  my $self = shift;
  my $result = $self->SUPER::content(@_);
  $self->{pg}->free if $self->{pg};   # be sure to clean up PG environment when the page is done
  return $result;
}

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	my $setName = $urlpath->arg("setID");
	my $problemNumber = $r->urlpath->arg("problemID");
	my $userName = $r->param('user');
	my $effectiveUserName = $r->param('effectiveUser');
	my $key = $r->param('key');
	my $editMode = $r->param("editMode");
	
	my $user = $db->getUser($userName); # checked
	die "record for user $userName (real user) does not exist."
		unless defined $user;
	
	my $effectiveUser = $db->getUser($effectiveUserName); # checked
	die "record for user $effectiveUserName (effective user) does not exist."
		unless defined $effectiveUser;
		
	# obtain the merged set for $effectiveUser
	my $set = $db->getMergedSet($effectiveUserName, $setName); 
	
	# check that the set is valid;
	# $self->{invalidSet} is set by ContentGenerator.pm
	die($self->{invalidSet}) if $self->{invalidSet};

	# we are open if we can view unopened sets
	$self->{isOpen} = $authz->hasPermissions($userName, "view_unopened_sets");

	# or if the set is the "Undefined_set"
	$self->{isOpen} = $self->{isOpen} || $setName eq "Undefined_Set";
	
	# or if the set is past the answer date
	$self->{isOpen} = $self->{isOpen} || time >= $set->answer_date;
	
	my $isClosed = 0;
	# now we check the reasons why it might be closed
	unless ($self->{isOpen}) {
	    # its closed if the set is restricted
	    $isClosed = $ce->{options}{enableConditionalRelease} && is_restricted($db, $set, $effectiveUserName);
	    # or if its a jitar set and the problem is hidden or closed
	    $isClosed = $isClosed || ($set->assignment_type() eq 'jitar' &&
				      is_jitar_problem_hidden($db,$effectiveUserName,$set->set_id,$problemNumber));
	    $isClosed = $isClosed || ($set->assignment_type() eq 'jitar' &&
				      is_jitar_problem_closed($db,$ce,$effectiveUserName,$set->set_id,$problemNumber));
	}

	# isOpen overrides $isClosed.  
	$self->{isOpen} = $self->{isOpen} || !$isClosed;
	
	die("You do not have permission to view unopened sets") unless $self->{isOpen};	

	# Database fix (in case of undefined visiblity state values)
	# this is only necessary because some people keep holding to ww1.9 which did not have a visible field
	# make sure visible is set to 0 or 1
	if ( $set and $set->visible ne "0" and $set->visible ne "1") {
		my $globalSet = $db->getGlobalSet($set->set_id);
		$globalSet->visible("1");	# defaults to visible
		$db->putGlobalSet($globalSet);
		$set = $db->getMergedSet($effectiveUserName, $setName);
	} else {
		# don't do anything just yet, maybe we're a professor and we're
		# fabricating a set or haven't assigned it to ourselves just yet
	}
		# When a set is created enable_reduced_scoring is null, so we have to set it 
	if ( $set and $set->enable_reduced_scoring ne "0" and $set->enable_reduced_scoring ne "1") {
		my $globalSet = $db->getGlobalSet($set->set_id);
		$globalSet->enable_reduced_scoring("0");	# defaults to disabled
		$db->putGlobalSet($globalSet);
		$set = $db->getMergedSet($effectiveUserName, $setName);
	}
	
	
	# obtain the merged problem for $effectiveUser
	my $problem = $db->getMergedProblem($effectiveUserName, $setName, $problemNumber); # checked
	
	# A very hacky and temporary solution to the max_attempts problem
	# if($problem->max_attempts == ""){
		# $problem->max_attempts = -1;
	# }
	
	if ($authz->hasPermissions($userName, "modify_problem_sets")) {
		# professors are allowed to fabricate sets and problems not
		# assigned to them (or anyone). this allows them to use the
		# editor to 

		# if a User Set does not exist for this user and this set
		# then we check the Global Set
		# if that does not exist we create a fake set
		# if it does, we add fake user data
		unless (defined $set) {
			my $userSetClass = $db->{set_user}->{record};
			my $globalSet = $db->getGlobalSet($setName); # checked

			if (not defined $globalSet) {
				$set = fake_set($db);
			} else {
				$set = global2user($userSetClass, $globalSet);
				$set->psvn(0);
			}
		}
		
		# if that is not yet defined obtain the global problem,
		# convert it to a user problem, and add fake user data
		unless (defined $problem) {
			my $userProblemClass = $db->{problem_user}->{record};
			my $globalProblem = $db->getGlobalProblem($setName, $problemNumber); # checked
			# if the global problem doesn't exist either, bail!
			if(not defined $globalProblem) {
				my $sourceFilePath = $r->param("sourceFilePath");
				die "sourceFilePath is unsafe!" unless path_is_subdir($sourceFilePath, $ce->{courseDirs}->{templates}, 1); # 1==path can be relative to dir
				# These are problems from setmaker.  If declared invalid, they won't come up
				$self->{invalidProblem} = $self->{invalidSet} = 1 unless defined $sourceFilePath;
#				die "Problem $problemNumber in set $setName does not exist" unless defined $sourceFilePath;
				$problem = fake_problem($db);
				$problem->problem_id(1);
				$problem->source_file($sourceFilePath);
				$problem->user_id($effectiveUserName);
			} else {
				$problem = global2user($userProblemClass, $globalProblem);
				$problem->user_id($effectiveUserName);
				$problem->problem_seed(0);
				$problem->status(0);
				$problem->attempted(0);
				$problem->last_answer("");
				$problem->num_correct(0);
				$problem->num_incorrect(0);
			}
		}
		
		# now we're sure we have valid UserSet and UserProblem objects
		# yay!
		
		# now deal with possible editor overrides:
		
		# if the caller is asking to override the source file, and
		# editMode calls for a temporary file, do so
		my $sourceFilePath = $r->param("sourceFilePath");
		if (defined $editMode and $editMode eq "temporaryFile" and defined $sourceFilePath) {
			die "sourceFilePath is unsafe!" unless path_is_subdir($sourceFilePath, $ce->{courseDirs}->{templates}, 1); # 1==path can be relative to dir
			$problem->source_file($sourceFilePath);
		}
		
		# if the problem does not have a source file or no source file has been passed in 
		# then this is really an invalid problem (probably from a bad URL)
		$self->{invalidProblem} = not (defined $sourceFilePath or $problem->source_file);

        # if the caller is asking to override the problem seed, do so
		my $problemSeed = $r->param("problemSeed");
		if (defined $problemSeed && $problemSeed =~ /^[+-]?\d+$/) {
			$problem->problem_seed($problemSeed);
        }	

		my $visiblityStateClass = ($set->visible) ? $r->maketext("font-visible") : $r->maketext("font-hidden");
		my $visiblityStateText = ($set->visible) ? $r->maketext("visible to students")."." : $r->maketext("hidden from students").".";
		$self->addmessage(CGI::span($r->maketext("This set is [_1]", CGI::span({class=>$visiblityStateClass}, $visiblityStateText))));

  # test for additional problem validity if it's not already invalid
        } else {
		$self->{invalidProblem} = !(defined $problem and ($set->visible || $authz->hasPermissions($userName, "view_hidden_sets")));
		
		$self->addbadmessage(CGI::p($r->maketext("This problem will not count towards your grade."))) if $problem and not $problem->value and not $self->{invalidProblem};
	}

	$self->{userName}          = $userName;
	$self->{effectiveUserName} = $effectiveUserName;
	$self->{user}              = $user;
	$self->{effectiveUser}     = $effectiveUser;
	$self->{set}               = $set;
	$self->{problem}           = $problem;
	$self->{editMode}          = $editMode;
	
	##### form processing #####
	
	# set options from form fields (see comment at top of file for names)
	my $displayMode               = $r->param("displayMode") || $user->displayMode || $ce->{pg}->{options}->{displayMode};
	my $redisplay                 = $r->param("redisplay");
	my $submitAnswers             = $r->param("submitAnswers");
	my $checkAnswers              = $r->param("checkAnswers");
	my $previewAnswers            = $r->param("previewAnswers");
	my $requestNewSeed            = $r->param("requestNewSeed") // 0;

	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	$self->{displayMode}    = $displayMode;
	$self->{redisplay}      = $redisplay;
	$self->{submitAnswers}  = $submitAnswers;
	$self->{checkAnswers}   = $checkAnswers;
	$self->{previewAnswers} = $previewAnswers;
	$self->{formFields}     = $formFields;
	$self->{requestNewSeed} = $requestNewSeed;

	# get result and send to message
	my $status_message = $r->param("status_message");
	$self->addmessage(CGI::p("$status_message")) if $status_message;

	# now that we've set all the necessary variables quit out if the set or problem is invalid
	return if $self->{invalidSet} || $self->{invalidProblem};

    # a hash containing information for showMeAnother
    #       TriesNeeded:   the number of times the student needs to attempt the problem before the button is available
    #       MaxReps:       the Maximum Number of times that showMeAnother can be clicked (specified in course configuration
    #       Count:         the number of times the student has clicked SMA (or clicked refresh on the page)
    my %SMAoptions = map {$_ => 1} @{$ce->{pg}->{options}->{showMeAnother}};
    my %showMeAnother = (
            TriesNeeded => $problem->{showMeAnother},
            MaxReps => $ce->{pg}->{options}->{showMeAnotherMaxReps},
            Count => $problem->{showMeAnotherCount},
          );

    # if $showMeAnother{Count} is somehow not an integer, make it one
    $showMeAnother{Count} = 0 unless ($showMeAnother{Count} =~ /^[+-]?\d+$/);

    # store the showMeAnother hash for the check to see if the button can be used
    # (this hash is updated and re-stored after the can, must, will hashes)
	$self->{showMeAnother} = \%showMeAnother;
	
	##### permissions #####

	# what does the user want to do?
	#FIXME  There is a problem with checkboxes -- if they are not checked they are invisible.  Hence if the default mode in $ce is 1
	# there is no way to override this.  Probably this is ok for the last three options, but it was definitely not ok for showing
	# saved answers which is normally on, but you want to be able to turn it off!  This section should be moved to ContentGenerator
	# so that you can set these options anywhere.  We also need mechanisms for making them sticky.
	# Note: ProblemSet and ProblemSets might set showOldAnswers to '', which
	#       needs to be treated as if it is not set.
	my %want = (
		showOldAnswers     => $user->showOldAnswers ne '' ? $user->showOldAnswers  : $ce->{pg}->{options}->{showOldAnswers},
		showCorrectAnswers => $r->param('showCorrectAnswers') || $ce->{pg}->{options}->{showCorrectAnswers},
		showAnsGroupInfo     => $r->param('showAnsGroupInfo') || $ce->{pg}->{options}->{showAnsGroupInfo},
		showAnsHashInfo    => $r->param('showAnsHashInfo') || $ce->{pg}->{options}->{showAnsHashInfo},
		showPGInfo         => $r->param('showPGInfo') || $ce->{pg}->{options}->{showPGInfo},
		showResourceInfo   => $r->param('showResourceInfo') || $ce->{pg}->{options}->{showResourceInfo},
		showHints          => $r->param("showHints")          || $ce->{pg}->{options}{use_knowls_for_hints} 
		                      || $ce->{pg}->{options}->{showHints},     #set to 0 in defaults.config
		showSolutions      => $r->param("showSolutions") || $ce->{pg}->{options}{use_knowls_for_solutions}      
							  || $ce->{pg}->{options}->{showSolutions}, #set to 0 in defaults.config
        useMathView        => $user->useMathView ne '' ? $user->useMathView : $ce->{pg}->{options}->{useMathView},
		recordAnswers      => $submitAnswers,
		checkAnswers       => $checkAnswers,
		getSubmitButton    => 1,
	);

	# are certain options enforced?
	my %must = (
		showOldAnswers     => 0,
		showCorrectAnswers => 0,
		showAnsGroupInfo     => 0,
		showAnsHashInfo    => 0,
		showPGInfo		   => 0,
		showResourceInfo   => 0,
		showHints          => 0,
		showSolutions      => 0,
		recordAnswers      => ! $authz->hasPermissions($userName, "avoid_recording_answers"),
		checkAnswers       => 0,
		showMeAnother      => 0,
		getSubmitButton    => 0,
	    useMathView        => 0,
	);
	 
	# does the user have permission to use certain options?
	my @args = ($user, $effectiveUser, $set, $problem);

	my %can = (
		showOldAnswers           => $self->can_showOldAnswers(@args),
		showCorrectAnswers       => $self->can_showCorrectAnswers(@args),
		showAnsGroupInfo         => $self->can_showAnsGroupInfo(@args),
		showAnsHashInfo          => $self->can_showAnsHashInfo(@args),
		showPGInfo           	 => $self->can_showPGInfo(@args),
		showResourceInfo         => $self->can_showResourceInfo(@args),
		showHints                => $self->can_showHints(@args),
		showSolutions            => $self->can_showSolutions(@args),
		recordAnswers            => $self->can_recordAnswers(@args, 0),
		checkAnswers             => $self->can_checkAnswers(@args, $submitAnswers),
		showMeAnother            => $self->can_showMeAnother(@args, $submitAnswers),
		getSubmitButton          => $self->can_recordAnswers(@args, $submitAnswers),
	    useMathView              => $self->can_useMathView(@args)
	);

	# re-randomization based on the number of attempts and specified period
	my $prEnabled = $ce->{pg}->{options}->{enablePeriodicRandomization} // 0;
	my $rerandomizePeriod = $ce->{pg}->{options}->{periodicRandomizationPeriod} // 0;
	if (defined $problem->{prPeriod} ){
		if ( $problem->{prPeriod} =~ /^\s*$/ ){
			$problem->{prPeriod} = $ce->{problemDefaults}->{prPeriod};
		}
	}
	if ( (defined $problem->{prPeriod}) and ($problem->{prPeriod} > -1) ){
		$rerandomizePeriod = $problem->{prPeriod};
	}
	$prEnabled = 0 if ($rerandomizePeriod < 1);
	if ($prEnabled){
		my $thisAttempt = ($submitAnswers) ? 1 : 0;
		my $attempts_used = $problem->num_correct + $problem->num_incorrect + $thisAttempt;
		if ($problem->{prCount} =~ /^\s*$/) {
			$problem->{prCount} = sprintf("%d",$attempts_used/$rerandomizePeriod) - 1;
		}
		$requestNewSeed = 0 if (
			($attempts_used % $rerandomizePeriod) or
			( sprintf("%d",$attempts_used/$rerandomizePeriod) <= $problem->{prCount} ) or
			after($set->due_date)
		);
		if ($requestNewSeed){
			# obtain new random seed to hopefully change the problem
			my $newSeed = ($problem->{problem_seed} + $attempts_used) % 10000;
			$problem->{problem_seed} = $newSeed;
			$problem->{prCount} = sprintf("%d",$attempts_used/$rerandomizePeriod);
			$db->putUserProblem($problem);
		}
	}

	
	# final values for options
	my %will;
	foreach (keys %must) {
		$will{$_} = $can{$_} && ($want{$_} || $must{$_});
		#warn "final values for options $_ is can $can{$_}, want $want{$_}, must $must{$_}, will $will{$_}";
	}
	
	##### sticky answers #####
	
	if (not ($submitAnswers or $previewAnswers or $checkAnswers) and $will{showOldAnswers}) {
		# do this only if new answers are NOT being submitted
		my %oldAnswers = decodeAnswers($problem->last_answer);
		$formFields->{$_} = $oldAnswers{$_} foreach keys %oldAnswers;
	}
	
	##### translation #####

	debug("begin pg processing");
	my $pg = WeBWorK::PG->new(
		$ce,
		$effectiveUser,
		$key,
		$set,
		$problem,
		$set->psvn, # FIXME: this field should be removed
		$formFields,
		{ # translation options
			displayMode     => $displayMode,
			showHints       => $will{showHints},
			showResourceInfo => $will{showResourceInfo},
			showSolutions   => $will{showSolutions},
			refreshMath2img => $will{showHints} || $will{showSolutions},
			processAnswers  => 1,
			permissionLevel => $db->getPermissionLevel($userName)->permission,
			effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
		},
	);

	debug("end pg processing");
	
	if ($prEnabled){
		my $thisAttempt = ($submitAnswers) ? 1 : 0;
		my $attempts_used = $problem->num_correct + $problem->num_incorrect + $thisAttempt;
		my $rerandomize_step = 0;
		$rerandomize_step = 1 if (
			($attempts_used > 0) &&
			($attempts_used % $rerandomizePeriod == 0) &&
			(sprintf("%d",$attempts_used/$rerandomizePeriod) > $problem->{prCount})
			);
		$rerandomize_step = 0 if ( after($set->due_date) );
		if ($rerandomize_step){
			$showMeAnother{active} = 0;
			$must{requestNewSeed} = 1;
			$can{requestNewSeed} = 1;
			$want{requestNewSeed} = 1;
			$will{requestNewSeed} = 1;
		}
	} 
	
	##### update and fix hint/solution options after PG processing #####
	
	$can{showHints}     &&= $pg->{flags}->{hintExists}  
	                    &&= $pg->{flags}->{showHintLimit}<=$pg->{state}->{num_of_incorrect_ans};
	$can{showSolutions} &&= $pg->{flags}->{solutionExists};
	
	##### record errors #########
	if (ref ($pg->{pgcore}) )  {
		my @debug_messages     = @{$pg->{pgcore}->get_debug_messages};
		my @warning_messages   = @{$pg->{pgcore}->get_warning_messages};
		my @internal_errors    = @{$pg->{pgcore}->get_internal_debug_messages};
		$self->{pgerrors}      = @debug_messages||@warning_messages||@internal_errors;  # is 1 if any of these are non-empty
		$self->{pgdebug}       =    \@debug_messages;
		$self->{pgwarning}     =    \@warning_messages;
		$self->{pginternalerrors} = \@internal_errors ;
	} else {
		warn "Processing of this PG problem was not completed.  Probably because of a syntax error.
		      The translator died prematurely and no PG warning messages were transmitted.";
	}

	##### store fields #####
	
	$self->{want} = \%want;
	$self->{must} = \%must;
	$self->{can}  = \%can;
	$self->{will} = \%will;
	$self->{pg} = $pg;

	#### process and log answers ####
	$self->{scoreRecordedMessage} = WeBWorK::ContentGenerator::ProblemUtil::ProblemUtil::process_and_log_answer($self) || "";

}

sub warnings {
	my $self = shift;
	# print "entering warnings() subroutine internal messages = ", $self->{pgerrors},CGI::br();
 	my $r  = $self->r;
# 	my $pg = $self->{pg};
# 	warn "type of pg is ",ref($pg);
#  	my $pgerrordiv = $pgdebug||$pgwarning||$pginternalerrors;  # is 1 if any of these are non-empty
    # print warning messages
    if (not defined $self->{pgerrors} ) {
    	print CGI::start_div();
		print CGI::h3({style=>"color:red;"}, $r->maketext("PG question failed to render"));
		print CGI::p($r->maketext("Unable to obtain error messages from within the PG question." ));
		print CGI::end_div();
    } elsif ( $self->{pgerrors} > 0 ) {
        my @pgdebug          = (defined $self->{pgdebug}) ? @{ $self->{pgdebug}} : () ; 
 		my @pgwarning        = (defined $self->{pgwarning}) ? @{ $self->{pgwarning}} : ();
 		my @pginternalerrors = (defined $self->{pginternalerrors}) ? @{ $self->{pginternalerrors}} : ();
		print CGI::start_div();
		print CGI::h3({style=>"color:red;"}, $r->maketext("PG question processing error messages"));
		print CGI::p(CGI::h3($r->maketext("PG debug messages" ) ),  join(CGI::br(), @pgdebug  )  )  if @pgdebug   ;
		print CGI::p(CGI::h3($r->maketext("PG warning messages" ) ),join(CGI::br(), @pgwarning)  )  if @pgwarning ;	
		print CGI::p(CGI::h3($r->maketext("PG internal errors" ) ), join(CGI::br(), @pginternalerrors )) if @pginternalerrors;
		print CGI::end_div();
	} 
	# print "proceeding to SUPER::warnings";
	$self->SUPER::warnings();
	#  print $self->{pgerrors};
	"";  #FIXME -- let's see if this is the appropriate output.
}

sub if_errors($$) {
	my ($self, $arg) = @_;
	
	if ($self->{isOpen}) {
		return $self->{pg}->{flags}->{error_flag} ? $arg : !$arg;
	} else {
		return !$arg;
	}
}

sub head {
	my ($self) = @_;
	my $ce = $self->r->ce;
	my $webwork_htdocs_url = $ce->{webwork_htdocs_url};
	return "" if ( $self->{invalidSet} );

	# Keys dont really work well anymore.  So I'm removing this for now GG
#	print qq{
#		<link rel="stylesheet" href="$webwork_htdocs_url/js/legacy/vendor/keys/keys.css">
#		<script src="$webwork_htdocs_url/js/legacy/vendor/keys/keys.js"></script>
#	};

	return $self->{pg}->{head_text} if $self->{pg}->{head_text};

}

sub post_header_text {
	my ($self) = @_;
	return "" if ( $self->{invalidSet} );
    return $self->{pg}->{post_header_text} if $self->{pg}->{post_header_text};
}

sub siblings {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	# can't show sibling problems if the set is invalid
	return "" if $self->{invalidSet};
	
	my $courseID = $urlpath->arg("courseID");
	my $setID = $self->{set}->set_id;
	my $eUserID = $r->param("effectiveUser");
	my @problemIDs = sort { $a <=> $b } $db->listUserProblems($eUserID, $setID);

	my $isJitarSet = 0;

	if ($setID) {
	    my $set = $r->db->getGlobalSet($setID);
	    if ($set && $set->assignment_type eq 'jitar') {
		$isJitarSet = 1;
	    }
	}
	
	my @where = map {[$eUserID, $setID, $_]} @problemIDs;
	my @problemRecords = $db->getMergedProblems(@where);

	# variables for the progress bar
	my $num_of_problems  = 0;
	my $problemList;
	my $total_correct=0;
	my $total_incorrect=0;
	my $total_inprogress=0;
	my $currentProblemID = $self->{problem}->problem_id if !($self->{invalidProblem});

	my $progressBarEnabled = $r->ce->{pg}->{options}->{enableProgressBar};
	

	print CGI::start_div({class=>"info-box", id=>"fisheye"});
	print CGI::h2($r->maketext("Problems"));
	print CGI::start_ul({class=>"problem-list"});
	
	my @items;

	foreach my $problemID (@problemIDs) {
	  if ($isJitarSet && !$authz->hasPermissions($eUserID, "view_unopened_sets") && is_jitar_problem_hidden($db,$eUserID, $setID, $problemID)) {
		shift(@problemRecords) if $progressBarEnabled;
		next;
	      }
	  
	  my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Problem", $r, courseID => $courseID, setID => $setID, problemID => $problemID);
	  my $link;
	  
	  my $status_symbol = '';
	  if($progressBarEnabled){
	    my $problemRecord = shift(@problemRecords);
	    $num_of_problems++;
	    my $total_attempts = $problemRecord->num_correct+$problemRecord->num_incorrect;
	    
	    my $status = $problemRecord->status;
	    if ($isJitarSet) {
	      $status = jitar_problem_adjusted_status($problemRecord,$db);
	    }
	    
	    # variables for the widths of the bars in the Progress Bar
	    if( $status ==1 ){
	      # correct
	      $total_correct++;
	      $status_symbol = " &#x2713;"; # checkmark
	    } else {
	      # incorrect
	      if($total_attempts >= $problemRecord->max_attempts and $problemRecord->max_attempts!=-1){
			$total_incorrect++;
			$status_symbol = " &#x2717;"; # cross
	      } else {
			# in progress
			if($problemRecord->attempted>0){
			  $total_inprogress++;
			  $status_symbol = " &hellip;"; # horizontal ellipsis
			}
	      }
	    }
	  }
	  
	  # if its a jitar set we need to hide and disable links to hidden or restricted
	  # problems.  
	  if ($isJitarSet) {
	    
	    my @seq = jitar_id_to_seq($problemID);
	    my $level = $#seq;
	    my $class = '';
	    if ($level != 0) {
	      $class='nested-problem-'.$level;
	    }
	    
	    if (!$authz->hasPermissions($eUserID, "view_unopened_sets") && is_jitar_problem_closed($db, $ce, $eUserID, $setID, $problemID)) {
	      $link = CGI::a( {href=>'#', class=>$class.' disabled-problem'},  $r->maketext("Problem [_1]", join('.',@seq)));
	    } else {
	      $link = CGI::a( {class=>$class,href=>$self->systemLink($problemPage)},  $r->maketext("Problem [_1]", join('.',@seq)).($progressBarEnabled?$status_symbol:""));
	      
	    }
	  } else {
	    $link = CGI::a( {href=>$self->systemLink($problemPage)},  $r->maketext("Problem [_1]", $problemID).($progressBarEnabled?$status_symbol:""));
	  }
	  
	  push @items, CGI::li({($progressBarEnabled && $currentProblemID eq $problemID ? ('class','currentProblem'):())},$link);
	}

	# output the progress bar
	if($num_of_problems>0 and $r->ce->{pg}->{options}->{enableProgressBar}){
	    my $unattempted = $num_of_problems - $total_correct - $total_incorrect - $total_inprogress;
	    my $progress_bar_correct_width = $total_correct*100/$num_of_problems;
	    my $progress_bar_incorrect_width = $total_incorrect*100/$num_of_problems;
	    my $progress_bar_inprogress_width = $total_inprogress*100/$num_of_problems;
	    my $progress_bar_unattempted_width = $unattempted*100/$num_of_problems;
	    
	    # construct the progress bar 
	    #       CORRECT | IN PROGRESS | INCORRECT | UNATTEMPTED
	    my $progress_bar = CGI::start_div({-class=>"progress-bar set-id-tooltip",
					       "aria-label"=>"progress bar for current problem set",
					      });
	    if($total_correct>0){
		$progress_bar .= CGI::div({-class=>"correct-progress set-id-tooltip",-style=>"width:$progress_bar_correct_width%",
					   "aria-label"=>"correct progress bar for current problem set",
					   "data-toggle"=>"tooltip", "data-placement"=>"bottom", title=>"", 
					   "data-original-title"=>$r->maketext("Correct: $total_correct/$num_of_problems")
					  });
		# perfect scores deserve some stars (&#9733;)
		$progress_bar .= ($total_correct == $num_of_problems)?"&#9733;Perfect&#9733;":"";
		$progress_bar .= CGI::end_div();
	    } 
	    if($total_inprogress>0){
		$progress_bar .= CGI::div({-class=>"inprogress-progress set-id-tooltip",-style=>"width:$progress_bar_inprogress_width%",
					   "aria-label"=>"in progress bar for current problem set",
					   "data-toggle"=>"tooltip", "data-placement"=>"bottom", title=>"", 
					   "data-original-title"=>$r->maketext("In progress: $total_inprogress/$num_of_problems")
					  });
		$progress_bar .= CGI::end_div();
	    }
	    if($total_incorrect>0){
		$progress_bar .= CGI::div({-class=>"incorrect-progress set-id-tooltip",-style=>"width:$progress_bar_incorrect_width%",
					   "aria-label"=>"incorrect progress bar for current problem set",
					   "data-toggle"=>"tooltip", "data-placement"=>"bottom", title=>"", 
					   "data-original-title"=>$r->maketext("Incorrect: $total_incorrect/$num_of_problems")
					  });
		$progress_bar .= CGI::end_div();
	    }
	    if($unattempted>0){
		$progress_bar .= CGI::div({-class=>"unattempted-progress set-id-tooltip",-style=>"width:$progress_bar_unattempted_width%",
					   "aria-label"=>"unattempted progress bar for current problem set",
					   "data-toggle"=>"tooltip", "data-placement"=>"bottom", title=>"", 
					   "data-original-title"=>$r->maketext("Unattempted: $unattempted/$num_of_problems")
					  });
		$progress_bar .= CGI::end_div();
	    }
	    # close the progress bar div 
	    $progress_bar .= CGI::end_div();
	    
	    # output to the screen
	    print $progress_bar;
	}

	print @items;

	print CGI::end_ul();
	print CGI::end_div();
	
	return "";
}

sub nav {
	my ($self, $args) = @_;
	my $r = $self->r;
	my %can = %{ $self->{can} };

	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	return "" if ( $self->{invalidSet} );

	my $courseID = $urlpath->arg("courseID");
	my $setID = $self->{set}->set_id if !($self->{invalidSet});
	my $problemID = $self->{problem}->problem_id if !($self->{invalidProblem});
	my $eUserID = $r->param("effectiveUser");
	my $mergedSet = $db->getMergedSet($eUserID,$setID);
	return "" unless $mergedSet;

	my $isJitarSet = ($mergedSet->assignment_type eq 'jitar');

	my ($prevID, $nextID);

	# for jitar sets finding the next or previous problem, and seeing if it
	# is actually open is a bit more of a process. 
	if (!$self->{invalidProblem}) {
		my @problemIDs = $db->listUserProblems($eUserID, $setID);

		@problemIDs = sort { $a <=> $b } @problemIDs;
		

		if ($isJitarSet) {
		    my @processedProblemIDs;
		    foreach my $id (@problemIDs) {
			push @processedProblemIDs, $id unless
			    !$authz->hasPermissions($eUserID, "view_unopened_sets") && is_jitar_problem_hidden($db,$eUserID,$setID,$id);
		    }
		    @problemIDs = @processedProblemIDs;
		}

		my $curr_index = 0;

		for (my $i=0; $i<=$#problemIDs; $i++) {
		    $curr_index = $i if $problemIDs[$i] == $problemID;
		}

		$prevID = $problemIDs[$curr_index-1] if $curr_index-1 >=0;
		$nextID = $problemIDs[$curr_index+1] if $curr_index+1 <= $#problemIDs;
		$nextID = '' if ($isJitarSet && $nextID 
				 && !$authz->hasPermissions($eUserID, "view_unopened_sets") 
				 && is_jitar_problem_closed($db,$ce, $eUserID,$setID,$nextID));
		    
		
	}
	
	my @links;

	if ($prevID) {
		my $prevPage = $urlpath->newFromModule(__PACKAGE__, $r, 
			courseID => $courseID, setID => $setID, problemID => $prevID);
		push @links, $r->maketext("Previous Problem"), $r->location . $prevPage->path, $r->maketext("navPrev");
	} else {
		push @links, $r->maketext("Previous Problem"), "", $r->maketext("navPrevGrey");
	}

	if (defined($setID) && $setID ne 'Undefined_Set') {
		push @links, $r->maketext("Problem List"), $r->location . $urlpath->parent->path, $r->maketext("navProbList");
	} else {
		push @links, $r->maketext("Problem List"), "", $r->maketext("navProbListGrey");
	}

	if ($nextID) {
		my $nextPage = $urlpath->newFromModule(__PACKAGE__, $r, 
			courseID => $courseID, setID => $setID, problemID => $nextID);
		push @links, $r->maketext("Next Problem"), $r->location . $nextPage->path, $r->maketext("navNext");
	} else {
		push @links, $r->maketext("Next Problem"), "", $r->maketext("navNextGrey");
	}

	my $tail = "";

	$tail .= "&displayMode=".$self->{displayMode} if defined $self->{displayMode};
	$tail .= "&showOldAnswers=".$self->{will}->{showOldAnswers}
		if defined $self->{will}->{showOldAnswers};
	return $self->navMacro($args, $tail, @links);
}

sub title {
	my ($self) = @_;
	my $r = $self->r;
	# using the url arguments won't break if the set/problem are invalid
	my $setID = $self->r->urlpath->arg("setID");
	my $problemID = $self->r->urlpath->arg("problemID");

	my $set = $r->db->getGlobalSet($setID);
	$setID = WeBWorK::ContentGenerator::underscore2nbsp($setID);
	if ($set && $set->assignment_type eq 'jitar') {
	    $problemID = join('.',jitar_id_to_seq($problemID));
	}

	return $r->maketext("[_1]: Problem [_2]",$setID, $problemID);
}

# now altered to outsource most output operations to the template, main functions now are simply error checking and answer processing - ghe3
sub body {
	my $self = shift;
	my $set = $self->{set};
	my $problem = $self->{problem};
	my $pg = $self->{pg};

	print CGI::p("Entering Problem::body subroutine.  
	         This indicates an old style system.template file -- consider upgrading. ",
	         caller(1), );

	my $valid = WeBWorK::ContentGenerator::ProblemUtil::ProblemUtil::check_invalid($self);
	unless($valid eq "valid"){
		return $valid;
	}
	
	
	
	##### answer processing #####
	debug("begin answer processing");
	# if answers were submitted:
	#my $scoreRecordedMessage = WeBWorK::ContentGenerator::ProblemUtil::ProblemUtil::process_and_log_answer($self);
	debug("end answer processing");
	# output for templates that only use body instead of calling the body parts individually
	$self ->output_JS;
	$self ->output_tag_info;
	$self ->output_custom_edit_message;
	$self ->output_summary;
	$self ->output_hidden_info;
	$self ->output_form_start();
	$self ->output_problem_body;
	$self ->output_message;
	$self ->output_editorLink;
	$self ->output_checkboxes;
	$self ->output_submit_buttons;
	$self ->output_score_summary;
	$self ->output_comments;
	$self ->output_misc;
	print "</form>";
	# debugging stuff
	if (0) {
		print
			CGI::hr(),
			CGI::h2("debugging information"),
			CGI::h3("form fields"),
			ref2string($self->{formFields}),
			CGI::h3("user object"),
			ref2string($self->{user}),
			CGI::h3("set object"),
			ref2string($set),
			CGI::h3("problem object"),
			ref2string($problem),
			CGI::h3("PG object"),
			ref2string($pg, {'WeBWorK::PG::Translator' => 1});
	}
	debug("leaving body of Problem.pm");
	return "";
}

# output_form_start subroutine

# prints out the beginning of the main form, and the necessary hidden authentication fields

sub output_form_start{
	my $self = shift;
	my $r = $self->r;

	print CGI::start_form(-method=>"POST", -action=> $r->uri, -id=>"problemMainForm", -name=>"problemMainForm", onsubmit=>"submitAction()");

	print $self->hidden_authen_fields;
	return "";
}

# output_problem_body subroutine

# prints out the body of the current problem

sub output_problem_body{
	my $self = shift;
	my $pg = $self->{pg};
	my %will = %{ $self->{will} };

	print "\n";
	print CGI::div($pg->{body_text});

	return "";
}

# output_message subroutine

# prints out a message about the problem

sub output_message{
	my $self = shift;
	my $pg = $self->{pg};
	my $r = $self->r;

	print CGI::p(CGI::b($r->maketext("Note").": "). CGI::i($pg->{result}->{msg})) if $pg->{result}->{msg};
	return "";
}

# output_editorLink subroutine

# processes and prints out the correct link to the editor of the current problem

sub output_editorLink{
	
	my $self = shift;

	my $set             = $self->{set};
	my $problem         = $self->{problem};
	my $pg              = $self->{pg};
	
	my $r = $self->r;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	my $user = $r->param('user');
	
	my $courseName = $urlpath->arg("courseID");
	
	# FIXME: move editor link to top, next to problem number.
	# format as "[edit]" like we're doing with course info file, etc.
	# add edit link for set as well.
	my $editorLink = "";
	my $editorLink2 = "";
	my $editorLink3 = "";
	# if we are here without a real homework set, carry that through
	my $forced_field = [];
	$forced_field = ['sourceFilePath' =>  $r->param("sourceFilePath")] if
		($set->set_id eq 'Undefined_Set');
	if ($authz->hasPermissions($user, "modify_problem_sets") and $ce->{showeditors}->{pgproblemeditor1}) {
		my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor", $r, 
			courseID => $courseName, setID => $set->set_id, problemID => $problem->problem_id);
		my $editorURL = $self->systemLink($editorPage, params=>$forced_field);
		$editorLink = CGI::span(CGI::a({href=>$editorURL,target =>'WW_Editor1'}, $r->maketext("Edit1")));
	}
	if ($authz->hasPermissions($user, "modify_problem_sets") and $ce->{showeditors}->{pgproblemeditor2}) {
		my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor2", $r, 
			courseID => $courseName, setID => $set->set_id, problemID => $problem->problem_id);
		my $editorURL = $self->systemLink($editorPage, params=>$forced_field);
		$editorLink2 = CGI::span(CGI::a({href=>$editorURL,target =>'WW_Editor2'}, $r->maketext("Edit2")));
	}
	if ($authz->hasPermissions($user, "modify_problem_sets") and $ce->{showeditors}->{pgproblemeditor3}) {
		my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor3", $r, 
			courseID => $courseName, setID => $set->set_id, problemID => $problem->problem_id);
		my $editorURL = $self->systemLink($editorPage, params=>$forced_field);
		$editorLink3 = CGI::span(CGI::a({href=>$editorURL,target =>'WW_Editor3'}, $r->maketext("Edit3")));
	}
	##### translation errors? #####

	if ($pg->{flags}->{error_flag}) {
		if ($authz->hasPermissions($user, "view_problem_debugging_info")) {
			print $self->errorOutput($pg->{errors}, $pg->{body_text});

			print $editorLink, " ", $editorLink2, " ", $editorLink3;
		} else {
			print $self->errorOutput($pg->{errors}, $r->maketext("You do not have permission to view the details of this error."));
		}
		print "";
	}
	else{
		print $editorLink, " ", $editorLink2, " ", $editorLink3;
	}
	return "";
}

# output_checkboxes subroutine

# prints out the checkbox input elements that are available for the current problem

sub output_checkboxes{
	my $self = shift;
	my $r = $self->r;
	my %can = %{ $self->{can} };
	my %will = %{ $self->{will} };
	my $ce = $r->ce;
    my $showHintCheckbox      = $ce->{pg}->{options}->{show_hint_checkbox};
    my $showSolutionCheckbox  = $ce->{pg}->{options}->{show_solution_checkbox};
    my $useKnowlsForHints     = $ce->{pg}->{options}->{use_knowls_for_hints};
	my $useKnowlsForSolutions = $ce->{pg}->{options}->{use_knowls_for_solutions};
	if ($can{showCorrectAnswers} or $can{showAnsGroupInfo} or 
	    $can{showAnsHashInfo} or $can{showPGInfo} or $can{showResourceInfo} ) {
		print "Show: &nbsp;&nbsp;";
	}
	if ($can{showCorrectAnswers}) {
		print WeBWorK::CGI_labeled_input(
			-type	 => "checkbox",
			-id		 => "showCorrectAnswers_id",
			-label_text => $r->maketext("CorrectAnswers"),
			-input_attr => $will{showCorrectAnswers} ?
			{
				-name    => "showCorrectAnswers",
				-checked => "checked",
				-value   => 1,
			}
			:
			{
				-name    => "showCorrectAnswers",
				-value   => 1,
			}
		),"&nbsp;";
	}
	if ($can{showAnsGroupInfo}) {
		print WeBWorK::CGI_labeled_input(
			-type	 => "checkbox",
			-id		 => "showAnsGroupInfo_id",
			-label_text => $r->maketext("AnswerGroupInfo"),
			-input_attr => $will{showAnsGroupInfo} ?
			{
				-name    => "showAnsGroupInfo",
				-checked => "checked",
				-value   => 1,
			}
			:
			{
				-name    => "showAnsGroupInfo",
				-value   => 1,
			}
		),"&nbsp;";
	}
	if ($can{showResourceInfo}) {
		print WeBWorK::CGI_labeled_input(
			-type	 => "checkbox",
			-id		 => "showResourceInfo_id",
			-label_text => $r->maketext("Show Auxiliary Resources"),
			-input_attr => $will{showResourceInfo} ?
			{
				-name    => "showResourceInfo",
				-checked => "checked",
				-value   => 1,
			}
			:
			{
				-name    => "showResourceInfo",
				-value   => 1,
			}
		),"&nbsp;";
	}

	if ($can{showAnsHashInfo}) {
		print WeBWorK::CGI_labeled_input(
			-type	 => "checkbox",
			-id		 => "showAnsHashInfo_id",
			-label_text => $r->maketext("AnswerHashInfo"),
			-input_attr => $will{showAnsHashInfo} ?
			{
				-name    => "showAnsHashInfo",
				-checked => "checked",
				-value   => 1,
			}
			:
			{
				-name    => "showAnsHashInfo",
				-value   => 1,
			}
		),"&nbsp;";
	}
	
	if ($can{showPGInfo}) {
		print WeBWorK::CGI_labeled_input(
			-type	 => "checkbox",
			-id		 => "showPGInfo_id",
			-label_text => $r->maketext("PGInfo"),
			-input_attr => $will{showPGInfo} ?
			{
				-name    => "showPGInfo",
				-checked => "checked",
				-value   => 1,
			}
			:
			{
				-name    => "showPGInfo",
				-value   => 1,
			}
		),"&nbsp;";
	}

	#  warn "can showHints $can{showHints} can show solutions $can{showSolutions}";
	if ($can{showHints} ) {
	  # warn "can showHints is ", $can{showHints};
		if ($showHintCheckbox or not $useKnowlsForHints) { # always allow checkbox to display if knowls are not used.
			print WeBWorK::CGI_labeled_input(
				-type	 => "checkbox",
				-id		 => "showHints_id",
				-label_text => $r->maketext("Show Hints"),
				-input_attr => $will{showHints} ?
				{
					-name    => "showHints",
					-checked => "checked",
					-value   => 1,
				}
				:
				{
					-name    => "showHints",
					-value   => 1,
				}
			),"&nbsp;";
		} else {
			print CGI::hidden({name => "showHints", id=>"showHints_id", value => 1})

		}
	}
	
	if ($can{showSolutions} ) {
	  if (  $showSolutionCheckbox or not $useKnowlsForSolutions ) { # always allow checkbox to display if knowls are not used.
		print WeBWorK::CGI_labeled_input(
			-type	 => "checkbox",
			-id		 => "showSolutions_id",
			-label_text => $r->maketext("Show Solutions"),
			-input_attr => $will{showSolutions} ?
			{
				-name    => "showSolutions",
				-checked => "checked",
				-value   => 1,
			}
			:
			{
				-name    => "showSolutions",
				-value   => 1,
			}
		),"&nbsp;";
	  } else {
	    print CGI::hidden({id=>"showSolutions_id", name => "showSolutions", value=>1})
	  }
	}
	

	if ($can{showCorrectAnswers} or $can{showAnsGroupInfo} or 
	    $can{showHints} or $can{showSolutions} or # needed to put buttons on newline
	    $can{showAnsHashInfo} or $can{showPGInfo} or $can{showResourceInfo}) {
		print CGI::br();
	}
       
	return "";
}

# output_submit_buttons

# prints out the submit button input elements that are available for the current problem

sub output_submit_buttons{
	my $self = shift;
	my $r = $self->r;
	my $ce = $self->r->ce;
	my %can = %{ $self->{can} };
	my %will = %{ $self->{will} };
	my $urlpath = $r->urlpath;
	my $problem = $self->{problem};
	my $courseID = $urlpath->arg("courseID");
	my $user = $r->param('user');
	my $effectiveUser = $r->param('effectiveUser');
	my %showMeAnother = %{ $self->{showMeAnother} };
	
	if ($will{requestNewSeed}){
		print WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"submitAnswers_id", -input_attr=>{-name=>"requestNewSeed", -value=>$r->maketext("Request New Version"), -onclick=>"this.form.target='_self'"});
		return "";
	}

        print WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"previewAnswers_id", -input_attr=>{-onclick=>"this.form.target='_self'",-name=>"previewAnswers", -value=>$r->maketext("Preview My Answers")});
        if ($can{checkAnswers}) {
        	print WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"checkAnswers_id", -input_attr=>{-onclick=>"this.form.target='_self'",-name=>"checkAnswers", -value=>$r->maketext("Check Answers")});
        }
        if ($can{getSubmitButton}) {
        	if ($user ne $effectiveUser) {
        		# if acting as a student, make it clear that answer submissions will
        		# apply to the student's records, not the professor's.
        		print WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"submitAnswers_id", -input_attr=>{-name=>$r->maketext("submitAnswers"), -value=>$r->maketext("Submit Answers for [_1]", $effectiveUser)});
        	} else {
        		#print CGI::submit(-name=>"submitAnswers", -label=>"Submit Answers", -onclick=>"alert('submit button clicked')");
        		print WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"submitAnswers_id", -input_attr=>{-name=>"submitAnswers", -value=>$r->maketext("Submit Answers"), -onclick=>"this.form.target='_self'"});
        		# FIXME  for unknown reasons the -onclick label seems to have to be there in order to allow the forms onsubmit to trigger
        		# WTF???
        	}
        }
        if ($can{showMeAnother}) {
            # only output showMeAnother button if we're not on the showMeAnother page
	    my $SMAURL = $self->systemLink($urlpath->newFromModule("WeBWorK::ContentGenerator::ShowMeAnother", $r,courseID => $courseID, setID => $problem->set_id, problemID =>$problem->problem_id));

	    print CGI::a({href=>$SMAURL, class=>"set-id-tooltip", "data-toggle"=>"tooltip", "data-placement"=>"right", id=>"SMA_button", title=>"", target=>"_wwsma", 
				   "data-original-title"=>$r->maketext("You can use this feature [quant,_1,more time,more times,as many times as you want] on this problem",($showMeAnother{MaxReps}>=$showMeAnother{Count})?($showMeAnother{MaxReps}-$showMeAnother{Count}):"")}, $r->maketext("Show me another"));
        } else {
            # if showMeAnother is available for the course, and for the current problem (but not yet
            # because the student hasn't tried enough times) then gray it out; otherwise display nothing

	  # if $showMeAnother{TriesNeeded} is somehow not an integer or if its -2, use the default value 
	  $showMeAnother{TriesNeeded} = $ce->{pg}->{options}->{showMeAnotherDefault} if ($showMeAnother{TriesNeeded} !~ /^[+-]?\d+$/ || $showMeAnother{TriesNeeded} == -2);
	  
            if($ce->{pg}->{options}->{enableShowMeAnother} and $showMeAnother{TriesNeeded} >-1 ){
                my $exhausted = ($showMeAnother{Count}>=$showMeAnother{MaxReps} and $showMeAnother{MaxReps}>-1) ? "exhausted" : "";
                print CGI::span({class=>"gray_button set-id-tooltip",
                                "data-toggle"=>"tooltip", "data-placement"=>"right", title=>"",
                                "data-original-title"=>($exhausted eq "exhausted") ? $r->maketext("Feature exhausted for this problem") : $r->maketext("You must attempt this problem [quant,_1,time,times] before this feature is available",$showMeAnother{TriesNeeded}),
                                }, $r->maketext("Show me another [_1]",$exhausted));
              }
	}
	
	return "";
}

# output_score_summary subroutine

# prints out a summary of the student's current progress and status on the current problem

sub output_score_summary{
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $problem = $self->{problem};
	my $set = $self->{set};
	my $pg = $self->{pg};
	my $effectiveUser = $r->param('effectiveUser') || $r->param('user');
	my $scoreRecordedMessage = $self->{scoreRecordedMessage};
	my $submitAnswers = $self->{submitAnswers};
	my %will = %{ $self->{will} };

	my $prEnabled = $ce->{pg}->{options}->{enablePeriodicRandomization} // 0;
	my $rerandomizePeriod = $ce->{pg}->{options}->{periodicRandomizationPeriod} // 0;
	if ( (defined $problem->{prPeriod}) and ($problem->{prPeriod} > -1) ){
		$rerandomizePeriod = $problem->{prPeriod};
	}
	$prEnabled = 0 if ($rerandomizePeriod < 1);

	# score summary
	warn "num_correct =", $problem->num_correct,"num_incorrect=",$problem->num_incorrect 
	  unless defined($problem->num_correct) and defined($problem->num_incorrect) ;
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	#my $attemptsNoun = $attempts != 1 ? $r->maketext("times") : $r->maketext("time");
	
	my $prMessage = "";
	if ($prEnabled){
		my $attempts_before_rr = ($rerandomizePeriod) - ($attempts ) % ($rerandomizePeriod);
		$attempts_before_rr = 0 if ( (defined $will{requestNewSeed}) and $will{requestNewSeed});
		$prMessage =
			$r->maketext(
				" You have [quant,_1,attempt,attempts] left before new version will be requested.",
				$attempts_before_rr)
			if ($attempts_before_rr > 0);
		$prMessage =
			$r->maketext(" Request new version now.")
			if ($attempts_before_rr == 0);
	}
	$prMessage = "" if ( after($set->due_date) or before($set->open_date) );
	
	my $problem_status    = $problem->status || 0;
	my $lastScore = wwRound(0, $problem_status * 100).'%'; # Round to whole number
	my $attemptsLeft = $problem->max_attempts - $attempts;
	
	my $setClosed = 0;
	my $setClosedMessage;
	if (before($set->open_date) or after($set->due_date)) {
	  $setClosed = 1;
	  if (before($set->open_date)) {
	    $setClosedMessage = $r->maketext("This homework set is not yet open.");
	  } elsif (after($set->due_date)) {
	    $setClosedMessage = $r->maketext("This homework set is closed.");
	  }
	}
	#if (before($set->open_date) or after($set->due_date)) {
	#	$setClosed = 1;
	#	$setClosedMessage = "This homework set is closed.";
	#	if ($authz->hasPermissions($user, "view_answers")) {
	#		$setClosedMessage .= " However, since you are a privileged user, additional attempts will be recorded.";
	#	} else {
	#		$setClosedMessage .= " Additional attempts will not be recorded.";
	#	}
	#}
	print CGI::start_p();
	unless (defined( $pg->{state}->{state_summary_msg}) and $pg->{state}->{state_summary_msg}=~/\S/) {

		my $notCountedMessage = ($problem->value) ? "" : $r->maketext("(This problem will not count towards your grade.)");
		print join("",
			$submitAnswers ? $scoreRecordedMessage . CGI::br() : "",
			$r->maketext("You have attempted this problem [quant,_1,time,times].",$attempts), $prMessage, CGI::br(),
			$submitAnswers ? $r->maketext("You received a score of [_1] for this attempt.",wwRound(0, $pg->{result}->{score} * 100).'%') . CGI::br():'',
			$problem->attempted
		
		? $r->maketext("Your overall recorded score is [_1].  [_2]",$lastScore,$notCountedMessage) . CGI::br()
				: "",
			$setClosed ? $setClosedMessage : $r->maketext("You have [negquant,_1,unlimited attempts,attempt,attempts] remaining.",$attemptsLeft) 
		);
	}else {
	  print $pg->{state}->{state_summary_msg};
	}
	
	#print jitar specific informaton for students. (and notify instructor 
	# if necessary
	if ($set->set_id ne 'Undefined_Set' && $set->assignment_type() eq 'jitar') {
	  my @problemIDs = $db->listUserProblems($effectiveUser, $set->set_id);
	  @problemIDs = sort { $a <=> $b } @problemIDs;
	  
	  # get some data 
	  my @problemSeqs;
	  my $index;
	  # this sets of an array of the sequence assoicated to the 
	  #problem_id
	  for (my $i=0; $i<=$#problemIDs; $i++) {
	    $index = $i if ($problemIDs[$i] == $problem->problem_id);
	    my @seq = jitar_id_to_seq($problemIDs[$i]);
	    push @problemSeqs, \@seq;
	  }
	  
	  my $next_id = $index+1;
	  my @seq = @{$problemSeqs[$index]};
	  my @children_counts_indexs;
	  my $hasChildren = 0;
	  
	  # this does several things.  It finds the index of the next problem
	  # at the same level as the current one.  It checks to see if there
	  # are any children, and it finds which of those children count
	  # toward the grade of this problem.  
	  
	  while ($next_id <= $#problemIDs && scalar(@{$problemSeqs[$index]}) < scalar(@{$problemSeqs[$next_id]})) {
	    
	    my $childProblem = $db->getMergedProblem($effectiveUser,$set->set_id, $problemIDs[$next_id]);
	    $hasChildren = 1;
	    push @children_counts_indexs, $next_id if scalar(@{$problemSeqs[$index]}) + 1 == scalar(@{$problemSeqs[$next_id]}) && $childProblem->counts_parent_grade;
	    $next_id++;
	  }	
	  
	  # print information if this problem has open children and if the grade
	  # for this problem can be replaced by the grades of its children
	  if ( $hasChildren 
	       && (($problem->att_to_open_children != -1 && $problem->num_incorrect >= $problem->att_to_open_children) ||
		   ($problem->max_attempts != -1 && 
		    $problem->num_incorrect >= $problem->max_attempts))) {
	    print CGI::br().$r->maketext('This problem has open subproblems.  You can visit them by using the links to the left or visiting the set page.');
	    
	    if (scalar(@children_counts_indexs) == 1) {
	      print CGI::br().$r->maketext('The grade for this problem is the larger of the score for this problem, or the score of problem [_1].', join('.', @{$problemSeqs[$children_counts_indexs[0]]}));
	    } elsif (scalar(@children_counts_indexs) > 1) {
	      print CGI::br().$r->maketext('The grade for this problem is the larger of the score for this problem, or the weighted average of the problems: [_1].', join(', ', map({join('.', @{$problemSeqs[$_]})}  @children_counts_indexs)));
	    }
	  }
	  
	  
	  # print information if this set has restricted progression and if you need
	  # to finish this problem (and maybe its children) to proceed
	  if ($set->restrict_prob_progression() &&
	      $next_id <= $#problemIDs && 
	      is_jitar_problem_closed($db,$ce,$effectiveUser, $set->set_id, $problemIDs[$next_id])) {
	    if ($hasChildren) {
	      print CGI::br().$r->maketext('You will not be able to proceed to problem [_1] until you have completed, or run out of attempts, for this problem and its graded subproblems.',join('.',@{$problemSeqs[$next_id]}));
	  } elsif (scalar(@seq) == 1 ||
			   $problem->counts_parent_grade()) {
	      print CGI::br().$r->maketext('You will not be able to proceed to problem [_1] until you have completed, or run out of attempts, for this problem.',join('.',@{$problemSeqs[$next_id]}));
	    }
	  }
	  # print information if this problem counts towards the grade of its parent, 
	  # if it doesn't (and its not a top level problem) then its grade doesnt matter. 
	  if ($problem->counts_parent_grade() && scalar(@seq) != 1) {
	    pop @seq;
	    print CGI::br().$r->maketext('The score for this problem can count towards score of problem [_1].',join('.',@seq));
	  } elsif (scalar(@seq)!=1) {
	    pop @seq;
	    print CGI::br().$r->maketext('This score for this problem does not count for the score of problem [_1] or for the set.',join('.',@seq));
	  }
	  
	  # if the instructor has set this up, email the instructor a warning message if 
	  # the student has run out of attempts on a top level problem and all of its children
	  # and didn't get 100%
	  if ($submitAnswers && $set->email_instructor) {
	    my $parentProb = $db->getMergedProblem($effectiveUser,$set->set_id,seq_to_jitar_id($seq[0]));
	    warn("Couldn't find problem $seq[0] from set ".$set->set_id." in the database") unless $parentProb;
	    
	    #email instructor with a message if the student didnt finish
	    if (jitar_problem_finished($parentProb,$db) &&
		jitar_problem_adjusted_status($parentProb,$db) != 1) {
	      WeBWorK::ContentGenerator::ProblemUtil::ProblemUtil::jitar_send_warning_email($self,$parentProb);
	    }
	    
	  }   
	}
	print CGI::end_p();
	return "";
}

# output_misc subroutine

# prints out other necessary elements

sub output_misc{

	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $pg = $self->{pg};
	my %will = %{ $self->{will} };
	my $user = $r->param('user');

# 	print CGI::start_div();
# 	
# 	my $pgdebug = join(CGI::br(), @{$pg->{pgcore}->{DEBUG_messages}} );
# 	my $pgwarning = join(CGI::br(), @{$pg->{pgcore}->{WARNING_messages}} );
# 	my $pginternalerrors = join(CGI::br(),  @{$pg->{pgcore}->get_internal_debug_messages}   );
# 	my $pgerrordiv = $pgdebug||$pgwarning||$pginternalerrors;  # is 1 if any of these are non-empty
# 	
# 	print CGI::p({style=>"color:red;"}, $r->maketext("Checking additional error messages")) if $pgerrordiv  ;
#  	print CGI::p($r->maketext("pg debug"),CGI::br(), $pgdebug                 )   if $pgdebug ;
# 	print CGI::p($r->maketext("pg warning"),CGI::br(),$pgwarning                ) if $pgwarning ;	
# 	print CGI::p($r->maketext("pg internal errors"),CGI::br(), $pginternalerrors) if $pginternalerrors;
# 	print CGI::end_div()                                                          if $pgerrordiv ;
	
	# save state for viewOptions
	print  CGI::hidden(
			   -name  => "showOldAnswers",
			   -value => $will{showOldAnswers}
		   ),

		   CGI::hidden(
			   -name  => "displayMode",
			   -value => $self->{displayMode}
		   );
	print( CGI::hidden(
			   -name    => 'editMode',
			   -value   => $self->{editMode},
		   )
	) if defined($self->{editMode}) and $self->{editMode} eq 'temporaryFile';
	
	# this is a security risk -- students can use this to find the source code for the problem

	my $permissionLevel = $db->getPermissionLevel($user)->permission;
	my $professorPermissionLevel = $ce->{userRoles}->{professor};
	print( CGI::hidden(
		   		-name   => 'sourceFilePath',
		   		-value  =>  $self->{problem}->{source_file}
	))  if defined($self->{problem}->{source_file}) and $permissionLevel>= $professorPermissionLevel; # only allow this for professors

	print( CGI::hidden(
		   		-name   => 'problemSeed',
		   		-value  =>  $r->param("problemSeed")
	))  if defined($r->param("problemSeed")) and $permissionLevel>= $professorPermissionLevel; # only allow this for professors

	return "";
}

# output_comments subroutine

# prints out any instructor comments present in the latest past_answer entry

sub output_comments{
	my $self = shift;

	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;

	my $problem = $self->{problem};
	my $set = $self->{set};
	my $urlpath        = $r->urlpath;
	my $courseName     = $urlpath->arg("courseID");
	my $setID          = $urlpath->arg("setID");
	my $problemID      = $urlpath->arg("problemID");
	my $key = $r->param('key');
	my $eUserID          = $r->param('effectiveUser');
	my $displayMode   = $self->{displayMode};
	my $authz = $r->authz;
	
	my $userPastAnswerID = $db->latestProblemPastAnswer($courseName, $eUserID, $setID, $problemID); 

	#if there is a comment then render it and print it 
	if ($userPastAnswerID) {
		my $userPastAnswer = $db->getPastAnswer($userPastAnswerID);
		if ($userPastAnswer->comment_string) {

		    my $comment = $userPastAnswer->comment_string;
		    $comment = CGI::escapeHTML($comment);
		    my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
		   		    print CGI::start_div({id=>"answerComment", class=>"answerComments"});
		    print CGI::b("Instructor Comment:"),  CGI::br();
		    print $comment;
		    print <<EOS;
				<script type="text/javascript">
					MathJax.Hub.Register.StartupHook('AsciiMath Jax Config', function () {
					var AM = MathJax.InputJax.AsciiMath.AM;
					for (var i=0; i< AM.symbols.length; i++) {
						if (AM.symbols[i].input == '**') {
						AM.symbols[i] = {input:"**", tag:"msup", output:"^", tex:null, ttype: AM.TOKEN.INFIX};
						}
					}
									 });
				MathJax.Hub.Config(["input/Tex","input/AsciiMath","output/HTML-CSS"]);
	
				MathJax.Hub.Queue([ "Typeset", MathJax.Hub,'answerComment']);
				</script>
EOS
		}
	}

	return "";
}

# output_summary subroutine

# prints out the summary of the questions that the student has answered 
# for the current problem, along with available information about correctness

sub output_summary{
	
	my $self = shift;
	
	my $editMode = $self->{editMode};
	my $problem = $self->{problem};
	my $pg = $self->{pg};
	my $submitAnswers = $self->{submitAnswers};
	my %will = %{ $self->{will} };
	my %can = %{ $self->{can} };
	my $checkAnswers = $self->{checkAnswers};
	my $previewAnswers = $self->{previewAnswers};
	my $showPartialCorrectAnswers = $self->{pg}{flags}{showPartialCorrectAnswers};

	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $set = $self->{set};
	my $authz = $r->authz;
	my $user = $r->param('user');
	my $effectiveUser = $r->param('effectiveUser');
	
        # attempt summary
	#FIXME -- the following is a kludge:  if showPartialCorrectAnswers is negative don't show anything.
	# until after the due date
	# do I need to check $will{showCorrectAnswers} to make preflight work??

	if (defined($pg->{flags}->{showPartialCorrectAnswers}) and ($pg->{flags}->{showPartialCorrectAnswers} >= 0 and $submitAnswers) ) {

	    # print this if user submitted answers OR requested correct answers	    
	    my $results = $self->attemptResults($pg, 
	                    1,   # showAttemptAnswers --display the unformatted submitted answer attempt
						$will{showCorrectAnswers}, # showCorrectAnswers
						$pg->{flags}->{showPartialCorrectAnswers}, # showAttemptResults
			            1, # showSummary
			            1  # showAttemptPreview
		);	    
	    print $results;
	    
	} elsif ($will{checkAnswers}) {
	    # print this if user previewed answers
	    print CGI::div({class=>'ResultsWithError'},$r->maketext("ANSWERS ONLY CHECKED -- ANSWERS NOT RECORDED")), CGI::br();
	    print $self->attemptResults($pg, 
	    	1, # showAttemptAnswers
	    	$will{showCorrectAnswers}, # showCorrectAnswers
	    	1, # showAttemptResults
	    	1, # showSummary
	    	1  # showAttemptPreview
	    );
	    # show attempt answers
	    # show correct answers if asked
	    # show attempt results (correctness)
	    # show attempt previews
	} elsif ($previewAnswers) {
	  # print this if user previewed answers
	    print CGI::div({class=>'ResultsWithError'},$r->maketext("PREVIEW ONLY -- ANSWERS NOT RECORDED")),CGI::br(),$self->attemptResults($pg, 1, 0, 0, 0, 1);
	    # show attempt answers
	    # don't show correct answers
	    # don't show attempt results (correctness)
	    # show attempt previews
	  }
	
	if ($set->set_id ne 'Undefined_Set' && $set->assignment_type() eq 'jitar') {
	my $hasChildren = 0;
	my @problemIDs = $db->listUserProblems($effectiveUser, $set->set_id);
	@problemIDs = sort { $a <=> $b } @problemIDs;

	# get some data 
	my @problemSeqs;
	my $index;
	# this sets of an array of the sequence associated to the 
	#problem_id
	for (my $i=0; $i<=$#problemIDs; $i++) {
	    $index = $i if ($problemIDs[$i] == $problem->problem_id);
	    my @seq = jitar_id_to_seq($problemIDs[$i]);
	    push @problemSeqs, \@seq;
	}
	
	my $next_id = $index+1;
	my @seq = @{$problemSeqs[$index]};
	
	# check to see if the problem has children
	while ($next_id <= $#problemIDs && scalar(@{$problemSeqs[$index]}) < scalar(@{$problemSeqs[$next_id]})) {
	    $hasChildren = 1;
	    $next_id++;
	}	
	
	# if it has children and conditions are right, print a message
	if ( $hasChildren 
	     && (($problem->att_to_open_children != -1 && $problem->num_incorrect >= $problem->att_to_open_children) ||
		    ($problem->max_attempts != -1 && 
		     $problem->num_incorrect >= $problem->max_attempts))) {
	    print CGI::div({class=>'showMeAnotherBox'},$r->maketext('This problem has open subproblems.  You can visit them by using the links to the left or visiting the set page.'));
	}
    }		
	    

    if (!$previewAnswers) {    # only color answers if not previewing
        if ($checkAnswers or $showPartialCorrectAnswers) { # color answers when partialCorrectAnswers is set
                                                           # or when checkAnswers is submitted
	    print CGI::start_script({type=>"text/javascript"}),
	            "addOnLoadEvent(function () {color_inputs([\n  ",
		      join(",\n  ",map {"'$_'"} @{$self->{correct_ids}||[]}),
	            "\n],[\n  ",
		      join(",\n  ",map {"'$_'"} @{$self->{incorrect_ids}||[]}),
	            "]\n)});",
	          CGI::end_script();
	}
    }
	return "";
}

# prints the achievement message if there is one

sub output_achievement_message{

    	my $self = shift;
	
	my $editMode = $self->{editMode};
	my $problem = $self->{problem};
	my $pg = $self->{pg};
	my $submitAnswers = $self->{submitAnswers};
	my %will = %{ $self->{will} };

	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;

	my $authz = $r->authz;
	my $user = $r->param('user');
	
	#If achievements enabled, and if we are not in a try it page, check to see if there are new ones.and print them
	if ($ce->{achievementsEnabled} && $will{recordAnswers} 
	    && $submitAnswers && $problem->set_id ne 'Undefined_Set') {
	    my $achievementMessage = WeBWorK::AchievementEvaluator::checkForAchievements($problem, $pg, $db, $ce);
	    print $achievementMessage;
	}
	

	return "";
}

# output_tag_info
# Puts the tags in the page

sub output_tag_info{
	my $self = shift;
	my $r = $self->r;
	my $authz = $r->authz;
	my $user = $r->param('user');
	if ($authz->hasPermissions($user, "modify_tags")) {
		print CGI::p(CGI::div({id=>'tagger'}, ''));
                print $self->hidden_authen_fields;
                my $courseID = $self->r->urlpath->arg("courseID");
                print CGI::hidden({id=>'hidden_courseID',name=>'courseID',default=>$courseID });
		my $templatedir = $r->ce->{courseDirs}->{templates};
		my $sourceFilePath = $templatedir .'/'. $self->{problem}->{source_file};
		$sourceFilePath =~ s/'/\\'/g;
		print CGI::start_script({type=>"text/javascript"}), "mytw = new tag_widget('tagger','$sourceFilePath')",CGI::end_script();
	}
	return "";
}

# output_custom_edit_message

# prints out a custom edit message

sub output_custom_edit_message{
	my $self = shift;
	my $r = $self->r;
	my $authz = $r->authz;
	my $user = $r->param('user');
	my $editMode = $self->{editMode};
	my $problem = $self->{problem};
	
	# custom message for editor
	if ($authz->hasPermissions($user, "modify_problem_sets") and defined $editMode) {
		if ($editMode eq "temporaryFile") {
			print CGI::p(CGI::div({class=>'temporaryFile'}, $r->maketext("Viewing temporary file: "), $problem->source_file));
		} elsif ($editMode eq "savedFile") {
			# taken care of in the initialization phase
		}
	}
	
	return "";
}




# output_past_answer_button

# prints out the "Show Past Answers" button

sub output_past_answer_button{
	my $self = shift;
	my $r = $self->r;
	my $problem = $self->{problem};
	
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	my $user = $r->param('user');
	
	my $courseName = $urlpath->arg("courseID");

	my $pastAnswersPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::ShowAnswers", $r, 
		courseID => $courseName);
	my $showPastAnswersURL = $self->systemLink($pastAnswersPage, authen => 0); # no authen info for form action
	
	my $problemNumber = $problem->problem_id;
	my $setRecord = $r->db->getGlobalSet($problem->set_id);
	if ( defined($setRecord) && $setRecord->assignment_type eq 'jitar' ) {
	    $problemNumber = join('.',jitar_id_to_seq($problemNumber));
	}

	# print answer inspection button
	if ($authz->hasPermissions($user, "view_answers")) {
	        my $hiddenFields = $self->hidden_authen_fields;
		$hiddenFields =~ s/\"hidden_/\"pastans-hidden_/g;
		print "\n",
			CGI::start_form(-method=>"POST",-action=>$showPastAnswersURL,-target=>"WW_Info"),"\n",
			$hiddenFields,"\n",
			CGI::hidden(-name => 'courseID',  -value=>$courseName), "\n",
			CGI::hidden(-name => 'selected_problems', -value=>$problemNumber), "\n",
			CGI::hidden(-name => 'selected_sets',  -value=>$problem->set_id), "\n",
               		CGI::hidden(-name => 'selected_users',  -value=>$problem->user_id), "\n",
			CGI::p(
				CGI::submit(-name => 'action',  -value=>$r->maketext("Show Past Answers"))
			), "\n",
			CGI::end_form();
	}
	
	return "";
}

# output_email_instructor subroutine

# prints out the "Email Instructor" button

sub output_email_instructor{
	my $self = shift;
	my $problem = $self->{problem};
	my %will = %{ $self->{will} };
	my $pg = $self->{pg};

	print $self->feedbackMacro(
		module             => __PACKAGE__,
		set                => $self->{set}->set_id,
		problem            => $problem->problem_id,
		displayMode        => $self->{displayMode},
		showOldAnswers     => $will{showOldAnswers},
		showCorrectAnswers => $will{showCorrectAnswers},
		showHints          => $will{showHints},
		showSolutions      => $will{showSolutions},
		pg_object          => $pg,
	);
	
	return "";
}

# output_hidden_info subroutine
# outputs the hidden fields required for the form

sub output_hidden_info {
    my $self = shift;
	print CGI::hidden({name => "templateName", 
	            id=>"templateName_id", value => $self->{templateName}}
	       );
    return "";
}

# output_JS subroutine

# prints out the wz_tooltip.js script for the current site.

sub output_wztooltip_JS{
	
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};
	
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/legacy/vendor/wz_tooltip.js"}), CGI::end_script();
	return "";
}

# outputs all of the Javascript needed for this page. 
# The main javascript needed here is color.js, which colors input fields based on whether or not 
# they are correct when answers are submitted.  When a problem attempts results, it prints out hidden fields containing identification 
# information for the fields that were correct and the fields that were incorrect.  color.js collects of the correct and incorrect fields into 
# two arrays using the information gathered from the hidden fields, and then loops through and changes the styles so 
# that the colors will show up correctly.

sub output_JS{
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};

	# This adds the dragmath functionality
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/legacy/dragmath.js"}), CGI::end_script();
	
	# This file declares a function called addOnLoadEvent which allows multiple different scripts to add to a single onLoadEvent handler on a page.
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/AddOnLoad/addOnLoadEvent.js"}), CGI::end_script();
	
	# This is a file which initializes the proper JAVA applets should they be needed for the current problem.
	print CGI::start_script({type=>"tesxt/javascript", src=>"$site_url/js/legacy/java_init.js"}), CGI::end_script();
	
	# The color.js file, which uses javascript to color the input fields based on whether they are correct or incorrect.
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/InputColor/color.js"}), CGI::end_script();
	
	# The Base64.js file, which handles base64 encoding and decoding
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/Base64/Base64.js"}), CGI::end_script();
	
	# This is for MathView.  
	if ($self->{will}->{useMathView}) {
	    if ((grep(/MathJax/,@{$ce->{pg}->{displayModes}}))) {
		print CGI::start_script({type=>"text/javascript", src=>"$ce->{webworkURLs}->{MathJax}"}), CGI::end_script();
		print CGI::start_script({type=>"text/javascript"});
		print "mathView_basepath = \"$site_url/images/mathview/\";";
		print CGI::end_script();
		print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/MathView/$ce->{pg}->{options}->{mathViewLocale}"}), CGI::end_script();
		print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/MathView/mathview.js"}), CGI::end_script();
	    } else {
		warn ("MathJax must be installed and enabled as a display mode for the math viewer to work");
	    }
	}
	
	# This is for knowls
        # Javascript and style for knowls
        print qq{
           <script type="text/javascript" src="$site_url/js/vendor/underscore/underscore.js"></script>
           <script type="text/javascript" src="$site_url/js/legacy/vendor/knowl.js"></script>};

	# This is for tagging menus (if allowed)
	if ($r->authz->hasPermissions($r->param('user'), "modify_tags")) {
		print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/TagWidget/tagwidget.js"}), CGI::end_script();
	}

	# This is for any page specific js.  Right now its just used for achievement popups
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/Problem/problem.js"}), CGI::end_script();

	return "";
}

sub output_CSS {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};

        # Javascript and style for knowls
        print qq{
           <link href="$site_url/css/knowlstyle.css" rel="stylesheet" type="text/css" />};

	#style for mathview
	if ($self->{will}->{useMathView}) {
	    print "<link href=\"$site_url/js/apps/MathView/mathview.css\" rel=\"stylesheet\" />";
	}
	
	return "";
}

sub output_achievement_CSS {
    return "";
}

#Tells template to output stylesheet and js for Jquery-UI
sub output_jquery_ui{
	return "";
}

# Simply here to indicate to the template that this page has body part methods which can be called

sub can_body_parts{
	return "";
}

1;
