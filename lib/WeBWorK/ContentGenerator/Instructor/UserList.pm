################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UserList - Entry point for User-specific
data editing

=cut

=for comment

What do we want to be able to do here?

Filter what users are shown:
	- all, selected
	- matching user_id, matching section, matching recitation
Switch from view mode to edit mode:
	- showing visible users
	- showing selected users
Switch from edit mode to view and save changes
Switch from edit mode to view and abandon changes
	- showing visible users
	- showing selected users
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

use Mojo::File;

use WeBWorK::File::Classlist qw(parse_classlist write_classlist);
use WeBWorK::Utils           qw(cryptPassword x);

use constant HIDE_USERS_THRESHHOLD => 200;
use constant EDIT_FORMS            => [qw(save_edit cancel_edit)];
use constant VIEW_FORMS            => [qw(filter sort edit import export add delete reset_2fa)];

# Prepare the tab titles for translation by maketext
use constant FORM_TITLES => {
	save_edit   => x('Save Edit'),
	cancel_edit => x('Cancel Edit'),
	filter      => x('Filter'),
	sort        => x('Sort'),
	edit        => x('Edit'),
	import      => x('Import'),
	export      => x('Export'),
	add         => x('Add'),
	delete      => x('Delete'),
	reset_2fa   => x('Reset Two Factor Authentication')
};

# permissions needed to perform a given action
use constant FORM_PERMS => {
	save_edit  => 'modify_student_data',
	edit       => 'modify_student_data',
	reset2_2fa => 'change_password',
	import     => 'modify_student_data',
	export     => 'modify_classlist_files',
	add        => 'modify_student_data',
	delete     => 'modify_student_data',
};

use constant SORT_SUBS => {
	user_id       => { ASC => \&byUserID,       DESC => \&byDescUserID },
	first_name    => { ASC => \&byFirstName,    DESC => \&byDescFirstName },
	last_name     => { ASC => \&byLastName,     DESC => \&byDescLastName },
	email_address => { ASC => \&byEmailAddress, DESC => \&byDescEmailAddress },
	student_id    => { ASC => \&byStudentID,    DESC => \&byDescStudentID },
	status        => { ASC => \&byStatus,       DESC => \&byDescStatus },
	section       => { ASC => \&bySection,      DESC => \&byDescSection },
	recitation    => { ASC => \&byRecitation,   DESC => \&byDescRecitation },
	comment       => { ASC => \&byComment,      DESC => \&byDescComment },
	permission    => { ASC => \&byPermission,   DESC => \&byDescPermission }
};

use constant FIELDS => [
	'user_id', 'first_name', 'last_name', 'email_address', 'student_id', 'status',
	'section', 'recitation', 'comment',   'permission',    'password'
];

# Note that only the editable fields need a type (i.e. all but user_id),
# and only the text fields need a size.
use constant FIELD_PROPERTIES => {
	user_id       => { name => x('Login Name') },
	first_name    => { name => x('First Name'),        type => 'text', size => 10 },
	last_name     => { name => x('Last Name'),         type => 'text', size => 10 },
	email_address => { name => x('Email Address'),     type => 'text', size => 20 },
	student_id    => { name => x('Student ID'),        type => 'text', size => 11 },
	status        => { name => x('Enrollment Status'), type => 'status' },
	section       => { name => x('Section'),           type => 'text', size => 3 },
	recitation    => { name => x('Recitation'),        type => 'text', size => 3 },
	comment       => { name => x('Comment'),           type => 'text', size => 20 },
	permission    => { name => x('Permission Level'),  type => 'permission' },
	password      => { name => x('Password'),          type => 'password' },
};

