################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Stats - Display statistics by user or
homework set (including sv graphs).

=cut

use strict;
use warnings;

use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::ContentGenerator::Grades;
use WeBWorK::Utils qw(jitar_id_to_seq jitar_problem_adjusted_status format_set_name_display);

# The table format has been borrowed from the Grades.pm module
sub initialize {
	my $self    = shift;
	my $r       = $self->r;
	my $urlpath = $r->urlpath;
	my $db      = $r->db;
	my $user    = $r->param('user');

	# Check permissions
	return unless $r->authz->hasPermissions($user, 'access_instructor_tools');

	$self->{type} = $urlpath->arg('statType') || '';
	if ($self->{type} eq 'student') {
		my $studentName = $urlpath->arg('userID') || $user;
		$self->{studentName} = $studentName;

	} elsif ($self->{type} eq 'set') {
		my $setName = $urlpath->arg('setID') || 0;
		$self->{setName} = $setName;
		my $setRecord = $db->getGlobalSet($setName);
		return unless $setRecord;
		$self->{set_due_date} = $setRecord->due_date;
		$self->{setRecord}    = $setRecord;
	}
}

sub title {
	my $self = shift;
	my $r    = $self->r;

	return '' unless $r->authz->hasPermissions($r->param('user'), 'access_instructor_tools');

	my $type = $self->{type};
	if ($type eq 'student') {
		return $r->maketext('Statistics for [_1] student [_2]', $self->{ce}{courseName}, $self->{studentName});
	} elsif ($type eq 'set') {
		return $r->maketext(
			'Statistics for [_1] set [_2]. Closes [_3]',
			$self->{ce}{courseName} =~ s/_/ /gr,
			CGI::span({ dir => 'ltr' }, format_set_name_display($self->{setName})),
			$self->formatDateTime($self->{set_due_date})
		);
	}

	return $r->maketext('Statistics');
}

sub siblings {
	my $self    = shift;
	my $r       = $self->r;
	my $db      = $r->db;
	my $urlpath = $r->urlpath;

	# Check permissions
	return '' unless $r->authz->hasPermissions($r->param('user'), 'access_instructor_tools');

	my $courseID = $urlpath->arg('courseID');
	my $eUserID  = $r->param('effectiveUser');

	print CGI::start_div({ class => 'info-box', id => 'fisheye' });
	print CGI::h2($r->maketext('Statistics'));
	print CGI::start_ul({ class => 'nav flex-column problem-list', dir => 'ltr' });

	# List links depending on if viewing set progress or student progress
	if ($self->{type} eq 'student') {
		my $ce = $r->ce;
		my $user = $r->param('user');
		# Get all users except the set level proctors, and restrict to the
		# sections or recitations that are allowed for the user if such
		# restrictions are defined.  This list is sorted by last_name,
		# then first_name, then user_id.
		my @studentRecords = $db->getUsersWhere(
			{
				user_id => { not_like => 'set_id:%' },
				$ce->{viewable_sections}{$user} || $ce->{viewable_recitations}{$user}
				? (
					-or => [
						$ce->{viewable_sections}{$user}
						? (section => { in => $ce->{viewable_sections}{$user} })
						: (),
						$ce->{viewable_recitations}{$user}
						? (recitation => { in => $ce->{viewable_recitations}{$user} })
						: ()
					]
					)
				: ()
			},
			[qw/last_name first_name user_id/]
		);

		for my $studentRecord (@studentRecords) {
			my $first_name         = $studentRecord->first_name;
			my $last_name          = $studentRecord->last_name;
			my $user_id            = $studentRecord->user_id;
			my $userStatisticsPage = $urlpath->newFromModule(
				$urlpath->module, $r,
				courseID => $courseID,
				statType => 'student',
				userID   => $user_id
			);
			print CGI::li(CGI::a(
				{ href => $self->systemLink($userStatisticsPage), class => 'nav-link' },
				"$last_name, $first_name  ($user_id)"
			));
		}
	} else {
		my @setIDs   = sort $db->listGlobalSets;
		for my $setID (@setIDs) {
			my $problemPage = $urlpath->newFromModule(
				$urlpath->module, $r,
				courseID => $courseID,
				setID    => $setID,
				statType => 'set',
			);
			print CGI::li(
				{ class => 'nav-item' },
				CGI::a(
					{ href => $self->systemLink($problemPage), class => 'nav-link' },
					format_set_name_display($setID)
				)
			);
		}
	}

	print CGI::end_ul();
	print CGI::end_div();

	return '';
}

