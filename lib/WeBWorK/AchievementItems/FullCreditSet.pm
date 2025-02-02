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

package WeBWorK::AchievementItems::FullCreditSet;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to give half credit on all problems in a homework set.

use WeBWorK::Utils           qw(x wwRound);
use WeBWorK::Utils::DateTime qw(after);

sub new ($class) {
	return bless {
		id          => 'FullCreditSet',
		name        => x('Greater Tome of Enlightenment'),
		description => x('Gives full credit on every problem in a set.')
	}, $class;
}

sub can_use ($self, $set, $records) {
	return 0
		unless $set->assignment_type eq 'default'
		&& after($set->open_date);

	my $total = 0;
	my $grade = 0;
	for my $problem (@$records) {
		$grade += $problem->status * $problem->value;
		$total += $problem->value;
	}
	$self->{old_grade} = 100 * wwRound(2, $grade / $total);
	return $self->{old_grade} == 100 ? 0 : 1;
}

sub print_form ($self, $set, $records, $c) {
	return $c->tag('p', $c->maketext(q(Increase this assignment's grade from [_1]% to 100%.), $self->{old_grade}));
}

sub use_item ($self, $set, $records, $c) {
	my $db = $c->db;

	my %userProblems =
		map { $_->problem_id => $_ } $db->getUserProblemsWhere({ user_id => $set->user_id, set_id => $set->set_id });
	for my $problem (@$records) {
		my $userProblem = $userProblems{ $problem->problem_id };
		$problem->status(1);
		$problem->sub_status(1);
		$userProblem->status(1);
		$userProblem->sub_status(1);
		$db->putUserProblem($userProblem);
	}

	return $c->maketext(q(Assignment's grade increased from [_1]% to 100%.), $self->{old_grade});
}

1;
