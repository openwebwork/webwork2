###############################################################################
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
# FOR A PARTICULAR PURPOSE.	 See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ContentGenerator::Instructor::Index;
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Index - Menu interface to the Instructor
pages

=cut

use strict;
use warnings;

use WeBWorK::Utils qw(x format_set_name_internal);

use constant E_MAX_ONE_SET  => x('Please select at most one set.');
use constant E_ONE_USER     => x('Please select exactly one user.');
use constant E_ONE_SET      => x('Please select exactly one set.');
use constant E_MIN_ONE_USER => x('Please select at least one user.');
use constant E_MIN_ONE_SET  => x('Please select at least one set.');
use constant E_SET_NAME     => x('Please specify a homework set name.');
use constant E_BAD_NAME     => x('Please use only letters, digits, dashes, underscores, and periods in your set name.');

async sub pre_header_initialize {
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $authz   = $r->authz;
	my $urlpath = $r->urlpath;

	# Make sure these are defined for the template.
	$r->stash->{users}          = [];
	$r->stash->{globalSets}     = [];
	$r->stash->{E_MAX_ONE_SET}  = E_MAX_ONE_SET;
	$r->stash->{E_ONE_USER}     = E_ONE_USER;
	$r->stash->{E_ONE_SET}      = E_ONE_SET;
	$r->stash->{E_MIN_ONE_USER} = E_MIN_ONE_USER;
	$r->stash->{E_MIN_ONE_SET}  = E_MIN_ONE_SET;
	$r->stash->{E_SET_NAME}     = E_SET_NAME;
	$r->stash->{E_BAD_NAME}     = E_BAD_NAME;
	$r->stash->{courseID}       = $urlpath->arg('courseID');

	my $userID = $r->param('user');

	return unless ($authz->hasPermissions($userID, 'access_instructor_tools'));

	my @selectedUserIDs = $r->param('selected_users');
	my @selectedSetIDs  = $r->param('selected_sets');

	my $nusers = @selectedUserIDs;
	my $nsets  = @selectedSetIDs;

	my $firstUserID = $nusers ? $selectedUserIDs[0] : '';
	my $firstSetID  = $nsets  ? $selectedSetIDs[0]  : '';

	# These will be used to construct a new URL.
	my $module;
	my %args = (courseID => $r->stash->{courseID});
	my %params;

	my $pfx  = 'WeBWorK::ContentGenerator';
	my $ipfx = 'WeBWorK::ContentGenerator::Instructor';

	my @error;

	# Depending on which button was pushed, fill in values for URL construction.
	if (defined $r->param('sets_assigned_to_user')) {
		if ($nusers == 1) {
			$module = "${ipfx}::UserDetail";
			$args{userID} = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	} elsif (defined $r->param('users_assigned_to_set')) {
		if ($nsets == 1) {
			$module = "${ipfx}::UsersAssignedToSet";
			$args{setID} = $firstSetID;
		} else {
			push @error, E_ONE_SET;
		}
	} elsif (defined $r->param('edit_sets')) {
		if ($nsets == 1) {
			$module = "${ipfx}::ProblemSetDetail";
			$args{setID} = $firstSetID;
		} else {
			push @error, E_ONE_SET;
		}
	} elsif (defined $r->param('prob_lib')) {
		if ($nsets == 1) {
			$module = "${ipfx}::SetMaker";
			$params{local_sets} = $firstSetID;
		} elsif ($nsets == 0) {
			$module = "${ipfx}::SetMaker";
		} else {
			push @error, E_ONE_SET;
		}
	} elsif (defined $r->param('user_stats')) {
		if ($nusers == 1) {
			$module         = "${ipfx}::Stats";
			$args{statType} = 'student';
			$args{userID}   = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	} elsif (defined $r->param('set_stats')) {
		if ($nsets == 1) {
			$module         = "${ipfx}::Stats";
			$args{statType} = 'set';
			$args{setID}    = $firstSetID;
		} else {
			push @error, E_ONE_SET;
		}
	} elsif (defined $r->param('user_progress')) {
		if ($nusers == 1) {
			$module         = "${ipfx}::StudentProgress";
			$args{statType} = 'student';
			$args{userID}   = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	} elsif (defined $r->param('set_progress')) {
		if ($nsets == 1) {
			$module         = "${ipfx}::StudentProgress";
			$args{statType} = 'set';
			$args{setID}    = $firstSetID;
		} else {
			push @error, E_ONE_SET;
		}
	} elsif (defined $r->param('user_options')) {
		if ($nusers == 1) {
			$module = "${pfx}::Options";
			$params{effectiveUser} = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	} elsif (defined $r->param('act_as_user')) {
		if ($nusers == 1 and $nsets <= 1) {
			if ($nsets) {
				# Unfortunately, we need to know what type of set it is to figure out the correct module.
				my $set = $db->getGlobalSet($firstSetID);
				if (defined($set) && $set->assignment_type =~ /gateway/) {
					$module = "${pfx}::GatewayQuiz";
				} else {
					$module = "${pfx}::ProblemSet";
				}
				$args{setID} = $firstSetID;
			} else {
				$module = "${pfx}::ProblemSets";
			}
			$params{effectiveUser} = $firstUserID;
		} else {
			push @error, E_ONE_USER    unless $nusers == 1;
			push @error, E_MAX_ONE_SET unless $nsets <= 1;
		}
	} elsif (defined $r->param('edit_set_for_users')) {
		if ($nusers >= 1 and $nsets == 1) {
			$module              = "${ipfx}::ProblemSetDetail";
			$args{setID}         = $firstSetID;
			$params{editForUser} = \@selectedUserIDs;
		} else {
			push @error, E_MIN_ONE_USER unless $nusers >= 1;
			push @error, E_ONE_SET      unless $nsets == 1;

		}
	} elsif (defined $r->param('create_set')) {
		my $setname = format_set_name_internal($r->param("new_set_name") // '');
		if ($setname) {
			if ($setname =~ /^[\w.-]*$/) {
				$module                = "${ipfx}::SetMaker";
				$params{new_local_set} = 'Create a New Set in this Course';
				$params{new_set_name}  = $setname;
				$params{selfassign}    = 1;
			} else {
				push @error, E_BAD_NAME;
			}
		} else {
			push @error, E_SET_NAME;
		}
	} elsif (defined $r->param('add_users')) {
		$module = "${ipfx}::AddUsers";
	} elsif (defined $r->param('email_users')) {
		$module = "${ipfx}::SendMail";
	} elsif (defined $r->param('transfer_files')) {
		$module = "${ipfx}::FileManager";
	}

	push @error, x('You are not allowed to act as a student.')
		if (defined $r->param('act_as_user') && !$authz->hasPermissions($userID, 'become_student'));
	push @error, x('You are not allowed to modify homework sets.')
		if ((defined $r->param('edit_sets') || defined $r->param('edit_set_for_users'))
			&& !$authz->hasPermissions($userID, 'modify_problem_sets'));
	push @error, x('You are not allowed to assign homework sets.')
		if ((defined $r->param('sets_assigned_to_user') || defined $r->param('users_assigned_to_set'))
			&& !$authz->hasPermissions($userID, 'assign_problem_sets'));
	push @error, x('You are not allowed to modify student data.')
		if ((defined $r->param('user_options') || defined $r->param('user_options'))
			&& !$authz->hasPermissions($userID, 'modify_student_data'));

	if (@error) {
		# Handle errors
		$self->addbadmessage($r->c(map { $r->maketext($_) } @error)->join($r->tag('br')));
	} elsif ($module) {
		# Redirect to target page
		my $page = $urlpath->newFromModule($module, $r, %args);
		my $url  = $self->systemLink($page, params => \%params);
		$self->reply_with_redirect($url);
		return;
	}

	# Get all users except the set level proctors, and restrict to the sections or recitations that are allowed for the
	# user if such restrictions are defined.  This list is sorted by last_name, then first_name, then user_id.
	$r->stash->{users} = [
		$db->getUsersWhere(
			{
				user_id => { not_like => 'set_id:%' },
				$ce->{viewable_sections}{$userID} || $ce->{viewable_recitations}{$userID}
				? (
					-or => [
						$ce->{viewable_sections}{$userID} ? (section => $ce->{viewable_sections}{$userID}) : (),
						$ce->{viewable_recitations}{$userID}
						? (recitation => $ce->{viewable_recitations}{$userID})
						: ()
					]
					)
				: ()
			},
			[qw/last_name first_name user_id/]
		)
	];

	$r->stash->{globalSets} = [ $db->getGlobalSetsWhere ];

	return;
}

1;
