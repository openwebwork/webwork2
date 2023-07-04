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

package WeBWorK::ContentGenerator::Instructor::ProblemSetList;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetList - Entry point for Set-specific
data editing/viewing

=cut

=for comment

What do we want to be able to do here?

filter sort edit publish import create delete

Filter what sets are shown:
	- none, all, selected
	- matching set_id, visible to students, hidden from students

Sort sets by:
	- set name
	- open date
	- due date
	- answer date
	- header files
	- visibility to students

Switch from view mode to edit mode:
    - showing all sets
	- showing listed sets
	- showing selected sets
Switch from edit mode to view and save changes
Switch from edit mode to view and abandon changes

Make sets visible to students (publish) or hidden from students (unpublish):
	- none, all, listed, selected

Import sets:
	- single or multiple
    - with set name (only for single)
	- assign to:
        - only the current user
		- all users

Export sets:
    - all, listed, selected

Score sets:
	- none, all, selected

Create a set with a given name
    - as new empty set or as duplicate of first selected

Delete sets:
	- none, selected

=cut

# FIXME: rather than having two types of boolean modes $editMode and $exportMode
# make one $mode variable that contains a string like "edit", "view", or "export"

use Mojo::File;

use WeBWorK::Debug;
use WeBWorK::Utils qw(timeToSec listFilesRecursive jitar_id_to_seq seq_to_jitar_id x
	format_set_name_internal format_set_name_display);
use WeBWorK::Utils::Instructor qw(assignSetToUser assignSetToAllUsers addProblemToSet);

use constant HIDE_SETS_THRESHOLD                   => 500;
use constant DEFAULT_VISIBILITY_STATE              => 1;
use constant DEFAULT_ENABLED_REDUCED_SCORING_STATE => 0;
use constant ONE_WEEK                              => 60 * 60 * 24 * 7;

use constant EDIT_FORMS   => [qw(save_edit cancel_edit)];
use constant VIEW_FORMS   => [qw(filter sort edit publish import export score create delete)];
use constant EXPORT_FORMS => [qw(save_export cancel_export)];

# Prepare the tab titles for translation by maketext
use constant FORM_TITLES => {
	save_edit     => x("Save Edit"),
	cancel_edit   => x("Cancel Edit"),
	filter        => x("Filter"),
	sort          => x("Sort"),
	edit          => x("Edit"),
	publish       => x("Publish"),
	import        => x("Import"),
	export        => x("Export"),
	score         => x("Score"),
	create        => x("Create"),
	delete        => x("Delete"),
	save_export   => x("Save Export"),
	cancel_export => x("Cancel Export")
};

use constant VIEW_FIELD_ORDER =>
	[qw(set_id problems users visible enable_reduced_scoring open_date reduced_scoring_date due_date answer_date)];
use constant EDIT_FIELD_ORDER =>
	[qw(set_id visible enable_reduced_scoring open_date reduced_scoring_date due_date answer_date)];
use constant EXPORT_FIELD_ORDER => [qw(set_id problems users)];

# permissions needed to perform a given action
use constant FORM_PERMS => {
	save_edit   => "modify_problem_sets",
	edit        => "modify_problem_sets",
	publish     => "modify_problem_sets",
	import      => "create_and_delete_problem_sets",
	export      => "modify_set_def_files",
	save_export => "modify_set_def_files",
	score       => "score_sets",
	create      => "create_and_delete_problem_sets",
	delete      => "create_and_delete_problem_sets",
};

# Note that these are the only fields that are ever shown on this page.
# The set_id is handle separately, and so is not in this list.
use constant FIELD_TYPES => {
	open_date              => 'date',
	reduced_scoring_date   => 'date',
	due_date               => 'date',
	answer_date            => 'date',
	visible                => 'check',
	enable_reduced_scoring => 'check'
};

sub pre_header_initialize ($c) {
	my $db         = $c->db;
	my $authz      = $c->authz;
	my $user       = $c->param('user');
	my $courseName = $c->stash('courseID');

	# Check permissions
	return unless $authz->hasPermissions($user, 'access_instructor_tools');

	# Get the list of global sets and the number of users and cache them for later use.
	$c->{allSetIDs}  = [ $db->listGlobalSets ];
	$c->{totalUsers} = $db->countUsers;

	if (defined $c->param('action') && $c->param('action') eq 'score' && $authz->hasPermissions($user, 'score_sets')) {
		my $scope = $c->param('action.score.scope');
		my @setsToScore;

		if ($scope eq 'none') {
			return;
		} elsif ($scope eq 'all') {
			@setsToScore = @{ $c->{allSetIDs} };
		} elsif ($scope eq 'visible') {
			@setsToScore = @{ $c->param('visibleSetIDs') };
		} elsif ($scope eq 'selected') {
			@setsToScore = $c->param('selected_sets');
		}

		return unless @setsToScore;

		$c->reply_with_redirect($c->systemLink(
			$c->url_for('instructor_scoring'),
			params => { scoreSelected => 'ScoreSelected', selectedSet => \@setsToScore }
		));
	}

	return;
}

sub initialize ($c) {
	my $db         = $c->db;
	my $ce         = $c->ce;
	my $authz      = $c->authz;
	my $courseName = $c->stash('courseID');
	my $setID      = $c->stash('setID');
	my $user       = $c->param('user');

	# Make sure these are defined for the templats.
	$c->stash->{fieldNames}  = VIEW_FIELD_ORDER();
	$c->stash->{formsToShow} = VIEW_FORMS();
	$c->stash->{formTitles}  = FORM_TITLES();
	$c->stash->{formPerms}   = FORM_PERMS();
	$c->stash->{fieldTypes}  = FIELD_TYPES();
	$c->stash->{sets}        = [];

	# Determine if the user has permisson to do anything here.
	return unless $authz->hasPermissions($user, 'access_instructor_tools');

	# Determine if edit mode or export mode is request, and check permissions for these modes.
	$c->{editMode} = $c->param("editMode") || 0;
	return if $c->{editMode} && !$authz->hasPermissions($user, 'modify_problem_sets');

	$c->{exportMode} = $c->param("exportMode") || 0;
	return if $c->{exportMode} && !$authz->hasPermissions($user, 'modify_set_def_files');

	if (defined $c->param("visible_sets")) {
		$c->{visibleSetIDs} = [ $c->param("visible_sets") ];
	} elsif (defined $c->param("no_visible_sets")) {
		$c->{visibleSetIDs} = [];
	} else {
		if (@{ $c->{allSetIDs} } > HIDE_SETS_THRESHOLD) {
			$c->{visibleSetIDs} = [];
		} else {
			$c->{visibleSetIDs} = $c->{allSetIDs};
		}
	}

	$c->{prevVisibleSetIDs} = $c->{visibleSetIDs};

	if (defined $c->param("selected_sets")) {
		$c->{selectedSetIDs} = [ $c->param("selected_sets") ];
	} else {
		$c->{selectedSetIDs} = [];
	}

	$c->{primarySortField}   = $c->param("primarySortField")   || "due_date";
	$c->{secondarySortField} = $c->param("secondarySortField") || "open_date";

	# Call action handler
	my $actionID = $c->param("action");
	$c->{actionID} = $actionID;
	if ($actionID) {
		unless (grep { $_ eq $actionID } @{ VIEW_FORMS() }, @{ EDIT_FORMS() }, @{ EXPORT_FORMS() }) {
			die $c->maketext("Action [_1] not found", $actionID);
		}
		# Check permissions
		if (not FORM_PERMS()->{$actionID} or $authz->hasPermissions($user, FORM_PERMS()->{$actionID})) {
			my $actionHandler = "${actionID}_handler";
			my ($success, $action_result) = $c->$actionHandler;
			if ($success) {
				$c->addgoodmessage($c->b($c->maketext('Result of last action performed: [_1]', $action_result)));
			} else {
				$c->addbadmessage($c->b($c->maketext('Result of last action performed: [_1]', $action_result)));
			}
		} else {
			$c->addbadmessage($c->maketext('You are not authorized to perform this action.'));
		}
	} else {
		$c->addgoodmessage($c->maketext("Please select action to be performed."));
	}

	$c->stash->{fieldNames} =
		$c->{editMode} ? EDIT_FIELD_ORDER() : $c->{exportMode} ? EXPORT_FIELD_ORDER() : VIEW_FIELD_ORDER();
	if (!$c->ce->{pg}{ansEvalDefaults}{enableReducedScoring}) {
		$c->stash->{fieldNames} =
			[ grep { !/enable_reduced_scoring|reduced_scoring_date/ } @{ $c->stash->{fieldNames} } ];
	}

	$c->stash->{formsToShow} = $c->{editMode} ? EDIT_FORMS() : $c->{exportMode} ? EXPORT_FORMS() : VIEW_FORMS();
	# Get requested sets in the requested order.
	$c->stash->{sets} = [
		@{ $c->{visibleSetIDs} }
		? $db->getGlobalSetsWhere({ set_id => $c->{visibleSetIDs} },
			[ $c->{primarySortField}, $c->{secondarySortField} ])
		: ()
	];

	return;
}

