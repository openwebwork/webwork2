################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/UserList.pm,v 1.50 2004/05/21 20:48:21 gage Exp $
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

package WeBWorK::ContentGenerator::Instructor::UserList;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UserList - Entry point for User-specific
data editing

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
use CGI qw();
use WeBWorK::Utils qw(readFile readDirectory cryptPassword);
use Apache::Constants qw(:common REDIRECT DONE);  #FIXME  -- this should be called higher up in the object tree.
use constant HIDE_USERS_THRESHHOLD => 20;
use constant EDIT_FORMS => [qw(cancelEdit saveEdit)];
use constant VIEW_FORMS => [qw(filter edit  import export add delete)];
use constant STATE_PARAMS => [qw(user effectiveUser key visible_users no_visible_users prev_visible_users no_prev_visible_users editMode sortField)];

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
		type => "enumerable",
		size => 4,
		access => "readwrite",
		items => {
			"C" => "Enrolled",
			"D" => "Drop",
			"A" => "Audit",
		},
		synonyms => {
			qr/^[ce]/i => "C",
			qr/^[dw]/i => "D",
			qr/^a/i => "A",
			"*" => "C",
		}
	},
	section => {
		type => "text",
		size => 4,
		access => "readwrite",
	},
	recitation => {
		type => "text",
		size => 4,
		access => "readwrite",
	},
	comment => {
		type => "text",
		size => 20,
		access => "readwrite",
	},
	permission => {
		type => "number",
		size => 2,
		access => "readwrite",
	}
};
sub pre_header_initialize {
	my $self          = shift;
	my $r             = $self->r;
	my $urlpath       = $r->urlpath;
	my $ce            = $r->ce;
	my $courseName    = $urlpath->arg("courseID");
	# Handle redirects, if any.
	##############################
	# Redirect to the addUser page
	##################################
	
	defined($r->param('action')) && $r->param('action') eq 'add' && do {
		# fix url and redirect
		my $root              = $ce->{webworkURLs}->{root};
		
		my $numberOfStudents  = $r->param('number_of_students');
		warn "number of students not defined " unless defined $numberOfStudents;

		my $uri=$self->systemLink( $urlpath->newFromModule('WeBWorK::ContentGenerator::Instructor::AddUsers',courseID=>$courseName),
		                           params=>{
		                          			number_of_students=>$numberOfStudents,
		                                   }
		);
		#FIXME  does the display mode need to be defined?
		#FIXME  url_authen_args also includes an effective user, so the new one must come first.
		# even that might not work with every browser since there are two effective User assignments.
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
	};
}
# FIXME  -- this should be moved up to instructor or contentgenerator
sub header {
	my $self = shift;
	return REDIRECT if $self->{noContent};
	my $r    = $self->r;
	$r->content_type('text/html');
	$r->send_http_header();
	return OK;
}

#FIXME -- this should probably be moved up to instructor or contentgenerator as well
#sub nbsp {
#	my $str = shift;  
#        ($str =~/\S/) ? $str : '&nbsp;'  ;  # returns non-breaking space for empty strings
#                                            # tricky cases:   $str =0;
#                                            #  $str is a complex number
#}
# moved to ContentGenerator.pm

