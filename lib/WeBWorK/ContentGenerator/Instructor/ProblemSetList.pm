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
use WeBWorK::Utils::Instructor qw(getDefList);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetList - Entry point for Set-specific
data editing/viewing

=cut

=for comment

What do we want to be able to do here?

filter sort edit publish import create delete

Filter what sets are shown:
	- all, selected
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
use WeBWorK::Utils qw(x);
use WeBWorK::Utils::DateTime qw(getDefaultSetDueDate);
use WeBWorK::Utils::Instructor qw(assignSetToUser);
use WeBWorK::Utils::Sets qw(format_set_name_internal format_set_name_display);
use WeBWorK::File::SetDef qw(importSetsFromDef exportSetsToDef);

use constant HIDE_SETS_THRESHOLD => 500;

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

use constant SORTABLE_FIELDS => {
	set_id               => 1,
	open_date            => 1,
	reduced_scoring_date => 1,
	due_date             => 1,
	answer_date          => 1,
	visible              => 1
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
		my $scope       = $c->param('action.score.scope');
		my @setsToScore = $scope eq 'all' ? @{ $c->{allSetIDs} } : $c->param('selected_sets');

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
	$c->stash->{fieldNames}     = VIEW_FIELD_ORDER();
	$c->stash->{formsToShow}    = VIEW_FORMS();
	$c->stash->{formTitles}     = FORM_TITLES();
	$c->stash->{formPerms}      = FORM_PERMS();
	$c->stash->{fieldTypes}     = FIELD_TYPES();
	$c->stash->{sortableFields} = SORTABLE_FIELDS();
	$c->stash->{sets}           = [];
	$c->stash->{setDefList}     = [];

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

	$c->{primarySortField}   = $c->param('primarySortField')   || 'due_date';
	$c->{primarySortOrder}   = $c->param('primarySortOrder')   || 'ASC';
	$c->{secondarySortField} = $c->param('secondarySortField') || 'open_date';
	$c->{secondarySortOrder} = $c->param('secondarySortOrder') || 'ASC';

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
				$c->addgoodmessage($c->b($action_result));
			} else {
				$c->addbadmessage($c->b($action_result));
			}
		} else {
			$c->addbadmessage($c->maketext('You are not authorized to perform this action.'));
		}
	}

	$c->stash->{fieldNames} =
		$c->{editMode} ? EDIT_FIELD_ORDER() : $c->{exportMode} ? EXPORT_FIELD_ORDER() : VIEW_FIELD_ORDER();
	if (!$c->ce->{pg}{ansEvalDefaults}{enableReducedScoring}) {
		$c->stash->{fieldNames} =
			[ grep { !/enable_reduced_scoring|reduced_scoring_date/ } @{ $c->stash->{fieldNames} } ];
	}

	# A scalar reference must be used for the order by clause in getGlobalSetsWhere due to a very limited override of
	# the SQL::Abstract _order_by method in WeBWorK::DB::Utils::SQLAbstractIdentTrans. Since scalar references bypass
	# the SQL::Abstract injection guard, care must be taken to ensure that only the allowed values are used.
	die 'Possible SQL injection attempt detected.'
		unless SORTABLE_FIELDS()->{ $c->{primarySortField} }
		&& SORTABLE_FIELDS()->{ $c->{secondarySortField} }
		&& ($c->{primarySortOrder} eq 'ASC'   || $c->{primarySortOrder} eq 'DESC')
		&& ($c->{secondarySortOrder} eq 'ASC' || $c->{secondarySortOrder} eq 'DESC');

	$c->stash->{formsToShow} = $c->{editMode} ? EDIT_FORMS() : $c->{exportMode} ? EXPORT_FORMS() : VIEW_FORMS();
	$c->stash->{setDefList}  = [ getDefList($ce) ] unless $c->{editMode} || $c->{exportMode};
	# Get requested sets in the requested order.
	$c->stash->{sets} = [
		@{ $c->{visibleSetIDs} }
		? $db->getGlobalSetsWhere({ set_id => $c->{visibleSetIDs} },
			\("$c->{primarySortField} $c->{primarySortOrder}, $c->{secondarySortField} $c->{secondarySortOrder}"))
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
		$result = $c->maketext('Showing all sets.');
		$c->{visibleSetIDs} = $c->{allSetIDs};
	} elsif ($scope eq "selected") {
		$result = $c->maketext('Showing selected sets.');
		$c->{visibleSetIDs} = [ $c->param('selected_sets') ];
	} elsif ($scope eq "match_ids") {
		$result = $c->maketext('Showing matching sets.');
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
	if (defined $c->param('labelSortMethod') || defined $c->param('labelSortOrder')) {
		if (defined $c->param('labelSortOrder')) {
			$c->{ $c->param('labelSortOrder') . 'SortOrder' } =
				$c->{ $c->param('labelSortOrder') . 'SortOrder' } eq 'ASC' ? 'DESC' : 'ASC';
		} elsif ($c->param('labelSortMethod') eq $c->{primarySortField}) {
			$c->{primarySortOrder} = $c->{primarySortOrder} eq 'ASC' ? 'DESC' : 'ASC';
		} else {
			$c->{secondarySortField} = $c->{primarySortField};
			$c->{secondarySortOrder} = $c->{primarySortOrder};
			$c->{primarySortField}   = $c->param('labelSortMethod');
			$c->{primarySortOrder}   = 'ASC';
		}

		$c->param('action.sort.primary',         $c->{primarySortField});
		$c->param('action.sort.primary.order',   $c->{primarySortOrder});
		$c->param('action.sort.secondary',       $c->{secondarySortField});
		$c->param('action.sort.secondary.order', $c->{secondarySortOrder});
	} else {
		$c->{primarySortField}   = $c->param('action.sort.primary');
		$c->{primarySortOrder}   = $c->param('action.sort.primary.order');
		$c->{secondarySortField} = $c->param('action.sort.secondary');
		$c->{secondarySortOrder} = $c->param('action.sort.secondary.order');
	}

	my %names = (
		set_id               => $c->maketext("Set Name"),
		open_date            => $c->maketext("Open Date"),
		reduced_scoring_date => $c->maketext("Reduced Scoring Date"),
		due_date             => $c->maketext("Close Date"),
		answer_date          => $c->maketext("Answer Date"),
		visible              => $c->maketext("Visibility"),
	);

	return (
		1,
		$c->maketext(
			'Sets sorted by [_1] in [plural,_2,ascending,descending] order, '
				. 'and then by [_3] in [plural,_4,ascending,descending] order.',
			$names{ $c->{primarySortField} },
			$c->{primarySortOrder} eq 'ASC' ? 1 : 2,
			$names{ $c->{secondarySortField} },
			$c->{secondarySortOrder} eq 'ASC' ? 1 : 2
		)
	);
}

