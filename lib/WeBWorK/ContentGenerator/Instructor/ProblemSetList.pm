################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: 
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
	- showing visible sets
	- showing selected sets
Switch from edit mode to view and save changes
Switch from edit mode to view and abandon changes

Make sets visible to or hidden from students:
	- all, selected

Import sets:
	- replace:
		- any users
		- visible users
		- selected users
		- no users
	- add:
		- any users
		- no users

Score sets:
	- all
	- visible
	- selected

Create a set with a given name

Delete sets:
	- visible
	- selected

=cut

# FIXME: rather than having two types of boolean modes $editMode and $exportMode
#	make one $mode variable that contains a string like "edit", "view", or "export"

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readFile listFilesRecursive cryptPassword sortByName);

use constant HIDE_SETS_THRESHOLD => 50;
use constant DEFAULT_PUBLISHED_STATE => 1;

use constant EDIT_FORMS => [qw(cancelEdit saveEdit duplicate)];
use constant VIEW_FORMS => [qw(filter sort edit publish import export score create delete)];
use constant EXPORT_FORMS => [qw(cancelExport saveExport)];

use constant VIEW_FIELD_ORDER => [ qw( select set_id problems users published open_date due_date answer_date) ];
use constant EDIT_FIELD_ORDER => [ qw( set_id published open_date due_date answer_date) ];
use constant EXPORT_FIELD_ORDER => [ qw( select set_id filename) ];

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

use constant SORT_SUBS => {
	set_id		=> \&bySetID,
	set_header	=> \&bySetHeader,
	hardcopy_header	=> \&byHardcopyHeader,
	open_date	=> \&byOpenDate,
	due_date	=> \&byDueDate,
	answer_date	=> \&byAnswerDate,
	published	=> \&byPublished,

};

use constant  FIELD_PROPERTIES => {
	set_id => {
		type => "text",
		size => 8,
		access => "readonly",
	},
	set_header => {
		type => "filelist",
		size => 10,
		access => "readonly",
	},
	hardcopy_header => {
		type => "filelist",
		size => 10,
		access => "readonly",
	},
	open_date => {
		type => "text",
		size => 20,
		access => "readwrite",
	},
	due_date => {
		type => "text",
		size => 20,
		access => "readwrite",
	},
	answer_date => {
		type => "text",
		size => 20,
		access => "readwrite",
	},
	published => {
		type => "checked",
		size => 4,
		access => "readwrite",
	},	
};

