package WeBWorK::ContentGenerator::API::ProblemActions;
use Mojo::Base 'WeBWorK::ContentGenerator::API', -signatures;

use Data::Structure::Util qw(unbless);

use WeBWorK::PG::Tidy          qw(pgtidy);
use WeBWorK::PG::ConvertToPGML qw(convertToPGML);
use WeBWorK::PG::Critic        qw(critiquePGCode);

our @apiCalls = qw(
	getUserProblem
	putUserProblem
	putProblemVersion
	putPastAnswer
	tidyPGCode
	convertCodeToPGML
	runPGCritic
);

sub apiCall ($invocant, $command) {
	return (grep { $_ eq $command } @apiCalls) && $invocant->can($command);
}

sub getUserProblem ($c) {
	return $c->renderError('You do not have permission for the getUserProblem API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	return $c->render(
		json => unbless($c->db->getUserProblem(
			$c->req->param('user_id'),
			$c->req->param('set_id'),
			$c->req->param('problem_id')
		))
	);
}

sub putUserProblem ($c) {
	return $c->renderError('You do not have permission for the putUserProblem API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'problem_grader');

	my $userProblem =
		$c->db->getUserProblem($c->req->param('user_id'), $c->req->param('set_id'), $c->req->param('problem_id'));
	return $c->renderError('User problem not found.') unless $userProblem;

	if ($c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data')) {
		for (
			'source_file',          'value',               'max_attempts', 'showMeAnother',
			'showMeAnotherCount',   'prPeriod',            'prCount',      'problem_seed',
			'attempted',            'last_answer',         'num_correct',  'num_incorrect',
			'att_to_open_children', 'counts_parent_grade', 'flags'
			)
		{
			$userProblem->{$_} = $c->req->param($_) if defined $c->req->param($_);
		}
	}

	# The status and sub_status are the only things that users with the problem_grader permission can change.
	# This method cannot be called without the problem_grader permission.
	$userProblem->{status}     = $c->req->param('status')     if defined $c->req->param('status');
	$userProblem->{sub_status} = $c->req->param('sub_status') if defined $c->req->param('sub_status');

	# Remove the needs_grading flag if the mark_graded parameter is set.
	$userProblem->{flags} =~ s/:needs_grading$// if $c->req->param('mark_graded');

	eval { $c->db->putUserProblem($userProblem) };
	return $c->renderError("putUserProblem: $@") if $@;

	return $c->render(json => unbless($userProblem));
}

sub putProblemVersion ($c) {
	return $c->renderError('You do not have permission for the putProblemVersion API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'problem_grader');

	my $problemVersion = $c->db->getProblemVersion(
		$c->req->param('user_id'),    $c->req->param('set_id'),
		$c->req->param('version_id'), $c->req->param('problem_id')
	);
	return $c->renderError('Problem version not found.') unless $problemVersion;

	if ($c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data')) {
		for (
			'source_file',          'value',               'max_attempts', 'showMeAnother',
			'showMeAnotherCount',   'prPeriod',            'prCount',      'problem_seed',
			'attempted',            'last_answer',         'num_correct',  'num_incorrect',
			'att_to_open_children', 'counts_parent_grade', 'flags'
			)
		{
			$problemVersion->{$_} = $c->req->param($_) if defined $c->req->param($_);
		}
	}

	# The status and sub_status are the only things that users with the problem_grader permission can change.
	# This method cannot be called without the problem_grader permission.
	$problemVersion->{status}     = $c->req->param('status')     if defined $c->req->param('status');
	$problemVersion->{sub_status} = $c->req->param('sub_status') if defined $c->req->param('sub_status');

	# Remove the needs_grading flag if the mark_graded parameter is set.
	$problemVersion->{flags} =~ s/:needs_grading$// if $c->req->param('mark_graded');

	eval { $c->db->putProblemVersion($problemVersion) };
	return $c->renderError("putProblemVersion: $@") if $@;

	return $c->render(json => unbless($problemVersion));
}

sub putPastAnswer ($c) {
	return $c->renderError('You do not have permission for the putPastAnswer API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'problem_grader');

	my $pastAnswer = $c->db->getPastAnswer($c->req->param('answer_id'));
	return $c->renderError('Past answer not found.') unless $pastAnswer;

	$pastAnswer->{user_id} = $c->req->param('user_id') if $c->req->param('user_id');

	if ($c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data')) {
		for (
			'set_id', 'problem_id',    'source_file',    'timestamp',
			'scores', 'answer_string', 'comment_string', 'problem_seed'
			)
		{
			$pastAnswer->{$_} = $c->req->param('$_') if defined $c->req->param('$_');
		}
	}

	# The comment_string is the only thing that users with the problem_grader permission can change.
	# This method cannot be called without the problem_grader permission.
	$pastAnswer->{comment_string} = $c->req->param('comment_string') if defined $c->req->param('comment_string');

	eval { $c->db->putPastAnswer($pastAnswer) };
	return $c->renderError("putPastAnswer $@") if $@;

	return $c->render(json => unbless($pastAnswer));
}

sub tidyPGCode ($c) {
	return $c->renderError('You do not have permission for the tidyPGCode API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	local @ARGV = ();
	my $result =
		pgtidy(source => \($c->req->param('pgCode')), destination => \(my $tidiedPGCode), errorfile => \(my $errors));

	return $c->render(json => { tidiedPGCode => $tidiedPGCode, status => $result, errors => $errors });
}

sub convertCodeToPGML ($c) {
	return $c->renderError('You do not have permission for the convertCodeToPGML API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	return $c->render(json => convertToPGML($c->req->param('pgCode')));
}

sub runPGCritic ($c) {
	return $c->renderError('You do not have permission for the runPGCritic API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	return $c->render(
		json => {
			html => $c->render_to_string(
				template   => 'ContentGenerator/Instructor/PGProblemEditor/pg_critic',
				violations => [ critiquePGCode($c->req->param('pgCode')) ]
			)
		}
	);
}

1;
