package WeBWorK::AchievementItems::ResurrectGW;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend the due date on a gateway

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(after getExtensionTime);

sub new ($class, $c) {
	my ($time, $timeText) = getExtensionTime($c, 1);

	return bless {
		id          => 'ResurrectGW',
		name        => x('Necromancers Charm'),
		description => [
			x(
				'Reopens any test for an additional [_1]. If you are allowed to start new versions of the test, '
					. 'then this allows you to start a new test even if the close date has past. '
					. 'If you were not allowed to start a new version of the test, '
					. 'then this item will not allow you to take additional versions of the test. '
					. 'This item will not extend the time limit for any tests that you have already started.',
				$timeText
			)
		],
		time     => $time,
		timeText => $timeText
	}, $class;
}

sub can_use ($self, $set, $records, $c) {
	return $set->assignment_type =~ /gateway/
		&& (
			after($set->due_date)
			|| ($c->ce->{pg}{ansEvalDefaults}{enableReducedScoring}
				&& $set->enable_reduced_scoring
				&& after($set->reduced_scoring_date))
		);
	# TODO: Check if a new version can be created, and only allow using this reward in that case.
}

sub print_form ($self, $set, $records, $c) {
	if (after($set->due_date)) {
		return $c->tag(
			'p',
			$c->maketext(
				'Reopen this test for the next [_1]. If you were allowed to start new versions of the test, '
					. 'then this will allow you to start a new test. '
					. 'If you have already started all of the versions of the test that you are allowed to start, '
					. 'then you should not use this item. '
					. 'This item will not extend the time limit for any tests that you have already started.',
				$self->{timeText}
			)
		);
	} else {
		if (after($set->due_date - $self->{time})) {
			return $c->tag(
				'p',
				$c->maketext(
					'Reopen this test for full credit for the next [_1]. If you are allowed to start new versions '
						. 'of the test, then this will allow you to start a new test. '
						. 'If you have already started all of the versions of the test that you are allowed to start, '
						. 'then you should not use this item. '
						. 'This item will not extend the time limit for any tests that you have already started.',
					$self->{timeText}
				)
			);
		} else {
			return $c->c(
				$c->tag(
					'p',
					$c->maketext(
						'Reopen this test for full credit for the next [_1].  After [_1] any tests will revert '
							. 'to counting for [_2]% of their value until [_3].',
						$c->{timeText},
						$c->ce->{pg}{ansEvalDefaults}{reducedScoringValue} * 100,
						$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat})
					)
				),
				$c->tag(
					'p',
					$c->maketext(
						' If you are allowed to start new versions of the test, '
							. 'then this will allow you to start a new test. '
							. 'If you have already started all of the versions of the test that you are allowed to start, '
							. 'then you should not use this item. '
							. 'This item will not extend the time limit for any tests that you have already started.'
					)
				)
			)->join('');
		}
	}
}

sub use_item ($self, $set, $records, $c) {
	my $db      = $c->db;
	my $userSet = $db->getUserSet($set->user_id, $set->set_id);

	# Add time to the reduced scoring date, due date, and answer date.
	if ($set->reduced_scoring_date) {
		$set->reduced_scoring_date(time + $self->{time});
		$userSet->reduced_scoring_date($set->reduced_scoring_date);
	}
	if (after($set->due_date - $self->{time})) {
		$set->due_date(time + $self->{time});
		$userSet->due_date($set->due_date);
		if ($set->due_date > $set->answer_date) {
			$set->answer_date($set->due_date);
			$userSet->answer_date($set->answer_date);
		}
	}
	$db->putUserSet($userSet);

	if ($c->ce->{pg}{ansEvalDefaults}{enableReducedScoring}
		&& $set->enable_reduced_scoring
		&& ($set->reduced_scoring_date != $set->due_date))
	{
		return $c->maketext(
			'This assignment has been reopened and is due on [_1].  After that date any work '
				. 'completed will count for [_2]% of its value until [_3].',
			$c->formatDateTime($set->reduced_scoring_date, $c->ce->{studentDateDisplayFormat}),
			$c->ce->{pg}{ansEvalDefaults}{reducedScoringValue} * 100,
			$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat})
		);
	} else {
		return $c->maketext(
			'This assignment has been reopened and will now close on [_1].',
			$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat})
		);
	}
}

1;
