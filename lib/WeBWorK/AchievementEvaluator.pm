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

package WeBWorK::AchievementEvaluator;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

  WeBWorK::AchievementEvaluator  -  Runs achievement evaluators for problems.

=cut

use DateTime;

use WeBWorK::Utils qw(sortAchievements nfreeze_base64 thaw_base64);
use WeBWorK::Utils::ProblemProcessing qw(compute_unreduced_score);
use WeBWorK::Utils::Tags;
use WeBWorK::WWSafe;

our @EXPORT_OK = qw(checkForAchievements);

sub checkForAchievements ($problem_in, $pg, $c, %options) {
	my $db = $c->db;
	my $ce = $c->ce;

	# Make a copy of the problem so that local modifications do not persist.
	our $problem = $db->newUserProblem($problem_in);

	# Date and time for course timezone (may differ from the server timezone)
	# Saved into separate array
	# https://metacpan.org/pod/DateTime
	my $dtCourseTime = DateTime->from_epoch(epoch => time(), time_zone => $ce->{siteDefaults}{timezone} || 'local');

	# Set up variables and get achievements
	my $cheevoMessage = $c->c;
	my $user_id       = $problem->user_id;
	my $set_id        = $problem->set_id;

	# exit early if the set is to be ignored by achievements
	foreach my $excludedSet (@{ $ce->{achievementExcludeSet} }) {
		return '' if $set_id eq $excludedSet;
	}

	our $set = $db->getMergedSet($user_id, $set_id);
	my @achievements          = sortAchievements($db->getAchievementsWhere());
	my $globalUserAchievement = $db->getGlobalUserAchievement($user_id);

	my $isGatewaySet = ($set->assignment_type =~ /gateway/) ? 1 : 0;
	my $isJitarSet   = ($set->assignment_type eq 'jitar')   ? 1 : 0;

	# If its a gateway set get the current version
	if ($isGatewaySet) {
		$set = $db->getSetVersion($user_id, $set_id, $options{setVersion});
	}

	# If no global data then initialize
	if (not $globalUserAchievement) {
		$globalUserAchievement = $db->newGlobalUserAchievement();
		$globalUserAchievement->user_id($user_id);
		$globalUserAchievement->achievement_points(0);
		$db->addGlobalUserAchievement($globalUserAchievement);
	}

	#These need to be "our" so that they can share to the safe container
	our $counter;
	our $maxCounter;
	our $achievementPoints = $globalUserAchievement->achievement_points;
	our $nextLevelPoints   = $globalUserAchievement->next_level_points;
	our $localData         = {};
	our $globalData        = {};
	our $userAchievements  = {};
	our $tags;
	our @setProblems;
	our @courseDateTime = (
		$dtCourseTime->sec,   $dtCourseTime->min,  $dtCourseTime->hour, $dtCourseTime->day,
		$dtCourseTime->month, $dtCourseTime->year, $dtCourseTime->day_of_week
	);

	my $compartment = WeBWorK::WWSafe->new;

	#initialize things that are ""
	if (not $achievementPoints) {
		$achievementPoints = 0;
		$globalUserAchievement->achievement_points(0);
	}

	#Methods alowed in the safe container
	$compartment->permit(qw(time localtime));

	#Thaw_Base64 globalData hash
	if ($globalUserAchievement->frozen_hash) {
		$globalData = thaw_base64($globalUserAchievement->frozen_hash);
	}

	#Generate hash of user achievements:
	foreach my $achievement (@achievements) {
		next unless $achievement->enabled;
		my $userAchievement = $db->getUserAchievement($user_id, $achievement->achievement_id);
		$userAchievements->{ $achievement->achievement_id } = $userAchievement->earned if $userAchievement;
	}

	@setProblems =
		$isGatewaySet
		? $db->getAllMergedProblemVersions($user_id, $set_id, $options{setVersion})
		: $db->getAllUserProblems($user_id, $set_id);

	# Compute the unreduced score for all problems and transfer that to the status.
	# The reduced score is saved in case an achievement needs that.
	# Also check and see of all problems are correct.
	my $allcorrect = 1;
	for (@setProblems) {
		$_->{reduced_score} = $_->status if defined $_->sub_status && $_->sub_status < $_->status;
		$_->status(compute_unreduced_score($ce, $_, $set));
		$allcorrect = 0 if $_->status < 1;

		# Update the data for this problem when it is found.
		if ($_->problem_id == $problem->problem_id) {
			$problem->{reduced_score} = $_->{reduced_score};
			$problem->status($_->status);
		}
	}

	# Check all problems for gateway sets since all are submitted at once.
	# Otherwise only check the current problem.
	for ($isGatewaySet ? @setProblems : $problem) {
		if ($_->status >= 1 && $_->num_correct == 1) {
			my $pointsEarned =
				defined $_->{reduced_score} && $_->{reduced_score} < 1
				? $ce->{achievementPointsPerProblemReduced}
				: $ce->{achievementPointsPerProblem};
			$globalUserAchievement->achievement_points($globalUserAchievement->achievement_points + $pointsEarned);
			# This variable is shared and should be considered iffy.
			$achievementPoints += $pointsEarned;
			$globalData->{completeProblems} += 1;
		}
	}

	$globalData->{completeSets}++ if ($allcorrect);

	# get the problem tags if its not a gatway
	# if it is a gateway get rid of $problem since it doensn't make sense
	if ($isGatewaySet) {
		$problem = undef;
	} else {
		my $templateDir = $ce->{courseDirs}{templates};
		$tags = WeBWorK::Utils::Tags->new($templateDir . '/' . $problem->source_file());
	}

	#These variables are shared with the safe compartment.  The achievement evaulators
	# have access too
	# $problem - the problem data;
	# @setProblems - the problem data for everything from this set;
	# $localData - the hash that is used only for this achievement
	# $globalData - the hash that is shared between all achievements
	# $maxCounter - the "max counter" associated with this achievement (if there is one);
	# $counter - the "counter" associated with this achievement (used in level bars)
	# $nextLevelPoints - only should be used by 'level' achievements
	# $set - the set data
	# $achievementPoints - the number of achievmeent points
	# $userAchievements - hash of enabled achievement_id => earned
	# $tags -this is the tag data associated to the problem from the problem library
	# @courseDateTime - array of time information in course timezone (sec,min,hour,day,month,year,day_of_week)

	$compartment->share(qw( $problem @setProblems $localData $maxCounter $userAchievements
		$globalData $counter $nextLevelPoints $set $achievementPoints $tags @courseDateTime));

	#load any preamble code
	my $preamble = '';
	my $source;
	if (-e "$ce->{courseDirs}{achievements}/$ce->{achievementPreambleFile}") {
		local $/;
		open(my $PREAMB, '<', "$ce->{courseDirs}{achievements}/$ce->{achievementPreambleFile}");
		$preamble = <$PREAMB>;
		close($PREAMB);
	}
	#loop through the various achievements, see if they have been obtained,
	foreach my $achievement (@achievements) {
		#skip achievements not assigned, not enabled, and that are already earned, or if it doesn't match the set type
		next unless $achievement->enabled;
		my $achievement_id = $achievement->achievement_id;
		next unless ($db->existsUserAchievement($user_id, $achievement_id));
		my $userAchievement = $db->getUserAchievement($user_id, $achievement_id);
		next if ($userAchievement->earned);
		my $setType = $set->assignment_type;
		next unless $achievement->assignment_type =~ /$setType/;

		#thaw_base64 localData hash
		if ($userAchievement->frozen_hash) {
			$localData = thaw_base64($userAchievement->frozen_hash);
		}

		#recover counter information (for progress bar achievements)
		$counter    = $userAchievement->counter;
		$maxCounter = $achievement->max_counter;

		#check the achievement using Safe
		my $sourceFilePath = $ce->{courseDirs}{achievements} . '/' . $achievement->test;
		if (-e $sourceFilePath) {
			local $/ = undef;
			open(my $SOURCE, '<', $sourceFilePath);
			$source = <$SOURCE>;
			close($SOURCE);
		} else {
			warn('Couldnt find achievement evaluator $sourceFilePath');
			next;
		}

		my $earned = $compartment->reval($preamble . "\n" . $source);
		warn "There were errors in achievement $achievement_id\n" . $@ if $@;

		#if we have a new achievement then update achievement points
		if ($earned) {
			$userAchievement->earned(1);

			# update userAchievements hash with earned status.
			$userAchievements->{$achievement_id} = $earned;

			if ($achievement->category eq 'level') {
				# Store prev_level_points in globalData, used for level progress bar.
				$globalData->{'prev_level_points'} = $globalUserAchievement->next_level_points;
				$globalUserAchievement->level_achievement_id($achievement_id);
				$globalUserAchievement->next_level_points($nextLevelPoints);
			}

			# Construct the cheevo message using the cheevoMessage template.
			push(@$cheevoMessage, $c->include('AchievementEvaluator/cheevoMessage', achievement => $achievement));

			my $points = $achievement->points;
			#just in case points is an uninitialized variable
			$points = 0 unless $points;

			$globalUserAchievement->achievement_points($globalUserAchievement->achievement_points + $points);
			#this variable is shared and should be considered iffy
			$achievementPoints += $points;

			# if email_template is defined, send an email to the user
			$c->minion->enqueue(
				send_achievement_email => [ {
					recipient       => $user_id,
					subject         => 'Congratulations on earning a new achievement!',
					achievementID   => $achievement_id,
					setID           => $set_id,
					nextLevelPoints => $nextLevelPoints || 0,
					pointsEarned    => $achievementPoints,
					remote_host     => $c->tx->remote_address || "UNKNOWN",
				} ],
				{ notes => { courseID => $ce->{courseName} } }
			) if ($ce->{mail}{achievementEmailFrom} && $achievement->email_template);
		}

		#update counter, nfreeze_base64 localData and store
		$userAchievement->counter($counter);
		$userAchievement->frozen_hash(nfreeze_base64($localData));
		$db->putUserAchievement($userAchievement);

	}    #end for loop

	#nfreeze_base64 globalData and store
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	if (@$cheevoMessage) {
		return $c->tag(
			'div',
			class =>
				'cheevo-toast-container toast-container position-absolute top-0 start-50 translate-middle-x p-3',
			$cheevoMessage->join('')
		);
	}

	return '';
}

1;
