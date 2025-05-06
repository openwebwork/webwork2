package WeBWorK::ContentGenerator::Instructor::AchievementUserEditor;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::AchievementUserEditor - List and edit the
users assigned to an achievement.

=cut

sub initialize ($c) {
	my $authz         = $c->authz;
	my $db            = $c->db;
	my $achievementID = $c->stash('achievementID');
	my $user          = $c->param('user');

	# Make sure this is defined for the template.
	$c->stash->{userRecords} = [];

	# Check permissions
	return unless $authz->hasPermissions($user, 'edit_achievements');

	my @all_users     = $db->listUsers;
	my %selectedUsers = map { $_ => 1 } $c->param('selected');

	my $doAssignToSelected = 0;

	#Check and see if we need to assign or unassign things
	if (defined $c->param('assignToAll')) {
		$c->addgoodmessage($c->maketext('Achievement has been assigned to all users.'));
		%selectedUsers      = map { $_ => 1 } @all_users;
		$doAssignToSelected = 1;
	} elsif (defined $c->param('unassignFromAll')
		&& defined($c->param('unassignFromAllSafety'))
		&& $c->param('unassignFromAllSafety') == 1)
	{
		%selectedUsers = ();
		$c->addbadmessage($c->maketext('Achievement has been unassigned to all students.'));
		$doAssignToSelected = 1;
	} elsif (defined $c->param('assignToSelected')) {
		$c->addgoodmessage($c->maketext('Achievement has been assigned to selected users.'));
		$doAssignToSelected = 1;
	} elsif (defined $c->param('unassignFromAll')) {
		# no action taken
		$c->addbadmessage($c->maketext('No action taken'));
	}

	#do actual assignment and unassignment
	if ($doAssignToSelected) {

		my %achievementUsers = map { $_ => 1 } $db->listAchievementUsers($achievementID);
		foreach my $selectedUser (@all_users) {
			if (exists $selectedUsers{$selectedUser} && $achievementUsers{$selectedUser}) {
				# update existing user data (in case fields were changed)
				my $userAchievement = $db->getUserAchievement($selectedUser, $achievementID);

				my $updatedEarned = $c->param("$selectedUser.earned") ? 1 : 0;
				my $earned        = $userAchievement->earned          ? 1 : 0;
				if ($updatedEarned != $earned) {

					$userAchievement->earned($updatedEarned);
					my $globalUserAchievement = $db->getGlobalUserAchievement($selectedUser);
					my $achievement           = $db->getAchievement($achievementID);

					my $points        = $achievement->points                       || 0;
					my $initialpoints = $globalUserAchievement->achievement_points || 0;
					#add the correct number of points if we
					# are saying that the user now earned the
					# achievement, or remove them otherwise
					if ($updatedEarned) {

						$globalUserAchievement->achievement_points($initialpoints + $points);
					} else {
						$globalUserAchievement->achievement_points($initialpoints - $points);
					}

					$db->putGlobalUserAchievement($globalUserAchievement);
				}

				$userAchievement->counter($c->param("$selectedUser.counter"));
				$db->putUserAchievement($userAchievement);

			} elsif (exists $selectedUsers{$selectedUser}) {
				# add users that dont exist
				my $userAchievement = $db->newUserAchievement();
				$userAchievement->user_id($selectedUser);
				$userAchievement->achievement_id($achievementID);
				$db->addUserAchievement($userAchievement);

				#If they dont have global achievement data, then add that too
				if (not $db->existsGlobalUserAchievement($selectedUser)) {
					my $globalUserAchievement = $db->newGlobalUserAchievement();
					$globalUserAchievement->user_id($selectedUser);
					$db->addGlobalUserAchievement($globalUserAchievement);
				}

			} else {
				# delete users who are not selected
				# but dont delete users who dont exist
				next unless $achievementUsers{$selectedUser};
				$db->deleteUserAchievement($selectedUser, $achievementID);
			}
		}
	}

	my @userRecords;
	for my $currentUser (@all_users) {
		my $userObj = $c->db->getUser($currentUser);
		die "Unable to find user object for $currentUser. " unless $userObj;
		push(@userRecords, $userObj);
	}
	@userRecords =
		sort { (lc($a->section) cmp lc($b->section)) || (lc($a->last_name) cmp lc($b->last_name)) } @userRecords;

	$c->stash->{userRecords} = \@userRecords;

	return;
}

1;
