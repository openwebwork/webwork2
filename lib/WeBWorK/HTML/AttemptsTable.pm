################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

=head1 NAME

	AttemptsTable

=head1 SYNPOSIS

	my $tbl = WeBWorK::HTML::AttemptsTable->new(
		$answers,
		answersSubmitted       => 1,
		answerOrder            => $pg->{flags}{ANSWER_ENTRY_ORDER},
		displayMode            => 'MathJax',
		showAnswerNumbers      => 0,
		showAttemptAnswers     => $showAttemptAnswers && $showEvaluatedAnswers,
		showAttemptPreviews    => $showAttemptPreview,
		showAttemptResults     => $showAttemptResults,
		showCorrectAnswers     => $showCorrectAnswers,
		showMessages           => $showAttemptAnswers, # internally checks for messages
		showSummary            => $showSummary,
		imgGen                 => $imgGen, # not needed if ce is present ,
		ce                     => '',	   # not needed if $imgGen is present
		maketext               => WeBWorK::Localize::getLoc("en"),
	);
	$tbl->{imgGen}->render(refresh => 1) if $tbl->displayMode eq 'images';
	my $answerTemplate = $tbl->answerTemplate;


=head1 DESCRIPTION

This module handles the formatting of the table which presents the results of analyzing a student's
answer to a WeBWorK problem.  It is used in Problem.pm, OpaqueServer.pm, standAlonePGproblemRender

=head2 new

	my $tbl = WeBWorK::HTML::AttemptsTable->new(
		$answers,
		answersSubmitted       => 1,
		answerOrder            => $pg->{flags}{ANSWER_ENTRY_ORDER},
		displayMode            => 'MathJax',
		showHeadline           => 1,
		showAnswerNumbers      => 0,
		showAttemptAnswers     => $showAttemptAnswers && $showEvaluatedAnswers,
		showAttemptPreviews    => $showAttemptPreview,
		showAttemptResults     => $showAttemptResults,
		showCorrectAnswers     => $showCorrectAnswers,
		showMessages           => $showAttemptAnswers, # internally checks for messages
		showSummary            => $showSummary,
		imgGen                 => $imgGen, # not needed if ce is present ,
		ce                     => '',	   # not needed if $imgGen is present
		maketext               => WeBWorK::Localize::getLoc("en"),
		summary                =>'',
	);

	$answers -- a hash of student answers e.g. $pg->{answers}
	answersSubmitted     if 0 then then the attemptsTable is not displayed (???)
	answerOrder       -- an array indicating the order the answers appear on the page.
	displayMode       'MathJax' and 'images' are the most common

	showHeadline       Show the header line 'Results for this submission'

	showAnswerNumbers, showAttemptAnswers, showAttemptPreviews,showAttemptResults,
	showCorrectAnswers and showMessages control the display of each column in the table.

	attemptAnswers     the student's typed in answer (possibly simplified numerically)
	attemptPreview     the student's answer after typesetting
	attemptResults     "correct", "_% correct",  "incorrect" or "ungraded"- links to the answer blank
	correctAnswers     typeset version (untypeset versions are available via popups)
	messages           warns of formatting typos in the answer, or
	                    more detailed messages about a wrong answer
	summary            is obtained from $pg->{result}{summary}.
	                   If this is empty then a (localized)
	                   version of "all answers are correct"
	                   or "at least one answer is not coorrect"
	imgGen             points to a prebuilt image generator objectfor "images" mode
	ce                 points to the CourseEnvironment -- it is needed if AttemptsTable
	                    is required to build its own imgGen object
	maketext           points to a localization subroutine

=head2 Methods

=over 4

=item answerTemplate

Returns HTML which formats the analysis of the student's answers to the problem.

=back

=head2 Read/Write Properties

=over 4

=item showMessages,

This can be switched on or off before exporting the answerTemplate, perhaps
under instructions from the PG problem.

=item summary

The contents of the summary can be defined when the attemptsTable object is created.

The summary can be defined by the PG problem grader usually returned as
$pg->{result}{summary}.

If the summary is not explicitly defined then (localized) versions
of the default summaries are created:

	"The answer above is correct.",
	"Some answers will be graded later.",
	"All of the [gradeable] answers above are correct.",
	"[N] of the questions remain unanswered.",
	"At least one of the answers above is NOT [fully] correct.',

