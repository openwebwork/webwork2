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

package WeBWorK::AchievementItems::DoubleProb;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to make a problem worth double.

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(after);

sub new ($class) {
	return bless {
		id          => 'DoubleProb',
		name        => x('Cupcake of Enlargement'),
		description => x('Causes a single homework problem to be worth twice as much.')
	}, $class;
}

sub can_use ($self, $set, $records) {
	return $set->assignment_type eq 'default' && after($set->open_date);
}

sub print_form ($self, $set, $records, $c) {
	return WeBWorK::AchievementItems::form_popup_menu_row(
		$c,
		id         => 'dbp_problem_id',
		label_text => $c->maketext('Problem Number'),
		first_item => $c->maketext('Choose problem to double.'),
		values     => [
			map { [ $c->maketext('Problem [_1] ([_2] to [_3])', $_->problem_id, $_->value, 2 * $_->value) =>
					$_->problem_id ] } @$records
		],
	);
}

sub use_item ($self, $set, $records, $c) {
	my $problemID = $c->param('dbp_problem_id');
	unless ($problemID) {
		$c->addbadmessage($c->maketext('Select problem to double with the [_1].', $self->name));
		return '';
	}

	my $problem;
	for (@$records) {
		if ($_->problem_id == $problemID) {
			$problem = $_;
			last;
		}
	}
	return '' unless $problem;

	# Double the value of the problem.
	my $db          = $c->db;
	my $userProblem = $db->getUserProblem($problem->user_id, $problem->set_id, $problem->problem_id);
	my $orig_value  = $problem->value;
	$problem->value($orig_value * 2);
	$userProblem->value($problem->value);
	$db->putUserProblem($userProblem);

	return $c->maketext('Problem [_1] increased from [_2] points to [_3] points.',
		$problemID, $orig_value, $problem->value);
}

1;
