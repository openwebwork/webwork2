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
use WeBWorK::Utils qw(jitar_id_to_seq jitar_problem_adjusted_status format_set_name_display getAssetURL grade_set);
use SVG;

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
		my $problemID = $urlpath->arg('problemID') || 0;
		if ($problemID) {
			$self->{prettyID} =
				$setRecord->assignment_type eq 'jitar' ? join('.', jitar_id_to_seq($problemID)) : $problemID;
			$self->{type} = 'problem';
			my $problemRecord = $db->getGlobalProblem($setName, $problemID);
			return unless $problemRecord;
			$self->{problemRecord} = $problemRecord;
		}
	}
}

sub output_JS {
	my $self = shift;
	my $r    = $self->r;
	my $ce   = $r->ce;
	print CGI::script(
		{
			src   => getAssetURL($ce, 'js/apps/Stats/stats.js'),
			defer => undef,
		},
		''
	);
	if ($self->{type} eq 'problem') {
		print CGI::script({ src => getAssetURL($ce, 'node_modules/iframe-resizer/js/iframeResizer.min.js') }, '');
	}
	return '';
}

sub title {
	my $self = shift;
	my $r    = $self->r;

	return '' unless $r->authz->hasPermissions($r->param('user'), 'access_instructor_tools');

	my $type = $self->{type};
	if ($type eq 'student') {
		return $r->maketext('Statistics for student [_1]', $self->{studentName});
	} elsif ($type eq 'set') {
		return $r->maketext('Statistics for [_1]',
			CGI::span({ dir => 'ltr' }, format_set_name_display($self->{setName})));
	} elsif ($type eq 'problem') {
		return $r->maketext(
			'Statsitcs for [_1] problem [_2]',
			CGI::span({ dir => 'ltr' }, format_set_name_display($self->{setName})),
			$self->{prettyID}
		);
	}

	return $r->maketext('Statistics');
}

sub path {
	my ($self, $args) = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $courseName = $urlpath->arg('courseID');
	my $setName    = $self->{setName}           || '';
	my $problemID  = $urlpath->arg('problemID') || '';
	my $prettyID   = $self->{prettyID}          || '';
	my $type       = $self->{type};

	my @path = (
		WeBWork            => $r->location,
		$courseName        => $r->location . "/$courseName",
		'Instructor Tools' => $r->location . "/$courseName/instructor",
		Statistics         => $r->location . "/$courseName/instructor/stats",
	);
	if ($type eq 'student') {
		push(@path, $self->{studentName} => '');
	} elsif ($type eq 'set') {
		push(@path, format_set_name_display($setName) => '');
	} elsif ($type eq 'problem') {
		push(
			@path, format_set_name_display($setName) => $r->location . "/$courseName/instructor/stats/set/$setName",
			$prettyID => ''
		);
	} else {
		$path[-1] = '';
	}

	print $self->pathMacro($args, @path);

	return '';
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
		my $ce             = $r->ce;
		my $user           = $r->param('user');
		my @studentRecords = $self->get_students(1);

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
			print CGI::li(
				{ class => 'nav-item' },
				CGI::a(
					{
						$user_id eq $self->{studentName}
						? (class => 'nav-link active')
						: (href => $self->systemLink($userStatisticsPage), class => 'nav-link')
					},
					"$last_name, $first_name ($user_id)"
				)
			);
		}
	} else {
		my @setIDs = sort $db->listGlobalSets;
		my $filter = $r->param('filterSection');
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
					{
						defined $self->{setName} && $setID eq $self->{setName}
						? (class => 'nav-link active')
						: (
							href =>
								$self->systemLink($problemPage, params => $filter ? { filterSection => $filter } : {}),
							class => 'nav-link'
						)
					},
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
		$self->displaySet();
	} elsif ($self->{type} eq 'problem') {
		$self->displayProblem();
	} elsif ($self->{type} eq '') {
		$self->index;
	} else {
		warn "Don't recognize statistics display type: |$self->{type}|";
	}

	return '';
}