sub pre_header_initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $ce     = $r->ce;
	my $authz  = $r->authz;
	my $urlpath = $r->urlpath;
	my $user   = $r->param('user');
	my $courseName = $urlpath->arg("courseID");


	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	
	if (defined $r->param("action") and $r->param("action") eq "score" and $authz->hasPermissions($user, "score_sets")) {
		my $scope = $r->param("action.score.scope");
		my @setsToScore = ();
	
		if ($scope eq "none") { 
			return "No sets selected for scoring.";
		} elsif ($scope eq "all") {
			@setsToScore = @{ $r->param("allSetIDs") };
		} elsif ($scope eq "visible") {
			@setsToScore = @{ $r->param("visibleSetIDs") };
		} elsif ($scope eq "selected") {
			@setsToScore = $r->param("selected_sets");
		}

		my $uri = $self->systemLink( $urlpath->newFromModule('WeBWorK::ContentGenerator::Instructor::Scoring', courseID=>$courseName),
						params=>{
							scoreSelected=>"ScoreSelected",
							selectedSet=>\@setsToScore,
#							recordSingleSetScores=>''
						}
		);

		$self->reply_with_redirect($uri);
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

	# templates for getting field names
	my $setTemplate = $self->{setTemplate} = $db->newGlobalSet;
	
	return CGI::div({class => "ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	# This table can be consulted when display-ready forms of field names are needed.
	my %prettyFieldNames = map { $_ => $_ } 
		$setTemplate->FIELDS();
	
	@prettyFieldNames{qw(
		select
		problems
		users
		filename
		set_id
		set_header
		hardcopy_header
		open_date
		due_date
		answer_date
		published		
	)} = (
		"Select",
		"Edit<br> Problems",
		"Edit<br> Assigned Sets",
		"Set Definition Filename",
		"Edit<br> Set Data", 
		"Set Header", 
		"Hardcopy Header", 
		"Open Date", 
		"Due Date", 
		"Answer Date", 
		"Visible", 
	);
	
	########## set initial values for state fields
	
	my @allSetIDs = $db->listGlobalSets;
	my @users = $db->listUsers;
	$self->{allSetIDs} = \@allSetIDs;
	$self->{totalUsers} = scalar @users;
	
	if (defined $r->param("visible_sets")) {
		$self->{visibleSetIDs} = [ $r->param("visible_sets") ];
	} elsif (defined $r->param("no_visible_sets")) {
		$self->{visibleSetIDs} = [];
	} else {
		if (@allSetIDs > HIDE_SETS_THRESHOLD) {
			$self->{visibleSetIDs} = [];
		} else {
			$self->{visibleSetIDs} = [ @allSetIDs ];
		}
	}
	
	$self->{prevVisibleSetIDs} = $self->{visibleSetIDs};
	
	if (defined $r->param("selected_sets")) {
		$self->{selectedSetIDs} = [ $r->param("selected_sets") ];
	} else {
		$self->{selectedSetIDs} = [];
	}
	
	$self->{editMode} = $r->param("editMode") || 0;
	
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to modify problem sets."))
		if $self->{editMode} and not $authz->hasPermissions($user, "modify_problem_sets");
	
	$self->{exportMode} = $r->param("exportMode") || 0;

	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to modify set definition files."))
		if $self->{exportMode} and not $authz->hasPermissions($user, "modify_set_def_files");
	
	$self->{primarySortField} = $r->param("primarySortField") || "due_date";
	$self->{secondarySortField} = $r->param("secondarySortField") || "open_date";
	
	my @allSets = $db->getGlobalSets(@allSetIDs);

	my (%open_dates, %due_dates, %answer_dates);
	foreach my $Set (@allSets) {
		push @{$open_dates{defined $Set->open_date ? $Set->open_date : ""}}, $Set->set_id;
		push @{$due_dates{defined $Set->due_date ? $Set->due_date : ""}}, $Set->set_id;
		push @{$answer_dates{defined $Set->answer_date ? $Set->answer_date : ""}}, $Set->set_id;
	}
	$self->{open_dates} = \%open_dates;
	$self->{due_dates} = \%due_dates;
	$self->{answer_dates} = \%answer_dates;
	
	########## call action handler
	
	my $actionID = $r->param("action");
	if ($actionID) {
		unless (grep { $_ eq $actionID } @{ VIEW_FORMS() }, @{ EDIT_FORMS() }, @{ EXPORT_FORMS() }) {
			die "Action $actionID not found";
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
			print CGI::div({class=>"Message"}, CGI::p("Results of last action performed: ", $self->$actionHandler(\%genericParams, \%actionParams, \%tableParams))), CGI::hr();
		} else {
			return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to perform this action."));
		}

	}
		
	########## retrieve possibly changed values for member fields
	
	@allSetIDs = @{ $self->{allSetIDs} }; # do we need this one? YES, deleting or importing a set will change this.
	my @visibleSetIDs = @{ $self->{visibleSetIDs} };
	my @prevVisibleSetIDs = @{ $self->{prevVisibleSetIDs} };
	my @selectedSetIDs = @{ $self->{selectedSetIDs} };
	my $editMode = $self->{editMode};
	my $exportMode = $self->{exportMode};
	my $primarySortField = $self->{primarySortField};
	my $secondarySortField = $self->{secondarySortField};
	
	#warn "visibleSetIDs=@visibleSetIDs\n";
	#warn "prevVisibleSetIDs=@prevVisibleSetIDs\n";
	#warn "selectedSetIDs=@selectedSetIDs\n";
	#warn "editMode=$editMode\n";
	
	########## get required users
		
	my @Sets = grep { defined $_ } @visibleSetIDs ? $db->getGlobalSets(@visibleSetIDs) : ();
	
	# presort users
	my %sortSubs = %{ SORT_SUBS() };
	my $primarySortSub = $sortSubs{$primarySortField};
	my $secondarySortSub = $sortSubs{$secondarySortField};	
	
	# don't forget to sort in opposite order of importance
	if ($secondarySortField eq "set_id") {
		@Sets = sortByName("set_id", @Sets);
	} else {
		@Sets = sort $secondarySortSub @Sets;
	}

	if ($primarySortField eq "set_id") {
		@Sets = sortByName("set_id", @Sets);
	} else {
		@Sets = sort $primarySortSub @Sets;
	}

	########## print beginning of form
	
	print CGI::start_form({method=>"post", action=>$self->systemLink($urlpath,authen=>0), name=>"problemsetlist"});
	print $self->hidden_authen_fields();
	
	########## print state data
	
	print "\n<!-- state data here -->\n";
	
	if (@visibleSetIDs) {
		print CGI::hidden(-name=>"visible_sets", -value=>\@visibleSetIDs);
	} else {
		print CGI::hidden(-name=>"no_visible_sets", -value=>"1");
	}
	
	if (@prevVisibleSetIDs) {
		print CGI::hidden(-name=>"prev_visible_sets", -value=>\@prevVisibleSetIDs);
	} else {
		print CGI::hidden(-name=>"no_prev_visible_sets", -value=>"1");
	}
	
	print CGI::hidden(-name=>"editMode", -value=>$editMode);
	print CGI::hidden(-name=>"exportMode", -value=>$exportMode);
	
	print CGI::hidden(-name=>"primarySortField", -value=>$primarySortField);
	print CGI::hidden(-name=>"secondarySortField", -value=>$secondarySortField);	
	
	print "\n<!-- state data here -->\n";
	
	########## print action forms
	
	print CGI::start_table({});
	print CGI::Tr({}, CGI::td({-colspan=>2}, "Select an action to perform:"));
	
	my @formsToShow;
	if ($editMode) {
		@formsToShow = @{ EDIT_FORMS() };
	} else {
		@formsToShow = @{ VIEW_FORMS() };
	}
	
	if ($exportMode) {
		@formsToShow = @{ EXPORT_FORMS() };
	}
	
	my $i = 0;
	foreach my $actionID (@formsToShow) {
		# Check permissions
		next if FORM_PERMS()->{$actionID} and not $authz->hasPermissions($user, FORM_PERMS()->{$actionID});
		my $actionForm = "${actionID}_form";
		my $onChange = "document.problemsetlist.action[$i].checked=true";
		my %actionParams = $self->getActionParams($actionID);
		
		print CGI::Tr({-valign=>"top"},
			CGI::td({}, CGI::input({-type=>"radio", -name=>"action", -value=>$actionID})),
			CGI::td({}, $self->$actionForm($onChange, %actionParams))
		);
		
		$i++;
	}
	
	print CGI::Tr({}, CGI::td({-colspan=>2, -align=>"center"},
		CGI::submit(-value=>"Take Action!"))
	);
	print CGI::end_table();
	
	########## print table
	
	print CGI::p("Showing ", scalar @visibleSetIDs, " out of ", scalar @allSetIDs, " sets.");
	
	$self->printTableHTML(\@Sets, \%prettyFieldNames,
		editMode => $editMode,
		exportMode => $exportMode,
		selectedSetIDs => \@selectedSetIDs,
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
		next unless $param =~ m/^(?:set)\./;
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
	my ($self, $onChange, %actionParams) = @_;
	#return CGI::table({}, CGI::Tr({-valign=>"top"},
	#	CGI::td({}, 
	return join("", 
			"Show ",
			CGI::popup_menu(
				-name => "action.filter.scope",
				-values => [qw(all none selected match_ids published unpublished)],
				-default => $actionParams{"action.filter.scope"}->[0] || "match_ids",
				-labels => {
					all => "all sets",
					none => "no sets",
					selected => "sets checked below",
					published => "sets visible to students",
					unpublished => "sets hidden from students", 
					match_ids => "sets with matching set IDs:",
				},
				-onchange => $onChange,
			),
			" ",
			CGI::textfield(
				-name => "action.filter.set_ids",
				-value => $actionParams{"action.filter.set_ids"}->[0] || "",,
				-width => "50",
				-onchange => $onChange,
			),
			" (separate multiple IDs with commas)",
			CGI::br(),
#			"Open dates: ",
#			CGI::popup_menu(
#				-name => "action.filter.open_date",
#				-values => [ keys %{ $self->{open_dates} } ],
#				-default => $actionParams{"action.filter.open_date"}->[0] || "",
#				-labels => { $self->menuLabels($self->{open_dates}) },
#				-onchange => $onChange,
#			),
#			" Due dates: ",
#			CGI::popup_menu(
#				-name => "action.filter.due_date",
#				-values => [ keys %{ $self->{due_dates} } ],
#				-default => $actionParams{"action.filter.due_date"}->[0] || "",
#				-labels => { $self->menuLabels($self->{due_dates}) },
#				-onchange => $onChange,
#			),
#			" Answer dates: ",
#			CGI::popup_menu(
#				-name => "action.filter.answer_date",
#				-values => [ keys %{ $self->{answer_dates} } ],
#				-default => $actionParams{"action.filter.answer_date"}->[0] || "",
#				-labels => { $self->menuLabels($self->{answer_dates}) },
#				-onchange => $onChange,
#			),
			
	);
}

# this action handler modifies the "visibleUserIDs" field based on the contents
# of the "action.filter.scope" parameter and the "selected_users" 
sub filter_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	
	my $r = $self->r ;
	my $db = $r->db;
	
	my $result;
	
	my $scope = $actionParams->{"action.filter.scope"}->[0];
	if ($scope eq "all") {
		$result = "showing all sets";
		$self->{visibleSetIDs} = $self->{allSetIDs};
	} elsif ($scope eq "none") {
		$result = "showing no sets";
		$self->{visibleSetIDs} = [];
	} elsif ($scope eq "selected") {
		$result = "showing selected sets";
		$self->{visibleSetIDs} = $genericParams->{selected_sets}; # an arrayref
	} elsif ($scope eq "match_ids") {
		my @setIDs = split /\s*,\s*/, $actionParams->{"action.filter.set_ids"}->[0];
		$self->{visibleSetIDs} = \@setIDs;
	} elsif ($scope eq "match_open_date") {
		my $open_date = $actionParams->{"action.filter.open_date"}->[0];
		$self->{visibleSetIDs} = $self->{open_dates}->{$open_date}; # an arrayref
	} elsif ($scope eq "match_due_date") {
		my $due_date = $actionParams->{"action.filter.due_date"}->[0];
		$self->{visibleSetIDs} = $self->{due_date}->{$due_date}; # an arrayref
	} elsif ($scope eq "match_answer_date") {
		my $answer_date = $actionParams->{"action.filter.answer_date"}->[0];
		$self->{visibleSetIDs} = $self->{answer_dates}->{$answer_date}; # an arrayref
	} elsif ($scope eq "published") {
		my @setRecords = $db->getGlobalSets(@{$self->{allSetIDs}});
		my @publishedSetIDs = map { $_->published ? $_->set_id : ""} @setRecords;		
		$self->{visibleSetIDs} = \@publishedSetIDs;
	} elsif ($scope eq "unpublished") {
		my @setRecords = $db->getGlobalSets(@{$self->{allSetIDs}});
		my @unpublishedSetIDs = map { (not $_->published) ? $_->set_id : ""} @setRecords;
		$self->{visibleSetIDs} = \@unpublishedSetIDs;
	}
	
	return $result;
}

sub sort_form {
	my ($self, $onChange, %actionParams) = @_;
	return join ("",
		"Primary sort: ",
		CGI::popup_menu(
			-name => "action.sort.primary",
			-values => [qw(set_id set_header hardcopy_header open_date due_date answer_date published)],
			-default => $actionParams{"action.sort.primary"}->[0] || "due_date",
			-labels => {
				set_id		=> "Set Name",
				set_header 	=> "Set Header",
				hardcopy_header	=> "Hardcopy Header",
				open_date	=> "Open Date",
				due_date	=> "Due Date",
				answer_date	=> "Answer Date",
				published	=> "Visibility",
			},
			-onchange => $onChange,
		),
		" Secondary sort: ",
		CGI::popup_menu(
			-name => "action.sort.secondary",
			-values => [qw(set_id set_header hardcopy_header open_date due_date answer_date published)],
			-default => $actionParams{"action.sort.secondary"}->[0] || "open_date",
			-labels => {
				set_id		=> "Set Name",
				set_header 	=> "Set Header",
				hardcopy_header	=> "Hardcopy Header",
				open_date	=> "Open Date",
				due_date	=> "Due Date",
				answer_date	=> "Answer Date",
				published	=> "Visibility",
			},
			-onchange => $onChange,
		),
		".",
	);
}

sub sort_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	
	my $primary = $actionParams->{"action.sort.primary"}->[0];
	my $secondary = $actionParams->{"action.sort.secondary"}->[0];
	
	$self->{primarySortField} = $primary;
	$self->{secondarySortField} = $secondary;

	my %names = (
		set_id		=> "Set Name",
		set_header	=> "Set Header",
		hardcopy_header	=> "Hardcopy Header",
		open_date	=> "Open Date",
		due_date	=> "Due Date",
		answer_date	=> "Answer Date",
		published	=> "Visibility",
	);
	
	return "sort by $names{$primary} and then by $names{$secondary}.";
}


sub edit_form {
	my ($self, $onChange, %actionParams) = @_;

	return join("",
		"Edit ",
		CGI::popup_menu(
			-name => "action.edit.scope",
			-values => [qw(all visible selected)],
			-default => $actionParams{"action.edit.scope"}->[0] || "selected",
			-labels => {
				all => "all sets",
				visible => "visible sets",
				selected => "selected sets",
			},
			-onchange => $onChange,
		),
	);
}

sub edit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $result;
	
	my $scope = $actionParams->{"action.edit.scope"}->[0];
	if ($scope eq "all") {
		$result = "editing all sets";
		$self->{visibleSetIDs} = $self->{allSetIDs};
	} elsif ($scope eq "visible") {
		$result = "editing visible sets";
		# leave visibleUserIDs alone
	} elsif ($scope eq "selected") {
		$result = "editing selected sets";
		$self->{visibleSetIDs} = $genericParams->{selected_sets}; # an arrayref
	}
	$self->{editMode} = 1;
	
	return $result;
}

