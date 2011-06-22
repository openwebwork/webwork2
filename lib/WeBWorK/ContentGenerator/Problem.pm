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
use base qw(WeBWorK::ContentGenerator);

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
use WeBWorK::Utils qw(readFile writeLog writeCourseLog encodeAnswers decodeAnswers
	ref2string makeTempDirectory path_is_subdir sortByName before after between);
use WeBWorK::DB::Utils qw(global2user user2global);
use URI::Escape;

use WeBWorK::Utils::Tasks qw(fake_set fake_problem);

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
	#my ($self, $User, $EffectiveUser, $Set, $Problem) = @_;
	
	return 1;
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

sub can_showHints {
	#my ($self, $User, $EffectiveUser, $Set, $Problem) = @_;
	
	return 1;
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

# Reset the default in some cases
sub set_showOldAnswers_default {
	my ($self, $ce, $userName, $authz, $set) = @_;
	# these people always use the system/course default, so don't
	# override the value of ...->{showOldAnswers}
	return if $authz->hasPermissions($userName, "can_always_use_show_old_answers_default");
	# this person should always default to 0
	$ce->{pg}->{options}->{showOldAnswers} = 0
		unless ($authz->hasPermissions($userName, "can_show_old_answers_by_default"));
	# we are after the due date, so default to not showing it
	$ce->{pg}->{options}->{showOldAnswers} = 0 if $set->{due_date} && after($set->{due_date});
}

################################################################################
# output utilities
################################################################################

# Note: the substance of attemptResults is lifted into GatewayQuiz.pm,
# with some changes to the output format

sub attemptResults {
	my $self = shift;
	my $pg = shift;
	my $showAttemptAnswers = shift;
	my $showCorrectAnswers = shift;
	my $showAttemptResults = $showAttemptAnswers && shift;
	my $showSummary = shift;
	my $showAttemptPreview = shift || 0;
	
	my $ce = $self->r->ce;
	
	# for color coding the responses.
	my @correct_ids = ();
	my @incorrect_ids = ();


	my $problemResult = $pg->{result}; # the overall result of the problem
	my @answerNames = @{ $pg->{flags}->{ANSWER_ENTRY_ORDER} };
	#warn "answer names are ", join(" ", @answerNames);
	my $showMessages = $showAttemptAnswers && grep { $pg->{answers}->{$_}->{ans_message} } @answerNames;
	
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
	
	my $showEvaluatedAnswers = $ce->{pg}->{options}->{showEvaluatedAnswers};

	my $header;
	#$header .= CGI::th("Part");
	if ($showEvaluatedAnswers) {
		$header .= $showAttemptAnswers ? CGI::th("Entered")  : "";
	}	
	$header .= $showAttemptPreview ? CGI::th("Answer Preview")  : "";
	$header .= $showCorrectAnswers ? CGI::th("Correct")  : "";
	$header .= $showAttemptResults ? CGI::th("Result")   : "";
	$header .= $showMessages       ? CGI::th("Messages") : "";
	my $fully = '';
	my @tableRows = ( $header );
	my $numCorrect = 0;
	my $numBlanks  =0;
	my $tthPreambleCache;
	foreach my $name (@answerNames) {
		my $answerResult  = $pg->{answers}->{$name};
		my $studentAnswer = $answerResult->{student_ans}; # original_student_ans
		my $preview       = ($showAttemptPreview
		                    	? $self->previewAnswer($answerResult, $imgGen, \$tthPreambleCache)
		                    	: "");
		my $correctAnswerPreview = $self->previewCorrectAnswer($answerResult, $imgGen, \$tthPreambleCache);
		my $correctAnswer = $answerResult->{correct_ans};
		my $answerScore   = $answerResult->{score};
		my $answerMessage = $showMessages ? $answerResult->{ans_message} : "";
		$answerMessage =~ s/\n/<BR>/g;
		$numCorrect += $answerScore >= 1;
		$numBlanks++ unless $studentAnswer =~/\S/ || $answerScore >= 1;   # unless student answer contains entry
		my $resultString = $answerScore >= 1 ? CGI::span({class=>"ResultsWithoutError"}, "correct") :
		                   $answerScore > 0  ? int($answerScore*100)."% correct" :
                                                       CGI::span({class=>"ResultsWithError"}, "incorrect");
		$fully = 'completely ' if $answerScore >0 and $answerScore < 1;
		
		#warn "answer $name  score $answerScore";
		push @correct_ids,   $name if $answerScore == 1;
		push @incorrect_ids, $name if $answerScore < 1;
		
		# need to capture auxiliary answers as well and identify their ids.
		
		
		my $row;
		#$row .= CGI::td($name);
		if ($showEvaluatedAnswers) {
		  $row .= $showAttemptAnswers ? CGI::td($self->nbsp($studentAnswer)) : "";
		}
		$row .= $showAttemptPreview ? CGI::td({onmouseover=>qq!Tip('$studentAnswer',SHADOW, true, 
		                    DELAY, 1000, FADEIN, 300, FADEOUT, 300, STICKY, 1, OFFSETX, -20, CLOSEBTN, true, CLICKCLOSE, false, 
		                    BGCOLOR, '#F4FF91', TITLE, 'Entered:',TITLEBGCOLOR, '#F4FF91', TITLEFONTCOLOR, '#000000')!},
		                    $self->nbsp($preview))       : "";
		$row .= $showCorrectAnswers ? CGI::td({onmouseover=> qq!Tip('$correctAnswer',SHADOW, true, 
		                    DELAY, 1000, FADEIN, 300, FADEOUT, 300, STICKY, 1, OFFSETX, -20, CLOSEBTN, true, CLICKCLOSE, false, 
		                    BGCOLOR, '#F4FF91', TITLE, 'Entered:',TITLEBGCOLOR, '#F4FF91', TITLEFONTCOLOR, '#000000')!},
		                  $self->nbsp($correctAnswerPreview)) : "";
		$row .= $showAttemptResults ? CGI::td($self->nbsp($resultString))  : "";
		$row .= $showMessages       ? CGI::td({-class=>"Message"},$self->nbsp($answerMessage)) : "";
		push @tableRows, $row;
	}
	
	# render equation images
	$imgGen->render(refresh => 1);
	
#	my $numIncorrectNoun = scalar @answerNames == 1 ? "question" : "questions";
	my $scorePercent = sprintf("%.0f%%", $problemResult->{score} * 100);
#   FIXME  -- I left the old code in in case we have to back out.
#	my $summary = "On this attempt, you answered $numCorrect out of "
#		. scalar @answerNames . " $numIncorrectNoun correct, for a score of $scorePercent.";
	my $summary = ""; 
	unless (defined($problemResult->{summary}) and $problemResult->{summary} =~ /\S/) {
		if (scalar @answerNames == 1) {  #default messages
				if ($numCorrect == scalar @answerNames) {
					$summary .= CGI::div({class=>"ResultsWithoutError"},"The answer above is correct.");
				 } else {
					 $summary .= CGI::div({class=>"ResultsWithError"},"The answer above is NOT ${fully}correct.");
				 }
		} else {
				if ($numCorrect == scalar @answerNames) {
					$summary .= CGI::div({class=>"ResultsWithoutError"},"All of the answers above are correct.");
				 } 
				 #unless ($numCorrect + $numBlanks == scalar( @answerNames)) { # this allowed you to figure out if you got one answer right.
				 elsif ($numBlanks != scalar( @answerNames)) {
					$summary .= CGI::div({class=>"ResultsWithError"},"At least one of the answers above is NOT ${fully}correct.");
				 }
				 if ($numBlanks) {
					my $s = ($numBlanks>1)?'':'s';
					$summary .= CGI::div({class=>"ResultsAlert"},"$numBlanks of the questions remain$s unanswered.");
				 }
		}
	} else {
		$summary = $problemResult->{summary};   # summary has been defined by grader
	}
	
	$self->{correct_ids}=[@correct_ids]       if @correct_ids;
	$self->{incorrect_ids} = [@incorrect_ids] if @incorrect_ids;

	return
		CGI::table({-class=>"attemptResults"}, CGI::Tr(\@tableRows))
		. ($showSummary ? CGI::p({class=>'attemptResultsSummary'},$summary) : "");
}


# Note: previewAnswer is lifted into GatewayQuiz.pm

sub previewAnswer {
	my ($self, $answerResult, $imgGen, $tthPreambleCache) = @_;
	my $ce            = $self->r->ce;
	my $effectiveUser = $self->{effectiveUser};
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
		
		# read the TTH preamble, or use the cached copy passed in from the caller
		my $tthPreamble='';
		if (defined $$tthPreambleCache) {
			$tthPreamble = $$tthPreambleCache;
		} else {
			my $tthPreambleFile = $ce->{courseDirs}->{templates} . "/tthPreamble.tex";
			if (-r $tthPreambleFile) {
				$tthPreamble = readFile($tthPreambleFile);
				# thanks to Jim Martino. each line in the definition file should end with
				#a % to prevent adding supurious paragraphs to output:
				$tthPreamble =~ s/(.)\n/$1%\n/g;
				# solves the problem if the file doesn't end with a return:
				$tthPreamble .="%\n";
				# store preamble in cache:
				$$tthPreambleCache = $tthPreamble;
			} else {
			}
		}
		
		# construct TTH command line
		my $tthCommand = $ce->{externalPrograms}->{tth}
			. " -L -f5 -u -r  2> /dev/null <<END_OF_INPUT; echo > /dev/null\n"
			. $tthPreamble . "\\[" . $tex . "\\]\n"
			. "END_OF_INPUT\n";
		
		# call tth
		my $result = `$tthCommand`;
		if ($?) {
			return "<b>[tth failed: $? $@]</b>";
		} else {
			#  avoid border problems in tables and remove unneeded initial <br>
			$result =~ s/(<table [^>]*)>/$1 CLASS="ArrayLayout">/gi;
			$result =~ s!\s*<br clear="all" />!!;
			return $result;
		}
		
	} elsif ($displayMode eq "images") {
		$imgGen->add($tex);
	} elsif ($displayMode eq "MathJax") {
		return '<span class="MathJax_Preview">[math]</span><script type="math/tex; mode=display">'.$tex.'</script>';
	} elsif ($displayMode eq "jsMath") {
		$tex =~ s/&/&amp;/g; $tex =~ s/</&lt;/g; $tex =~ s/>/&gt;/g;
		return '<SPAN CLASS="math">\\displaystyle{'.$tex.'}</SPAN>';
	}
}
sub previewCorrectAnswer {
	my ($self, $answerResult, $imgGen, $tthPreambleCache) = @_;
	my $ce            = $self->r->ce;
	my $effectiveUser = $self->{effectiveUser};
	my $set           = $self->{set};
	my $problem       = $self->{problem};
	my $displayMode   = $self->{displayMode};
	
	# note: right now, we have to do things completely differently when we are
	# rendering math from INSIDE the translator and from OUTSIDE the translator.
	# so we'll just deal with each case explicitly here. there's some code
	# duplication that can be dealt with later by abstracting out tth/dvipng/etc.
	
	my $tex = $answerResult->{correct_ans_latex_string};
	return $answerResult->{correct_ans} unless defined $tex and $tex=~/\S/;   # some answers don't have latex strings defined
	# return "" unless defined $tex and $tex ne "";
	
	if ($displayMode eq "plainText") {
		return $tex;
	} elsif ($displayMode eq "formattedText") {
		
		# read the TTH preamble, or use the cached copy passed in from the caller
		my $tthPreamble='';
		if (defined $$tthPreambleCache) {
			$tthPreamble = $$tthPreambleCache;
		} else {
			my $tthPreambleFile = $ce->{courseDirs}->{templates} . "/tthPreamble.tex";
			if (-r $tthPreambleFile) {
				$tthPreamble = readFile($tthPreambleFile);
				# thanks to Jim Martino. each line in the definition file should end with
				#a % to prevent adding supurious paragraphs to output:
				$tthPreamble =~ s/(.)\n/$1%\n/g;
				# solves the problem if the file doesn't end with a return:
				$tthPreamble .="%\n";
				# store preamble in cache:
				$$tthPreambleCache = $tthPreamble;
			} else {
			}
		}
		
		# construct TTH command line
		my $tthCommand = $ce->{externalPrograms}->{tth}
			. " -L -f5 -u -r  2> /dev/null <<END_OF_INPUT; echo > /dev/null\n"
			. $tthPreamble . "\\[" . $tex . "\\]\n"
			. "END_OF_INPUT\n";
		
		# call tth
		my $result = `$tthCommand`;
		if ($?) {
			return "<b>[tth failed: $? $@]</b>";
		} else {
			#  avoid border problems in tables and remove unneeded initial <br>
			$result =~ s/(<table [^>]*)>/$1 CLASS="ArrayLayout">/gi;
			$result =~ s!\s*<br clear="all" />!!;
			return $result;
		}
		
	} elsif ($displayMode eq "images") {
		$imgGen->add($tex);
	} elsif ($displayMode eq "MathJax") {
		return '<span class="MathJax_Preview">[math]</span><script type="math/tex; mode=display">'.$tex.'</script>';
	} elsif ($displayMode eq "jsMath") {
		$tex =~ s/&/&amp;/g; $tex =~ s/</&lt;/g; $tex =~ s/>/&gt;/g;
		return '<SPAN CLASS="math">\\displaystyle{'.$tex.'}</SPAN>';
	}
}

