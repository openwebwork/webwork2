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

package WeBWorK::AchievementItems::ReducedCred;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend a close date by 24 hours for reduced credit
# Reduced scoring needs to be enabled for this item to work.

use WeBWorK::Utils           qw(x nfreeze_base64 thaw_base64);
use WeBWorK::Utils::DateTime qw(between);
use WeBWorK::Utils::Sets     qw(format_set_name_display);

use constant ONE_DAY => 86400;

sub new ($class) {
	return bless {
		id          => 'ReducedCred',
		name        => x('Ring of Reduction'),
		description => x(
			'Enable reduced scoring for a homework set.  This will allow you to submit answers '
				. 'for partial credit for 24 hours after the close date. '
				. 'This will randomize problem details if used after the original close date.'
		)
	}, $class;
}

sub print_form ($self, $sets, $setProblemIds, $c) {
	my @openSets;

	for my $i (0 .. $#$sets) {
		push(@openSets, [ format_set_name_display($sets->[$i]->set_id) => $sets->[$i]->set_id ])
			if (between($sets->[$i]->open_date, $sets->[$i]->due_date + ONE_DAY)
				&& $sets->[$i]->assignment_type eq 'default');
	}

	return unless @openSets;

	return $c->c(
		$c->tag('p', $c->maketext('Choose the set which you would like to enable partial credit for.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'red_set_id',
			label_text => $c->maketext('Set Name'),
			values     => \@openSets,
			menu_attr  => { dir => 'ltr' }
		)
	)->join('');
}

sub use_item ($self, $userName, $c) {
	my $db = $c->db;
	my $ce = $c->ce;

	# Validate data

	return q{This item won't work unless your instructor enables the reduced scoring feature.  }
		. 'Let your instructor know that you received this message.'
		unless $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod};

	my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
	return "No achievement data?!?!?!" unless $globalUserAchievement->frozen_hash;

	my $globalData = thaw_base64($globalUserAchievement->frozen_hash);
	return "You are $self->{id} trying to use an item you don't have" unless $globalData->{ $self->{id} };

	my $setID = $c->param('red_set_id');
	return "You need to input a Set Name" unless defined $setID;

	my $set     = $db->getMergedSet($userName, $setID);
	my $userSet = $db->getUserSet($userName, $setID);
	return "Couldn't find that set!" unless $set && $userSet;

	# Change the seed for all of the problems if the set is currently closed.
	if (after($set->due_date)) {
		my @probIDs = $db->listUserProblems($userName, $setID);
		for my $probID (@probIDs) {
			my $problem = $db->getUserProblem($userName, $setID, $probID);
			$problem->problem_seed($problem->problem_seed % 2**31 + 1);
			$db->putUserProblem($problem);
		}
	}

	# Either there is already a valid reduced scoring date, or set the reduced scoring date to the close date.
	$userSet->reduced_scoring_date($set->due_date)
		unless ($set->reduced_scoring_date && ($set->reduced_scoring_date < $set->due_date));
	$userSet->enable_reduced_scoring(1);
	# Add time to the close date
	$userSet->due_date($set->due_date + ONE_DAY);
	# This may require also extending the answer date.
	$userSet->answer_date($userSet->due_date) if ($userSet->due_date > $set->answer_date);
	$db->putUserSet($userSet);

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