sub publish_form {
	my ($self, $onChange, %actionParams) = @_;

	return join ("",
		"Make ",
		CGI::popup_menu(
			-name => "action.publish.scope",
			-values => [ qw(none all selected) ],
			-default => $actionParams{"action.publish.scope"}->[0] || "selected",
			-labels => {
				none => "",
				all => "all sets",
#				visible => "visible sets",
				selected => "selected sets",
			},
			-onchange => $onChange,
		),
		CGI::popup_menu(
			-name => "action.publish.value",
			-values => [ 0, 1 ],
			-default => $actionParams{"action.publish.value"}->[0] || "1",
			-labels => {
				0 => "hidden",
				1 => "visible",
			},
			-onchange => $onChange,
		),
		" for students.",
	);
}

sub publish_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r = $self->r;
	my $db = $r->db;

	my $result = "";
	
	my $scope = $actionParams->{"action.publish.scope"}->[0];
	my $value = $actionParams->{"action.publish.value"}->[0];

	my $verb = $value ? "made visible for" : "hidden from";
	
	my @setIDs;
	
	if ($scope eq "none") { # FIXME: double negative "Make no sets hidden" might make professor expect all sets to be made visible.
		@setIDs = ();
		$result = "No change made to any set.";
	} elsif ($scope eq "all") {
		@setIDs = @{ $self->{allSetIDs} };
		$result = "All sets $verb all students.";
	} elsif ($scope eq "visible") {
		@setIDs = @{ $self->{visibleSetIDs} };
		$result = "All visible sets $verb all students.";
	} elsif ($scope eq "selected") {
		@setIDs = @{ $genericParams->{selected_sets} };
		$result = "All selected sets $verb all students.";
	}
	
	my @sets = $db->getGlobalSets(@setIDs);
	
	map { $_->published("$value") if $_; $db->putGlobalSet($_); } @sets;
	
	return $result
	
}

