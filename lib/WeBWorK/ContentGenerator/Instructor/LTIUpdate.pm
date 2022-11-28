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

# This page is for triggering LTI grade updates

package WeBWorK::ContentGenerator::Instructor::LTIUpdate;
use parent qw(WeBWorK::ContentGenerator);

use strict;
use warnings;

use WeBWorK::Utils(qw(format_set_name_display));

sub initialize {
	my $self = shift;
	my $r    = $self->r;
	my $db   = $r->db;
	my $ce   = $r->ce;
	my $user = $r->param('user');

	# Check permissions
	return unless $r->authz->hasPermissions($user, 'score_sets');
	return unless $ce->{LTIGradeMode};

	return unless $r->param('updateLTI');

	my $setID       = $r->param('updateSetID')  || 'All Sets';
	my $userID      = $r->param('updateUserID') || 'All Users';
	my $prettySetID = format_set_name_display($setID);

	# Test if setID and userID are valid.
	unless ($userID eq 'All Users' || $db->getUser($userID)) {
		$self->{updateMessage} = $r->maketext('Update aborted. Invalid user [_1].', $userID);
		return;
	}
	unless ($ce->{LTIGradeMode} eq 'course' || $setID eq 'All Sets' || $db->getGlobalSet($setID)) {
		$self->{updateMessage} = $r->maketext('Update aborted. Invalid set [_1].', $prettySetID);
		return;
	}

	my @updateParms;
	if ($setID eq 'All Sets' && $userID eq 'All Users') {
		@updateParms = ('all');
		$self->{updateMessage} =
			$ce->{LTIGradeMode} eq 'homework'
			? $r->maketext('LTI update of all users and sets started.')
			: $r->maketext('LTI update of all users started.');
	} elsif ($setID eq 'All Sets' && $ce->{LTIGradeMode} eq 'homework') {
		@updateParms = ('user', $userID);
		$self->{updateMessage} = $r->maketext('LTI update of user [_1] started.', $userID);
	} elsif ($userID eq 'All Users') {
		@updateParms = ('set', $setID);
		$self->{updateMessage} = $r->maketext('LTI update of set [_1] started.', $prettySetID);
	} elsif ($ce->{LTIGradeMode} eq 'homework') {
		@updateParms = ('user_set', $userID, $setID);
		$self->{updateMessage} = $r->maketext('LTI update of user [_1] and set [_2] started.', $userID, $prettySetID);
	} else {
		# Abort update. A post with a valid setID was sent in course LTIGradeMode,
		# but the page shouldn't allow this. Don't set an updateMessage for this case.
		return;
	}

	my $grader = WeBWorK::Authen::LTIAdvanced::SubmitGrade->new($r);
	$grader->mass_update(@updateParms);
}

sub title {
	my $self = shift;
	my $r    = $self->r;

	return $r->maketext('LTI Grade Update');
}

sub body {
	my $self  = shift;
	my $r     = $self->r;
	my $db    = $r->db;
	my $ce    = $r->ce;
	my $authz = $r->authz;
	my $user  = $r->param('user');

	return CGI::div({ class => 'alert alert-danger p-1' }, $r->maketext('You are not authorized to update lti scores'))
		unless $authz->hasPermissions($user, 'score_sets');

	return CGI::div({ class => 'alert alert-danger p-1' },
		$r->maketext('LTI grade passback is not enabled for this course'))
		unless $ce->{LTIGradeMode};

	# Update message.
	print CGI::div({ class => 'alert alert-warning p-1' }, $self->{updateMessage}) if defined($self->{updateMessage});

	my $gradeMode      = $ce->{LTIGradeMode};
	my $lastUpdate     = $db->getSettingValue('LTILastUpdate') || 0;
	my $updateInterval = $ce->{LTIMassUpdateInterval}          || -1;

	# Print status table
	print CGI::div(
		{ class => 'table-responsive' },
		CGI::table(
			{ class => 'table table-bordered w-auto' },
			CGI::Tr(CGI::th($r->maketext('LTI Grade Mode')), CGI::td($gradeMode)),
			CGI::Tr(
				CGI::th($r->maketext('Update Interval')),
				CGI::td($updateInterval > -1 ? $self->format_interval($updateInterval) : $r->maketext('Never'))
			),
			CGI::Tr(
				CGI::th($r->maketext('Last Full Update')),
				CGI::td(
					$lastUpdate
					? $self->formatDateTime($lastUpdate, 0, $ce->{studentDateDisplayFormat})
					: $r->maketext('Never')
				)
			),
			$updateInterval > -1 ? CGI::Tr(
				CGI::th($r->maketext('Next Update')),
				CGI::td($self->formatDateTime($lastUpdate + $updateInterval, 0, $ce->{studentDateDisplayFormat})),
			) : '',
		)
	);

	print CGI::h2($r->maketext('Start LTI Grade Update'));
	my @sets  = sort($db->listGlobalSets);
	my @users = sort($db->listUsers);

	print CGI::start_form({
		method => 'POST',
		action => $r->uri,
		id     => 'updateLTIForm',
		name   => 'updateLTIForm',
	}),
		CGI::div(
			{ class => 'row mb-3' },
			CGI::label(
				{ for => 'updateUserID', class => 'col-auto col-form-label fw-bold' },
				$r->maketext('Update user:')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'updateUserID',
					name    => 'updateUserID',
					value   => [ 'All Users', @users ],
					default => 'All Users',
					class   => 'form-select',
					labels  => {
						'All Users' => $r->maketext('All Users'),
						map { $_ => $_ } @users
					}
				})
			)
		),
		$gradeMode eq 'homework'
		? CGI::div(
			{ class => 'row mb-3' },
			CGI::label(
				{ for => 'updateSetID', class => 'col-auto col-form-label fw-bold' },
				$r->maketext('Update set:')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'updateSetID',
					name    => 'updateSetID',
					value   => [ 'All Sets', @sets ],
					default => 'All Sets',
					class   => 'form-select',
					labels  => {
						'All Sets' => $r->maketext('All Sets'),
						map { $_ => format_set_name_display($_) } @sets
					}
				})
			)
		)
		: '',
		CGI::submit({
			id    => 'updateLTI',
			name  => 'updateLTI',
			label => $r->maketext('Update Grades'),
			class => 'btn btn-primary mb-3',
		}),
		CGI::end_form();

	return '';
}

sub format_interval {
	my $self    = shift;
	my $r       = $self->r;
	my $seconds = shift;
	my $minutes = int($seconds / 60);
	my $hours   = int($minutes / 60);
	my $days    = int($hours / 24);
	my $out     = '';

	return $r->maketext('0 seconds') unless $seconds > 0;

	$seconds = $seconds - 60 * $minutes;
	$minutes = $minutes - 60 * $hours;
	$hours   = $hours - 24 * $days;

	$out .= $r->maketext('[quant,_1,day]',    $days) . ' '    if $days;
	$out .= $r->maketext('[quant,_1,hour]',   $hours) . ' '   if $hours;
	$out .= $r->maketext('[quant,_1,minute]', $minutes) . ' ' if $minutes;
	$out .= $r->maketext('[quant,_1,second]', $seconds) . ' ' if $seconds;
	chop($out);

	return $out;
}

1;
