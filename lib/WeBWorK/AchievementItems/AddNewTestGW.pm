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

package WeBWorK::AchievementItems::AddNewTestGW;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to allow students to take an additional version of a test within its test version interval

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(between);

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

sub can_use ($self, $set, $records) {
	return
		$set->assignment_type =~ /gateway/
		&& $set->set_id !~ /,v\d+$/
		&& between($set->open_date, $set->due_date)
		&& $set->versions_per_interval > 0;
}

sub print_form ($self, $set, $records, $c) {
	return $c->tag(
		'p',
		$c->maketext(
			'Increase the number of versions from [_1] to [_2] for this test.',
			$set->versions_per_interval,
			$set->versions_per_interval + 1
		)
	);
}

sub use_item ($self, $set, $records, $c) {
	# Increase the number of versions per interval by 1.
	my $db      = $c->db;
	my $userSet = $db->getUserSet($set->user_id, $set->set_id);
	$set->versions_per_interval($set->versions_per_interval + 1);
	$userSet->versions_per_interval($set->versions_per_interval);
	$db->putUserSet($userSet);

	return $c->maketext('One additional test version added to this test.');
}

1;
