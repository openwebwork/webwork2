package WeBWorK::ContentGenerator::Instructor::StudentProgress;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::StudentProgress - Display Student Progress.

=cut

use WeBWorK::Utils                qw(wwRound);
use WeBWorK::Utils::FilterRecords qw(getFiltersForClass filterRecords);
use WeBWorK::Utils::JITAR         qw(jitar_id_to_seq);
use WeBWorK::Utils::Sets          qw(grade_set list_set_versions format_set_name_display);

sub initialize ($c) {
	my $db   = $c->db;
	my $ce   = $c->ce;
	my $user = $c->param('user');

	# Check permissions
	return unless $c->authz->hasPermissions($user, "access_instructor_tools");

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

	if ($c->current_route eq 'instructor_user_progress') {
		$c->{studentID} = $c->stash('userID');
	} elsif ($c->current_route eq 'instructor_set_progress') {
		my $setRecord = $db->getGlobalSet($c->stash('setID'));
		return unless $setRecord;
		$c->{setRecord} = $setRecord;
	}

	return;
}

sub page_title ($c) {
	return '' unless $c->authz->hasPermissions($c->param('user'), 'access_instructor_tools');

	if ($c->current_route eq 'instructor_user_progress') {
		return $c->maketext('Student Progress for [_1]', $c->{studentID});
	} elsif ($c->current_route eq 'instructor_set_progress') {
		return $c->maketext(
			'Student Progress for set [_1]',
			$c->tag('span', dir => 'ltr', format_set_name_display($c->stash('setID'))),
		);
	}

	return $c->maketext('Student Progress');
}

sub siblings ($c) {
	# Stats and StudentProgress share this template.
	return $c->include('ContentGenerator/Instructor/Stats/siblings', header => $c->maketext('Student Progress'));
}

