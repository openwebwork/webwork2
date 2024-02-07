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

package WeBWorK::AchievementItems::HalfCreditSet;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to give half credit on all problems in a homework set.

use WeBWorK::Utils qw(between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new ($class) {
	return bless {
		id          => 'HalfCreditSet',
		name        => x('Lesser Tome of Enlightenment'),
		description => x('Gives half credit on every problem in a set.')
	}, $class;
}

sub print_form ($self, $sets, $setProblemIds, $c) {
	my @openSets;

	for my $i (0 .. $#$sets) {
		push(@openSets, [ format_set_name_display($sets->[$i]->set_id) => $sets->[$i]->set_id ])
			if (between($sets->[$i]->open_date, $sets->[$i]->due_date) && $sets->[$i]->assignment_type eq 'default');
	}

	return unless @openSets;

	return $c->c(
		$c->tag('p', $c->maketext('Please choose the set for which all problems should have half credit added.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'hcs_set_id',
			label_text => $c->maketext('Set Name'),
			values     => \@openSets,
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

	my $setID = $c->param('hcs_set_id');
	return 'You need to input a Set Name' unless defined $setID;

	my @probIDs = $db->listUserProblems($userName, $setID);

	for my $probID (@probIDs) {
		my $problem = $db->getUserProblem($userName, $setID, $probID);

		# Add .5 to grade with max of 1.
		if ($problem->status < .5) {
			$problem->status($problem->status + .5);
		} else {
			$problem->status(1);
		}
		$db->putUserProblem($problem);
	}

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
