################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator::Instructor);

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
#	make one $mode variable that contains a string like "edit", "view", or "export"

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Utils qw(timeToSec readFile listFilesRecursive jitar_id_to_seq seq_to_jitar_id x getAssetURL
	format_set_name_internal format_set_name_display);

use constant HIDE_SETS_THRESHOLD => 500;
use constant DEFAULT_VISIBILITY_STATE => 1;
use constant DEFAULT_ENABLED_REDUCED_SCORING_STATE => 0;
use constant ONE_WEEK => 60*60*24*7;

use constant EDIT_FORMS => [qw(saveEdit cancelEdit)];
use constant VIEW_FORMS => [qw(filter sort edit publish import export score create delete)];
use constant EXPORT_FORMS => [qw(saveExport cancelExport)];

# Prepare the tab titles for translation by maketext
use constant FORM_TITLES => {
	saveEdit       => x("Save Edit"),
	cancelEdit     => x("Cancel Edit"),
	filter         => x("Filter"),
	sort           => x("Sort"),
	edit           => x("Edit"),
	publish        => x("Publish"),
	import         => x("Import"),
	export         => x("Export"),
	score          => x("Score"),
	create         => x("Create"),
	delete         => x("Delete"),
	saveExport     => x("Save Export"),
	cancelExport   => x("Cancel Export")
};

use constant VIEW_FIELD_ORDER => [ qw( set_id problems users visible enable_reduced_scoring open_date reduced_scoring_date due_date answer_date) ];
use constant EDIT_FIELD_ORDER => [ qw( set_id visible enable_reduced_scoring open_date reduced_scoring_date due_date answer_date) ];
use constant EXPORT_FIELD_ORDER => [ qw( select set_id problems users) ];

# permissions needed to perform a given action
use constant FORM_PERMS => {
		saveEdit => "modify_problem_sets",
		edit => "modify_problem_sets",
		publish => "modify_problem_sets",
		import => "create_and_delete_problem_sets",
		export => "modify_set_def_files",
		saveExport => "modify_set_def_files",
		score => "score_sets",
		create => "create_and_delete_problem_sets",
		delete => "create_and_delete_problem_sets",
};

# permissions needed to view a given field
use constant FIELD_PERMS => {
		problems => "modify_problem_sets",
		users	=> "assign_problem_sets",
};

use constant STATE_PARAMS => [qw(user effectiveUser key visible_sets no_visible_sets prev_visible_sets no_prev_visible_set editMode exportMode primarySortField secondarySortField)];

# note that field_properties for some fields, in particular, gateway
# parameters, are not currently shown in the edit or display tables
use constant  FIELD_PROPERTIES => {
	set_id => {
		type => "text",
		size => 8,
		access => "readonly",
	},
	open_date => {
		type => "date",
		size => 22,
		access => "readwrite",
	},
	reduced_scoring_date => {
		type => "date",
		size => 22,
		access => "readwrite",
	},
	due_date => {
		type => "date",
		size => 22,
		access => "readwrite",
	},
	answer_date => {
		type => "date",
		size => 22,
		access => "readwrite",
	},
	visible => {
		type => "checked",
		size => 4,
		access => "readwrite",
	},
	enable_reduced_scoring => {
		type => "checked",
		size => 4,
		access => "readwrite",
	},
	assignment_type => {
		type => "text",
		size => 20,
		access => "readwrite",
	},
	attempts_per_version => {
		type => "text",
		size => 4,
		access => "readwrite",
	},
	time_interval => {
		type => "text",
		size => 10,
		access => "readwrite",
	},
	versions_per_interval => {
		type => "text",
		size => 4,
		access => "readwrite",
	},
	version_time_limit => {
		type => "text",
		size => 10,
		access => "readwrite",
	},
	problem_randorder => {
		type => "text",
		size => 4,
		access => "readwrite",
	},
	problems_per_page => {
		type => "text",
		size => 4,
		access => "readwrite",
	},
	version_creation_time => {
		type => "text",
		size => 10,
		access => "readonly",
	},
	version_last_attempt_time => {
		type => "text",
		size => 10,
		access => "readonly",
	},
	# hide_score and hide_work should be drop down selects with
	#    options 'N', 'Y' and 'BeforeAnswerDate'.  in that we don't
	#    allow editing of these fields in this module, this is moot.
	hide_score => {
		type => "text",
		size => 16,
		access => "readwrite",
	},
	hide_work => {
		type => "text",
		size => 16,
		access => "readwrite",
	},
	time_limit_cap => {
		type => "checked",
		size => 4,
		access => "readwrite",
	},
	# this should be 'No', 'RestrictTo' or 'DenyFrom'
	restrict_ip => {
		type => "text",
		size => 10,
		access => "readwrite",
	},
#	hide_hint => {
#		type => "checked",
#		size => 4,
#		access => "readwrite",
#	}
};

sub pre_header_initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $authz  = $r->authz;
	my $urlpath = $r->urlpath;
	my $user   = $r->param('user');
	my $courseName = $urlpath->arg("courseID");

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");

	# Get the list of global sets and the number of users and cache them for later use.
	$self->{allSetIDs} = [ $db->listGlobalSets() ];
	$self->{totalUsers} = $db->countUsers;

	if (defined $r->param("action") and $r->param("action") eq "score" and $authz->hasPermissions($user, "score_sets")) {
		my $scope = $r->param("action.score.scope");
		my @setsToScore = ();

		if ($scope eq "none") {
			return $r->maketext("No sets selected for scoring");
		} elsif ($scope eq "all") {
			@setsToScore = @{ $self->{allSetIDs} };
		} elsif ($scope eq "visible") {
			@setsToScore = @{ $r->param("visibleSetIDs") };
		} elsif ($scope eq "selected") {
			@setsToScore = $r->param("selected_sets");
		}

		my $uri = $self->systemLink(
			$urlpath->newFromModule('WeBWorK::ContentGenerator::Instructor::Scoring', $r, courseID => $courseName),
			params => {
				scoreSelected => "ScoreSelected",
				selectedSet   => \@setsToScore,
			}
		);

		$self->reply_with_redirect($uri);
	}
}

sub initialize {

	my ($self)       = @_;
	my $r            = $self->r;
	my $urlpath      = $r->urlpath;
	my $db           = $r->db;
	my $ce           = $r->ce;
	my $authz        = $r->authz;
	my $courseName   = $urlpath->arg("courseID");
	my $setID        = $urlpath->arg("setID");
	my $user         = $r->param('user');

	# Determine if the user has permisson to do anything here.
	return unless $authz->hasPermissions($user, 'access_instructor_tools');

	# Determine if edit mode or export mode is request, and check permissions for these modes.
	$self->{editMode} = $r->param("editMode") || 0;
	return if $self->{editMode} and not $authz->hasPermissions($user, 'modify_problem_sets');

	$self->{exportMode} = $r->param("exportMode") || 0;
	return if $self->{exportMode} and not $authz->hasPermissions($user, 'modify_set_def_files');

	my $root = $ce->{webworkURLs}->{root};

	# Templates for getting field names
	my $setTemplate = $self->{setTemplate} = $db->newGlobalSet;

	if (defined $r->param("visible_sets")) {
		$self->{visibleSetIDs} = [ $r->param("visible_sets") ];
	} elsif (defined $r->param("no_visible_sets")) {
		$self->{visibleSetIDs} = [];
	} else {
		if (@{ $self->{allSetIDs} } > HIDE_SETS_THRESHOLD) {
			$self->{visibleSetIDs} = [];
		} else {
			$self->{visibleSetIDs} = $self->{allSetIDs};
		}
	}

	$self->{prevVisibleSetIDs} = $self->{visibleSetIDs};

	if (defined $r->param("selected_sets")) {
		$self->{selectedSetIDs} = [ $r->param("selected_sets") ];
	} else {
		$self->{selectedSetIDs} = [];
	}

	$self->{primarySortField} = $r->param("primarySortField") || "due_date";
	$self->{secondarySortField} = $r->param("secondarySortField") || "open_date";

	#########################################
	#  call action handler
	#########################################

	my $actionID = $r->param("action");
	$self->{actionID} = $actionID;
	if ($actionID) {
		unless (grep { $_ eq $actionID } @{ VIEW_FORMS() }, @{ EDIT_FORMS() }, @{ EXPORT_FORMS() }) {
			die $r->maketext("Action [_1] not found", $actionID);
		}
		# Check permissions
		if (not FORM_PERMS()->{$actionID} or $authz->hasPermissions($user, FORM_PERMS()->{$actionID})) {
			my $actionHandler = "${actionID}_handler";
			my %genericParams;
			foreach my $param (qw(selected_sets)) {
				$genericParams{$param} = [ $r->param($param) ];
			}
			my %actionParams = $self->getActionParams($actionID);
			my %tableParams = $self->getTableParams();
			$self->addmessage(CGI::div({ class => 'mb-1' }, $r->maketext("Results of last action performed") . ": "));
			$self->addmessage($self->$actionHandler(\%genericParams, \%actionParams, \%tableParams));
		} else {
			return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
				CGI::p($r->maketext("You are not authorized to perform this action.")));
		}
	} else {
		$self->addgoodmessage($r->maketext("Please select action to be performed."));
	}
}

