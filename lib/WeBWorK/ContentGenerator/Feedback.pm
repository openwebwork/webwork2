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

package WeBWorK::ContentGenerator::Feedback;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Feedback - Send mail to professors.

=cut

use Data::Dumper;
use Email::Stuffer;
use Try::Tiny;

use WeBWorK::Upload;
use WeBWorK::Utils qw(createEmailSenderTransportSMTP fetchEmailRecipients);

# request paramaters used
#
# user
# key
# route
# set (if from ProblemSet or Problem)
# problem (if from Problem)
# displayMode (if from Problem)
# showOldAnswers (if from Problem)
# showCorrectAnswers (if from Problem)
# showHints (if from Problem)
# showSolutions (if from Problem)

# state data sent
#
# user object for current user
# permission level of current user
# current session key
# which ContentGenerator route called Feedback?
# set object for current set (if from ProblemSet or Problem)
# problem object for current problem (if from Problem)
# display options (if from Problem)

sub initialize ($c) {
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;

	# get form fields
	my $userID    = $c->param('user');
	my $route     = $c->param('route');
	my $setID     = $c->param('set');
	my $problemID = $c->param('problem');
	my $from      = $c->param('from');
	my $feedback  = $c->param('feedback');
	my $courseID  = $c->stash('courseID');

	my ($user, $set, $problem);

	$user = $db->getUser($userID) if $userID;
	$c->stash->{user_email_address} = $user ? $user->email_address : '';

	if (defined $user) {
		$set     = $db->getMergedSet($userID, $setID) if defined $setID && $setID ne '';
		$problem = $db->getMergedProblem($userID, $setID, $problemID)
			if defined $set && defined $problemID && $problemID ne '';
	} else {
		$set     = $db->getGlobalSet($setID) if defined $setID && $setID ne '';
		$problem = $db->getGlobalProblem($setID, $problemID)
			if defined $set && defined $problemID && $problemID ne '';
	}

	# Generate context URLs.
	(my $emailableURL, $c->stash->{returnURL}) = $c->generateURLs(set_id => $setID, problem_id => $problemID);

	return unless $authz->hasPermissions($userID, 'submit_feedback');

	# Determine the recipients of the email.
	my @recipients = $c->fetchEmailRecipients('receive_feedback', $user);
	$c->stash->{numRecipients} = scalar @recipients;

	return unless $c->stash->{numRecipients};

	if (defined $c->param('sendFeedback')) {
		# Get verbosity level.
		my $verbosity = $ce->{mail}{feedbackVerbosity};

		# Determine the sender of the email.
		my $sender;
		if ($user && $user->email_address) {
			$from   = $user->email_address;
			$sender = $user->rfc822_mailbox;
		}

		unless ($from) {
			$c->stash->{send_error} = $c->maketext('No Sender specified.');
			return;
		}
		unless ($from =~ /^[a-zA-Z0-9.!#$%&\'*+\/=?^_`~\-]+@[a-zA-Z0-9\-]+\.[a-zA-Z0-9.\-]+$/) {
			$c->stash->{send_error} = $c->maketext('Sender is not a valid email address.');
			return;
		}
		unless ($feedback) {
			$c->stash->{send_error} = $c->maketext('Message was blank.');
			return;
		}
		unless ($sender) {
			if ($user && $user->full_name) {
				$sender = $user->full_name . " <$from>";
			} else {
				$sender = $from;
			}
		}

		my %subject_map = (
			'c' => $courseID,
			'u' => $user    ? $user->user_id       : undef,
			's' => $set     ? $set->set_id         : undef,
			'p' => $problem ? $problem->problem_id : undef,
			'x' => $user    ? $user->section       : undef,
			'r' => $user    ? $user->recitation    : undef,
			'%' => '%',
		);
		my $chars   = join('', keys %subject_map);
		my $subject = $ce->{mail}{feedbackSubjectFormat} || 'WeBWorK question from %c: %u set %s/prob %p';
		$subject =~ s/%([$chars])/defined $subject_map{$1} ? $subject_map{$1} : ''/eg;

		my %data = (
			user         => $user,
			emailableURL => $emailableURL,
			feedback     => $feedback,
			problem      => $problem,
			set          => $set,
			verbosity    => $verbosity,
			remote_host  => $c->tx->remote_address || 'UNKNOWN',
			remote_port  => $c->tx->remote_port    || 'UNKNOWN'
		);

		my $email =
			Email::Stuffer->to(join(',', @recipients))->subject($subject)
			->text_body($c->render_to_string('ContentGenerator/Feedback/feedback_email', format => 'txt', %data))
			->html_body($c->render_to_string('ContentGenerator/Feedback/feedback_email', %data))
			->header('X-Remote-Host' => $data{remote_host});
		if ($ce->{feedback_sender_email}) {
			my $from_name = $user ? $user->full_name : $ce->{generic_sender_name};
			$email->from("$from_name <$ce->{feedback_sender_email}>")->reply_to($sender);
		} else {
			$email->from($sender);
		}

		# Extra headers
		$email->header('X-WeBWorK-Route',  $route)    if defined $route;
		$email->header('X-WeBWorK-Course', $courseID) if defined $courseID;
		if ($user) {
			$email->header('X-WeBWorK-User',       $user->user_id);
			$email->header('X-WeBWorK-Section',    $user->section);
			$email->header('X-WeBWorK-Recitation', $user->recitation);
		}
		$email->header('X-WeBWorK-Set',     $set->set_id)         if $set;
		$email->header('X-WeBWorK-Problem', $problem->problem_id) if $problem;

		# Add the attachment if one was provided.
		my $fileIDhash = $c->param('attachment');
		if ($fileIDhash) {
			my $attachment =
				WeBWorK::Upload->retrieve(split(/\s+/, $fileIDhash), dir => $ce->{webworkDirs}{uploadCache});

			# Get the filename and read its contents.
			my $filename = $attachment->filename;
			my $fh       = $attachment->fileHandle;
			my $contents;
			{
				local $/;
				$contents = <$fh>;
			};
			close $fh;
			$attachment->dispose;

			# Check to see that this is an allowed filetype.
			unless (lc($filename =~ s/.*\.//r) =~ /^(jpe?g|gif|png|pdf|zip|txt|csv)$/) {
				$c->stash->{send_error} =
					$c->maketext('The filetype of the attached file "[_1]" is not allowed.', $filename);
				return;
			}

			# Check to see that the attached file does not exceed the allowed size.
			if (length($contents) > $ce->{mail}{maxAttachmentSize} * 1000000) {

				$c->stash->{send_error} =
					$c->maketext('The attached file "[_1]" exceeds the allowed attachment size of [quant,_2,megabyte].',
						$filename, $ce->{mail}{maxAttachmentSize});
				return;
			}

			# Attach the file.
			$email->attach($contents, filename => $filename);
		}

		# $ce->{mail}{set_return_path} is the address used to report returned email if defined and non empty.
		# It is an argument used in sendmail (via Email::Stuffer::send_or_die).
		# For arcane historical reasons sendmail actually sets the field "MAIL FROM" and the smtp server then
		# uses that to set "Return-Path".
		# references:
		#  https://stackoverflow.com/questions/1235534/
		#      what-is-the-behavior-difference-between-return-path-reply-to-and-from
		#  https://metacpan.org/pod/Email::Sender::Manual::QuickStart#envelope-information
		try {
			$email->send_or_die({
				# createEmailSenderTransportSMTP is defined in ContentGenerator
				transport => createEmailSenderTransportSMTP($ce),
				$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : ()
			});
		} catch {
			$c->stash->{send_error} = $c->maketext('Failed to send message: [_1]', ref($_) ? $_->message : $_);
		};
	}

	return;
}

sub page_title ($c) {
	return $c->ce->{feedback_button_name} || $c->maketext('E-mail Instructor');
}

1;
