package Mojolicious::WeBWorK::Tasks::LTISetDateSync;
use Mojo::Base 'Minion::Job', -signatures, -async_await;

use Mojo::UserAgent;
use Mojo::Date;

use WeBWorK::Authen::LTIAdvantage::SubmitGrade;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Utils::DateTime qw(formatDateTime);

# Synchronize requested set dates to the LMS.
sub run ($job, $setIDs, $syncToLMS = 1) {
	# Establish a lock guard that only allows 1 job at a time (technically more than one could run at a time if a job
	# takes more than an hour to complete).  As soon as a job completes (or fails) the lock is released and a new job
	# can start.  New jobs retry every minute until they can acquire their own lock.
	return $job->retry({ delay => 60 }) unless my $guard = $job->minion->guard('lti_set_date_sync', 3600);

	# Minion does not support asynchronous jobs with notification of job completion, and so the Mojolicious::Promise
	# wait method must be used. The synchronizeSetDates method is used so that the async/await syntax can be used
	# instead of using the wait method on each method that needs to be awaited which would be tedious.  So the wait
	# method only needs to be used once here.
	$job->synchronizeSetDates($setIDs, $syncToLMS)->wait();

	return;
}

async sub synchronizeSetDates ($job, $setIDs, $syncToLMS) {
	my $courseID = $job->info->{notes}{courseID};
	return $job->fail('The course id was not passed when this job was enqueued.') unless $courseID;

	my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $courseID }) };
	return $job->fail('Could not construct course environment.') unless $ce;

	$job->{language_handle} = WeBWorK::Localize::getLoc($ce->{language} || 'en');

	return $job->fail($job->maketext('This course is not configured to synchronize set dates with the LMS via LTI.'))
		if !$ce->{LTIVersion} || $ce->{LTIVersion} ne 'v1p3' || $ce->{LTIGradeMode} ne 'homework';

	my $db = WeBWorK::DB->new($ce);
	return $job->fail($job->maketext('Could not obtain database connection.')) unless $db;

	my $lineitemsURL = $db->getSettingValue('LTILineitemsURL');
	return $job->fail($job->maketext('Could not perform date synchronization. The lineitems URL is not available.'))
		unless $lineitemsURL;

	my $accessToken =
		await WeBWorK::Authen::LTIAdvantage::SubmitGrade->new(({ ce => $ce, db => $db, app => $job->app }, 1))
		->get_access_token;
	return $job->fail($job->maketext('Could not perform date synchronization. Unable to obtain access token.'))
		unless $accessToken;

	my $ua = Mojo::UserAgent->new;

	my $lineitemsResult =
		(await $ua->get_p(
			$lineitemsURL, { Authorization => "$accessToken->{token_type} $accessToken->{access_token}" }))->result;

	return $job->fail($job->maketext(
		'There was an error obtaining the current lineitems from the LMS: [_1]',
		$lineitemsResult->message
	))
		unless $lineitemsResult->is_success;

	my %lineitems = map { $_->{resourceId} => $_ } grep { defined $_->{resourceId} } @{ $lineitemsResult->json };

	my @messages;

	for my $set ($db->getGlobalSetsWhere({ set_id => $setIDs })) {
		unless ($lineitems{ $set->set_id }) {
			# If a link to a set was not created via deep linking, then the lineitem obtained from the lineitems URL
			# will not have the resourceId. But if the link was used by someone, then the lineitem URL for the set will
			# be in the lis_source_did column for the set. So that can be used to get the current lineitem information
			# from the LMS.
			if ($set->lis_source_did) {
				my $lineitemResult = (await $ua->get_p(
					$set->lis_source_did,
					{ Authorization => "$accessToken->{token_type} $accessToken->{access_token}" }
				))->result;

				if ($lineitemResult->is_success) {
					$lineitems{ $set->set_id } = $lineitemResult->json;

					# Set the resourceId so that the LMS sends it the next time that date synchronization occurs.
					$lineitems{ $set->set_id }{resourceId} = $set->set_id;

					# If not synchronizing dates to the LMS, then update the lineitem to the LMS now, so that the
					# resourceId will be set in the LMS. If synchronizing dates to the LMS this will be included when
					# the dates are sent, so it isn't needed now.
					if (!$syncToLMS) {
						my $updateLineitemResult = (await $ua->put_p(
							$lineitems{ $set->set_id }{id},
							{
								Authorization  => "$accessToken->{token_type} $accessToken->{access_token}",
								'Content-Type' => 'application/vnd.ims.lis.v2.lineitem+json'
							},
							json => $lineitems{ $set->set_id }
						))->result;

						# Don't add a message about this to the job. This is an internal implementation detail the
						# instructor that queued the job doesn't need to know about. Just log it.
						$job->app->log->error('Failed to update the resource id for set '
								. $set->set_id
								. ' while performering date synchronization.')
							if !$updateLineitemResult->is_success;
					}
				}
			}
			unless ($lineitems{ $set->set_id }) {
				push(
					@messages,
					$job->maketext(
						'Skipping synchronization of dates for "[_1]" as the lineitem for this set is not available.',
						$set->set_id
					)
				);
				next;
			}
		}

		# Save the lineitem URL for the set if it is not yet in the database.
		if (!defined $set->lis_source_did || $set->lis_source_did ne $lineitems{ $set->set_id }{id}) {
			$set->lis_source_did($lineitems{ $set->set_id }{id});
			$db->putGlobalSet($set);
		}

		if ($syncToLMS) {
			$lineitems{ $set->set_id }{startDateTime} = formatDateTime($set->open_date, '%Y-%m-%dT%H:%M:%S%z');
			$lineitems{ $set->set_id }{endDateTime}   = formatDateTime($set->due_date,  '%Y-%m-%dT%H:%M:%S%z');

			my $updateLineitemResult = (await $ua->put_p(
				$lineitems{ $set->set_id }{id},
				{
					Authorization  => "$accessToken->{token_type} $accessToken->{access_token}",
					'Content-Type' => 'application/vnd.ims.lis.v2.lineitem+json'
				},
				json => $lineitems{ $set->set_id }
			))->result;

			if ($updateLineitemResult->is_success) {
				push(@messages, $job->maketext('Submitted dates for "[_1]" to the LMS.', $set->set_id));
			} else {
				push(
					@messages,
					$job->maketext(
						'Failed to submit dates for "[_1]" to the LMS: [_2]', $set->set_id,
						$updateLineitemResult->message
					)
				);
			}
		} else {
			my ($openDateChanged, $closeDateChanged) = (0, 0);
			if ($lineitems{ $set->set_id }{startDateTime}) {
				my $newOpenDate = Mojo::Date->new($lineitems{ $set->set_id }{startDateTime})->epoch;
				if (defined $newOpenDate) {
					$openDateChanged = 1 if $newOpenDate != $set->open_date;
					$set->open_date($newOpenDate);
				}
			}
			if ($lineitems{ $set->set_id }{endDateTime}) {
				my $newCloseDate = Mojo::Date->new($lineitems{ $set->set_id }{endDateTime})->epoch;
				if (defined $newCloseDate) {
					$closeDateChanged = 1 if $newCloseDate != $set->due_date;
					$set->due_date($newCloseDate);
				}
			}

			# Only change dates if at least one date was received from the LMS. Some LMSs do not support dates and will
			# not send them at all, or the dates may just not be set in the LMS in which case they also will not be
			# sent.
			unless ($openDateChanged || $closeDateChanged) {
				push(@messages, $job->maketext('The dates for "[_1]" were not changed.', $set->set_id));
				next;
			}

			# The following assumes that if the instructor is using synchronization of dates from the LMS, then the
			# instructor wants those dates to be used.  As such, this tries to make the dates work with the other dates
			# for the set.

			if ($set->open_date > $set->due_date) {
				if ($lineitems{ $set->set_id }{startDateTime} && $lineitems{ $set->set_id }{endDateTime}) {
					push(
						@messages,
						$job->maketext(
							'Error setting dates for [_1]: Invalid dates received from the LMS. '
								. 'The start date was not before the end date.',
							$set->set_id
						)
					);
					next;
				}
				# If one of the dates was received from the LMS, but not the other, and the current date stored for the
				# other does not work with the received date, then adjust the other date to make it work.
				if ($openDateChanged && !$closeDateChanged) {
					$set->due_date($set->open_date + 60 * $ce->{pg}{assignOpenPriorToDue});
				} elsif (!$openDateChanged && $closeDateChanged) {
					$set->open_date($set->due_date - 60 * $ce->{pg}{assignOpenPriorToDue});
				}
			}

			$set->answer_date($set->due_date + 60 * $ce->{pg}{answersOpenAfterDueDate})
				if $set->answer_date < $set->due_date;

			if (!$set->reduced_scoring_date
				|| $set->reduced_scoring_date < $set->open_date
				|| $set->reduced_scoring_date > $set->due_date)
			{
				if ($ce->{pg}{ansEvalDefaults}{enableReducedScoring} && $set->enable_reduced_scoring) {
					$set->reduced_scoring_date($set->due_date - 60 * $ce->{pg}{ansEvalDefaults}{reducedScoringPeriod});

					# If using the reducedScoringPeriod results in a time before the open date,
					# then just use the due date.
					$set->reduced_scoring_date($set->due_date) if $set->reduced_scoring_date < $set->open_date;
				} else {
					$set->reduced_scoring_date($set->due_date);
				}
			}

			$db->putGlobalSet($set);

			if ($ce->{pg}{ansEvalDefaults}{enableReducedScoring} && $set->enable_reduced_scoring) {
				push(
					@messages,
					$job->maketext(
						'Changed dates for "[_1]" to: open date: [_2], reduced scoring date: [_3], '
							. 'close date: [_4], answer date: [_5]',
						$set->set_id,
						(
							map {
								formatDateTime($set->$_, 'datetime_format_short', $ce->{siteDefaults}{timezone},
									$ce->{language})
							} 'open_date',
							'reduced_scoring_date',
							'due_date',
							'answer_date'
						)
					)
				);
			} else {
				push(
					@messages,
					$job->maketext(
						'Changed dates for "[_1]" to: open date: [_2], close date: [_3], answer date: [_4]',
						$set->set_id,
						(
							map {
								formatDateTime($set->$_, 'datetime_format_short', $ce->{siteDefaults}{timezone},
									$ce->{language})
							} 'open_date',
							'due_date',
							'answer_date'
						)
					)
				);
			}
		}
	}

	return $job->finish(@messages > 1 ? \@messages : $messages[0]);
}

sub maketext ($job, @args) {
	return &{ $job->{language_handle} }(@args);
}

1;
