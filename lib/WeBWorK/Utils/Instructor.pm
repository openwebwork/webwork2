################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::Utils::Instructor;
use parent qw(Exporter);

=head1 NAME

WeBWorK::Utils::Instructor - Useful instructor utility tools.

=cut

use strict;
use warnings;

use File::Find;

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
	assignMultipleProblemsToGivenUsers
	addProblemToSet
	getDefList
);

=head1 METHODS

=cut

################################################################################
# Primary assignment methods
################################################################################

=head2 Primary assignment methods

=over

=item assignSetToUser($db, $userID, $GlobalSet)

Assigns the given set and all problems contained therein to the given user. If
the set (or any problems in the set) are already assigned to the user, a list of
failure messages is returned.

=cut

sub assignSetToUser {
	my ($db, $userID, $GlobalSet) = @_;
	my $setID = $GlobalSet->set_id;

	my $UserSet = $db->newUserSet;
	$UserSet->user_id($userID);
	$UserSet->set_id($setID);

	my @results;
	my $set_assigned = 0;

	eval { $db->addUserSet($UserSet) };
	if ($@) {
		if ($@ =~ m/user set exists/) {
			push @results, "set $setID is already assigned to user $userID.";
			$set_assigned = 1;
		} else {
			die $@;
		}
	}

	my @globalProblemIDs = $db->listGlobalProblems($setID);

	my $result;
	# Make the next operation as close to a transaction as possible
	eval {
		$db->start_transaction;
		$result = assignMultipleProblemsToGivenUsers($db, [$userID], $setID, @globalProblemIDs);
		$db->end_transaction;
	};
	if ($@) {
		my $msg = "assignSetToUser: error during asignMultipleProblemsToGivenUsers: $@";
		$db->abort_transaction;
		die $msg;
	}

	push @results, $result if $result and not $set_assigned;

	return @results;
}

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

	my @results      = ();
	my $set_assigned = 0;

	# add the set to the database
	eval { $db->addSetVersion($userSet) };
	if ($@) {
		if ($@ =~ m/user set exists/) {
			push(@results, "set $setID,v$setVersionNum is already assigned" . "to user $userID");
			$set_assigned = 1;
		} else {
			die $@;
		}
	}

	# populate set with problems
	my @GlobalProblems = grep { defined $_ } $db->getAllGlobalProblems($setID);

	# keep track of problems assigned from groups so that we can have multiple
	#    problems from a given group, without duplicates
	my %groupProblems = ();

	foreach my $GlobalProblem (@GlobalProblems) {
		$GlobalProblem->set_id($setID);
		my @result = assignProblemToUserSetVersion($db, $userID, $userSet, $GlobalProblem, \%groupProblems);
		push(@results, @result) if (@result && !$set_assigned);
	}

	return @results;
}

=item assignMultipleProblemsToGivenUsers($db, $userIDsRef, $set_id, @globalProblemIDs)

Assigns all the problems of the given $set_id to the given users.
The list of users are sent as an array reference
If any assignments fail, an error message is returned.

=cut

sub assignMultipleProblemsToGivenUsers {
	my ($db, $userIDsRef, $set_id, @globalProblemIDs) = @_;

	if (!@globalProblemIDs) {    # When the set is empty there is nothing to do
		return;
	}

	my @allRecords;
	for my $userID (@{$userIDsRef}) {
		my @records;
		for my $problem_id (@globalProblemIDs) {
			my $userProblem = $db->newUserProblem;
			$userProblem->user_id($userID);
			$userProblem->set_id($set_id);
			$userProblem->problem_id($problem_id);
			initializeUserProblem($userProblem, undef);    # No $seed
			push(@records, $userProblem);
		}
		push(@allRecords, [@records]);
	}

	eval { $db->addUserMultipleProblems(@allRecords) };
	if ($@) {
		if ($@ =~ m/user problems existed/) {
			return "some problem in the set $set_id were already assigned to one of the users being processed.\n $@";
		} else {
			die $@;
		}
	}

	return;
}

=item assignProblemToUser($db, $userID, $GlobalProblem, $seed)

Assigns the given problem to the given user. If the problem is already assigned
to the user, an error string is returned. If $seed is defined, the UserProblem
will be given that seed.

=cut

sub assignProblemToUser {
	my ($db, $userID, $GlobalProblem, $seed) = @_;

	my $UserProblem = $db->newUserProblem;
	$UserProblem->user_id($userID);
	$UserProblem->set_id($GlobalProblem->set_id);
	$UserProblem->problem_id($GlobalProblem->problem_id);
	initializeUserProblem($UserProblem, $seed);

	eval { $db->addUserProblem($UserProblem) };
	if ($@) {
		if ($@ =~ m/user problem exists/) {
			return
				"problem "
				. $GlobalProblem->problem_id
				. " in set "
				. $GlobalProblem->set_id
				. " is already assigned to user $userID.";
		} else {
			die $@;
		}
	}

	return ();
}

