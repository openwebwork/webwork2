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

package WeBWorK::AchievementItems::FullCreditProb;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to give full credit on a single problem

use WeBWorK::Utils           qw(x wwRound);
use WeBWorK::Utils::DateTime qw(after);

sub new ($class) {
	return bless {
		id          => 'FullCreditProb',
		name        => x('Greater Rod of Revelation'),
		description => x('Gives full credit on a single homework problem.')
	}, $class;
}

sub can_use ($self, $set, $records) {
	return 0
		unless $set->assignment_type eq 'default'
		&& after($set->open_date);

	my @problems = grep { $_->status < 1 } @$records;
	return 0 unless @problems;

	$self->{usableProblems} = \@problems;
	return 1;
}

sub print_form ($self, $set, $records, $c) {
	return WeBWorK::AchievementItems::form_popup_menu_row(
		$c,
		id         => 'full_cred_problem_id',
		label_text => $c->maketext('Problem number to give full credit'),
		first_item => $c->maketext('Choose problem to give full credit.'),
		values     => [
			map { [ $c->maketext('Problem [_1] ([_2]% to 100%)', $_->problem_id, 100 * wwRound(2, $_->status)) =>
					$_->problem_id ] } @{ $self->{usableProblems} }
		],
	);
}

sub use_item ($self, $set, $records, $c) {
	my $problemID = $c->param('full_cred_problem_id');
	unless ($problemID) {
		$c->addbadmessage($c->maketext('Select problem to give full credit with the [_1].', $self->name));
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

	# Increase status to 100%.
	my $db          = $c->db;
	my $userProblem = $db->getUserProblem($problem->user_id, $problem->set_id, $problem->problem_id);
	$problem->status(1);
	$problem->sub_status(1);
	$userProblem->status(1);
	$userProblem->sub_status(1);
	$db->putUserProblem($userProblem);

	return $c->maketext('Problem number [_1] given full credit.', $problemID);
}

1;
