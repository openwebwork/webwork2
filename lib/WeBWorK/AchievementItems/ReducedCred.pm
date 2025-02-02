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

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(after between);

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

sub can_use ($self, $set, $records) {
	return $set->assignment_type eq 'default' && between($set->open_date, $set->due_date + ONE_DAY);
}

sub print_form ($self, $set, $records, $c) {
	my $ce = $c->ce;

	return $c->tag(
		'p',
		$c->maketext(
			q{This item won't work unless your instructor enables the reduced scoring feature.  }
				. 'Let your instructor know that you received this message.'
		)
	) unless $ce->{pg}{ansEvalDefaults}{enableReducedScoring};

	my $randomization_statement = after($set->due_date) ? $c->maketext('All problems will be rerandomized.') : '';
	return $c->tag(
		'p',
		$c->maketext(
			'Extend the close date of this assignment to [_1] (an additional 24 hours).  Any submissions during '
				. 'this additional time will be reducend and are worth [_2]% of their full value. [_3]',
			$c->formatDateTime($set->due_date + ONE_DAY, $ce->{studentDateDisplayFormat}),
			100 * $ce->{pg}{ansEvalDefaults}{reducedScoringValue},
			$randomization_statement
		)
	);
}

sub use_item ($self, $set, $records, $c) {
	my $ce = $c->ce;
	my $db = $c->db;

	# Still need to double check reduced scoring is enabled.
	return '' unless $ce->{pg}{ansEvalDefaults}{enableReducedScoring};

	my $userSet = $db->getUserSet($set->user_id, $set->set_id);

	# Change the seed for all of the problems if the set is currently closed.
	if (after($set->due_date)) {
		my %userProblems =
			map { $_->problem_id => $_ }
			$db->getUserProblemsWhere({ user_id => $set->user_id, set_id => $set->set_id });
		for my $problem (@$records) {
			my $userProblem = $userProblems{ $problem->problem_id };
			$userProblem->problem_seed($userProblem->problem_seed % 2**31 + 1);
			$problem->problem_seed($userProblem->problem_seed);
			$db->putUserProblem($userProblem);
		}
	}

	# Either there is already a valid reduced scoring date, or set the reduced scoring date to the close date.
	unless ($set->reduced_scoring_date && $set->reduced_scoring_date < $set->due_date) {
		$set->reduced_scoring_date($set->due_date);
		$userSet->reduced_scoring_date($set->reduced_scoring_date);
	}
	$set->enable_reduced_scoring(1);
	$userSet->enable_reduced_scoring(1);
	# Add time to the close date
	$set->due_date($set->due_date + ONE_DAY);
	$userSet->due_date($set->due_date);
	# This may require also extending the answer date.
	if ($set->due_date > $set->answer_date) {
		$set->answer_date($set->due_date);
		$userSet->answer_date($set->answer_date);
	}
	$db->putUserSet($userSet);

	return $c->maketext('Close date changed by 24 hours to [_1].',
		$c->formatDateTime($set->due_date, $ce->{studentDateDisplayFormat}));
}

1;