sub initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $ce     = $r->ce;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	unless ($authz->hasPermissions($user, "modify_student_data")) {
		$self->addmessage(CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to modify student data")));
		return;
	}
	
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
	
	return CGI::em("You are not authorized to access the Instructor tools.")
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
		"Assigned sets", 
		"First Name", 
		"Last Name", 
		"E-mail", 
		"Student ID", 
		"Status", 
		"Section", 
		"Recitation", 
		"Comment", 
		"Perm. Level"
	);
	
	########## set initial values for state fields
	
	my @allUserIDs = $db->listUsers;
	$self->{allUserIDs} = \@allUserIDs;
	
	if (defined $r->param("visible_users")) {
		$self->{visibleUserIDs} = [ $r->param("visible_users") ];
	} elsif (defined $r->param("no_visible_users")) {
		$self->{visibleUserIDs} = [];
	} else {
		if (@allUserIDs > HIDE_USERS_THRESHHOLD) {
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
	
	$self->{sortField} = $r->param("sortField") || "last_name";
	
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
		unless (grep { $_ eq $actionID } @{ VIEW_FORMS() }, @{ EDIT_FORMS() }) {
			die "Action $actionID not found";
		}
		my $actionHandler = "${actionID}_handler";
		my %genericParams;
		foreach my $param (qw(selected_users)) {
			$genericParams{$param} = [ $r->param($param) ];
		}
		my %actionParams = $self->getActionParams($actionID);
		my %tableParams = $self->getTableParams();
		print CGI::p(
		    '<div style="color:green">',
			"Result of last action performed: ",
			CGI::i($self->$actionHandler(\%genericParams, \%actionParams, \%tableParams)),
			'</div>',
			CGI::hr()
			
		);
	}
		
	########## retrieve possibly changed values for member fields
	
	#@allUserIDs = @{ $self->{allUserIDs} }; # do we need this one?
	my @visibleUserIDs = @{ $self->{visibleUserIDs} };
	my @prevVisibleUserIDs = @{ $self->{prevVisibleUserIDs} };
	my @selectedUserIDs = @{ $self->{selectedUserIDs} };
	my $editMode = $self->{editMode};
	my $sortField = $self->{sortField};
	
	#warn "visibleUserIDs=@visibleUserIDs\n";
	#warn "prevVisibleUserIDs=@prevVisibleUserIDs\n";
	#warn "selectedUserIDs=@selectedUserIDs\n";
	#warn "editMode=$editMode\n";
	
	########## get required users
		
	my @Users = grep { defined $_ } @visibleUserIDs ? $db->getUsers(@visibleUserIDs) : ();
	
	# presort users
	my %sortSubs = %{ SORT_SUBS() };
	my $sortSub = $sortSubs{$sortField};
	#@Users = sort $sortSub @Users;
	@Users = sort byLnFnUid @Users;
		
	my @PermissionLevels;
	
	for (my $i = 0; $i < @Users; $i++) {
		my $User = $Users[$i];
		my $PermissionLevel = $db->getPermissionLevel($User->user_id); # checked
		
		unless ($PermissionLevel) {
			# uh oh! no permission level record found!
			warn "added missing permission level for user ", $User->user_id, "\n";
			
			# create a new permission level record
			$PermissionLevel = $db->newPermissionLevel;
			$PermissionLevel->user_id($User->user_id);
			$PermissionLevel->permission(0);
			
			# add it to the database
			$db->addPermissionLevel($PermissionLevel);
		}
		
		$PermissionLevels[$i] = $PermissionLevel;
	}
	
	########## print beginning of form
	
	print CGI::start_form({method=>"post", action=>$self->systemLink($urlpath,authen=>0), name=>"userlist"});
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
	
	print CGI::hidden(-name=>"sortField", -value=>$sortField);
	
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
		my $onChange = "document.userlist.action[$i].checked=true";
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
	
	print CGI::p("Showing ", scalar @visibleUserIDs, " out of ", scalar @allUserIDs, " users.");
	
	$self->printTableHTML(\@Users, \@PermissionLevels, \%prettyFieldNames,
		editMode => $editMode,
		selectedUserIDs => \@selectedUserIDs,
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
	return join("", 
			"Show ",
			CGI::popup_menu(
				-name => "action.filter.scope",
				-values => [qw(all none selected match_ids match_section match_recitation)],
				-default => $actionParams{"action.filter.scope"}->[0] || "match_ids",
				-labels => {
					all => "all users",
					none => "no users",
					selected => "users checked below",
					match_ids => "users with matching user IDs:",
					match_section => "users in selected section",
					match_recitation => "users in selected recitation",
				},
				-onchange => $onChange,
			),
			" ",
			CGI::textfield(
				-name => "action.filter.user_ids",
				-value => $actionParams{"action.filter.user_ids"}->[0] || "",,
				-width => "50",
				-onchange => $onChange,
			),
			" (separate multiple IDs with commas)",
			CGI::br(),
			"sections: ",
			CGI::popup_menu(
				-name => "action.filter.section",
				-values => [ keys %{ $self->{sections} } ],
				-default => $actionParams{"action.filter.section"}->[0] || "",
				-labels => { $self->menuLabels($self->{sections}) },
				-onchange => $onChange,
			),
			" recitations: ",
			CGI::popup_menu(
				-name => "action.filter.recitation",
				-values => [ keys %{ $self->{recitations} } ],
				-default => $actionParams{"action.filter.recitation"}->[0] || "",
				-labels => { $self->menuLabels($self->{recitations}) },
				-onchange => $onChange,
			),
	);
	#	),
	#));
}

# this action handler modifies the "visibleUserIDs" field based on the contents
# of the "action.filter.scope" parameter and the "selected_users" 
sub filter_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	
	my $result;
	
	my $scope = $actionParams->{"action.filter.scope"}->[0];
	if ($scope eq "all") {
		$result = "showing all users";
		$self->{visibleUserIDs} = $self->{allUserIDs};
	} elsif ($scope eq "none") {
		$result = "showing no users";
		$self->{visibleUserIDs} = [];
	} elsif ($scope eq "selected") {
		$result = "showing selected users";
		$self->{visibleUserIDs} = $genericParams->{selected_users}; # an arrayref
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

sub edit_form {
	my ($self, $onChange, %actionParams) = @_;
	return join("",
		"Edit ",
		CGI::popup_menu(
			-name => "action.edit.scope",
			-values => [qw(all visible selected)],
			-default => $actionParams{"action.edit.scope"}->[0] || "selected",
			-labels => {
				all => "all users",
				visible => "visible users",
				selected => "selected users"
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
		$result = "editing all users";
		$self->{visibleUserIDs} = $self->{allUserIDs};
	} elsif ($scope eq "visible") {
		$result = "editing visible users";
		# leave visibleUserIDs alone
	} elsif ($scope eq "selected") {
		$result = "editing selected users";
		$self->{visibleUserIDs} = $genericParams->{selected_users}; # an arrayref
	}
	$self->{editMode} = 1;
	
	return $result;
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
			    none     => "no users.",
				#visible  => "visible users.",
				selected => "selected users."
			},
			-onchange => $onChange,
		),
		CGI::em(" Deletion destroys all user-related data and is not undoable!"),
		),
	);
}

