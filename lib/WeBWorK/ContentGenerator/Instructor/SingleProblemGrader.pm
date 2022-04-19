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

package WeBWorK::ContentGenerator::Instructor::SingleProblemGrader;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SingleProblemGrader is a module for
manually grading a single webwork problem.  It is displayed with the problem
when an instructor is acting as a student.

=cut

use WeBWorK::PG;
use WeBWorK::Localize;
use WeBWorK::Utils 'wwRound';
use CGI;

use strict;
use warnings;

sub new {
	my ($class, $r, $pg, $userProblem) = @_;
	$class = ref($class) ? ref($class) : $class;

	my $db        = $r->db;
	my $urlpath   = $r->urlpath;
	my $courseID  = $urlpath->arg('courseID');
	my $setID     = $userProblem->set_id;
	my $versionID = ref($userProblem) =~ /::ProblemVersion/ ? $userProblem->version_id : 0;
	my $studentID = $userProblem->user_id;
	my $problemID = $userProblem->problem_id;

	# Get the currently saved score.
	my $recordedScore = $userProblem->status;

	# Retrieve the latest past answer and comment (if any).
	my $userPastAnswerID =
		$db->latestProblemPastAnswer($courseID, $studentID, $setID . ($versionID ? ",v$versionID" : ''), $problemID);
	my $pastAnswer = $userPastAnswerID ? $db->getPastAnswer($userPastAnswerID) : 0;
	my $comment    = $pastAnswer       ? $pastAnswer->comment_string           : '';

	my $self = {
		pg             => $pg,
		course_id      => $courseID,
		student_id     => $studentID,
		problem_id     => $problemID,
		set_id         => $setID,
		version_id     => $versionID,
		recorded_score => $recordedScore,
		past_answer_id => $userPastAnswerID // 0,
		comment_string => $comment,
		maketext       => WeBWorK::Localize::getLoc($r->ce->{language})
	};
	bless $self, $class;

	return $self;
}

sub maketext {
	my $self = shift;
	return &{ $self->{maketext} }(@_);
}

# Output the problem grader.

