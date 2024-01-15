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

package WeBWorK::AchievementItems::AddNewTestGW;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to allow students to take an additional version of a test within its test version interval

use WeBWorK::Utils qw(before between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new ($class) {
	return bless {
		id          => 'AddNewTestGW',
		name        => x('Oil of Cleansing'),
		description => x(
			'Unlock an additional version of a test.  If used before the close date of '
				. 'the test this will allow you to generate a new version of the test.'
		)
	}, $class;
}

sub print_form ($self, $sets, $setProblemIds, $c) {
	my $db = $c->db;

	my @openGateways;

	# Find the template sets of open gateway quizzes.
	for my $set (@$sets) {
		push(@openGateways, [ format_set_name_display($set->set_id) => $set->set_id ])
			if $set->assignment_type =~ /gateway/
			&& $set->set_id !~ /,v\d+$/
			&& between($set->open_date, $set->due_date);
	}

	return $c->c(
		$c->tag('p', $c->maketext('Add a new version for which test?')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'adtgw_gw_id',
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

	my $setID = $c->param('adtgw_gw_id');
	return 'You need to input a Test Name' unless defined $setID;

	my $set     = $db->getMergedSet($userName, $setID);
	my $userSet = $db->getUserSet($userName, $setID);
	return q{Couldn't find that set!} unless $set && $userSet;

	# Add an additional version per interval to the set.
	$userSet->versions_per_interval($set->versions_per_interval + 1) unless $set->versions_per_interval == 0;
	$db->putUserSet($userSet);

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
