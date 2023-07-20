###############################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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
	my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $mail_data->{courseName} }) };
	return $job->fail("Could not construct course environment for $mail_data->{courseName}.") unless $ce;

	my $db = WeBWorK::DB->new($ce->{dbLayout});
	return $job->fail("Could not obtain database connection for $mail_data->{courseName}.") unless $db;

	$job->{language_handle} = WeBWorK::Localize::getLoc($ce->{language} || 'en');

	my $result_message = eval { $job->mail_message_to_recipients($ce, $db, $mail_data) };
	if ($@) {
		$result_message .= "An error occurred while trying to send email.\n" . "The error message is:\n\n$@\n\n";
		$job->app->log->error("An error occurred while trying to send email: $@\n");
	}

	eval { $job->email_notification($ce, $mail_data, $result_message) };
	if ($@) {
		$job->app->log->error("An error occured while trying to send the email notification: $@\n");
		return $job->fail("FAILURE: Unable to send email notifation to instructor.");
	}

	return $job->finish("SUCCESS: Email messages sent.");
}

sub mail_message_to_recipients ($job, $ce, $db, $mail_data) {
	my $result_message  = '';
	my $failed_messages = 0;
	my $error_messages  = '';

	my @recipients = @{ $mail_data->{recipients} };

	for my $recipient (@recipients) {
		$error_messages = '';

		my $user_record = $db->getUser($recipient);
		unless ($user_record) {
			$error_messages .= "Record for user $recipient not found\n";
			next;
		}
		unless ($user_record->email_address =~ /\S/) {
			$error_messages .= "User $recipient does not have an email address -- skipping\n";
			next;
		}

		my $msg = processEmailMessage(
			$mail_data->{text}, $user_record,
			$ce->status_abbrev_to_name($user_record->status),
			$mail_data->{merge_data}
		);

		my $email =
			Email::Stuffer->to($user_record->email_address)->from($mail_data->{from})->subject($mail_data->{subject})
			->text_body($msg)->header('X-Remote-Host' => $mail_data->{remote_host});

		eval {
			$email->send_or_die({
				transport => createEmailSenderTransportSMTP($ce),
				$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : ()
			});
			debug 'email sent successfully to ' . $user_record->email_address;
		};
		if ($@) {
			debug "Error sending email: $@";
			$error_messages .= "Error sending email: $@";
			next;
		}

		$result_message .=
			$job->maketext('Message sent to [_1] at [_2].', $recipient, $user_record->email_address) . "\n"
			unless $error_messages;
	} continue {
		# Update failed messages before continuing loop.
		if ($error_messages) {
			$failed_messages++;
			$result_message .= $error_messages;
		}
	}

	my $number_of_recipients = @recipients - $failed_messages;
	return $job->maketext(
		'A message with the subject line "[_1]" has been sent to [quant,_2,recipient] in the class [_3].  '
			. 'There were [_4] message(s) that could not be sent.',
		$mail_data->{subject}, $number_of_recipients, $mail_data->{courseName},
		$failed_messages
		)
		. "\n\n"
		. $result_message;
}

sub email_notification ($job, $ce, $mail_data, $result_message) {
	my $email =
		Email::Stuffer->to($mail_data->{defaultFrom})->from($mail_data->{defaultFrom})->subject('WeBWorK email sent')
		->text_body($result_message)->header('X-Remote-Host' => $mail_data->{remote_host});

	eval {
		$email->send_or_die({
			transport => createEmailSenderTransportSMTP($ce),
			$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : ()
		});
	};
	$job->app->log->error("Error sending email: $@") if $@;

	$job->app->log->info("WeBWorK::Tasks::SendInstructorEmail: Instructor message sent from $mail_data->{defaultFrom}");

	return;
}

sub maketext ($job, @args) {
	return &{ $job->{language_handle} }(@args);
}

1;
