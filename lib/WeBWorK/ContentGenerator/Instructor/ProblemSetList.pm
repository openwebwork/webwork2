################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
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

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(formatDateTime parseDateTime readFile readDirectory cryptPassword);

use constant HIDE_SETS_THRESHOLD => 50;
use constant DEFAULT_PUBLISHED_STATE => 1;

use constant EDIT_FORMS => [qw(cancelEdit saveEdit)];
use constant VIEW_FORMS => [qw(filter sort edit publish import score create export delete)];

use constant VIEW_FIELD_ORDER => [ qw( select set_id problems users published open_date due_date answer_date set_header problem_header) ];
use constant EDIT_FIELD_ORDER => [ qw( set_id published open_date due_date answer_date set_header problem_header) ];

use constant STATE_PARAMS => [qw(user effectiveUser key visible_sets no_visible_sets prev_visible_sets no_prev_visible_set editMode primarySortField secondarySortField)];

use constant SORT_SUBS => {
	set_id		=> \&bySetID,
	set_header	=> \&bySetHeader,
	problem_header	=> \&byProblemHeader,
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
		access => "readwrite",
	},
	problem_header => {
		type => "filelist",
		size => 10,
		access => "readwrite",
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
		set_id
		set_header
		problem_header
		open_date
		due_date
		answer_date
		published		
	)} = (
		"Select",
		"Problems",
		"Assigned Users",
		"Set Name", 
		"Set Header", 
		"Paper Header", 
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
		unless (grep { $_ eq $actionID } @{ VIEW_FORMS() }, @{ EDIT_FORMS() }) {
			die "Action $actionID not found";
		}
		my $actionHandler = "${actionID}_handler";
		my %genericParams;
		foreach my $param (qw(selected_sets)) {
			$genericParams{$param} = [ $r->param($param) ];
		}
		my %actionParams = $self->getActionParams($actionID);
		my %tableParams = $self->getTableParams();
		print CGI::div({class=>"Message"}, CGI::p("Results of last action performed: ", $self->$actionHandler(\%genericParams, \%actionParams, \%tableParams))), CGI::hr();

	}
		
	########## retrieve possibly changed values for member fields
	
	@allSetIDs = @{ $self->{allSetIDs} }; # do we need this one? YES, deleting or importing a set will change this.
	my @visibleSetIDs = @{ $self->{visibleSetIDs} };
	my @prevVisibleSetIDs = @{ $self->{prevVisibleSetIDs} };
	my @selectedSetIDs = @{ $self->{selectedSetIDs} };
	my $editMode = $self->{editMode};
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
	@Sets = sort $secondarySortSub @Sets;
	@Sets = sort $primarySortSub @Sets;

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
	
	my $i = 0;
	foreach my $actionID (@formsToShow) {
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
			-values => [qw(set_id set_header problem_header open_date due_date answer_date published)],
			-default => $actionParams{"action.sort.primary"}->[0] || "due_date",
			-labels => {
				set_id		=> "Set Name",
				set_header 	=> "Set Header",
				problem_header	=> "Paper Header",
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
			-values => [qw(set_id set_header problem_header open_date due_date answer_date published)],
			-default => $actionParams{"action.sort.secondary"}->[0] || "open_date",
			-labels => {
				set_id		=> "Set Name",
				set_header 	=> "Set Header",
				problem_header	=> "Paper Header",
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
		problem_header	=> "Paper Header",
		open_date	=> "Open Date",
		due_date	=> "Due Date",
		answer_date	=> "Answer Date",
		published	=> "Visibility",
	);
	
	return "sort by $names{$primary} and then by $names{$secondary}.";
}


sub edit_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r      = $self->r;
	my $authz  = $r->authz;
	my $user   = $r->param('user');
	
	return CGI::em("You are not authorized to modify problem sets.") 
		unless ($authz->hasPermissions($user, "modify_problem_sets"));
	
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

	my $r      = $self->r;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	return CGI::em("You are not authorized to modify problem sets.") 
		unless ($authz->hasPermissions($user, "modify_problem_sets"));
	
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

	my $r      = $self->r;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	return CGI::em("You are not authorized to modify problem sets.") 
		unless ($authz->hasPermissions($user, "modify_problem_sets"));

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

	my $r      = $self->r;
	my $db     = $r->db;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	return CGI::em("You are not authorized to modify problem sets.") 
		unless ($authz->hasPermissions($user, "modify_problem_sets"));
	
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

	my $r      = $self->r;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	return CGI::em("You are not authorized to score sets.") 
		unless ($authz->hasPermissions($user, "score_sets"));
	
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
	my $authz  = $r->authz;
	my $user   = $r->param('user');
	my $courseName = $urlpath->arg("courseID");

	return CGI::em("You are not authorized to score sets.") 
		unless ($authz->hasPermissions($user, "score_sets"));

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

	my $r      = $self->r;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	return CGI::em("You are not authorized to delete problem sets.") 
		unless ($authz->hasPermissions($user, "create_and_delete_problem_sets"));

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
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	return CGI::em("You are not authorized to delete problem sets.") 
		unless ($authz->hasPermissions($user, "create_and_delete_problem_sets"));

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
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	return CGI::em("You are not authorized to create problem sets.") 
		unless ($authz->hasPermissions($user, "create_and_delete_problem_sets"));
	
	return "Create a new set named: ", 
		CGI::textfield(
			-name => "action.create.name",
			-value => $actionParams{"action.create.name"}->[0] || "",
			-width => "50",
			-onchange => $onChange,
		);
}

