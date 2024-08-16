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

package WeBWorK::AchievementItems;
use Mojo::Base -signatures;

use WeBWorK::Utils qw(thaw_base64);

# List of available achievement items.  Make sure to add any new items to this list. Furthermore, the elements in this
# list have to match the class name of the achievement item classes loaded below.
use constant ITEMS => [ qw(
	ResetIncorrectAttempts
	DuplicateProb
	DoubleProb
	HalfCreditProb
	FullCreditProb
	ReducedCred
	NoReducedCred
	ExtendDueDate
	ExtendReducedDate
	DoubleSet
	ResurrectHW
	Surprise
	SuperExtendDueDate
	SuperExtendReducedDate
	HalfCreditSet
	FullCreditSet
	AddNewTestGW
	ExtendDueDateGW
	ResurrectGW
) ];

=head2 NAME

This is the base class for achievement times.  This defines an interface for all of the achievement items.  Each
achievement item will have a name, a description, a method for creating an html form to get its inputs called print_form
and a method for applying those inputs called use_item.

Note: the ID has to match the name of the class.

=cut

sub id          ($c) { return $c->{id}; }
sub name        ($c) { return $c->{name}; }
sub description ($c) { return $c->{description}; }

# This is a global method that returns all of the provided users items.
sub UserItems ($userName, $db, $ce) {
	# return unless the user has global achievement data
	my $globalUserAchievement = $db->getGlobalUserAchievement($userName);

	return unless ($globalUserAchievement->frozen_hash);

	my $globalData = thaw_base64($globalUserAchievement->frozen_hash);
	my @items;

	# Get a new item object for each type of item.
	for my $item (@{ +ITEMS }) {
		push(@items, [ "WeBWorK::AchievementItems::$item"->new, $globalData->{$item} ])
			if ($globalData->{$item});
	}

	return \@items;
}

# Utility method for outputing a form row with a label and popup menu.
# The id, label_text, and values are required parameters.
sub form_popup_menu_row ($c, %options) {
	my %params = (
		id                  => '',
		label_text          => '',
		label_attr          => {},
		values              => [],
		menu_attr           => {},
		menu_container_attr => {},
		add_container       => 1,
		%options
	);

	$params{label_attr}{class}          //= 'col-4 col-form-label';
	$params{menu_attr}{class}           //= 'form-select';
	$params{menu_container_attr}{class} //= 'col-8';

	my $row_contents = $c->c(
		$c->label_for($params{id} => $params{label_text}, %{ $params{label_attr} }),
		$c->tag(
			'div',
			%{ $params{menu_container_attr} },
			$c->select_field($params{id} => $params{values}, id => $params{id}, %{ $params{menu_attr} })
		)
	)->join('');

	return $params{add_container} ? $c->tag('div', class => 'row mb-3', $row_contents) : $row_contents;
}

END {
	# Load the achievement item classes.
	use WeBWorK::AchievementItems::AddNewTestGW;
	use WeBWorK::AchievementItems::DoubleProb;
	use WeBWorK::AchievementItems::DoubleSet;
	use WeBWorK::AchievementItems::DuplicateProb;
	use WeBWorK::AchievementItems::ExtendDueDateGW;
	use WeBWorK::AchievementItems::ExtendDueDate;
	use WeBWorK::AchievementItems::ExtendReducedDate;
	use WeBWorK::AchievementItems::FullCreditProb;
	use WeBWorK::AchievementItems::FullCreditSet;
	use WeBWorK::AchievementItems::HalfCreditProb;
	use WeBWorK::AchievementItems::HalfCreditSet;
	use WeBWorK::AchievementItems::ReducedCred;
	use WeBWorK::AchievementItems::NoReducedCred;
	use WeBWorK::AchievementItems::ResetIncorrectAttempts;
	use WeBWorK::AchievementItems::ResurrectGW;
	use WeBWorK::AchievementItems::ResurrectHW;
	use WeBWorK::AchievementItems::SuperExtendDueDate;
	use WeBWorK::AchievementItems::SuperExtendReducedDate;
	use WeBWorK::AchievementItems::Surprise;
}

1;
