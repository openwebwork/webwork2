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

package WeBWorK::Utils::Sets;
use Mojo::Base 'Exporter', -signatures;

use Carp;

use PGrandom;
use WeBWorK::Utils qw(wwRound);
use WeBWorK::Utils::DateTime qw(after before);
use WeBWorK::Utils::JITAR qw(jitar_id_to_seq jitar_problem_adjusted_status);

our @EXPORT_OK = qw(
	format_set_name_internal
	format_set_name_display
	grade_set
	grade_gateway
	grade_all_sets
	is_restricted
	get_test_problem_position
	list_set_versions
);

sub format_set_name_internal ($set_name) {
	return ($set_name =~ s/^\s*|\s*$//gr) =~ s/ /_/gr;
}

sub format_set_name_display ($set_name) {
	return $set_name =~ s/_/ /gr;
}

sub grade_set ($db, $set, $studentName, $setIsVersioned = 0, $wantProblemDetails = 0) {
	my $totalRight = 0;
	my $total      = 0;

	# This information is also accumulated if $wantProblemDetails is true.
	my $problem_scores             = [];
	my $problem_incorrect_attempts = [];

	# DBFIXME: To collect the problem records, we have to know which merge routines to call.  Should this really be an
	# issue here?  That is, shouldn't the database deal with it invisibly by detecting what the problem types are?
	my @problemRecords =
		$setIsVersioned
		? $db->getAllMergedProblemVersions($studentName, $set->set_id, $set->version_id)
		: $db->getAllMergedUserProblems($studentName, $set->set_id);

	# For jitar sets we only use the top level problems.
	if ($set->assignment_type && $set->assignment_type eq 'jitar') {
		my @topLevelProblems;
		for my $problem (@problemRecords) {
			my @seq = jitar_id_to_seq($problem->problem_id);
			push @topLevelProblems, $problem if $#seq == 0;
		}

		@problemRecords = @topLevelProblems;
	}

	if ($wantProblemDetails) {
		# Sort records.  For gateway/quiz assignments we have to be careful about the order in which the problems are
		# displayed, because they may be in a random order.
		if ($set->problem_randorder) {
			my @newOrder;
			my @probOrder = (0 .. $#problemRecords);
			# Reorder using the set psvn for the seed in the same way that the GatewayQuiz module does.
			my $pgrand = PGrandom->new();
			$pgrand->srand($set->psvn);
			while (@probOrder) {
				my $i = int($pgrand->rand(scalar(@probOrder)));
				push(@newOrder, splice(@probOrder, $i, 1));
			}
			# Now $newOrder[i] = pNum - 1, where pNum is the problem number to display in the ith position on the test
			# for sorting. Invert this mapping.
			my %pSort = map { $problemRecords[ $newOrder[$_] ]->problem_id => $_ } (0 .. $#newOrder);

			@problemRecords = sort { $pSort{ $a->problem_id } <=> $pSort{ $b->problem_id } } @problemRecords;
		} else {
			# Sort records
			@problemRecords = sort { $a->problem_id <=> $b->problem_id } @problemRecords;
		}
	}

	for my $problemRecord (@problemRecords) {
		my $status = $problemRecord->status || 0;

		# Get the adjusted jitar grade for top level problems if this is a jitar set.
		$status = jitar_problem_adjusted_status($problemRecord, $db) if $set->assignment_type eq 'jitar';

		# Clamp the status value between 0 and 1.
		$status = 0 if $status < 0;
		$status = 1 if $status > 1;

		if ($wantProblemDetails) {
			push(@$problem_scores,             $problemRecord->attempted ? 100 * wwRound(2, $status) : '&nbsp;.&nbsp;');
			push(@$problem_incorrect_attempts, $problemRecord->num_incorrect || 0);
		}

		my $probValue = $problemRecord->value;
		$probValue = 1 unless defined $probValue && $probValue ne '';    # FIXME: Set defaults here?
		$total      += $probValue;
		$totalRight += $status * $probValue;
	}

	if (wantarray) {
		return ($totalRight, $total, $problem_scores, $problem_incorrect_attempts);
	} else {
		return $total ? $totalRight / $total : 0;
	}
}

sub grade_gateway ($db, $set, $setName, $studentName) {
	my @versionNums = $db->listSetVersions($studentName, $setName);

	my $bestTotalRight = 0;
	my $bestTotal      = 0;

	if (@versionNums) {
		for my $i (@versionNums) {
			my $versionedSet = $db->getSetVersion($studentName, $setName, $i);

			my ($totalRight, $total) = grade_set($db, $versionedSet, $studentName, 1);
			if ($totalRight > $bestTotalRight) {
				$bestTotalRight = $totalRight;
				$bestTotal      = $total;
			}
		}
	}

	if (wantarray) {
		return ($bestTotalRight, $bestTotal);
	} else {
		return 0 unless $bestTotal;
		return $bestTotalRight / $bestTotal;
	}
}

sub grade_all_sets ($db, $studentName, $LTISendZeroScores) {
	my @setIDs     = $db->listUserSets($studentName);
	my @userSetIDs = map { [ $studentName, $_ ] } @setIDs;
	my @userSets   = $db->getMergedSets(@userSetIDs);

	my $courseTotal      = 0;
	my $courseTotalRight = 0;

	for my $userSet (@userSets) {
		next unless (after($userSet->open_date()));
		my $totalRight;
		my $total;
		my %dates = (
			open    => $userSet->open_date(),
			reduced => $userSet->reduced_scoring_date(),
			close   => $userSet->close_date(),
			answer  => $userSet->answer_date()
		);
		if ($userSet->assignment_type() =~ /gateway/) {
			($totalRight, $total) = grade_gateway($db, $userSet, $userSet->set_id, $studentName);
		} else {
			($totalRight, $total) = grade_set($db, $userSet, $studentName, 0);
		}
		if ($totalRight == 0) {
			next if ($LTISendZeroScores eq 'never' || before($dates{$LTISendZeroScores}));
		}
		$courseTotalRight += $totalRight;
		$courseTotal      += $total;
	}

	if (wantarray) {
		return ($courseTotalRight, $courseTotal);
	} else {
		return 0 unless $courseTotal;
		return $courseTotalRight / $courseTotal;
	}

}

sub is_restricted ($db, $set, $studentName) {
	# all sets open after the due date
	return () if after($set->due_date());

	my $setID = $set->set_id();
	my @needed;

	if ($set->restricted_release) {
		my @proposed_sets  = split(/\s*,\s*/, $set->restricted_release);
		my $required_score = sprintf('%.2f', $set->restricted_status || 0);

		my @good_sets;
		for (@proposed_sets) {
			push @good_sets, $_ if $db->existsGlobalSet($_);
		}

		for my $restrictor (@good_sets) {
			my $r_score        = 0;
			my $restrictor_set = $db->getGlobalSet($restrictor);

			if ($restrictor_set->assignment_type =~ /gateway/) {
				my @versions =
					$db->getSetVersionsWhere({ user_id => $studentName, set_id => { like => $restrictor . ',v%' } });
				for (@versions) {
					my $v_score = grade_set($db, $_, $studentName, 1);

					$r_score = $v_score if ($v_score > $r_score);
				}
			} else {
				$r_score = grade_set($db, $restrictor_set, $studentName, 0);
			}

			# round to evade machine rounding error
			$r_score = sprintf('%.2f', $r_score);
			if ($r_score < $required_score) {
				push @needed, $restrictor;
			}
		}
	}
	return unless @needed;
	return @needed;
}

sub get_test_problem_position ($db, $problem) {
	my $set            = $db->getMergedSetVersion($problem->user_id, $problem->set_id, $problem->version_id);
	my @problemNumbers = $db->listProblemVersions($set->user_id, $set->set_id, $set->version_id);

	my $problemNumber = 0;

	if ($set->problem_randorder) {
		# Find the test problem order using the set psvn for the seed in the same way that the GatewayQuiz module does.
		my @problemOrder = (0 .. $#problemNumbers);
		my $pgrand       = PGrandom->new;
		$pgrand->srand($set->psvn);
		my $count = 0;
		while (@problemOrder) {
			my $index = splice(@problemOrder, int($pgrand->rand(scalar(@problemOrder))), 1);
			if ($problemNumbers[$index] == $problem->problem_id) {
				$problemNumber = $count;
				last;
			}
			++$count;
		}
	} else {
		($problemNumber) = grep { $problemNumbers[$_] == $problem->problem_id } 0 .. $#problemNumbers;
	}

	my $pageNumber;

	# Update startProb and endProb for multipage tests
	if ($set->problems_per_page) {
		$pageNumber = ($problemNumber + 1) / $set->problems_per_page;
		$pageNumber = int($pageNumber) + 1 if int($pageNumber) != $pageNumber;
	} else {
		$pageNumber = 1;
	}

	return ($problemNumber, $pageNumber);
}

sub list_set_versions ($db, $studentName, $setName, $setIsVersioned = 0) {
	croak 'list_set_versions requires a database reference as the first element' unless ref($db) =~ /DB/;

	my @allSetNames;
	my $notAssignedSet = 0;

	if ($setIsVersioned) {
		my @setVersions = $db->listSetVersions($studentName, $setName);
		@allSetNames = map {"$setName,v$_"} @setVersions;
		# If there are not any set versions, it may be because the user is not assigned the set,
		# or because the user hasn't completed any versions.
		$notAssignedSet = 1 if !@setVersions && !$db->existsUserSet($studentName, $setName);
	} else {
		@allSetNames    = ($setName);
		$notAssignedSet = 1 if !$db->existsUserSet($studentName, $setName);
	}

	return (\@allSetNames, $notAssignedSet);
}

1;

=head1 NAME

WeBWorK::Utils::Sets - contains utility subroutines for sets.

=head2 format_set_name_internal

Usage: C<format_set_name_internal($set_name)>

This is for formatting set names input via text inputs in the user interface for
internal use.  Set names are allowed to be input with spaces, but internally
spaces are not allowed and are converted to underscores.

=head2 format_set_name_internal

Usage: C<format_set_name_display($set_name)>

This formats set names for display, converting underscores back into spaces.

=head2 grade_set

Usage: C<grade_set($db, $set, $studentName, $setIsVersioned = 0, $wantProblemDetails)>

The arguments C<$db>, C<$set>, and C<$studentName> are required. If
C<$setIsVersioned> is true, then the given set is assumed to be a set version.

In list context this returns a list containing the total number of correct
problems, and the total number of problems in the set.  If
C<$wantProblemDetails> is true, then a reference to an array of the scores for
each problem, and a reference to the array of the number of incorrect attempts
for each problem are also included in the returned list.

In scalar context this returns the percentage correct.

=head2 grade_gateway

Usage: C<grade_gateway($db, $set, $setName, $studentName)>

All arguments are required.

In list context this returns a list fo the total number of correct problems for
the highest scoring version of this test, and the total number of problems in
that version.

In scalar context this returns the percentage correct for the highest scoring
version of this test.

=head2 grade_all_sets

Usage: C<grade_all_sets($db, $studentName)>

All arguments listed are required.

In list context this returns the total course score for all sets and the maximum
possible course score.

In scalar context this returns the percentage score for all sets in the course.

=head2 is_restricted

Usage: C<is_restricted($db, $set, $studentName)>

All arguments are required.

This returns 1 if release of the set is restricted for the student given in
C<$studentName>, and 0 otherwise.

=head2 get_test_problem_position

Usage: C<get_test_problem_position($db, $problem)>

Given C<$problem> which should be a problem version, get_test_problem_position
returns the 0 based problem number for the problem on the test, and the 1 based
page number for the page on the test that the problem is on.

=head2 list_set_versions

Usage: C<list_set_versions($db, $studentName, $setName, $setIsVersioned)>

Construct a list of versioned sets for this student user.  This returns a
reference to an array of names of set versions and whether or not the user is
assigned to the set.  The list of names will be a list of set versions if the
set is versioned (i.e., if C<setIsVersioned> is true), and a list containing
only the original set id otherwise.

=cut
