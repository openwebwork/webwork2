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

package WeBWorK::AchievementItems::DoubleSet;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to make a homework set worth twice as much

use WeBWorK::Utils qw(x nfreeze_base64 thaw_base64);
use WeBWorK::Utils::DateTime qw(between);
use WeBWorK::Utils::Sets qw(format_set_name_display);

sub new ($class) {
	return bless {
		id          => 'DoubleSet',
		name        => x('Cake of Enlargement'),
		description => x('Cause the selected homework set to count for twice as many points as it normally would.')
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
		$c->tag('p', $c->maketext('Choose the set which you would like to be worth twice as much.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'dub_set_id',
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

	my $setID = $c->param('dub_set_id');
	return 'You need to input a Set Name' unless defined $setID;

	my $set = $db->getMergedSet($userName, $setID);
	return q{Couldn't find that set!} unless $set;

	my @probIDs = $db->listUserProblems($userName, $setID);

	for my $probID (@probIDs) {
		my $globalproblem = $db->getMergedProblem($userName, $setID, $probID);
		my $problem       = $db->getUserProblem($userName, $setID, $probID);

		# Double the problem value.
		$problem->value($globalproblem->value * 2);
		$db->putUserProblem($problem);
	}

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
