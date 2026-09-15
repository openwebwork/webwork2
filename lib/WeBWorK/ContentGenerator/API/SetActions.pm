package WeBWorK::ContentGenerator::API::SetActions;
use Mojo::Base 'WeBWorK::ContentGenerator::API', -signatures;

use Mojo::JSON            qw(from_json);
use Data::Structure::Util qw(unbless);

use WeBWorK::Utils             qw(max);
use WeBWorK::Utils::Instructor qw(assignProblemToAllSetUsers assignSetToGivenUsers);
use WeBWorK::Utils::JITAR      qw(seq_to_jitar_id jitar_id_to_seq);

our @apiCalls = qw(
	listGlobalSets
	listGlobalSetProblems
	getSets
	getUserSets
	getSet
	updateSetProperties
	listSetUsers
	createNewSet
	assignSetToUsers
	deleteProblemSet
	reorderProblems
	updateProblem
	updateUserSet
	getSetUserSets
	saveUserSets
	unassignSetFromUsers
	addProblem
	deleteProblem
);

sub apiCall ($invocant, $command) {
	return (grep { $_ eq $command } @apiCalls) && $invocant->can($command);
}

sub listGlobalSets ($c) {
	return $c->renderError('You do not have permission for the listGlobalSets API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	return $c->render(json => [ $c->db->listGlobalSets ]);
}

sub listGlobalSetProblems ($c) {
	return $c->renderError('You do not have permission for the listGlobalSetProblems API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	return $c->render(
		json => [ map { unbless($_) } $c->db->getGlobalProblemsWhere({ set_id => $c->req->param('set_id') }) ]);
}

# FIXME: Use the remainder of these API calls very carefully. Many of these are not well thought out.  Parameters are
# rarely verified, and some of them can do some very damaging things if not used correctly. None of them are used by
# webwork2 at this point.  If any of them ever are, make sure their implementations are fixed.

# This returns all problem sets of a course.
sub getSets ($c) {
	return $c->renderError('You do not have permission for the getSets API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	my $db = $c->db;

	my @sets = map { unbless($_) } $db->getGlobalSetsWhere;

	for my $set (@sets) {
		$set->{assigned_users} = [ $db->listSetUsers($set->{set_id}) ];
	}

	return $c->render(json => \@sets);
}

# This returns all problem sets of a course for a given user.
# The set is stored in the set_id and the user in user_id
sub getUserSets ($c) {
	return $c->renderError('You do not have permission for the getUserSets API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	return $c->render(
		json => [ map { unbless($_) } $c->db->getGlobalSets($c->db->listUserSets($c->req->param('user_id'))) ]);
}

# This returns a single problem set with name stored in set_id
sub getSet ($c) {
	return $c->renderError('You do not have permission for the getSet API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	return $c->render(json => unbless($c->db->getGlobalSet($c->req->param('set_id'))));
}

sub updateSetProperties ($c) {
	return $c->renderError('You do not have permission for the updateSetProperties API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_problem_sets');

	my $db = $c->db;

	my $set = $db->getGlobalSet($c->req->param('set_id'));
	$set->set_header($c->req->param('set_header'));
	$set->hardcopy_header($c->req->param('hardcopy_header'));
	$set->open_date($c->req->param('open_date'));
	$set->due_date($c->req->param('due_date'));
	$set->answer_date($c->req->param('answer_date'));
	$set->visible($c->req->param('visible'));
	$set->enable_reduced_scoring($c->req->param('enable_reduced_scoring'));
	$set->assignment_type($c->req->param('assignment_type'));
	$set->attempts_per_version($c->req->param('attempts_per_version'));
	$set->time_interval($c->req->param('time_interval'));
	$set->versions_per_interval($c->req->param('versions_per_interval'));
	$set->version_time_limit($c->req->param('version_time_limit'));
	$set->version_creation_time($c->req->param('version_creation_time'));
	$set->problem_randorder($c->req->param('problem_randorder'));
	$set->version_last_attempt_time($c->req->param('version_last_attempt_time'));
	$set->problems_per_page($c->req->param('problems_per_page'));
	$set->hide_score($c->req->param('hide_score'));
	$set->hide_score_by_problem($c->req->param('hide_score_by_problem'));
	$set->hide_work($c->req->param('hide_work'));
	$set->time_limit_cap($c->req->param('time_limit_cap'));
	$set->restrict_ip($c->req->param('restrict_ip'));
	$set->relax_restrict_ip($c->req->param('relax_restrict_ip'));
	$set->restricted_login_proctor($c->req->param('restricted_login_proctor'));

	$db->putGlobalSet($set);

	# Update the assigned_users list.  The following seems to work if there are only additions or subtractions from the
	# assigned_users field.  Perhaps a better way to do this is to check users that are new or missing and add or delete
	# them.

	my @usersForTheSetBefore = $db->listSetUsers($c->req->param('set_id'));

	my @usersForTheSetNow = split(/,/, $c->req->param('assigned_users'));

	for my $user (@usersForTheSetNow) {
		if (!(grep {/^$user$/} @usersForTheSetBefore)) {
			my $userSet = $db->newUserSet;
			$userSet->user_id($user);
			$userSet->set_id($c->req->param('set_id'));
			$userSet->version_id(0);
			$db->addUserSet($userSet);
		}
	}

	for my $user (@usersForTheSetBefore) {
		if (!(grep {/^$user$/} @usersForTheSetNow)) {
			$db->deleteUserSet($user, $c->req->param('set_id'));
		}
	}

	return $c->render(
		json => { updated_set => unbless($set), message => 'Successfully updated set ' . $c->req->param('set_id') }
	);
}

sub listSetUsers ($c) {
	return $c->renderError('You do not have permission for the listSetUsers API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	return $c->render(json => [ $c->db->listSetUsers($c->req->param('set_id')) ]);
}

sub createNewSet ($c) {
	return $c->renderError('You do not have permission for the createNewSet API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_problem_sets');

	my $newSetName = $c->req->param('set_id');

	return $c->renderError('Invalid set name') if $newSetName !~ /^[\w .-]*$/;

	$newSetName =~ s/\s/_/g;

	my $db = $c->db;

	return $c->renderError("The set name '$newSetName' already exists. "
			. 'Pick a different name if you would like to create a new set.')
		if defined($db->getGlobalSet($newSetName));

	my $now          = time;
	my $newSetRecord = $db->newGlobalSet;
	$newSetRecord->set_id($newSetName);
	$newSetRecord->set_header('defaultHeader');
	$newSetRecord->hardcopy_header('defaultHeader');
	$newSetRecord->open_date($c->req->param('open_date')                           // $now);
	$newSetRecord->due_date($c->req->param('due_date')                             // ($now + 1209600));
	$newSetRecord->answer_date($c->req->param('answer_date')                       // ($now + 1209600));
	$newSetRecord->reduced_scoring_date($c->req->param('reduced_scoring_date')     // ($now + 1209600));
	$newSetRecord->visible($c->req->param('visible')                               // 1);
	$newSetRecord->enable_reduced_scoring($c->req->param('enable_reduced_scoring') // 0);
	$newSetRecord->assignment_type($c->req->param('assignment_type')               // 'default');
	$newSetRecord->description($c->req->param('description'));
	$newSetRecord->restricted_release($c->req->param('restricted_release'));
	$newSetRecord->restricted_status($c->req->param('restricted_status')         // 1);
	$newSetRecord->attempts_per_version($c->req->param('attempts_per_version')   // 0);
	$newSetRecord->time_interval($c->req->param('time_interval')                 // 0);
	$newSetRecord->versions_per_interval($c->req->param('versions_per_interval') // 0);
	$newSetRecord->version_time_limit($c->req->param('version_time_limit')       // 0);
	$newSetRecord->version_creation_time($c->req->param('version_creation_time'));
	$newSetRecord->problem_randorder($c->req->param('problem_randorder'));
	$newSetRecord->version_last_attempt_time($c->req->param('version_last_attempt_time'));
	$newSetRecord->problems_per_page($c->req->param('problems_per_page') // 0);
	$newSetRecord->hide_score($c->req->param('hide_score'));
	$newSetRecord->hide_score_by_problem($c->req->param('hide_score_by_problem'));
	$newSetRecord->hide_work($c->req->param('hide_work'));
	$newSetRecord->time_limit_cap($c->req->param('time_limit_cap'));
	$newSetRecord->restrict_ip($c->req->param('restrict_ip')                             // 'No');
	$newSetRecord->relax_restrict_ip($c->req->param('relax_restrict_ip')                 // 'No');
	$newSetRecord->hide_hint($c->req->param('hide_hint')                                 // 0);
	$newSetRecord->restrict_prob_progression($c->req->param('restrict_prob_progression') // 0);
	$newSetRecord->email_instructor($c->req->param('email_instructor')                   // 0);

	$db->addGlobalSet($newSetRecord);
	my $message = "Successfully created new set $newSetName.";

	my $selfassign = $c->req->param('selfassign') // '';
	if ($selfassign && $selfassign !~ /false/i) {
		my $userSet = $db->newUserSet;
		$userSet->user_id($c->req->param('user'));
		$userSet->set_id($newSetName);
		$userSet->version_id(0);
		$db->addUserSet($userSet);
		$message .= ' Set was assigned to ' . $c->req->param('user') . '.';
	}
	return $c->render(json => { message => $message });
}

sub assignSetToUsers ($c) {
	return $c->renderError('You do not have permission for the assignSetToUsers API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'assign_problem_sets');

	my $db = $c->db;

	my $setID = $c->req->param('set_id');

	return $c->renderError("The set $setID does not exist.") unless $db->existsGlobalSet($setID);

	my %setUsers = map { $_ => 1 } $db->listSetUsers($setID);

	my @usersToAdd;
	for my $user (split(',', $c->req->param('users'))) {
		next if $setUsers{$user};
		push @usersToAdd, $user;
	}
	assignSetToGivenUsers($db, $c->ce, $setID, 1, $db->getUsers(@usersToAdd));

	return $c->render(json => { message => "Successfully assigned users to set $setID" });
}

sub deleteProblemSet ($c) {
	return $c->renderError('You do not have permission for the deleteProblemSet API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_problem_sets');
	return $c->render(json => { message => 'Deleted problem set ' . $c->req->param('set_id') . '.' })
		if $c->db->deleteGlobalSet($c->req->param('set_id')) != 0E0;
	return $c->renderError('Unable to delete problem set ' . $c->req->param('set_id') . '. Does the set exist?');
}

sub reorderProblems ($c) {
	return $c->renderError('You do not have permission for the reorderProblems API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_problem_sets');

	my $db           = $c->db;
	my $setID        = $c->req->param('set_id');
	my @problemList  = split(/,/, $c->req->param('probList'));
	my $templatesDir = $c->ce->{courseDirs}{templates};

	for my $problem ($db->getAllGlobalProblems($setID)) {
		my $recordFound = 0;
		for (my $i = 0; $i < @problemList; ++$i) {
			$problemList[$i] =~ s|^$templatesDir/*||;
			if ($problem->{source_file} eq $problemList[$i]) {
				if ($db->existsGlobalProblem($setID, $i + 1)) {
					$problem->problem_id($i + 1);
					$db->putGlobalProblem($problem);
				} else {
					$db->deleteGlobalProblem($setID, $problem->{problem_id});
					$problem->problem_id($i + 1);
					$db->addGlobalProblem($problem);
				}
			}
			$recordFound = 1;
		}
		return $c->renderError("Problem $problem->{source_file} for set $setID not found.")
			unless $recordFound;
	}

	return $c->render(json => { message => 'Successfully reordered problems' });
}

sub updateProblem ($c) {
	return $c->renderError('You do not have permission for the updateProblem API command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_problem_sets');

	my $setID = $c->req->param('set_id');
	my $path  = $c->req->param('problemPath');

	my @problem = $c->db->getGlobalProblemsWhere({ set_id => $setID, source_file => $path });
	return $c->renderError("Unable to find the problem in the set $setID with path $path.")
		unless @problem && @problem == 1;

	$problem[0]->value($c->req->param('value') // 1);
	$c->db->putGlobalProblem($problem[0]);

	return $c->render(json => { message => "Updated problem in set $setID with source file $path." });
}

# This updates the userSet for a problem set (only the open, due and answer dates are updated).
# Note that this does not validate the dates.
sub updateUserSet ($c) {
	return $c->renderError('You do not have permission for the updateUserSet api command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data');

	for my $userID (split(',', $c->req->param('users'))) {
		my $set = $c->db->getUserSet($userID, $c->req->param('set_id'));
		if ($set) {
			$set->open_date($c->req->param('open_date'));
			$set->due_date($c->req->param('due_date'));
			$set->answer_date($c->req->param('answer_date'));
			$c->db->putUserSet($set);
		} else {
			my $newSet = $c->db->newUserSet;
			$newSet->user_id($userID);
			$newSet->set_id($c->req->param('set_id'));
			$newSet->version_id(0);
			$newSet->open_date($c->req->param('open_date'));
			$newSet->due_date($c->req->param('due_date'));
			$newSet->answer_date($c->req->param('answer_date'));
			$newSet = $c->db->addUserSet($newSet);
		}
	}

	return $c->render(
		json => {
			message => 'Successfully updated set '
				. $c->req->param('set_id')
				. ' for users '
				. $c->req->param('users') . '.'
		}
	);
}

sub getSetUserSets ($c) {
	return $c->renderError('You do not have permission for the getSetUserSets api command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	my $db = $c->db;

	my @userData;

	for my $userID ($db->listSetUsers($c->req->param('set_id'))) {
		push(@userData, unbless($db->getUserSet($userID, $c->req->param('set_id'))));
	}

	return $c->render(json => \@userData);
}

sub saveUserSets ($c) {
	return $c->renderError('You do not have permission for the saveUserSets api command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data');

	for my $override (@{ from_json($c->req->param('overrides')) }) {
		my $set = $c->db->getUserSet($override->{user_id}, $c->req->param('set_id'));
		if ($override->{open_date})   { $set->{open_date}   = $override->{open_date}; }
		if ($override->{due_date})    { $set->{due_date}    = $override->{due_date}; }
		if ($override->{answer_date}) { $set->{answer_date} = $override->{answer_date}; }
		$c->db->putUserSet($set);
	}

	return $c->render(json => { message => 'Updated the overrides for set ' . $c->req->param('set_id') . '.' });
}

sub addProblem ($c) {
	return $c->renderError('You do not have permission for the saveUserSets api command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data');

	my $db    = $c->db;
	my $setID = $c->req->param('set_id');
	my $file  = $c->req->param('problemPath');

	my $problemID = $c->req->param('problemID');
	my $set       = $db->getGlobalSet($setID);
	return $c->renderError("Set $setID not found.") unless $set;

	if (!defined $problemID || $problemID eq '') {
		if ($set->assignment_type eq 'jitar') {
			# For jitar sets the next problem id is the next top level problem.
			my @problemIDs = $db->listGlobalProblems($setID);
			my @seq        = (0);
			@seq       = jitar_id_to_seq($problemIDs[-1]) if $#problemIDs != -1;
			$problemID = seq_to_jitar_id($seq[0] + 1);
		} else {
			$problemID = max($db->listGlobalProblems($setID)) + 1;
		}
	}

	my $problemRecord = $db->newGlobalProblem(
		problem_id  => $problemID,
		set_id      => $setID,
		source_file => $file,
		value       => defined $c->req->param('value')
			&& $c->req->param('value') ne '' ? $c->req->param('value') : $c->ce->{problemDefaults}{value},
		max_attempts         => $c->req->param('maxAttempts')    // $c->ce->{problemDefaults}{max_attempts},
		showMeAnother        => $c->req->param('showMeAnother')  // $c->ce->{problemDefaults}{showMeAnother},
		showHintsAfter       => $c->req->param('showHintsAfter') // $c->ce->{problemDefaults}{showHintsAfter},
		showMeAnotherCount   => 0,
		att_to_open_children => $c->req->param('att_to_open_children')
			|| $c->ce->{problemDefaults}{att_to_open_children},
		counts_parent_grade => $c->req->param('counts_parent_grade')
			|| $c->ce->{problemDefaults}{counts_parent_grade},
		prPeriod => $c->req->param('prPeriod') // $c->ce->{problemDefaults}->{prPeriod},
		prCount  => 0
	);
	$db->addGlobalProblem($problemRecord);

	assignProblemToAllSetUsers($db, $problemRecord);

	return $c->render(json => { message => "Problem added to $setID" });
}

sub deleteProblem ($c) {
	return $c->renderError('You do not have permission for the saveUserSets api command.')
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_student_data');

	my $setID = $c->req->param('set_id');
	my $path  = $c->req->param('problemPath');

	my @problem = $c->db->getGlobalProblemsWhere({ set_id => $setID, source_file => $path });
	return $c->renderError("Unable to find the problem in the set $setID with path $path.")
		unless @problem && @problem == 1;
	$c->db->deleteGlobalProblem($setID, $problem[0]);

	return $c->render(json => { message => "Problem removed from $setID" });
}

1;