sub score_form {
	my ($self, $onChange, %actionParams) = @_;

	return join ("",
		"Score ",
		CGI::popup_menu(
			-name => "action.score.scope",
			-values => [qw(none all selected)],
			-default => $actionParams{"action.score.scope"}->[0] || "none",
			-labels => {
				none => "no sets.",
				all => "all sets.",
				selected => "selected sets.",
			},
			-onchange => $onChange,
		),
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
		return "No sets selected for scoring.";
	} elsif ($scope eq "all") {
		@setsToScore = @{ $self->{allSetIDs} };
	} elsif ($scope eq "visible") {
		@setsToScore = @{ $self->{visibleSetIDs} };
	} elsif ($scope eq "selected") {
		@setsToScore = @{ $genericParams->{selected_sets} };
	}

	my $uri = $self->systemLink( $urlpath->newFromModule('WeBWorK::ContentGenerator::Instructor::Scoring', courseID=>$courseName),
					params=>{
						scoreSelected=>"Score Selected",
						selectedSet=>\@setsToScore,
#						recordSingleSetScores=>''
					}
	);
	
	
	return $uri;
}


sub delete_form {
	my ($self, $onChange, %actionParams) = @_;

	return join("",
		CGI::div({class=>"ResultsWithError"}, 
			"Delete ",
			CGI::popup_menu(
				-name => "action.delete.scope",
				-values => [qw(none selected)],
				-default => $actionParams{"action.delete.scope"}->[0] || "none",
				-labels => {
					none => "no sets.",
					#visble => "visible sets.",
					selected => "selected sets.",
				},
				-onchange => $onChange,
			),
			CGI::em(" Deletion destroys all set-related data and is not undoable!"),
		)
	);
}

sub delete_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r      = $self->r;
	my $db     = $r->db;

	my $scope = $actionParams->{"action.delete.scope"}->[0];

	
	my @setIDsToDelete = ();

	if ($scope eq "selected") {
		@setIDsToDelete = @{ $self->{selectedSetIDs} };
	}
	
	my %allSetIDs = map { $_ => 1 } @{ $self->{allSetIDs} };
	my %visibleSetIDs = map { $_ => 1 } @{ $self->{visibleSetIDs} };
	my %selectedSetIDs = map { $_ => 1 } @{ $self->{selectedSetIDs} };

	foreach my $setID (@setIDsToDelete) {
		delete $allSetIDs{$setID};
		delete $visibleSetIDs{$setID};
		delete $selectedSetIDs{$setID};
		$db->deleteGlobalSet($setID);
	}
	
	$self->{allSetIDs} = [ keys %allSetIDs ];
	$self->{visibleSetIDs} = [ keys %visibleSetIDs ];
	$self->{selectedSetIDs} = [ keys %selectedSetIDs ];
	
	my $num = @setIDsToDelete;
	return "deleted $num set" . ($num == 1 ? "" : "s");
}

sub create_form {
	my ($self, $onChange, %actionParams) = @_;

	my $r      = $self->r;
	
	return "Create a new set named: ", 
		CGI::textfield(
			-name => "action.create.name",
			-value => $actionParams{"action.create.name"}->[0] || "",
			-width => "50",
			-onchange => $onChange,
		),
		" as ",
		CGI::popup_menu(
			-name => "action.create.type",
			-values => [qw(empty copy)],
			-default => $actionParams{"action.create.type"}->[0] || "empty",
			-labels => {
				empty => "a new empty set.",
				copy => "a duplicate of the first selected set.",
			},
			-onchange => $onChange,
		);
			
}

sub create_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r      = $self->r;
	my $db     = $r->db;
	
	my $newSetRecord = $db->newGlobalSet;
	my $oldSetID = $self->{selectedSetIDs}->[0];
	my $newSetID = $actionParams->{"action.create.name"}->[0];
	return CGI::div({class => "ResultsWithError"}, "Failed to create new set: no set name specified!") unless $newSetID =~ /\S/;
	
	my $type = $actionParams->{"action.create.type"}->[0];
	if ($type eq "empty") {
		$newSetRecord->set_id($newSetID);
		$newSetRecord->set_header("");
		$newSetRecord->hardcopy_header("");
		$newSetRecord->open_date("0");
		$newSetRecord->due_date("0");
		$newSetRecord->answer_date("0");
		$newSetRecord->published(DEFAULT_PUBLISHED_STATE);	# don't want students to see an empty set
		eval {$db->addGlobalSet($newSetRecord)};
	} elsif ($type eq "copy") {
		return CGI::div({class => "ResultsWithError"}, "Failed to duplicate set: no set selected for duplication!") unless $oldSetID =~ /\S/;
		$newSetRecord = $db->getGlobalSet($oldSetID);
		$newSetRecord->set_id($newSetID);
		eval {$db->addGlobalSet($newSetID)};

		# take all the problems from the old set and make them part of the new set
		foreach ($db->getAllGlobalProblems($oldSetID)) { 
			$_->set_id($newSetID); 
			$db->addGlobalProblem($_);
		}
	}

	push @{ $self->{visibleSetIDs} }, $newSetID;
	push @{ $self->{allSetIds} }, $newSetID;
	
	return CGI::div({class => "ResultsWithError"}, "Failed to create new set: $@") if $@;
	
	return "Successfully created new set $newSetID";
	
}

