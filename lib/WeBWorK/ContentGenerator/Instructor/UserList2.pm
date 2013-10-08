################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/UserList2.pm,v 1.96 2010/05/14 00:52:48 gage Exp $
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

package WeBWorK::ContentGenerator::Instructor::UserList2;
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator);
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UserList2 - Entry point for User-specific
data editing (ghe3 version)

=cut

=for comment

What do we want to be able to do here?

Filter what users are shown:
	- none, all, selected
	- matching user_id, matching section, matching recitation
Switch from view mode to edit mode:
	- showing visible users
	- showing selected users
Switch from edit mode to view and save changes
Switch from edit mode to view and abandon changes
Switch from view mode to password mode:
	- showing visible users
	- showing selected users
Switch from password mode to view and save changes
Switch from password mode to view and abandon changes
Delete users:
	- visible
	- selected
Import users:
	- replace:
		- any users
		- visible users
		- selected users
		- no users
	- add:
		- any users
		- no users
Export users:
	- export:
		- all
		- visible
		- selected
	- to:
		- existing file on server (overwrite): [ list of files ]
		- new file on server (create): [ filename ]

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::File::Classlist;
use WeBWorK::DB qw(check_user_id);
use WeBWorK::Utils qw(readFile readDirectory cryptPassword);
use constant HIDE_USERS_THRESHHOLD => 200;
use constant EDIT_FORMS => [qw(saveEdit cancelEdit)];
use constant PASSWORD_FORMS => [qw(savePassword cancelPassword)];
use constant VIEW_FORMS => [qw(filter sort edit password import export add delete)];

# permissions needed to perform a given action
use constant FORM_PERMS => {
		saveEdit => "modify_student_data",
		edit => "modify_student_data",
		savePassword => "change_password",
		password => "change_password",
		import => "modify_student_data",
		export => "modify_classlist_files",
		add => "modify_student_data",
		delete => "modify_student_data",
};

# permissions needed to view a given field
use constant FIELD_PERMS => {
		act_as => "become_student",
		sets	=> "assign_problem_sets",
};

use constant STATE_PARAMS => [qw(user effectiveUser key visible_users no_visible_users prev_visible_users no_prev_visible_users editMode passwordMode primarySortField secondarySortField ternarySortField labelSortMethod)];

use constant SORT_SUBS => {
	user_id       => \&byUserID,
	first_name    => \&byFirstName,
	last_name     => \&byLastName,
	email_address => \&byEmailAddress,
	student_id    => \&byStudentID,
	status        => \&byStatus,
	section       => \&bySection,
	recitation    => \&byRecitation,
	comment       => \&byComment,
	permission    => \&byPermission,
};

use constant  FIELD_PROPERTIES => {
	user_id => {
		type => "text",
		size => 8,
		access => "readonly",
	},
	first_name => {
		type => "text",
		size => 10,
		access => "readwrite",
	},
	last_name => {
		type => "text",
		size => 10,
		access => "readwrite",
	},
	email_address => {
		type => "text",
		size => 20,
		access => "readwrite",
	},
	student_id => {
		type => "text",
		size => 11,
		access => "readwrite",
	},
	status => {
		#type => "enumerable",
		type => "status",
		size => 4,
		access => "readwrite",
		#items => {
		#	"C" => "Enrolled",
		#	"D" => "Drop",
		#	"A" => "Audit",
		#},
		#synonyms => {
		#	qr/^[ce]/i => "C",
		#	qr/^[dw]/i => "D",
		#	qr/^a/i => "A",
		#	"*" => "C",
		#}
	},
	section => {
		type => "text",
		size => 3,
		access => "readwrite",
	},
	recitation => {
		type => "text",
		size => 3,
		access => "readwrite",
	},
	comment => {
		type => "text",
		size => 20,
		access => "readwrite",
	},
	permission => {
# this really should be read from $r->ce, but that's not available here
		type => "permission",
		access => "readwrite",
		size => 4,
#		type => "number",
#		size => 2,
#		access => "readwrite",
	}
};
sub pre_header_initialize {
	my $self          = shift;
	my $r             = $self->r;
	my $urlpath       = $r->urlpath;
	my $authz         = $r->authz;
	my $ce            = $r->ce;
	my $courseName    = $urlpath->arg("courseID");
	my $user          = $r->param('user');
	# Handle redirects, if any.
	##############################
	# Redirect to the addUser page
	##################################

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	
	defined($r->param('action')) && $r->param('action') eq 'add' && do {
		# fix url and redirect
		my $root              = $ce->{webworkURLs}->{root};
		
		my $numberOfStudents  = $r->param('number_of_students');
		warn $r->maketext("number of students not defined") unless defined $numberOfStudents;

		my $uri=$self->systemLink( $urlpath->newFromModule('WeBWorK::ContentGenerator::Instructor::AddUsers', $r, courseID=>$courseName),
		                           params=>{
		                          			number_of_students=>$numberOfStudents,
		                                   }
		);
		#FIXME  does the display mode need to be defined?
		#FIXME  url_authen_args also includes an effective user, so the new one must come first.
		# even that might not work with every browser since there are two effective User assignments.
		$self->reply_with_redirect($uri);
		return;
	};
}

