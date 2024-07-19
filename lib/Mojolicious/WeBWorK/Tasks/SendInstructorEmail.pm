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

package Mojolicious::WeBWorK::Tasks::SendInstructorEmail;
use Mojo::Base 'Minion::Job', -signatures;

use Email::Stuffer;
use Email::Sender::Transport::SMTP;

use WeBWorK::Debug qw(debug);
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Localize;
use WeBWorK::Utils qw/processEmailMessage createEmailSenderTransportSMTP/;

# Send instructor email messages to students.
# FIXME: This job currently allows multiple jobs to run at once.  Should it be limited?
sub run ($job, $mail_data) {
	my $courseID = $job->info->{notes}{courseID};
	return $job->fail('The course id was not passed when this job was enqueued.') unless $courseID;

	my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $courseID }) };
	return $job->fail('Could not construct course environment.') unless $ce;

	$job->{language_handle} = WeBWorK::Localize::getLoc($ce->{language} || 'en');

	my $db = WeBWorK::DB->new($ce->{dbLayout});
	return $job->fail($job->maketext('Could not obtain database connection.')) unless $db;

	my @result_messages = eval { $job->mail_message_to_recipients($ce, $db, $mail_data) };
	if ($@) {
		push(@result_messages,
			$job->maketext('An error occurred while trying to send email.'),
			$job->maketext('The error message is: [_1]', ref($@) ? $@->message : $@),
		);
		$job->app->log->error($_) for @result_messages;
		return $job->fail(\@result_messages);
	}

	$job->app->log->error($_) for @result_messages;
	return $job->finish(\@result_messages);
}

sub mail_message_to_recipients ($job, $ce, $db, $mail_data) {
	my @result_messages;
	my $failed_messages = 0;
	my @error_messages;

	my @recipients = @{ $mail_data->{recipients} };

	for my $recipient (@recipients) {
		@error_messages = ();

		my $user_record = $db->getUser($recipient);
		unless ($user_record) {
			push(@error_messages, $job->maketext('Record for user [_1] not found.', $recipient));
			next;
		}
		unless ($user_record->email_address =~ /\S/) {
			push(@error_messages, $job->maketext('User [_1] does not have an email address.', $recipient));
			next;
		}

		my $msg = processEmailMessage(
			$mail_data->{text}, $user_record,
			$ce->status_abbrev_to_name($user_record->status),
			$mail_data->{merge_data}
		);

		my $email;
		if ($ce->{instructor_sender_email}) {
			$email =
				Email::Stuffer->to($user_record->email_address)
				->from($mail_data->{from_name} . ' <' . $ce->{instructor_sender_email} . '>')
				->reply_to($mail_data->{from})->subject($mail_data->{subject})->text_body($msg)
				->header('X-Remote-Host' => $mail_data->{remote_host});
		} else {
			$email =
				Email::Stuffer->to($user_record->email_address)->from($mail_data->{from})
				->subject($mail_data->{subject})->text_body($msg)->header('X-Remote-Host' => $mail_data->{remote_host});
		}

		eval {
			$email->send_or_die({
				transport => createEmailSenderTransportSMTP($ce),
				$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : ()
			});
			debug 'Email successfully sent to ' . $user_record->email_address;
		};
		if ($@) {
			my $exception_message = ref($@) ? $@->message : $@;
			debug 'Error sending email to ' . $user_record->email_address . ": $exception_message";
			push(
				@error_messages,
				$job->maketext(
					'Error sending email to [_1]: [_2]', $user_record->email_address, $exception_message
				)
			);
			next;
		}

		push(@result_messages, $job->maketext('Message sent to [_1] at [_2].', $recipient, $user_record->email_address))
			unless @error_messages;
	} continue {
		# Update failed messages before continuing loop.
		if (@error_messages) {
			$failed_messages++;
			push(@result_messages, @error_messages);
		}
	}

	my $number_of_recipients = @recipients - $failed_messages;
	return (
		$job->maketext(
			'A message with the subject line "[_1]" has been sent to [quant,_2,recipient].',
			$mail_data->{subject}, $number_of_recipients
		),
		$failed_messages
		? ($job->maketext(
			'There [plural,_1,was,were] [quant,_1,message] that could not be sent.',
			$failed_messages
		))
		: (),
		@result_messages
	);
}

sub maketext ($job, @args) {
	return &{ $job->{language_handle} }(@args);
}

1;
