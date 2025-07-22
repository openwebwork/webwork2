package WeBWorK::AchievementItems::DuplicateProb;
use Mojo::Base 'WeBWorK::AchievementItems', -signatures;

# Item to turn one problem into another problem

use WeBWorK::Utils           qw(x);
use WeBWorK::Utils::DateTime qw(between);

sub new ($class) {
	return bless {
		id          => 'DuplicateProb',
		name        => x('Box of Transmogrification'),
		description => x('Causes a homework problem to become a clone of another problem from the same set.')
	}, $class;
}

sub can_use ($self, $set, $records) {
	return $set->assignment_type eq 'default' && between($set->open_date, $set->due_date);
}

sub print_form ($self, $set, $records, $c) {
	return $c->c(
		$c->tag('p', $c->maketext('Replaces the second problem with a copy of the first.')),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'clone_source_problem_id',
			label_text => $c->maketext('Problem number to copy'),
			first_item => $c->maketext('Choose problem to copy from.'),
			values     => [ map { [ $c->maketext('Problem [_1]', $_->problem_id) => $_->problem_id ] } @$records ],
		),
		WeBWorK::AchievementItems::form_popup_menu_row(
			$c,
			id         => 'clone_dest_problem_id',
			label_text => $c->maketext('Problem number to replace'),
			first_item => $c->maketext('Choose problem to replace.'),
			values     => [ map { [ $c->maketext('Problem [_1]', $_->problem_id) => $_->problem_id ] } @$records ],
		),
	)->join('');
}

sub use_item ($self, $set, $records, $c) {
	my $sourceID = $c->param('clone_source_problem_id');
	my $destID   = $c->param('clone_dest_problem_id');
	unless ($sourceID) {
		$c->addbadmessage($c->maketext('Select problem to clone with the [_1].', $self->name));
		return '';
	}
	unless ($destID) {
		$c->addbadmessage($c->maketext('Select problem to replace with the [_1].', $self->name));
		return '';
	}

	my ($sourceProblem, $destProblem);
	for (@$records) {
		$sourceProblem = $_ if $_->problem_id == $sourceID;
		$destProblem   = $_ if $_->problem_id == $destID;
		last if $sourceProblem && $destProblem;
	}
	return '' unless $sourceProblem && $destProblem;

	my $db          = $c->db;
	my $userProblem = $db->getUserProblem($destProblem->user_id, $destProblem->set_id, $destProblem->problem_id);
	$destProblem->source_file($sourceProblem->source_file);
	$userProblem->source_file($destProblem->source_file);
	$db->putUserProblem($userProblem);

	return $c->maketext("Problem [_1] replaced with problem [_2].", $destID, $sourceID);
}

1;
