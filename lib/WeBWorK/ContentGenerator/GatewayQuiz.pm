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

package WeBWorK::ContentGenerator::GatewayQuiz;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator::GatewayQuiz - display a quiz of problems on one page,
deal with versioning sets

=cut

use Mojo::Promise;
use Mojo::JSON qw(encode_json decode_json);

use WeBWorK::PG::ImageGenerator;
use WeBWorK::Utils qw(writeLog writeCourseLogGivenTime encodeAnswers decodeAnswers
	path_is_subdir before after between wwRound is_restricted);
use WeBWorK::Utils::Instructor qw(assignSetVersionToUser);
use WeBWorK::Utils::Rendering qw(getTranslatorDebuggingOptions renderPG);
use WeBWorK::Utils::ProblemProcessing qw/create_ans_str_from_responses compute_reduced_score/;
use WeBWorK::DB::Utils qw(global2user);
use WeBWorK::Utils::Tasks qw(fake_set fake_set_version fake_problem);
use WeBWorK::Debug;
use WeBWorK::Authen::LTIAdvanced::SubmitGrade;
use WeBWorK::Authen::LTIAdvantage::SubmitGrade;
use PGrandom;
use Caliper::Sensor;
use Caliper::Entity;

# Disable links for gateway tests.
sub can ($c, $arg) {
	return $arg eq 'links' ? 0 : $c->SUPER::can($arg);
}

# "can" methods
# Subroutines to determine if a user "can" perform an action. Each subroutine is
# called with the following arguments:
#   ($c, $user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet)
# In addition can_recordAnswers and can_checkAnswers have the argument $submitAnswers
# that is used to distinguish between this submission and the next.

sub can_showOldAnswers ($c, $user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet) {
	my $authz = $c->authz;

	return 0 unless $authz->hasPermissions($user->user_id, 'can_show_old_answers');

	return (
		before($set->due_date, $c->submitTime)
			|| $authz->hasPermissions($user->user_id, 'view_hidden_work')
			|| ($set->hide_work eq 'N'
				|| ($set->hide_work eq 'BeforeAnswerDate' && after($tmplSet->answer_date, $c->submitTime)))
	);
}

sub can_showCorrectAnswers ($c, $user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet) {
	my $authz = $c->authz;

	# Allow correct answers to be viewed after all attempts at a version
	# are exhausted or if it is after the answer date.
	my $attemptsPerVersion = $set->attempts_per_version || 0;
	my $attemptsUsed       = $problem->num_correct + $problem->num_incorrect + ($c->{submitAnswers} ? 1 : 0);

	# This is complicated by trying to address hiding scores by problem.  That is, if $set->hide_score_by_problem and
	# $set->hide_score are both set, then we should allow scores to be shown, but not show the score on any individual
	# problem.  To deal with this, we make can_showCorrectAnswers give the least restrictive view of hiding, and then
	# filter scores for the problems themselves later.
	return (
		(
			(
				after($set->answer_date, $c->submitTime) || ($attemptsUsed >= $attemptsPerVersion
					&& $attemptsPerVersion != 0
					&& $set->due_date == $set->answer_date)
			)
				|| $authz->hasPermissions($user->user_id, 'show_correct_answers_before_answer_date')
		)
			&& (
				$authz->hasPermissions($user->user_id, 'view_hidden_work')
				|| $set->hide_score_by_problem eq 'N' && ($set->hide_score eq 'N'
					|| ($set->hide_score eq 'BeforeAnswerDate' && after($tmplSet->answer_date, $c->submitTime)))
			)
	);
}

sub can_showProblemGrader ($c, $user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet) {
	my $authz = $c->authz;

	return ($authz->hasPermissions($user->user_id, 'access_instructor_tools')
			&& $authz->hasPermissions($user->user_id, 'score_sets')
			&& $set->set_id ne 'Undefined_Set'
			&& !$c->{invalidSet});
}

sub can_showHints ($c) { return 1; }

sub can_showSolutions ($c, $user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet) {
	my $authz = $c->authz;

	return 1 if $authz->hasPermissions($user->user_id, 'always_show_solution');

	# This is the same as can_showCorrectAnswers.
	return $c->can_showCorrectAnswers($user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet);
}

# Allow for a version_last_attempt_time which is the time the set was submitted. If that is present we use that instead
# of the current time to decide if answers can be recorded.  This deals with the time between the submission time and
# the proctor authorization.
sub can_recordAnswers ($c, $user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet = 0, $submitAnswers = 0) {
	my $authz = $c->authz;

	# Never record answers for undefined sets
	return 0 if $set->set_id eq 'Undefined_Set';

	if ($user->user_id ne $effectiveUser->user_id) {
		# If the user is not allowed to record answers as another user, return that permission.  If the user is allowed
		# to record only set version answers, then allow that between the open and close dates, and so drop out of this
		# conditional to the usual one.
		return 1 if $authz->hasPermissions($user->user_id,  'record_answers_when_acting_as_student');
		return 0 if !$authz->hasPermissions($user->user_id, 'record_set_version_answers_when_acting_as_student');
	}

	my $submitTime =
		($set->assignment_type eq 'proctored_gateway' && $set->version_last_attempt_time)
		? $set->version_last_attempt_time
		: $c->submitTime;

	return $authz->hasPermissions($user->user_id, 'record_answers_before_open_date')
		if before($set->open_date, $submitTime);

	if (between($set->open_date, $set->due_date + $c->ce->{gatewayGracePeriod}, $submitTime)) {
		# Look at maximum attempts per version, not for the set, to determine the number of attempts allowed.
		my $attemptsPerVersion = $set->attempts_per_version || 0;
		my $attemptsUsed       = $problem->num_correct + $problem->num_incorrect + ($submitAnswers ? 1 : 0);

		if ($attemptsPerVersion == 0 || $attemptsUsed < $attemptsPerVersion) {
			return $authz->hasPermissions($user->user_id, 'record_answers_after_open_date_with_attempts');
		} else {
			return $authz->hasPermissions($user->user_id, 'record_answers_after_open_date_without_attempts');
		}
	}

	return $authz->hasPermissions($user->user_id, 'record_answers_after_due_date')
		if between(($set->due_date + $c->ce->{gatewayGracePeriod}), $set->answer_date, $submitTime);

	return $authz->hasPermissions($user->user_id, 'record_answers_after_answer_date')
		if after($set->answer_date, $submitTime);

	return 0;
}

# Allow for a version_last_attempt_time which is the time the set was submitted.  If that is present, then use that
# instead of the current time to decide if answers can be checked.  This deals with the time between the submission time
# and the proctor authorization.
sub can_checkAnswers ($c, $user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet, $submitAnswers = 0) {
	my $authz = $c->authz;

	return 0
		if $c->can_recordAnswers($user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet, $submitAnswers)
		&& !$authz->hasPermissions($user->user_id, 'can_check_and_submit_answers');

	my $submitTime =
		($set->assignment_type eq 'proctored_gateway' && $set->version_last_attempt_time)
		? $set->version_last_attempt_time
		: $c->submitTime;

	return $authz->hasPermissions($user->user_id, 'check_answers_before_open_date')
		if before($set->open_date, $submitTime);

	# This is complicated by trying to address hiding scores by problem.  If $set->hide_score_by_problem and
	# $set->hide_score are both set, then allow scores to be shown, but don't show the score on any individual problem.
	# To deal with this, use the least restrictive view of hiding, and then filter for the problems themselves later.

	my $canShowProblemScores =
		$c->can_showProblemScores($user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet);

	if (between($set->open_date, $set->due_date + $c->ce->{gatewayGracePeriod}, $submitTime)) {
		# Look at maximum attempts per version, not for the set, to determine the number of attempts allowed.
		my $attempts_per_version = $set->attempts_per_version || 0;
		my $attempts_used        = $problem->num_correct + $problem->num_incorrect + ($submitAnswers ? 1 : 0);

		if ($attempts_per_version == -1 || $attempts_used < $attempts_per_version) {
			return $authz->hasPermissions($user->user_id, 'check_answers_after_open_date_with_attempts')
				&& $canShowProblemScores;
		} else {
			return $authz->hasPermissions($user->user_id, 'check_answers_after_open_date_without_attempts')
				&& $canShowProblemScores;
		}
	}

	return $authz->hasPermissions($user->user_id, 'check_answers_after_due_date') && $canShowProblemScores
		if between(($set->due_date + $c->ce->{gatewayGracePeriod}), $set->answer_date, $submitTime);

	return $authz->hasPermissions($user->user_id, 'check_answers_after_answer_date') && $canShowProblemScores
		if after($set->answer_date, $submitTime);

	return 0;
}

