package WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet - List and edit the
users to which sets are assigned.

=cut

use WeBWorK::Debug             qw(debug);
use WeBWorK::Utils::Instructor qw(assignSetToGivenUsers);

sub initialize ($c) {
	my $authz = $c->authz;
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $setID = $c->stash('setID');
	my $user  = $c->param('user');

	# Make sure these are defined for the template.
	$c->stash->{user_records}               = [];
	$c->stash->{current_users}              = {};
	$c->stash->{set_records}                = {};
	$c->stash->{set_record}                 = '';
	$c->stash->{numberCurrentUsers}         = 0;
	$c->stash->{numberAssignedUsers}        = 0;
	$c->stash->{numberAssignedCurrentUsers} = 0;

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	return unless $authz->hasPermissions($user, "assign_problem_sets");

	# Stash set record so template dates are known.
	$c->stash->{set_record} = $db->getGlobalSet($setID);
	return unless $c->stash->{set_record};

	# Get all user records and cache them for later use.
	my @userRecords =
		$db->getUsersWhere({ user_id => { not_like => 'set_id:%' } }, [qw/section last_name first_name/]);
	my %currentUsers =
		map { $ce->status_abbrev_has_behavior($_->status, 'include_in_assignment') ? ($_->user_id => 1) : () }
		@userRecords;
	$c->stash->{user_records}  = \@userRecords;
	$c->stash->{current_users} = \%currentUsers;

	if ($c->param('assignToSelected') || $c->param('assignToAll')) {
		debug("Assigning $setID to selected users.");

		my %selectedUsers = map { $_ => 1 } $c->param('selected');
		my %setUsers      = map { $_ => 1 } $db->listSetUsers($setID);
		my @usersToAdd;
		my @usersToDelete;
		for my $userRecord (@userRecords) {
			my $userID = $userRecord->user_id;
			if (exists $selectedUsers{$userID}) {
				next if $setUsers{$userID};    # Skip users already assigned to the set.
				debug("Saving $userID to be added to set later.");
				push @usersToAdd, $userRecord;
			} else {
				next unless $setUsers{$userID};    # Skip users not assigned to the set.
				debug("Saving $userID to be deleted from set later.");
				push @usersToDelete, $userID;
			}
		}

		if (@usersToAdd) {
			debug("Assigning users to $setID.");
			assignSetToGivenUsers($db, $ce, $setID, 1, @usersToAdd);
			debug('Done assigning users.');
		}

		if (@usersToDelete && $c->param('allow_unassign')) {
			debug("Deleting users from $setID.");
			$db->deleteUserSet($_, $setID) for @usersToDelete;
			debug('Done deleting users.');
		} else {
			# Since no users were deleted, ensure it is empty for messaging.
			@usersToDelete = ();
		}

		debug('Done assigning/unassigning users: '
				. @usersToAdd
				. ' new users assigned and '
				. @usersToDelete
				. ' users unassigned.');
		if (@usersToAdd && @usersToDelete) {
			$c->addgoodmessage($c->maketext(
				'Problems have been assigned to [quant,_1,user,users] and unassigned from [quant,_2,user,users].',
				scalar(@usersToAdd), scalar(@usersToDelete)
			));
		} elsif (@usersToAdd) {
			$c->addgoodmessage(
				$c->maketext('Problems have been assigned to [quant,_1,user,users].', scalar(@usersToAdd)));
		} elsif (@usersToDelete) {
			$c->addgoodmessage(
				$c->maketext('Problems have been unassigned from [quant,_1,user,users].', scalar(@usersToDelete)));
		} else {
			$c->addgoodmessage($c->maketext('No new users to assign or unassign. No action taken.'));
		}
	}

	my %setRecords = map { $_->user_id => $_ } $db->getUserSetsWhere({ set_id => $setID });
	$c->stash->{set_records} = \%setRecords;

	# Count number of current, currently assigned, and total assigned users.
	my $numberAssignedUsers        = 0;
	my $numberAssignedCurrentUsers = 0;
	for (@userRecords) {
		my $userID = $_->user_id;
		if ($setRecords{$userID}) {
			++$numberAssignedUsers;
			++$numberAssignedCurrentUsers if $currentUsers{$userID};
		}
	}
	$c->stash->{numberCurrentUsers}         = scalar(keys %currentUsers);
	$c->stash->{numberAssignedUsers}        = $numberAssignedUsers;
	$c->stash->{numberAssignedCurrentUsers} = $numberAssignedCurrentUsers;

	return;
}

1;
