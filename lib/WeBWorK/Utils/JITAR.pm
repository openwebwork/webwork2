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

package WeBWorK::Utils::JITAR;
use Mojo::Base 'Exporter', -signatures;

use WeBWorK::Utils::DateTime qw(after);

our @EXPORT_OK = qw(
	seq_to_jitar_id
	jitar_id_to_seq
	is_jitar_problem_hidden
	is_jitar_problem_closed
	jitar_problem_finished
	jitar_problem_adjusted_status
	prob_id_sort
);

use constant JITAR_MASK =>
	[ hex 'FF000000', hex '00FC0000', hex '0003F000', hex '00000F00', hex '000000F0', hex '0000000F' ];
use constant JITAR_SHIFT => [ 24, 18, 12, 8, 4, 0 ];

sub seq_to_jitar_id (@seq) {
	die 'Jitar index 1 must be between 1 and 125' unless defined $seq[0] && $seq[0] < 126;

	my $id = $seq[0];
	my $ind;

	my @JITAR_SHIFT = @{ JITAR_SHIFT() };

	# Shift the first index to the first two bytes.
	$id = $id << $JITAR_SHIFT[0];

	# Look for the second and third indices.
	for (1 .. 2) {
		if (defined $seq[$_]) {
			$ind = $seq[$_];
			die 'Jitar index ' . ($_ + 1) . ' must be less than 63' unless $ind < 63;

			# Shift the index and or it with the id to put it in right place.
			$ind = $ind << $JITAR_SHIFT[$_];
			$id  = $id | $ind;
		}
	}

	# Look for the remaining 3 indices.
	for (3 .. 5) {
		if (defined($seq[$_])) {
			$ind = $seq[$_];
			die 'Jitar index ' . ($_ + 1) . ' must be less than 16' unless $ind < 16;

			# Shift the index and or it with id to put it in right place.
			$ind = $ind << $JITAR_SHIFT[$_];
			$id  = $id | $ind;
		}
	}

	return $id;
}

sub jitar_id_to_seq ($id) {
	my $ind;
	my @seq;

	my @JITAR_SHIFT = @{ JITAR_SHIFT() };
	my @JITAR_MASK  = @{ JITAR_MASK() };

	for (0 .. 5) {
		$ind = $id;
		# Use a mask to isolate only the bits we want for this index, and shift them to get the index.
		$ind = $ind & $JITAR_MASK[$_];
		$ind = $ind >> $JITAR_SHIFT[$_];

		# Quit if nonzero index is not found.
		last unless $ind;

		$seq[$_] = $ind;
	}

	return @seq;
}

sub is_jitar_problem_hidden ($db, $userID, $setID, $problemID) {
	my $mergedSet = $db->getMergedSet($userID, $setID);

	unless ($mergedSet) {
		warn "Couldn't get set $setID for user $userID from the database";
		return 0;
	}

	# This only makes sense for jitar sets.
	return 0 unless ($mergedSet->assignment_type eq 'jitar');

	# The set opens everything up after the due date.
	return 0 if (after($mergedSet->due_date));

	my @idSeq       = jitar_id_to_seq($problemID);
	my @parentIDSeq = @idSeq;

	unless ($#parentIDSeq != 0) {
		# This means we are at a top level problem and this check doesnt make sense.
		return 0;
	}

	pop @parentIDSeq;
	while (@parentIDSeq) {

		my $parentProbID = seq_to_jitar_id(@parentIDSeq);

		my $userParentProb = $db->getMergedProblem($userID, $setID, $parentProbID);

		unless ($userParentProb) {
			warn "Couldn't get problem $parentProbID for user $userID and set $setID from the database";
			return 0;
		}

		# the child problems are closed unless the number of incorrect attempts is above the
		# attempts to open children, or if they have exausted their max_attempts
		# if att_to_open_children is -1 we just use max attempts
		# if max_attempts is -1 then they are always less than max attempts
		if (
			(
				$userParentProb->att_to_open_children == -1
				|| $userParentProb->num_incorrect() < $userParentProb->att_to_open_children()
			)
			&& ($userParentProb->max_attempts == -1
				|| $userParentProb->num_incorrect() < $userParentProb->max_attempts())
			)
		{
			return 1;
		}
		pop @parentIDSeq;
	}

	# if we get here then all of the parents are open so the problem is open.
	return 0;
}

