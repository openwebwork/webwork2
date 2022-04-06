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

package WeBWorK::ContentGenerator::Instructor::Assigner;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Assigner - Assign homework sets to users.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $authz = $r->authz;
	my $ce = $r->ce;
	my $user = $r->param('user');

	# Permissions dealt with in the body
	return "" unless $authz->hasPermissions($user, "access_instructor_tools");
	return "" unless $authz->hasPermissions($user, "assign_problem_sets");

	my @selected_users = $r->param("selected_users");
	my @selected_sets = $r->param("selected_sets");

	if (defined $r->param("assign") || defined $r->param("unassign")) {
		if  (@selected_users && @selected_sets) {
			my @results;  # This is not used?
			if(defined $r->param("assign")) {
				$self->assignSetsToUsers(\@selected_sets, \@selected_users);
				$self->addgoodmessage($r->maketext('All assignments were made successfully.'));
			}
			if (defined $r->param("unassign")) {
				if(defined $r->param('unassignFromAllSafety') and $r->param('unassignFromAllSafety')==1) {
					$self->unassignSetsFromUsers(\@selected_sets, \@selected_users) if(defined $r->param("unassign"));
					$self->addgoodmessage($r->maketext('All unassignments were made successfully.'));
				} else { # asked for unassign, but no safety radio toggle
					$self->addbadmessage($r->maketext('Unassignments were not done.  You need to both click to "Allow unassign" and click on the Unassign button.'));
				}
			}

			if (@results) { # Can't get here?
				$self->addbadmessage(
					"The following error(s) occured while assigning:".
					CGI::ul(CGI::li(\@results))
				);
			}
		} else {
			$self->addbadmessage("You must select one or more users below.")
				unless @selected_users;
			$self->addbadmessage("You must select one or more sets below.")
				unless @selected_sets;
		}
	}
}

sub body {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $authz  = $r->authz;
	my $ce     = $r->ce;

	my $user = $r->param('user');

	# Check permissions
	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		"You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' }, "You are not authorized to assign homework sets.")
		unless $authz->hasPermissions($user, "assign_problem_sets");

	print CGI::p(
		$r->maketext(
			"Select one or more sets and one or more users below to assign/unassign each selected set to/from all selected users."
		)
	);

	# Get all users except the set level proctors, and restrict to the sections or recitations that are allowed for the
	# user if such restrictions are defined.
	my @Users = $db->getUsersWhere({
		user_id => { not_like => 'set_id:%' },
		$ce->{viewable_sections}{$user} || $ce->{viewable_recitations}{$user}
		? (
			-or => [
				$ce->{viewable_sections}{$user}    ? (section    => $ce->{viewable_sections}{$user})    : (),
				$ce->{viewable_recitations}{$user} ? (recitation => $ce->{viewable_recitations}{$user}) : ()
			]
			)
		: ()
	});

	my @GlobalSets   = $db->getGlobalSetsWhere();

	print CGI::start_form({ method => 'post', action => $r->uri() });
	print $self->hidden_authen_fields();

	print CGI::div(
		CGI::div(
			{ class => 'row gx-3' },
			CGI::div(
				{ class => 'col-xl-5 col-md-6 mb-2' },
				CGI::div(
					{ class => 'fw-bold text-center' },
					CGI::label({ for => 'selected_users' }, $r->maketext('Users'))
				),
				scrollingRecordList(
					{
						name            => 'selected_users',
						id              => 'selected_users',
						request         => $r,
						default_sort    => 'lnfn',
						default_format  => 'lnfn_uid',
						default_filters => ['all'],
						attrs           => {
							size     => 20,
							multiple => 1
						}
					},
					@Users
				)
			),
			CGI::div(
				{ class => 'col-xl-5 col-md-6 mb-2' },
				CGI::div(
					{ class => 'fw-bold text-center' },
					CGI::label({ for => 'selected_sets' }, $r->maketext('Sets'))
				),
				scrollingRecordList(
					{
						name            => 'selected_sets',
						id              => 'selected_sets',
						request         => $r,
						default_sort    => 'set_id',
						default_format  => 'set_id',
						default_filters => ['all'],
						attrs           => {
							size     => 20,
							multiple => 1,
							dir      => 'ltr'
						}
					},
					@GlobalSets
				)
			)
		),
		CGI::div(
			CGI::submit({
				name  => 'assign',
				value => $r->maketext('Assign selected sets to selected users'),
				class => 'btn btn-primary mb-2'
			}),
			CGI::div(
				{ class => 'alert alert-danger p-1 mb-2' },
				CGI::div({ class => 'mb-1' }, $r->maketext('Do not unassign students unless you know what you are doing.')),
				CGI::div($r->maketext('There is NO undo for unassigning students.'))
			),
			CGI::div(
				{ class => 'd-flex align-items-center' },
				CGI::submit({
					name  => "unassign",
					value => $r->maketext("Unassign selected sets from selected users"),
					class => 'btn btn-primary me-2'
				}),
				CGI::radio_group({
					name            => "unassignFromAllSafety",
					values          => [ 0, 1 ],
					default         => 0,
					labels          => { 0 => $r->maketext('Assignments only'), 1 => $r->maketext('Allow unassign') },
					class           => 'form-check-input mx-1',
					labelattributes => { class => 'form-check-label' },
				})
			),
			CGI::div(
				{ class => 'mt-2' },
				"When you unassign a student's name, you destroy all of the data for that homework set for that "
					. "student.  You will then need to reassign the set(s) to these students and they will receive new "
					. "versions of the problems.  Make sure this is what you want to do before unassigning students."
			)
		)
	);

	print CGI::end_form();

	return '';
}

1;
