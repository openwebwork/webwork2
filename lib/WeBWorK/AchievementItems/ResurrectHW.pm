package WeBWorK::AchievementItems::ResurrectHW;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to resurrect a homework for 24 hours

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(after);

use constant ONE_DAY => 86400;

sub new ($class) {
	return bless {
		id          => 'ResurrectHW',
		name        => x('Scroll of Resurrection'),
		description => x("Reopens one closed homework set for 24 hours and rerandomizes all problems."),
	}, $class;
}

sub can_use ($self, $set, $records, $c) {
	return $set->assignment_type eq 'default'
		&& (
			after($set->due_date)
			|| ($c->ce->{pg}{ansEvalDefaults}{enableReducedScoring}
				&& $set->enable_reduced_scoring
				&& after($set->reduced_scoring_date))
		);
}

sub print_form ($self, $set, $records, $c) {
	if (after($set->due_date)) {
		return $c->tag(
			'p',
			$c->maketext(
				'Reopen this homework assignment for the next 24 hours. All problems will be rerandomized.')
		);
	} else {
		if (after($set->due_date - ONE_DAY)) {
			return $c->tag('p',
				$c->maketext('Reopen this homework assignment for full credit for the next 24 hours. '));
		} else {
			return $c->tag(
				'p',
				$c->maketext(
					'Reopen this homework assignment for full credit for the next 24 hours. After 24 hours '
						. 'any progress will revert to counting for [_1]% of the value until [_2].',
					$c->ce->{pg}{ansEvalDefaults}{reducedScoringValue} * 100,
					$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat})
				)
			);
		}
	}
}

sub use_item ($self, $set, $records, $c) {
	my $db                 = $c->db;
	my $userSet            = $db->getUserSet($set->user_id, $set->set_id);
	my $rerandomizeMessage = '';

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
		$rerandomizeMessage = $c->maketext('Problems have been rerandomized.');
	}

	# Add time to the reduced scoring date if it was defined in the first place
	if ($set->reduced_scoring_date) {
		$set->reduced_scoring_date(time + ONE_DAY);
		$userSet->reduced_scoring_date($set->reduced_scoring_date);
	}
	# Add time to the close date if necessary
	if (after($set->due_date - ONE_DAY)) {
		$set->due_date(time + ONE_DAY);
		$userSet->due_date($set->due_date);
		# This may require also extending the answer date.
		if ($set->due_date > $set->answer_date) {
			$set->answer_date($set->due_date);
			$userSet->answer_date($set->answer_date);
		}
	}
	$db->putUserSet($userSet);

	if ($set->enable_reduced_scoring && ($set->reduced_scoring_date != $set->due_date)) {
		return $c->maketext(
			'This assignment has been reopened and is due on [_1].  After that date any work '
				. 'completed will count for [_2]% of its value until [_3].',
			$c->formatDateTime($set->reduced_scoring_date, $c->ce->{studentDateDisplayFormat}),
			$c->ce->{pg}{ansEvalDefaults}{reducedScoringValue} * 100,
			$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat})
		) . ($rerandomizeMessage ? " $rerandomizeMessage" : '');
	} else {
		return $c->maketext(
			'This assignment has been reopened and will now close on [_1].',
			$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat})
		) . ($rerandomizeMessage ? " $rerandomizeMessage" : '');
	}
}

1;
