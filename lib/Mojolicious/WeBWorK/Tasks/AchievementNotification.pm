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

package Mojolicious::WeBWorK::Tasks::AchievementNotification;
use Mojo::Base 'Minion::Job', -signatures;

use Email::Stuffer;
use Email::Sender::Transport::SMTP;

use WeBWorK::Debug qw(debug);
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Localize;
use WeBWorK::Utils qw/processEmailMessage createEmailSenderTransportSMTP/;

# send student notification that they have earned an achievement
sub run ($job, $mail_data) {
	my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $mail_data->{courseName} }); };
	return $job->fail("Could not construct course environment for $mail_data->{courseName}.")
		unless $ce;

	my $db = WeBWorK::DB->new($ce->{dbLayout});
	return $job->fail("Could not obtain database connection for $mail_data->{courseName}.")
		unless $db;

	return $job->fail("Cannot notify student without an achievement.")
		unless $mail_data->{achievementID};
	$mail_data->{achievement} =
		$db->getAchievement($mail_data->{achievementID});
	return $job->fail("Could not find achievement $mail_data->{achievementID}.")
		unless $mail_data->{achievement};

	$job->{language_handle} =
		WeBWorK::Localize::getLoc($ce->{language} || 'en');

	my $result_message = eval { $job->send_achievement_notification($ce, $db, $mail_data) };
	if ($@) {
		$job->app->log->error("An error occurred while trying to send email: $@");
		return $job->fail();    # fail silently
	}
	$job->app->log->info("Message sent to $mail_data->{recipient}");
	return $job->finish();      # succeed silently
}

sub send_achievement_notification ($job, $ce, $db, $mail_data) {
	if ($ce->{mail}{smtpSender} || $ce->{mail}{set_return_path}) {
		$mail_data->{from} =
			$ce->{mail}{smtpSender} || $ce->{mail}{set_return_path};
	} else {
		die "Cannot send system email without one of: mail{set_return_path} or mail{smtpSender}";
	}

	my $recipient = $mail_data->{recipient};
	my $template  = $ce->{courseDirs}{achievements} . '/' . $mail_data->{achievement}{email_template};
	my $renderer  = Mojo::Template->new(vars => 1);

	# what other data might need to be passed to the template?
	$mail_data->{body} = $renderer->render_file(
		$template,
		{
			ce              => $ce,                             # holds achievement URLs
			maketext        => sub { maketext($job, @_) },
			achievement     => $mail_data->{achievement},       # full db record
			setID           => $mail_data->{set_id},
			nextLevelPoints => $mail_data->{nextLevelPoints},
			pointsEarned    => $mail_data->{pointsEarned},
		}
	);

	my $user_record = $db->getUser($recipient);
	unless ($user_record) {
		die "Record for user $recipient not found\n";
	}
	unless ($user_record->email_address =~ /\S/) {
		die "User $recipient does not have an email address -- skipping\n";
	}

	# parse email template similar to how it is done in SendMail.pm
	my $msg = processEmailMessage(
		$mail_data->{body}, $user_record,
		$ce->status_abbrev_to_name($user_record->status),
		$mail_data->{merge_data}
	);

	my $email =
		Email::Stuffer->to($user_record->email_address)->from($mail_data->{from})->subject($mail_data->{subject})
		->text_body($msg)->header('X-Remote-Host' => $mail_data->{remote_host});

	$email->send_or_die({
		transport => createEmailSenderTransportSMTP($ce),
		$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : ()
	});
	debug 'email sent successfully to ' . $user_record->email_address;

	return $job->maketext('Message sent to [_1] at [_2].', $recipient, $user_record->email_address) . "\n";
}

sub maketext ($job, @args) {
	return &{ $job->{language_handle} }(@args);
}

1;