sub import_form {
	my ($self, $onChange, %actionParams) = @_;
	
	my $r = $self->r;
	my $authz = $r->authz;
	my $user = $r->param('user');

	# this will make the popup menu alternate between a single selection and a multiple selection menu
	# Note: search by name is required since document.problemsetlist.action.import.number is not seen as
	# a valid reference to the object named 'action.import.number'
	my $importScript = join (" ",
				"var number = document.getElementsByName('action.import.number')[0].value;",
				"document.getElementsByName('action.import.source')[0].size = number;",
				"document.getElementsByName('action.import.source')[0].multiple = (number > 1 ? true : false);",
				"document.getElementsByName('action.import.name')[0].value = (number > 1 ? '(taken from filenames)' : '');",
			);
	
	return join(" ",
		"Import ",
		CGI::popup_menu(
			-name => "action.import.number",
			-values => [ 1, 8 ],
			-default => $actionParams{"action.import.number"}->[0] || "1",
			-labels => {
				1 => "a single set",
				8 => "multiple sets",
			},
			-onchange => "$onChange;$importScript",
		),
		" from ", # set definition file(s) ",
		CGI::popup_menu(
			-name => "action.import.source",
			-values => [ "", $self->getDefList() ],
			-labels => { "" => "the following file(s)" },
			-default => $actionParams{"action.import.source"}->[0] || "",
			-size => $actionParams{"action.import.number"}->[0] || "1",
			-onchange => $onChange,
		),
		" with set name(s): ",
		CGI::textfield(
			-name => "action.import.name",
			-value => $actionParams{"action.import.name"}->[0] || "",
			-width => "50",
			-onchange => $onChange,
		),
		($authz->hasPermissions($user, "assign_problem_sets")) 
			?
			"assigning this set to " .
			CGI::popup_menu(
				-name => "action.import.assign",
				-value => [qw(all none)],
				-default => $actionParams{"action.import.assign"}->[0] || "none",
				-labels => {
					all => "all current users.",
					none => "no users.",
				},
				-onchange => $onChange,
			)
			:
			""	#user does not have permissions to assign problem sets
	);
}

sub import_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my @fileNames = @{ $actionParams->{"action.import.source"} };
	my $newSetName = $actionParams->{"action.import.name"}->[0];
	$newSetName = "" if $actionParams->{"action.import.number"}->[0] > 1; # cannot assign set names to multiple imports
	my $assign = $actionParams->{"action.import.assign"}->[0];
	
	my ($added, $skipped) = $self->importSetsFromDef($newSetName, $assign, @fileNames);

	# make new sets visible... do we really want to do this? probably.
	push @{ $self->{visibleSetIDs} }, @$added;
	push @{ $self->{allSetIDs} }, @$added;
	
	my $numAdded = @$added;
	my $numSkipped = @$skipped;

	return 	$numAdded . " set" . ($numAdded == 1 ? "" : "s") . " added, "
		. $numSkipped . " set" . ($numSkipped == 1 ? "" : "s") . " skipped"
		. " (" . join (", ", @$skipped) . ") ";
}

sub export_form {
	my ($self, $onChange, %actionParams) = @_;

	return join("",
		"Export ",
		CGI::popup_menu(
			-name => "action.export.scope",
			-values => [qw(all visible selected)],
			-default => $actionParams{"action.export.scope"}->[0] || "visible",
			-labels => {
				all => "all sets",
				visible => "visible sets",
				selected => "selected sets",
			},
			-onchange => $onChange,
		),
	);
}

# this does not actually export any files, rather it sends us to a new page in order to export the files
sub export_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $result;
	
	my $scope = $actionParams->{"action.export.scope"}->[0];
	if ($scope eq "all") {
		$result = "exporting all sets";
		$self->{selectedSetIDs} = $self->{visibleSetIDs} = $self->{allSetIDs};

	} elsif ($scope eq "visible") {
		$result = "exporting visible sets";
		$self->{selectedSetIDs} = $self->{visibleSetIDs};
	} elsif ($scope eq "selected") {
		$result = "exporting selected sets";
		$self->{selectedSetIDs} = $self->{visibleSetIDs} = $genericParams->{selected_sets}; # an arrayref
	}
	$self->{exportMode} = 1;
	
	return $result;
}

sub cancelExport_form {
	my ($self, $onChange, %actionParams) = @_;
	return "Abandon export";
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
	
	return "export abandoned";
}

sub saveExport_form {
	my ($self, $onChange, %actionParams) = @_;
	return "Export selected sets (This may take a long time.  Even if your browser times out, all the files will be exported).";
}

sub saveExport_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r           = $self->r;
	my $db          = $r->db;
	
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
	
	my @reasons = map { "set $_ - " . $reason->{$_} } keys %$reason;

	return 	$numExported . " set" . ($numExported == 1 ? "" : "s") . " exported, "
		. $numSkipped . " set" . ($numSkipped == 1 ? "" : "s") . " skipped."
		. (($numSkipped) ? CGI::ul(CGI::li(\@reasons)) : "");

}

sub cancelEdit_form {
	my ($self, $onChange, %actionParams) = @_;
	return "Abandon changes";
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
	
	return "changes abandoned";
}

sub saveEdit_form {
	my ($self, $onChange, %actionParams) = @_;
	return "Save changes";
}

sub saveEdit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r           = $self->r;
	my $db          = $r->db;
	
	my @visibleSetIDs = @{ $self->{visibleSetIDs} };
	foreach my $setID (@visibleSetIDs) {
		my $Set = $db->getGlobalSet($setID); # checked
# FIXME: we may not want to die on bad sets, they're not as bad as bad users
		die "record for visible set $setID not found" unless $Set;

		foreach my $field ($Set->NONKEYFIELDS()) {
			my $param = "set.${setID}.${field}";
			if (defined $tableParams->{$param}->[0]) {
				if ($field =~ /_date/) {
					$Set->$field($self->parseDateTime($tableParams->{$param}->[0]));
				} else {
					$Set->$field($tableParams->{$param}->[0]);
				}
			}
		}

		###################################################
		# Check that the open, due and answer dates are in increasing order.
		# Bail if this is not correct.
		###################################################
		if ($Set->open_date > $Set->due_date)  {
			return CGI::div({class=>'ResultsWithError'}, "Error: Due date must come after open date in set $setID");
		}
		if ($Set->due_date > $Set->answer_date) {
			return CGI::div({class=>'ResultsWithError'}, "Error: Answer date must come after due date in set $setID");
		}
		###################################################
		# End date check section.
		###################################################
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
	
	return "changes saved";
}

sub duplicate_form {
	my ($self, $onChange, %actionParams) = @_;
	
	return join ("", 
		"Duplicate this set and name it: ", 
		CGI::textfield(
			-name => "action.duplicate.name",
			-value => $actionParams{"action.duplicate.name"}->[0] || "",
			-width => "50",
			-onchange => $onChange,
		),
	);
}