sub can_showScore ($c, $user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet) {
	return
		$c->authz->hasPermissions($user->user_id, 'view_hidden_work')
		|| $set->hide_score eq 'N'
		|| ($set->hide_score eq 'BeforeAnswerDate' && after($tmplSet->answer_date, $c->submitTime));
}

sub can_showProblemScores ($c, $user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet) {
	return $c->can_showScore($user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet)
		&& ($set->hide_score_by_problem eq 'N' || $c->authz->hasPermissions($user->user_id, 'view_hidden_work'));
}

sub can_showWork ($c, $user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet) {
	return $c->authz->hasPermissions($user->user_id, 'view_hidden_work')
		|| ($set->hide_work eq 'N'
			|| ($set->hide_work eq 'BeforeAnswerDate' && $c->submitTime > $tmplSet->answer_date));
}

sub can_useMathView ($c) {
	return $c->ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathView';
}

sub can_useMathQuill ($c) {
	return $c->ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathQuill';
}

# Output utility
sub attemptResults ($c, $pg) {
	return ($c->{can}{showProblemScores} && $pg->{result}{summary})
		? $c->tag('div', role => 'alert', $c->b($pg->{result}{summary}))
		: '';
}

sub get_instructor_comment ($c, $problem) {
	return unless ref($problem) =~ /ProblemVersion/;

	my $db = $c->db;
	my $userPastAnswerID =
		$db->latestProblemPastAnswer($problem->user_id, $problem->set_id . ',v' . $problem->version_id,
			$problem->problem_id);

	if ($userPastAnswerID) {
		my $userPastAnswer = $db->getPastAnswer($userPastAnswerID);
		return $userPastAnswer->comment_string;
	}

	return '';
}

# Template methods