sub create_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r      = $self->r;
	my $db     = $r->db;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	return CGI::em("You are not authorized to create problem sets.") 
		unless ($authz->hasPermissions($user, "create_and_delete_problem_sets"));
	
	my $newSetRecord = $db->newGlobalSet;
	my $newSetName = $actionParams->{"action.create.name"}->[0];
	return CGI::div({class => "ResultsWithError"}, "Failed to create new set: no set name specified!") unless $newSetName =~ /\S/;
	$newSetRecord->set_id($newSetName);
	$newSetRecord->set_header("");
	$newSetRecord->problem_header("");
	$newSetRecord->open_date("0");
	$newSetRecord->due_date("0");
	$newSetRecord->answer_date("0");
	$newSetRecord->published(DEFAULT_PUBLISHED_STATE);	# don't want students to see an empty set
	eval {$db->addGlobalSet($newSetRecord)};
	
	return CGI::div({class => "ResultsWithError"}, "Failed to create new set: $@") if $@;
	
	return "Successfully created new set $newSetName";
	
}

sub import_form {
	my ($self, $onChange, %actionParams) = @_;

	my $r      = $self->r;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	return CGI::em("You are not authorized to create problem sets.") 
		unless ($authz->hasPermissions($user, "create_and_delete_problem_sets"));
	
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

	my $r      = $self->r;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	return CGI::em("You are not authorized to create problem sets.") 
		unless ($authz->hasPermissions($user, "create_and_delete_problem_sets"));

	my @fileNames = @{ $actionParams->{"action.import.source"} };
	my $newSetName = $actionParams->{"action.import.name"}->[0];
	$newSetName = "" if @fileNames > 1; # cannot assign set names to multiple imports
	my $assign = $actionParams->{"action.import.assign"}->[0];
	
	my ($added, $skipped) = $self->importSetsFromDef($newSetName, $assign, @fileNames);

	# make new sets visible... do we really want to do this? probably.
	push @{ $self->{visibleSetIDs} }, @$added;
	push @{ $self->{allSetIDs} }, @$added;
	
	my $numAdded = @$added;
	my $numSkipped = @$skipped;

	return 	$numAdded . " set" . ($numAdded == 1 ? "" : "s") . " added, "
		. $numSkipped . " set" . ($numSkipped == 1 ? "" : "s") . " skipped.";
}

sub export_form {
	my ($self, $onChange, %actionParams) = @_;
	#return CGI::i("Exporting multiple sets would probably require a different form if you want to specify their names");
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
# 		" to ",
# 		CGI::popup_menu(
# 			-name=>"action.export.target",
# 			-values => [ "new", $self->getDefList() ],
# 			-labels => { new => "a new file named:" },
# 			-default => $actionParams{"action.export.target"}->[0] || "",
# 			-onchange => $onChange,
# 		),
# 		#CGI::br(),
# 		#"new file to create: ",
# 		CGI::textfield(
# 			-name => "action.export.new",
# 			-value => $actionParams{"action.export.new"}->[0] || "",,
# 			-width => "50",
# 			-onchange => $onChange,
# 		),
# 		CGI::tt(".def"),
	);
}

# FIXME: this will NOT work as is
sub export_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	
	my $scope = $actionParams->{"action.export.scope"}->[0];
# 	my $target = $actionParams->{"action.export.target"}->[0];
# 	my $new = $actionParams->{"action.export.new"}->[0];
# 	
# 	my $fileName;
# 	if ($target eq "new") {
# 		$fileName = $new;
# 	} else {
# 		$fileName = $target;
# 	}
	
