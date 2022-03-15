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

package WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SetsAssignedToUsers - List and edit which
sets are assigned to a given user.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;

sub initialize {
	my ($self)     = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $db         = $r->db;
	my $authz      = $r->authz;

	my $userID     = $urlpath->arg("userID");
	my $user       = $r->param("user");

	# check authorization
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	return unless $authz->hasPermissions($user, "assign_problem_sets");

	# Get a list of all set records sorted by set_id.
	$self->{set_records} = [ $db->getGlobalSetsWhere({}, 'set_id') ];

	if (defined $r->param("assignToAll")) {
		$self->assignAllSetsToUser($userID);
		debug("assignAllSetsToUser($userID)");
		$self->addgoodmessage($r->maketext('User has been assigned to all current sets.'));
		debug("done assignAllSetsToUsers($userID)");
	} elsif (defined $r->param('unassignFromAll')
		&& defined($r->param('unassignFromAllSafety'))
		&& $r->param('unassignFromAllSafety') == 1)
	{
		$self->addgoodmessage($r->maketext('User has been unassigned from all sets.'));
		$self->unassignAllSetsFromUser($userID);
	} elsif (defined $r->param('assignToSelected')) {
		# Create hash for checking if a set is selected.
		my %selectedSets = map { $_ => 1 } $r->param("selected");

		# get current user
		my $User = $db->getUser($userID); # checked
		die "record not found for $userID.\n" unless $User;

		$self->addgoodmessage($r->maketext("User's sets have been reassigned."));

		my %userSets = map { $_ => 1 } $db->listUserSets($userID);

		# go through each possible set
		foreach my $setRecord (@{ $self->{set_records} }) {
			my $setID = $setRecord->set_id;
			# does the user want it to be assigned to the selected user
			if (exists $selectedSets{$setID}) {
				unless ($userSets{$setID}) {	# skip users already in the set
					debug("assignSetToUser($userID, $setID)");
					$self->assignSetToUser($userID, $setRecord);
					debug("done assignSetToUser($userID, $setID)");
				}
			} else {
				# user asked to NOT have the set assigned to the selected user
				next unless $userSets{$setID};	# skip users not in the set
				$db->deleteUserSet($userID, $setID);
			}
		}
	} elsif (defined $r->param("unassignFromAll")) {
	   # no action taken
	   $self->addbadmessage($r->maketext('No action taken'));
	}
}

sub getUserName {
	my ($self, $pathUserName) = @_;

	if (ref $pathUserName eq "HASH") {
		$pathUserName = undef;
	}

	return $pathUserName;
}

sub body {
	my ($self)      = @_;
	my $r           = $self->r;
	my $urlpath     = $r->urlpath;
	my $db          = $r->db;
	my $ce          = $r->ce;
	my $authz       = $r->authz;
	my $courseName  = $urlpath->arg('courseID');
	my $webworkRoot = $ce->{webworkURLs}->{root};
	my $userID      = $urlpath->arg('userID');

	my $user                   = $r->param('user');
	my $setsAssignedToUserPage = $urlpath->newFromModule(
		$urlpath->module, $r,
		courseID => $courseName,
		userID   => $userID
	);
	my $setsAssignedToUserURL = $self->systemLink($setsAssignedToUserPage, authen => 0);

	# check authorization
	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		'You are not authorized to access the Instructor tools.')
		unless $authz->hasPermissions($user, 'access_instructor_tools');

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' }, 'You are not authorized to assign homework sets.')
		unless $authz->hasPermissions($user, 'assign_problem_sets');

	print CGI::start_form(
		{ id => 'set-user-form', name => 'set-user-form', method => 'post', action => $setsAssignedToUserURL });
	print $self->hidden_authen_fields;

	print CGI::div({ class => 'my-2' },
		CGI::submit({ name => 'assignToAll', value => 'Assign All Sets', class => 'btn btn-primary' }));

	print CGI::div(
		{ class => 'alert alert-danger p-1 mb-2 fs-6' },
		CGI::div({ class => 'mb-1' }, 'Do not uncheck a set unless you know what you are doing.'),
		CGI::div('There is NO undo for unassigning a set.')
	);

	print CGI::div(
		{ class => 'fs-6 mb-2' },
		'When you uncheck a homework set (and save the changes), you destroy all
		      of the data for that set for this student.   If You then need to
		      reassign the set and the student will receive new versions of the problems.
		      Make sure this is what you want to do before unchecking sets.'
	);

	print CGI::start_div({ class => 'table-responsive' }),
		CGI::start_table({ class => 'table table-bordered table-sm font-sm w-auto' });
	print CGI::Tr(CGI::th({ class => 'text-center' }, 'Assigned'),
		CGI::th([ 'Set Name', 'Close Date', '' ]));

	foreach my $Set (@{ $self->{set_records} }) {
		my $setID = $Set->set_id;

		my $UserSet           = $db->getUserSet($userID, $setID);
		my $currentlyAssigned = defined $UserSet;

		my $prettyDate;
		if ($currentlyAssigned and $UserSet->due_date) {
			$prettyDate = $self->formatDateTime($UserSet->due_date, '', 'datetime_format_short', $ce->{language});
		} else {
			$prettyDate = $self->formatDateTime($Set->due_date, '', 'datetime_format_short', $ce->{language});
		}

		# URL to edit user-specific set data
		my $setListPage = $urlpath->new(
			type => 'instructor_set_detail',
			args => {
				courseID => $courseName,
				setID    => $setID
			}
		);
		my $url = $self->systemLink($setListPage, params => { editForUser => $userID });
		print CGI::Tr(
			CGI::td(
				{ class => 'text-center' },
				CGI::checkbox({
					type    => 'checkbox',
					name    => 'selected',
					checked => $currentlyAssigned,
					value   => $setID,
					label   => '',
					class   => 'form-check-input'
				})
			),
			CGI::td($setID),
			CGI::td({ class => 'text-center' }, $prettyDate),
			CGI::td($currentlyAssigned ? CGI::a({ href => $url }, 'Edit user-specific set data') : '')
		);
	}
	print CGI::end_table(), CGI::end_div();
	print CGI::submit({ name => 'assignToSelected', value => 'Save', class => 'btn btn-primary' });

	print CGI::hr()
		. CGI::div(
			CGI::div(
				{ class => 'alert alert-danger p-1 mb-3' },
				$r->maketext(
					'There is NO undo for this function.  '
						. 'Do not use it unless you know what you are doing!  When you unassign '
						. 'sets using this button, or by unchecking their set names, you destroy all '
						. 'of the data for those sets for this student.',
				)
			),
			CGI::div(
				{ class => 'd-flex align-items-center' },
				CGI::submit({
					name  => "unassignFromAll",
					value => $r->maketext("Unassign All Sets"),
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

	return '';
}

sub title {
        my ($self) = @_;
        my $r = $self->{r};
        my $userID = $r->urlpath->arg("userID");

        return "Assigned Sets for user $userID";
}

1;