# Get a list of problem records and build a problem menu.
sub get_problems {
	my $self          = shift;
	my $r             = $self->r;
	my $db            = $r->db;
	my $urlpath       = $r->urlpath;
	my $setID         = $self->{setName};
	my $setRecord     = $self->{setRecord};
	my $prettyID      = $self->{prettyID} || '';
	my $filterSection = $r->param('filterSection');
	my $isJitarSet    = $setRecord->assignment_type eq 'jitar';
	my @problems      = $db->getGlobalProblemsWhere({ set_id => $setID }, 'problem_id');

	return (
		CGI::div(
			{ class => 'btn-group student-nav-filter-selector mx-2' },
			CGI::a(
				{
					href           => '#',
					id             => 'problemMenu',
					class          => 'btn btn-primary dropdown-toggle',
					role           => 'button',
					data_bs_toggle => 'dropdown',
					aria_expanded  => 'false',
				},
				$prettyID ? $r->maketext('Problem [_1]', $prettyID) : $r->maketext('All problems')
			),
			CGI::ul(
				{
					class           => 'dropdown-menu',
					role            => 'menu',
					aria_labelledby => 'problemMenu'
				},
				CGI::li(CGI::a(
					{
						class => 'dropdown-item',
						style => $prettyID ? '' : 'background-color: #8F8',
						href  => $self->systemLink(
							$urlpath->newFromModule(
								__PACKAGE__, $r,
								courseID => $urlpath->arg('courseID'),
								statType => $self->{type},
								setID    => $setID,
							),
							params => $filterSection ? { filterSection => $filterSection } : {}
						)
					},
					$r->maketext('All problems')
				)),
				(
					map {
						my $probID    = $isJitarSet ? join('.', jitar_id_to_seq($_->problem_id)) : $_->problem_id;
						my $statsPage = $urlpath->newFromModule(
							__PACKAGE__, $r,
							courseID  => $urlpath->arg('courseID'),
							statType  => $self->{type},
							setID     => $setID,
							problemID => $_->problem_id
						);
						CGI::li(CGI::a(
							{
								class => 'dropdown-item',
								style => $probID eq $prettyID ? 'background-color: #8F8' : '',
								href  => $self->systemLink(
									$statsPage, params => $filterSection ? { filterSection => $filterSection } : {}
								)
							},
							$r->maketext('Problem [_1]', $probID)
						))
					} @problems
				)
			)
		),
		@problems
	);
}

# Get a list of student records and create a section/recitation menu.
sub get_students {
	my $self     = shift;
	my $noFilter = shift;
	my $r        = $self->r;
	my $ce       = $r->ce;
	my $db       = $r->db;
	my $urlpath  = $r->urlpath;
	my $user     = $r->param('user');

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

	return @studentRecords if $noFilter;

	# Create a hash of sections and recitations, if there are any for the course.
	# Filter out all records except for current/auditing students for stats.
	# Filter out students not in selected section/recitation.
	my $filterSection = $r->param('filterSection');
	my %sections;
	my @outStudents;
	for my $student (@studentRecords) {
		# Only include current/auditing students in stats.
		next
			unless ($ce->status_abbrev_has_behavior($student->status, 'include_in_stats')
				&& $db->getPermissionLevel($student->user_id)->permission == $ce->{userRoles}{student});

		my $section = $student->section;
		$sections{"section:$section"} = $r->maketext('Section [_1]', $section)
			if $section && !$sections{"section:$section"};
		my $recitation = $student->recitation;
		$sections{"recitation:$recitation"} = $r->maketext('Recitation [_1]', $recitation)
			if $recitation && !$sections{"recitation:$recitation"};

		# Only add users who match the selected section/recitation.
		push(@outStudents, $student)
			if (!$filterSection
				|| ($filterSection =~ /^section:(.*)$/    && $section eq $1)
				|| ($filterSection =~ /^recitation:(.*)$/ && $recitation eq $1));
	}

	my $statsPage = $urlpath->newFromModule(
		__PACKAGE__, $r,
		courseID  => $urlpath->arg('courseID'),
		statType  => $self->{type},
		setID     => $self->{setName},
		problemID => $urlpath->arg('problemID') || ''
	);

	# Create a section/recitation "filter by" dropdown if there are sections or recitations.
	my $filterMenu = (scalar keys %sections)
		? CGI::div(
			{ class => 'btn-group student-nav-filter-selector mx-2' },
			CGI::a(
				{
					href           => '#',
					id             => 'filterSection',
					class          => 'btn btn-primary dropdown-toggle',
					role           => 'button',
					data_bs_toggle => 'dropdown',
					aria_expanded  => 'false',
				},
				$filterSection ? $sections{$filterSection} : $r->maketext('All sections')
			),
			CGI::ul(
				{
					class           => 'dropdown-menu',
					role            => 'menu',
					aria_labelledby => 'filterSection'
				},
				CGI::li(CGI::a(
					{
						class => 'dropdown-item',
						style => $filterSection ? '' : 'background-color: #8F8',
						href  => $self->systemLink($statsPage)
					},
					$r->maketext('All sections')
				)),
				(
					map {
						CGI::li(CGI::a(
							{
								class => 'dropdown-item',
								style => ($filterSection || '') eq $_ ? 'background-color: #8F8' : '',
								href  => $self->systemLink(
									$statsPage,
									params => {
										filterSection => $_
									}
								)
							},
							$sections{$_}
						))
					} sort keys %sections
				)
			)
		)
		: '';

	return ($filterMenu, @outStudents);
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
		push @setLinks, CGI::a({ href => $self->systemLink($setStatisticsPage) }, format_set_name_display($set));
	}

	my @studentRecords = $self->get_students(1);
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
			CGI::ul({ dir   => 'ltr' }, CGI::li([@setLinks])),
		),
		CGI::div(
			{ class => 'col-lg-5 col-sm-6 border border-dark' },
			CGI::h2({ class => 'text-center fs-3' }, $r->maketext('View statistics by student')),
			CGI::ul(CGI::li([@studentLinks])),
		)
	);
}