sub is_jitar_problem_closed ($db, $ce, $userID, $setID, $problemID) {
	my $mergedSet = $db->getMergedSet($userID, $setID);

	unless ($mergedSet) {
		warn "Couldn't get set $setID for user $userID from the database";
		return 0;
	}

	# Return 0 unless this is a restricted jitar set.
	return 0 unless ($mergedSet->assignment_type eq 'jitar' && $mergedSet->restrict_prob_progression());

	# The set opens everything up after the due date.
	return 0 if (after($mergedSet->due_date));

	my $prob;
	my $id;
	my @idSeq     = jitar_id_to_seq($problemID);
	my @parentSeq = @idSeq;

	# Problems are automatically closed if their parents are closed.
	# This means we cant find a previous problem to test against so the problem is open as long as the parent is open.
	pop(@parentSeq);

	# If we can't get a parent problem then this is a top level problem and we
	# just check the previous.
	if (@parentSeq) {
		$id = seq_to_jitar_id(@parentSeq);
		if (is_jitar_problem_closed($db, $ce, $userID, $setID, $id)) {
			return 1;
		}
	}

	# If the parent is open then the problem is open if the previous problem has been "completed" or, if this is the
	# first problem in this level.

	do {
		$idSeq[-1]--;

		# In this case we are the first problem in the level.
		if ($idSeq[-1] == 0) {
			return 0;
		}

		$id = seq_to_jitar_id(@idSeq);
	} until ($db->existsUserProblem($userID, $setID, $id));

	$prob = $db->getMergedProblem($userID, $setID, $id);

	# We have to test against the target status in case the student is working in the reduced scoring period.
	my $targetStatus = 1;
	if ($ce->{pg}{ansEvalDefaults}{enableReducedScoring}
		&& $mergedSet->enable_reduced_scoring
		&& after($mergedSet->reduced_scoring_date))
	{
		$targetStatus = $ce->{pg}{ansEvalDefaults}{reducedScoringValue};
	}

	if (abs(jitar_problem_adjusted_status($prob, $db) - $targetStatus) < .001
		|| jitar_problem_finished($prob, $db))
	{
		# Either the previous problem is 100% or is finished.
		return 0;
	} else {

		# In this case the previous problem is hidden.
		return 1;
	}

}

sub jitar_problem_finished ($userProblem, $db) {
	# The problem is open if attempts remain and the maximum score has not been attained.
	return 0
		if (
			$userProblem->status < 1
			&& ($userProblem->max_attempts == -1
				|| $userProblem->max_attempts > $userProblem->num_correct + $userProblem->num_incorrect)
		);

	# Find children
	my @problemSeq = jitar_id_to_seq($userProblem->problem_id);

	my @problemIDs = $db->listUserProblems($userProblem->user_id, $userProblem->set_id);

ID: for my $id (@problemIDs) {
		my @seq = jitar_id_to_seq($id);

		# Check and see if this is a child.
		next unless $#seq == $#problemSeq + 1;
		for (0 .. $#problemSeq) {
			next ID unless $seq[$_] == $problemSeq[$_];
		}

		# Check to see if this counts towards the parent grade.
		my $problem = $db->getMergedProblem($userProblem->user_id, $userProblem->set_id, $id);

		die "Couldn't get problem $id for user "
			. $userProblem->user_id
			. ' and set '
			. $userProblem->set_id
			. ' from the database'
			unless $problem;

		# If this doesn't count then we dont need to worry about it.
		next unless $problem->counts_parent_grade();

		# If it does then see if the problem is finished.
		# If it isn't then the parent isnt finished either.
		return 0 unless jitar_problem_finished($problem, $db);
	}

	return 1;
}

