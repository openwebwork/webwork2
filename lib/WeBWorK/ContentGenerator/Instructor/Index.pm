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
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Index - Menu interface to the Instructor
pages

=cut

use strict;
use warnings;
use WeBWorK::CGI;
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;
use WeBWorK::Utils qw/x getAssetURL format_set_name_internal/;

use constant E_MAX_ONE_SET  => x('Please select at most one set.');
use constant E_ONE_USER     => x('Please select exactly one user.');
use constant E_ONE_SET      => x('Please select exactly one set.');
use constant E_MIN_ONE_USER => x('Please select at least one user.');
use constant E_MIN_ONE_SET  => x('Please select at least one set.');
use constant E_SET_NAME     => x('Please specify a homework set name.');
use constant E_BAD_NAME     => x('Please use only letters, digits, dashes, underscores, and periods in your set name.');

sub pre_header_initialize {
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $authz   = $r->authz;
	my $urlpath = $r->urlpath;

	my $courseID = $urlpath->arg('courseID');
	my $userID   = $r->param('user');
	my $eUserID  = $r->param('effectiveUser');
	$self->{courseName} = $courseID;
	# Check permissions
	return unless ($authz->hasPermissions($userID, 'access_instructor_tools'));

	my @selectedUserIDs = $r->param('selected_users');
	my @selectedSetIDs  = $r->param('selected_sets');

	my $nusers = @selectedUserIDs;
	my $nsets  = @selectedSetIDs;

	my $firstUserID = $nusers ? $selectedUserIDs[0] : '';
	my $firstSetID  = $nsets  ? $selectedSetIDs[0]  : '';

	# These will be used to construct a new URL.
	my $module;
	my %args = (courseID => $courseID);
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

	push @error, 'You are not allowed to act as a student.'
		if (defined $r->param('act_as_user') && !$authz->hasPermissions($userID, 'become_student'));
	push @error, 'You are not allowed to modify homework sets.'
		if ((defined $r->param('edit_sets') || defined $r->param('edit_set_for_users'))
			&& !$authz->hasPermissions($userID, 'modify_problem_sets'));
	push @error, 'You are not allowed to assign homework sets.'
		if ((defined $r->param('sets_assigned_to_user') || defined $r->param('users_assigned_to_set'))
			&& !$authz->hasPermissions($userID, 'assign_problem_sets'));
	push @error, 'You are not allowed to modify student data.'
		if ((defined $r->param('user_options') || defined $r->param('user_options'))
			&& !$authz->hasPermissions($userID, 'modify_student_data'));

	if (@error) {
		# Handle errors
		$self->addbadmessage(
			CGI::div({ class => 'd-flex flex-column gap-1' }, map { CGI::div($r->maketext($_)) } @error));
	} elsif ($module) {
		# Redirect to target page
		my $page = $urlpath->newFromModule($module, $r, %args);
		my $url  = $self->systemLink($page, params => \%params);
		$self->reply_with_redirect($url);
	}
}