sub initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $ce     = $r->ce;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	
	#if (defined($r->param('addStudent'))) {
	#	my $newUser = $db->newUser;
	#	my $newPermissionLevel = $db->newPermissionLevel;
	#	my $newPassword = $db->newPassword;
	#	$newUser->user_id($r->param('newUserID'));
	#	$newPermissionLevel->user_id($r->param('newUserID'));
	#	$newPassword->user_id($r->param('newUserID'));
	#	$newUser->status('C');
	#	$newPermissionLevel->permission(0);
	#	$db->addUser($newUser);
	#	$db->addPermissionLevel($newPermissionLevel);
	#	$db->addPassword($newPassword);
	#}
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
	my $userTemplate            = $self->{userTemplate}            = $db->newUser;
	my $permissionLevelTemplate = $self->{permissionLevelTemplate} = $db->newPermissionLevel;
	
	return CGI::div({class=>"ResultsWithError"}, CGI::p($r->maketext("You are not authorized to access the instructor tools.")))
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	# This table can be consulted when display-ready forms of field names are needed.
	my %prettyFieldNames = map { $_ => $_ } 
		$userTemplate->FIELDS(),
		$permissionLevelTemplate->FIELDS();
	
	@prettyFieldNames{qw(
		user_id 
		first_name 
		last_name 
		email_address 
		student_id 
		status 
		section 
		recitation 
		comment 
		permission
	)} = (
		$r->maketext("Login Name"), 
		$r->maketext("First Name"), 
		$r->maketext("Last Name"), 
		$r->maketext("Email Address"), 
		$r->maketext("Student ID"), 
		$r->maketext("Status"), 
		$r->maketext("Section"), 
		$r->maketext("Recitation"), 
		$r->maketext("Comment"), 
		$r->maketext("Permission Level")
	);
	
	$self->{prettyFieldNames} = \%prettyFieldNames;
	########## set initial values for state fields
	
	# exclude set-level proctors
	my @allUserIDs = grep {$_ !~ /^set_id:/} $db->listUsers;
	# DBFIXME count would work
	$self->{totalSets} = $db->listGlobalSets; # save for use in "assigned sets" links
	$self->{allUserIDs} = \@allUserIDs;
	
	# DBFIXME filter in the database
	if (defined $r->param("visable_user_string")) {
		my @visableUserIDs = split /:/, $r->param("visable_user_string");
		$self->{visibleUserIDs} = [ @visableUserIDs ];
	} elsif (defined $r->param("visible_users")) {
		$self->{visibleUserIDs} = [ $r->param("visible_users") ];
	} elsif (defined $r->param("no_visible_users")) {
		$self->{visibleUserIDs} = [];
	} else {
		if ((@allUserIDs > HIDE_USERS_THRESHHOLD) and (not defined $r->param("show_all_users") )) {
			$self->{visibleUserIDs} = [];
		} else {
			$self->{visibleUserIDs} = [ @allUserIDs ];
		}
	}
	
	$self->{prevVisibleUserIDs} = $self->{visibleUserIDs};
	
	if (defined $r->param("selected_users")) {
		$self->{selectedUserIDs} = [ $r->param("selected_users") ];
	} else {
		$self->{selectedUserIDs} = [];
	}
	
	$self->{editMode} = $r->param("editMode") || 0;

	return CGI::div({class=>"ResultsWithError"}, CGI::p($r->maketext("You are not authorized to modify student data")))
		if $self->{editMode} and not $authz->hasPermissions($user, "modify_student_data");


	$self->{passwordMode} = $r->param("passwordMode") || 0;

	return CGI::div({class=>"ResultsWithError"}, CGI::p($r->maketext("You are not authorized to modify student data")))
		if $self->{passwordMode} and not $authz->hasPermissions($user, "modify_student_data");

	if (defined $r->param("labelSortMethod")) {
		$self->{primarySortField} = $r->param("labelSortMethod");
		$self->{secondarySortField} = $r->param("primarySortField");
		$self->{ternarySortField} = $r->param("secondarySortField");
	}
	else {			
		$self->{primarySortField} = $r->param("primarySortField") || "last_name";
		$self->{secondarySortField} = $r->param("secondarySortField") || "first_name";
		$self->{ternarySortField} = $r->param("ternarySortField") || "student_id";
	}
	
	# DBFIXME use an iterator
	my @allUsers = $db->getUsers(@allUserIDs);
	my (%sections, %recitations);
	foreach my $User (@allUsers) {
		push @{$sections{defined $User->section ? $User->section : ""}}, $User->user_id;
		push @{$recitations{defined $User->recitation ? $User->recitation : ""}}, $User->user_id;
	}
	$self->{sections} = \%sections;
	$self->{recitations} = \%recitations;
	
	########## call action handler
	
	my $actionID = $r->param("action");
	if ($actionID) {
		unless (grep { $_ eq $actionID } @{ VIEW_FORMS() }, @{ EDIT_FORMS() }, @{ PASSWORD_FORMS() } ) {
			die $r->maketext("Action [_1] not found", $actionID);
		}
		# Check permissions
		if (not FORM_PERMS()->{$actionID} or $authz->hasPermissions($user, FORM_PERMS()->{$actionID})) {
			my $actionHandler = "${actionID}_handler";
			my %genericParams;
			foreach my $param (qw(selected_users)) {
				$genericParams{$param} = [ $r->param($param) ];
			}
			my %actionParams = $self->getActionParams($actionID);
			my %tableParams = $self->getTableParams();
			print CGI::p(
			    CGI::div({-style=>"color:green"}, $r->maketext("Result of last action performed: [_1]", CGI::i($self->$actionHandler(\%genericParams, \%actionParams, \%tableParams)))),
				CGI::hr()
			);
		} else {
			return CGI::div({class=>"ResultsWithError"}, CGI::p($r->maketext("You are not authorized to perform this action.")));
		}
	}
		
	########## retrieve possibly changed values for member fields
	
	#@allUserIDs = @{ $self->{allUserIDs} }; # do we need this one?
	# DBFIXME instead of re-listing, why not add added users to $self->{allUserIDs} ?
	# exclude set-level proctors
	@allUserIDs = grep {$_ !~ /^set_id:/} $db->listUsers; # recompute value in case some were added
	my @visibleUserIDs = @{ $self->{visibleUserIDs} };
	my @prevVisibleUserIDs = @{ $self->{prevVisibleUserIDs} };
	my @selectedUserIDs = @{ $self->{selectedUserIDs} };
	my $editMode = $self->{editMode};
	my $passwordMode = $self->{passwordMode};	
	my $primarySortField = $self->{primarySortField};
	my $secondarySortField = $self->{secondarySortField};
	my $ternarySortField = $self->{ternarySortField};
	
	#warn "visibleUserIDs=@visibleUserIDs\n";
	#warn "prevVisibleUserIDs=@prevVisibleUserIDs\n";
	#warn "selectedUserIDs=@selectedUserIDs\n";
	#warn "editMode=$editMode\n";
	#warn "passwordMode=$passwordMode\n";
	#warn "primarySortField=$primarySortField\n";
	#warn "secondarySortField=$secondarySortField\n";
	#warn "ternarySortField=$ternarySortField\n";

	########## get required users
		
	my @Users = grep { defined $_ } @visibleUserIDs ? $db->getUsers(@visibleUserIDs) : ();

	my %sortSubs = %{ SORT_SUBS() };
	my $primarySortSub = $sortSubs{$primarySortField};
	my $secondarySortSub = $sortSubs{$secondarySortField};
	my $ternarySortSub = $sortSubs{$ternarySortField};
	
	# add permission level to user record hash so we can sort it if necessary
	# DBFIXME this calls for a join... (i'd like the User record to contain permission level info)
	if ($primarySortField eq 'permission' or $secondarySortField eq 'permission' or $ternarySortField eq 'permission') {
		foreach my $User (@Users) {
			next unless $User;
			my $permissionLevel = $db->getPermissionLevel($User->user_id);
        	                $User->{permission} = $permissionLevel->permission;
		}
	}
		
	
#	# don't forget to sort in opposite order of importance
#	@Users = sort $secondarySortSub @Users;
#	@Users = sort $primarySortSub @Users;
#	#@Users = sort byLnFnUid @Users;

