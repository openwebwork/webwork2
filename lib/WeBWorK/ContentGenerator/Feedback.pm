package WeBWorK::ContentGenerator::Feedback;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Feedback - Send mail to professors.

=cut

use Data::Dumper;
use Email::Stuffer;
use GD;
use MIME::Base64 qw(decode_base64 encode_base64);
use Try::Tiny;

use WeBWorK::Upload;
use WeBWorK::Utils qw(createEmailSenderTransportSMTP fetchEmailRecipients formatEmailSubject);

# request parameters used
#
# user
# key
# route
# set (if from ProblemSet or Problem)
# problem (if from Problem)
# showOldAnswers (if from Problem)
# showCorrectAnswers (if from Problem)
# showHints (if from Problem)
# showSolutions (if from Problem)
# problemError (if from Problem and the problem failed to render)
# screenshot (if from Problem and $ce->{mail}{feedbackScreenshot} is set)
# includeScreenshot

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

	# Get the screenshot of the problem if one was sent.
	my $screenshot;
	if ($ce->{mail}{feedbackScreenshot}
		&& $problem
		&& ($c->param('screenshot') // '') =~ m{^data:image/png;base64,([A-Za-z0-9+/]+={0,2})$})
	{
		$screenshot = decode_base64($1);
		if (substr($screenshot, 0, 8) eq "\x89PNG\r\n\x1a\n"
			&& length($screenshot) <= $ce->{mail}{maxAttachmentSize} * 1000000)
		{
			# Reduce the size of the screenshot when it is first received from the problem page.
			if (!defined $c->param('sendFeedback')) {
				my $image = eval { GD::Image->newFromPngData($screenshot, 1) };
				if ($image) {
					$image->saveAlpha(1);
					$image->trueColorToPalette(0, 256);
					my $png = $image->png(9);
					$screenshot = $png if length($png) < length($screenshot);
				}
			}
			$c->stash->{screenshot} = 'data:image/png;base64,' . encode_base64($screenshot, '');
		} else {
			$screenshot = undef;
		}
	}

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

		my $subject = formatEmailSubject(
			$ce->{mail}{feedbackSubjectFormat},
			$courseID,
			$user    ? $user->user_id       : '',
			$set     ? $set->set_id         : '',
			$problem ? $problem->problem_id : '',
			$user    ? $user->section       : '',
			$user    ? $user->recitation    : ''
		);

		$screenshot = undef unless $c->param('includeScreenshot');
		my $screenshotCID = $screenshot ? sprintf('screenshot.%d.%X@webwork', time, int rand 2**32) : undef;

		my %data = (
			user          => $user,
			emailableURL  => $emailableURL,
			feedback      => $feedback,
			problem       => $problem,
			set           => $set,
			verbosity     => $verbosity,
			screenshotCID => $screenshotCID,
			problemError  => $problem ? substr($c->param('problemError') // '', 0, 5000) : '',
			remote_host   => $c->tx->remote_address || 'UNKNOWN',
			remote_port   => $c->tx->remote_port    || 'UNKNOWN'
		);

		my $email =
			Email::Stuffer->to(join(',', @recipients))
			->subject($subject)
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

		# Embed the screenshot in the html body, and attach it to the text body.
		if ($screenshot) {
			my $filename = 'screenshot-' . ($set ? $set->set_id . '-' . $problem->problem_id : 'problem') . '.png';
			$filename =~ s/[^\w.-]/_/g;
			$email->{parts} = [
				Email::MIME->create(
					attributes => { content_type => 'multipart/alternative' },
					parts      => [
						Email::MIME->create(
							attributes => { content_type => 'multipart/mixed' },
							parts      => [
								$email->{parts}[0],
								Email::MIME->create(
									attributes => {
										content_type => 'image/png',
										encoding     => 'base64',
										disposition  => 'attachment',
										filename     => $filename,
										name         => $filename
									},
									body => $screenshot
								)
							]
						),
						Email::MIME->create(
							attributes => { content_type => 'multipart/related' },
							parts      => [
								$email->{parts}[1],
								Email::MIME->create(
									attributes => {
										content_type => 'image/png',
										encoding     => 'base64',
										disposition  => 'inline',
										filename     => $filename,
										name         => $filename
									},
									header_str => [ 'Content-ID' => "<$screenshotCID>" ],
									body       => $screenshot
								)
							]
						)
					]
				)
			];
		}

		# Add the attachment if one was provided.
		my $fileIDhash = $c->param('attachment');
		if ($fileIDhash) {
			my $attachment =
				WeBWorK::Upload->retrieve(split(/\s+/, $fileIDhash), $ce->{webworkDirs}{uploadCache});

			# Get the filename and read its contents.
			my $filename = $attachment->filename;
			my $fh       = $attachment->fileHandle;
			my $contents;
			{
				local $/;
				$contents = <$fh>;
			};
			$fh->close;
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

			# Email::Stuffer incorrectly adds the attachment together with the text and html body parts at the same
			# level.  As a result, when an email has a text body, an html body, and an attachment, both the text and
			# html are shown in most email clients.  The text and html body should be parts of a separate part that has
			# content type 'multipart/alternative'.  So the email has two parts, and the first part has two parts which
			# are the text and html body.  The second part is the attachment. So before attaching the file move the text
			# and html body into their own part (unless that was already done above for the screenshot).
			$email->{parts} = [
				Email::MIME->create(
					attributes => { content_type => 'multipart/alternative' },
					parts      => $email->{parts}
				)
				]
				unless $screenshot;

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