sub body {
	my ($self)       = @_;
	my $r            = $self->r;
	my $urlpath      = $r->urlpath;
	my $db           = $r->db;
	my $ce           = $r->ce;
	my $authz        = $r->authz;
	my $courseName   = $urlpath->arg("courseID");
	my $setID        = $urlpath->arg("setID");
	my $user         = $r->param('user');

	my $root = $ce->{webworkURLs}->{root};

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		$r->maketext("You are not authorized to access the instructor tools."))
		unless $authz->hasPermissions($user, "access_instructor_tools");

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		CGI::p($r->maketext("You are not authorized to modify homework sets.")))
		if $self->{editMode} and not $authz->hasPermissions($user, "modify_problem_sets");

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		CGI::p($r->maketext("You are not authorized to modify set definition files.")))
		if $self->{exportMode} and not $authz->hasPermissions($user, "modify_set_def_files");

	# templates for getting field names
	my $setTemplate = $self->{setTemplate} = $db->newGlobalSet;

	# This table can be consulted when display-ready forms of field names are needed.
	my %fieldHeaders;

	@fieldHeaders{qw(
		problems
		users
		filename
		set_id
		open_date
		reduced_scoring_date
		due_date
		answer_date
		visible
		enable_reduced_scoring
		hide_hint
	)} = (
		CGI::th({ id => 'problems_header' }, $r->maketext("Edit Problems")),
		CGI::th({ id => 'users_header' }, $r->maketext("Edit Assigned Users")),
		CGI::th({ id => 'filename_header' }, $r->maketext("Set Definition Filename")),
		CGI::th(CGI::label({ for => 'select-all' }, $r->maketext("Edit Set Data"))),
		CGI::th({ id => 'open_date_header' }, $r->maketext("Open Date")),
		CGI::th({ id => 'reduced_scoring_date_header' }, $r->maketext("Reduced Scoring Date")),
		CGI::th({ id => 'due_date_header' }, $r->maketext("Close Date")),
		CGI::th({ id => 'answer_date_header' }, $r->maketext("Answer Date")),
		CGI::th({ id => 'visible_header' }, $r->maketext("Visible")),
		CGI::th($r->maketext("Reduced Scoring")),
		CGI::th({ id => 'hide_hint_header' }, $r->maketext("Hide Hints"))
	);

	my $actionID = $self->{actionID};

	# Retrieve values for member fields
	my $editMode = $self->{editMode};
	my $exportMode = $self->{exportMode};
	my $primarySortField = $self->{primarySortField};
	my $secondarySortField = $self->{secondarySortField};

	# Get requested sets in the requested order.
	my @Sets =
		@{ $self->{visibleSetIDs} }
		? $db->getGlobalSetsWhere({ set_id => $self->{visibleSetIDs} }, [ $primarySortField, $secondarySortField ])
		: ();

	########## print site identifying information

	print CGI::input({
		type  => 'button',
		id    => 'show_hide',
		value => $r->maketext('Show/Hide Site Description'),
		class => 'btn btn-info mb-2'
	});
	print CGI::p(
		{ id => 'site_description', style => 'display:none' },
		CGI::em($r->maketext(
			'This is the homework sets editor page where you can view and edit the homework sets that exist in this '
				. 'course and the problems that they contain. The top of the page contains forms which allow you to '
				. 'filter which sets to display in the table, sort the sets in a chosen order, edit homework sets, '
				. 'publish homework sets, import/export sets from/to an external file, score sets, or create/delete '
				. 'sets.  To use, please select the action you would like to perform, enter in the relevant '
				. 'information in the fields below, and hit the "Take Action!" button at the bottom of the form.  The '
				. 'bottom of the page contains a table displaying the sets and several pieces of relevant information. '
				. 'The Edit Set Data field in the table contains checkboxes for selection and a link to the set data '
				. 'editing page.  The cells in the Edit Problems fields contain links which take you to a page where '
				. 'you can edit the containing problems, and the cells in the edit assigned users field contains links '
				. 'which take you to a page where you can edit what students the set is assigned to.'
		))
	);

	########## print beginning of form

	print CGI::start_form({
		method => 'post',
		action => $self->systemLink($urlpath, authen => 0),
		id     => 'problemsetlist',
		name   => 'problemsetlist',
		class  => 'font-sm'
	});
	print $self->hidden_authen_fields();

	########## print state data

	print "\n<!-- state data here -->\n";

	if (@{ $self->{visibleSetIDs} }) {
		print CGI::hidden(-name => "visible_sets", -value => $self->{visibleSetIDs});
	} else {
		print CGI::hidden(-name=>"no_visible_sets", -value=>"1");
	}

	if (@{ $self->{prevVisibleSetIDs} }) {
		print CGI::hidden(-name => "prev_visible_sets", -value => $self->{prevVisibleSetIDs});
	} else {
		print CGI::hidden(-name => "no_prev_visible_sets", -value => "1");
	}

	print CGI::hidden(-name=>"editMode", -value=>$editMode);
	print CGI::hidden(-name=>"exportMode", -value=>$exportMode);

	print CGI::hidden(-name=>"primarySortField", -value=>$primarySortField);
	print CGI::hidden(-name=>"secondarySortField", -value=>$secondarySortField);

	print "\n<!-- state data here -->\n";

	########## print action forms

	print CGI::p(CGI::b($r->maketext("Any changes made below will be reflected in the set for ALL students."))) if $editMode;

	print CGI::p($r->maketext("Select an action to perform").":");

	my @formsToShow;
	if ($editMode) {
		@formsToShow = @{ EDIT_FORMS() };
	} elsif ($exportMode) {
		@formsToShow = @{ EXPORT_FORMS() };
	} else {
		@formsToShow = @{ VIEW_FORMS() };
	}
	my %formTitles = %{ FORM_TITLES() };

	my @tabArr;
	my @contentArr;
	my $default_choice;

	for my $actionID (@formsToShow) {
		# Check permissions
		next if FORM_PERMS()->{$actionID} and not $authz->hasPermissions($user, FORM_PERMS()->{$actionID});

		my $actionForm = "${actionID}_form";

		my $active = '';
		$active = ' active', $default_choice = $actionID unless $default_choice;

		push(
			@tabArr,
			CGI::li(
				{ class => 'nav-item', role => 'presentation' },
				CGI::a(
					{
						href           => "#$actionID",
						class          => "nav-link action-link$active",
						id             => "$actionID-tab",
						data_action    => $actionID,
						data_bs_toggle => 'tab',
						data_bs_target => "#$actionID",
						role           => 'tab',
						aria_controls  => $actionID,
						aria_selected  => $active ? 'true' : 'false'
					},
					$r->maketext($formTitles{$actionID})
				)
			)
		);
		push(
			@contentArr,
			CGI::div(
				{
					class           => 'tab-pane fade mb-2' . ($active ? " show$active" : ''),
					id              => $actionID,
					role            => 'tabpanel',
					aria_labelledby => "$actionID-tab"
				},
				$self->$actionForm($self->getActionParams($actionID))
			)
		);
	}

	print CGI::hidden(-name => 'action', -id => 'current_action', -value => $default_choice);
	print CGI::div(
		CGI::ul({ class => 'nav nav-tabs mb-2', role => 'tablist' }, @tabArr),
		CGI::div({ class => 'tab-content' }, @contentArr)
	);

	print CGI::submit({
		id    => 'take_action',
		value => $r->maketext('Take Action!'),
		class => 'btn btn-primary mb-3'
	});

	########## print table

	########## first adjust heading if in editMode
	$fieldHeaders{set_id} = CGI::th($r->maketext("Edit Set")) if $editMode;
	$fieldHeaders{enable_reduced_scoring} =
		CGI::th({ id => 'enable_reduced_scoring_header' }, $r->maketext('Enable Reduced Scoring'))
		if $editMode;


	print CGI::p(
		$r->maketext(
			"Showing [_1] out of [_2] sets.",
			scalar @{ $self->{visibleSetIDs} },
			scalar @{ $self->{allSetIDs} }
		)
	);

	$self->printTableHTML(
		\@Sets, \%fieldHeaders,
		editMode       => $editMode,
		exportMode     => $exportMode,
		selectedSetIDs => $self->{selectedSetIDs},
	);

	########## print end of form

 	print CGI::end_form();

	return "";
}

################################################################################
# extract particular params and put them in a hash (values are ARRAYREFs!)
################################################################################

sub getActionParams {
	my ($self, $actionID) = @_;
	my $r = $self->{r};

	my %actionParams;
	foreach my $param ($r->param) {
		next unless $param =~ m/^action\.$actionID\./;
		$actionParams{$param} = [ $r->param($param) ];
	}
	return %actionParams;
}

sub getTableParams {
	my ($self) = @_;
	my $r = $self->{r};

	my %tableParams;
	foreach my $param ($r->param) {
		next unless $param =~ m/^(?:.*set)\./;
		$tableParams{$param} = [ $r->param($param) ];
	}
	return %tableParams;
}

################################################################################
# actions and action triggers
################################################################################

# filter, edit, cancelEdit, and saveEdit should stay with the display module and
# not be real "actions". that way, all actions are shown in view mode and no
# actions are shown in edit mode.

sub filter_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;

	return CGI::div(
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'filter_select', class => 'col-form-label col-form-label-sm col-sm-auto' },
				$r->maketext('Show which sets?')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'filter_select',
					name    => 'action.filter.scope',
					values  => [qw(all none selected match_ids visible unvisible)],
					default => $actionParams{'action.filter.scope'}[0] || 'match_ids',
					class   => 'form-select form-select-sm',
					labels  => {
						all       => $r->maketext('all sets'),
						none      => $r->maketext('no sets'),
						selected  => $r->maketext('selected sets'),
						visible   => $r->maketext('sets visible to students'),
						unvisible => $r->maketext('sets hidden from students'),
						match_ids => $r->maketext('enter matching set IDs below'),
					}
				})
			)
		),
		CGI::div(
			{ id => 'filter_elements', class => 'row mb-2' },
			CGI::label(
				{ for => 'filter_text', class => 'col-form-label col-form-label-sm col-sm-auto' },
				$r->maketext('Match on what? (separate multiple IDs with commas)')
					. CGI::span({ class => 'required-field' }, '*')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::textfield({
					id            => 'filter_text',
					name          => 'action.filter.set_ids',
					value         => $actionParams{'action.filter.set_ids'}[0] // '',
					aria_required => 'true',
					class         => 'form-control form-control-sm',
					dir           => 'ltr'
				})
			)
		),
		CGI::div(
			{ id => 'filter_err_msg', class => 'alert alert-danger p-1 mb-2 d-inline-flex d-none' },
			$r->maketext('Please enter in a value to match in the filter field.')
		)
	);
}

# this action handler modifies the "visibleSetIDs" field based on the contents
# of the "action.filter.scope" parameter and the "selected_sets"
sub filter_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r  = $self->r;
	my $db = $r->db;

	my $result;

	my $scope = $actionParams->{"action.filter.scope"}->[0];

	if ($scope eq "all") {
		$result = $r->maketext("showing all sets");
		$self->{visibleSetIDs} = $self->{allSetIDs};
	} elsif ($scope eq "none") {
		$result = $r->maketext("showing no sets");
		$self->{visibleSetIDs} = [];
	} elsif ($scope eq "selected") {
		$result = $r->maketext("showing selected sets");
		$self->{visibleSetIDs} = $genericParams->{selected_sets};
	} elsif ($scope eq "match_ids") {
		$result = $r->maketext("showing matching sets");
		my @searchTerms = map { format_set_name_internal($_) } split /\s*,\s*/,
			$actionParams->{'action.filter.set_ids'}[0];
		my $regexTerms = join('|', @searchTerms);
		my @setIDs     = grep {/$regexTerms/i} @{ $self->{allSetIDs} };
		$self->{visibleSetIDs} = \@setIDs;
	} elsif ($scope eq "visible") {
		$result = $r->maketext("showing sets that are visible to students");
		$self->{visibleSetIDs} = [ map { $_->[0] } $db->listGlobalSetsWhere({ visible => 1 }) ];
	} elsif ($scope eq "unvisible") {
		$result = $r->maketext("showing sets that are hidden from students");
		$self->{visibleSetIDs} = [ map { $_->[0] } $db->listGlobalSetsWhere({ visible => 0 }) ];
	}

	return CGI::div({ class => 'alert alert-success p-1 mb-0' }, $result);
}

