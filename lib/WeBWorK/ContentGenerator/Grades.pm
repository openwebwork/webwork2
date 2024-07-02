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

package WeBWorK::ContentGenerator::Grades;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Grades - Display statistics by user.

=cut

use WeBWorK::Utils qw(wwRound);
use WeBWorK::Utils::DateTime qw(after);
use WeBWorK::Utils::JITAR qw(jitar_id_to_seq);
use WeBWorK::Utils::Sets qw(grade_set format_set_name_display);
use WeBWorK::Localize;

sub initialize ($c) {
	$c->{studentID} = $c->param('effectiveUser') // $c->param('user');
	return;
}

sub scoring_info ($c) {
	my $db = $c->db;
	my $ce = $c->ce;

	my $user = $db->getUser($c->{studentID});
	return '' unless $user;

	my $message_file = 'report_grades.msg';
	my $filePath     = "$ce->{courseDirs}{email}/$message_file";
	my $merge_file   = "report_grades_data.csv";

	# Return if the files don't exist.
	if (!(-e "$ce->{courseDirs}{scoring}/$merge_file" && -e "$filePath")) {
		if ($c->authz->hasPermissions($c->param('user'), 'access_instructor_tools')) {
			return $c->maketext(
				'There is no additional grade information.  A message about additional grades can go in '
					. '~[TMPL~]/email/[_1]. It is merged with the file ~[Scoring~]/[_2]. These files can be '
					. 'edited using the "Email" link and the "File Manager" link in the left margin.',
				$message_file, $merge_file
			);
		} else {
			return '';
		}
	}

	my $rh_merge_data = $c->read_scoring_file($merge_file);
	my $text;
	my $header = '';
	if (-e $filePath and -r $filePath) {
		open my $FILE, '<:encoding(UTF-8)', $filePath or return "Can't open $filePath";
		while ($header !~ s/Message:\s*$//m && !eof($FILE)) {
			$header .= <$FILE>;
		}
		$text = join('', <$FILE>);
		close($FILE);
	} else {
		return r->c('There is no additional grade information.',
			$c->tag('br'), "The message file $filePath cannot be found.")->join('');
	}

	my $status_name = $ce->status_abbrev_to_name($user->status);
	$status_name = $user->status unless defined $status_name;

	my $SID        = $user->student_id;
	my $FN         = $user->first_name;
	my $LN         = $user->last_name;
	my $SECTION    = $user->section;
	my $RECITATION = $user->recitation;
	my $STATUS     = $status_name;
	my $EMAIL      = $user->email_address;
	my $LOGIN      = $user->user_id;
	my @COL        = ref $rh_merge_data->{$SID} eq 'ARRAY' ? @{ $rh_merge_data->{$SID} } : ();
	unshift(@COL, '');    # This makes COL[1] the first column

	my $endCol = @COL;
	# For safety, only evaluate special variables.
	my $msg = $text;
	$msg =~ s/(\$PAR)/<p>/g;
	$msg =~ s/(\$BR)/<br>/g;

	$msg =~ s/\$SID/$SID/g;
	$msg =~ s/\$LN/$LN/g;
	$msg =~ s/\$FN/$FN/g;
	$msg =~ s/\$STATUS/$STATUS/g;
	$msg =~ s/\$SECTION/$SECTION/g;
	$msg =~ s/\$RECITATION/$RECITATION/g;
	$msg =~ s/\$EMAIL/$EMAIL/g;
	$msg =~ s/\$LOGIN/$LOGIN/g;

	if (defined $COL[1]) {
		$msg =~ s/\$COL\[(\-?\d+)\]/$COL[$1]/g;
	} else {
		# Prevents extraneous $COL's in email message
		$msg =~ s/\$COL\[(\-?\d+)\]//g;
	}

	$msg =~ s/\r//g;
	$msg =~ s/\n/<br>/g;

	my $output = $c->c($c->tag(
		'div',
		class => 'additional-scoring-msg card bg-light p-2',
		$c->c($c->tag('h3', $c->maketext('Scoring Message')), $msg)->join('')
	));

	push(
		@$output,
		$c->tag(
			'div',
			class => 'mt-2',
			$c->maketext(
				'This scoring message is generated from ~[TMPL~]/email/[_1]. It is merged with the file '
					. '~[Scoring~]/[_2]. These files can be edited using the "Email" link and the "File Manager" '
					. 'link in the left margin.',
				$message_file,
				$merge_file
			)
		)
	) if $c->authz->hasPermissions($c->param('user'), 'access_instructor_tools');

	return $output->join('');
}

sub displayStudentStats ($c, $studentID) {
	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;

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

		my ($totalRight, $total, $problem_scores, $problem_incorrect_attempts) =
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

		for (my $i = 0; $i < $max_problems; ++$i) {
			my $score = defined $problem_scores->[$i] && $show_problem_scores ? $problem_scores->[$i] : '';
			push(
				@html_prob_scores,
				$c->tag(
					'td',
					class => 'problem-data',
					$c->c(
						$c->tag(
							'span',
							class => $score eq '100' ? 'correct' : $score eq '&nbsp;.&nbsp;' ? 'unattempted' : '',
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
		'ContentGenerator/Grades/student_stats',
		fullName         => $fullName,
		max_problems     => $max_problems,
		rows             => $rows->join(''),
		courseTotal      => $courseTotal,
		courseTotalRight => $courseTotalRight
	);
}

1;