async sub pre_header_initialize ($c) {
	# Make sure these are defined for the templates.
	$c->stash->{problems}        = [];
	$c->stash->{pg_results}      = [];
	$c->stash->{startProb}       = 0;
	$c->stash->{endProb}         = 0;
	$c->stash->{numPages}        = 0;
	$c->stash->{pageNumber}      = 0;
	$c->stash->{problem_numbers} = [];
	$c->stash->{probOrder}       = [];

	# If authz->checkSet has failed, then this set is invalid.  No need to proceeded.
	return if $c->{invalidSet};

	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;

	my $setID           = $c->stash('setID');
	my $userID          = $c->param('user');
	my $effectiveUserID = $c->param('effectiveUser');
	my $isFakeSet       = 0;

	# User checks
	my $user = $db->getUser($userID);
	die "record for user $userID (real user) does not exist." unless defined $user;

	my $effectiveUser = $db->getUser($effectiveUserID);
	die "record for user $effectiveUserID (effective user) does not exist." unless defined $effectiveUser;

	my $permissionLevel = $db->getPermissionLevel($userID);
	die "permission level record for $userID does not exist (but the user does? odd...)"
		unless defined $permissionLevel;

	# The $setID could be the versioned or nonversioned set.  Extract the version if it is provided.
	my $requestedVersion = ($setID =~ /,v(\d+)$/) ? $1 : 0;
	$setID =~ s/,v\d+$//;
	# Note that if a version was provided the version needs to be checked.  That is done after it has
	# been validated that the user is assigned the set.

	# Gateway set and problem collection

	# We need the template (user) set, the merged set version, and a problem from the set to be able to test whether
	# we're creating a new set version.
	my ($tmplSet, $set, $problem) = (0, 0, 0);

	# If the set comes in as "Undefined_Set", then we're trying/editing a single problem in a set, and so create a fake
	# set with which to work if the user has the authorization to do that.
	if ($setID eq 'Undefined_Set') {
		$isFakeSet = 1;
		# Make sure these are defined
		$requestedVersion = 1;
		$c->{assignment_type} = 'gateway';

		if (!$authz->hasPermissions($userID, 'modify_problem_sets')) {
			$c->{invalidSet} = 'You do not have the authorization level required to view/edit undefined sets.';

			# Define these so that we can drop through to report the error in body.
			$tmplSet = fake_set($db);
			$set     = fake_set_version($db);
			$problem = fake_problem($db);
		} else {
			# In this case we're creating a fake set from the input, so the input must include a source file.
			if (!$c->param('sourceFilePath')) {
				$c->{invalidSet} =
					'An Undefined_Set was requested, but no source file for the contained problem was provided.';

				# Define these so that we can drop through to report the error in body.
				$tmplSet = fake_set($db);
				$set     = fake_set_version($db);
				$problem = fake_problem($db);

			} else {
				my $sourceFPath = $c->param('sourceFilePath');
				die('sourceFilePath is unsafe!')
					unless path_is_subdir($sourceFPath, $ce->{courseDirs}{templates}, 1);

				$tmplSet = fake_set($db);
				$set     = fake_set_version($db);
				$problem = fake_problem($db);

				my $creation_time = time;

				$tmplSet->assignment_type('gateway');
				$tmplSet->attempts_per_version(0);
				$tmplSet->time_interval(0);
				$tmplSet->versions_per_interval(1);
				$tmplSet->version_time_limit(0);
				$tmplSet->version_creation_time($creation_time);
				$tmplSet->problem_randorder(0);
				$tmplSet->problems_per_page(1);
				$tmplSet->hide_score('N');
				$tmplSet->hide_score_by_problem('N');
				$tmplSet->hide_work('N');
				$tmplSet->time_limit_cap('0');
				$tmplSet->restrict_ip('No');

				$set->assignment_type('gateway');
				$set->time_interval(0);
				$set->versions_per_interval(1);
				$set->version_time_limit(0);
				$set->version_creation_time($creation_time);
				$set->time_limit_cap('0');

				$problem->problem_id(1);
				$problem->source_file($sourceFPath);
				$problem->user_id($effectiveUserID);
				$problem->value(1);
				$problem->problem_seed($c->param('problemSeed')) if ($c->param('problemSeed'));
			}
		}
	} else {
		# Get the template set, i.e., the non-versioned set that's assigned to the user.
		# If this failed in authz->checkSet, then $c->{invalidSet} is set.
		$tmplSet = $db->getMergedSet($effectiveUserID, $setID);

		# Now that is has been validated that this is a gateway test, save the assignment test for the processing of
		# proctor keys for graded proctored tests.  If a set was not obtained from the database, store a fake value here
		# to be able to continue.
		$c->{assignment_type} = $tmplSet->assignment_type || 'gateway';

		# next, get the latest (current) version of the set if we don't have a
		#     requested version number
		my @allVersionIds = $db->listSetVersions($effectiveUserID, $setID);
		my $latestVersion = (@allVersionIds ? $allVersionIds[-1] : 0);

		# Double check that the requested version makes sense.
		$requestedVersion = $latestVersion
			if ($requestedVersion !~ /^\d+$/
				|| $requestedVersion > $latestVersion
				|| $requestedVersion < 0);

		die('No requested version when returning to problem?!')
			if (
				(
					$c->param('previewAnswers')
					|| $c->param('checkAnswers')
					|| $c->param('submitAnswers')
					|| $c->param('newPage')
				)
				&& !$requestedVersion
			);

		# To check for a proctored test, the set version is needed, not the template.  So get that.
		if ($requestedVersion) {
			$set = $db->getMergedSetVersion($effectiveUserID, $setID, $requestedVersion);
		} elsif ($latestVersion) {
			$set = $db->getMergedSetVersion($effectiveUserID, $setID, $latestVersion);
		} else {
			# If there is not a requested version or a latest version, then create dummy set to proceed.
			# FIXME RETURN TO: should this be global2version?
			$set = global2user($ce->{dbLayout}{set_version}{record}, $db->getGlobalSet($setID));
			$set->user_id($effectiveUserID);
			$set->psvn('000');
			$set->set_id($setID);    # redundant?
			$set->version_id(0);
		}
	}
	my $setVersionNumber = $set ? $set->version_id : 0;

	# Assemble gateway parameters

	# We get the open and close dates for the gateway from the template set, or from the merged set version if a set has
	# been requested.  Note $isOpen and $isClosed give the open and close dates for the gateway as a whole (that is, the
	# merged user|global set).  The set could be an invalid set, so check for an open_date before actually testing the
	# date.  If a specific version has not been requested and conditional release is enabled, then this also checks to
	# see if the conditions have been met for a conditional release.
	my $isOpen = (
		$requestedVersion ? ($set && $set->open_date && after($set->open_date, $c->submitTime)) : ($tmplSet
				&& $tmplSet->open_date
				&& after($tmplSet->open_date, $c->submitTime)
				&& !($ce->{options}{enableConditionalRelease} && is_restricted($db, $tmplSet, $effectiveUserID)))
		)
		|| $authz->hasPermissions($userID, 'view_unopened_sets');

	my $isClosed =
		$tmplSet
		&& $tmplSet->due_date
		&& after($tmplSet->due_date, $c->submitTime)
		&& !$authz->hasPermissions($userID, 'record_answers_after_due_date');

	# To determine if we need a new version, we need to know whether this version exceeds the number of attempts per
	# version.  Among other things, the number of attempts is a property of the problem, so get a problem to check that.
	# Note that for a gateway quiz all problems will have the same number of attempts.  This means that if the set
	# doesn't have any problems we're up a creek, so check for that here and bail if that is the case.
	my @setPNum = $setID eq 'Undefined_Set' ? (1) : $db->listUserProblems($effectiveUser->user_id, $setID);
	die("Set $setID contains no problems.") if (!@setPNum);

	# If we assigned a fake problem above, $problem is already defined.  Otherwise, get the problem, or define it to be
	# undefined if the set hasn't been versioned to the user yet.  This is fixed when we assign the setVersion.
	if (!$problem) {
		$problem =
			$setVersionNumber
			? $db->getMergedProblemVersion($effectiveUser->user_id, $setID, $setVersionNumber, $setPNum[0])
			: undef;
	}

	my $maxAttemptsPerVersion = $tmplSet->attempts_per_version  || 0;
	my $timeInterval          = $tmplSet->time_interval         || 0;
	my $versionsPerInterval   = $tmplSet->versions_per_interval || 0;
	my $timeLimit             = $tmplSet->version_time_limit    || 0;

	# What happens if someone didn't set one of these?  Perhaps this can happen if we're handed a malformed set, where
	# the values in the database are null.
	$timeInterval        = 0 if !defined $timeInterval        || $timeInterval eq '';
	$versionsPerInterval = 0 if !defined $versionsPerInterval || $versionsPerInterval eq '';

	# Every problem in the set is assumed have the same submission characteristics.
	my $currentNumAttempts = defined $problem ? $problem->num_correct + $problem->num_incorrect : 0;

	# $maxAttempts is the maximum number of versions that can be created.
	# If the problem isn't defined it doesn't matter.
	my $maxAttempts = defined $problem && $problem->max_attempts ? $problem->max_attempts : -1;

	# Find the number of versions per time interval.  Interpret the time interval as a rolling interval. That is, if two
	# sets are allowed per day, that is two sets in any 24 hour period.

	my $currentNumVersions = 0;    # this is the number of versions in the time interval
	my $totalNumVersions   = 0;

	if ($setVersionNumber && !$c->{invalidSet} && $setID ne 'Undefined_Set') {
		my @setVersionIDs = $db->listSetVersions($effectiveUserID, $setID);
		my @setVersions   = $db->getSetVersions(map { [ $effectiveUserID, $setID,, $_ ] } @setVersionIDs);
		for (@setVersions) {
			$totalNumVersions++;
			$currentNumVersions++ if (!$timeInterval || $_->version_creation_time() > ($c->submitTime - $timeInterval));
		}
	}

	# New version creation conditional

	my $versionIsOpen = 0;

	if ($isOpen && !$isClosed && !$c->{invalidSet}) {
		# If specific version was not requested, then create a new one if needed.
		if (!$requestedVersion) {
			if (
				($maxAttempts == -1 || $totalNumVersions < $maxAttempts)
				&& (
					$setVersionNumber == 0
					|| (
						(
							($maxAttemptsPerVersion == 0 && $currentNumAttempts > 0)
							|| ($maxAttemptsPerVersion != 0 && $currentNumAttempts >= $maxAttemptsPerVersion)
							|| $c->submitTime >= $set->due_date + $ce->{gatewayGracePeriod}
						)
						&& (!$versionsPerInterval || $currentNumVersions < $versionsPerInterval)
					)
				)
				&& (
					$effectiveUserID eq $userID
					|| (
						$authz->hasPermissions($userID, 'record_answers_when_acting_as_student')
						|| ($authz->hasPermissions($userID, 'create_new_set_version_when_acting_as_student')
							&& $c->param('createnew_ok'))
					)
				)
				)
			{
				# Assign the set, get the right name, version number, etc., and redefine the $set and $problem for the
				# remainder of this method.
				my $setTmpl = $db->getUserSet($effectiveUserID, $setID);
				assignSetVersionToUser($db, $effectiveUserID, $setTmpl);
				$setVersionNumber++;

				# Get a clean version of the set and merged version to use in the rest of the routine.
				my $cleanSet = $db->getSetVersion($effectiveUserID, $setID, $setVersionNumber);
				$set = $db->getMergedSetVersion($effectiveUserID, $setID, $setVersionNumber);
				$set->visible(1);

				$problem = $db->getMergedProblemVersion($effectiveUserID, $setID, $setVersionNumber, $setPNum[0]);

				# Convert the floating point value from Time::HiRes to an integer for use below. Truncate towards 0.
				my $timeNowInt = int($c->submitTime);

				# Set up creation time, and open and due dates.
				my $ansOffset = $set->answer_date - $set->due_date;
				$set->version_creation_time($timeNowInt);
				$set->open_date($timeNowInt);
				# Figure out the due date, taking into account the time limit cap.
				my $dueTime =
					$timeLimit == 0 || ($set->time_limit_cap && $c->submitTime + $timeLimit > $set->due_date)
					? $set->due_date
					: $timeNowInt + $timeLimit;

				$set->due_date($dueTime);
				$set->answer_date($set->due_date + $ansOffset);
				$set->version_last_attempt_time(0);

				# Put this new info into the database.  Put back the data needed for the version, and leave blank any
				# information that should be inherited from the user set or global set.  Set the data which determines
				# if a set is open, because a set version should not reopen after it's complete.
				$cleanSet->version_creation_time($set->version_creation_time);
				$cleanSet->open_date($set->open_date);
				$cleanSet->due_date($set->due_date);
				$cleanSet->answer_date($set->answer_date);
				$cleanSet->version_last_attempt_time($set->version_last_attempt_time);
				$cleanSet->version_time_limit($set->version_time_limit);
				$cleanSet->attempts_per_version($set->attempts_per_version);
				$cleanSet->assignment_type($set->assignment_type);
				$db->putSetVersion($cleanSet);

				# This is a new set version, so it's open.
				$versionIsOpen = 1;

				# Set the number of attempts for this set to zero.
				$currentNumAttempts = 0;

			} elsif ($maxAttempts != -1 && $totalNumVersions > $maxAttempts) {
				$c->{invalidSet} = 'No new versions of this assignment are available, '
					. 'because you have already taken the maximum number allowed.';

			} elsif ($effectiveUserID ne $userID
				&& $authz->hasPermissions($userID, 'create_new_set_version_when_acting_as_student'))
			{

				$c->{invalidSet} =
					"User $effectiveUserID is being acted "
					. 'as.  If you continue, you will create a new version of this set '
					. 'for that user, which will count against their allowed maximum '
					. 'number of versions for the current time interval.  IN GENERAL, THIS '
					. 'IS NOT WHAT YOU WANT TO DO.  Please be sure that you want to '
					. 'do this before clicking the "Create new set version" link '
					. 'below.  Alternately, PRESS THE "BACK" BUTTON and continue.';
				$c->{invalidVersionCreation} = 1;

			} elsif ($effectiveUserID ne $userID) {
				$c->{invalidSet} = "User $effectiveUserID is being acted as.  "
					. 'When acting as another user, new versions of the set cannot be created.';
				$c->{invalidVersionCreation} = 2;

			} elsif (($maxAttemptsPerVersion == 0 || $currentNumAttempts < $maxAttemptsPerVersion)
				&& $c->submitTime < $set->due_date() + $ce->{gatewayGracePeriod})
			{
				if (between($set->open_date(), $set->due_date() + $ce->{gatewayGracePeriod}, $c->submitTime)) {
					$versionIsOpen = 1;
				} else {
					$c->{invalidSet} =
						'No new  versions of this assignment are available, because the set is not open or its time'
						. ' limit has expired.';
				}

			} elsif ($versionsPerInterval
				&& ($currentNumVersions >= $versionsPerInterval))
			{
				$c->{invalidSet} =
					'You have already taken all available versions of this test in the current time interval.  '
					. 'You may take the test again after the time interval has expired.';

			}

		} else {
			# If a specific version is requested, then check to see if it's open.
			if (
				($currentNumAttempts < $maxAttemptsPerVersion)
				&& ($effectiveUserID eq $userID
					|| $authz->hasPermissions($userID, 'record_set_version_answers_when_acting_as_student'))
				)
			{
				if (between($set->open_date(), $set->due_date() + $ce->{gatewayGracePeriod}, $c->submitTime)) {
					$versionIsOpen = 1;
				}
			}
		}

	} elsif (!$c->{invalidSet} && !$requestedVersion) {
		$c->{invalidSet} = 'This set is closed.  No new set versions may be taken.';
	}

	# If the set or problem is invalid, then delete any proctor keys if any and return.
	if ($c->{invalidSet} || $c->{invalidProblem}) {
		if (defined $c->{assignment_type} && $c->{assignment_type} eq 'proctored_gateway') {
			my $proctorID = $c->param('proctor_user');
			if ($proctorID) {
				eval { $db->deleteKey("$effectiveUserID,$proctorID"); };
				eval { $db->deleteKey("$effectiveUserID,$proctorID,g"); };
			}
		}
		return;
	}

	# Save problem and user data

	my $psvn = $set->psvn();
	$c->{tmplSet} = $tmplSet;
	$c->{set}     = $set;
	$c->{problem} = $problem;

	$c->{userID}        = $userID;
	$c->{user}          = $user;
	$c->{effectiveUser} = $effectiveUser;

	$c->{isOpen}        = $isOpen;
	$c->{isClosed}      = $isClosed;
	$c->{versionIsOpen} = $versionIsOpen;

	# Form processing

	# Get the current page, if it's given.
	my $currentPage = $c->param('currentPage') || 1;

	# This is a hack to manage changing pages.  Set previewAnswers to
	# false if the "pageChangeHack" input is set (a page change link was used).
	$c->param('previewAnswers', 0) if $c->param('pageChangeHack');

	$c->{displayMode} = $user->displayMode || $ce->{pg}{options}{displayMode};

	# Set options from request parameters.
	$c->{redisplay}      = $c->param('redisplay');
	$c->{submitAnswers}  = $c->param('submitAnswers') || 0;
	$c->{checkAnswers}   = $c->param('checkAnswers')   // 0;
	$c->{previewAnswers} = $c->param('previewAnswers') // 0;
	$c->{formFields}     = $c->req->params->to_hash;

	# Permissions

	# Bail without doing anything if the set isn't yet open for this user.
	if (!($c->{isOpen} || $authz->hasPermissions($userID, 'view_unopened_sets'))) {
		$c->{invalidSet} = 'This set is not yet open.';
		return;
	}

	# What does the user want to do?
	my %want = (
		showOldAnswers => $user->showOldAnswers ne '' ? $user->showOldAnswers : $ce->{pg}{options}{showOldAnswers},
		# showProblemGrader implies showCorrectAnswers.  This is a convenience for grading.
		showCorrectAnswers => ($c->param('showProblemGrader') || 0)
			|| ($c->param('showCorrectAnswers') && ($c->{submitAnswers} || $c->{checkAnswers}))
			|| 0,
		showProblemGrader => $c->param('showProblemGrader')
			|| 0,
		# Hints are not yet implemented in gateway quzzes.
		showHints     => 0,
		showSolutions => 1,
		recordAnswers => $c->{submitAnswers} && !$authz->hasPermissions($userID, 'avoid_recording_answers'),
		# we also want to check answers if we were checking answers and are switching between pages
		checkAnswers => $c->{checkAnswers},
		useMathView  => $user->useMathView ne ''  ? $user->useMathView  : $ce->{pg}{options}{useMathView},
		useMathQuill => $user->useMathQuill ne '' ? $user->useMathQuill : $ce->{pg}{options}{useMathQuill},
	);

	# Are certain options enforced?
	my %must = (
		showOldAnswers     => 0,
		showCorrectAnswers => 0,
		showProblemGrader  => 0,
		showHints          => 0,
		showSolutions      => 0,
		recordAnswers      => 0,
		checkAnswers       => 0,
		useMathView        => 0,
		useMathQuill       => 0,
	);

	# Does the user have permission to use certain options?
	my @args = ($user, $permissionLevel, $effectiveUser, $set, $problem, $tmplSet);
	my %can  = (
		showOldAnswers        => $c->can_showOldAnswers(@args),
		showCorrectAnswers    => $c->can_showCorrectAnswers(@args),
		showProblemGrader     => $c->can_showProblemGrader(@args),
		showHints             => $c->can_showHints,
		showSolutions         => $c->can_showSolutions(@args),
		recordAnswers         => $c->can_recordAnswers(@args),
		checkAnswers          => $c->can_checkAnswers(@args),
		recordAnswersNextTime => $c->can_recordAnswers(@args, $c->{submitAnswers}),
		checkAnswersNextTime  => $c->can_checkAnswers(@args, $c->{submitAnswers}),
		showScore             => $c->can_showScore(@args),
		showProblemScores     => $c->can_showProblemScores(@args),
		showWork              => $c->can_showWork(@args),
		useMathView           => $c->can_useMathView,
		useMathQuill          => $c->can_useMathQuill
	);

	# Final values for options
	my %will = map { $_ => $can{$_} && ($must{$_} || $want{$_}) } keys %must;

	$c->{want} = \%want;
	$c->{must} = \%must;
	$c->{can}  = \%can;
	$c->{will} = \%will;

	# Set up problem numbering and multipage variables.

	my @problemNumbers;
	if ($setID eq 'Undefined_Set') {
		@problemNumbers = (1);
	} else {
		@problemNumbers = $db->listProblemVersions($effectiveUserID, $setID, $setVersionNumber);
	}

	# To speed up processing of long (multi-page) tests, we want to only translate those problems that are being
	# submitted or are currently being displayed.  So determine which problems are on the current page.
	my ($numPages, $pageNumber, $numProbPerPage) = (1, 0, 0);
	my ($startProb, $endProb) = (0, $#problemNumbers);

	# Update startProb and endProb for multipage tests
	if ($set->problems_per_page) {
		$numProbPerPage = $set->problems_per_page;
		$pageNumber     = $c->param('newPage') || $currentPage;

		$numPages = scalar(@problemNumbers) / $numProbPerPage;
		$numPages = int($numPages) + 1 if (int($numPages) != $numPages);

		$startProb = ($pageNumber - 1) * $numProbPerPage;
		$startProb = 0 if ($startProb < 0 || $startProb > $#problemNumbers);
		$endProb =
			($startProb + $numProbPerPage > $#problemNumbers) ? $#problemNumbers : $startProb + $numProbPerPage - 1;
	}

	# Set up problem list for randomly ordered tests.
	my @probOrder = (0 .. $#problemNumbers);

	if ($set->problem_randorder) {
		my @newOrder;
		# Make sure to keep the random order the same each time the set is loaded!  This is done by ensuring that the
		# random seed used is the same each time the same set is called by setting the seed to the psvn of the problem
		# set.  Use a local PGrandom object to avoid mucking with the system seed.
		my $pgrand = PGrandom->new;
		$pgrand->srand($set->psvn);
		while (@probOrder) {
			my $i = int($pgrand->rand(scalar(@probOrder)));
			push(@newOrder, splice(@probOrder, $i, 1));
		}
		@probOrder = @newOrder;
	}
	# Now $probOrder[i] is the problem number, numbered from zero, that is displayed in the ith position on the test.

	# Make a list of those problems displayed on this page.
	my @probsToDisplay = ();
	for (my $i = 0; $i < @probOrder; $i++) {
		push(@probsToDisplay, $probOrder[$i])
			if ($i >= $startProb && $i <= $endProb);
	}

	# Process problems

	my @problems;
	my @pg_results;

	# pg errors are stored here.
	$c->{errors} = [];

	# Process the problems as needed.
	my @mergedProblems;
	if ($setID eq 'Undefined_Set') {
		@mergedProblems = ($problem);
	} else {
		@mergedProblems = $db->getAllMergedProblemVersions($effectiveUserID, $setID, $setVersionNumber);
	}

	my @renderPromises;

	for my $pIndex (0 .. $#problemNumbers) {
		my $problemN = $mergedProblems[$pIndex];

		if (!defined $problemN) {
			$c->{invalidSet} = 'One or more of the problems in this set have not been assigned to you.';
			return;
		}

		# sticky answers are set up here
		if (!($c->{submitAnswers} || $c->{previewAnswers} || $c->{checkAnswers} || $c->param('newPage'))
			&& $will{showOldAnswers})
		{
			my %oldAnswers = decodeAnswers($problemN->last_answer);
			$c->{formFields}{$_} = $oldAnswers{$_} for (keys %oldAnswers);
		}

		push(@problems, $problemN);

		# If this problem DOES NOT need to be translated, store a defined but false placeholder in the array.
		my $pg = 0;
		# This is the actual translation of each problem.
		if ((grep {/^$pIndex$/} @probsToDisplay) || $c->{submitAnswers}) {
			push @renderPromises, $c->getProblemHTML($c->{effectiveUser}, $set, $c->{formFields}, $problemN);
			# If this problem DOES need to be translated, store an undefined placeholder in the array.
			# This will be replaced with the rendered problem after all of the above promises are awaited.
			$pg = undef;
		}
		push(@pg_results, $pg);
	}

	# Show the template problem ID if the problems are in random order
	# or the template problem IDs are not in order starting at 1.
	$c->{can}{showTemplateIds} = $c->{can}{showProblemGrader}
		&& ($set->problem_randorder || $problems[-1]->problem_id != scalar(@problems));

	# Wait for all problems to be rendered and replace the undefined entries
	# in the pg_results array with the rendered result.
	my @renderedPG = await Mojo::Promise->all(@renderPromises);
	for (@pg_results) {
		$_ = (shift @renderedPG)->[0] if !defined $_;
	}

	$c->stash->{problems}        = \@problems;
	$c->stash->{pg_results}      = \@pg_results;
	$c->stash->{startProb}       = $startProb;
	$c->stash->{endProb}         = $endProb;
	$c->stash->{numPages}        = $numPages;
	$c->stash->{pageNumber}      = $pageNumber;
	$c->stash->{problem_numbers} = \@problemNumbers;
	$c->stash->{probOrder}       = \@probOrder;

	my $versionID = $set->version_id;
	my $setVName  = "$setID,v$versionID";

	# Report everything with the request submit time. Convert the floating point
	# value from Time::HiRes to an integer for use below. Truncate towards 0.
	my $timeNowInt = int($c->submitTime);

	# Answer processing

	debug('begin answer processing');

	my @scoreRecordedMessage = ('') x scalar(@problems);
	my $LTIGradeResult       = -1;

	# Save results to database as appropriate
	if ($c->{submitAnswers} || (($c->{previewAnswers} || $c->param('newPage')) && $can{recordAnswers})) {
		# If answers are being submitted, then save the problems to the database.  If this is a preview or page change
		# and answers can be recorded, then save the last answer for future reference.
		# Also save the persistent data to the database even when the last answer is not saved.

		# First, deal with answers being submitted for a proctored exam.  Delete the proctor keys that authorized the
		# grading, so that it isn't possible to log in and take another proctored test without being reauthorized.
		if ($c->{submitAnswers} && $c->{assignment_type} eq 'proctored_gateway') {
			my $proctorID = $c->param('proctor_user');

			# If there are no attempts left, delete all proctor keys for this user.
			if ($set->attempts_per_version > 0
				&& $set->attempts_per_version - 1 - $problem->num_correct - $problem->num_incorrect <= 0)
			{
				eval { $db->deleteAllProctorKeys($effectiveUserID); };
			} else {
				# Otherwise, delete only the grading key.
				eval { $db->deleteKey("$effectiveUserID,$proctorID,g"); };
				# In this case there may be a past login proctor key that can be kept so that another login to continue
				# working the test is not needed.
				if ($c->param('past_proctor_user') && $c->param('past_proctor_key')) {
					$c->param('proctor_user', scalar $c->param('past_proctor_user'));
					$c->param('proctor_key',  scalar $c->param('past_proctor_key'));
				}
			}
			# This is unsubtle, but we'd rather not have bogus keys sitting around.
			if ($@) {
				die "ERROR RESETTING PROCTOR GRADING KEY(S): $@\n";
			}

		}

		my @pureProblems = $db->getAllProblemVersions($effectiveUserID, $setID, $versionID);
		for my $i (0 .. $#problems) {
			# Process each problem.
			my $pureProblem = $pureProblems[ $probOrder[$i] ];
			my $problem     = $problems[ $probOrder[$i] ];
			my $pg_result   = $pg_results[ $probOrder[$i] ];

			my %answerHash;
			my @answer_order;
			my ($encoded_last_answer_string, $answer_types_string);

			if (ref $pg_result) {
				my ($past_answers_string, $scores);    # Not used here
				($past_answers_string, $encoded_last_answer_string, $scores, $answer_types_string) =
					create_ans_str_from_responses($c, $pg_result);

				# Transfer persistent problem data from the PERSISTENCE_HASH:
				# - Get keys to update first, to avoid extra work when no updated ar
				#   are needed. When none, we avoid the need to decode/encode JSON,
				#   to save the pureProblem when it would not otherwise be saved.
				# - We are assuming that there is no need to DELETE old
				#   persistent data if the hash is empty, even if in
				#   potential there may be some data already in the database.
				my @persistent_data_keys = keys %{ $pg_result->{PERSISTENCE_HASH_UPDATED} };
				if (@persistent_data_keys) {
					my $json_data = decode_json($pureProblem->{problem_data} || '{}');
					for my $key (@persistent_data_keys) {
						$json_data->{$key} = $pg_result->{PERSISTENCE_HASH}{$key};
					}
					$pureProblem->problem_data(encode_json($json_data));

					# If the pureProblem will not be saved below, we should save the
					# persistent data here before any other changes are made to it.
					if (($c->{submitAnswers} && !$will{recordAnswers})) {
						$c->db->putProblemVersion($pureProblem);
					}
				}
			} else {
				my $prefix         = sprintf('Q%04d_', $problemNumbers[$i]);
				my @fields         = sort grep {/^(?!previous).*$prefix/} (keys %{ $c->{formFields} });
				my %answersToStore = map       { $_ => $c->{formFields}->{$_} } @fields;
				my @answer_order   = @fields;
				$encoded_last_answer_string = encodeAnswers(%answersToStore, @answer_order);
			}

			# Set the last answer
			$problem->last_answer($encoded_last_answer_string);
			$pureProblem->last_answer($encoded_last_answer_string);

			# Store the state in the database if answers are being recorded.
			if ($c->{submitAnswers} && $will{recordAnswers}) {
				my $score =
					compute_reduced_score($ce, $problem, $set, $pg_result->{state}{recorded_score}, $c->submitTime);
				$problem->status($score) if $score > $problem->status;

				$problem->sub_status($problem->status)
					if (!$ce->{pg}{ansEvalDefaults}{enableReducedScoring}
						|| !$set->enable_reduced_scoring
						|| before($set->reduced_scoring_date, $c->submitTime));

				$problem->attempted(1);
				$problem->num_correct($pg_result->{state}{num_of_correct_ans});
				$problem->num_incorrect($pg_result->{state}{num_of_incorrect_ans});

				$pureProblem->status($problem->status);
				$pureProblem->sub_status($problem->sub_status);
				$pureProblem->attempted(1);
				$pureProblem->num_correct($pg_result->{state}{num_of_correct_ans});
				$pureProblem->num_incorrect($pg_result->{state}{num_of_incorrect_ans});

				if ($answer_types_string) {
					# Add flags which are really a comma separated list of answer types.  If its an essay question and
					# the user is submitting an answer then there could be potential changes. So the problem is also
					# flagged as needing grading by appending ":needs_grading" to the answer types.
					$pureProblem->flags(
						$answer_types_string . ($answer_types_string =~ /essay/ ? ':needs_grading' : ''));
				}

				if ($db->putProblemVersion($pureProblem)) {
					# Use a simple untranslated value here.  This message will never be shown, and will later be
					# used in a string comparison.  Don't compare translated strings!
					$scoreRecordedMessage[ $probOrder[$i] ] = 'recorded';
				} else {
					$scoreRecordedMessage[ $probOrder[$i] ] = $c->maketext('Your score was not recorded because '
							. 'there was a failure in storing the problem record to the database.');
				}

				# Write the transaction log
				writeLog($c->ce, 'transaction',
					$problem->problem_id . "\t"
						. $problem->set_id . "\t"
						. $problem->user_id . "\t"
						. $problem->source_file . "\t"
						. $problem->value . "\t"
						. $problem->max_attempts . "\t"
						. $problem->problem_seed . "\t"
						. $problem->status . "\t"
						. $problem->attempted . "\t"
						. $problem->last_answer . "\t"
						. $problem->num_correct . "\t"
						. $problem->num_incorrect);
			} elsif ($c->{submitAnswers}) {
				# This is the case answers were submitted but can not be saved. Report an error message.
				if ($c->{isClosed}) {
					$scoreRecordedMessage[ $probOrder[$i] ] =
						$c->maketext('Your score was not recorded because this problem set version is not open.');
				} elsif ($problem->num_correct + $problem->num_incorrect >= $set->attempts_per_version) {
					$scoreRecordedMessage[ $probOrder[$i] ] = $c->maketext(
						'Your score was not recorded because you have no attempts remaining on this set version.');
				} elsif (!$c->{versionIsOpen}) {
					my $endTime = ($set->version_last_attempt_time) ? $set->version_last_attempt_time : $c->submitTime;
					if ($endTime > $set->due_date && $endTime < $set->due_date + $ce->{gatewayGracePeriod}) {
						$endTime = $set->due_date;
					}
					my $elapsed = int(($endTime - $set->open_date) / 0.6 + 0.5) / 100;
					$scoreRecordedMessage[ $probOrder[$i] ] = $c->maketext(
						'Your score was not recorded because you have exceeded the time limit for this test. '
							. '(Time taken: [_1] min; allowed: [_2] min.)',
						$elapsed,
						# Assume the allowed time is an even number of minutes.
						($set->due_date - $set->open_date) / 60
					);
				} else {
					$scoreRecordedMessage[ $probOrder[$i] ] = $c->maketext('Your score was not recorded.');
				}
			} else {
				# The final case is that of a preview or page change.  Save the last answers for the problems.
				$db->putProblemVersion($pureProblem);
			}
		}

		# Try to update the student score on the LMS if that option is enabled.
		if ($c->{submitAnswers} && $will{recordAnswers} && $ce->{LTIGradeMode} && $ce->{LTIGradeOnSubmit}) {
			my $grader = $ce->{LTI}{ $ce->{LTIVersion} }{grader}->new($c);
			if ($ce->{LTIGradeMode} eq 'course') {
				$LTIGradeResult = await $grader->submit_course_grade($effectiveUserID);
			} elsif ($ce->{LTIGradeMode} eq 'homework') {
				$LTIGradeResult = await $grader->submit_set_grade($effectiveUserID, $setID);
			}
		}

		# Finally, log student answers answers are being submitted, provided that answers can be recorded.  Note that
		# this will log an overtime submission (or any case where someone submits the test, or spoofs a request to
		# submit a test).
		my $answer_log = $ce->{courseFiles}{logs}{answer_log};

		if (defined $answer_log && $c->{submitAnswers}) {
			for my $i (0 .. $#problems) {
				next unless ref($pg_results[ $probOrder[$i] ]);

				my $problem = $problems[ $probOrder[$i] ];

				my ($past_answers_string, $encoded_last_answer_string, $scores, $answer_types_string) =
					create_ans_str_from_responses($c, $pg_results[ $probOrder[$i] ]);
				$past_answers_string =~ s/\t+$/\t/;

				if (!$past_answers_string || $past_answers_string =~ /^\t$/) {
					$past_answers_string = "No answer entered\t";
				}

				# Write to courseLog, use the recorded time of when the submission was received, but as an integer
				writeCourseLogGivenTime(
					$c->ce,
					'answer_log',
					$timeNowInt,
					join('',
						'|', $problem->user_id, '|', $setVName, '|', ($i + 1), '|', $scores,
						"\t$timeNowInt\t", "$past_answers_string")
				);

				# Add to PastAnswer db
				my $pastAnswer = $db->newPastAnswer();
				$pastAnswer->user_id($problem->user_id);
				$pastAnswer->set_id($setVName);
				$pastAnswer->problem_id($problem->problem_id);
				$pastAnswer->timestamp($timeNowInt);
				$pastAnswer->scores($scores);
				$pastAnswer->answer_string($past_answers_string);
				$pastAnswer->source_file($problem->source_file);
				$pastAnswer->problem_seed($problem->problem_seed);
				$db->addPastAnswer($pastAnswer);
			}
		}

		my $caliper_sensor = Caliper::Sensor->new($c->ce);
		if ($caliper_sensor->caliperEnabled() && defined $answer_log) {
			my $events = [];

			my $startTime = $c->param('startTime');
			my $endTime   = int($c->submitTime);
			if ($c->{submitAnswers} && $will{recordAnswers}) {
				for my $i (0 .. $#problems) {
					my $problem                  = $problems[ $probOrder[$i] ];
					my $pg                       = $pg_results[ $probOrder[$i] ];
					my $completed_question_event = {
						'type'    => 'AssessmentItemEvent',
						'action'  => 'Completed',
						'profile' => 'AssessmentProfile',
						'object'  => Caliper::Entity::problem_user(
							$c->ce, $db, $problem->set_id(), $versionID, $problem->problem_id(),
							$problem->user_id(), $pg
						),
						'generated' => Caliper::Entity::answer(
							$c->ce,
							$db,
							$problem->set_id(),
							$versionID,
							$problem->problem_id(),
							$problem->user_id(),
							$pg,
							0,    # don't track start/end time for gateway problems (multiple answers per page)
							0     # don't track start/end time for gateway problems (multiple answers per page)
						),
					};
					push @$events, $completed_question_event;
				}
				my $submitted_set_event = {
					'type'      => 'AssessmentEvent',
					'action'    => 'Submitted',
					'profile'   => 'AssessmentProfile',
					'object'    => Caliper::Entity::problem_set($c->ce, $db, $setID),
					'generated' => Caliper::Entity::problem_set_attempt(
						$c->ce, $db, $setID, $versionID, $effectiveUserID, $startTime, $endTime
					),
				};
				push @$events, $submitted_set_event;
			} else {
				my $paused_set_event = {
					'type'      => 'AssessmentEvent',
					'action'    => 'Paused',
					'profile'   => 'AssessmentProfile',
					'object'    => Caliper::Entity::problem_set($c->ce, $db, $setID),
					'generated' => Caliper::Entity::problem_set_attempt(
						$c->ce, $db, $setID, $versionID, $effectiveUserID, $startTime, $endTime
					),
				};
				push @$events, $paused_set_event;
			}
			my $tool_use_event = {
				'type'    => 'ToolUseEvent',
				'action'  => 'Used',
				'profile' => 'ToolUseProfile',
				'object'  => Caliper::Entity::webwork_app(),
			};
			push @$events, $tool_use_event;
			$caliper_sensor->sendEvents($c, $events);

			# Reset start time
			$c->param('startTime', '');
		}
	} else {
		# This 'else' case includes initial load of the first page of the
		# quiz and checkAnswers calls, as well as when $can{recordAnswers}
		# is false.

		# Save persistent data to database even in this case, when answers
		# would not or can not be recorded.
		my @pureProblems = $db->getAllProblemVersions($effectiveUserID, $setID, $versionID);
		for my $i (0 .. $#problems) {
			# Process each problem.
			my $pureProblem = $pureProblems[ $probOrder[$i] ];
			my $pg_result   = $pg_results[ $probOrder[$i] ];

			if (ref $pg_result) {
				# Transfer persistent problem data from the PERSISTENCE_HASH:
				# - Get keys to update first, to avoid extra work when no updates
				#   are needed. When none, we avoid the need to decode/encode JSON,
				#   or to save the pureProblem.
				# - We are assuming that there is no need to DELETE old
				#   persistent data if the hash is empty, even if in
				#   potential there may be some data already in the database.
				my @persistent_data_keys = keys %{ $pg_result->{PERSISTENCE_HASH_UPDATED} };
				next unless (@persistent_data_keys);    # stop now if nothing to do
				if ($isFakeSet) {
					warn join("",
						"This problem stores persistent data and this cannot be done in a fake set. ",
						"Some functionality may not work properly when testing this problem in this setting.");
					next;
				}

				my $json_data = decode_json($pureProblem->{problem_data} || '{}');
				for my $key (@persistent_data_keys) {
					$json_data->{$key} = $pg_result->{PERSISTENCE_HASH}{$key};
				}
				$pureProblem->problem_data(encode_json($json_data));

				$c->db->putProblemVersion($pureProblem);
			}
		}
	}
	debug('end answer processing');

	$c->{scoreRecordedMessage} = \@scoreRecordedMessage;
	$c->{LTIGradeResult}       = $LTIGradeResult;

	# Additional set-level database manipulation: We want to save the time that a set was submitted, and for proctored
	# tests we want to reset the assignment type after a set is submitted for the last time so that it's possible to
	# look at it later without getting proctor authorization.
	if (
		(
			$c->{submitAnswers}
			&& (
				$will{recordAnswers}
				|| (!$set->version_last_attempt_time && $c->submitTime > $set->due_date + $ce->{gatewayGracePeriod})
			)
		)
		|| (
			$set->assignment_type eq 'proctored_gateway'
			&& (
				($userID eq $effectiveUserID && !$can{recordAnswersNextTime})
				|| (
					$userID ne $effectiveUserID
					&& $authz->hasPermissions($userID, 'record_answers_when_acting_as_student')
					&& $set->attempts_per_version > 0
					&& ($problem->num_correct + $problem->num_incorrect + ($c->{submitAnswers} ? 1 : 0) >=
						$set->attempts_per_version)
				)
			)
		)
		)
	{
		# Save the submission time if we're recording the answer, or if the first submission occurs after the due_date.
		$set->version_last_attempt_time($timeNowInt)
			if (
				$c->{submitAnswers}
				&& (
					$will{recordAnswers}
					|| (!$set->version_last_attempt_time && $c->submitTime > $set->due_date + $ce->{gatewayGracePeriod})
				)
			);

		$set->assignment_type('gateway')
			if (
				$set->assignment_type eq 'proctored_gateway'
				&& (
					($userID eq $effectiveUserID && !$can{recordAnswersNextTime})
					|| (
						$userID ne $effectiveUserID
						&& $authz->hasPermissions($userID, 'record_answers_when_acting_as_student')
						&& $set->attempts_per_version > 0
						&& ($problem->num_correct + $problem->num_incorrect + ($c->{submitAnswers} ? 1 : 0) >=
							$set->attempts_per_version)
					)
				)
			);

		# Save only parameters that determine access to the set version.
		my $cleanSet = $db->getSetVersion($effectiveUserID, $set->set_id, $versionID);
		$cleanSet->assignment_type($set->assignment_type);
		$cleanSet->version_last_attempt_time($set->version_last_attempt_time);
		$db->putSetVersion($cleanSet);
	}

	# For answer checking on multi-page tests, track changes made on other pages, and scores for problems on those
	# pages.  @probStatus is used for this.  Initialize this to the saved score either from a hidden input or the
	# database, and then update this when calculating the score for checked or submitted tests.
	my @probStatus;

	# Figure out the recorded score for the set, and the score on this attempt.
	$c->{recordedScore} = 0;
	$c->{totalPossible} = 0;
	for (@problems) {
		my $pv = $_->value // 1;
		$c->{totalPossible} += $pv;
		$c->{recordedScore} += $_->status * $pv if defined $_->status;
		push(@probStatus, ($c->param('probstatus' . $_->problem_id) || $_->status || 0));
	}

	# To get the attempt score, determine the score for each problem, and multiply the total for the problem by the
	# weight (value) of the problem.  Avoid translating all of the problems when checking answers.
	# Note that it is okay to ignore problem order here as all arrays used are index the same.
	$c->{attemptScore} = 0;
	if ($will{recordAnswers} || $will{checkAnswers}) {
		my $i = 0;
		for my $pg (@pg_results) {
			my $pValue = $problems[$i]->value // 1;
			my $pScore = 0;
			if (ref $pg) {
				# If a pg object is available, then use the pg recorded score and save it in the @probStatus array.
				$pScore = compute_reduced_score($ce, $problems[$i], $set, $pg->{state}{recorded_score}, $c->submitTime);
				$probStatus[$i] = $pScore if $pScore > $probStatus[$i];
			} else {
				# If a pg object is not available, then use the saved problem status.
				$pScore = $probStatus[$i];
			}
			$c->{attemptScore} += $pScore * $pValue;
			$i++;
		}

		$c->{attemptScore} = wwRound(2, $c->{attemptScore});
	}
	$c->{probStatus} = \@probStatus;

	# To compute the elapsed time, take into account the last submission time or the current time if the test hasn't
	# been submitted. Also, if the submission is during the grace period, then round it to the due date.
	$c->{exceededAllowedTime} = 0;
	my $endTime = $set->version_last_attempt_time ? $set->version_last_attempt_time : $timeNowInt;
	if ($endTime > $set->due_date && $endTime < $set->due_date + $ce->{gatewayGracePeriod}) {
		$endTime = $set->due_date;
	} elsif ($endTime > $set->due_date) {
		$c->{exceededAllowedTime} = 1;
	}
	$c->{elapsedTime} = int(($endTime - $set->open_date) / 0.6 + 0.5) / 100;

	# Get the number of attempts and number of remaining attempts.
	$c->{attemptNumber} =
		$problem->num_correct + $problem->num_incorrect + ($c->{submitAnswers} && $will{recordAnswers} ? 1 : 0);
	$c->{numAttemptsLeft} = ($set->attempts_per_version || 0) - $c->{attemptNumber};

	return;
}

sub head ($c) {
	return '' unless ref $c->stash->{pg_results} eq 'ARRAY';
	my $head_text = '';
	for (@{ $c->stash->{pg_results} }) {
		next unless ref $_;
		$head_text .= $_->{head_text} if $_->{head_text};
	}
	return $head_text;
}

sub path ($c, $args) {
	my $ce         = $c->ce;
	my $setID      = $c->stash('setID');
	my $courseName = $ce->{courseName};

	my $navigation_allowed = $c->authz->hasPermissions($c->param('user'), 'navigation_allowed');

	return $c->pathMacro(
		$args,
		'WeBWorK'   => $navigation_allowed ? $c->url_for('root')     : '',
		$courseName => $navigation_allowed ? $c->url_for('set_list') : '',
		$setID eq 'Undefined_Set' || $c->{invalidSet}
		? ($setID => '')
		: (
			$c->{set}->set_id           => $c->url_for('problem_list', setID => $c->{set}->set_id),
			'v' . $c->{set}->version_id => ''
		),
	);
}

sub nav ($c, $args) {
	my $db              = $c->db;
	my $userID          = $c->param('user');
	my $effectiveUserID = $c->param('effectiveUser');

	return '' if $c->{invalidSet};

	# Set up and display a student navigation for those that have permission to act as a student.
	if ($c->authz->hasPermissions($userID, 'become_student') && $effectiveUserID ne $userID) {
		my $setID = $c->{set}->set_id;

		return '' if $setID eq 'Undefined_Set';

		my $setVersion = $c->{set}->version_id;

		# Find all versions of this set that have been taken (excluding those taken by the current user).
		my @users =
			$db->listSetVersionsWhere({ user_id => { not_like => $userID }, set_id => { like => "$setID,v\%" } });
		my @allUserRecords = $db->getUsers(map { $_->[0] } @users);

		my $filter = $c->param('studentNavFilter');

		# Format the student names for display, and associate the users with the test versions.
		my %filters;
		my @userRecords;
		for (0 .. $#allUserRecords) {
			# Add to the sections and recitations if defined.  Also store the first user found in that section or
			# recitation.  This user will be switched to when the filter is selected.
			my $section = $allUserRecords[$_]->section;
			$filters{"section:$section"} =
				[ $c->maketext('Filter by section [_1]', $section), $allUserRecords[$_]->user_id, $users[$_][2] ]
				if $section && !$filters{"section:$section"};
			my $recitation = $allUserRecords[$_]->recitation;
			$filters{"recitation:$recitation"} =
				[ $c->maketext('Filter by recitation [_1]', $recitation), $allUserRecords[$_]->user_id, $users[$_][2] ]
				if $recitation && !$filters{"recitation:$recitation"};

			# Only keep this user if it satisfies the selected filter if a filter was selected.
			next
				unless !$filter
				|| ($filter =~ /^section:(.*)$/    && $allUserRecords[$_]->section eq $1)
				|| ($filter =~ /^recitation:(.*)$/ && $allUserRecords[$_]->recitation eq $1);

			my $addRecord = $allUserRecords[$_];
			push @userRecords, $addRecord;

			$addRecord->{displayName} =
				($addRecord->last_name || $addRecord->first_name
					? $addRecord->last_name . ', ' . $addRecord->first_name
					: $addRecord->user_id);
			$addRecord->{setVersion} = $users[$_][2];
		}

		# Sort by last name, then first name, then user_id, then set version.
		@userRecords = sort {
			lc($a->last_name) cmp lc($b->last_name)
				|| lc($a->first_name) cmp lc($b->first_name)
				|| lc($a->user_id) cmp lc($b->user_id)
				|| lc($a->{setVersion}) <=> lc($b->{setVersion})
		} @userRecords;

		# Find the previous, current, and next test.
		my $currentTestIndex = 0;
		for (0 .. $#userRecords) {
			if ($userRecords[$_]->user_id eq $effectiveUserID && $userRecords[$_]->{setVersion} == $setVersion) {
				$currentTestIndex = $_;
				last;
			}
		}
		my $prevTest = $currentTestIndex > 0             ? $userRecords[ $currentTestIndex - 1 ] : 0;
		my $nextTest = $currentTestIndex < $#userRecords ? $userRecords[ $currentTestIndex + 1 ] : 0;

		# Mark the current test.
		$userRecords[$currentTestIndex]{currentTest} = 1;

		# Show the student nav.
		return $c->include(
			'ContentGenerator/GatewayQuiz/nav',
			userRecords      => \@userRecords,
			setVersion       => $setVersion,
			prevTest         => $prevTest,
			nextTest         => $nextTest,
			currentTestIndex => $currentTestIndex,
			filters          => \%filters,
			filter           => $filter
		);
	}
}

sub warningMessage ($c) {
	return $c->maketext('<strong>Warning</strong>: There may be something wrong with a question in this test. '
			. 'Please inform your instructor including the warning messages below.');
}

# Evaluation utility
# $effectiveUser is the current effective user, $set is the merged set version, $formFields is a reference to the
# hash of parameters from the input form that need to be passed to the translator, and $mergedProblem
# is what we'd expect.
async sub getProblemHTML ($c, $effectiveUser, $set, $formFields, $mergedProblem) {
	my $pg = await renderPG(
		$c,
		$effectiveUser,
		$set,
		$mergedProblem,
		$set->psvn,
		$formFields,
		{
			displayMode             => $c->{displayMode},
			showHints               => $c->{will}{showHints},
			showSolutions           => $c->{will}{showSolutions},
			refreshMath2img         => $c->{will}{showHints} || $c->{will}{showSolutions},
			processAnswers          => 1,
			QUIZ_PREFIX             => 'Q' . sprintf('%04d', $mergedProblem->problem_id) . '_',
			useMathQuill            => $c->{will}{useMathQuill},
			useMathView             => $c->{will}{useMathView},
			forceScaffoldsOpen      => 1,
			isInstructor            => $c->authz->hasPermissions($c->{userID}, 'view_answers'),
			showFeedback            => $c->{submitAnswers} || $c->{previewAnswers} || $c->{will}{checkAnswers},
			showAttemptAnswers      => $c->ce->{pg}{options}{showEvaluatedAnswers},
			showAttemptPreviews     => 1,
			showAttemptResults      => !$c->{previewAnswers} && $c->{can}{showProblemScores},
			forceShowAttemptResults => $c->{will}{showProblemGrader},
			showMessages            => 1,
			showCorrectAnswers => ($c->{submitAnswers} || $c->{will}{checkAnswers} || $c->{will}{showProblemGrader})
			? $c->{will}{showCorrectAnswers}
			: 0,
			debuggingOptions => getTranslatorDebuggingOptions($c->authz, $c->{userID})
		},
	);

	# Warnings in the renderPG subprocess will not be caught by the global warning handler of this process.
	# So rewarn them and let the global warning handler take care of it.
	warn $pg->{warnings} if $pg->{warnings};

	if ($pg->{flags}{error_flag}) {
		push @{ $c->{errors} },
			{
				set     => $set->set_id . ',v' . $set->version_id,
				problem => $mergedProblem->problem_id,
				message => $pg->{errors},
				context => $pg->{body_text},
			};
		$pg->{body_text} = undef;
	}

	return $pg;
}

1;
