################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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
use parent qw(WeBWorK::ContentGenerator);

use strict;
use warnings;
use utf8;

=head1 NAME

WeBWorK::ContentGenerator::Problem - Allow a student to interact with a problem.

=cut

use Future::AsyncAwait;

use WeBWorK::HTML::SingleProblemGrader;
use WeBWorK::Debug;
use WeBWorK::Form;
use WeBWorK::PG::ImageGenerator;
use WeBWorK::Utils qw(decodeAnswers is_restricted path_is_subdir before after between
	wwRound is_jitar_problem_closed is_jitar_problem_hidden jitar_problem_adjusted_status
	jitar_id_to_seq seq_to_jitar_id jitar_problem_finished format_set_name_display);
use WeBWorK::Utils::Rendering qw(getTranslatorDebuggingOptions renderPG);
use WeBWorK::Utils::ProblemProcessing qw/process_and_log_answer jitar_send_warning_email compute_reduced_score/;
use WeBWorK::AchievementEvaluator qw(checkForAchievements);
use WeBWorK::DB::Utils qw(global2user);
use WeBWorK::Localize;
use WeBWorK::Utils::Tasks qw(fake_set fake_problem);
use WeBWorK::Utils::LanguageAndDirection qw(get_problem_lang_and_dir);
use WeBWorK::AchievementEvaluator;
use WeBWorK::HTML::AttemptsTable;

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
#   ($self, $user, $effectiveUser, $set, $problem)
# In addition can_recordAnswers and can_showMeAnother have the argument
# $submitAnswers that is used to distinguish between this submission and the
# next.

sub can_showOldAnswers {
	my ($self, $user, $effectiveUser, $set, $problem) = @_;
	return $self->r->authz->hasPermissions($user->user_id, 'can_show_old_answers');
}

sub can_showCorrectAnswers {
	my ($self, $user, $effectiveUser, $set, $problem) = @_;
	return after($set->answer_date, $self->r->submitTime)
		|| $self->r->authz->hasPermissions($user->user_id, 'show_correct_answers_before_answer_date');
}

sub can_showProblemGrader {
	my ($self, $user, $effectiveUser, $set, $problem) = @_;
	my $authz = $self->r->authz;

	return ($authz->hasPermissions($user->user_id, 'access_instructor_tools')
			&& $authz->hasPermissions($user->user_id, 'score_sets')
			&& $set->set_id ne 'Undefined_Set'
			&& !$self->{invalidSet});
}

sub can_showAnsGroupInfo {
	my ($self, $user, $effectiveUser, $set, $problem) = @_;
	return $self->r->authz->hasPermissions($user->user_id, 'show_answer_group_info');
}

sub can_showAnsHashInfo {
	my ($self, $user, $effectiveUser, $set, $problem) = @_;
	return $self->r->authz->hasPermissions($user->user_id, 'show_answer_hash_info');
}

sub can_showPGInfo {
	my ($self, $user, $effectiveUser, $set, $problem) = @_;
	return $self->r->authz->hasPermissions($user->user_id, 'show_pg_info');
}

sub can_showResourceInfo {
	my ($self, $user, $effectiveUser, $set, $problem) = @_;
	return $self->r->authz->hasPermissions($user->user_id, 'show_resource_info');
}

sub can_showHints {
	my ($self, $user, $effectiveUser, $set, $problem) = @_;
	my $r = $self->r;

	return 1 if $r->authz->hasPermissions($user->user_id, 'always_show_hint');

	my $showHintsAfter =
		$set->hide_hint                 ? -1
		: $problem->showHintsAfter > -2 ? $problem->showHintsAfter
		:                                 $r->ce->{pg}{options}{showHintsAfter};

	return $showHintsAfter > -1
		&& $showHintsAfter <= $problem->num_correct + $problem->num_incorrect + ($self->{submitAnswers} ? 1 : 0);
}

sub can_showSolutions {
	my ($self, $user, $effectiveUser, $set, $problem) = @_;
	my $authz = $self->r->authz;

	return
		$authz->hasPermissions($user->user_id, 'always_show_solutions')
		|| after($set->answer_date, $self->r->submitTime)
		|| $authz->hasPermissions($user->user_id, 'show_solutions_before_answer_date');
}

sub can_recordAnswers {
	my ($self, $user, $effectiveUser, $set, $problem, $submitAnswers) = @_;
	my $authz = $self->r->authz;

	if ($user->user_id ne $effectiveUser->user_id) {
		return $authz->hasPermissions($user->user_id, 'record_answers_when_acting_as_student');
	}

	return $authz->hasPermissions($user->user_id, 'record_answers_before_open_date')
		if (before($set->open_date, $self->r->submitTime));

	if (between($set->open_date, $set->due_date, $self->r->submitTime)) {
		my $max_attempts  = $problem->max_attempts;
		my $attempts_used = $problem->num_correct + $problem->num_incorrect + ($submitAnswers ? 1 : 0);
		if ($max_attempts == -1 or $attempts_used < $max_attempts) {
			return $authz->hasPermissions($user->user_id, 'record_answers_after_open_date_with_attempts');
		} else {
			return $authz->hasPermissions($user->user_id, 'record_answers_after_open_date_without_attempts');
		}
	}

	return $authz->hasPermissions($user->user_id, 'record_answers_after_due_date')
		if (between($set->due_date, $set->answer_date, $self->r->submitTime));

	return $authz->hasPermissions($user->user_id, 'record_answers_after_answer_date')
		if (after($set->answer_date, $self->r->submitTime));

	return 0;
}

sub can_checkAnswers {
	my ($self, $user, $effectiveUser, $set, $problem) = @_;
	my $authz = $self->r->authz;

	# If we can record answers then we dont need to be able to check them
	# unless we have that specific permission.
	return 0
		if ($self->can_recordAnswers($user, $effectiveUser, $set, $problem, $self->{submitAnswers})
			&& !$authz->hasPermissions($user->user_id, 'can_check_and_submit_answers'));

	return $authz->hasPermissions($user->user_id, 'check_answers_before_open_date')
		if (before($set->open_date, $self->r->submitTime));

	if (between($set->open_date, $set->due_date, $self->r->submitTime)) {
		my $max_attempts  = $problem->max_attempts;
		my $attempts_used = $problem->num_correct + $problem->num_incorrect + ($self->{submitAnswers} ? 1 : 0);
		if ($max_attempts == -1 or $attempts_used < $max_attempts) {
			return $authz->hasPermissions($user->user_id, 'check_answers_after_open_date_with_attempts');
		} else {
			return $authz->hasPermissions($user->user_id, 'check_answers_after_open_date_without_attempts');
		}
	}

	return $authz->hasPermissions($user->user_id, 'check_answers_after_due_date')
		if (between($set->due_date, $set->answer_date, $self->r->submitTime));

	return $authz->hasPermissions($user->user_id, 'check_answers_after_answer_date')
		if (after($set->answer_date, $self->r->submitTime));

	return 0;
}