sub pre_header_initialize ($c) {
	my $authz = $c->authz;
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $user  = $c->param('user');

	return unless $authz->hasPermissions($user, 'access_instructor_tools');

	$c->{editMode} = $c->param('editMode') || 0;

	return if $c->{editMode} && !$authz->hasPermissions($user, 'modify_student_data');

	if (defined $c->param('action') && $c->param('action') eq 'add') {
		# Redirect to the addUser page
		$c->reply_with_redirect($c->systemLink(
			$c->url_for('instructor_add_users'),
			params => { number_of_students => $c->param('number_of_students') // 1 }
		));
		return;
	}

	# Get a list of all users except set-level proctors from the database.
	my @allUsersDB = $db->getUsersWhere({ user_id => { not_like => 'set_id:%' } });

	my %permissionLevels =
		map { $_->user_id => $_->permission } $db->getPermissionLevelsWhere({ user_id => { not_like => 'set_id:%' } });

	my %passwordExists =
		map { $_->user_id => defined $_->password } $db->getPasswordsWhere({ user_id => { not_like => 'set_id:%' } });

	# Add permission level and a password exists field to the user record hash.
	for my $user (@allUsersDB) {
		unless (defined $permissionLevels{ $user->user_id }) {
			# Uh oh! No permission level record found!
			$c->addbadmessage($c->maketext('Added missing permission level for user [_1].', $user->user_id));

			# Create a new permission level record.
			my $permissionRecord = $db->newPermissionLevel;
			$permissionRecord->user_id($user->user_id);
			$permissionRecord->permission(0);

			# Add it to the database.
			$db->addPermissionLevel($permissionRecord);

			$permissionLevels{ $user->user_id } = 0;
		}

		$user->{permission}     = $permissionLevels{ $user->user_id };
		$user->{passwordExists} = $passwordExists{ $user->user_id };
	}

	my %allUsers = map { $_->user_id => $_ } @allUsersDB;
	$c->{userPermission} = $allUsers{$user}{permission};

	# Get the number of sets in the course for use in the "assigned sets" links.
	$c->{totalSets}  = $db->countGlobalSets;
	$c->{allUserIDs} = [ keys %allUsers ];
	$c->{allUsers}   = \%allUsers;

	if (defined $c->param('visible_users')) {
		$c->{visibleUserIDs} = { map { $_ => 1 } @{ $c->every_param('visible_users') } };
	} elsif (@allUsersDB > HIDE_USERS_THRESHHOLD || defined $c->param('no_visible_users')) {
		$c->{visibleUserIDs} = {};
	} else {
		$c->{visibleUserIDs} = { map { $_ => 1 } @{ $c->{allUserIDs} } };
	}
	$c->{prevVisibleUserIDs} = $c->{visibleUserIDs};

	if (defined $c->param('selected_users')) {
		$c->{selectedUserIDs} = { map { $_ => 1 } @{ $c->every_param('selected_users') } };
	} else {
		$c->{selectedUserIDs} = {};
	}

	$c->{userIsEditable} =
		{ map { $allUsers{$_}{permission} > $c->{userPermission} ? () : ($_ => 1) } (keys %allUsers) };

	# Always have a definite sort order.
	$c->{primarySortField}   = $c->param('primarySortField')   || 'last_name';
	$c->{primarySortOrder}   = $c->param('primarySortOrder')   || 'ASC';
	$c->{secondarySortField} = $c->param('secondarySortField') || 'first_name';
	$c->{secondarySortOrder} = $c->param('secondarySortOrder') || 'ASC';
	$c->{ternarySortField}   = $c->param('ternarySortField')   || 'student_id';
	$c->{ternarySortOrder}   = $c->param('ternarySortOrder')   || 'ASC';

	my $actionID = $c->param('action');
	if ($actionID) {
		unless (grep { $_ eq $actionID } @{ VIEW_FORMS() }, @{ EDIT_FORMS() }) {
			die $c->maketext('Action [_1] not found', $actionID);
		}
		if (!FORM_PERMS()->{$actionID} || $authz->hasPermissions($user, FORM_PERMS()->{$actionID})) {
			# Call the action handler
			my $actionHandler = "${actionID}_handler";
			$c->addgoodmessage($c->$actionHandler);
		} else {
			$c->addbadmessage($c->maketext('You are not authorized to perform this action.'));
		}
	}

	# Sort all users
	my $primarySortSub   = SORT_SUBS()->{ $c->{primarySortField} }{ $c->{primarySortOrder} };
	my $secondarySortSub = SORT_SUBS()->{ $c->{secondarySortField} }{ $c->{secondarySortOrder} };
	my $ternarySortSub   = SORT_SUBS()->{ $c->{ternarySortField} }{ $c->{ternarySortOrder} };

	$c->{allUserIDs} = [ keys %allUsers ];

	# Always have a definite sort order in case the first three sorts don't determine things.
	$c->{sortedUserIDs} = [
		map { $_->user_id }
		sort {
			$primarySortSub->()
				|| $secondarySortSub->()
				|| $ternarySortSub->()
				|| byLastName()
				|| byFirstName()
				|| byUserID()
		}
		grep { $c->{visibleUserIDs}{ $_->user_id } } (values %allUsers)
	];

	return;
}

sub initialize ($c) {
	# Make sure these are defined for the template.
	# This is done here as it needs to occur after the action handler has been executed.
	$c->stash->{formsToShow}     = $c->{editMode} ? EDIT_FORMS() : VIEW_FORMS();
	$c->stash->{formTitles}      = FORM_TITLES();
	$c->stash->{formPerms}       = FORM_PERMS();
	$c->stash->{fields}          = FIELDS();
	$c->stash->{fieldProperties} = FIELD_PROPERTIES();
	$c->stash->{CSVList} =
		$c->{editMode}
		? []
		: Mojo::File->new($c->ce->{courseDirs}{templates})->list->grep(sub { -f && m/\.lst$/ })->map('basename');

	return;
}

# Action handlers

# This action handler modifies the "visibleUserIDs" field based on the contents
# of the "action.filter.scope" parameter and the "selected_users".
sub filter_handler ($c) {
	my $ce = $c->ce;

	my $result;

	my $scope = $c->param('action.filter.scope');
	if ($scope eq 'all') {
		$result = $c->maketext('Showing all users.');
		$c->{visibleUserIDs} = { map { $_ => 1 } @{ $c->{allUserIDs} } };
	} elsif ($scope eq 'selected') {
		$result = $c->maketext('Showing selected users.');
		$c->{visibleUserIDs} = $c->{selectedUserIDs};
	} elsif ($scope eq 'match_regex') {
		$result = $c->maketext('Showing matching users.');
		my $regex    = $c->param('action.filter.user_ids');
		my $field    = $c->param('action.filter.field');
		my %allUsers = %{ $c->{allUsers} };
		my @matchingUserIDs;
		my %permissionLabels = reverse %{ $ce->{userRoles} };
		for my $userID (@{ $c->{allUserIDs} }) {
			if ($field eq 'permission') {
				push @matchingUserIDs, $userID
					if $permissionLabels{ $allUsers{$userID}{permission} } =~ /^$regex/i
					|| $c->maketext($permissionLabels{ $allUsers{$userID}{permission} }) =~ /^$regex/i;
			} elsif ($field eq 'status') {
				push @matchingUserIDs, $userID
					if $ce->status_abbrev_to_name($allUsers{$userID}{status}) =~ /^$regex/i
					|| $c->maketext($ce->status_abbrev_to_name($allUsers{$userID}{status})) =~ /^$regex/i;
			} else {
				push @matchingUserIDs, $userID if $allUsers{$userID}{$field} =~ /^$regex/i;
			}
		}
		$c->{visibleUserIDs} = { map { $_ => 1 } @matchingUserIDs };
	}

	return $result;
}

sub sort_handler ($c) {
	if (defined $c->param('labelSortMethod') || defined $c->param('labelSortOrder')) {
		if (defined $c->param('labelSortOrder')) {
			$c->{ $c->param('labelSortOrder') . 'SortOrder' } =
				$c->{ $c->param('labelSortOrder') . 'SortOrder' } eq 'ASC' ? 'DESC' : 'ASC';
		} elsif ($c->param('labelSortMethod') eq $c->{primarySortField}) {
			$c->{primarySortOrder} = $c->{primarySortOrder} eq 'ASC' ? 'DESC' : 'ASC';
		} else {
			$c->{ternarySortField}   = $c->{secondarySortField};
			$c->{ternarySortOrder}   = $c->{secondarySortOrder};
			$c->{secondarySortField} = $c->{primarySortField};
			$c->{secondarySortOrder} = $c->{primarySortOrder};
			$c->{primarySortField}   = $c->param('labelSortMethod');
			$c->{primarySortOrder}   = 'ASC';
		}

		$c->param('action.sort.primary',         $c->{primarySortField});
		$c->param('action.sort.primary.order',   $c->{primarySortOrder});
		$c->param('action.sort.secondary',       $c->{secondarySortField});
		$c->param('action.sort.secondary.order', $c->{secondarySortOrder});
		$c->param('action.sort.ternary',         $c->{ternarySortField});
		$c->param('action.sort.ternary.order',   $c->{ternarySortOrder});
	} else {
		$c->{primarySortField}   = $c->param('action.sort.primary');
		$c->{primarySortOrder}   = $c->param('action.sort.primary.order');
		$c->{secondarySortField} = $c->param('action.sort.secondary');
		$c->{secondarySortOrder} = $c->param('action.sort.secondary.order');
		$c->{ternarySortField}   = $c->param('action.sort.ternary');
		$c->{ternarySortOrder}   = $c->param('action.sort.ternary.order');
	}

	return $c->maketext(
		'Sets sorted by [_1] in [plural,_2,ascending,descending] order, '
			. 'then by [_3] in [plural,_4,ascending,descending] order,'
			. 'and then by [_5] in [plural,_6,ascending,descending] order.',
		$c->maketext(FIELD_PROPERTIES()->{ $c->{primarySortField} }{name}),
		$c->{primarySortOrder} eq 'ASC' ? 1 : 2,
		$c->maketext(FIELD_PROPERTIES()->{ $c->{secondarySortField} }{name}),
		$c->{secondarySortOrder} eq 'ASC' ? 1 : 2,
		$c->maketext(FIELD_PROPERTIES()->{ $c->{ternarySortField} }{name}),
		$c->{ternarySortOrder} eq 'ASC' ? 1 : 2
	);
}

sub edit_handler ($c) {
	my $scope = $c->param('action.edit.scope');
	my @usersToEdit =
		grep { $c->{userIsEditable}{$_} } ($scope eq 'all' ? @{ $c->{allUserIDs} } : (keys %{ $c->{selectedUserIDs} }));
	$c->{visibleUserIDs} = { map { $_ => 1 } @usersToEdit };
	$c->{editMode}       = 1;

	return $scope eq 'all' ? $c->maketext('Editing all users.') : $c->maketext('Editing selected users.');
}

sub delete_handler ($c) {
	my $db      = $c->db;
	my $user    = $c->param('user');
	my $confirm = $c->param('action.delete.confirm');
	my $num     = 0;

	return $c->maketext('Deleted [_1] users.', $num) unless ($confirm eq 'yes');

	# grep on userIsEditable would still enforce permissions, but no UI feedback
	my @userIDsToDelete = keys %{ $c->{selectedUserIDs} };

	my @resultText;
	foreach my $userID (@userIDsToDelete) {
		if ($userID eq $user) {
			push @resultText, $c->maketext('You cannot delete yourself!');
			next;
		}

		unless ($c->{userIsEditable}{$userID}) {
			push @resultText, $c->maketext('You are not allowed to delete [_1].', $userID);
			next;
		}
		delete $c->{allUsers}{$userID};
		delete $c->{visibleUserIDs}{$userID};
		delete $c->{selectedUserIDs}{$userID};
		delete $c->{userIsEditable}{$userID};
		$db->deleteUser($userID);
		$num++;
	}

	unshift @resultText, $c->maketext('Deleted [_1] users.', $num);
	return join(' ', @resultText);
}

sub add_handler ($c) {
	# This action is redirected to the AddUsers.pm module using ../instructor/add_user/...
	return '';
}

sub import_handler ($c) {
	my $fileName = $c->param('action.import.source');
	my $replace  = $c->param('action.import.replace');

	unless (defined($fileName) and $fileName =~ /\.lst$/) {
		$c->addbadmessage($c->maketext('No class list file provided.'));
		return $c->maketext('No users added.');
	}
	my $replaceExisting;
	my @replaceList;
	if ($replace eq 'any') {
		# even in any mode, do not allow replacement of higher permission users
		$replaceExisting = 'listed';
		@replaceList     = grep { $c->{userIsEditable}{$_} } @{ $c->{allUserIDs} };
	} elsif ($replace eq 'none') {
		$replaceExisting = 'none';
	} elsif ($replace eq 'visible') {
		$replaceExisting = 'listed';
		@replaceList     = grep { $c->{userIsEditable}{$_} } (keys %{ $c->{visibleUserIDs} });
	} elsif ($replace eq 'selected') {
		$replaceExisting = 'listed';
		@replaceList     = grep { $c->{userIsEditable}{$_} } (keys %{ $c->{selectedUserIDs} });
	}

	my ($replaced, $added, $skipped) =
		$c->importUsersFromCSV($fileName, $replaceExisting, $c->param('fallback_password_source'), @replaceList);

	# make new users visible and update records of replaced users
	for (@$added) {
		$c->{allUsers}{ $_->user_id }       = $_;
		$c->{visibleUserIDs}{ $_->user_id } = 1;
		$c->{userIsEditable}{ $_->user_id } = 1;
	}
	for (@$replaced) {
		$c->{allUsers}{ $_->user_id } = $_;
	}

	my $numReplaced = @$replaced;
	my $numAdded    = @$added;
	my $numSkipped  = @$skipped;

	return $c->maketext('[_1] users replaced, [_2] users added, [_3] users skipped. Skipped users: ([_4])',
		$numReplaced, $numAdded, $numSkipped, join(', ', @$skipped));
}

sub export_handler ($c) {
	my $ce  = $c->ce;
	my $dir = $ce->{courseDirs}{templates};

	my $scope  = $c->param('action.export.scope');
	my $target = $c->param('action.export.target');
	my $new    = $c->param('action.export.new');

	#get name of templates directory as it appears in file manager
	$dir =~ s|.*/||;

	my $fileName;
	if ($target eq 'new') {
		$fileName = $new;
	} else {
		$fileName = $target;
	}

	$fileName .= '.lst' unless $fileName =~ m/\.lst$/;

	my @userIDsToExport = $scope eq 'all' ? @{ $c->{allUserIDs} } : keys %{ $c->{selectedUserIDs} };
	$c->exportUsersToCSV($fileName, @userIDsToExport);

	return $c->maketext('[_1] users exported to file [_2]', scalar @userIDsToExport, "$dir/$fileName");
}

sub reset_2fa_handler ($c) {
	my $db   = $c->db;
	my $user = $c->param('user');

	my $confirm = $c->param('action.reset_2fa.confirm');
	my $num     = 0;

	return $c->maketext('Reset two factor authentication for [_1] users.', $num) unless $confirm eq 'yes';

	# grep on userIsEditable would still enforce permissions, but no UI feedback
	my @userIDsForReset = keys %{ $c->{selectedUserIDs} };

	my @resultText;
	for my $userID (@userIDsForReset) {
		if ($userID eq $user) {
			push @resultText, $c->maketext('You cannot reset two factor authentication for yourself!');
			next;
		}

		unless ($c->{userIsEditable}{$userID}) {
			push @resultText, $c->maketext('You are not allowed to reset two factor authenticatio for [_1].', $userID);
			next;
		}
		my $password = $db->getPassword($userID);
		$password->otp_secret('');
		$db->putPassword($password);
		$num++;
	}

	unshift @resultText, $c->maketext('Reset two factor authentication for [quant,_1,user].', $num);
	return join(' ', @resultText);
}

sub cancel_edit_handler ($c) {
	if (defined $c->param('prev_visible_users')) {
		$c->{visibleUserIDs} = { map { $_ => 1 } @{ $c->every_param('prev_visible_users') } };
	} elsif (defined $c->param('no_prev_visible_users')) {
		$c->{visibleUserIDs} = {};
	}
	$c->{editMode} = 0;

	return $c->maketext('Changes abandoned.');
}

sub save_edit_handler ($c) {
	my $db = $c->db;

	my @visibleUserIDs = keys %{ $c->{visibleUserIDs} };
	foreach my $userID (@visibleUserIDs) {
		my $User = $db->getUser($userID);
		die $c->maketext('record for visible user [_1] not found', $userID) unless $User;
		my $PermissionLevel = $db->getPermissionLevel($userID);
		die $c->maketext('permissions for [_1] not defined', $userID) unless defined $PermissionLevel;

		# delete requests for elevated users should never make it this far
		die $c->maketext('insufficient permission to edit [_1]', $userID) unless ($c->{userIsEditable}{$userID});

		for my $field ($User->NONKEYFIELDS()) {
			my $newValue = $c->param("user.$userID.$field");
			$User->$field($newValue) if defined $newValue;
		}
		$db->putUser($User);

		my $newPermissionLevel = $c->param("user.$userID.permission");
		$PermissionLevel->permission($newPermissionLevel)
			if defined $newPermissionLevel && $newPermissionLevel <= $c->{userPermission};
		$db->putPermissionLevel($PermissionLevel);
		$User->{permission} = $PermissionLevel->permission;

		if ($c->param("user.${userID}.password_delete")) {
			# Note that if the user has setup two factor authentication, then this also will delete the otp_secret.
			# Thus if the password is set again later, the user will need to setup two factor authentication again.
			$db->deletePassword($User->user_id) if $db->existsPassword($User->user_id);
		} else {
			my $newPassword = $c->param("user.${userID}.password");
			if ($newPassword && $newPassword =~ /\S/) {
				my $Password      = eval { $db->getPassword($User->user_id) };
				my $cryptPassword = cryptPassword($newPassword);
				if ($Password) {
					# Note that in this case the otp_secret will be preserved. So the user will still be able to use the
					# configured two factor authentication with the new password.
					$Password->password(cryptPassword($newPassword));
					eval { $db->putPassword($Password) };
				} else {
					$Password = $db->newPassword();
					$Password->user_id($userID);
					$Password->password(cryptPassword($newPassword));
					eval { $db->addPassword($Password) };
				}
			}
		}

		$c->{allUsers}{$userID} = $User;
	}

	if (defined $c->param('prev_visible_users')) {
		$c->{visibleUserIDs} = { map { $_ => 1 } @{ $c->every_param('prev_visible_users') } };
	} elsif (defined $c->param('no_prev_visible_users')) {
		$c->{visibleUserIDs} = {};
	}

	$c->{editMode} = 0;

	return $c->maketext('Changes saved.');
}

# Sort methods (ascending)

sub byUserID { return lc $a->user_id cmp lc $b->user_id }

sub byFirstName {
	return (defined $a->first_name && defined $b->first_name) ? lc $a->first_name cmp lc $b->first_name : 0;
}

sub byLastName { return (defined $a->last_name && defined $b->last_name) ? lc $a->last_name cmp lc $b->last_name : 0; }
sub byEmailAddress { return lc $a->email_address cmp lc $b->email_address }
sub byStudentID    { return lc $a->student_id cmp lc $b->student_id }
sub byStatus       { return lc $a->status cmp lc $b->status }
sub bySection      { return lc $a->section cmp lc $b->section }
sub byRecitation   { return lc $a->recitation cmp lc $b->recitation }
sub byComment      { return lc $a->comment cmp lc $b->comment }

# Permission level is added to the user record hash so we can sort by it if necessary.
sub byPermission { return $a->{permission} <=> $b->{permission}; }

# Sort methods (descending)
sub byDescUserID       { local ($b, $a) = ($a, $b); return byUserID() }
sub byDescFirstName    { local ($b, $a) = ($a, $b); return byFirstName() }
sub byDescLastName     { local ($b, $a) = ($a, $b); return byLastName() }
sub byDescEmailAddress { local ($b, $a) = ($a, $b); return byEmailAddress() }
sub byDescStudentID    { local ($b, $a) = ($a, $b); return byStudentID() }
sub byDescStatus       { local ($b, $a) = ($a, $b); return byStatus() }
sub byDescSection      { local ($b, $a) = ($a, $b); return bySection() }
sub byDescRecitation   { local ($b, $a) = ($a, $b); return byRecitation() }
sub byDescComment      { local ($b, $a) = ($a, $b); return byC mment() }
sub byDescPermission   { local ($b, $a) = ($a, $b); return byPermission() }

# Utilities

# generate labels for section/recitation popup menus
sub menuLabels ($c, $hashRef) {
	my %hash = %$hashRef;

	my %result;
	foreach my $key (keys %hash) {
		my $count      = @{ $hash{$key} };
		my $displayKey = $key || '<none>';
		$result{$key} = "$displayKey ($count users)";
	}
	return %result;
}

sub importUsersFromCSV ($c, $fileName, $replaceExisting, $fallbackPasswordSource, @replaceList) {
	my $ce   = $c->ce;
	my $db   = $c->db;
	my $dir  = $ce->{courseDirs}{templates};
	my $user = $c->param('user');
	my $perm = $c->{userPermission};

	die $c->maketext("Illegal '/' character in input.") if $fileName =~ m|/|;
	die $c->maketext("File [_1]/[_2] either does not exist or is not readable.", $dir, $fileName)
		unless -r "$dir/$fileName";

	my %allUserIDs = map { $_ => 1 } @{ $c->{allUserIDs} };

	my %replaceOK;
	if ($replaceExisting eq 'none') {
		%replaceOK = ();
	} elsif ($replaceExisting eq 'listed') {
		%replaceOK = map { $_ => 1 } @replaceList;
	} elsif ($replaceExisting eq 'any') {
		%replaceOK = %allUserIDs;
	}

	my $default_permission_level = $ce->{default_permission_level};

	my (@replaced, @added, @skipped);

	# get list of hashrefs representing lines in classlist file
	my @classlist = parse_classlist("$dir/$fileName");

	# Default status is enrolled -- fetch abbreviation for enrolled
	my $default_status_abbrev = $ce->{statuses}{Enrolled}{abbrevs}[0];

	foreach my $record (@classlist) {
		my %record  = %$record;
		my $user_id = $record{user_id};

		unless (WeBWorK::DB::check_user_id($user_id)) {    # try to catch lines with bad characters
			push @skipped, $user_id;
			next;
		}
		if ($user_id eq $user) {                           # don't replace yourself!!
			push @skipped, $user_id;
			next;
		}
		if ($record{permission} && $perm < $record{permission}) {
			push @skipped, $user_id;
			next;
		}

		if (exists $allUserIDs{$user_id} && !exists $replaceOK{$user_id}) {
			push @skipped, $user_id;
			next;
		}

		# set default status is status field is "empty"
		$record{status} = $default_status_abbrev
			unless defined $record{status} and $record{status} ne "";

		# Determine what to use for the password (if anything).
		if (!$record{password}) {
			if (defined $record{unencrypted_password} && $record{unencrypted_password} =~ /\S/) {
				$record{password} = cryptPassword($record{unencrypted_password});
			} elsif ($fallbackPasswordSource
				&& $record{$fallbackPasswordSource}
				&& $record{$fallbackPasswordSource} =~ /\S/)
			{
				$record{password} = cryptPassword($record{$fallbackPasswordSource});
			}
		}

		# set default permission level if permission level is "empty"
		$record{permission} = $default_permission_level
			unless defined $record{permission} and $record{permission} ne "";

		my $User            = $db->newUser(%record);
		my $PermissionLevel = $db->newPermissionLevel(user_id => $user_id, permission => $record{permission});
		my $Password = $record{password} ? $db->newPassword(user_id => $user_id, password => $record{password}) : undef;

		# DBFIXME use REPLACE
		if (exists $allUserIDs{$user_id}) {
			$db->putUser($User);
			$db->putPermissionLevel($PermissionLevel);
			$db->putPassword($Password) if $Password;
			$User->{permission}     = $PermissionLevel->permission;
			$User->{passwordExists} = 1 if $Password;
			push @replaced, $User;
		} else {
			$allUserIDs{$user_id} = 1;
			$db->addUser($User);
			$db->addPermissionLevel($PermissionLevel);
			$db->addPassword($Password) if $Password;
			$User->{permission}     = $PermissionLevel->permission;
			$User->{passwordExists} = 1 if $Password;
			push @added, $User;
		}
	}

	return \@replaced, \@added, \@skipped;
}

sub exportUsersToCSV ($c, $fileName, @userIDsToExport) {
	my $ce = $c->ce;
	my $db = $c->db;

	die $c->maketext(q{illegal character in input: '/'}) if $fileName =~ m|/|;

	my @records;

	my @users            = $db->getUsers(@userIDsToExport);
	my %passwords        = map { $_->user_id => $_ } $db->getPasswords(@userIDsToExport);
	my %permissionLevels = map { $_->user_id => $_ } $db->getPermissionLevels(@userIDsToExport);

	for my $user (@users) {
		my $password        = $passwords{ $user->user_id };
		my $permissionLevel = $permissionLevels{ $user->user_id };
		my %record          = (
			defined $permissionLevel ? $permissionLevel->toHash : (),
			defined $password        ? $password->toHash        : (),
			$user->toHash,
		);
		push @records, \%record;
	}

	write_classlist("$ce->{courseDirs}{templates}/$fileName", @records);

	return;
}

1;