#   Always have a definite sort order even if first three sorts don't determine things
	@Users = sort {
		&$primarySortSub
			||
		&$secondarySortSub 
			||
		&$ternarySortSub
			||
		byLastName
			||
		byFirstName
			||
		byUserID
		} 
		@Users;
		
	my @PermissionLevels;
	
	for (my $i = 0; $i < @Users; $i++) {
		my $User = $Users[$i];
		# DBFIX we maybe already have the permission level from above (for use in sorting)
		my $PermissionLevel = $db->getPermissionLevel($User->user_id); # checked
		
		# DBFIXME this should go in the DB layer
		unless ($PermissionLevel) {
			# uh oh! no permission level record found!
			warn $r->maketext("added missing permission level for user"), $User->user_id, "\n";
			
			# create a new permission level record
			$PermissionLevel = $db->newPermissionLevel;
			$PermissionLevel->user_id($User->user_id);
			$PermissionLevel->permission(0);
			
			# add it to the database
			$db->addPermissionLevel($PermissionLevel);
		}
		
		$PermissionLevels[$i] = $PermissionLevel;
	}
	
	########## print site identifying information
	
	print WeBWorK::CGI_labeled_input(-type=>"button", -id=>"show_hide", -input_attr=>{-value=>$r->maketext("Show/Hide Site Description"), -class=>"button_input"});
	print CGI::p({-id=>"site_description", -style=>"display:none"}, CGI::em($r->maketext("_CLASSLIST_EDITOR_DESCRIPTION")));
	
	########## print beginning of form
	
	print CGI::start_form({method=>"post", action=>$self->systemLink($urlpath,authen=>0), name=>"userlist", id=>"classlist-form", class=>"edit_form"});
	print $self->hidden_authen_fields();
	
	########## print state data
	
	print "\n<!-- state data here -->\n";
	
	if (@visibleUserIDs) {
		print CGI::hidden(-name=>"visible_users", -value=>\@visibleUserIDs);
	} else {
		print CGI::hidden(-name=>"no_visible_users", -value=>"1");
	}
	
	if (@prevVisibleUserIDs) {
		print CGI::hidden(-name=>"prev_visible_users", -value=>\@prevVisibleUserIDs);
	} else {
		print CGI::hidden(-name=>"no_prev_visible_users", -value=>"1");
	}
	
	print CGI::hidden(-name=>"editMode", -value=>$editMode);
	
	print CGI::hidden(-name=>"passwordMode", -value=>$passwordMode);
	
	print CGI::hidden(-name=>"primarySortField", -value=>$primarySortField);
	print CGI::hidden(-name=>"secondarySortField", -value=>$secondarySortField);
	print CGI::hidden(-name=>"ternarySortField", -value=>$ternarySortField);
	
	print "\n<!-- state data here -->\n";
	
	########## print action forms
	
	# print CGI::start_table({});
	print CGI::p($r->maketext("Select an action to perform").":");
	
	my @formsToShow;
	if ($editMode) {
		@formsToShow = @{ EDIT_FORMS() };
	}elsif ($passwordMode) {
		@formsToShow = @{ PASSWORD_FORMS() };	
	} else {
		@formsToShow = @{ VIEW_FORMS() };
	}
	
	print CGI::start_div({-class=>"tabber"});

	my $i = 0;
	foreach my $actionID (@formsToShow) {

	    # Check permissions
	    next if FORM_PERMS()->{$actionID} and not $authz->hasPermissions($user, FORM_PERMS()->{$actionID});
	    my $actionForm = "${actionID}_form";
	    my $onChange = "document.userlist.action[$i].checked=true";
	    my %actionParams = $self->getActionParams($actionID);
	    
	    print CGI::div({-class=>"tabbertab"},
			   CGI::h3($r->maketext(ucfirst(WeBWorK::split_cap($actionID)))),
			   CGI::span({-class=>"radio_span"},  WeBWorK::CGI_labeled_input(-type=>"radio", 
			   -id=>$actionID."_id", -label_text=>$r->maketext(ucfirst(WeBWorK::split_cap($actionID))), 
                           -input_attr=>{-name=>"action", -value=>$actionID}, -label_attr=>{-class=>"radio_label"})),
			    $self->$actionForm($onChange, %actionParams));
		
		$i++;
	}


	print CGI::end_div();

	print CGI::start_div();

	my $selectAll =WeBWorK::CGI_labeled_input(-type=>'button', -id=>"select_all", -input_attr=>{-name=>'check_all', -class=>"button_input", -value=>$r->maketext('Select all users'),
	       onClick => "for (i in document.userlist.elements)  { 
	                       if (document.userlist.elements[i].name =='selected_users') { 
	                           document.userlist.elements[i].checked = true
	                       }
	                    }" });
   	my $selectNone =WeBWorK::CGI_labeled_input(-type=>'button', -id=>"select_none", -input_attr=>{-name=>'check_none', -class=>"button_input", -value=>$r->maketext('Unselect all users'),
	       onClick => "for (i in document.userlist.elements)  { 
	                       if (document.userlist.elements[i].name =='selected_users') { 
	                          document.userlist.elements[i].checked = false
	                       }
	                    }" });
	unless ($editMode or $passwordMode) {
		print $selectAll." ". $selectNone;
	}

	print WeBWorK::CGI_labeled_input(-type=>"reset", -id=>"clear_entries", -input_attr=>{-value=>$r->maketext("Clear"), -class=>"button_input"});
	print WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"take_action", -input_attr=>{-value=>$r->maketext("Take Action!"), -class=>"button_input"}).CGI::br().CGI::br();
	print CGI::end_div();
	# print CGI::end_table();
	
	########## print table
	
	print CGI::p({},$r->maketext("Showing [_1] out of [_2] users", scalar @Users, scalar @allUserIDs));
	
	print CGI::p($r->maketext("If a password field is left blank, the student's current password will be maintained.")) if $passwordMode;
	if ($editMode) {
	   

		print CGI::p($r->maketext('Click on the login name to edit individual problem set data, (e.g. due dates) for these students.'));
	}
	$self->printTableHTML(\@Users, \@PermissionLevels, \%prettyFieldNames,
		editMode => $editMode,
		passwordMode => $passwordMode,
		selectedUserIDs => \@selectedUserIDs,
		primarySortField => $primarySortField,
		secondarySortField => $secondarySortField,
		visableUserIDs => \@visibleUserIDs,
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
		next unless $param =~ m/^(?:user|permission)\./;
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
	my $r = $self->r;
	
	my %prettyFieldNames = %{ $self->{prettyFieldNames} };
	
	return join("",
			WeBWorK::CGI_labeled_input(
				-type=>"select",
				-id=>"filter_select",
				-label_text=>$r->maketext("Show Which Users?").": ",
				-input_attr=>{
					-name => "action.filter.scope",
					-values => [qw(all none selected match_regex)],
					-default => $actionParams{"action.filter.scope"}->[0] || "match_regex",
					-labels => {
						all => $r->maketext("all users"),
						none => $r->maketext("no users"),
						selected => $r->maketext("selected users"),
						match_regex => $r->maketext("users who match on selected field"),
					},
					-onchange => $onChange,
				}
			),
			CGI::br(),
			" ",
			CGI::div({-id=>"filter_elements"},
			WeBWorK::CGI_labeled_input(
				-type=>"select",
				-id=>"filter_type_select",
				-label_text=>$r->maketext("What field should filtered users match on?").": ",
				-input_attr=>{
					-name => "action.filter.field",
					-value => [ keys %{ FIELD_PROPERTIES() } ],
					-default => $actionParams{"action.filter.field"}->[0] || "user_id",
					-labels => \%prettyFieldNames,
					-onchange => $onChange
				}
			),
			CGI::br(),
			WeBWorK::CGI_labeled_input(
				-type=>"text",
				-id=>"filter_text",
				-label_text=>$r->maketext("Filter by what text?").": ",
				-input_attr=>{
					-name => "action.filter.user_ids",
					-value => $actionParams{"action.filter.user_ids"}->[0] || "",,
					-width => "50",
					-onchange => $onChange,
				}
			),
			CGI::br(),
			),
	);
}

# this action handler modifies the "visibleUserIDs" field based on the contents
# of the "action.filter.scope" parameter and the "selected_users" 
# DBFIXME filtering should happen in the database!
sub filter_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	
	my $r = $self->r;
	my $db = $r->db;
	
	my $result;
	
	my $scope = $actionParams->{"action.filter.scope"}->[0];
	if ($scope eq "all") {
		$result = $r->maketext("showing all users");
		$self->{visibleUserIDs} = $self->{allUserIDs};
	} elsif ($scope eq "none") {
		$result = $r->maketext("showing no users");
		$self->{visibleUserIDs} = [];
	} elsif ($scope eq "selected") {
		$result = $r->maketext("showing selected users");
		$self->{visibleUserIDs} = $genericParams->{selected_users}; # an arrayref
	} elsif ($scope eq "match_regex") {
		$result = $r->maketext("showing matching users");
		my $regex = $actionParams->{"action.filter.user_ids"}->[0];
		my $field = $actionParams->{"action.filter.field"}->[0];
		my @userRecords = $db->getUsers(@{$self->{allUserIDs}});
		my @userIDs;
		foreach my $record (@userRecords) {
			next unless $record;

			# add permission level to user record hash so we can match it if necessary
			if ($field eq "permission") {
				my $permissionLevel = $db->getPermissionLevel($record->user_id);
        	                $record->{permission} = $permissionLevel->permission;
			}
			push @userIDs, $record->user_id if $record->{$field} =~ /^$regex/i;
		}
		$self->{visibleUserIDs} = \@userIDs;
	} elsif ($scope eq "match_ids") {
		my @userIDs = split /\s*,\s*/, $actionParams->{"action.filter.user_ids"}->[0];
		$self->{visibleUserIDs} = \@userIDs;
	} elsif ($scope eq "match_section") {
		my $section = $actionParams->{"action.filter.section"}->[0];
		$self->{visibleUserIDs} = $self->{sections}->{$section}; # an arrayref
	} elsif ($scope eq "match_recitation") {
		my $recitation = $actionParams->{"action.filter.recitation"}->[0];
		$self->{visibleUserIDs} = $self->{recitations}->{$recitation}; # an arrayref
	}
	
	return $result;
}

