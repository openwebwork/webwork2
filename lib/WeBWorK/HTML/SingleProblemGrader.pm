package WeBWorK::HTML::SingleProblemGrader;
use Mojo::Base -signatures;

=head1 NAME

WeBWorK::HTML::SingleProblemGrader is a module for manually grading a single
webwork problem.  It is displayed with the problem when an instructor is acting
as a student.

=cut

use WeBWorK::Localize;
use WeBWorK::Utils 'wwRound';

sub new ($class, $c, $pg, $userProblem) {
	$class = ref($class) || $class;

	my $db           = $c->db;
	my $courseID     = $c->stash('courseID');
	my $setID        = $userProblem->set_id;
	my $versionID    = ref($userProblem) =~ /::ProblemVersion/ ? $userProblem->version_id : 0;
	my $studentID    = $userProblem->user_id;
	my $problemID    = $userProblem->problem_id;
	my $problemValue = $userProblem->value;

	# Get the currently saved score.
	my $recordedScore = $userProblem->status;

	# Retrieve the latest past answer and comment (if any).
	my $userPastAnswerID =
		$db->latestProblemPastAnswer($studentID, $setID . ($versionID ? ",v$versionID" : ''), $problemID);
	my $pastAnswer = $userPastAnswerID ? $db->getPastAnswer($userPastAnswerID) : 0;
	my $comment    = $pastAnswer       ? $pastAnswer->comment_string           : '';

	my $self = {
		pg             => $pg,
		course_id      => $courseID,
		student_id     => $studentID,
		problem_id     => $problemID,
		problem_value  => $problemValue,
		set_id         => $setID,
		version_id     => $versionID,
		recorded_score => $recordedScore,
		past_answer_id => $userPastAnswerID // 0,
		comment_string => $comment,
		c              => $c
	};
	bless $self, $class;

	return $self;
}

# Output the problem grader.
sub insertGrader ($self) {
	return $self->{c}->include('HTML/SingleProblemGrader/grader', grader => $self);
}

1;
