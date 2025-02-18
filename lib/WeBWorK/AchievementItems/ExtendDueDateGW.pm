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

package WeBWorK::AchievementItems::ExtendDueDateGW;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend the close date on a test

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(between);

use constant ONE_DAY => 86400;

sub new ($class) {
	return bless {
		id          => 'ExtendDueDateGW',
		name        => x('Amulet of Extension'),
		description =>
			x('Extends the close date of a test by 24 hours. Note: The test must still be open for this to work.')
	}, $class;
}

sub can_use ($self, $set, $records) {
	return
		$set->assignment_type =~ /gateway/
		&& $set->set_id !~ /,v\d+$/
		&& between($set->open_date, $set->due_date + ONE_DAY);
}

sub print_form ($self, $set, $records, $c) {
	return $c->tag(
		'p',
		$c->maketext(
			'Extend the close date of this test to [_1] (an additional 24 hours).',
			$c->formatDateTime($set->due_date + ONE_DAY, $c->ce->{studentDateDisplayFormat})
		)
	);
}

sub use_item ($self, $set, $records, $c) {
	my $db      = $c->db;
	my $userSet = $db->getUserSet($set->user_id, $set->set_id);

	# Add time to the reduced scoring date, due date, and answer date.
	if ($set->reduced_scoring_date) {
		$set->reduced_scoring_date($set->reduced_scoring_date + ONE_DAY);
		$userSet->reduced_scoring_date($set->reduced_scoring_date);
	}
	$set->due_date($set->due_date + ONE_DAY);
	$userSet->due_date($set->due_date);
	$set->answer_date($set->answer_date + ONE_DAY);
	$userSet->answer_date($set->answer_date);
	$db->putUserSet($userSet);

	# FIXME: Should we add time to each test version, as adding 24 hours to a 1 hour long test
	# isn't reasonable. Disabling this for now, will revisit later.
	# Add time to the reduced scoring date, due date, and answer date for all versions.
	#my @versions = $db->listSetVersions($userName, $setID);
	#for my $version (@versions) {
	#	$set = $db->getSetVersion($userName, $setID, $version);
	#	$set->reduced_scoring_date($set->reduced_scoring_date() + ONE_DAY)
	#		if defined($set->reduced_scoring_date()) && $set->reduced_scoring_date();
	#	$set->due_date($set->due_date() + ONE_DAY);
	#	$set->answer_date($set->answer_date() + ONE_DAY);
	#	$db->putSetVersion($set);
	#}

	return $c->maketext('Close date of this test extended by 24 hours to [_1].',
		$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat}));
}

1;
