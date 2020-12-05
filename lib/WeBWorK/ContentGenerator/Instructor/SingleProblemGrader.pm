################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2020 The WeBWorK Project, http://openwebwork.sf.net/
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
	my ($class, $r, $pg, $userProblem, $formFields) = @_;
	$class = ref($class) ? ref($class) : $class;

	my $db = $r->db;
	my $urlpath = $r->urlpath;
	my $courseName = $urlpath->arg("courseID");
	my $setID = $urlpath->arg("setID");
	my $studentID = $userProblem->user_id;
	my $problemID = $userProblem->problem_id;

	# Get the currently saved score.
	my $recordedScore = $userProblem->status;

	# Retrieve the latest past answer and comment (if any).
	my $userPastAnswerID = $db->latestProblemPastAnswer($courseName, $studentID, $setID, $problemID);
	my $pastAnswer = $userPastAnswerID ? $db->getPastAnswer($userPastAnswerID) : 0;
	my $comment = $pastAnswer ? $pastAnswer->comment_string : "";

	# Save the grade and comment if this is a saveGrade submission.
	if ($r->param('saveGrade')) {
		$recordedScore = $formFields->{"problem$problemID.score"} / 100;
		$userProblem->status($recordedScore);
		if (ref($userProblem) =~ /.*::ProblemVersion$/) {
			$db->putProblemVersion($userProblem);
		} else {
			$db->putUserProblem($userProblem);
		}

		if ($pastAnswer) {
			$comment = $formFields->{"problem$problemID.comment"};
			$pastAnswer->comment_string($comment);
			$db->putPastAnswer($pastAnswer);
		}
	}

	my $self = {
		pg => $pg,
		prob_id => "problem$problemID",
		recorded_score => $recordedScore,
		have_past_answer => $pastAnswer ? 1 : 0,
		comment_string => $comment,
		maketext => WeBWorK::Localize::getLoc($r->ce->{language})
	};
	bless $self, $class;

	return $self;
}

# Output the problem grader.

sub insertGrader {
	my $self = shift;

	print CGI::start_div({ class => 'problem-grader' });
	print CGI::hr();
	print CGI::start_table({ class => "problem-grader-table" });

	# Subscores for each answer in the problem.
	if (@{$self->{pg}{flags}{ANSWER_ENTRY_ORDER}} > 1) {

		# Determine the scores and weights for each part of the problem.
		my $total = 0;
		my (@scores, @weights);
		for my $ans_id (@{$self->{pg}{flags}{ANSWER_ENTRY_ORDER}}) {
			push(@scores, wwRound(0, $self->{pg}{answers}{$ans_id}{score} * 100));
			push(@weights, $self->{pg}{answers}{$ans_id}{weight} // 1);
			$total += $weights[$#weights];
		}

		# Normalize the weights
		@weights = map { $_ / $total } @weights;

		for my $part (0 .. $#scores) {
			print CGI::Tr({ align => "left" },
				CGI::th($self->{maketext}("Answer [_1] Score (%):", $part + 1)) .
				CGI::td(CGI::input({ type => 'number',
							min => 0, max => 100, autocomplete => "off",
							class => 'answer-part-score',
							name => "$self->{prob_id}.$self->{pg}{flags}{ANSWER_ENTRY_ORDER}[$part].score",
							data_prob_id => $self->{prob_id},
							data_answer_labels => '["' . join('","', @{$self->{pg}{flags}{ANSWER_ENTRY_ORDER}}) . '"]',
							data_weight => $weights[$part],
							value => $scores[$part],
							size => 5 }) . "&nbsp" .
					$self->{maketext}("<b>Weight:</b> [_1]%", wwRound(2, $weights[$part] * 100)))
			);
		}
	}

	# Total problem score
	print CGI::Tr({ align => "left" },
		CGI::th($self->{maketext}("Problem Score (%):")) .
		CGI::td(CGI::input({ type => 'number', name => "$self->{prob_id}.score", class => 'problem-score',
					min => 0, max => 100, autocomplete => "off",
					value => wwRound(0, $self->{recorded_score} * 100), size => 5 }))
	);

	# Instructor comment
	if ($self->{have_past_answer}) {
		print CGI::Tr({ valign => "top", align => "left" },
			CGI::th($self->{maketext}("Comment:")) .
			CGI::td(CGI::textarea({ name => "$self->{prob_id}.comment",
						value => $self->{comment_string}, rows => 3, cols => 30 }) .
				CGI::br() .
				CGI::input({ class => 'preview btn', type => 'button', name => "$self->{prob_id}.preview",
						value => "Preview Comment" }))
		);
	}

	# Save button
	print CGI::Tr({ align => "left" },
		CGI::td([WeBWorK::CGI_labeled_input(-type => "submit", -id => "saveGrade_id",
					-input_attr => {
						-formtarget => "_self", -name => "saveGrade",
						-value => $self->{maketext}("Save")
					}), "&nbsp;"])
	);
	print CGI::end_table();
	print CGI::hr();
	print CGI::end_div();

	return "";
}

1;
