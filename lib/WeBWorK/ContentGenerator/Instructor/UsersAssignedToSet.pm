################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet;
use parent qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet - List and edit the
users to which sets are assigned.

=cut

use strict;
use warnings;

use WeBWorK::Debug;
use WeBWorK::Utils qw(format_set_name_display);

sub initialize {
	my ($self)  = @_;
	my $r       = $self->r;
	my $urlpath = $r->urlpath;
	my $authz   = $r->authz;
	my $db      = $r->db;
	my $setID   = $urlpath->arg("setID");
	my $user    = $r->param('user');

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	return unless $authz->hasPermissions($user, "assign_problem_sets");

	my %selectedUsers = map { $_ => 1 } $r->param('selected');

	my $doAssignToSelected = 0;

	if (defined $r->param('assignToAll')) {
		debug("assignSetToAllUsers($setID)");
		$self->addgoodmessage($r->maketext("Problems have been assigned to all current users."));
		$self->assignSetToAllUsers($setID);
		debug("done assignSetToAllUsers($setID)");
	} elsif (defined $r->param('unassignFromAll')
		&& defined($r->param('unassignFromAllSafety'))
		&& $r->param('unassignFromAllSafety') == 1)
	{
		%selectedUsers = ();
		$self->addgoodmessage($r->maketext("Problems for all students have been unassigned."));
		$doAssignToSelected = 1;
	} elsif (defined $r->param('assignToSelected')) {
		$self->addgoodmessage($r->maketext("Problems for selected students have been reassigned."));
		$doAssignToSelected = 1;
	} elsif (defined $r->param("unassignFromAll")) {
		# no action taken
		$self->addbadmessage($r->maketext("No action taken"));
	}

	# Get all user records and cache them for later use.
	$self->{user_records} =
		[ $db->getUsersWhere({ user_id => { not_like => 'set_id:%' } }, [qw/section last_name first_name/]) ];

	if ($doAssignToSelected) {
		my $setRecord = $db->getGlobalSet($setID);
		die "Unable to get global set record for $setID " unless $setRecord;

		my %setUsers = map { $_ => 1 } $db->listSetUsers($setID);
		for my $selectedUser (map { $_->user_id } @{ $self->{user_records} }) {
			if (exists $selectedUsers{$selectedUser}) {
				unless ($setUsers{$selectedUser}) {    # skip users already in the set
					debug("assignSetToUser($selectedUser, ...)");
					$self->assignSetToUser($selectedUser, $setRecord);
					debug("done assignSetToUser($selectedUser, ...)");
				}
			} else {
				next unless $setUsers{$selectedUser};    # skip users not in the set
				$db->deleteUserSet($selectedUser, $setID);
			}
		}
	}

	return;
}

1;
