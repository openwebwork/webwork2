## no critic (Modules::RequireExplicitPackage, TestingAndDebugging::RequireUseStrict, TestingAndDebugging::RequireUseWarnings)

=head1 NAME

IMathAS.pl - Put a question from an IMathAS server into a PG problem.

=head1 DESCRIPTION

This macro is used by webwork2 to render a problem whose source file is a
question on an IMathAS server, such as C<imathas:1234> or C<myopenmath:1234>.
See L<WeBWorK::ExternalProblem::IMathAS>.  It is internal to that module, and is
not for use in problem files.  webwork2 gets the question from the IMathAS
server (and has the server score the responses of the student) before PG is
called, puts what it got into C<$envir{imathas}>, and then renders a problem
that calls C<IMathASQuestion>.

Each answer box of the IMathAS question is an answer of the PG problem, with the
score that IMathAS gives it.  The score of the problem is the score that IMathAS
gives the question, since IMathAS weights the parts of a question.

The answer entry tips of IMathAS are shown as help links next to the answer
boxes, like those of C<helpLink>.

When correct answers are to be shown, they are obtained from IMathAS typeset.
If the author of the IMathAS question set its solution to be shown with the
answers, then that solution is shown as the solution of the problem when
solutions are to be shown.

For hardcopy and PreTeXt output the question is obtained from IMathAS as
PreTeXt.  For hardcopy that is converted to LaTeX.  The correct answers are
available for these as well.

=head1 MACROS

=head2 IMathASQuestion

    TEXT(IMathASQuestion());

Returns the IMathAS question in the form for the display mode in use (HTML,
LaTeX for hardcopy, or PreTeXt), and sets up the answers for it.  If the
question could not be loaded, then a message that says so is shown in place of
the question and a warning that gives the reason is issued.

=head1 LIMITATIONS

=over

=item *

In hardcopy and PreTeXt output, images of a question are not shown, and
questions that are answered by drawing or by other means that are not text
entry or choices may not be shown well.

=item *

IMathAS questions can not be used in tests (gateway quizzes), since IMathAS
determines the names of the form fields, and those can not be given the prefix
that the problems of a test need.

=item *

The IMathAS equation editor and answer preview are not used.  If MathQuill is
enabled in WeBWorK, then the WeBWorK MathQuill editor is used for the answer
boxes of IMathAS question types that take mathematical input.  IMathAS accepts
most of what that editor produces.  For the things that it does not accept, what
IMathAS expects is put in their place when an answer is submitted: C<oo> for
C<inf> and C<infinity>, C<DNE> for C<empty set>, C<+-> for C<pm>, and angle
brackets typed with the keyboard for those of the editor.  There may be other
things that the editor produces that IMathAS does not accept.

=item *

Correct answers are not shown for a question if the number of correct answers
that IMathAS gives for it is not the number of its answer boxes.

=item *

For some types of IMathAS questions (such as multiple choice and matrix
questions) the answer that is shown as entered is in the form that IMathAS
records it in, and not as the student sees it.

=back

=cut

# The stylesheet and JavaScript for IMathAS questions are in the htdocs directory of webwork2.
sub _IMathAS_init {
	ADD_CSS_FILE('js/IMathAS/imathas.css');
	ADD_JS_FILE('js/IMathAS/imathas.js', 0, { defer => undef });
	return;
}

