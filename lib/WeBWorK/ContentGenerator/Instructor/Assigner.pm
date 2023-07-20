################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Assigner - Assign homework sets to users.

=cut

use WeBWorK::Utils::Instructor qw(assignSetsToUsers unassignSetsFromUsers);

sub pre_header_initialize ($c) {
	my $db    = $c->db;
	my $authz = $c->authz;
	my $ce    = $c->ce;
	my $user  = $c->param('user');

	# Make sure these are defined for the template.
	$c->stash->{users}      = [];
	$c->stash->{globalSets} = [];

	# Permissions dealt with in the body
	return '' unless $authz->hasPermissions($user, 'access_instructor_tools');
	return '' unless $authz->hasPermissions($user, 'assign_problem_sets');

	my @selected_users = $c->param('selected_users');
	my @selected_sets  = $c->param('selected_sets');

	if (defined $c->param('assign') || defined $c->param('unassign')) {
		if (@selected_users && @selected_sets) {
			my @results;    # This is not used?
			if (defined $c->param('assign')) {
				assignSetsToUsers($db, $ce, \@selected_sets, \@selected_users);
				$c->addgoodmessage($c->maketext('All assignments were made successfully.'));
			}
			if (defined $c->param('unassign')) {
				if (defined $c->param('unassignFromAllSafety') and $c->param('unassignFromAllSafety') == 1) {
					unassignSetsFromUsers($db, \@selected_sets, \@selected_users) if (defined $c->param('unassign'));
					$c->addgoodmessage($c->maketext('All unassignments were made successfully.'));
				} else {    # asked for unassign, but no safety radio toggle
					$c->addbadmessage($c->maketext(
						'Unassignments were not done.  '
							. 'You need to select "Allow unassign" and then click on the Unassign button.'
					));
				}
			}

			if (@results) {    # Can't get here?
				$c->addbadmessage(
					$c->c('The following error(s) occured while assigning:',
						$c->tag('ul', $c->c(map { $c->tag('li', $_) } @results)->join('')))->join('')
				);
			}
		} else {
			$c->addbadmessage('You must select one or more users below.')
				unless @selected_users;
			$c->addbadmessage('You must select one or more sets below.')
				unless @selected_sets;
		}
	}

	# Get all users except the set level proctors, and restrict to the sections or recitations that are allowed for the
	# user if such restrictions are defined.
	$c->stash->{users} = [
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

	$c->stash->{globalSets} = [ $db->getGlobalSetsWhere ];

	return;
}

1;
