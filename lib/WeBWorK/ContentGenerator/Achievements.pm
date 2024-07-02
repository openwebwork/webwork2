################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

# This module prints out the list of achievements that a student has earned
package WeBWorK::ContentGenerator::Achievements;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Achievements - Content Generator for achievements list
This produces a list of earned achievements for each student.

=cut

use WeBWorK::Utils qw(sortAchievements thaw_base64);
use WeBWorK::AchievementItems;

sub initialize ($c) {
	my $db = $c->db;
	my $ce = $c->ce;

	# Get user Data
	$c->{userName}    = $c->param('user');
	$c->{studentName} = $c->param('effectiveUser') // $c->{userName};
	$c->{globalData}  = $db->getGlobalUserAchievement($c->{studentName});

	# Check to see if user items are enabled and if the user has achievement data.
	if ($ce->{achievementItemsEnabled} && defined $c->{globalData}) {
		my $itemsWithCounts = WeBWorK::AchievementItems::UserItems($c->{studentName}, $db, $ce);
		$c->{achievementItems} = $itemsWithCounts;

		my $usedItem = $c->param('useditem');

		# If the useditem parameter is defined then the student wanted to use an item, so lets do that by calling the
		# appropriate item's use method and printing results.
		if (defined $usedItem) {
			my $error = $itemsWithCounts->[$usedItem][0]->use_item($c->{studentName}, $c);
			if ($error) {
				$c->addbadmessage($error);
			} else {
				if   ($itemsWithCounts->[$usedItem][1] != 1) { --$itemsWithCounts->[$usedItem][1]; }
				else                                         { splice(@$itemsWithCounts, $usedItem, 1); }
				$c->addgoodmessage($c->maketext('Reward used successfully!'));
			}
		}
	}

	return;
}

sub getAchievementLevelData ($c) {
	my ($achievement, $level_progress, $level_goal, $level_percentage);

	if ($c->{globalData}->level_achievement_id) {
		$achievement = $c->db->getAchievement($c->{globalData}->level_achievement_id);
	}

	if ($achievement) {
		if ($c->{globalData}->next_level_points) {
			# Get prev_level_points from the globalData frozen_hash in the database.
			my $globalData = $c->{globalData}->frozen_hash ? thaw_base64($c->{globalData}->frozen_hash) : {};
			my $prev_level = $globalData->{prev_level_points} || 0;
			$level_goal       = $c->{globalData}->next_level_points - $prev_level;
			$level_progress   = $c->{globalData}->achievement_points - $prev_level;
			$level_progress   = 0           if $level_progress < 0;
			$level_progress   = $level_goal if $level_progress > $level_goal;
			$level_percentage = $level_goal ? int(100 * $level_progress / $level_goal) : 0;
		}
	}

	return (
		achievement      => $achievement,
		level_progress   => $level_progress,
		level_goal       => $level_goal,
		level_percentage => $level_percentage
	);
}

sub getAchievementItemsData ($c) {
	my $db = $c->db;

	my $userID = $c->{studentName};

	my (@items, %itemCounts, @sets, %setProblemIds);

	if ($c->ce->{achievementItemsEnabled} && $c->{achievementItems}) {
		# Remove count data so @items is structured as originally designed.
		for my $item (@{ $c->{achievementItems} }) {
			push(@items, $item->[0]);
			$itemCounts{ $item->[0]->id } = $item->[1];
		}

		for my $set ($db->getMergedSets(map { [ $userID, $_ ] } $db->listUserSets($userID))) {
			push(@sets, $set);
			$setProblemIds{ $set->set_id } = [ map { $_->[2] }
					$db->listUserProblemsWhere({ user_id => $userID, set_id => $set->set_id }, 'problem_id') ];
		}
	}

	return (
		items         => \@items,
		itemCounts    => \%itemCounts,
		sets          => \@sets,
		setProblemIds => \%setProblemIds
	);
}

sub getAchievementsData ($c) {
	my $db = $c->db;
	my $ce = $c->ce;

	my $userID = $c->{studentName};

	my (@visibleAchievements, %userAchievements);

	# Get all the achievements
	my @allAchievementIDs = $db->listAchievements;
	if (@allAchievementIDs) {
		my @achievements = $db->getAchievements(@allAchievementIDs);

		@achievements = sortAchievements(@achievements);
		my $previousCategory = $achievements[0]->category;
		my $previousNumber   = $achievements[0]->number;
		my $chainName        = $achievements[0]->achievement_id =~ s/^([^_]*_).*$/$1/r;
		my $chainCount       = 0;
		my $chainStart       = 0;

		# Loop through achievements
		for my $achievement (@achievements) {
			# Skip the level achievements and only show achievements assigned to user.
			last if ($achievement->category eq 'level');
			next unless ($db->existsUserAchievement($userID, $achievement->achievement_id));
			next unless $achievement->enabled;

			# Setup up chain achievements.
			my $isChain = 1;
			if (!$achievement->max_counter
				|| $achievement->max_counter == 0
				|| $previousCategory ne $achievement->category
				|| $previousNumber + 1 != $achievement->number
				|| $achievement->achievement_id !~ /^$chainName/)
			{
				$isChain    = 0;
				$chainCount = 0;
				$chainName  = $achievement->achievement_id =~ s/^([^_]*_).*$/$1/r;
			}
			$previousCategory = $achievement->category;
			$previousNumber   = $achievement->number;

			my $userAchievement = $db->getUserAchievement($userID, $achievement->achievement_id);

			# Don't show unearned secret achievements.
			next if ($achievement->category eq 'secret' && !$userAchievement->earned);

			# Don't show chain achievements beyond the first.
			++$chainCount if $isChain && !$userAchievement->earned;
			if ($chainCount == 0) {
				$chainStart = $userAchievement->earned ? 1 : 0;
			}
			next if $isChain && ($chainCount > 1 || ($chainCount == 1 && $chainStart == 0));

			push(@visibleAchievements, $achievement);
			$userAchievements{ $achievement->achievement_id } = $userAchievement;
		}
	}

	return (achievements => \@visibleAchievements, userAchievements => \%userAchievements);
}

1;
