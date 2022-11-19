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

package WeBWorK::AchievementItems::ResurrectGW;
use parent qw(WeBWorK::AchievementItems);

# Item to extend the due date on a gateway

use strict;
use warnings;

use WeBWorK::Utils qw(x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
	my ($class) = @_;

	return bless {
		id          => 'ResurrectGW',
		name        => x('Necromancers Charm'),
		description => x(
			'Reopens any gateway test for an additional 24 hours. This allows you to take a test even if the '
				. 'close date has past. This item does not allow you to take additional versions of the test.'
		)
	}, $class;
}

sub print_form {
	my ($self, $sets, $setProblemCount, $r) = @_;
	my $db = $r->db;

	my $effectiveUserName = $r->param('effectiveUser') // $r->param('user');
	my @unfilteredsets = $db->getMergedSets(map { [ $effectiveUserName, $_ ] } $db->listUserSets($effectiveUserName));
	my @sets;

	# Find the template sets of gateway quizzes.
	for my $set (@unfilteredsets) {
		push(@sets, [ format_set_name_display($set->set_id) => $set->set_id ])
			if ($set->assignment_type =~ /gateway/ && $set->set_id !~ /,v\d+$/);
	}

	return $r->c(
		$r->tag('p', $r->maketext('Resurrect which Gateway?')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$r,
			id         => 'resgw_gw_id',
			label_text => $r->maketext('Gateway Name'),
			values     => \@sets,
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

	my $setID = $r->param('resgw_gw_id');
	return 'You need to input a Gateway Name' unless defined $setID;

	my $set = $db->getUserSet($userName, $setID);
	return q{Couldn't find that set!} unless $set;

	# Add time to the reduced scoring date, due date, and answer date.
	$set->reduced_scoring_date(time + 86400) if defined($set->reduced_scoring_date()) && $set->reduced_scoring_date();
	$set->due_date(time + 86400);
	$set->answer_date(time + 86400);
	$db->putUserSet($set);

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
