###############################################################################
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

package Mojolicious::WeBWorK::Tasks::LTIMassUpdate;
use Mojo::Base 'Minion::Job', -signatures;

use WeBWorK::Authen::LTIAdvanced::SubmitGrade;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;

# Perform a mass update of grades via LTI.
sub run ($job, $courseID, $userID = '', $setID = '') {
	# Establish a lock guard that only allow 1 job at a time (technichally more than one could run at a time if a job
	# takes more than an hour to complete).  As soon as a job completes (or fails) the lock is released and a new job
	# can start.  New jobs retry every minute until they can aquire their own lock.
	return $job->retry({ delay => 60 }) unless my $guard = $job->minion->guard('lti_mass_update', 3600);

	my $ce = eval { WeBWorK::CourseEnvironment->new({ %WeBWorK::SeedCE, courseName => $courseID }) };
	return $job->fail("Could not construct course environment for $courseID.") unless $ce;

	my $db = WeBWorK::DB->new($ce->{dbLayout});
	return $job->fail("Could not obtain database connection for $courseID.") unless $db;

	if ($setID && $userID && $ce->{LTIGradeMode} eq 'homework') {
		$job->app->log->info("LTI Mass Update: Starting grade update for user $userID and set $setID.");
	} elsif ($setID && $ce->{LTIGradeMode} eq 'homework') {
		$job->app->log->info("LTI Mass Update: Starting grade update for all users assigned to set $setID.");
	} elsif ($userID) {
		$job->app->log->info("LTI Mass Update: Starting grade update of all sets assigned to user $userID.");
	} else {
		$job->app->log->info('LTI Mass Update: Starting grade update for all sets and users.');
	}

	# Construct a fake r object that will work for the grader.
	my $r = { ce => $ce, db => $db, app => $job->app };

	my $grader = WeBWorK::Authen::LTIAdvanced::SubmitGrade->new($r);
	$grader->{post_processing_mode} = 1;

	eval {
		# Determine what needs to be updated.
		my %updateUsers;
		if ($setID && $userID && $ce->{LTIGradeMode} eq 'homework') {
			$updateUsers{$userID} = [$setID];
		} elsif ($setID && $ce->{LTIGradeMode} eq 'homework') {
			%updateUsers = map { $_ => [$setID] } $db->listSetUsers($setID);
		} else {
			if ($ce->{LTIGradeMode} eq 'course') {
				%updateUsers = map { $_ => 'update_course_grade' } ($userID || $db->listUsers);
			} elsif ($ce->{LTIGradeMode} eq 'homework') {
				%updateUsers = map { $_ => [ $db->listUserSets($_) ] } ($userID || $db->listUsers);
			}
		}

		for my $user (keys %updateUsers) {
			if (ref($updateUsers{$user}) eq 'ARRAY') {
				for my $set (@{ $updateUsers{$user} }) {
					$grader->submit_set_grade($user, $set);
				}
			} elsif ($updateUsers{$user} eq 'update_course_grade') {
				$grader->submit_course_grade($user);
			}
		}
	};
	if ($@) {
		# Write errors to the Mojolicious log.
		$job->app->log->error("An error occured while trying to mass update grades via LTI: $@");
		return $job->fail("An error ocurred while trying to mass update grades for $courseID: $@");
	}

	$job->app->log->info("Updated grades via LTI for course $courseID.");
	return $job->finish("Updated grades via LTI for course $courseID.");
}

1;
