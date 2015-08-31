################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
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
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Utils qw(timeToSec readFile listFilesRecursive cryptPassword sortByName);

use constant HIDE_SETS_THRESHOLD => 500;
use constant DEFAULT_VISIBILITY_STATE => 1;
use constant DEFAULT_ENABLED_REDUCED_SCORING_STATE => 0;
use constant ONE_WEEK => 60*60*24*7;  

use constant EDIT_FORMS => [qw(cancelEdit saveEdit)];
use constant VIEW_FORMS => [qw(filter sort edit publish import export score create delete)];
use constant EXPORT_FORMS => [qw(cancelExport saveExport)];

use constant VIEW_FIELD_ORDER => [ qw( select set_id problems users visible enable_reduced_scoring open_date due_date answer_date) ];
use constant EDIT_FIELD_ORDER => [ qw( set_id visible enable_reduced_scoring open_date due_date answer_date) ];
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
#	set_header	=> \&bySetHeader,  # can't figure out why these are useful
#	hardcopy_header	=> \&byHardcopyHeader,  # can't figure out why these are useful
	open_date	=> \&byOpenDate,
	due_date	=> \&byDueDate,
	answer_date	=> \&byAnswerDate,
	visible	=> \&byVisible,

};

# note that field_properties for some fields, in particular, gateway 
# parameters, are not currently shown in the edit or display tables
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
		size => 26,
		access => "readwrite",
	},
	due_date => {
		type => "text",
		size => 26,
		access => "readwrite",
	},
	answer_date => {
		type => "text",
		size => 26,
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
	}
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
		    @setsToScore = $db->listGlobalSets;
		} elsif ($scope eq "visible") {
			@setsToScore = @{ $r->param("visibleSetIDs") };
		} elsif ($scope eq "selected") {
			@setsToScore = $r->param("selected_sets");
		}

		my $uri = $self->systemLink( $urlpath->newFromModule('WeBWorK::ContentGenerator::Instructor::Scoring', $r, courseID=>$courseName),
						params=>{
							scoreSelected=>"ScoreSelected",
							selectedSet=>\@setsToScore,
#							recordSingleSetScores=>''
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
	

	my $root = $ce->{webworkURLs}->{root};

	# templates for getting field names
	my $setTemplate = $self->{setTemplate} = $db->newGlobalSet;
	
	return CGI::div({class => "ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	########## set initial values for state fields
	
	my @allSetIDs = $db->listGlobalSets;
	# DBFIXME count would suffice here :P
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
	
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to modify homework sets."))
		if $self->{editMode} and not $authz->hasPermissions($user, "modify_problem_sets");
	
	$self->{exportMode} = $r->param("exportMode") || 0;

	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to modify set definition files."))
		if $self->{exportMode} and not $authz->hasPermissions($user, "modify_set_def_files");
	
	$self->{primarySortField} = $r->param("primarySortField") || "due_date";
	$self->{secondarySortField} = $r->param("secondarySortField") || "open_date";
	
	
	#########################################
	# collect date information from sets
	#########################################

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
	
	#########################################
	#  call action handler  
	#########################################
	
	my $actionID = $r->param("action");
	$self->{actionID} = $actionID;
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
			$self->addmessage( CGI::div("Results of last action performed: "));
			$self->addmessage(
			                     $self->$actionHandler(\%genericParams, \%actionParams, \%tableParams), 
			                     CGI::hr()
			);
		} else {
			return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to perform this action."));
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
		visible
		enable_reduced_scoring	
	)} = (
		$r->maketext("Select"),
		$r->maketext("Edit Problems"),
		$r->maketext("Edit Assigned Users"),
		$r->maketext("Set Definition Filename"),
		$r->maketext("Edit Set Data"), 
		$r->maketext("Set Header"), 
		$r->maketext("Hardcopy Header"), 
		$r->maketext("Open Date"), 
		$r->maketext("Due Date"), 
		$r->maketext("Answer Date"), 
		$r->maketext("Visible"),
		$r->maketext("Reduced Scoring Enabled") 
	);
	


	my $actionID = $self->{actionID};
	
	########## retrieve possibly changed values for member fields
	
	my @allSetIDs = @{ $self->{allSetIDs} }; # do we need this one? YES, deleting or importing a set will change this.
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
	#warn "exportMode = $exportMode\n";
	
	########## get required users
		
	# DBFIXME use an iterator
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
	
	print CGI::start_form({method=>"post", action=>$self->systemLink($urlpath,authen=>0), name=>"problemsetlist", id=>"problemsetlist"});
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
	
	print CGI::p(CGI::b($r->maketext("Any changes made below will be reflected in the set for ALL students."))) if $editMode;

	print CGI::start_table({});
	print CGI::Tr({}, CGI::td({-colspan=>2}, $r->maketext("Select an action to perform:")));

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
	
	my $selectAll =CGI::input({-type=>'button', -name=>'check_all', -value=>$r->maketext('Select all sets'),
	       onClick => "for (i in document.problemsetlist.elements)  { 
	                       if (document.problemsetlist.elements[i].name =='selected_sets') { 
	                           document.problemsetlist.elements[i].checked = true
	                       }
	                    }" });
   	my $selectNone =CGI::input({-type=>'button', -name=>'check_none', -value=>$r->maketext('Unselect all sets'),
	       onClick => "for (i in document.problemsetlist.elements)  { 
	                       if (document.problemsetlist.elements[i].name =='selected_sets') { 
	                          document.problemsetlist.elements[i].checked = false
	                       }
	                    }" });
	unless ($editMode or $exportMode) {
		print CGI::Tr({}, CGI::td({ colspan=>2, -align=>"center"},
			$selectAll." ". $selectNone
			)
		);
	}
	print CGI::Tr({}, CGI::td({-colspan=>2, -align=>"center"},
		CGI::submit(-value=>$r->maketext("Take Action!")))
	);
	print CGI::end_table();
	
	########## print table
	
	########## first adjust heading if in editMode
	$prettyFieldNames{set_id} = $r->maketext("Edit All Set Data") if $editMode;
	$prettyFieldNames{enable_reduced_scoring} = $r->maketext('Enable Reduced Scoring') if $editMode;
	
	
	print CGI::p({},$r->maketext("Showing"), " ", scalar @visibleSetIDs, " ", $r->maketext("out of"), " ", scalar @allSetIDs, $r->maketext("sets").".");
	
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
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	#return CGI::table({}, CGI::Tr({-valign=>"top"},
	#	CGI::td({}, 
	return join("", 
			$r->maketext("Show")." ",
			CGI::popup_menu(
				-name => "action.filter.scope",
				-values => [qw(all none selected match_ids visible unvisible)],
				-default => $actionParams{"action.filter.scope"}->[0] || "match_ids",
				-labels => {
					all => $r->maketext("all sets"),
					none => $r->maketext("no sets"),
					selected => $r->maketext("sets checked below"),
					visible => $r->maketext("sets visible to students"),
					unvisible => $r->maketext("sets hidden from students"), 
					match_ids => $r->maketext("sets with matching set IDs:"),
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
			" (".$r->maketext("separate multiple IDs with commas").")",
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
	} elsif ($scope eq "visible") {
		# DBFIXME do filtering in the database, please!
		my @setRecords = $db->getGlobalSets(@{$self->{allSetIDs}});
		my @visibleSetIDs = map { $_->visible ? $_->set_id : ""} @setRecords;		
		$self->{visibleSetIDs} = \@visibleSetIDs;
	} elsif ($scope eq "unvisible") {
		# DBFIXME do filtering in the database, please!
		my @setRecords = $db->getGlobalSets(@{$self->{allSetIDs}});
		my @unvisibleSetIDs = map { (not $_->visible) ? $_->set_id : ""} @setRecords;
		$self->{visibleSetIDs} = \@unvisibleSetIDs;
	}
	
	return $result;
}

sub sort_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;

	return join ("",
		$r->maketext("Primary sort").": ",
		CGI::popup_menu(
			-name => "action.sort.primary",
			-values => [qw(set_id open_date due_date answer_date visible)],
			-default => $actionParams{"action.sort.primary"}->[0] || "due_date",
			-labels => {
				set_id		=> $r->maketext("Set Name"),
				set_header 	=> $r->maketext("Set Header"),
				hardcopy_header	=> $r->maketext("Hardcopy Header"),
				open_date	=> $r->maketext("Open Date"),
				due_date	=> $r->maketext("Due Date"),
				answer_date	=> $r->maketext("Answer Date"),
				visible	=> $r->maketext("Visibility"),
			},
			-onchange => $onChange,
		),
		" ".$r->maketext("Secondary sort").": ",
		CGI::popup_menu(
			-name => "action.sort.secondary",
			-values => [qw(set_id set_header hardcopy_header open_date due_date answer_date visible)],
			-default => $actionParams{"action.sort.secondary"}->[0] || "open_date",
			-labels => {
				set_id		=> $r->maketext("Set Name"),
				set_header 	=> $r->maketext("Set Header"),
				hardcopy_header	=> $r->maketext("Hardcopy Header"),
				open_date	=> $r->maketext("Open Date"),
				due_date	=> $r->maketext("Due Date"),
				answer_date	=> $r->maketext("Answer Date"),
				visible	=> $r->maketext("Visibility"),
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
		visible	=> "Visibility",
	);
	
	return "sort by $names{$primary} and then by $names{$secondary}.";
}


sub edit_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;

	return join("",
		$r->maketext("Edit")." ",
		CGI::popup_menu(
			-name => "action.edit.scope",
			-values => [qw(all visible selected)],
			-default => $actionParams{"action.edit.scope"}->[0] || "selected",
			-labels => {
				all => $r->maketext("all sets"),
				visible => $r->maketext("visible sets"),
				selected => $r->maketext("selected sets"),
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
	my $r = $self->r;
	return join ("",
		$r->maketext("Make")." ",
		CGI::popup_menu(
			-name => "action.publish.scope",
			-values => [ qw(none all selected) ],
			-default => $actionParams{"action.publish.scope"}->[0] || "selected",
			-labels => {
				none => "",
				all => $r->maketext("all sets"),
#				visible => "visible sets",
				selected => $r->maketext("selected sets"),
			},
			-onchange => $onChange,
		),
		CGI::popup_menu(
			-name => "action.publish.value",
			-values => [ 0, 1 ],
			-default => $actionParams{"action.publish.value"}->[0] || "1",
			-labels => {
				0 => $r->maketext("hidden"),
				1 => $r->maketext("visible"),
			},
			-onchange => $onChange,
		),
		" ".$r->maketext("for students").".",
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
		$result = CGI::div({class=>"ResultsWithError"},"No change made to any set.");
	} elsif ($scope eq "all") {
		@setIDs = @{ $self->{allSetIDs} };
		$result = CGI::div({class=>"ResultsWithoutError"},"All sets $verb all students.");
	} elsif ($scope eq "visible") {
		@setIDs = @{ $self->{visibleSetIDs} };
		$result = CGI::div({class=>"ResultsWithoutError"},"All visible sets $verb all students.");
	} elsif ($scope eq "selected") {
		@setIDs = @{ $genericParams->{selected_sets} };
		$result = CGI::div({class=>"ResultsWithoutError"},"All selected sets $verb all students.");
	}
	
	# can we use UPDATE here, instead of fetch/change/store?
	my @sets = $db->getGlobalSets(@setIDs);
	
	map { $_->visible("$value") if $_; $db->putGlobalSet($_); } @sets;
	
	return $result
	
}
sub enable_reduced_scoring_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	my $ce = $self->ce;

	return join ("",
		"Make ",
		CGI::popup_menu(
			-name => "action.enable_reduced_scoring.scope",
			-values => [ qw(none all selected) ],
			-default => $actionParams{"action.enable_reduced_scoring.scope"}->[0] || "selected",
			-labels => {
				none => "",
				all => $r->maketext("all sets"),
#				visible => "visible sets",
				selected => $r->maketext("selected sets"),
			},
			-onchange => $onChange,
		),
		CGI::popup_menu(
			-name => "action.enable_reduced_scoring.value",
			-values => [ 0, 1 ],
			-default => $actionParams{"action.enable_reduced_scoring.value"}->[0] || "1",
			-labels => {
				0 => "disable",
				1 => "enable",
			},
			-onchange => $onChange,
		),
		" reduced sccoring.",
	);
}

sub enable_reduced_scoring_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;

	my $result = "";
	
	my $scope = $actionParams->{"action.enable_reduced_scoring.scope"}->[0];
	my $value = $actionParams->{"action.enable_reduced_scoring.value"}->[0];

	my $verb = $value ? "enabled" : "disabled";
	
	my @setIDs;
	
	if ($scope eq "none") { # FIXME: double negative "Make no sets hidden" might make professor expect all sets to be made visible.
		@setIDs = ();
		$result =  CGI::div({class=>"ResultsWithError"}, "No change made to any set.");
	} elsif ($scope eq "all") {
		@setIDs = @{ $self->{allSetIDs} };
		$result = CGI::div({class=>"ResultsWithoutError"},"Reduced Scoring $verb for all sets.");
	} elsif ($scope eq "visible") {
		@setIDs = @{ $self->{visibleSetIDs} };
		$result = CGI::div({class=>"ResultsWithoutError"},"Reduced Scoring $verb for visable sets.");
	} elsif ($scope eq "selected") {
		@setIDs = @{ $genericParams->{selected_sets} };
		$result = CGI::div({class=>"ResultsWithoutError"},"Reduced Scoring $verb for selected sets.");
	}
	
	# can we use UPDATE here, instead of fetch/change/store?
	my @sets = $db->getGlobalSets(@setIDs);
	
	foreach my $set (@sets) {
	    next unless $set;
	    $set->enable_reduced_scoring("$value");
	    if ($value  && !$set->reduced_scoring_date) {
		$set->reduced_scoring_date($set->due_date -
					  60*$ce->{pg}{ansEvalDefaults}{reducedScoringPeriod});
	    }
	    $db->putGlobalSet($set);
	}
	
	
	return $result
	
}

sub score_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;

	return join ("",
		"Score ",
		CGI::popup_menu(
			-name => "action.score.scope",
			-values => [qw(none all selected)],
			-default => $actionParams{"action.score.scope"}->[0] || "none",
			-labels => {
				none => $r->maketext("no sets").".",
				all => $r->maketext("all sets").".",
				selected => $r->maketext("selected sets").".",
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
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;

	return join("",
		CGI::div({class=>"ResultsWithError"}, 
			$r->maketext("Delete")." ",
			CGI::popup_menu(
				-name => "action.delete.scope",
				-values => [qw(none selected)],
				-default => "none", #  don't make it easy to delete # $actionParams{"action.delete.scope"}->[0] || "none",
				-labels => {
					none => $r->maketext("no sets").".",
					#visible => "visible sets.",
					selected => $r->maketext("selected sets").".",
				},
				-onchange => $onChange,
			),
			CGI::em(" ".$r->maketext("Deletion destroys all set-related data and is not undoable!")),
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
	 return CGI::div({class=>"ResultsWithoutError"},  "deleted $num set" .
	                                           ($num == 1 ? "" : "s")
	);
}

sub create_form {
	my ($self, $onChange, %actionParams) = @_;

	my $r      = $self->r;
	
	return $r->maketext($r->maketext("Create a new set named:"))." ", 
		CGI::textfield(
			-name => "action.create.name",
			-value => $actionParams{"action.create.name"}->[0] || "",
			-width => "50",
			-onchange => $onChange,
		),
		" ".$r->maketext("as")." ",
		CGI::popup_menu(
			-name => "action.create.type",
			-values => [qw(empty copy)],
			-default => $actionParams{"action.create.type"}->[0] || "empty",
			-labels => {
				empty => $r->maketext("a new empty set").".",
				copy => $r->maketext("a duplicate of the first selected set").".",
			},
			-onchange => $onChange,
		);
			
}

sub create_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r      = $self->r;
	my $db     = $r->db;
	
	my $newSetID = $actionParams->{"action.create.name"}->[0];
	return CGI::div({class => "ResultsWithError"}, "Failed to create new set: no set name specified!") unless $newSetID =~ /\S/;
	return CGI::div({class => "ResultsWithError"}, "Set $newSetID exists.  No set created") if $db->existsGlobalSet($newSetID);
	my $newSetRecord = $db->newGlobalSet;
	my $oldSetID = $self->{selectedSetIDs}->[0];

	my $type = $actionParams->{"action.create.type"}->[0];
	# It's convenient to set the open date one week from now so that it is 
	# not accidentally available to students.  We set the due and answer date
	# to be two weeks from now.


	if ($type eq "empty") {
		$newSetRecord->set_id($newSetID);
		$newSetRecord->set_header("defaultHeader");
		$newSetRecord->hardcopy_header("defaultHeader");
		$newSetRecord->open_date(time + ONE_WEEK());
		$newSetRecord->due_date(time + 2*ONE_WEEK() );
		$newSetRecord->answer_date(time + 2*ONE_WEEK() );
		$newSetRecord->visible(DEFAULT_VISIBILITY_STATE());	# don't want students to see an empty set
		$newSetRecord->enable_reduced_scoring(DEFAULT_ENABLED_REDUCED_SCORING_STATE());
		$db->addGlobalSet($newSetRecord);
	} elsif ($type eq "copy") {
		return CGI::div({class => "ResultsWithError"}, "Failed to duplicate set: no set selected for duplication!") unless $oldSetID =~ /\S/;
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
    #  Assign set to current active user
     my $userName = $r->param('user'); # FIXME possible security risk
     $self->assignSetToUser($userName, $newSetRecord); # cures weird date error when no-one assigned to set
	 $self->addgoodmessage("Set $newSetID was assigned to $userName."); # not currently used

	push @{ $self->{visibleSetIDs} }, $newSetID;
	push @{ $self->{allSetIds} }, $newSetID;
	
	return CGI::div({class => "ResultsWithError"}, "Failed to create new set: $@") if $@;
	
	 return CGI::div({class=>"ResultsWithoutError"},"Successfully created new set $newSetID" );
	
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
		$r->maketext("Import")." ",
		CGI::popup_menu(
			-name => "action.import.number",
			-values => [ 1, 8 ],
			-default => $actionParams{"action.import.number"}->[0] || "1",
			-labels => {
				1 => $r->maketext("a single set"),
				8 => $r->maketext("multiple sets"),
			},
			-onchange => "$onChange;$importScript",
		),
		" ".$r->maketext("from")." ", # set definition file(s) ",
		CGI::popup_menu(
			-name => "action.import.source",
			-values => [ "", $self->getDefList() ],
			-labels => { "" => $r->maketext("the following file(s)") },
			-default => $actionParams{"action.import.source"}->[0] || "",
			-size => $actionParams{"action.import.number"}->[0] || "1",
			-onchange => $onChange,
		),
		" ".$r->maketext("with set name(s):")." ",
		CGI::textfield(
			-name => "action.import.name",
			-value => $actionParams{"action.import.name"}->[0] || "",
			-width => "50",
			-onchange => $onChange,
		),
		($authz->hasPermissions($user, "assign_problem_sets")) 
			?
			$r->maketext("assigning this set to")." " .
			CGI::popup_menu(
				-name => "action.import.assign",
				-value => [qw(user all)],
				-default => $actionParams{"action.import.assign"}->[0] || "user",
				-labels => {
					all => $r->maketext("all current users").".",
					user => $r->maketext("only")." ".$user.".",
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

   return CGI::div(
		{class=>"ResultsWithoutError"},	
		$numAdded . " set" . ($numAdded == 1 ? "" : "s") . " added, "
		. $numSkipped . " set" . ($numSkipped == 1 ? "" : "s") . " skipped"
		. " (" . join (", ", @$skipped) . ") "
	);
}

sub export_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;

	return join("",
		"Export ",
		CGI::popup_menu(
			-name => "action.export.scope",
			-values => [qw(all visible selected)],
			-default => $actionParams{"action.export.scope"}->[0] || "visible",
			-labels => {
				all => $r->maketext("all sets"),
				visible => $r->maketext("visible sets"),
				selected => $r->maketext("selected sets"),
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
	
	return   CGI::div({class=>"ResultsWithoutError"},  $result);
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
	
	return CGI::div({class=>"ResultsWithError"},  "export abandoned");
}

sub saveExport_form {
	my ($self, $onChange, %actionParams) = @_;
	return "Export selected sets.";
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
	my $resultFont = ($numSkipped)? "ResultsWithError" : "ResultsWithoutError";
	
	my @reasons = map { "set $_ - " . $reason->{$_} } keys %$reason;

	return 	CGI::div( {class=>$resultFont},
	    $numExported . " set" . ($numExported == 1 ? "" : "s") . " exported, "
		. $numSkipped . " set" . ($numSkipped == 1 ? "" : "s") . " skipped."
		. (($numSkipped) ? CGI::ul(CGI::li(\@reasons)) : "")
		);

}

sub cancelEdit_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	return $r->maketext("Abandon changes");
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
	
	return CGI::div({class=>"ResultsWithError"}, "changes abandoned");
}

sub saveEdit_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	return $r->maketext("Save changes");
}

sub saveEdit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r           = $self->r;
	my $db          = $r->db;
	my $ce          = $r->ce;

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
				} elsif ($field eq 'enable_reduced_scoring') {
				    #If we are enableing reduced scoring, make sure the reduced scoring date is set
				    my $value = $tableParams->{$param}->[0];
				    $Set->enable_reduced_scoring($value);
				    if (!$Set->reduced_scoring_date) {
					$Set->reduced_scoring_date($Set->due_date -
								  60*$ce->{pg}{ansEvalDefaults}{reducedScoringPeriod});
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
		return CGI::div({class=>'ResultsWithError'}, "Error: open date cannot be more than 10 years from now in set $setID")
			if $Set->open_date > $cutoff;
		return CGI::div({class=>'ResultsWithError'}, "Error: due date cannot be more than 10 years from now in set $setID")
			if $Set->due_date > $cutoff;
		return CGI::div({class=>'ResultsWithError'}, "Error: answer date cannot be more than 10 years from now in set $setID")
			if $Set->answer_date > $cutoff;
		
		# Check that the open, due and answer dates are in increasing order.
		# Bail if this is not correct.
		if ($Set->open_date > $Set->due_date)  {
			return CGI::div({class=>'ResultsWithError'}, "Error: Due date must come after open date in set $setID");
		}
		if ($Set->due_date > $Set->answer_date) {
			return CGI::div({class=>'ResultsWithError'}, "Error: Answer date must come after due date in set $setID");
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
	
	return CGI::div({class=>"ResultsWithError"}, "changes saved" );
}

sub duplicate_form {
	my ($self, $onChange, %actionParams) = @_;

	my $r = $self->r;
	my @visible_sets = $r->param('visible_sets');

	return "" unless @visible_sets == 1;
	
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
	# DBFIXME checking for existence -- don't need to fetch
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

# I can't figure out why these are useful

# sub bySetHeader     { $a->set_header     cmp $b->set_header     }
# sub byHardcopyHeader { $a->hardcopy_header cmp $b->hardcopy_header }
#FIXME  eventually we may be able to remove these checks, if we can trust 
# that the dates are always defined
# dates which are the empty string '' or undefined  are treated as 0
sub byOpenDate      { my $result = eval{( $a->open_date || 0 )      <=> ( $b->open_date || 0 ) };
                      return $result unless $@;
                      warn "Open date not correctly defined.";
                      return 0;
}
sub byDueDate       { my $result = eval{( $a->due_date || 0 )     <=> ( $b->due_date || 0 )   };      
                      return $result unless $@;
                      warn "Due date not correctly defined.";
                      return 0;
}
sub byAnswerDate    { my $result = eval{( $a->answer_date || 0)    <=> ( $b->answer_date || 0 )  };    
                      return $result unless $@;
                      warn "Answer date not correctly defined.";
                      return 0;
}
sub byVisible     { my $result = eval{$a->visible      cmp $b->visible   };      
                      return $result unless $@;
                      warn "Visibility status not correctly defined.";
                      return 0;
}

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

	# if the user includes "following files" in a multiple selection
	# it shows up here as "" which causes the importing to die
	# so, we select on filenames containing non-whitespace
	@setDefFiles = grep(/\S/, @setDefFiles);

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
	# DBFIXME all we need here is set IDs, right? why fetch entire records?
	my %allSets = map { $_->set_id => 1 if $_} $db->getGlobalSets(@allSetIDs); # checked

	my (@added, @skipped);

	foreach my $set_definition_file (@setDefFiles) {

		debug("$set_definition_file: reading set definition file");
		# read data in set definition file
		my ($setName, $paperHeaderFile, $screenHeaderFile, $openDate, $dueDate, $answerDate, $ra_problemData, $assignmentType, $attemptsPerVersion, $timeInterval, $versionsPerInterval, $versionTimeLimit, $problemRandOrder, $problemsPerPage, $hideScore, $hideWork,$timeCap,$restrictIP,$restrictLoc,$relaxRestrictIP) = $self->readSetDef($set_definition_file);
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
		$newSetRecord->enable_reduced_scoring(DEFAULT_ENABLED_REDUCED_SCORING_STATE);

	# gateway/version data.  these should are all initialized to ''
        #   by readSetDef, so for non-gateway/versioned sets they'll just 
        #   be stored as null
		$newSetRecord->assignment_type($assignmentType);
		$newSetRecord->attempts_per_version($attemptsPerVersion);
		$newSetRecord->time_interval($timeInterval);
		$newSetRecord->versions_per_interval($versionsPerInterval);
		$newSetRecord->version_time_limit($versionTimeLimit);
		$newSetRecord->problem_randorder($problemRandOrder);
		$newSetRecord->problems_per_page($problemsPerPage);
		$newSetRecord->hide_score($hideScore);
		$newSetRecord->hide_work($hideWork);
		$newSetRecord->time_limit_cap($timeCap);
		$newSetRecord->restrict_ip($restrictIP);
		$newSetRecord->relax_restrict_ip($relaxRestrictIP);

		#create the set
		eval {$db->addGlobalSet($newSetRecord)};
		die "addGlobalSet $setName in ProblemSetList:  $@" if $@;

		#do we need to add locations to the set_locations table?
		if ( $restrictIP ne 'No' && $restrictLoc ) {
			if ($db->existsLocation( $restrictLoc ) ) {
				if ( ! $db->existsGlobalSetLocation($setName,$restrictLoc) ) {
					my $newSetLocation = $db->newGlobalSetLocation;
					$newSetLocation->set_id( $setName );
					$newSetLocation->location_id( $restrictLoc );
					eval {$db->addGlobalSetLocation($newSetLocation)};
					warn("error adding set location $restrictLoc " .
					     "for set $setName: $@") if $@;
				} else {
					# this should never happen.
					warn("input set location $restrictLoc" .
					     " already exists for set " . 
					     "$setName.\n");
				}
			} else { 
				warn("restriction location $restrictLoc " .
				     "does not exist.  IP restrictions have " .
				     "been ignored.\n");
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
			  setName => $setName,
			  sourceFile => $rh_problem->{source_file},
			  problemID => $freeProblemID++,
			  value => $rh_problem->{value},
			  maxAttempts => $rh_problem->{max_attempts},
			  showMeAnother => $rh_problem->{showMeAnother});
		}


		if ($assign eq "all") {
			$self->assignSetToAllUsers($setName);
		}
		else {
			my $userName = $r->param('user');
			$self->assignSetToUser($userName, $newSetRecord); ## always assign set to instructor
		}
	}

	return \@added, \@skipped;
}

sub readSetDef {
	my ($self, $fileName) = @_;
	my $templateDir   = $self->{ce}->{courseDirs}->{templates};
	my $filePath      = "$templateDir/$fileName";
	my $value_default = $self->{ce}->{problemDefaults}->{value};
	my $max_attempts_default = $self->{ce}->{problemDefaults}->{max_attempts};
	my $showMeAnother = $self->{ce}->{problemDefaults}->{showMeAnother};

	my $setName = '';

	if ($fileName =~ m|^.*set([.\w-]+)\.def$|) {
		$setName = $1;
	} else {
		$self->addbadmessage( 
		    qq{The setDefinition file name must begin with   <CODE>set</CODE>},
			qq{and must end with   <CODE>.def</CODE>  . Every thing in between becomes the name of the set. },
			qq{For example <CODE>set1.def</CODE>, <CODE>setExam.def</CODE>, and <CODE>setsample7.def</CODE> },
			qq{define sets named <CODE>1</CODE>, <CODE>Exam</CODE>, and <CODE>sample7</CODE> respectively. },
			qq{The filename, $fileName, you entered is not legal\n } 
		);

	}

	my ($line, $name, $value, $attemptLimit, $continueFlag);
	my $paperHeaderFile = '';
	my $screenHeaderFile = '';
	my ($dueDate, $openDate, $answerDate);
	my @problemData;	

# added fields for gateway test/versioned set definitions:
	my ( $assignmentType, $attemptsPerVersion, $timeInterval, 
	     $versionsPerInterval, $versionTimeLimit, $problemRandOrder,
	     $problemsPerPage, $restrictLoc,
	     ) = 
		 ('')x8;  # initialize these to ''
	my ( $timeCap, $restrictIP, $relaxRestrictIP ) = ( 0, 'No', 'No');
# additional fields currently used only by gateways; later, the world?
	my ( $hideScore, $hideWork, ) = ( 'N', 'N' );

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
			} elsif ($item eq 'problemList') {
				last;
			} elsif ($item eq 'problemListV2') {
			    die $self->r->maketext("Newer problem set def files must be imported using Hmwk Sets Editor2");
			} else {
				warn "readSetDef error, can't read the line: ||$line||";
			}
		}

		#####################################################################
		# Check and format dates
		#####################################################################
		my ($time1, $time2, $time3) = map {  $self->parseDateTime($_);  }    ($openDate, $dueDate, $answerDate);
	
		unless ($time1 <= $time2 and $time2 <= $time3) {
			warn "The open date: $openDate, due date: $dueDate, and answer date: $answerDate must be defined and in chronological order.";
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
			warn("The value $hideScore for the hideScore option " .
			     "is not valid; it will be replaced with 'N'.\n");
			$hideScore = 'N';
		}
		if ( $hideWork ne 'N' && $hideWork ne 'Y' && 
		     $hideWork ne 'BeforeAnswerDate' ) {
			warn("The value $hideWork for the hideWork option " .
			     "is not valid; it will be replaced with 'N'.\n");
			$hideWork = 'N';
		}
		if ( $timeCap ne '0' && $timeCap ne '1' ) {
			warn("The value $timeCap for the capTimeLimit option " .
			     "is not valid; it will be replaced with '0'.\n");
			$timeCap = '0';
		}
		if ( $restrictIP ne 'No' && $restrictIP ne 'DenyFrom' &&
		     $restrictIP ne 'RestrictTo' ) {
			warn("The value $restrictIP for the restrictIP " .
			     "option is not valid; it will be replaced " . 
			     "with 'No'.\n");
			$restrictIP = 'No';
			$restrictLoc = '';
			$relaxRestrictIP = 'No';
		}
		if ( $relaxRestrictIP ne 'No' && 
		     $relaxRestrictIP ne 'AfterAnswerDate' &&
		     $relaxRestrictIP ne 'AfterVersionAnswerDate' ) {
			warn("The value $relaxRestrictIP for the " .
			     "relaxRestrictIP option is not valid; it will " . 
			     "be replaced with 'No'.\n");
			$relaxRestrictIP = 'No';
		}
		# to verify that restrictLoc is valid requires a database
		#    call, so we defer that until we return to add the set
		
		#####################################################################
		# Read and check list of problems for the set
		#####################################################################
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
			    ($name, $value, $attemptLimit, $showMeAnother, $continueFlag) = @line;
            } else {
			    ($name, $value, $attemptLimit, $continueFlag) = @line;
            }
			#####################
			#  clean up problem values
			###########################
			$name =~ s/\s*//g;
			$value = "" unless defined($value);
			$value =~ s/[^\d\.]*//g;
			unless ($value =~ /\d+/) {$value = $value_default;}
			$attemptLimit = "" unless defined($attemptLimit);
			$attemptLimit =~ s/[^\d-]*//g;
			unless ($attemptLimit =~ /\d+/) {$attemptLimit = $max_attempts_default;}
			$continueFlag = "0" unless( defined($continueFlag) && @problemData );  
			# can't put continuation flag onto the first problem
			push(@problemData, {source_file    => $name,
			                    value          =>  $value,
			                    max_attempts   =>, $attemptLimit,
			                    showMeAnother   =>, $showMeAnother,
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
		 $assignmentType, $attemptsPerVersion, $timeInterval, 
		 $versionsPerInterval, $versionTimeLimit, $problemRandOrder,
		 $problemsPerPage, 
		 $hideScore,
		 $hideWork,
		 $timeCap,
		 $restrictIP,
		 $restrictLoc,
		 $relaxRestrictIP,
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
			# DBFIXME use an iterator?
			my $problemRecord = $db->getGlobalProblem($set, $prob); # checked
			unless (defined $problemRecord) {
				push @skipped, $set;
				$reason{$set} = "No record found for problem $prob.";
				next SET;
			}
			my $source_file   = $problemRecord->source_file();
			my $value         = $problemRecord->value();
			my $max_attempts  = $problemRecord->max_attempts();
			my $showMeAnother  = $problemRecord->showMeAnother();
			
			# backslash-escape commas in fields
			$source_file =~ s/([,\\])/\\$1/g;
			$value =~ s/([,\\])/\\$1/g;
			$max_attempts =~ s/([,\\])/\\$1/g;
			$showMeAnother =~ s/([,\\])/\\$1/g;
			$problemList     .= "$source_file, $value, $max_attempts, $showMeAnother \n";
		}

		# gateway fields
		my $assignmentType = $setRecord->assignment_type;
		my $gwFields = '';
		if ( $assignmentType =~ /gateway/ ) {
		    my $attemptsPerV = $setRecord->attempts_per_version;
		    my $timeInterval = $setRecord->time_interval;
		    my $vPerInterval = $setRecord->versions_per_interval;
		    my $vTimeLimit   = $setRecord->version_time_limit;
		    my $probRandom   = $setRecord->problem_randorder;
		    my $probPerPage  = $setRecord->problems_per_page;
		    my $hideScore    = $setRecord->hide_score;
		    my $hideWork     = $setRecord->hide_work;
		    my $timeCap      = $setRecord->time_limit_cap;
		    $gwFields =<<EOG;

assignmentType      = $assignmentType
attemptsPerVersion  = $attemptsPerV
timeInterval        = $timeInterval
versionsPerInterval = $vPerInterval
versionTimeLimit    = $vTimeLimit
problemRandOrder    = $probRandom
problemsPerPage     = $probPerPage
hideScore           = $hideScore
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

openDate          = $openDate
dueDate           = $dueDate
answerDate        = $answerDate
paperHeaderFile   = $paperHeader
screenHeaderFile  = $setHeader$gwFields
${restrictFields}problemList       = 
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
	
	    my %attr = ( name => $fieldName,
			 label => "",
			 value => 1
		);
	    
	    $attr{'checked'} = 1 if ($value);
	    
	    
	    
	    
	    
	    # FIXME: kludge (R)
	    # if the checkbox is checked it returns a 1, if it is unchecked it returns nothing
	    # in which case the hidden field overrides the parameter with a 0
	    return CGI::checkbox( \%attr ) . CGI::hidden(
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

	my $visibleClass = $Set->visible ? "font-visible" : "font-hidden";
	my $enable_reduced_scoringClass = $Set->enable_reduced_scoring ? $r->maketext('Reduced Scoring Enabled') : $r->maketext('Reduced Scoring Disabled');

	my $users = $db->countSetUsers($Set->set_id);
	my $totalUsers = $self->{totalUsers};
	# DBFIXME count would suffice
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
#	$fakeRecord{set_id} = CGI::font({class=>$visibleClass}, $set_id) . ($editMode ? "" : $imageLink);
	$fakeRecord{set_id} = $editMode 
					? CGI::a({href=>$problemListURL}, "$set_id") 
					: CGI::font({class=>$visibleClass}, $set_id) . $imageLink;
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
	if ($editMode) {
		push @tableCells, CGI::a({href=>$problemListURL}, "$set_id");
	} else {		
	push @tableCells, CGI::font({class=>$visibleClass}, $set_id . $imageLink);
	}

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
	    @fieldsToShow = grep {$_ ne 'enable_reduced_scoring'} @fieldsToShow;
	}

	# make a hash out of this so we can test membership easily
	my %nonkeyfields; @nonkeyfields{$Set->NONKEYFIELDS} = ();
	
	# Set Fields
	foreach my $field (@fieldsToShow) {
		next unless exists $nonkeyfields{$field};
		my $fieldName = "set." . $set_id . "." . $field,		
		my $fieldValue = $Set->$field;
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = "readonly" unless $editMode;
		$fieldValue = $self->formatDateTime($fieldValue) if $field =~ /_date/;
		$fieldValue =~ s/ /&nbsp;/g unless $editMode;
		$fieldValue = ($fieldValue) ? $r->maketext("Yes") : $r->maketext("No") if $field =~ /visible/ and not $editMode;
		$fieldValue = ($fieldValue) ? $r->maketext("Yes") : $r->maketext("No") if $field =~ /enable_reduced_scoring/ and not $editMode;
		push @tableCells, CGI::font({class=>$visibleClass}, $self->fieldEditHTML($fieldName, $fieldValue, \%properties));
		#$fakeRecord{$field} = CGI::font({class=>$visibleClass}, $self->fieldEditHTML($fieldName, $fieldValue, \%properties));
	}

	#@tableCells = map { $fakeRecord{$_} } @fieldsToShow;

	return CGI::Tr({}, CGI::td({}, \@tableCells));
}

sub printTableHTML {
	my ($self, $SetsRef, $fieldNamesRef, %options) = @_;
	my $r                       = $self->r;
	my $ce = $r->ce;
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

	
	# Remove the enable reduced scoring box if that feature isnt enabled
	if (!$ce->{pg}{ansEvalDefaults}{enableReducedScoring}) {
	    @realFieldNames = grep {$_ ne 'enable_reduced_scoring'} @realFieldNames;
	}
	
	my %sortSubs = %{ SORT_SUBS() };

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
	$headers{""} = "Use System Default";
	$self->{headerFiles} = \%headers;	# store these header files so we don't have to look for them later.


	my @tableHeadings = map { $fieldNames{$_} } @realFieldNames;
	
	# prepend selection checkbox? only if we're NOT editing!
#	unshift @tableHeadings, "Select", "Set", "Problems" unless $editMode;

	# print the table
	if ($editMode or $exportMode) {
		print CGI::start_table({id=>"set_table_id", class=>"set_table"});
	} else {
		print CGI::start_table({-class=>"set_table", id=>"set_table_id"});
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