sub delete_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r         = $self->r;
	my $db        = $r->db;
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
	
	foreach my $userID (@userIDsToDelete) {
		delete $allUserIDs{$userID};
		delete $visibleUserIDs{$userID};
		delete $selectedUserIDs{$userID};
		$db->deleteUser($userID);
	}
	
	$self->{allUserIDs} = [ keys %allUserIDs ];
	$self->{visibleUserIDs} = [ keys %visibleUserIDs ];
	$self->{selectedUserIDs} = [ keys %selectedUserIDs ];
	
	my $num = @userIDsToDelete;
	return "deleted $num user" . ($num == 1 ? "" : "s");
}
sub add_form {
	my ($self, $onChange, %actionParams) = @_;

    return "Add ", CGI::input({name=>'number_of_students', value=>1,size => 3}), " student(s). ";
}

sub add_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	# This action is redirected to the addUser.pm module using ../instructor/add_user/...
	return "Nothing done by add student handler";
}
sub import_form {
	my ($self, $onChange, %actionParams) = @_;
	return join(" ",
		"Import users from file",
		CGI::popup_menu(
			-name => "action.import.source",
			-values => [ "", $self->getCSVList() ],
			-default => $actionParams{"action.import.source"}->[0] || "",
			-onchange => $onChange,
		),
		"replacing",
		CGI::popup_menu(
			-name => "action.import.replace",
			-values => [qw(any visible selected none)],
			-default => $actionParams{"action.import.replace"}->[0] || "none",
			-labels => {
				any => "any",
				visible => "visible",
				selected => "selected",
				none => "no",
			},
			-onchange => $onChange,
		),
		"existing users and adding",
		CGI::popup_menu(
			-name => "action.import.add",
			-values => [qw(any none)],
			-default => $actionParams{"action.import.add"}->[0] || "any",
			-labels => {
				any => "any",
				none => "no",
			},
			-onchange => $onChange,
		),
		"new users",
	);
}

sub import_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	
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
	
	return $numReplaced . " user" . ($numReplaced == 1 ? "" : "s") . " replaced, "
		. $numAdded . " user" . ($numAdded == 1 ? "" : "s") . " added, "
		. $numSkipped . " user" . ($numSkipped == 1 ? "" : "s") . " skipped.";
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
				all => "all users",
				visible => "visible users",
				selected => "selected users"
			},
			-onchange => $onChange,
		),
		" to ",
		CGI::popup_menu(
			-name=>"action.export.target",
			-values => [ "new", $self->getCSVList() ],
			-labels => { new => "a new file named:" },
			-default => $actionParams{"action.export.target"}->[0] || "",
			-onchange => $onChange,
		),
		#CGI::br(),
		#"new file to create: ",
		CGI::textfield(
			-name => "action.export.new",
			-value => $actionParams{"action.export.new"}->[0] || "",,
			-width => "50",
			-onchange => $onChange,
		),
		CGI::tt(".lst"),
	);
}

