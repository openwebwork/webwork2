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

package WeBWorK::AchievementItems::NoReducedCred;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to remove reduce credit scoring period from a set.
# Reduced scoring needs to be enabled for this item to be useful.

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(between);

sub new ($class) {
	return bless {
		id          => 'NoReducedCred',
		name        => x('Potion of Power'),
		description => x(
			'Remove reduced scoring penalties from an open assignemnt.  You will have to resubmit '
				. 'any problems that have already been penalized to earn full credit on them.'
		)
	}, $class;
}

sub can_use ($self, $set, $records) {
	return 0
		unless $set->assignment_type eq 'default'
		&& $set->enable_reduced_scoring
		&& $set->reduced_scoring_date
		&& $set->reduced_scoring_date < $set->due_date
		&& between($set->open_date, $set->due_date);
}

sub print_form ($self, $set, $records, $c) {
	return $c->tag(
		'p',
		$c->maketext(
			q{This item won't work unless your instructor enables the reduced scoring feature.  }
				. 'Let your instructor know that you recieved this message.'
		)
	) unless $c->{ce}->{pg}{ansEvalDefaults}{enableReducedScoring};

	return $c->tag(
		'p',
		$c->maketext(
			'Remove the reduced scoring penalty from this assignment. Problems submitted before '
				. 'the close date on [_1] will earn full credit. Any problems that have already been '
				. 'penalized will have to be resubmitted for full credit.',
			$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat})
		)
	);
}

sub use_item ($self, $set, $records, $c) {
	return '' unless $c->{ce}->{pg}{ansEvalDefaults}{enableReducedScoring};

	my $db      = $c->db;
	my $userSet = $db->getUserSet($set->user_id, $set->set_id);

	$set->enable_reduced_scoring(0);
	$set->reduced_scoring_date($set->due_date);
	$userSet->enable_reduced_scoring(0);
	$userSet->reduced_scoring_date($set->due_date);
	$db->putUserSet($userSet);

	return $c->maketext('Reduced scoring penalty removed.');
}

1;