sub can_useMathView {
	my ($self) = @_;
	return $self->r->ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathView';
}

sub can_useWirisEditor {
	my ($self) = @_;
	return $self->r->ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'WIRIS';
}

sub can_useMathQuill {
	my ($self) = @_;
	return $self->r->ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathQuill';
}

# Check if the showMeAnother button should be allowed.  Note that this is done *before* the check to see if
# showMeAnother is possible.
sub can_showMeAnother {
	my ($self, $user, $effectiveUser, $set, $problem, $submitAnswers) = @_;
	my $ce = $self->r->ce;

	# If the showMeAnother button isn't enabled in the course configuration,
	# don't show it under any circumstances (not even for the instructor).
	return 0 unless $ce->{pg}{options}{enableShowMeAnother};

	# Get the hash of information about showMeAnother
	my %showMeAnother = %{ $self->{showMeAnother} };

	if (after($set->open_date, $self->r->submitTime)
		|| $self->r->authz->hasPermissions($self->r->param('user'), 'can_use_show_me_another_early'))
	{
		# If $showMeAnother{TriesNeeded} is somehow not an integer or if it is -2, use the default value.
		$showMeAnother{TriesNeeded} = $ce->{pg}{options}{showMeAnotherDefault}
			if ($showMeAnother{TriesNeeded} !~ /^[+-]?\d+$/ || $showMeAnother{TriesNeeded} == -2);

		# If SMA is not permitted for the problem, don't show it.
		return 0 unless $showMeAnother{TriesNeeded} > -1;

		# If the student is previewing or checking an answer to SMA then clearly the user can use show me another.
		return 1 if $showMeAnother{CheckAnswers} || $showMeAnother{Preview};

		# If $showMeAnother{Count} is somehow not an integer, it probably means that the value in the database was not
		# initialized correctly.  So set it to 0.
		$showMeAnother{Count} = 0 unless $showMeAnother{Count} =~ /^[+-]?\d+$/;

		# If the button is enabled globally and for the problem, then check if the student has either
		# not submitted enough answers yet or has used the SMA button too many times.
		return 0
			if $problem->num_correct + $problem->num_incorrect + ($submitAnswers ? 1 : 0) < $showMeAnother{TriesNeeded}
			|| ($showMeAnother{Count} >= $showMeAnother{MaxReps} && $showMeAnother{MaxReps} > -1);

		return 1;
	}

	return 0;
}

sub attemptResults {
	my ($self, $pg, $showCorrectAnswers, $showAttemptResults, $showSummary) = @_;

	my $ce = $self->r->ce;

	# Create AttemptsTable object
	my $tbl = WeBWorK::HTML::AttemptsTable->new(
		$pg->{answers},
		$self->r,
		answersSubmitted    => 1,
		answerOrder         => $pg->{flags}->{ANSWER_ENTRY_ORDER},
		displayMode         => $self->{displayMode},
		showAnswerNumbers   => 0,
		showAttemptAnswers  => $ce->{pg}{options}{showEvaluatedAnswers},
		showAttemptPreviews => 1,
		showAttemptResults  => $showAttemptResults,
		showCorrectAnswers  => $showCorrectAnswers,
		showMessages        => 1,
		showSummary         => $showSummary,
		imgGen              => WeBWorK::PG::ImageGenerator->new(
			tempDir         => $ce->{webworkDirs}{tmp},
			latex           => $ce->{externalPrograms}{latex},
			dvipng          => $ce->{externalPrograms}{dvipng},
			useCache        => 1,
			cacheDir        => $ce->{webworkDirs}{equationCache},
			cacheURL        => $ce->{webworkURLs}{equationCache},
			cacheDB         => $ce->{webworkFiles}{equationCacheDB},
			useMarkers      => 1,
			dvipng_align    => $ce->{pg}{displayModeOptions}{images}{dvipng_align},
			dvipng_depth_db => $ce->{pg}{displayModeOptions}{images}{dvipng_depth_db},
		),
	);

	# Render equation images
	my $answerTemplate = $tbl->answerTemplate;
	$tbl->imgGen->render(body_text => \$answerTemplate) if $tbl->displayMode eq 'images';

	return $answerTemplate;
}

