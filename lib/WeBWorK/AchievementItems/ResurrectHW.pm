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

package WeBWorK::AchievementItems::ResurrectHW;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to resurrect a homework for 24 hours

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(between);

use constant ONE_DAY => 86400;

sub new ($class) {
	return bless {
		id          => 'ResurrectHW',
		name        => x('Scroll of Resurrection'),
		description => x("Reopens one closed homework set for 24 hours and rerandomizes all problems."),
	}, $class;
}

sub can_use($self, $set, $records) {
	return $set->assignment_type eq 'default' && between($set->due_date, $set->due_date + ONE_DAY);
}

sub print_form ($self, $set, $records, $c) {
	return $c->tag('p',
		$c->maketext('Reopen this homework assignment for the next 24 hours. All problems will be rerandomized.'));
}

sub use_item ($self, $set, $records, $c) {
	my $db      = $c->db;
	my $userSet = $db->getUserSet($set->user_id, $set->set_id);

	# Change the seed for all of the problems if the set is currently closed.
	if (after($set->due_date)) {
		my @userProblems =
			$db->getUserProblemsWhere({ user_id => $set->user_id, set_id => $set->set_id }, 'problem_id');
		for my $n (0 .. $#userProblems) {
			$userProblems[$n]->problem_seed($userProblems[$n]->problem_seed % 2**31 + 1);
			$records->[$n]->problem_seed($userProblems[$n]->problem_seed);
			$db->putUserProblem($userProblems[$n]);
		}
	}

	# Add time to the reduced scoring date if it was defined in the first place
	if ($set->reduced_scoring_date) {
		$set->reduced_scoring_date($set->reduced_scoring_date + ONE_DAY);
		$userSet->reduced_scoring_date($set->reduced_scoring_date);
	}
	# Add time to the close date
	$set->due_date($set->due_date + ONE_DAY);
	$userSet->due_date($set->due_date);
	# This may require also extending the answer date.
	if ($set->due_date > $set->answer_date) {
		$set->answer_date($set->due_date);
		$userSet->answer_date($set->answer_date);
	}
	$db->putUserSet($userSet);

	return $c->maketext(
		'Closing date of this assignment extended by 24 hours to [_1].',
		$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat})
	);
}

1;
