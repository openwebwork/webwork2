package WeBWorK::AchievementItems::ReducedCred;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend a close date by 24 * $achievementExtensionFactor hours for reduced credit
# Reduced scoring needs to be enabled for this item to work.

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(after between getExtensionTime);

sub new ($class, $c) {
	my ($time, $timeText) = getExtensionTime($c, 1);

	return bless {
		id          => 'ReducedCred',
		name        => x('Ring of Reduction'),
		description => [
			x(
				'Enable reduced scoring for a homework set.  This will allow you to submit answers '
					. 'for partial credit for [_1] after the close date. '
					. 'This will randomize problem details if used after the original close date.',
				$timeText
			)
		],
		time     => $time,
		timeText => $timeText
	}, $class;
}

sub can_use ($self, $set, $records, $c) {
	return $set->assignment_type eq 'default' && between($set->open_date, $set->due_date + $self->{time});
}

sub print_form ($self, $set, $records, $c) {
	my $ce = $c->ce;

	return $c->tag(
		'p',
		$c->maketext(
			q{This item won't work unless your instructor enables the reduced scoring feature.  }
				. 'Let your instructor know that you received this message.'
		)
	) unless $ce->{pg}{ansEvalDefaults}{enableReducedScoring};

	my $randomization_statement = after($set->due_date) ? $c->maketext('All problems will be rerandomized.') : '';
	return $c->tag(
		'p',
		$c->maketext(
			'Extend the close date of this assignment to [_1] (an additional [_2]).  Any submissions during '
				. 'this additional time will be reduced and are worth [_3]% of their full value. [_4]',
			$c->formatDateTime($set->due_date + $self->{time}, $ce->{studentDateDisplayFormat}),
			$self->{timeText},
			100 * $ce->{pg}{ansEvalDefaults}{reducedScoringValue},
			$randomization_statement
		)
	);
}

sub use_item ($self, $set, $records, $c) {
	my $ce = $c->ce;
	my $db = $c->db;

	# Still need to double check reduced scoring is enabled.
	return '' unless $ce->{pg}{ansEvalDefaults}{enableReducedScoring};

	my $userSet = $db->getUserSet($set->user_id, $set->set_id);

	# Change the seed for all of the problems if the set is currently closed.
	if (after($set->due_date)) {
		my %userProblems =
			map { $_->problem_id => $_ }
			$db->getUserProblemsWhere({ user_id => $set->user_id, set_id => $set->set_id });
		for my $problem (@$records) {
			my $userProblem = $userProblems{ $problem->problem_id };
			$userProblem->problem_seed($userProblem->problem_seed % 2**31 + 1);
			$problem->problem_seed($userProblem->problem_seed);
			$db->putUserProblem($userProblem);
		}
	}

	# Either there is already a valid reduced scoring date, or set the reduced scoring date to the close date.
	unless ($set->reduced_scoring_date && $set->reduced_scoring_date < $set->due_date) {
		$set->reduced_scoring_date($set->due_date);
		$userSet->reduced_scoring_date($set->reduced_scoring_date);
	}
	$set->enable_reduced_scoring(1);
	$userSet->enable_reduced_scoring(1);
	# Add time to the close date
	$set->due_date($set->due_date + $self->{time});
	$userSet->due_date($set->due_date);
	# This may require also extending the answer date.
	if ($set->due_date > $set->answer_date) {
		$set->answer_date($set->due_date);
		$userSet->answer_date($set->answer_date);
	}
	$db->putUserSet($userSet);

	return $c->maketext('Close date of this assignment extended by [_1] to [_2].',
		$self->{timeText}, $c->formatDateTime($set->due_date, $ce->{studentDateDisplayFormat}));
}

1;
