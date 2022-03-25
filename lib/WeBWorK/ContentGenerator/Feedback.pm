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

package WeBWorK::ContentGenerator::Feedback;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Feedback - Send mail to professors.

=cut

# *** feedback should be exempt from authentication, so that people can send
# feedback from the login page!

use strict;
use warnings;
use utf8;
use Data::Dumper;
use Data::Dump qw/dump/;
use WeBWorK::Debug;
use WeBWorK::CGI;
use Email::Stuffer;
use Try::Tiny;
use WeBWorK::Upload;

use Socket qw/unpack_sockaddr_in inet_ntoa/; # for remote host/port info
use Text::Wrap qw(wrap);
use WeBWorK::Utils qw/ decodeAnswers/;


use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

# request paramaters used
#
# user
# key
# module
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
# which ContentGenerator module called Feedback?
# set object for current set (if from ProblemSet or Problem)
# problem object for current problem (if from Problem)
# display options (if from Problem)

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;

	# get form fields
	my $key                = $r->param("key");
	my $userName           = $r->param("user");
	my $module             = $r->param("module");
	my $setName            = $r->param("set");
	my $problemNumber      = $r->param("problem");
	my $displayMode        = $r->param("displayMode");
	my $showOldAnswers     = $r->param("showOldAnswers");
	my $showCorrectAnswers = $r->param("showCorrectAnswers");
	my $showHints          = $r->param("showHints");
	my $showSolutions      = $r->param("showSolutions");
	my $from               = $r->param("from");
	my $feedback           = $r->param("feedback");
	my $courseID           = $r->urlpath->arg("courseID");

	my ($user, $set, $problem);
	$user = $db->getUser($userName) # checked
		if defined $userName and $userName ne "";
	if (defined $user) {
		$set = $db->getMergedSet($userName, $setName) # checked
			if defined $setName and $setName ne "";
		$problem = $db->getMergedProblem($userName, $setName, $problemNumber) # checked
			if defined $set and defined $problemNumber && $problemNumber ne "";
	} else {
		$set = $db->getGlobalSet($setName) # checked
			if defined $setName and $setName ne "";
		$problem = $db->getGlobalProblem($setName, $problemNumber) # checked
			if defined $set and defined $problemNumber && $problemNumber ne "";
	}

	# generate context URLs
	my ($emailableURL, $returnURL) = $self->generateURLs(set_id => $setName, problem_id => $problemNumber);

	my $homeModulePath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::Home", $r);
	my $systemURL = $self->systemLink($homeModulePath, authen=>0, use_abs_url=>1);

	unless ($authz->hasPermissions($userName, "submit_feedback")) {
		$self->feedbackNotAllowed($returnURL);
		return "";
	}

	# determine the recipients of the email
	my @recipients = $self->getFeedbackRecipients($user);

	unless (@recipients) {
		$self->noRecipientsAvailable($returnURL);
		return "";
	}

	if (defined $r->param("sendFeedback")) {
		# get verbosity level
		my $verbosity = $ce->{mail}->{feedbackVerbosity};

		# determine the sender of the email
		my $sender;
		if ($user) {
			if ($user->email_address) {
				# rfc822_mailbox was modified to use RFC 2047 "MIME-Header" encoding
				# when the full_name is set.
				$sender = $user->rfc822_mailbox;
			} else {
				if ($user->full_name) {
					# Encode the user name using "MIME-Header" encoding,
					# (RFC 2047) which allows UTF-8 encoded names to be
					# encoded inside the mail header using a special format.
					$sender = Encode::encode("MIME-Header", $user->full_name) . " <$from>";
				} else {
					$sender = $from;
				}
			}
		} else {
			$sender = $from;
		}

		# sanity checks
		unless ($sender) {
			$self->feedbackForm($user, $returnURL,
				"No Sender specified.");
			return "";
		}
		unless ($feedback) {
			$self->feedbackForm($user, $returnURL,
				"Message was blank.");
			return "";
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
		my $chars = join("", keys %subject_map);
		my $subject = $ce->{mail}{feedbackSubjectFormat}
			|| "WeBWorK question from %c: %u set %s/prob %p"; # default if not entered
		$subject =~ s/%([$chars])/defined $subject_map{$1} ? $subject_map{$1} : ""/eg;

		# If in the future any fields in the subject can contain non-ASCII characters
		# then we will also need:
		# $subject = Encode::encode("MIME-Header", $subject);
		# at present, this does not seem to be necessary.

		# get info about remote user (stolen from &WeBWorK::Authen::write_log_entry)
		my ($remote_host, $remote_port);

		my $APACHE24 = 0;
		# If its apache 2.4 then it has to also mod perl 2.0 or better
		if (MP2) {
		    my $version;

		    # check to see if the version is manually defined
		    if (defined($ce->{server_apache_version}) &&
			$ce->{server_apache_version}) {
			$version = $ce->{server_apache_version};
			# otherwise try and get it from the banner
		    } elsif (Apache2::ServerUtil::get_server_banner() =~
			   m:^Apache/(\d\.\d+):) {
			$version = $1;
		    }

		    if ($version) {
			$APACHE24 = version->parse($version) >= version->parse('2.4.0');
		    }
		}
		# If its apache 2.4 then the API has changed
		if ($APACHE24) {
		    $remote_host = $r->connection->client_addr->ip_get || "UNKNOWN";
		    $remote_port = $r->connection->client_addr->port || "UNKNOWN";
		} elsif (MP2) {
			$remote_host = $r->connection->remote_addr->ip_get || "UNKNOWN";
			$remote_port = $r->connection->remote_addr->port || "UNKNOWN";
		} else {
			($remote_port, $remote_host) = unpack_sockaddr_in($r->connection->remote_addr);
			$remote_host = defined $remote_host ? inet_ntoa($remote_host) : "UNKNOWN";
			$remote_port = "UNKNOWN" unless defined $remote_port;
		}

		my $msg = qq/This  message was automatically generated by the WeBWorK
system at $systemURL, in response to a request from $remote_host:$remote_port.

Click this link to see the page from which the user sent feedback:
$emailableURL

/;

		if ($feedback){
			$msg .= qq/***** The feedback message: *****\n\n\n$feedback\n\n\n/;
		}
		if($problem and $verbosity >=1){
			$msg .= qq/***** Data about the problem processor: ***** \n\n/
			. "Display Mode:         $displayMode\n"
			. "Show Old Answers:     ". ($showOldAnswers ? "yes" : "no") . "\n"
			. " Show Correct Answers: " . ($showCorrectAnswers ? "yes" : "no") . "\n"
			. " Show Hints:           " . ($showHints ? "yes" : "no") . "\n"
			. " Show Solutions:       " . ($showSolutions ? "yes" : "no") . "\n\n";
		}

		if ($user and $verbosity >= 1) {
			$msg .= "***** Data about the user: *****\n\n";
			$msg .= $self->format_user($user). "\n";
		}

		if ($problem and $verbosity >= 1) {
			$msg .= "***** Data about the problem: *****\n\n";
			$msg .= $self->format_userproblem($problem). "\n";
		}
		if ($set and $verbosity >= 1) {
			$msg .= "***** Data about the homework set: *****\n\n"
			. $self->format_userset($set). "\n";
		}
		if ($ce and $verbosity >= 2) {
			$msg .= "***** Data about the environment: *****\n\n",
			$msg .= Dumper($ce). "\n\n";
		}

		my $email = Email::Stuffer->to(join(',', @recipients))->from($sender)->subject($subject)
			->text_body(Encode::encode('UTF-8', $msg))->header('X-Remote-Host' => $remote_host);

		# Extra headers
		$email->header('X-WeBWorK-Module', $module)   if defined $module;
		$email->header('X-WeBWorK-Course', $courseID) if defined $courseID;
		if ($user) {
			$email->header('X-WeBWorK-User',       $user->user_id);
			$email->header('X-WeBWorK-Section',    $user->section);
			$email->header('X-WeBWorK-Recitation', $user->recitation);
		}
		$email->header('X-WeBWorK-Set',     $set->set_id)         if $set;
		$email->header('X-WeBWorK-Problem', $problem->problem_id) if $problem;

		# Add the attachment if one was provided.
		my $fileIDhash = $r->param('attachment');
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
				$self->feedbackForm($user, $returnURL,
					$r->maketext('The filetype of the attached file "[_1]" is not allowed.', $filename));
				return '';
			}

			# Check to see that the attached file does not exceed the allowed size.
			if (length($contents) > $ce->{mail}{maxAttachmentSize} * 1000000) {
				$self->feedbackForm(
					$user,
					$returnURL,
					$r->maketext(
						'The attached file "[_1]" exceeds the allowed attachment size of [quant,_2,megabyte].',
						$filename, $ce->{mail}{maxAttachmentSize}
					)
				);
				return '';
			}

			# Attach the file.
			$email->attach($contents, filename => $filename);
		}

		# $ce->{mail}{set_return_path} is the address used to report returned email if defined and non empty.
		# It is an argument used in sendmail() (aka Email::Stuffer::send_or_die).
		# For arcane historical reasons sendmail actually sets the field "MAIL FROM" and the smtp server then
		# uses that to set "Return-Path".
		# references:
		#  https://stackoverflow.com/questions/1235534/what-is-the-behavior-difference-between-return-path-reply-to-and-from
		#  https://metacpan.org/pod/Email::Sender::Manual::QuickStart#envelope-information
		try {
			$email->send_or_die({
				# createEmailSenderTransportSMTP is defined in ContentGenerator
				transport => $self->createEmailSenderTransportSMTP(),
				$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : ()
			});
			print CGI::p($r->maketext('Your message was sent successfully.'));
			print CGI::p(CGI::a({ -href => $returnURL }, $r->maketext('Return to your work')));
			print CGI::pre(wrap('', '', $feedback));
		} catch {
			$self->feedbackForm($user, $returnURL, "Failed to send message: $_");
		};
	} else {
		# just print the feedback form, with no message
		$self->feedbackForm($user, $returnURL, '');
	}

	return '';
}

sub feedbackNotAllowed {
	my ($self, $returnURL) = @_;

	print CGI::p("You are not allowed to send e-mail.");
	print CGI::p(CGI::a({-href=>$returnURL}, "Cancel E-Mail")) if $returnURL;
}

sub noRecipientsAvailable {
	my ($self, $returnURL) = @_;

	print CGI::p("No e-mail recipients are listed for this course.");
	print CGI::p(CGI::a({-href=>$returnURL}, "Cancel E-Mail")) if $returnURL;
}
sub title {
	my ($self, $user, $returnURL, $message) = @_;
	my $r = $self->r;
	return $r->maketext("E-mail Instructor");
}

sub feedbackForm {
	my ($self, $user, $returnURL, $message) = @_;
	my $r = $self->r;

	print CGI::start_form(-method => 'POST', -action => $r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields(qw(
		module set problem displayMode showOldAnswers showCorrectAnswers
		showHints showSolutions
	));

	print CGI::div(
		{ class => 'mb-3' },
		$r->maketext(
			'Use this form to ask your instructor a question, to report a problem with the WeBWorK system, or '
				. 'to report an error in a problem you are attempting. Along with your message, additional '
				. 'information about the state of the system will be included.'
		)
	);

	print CGI::div(
		{ class => 'row mb-3' },
		CGI::label({ for => 'from', class => 'col-form-label col-auto' }, CGI::b($r->maketext('From:'))),
		CGI::div(
			{ class => 'col-auto' },
			CGI::textfield({
				class => 'form-control',
				size  => 40,
				name  => 'from',
				id    => 'from',
				$user && $user->email_address
				? (disabled => undef, readonly => undef, value => $user->email_address)
				: (required => undef, value => $r->param('from') // '')
			})
		)
	);
	print CGI::div({ class => 'alert alert-danger mb-3' }, $message) if $message;
	print CGI::div(
		{ class => 'mb-3' },
		CGI::label({ for => 'feedback', class => 'form-label' }, CGI::b($r->maketext('E-mail:'))),
		CGI::textarea({
			name        => 'feedback',
			id          => 'feedback',
			rows        => '20',
			class       => 'form-control',
			placeholder => $r->maketext('Compose Email Message'),
			value       => $r->param('feedback') // '',
			required    => undef
		}),
	);

	# Attachment
	print CGI::div(
		{ class => 'row mb-3' },
		CGI::label({ for => 'attachment', class => 'col-form-label col-auto' }, CGI::b($r->maketext('Attachment:'))),
		CGI::div(
			{ class => 'col-auto' },
			CGI::filefield({
				name   => 'attachment',
				id     => 'attachment',
				class  => 'form-control',
				accept => 'image/*,application/pdf,application/zip,text/plain,text/csv'
			})
		)
	);

	print CGI::submit(
		{ name => 'sendFeedback', value => $r->maketext('Send E-mail'), class => 'btn btn-primary mb-1' });
	print CGI::end_form();
	print CGI::div(CGI::a({ href => $returnURL, class => 'btn btn-primary mt-2' }, $r->maketext('Cancel E-mail')))
		if $returnURL;
}

sub getFeedbackRecipients {
	my ($self, $user) = @_;
	my $ce = $self->r->ce;
	my $db = $self->r->db;
	my $authz = $self->r->authz;

	my @recipients;

	# send to all users with permission to receive_feedback and an email address
	foreach my $rcptName ($db->listUsers()) {
		if ($authz->hasPermissions($rcptName, "receive_feedback")) {
			my $rcpt = $db->getUser($rcptName); # checked
			next if $ce->{feedback_by_section} and defined $user
				and defined $rcpt->section and defined $user->section
				and $rcpt->section ne $user->section;
			if ($rcpt and $rcpt->email_address) {
				# rfc822_mailbox was modified to use RFC 2047 "MIME-Header" encoding
				# when the full_name is set.
				push @recipients, $rcpt->rfc822_mailbox;
			}
		}
	}

	if (defined $ce->{mail}->{feedbackRecipients}) {
		push @recipients, @{$ce->{mail}->{feedbackRecipients}};
	}

	return @recipients;
}

sub format_user {
	my ($self, $User) = @_;
	my $ce = $self->r->ce;

	my $result = "User ID:    " . $User->user_id . "\n";
	$result .= "Name:       " . $User->full_name . "\n";
	$result .= "Email:      " . $User->email_address . "\n";
	unless( $ce->{blockStudentIDinFeedback} ) {
		$result .= "Student ID: " . $User->student_id . "\n";
	}

	my $status_name = $ce->status_abbrev_to_name($User->status);
	my $status_string = defined $status_name
		? "$status_name ('" . $User->status . "')"
		: $User->status . " (unknown status abbreviation)";
	$result .= "Status:     $status_string\n";

	$result .= "Section:    " . $User->section . "\n";
	$result .= "Recitation: " . $User->recitation . "\n";
	$result .= "Comment:    " . $User->comment . "\n";

	return $result;
}

sub format_userset {
	my ($self, $Set) = @_;
	my $ce = $self->r->ce;

	my $result = "Set ID:                    " . $Set->set_id . "\n";
	$result .= "Set header file:           " . $Set->set_header . "\n";
	$result .= "Hardcopy header file:      " . $Set->hardcopy_header . "\n";

	my $tz = $ce->{siteDefaults}{timezone};
	$result .= "Open date:                 " . $self->formatDateTime($Set->open_date, $tz). "\n";
	$result .= "Due date:                  " . $self->formatDateTime($Set->due_date, $tz). "\n";
	$result .= "Answer date:               " . $self->formatDateTime($Set->answer_date, $tz) . "\n";
	$result .= "Visible:                   " . ($Set->visible ? "yes" : "no") . "\n";
	$result .= "Assignment type:           " . $Set->assignment_type . "\n";
	if ($Set->assignment_type =~ /gateway/) {
		$result .= "Attempts per version:      " . $Set->assignment_type . "\n";
		$result .= "Time interval:             " . $Set->time_interval . "\n";
		$result .= "Versions per interval:     " . $Set->versions_per_interval . "\n";
		$result .= "Version time limit:        " . $Set->version_time_limit . "\n";
		$result .= "Version creation time:     " . $self->formatDateTime($Set->version_creation_time, $tz) . "\n";
		$result .= "Problem randorder:         " . $Set->problem_randorder . "\n";
		$result .= "Version last attempt time: " . $Set->version_last_attempt_time . "\n";
	}

	return $result;
}

sub format_userproblem {
	my ($self, $Problem) = @_;
	my $ce = $self->r->ce;

	my $result = "Problem ID:                   " . $Problem->problem_id . "\n";
	$result .= "Source file:                  " . $Problem->source_file . "\n";
	$result .= "Value:                        " . $Problem->value . "\n";
	$result .= "Max attempts                  " . ($Problem->max_attempts == -1 ? "unlimited" : $Problem->max_attempts) . "\n";
	$result .= "Random seed:                  " . $Problem->problem_seed . "\n";
	$result .= "Status:                       " . $Problem->status . "\n";
	$result .= "Attempted:                    " . ($Problem->attempted ? "yes" : "no") . "\n";

	my %last_answer = decodeAnswers($Problem->last_answer);
	if (%last_answer) {
		$result .= "Last answer:\n";
		foreach my $key (sort keys %last_answer) {
			$result .= "\t$key: $last_answer{$key}\n" if $last_answer{$key};
		}
	} else {
		$result .= "Last answer:                  none\n";
	}

	$result .= "Number of correct attempts:   " . $Problem->num_correct . "\n";
	$result .= "Number of incorrect attempts: " . $Problem->num_incorrect . "\n";

	return $result;
}

1;