sub sort_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	
	return join ("",
		WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>"sort_select_1",
			-label_text=>$r->maketext("Sort by").": ",
			-input_attr=>{
				-name => "action.sort.primary",
				-values => [qw(user_id first_name last_name email_address student_id status section recitation comment permission)],
				-default => $actionParams{"action.sort.primary"}->[0] || "last_name",
				-labels => {
					user_id		=> $r->maketext("Login Name"),
					first_name	=> $r->maketext("First Name"),
					last_name	=> $r->maketext("Last Name"),
					email_address	=> $r->maketext("Email Address"),
					student_id	=> $r->maketext("Student ID"),
					status		=> $r->maketext("Enrollment Status"),
					section		=> $r->maketext("Section"),
					recitation	=> $r->maketext("Recitation"),
					comment		=> $r->maketext("Comment"),
					permission	=> $r->maketext("Permission Level")
				},
				-onchange => $onChange,
			},
		),
		CGI::br(),
		WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>"sort_select_2",
			-label_text=>$r->maketext("Then by").": ",
			-input_attr=>{
				-name => "action.sort.secondary",
				-values => [qw(user_id first_name last_name email_address student_id status section recitation comment permission)],
				-default => $actionParams{"action.sort.secondary"}->[0] || "first_name",
				-labels => {
					user_id		=> $r->maketext("Login Name"),
					first_name	=> $r->maketext("First Name"),
					last_name	=> $r->maketext("Last Name"),
					email_address	=> $r->maketext("Email Address"),
					student_id	=> $r->maketext("Student ID"),
					status		=> $r->maketext("Enrollment Status"),
					section		=> $r->maketext("Section"),
					recitation	=> $r->maketext("Recitation"),
					comment		=> $r->maketext("Comment"),
					permission	=> $r->maketext("Permission Level")
				},
				-onchange => $onChange,
			},
		),
		CGI::br(),
		WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>"sort_select_3",
			-label_text=>$r->maketext("Then by").": ",
			-input_attr=>{
				-name => "action.sort.ternary",
				-values => [qw(user_id first_name last_name email_address student_id status section recitation comment permission)],
				-default => $actionParams{"action.sort.ternary"}->[0] || "user_id",
				-labels => {
					user_id		=> $r->maketext("Login Name"),
					first_name	=> $r->maketext("First Name"),
					last_name	=> $r->maketext("Last Name"),
					email_address	=> $r->maketext("Email Address"),
					student_id	=> $r->maketext("Student ID"),
					status		=> $r->maketext("Enrollment Status"),
					section		=> $r->maketext("Section"),
					recitation	=> $r->maketext("Recitation"),
					comment		=> $r->maketext("Comment"),
					permission	=> $r->maketext("Permission Level")
				},
				-onchange => $onChange,
			},
		),
	);
}

sub sort_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;
	
	my $primary = $actionParams->{"action.sort.primary"}->[0];
	my $secondary = $actionParams->{"action.sort.secondary"}->[0];
	my $ternary = $actionParams->{"action.sort.ternary"}->[0];
	
	$self->{primarySortField} = $primary;
	$self->{secondarySortField} = $secondary;
	$self->{ternarySortField} = $ternary;

	my %names = (
				user_id		=> $r->maketext("Login Name"),
				first_name	=> $r->maketext("First Name"),
				last_name	=> $r->maketext("Last Name"),
				email_address	=> $r->maketext("Email Address"),
				student_id	=> $r->maketext("Student ID"),
				status		=> $r->maketext("Enrollment Status"),
				section		=> $r->maketext("Section"),
				recitation	=> $r->maketext("Recitation"),
				comment		=> $r->maketext("Comment"),
				permission	=> $r->maketext("Permission Level")
	);
	
	return $r->maketext("Users sorted by [_1], then by [_2], then by [_3]", $names{$primary}, $names{$secondary}, $names{$ternary});
}

sub edit_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;

	return join("",
		WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>"edit_select",
			-label_text=>$r->maketext("Edit Which Users?").": ",
			-input_attr=>{
				-name => "action.edit.scope",
				-values => [qw(all visible selected)],
				-default => $actionParams{"action.edit.scope"}->[0] || "selected",
				-labels => {
					all => $r->maketext("all users"),
					visible => $r->maketext("visible users"),
					selected => $r->maketext("selected users")
				},
				-onchange => $onChange,
			}
		),
	);
}

sub edit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;

	my $result;
	
	my $scope = $actionParams->{"action.edit.scope"}->[0];
	if ($scope eq "all") {
		$result = $r->maketext("editing all users");
		$self->{visibleUserIDs} = $self->{allUserIDs};
	} elsif ($scope eq "visible") {
		$result = $r->maketext("editing visible users");
		# leave visibleUserIDs alone
	} elsif ($scope eq "selected") {
		$result = $r->maketext("editing selected users");
		$self->{visibleUserIDs} = $genericParams->{selected_users}; # an arrayref
	}
	$self->{editMode} = 1;
	
	return $result;
}


sub password_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;

	return join("",
		WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>"password_select",
			-label_text=>$r->maketext("Give new password to which users?").": ",
			-input_attr=>{
				-name => "action.password.scope",
				-values => [qw(all visible selected)],
				-default => $actionParams{"action.password.scope"}->[0] || "selected",
				-labels => {
					all => $r->maketext("all users"),
					visible => $r->maketext("visible users"),
					selected => $r->maketext("selected users")
				},
				-onchange => $onChange,
			},
		),
	);
}

sub password_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;

	my $result;
	
	my $scope = $actionParams->{"action.password.scope"}->[0];
	if ($scope eq "all") {
		$result = $r->maketext("giving new passwords to all users");
		$self->{visibleUserIDs} = $self->{allUserIDs};
	} elsif ($scope eq "visible") {
		$result = $r->maketext("giving new passwords to visible users");
		# leave visibleUserIDs alone
	} elsif ($scope eq "selected") {
		$result = $r->maketext("giving new passwords to selected users");
		$self->{visibleUserIDs} = $genericParams->{selected_users}; # an arrayref
	}
	$self->{passwordMode} = 1;
	
	return $result;
}

sub delete_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;

	return join("",
		CGI::span({-class=>"ResultsWithError"}, CGI::em($r->maketext("Warning: Deletion destroys all user-related data and is not undoable!"))),CGI::br(),
		WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>"delete_select",
			-label_text=>$r->maketext("Delete how many?").": ",
			-input_attr=>{
				-name => "action.delete.scope",
				-values => [qw(none selected)],
				-default => $actionParams{"action.delete.scope"}->[0] || "none",
				-labels => {
					none     => $r->maketext("no users"),
					# visible  => "visible users",
					selected => $r->maketext("selected users")
				},
				-onchange => $onChange,
			},
		),
	);
}

sub delete_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r         = $self->r;
	my $db        = $r->db;
	my $user      = $r->param('user');
	my $scope = $actionParams->{"action.delete.scope"}->[0];
	
	my @userIDsToDelete = ();
	#if ($scope eq "visible") {
	#	@userIDsToDelete = @{ $self->{visibleUserIDs} };
	#} elsif ($scope eq "selected") {
	if ($scope eq "selected") {
		@userIDsToDelete = @{ $self->{selectedUserIDs} };
	}
	
	my %allUserIDs = map { $_ => 1 } @{ $self->{allUserIDs} };
	my %visibleUserIDs = map { $_ => 1 } @{ $self->{visibleUserIDs} };
	my %selectedUserIDs = map { $_ => 1 } @{ $self->{selectedUserIDs} };
	
	my $error = "";
	my $num = 0;
	foreach my $userID (@userIDsToDelete) {
		if ($user eq $userID) { # don't delete yourself!!
			$error = $r->maketext("You cannot delete yourself!");
			next;
		}
		delete $allUserIDs{$userID};
		delete $visibleUserIDs{$userID};
		delete $selectedUserIDs{$userID};
		$db->deleteUser($userID);
		$num++;
	}
	
	$self->{allUserIDs} = [ keys %allUserIDs ];
	$self->{visibleUserIDs} = [ keys %visibleUserIDs ];
	$self->{selectedUserIDs} = [ keys %selectedUserIDs ];
	
	return $error ? $error : $r->maketext("deleted [_1] users", $num);
}
sub add_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;

	return WeBWorK::CGI_labeled_input(-type=>"text", -id=>"add_entry", -label_text=>$r->maketext("Add how many students?").": ", -input_attr=>{name=>'number_of_students', value=>1,size => 3});
}

sub add_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	# This action is redirected to the addUser.pm module using ../instructor/add_user/...
	return "Nothing done by add student handler";
}