sub duplicate_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	
	my $r = $self->r;
	my $db = $r->db;
	
	my $oldSetID = $self->{selectedSetIDs}->[0];
	return CGI::div({class => "ResultsWithError"}, "Failed to duplicate set: no set selected for duplication!") unless defined($oldSetID) and $oldSetID =~ /\S/;	
	my $newSetID = $actionParams->{"action.duplicate.name"}->[0];
	return CGI::div({class => "ResultsWithError"}, "Failed to duplicate set: no set name specified!") unless $newSetID =~ /\S/;		
	return CGI::div({class => "ResultsWithError"}, "Failed to duplicate set: set $newSetID already exists!") if defined $db->getGlobalSet($newSetID);

	my $newSet = $db->getGlobalSet($oldSetID);
	$newSet->set_id($newSetID);
	eval {$db->addGlobalSet($newSet)};
	
	# take all the problems from the old set and make them part of the new set
	foreach ($db->getAllGlobalProblems($oldSetID)) { 
		$_->set_id($newSetID); 
		$db->addGlobalProblem($_);
	}
	
	push @{ $self->{visibleSetIDs} }, $newSetID;

	return CGI::div({class => "ResultsWithError"}, "Failed to duplicate set: $@") if $@;
	
	return "SUCCESS";
}

################################################################################
# sorts
################################################################################

sub bySetID         { $a->set_id         cmp $b->set_id         }
sub bySetHeader     { $a->set_header     cmp $b->set_header     }
sub byHardcopyHeader { $a->hardcopy_header cmp $b->hardcopy_header }
sub byOpenDate      { $a->open_date      <=> $b->open_date      }
sub byDueDate       { $a->due_date       <=> $b->due_date       }
sub byAnswerDate    { $a->answer_date    <=> $b->answer_date    }
sub byPublished     { $a->published      cmp $b->published      }

sub byOpenDue       { &byOpenDate || &byDueDate }

################################################################################
# utilities
################################################################################

# generate labels for open_date/due_date/answer_date popup menus
sub menuLabels {
	my ($self, $hashRef) = @_;
	my %hash = %$hashRef;
	
	my %result;
	foreach my $key (keys %hash) {
		my $count = @{ $hash{$key} };
		my $displayKey = $self->formatDateTime($key) || "<none>";
		$result{$key} = "$displayKey ($count sets)";
	}
	return %result;
}

sub importSetsFromDef {
	my ($self, $newSetName, $assign, @setDefFiles) = @_;
	my $r     = $self->r;
	my $ce    = $r->ce;
	my $db    = $r->db;
	my $dir   = $ce->{courseDirs}->{templates};

	# FIXME: do we really want everything to fail on one bad file name?
	foreach my $fileName (@setDefFiles) {
		die "won't be able to read from file $dir/$fileName: does it exist? is it readable?"
			unless -r "$dir/$fileName";
	}

	my @allSetIDs = $db->listGlobalSets();
	# FIXME: getGlobalSets takes a lot of time just for checking to see if a set already exists
	# 	this could be avoided by waiting until the call to addGlobalSet below
	#	and checking to see if the error message says that the set already exists
	#	but if the error message is ever changed the code here might be broken
	#	then again, one call to getGlobalSets and skipping unnecessary calls to addGlobalSet
	#	could be faster than no call to getGlobalSets and lots of unnecessary calls to addGlobalSet
	my %allSets = map { $_->set_id => 1 if $_} $db->getGlobalSets(@allSetIDs); # checked

	my (@added, @skipped);

	foreach my $set_definition_file (@setDefFiles) {

		$WeBWorK::timer->continue("$set_definition_file: reading set definition file") if defined $WeBWorK::timer;
		# read data in set definition file
		my ($setName, $paperHeaderFile, $screenHeaderFile, $openDate, $dueDate, $answerDate, $ra_problemData) = $self->readSetDef($set_definition_file);
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

		$WeBWorK::timer->continue("$set_definition_file: adding set") if defined $WeBWorK::timer;
		# add the data to the set record
		my $newSetRecord = $db->newGlobalSet;
		$newSetRecord->set_id($setName);
		$newSetRecord->set_header($screenHeaderFile);
		$newSetRecord->hardcopy_header($paperHeaderFile);
		$newSetRecord->open_date($openDate);
		$newSetRecord->due_date($dueDate);
		$newSetRecord->answer_date($answerDate);
		$newSetRecord->published(DEFAULT_PUBLISHED_STATE);

		#create the set
		eval {$db->addGlobalSet($newSetRecord)};
		die "addGlobalSet $setName in ProblemSetList:  $@" if $@;

		$WeBWorK::timer->continue("$set_definition_file: adding problems to database") if defined $WeBWorK::timer;
		# add problems
		my $freeProblemID = WeBWorK::Utils::max($db->listGlobalProblems($setName)) + 1;
		foreach my $rh_problem (@problemList) {
			$self->addProblemToSet(
			  setName => $setName,
			  sourceFile => $rh_problem->{source_file},
			  problemID => $freeProblemID++,
			  value => $rh_problem->{value},
			  maxAttempts => $rh_problem->{max_attempts});
		}


		if ($assign eq "all") {
			$self->assignSetToAllUsers($setName);
		}
	}


	return \@added, \@skipped;
}