async sub pre_header_initialize {
	my ($self) = @_;

	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $authz   = $r->authz;
	my $urlpath = $r->urlpath;

	my $setID           = $urlpath->arg('setID');
	my $problemID       = $r->urlpath->arg('problemID');
	my $userID          = $r->param('user');
	my $effectiveUserID = $r->param('effectiveUser');
	$self->{editMode} = $r->param('editMode');

	my $user = $db->getUser($userID);
	die "record for user $userID (real user) does not exist."
		unless defined $user;

	my $effectiveUser = $db->getUser($effectiveUserID);
	die "record for user $effectiveUserID (effective user) does not exist."
		unless defined $effectiveUser;

	# Check that the set is valid.  $self->{invalidSet} is set in checkSet called by ContentGenerator.pm.
	die $self->{invalidSet} if $self->{invalidSet};

	# Obtain the merged set for $effectiveUser
	my $set = $db->getMergedSet($effectiveUserID, $setID);

	# Determine if the set should be considered open.
	# It is open if the user can view unopened sets or is an instructor editing a problem from the problem editor,
	# or it is after the set open date and is not conditionally restricted and is not jitar hidden or closed.
	die 'You do not have permission to view unopened sets'
		unless $authz->hasPermissions($userID, 'view_unopened_sets')
		|| $setID eq 'Undefined_Set'
		|| (
			after($set->open_date, $self->r->submitTime)
			&& !(
				($ce->{options}{enableConditionalRelease} && is_restricted($db, $set, $effectiveUserID))
				|| (
					$set->assignment_type eq 'jitar'
					&& (is_jitar_problem_hidden($db, $effectiveUserID, $set->set_id, $problemID)
						|| is_jitar_problem_closed($db, $ce, $effectiveUserID, $set->set_id, $problemID))
				)
			)
		);

	# When a set is created enable_reduced_scoring is null, so we have to set it
	if ($set && $set->enable_reduced_scoring ne '0' && $set->enable_reduced_scoring ne '1') {
		my $globalSet = $db->getGlobalSet($set->set_id);
		$globalSet->enable_reduced_scoring('0');
		$db->putGlobalSet($globalSet);
		$set = $db->getMergedSet($effectiveUserID, $setID);
	}

	# Obtain the merged problem for the effective user.
	my $problem = $db->getMergedProblem($effectiveUserID, $setID, $problemID);

	if ($authz->hasPermissions($userID, 'modify_problem_sets')) {
		# This is the case of the problem editor for a user that can modify problem sets.

		# If a user set does not exist for this user and this set, then check
		# the global set.  If that does not exist, then create a fake set.  If it does, then add fake user data.
		unless (defined $set) {
			my $userSetClass = $db->{set_user}->{record};
			my $globalSet    = $db->getGlobalSet($setID);

			if (not defined $globalSet) {
				$set = fake_set($db);
			} else {
				$set = global2user($userSetClass, $globalSet);
				$set->psvn(0);
			}
		}

		# If a problem is not defined obtain the global problem, convert it to a user problem, and add fake user data.
		unless (defined $problem) {
			my $userProblemClass = $db->{problem_user}->{record};
			my $globalProblem    = $db->getGlobalProblem($setID, $problemID);

			# If the global problem doesn't exist either, bail!
			if (!defined $globalProblem) {
				my $sourceFilePath = $r->param('sourceFilePath');
				die 'sourceFilePath is unsafe!'
					unless path_is_subdir($sourceFilePath, $ce->{courseDirs}{templates}, 1);

				# These are problems from setmaker.  If declared invalid, they won't come up.
				$self->{invalidProblem} = $self->{invalidSet} = 1 unless defined $sourceFilePath;

				$problem = fake_problem($db);
				$problem->problem_id(1);
				$problem->source_file($sourceFilePath);
				$problem->user_id($effectiveUserID);
			} else {
				$problem = global2user($userProblemClass, $globalProblem);
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
		my $sourceFilePath = $r->param('sourceFilePath');
		if (defined $self->{editMode} && $self->{editMode} eq 'temporaryFile' && defined $sourceFilePath) {
			die 'sourceFilePath is unsafe!'
				unless path_is_subdir($sourceFilePath, $ce->{courseDirs}->{templates}, 1);
			$problem->source_file($sourceFilePath);
		}

		# If the problem does not have a source file or no source file has been passed in
		# then this is really an invalid problem (probably from a bad URL).
		$self->{invalidProblem} = !(defined $sourceFilePath || $problem->source_file);

		# If the caller is asking to override the problem seed, do so.
		my $problemSeed = $r->param('problemSeed');
		if (defined $problemSeed && $problemSeed =~ /^[+-]?\d+$/) {
			$problem->problem_seed($problemSeed);
		}

		$self->addmessage($set->visible
			? $r->tag('span', class => 'font-visible', $r->maketext('This set is visible to students.'))
			: $r->tag('span', class => 'font-hidden',  $r->maketext('This set is hidden from students.')));

	} else {
		# Test for additional problem validity if it's not already invalid.
		$self->{invalidProblem} =
			!(defined $problem && ($set->visible || $authz->hasPermissions($userID, 'view_hidden_sets')));

		$self->addbadmessage($r->maketext('This problem will not count towards your grade.'))
			if $problem && !$problem->value && !$self->{invalidProblem};
	}

	$self->{userID}          = $userID;
	$self->{effectiveUserID} = $effectiveUserID;
	$self->{user}            = $user;
	$self->{effectiveUser}   = $effectiveUser;
	$self->{set}             = $set;
	$self->{problem}         = $problem;

	# Form processing

	# Set options from form fields (see comment at top of file for form fields).
	my $displayMode = $r->param('displayMode') || $user->displayMode || $ce->{pg}->{options}->{displayMode};
	my $redisplay   = $r->param('redisplay');
	$self->{submitAnswers} = $r->param('submitAnswers');
	my $checkAnswers   = $r->param('checkAnswers');
	my $previewAnswers = $r->param('previewAnswers');
	my $requestNewSeed = $r->param('requestNewSeed') // 0;

	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };

	# Check for a page refresh which causes a cached form resubmission.  In that case this is
	# not a valid submission of answers.
	if (
		$set->set_id ne 'Undefined_Set'
		&& $self->{submitAnswers}
		&& (
			!defined $formFields->{num_attempts}
			|| (defined $formFields->{num_attempts}
				&& $formFields->{num_attempts} != $problem->num_correct + $problem->num_incorrect)
		)
		)
	{
		$self->{submitAnswers}    = 0;
		$self->{resubmitDetected} = 1;
	}

	$self->{displayMode}    = $displayMode;
	$self->{redisplay}      = $redisplay;
	$self->{checkAnswers}   = $checkAnswers;
	$self->{previewAnswers} = $previewAnswers;
	$self->{formFields}     = $formFields;

	# Get the status message and add it to the messages.
	$self->addmessage($r->tag('p', class => 'my-2', $r->b($r->param('status_message')))) if $r->param('status_message');

	# Now that the necessary variables are set, return if the set or problem is invalid.
	return if $self->{invalidSet} || $self->{invalidProblem};

	# Construct a hash containing information for showMeAnother.
	#   TriesNeeded:   the number of times the student needs to attempt the problem before the button is available
	#   MaxReps:       the Maximum Number of times that showMeAnother can be clicked (specified in course configuration
	#   Count:         the number of times the student has clicked SMA (or clicked refresh on the page)
	my %SMAoptions    = map { $_ => 1 } @{ $ce->{pg}{options}{showMeAnother} };
	my %showMeAnother = (
		TriesNeeded => $problem->{showMeAnother},
		MaxReps     => $ce->{pg}{options}{showMeAnotherMaxReps},
		Count       => $problem->{showMeAnotherCount},
	);

	# If $showMeAnother{Count} is somehow not an integer, make it one.
	$showMeAnother{Count} = 0 unless $showMeAnother{Count} =~ /^[+-]?\d+$/;

	# Store the showMeAnother hash for the check to see if the button can be used
	# (this hash is updated and re-stored after the can, must, will hashes)
	$self->{showMeAnother} = \%showMeAnother;

	# Permissions

	# What does the user want to do?
	my %want = (
		showOldAnswers => $user->showOldAnswers ne '' ? $user->showOldAnswers : $ce->{pg}{options}{showOldAnswers},
		# showProblemGrader implies showCorrectAnswers.  This is a convenience for grading.
		showCorrectAnswers => $r->param('showCorrectAnswers') || $r->param('showProblemGrader') || 0,
		showProblemGrader  => $r->param('showProblemGrader')  || 0,
		showAnsGroupInfo   => $r->param('showAnsGroupInfo')   || $ce->{pg}{options}{showAnsGroupInfo},
		showAnsHashInfo    => $r->param('showAnsHashInfo')    || $ce->{pg}{options}{showAnsHashInfo},
		showPGInfo         => $r->param('showPGInfo')         || $ce->{pg}{options}{showPGInfo},
		showResourceInfo   => $r->param('showResourceInfo')   || $ce->{pg}{options}{showResourceInfo},
		showHints          => 1,
		showSolutions      => 1,
		useMathView        => $user->useMathView ne ''    ? $user->useMathView    : $ce->{pg}{options}{useMathView},
		useWirisEditor     => $user->useWirisEditor ne '' ? $user->useWirisEditor : $ce->{pg}{options}{useWirisEditor},
		useMathQuill       => $user->useMathQuill ne ''   ? $user->useMathQuill   : $ce->{pg}{options}{useMathQuill},
		recordAnswers      => $self->{submitAnswers},
		checkAnswers       => $checkAnswers,
		getSubmitButton    => 1,
	);

	# Are certain options enforced?
	my %must = (
		showOldAnswers     => 0,
		showCorrectAnswers => 0,
		showProblemGrader  => 0,
		showAnsGroupInfo   => 0,
		showAnsHashInfo    => 0,
		showPGInfo         => 0,
		showResourceInfo   => 0,
		showHints          => 0,
		showSolutions      => 0,
		recordAnswers      => !$authz->hasPermissions($userID, 'avoid_recording_answers'),
		checkAnswers       => 0,
		showMeAnother      => 0,
		getSubmitButton    => 0,
		useMathView        => 0,
		useWirisEditor     => 0,
		useMathQuill       => 0,
	);

	# Does the user have permission to use certain options?
	my @args = ($user, $effectiveUser, $set, $problem);

	my %can = (
		showOldAnswers     => $self->can_showOldAnswers(@args),
		showCorrectAnswers => $self->can_showCorrectAnswers(@args),
		showProblemGrader  => $self->can_showProblemGrader(@args),
		showAnsGroupInfo   => $self->can_showAnsGroupInfo(@args),
		showAnsHashInfo    => $self->can_showAnsHashInfo(@args),
		showPGInfo         => $self->can_showPGInfo(@args),
		showResourceInfo   => $self->can_showResourceInfo(@args),
		showHints          => $self->can_showHints(@args),
		showSolutions      => $self->can_showSolutions(@args),
		recordAnswers      => $self->can_recordAnswers(@args),
		checkAnswers       => $self->can_checkAnswers(@args),
		showMeAnother      => $self->can_showMeAnother(@args),
		getSubmitButton    => $self->can_recordAnswers(@args, $self->{submitAnswers}),
		useMathView        => $self->can_useMathView,
		useWirisEditor     => $self->can_useWirisEditor,
		useMathQuill       => $self->can_useMathQuill,
	);

	# Re-randomization based on the number of attempts and specified period
	my $prEnabled         = $ce->{pg}{options}{enablePeriodicRandomization} // 0;
	my $rerandomizePeriod = $ce->{pg}{options}{periodicRandomizationPeriod} // 0;

	$problem->{prPeriod} = $ce->{problemDefaults}{prPeriod}
		if (defined $problem->{prPeriod} && $problem->{prPeriod} =~ /^\s*$/);

	$rerandomizePeriod = $problem->{prPeriod}
		if (defined $problem->{prPeriod} && $problem->{prPeriod} > -1);

	$prEnabled = 0 if ($rerandomizePeriod < 1 || $self->{editMode});
	if ($prEnabled) {
		$problem->{prCount} = 0
			if !defined $problem->{prCount} || $problem->{prCount} =~ /^\s*$/;

		$problem->{prCount} += $self->{submitAnswers} ? 1 : 0;

		$requestNewSeed = 0
			if ($problem->{prCount} < $rerandomizePeriod || after($set->due_date, $self->r->submitTime));

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
	my %will = map { $_ => $can{$_} && ($want{$_} || $must{$_}) } keys %must;

	# Sticky answers
	if (!($self->{submitAnswers} || $previewAnswers || $checkAnswers) && $will{showOldAnswers}) {
		my %oldAnswers = decodeAnswers($problem->last_answer);
		# Do this only if new answers are NOT being submitted
		if ($prEnabled && !$problem->{prCount}) {
			# Clear answers if this is a new problem version
			delete $formFields->{$_} for keys %oldAnswers;
		} else {
			$formFields->{$_} = $oldAnswers{$_} for keys %oldAnswers;
		}
	}

	# Translation
	debug('begin pg processing');
	my $pg = await renderPG(
		$r,
		$effectiveUser,
		$set, $problem,
		$set->psvn,
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
			useWirisEditor           => $will{useWirisEditor},
			forceScaffoldsOpen       => 0,
			isInstructor             => $authz->hasPermissions($userID, 'view_answers'),
			debuggingOptions         => getTranslatorDebuggingOptions($authz, $userID)
		}
	);

	# Warnings in the renderPG subprocess will not be caught by the global warning handler of this process.
	# So rewarn them and let the global warning handler take care of it.
	warn $pg->{warnings} if $pg->{warnings};

	debug('end pg processing');

	$pg->{body_text} .= $r->hidden_field(
		num_attempts => $problem->num_correct + $problem->num_incorrect + ($self->{submitAnswers} ? 1 : 0),
		id           => 'num_attempts'
	);

	if ($prEnabled && $problem->{prCount} >= $rerandomizePeriod && !after($set->due_date, $self->r->submitTime)) {
		$showMeAnother{active}          = 0;
		$must{requestNewSeed}           = 1;
		$can{requestNewSeed}            = 1;
		$want{requestNewSeed}           = 1;
		$will{requestNewSeed}           = 1;
		$self->{showCorrectOnRandomize} = $ce->{pg}{options}{showCorrectOnRandomize};
		# If this happens, it means that the page was refreshed.  So prevent the answers from
		# being recorded and the number of attempts from being increased.
		if ($problem->{prCount} > $rerandomizePeriod) {
			$self->{resubmitDetected} = 1;
			$must{recordAnswers}      = 0;
			$can{recordAnswers}       = 0;
			$want{recordAnswers}      = 0;
			$will{recordAnswers}      = 0;
		}
	}

	# Update and fix hint/solution options after PG processing
	$can{showHints}     &&= $pg->{flags}{hintExists};
	$can{showSolutions} &&= $pg->{flags}{solutionExists};

	# Record errors
	$self->{pgdebug}          = $pg->{debug_messages}          if ref $pg->{debug_messages} eq 'ARRAY';
	$self->{pgwarning}        = $pg->{warning_messages}        if ref $pg->{warning_messages} eq 'ARRAY';
	$self->{pginternalerrors} = $pg->{internal_debug_messages} if ref $pg->{internal_debug_messages} eq 'ARRAY';
	# $self->{pgerrors} is defined if any of the above are defined, and is nonzero if any are non-empty.
	$self->{pgerrors} =
		@{ $self->{pgdebug} // [] } || @{ $self->{pgwarning} // [] } || @{ $self->{pginternalerrors} // [] }
		if defined $self->{pgdebug} || defined $self->{pgwarning} || defined $self->{pginternalerrors};

	# If $self->{pgerrors} is not defined, then the PG messages arrays were not defined,
	# which means $pg->{pgcore} was not defined and the translator died.
	warn 'Processing of this PG problem was not completed.  Probably because of a syntax error. '
		. 'The translator died prematurely and no PG warning messages were transmitted.'
		unless defined $self->{pgerrors};

	# Store fields
	$self->{want} = \%want;
	$self->{must} = \%must;
	$self->{can}  = \%can;
	$self->{will} = \%will;
	$self->{pg}   = $pg;

	# Process and log answers
	$self->{scoreRecordedMessage} = process_and_log_answer($self) || '';

	return;
}

sub warnings {
	my $self = shift;
	my $r    = $self->r;

	my $output = $r->c;

	# Display warning messages
	if (!defined $self->{pgerrors}) {
		push(
			@$output,
			$r->tag(
				'div',
				$r->c(
					$r->tag('h3', style => 'color:red;', $r->maketext('PG question failed to render')),
					$r->tag('p',  $r->maketext('Unable to obtain error messages from within the PG question.'))
				)->join('')
			)
		);
	} elsif ($self->{pgerrors} > 0) {
		my @pgdebug          = @{ $self->{pgdebug}          // [] };
		my @pgwarning        = @{ $self->{pgwarning}        // [] };
		my @pginternalerrors = @{ $self->{pginternalerrors} // [] };
		push(
			@$output,
			$r->tag(
				'div',
				$r->c(
					$r->tag('h3', style => 'color:red;', $r->maketext('PG question processing error messages')),
					@pgdebug ? $r->tag(
						'p',
						$r->c(
							$r->tag('h3', $r->maketext('PG debug messages')), r->c(@pgdebug)->join($r->tag('br'))
						)->join('')
					) : '',
					@pgwarning ? $r->tag(
						'p',
						$r->c($r->tag('h3', $r->maketext('PG warning messages')),
							$r->c(@pgwarning)->join($r->tag('br')))->join('')
					) : '',
					@pginternalerrors ? $r->tag(
						'p',
						$r->c(
							$r->tag('h3', $r->maketext('PG internal errors')),
							$r->c(@pginternalerrors)->join($r->tag('br'))
						)->join('')
					) : ''
				)->join('')
			)
		);
	}

	push(@$output, $self->SUPER::warnings());

	return $output->join('');
}

sub head {
	my ($self) = @_;
	return ''                       if ($self->{invalidSet});
	return $self->{pg}->{head_text} if $self->{pg}->{head_text};
	return '';
}

sub post_header_text {
	my ($self) = @_;
	return ''                              if ($self->{invalidSet});
	return $self->{pg}->{post_header_text} if $self->{pg}->{post_header_text};
	return '';
}

sub siblings {
	my ($self)  = @_;
	my $r       = $self->r;
	my $db      = $r->db;
	my $ce      = $r->ce;
	my $authz   = $r->authz;
	my $urlpath = $r->urlpath;

	# Can't show sibling problems if the set is invalid.
	return '' if $self->{invalidSet};

	my $courseID = $urlpath->arg('courseID');
	my $setID    = $self->{set}->set_id;
	my $eUserID  = $r->param('effectiveUser');

	my @problemRecords = $db->getMergedProblemsWhere({ user_id => $eUserID, set_id => $setID }, 'problem_id');
	my @problemIDs     = map { $_->problem_id } @problemRecords;

	my $isJitarSet = $setID ne 'Undefined_Set' && $self->{set}->assignment_type eq 'jitar' ? 1 : 0;

	# Variables for the progress bar
	my $num_of_problems = 0;
	my $problemList;
	my $total_correct    = 0;
	my $total_incorrect  = 0;
	my $total_inprogress = 0;
	my $currentProblemID = $self->{invalidProblem} ? 0 : $self->{problem}->problem_id;

	my $progressBarEnabled = $r->ce->{pg}{options}{enableProgressBar};

	my @items;

	# Keep the grader open when linking to problems if it is already open.
	my %problemGraderLink = $self->{will}{showProblemGrader} ? (params => { showProblemGrader => 1 }) : ();

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

			my $status = $problemRecord->status;
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

		my $problemPage = $urlpath->newFromModule(
			'WeBWorK::ContentGenerator::Problem', $r,
			courseID  => $courseID,
			setID     => $setID,
			problemID => $problemID
		);

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
					$r->link_to(
						$r->maketext('Problem [_1]', join('.', @seq)) => '#',
						class                                         => $class . ' disabled-problem',
					)
				);
			} else {
				push(
					@items,
					$r->tag(
						'a',
						$active ? () : (href => $self->systemLink($problemPage, %problemGraderLink)),
						class => $class,
						$r->b($r->maketext('Problem [_1]', join('.', @seq)) . $status_symbol)
					)
				);
			}
		} else {
			push(
				@items,
				$r->tag(
					'a',
					$active ? () : (href => $self->systemLink($problemPage, %problemGraderLink)),
					class => 'nav-link' . ($active ? ' active' : ''),
					$r->b($r->maketext('Problem [_1]', $problemID) . $status_symbol)
				)
			);
		}
	}

	return $r->include(
		'ContentGenerator/Problem/siblings',
		items            => \@items,
		num_of_problems  => $num_of_problems,
		total_correct    => $total_correct,
		total_incorrect  => $total_incorrect,
		total_inprogress => $total_inprogress,
	);
}

sub nav {
	my ($self, $args) = @_;
	my $r   = $self->r;
	my %can = %{ $self->{can} };

	my $db      = $r->db;
	my $ce      = $r->ce;
	my $authz   = $r->authz;
	my $urlpath = $r->urlpath;

	my $courseID  = $urlpath->arg('courseID');
	my $setID     = $self->{set}->set_id;
	my $problemID = $self->{invalidProblem} ? 0 : $self->{problem}->problem_id;
	my $userID    = $r->param('user');
	my $eUserID   = $r->param('effectiveUser');

	my $mergedSet = $db->getMergedSet($eUserID, $setID);
	return '' if $self->{invalidSet} || !$mergedSet;

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

		my $filter = $r->param('studentNavFilter');

		# Find the previous, current, and next users, and format the student names for display.
		# Also create a hash of sections and recitations if there are any for the course.
		my @userRecords;
		my $currentUserIndex = 0;
		my %filters;
		for (@allUserRecords) {
			# Add to the sections and recitations if defined.  Also store the first user found in that section or
			# recitation.  This user will be switched to when the filter is selected.
			my $section = $_->section;
			$filters{"section:$section"} = [ $r->maketext('Filter by section [_1]', $section), $_->user_id ]
				if $section && !$filters{"section:$section"};
			my $recitation = $_->recitation;
			$filters{"recitation:$recitation"} = [ $r->maketext('Filter by recitation [_1]', $recitation), $_->user_id ]
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

		my $problemPage = $urlpath->newFromModule(
			__PACKAGE__, $r,
			courseID  => $courseID,
			setID     => $setID,
			problemID => $problemID
		);

		# Set up the student nav.
		$userNav = $r->include(
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
	if (!$self->{invalidProblem}) {
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
		my $prevPage = $urlpath->newFromModule(
			__PACKAGE__, $r,
			courseID  => $courseID,
			setID     => $setID,
			problemID => $prevID
		);
		push @links, $r->maketext('Previous Problem'), $r->location . $prevPage->path, $r->maketext('Previous Problem');
	} else {
		push @links, $r->maketext('Previous Problem'), '', $r->maketext('Previous Problem');
	}

	if (defined $setID && $setID ne 'Undefined_Set') {
		push @links, $r->maketext('Problem List'), $r->location . $urlpath->parent->path, $r->maketext('Problem List');
	} else {
		push @links, $r->maketext('Problem List'), '', $r->maketext('Problem List');
	}

	if ($nextID) {
		my $nextPage = $urlpath->newFromModule(
			__PACKAGE__, $r,
			courseID  => $courseID,
			setID     => $setID,
			problemID => $nextID
		);
		push @links, $r->maketext('Next Problem'), $r->location . $nextPage->path, $r->maketext('Next Problem');
	} else {
		push @links, $r->maketext('Next Problem'), '', $r->maketext('Next Problem');
	}

	my $tail = '';
	$tail .= "&displayMode=$self->{displayMode}"                   if defined $self->{displayMode};
	$tail .= "&showOldAnswers=$self->{will}{showOldAnswers}"       if defined $self->{will}{showOldAnswers};
	$tail .= "&showProblemGrader=$self->{will}{showProblemGrader}" if defined $self->{will}{showProblemGrader};
	$tail .= '&studentNavFilter=' . $r->param('studentNavFilter')  if $r->param('studentNavFilter');

	return $r->tag(
		'div',
		class        => 'row sticky-nav',
		role         => 'navigation',
		'aria-label' => 'problem navigation',
		$r->c($r->tag('div', class => 'd-flex submit-buttons-container', $self->navMacro($args, $tail, @links)),
			$userNav)->join('')
	);
}

sub path {
	my ($self, $args) = @_;
	my $r                   = $self->r;
	my $urlpath             = $r->urlpath;
	my $courseID            = $urlpath->arg('courseID');
	my $setID               = $urlpath->arg('setID')     || '';
	my $problemID           = $urlpath->arg('problemID') || '';
	my $prettyProblemNumber = $problemID;

	if ($setID) {
		my $set = $r->db->getGlobalSet($setID);
		if ($set && $set->assignment_type eq 'jitar' && $problemID) {
			$prettyProblemNumber = join('.', jitar_id_to_seq($problemID));
		}
	}

	my $navigation_allowed = $r->authz->hasPermissions($r->param('user'), 'navigation_allowed');

	my @path = (
		WeBWorK   => $navigation_allowed ? $r->location                : '',
		$courseID => $navigation_allowed ? $r->location . "/$courseID" : '',
		$setID    => $r->location . "/$courseID/$setID",
	);

	if ($urlpath->module =~ /ShowMeAnother$/) {
		push(
			@path,
			$prettyProblemNumber => $r->location . "/$courseID/$setID/$problemID",
			'Show Me Another'    => ''
		);
	} else {
		push(@path, $prettyProblemNumber => '');
	}

	return $self->pathMacro($args, @path);
}

sub title {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;

	my $setID     = $self->r->urlpath->arg('setID');
	my $problemID = $self->r->urlpath->arg('problemID');

	my $set = $db->getGlobalSet($setID);
	if ($set && $set->assignment_type eq 'jitar') {
		$problemID = join('.', jitar_id_to_seq($problemID));
	}
	my $header =
		$r->maketext('[_1]: Problem [_2]', $r->tag('span', dir => 'ltr', format_set_name_display($setID)), $problemID);

	# Return here if we don't have the requisite information.
	return $header if ($self->{invalidSet} || $self->{invalidProblem});

	my $ce      = $r->ce;
	my $problem = $self->{problem};

	my $subheader = '';

	my $problemValue = $problem->value;
	if (defined $problemValue && $problemValue ne '') {
		$subheader .= $r->maketext('([quant,_1,point])', $problemValue);
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
	if ($r->authz->hasPermissions($r->param('user'), 'modify_problem_sets')) {
		$subheader = $r->c(
			$subheader,
			$r->tag(
				'span',
				class => 'ms-2',
				$r->link_to(
					$r->maketext('Edit') => $self->systemLink(
						$r->urlpath->newFromModule(
							'WeBWorK::ContentGenerator::Instructor::PGProblemEditor', $r,
							courseID  => $r->urlpath->arg('courseID'),
							setID     => $self->{set}->set_id,
							problemID => $self->{problem}->problem_id
						),
						# If we are here without a real homework set, carry that through.
						$self->{set}->set_id eq 'Undefined_Set'
						? (params => [ 'sourceFilePath' => $r->param('sourceFilePath') ])
						: ()
					),
					target => 'WW_Editor',
					class  => 'btn btn-sm btn-secondary'
				)
			)
		)->join('');
	}

	return $r->c($header, $r->tag('span', class => 'problem-sub-header d-block', $subheader))->join('');
}

# Add a lang and maybe also a dir setting to the DIV tag attributes, if needed by the PROBLEM language.
sub output_problem_lang_and_dir {
	my $self = shift;
	return get_problem_lang_and_dir(
		$self->{pg}{flags},
		$self->r->ce->{perProblemLangAndDirSettingMode},
		$self->r->ce->{language}
	);
}

# Output the body of the current problem
sub output_problem_body {
	my $self = shift;
	my $r    = $self->r;

	# If there are translation errors then render those with the body text of the problem.
	if ($self->{pg}{flags}{error_flag}) {
		if ($r->authz->hasPermissions($r->param('user'), 'view_problem_debugging_info')) {
			# For instructors render the body text of the problem with the errors.
			return $r->include(
				'ContentGenerator/Base/error_output',
				error   => $self->{pg}{errors},
				details => $self->{pg}{body_text}
			);
		} else {
			# For students render the body text of the problem with a message about error details.
			return $r->c(
				$r->tag('div', id => 'output_problem_body', $r->b($self->{pg}{body_text})),
				$r->include(
					'ContentGenerator/Base/error_output',
					error   => $self->{pg}{errors},
					details => $r->maketext('You do not have permission to view the details of this error.')
				)
			)->join('');
		}
	}

	return $r->tag('div', id => 'output_problem_body', $r->b($self->{pg}{body_text}));
}

# Output messages about the problem
sub output_message {
	my $self = shift;
	return $self->r->include('ContentGenerator/Problem/messages');
}

# Output the problem grader if the user has permissions to grade problems
sub output_grader {
	my $self = shift;

	if ($self->{will}{showProblemGrader}) {
		return WeBWorK::HTML::SingleProblemGrader->new($self->r, $self->{pg}, $self->{problem})->insertGrader;
	}

	return '';
}

# Output the checkbox input elements that are available for the current problem
sub output_checkboxes {
	my $self = shift;
	return $self->r->include('ContentGenerator/Problem/checkboxes');
}

# Output the submit button input elements that are available for the current problem
sub output_submit_buttons {
	my $self = shift;
	return $self->r->include('ContentGenerator/Problem/submit_buttons');
}

# Output a summary of the student's current progress and status on the current problem.
sub output_score_summary {
	my $self          = shift;
	my $r             = $self->r;
	my $ce            = $r->ce;
	my $db            = $r->db;
	my $problem       = $self->{problem};
	my $set           = $self->{set};
	my $pg            = $self->{pg};
	my $effectiveUser = $r->param('effectiveUser') || $r->param('user');

	my $prEnabled         = $ce->{pg}{options}{enablePeriodicRandomization} // 0;
	my $rerandomizePeriod = $ce->{pg}{options}{periodicRandomizationPeriod} // 0;
	$rerandomizePeriod = $problem->{prPeriod} if defined $problem->{prPeriod} && $problem->{prPeriod} > -1;
	$prEnabled         = 0                    if $rerandomizePeriod < 1;

	warn 'num_correct = ' . $problem->num_correct . 'num_incorrect = ' . $problem->num_incorrect
		unless defined $problem->num_correct && defined $problem->num_incorrect;

	my $prMessage = '';
	if ($prEnabled) {
		my $attempts_before_rr = $self->{will}{requestNewSeed} ? 0 : ($rerandomizePeriod - $problem->{prCount});

		$prMessage = ' '
			. $r->maketext('You have [quant,_1,attempt,attempts] left before new version will be requested.',
				$attempts_before_rr)
			if $attempts_before_rr > 0;

		$prMessage = ' ' . $r->maketext('Request new version now.') if ($attempts_before_rr == 0);
	}
	$prMessage = '' if after($set->due_date, $self->r->submitTime) or before($set->open_date, $self->r->submitTime);

	my $setClosed = 0;
	my $setClosedMessage;
	if (before($set->open_date, $self->r->submitTime) || after($set->due_date, $self->r->submitTime)) {
		$setClosed = 1;
		if (before($set->open_date, $self->r->submitTime)) {
			$setClosedMessage = $r->maketext('This homework set is not yet open.');
		} elsif (after($set->due_date, $self->r->submitTime)) {
			$setClosedMessage = $r->maketext('This homework set is closed.');
		}
	}

	my $attempts = $problem->num_correct + $problem->num_incorrect;

	my $output = $r->c;

	unless (defined $pg->{state}{state_summary_msg} && $pg->{state}{state_summary_msg} =~ /\S/) {
		push(
			@$output,
			$self->{submitAnswers} ? $self->{scoreRecordedMessage} . $r->tag('br') : '',
			$r->maketext('You have attempted this problem [quant,_1,time,times].', $attempts),
			$prMessage,
			$r->tag('br'),
			$self->{submitAnswers}
			? (
				$r->maketext(
					'You received a score of [_1] for this attempt.',
					wwRound(
						0,
						compute_reduced_score($ce, $problem, $set, $pg->{result}{score}, $self->r->submitTime) *
							100
						)
						. '%'
				),
				$r->tag('br')
				)
			: '',
			$problem->attempted
			? (
				$r->maketext(
					'Your overall recorded score is [_1].  [_2]',
					wwRound(0, $problem->status * 100) . '%',
					$problem->value ? '' : $r->maketext('(This problem will not count towards your grade.)')
				),
				$r->tag('br')
				)
			: '',
			$setClosed ? $setClosedMessage : $r->maketext(
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
				$r->tag('br'),
				$r->maketext(
					'This problem has open subproblems.  '
						. 'You can visit them by using the links to the left or visiting the set page.'
				)
			);

			if (scalar(@children_counts_indexs) == 1) {
				push(
					@$output,
					$r->tag('br'),
					$r->maketext(
						'The grade for this problem is the larger of the score for this problem, '
							. 'or the score of problem [_1].',
						join('.', @{ $problemSeqs[ $children_counts_indexs[0] ] })
					)
				);
			} elsif (scalar(@children_counts_indexs) > 1) {
				push(
					@$output,
					$r->tag('br'),
					$r->maketext(
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
					$r->tag('br'),
					$r->maketext(
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
					$r->tag('br'),
					$r->maketext(
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
				$r->tag('br'),
				$r->maketext(
					'The score for this problem can count towards score of problem [_1].', join('.', @seq)
				)
			);
		} elsif (scalar(@seq) != 1) {
			pop @seq;
			push(
				@$output,
				$r->tag('br'),
				$r->maketext(
					'This score for this problem does not count for the score of problem [_1] or for the set.',
					join('.', @seq)
				)
			);
		}

		# If the instructor has set this up, then email the instructor a warning message if the student has run out of
		# attempts on a top level problem and all of its children and didn't get 100%.
		if ($self->{submitAnswers} && $set->email_instructor) {
			my $parentProb = $db->getMergedProblem($effectiveUser, $set->set_id, seq_to_jitar_id($seq[0]));
			warn("Couldn't find problem $seq[0] from set " . $set->set_id . ' in the database') unless $parentProb;

			if (jitar_problem_finished($parentProb, $db) && jitar_problem_adjusted_status($parentProb, $db) != 1) {
				jitar_send_warning_email($self, $parentProb);
			}

		}
	}

	return $r->tag('p', $output->join(''));
}

# Output other necessary elements
sub output_misc {
	my $self = shift;
	my $r    = $self->r;

	my $output = $r->c;

	# Save state for viewOptions
	push(@$output,
		$r->hidden_field(showOldAnswers => $self->{will}{showOldAnswers}),
		$r->hidden_field(displayMode    => $self->{displayMode}));

	push(@$output, $r->hidden_field(editMode => $self->{editMode}))
		if defined $self->{editMode} && $self->{editMode} eq 'temporaryFile';

	my $permissionLevel          = $r->db->getPermissionLevel($r->param('user'))->permission;
	my $professorPermissionLevel = $r->ce->{userRoles}{professor};

	# Only allow this for professors
	push(@$output, $r->hidden_field(sourceFilePath => $self->{problem}{source_file}))
		if defined $self->{problem}{source_file} && $permissionLevel >= $professorPermissionLevel;

	# Only allow this for professors
	push(@$output, $r->hidden_field(problemSeed => $r->param('problemSeed')))
		if defined $r->param('problemSeed') && $permissionLevel >= $professorPermissionLevel;

	# Make sure the student nav filter setting is preserved when the problem form is submitted.
	push(@$output, $r->hidden_field(studentNavFilter => $r->param('studentNavFilter')))
		if $r->param('studentNavFilter');

	return $output->join('');
}

# Output any instructor comments present in the latest past_answer entry
sub output_comments {
	my $self    = shift;
	my $r       = $self->r;
	my $db      = $r->db;
	my $urlpath = $r->urlpath;

	my $userPastAnswerID = $db->latestProblemPastAnswer(
		$urlpath->arg('courseID'), $r->param('effectiveUser'),
		$urlpath->arg('setID'),    $urlpath->arg('problemID')
	);

	# If there is a comment then display it.
	if ($userPastAnswerID) {
		my $userPastAnswer = $db->getPastAnswer($userPastAnswerID);
		if ($userPastAnswer->comment_string) {
			return $r->tag(
				'div',
				id    => 'answerComment',
				class => 'answerComments mt-2',
				$r->c($r->tag('b', 'Instructor Comment:'), $r->tag('div', $userPastAnswer->comment_string))
					->join('')
			);
		}
	}

	return '';
}

# Output the summary of the questions that the student has answered
# for the current problem, along with available information about correctness
sub output_summary {
	my $self = shift;
	my $r    = $self->r;
	my $db   = $r->db;
	my $pg   = $self->{pg};
	my %will = %{ $self->{will} };

	my $output = $r->c;

	# Attempt summary
	if (defined $pg->{flags}{showPartialCorrectAnswers}
		&& $pg->{flags}{showPartialCorrectAnswers} >= 0
		&& $self->{submitAnswers})
	{
		push(
			@$output,
			$self->attemptResults(
				$pg,
				$self->{showCorrectOnRandomize} // $will{showCorrectAnswers},
				$pg->{flags}{showPartialCorrectAnswers}, 1
			)
		);
	} elsif ($will{checkAnswers} || $self->{will}{showProblemGrader}) {
		push(
			@$output,
			$r->tag(
				'div',
				class => 'ResultsWithError d-inline-block mb-3',
				$r->maketext('ANSWERS ONLY CHECKED -- ANSWERS NOT RECORDED')
			),
			$self->attemptResults($pg, $will{showCorrectAnswers}, 1, 1)
		);
	} elsif ($self->{previewAnswers}) {
		push(
			@$output,
			$r->tag(
				'div',
				class => 'ResultsWithError d-inline-block mb-3',
				$r->maketext('PREVIEW ONLY -- ANSWERS NOT RECORDED')
			),
			$self->attemptResults($pg, 0, 0, 0)
		);
	}

	push(
		@$output,
		$r->tag(
			'div',
			class => 'ResultsWithError d-inline-block mb-3',
			$r->maketext(
				'ATTEMPT NOT ACCEPTED -- Please submit answers again (or request new version if neccessary).')
		)
	) if $self->{resubmitDetected};

	if ($self->{set}->set_id ne 'Undefined_Set' && $self->{set}->assignment_type eq 'jitar') {
		my $hasChildren = 0;

		my @problemIDs =
			map { $_->[2] }
			$db->listUserProblemsWhere({ user_id => $r->param('effectiveUser'), set_id => $self->{set}->set_id },
				'problem_id');

		my @problemSeqs;
		my $index;
		# This sets of an array of the sequence associated to the problem_id.
		for (my $i = 0; $i <= $#problemIDs; $i++) {
			$index = $i if ($problemIDs[$i] == $self->{problem}->problem_id);
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
					$self->{problem}->att_to_open_children != -1
					&& $self->{problem}->num_incorrect >= $self->{problem}->att_to_open_children
				)
				|| ($self->{problem}->max_attempts != -1
					&& $self->{problem}->num_incorrect >= $self->{problem}->max_attempts)
			)
			)
		{
			push(
				@$output,
				$r->tag(
					'div',
					class => 'showMeAnotherBox',
					$r->maketext(
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
sub output_achievement_message {
	my $self = shift;
	my $r    = $self->r;

	# If achievements are enabled and this is not an undefined set,
	# check to see if there are new achievements and output them.
	if ($r->ce->{achievementsEnabled}
		&& $self->{will}{recordAnswers}
		&& $self->{submitAnswers}
		&& $self->{problem}->set_id ne 'Undefined_Set')
	{
		return checkForAchievements($self->{problem}, $self->{pg}, $r);
	}

	return '';
}

# Puts the tags in the page
sub output_tag_info {
	my $self = shift;
	my $r    = $self->r;

	if ($r->authz->hasPermissions($r->param('user'), 'modify_tags')) {
		return $r->c(
			$r->tag(
				'div',
				id    => 'tagger',
				class => 'tag-widget',
				data  =>
					{ source_file_path => $r->ce->{courseDirs}{templates} . '/' . $self->{problem}{source_file} },
				''
			),
			$r->hidden_field(courseID => $self->r->urlpath->arg('courseID'), id => 'hidden_courseID')
		)->join('');
	}

	return '';
}

# Output a custom edit message
sub output_custom_edit_message {
	my $self = shift;
	my $r    = $self->r;

	if ($r->authz->hasPermissions($r->param('user'), 'modify_problem_sets')
		&& $self->{editMode}
		&& $self->{editMode} eq 'temporaryFile')
	{
		return $r->tag(
			'p',
			class => 'temporaryFile',
			$r->maketext('Viewing temporary file: [_1]', $self->{problem}->source_file)
		);
	}

	return '';
}

# Output the "Show Past Answers" button
sub output_past_answer_button {
	my $self    = shift;
	my $r       = $self->r;
	my $urlpath = $r->urlpath;

	my $courseID = $urlpath->arg('courseID');

	my $problemID = $self->{problem}->problem_id;
	my $setRecord = $r->db->getGlobalSet($self->{problem}->set_id);
	if (defined $setRecord && $setRecord->assignment_type eq 'jitar') {
		$problemID = join('.', jitar_id_to_seq($problemID));
	}

	if ($r->authz->hasPermissions($r->param('user'), 'view_answers')) {
		my $hiddenFields = $self->hidden_authen_fields;
		$hiddenFields =~ s/\"hidden_/\"pastans-hidden_/g;
		return $r->form_for(
			$self->systemLink(
				$urlpath->newFromModule(
					'WeBWorK::ContentGenerator::Instructor::ShowAnswers',
					$r, courseID => $courseID
				),
				authen => 0
			),
			method => 'POST',
			target => 'WW_Info',
			$r->c(
				$hiddenFields,
				$r->hidden_field(courseID          => $courseID),
				$r->hidden_field(selected_problems => $problemID),
				$r->hidden_field(selected_sets     => $self->{problem}->set_id),
				$r->hidden_field(selected_users    => $self->{problem}->user_id),
				$r->tag(
					'p',
					$r->submit_button(
						$r->maketext('Show Past Answers'),
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
sub output_email_instructor {
	my $self = shift;
	my $r    = $self->r;

	my $user = $r->db->getUser($r->param('user'));

	return $self->feedbackMacro(
		module          => __PACKAGE__,
		courseId        => $r->urlpath->arg('courseID'),
		set             => $self->{set}->set_id,
		problem         => $self->{problem}->problem_id,
		problemPath     => $self->{problem}->source_file,
		randomSeed      => $self->{problem}->problem_seed,
		notifyAddresses => join(';', $self->fetchEmailRecipients('receive_feedback', $user)),
		emailableURL    => $self->generateURLs(
			url_type   => 'absolute',
			set_id     => $self->{set}->set_id,
			problem_id => $self->{problem}->problem_id
		),
		studentName        => $user->full_name,
		displayMode        => $self->{displayMode},
		showOldAnswers     => $self->{will}{showOldAnswers},
		showCorrectAnswers => $self->{will}{showCorrectAnswers},
		showHints          => $self->{will}{showHints},
		showSolutions      => $self->{will}{showSolutions},
		pg_object          => $self->{pg},
	);
}

1;
