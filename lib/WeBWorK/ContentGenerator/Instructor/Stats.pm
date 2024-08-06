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

package WeBWorK::ContentGenerator::Instructor::Stats;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Stats - Display statistics by user or
homework set (including sv graphs).

=cut

use SVG;

use WeBWorK::Utils::FilterRecords qw(getFiltersForClass filterRecords);
use WeBWorK::Utils::JITAR qw(jitar_id_to_seq jitar_problem_adjusted_status);
use WeBWorK::Utils::Sets qw(grade_set format_set_name_display);

sub initialize ($c) {
	my $db   = $c->db;
	my $ce   = $c->ce;
	my $user = $c->param('user');

	# Check permissions
	return unless $c->authz->hasPermissions($user, 'access_instructor_tools');

	# Cache a list of all users except set level proctors and practice users, and restrict to the sections or
	# recitations that are allowed for the user if such restrictions are defined.  This list is sorted by last_name,
	# then first_name, then user_id.  This is used in multiple places in this module, and is guaranteed to be used at
	# least once.  So it is done here to prevent extra database access.
	$c->{student_records} = [
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

	if ($c->current_route eq 'instructor_user_statistics') {
		$c->{studentID} = $c->stash('userID');
	} elsif ($c->current_route =~ /^instructor_(set|problem)_statistics$/) {
		my $setRecord = $db->getGlobalSet($c->stash('setID'));
		return unless $setRecord;
		$c->{setRecord} = $setRecord;
		my $problemID = $c->stash('problemID') || 0;
		if ($problemID) {
			$c->{prettyID} =
				$setRecord->assignment_type eq 'jitar' ? join('.', jitar_id_to_seq($problemID)) : $problemID;
			my $problemRecord = $db->getGlobalProblem($c->stash('setID'), $problemID);
			return unless $problemRecord;
			$c->{problemRecord} = $problemRecord;
		}
	}

	return;
}

sub page_title ($c) {
	return '' unless $c->authz->hasPermissions($c->param('user'), 'access_instructor_tools');

	my $setID = $c->stash('setID') || '';

	if ($c->current_route eq 'instructor_user_statistics') {
		return $c->maketext('Statistics for student [_1]', $c->{studentID});
	} elsif ($c->current_route eq 'instructor_set_statistics') {
		return $c->maketext('Statistics for [_1]', $c->tag('span', dir => 'ltr', format_set_name_display($setID)));
	} elsif ($c->current_route eq 'instructor_problem_statistics') {
		return $c->maketext(
			'Statistics for [_1] problem [_2]',
			$c->tag('span', dir => 'ltr', format_set_name_display($setID)),
			$c->{prettyID}
		);
	}

	return $c->maketext('Statistics');
}

sub siblings ($c) {
	# Stats and StudentProgress share this template.
	return $c->include('ContentGenerator/Instructor/Stats/siblings', header => $c->maketext('Statistics'));
}

# Apply the currently selected filter to the student records, and return a reference to the
# list of students and a reference to the array of section/recitation filters.
sub filter_students ($c) {
	my $ce       = $c->ce;
	my $filter   = $c->param('filter') || 'all';
	my @students = grep { $ce->status_abbrev_has_behavior($_->status, 'include_in_stats') } @{ $c->{student_records} };

	# Change visible name of the first 'all' filter.
	my $filters = getFiltersForClass($c, [ 'section', 'recitation' ], @students);
	$filters->[0][0] = $c->maketext('All students');

	@students = filterRecords($c, 0, [$filter], @students) unless $filter eq 'all';

	return (\@students, $filters);
}

sub set_stats ($c) {
	return $c->tag(
		'div',
		class => 'alert alert-danger p-1',
		$c->maketext('Global set [_1] not found.', $c->stash('setID'))
	) unless $c->{setRecord};

	my $db = $c->db;

	# Get a list of the global problem records for this set.
	my @problems = $db->getGlobalProblemsWhere({ set_id => $c->stash('setID') }, 'problem_id');

	# Total point value of the set.
	my $totalValue = 0;

	my $isJitarSet = $c->{setRecord}->assignment_type eq 'jitar';

	# For jitar sets we need to know which problems are top level problems.
	my %topLevelProblems;

	# Compile the following data for all students.
	my @index_list;                         # List of all student success indicators.
	my @score_list;                         # List of all student total percentage scores.
	my %attempts_list_for_problem;          # A list of the number of attempts for each problem.
	my %num_attempts_for_problem;           # Total number of attempts for this problem (sum of above list).
	my %num_students_attempting_problem;    # The number of students attempting this problem.
	my %total_status_for_problem;           # The total status of active students (sum of individual status).
	my %adjusted_status_for_problem;        # The total adjusted status for top level jitar problems.

	for my $problem (@problems) {
		my $probID = $problem->problem_id;

		# Pretty problem number for jitar sets (just the problem id otherwise).
		$problem->{prettyID} = $isJitarSet ? join('.', jitar_id_to_seq($problem->problem_id)) : $problem->problem_id;

		# Link to individual problem stats page.
		$problem->{statsLink} =
			$c->systemLink(
				$c->url_for('instructor_problem_statistics', setID => $c->stash('setID'), problemID => $probID),
				params => $c->param('filter') ? { filter => $c->param('filter') } : {});

		# Store the point value of each problem.
		$totalValue += $problem->value;

		# Keep track of all problems for non Jitar sets, and top level for Jitar.
		$topLevelProblems{$probID} = 1 if $isJitarSet && $problem->{prettyID} !~ /\./;

		# Initialize the number of correct answers and correct adjusted answers.
		$total_status_for_problem{$probID}    = 0;
		$adjusted_status_for_problem{$probID} = 0 if $isJitarSet;
	}

	# Only count top level problems for Jitar sets.
	my $num_problems = $isJitarSet ? scalar(keys %topLevelProblems) : scalar(@problems);

	my ($students, $filters) = $c->filter_students;
	for my $studentRecord (@$students) {
		my $student                    = $studentRecord->user_id;
		my $totalRight                 = 0;
		my $total                      = 0;
		my $total_num_attempts_for_set = 0;

		# Get problem data for student.
		my @problemRecords;
		my $noSkip = 0;
		if ($c->{setRecord}->assignment_type =~ /gateway/) {
			# Only use the quiz version with the best score.
			my @setVersions =
				$db->getMergedSetVersionsWhere(
					{ user_id => $student, set_id => { like => $c->stash('setID') . ',v%' } });
			if (@setVersions) {
				my $maxVersion = 1;
				my $maxStatus  = 0;
				for my $verSet (@setVersions) {
					my ($total, $possible) = grade_set($db, $verSet, $student, 1);
					if ($possible > 0 && $total / $possible >= $maxStatus) {
						$maxStatus  = $total / $possible;
						$maxVersion = $verSet->version_id;
					}
				}
				@problemRecords = $db->getAllMergedProblemVersions($student, $c->stash('setID'), $maxVersion);
			} else {
				# Check if student is assigned to the quiz but hasn't started any version.
				$noSkip = 1 if $db->getMergedSet($student, $c->stash('setID'));
			}
		} else {
			@problemRecords = $db->getUserProblemsWhere({ user_id => $student, set_id => $c->stash('setID') });
		}
		# Don't include students who are not assigned to set.
		next unless ($noSkip || @problemRecords);

		for my $problemRecord (@problemRecords) {
			my $probID = $problemRecord->problem_id;

			# It is possible that $problemRecord->foo can be an empty or blank string instead of 0.
			# The || clause fixes this and prevents warning messages in the usage below.
			my $num_attempts = ($problemRecord->num_correct || 0) + ($problemRecord->num_incorrect || 0);
			my $probValue    = $problemRecord->value;
			$probValue = 1 unless defined($probValue) && $probValue ne '';
			my $status = $problemRecord->status || 0;

			# Clamp the status value between 0 and 1.
			$status = 0 if $status < 0;
			$status = 1 if $status > 1;

			# Get the adjusted jitar grade for top level problems if this is a jitar set.
			my $adjusted_status = $isJitarSet ? jitar_problem_adjusted_status($problemRecord, $db) : '';

			# Clamp the adjusted status value between 0 and 1.
			$adjusted_status = 0 if $adjusted_status ne '' && $adjusted_status < 0;
			$adjusted_status = 1 if $adjusted_status ne '' && $adjusted_status > 1;

			# If it is a jitar set, then compute total and totalRight using adjusted status and top level problems.
			if ($isJitarSet) {
				my @seq = jitar_id_to_seq($probID);
				if ($#seq == 0) {
					$total      += $probValue;
					$totalRight += $adjusted_status * $probValue;
				}
			} else {
				$total      += $probValue;
				$totalRight += $status * $probValue;
			}

			# Add on the scores for this problem.
			if ($problemRecord->attempted) {
				$num_students_attempting_problem{$probID}++;
				push(@{ $attempts_list_for_problem{$probID} }, $num_attempts);
				$num_attempts_for_problem{$probID}    += $num_attempts;
				$total_num_attempts_for_set           += $num_attempts;
				$total_status_for_problem{$probID}    += $status;
				$adjusted_status_for_problem{$probID} += $adjusted_status if ($isJitarSet);
			}
		}

		my $avgScore         = $total        ? $totalRight / $total                        : 0;
		my $avg_num_attempts = $num_problems ? $total_num_attempts_for_set / $num_problems : 0;

		# Add the success indicator and scores (between 0 and 1) to respective lists.
		push(@index_list, $avg_num_attempts ? $avgScore**2 / $avg_num_attempts : 0);
		push(@score_list, $avgScore);
	}

	# Loop over the problems one more time to compute statistics.
	my (@avgScore, @adjScore, @avgAttempts, @numActive, @attemptsList, @successList);
	for (@problems) {
		my $probID  = $_->problem_id;
		my $nStu    = $num_students_attempting_problem{$probID};
		my $avgS    = $nStu ? $total_status_for_problem{$probID} / $nStu : 0;
		my $avgA    = $avgS ? $num_attempts_for_problem{$probID} / $nStu : 0;
		my $success = $avgA ? sprintf('%0.0f', 100 * $avgS**2 / $avgA)   : '-';

		push(@attemptsList, $attempts_list_for_problem{$probID});
		push(@avgScore,     $avgS ? sprintf('%0.0f', 100 * $avgS) : '-');
		push(@avgAttempts,  $avgA ? sprintf('%0.1f', $avgA)       : '-');
		push(@numActive,    $nStu ? $nStu : '-');
		push(@successList,  $success);
		push(@adjScore,
			$nStu && $topLevelProblems{$probID}
			? sprintf('%0.0f', 100 * $adjusted_status_for_problem{$probID} / $nStu)
			: '-')
			if ($isJitarSet);
	}

	# Collect data for the histogram of total scores.
	my @buckets = (0) x 10;
	for (@score_list) { $buckets[ $_ > 0.995 ? 9 : int(10 * $_ + 0.05) ]++ }
	my $maxCount = 0;
	for (@buckets) { $maxCount = $_ if $_ > $maxCount; }
	$maxCount = int($maxCount / 5) + 1;
	@buckets  = reverse(@buckets);

	# Overall average
	my ($mean, $stddev) = $c->compute_stats(@score_list);
	my ($overallAvgAttempts) = $c->compute_stats(grep { !/-/ } @avgAttempts);
	my $overallSuccess = $overallAvgAttempts ? $mean**2 / $overallAvgAttempts : 0;
	($overallSuccess) = $c->compute_stats(@index_list);

	# Data for the SVG bar graph showing the percentage of students with correct answers for each problem.
	my (@svgProblemData, @svgProblemLabels, @jitarBars);
	for (@problems) {
		my $probID = $_->problem_id;

		if ($isJitarSet) {
			if ($topLevelProblems{$probID}) {
				push(
					@jitarBars,
					$num_students_attempting_problem{$probID}
					? sprintf('%0.2f',
						$adjusted_status_for_problem{$probID} / $num_students_attempting_problem{$probID})
					: 0
				);    # Avoid division by zero
			} else {
				push(@jitarBars, -1);    # Don't draw bars for non-top level problem.
			}
		}
		push(@svgProblemData,
			$num_students_attempting_problem{$probID}
			? sprintf('%0.2f', $total_status_for_problem{$probID} / $num_students_attempting_problem{$probID})
			: 0);                        # Avoid division by zero

		push(@svgProblemLabels, length $_->{prettyID} > 4 ? '##' : $_->{prettyID});
	}

	return $c->include(
		'ContentGenerator/Instructor/Stats/set_stats',
		filters            => $filters,
		problems           => \@problems,
		score_list         => [ map { sprintf('%0.0f', 100 * $_) } @score_list ],
		buckets            => \@buckets,
		maxCount           => $maxCount,
		totalValue         => $totalValue,
		mean               => $mean,
		stddev             => $stddev,
		overallAvgAttempts => $overallAvgAttempts,
		overallSuccess     => $overallSuccess,
		index_list         => [ map { sprintf('%0.0f', 100 * $_) } @index_list ],
		svgProblemData     => \@svgProblemData,
		svgProblemLabels   => \@svgProblemLabels,
		isJitarSet         => $isJitarSet,
		jitarBars          => \@jitarBars,
		adjScore           => \@adjScore,
		avgScore           => \@avgScore,
		avgAttempts        => \@avgAttempts,
		successList        => \@successList,
		numActive          => \@numActive,
		attemptsList       => \@attemptsList
	);
}

sub problem_stats ($c) {
	return $c->tag(
		'div',
		class => 'alert alert-danger p-1',
		$c->maketext('Global set [_1] not found.', $c->stash('setID'))
	) unless $c->{setRecord};

	return $c->tag(
		'div',
		class => 'alert alert-danger p-1',
		$c->maketext('Global problem [_1] not found for set [_2].', $c->{prettyID}, $c->stash('setID'))
	) unless $c->{problemRecord};

	my $db        = $c->db;
	my $ce        = $c->ce;
	my $user      = $c->param('user');
	my $courseID  = $c->stash('courseID');
	my $problemID = $c->stash('problemID');

	my $isJitarSet    = $c->{setRecord}->assignment_type eq 'jitar';
	my $topLevelJitar = $c->{prettyID} !~ /\./;

	my ($students, $filters) = $c->filter_students;
	my (@problemScores, @adjustedScores, @problemAttempts, @successList);
	my $activeStudents   = 0;
	my $inactiveStudents = 0;
	for my $studentRecord (@$students) {
		my $student = $studentRecord->user_id;
		my $studentProblem;

		if ($c->{setRecord}->assignment_type =~ /gateway/) {
			my @problemRecords =
				$db->getProblemVersionsWhere(
					{ user_id => $student, problem_id => $problemID, set_id => { like => $c->stash('setID') . ',v%' } }
				);
			my $maxRecord = 0;
			my $maxStatus = 0;
			for (0 .. $#problemRecords) {
				if ($problemRecords[$_]->status > $maxStatus) {
					$maxRecord = $_;
					$maxStatus = $problemRecords[$_]->status;
				}
			}
			$studentProblem = $problemRecords[$maxRecord];
		} else {
			$studentProblem = $db->getMergedProblem($student, $c->stash('setID'), $problemID);
		}
		# Don't include students who are not assigned to set.
		next unless ($studentProblem);

		# It is possible that $problemRecord->num_correct or $problemRecord->num_correct is an empty or blank string
		# instead of 0.  The || clause fixes this and prevents warning messages in the usage below.
		my $numAttempts = ($studentProblem->num_correct || 0) + ($studentProblem->num_incorrect || 0);

		# It is also possible that $problemRecord->status is an empty or blank string instead of 0.
		my $status = $studentProblem->status || 0;

		# Clamp the status value between 0 and 1.
		$status = 0 if $status < 0;
		$status = 1 if $status > 1;

		# Compute adjusted scores for jitar sets.
		my $adjustedStatus = $isJitarSet ? jitar_problem_adjusted_status($studentProblem, $db) : '';

		# Clamp the adjusted status value between 0 and 1.
		$adjustedStatus = 0 if $adjustedStatus ne '' && $adjustedStatus < 0;
		$adjustedStatus = 1 if $adjustedStatus ne '' && $adjustedStatus > 1;

		if ($numAttempts) {
			$activeStudents++;
			push(@problemScores,   $status);
			push(@adjustedScores,  $adjustedStatus) if ($isJitarSet && $topLevelJitar);
			push(@problemAttempts, $numAttempts);
			push(@successList,     $numAttempts ? $status**2 / $numAttempts : 0);
		} else {
			$inactiveStudents++;
		}
	}

	# Data for the histogram of total scores.
	my @buckets = map {0} 1 .. 10;
	for (@problemScores) { $buckets[ $_ > 0.995 ? 9 : int(10 * $_ + 0.05) ]++ }
	my $maxCount = 0;
	for (@buckets) { $maxCount = $_ if $_ > $maxCount; }
	@buckets = reverse(@buckets);
	my @jitarBars;
	if ($isJitarSet && $topLevelJitar) {
		@jitarBars = map {0} 1 .. 10;
		for (@adjustedScores) { $jitarBars[ $_ > 0.995 ? 9 : int(10 * $_ + 0.05) ]++ }
		for (@jitarBars)      { $maxCount = $_ if $_ > $maxCount; }
	}
	@jitarBars = reverse(@jitarBars);
	$maxCount  = int($maxCount / 5) + 1;

	# Overall statistics
	my ($mean,  $stddev)  = $c->compute_stats(@problemScores);
	my ($mean2, $stddev2) = $c->compute_stats(@problemAttempts);
	my $successIndex = $mean2 ? $mean**2 / $mean2 : 0;

	return $c->include(
		'ContentGenerator/Instructor/Stats/problem_stats',
		filters          => $filters,
		problemID        => $problemID,
		problems         => [ $db->getGlobalProblemsWhere({ set_id => $c->stash('setID') }, 'problem_id') ],
		buckets          => \@buckets,
		maxCount         => $maxCount,
		isJitarSet       => $isJitarSet,
		topLevelJitar    => $topLevelJitar,
		jitarBars        => \@jitarBars,
		mean             => $mean,
		stddev           => $stddev,
		mean2            => $mean2,
		successIndex     => $successIndex,
		activeStudents   => $activeStudents,
		inactiveStudents => $inactiveStudents,
		problemScores    => [ map { sprintf('%0.0f', 100 * $_) } @problemScores ],
		adjustedScores   => [ map { sprintf('%0.0f', 100 * $_) } @adjustedScores ],
		successList      => \@successList,
		problemAttempts  => \@problemAttempts
	);
}

# Determines the percentage of students whose score is greater than a given value.
sub determine_percentiles ($c, $percent_brackets, @data) {
	my @list_of_scores = sort { $a <=> $b } @data;
	my $num_students   = $#list_of_scores;
	# For example, $percentiles{75} = @list_of_scores[int(25 * $num_students / 100)]
	# means that 75% of the students received this score $percentiles{75} or higher.
	my %percentiles = map { $_ => @list_of_scores[ int((100 - $_) * $num_students / 100) ] // 0 } @$percent_brackets;
	$percentiles{max} = $list_of_scores[-1];
	$percentiles{min} = $list_of_scores[0];
	return %percentiles;
}

# Replace an array such as "[0, 0, 0, 86, 86, 100, 100, 100]" by "[0, '-', '-', 86, '-', 100, '-', '-']"
sub prevent_repeats ($c, @inarray) {
	my @outarray;
	my $saved_item = shift @inarray;
	push @outarray, $saved_item;
	while (@inarray) {
		my $current_item = shift @inarray;
		if ($current_item == $saved_item) {
			push @outarray, '-';
		} else {
			push @outarray, $current_item;
			$saved_item = $current_item;
		}
	}
	return @outarray;
}

# Create percentile bracket table.
sub bracket_table ($c, $brackets, $data, $headers, %options) {
	my @dataOut = ([@$brackets]);
	push(@{ $dataOut[-1] }, $c->maketext('Top Score')) if $options{showMax};

	for (@$data) {
		my %percentiles =
			ref($_) eq 'ARRAY' ? $c->determine_percentiles($brackets, @$_) : map { $_ => '-' } @$brackets;
		my @tableData = map { $percentiles{$_} } @$brackets;
		@tableData = reverse(@tableData)             if $options{reverse};
		@tableData = $c->prevent_repeats(@tableData) if ref($_) eq 'ARRAY';
		push(@tableData, $options{reverse} ? $percentiles{min} : $percentiles{max}) if $options{showMax};
		push(@dataOut, \@tableData);
	}
	return $c->include(
		'ContentGenerator/Instructor/Stats/stats_table',
		tableHeaders => [ $c->maketext('Percent of Students'), @$headers ],
		tableData    => \@dataOut
	);
}

# Compute Mean / Std Deviation.
sub compute_stats ($c, @data) {
	my $n = scalar(@data);
	return (0, 0, 0) unless ($n > 0);
	my $sum = 0;
	for (@data) { $sum += $_; }
	my $mean = sprintf('%0.4g', $sum / $n);
	my $sum2 = 0;
	for (@data) { $sum2 += ($_ - $mean)**2; }
	my $stddev = ($n > 1) ? sqrt($sum2 / ($n - 1)) : 0;
	return ($mean, $stddev, $sum);
}

# Create SVG bar graph from input data.
sub build_bar_chart ($c, $data, %options) {
	return '' unless (@$data);
	$c->{barCount} = 1 unless $c->{barCount};
	my $id   = $c->{barCount}++;
	my %opts = (
		yAxisLabels  => [],
		xAxisLabels  => [],
		yAxisTicks   => 9,
		yMax         => 1,
		isPercent    => 1,
		isJitarSet   => 0,
		jitarBars    => [],
		barLinks     => [],
		mainTitle    => 'ERROR: This must be set',
		xTitle       => '',
		yTitle       => '',
		barWidth     => 22,
		barSep       => 4,
		barFill      => 'rgb(0,153,198)',
		jitarFill    => 'rgb(0,51,136)',
		topMargin    => 30,
		rightMargin  => 20,
		bottomMargin => 45,
		leftMargin   => 40,
		minWidth     => 450,
		plotHeight   => 200,
		%options
	);
	$opts{rightMargin} += 160 if $opts{isJitarSet};

	my $n;
	# Image size calculations.
	my $barWidth  = $opts{barWidth} + 2 * $opts{barSep};
	my $plotWidth = scalar(@$data) * $barWidth;
	$plotWidth = $opts{minWidth} if ($plotWidth < $opts{minWidth});
	my $imageWidth  = $opts{leftMargin} + $plotWidth + $opts{rightMargin};
	my $imageHeight = $opts{topMargin} + $opts{plotHeight} + $opts{bottomMargin};

	# Create SVG image output.
	my $svg = SVG->new(
		-inline           => 1,
		id                => "bar_graph_$id",
		height            => '100%',
		width             => '100%',
		viewbox           => '-2 -2 ' . ($imageWidth + 3) . ' ' . ($imageHeight + 3),
		'aria-labelledby' => "bar_graph_title_$id",
		role              => 'img',
		-nocredits        => 1
	);

	# Main graph setup.
	$svg->rect(
		id               => "bar_graph_window_$id",
		x                => 0,
		y                => 0,
		width            => $imageWidth,
		height           => $imageHeight,
		rx               => 20,
		ry               => 20,
		fill             => 'white',
		'fill-opacity'   => 0,
		stroke           => '#888',
		'stroke-width'   => 1,
		'stroke-opacity' => 1,
	);
	$svg->text(
		id            => "bar_graph_title_$id",
		x             => $opts{leftMargin} + int($plotWidth / 2),
		y             => $opts{topMargin} / 2,
		'font-family' => 'sans-serif',
		'font-size'   => 14,
		fill          => 'black',
		'text-anchor' => 'middle',
		'font-weight' => 'bold',
	)->cdata($opts{mainTitle});
	$svg->text(
		id            => "bar_graph_xaxis_label_$id",
		x             => $opts{leftMargin} + int($plotWidth / 2),
		y             => $imageHeight - 10,
		'font-family' => 'sans-serif',
		'font-size'   => 14,
		fill          => 'black',
		'text-anchor' => 'middle',
	)->cdata($opts{xTitle})
		if ($opts{xTitle});
	$svg->text(
		id            => "bar_graph_yaxis_label_$id",
		x             => 20,
		y             => $opts{topMargin} + int($opts{plotHeight} / 2),
		transform     => 'rotate(-90, 20, ' . ($opts{topMargin} + int($opts{plotHeight} / 2)) . ')',
		'font-family' => 'sans-serif',
		'font-size'   => 14,
		'text-anchor' => 'middle',
	)->cdata($opts{yTitle})
		if $opts{yTitle};
	$svg->rect(
		id               => "bar_graph_plot_window_$id",
		x                => $opts{leftMargin},
		y                => $opts{topMargin},
		width            => $plotWidth,
		height           => $opts{plotHeight},
		fill             => 'white',
		'fill-opacity'   => 0,
		stroke           => '#888',
		'stroke-width'   => 1,
		'stroke-opacity' => 1,
	);

	# Jitar Legend.
	if ($opts{isJitarSet}) {
		$svg->rect(
			x      => $opts{leftMargin} + $plotWidth + 10,
			y      => $opts{topMargin} + 20,
			width  => 10,
			height => 10,
			stroke => $opts{jitarFill},
			fill   => $opts{jitarFill},
		);
		$svg->text(
			x             => $opts{leftMargin} + $plotWidth + 25,
			y             => $opts{topMargin} + 30,
			'font-family' => 'sans-serif',
			'font-size'   => 12,
			'text-anchor' => 'start',
		)->cdata($c->maketext('Correct Adjusted Status'));
		$svg->rect(
			x      => $opts{leftMargin} + $plotWidth + 10,
			y      => $opts{topMargin} + 40,
			width  => 10,
			height => 10,
			stroke => $opts{barFill},
			fill   => $opts{barFill},
		);
		$svg->text(
			x             => $opts{leftMargin} + $plotWidth + 25,
			y             => $opts{topMargin} + 50,
			'font-family' => 'sans-serif',
			'font-size'   => 12,
			'text-anchor' => 'start',
		)->cdata($c->maketext('Correct Status'));
	}

	# y-axis labels.
	$n = scalar(@{ $opts{yAxisLabels} }) - 1;
	my $yOffset = int($opts{plotHeight} / (10 * $n));
	for (0 .. $n) {
		my $yPos = $opts{topMargin} + ($n - $_) * int($opts{plotHeight} / $n) + $yOffset;
		$svg->text(
			x             => $opts{leftMargin} - 5,
			y             => $yPos,
			'font-family' => 'sans-serif',
			'font-size'   => 14,
			'text-anchor' => 'end',
			'font-size'   => 12,
		)->cdata($opts{yAxisLabels}->[$_]);
	}

	# y-axis ticks.
	$n = $opts{yAxisTicks} + 1;
	for (1 .. $opts{yAxisTicks}) {
		my $yPos = $opts{topMargin} + $_ * int($opts{plotHeight} / $n);
		$svg->line(
			x1               => $opts{leftMargin},
			y1               => $yPos,
			x2               => $imageWidth - $opts{rightMargin},
			y2               => $yPos,
			stroke           => '#888',
			'stroke-width'   => 1,
			'stroke-opacity' => 1,
		);
	}

	# Bars.
	$n = scalar(@$data) - 1;
	for (0 .. $n) {
		my $xPos    = $opts{leftMargin} + $_ * $barWidth + $opts{barSep};
		my $yHeight = int($opts{plotHeight} * $data->[$_] / $opts{yMax} + 0.5);
		if ($opts{isJitarSet} && $opts{jitarBars}->[$_] > 0) {
			my $jHeight = int($opts{plotHeight} * $opts{jitarBars}->[$_] / $opts{yMax} + 0.5);
			$svg->rect(
				x                => $xPos,
				y                => $opts{topMargin} + $opts{plotHeight} - $jHeight,
				width            => $opts{barWidth} + $opts{barSep},
				height           => $jHeight,
				fill             => $opts{jitarFill},
				'data-bs-toggle' => 'tooltip',
				'data-bs-title'  => $opts{isPercent} ? (100 * $opts{jitarBars}->[$_]) . '%' : $opts{jitarBars}->[$_],
				class            => 'bar_graph_bar',
			);
		}
		my $tag = @{ $opts{barLinks} } ? $svg->anchor(-href => $opts{barLinks}->[$_]) : $svg;
		$tag->rect(
			x                => $xPos,
			y                => $opts{topMargin} + $opts{plotHeight} - $yHeight,
			width            => $opts{barWidth},
			height           => $yHeight,
			fill             => $opts{barFill},
			'data-bs-toggle' => 'tooltip',
			'data-bs-title'  => $opts{isPercent} ? (100 * $data->[$_]) . '%' : $data->[$_],
			class            => 'bar_graph_bar',
		);
		$tag->text(
			x             => $xPos + $opts{barWidth} / 2,
			y             => $imageHeight - $opts{bottomMargin} + 15,
			'font-family' => 'sans-serif',
			'text-anchor' => 'middle',
			'font-size'   => 12,
		)->cdata($opts{xAxisLabels}->[$_]);
	}

	# FIXME:  The invalid html attribute xmlns:svg needs to be removed. The SVG module needs to be fixed to not
	# add this invalid attribute when rendering for html.
	return $c->tag(
		'div',
		class => 'img-fluid mb-3',
		style => "max-width: ${imageWidth}px",
		$c->b($svg->render =~ s/xmlns:svg="[^"]*"//r)
	);
}

1;
