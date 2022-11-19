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

package WeBWorK::ContentGenerator::Instructor::Assigner;
use parent qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Assigner - Assign homework sets to users.

=cut

use strict;
use warnings;

async sub pre_header_initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $authz  = $r->authz;
	my $ce     = $r->ce;
	my $user   = $r->param('user');

	# Make sure these are defined for the template.
	$r->stash->{users}      = [];
	$r->stash->{globalSets} = [];

	# Permissions dealt with in the body
	return '' unless $authz->hasPermissions($user, 'access_instructor_tools');
	return '' unless $authz->hasPermissions($user, 'assign_problem_sets');

	my @selected_users = $r->param('selected_users');
	my @selected_sets  = $r->param('selected_sets');

	if (defined $r->param('assign') || defined $r->param('unassign')) {
		if (@selected_users && @selected_sets) {
			my @results;    # This is not used?
			if (defined $r->param('assign')) {
				$self->assignSetsToUsers(\@selected_sets, \@selected_users);
				$self->addgoodmessage($r->maketext('All assignments were made successfully.'));
			}
			if (defined $r->param('unassign')) {
				if (defined $r->param('unassignFromAllSafety') and $r->param('unassignFromAllSafety') == 1) {
					$self->unassignSetsFromUsers(\@selected_sets, \@selected_users) if (defined $r->param('unassign'));
					$self->addgoodmessage($r->maketext('All unassignments were made successfully.'));
				} else {    # asked for unassign, but no safety radio toggle
					$self->addbadmessage($r->maketext(
						'Unassignments were not done.  '
							. 'You need to select "Allow unassign" and then click on the Unassign button.'
					));
				}
			}

			if (@results) {    # Can't get here?
				$self->addbadmessage(
					$r->c('The following error(s) occured while assigning:',
						$r->tag('ul', $r->c(map { $r->tag('li', $_) } @results)->join('')))->join('')
				);
			}
		} else {
			$self->addbadmessage('You must select one or more users below.')
				unless @selected_users;
			$self->addbadmessage('You must select one or more sets below.')
				unless @selected_sets;
		}
	}

	# Get all users except the set level proctors, and restrict to the sections or recitations that are allowed for the
	# user if such restrictions are defined.
	$r->stash->{users} = [
		$db->getUsersWhere({
			user_id => { not_like => 'set_id:%' },
			$ce->{viewable_sections}{$user} || $ce->{viewable_recitations}{$user}
			? (
				-or => [
					$ce->{viewable_sections}{$user}    ? (section    => $ce->{viewable_sections}{$user})    : (),
					$ce->{viewable_recitations}{$user} ? (recitation => $ce->{viewable_recitations}{$user}) : ()
				]
				)
			: ()
		})
	];

	$r->stash->{globalSets} = [ $db->getGlobalSetsWhere ];

	return;
}

1;