sub edit_handler ($c) {
	my $scope = $c->param('action.edit.scope');
	$c->{editMode} = 1;

	if ($scope eq 'all') {
		$c->{visibleSetIDs} = $c->{allSetIDs};
		return (1, $c->maketext('Editing all sets.'));
	}

	$c->{visibleSetIDs} = [ $c->param('selected_sets') ];
	return (1, $c->maketext('Editing selected sets.'));
}

sub publish_handler ($c) {
	my $db     = $c->db;
	my $value  = $c->param('action.publish.value');
	my $scope  = $c->param('action.publish.scope');
	my @setIDs = $scope eq 'all' ? @{ $c->{allSetIDs} } : $c->param('selected_sets');

	# Can we use UPDATE here, instead of fetch/change/store?
	my @sets = $db->getGlobalSets(@setIDs);
	map { $_->visible($value); $db->putGlobalSet($_); } @sets;

	if ($scope eq 'all') {
		return $value
			? (1, $c->maketext('All sets made visible for all students.'))
			: (1, $c->maketext('All sets hidden from all students.'));
	}

	return $value
		? (1, $c->maketext('All selected sets made visible for all students.'))
		: (1, $c->maketext('All selected sets hidden from all students.'));
}

sub score_handler ($c) {
	# The only time this is called is if "no sets" is selected (do we really need that option),
	# or one of the other options was selected but there were no sets to score.
	return (0, $c->maketext('No sets selected for scoring.'));
}