sub displaySet {
	my $self       = shift;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $user       = $r->param('user');
	my $courseName = $urlpath->arg('courseID');
	my $setName    = $urlpath->arg('setID');
	my $setRecord  = $self->{setRecord};
	my $filter     = $r->param('filterSection');

	unless ($setRecord) {
		print CGI::div({ class => 'alert alert-danger p-1' }, $r->maketext('Global set [_1] not found.', $setName));
		return;
	}

	# Get a list of the global problem records for this set.
	my ($problemMenu, @problems) = $self->get_problems;
	my %prettyIDs;         # Format problem ID for jitar sets.
	my @problemHref;       # List of href for links to the problem stats page.
	my @problemLinks;      # List of html formatted links of the form "Problem problem_id".
	my @problemIDLinks;    # List of html formatted links with just the problem id.
	my @problemValues;     # List of the point values of each problem.
	my $totalValue = 0;    # Total point value of the set.

	# For jitar sets we need to know which problems are top level problems.
	my $isJitarSet = $setRecord->assignment_type eq 'jitar';
	my %topLevelProblems;

	# Show a grading link for any essay problems in the set (if any).
	my @GradeableRows;
	my $showGradeRow = 0;

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
		$prettyIDs{$probID} = $isJitarSet ? join('.', jitar_id_to_seq($problem->problem_id)) : $problem->problem_id;

		# Link to individual problem stats page.
		my $statsLink = $self->systemLink(
			$urlpath->newFromModule(
				'WeBWorK::ContentGenerator::Instructor::Stats', $r,
				courseID  => $courseName,
				statType  => 'set',
				setID     => $setName,
				problemID => $probID
			),
			params => $filter ? { filterSection => $filter } : {}
		);
		push(@problemHref,    $statsLink);
		push(@problemIDLinks, CGI::a({ href => $statsLink }, $prettyIDs{$probID}));
		push(@problemLinks,   CGI::a({ href => $statsLink }, $r->maketext('Problem [_1]', $prettyIDs{$probID})));

		# It appears the problem flags are not being set in database, so this current does nothing.
		if ($problem->flags =~ /essay/) {
			$showGradeRow = 1;
			push(
				@GradeableRows,
				CGI::a(
					{
						href => $self->systemLink($urlpath->new(
							type => 'instructor_problem_grader',
							args => { courseID => $courseName, setID => $setName, problemID => $probID }
						))
					},
					$r->maketext('Grade Problem [_1]', $prettyIDs{$probID})
				)
			);
		} else {
			push(@GradeableRows, '');
		}

		# Store the point value of each problem.
		$totalValue += $problem->value;
		push(@problemValues, $problem->value);

		# Keep track of all problems for non Jitar sets, and top level for Jitar.
		$topLevelProblems{$probID} = 1 if ($isJitarSet && $prettyIDs{$probID} !~ /\./);

		# Initialize the number of correct answers and correct adjusted answers.
		$total_status_for_problem{$probID}    = 0;
		$adjusted_status_for_problem{$probID} = 0 if $isJitarSet;
	}
	# Only count top level problems for Jitar sets.
	my $num_problems = ($isJitarSet) ? scalar(keys %topLevelProblems) : scalar(@problemLinks);

	my ($filterMenu, @studentRecords) = $self->get_students();
	for my $studentRecord (@studentRecords) {
		my $student                    = $studentRecord->user_id;
		my $totalRight                 = 0;
		my $total                      = 0;
		my $total_num_attempts_for_set = 0;

		# Get problem data for student.
		my @problemRecords;
		my $noSkip = 0;
		if ($setRecord->assignment_type =~ /gateway/) {
			# Only use the quiz version with the best score.
			my @setVersions =
				$db->getMergedSetVersionsWhere({ user_id => $student, set_id => { like => "$setName,v\%" } });
			if (@setVersions) {
				my $maxVersion = 1;
				my $maxStatus  = 0;
				foreach my $verSet (@setVersions) {
					my ($total, $possible) = grade_set($db, $verSet, $student, 1);
					if ($possible > 0 && $total / $possible >= $maxStatus) {
						$maxStatus  = $total / $possible;
						$maxVersion = $verSet->version_id;
					}
				}
				@problemRecords = $db->getAllMergedProblemVersions($student, $setName, $maxVersion);
			} else {
				# Check if student is assigned to the quiz but hasn't started any version.
				$noSkip = 1 if $db->getMergedSet($student, $setName);
			}
		} else {
			@problemRecords = $db->getUserProblemsWhere({ user_id => $student, set_id => $setName });
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

		my $avgScore         = $total            ? $totalRight / $total                        : 0;
		my $avg_num_attempts = $num_problems     ? $total_num_attempts_for_set / $num_problems : 0;
		my $successIndicator = $avg_num_attempts ? $avgScore**2 / $avg_num_attempts            : 0;

		# Add the success indicator and scores (between 0 and 1) to respecitve lists.
		push(@index_list, $successIndicator);
		push(@score_list, $avgScore);
	}

	# Loop over the problems one more time to build stats tables.
	my (@avgScore, @adjScore, @avgAttempts, @numActive, @attemptsList, @successList);
	foreach (@problems) {
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

	# Set Information
	my $statusHelp = '';
	my $status     = $r->maketext('Open');
	if (time < $setRecord->open_date) {
		$status = $r->maketext('Before Open Date');
	} elsif ($setRecord->enable_reduced_scoring
		&& time > $setRecord->reduced_scoring_date
		&& time < $setRecord->due_date)
	{
		$status = $r->maketext('Reduced Scoring Period');
	} elsif (time > $setRecord->due_date && time < $setRecord->answer_date) {
		$status = $r->maketext('Closed');
	} else {
		$status     = $r->maketext('Answers Available');
		$statusHelp = CGI::a(
			{
				class           => 'help-popup ms-2',
				data_bs_content => $r->maketext(
					'Answer availability for gateway quizzes depends on multiple gateway quiz settings. This only '
						. 'indicates the template answer date has passed. See set editor for actual availability.'
				),
				data_bs_placement => 'top',
				data_bs_toggle    => 'popover',
				role              => 'button',
				tabindex          => 0
			},
			CGI::i(
				{
					class       => 'icon fas fa-question-circle',
					data_alt    => $r->maketext('Help Icon'),
					aria_hidden => 'true'
				},
				''
			)
		) if $setRecord->assignment_type =~ /gateway/;
	}
	$status .= ' (' . $r->maketext('Hidden') . ')' unless $setRecord->visible;

	print CGI::div({ class => 'mb-3' }, $r->maketext('Showing statistics for:') . $filterMenu . $problemMenu);

	print CGI::div(
		{ class => 'table-responsive' },
		CGI::table(
			{ class => 'stats-table table table-bordered', style => 'width: auto' },
			CGI::Tr(
				CGI::th(
					$r->maketext('Status')
						. CGI::a(
							{
								class           => 'help-popup ms-2',
								data_bs_content => $r->maketext(
									'This gives the status and dates of the main set. '
									. 'Indvidual students may have different settings.'
								),
								data_bs_placement => 'top',
								data_bs_toggle    => 'popover',
								role              => 'button',
								tabindex          => 0
							},
							CGI::i(
								{
									class       => 'icon fas fa-question-circle',
									data_alt    => $r->maketext('Help Icon'),
									aria_hidden => 'true'
								},
								''
							)
						)
				),
				CGI::td($status . $statusHelp)
			),
			CGI::Tr(CGI::th($r->maketext('Number of Students')), CGI::td(scalar(@score_list))),
			CGI::Tr(
				CGI::th($r->maketext('Open Date')),
				CGI::td($self->formatDateTime($setRecord->open_date, undef, $ce->{studentDateDisplayFormat}))
			),
			$setRecord->enable_reduced_scoring
			? CGI::Tr(
				CGI::th($r->maketext('Reduced Scoring Date')),
				CGI::td($self->formatDateTime(
					$setRecord->reduced_scoring_date, undef, $ce->{studentDateDisplayFormat}
				))
				)
			: '',
			CGI::Tr(
				CGI::th($r->maketext('Close Date')),
				CGI::td($self->formatDateTime($setRecord->due_date, undef, $ce->{studentDateDisplayFormat}))
			),
			CGI::Tr(
				CGI::th($r->maketext('Answer Date')),
				CGI::td($self->formatDateTime($setRecord->answer_date, undef, $ce->{studentDateDisplayFormat}))
			),
		)
	);

	# Overall Stats.
	print CGI::h2($r->maketext('Overall Results'));

	# Histogram of total scores.
	my @buckets = map {0} 1 .. 10;
	foreach (@score_list) { $buckets[ $_ > 0.995 ? 9 : int(10 * $_ + 0.05) ]++ }
	my $maxCount = 0;
	foreach (@buckets) { $maxCount = $_ if $_ > $maxCount; }
	$maxCount = int($maxCount / 5) + 1;
	print $self->buildBarChart(
		[ reverse(@buckets) ],
		xAxisLabels => [ '90-100', '80-89', '70-79', '60-69', '50-59', '40-49', '30-39', '20-29', '10-19', '0-9' ],
		yMax        => 5 * $maxCount,
		yAxisLabels => [ map { $_ * $maxCount } 0 .. 5 ],
		mainTitle   => $r->maketext('Overall Set Grades'),
		xTitle      => $r->maketext('Percent Ranges'),
		yTitle      => $r->maketext('Number of Students'),
		barWidth    => 35,
		barSep      => 5,
		isPercent   => 0,
		leftMargin  => 40 + 5 * length(5 * $maxCount),
	);

	# Success index help icon.
	my $successHelp = CGI::a(
		{
			class           => 'help-popup ms-2',
			data_bs_content => $r->maketext(
				'Success index is the square of the average score divided by the average number of attempts.'),
			data_bs_placement => 'top',
			data_bs_toggle    => 'popover',
			role              => 'button',
			tabindex          => 0
		},
		CGI::i(
			{
				class       => 'icon fas fa-question-circle',
				data_alt    => $r->maketext('Help Icon'),
				aria_hidden => 'true'
			},
			''
		)
	);

	# Overall Average
	my ($mean, $stddev) = $self->computeStats(@score_list);
	my ($avgAttempts) = $self->computeStats(grep(!/-/, @avgAttempts));
	my $overallSuccess = $avgAttempts ? $mean**2 / $avgAttempts : 0;
	($overallSuccess) = $self->computeStats(@index_list);
	print CGI::div(
		{ class => 'table-responsive' },
		CGI::table(
			{ class => 'stats-table table table-bordered', style => 'width: auto;' },
			CGI::Tr(CGI::th($r->maketext('Total Points')),                 CGI::td($totalValue)),
			CGI::Tr(CGI::th($r->maketext('Average Percent')),              CGI::td(sprintf('%0.1f', 100 * $mean))),
			CGI::Tr(CGI::th($r->maketext('Standard Deviation')),           CGI::td(sprintf('%0.1f', 100 * $stddev))),
			CGI::Tr(CGI::th($r->maketext('Average Attempts Per Problem')), CGI::td(sprintf('%0.1f', $avgAttempts))),
			CGI::Tr(
				CGI::th($r->maketext('Overall Success Index') . $successHelp),
				CGI::td(sprintf('%0.1f', 100 * $overallSuccess))
			),
		)
	);

	# Table showing percentile statistics for scores and success indices.
	print CGI::p(
		$r->maketext(
			'The percentage of students receiving at least these scores. The median score is in the 50% column.')
	);
	print $self->bracketTable(
		[ 90,                                                 80, 70, 60, 50, 40, 30, 20, 10 ],
		[ [ map { sprintf('%0.0f', 100 * $_) } @score_list ], [ map { sprintf('%0.0f', 100 * $_) } @index_list ] ],
		[ $r->maketext('Percent Score'),                      $r->maketext('Success Index') . $successHelp ],
		showMax => 1,
	);

	# Individual problem stats.
	print CGI::h2($r->maketext('Individual Problem Results'));

	# SVG bar graph showing the percentage of students with correct answers for each problem.
	my (@problemData, @problemLabels, @jitarBars);
	for (my $i = 0; $i <= $#problems; $i++) {
		my $probID = $problems[$i]->problem_id;

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
		push(@problemData,
			$num_students_attempting_problem{$probID}
			? sprintf('%0.2f', $total_status_for_problem{$probID} / $num_students_attempting_problem{$probID})
			: 0);                        # Avoid division by zero

		my $prettyID = $prettyIDs{$probID};
		$prettyID = '##' if (length($prettyID) > 4);
		push(@problemLabels, $prettyID);
	}

	print $self->buildBarChart(
		\@problemData,
		yAxisLabels => [ '0%', '20%', '40%', '60%', '80%', '100%' ],
		xAxisLabels => \@problemLabels,
		mainTitle   => $r->maketext('Grade of Active Students'),
		xTitle      => $r->maketext('Problem Number'),
		isJitarSet  => $isJitarSet,
		jitarBars   => $isJitarSet ? \@jitarBars : [],
		barLinks    => \@problemHref,
	);

	# Table showing indvidual problem stats.
	@problemLabels = ($r->maketext('Problem Number'), $r->maketext('Point Value'), $r->maketext('Average Percent'));
	@problemData   = (\@problemIDLinks, \@problemValues, \@avgScore);
	if ($isJitarSet) {
		push(@problemLabels, $r->maketext('% Average with Review'));
		push(@problemData,   \@adjScore);
	}
	push(@problemLabels,
		$r->maketext('Average Attempts'),
		$r->maketext('Success Index') . $successHelp,
		$r->maketext('# of Active Students'));
	push(@problemData, \@avgAttempts, \@successList, \@numActive);
	if ($showGradeRow) {
		push(@problemLabels, $r->maketext('Manual Grader'));
		push(@problemData,   \@GradeableRows);
	}
	print $self->statsTable(\@problemLabels, \@problemData);

	# Table showing percentile statistics for scores and success indices.
	print CGI::p(
		$r->maketext(
			'Percentile cutoffs for number of attempts. The 50% column shows the median number of attempts.')
	);
	print $self->bracketTable([ 95, 75, 50, 25, 5, 1 ], \@attemptsList, \@problemLinks, reverse => 1);

	return '';
}

sub displayProblem {
	my $self          = shift;
	my $r             = $self->r;
	my $urlpath       = $r->urlpath;
	my $db            = $r->db;
	my $ce            = $r->ce;
	my $user          = $r->param('user');
	my $courseID      = $urlpath->arg('courseID');
	my $setName       = $self->{setName};
	my $problemID     = $urlpath->arg('problemID');
	my $prettyID      = $self->{prettyID};
	my $setRecord     = $self->{setRecord};
	my $problemRecord = $self->{problemRecord};
	my $isJitarSet    = $setRecord->assignment_type eq 'jitar';
	my $topLevelJitar = $prettyID !~ /\./;

	unless ($setRecord) {
		print CGI::div({ class => 'alert alert-danger p-1' }, $r->maketext('Global set [_1] not found.', $setName));
		return;
	}
	unless ($problemRecord) {
		print CGI::div({ class => 'alert alert-danger p-1' },
			$r->maketext('Global problem [_1] not found for set [_2].', $prettyID, $setName));
		return;
	}

	my ($filterMenu, @studentRecords) = $self->get_students;
	my (@problemScores, @adjustedScores, @problemAttempts, @successList);
	my $activeStudents   = 0;
	my $inactiveStudents = 0;
	for my $studentRecord (@studentRecords) {
		my $student = $studentRecord->user_id;
		my $studentProblem;

		if ($setRecord->assignment_type =~ /gateway/) {
			my @problemRecords =
				$db->getProblemVersionsWhere(
					{ user_id => $student, problem_id => $problemID, set_id => { like => "$setName,v\%" } });
			my $maxRecord = 0;
			my $maxStatus = 0;
			foreach (0 .. $#problemRecords) {
				if ($problemRecords[$_]->status > $maxStatus) {
					$maxRecord = $_;
					$maxStatus = $problemRecords[$_]->status;
				}
			}
			$studentProblem = $problemRecords[$maxRecord];
		} else {
			$studentProblem = $db->getMergedProblem($student, $setName, $problemID);
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

	my ($problemMenu) = $self->get_problems;
	print CGI::div({ class => 'mb-3' }, $r->maketext('Showing statistics for:') . $filterMenu . $problemMenu);

	# Histogram of total scores.
	my @buckets = map {0} 1 .. 10;
	foreach (@problemScores) { $buckets[ $_ > 0.995 ? 9 : int(10 * $_ + 0.05) ]++ }
	my $maxCount = 0;
	foreach (@buckets) { $maxCount = $_ if $_ > $maxCount; }
	my @jitarBars = ();
	if ($isJitarSet && $topLevelJitar) {
		@jitarBars = map {0} 1 .. 10;
		foreach (@adjustedScores) { $jitarBars[ $_ > 0.995 ? 9 : int(10 * $_ + 0.05) ]++ }
		foreach (@jitarBars)      { $maxCount = $_ if $_ > $maxCount; }
	}
	$maxCount = int($maxCount / 5) + 1;
	print $self->buildBarChart(
		[ reverse(@buckets) ],
		xAxisLabels => [ '90-100', '80-89', '70-79', '60-69', '50-59', '40-49', '30-39', '20-29', '10-19', '0-9' ],
		yMax        => 5 * $maxCount,
		yAxisLabels => [ map { $_ * $maxCount } 0 .. 5 ],
		mainTitle   => $r->maketext('Active Students Problem [_1] Grades', $prettyID),
		xTitle      => $r->maketext('Percent Ranges'),
		yTitle      => $r->maketext('Number of Students'),
		barWidth    => 35,
		barSep      => 5,
		isPercent   => 0,
		leftMargin  => 40 + 5 * length(5 * $maxCount),
		isJitarSet  => ($isJitarSet && $topLevelJitar),
		jitarBars   => [ reverse(@jitarBars) ],
	);

	# Success index help icon.
	my $successHelp = CGI::a(
		{
			class           => 'help-popup ms-2',
			data_bs_content => $r->maketext(
				'Success index is the square of the average score divided by the average number of attempts.'),
			data_bs_placement => 'top',
			data_bs_toggle    => 'popover',
			role              => 'button',
			tabindex          => 0
		},
		CGI::i(
			{
				class       => 'icon fas fa-question-circle',
				data_alt    => $r->maketext('Help Icon'),
				aria_hidden => 'true'
			},
			''
		)
	);
	my $successHelp2 = CGI::a(
		{
			class           => 'help-popup ms-2',
			data_bs_content =>
				$r->maketext('Success index is the square of the score divided by the number of attempts.'),
			data_bs_placement => 'top',
			data_bs_toggle    => 'popover',
			role              => 'button',
			tabindex          => 0
		},
		CGI::i(
			{
				class       => 'icon fas fa-question-circle',
				data_alt    => $r->maketext('Help Icon'),
				aria_hidden => 'true'
			},
			''
		)
	);

	# Overall Average
	my ($mean,  $stddev)  = $self->computeStats(@problemScores);
	my ($mean2, $stddev2) = $self->computeStats(@problemAttempts);
	my $successIndex = $mean2 ? $mean**2 / $mean2 : 0;
	print CGI::div(
		{ class => 'table-responsive' },
		CGI::table(
			{ class => 'stats-table table table-bordered', style => 'width: auto;' },
			CGI::Tr(CGI::th($r->maketext('Point Value')),        CGI::td($problemRecord->value)),
			CGI::Tr(CGI::th($r->maketext('Average Percent')),    CGI::td(sprintf('%0.1f', 100 * $mean))),
			CGI::Tr(CGI::th($r->maketext('Standard Deviation')), CGI::td(sprintf('%0.1f', 100 * $stddev))),
			CGI::Tr(CGI::th($r->maketext('Average Attempts')),   CGI::td(sprintf('%0.1f', $mean2))),
			CGI::Tr(
				CGI::th($r->maketext('Success Index') . $successHelp),
				CGI::td(sprintf('%0.1f', 100 * $successIndex))
			),
			CGI::Tr(CGI::th($r->maketext('Active Students')),   CGI::td($activeStudents)),
			CGI::Tr(CGI::th($r->maketext('Inactive Students')), CGI::td($inactiveStudents)),
		)
	);

	# Table showing percentile statistics for scores.
	print CGI::p($r->maketext(
		'Percentile cutoffs for student\'s score and success index. '
			. 'The 50% column shows the median number of attempts.'
	));
	my @tableHeaders = ($r->maketext('Percent Score'));
	my @tableData    = ([ map { sprintf('%0.0f', 100 * $_) } @problemScores ]);
	if ($isJitarSet && $topLevelJitar) {
		push(@tableHeaders, $r->maketext('% Score with Review'));
		push(@tableData,    [ map { sprintf('%0.0f', 100 * $_) } @adjustedScores ]);
	}
	push(@tableHeaders, $r->maketext('Success Index') . $successHelp2);
	push(@tableData,    [ map { sprintf('%0.0f', 100 * $_) } @successList ]);
	print $self->bracketTable([ 90, 80, 70, 60, 50, 40, 30, 20, 10 ], \@tableData, \@tableHeaders, showMax => 1,);

	# Table showing attempts percentiles
	print CGI::p(
		$r->maketext(
			'Percentile cutoffs for number of attempts. The 50% column shows the median number of attempts.')
	);
	print $self->bracketTable(
		[ 95, 75, 50, 25, 5, 1 ],
		[ \@problemAttempts ],
		[ $r->maketext('# of attempts') ],
		reverse => 1
	);

	# Render Problem
	print "\n"
		. CGI::div(
			{
				style => 'background-color: #f5f5f5; border: 1px solid #e3e3e3; border-radius: 4px;',
				class => 'mt-3 p-3'
			},
			$self->hidden_authen_fields,
			CGI::input({ type => 'hidden', id => 'hidden_course_id',  name => 'courseID',  value => $courseID }),
			CGI::input({ type => 'hidden', id => 'hidden_set_id',     name => 'setID',     value => $setName }),
			CGI::input({ type => 'hidden', id => 'hidden_problem_id', name => 'problemID', value => $problemID }),
			CGI::input({
				type  => 'hidden',
				id    => 'hidden_source_file',
				name  => 'sourceFilePath',
				value => $problemRecord->source_file
			}),
			CGI::div(
				CGI::a(
					{ id => 'pdr_render', class => 'btn btn-primary', role => 'button', tabindex => 0 },
					$r->maketext('Render Problem')
				),
				CGI::a(
					{
						class => 'btn btn-primary',
						href  => $self->systemLink($urlpath->new(
							type => 'instructor_problem_editor_withset_withproblem',
							args => { courseID => $courseID, setID => $setName, problemID => $problemID }
						))
					},
					$r->maketext('Edit Problem')
				)
			),
			CGI::div({ id => 'psr_render_area', class => 'psr_render_area m-3' }, '')
		);

	return '';
}

# Determines the percentage of students whose score is greater than a given value.
sub determinePercentiles {
	my $self             = shift;
	my $percent_brackets = shift;
	my @list_of_scores   = sort { $a <=> $b } @_;
	my $num_students     = $#list_of_scores;
	# For example, $percentiles{75} = @list_of_scores[int(25 * $num_students / 100)]
	# means that 75% of the students received this score $percentiles{75} or higher.
	my %percentiles = map { $_ => @list_of_scores[ int((100 - $_) * $num_students / 100) ] // 0 } @$percent_brackets;
	$percentiles{max} = $list_of_scores[-1];
	$percentiles{min} = $list_of_scores[0];
	return %percentiles;
}

# Replace an array such as "[0, 0, 0, 86, 86, 100, 100, 100]" by "[0, '-', '-', 86, '-', 100, '-', '-']"
sub preventRepeats {
	my $self    = shift;
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

# Create percentile bracket table.
sub bracketTable {
	my $self     = shift;
	my $r        = $self->r;
	my $brackets = shift;
	my $data     = shift;
	my $heads    = shift;
	my %opts     = (
		reverse  => 0,
		showMax  => 0,
		maxTitle => $r->maketext('Top Score'),
		@_
	);
	my @headOut = ($r->maketext('Percent of Students'));
	my @dataOut = @$brackets;
	push(@dataOut, $r->maketext('Top Score')) if $opts{showMax};
	@dataOut = ([@dataOut]);

	while (@$data) {
		my $row = shift(@$data);
		my %percentiles =
			ref($row) eq 'ARRAY' ? $self->determinePercentiles($brackets, @$row) : map { $_ => '-' } @$brackets;
		my @tableData = map { $percentiles{$_} } @$brackets;
		@tableData = reverse(@tableData)               if $opts{reverse};
		@tableData = $self->preventRepeats(@tableData) if ref($row) eq 'ARRAY';
		push(@tableData, $opts{reverse} ? $percentiles{min} : $percentiles{max}) if $opts{showMax};
		push(@headOut,   shift(@$heads));
		push(@dataOut,   \@tableData);
	}
	return $self->statsTable(\@headOut, \@dataOut);
}

sub statsTable {
	my $self  = shift;
	my $heads = shift;
	my $data  = shift;
	my $out =
		CGI::start_div({ class => 'table-responsive' })
		. CGI::start_table({ class => 'stats-table table table-bordered' });

	while (@$data) {
		$out .= CGI::Tr(CGI::th(shift(@$heads)), CGI::td({ class => 'text-center' }, shift(@$data)));
	}
	$out .= CGI::end_table . CGI::end_div;
	return $out;
}

# Compute Mean / Std Deviation.
sub computeStats {
	my $self = shift;
	my @data = @_;
	my $n    = scalar(@data);
	return (0, 0, 0) unless ($n > 0);
	my $sum = 0;
	foreach (@data) { $sum += $_; }
	my $mean = sprintf('%0.4g', $sum / $n);
	my $sum2 = 0;
	foreach (@data) { $sum2 += ($_ - $mean)**2; }
	my $stddev = ($n > 1) ? sqrt($sum2 / ($n - 1)) : 0;
	return ($mean, $stddev, $sum);
}

# Create SVG bar graph from input data.
sub buildBarChart {
	my $self = shift;
	my $r    = $self->r;
	my $data = shift;
	return '' unless (@$data);
	$self->{barCount} = 1 unless $self->{barCount};
	my $id   = $self->{barCount}++;
	my %opts = (
		yAxisLabels  => [],
		xAxisLabels  => [],
		yAxisTicks   => 9,
		yMax         => 1,
		isPercent    => 1,
		isJitarSet   => 0,
		jitarBars    => [],
		barLinks     => [],
		mainTitle    => '',
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
		@_,
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
		-inline          => 1,
		id               => "bar_graph_$id",
		height           => '100%',
		width            => '100%',
		viewbox          => '-2 -2 ' . ($imageWidth + 3) . ' ' . ($imageHeight + 3),
		'aria-labeledby' => 'bar_graph_title',
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
	)->cdata($opts{mainTitle})
		if ($opts{mainTitle});
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
		)->cdata($r->maketext('Correct Adjusted Status'));
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
		)->cdata($r->maketext('Correct Status'));
	}

	# y-axis labels.
	$n = scalar(@{ $opts{yAxisLabels} }) - 1;
	my $yOffset = int($opts{plotHeight} / (10 * $n));
	foreach (0 .. $n) {
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
	foreach (1 .. $opts{yAxisTicks}) {
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
	foreach (0 .. $n) {
		my $xPos    = $opts{leftMargin} + $_ * $barWidth + $opts{barSep};
		my $yHeight = int($opts{plotHeight} * $data->[$_] / $opts{yMax} + 0.5);
		if ($opts{isJitarSet} && $opts{jitarBars}->[$_] > 0) {
			my $jHeight = int($opts{plotHeight} * $opts{jitarBars}->[$_] / $opts{yMax} + 0.5);
			$svg->rect(
				x              => $xPos,
				y              => $opts{topMargin} + $opts{plotHeight} - $jHeight,
				width          => $opts{barWidth} + $opts{barSep},
				height         => $jHeight,
				fill           => $opts{jitarFill},
				'data-tooltip' => $opts{isPercent} ? (100 * $opts{jitarBars}->[$_]) . '%' : $opts{jitarBars}->[$_],
				class          => 'bar_graph_bar',
			);
		}
		my $tag = @{ $opts{barLinks} } ? $svg->anchor(-href => $opts{barLinks}->[$_]) : $svg;
		$tag->rect(
			x              => $xPos,
			y              => $opts{topMargin} + $opts{plotHeight} - $yHeight,
			width          => $opts{barWidth},
			height         => $yHeight,
			fill           => $opts{barFill},
			'data-tooltip' => $opts{isPercent} ? (100 * $data->[$_]) . '%' : $data->[$_],
			class          => 'bar_graph_bar',
		);
		$tag->text(
			x             => $xPos + $opts{barWidth} / 2,
			y             => $imageHeight - $opts{bottomMargin} + 15,
			'font-family' => 'sans-serif',
			'text-anchor' => 'middle',
			'font-size'   => 12,
		)->cdata($opts{xAxisLabels}->[$_]);
	}

	# Tooltip div. Only include once.
	my $tooltip = ($id > 1) ? '' : CGI::div(
		{
			id    => 'bar_tooltip',
			style =>
				'position: absolute; display: none; background: cornsilk; border: 1px solid black; border-radius: 5px; padding: 5px;'
		},
		''
	);

	return $tooltip . CGI::div({ class => 'img-fluid mb-3', style => "max-width: ${imageWidth}px" }, $svg->render);
}

1;
