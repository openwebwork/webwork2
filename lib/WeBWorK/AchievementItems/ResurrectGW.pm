package WeBWorK::AchievementItems::ResurrectGW;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to extend the due date on a gateway

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(after);

use constant ONE_DAY => 86400;

sub new ($class) {
	return bless {
		id          => 'ResurrectGW',
		name        => x('Necromancers Charm'),
		description => x(
			'Reopens any test for an additional 24 hours. This allows you to take a test even if the '
				. 'close date has past. This item does not allow you to take additional versions of the test.'
		)
	}, $class;
}

sub can_use($self, $set, $records) {
	return $set->assignment_type =~ /gateway/
		&& (after($set->due_date) || ($set->reduced_scoring_date && after($set->reduced_scoring_date)));
	# TODO: Check if a new version can be created, and only allow using this reward in that case.
}

sub print_form ($self, $set, $records, $c) {
	return $c->tag(
		'p',
		$c->maketext(
			'Reopen this test for the next 24 hours. This item does not allow you to take any additional '
				. 'versions of the test.'
		)
	);
}

sub use_item ($self, $set, $records, $c) {
	my $db      = $c->db;
	my $userSet = $db->getUserSet($set->user_id, $set->set_id);

	# Add time to the reduced scoring date, due date, and answer date.
	if ($set->reduced_scoring_date) {
		$set->reduced_scoring_date(time + ONE_DAY);
		$userSet->reduced_scoring_date($set->reduced_scoring_date);
	}
	$set->due_date(time + ONE_DAY);
	$userSet->due_date($set->due_date);
	if ($set->due_date > $set->answer_date) {
		$set->answer_date(time + ONE_DAY);
		$userSet->answer_date($set->answer_date);
	}
	$db->putUserSet($userSet);

	return $c->maketext(
		'This assignment has been reopened and will now close on [_1].',
		$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat})
	);
}

1;