Note that if this is set after initialization, you must ensure that it is a
Mojo::ByteStream object if it contains html or characters that need escaping.

=back

=cut

package WeBWorK::HTML::AttemptsTable;
use Mojo::Base 'Class::Accessor', -signatures;

use Scalar::Util 'blessed';
use WeBWorK::Utils 'wwRound';

# %options may contain:  displayMode, submitted, imgGen, ce
# At least one of imgGen or ce must be provided if displayMode is 'images'.
sub new ($class, $rh_answers, $c, %options) {
	$class = ref $class || $class;
	ref($rh_answers) =~ /HASH/     or die 'The first entry to AttemptsTable must be a hash of answers';
	$c->isa('WeBWorK::Controller') or die 'The second entry to AttemptsTable must be a WeBWorK::Controller';
	my $self = bless {
		answers             => $rh_answers,
		c                   => $c,
		answerOrder         => $options{answerOrder}      // [],
		answersSubmitted    => $options{answersSubmitted} // 0,
		summary             => undef,                                # summary provided by problem grader (set in _init)
		displayMode         => $options{displayMode} || 'MathJax',
		showHeadline        => $options{showHeadline}        // 1,
		showAnswerNumbers   => $options{showAnswerNumbers}   // 1,
		showAttemptAnswers  => $options{showAttemptAnswers}  // 1,    # show student answer as entered and parsed
		showAttemptPreviews => $options{showAttemptPreviews} // 1,    # show preview of student answer
		showAttemptResults  => $options{showAttemptResults}  // 1,    # show results of grading student answer
		showMessages        => $options{showMessages}        // 1,    # show messages generated by evaluation
		showCorrectAnswers  => $options{showCorrectAnswers}  // 0,    # show the correct answers
		showSummary         => $options{showSummary}         // 1,    # show result summary
		imgGen              => undef,                                 # set or created in _init method
	}, $class;

	# Create accessors/mutators
	$self->mk_ro_accessors(qw(answers c answerOrder answersSubmitted displayMode imgGen showAnswerNumbers
		showAttemptAnswers showHeadline showAttemptPreviews showAttemptResults showCorrectAnswers showSummary));
	$self->mk_accessors(qw(showMessages summary));

	# Sanity check and initialize imgGenerator.
	$self->_init(%options);

	return $self;
}