################################################################################
# Template escape implementations
################################################################################

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
	my $set = $db->getMergedSet($effectiveUserName, $setName); # checked

	$self->set_showOldAnswers_default($ce, $userName, $authz, $set);

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
		if (defined $problemSeed) {
			$problem->problem_seed($problemSeed);
		}

		my $visiblityStateClass = ($set->visible) ? "visible" : "hidden";
		my $visiblityStateText = ($set->visible) ? "visible to students." : "hidden from students.";
		$self->addmessage(CGI::span("This set is " . CGI::font({class=>$visiblityStateClass}, $visiblityStateText)));

  # test for additional problem validity if it's not already invalid
        } else {
		$self->{invalidProblem} = !(defined $problem and ($set->visible || $authz->hasPermissions($userName, "view_hidden_sets")));
		
		$self->addbadmessage(CGI::p("This problem will not count towards your grade.")) if $problem and not $problem->value and not $self->{invalidProblem};
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
	my $displayMode        = $r->param("displayMode") || $ce->{pg}->{options}->{displayMode};
	my $redisplay          = $r->param("redisplay");
	my $submitAnswers      = $r->param("submitAnswers");
	my $checkAnswers       = $r->param("checkAnswers");
	my $previewAnswers     = $r->param("previewAnswers");
	
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	$self->{displayMode}    = $displayMode;
	$self->{redisplay}      = $redisplay;
	$self->{submitAnswers}  = $submitAnswers;
	$self->{checkAnswers}   = $checkAnswers;
	$self->{previewAnswers} = $previewAnswers;
	$self->{formFields}     = $formFields;

	# get result and send to message
	my $status_message = $r->param("status_message");
	$self->addmessage(CGI::p("$status_message")) if $status_message;

	# now that we've set all the necessary variables quit out if the set or problem is invalid
	return if $self->{invalidSet} || $self->{invalidProblem};
	
	##### permissions #####

	# what does the user want to do?
	#FIXME  There is a problem with checkboxes -- if they are not checked they are invisible.  Hence if the default mode in $ce is 1
	# there is no way to override this.  Probably this is ok for the last three options, but it was definitely not ok for showing
	# saved answers which is normally on, but you want to be able to turn it off!  This section should be moved to ContentGenerator
	# so that you can set these options anywhere.  We also need mechanisms for making them sticky.
	# Note: ProblemSet and ProblemSets might set showOldAnswers to '', which
	#       needs to be treated as if it is not set.
	my %want = (
		showOldAnswers     => (defined($r->param("showOldAnswers")) and $r->param("showOldAnswers") ne '') ? $r->param("showOldAnswers")  : $ce->{pg}->{options}->{showOldAnswers},
		showCorrectAnswers => $r->param("showCorrectAnswers") || $ce->{pg}->{options}->{showCorrectAnswers},
		showHints          => $r->param("showHints")          || $ce->{pg}->{options}->{showHints},
		showSolutions      => $r->param("showSolutions")      || $ce->{pg}->{options}->{showSolutions},
		recordAnswers      => $submitAnswers,
		checkAnswers       => $checkAnswers,
		getSubmitButton    => 1,
	);
	
	# are certain options enforced?
	my %must = (
		showOldAnswers     => 0,
		showCorrectAnswers => 0,
		showHints          => 0,
		showSolutions      => 0,
		recordAnswers      => ! $authz->hasPermissions($userName, "avoid_recording_answers"),
		checkAnswers       => 0,
		getSubmitButton    => 0,
	);
	 
	# does the user have permission to use certain options?
	my @args = ($user, $effectiveUser, $set, $problem);
	my %can = (
		showOldAnswers     => $self->can_showOldAnswers(@args),
		showCorrectAnswers => $self->can_showCorrectAnswers(@args),
		showHints          => $self->can_showHints(@args),
		showSolutions      => $self->can_showSolutions(@args),
		recordAnswers      => $self->can_recordAnswers(@args, 0),
		checkAnswers       => $self->can_checkAnswers(@args, $submitAnswers),
		getSubmitButton    => $self->can_recordAnswers(@args, $submitAnswers),
	);
	
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
			showSolutions   => $will{showSolutions},
			refreshMath2img => $will{showHints} || $will{showSolutions},
			processAnswers  => 1,
			permissionLevel => $db->getPermissionLevel($userName)->permission,
			effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
		},
	);

	debug("end pg processing");
	
	##### fix hint/solution options #####
	
	$can{showHints}     &&= $pg->{flags}->{hintExists}  
	                    &&= $pg->{flags}->{showHintLimit}<=$pg->{state}->{num_of_incorrect_ans};
	$can{showSolutions} &&= $pg->{flags}->{solutionExists};
	
	##### store fields #####
	
	$self->{want} = \%want;
	$self->{must} = \%must;
	$self->{can}  = \%can;
	$self->{will} = \%will;
	$self->{pg} = $pg;
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

	return "" if ( $self->{invalidSet} );
	return $self->{pg}->{head_text} if $self->{pg}->{head_text};
}