sub sort_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;

	return CGI::div(
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'sort_select_1', class => 'col-form-label col-form-label-sm', style => 'width:4.5rem' },
				$r->maketext('Sort by') . ':'
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'sort_select_1',
					name    => 'action.sort.primary',
					values  => [qw(set_id open_date due_date answer_date visible)],
					default => $actionParams{'action.sort.primary'}[0] || 'due_date',
					class   => 'form-select form-select-sm',
					labels  => {
						set_id      => $r->maketext('Set Name'),
						open_date   => $r->maketext('Open Date'),
						due_date    => $r->maketext('Close Date'),
						answer_date => $r->maketext('Answer Date'),
						visible     => $r->maketext('Visibility'),
					}
				})
			)
		),
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'sort_select_2', class => 'col-form-label col-form-label-sm', style => 'width:4.5rem' },
				$r->maketext('Then by') . ':'
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'sort_select_2',
					name    => 'action.sort.secondary',
					values  => [qw(set_id open_date due_date answer_date visible)],
					default => $actionParams{'action.sort.secondary'}[0] || 'open_date',
					class   => 'form-select form-select-sm',
					labels  => {
						set_id      => $r->maketext('Set Name'),
						open_date   => $r->maketext('Open Date'),
						due_date    => $r->maketext('Close Date'),
						answer_date => $r->maketext('Answer Date'),
						visible     => $r->maketext('Visibility'),
					}
				})
			)
		)
	);
}

sub sort_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;

	my $primary = $actionParams->{"action.sort.primary"}->[0];
	my $secondary = $actionParams->{"action.sort.secondary"}->[0];

	$self->{primarySortField} = $primary;
	$self->{secondarySortField} = $secondary;

	my %names = (
		set_id		=> $r->maketext("Set Name"),
		open_date	=> $r->maketext("Open Date"),
		due_date	=> $r->maketext("Close Date"),
		answer_date	=> $r->maketext("Answer Date"),
		visible	=> $r->maketext("Visibility"),
	);

	return CGI::div({ class => 'alert alert-success p-1 mb-0' },
		$r->maketext("Sort by [_1] and then by [_2]", $names{$primary}, $names{$secondary}));
}


sub edit_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;

	return CGI::div(
		{ class => 'row mb-2' },
		CGI::label(
			{ for => 'edit_select', class => 'col-form-label col-form-label-sm col-auto' },
			$r->maketext('Edit which sets?')
		),
		CGI::div(
			{ class => 'col-auto' },
			CGI::popup_menu({
				id      => 'edit_select',
				name    => 'action.edit.scope',
				values  => [qw(all visible selected)],
				default => $actionParams{'action.edit.scope'}[0] || 'selected',
				class   => 'form-select form-select-sm',
				labels  => {
					all      => $r->maketext('all sets'),
					visible  => $r->maketext('listed sets'),
					selected => $r->maketext('selected sets'),
				}
			})
		)
	);
}

sub edit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;

	my $result;

	my $scope = $actionParams->{"action.edit.scope"}->[0];
	if ($scope eq "all") {
		$result = $r->maketext("editing all sets");
		$self->{visibleSetIDs} = $self->{allSetIDs};
	} elsif ($scope eq "visible") {
		$result = $r->maketext("editing listed sets");
		# leave visibleSetIDs alone
	} elsif ($scope eq "selected") {
		$result = $r->maketext("editing selected sets");
		$self->{visibleSetIDs} = $genericParams->{selected_sets}; # an arrayref
	}
	$self->{editMode} = 1;

	return CGI::div({ class => 'alert alert-success p-1 mb-0' }, $result);
}

sub publish_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;

	return CGI::div(
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'publish_filter_select', class => 'col-form-label col-form-label-sm col-sm-auto' },
				$r->maketext('Choose which sets to be affected') . ':'
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'publish_filter_select',
					name    => 'action.publish.scope',
					values  => [qw(none all visible selected)],
					default => $actionParams{'action.publish.scope'}[0] || 'selected',
					class   => 'form-select form-select-sm',
					labels  => {
						none     => $r->maketext('no sets'),
						all      => $r->maketext('all sets'),
						visible  => $r->maketext('listed sets'),
						selected => $r->maketext('selected sets'),
					}
				})
			)
		),
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'publish_visibility_select', class => 'col-form-label col-form-label-sm col-sm-auto' },
				$r->maketext('Choose visibility of the sets to be affected') . ':'
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'publish_visibility_select',
					name    => 'action.publish.value',
					values  => [ 0, 1 ],
					default => $actionParams{'action.publish.value'}->[0] || '1',
					class   => 'form-select form-select-sm d-inline w-auto',
					labels  => {
						0 => $r->maketext('Hidden'),
						1 => $r->maketext('Visible'),
					}
				})
			)
		)
	);
}

sub publish_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r  = $self->r;
	my $db = $r->db;

	my $result = "";

	my $scope = $actionParams->{"action.publish.scope"}->[0];
	my $value = $actionParams->{"action.publish.value"}->[0];

	my $verb = $value ? $r->maketext("made visible for") : $r->maketext("hidden from");

	my @setIDs;

	if ($scope eq "none") {
		@setIDs = ();
		$result = CGI::div({ class => 'alert alert-danger p-1 mb-0' }, $r->maketext("No change made to any set"));
	} elsif ($scope eq "all") {
		@setIDs = @{ $self->{allSetIDs} };
		$result = $value
			? CGI::div({ class => 'alert alert-success p-1 mb-0' },
				$r->maketext("All sets made visible for all students"))
			: CGI::div({ class => 'alert alert-success p-1 mb-0' }, $r->maketext("All sets hidden from all students"));
	} elsif ($scope eq "visible") {
		@setIDs = @{ $self->{visibleSetIDs} };
		$result = $value
			? CGI::div({ class => 'alert alert-success p-1 mb-0' },
				$r->maketext("All listed sets were made visible for all the students"))
			: CGI::div({ class => 'alert alert-success p-1 mb-0' },
				$r->maketext("All listed sets were hidden from all the students"));
	} elsif ($scope eq "selected") {
		@setIDs = @{ $genericParams->{selected_sets} };
		$result = $value
			? CGI::div({ class => 'alert alert-success p-1 mb-0' },
				$r->maketext("All selected sets made visible for all students"))
			: CGI::div({ class => 'alert alert-success p-1 mb-0' },
				$r->maketext("All selected sets hidden from all students"));
	}

	# Can we use UPDATE here, instead of fetch/change/store?
	my @sets = $db->getGlobalSets(@setIDs);
	map { $_->visible($value); $db->putGlobalSet($_); } @sets;

	return CGI::div({ class => 'alert alert-success p-1 mb-0' }, $result);
}

sub score_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;

	return CGI::div(
		{ class => 'row mb-2' },
		CGI::label(
			{ for => 'score_select', class => 'col-form-label col-form-label-sm col-auto' },
			$r->maketext('Score which sets?')
		),
		CGI::div(
			{ class => 'col-auto' },
			CGI::popup_menu({
				id      => 'score_select',
				name    => 'action.score.scope',
				values  => [qw(none all selected)],
				default => $actionParams{'action.score.scope'}[0] || 'none',
				class   => 'form-select form-select-sm',
				labels  => {
					none     => $r->maketext('no sets'),
					all      => $r->maketext('all sets'),
					selected => $r->maketext('selected sets'),
				}
			})
		)
	);
}

sub score_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r      = $self->r;
	my $urlpath = $r->urlpath;
	my $courseName = $urlpath->arg("courseID");

	my $scope = $actionParams->{"action.score.scope"}->[0];
	my @setsToScore;

	if ($scope eq "none") {
		@setsToScore = ();
		return $r->maketext("No sets selected for scoring");
	} elsif ($scope eq "all") {
		@setsToScore = @{ $self->{allSetIDs} };
	} elsif ($scope eq "visible") {
		@setsToScore = @{ $self->{visibleSetIDs} };
	} elsif ($scope eq "selected") {
		@setsToScore = @{ $genericParams->{selected_sets} };
	}

	my $uri = $self->systemLink( $urlpath->newFromModule('WeBWorK::ContentGenerator::Instructor::Scoring',$r, courseID=>$courseName),
					params=>{
						scoreSelected=>"Score Selected",
						selectedSet=>\@setsToScore,
#						recordSingleSetScores=>''
					}
	);


	return $uri;
}


sub delete_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;

	return CGI::div(
		CGI::div(
			{ class => 'd-inline-block alert alert-danger p-1 mb-2' },
			CGI::em($r->maketext('Warning: Deletion destroys all set-related data and is not undoable!'))
		),
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'delete_select', class => 'col-form-label col-form-label-sm col-auto' },
				$r->maketext('Delete which sets?')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'delete_select',
					name    => 'action.delete.scope',
					values  => [qw(none selected)],
					default => $actionParams{'action.delete.scope'}[0] || 'none',
					class   => 'form-select form-select-sm',
					labels  => {
						none     => $r->maketext('no sets'),
						selected => $r->maketext('selected sets'),
					}
				})
			)
		)
	);
}

sub delete_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r  = $self->r;
	my $db = $r->db;

	my $scope = $actionParams->{"action.delete.scope"}->[0];

	my @setIDsToDelete = ();

	if ($scope eq "selected") {
		@setIDsToDelete = @{ $self->{selectedSetIDs} };
	}

	my %allSetIDs      = map { $_ => 1 } @{ $self->{allSetIDs} };
	my %visibleSetIDs  = map { $_ => 1 } @{ $self->{visibleSetIDs} };
	my %selectedSetIDs = map { $_ => 1 } @{ $self->{selectedSetIDs} };

	foreach my $setID (@setIDsToDelete) {
		delete $allSetIDs{$setID};
		delete $visibleSetIDs{$setID};
		delete $selectedSetIDs{$setID};
		$db->deleteGlobalSet($setID);
	}

	$self->{allSetIDs}      = [ keys %allSetIDs ];
	$self->{visibleSetIDs}  = [ keys %visibleSetIDs ];
	$self->{selectedSetIDs} = [ keys %selectedSetIDs ];

	my $num = @setIDsToDelete;
	return CGI::div({ class => 'alert alert-success p-1 mb-0' }, $r->maketext('deleted [_1] sets', $num));
}

sub create_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;

	return CGI::div(
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'create_text', class => 'col-form-label col-form-label-sm col-auto' },
				$r->maketext('Name the new set') . CGI::span({ class => 'required-field' }, '*') . ':'
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::textfield({
					id            => 'create_text',
					name          => 'action.create.name',
					value         => $actionParams{'action.create.name'}[0] || '',
					maxlength     => '100',
					aria_required => 'true',
					class         => 'form-control form-control-sm',
					dir           => 'ltr'
				})
			)
		),
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'create_select', class => 'col-form-label col-form-label-sm col-auto' },
				$r->maketext("Create as what type of set?")
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'create_select',
					name    => 'action.create.type',
					values  => [qw(empty copy)],
					default => $actionParams{'action.create.type'}[0] || 'empty',
					class   => 'form-select form-select-sm',
					labels  => {
						empty => $r->maketext('a new empty set'),
						copy  => $r->maketext('a duplicate of the first selected set'),
					}
				})
			)
		)
	);
}

