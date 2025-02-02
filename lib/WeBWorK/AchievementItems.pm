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

use WeBWorK::Utils qw(nfreeze_base64 thaw_base64);

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

This is the base class for achievement times.  This defines an interface for all of the achievement items.
Each achievement item will have an id, a name, a description, and the three methods can_use (checks if the
item can be used on the given set), print_form (prints the form to use the item), and use_item.

Note: the ID has to match the name of the class.

The global method UserItems returns an array of all achievement items available to the given user.  If no
set is included, a list of all earned achievement items is return. If provided a set and corresponding problem
or test version records, a list of items usable on the current set and records paired with an input form to
use the item is returned. This method will also process any posts to use the achievement item.

=cut

sub id          ($self) { return $self->{id}; }
sub name        ($self) { return $self->{name}; }
sub count       ($self) { return $self->{count}; }
sub description ($self) { return $self->{description}; }

# Method to find all achievement items available to the given user.
# If $set is undefined return an array reference of all earned items.
# If $set is defined, return an array reference of the usable items
# for the given $set and problem or test versions records. Each item
# is paired with its input form to use the item.
sub UserItems ($c, $userName, $set, $records) {
	my $db = $c->db;
	my $ce = $c->ce;

	# Return unless achievement items are enabled.
	return unless $ce->{achievementsEnabled} && $ce->{achievementItemsEnabled};

	# When acting as another user, achievement items can be listed but not used.
	return if $set && $userName ne $c->param('user');

	# Return unless the user has global achievement data.
	my $globalUserAchievement = $c->{globalData} // $db->getGlobalUserAchievement($userName);
	return unless $globalUserAchievement && $globalUserAchievement->frozen_hash;

	my $globalData  = thaw_base64($globalUserAchievement->frozen_hash);
	my $use_item_id = $c->param('use_achievement_item_id') // '';
	my @items;

	for my $item (@{ +ITEMS }) {
		next unless $globalData->{$item};
		my $achievementItem = "WeBWorK::AchievementItems::$item"->new;
		$achievementItem->{count} = $globalData->{$item};

		# Return list of achievements items if $set is not defined.
		unless ($set) {
			push(@items, $achievementItem);
			next;
		}
		next unless $achievementItem->can_use($set, $records);

		# Use the achievement item.
		if ($use_item_id eq $item) {
			my $message = $achievementItem->use_item($set, $records, $c);
			if ($message) {
				$globalData->{$item}--;
				$achievementItem->{count}--;
				$globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
				$db->putGlobalUserAchievement($globalUserAchievement);
				$c->addgoodmessage($c->maketext('[_1] succesffuly used. [_2]', $achievementItem->name, $message));
			}
		}

		push(@items, [ $achievementItem, $use_item_id ? '' : $achievementItem->print_form($set, $records, $c) ]);
	}

	# If an achievement item has been used, double check if the achievement items can still be used
	# since the item count could now be zero or an achievement item has altered the set/records.
	# Input forms are also built here to account for any possible change.
	if ($set && $use_item_id) {
		my @new_items;
		for (@items) {
			my $item = $_->[0];
			next unless $item->{count} && $item->can_use($set, $records);
			push(@new_items, [ $item, $item->print_form($set, $records, $c) ]);
		}
		return \@new_items;
	}
	return \@items;
}

# Method that returns a string with the achievement name and number of remaining items.
# This should only be called if count != 0.
sub remaining_title ($self, $c) {
	if ($self->count > 0) {
		return $c->maketext('[_1] ([_2] remaining)', $c->maketext($self->name), $self->count);
	} else {
		return $c->maketext('[_1] (unlimited reusability)', $c->maketext($self->name));
	}
}

# Utility method for outputing a form row with a label and popup menu.
# The id, label_text, and values are required parameters.
sub form_popup_menu_row ($c, %options) {
	my %params = (
		id            => '',
		first_item    => '',
		label_text    => '',
		label_attr    => {},
		values        => [],
		menu_attr     => {},
		add_container => 1,
		%options
	);

	$params{label_attr}{class} //= 'col-form-label';
	$params{menu_attr}{class}  //= 'form-select';

	unshift(@{ $params{values} }, [ $params{first_item} => '' ]) if $params{first_item};

	my $row_contents = $c->tag(
		'div',
		class => 'form-floating',
		$c->c(
			$c->select_field($params{id} => $params{values}, %{ $params{menu_attr} }),
			$c->label_for($params{id} => $params{label_text}, %{ $params{label_attr} })
		)->join('')
	);

	return $params{add_container} ? $c->tag('div', class => 'my-3', $row_contents) : $row_contents;
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
