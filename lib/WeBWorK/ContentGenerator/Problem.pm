################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator::Problem - Allow a student to interact with a problem.

=cut

use WeBWorK::HTML::SingleProblemGrader;
use WeBWorK::Debug;
use WeBWorK::Utils qw(decodeAnswers wwRound);
use WeBWorK::Utils::DateTime qw(before between after);
use WeBWorK::Utils::Files qw(path_is_subdir);
use WeBWorK::Utils::JITAR qw(seq_to_jitar_id jitar_id_to_seq is_jitar_problem_hidden is_jitar_problem_closed
	jitar_problem_finished jitar_problem_adjusted_status);
use WeBWorK::Utils::LanguageAndDirection qw(get_problem_lang_and_dir);
use WeBWorK::Utils::ProblemProcessing qw(process_and_log_answer jitar_send_warning_email compute_reduced_score
	compute_unreduced_score);
use WeBWorK::Utils::Rendering qw(getTranslatorDebuggingOptions renderPG);
use WeBWorK::Utils::Sets qw(is_restricted format_set_name_display);
use WeBWorK::AchievementEvaluator qw(checkForAchievements);
use WeBWorK::DB::Utils qw(global2user fake_set fake_problem);
use WeBWorK::Localize;
use WeBWorK::AchievementEvaluator;

# GET/POST Parameters for this module
#
# Standard params:
#
#     user - user ID of real user
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

# "can" methods
# Subroutines to determine if a user "can" perform an action. Each subroutine is
# called with the following arguments:
#   ($c, $user, $effectiveUser, $set, $problem)
# In addition can_recordAnswers and can_showMeAnother have the argument
# $submitAnswers that is used to distinguish between this submission and the
# next.

sub can_showOldAnswers ($c, $user, $effectiveUser, $set, $problem) {
	return $c->authz->hasPermissions($user->user_id, 'can_show_old_answers');
}

sub can_showCorrectAnswers ($c, $user, $effectiveUser, $set, $problem) {
	return after($set->answer_date, $c->submitTime)
		|| $c->authz->hasPermissions($user->user_id, 'show_correct_answers_before_answer_date');
}

sub can_showProblemGrader ($c, $user, $effectiveUser, $set, $problem) {
	my $authz = $c->authz;

	return ($authz->hasPermissions($user->user_id, 'access_instructor_tools')
			&& $authz->hasPermissions($user->user_id, 'score_sets')
			&& $set->set_id ne 'Undefined_Set'
			&& !$c->{invalidSet});
}

sub can_showAnsGroupInfo ($c, $user, $effectiveUser, $set, $problem) {
	return $c->authz->hasPermissions($user->user_id, 'show_answer_group_info');
}

sub can_showAnsHashInfo ($c, $user, $effectiveUser, $set, $problem) {
	return $c->authz->hasPermissions($user->user_id, 'show_answer_hash_info');
}

sub can_showPGInfo ($c, $user, $effectiveUser, $set, $problem) {
	return $c->authz->hasPermissions($user->user_id, 'show_pg_info');
}

sub can_showResourceInfo ($c, $user, $effectiveUser, $set, $problem) {
	return $c->authz->hasPermissions($user->user_id, 'show_resource_info');
}

sub can_showHints ($c, $user, $effectiveUser, $set, $problem) {
	return 1 if $c->authz->hasPermissions($user->user_id, 'always_show_hint');

	my $showHintsAfter =
		$set->hide_hint                 ? -1
		: $problem->showHintsAfter > -2 ? $problem->showHintsAfter
		:                                 $c->ce->{pg}{options}{showHintsAfter};

	return $showHintsAfter > -1
		&& $showHintsAfter <= $problem->num_correct + $problem->num_incorrect + ($c->{submitAnswers} ? 1 : 0);
}

sub can_showSolutions ($c, $user, $effectiveUser, $set, $problem) {
	my $authz = $c->authz;

	return
		$authz->hasPermissions($user->user_id, 'always_show_solutions')
		|| after($set->answer_date, $c->submitTime)
		|| $authz->hasPermissions($user->user_id, 'show_solutions_before_answer_date');
}

sub can_recordAnswers ($c, $user, $effectiveUser, $set, $problem, $submitAnswers = 0) {
	my $authz = $c->authz;

	if ($user->user_id ne $effectiveUser->user_id) {
		return $authz->hasPermissions($user->user_id, 'record_answers_when_acting_as_student');
	}

	return $authz->hasPermissions($user->user_id, 'record_answers_before_open_date')
		if (before($set->open_date, $c->submitTime));

	if (between($set->open_date, $set->due_date, $c->submitTime)) {
		my $max_attempts  = $problem->max_attempts;
		my $attempts_used = $problem->num_correct + $problem->num_incorrect + ($submitAnswers ? 1 : 0);
		if ($max_attempts == -1 or $attempts_used < $max_attempts) {
			return $authz->hasPermissions($user->user_id, 'record_answers_after_open_date_with_attempts');
		} else {
			return $authz->hasPermissions($user->user_id, 'record_answers_after_open_date_without_attempts');
		}
	}

	return $authz->hasPermissions($user->user_id, 'record_answers_after_due_date')
		if (between($set->due_date, $set->answer_date, $c->submitTime));

	return $authz->hasPermissions($user->user_id, 'record_answers_after_answer_date')
		if (after($set->answer_date, $c->submitTime));

	return 0;
}

sub can_checkAnswers ($c, $user, $effectiveUser, $set, $problem) {
	my $authz = $c->authz;

	# If we can record answers then we dont need to be able to check them
	# unless we have that specific permission.
	return 0
		if ($c->can_recordAnswers($user, $effectiveUser, $set, $problem, $c->{submitAnswers})
			&& !$authz->hasPermissions($user->user_id, 'can_check_and_submit_answers'));

	return $authz->hasPermissions($user->user_id, 'check_answers_before_open_date')
		if (before($set->open_date, $c->submitTime));

	if (between($set->open_date, $set->due_date, $c->submitTime)) {
		my $max_attempts  = $problem->max_attempts;
		my $attempts_used = $problem->num_correct + $problem->num_incorrect + ($c->{submitAnswers} ? 1 : 0);
		if ($max_attempts == -1 or $attempts_used < $max_attempts) {
			return $authz->hasPermissions($user->user_id, 'check_answers_after_open_date_with_attempts');
		} else {
			return $authz->hasPermissions($user->user_id, 'check_answers_after_open_date_without_attempts');
		}
	}

	return $authz->hasPermissions($user->user_id, 'check_answers_after_due_date')
		if (between($set->due_date, $set->answer_date, $c->submitTime));

	return $authz->hasPermissions($user->user_id, 'check_answers_after_answer_date')
		if (after($set->answer_date, $c->submitTime));

	return 0;
}

sub can_useMathView ($c) {
	return $c->ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathView';
}

sub can_useMathQuill ($c) {
	return $c->ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathQuill';
}

