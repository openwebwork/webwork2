package WeBWorK::AchievementItems::HalfCreditProb;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to give half credit on a single problem.

use WeBWorK::Utils           qw(x wwRound);
use WeBWorK::Utils::DateTime qw(after);

sub new ($class) {
	return bless {
		id          => 'HalfCreditProb',
		name        => x('Lesser Rod of Revelation'),
		description => x('Increases the grade of a single problem by 50%, to a maximum of 100%.')
	}, $class;
}

sub can_use($self, $set, $records) {
	return 0
		unless $set->assignment_type eq 'default'
		&& after($set->open_date);

	$self->{unfinishedProblems} = [ grep { $_->status < 1 } @$records ];
	return @{ $self->{unfinishedProblems} } ? 1 : 0;
}

sub print_form ($self, $set, $records, $c) {
	return WeBWorK::AchievementItems::form_popup_menu_row(
		$c,
		id         => 'half_cred_problem_id',
		label_text => $c->maketext('Problem number to increase grade by 50%'),
		first_item => $c->maketext('Choose problem to increase grade by 50%.'),
		values     => [
			map { [
				$c->maketext(
					'Problem [_1] ([_2]% to [_3]%)',
					$_->problem_id,
					100 * wwRound(2, $_->status),
					100 * wwRound(2, $_->status < 0.5 ? $_->status + 0.5 : 1)
				) => $_->problem_id
			] } @{ $self->{unfinishedProblems} }
		],
	);
}

sub use_item ($self, $set, $records, $c) {
	my $problemID = $c->param('half_cred_problem_id');
	unless ($problemID) {
		$c->addbadmessage($c->maketext('Select problem to increase its grade by 50% with the [_1].', $self->name));
		return '';
	}

	my $problem;
	for (@$records) {
		if ($_->problem_id == $problemID) {
			$problem = $_;
			last;
		}
	}
	return '' unless $problem;

	# Increase status to 100%.
	my $db          = $c->db;
	my $userProblem = $db->getUserProblem($problem->user_id, $problem->set_id, $problem->problem_id);
	$problem->status($problem->status > 0.5 ? 1 : $problem->status + 0.5);
	$problem->sub_status($problem->status);
	$userProblem->status($problem->status);
	$userProblem->sub_status($problem->status);
	$db->putUserProblem($userProblem);

	return $c->maketext('Problem number [_1] grade increased to [_2]%.', $problemID,
		100 * wwRound(2, $problem->status));
}

1;