sub insertGrader {
	my $self = shift;

	print CGI::start_div({ class => 'problem-grader' });
	print CGI::hr();
	print CGI::start_div({ class => 'problem-grader-table' });

	# Subscores for each answer in the problem.
	if (@{ $self->{pg}{flags}{ANSWER_ENTRY_ORDER} } > 1) {

		# Determine the scores and weights for each part of the problem.
		my $total = 0;
		my (@scores, @weights);
		for my $ans_id (@{ $self->{pg}{flags}{ANSWER_ENTRY_ORDER} }) {
			push(@scores,  wwRound(0, $self->{pg}{answers}{$ans_id}{score} * 100));
			push(@weights, $self->{pg}{answers}{$ans_id}{weight} // 1);
			$total += $weights[$#weights];
		}

		# Normalize the weights
		@weights = map { $_ / $total } @weights;

		for my $part (0 .. $#scores) {
			print CGI::div(
				{ class => 'row align-items-center mb-2' },
				CGI::label(
					{ class => 'col-fixed col-form-label' },
					$self->maketext('Answer [_1] Score (%):', $part + 1) . ' '
						. CGI::a(
						{
							class           => 'help-popup',
							data_bs_content => $self->maketext(
								'The initial value is the answer sub score for the answer '
									. 'that is currently shown.  If this is modified, it will be used to compute '
									. 'the total problem score below.  This score is not saved, and will reset to the '
									. 'score for the shown answer if the page is reloaded.'
							),
							data_bs_placement => 'top',
							data_bs_toggle    => 'popover'
						},
						CGI::i(
							{
								class       => 'icon fas fa-question-circle',
								aria_hidden => 'true',
								data_alt    => 'Help Icon'
							},
							''
						)
						)
					)
					. CGI::div(
					{ class => 'col-sm' },
					CGI::input({
						type         => 'number',
						min          => 0,
						max          => 100,
						autocomplete => 'off',
						class        => 'answer-part-score form-control form-control-sm w-auto d-inline',
						id => "score_problem$self->{problem_id}_$self->{pg}{flags}{ANSWER_ENTRY_ORDER}[$part]",
						data_problem_id    => $self->{problem_id},
						data_answer_labels => '["' . join('","', @{ $self->{pg}{flags}{ANSWER_ENTRY_ORDER} }) . '"]',
						data_weight        => $weights[$part],
						value              => $scores[$part],
						size               => 5
					})
						. '&nbsp'
						. $self->maketext('<b>Weight:</b> [_1]%', wwRound(2, $weights[$part] * 100))
					)
			);
		}
	}

	# Total problem score
	print CGI::div(
		{ class => 'row align-items-center mb-2' },
		CGI::label(
			{ class => 'col-fixed col-form-label' },
			$self->maketext('Problem Score (%):') . ' '
				. CGI::a(
				{
					class           => 'help-popup',
					data_bs_content =>
						$self->maketext('The initial value is the currently saved score for this student.')
						. (
						@{ $self->{pg}{flags}{ANSWER_ENTRY_ORDER} } > 1
						? ' '
							. $self->maketext(
							'This is the only part of the score that is actually saved. '
								. 'This is computed from the answer sub scores above using the weights shown if they '
								. 'are modified.  Alternatively, enter the score you want saved here '
								. '(the above sub scores will be ignored).'
							)
						: ''
						),
					data_bs_placement => 'top',
					data_bs_toggle    => 'popover'
				},
				CGI::i({ class => 'icon fas fa-question-circle', aria_hidden => 'true', data_alt => 'Help Icon' }, '')
					. CGI::span({ class => 'sr-only-glyphicon' }, 'Help Icon')
				)
			)
			. CGI::div(
			{ class => 'col-sm' },
			CGI::input({
				type            => 'number',
				id              => "score_problem$self->{problem_id}",
				class           => 'problem-score form-control form-control-sm w-auto d-inline',
				min             => 0,
				max             => 100,
				autocomplete    => 'off',
				data_problem_id => $self->{problem_id},
				value           => wwRound(0, $self->{recorded_score} * 100),
				size            => 5
			})
			)
	);

	# Instructor comment
	if ($self->{past_answer_id}) {
		print CGI::div(
			{ class => 'row' },
			CGI::label({ class => 'col-fixed col-form-label' }, $self->maketext('Comment:'))
				. CGI::div(
				{ class => 'col-sm' },
				CGI::textarea({
					id              => "comment_problem$self->{problem_id}",
					class           => 'grader-problem-comment form-control d-inline',
					data_problem_id => $self->{problem_id},
					value           => $self->{comment_string},
					rows            => 3
				}),
				CGI::input({
					class => 'preview btn btn-secondary mt-1',
					type  => 'button',
					value => $self->maketext('Preview Comment')
				})
				)
		);
	}

	# Save button
	print CGI::div(
		{ class => 'row align-items-center' },
		CGI::div(
			{ class => 'col-fixed mt-2' },
			CGI::input({
				class               => 'save-grade btn btn-secondary',
				type                => 'button',
				id                  => "save_grade_problem$self->{problem_id}",
				data_course_id      => $self->{course_id},
				data_student_id     => $self->{student_id},
				data_set_id         => $self->{set_id},
				data_version_id     => $self->{version_id},
				data_problem_id     => $self->{problem_id},
				data_past_answer_id => $self->{past_answer_id},
				value               => 'Save'
			}),
		),
		CGI::div(
			{ class => 'col-sm mt-2' },
			CGI::div({ id => "grader_messages_problem$self->{problem_id}", class => 'problem-grader-message' }, '')
		)
	);
	print CGI::end_div();
	print CGI::hr();
	print CGI::end_div();

	return '';
}

1;
