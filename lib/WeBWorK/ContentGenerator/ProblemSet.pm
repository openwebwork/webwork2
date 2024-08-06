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

package WeBWorK::ContentGenerator::ProblemSet;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator::ProblemSet - display an index of the problems in a
problem set.

=cut

use WeBWorK::Debug;
use WeBWorK::Utils qw(wwRound);
use WeBWorK::Utils::DateTime qw(after);
use WeBWorK::Utils::Files qw(path_is_subdir);
use WeBWorK::Utils::Rendering qw(renderPG);
use WeBWorK::Utils::Sets qw(is_restricted grade_set format_set_name_display);
use WeBWorK::DB::Utils qw(grok_versionID_from_vsetID_sql);
use WeBWorK::Localize;

async sub initialize ($c) {
	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;

	# $c->{invalidSet} is set in checkSet which is called by ContentGenerator.pm
	return
		if $c->{invalidSet}
		&& ($c->{invalidSet} !~ /^Client ip address .* is not in the list of addresses/
			|| $authz->{merged_set}->assignment_type !~ /gateway/);

	# This will all be valid if checkSet did not set $c->{invalidSet}.
	my $userID  = $c->param('user');
	my $eUserID = $c->param('effectiveUser');

	my $user          = $db->getUser($userID);
	my $effectiveUser = $db->getUser($eUserID);
	$c->{set} = $authz->{merged_set};

	$c->{displayMode} = $user->displayMode || $ce->{pg}{options}{displayMode};

	# Display status messages.
	$c->addmessage($c->tag('p', $c->b($c->authen->flash('status_message')))) if $c->authen->flash('status_message');

	if ($authz->hasPermissions($userID, 'view_hidden_sets')) {
		if ($c->{set}->visible) {
			$c->addmessage($c->tag('p', class => 'font-visible', $c->maketext('This set is visible to students.')));
		} else {
			$c->addmessage($c->tag('p', class => 'font-hidden', $c->maketext('This set is hidden from students.')));
		}
	}

	# Hack to prevent errors from uninitialized set_headers.
	$c->{set}->set_header('defaultHeader') unless $c->{set}->set_header =~ /\S/;
	my $screenSetHeader =
		$c->{set}->set_header eq 'defaultHeader'
		? $ce->{webworkFiles}{screenSnippets}{setHeader}
		: $c->{set}->set_header;

	# Note this may be different than the display mode above when previewing a temporary set header file.
	my $displayMode = $c->param('displayMode') || $ce->{pg}{options}{displayMode};

	if ($authz->hasPermissions($userID, 'modify_problem_sets')) {
		if (defined $c->param('editMode') && $c->param('editMode') eq 'temporaryFile') {
			$screenSetHeader = $c->param('sourceFilePath');
			$screenSetHeader = "$ce->{courseDirs}{templates}/$screenSetHeader" unless $screenSetHeader =~ m!^/!;
			die 'sourceFilePath is unsafe!' unless path_is_subdir($screenSetHeader, $ce->{courseDirs}{templates});
			$c->addmessage($c->tag(
				'p',
				class => 'temporaryFile',
				$c->maketext('Viewing temporary file: [_1]', $screenSetHeader)
			));
		}
	}

	return unless $screenSetHeader;

	my $problem = WeBWorK::DB::Record::UserProblem->new(
		problem_id  => 0,
		set_id      => $c->{set}->set_id,
		login_id    => $effectiveUser->user_id,
		source_file => $screenSetHeader
	);

	$c->{pg} =
		await renderPG($c, $effectiveUser, $c->{set}, $problem, $c->{set}->psvn, {}, { displayMode => $displayMode });

	return;
}

sub nav ($c, $args) {
	# Don't show the nav if the user does not have unrestricted navigation permissions.
	return '' unless $c->authz->hasPermissions($c->param('user'), 'navigation_allowed');

	my @links = (
		$c->maketext('Assignments'),
		$c->url_for($c->app->routes->lookup($c->current_route)->parent->name),
		$c->maketext('Assignments')
	);
	return $c->tag(
		'div',
		class        => 'row sticky-nav',
		role         => 'navigation',
		'aria-label' => 'problem navigation',
		$c->tag('div', $c->navMacro($args, {}, @links))
	);
}