sub body {
	my $self    = shift;
	my $r       = $self->r;
	my $urlpath = $r->urlpath;
	my $authz   = $r->authz;
	my $user    = $r->param('user');

	# Check permissions
	return CGI::div({ class => 'alert alert-danger p-1' }, 'You are not authorized to access instructor tools')
		unless $authz->hasPermissions($user, 'access_instructor_tools');

	if ($self->{type} eq 'student') {
		my $studentRecord = $r->db->getUser($self->{studentName});
		unless ($studentRecord) {
			return CGI::div({ class => 'alert alert-danger p-1' },
				$r->maketext('Record for user [_1] not found.', $self->{studentName}));
		}

		my $courseHomePage = $urlpath->new(
			type => 'set_list',
			args => { courseID => $urlpath->arg('courseID') }
		);

		my $email = $studentRecord->email_address;
		print CGI::a({ href => "mailto:$email" }, $email), CGI::br(),
			$r->maketext('Section') . ': ',    $studentRecord->section,    CGI::br(),
			$r->maketext('Recitation') . ': ', $studentRecord->recitation, CGI::br();

		if ($authz->hasPermissions($user, 'become_student')) {
			my $act_as_student_url =
				$self->systemLink($courseHomePage, params => { effectiveUser => $self->{studentName} });

			print $r->maketext('Act as:') . ' ', CGI::a({ href => $act_as_student_url }, $studentRecord->user_id);
		}

		print WeBWorK::ContentGenerator::Grades::displayStudentStats($self, $self->{studentName});
	} elsif ($self->{type} eq 'set') {
		$self->displaySet($self->{setName});
	} elsif ($self->{type} eq '') {
		$self->index;
	} else {
		warn "Don't recognize statistics display type: |$self->{type}|";
	}

	return '';
}