sub IMathASQuestion {
	my $data = $main::envir{imathas};
	return _IMathAS_error('No IMathAS question was given.') unless ref $data eq 'HASH';

	my $name = $data->{source} // "IMathAS question $data->{id}";
	return _IMathAS_error("$name could not be loaded: $data->{error}") if $data->{error};

	return _IMathAS_static($data->{static}) if $main::displayMode eq 'TeX' || $main::displayMode eq 'PTX';

	my $result = $data->{question};
	return _IMathAS_error("$name could not be loaded.") unless ref $result eq 'HASH';
	warn "$name: $_\n" for @{ $result->{errors} // [] };

	# webwork2 also got the question as IMathAS gives it for output that is not interactive.  That has the correct
	# answers (typeset), which are only used if there is one for each answer box, and the solution if there is one.
	my $solution = '';
	if (my $static = $data->{static}) {
		warn "The correct answers and solution of $name could not be loaded: $static->{error}"
			if $static->{error} && ($main::envir{showCorrectAnswers} || $main::envir{showSolutions});
		my @answers = @{ $static->{answers} // [] };
		if (@answers && @answers == @{ $result->{boxes} // [] }) {
			for (0 .. $#answers) {
				$result->{boxes}[$_]{correct_ans} = $answers[$_]{correct_ans};
				$result->{boxes}[$_]{correct_tex} = $answers[$_]{correct_tex};
			}
		}
		# This is done even if solutions are not to be shown so that PG records that the problem has a solution.  Then
		# webwork2 offers to show it when that is allowed.
		$solution = _IMathAS_solution($static->{solution}{html}) if $static->{solution};
	}

	my %boxNames;
	for my $box (@{ $result->{boxes} // [] }) {
		$boxNames{ $box->{name} } = 1;

		# Give answer boxes for mathematical input the class that the answer rules of PG have.  That gives them the
		# same appearance, and the MathQuill editor of WeBWorK is only used for inputs with that class.
		$box->{math} = ($box->{type} // '') =~ /^(?:number|calculated|numfunc|(?:calc)?(?:interval|ntuple|complex))$/
			&& $result->{html} =~ s/(<input\b[^>]*\bname="\Q$box->{name}\E"[^>]*\bclass=")/$1codeshard /;

		# The answer preview of IMathAS is not used, so remove the button for it.
		my $ref = substr($box->{name}, 2);
		$result->{html} =~ s/\s*<button\b[^>]*\bid="?pbtn$ref"?[^>]*>.*?<\/button>//s;

		# Show the answer entry tip of IMathAS as a help link like those that helpLink gives.
		if (defined $box->{longtip} || defined $box->{tip}) {
			my $help = ' '
				. knowlLink(
					'help (answer format)',
					value => $box->{longtip} // $box->{tip},
					title => $box->{tip}     // 'Answer format',
					type  => 'help'
				);
			# Put the link at the preview area that follows the answer box, or else directly after the answer box.
			$result->{html} =~ s/(<span\s+id="?p$ref"?\s*>)/$help $1/
				|| $result->{html} =~ s/(<input\b[^>]*\bname="\Q$box->{name}\E"[^>]*>)/$1$help/;
		}

		RECORD_ANS_NAME($box->{name}, $main::inputs_ref->{ $box->{name} } // '');
		NAMED_ANS($box->{name} => _IMathAS_cmp($box, $result->{scored}));

		# Form fields with these names are added by the IMathAS JavaScript when the form is submitted.
		RECORD_EXTRA_ANSWERS("$box->{name}-val");
		RECORD_EXTRA_ANSWERS("$box->{name}-choicemap");
	}

	# Record the other form fields of the question (for example the entries of a matrix) so that the responses in them
	# are saved.
	my %seen;
	while ($result->{html} =~ /\bname\s*=\s*["']?((?:qn|tc|qs)\d[^"'\s>]*)/g) {
		RECORD_EXTRA_ANSWERS($1) unless $boxNames{$1} || $seen{$1}++;
	}

	# IMathAS weights the parts of a question, so use its score for the problem.
	if ($result->{scored}) {
		my $score = $result->{score};
		install_problem_grader(sub {
			my ($answers, $state, %form_options) = @_;
			my ($problem_result, $problem_state) = avg_problem_grader($answers, $state, %form_options);
			if ($form_options{answers_submitted}) {
				$problem_result->{score}         = $score < 0 ? 0 : $score > 1 ? 1 : $score;
				$problem_result->{type}          = 'imathas_problem_grader';
				$problem_state->{recorded_score} = $problem_result->{score}
					if $problem_result->{score} > ($problem_state->{recorded_score} // 0);
			}
			return ($problem_result, $problem_state);
		});
	}

	return
		'<div class="imathas-question" data-public-url="'
		. encode_pg_and_html($result->{publicURL})
		. '" data-jsparams="'
		. encode_pg_and_html($result->{jsparams_json})
		. '"><div class="question" id="questionwrap5">'
		. $result->{html}
		. '</div></div>'
		. $solution;
}

# Issue a warning, and return a message that the question could not be loaded in the form for the display mode.
sub _IMathAS_error {
	my $message = shift;
	warn $message =~ /\n$/ ? $message : "$message\n";
	return MODES(
		HTML => '<div class="alert alert-danger">This question could not be loaded.</div>',
		TeX  => '{\\bf This question could not be loaded.}',
		PTX  => '<p>This question could not be loaded.</p>'
	);
}

# The solution of the question as the SOLUTION method gives it.  The SOLUTION method adds the solution to the problem
# text when it is called, and that is before the question is added.  So the solution is taken back out of the problem
# text and returned so that it can be put after the question.
sub _IMathAS_solution {
	my $body = shift;
	return '' unless defined $body && $body =~ /\S/;
	my $output = $main::PG->{OUTPUT_ARRAY};
	my $count  = @$output;
	SOLUTION($body);
	return join('', splice(@$output, $count));
}

# The question for hardcopy and PreTeXt output.
sub _IMathAS_static {
	my $result = shift;

	for my $answer (@{ $result->{answers} // [] }) {
		RECORD_ANS_NAME($answer->{name}, '');
		NAMED_ANS($answer->{name} => _IMathAS_cmp($answer, 0));
	}

	my $solution =
		$result->{solution}
		? _IMathAS_solution(MODES(HTML => '', TeX => $result->{solution}{tex}, PTX => $result->{solution}{ptx}))
		: '';

	return MODES(HTML => '', TeX => $result->{tex}, PTX => $result->{ptx}) . $solution;
}

# The answer evaluator for an answer box of an IMathAS question.  It does not evaluate anything.  It gives the
# result that IMathAS gave when the question was loaded.
sub _IMathAS_cmp {
	my ($box, $scored) = @_;
	my $ans = AnswerEvaluator->new;

	# The correct answer as text.  Mathematics in it is LaTeX.
	my $correct = $box->{correct_ans};

	# This is not wrapped in LaTeX delimiters by PG, so do that here when there is LaTeX for the answer.
	my $correctDisplay =
		defined $box->{correct_tex} ? '\\(' . encode_pg_and_html($box->{correct_tex}) . '\\)'
		: defined $correct          ? encode_pg_and_html($correct)
		:                             undef;

	$ans->ans_hash(
		type            => 'imathas' . (defined $box->{type} ? "_$box->{type}" : ''),
		correct_ans     => $correct // '',
		non_tex_preview => 1,
		# Only use the MathQuill editor of WeBWorK for answer boxes for mathematical input.
		($box->{math} ? () : (mathQuillOpts => 'disabled')),
		feedback_options => sub {
			my ($ansHash, $options) = @_;
			$options->{showCorrect} = 0 unless defined $correct;
		}
	);
	$ans->{rh_ans}{correct_ans_latex_string} = $correctDisplay if defined $correctDisplay;

	# The default filters stop a blank answer from being evaluated.  Remove them since the responses to some types of
	# IMathAS questions are not in a form field that has the name of the answer.
	$ans->install_pre_filter('erase');
	$ans->install_post_filter('erase');

	$ans->install_evaluator(sub {
		my $ans_hash = shift;
		my $student  = $scored ? $box->{student_ans} // '' : '';
		$ans_hash->{_filter_name}         = 'IMathAS';
		$ans_hash->{score}                = $scored ? $box->{score} // 0 : 0;
		$ans_hash->{student_ans}          = $student;
		$ans_hash->{preview_text_string}  = $student;
		$ans_hash->{preview_latex_string} = encode_pg_and_html($student);
		return $ans_hash;
	});

	return $ans;
}

1;
