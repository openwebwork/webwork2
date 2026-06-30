package WeBWorK::AchievementItems::ExtendDueDateGW;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend the close date on a test

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(before between getExtensionTime);

sub new ($class, $c) {
	my ($time, $timeText) = getExtensionTime($c, 1);

	return bless {
		id          => 'ExtendDueDateGW',
		name        => x('Amulet of Extension'),
		description => [ x('Extends the close date of a test by [_1].', $timeText) ],
		time        => $time,
		timeText    => $timeText,
	}, $class;
}

sub can_use ($self, $set, $records, $c) {
	return
		$set->assignment_type =~ /gateway/
		&& $set->set_id !~ /,v\d+$/
		&& between($set->open_date, $set->due_date + $self->{time});
}

sub print_form ($self, $set, $records, $c) {
	if ($set->enable_reduced_scoring) {
		if (before($set->reduced_scoring_date + $self->{time})) {
			return $c->c(
				$c->tag('p', $c->maketext('Extend the deadline by [_1].', $self->{timeText})),
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
						'Extend the reduced credit deadline of this assignment to [_1] (an additional [_2]).',
						$c->formatDateTime($set->due_date + $self->{time}, $c->ce->{studentDateDisplayFormat}),
						$self->{timeText}
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
				'Extend the close date of this assignment to [_1] (an additional [_2]).',
				$c->formatDateTime($set->due_date + $self->{time}, $c->ce->{studentDateDisplayFormat}),
				$self->{timeText}
			)
		);
	}
}

sub use_item ($self, $set, $records, $c) {
	my $db      = $c->db;
	my $userSet = $db->getUserSet($set->user_id, $set->set_id);

	# Add time to the reduced scoring date, due date, and answer date.
	if ($set->reduced_scoring_date) {
		$set->reduced_scoring_date($set->reduced_scoring_date + $self->{time});
		$userSet->reduced_scoring_date($set->reduced_scoring_date);
	}
	$set->due_date($set->due_date + $self->{time});
	$userSet->due_date($set->due_date);
	$set->answer_date($set->answer_date + $self->{time});
	$userSet->answer_date($set->answer_date);
	$db->putUserSet($userSet);

	# FIXME: Should we add time to each test version, as adding 24 hours to a 1 hour long test
	# isn't reasonable. Disabling this for now, will revisit later.
	# Add time to the reduced scoring date, due date, and answer date for all versions.
	#my @versions = $db->listSetVersions($userName, $setID);
	#for my $version (@versions) {
	#	$set = $db->getSetVersion($userName, $setID, $version);
	#	$set->reduced_scoring_date($set->reduced_scoring_date() + $self->{time})
	#		if defined($set->reduced_scoring_date()) && $set->reduced_scoring_date();
	#	$set->due_date($set->due_date() + $self->{time});
	#	$set->answer_date($set->answer_date() + $self->{time});
	#	$db->putSetVersion($set);
	#}

	return $c->maketext('Close date of this test extended by [_1] to [_2].',
		$self->{timeText}, $c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat}));
}

1;