# $seed is optional -- if set, the UserProblem will be given that seed
sub assignProblemToUserSetVersion {
	my ($db, $userID, $userSet, $GlobalProblem, $groupProbRef, $seed) = @_;

	# conditional to allow selection of problems from a group of problems,
	# defined in a set.

	# problem groups are indicated by source files "group:problemGroupName"
	if ($GlobalProblem->source_file() =~ /^group:(.+)$/) {
		my $problemGroupName = $1;

		# get list of problems in group
		my @problemList = $db->listGlobalProblems($problemGroupName);
		# sanity check: if the group set hasn't been defined or doesn't
		# actually contain problems (oops), then we can't very well assign
		# this problem to the user.  we could go on and assign all other
		# problems, but that results in a partial set.  so we die here if
		# this happens.  philosophically we're requiring that the instructor
		# set up the sets correctly or have to deal with the carnage after-
		# wards.  I'm not sure that this is the best long-term solution.
		# FIXME: this means that we may have created a set version that
		# doesn't have any problems.  this is bad.  but it's hard to see
		# where else to deal with it---fixing the problem requires checking
		# at the set version-creation level that all the problems in the
		# set are well defined.  FIXME
		die("Error in set version creation: no problems are available "
				. "in problem group $problemGroupName.  Set "
				. $userSet->set_id
				. " has been created for $userID, but "
				. "does not contain the right problems.\n")
			if (!@problemList);

		my $nProb        = @problemList;
		my $whichProblem = int(rand($nProb));

		# we allow selection of multiple problems from a group, but want them to
		#   be different.  there's probably a better way to do this
		if (defined($groupProbRef->{$problemGroupName})
			&& $groupProbRef->{$problemGroupName} =~ /\b$whichProblem\b/)
		{
			my $nAvail = $nProb - ($groupProbRef->{$problemGroupName} =~ tr/,//) - 1;

			die("Too many problems selected from group.") if (!$nAvail);

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

	# all set; do problem assignment
	my $UserProblem = $db->newProblemVersion;
	$UserProblem->user_id($userID);
	$UserProblem->set_id($userSet->set_id);
	$UserProblem->version_id($userSet->version_id);
	$UserProblem->problem_id($GlobalProblem->problem_id);
	$UserProblem->source_file($GlobalProblem->source_file);
	initializeUserProblem($UserProblem, $seed);

	eval { $db->addProblemVersion($UserProblem) };
	if ($@) {
		if ($@ =~ m/user problem exists/) {
			return
				"problem "
				. $GlobalProblem->problem_id
				. " in set "
				. $GlobalProblem->set_id
				. " is already assigned to user $userID.";
		} else {
			die $@;
		}
	}

	return ();
}

=back

=cut

################################################################################
# Secondary set assignment methods
################################################################################

=head2 Secondary assignment methods

=over

=item assignSetToAllUsers($db, $ce, $setID)

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

=item assignSetToGivenUsers($db, $ce, $setID, $alwaysInclude, @userRecords)

Assigns the set specified and all problems contained therein to all users
in the list provided.
When $alwaysInclude is false, it will skip users whose status does not
have the behavior include_in_assignment.
This is more efficient than repeatedly calling assignSetToUser().
If any assignments fail, an error message is returned.

=cut

sub assignSetToGivenUsers {
	my ($db, $ce, $setID, $alwaysInclude, @userRecords) = @_;

	debug("$setID: getting problem list");
	my @globalProblemIDs = $db->listGlobalProblems($setID);
	debug("$setID: (done with that)");

	my @results;

	my @userSetsToAdd;
	my @usersToProcess;
	foreach my $User (@userRecords) {
		next unless ($alwaysInclude || $ce->status_abbrev_has_behavior($User->status, "include_in_assignment"));
		my $userID = $User->user_id;
		next if $db->existsUserSet($userID, $setID);

		my $userSet = $db->newUserSet;
		$userSet->user_id($userID);
		$userSet->set_id($setID);
		debug("Scheduled $setID: adding UserSet for $userID");
		push(@userSetsToAdd,  $userSet);
		push(@usersToProcess, $userID);
	}
	return unless @usersToProcess;    # nothing to do

	# Insert them all at once
	eval {
		$db->start_transaction;
		$db->addMultipleUserSets(@userSetsToAdd);
	};
	if ($@) {
		my $msg = "assignSetToGivenUsers: error during addMultipleUserSets: $@";
		$db->abort_transaction;
		die $msg;
	}
	# Now add the problem records - as a batch
	my $result;
	eval {
		$result = assignMultipleProblemsToGivenUsers($db, [@usersToProcess], $setID, @globalProblemIDs);
		$db->end_transaction;
	};
	if ($@) {
		my $msg = "assignSetToGivenUsers: error during assignMultipleProblemsToGivenUsers: $@";
		$db->abort_transaction;
		die $msg;
	}
	return $result;
}

=item unassignSetFromAllUsers($db, $setID)

Unassigns the specified sets and all problems contained therein from all users.

=cut

sub unassignSetFromAllUsers {
	my ($db, $setID) = @_;

	my @userIDs = $db->listSetUsers($setID);

	foreach my $userID (@userIDs) {
		$db->deleteUserSet($userID, $setID);
	}

	return;
}

=item assignAllSetsToUser($db, $userID)

Assigns all sets in the course and all problems contained therein to the
specified user. If any assignments fail, a list of failure messages is
returned.

=cut

sub assignAllSetsToUser {
	my ($db, $userID) = @_;

	my @GlobalSets = $db->getGlobalSetsWhere();

	my @results;

	for my $GlobalSet (@GlobalSets) {
		my @result = assignSetToUser($db, $userID, $GlobalSet);
		push @results, @result if @result;
	}

	return @results;
}

=item unassignAllSetsFromUser($db, $userID)

Unassigns all sets and all problems contained therein from the specified user.

=cut

sub unassignAllSetsFromUser {
	my ($db, $userID) = @_;

	my @setIDs = $db->listUserSets($userID);

	foreach my $setID (@setIDs) {
		$db->deleteUserSet($userID, $setID);
	}

	return;
}

=back

=cut

################################################################################
# Utility assignment methods
################################################################################

=head2 Utility assignment methods

=over

=item assignSetsToUsers($db, $ce, $setIDsRef, $userIDsRef)

Assign each of the given sets to each of the given users. If any assignments
fail, a list of failure messages is returned.

=cut

sub assignSetsToUsers {
	my ($db, $ce, $setIDsRef, $userIDsRef) = @_;

	my @userRecords = $db->getUsers(@$userIDsRef);
	my @results;

	foreach my $setID (@$setIDsRef) {
		my $result = assignSetToGivenUsers($db, $ce, $setID, 1, @userRecords);
		push @results, $result if $result;
	}

	return @results;
}

=item unassignSetsFromUsers($db, $setIDsRef, $userIDsRef)

Unassign each of the given sets from each of the given users.

=cut

sub unassignSetsFromUsers {
	my ($db, $setIDsRef, $userIDsRef) = @_;
	my @setIDs  = @$setIDsRef;
	my @userIDs = @$userIDsRef;

	foreach my $setID (@setIDs) {
		foreach my $userID (@userIDs) {
			$db->deleteUserSet($userID, $setID);
		}
	}

	return;
}

=item assignProblemToAllSetUsers($GlobalProblem)

Assigns the problem specified to all users to whom the problem's set is
assigned. If any assignments fail, a list of failure messages is returned.

=cut

sub assignProblemToAllSetUsers {
	my ($db, $GlobalProblem) = @_;
	my $setID   = $GlobalProblem->set_id;
	my @userIDs = $db->listSetUsers($setID);

	my @results;

	foreach my $userID (@userIDs) {
		my @result = assignProblemToUser($db, $userID, $GlobalProblem);
		push @results, @result if @result;
	}

	return @results;
}

=back

=cut

################################################################################
# Utility method for adding problems to a set
################################################################################

=head2 Utility method for adding problems to a set

=over

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

=back

=cut

################################################################################
# Methods for listing various types of files
################################################################################

=head2 Methods for listing various types of files

=over

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

		return @{ JSON->new->decode($data) };
	}

	return;
}

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

	# Load the OPL set definition files from the list file.
	push(@found_set_defs, loadSetDefListFile("$ce->{webworkDirs}{htdocs}/DATA/library-set-defs.json"))
		if -d "$ce->{courseDirs}{templates}/Library" && -r "$ce->{courseDirs}{templates}/Library";

	# Load the Contrib set definition files from the list file.
	push(@found_set_defs, loadSetDefListFile("$ce->{webworkDirs}{htdocs}/DATA/contrib-set-defs.json"))
		if -d "$ce->{courseDirs}{templates}/Contrib" && -r "$ce->{courseDirs}{templates}/Contrib";

	my @lib_order;
	my @depths;
	my @caps;
	for (@found_set_defs) {
		push(@lib_order, $_ =~ m|^Library/| ? 2 : $_ =~ m|^Contrib/| ? 3 : 1);
		push @depths, scalar(@{ [ $_ =~ /\//g ] });
		push @caps,   uc($_);
	}
	return @found_set_defs[
		sort { $lib_order[$a] <=> $lib_order[$b] || $depths[$a] <=> $depths[$b] || $caps[$a] cmp $caps[$b] }
		0 .. $#found_set_defs ];
}

=back

=cut

1;