sub readSetDef {
	my ($self, $fileName) = @_;
	my $templateDir   = $self->{ce}->{courseDirs}->{templates};
	my $filePath      = "$templateDir/$fileName";

	my $setName = '';

	if ($fileName =~ m|^set([\w-]+)\.def$|) {
		$setName = $1;
	} else {
		warn qq{The setDefinition file name must begin with   <CODE>set</CODE>},
			qq{and must end with   <CODE>.def</CODE>  . Every thing in between becomes the name of the set. },
			qq{For example <CODE>set1.def</CODE>, <CODE>setExam.def</CODE>, and <CODE>setsample7.def</CODE> },
			qq{define sets named <CODE>1</CODE>, <CODE>Exam</CODE>, and <CODE>sample7</CODE> respectively. },
			qq{The filename, $fileName, you entered is not legal\n };

	}

	my ($line, $name, $value, $attemptLimit, $continueFlag);
	my $paperHeaderFile = '';
	my $screenHeaderFile = '';
	my ($dueDate, $openDate, $answerDate);
	my @problemData;	


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
			$line =~ m|^\s*(\w+)\s*=\s*(.*)|;
			
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
			} elsif ($item eq 'problemList') {
				last;
			} else {
				warn "readSetDef error, can't read the line: ||$line||";
			}
		}

		#####################################################################
		# Check and format dates
		#####################################################################
		my ($time1, $time2, $time3) = map { $_ =~ s/\s*at\s*/ /; $self->parseDateTime($_);  }    ($openDate, $dueDate, $answerDate);
	
		unless ($time1 <= $time2 and $time2 <= $time3) {
			warn "The open date: $openDate, due date: $dueDate, and answer date: $answerDate must be defined and in chronological order.";
		}

		# Check header file names
		$paperHeaderFile =~ s/(.*?)\s*$/$1/;   #remove trailing white space
		$screenHeaderFile =~ s/(.*?)\s*$/$1/;   #remove trailing white space
	
		#####################################################################
		# Read and check list of problems for the set
		#####################################################################
		while(<SETFILENAME>) {
			chomp($line=$_);
			$line =~ s/(#.*)//;                             ## don't read past comments
			unless ($line =~ /\S/) {next;}                  ## skip blank lines
	
			($name, $value, $attemptLimit, $continueFlag) = split (/\s*,\s*/,$line);
			#####################
			#  clean up problem values
			###########################
			$name =~ s/\s*//g;
			$value = "" unless defined($value);
			$value =~ s/[^\d\.]*//g;
			unless ($value =~ /\d+/) {$value = 1;}
			$attemptLimit = "" unless defined($attemptLimit);
			$attemptLimit =~ s/[^\d-]*//g;
			unless ($attemptLimit =~ /\d+/) {$attemptLimit = -1;}
			$continueFlag = "0" unless( defined($continueFlag) && @problemData );  
			# can't put continuation flag onto the first problem
			push(@problemData, {source_file    => $name,
			                    value          =>  $value,
			                    max_attempts   =>, $attemptLimit,
			                    continuation   => $continueFlag 
			                    });
		}
		close(SETFILENAME);
		($setName,
		 $paperHeaderFile,
		 $screenHeaderFile,
		 $time1,
		 $time2,
		 $time3,
		 \@problemData,
		);
	} else {
		warn "Can't open file $filePath\n";
	}
}

