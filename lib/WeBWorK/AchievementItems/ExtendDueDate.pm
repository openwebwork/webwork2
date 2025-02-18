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

package WeBWorK::AchievementItems::ExtendDueDate;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend a close date by 24 hours.

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(after between);

use constant ONE_DAY => 86400;

sub new ($class) {
	return bless {
		id          => 'ExtendDueDate',
		name        => x('Tunic of Extension'),
		description => x(
			'Adds 24 hours to the close date of a homework. '
				. 'This will randomize problem details if used after the original close date.'
		)
	}, $class;
}

sub can_use ($self, $set, $records) {
	return $set->assignment_type eq 'default' && between($set->open_date, $set->due_date + ONE_DAY);
}

sub print_form ($self, $set, $records, $c) {
	my $randomization_statement = after($set->due_date) ? $c->maketext('All problems will be rerandomized.') : '';
	return $c->tag(
		'p',
		$c->maketext(
			'Extend the close date of this assignment to [_1] (an additional 24 hours). [_2]',
			$c->formatDateTime($set->due_date + ONE_DAY, $c->ce->{studentDateDisplayFormat}),
			$randomization_statement
		)
	);
}

sub use_item ($self, $set, $records, $c) {
	my $db      = $c->db;
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
		'Close date of this assignment extended by 24 hours to [_1].',
		$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat})
	);
}

1;
