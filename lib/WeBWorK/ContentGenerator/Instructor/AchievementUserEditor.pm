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

	# Make sure these are defined for the template.
	$c->stash->{userRecords}            = [];
	$c->stash->{userAchievementRecords} = [];

	# Check permissions
	return unless $authz->hasPermissions($user, 'edit_achievements');

	$c->stash->{userRecords} =
		[ $db->getUsersWhere({ user_id => { not_like => 'set_id:%' } }, [qw/section last_name first_name/]) ];
	$c->stash->{userAchievementRecords} =
		{ map { $_->user_id => $_ } $db->getUserAchievementsWhere({ achievement_id => $achievementID }) };

	my %selectedUsers = map { $_ => 1 } $c->param('selected');

	my $doAssignToSelected = 0;

	# Check and see if we need to assign or unassign achievements.
	if (defined $c->param('assignToAll')) {
		$c->addgoodmessage($c->maketext('Achievement has been assigned to all users.'));
		%selectedUsers      = map { $_->user_id => 1 } @{ $c->stash->{userRecords} };
		$doAssignToSelected = 1;
	} elsif (defined $c->param('unassignFromAll')
		&& defined($c->param('unassignFromAllSafety'))
		&& $c->param('unassignFromAllSafety') == 1)
	{
		%selectedUsers = ();
		$c->addgoodmessage($c->maketext('Achievement has been unassigned from all users.'));
		$doAssignToSelected = 1;
	} elsif (defined $c->param('assignToSelected')) {
		$c->addgoodmessage($c->maketext('Achievement has been assigned to selected users.'));
		$doAssignToSelected = 1;
	} elsif (defined $c->param('unassignFromAll')) {
		$c->addbadmessage($c->maketext('No action taken'));
	}

	# Do the actual assignment and unassignment.
	if ($doAssignToSelected) {
		my $achievement = $db->getAchievement($achievementID);

		my %globalUserAchievements = map { $_->user_id => $_ } $db->getGlobalUserAchievementsWhere;

		my (
			@userAchievementsToInsert,       @userAchievementsToUpdate, @userAchievementsToDelete,
			@globalUserAchievementsToInsert, @globalUserAchievementsToUpdate,
		);

		for my $user (@{ $c->stash->{userRecords} }) {
			my $userID = $user->user_id;
			if ($selectedUsers{$userID} && $c->stash->{userAchievementRecords}{$userID}) {
				# Update existing user data (in case fields were changed).
				my $updatedEarned = $c->param("$userID.earned")                          ? 1 : 0;
				my $earned        = $c->stash->{userAchievementRecords}{$userID}->earned ? 1 : 0;

				if ($updatedEarned != $earned) {
					$c->stash->{userAchievementRecords}{$userID}->earned($updatedEarned);

					my $points        = $achievement->points                                 || 0;
					my $initialpoints = $globalUserAchievements{$userID}->achievement_points || 0;

					# Add the correct number of points if we are saying that the
					# user now earned the achievement, or remove them otherwise.
					if ($updatedEarned) {
						$globalUserAchievements{$userID}->achievement_points($initialpoints + $points);
					} else {
						$globalUserAchievements{$userID}->achievement_points($initialpoints - $points);
					}

					push(@globalUserAchievementsToUpdate, $globalUserAchievements{$userID});
				}

				my $updatedCounter = $c->param("$userID.counter")                          // '';
				my $counter        = $c->stash->{userAchievementRecords}{$userID}->counter // '';
				$c->stash->{userAchievementRecords}{$userID}->counter($updatedCounter)
					if $updatedCounter ne $counter;

				push(@userAchievementsToUpdate, $c->stash->{userAchievementRecords}{$userID})
					if $updatedEarned != $earned || $updatedCounter ne $counter;
			} elsif ($selectedUsers{$userID}) {
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
			} else {
				# Delete achievements for users that are not selected, but don't delete achievements that don't exist.
				next unless $c->stash->{userAchievementRecords}{$userID};
				push(@userAchievementsToDelete, $c->stash->{userAchievementRecords}{$userID});
				delete $c->stash->{userAchievementRecords}{$userID};
			}
		}

		$db->GlobalUserAchievement->insert_records(\@globalUserAchievementsToInsert) if @globalUserAchievementsToInsert;
		$db->GlobalUserAchievement->update_records(\@globalUserAchievementsToUpdate) if @globalUserAchievementsToUpdate;
		$db->UserAchievement->insert_records(\@userAchievementsToInsert)             if @userAchievementsToInsert;
		$db->UserAchievement->update_records(\@userAchievementsToUpdate)             if @userAchievementsToUpdate;

		# This is one of the rare places this can be done since user achievements don't
		# have any dependent rows in other tables that also need to be deleted.
		$db->UserAchievement->delete_records(\@userAchievementsToDelete) if @userAchievementsToDelete;
	}

	return;
}

1;
