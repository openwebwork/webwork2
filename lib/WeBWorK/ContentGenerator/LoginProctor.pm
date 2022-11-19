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

package WeBWorK::ContentGenerator::LoginProctor;
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::LoginProctor - display a login form for
GatewayQuiz proctored tests.

=cut

use strict;
use warnings;

use Future::AsyncAwait;

use WeBWorK::Utils::Rendering qw(renderPG);
use WeBWorK::DB::Utils qw(grok_vsetID);

async sub initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;

	my $userID          = $r->param('user');
	my $effectiveUserID = $r->param('effectiveUser') || '';

	$self->{effectiveUser} = $r->db->getUser($effectiveUserID);

	# The user set is needed to check for a set-restricted login proctor, and to show and possibly save the submission
	# time.  To get the user set, the set name and version number are needed.  Attempt to obtain those from the url path
	# setID.  Otherwise, use the highest version number.
	($r->stash->{setID}, my $versionNum) = grok_vsetID($r->urlpath->arg('setID'));
	my $noSetVersions = 0;
	if (!$versionNum) {
		# Get a list of all available versions.
		my @setVersions = $db->listSetVersions($effectiveUserID, $r->stash->{setID});
		if (@setVersions) {
			$versionNum = $setVersions[-1];
		} else {
			# If there are no versions yet, start with the first one.
			$versionNum    = 1;
			$noSetVersions = 1;
		}
	}

	# Get the merged set. If a test is being graded or this is a new version, get the merged template set instead.
	$r->stash->{userSet} =
		$noSetVersions || !$r->param('submitAnswers')
		? $db->getMergedSet($effectiveUserID, $r->stash->{setID})
		: $db->getMergedSetVersion($effectiveUserID, $r->stash->{setID}, $versionNum);

	if (defined $r->stash->{userSet}) {
		# If the set is being submitted, then save the submission time.
		if ($r->param('submitAnswers')) {
			# This should never happen.
			die 'Request to grade a set version before any tests have been taken.' if $noSetVersions;

			# Determine if answers can be recorded, and set last_attempt_time if appropriate.
			if (WeBWorK::ContentGenerator::GatewayQuiz::can_recordAnswers(
				$self,
				$db->getUser($userID),
				$db->getPermissionLevel($userID),
				$self->{effectiveUser},
				$r->stash->{userSet},
				$db->getMergedProblemVersion($effectiveUserID, $r->stash->{setID}, $versionNum, 1)
			))
			{
				$r->stash->{userSet}->version_last_attempt_time(int($r->submitTime));
				# FIXME: This saves all of the merged set data into the set_user table.  We live with this in other
				# places for versioned sets, but it's not ideal.
				$db->putSetVersion($r->stash->{userSet});
			}
		}
	}

	# Get problem set info.
	my $set = $r->authz->{merged_set};
	return unless $set;

	# Hack to prevent errors from uninitialized set_headers.
	$set->set_header('defaultHeader') unless $set->set_header =~ /\S/;

	$self->{pg} = await renderPG(
		$r,
		$self->{effectiveUser},
		$set,
		WeBWorK::DB::Record::UserProblem->new(
			problem_id  => 0,
			set_id      => $set->set_id,
			login_id    => $self->{effectiveUser}->user_id,
			source_file => $set->set_header eq 'defaultHeader'
			? $ce->{webworkFiles}{screenSnippets}{setHeader}
			: $set->set_header
		),
		$set->psvn,
		{},
		{ displayMode => $r->param('displayMode') || $ce->{pg}{options}{displayMode} }
	);

	return;
}

sub info {
	my ($self) = @_;
	return '' unless $self->{pg};
	return $self->r->c($self->r->tag('h2', $self->r->maketext('Set Info')), $self->{pg}{body_text})->join('');
}

1;
