###############################################################################
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

package WeBWorK::Authen::LTI::GradePassback;
use Mojo::Base 'Exporter', -signatures, -async_await;

=head1 NAME

WeBWorK::Authen::LTI::GradePassback - Grade passback utilities for LTI authentication

=cut

use WeBWorK::Utils::DateTime qw(after before);
use WeBWorK::Utils::Sets qw(grade_set grade_gateway);

our @EXPORT_OK = qw(massUpdate passbackGradeOnSubmit getSetPassbackScore);

# These must be required and not used, and must be after the exports are defined above.
# Otherwise this will create a circular dependency with the SubmitGrade modules.
require WeBWorK::Authen::LTIAdvanced::SubmitGrade;
require WeBWorK::Authen::LTIAdvantage::SubmitGrade;

# Perform a mass update of all grades.  This is all user grades for course grade mode and all user set grades for
# homework grade mode if $manual_update is false.  Otherwise what is updated is determined by a combination of the grade
# mode and the useriD and setID parameters.  Note that the only required parameter is $c which should be a
# WeBWorK::Controller object with a valid course environment and database.
sub massUpdate ($c, $manual_update = 0, $userID = undef, $setID = undef) {
	my $ce = $c->ce;
	my $db = $c->db;

	# Sanity check.
	unless (ref($ce)) {
		warn('course environment is not defined');
		return;
	}
	unless (ref($db)) {
		warn('database reference is not defined');
		return;
	}

	# Only run an automatic update if the time interval has passed.
	if (!$manual_update) {
		my $lastUpdate     = $db->getSettingValue('LTILastUpdate') || 0;
		my $updateInterval = $ce->{LTIMassUpdateInterval} // -1;
		return unless ($updateInterval != -1 && time - $lastUpdate > $updateInterval);
		$db->setSettingValue('LTILastUpdate', time);
	}

	# Send warning if debug_lti_grade_passback is set.
	if ($ce->{debug_lti_grade_passback}) {
		if ($setID && $userID && $ce->{LTIGradeMode} eq 'homework') {
			warn "LTI Mass Update: Queueing grade update for user $userID and set $setID.\n";
		} elsif ($setID && $ce->{LTIGradeMode} eq 'homework') {
			warn "LTI Mass Update: Queueing grade update for all users assigned to set $setID.\n";
		} elsif ($userID) {
			warn "LTI Mass Update: Queueing grade update of all sets assigned to user $userID.\n";
		} else {
			warn "LTI Mass Update: Queueing grade update for all sets and users.\n";
		}
	}

	$c->minion->enqueue(lti_mass_update => [ $userID, $setID ], { notes => { courseID => $ce->{courseName} } });

	return;
}

async sub passbackGradeOnSubmit ($c, $userID, $set) {
	my $ce = $c->ce;

	my $LMSname = $ce->{LTI}{ $ce->{LTIVersion} }{LMS_name};

	if ($ce->{LTIGradeOnSubmit}) {
		my $LTIGradeResult = 0;

		my $grader =
			$ce->{LTIVersion} eq 'v1p1'
			? WeBWorK::Authen::LTIAdvanced::SubmitGrade->new($c)
			: WeBWorK::Authen::LTIAdvantage::SubmitGrade->new($c);

		if ($ce->{LTIGradeMode} eq 'course') {
			$LTIGradeResult = await $grader->submit_course_grade($userID, $set);
		} elsif ($ce->{LTIGradeMode} eq 'homework') {
			$LTIGradeResult = await $grader->submit_set_grade($userID, $set->set_id, $set);
		}
		if ($LTIGradeResult == 0) {
			return $c->maketext('Your score was not successfully sent to [_1].', $LMSname);
		} elsif ($LTIGradeResult > 0) {
			return $c->maketext('Your score was successfully sent to [_1].', $LMSname);
		} elsif ($LTIGradeResult < 0) {
			return $c->maketext('Your score will be sent to [_1] at a later time.', $LMSname);
		}
	} elsif ($ce->{LTIMassUpdateInterval} > 0) {
		if ($ce->{LTIMassUpdateInterval} < 120) {
			return $c->maketext('Scores are sent to [_1] every [quant,_2,second].',
				$LMSname, $ce->{LTIMassUpdateInterval});
		} elsif ($ce->{LTIMassUpdateInterval} < 7200) {
			return $c->maketext('Scores are sent to [_1] every [quant,_2,minute].',
				$LMSname, int($ce->{LTIMassUpdateInterval} / 60 + 0.99));
		} else {
			return $c->maketext('Scores are sent to [_1] every [quant,_2,hour].',
				$LMSname, int($ce->{LTIMassUpdateInterval} / 3600 + 0.9999));
		}
	}
}