sub create_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r      = $self->r;
	my $db     = $r->db;
	my $ce     = $r->ce;

	my $newSetID = format_set_name_internal($actionParams->{'action.create.name'}[0] // '');
	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		$r->maketext("Failed to create new set: set name cannot exceed 100 characters."))
		if (length($newSetID) > 100);
	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		$r->maketext("Failed to create new set: no set name specified!"))
		unless $newSetID =~ /\S/;
	return CGI::div(
		{ class => 'alert alert-danger p-1 mb-0' },
		$r->maketext(
			"The set name '[_1]' is already in use.  Pick a different name if you would like to start a new set.",
			$newSetID)
			. " "
			. $r->maketext("No set created.")
	) if $db->existsGlobalSet($newSetID);

	my $newSetRecord = $db->newGlobalSet;
	my $oldSetID = $self->{selectedSetIDs}->[0];

	my $type = $actionParams->{"action.create.type"}->[0];
	# It's convenient to set the due date two weeks from now so that it is
	# not accidentally available to students.

	my $dueDate = time+2*ONE_WEEK();
	my $display_tz = $ce->{siteDefaults}{timezone};
	my $fDueDate = $self->formatDateTime($dueDate, $display_tz, "%m/%d/%Y at %I:%M%P");
	my $dueTime = $ce->{pg}{timeAssignDue};

	# We replace the due time by the one from the config variable
	# and try to bring it back to unix time if possible
	$fDueDate =~ s/\d\d:\d\d(am|pm|AM|PM)/$dueTime/;

	$dueDate = $self->parseDateTime($fDueDate, $display_tz);

	if ($type eq "empty") {
		$newSetRecord->set_id($newSetID);
		$newSetRecord->set_header("defaultHeader");
		$newSetRecord->hardcopy_header("defaultHeader");
		#Rest of the dates are set according to to course configuration
		$newSetRecord->open_date($dueDate - 60*$ce->{pg}{assignOpenPriorToDue});
		$newSetRecord->reduced_scoring_date($dueDate - 60*$ce->{pg}{ansEvalDefaults}{reducedScoringPeriod});
		$newSetRecord->due_date($dueDate);
		$newSetRecord->answer_date($dueDate + 60*$ce->{pg}{answersOpenAfterDueDate});
		$newSetRecord->visible(DEFAULT_VISIBILITY_STATE());	# don't want students to see an empty set
		$newSetRecord->enable_reduced_scoring(DEFAULT_ENABLED_REDUCED_SCORING_STATE());
		$newSetRecord->assignment_type('default');
		$db->addGlobalSet($newSetRecord);
	} elsif ($type eq "copy") {
		return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
			$r->maketext('Failed to duplicate set: no set selected for duplication!'))
			unless $oldSetID =~ /\S/;
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
		if ( $newSetRecord->restricted_login_proctor eq 'Yes' ) {
			my $procUser = $db->getUser("set_id:$oldSetID");
			$procUser->user_id("set_id:$newSetID");
			eval { $db->addUser( $procUser ) };
			if ( ! $@ ) {
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
	my $userName = $r->param('user');
	$self->assignSetToUser($userName, $newSetRecord);    # Cures weird date error when no-one assigned to set.
	$self->addgoodmessage($r->maketext(
		'Set [_1] was assigned to [_2].',
		CGI::span({ dir => 'ltr' }, format_set_name_display($newSetID)), $userName
	));

	push @{ $self->{visibleSetIDs} }, $newSetID;
	push @{ $self->{allSetIds} }, $newSetID;

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' }, $r->maketext('Failed to create new set: [_1]', $@))
		if $@;

	return CGI::div(
		{ class => 'alert alert-success p-1 mb-0' },
		$r->maketext(
			'Successfully created new set [_1]',
			CGI::span({ dir => 'ltr' }, format_set_name_display($newSetID))
		)
	);
}

sub import_form {
	my ($self, %actionParams) = @_;

	my $r     = $self->r;
	my $authz = $r->authz;
	my $user  = $r->param('user');
	my $ce    = $r->ce;

	return CGI::div(
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'import_amt_select', class => 'col-form-label col-form-label-sm col-md-auto' },
				$r->maketext('Import how many sets?')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'import_amt_select',
					name    => 'action.import.number',
					values  => [ 1, 8 ],
					default => $actionParams{'action.import.number'}[0] || '1',
					class   => 'form-select form-select-sm',
					labels  => {
						1 => $r->maketext('a single set'),
						8 => $r->maketext('multiple sets'),
					}
				})
			)
		),
		CGI::div(
			{ class => 'row align-items-center mb-2' },
			CGI::label(
				{ for => 'import_source_select', class => 'col-form-label col-form-label-sm col-md-auto' },
				$r->maketext('Import from where?')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					name    => 'action.import.source',
					id      => 'import_source_select',
					values  => [ '', $self->getDefList() ],
					labels  => { '' => $r->maketext('Enter filenames below') },
					default => defined($actionParams{'action.import.source'})
					? $actionParams{'action.import.source'}
					: '',
					class => 'form-select form-select-sm',
					size  => $actionParams{'action.import.number'}[0] || '1',
					defined($actionParams{'action.import.number'}[0])
						&& $actionParams{'action.import.number'}[0] ne '1' ? (multiple => undef) : ()
				})
			)
		),
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'import_text', class => 'col-form-label col-form-label-sm col-md-auto' },
				$r->maketext('Import sets with names') . ':'
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::textfield({
					id    => 'import_text',
					name  => 'action.import.name',
					value => $actionParams{'action.import.name'}[0] || '',
					class => 'form-control form-control-sm',
					dir   => 'ltr'
				})
			)
		),
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'import_date_shift', class => 'col-form-label col-form-label-sm col-md-auto' },
				$r->maketext('Shift dates so that the earliest is') . ':'
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::div(
					{ class => 'input-group input-group-sm flatpickr' },
					CGI::textfield({
						id             => 'import_date_shift',
						name           => 'action.import.start.date',
						size           => '27',
						value          => $actionParams{'action.import.start.date'}[0] || '',
						class          => 'form-control',
						data_input     => undef,
						data_done_text => $r->maketext('Done'),
						data_locale    => $ce->{language},
						data_timezone  => $ce->{siteDefaults}{timezone}
					}),
					CGI::a(
						{
							class       => 'btn btn-secondary btn-sm',
							data_toggle => undef,
							role        => 'button',
							tabindex    => 0,
							aria_label  => $r->maketext('Pick date and time')
						},
						CGI::i({ class => 'fas fa-calendar-alt' }, '')
					)
				)
			)
		),
		$authz->hasPermissions($user, 'assign_problem_sets') ? CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'import_users_select', class => 'col-form-label col-form-label-sm col-md-auto' },
				$r->maketext('Assign this set to which users?')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'import_users_select',
					name    => 'action.import.assign',
					value   => [qw(user all)],
					default => $actionParams{'action.import.assign'}[0] || 'none',
					class   => 'form-select form-select-sm',
					labels  => {
						all  => $r->maketext('all current users') . '.',
						user => $r->maketext('only') . ' ' . $user . '.',
					}
				})
			)
		) : ''    #user does not have permissions to assign problem sets
	);
}

sub import_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;

	my ($added, $skipped) = $self->importSetsFromDef(
		$actionParams->{"action.import.number"}[0] > 1
		? ''    # Cannot assign set names to multiple imports.
		: format_set_name_internal($actionParams->{'action.import.name'}[0]),
		$actionParams->{'action.import.assign'}[0],
		$actionParams->{'action.import.start.date'}[0] // 0,
		@{ $actionParams->{'action.import.source'} }
	);

	# Make new sets visible.
	push @{ $self->{visibleSetIDs} }, @$added;
	push @{ $self->{allSetIDs} },     @$added;

	my $numAdded   = @$added;
	my $numSkipped = @$skipped;

	return CGI::div(
		{ class => 'alert alert-success p-1 mb-0' },
		$r->maketext(
			'[_1] sets added, [_2] sets skipped. Skipped sets: ([_3])',
			$numAdded, $numSkipped, join(', ', @$skipped)
		)
	);
}

sub export_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;

	return CGI::div(
		{ class => 'row mb-2' },
		CGI::label(
			{ for => 'export_select', class => 'col-form-label col-form-label-sm col-auto' },
			$r->maketext('Prepare which sets for export?')
		),
		CGI::div(
			{ class => 'col-auto' },
			CGI::popup_menu({
				id      => 'export_select',
				name    => 'action.export.scope',
				values  => [qw(all visible selected)],
				default => $actionParams{'action.export.scope'}[0] || 'visible',
				class   => 'form-select form-select-sm',
				labels  => {
					all      => $r->maketext('all sets'),
					visible  => $r->maketext('listed sets'),
					selected => $r->maketext('selected sets'),
				}
			})
		)
	);
}

# this does not actually export any files, rather it sends us to a new page in order to export the files
sub export_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;

	my $result;

	my $scope = $actionParams->{"action.export.scope"}->[0];
	if ($scope eq "all") {
		$result = $r->maketext("All sets were selected for export.");
		$self->{selectedSetIDs} = $self->{visibleSetIDs} = $self->{allSetIDs};
	} elsif ($scope eq "visible") {
		$result = $r->maketext("Visible sets were selected for export.");
		$self->{selectedSetIDs} = $self->{visibleSetIDs};
	} elsif ($scope eq "selected") {
		$result = $r->maketext("Sets were selected for export.");
		$self->{selectedSetIDs} = $self->{visibleSetIDs} = $genericParams->{selected_sets}; # an arrayref
	}
	$self->{exportMode} = 1;

	return CGI::div({ class => 'alert alert-success p-1 mb-0' }, $result);
}

sub cancelExport_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;
	return CGI::span($r->maketext('Abandon export'));
}

sub cancelExport_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r      = $self->r;

	#$self->{selectedSetIDs) = $self->{visibleSetIDs};
		# only do the above if we arrived here via "edit selected users"
	if (defined $r->param("prev_visible_sets")) {
		$self->{visibleSetIDs} = [ $r->param("prev_visible_sets") ];
	} elsif (defined $r->param("no_prev_visible_sets")) {
		$self->{visibleSetIDs} = [];
	} else {
		# leave it alone
	}
	$self->{exportMode} = 0;

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' }, $r->maketext('export abandoned'));
}

sub saveExport_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;
	return CGI::span($r->maketext('Confirm which sets to export.'));
}

sub saveExport_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r           = $self->r;

	my @setIDsToExport = @{ $self->{selectedSetIDs} };

	my %filenames = map { $_ => (@{ $tableParams->{"set.$_"} }[0] || $_) } @setIDsToExport;

	my ($exported, $skipped, $reason) = $self->exportSetsToDef(%filenames);

	if (defined $r->param("prev_visible_sets")) {
		$self->{visibleSetIDs} = [ $r->param("prev_visible_sets") ];
	} elsif (defined $r->param("no_prev_visble_sets")) {
		$self->{visibleSetIDs} = [];
	} else {
		# leave it alone
	}

	$self->{exportMode} = 0;

	my $numExported = @$exported;
	my $numSkipped = @$skipped;
	my $resultFont = $numSkipped ? 'alert-danger' : 'alert-success';

	my @reasons = map { "set $_ - " . $reason->{$_} } keys %$reason;

	return CGI::div(
		{ class => "alert $resultFont p-1 mb-0" },
		$r->maketext(
			'[_1] sets exported, [_2] sets skipped. Skipped sets: ([_3])',
			$numExported, $numSkipped, ($numSkipped) ? CGI::ul(CGI::li(\@reasons)) : ''
		)
	);
}