sub options {
	my ($self) = @_;
	#warn "doing options in Problem";
	
	# don't show options if we don't have anything to show
	return "" if $self->{invalidSet} or $self->{invalidProblem};
	
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

sub siblings {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	# can't show sibling problems if the set is invalid
	return "" if $self->{invalidSet};
	
	my $courseID = $urlpath->arg("courseID");
	my $setID = $self->{set}->set_id;
	my $eUserID = $r->param("effectiveUser");
	my @problemIDs = sort { $a <=> $b } $db->listUserProblems($eUserID, $setID);
	
	print CGI::start_div({class=>"info-box", id=>"fisheye"});
	print CGI::h2("Problems");
	#print CGI::start_ul({class=>"LinksMenu"});
	#print CGI::start_li();
	#print CGI::span({style=>"font-size:larger"}, "Problems");
	print CGI::start_ul();

	foreach my $problemID (@problemIDs) {
		my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",
			courseID => $courseID, setID => $setID, problemID => $problemID);
		print CGI::li(CGI::a( {href=>$self->systemLink($problemPage, 
													params=>{  displayMode => $self->{displayMode}, 
															   showOldAnswers => $self->{will}->{showOldAnswers}
															})},  "Problem $problemID")
	   );
	}

	print CGI::end_ul();
	#print CGI::end_li();
	#print CGI::end_ul();
	print CGI::end_div();

	return "";
}

