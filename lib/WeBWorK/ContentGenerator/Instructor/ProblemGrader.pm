################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemGrader - This is a page for
manually grading webwork problems.

=cut

use HTML::Entities;

use WeBWorK::Utils::JITAR qw(jitar_id_to_seq);
use WeBWorK::Utils::Rendering qw(renderPG);
use WeBWorK::Utils::Sets qw(get_test_problem_position format_set_name_display);

async sub initialize ($c) {
	my $authz      = $c->authz;
	my $db         = $c->db;
	my $ce         = $c->ce;
	my $courseName = $c->stash('courseID');
	my $setID      = $c->stash('setID');
	my $problemID  = $c->stash('problemID');
	my $userID     = $c->param('user');

	# Make sure these are defined for the template.
	$c->stash->{set}          = $db->getGlobalSet($setID);
	$c->stash->{problem}      = $db->getGlobalProblem($setID, $problemID);
	$c->stash->{users}        = [];
	$c->stash->{haveSections} = 0;

	return
		unless $c->stash->{set}
		&& $c->stash->{problem}
		&& $authz->hasPermissions($userID, 'access_instructor_tools')
		&& $authz->hasPermissions($userID, 'score_sets');

	# Get all users of the set, and restrict to the sections or recitations that are allowed for the user if such
	# restrictions are defined.  For gateway sets only get users for which versions exist.  The users are sorted by
	# section, last name, first name, and then user_id.
	$c->stash->{users} = [
		$db->getUsersWhere(
			{
				user_id => [
					map { $_->[0] } (
						$c->stash->{set}->assignment_type =~ /gateway/
						? $db->listSetVersionsWhere({ set_id => { like => "$setID,v\%" } })
						: $db->listUserSetsWhere({ set_id => $setID })
					)
				],
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
			[qw/section last_name first_name user_id/]
		)
	];

	# First process student problems and answers and cache relevant data used both for
	# saving grades and displaying the grader table.
	for my $user (@{ $c->stash->{users} }) {
		$user->{displayName} =
			$user->last_name || $user->first_name ? $user->last_name . ', ' . $user->first_name : $user->user_id;
		$c->stash->{haveSections} = 1 if $user->section;

		if ($c->stash->{set}->assignment_type =~ /gateway/) {
			$user->{data} = [
				map { { problem => $_ } } $db->getProblemVersionsWhere(
					{ user_id => $user->user_id, problem_id => $problemID, set_id => { like => "$setID,v\%" } }
				)
			];
		} else {
			$user->{data} =
				[ map { { problem => $_ } } $db->getUserProblem($user->user_id, $setID, $problemID) ];
		}

		for (@{ $user->{data} }) {
			next unless defined $_->{problem};
			my $versionID = ref($_->{problem}) =~ /::ProblemVersion/ ? $_->{problem}->version_id : 0;
			my $userPastAnswerID =
				$db->latestProblemPastAnswer($user->user_id, $setID . ($versionID ? ",v$versionID" : ''), $problemID);
			$_->{past_answer} = $db->getPastAnswer($userPastAnswerID) if ($userPastAnswerID);
			($_->{problemNumber}, $_->{pageNumber}) = get_test_problem_position($db, $_->{problem}) if $versionID;

		}
	}

	# Update grades if saving.
	if ($c->param('assignGrades')) {
		$c->addgoodmessage($c->maketext('Grades have been saved for all current users.'));

		for my $user (@{ $c->stash->{users} }) {
			my $userID = $user->user_id;
			for (@{ $user->{data} }) {
				next unless defined $_->{problem};

				my $versionID = ref($_->{problem}) =~ /::ProblemVersion/ ? $_->{problem}->version_id : 0;

				# Only save if there is a change made.  This prevents the "needs_grading" flag from being removed until
				# the instructor explicitly grades the problem for this student.
				next
					unless (defined $c->param("$userID.$versionID.score")
						&& $c->param("$userID.$versionID.score") / 100 != $_->{problem}->status)
					|| $c->param("$userID.$versionID.mark_correct")
					|| ($c->param("$userID.$versionID.comment") && defined $_->{past_answer});

				# Update grades and set flags.
				$_->{problem}{flags} =~ s/:needs_grading$//;
				if ($c->param("$userID.$versionID.mark_correct")) {
					$_->{problem}->status(1);
				} elsif (defined $c->param("$userID.$versionID.score")) {
					my $newscore = $c->param("$userID.$versionID.score") / 100;
					if ($newscore != $_->{problem}->status) { $_->{problem}->status($newscore); }
				}

				if   ($versionID) { $db->putProblemVersion($_->{problem}); }
				else              { $db->putUserProblem($_->{problem}); }

				# Save the instructor comment to the latest past answer.
				if ($c->param("$userID.$versionID.comment") && defined $_->{past_answer}) {
					$_->{past_answer}->comment_string($c->param("$userID.$versionID.comment"));
					$db->putPastAnswer($_->{past_answer});
				}
			}
		}
	}

	return
		unless @{ $c->stash->{users} }
		&& @{ $c->stash->{users}[0]{data} }
		&& defined $c->stash->{users}[0]{data}[0]{problem};

	# Render the first student's problem.
	my ($set, $problem);
	if ($c->stash->{set}->assignment_type =~ /gateway/) {
		$set = $db->getMergedSetVersion($c->stash->{users}[0]->user_id,
			$setID, $c->stash->{users}[0]{data}[0]{problem}->version_id);
		$problem = $db->getMergedProblemVersion($c->stash->{users}[0]->user_id,
			$setID, $c->stash->{users}[0]{data}[0]{problem}->version_id, $problemID);
	} else {
		$set     = $db->getMergedSet($c->stash->{users}[0]->user_id, $setID);
		$problem = $db->getMergedProblem($c->stash->{users}[0]->user_id, $setID, $problemID);
	}

	# These should always be defined except for some odd edge cases.
	return unless $set && $problem;

	# Get the current user for the displayMode.
	my $user = $db->getUser($userID);

	# Render the problem text.
	$c->stash->{pg} = await renderPG(
		$c,
		$c->stash->{users}[0],
		$set, $problem,
		$set->psvn,
		{},
		{
			displayMode              => $user->displayMode || $c->ce->{pg}{options}{displayMode},
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

sub page_title ($c) {
	my $problemID = $c->stash('problemID');
	if ($c->stash->{set} && $c->stash->{set}->assignment_type eq 'jitar') {
		$problemID = join('.', jitar_id_to_seq($problemID));
	}
	return $c->maketext('Manual Grader for [_1]: Problem [_2]',
		$c->tag('span', dir => 'ltr', format_set_name_display($c->stash->{set}->set_id)), $problemID);
}

sub siblings ($c) {
	return $c->include('ContentGenerator/Instructor/ProblemGrader/siblings');
}

1;
