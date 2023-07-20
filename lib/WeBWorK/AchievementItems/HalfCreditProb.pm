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

package WeBWorK::AchievementItems::HalfCreditProb;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to give half credit on a single problem.

use WeBWorK::Utils qw(between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new ($class) {
	return bless {
		id          => 'HalfCreditProb',
		name        => x('Lesser Rod of Revelation'),
		description => x('Gives half credit on a single homework problem.')
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
				'Please choose the set name and problem number of the question which should be given half credit.')
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'hcp_set_id',
			label_text => $c->maketext('Set Name'),
			values     => \@openSets,
			menu_attr  => { dir => 'ltr', data => { problems => 'hcp_problem_id' } }
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id                  => 'hcp_problem_id',
			values              => \@problemIDs,
			label_text          => $c->maketext('Problem Number'),
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

	my $setID = $c->param('hcp_set_id');
	return 'You need to input a Set Name' unless defined $setID;

	my $problemID = $c->param('hcp_problem_id');
	return 'You need to input a Problem Number' unless $problemID;

	my $problem = $db->getUserProblem($userName, $setID, $problemID);
	return 'There was an error accessing that problem.' unless $problem;

	# Add .5 to grade with max of 1

	if ($problem->status < .5) {
		$problem->status($problem->status + .5);
	} else {
		$problem->status(1);
	}

	$db->putUserProblem($problem);

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
