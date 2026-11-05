package WeBWorK::Utils::AnswerFlags;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::Utils::AnswerFlags - Flag answer submissions that show signs that the
answers may not have been entered by the student, for example by an AI agent.

=head1 DESCRIPTION

Flags are evidence for an instructor to investigate, not proof.  They must never
be shown to students.

Flagging is configured by C<$options{flagUnusualAnswers}>.  If it is 0, then
nothing is flagged.  If it is 1, then only the checks done on the stored
submission data (timing and LaTeX) are used.  If it is 2, then the in-browser
checks done by the problem page javascript are also used.

=cut

our @EXPORT_OK =
	qw(browser_checks_enabled clean_input_flags answer_types_from_flags flag_past_answers answer_flag_description);

# Flags that the problem page javascript may send with a submission.
use constant INPUT_FLAGS => { no_interaction => 1, webdriver => 1 };

# The number of consecutive submissions, the minimum number of distinct problems in those submissions, and the maximum
# coefficient of variation of the time between them for a run of submissions to be flagged as at regular intervals.
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

=head2 clean_input_flags

    my $inputFlags = clean_input_flags($c->param('inputFlags'));

Returns a comma separated string of the known flags in the given comma separated
string of flags sent by the problem page javascript.

=cut

sub clean_input_flags ($flags) {
	return join(',', grep { INPUT_FLAGS->{$_} } split(/,/, $flags // ''));
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

    my $flags = flag_past_answers($ce, \@pastAnswers, timing => 1, answerTypes => \%answerTypes);

Takes a reference to an array of the past answer records of one user for one set
(or one version of a test), and returns a reference to a hash whose keys are the
answer ids of the flagged past answers, and whose values are references to arrays
of flags.  Each flag is a hash with a C<type> key, and possibly other keys with
details for that type.

Flags saved by the in-browser checks are only included if those checks are
currently enabled for the course.

If the C<timing> option is true, then submissions are flagged that are correct on
the first attempt very soon after the previous submission, or that are part of a
run of submissions on several problems at very regular intervals.  These checks
should not be done for tests since all problems in a test are submitted at once.

The C<answerTypes> option is a reference to a hash whose keys are problem ids and
whose values are references to arrays of the answer types for the problem.
Submissions that contain LaTeX in an answer that is not an essay answer are
flagged.  Answers for problems that are not in this hash, or whose answer types
are not known, are not checked.

=cut

sub flag_past_answers ($ce, $pastAnswers, %options) {
	my $answerTypes = $options{answerTypes}                 // {};
	my $fastSeconds = $ce->{options}{flagFastAnswerSeconds} // 0;
	my $inputFlags  = browser_checks_enabled($ce);

	my @pastAnswers = sort { $a->timestamp <=> $b->timestamp || $a->answer_id <=> $b->answer_id } @$pastAnswers;

	my %flags;
	my %attempted;
	my $previousTime;

	for my $pastAnswer (@pastAnswers) {
		my @answerFlags =
			$inputFlags ? map { { type => $_ } } split(/,/, clean_input_flags($pastAnswer->input_flags)) : ();

		if ($options{timing} && defined $previousTime && !$attempted{ $pastAnswer->problem_id }) {
			my $scores  = $pastAnswer->scores // '';
			my $seconds = $pastAnswer->timestamp - $previousTime;
			push(@answerFlags, { type => 'fast', seconds => $seconds })
				if $scores ne '' && $scores !~ /[^1]/ && $seconds < $fastSeconds;
		}

		my $types = $answerTypes->{ $pastAnswer->problem_id };
		if ($types && @$types) {
			my @answers = split(/\t/, $pastAnswer->answer_string // '');
			push(@answerFlags, { type => 'latex' })
				if grep { ($types->[$_] // '') ne 'essay' && $answers[$_] =~ /\\[a-zA-Z]{2,}/ } 0 .. $#answers;
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
	return $c->maketext('The answers were changed without any keyboard, mouse, or touch input.')
		if $flag->{type} eq 'no_interaction';
	return $c->maketext('The browser reported that it is controlled by automation software.')
		if $flag->{type} eq 'webdriver';
	return $flag->{type};
}

1;