#	$fileName .= ".def" unless $fileName =~ m/\.def$/;
	
	my @setIDsToExport;
	if ($scope eq "all") {
		@setIDsToExport = @{ $self->{allSetIDs} };
	} elsif ($scope eq "visible") {
		@setIDsToExport = @{ $self->{visibleSetIDs} };
	} elsif ($scope eq "selected") {
		@setIDsToExport = @{ $self->{selectedSetIDs} };
	}
	my @setIDsExported = ();
	foreach my $set (@setIDsToExport) {
		if ($self->exportSetsToDef($set) ) {
			push @setIDsExported, $set;   # success
		}
	}
	
	return scalar @setIDsExported . " sets exported";
}

sub exportSetsToDef {
    #FIXME  -- this needs refining.
	my $self     = shift;
	my $fileName = shift;
	my $setName  = $fileName;
	my $ce       = $self->r->ce;
	my $db       = $self->r->db;
	
	$fileName .= ".def" unless $fileName =~ m/\.def$/;
    $fileName  = "set".$fileName unless $fileName =~ m/^set/;
	my $setRecord   = $db->getGlobalSet($setName);
		my $filePath  = $ce->{courseDirs}->{templates}.'/'.$fileName;
		# back up existing file
		if(-e $filePath) {
		    rename($filePath,"$filePath.bak") or 
	    	       die "Can't rename $filePath to $filePath.bak ",
	    	           "Check permissions for webserver on directories. $!";
	        $self->addgoodmessage(CGI::p("Earlier set def file backed up to $filePath.bak"));
		}
	    my $openDate     = formatDateTime($setRecord->open_date);
	    my $dueDate      = formatDateTime($setRecord->due_date);
	    my $answerDate   = formatDateTime($setRecord->answer_date);
	    my $setHeader    = $setRecord->set_header;
	    
	    my @problemList = $db->listGlobalProblems($setName);
	    my $problemList  = '';
	    foreach my $prob (sort {$a <=> $b} @problemList) {
	    	my $problemRecord = $db->getGlobalProblem($setName, $prob); # checked
	    	die "global problem $prob for set $setName not found" unless defined($problemRecord);
	    	my $source_file   = $problemRecord->source_file();
			my $value         = $problemRecord->value();
			my $max_attempts  = $problemRecord->max_attempts();
	    	$problemList     .= "$source_file, $value, $max_attempts \n";	    
	    }
	    my $fileContents = <<EOF;

openDate          = $openDate
dueDate           = $dueDate
answerDate        = $answerDate
paperHeaderFile   = $setHeader
screenHeaderFile  = $setHeader
problemList       = 

$problemList



EOF


	    $self->saveProblem($fileContents, $filePath);
	    $self->addgoodmessage(CGI::p("Set definition saved to $filePath"));
	return 1;
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
					$Set->$field(parseDateTime($tableParams->{$param}->[0]));
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

################################################################################
# sorts
################################################################################

sub bySetID         { $a->set_id         cmp $b->set_id         }
sub bySetHeader     { $a->set_header     cmp $b->set_header     }
sub byProblemHeader { $a->problem_header cmp $b->problem_header }
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
		my $displayKey = formatDateTime($key) || "<none>";
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
		die "illegal character in input: \"/\"" if $fileName =~ m|/|;
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
		$newSetRecord->problem_header($paperHeaderFile);
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
		my ($time1, $time2, $time3) = map { $_ =~ s/\s*at\s*/ /; WeBWorK::Utils::parseDateTime($_);  }    ($openDate, $dueDate, $answerDate);
	
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

# search recursively through a directory looking for all filenames matching a given pattern
sub recurseDirectory {

	my ($self, $dir, $pattern) = @_;
	
	my @dirs = grep {$_ ne "." and $_ ne ".." and $_ ne "Library" and $_ ne "CVS" and -d "$dir/$_"} readDirectory($dir);

	my @files = map { "$dir/$_" } $self->read_dir($dir, $pattern);

	foreach (@dirs) {
		push (@files, $self->recurseDirectory("$dir/$_", $pattern));
	}

	return @files;
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
	my $root        = $ce->{webworkURLs}->{root};
	my $courseName  = $urlpath->arg("courseID");
	
	my $editMode = $options{editMode};
	my $setSelected = $options{setSelected};

	my $publishedClass = $Set->published ? "Published" : "Unpublished";

	my $users = $db->countSetUsers($Set->set_id);
	my $totalUsers = $self->{totalUsers};
	my $problems = $db->listGlobalProblems($Set->set_id);
	
        my $usersAssignedToSetURL  = $self->systemLink($urlpath->new(type=>'instructor_users_assigned_to_set', args=>{courseID => $courseName, setID => $Set->set_id} ));
	my $problemListURL  = $self->systemLink($urlpath->new(type=>'instructor_problem_list', args=>{courseID => $courseName, setID => $Set->set_id} ));
	my $problemSetListURL = $self->systemLink($urlpath->new(type=>'instructor_set_list', args=>{courseID => $courseName, setID => $Set->set_id})) . "&editMode=1&visible_sets=" . $Set->set_id;
	my $imageURL = $ce->{webworkURLs}->{htdocs}."/images/edit.gif";
        my $imageLink = CGI::a({href => $problemSetListURL}, CGI::img({src=>$imageURL, border=>0}));
	
	my @tableCells;
	my %fakeRecord;
	$fakeRecord{select} = CGI::checkbox(-name => "selected_sets", -value => $Set->set_id, -checked => $setSelected, -label => "", );
	$fakeRecord{set_id} = CGI::font({class=>$publishedClass}, $Set->set_id) . ($editMode ? "" : $imageLink);
	$fakeRecord{problems} = CGI::a({href=>$problemListURL}, "$problems");
	$fakeRecord{users} = CGI::a({href=>$usersAssignedToSetURL}, "$users/$totalUsers");
		
	# Select
	if ($editMode) {
		# column not there
	} else {
		# selection checkbox
		push @tableCells, CGI::checkbox(
			-name => "selected_sets",
			-value => $Set->set_id,
			-checked => $setSelected,
			-label => "",
		);
	}
	
	# Set ID
	push @tableCells, CGI::font({class=>$publishedClass}, $Set->set_id . $imageLink);

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
		my $fieldName = "set." . $Set->set_id . "." . $field,		
		my $fieldValue = $Set->$field;
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = "readonly" unless $editMode;
		$fieldValue = formatDateTime($fieldValue) if $field =~ /_date/;
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

	@tableCells = map { $fakeRecord{$_} } @fieldsToShow;

	return CGI::Tr({}, CGI::td({}, \@tableCells));
}

sub printTableHTML {
	my ($self, $SetsRef, $fieldNamesRef, %options) = @_;
	my $r                       = $self->r;
	my $setTemplate	            = $self->{setTemplate};
	my @Sets                    = @$SetsRef;
	my %fieldNames              = %$fieldNamesRef;
	
	my $editMode                = $options{editMode};
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

	
	my %sortSubs = %{ SORT_SUBS() };

	# FIXME: should this always presume to use the templates directory?
	my @headers = $self->recurseDirectory($self->{ce}->{courseDirs}->{templates}, '(?i)header.*?\\.pg$');
	map { s|^$self->{ce}->{courseDirs}->{templates}/?|| } @headers;
	@headers = sort @headers;
	my %headers = map { $_ => $_ } @headers;
	$headers{""} = "Use System Default";
	$self->{headerFiles} = \%headers;	# store these header files so we don't have to look for them later.

	my @tableHeadings;
	foreach my $field (@realFieldNames) {
		my $result = $fieldNames{$field};
		push @tableHeadings, $result;
	};
	
	# prepend selection checkbox? only if we're NOT editing!
#	unshift @tableHeadings, "Select", "Set", "Problems" unless $editMode;


	
	# print the table
	if ($editMode) {
		print CGI::start_table({});
	} else {
		print CGI::start_table({-border=>1});
	}
	
	print CGI::Tr({}, CGI::th({}, \@tableHeadings));
	

	for (my $i = 0; $i < @Sets; $i++) {
		my $Set = $Sets[$i];
		
		print $self->recordEditHTML($Set,
			editMode => $editMode,
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
###########################################################################
# utility
###########################################################################
sub saveProblem {     
    my $self      = shift;
	my ($body, $probFileName)= @_;
	local(*PROBLEM);
	open (PROBLEM, ">$probFileName") ||
		$self->addbadmessage(CGI::p("Could not open $probFileName for writing. Check that the  permissions for this problem are 660 (-rw-rw----)"));
	print PROBLEM $body;
	close PROBLEM;
	chmod 0660, "$probFileName" ||
		$self->addbadmessage(CGI::p("CAN'T CHANGE PERMISSIONS ON FILE $probFileName"));
}
1;