# Display student progress table
sub displaySets ($c) {
	my $db = $c->db;
	my $ce = $c->ce;

	my $setIsVersioned = defined $c->{setRecord}->assignment_type && $c->{setRecord}->assignment_type =~ /gateway/;

	# The returning parameter lets us set defaults for versioned sets
	if ($setIsVersioned && !$c->param('returning')) {
		$c->param('show_date',     1) if !$c->param('show_date');
		$c->param('show_testtime', 1) if !$c->param('show_testtime');
	}

	# For versioned sets some of the columns are optionally shown.  The following flags keep track of which ones to
	# show.  An additional variable keeps track of whether to show all scores or only the best score.  The defaults set
	# here used to determine headers for non-versioned sets.

	my %showColumns = $setIsVersioned
		? (
			date     => $c->param('show_date')       // 0,
			testtime => $c->param('show_testtime')   // 0,
			timeleft => $c->param('show_timeleft')   // 0,
			problems => $c->param('show_problems')   // 0,
			section  => $c->param('show_section')    // 0,
			recit    => $c->param('show_recitation') // 0,
			login    => $c->param('show_login')      // 0,
		)
		: (date => 0, testtime => 0, timeleft => 0, problems => 1, section => 1, recit => 1, login => 1);
	my $showBestOnly = $setIsVersioned ? $c->param('show_best_only') : 0;

	# Only show students who are included in stats.
	my @student_records =
		grep { $ce->status_abbrev_has_behavior($_->status, 'include_in_stats') } @{ $c->{student_records} };

	# Change visible name of the first 'all' filter.
	my $filter  = $c->param('filter') || 'all';
	my $filters = getFiltersForClass($c, [ 'section', 'recitation' ], @student_records);
	$filters->[0][0] = $c->maketext('All students');

	@student_records = filterRecords($c, 0, [$filter], @student_records) unless $filter eq 'all';

	my @score_list;
	my @user_set_list;

	for my $studentRecord (@student_records) {
		my $studentName = $studentRecord->user_id;
		my ($allSetVersionNames, $notAssignedSet) =
			list_set_versions($db, $studentName, $c->stash('setID'), $setIsVersioned);

		next if $notAssignedSet;

		my $max_version_data = {};

		for my $setName (@$allSetVersionNames) {
			my $set;
			my $vNum = 0;

			# For versioned tests we might be displaying the test date and test time.
			my $dateOfTest = '';
			my $testTime   = '';
			my $timeLeft   = '';

			if ($setIsVersioned) {
				($setName, $vNum) = ($setName =~ /(.+),v(\d+)$/);
				# Information from the set is needed to set up the display below. So get the merged user set as well.
				$set        = $db->getMergedSetVersion($studentRecord->user_id, $setName, $vNum);
				$dateOfTest = localtime($set->version_creation_time());
				if ($set->version_last_attempt_time) {
					$testTime = ($set->version_last_attempt_time - $set->open_date) / 60;
					my $timeLimit = $set->version_time_limit / 60;
					$testTime = $timeLimit if ($testTime > $timeLimit);
					$testTime = $c->maketext("[quant,_1,minute]", sprintf('%3.1f', $testTime));
					$timeLeft = 0;
					if ($showColumns{timeleft} && time - $set->open_date < $set->version_time_limit) {
						# Get a problem to determine how many submits have been made.
						my @ProblemNums = $db->listUserProblems($studentRecord->user_id, $setName);
						my $Problem =
							$db->getMergedProblemVersion($studentRecord->user_id, $setName, $vNum, $ProblemNums[0]);
						my $verSubmits = defined $Problem ? $Problem->num_correct + $Problem->num_incorrect : 0;
						$timeLeft = sprintf('%3.1f', ($set->version_time_limit - time + $set->open_date) / 60)
							if ($set->attempts_per_version == 0 || $verSubmits < $set->attempts_per_version);
					}
				} elsif (time - $set->open_date < $set->version_time_limit) {
					$testTime = $c->maketext('still open');
					$timeLeft = sprintf('%3.1f', ($set->version_time_limit - time + $set->open_date) / 60);
				} else {
					$testTime = $c->maketext('time limit exceeded');
					$timeLeft = 0;
				}
				$timeLeft = $c->maketext('[quant,_1,minute]', $timeLeft);
			} else {
				$set = $db->getMergedSet($studentName, $setName);
			}

			my ($score, $total, $problem_scores, $problem_incorrect_attempts) =
				grade_set($db, $set, $studentName, $setIsVersioned, 1);
			$score = wwRound(2, $score);

			my $version_data = {
				version                    => $vNum,
				score                      => $score,
				total                      => $total,
				date                       => $dateOfTest,
				testtime                   => $testTime,
				timeleft                   => $timeLeft,
				problem_scores             => $problem_scores,
				problem_incorrect_attempts => $problem_incorrect_attempts
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
					score              =>  0,
					total              => -1,
					date               => '',
					testtime           => '',
					timeleft           => '',
					problem_scores     => [],
					incorrect_attempts => [],
					%$max_version_data
				}
			);
		}
	}

	my $primary_sort_method   = $c->param('primary_sort');
	my $secondary_sort_method = $c->param('secondary_sort');
	my $ternary_sort_method   = $c->param('ternary_sort');

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
	my @problems = map { $_->[1] } $db->listGlobalProblemsWhere({ set_id => $c->stash('setID') }, 'problem_id');
	@problems = ($c->maketext('None')) unless @problems;

	# For a jitar set we only get the top level problems
	if ($c->{setRecord}->assignment_type eq 'jitar') {
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
	$numCols++                    if $showColumns{timeleft};
	$numCols += scalar(@problems) if $showColumns{problems};

	return $c->include(
		'ContentGenerator/Instructor/StudentProgress/set_progress',
		setIsVersioned        => $setIsVersioned,
		showColumns           => \%showColumns,
		showBestOnly          => $showBestOnly,
		numCols               => $numCols,
		primary_sort_method   => $primary_sort_method,
		secondary_sort_method => $secondary_sort_method,
		ternary_sort_method   => $ternary_sort_method,
		problems              => \@problems,
		user_set_list         => \@user_set_list,
		filters               => $filters,
		filter                => $filter,
	);
}

1;
