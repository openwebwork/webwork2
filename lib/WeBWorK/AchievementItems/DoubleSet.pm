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

package WeBWorK::AchievementItems::DoubleSet;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to make a homework set worth twice as much

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(after);

sub new ($class) {
	return bless {
		id          => 'DoubleSet',
		name        => x('Cake of Enlargement'),
		description => x('Cause the selected homework set to count for twice as many points as it normally would.')
	}, $class;
}

sub can_use ($self, $set, $records) {
	return $set->assignment_type eq 'default' && after($set->open_date);
}

sub print_form ($self, $set, $records, $c) {
	my $total = 0;
	for my $problem (@$records) {
		$total += $problem->value;
	}
	return $c->tag('p',
		$c->maketext(q(Increase this assignment's total number of points from [_1] to [_2].), $total, 2 * $total));
}

sub use_item ($self, $set, $records, $c) {
	my $db        = $c->db;
	my $old_value = 0;
	my $new_value = 0;

	my @userProblems = $db->getUserProblemsWhere({ user_id => $set->user_id, set_id => $set->set_id }, 'problem_id');
	for my $n (0 .. $#userProblems) {
		$old_value += $records->[$n]->value;
		$records->[$n]->value($records->[$n]->value * 2);
		$userProblems[$n]->value($records->[$n]->value);
		$new_value += $userProblems[$n]->value;
		$db->putUserProblem($userProblems[$n]);
	}

	return $c->maketext(q(Assignment's total point value increased from [_1] points to [_2] points),
		$old_value, $new_value);
}

1;
