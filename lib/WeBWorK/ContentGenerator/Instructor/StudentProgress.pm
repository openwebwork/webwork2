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
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::StudentProgress - Display Student Progress.

=cut

use strict;
use warnings;

use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::ContentGenerator::Grades;
use WeBWorK::Utils qw(jitar_id_to_seq wwRound grade_set format_set_name_display);
use WeBWorK::Utils::Grades qw/list_set_versions/;

# The table format has been borrowed from the Grades.pm module
sub initialize {
	my $self       = shift;
	my $r          = $self->{r};
	my $urlpath    = $r->urlpath;
	my $type       = $urlpath->arg("statType") || '';
	my $db         = $self->{db};
	my $ce         = $self->{ce};
	my $authz      = $self->{authz};
	my $courseName = $urlpath->arg('courseID');
	my $user       = $r->param('user');

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");

	$self->{type} = $type;
	if ($type eq 'student') {
		my $studentName = $r->urlpath->arg("userID") || $user;
		$self->{studentName} = $studentName;

	} elsif ($type eq 'set') {
		my $setName = $r->urlpath->arg("setID") || 0;
		$self->{setName} = $setName;
		my $setRecord = $db->getGlobalSet($setName);    # checked
		die "global set $setName  not found." unless $setRecord;
		$self->{set_due_date} = $setRecord->due_date;
		$self->{setRecord}    = $setRecord;
	}
}

sub title {
	my ($self) = @_;
	my $r      = $self->r;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	# Check permissions
	return '' unless $authz->hasPermissions($user, 'access_instructor_tools');

	my $type = $self->{type};
	if ($type eq 'student') {
		return $r->maketext('Student Progress for [_1] student [_2]', $self->{ce}->{courseName}, $self->{studentName});
	} elsif ($type eq 'set') {
		return $r->maketext(
			'Student Progress for [_1] set [_2]. Closes [_3]',
			$self->{ce}->{courseName},
			CGI::span({ dir => 'ltr' }, format_set_name_display($self->{setName})),
			$self->formatDateTime($self->{set_due_date})
		);
	}

	return $r->maketext('Student Progress');
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
	print CGI::h2($r->maketext('Student Progress'));

	# List links depending on if viewing set progress or student progress
	if ($self->{type} eq 'student') {
		my $ce   = $r->ce;
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

		print CGI::start_ul({ class => 'nav flex-column problem-list' });
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
		print CGI::end_ul();
	} else {
		my @setIDs = sort $db->listGlobalSets;

		print CGI::start_ul({ class => 'nav flex-column problem-list', dir => 'ltr' });
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
						: (href => $self->systemLink($problemPage), class => 'nav-link')
					},
					format_set_name_display($setID)
				)
			);
		}
		print CGI::end_ul();
	}

	print CGI::end_div();

	return '';
}

sub body {
	my $self       = shift;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $authz      = $r->authz;
	my $user       = $r->param('user');
	my $courseName = $urlpath->arg("courseID");
	my $type       = $self->{type};

	# Check permissions
	return CGI::div({ class => 'alert alert-danger p-1' } . "You are not authorized to access instructor tools")
		unless $authz->hasPermissions($user, "access_instructor_tools");

	if ($type eq 'student') {
		my $studentName   = $self->{studentName};
		my $studentRecord = $db->getUser($studentName)    # checked
			or die "record for user $studentName not found";
		my $fullName       = $studentRecord->full_name;
		my $courseHomePage = $urlpath->new(
			type => 'set_list',
			args => { courseID => $courseName }
		);
		my $email = $studentRecord->email_address;

		print CGI::a({ -href => "mailto:$email" }, $email), CGI::br(),
			$r->maketext("Section") . ": ",    $studentRecord->section,    CGI::br(),
			$r->maketext("Recitation") . ": ", $studentRecord->recitation, CGI::br();

		if ($authz->hasPermissions($user, "become_student")) {
			my $act_as_student_url = $self->systemLink($courseHomePage, params => { effectiveUser => $studentName });

			print $r->maketext("Act as:") . " " . CGI::a({ -href => $act_as_student_url }, $studentRecord->user_id);
		}

		print WeBWorK::ContentGenerator::Grades::displayStudentStats($self, $studentName);
	} elsif ($type eq 'set') {
		$self->displaySets($self->{setName});
	} elsif ($type eq '') {
		$self->index;
	} else {
		warn "Don't recognize statistics display type: |$type|";

	}

	return '';

}