sub nav {
	my ($self, $args) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $urlpath = $r->urlpath;

	return "" if ( $self->{invalidSet} );

	my $courseID = $urlpath->arg("courseID");
	my $setID = $self->{set}->set_id if !($self->{invalidSet});
	my $problemID = $self->{problem}->problem_id if !($self->{invalidProblem});
	my $eUserID = $r->param("effectiveUser");

	my ($prevID, $nextID);

	if (!$self->{invalidProblem}) {
		my @problemIDs = $db->listUserProblems($eUserID, $setID);
		foreach my $id (@problemIDs) {
			$prevID = $id if $id < $problemID
				and (not defined $prevID or $id > $prevID);
			$nextID = $id if $id > $problemID
				and (not defined $nextID or $id < $nextID);
		}
	}

	my @links;

	if ($prevID) {
		my $prevPage = $urlpath->newFromModule(__PACKAGE__,
			courseID => $courseID, setID => $setID, problemID => $prevID);
		push @links, "Previous Problem", $r->location . $prevPage->path, "navPrev";
	} else {
		push @links, "Previous Problem", "", "navPrevGrey";
	}

	if (defined($setID) && $setID ne 'Undefined_Set') {
		push @links, "Problem List", $r->location . $urlpath->parent->path, "navProbList";
	} else {
		push @links, "Problem List", "", "navProbListGrey";
	}

	if ($nextID) {
		my $nextPage = $urlpath->newFromModule(__PACKAGE__,
			courseID => $courseID, setID => $setID, problemID => $nextID);
		push @links, "Next Problem", $r->location . $nextPage->path, "navNext";
	} else {
		push @links, "Next Problem", "", "navNextGrey";
	}

	my $tail = "";

	$tail .= "&displayMode=".$self->{displayMode} if defined $self->{displayMode};
	$tail .= "&showOldAnswers=".$self->{will}->{showOldAnswers}
		if defined $self->{will}->{showOldAnswers};
	return $self->navMacro($args, $tail, @links);
}