# Check if the showMeAnother button should be allowed.  Note that this is done *before* the check to see if
# showMeAnother is possible.
sub can_showMeAnother ($c, $user, $effectiveUser, $set, $problem, $submitAnswers = 0) {
	my $ce = $c->ce;

	# If the showMeAnother button isn't enabled for the course, then it can't be used.
	return 0 unless $ce->{pg}{options}{enableShowMeAnother};

	if (after($set->open_date, $c->submitTime)
		|| $c->authz->hasPermissions($c->param('user'), 'can_use_show_me_another_early'))
	{
		$c->{showMeAnother}{TriesNeeded} = $ce->{pg}{options}{showMeAnotherDefault}
			if $c->{showMeAnother}{TriesNeeded} == -2;

		# If showMeAnother is not permitted for the problem, then it can't be used for this problem.
		return 0 unless $c->{showMeAnother}{TriesNeeded} > -1;

		# If the user is previewing or checking a showMeAnother problem corresponding to this set and problem then
		# clearly the user can use show me another.
		return 1
			if $c->authen->session->{showMeAnother}
			&& defined $c->authen->session->{showMeAnother}{setID}
			&& $c->authen->session->{showMeAnother}{setID} eq $set->set_id
			&& defined $c->authen->session->{showMeAnother}{problemID}
			&& $c->authen->session->{showMeAnother}{problemID} eq $problem->problem_id
			&& ($c->{checkAnswers} || $c->{previewAnswers});

		# If the student has not attempted the original problem enough times yet, then showMeAnother can not be used.
		return 0
			if $problem->num_correct + $problem->num_incorrect + ($submitAnswers ? 1 : 0) <
			$c->{showMeAnother}{TriesNeeded};

		# If the number of showMeAnother uses has been exceeded, then the user can not use it again.
		return 0 if $c->{showMeAnother}{Count} >= $c->{showMeAnother}{MaxReps} && $c->{showMeAnother}{MaxReps} > -1;

		return 1;
	}

	return 0;
}

sub attemptResults ($c, $pg) {
	return $pg->{result}{summary}
		? $c->c($c->tag('h2', class => 'fs-3 mb-2', $c->maketext('Results for this submission'))
			. $c->tag('div', role => 'alert', $c->b($pg->{result}{summary})))->join('')
		: '';
}