# Action handlers
# The forms for the actions are templates.

# filter, edit, cancel_edit, and save_edit should stay with the display module and
# not be real "actions". That way, all actions are shown in view mode and no
# actions are shown in edit mode.

# This action handler modifies the "visibleSetIDs" field based on the contents
# of the "action.filter.scope" parameter and the "selected_sets".
sub filter_handler ($c) {
	my $db = $c->db;

	my $result;

	my $scope = $c->param('action.filter.scope');

	if ($scope eq "all") {
		$result = $c->maketext("showing all sets");
		$c->{visibleSetIDs} = $c->{allSetIDs};
	} elsif ($scope eq "none") {
		$result = $c->maketext("showing no sets");
		$c->{visibleSetIDs} = [];
	} elsif ($scope eq "selected") {
		$result = $c->maketext("showing selected sets");
		$c->{visibleSetIDs} = [ $c->param('selected_sets') ];
	} elsif ($scope eq "match_ids") {
		$result = $c->maketext("showing matching sets");
		my @searchTerms = map { format_set_name_internal($_) } split /\s*,\s*/, $c->param('action.filter.set_ids');
		my $regexTerms  = join('|', @searchTerms);
		my @setIDs      = grep {/$regexTerms/i} @{ $c->{allSetIDs} };
		$c->{visibleSetIDs} = \@setIDs;
	} elsif ($scope eq "visible") {
		$result = $c->maketext("showing sets that are visible to students");
		$c->{visibleSetIDs} = [ map { $_->[0] } $db->listGlobalSetsWhere({ visible => 1 }) ];
	} elsif ($scope eq "unvisible") {
		$result = $c->maketext("showing sets that are hidden from students");
		$c->{visibleSetIDs} = [ map { $_->[0] } $db->listGlobalSetsWhere({ visible => 0 }) ];
	}

	return (1, $result);
}

sub sort_handler ($c) {
	my $primary   = $c->param('action.sort.primary');
	my $secondary = $c->param('action.sort.secondary');

	$c->{primarySortField}   = $primary;
	$c->{secondarySortField} = $secondary;

	my %names = (
		set_id      => $c->maketext("Set Name"),
		open_date   => $c->maketext("Open Date"),
		due_date    => $c->maketext("Close Date"),
		answer_date => $c->maketext("Answer Date"),
		visible     => $c->maketext("Visibility"),
	);

	return (1, $c->maketext("Sort by [_1] and then by [_2]", $names{$primary}, $names{$secondary}));
}

sub edit_handler ($c) {
	my $result;

	my $scope = $c->param('action.edit.scope');
	if ($scope eq "all") {
		$result = $c->maketext("editing all sets");
		$c->{visibleSetIDs} = $c->{allSetIDs};
	} elsif ($scope eq "visible") {
		$result = $c->maketext("editing listed sets");
		# leave visibleSetIDs alone
	} elsif ($scope eq "selected") {
		$result = $c->maketext("editing selected sets");
		$c->{visibleSetIDs} = [ $c->param('selected_sets') ];
	}
	$c->{editMode} = 1;

	return (1, $result);
}

sub publish_handler ($c) {
	my $db = $c->db;

	my @result;

	my $scope = $c->param('action.publish.scope');
	my $value = $c->param('action.publish.value');

	my @setIDs;

	if ($scope eq "none") {
		@setIDs = ();
		@result = (0, $c->maketext("No change made to any set"));
	} elsif ($scope eq "all") {
		@setIDs = @{ $c->{allSetIDs} };
		@result =
			$value
			? (1, $c->maketext("All sets made visible for all students"))
			: (1, $c->maketext("All sets hidden from all students"));
	} elsif ($scope eq "visible") {
		@setIDs = @{ $c->{visibleSetIDs} };
		@result =
			$value
			? (1, $c->maketext("All listed sets were made visible for all the students"))
			: (1, $c->maketext("All listed sets were hidden from all the students"));
	} elsif ($scope eq "selected") {
		@setIDs = $c->param('selected_sets');
		@result =
			$value
			? (1, $c->maketext("All selected sets made visible for all students"))
			: (1, $c->maketext("All selected sets hidden from all students"));
	}

	# Can we use UPDATE here, instead of fetch/change/store?
	my @sets = $db->getGlobalSets(@setIDs);
	map { $_->visible($value); $db->putGlobalSet($_); } @sets;

	return @result;
}

sub score_handler ($c) {
	# The only time this is called is if "no sets" is selected (do we really need that option),
	# or one of the other options was selected but there were no sets to score.
	return (0, $c->maketext('No sets selected for scoring.'));
}

sub delete_handler ($c) {
	my $db = $c->db;

	my $scope = $c->param('action.delete.scope');

	my @setIDsToDelete = ();

	if ($scope eq "selected") {
		@setIDsToDelete = @{ $c->{selectedSetIDs} };
	}

	my %allSetIDs      = map { $_ => 1 } @{ $c->{allSetIDs} };
	my %visibleSetIDs  = map { $_ => 1 } @{ $c->{visibleSetIDs} };
	my %selectedSetIDs = map { $_ => 1 } @{ $c->{selectedSetIDs} };

	foreach my $setID (@setIDsToDelete) {
		delete $allSetIDs{$setID};
		delete $visibleSetIDs{$setID};
		delete $selectedSetIDs{$setID};
		$db->deleteGlobalSet($setID);
	}

	$c->{allSetIDs}      = [ keys %allSetIDs ];
	$c->{visibleSetIDs}  = [ keys %visibleSetIDs ];
	$c->{selectedSetIDs} = [ keys %selectedSetIDs ];

	my $num = @setIDsToDelete;
	return (1, $c->maketext('deleted [_1] sets', $num));
}

