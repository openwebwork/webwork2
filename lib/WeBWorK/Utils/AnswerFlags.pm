package WeBWorK::Utils::AnswerFlags;
use Mojo::Base 'Exporter', -signatures;

use Mojo::DOM;

=head1 NAME

WeBWorK::Utils::AnswerFlags - Flag answer submissions that show signs that the
answers may not have been entered by the student, for example by an AI agent.

=head1 DESCRIPTION

Flags are evidence for an instructor to investigate, not proof.  They must never
be shown to students.

Flagging is configured by C<$options{flagUnusualAnswers}>.  If it is 0, then
nothing is flagged.  If it is 1, then only the server-side checks are used.  The
timing checks are done on the stored submission data, and the LaTeX and
MathQuill checks are done when a submission is recorded.  If it is 2, then the
in-browser checks done by the problem page javascript are also used.

=cut

our @EXPORT_OK =
	qw(browser_checks_enabled submission_input_flags answer_types_from_flags flag_past_answers answer_flag_description);

# Flags that the problem page javascript may send with a submission.
use constant BROWSER_FLAGS => { no_interaction => 1, webdriver => 1 };

# Flag for a problem page submission without the in-browser check results.
use constant NO_BROWSER_CHECKS_FLAG => 'no_browser_checks';

# Flags that are determined by the server when a submission is recorded.
use constant SERVER_FLAGS => { latex => 1, mathquill_blank => 1 };

# Length, minimum number of distinct problems, and maximum interval variation of a flagged run of regular submissions.
use constant REGULAR_RUN_LENGTH        => 10;
use constant REGULAR_RUN_MIN_PROBLEMS  => 3;
use constant REGULAR_RUN_MAX_VARIATION => 0.1;

=head1 FUNCTIONS

=head2 browser_checks_enabled

    my $enabled = browser_checks_enabled($ce);

Returns true if the in-browser checks are enabled for the course.

=cut

sub browser_checks_enabled ($ce) {
	return ($ce->{options}{flagUnusualAnswers} || 0) == 2;
}

=head2 submission_input_flags

    my $inputFlags = submission_input_flags($ce, $pg, $formFields, browserFlags => $c->param('inputFlags'));

Returns a comma separated string of the flags to save in the C<input_flags> field
of the past answer record for a submission.  The C<browserFlags> option should be
given for submissions from pages that do the in-browser checks, and is the comma
separated string of flags sent by the javascript of the page.  If the in-browser
checks are enabled, then this contains the known flags in that string, or the
C<no_browser_checks> flag if the option is given but undefined.  It also contains
the C<latex> flag if any answer typed into a text field of the problem contains
LaTeX, and the C<mathquill_blank> flag if an answer that is entered with
MathQuill was submitted without a MathQuill value.

=cut

sub submission_input_flags ($ce, $pg, $formFields, %options) {
	my @flags;
	if (browser_checks_enabled($ce) && exists $options{browserFlags}) {
		@flags =
			defined $options{browserFlags}
			? grep { BROWSER_FLAGS->{$_} } split(/,/, $options{browserFlags})
			: (NO_BROWSER_CHECKS_FLAG);
	}
	push(@flags, typed_answer_flags($pg, $formFields));
	return join(',', @flags);
}