sub import_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	
	return join(" ",
		WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>"import_select_source",
			-label_text=>$r->maketext("Import users from what file?").": ",
			-input_attr=>{
				-name => "action.import.source",
				-values => [ $self->getCSVList() ],
				-default => $actionParams{"action.import.source"}->[0] || "",
				-onchange => $onChange,
			}
		),
		CGI::br(),
		WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>"import_select_replace",
			-label_text=>$r->maketext("Replace which users?").": ",
			-input_attr=>{
				-name => "action.import.replace",
				-values => [qw(any visible selected none)],
				-default => $actionParams{"action.import.replace"}->[0] || "none",
				-labels => {
					any => $r->maketext("any users"),
					visible => $r->maketext("visible users"),
					selected => $r->maketext("selected users"),
					none => $r->maketext("no users"),
				},
				-onchange => $onChange,
			}
		),
		CGI::br(),
		WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>"import_select_add",
			-label_text=>$r->maketext("Add which new users?").": ",
			-input_attr=>{
				-name => "action.import.add",
				-values => [qw(any none)],
				-default => $actionParams{"action.import.add"}->[0] || "any",
				-labels => {
					any => $r->maketext("any users"),
					none => $r->maketext("no users"),
				},
				-onchange => $onChange,
			}
		),
	);
}

sub import_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;
	
	my $source = $actionParams->{"action.import.source"}->[0];
	my $add = $actionParams->{"action.import.add"}->[0];
	my $replace = $actionParams->{"action.import.replace"}->[0];
	
	my $fileName = $source;
	my $createNew = $add eq "any";
	my $replaceExisting;
	my @replaceList;
	if ($replace eq "any") {
		$replaceExisting = "any";
	} elsif ($replace eq "none") {
		$replaceExisting = "none";
	} elsif ($replace eq "visible") {
		$replaceExisting = "listed";
		@replaceList = @{ $self->{visibleUserIDs} };
	} elsif ($replace eq "selected") {
		$replaceExisting = "listed";
		@replaceList = @{ $self->{selectedUserIDs} };
	}
	
	my ($replaced, $added, $skipped)
		= $self->importUsersFromCSV($fileName, $createNew, $replaceExisting, @replaceList);
	
	# make new users visible... do we really want to do this? probably.
	push @{ $self->{visibleUserIDs} }, @$added;
	
	my $numReplaced = @$replaced;
	my $numAdded = @$added;
	my $numSkipped = @$skipped;
	
	return $r->maketext("[_1] users replaced, [_2] users added, [_3] users skipped. Skipped users: ([_4])", $numReplaced, $numAdded, $numSkipped, join (", ", @$skipped));
}

sub export_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	
	return join("",
		WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>"export_select_scope",
			-label_text=>$r->maketext("Export which users?").": ",
			-input_attr=>{
				-name => "action.export.scope",
				-values => [qw(all visible selected)],
				-default => $actionParams{"action.export.scope"}->[0] || "visible",
				-labels => {
					all => $r->maketext("all users"),
					visible => $r->maketext("visible users"),
					selected => $r->maketext("selected users")
				},
				-onchange => $onChange,
			}
		),
		CGI::br(),
		WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>"export_select_target",
			-label_text=>$r->maketext("Export to what kind of file?").": ",
			-input_attr=>{
				-name=>"action.export.target",
				-values => [ "new", $self->getCSVList() ],
				-labels => { new => $r->maketext("Enter filename below") },
				-default => $actionParams{"action.export.target"}->[0] || "",
				-onchange => $onChange,
			}
		),
		CGI::br(),
		CGI::div({-id=>"export_elements"},
		WeBWorK::CGI_labeled_input(
			-type=>"text",
			-id=>"export_filename",
			-label_text=>$r->maketext("Filename").": ",
			-input_attr=>{
				-name => "action.export.new",
				-value => $actionParams{"action.export.new"}->[0] || "",,
				-width => "50",
				-onchange => $onChange,
			}
		),
		CGI::tt(".lst"),
		),
	);
}

sub export_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $dir     = $ce->{courseDirs}->{templates};
	
	my $scope = $actionParams->{"action.export.scope"}->[0];
	my $target = $actionParams->{"action.export.target"}->[0];
	my $new = $actionParams->{"action.export.new"}->[0];
	
	#get name of templates directory as it appears in file manager
	$dir =~ s|.*/||;
	
	my $fileName;
	if ($target eq "new") {
		$fileName = $new;
	} else {
		$fileName = $target;
	}
	
	$fileName .= ".lst" unless $fileName =~ m/\.lst$/;
	
	my @userIDsToExport;
	if ($scope eq "all") {
		@userIDsToExport = @{ $self->{allUserIDs} };
	} elsif ($scope eq "visible") {
		@userIDsToExport = @{ $self->{visibleUserIDs} };
	} elsif ($scope eq "selected") {
		@userIDsToExport = @{ $self->{selectedUserIDs} };
	}
	
	$self->exportUsersToCSV($fileName, @userIDsToExport);
	
	return $r->maketext("[_1] users exported to file [_2]/[_3]", scalar @userIDsToExport, $dir, $fileName);
}

sub cancelEdit_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	return CGI::span($r->maketext("Abandon changes"));
}

sub cancelEdit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r      = $self->r;
	
	#$self->{selectedUserIDs} = $self->{visibleUserIDs};
		# only do the above if we arrived here via "edit selected users"
	if (defined $r->param("prev_visible_users")) {
		$self->{visibleUserIDs} = [ $r->param("prev_visible_users") ];
	} elsif (defined $r->param("no_prev_visible_users")) {
		$self->{visibleUserIDs} = [];
	} else {
		# leave it alone
	}
	$self->{editMode} = 0;
	
	return $r->maketext("Changes abandoned");
}

sub saveEdit_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	return CGI::span($r->maketext("Save changes"));
}

sub saveEdit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r           = $self->r;
	my $db          = $r->db;
	
	my @visibleUserIDs = @{ $self->{visibleUserIDs} };
	foreach my $userID (@visibleUserIDs) {
		my $User = $db->getUser($userID); # checked
		die $r->maketext("record for visible user [_1] not found", $userID) unless $User;
		my $PermissionLevel = $db->getPermissionLevel($userID); # checked
		die $r->maketext("permissions for [_1] not defined", $userID) unless defined $PermissionLevel;
		foreach my $field ($User->NONKEYFIELDS()) {
			my $param = "user.${userID}.${field}";
			if (defined $tableParams->{$param}->[0]) {
				$User->$field($tableParams->{$param}->[0]);
			}
		}
		
		foreach my $field ($PermissionLevel->NONKEYFIELDS()) {
			my $param = "permission.${userID}.${field}";
			if (defined $tableParams->{$param}->[0]) {
				$PermissionLevel->$field($tableParams->{$param}->[0]);
			}
		}
		
		$db->putUser($User);
		$db->putPermissionLevel($PermissionLevel);
	}
	
	if (defined $r->param("prev_visible_users")) {
		$self->{visibleUserIDs} = [ $r->param("prev_visible_users") ];
	} elsif (defined $r->param("no_prev_visible_users")) {
		$self->{visibleUserIDs} = [];
	} else {
		# leave it alone
	}
	
	$self->{editMode} = 0;
	
	return $r->maketext("Changes saved");
}

sub cancelPassword_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	return CGI::span($r->maketext("Abandon changes"));
}

sub cancelPassword_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r      = $self->r;
	
	#$self->{selectedUserIDs} = $self->{visibleUserIDs};
		# only do the above if we arrived here via "edit selected users"
	if (defined $r->param("prev_visible_users")) {
		$self->{visibleUserIDs} = [ $r->param("prev_visible_users") ];
	} elsif (defined $r->param("no_prev_visible_users")) {
		$self->{visibleUserIDs} = [];
	} else {
		# leave it alone
	}
	$self->{passwordMode} = 0;
	
	return $r->maketext("Changes abandoned");
}

sub savePassword_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	return CGI::span($r->maketext("Save changes"));
}

