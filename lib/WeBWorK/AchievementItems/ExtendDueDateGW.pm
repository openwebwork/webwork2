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

package WeBWorK::AchievementItems::ExtendDueDateGW;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend the close date on a test

use WeBWorK::Utils qw(between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new ($class) {
	return bless {
		id          => 'ExtendDueDateGW',
		name        => x('Amulet of Extension'),
		description =>
			x('Extends the close date of a test by 24 hours. Note: The test must still be open for this to work.')
	}, $class;
}

sub print_form ($self, $sets, $setProblemIds, $c) {
	my $db = $c->db;

	my @openGateways;

	# Find the template sets for open tests.
	for my $set (@$sets) {
		push(@openGateways, [ format_set_name_display($set->set_id) => $set->set_id ])
			if $set->assignment_type =~ /gateway/
			&& $set->set_id !~ /,v\d+$/
			&& between($set->open_date, $set->due_date);
	}

	return $c->c(
		$c->tag('p', $c->maketext('Extend the close date for which test?')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'eddgw_gw_id',
			label_text => $c->maketext('Test Name'),
			values     => \@openGateways,
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

	my $setID = $c->param('eddgw_gw_id');
	return 'You need to input a Test Name' unless defined $setID;

	my $set     = $db->getMergedSet($userName, $setID);
	my $userSet = $db->getUserSet($userName, $setID);
	return q{Couldn't find that set!} unless $set && $userSet;

	# Add time to the reduced scoring date, due date, and answer date.
	$userSet->reduced_scoring_date($set->reduced_scoring_date() + 86400)
		if defined($set->reduced_scoring_date()) && $set->reduced_scoring_date();
	$userSet->due_date($set->due_date() + 86400);
	$userSet->answer_date($set->answer_date() + 86400);
	$db->putUserSet($userSet);

	# Add time to the reduced scoring date, due date, and answer date for all versions.
	my @versions = $db->listSetVersions($userName, $setID);

	for my $version (@versions) {
		$set = $db->getSetVersion($userName, $setID, $version);
		$set->reduced_scoring_date($set->reduced_scoring_date() + 86400)
			if defined($set->reduced_scoring_date()) && $set->reduced_scoring_date();
		$set->due_date($set->due_date() + 86400);
		$set->answer_date($set->answer_date() + 86400);
		$db->putSetVersion($set);
	}

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
