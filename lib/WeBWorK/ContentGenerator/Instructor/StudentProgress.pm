################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::Instructor::StudentProgress;
use parent qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::StudentProgress - Display Student Progress.

=cut

use strict;
use warnings;

use WeBWorK::Utils qw(jitar_id_to_seq wwRound grade_set format_set_name_display);
use WeBWorK::Utils::Grades qw(list_set_versions);

sub initialize {
	my $self    = shift;
	my $r       = $self->{r};
	my $urlpath = $r->urlpath;
	my $db      = $self->{db};
	my $ce      = $self->{ce};
	my $user    = $r->param('user');

	# Check permissions
	return unless $r->authz->hasPermissions($user, "access_instructor_tools");

	# Cache a list of all users except set level proctors and practice users, and restrict to the sections or
	# recitations that are allowed for the user if such restrictions are defined.  This list is sorted by last_name,
	# then first_name, then user_id.  This is used in multiple places in this module, and is guaranteed to be used at
	# least once.  So it is done here to prevent extra database access.
	$self->{student_records} = [
		$db->getUsersWhere(
			{
				user_id => [ -and => { not_like => 'set_id:%' }, { not_like => "$ce->{practiceUserPrefix}\%" } ],
				$ce->{viewable_sections}{$user} || $ce->{viewable_recitations}{$user}
				? (
					-or => [
						$ce->{viewable_sections}{$user}    ? (section    => $ce->{viewable_sections}{$user})    : (),
						$ce->{viewable_recitations}{$user} ? (recitation => $ce->{viewable_recitations}{$user}) : ()
					]
					)
				: ()
			},
			[qw/last_name first_name user_id/]
		)
	];

	$self->{type} = $urlpath->arg("statType") || '';
	if ($self->{type} eq 'student') {
		$self->{studentID} = $r->urlpath->arg("userID") || $user;
	} elsif ($self->{type} eq 'set') {
		$self->{setID} = $r->urlpath->arg("setID") || 0;
		my $setRecord = $db->getGlobalSet($self->{setID});
		return unless $setRecord;
		$self->{setRecord} = $setRecord;
	}

	return;
}

sub title {
	my ($self) = @_;
	my $r = $self->r;

	return '' unless $r->authz->hasPermissions($r->param('user'), 'access_instructor_tools');

	my $type = $self->{type};
	if ($type eq 'student') {
		return $r->maketext('Student Progress for [_1] student [_2]', $self->{ce}{courseName}, $self->{studentID});
	} elsif ($type eq 'set') {
		return $r->maketext(
			'Student Progress for [_1] set [_2]. Closes [_3]',
			$self->{ce}{courseName},
			$r->tag('span', dir => 'ltr', format_set_name_display($self->{setID})),
			$self->formatDateTime($self->{setRecord}->due_date)
		);
	}

	return $r->maketext('Student Progress');
}

sub siblings {
	my $self = shift;
	# Stats and StudentProgress share this template.
	return $self->r->include('ContentGenerator/Instructor/Stats/siblings',
		header => $self->r->maketext('Student Progress'));
}

