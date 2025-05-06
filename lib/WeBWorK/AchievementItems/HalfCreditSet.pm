package WeBWorK::AchievementItems::HalfCreditSet;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to give half credit on all problems in a homework set.

use WeBWorK::Utils           qw(x wwRound);
use WeBWorK::Utils::DateTime qw(after);

sub new ($class) {
	return bless {
		id          => 'HalfCreditSet',
		name        => x('Lesser Tome of Enlightenment'),
		description => x('Increases the score of every problem in an assignment by 50%, to a maximum of 100%.')
	}, $class;
}

sub can_use($self, $set, $records) {
	return 0
		unless $set->assignment_type eq 'default'
		&& after($set->open_date);

	my $total     = 0;
	my $old_grade = 0;
	my $new_grade = 0;
	for my $problem (@$records) {
		$old_grade += $problem->status * $problem->value;
		$new_grade += ($problem->status > 0.5 ? 1 : $problem->status + 0.5) * $problem->value;
		$total     += $problem->value;
	}
	$self->{old_grade} = 100 * wwRound(2, $old_grade / $total);
	$self->{new_grade} = 100 * wwRound(2, $new_grade / $total);
	return $self->{old_grade} == 100 ? 0 : 1;
}

sub print_form ($self, $set, $records, $c) {
	return $c->tag(
		'p',
		$c->maketext(
			q(Increase this assignment's grade from [_1]% to [_2]%.),
			$self->{old_grade}, $self->{new_grade}
		)
	);
}

sub use_item ($self, $set, $records, $c) {
	my $db = $c->db;

	my %userProblems =
		map { $_->problem_id => $_ } $db->getUserProblemsWhere({ user_id => $set->user_id, set_id => $set->set_id });
	for my $problem (@$records) {
		my $userProblem = $userProblems{ $problem->problem_id };
		$problem->status($problem->status > 0.5 ? 1 : $problem->status + 0.5);
		$problem->sub_status($problem->status);
		$userProblem->status($problem->status);
		$userProblem->sub_status($problem->status);
		$db->putUserProblem($userProblem);
	}

	return $c->maketext(q(Assignment's grade increased from [_1] to [_2].), $self->{old_grade}, $self->{new_grade});
}

1;
