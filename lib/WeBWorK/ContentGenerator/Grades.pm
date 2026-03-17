package WeBWorK::ContentGenerator::Grades;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Grades - Display statistics by user.

=cut

use WeBWorK::Utils                    qw(wwRound);
use WeBWorK::Utils::DateTime          qw(before);
use WeBWorK::Utils::JITAR             qw(jitar_id_to_seq);
use WeBWorK::Utils::Sets              qw(grade_set format_set_name_display restricted_set_message);
use WeBWorK::Utils::ProblemProcessing qw(compute_unreduced_score);
use WeBWorK::HTML::StudentNav         qw(studentNav);
use WeBWorK::Localize;

use constant TWO_DAYS => 172800;

sub initialize ($c) {
	$c->{studentID} = $c->param('effectiveUser') // $c->param('user');
	return;
}

sub nav ($c, $args) {
	return '' unless $c->authz->hasPermissions($c->param('user'), 'become_student');

	return $c->tag(
		'div',
		class        => 'row sticky-nav',
		role         => 'navigation',
		'aria-label' => 'student grades navigation',
		studentNav($c, undef)
	);
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

# Determine if the grade can be improved by testing if the unreduced score
# less than 1 and there are more attempts available.
sub can_improve_score ($c, $set, $problem_record) {
	my $unreduced_score = compute_unreduced_score($c->ce, $problem_record, $set);
	return $unreduced_score < 1
		&& ($problem_record->max_attempts < 0
			|| $problem_record->num_correct + $problem_record->num_incorrect < $problem_record->max_attempts);
}

# Note, this is meant to be a student view. Instructors will see the same information
# as the student they are acting as. For an instructor to see hidden grades, they
# can use the student progress report in instructor tools.
sub displayStudentGrades ($c) {
	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;

	my $studentID     = $c->{studentID};
	my $studentRecord = $db->getUser($studentID);
	unless ($studentRecord) {
		$c->addbadmessage($c->maketext('Record for user [_1] not found.', $studentID));
		return '';
	}
	my $effectiveUser = $studentRecord->user_id;

	my $courseName = $ce->{courseName};

	# First get all merged sets for this user ordered by set_id.
	my @sets = $db->getMergedSetsWhere({ user_id => $studentID }, 'set_id');
	# To be able to find the set objects later, make a handy hash of set ids to set objects.
	my %setsByID = (map { $_->set_id => $_ } @sets);

	# Before going through the table generating loop, find all the set versions for the sets in our list.
	my %setVersionsCount;
	my @allSetIDs;
	for my $set (@sets) {
		# Don't show hidden sets.
		next unless $set->visible;

		my $setID = $set->set_id;

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

	# Set groups.
	my (@notOpen, @open, @reduced, @recentClosed, @closed, %allItems);

	for my $setID (@allSetIDs) {
		my $set = $setsByID{$setID};

		# Determine if set is a test and if it is a test template or version.
		my $setIsTest      = defined $set->assignment_type && $set->assignment_type =~ /gateway/;
		my $setIsVersioned = $setIsTest                    && !defined $setVersionsCount{$setID};
		my $setTemplateID  = $setID =~ s/,v\d+$//r;

		# Initialize set item. Define link here. It will be adjusted for versioned tests later.
		my $item = {
			name              => format_set_name_display($setTemplateID),
			grade             => 0,
			grade_total       => 0,
			grade_total_right => 0,
			is_test           => $setIsTest,
			link              => $c->systemLink(
				$c->url_for('problem_list', setID => $setID),
				params => { effectiveUser => $effectiveUser }
			)
		};
		$allItems{$setID} = $item;

		# Determine which group to put set in. Test versions are added to test template.
		unless ($setIsVersioned) {
			my $enable_reduced_scoring =
				$ce->{pg}{ansEvalDefaults}{enableReducedScoring}
				&& $set->enable_reduced_scoring
				&& $set->reduced_scoring_date;
			if (before($set->open_date)) {
				push(@notOpen, $item);
				$item->{message} = $c->maketext('Will open on [_1].',
					$c->formatDateTime($set->open_date, $ce->{studentDateDisplayFormat}));
				next;
			} elsif (($enable_reduced_scoring && before($set->reduced_scoring_date)) || before($set->due_date)) {
				push(@open, $item);
			} elsif ($enable_reduced_scoring && before($set->due_date)) {
				push(@reduced, $item);
			} elsif ($ce->{achievementsEnabled} && $ce->{achievementItemsEnabled} && before($set->due_date + TWO_DAYS))
			{
				push(@recentClosed, $item);
			} else {
				push(@closed, $item);
			}
		}

		# Tests need their link updated. Along with template sets need to add a version list.
		# Also determines if grade and test problems should be shown.
		if ($setIsTest) {
			my $act_as_student_test_url = '';
			if ($set->assignment_type eq 'proctored_gateway') {
				$act_as_student_test_url = $item->{link} =~ s/($courseName)\//$1\/proctored_test_mode\//r;
			} else {
				$act_as_student_test_url = $item->{link} =~ s/($courseName)\//$1\/test_mode\//r;
			}

			# If this is a template gateway set, determine if there are any versions, then move on.
			unless ($setIsVersioned) {
				# Remove version from set url
				$item->{link} =~ s/,v\d+//;
				if ($setVersionsCount{$setID}) {
					$item->{versions} = [];
					# Hide score initially unless there is a version the score can be seen.
					$item->{hide_score} = 1;
				} else {
					$item->{message} = $c->maketext('No versions of this test have been taken.');
				}
				next;
			}

			# This is a versioned test, add it to the appropriate template item.
			push(@{ $allItems{$setTemplateID}{versions} }, $item);
			$item->{name} = $c->maketext('Version [_1]', $set->version_id);

			# Only add link if the problems can be seen.
			if ($set->hide_work eq 'N'
				|| ($set->hide_work eq 'BeforeAnswerDate' && time >= $set->answer_date))
			{
				if ($set->assignment_type eq 'proctored_gateway') {
					$item->{link} =~ s/($courseName)\//$1\/proctored_test_mode\//;
				} else {
					$item->{link} =~ s/($courseName)\//$1\/test_mode\//;
				}
			} else {
				$item->{link} = '';
			}

			# If the set has hide_score set, then nothing left to do.
			if (defined $set->hide_score && $set->hide_score eq 'Y'
				|| ($set->hide_score eq 'BeforeAnswerDate' && time < $set->answer_date))
			{
				$item->{hide_score} = 1;
				$item->{message}    = $c->maketext('Display of scores for this test is not allowed.');
				next;
			}
			# This is a test version, and the scores can be shown, so also show score of template set.
			$allItems{$setTemplateID}{hide_score} = 0;
		} else {
			# For a regular set, start out assuming it is complete until a problem says otherwise.
			$item->{completed} = 1;
		}

		my ($total_right, $total, $problem_scores, $problem_incorrect_attempts, $problem_records) =
			grade_set($db, $set, $studentID, $setIsVersioned, 1);
		$total_right = wwRound(2, $total_right);

		# Save set grades.
		$item->{grade_total}       = $total;
		$item->{grade_total_right} = $total_right;
		$item->{grade}             = 100 * wwRound(2, $total ? $total_right / $total : 0);

		# Only show problem scores if allowed.
		unless (defined $set->hide_score_by_problem && $set->hide_score_by_problem eq 'Y') {
			$item->{problems} = [];

			# Create a direct link to the problems unless the set is a test, or there is a set
			# restriction preventing the student from accessing the set problems.
			my $noProblemLink =
				$setIsTest
				|| restricted_set_message($c, $set, 'lti')
				|| restricted_set_message($c, $set, 'conditional')
				|| $authz->invalidIPAddress($set);

			for my $i (0 .. $#$problem_scores) {
				my $score      = $problem_scores->[$i];
				my $problem_id = $setIsVersioned ? $i + 1 : $problem_records->[$i]{problem_id};
				my $problem_link =
					$noProblemLink
					? ''
					: $c->systemLink($c->url_for('problem_detail', setID => $setID, problemID => $problem_id),
						params => { effectiveUser => $effectiveUser });
				$score = 0 unless $score =~ /^\d+$/;
				# For jitar sets we only display grades for top level problems.
				if ($set->assignment_type eq 'jitar') {
					my @seq = jitar_id_to_seq($problem_id);
					if ($#seq == 0) {
						push(@{ $item->{problems} }, { id => $seq[0], score => $score, link => $problem_link });
						$item->{completed} = 0 if $c->can_improve_score($set, $problem_records->[$i]);
					}
				} else {
					push(@{ $item->{problems} }, { id => $problem_id, score => $score, link => $problem_link });
					$item->{completed} = 0 if !$setIsTest && $c->can_improve_score($set, $problem_records->[$i]);
				}
			}
		}

		# If this is a test version, update template set to the best grade a student hand.
		if ($setIsVersioned) {
			# Compare the score to the template set and update as needed.
			my $templateItem = $allItems{$setTemplateID};
			if ($item->{grade} > $templateItem->{grade}) {
				for ('grade', 'grade_total', 'grade_total_right') {
					$templateItem->{$_} = $item->{$_};
				}
			}
		}
	}

	# Compute total course grade if requested.
	my $courseTotal = 0;
	my $totalRight  = 0;
	if ($ce->{showCourseHomeworkTotals}) {
		for (@open, @reduced, @recentClosed, @closed) {
			$courseTotal += $_->{grade_total};
			$totalRight  += $_->{grade_total_right};
		}
	}

	return $c->include(
		'ContentGenerator/Grades/student_grades',
		effectiveUser => $effectiveUser,
		fullName      => join(' ', $studentRecord->first_name, $studentRecord->last_name),
		notOpen       => \@notOpen,
		open          => \@open,
		reduced       => \@reduced,
		recentClosed  => \@recentClosed,
		closed        => \@closed,
		courseTotal   => $courseTotal,
		totalRight    => $totalRight
	);
}

1;
