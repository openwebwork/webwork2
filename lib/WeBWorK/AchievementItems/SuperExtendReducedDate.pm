package WeBWorK::AchievementItems::SuperExtendReducedDate;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend a close date by 48 hours.

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(between);

use constant TWO_DAYS => 172800;

sub new ($class) {
	return bless {
		id          => 'SuperExtendReducedDate',
		name        => x('Scroll of Longevity'),
		description => x(
			'Adds 48 hours to the reduced scoring date of an assignment.  You will have to resubmit '
				. 'any problems that have already been penalized to earn full credit.  You cannot '
				. 'extend the reduced scoring date beyond the due date of an assignment.'
		)
	}, $class;
}

sub can_use ($self, $set, $records) {
	return 0
		unless $set->assignment_type eq 'default'
		&& $set->enable_reduced_scoring
		&& $set->reduced_scoring_date
		&& $set->reduced_scoring_date < $set->due_date;

	$self->{new_date} = $set->reduced_scoring_date + TWO_DAYS;
	$self->{new_date} = $set->due_date if $set->due_date < $self->{new_date};
	return between($set->open_date, $self->{new_date});
}

sub print_form ($self, $set, $records, $c) {
	return $c->tag(
		'p',
		$c->maketext(
			q{This item won't work unless your instructor enables the reduced scoring feature.  }
				. 'Let your instructor know that you recieved this message.'
		)
	) unless $c->{ce}->{pg}{ansEvalDefaults}{enableReducedScoring};

	return $c->tag(
		'p',
		$c->maketext(
			'Extend the reduced scoring date to [_1] (an additional 48 hours).',
			$c->formatDateTime($self->{new_date}, $c->ce->{studentDateDisplayFormat})
		)
	);
}

sub use_item ($self, $set, $records, $c) {
	return '' unless $c->{ce}->{pg}{ansEvalDefaults}{enableReducedScoring};

	my $db      = $c->db;
	my $userSet = $db->getUserSet($set->user_id, $set->set_id);

	$set->reduced_scoring_date($self->{new_date});
	$userSet->reduced_scoring_date($set->reduced_scoring_date);
	$db->putUserSet($userSet);

	return $c->maketext(
		'Reduced scoring date of this assignment extended by 48 hours to [_1].',
		$c->formatDateTime($self->{new_date}, $c->ce->{studentDateDisplayFormat})
	);
}

1;
