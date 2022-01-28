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

package WeBWorK::ContentGenerator::ProblemSet;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::ProblemSet - display an index of the problems in a
problem set.

=cut

use strict;
use warnings;
use WeBWorK::CGI;
use WeBWorK::PG;
use URI::Escape;
use WeBWorK::Debug;
use WeBWorK::Utils qw(sortByName path_is_subdir is_restricted is_jitar_problem_closed is_jitar_problem_hidden jitar_problem_adjusted_status jitar_id_to_seq seq_to_jitar_id wwRound before between after grade_set);
use WeBWorK::Localize;

sub initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $urlpath = $r->urlpath;
	my $authz = $r->authz;

	my $setName = $urlpath->arg("setID");
	my $userName = $r->param("user");
	my $effectiveUserName = $r->param("effectiveUser");

	my $user            = $db->getUser($userName); # checked
	my $effectiveUser   = $db->getUser($effectiveUserName); # checked
	my $set             = $db->getMergedSet($effectiveUserName, $setName); # checked

	die "user $user (real user) not found."  unless $user;
	die "effective user $effectiveUserName  not found. One 'acts as' the effective user."  unless $effectiveUser;

	$self->{displayMode}  = $user->displayMode ? $user->displayMode :  $r->ce->{pg}->{options}->{displayMode};

	# FIXME: some day it would be nice to take out this code and consolidate the two checks

	# get result and send to message
	my $status_message = $r->param("status_message");
	$self->addmessage(CGI::p("$status_message")) if $status_message;

	# $self->{invalidSet} is set by ContentGenerator.pm
	return if $self->{invalidSet};
	return unless defined($set);

	# Database fix (in case of undefined visible values)
	# this is only necessary because some people keep holding to ww1.9 which did not have a visible field
	# make sure visible is set to 0 or 1

	if ($set->visible ne "0" and $set->visible ne "1") {
		my $globalSet = $db->getGlobalSet($set->set_id);
		$globalSet->visible("1"); # defaults to visible
		$db->putGlobalSet($globalSet);
		$set = $db->getMergedSet($effectiveUserName, $set->set_id);
	}

	# When a set is created enable_reduced_scoring is null, so we have to set it
	if ($set->enable_reduced_scoring ne "0" and $set->enable_reduced_scoring ne "1") {
		my $globalSet = $db->getGlobalSet($set->set_id);
		$globalSet->enable_reduced_scoring("0"); # defaults to disabled
		$db->putGlobalSet($globalSet);
		$set = $db->getMergedSet($effectiveUserName, $set->set_id);
	}

	my $visiblityStateText = ($set->visible) ? $r->maketext("visible to students")."." : $r->maketext("hidden from students").".";
	my $visiblityStateClass = ($set->visible) ? "font-visible" : "font-hidden";
	$self->addmessage(CGI::span($r->maketext("This set is [_1]", CGI::span({class=>$visiblityStateClass}, $visiblityStateText))))
	if $authz->hasPermissions($userName, "view_hidden_sets");


	$self->{userName}        = $userName;
	$self->{user}            = $user;
	$self->{effectiveUser}   = $effectiveUser;
	$self->{set}             = $set;

	##### permissions #####

	$self->{isOpen} = ((time >= $set->open_date && !(
				$ce->{options}{enableConditionalRelease} &&
				is_restricted($db, $set, $effectiveUserName)))
		|| $authz->hasPermissions($userName, "view_unopened_sets"));

	die("You do not have permission to view unopened sets") unless $self->{isOpen};
}

sub nav {
	my ($self, $args) = @_;
	my $r = $self->r;
	my $urlpath = $r->urlpath;

	my $courseID = $urlpath->arg("courseID");
	#my $problemSetsPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",  $r, courseID => $courseID);
	my $problemSetsPage = $urlpath->parent;

	my @links = ($r->maketext("Homework Sets"), $r->location . $problemSetsPage->path, $r->maketext("Homework Sets"));
	return CGI::div({ class => 'row sticky-nav', role => 'navigation', aria_label => 'problem navigation' },
		CGI::div($self->navMacro($args, '', @links)));
}