# Returns the latex and mathquill_blank flags for the answers typed into the text fields of a problem.
sub typed_answer_flags ($pg, $formFields) {
	my %pgAnswers = %{ $pg->{PG_ANSWERS_HASH} // {} };

	my %candidates;
	for my $answerID (@{ $pg->{flags}{ANSWER_ENTRY_ORDER} // [] }) {
		my $isEssay   = ($pgAnswers{$answerID}{rh_ans}{type} // '') eq 'essay';
		my $responses = $pgAnswers{$answerID}{response_obj}{responses} // {};
		for my $responseID (@{ $pgAnswers{$answerID}{response_obj}{response_order} // [] }) {
			# Radio button and checkbox responses are recorded as a list of the choices.
			next if ref($responses->{$responseID});
			my $answer = $formFields->{$responseID};
			next if !defined $answer || ref $answer || $answer !~ /\S/;

			push(@{ $candidates{latex} }, $responseID) if !$isEssay && $answer =~ /\\[a-zA-Z]{2,}/;

			my $latex = $formFields->{"MaThQuIlL_$responseID"};
			push(@{ $candidates{mathquill_blank} }, $responseID) if !defined $latex || ref $latex || $latex !~ /\S/;
		}
	}
	return () unless %candidates;

	# Only parse the problem HTML if needed.  MathQuill is only used for codeshard inputs that have a MathQuill field.
	my $dom = Mojo::DOM->new($pg->{body_text} // '');
	my (%textFields, %mathQuillFields);
	for ($dom->find('input[name], textarea[name]')->each) {
		$textFields{ $_->attr('name') } = 1 if $_->tag eq 'textarea' || lc($_->attr('type') // 'text') eq 'text';
	}
	my %hasMathQuillField =
		map { $_->attr('name') =~ s/^MaThQuIlL_//r => 1 } $dom->find('input[name^="MaThQuIlL_"]')->each;
	for ($dom->find('input.codeshard[name]')->each) {
		$mathQuillFields{ $_->attr('name') } = 1
			if lc($_->attr('type') // 'text') eq 'text' && $hasMathQuillField{ $_->attr('name') };
	}

	return grep {
		my $fields = $_ eq 'latex' ? \%textFields : \%mathQuillFields;
		grep { $fields->{$_} } @{ $candidates{$_} // [] }
	} qw(latex mathquill_blank);
}

=head2 answer_types_from_flags

    my @answerTypes = answer_types_from_flags($problem->flags);

Returns the answer types saved in the flags of a user problem record, or an empty
list if the answer types were not saved.

=cut

sub answer_types_from_flags ($flags) {
	# If the flags end in a comma, then this is the old type of flags value without answer types.
	return () if !$flags || $flags =~ /,$/;
	return split(',', $flags =~ s/:needs_grading$//r);
}

=head2 flag_past_answers

    my $flags = flag_past_answers($ce, \@pastAnswers, timing => 1);

Takes a reference to an array of the past answer records of one user for one set
(or one version of a test), and returns a reference to a hash whose keys are the
answer ids of the flagged past answers, and whose values are references to arrays
of flags.  Each flag is a hash with a C<type> key, and possibly other keys with
details for that type.

Flags saved when a submission is recorded are included, except that flags saved
by the in-browser checks are only included if those checks are currently enabled
for the course.

If the C<timing> option is true, then submissions are flagged that are correct on
the first attempt very soon after the previous submission, or that are part of a
run of submissions on several problems at very regular intervals.  These checks
should not be done for tests since all problems in a test are submitted at once.

=cut

sub flag_past_answers ($ce, $pastAnswers, %options) {
	my $fastSeconds = $ce->{options}{flagFastAnswerSeconds} // 0;
	my %knownFlags =
		(%{ SERVER_FLAGS() }, browser_checks_enabled($ce) ? (%{ BROWSER_FLAGS() }, NO_BROWSER_CHECKS_FLAG, 1) : ());

	my @pastAnswers = sort { $a->timestamp <=> $b->timestamp || $a->answer_id <=> $b->answer_id } @$pastAnswers;

	my %flags;
	my %attempted;
	my $previousTime;

	for my $pastAnswer (@pastAnswers) {
		my @answerFlags = map { { type => $_ } } grep { $knownFlags{$_} } split(/,/, $pastAnswer->input_flags // '');

		if ($options{timing} && defined $previousTime && !$attempted{ $pastAnswer->problem_id }) {
			my $scores  = $pastAnswer->scores // '';
			my $seconds = $pastAnswer->timestamp - $previousTime;
			push(@answerFlags, { type => 'fast', seconds => $seconds })
				if $scores ne '' && $scores !~ /[^1]/ && $seconds < $fastSeconds;
		}

		$flags{ $pastAnswer->answer_id }      = \@answerFlags if @answerFlags;
		$attempted{ $pastAnswer->problem_id } = 1;
		$previousTime                         = $pastAnswer->timestamp;
	}

	if ($options{timing} && @pastAnswers >= REGULAR_RUN_LENGTH) {
		# Running totals of the intervals between submissions are used so each run is checked in constant time.
		my @times       = map { $_->timestamp } @pastAnswers;
		my @sums        = (0);
		my @squareSums  = (0);
		my @nonPositive = (0);
		for my $i (1 .. $#times) {
			my $interval = $times[$i] - $times[ $i - 1 ];
			push(@sums,        $sums[-1] + $interval);
			push(@squareSums,  $squareSums[-1] + $interval**2);
			push(@nonPositive, $nonPositive[-1] + ($interval <= 0 ? 1 : 0));
		}

		my %problemCounts;
		$problemCounts{ $_->problem_id }++ for @pastAnswers[ 0 .. REGULAR_RUN_LENGTH - 2 ];

		my %inRegularRun;
		for my $start (0 .. @pastAnswers - REGULAR_RUN_LENGTH) {
			my $end = $start + REGULAR_RUN_LENGTH - 1;
			$problemCounts{ $pastAnswers[$end]->problem_id }++;
			if ($start > 0) {
				my $removed = $pastAnswers[ $start - 1 ]->problem_id;
				delete $problemCounts{$removed} unless --$problemCounts{$removed};
			}

			next if keys %problemCounts < REGULAR_RUN_MIN_PROBLEMS;
			next if $nonPositive[$end] - $nonPositive[$start];

			my $count    = $end - $start;
			my $mean     = ($sums[$end] - $sums[$start]) / $count;
			my $variance = ($squareSums[$end] - $squareSums[$start]) / $count - $mean**2;
			next if sqrt($variance > 0 ? $variance : 0) / $mean > REGULAR_RUN_MAX_VARIATION;

			$inRegularRun{ $_->answer_id } = 1 for @pastAnswers[ $start .. $end ];
		}
		push(@{ $flags{$_} }, { type => 'regular' }) for keys %inRegularRun;
	}

	return \%flags;
}

=head2 answer_flag_description

    my $description = answer_flag_description($c, $flag);

Returns a translated description of a flag returned by C<flag_past_answers>.

=cut

sub answer_flag_description ($c, $flag) {
	return $c->maketext('Correct on the first attempt [quant,_1,second] after the previous submission.',
		$flag->{seconds})
		if $flag->{type} eq 'fast';
	return $c->maketext('Part of a run of submissions on several problems at very regular intervals.')
		if $flag->{type} eq 'regular';
	return $c->maketext('An answer contains LaTeX.') if $flag->{type} eq 'latex';
	return $c->maketext('An answer was submitted without anything entered in its MathQuill answer box.')
		if $flag->{type} eq 'mathquill_blank';
	return $c->maketext('The answers were changed without any keyboard, mouse, or touch input.')
		if $flag->{type} eq 'no_interaction';
	return $c->maketext('The browser reported that it is controlled by automation software.')
		if $flag->{type} eq 'webdriver';
	return $c->maketext(
		'The in-browser checks did not run, so the answers may have been sent without the problem page.')
		if $flag->{type} eq NO_BROWSER_CHECKS_FLAG;
	return $flag->{type};
}

1;