sub cancelEdit_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;
	return CGI::span($r->maketext('Abandon changes'));
}

sub cancelEdit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r      = $self->r;

	#$self->{selectedSetIDs) = $self->{visibleSetIDs};
		# only do the above if we arrived here via "edit selected users"
	if (defined $r->param("prev_visible_sets")) {
		$self->{visibleSetIDs} = [ $r->param("prev_visible_sets") ];
	} elsif (defined $r->param("no_prev_visible_sets")) {
		$self->{visibleSetIDs} = [];
	} else {
		# leave it alone
	}
	$self->{editMode} = 0;

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' }, $r->maketext('changes abandoned'));
}

sub saveEdit_form {
	my ($self, %actionParams) = @_;
	my $r = $self->r;
	return CGI::span($r->maketext('Save changes'));
}

sub saveEdit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r           = $self->r;
	my $db          = $r->db;
	my $ce          = $r->ce;

	my @visibleSetIDs = @{ $self->{visibleSetIDs} };
	foreach my $setID (@visibleSetIDs) {
	        next unless defined($setID);
		my $Set = $db->getGlobalSet($setID); # checked
		# FIXME: we may not want to die on bad sets, they're not as bad as bad users
		die "record for visible set $setID not found" unless $Set;

		foreach my $field ($Set->NONKEYFIELDS()) {
			my $param = "set.${setID}.${field}";
			if (defined $tableParams->{$param}[0]) {
				if ($field =~ /_date/) {
					$Set->$field($tableParams->{$param}[0]);
				} elsif ($field eq 'enable_reduced_scoring') {
					# If we are enableing reduced scoring, make sure the reduced scoring date
					# is set and in a proper interval.
					my $value = $tableParams->{$param}[0];
					$Set->enable_reduced_scoring($value);
					if (!$Set->reduced_scoring_date) {
						$Set->reduced_scoring_date(
							$Set->due_date - 60 * $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod});
					}
				} else {
					$Set->$field($tableParams->{$param}->[0]);
				}
			}
		}

		# make sure the dates are not more than 10 years in the future
		my $curr_time = time;
		my $seconds_per_year = 31_556_926;
		my $cutoff = $curr_time + $seconds_per_year*10;
		return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
			$r->maketext("Error: open date cannot be more than 10 years from now in set [_1]", $setID))
			if $Set->open_date > $cutoff;
		return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
			$r->maketext("Error: close date cannot be more than 10 years from now in set [_1]", $setID))
			if $Set->due_date > $cutoff;
		return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
			$r->maketext("Error: answer date cannot be more than 10 years from now in set [_1]", $setID))
			if $Set->answer_date > $cutoff;

		# Check that the open, due and answer dates are in increasing order.
		# Bail if this is not correct.
		if ($Set->open_date > $Set->due_date) {
			return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
				$r->maketext("Error: Close date must come after open date in set [_1]", $setID));
		}
		if ($Set->due_date > $Set->answer_date) {
			return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
				$r->maketext("Error: Answer date must come after close date in set [_1]", $setID));
		}

		# check that the reduced scoring date is in the right place
		my $enable_reduced_scoring =
		    $ce->{pg}{ansEvalDefaults}{enableReducedScoring} &&
		    (defined($r->param("set.$setID.enable_reduced_scoring")) ?
		    $r->param("set.$setID.enable_reduced_scoring") :
		     $Set->enable_reduced_scoring);

		if ($enable_reduced_scoring &&
		    $Set->reduced_scoring_date
		    && ($Set->reduced_scoring_date > $Set->due_date
			|| $Set->reduced_scoring_date < $Set->open_date)) {
			return CGI::div(
				{ class => 'alert alert-danger p-1 mb-0' },
				$r->maketext(
					"Error: Reduced scoring date must come between the open date and close date in set [_1]", $setID
				)
			);
		}

		$db->putGlobalSet($Set);
	}

	if (defined $r->param("prev_visible_sets")) {
		$self->{visibleSetIDs} = [ $r->param("prev_visible_sets") ];
	} elsif (defined $r->param("no_prev_visble_sets")) {
		$self->{visibleSetIDs} = [];
	} else {
		# leave it alone
	}

	$self->{editMode} = 0;

	return CGI::div({ class => 'alert alert-success p-1 mb-0' }, $r->maketext("changes saved"));
}

################################################################################
# utilities
################################################################################

