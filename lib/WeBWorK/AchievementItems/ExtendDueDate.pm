package WeBWorK::AchievementItems::ExtendDueDate;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend a close date by 24 * $achievementExtensionFactor hours.

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(before after between getExtensionTime);

sub new ($class, $c) {
	my ($time, $timeText) = getExtensionTime($c, 1);

	return bless {
		id          => 'ExtendDueDate',
		name        => x('Tunic of Extension'),
		description => [
			x(
				'Adds [_1] to the close date of a homework. '
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
	my $randomization_statement = after($set->due_date) ? $c->maketext('All problems will be rerandomized.') : '';
	if ($set->enable_reduced_scoring) {
		if (before($set->reduced_scoring_date + $self->{time})) {
			return $c->c(
				$c->tag(
					'p',
					$c->maketext('Extend the deadline by [_1]. [_2]', $self->{timeText}, $randomization_statement)
				),
				$c->tag(
					'ul',
					$c->c(
						$c->tag(
							'li',
							$c->maketext(
								'You will be able to receive full credit until [_1].',
								$c->formatDateTime(
									$set->reduced_scoring_date + $self->{time},
									$c->ce->{studentDateDisplayFormat}
								)
							)
						),
						$c->tag(
							'li',
							$c->maketext(
								'You will be able to receive reduced credit until [_1].',
								$c->formatDateTime(
									$set->due_date + $self->{time},
									$c->ce->{studentDateDisplayFormat}
								)
							)
						)
					)->join('')
				),
			)->join('');
		} else {
			return $c->c(
				$c->tag(
					'p',
					$c->maketext(
						'Extend the reduced credit deadline of this assignment to [_1] (an additional [_2]). [_3]',
						$c->formatDateTime($set->due_date + $self->{time}, $c->ce->{studentDateDisplayFormat}),
						$self->{timeText},
						$randomization_statement
					)
				),
				$c->tag(
					'p',
					$c->maketext(
						'Because the deadline has already passed you will only '
							. 'receive reduced credit during this extension.'
					)
				)
			)->join('');
		}

	} else {
		return $c->tag(
			'p',
			$c->maketext(
				'Extend the close date of this assignment to [_1] (an additional [_2]). [_3]',
				$c->formatDateTime($set->due_date + $self->{time}, $c->ce->{studentDateDisplayFormat}),
				$self->{timeText},
				$randomization_statement
			)
		);
	}

}

sub use_item ($self, $set, $records, $c) {
	my $db      = $c->db;
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

	# Add time to the reduced scoring date if it was defined in the first place
	if ($set->reduced_scoring_date) {
		$set->reduced_scoring_date($set->reduced_scoring_date + $self->{time});
		$userSet->reduced_scoring_date($set->reduced_scoring_date);
	}
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
		$self->{timeText}, $c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat}));
}

1;
