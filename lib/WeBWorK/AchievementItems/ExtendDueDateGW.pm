package WeBWorK::AchievementItems::ExtendDueDateGW;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend the close date on a test

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(before between);

use constant ONE_DAY => 86400;

sub new ($class) {
	return bless {
		id          => 'ExtendDueDateGW',
		name        => x('Amulet of Extension'),
		description => x('Extends the close date of a test by 24 hours.')
	}, $class;
}

sub can_use ($self, $set, $records, $c) {
	return
		$set->assignment_type =~ /gateway/
		&& $set->set_id !~ /,v\d+$/
		&& between($set->open_date, $set->due_date + ONE_DAY);
}

sub print_form ($self, $set, $records, $c) {
	if ($set->enable_reduced_scoring) {
		if (before($set->reduced_scoring_date + ONE_DAY)) {
			return $c->c(
				$c->tag('p', $c->maketext('Extend the deadline by 24 hours.')),
				$c->tag(
					'ul',
					$c->c(
						$c->tag(
							'li',
							$c->maketext(
								'You will be able to receive full credit until [_1].',
								$c->formatDateTime(
									$set->reduced_scoring_date + ONE_DAY,
									$c->ce->{studentDateDisplayFormat}
								)
							)
						),
						$c->tag(
							'li',
							$c->maketext(
								'You will be able to receive reduced credit until [_1].',
								$c->formatDateTime($set->due_date + ONE_DAY, $c->ce->{studentDateDisplayFormat})
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
						'Extend the reduced credit deadline of this assignment to [_1] (an additional 24 hours).',
						$c->formatDateTime($set->due_date + ONE_DAY, $c->ce->{studentDateDisplayFormat})
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
				'Extend the close date of this assignment to [_1] (an additional 24 hours).',
				$c->formatDateTime($set->due_date + ONE_DAY, $c->ce->{studentDateDisplayFormat})
			)
		);
	}
}

sub use_item ($self, $set, $records, $c) {
	my $db      = $c->db;
	my $userSet = $db->getUserSet($set->user_id, $set->set_id);

	# Add time to the reduced scoring date, due date, and answer date.
	if ($set->reduced_scoring_date) {
		$set->reduced_scoring_date($set->reduced_scoring_date + ONE_DAY);
		$userSet->reduced_scoring_date($set->reduced_scoring_date);
	}
	$set->due_date($set->due_date + ONE_DAY);
	$userSet->due_date($set->due_date);
	$set->answer_date($set->answer_date + ONE_DAY);
	$userSet->answer_date($set->answer_date);
	$db->putUserSet($userSet);

	# FIXME: Should we add time to each test version, as adding 24 hours to a 1 hour long test
	# isn't reasonable. Disabling this for now, will revisit later.
	# Add time to the reduced scoring date, due date, and answer date for all versions.
	#my @versions = $db->listSetVersions($userName, $setID);
	#for my $version (@versions) {
	#	$set = $db->getSetVersion($userName, $setID, $version);
	#	$set->reduced_scoring_date($set->reduced_scoring_date() + ONE_DAY)
	#		if defined($set->reduced_scoring_date()) && $set->reduced_scoring_date();
	#	$set->due_date($set->due_date() + ONE_DAY);
	#	$set->answer_date($set->answer_date() + ONE_DAY);
	#	$db->putSetVersion($set);
	#}

	return $c->maketext('Close date of this test extended by 24 hours to [_1].',
		$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat}));
}

1;
