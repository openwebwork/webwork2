################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

# Web service which fetches, adds, removes and moves WeBWorK problems when working with a Set.
package WebworkWebservice::SetActions;

use strict;
use warnings;

use Carp;
use JSON;
use Data::Structure::Util qw(unbless);

use WeBWorK::Utils qw(max);
use WeBWorK::Utils::Instructor qw(assignSetToGivenUsers assignMultipleProblemsToGivenUsers);
use WeBWorK::Utils::JITAR qw(seq_to_jitar_id jitar_id_to_seq);
use WeBWorK::Debug;
use WeBWorK::DB::Utils qw(initializeUserProblem);

sub listGlobalSets {
	my ($invocant, $self) = @_;

	debug('in listGlobalSets');

	my @found_sets = $self->db->listGlobalSets;
	return { ra_out => \@found_sets, text => 'Loaded sets for course: ' . $self->ce->{courseName} };
}

# This returns an array of problems (path,value,problem_id, which is weight)
sub listGlobalSetProblems {
	my ($invocant, $self, $params) = @_;

	debug('listGlobalSetProblems loading problems for ' . $params->{set_id});

	my $db = $self->db;

	# If a command is passed, then we want relative paths rather than absolute paths.
	# Do that by setting templateDir to the empty string.
	my $templateDir = $params->{command} ? '' : ($self->ce->{courseDirs}{templates} . '/');

	my @found_problems = $db->listGlobalProblems($params->{set_id});

	my @problems;
	for my $problem (@found_problems) {
		my $problemRecord = $db->getGlobalProblem($params->{set_id}, $problem);
		return { text => "global $problem for set $params->{set_id} not found." } unless $problemRecord;
		push @problems,
			{
				path       => $templateDir . $problemRecord->source_file,
				problem_id => $problemRecord->{problem_id},
				value      => $problemRecord->{value}
			};
	}

	return { ra_out => \@problems, text => "Loaded Problems for set: $params->{set_id}" };
}

# This returns all problem sets of a course.
sub getSets {
	my ($invocant, $self, $params) = @_;

	debug('in getSets');

	my $db = $self->db;

	my @found_sets = $db->listGlobalSets;
	my @all_sets   = map { unbless($_) } $db->getGlobalSets(@found_sets);

	# Add a list of set users to the return data.
	for my $set (@all_sets) {
		my @users = $db->listSetUsers($set->{set_id});
		$set->{assigned_users} = \@users;
	}

	return { ra_out => \@all_sets, text => 'Sets for course: ' . $self->ce->{courseName} };
}

# This returns all problem sets of a course for a given user.
# The set is stored in the set_id and the user in user_id
sub getUserSets {
	my ($invocant, $self, $params) = @_;

	debug('in getUserSets');

	my $db           = $self->db;
	my @userSetNames = $db->listUserSets($params->{user_id});
	my @userSets     = map { unbless($_) } $db->getGlobalSets(@userSetNames);

	return {
		ra_out => \@userSets,
		text   => "User sets for user $params->{user_id} in course " . $self->ce->{courseName}
	};
}

# This returns a single problem set with name stored in set_id
sub getSet {
	my ($invocant, $self, $params) = @_;

	my $db  = $self->db;
	my $set = unbless($db->getGlobalSet($params->{set_id}));

	return { ra_out => $set, text => "Loaded set $params->{set_id} in " . $self->ce->{courseName} };
}