sub title {
	my ($self) = @_;
	my $r = $self->r;
	my $eUserID = $r->param("effectiveUser");
	# using the url arguments won't break if the set/problem are invalid
	my $prettySetID = WeBWorK::ContentGenerator::underscore2nbsp($r->urlpath->arg("setID"));
	my $setID = $r->urlpath->arg("setID");

	my $title = $prettySetID;
	#put either due date or reduced scoring date in the title.
	my $set = $r->db->getMergedSet($eUserID, $setID);
	if (defined($set) && between($set->open_date, $set->due_date)) {
		my $enable_reduced_scoring =  $r->{ce}->{pg}{ansEvalDefaults}{enableReducedScoring} && $set->enable_reduced_scoring && $set->reduced_scoring_date &&$set->reduced_scoring_date != $set->due_date;
		if ($enable_reduced_scoring &&
			before($set->reduced_scoring_date)) {
			$title .= ' - '.$r->maketext("Due [_1], after which reduced scoring is available until [_2]",
				$self->formatDateTime($set->reduced_scoring_date, undef,
					$r->ce->{studentDateDisplayFormat}),
				$self->formatDateTime($set->due_date, undef,
					$r->ce->{studentDateDisplayFormat}));
		} elsif ($set->due_date) {
			$title .= ' - '.$r->maketext("Closes [_1]",
				$self->formatDateTime($set->due_date, undef,
					$r->ce->{studentDateDisplayFormat}));
		}
	}

	return $title;
}

sub templateName {
	my $self = shift;
	my $r = $self->r;
	my $templateName = $r->param('templateName')//'system';
	$self->{templateName}= $templateName;
	$templateName;
}

sub siblings {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;


	my $courseID = $urlpath->arg("courseID");
	my $user = $r->param('user');
	my $eUserID = $r->param("effectiveUser");

	# note that listUserSets does not list versioned sets
	# DBFIXME do filtering in WHERE clause, use iterator for results :)
	my @setIDs = sortByName(undef, $db->listUserSets($eUserID));

	# do not show hidden siblings unless user is allowed to view hidden sets, and
	# exclude gateway tests in all cases
	if ( $authz->hasPermissions($user, "view_hidden_sets") ) {
		@setIDs = grep {my $gs = $db->getGlobalSet( $_ );
			$gs->assignment_type() !~ /gateway/} @setIDs;

	} else {
		@setIDs = grep {
			my $set = $db->getMergedSet($eUserID, $_);
			my @restricted = $ce->{options}{enableConditionalRelease} ? is_restricted($db, $set, $eUserID) : ();
			my $LTIRestricted = defined($ce->{LTIGradeMode}) && $ce->{LTIGradeMode} eq 'homework' && !$set->lis_source_did;

			after($set->open_date) &&
			$set->assignment_type() !~ /gateway/ &&
			(defined($set->visible()) ? $set->visible() : 1)
			&& !@restricted
			&& !$LTIRestricted;
		} @setIDs;
	}

	print CGI::start_div({class=>"info-box", id=>"fisheye"});
	print CGI::h2($r->maketext("Sets"));
	print CGI::start_ul({ class => 'nav flex-column bg-light' });

	debug("Begin printing sets from listUserSets()");
	foreach my $setID (@setIDs) {
		my $setPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet", $r,
			courseID => $courseID, setID => $setID);
		my $pretty_set_id = $setID;
		$pretty_set_id =~ s/_/ /g;
		print CGI::li({ class => 'nav-item' },
			CGI::a({
					href => $self->systemLink($setPage),
					id => $pretty_set_id,
					class => 'nav-link'
				}, $pretty_set_id)
		) ;
	}
	debug("End printing sets from listUserSets()");

	# FIXME: when database calls are faster, this will get rid of hidden sibling links
	#debug("Begin printing sets from getMergedSets()");
	#my @userSetIDs = map {[$eUserID, $_]} @setIDs;
	#my @sets = $db->getMergedSets(@userSetIDs);
	#foreach my $set (@sets) {
	#	my $setPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",  $r, courseID => $courseID, setID => $set->set_id);
	#	print CGI::li(CGI::a({href=>$self->systemLink($setPage)}, $set->set_id)) unless !(defined $set && ($set->published || $authz->hasPermissions($user, "view_unpublished_sets"));
	#}
	#debug("Begin printing sets from getMergedSets()");

	print CGI::end_ul();
	print CGI::end_div();

	return "";
}

