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

package WeBWorK::ContentGenerator::Instructor::ProblemSetList3;
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetList3 - Entry point for Set-specific
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

This current version (as of Fall 2012) is a total rewrite of the Problem Set Editor (Homework Set Editor) to bring
the interface and usability up to date.  
	
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
#use constant DEFAULT_VISIBILITY_STATE => 1;
#use constant DEFAULT_ENABLED_REDUCED_SCORING_STATE => 0;
#use constant ONE_WEEK => 60*60*24*7;  

#use constant EDIT_FORMS => [qw(cancelEdit saveEdit)];
#use constant VIEW_FORMS => [qw(filter sort edit publish import export score create delete)];
#use constant EXPORT_FORMS => [qw(cancelExport saveExport)];

#use constant VIEW_FIELD_ORDER => [ qw( select set_id problems users visible enable_reduced_scoring open_date due_date answer_date) ];
#use constant EDIT_FIELD_ORDER => [ qw( set_id visible enable_reduced_scoring open_date due_date answer_date) ];
#use constant EXPORT_FIELD_ORDER => [ qw( select set_id filename) ];

# permissions needed to perform a given action
#use constant FORM_PERMS => {
#		saveEdit => "modify_problem_sets",
#		edit => "modify_problem_sets",
#		publish => "modify_problem_sets",
#		import => "create_and_delete_problem_sets",
#		export => "modify_set_def_files",
#		saveExport => "modify_set_def_files",
#		score => "score_sets",
#		create => "create_and_delete_problem_sets",
#		delete => "create_and_delete_problem_sets",
#};

# permissions needed to view a given field
#use constant FIELD_PERMS => {
#		problems => "modify_problem_sets",
#		users	=> "assign_problem_sets",
#};

#use constant STATE_PARAMS => [qw(user effectiveUser key visible_sets no_visible_sets prev_visible_sets no_prev_visible_set editMode exportMode primarySortField secondarySortField)];

#use constant SORT_SUBS => {
#	set_id		=> \&bySetID,
#	set_header	=> \&bySetHeader,  # can't figure out why these are useful
#	hardcopy_header	=> \&byHardcopyHeader,  # can't figure out why these are useful
#	open_date	=> \&byOpenDate,
#	due_date	=> \&byDueDate,
#	answer_date	=> \&byAnswerDate,
#	visible	=> \&byVisible,

#};

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

# template method
sub templateName {
	return "lbtwo";
}

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
			return $r->maketext("No sets selected for scoring".".");
		} elsif ($scope eq "all") {
			@setsToScore = @{ $r->param("allSetIDs") };
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
	
	return CGI::div({class => "ResultsWithError"}, $r->maketext("You are not authorized to access the instructor tools."))
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
	
	return CGI::div({class=>"ResultsWithError"}, CGI::p($r->maketext("You are not authorized to modify homework sets.")))
		if $self->{editMode} and not $authz->hasPermissions($user, "modify_problem_sets");
	
	$self->{exportMode} = $r->param("exportMode") || 0;

	return CGI::div({class=>"ResultsWithError"}, CGI::p($r->maketext("You are not authorized to modify set definition files.")))
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
			$self->addmessage(CGI::div($r->maketext("Results of last action performed").": "));
			$self->addmessage($self->$actionHandler(\%genericParams, \%actionParams, \%tableParams));
		} else {
			return CGI::div({class=>"ResultsWithError"}, CGI::p($r->maketext("You are not authorized to perform this action.")));
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
	
	return CGI::div({class => "ResultsWithError"}, $r->maketext("You are not authorized to access the instructor tools."))
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	
	my $template = HTML::Template->new(filename => $WeBWorK::Constants::WEBWORK_DIRECTORY . '/htdocs/html-templates/homework-manager.html');  
	print $template->output();
	
	print $self->hidden_authen_fields;
	print CGI::hidden({id=>'hidden_courseID',name=>'courseID',default=>$courseName });



	return "";
}

sub head{
	my $self = shift;
	my $r = $self->r;
    	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};
    	print "<link rel='stylesheet' href='$site_url/js/vendor/jquery/jquery-ui-1.10.0.custom/css/ui-lightness/jquery-ui-1.10.0.custom.min.css' type='text/css' media='screen'>";
        print "<link rel='stylesheet' type='text/css' href='$site_url/css/problemsetlist.css' > </style>";
	return "";
}

# output_JS subroutine

# prints out the necessary JS for this page

sub output_JS{
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};
	print qq!<script type="text/javascript" src="$site_url/mathjax/MathJax.js?config=TeX-AMS-MML_HTMLorMML"></script>!;
	print qq!<script data-main="$site_url/js/apps/HomeworkManager/HomeworkManager" src="$site_url/js/vendor/requirejs/require.js"></script>!;


	
	return "";
}

1;
=head1 AUTHOR

Written by Peter Staab at (pstaab  at  fitchburgstate.edu)

=cut
