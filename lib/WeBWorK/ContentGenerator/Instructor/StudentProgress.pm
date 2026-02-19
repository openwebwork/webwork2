package WeBWorK::ContentGenerator::Instructor::StudentProgress;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::StudentProgress - Display Student Progress.

=cut

use WeBWorK::Utils                    qw(wwRound);
use WeBWorK::Utils::DateTime          qw(after);
use WeBWorK::Utils::FilterRecords     qw(getFiltersForClass filterRecords);
use WeBWorK::Utils::JITAR             qw(jitar_id_to_seq);
use WeBWorK::Utils::Sets              qw(grade_set list_set_versions format_set_name_display);
use WeBWorK::Utils::ProblemProcessing qw(compute_unreduced_score);

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
	return $c->include('ContentGenerator/Instructor/StudentProgress/siblings');
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

sub displayStudentStats ($c) {
	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;

	my $studentID     = $c->{studentID};
	my $studentRecord = $db->getUser($studentID);
	unless ($studentRecord) {
		$c->addbadmessage($c->maketext('Record for user [_1] not found.', $studentID));
		return '';
	}

	my $courseName = $ce->{courseName};

	# First get all merged sets for this user ordered by set_id.
	my @sets = $db->getMergedSetsWhere({ user_id => $studentID }, 'set_id');
	# To be able to find the set objects later, make a handy hash of set ids to set objects.
	my %setsByID = (map { $_->set_id => $_ } @sets);

	# Before going through the table generating loop, find all the set versions for the sets in our list.
	my %setVersionsCount;
	my @allSetIDs;
	for my $set (@sets) {
		# Don't show hidden sets unless user has appropriate permissions.
		next unless ($set->visible || $authz->hasPermissions($c->param('user'), 'view_hidden_sets'));

		my $setID = $set->set_id();

		# FIXME: Here, as in many other locations, we assume that there is a one-to-one matching between versioned sets
		# and gateways.  We really should have two flags, $set->assignment_type and $set->versioned.  I'm not adding
		# that yet, however, so this will continue to use assignment_type.
		if (defined $set->assignment_type && $set->assignment_type =~ /gateway/) {
			# We have to have the merged set versions to know what each of their assignment types are
			# (because proctoring can change this).
			my @setVersions =
				$db->getMergedSetVersionsWhere({ user_id => $studentID, set_id => { like => "$setID,v\%" } });

			# Add the set versions to our list of sets.
			$setsByID{ $_->set_id . ',v' . $_->version_id } = $_ for (@setVersions);

			# Flag the existence of set versions for this set.
			$setVersionsCount{$setID} = scalar @setVersions;

			# Save the set names for display.
			push(@allSetIDs, $setID);
			push(@allSetIDs, map { $_->set_id . ',v' . $_->version_id } @setVersions);

		} else {
			push(@allSetIDs, $setID);
		}
	}

	my $fullName      = join(' ', $studentRecord->first_name, $studentRecord->last_name);
	my $effectiveUser = $studentRecord->user_id();

	my $max_problems     = 0;
	my $courseTotal      = 0;
	my $courseTotalRight = 0;

	for my $setID (@allSetIDs) {
		my $set = $db->getGlobalSet($setID);
		my $num_of_problems;
		# For jitar sets we only display grades for top level problems, so we need to count how many there are.
		if ($set && $set->assignment_type() eq 'jitar') {
			my @problemIDs = $db->listGlobalProblems($setID);
			for my $problemID (@problemIDs) {
				my @seq = jitar_id_to_seq($problemID);
				$num_of_problems++ if ($#seq == 0);
			}
		} else {
			# For other sets we just count the number of problems.
			$num_of_problems = $db->countGlobalProblems($setID);
		}
		$max_problems =
			$set && after($set->open_date) && $max_problems < $num_of_problems ? $num_of_problems : $max_problems;
	}

	# Variables to help compute gateway scores.
	my $numGatewayVersions = 0;
	my $bestGatewayScore   = 0;

	my $rows = $c->c;
	for my $setID (@allSetIDs) {
		my $act_as_student_set_url =
			$c->systemLink($c->url_for('problem_list', setID => $setID), params => { effectiveUser => $effectiveUser });
		my $set = $setsByID{$setID};

		# Determine if set is a test and create the test url.
		my $setIsVersioned          = 0;
		my $act_as_student_test_url = '';
		if (defined $set->assignment_type && $set->assignment_type =~ /gateway/) {
			$setIsVersioned = 1;
			if ($set->assignment_type eq 'proctored_gateway') {
				$act_as_student_test_url = $act_as_student_set_url =~ s/($courseName)\//$1\/proctored_test_mode\//r;
			} else {
				$act_as_student_test_url = $act_as_student_set_url =~ s/($courseName)\//$1\/test_mode\//r;
			}
			# Remove version from set url
			$act_as_student_set_url =~ s/,v\d+//;
		}

		# Format set name based on set visibility.
		my $setName = $c->tag(
			'span',
			class => $set->visible ? 'font-visible' : 'font-hidden',
			format_set_name_display($setID =~ s/,v\d+$//r)
		);

		# If the set is a template gateway set and there are no versions, we acknowledge that the set exists and the
		# student hasn't attempted it. Otherwise, we skip it and let the versions speak for themselves.
		if (defined $setVersionsCount{$setID}) {
			next if $setVersionsCount{$setID};
			push @$rows,
				$c->tag(
					'tr',
					$c->c(
						$c->tag(
							'th',
							dir => 'ltr',
							(after($set->open_date) || $authz->hasPermissions($c->param('user'), 'view_unopened_sets'))
							? $c->link_to($setName => $act_as_student_set_url)
							: $setName
						),
						$c->tag(
							'td',
							colspan => $max_problems + 3,
							$c->tag(
								'em',
								after($set->open_date) ? $c->maketext('No versions of this test have been taken.')
								: $c->maketext(
									'Will open on [_1].',
									$c->formatDateTime($set->open_date, $ce->{studentDateDisplayFormat})
								)
							)
						)
				)->join('')
				);
			next;
		}

		# If the set has hide_score set, then we need to skip printing the score as well.
		if (
			defined $set->assignment_type
			&& $set->assignment_type =~ /gateway/
			&& defined $set->hide_score
			&& (
				!$authz->hasPermissions($c->param('user'), 'view_hidden_work')
				&& ($set->hide_score eq 'Y' || ($set->hide_score eq 'BeforeAnswerDate' && time < $set->answer_date))
			)
			)
		{
			# Add a link to the test version if the problems can be seen.
			my $thisSetName =
				$c->link_to($setName => $act_as_student_set_url) . ' ('
				. (
					(
						$set->hide_work eq 'N'
						|| ($set->hide_work eq 'BeforeAnswerDate' && time >= $set->answer_date)
						|| $authz->hasPermissions($c->param('user'), 'view_unopened_sets')
					)
					? $c->link_to($c->maketext('version [_1]', $set->version_id) => $act_as_student_test_url)
					: $c->maketext('version [_1]', $set->version_id)
				) . ')';
			push(
				@$rows,
				$c->tag(
					'tr',
					$c->c(
						$c->tag(
							'th',
							dir => 'ltr',
							sub {$thisSetName}
						),
						$c->tag(
							'td',
							colspan => $max_problems + 3,
							$c->tag('em', $c->maketext('Display of scores for this test is not allowed.'))
						)
					)->join('')
				)
			);
			next;
		}

		my ($totalRight, $total, $problem_scores, $problem_incorrect_attempts, $problem_records) =
			grade_set($db, $set, $studentID, $setIsVersioned, 1);
		$totalRight = wwRound(2, $totalRight);

		my @html_prob_scores;

		my $show_problem_scores = 1;

		if (defined $set->hide_score_by_problem
			&& !$authz->hasPermissions($c->param('user'), 'view_hidden_work')
			&& $set->hide_score_by_problem eq 'Y')
		{
			$show_problem_scores = 0;
		}

		for my $i (0 .. $max_problems - 1) {
			my $score      = defined $problem_scores->[$i] && $show_problem_scores ? $problem_scores->[$i] : '';
			my $is_correct = $score =~ /^\d+$/ && compute_unreduced_score($ce, $problem_records->[$i], $set) == 1;
			push(
				@html_prob_scores,
				$c->tag(
					'td',
					class => 'problem-data',
					$c->c(
						$c->tag(
							'span',
							class => $is_correct ? 'correct' : $score eq '&nbsp;.&nbsp;' ? 'unattempted' : '',
							$c->b($score)
						),
						$c->tag('br'),
						(defined $problem_incorrect_attempts->[$i] && $show_problem_scores)
						? $problem_incorrect_attempts->[$i]
						: $c->b('&nbsp;')
					)->join('')
				)
			);
		}

		# Get percentage correct.
		my $totalRightPercent = 100 * wwRound(2, $total ? $totalRight / $total : 0);
		my $class             = '';
		if ($totalRightPercent == 0) {
			$class = 'unattempted';
		} elsif ($totalRightPercent == 100) {
			$class = 'correct';
		}

		# If its a gateway set, then in order to mimic the scoring done in Scoring Tools we need to use the best score a
		# student had.  Otherwise we just add the set to the running course total.
		if ($setIsVersioned) {
			$setID =~ /(.+),v(\d+)$/;
			my $gatewayName    = $1;
			my $currentVersion = $2;

			# If we are just starting a new gateway then set variables to look for the max.
			if ($currentVersion == 1) {
				$numGatewayVersions = $db->countSetVersions($studentID, $gatewayName);
			}

			if ($totalRight > $bestGatewayScore) {
				$bestGatewayScore = $totalRight;
			}

			# If its the last version then add the max to the course totals and reset variables;
			if ($currentVersion == $numGatewayVersions) {
				if (after($set->open_date())) {
					$courseTotal      += $total;
					$courseTotalRight += $bestGatewayScore;
				}
				$bestGatewayScore = 0;
			}
		} else {
			if (after($set->open_date())) {
				$courseTotal      += $total;
				$courseTotalRight += $totalRight;
			}
		}

		# Only show scores for open sets, and don't link to non open sets.
		if (after($set->open_date) || $authz->hasPermissions($c->param('user'), 'view_unopened_sets')) {
			# Set the set name and link. If a test, don't link to the version unless the problems can be seen.
			my $thisSetName = $setIsVersioned
				? $c->link_to($setName => $act_as_student_set_url) . ' ('
				. (
					(
						$set->hide_work eq 'N'
						|| ($set->hide_work eq 'BeforeAnswerDate' && time >= $set->answer_date)
						|| $authz->hasPermissions($c->param('user'), 'view_unopened_sets')
					)
					? $c->link_to($c->maketext('version [_1]', $set->version_id) => $act_as_student_test_url)
					: $c->maketext('version [_1]', $set->version_id)
				)
				. ')'
				: $c->link_to($setName => $act_as_student_set_url);
			push @$rows, $c->tag(
				'tr',
				$c->c(
					$c->tag(
						'th',
						scope => 'row',
						dir   => 'ltr',
						sub {$thisSetName}
					),
					$c->tag('td', $c->tag('span', class => $class, $totalRightPercent . '%')),
					$c->tag('td', sprintf('%0.2f', $totalRight)),                                # score
					$c->tag('td', $total),                                                       # out of
					@html_prob_scores                                                            # problems
				)->join('')
			);
		} else {
			push @$rows,
				$c->tag(
					'tr',
					$c->c(
						$c->tag(
							'th',
							dir => 'ltr',
							$setName
						),
						$c->tag(
							'td',
							colspan => $max_problems + 3,
							$c->tag(
								'em',
								$c->maketext(
									'Will open on [_1].',
									$c->formatDateTime($set->open_date, $ce->{studentDateDisplayFormat})
								)
							)
						)
				)->join('')
				);
		}
	}

	return $c->include(
		'ContentGenerator/Instructor/StudentProgress/student_stats',
		fullName         => $fullName,
		max_problems     => $max_problems,
		rows             => $rows->join(''),
		courseTotal      => $courseTotal,
		courseTotalRight => $courseTotalRight
	);
}

1;
