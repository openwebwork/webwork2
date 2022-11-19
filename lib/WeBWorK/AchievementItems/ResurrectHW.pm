################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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
use parent qw(WeBWorK::AchievementItems);

# Item to resurrect a homework for 24 hours

use strict;
use warnings;

use WeBWorK::Utils qw(after x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
	my ($class) = @_;

	return bless {
		id          => 'ResurrectHW',
		name        => x('Scroll of Resurrection'),
		description => x('Opens any homework set for 24 hours.')
	}, $class;
}

sub print_form {
	my ($self, $sets, $setProblemCount, $r) = @_;

	# List all of the sets that are closed or past their reduced scoring date.

	my @closedSets;

	for my $i (0 .. $#$sets) {
		push(@closedSets, [ format_set_name_display($sets->[$i]->set_id) => $sets->[$i]->set_id ])
			if $sets->[$i]->assignment_type eq 'default'
			&& (after($sets->[$i]->due_date)
				|| ($sets->[$i]->reduced_scoring_date && after($$sets[$i]->reduced_scoring_date)));
	}

	return $r->c(
		$r->tag('p', $r->maketext('Choose the set which you would like to resurrect.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$r,
			id         => 'res_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@closedSets,
			menu_attr  => { dir => 'ltr' }
		)
	)->join('');
}

sub use_item {
	my ($self, $userName, $r) = @_;
	my $db = $r->db;
	my $ce = $r->ce;

	# Validate data

	my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
	return 'No achievement data?!?!?!' unless $globalUserAchievement->frozen_hash;

	my $globalData = thaw_base64($globalUserAchievement->frozen_hash);
	return "You are $self->{id} trying to use an item you don't have" unless $globalData->{ $self->{id} };

	my $setID = $r->param('res_set_id');
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