sub jitar_problem_adjusted_status ($userProblem, $db) {
	# This is going to happen often enough that the check saves time.
	return 1 if $userProblem->status == 1;

	my @problemSeq = jitar_id_to_seq($userProblem->problem_id);

	my @problemIDs = $db->listUserProblems($userProblem->user_id, $userProblem->set_id);

	my @weights;
	my @scores;

ID: for my $id (@problemIDs) {
		my @seq = jitar_id_to_seq($id);

		# Check and see if this is a child.
		# It has to be one level deeper,
		next unless $#seq == $#problemSeq + 1;

		# and it has to equal @seq up to the penultimate index.
		for (0 .. $#problemSeq) {
			next ID unless $seq[$_] == $problemSeq[$_];
		}

		# Check to see if this counts towards the parent grade
		my $problem = $db->getMergedProblem($userProblem->user_id, $userProblem->set_id, $id);

		die "Couldn't get problem $id for user "
			. $userProblem->user_id
			. ' and set '
			. $userProblem->set_id
			. ' from the database'
			unless $problem;

		# Skip if it doesnt.
		next unless $problem->counts_parent_grade();

		# If it does count then add its adjusted status to the grading array.
		push @weights, $problem->value;
		push @scores,  jitar_problem_adjusted_status($problem, $db);
	}

	# If no children count towards the problem grade return status.
	return $userProblem->status unless (@weights && @scores);

	# If children do count then return the larger of the two.
	my $childScore  = 0;
	my $totalWeight = 0;
	for (0 .. $#scores) {
		$childScore  += $scores[$_] * $weights[$_];
		$totalWeight += $weights[$_];
	}

	$childScore = $childScore / $totalWeight;

	if ($childScore > $userProblem->status) {
		return $childScore;
	} else {
		return $userProblem->status;
	}
}

sub prob_id_sort (@ids) {
	my @sorted = sort {
		my @seqa = split(/\./, $a);
		my @seqb = split(/\./, $b);

		# Go through the problem number sequence.
		for (0 .. $#seqa) {
			# If at some point two numbers are different return the comparison.  E.g. 2.1.3 vs 1.2.6.
			return $seqa[$_] <=> $seqb[$_] if $seqa[$_] != $seqb[$_];

			# If all of the values are equal but b is shorter then it comes first, i.e. 2.1.3 vs 2.1.
			return 1 if $_ == $#seqb;
		}

		# If all of the values are equal and a and b are the same length then the sequences are equal.
		# Otherwise a was shorter than b so a comes first.
		return $#seqa == $#seqb ? 0 : -1;
	} @ids;
	return @sorted;
}

1;

=head1 NAME

WeBWorK::Utils::JITAR - contains utility subroutines for JITAR problems.

=head2 seq_to_jitar_id

Usage: C<seq_to_jitar_id(@seq)>

This method takes the tree sequence C<@seq> and returns the jitar id.  This id
is a specially crafted signed 32 bit integer of the form

    SAAAAAAABBBBBBCCCCCCDDDDEEEEFFFF

in binary.  Here A is the level 1 index, B is the level 2 index, and C, D, E and
F are the indexes for levels 3 through 6.

Note: Level 1 can contain indexes up to 125.  Levels 2 and 3 can contain indxes
up to 63.  For levels 4 through six you are limited to 15.

=head2 jitar_id_to_seq

Usage: C<jitar_id_to_seq($id)>

Takes a jitar_id and returns the tree sequence.  Jitar ids have the format
described above.

=head2 is_jitar_problem_hidden

Usage: C<is_jitar_problem_hidden($db, $userID, $setID, $problemID)>

Returns 1 if the problem is hidden.  The problem is hidden if the number of
attempts on the parent problem is greater than att_to_open_children, or if the
user has run out of attempts.  Everything is opened up after the due date.

=head2 is_jitar_problem_closed

Usage: C<is_jitar_problem_closed($db, $ce, $userID, $setID, $problemID)>

Returns 1 if the jitar problem is closed.  JITAR problems are closed if the
restrict_prob_progression variable is set on the set, and if the previous
problem is closed, or hasn't been finished yet.  The first problem in a level is
always open.

=head2 jitar_problem_finished

Usage: C<jitar_problem_finished($userProblem, $db)>

This returns 1 if the given problem is "finished".  This happens when the
problem attempts have been maxed out, and the attempts of any children with the
"counts_to_parent_grade" also have their attemtps maxed out.  (In other words if
the grade can't be raised any more.)

=head2 jitar_problem_adjusted_status

Usage: C<jitar_problem_adjusted_status($userProblem, $db)>

This returns the adjusted status for a jitar problem.  This is either the
problems status, or it is the greater of the status and the score generated by
taking the weighted average of all child problems that have the
"counts_parent_grade" flag set.

=head2 prob_id_sort

Usage: C<prob_id_sort(@ids)>

Sorts problem ID's so that the usual integral problem ids are first and
just-in-time ids after that. For example,

    1, 1.1, 1.1.1, 2, 2.1, 2.2, 3, 4

=cut
