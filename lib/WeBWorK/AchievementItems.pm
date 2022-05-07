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

package WeBWorK::AchievementItems;
use base qw(WeBWorK);

use WeBWorK::Utils qw(nfreeze_base64 thaw_base64);

use strict;
use warnings;

# have to add any new items to this list, furthermore
# the elements of this list have to match the class name/id of the
# item classes defined below.
use constant ITEMS => [qw(
ResetIncorrectAttempts
DuplicateProb
DoubleProb
HalfCreditProb
FullCreditProb
ReducedCred
ExtendDueDate
DoubleSet
ResurrectHW
Surprise
SuperExtendDueDate
HalfCreditSet
FullCreditSet
AddNewTestGW
ExtendDueDateGW
ResurrectGW
)];

=head2 NAME

Item - this is the base class for achievement times.  This defines an
interface for all of the achievement items.  Each achievement item will have
a name, a description, a method for creating an html form to get its inputs
called print_form and a method for applying those inputs called use_item.

Note: the ID has to match the name of the class.

=cut

sub id { shift->{id} }
sub name { shift->{name} }
sub description { shift->{description} }

# This is a global method that returns all of the provided users items.
sub UserItems {
    my $userName = shift;
    my $db = shift;
    my $ce = shift;

    # return unless the user has global achievement data
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);

    return unless ($globalUserAchievement->frozen_hash);

    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);
    my @items;

    # ugly eval to get a new item object for each type of item.
    foreach my $item (@{+ITEMS}) {
	push (@items, [eval("WeBWorK::AchievementItems::${item}->new"),$globalData->{$item}]) if
	    ($globalData->{$item});
    }

    return \@items;
}

# Utility method for outputing a form row with a label and popup menu.
# The id, label_text, and values are required parameters.
sub form_popup_menu_row {
	my %params = (
		id                  => '',
		label_text          => '',
		label_attr          => {},
		values              => [],
		labels              => {},
		menu_attr           => {},
		menu_container_attr => {},
		add_container       => 1,
		@_
	);

	$params{label_attr}{for}            = $params{id};
	$params{label_attr}{class}          = 'col-4 col-form-label' unless defined $params{label_attr}{class};
	$params{menu_attr}{values}          = $params{values};
	$params{menu_attr}{labels}          = $params{labels};
	$params{menu_attr}{id}              = $params{id};
	$params{menu_attr}{name}            = $params{id};
	$params{menu_attr}{class}           = 'form-select' unless defined $params{menu_attr}{class};
	$params{menu_container_attr}{class} = 'col-8'       unless defined $params{menu_container_attr}{class};

	return join('',
		$params{add_container} ? CGI::start_div({ class => 'row mb-3' }) : '',
		CGI::label($params{label_attr}, $params{label_text}),
		CGI::div($params{menu_container_attr}, CGI::popup_menu($params{menu_attr})),
		$params{add_container} ? CGI::end_div() : '');
}

#Item to resurrect a homework for 24 hours