sub index {
	my $self       = shift;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $ce         = $r->ce;
	my $db         = $r->db;
	my $courseName = $urlpath->arg("courseID");

	my $user = $r->param("user");

	# Get all users except the set level proctors, and restrict to the sections or recitations that are allowed for the
	# user if such restrictions are defined.  This list is sorted by last_name, then first_name, then user_id.
	my @studentRecords = $db->getUsersWhere(
		{
			user_id => { not_like => 'set_id:%' },
			$ce->{viewable_sections}{$user} || $ce->{viewable_recitations}{$user}
			? (
				-or => [
					$ce->{viewable_sections}{$user} ? (section => { -in => $ce->{viewable_sections}{$user} }) : (),
					$ce->{viewable_recitations}{$user}
					? (recitation => { -in => $ce->{viewable_recitations}{$user} })
					: ()
				]
				)
			: ()
		},
		[qw/last_name first_name user_id/]
	);

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

	for my $studentRecord (@studentRecords) {
		my $first_name         = $studentRecord->first_name;
		my $last_name          = $studentRecord->last_name;
		my $user_id            = $studentRecord->user_id;
		my $userStatisticsPage = $urlpath->newFromModule(
			$urlpath->module, $r,
			courseID => $courseName,
			statType => 'student',
			userID   => $user_id
		);

		push @studentLinks,
			CGI::a({ href => $self->systemLink($userStatisticsPage) }, "$last_name, $first_name  ($user_id)");
	}

	print CGI::div(
		{ class => 'row g-0' },
		CGI::div(
			{ class => 'col-lg-5 col-sm-6 border border-dark' },
			CGI::h2({ class => 'text-center fs-3' }, $r->maketext('View student progress by set')),
			CGI::ul({ dir   => 'ltr' }, CGI::li([@setLinks]))
		),
		CGI::div(
			{ class => 'col-lg-5 col-sm-6 border border-dark' },
			CGI::h2({ class => 'text-center fs-3' }, $r->maketext('View student progress by student')),
			CGI::ul(CGI::li([@studentLinks]))
		)
	);
}