sub create_handler ($c) {
	my $db = $c->db;
	my $ce = $c->ce;

	my $newSetID = format_set_name_internal($c->param('action.create.name') // '');
	return (0, $c->maketext("Failed to create new set: Set name cannot exceed 100 characters."))
		if (length($newSetID) > 100);
	return (0, $c->maketext("Failed to create new set: No set name specified.")) unless $newSetID =~ /\S/;
	return (
		0,
		$c->maketext(
			'Failed to create new set: Invalid characters in set name "[_1]". '
				. 'A set name may only contain letters, numbers, hyphens, periods, and spaces.',
			$newSetID =~ s/_/ /gr
		)
	) unless $newSetID =~ m/^[-a-zA-Z0-9_.]*$/;
	return (
		0,
		$c->maketext(
			'The set name "[_1]" is already in use. Pick a different name if you would like to start a new set. '
				. 'No set created.',
			$newSetID
		)
	) if $db->existsGlobalSet($newSetID);

	my $newSetRecord = $db->newGlobalSet;
	my $oldSetID     = $c->{selectedSetIDs}->[0];

	my $type = $c->param('action.create.type');
	# It's convenient to set the due date two weeks from now so that it is
	# not accidentally available to students.

	my $dueDate    = time + 2 * ONE_WEEK();
	my $display_tz = $ce->{siteDefaults}{timezone};
	my $fDueDate   = $c->formatDateTime($dueDate, $display_tz, "%m/%d/%Y at %I:%M%P");
	my $dueTime    = $ce->{pg}{timeAssignDue};

	# We replace the due time by the one from the config variable
	# and try to bring it back to unix time if possible
	$fDueDate =~ s/\d\d:\d\d(am|pm|AM|PM)/$dueTime/;

	$dueDate = $c->parseDateTime($fDueDate, $display_tz);

	if ($type eq "empty") {
		$newSetRecord->set_id($newSetID);
		$newSetRecord->set_header("defaultHeader");
		$newSetRecord->hardcopy_header("defaultHeader");
		#Rest of the dates are set according to to course configuration
		$newSetRecord->open_date($dueDate - 60 * $ce->{pg}{assignOpenPriorToDue});
		$newSetRecord->reduced_scoring_date($dueDate - 60 * $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod});
		$newSetRecord->due_date($dueDate);
		$newSetRecord->answer_date($dueDate + 60 * $ce->{pg}{answersOpenAfterDueDate});
		$newSetRecord->visible(DEFAULT_VISIBILITY_STATE());    # don't want students to see an empty set
		$newSetRecord->enable_reduced_scoring(DEFAULT_ENABLED_REDUCED_SCORING_STATE());
		$newSetRecord->assignment_type('default');
		$db->addGlobalSet($newSetRecord);
	} elsif ($type eq "copy") {
		return (0, $c->maketext('Failed to duplicate set: no set selected for duplication!')) unless $oldSetID =~ /\S/;
		$newSetRecord = $db->getGlobalSet($oldSetID);
		$newSetRecord->set_id($newSetID);
		$db->addGlobalSet($newSetRecord);

		# take all the problems from the old set and make them part of the new set
		foreach ($db->getAllGlobalProblems($oldSetID)) {
			$_->set_id($newSetID);
			$db->addGlobalProblem($_);
		}

		# also copy any set_location restrictions and set-level proctor
		#    information
		foreach ($db->getAllGlobalSetLocations($oldSetID)) {
			$_->set_id($newSetID);
			$db->addGlobalSetLocation($_);
		}
		if ($newSetRecord->restricted_login_proctor eq 'Yes') {
			my $procUser = $db->getUser("set_id:$oldSetID");
			$procUser->user_id("set_id:$newSetID");
			eval { $db->addUser($procUser) };
			if (!$@) {
				my $procPerm = $db->getPermissionLevel("set_id:$oldSetID");
				$procPerm->user_id("set_id:$newSetID");
				$db->addPermissionLevel($procPerm);
				my $procPass = $db->getPassword("set_id:$oldSetID");
				$procPass->user_id("set_id:$newSetID");
				$db->addPassword($procPass);
			}
		}
	}
	# Assign set to current active user.
	my $userName = $c->param('user');
	assignSetToUser($db, $userName, $newSetRecord);    # Cures weird date error when no-one assigned to set.
	$c->addgoodmessage($c->maketext(
		'Set [_1] was assigned to [_2].',
		$c->tag('span', dir => 'ltr', format_set_name_display($newSetID)), $userName
	));

	push @{ $c->{visibleSetIDs} }, $newSetID;
	push @{ $c->{allSetIds} },     $newSetID;

	return (0, $c->maketext('Failed to create new set: [_1]', $@)) if $@;

	return (
		1,
		$c->b($c->maketext(
			'Successfully created new set [_1]',
			$c->tag('span', dir => 'ltr', format_set_name_display($newSetID))
		))
	);
}

sub import_handler ($c) {
	my ($added, $skipped) = $c->importSetsFromDef(
		$c->param('action.import.number') > 1
		? ''    # Cannot assign set names to multiple imports.
		: format_set_name_internal($c->param('action.import.name')),
		$c->param('action.import.assign'),
		$c->param('action.import.start.date') // 0,
		$c->param('action.import.source')
	);

	# Make new sets visible.
	push @{ $c->{visibleSetIDs} }, @$added;
	push @{ $c->{allSetIDs} },     @$added;

	my $numAdded   = @$added;
	my $numSkipped = @$skipped;

	return (
		1,
		$c->maketext(
			'[_1] sets added, [_2] sets skipped. Skipped sets: ([_3])', $numAdded,
			$numSkipped,                                                join(', ', @$skipped)
		)
	);
}

# this does not actually export any files, rather it sends us to a new page in order to export the files
sub export_handler ($c) {
	my $result;

	my $scope = $c->param('action.export.scope');
	if ($scope eq "all") {
		$result = $c->maketext("All sets were selected for export.");
		$c->{selectedSetIDs} = $c->{visibleSetIDs} = $c->{allSetIDs};
	} elsif ($scope eq "visible") {
		$result = $c->maketext("Visible sets were selected for export.");
		$c->{selectedSetIDs} = $c->{visibleSetIDs};
	} elsif ($scope eq "selected") {
		$result = $c->maketext("Sets were selected for export.");
		$c->{selectedSetIDs} = $c->{visibleSetIDs} = [ $c->param('selected_sets') ];
	}
	$c->{exportMode} = 1;

	return (1, $result);
}

sub cancel_export_handler ($c) {
	if (defined $c->param("prev_visible_sets")) {
		$c->{visibleSetIDs} = [ $c->param("prev_visible_sets") ];
	} elsif (defined $c->param("no_prev_visible_sets")) {
		$c->{visibleSetIDs} = [];
	} else {
		# leave it alone
	}
	$c->{exportMode} = 0;

	return (0, $c->maketext('export abandoned'));
}