sub updateSetProperties {
	my ($invocant, $self, $params) = @_;
	my $db = $self->db;

	my $set = $db->getGlobalSet($params->{set_id});
	$set->set_header($params->{set_header});
	$set->hardcopy_header($params->{hardcopy_header});
	$set->open_date($params->{open_date});
	$set->due_date($params->{due_date});
	$set->answer_date($params->{answer_date});
	$set->visible($params->{visible});
	$set->enable_reduced_scoring($params->{enable_reduced_scoring});
	$set->assignment_type($params->{assignment_type});
	$set->attempts_per_version($params->{attempts_per_version});
	$set->time_interval($params->{time_interval});
	$set->versions_per_interval($params->{versions_per_interval});
	$set->version_time_limit($params->{version_time_limit});
	$set->version_creation_time($params->{version_creation_time});
	$set->problem_randorder($params->{problem_randorder});
	$set->version_last_attempt_time($params->{version_last_attempt_time});
	$set->problems_per_page($params->{problems_per_page});
	$set->hide_score($params->{hide_score});
	$set->hide_score_by_problem($params->{hide_score_by_problem});
	$set->hide_work($params->{hide_work});
	$set->time_limit_cap($params->{time_limit_cap});
	$set->restrict_ip($params->{restrict_ip});
	$set->relax_restrict_ip($params->{relax_restrict_ip});
	$set->restricted_login_proctor($params->{restricted_login_proctor});

	$db->putGlobalSet($set);

	# Next update the assigned_users list

	# first, get the current list of users.

	my @usersForTheSetBefore = $db->listSetUsers($params->{set_id});

	debug(to_json(\@usersForTheSetBefore));

	# then determine those currently in the list.

	my @usersForTheSetNow = split(/,/, $params->{assigned_users});

	# The following seems to work if there are only additions or subtractions from the assigned_users field.
	# Perhaps a better way to do this is to check users that are new or missing and add or delete them.

	# if the number of users have grown, then add them.

	debug(to_json(\@usersForTheSetNow));

	# determine users to be added

	for my $user (@usersForTheSetNow) {
		if (!(grep {/^$user$/} @usersForTheSetBefore)) {
			my $userSet = $db->newUserSet;
			$userSet->user_id($user);
			$userSet->set_id($params->{set_id});
			$db->addUserSet($userSet);
		}
	}

	# delete users that are in the set before but not now.

	for my $user (@usersForTheSetBefore) {
		if (!(grep {/^$user$/} @usersForTheSetNow)) {
			$db->deleteUserSet($user, $params->{set_id});
		}
	}

	return { ra_out => unbless($set), text => "Successfully updated set $params->{set_id}" };
}

sub listSetUsers {
	my ($invocant, $self, $params) = @_;
	my $db = $self->db;

	my @users = $db->listSetUsers($params->{set_id});
	return { ra_out => \@users, text => "Successfully returned the users for set $params->{set_id}" };
}

