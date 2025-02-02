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

package WeBWorK::AchievementItems::ResetIncorrectAttempts;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to reset number of incorrect attempts.

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(between);

sub new ($class) {
	return bless {
		id          => 'ResetIncorrectAttempts',
		name        => x('Potion of Forgetfulness'),
		description => x('Resets the number of incorrect attempts on a single homework problem.')
	}, $class;
}

sub can_use ($self, $set, $records) {
	return 0
		unless $set->assignment_type eq 'default'
		&& between($set->open_date, $set->due_date);

	$self->{usableProblems} = [ grep { $_->max_attempts > 0 && $_->num_incorrect > 0 && $_->status < 1 } @$records ];
	return @{ $self->{usableProblems} } ? 1 : 0;
}

sub print_form ($self, $set, $records, $c) {
	return WeBWorK::AchievementItems::form_popup_menu_row(
		$c,
		id         => 'reset_attempts_problem_id',
		label_text => $c->maketext('Problem number to reset incorrect attempts'),
		first_item => $c->maketext('Choose problem to reset incorrect attempts.'),
		values     => [
			map { [
				$c->maketext('Problem [_1] ([_2] of [_3] used)',
					$_->problem_id, $_->num_incorrect, $_->max_attempts) => $_->problem_id
			] } @{ $self->{usableProblems} }
		],
	);
}

# use_item is called after print_form returns a non-empty form.
# So we can assume that $set and $records have already been validated.
sub use_item ($self, $set, $records, $c) {
	my $problemID = $c->param('reset_attempts_problem_id');
	unless ($problemID) {
		$c->addbadmessage($c->maketext('Select problem to reset with the [_1].', $self->name));
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

	# Set the number of incorrect attempts to zero.
	my $db          = $c->db;
	my $userProblem = $db->getUserProblem($problem->user_id, $problem->set_id, $problem->problem_id);
	$problem->num_incorrect(0);
	$userProblem->num_incorrect(0);
	$db->putUserProblem($userProblem);

	return $c->maketext('Reset the number of attempts on problem [_1].', $problemID);
}

1;