sub title {
	my ($self) = @_;

	# using the url arguments won't break if the set/problem are invalid
	my $setID = WeBWorK::ContentGenerator::underscore2nbsp($self->r->urlpath->arg("setID"));
	my $problemID = $self->r->urlpath->arg("problemID");

	return "$setID: Problem $problemID";
}

sub body {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	my $user = $r->param('user');
	my $effectiveUser = $r->param('effectiveUser');
	if ( $self->{invalidSet} ) { 
		return CGI::div({class=>"ResultsWithError"},
				CGI::p("The selected problem set (" .
				       $urlpath->arg("setID") . ") is not " .
				       "a valid set for $effectiveUser:"),
				CGI::p($self->{invalidSet}));
	}
	
	if ($self->{invalidProblem}) {
		return CGI::div({class=>"ResultsWithError"},
			CGI::p("The selected problem (" . $urlpath->arg("problemID") . ") is not a valid problem for set " . $self->{set}->set_id . "."));
	}	

	# unpack some useful variables
	my $set             = $self->{set};
	my $problem         = $self->{problem};
	my $editMode        = $self->{editMode};
	my $submitAnswers   = $self->{submitAnswers};
	my $checkAnswers    = $self->{checkAnswers};
	my $previewAnswers  = $self->{previewAnswers};
	my %want            = %{ $self->{want} };
	my %can             = %{ $self->{can}  };
	my %must            = %{ $self->{must} };
	my %will            = %{ $self->{will} };
	my $pg              = $self->{pg};
	
	my $courseName = $urlpath->arg("courseID");
	
	# FIXME: move editor link to top, next to problem number.
	# format as "[edit]" like we're doing with course info file, etc.
	# add edit link for set as well.
	my $editorLink = "";
	# if we are here without a real homework set, carry that through
	my $forced_field = [];
	$forced_field = ['sourceFilePath' =>  $r->param("sourceFilePath")] if
		($set->set_id eq 'Undefined_Set');
	if ($authz->hasPermissions($user, "modify_problem_sets")) {
		my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
			courseID => $courseName, setID => $set->set_id, problemID => $problem->problem_id);
		my $editorURL = $self->systemLink($editorPage, params=>$forced_field);
		$editorLink = CGI::p(CGI::a({href=>$editorURL,target =>'WW_Editor'}, "Edit this problem"));
	}
	
	##### translation errors? #####

	if ($pg->{flags}->{error_flag}) {
		if ($authz->hasPermissions($user, "view_problem_debugging_info")) {
			print $self->errorOutput($pg->{errors}, $pg->{body_text});
		} else {
			print $self->errorOutput($pg->{errors}, "You do not have permission to view the details of this error.");
		}
		print $editorLink;
		return "";
	}
	
	##### answer processing #####
	debug("begin answer processing");
	# if answers were submitted:
	my $scoreRecordedMessage;
	my $pureProblem;
	if ($submitAnswers) {
		# get a "pure" (unmerged) UserProblem to modify
		# this will be undefined if the problem has not been assigned to this user
		$pureProblem = $db->getUserProblem($problem->user_id, $problem->set_id, $problem->problem_id); # checked
		if (defined $pureProblem) {
			# store answers in DB for sticky answers
			my %answersToStore;
			my %answerHash = %{ $pg->{answers} };
			$answersToStore{$_} = $self->{formFields}->{$_}  #$answerHash{$_}->{original_student_ans} -- this may have been modified for fields with multiple values.  Don't use it!!
				foreach (keys %answerHash);
			
			# There may be some more answers to store -- one which are auxiliary entries to a primary answer.  Evaluating
			# matrices works in this way, only the first answer triggers an answer evaluator, the rest are just inputs
			# however we need to store them.  Fortunately they are still in the input form.
			my @extra_answer_names  = @{ $pg->{flags}->{KEPT_EXTRA_ANSWERS}};
			$answersToStore{$_} = $self->{formFields}->{$_} foreach  (@extra_answer_names);
			
			# Now let's encode these answers to store them -- append the extra answers to the end of answer entry order
			my @answer_order = (@{$pg->{flags}->{ANSWER_ENTRY_ORDER}}, @extra_answer_names);
			my $answerString = encodeAnswers(%answersToStore,
				 @answer_order);
			
			# store last answer to database
			$problem->last_answer($answerString);
			$pureProblem->last_answer($answerString);
			$db->putUserProblem($pureProblem);
			
			# store state in DB if it makes sense
			if ($will{recordAnswers}) {
				$problem->status($pg->{state}->{recorded_score});
				$problem->sub_status($pg->{state}->{sub_recorded_score});
				$problem->attempted(1);
				$problem->num_correct($pg->{state}->{num_of_correct_ans});
				$problem->num_incorrect($pg->{state}->{num_of_incorrect_ans});
				$pureProblem->status($pg->{state}->{recorded_score});
				$pureProblem->sub_status($pg->{state}->{sub_recorded_score});
				$pureProblem->attempted(1);
				$pureProblem->num_correct($pg->{state}->{num_of_correct_ans});
				$pureProblem->num_incorrect($pg->{state}->{num_of_incorrect_ans});
				if ($db->putUserProblem($pureProblem)) {
					$scoreRecordedMessage = "Your score was recorded.";
				} else {
					$scoreRecordedMessage = "Your score was not recorded because there was a failure in storing the problem record to the database.";
				}
				# write to the transaction log, just to make sure
				writeLog($self->{ce}, "transaction",
					$problem->problem_id."\t".
					$problem->set_id."\t".
					$problem->user_id."\t".
					$problem->source_file."\t".
					$problem->value."\t".
					$problem->max_attempts."\t".
					$problem->problem_seed."\t".
					$pureProblem->status."\t".
					$pureProblem->attempted."\t".
					$pureProblem->last_answer."\t".
					$pureProblem->num_correct."\t".
					$pureProblem->num_incorrect
				);
			} else {
				if (before($set->open_date) or after($set->due_date)) {
					$scoreRecordedMessage = "Your score was not recorded because this homework set is closed.";
				} else {
					$scoreRecordedMessage = "Your score was not recorded.";
				}
			}
		} else {
			$scoreRecordedMessage = "Your score was not recorded because this problem has not been assigned to you.";
		}
	}
	
	# logging student answers

	my $answer_log    = $self->{ce}->{courseFiles}->{logs}->{'answer_log'};
	if ( defined($answer_log ) and defined($pureProblem)) {
		if ($submitAnswers && !$authz->hasPermissions($effectiveUser, "dont_log_past_answers")) {
		        my $answerString = ""; my $scores = "";
			my %answerHash = %{ $pg->{answers} };
			# FIXME  this is the line 552 error.  make sure original student ans is defined.
			# The fact that it is not defined is probably due to an error in some answer evaluator.
			# But I think it is useful to suppress this error message in the log.
			foreach (sortByName(undef, keys %answerHash)) {
				my $orig_ans = $answerHash{$_}->{original_student_ans};
				my $student_ans = defined $orig_ans ? $orig_ans : '';
				$answerString  .= $student_ans."\t";
				$scores .= $answerHash{$_}->{score} >= 1 ? "1" : "0";
			}
			$answerString = '' unless defined($answerString); # insure string is defined.
			writeCourseLog($self->{ce}, "answer_log",
			        join("",
						'|', $problem->user_id,
						'|', $problem->set_id,
						'|', $problem->problem_id,
						'|', $scores, "\t",
						time(),"\t",
						$answerString,
					),
			);
			
		}
	}
	
	debug("end answer processing");
	##### javaScripts #############
	my $site_url = $ce->{webworkURLs}->{htdocs};
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/wz_tooltip.js"}), CGI::end_script();

	##### output #####
	# custom message for editor
	if ($authz->hasPermissions($user, "modify_problem_sets") and defined $editMode) {
		if ($editMode eq "temporaryFile") {
			print CGI::p(CGI::div({class=>'temporaryFile'}, "Viewing temporary file: ", $problem->source_file));
		} elsif ($editMode eq "savedFile") {
			# taken care of in the initialization phase
		}
	}
	print CGI::start_div({class=>"problemHeader"});
	
	

	# attempt summary
	#FIXME -- the following is a kludge:  if showPartialCorrectAnswers is negative don't show anything.
	# until after the due date
	# do I need to check $will{showCorrectAnswers} to make preflight work??
	if (($pg->{flags}->{showPartialCorrectAnswers} >= 0 and $submitAnswers) ) {
		# print this if user submitted answers OR requested correct answers
		
		print $self->attemptResults($pg, 1,
			$will{showCorrectAnswers},
			$pg->{flags}->{showPartialCorrectAnswers}, 1, 1);
	} elsif ($checkAnswers) {
		# print this if user previewed answers
		print CGI::div({class=>'ResultsWithError'},"ANSWERS ONLY CHECKED -- ANSWERS NOT RECORDED"), CGI::br();
		print $self->attemptResults($pg, 1, $will{showCorrectAnswers}, 1, 1, 1);
			# show attempt answers
			# show correct answers if asked
			# show attempt results (correctness)
			# show attempt previews
	} elsif ($previewAnswers) {
		# print this if user previewed answers
		print CGI::div({class=>'ResultsWithError'},"PREVIEW ONLY -- ANSWERS NOT RECORDED"),CGI::br(),$self->attemptResults($pg, 1, 0, 0, 0, 1);
			# show attempt answers
			# don't show correct answers
			# don't show attempt results (correctness)
			# show attempt previews
	}
	
	print CGI::end_div();
	
	
	###########################
	# print style sheet for correct and incorrect answers
	###########################
	# always show colors for checkAnswers
	# show colors for submit answer if 
	if (($self->{checkAnswers}) or ($self->{submitAnswers} and $pg->{flags}->{showPartialCorrectAnswers}) ) {
		print CGI::start_style({type=>"text/css"});
		#FIXME -- this hack is no longer needed?
		# my $string ="";
# 		foreach my $ans_name (@{ $self->{correct_ids} }) {
# 			$string .= '#'. ( $ans_name ). $ce->{pg}{options}{correct_answer}."\n";
# 		}
# 		print $string;
# 		$string ="";
# 		foreach my $ans_name (@{ $self->{incorrect_ids} }) {
# 			$string .= '#'. ($ ans_name). $ce->{pg}{options}{incorrect_answer}."\n";
# 		}
# 		print $string;
		# the above method keeps one bad array ID from ruining all of the assignments.
		print	'#'.join(', #', @{ $self->{correct_ids} }), $ce->{pg}{options}{correct_answer},"\n"   if ref( $self->{correct_ids}  )=~/ARRAY/;   #correct  green
		print	'#'.join(', #', @{ $self->{incorrect_ids} }), $ce->{pg}{options}{incorrect_answer},"\n" if ref( $self->{incorrect_ids})=~/ARRAY/; #incorrect  reddish
		print	CGI::end_style();
	}
	###########################
	# post_header material
	###########################
    print CGI::p($pg->{post_header_text});
	###########################
	# main form
	###########################
	print "\n";
	
	print CGI::start_form(-method=>"POST", -action=> $r->uri,-name=>"problemMainForm", onsubmit=>"submitAction()");
	print $self->hidden_authen_fields;
	print "\n";
	print CGI::start_div({class=>"problem"});
	print CGI::p($pg->{body_text});
	print CGI::p(CGI::b("Note: "). CGI::i($pg->{result}->{msg})) if $pg->{result}->{msg};
	print $editorLink; # this is empty unless it is appropriate to have an editor link.
	print CGI::end_div();
	
	print CGI::start_p();
	
	if ($can{showCorrectAnswers}) {
		print CGI::checkbox(
			-name    => "showCorrectAnswers",
			-checked => $will{showCorrectAnswers},
			-label   => "Show correct answers",
			-value   => 1,
		);
	}
	if ($can{showHints}) {
		print CGI::div({style=>"color:red"},
			CGI::checkbox(
				-name    => "showHints",
				-checked => $will{showHints},
				-label   => "Show Hints",
				-value   =>1,
			)
		);
	}
	if ($can{showSolutions}) {
		print CGI::checkbox(
			-name    => "showSolutions",
			-checked => $will{showSolutions},
			-label   => "Show Solutions",
			-value   => 1,
		);
	}
	
	if ($can{showCorrectAnswers} or $can{showHints} or $can{showSolutions}) {
		print CGI::br();
	}
		
	print CGI::submit(-name=>"previewAnswers", -label=>"Preview Answers");
	if ($can{checkAnswers}) {
		print CGI::submit(-name=>"checkAnswers", -label=>"Check Answers");
	}
	if ($can{getSubmitButton}) {
		if ($user ne $effectiveUser) {
			# if acting as a student, make it clear that answer submissions will
			# apply to the student's records, not the professor's.
			print CGI::submit(-name=>"submitAnswers", -label=>"Submit Answers for $effectiveUser");
		} else {
			#print CGI::submit(-name=>"submitAnswers", -label=>"Submit Answers", -onclick=>"alert('submit button clicked')");
			print CGI::submit(-name=>"submitAnswers", -label=>"Submit Answers", -onclick=>"");
			# FIXME  for unknown reasons the -onclick label seems to have to be there in order to allow the forms onsubmit to trigger
			# WFT???
		}
	}
	
	print CGI::end_p();
	
	print CGI::start_div({class=>"scoreSummary"});
	
	# score summary
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	my $attemptsNoun = $attempts != 1 ? "times" : "time";
	my $problem_status    = $problem->status || 0;
	my $lastScore = sprintf("%.0f%%", $problem_status * 100); # Round to whole number
	my ($attemptsLeft, $attemptsLeftNoun);
	if ($problem->max_attempts == -1) {
		# unlimited attempts
		$attemptsLeft = "unlimited";
		$attemptsLeftNoun = "attempts";
	} else {
		$attemptsLeft = $problem->max_attempts - $attempts;
		$attemptsLeftNoun = $attemptsLeft == 1 ? "attempt" : "attempts";
	}
	
	my $setClosed = 0;
	my $setClosedMessage;
	if (before($set->open_date) or after($set->due_date)) {
		$setClosed = 1;
		if (before($set->open_date)) {
			$setClosedMessage = "This homework set is not yet open.";
		} elsif (after($set->due_date)) {
			$setClosedMessage = "This homework set is closed.";
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
	unless (defined( $pg->{state}->{state_summary_msg}) and $pg->{state}->{state_summary_msg}=~/\S/) {
		my $notCountedMessage = ($problem->value) ? "" : "(This problem will not count towards your grade.)";
		print CGI::p(join("",
			$submitAnswers ? $scoreRecordedMessage . CGI::br() : "",
			"You have attempted this problem $attempts $attemptsNoun.", CGI::br(),
			$submitAnswers ?"You received a score of ".sprintf("%.0f%%", $pg->{result}->{score} * 100)." for this attempt.".CGI::br():'',
			$problem->attempted
				? "Your overall recorded score is $lastScore.  $notCountedMessage" . CGI::br()
				: "",
			$setClosed ? $setClosedMessage : "You have $attemptsLeft $attemptsLeftNoun remaining."
		));
	}else {
		print CGI::p($pg->{state}->{state_summary_msg});
	}

	print CGI::end_div();
	print CGI::start_div();
	
	my $pgdebug = join(CGI::br(), @{$pg->{pgcore}->{flags}->{DEBUG_messages}} );
	my $pgwarning = join(CGI::br(), @{$pg->{pgcore}->{flags}->{WARNING_messages}} );
	my $pginternalerrors = join(CGI::br(),  @{$pg->{pgcore}->get_internal_debug_messages}   );
	my $pgerrordiv = $pgdebug||$pgwarning||$pginternalerrors;  # is 1 if any of these are non-empty
	
	print CGI::p({style=>"color:red;"}, "Checking additional error messages") if $pgerrordiv  ;
 	print CGI::p("pg debug<br/> $pgdebug"                   ) if $pgdebug ;
	print CGI::p("pg warning<br/>$pgwarning"                ) if $pgwarning ;	
	print CGI::p("pg internal errors<br/> $pginternalerrors") if $pginternalerrors;
	print CGI::end_div()                                      if $pgerrordiv ;
	
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

			
	# end of main form
	print CGI::endform();
	
	print  CGI::start_div({class=>"problemFooter"});
	
	
	my $pastAnswersPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::ShowAnswers",
		courseID => $courseName);
	my $showPastAnswersURL = $self->systemLink($pastAnswersPage, authen => 0); # no authen info for form action
		
	# print answer inspection button
	if ($authz->hasPermissions($user, "view_answers")) {
		print "\n",
			CGI::start_form(-method=>"POST",-action=>$showPastAnswersURL,-target=>"WW_Info"),"\n",
			$self->hidden_authen_fields,"\n",
			CGI::hidden(-name => 'courseID',  -value=>$courseName), "\n",
			CGI::hidden(-name => 'problemID', -value=>$problem->problem_id), "\n",
			CGI::hidden(-name => 'setID',  -value=>$problem->set_id), "\n",
			CGI::hidden(-name => 'studentUser',    -value=>$problem->user_id), "\n",
			CGI::p( {-align=>"left"},
				CGI::submit(-name => 'action',  -value=>'Show Past Answers')
			), "\n",
			CGI::endform();
	}
	
	
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
	
	print CGI::end_div();
	
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

1;