sub export_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	
	my $scope = $actionParams->{"action.export.scope"}->[0];
	my $target = $actionParams->{"action.export.target"}->[0];
	my $new = $actionParams->{"action.export.new"}->[0];
	
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
	
	return scalar @userIDsToExport . " users exported";
}

sub cancelEdit_form {
	my ($self, $onChange, %actionParams) = @_;
	return "Abandon changes";
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
	
	my @visibleUserIDs = @{ $self->{visibleUserIDs} };
	foreach my $userID (@visibleUserIDs) {
		my $User = $db->getUser($userID); # checked
		die "record for visible user $userID not found" unless $User;
		my $PermissionLevel = $db->getPermissionLevel($userID); # checked
		die "permissions for $userID not defined" unless defined $PermissionLevel;
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
	
	return "changes saved";
}

################################################################################
# sorts
################################################################################

sub byUserID       { $a->user_id       cmp $b->user_id       }
sub byFirstName    { $a->first_name    cmp $b->first_name    }
sub byLastName     { $a->last_name     cmp $b->last_name     }
sub byEmailAddress { $a->email_address cmp $b->email_address }
sub byStudentID    { $a->student_id    cmp $b->student_id    }
sub byStatus       { $a->status        cmp $b->status        }
sub bySection      { $a->section       cmp $b->section       }
sub byRecitation   { $a->recitation    cmp $b->recitation    }
sub byComment      { $a->comment       cmp $b->comment       }

sub byLnFnUid { &byLastName || &byFirstName || &byUserID }

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

sub importUsersFromCSV {
	my ($self, $fileName, $createNew, $replaceExisting, @replaceList) = @_;
	my $r     = $self->r;
	my $ce    = $r->ce;
	my $db    = $r->db;
	my $dir   = $ce->{courseDirs}->{templates};
	
	die "illegal character in input: \"/\"" if $fileName =~ m|/|;
	die "won't be able to read from file $dir/$fileName: does it exist? is it readable?"
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
	
	my (@replaced, @added, @skipped);
	
	my @contents = split /\n/, readFile("$dir/$fileName");
	foreach my $string (@contents) {
		$string =~ s/^\s+//;
		$string =~ s/\s+$//;
		my (
			$student_id, $last_name, $first_name, $status, $comment,
			$section, $recitation, $email_address, $user_id
		) = split /\s*,\s*/, $string;
		
		if (exists $allUserIDs{$user_id} and not exists $replaceOK{$user_id}) {
			push @skipped, $user_id;
			next;
		}
		
		if (not exists $allUserIDs{$user_id} and not $createNew) {
			push @skipped, $user_id;
			next;
		}
		
		my $User = $db->newUser;
		$User->user_id($user_id);
		$User->first_name($first_name);
		$User->last_name($last_name);
		$User->email_address($email_address);
		$User->student_id($student_id);
		$User->status($status);
		$User->section($section);
		$User->recitation($recitation);
		$User->comment($comment);
		
		my $PermissionLevel = $db->newPermissionLevel;
		$PermissionLevel->user_id($user_id);
		$PermissionLevel->permission(0);
		
		my $Password = $db->newPassword;
		$Password->user_id($user_id);
		$Password->password(cryptPassword($student_id));
		
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
		
	die "illegal character in input: \"/\"" if $fileName =~ m|/|;
	
	open my $fh, ">", "$dir/$fileName"
		or die "failed to open file $dir/$fileName for writing: $!\n";
	
	foreach my $userID (@userIDsToExport) {
		my $User = $db->getUser($userID); # checked
		die "record for user $userID not found." unless $User;
		my @fields = (
			$User->student_id,
			$User->last_name,
			$User->first_name,
			$User->status,
			$User->comment,
			$User->section,
			$User->recitation,
			$User->email_address,
			$User->user_id,
		);
		my $string = join ",", @fields;
		print $fh "$string\n";
	}
	
	close $fh;
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
	
	if ($access eq "readonly") {
		return $value;
	}
	
	if ($type eq "number" or $type eq "text") {
		return CGI::input({type=>"text", name=>$fieldName, value=>$value, size=>$size});
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
}

sub recordEditHTML {
	my ($self, $User, $PermissionLevel, %options) = @_;
	my $r           = $self->r;
	my $urlpath     = $r->urlpath;
	my $ce          = $r->ce;
	my $root        = $ce->{webworkURLs}->{root};
	my $courseName  = $urlpath->arg("courseID");
	
	my $editMode = $options{editMode};
	my $userSelected = $options{userSelected};

	my $statusClass = $ce->{siteDefaults}->{status}->{$User->{status}};
	
	my $changeEUserURL = $self->systemLink($urlpath->new(type=>'set_list',args=>{courseID=>$courseName}),
										   params => {effectiveUser => $User->user_id}
	);
	
	my $setsAssignedToUserURL = $self->systemLink($urlpath->new(type=>'instructor_sets_assigned_to_user',
	                                                            args=>{courseID => $courseName, 
	                                                                   userID   => $User->user_id
	                                                                   }),
										   params => {effectiveUser => $User->user_id}
	);
	
	my @tableCells;
	
	# Select
	if ($editMode) {
		# column not there
	} else {
		# selection checkbox
		push @tableCells, CGI::checkbox(
			-name => "selected_users",
			-value => $User->user_id,
			-checked => $userSelected,
			-label => "",
		);
	}
	
	# Act As
	if ($editMode) {
		# column not there
	} else {
		# selection checkbox
		push @tableCells, CGI::a({href=>$changeEUserURL}, $User->user_id);
	}
	
	# User ID
	if ($editMode) {
		# straight user ID
		push @tableCells, CGI::div({class=>$statusClass}, $User->user_id);
	} else {
		# "edit sets assigned to user" link
		push @tableCells, CGI::a({href=>$setsAssignedToUserURL}, "Edit sets");
	}

	# User Fields
	foreach my $field ($User->NONKEYFIELDS) {
		my $fieldName = "user." . $User->user_id . "." . $field,
		my $fieldValue = $User->$field;
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = "readonly" unless $editMode;
		$fieldValue = $self->nbsp($fieldValue) unless $editMode;
		push @tableCells, CGI::div({class=>$statusClass}, $self->fieldEditHTML($fieldName, $fieldValue, \%properties));
	}
	
	# PermissionLevel Fields
	foreach my $field ($PermissionLevel->NONKEYFIELDS) {
		my $fieldName = "permission." . $PermissionLevel->user_id . "." . $field,
		my $fieldValue = $PermissionLevel->$field;
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = "readonly" unless $editMode;
		$fieldValue = $self->nbsp($fieldValue) unless $editMode;
		push @tableCells, CGI::div({class=>$statusClass}, $self->fieldEditHTML($fieldName, $fieldValue, \%properties));
	}
	
	return CGI::Tr({}, CGI::td({}, \@tableCells));
}

sub printTableHTML {
	my ($self, $UsersRef, $PermissionLevelsRef, $fieldNamesRef, %options) = @_;
	my $r                       = $self->r;
	my $userTemplate            = $self->{userTemplate};
	my $permissionLevelTemplate = $self->{permissionLevelTemplate};
	my @Users                   = @$UsersRef;
	my @PermissionLevels        = @$PermissionLevelsRef;
	my %fieldNames              = %$fieldNamesRef;
	
	my $editMode                = $options{editMode};
	my %selectedUserIDs         = map { $_ => 1 } @{ $options{selectedUserIDs} };
	my $currentSort             = $options{currentSort};
	
	# names of headings:
	my @realFieldNames = (
			$userTemplate->KEYFIELDS,
			$userTemplate->NONKEYFIELDS,
			$permissionLevelTemplate->NONKEYFIELDS,
	);
	
	my %sortSubs = %{ SORT_SUBS() };
	#my @stateParams = @{ STATE_PARAMS() };
	#my $hrefPrefix = $r->uri . "?" . $self->url_args(@stateParams); # $self->url_authen_args
	my @tableHeadings;
	foreach my $field (@realFieldNames) {
		my $result = $fieldNames{$field};
		push @tableHeadings, $result;
	};
	
	# prepend selection checkbox? only if we're NOT editing!
	unshift @tableHeadings, "Select", "Act As" unless $editMode;
	
	# print the table
	if ($editMode) {
		print CGI::start_table({});
	} else {
		print CGI::start_table({-border=>1});
	}
	
	print CGI::Tr({}, CGI::th({}, \@tableHeadings));
	

	for (my $i = 0; $i < @Users; $i++) {
		my $User = $Users[$i];
		my $PermissionLevel = $PermissionLevels[$i];
		
		print $self->recordEditHTML($User, $PermissionLevel,
			editMode => $editMode,
			userSelected => exists $selectedUserIDs{$User->user_id}
		);
	}
	
	print CGI::end_table();
    #########################################
	# if there are no users shown print message
	# 
	##########################################
	
	print CGI::p(
	              CGI::i("No students shown.  Choose one of the options above to 
	              list the students in the course.")
	) unless @Users;
}

1;

