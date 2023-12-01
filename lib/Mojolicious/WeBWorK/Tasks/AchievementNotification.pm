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
use WeBWorK::Utils qw(createEmailSenderTransportSMTP);

# send student notification that they have earned an achievement
sub run ($job, $mail_data) {
	my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $mail_data->{courseName} }); };
	return $job->fail("Could not construct course environment for $mail_data->{courseName}.")
		unless $ce;

	$job->{language_handle} =
		WeBWorK::Localize::getLoc($ce->{language} || 'en');

	my $db = WeBWorK::DB->new($ce->{dbLayout});
	return $job->fail($job->maketext("Could not obtain database connection for [_1].", $mail_data->{courseName}))
		unless $db;

	return $job->fail($job->maketext("Cannot notify student without an achievement."))
		unless $mail_data->{achievementID};
	$mail_data->{achievement} = $db->getAchievement($mail_data->{achievementID});
	return $job->fail($job->maketext("Could not find achievement [_1].", $mail_data->{achievementID}))
		unless $mail_data->{achievement};

	my $result_message = eval { $job->send_achievement_notification($ce, $db, $mail_data) };
	if ($@) {
		$job->app->log->error($job->maketext("An error occurred while trying to send email: $@"));
		return $job->fail($job->maketext("An error occurred while trying to send email: [_1]", $@));
	}
	$job->app->log->info("Message sent to $mail_data->{recipient}");
	return $job->finish($job->maketext("Message sent to [_1]", $mail_data->{recipient}));
}

sub send_achievement_notification ($job, $ce, $db, $mail_data) {
	my $from = $ce->{mail}{achievementEmailFrom};
	die 'Cannot send achievement email notification without mail{achievementEmailFrom}.' unless $from;

	my $user_record = $db->getUser($mail_data->{recipient});
	die "Record for user $mail_data->{recipient} not found\n" unless ($user_record);
	die "User $mail_data->{recipient} does not have an email address -- skipping\n"
		unless ($user_record->email_address =~ /\S/);

	my $template = "$ce->{courseDirs}{achievement_notifications}/$mail_data->{achievement}{email_template}";
	my $renderer = Mojo::Template->new(vars => 1);

	# what other data might need to be passed to the template?
	my $body = $renderer->render_file(
		$template,
		{
			ce              => $ce,                                               # holds achievement URLs
			achievement     => $mail_data->{achievement},                         # full db record
			setID           => $mail_data->{set_id},
			nextLevelPoints => $mail_data->{nextLevelPoints},
			pointsEarned    => $mail_data->{pointsEarned},
			user            => $user_record,
			user_status     => $ce->status_abbrev_to_name($user_record->status)
		}
	);

	my $email =
		Email::Stuffer->to($user_record->email_address)->from($from)->subject($mail_data->{subject})->text_body($body)
		->header('X-Remote-Host' => $mail_data->{remote_host});

	$email->send_or_die({
		transport => createEmailSenderTransportSMTP($ce),
		$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : ()
	});
	debug 'email sent successfully to ' . $user_record->email_address;

	return $job->maketext('Message sent to [_1] at [_2].', $mail_data->{recipient}, $user_record->email_address) . "\n";
}

sub maketext ($job, @args) {
	return &{ $job->{language_handle} }(@args);
}

1;