sub importSetsFromDef {
	my ($self, $newSetName, $assign, $startdate, @setDefFiles) = @_;
	my $r     = $self->r;
	my $ce    = $r->ce;
	my $db    = $r->db;
	my $dir   = $ce->{courseDirs}->{templates};
	my $mindate = 0;

	# if the user includes "following files" in a multiple selection
	# it shows up here as "" which causes the importing to die
	# so, we select on filenames containing non-whitespace
	@setDefFiles = grep(/\S/, @setDefFiles);

	# FIXME: do we really want everything to fail on one bad file name?
	foreach my $fileName (@setDefFiles) {
		die $r->maketext("won't be able to read from file [_1]/[_2]: does it exist? is it readable?", $dir, $fileName)
			unless -r "$dir/$fileName";
	}

	# Get a list of set ids of existing sets in the course.  This is used to
	# ensure that an imported set does not already exist.
	my %allSets = map { $_ => 1 } @{ $self->{allSetIDs} };

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
		) = $self->readSetDef($set_definition_file);
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
		eval {$db->addGlobalSet($newSetRecord)};
		die $r->maketext("addGlobalSet [_1] in ProblemSetList:  [_2]", $setName, $@) if $@;

		#do we need to add locations to the set_locations table?
		if ( $restrictIP ne 'No' && $restrictLoc ) {
			if ($db->existsLocation( $restrictLoc ) ) {
				if ( ! $db->existsGlobalSetLocation($setName,$restrictLoc) ) {
					my $newSetLocation = $db->newGlobalSetLocation;
					$newSetLocation->set_id( $setName );
					$newSetLocation->location_id( $restrictLoc );
					eval {$db->addGlobalSetLocation($newSetLocation)};
					warn($r->maketext("error adding set location [_1] for set [_2]: [_3]", $restrictLoc, $setName, $@)) if $@;
				} else {
					# this should never happen.
					warn($r->maketext("input set location [_1] already exists for set [_2].", $restrictLoc, $setName)."\n");
				}
			} else {
				warn($r->maketext("restriction location [_1] does not exist.  IP restrictions have been ignored.", $restrictLoc)."\n");
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
			$self->addProblemToSet(
				setName           => $setName,
				sourceFile        => $rh_problem->{source_file},
				problemID         => $rh_problem->{problemID} ? $rh_problem->{problemID} : $freeProblemID++,
				value             => $rh_problem->{value},
				maxAttempts       => $rh_problem->{max_attempts},
				showMeAnother     => $rh_problem->{showMeAnother},
				prPeriod          => $rh_problem->{prPeriod},
				attToOpenChildren => $rh_problem->{attToOpenChildren},
				countsParentGrade => $rh_problem->{countsParentGrade}
			);
		}

		if ($assign eq "all") {
			$self->assignSetToAllUsers($setName);
		}
		else {
			my $userName = $r->param('user');
			$self->assignSetToUser($userName, $newSetRecord); ## always assign set to instructor
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

sub readSetDef {
	my ($self, $fileName) = @_;
	my $templateDir   = $self->{ce}->{courseDirs}->{templates};
	my $filePath      = "$templateDir/$fileName";
	my $weight_default = $self->{ce}->{problemDefaults}->{value};
	my $max_attempts_default = $self->{ce}->{problemDefaults}->{max_attempts};
	my $att_to_open_children_default =
	    $self->{ce}->{problemDefaults}->{att_to_open_children};
	my $counts_parent_grade_default =
	    $self->{ce}->{problemDefaults}->{counts_parent_grade};
	my $showMeAnother_default = $self->{ce}->{problemDefaults}->{showMeAnother};
	my $prPeriod_default=$self->{ce}->{problemDefaults}->{prPeriod};

	my $setName = '';

	my $r = $self->r;

	if ($fileName =~ m|^(.*/)?set([.\w-]+)\.def$|) {
		$setName = $2;
	} else {
		$self->addbadmessage(
		    qq{The setDefinition file name must begin with   <CODE>set</CODE>},
			qq{and must end with   <CODE>.def</CODE>  . Every thing in between becomes the name of the set. },
			qq{For example <CODE>set1.def</CODE>, <CODE>setExam.def</CODE>, and <CODE>setsample7.def</CODE> },
			qq{define sets named <CODE>1</CODE>, <CODE>Exam</CODE>, and <CODE>sample7</CODE> respectively. },
			qq{The filename, $fileName, you entered is not legal\n }
		);

	}

	my ($line, $name, $weight, $attemptLimit, $continueFlag);
	my $paperHeaderFile = '';
	my $screenHeaderFile = '';
	my $description = '';
	my ($dueDate, $openDate, $reducedScoringDate, $answerDate);
	my @problemData;

# added fields for gateway test/versioned set definitions:
	my ( $assignmentType, $attemptsPerVersion, $timeInterval, $enableReducedScoring,
	     $versionsPerInterval, $versionTimeLimit, $problemRandOrder,
	     $problemsPerPage, $restrictLoc,
	     $emailInstructor, $restrictProbProgression,
	     $countsParentGrade, $attToOpenChildren,
	     $problemID, $showMeAnother, $prPeriod, $listType
	     ) =
		 ('')x16;  # initialize these to ''
	my ( $timeCap, $restrictIP, $relaxRestrictIP ) = ( 0, 'No', 'No');
# additional fields currently used only by gateways; later, the world?
	my ( $hideScore, $hideScoreByProblem, $hideWork, ) = ( 'N', 'N', 'N' );

	my %setInfo;
	if ( open (SETFILENAME, "$filePath") )    {
	#####################################################################
	# Read and check set data
	#####################################################################
		while (<SETFILENAME>) {

			chomp($line = $_);
			$line =~ s|(#.*)||;                              ## don't read past comments
			unless ($line =~ /\S/) {next;}                   ## skip blank lines
			$line =~ s|\s*$||;                               ## trim trailing spaces
			$line =~ m|^\s*(\w+)\s*=?\s*(.*)|;

			######################
			# sanity check entries
			######################
			my $item = $1;
			$item    = '' unless defined $item;
			my $value = $2;
			$value    = '' unless defined $value;

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
				$hideScore = ( $value ) ? $value : 'N';
			} elsif ($item eq 'hideScoreByProblem') {
				$hideScoreByProblem = ( $value ) ? $value : 'N';
			} elsif ($item eq 'hideWork') {
				$hideWork = ( $value ) ? $value : 'N';
			} elsif ($item eq 'capTimeLimit') {
				$timeCap = ( $value ) ? 1 : 0;
			} elsif ($item eq 'restrictIP') {
				$restrictIP = ( $value ) ? $value : 'No';
			} elsif ($item eq 'restrictLocation' ) {
				$restrictLoc = ( $value ) ? $value : '';
			} elsif ( $item eq 'relaxRestrictIP' ) {
			    $relaxRestrictIP = ( $value ) ? $value : 'No';
			} elsif ( $item eq 'emailInstructor' ) {
			    $emailInstructor = ( $value ) ? $value : 0;
			} elsif ( $item eq 'restrictProbProgression' ) {
			    $restrictProbProgression = ( $value ) ? $value : 0;
			} elsif ( $item eq 'description' ) {
			    $value =~ s/<n>/\n/g;
			    $description = $value;
			} elsif ($item eq 'problemList' ||
			    $item eq 'problemListV2') {
			    $listType = $item;
				last;
			} else {
				warn $r->maketext("readSetDef error, can't read the line: ||[_1]||", $line);
			}
		}

		#####################################################################
		# Check and format dates
		#####################################################################
		my ($time1, $time2, $time3) = map {  $self->parseDateTime($_);  }    ($openDate, $dueDate, $answerDate);

		unless ($time1 <= $time2 and $time2 <= $time3) {
			warn $r->maketext("The open date: [_1], close date: [_2], and answer date: [_3] must be defined and in chronological order.", $openDate, $dueDate, $answerDate);
		}

		# validate reduced credit date

		# Special handling for values which seem to roughly correspond to epoch 0.
		#    namely if the date string contains 12/31/1969 or 01/01/1970
		if ($reducedScoringDate) {
			if ( ( $reducedScoringDate =~ m+12/31/1969+ ) || ( $reducedScoringDate =~ m+01/01/1970+ ) ) {
				my $origReducedScoringDate = $reducedScoringDate;
				$reducedScoringDate = $self->parseDateTime($reducedScoringDate);
				if ( $reducedScoringDate != 0 ) {
					# In this case we want to treat it BY FORCE as if the value did correspond to epoch 0.
					warn $r->maketext("The reduced credit date [_1] in the file probably was generated from the Unix epoch 0 value and is being treated as if it was Unix epoch 0.", $origReducedScoringDate );
					$reducedScoringDate = 0;
				}
			} else {
				# Original behavior, which may cause problems for some time-zones when epoch 0 was set and does not parse back to 0
				$reducedScoringDate = $self->parseDateTime($reducedScoringDate);
			}
		}

		if ($reducedScoringDate) {
			if ($reducedScoringDate < $time1 || $reducedScoringDate > $time2) {
				warn $r->maketext("The reduced credit date should be between the open date [_1] and close date [_2]", $openDate, $dueDate);
			} elsif ( $reducedScoringDate == 0 && $enableReducedScoring ne 'Y' ) {
				# In this case - the date in the file was Unix epoch 0 (or treated as such),
				# and unless $enableReducedScoring eq 'Y' we will leave it as 0.
			}
		} else {
		    $reducedScoringDate = $time2 - 60*$r->{ce}->{pg}{ansEvalDefaults}{reducedScoringPeriod};
		}

		if ($enableReducedScoring ne '' && $enableReducedScoring eq 'Y') {
		    $enableReducedScoring = 1;
		} elsif ($enableReducedScoring ne '' && $enableReducedScoring eq 'N') {
		    $enableReducedScoring = 0;
		} elsif ($enableReducedScoring ne '') {
		    warn($r->maketext("The value [_1] for enableReducedScoring is not valid; it will be replaced with 'N'.",$enableReducedScoring)."\n");
		    $enableReducedScoring = 0;
		} else {
		    $enableReducedScoring = DEFAULT_ENABLED_REDUCED_SCORING_STATE;
		}

		# Check header file names
		$paperHeaderFile =~ s/(.*?)\s*$/$1/;   #remove trailing white space
		$screenHeaderFile =~ s/(.*?)\s*$/$1/;   #remove trailing white space

                #####################################################################
                # Gateway/version variable cleanup: convert times into seconds
		$assignmentType ||= 'default';

		$timeInterval = WeBWorK::Utils::timeToSec( $timeInterval )
		    if ( $timeInterval );
		$versionTimeLimit = WeBWorK::Utils::timeToSec($versionTimeLimit)
		    if ( $versionTimeLimit );

		# check that the values for hideWork and hideScore are valid
		if ( $hideScore ne 'N' && $hideScore ne 'Y' &&
		     $hideScore ne 'BeforeAnswerDate' ) {
			warn($r->maketext("The value [_1] for the hideScore option is not valid; it will be replaced with 'N'.", $hideScore)."\n");
			$hideScore = 'N';
		}
		if ( $hideScoreByProblem ne 'N' && $hideScoreByProblem ne 'Y' &&
		     $hideScoreByProblem ne 'BeforeAnswerDate' ) {
			warn($r->maketext("The value [_1] for the hideScore option is not valid; it will be replaced with 'N'.", $hideScoreByProblem)."\n");
			$hideScoreByProblem = 'N';
		}
		if ( $hideWork ne 'N' && $hideWork ne 'Y' &&
		     $hideWork ne 'BeforeAnswerDate' ) {
			warn($r->maketext("The value [_1] for the hideWork option is not valid; it will be replaced with 'N'.", $hideWork)."\n");
			$hideWork = 'N';
		}
		if ( $timeCap ne '0' && $timeCap ne '1' ) {
			warn($r->maketext("The value [_1] for the capTimeLimit option is not valid; it will be replaced with '0'.", $timeCap)."\n");
			$timeCap = '0';
		}
		if ( $restrictIP ne 'No' && $restrictIP ne 'DenyFrom' &&
		     $restrictIP ne 'RestrictTo' ) {
			warn($r->maketext("The value [_1] for the restrictIP option is not valid; it will be replaced with 'No'.", $restrictIP)."\n");
			$restrictIP = 'No';
			$restrictLoc = '';
			$relaxRestrictIP = 'No';
		}
		if ( $relaxRestrictIP ne 'No' &&
		     $relaxRestrictIP ne 'AfterAnswerDate' &&
		     $relaxRestrictIP ne 'AfterVersionAnswerDate' ) {
			warn($r->maketext("The value [_1] for the relaxRestrictIP option is not valid; it will be replaced with 'No'.", $relaxRestrictIP)."\n");
			$relaxRestrictIP = 'No';
		}
		# to verify that restrictLoc is valid requires a database
		#    call, so we defer that until we return to add the set

		#####################################################################
		# Read and check list of problems for the set
		#####################################################################


		# NOTE:  There are now two versions of problemList, the first is an unlabeled
		# list which may or may not contain a showMeAnother variable.  This is supported
		# but the unlabeled list is hard to work with.  The new version prints a
		# labeled list of values similar to how its done for the set variables

		if ($listType eq 'problemList') {


		    while(<SETFILENAME>) {
			chomp($line=$_);
			$line =~ s/(#.*)//;                             ## don't read past comments
			unless ($line =~ /\S/) {next;}                  ## skip blank lines

			# commas are valid in filenames, so we have to handle commas
			# using backslash escaping, so \X will be replaced with X
			my @line = ();
			my $curr = '';
			for (my $i = 0; $i < length $line; $i++) {
			    my $c = substr($line,$i,1);
			    if ($c eq '\\') {
				$curr .= substr($line,++$i,1);
			    } elsif ($c eq ',') {
				push @line, $curr;
				$curr = '';
			    } else {
				$curr .= $c;
			    }
			}
			## anything left?
			push(@line, $curr) if ( $curr );

			# read the line and only look for $showMeAnother if it has the correct number of entries
			# otherwise the default value will be used
			if(scalar(@line)==4){
			    ($name, $weight, $attemptLimit, $showMeAnother, $continueFlag) = @line;
			} else {
			    ($name, $weight, $attemptLimit, $continueFlag) = @line;
			}

			#####################
			#  clean up problem values
			###########################
			$name =~ s/\s*//g;
			$weight = "" unless defined($weight);
			$weight =~ s/[^\d\.]*//g;
			unless ($weight =~ /\d+/) {$weight = $weight_default;}
			$attemptLimit = "" unless defined($attemptLimit);
			$attemptLimit =~ s/[^\d-]*//g;
			unless ($attemptLimit =~ /\d+/) {$attemptLimit = $max_attempts_default;}
			$continueFlag = "0" unless( defined($continueFlag) && @problemData );
			# can't put continuation flag onto the first problem
			push(@problemData, {source_file    => $name,
			                    value          =>  $weight,
			                    max_attempts   => $attemptLimit,
			                    showMeAnother   => $showMeAnother,
			                    # use default since it's not going to be in the file
			                    prPeriod		=> $prPeriod_default,
			                    continuation   => $continueFlag,
			     });
		    }
		} else {

		    # This is the new version, it looks for pairs of entries
		    # of the form field name = value
		    while (<SETFILENAME>) {

			chomp($line = $_);
			$line =~ s|(#.*)||;                              ## don't read past comments
			unless ($line =~ /\S/) {next;}                   ## skip blank lines
			$line =~ s|\s*$||;                               ## trim trailing spaces
			$line =~ m|^\s*(\w+)\s*=?\s*(.*)|;

			######################
			# sanity check entries
			######################
			my $item = $1;
			$item    = '' unless defined $item;
			my $value = $2;
			$value    = '' unless defined $value;

			if ($item eq 'problem_start') {
			    next;
			} elsif ($item eq 'source_file') {
			    warn($r->maketext('No source_file for problem in .def file')) unless $value;
			    $name = $value;
			} elsif ($item eq 'value' ) {
			    $weight = ( $value ) ? $value : $weight_default;
			} elsif ( $item eq 'max_attempts' ) {
			    $attemptLimit = ( $value ) ? $value : $max_attempts_default;
			} elsif ( $item eq 'showMeAnother' ) {
			    $showMeAnother = ( $value ) ? $value : 0;
			} elsif ( $item eq 'prPeriod' ) {
			    $prPeriod = ( $value ) ? $value : 0;
			} elsif ( $item eq 'restrictProbProgression' ) {
			    $restrictProbProgression = ( $value ) ? $value : 'No';
			} elsif ( $item eq 'problem_id' ) {
			    $problemID = ( $value ) ? $value : '';
			} elsif ( $item eq 'counts_parent_grade' ) {
			    $countsParentGrade = ( $value ) ? $value : 0;
			} elsif ( $item eq 'att_to_open_children' ) {
			    $attToOpenChildren = ( $value ) ? $value : 0;
			} elsif ($item eq 'problem_end') {

			    #####################
			    #  clean up problem values
			    ###########################
			    $name =~ s/\s*//g;
			    $weight = "" unless defined($weight);
			    $weight =~ s/[^\d\.]*//g;
			    unless ($weight =~ /\d+/) {$weight = $weight_default;}
			    $attemptLimit = "" unless defined($attemptLimit);
			    $attemptLimit =~ s/[^\d-]*//g;
			    unless ($attemptLimit =~ /\d+/) {$attemptLimit = $max_attempts_default;}

			    unless ($countsParentGrade =~ /(0|1)/) {$countsParentGrade = $counts_parent_grade_default;}
			    $countsParentGrade =~ s/[^\d-]*//g;

			    unless ($showMeAnother =~ /-?\d+/) {$showMeAnother = $showMeAnother_default;}
			    $showMeAnother =~ s/[^-?\d-]*//g;

			    unless ($prPeriod =~ /-?\d+/) {$prPeriod = $prPeriod_default;}
			    $prPeriod =~ s/[^-?\d-]*//g;

			    unless ($attToOpenChildren =~ /\d+/) {$attToOpenChildren = $att_to_open_children_default;}
			    $attToOpenChildren =~ s/[^\d-]*//g;

			    if ($assignmentType eq 'jitar') {
				unless ($problemID =~ /[\d\.]+/) {$problemID = '';}
				$problemID =~ s/[^\d\.-]*//g;
				$problemID = seq_to_jitar_id(split(/\./,$problemID));
			    } else {
				unless ($problemID =~ /\d+/) {$problemID = '';}
				$problemID =~ s/[^\d-]*//g;
			    }

			    # can't put continuation flag onto the first problem
			    push(@problemData, {source_file    => $name,
						problemID      => $problemID,
						value          =>  $weight,
						max_attempts   => $attemptLimit,
						showMeAnother  => $showMeAnother,
						prPeriod		=> $prPeriod,
						attToOpenChildren => $attToOpenChildren,
						countsParentGrade => $countsParentGrade,
				 });

			    # reset the various values
			    $name = '';
			    $problemID = '';
			    $weight = '';
			    $attemptLimit = '';
			    $showMeAnother = '';
			    $attToOpenChildren = '';
			    $countsParentGrade = '';

			} else {
			    warn $r->maketext("readSetDef error, can't read the line: ||[_1]||", $line);
			}
		    }


		}

		close(SETFILENAME);
		($setName,
		 $paperHeaderFile,
		 $screenHeaderFile,
		 $time1,
		 $time2,
		 $time3,
		 \@problemData,
		 $assignmentType,
		 $enableReducedScoring,
		 $reducedScoringDate,
		 $attemptsPerVersion, $timeInterval,
		 $versionsPerInterval, $versionTimeLimit, $problemRandOrder,
		 $problemsPerPage,
		 $hideScore,
		 $hideScoreByProblem,
		 $hideWork,
		 $timeCap,
		 $restrictIP,
		 $restrictLoc,
		 $relaxRestrictIP,
		 $description,
		 $emailInstructor,
		 $restrictProbProgression
		);
	} else {
		warn $r->maketext("Can't open file [_1]", $filePath)."\n";
	}
}

sub exportSetsToDef {
	my ($self, %filenames) = @_;

	my $r        = $self->r;
	my $ce       = $r->ce;
	my $db       = $r->db;

	my (@exported, @skipped, %reason);

SET: foreach my $set (keys %filenames) {

		my $fileName = $filenames{$set};
		$fileName .= ".def" unless $fileName =~ m/\.def$/;
		$fileName  = "set" . $fileName unless $fileName =~ m/^set/;
		# files can be exported to sub directories but not parent directories
		if ($fileName =~ /\.\./) {
			push @skipped, $set;
			$reason{$set} = $r->maketext("Illegal filename contains '..'");
			next SET;
		}

		my $setRecord = $db->getGlobalSet($set);
		unless (defined $setRecord) {
			push @skipped, $set;
			$reason{$set} = $r->maketext("No record found.");
			next SET;
		}
		my $filePath = $ce->{courseDirs}->{templates} . '/' . $fileName;

		# back up existing file
		if(-e $filePath) {
			rename($filePath, "$filePath.bak") or
				$reason{$set} = $r->maketext("Existing file [_1] could not be backed up and was lost.", $filePath);
		}

		my $openDate     = $self->formatDateTime($setRecord->open_date);
		my $dueDate      = $self->formatDateTime($setRecord->due_date);
		my $answerDate   = $self->formatDateTime($setRecord->answer_date);
		my $reducedScoringDate =  $self->formatDateTime($setRecord->reduced_scoring_date);
		my $description = $setRecord->description;
		if ($description) {
		    $description =~ s/\r?\n/<n>/g;
		}

		my $assignmentType = $setRecord->assignment_type;
		my $enableReducedScoring = $setRecord->enable_reduced_scoring ? 'Y' : 'N';
		my $setHeader    = $setRecord->set_header;
		my $paperHeader  = $setRecord->hardcopy_header;
		my $emailInstructor = $setRecord->email_instructor;
		my $restrictProbProgression = $setRecord->restrict_prob_progression;

		my @problemList = $db->getGlobalProblemsWhere({ set_id => $set }, 'problem_id');

		my $problemList  = '';
		for my $problemRecord (@problemList) {
			my $problem_id = $problemRecord->problem_id();

			if ($setRecord->assignment_type eq 'jitar') {
				$problem_id = join('.', jitar_id_to_seq($problem_id));
			}

			my $source_file       = $problemRecord->source_file();
			my $value             = $problemRecord->value();
			my $max_attempts      = $problemRecord->max_attempts();
			my $showMeAnother     = $problemRecord->showMeAnother();
			my $prPeriod          = $problemRecord->prPeriod();
			my $countsParentGrade = $problemRecord->counts_parent_grade();
			my $attToOpenChildren = $problemRecord->att_to_open_children();

			# backslash-escape commas in fields
			$source_file   =~ s/([,\\])/\\$1/g;
			$value         =~ s/([,\\])/\\$1/g;
			$max_attempts  =~ s/([,\\])/\\$1/g;
			$showMeAnother =~ s/([,\\])/\\$1/g;
			$prPeriod      =~ s/([,\\])/\\$1/g;

			# This is the new way of saving problem information
			# the labelled list makes it easier to add variables and
			# easier to tell when they are missing
			$problemList .= "problem_start\n";
			$problemList .= "problem_id = $problem_id\n";
			$problemList .= "source_file = $source_file\n";
			$problemList .= "value = $value\n";
			$problemList .= "max_attempts = $max_attempts\n";
			$problemList .= "showMeAnother = $showMeAnother\n";
			$problemList .= "prPeriod = $prPeriod\n";
			$problemList .= "counts_parent_grade = $countsParentGrade\n";
			$problemList .= "att_to_open_children = $attToOpenChildren \n";
			$problemList .= "problem_end\n";
		}

		# gateway fields
		my $gwFields = '';
		if ( $assignmentType =~ /gateway/ ) {
		    my $attemptsPerV = $setRecord->attempts_per_version;
		    my $timeInterval = $setRecord->time_interval;
		    my $vPerInterval = $setRecord->versions_per_interval;
		    my $vTimeLimit   = $setRecord->version_time_limit;
		    my $probRandom   = $setRecord->problem_randorder;
		    my $probPerPage  = $setRecord->problems_per_page;
		    my $hideScore    = $setRecord->hide_score;
		    my $hideScoreByProblem  = $setRecord->hide_score_by_problem;
		    my $hideWork     = $setRecord->hide_work;
		    my $timeCap      = $setRecord->time_limit_cap;
		    $gwFields =<<EOG;

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
		my $restrictIP = $setRecord->restrict_ip;
		my $restrictFields = '';
		if ( $restrictIP && $restrictIP ne 'No' ) {
			# only store the first location
			my $restrictLoc = ($db->listGlobalSetLocations($setRecord->set_id))[0];
			my $relaxRestrict = $setRecord->relax_restrict_ip;
			$restrictLoc || ($restrictLoc = '');
			$restrictFields = "restrictIP          = $restrictIP" .
			    "\nrestrictLocation    = $restrictLoc\n" .
			    "relaxRestrictIP     = $relaxRestrict\n";
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
			local *SETDEF;
			open SETDEF, ">$filePath" or die $r->maketext("Failed to open [_1]", $filePath);
			print SETDEF $fileContents;
			close SETDEF;
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

################################################################################
# "display" methods
################################################################################

sub fieldEditHTML {
	my ($self, $fieldName, $value, $properties) = @_;
	my $size = $properties->{size};
	my $type = $properties->{type};
	my $access = $properties->{access};
	my $items = $properties->{items};
	my $synonyms = $properties->{synonyms};
	my $headerFiles = $self->{headerFiles};

	if ($access eq "readonly") {
		return CGI::span({ dir => 'ltr' }, $value) if ($type eq 'date');
		return $value;
	}

	if ($type eq 'number' || $type eq 'text') {
		return CGI::div(
			{ class => 'input-group input-group-sm flex-nowrap' },
			CGI::input({
				type            => 'text',
				name            => $fieldName,
				id              => "${fieldName}_id",
				aria_labelledby => ($fieldName =~ s/^.*\.([^.]*)$/$1/r) . '_header',
				value           => $value,
				size            => $size,
				class           => 'form-control w-auto'
			})
		);
	}

	if ($type eq 'date') {
		return CGI::div(
			{ class => 'input-group input-group-sm flex-nowrap flatpickr' },
			CGI::textfield({
				name            => $fieldName,
				id              => "${fieldName}_id",
				aria_labelledby => ($fieldName =~ s/^.*\.([^.]*)$/$1/r) . '_header',
				value           => $value,
				size            => $size,
				class           => 'form-control w-auto ' . ($fieldName =~ /\.open_date/ ? ' datepicker-group' : ''),
				placeholder     => $self->r->maketext("None Specified"),
				data_input      => undef,
				data_done_text  => $self->r->maketext('Done'),
				data_locale     => $self->r->ce->{language},
				data_timezone   => $self->r->ce->{siteDefaults}{timezone},
				role            => 'button',
				tabindex        => 0
			}),
			CGI::a(
				{
					class       => 'btn btn-secondary btn-sm',
					data_toggle => undef,
					role        => 'button',
					tabindex    => 0,
					aria_label  => $self->r->maketext('Pick date and time')
				},
				CGI::i({ class => 'fas fa-calendar-alt' }, '')
			)
		);
	}

	if ($type eq "checked") {
		# If the checkbox is checked it returns a 1, if it is unchecked it returns nothing
		# in which case the hidden field overrides the parameter with a 0.
		# This is actually the accepted way to do this.
		return CGI::input({
			type            => 'checkbox',
			id              => "${fieldName}_id",
			name            => $fieldName,
			aria_labelledby => ($fieldName =~ s/^.*\.([^.]*)$/$1/r) . '_header',
			value           => 1,
			class           => 'form-check-input',
			$value ? (checked => undef) : ()
		})
		. CGI::hidden({
			name  => $fieldName,
			value => 0
		});
	}
}

sub recordEditHTML {
	my ($self, $Set, %options) = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $ce         = $r->ce;
	my $db         = $r->db;
	my $authz      = $r->authz;
	my $user       = $r->param('user');
	my $root       = $ce->{webworkURLs}{root};
	my $courseName = $urlpath->arg('courseID');

	my $editMode    = $options{editMode};
	my $exportMode  = $options{exportMode};
	my $setSelected = $options{setSelected};

	my $visibleClass = $Set->visible ? 'font-visible' : 'font-hidden';
	my $enable_reduced_scoringClass =
		$Set->enable_reduced_scoring
		? $r->maketext('Reduced Scoring Enabled')
		: $r->maketext('Reduced Scoring Disabled');

	my $users      = $db->countSetUsers($Set->set_id);
	my $totalUsers = $self->{totalUsers};

	my $problems = $db->countGlobalProblems($Set->set_id);

	my $usersAssignedToSetURL = $self->systemLink($urlpath->new(
		type => 'instructor_users_assigned_to_set',
		args => { courseID => $courseName, setID => $Set->set_id }
	));
	my $prettySetID    = format_set_name_display($Set->set_id);
	my $problemListURL = $self->systemLink(
		$urlpath->new(type => 'instructor_set_detail', args => { courseID => $courseName, setID => $Set->set_id }));
	my $problemSetListURL = $self->systemLink(
		$urlpath->new(type => 'instructor_set_list', args => { courseID => $courseName, setID => $Set->set_id }))
		. '&editMode=1&visible_sets='
		. $Set->set_id;
	my $imageLink = '';

	if ($authz->hasPermissions($user, 'modify_problem_sets')) {
		$imageLink = CGI::a({ href => $problemSetListURL },
			CGI::i({ class => 'icon fas fa-pencil-alt', data_alt => 'edit', aria_hidden => 'true' }, ''));
	}

	my @tableCells;
	my %fakeRecord;
	my $set_id = $Set->set_id;

	$fakeRecord{select} = CGI::input({
		type  => 'checkbox',
		name  => 'selected_sets',
		value => $set_id,
		class => 'form-check-input',
		$setSelected ? (checked => undef) : (),
	});
	$fakeRecord{set_id} =
		$editMode
		? CGI::a({ href => $problemListURL }, $set_id)
		: CGI::span({ class => $visibleClass }, $set_id) . ' ' . $imageLink;
	$fakeRecord{problems} =
		(FIELD_PERMS()->{problems} and not $authz->hasPermissions($user, FIELD_PERMS()->{problems}))
		? $problems
		: CGI::a({ href => $problemListURL }, "$problems");
	$fakeRecord{users} =
		(FIELD_PERMS()->{users} and not $authz->hasPermissions($user, FIELD_PERMS()->{users}))
		? "$users/$totalUsers"
		: CGI::a({ href => $usersAssignedToSetURL }, "$users/$totalUsers");
	$fakeRecord{filename} = CGI::input({ -name => "set.$set_id", -value => "set$set_id.def", -size => 60 });

	# Select
	if ($editMode) {
		# No checkbox column in this case.
		push(@tableCells, CGI::td({ dir => 'ltr' }, CGI::a({ href => $problemListURL }, $prettySetID)));
	} else {
		# Set ID
		my $label = CGI::span(
			{
				class             => "set-label set-id-tooltip $visibleClass",
				data_bs_toggle    => 'tooltip',
				data_bs_placement => 'right',
				data_bs_title     => $Set->description()
			},
			$prettySetID
			)
			. ' '
			. $imageLink;

		# Selection checkbox
		push @tableCells,
			CGI::td(CGI::input({
				type  => 'checkbox',
				id    => "${set_id}_id",
				name  => 'selected_sets',
				value => $set_id,
				class => 'form-check-input',
				$setSelected ? (checked => 'checked') : (),
			}));

		push @tableCells,
			CGI::td(CGI::div(
				{ class => 'label-with-edit-icon', dir => 'ltr' },
				CGI::label({ for => "${set_id}_id" }, $label)
			));
	}

	# Problems link
	if (!$editMode) {
		# "problem list" link
		push @tableCells, CGI::td(CGI::a({ href => $problemListURL }, $problems));
	}

	# Users link
	if (!$editMode) {
		# "edit users assigned to set" link
		push @tableCells, CGI::td(CGI::a({ href => $usersAssignedToSetURL }, "$users/$totalUsers"));
	}

	# determine which non-key fields to show
	my @fieldsToShow;
	if ($editMode) {
		@fieldsToShow = @{ EDIT_FIELD_ORDER() };
	} elsif ($exportMode) {
		@fieldsToShow = @{ EXPORT_FIELD_ORDER() };
	} else {
		@fieldsToShow = @{ VIEW_FIELD_ORDER() };
	}

	# Remove the enable reduced scoring box if that feature isnt enabled
	if (!$ce->{pg}{ansEvalDefaults}{enableReducedScoring}) {
		@fieldsToShow = grep { !/enable_reduced_scoring|reduced_scoring_date/ } @fieldsToShow;
	}

	# make a hash out of this so we can test membership easily
	my %nonkeyfields;
	@nonkeyfields{ $Set->NONKEYFIELDS } = ();

	# Set Fields
	for my $field (@fieldsToShow) {
		next unless exists $nonkeyfields{$field};
		my $fieldName = 'set.' . $set_id . '.' . $field, my $fieldValue = $Set->$field;

		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = 'readonly' unless $editMode;

		$fieldValue = $self->formatDateTime($fieldValue, '', 'datetime_format_short', $ce->{language})
			if !$editMode && $field =~ /_date/;

		$fieldValue =~ s/ /&nbsp;/g unless $editMode;
		$fieldValue = $fieldValue ? $r->maketext('Yes') : $r->maketext('No')
			if $field =~ /visible/ and not $editMode;
		$fieldValue = $fieldValue ? $r->maketext('Yes') : $r->maketext('No')
			if $field =~ /enable_reduced_scoring/ and not $editMode;
		$fieldValue = $fieldValue ? $r->maketext('Yes') : $r->maketext('No')
			if $field =~ /hide_hint/ and not $editMode;

		push @tableCells,
			CGI::td(CGI::span(
				{ class => "d-inline-block w-100 text-center $visibleClass" },
				$self->fieldEditHTML($fieldName, $fieldValue, \%properties)
			));
	}

	return CGI::Tr(@tableCells);
}

sub printTableHTML {
	my ($self, $SetsRef, $fieldHeadersRef, %options) = @_;
	my $r                       = $self->r;
	my $ce = $r->ce;
	my $authz                   = $r->authz;
	my $user                    = $r->param('user');
	my $setTemplate	            = $self->{setTemplate};
	my @Sets                    = @$SetsRef;
	my %fieldHeaders            = %$fieldHeadersRef;

	my $editMode                = $options{editMode};
	my $exportMode              = $options{exportMode};
	my %selectedSetIDs          = map { $_ => 1 } @{ $options{selectedSetIDs} };
	my $currentSort             = $options{currentSort};

	# names of headings:
	my @realFieldNames = (
		$setTemplate->KEYFIELDS,
		$setTemplate->NONKEYFIELDS,
	);

	if ($editMode) {
		@realFieldNames = @{ EDIT_FIELD_ORDER() };
	} else {
		@realFieldNames = @{ VIEW_FIELD_ORDER() };
	}

	if ($exportMode) {
		@realFieldNames = @{ EXPORT_FIELD_ORDER() };
	}


	# Remove the enable reduced scoring box if that feature isnt enabled
	if (!$ce->{pg}{ansEvalDefaults}{enableReducedScoring}) {
		@realFieldNames = grep {!/enable_reduced_scoring|reduced_scoring_date/} @realFieldNames;
	}

	# FIXME: should this always presume to use the templates directory?
	# (no, but that can wait until we have an abstract ProblemLibrary API -- sam)
	my $templates_dir = $r->ce->{courseDirs}->{templates};
	my $exempt_dirs = join "|", keys %{ $r->ce->{courseFiles}->{problibs} };
	my @headers = listFilesRecursive(
		$templates_dir,
		qr/header.*\.pg$/i, # match these files
		qr/^(?:$exempt_dirs|CVS)$/, # prune these directories
		0, # match against file name only
		1, # prune against path relative to $templates_dir
	);

	@headers = sort @headers;
	my %headers = map { $_ => $_ } @headers;
	$headers{""} = $r->maketext("Use System Default");
	$self->{headerFiles} = \%headers;	# store these header files so we don't have to look for them later.


	my @tableHeadings = map { $fieldHeaders{$_} } @realFieldNames;

	if (!($editMode || $exportMode)) {
		unshift @tableHeadings,
			CGI::th(CGI::input({
				type              => 'checkbox',
				id                => 'select-all',
				aria_label        => $r->maketext('Select all sets'),
				data_select_group => 'selected_sets',
				class             => 'form-check-input'
			}));
	}

	# Print the table
	print CGI::start_div({ class => 'table-responsive' });
	print CGI::start_table({
		id    => "set_table_id",
		class => "set_table table table-sm table-bordered caption-top font-sm" . ($editMode ? ' align-middle' : '')
	});

	print CGI::caption($r->maketext("Set List"));

	print CGI::thead(CGI::Tr(@tableHeadings));

	print CGI::start_tbody();
	for (my $i = 0; $i < @Sets; $i++) {
		my $Set = $Sets[$i];

		print $self->recordEditHTML($Set,
			editMode => $editMode,
			exportMode => $exportMode,
			setSelected => exists $selectedSetIDs{$Set->set_id}
		);
	}
	print CGI::end_tbody();

	print CGI::end_table(), CGI::end_div();

	# If there are no users, shown print message.
	print CGI::p(
		CGI::i($r->maketext("No sets shown.  Choose one of the options above to list the sets in the course."))
	) unless @Sets;
}

# output_JS subroutine

# outputs all of the Javascript required for this page

sub output_JS {
	my $self = shift;
	my $ce   = $self->r->ce;

	# Print javascript and style for the flatpickr date/time picker.
	print CGI::Link({ rel => 'stylesheet', href => getAssetURL($ce, 'node_modules/flatpickr/dist/flatpickr.min.css') });
	print CGI::Link({
		rel  => 'stylesheet',
		href => getAssetURL($ce, 'node_modules/flatpickr/dist/plugins/confirmDate/confirmDate.css')
	});
	print CGI::script({ src => getAssetURL($ce, 'node_modules/luxon/build/global/luxon.min.js'), defer => undef }, '');
	print CGI::script({ src => getAssetURL($ce, 'node_modules/flatpickr/dist/flatpickr.min.js'), defer => undef }, '');
	if ($ce->{language} !~ /^en/) {
		print CGI::script(
			{
				src => getAssetURL(
					$ce, 'node_modules/flatpickr/dist/l10n/' . ($ce->{language} =~ s/^(..).*/$1/gr) . '.js'
				),
				defer => undef
			},
			''
		);
	}
	print CGI::script(
		{
			src   => getAssetURL($ce, 'node_modules/flatpickr/dist/plugins/confirmDate/confirmDate.js'),
			defer => undef
		},
		''
	);
	print CGI::script({ src => getAssetURL($ce, 'js/apps/DatePicker/datepicker.js'), defer => undef }, '');

	print CGI::script({ src => getAssetURL($ce, 'js/apps/ActionTabs/actiontabs.js'),         defer => undef }, '');
	print CGI::script({ src => getAssetURL($ce, 'js/apps/ProblemSetList/problemsetlist.js'), defer => undef }, '');
	print CGI::script({ src => getAssetURL($ce, 'js/apps/ShowHide/show_hide.js'),            defer => undef }, '');
	print CGI::script({ src => getAssetURL($ce, 'js/apps/SelectAll/selectall.js'),           defer => undef }, '');

	return '';
}

1;

=head1 AUTHOR

Written by Robert Van Dam, toenail (at) cif.rochester.edu

=cut