sub siblings ($c) {
	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;

	my $user    = $c->param('user');
	my $eUserID = $c->param('effectiveUser');

	# Restrict navigation to other problem sets if not allowed.
	return '' unless $authz->hasPermissions($user, 'navigation_allowed');

	# Note that listUserSets does not list versioned sets, but listUserSetsWhere does.  On the other hand, listUserSets
	# can not sort in the database, while listUserSetsWhere can.
	my @setIDs =
		map { $_->[1] } $db->listUserSetsWhere({ user_id => $eUserID, set_id => { not_like => '%,v%' } }, 'set_id');

	# Do not show hidden siblings unless user is allowed to view hidden sets.
	unless ($authz->hasPermissions($user, 'view_hidden_sets')) {
		@setIDs = grep {
			my $set        = $db->getMergedSet($eUserID, $_);
			my @restricted = $ce->{options}{enableConditionalRelease} ? is_restricted($db, $set, $eUserID) : ();
			my $LTIRestricted =
				defined($ce->{LTIGradeMode}) && $ce->{LTIGradeMode} eq 'homework' && !$set->lis_source_did;

			after($set->open_date)
				&& (defined($set->visible()) ? $set->visible() : 1)
				&& !@restricted
				&& !$LTIRestricted;
		} @setIDs;
	}

	return $c->include('ContentGenerator/ProblemSet/siblings', setIDs => \@setIDs);
}

sub info {
	my ($c) = @_;
	return '' unless $c->{pg};
	return $c->include('ContentGenerator/ProblemSet/info');
}

# This is called by the ContentGenerator/ProblemSet/body template for a regular homework set.
# It lists the problems in the set.
sub problem_list ($c) {
	my $authz = $c->authz;
	my $db    = $c->db;

	my $setID = $c->stash('setID');
	my $user  = $c->param('user');

	my @problems =
		$db->getMergedProblemsWhere({ user_id => $c->param('effectiveUser'), set_id => $setID }, 'problem_id');

	return $c->include('ContentGenerator/ProblemSet/problem_list', problems => \@problems);
}

