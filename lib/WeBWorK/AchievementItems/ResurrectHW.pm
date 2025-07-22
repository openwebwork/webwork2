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

sub can_use($self, $set, $records) {
	return $set->assignment_type eq 'default'
		&& (after($set->due_date) || ($set->reduced_scoring_date && after($set->reduced_scoring_date)));
}

sub print_form ($self, $set, $records, $c) {
	return $c->tag('p',
		$c->maketext('Reopen this homework assignment for the next 24 hours. All problems will be rerandomized.'));
}

sub use_item ($self, $set, $records, $c) {
	my $db      = $c->db;
	my $userSet = $db->getUserSet($set->user_id, $set->set_id);

	# Change the seed for all of the problems since the set is currently closed.
	my %userProblems =
		map { $_->problem_id => $_ } $db->getUserProblemsWhere({ user_id => $set->user_id, set_id => $set->set_id });
	for my $problem (@$records) {
		my $userProblem = $userProblems{ $problem->problem_id };
		$userProblem->problem_seed($userProblem->problem_seed % 2**31 + 1);
		$problem->problem_seed($userProblem->problem_seed);
		$db->putUserProblem($userProblem);
	}

	# Add time to the reduced scoring date if it was defined in the first place
	if ($set->reduced_scoring_date) {
		$set->reduced_scoring_date(time + ONE_DAY);
		$userSet->reduced_scoring_date($set->reduced_scoring_date);
	}
	# Add time to the close date
	$set->due_date(time + ONE_DAY);
	$userSet->due_date($set->due_date);
	# This may require also extending the answer date.
	if ($set->due_date > $set->answer_date) {
		$set->answer_date($set->due_date);
		$userSet->answer_date($set->answer_date);
	}
	$db->putUserSet($userSet);

	return $c->maketext(
		'This assignment has been reopened and will now close on [_1]. Problems have been rerandomized.',
		$c->formatDateTime($set->due_date, $c->ce->{studentDateDisplayFormat}));
}

1;