sub delete_handler ($c) {
	my $db      = $c->db;
	my $confirm = $c->param('action.delete.confirm');

	return (1, $c->maketext('Deleted [_1] sets.', 0)) unless ($confirm eq 'yes');

	my @setIDsToDelete = @{ $c->{selectedSetIDs} };
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

	return (1, $c->maketext('Deleted [_1] sets.', scalar @setIDsToDelete));
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

	my $type = $c->param('action.create.type');

	if ($type eq "empty") {
		my $dueDate = getDefaultSetDueDate($ce);

		$newSetRecord->set_id($newSetID);
		$newSetRecord->set_header("defaultHeader");
		$newSetRecord->hardcopy_header("defaultHeader");
		$newSetRecord->open_date($dueDate - 60 * $ce->{pg}{assignOpenPriorToDue});
		$newSetRecord->reduced_scoring_date($dueDate - 60 * $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod});
		$newSetRecord->due_date($dueDate);
		$newSetRecord->answer_date($dueDate + 60 * $ce->{pg}{answersOpenAfterDueDate});
		$newSetRecord->visible(1);
		$newSetRecord->enable_reduced_scoring(0);
		$newSetRecord->assignment_type('default');
		$db->addGlobalSet($newSetRecord);
	} elsif ($type eq "copy") {
		my $oldSetID = $c->{selectedSetIDs}[0];
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
	my ($added, $skipped, $errors) = importSetsFromDef(
		$c->ce,
		$c->db,
		[ $c->param('action.import.source') ],
		$c->{allSetIDs},
		$c->param('action.import.assign'),
		$c->param('action.import.start.date') // 0,
		# Cannot assign set names to multiple imports.
		$c->param('action.import.number') > 1 ? '' : format_set_name_internal($c->param('action.import.name')),
	);

	# Make new sets visible.
	push @{ $c->{visibleSetIDs} }, @$added;
	push @{ $c->{allSetIDs} },     @$added;

	return (
		@$skipped ? 0 : 1,
		$c->c(
			$c->maketext('[quant,_1,set] added, [quant,_2,set] skipped.', scalar(@$added), scalar(@$skipped)),
			@$errors
			? $c->tag('ul', class => 'my-1', $c->c(map { $c->tag('li', $c->maketext(@$_)) } @$errors)->join(''))
			: ''
		)->join('')
	);
}

# this does not actually export any files, rather it sends us to a new page in order to export the files
sub export_handler ($c) {
	my $scope = $c->param('action.export.scope');
	$c->{selectedSetIDs} = $scope eq 'all' ? $c->{allSetIDs} : [ $c->param('selected_sets') ];
	$c->{visibleSetIDs}  = $c->{selectedSetIDs};
	$c->{exportMode}     = 1;

	return $scope eq 'all'
		? (1, $c->maketext('All sets were exported.'))
		: (1, $c->maketext('Selected sets were exported.'));
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

	return (0, $c->maketext('Export abandoned.'));
}

sub save_export_handler ($c) {
	my ($exported, $skipped, $reason) =
		exportSetsToDef($c->ce, $c->db, @{ $c->{selectedSetIDs} });

	if (defined $c->param('prev_visible_sets')) {
		$c->{visibleSetIDs} = [ $c->param('prev_visible_sets') ];
	} elsif (defined $c->param('no_prev_visble_sets')) {
		$c->{visibleSetIDs} = [];
	}

	$c->{exportMode} = 0;

	return (
		@$skipped ? 0 : 1,
		$c->c(
			$c->maketext('[quant,_1,set] exported, [quant,_2,set] skipped.', scalar(@$exported), scalar(@$skipped)),
			@$skipped ? $c->tag(
				'ul',
				class => 'my-1',
				$c->c(map { $c->tag('li', "set $_ - " . $c->maketext(@{ $reason->{$_} })) } keys %$reason)->join('')
			) : ''
		)->join('')
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

	return (0, $c->maketext('Changes abandoned.'));
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
		return (0, $c->maketext('Error: Open date cannot be more than 10 years from now in set [_1].', $setID))
			if $Set->open_date > $cutoff;
		return (0, $c->maketext('Error: Close date cannot be more than 10 years from now in set [_1].', $setID))
			if $Set->due_date > $cutoff;
		return (0, $c->maketext('Error: Answer date cannot be more than 10 years from now in set [_1].', $setID))
			if $Set->answer_date > $cutoff;

		# Check that the open, due and answer dates are in increasing order.
		# Bail if this is not correct.
		if ($Set->open_date > $Set->due_date) {
			return (0, $c->maketext('Error: Close date must come after open date in set [_1].', $setID));
		}
		if ($Set->due_date > $Set->answer_date) {
			return (0, $c->maketext('Error: Answer date must come after close date in set [_1].', $setID));
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
					'Error: Reduced scoring date must come between the open date and close date in set [_1].',
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

	return (1, $c->maketext('Changes saved.'));
}

1;