sub setAttempted ($problems, $setVersions = undef) {
	return 0 unless ref($problems) eq 'ARRAY';

	# If this is a test with set versions, then it counts as "attempted" if there is more than one set version.
	return 1 if ref($setVersions) eq 'ARRAY' && @$setVersions > 1;

	for (@$problems) {
		return 1 if $_->attempted || $_->status > 0;
	}
	return 0;
}

sub earliestGatewayDate ($ce, $userSet, $setVersions) {
	# If there are no versions, use the template's date.
	return getLTISendScoresAfterDate($userSet, $ce) unless ref($setVersions) eq 'ARRAY';

	# Otherwise, use the earliest date among versions.
	my $earliest_date = -1;
	for (@$setVersions) {
		my $versionedSetDate = getLTISendScoresAfterDate($_, $ce);
		$earliest_date = $versionedSetDate if $earliest_date == -1 || $versionedSetDate < $earliest_date;
	}
	return $earliest_date;
}

sub getLTISendScoresAfterDate ($set, $ce) {
	if ($ce->{LTISendScoresAfterDate} eq 'open_date') {
		return $set->open_date;
	} elsif ($ce->{LTISendScoresAfterDate} eq 'reduced_scoring_date') {
		return ($ce->{pg}{ansEvalDefaults}{enableReducedScoring}
				&& $set->enable_reduced_scoring
				&& $set->reduced_scoring_date) ? $set->reduced_scoring_date : $set->due_date;
	} elsif ($ce->{LTISendScoresAfterDate} eq 'due_date') {
		return $set->due_date;
	} elsif ($ce->{LTISendScoresAfterDate} eq 'answer_date') {
		return $set->answer_date;
	}
}

# Returns a reference to hash with the keys totalRight, total, and score if the
# set has met the conditions for grade pass back to occur, and undef otherwise.
sub getSetPassbackScore ($db, $ce, $userID, $userSet, $gradingSubmission = 0) {
	my ($totalRight, $total, $problemRecords, $setVersions) =
		$userSet->assignment_type =~ /gateway/
		? grade_gateway($db, $userSet->set_id, $userID)
		: grade_set($db, $userSet, $userID);

	my $return = { totalRight => $totalRight, total => $total, score => $total ? $totalRight / $total : 0 };

	return $return if $gradingSubmission && $ce->{LTISendGradesEarlyThreshold} eq 'attempted';

	my $criticalDate =
		$ce->{LTISendScoresAfterDate} ne 'never'
		? ($userSet->assignment_type =~ /gateway/
			? earliestGatewayDate($ce, $userSet, $setVersions)
			: getLTISendScoresAfterDate($userSet, $ce))
		: undef;

	return $return
		if ($criticalDate && after($criticalDate))
		|| ($ce->{LTISendGradesEarlyThreshold} eq 'attempted' && setAttempted($problemRecords, $setVersions))
		|| ($ce->{LTISendGradesEarlyThreshold} ne 'attempted'
			&& $return->{score} >= $ce->{LTISendGradesEarlyThreshold});

	return;
}

1;