# Display student progress table
sub displaySets {
	my $self    = shift;
	my $r       = $self->r;
	my $urlpath = $r->urlpath;
	my $db      = $r->db;
	my $ce      = $r->ce;

	my $setIsVersioned =
		defined $self->{setRecord}->assignment_type && $self->{setRecord}->assignment_type =~ /gateway/;

	# The returning parameter lets us set defaults for versioned sets
	if ($setIsVersioned && !$r->param('returning')) {
		$r->param('show_date',     1) if !$r->param('show_date');
		$r->param('show_testtime', 1) if !$r->param('show_testtime');
	}

	# For versioned sets some of the columns are optionally shown.  The following flags keep track of which ones to
	# show.  An additional variable keeps track of whether to show all scores or only the best score.  The defaults set
	# here used to determine headers for non-versioned sets.

	my %showColumns = $setIsVersioned
		? (
			date     => $r->param('show_date')       // 0,
			testtime => $r->param('show_testtime')   // 0,
			problems => $r->param('show_problems')   // 0,
			section  => $r->param('show_section')    // 0,
			recit    => $r->param('show_recitation') // 0,
			login    => $r->param('show_login')      // 0,
		)
		: (date => 0, testtime => 0, problems => 1, section => 1, recit => 1, login => 1);
	my $showBestOnly = $setIsVersioned ? $r->param('show_best_only') : 0;

	my @score_list;
	my @user_set_list;

	for my $studentRecord (@{ $self->{student_records} }) {
		next unless $ce->status_abbrev_has_behavior($studentRecord->status, 'include_in_stats');

		my $studentName = $studentRecord->user_id;
		my ($allSetVersionNames, $notAssignedSet) =
			list_set_versions($db, $studentName, $self->{setID}, $setIsVersioned);

		next if $notAssignedSet;

		my $max_version_data = {};

		for my $setName (@$allSetVersionNames) {
			my $set;
			my $vNum = 0;

			# For versioned tests we might be displaying the test date and test time.
			my $dateOfTest = '';
			my $testTime   = '';

			if ($setIsVersioned) {
				($setName, $vNum) = ($setName =~ /(.+),v(\d+)$/);
				# Information from the set is needed to set up the display below. So get the merged user set as well.
				$set        = $db->getMergedSetVersion($studentRecord->user_id, $setName, $vNum);
				$dateOfTest = localtime($set->version_creation_time());
				if ($set->version_last_attempt_time) {
					$testTime = ($set->version_last_attempt_time - $set->open_date) / 60;
					my $timeLimit = $set->version_time_limit / 60;
					$testTime = $timeLimit if ($testTime > $timeLimit);
					$testTime = sprintf('%3.1f min', $testTime);
				} elsif (time - $set->open_date < $set->version_time_limit) {
					$testTime = $r->maketext('still open');
				} else {
					$testTime = $r->maketext('time limit exceeded');
				}
			} else {
				$set = $db->getMergedSet($studentName, $setName);
			}

			my ($score, $total, $problem_scores, $problem_incorrect_attempts) =
				grade_set($db, $set, $studentName, $setIsVersioned, 1);
			$score = wwRound(2, $score);

			my $version_data = {
				version            => $vNum,
				score              => $score,
				total              => $total,
				date               => $dateOfTest,
				testtime           => $testTime,
				problem_scores     => $problem_scores,
				incorrect_attempts => ''
			};

			if ($showBestOnly) {
				# Keep track of the best score.
				if (!%$max_version_data || $score > $max_version_data->{score}) {
					$max_version_data = {%$version_data};
				}
			} else {
				# Add the score to the list of scores, and add the data to the set data list.
				push(@score_list,    $version_data->{total} ? $version_data->{score} / $version_data->{total} : 0);
				push(@user_set_list, { record => $studentRecord, %$version_data });
			}
		}

		if ($showBestOnly || !@$allSetVersionNames) {
			# If only the best score is to be shown or there were no set versions and the set was assigned to the user,
			# then add the score to the list of scores and add the data to the set data list.
			push(@score_list,
				%$max_version_data
					&& $max_version_data->{total} ? $max_version_data->{score} / $max_version_data->{total} : 0);

			push(
				@user_set_list,
				{
					record             => $studentRecord,
					score              => 0,
					total              => -1,
					date               => '',
					testtime           => '',
					problem_scores     => [],
					incorrect_attempts => [],
					%$max_version_data
				}
			);
		}
	}

	my $primary_sort_method   = $r->param('primary_sort');
	my $secondary_sort_method = $r->param('secondary_sort');
	my $ternary_sort_method   = $r->param('ternary_sort');

	my $sort_method = sub {
		my ($m, $n, $sort_method_name) = @_;
		return 0 unless defined($sort_method_name);
		return lc($m->{record}{last_name}) cmp lc($n->{record}{last_name})   if $sort_method_name eq 'last_name';
		return lc($m->{record}{first_name}) cmp lc($n->{record}{first_name}) if $sort_method_name eq 'first_name';
		return lc($m->{record}{email_address}) cmp lc($n->{record}{email_address})
			if $sort_method_name eq 'email_address';
		return $n->{score} <=> $m->{score}                                   if $sort_method_name eq 'score';
		return lc($m->{record}{section}) cmp lc($n->{record}{section})       if $sort_method_name eq 'section';
		return lc($m->{record}{recitation}) cmp lc($n->{record}{recitation}) if $sort_method_name eq 'recitation';
		return lc($m->{record}{user_id}) cmp lc($n->{record}{user_id})       if $sort_method_name eq 'user_id';
	};

	@user_set_list = sort {
		$sort_method->($a, $b, $primary_sort_method)
			|| $sort_method->($a, $b, $secondary_sort_method)
			|| $sort_method->($a, $b, $ternary_sort_method)
			|| lc($a->{record}{last_name}) cmp lc($b->{record}{last_name})
			|| lc($a->{record}{first_name}) cmp lc($b->{record}{first_name})
			|| lc($a->{record}{user_id}) cmp lc($b->{record}{user_id})
	} @user_set_list;

	# Construct header
	my @problems = map { $_->[1] } $db->listGlobalProblemsWhere({ set_id => $self->{setID} }, 'problem_id');
	@problems = ($r->maketext('None')) unless @problems;

	# For a jitar set we only get the top level problems
	if ($self->{setRecord}->assignment_type eq 'jitar') {
		my @topLevelProblems;
		for my $id (@problems) {
			my @seq = jitar_id_to_seq($id);
			push @topLevelProblems, $seq[0] if $#seq == 0;
		}
		@problems = @topLevelProblems;
	}

	my $numCols = 1;
	$numCols++                    if $showColumns{date};
	$numCols++                    if $showColumns{testtime};
	$numCols += scalar(@problems) if $showColumns{problems};

	return $r->include(
		'ContentGenerator/Instructor/StudentProgress/set_progress',
		setIsVersioned        => $setIsVersioned,
		showColumns           => \%showColumns,
		showBestOnly          => $showBestOnly,
		numCols               => $numCols,
		primary_sort_method   => $primary_sort_method,
		secondary_sort_method => $secondary_sort_method,
		ternary_sort_method   => $ternary_sort_method,
		problems              => \@problems,
		user_set_list         => \@user_set_list
	);
}

1;