# Display student progress table
sub displaySets {
	my $self       = shift;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $authz      = $r->authz;
	my $courseName = $urlpath->arg("courseID");
	my $setName    = $urlpath->arg("setID");
	my $user       = $r->param('user');
	my $GlobalSet  = $self->{setRecord};
	my $root       = $ce->{webworkURLs}->{root};
	my $setStatsPage =
		$urlpath->newFromModule($urlpath->module, $r, courseID => $courseName, statType => 'sets', setID => $setName);
	my $primary_sort_method_name   = $r->param('primary_sort');
	my $secondary_sort_method_name = $r->param('secondary_sort');
	my $ternary_sort_method_name   = $r->param('ternary_sort');

	# another versioning/gateway change.  in many cases we don't want or need
	# all of the columns that are put in here by default, so we add a set of
	# flags for which columns to show.  for versioned sets we may also want to
	# only see the best score, so we include that as an option also.
	# these are ignored for non-versioned sets
	my %showColumns = (
		'name'     => 1,
		'score'    => 1,
		'outof'    => 1,
		'date'     => 0,
		'testtime' => 0,
		'login'    => 1,
		'problems' => 1,
		'section'  => 1,
		'recit'    => 1,
	);
	my $showBestOnly = 0;

	my @score_list  = ();     # list of all student total percentage scores
	my $sort_method = sub {
		my ($a, $b, $sort_method_name) = @_;
		return 0 unless defined($sort_method_name);
		return lc($a->{last_name}) cmp lc($b->{last_name})         if $sort_method_name eq 'last_name';
		return lc($a->{first_name}) cmp lc($b->{first_name})       if $sort_method_name eq 'first_name';
		return lc($a->{email_address}) cmp lc($b->{email_address}) if $sort_method_name eq 'email_address';
		return $b->{score} <=> $a->{score}                         if $sort_method_name eq 'score';
		return lc($a->{section}) cmp lc($b->{section})             if $sort_method_name eq 'section';
		return lc($a->{recitation}) cmp lc($b->{recitation})       if $sort_method_name eq 'recitation';
		return lc($a->{user_id}) cmp lc($b->{user_id})             if $sort_method_name eq 'user_id';
	};
	my %display_sort_method_name = (
		last_name     => $r->maketext('last name'),
		first_name    => $r->maketext('first name'),
		email_address => $r->maketext('email address'),
		score         => $r->maketext('score'),
		section       => $r->maketext('section'),
		recitation    => $r->maketext('recitation'),
		user_id       => $r->maketext('login name'),
	);

	# get versioning information
	my $setIsVersioned =
		(defined($GlobalSet->assignment_type()) && $GlobalSet->assignment_type() =~ /gateway/) ? 1 : 0;

	# reset column view options based on whether the set is versioned and, if so,
	# the input parameters
	if ($setIsVersioned) {
		# the returning parameter lets us set defaults for versioned sets
		my $ret = defined($r->param('returning')) ? $r->param('returning') : 0;
		$showColumns{'date'}     = ($ret && !defined($r->param('show_date')))      ? $r->param('show_date')       : 1;
		$showColumns{'testtime'} = ($ret && !defined($r->param('show_testtime')))  ? $r->param('show_testtime')   : 1;
		$showColumns{'problems'} = ($ret && defined($r->param('show_problems')))   ? $r->param('show_problems')   : 0;
		$showColumns{'section'}  = ($ret && defined($r->param('show_section')))    ? $r->param('show_section')    : 0;
		$showColumns{'recit'}    = ($ret && defined($r->param('show_recitation'))) ? $r->param('show_recitation') : 0;
		$showColumns{'login'}    = ($ret && defined($r->param('show_login')))      ? $r->param('show_login')      : 0;
		$showBestOnly            = ($ret && defined($r->param('show_best_only')))  ? $r->param('show_best_only')  : 0;
	}

	# Get all users except the set level proctors and practice users, and restrict to the sections or recitations that
	# are allowed for the user if such restrictions are defined.  This list is sorted by last_name, then first_name,
	# then user_id.
	debug("Begin obtaining user records for set $setName");
	my @studentRecords = $db->getUsersWhere(
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
	);
	debug("End obtaining user records for set $setName");

	debug("begin main loop");
	my @augmentedUserRecords = ();

	foreach my $studentRecord (@studentRecords) {
		my $studentName = $studentRecord->user_id;
		next unless $ce->status_abbrev_has_behavior($studentRecord->status, "include_in_stats");

		my ($ra_allSetVersionNames, $notAssignedSet) = list_set_versions($db, $studentName, $setName, $setIsVersioned);
		my @allSetVersionNames = @{$ra_allSetVersionNames};

		# for versioned sets, we might be keeping only the high score
		my $maxScore = -1;
		my $max_hash = {};

		foreach my $setName (@allSetVersionNames) {
			my $set;
			my $vNum = 0;

			# For versioned tests we might be displaying the test date and test time.
			my $dateOfTest = '';
			my $testTime   = '';

			if ($setIsVersioned) {
				($setName, $vNum) = ($setName =~ /(.+),v(\d+)$/);
				# we'll also need information from the set
				# as we set up the display below, so get
				# the merged userset as well
				$set        = $db->getMergedSetVersion($studentRecord->user_id, $setName, $vNum);
				$dateOfTest = localtime($set->version_creation_time());
				if (defined $set->version_last_attempt_time() && $set->version_last_attempt_time()) {
					$testTime = ($set->version_last_attempt_time() - $set->open_date()) / 60;
					my $timeLimit = $set->version_time_limit() / 60;
					$testTime = $timeLimit if ($testTime > $timeLimit);
					$testTime = sprintf("%3.1f min", $testTime);
				} elsif (time() - $set->open_date() < $set->version_time_limit()) {
					$testTime = $r->maketext('still open');
				} else {
					$testTime = $r->maketext('time limit exceeded');
				}
			} else {
				$set = $db->getMergedSet($studentName, $setName);
			}

			$set = $db->newUserSet(set_id => $setName) unless ref $set;

			my $email = $studentRecord->email_address;
			my ($score, $total, $problem_scores, $problem_incorrect_attempts) =
				grade_set($db, $set, $studentName, $setIsVersioned, 1);
			$score = wwRound(2, $score);

			# Construct problems row
			my $problemsRow = [
				map {
					CGI::span(
						{
							class => $problem_scores->[$_] eq '100' ? 'correct'
							: $problem_scores->[$_] eq '&nbsp;.&nbsp;' ? 'unattempted'
							:                                            ''
						},
						$problem_scores->[$_]
						)
						. CGI::br()
						. ($problem_incorrect_attempts->[$_] // '&nbsp;')
				} 0 .. $#$problem_scores
			];

			$problemsRow = ['&nbsp;'] if !@$problemsRow;

			my $temp_hash = {
				user_id       => $studentRecord->user_id,
				last_name     => $studentRecord->last_name,
				first_name    => $studentRecord->first_name,
				version       => $vNum,
				score         => $score,
				total         => $total,
				section       => $studentRecord->section,
				recitation    => $studentRecord->recitation,
				problemsRow   => $problemsRow,
				email_address => $studentRecord->email_address,
				date          => $dateOfTest,
				testtime      => $testTime,
			};

			# keep track of best score
			if ($score > $maxScore) {
				$maxScore = $score;
				$max_hash = {%$temp_hash};
			}

			# if we're showing all records, add it in to the list
			if (!$showBestOnly) {
				# add this data to the list of total scores (out of 100)
				# add this data to the list of success indices.
				push(@score_list,           ($temp_hash->{total}) ? $temp_hash->{score} / $temp_hash->{total} : 0);
				push(@augmentedUserRecords, $temp_hash);
			}

		}    # this closes the loop through all set versions

		# if we're showing only the best score, add the best score now
		if ($showBestOnly) {
			# If there's no %$max_hash, then we had no results.
			# This occurs for proctors, for example.
			if ($notAssignedSet) {
				next;
			} elsif (!%$max_hash) {
				$max_hash = {
					user_id       => $studentRecord->user_id(),
					last_name     => $studentRecord->last_name(),
					first_name    => $studentRecord->first_name(),
					score         => 0,
					total         => 'n/a',
					section       => $studentRecord->section(),
					recitation    => $studentRecord->recitation(),
					problemsRow   => [ $r->maketext('no attempt recorded') ],
					email_address => $studentRecord->email_address(),
					date          => 'n/a',
					testtime      => 'n/a',
				};
			}

			push(@score_list,
				($max_hash->{total} && $max_hash->{total} ne 'n/a') ? $max_hash->{score} / $max_hash->{total} : 0);
			push(@augmentedUserRecords, $max_hash);
			# if there were no set versions and the set was assigned
			# to the user, also keep the data
		} elsif (!@allSetVersionNames && !$notAssignedSet) {
			my $dataH = {
				user_id       => $studentRecord->user_id(),
				last_name     => $studentRecord->last_name(),
				first_name    => $studentRecord->first_name(),
				score         => 0,
				total         => 'n/a',
				section       => $studentRecord->section(),
				recitation    => $studentRecord->recitation(),
				problemsRow   => ['&nbsp;'],
				email_address => $studentRecord->email_address(),
				date          => 'n/a',
				testtime      => 'n/a',
			};
			push(@score_list,           0);
			push(@augmentedUserRecords, $dataH);
		}
	}    # this closes the loop through all student records
	debug("end mainloop");

	@augmentedUserRecords = sort {
		&$sort_method($a, $b, $primary_sort_method_name)
			|| &$sort_method($a, $b, $secondary_sort_method_name)
			|| &$sort_method($a, $b, $ternary_sort_method_name)
			|| lc($a->{last_name}) cmp lc($b->{last_name})
			|| lc($a->{first_name}) cmp lc($b->{first_name})
			|| lc($a->{user_id}) cmp lc($b->{user_id})
	} @augmentedUserRecords;

	# construct header
	my @list_problems = map { $_->[1] } $db->listGlobalProblemsWhere({ set_id => $setName }, 'problem_id');
	@list_problems = ($r->maketext('None')) unless (@list_problems);
	my $maxProblem = scalar @list_problems;

	# for a jitar set we only get the top level problems
	if ($GlobalSet->assignment_type eq 'jitar') {
		my @topLevelProblems;
		foreach my $id (@list_problems) {
			my @seq = jitar_id_to_seq($id);
			push @topLevelProblems, $seq[0] if ($#seq == 0);
		}
		@list_problems = @topLevelProblems;
	}

	# Changes for gateways/versioned sets here.  In this case we allow instructors
	# to modify the appearance of output, which we do with a form.  So paste in the
	# form header here, and make appropriate modifications.
	if ($setIsVersioned) {
		print CGI::start_div({ class => 'card bg-light mb-3' });
		print CGI::start_form({
			method => 'post',
			id     => 'sp-gateway-form',
			action => $self->systemLink($urlpath, authen => 0),
			name   => 'StudentProgress'
		});
		print $self->hidden_authen_fields();
		print CGI::div(
			{ class => 'card-body' },
			CGI::h5({ class => 'card-title' }, $r->maketext("Display options: Show")),
			CGI::div(
				{ 'class' => 'mb-2' },
				CGI::hidden({ name => 'returning', value => '1' }),
				CGI::div(
					{ class => 'form-check form-check-inline' },
					CGI::checkbox({
						name            => 'show_best_only',
						value           => '1',
						checked         => $showBestOnly,
						label           => $r->maketext('only best scores'),
						class           => 'form-check-input',
						labelattributes => { class => 'form-check-label' }
					})
				),
				CGI::div(
					{ class => 'form-check form-check-inline' },
					CGI::checkbox({
						name            => 'show_date',
						value           => '1',
						checked         => $showColumns{'date'},
						label           => $r->maketext('test date'),
						class           => 'form-check-input',
						labelattributes => { class => 'form-check-label' }
					})
				),
				CGI::div(
					{ class => 'form-check form-check-inline' },
					CGI::checkbox({
						name            => 'show_testtime',
						value           => '1',
						checked         => $showColumns{'testtime'},
						label           => $r->maketext('test time'),
						class           => 'form-check-input',
						labelattributes => { class => 'form-check-label' }
					})
				),
				CGI::div(
					{ class => 'form-check form-check-inline' },
					CGI::checkbox({
						name            => 'show_problems',
						value           => '1',
						checked         => $showColumns{'problems'},
						label           => $r->maketext('problems'),
						class           => 'form-check-input',
						labelattributes => { class => 'form-check-label' }
					})
				),
				CGI::div(
					{ class => 'form-check form-check-inline' },
					CGI::checkbox({
						name            => 'show_section',
						value           => '1',
						checked         => $showColumns{'section'},
						label           => $r->maketext('section #'),
						class           => 'form-check-input',
						labelattributes => { class => 'form-check-label' }
					})
				),
				CGI::div(
					{ class => 'form-check form-check-inline' },
					CGI::checkbox({
						name            => 'show_recitation',
						value           => '1',
						checked         => $showColumns{'recit'},
						label           => $r->maketext('recitation #'),
						class           => 'form-check-input',
						labelattributes => { class => 'form-check-label' }
					})
				),
				CGI::div(
					{ class => 'form-check form-check-inline' },
					CGI::checkbox({
						name            => 'show_login',
						value           => '1',
						checked         => $showColumns{'login'},
						label           => $r->maketext('login'),
						class           => 'form-check-input',
						labelattributes => { class => 'form-check-label' }
					})
				)
			),
			CGI::submit({ value => $r->maketext('Update Display'), class => 'btn btn-primary' })
		);
		print CGI::end_form();
		print CGI::end_div();
	}

	# Table description. Only show the problem description if the problems column is shown.
	print CGI::start_div();
	if (!$setIsVersioned || $showColumns{'problems'}) {
		print CGI::p($r->maketext(
			'A period (.) indicates a problem has not been attempted, and a number from 0 to 100 '
				. 'indicates the grade earned. The number on the second line gives the number of incorrect attempts.'
		));
	}
	if ($setIsVersioned) {
		print CGI::p($r->maketext(
			'Click a student\'s name to see the student\'s test summary page. '
				. 'Click a test\'s version number to see the corresponding test version. '
				. 'Click a heading to sort the table.'
		));
	} else {
		print CGI::p($r->maketext(
			'Click a student\'s name to see the student\'s homework set. ' . 'Click a heading to sort the table.'
		));
	}
	if (defined $primary_sort_method_name) {
		print CGI::p(
			$r->maketext('Entries are sorted by [_1]', $display_sort_method_name{$primary_sort_method_name})
				. (
					defined $secondary_sort_method_name
					? $r->maketext(', then by [_1]', $display_sort_method_name{$secondary_sort_method_name})
					: ''
				)
				. (
					defined $ternary_sort_method_name
					? $r->maketext(', then by [_1]', $display_sort_method_name{$ternary_sort_method_name})
					: ''
				)
				. '.'
		);
	}
	print CGI::end_div();

	# calculate secondary and ternary sort methods parameters if appropriate
	my %past_sort_methods = ();
	%past_sort_methods = (secondary_sort => "$primary_sort_method_name",) if defined($primary_sort_method_name);
	%past_sort_methods = (%past_sort_methods, ternary_sort => "$secondary_sort_method_name",)
		if defined($secondary_sort_method_name);
	my %params = (%past_sort_methods);

	# we need to preserve display options when the sort headers are clicked on gateway quizzes
	if ($setIsVersioned) {
		my %display_options = (
			returning       => 1,
			show_best_only  => $showBestOnly,
			show_date       => $showColumns{date},
			show_testtime   => $showColumns{testtime},
			show_problems   => $showColumns{problems},
			show_section    => $showColumns{section},
			show_recitation => $showColumns{recit},
			show_login      => $showColumns{login},
		);
		%params = (%past_sort_methods, %display_options);
	}

	# To deal with the variable number of columns and the problems columns
	# split the headers into two pieces.
	# @columnHeaders1 are the columns before the problem columns.
	# @columnHeaders2 are the columns after the problem columns.
	my @columnHeaders1 = (
		$r->maketext('Name')
			. CGI::br()
			. CGI::a(
				{
					href => $self->systemLink(
						$setStatsPage, params => { primary_sort => 'first_name', %params }
					)
				},
				$r->maketext('First')
			)
			. '&nbsp;&nbsp;&nbsp;'
			. CGI::a(
				{
					href => $self->systemLink(
						$setStatsPage, params => { primary_sort => 'last_name', %params }
					)
				},
				$r->maketext('Last')
			)
			. CGI::br()
			. CGI::a(
				{
					href => $self->systemLink(
						$setStatsPage, params => { primary_sort => 'email_address', %params }
					)
				},
				$r->maketext('Email')
			),
		CGI::a(
			{
				href => $self->systemLink(
					$setStatsPage, params => { primary_sort => 'score', %params }
				)
			},
			$r->maketext('Score')
		),
		$r->maketext('Out Of'),
	);
	my @columnHeaders2 = ();

	# Additional columns that may or may not be shown depending on if
	# showing a gateway quiz and any user configuration.
	push(@columnHeaders1, $r->maketext('Date'))      if ($setIsVersioned && $showColumns{'date'});
	push(@columnHeaders1, $r->maketext('Test Time')) if ($setIsVersioned && $showColumns{'testtime'});
	push(
		@columnHeaders2,
		CGI::a(
			{
				href => $self->systemLink(
					$setStatsPage, params => { primary_sort => 'section', %params }
				)
			},
			$r->maketext('Section')
		)
	) if (!$setIsVersioned || $showColumns{'section'});
	push(
		@columnHeaders2,
		CGI::a(
			{
				href => $self->systemLink(
					$setStatsPage, params => { primary_sort => 'recitation', %params }
				)
			},
			$r->maketext('Recitation')
		)
	) if (!$setIsVersioned || $showColumns{'recit'});
	push(
		@columnHeaders2,
		CGI::a(
			{
				href => $self->systemLink(
					$setStatsPage, params => { primary_sort => 'user_id', %params }
				)
			},
			$r->maketext('Login Name')
		)
	) if (!$setIsVersioned || $showColumns{'login'});

	# Start table output
	print CGI::start_div({ class => 'table-responsive' }),
		CGI::start_table({ class => 'grade-table table table-bordered table-sm font-xs' });

	if (!@columnHeaders2 && $showColumns{'problems'}) {
		print CGI::thead(
			CGI::Tr(
				CGI::th({ rowspan => 2 },           [@columnHeaders1]),
				CGI::th({ colspan => $maxProblem }, $r->maketext('Problems'))
			),
			CGI::Tr(CGI::th({ class => 'problem-data' }, [@list_problems]))
		);
	} elsif ($showColumns{'problems'}) {
		print CGI::thead(
			CGI::Tr(
				CGI::th({ rowspan => 2 },           [@columnHeaders1]),
				CGI::th({ colspan => $maxProblem }, $r->maketext('Problems')),
				CGI::th({ rowspan => 2 },           [@columnHeaders2])
			),
			CGI::Tr(CGI::th({ class => 'problem-data' }, [@list_problems]))
		);
	} else {
		print CGI::thead(CGI::Tr(CGI::th([ @columnHeaders1, @columnHeaders2 ])));
	}
	print CGI::start_tbody();

	# variables to keep track of versioned sets
	my $prevUserID = '';

	# and to make formatting nice for students who haven't taken any tests
	# (the total number of columns is two more than this; we want the
	# number that missing record information should span)
	my $numCol = 1;
	$numCol++              if $showColumns{'date'};
	$numCol++              if $showColumns{'testtime'};
	$numCol += $maxProblem if $showColumns{'problems'};

	# Loop that prints the table rows
	foreach my $rec (@augmentedUserRecords) {
		my $fullName = join("", $rec->{first_name}, " ", $rec->{last_name});
		my $email    = $rec->{email_address};

		if (!$setIsVersioned) {
			my $problemSetPage = $urlpath->newFromModule(
				'WeBWorK::ContentGenerator::ProblemSet', $r,
				courseID => $courseName,
				setID    => $setName
			);
			my $interactiveURL = $self->systemLink($problemSetPage, params => { effectiveUser => $rec->{user_id} });
			print CGI::Tr(
				CGI::td(
					CGI::div(CGI::a({ href => $interactiveURL }, $fullName)),
					$email ? CGI::div(CGI::a({ href => "mailto:$email" }, $email)) : ''
				),
				CGI::td($rec->{score}),
				CGI::td($rec->{total}),
				CGI::td({ class => 'problem-data' }, $rec->{problemsRow}),
				CGI::td($self->nbsp($rec->{section})),
				CGI::td($self->nbsp($rec->{recitation})),
				CGI::td($rec->{user_id})
			);
		} else {
			my $problemSetPage = $urlpath->newFromModule(
				'WeBWorK::ContentGenerator::ProblemSet', $r,
				courseID => $courseName,
				setID    => $setName
			);
			my $interactiveURL = $self->systemLink($problemSetPage, params => { effectiveUser => $rec->{user_id} });

			# if total is 'n/a', then it's a user who hasn't taken
			# any tests, which we treat separately
			if ($rec->{total} ne 'n/a') {
				# make make versioned sets' name format nicer and link to appropriate test version
				my $nameEntry   = '';
				my $versionPage = $urlpath->newFromModule(
					'WeBWorK::ContentGenerator::GatewayQuiz', $r,
					courseID => $courseName,
					setID    => $setName . ',v' . $rec->{version}
				);
				my $versionLink = CGI::a(
					{
						href => $self->systemLink(
							$versionPage, params => { effectiveUser => $rec->{user_id} }
						)
					},
					"version $rec->{version}"
				);
				if ($rec->{user_id} eq $prevUserID) {
					$nameEntry = CGI::div({ class => 'ms-4' }, "($versionLink)");
				} else {
					$nameEntry =
						CGI::a({ href => $interactiveURL }, $fullName)
						. ($setIsVersioned && !$showBestOnly ? " ($versionLink)" : ' ')
						. CGI::br()
						. CGI::a({ href => "mailto:$email" }, $email);
					$prevUserID = $rec->{user_id};
				}

				# build columns to show
				my @cols;
				push(@cols, CGI::td($nameEntry), CGI::td($rec->{score}), CGI::td($rec->{total}));
				push(@cols, CGI::td($self->nbsp($rec->{date})))     if ($showColumns{'date'});
				push(@cols, CGI::td($self->nbsp($rec->{testtime}))) if ($showColumns{'testtime'});
				push(@cols, CGI::td({ class => 'problem-data' }, $rec->{problemsRow}))
					if ($showColumns{'problems'});
				push(@cols, CGI::td($self->nbsp($rec->{section})))    if ($showColumns{'section'});
				push(@cols, CGI::td($self->nbsp($rec->{recitation}))) if ($showColumns{'recit'});
				push(@cols, CGI::td($rec->{user_id}))                 if ($showColumns{'login'});
				print CGI::Tr(@cols);
			} else {
				my @cols = (
					CGI::td(
						CGI::a({ href => $interactiveURL }, $fullName)
							. CGI::br()
							. CGI::a({ href => "mailto:$email" }, $email)
					),
					CGI::td($rec->{score}),
					CGI::td({ colspan => $numCol }, CGI::em($self->nbsp($r->maketext('No tests taken.'))))
				);
				push(@cols, CGI::td($self->nbsp($rec->{section})))    if ($showColumns{'section'});
				push(@cols, CGI::td($self->nbsp($rec->{recitation}))) if ($showColumns{'recit'});
				push(@cols, CGI::td($self->nbsp($rec->{user_id})))    if ($showColumns{'login'});
				print CGI::Tr(@cols);
			}
		}
	}

	print CGI::end_tbody(), CGI::end_table(), CGI::end_div();

	return '';
}

1;