sub savePassword_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r           = $self->r;
	my $db          = $r->db;
	
	my @visibleUserIDs = @{ $self->{visibleUserIDs} };
	foreach my $userID (@visibleUserIDs) {
		my $User = $db->getUser($userID); # checked
		die $r->maketext("record for visible user [_1] not found", $userID) unless $User;
		my $param = "user.${userID}.new_password";
			if ((defined $tableParams->{$param}->[0]) and ($tableParams->{$param}->[0])) {
				my $newP = $tableParams->{$param}->[0];
				my $Password = eval {$db->getPassword($User->user_id)}; # checked	 	
				my 	$cryptPassword = cryptPassword($newP);											 
				$Password->password(cryptPassword($newP));
				eval { $db->putPassword($Password) };				
			}
	}
	
	if (defined $r->param("prev_visible_users")) {
		$self->{visibleUserIDs} = [ $r->param("prev_visible_users") ];
	} elsif (defined $r->param("no_prev_visible_users")) {
		$self->{visibleUserIDs} = [];
	} else {
		# leave it alone
	}
	
	$self->{passwordMode} = 0;
	
	return $r->maketext("New passwords saved");
}


################################################################################
# sorts
################################################################################

sub byUserID       { lc $a->user_id       cmp lc $b->user_id       }
sub byFirstName    {  (defined $a->first_name && defined $b->first_name) ?  lc $a->first_name cmp lc $b->first_name  : 0;  }
sub byLastName     {  (defined $a->last_name  && defined $b->last_name ) ?  lc $a->last_name  cmp lc $b->last_name   : 0;  }
sub byEmailAddress { lc $a->email_address cmp lc $b->email_address }
sub byStudentID    { lc $a->student_id    cmp lc $b->student_id    }
sub byStatus       { lc $a->status        cmp lc $b->status        }
sub bySection      { lc $a->section       cmp lc $b->section       }
sub byRecitation   { lc $a->recitation    cmp lc $b->recitation    }
sub byComment      { lc $a->comment       cmp lc $b->comment       }
sub byPermission   { $a->{permission}    <=>  $b->{permission}     }  ## permission level is added to user record hash so we can sort it if necessary

# sub byLnFnUid { &byLastName || &byFirstName || &byUserID }

################################################################################
# utilities
################################################################################

# generate labels for section/recitation popup menus
sub menuLabels {
	my ($self, $hashRef) = @_;
	my %hash = %$hashRef;
	
	my %result;
	foreach my $key (keys %hash) {
		my $count = @{ $hash{$key} };
		my $displayKey = $key || "<none>";
		$result{$key} = "$displayKey ($count users)";
	}
	return %result;
}

# FIXME REFACTOR this belongs in a utility class so that addcourse can use it!
# (we need a whole suite of higher-level import/export functions somewhere)
sub importUsersFromCSV {
	my ($self, $fileName, $createNew, $replaceExisting, @replaceList) = @_;
	my $r     = $self->r;
	my $ce    = $r->ce;
	my $db    = $r->db;
	my $dir   = $ce->{courseDirs}->{templates};
	my $user  = $r->param('user');
	
	die $r->maketext("illegal character in input: '/'") if $fileName =~ m|/|;
	die $r->maketext("won't be able to read from file [_1]/[_2]: does it exist? is it readable?", $dir, $fileName)
		unless -r "$dir/$fileName";
	
	my %allUserIDs = map { $_ => 1 } @{ $self->{allUserIDs} };
	my %replaceOK;
	if ($replaceExisting eq "none") {
		%replaceOK = ();
	} elsif ($replaceExisting eq "listed") {
		%replaceOK = map { $_ => 1 } @replaceList;
	} elsif ($replaceExisting eq "any") {
		%replaceOK = %allUserIDs;
	}
	
	my $default_permission_level = $ce->{default_permission_level};
	
	my (@replaced, @added, @skipped);
	
	# get list of hashrefs representing lines in classlist file
	my @classlist = parse_classlist("$dir/$fileName");
	
	# Default status is enrolled -- fetch abbreviation for enrolled
	my $default_status_abbrev = $ce->{statuses}->{Enrolled}->{abbrevs}->[0];
	
	foreach my $record (@classlist) {
		my %record = %$record;
		my $user_id = $record{user_id};
		
		unless (WeBWorK::DB::check_user_id($user_id) ) {  # try to catch lines with bad characters
			push @skipped, $user_id;
			next;
		}
		if ($user_id eq $user) { # don't replace yourself!!
			push @skipped, $user_id;
			next;
		}
		
		if (exists $allUserIDs{$user_id} and not exists $replaceOK{$user_id}) {
			push @skipped, $user_id;
			next;
		}
		
		if (not exists $allUserIDs{$user_id} and not $createNew) {
			push @skipped, $user_id;
			next;
		}
		
		# set default status is status field is "empty"
		$record{status} = $default_status_abbrev
			unless defined $record{status} and $record{status} ne "";
		
		# set password from student ID if password field is "empty"
		if (not defined $record{password} or $record{password} eq "") {
			if (defined $record{student_id} and $record{student_id} ne "") {
				# crypt the student ID and use that
				$record{password} = cryptPassword($record{student_id});
			} else {
				# an empty password field in the database disables password login
				$record{password} = "";
			}
		}
		
		# set default permission level if permission level is "empty"
		$record{permission} = $default_permission_level
			unless defined $record{permission} and $record{permission} ne "";
		
		my $User = $db->newUser(%record);
		my $PermissionLevel = $db->newPermissionLevel(user_id => $user_id, permission => $record{permission});
		my $Password = $db->newPassword(user_id => $user_id, password => $record{password});
		
		# DBFIXME use REPLACE
		if (exists $allUserIDs{$user_id}) {
			$db->putUser($User);
			$db->putPermissionLevel($PermissionLevel);
			$db->putPassword($Password);
			push @replaced, $user_id;
		} else {
			$db->addUser($User);
			$db->addPermissionLevel($PermissionLevel);
			$db->addPassword($Password);
			push @added, $user_id;
		}
	}
	
	return \@replaced, \@added, \@skipped;
}

sub exportUsersToCSV {
	my ($self, $fileName, @userIDsToExport) = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $dir     = $ce->{courseDirs}->{templates};
		
	die $r->maketext("illegal character in input: '/'") if $fileName =~ m|/|;
	
	my @records;
	
	# DBFIXME use an iterator here
	my @Users = $db->getUsers(@userIDsToExport);
	my @Passwords = $db->getPasswords(@userIDsToExport);
	my @PermissionLevels = $db->getPermissionLevels(@userIDsToExport);
	foreach my $i (0 .. $#userIDsToExport) {
		my $User = $Users[$i];
		my $Password = $Passwords[$i];
		my $PermissionLevel = $PermissionLevels[$i];
		next unless defined $User;
		my %record = (
			defined $PermissionLevel ? $PermissionLevel->toHash : (),
			defined $Password ? $Password->toHash : (),
			$User->toHash,
		);
		push @records, \%record;
	}
	
	write_classlist("$dir/$fileName", @records);
}

################################################################################
# "display" methods
################################################################################

sub fieldEditHTML {
	my ($self, $fieldName, $value, $properties) = @_;
	my $r = $self->r;
	my $ce = $self->r->ce;
	my $size = $properties->{size};
	my $type = $properties->{type};
	my $access = $properties->{access};
	my $items = $properties->{items};
	my $synonyms = $properties->{synonyms};
	
	if ($type eq "email") {
		if ($value eq '&nbsp;') {
			return $value;}
		else {
			return CGI::a({-href=>"mailto:$value"},$value);
		}
	}
	
	if ($access eq "readonly") {
		# hack for status
		if ($type eq "status") {
			my $status_name = $ce->status_abbrev_to_name($value);
			if (defined $status_name) {
				$value = "$status_name ($value)";
			}
		}
		return $value;
	}
	
	if ($type eq "number" or $type eq "text") {
		return CGI::input({-type=>"text", -id=>$fieldName."_id", name=>$fieldName, value=>$value, size=>$size});
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
		
		return WeBWorK::CGI_labeled_input(
			-type=>"select",
			-id=>$fieldName."_id",
			-label_text=>$r->maketext(ucfirst($fieldName)),
			-input_attr=>{
				name => $fieldName, 
				values => [keys %$items],
				default => $value,
				labels => $items,
			}
		),
	}
	
	if ($type eq "status") {
		# we used to surreptitously map synonyms to a canonical value...
		# so should we continue to do that?
		my $status_name = $ce->status_abbrev_to_name($value);
		if (defined $status_name) {
			$value = ($ce->status_name_to_abbrevs($status_name))[0];
		}
		
		my (@values, %labels);
		while (my ($k, $v) = each %{$ce->{statuses}}) {
			my @abbrevs = @{$v->{abbrevs}};
			push @values, $abbrevs[0];
			foreach my $abbrev (@abbrevs) {
				$labels{$abbrev} = $r->maketext($k);
			}
		}
		
		return CGI::popup_menu({
		    -id=>$fieldName."_id",
		    -name => $fieldName, 
		    -values => \@values,
		    -default => $value,
		    -labels => \%labels,
				  }
		    ),
	}

	if ($type eq "permission") {
		my ($default, @values, %labels);
		my %roles = %{$ce->{userRoles}};
		foreach my $role (sort {$roles{$a}<=>$roles{$b}} keys(%roles) ) {
			my $val = $roles{$role};

			push(@values, $val);
			$labels{$val} = $role;
			$default = $val if ( $value eq $role );
		}
		
		return CGI::popup_menu({
		    -id=>$fieldName."_id",
		    -name => $fieldName,
		    -values => \@values,
		    -default => [$default], # force default of 0 to be a selector value (instead of 
		    # being considered as a null -- now works with CGI 3.42
		    #-default => $default,   # works with CGI 3.49 (but the above does not, go figure
		    -labels => \%labels,
		    -override => 1,    # force default value to be selected. (corrects bug on newer CGI
		    }
		),
	}
}