async sub pre_header_initialize ($c) {
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;

	my $setID           = $c->stash('setID');
	my $problemID       = $c->stash('problemID');
	my $userID          = $c->param('user');
	my $effectiveUserID = $c->param('effectiveUser');
	$c->{editMode} = $c->param('editMode');

	my $user          = $db->getUser($userID);
	my $effectiveUser = $db->getUser($effectiveUserID);

	return unless defined $user && defined $effectiveUser;    # This should be impossible.

	# Check that the set is valid.  $c->{invalidSet} is set in checkSet called by ContentGenerator.pm.
	return if $c->{invalidSet};

	# Obtain the merged set for $effectiveUser
	$c->{set} = $db->getMergedSet($effectiveUserID, $setID);

	# Determine if the set should be considered open.
	# It is open if the user can view unopened sets or is an instructor editing a problem from the problem editor,
	# or it is after the set open date and is not conditionally restricted and is not jitar hidden or closed.
	return
		unless $authz->hasPermissions($userID, 'view_unopened_sets')
		|| $setID eq 'Undefined_Set'
		|| (
			after($c->{set}->open_date, $c->submitTime)
			&& !(
				($ce->{options}{enableConditionalRelease} && is_restricted($db, $c->{set}, $effectiveUserID))
				|| (
					$c->{set}->assignment_type eq 'jitar'
					&& (is_jitar_problem_hidden($db, $effectiveUserID, $c->{set}->set_id, $problemID)
						|| is_jitar_problem_closed($db, $ce, $effectiveUserID, $c->{set}->set_id, $problemID))
				)
			)
		);

	# When a set is created enable_reduced_scoring is null, so we have to set it
	if ($c->{set} && $c->{set}->enable_reduced_scoring ne '0' && $c->{set}->enable_reduced_scoring ne '1') {
		my $globalSet = $db->getGlobalSet($c->{set}->set_id);
		$globalSet->enable_reduced_scoring('0');
		$db->putGlobalSet($globalSet);
		$c->{set} = $db->getMergedSet($effectiveUserID, $setID);
	}

	# Obtain the merged problem for the effective user.
	my $problem = $db->getMergedProblem($effectiveUserID, $setID, $problemID);

	if ($authz->hasPermissions($userID, 'modify_problem_sets')) {
		# This is the case of the problem editor for a user that can modify problem sets.

		# If a user set does not exist for this user and this set, then check
		# the global set.  If that does not exist, then create a fake set.  If it does, then add fake user data.
		unless (defined $c->{set}) {
			my $userSetClass = $db->{set_user}->{record};
			my $globalSet    = $db->getGlobalSet($setID);

			if (not defined $globalSet) {
				$c->{set} = fake_set($db);
			} else {
				$c->{set} = global2user($userSetClass, $globalSet);
				$c->{set}->psvn(0);
			}
		}

		# If a problem is not defined obtain the global problem, convert it to a user problem, and add fake user data.
		unless (defined $problem) {
			my $globalProblem = $db->getGlobalProblem($setID, $problemID);

			# If the global problem doesn't exist either, bail!
			if (!defined $globalProblem) {
				my $sourceFilePath = $c->param('sourceFilePath');

				# These are problems from setmaker.  If declared invalid, they won't come up.
				if (defined $sourceFilePath) {
					die 'sourceFilePath is unsafe!'
						unless path_is_subdir($sourceFilePath, $ce->{courseDirs}{templates}, 1);
				} else {
					$c->{invalidProblem} = $c->{invalidSet} = 1;
					return;
				}

				$problem = fake_problem($db);
				$problem->problem_id(1);
				$problem->source_file($sourceFilePath);
				$problem->user_id($effectiveUserID);
			} else {
				$problem = global2user($db->{problem_user}{record}, $globalProblem);
				$problem->user_id($effectiveUserID);
				$problem->problem_seed(0);
				$problem->status(0);
				$problem->attempted(0);
				$problem->last_answer('');
				$problem->num_correct(0);
				$problem->num_incorrect(0);
			}
		}

		# Now we're sure we have valid UserSet and UserProblem objects

		# Deal with possible editor overrides.
		# If the caller is asking to override the source file, and editMode calls for a temporary file, do so.
		my $sourceFilePath = $c->param('sourceFilePath');
		if (defined $c->{editMode} && $c->{editMode} eq 'temporaryFile' && defined $sourceFilePath) {
			die 'sourceFilePath is unsafe!'
				unless path_is_subdir($sourceFilePath, $ce->{courseDirs}->{templates}, 1);
			$problem->source_file($sourceFilePath);
		}

		# If the problem does not have a source file or no source file has been passed in
		# then this is really an invalid problem (probably from a bad URL).
		$c->{invalidProblem} = !(defined $sourceFilePath || $problem->source_file);

		# If the caller is asking to override the problem seed, do so.
		my $problemSeed = $c->param('problemSeed');
		if (defined $problemSeed && $problemSeed =~ /^[+-]?\d+$/) {
			$problem->problem_seed($problemSeed);
		}

		$c->addmessage($c->{set}->visible
			? $c->tag('p', class => 'font-visible m-0', $c->maketext('This set is visible to students.'))
			: $c->tag('p', class => 'font-hidden m-0',  $c->maketext('This set is hidden from students.')));

	} else {
		# Test for additional problem validity if it's not already invalid.
		$c->{invalidProblem} =
			!(defined $problem && ($c->{set}->visible || $authz->hasPermissions($userID, 'view_hidden_sets')));

		$c->addbadmessage($c->maketext('This problem will not count towards your grade.'))
			if $problem && !$problem->value && !$c->{invalidProblem};
	}

	$c->{userID}          = $userID;
	$c->{effectiveUserID} = $effectiveUserID;
	$c->{user}            = $user;
	$c->{effectiveUser}   = $effectiveUser;
	$c->{problem}         = $problem;

	# Form processing

	# Set options from form fields (see comment at top of file for form fields).
	my $displayMode = $c->param('displayMode') || $user->displayMode || $ce->{pg}->{options}->{displayMode};
	my $redisplay   = $c->param('redisplay');
	$c->{submitAnswers} = $c->param('submitAnswers');
	my $checkAnswers   = $c->param('checkAnswers');
	my $previewAnswers = $c->param('previewAnswers');
	my $requestNewSeed = $c->param('requestNewSeed') // 0;

	my $formFields = $c->req->params->to_hash;

	# Check for a page refresh which causes a cached form resubmission.  In that case this is
	# not a valid submission of answers.
	if (
		$c->{set}->set_id ne 'Undefined_Set'
		&& $c->{submitAnswers}
		&& (
			!defined $formFields->{num_attempts}
			|| (defined $formFields->{num_attempts}
				&& $formFields->{num_attempts} != $problem->num_correct + $problem->num_incorrect)
		)
		)
	{
		$c->{submitAnswers}    = 0;
		$c->{resubmitDetected} = 1;
		delete $formFields->{submitAnswers};
	}

	$c->{displayMode}    = $displayMode;
	$c->{redisplay}      = $redisplay;
	$c->{checkAnswers}   = $checkAnswers;
	$c->{previewAnswers} = $previewAnswers;
	$c->{formFields}     = $formFields;

	# Get the status message and add it to the messages.
	$c->addmessage($c->tag('p', $c->b($c->authen->flash('status_message')))) if $c->authen->flash('status_message');

	# Now that the necessary variables are set, return if the set or problem is invalid.
	return if $c->{invalidSet} || $c->{invalidProblem};

	# Construct a hash containing information for showMeAnother.
	#   TriesNeeded:   The number of times the student needs to attempt this problem before the button is available.
	#   MaxReps:       The maximum number of times that showMeAnother can be used for this problem.
	#   Count:         The number of times the student has used showMeAnother for this problem.
	$c->{showMeAnother} = {
		TriesNeeded => $problem->{showMeAnother},
		MaxReps     => $ce->{pg}{options}{showMeAnotherMaxReps},
		Count       => $problem->{showMeAnotherCount},
	};

	# Unset the showProblemGrader parameter if the "Hide Problem Grader" button was clicked.
	$c->param(showProblemGrader => undef) if $c->param('hideProblemGrader');

	# Permissions

	# What does the user want to do?
	my %want = (
		showOldAnswers     => $user->showOldAnswers ne '' ? $user->showOldAnswers : $ce->{pg}{options}{showOldAnswers},
		showCorrectAnswers => 1,
		showProblemGrader  => $c->param('showProblemGrader') || 0,
		showAnsGroupInfo   => $c->param('showAnsGroupInfo')  || $ce->{pg}{options}{showAnsGroupInfo},
		showAnsHashInfo    => $c->param('showAnsHashInfo')   || $ce->{pg}{options}{showAnsHashInfo},
		showPGInfo         => $c->param('showPGInfo')        || $ce->{pg}{options}{showPGInfo},
		showResourceInfo   => $c->param('showResourceInfo')  || $ce->{pg}{options}{showResourceInfo},
		showHints          => 1,
		showSolutions      => 1,
		useMathView        => $user->useMathView ne ''  ? $user->useMathView  : $ce->{pg}{options}{useMathView},
		useMathQuill       => $user->useMathQuill ne '' ? $user->useMathQuill : $ce->{pg}{options}{useMathQuill},
		recordAnswers      => $c->{submitAnswers} && !$authz->hasPermissions($userID, 'avoid_recording_answers'),
		checkAnswers       => $checkAnswers,
		getSubmitButton    => 1,
	);

	# Does the user have permission to use certain options?
	my @args = ($user, $effectiveUser, $c->{set}, $problem);

	my %can = (
		showOldAnswers     => $c->can_showOldAnswers(@args),
		showCorrectAnswers => $c->can_showCorrectAnswers(@args),
		showProblemGrader  => $c->can_showProblemGrader(@args),
		showAnsGroupInfo   => $c->can_showAnsGroupInfo(@args),
		showAnsHashInfo    => $c->can_showAnsHashInfo(@args),
		showPGInfo         => $c->can_showPGInfo(@args),
		showResourceInfo   => $c->can_showResourceInfo(@args),
		showHints          => $c->can_showHints(@args),
		showSolutions      => $c->can_showSolutions(@args),
		recordAnswers      => $c->can_recordAnswers(@args),
		checkAnswers       => $c->can_checkAnswers(@args),
		showMeAnother      => $c->can_showMeAnother(@args, $c->{submitAnswers}),
		getSubmitButton    => $c->can_recordAnswers(@args, $c->{submitAnswers}),
		useMathView        => $c->can_useMathView,
		useMathQuill       => $c->can_useMathQuill,
	);

	# Re-randomization based on the number of attempts and specified period
	my $prEnabled         = $ce->{pg}{options}{enablePeriodicRandomization} // 0;
	my $rerandomizePeriod = $ce->{pg}{options}{periodicRandomizationPeriod} // 0;

	$problem->{prPeriod} = $ce->{problemDefaults}{prPeriod}
		if (defined $problem->{prPeriod} && $problem->{prPeriod} =~ /^\s*$/);

	$rerandomizePeriod = $problem->{prPeriod}
		if (defined $problem->{prPeriod} && $problem->{prPeriod} > -1);

	$prEnabled = 0 if ($rerandomizePeriod < 1 || $c->{editMode});
	if ($prEnabled) {
		$problem->{prCount} = 0
			if !defined $problem->{prCount} || $problem->{prCount} =~ /^\s*$/;

		$problem->{prCount} += $c->{submitAnswers} ? 1 : 0;

		$requestNewSeed = 0
			if ($problem->{prCount} < $rerandomizePeriod || after($c->{set}->due_date, $c->submitTime));

		if ($requestNewSeed) {
			# obtain new random seed to hopefully change the problem
			$problem->{problem_seed} =
				($problem->{problem_seed} + $problem->num_correct + $problem->num_incorrect) % 10000;
			$problem->{prCount} = 0;
		}
		if ($problem->{prCount} > -1) {
			my $pureProblem = $db->getUserProblem($problem->user_id, $problem->set_id, $problem->problem_id);
			$pureProblem->problem_seed($problem->{problem_seed});
			$pureProblem->prCount($problem->{prCount});
			$db->putUserProblem($pureProblem);
		}
	}

	# Final values for options
	my %will = map { $_ => $can{$_} && $want{$_} } keys %can;

	if ($prEnabled && $problem->{prCount} >= $rerandomizePeriod && !after($c->{set}->due_date, $c->submitTime)) {
		$can{requestNewSeed}         = 1;
		$want{requestNewSeed}        = 1;
		$will{requestNewSeed}        = 1;
		$c->{showCorrectOnRandomize} = $ce->{pg}{options}{showCorrectOnRandomize};
		# If this happens, it means that the page was refreshed.  So prevent the answers from
		# being recorded and the number of attempts from being increased.
		if ($problem->{prCount} > $rerandomizePeriod) {
			$c->{resubmitDetected} = 1;
			$can{recordAnswers}    = 0;
			$want{recordAnswers}   = 0;
			$will{recordAnswers}   = 0;
		}
	}

	# If this is set to 1 below, then feedback is shown when a student returns to a previously worked problem without
	# requiring another answer submission.
	my $showReturningFeedback = 0;

	# Sticky answers
	if (!($c->{submitAnswers} || $previewAnswers || $checkAnswers) && $will{showOldAnswers}) {
		my %oldAnswers = decodeAnswers($problem->last_answer);
		# Do this only if new answers are NOT being submitted
		if ($prEnabled && !$problem->{prCount}) {
			# Clear answers if this is a new problem version
			delete $formFields->{$_} for keys %oldAnswers;
		} else {
			$formFields->{$_} = $oldAnswers{$_} for (keys %oldAnswers);
			$showReturningFeedback = 1
				if $ce->{pg}{options}{automaticAnswerFeedback} && $problem->num_correct + $problem->num_incorrect > 0;
		}
	}

	# Translation
	debug('begin pg processing');
	my $pg = await renderPG(
		$c,
		$effectiveUser,
		$c->{set},
		$problem,
		$c->{set}->psvn,
		$formFields,
		{
			displayMode              => $displayMode,
			showHints                => $will{showHints},
			showSolutions            => $will{showSolutions},
			showResourceInfo         => $will{showResourceInfo},
			refreshMath2img          => $will{showHints} || $will{showSolutions},
			processAnswers           => 1,
			permissionLevel          => $db->getPermissionLevel($userID)->permission,
			effectivePermissionLevel => $db->getPermissionLevel($effectiveUserID)->permission,
			useMathQuill             => $will{useMathQuill},
			useMathView              => $will{useMathView},
			forceScaffoldsOpen       => 0,
			isInstructor             => $authz->hasPermissions($userID, 'view_answers'),
			showFeedback             => $c->{submitAnswers} || $c->{previewAnswers} || $showReturningFeedback,
			showAttemptAnswers       => $ce->{pg}{options}{showEvaluatedAnswers},
			showAttemptPreviews      => 1,
			showAttemptResults       => $c->{submitAnswers} || $showReturningFeedback,
			forceShowAttemptResults  => $will{checkAnswers}
				|| $will{showProblemGrader}
				|| ($ce->{pg}{options}{automaticAnswerFeedback}
					&& !$c->{previewAnswers}
					&& after($c->{set}->answer_date, $c->submitTime)),
			showMessages       => 1,
			showCorrectAnswers => (
				$will{showProblemGrader} || ($c->{submitAnswers} && $c->{showCorrectOnRandomize}) ? 2
				: !$c->{previewAnswers} && after($c->{set}->answer_date, $c->submitTime)
				? ($ce->{pg}{options}{correctRevealBtnAlways} ? 1 : 2)
				: !$c->{previewAnswers} && $will{showCorrectAnswers} ? 1
				: 0
			),
			debuggingOptions => getTranslatorDebuggingOptions($authz, $userID)
		}
	);

	# Warnings in the renderPG subprocess will not be caught by the global warning handler of this process.
	# So rewarn them and let the global warning handler take care of it.
	warn $pg->{warnings} if $pg->{warnings};

	debug('end pg processing');

	$pg->{body_text} .= $c->hidden_field(
		num_attempts => $problem->num_correct + $problem->num_incorrect + ($c->{submitAnswers} ? 1 : 0),
		id           => 'num_attempts'
	);

	# Update and fix hint/solution options after PG processing
	$can{showHints}     &&= $pg->{flags}{hintExists};
	$can{showSolutions} &&= $pg->{flags}{solutionExists};

	# Record errors
	$c->{pgdebug}          = $pg->{debug_messages}          if ref $pg->{debug_messages} eq 'ARRAY';
	$c->{pgwarning}        = $pg->{warning_messages}        if ref $pg->{warning_messages} eq 'ARRAY';
	$c->{pginternalerrors} = $pg->{internal_debug_messages} if ref $pg->{internal_debug_messages} eq 'ARRAY';
	# $c->{pgerrors} is defined if any of the above are defined, and is nonzero if any are non-empty.
	$c->{pgerrors} = @{ $c->{pgdebug} // [] } || @{ $c->{pgwarning} // [] } || @{ $c->{pginternalerrors} // [] }
		if defined $c->{pgdebug} || defined $c->{pgwarning} || defined $c->{pginternalerrors};

	# If $c->{pgerrors} is not defined, then the PG messages arrays were not defined,
	# which means $pg->{pgcore} was not defined and the translator died.
	warn 'Processing of this PG problem was not completed.  Probably because of a syntax error. '
		. 'The translator died prematurely and no PG warning messages were transmitted.'
		unless defined $c->{pgerrors};

	# Store fields
	$c->{want} = \%want;
	$c->{can}  = \%can;
	$c->{will} = \%will;
	$c->{pg}   = $pg;

	# Process and log answers
	$c->{scoreRecordedMessage} = await process_and_log_answer($c) || '';

	return;
}

sub warnings ($c) {
	my $output = $c->c;

	# Display warning messages
	if (!defined $c->{pgerrors}) {
		push(
			@$output,
			$c->tag(
				'div',
				$c->c(
					$c->tag('h3', style => 'color:red;', $c->maketext('PG question failed to render')),
					$c->tag('p',  $c->maketext('Unable to obtain error messages from within the PG question.'))
				)->join('')
			)
		);
	} elsif ($c->{pgerrors} > 0) {
		my @pgdebug          = @{ $c->{pgdebug}          // [] };
		my @pgwarning        = @{ $c->{pgwarning}        // [] };
		my @pginternalerrors = @{ $c->{pginternalerrors} // [] };
		push(
			@$output,
			$c->tag(
				'div',
				$c->c(
					$c->tag('h2', $c->maketext('PG question processing error messages')),
					@pgdebug ? $c->c(
						$c->tag('h3', $c->maketext('PG debug messages')),
						$c->tag('p',  $c->c(@pgdebug)->join($c->tag('br')))
					)->join('') : '',
					@pgwarning ? $c->c(
						$c->tag('h3', $c->maketext('PG warning messages')),
						$c->tag('p',  $c->c(@pgwarning)->join($c->tag('br')))
					)->join('') : '',
					@pginternalerrors ? $c->c(
						$c->tag('h3', $c->maketext('PG internal errors')),
						$c->tag('p',  $c->c(@pginternalerrors)->join($c->tag('br')))
					)->join('') : ''
				)->join('')
			)
		);
	}

	push(@$output, $c->SUPER::warnings());

	return $output->join('');
}

sub head ($c) {
	return ''                  if ($c->{invalidSet});
	return $c->{pg}{head_text} if $c->{pg}{head_text};
	return '';
}

sub post_header_text ($c) {
	return ''                           if ($c->{invalidSet});
	return $c->{pg}->{post_header_text} if $c->{pg}->{post_header_text};
	return '';
}

sub siblings ($c) {
	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;

	# Can't show sibling problems if the set is invalid.
	return '' if $c->{invalidSet};

	my $setID   = $c->{set}->set_id;
	my $eUserID = $c->param('effectiveUser');

	my @problemRecords = $db->getMergedProblemsWhere({ user_id => $eUserID, set_id => $setID }, 'problem_id');
	my @problemIDs     = map { $_->problem_id } @problemRecords;

	my $isJitarSet = $setID ne 'Undefined_Set' && $c->{set}->assignment_type eq 'jitar' ? 1 : 0;

	# Variables for the progress bar
	my $num_of_problems = 0;
	my $problemList;
	my $total_correct    = 0;
	my $total_incorrect  = 0;
	my $total_inprogress = 0;
	my $is_reduced       = 0;
	my $currentProblemID = $c->{invalidProblem} ? 0 : $c->{problem}->problem_id;

	my $progressBarEnabled = $c->ce->{pg}{options}{enableProgressBar};

	my @items;

	# Keep the grader open when linking to problems if it is already open.
	my %problemGraderLink = $c->{will}{showProblemGrader} ? (params => { showProblemGrader => 1 }) : ();

	for my $problemID (@problemIDs) {
		if ($isJitarSet
			&& !$authz->hasPermissions($eUserID, 'view_unopened_sets')
			&& is_jitar_problem_hidden($db, $eUserID, $setID, $problemID))
		{
			shift(@problemRecords) if $progressBarEnabled;
			next;
		}

		my $status_symbol = '';
		if ($progressBarEnabled) {
			my $problemRecord = shift(@problemRecords);
			$num_of_problems++;
			my $total_attempts = $problemRecord->num_correct + $problemRecord->num_incorrect;

			my $status = compute_unreduced_score($ce, $problemRecord, $c->{set});
			$is_reduced = 1 if $status > $problemRecord->status;
			if ($isJitarSet) {
				$status = jitar_problem_adjusted_status($problemRecord, $db);
			}

			# variables for the widths of the bars in the Progress Bar
			if ($status == 1) {
				# correct
				$total_correct++;
				$status_symbol = ' &#x2713;';    # checkmark
			} else {
				# incorrect
				if ($total_attempts >= $problemRecord->max_attempts && $problemRecord->max_attempts != -1) {
					$total_incorrect++;
					$status_symbol = ' &#x2717;';    # cross
				} else {
					# in progress
					if ($problemRecord->attempted > 0) {
						$total_inprogress++;
						$status_symbol = ' &hellip;';    # horizontal ellipsis
					}
				}
			}
		}

		my $active = ($progressBarEnabled && $currentProblemID eq $problemID);

		my $problemPage = $c->url_for('problem_detail', setID => $setID, problemID => $problemID);

		if ($isJitarSet) {
			# If it is a jitar set, we need to hide and disable links to hidden or restricted problems.
			my @seq   = jitar_id_to_seq($problemID);
			my $level = $#seq;
			my $class = 'nav-link' . ($active ? ' active' : '');
			if ($level != 0) {
				$class .= ' nested-problem-' . $level;
			}

			if (!$authz->hasPermissions($eUserID, 'view_unopened_sets')
				&& is_jitar_problem_closed($db, $ce, $eUserID, $setID, $problemID))
			{
				push(
					@items,
					$c->link_to(
						$c->maketext('Problem [_1]', join('.', @seq)) => '#',
						class                                         => $class . ' disabled-problem',
					)
				);
			} else {
				push(
					@items,
					$c->tag(
						'a',
						$active ? () : (href => $c->systemLink($problemPage, %problemGraderLink)),
						class => $class,
						$c->b($c->maketext('Problem [_1]', join('.', @seq)) . $status_symbol)
					)
				);
			}
		} else {
			push(
				@items,
				$c->tag(
					'a',
					$active ? () : (href => $c->systemLink($problemPage, %problemGraderLink)),
					class => 'nav-link' . ($active ? ' active' : ''),
					$c->b($c->maketext('Problem [_1]', $problemID) . $status_symbol)
				)
			);
		}
	}

	return $c->include(
		'ContentGenerator/Problem/siblings',
		items            => \@items,
		num_of_problems  => $num_of_problems,
		total_correct    => $total_correct,
		total_incorrect  => $total_incorrect,
		total_inprogress => $total_inprogress,
		is_reduced       => $is_reduced
	);
}

sub nav ($c, $args) {
	return '' if $c->{invalidProblem} || $c->{invalidSet};

	my %can = %{ $c->{can} };

	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;

	my $setID     = $c->{set}->set_id;
	my $problemID = $c->{problem}->problem_id;
	my $userID    = $c->param('user');
	my $eUserID   = $c->param('effectiveUser');

	my $mergedSet = $db->getMergedSet($eUserID, $setID);
	return '' if !$mergedSet;

	# Set up a student navigation for those that have permission to act as a student.
	my $userNav = '';
	if ($authz->hasPermissions($userID, 'become_student') && $eUserID ne $userID) {
		# Find all users for this set (except the current user) sorted by last_name, then first_name, then user_id.
		my @allUserRecords = $db->getUsersWhere(
			{
				user_id => [
					map { $_->[0] } $db->listUserSetsWhere({ set_id => $setID, user_id => { not_like => $userID } })
				]
			},
			[qw/last_name first_name user_id/]
		);

		my $filter = $c->param('studentNavFilter');

		# Find the previous, current, and next users, and format the student names for display.
		# Also create a hash of sections and recitations if there are any for the course.
		my @userRecords;
		my $currentUserIndex = 0;
		my %filters;
		for (@allUserRecords) {
			# Add to the sections and recitations if defined.  Also store the first user found in that section or
			# recitation.  This user will be switched to when the filter is selected.
			my $section = $_->section;
			$filters{"section:$section"} = [ $c->maketext('Filter by section [_1]', $section), $_->user_id ]
				if $section && !$filters{"section:$section"};
			my $recitation = $_->recitation;
			$filters{"recitation:$recitation"} = [ $c->maketext('Filter by recitation [_1]', $recitation), $_->user_id ]
				if $recitation && !$filters{"recitation:$recitation"};

			# Only keep this user if it satisfies the selected filter if a filter was selected.
			next
				unless !$filter
				|| ($filter =~ /^section:(.*)$/    && $_->section eq $1)
				|| ($filter =~ /^recitation:(.*)$/ && $_->recitation eq $1);

			my $addRecord = $_;
			$currentUserIndex = @userRecords if $addRecord->user_id eq $eUserID;
			push @userRecords, $addRecord;

			# Construct a display name.
			$addRecord->{displayName} =
				($addRecord->last_name || $addRecord->first_name
					? $addRecord->last_name . ', ' . $addRecord->first_name
					: $addRecord->user_id);
		}
		my $prevUser = $currentUserIndex > 0             ? $userRecords[ $currentUserIndex - 1 ] : 0;
		my $nextUser = $currentUserIndex < $#userRecords ? $userRecords[ $currentUserIndex + 1 ] : 0;

		# Mark the current user.
		$userRecords[$currentUserIndex]{currentUser} = 1;

		my $problemPage = $c->url_for('problem_detail', setID => $setID, problemID => $problemID);

		# Set up the student nav.
		$userNav = $c->include(
			'ContentGenerator/Problem/student_nav',
			eUserID          => $eUserID,
			problemPage      => $problemPage,
			userRecords      => \@userRecords,
			currentUserIndex => $currentUserIndex,
			prevUser         => $prevUser,
			nextUser         => $nextUser,
			filter           => $filter,
			filters          => \%filters
		);
	}

	my $isJitarSet = $mergedSet->assignment_type eq 'jitar';

	my ($prevID, $nextID);

	# Find the next or previous problem, and determine if it is actually open for a jitar set.
	if (!$c->{invalidProblem}) {
		my @problemIDs =
			map { $_->[2] } $db->listUserProblemsWhere({ user_id => $eUserID, set_id => $setID }, 'problem_id');

		if ($isJitarSet) {
			my @processedProblemIDs;
			for my $id (@problemIDs) {
				push @processedProblemIDs, $id
					unless !$authz->hasPermissions($eUserID, 'view_unopened_sets')
					&& is_jitar_problem_hidden($db, $eUserID, $setID, $id);
			}
			@problemIDs = @processedProblemIDs;
		}

		my $curr_index = 0;

		for (my $i = 0; $i <= $#problemIDs; $i++) {
			$curr_index = $i if $problemIDs[$i] == $problemID;
		}

		$prevID = $problemIDs[ $curr_index - 1 ] if $curr_index - 1 >= 0;
		$nextID = $problemIDs[ $curr_index + 1 ] if $curr_index + 1 <= $#problemIDs;
		$nextID = ''
			if ($isJitarSet
				&& $nextID
				&& !$authz->hasPermissions($eUserID, 'view_unopened_sets')
				&& is_jitar_problem_closed($db, $ce, $eUserID, $setID, $nextID));
	}

	my @links;

	if ($prevID) {
		push @links, $c->maketext('Previous Problem'),
			$c->url_for('problem_detail', setID => $setID, problemID => $prevID),
			$c->maketext('Previous Problem');
	} else {
		push @links, $c->maketext('Previous Problem'), '', $c->maketext('Previous Problem');
	}

	if (defined $setID && $setID ne 'Undefined_Set') {
		push @links, $c->maketext('Problem List'), $c->url_for('problem_list', setID => $setID),
			$c->maketext('Problem List');
	} else {
		push @links, $c->maketext('Problem List'), '', $c->maketext('Problem List');
	}

	if ($nextID) {
		push @links, $c->maketext('Next Problem'),
			$c->url_for('problem_detail', setID => $setID, problemID => $nextID),
			$c->maketext('Next Problem');
	} else {
		push @links, $c->maketext('Next Problem'), '', $c->maketext('Next Problem');
	}

	my %tail;
	$tail{displayMode}       = $c->{displayMode}             if defined $c->{displayMode};
	$tail{showOldAnswers}    = 1                             if $c->{will}{showOldAnswers};
	$tail{showProblemGrader} = 1                             if $c->{will}{showProblemGrader};
	$tail{studentNavFilter}  = $c->param('studentNavFilter') if $c->param('studentNavFilter');

	return $c->tag(
		'div',
		class        => 'row sticky-nav',
		role         => 'navigation',
		'aria-label' => 'problem navigation',
		$c->c($c->tag('div', class => 'd-flex submit-buttons-container', $c->navMacro($args, \%tail, @links)),
			$userNav)->join('')
	);
}

sub path ($c, $args) {
	my $prettyProblemNumber = $c->stash('problemID');

	my $set = $c->db->getGlobalSet($c->stash('setID'));
	if ($set && $set->assignment_type eq 'jitar' && $prettyProblemNumber) {
		$prettyProblemNumber = join('.', jitar_id_to_seq($prettyProblemNumber));
	}

	my $navigation_allowed = $c->authz->hasPermissions($c->param('user'), 'navigation_allowed');

	my @path = (
		WeBWorK               => $navigation_allowed ? $c->url_for('root')     : '',
		$c->stash('courseID') => $navigation_allowed ? $c->url_for('set_list') : '',
		$c->stash('setID')    => $c->url_for('problem_list'),
	);

	if ($c->current_route eq 'show_me_another') {
		push(
			@path,
			$prettyProblemNumber => $c->url_for('problem_detail'),
			'Show Me Another'    => ''
		);
	} else {
		push(@path, $prettyProblemNumber => '');
	}

	return $c->pathMacro($args, @path);
}

sub page_title ($c) {
	my $db = $c->db;

	my $setID     = $c->stash('setID');
	my $problemID = $c->stash('problemID');

	my $set = $db->getGlobalSet($setID);
	if ($set && $set->assignment_type eq 'jitar') {
		$problemID = join('.', jitar_id_to_seq($problemID));
	}
	my $header =
		$c->maketext('[_1]: Problem [_2]', $c->tag('span', dir => 'ltr', format_set_name_display($setID)), $problemID);

	# Return here if we don't have the requisite information.
	return $header if ($c->{invalidSet} || $c->{invalidProblem});

	my $ce      = $c->ce;
	my $problem = $c->{problem};

	my $subheader = '';

	my $problemValue = $problem->value;
	if (defined $problemValue && $problemValue ne '') {
		$subheader .= $c->maketext('([quant,_1,point])', $problemValue);
	}

	# This uses the permission level and user id of the user assigned to the problem.
	my $problemUser = $problem->user_id;
	my $inList      = grep { $_ eq $problemUser } @{ $ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} };
	if ($db->getPermissionLevel($problemUser)->permission >=
		$ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_PERMISSION_LEVEL} || $inList)
	{
		$subheader .= ' ' . $problem->source_file;
	}

	# Add the edit link to the sub header if the user has the permisions ot edit problems.
	if ($c->authz->hasPermissions($c->param('user'), 'modify_problem_sets')) {
		$subheader = $c->c(
			$subheader,
			$c->tag(
				'span',
				class => 'ms-2',
				$c->link_to(
					$c->maketext('Edit') => $c->systemLink(
						$c->url_for(
							'instructor_problem_editor_withset_withproblem',
							setID     => $c->{set}->set_id,
							problemID => $c->{problem}->problem_id
						),
						# If we are here without a real homework set, carry that through.
						$c->{set}->set_id eq 'Undefined_Set'
						? (params => [ 'sourceFilePath' => $c->param('sourceFilePath') ])
						: ()
					),
					target => 'WW_Editor',
					class  => 'btn btn-sm btn-secondary'
				)
			)
		)->join('');
	}

	# Add the tag edit button to the sub header if the user has permission to edit tags.
	if ($c->authz->hasPermissions($c->param('user'), 'modify_tags')) {
		$subheader = $c->c(
			$subheader,
			$c->tag(
				'button',
				id    => 'tagger',
				type  => 'button',
				class => 'tag-edit-btn btn btn-secondary btn-sm ms-2',
				data  => { source_file => $c->ce->{courseDirs}{templates} . '/' . $c->{problem}{source_file} },
				$c->maketext('Edit Tags')
			),
			$c->hidden_field(hidden_course_id => $c->stash('courseID'))
		)->join('');
	}

	return $c->c($header, $c->tag('span', class => 'problem-sub-header d-block', $subheader))->join('');
}

# Add a lang and maybe also a dir setting to the DIV tag attributes, if needed by the PROBLEM language.
sub output_problem_lang_and_dir ($c) {
	return get_problem_lang_and_dir($c->{pg}{flags}, $c->ce->{perProblemLangAndDirSettingMode}, $c->ce->{language});
}

# Output the body of the current problem
sub output_problem_body ($c) {
	# If there are translation errors then render those with the body text of the problem.
	if ($c->{pg}{flags}{error_flag}) {
		if ($c->authz->hasPermissions($c->param('user'), 'view_problem_debugging_info')) {
			# For instructors render the body text of the problem with the errors.
			return $c->include(
				'ContentGenerator/Base/error_output',
				error   => $c->{pg}{errors},
				details => $c->{pg}{body_text}
			);
		} else {
			# For students render the body text of the problem with a message about error details.
			return $c->c(
				$c->tag('div', id => 'output_problem_body', $c->b($c->{pg}{body_text})),
				$c->include(
					'ContentGenerator/Base/error_output',
					error   => $c->{pg}{errors},
					details => $c->maketext('You do not have permission to view the details of this error.')
				)
			)->join('');
		}
	}

	return $c->tag('div', id => 'output_problem_body', $c->b($c->{pg}{body_text}));
}

# Output messages about the problem
sub output_message ($c) {
	return $c->include('ContentGenerator/Problem/messages');
}

# Output the problem grader if the user has permissions to grade problems
sub output_grader ($c) {
	if ($c->{will}{showProblemGrader}) {
		return WeBWorK::HTML::SingleProblemGrader->new($c, $c->{pg}, $c->{problem})->insertGrader;
	}

	return '';
}

# Output the checkbox input elements that are available for the current problem
sub output_checkboxes ($c) {
	return $c->include('ContentGenerator/Problem/checkboxes');
}

# Output the submit button input elements that are available for the current problem
sub output_submit_buttons ($c) {
	return $c->include('ContentGenerator/Problem/submit_buttons');
}

# Output a summary of the student's current progress and status on the current problem.
sub output_score_summary ($c) {
	my $ce            = $c->ce;
	my $db            = $c->db;
	my $problem       = $c->{problem};
	my $set           = $c->{set};
	my $pg            = $c->{pg};
	my $effectiveUser = $c->param('effectiveUser') || $c->param('user');

	my $prEnabled         = $ce->{pg}{options}{enablePeriodicRandomization} // 0;
	my $rerandomizePeriod = $ce->{pg}{options}{periodicRandomizationPeriod} // 0;
	$rerandomizePeriod = $problem->{prPeriod} if defined $problem->{prPeriod} && $problem->{prPeriod} > -1;
	$prEnabled         = 0                    if $rerandomizePeriod < 1;

	warn 'num_correct = ' . $problem->num_correct . 'num_incorrect = ' . $problem->num_incorrect
		unless defined $problem->num_correct && defined $problem->num_incorrect;

	my $prMessage = '';
	if ($prEnabled) {
		my $attempts_before_rr = $c->{will}{requestNewSeed} ? 0 : ($rerandomizePeriod - $problem->{prCount});

		$prMessage = ' '
			. $c->maketext('You have [quant,_1,attempt,attempts] left before new version will be requested.',
				$attempts_before_rr)
			if $attempts_before_rr > 0;

		$prMessage = ' ' . $c->maketext('Request new version now.') if ($attempts_before_rr == 0);
	}
	$prMessage = '' if after($set->due_date, $c->submitTime) or before($set->open_date, $c->submitTime);

	my $setClosed = 0;
	my $setClosedMessage;
	if (before($set->open_date, $c->submitTime) || after($set->due_date, $c->submitTime)) {
		$setClosed = 1;
		if (before($set->open_date, $c->submitTime)) {
			$setClosedMessage = $c->maketext('This homework set is not yet open.');
		} elsif (after($set->due_date, $c->submitTime)) {
			$setClosedMessage = $c->maketext('This homework set is closed.');
		}
	}

	my $attempts = $problem->num_correct + $problem->num_incorrect;

	my $output = $c->c;

	unless (defined $pg->{state}{state_summary_msg} && $pg->{state}{state_summary_msg} =~ /\S/) {
		push(
			@$output,
			$c->{submitAnswers} ? $c->{scoreRecordedMessage} . $c->tag('br') : '',
			$c->maketext('You have attempted this problem [quant,_1,time,times].', $attempts),
			$prMessage,
			$c->tag('br'),
			$c->{submitAnswers}
			? (
				$c->maketext(
					'You received a score of [_1] for this attempt.',
					wwRound(0,
						compute_reduced_score($ce, $problem, $set, $pg->{result}{score}, $c->submitTime) * 100)
						. '%'
				),
				$c->tag('br')
				)
			: '',
			$problem->attempted
			? (
				$c->maketext(
					'Your overall recorded score is [_1].  [_2]',
					wwRound(0, $problem->status * 100) . '%',
					$problem->value ? '' : $c->maketext('(This problem will not count towards your grade.)')
				),
				$c->tag('br')
				)
			: '',
			$setClosed ? $setClosedMessage : $c->maketext(
				'You have [negquant,_1,unlimited attempts,attempt,attempts] remaining.',
				$problem->max_attempts - $attempts
			)
		);
	} else {
		push(@$output, $pg->{state}{state_summary_msg});
	}

	# Print jitar specific informaton for students (and notify instructor if necessary).
	if ($set->set_id ne 'Undefined_Set' && $set->assignment_type() eq 'jitar') {
		my @problemIDs =
			map { $_->[2] }
			$db->listUserProblemsWhere({ user_id => $effectiveUser, set_id => $set->set_id }, 'problem_id');

		my @problemSeqs;
		my $index;

		# This sets of an array of the sequence assoicated to the problem_id
		for (my $i = 0; $i <= $#problemIDs; $i++) {
			$index = $i if ($problemIDs[$i] == $problem->problem_id);
			my @seq = jitar_id_to_seq($problemIDs[$i]);
			push @problemSeqs, \@seq;
		}

		my $next_id = $index + 1;
		my @seq     = @{ $problemSeqs[$index] };
		my @children_counts_indexs;
		my $hasChildren = 0;

		# Find the index of the next problem at the same level as the current one, check to see if there are any
		# children, and determine which children count toward the grade of this problem.
		while ($next_id <= $#problemIDs && scalar(@{ $problemSeqs[$index] }) < scalar(@{ $problemSeqs[$next_id] })) {
			my $childProblem = $db->getMergedProblem($effectiveUser, $set->set_id, $problemIDs[$next_id]);
			$hasChildren = 1;
			push @children_counts_indexs, $next_id
				if scalar(@{ $problemSeqs[$index] }) + 1 == scalar(@{ $problemSeqs[$next_id] })
				&& $childProblem->counts_parent_grade;
			$next_id++;
		}

		# Output information if this problem has open children, and if the grade
		# for this problem can be replaced by the grades of its children.
		if (
			$hasChildren
			&& (
				($problem->att_to_open_children != -1 && $problem->num_incorrect >= $problem->att_to_open_children)
				|| ($problem->max_attempts != -1
					&& $problem->num_incorrect >= $problem->max_attempts)
			)
			)
		{
			push(
				@$output,
				$c->tag('br'),
				$c->maketext(
					'This problem has open subproblems.  '
						. 'You can visit them by using the links to the left or visiting the set page.'
				)
			);

			if (scalar(@children_counts_indexs) == 1) {
				push(
					@$output,
					$c->tag('br'),
					$c->maketext(
						'The grade for this problem is the larger of the score for this problem, '
							. 'or the score of problem [_1].',
						join('.', @{ $problemSeqs[ $children_counts_indexs[0] ] })
					)
				);
			} elsif (scalar(@children_counts_indexs) > 1) {
				push(
					@$output,
					$c->tag('br'),
					$c->maketext(
						'The grade for this problem is the larger of the score for this problem, '
							. 'or the weighted average of the problems: [_1].',
						join(', ', map({ join('.', @{ $problemSeqs[$_] }) } @children_counts_indexs))
					)
				);
			}
		}

		# Output information if this set has restricted progression and if the user needs
		# to finish this problem (and maybe its children) to proceed.
		if ($set->restrict_prob_progression()
			&& $next_id <= $#problemIDs
			&& is_jitar_problem_closed($db, $ce, $effectiveUser, $set->set_id, $problemIDs[$next_id]))
		{
			if ($hasChildren) {
				push(
					@$output,
					$c->tag('br'),
					$c->maketext(
						'You will not be able to proceed to problem [_1] until you have completed, '
							. 'or run out of attempts, for this problem and its graded subproblems.',
						join('.', @{ $problemSeqs[$next_id] })
					)
				);
			} elsif (scalar(@seq) == 1
				|| $problem->counts_parent_grade())
			{
				push(
					@$output,
					$c->tag('br'),
					$c->maketext(
						'You will not be able to proceed to problem [_1] until you have completed, '
							. 'or run out of attempts, for this problem.',
						join('.', @{ $problemSeqs[$next_id] })
					)
				);
			}
		}
		# Show information if this problem counts towards the grade of its parent.
		# If it doesn't (and its not a top level problem) then its grade doesnt matter.
		if ($problem->counts_parent_grade() && scalar(@seq) != 1) {
			pop @seq;
			push(
				@$output,
				$c->tag('br'),
				$c->maketext(
					'The score for this problem can count towards score of problem [_1].', join('.', @seq)
				)
			);
		} elsif (scalar(@seq) != 1) {
			pop @seq;
			push(
				@$output,
				$c->tag('br'),
				$c->maketext(
					'This score for this problem does not count for the score of problem [_1] or for the set.',
					join('.', @seq)
				)
			);
		}

		# If the instructor has set this up, then email the instructor a warning message if the student has run out of
		# attempts on a top level problem and all of its children and didn't get 100%.
		if ($c->{submitAnswers} && $set->email_instructor) {
			my $parentProb = $db->getMergedProblem($effectiveUser, $set->set_id, seq_to_jitar_id($seq[0]));
			warn("Couldn't find problem $seq[0] from set " . $set->set_id . ' in the database') unless $parentProb;

			if (jitar_problem_finished($parentProb, $db) && jitar_problem_adjusted_status($parentProb, $db) != 1) {
				jitar_send_warning_email($c, $parentProb);
			}

		}
	}

	return $c->tag('p', $output->join(''));
}

# Output other necessary elements
sub output_misc ($c) {
	my $output = $c->c;

	# Save state for viewOptions
	push(@$output,
		$c->hidden_field(showOldAnswers => $c->{will}{showOldAnswers}),
		$c->hidden_field(displayMode    => $c->{displayMode}));

	push(@$output, $c->hidden_field(editMode => $c->{editMode}))
		if defined $c->{editMode} && $c->{editMode} eq 'temporaryFile';

	my $permissionLevel          = $c->db->getPermissionLevel($c->param('user'))->permission;
	my $professorPermissionLevel = $c->ce->{userRoles}{professor};

	# Only allow this for professors
	push(@$output, $c->hidden_field(sourceFilePath => $c->{problem}{source_file}))
		if defined $c->{problem}{source_file} && $permissionLevel >= $professorPermissionLevel;

	# Only allow this for professors
	push(@$output, $c->hidden_field(problemSeed => $c->param('problemSeed')))
		if defined $c->param('problemSeed') && $permissionLevel >= $professorPermissionLevel;

	# Make sure the student nav filter setting is preserved when the problem form is submitted.
	push(@$output, $c->hidden_field(studentNavFilter => $c->param('studentNavFilter')))
		if $c->param('studentNavFilter');

	return $output->join('');
}

# Output any instructor comments present in the latest past_answer entry
sub output_comments ($c) {
	my $db = $c->db;

	my $userPastAnswerID =
		$db->latestProblemPastAnswer($c->param('effectiveUser'), $c->stash('setID'), $c->stash('problemID'));

	# If there is a comment then display it.
	if ($userPastAnswerID) {
		my $userPastAnswer = $db->getPastAnswer($userPastAnswerID);
		if ($userPastAnswer->comment_string) {
			return $c->tag(
				'div',
				id    => 'answerComment',
				class => 'answerComments mt-2',
				$c->c($c->tag('b', 'Instructor Comment:'), $c->tag('div', $userPastAnswer->comment_string))
					->join('')
			);
		}
	}

	return '';
}

# Output the summary of the questions that the student has answered
# for the current problem, along with available information about correctness
sub output_summary ($c) {
	my $db   = $c->db;
	my $pg   = $c->{pg};
	my %will = %{ $c->{will} };

	my $output = $c->c;

	# Attempt summary
	if ($c->{submitAnswers}) {
		push(@$output, $c->attemptResults($pg));
	} elsif ($will{checkAnswers} || $c->{will}{showProblemGrader}) {
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-danger d-inline-block mb-2 p-1',
				$c->maketext('ANSWERS ONLY CHECKED -- ANSWERS NOT RECORDED')
			),
			$c->attemptResults($pg)
		);
	} elsif ($c->{previewAnswers}) {
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-danger d-inline-block mb-2 p-1',
				$c->maketext('PREVIEW ONLY -- ANSWERS NOT RECORDED')
			),
		);
	}

	push(
		@$output,
		$c->tag(
			'div',
			class => 'alert alert-danger d-inline-block mb-2 p-1',
			$c->maketext(
				'ATTEMPT NOT ACCEPTED -- Please submit answers again (or request new version if neccessary).')
		)
	) if $c->{resubmitDetected};

	if ($c->{set}->set_id ne 'Undefined_Set' && $c->{set}->assignment_type eq 'jitar') {
		my $hasChildren = 0;

		my @problemIDs =
			map { $_->[2] }
			$db->listUserProblemsWhere({ user_id => $c->param('effectiveUser'), set_id => $c->{set}->set_id },
				'problem_id');

		my @problemSeqs;
		my $index;
		# This sets of an array of the sequence associated to the problem_id.
		for (my $i = 0; $i <= $#problemIDs; $i++) {
			$index = $i if ($problemIDs[$i] == $c->{problem}->problem_id);
			my @seq = jitar_id_to_seq($problemIDs[$i]);
			push @problemSeqs, \@seq;
		}

		my $next_id = $index + 1;
		my @seq     = @{ $problemSeqs[$index] };

		# Check to see if the problem has children.
		while ($next_id <= $#problemIDs && scalar(@{ $problemSeqs[$index] }) < scalar(@{ $problemSeqs[$next_id] })) {
			$hasChildren = 1;
			$next_id++;
		}

		# If the problem has children and conditions are right, output a message.
		if (
			$hasChildren
			&& (
				(
					$c->{problem}->att_to_open_children != -1
					&& $c->{problem}->num_incorrect >= $c->{problem}->att_to_open_children
				)
				|| ($c->{problem}->max_attempts != -1
					&& $c->{problem}->num_incorrect >= $c->{problem}->max_attempts)
			)
			)
		{
			push(
				@$output,
				$c->tag(
					'div',
					class => 'showMeAnotherBox',
					$c->maketext(
						'This problem has open subproblems.  You can visit them by using '
							. 'the links to the left or visiting the set page.'
					)
				)
			);
		}
	}

	return $output->join('');
}

