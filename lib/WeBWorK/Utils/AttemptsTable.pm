#!/usr/bin/perl -w
use 5.010;

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

=head1 NAME

	AttemptsTable

=head1 SYNPOSIS

	my $tbl = WeBWorK::Utils::AttemptsTable->new(
		$answers,
		answersSubmitted       => 1,
		answerOrder            => $pg->{flags}->{ANSWER_ENTRY_ORDER},
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
	# this also collects the correct_ids and incorrect_ids
	$self->{correct_ids}   = $tbl->correct_ids;
	$self->{incorrect_ids} = $tbl->incorrect_ids;


=head1 DESCRIPTION
This module handles the formatting of the table which presents the results of analyzing a student's
answer to a WeBWorK problem.  It is used in Problem.pm, OpaqueServer.pm, standAlonePGproblemRender

=head2 new

	my $tbl = WeBWorK::Utils::AttemptsTable->new(
		$answers,
		answersSubmitted       => 1,
		answerOrder            => $pg->{flags}->{ANSWER_ENTRY_ORDER},
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
	summary            is obtained from $pg->{result}->{summary}.
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

=item correct_ids, incorrect_ids,

These are references to lists of the ids of the correct answers and the incorrect answers respectively.

=item showMessages,

This can be switched on or off before exporting the answerTemplate, perhaps under instructions
	from the PG problem.

=item summary

The contents of the summary can be defined when the attemptsTable object is created.

The summary can be defined by the PG problem grader
usually returned as $pg->{result}->{summary}.

If the summary is not explicitly defined then (localized) versions
of the default summaries are created:

	"The answer above is correct.",
	"Some answers will be graded later.",
	"All of the [gradeable] answers above are correct.",
	"[N] of the questions remain unanswered.",
	"At least one of the answers above is NOT [fully] correct.',

=back

=cut

package WeBWorK::Utils::AttemptsTable;
use base qw(Class::Accessor);

use strict;
use warnings;
use Scalar::Util 'blessed';
use WeBWorK::Utils 'wwRound';
use CGI;

# Object contains hash of answer results
# Object contains display mode
# Object contains or creates Image generator
# object returns table

sub new {
	my $class = shift;
	$class = (ref($class))? ref($class) : $class; # create a new object of the same class
	my $rh_answers = shift;
	ref($rh_answers) =~/HASH/ or die "The first entry to AttemptsTable must be a hash of answers";
	my %options = @_; # optional:  displayMode=>, submitted=>, imgGen=>, ce=>
	my $self = {
		answers             => $rh_answers // {},
		answerOrder         => $options{answerOrder} // [],
		answersSubmitted    => $options{answersSubmitted} // 0,
		summary             => $options{summary} // '',  # summary provided by problem grader
		displayMode         => $options{displayMode} || "MathJax",
		showHeadline        => $options{showHeadline} // 1,
		showAnswerNumbers   => $options{showAnswerNumbers} // 1,
		showAttemptAnswers  =>  $options{showAttemptAnswers} // 1,    # show student answer as entered and simplified
	                                                                      #  (e.g numerical formulas are calculated to produce numbers)
		showAttemptPreviews => $options{showAttemptPreviews} // 1,    # show preview of student answer
		showAttemptResults  => $options{showAttemptResults} // 1,     # show whether student answer is correct
		showMessages        => $options{showMessages} // 1,           # show any messages generated by evaluation
		showCorrectAnswers  => $options{showCorrectAnswers} // 1,     # show the correct answers
		showSummary         => $options{showSummary} // 1,            # show summary to students
		maketext            => $options{maketext} // sub {return @_}, # pointer to the maketext subroutine
		imgGen              => undef,                                 # created in _init method
	};
	bless $self, $class;
	# create read only accessors/mutators
	$self->mk_ro_accessors(qw(answers answerOrder answersSubmitted displayMode imgGen maketext));
	$self->mk_ro_accessors(qw(showAnswerNumbers showAttemptAnswers showHeadline
	                          showAttemptPreviews showAttemptResults
	                          showCorrectAnswers showSummary));
	$self->mk_accessors(qw(correct_ids incorrect_ids showMessages  summary));
	# sanity check and initialize imgGenerator.
	_init($self, %options);
	return $self;
}

sub _init {
	# verify display mode
	# build imgGen if it is not supplied
	my $self = shift;
	my %options = @_;
	$self->{submitted}=$options{submitted}//0;
	$self->{displayMode} = $options{displayMode} || "MathJax";
	# only show message column if there is at least one message:
	my @reallyShowMessages =  grep { $self->answers->{$_}->{ans_message} } @{$self->answerOrder};
	$self->showMessages( $self->showMessages && !!@reallyShowMessages );
	                               #           (!! forces boolean scalar environment on list)
	# only used internally -- don't need accessors.
	$self->{numCorrect}=0;
	$self->{numBlanks}=0;
	$self->{numEssay}=0;

	if ( $self->displayMode eq 'images') {
		if ( blessed( $options{imgGen} ) ) {
			$self->{imgGen} = $options{imgGen};
		} elsif ( blessed( $options{ce} ) ) {
			warn "building imgGen";
			my $ce = $options{ce};
			my $site_url = $ce->{server_root_url};
			my %imagesModeOptions = %{$ce->{pg}->{displayModeOptions}->{images}};

			my $imgGen = WeBWorK::PG::ImageGenerator->new(
				tempDir         => $ce->{webworkDirs}->{tmp},
				latex	        => $ce->{externalPrograms}->{latex},
				dvipng          => $ce->{externalPrograms}->{dvipng},
				useCache        => 1,
				cacheDir        => $ce->{webworkDirs}->{equationCache},
				cacheURL        => $site_url.$ce->{webworkURLs}->{equationCache},
				cacheDB         => $ce->{webworkFiles}->{equationCacheDB},
				dvipng_align    => $imagesModeOptions{dvipng_align},
				dvipng_depth_db => $imagesModeOptions{dvipng_depth_db},
			);
	        $self->{imgGen} = $imgGen;
		} else {
			warn "Must provide image Generator (imgGen) or a course environment (ce) to build attempts table.";
		}
	}
}

sub maketext {
        my $self = shift;
#       Uncomment to check that strings are run through maketext
#	return 'xXx'.&{$self->{maketext}}(@_).'xXx';
	return &{$self->{maketext}}(@_);
}
sub formatAnswerRow {
	my $self          = shift;
	my $rh_answer     = shift;
	my $ans_id        = shift;
	my $answerNumber  = shift;
	my $answerString         = $rh_answer->{student_ans}//'';
	# use student_ans and not original_student_ans above.  student_ans has had HTML entities translated to prevent XSS.
	my $answerPreview        = $self->previewAnswer($rh_answer)//'&nbsp;';
	my $correctAnswer        = $rh_answer->{correct_ans}//'';
	my $correctAnswerPreview = $self->previewCorrectAnswer($rh_answer)//'&nbsp;';

	my $answerMessage   = $rh_answer->{ans_message}//'';
	$answerMessage =~ s/\n/<BR>/g;
	my $answerScore      = $rh_answer->{score}//0;
	$self->{numCorrect}  += $answerScore >=1;
	$self->{numEssay}    += ($rh_answer->{type}//'') eq 'essay';
	$self->{numBlanks}++ unless $answerString =~/\S/ || $answerScore >= 1;

	my $feedbackMessageClass = ($answerMessage eq "") ? "" : $self->maketext("FeedbackMessage");

	my (@correct_ids, @incorrect_ids);
	my $resultString;
	my $resultStringClass;
	if ($answerScore >= 1) {
		$resultString      = $self->maketext("correct");
		$resultStringClass = "ResultsWithoutError";
	} elsif (($rh_answer->{type} // '') eq 'essay') {
		$resultString = $self->maketext("Ungraded");
		$self->{essayFlag} = 1;
	} elsif (defined($answerScore) and $answerScore == 0) {
		$resultStringClass = "ResultsWithError";
		$resultString      = $self->maketext("incorrect");
	} else {
		$resultString = $self->maketext("[_1]% correct", wwRound(0, $answerScore * 100));
	}
	my $attemptResults = CGI::td({ class => $resultStringClass },
		CGI::a({ href => '#', data_answer_id => $ans_id }, $self->nbsp($resultString)));

	my $row = join('',
			  ($self->showAnswerNumbers) ? CGI::td({},$answerNumber):'',
			  ($self->showAttemptAnswers) ? CGI::td({dir=>"auto"},$self->nbsp($answerString)):'' ,   # student original answer
			  ($self->showAttemptPreviews)?  $self->formatToolTip($answerString, $answerPreview):"" ,
			  ($self->showAttemptResults)?   $attemptResults : '' ,
			  ($self->showCorrectAnswers)?  $self->formatToolTip($correctAnswer,$correctAnswerPreview):"" ,
			  ($self->showMessages)?        CGI::td({class=>$feedbackMessageClass},$self->nbsp($answerMessage)):"",
			  "\n"
			  );
	$row;
}

#####################################################
# determine whether any answers were submitted
# and create answer template if they have been
#####################################################

sub answerTemplate {
	my $self = shift;
	my $rh_answers = $self->{answers};
	my @tableRows;
	my @correct_ids;
	my @incorrect_ids;

	push @tableRows,CGI::Tr(
			($self->showAnswerNumbers) ? CGI::th("#"):'',
			($self->showAttemptAnswers)? CGI::th($self->maketext("Entered")):'',  # student original answer
			($self->showAttemptPreviews)? CGI::th($self->maketext("Answer Preview")):'',
			($self->showAttemptResults)?  CGI::th($self->maketext("Result")):'',
			($self->showCorrectAnswers)?  CGI::th($self->maketext("Correct Answer")):'',
			($self->showMessages)?        CGI::th($self->maketext("Message")):'',
		);

	my $answerNumber     = 1;
    foreach my $ans_id (@{ $self->answerOrder() }) {
    	push @tableRows, CGI::Tr($self->formatAnswerRow($rh_answers->{$ans_id}, $ans_id, $answerNumber++));
    	push @correct_ids,   $ans_id if ($rh_answers->{$ans_id}->{score}//0) >= 1;
    	push @incorrect_ids,   $ans_id if ($rh_answers->{$ans_id}->{score}//0) < 1;
    	#$self->{essayFlag} = 1;
    }
	my $answerTemplate = "";
	$answerTemplate .= CGI::h3({ class => 'attemptResultsHeader' }, $self->maketext("Results for this submission"))
		if $self->showHeadline;
	$answerTemplate .= CGI::table({ class => 'attemptResults table table-sm table-bordered' }, @tableRows);
    ### "results for this submission" is better than "attempt results" for a headline
    $answerTemplate .= ($self->showSummary)? $self->createSummary() : '';
    $answerTemplate = "" unless $self->answersSubmitted; # only print if there is at least one non-blank answer
    $self->correct_ids(\@correct_ids);
    $self->incorrect_ids(\@incorrect_ids);
    $answerTemplate;
}
#################################################

sub previewAnswer {
	my $self =shift;
	my $answerResult = shift;
	my $displayMode = $self->displayMode;
	my $imgGen      = $self->imgGen;

	# note: right now, we have to do things completely differently when we are
	# rendering math from INSIDE the translator and from OUTSIDE the translator.
	# so we'll just deal with each case explicitly here. there's some code
	# duplication that can be dealt with later by abstracting out dvipng/etc.

	my $tex = $answerResult->{preview_latex_string};

	return "" unless defined $tex and $tex ne "";

	return $tex if $answerResult->{non_tex_preview};

	if ($displayMode eq "plainText") {
		return $tex;
	} elsif (($answerResult->{type}//'') eq 'essay') {
	    return $tex;
	} elsif ($displayMode eq "images") {
		$imgGen->add($tex);
	} elsif ($displayMode eq "MathJax") {
		return '<script type="math/tex; mode=display">' . $tex . '</script>';
	}
}

sub previewCorrectAnswer {
	my $self =shift;
	my $answerResult = shift;
	my $displayMode = $self->displayMode;
	my $imgGen      = $self->imgGen;

	my $tex = $answerResult->{correct_ans_latex_string};
	return $answerResult->{correct_ans} unless defined $tex and $tex=~/\S/;   # some answers don't have latex strings defined
	# return "" unless defined $tex and $tex ne "";

	return $tex if $answerResult->{non_tex_preview};

	if ($displayMode eq "plainText") {
		return $tex;
	} elsif ($displayMode eq "images") {
		$imgGen->add($tex);
		# warn "adding $tex";
	} elsif ($displayMode eq "MathJax") {
		return '<script type="math/tex; mode=display">' . $tex . '</script>';
	}
}

###########################################
# Create summary
###########################################
sub createSummary {
	my $self = shift;
	my $summary = "";
	my $numCorrect = $self->{numCorrect};
	my $numBlanks  = $self->{numBlanks};
	my $numEssay   = $self->{numEssay};

	unless (defined($self->summary) and $self->summary =~ /\S/) {
		my @answerNames = @{ $self->answerOrder() };
		if (scalar @answerNames == 1) {    #default messages
			if ($numCorrect == scalar @answerNames) {
				$summary .=
					CGI::div({ class => 'ResultsWithoutError mb-2' }, $self->maketext('The answer above is correct.'));
			} elsif ($self->{essayFlag}) {
				$summary .= CGI::div($self->maketext('Some answers will be graded later.'));
			} else {
				$summary .=
					CGI::div({ class => 'ResultsWithError mb-2' }, $self->maketext('The answer above is NOT correct.'));
			}
		} else {
			if ($numCorrect + $numEssay == scalar @answerNames) {
				if ($numEssay) {
					$summary .= CGI::div({ class => 'ResultsWithoutError mb-2' },
						$self->maketext('All of the gradeable answers above are correct.'));
				} else {
					$summary .= CGI::div({ class => 'ResultsWithoutError mb-2' },
						$self->maketext('All of the answers above are correct.'));
				}
			} elsif ($numBlanks + $numEssay != scalar(@answerNames)) {
				$summary .= CGI::div({ class => 'ResultsWithError mb-2' },
					$self->maketext('At least one of the answers above is NOT correct.'));
			}
			if ($numBlanks > $numEssay) {
				my $s = ($numBlanks > 1) ? '' : 's';
				$summary .= CGI::div(
					{ class => 'ResultsAlert mb-2' },
					$self->maketext(
						'[quant,_1,of the questions remains,of the questions remain] unanswered.', $numBlanks
					)
				);
			}
		}
	} else {
		$summary = $self->summary;    # summary has been defined by grader
	}
	$summary = CGI::div({role=>"alert", class=>"attemptResultsSummary"},
			  $summary);
	$self->summary($summary);
	return $summary;   # return formatted version of summary in class "attemptResultsSummary" div
}
################################################

############################################
# utility subroutine -- prevents unwanted line breaks
############################################
sub nbsp {
	my ($self, $str) = @_;
	return (defined $str && $str =~/\S/) ? $str : "&nbsp;";
}

# note that formatToolTip output includes CGI::td wrapper
sub formatToolTip {
	my $self = shift;
	my $answer = shift;
	my $formattedAnswer = shift;
	return CGI::td(CGI::span({
				class => "answer-preview",
				data_bs_toggle => "popover",
				data_bs_content => $answer,
				data_bs_placement => "bottom",
			},
			$self->nbsp($formattedAnswer))
	);
}

1;