sub info {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	return "" if ( $self->{invalidSet} );

	my $courseID = $urlpath->arg("courseID");
	my $setID = $r->urlpath->arg("setID");

	my $userID = $r->param("user");
	my $eUserID = $r->param("effectiveUser");

	my $effectiveUser = $db->getUser($eUserID); # checked
	my $set  = $db->getMergedSet($eUserID, $setID); # checked

	die "effective user $eUserID not found. One 'acts as' the effective user." unless $effectiveUser;
	# FIXME: this was already caught in initialize()
	die "set $setID for effectiveUser $eUserID not found." unless $set;

	my $psvn = $set->psvn();
	# hack to prevent errors from uninitialized set_headers.
	$set->set_header("defaultHeader") unless $set->set_header =~/\S/; # (some non-white space character required)
	my $screenSetHeader = ($set->set_header eq "defaultHeader") ?
	$ce->{webworkFiles}->{screenSnippets}->{setHeader} :
	$set->set_header;

	my $displayMode     = $r->param("displayMode") || $ce->{pg}->{options}->{displayMode};

	if ($authz->hasPermissions($userID, "modify_problem_sets")) {
		if (defined $r->param("editMode") and $r->param("editMode") eq "temporaryFile") {
			$screenSetHeader = $r->param('sourceFilePath');
			$screenSetHeader = $ce->{courseDirs}{templates}.'/'.$screenSetHeader unless $screenSetHeader =~ m!^/!;
			die "sourceFilePath is unsafe!" unless path_is_subdir($screenSetHeader, $ce->{courseDirs}->{templates});
			$self->addmessage(CGI::div({class=>'temporaryFile'}, $r->maketext("Viewing temporary file:")." ",
					$screenSetHeader));
			$displayMode = $r->param("displayMode") if $r->param("displayMode");
		}
	}

	return "" unless defined $screenSetHeader and $screenSetHeader;

	# decide what to do about problem number
	my $problem = WeBWorK::DB::Record::UserProblem->new(
		problem_id => 0,
		set_id => $set->set_id,
		login_id => $effectiveUser->user_id,
		source_file => $screenSetHeader,
		# the rest of Problem's fields are not needed, i think
	);

	my $pg = WeBWorK::PG->new(
		$ce,
		$effectiveUser,
		$r->param('key'),
		$set,
		$problem,
		$psvn,
		{}, # no form fields!
		{ # translation options
			displayMode     => $displayMode,
			showHints       => 0,
			showSolutions   => 0,
			processAnswers  => 0,
		},
	);

	my $editorURL;
	if (defined($set) and $authz->hasPermissions($userID, "modify_problem_sets")) {
		my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor", $r,
			courseID => $courseID, setID => $set->set_id, problemID => 0);
		$editorURL = $self->systemLink($editorPage, params => { file_type => 'set_header'});
	}

	if ($editorURL) {
		print CGI::h2(
			{ class => 'd-flex align-items-center justify-content-center' },
			$r->maketext("Set Info"),
			CGI::a(
				{ href => $editorURL, target => "WW_Editor", class => 'btn btn-sm btn-info m-1' },
				$r->maketext("Edit")
			)
		);
	} else {
		print CGI::h2($r->maketext("Set Info"));
	}

	if ($pg->{flags}->{error_flag}) {
		print CGI::div({ class => 'alert alert-danger p-1 mb-0' }, $self->errorOutput($pg->{errors}, $pg->{body_text}));
	} else {
		print $pg->{body_text};
	}

	return "";
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $authz = $r->authz;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;

	my $courseID = $urlpath->arg("courseID");
	my $setName = $urlpath->arg("setID");
	my $effectiveUser = $r->param('effectiveUser');
	my $user = $r->param('user');

	my $set = $db->getMergedSet($effectiveUser, $setName);  # checked

	if ($self->{invalidSet}) {
		return CGI::div(
			{ class => 'alert alert-danger' },
			CGI::div(
				{ class => 'mb-3' },
				$r->maketext("The selected problem set ([_1]) is not a valid set for [_2]", $setName, $effectiveUser)
					. ":"
			),
			CGI::div($self->{invalidSet})
		);
	}

	my $isJitarSet = ($set->assignment_type eq 'jitar');
	my $isGateway = ($set->assignment_type =~ /gateway/);

	my ($hardcopyPage, $hardcopyURL);
	if ($isGateway) {
		$hardcopyPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Hardcopy", $r, courseID => $courseID);
		$hardcopyURL = $self->systemLink($hardcopyPage, authen => 0);
	} else {
		$hardcopyPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Hardcopy", $r,
			courseID => $courseID, setID => $setName);
		$hardcopyURL = $self->systemLink($hardcopyPage);
	}

	my $enable_reduced_scoring =  $ce->{pg}{ansEvalDefaults}{enableReducedScoring} && $set->enable_reduced_scoring && $set->reduced_scoring_date &&$set->reduced_scoring_date != $set->due_date;

	my $reduced_scoring_date = $set->reduced_scoring_date;
	if ($enable_reduced_scoring) {
		my $dueDate = $self->formatDateTime($set->due_date());
		my $reducedScoringValue = $ce->{pg}->{ansEvalDefaults}->{reducedScoringValue};
		my $reducedScoringPerCent = int(100*$reducedScoringValue+.5);
		my $beginReducedScoringPeriod =  $self->formatDateTime($reduced_scoring_date);

		if (before($reduced_scoring_date)) {
			print CGI::div({class=>"alert alert-warning mb-3"},
				$r->maketext("After the reduced scoring period begins all work counts for [_1]% of its value.",
					$reducedScoringPerCent));

		} elsif (between($reduced_scoring_date, $set->due_date())) {
			print CGI::div({class=>"alert alert-warning mb-3"},
				$r->maketext("This set is in its reduced scoring period.  All work counts for [_1]% of its value.",
					$reducedScoringPerCent));
		} else {
			print CGI::div({class=>"alert alert-warning mb-3"},
				$r->maketext("This set had a reduced scoring period that started on [_1] and ended on [_2].  During that period all work counted for [_3]% of its value.",
					$beginReducedScoringPeriod, $dueDate, $reducedScoringPerCent));
		}
	}

	# If gateway list quiz versions.
	my $multiSet = $authz->hasPermissions($user, "view_multiple_sets");
	my $totalVersions = 0;
	if ($isGateway) {
		my $timeNow = time;
		my @setVers = $db->listSetVersions($effectiveUser, $set->set_id);
		$totalVersions = scalar @setVers;
		my $timeLimit = $set->version_time_limit() || 0;

		# Compute how many versions have been launched within timeInterval
		#     to determine if a new version can be created, if a version
		#     can be continued, and the date a next version can be started.
		#     If there is an open version with no submits, add button to
		#     continue the first such version found.
		#     Build a data hash for each version that is used to create the
		#     quiz versions table.
		my $continueVersion = 0;
		my $continueTimeLeft = 0;
		my $currentVersions = 0;
		my $lastTime = 0;
		my $timeInterval = $set->time_interval() || 0;
		my $maxVersions = $set->versions_per_interval() || 0;
		my @versData = ();
		foreach my $ver (@setVers) {
			my $verSet = $db->getMergedSetVersion($effectiveUser, $set->set_id, $ver);

			# Count number of versions in current timeInterval
			if (!$timeInterval || $verSet->version_creation_time() > ($timeNow - $timeInterval)) {
				$currentVersions++;
				$lastTime = $verSet->version_creation_time()
				if ($lastTime == 0 || $lastTime > $verSet->version_creation_time);
			}
			
			# Get a problem to determine how many submits have been made.
			my @ProblemNums = $db->listUserProblems($effectiveUser, $set->set_id);
			my $Problem = $db->getMergedProblemVersion($effectiveUser, $set->set_id, $ver, $ProblemNums[0]);
			my $verSubmits = (defined($Problem) && $Problem->num_correct() ne '')
				? $Problem->num_correct() + $Problem->num_incorrect() : 0;
			my $maxSubmits = $verSet->attempts_per_version() || 0;

			# Build data hash for this version.
			my $data = {};
			$data->{id} = $set->set_id.',v'.$ver;
			$data->{version} = $ver;
			$data->{start} = $self->formatDateTime($verSet->version_creation_time, undef, $ce->{studentDateDisplayFormat});

			# Display time left for timed quizzes, otherwise display close date.
			my $timeLeftText = '';
			if ($timeLimit > 0) {
				my $minutes = int(($verSet->due_date - $timeNow)/60);
				my $hours = int($minutes/60);
				$minutes %= 60;

				# Two cases to format time to work well with translation.
				if ($hours && $minutes) {
					$timeLeftText = $r->maketext('[quant,_1,hour] and [quant,_2,minute] remain.',
						$hours, $minutes);
				} else {
					# Translation Note: In this case only one of hours or minutes is non-zero,
					#  so the zero case of the "quant" will be used for the other two.
					$timeLeftText = $r->maketext('[quant,_1,hour,hours,][quant,_2,minute,minutes,] remain.',
						$hours, $minutes);
				}
			} else {
				$timeLeftText = $r->maketext('Closes on [_1]',
					$self->formatDateTime($verSet->due_date, undef, $ce->{studentDateDisplayFormat}));
			}

			if (defined($verSet->version_last_attempt_time) && $verSet->version_last_attempt_time > 0) {
				if ($timeNow < $verSet->due_date && ($maxSubmits <= 0 ||
						($maxSubmits > 0 && $verSubmits < $maxSubmits))
				) {
					if ($verSubmits > 0) {
						$data->{end} = $r->maketext('Additional submissions available.') . " $timeLeftText";
					} else {
						$data->{end} = $timeLeftText;
					}
				} else {
					$data->{end} = $self->formatDateTime($verSet->version_last_attempt_time,
						undef, $ce->{studentDateDisplayFormat});
				}
			} elsif ($timeNow < $verSet->due_date) {
				$data->{end} = $r->maketext('Test not yet submitted.') . " $timeLeftText";
			} else {
				$data->{end} = $r->maketext("No submissions. Over time.");
			}

			# Status Logic: Assuming it is always after the open date for test versions.
			# Matching can_showCorrectAnswer method where hide_work eq 'N' is
			# only honored before the answer_date if it also equals the due_date.
			# Using $set->answer_date since the template date is what is currently used to decide
			# if answers are available.
			my $canShowAns = (($verSet->hide_work eq 'N' && 
					($verSet->due_date == $verSet->answer_date || $timeNow >= $set->answer_date)) ||
				($verSet->hide_work eq 'BeforeAnswerDate' && $timeNow >= $set->answer_date)) ? 1 : 0;
			if ($timeNow < $verSet->due_date()) {
				if ($maxSubmits > 0 && $verSubmits >= $maxSubmits) {
					$data->{status} = $r->maketext('Completed.');
					$data->{status} .= $r->maketext(' Answers Available.') if ($canShowAns);
				} elsif ($verSubmits >= 1) {
					$data->{status} = $r->maketext('Open. Submitted.');
				} else {
					$data->{status} = $r->maketext('Open.');
					if ($continueVersion == 0) {
						$continueVersion = $ver;
						$continueTimeLeft = int(($verSet->due_date - $timeNow)/60);
					}
				}
			} else {
				if ($verSubmits > 0) {
					$data->{status} = $r->maketext('Completed.');
				} else {
					$data->{status} = $r->maketext('Closed.');
				}
				$data->{status} .= $r->maketext(' Answers Available.') if ($canShowAns);
			}

			# Only show download link if work is not hidden.
			# Only show version link if the set is open or if works is not hidden.
			$data->{show_download} = ($verSet->hide_work eq 'N' ||
				($verSet->hide_work eq 'BeforeAnswerDate' && $timeNow >= $set->answer_date)) ? 1 : 0;
			$data->{show_link} = ($data->{status} =~ /Open/ || $data->{show_download});

			$data->{score} = '&nbsp;';
			# Only show score if user has permission and assignment has at least one submit.
			if ($authz->hasPermissions($user, 'view_hidden_work') ||
				($verSet->hide_score eq 'N' && $verSubmits >= 1) ||
				($verSet->hide_score eq 'BeforeAnswerDate' && $timeNow > $set->answer_date))
			{
				my ($total, $possible) = grade_set($db, $verSet, $verSet->set_id, $effectiveUser, 1);
				$total = wwRound(2, $total);
				$data->{score} = "$total/$possible";
			}
			push @versData, $data;
		}

		my $urlModule = ($set->assignment_type() =~ /proctored/) ?
			'WeBWorK::ContentGenerator::ProctoredGatewayQuiz' :
			'WeBWorK::ContentGenerator::GatewayQuiz';

		# Display continue open test button if open non submitted version found.
		if ($continueVersion > 0) {
			my $continueText = $r->maketext('Click continue button below to resume current test.');

			if ($timeLimit > 0) {
				my $minutes = $continueTimeLeft;
				my $hours = int($minutes/60);
				$minutes %= 60;
				my $timeText = '';

				# Two cases to format time to work well with translation.
				if ($hours && $minutes) {
					$timeText = $r->maketext('You have [quant,_1,hour] and [quant,_2,minute]'
						. ' remaining to complete the test.',
						$hours, $minutes);
				} else {
					# Translation Note: In this case only one of hours or minutes is non-zero,
					# so the zero case of the "quant" will be used for the other two.
					$timeText = $r->maketext('You have [quant,_1,hour,hours,]'
						. '[quant,_2,minute,minutes,] remaining to complete the test.',
						$hours, $minutes);
				}
				$continueText .= ' ' . CGI::strong($timeText);
			}
			print CGI::p($continueText);

			if ($set->assignment_type =~ /proctor/) {
				print CGI::p($r->maketext('This test requires a proctor password to continue.'));
			}

			my $interactiveURL = $self->systemLink(
				$urlpath->newFromModule($urlModule, $r,
					courseID => $courseID, setID => $set->set_id.',v'.$continueVersion)
			);
			print CGI::div({ class => 'mb-3' },
				CGI::a({ href => $interactiveURL, class => 'btn btn-primary' },
					$r->maketext('Continue Open Test')
				)
			);

		# Otherwise display start new test button if available.
		} elsif (
			(
				$timeNow >= $set->open_date ||
				$authz->hasPermissions($user, "view_hidden_sets")
			) &&
			$timeNow <= $set->due_date &&
			!(
				$ce->{options}{enableConditionalRelease} &&
				is_restricted($db, $set, $effectiveUser)
			) &&
			($maxVersions <= 0 || $currentVersions < $maxVersions)
		) {
			# Print time limit for timed tests
			my $startText = $r->maketext('Click start button below to start a new version.');
			if ($timeLimit > 0) {
				my $hours = int($timeLimit / 3600);
				my $minutes = int(($timeLimit % 3600)/60);
				my $timeText = '';

				# Two cases to format time to work well with translation.
				if ($hours && $minutes) {
					$timeText = $r->maketext('You will have [quant,_1,hour] and [quant,_2,minute] to complete the test.',
						$hours, $minutes);
				} else {
					# Translation Note: In this case only one of hours or minutes is non-zero,
					# so the zero case of the "quant" will be used for the other two.
					$timeText = $r->maketext('You will have [quant,_1,hour,hours,]'
						. '[quant,_2,minute,minutes,] to complete the test.',
						$hours, $minutes);
				}
				$startText .= ' ' . CGI::strong($timeText);
			}
			print CGI::p($startText);

			if ($set->assignment_type =~ /proctor/) {
				print CGI::p($r->maketext('This test requires a proctor password to start.'));
			}

			my $interactiveURL = $self->systemLink(
				$urlpath->newFromModule($urlModule, $r,
					courseID => $courseID, setID => $set->set_id)
			);
			print CGI::div({ class=> 'mb-3'},
				CGI::a({ href => $interactiveURL, class => 'btn btn-primary' },
					$r->maketext('Start New Test')
				)
			);

		# Message about if/when next version will be available.
		} else {
			my $msg = $r->maketext('No more tests available.');

			# Can they open a test in the future?
			if ($timeInterval > 0) {
				my $nextTime = ($currentVersions == $maxVersions) ? $lastTime + $timeInterval : $timeNow + $timeInterval;
				if ($nextTime < $set->due_date) {
					$msg = $r->maketext('Next test will be available by [_1].',
						$self->formatDateTime($nextTime, 0, $ce->{studentDateDisplayFormat}));
				}
			}

			# Is it past due date?
			if ($timeNow >= $set->due_date) {
				$msg = $r->maketext('Test is closed.');
			}

			print CGI::div(CGI::p(CGI::strong($msg)));
		}

		# Start of form for hardcopy of test versions.
		if ($multiSet && $totalVersions > 0) {
			print CGI::start_form(
				-name   => 'problem-sets-form',
				-id     => 'problem-sets-form',
				-method => 'POST',
				-action => $hardcopyURL
			),
			$self->hidden_authen_fields;
		}


		if ($totalVersions > 0) {
			print CGI::start_div({ class => 'table-responsive' });
			print CGI::start_table({
				class    => 'problem_set_table table table-sm caption-top font-sm',
				summary => $r->maketext(
					'This table lists the current attempts for this test/quiz, '
					. 'along with its status, score, start date, and close date. '
					. 'Click on the version link to access that version. '
					. 'There is also a Generate Hardcopy and Email Instrucotr button below.'
				)
			});
			print CGI::caption($r->maketext('Test Versions'));
			print CGI::thead(CGI::Tr(
				CGI::th({ scope => 'col'}, 'Versions'),
				CGI::th({ scope => 'col'}, 'Status'),
				CGI::th({ scope => 'col'}, 'Score'),
				CGI::th({ scope => 'col'}, 'Start'),
				CGI::th({ scope => 'col'}, 'End'),
				CGI::th(
					{ scope => 'col', class => 'hardcopy'},
					CGI::i(
						{
							class => 'icon far fa-lg fa-arrow-alt-circle-down',
							aria_hidden => 'true',
							title => $r->maketext('Generate Hardcopy'),
							data_alt => $r->maketext('Generate Hardcopy')
						},
						''
					)
				),
			));
			print CGI::start_tbody();
		}

		foreach my $ver (@versData) {
			# Download hardcopy.
			my $control = '';
			if ($multiSet) {
				$control = CGI::input({
					type  => 'checkbox',
					id    => $ver->{id},
					name  => 'selected_sets',
					value => $ver->{id},
					class => 'form-check-input'
				});
			
			# Only display download option if answers are available.
			} elsif ($ver->{show_download}) {
				my $hardcopyPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Hardcopy", $r,
					courseID => $courseID, setID => $ver->{id});
				my $link = $self->systemLink($hardcopyPage, params => { selected_sets => $ver->{id} });
				$control = CGI::a(
					{ class => 'hardcopy-link', href => $link },
					CGI::i(
						{
							class       => 'icon far fa-arrow-alt-circle-down fa-lg',
							aria_hidden => 'true',
							title       => $r->maketext('Download [_1]', $ver->{id} =~ s/_/ /gr),
							data_alt    => $r->maketext('Download [_1]', $ver->{id} =~ s/_/ /gr)
						},
						''
					)
				);
			}

			my $interactive = $r->maketext('Version #[_1]', $ver->{version});
			if ($authz->hasPermissions($user, 'view_hidden_work') || $ver->{show_link}) {
				my $interactiveURL = $self->systemLink(
					$urlpath->newFromModule($urlModule, $r,
						courseID => $courseID, setID => $ver->{id} ));
				$interactive = CGI::a(
					{
						class             => 'set-id-tooltip',
						data_bs_toggle    => 'tooltip',
						data_bs_placement => 'right',
						data_bs_title     => $set->description(),
						href  => $interactiveURL
					},
					$interactive
				);
			}

			print CGI::Tr(
				CGI::td($interactive),
				CGI::td(CGI::strong($ver->{status})),
				CGI::td([$ver->{score}, $ver->{start}, $ver->{end}]),
				CGI::td({class => 'hardcopy'}, $control)
			);
		}
		if ($totalVersions > 0) {
			print CGI::end_tbody();
			print CGI::end_table();
			print CGI::end_div();
		} else {
			print CGI::div(CGI::p($r->maketext('No versions of this test have been taken.')));
		}

	# Normal set, list problems
	} else {

		# DBFIXME use iterator
		my @problemNumbers = WeBWorK::remove_duplicates($db->listUserProblems($effectiveUser, $setName));

		# Check permissions and see if any of the problems have are gradeable
		my $canScoreProblems = 0;
		if ($authz->hasPermissions($user, "access_instructor_tools") &&
			$authz->hasPermissions($user, "score_sets")) {

			my @setUsers = $db->listSetUsers($setName);
			my @gradeableProblems;

			foreach my $problemID (@problemNumbers) {
				my $problem = $db->getGlobalProblem($setName, $problemID);

				if ($problem->flags =~ /essay/)  {
					$canScoreProblems = 1;
					$gradeableProblems[$problemID] = 1;
				}
			}

			$self->{gradeableProblems} = \@gradeableProblems if $canScoreProblems;
		}

		if (@problemNumbers) {
			# This table contains a summary, a caption, and scope variables for the columns.
			print CGI::div({ class => 'table-responsive' });
			print CGI::start_table({
					class => "problem_set_table table caption-top font-sm",
					summary => $r->maketext("This table shows the problems that are in this problem set.  " .
						"The columns from left to right are: name of the problem, current number of attempts made, " .
						"number of attempts remaining, the point worth, and the completion status.  Click on the " .
						"link on the name of the problem to take you to the problem page.")
				});
			print CGI::caption($r->maketext("Problems"));
			my $AdjustedStatusPopover = "&nbsp;" . CGI::a({
					class => 'help-popup',
					data_bs_content => $r->maketext('The adjusted status of a problem is the larger of the problem\'s ' .
						'status and the weighted average of the status of those problems which count towards the ' .
						'parent grade.'),
					data_bs_placement => 'top',
					data_bs_toggle => 'popover'
				}, CGI::i({ class => "icon fas fa-question-circle", aria_hidden => "true", data_alt => "Help Icon" }, ""));

			my $thRow = [ CGI::th($r->maketext("Name")),
				CGI::th($r->maketext("Attempts")),
				CGI::th($r->maketext("Remaining")),
				CGI::th($r->maketext("Worth")),
				CGI::th($r->maketext("Status")) ];
			if ($isJitarSet) {
				push @$thRow, CGI::th($r->maketext("Adjusted Status") . $AdjustedStatusPopover);
				push @$thRow, CGI::th($r->maketext("Counts for Parent"));
			}

			if ($canScoreProblems) {
				push @$thRow, CGI::th($r->maketext("Grader"));
			}

			print CGI::thead(CGI::Tr(@$thRow));
			print CGI::start_tbody();

			@problemNumbers = sort { $a <=> $b } @problemNumbers;

			foreach my $problemNumber (@problemNumbers) {
				my $problem = $db->getMergedProblem($effectiveUser, $setName, $problemNumber); # checked
				die "problem $problemNumber in set $setName for user $effectiveUser not found." unless $problem;
				print $self->problemListRow($set, $problem, $db, $canScoreProblems, $isJitarSet);
			}

			print CGI::end_tbody();
			print CGI::end_table();
			print CGI::end_div();
		} else {
			print CGI::p($r->maketext("This homework set contains no problems."));
		}

	} # End Gateway vs Normal assignment conditional

	# Display hardcopy button
	if ($isGateway && $multiSet && $totalVersions > 0) {
		print CGI::div({ class => 'mb-3' },
			CGI::reset({ id => 'clear', value => $r->maketext('Deselect All Test Versions'), class => 'btn btn-primary' })
		);
		print CGI::div({ class => 'mb-3' },
			CGI::submit({
				id => 'hardcopy',
				name => 'hardcopy',
				value => $r->maketext('Download PDF or TeX Hardcopy for Selected Tests'),
				class => 'btn btn-primary'
			})
		);
		print CGI::end_form();
	} elsif (! $isGateway) {
		print CGI::div(
			{ class => 'mb-3' },
			CGI::a(
				{ href => $hardcopyURL, class => 'btn btn-primary' },
				$r->maketext('Download PDF or TeX Hardcopy for Current Set')
			)
		);
	}

	print CGI::div({ class => 'mb-3' },
		$self->feedbackMacro(
			module => __PACKAGE__,
			set => $self->{set}->set_id,
			problem => "",
			displayMode => $self->{displayMode},
			showOldAnswers => "",
			showCorrectAnswers => "",
			showHints => "",
			showSolutions => "",
		)
	);

	return "";
}

