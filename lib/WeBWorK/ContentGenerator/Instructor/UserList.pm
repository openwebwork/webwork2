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

use strict;
use warnings;
use CGI qw();

use constant HIDE_USERS_THRESHHOLD => 20;

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
		my @userList = $db->listUsers;
		foreach my $user (@userList) {
			my $userRecord = $db->getUser($user);
			my $permissionLevelRecord = $db->getPermissionLevel($user);
			foreach my $field ($userRecord->NONKEYFIELDS()) {
				my $paramName = "user.${user}.${field}";
				if (defined($r->param($paramName))) {
					$userRecord->$field($r->param($paramName));
				}
			}
			foreach my $field ($permissionLevelRecord->NONKEYFIELDS()) {
				my $paramName = "permission.${user}.${field}";
				if (defined($r->param($paramName))) {
					$permissionLevelRecord->$field($r->param($paramName));
				}
			}
			$db->putUser($userRecord);
			$db->putPermissionLevel($permissionLevelRecord);
		}
	} elsif (defined($r->param('delete_selected'))) {
		foreach my $userID ($r->param('selectUser')) {
			$db->deleteUser($userID);
		}
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
	
	return CGI::em("You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	my $userTemplate = $db->newUser;
	my $permissionLevelTemplate = $db->newPermissionLevel;
	
	my $editMode = 0;
	if (defined $r->param("edit_selected") or defined $r->param("edit_visible")) {
		$editMode = 1;
	}
	
	# This table can be consulted when display-ready forms of field names are needed.
	my %prettyFieldNames = map { $_ => $_ } (
		$userTemplate->FIELDS(), $permissionLevelTemplate->FIELDS());
	
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
	
	my %fieldProperties = (
		user_id => {
			type => "text",
			size => 8,
			access => "readonly",
		},
		first_name => {
			type => "text",
			size => 10,
			access => $editMode ? "readwrite" : "readonly",
		},
		last_name => {
			type => "text",
			size => 10,
			access => $editMode ? "readwrite" : "readonly",
		},
		email_address => {
			type => "text",
			size => 20,
			access => $editMode ? "readwrite" : "readonly",
		},
		student_id => {
			type => "text",
			size => 11,
			access => $editMode ? "readwrite" : "readonly",
		},
		status => {
			type => "enumerable",
			size => 4,
			access => $editMode ? "readwrite" : "readonly",
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
			access => $editMode ? "readwrite" : "readonly",
		},
		recitation => {
			type => "text",
			size => 4,
			access => $editMode ? "readwrite" : "readonly",
		},
		comment => {
			type => "text",
			size => 20,
			access => $editMode ? "readwrite" : "readonly",
		},
		permission => {
			type => "number",
			size => 2,
			access => $editMode ? "readwrite" : "readonly",
		}
	);
	
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
	
	# filter options
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
}

1;
