################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
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
		- client

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readFile readDirectory);

use constant HIDE_USERS_THRESHHOLD => 20;
use constant EDIT_FORMS => [qw(cancelEdit saveEdit)];
use constant VIEW_FORMS => [qw(filter edit delete import export)];
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

sub initialize {
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $user = $r->param('user');

	unless ($authz->hasPermissions($user, "modify_student_data")) {
		$self->{submitError} = "You are not authorized to modify student data";
		return;
	}
	
	if (defined($r->param('save_classlist'))) {
	} elsif (defined($r->param('delete_selected'))) {
	} elsif (defined($r->param('addStudent'))) {
		my $newUser = $db->newUser;
		my $newPermissionLevel = $db->newPermissionLevel;
		my $newPassword = $db->newPassword;
		$newUser->user_id($r->param('newUserID'));
		$newPermissionLevel->user_id($r->param('newUserID'));
		$newPassword->user_id($r->param('newUserID'));
		$newUser->status('C');
		$newPermissionLevel->permission(0);
		$db->addUser($newUser);
		$db->addPermissionLevel($newPermissionLevel);
		$db->addPassword($newPassword);
	}
}

sub title {
	my $self = shift;
	return "User List";
}

sub path {
	my $self = shift;
	my $args = $_[-1];
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
	return $self->pathMacro($args,
		"Home"              => "$root",
		$courseName         => "$root/$courseName",
		"Instructor Tools"  => "$root/$courseName/instructor",
		"User List"         => "",
	);
}

sub body {
	my ($self, $setID) = @_;
	my $r = $self->{r};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
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
		"User ID", 
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
			"Result of last action performed: ",
			CGI::i($self->$actionHandler(\%genericParams, \%actionParams, \%tableParams))
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
	
	my @Users = @visibleUserIDs ? $db->getUsers(@visibleUserIDs) : ();
	
	# presort users
	my %sortSubs = %{ SORT_SUBS() };
	my $sortSub = $sortSubs{$sortField};
	#@Users = sort $sortSub @Users;
	@Users = sort byLnFnUid @Users;
		
	my @PermissionLevels;
	
	for (my $i = 0; $i < @Users; $i++) {
		my $User = $Users[$i];
		my $PermissionLevel = $db->getPermissionLevel($User->user_id);
		
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
	
	print CGI::start_form({method=>"post", action=>$r->uri, name=>"userlist"});
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
	return join("",
		"Show ",
		CGI::popup_menu(
			-name => "action.filter.scope",
			-values => [qw(all none selected)],
			-default => $actionParams{"action.filter.scope"}->[0] || "selected",
			-labels => {
				all => "all users",
				none => "no users",
				selected => "selected users"
			},
			-onchange => $onChange,
		),
	);
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
			-default => $actionParams{"action.edit.scope"}->[0] || "visible",
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
		"Delete ",
		CGI::popup_menu(
			-name => "action.delete.scope",
			-values => [qw(visible selected)],
			-default => $actionParams{"action.delete.scope"}->[0] || "selected",
			-labels => {
				visible => "visible users",
				selected => "selected users"
			},
			-onchange => $onChange,
		),
		CGI::em(" Deletion destroys all user-related data and is not undoable!"),
	);
}