sub exportSetsToDef {
    	my ($self, %filenames) = @_;

	my $r        = $self->r;
	my $ce       = $r->ce;
	my $db       = $r->db;

	my (@exported, @skipped, %reason);

SET:	foreach my $set (keys %filenames) {

		my $fileName = $filenames{$set};
		$fileName .= ".def" unless $fileName =~ m/\.def$/;
		$fileName  = "set" . $fileName unless $fileName =~ m/^set/;
		# files can be exported to sub directories but not parent directories
		if ($fileName =~ /\.\./) {
			push @skipped, $set;
			$reason{$set} = "Illegal filename contains '..'";
			next SET;
		}

		my $setRecord = $db->getGlobalSet($set);
		unless (defined $setRecord) {
			push @skipped, $set;
			$reason{$set} = "No record found.";
			next SET;
		}
		my $filePath = $ce->{courseDirs}->{templates} . '/' . $fileName;

		# back up existing file
		if(-e $filePath) {
			rename($filePath, "$filePath.bak") or 
				$reason{$set} = "Existing file $filePath could not be backed up and was lost.";
		}
		
		my $openDate     = $self->formatDateTime($setRecord->open_date);
		my $dueDate      = $self->formatDateTime($setRecord->due_date);
		my $answerDate   = $self->formatDateTime($setRecord->answer_date);
		my $setHeader    = $setRecord->set_header;
		my $paperHeader  = $setRecord->hardcopy_header;
		my @problemList = $db->listGlobalProblems($set);

		my $problemList  = '';
		foreach my $prob (sort {$a <=> $b} @problemList) {
			my $problemRecord = $db->getGlobalProblem($set, $prob); # checked
			unless (defined $problemRecord) {
				push @skipped, $set;
				$reason{$set} = "No record found for problem $prob.";
				next SET;
			}
			my $source_file   = $problemRecord->source_file();
			my $value         = $problemRecord->value();
			my $max_attempts  = $problemRecord->max_attempts();
			$problemList     .= "$source_file, $value, $max_attempts \n";
		}
		my $fileContents = <<EOF;

openDate          = $openDate
dueDate           = $dueDate
answerDate        = $answerDate
paperHeaderFile   = $paperHeader
screenHeaderFile  = $setHeader
problemList       = 

$problemList



EOF

		$filePath = WeBWorK::Utils::surePathToFile($ce->{courseDirs}->{templates}, $filePath);
		eval {
			local *SETDEF;
			open SETDEF, ">$filePath" or die "Failed to open $filePath";
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
		return $value;
	}
	
	if ($type eq "number" or $type eq "text") {
		return CGI::input({type=>"text", name=>$fieldName, value=>$value, size=>$size});
	}
	
	if ($type eq "filelist") {
		return CGI::popup_menu({
			name => $fieldName,
			value => [ sort keys %$headerFiles ],
			labels => $headerFiles,
			default => $value || 0,
		});
	}

	if ($type eq "enumerable") {
		my $matched = undef; # Whether a synonym match has occurred

		# Process synonyms for enumerable objects
		foreach my $synonym (keys %$synonyms) {
			if ($synonym ne "*" and $value =~ m/$synonym/) {
				$value = $synonyms->{$synonym};
				$matched = 1;
			}
		}
		
		if (!$matched and exists $synonyms->{"*"}) {
			$value = $synonyms->{"*"};
		}
		
		return CGI::popup_menu({
			name => $fieldName, 
			values => [keys %$items],
			default => $value,
			labels => $items,
		});
	}
	
	if ($type eq "checked") {
		
		# FIXME: kludge (R)
		# if the checkbox is checked it returns a 1, if it is unchecked it returns nothing
		# in which case the hidden field overrides the parameter with a 0
		return CGI::checkbox(
			-name => $fieldName,
			-checked => $value,
			-label => "",
			-value => 1
		) . CGI::hidden(
			-name => $fieldName,
			-value => 0
		);
	}
}

sub recordEditHTML {
	my ($self, $Set, %options) = @_;
	my $r           = $self->r;
	my $urlpath     = $r->urlpath;
	my $ce          = $r->ce;
	my $db		= $r->db;
	my $authz	= $r->authz;
	my $user	= $r->param('user');
	my $root        = $ce->{webworkURLs}->{root};
	my $courseName  = $urlpath->arg("courseID");
	
	my $editMode = $options{editMode};
	my $exportMode = $options{exportMode};
	my $setSelected = $options{setSelected};

	my $publishedClass = $Set->published ? "Published" : "Unpublished";

	my $users = $db->countSetUsers($Set->set_id);
	my $totalUsers = $self->{totalUsers};
	my $problems = $db->listGlobalProblems($Set->set_id);
	
        my $usersAssignedToSetURL  = $self->systemLink($urlpath->new(type=>'instructor_users_assigned_to_set', args=>{courseID => $courseName, setID => $Set->set_id} ));
	my $problemListURL  = $self->systemLink($urlpath->new(type=>'instructor_set_detail', args=>{courseID => $courseName, setID => $Set->set_id} ));
	my $problemSetListURL = $self->systemLink($urlpath->new(type=>'instructor_set_list', args=>{courseID => $courseName, setID => $Set->set_id})) . "&editMode=1&visible_sets=" . $Set->set_id;
	my $imageURL = $ce->{webworkURLs}->{htdocs}."/images/edit.gif";
        my $imageLink = CGI::a({href => $problemSetListURL}, CGI::img({src=>$imageURL, border=>0}));
	
	my @tableCells;
	my %fakeRecord;
	my $set_id = $Set->set_id;
	$fakeRecord{select} = CGI::checkbox(-name => "selected_sets", -value => $set_id, -checked => $setSelected, -label => "", );
	$fakeRecord{set_id} = CGI::font({class=>$publishedClass}, $set_id) . ($editMode ? "" : $imageLink);
	$fakeRecord{problems} = (FIELD_PERMS()->{problems} and not $authz->hasPermissions($user, FIELD_PERMS()->{problems}))
					? "$problems"
					: CGI::a({href=>$problemListURL}, "$problems");
	$fakeRecord{users} = (FIELD_PERMS()->{users} and not $authz->hasPermissions($user, FIELD_PERMS()->{users}))
					? "$users/$totalUsers"
					: CGI::a({href=>$usersAssignedToSetURL}, "$users/$totalUsers");
	$fakeRecord{filename} = CGI::input({-name => "set.$set_id", -value=>"set$set_id.def", -size=>60});
					
		
	# Select
	if ($editMode) {
		# column not there
	} else {
		# selection checkbox
		push @tableCells, CGI::checkbox(
			-name => "selected_sets",
			-value => $set_id,
			-checked => $setSelected,
			-label => "",
		);
	}
	
	# Set ID
	push @tableCells, CGI::font({class=>$publishedClass}, $set_id . $imageLink);

	# Problems link
	if ($editMode) {
		# column not there
	} else {
		# "problem list" link
		push @tableCells, CGI::a({href=>$problemListURL}, "$problems");
	}
	
	# Users link
	if ($editMode) {
		# column not there
	} else {
		# "edit users assigned to set" link
		push @tableCells, CGI::a({href=>$usersAssignedToSetURL}, "$users/$totalUsers");
	}
	
	# Set Fields
	foreach my $field ($Set->NONKEYFIELDS) {
		my $fieldName = "set." . $set_id . "." . $field,		
		my $fieldValue = $Set->$field;
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = "readonly" unless $editMode;
		$fieldValue = $self->formatDateTime($fieldValue) if $field =~ /_date/;
		$fieldValue =~ s/ /&nbsp;/g unless $editMode;
		$fieldValue = ($fieldValue) ? "Yes" : "No" if $field =~ /published/ and not $editMode;
		push @tableCells, CGI::font({class=>$publishedClass}, $self->fieldEditHTML($fieldName, $fieldValue, \%properties));
		$fakeRecord{$field} = CGI::font({class=>$publishedClass}, $self->fieldEditHTML($fieldName, $fieldValue, \%properties));
	}

	my @fieldsToShow;
	if ($editMode) {
		@fieldsToShow = @{ EDIT_FIELD_ORDER() };
	} else {
		@fieldsToShow = @{ VIEW_FIELD_ORDER() };
	}
	
	if ($exportMode) {
		@fieldsToShow = @{ EXPORT_FIELD_ORDER() };
	}

	@tableCells = map { $fakeRecord{$_} } @fieldsToShow;

	return CGI::Tr({}, CGI::td({}, \@tableCells));
}

sub printTableHTML {
	my ($self, $SetsRef, $fieldNamesRef, %options) = @_;
	my $r                       = $self->r;
	my $authz                   = $r->authz;
	my $user                    = $r->param('user');
	my $setTemplate	            = $self->{setTemplate};
	my @Sets                    = @$SetsRef;
	my %fieldNames              = %$fieldNamesRef;
	
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

	
	my %sortSubs = %{ SORT_SUBS() };

	# FIXME: should this always presume to use the templates directory?
	# (no, but that can wait until we have an abstract ProblemLibrary API -- sam)
	my $templates_dir = $r->ce->{courseDirs}->{templates};
	my %probLibs = %{ $r->ce->{courseFiles}->{problibs} };
	my $exempt_dirs = join("|", keys %probLibs);
	my @headers = listFilesRecursive(
		$templates_dir,
		qr/header.*\.pg$/i, # match these files
		qr/^(?:$exempt_dirs|CVS)$/, # prune these directories
		0, # match against file name only
		1, # prune against path relative to $templates_dir
	);
	
	@headers = sort @headers;
	my %headers = map { $_ => $_ } @headers;
	$headers{""} = "Use System Default";
	$self->{headerFiles} = \%headers;	# store these header files so we don't have to look for them later.


	my @tableHeadings = map { $fieldNames{$_} } @realFieldNames;
	
	# prepend selection checkbox? only if we're NOT editing!
#	unshift @tableHeadings, "Select", "Set", "Problems" unless $editMode;

	# print the table
	if ($editMode or $exportMode) {
		print CGI::start_table({});
	} else {
		print CGI::start_table({-border=>1});
	}
	
	print CGI::Tr({}, CGI::th({}, \@tableHeadings));
	

	for (my $i = 0; $i < @Sets; $i++) {
		my $Set = $Sets[$i];
		
		print $self->recordEditHTML($Set,
			editMode => $editMode,
			exportMode => $exportMode,
			setSelected => exists $selectedSetIDs{$Set->set_id}
		);
	}
	
	print CGI::end_table();
	#########################################
	# if there are no users shown print message
	# 
	##########################################
	
	print CGI::p(
                      CGI::i("No sets shown.  Choose one of the options above to list the sets in the course.")
	) unless @Sets;
}

1;

=head1 AUTHOR

Written by Robert Van Dam, toenail (at) cif.rochester.edu

=cut