sub recordEditHTML {
	my ($self, $User, $PermissionLevel, %options) = @_;
	my $r           = $self->r;
	my $urlpath     = $r->urlpath;
	my $db          = $r->db;
	my $ce          = $r->ce;
	my $authz	= $r->authz;
	my $user	= $r->param('user');
	my $root        = $ce->{webworkURLs}->{root};
	my $courseName  = $urlpath->arg("courseID");
	
	my $editMode = $options{editMode};
	my $passwordMode = $options{passwordMode};
	my $userSelected = $options{userSelected};

	my $statusClass = $ce->status_abbrev_to_name($User->status);

	my $sets = $db->countUserSets($User->user_id);
	my $totalSets = $self->{totalSets};
	
	my $changeEUserURL = $self->systemLink($urlpath->new(type=>'set_list',args=>{courseID=>$courseName}),
										   params => {effectiveUser => $User->user_id}
	);
	
	my $setsAssignedToUserURL = $self->systemLink($urlpath->new(type=>'instructor_user_detail',
	                                                            args=>{courseID => $courseName, 
	                                                                   userID   => $User->user_id
	                                                                   }),
										   params => {effectiveUser => $User->user_id}
	);

	my $userListURL = $self->systemLink($urlpath->new(type=>'instructor_user_list2', args=>{courseID => $courseName} )) . "&editMode=1&visible_users=" . $User->user_id;

	my $imageURL = $ce->{webworkURLs}->{htdocs}."/images/edit.gif";
        my $imageLink = CGI::a({href => $userListURL}, CGI::img({src=>$imageURL, border=>0, alt=>"Link to Edit Page for ".$User->user_id}));
	
	my @tableCells;
	
	# Select
	if ($editMode or $passwordMode) {
		# column not there
	} else {
		# selection checkbox
		# push @tableCells, CGI::checkbox(
			# -name => "selected_users",
			# -value => $User->user_id,
			# -checked => $userSelected,
			# -label => "",
		my $label = "";
		if ( FIELD_PERMS()->{act_as} and not $authz->hasPermissions($user, FIELD_PERMS()->{act_as}) ){
			$label = $User->user_id . $imageLink;
		} else {
			$label = CGI::a({href=>$changeEUserURL}, $User->user_id) . $imageLink;
		}
		
		push @tableCells, WeBWorK::CGI_labeled_input(
			-type=>"checkbox",
			-id=>$User->user_id."_checkbox",
			-label_text=>$label,
			-input_attr=> $userSelected ?
			{
				-name => "selected_users",
				-value => $User->user_id,
				-checked => "checked",
				-class=>"table_checkbox",
			}
			:
			{
				-name => "selected_users",
				-value => $User->user_id,
				-class=>"table_checkbox",
			}
		);
	}
	
	# Act As
	# if ($editMode or $passwordMode) {
		# # column not there
	# } else {
		# # selection checkbox
		# if ( FIELD_PERMS()->{act_as} and not $authz->hasPermissions($user, FIELD_PERMS()->{act_as}) ){
			# push @tableCells, $User->user_id . $imageLink;
		# } else {
			# push @tableCells, CGI::a({href=>$changeEUserURL}, $User->user_id) . $imageLink;
		# }
	# }
	
	# Login Status
	if ($editMode or $passwordMode) {
		# column not there
	} else {
		# check to see if a user is currently logged in
		# DBFIXME use a WHERE clause
		my $Key = $db->getKey($User->user_id);
		my $is_active = ($Key and time <= $Key->timestamp()+$ce->{sessionKeyTimeout}); # cribbed from check_session
		push @tableCells, $is_active ? CGI::b($r->maketext("Active")) : CGI::em($r->maketext("Inactive"));
	}
	
	# change password (only in password mode)
	if ($passwordMode) {
		if ($User->user_id eq $user) {
			push @tableCells, CGI::div({-class=>"ResultsWithError"},$r->maketext("You may not change your own password here!"))   # don't allow a professor to change their own password from this form
		}
		else {
			my $fieldName = 'user.' . $User->user_id . '.' . 'new_password';
			push @tableCells, WeBWorK::CGI_labeled_input(-type=>"text", -id=>"password_edit", -label_text=>$r->maketext("New Password").": ", -input_attr=>{name=>$fieldName, size=>14});
		}	
	}	
	# User ID (edit mode) or Assigned Sets (otherwise)
	if ( $passwordMode) {
		# straight user ID
		push @tableCells, CGI::div({class=>$statusClass}, $User->user_id);
	} elsif ($editMode) {
		# straight user ID
		 my $userDetailPage = $urlpath->new(type =>'instructor_user_detail',
					                       args =>{
						                             courseID => $courseName,
						                             userID   => $User->user_id, #FIXME eventually this should be a list??
	                }
	    );
	    my $userDetailUrl = $self->systemLink($userDetailPage,params =>{});
		push @tableCells, CGI::a({href=>$userDetailUrl}, $User->user_id);
	
	} else {
		# "edit sets assigned to user" link
		#push @tableCells, CGI::a({href=>$setsAssignedToUserURL}, "Edit sets");
		if ( FIELD_PERMS()->{sets} and not $authz->hasPermissions($user, FIELD_PERMS()->{sets}) ) {
			push @tableCells, "$sets/$totalSets";
		} else {
			push @tableCells, CGI::a({href=>$setsAssignedToUserURL}, "$sets/$totalSets");
		}
	}

	# User Fields
	foreach my $field ($User->NONKEYFIELDS) {
		my $fieldName = 'user.' . $User->user_id . '.' . $field,
		my $fieldValue = $User->$field;
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = 'readonly' unless $editMode;
		$properties{type} = 'email' if ($field eq 'email_address' and !$editMode and !$passwordMode);
		$fieldValue = $self->nbsp($fieldValue) unless $editMode;
		push @tableCells, CGI::div({class=>$statusClass}, $self->fieldEditHTML($fieldName, $fieldValue, \%properties));
	}
	
	# PermissionLevel Fields
	foreach my $field ($PermissionLevel->NONKEYFIELDS) {
		my $fieldName = 'permission.' . $PermissionLevel->user_id . '.' . $field,
		my $fieldValue = $PermissionLevel->$field;
		# get name out of permission level 
		if ( $field eq 'permission' ) {
			($fieldValue) = grep { $ce->{userRoles}->{$_} eq $fieldValue } ( keys ( %{$ce->{userRoles}} ) );
		}
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = 'readonly' unless $editMode;
		$fieldValue = $self->nbsp($fieldValue) unless $editMode;
		push @tableCells, CGI::div({class=>$statusClass}, $self->fieldEditHTML($fieldName, $fieldValue, \%properties));
	}
	
	return CGI::Tr({}, CGI::td({nowrap=>1}, \@tableCells));
}