sub delete_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $db = $self->{db};
	my $scope = $actionParams->{"action.delete.scope"}->[0];
	
	my @userIDsToDelete;
	if ($scope eq "visible") {
		@userIDsToDelete = @{ $self->{visibleUserIDs} };
	} elsif ($scope eq "selected") {
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
	my $r = $self->{r};
	
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
	my $r = $self->{r};
	my $db = $self->{db};
	
	my @visibleUserIDs = @{ $self->{visibleUserIDs} };
	foreach my $userID (@visibleUserIDs) {
		my $User = $db->getUser($userID);
		my $PermissionLevel = $db->getPermissionLevel($userID);
		
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

sub getCSVList {
	my ($self) = @_;
	my $ce = $self->{ce};
	my $dir = $ce->{courseDirs}->{templates};
	return grep { not m/^\./ and m/\.lst$/ and -f "$dir/$_" } readDirectory($dir);
}

sub importUsersFromCSV {
	my ($self, $fileName, $createNew, $replaceExisting, @replaceList) = @_;
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $dir = $ce->{courseDirs}->{templates};
	
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
		$Password->password($student_id);
		
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
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $dir = $ce->{courseDirs}->{templates};
		
	die "illegal character in input: \"/\"" if $fileName =~ m|/|;
	
	open my $fh, ">", "$dir/$fileName"
		or die "failed to open file $dir/$fileName for writing: $!\n";
	
	foreach my $userID (@userIDsToExport) {
		my $User = $db->getUser($userID);
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
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
	my $editMode = $options{editMode};
	my $userSelected = $options{userSelected};
	
	my $changeEUserURL = "$root/$courseName?"
		. "user="           . $r->param("user")
		. "&effectiveUser=" . $User->user_id
		. "&key="           . $r->param("key");
	
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
	
	# User ID
	if ($editMode) {
		# straight user ID
		push @tableCells, $User->user_id;
	} else {
		# "become user" link
		push @tableCells, CGI::a({href=>$changeEUserURL}, $User->user_id);
	}
	
	# User Fields
	foreach my $field ($User->NONKEYFIELDS) {
		my $fieldName = "user." . $User->user_id . "." . $field,
		my $fieldValue = $User->$field;
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = "readonly" unless $editMode;
		push @tableCells, $self->fieldEditHTML($fieldName, $fieldValue, \%properties);
	}
	
	# PermissionLevel Fields
	foreach my $field ($PermissionLevel->NONKEYFIELDS) {
		my $fieldName = "permission." . $PermissionLevel->user_id . "." . $field,
		my $fieldValue = $PermissionLevel->$field;
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = "readonly" unless $editMode;
		push @tableCells, $self->fieldEditHTML($fieldName, $fieldValue, \%properties);
	}
	
	return CGI::Tr({}, CGI::td({}, \@tableCells));
}

sub printTableHTML {
	my ($self, $UsersRef, $PermissionLevelsRef, $fieldNamesRef, %options) = @_;
	my $r = $self->{r};
	my $userTemplate = $self->{userTemplate};
	my $permissionLevelTemplate = $self->{permissionLevelTemplate};
	my @Users = @$UsersRef;
	my @PermissionLevels = @$PermissionLevelsRef;
	my %fieldNames = %$fieldNamesRef;
	
	my $editMode = $options{editMode};
	my %selectedUserIDs = map { $_ => 1 } @{ $options{selectedUserIDs} };
	my $currentSort = $options{currentSort};
	
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
		my $result;
		#if (exists $sortSubs{$field}) {
		#	$result = CGI::a({-href=>"$hrefPrefix&sort=$field"}, $fieldNames{$field});
		#} else {
			$result = $fieldNames{$field};
		#}
		push @tableHeadings, $result;
	};
	
	# prepend selection checkbox? only if we're NOT editing!
	unshift @tableHeadings, "Sel." unless $editMode;
	
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
}

1;

__END__
	
	my $editMode = 0;
	if (defined $r->param("edit_selected") or defined $r->param("edit_visible")) {
		$editMode = 1;
	}
	
	my @userIDs = $db->listUsers;
	my @userRecords = $db->getUsers(@userIDs);
	
	my (%sections, %recitations);
	foreach my $user (@userRecords) {
		push @{$sections{$user->section}}, $user;
		push @{$recitations{$user->recitation}}, $user;
	}
	
	my $filter_type = $r->param("filter_type")
		|| (@userIDs > HIDE_USERS_THRESHHOLD ? "none" : "all");
	my $filter_user_id = $filter_type eq "filter_user_id"
		? $r->param("filter_user_id") || ""
		: "";
	my $filter_section = $filter_type eq "filter_section"
		? $r->param("filter_section") || ""
		: "";
	my $filter_recitation = $filter_type eq "filter_recitation"
		? $r->param("filter_recitation") || ""
		: "";
	
	# override filter selection if "Edit Selected Users" button is pressed
	if (defined $r->param("edit_selected")) {
		$filter_type = "filter_selected";
	}
	
	if ($filter_type eq "none") {
		@userRecords = ();
	} elsif ($filter_type eq "filter_selected") {
		@userRecords = ();
		my @userIDs = $r->param("selectUser");
		if (@userIDs) {
			@userRecords = $db->getUsers(@userIDs);
		}
	} elsif ($filter_type eq "filter_user_id") {
		@userRecords = ();
		if ($filter_user_id ne "") {
			my $userRecord = $db->getUser($filter_user_id);
			@userRecords = ($userRecord) if $userRecord;
		}
	} elsif ($filter_type eq "filter_section") {
		@userRecords = ();
		@userRecords = @{$sections{$filter_section}}
			if exists $sections{$filter_section};
	} elsif ($filter_type eq "filter_recitation") {
		@userRecords = ();
		@userRecords = @{$recitations{$filter_recitation}}
			if exists $recitations{$filter_recitation};
	}
	
	@userRecords = sort {
		(lc $a->section cmp lc $b->section)
			|| (lc $a->last_name cmp lc $b->last_name)
			|| (lc $a->first_name cmp lc $b->first_name)
			|| (lc $a->user_id cmp lc $b->user_id)
	} @userRecords;
	
	print CGI::start_form({method=>"post", action=>$r->uri()});
	print $self->hidden_authen_fields();
	
	filter options
	my %labels = (
		none => "No users",
		all => "All " . scalar @userIDs . " users",
		filter_selected => "Users selected below",
		filter_user_id => "User with ID " . CGI::input({
			type=>"text",
			name=>"filter_user_id",
			value=>$filter_user_id,
			size=>"20"
		}),
		filter_section => "Users in section " . CGI::popup_menu(
			-name=>"filter_section",
			-values=>[ keys %sections ],
			-labels=>{ $self->menuLabels(\%sections) },
			-default=>$filter_section,
		),
		filter_recitation => "Users in recitation " . CGI::popup_menu(
			-name=>"filter_recitation",
			-values=>[ sort keys %recitations ],
			-labels=>{ $self->menuLabels(\%recitations) },
			-default=>$filter_recitation,
		),
	);
	
	if ($editMode) {
		print CGI::hidden(
			-name=>"filter_type",
			-value=>"filter_selected",
		);
	} else {
		my $cgi = new CGI;
		$cgi->autoEscape(0);
		print "Show:", CGI::br();
		print $cgi->radio_group(
			-name=>"filter_type",
			-values=>[ qw(none all filter_selected filter_user_id filter_section filter_recitation) ],
			-default=>$filter_type,
			-linebreak=>"true",
			-labels=>\%labels,
			-rows=>3,
			-columns=>2,
		);
		print CGI::submit({name=>"filter", value=>"Filter"});
	}
	
	print CGI::start_table({});
	
	# Table headings, prettied-up
	my @tableHeadings = (
		($editMode ? () : "Select"),
		map {$prettyFieldNames{$_}} (
			$userTemplate->KEYFIELDS(),
			$userTemplate->NONKEYFIELDS(),
			$permissionLevelTemplate->NONKEYFIELDS(),
		),
	);
	
	# now print them
	print CGI::Tr({},
		CGI::th({}, \@tableHeadings)
	);
	
	my @userIDsForHiddenSelectField;
	
	# process user records
	foreach my $userRecord (@userRecords) {
		my $currentUser = $userRecord->user_id;
		push @userIDsForHiddenSelectField, $currentUser;
		my $permissionLevel = $db->getPermissionLevel($currentUser);
		unless (defined $permissionLevel) {
			warn "No permissionLevel record for user $currentUser -- added";
			my $newPermissionLevel = $db->newPermissionLevel;
			$newPermissionLevel->user_id($currentUser);
			$newPermissionLevel->permission(0);
			$db->addPermissionLevel($newPermissionLevel);
			$permissionLevel = $newPermissionLevel;
 			# permission set to minimum level
		}
		
		# A concise way of printing a row containing a cell for each field, editable unless it's a key
		print CGI::Tr({},
			CGI::td({}, [
				($editMode
					? () # don't show selection checkbox if we're in edit mode -- hidden field below
					#: CGI::input({type=>"checkbox", name=>"selectUser", value=>$currentUser})
					: CGI::checkbox(
						-name=>"selectUser",
						-value=>$currentUser,
						-checked=>($filter_type eq "filter_selected" and not defined $r->param("editingAllVisibleUsers")),
						-label=>""
					)
				),
				($editMode
					? $currentUser
					: (map {
						my $changeEUserURL = "$root/$courseName?"
							. "user=" . $r->param("user")
							. "&effectiveUser=" . $userRecord->user_id
							. "&key=" . $r->param("key");
						CGI::a({href=>$changeEUserURL}, $userRecord->$_)
					} $userRecord->KEYFIELDS)
				),
				(map {
					$self->fieldEditHTML(
						"user." . $userRecord->user_id . "." .$_,
						$userRecord->$_, $fieldProperties{$_});
				} $userRecord->NONKEYFIELDS()), 
				(map {
					$self->fieldEditHTML(
						"permission." . $permissionLevel->user_id . "." . $_,
						$permissionLevel->$_, $fieldProperties{$_});
				} $permissionLevel->NONKEYFIELDS()),
			])
		);
	}
	
	unless (@userRecords) {
		print CGI::Tr({},
			CGI::td({-colspan=>scalar(@tableHeadings), -align=>"center"},
				"No users match the filter criteria above."
			),
		);
	}
	
	print CGI::end_table();
	
	if ($editMode) {
		print CGI::hidden(-name=>"selectUser", -value=>[ @userIDsForHiddenSelectField ]);
		if (defined $r->param("edit_visible")) {
			print CGI::hidden(-name=>"editingAllVisibleUsers", -value=>1);
		}
	}
	
	if ($editMode) {
		print CGI::submit({name=>"discard_chagnes", value=>"Discard Changes to Users"});
		print CGI::submit({name=>"save_classlist", value=>"Save Changes to Users"});
	} else {
		print CGI::submit({name=>"edit_visible", value=>"Edit Visible Users"});
		print CGI::submit({name=>"edit_selected", value=>"Edit Selected Users"});
		print CGI::submit({name=>"delete_selected", value=>"Delete Selected Users"});
	}
	
	print CGI::end_form();
	
	# Add a student form
	unless ($editMode) {
		print CGI::start_form({method=>"post", action=>$r->uri()});
		print $self->hidden_authen_fields();
		print "User ID:";
		print CGI::input({type=>"text", name=>"newUserID", value=>"", size=>"20"});
		print CGI::submit({name=>"addStudent", value=>"Add User"});
		print CGI::end_form();
	}
	
	return "";