sub problemListRow($$$$$) {
	my ($self, $set, $problem, $db, $canScoreProblems, $isJitarSet) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	my $courseID = $urlpath->arg("courseID");
	my $setID = $set->set_id;
	my $problemID = $problem->problem_id;
	my $problemNumber = $problemID;

	my $jitarRestriction = 0;
	my $problemLevel = 0;

	if ($isJitarSet) {
		my @seq = jitar_id_to_seq($problemID);
		$problemLevel = $#seq;
		$problemNumber = join('.', @seq);
	}

	# if the problem is closed we dont even print it
	if ($isJitarSet && !$authz->hasPermissions($problem->user_id, "view_unopened_sets") && is_jitar_problem_hidden($db, $problem->user_id, $setID, $problemID)) {
		return '';
	}

	my $interactiveURL = $self->systemLink(
		$urlpath->newFromModule("WeBWorK::ContentGenerator::Problem", $r,
			courseID => $courseID, setID => $setID, problemID => $problemID ));

	my $linkClasses = '';
	my $interactive;

	if ($problemLevel != 0) {
		$linkClasses = "nested-problem-$problemLevel";
	}

	# if the problem is trestricted we show that it exists but its greyed out
	if ($isJitarSet
		&& !$authz->hasPermissions($problem->user_id, "view_unopened_sets")
		&& is_jitar_problem_closed($db, $ce, $problem->user_id, $setID, $problemID))
	{
		$interactive = CGI::span({ class => $linkClasses . " disabled-problem text-nowrap" },
			$r->maketext("Problem [_1]", $problemNumber));
	} else {
		$interactive = CGI::a({ href => $interactiveURL, class => $linkClasses . " text-nowrap" },
			$r->maketext("Problem [_1]", $problemNumber));
	}

	my $attempts = $problem->num_correct + $problem->num_incorrect;
	# a blank yields 'infinite' because it evaluates as false with out giving warnings about comparing non-numbers
	my $remaining = ($problem->max_attempts || -1) < 0
		? $r->maketext("unlimited")
		: $problem->max_attempts - $attempts;

	my $value = $problem->value;

	$value = '' if ($isJitarSet && $problemLevel != 0
		&& !$problem->counts_parent_grade);

	my $rawStatus = 0;
	$rawStatus = $problem->status;

	my $status = eval{ wwRound(0, $rawStatus * 100).'%'}; # round to whole number
	$status = 'unknown(FIXME)' if $@; # use a blank if problem status was not defined or not numeric.
	# FIXME  -- this may not cover all cases.

	my $adjustedStatus = '';
	if (!$isJitarSet || $problemLevel == 0) {
		$adjustedStatus = jitar_problem_adjusted_status($problem, $db);
		$adjustedStatus = eval{wwRound(0, $adjustedStatus*100).'%'};
	}

	my $countsForParent = "";
	if ($isJitarSet && $problemLevel != 0 ) {
		$countsForParent = $problem->counts_parent_grade() ? $r->maketext('Yes') : $r->maketext('No');

	}

	my $graderLink = "";
	if ($canScoreProblems && $self->{gradeableProblems}[$problemID]) {
		my $gradeProblemPage = $urlpath->new(type => 'instructor_problem_grader',
			args => { courseID => $courseID, setID => $setID, problemID => $problemID });
		$graderLink = CGI::td(CGI::a({href => $self->systemLink($gradeProblemPage)}, $r->maketext("Grade Problem")));
	} elsif ($canScoreProblems) {
		$graderLink = CGI::td('');
	}

	my $problemRow = [CGI::td($interactive),
		CGI::td([
				$attempts,
				$remaining,
				$value,
				$status])];
	if ($isJitarSet) {
		push @$problemRow, CGI::td($adjustedStatus);
		push @$problemRow, CGI::td($countsForParent);
	}

	if ($canScoreProblems) {
		push @$problemRow, $graderLink;
	}

	return CGI::Tr({}, @$problemRow);
}

1;
