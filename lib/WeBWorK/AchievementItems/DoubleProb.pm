################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

use WeBWorK::Utils qw(between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new ($class) {
	return bless {
		id          => 'DoubleProb',
		name        => x('Cupcake of Enlargement'),
		description => x('Causes a single homework problem to be worth twice as much.')
	}, $class;
}

sub print_form ($self, $sets, $setProblemCount, $c) {
	# Construct a dropdown with open sets and another with problems.
	# Javascript ensures the appropriate number of problems are shown for the selected set.

	my @openSets;
	my $maxProblems = 0;

	for my $i (0 .. $#$sets) {
		if (between($sets->[$i]->open_date, $sets->[$i]->due_date) && $sets->[$i]->assignment_type eq 'default') {
			push(
				@openSets,
				[
					format_set_name_display($sets->[$i]->set_id) => $sets->[$i]->set_id,
					data                                         => { max => $setProblemCount->[$i] }
				]
			);
			$maxProblems = $setProblemCount->[$i] if $setProblemCount->[$i] > $maxProblems;
		}
	}

	my @problemIDs;

	for my $i (1 .. $maxProblems) {
		push(@problemIDs, [ $i => $i, $i > $openSets[0][3]{max} ? (style => 'display:none') : () ]);
	}

	return $c->c(
		$c->tag(
			'p',
			$c->maketext(
				'Please choose the set name and problem number of the question which should have its weight doubled.')
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'dbp_set_id',
			label_text => $c->maketext('Set Name'),
			values     => \@openSets,
			menu_attr  => { dir => 'ltr', data => { problems => 'dbp_problem_id' } }
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id                  => 'dbp_problem_id',
			label_text          => $c->maketext('Problem Number'),
			values              => \@problemIDs,
			menu_container_attr => { class => 'col-3' }
		)
	)->join('');
}

sub use_item ($self, $userName, $c) {
	my $db = $c->db;
	my $ce = $c->ce;

	# Validate data

	my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
	return 'No achievement data?!?!?!' unless $globalUserAchievement->frozen_hash;

	my $globalData = thaw_base64($globalUserAchievement->frozen_hash);
	return "You are $self->{id} trying to use an item you don't have" unless $globalData->{ $self->{id} };

	my $setID = $c->param('dbp_set_id');
	return 'You need to input a Set Name' unless defined $setID;

	my $problemID = $c->param('dbp_problem_id');
	return 'You need to input a Problem Number' unless $problemID;

	my $globalproblem = $db->getMergedProblem($userName, $setID, $problemID);
	my $problem       = $db->getUserProblem($userName, $setID, $problemID);
	return 'There was an error accessing that problem.' unless $globalproblem && $problem;

	# Double the value of the problem.
	$problem->value($globalproblem->value * 2);
	$db->putUserProblem($problem);

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
