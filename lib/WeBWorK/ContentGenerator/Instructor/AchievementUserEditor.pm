################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::AchievementUserEditor - List and edit the
users assigned to an achievement.

=cut

use strict;
use warnings;
use CGI qw(-nosticky );
use WeBWorK::Debug;

sub initialize {
	my ($self)     = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $authz      = $r->authz;
	my $db         = $r->db;
	my $achievementID = $urlpath->arg("achievementID");
	my $user       = $r->param('user');

	# Check permissions
	return unless $authz->hasPermissions($user, "edit_achievements");

	$self->{all_users} = [ $db->listUsers ];
	my %selectedUsers = map {$_ => 1} $r->param('selected');

	my $doAssignToSelected = 0;

	#Check and see if we need to assign or unassign things
	if (defined $r->param('assignToAll')) {
		$self->addmessage(CGI::div(
			{ class => 'alert alert-success p-1 mb-0' },
			$r->maketext("Achievement has been assigned to all users.")
		));
		%selectedUsers      = map { $_ => 1 } @{ $self->{all_users} };
		$doAssignToSelected = 1;
	} elsif (defined $r->param('unassignFromAll')
		&& defined($r->param('unassignFromAllSafety'))
		&& $r->param('unassignFromAllSafety') == 1)
	{
		%selectedUsers = ();
		$self->addmessage(
			CGI::div(
				{ class => 'alert alert-danger p-1 mb-0' },
				$r->maketext("Achievement has been unassigned to all students.")
			)
		);
		$doAssignToSelected = 1;
	} elsif (defined $r->param('assignToSelected')) {
		$self->addmessage(
			CGI::div(
				{ class => 'alert alert-success p-1 mb-0' },
				$r->maketext("Achievement has been assigned to selected users.")
			)
		);
		$doAssignToSelected = 1;
	} elsif (defined $r->param("unassignFromAll")) {
		# no action taken
		$self->addmessage(CGI::div({ class => 'alert alert-danger p-1 mb-0' }, $r->maketext("No action taken")));
	}

	#do actual assignment and unassignment
	if ($doAssignToSelected) {

		my %achievementUsers = map { $_ => 1 } $db->listAchievementUsers($achievementID);
		foreach my $selectedUser (@{ $self->{all_users} }) {
			if (exists $selectedUsers{$selectedUser} && $achievementUsers{$selectedUser}) {
			    # update existing user data (in case fields were changed)
			    my $userAchievement = $db->getUserAchievement($selectedUser,$achievementID);

			    my $updatedEarned = $r->param("$selectedUser.earned") ? 1:0;
			    my $earned = $userAchievement->earned ? 1:0;
			    if ($updatedEarned != $earned) {

				$userAchievement->earned($updatedEarned);
				my $globalUserAchievement = $db->getGlobalUserAchievement($selectedUser);
				my $achievement = $db->getAchievement($achievementID);

				my $points = $achievement->points || 0;
				my $initialpoints = $globalUserAchievement->achievement_points || 0;
				#add the correct number of points if we
				# are saying that the user now earned the
				# achievement, or remove them otherwise
				if ($updatedEarned) {

				    $globalUserAchievement->achievement_points(
					$initialpoints +	$points);
				} else {
				    $globalUserAchievement->achievement_points(
					$initialpoints -	$points);
				}

				$db->putGlobalUserAchievement($globalUserAchievement);
			    }


			    $userAchievement->counter($r->param("$selectedUser.counter"));
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
}

sub body {
	my ($self)         = @_;
	my $r              = $self->r;
	my $urlpath        = $r->urlpath;
	my $db             = $r->db;
	my $ce             = $r->ce;
	my $authz          = $r->authz;
	my $webworkRoot    = $ce->{webworkURLs}->{root};
	my $courseName     = $urlpath->arg("courseID");
	my $achievementID  = $urlpath->arg("achievementID");
	my $user           = $r->param('user');

	return CGI::div({ class => 'alert alert-danger p-1' }, "You are not authorized to edit achievements.")
		unless $authz->hasPermissions($user, "edit_achievements");

	print CGI::start_form({name=>"user-achievement-form", id=>"user-achievement-form", method=>"post", action => $self->systemLink( $urlpath, authen=>0) });

	# Assign to everyone message
	print CGI::div(
		{ class => 'my-2' },
		CGI::submit({
			name  => "assignToAll",
			value => $r->maketext("Assign to All Current Users"),
			class => 'btn btn-primary'
		}),
		CGI::i($r->maketext("This action will not overwrite existing users."))
	);

	print CGI::div(
		{ class => 'alert alert-danger p-1 mb-2' },
		CGI::div({ class => 'mb-1' }, $r->maketext('Do not uncheck students, unless you know what you are doing.')),
		CGI::div($r->maketext('There is NO undo for unassigning students.'))
	);
	print CGI::p($r->maketext(
		"When you unassign by unchecking a student's name, you destroy all of the data for achievement [_1] "
			. 'for this student. Make sure this is what you want to do.',
		CGI::b($achievementID)
	));

	# Print table
	print CGI::start_div({ class => 'table-responsive' }),
		CGI::start_table({ class => 'table table-sm table-bordered font-sm align-middle w-auto' });
	print CGI::Tr(
		CGI::th({ class => 'text-center' }, $r->maketext('Assigned')),
		CGI::th($r->maketext('Login Name')),
		CGI::th($r->maketext('Student Name')),
		CGI::th({ class => 'text-center' }, $r->maketext('Section')),
		CGI::th({ class => 'text-center', id => 'earned_header' }, $r->maketext('Earned')),
		CGI::th({ class => 'text-center', id => 'counter_header' }, $r->maketext('Counter'))
	);

	# get user records
	my @userRecords  = ();
	for my $currentUser (@{ $self->{all_users} }) {
		my $userObj = $db->getUser($currentUser); #checked
		die "Unable to find user object for $currentUser. " unless $userObj;
		push (@userRecords, $userObj );
	}
	@userRecords = sort { ( lc($a->section) cmp lc($b->section) ) ||
	                     ( lc($a->last_name) cmp lc($b->last_name )) } @userRecords;

	#print row for user
	for my $userRecord (@userRecords) {

		my $statusClass = $ce->status_abbrev_to_name($userRecord->status) || '';

		my $user            = $userRecord->user_id;
		my $userAchievement = $db->getUserAchievement($user, $achievementID);
		my $prettyName      = $userRecord->last_name . ', ' . $userRecord->first_name;
		my $earned          = $userAchievement->earned  if ref $userAchievement;
		my $counter         = $userAchievement->counter if ref $userAchievement;

		print CGI::Tr(
			CGI::td(
				{ class => 'text-center' },
				CGI::input({
					type    => 'checkbox',
					name    => 'selected',
					id      => "$user.assigned",
					checked => defined $userAchievement,
					value   => $user,
					class   => 'form-check-input'
				})
			),
			CGI::td(CGI::label({ for => "$user.assigned" }, $user)),
			CGI::td($prettyName),
			CGI::td({ class => 'text-center' }, $userRecord->section),
			(
				defined $userAchievement
				? (
					CGI::td(
						{ class => 'text-center' },
						CGI::input({
							type            => 'checkbox',
							name            => "$user.earned",
							aria_labelledby => 'earned_header',
							value           => '1',
							checked         => $earned ? 1 : 0,
							class           => 'form-check-input'
						})
					),
					CGI::td(
						{ class => 'text-center' },
						CGI::input({
							type            => 'text',
							name            => "$user.counter",
							aria_labelledby => 'counter_header',
							value           => $counter,
							size            => 6,
							class           => 'form-control form-control-sm'
						})
					),
					)
				: (CGI::td(), CGI::td())
			)
		);
	}

	print CGI::end_table(), CGI::end_div();
	print $self->hidden_authen_fields;
	print CGI::submit({ name => "assignToSelected", value => $r->maketext("Save"), class => 'btn btn-primary' });

	#Print unassign from everyone stuff
	print CGI::hr()
		. CGI::div(
			CGI::div(
				{ class => 'alert alert-danger p-1 mb-3' },
				$r->maketext(
					"There is NO undo for this function.  Do not use it unless you know what you are doing!  "
						. "When you unassign a student using this button, or by unchecking their name, you destroy all "
						. "of the data for achievement [_1] for this student.",
					$achievementID
				)
			),
			CGI::div(
				{ class => 'd-flex align-items-center' },
				CGI::submit({
					name  => "unassignFromAll",
					value => $r->maketext("Unassign from All Users"),
					class => 'btn btn-primary'
				}),
				CGI::radio_group({
					name            => "unassignFromAllSafety",
					values          => [ 0, 1 ],
					default         => 0,
					labels          => { 0 => $r->maketext('Read only'), 1 => $r->maketext('Allow unassign') },
					class           => 'form-check-input mx-1',
					labelattributes => { class => 'form-check-label' },
				}),
			)
		) . CGI::hr();
	print CGI::end_form();

	return "";
}

1;
