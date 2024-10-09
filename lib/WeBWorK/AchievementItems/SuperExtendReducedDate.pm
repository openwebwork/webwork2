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

package WeBWorK::AchievementItems::SuperExtendReducedDate;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend a close date by 48 hours.

use WeBWorK::Utils qw(x nfreeze_base64 thaw_base64);
use WeBWorK::Utils::DateTime qw(between);
use WeBWorK::Utils::Sets qw(format_set_name_display);

sub new ($class) {
	return bless {
		id          => 'SuperExtendReducedDate',
		name        => x('Scroll of Longevity'),
		description => x(
			'Adds 48 hours to the reduced scoring date of an assignment.  You will have to resubmit '
				. 'any problems that have already been penalized to earn full credit.'
		)
	}, $class;
}

sub print_form ($self, $sets, $setProblemIds, $c) {
	my @openSets;

	# Nothing to do if reduced scoring is not enabled.
	return unless $c->{ce}->{pg}{ansEvalDefaults}{enableReducedScoring};

	for my $i (0 .. $#$sets) {
		my $new_date = $sets->[$i]->reduced_scoring_date() + 172800;
		$new_date = $sets->[$i]->due_date() if $sets->[$i]->due_date() < $new_date;
		push(@openSets, [ format_set_name_display($sets->[$i]->set_id) => $sets->[$i]->set_id ])
			if (between($sets->[$i]->open_date, $sets->[$i]->due_date)
				&& $sets->[$i]->assignment_type eq 'default'
				&& $sets->[$i]->enable_reduced_scoring);
	}

	return unless @openSets;

	return $c->c(
		$c->tag(
			'p',
			$c->maketext('Choose the assignment whose reduced scoring date you would like to extend by 48 hours.')
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'super_ext_reduced_set_id',
			label_text => $c->maketext('Assignment Name'),
			values     => \@openSets,
			menu_attr  => { dir => 'ltr' }
		)
	)->join('');
}

sub use_item ($self, $userName, $c) {
	my $db = $c->db;
	my $ce = $c->ce;

	# Validate data

	# Nothing to do if reduced scoring is not enabled.
	return 'Reduce scoring disabled.' unless $c->{ce}->{pg}{ansEvalDefaults}{enableReducedScoring};

	my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
	return 'No achievement data?!?!?!' unless $globalUserAchievement->frozen_hash;

	my $globalData = thaw_base64($globalUserAchievement->frozen_hash);
	return "You are $self->{id} trying to use an item you don't have" unless $globalData->{ $self->{id} };

	my $setID = $c->param('super_ext_reduced_set_id');
	return 'You need to input a Set Name' unless defined $setID;

	my $set     = $db->getMergedSet($userName, $setID);
	my $userSet = $db->getUserSet($userName, $setID);
	return q{Couldn't find that set!} unless $set && $userSet;

	# Add time to the reduced scoring date, keeping in mind this cannot extend past the due date.
	my $new_date = $set->reduced_scoring_date() + 172800;
	$new_date = $set->due_date() if $set->due_date() < $new_date;
	$userSet->reduced_scoring_date($new_date);
	$db->putUserSet($userSet);

	$globalData->{ $self->{id} }--;
	$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
	$db->putGlobalUserAchievement($globalUserAchievement);

	return;
}

1;