sub save_export_handler ($c) {
	my @setIDsToExport = @{ $c->{selectedSetIDs} };

	my %filenames = map { $_ => ($c->param("set.$_") || $_) } @setIDsToExport;

	my ($exported, $skipped, $reason) = $c->exportSetsToDef(%filenames);

	if (defined $c->param("prev_visible_sets")) {
		$c->{visibleSetIDs} = [ $c->param("prev_visible_sets") ];
	} elsif (defined $c->param("no_prev_visble_sets")) {
		$c->{visibleSetIDs} = [];
	}

	$c->{exportMode} = 0;

	my $numExported = @$exported;
	my $numSkipped  = @$skipped;

	my @reasons = map { "set $_ - " . $reason->{$_} } keys %$reason;

	return (
		!$numSkipped,
		$c->b($c->maketext(
			'[_1] sets exported, [_2] sets skipped. Skipped sets: ([_3])',
			$numExported, $numSkipped,
			$numSkipped ? $c->tag('ul', $c->c(map { $c->tag('li', $_) } @reasons)->join('')) : ''
		))
	);
}

sub cancel_edit_handler ($c) {
	if (defined $c->param("prev_visible_sets")) {
		$c->{visibleSetIDs} = [ $c->param("prev_visible_sets") ];
	} elsif (defined $c->param("no_prev_visible_sets")) {
		$c->{visibleSetIDs} = [];
	} else {
		# leave it alone
	}
	$c->{editMode} = 0;

	return (0, $c->maketext('changes abandoned'));
}

sub save_edit_handler ($c) {
	my $db = $c->db;
	my $ce = $c->ce;

	my @visibleSetIDs = @{ $c->{visibleSetIDs} };
	foreach my $setID (@visibleSetIDs) {
		next unless defined($setID);
		my $Set = $db->getGlobalSet($setID);
		# FIXME: we may not want to die on bad sets, they're not as bad as bad users
		die "record for visible set $setID not found" unless $Set;

		foreach my $field ($Set->NONKEYFIELDS()) {
			my $value = $c->param("set.$setID.$field");
			if (defined $value) {
				if ($field =~ /_date/) {
					$Set->$field($value);
				} elsif ($field eq 'enable_reduced_scoring') {
					# If we are enableing reduced scoring, make sure the reduced scoring date
					# is set and in a proper interval.
					$Set->enable_reduced_scoring($value);
					if (!$Set->reduced_scoring_date) {
						$Set->reduced_scoring_date(
							$Set->due_date - 60 * $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod});
					}
				} else {
					$Set->$field($value);
				}
			}
		}

		# make sure the dates are not more than 10 years in the future
		my $curr_time        = time;
		my $seconds_per_year = 31_556_926;
		my $cutoff           = $curr_time + $seconds_per_year * 10;
		return (0, $c->maketext("Error: open date cannot be more than 10 years from now in set [_1]", $setID))
			if $Set->open_date > $cutoff;
		return (0, $c->maketext("Error: close date cannot be more than 10 years from now in set [_1]", $setID))
			if $Set->due_date > $cutoff;
		return (0, $c->maketext("Error: answer date cannot be more than 10 years from now in set [_1]", $setID))
			if $Set->answer_date > $cutoff;

		# Check that the open, due and answer dates are in increasing order.
		# Bail if this is not correct.
		if ($Set->open_date > $Set->due_date) {
			return (0, $c->maketext("Error: Close date must come after open date in set [_1]", $setID));
		}
		if ($Set->due_date > $Set->answer_date) {
			return (0, $c->maketext("Error: Answer date must come after close date in set [_1]", $setID));
		}

		# check that the reduced scoring date is in the right place
		my $enable_reduced_scoring = $ce->{pg}{ansEvalDefaults}{enableReducedScoring}
			&& (
				defined($c->param("set.$setID.enable_reduced_scoring"))
				? $c->param("set.$setID.enable_reduced_scoring")
				: $Set->enable_reduced_scoring);

		if (
			$enable_reduced_scoring
			&& $Set->reduced_scoring_date
			&& ($Set->reduced_scoring_date > $Set->due_date
				|| $Set->reduced_scoring_date < $Set->open_date)
			)
		{
			return (
				0,
				$c->maketext(
					"Error: Reduced scoring date must come between the open date and close date in set [_1]",
					$setID
				)
			);
		}

		$db->putGlobalSet($Set);
	}

	if (defined $c->param("prev_visible_sets")) {
		$c->{visibleSetIDs} = [ $c->param("prev_visible_sets") ];
	} elsif (defined $c->param("no_prev_visble_sets")) {
		$c->{visibleSetIDs} = [];
	} else {
		# leave it alone
	}

	$c->{editMode} = 0;

	return (1, $c->maketext("changes saved"));
}

# Utilities