package WeBWorK::AchievementItems::ResurrectHW;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "ResurrectHW",
	name => x("Scroll of Resurrection"),
	description => x("Opens any homework set for 24 hours."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;

    my @openSets;
    my @openSetCount;
    my $maxProblems=0;

    #Find all of the closed sets or sets that are past their reduced scoring date and put them in form

	for (my $i = 0; $i <= $#$sets; $i++) {
		if (after($$sets[$i]->due_date) && $$sets[$i]->assignment_type eq 'default') {
			push(@openSets, $$sets[$i]->set_id);
		} elsif (defined $$sets[$i]->reduced_scoring_date && $$sets[$i]->reduced_scoring_date ne '') {
			if (after($$sets[$i]->reduced_scoring_date) && $$sets[$i]->assignment_type eq 'default') {
				push(@openSets, $$sets[$i]->set_id);
			}
		}
	}

	return join(
		'',
		CGI::p($r->maketext('Choose the set which you would like to resurrect.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'res_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			menu_attr  => { dir => 'ltr' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #check and see if student really has the item and if the data is valid
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('res_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    my $set = $db->getUserSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);

    # Set a new reduced scoring date, close date, and answer date for the student; remove the item
    $set->reduced_scoring_date(time()+86400);
    $set->due_date(time()+86400);
    $set->answer_date(time()+86400);

    $db->putUserSet($set);

    my @probIDs = $db->listUserProblems($userName,$setID);

    foreach my $probID (@probIDs) {
	my $problem = $db->getUserProblem($userName,$setID,$probID);
	$problem->problem_seed($problem->problem_seed + 100);
	$db->putUserProblem($problem);
    }

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to extend a close date by 24 hours.

package WeBWorK::AchievementItems::ExtendDueDate;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "ExtendDueDate",
	name => x("Tunic of Extension"),
	description => x("Adds 24 hours to the close date of a homework."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;

    my @openSets;
    my @openSetCount;
    my $maxProblems=0;

    #find all currently open sets and print to a form
    for (my $i=0; $i<=$#$sets; $i++) {
	if (between($$sets[$i]->open_date, $$sets[$i]->answer_date)  && $$sets[$i]->assignment_type eq "default") {
	    push(@openSets,$$sets[$i]->set_id);
	}
    }

	return join(
		'',
		CGI::p($r->maketext('Choose the set whose close date you would like to extend.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'ext_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			menu_attr  => { dir => 'ltr' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #check and see if the student has the achievement and if the data is valid
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('ext_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);
    my $userSet = $db->getUserSet($userName,$setID);

    #add time to the reduced scoring date, due date, and answer date; remove item from inventory
    $userSet->reduced_scoring_date($set->reduced_scoring_date()+86400) if defined($set->reduced_scoring_date()) && $set->reduced_scoring_date();
    $userSet->due_date($set->due_date()+86400);
    $userSet->answer_date($set->answer_date()+86400);

    $db->putUserSet($userSet);

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to extend a close date by 48 hours.

package WeBWorK::AchievementItems::SuperExtendDueDate;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "SuperExtendDueDate",
	name => x("Robe of Longevity"),
	description => x("Adds 48 hours to the close date of a homework."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;

    my @openSets;
    my @openSetCount;
    my $maxProblems=0;

    #find all currently open sets and print to a form
    for (my $i=0; $i<=$#$sets; $i++) {
	if (between($$sets[$i]->open_date, $$sets[$i]->answer_date)  && $$sets[$i]->assignment_type eq "default") {
	    push(@openSets,$$sets[$i]->set_id);
	}
    }

	return join(
		'',
		CGI::p($r->maketext('Choose the set whose close date you would like to extend.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'ext_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			menu_attr  => { dir => 'ltr' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #check and see if the student has the achievement and if the data is valid
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('ext_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);
    my $userSet = $db->getUserSet($userName,$setID);

    #add time to the reduced scoring date, due date, and answer date; remove item from inventory
    $userSet->reduced_scoring_date($set->reduced_scoring_date()+172800) if defined($set->reduced_scoring_date()) && $set->reduced_scoring_date();
    $userSet->due_date($set->due_date()+172800);
    $userSet->answer_date($set->answer_date()+172800);

    $db->putUserSet($userSet);

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to extend a close date by 24 hours for reduced credit

package WeBWorK::AchievementItems::ReducedCred;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "ReducedCred",
	name => x("Ring of Reduction"),
	#Reduced credit needs to be set up in course configuration for this
	# item to work,
	description => x("Enable reduced scoring for a homework set.  This will allow you to submit answers for partial credit for 24 hours after the close date."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;
    my $ce = $r->{ce};

    my @openSets;
    my @openSetCount;
    my $maxProblems=0;


    #print names of open sets
    for (my $i=0; $i<=$#$sets; $i++) {
	if (between($$sets[$i]->open_date, $$sets[$i]->answer_date)  && $$sets[$i]->assignment_type eq "default") {
	    push(@openSets,$$sets[$i]->set_id);
	}
    }

	return join(
		'',
		CGI::p($r->maketext('Choose the set which you would like to enable partial credit for.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'red_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			menu_attr  => { dir => 'ltr' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;


    #check variables
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "This item won't work unless your instructor enables the reduced scoring feature.  Let them know that you recieved this message." unless $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod};


    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('red_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);
    my $userSet = $db->getUserSet($userName,$setID);

    # enable reduced scoring on the set and add the reduced scoring period
    # to the due date.
    my $additionalTime = 60*$ce->{pg}{ansEvalDefaults}{reducedScoringPeriod};
    $userSet->enable_reduced_scoring(1);
    $userSet->reduced_scoring_date($set->due_date());
    $userSet->due_date($set->due_date()+$additionalTime);
    $userSet->answer_date($set->answer_date()+$additionalTime);

    $db->putUserSet($userSet);

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to make a homework set worth twice as much

package WeBWorK::AchievementItems::DoubleSet;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "DoubleSet",
	name => x("Cake of Enlargement"),
	description => x("Cause the selected homework set to count for twice as many points as it normally would."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;
    my $ce = $r->{ce};

    my @openSets;

    #print open sets

    for (my $i=0; $i<=$#$sets; $i++) {
	if ($$sets[$i]->assignment_type eq "default") {
	    push(@openSets,$$sets[$i]->set_id);
	}
    }

	return join(
		'',
		CGI::p($r->maketext('Choose the set which you would like to be worth twice as much.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'dub_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			menu_attr  => { dir => 'ltr' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate input data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('dub_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);

    # got through the problems in the set and double the value/weight of each

    my @probIDs = $db->listUserProblems($userName,$setID);

    foreach my $probID (@probIDs) {
	my $globalproblem = $db->getMergedProblem($userName, $setID,$probID);
	my $problem = $db->getUserProblem($userName,$setID,$probID);
	$problem->value($globalproblem->value*2);
	$db->putUserProblem($problem);
    }

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to reset number of incorrect attempts.
package WeBWorK::AchievementItems::ResetIncorrectAttempts;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "ResetIncorrectAttempts",
	name => x("Potion of Forgetfulness"),
	description => x("Resets the number of incorrect attempts on a single homework problem."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
	my $self            = shift;
	my $sets            = shift;
	my $setProblemCount = shift;
	my $r               = shift;

	my @openSets;
	my $set_attribs;
	my @openSetCount;
	my $maxProblems = 0;

	#print open sets in a drop down and some javascript which will cause the
	#second drop down to have the correct number of problems for each set

	for (my $i = 0; $i <= $#$sets; $i++) {
		if (between($$sets[$i]->open_date, $$sets[$i]->due_date) && $$sets[$i]->assignment_type eq "default") {
			push(@openSets, $$sets[$i]->set_id);
			$set_attribs->{ $$sets[$i]->set_id }{'data-max'} = $$setProblemCount[$i];
			push(@openSetCount, $$setProblemCount[$i]);
			$maxProblems = $$setProblemCount[$i] if ($$setProblemCount[$i] > $maxProblems);
		}
	}

	my @problemIDs;
	my $problem_attribs;

	for (my $i = 1; $i <= $maxProblems; $i++) {
		push(@problemIDs, $i);
		if ($i > $openSetCount[0]) {
			$problem_attribs->{$i}{style} = 'display:none;';
		}
	}

	return join(
		'',
		CGI::p($r->maketext(
			'Please choose the set name and problem number of the question which '
				. 'should have its incorrect attempt count reset.'
		)),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'ria_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			menu_attr  => { attributes => $set_attribs, dir => 'ltr', data_problems => 'ria_problem_id' }
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id                  => 'ria_problem_id',
			label_text          => $r->maketext('Problem Number'),
			values              => \@problemIDs,
			menu_attr           => { attributes => $problem_attribs },
			menu_container_attr => { class      => 'col-3' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('ria_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);
    my $problemID = $r->param('ria_problem_id');
    return "You need to input a Problem Number" unless
	($problemID);

    my $problem = $db->getUserProblem($userName, $setID, $problemID);

    return "There was an error accessing that problem." unless $problem;

    #set number of incorrect attempts to zero

    $problem->num_incorrect(0);

    $db->putUserProblem($problem);

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to make a problem worth double.
package WeBWorK::AchievementItems::DoubleProb;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "DoubleProb",
	name => x("Cupcake of Enlargement"),
	description => x("Causes a single homework problem to be worth twice as much."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
	my $self            = shift;
	my $sets            = shift;
	my $setProblemCount = shift;
	my $r               = shift;

	my @openSets;
	my $set_attribs;
	my @openSetCount;
	my $maxProblems = 0;

	#print open sets and javascript to mach second dropdown to number of
	#problems in each set

	for (my $i = 0; $i <= $#$sets; $i++) {
		if (between($$sets[$i]->open_date, $$sets[$i]->due_date) && $$sets[$i]->assignment_type eq "default") {
			push(@openSets, $$sets[$i]->set_id);
			$set_attribs->{ $$sets[$i]->set_id }{'data-max'} = $$setProblemCount[$i];
			push(@openSetCount, $$setProblemCount[$i]);
			$maxProblems = $$setProblemCount[$i] if ($$setProblemCount[$i] > $maxProblems);
		}
	}

	my @problemIDs;
	my $problem_attribs;

	for (my $i = 1; $i <= $maxProblems; $i++) {
		push(@problemIDs, $i);
		if ($i > $openSetCount[0]) {
			$problem_attribs->{$i}{style} = 'display:none;';
		}
	}

	return join(
		'',
		CGI::p(
			$r->maketext(
				'Please choose the set name and problem number of the question which should have its weight doubled.')
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'dbp_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			menu_attr  => { attributes => $set_attribs, dir => 'ltr', data_problems => 'dbp_problem_id' }
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id                  => 'dbp_problem_id',
			label_text          => $r->maketext('Problem Number'),
			values              => \@problemIDs,
			menu_attr           => { attributes => $problem_attribs },
			menu_container_attr => { class      => 'col-3' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('dbp_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);
    my $problemID = $r->param('dbp_problem_id');
    return "You need to input a Problem Number" unless
	($problemID);


    my $globalproblem = $db->getMergedProblem($userName, $setID,$problemID);
    my $problem = $db->getUserProblem($userName, $setID, $problemID);

    return "There was an error accessing that problem." unless $problem;

    #double value of problem

    $problem->value($globalproblem->value*2);
    $db->putUserProblem($problem);

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to give half credit on a single problem.
package WeBWorK::AchievementItems::HalfCreditProb;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "HalfCreditProb",
	name => x("Lesser Rod of Revelation"),
	description => x("Gives half credit on a single homework problem."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
	my $self            = shift;
	my $sets            = shift;
	my $setProblemCount = shift;
	my $r               = shift;

	my @openSets;
	my $set_attribs;
	my @openSetCount;
	my $maxProblems = 0;

	#print form with open sets and javasscript to have appropriate number
	# of items in second drop down

	for (my $i = 0; $i <= $#$sets; $i++) {
		if (between($$sets[$i]->open_date, $$sets[$i]->due_date) && $$sets[$i]->assignment_type eq "default") {
			push(@openSets, $$sets[$i]->set_id);
			$set_attribs->{ $$sets[$i]->set_id }{'data-max'} = $$setProblemCount[$i];
			push(@openSetCount, $$setProblemCount[$i]);
			$maxProblems = $$setProblemCount[$i] if ($$setProblemCount[$i] > $maxProblems);
		}
	}

	my @problemIDs;
	my $problem_attribs;

	for (my $i = 1; $i <= $maxProblems; $i++) {
		push(@problemIDs, $i);
		$problem_attribs->{$i}{style} = 'display:none;' if ($i > $openSetCount[0]);
	}

	return join(
		'',
		CGI::p(
			$r->maketext(
				'Please choose the set name and problem number of the question which should be given half credit.')
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'hcp_set_id',
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			label_text => $r->maketext('Set Name'),
			menu_attr  => { attributes => $set_attribs, dir => 'ltr', data_problems => 'hcp_problem_id' }
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id                  => 'hcp_problem_id',
			values              => \@problemIDs,
			label_text          => $r->maketext('Problem Number'),
			menu_attr           => { attributes => $problem_attribs },
			menu_container_attr => { class      => 'col-3' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('hcp_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);
    my $problemID = $r->param('hcp_problem_id');
    return "You need to input a Problem Number" unless
	($problemID);

    my $problem = $db->getUserProblem($userName, $setID, $problemID);

    return "There was an error accessing that problem." unless $problem;

    #Add .5 to grade with max of 1

    if ($problem->status < .5) {
	$problem->status($problem->status + .5);
    } else {
	$problem->status(1);
    }

    $db->putUserProblem($problem);

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to give half credit on all problems in a homework set.
package WeBWorK::AchievementItems::HalfCreditSet;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "HalfCreditSet",
	name => x("Lesser Tome of Enlightenment"),
	description => x("Gives half credit on every problem in a set."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;

    my @openSets;
    my @openSetCount;
    my $maxProblems=0;

    for (my $i=0; $i<=$#$sets; $i++) {
	push(@openSets,$$sets[$i]->set_id);
    }


	# print form with sets
	return join(
		'',
		CGI::p($r->maketext('Choose the set which you would like to resurrect.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'hcs_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			menu_attr  => { dir => 'ltr' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('hcs_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    # go through the problems in the set
    my @probIDs = $db->listUserProblems($userName,$setID);

    foreach my $probID (@probIDs) {
	my $problem = $db->getUserProblem($userName, $setID, $probID);

	return "There was an error accessing that problem." unless $problem;

	#Add .5 to grade with max of 1

	if ($problem->status < .5) {
	    $problem->status($problem->status + .5);
	} else {
	    $problem->status(1);
	}

	$db->putUserProblem($problem);
    }

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to give full credit on a single problem
package WeBWorK::AchievementItems::FullCreditProb;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "FullCreditProb",
	name => x("Greater Rod of Revelation"),
	description => x("Gives full credit on a single homework problem."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
	my $self            = shift;
	my $sets            = shift;
	my $setProblemCount = shift;
	my $r               = shift;

	my @openSets;
	my $set_attribs;
	my @openSetCount;
	my $maxProblems = 0;

	#print form getting set and problem number

	for (my $i = 0; $i <= $#$sets; $i++) {
		if (between($$sets[$i]->open_date, $$sets[$i]->due_date) && $$sets[$i]->assignment_type eq "default") {
			push(@openSets, $$sets[$i]->set_id);
			$set_attribs->{ $$sets[$i]->set_id }{'data-max'} = $$setProblemCount[$i];
			push(@openSetCount, $$setProblemCount[$i]);
			$maxProblems = $$setProblemCount[$i] if ($$setProblemCount[$i] > $maxProblems);
		}
	}

	my @problemIDs;
	my $problem_attribs;

	for (my $i = 1; $i <= $maxProblems; $i++) {
		push(@problemIDs, $i);
		if ($i > $openSetCount[0]) {
			$problem_attribs->{$i}{style} = 'display:none;' if ($i > $openSetCount[0]);
		}
	}

	return join(
		'',
		CGI::p(
			$r->maketext(
				'Please choose the set name and problem number of the question which should be given full credit.')
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'fcp_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			menu_attr  => { attributes => $set_attribs, dir => 'ltr', data_problems => 'fcp_problem_id' }
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id                  => 'fcp_problem_id',
			values              => \@problemIDs,
			label_text          => $r->maketext('Problem Number'),
			menu_attr           => { attributes => $problem_attribs },
			menu_container_attr => { class      => 'col-3' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('fcp_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);
    my $problemID = $r->param('fcp_problem_id');
    return "You need to input a Problem Number" unless
	($problemID);

    my $problem = $db->getUserProblem($userName, $setID, $problemID);

    return "There was an error accessing that problem." unless $problem;

    #set status of the file to one.

    $problem->status(1);

    $db->putUserProblem($problem);

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to give half credit on all problems in a homework set.
package WeBWorK::AchievementItems::FullCreditSet;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "FullCreditSet",
	name => x("Greater Tome of Enlightenment"),
	description => x("Gives full credit on every problem in a set."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;

    my @openSets;
    my @openSetCount;
    my $maxProblems=0;

    for (my $i=0; $i<=$#$sets; $i++) {
	push(@openSets,$$sets[$i]->set_id);
    }


	# print form with sets
	return join(
		'',
		CGI::p($r->maketext('Choose the set which you would like to resurrect.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'fcs_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			menu_attr  => { dir => 'ltr' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('fcs_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);

    # go through the problems in the set
    my @probIDs = $db->listUserProblems($userName,$setID);

    foreach my $probID (@probIDs) {
	my $problem = $db->getUserProblem($userName, $setID, $probID);

	return "There was an error accessing that problem." unless $problem;

	# set status to 1
	$problem->status(1);

	$db->putUserProblem($problem);
    }

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to turn one problem into another problem
package WeBWorK::AchievementItems::DuplicateProb;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "DuplicateProb",
	name => x("Box of Transmogrification"),
	description => x("Causes a homework problem to become a clone of another problem from the same set."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
	my $self            = shift;
	my $sets            = shift;
	my $setProblemCount = shift;
	my $r               = shift;

	my @openSets;
	my $set_attribs;
	my @openSetCount;
	my $maxProblems = 0;

	# print open sets and allow for a choice of two problems from the set

	for (my $i = 0; $i <= $#$sets; $i++) {
		if (between($$sets[$i]->open_date, $$sets[$i]->due_date) && $$sets[$i]->assignment_type eq "default") {
			push(@openSets, $$sets[$i]->set_id);
			$set_attribs->{ $$sets[$i]->set_id }{'data-max'} = $$setProblemCount[$i];
			push(@openSetCount, $$setProblemCount[$i]);
			$maxProblems = $$setProblemCount[$i] if ($$setProblemCount[$i] > $maxProblems);
		}
	}

	my @problemIDs;
	my %attributes;

	for (my $i = 1; $i <= $maxProblems; $i++) {
		push(@problemIDs, $i);
		if ($i > $openSetCount[0]) {
			$attributes{$i}{style} = 'display:none;';
		}
	}

	return join(
		'',
		CGI::p($r->maketext(
			'Please choose the set, the problem you would like to copy, '
				. 'and the problem you would like to copy it to.'
		)),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'tran_set_id',
			label_text => $r->maketext('Set Name'),
			values     => \@openSets,
			labels     => { map { $_ => format_set_name_display($_) } @openSets },
			menu_attr  => {
				attributes     => $set_attribs,
				dir            => 'ltr',
				data_problems  => 'tran_problem_id',
				data_problems2 => 'tran_problem_id2'
			}
		),
		CGI::div(
			{ class => 'row mb-3' },
			WeBWorK::AchievementItems::form_popup_menu_row(
				id                  => 'tran_problem_id',
				values              => \@problemIDs,
				label_text          => $r->maketext('Copy this Problem'),
				menu_attr           => { attributes => \%attributes },
				menu_container_attr => { class      => 'col-2 ps-0' },
				add_container       => 0
			),
			WeBWorK::AchievementItems::form_popup_menu_row(
				id                  => 'tran_problem_id2',
				values              => \@problemIDs,
				label_text          => $r->maketext('To this Problem'),
				menu_attr           => { attributes => \%attributes },
				menu_container_attr => { class      => 'col-2 ps-0' },
				add_container       => 0
			)
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data

    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('tran_set_id');
    return "You need to input a Set Name" unless
	(defined $setID);
    my $problemID = $r->param('tran_problem_id');
    return "You need to input a Problem Number" unless
	($problemID);
    my $problemID2 = $r->param('tran_problem_id2');
    return "You need to input a Problem Number" unless
	($problemID2);

    return "You need to pick 2 different problems!" if
	($problemID == $problemID2);

    my $problem = $db->getMergedProblem($userName, $setID, $problemID);
    my $problem2 = $db->getUserProblem($userName, $setID, $problemID2);

    return "There was an error accessing that problem." unless $problem;

    #set the source of the second problem to that of the first problem.

    $problem2->source_file($problem->source_file);

    $db->putUserProblem($problem2);

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to print a suprise message
package WeBWorK::AchievementItems::Surprise;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "Surprise",
	name => x("Mysterious Package (with Ribbons)"),
	description => x("What could be inside?"),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;

    # the form opens the file "suprise_message.txt" in the achievements
    # folder and then prints the contetnts of the file.

    my $sourceFilePath = $r->{ce}->{courseDirs}->{achievements}.'/surprise_message.txt';

    open MESSAGE, $sourceFilePath or return CGI::p($r->maketext("I couldn't find the file [ACHEVDIR]/surprise_message.txt!"));

    my @message = <MESSAGE>;

    return CGI::div(@message);

}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #doesn't do anything

    return;
}

#Item to allow students to take an addition test
package WeBWorK::AchievementItems::AddNewTestGW;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "AddNewTestGW",
	name => x("Oil of Cleansing"),
	description => x("Unlock an additional version of a Gateway Test.  If used before the close date of the Gateway Test this will allow you to generate a new version of the test."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;
    my $db = $r->db;

    my $userName = $r->param('user');
    my $effectiveUserName = defined($r->param('effectiveUser') ) ? $r->param('effectiveUser') : $userName;
    my @setIDs = $db->listUserSets($effectiveUserName);
    my @userSetIDs = map {[$effectiveUserName, $_]} @setIDs;
    my @unfilteredsets = $db->getMergedSets(@userSetIDs);
    my @sets;

    # we going to have to find the gateways for these achievements.
    # we don't want the versioned gateways though.
    foreach my $set (@unfilteredsets) {
	if ($set->assignment_type() =~ /gateway/ &&
	    $set->set_id !~ /,v\d+$/) {
	    push @sets, $set;
	}
    }

    # now we need to find out which gateways are open
    my @openGateways;

    foreach my $set (@sets) {
	if (between($set->open_date, $set->due_date)) {
	    push @openGateways, $set->set_id;
	}
    }

    #print open gateways in a drop down.

	return join(
		'',
		CGI::p($r->maketext('Add a new test for which Gateway?')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'adtgw_gw_id',
			label_text => $r->maketext('Gateway Name'),
			values     => \@openGateways,
			labels     => { map { $_ => format_set_name_display($_) } @openGateways },
			menu_attr  => { dir => 'ltr' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('adtgw_gw_id');
    return "You need to input a Gateway Name" unless
	(defined $setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);

    my $userSet = $db->getUserSet($userName,$setID);

    $userSet->versions_per_interval($set->versions_per_interval()+1)
      unless ($set->versions_per_interval() == 0);

    $db->putUserSet($userSet);

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);



    return;
}

#Item to extend the due date on a gateway
package WeBWorK::AchievementItems::ExtendDueDateGW;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "ExtendDueDateGW",
	name => x("Amulet of Extension"),
	description => x("Extends the close date of a gateway test by 24 hours. Note: The test must still be open for this to work."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;
    my $db = $r->db;

    my $userName = $r->param('user');
    my $effectiveUserName = defined($r->param('effectiveUser') ) ? $r->param('effectiveUser') : $userName;
    my @setIDs = $db->listUserSets($effectiveUserName);
    my @userSetIDs = map {[$effectiveUserName, $_]} @setIDs;
    my @unfilteredsets = $db->getMergedSets(@userSetIDs);
    my @sets;

    # we going to have to find the gateways for these achievements.
    # we don't want the versioned gateways though.
    foreach my $set (@unfilteredsets) {
	if ($set->assignment_type() =~ /gateway/ &&
	    $set->set_id !~ /,v\d+$/) {
	    push @sets, $set;
	}
    }

    # now we need to find out which gateways are open
    my @openGateways;

    foreach my $set (@sets) {
	if (between($set->open_date, $set->due_date)) {
	    push @openGateways, $set->set_id;
	}
    }

    # Print open gateways in a drop down.
	return join(
		'',
		CGI::p($r->maketext('Extend the close date for which Gateway?')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'eddgw_gw_id',
			label_text => $r->maketext('Gateway Name'),
			values     => \@openGateways,
			labels     => { map { $_ => format_set_name_display($_) } @openGateways },
			menu_attr  => { dir => 'ltr' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('eddgw_gw_id');
    return "You need to input a Gateway Name" unless
	(defined $setID);

    my $set = $db->getMergedSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);
    my $userSet = $db->getUserSet($userName,$setID);

    #add time to the reduced scoring date, due date, and answer date
    $userSet->reduced_scoring_date($set->reduced_scoring_date()+86400) if defined($set->reduced_scoring_date()) && $set->reduced_scoring_date();
    $userSet->due_date($set->due_date()+86400);
    $userSet->answer_date($set->answer_date()+86400);

    $db->putUserSet($userSet);

    #add time to the reduced scoring date, due date, and answer date of various versions
    my @versions = $db->listSetVersions($userName,$setID);

    foreach my $version (@versions) {

	$set = $db->getSetVersion($userName,$setID,$version);
	$set->reduced_scoring_date($set->reduced_scoring_date()+86400) if defined($set->reduced_scoring_date()) && $set->reduced_scoring_date();
	$set->due_date($set->due_date()+86400);
	$set->answer_date($set->answer_date()+86400);
	$db->putSetVersion($set);

    }

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}

#Item to extend the due date on a gateway
package WeBWorK::AchievementItems::ResurrectGW;
our @ISA = qw(WeBWorK::AchievementItems);

use WeBWorK::Utils qw(sortByName before after between x nfreeze_base64 thaw_base64 format_set_name_display);

sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
	id => "ResurrectGW",
	name => x("Necromancers Charm"),
	description => x("Reopens any gateway test for an additional 24 hours. This allows you to take a test even if the close date has past. This item does not allow you to take additional versions of the test."),
	%options,
    };

    bless($self, $class);
    return $self;
}

sub print_form {
    my $self = shift;
    my $sets = shift;
    my $setProblemCount = shift;
    my $r = shift;
    my $db = $r->db;

    my $userName = $r->param('user');
    my $effectiveUserName = defined($r->param('effectiveUser') ) ? $r->param('effectiveUser') : $userName;
    my @setIDs = $db->listUserSets($effectiveUserName);
    my @userSetIDs = map {[$effectiveUserName, $_]} @setIDs;
    my @unfilteredsets = $db->getMergedSets(@userSetIDs);
    my @sets;

    # we going to have to find the gateways for these achievements.
    foreach my $set (@unfilteredsets) {
	if ($set->assignment_type() =~ /gateway/ &&
	    $set->set_id !~ /,v\d+$/) {
	    push @sets, $set->set_id;
	}
    }

    # Print gateways in a drop down.
	return join(
		'',
		CGI::p($r->maketext('Resurrect which Gateway?')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			id         => 'resgw_gw_id',
			label_text => $r->maketext('Gateway Name'),
			values     => \@sets,
			labels     => { map { $_ => format_set_name_display($_) } @sets },
			menu_attr  => { dir => 'ltr' }
		)
	);
}

sub use_item {
    my $self = shift;
    my $userName = shift;
    my $r = shift;
    my $db = $r->db;
    my $ce = $r->ce;

    #validate data
    my $globalUserAchievement = $db->getGlobalUserAchievement($userName);
    return "No achievement data?!?!?!"
	unless ($globalUserAchievement->frozen_hash);
    my $globalData = thaw_base64($globalUserAchievement->frozen_hash);

    return "You are $self->{id} trying to use an item you don't have" unless
	($globalData->{$self->{id}});

    my $setID = $r->param('resgw_gw_id');
    return "You need to input a Gateway Name" unless
	(defined $setID);

    my $set = $db->getUserSet($userName,$setID);
    return "Couldn't find that set!" unless
	($set);

    #add time to the reduced scoring date, due date, and answer date; remove item from inventory
    $set->reduced_scoring_date(time()+86400) if defined($set->reduced_scoring_date()) && $set->reduced_scoring_date();
    $set->due_date(time()+86400);
    $set->answer_date(time()+86400);

    $db->putUserSet($set);

    $globalData->{$self->{id}}--;
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return;
}


1;
