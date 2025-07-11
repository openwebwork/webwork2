package WeBWorK::AchievementItems::DoubleSet;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to make a homework set worth twice as much

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(after);

sub new ($class) {
	return bless {
		id          => 'DoubleSet',
		name        => x('Cake of Enlargement'),
		description => x('Cause the selected homework set to count for twice as many points as it normally would.')
	}, $class;
}

sub can_use ($self, $set, $records) {
	return $set->assignment_type eq 'default' && after($set->open_date);
}

sub print_form ($self, $set, $records, $c) {
	my $total = 0;
	for my $problem (@$records) {
		$total += $problem->value;
	}
	return $c->tag('p',
		$c->maketext(q(Increase this assignment's total number of points from [_1] to [_2].), $total, 2 * $total));
}

sub use_item ($self, $set, $records, $c) {
	my $db        = $c->db;
	my $old_value = 0;
	my $new_value = 0;

	my %userProblems =
		map { $_->problem_id => $_ } $db->getUserProblemsWhere({ user_id => $set->user_id, set_id => $set->set_id });
	for my $problem (@$records) {
		my $userProblem = $userProblems{ $problem->problem_id };
		$old_value += $problem->value;
		$problem->value(2 * $problem->value);
		$userProblem->value($problem->value);
		$new_value += $userProblem->value;
		$db->putUserProblem($userProblem);
	}

	return $c->maketext(q(Assignment's total point value increased from [_1] points to [_2] points),
		$old_value, $new_value);
}

1;