sub importSetsFromDef ($c, $newSetName, $assign, $startdate, @setDefFiles) {
	my $ce      = $c->ce;
	my $db      = $c->db;
	my $dir     = $ce->{courseDirs}{templates};
	my $mindate = 0;

	# If the user includes "following files" in a multiple selection
	# it shows up here as "" which causes the importing to die.
	# So, we select on filenames containing non-whitespace.
	@setDefFiles = grep {/\S/} @setDefFiles;

	# FIXME: do we really want everything to fail on one bad file name?
	foreach my $fileName (@setDefFiles) {
		die $c->maketext("won't be able to read from file [_1]/[_2]: does it exist? is it readable?", $dir, $fileName)
			unless -r "$dir/$fileName";
	}

	# Get a list of set ids of existing sets in the course.  This is used to
	# ensure that an imported set does not already exist.
	my %allSets = map { $_ => 1 } @{ $c->{allSetIDs} };

	my (@added, @skipped);

	foreach my $set_definition_file (@setDefFiles) {

		debug("$set_definition_file: reading set definition file");
		# read data in set definition file
		my (
			$setName,              $paperHeaderFile,    $screenHeaderFile,   $openDate,
			$dueDate,              $answerDate,         $ra_problemData,     $assignmentType,
			$enableReducedScoring, $reducedScoringDate, $attemptsPerVersion, $timeInterval,
			$versionsPerInterval,  $versionTimeLimit,   $problemRandOrder,   $problemsPerPage,
			$hideScore,            $hideScoreByProblem, $hideWork,           $timeCap,
			$restrictIP,           $restrictLoc,        $relaxRestrictIP,    $description,
			$emailInstructor,      $restrictProbProgression
		) = $c->readSetDef($set_definition_file);
		my @problemList = @{$ra_problemData};

		# Use the original name if form doesn't specify a new one.
		# The set acquires the new name specified by the form.  A blank
		# entry on the form indicates that the imported set name will be used.
		$setName = $newSetName if $newSetName;

		if ($allSets{$setName}) {
			# this set already exists!!
			push @skipped, $setName;
			next;
		} else {
			push @added, $setName;
		}

		# keep track of which as the earliest answer date
		if ($mindate > $openDate || $mindate == 0) {
			$mindate = $openDate;
		}

		debug("$set_definition_file: adding set");
		# add the data to the set record
		my $newSetRecord = $db->newGlobalSet;
		$newSetRecord->set_id($setName);
		$newSetRecord->set_header($screenHeaderFile);
		$newSetRecord->hardcopy_header($paperHeaderFile);
		$newSetRecord->open_date($openDate);
		$newSetRecord->due_date($dueDate);
		$newSetRecord->answer_date($answerDate);
		$newSetRecord->visible(DEFAULT_VISIBILITY_STATE);
		$newSetRecord->reduced_scoring_date($reducedScoringDate);
		$newSetRecord->enable_reduced_scoring($enableReducedScoring);
		$newSetRecord->description($description);
		$newSetRecord->email_instructor($emailInstructor);
		$newSetRecord->restrict_prob_progression($restrictProbProgression);

		# gateway/version data.  these should are all initialized to ''
		# by readSetDef, so for non-gateway/versioned sets they'll just
		# be stored as null
		$newSetRecord->assignment_type($assignmentType);
		$newSetRecord->attempts_per_version($attemptsPerVersion);
		$newSetRecord->time_interval($timeInterval);
		$newSetRecord->versions_per_interval($versionsPerInterval);
		$newSetRecord->version_time_limit($versionTimeLimit);
		$newSetRecord->problem_randorder($problemRandOrder);
		$newSetRecord->problems_per_page($problemsPerPage);
		$newSetRecord->hide_score($hideScore);
		$newSetRecord->hide_score_by_problem($hideScoreByProblem);
		$newSetRecord->hide_work($hideWork);
		$newSetRecord->time_limit_cap($timeCap);
		$newSetRecord->restrict_ip($restrictIP);
		$newSetRecord->relax_restrict_ip($relaxRestrictIP);

		#create the set
		eval { $db->addGlobalSet($newSetRecord) };
		die $c->maketext("addGlobalSet [_1] in ProblemSetList:  [_2]", $setName, $@) if $@;

		#do we need to add locations to the set_locations table?
		if ($restrictIP ne 'No' && $restrictLoc) {
			if ($db->existsLocation($restrictLoc)) {
				if (!$db->existsGlobalSetLocation($setName, $restrictLoc)) {
					my $newSetLocation = $db->newGlobalSetLocation;
					$newSetLocation->set_id($setName);
					$newSetLocation->location_id($restrictLoc);
					eval { $db->addGlobalSetLocation($newSetLocation) };
					warn($c->maketext(
						"error adding set location [_1] for set [_2]: [_3]",
						$restrictLoc, $setName, $@
					))
						if $@;
				} else {
					# this should never happen.
					warn(
						$c->maketext(
							"input set location [_1] already exists for set [_2].", $restrictLoc, $setName
							)
							. "\n"
					);
				}
			} else {
				warn(
					$c->maketext("restriction location [_1] does not exist.  IP restrictions have been ignored.",
						$restrictLoc)
						. "\n"
				);
				$newSetRecord->restrict_ip('No');
				$newSetRecord->relax_restrict_ip('No');
				eval { $db->putGlobalSet($newSetRecord) };
				# we ignore error messages here; if the set
				#    added without error before, we assume
				#    (ha) that it will put without trouble
			}
		}

		debug("$set_definition_file: adding problems to database");
		# add problems
		my $freeProblemID = WeBWorK::Utils::max($db->listGlobalProblems($setName)) + 1;
		foreach my $rh_problem (@problemList) {
			addProblemToSet(
				$db, $ce->{problemDefaults},
				setName           => $setName,
				sourceFile        => $rh_problem->{source_file},
				problemID         => $rh_problem->{problemID} ? $rh_problem->{problemID} : $freeProblemID++,
				value             => $rh_problem->{value},
				maxAttempts       => $rh_problem->{max_attempts},
				showMeAnother     => $rh_problem->{showMeAnother},
				showHintsAfter    => $rh_problem->{showHintsAfter},
				prPeriod          => $rh_problem->{prPeriod},
				attToOpenChildren => $rh_problem->{attToOpenChildren},
				countsParentGrade => $rh_problem->{countsParentGrade}
			);
		}

		if ($assign eq "all") {
			assignSetToAllUsers($db, $ce, $setName);
		} else {
			my $userName = $c->param('user');
			assignSetToUser($db, $userName, $newSetRecord);    ## always assign set to instructor
		}
	}

	#if there is a start date we have to reopen all of the sets that were added and shift the dates
	if ($startdate) {
		#the shift for all of the dates is from the min date to the start date
		my $dateshift = $startdate - $mindate;

		foreach my $setID (@added) {
			my $setRecord = $db->getGlobalSet($setID);
			$setRecord->open_date($setRecord->open_date + $dateshift);
			$setRecord->reduced_scoring_date($setRecord->reduced_scoring_date + $dateshift);
			$setRecord->due_date($setRecord->due_date + $dateshift);
			$setRecord->answer_date($setRecord->answer_date + $dateshift);
			$db->putGlobalSet($setRecord);
		}
	}

	return \@added, \@skipped;
}