sub printTableHTML {
	my ($self, $UsersRef, $PermissionLevelsRef, $fieldNamesRef, %options) = @_;
	my $r                       = $self->r;
	my $urlpath     = $r->urlpath;
	my $courseName  = $urlpath->arg("courseID");
	my $userTemplate            = $self->{userTemplate};
	my $permissionLevelTemplate = $self->{permissionLevelTemplate};
	my @Users                   = @$UsersRef;
	my @PermissionLevels        = @$PermissionLevelsRef;
	my %fieldNames              = %$fieldNamesRef;
	
	my $editMode                = $options{editMode};
	my $passwordMode            = $options{passwordMode};
	my %selectedUserIDs         = map { $_ => 1 } @{ $options{selectedUserIDs} };
#	my $currentSort             = $options{currentSort};
	my $primarySortField        = $options{primarySortField};
	my $secondarySortField      = $options{secondarySortField};	
	my @visableUserIDs          = @{ $options{visableUserIDs} };	
		
	# names of headings:
	my @realFieldNames = (
			$userTemplate->KEYFIELDS,
			$userTemplate->NONKEYFIELDS,
			$permissionLevelTemplate->NONKEYFIELDS,
	);
	
#	my %sortSubs = %{ SORT_SUBS() };
	#my @stateParams = @{ STATE_PARAMS() };
	#my $hrefPrefix = $r->uri . "?" . $self->url_args(@stateParams); # $self->url_authen_args
	my @tableHeadings;
	foreach my $field (@realFieldNames) {
		my $result = $fieldNames{$field};
		push @tableHeadings, $result;
	};
	
	# prepend selection checkbox? only if we're NOT editing!
	unless($editMode or $passwordMode) {

		#warn "line 1582 visibleUserIDs=@visableUserIDs \n";
		my %current_state =();
		if (@visableUserIDs) {
			# This is a hack to get around: Maximum URL Length Is 2,083 Characters in Internet Explorer.
			# Without passing visable users the URL is about 250 characters. If the total URL is under the limit
			# we will pass visable users. If it is over, we will not pass any and all users will be displayed.
			# Maybe we should replace the GET method by POST (but this doesn't look good) --- AKP

			my $visableUserIDsString = join ':', @visableUserIDs;
			if (length($visableUserIDsString) < 1830) {
				%current_state = (
					primarySortField => "$primarySortField", 
					secondarySortField => "$secondarySortField",
					visable_user_string => "$visableUserIDsString"
				);
			} else {
				%current_state = (
				primarySortField => "$primarySortField", 
				secondarySortField => "$secondarySortField",
				show_all_users => "1"
				);
			}	
		} else {
			%current_state = (
			primarySortField => "$primarySortField", 
			secondarySortField => "$secondarySortField",
			no_visible_users => "1"
			);
		}	
		@tableHeadings = (
			#"Select",
			CGI::a({href => $self->systemLink($urlpath->new(type=>'instructor_user_list2', args=>{courseID => $courseName,} ), params=>{labelSortMethod=>'user_id', %current_state})}, $r->maketext('Login Name')),
			$r->maketext("Login Status"), 
			$r->maketext("Assigned Sets"),
			CGI::a({href => $self->systemLink($urlpath->new(type=>'instructor_user_list2', args=>{courseID => $courseName,} ), params=>{labelSortMethod=>'first_name', %current_state})}, $r->maketext('First Name')),
			CGI::a({href => $self->systemLink($urlpath->new(type=>'instructor_user_list2', args=>{courseID => $courseName,} ), params=>{labelSortMethod=>'last_name', %current_state})}, $r->maketext('Last Name')),
			CGI::a({href => $self->systemLink($urlpath->new(type=>'instructor_user_list2', args=>{courseID => $courseName,} ), params=>{labelSortMethod=>'email_address', %current_state})}, $r->maketext('Email Address')),
			CGI::a({href => $self->systemLink($urlpath->new(type=>'instructor_user_list2', args=>{courseID => $courseName,} ), params=>{labelSortMethod=>'student_id', %current_state})}, $r->maketext('Student ID')),
			CGI::a({href => $self->systemLink($urlpath->new(type=>'instructor_user_list2', args=>{courseID => $courseName,} ), params=>{labelSortMethod=>'status', %current_state})}, $r->maketext('Status')),
			CGI::a({href => $self->systemLink($urlpath->new(type=>'instructor_user_list2', args=>{courseID => $courseName,} ), params=>{labelSortMethod=>'section', %current_state})}, $r->maketext('Section')),
			CGI::a({href => $self->systemLink($urlpath->new(type=>'instructor_user_list2', args=>{courseID => $courseName,} ), params=>{labelSortMethod=>'recitation', %current_state})}, $r->maketext('Recitation')),
			CGI::a({href => $self->systemLink($urlpath->new(type=>'instructor_user_list2', args=>{courseID => $courseName,} ), params=>{labelSortMethod=>'comment', %current_state})}, $r->maketext('Comment')),
			CGI::a({href => $self->systemLink($urlpath->new(type=>'instructor_user_list2', args=>{courseID => $courseName,} ), params=>{labelSortMethod=>'permission', %current_state})}, $r->maketext('Permission Level')),
		)	
	}
 	if($passwordMode) {	
		unshift @tableHeadings, $r->maketext("New Password");
        }       
        
	# print the table
	if ($editMode or $passwordMode) {
		print CGI::start_table({-nowrap=>0, id=>"classlist-table", -class=>"classlist-table set_table", -summary=>$r->maketext("_USER_TABLE_SUMMARY") });# "A table showing all the current users along with several fields of user information. The fields from left to right are: Login Name, Login Status, Assigned Sets, First Name, Last Name, Email Address, Student ID, Enrollment Status, Section, Recitation, Comments, and Permission Level.  Clicking on the links in the column headers will sort the table by the field it corresponds to. The Login Name fields contain checkboxes for selecting the user.  Clicking the link of the name itself will allow you to act as the selected user.  There will also be an image link following the name which will take you to a page where you can edit the selected user's information.  Clicking the emails will allow you to email the corresponding user.  Clicking the links in the entries in the assigned sets columns will take you to a page where you can view and reassign the sets for the selected user."});
	} else {
		print CGI::start_table({-border=>1, -nowrap=>1, -id=>"classlist-table", -class=>"classlist-table set_table", -summary=>$r->maketext("_USER_TABLE_SUMMARY") });#"A table showing all the current users along with several fields of user information. The fields from left to right are: Login Name, Login Status, Assigned Sets, First Name, Last Name, Email Address, Student ID, Enrollment Status, Section, Recitation, Comments, and Permission Level.  Clicking on the links in the column headers will sort the table by the field it corresponds to. The Login Name fields contain checkboxes for selecting the user.  Clicking the link of the name itself will allow you to act as the selected user.  There will also be an image link following the name which will take you to a page where you can edit the selected user's information.  Clicking the emails will allow you to email the corresponding user.  Clicking the links in the entries in the assigned sets columns will take you to a page where you can view and reassign the sets for the selected user."});
	}
	
	print CGI::caption($r->maketext("Users List"));
	
	print CGI::Tr({}, CGI::th({}, \@tableHeadings));
	

	for (my $i = 0; $i < @Users; $i++) {
		my $User = $Users[$i];
		my $PermissionLevel = $PermissionLevels[$i];
		
		print $self->recordEditHTML($User, $PermissionLevel,
			editMode => $editMode,
			passwordMode => $passwordMode,
			userSelected => exists $selectedUserIDs{$User->user_id}
		);
	}
	
	print CGI::end_table();
    #########################################
	# if there are no users shown print message
	# 
	##########################################
	
	print CGI::p(
	              CGI::i($r->maketext("No students shown.  Choose one of the options above to list the students in the course."))
	) unless @Users;
}

# output_JS subroutine

# prints out the necessary JS for this page

sub output_JS{
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/legacy/addOnLoadEvent.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/legacy/show_hide.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/legacy/vendor/tabber.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/legacy/classlist_handlers.js"}), CGI::end_script();
	return "";
}

# Just tells template to output the stylesheet for Tabber
sub output_tabber_CSS{
	return "";
}

#Tells template to output stylesheet for Jquery-UI
sub output_jquery_ui_CSS{
	return "";
}
1;

