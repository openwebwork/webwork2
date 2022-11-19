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

package WeBWorK::ContentGenerator::Instructor::ProblemGrader;
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemGrader - This is a page for
manually grading webwork problems.

=cut

use strict;
use warnings;

use Future::AsyncAwait;
use HTML::Entities;

use WeBWorK::Utils qw(sortByName wwRound);
use WeBWorK::Utils::Rendering qw(renderPG);
use WeBWorK::PG;

async sub initialize {
	my ($self)     = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $authz      = $r->authz;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $courseName = $urlpath->arg('courseID');
	my $setID      = $urlpath->arg('setID');
	my $problemID  = $urlpath->arg('problemID');
	my $userID     = $r->param('user');

	return unless $authz->hasPermissions($userID, 'access_instructor_tools');
	return unless $authz->hasPermissions($userID, 'score_sets');

	# Get all users except the set level proctors, and restrict to the sections or recitations that are allowed for the
	# user if such restrictions are defined.  The users are sorted first by section, then by last name.
	$self->{users} = [
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
			[qw/section last_name/]
		)
	];

	# First process student problems and answers and cache relevant data used both for
	# saving grades and displaying the grader table.
	for my $user (@{ $self->{users} }) {
		$user->{data}{problem} = $db->getUserProblem($user->user_id, $setID, $problemID);
		next unless $user->{data}{problem};

		my $userPastAnswerID = $db->latestProblemPastAnswer($courseName, $user->user_id, $setID, $problemID);
		$user->{data}{past_answer} = $db->getPastAnswer($userPastAnswerID)
			if ($userPastAnswerID && $user->{data}{problem});
	}

	# Update grades if saving.
	if ($r->param('assignGrades')) {
		$self->addmessage($r->tag(
			'p',
			class => 'alert alert-success p-1 my-2',
			$r->maketext('Grades have been saved for all current users.')
		));

		for my $user (@{ $self->{users} }) {
			my $userID      = $user->user_id;
			my $userProblem = $user->{data}{problem};
			next unless $userProblem && defined $r->param("$userID.score");

			# Update grades and set flags.
			$userProblem->{flags} =~ s/needs_grading/graded/;
			if ($r->param("$userID.mark_correct")) {
				$userProblem->status(1);
			} else {
				my $newscore = $r->param("$userID.score") / 100;
				if ($newscore != $userProblem->status) {
					$userProblem->status($newscore);
				}
			}

			$db->putUserProblem($userProblem);

			# Save the instructor comment to the latest past answer.
			if (my $comment = $r->param("$userID.comment") && defined $user->{data}{past_answer}) {
				$user->{data}{past_answer}->comment_string($comment);
				warn q{Couldn't save comment} unless $db->putPastAnswer($user->{data}{past_answer});
			}
		}
	}

	my $user = $db->getUser($userID);
	return unless $user;    # This should never happen at this point.

	$self->{set}     = $db->getMergedSet($userID, $setID);
	$self->{problem} = $db->getMergedProblem($userID, $setID, $problemID);

	return unless $self->{set} && $self->{problem};

	# Render the problem text.
	$self->{pg} = await renderPG(
		$r, $user,
		$self->{set},
		$self->{problem},
		$self->{set}->psvn,
		{ WeBWorK::Form->new_from_paramable($r)->Vars },
		{
			displayMode              => $user->displayMode || $r->ce->{pg}{options}{displayMode},
			showHints                => 0,
			showSolutions            => 0,
			refreshMath2img          => 0,
			processAnswers           => 1,
			permissionLevel          => $db->getPermissionLevel($userID)->permission,
			effectivePermissionLevel => $db->getPermissionLevel($userID)->permission,
			isInstructor             => 1
		},
	);

	return;
}

1;
