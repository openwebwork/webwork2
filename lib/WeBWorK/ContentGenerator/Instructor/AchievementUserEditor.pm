package WeBWorK::ContentGenerator::Instructor::AchievementUserEditor;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::AchievementUserEditor - List and edit the
users assigned to an achievement.

=cut

sub initialize ($c) {
	my $authz         = $c->authz;
	my $ce            = $c->ce;
	my $db            = $c->db;
	my $achievementID = $c->stash('achievementID');
	my $user          = $c->authen->{user_id};

	# Make sure these are defined for the template.
	$c->stash->{userRecords}                = [];
	$c->stash->{userAchievementRecords}     = {};
	$c->stash->{currentUsers}               = {};
	$c->stash->{numberCurrentUsers}         = 0;
	$c->stash->{numberAssignedUsers}        = 0;
	$c->stash->{numberAssignedCurrentUsers} = 0;

	# Check permissions
	return unless $authz->hasPermissions($user, 'edit_achievements');

	$c->stash->{userRecords} =
		[ $db->getUsersWhere({ user_id => { not_like => 'set_id:%' } }, [qw/section last_name first_name/]) ];
	$c->stash->{userAchievementRecords} =
		{ map { $_->user_id => $_ } $db->getUserAchievementsWhere({ achievement_id => $achievementID }) };
	$c->stash->{currentUsers} =
		{ map { $ce->status_abbrev_has_behavior($_->status, 'include_in_assignment') ? ($_->user_id => 1) : () }
			@{ $c->stash->{userRecords} } };

	# Check and see if we need to assign or unassign achievements.
	if ($c->param('assignToSelected') || $c->param('assignToAll')) {
		my $achievement            = $db->getAchievement($achievementID);
		my %globalUserAchievements = map { $_->user_id => $_ } $db->getGlobalUserAchievementsWhere;
		my (
			@userAchievementsToInsert,       @userAchievementsToUpdate, @userAchievementsToDelete,
			@globalUserAchievementsToInsert, @globalUserAchievementsToUpdate,
		);
		for my $userRecord (@{ $c->stash->{userRecords} }) {
			my $userID  = $userRecord->user_id;
			my %actions = map { $_ => 1 } $c->param("$userID.achievement");
			next unless %actions;

			if ($actions{assigned}) {
				if ($c->stash->{userAchievementRecords}{$userID}) {
					# Update earned status if requested and it didn't change in the background.
					my $updatedEarned = $c->param("$userID.earned")                          ? 1 : 0;
					my $earned        = $c->stash->{userAchievementRecords}{$userID}->earned ? 1 : 0;
					my $earned_check  = $c->param("$userID.earned_check")                    ? 1 : 0;
					my $updateEarned  = $updatedEarned != $earned && $earned == $earned_check;
					if ($updateEarned) {
						$c->stash->{userAchievementRecords}{$userID}->earned($updatedEarned);

						# If the user does not have global achievement data, then add it.
						if ($globalUserAchievements{$userID}) {
							push(@globalUserAchievementsToUpdate, $globalUserAchievements{$userID});
						} else {
							$globalUserAchievements{$userID} = $db->newGlobalUserAchievement(user_id => $userID);
							push(@globalUserAchievementsToInsert, $globalUserAchievements{$userID});
						}

						my $points        = $achievement->points                                 || 0;
						my $initialpoints = $globalUserAchievements{$userID}->achievement_points || 0;

						# Add/subtract achievement points due to changing earned status.
						if ($updatedEarned) {
							$globalUserAchievements{$userID}->achievement_points($initialpoints + $points);
						} else {
							$globalUserAchievements{$userID}->achievement_points($initialpoints - $points);
						}
					} elsif ($updatedEarned != $earned_check && $updatedEarned != $earned) {
						$c->addbadmessage($c->maketext(
							'Requested change in earned status for user "[_1]" on achievement "[_2]" aborted '
								. 'because earned status changed in the background.',
							$userID,
							$achievementID
						));
					}

					# Update counter if requested and it didn't change in the background.
					my $updatedCounter = $c->param("$userID.counter")                          // '';
					my $counter        = $c->stash->{userAchievementRecords}{$userID}->counter // '';
					my $counter_check  = $c->param("$userID.counter_check")                    // '';
					my $updateCounter  = $updatedCounter ne $counter && $counter eq $counter_check;
					if ($updateCounter) {
						$c->stash->{userAchievementRecords}{$userID}->counter($updatedCounter);
					} elsif ($updatedCounter ne $counter_check && $updatedCounter ne $counter) {
						$c->addbadmessage($c->maketext(
							'Requested change in counter for user "[_1]" on achievement "[_2]" aborted '
								. 'because the counter changed in the background.',
							$userID,
							$achievementID
						));
					}

					push(@userAchievementsToUpdate, $c->stash->{userAchievementRecords}{$userID})
						if $updateEarned || $updateCounter;
				} else {
					# Add user achievements that don't exist.
					$c->stash->{userAchievementRecords}{$userID} = $db->newUserAchievement;
					$c->stash->{userAchievementRecords}{$userID}->user_id($userID);
					$c->stash->{userAchievementRecords}{$userID}->achievement_id($achievementID);
					push(@userAchievementsToInsert, $c->stash->{userAchievementRecords}{$userID});

					# If the user does not have global achievement data, then add that too.
					if (!$globalUserAchievements{$userID}) {
						$globalUserAchievements{$userID} = $db->newGlobalUserAchievement(user_id => $userID);
						push(@globalUserAchievementsToInsert, $globalUserAchievements{$userID});
					}
				}
			} elsif ($actions{delete} && $c->param('allow_unassign') && $c->stash->{userAchievementRecords}{$userID}) {
				# Delete achievements for users that were unchecked.
				push(@userAchievementsToDelete, $c->stash->{userAchievementRecords}{$userID});
				delete $c->stash->{userAchievementRecords}{$userID};
			}
		}

		$db->GlobalUserAchievement->insert_records(\@globalUserAchievementsToInsert) if @globalUserAchievementsToInsert;
		$db->GlobalUserAchievement->update_records(\@globalUserAchievementsToUpdate) if @globalUserAchievementsToUpdate;
		if (@userAchievementsToInsert) {
			$c->addgoodmessage($c->maketext(
				'Achievement assigned to [quant,_1,user,users].', scalar(@userAchievementsToInsert)));
			$db->UserAchievement->insert_records(\@userAchievementsToInsert);
		}
		if (@userAchievementsToUpdate) {
			$c->addgoodmessage($c->maketext(
				'Achievement data updated for [quant,_1,user,users].',
				scalar(@userAchievementsToUpdate)
			));
			$db->UserAchievement->update_records(\@userAchievementsToUpdate);
		}
		if (@userAchievementsToDelete) {
			# This is one of the rare places this can be done since user achievements don't
			# have any dependent rows in other tables that also need to be deleted.
			$c->addgoodmessage($c->maketext(
				'Achievement unassigned from [quant,_1,user,users].',
				scalar(@userAchievementsToDelete)
			));
			$db->UserAchievement->delete_records(\@userAchievementsToDelete);
		}
		$c->addgoodmessage($c->maketext('No new users to assign, update, or unassign. No action taken.'))
			unless @userAchievementsToInsert || @userAchievementsToUpdate || @userAchievementsToDelete;
	}

	# Count number of current, currently assigned, and total assigned users.
	my $numberAssignedUsers        = 0;
	my $numberAssignedCurrentUsers = 0;
	for (@{ $c->stash->{userRecords} }) {
		my $userID = $_->user_id;
		if ($c->stash->{userAchievementRecords}{$userID}) {
			++$numberAssignedUsers;
			++$numberAssignedCurrentUsers if $c->stash->{currentUsers}{$userID};
		}
	}
	$c->stash->{numberCurrentUsers}         = scalar(keys %{ $c->stash->{currentUsers} });
	$c->stash->{numberAssignedUsers}        = $numberAssignedUsers;
	$c->stash->{numberAssignedCurrentUsers} = $numberAssignedCurrentUsers;

	return;
}

1;