# This is called by the ContentGenerator/ProblemSet/body template for a test.
# It gives some information about the test parameters, and lists the versions.
sub gateway_body ($c) {
	my $authz = $c->authz;
	my $ce    = $c->ce;
	my $db    = $c->db;

	my $set           = $c->{set};
	my $effectiveUser = $c->param('effectiveUser');
	my $user          = $c->param('user');

	my $timeNow   = time;
	my $timeLimit = $set->version_time_limit || 0;

	# Compute how many versions have been launched within timeInterval to determine if a new version can be created,
	# if a version can be continued, and the date a next version can be started.  If there is an open version that
	# can be resumed, add a button to continue the last such version found.
	my $continueVersion  = 0;
	my $continueTimeLeft = 0;
	my $currentVersions  = 0;
	my $lastTime         = 0;
	my $timeInterval     = $set->time_interval || 0;
	my @versionData;

	my @setVersions = $db->getMergedSetVersionsWhere(
		{ user_id => $effectiveUser, set_id => { like => $set->set_id . ',v%' } },
		\grok_versionID_from_vsetID_sql($db->{set_version_merged}->sql->_quote('set_id'))
	);

	for my $verSet (@setVersions) {
		# Count number of versions in current timeInterval
		if (!$timeInterval || $verSet->version_creation_time > ($timeNow - $timeInterval)) {
			++$currentVersions;
			$lastTime = $verSet->version_creation_time
				if ($lastTime == 0 || $lastTime > $verSet->version_creation_time);
		}

		# Get a problem to determine how many submits have been made.
		my @ProblemNums = $db->listUserProblems($effectiveUser, $set->set_id);
		my $Problem = $db->getMergedProblemVersion($effectiveUser, $set->set_id, $verSet->version_id, $ProblemNums[0]);
		my $verSubmits = defined $Problem ? $Problem->num_correct + $Problem->num_incorrect : 0;
		my $maxSubmits = $verSet->attempts_per_version || 0;

		# Build data hash for this version.
		my $data = {};
		$data->{id}        = $set->set_id . ',v' . $verSet->version_id;
		$data->{version}   = $verSet->version_id;
		$data->{start}     = $c->formatDateTime($verSet->version_creation_time, $ce->{studentDateDisplayFormat});
		$data->{proctored} = $verSet->assignment_type =~ /proctored/;

		# Display close date if this is not a timed test.
		my $closeText = '';
		if (!$timeLimit) {
			$closeText =
				$c->maketext('Closes on [_1]', $c->formatDateTime($verSet->due_date, $ce->{studentDateDisplayFormat}));
		}

		if (defined $verSet->version_last_attempt_time && $verSet->version_last_attempt_time > 0) {
			if ($timeNow < $verSet->due_date
				&& ($maxSubmits <= 0 || ($maxSubmits > 0 && $verSubmits < $maxSubmits)))
			{
				if ($verSubmits > 0) {
					$data->{end} = $c->maketext('Additional submissions available.') . " $closeText";
				} else {
					$data->{end} = $closeText;
				}
			} else {
				$data->{end} =
					$c->formatDateTime($verSet->version_last_attempt_time, $ce->{studentDateDisplayFormat});
			}
		} elsif ($timeNow < $verSet->due_date) {
			$data->{end} = $c->maketext('Test not yet submitted.') . " $closeText";
		} else {
			$data->{end} = $c->maketext('No submissions. Over time.');
		}

		# Status Logic: Assuming it is always after the open date for test versions.
		# Matching can_showCorrectAnswer method where hide_work eq 'N' is
		# only honored before the answer_date if it also equals the due_date.
		# Using $set->answer_date since the template date is what is currently used to decide
		# if answers are available.
		my $canShowAns = (
			(
				$verSet->hide_work eq 'N'
					&& ($verSet->due_date == $verSet->answer_date || $timeNow >= $set->answer_date)
			)
				|| ($verSet->hide_work eq 'BeforeAnswerDate' && $timeNow >= $set->answer_date)
		) ? 1 : 0;

		if ($timeNow < $verSet->due_date + $ce->{gatewayGracePeriod}) {
			if ($maxSubmits > 0 && $verSubmits >= $maxSubmits) {
				$data->{status} = $c->maketext('Completed.');
				$data->{status} .= $c->maketext(' Answers Available.') if ($canShowAns);
			} else {
				if ($verSubmits) {
					$data->{status} = $c->maketext('Open. Submitted.');
				} else {
					$data->{status} = $c->maketext('Open.');
				}
				if (($maxSubmits == 0 && !$verSubmits) || $verSubmits < $maxSubmits) {
					$continueVersion = $verSet;
					$continueTimeLeft =
						$verSet->due_date + ($timeNow >= $verSet->due_date ? $ce->{gatewayGracePeriod} : 0) - $timeNow;
				}
			}
		} else {
			if ($verSubmits > 0) {
				$data->{status} = $c->maketext('Completed.');
			} else {
				$data->{status} = $c->maketext('Closed.');
			}
			$data->{status} .= $c->maketext(' Answers Available.') if ($canShowAns);
		}

		# Only show download link if work is not hidden.
		# Only show version link if the set is open or if works is not hidden.
		$data->{show_download} =
			($verSet->hide_work eq 'N' || ($verSet->hide_work eq 'BeforeAnswerDate' && $timeNow >= $set->answer_date))
			? 1
			: 0;
		$data->{show_link} = ($data->{status} =~ /Open/ || $data->{show_download});

		$data->{score} = '';
		# Only show score if user has permission and assignment has at least one submit.
		if ($authz->hasPermissions($user, 'view_hidden_work')
			|| ($verSet->hide_score eq 'N'                && $verSubmits >= 1)
			|| ($verSet->hide_score eq 'BeforeAnswerDate' && $timeNow > $set->answer_date))
		{
			my ($total, $possible) = grade_set($db, $verSet, $effectiveUser, 1);
			$total = wwRound(2, $total);
			$data->{score} = "$total/$possible";
		}
		push @versionData, $data;
	}

	return $c->include(
		'ContentGenerator/ProblemSet/version_list',
		continueVersion  => $continueVersion,
		continueTimeLeft => $continueTimeLeft,
		timeLimit        => $timeLimit,
		timeInterval     => $timeInterval,
		timeNow          => $timeNow,
		lastTime         => $lastTime,
		setVersions      => \@setVersions,
		versionData      => \@versionData,
		currentVersions  => $currentVersions
	);
}

1;