sub body {
	my ($self)     = @_;
	my $r          = $self->r;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $authz      = $r->authz;
	my $courseName = $self->{courseName};
	my $user       = $r->param('user');

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		'You are not authorized to access the Instructor tools.')
		unless $authz->hasPermissions($user, 'access_instructor_tools');

	print CGI::p(
		$r->maketext(
			'Use the interface below to quickly access commonly-used instructor tools, '
				. 'or select a tool from the list to the left.'
		),
		CGI::br(),
		$r->maketext('Select user(s) and/or set(s) below and click the action button of your choice.')
	);

	# Get all users except the set level proctors, and restrict to the sections or recitations that are allowed for the
	# user if such restrictions are defined.  This list is sorted by last_name, then first_name, then user_id.
	my @Users = $db->getUsersWhere(
		{
			user_id => { not_like => 'set_id:%' },
			$ce->{viewable_sections}{$user} || $ce->{viewable_recitations}{$user}
			? (
				-or => [
					$ce->{viewable_sections}{$user}    ? (section    => $ce->{viewable_sections}{$user})    : (),
					$ce->{viewable_recitations}{$user} ? (recitation => $ce->{viewable_recitations}{$user}) : ()
				]
				)
			: ()
		},
		[qw/last_name first_name user_id/]
	);

	my @GlobalSets = $db->getGlobalSetsWhere();

	my @selected_users = $r->param('selected_users');
	my @selected_sets  = $r->param('selected_sets');

	print CGI::start_form({ method => 'post', id => 'instructor-tools-form', action => $r->uri() });
	print $self->hidden_authen_fields();

	print CGI::div(
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
					request         => $r,
					default_sort    => 'lnfn',
					default_format  => 'lnfn_uid',
					default_filters => ['all'],
					size            => 10,
					multiple        => 1,
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
					request         => $r,
					default_sort    => 'set_id',
					default_format  => 'sid',
					default_filters => ['all'],
					size            => 10,
					multiple        => 1,
				},
				@GlobalSets
			)
		)
		),
		CGI::div(
			{ class => 'row gx-3' },
			CGI::div(
				{ class => 'col-xl-5 col-md-6 mb-2' },
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name              => 'sets_assigned_to_user',
						label             => $r->maketext('View/Edit'),
						class             => 'btn btn-sm btn-secondary',
						data_users_needed => 'exactly one',
						data_error_users  => $r->maketext(E_ONE_USER)
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('all set dates for one <b>user</b>')
					)
				),
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name       => 'edit_users',
						label      => $r->maketext('Edit'),
						class      => 'btn btn-sm btn-secondary',
						formaction => $self->systemLink($r->urlpath->newFromModule(
							'WeBWorK::ContentGenerator::Instructor::UserList',
							$r, courseID => $self->{courseName}
						)),
						data_users_needed => 'at least one',
						data_error_users  => $r->maketext(E_MIN_ONE_USER)
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('class list data for selected <b>users</b>')
					)
				),
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name              => 'user_stats',
						label             => $r->maketext('Statistics'),
						class             => 'btn btn-sm btn-secondary',
						data_users_needed => 'exactly one',
						data_error_users  => $r->maketext(E_ONE_USER)
					}),
					CGI::span({ class => 'input-group-text' }, $r->maketext('or')),
					CGI::submit({
						name              => 'user_progress',
						label             => $r->maketext('progress'),
						class             => 'btn btn-sm btn-secondary',
						data_users_needed => 'exactly one',
						data_error_users  => $r->maketext(E_ONE_USER)
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('for one <b>user</b>')
					)
				),
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name              => 'user_options',
						label             => $r->maketext('Change Password'),
						class             => 'btn btn-sm btn-secondary',
						data_users_needed => 'exactly one',
						data_error_users  => $r->maketext(E_ONE_USER)
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('for one <b>user</b>')
					)
				),
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name  => 'add_users',
						label => $r->maketext('Add'),
						class => 'btn btn-sm btn-secondary'
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('new users')
					)
				),
			),
			CGI::div(
				{ class => 'col-xl-5 col-md-6 mb-2 font-sm' },
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name             => 'users_assigned_to_set',
						label            => $r->maketext('View/Edit'),
						class            => 'btn btn-sm btn-secondary',
						data_sets_needed => 'exactly one',
						data_error_sets  => $r->maketext(E_ONE_SET)
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('all users for one <b>set</b>')
					)
				),
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name             => 'edit_sets',
						label            => $r->maketext('Edit'),
						class            => 'btn btn-sm btn-secondary',
						data_sets_needed => 'exactly one',
						data_error_sets  => $r->maketext(E_ONE_SET)
					}),
					CGI::span(
						{ class => 'input-group-text', style => 'white-space:pre;' },
						$r->maketext('one <b>set</b>')
					),
					CGI::span({ class => 'input-group-text' }, $r->maketext('or')),
					CGI::submit({
						name             => 'prob_lib',
						label            => $r->maketext('add problems'),
						class            => 'btn btn-sm btn-secondary',
						data_sets_needed => 'exactly one',
						data_error_sets  => $r->maketext(E_ONE_SET)
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('to one <b>set</b>')
					)
				),
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name             => 'set_stats',
						label            => $r->maketext('Statistics'),
						class            => 'btn btn-sm btn-secondary',
						data_sets_needed => 'exactly one',
						data_error_sets  => $r->maketext(E_ONE_SET)
					}),
					CGI::span({ class => 'input-group-text' }, $r->maketext('or')),
					CGI::submit({
						name             => 'set_progress',
						label            => $r->maketext('progress'),
						class            => 'btn btn-sm btn-secondary',
						data_sets_needed => 'exactly one',
						data_error_sets  => $r->maketext(E_ONE_SET)
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('for one <b>set</b>')
					)
				),
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name       => 'score_sets',
						label      => $r->maketext('Score'),
						class      => 'btn btn-sm btn-secondary',
						formaction => $self->systemLink($r->urlpath->newFromModule(
							'WeBWorK::ContentGenerator::Instructor::Scoring',
							$r, courseID => $self->{courseName}
						)),
						data_sets_needed => 'at least one',
						data_error_sets  => $r->maketext(E_MIN_ONE_SET)
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('selected <b>sets</b>')
					)
				),
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name                        => 'create_set',
						label                       => $r->maketext('Create'),
						class                       => 'btn btn-sm btn-secondary',
						data_set_name_needed        => 'true',
						data_error_set_name         => $r->maketext(E_SET_NAME),
						data_error_invalid_set_name => $r->maketext(E_BAD_NAME)
					}),
					CGI::label({ for => 'new_set_name', class => 'input-group-text' }, $r->maketext('new set:')),
					CGI::textfield({
						name        => 'new_set_name',
						id          => 'new_set_name',
						placeholder => $r->maketext("Name for new set here"),
						size        => 20,
						class       => 'form-control form-control-sm'
					})
				)
			)
		),
		CGI::div(
			{ class => 'row gx-3' },
			CGI::div(
				{ class => 'col-xl-4 col-md-6 offset-md-3' },
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						# This name is the same as the name of the submit button in Assigner.pm and the form is
						# directly submitted to that module without modification.
						name       => 'assign',
						label      => $r->maketext('Assign'),
						class      => 'btn btn-sm btn-secondary',
						formaction => $self->systemLink($r->urlpath->newFromModule(
							'WeBWorK::ContentGenerator::Instructor::Assigner',
							$r, courseID => $self->{courseName}
						)),
						data_users_needed => 'at least one',
						data_error_users  => $r->maketext(E_MIN_ONE_USER),
						data_sets_needed  => 'at least one',
						data_error_sets   => $r->maketext(E_MIN_ONE_SET)
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('selected <b>users</b> to selected <b>sets</b>')
					)
				),
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name              => 'act_as_user',
						label             => $r->maketext('Act as'),
						class             => 'btn btn-sm btn-secondary',
						data_users_needed => 'exactly one',
						data_error_users  => $r->maketext(E_ONE_USER),
						data_sets_needed  => 'at most one',
						data_error_sets   => $r->maketext(E_MAX_ONE_SET)
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('one <b>user</b> (on one <b>set</b>)')
					)
				),
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name              => 'edit_set_for_users',
						label             => $r->maketext('Edit'),
						class             => 'btn btn-sm btn-secondary',
						data_users_needed => 'at least one',
						data_error_users  => $r->maketext(E_MIN_ONE_USER),
						data_sets_needed  => 'exactly one',
						data_error_sets   => $r->maketext(E_ONE_SET)
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('one <b>set</b> for  <b>users</b>')
					)
				),
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::submit({
						name  => 'email_users',
						label => $r->maketext('Email'),
						class => 'btn btn-sm btn-secondary'
					}),
					CGI::span(
						{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
						$r->maketext('your students')
					)
				),
				(
					$authz->hasPermissions($user, 'manage_course_files')
					? CGI::div(
						{ class => 'input-group input-group-sm mb-2' },
						CGI::submit({
							name  => 'transfer_files',
							label => $r->maketext('Transfer'),
							class => 'btn btn-sm btn-secondary'
						}),
						CGI::span(
							{ class => 'input-group-text flex-grow-1', style => 'white-space:pre;' },
							$r->maketext('course files')
						)
					)
					: ()
				)
			)
		);

	print CGI::end_form();

	return '';
}

sub output_JS {
	my $self = shift;
	my $ce   = $self->r->ce;

	print CGI::script({ src => getAssetURL($ce, 'js/apps/InstructorTools/instructortools.js'), defer => undef }, '');

	return '';
}

1;
