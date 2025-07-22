package WeBWorK::Utils::Instructor;
use Mojo::Base 'Exporter';

=head1 NAME

WeBWorK::Utils::Instructor - Useful instructor utility tools.

=cut

use File::Find;
use Mojo::JSON qw(decode_json);

use WeBWorK::DB::Utils qw(initializeUserProblem);
use WeBWorK::Debug;
use WeBWorK::Utils::JITAR qw(seq_to_jitar_id jitar_id_to_seq);

our @EXPORT_OK = qw(
	assignSetToUser
	assignSetVersionToUser
	assignProblemToUser
	assignProblemToUserSetVersion
	assignSetToAllUsers
	unassignSetFromAllUsers
	assignAllSetsToUser
	unassignAllSetsFromUser
	assignSetsToUsers
	assignSetToGivenUsers
	unassignSetsFromUsers
	assignProblemToAllSetUsers
	addProblemToSet
	getDefList
);

=head1 METHODS

=head2 assignSetToUser

    assignSetToUser($db, $userID, $GlobalSet)

Assigns the set C<$GlobalSet> and all problems contained therein to the user
identified by C<$userID>. If the assignment of the set or the assignment of any
of the problems in the set fails, then an exception is thrown.  Note that it is
not considered a failure for the set or a problem in the set to have already
been assigned to the user.

=cut

sub assignSetToUser {
	my ($db, $userID, $GlobalSet) = @_;
	my $setID = $GlobalSet->set_id;

	my $UserSet = $db->newUserSet;
	$UserSet->user_id($userID);
	$UserSet->set_id($setID);

	eval { $db->addUserSet($UserSet) };
	die $@ if $@ && !WeBWorK::DB::Ex::RecordExists->caught;

	my @globalProblemIDs = $db->listGlobalProblems($setID);

	eval {
		$db->start_transaction;
		_assignMultipleProblemsToGivenUsers($db, [$userID], $setID, @globalProblemIDs);
		$db->end_transaction;
	};
	if (my $err = $@) {
		$db->abort_transaction;
		die $err;
	}

	return;
}

=head2 assignSetVersionToUser

    assignSetVersionToUser($db, $userID, $GlobalSet)

Assigns a version of C<$GlobalSet> to C<$userID>.

=cut

sub assignSetVersionToUser {
	my ($db, $userID, $GlobalSet) = @_;
	# in:  $db = a database connection
	#      $userID = the userID of the user to which to assign the set,
	#      $GlobalSet = the global set object.
	# out: a new set version is assigned to the user.
	# note: we assume that the global set and user are well defined.  I think this
	#    is a safe assumption.  it would be nice to just call assignSetToUser,
	#    but we run into trouble doing that because of the distinction between
	#    the setID and the setVersionID

	my $setID = $GlobalSet->set_id;

	# figure out what version we're on, reset setID, get a new user set
	# FIXME: old version; new call follows
	#    my $setVersionNum = $db->getUserSetVersionNumber( $userID, $setID );
	my @allVersionIDs = $db->listSetVersions($userID, $setID);
	my $setVersionNum = (@allVersionIDs) ? $allVersionIDs[-1] : 0;
	$setVersionNum++;
	my $userSet = $db->newSetVersion;
	$userSet->user_id($userID);
	$userSet->set_id($setID);
	$userSet->version_id($setVersionNum);

	# add the set to the database
	eval { $db->addSetVersion($userSet) };
	die $@ if $@ && !WeBWorK::DB::Ex::RecordExists->caught;

	# populate set with problems
	my @GlobalProblems = grep { defined $_ } $db->getAllGlobalProblems($setID);

	# keep track of problems assigned from groups so that we can have multiple
	#    problems from a given group, without duplicates
	my %groupProblems = ();

	for my $GlobalProblem (@GlobalProblems) {
		$GlobalProblem->set_id($setID);
		assignProblemToUserSetVersion($db, $userID, $userSet, $GlobalProblem, \%groupProblems);
	}

	return;
}

# This is an internal method that should not be used outside of this module.
sub _assignMultipleProblemsToGivenUsers {
	my ($db, $userIDsRef, $set_id, @globalProblemIDs) = @_;

	return unless @globalProblemIDs;

	my @records;
	for my $userID (@{$userIDsRef}) {
		for my $problem_id (@globalProblemIDs) {
			my $userProblem = $db->newUserProblem;
			$userProblem->user_id($userID);
			$userProblem->set_id($set_id);
			$userProblem->problem_id($problem_id);
			initializeUserProblem($userProblem, undef);    # No $seed
			push(@records, $userProblem);
		}
	}

	eval { $db->{problem_user}->insert_records(\@records) };
	die $@ if $@ && !WeBWorK::DB::Ex::RecordExists->caught;

	return;
}

