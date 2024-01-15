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

package WeBWorK::AchievementItems::DuplicateProb;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to turn one problem into another problem

use Mojo::JSON qw(encode_json);

use WeBWorK::Utils qw(between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new ($class) {
	return bless {
		id          => 'DuplicateProb',
		name        => x('Box of Transmogrification'),
		description => x('Causes a homework problem to become a clone of another problem from the same set.')
	}, $class;
}

sub print_form ($self, $sets, $setProblemIds, $c) {
	# Show open sets and allow for a choice of two problems from the set.
	# Javascript ensures the appropriate problems are shown for the selected set.

	my (@openSets, @initialProblemIDs);

	for my $i (0 .. $#$sets) {
		if (between($sets->[$i]->open_date, $sets->[$i]->due_date)
			&& $sets->[$i]->assignment_type eq 'default'
			&& @{ $setProblemIds->{ $sets->[$i]->set_id } })
		{
			push(
				@openSets,
				[
					format_set_name_display($sets->[$i]->set_id) => $sets->[$i]->set_id,
					data => { problem_ids => encode_json($setProblemIds->{ $sets->[$i]->set_id }) }
				]
			);
			@initialProblemIDs = @{ $setProblemIds->{ $sets->[$i]->set_id } } unless @initialProblemIDs;
		}
	}

	return $c->c(
		$c->tag(
			'p',
			$c->maketext(
				'Please choose the set, the problem you would like to copy, '
					. 'and the problem you would like to copy it to.'
			)
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'tran_set_id',
			label_text => $c->maketext('Set Name'),
			values     => \@openSets,
			menu_attr  => {
				dir  => 'ltr',
				data => { problems => 'tran_problem_id', problems2 => 'tran_problem_id2' }
			}
		),
		$c->tag(
			'div',
			class => 'row mb-3',
			$c->c(
				WeBWorK::AchievementItems::form_popup_menu_row(
					$c,
					id                  => 'tran_problem_id',
					values              => \@initialProblemIDs,
					label_text          => $c->maketext('Copy this Problem'),
					menu_container_attr => { class => 'col-2 ps-0' },
					add_container       => 0
				),
				WeBWorK::AchievementItems::form_popup_menu_row(
					$c,
					id                  => 'tran_problem_id2',
					values              => \@initialProblemIDs,
					label_text          => $c->maketext('To this Problem'),
					menu_container_attr => { class => 'col-2 ps-0' },
					add_container       => 0
				)
			)->join('')
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

	my $setID = $c->param('tran_set_id');
	return 'You need to input a Set Name' unless defined $setID;

	my $problemID = $c->param('tran_problem_id');
	return 'You need to input a Problem Number' unless $problemID;

	my $problemID2 = $c->param('tran_problem_id2');
	return 'You need to input a Problem Number' unless $problemID2;

	return 'You need to pick 2 different problems!' if $problemID == $problemID2;

	my $problem  = $db->getMergedProblem($userName, $setID, $problemID);
	my $problem2 = $db->getUserProblem($userName, $setID, $problemID2);
	return 'There was an error accessing those problems.' unless $problem && $problem2;

	# Set the source of the second problem to that of the first problem.
	$problem2->source_file($problem->source_file);
	$db->putUserProblem($problem2);

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