sub readSetDef ($c, $fileName) {
	my $ce                           = $c->ce;
	my $templateDir                  = $ce->{courseDirs}{templates};
	my $filePath                     = "$templateDir/$fileName";
	my $weight_default               = $ce->{problemDefaults}{value};
	my $max_attempts_default         = $ce->{problemDefaults}{max_attempts};
	my $att_to_open_children_default = $ce->{problemDefaults}{att_to_open_children};
	my $counts_parent_grade_default  = $ce->{problemDefaults}{counts_parent_grade};
	my $showMeAnother_default        = $ce->{problemDefaults}{showMeAnother};
	my $showHintsAfter_default       = $ce->{problemDefaults}{showHintsAfter};
	my $prPeriod_default             = $ce->{problemDefaults}{prPeriod};

	my $setName = '';

	if ($fileName =~ m|^(.*/)?set([.\w-]+)\.def$|) {
		$setName = $2;
	} else {
		$c->addbadmessage(
			qq{The setDefinition file name must begin with <strong>set</strong> and must end with },
			qq{<strong>.def</strong>. Every thing in between becomes the name of the set. For example },
			qq{<strong>set1.def</strong>, <strong>setExam.def</strong>, and <strong>setsample7.def</strong> define },
			qq{sets named <strong>1</strong>, <strong>Exam</strong>, and <strong>sample7</strong> respectively. },
			qq{The filename "$fileName" you entered is not legal\n }
		);

	}

	my ($name, $weight, $attemptLimit, $continueFlag);
	my $paperHeaderFile  = '';
	my $screenHeaderFile = '';
	my $description      = '';
	my ($dueDate, $openDate, $reducedScoringDate, $answerDate);
	my @problemData;

	# added fields for gateway test/versioned set definitions:
	my (
		$assignmentType,      $attemptsPerVersion, $timeInterval,            $enableReducedScoring,
		$versionsPerInterval, $versionTimeLimit,   $problemRandOrder,        $problemsPerPage,
		$restrictLoc,         $emailInstructor,    $restrictProbProgression, $countsParentGrade,
		$attToOpenChildren,   $problemID,          $showMeAnother,           $showHintsAfter,
		$prPeriod,            $listType
	) = ('') x 18;    # initialize these to ''
	my ($timeCap, $restrictIP, $relaxRestrictIP) = (0, 'No', 'No');
	# additional fields currently used only by gateways; later, the world?
	my ($hideScore, $hideScoreByProblem, $hideWork,) = ('N', 'N', 'N');

	my %setInfo;
	if (my $SETFILENAME = Mojo::File->new($filePath)->open('<')) {
		# Read and check set data
		while (my $line = <$SETFILENAME>) {

			chomp $line;
			$line =~ s|(#.*)||;                  # Don't read past comments
			unless ($line =~ /\S/) { next; }     # Skip blank lines
			$line =~ s|\s*$||;                   # Trim trailing spaces
			$line =~ m|^\s*(\w+)\s*=?\s*(.*)|;

			# Sanity check entries
			my $item = $1;
			$item = '' unless defined $item;
			my $value = $2;
			$value = '' unless defined $value;

			if ($item eq 'setNumber') {
				next;
			} elsif ($item eq 'paperHeaderFile') {
				$paperHeaderFile = $value;
			} elsif ($item eq 'screenHeaderFile') {
				$screenHeaderFile = $value;
			} elsif ($item eq 'dueDate') {
				$dueDate = $value;
			} elsif ($item eq 'openDate') {
				$openDate = $value;
			} elsif ($item eq 'answerDate') {
				$answerDate = $value;
			} elsif ($item eq 'enableReducedScoring') {
				$enableReducedScoring = $value;
			} elsif ($item eq 'reducedScoringDate') {
				$reducedScoringDate = $value;
			} elsif ($item eq 'assignmentType') {
				$assignmentType = $value;
			} elsif ($item eq 'attemptsPerVersion') {
				$attemptsPerVersion = $value;
			} elsif ($item eq 'timeInterval') {
				$timeInterval = $value;
			} elsif ($item eq 'versionsPerInterval') {
				$versionsPerInterval = $value;
			} elsif ($item eq 'versionTimeLimit') {
				$versionTimeLimit = $value;
			} elsif ($item eq 'problemRandOrder') {
				$problemRandOrder = $value;
			} elsif ($item eq 'problemsPerPage') {
				$problemsPerPage = $value;
			} elsif ($item eq 'hideScore') {
				$hideScore = ($value) ? $value : 'N';
			} elsif ($item eq 'hideScoreByProblem') {
				$hideScoreByProblem = ($value) ? $value : 'N';
			} elsif ($item eq 'hideWork') {
				$hideWork = ($value) ? $value : 'N';
			} elsif ($item eq 'capTimeLimit') {
				$timeCap = ($value) ? 1 : 0;
			} elsif ($item eq 'restrictIP') {
				$restrictIP = ($value) ? $value : 'No';
			} elsif ($item eq 'restrictLocation') {
				$restrictLoc = ($value) ? $value : '';
			} elsif ($item eq 'relaxRestrictIP') {
				$relaxRestrictIP = ($value) ? $value : 'No';
			} elsif ($item eq 'emailInstructor') {
				$emailInstructor = ($value) ? $value : 0;
			} elsif ($item eq 'restrictProbProgression') {
				$restrictProbProgression = ($value) ? $value : 0;
			} elsif ($item eq 'description') {
				$value =~ s/<n>/\n/g;
				$description = $value;
			} elsif ($item eq 'problemList'
				|| $item eq 'problemListV2')
			{
				$listType = $item;
				last;
			} else {
				warn $c->maketext("readSetDef error, can't read the line: ||[_1]||", $line);
			}
		}

		# Check and format dates
		my ($time1, $time2, $time3) = map { $c->parseDateTime($_); } ($openDate, $dueDate, $answerDate);

		unless ($time1 <= $time2 and $time2 <= $time3) {
			warn $c->maketext('The open date: [_1], close date: [_2], and answer date: [_3] '
					. 'must be defined and in chronological order.',
				$openDate, $dueDate, $answerDate);
		}

		# validate reduced credit date

		# Special handling for values which seem to roughly correspond to epoch 0.
		#    namely if the date string contains 12/31/1969 or 01/01/1970
		if ($reducedScoringDate) {
			if (($reducedScoringDate =~ m+12/31/1969+) || ($reducedScoringDate =~ m+01/01/1970+)) {
				my $origReducedScoringDate = $reducedScoringDate;
				$reducedScoringDate = $c->parseDateTime($reducedScoringDate);
				if ($reducedScoringDate != 0) {
					# In this case we want to treat it BY FORCE as if the value did correspond to epoch 0.
					warn $c->maketext(
						'The reduced credit date [_1] in the file probably was generated from '
							. 'the Unix epoch 0 value and is being treated as if it was Unix epoch 0.',
						$origReducedScoringDate
					);
					$reducedScoringDate = 0;
				}
			} else {
				# Original behavior, which may cause problems for some time-zones when epoch 0 was set and does not
				# parse back to 0.
				$reducedScoringDate = $c->parseDateTime($reducedScoringDate);
			}
		}

		if ($reducedScoringDate) {
			if ($reducedScoringDate < $time1 || $reducedScoringDate > $time2) {
				warn $c->maketext("The reduced credit date should be between the open date [_1] and close date [_2]",
					$openDate, $dueDate);
			} elsif ($reducedScoringDate == 0 && $enableReducedScoring ne 'Y') {
				# In this case - the date in the file was Unix epoch 0 (or treated as such),
				# and unless $enableReducedScoring eq 'Y' we will leave it as 0.
			}
		} else {
			$reducedScoringDate = $time2 - 60 * $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod};
		}

		if ($enableReducedScoring ne '' && $enableReducedScoring eq 'Y') {
			$enableReducedScoring = 1;
		} elsif ($enableReducedScoring ne '' && $enableReducedScoring eq 'N') {
			$enableReducedScoring = 0;
		} elsif ($enableReducedScoring ne '') {
			warn(
				$c->maketext("The value [_1] for enableReducedScoring is not valid; it will be replaced with 'N'.",
					$enableReducedScoring)
					. "\n"
			);
			$enableReducedScoring = 0;
		} else {
			$enableReducedScoring = DEFAULT_ENABLED_REDUCED_SCORING_STATE;
		}

		# Check header file names
		$paperHeaderFile  =~ s/(.*?)\s*$/$1/;    # Remove trailing white space
		$screenHeaderFile =~ s/(.*?)\s*$/$1/;    # Remove trailing white space

		# Gateway/version variable cleanup: convert times into seconds
		$assignmentType ||= 'default';

		$timeInterval = WeBWorK::Utils::timeToSec($timeInterval)
			if ($timeInterval);
		$versionTimeLimit = WeBWorK::Utils::timeToSec($versionTimeLimit)
			if ($versionTimeLimit);

		# Check that the values for hideWork and hideScore are valid.
		if ($hideScore ne 'N'
			&& $hideScore ne 'Y'
			&& $hideScore ne 'BeforeAnswerDate')
		{
			warn(
				$c->maketext("The value [_1] for the hideScore option is not valid; it will be replaced with 'N'.",
					$hideScore)
					. "\n"
			);
			$hideScore = 'N';
		}
		if ($hideScoreByProblem ne 'N'
			&& $hideScoreByProblem ne 'Y'
			&& $hideScoreByProblem ne 'BeforeAnswerDate')
		{
			warn(
				$c->maketext("The value [_1] for the hideScore option is not valid; it will be replaced with 'N'.",
					$hideScoreByProblem)
					. "\n"
			);
			$hideScoreByProblem = 'N';
		}
		if ($hideWork ne 'N'
			&& $hideWork ne 'Y'
			&& $hideWork ne 'BeforeAnswerDate')
		{
			warn(
				$c->maketext("The value [_1] for the hideWork option is not valid; it will be replaced with 'N'.",
					$hideWork)
					. "\n"
			);
			$hideWork = 'N';
		}
		if ($timeCap ne '0' && $timeCap ne '1') {
			warn(
				$c->maketext(
					"The value [_1] for the capTimeLimit option is not valid; it will be replaced with '0'.",
					$timeCap)
					. "\n"
			);
			$timeCap = '0';
		}
		if ($restrictIP ne 'No'
			&& $restrictIP ne 'DenyFrom'
			&& $restrictIP ne 'RestrictTo')
		{
			warn(
				$c->maketext(
					"The value [_1] for the restrictIP option is not valid; it will be replaced with 'No'.",
					$restrictIP)
					. "\n"
			);
			$restrictIP      = 'No';
			$restrictLoc     = '';
			$relaxRestrictIP = 'No';
		}
		if ($relaxRestrictIP ne 'No'
			&& $relaxRestrictIP ne 'AfterAnswerDate'
			&& $relaxRestrictIP ne 'AfterVersionAnswerDate')
		{
			warn(
				$c->maketext(
					"The value [_1] for the relaxRestrictIP option is not valid; it will be replaced with 'No'.",
					$relaxRestrictIP)
					. "\n"
			);
			$relaxRestrictIP = 'No';
		}
		# to verify that restrictLoc is valid requires a database
		#    call, so we defer that until we return to add the set

		# Read and check list of problems for the set

		# NOTE:  There are now two versions of problemList, the first is an unlabeled
		# list which may or may not contain a showMeAnother variable.  This is supported
		# but the unlabeled list is hard to work with.  The new version prints a
		# labeled list of values similar to how its done for the set variables

		if ($listType eq 'problemList') {

			while (my $line = <$SETFILENAME>) {
				chomp $line;
				$line =~ s/(#.*)//;                 ## don't read past comments
				unless ($line =~ /\S/) { next; }    ## skip blank lines

				# commas are valid in filenames, so we have to handle commas
				# using backslash escaping, so \X will be replaced with X
				my @line = ();
				my $curr = '';
				for (my $i = 0; $i < length $line; $i++) {
					my $c = substr($line, $i, 1);
					if ($c eq '\\') {
						$curr .= substr($line, ++$i, 1);
					} elsif ($c eq ',') {
						push @line, $curr;
						$curr = '';
					} else {
						$curr .= $c;
					}
				}
				# anything left?
				push(@line, $curr) if ($curr);

				# read the line and only look for $showMeAnother if it has the correct number of entries
				# otherwise the default value will be used
				if (scalar(@line) == 4) {
					($name, $weight, $attemptLimit, $showMeAnother, $continueFlag) = @line;
				} else {
					($name, $weight, $attemptLimit, $continueFlag) = @line;
				}

				# clean up problem values
				$name =~ s/\s*//g;
				$weight = "" unless defined($weight);
				$weight =~ s/[^\d\.]*//g;
				unless ($weight =~ /\d+/) { $weight = $weight_default; }
				$attemptLimit = "" unless defined($attemptLimit);
				$attemptLimit =~ s/[^\d-]*//g;
				unless ($attemptLimit =~ /\d+/) { $attemptLimit = $max_attempts_default; }
				$continueFlag = "0" unless (defined($continueFlag) && @problemData);
				# can't put continuation flag onto the first problem
				push(
					@problemData,
					{
						source_file   => $name,
						value         => $weight,
						max_attempts  => $attemptLimit,
						showMeAnother => $showMeAnother,
						continuation  => $continueFlag,
						# Use defaults for these since they are not going to be in the file.
						prPeriod       => $prPeriod_default,
						showHintsAfter => $showHintsAfter_default,
					}
				);
			}
		} else {
			# This is the new version, it looks for pairs of entries
			# of the form field name = value
			while (my $line = <$SETFILENAME>) {

				chomp $line;
				$line =~ s|(#.*)||;                  # Don't read past comments
				unless ($line =~ /\S/) { next; }     # Skip blank lines
				$line =~ s|\s*$||;                   # Trim trailing spaces
				$line =~ m|^\s*(\w+)\s*=?\s*(.*)|;

				# sanity check entries
				my $item = $1;
				$item = '' unless defined $item;
				my $value = $2;
				$value = '' unless defined $value;

				if ($item eq 'problem_start') {
					next;
				} elsif ($item eq 'source_file') {
					warn($c->maketext('No source_file for problem in .def file')) unless $value;
					$name = $value;
				} elsif ($item eq 'value') {
					$weight = ($value) ? $value : $weight_default;
				} elsif ($item eq 'max_attempts') {
					$attemptLimit = ($value) ? $value : $max_attempts_default;
				} elsif ($item eq 'showMeAnother') {
					$showMeAnother = ($value) ? $value : 0;
				} elsif ($item eq 'showHintsAfter') {
					$showHintsAfter = ($value) ? $value : -2;
				} elsif ($item eq 'prPeriod') {
					$prPeriod = ($value) ? $value : 0;
				} elsif ($item eq 'restrictProbProgression') {
					$restrictProbProgression = ($value) ? $value : 'No';
				} elsif ($item eq 'problem_id') {
					$problemID = ($value) ? $value : '';
				} elsif ($item eq 'counts_parent_grade') {
					$countsParentGrade = ($value) ? $value : 0;
				} elsif ($item eq 'att_to_open_children') {
					$attToOpenChildren = ($value) ? $value : 0;
				} elsif ($item eq 'problem_end') {

					#  clean up problem values
					$name =~ s/\s*//g;
					$weight = "" unless defined($weight);
					$weight =~ s/[^\d\.]*//g;
					unless ($weight =~ /\d+/) { $weight = $weight_default; }
					$attemptLimit = "" unless defined($attemptLimit);
					$attemptLimit =~ s/[^\d-]*//g;
					unless ($attemptLimit =~ /\d+/) { $attemptLimit = $max_attempts_default; }

					unless ($countsParentGrade =~ /(0|1)/) { $countsParentGrade = $counts_parent_grade_default; }
					$countsParentGrade =~ s/[^\d-]*//g;

					unless ($showMeAnother =~ /-?\d+/) { $showMeAnother = $showMeAnother_default; }
					$showMeAnother =~ s/[^\d-]*//g;

					unless ($showHintsAfter =~ /-?\d+/) { $showHintsAfter = $showHintsAfter_default; }
					$showHintsAfter =~ s/[^\d-]*//g;

					unless ($prPeriod =~ /-?\d+/) { $prPeriod = $prPeriod_default; }
					$prPeriod =~ s/[^\d-]*//g;

					unless ($attToOpenChildren =~ /\d+/) { $attToOpenChildren = $att_to_open_children_default; }
					$attToOpenChildren =~ s/[^\d-]*//g;

					if ($assignmentType eq 'jitar') {
						unless ($problemID =~ /[\d\.]+/) { $problemID = ''; }
						$problemID =~ s/[^\d\.-]*//g;
						$problemID = seq_to_jitar_id(split(/\./, $problemID));
					} else {
						unless ($problemID =~ /\d+/) { $problemID = ''; }
						$problemID =~ s/[^\d-]*//g;
					}

					# can't put continuation flag onto the first problem
					push(
						@problemData,
						{
							source_file       => $name,
							problemID         => $problemID,
							value             => $weight,
							max_attempts      => $attemptLimit,
							showMeAnother     => $showMeAnother,
							showHintsAfter    => $showHintsAfter,
							prPeriod          => $prPeriod,
							attToOpenChildren => $attToOpenChildren,
							countsParentGrade => $countsParentGrade,
						}
					);

					# reset the various values
					$name              = '';
					$problemID         = '';
					$weight            = '';
					$attemptLimit      = '';
					$showMeAnother     = '';
					$showHintsAfter    = '';
					$attToOpenChildren = '';
					$countsParentGrade = '';

				} else {
					warn $c->maketext("readSetDef error, can't read the line: ||[_1]||", $line);
				}
			}

		}

		$SETFILENAME->close;
		return (
			$setName,              $paperHeaderFile,    $screenHeaderFile,   $time1,
			$time2,                $time3,              \@problemData,       $assignmentType,
			$enableReducedScoring, $reducedScoringDate, $attemptsPerVersion, $timeInterval,
			$versionsPerInterval,  $versionTimeLimit,   $problemRandOrder,   $problemsPerPage,
			$hideScore,            $hideScoreByProblem, $hideWork,           $timeCap,
			$restrictIP,           $restrictLoc,        $relaxRestrictIP,    $description,
			$emailInstructor,      $restrictProbProgression
		);
	} else {
		warn $c->maketext("Can't open file [_1]", $filePath) . "\n";
		return;
	}
}

sub exportSetsToDef ($c, %filenames) {
	my $ce = $c->ce;
	my $db = $c->db;

	my (@exported, @skipped, %reason);

SET: foreach my $set (keys %filenames) {

		my $fileName = $filenames{$set};
		$fileName .= ".def"           unless $fileName =~ m/\.def$/;
		$fileName = "set" . $fileName unless $fileName =~ m/^set/;
		# files can be exported to sub directories but not parent directories
		if ($fileName =~ /\.\./) {
			push @skipped, $set;
			$reason{$set} = $c->maketext("Illegal filename contains '..'");
			next SET;
		}

		my $setRecord = $db->getGlobalSet($set);
		unless (defined $setRecord) {
			push @skipped, $set;
			$reason{$set} = $c->maketext("No record found.");
			next SET;
		}
		my $filePath = $ce->{courseDirs}->{templates} . '/' . $fileName;

		# back up existing file
		if (-e $filePath) {
			rename($filePath, "$filePath.bak")
				or $reason{$set} = $c->maketext("Existing file [_1] could not be backed up and was lost.", $filePath);
		}

		my $openDate           = $c->formatDateTime($setRecord->open_date);
		my $dueDate            = $c->formatDateTime($setRecord->due_date);
		my $answerDate         = $c->formatDateTime($setRecord->answer_date);
		my $reducedScoringDate = $c->formatDateTime($setRecord->reduced_scoring_date);
		my $description        = $setRecord->description;
		if ($description) {
			$description =~ s/\r?\n/<n>/g;
		}

		my $assignmentType          = $setRecord->assignment_type;
		my $enableReducedScoring    = $setRecord->enable_reduced_scoring ? 'Y' : 'N';
		my $setHeader               = $setRecord->set_header;
		my $paperHeader             = $setRecord->hardcopy_header;
		my $emailInstructor         = $setRecord->email_instructor;
		my $restrictProbProgression = $setRecord->restrict_prob_progression;

		my @problemList = $db->getGlobalProblemsWhere({ set_id => $set }, 'problem_id');

		my $problemList = '';
		for my $problemRecord (@problemList) {
			my $problem_id = $problemRecord->problem_id();

			if ($setRecord->assignment_type eq 'jitar') {
				$problem_id = join('.', jitar_id_to_seq($problem_id));
			}

			my $source_file       = $problemRecord->source_file();
			my $value             = $problemRecord->value();
			my $max_attempts      = $problemRecord->max_attempts();
			my $showMeAnother     = $problemRecord->showMeAnother();
			my $showHintsAfter    = $problemRecord->showHintsAfter();
			my $prPeriod          = $problemRecord->prPeriod();
			my $countsParentGrade = $problemRecord->counts_parent_grade();
			my $attToOpenChildren = $problemRecord->att_to_open_children();

			# backslash-escape commas in fields
			$source_file    =~ s/([,\\])/\\$1/g;
			$value          =~ s/([,\\])/\\$1/g;
			$max_attempts   =~ s/([,\\])/\\$1/g;
			$showMeAnother  =~ s/([,\\])/\\$1/g;
			$showHintsAfter =~ s/([,\\])/\\$1/g;
			$prPeriod       =~ s/([,\\])/\\$1/g;

			# This is the new way of saving problem information
			# the labelled list makes it easier to add variables and
			# easier to tell when they are missing
			$problemList .= "problem_start\n";
			$problemList .= "problem_id = $problem_id\n";
			$problemList .= "source_file = $source_file\n";
			$problemList .= "value = $value\n";
			$problemList .= "max_attempts = $max_attempts\n";
			$problemList .= "showMeAnother = $showMeAnother\n";
			$problemList .= "showHintsAfter = $showHintsAfter\n";
			$problemList .= "prPeriod = $prPeriod\n";
			$problemList .= "counts_parent_grade = $countsParentGrade\n";
			$problemList .= "att_to_open_children = $attToOpenChildren \n";
			$problemList .= "problem_end\n";
		}

		# gateway fields
		my $gwFields = '';
		if ($assignmentType =~ /gateway/) {
			my $attemptsPerV       = $setRecord->attempts_per_version;
			my $timeInterval       = $setRecord->time_interval;
			my $vPerInterval       = $setRecord->versions_per_interval;
			my $vTimeLimit         = $setRecord->version_time_limit;
			my $probRandom         = $setRecord->problem_randorder;
			my $probPerPage        = $setRecord->problems_per_page;
			my $hideScore          = $setRecord->hide_score;
			my $hideScoreByProblem = $setRecord->hide_score_by_problem;
			my $hideWork           = $setRecord->hide_work;
			my $timeCap            = $setRecord->time_limit_cap;
			$gwFields = <<EOG;

attemptsPerVersion  = $attemptsPerV
timeInterval        = $timeInterval
versionsPerInterval = $vPerInterval
versionTimeLimit    = $vTimeLimit
problemRandOrder    = $probRandom
problemsPerPage     = $probPerPage
hideScore           = $hideScore
hideScoreByProblem  = $hideScoreByProblem
hideWork            = $hideWork
capTimeLimit        = $timeCap
EOG
			chomp($gwFields);
		}

		# ip restriction fields
		my $restrictIP     = $setRecord->restrict_ip;
		my $restrictFields = '';
		if ($restrictIP && $restrictIP ne 'No') {
			# only store the first location
			my $restrictLoc   = ($db->listGlobalSetLocations($setRecord->set_id))[0];
			my $relaxRestrict = $setRecord->relax_restrict_ip;
			$restrictLoc || ($restrictLoc = '');
			$restrictFields =
				"restrictIP          = $restrictIP"
				. "\nrestrictLocation    = $restrictLoc\n"
				. "relaxRestrictIP     = $relaxRestrict\n";
		}

		my $fileContents = <<EOF;
assignmentType      = $assignmentType
openDate          = $openDate
reducedScoringDate = $reducedScoringDate
dueDate           = $dueDate
answerDate        = $answerDate
enableReducedScoring = $enableReducedScoring
paperHeaderFile   = $paperHeader
screenHeaderFile  = $setHeader$gwFields
description       = $description
restrictProbProgression = $restrictProbProgression
emailInstructor   = $emailInstructor
${restrictFields}
problemListV2
$problemList
EOF

		$filePath = WeBWorK::Utils::surePathToFile($ce->{courseDirs}->{templates}, $filePath);
		eval {
			open(my $SETDEF, '>', $filePath) or die $c->maketext("Failed to open [_1]", $filePath);
			print $SETDEF $fileContents;
			close $SETDEF;
		};

		if ($@) {
			push @skipped, $set;
			$reason{$set} = $@;
		} else {
			push @exported, $set;
		}

	}

	return \@exported, \@skipped, \%reason;
}

1;
