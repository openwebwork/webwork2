package Mojolicious::WeBWorK::Tasks::LTIMassUpdate;
use Mojo::Base 'Minion::Job', -signatures;

use WeBWorK::Authen::LTIAdvanced::SubmitGrade;
use WeBWorK::Authen::LTIAdvantage::SubmitGrade;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;

# Perform a mass update of grades via LTI.
sub run ($job, $userID = '', $setIDs = '') {
	# Establish a lock guard that only allows 1 job at a time (technically more than one could run at a time if a job
	# takes more than an hour to complete).  As soon as a job completes (or fails) the lock is released and a new job
	# can start.  New jobs retry every minute until they can acquire their own lock.
	return $job->retry({ delay => 60 }) unless my $guard = $job->minion->guard('lti_mass_update', 3600);

	my $courseID = $job->info->{notes}{courseID};
	return $job->fail('The course id was not passed when this job was enqueued.') unless $courseID;

	my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $courseID }) };
	return $job->fail('Could not construct course environment.') unless $ce;

	$job->{language_handle} = WeBWorK::Localize::getLoc($ce->{language} || 'en');

	my $db = WeBWorK::DB->new($ce);
	return $job->fail($job->maketext('Could not obtain database connection.')) unless $db;

	my @messages;
	my $job_logger = sub {
		my ($log, $level, @lines) = @_;
		push @messages, $lines[-1];
	};
	$job->app->log->on(message => $job_logger);

	# Pass a fake controller object that will work for the grader.
	my $grader =
		$ce->{LTIVersion} eq 'v1p1'
		? WeBWorK::Authen::LTIAdvanced::SubmitGrade->new({ ce => $ce, db => $db, app => $job->app }, 1)
		: WeBWorK::Authen::LTIAdvantage::SubmitGrade->new({ ce => $ce, db => $db, app => $job->app }, 1);

	# Determine what needs to be updated.
	my %updateUsers;
	if ($setIDs && $ce->{LTIGradeMode} eq 'homework') {
		if ($userID) {
			$updateUsers{$userID} = ref($setIDs) eq 'ARRAY' ? $setIDs : [$setIDs];
		} else {
			if (ref($setIDs) eq 'ARRAY') {
				%updateUsers = map { $_ => $setIDs } $db->listUsers;
			} else {
				%updateUsers = map { $_ => [$setIDs] } $db->listSetUsers($setIDs);
			}
		}
	} else {
		if ($ce->{LTIGradeMode} eq 'course') {
			%updateUsers = map { $_ => 'update_course_grade' } ($userID || $db->listUsers);
		} elsif ($ce->{LTIGradeMode} eq 'homework') {
			%updateUsers = map { $_ => [ $db->listUserSets($_) ] } ($userID || $db->listUsers);
		}
	}

	# Minion does not support asynchronous jobs.  At least if you want notification of job completion.  So call the
	# Mojolicious::Promise wait method instead.
	for my $user (keys %updateUsers) {
		if (ref($updateUsers{$user}) eq 'ARRAY') {
			for my $set (@{ $updateUsers{$user} }) {
				$grader->submit_set_grade($user, $set)->wait;
			}
		} elsif ($updateUsers{$user} eq 'update_course_grade') {
			$grader->submit_course_grade($user)->wait;
		}
	}

	if ($ce->{LTIGradeMode} eq 'homework') {
		if ($setIDs && ref($setIDs) eq 'ARRAY') {
			my $nSets = scalar(@$setIDs);
			if ($userID) {
				unshift(
					@messages,
					$job->maketext(
						'Updated grades via LTI for user [_1] for [_2] [plural,_2,set].',
						$userID, $nSets
					)
				);
			} else {
				unshift(@messages,
					$job->maketext('Updated grades via LTI for all users for [_1] [plural,_1,set].', $nSets));
			}
		} elsif ($setIDs) {
			if ($userID) {
				unshift(@messages,
					$job->maketext('Updated grades via LTI for user [_1] and set [_2].', $userID, $setIDs));
			} else {
				unshift(@messages, $job->maketext('Updated grades via LTI all users assigned to set [_1].', $setIDs));
			}
		} elsif ($userID) {
			unshift(@messages, $job->maketext('Updated grades via LTI of all sets assigned to user [_1].', $userID));
		} else {
			unshift(@messages, $job->maketext('Updated grades via LTI for all sets and users.'));
		}
	} elsif ($userID) {
		unshift(@messages, $job->maketext('Updated course grade for user [_1].', $userID));
	} else {
		unshift(@messages, $job->maketext('Updated course grade for all users.'));
	}

	$job->app->log->unsubscribe(message => $job_logger);

	$job->app->log->info($messages[0]);
	return $job->finish(@messages > 1 ? \@messages : $messages[0]);
}

sub maketext ($job, @args) {
	return &{ $job->{language_handle} }(@args);
}

1;
