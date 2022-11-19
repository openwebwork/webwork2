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

package WeBWorK::AchievementItems::SuperExtendDueDate;
use parent qw(WeBWorK::AchievementItems);

# Item to extend a close date by 48 hours.

use strict;
use warnings;

use WeBWorK::Utils qw(between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
	my ($class) = @_;

	return bless {
		id          => 'SuperExtendDueDate',
		name        => x('Robe of Longevity'),
		description => x('Adds 48 hours to the close date of a homework.')
	}, $class;
}

sub print_form {
	my ($self, $sets, $setProblemCount, $r) = @_;

	my @openSets;

	for my $i (0 .. $#$sets) {
		push(@openSets, [ format_set_name_display($sets->[$i]->set_id) => $sets->[$i]->set_id ])
			if (between($sets->[$i]->open_date, $sets->[$i]->due_date) && $sets->[$i]->assignment_type eq 'default');
	}

	return $r->c(
		$r->tag('p', $r->maketext('Choose the set whose close date you would like to extend.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$r,
			id         => 'ext_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
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

	my $setID = $r->param('ext_set_id');
	return 'You need to input a Set Name' unless defined $setID;

	my $set     = $db->getMergedSet($userName, $setID);
	my $userSet = $db->getUserSet($userName, $setID);
	return q{Couldn't find that set!} unless $set && $userSet;

	# Add time to the reduced scoring date, due date, and answer date.
	$userSet->reduced_scoring_date($set->reduced_scoring_date() + 172800) if $set->reduced_scoring_date;
	$userSet->due_date($set->due_date() + 172800);
	$userSet->answer_date($set->answer_date() + 172800);
	$db->putUserSet($userSet);

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
