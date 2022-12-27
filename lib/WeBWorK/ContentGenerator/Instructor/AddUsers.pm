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

package WeBWorK::ContentGenerator::Instructor::AddUsers;
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::AddUsers - Menu interface for adding users

=cut

use strict;
use warnings;

use WeBWorK::Utils qw/cryptPassword trim_spaces/;
use WeBWorK::Utils::Instructor qw(assignSetsToUsers);

sub initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $ce     = $r->ce;
	my $authz  = $r->authz;

	my $user = $r->param('user');

	# Check permissions
	return unless $authz->hasPermissions($user, 'access_instructor_tools');
	return unless $authz->hasPermissions($user, 'modify_student_data');

	if (defined $r->param('addStudents')) {
		$self->{studentEntryReport} = $r->c;

		my @userIDs;
		my $numberOfStudents = $r->param('number_of_students') // 0;

		# FIXME: Handle errors if user already exists as well as all other errors that could occur (including errors
		# when adding the permission, adding the password, and assigning sets to the users).
		for my $i (1 .. $numberOfStudents) {
			my $new_user_id  = trim_spaces($r->param("new_user_id_$i"));
			my $new_password = cryptPassword($r->param("student_id_$i"));
			next unless $new_user_id;

			my $newUser = $db->newUser;
			$newUser->user_id($new_user_id);
			$newUser->last_name(trim_spaces($r->param("last_name_$i")));
			$newUser->first_name(trim_spaces($r->param("first_name_$i")));
			$newUser->student_id(trim_spaces($r->param("student_id_$i")));
			$newUser->email_address(trim_spaces($r->param("email_address_$i")));
			$newUser->section(trim_spaces($r->param("section_$i")));
			$newUser->recitation(trim_spaces($r->param("recitation_$i")));
			$newUser->comment(trim_spaces($r->param("comment_$i")));
			$newUser->status($ce->status_name_to_abbrevs($ce->{default_status}));

			eval { $db->addUser($newUser) };
			if ($@) {
				push(
					@{ $self->{studentEntryReport} },
					$r->include(
						'ContentGenerator/Instructor/AddUsers/student_entry_report',
						newUser  => $newUser,
						addError => $@
					)
				);
			} else {
				push @userIDs, $new_user_id;

				my $newPermissionLevel = $db->newPermissionLevel;
				$newPermissionLevel->user_id($new_user_id);
				$newPermissionLevel->permission(0);
				$db->addPermissionLevel($newPermissionLevel);

				my $newPassword = $db->newPassword;
				$newPassword->user_id($new_user_id);
				$newPassword->password($new_password);
				$db->addPassword($newPassword);

				push(
					@{ $self->{studentEntryReport} },
					$r->include(
						'ContentGenerator/Instructor/AddUsers/student_entry_report',
						newUser  => $newUser,
						addError => ''
					)
				);
			}
		}
		if (defined $r->param('assignSets')) {
			my @setIDs = $r->param('assignSets');
			assignSetsToUsers($db, \@setIDs, \@userIDs);
		}
	}

	return;
}

1;