# Verify the display mode, and build imgGen if it is not supplied.
sub _init ($self, %options) {
	$self->{submitted}   = $options{submitted} // 0;
	$self->{displayMode} = $options{displayMode} || 'MathJax';

	# Only show message column if there is at least one message.
	my @reallyShowMessages = grep { $self->answers->{$_}{ans_message} } @{ $self->answerOrder };
	$self->showMessages($self->showMessages && !!@reallyShowMessages);

	# Only used internally.  Accessors are not needed.
	$self->{numCorrect} = 0;
	$self->{numBlanks}  = 0;
	$self->{numEssay}   = 0;

	if ($self->displayMode eq 'images') {
		if (blessed($options{imgGen}) && $options{imgGen}->isa('WeBWorK::PG::ImageGenerator')) {
			$self->{imgGen} = $options{imgGen};
		} elsif (blessed($options{ce}) && $options{ce}->isa('WeBWorK::CourseEnvironment')) {
			my $ce = $options{ce};

			$self->{imgGen} = WeBWorK::PG::ImageGenerator->new(
				tempDir         => $ce->{webworkDirs}{tmp},
				latex           => $ce->{externalPrograms}{latex},
				dvipng          => $ce->{externalPrograms}{dvipng},
				useCache        => 1,
				cacheDir        => $ce->{webworkDirs}{equationCache},
				cacheURL        => $ce->{server_root_url} . $ce->{webworkURLs}{equationCache},
				cacheDB         => $ce->{webworkFiles}{equationCacheDB},
				dvipng_align    => $ce->{pg}{displayModeOptions}{images}{dvipng_align},
				dvipng_depth_db => $ce->{pg}{displayModeOptions}{images}{dvipng_depth_db},
			);
		} else {
			warn 'Must provide image Generator (imgGen) or a course environment (ce) to build attempts table.';
		}
	}

	# Make sure that the provided summary is a Mojo::ByteStream object.
	$self->summary(blessed($options{summary})
			&& $options{summary}->isa('Mojo::ByteStream') ? $options{summary} : $self->c->b($options{summary} // ''));

	return;
}

sub formatAnswerRow ($self, $rh_answer, $ans_id, $answerNumber) {
	my $c = $self->c;

	my $answerString         = $rh_answer->{student_ans}               // '';
	my $answerPreview        = $self->previewAnswer($rh_answer)        // '&nbsp;';
	my $correctAnswer        = $rh_answer->{correct_ans}               // '';
	my $correctAnswerPreview = $self->previewCorrectAnswer($rh_answer) // '&nbsp;';

	my $answerMessage = $rh_answer->{ans_message} // '';
	$answerMessage =~ s/\n/<BR>/g;
	my $answerScore = $rh_answer->{score} // 0;
	$self->{numCorrect} += $answerScore >= 1;
	$self->{numEssay}   += ($rh_answer->{type} // '') eq 'essay';
	$self->{numBlanks}++ unless $answerString =~ /\S/ || $answerScore >= 1;

	my $feedbackMessageClass = ($answerMessage eq '') ? '' : $c->maketext('FeedbackMessage');

	my $resultString;
	my $resultStringClass;
	if ($answerScore >= 1) {
		$resultString      = $c->maketext('correct');
		$resultStringClass = 'ResultsWithoutError';
	} elsif (($rh_answer->{type} // '') eq 'essay') {
		$resultString = $c->maketext('Ungraded');
		$self->{essayFlag} = 1;
	} elsif ($answerScore == 0) {
		$resultStringClass = 'ResultsWithError';
		$resultString      = $c->maketext('incorrect');
	} else {
		$resultString = $c->maketext('[_1]% correct', wwRound(0, $answerScore * 100));
	}
	my $attemptResults = $c->tag(
		'td',
		class => $resultStringClass,
		$c->tag('a', href => '#', data => { answer_id => $ans_id }, $self->nbsp($resultString))
	);

	return $c->c(
		$self->showAnswerNumbers  ? $c->tag('td', $answerNumber)                             : '',
		$self->showAttemptAnswers ? $c->tag('td', dir => 'auto', $self->nbsp($answerString)) : '',
		$self->showAttemptPreviews
		? (((defined $answerPreview && $answerPreview ne '') || $self->showAttemptAnswers)
			? $self->formatToolTip($answerString, $answerPreview)
			: $c->tag('td', dir => 'auto', $self->nbsp($answerString)))
		: '',
		$self->showAttemptResults ? $attemptResults                                                            : '',
		$self->showCorrectAnswers ? $self->formatToolTip($correctAnswer, $correctAnswerPreview)                : '',
		$self->showMessages       ? $c->tag('td', class => $feedbackMessageClass, $self->nbsp($answerMessage)) : ''
	)->join('');
}

# Determine whether any answers were submitted and create answer template if they have been.
sub answerTemplate ($self) {
	my $c = $self->c;

	return '' unless $self->answersSubmitted;    # Only print if there is at least one non-blank answer

	my $tableRows = $c->c;

	push(
		@$tableRows,
		$c->tag(
			'tr',
			$c->c(
				$self->showAnswerNumbers   ? $c->tag('th', '#')                            : '',
				$self->showAttemptAnswers  ? $c->tag('th', $c->maketext('Entered'))        : '',
				$self->showAttemptPreviews ? $c->tag('th', $c->maketext('Answer Preview')) : '',
				$self->showAttemptResults  ? $c->tag('th', $c->maketext('Result'))         : '',
				$self->showCorrectAnswers  ? $c->tag('th', $c->maketext('Correct Answer')) : '',
				$self->showMessages        ? $c->tag('th', $c->maketext('Message'))        : ''
			)->join('')
		)
	);

	my $answerNumber = 0;
	for (@{ $self->answerOrder() }) {
		push @$tableRows, $c->tag('tr', $self->formatAnswerRow($self->{answers}{$_}, $_, ++$answerNumber));
	}

	return $c->c(
		$self->showHeadline
		? $c->tag('h2', class => 'attemptResultsHeader', $c->maketext('Results for this submission'))
		: '',
		$c->tag(
			'div',
			class => 'table-responsive',
			$c->tag('table', class => 'attemptResults table table-sm table-bordered', $tableRows->join(''))
		),
		$self->showSummary ? $self->createSummary : ''
	)->join('');
}

sub previewAnswer ($self, $answerResult) {
	my $displayMode = $self->displayMode;
	my $imgGen      = $self->imgGen;

	my $tex = $answerResult->{preview_latex_string};

	return '' unless defined $tex and $tex ne '';

	return $tex if $answerResult->{non_tex_preview};

	if ($displayMode eq 'plainText') {
		return $tex;
	} elsif (($answerResult->{type} // '') eq 'essay') {
		return $tex;
	} elsif ($displayMode eq 'images') {
		return $imgGen->add($tex);
	} elsif ($displayMode eq 'MathJax') {
		return $self->c->tag('script', type => 'math/tex; mode=display', $self->c->b($tex));
	}
}

sub previewCorrectAnswer ($self, $answerResult) {
	my $displayMode = $self->displayMode;
	my $imgGen      = $self->imgGen;

	my $tex = $answerResult->{correct_ans_latex_string};

	# Some answers don't have latex strings defined return the raw correct answer
	# unless defined $tex and $tex contains non whitespace characters;
	return $answerResult->{correct_ans}
		unless defined $tex and $tex =~ /\S/;

	return $tex if $answerResult->{non_tex_preview};

	if ($displayMode eq 'plainText') {
		return $tex;
	} elsif ($displayMode eq 'images') {
		return $imgGen->add($tex);
	} elsif ($displayMode eq 'MathJax') {
		return $self->c->tag('script', type => 'math/tex; mode=display', $self->c->b($tex));
	}
}

# Create summary
sub createSummary ($self) {
	my $c = $self->c;

	my $numCorrect = $self->{numCorrect};
	my $numBlanks  = $self->{numBlanks};
	my $numEssay   = $self->{numEssay};

	my $summary;

	unless (defined($self->summary) and $self->summary =~ /\S/) {
		# Default messages
		$summary = $c->c;
		my @answerNames = @{ $self->answerOrder() };
		if (scalar @answerNames == 1) {
			if ($numCorrect == scalar @answerNames) {
				push(
					@$summary,
					$c->tag(
						'div',
						class => 'ResultsWithoutError mb-2',
						$c->maketext('The answer above is correct.')
					)
				);
			} elsif ($self->{essayFlag}) {
				push(@$summary, $c->tag('div', $c->maketext('Some answers will be graded later.')));
			} else {
				push(
					@$summary,
					$c->tag(
						'div',
						class => 'ResultsWithError mb-2',
						$c->maketext('The answer above is NOT correct.')
					)
				);
			}
		} else {
			if ($numCorrect + $numEssay == scalar @answerNames) {
				if ($numEssay) {
					push(
						@$summary,
						$c->tag(
							'div',
							class => 'ResultsWithoutError mb-2',
							$c->maketext('All of the gradeable answers above are correct.')
						)
					);
				} else {
					push(
						@$summary,
						$c->tag(
							'div',
							class => 'ResultsWithoutError mb-2',
							$c->maketext('All of the answers above are correct.')
						)
					);
				}
			} elsif ($numBlanks + $numEssay != scalar(@answerNames)) {
				push(
					@$summary,
					$c->tag(
						'div',
						class => 'ResultsWithError mb-2',
						$c->maketext('At least one of the answers above is NOT correct.')
					)
				);
			}
			if ($numBlanks > $numEssay) {
				my $s = ($numBlanks > 1) ? '' : 's';
				push(
					@$summary,
					$c->tag(
						'div',
						class => 'ResultsAlert mb-2',
						$c->maketext(
							'[quant,_1,of the questions remains,of the questions remain] unanswered.', $numBlanks
						)
					)
				);
			}
		}
		$summary = $summary->join('');
	} else {
		$summary = $self->summary;    # Summary defined by grader
	}
	$summary = $c->tag('div', role => 'alert', class => 'attemptResultsSummary', $summary);
	$self->summary($summary);
	return $summary;
}

# Utility subroutine that prevents unwanted line breaks, and ensures that the return value is a Mojo::ByteStream object.
sub nbsp ($self, $str) {
	return $self->c->b(defined $str && $str =~ /\S/ ? $str : '&nbsp;');
}

# Note that formatToolTip output includes the <td></td> wrapper.
sub formatToolTip ($self, $answer, $formattedAnswer) {
	return $self->c->tag(
		'td',
		$self->c->tag(
			'div',
			class => 'answer-preview',
			data  => {
				bs_toggle    => 'popover',
				bs_content   => $answer,
				bs_placement => 'bottom',
			},
			$self->nbsp($formattedAnswer)
		)
	);
}

1;