=head2 assignProblemToUser

    assignProblemToUser($db, $userID, $GlobalProblem, $seed)

Assigns the given problem to the given user. If $seed is defined, the
user problem will be given that seed. If the assignment fails an exception is
thrown. Note that it is not considered a failure for the problem to have already
been assigned to the user.

=cut

sub assignProblemToUser {
	my ($db, $userID, $GlobalProblem, $seed) = @_;

	my $UserProblem = $db->newUserProblem;
	$UserProblem->user_id($userID);
	$UserProblem->set_id($GlobalProblem->set_id);
	$UserProblem->problem_id($GlobalProblem->problem_id);
	initializeUserProblem($UserProblem, $seed);

	eval { $db->addUserProblem($UserProblem) };
	die $@ if $@ && !WeBWorK::DB::Ex::RecordExists->caught;

	return;
}

=head2 assignProblemToUserSetVersion

    assignProblemToUserSetVersion($db, $userID, $userSet, $GlobalProblem, $groupProbRef, $seed)

Assigns a problem version to C<$userID>. An exception is thrown in the case of a
failure. It is not a failure for the problem to have already been assigned to
the user.

=cut

# $seed is optional -- if set, the UserProblem will be given that seed
sub assignProblemToUserSetVersion {
	my ($db, $userID, $userSet, $GlobalProblem, $groupProbRef, $seed) = @_;

	# Conditional to allow selection of problems from a group of problems defined in a set.
	# Problem groups are indicated by source files "group:problemGroupName".
	if ($GlobalProblem->source_file =~ /^group:(.+)$/) {
		my $problemGroupName = $1;

		# Get the list of problems in the group.
		my @problemList = $db->listGlobalProblems($problemGroupName);

		# If the group set is not defined or doesn't actually contain problems, then this problem can not be assigned to
		# the user.  Continuing to assign the other problems would result in a partial set.  So die here if this
		# happens.  This exception and any others in the set version creation process are handled in the GatewayQuiz.pm
		# module, and this set is immediately deleted and a message displayed instructing the user to speak to their
		# instructor.  It is the instructor's responsibility to fix the issue from there.
		die "No problems are available in problem group $problemGroupName.\n" if !@problemList;

		my $nProb        = @problemList;
		my $whichProblem = int(rand($nProb));

		# Allow selection of multiple problems from a group, but ensure they are different.
		# There's probably a better way to do this.
		if (defined($groupProbRef->{$problemGroupName})
			&& $groupProbRef->{$problemGroupName} =~ /\b$whichProblem\b/)
		{
			die "Too many problems selected from group $problemGroupName.\n"
				if !($nProb - ($groupProbRef->{$problemGroupName} =~ tr/,//) - 1);

			$whichProblem = int(rand($nProb));
			while ($groupProbRef->{$problemGroupName} =~ /\b$whichProblem\b/) {
				$whichProblem = ($whichProblem + 1) % $nProb;
			}
		}
		if (defined($groupProbRef->{$problemGroupName})) {
			$groupProbRef->{$problemGroupName} .= ",$whichProblem";
		} else {
			$groupProbRef->{$problemGroupName} = "$whichProblem";
		}

		my $prob = $db->getGlobalProblem($problemGroupName, $problemList[$whichProblem]);
		$GlobalProblem->source_file($prob->source_file());
	}

	# Assign the problem.
	my $UserProblem = $db->newProblemVersion;
	$UserProblem->user_id($userID);
	$UserProblem->set_id($userSet->set_id);
	$UserProblem->version_id($userSet->version_id);
	$UserProblem->problem_id($GlobalProblem->problem_id);
	$UserProblem->source_file($GlobalProblem->source_file);
	initializeUserProblem($UserProblem, $seed);

	eval { $db->addProblemVersion($UserProblem) };
	die $@ if $@ && !WeBWorK::DB::Ex::RecordExists->caught;

	return;
}

=head2 assignSetToAllUsers

    assignSetToAllUsers($db, $ce, $setID)

Assigns the set specified and all problems contained therein to all users
in the course. This skips users whose status does not have the behavior
include_in_assignment.
This is more efficient than repeatedly calling assignSetToUser().
If any assignments fail, a list of failure messages is returned.

=cut

sub assignSetToAllUsers {
	my ($db, $ce, $setID) = @_;

	debug("$setID: getting user list");
	my @userRecords = $db->getUsersWhere({ user_id => { not_like => 'set_id:%' } });
	debug("$setID: (done with that)");

	return assignSetToGivenUsers($db, $ce, $setID, 0, @userRecords);
}

=head2 assignSetToGivenUsers

    assignSetToGivenUsers($db, $ce, $setID, $alwaysInclude, @userRecords)

Assigns the set specified and all problems contained therein to all users in the
list provided.  When C<$alwaysInclude> is false, it will skip users whose status
does not have the behavior include_in_assignment.  This is more efficient than
repeatedly calling C<assignSetToUser>.  If any assignments fail, an exception is
thrown.

=cut

sub assignSetToGivenUsers {
	my ($db, $ce, $setID, $alwaysInclude, @userRecords) = @_;

	my @userSetsToAdd;
	for my $User (@userRecords) {
		next unless $alwaysInclude || $ce->status_abbrev_has_behavior($User->status, 'include_in_assignment');
		my $userID = $User->user_id;
		next if $db->existsUserSet($userID, $setID);

		my $userSet = $db->newUserSet;
		$userSet->user_id($userID);
		$userSet->set_id($setID);

		push(@userSetsToAdd, $userSet);
		debug("Scheduled $setID: adding UserSet for $userID");
	}
	return unless @userSetsToAdd;

	debug("$setID: getting problem list");
	my @globalProblemIDs = $db->listGlobalProblems($setID);
	debug("$setID: (done with that)");

	eval {
		$db->start_transaction;
		$db->{set_user}->insert_records(\@userSetsToAdd);
		_assignMultipleProblemsToGivenUsers($db, [ map { $_->user_id } @userSetsToAdd ], $setID, @globalProblemIDs);
		$db->end_transaction;
	};
	if (my $err = $@) {
		$db->abort_transaction;
		die $err;
	}
	return;
}

=head2 unassignSetFromAllUsers

    unassignSetFromAllUsers($db, $setID)

Unassigns the specified sets and all problems contained therein from all users.

=cut

sub unassignSetFromAllUsers {
	my ($db, $setID) = @_;

	for my $userID ($db->listSetUsers($setID)) {
		$db->deleteUserSet($userID, $setID);
	}

	return;
}

=head2 assignAllSetsToUser

    assignAllSetsToUser($db, $userID)

Assigns all sets in the course and all problems contained therein to the
specified user. If any assignments fail, an exception is thrown. Note that it is
not considered a failure for the set or a problem in the set to have already
been assigned to the user.

=cut

sub assignAllSetsToUser {
	my ($db, $userID) = @_;

	for my $GlobalSet ($db->getGlobalSetsWhere) {
		assignSetToUser($db, $userID, $GlobalSet);
	}

	return;
}

=head2 unassignAllSetsFromUser

    unassignAllSetsFromUser($db, $userID)

Unassigns all sets and all problems contained therein from the specified user.

=cut

sub unassignAllSetsFromUser {
	my ($db, $userID) = @_;

	my @setIDs = $db->listUserSets($userID);

	for my $setID (@setIDs) {
		$db->deleteUserSet($userID, $setID);
	}

	return;
}

=head2 assignSetsToUsers

    assignSetsToUsers($db, $ce, $setIDsRef, $userIDsRef)

Assign each of the given sets to each of the given users. If any assignments
fail, an exception is thrown. Note that it is not considered a failure for a set
(or any problems therein) to have already been assigned to a user.

=cut

sub assignSetsToUsers {
	my ($db, $ce, $setIDsRef, $userIDsRef) = @_;

	my @userRecords = $db->getUsers(@$userIDsRef);

	for my $setID (@$setIDsRef) {
		assignSetToGivenUsers($db, $ce, $setID, 1, @userRecords);
	}

	return;
}

=head2 unassignSetsFromUsers

    unassignSetsFromUsers($db, $setIDsRef, $userIDsRef)

Unassign each of the given sets from each of the given users. Note that this
method returns a C<Mojo::Promise> and so must be awaited.

=cut

sub unassignSetsFromUsers {
	my ($db, $setIDsRef, $userIDsRef) = @_;

	for my $userID (@$userIDsRef) {
		for my $setID (@$setIDsRef) {
			$db->deleteUserSet($userID, $setID);
		}
	}

	return;
}

=head2 assignProblemToAllSetUsers

    assignProblemToAllSetUsers($GlobalProblem)

Assigns the problem specified to all users to whom the problem's set is
assigned. If any assignments fail, a list of failure messages is returned.

=cut

sub assignProblemToAllSetUsers {
	my ($db, $GlobalProblem) = @_;

	for my $userID ($db->listSetUsers($GlobalProblem->set_id)) {
		assignProblemToUser($db, $userID, $GlobalProblem);
	}

	return;
}

=head2 addProblemToSet

    addProblemToSet($db, $problemDefaults, %args)

Adds a problem to a set.  The paramters C<setName> and C<sourceFile>C<%args>
must be specified in C<%args>.

=cut

sub addProblemToSet {
	my ($db, $problemDefaults, %args) = @_;
	my $value_default                = $problemDefaults->{value};
	my $max_attempts_default         = $problemDefaults->{max_attempts};
	my $showMeAnother_default        = $problemDefaults->{showMeAnother};
	my $att_to_open_children_default = $problemDefaults->{att_to_open_children};
	my $counts_parent_grade_default  = $problemDefaults->{counts_parent_grade};
	my $showHintsAfter_default       = $problemDefaults->{showHintsAfter};
	my $prPeriod_default             = $problemDefaults->{prPeriod};
	# showMeAnotherCount is the number of times that showMeAnother has been clicked; initially 0
	my $showMeAnotherCount = 0;

	die "addProblemToSet called without specifying the set name." if $args{setName} eq "";
	my $setName = $args{setName};

	my $sourceFile = $args{sourceFile}
		or die "addProblemToSet called without specifying the sourceFile.";

	my $problemID = $args{problemID};

	# The rest of the arguments are optional
	my $value             = $args{value} // $value_default;
	my $maxAttempts       = $args{maxAttempts} || $max_attempts_default;
	my $showMeAnother     = $args{showMeAnother}     // $showMeAnother_default;
	my $showHintsAfter    = $args{showHintsAfter}    // $showHintsAfter_default;
	my $prPeriod          = $args{prPeriod}          // $prPeriod_default;
	my $countsParentGrade = $args{countsParentGrade} // $counts_parent_grade_default;
	my $attToOpenChildren = $args{attToOpenChildren} // $att_to_open_children_default;

	unless ($problemID) {

		my $set = $db->getGlobalSet($setName);
		# for jitar sets the new problem id is the one that
		# makes it a new top level problem
		if ($set && $set->assignment_type eq 'jitar') {
			my @problemIDs = $db->listGlobalProblems($setName);
			if (@problemIDs) {
				my @seq = jitar_id_to_seq($problemIDs[-1]);
				$problemID = seq_to_jitar_id($seq[0] + 1);
			} else {
				$problemID = seq_to_jitar_id(1);
			}
		} else {
			$problemID = WeBWorK::Utils::max($db->listGlobalProblems($setName)) + 1;
		}
	}

	my $problemRecord = $db->newGlobalProblem;
	$problemRecord->problem_id($problemID);
	$problemRecord->set_id($setName);
	$problemRecord->source_file($sourceFile);
	$problemRecord->value($value);
	$problemRecord->max_attempts($maxAttempts);
	$problemRecord->att_to_open_children($attToOpenChildren);
	$problemRecord->counts_parent_grade($countsParentGrade);
	$problemRecord->showMeAnother($showMeAnother);
	$problemRecord->{showMeAnotherCount} = $showMeAnotherCount;
	$problemRecord->showHintsAfter($showHintsAfter);
	$problemRecord->prPeriod($prPeriod);
	$problemRecord->prCount(0);
	$db->addGlobalProblem($problemRecord);

	return $problemRecord;
}

=head2 loadSetDefListFile

    loadSetDefListFile($file)

Returns the contents of the set definition list file specified in C<$file>.

=cut

sub loadSetDefListFile {
	my $file = shift;

	if (-r $file) {
		my $data = do {
			open(my $fh, "<:encoding(UTF-8)", $file)
				or die "FATAL: Unable to open '$file'!";
			local $/;
			my $contents = <$fh>;
			close $fh;
			$contents;
		};

		return @{ decode_json($data) };
	}

	return;
}

=head2 getDefList

    getDefList($ce)

Returns a list of all set definition files found in a course's templates
directory.

=cut

sub getDefList {
	my $ce     = shift;
	my $topdir = $ce->{courseDirs}{templates};

	# Search to a depth of the setDefSearchDepth value plus the depth of the templates directory.
	my $max_depth = $ce->{options}{setDefSearchDepth} + @{ [ $topdir =~ /\//g ] };

	my @found_set_defs;

	find(
		{
			wanted => sub {
				if ($File::Find::dir =~ /^$topdir\/Library/
					|| $File::Find::dir =~ /^$topdir\/Contrib/
					|| $File::Find::dir =~ /^$topdir\/capaLibrary/)
				{
					$File::Find::prune = 1;
					return;
				}
				if (@{ [ $File::Find::dir =~ /\//g ] } > $max_depth) { $File::Find::prune = 1; return; }
				push @found_set_defs, $_ =~ s|^$topdir/?||r if m|/set[^/]*\.def$|;
			},
			follow_fast => 1,
			no_chdir    => 1,
			follow_skip => 2
		},
		$topdir
	);

	my @depths;
	my @caps;
	for (@found_set_defs) {
		push @depths, scalar(@{ [ $_ =~ /\//g ] });
		push @caps,   uc($_);
	}
	return @found_set_defs[ sort { $depths[$a] <=> $depths[$b] || $caps[$a] cmp $caps[$b] } 0 .. $#found_set_defs ];
}

1;