sub index {
	my $self       = shift;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $ce         = $r->ce;
	my $db         = $r->db;
	my $user       = $r->param('user');
	my $courseName = $urlpath->arg('courseID');

	my @setList = map { $_->[0] } $db->listGlobalSetsWhere({}, 'set_id');

	my @setLinks     = ();
	my @studentLinks = ();
	for my $set (@setList) {
		my $setStatisticsPage = $urlpath->newFromModule(
			$urlpath->module, $r,
			courseID => $courseName,
			statType => 'set',
			setID    => $set
		);
		push @setLinks,
			CGI::a({ href => $self->systemLink($setStatisticsPage) }, format_set_name_display($set));
	}

	# Get a list of students sorted by user_id.
	# Get all users except the set level proctors, and restrict to the sections or recitations that are allowed for the
	# user if such restrictions are defined.  This list is sorted by last_name, then first_name, then user_id.
	my @studentRecords = $db->getUsersWhere(
		{
			user_id => { not_like => 'set_id:%' },
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
	);

	for my $student (@studentRecords) {
		my $first_name = $student->first_name;
		my $last_name  = $student->last_name;
		my $user_id    = $student->user_id;

		my $userStatisticsPage = $urlpath->newFromModule(
			$urlpath->module, $r,
			courseID => $courseName,
			statType => 'student',
			userID   => $student->user_id
		);
		push @studentLinks,
			CGI::a({ href => $self->systemLink($userStatisticsPage) }, "$last_name, $first_name ($user_id)");
	}

	print CGI::div(
		{ class => 'row g-0' },
		CGI::div(
			{ class => 'col-lg-5 col-sm-6 border border-dark' },
			CGI::h2({ class => 'text-center fs-3' }, $r->maketext('View statistics by set')),
			CGI::ul({ dir => 'ltr' }, CGI::li([@setLinks])),
		),
		CGI::div(
			{ class => 'col-lg-5 col-sm-6 border border-dark' },
			CGI::h2({ class => 'text-center fs-3' }, $r->maketext('View statistics by student')),
			CGI::ul(CGI::li([@studentLinks])),
		)
	);
}

# Determines the percentage of students whose score is greater than a given value.
sub determine_percentiles {
	my $percent_brackets = shift;
	my @list_of_scores   = sort { $a <=> $b } @_;
	my $num_students     = $#list_of_scores;
	my %percentiles = map { $_ => @list_of_scores[ int((100 - $_) * $num_students / 100) ] // 0 } @$percent_brackets;
	# For example, $percentiles{75} = @list_of_scores[int(25 * $num_students / 100)]
	# means that 75% of the students received this score $percentiles{75} or higher.
	return %percentiles;
}

# Replace an array such as "[0, 0, 0, 86, 86, 100, 100, 100]" by "[0, '-', '-', 86, '-', 100, '-', '-']"
sub prevent_repeats {
	my @inarray = @_;
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
	@outarray;
}

sub displaySet {
	my $self       = shift;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $courseName = $urlpath->arg('courseID');
	my $setName    = $urlpath->arg('setID');
	my $setRecord  = $self->{setRecord};

	unless ($setRecord) {
		print CGI::div({ class => 'alert alert-danger p-1' }, $r->maketext('Global set [_1] not found.', $setName));
		return;
	}

	# Get a list of the global problem records for this set.
	my @problems = $db->getGlobalProblemsWhere({ set_id => $setName }, 'problem_id');

	# The number of problems in the set.  Note that for jitar sets, this is the number of top level problems.
	my $num_problems = 0;

	# Formatted problem name.  For jitar sets this is the sequence separated by periods.  Otherwise it is just the
	# problem id.
	my %prettyProblemIDs;

	# For jitar sets we need to know which problems are top level problems.
	my $isJitarSet = $setRecord->assignment_type eq 'jitar';
	my %topLevelProblems;

	# Show a grading link for any essay problems in the set (if any).
	my @GradeableRows;
	my $showGradeRow = 0;

	# Compile the following data for all students.
	my @index_list;                              # List of all student indices
	my @score_list;                              # List of all student total percentage scores
	my %attempts_list_for_problem;               # A list of the number of attempts for each problem
	my %num_attempts_for_problem;                # The total number of attempst for this problem (sum of above list)
	my %num_students_attempting_problem;         # The number of students attempting this problem.
	my %correct_answers_for_problem;             # The number of students correctly answering this problem
												 # (partial correctness allowed).
	my %correct_adjusted_answers_for_problem;    # The number of students with an adjusted status
												 # of 1 for the problem (only for jitar sets).

	for my $problem (@problems) {
		$prettyProblemIDs{ $problem->problem_id } =
			$isJitarSet ? join('.', jitar_id_to_seq($problem->problem_id)) : $problem->problem_id;

		if ($problem->flags =~ /essay/) {
			$showGradeRow = 1;
			push(
				@GradeableRows,
				CGI::a(
					{
						href => $self->systemLink($urlpath->new(
							type => 'instructor_problem_grader',
							args =>
								{ courseID => $courseName, setID => $setName, problemID => $problem->problem_id }
						))
					},
					$r->maketext('Grade Problem')
				)
			);
		} else {
			push(@GradeableRows, '');
		}

		if ($isJitarSet) {
			my @seq = jitar_id_to_seq($problem->problem_id);
			if ($#seq == 0) {
				$topLevelProblems{ $problem->problem_id } = 1;
				++$num_problems;
			}
		} else {
			++$num_problems;
		}

		# Initialize the number of correct answers and correct adjusted answers.
		$correct_answers_for_problem{ $problem->problem_id }          = 0;
		$correct_adjusted_answers_for_problem{ $problem->problem_id } = 0 if $isJitarSet;
	}

	# Get user records
	debug("Begin obtaining problem records for set $setName");
	my @userRecords = $db->getUsersWhere({
		user_id => [ -and => { not_like => 'set_id:%' }, { not_like => "$ce->{practiceUserPrefix}\%" } ]
	});
	debug("End obtaining user records for set $setName");

	debug('begin main loop');
	for my $studentRecord (@userRecords) {
		next unless $ce->status_abbrev_has_behavior($studentRecord->status, 'include_in_stats');

		my $student = $studentRecord->user_id;

		my $totalRight                 = 0;
		my $total                      = 0;
		my $total_num_attempts_for_set = 0;
		my $probNum                    = 0;

		debug("Begin obtaining problem records for user $student set $setName");
		my @problemRecords;
		if ($setRecord->assignment_type =~ /gateway/) {
			@problemRecords =
				$db->getProblemVersionsWhere({ user_id => $student, set_id => { like => "$setName,v\%" } });
		} else {
			@problemRecords = $db->getUserProblemsWhere({ user_id => $student, set_id => $setName });
		}
		debug("End obtaining problem records for user $student set $setName");

		for my $problemRecord (@problemRecords) {
			my $probID = $problemRecord->problem_id;

			# It is possible that $problemRecord->num_correct or $problemRecord->num_correct is an empty or blank string
			# instead of 0.  The || clause fixes this and prevents warning messages in the usage below.
			my $num_attempts = ($problemRecord->num_correct || 0) + ($problemRecord->num_incorrect || 0);

			my $probValue = $problemRecord->value;
			$probValue = 1 unless defined($probValue) && $probValue ne '';    # FIXME:  Set defaults here?

			# It is also possible that $problemRecord->status is an empty or blank string instead of 0.
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
				$num_attempts_for_problem{$probID}             += $num_attempts;
				$total_num_attempts_for_set                    += $num_attempts;
				$correct_answers_for_problem{$probID}          += $status;
				$correct_adjusted_answers_for_problem{$probID} += $adjusted_status if ($isJitarSet);
			}
		}

		my $act_as_student_url =
			$self->systemLink($urlpath->new(type => 'set_list', args => { courseID => $courseName }),
				params => { effectiveUser => $studentRecord->user_id });
		my $email = $studentRecord->email_address;

		my $avg_num_attempts = $num_problems     ? $total_num_attempts_for_set / $num_problems   : 0;
		my $successIndicator = $avg_num_attempts ? ($totalRight / $total)**2 / $avg_num_attempts : 0;

		# Add the success indicator to the list of success indices.
		push(@index_list, $successIndicator);
		# Add the score to the list of total scores (out of 100).
		push(@score_list, $total ? $totalRight / $total : 0);
	}
	debug('end mainloop');

	# Determine index quartiles.
	# Percentage of students having scores or indices above this cutoff value.
	my @brackets1         = (90, 80, 70, 60, 50, 40, 30, 20, 10);
	my %index_percentiles = determine_percentiles(\@brackets1, @index_list);
	my %score_percentiles = determine_percentiles(\@brackets1, @score_list);
	my %attempts_percentiles_for_problem;
	my %problemPage;

	my @brackets2 = (95, 75, 50, 25, 5, 1);
	for my $problem (@problems) {
		my $probID = $problem->problem_id;

		# Percentage of students having this many attempts or more.
		$attempts_percentiles_for_problem{$probID} =
			{ determine_percentiles([@brackets2], @{ $attempts_list_for_problem{$probID} }) };

		if ($setRecord->assignment_type =~ /gateway/ || !$db->existsUserSet($r->param('user') , $setName)) {
			# If this is a gateway quiz, there is not a valid link to the problem, so use the Problem.pm editMode with
			# an undefined set instead.
			$problemPage{$probID} = $self->systemLink(
				$urlpath->newFromModule(
					'WeBWorK::ContentGenerator::Problem', $r,
					courseID  => $courseName,
					setID     => 'Undefined_Set',
					problemID => $problem->problem_id
				),
				params => {
					editMode       => 'savedFile',
					sourceFilePath => $problem->source_file
				}
			);
		} else {
			$problemPage{$probID} = $self->systemLink($urlpath->newFromModule(
				'WeBWorK::ContentGenerator::Problem', $r,
				courseID  => $courseName,
				setID     => $setName,
				problemID => $probID
			));
		}
	}

	# SVG bar graph showing the percentage of students with correct answers for each problem.

	my ($barwidth, $barsep) = (22, 4);
	my $totalbarwidth = $barwidth + 2 * $barsep;
	my ($topmargin, $rightmargin, $bottommargin, $leftmargin) = (30, 20, 35, 40);
	my ($plotwindowwidth, $plotwindowheight) = (@problems * ($barwidth + 2 * $barsep), 200);
	# Since $plotwindowheight = 200, the height of each bar is 2 * percentagescore.
	if ($plotwindowwidth < 450) { $plotwindowwidth = 450; }
	my ($imagewidth, $imageheight) =
		($leftmargin + $plotwindowwidth + $rightmargin, $topmargin + $plotwindowheight + $bottommargin);
	$imagewidth += 200 if $isJitarSet;
	my ($titlexpixel, $titleypixel) = ($leftmargin + sprintf('%d', $plotwindowwidth / 2), $topmargin - 10);
	my ($xaxislabelxpixel, $xaxislabelypixel) = ($titlexpixel, $imageheight - 5);
	my $yaxislabelxpixel = $leftmargin - 4;

	# Create a string for the svg image.
	my $svg =
		'<svg id="bargraph" xmlns="http://www.w3.org/2000/svg" '
		. qq!width="100%" height="100%" viewbox="0 0 $imagewidth $imageheight" !
		. 'aria-labelledby="bargraphtitle">'

		. qq!<rect id="bargraphwindow" x="0" y="0" width="$imagewidth" height="$imageheight" !
		. ' rx="20" ry="20" stroke="#888" stroke-width="2" stroke-opacity="1" fill="white" fill-opacity="0" />'

		. qq!<text id="bargraphtitle" x="$titlexpixel" y="$titleypixel" !
		. 'font-family="sans-serif" font-size="14" fill="black" text-anchor="middle" font-weight="bold">'
		. $r->maketext('Percentage of Active Students with Correct Answers')
		. '</text>'

		. qq!<text id="bargraphxaxislabel" x="$xaxislabelxpixel" y="$xaxislabelypixel" !
		. 'font-family="sans-serif" font-size="14" fill="black" text-anchor="middle" font-weight="normal">'
		. $r->maketext('Problem Number')
		. '</text>'

		. qq!<rect id="bargraphplotwindow" x="$leftmargin" y="$topmargin" !
		. qq!width="$plotwindowwidth" height="$plotwindowheight" !
		. 'fill="white" stroke="#bbb" stroke-width="1" fill-opacity="0" stroke-opacity="1" />';

	my $yaxislabelypixel = 0;
	my $yaxislabel       = '';
	for my $i (0 .. 5) {
		$yaxislabelypixel = $topmargin + 5 + ($i * sprintf('%d', $plotwindowheight / 5));
		$yaxislabel       = 20 * (5 - $i);
		$svg .=
			qq!<text id="bargraphylabel$yaxislabel" x="$yaxislabelxpixel" y="$yaxislabelypixel" !
			. 'font-family="sans-serif" font-size="12" fill="black" text-anchor="end" font-weight="normal">'
			. $yaxislabel
			. '%</text>';
	}

	my $yaxisruleypixel      = 0;
	my $yaxisrulerightxpixel = $leftmargin + $plotwindowwidth;
	for my $i (1 .. 9) {
		$yaxisruleypixel = $topmargin + ($i * sprintf('%d', $plotwindowheight / 10));
		$svg .=
			qq!<line x1="$leftmargin" y1="$yaxisruleypixel" !
			. qq!x2="$yaxisrulerightxpixel" y2="$yaxisruleypixel" !
			. 'stroke="#bbb" stroke-width="1" stroke-opacity="1" />';
	}

	my $problabelypixel = $topmargin + $plotwindowheight + 15;

	for (my $i = 0; $i <= $#problems; $i++) {
		my $probID = $problems[$i]->problem_id;

		my $percentcorrect = 0;
		my $barheight      = 0;
		my $barxpixel      = 0;
		my $barypixel      = 0;

		if ($isJitarSet && $topLevelProblems{$probID}) {
			$percentcorrect = $num_students_attempting_problem{$probID}
				? sprintf('%0.0f',
					100 * $correct_adjusted_answers_for_problem{$probID} / $num_students_attempting_problem{$probID})
				: 0;    # Avoid division by zero
			$barheight = sprintf('%d', $percentcorrect * $plotwindowheight / 100);
			$barxpixel = $leftmargin + $i * ($barwidth + 2 * $barsep) + $barsep + 3;
			$barypixel = $topmargin + $plotwindowheight - $barheight;
			$svg .=
				qq!<rect id="adjbar$probID" x="$barxpixel" y="$barypixel" width="$barwidth" height="$barheight" !
				. 'fill="rgb(0,51,136)" />';
		}
		$percentcorrect =
			$num_students_attempting_problem{$probID}
			? sprintf('%0.0f', 100 * $correct_answers_for_problem{$probID} / $num_students_attempting_problem{$probID})
			: 0;    # Avoid division by zero
		$barheight = sprintf('%d', $percentcorrect * $plotwindowheight / 100);
		$barxpixel = $leftmargin + $i * $totalbarwidth + $barsep;
		$barypixel = $topmargin + $plotwindowheight - $barheight;

		my $problabelxpixel = $leftmargin + $i * $totalbarwidth + sprintf('%d', $totalbarwidth / 2);

		my $prettyID = $prettyProblemIDs{$probID};
		$prettyID = '##' if (length($prettyID) > 4);
		$svg .=
			'<a '
			. ($problemPage{$probID} ? qq!href="$problemPage{$probID}"! : '')
			. ' target="ww_stats_problem">'
			. qq!<rect id="bar$probID" x="$barxpixel" y="$barypixel" !
			. qq!width="$barwidth" height="$barheight" fill="rgb(0,153,198)" />!
			. qq!<text id="problem$probID" x="$problabelxpixel" y="$problabelypixel" !
			. qq!font-family="sans-serif" font-size="12" fill="black" text-anchor="middle">$prettyID</text></a>!;
	}

	# Print a legend if its a jitar set
	if ($isJitarSet) {
		my $barxpixel = $leftmargin + $plotwindowwidth + 10;
		my $barypixel = 55;
		$svg .= qq!<rect id="legend1" x="$barxpixel" y="$barypixel" width="10" height="10" fill="rgb(0,153,198)" />!;
		$svg .=
			qq!<text id="legend1lab" x="${\($barxpixel + 15)}" y="${\($barypixel + 10)}" !
			. 'font-family="sans-serif" font-size="12" fill="black" text-anchor="start">'
			. $r->maketext('Correct Status')
			. '</text>';

		$barypixel = $barypixel - 15;
		$svg .= qq!<rect id="legend2" x="$barxpixel" y="$barypixel" width="10" height="10" fill="rgb(0,51,136)" />!;
		$svg .=
			qq!<text id="legend2lab" x="${\($barxpixel + 15)}" y="${\($barypixel + 10)}" !
			. 'font-family="sans-serif" font-size="12" fill="black" text-anchor="start">'
			. $r->maketext('Correct Adjusted Status')
			. '</text>';
	}

	$svg .= '</svg>';

	print CGI::div({ class => 'img-fluid mb-3', style => "max-width:${imagewidth}px" }, $svg);

	# Print tables

	# Table showing the percentage of students with correct answers for each problems
	print CGI::p($r->maketext('The percentage of active students with correct answers for each problem')),
		CGI::start_div({ class => 'table-responsive' }),
		CGI::start_table({ class => 'stats-table table table-bordered' }), CGI::Tr(
			CGI::th($r->maketext('Problem #')),
			CGI::td(
				{ class => 'text-center' },
				[
					map {
						my $probID = $_->problem_id;
						$problemPage{$probID}
							? CGI::a({ href => $problemPage{$probID}, target => 'ww_stats_problem' },
								$prettyProblemIDs{$probID})
							: $prettyProblemIDs{$probID}
					} @problems
				]
			)
		),
		CGI::Tr(
			CGI::th($r->maketext('% correct')),
			CGI::td(
				{ class => 'text-center' },
				[
					map {
						my $probID = $_->problem_id;
						($num_students_attempting_problem{$probID})
						? sprintf('%0.0f',
							100 * $correct_answers_for_problem{$probID} / $num_students_attempting_problem{$probID})
						: '-'
					} @problems
				]
			)
		),
		(
			$isJitarSet
			? CGI::TR(
				CGI::th($r->maketext('% correct with review')),
				CGI::td(
					{ class => 'text-center' },
					[
						map {
							my $probID = $_->problem_id;
							$num_students_attempting_problem{$probID} && $topLevelProblems{$probID}
							? sprintf('%0.0f',
								100 * $correct_adjusted_answers_for_problem{$probID} /
								$num_students_attempting_problem{$probID})
							: '-'
						} @problems
					]
				)
			)
			: ''
		),
		CGI::Tr(
			CGI::th($r->maketext('avg attempts')),
			CGI::td(
				{ class => 'text-center' },
				[
					map {
						my $probID = $_->problem_id;
						($num_students_attempting_problem{$probID})
						? sprintf('%0.1f',
							$num_attempts_for_problem{$probID} / $num_students_attempting_problem{$probID})
						: '-'
					} @problems
				]
			)
		),
		CGI::Tr(
			CGI::th($r->maketext('# of active students')),
			CGI::td(
				{ class => 'text-center' },
				[
					map {
						($num_students_attempting_problem{ $_->problem_id })
						? $num_students_attempting_problem{ $_->problem_id }
						: '-'
					} @problems
				]
			)
		);

	print CGI::Tr(CGI::th($r->maketext('Manual Grader')), CGI::td(\@GradeableRows)) if ($showGradeRow);

	print CGI::end_table(), CGI::end_div();

	# Table showing percentile statistics for scores and success indices.
	print CGI::p(CGI::i(
		$r->maketext(
			'The percentage of students receiving at least these scores. The median score is in the 50% column.')
	));
	print CGI::div(
		{ class => 'table-responsive' },
		CGI::table(
			{ class => 'stats-table table table-bordered' },
			CGI::Tr(
				CGI::th($r->maketext('% students')),
				CGI::td({ class => 'text-center' }, \@brackets1),
				CGI::td({ class => 'text-center' }, $r->maketext('top score'))
			),
			CGI::Tr(
				CGI::th($r->maketext('Score')),
				CGI::td(
					{ class => 'text-center' },
					[ prevent_repeats map { sprintf('%0.0f', 100 * $score_percentiles{$_}) } @brackets1 ]
				),
				CGI::td({ class => 'text-center' }, sprintf('%0.0f', 100))
			),
			CGI::Tr(
				CGI::th($r->maketext('Success Index')),
				CGI::td(
					{ class => 'text-center' },
					[ prevent_repeats map { sprintf('%0.0f', 100 * $index_percentiles{$_}) } @brackets1 ]
				),
				CGI::td({ class => 'text-center' }, sprintf('%0.0f', 100))
			)
		)
	);

	# Table showing percentile statistics for scores and success indices.
	print CGI::p(CGI::i(
		$r->maketext(
			'Percentile cutoffs for number of attempts. The 50% column shows the median number of attempts.')
		)),
		CGI::start_div({ class => 'table-responsive' }),
		CGI::start_table({ class => 'stats-table table table-bordered' }),
		CGI::Tr(CGI::th($r->maketext('% students')), CGI::td({ class => 'text-center' }, \@brackets2));

	for my $problem (@problems) {
		my $probID = $problem->problem_id;
		print CGI::Tr(
			CGI::th(
				$problemPage{$probID}
				? CGI::a({ href => $problemPage{$probID}, target => 'ww_stats_problem' },
					$r->maketext('Problem [_1]', $prettyProblemIDs{$probID}))
				: $prettyProblemIDs{$probID}
			),
			CGI::td(
				{ class => 'text-center' },
				[
					prevent_repeats reverse
						map { sprintf('%0.0f', $attempts_percentiles_for_problem{$probID}{$_}) } @brackets2
				]
			)
		);
	}

	print CGI::end_table(), CGI::end_div();

	return '';
}

1;
