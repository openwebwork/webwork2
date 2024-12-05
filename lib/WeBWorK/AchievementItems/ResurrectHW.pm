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

use WeBWorK::Utils           qw(x nfreeze_base64 thaw_base64);
use WeBWorK::Utils::DateTime qw(after);
use WeBWorK::Utils::Sets     qw(format_set_name_display);

sub new ($class) {
	return bless {
		id          => 'ResurrectHW',
		name        => x('Scroll of Resurrection'),
		description => x("Reopens one closed homework set for 24 hours and rerandomizes all problems."),
	}, $class;
}

sub print_form ($self, $sets, $setProblemIds, $c) {
	# List all of the sets that are closed or past their reduced scoring date.

	my @closedSets;

	for my $i (0 .. $#$sets) {
		push(@closedSets, [ format_set_name_display($sets->[$i]->set_id) => $sets->[$i]->set_id ])
			if $sets->[$i]->assignment_type eq 'default'
			&& (after($sets->[$i]->due_date)
				|| ($sets->[$i]->reduced_scoring_date && after($sets->[$i]->reduced_scoring_date)));
	}

	return unless @closedSets;

	return $c->c(
		$c->tag('p', $c->maketext('Choose the set which you would like to resurrect.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'res_set_id',
			label_text => $c->maketext('Set Name'),
			values     => \@closedSets,
			menu_attr  => { dir => 'ltr' }
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

	my $setID = $c->param('res_set_id');
	return 'You need to input a Set Name' unless defined $setID;

	my $set = $db->getUserSet($userName, $setID);
	return q{Couldn't find that set!} unless $set;

	# Set a new reduced scoring date, close date, and answer date for the student.
	$set->reduced_scoring_date(time + 86400);
	$set->due_date(time + 86400);
	$set->answer_date(time + 86400);
	$db->putUserSet($set);

	my @probIDs = $db->listUserProblems($userName, $setID);

	# Change the seed for all of the problems in the set.
	for my $probID (@probIDs) {
		my $problem = $db->getUserProblem($userName, $setID, $probID);
		$problem->problem_seed($problem->problem_seed + 100);
		$db->putUserProblem($problem);
	}

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