# Output the achievement message if there is one.
sub output_achievement_message ($c) {
	# If achievements are enabled and this is not an undefined set,
	# check to see if there are new achievements and output them.
	if ($c->ce->{achievementsEnabled}
		&& $c->{will}{recordAnswers}
		&& $c->{submitAnswers}
		&& $c->{problem}->set_id ne 'Undefined_Set')
	{
		return checkForAchievements($c->{problem}, $c->{pg}, $c);
	}

	return '';
}

# Output a custom edit message
sub output_custom_edit_message ($c) {
	if ($c->authz->hasPermissions($c->param('user'), 'modify_problem_sets')
		&& $c->{editMode}
		&& $c->{editMode} eq 'temporaryFile')
	{
		return $c->tag(
			'p',
			class => 'temporaryFile',
			$c->maketext('Viewing temporary file: [_1]', $c->{problem}->source_file)
		);
	}

	return '';
}

# Output the "Show Past Answers" button
sub output_past_answer_button ($c) {
	my $problemID = $c->{problem}->problem_id;
	my $setRecord = $c->db->getGlobalSet($c->{problem}->set_id);
	if (defined $setRecord && $setRecord->assignment_type eq 'jitar') {
		$problemID = join('.', jitar_id_to_seq($problemID));
	}

	if ($c->authz->hasPermissions($c->param('user'), 'view_answers')) {
		my $hiddenFields = $c->hidden_authen_fields;
		$hiddenFields =~ s/\"hidden_/\"pastans-hidden_/g;
		return $c->form_for(
			'answer_log',
			method => 'POST',
			target => 'WW_Info',
			$c->c(
				$hiddenFields,
				$c->hidden_field(courseID          => $c->stash('courseID')),
				$c->hidden_field(selected_problems => $problemID),
				$c->hidden_field(selected_sets     => $c->{problem}->set_id),
				$c->hidden_field(selected_users    => $c->{problem}->user_id),
				$c->tag(
					'p',
					$c->submit_button(
						$c->maketext('Show Past Answers'),
						name  => 'action',
						class => 'btn btn-primary'
					)
				)
			)->join('')
		);
	}

	return '';
}

# Output the "Email Instructor" button
sub output_email_instructor ($c) {
	my $user = $c->db->getUser($c->param('user'));

	# FIXME: Most of what is passed here is only needed by the feedback form, and should be extracted in the
	# feedbackMacro method and only for that case.
	return $c->feedbackMacro(
		route        => $c->current_route,
		courseId     => $c->stash('courseID'),
		set          => $c->{set}->set_id,
		problem      => $c->{problem}->problem_id,
		problemPath  => $c->{problem}->source_file,
		randomSeed   => $c->{problem}->problem_seed,
		emailableURL => $c->generateURLs(
			url_type   => 'absolute',
			set_id     => $c->{set}->set_id,
			problem_id => $c->{problem}->problem_id
		),
		studentName        => $user->full_name,
		displayMode        => $c->{displayMode},
		showOldAnswers     => $c->{will}{showOldAnswers},
		showCorrectAnswers => $c->{will}{showCorrectAnswers},
		showHints          => $c->{will}{showHints},
		showSolutions      => $c->{will}{showSolutions},
		pg_object          => $c->{pg},
	);
}

1;