sub createNewSet {
	my ($invocant, $self, $params) = @_;
	my $db  = $self->db;
	my $out = {};

	debug('in createNewSet');

	if ($params->{set_id} !~ /^[\w .-]*$/) {
		$out->{text}   = 'Invalid set name';
		$out->{ra_out} = { success => \0 };
	} else {
		my $newSetName = $params->{set_id};
		$newSetName =~ s/\s/_/g;

		if (defined($db->getGlobalSet($newSetName))) {
			$out->{text} = "The set name '$newSetName' is already in use. "
				. 'Pick a different name if you would like to start a new set.';
			$out->{ra_out} = { success => \0 };
		} else {
			my $now          = time;
			my $newSetRecord = $db->newGlobalSet;
			$newSetRecord->set_id($newSetName);
			$newSetRecord->set_header('defaultHeader');
			$newSetRecord->hardcopy_header('defaultHeader');
			$newSetRecord->open_date($params->{open_date}                           // $now);
			$newSetRecord->due_date($params->{due_date}                             // ($now + 1209600));
			$newSetRecord->answer_date($params->{answer_date}                       // ($now + 1209600));
			$newSetRecord->reduced_scoring_date($params->{reduced_scoring_date}     // ($now + 1209600));
			$newSetRecord->visible($params->{visible}                               // 1);
			$newSetRecord->enable_reduced_scoring($params->{enable_reduced_scoring} // 0);
			$newSetRecord->assignment_type($params->{assignment_type}               // 'default');
			$newSetRecord->description($params->{description});
			$newSetRecord->restricted_release($params->{restricted_release});
			$newSetRecord->restricted_status($params->{restricted_status}         // 1);
			$newSetRecord->attempts_per_version($params->{attempts_per_version}   // 0);
			$newSetRecord->time_interval($params->{time_interval}                 // 0);
			$newSetRecord->versions_per_interval($params->{versions_per_interval} // 0);
			$newSetRecord->version_time_limit($params->{version_time_limit}       // 0);
			$newSetRecord->version_creation_time($params->{version_creation_time});
			$newSetRecord->problem_randorder($params->{problem_randorder});
			$newSetRecord->version_last_attempt_time($params->{version_last_attempt_time});
			$newSetRecord->problems_per_page($params->{problems_per_page} // 0);
			$newSetRecord->hide_score($params->{hide_score});
			$newSetRecord->hide_score_by_problem($params->{hide_score_by_problem});
			$newSetRecord->hide_work($params->{hide_work});
			$newSetRecord->time_limit_cap($params->{time_limit_cap});
			$newSetRecord->restrict_ip($params->{restrict_ip}                             // 'No');
			$newSetRecord->relax_restrict_ip($params->{relax_restrict_ip}                 // 'No');
			$newSetRecord->hide_hint($params->{hide_hint}                                 // 0);
			$newSetRecord->restrict_prob_progression($params->{restrict_prob_progression} // 0);
			$newSetRecord->email_instructor($params->{email_instructor}                   // 0);

			$db->addGlobalSet($newSetRecord);
			$out->{text}   = "Successfully created new set $newSetName";
			$out->{ra_out} = { success => \1 };

			my $selfassign = $params->{selfassign} // '';
			debug("selfassign: $selfassign");
			$selfassign = '' if ($selfassign =~ /false/i);    # deal with javascript false
			if ($selfassign) {
				debug("Assigning to user: $params->{user}");
				my $userSet = $db->newUserSet;
				$userSet->user_id($params->{user});
				$userSet->set_id($newSetName);
				$db->addUserSet($userSet);
				$out->{text} .= " Set was assigned to $params->{user}.";
			}
		}
	}
	return $out;
}

sub assignSetToUsers {
	my ($invocant, $self, $params) = @_;
	my $db = $self->db;

	my $setID     = $params->{set_id};
	my $GlobalSet = $db->getGlobalSet($params->{set_id});

	my %setUsers = map { $_ => 1 } $db->listSetUsers($setID);

	debug("users: " . $params->{users});
	my @users = split(',', $params->{users});
	my @usersToAdd;
	my @results;
	for my $user (@users) {
		if ($setUsers{$user}) {
			push @results, "set $setID is already assigned to user $user.";

		} else {
			push @usersToAdd, $user;
		}
	}
	push @results, assignSetToGivenUsers($db, $self->ce, $setID, 1, $db->getUsers(@usersToAdd));

	return { ra_out => \@results, text => "Successfully assigned users to set $params->{set_id}" };
}

sub deleteProblemSet {
	my ($invocant, $self, $params) = @_;
	my $db     = $self->db;
	my $setID  = $params->{set_id};
	my $result = $db->deleteGlobalSet($setID);

	# check the result
	debug("in deleteProblemSet");
	debug("deleted set:  $setID");
	debug($result);

	return { text => "Deleted Problem Set $setID" };
}

sub reorderProblems {
	my ($invocant, $self, $params) = @_;

	my $db          = $self->db;
	my $setID       = $params->{set_id};
	my @problemList = split(/,/, $params->{probList});
	my $topdir      = $self->ce->{courseDirs}{templates};

	# get all the problems
	my @allProblems = $db->getAllGlobalProblems($setID);

	my @probOrder = ();

	for my $problem (@allProblems) {
		my $recordFound = 0;

		for (my $i = 0; $i < scalar(@problemList); $i++) {
			$problemList[$i] =~ s|^$topdir/*||;

			if ($problem->{source_file} eq $problemList[$i]) {
				push(@probOrder, $i + 1);
				if ($db->existsGlobalProblem($setID, $i + 1)) {
					$problem->problem_id($i + 1);
					$db->putGlobalProblem($problem);
					debug("updating problem " . $problemList[$i] . " and setting the index to " . ($i + 1));

				} else {
					# delete the problem with the old problem_id and create a new one
					$db->deleteGlobalProblem($setID, $problem->{problem_id});
					$problem->problem_id($i + 1);
					$db->addGlobalProblem($problem);

					debug("adding new problem " . $problemList[$i] . " and setting the index to " . ($i + 1));
				}
			}
			$recordFound = 1;
		}
		die "global " . $problem->{source_file} . " for set $setID not found." unless $recordFound;

	}

	return { text => 'Successfully reordered problems' };
}

sub updateProblem {
	my ($invocant, $self, $params) = @_;
	my $db     = $self->db;
	my $setID  = $params->{set_id};
	my $path   = $params->{problemPath};
	my $topdir = $self->ce->{courseDirs}{templates};
	$path =~ s|^$topdir/*||;

	my @problems = $db->getAllGlobalProblems($setID);
	for my $problem (@problems) {
		if ($problem->{source_file} eq $path) {
			debug($params->{value});
			$problem->value($params->{value});
			$db->putGlobalProblem($problem);
		}
	}

	return { text => "Updated Problem Set $setID" };
}

# This updates the userSet for a problem set (just the open, due and answer dates)
sub updateUserSet {
	my ($invocant, $self, $params) = @_;
	my $db    = $self->db;
	my @users = split(',', $params->{users});

	debug($params->{open_date});
	debug($params->{due_date});
	debug($params->{answer_date});

	for my $userID (@users) {
		my $set = $db->getUserSet($userID, $params->{set_id});
		if ($set) {
			$set->open_date($params->{open_date});
			$set->due_date($params->{due_date});
			$set->answer_date($params->{answer_date});
			$db->putUserSet($set);
		} else {
			my $newSet = $db->newUserSet;
			$newSet->user_id($userID);
			$newSet->set_id($params->{set_id});
			$newSet->open_date($params->{open_date});
			$newSet->due_date($params->{due_date});
			$newSet->answer_date($params->{answer_date});

			$newSet = $db->addUserSet($newSet);
		}
	}

	return {
		#ra_out => $set,
		text => "Successfully updated set $params->{set_id} for users $params->{users}"
	};
}

sub getSetUserSets {
	my ($invocant, $self, $params) = @_;
	my $db = $self->db;

	my @setUserIDs = $db->listSetUsers($params->{set_id});

	my @userData = ();

	for my $user_id (@setUserIDs) {
		push(@userData, unbless($db->getUserSet($user_id, $params->{set_id})));
	}

	return { ra_out => \@userData, text => "Returning all users sets for set $params->{set_id}" };
}

sub saveUserSets {
	my ($invocant, $self, $params) = @_;
	my $db = $self->db;
	debug($params->{overrides});

	my @overrides = @{ from_json($params->{overrides}) };
	for my $override (@overrides) {
		my $set = $db->getUserSet($override->{user_id}, $params->{set_id});
		if ($override->{open_date})   { $set->{open_date}   = $override->{open_date}; }
		if ($override->{due_date})    { $set->{due_date}    = $override->{due_date}; }
		if ($override->{answer_date}) { $set->{answer_date} = $override->{answer_date}; }
		$db->putUserSet($set);
	}

	return { ra_out => '', text => "Updating the overrides for set $params->{set_id}" };
}

sub addProblem {
	my ($invocant, $self, $params) = @_;
	my $db      = $self->db;
	my $setName = $params->{set_id};

	my $file   = $params->{problemPath};
	my $topdir = $self->ce->{courseDirs}{templates};
	$file =~ s|^$topdir/*||;

	my $freeProblemID;
	my $set = $db->getGlobalSet($setName);
	warn "record not found for global set $setName" unless $set;

	# for jitar sets the next problem id is the next top level problem
	if ($set->assignment_type eq 'jitar') {
		my @problemIDs = $db->listGlobalProblems($setName);
		my @seq        = (0);
		if ($#problemIDs != -1) {
			@seq = jitar_id_to_seq($problemIDs[-1]);
		}

		$freeProblemID = seq_to_jitar_id($seq[0] + 1);
	} else {
		$freeProblemID = max($db->listGlobalProblems($setName)) + 1;
	}

	my $value_default                = $self->ce->{problemDefaults}->{value};
	my $max_attempts_default         = $self->ce->{problemDefaults}->{max_attempts};
	my $showMeAnother_default        = $self->ce->{problemDefaults}->{showMeAnother};
	my $showHintsAfter_default       = $self->ce->{problemDefaults}{showHintsAfter};
	my $att_to_open_children_default = $self->ce->{problemDefaults}->{att_to_open_children};
	my $counts_parent_grade_default  = $self->ce->{problemDefaults}->{counts_parent_grade};
	# showMeAnotherCount is the number of times that showMeAnother has been clicked; initially 0
	my $showMeAnotherCount = 0;

	my $prPeriod_default = $self->ce->{problemDefaults}->{prPeriod};

	my $value = $value_default;
	if (defined($params->{value}) and length($params->{value})) {
		$value = $params->{value};
	}    # 0 is a valid value for $params{value} but we don't want emptystring

	my $maxAttempts       = $params->{maxAttempts}    || $max_attempts_default;
	my $showMeAnother     = $params->{showMeAnother}  || $showMeAnother_default;
	my $showHintsAfter    = $params->{showHintsAfter} || $showHintsAfter_default;
	my $problemID         = $params->{problemID};
	my $countsParentGrade = $params->{counts_parent_grade}  || $counts_parent_grade_default;
	my $attToOpenChildren = $params->{att_to_open_children} || $att_to_open_children_default;

	my $prPeriod = $prPeriod_default;
	if (defined($params->{prPeriod})) {
		$prPeriod = $params->{prPeriod};
	}

	unless ($problemID) {
		$problemID = $freeProblemID;
	}

	my $problemRecord = $db->newGlobalProblem;
	$problemRecord->problem_id($problemID);
	$problemRecord->set_id($setName);
	$problemRecord->source_file($file);
	$problemRecord->value($value);
	$problemRecord->max_attempts($maxAttempts);
	$problemRecord->showMeAnother($showMeAnother);
	$problemRecord->showHintsAfter($showHintsAfter);
	$problemRecord->{showMeAnotherCount}   = $showMeAnotherCount;
	$problemRecord->{att_to_open_children} = $attToOpenChildren;
	$problemRecord->{counts_parent_grade}  = $countsParentGrade;
	$problemRecord->prPeriod($prPeriod);
	$problemRecord->prCount(0);
	$db->addGlobalProblem($problemRecord);

	my @results;
	my @userIDs = $db->listSetUsers($setName);
	my $result  = assignMultipleProblemsToGivenUsers($db, \@userIDs, $setName, ($problemID));
	push @results, $result if $result;

	return { text => "Problem added to $setName" };
}

sub deleteProblem {
	my ($invocant, $self, $params) = @_;

	my $db      = $self->db;
	my $setName = $params->{set_id};

	my $file   = $params->{problemPath};
	my $topdir = $self->ce->{courseDirs}{templates};
	$file =~ s|^$topdir/*||;

	my @setGlobalProblems = $db->getGlobalProblemsWhere({ set_id => $setName });
	for my $problemRecord (@setGlobalProblems) {
		if ($problemRecord->source_file eq $file) {
			$db->deleteGlobalProblem($setName, $problemRecord->problem_id);
		}
	}
	return { text => "Problem removed from $setName" };
}

1;
