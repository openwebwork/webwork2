################################################################################
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

package WeBWorK::ContentGenerator::Instructor::SendMail;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SendMail - Entry point for User-specific data editing

=cut

use Email::Address::XS;
use Email::Stuffer;
use Try::Tiny;
use Data::Dump qw/dump/;
use Text::Wrap qw(wrap);

use WeBWorK::Debug;
use WeBWorK::Utils::Instructor qw(read_dir);

sub initialize ($c) {
	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;
	my $user  = $c->param('user');

	my @selected_filters;
	if   (defined($c->param('classList!filter'))) { @selected_filters = $c->param('classList!filter'); }
	else                                          { @selected_filters = ("all"); }

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	return unless $authz->hasPermissions($user, "send_mail");

	# Gather directory data
	my $emailDirectory    = $ce->{courseDirs}->{email};
	my $scoringDirectory  = $ce->{courseDirs}->{scoring};
	my $templateDirectory = $ce->{courseDirs}->{templates};

	my $openfilename = $c->param('openfilename');
	my $savefilename = $c->param('savefilename');
	my $mergefile    = $c->param('merge_file');

	#FIXME  get these values from global course environment (see subroutines as well)
	my $default_msg_file     = 'default.msg';
	my $old_default_msg_file = 'old_default.msg';

	#if mergefile or openfilename haven't been defined via parameter
	# check the database to see if there is a file we should use.
	# if they have been defined via parameter then we should update the db

	if (defined($openfilename) && $openfilename) {
		$db->setSettingValue("${user}_openfile", $openfilename);
	} elsif ($db->settingExists("${user}_openfile")) {
		$openfilename = $db->getSettingValue("${user}_openfile");
	}

	if (defined($mergefile) && $mergefile) {
		$db->setSettingValue("${user}_mergefile", $mergefile);
	} elsif ($db->settingExists("${user}_mergefile")) {
		$mergefile = $db->getSettingValue("${user}_mergefile");
		$mergefile = undef unless (-e "$ce->{courseDirs}{scoring}/$mergefile");
	}

	# Figure out action from submit data
	my $action = '';
	if ($c->param('sendEmail')) {
		$action = 'sendEmail';
	} elsif ($c->param('saveMessage')) {
		$action = 'saveMessage';
	} elsif ($c->param('saveAs')) {
		$action = 'saveAs';
	} elsif ($c->param('saveDefault')) {
		$action = 'saveDefault';
	} elsif ($c->param('openMessage')) {
		$action = 'openMessage';
	} elsif ($c->param('updateSettings')) {
		$action = 'updateSettings';
	} elsif ($c->param('previewMessage')) {
		$action = 'previewMessage';
	}

	# Get user record
	my $ur = $db->getUser($user);

	# Store data
	$c->{defaultFrom}    = $ur->rfc822_mailbox;
	$c->{defaultReply}   = $ur->rfc822_mailbox;
	$c->{defaultSubject} = $c->stash('courseID') . ' notice';

	$c->{rows}    = (defined($c->param('rows')))    ? $c->param('rows')    : $ce->{mail}->{editor_window_rows};
	$c->{columns} = (defined($c->param('columns'))) ? $c->param('columns') : $ce->{mail}->{editor_window_columns};
	$c->{default_msg_file}     = $default_msg_file;
	$c->{old_default_msg_file} = $old_default_msg_file;
	$c->{merge_file}           = $mergefile;

	my @classList = (defined($c->param('classList'))) ? $c->param('classList') : ($user);
	$c->{preview_user} = $classList[0] || $user;

	# Gather database data
	# Get all users except set level proctors and practice users.  If the current user has restrictions on viewable
	# sections or recitations, those are filtered out as well.  The users are sorted by user_id.
	my @Users = $db->getUsersWhere(
		{
			user_id => [ -and => { not_like => 'set_id:%' }, { not_like => "$ce->{practiceUserPrefix}\%" } ],
			$ce->{viewable_sections}{$user} || $ce->{viewable_recitations}{$user}
			? (
				-or => [
					$ce->{viewable_sections}{$user}    ? (section    => $ce->{viewable_sections}{$user})    : (),
					$ce->{viewable_recitations}{$user} ? (recitation => $ce->{viewable_recitations}{$user}) : ()
				]
				)
			: ()
		},
		'user_id'
	);

	# Filter out users who don't get included in email
	@Users = grep { $ce->status_abbrev_has_behavior($_->status, "include_in_email") } @Users;

	# Cache the user records for later use.
	$c->{ra_user_records} = \@Users;

	# Gather list of recipients
	my @send_to;
	my $recipients = $c->param('send_to') // '';
	if ($recipients eq 'all_students') {
		@send_to = map { $_->user_id } @Users;
	} elsif ($recipients eq 'studentID') {
		@send_to = $c->param('classList');
	}

	$c->{ra_send_to} = \@send_to;

	# Check the validity of the input file name
	my $input_file = '';
	# Make sure an input message file was submitted and exists.
	# Otherwise use the default message.
	if (defined($openfilename)) {
		if (-e "${emailDirectory}/$openfilename") {
			if (-R "${emailDirectory}/$openfilename") {
				$input_file = $openfilename;
			} else {
				$c->addbadmessage($c->maketext(
					'The file [_1] is not readable by the webserver. '
						. q{Check that it's permissions are set correctly.},
					"$emailDirectory/$openfilename"
				));
			}
		} else {
			$input_file = $default_msg_file;
			$c->addbadmessage($c->maketext(
				'The file [_1] cannot be found. '
					. 'Check whether it exists and whether the directory [_2] can be read by the webserver. ',
				"$emailDirectory/$openfilename",
				$emailDirectory
			));
			$c->addbadmessage($c->maketext('Using contents of the default message [_1] instead.', $default_msg_file));
		}
	} else {
		$input_file = $default_msg_file;
	}
	$c->{input_file} = $input_file;

	# Determine the file name to save message into
	my $output_file = 'FIXME no output file specified';
	if ($action eq 'saveDefault') {
		$output_file = $default_msg_file;
	} elsif ($action eq 'saveMessage' or $action eq 'saveAs') {
		if (defined($savefilename) and $savefilename) {
			$output_file = $savefilename;
		} else {
			$c->addbadmessage($c->maketext('No filename was specified for saving!  The message was not saved.'));
		}
	} elsif (defined($input_file)) {
		$output_file = $input_file;
	}

	# Sanity check on save file name
	if ($output_file =~ /^[~.]/ || $output_file =~ /\.\./) {
		$c->addbadmessage($c->maketext(
			'For security reasons, you cannot specify a message file from a directory higher than the '
				. q{email directory (you can't use ../blah/blah for example). }
				. 'Please specify a different file or move the needed file to the email directory.'
		));
	}
	unless ($output_file =~ m|\.msg$|) {
		$c->addbadmessage($c->maketext(
			'Invalid file name "[_1]". All email file names must end with the ".msg" extension.  '
				. 'Choose a file name with the ".msg" extension. The message was not saved.',
			$output_file
		));
	}

	$c->{output_file} = $output_file;

	# Determine input source
	my $input_source;
	if ($action) {
		$input_source = (defined($c->param('body')) and $action ne 'openMessage') ? 'form' : 'file';
	} else {
		$input_source = (defined($c->param('body'))) ? 'form' : 'file';
	}

	# Get inputs
	my ($from, $replyTo, $r_text, $subject);
	if ($input_source eq 'file') {

		($from, $replyTo, $subject, $r_text) = $c->read_input_file("$emailDirectory/$input_file");

	} elsif ($input_source eq 'form') {
		# read info from the form
		# bail if there is no message body

		$from    = $c->param('from');
		$replyTo = $c->param('replyTo');
		$subject = $c->param('subject');
		my $body = $c->param('body');
		# Sanity check: body must contain non-white space
		$c->addbadmessage($c->maketext('You didn\'t enter any message.'))
			unless $c->param('body') =~ /\S/;
		$r_text = \$body;

	}

	my $remote_host = $c->tx->remote_address || "UNKNOWN";

	# Store data
	$c->{from}        = $from;
	$c->{replyTo}     = $replyTo;
	$c->{subject}     = $subject;
	$c->{remote_host} = $remote_host;
	$c->{r_text}      = $r_text;

	#Determine the appropriate script action from the buttons
	#     first time actions
	#          open new file
	#          open default file
	#     choose merge file actions
	#          chose merge button
	#     option actions
	#       'reset rows'

	#     save actions
	#       "save" button
	#       "save as" button
	#       "save as default" button
	#     preview actions
	#       'preview' button
	#     email actions
	#       'entire class'
	#       'selected studentIDs'
	#     error actions (various)

	# if no form is submitted, gather data needed to produce the mail form and return
	my $to            = $c->param('To');
	my $script_action = '';

	if (not $action
		or $action eq 'openMessage'
		or $action eq 'updateSettings')
	{

		return '';
	}

	# If form is submitted deal with filled out forms
	# and various actions resulting from different buttons

	if ($action eq 'saveMessage' or $action eq 'saveAs' or $action eq 'saveDefault') {

		# construct message body
		my $temp_body = ${$r_text};
		$temp_body =~ s/\r\n/\n/g;
		$temp_body = join(
			"\n",
			"From: $from",
			"Reply-To: $replyTo",
			"Subject: $subject",
			"Content-Type: text/plain; charset=UTF-8",
			"Message:",
			# Do NOT encode to UTF-8 here.
			$temp_body
		);

		# overwrite protection
		if ($action eq 'saveAs' and -e "$emailDirectory/$output_file") {
			$c->addbadmessage($c->maketext(
				'The file [_1] already exists and cannot be overwritten. The message was not saved.',
				"$emailDirectory/$openfilename"
			));
			return;
		}

		# Back up existing file?
		if ($action eq 'saveDefault' and -e "$emailDirectory/$default_msg_file") {
			rename("$emailDirectory/$default_msg_file", "$emailDirectory/$old_default_msg_file")
				or die "Can't rename $emailDirectory/$default_msg_file to $emailDirectory/$old_default_msg_file ",
				"Check permissions for webserver on directory $emailDirectory. $!";
			$c->addgoodmessage($c->maketext('Backup file [_1] created.', "$emailDirectory/$old_default_msg_file"),);
		}

		# Save the message
		$c->saveMessageFile($temp_body, "${emailDirectory}/$output_file")
			unless ($output_file =~ /^[~.]/ || $output_file =~ /\.\./ || $output_file !~ m|\.msg$|);
		unless (!-w "${emailDirectory}/$output_file") {    # if there are no errors report success
			$c->addgoodmessage($c->maketext('Message saved to file [_1].', "$emailDirectory/$output_file"));
			$c->{input_file} = $output_file;
			$db->setSettingValue("${user}_openfile", $output_file);
		}

	} elsif ($action eq 'previewMessage') {
		$c->{response} = 'preview';

	} elsif ($action eq 'sendEmail') {
		# verify format of From address (one valid rfc2822/rfc5322 address)
		my @parsed_from_addrs = Email::Address::XS->parse($c->{from});
		unless (@parsed_from_addrs == 1) {
			$c->addbadmessage($c->maketext("From field must contain one valid email address."));
			return;
		}

		# verify format of Reply-to address (zero or more valid rfc2822/ref5322 addresses)
		if (defined $c->{replyTo} and $c->{replyTo} ne "") {
			my @parsed_replyto_addrs = Email::Address::XS->parse($c->{replyTo});
			unless (@parsed_replyto_addrs > 0) {
				$c->addbadmessage($c->maketext("Invalid Reply-to address."));
				return;
			}
		}

		# Check that recipients have been selected.
		unless (@{ $c->{ra_send_to} }) {
			$c->addbadmessage(
				$c->maketext('No recipients selected. Please select one or more recipients from the list below.'));
			return;
		}

		#  get merge file
		my $merge_file    = (defined($c->{merge_file})) ? $c->{merge_file} : 'None';
		my $rh_merge_data = $c->read_scoring_file($merge_file);
		unless (ref($rh_merge_data)) {
			$c->addbadmessage($c->maketext("No merge data file"));
			$c->addbadmessage($c->maketext("Can't read merge file [_1]. No message sent", $merge_file));
			return;
		}
		$c->{rh_merge_data} = $rh_merge_data;

		# we don't set the response until we're sure that email can be sent
		$c->{response} = 'send_email';

		# FIXME i'm not sure why we're pulling this out here -- mail_message_to_recipients does have
		# access to the course environment and should just grab it directly
		$c->{smtpServer} = $ce->{mail}->{smtpServer};

		# Do actual mailing in the after the response is sent, since it could take a long time
		# FIXME we need to do a better job providing status notifications for long-running email jobs
		Mojo::IOLoop->timer(
			1 => sub {
				# catch exceptions generated during the sending process
				my $result_message = eval { $c->mail_message_to_recipients() };
				if ($@) {
					# add the die message to the result message
					$result_message .=
						"An error occurred while trying to send email.\n" . "The error message is:\n\n$@\n\n";
					# and also write it to the Mojolicious log
					$c->log->error("An error occurred while trying to send email: $@\n");
				}
				# this could fail too...
				eval { $c->email_notification($result_message) };
				if ($@) {
					$c->log->error("An error occured while trying to send the email notification: $@\n");
				}
			}
		);
	} else {
		$c->addbadmessage($c->maketext("Didn't recognize action"));
	}

	return;
}

sub print_preview ($c) {
	# Get preview user
	my $ur = $c->db->getUser($c->{preview_user});
	die "record for preview user " . $c->{preview_user} . " not found." unless $ur;

	# Get merge file
	my $merge_file    = (defined($c->{merge_file})) ? $c->{merge_file} : 'None';
	my $rh_merge_data = $c->read_scoring_file($merge_file);

	my ($msg, $preview_header) = $c->process_message($ur, $rh_merge_data, 1);    # 1 == for preview

	my $recipients = join(" ", @{ $c->{ra_send_to} });

	# The content in message is going to be displayed in HTML.
	# It needs to have html entities escaped to avoid problems with things like <user@domain.com>.
	# Note that this escaping is done in the Mojolicious template automatically.
	$msg = join(
		"",
		"To: ",       $ur->email_address, "\n",
		"From: ",     $c->{from},         "\n",
		"Reply-To: ", $c->{replyTo},      "\n",
		"Subject: ",  $c->{subject},      "\n",
		# In a real mails we would UTF-8 encode the message and give the Content-Type header. For the preview which is
		# displayed as html, just add the header, but do NOT use Encode::encode("UTF-8",$msg).
		"Content-Type: text/plain; charset=UTF-8\n\n",
		wrap('', '', $msg),
		"\n"
	);

	return $c->include(
		'ContentGenerator/Instructor/SendMail/preview',
		preview_header => $preview_header,
		ur             => $ur,
		msg            => $msg,
		recipients     => $recipients
	);
}

# Utility methods
sub saveMessageFile ($c, $body, $msgFileName) {
	open(my $PROBLEM, ">:encoding(UTF-8)", $msgFileName)
		|| $c->addbadmessage("Could not open $msgFileName for writing. "
			. 'Check that the permissions for this file are 660 (-rw-rw----).');
	print $PROBLEM $body if -w $msgFileName;
	close $PROBLEM;

	chmod 0660, "$msgFileName"
		|| $c->addbadmessage("CAN'T CHANGE PERMISSIONS ON FILE $msgFileName");

	return;
}

sub read_input_file ($c, $filePath) {
	my ($text, @text);
	my $header = '';
	my ($subject, $from, $replyTo);

	if (-e "$filePath" and -r "$filePath") {
		open my $FILE, "<:encoding(UTF-8)", $filePath
			or do { $c->addbadmessage($c->maketext(q{Can't open [_1]}, $filePath)); return };
		while ($header !~ s/Message:\s*$//m and not eof($FILE)) {
			$header .= <$FILE>;
		}
		$text = join('', <$FILE>);
		close $FILE;

		$text   =~ s/^\s*//;           # remove initial white space if any.
		$header =~ /^From:\s(.*)$/m;
		$from = $1 or $from = $c->{defaultFrom};

		$header =~ /^Reply-To:\s(.*)$/m;
		$replyTo = $1 or $replyTo = $c->{defaultReply};

		$header =~ /^Subject:\s(.*)$/m;
		$subject = $1;

	} else {
		$from    = $c->{defaultFrom};
		$replyTo = $c->{defaultReply};
		$text    = (-e "$filePath") ? "FIXME file $filePath can't be read" : "FIXME file $filePath doesn't exist";
		$subject = $c->{defaultSubject};
	}

	return ($from, $replyTo, $subject, \$text);
}

sub get_message_file_names ($c) {
	return read_dir($c->{ce}{courseDirs}{email}, '\\.msg$');
}

sub get_merge_file_names ($c) {
	# FIXME: Check that only readable files are listed.
	return 'None', read_dir($c->{ce}{courseDirs}{scoring}, '\\.csv$');
}

sub mail_message_to_recipients ($c) {
	my $ce              = $c->ce;
	my $subject         = $c->{subject};
	my $from            = $c->{from};
	my @recipients      = @{ $c->{ra_send_to} };
	my $rh_merge_data   = $c->{rh_merge_data};
	my $merge_file      = $c->{merge_file};
	my $result_message  = '';
	my $failed_messages = 0;
	my $error_messages  = '';

	for my $recipient (@recipients) {
		$error_messages = '';

		my $ur = $c->db->getUser($recipient);
		unless ($ur) {
			$error_messages .= "Record for user $recipient not found\n";
			next;
		}
		unless ($ur->email_address =~ /\S/) {    #unless address contains a non-blank charachter
			$error_messages .= "User $recipient does not have an email address -- skipping\n";
			next;
		}

		my $msg = eval { $c->process_message($ur, $rh_merge_data) };
		$error_messages .= "There were errors in processing user $recipient, merge file $merge_file. \n$@\n" if $@;

		my $email = Email::Stuffer->to($ur->email_address)->from($from)->subject($subject)->text_body($msg)
			->header('X-Remote-Host' => $c->{remote_host});

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
				transport => $c->createEmailSenderTransportSMTP(),
				$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : ()
			});
			debug 'email sent successfully to ' . $ur->email_address;
		} catch {
			debug "Error sending email: $_";
			debug dump $@;
			$error_messages .= "Error sending email: $_";
			next;
		};

		$result_message .= $c->maketext("Message sent to [_1] at [_2].", $recipient, $ur->email_address) . "\n"
			unless $error_messages;
	} continue {    #update failed messages before continuing loop
		if ($error_messages) {
			$failed_messages++;
			$result_message .= $error_messages;
		}
	}
	my $number_of_recipients = scalar(@recipients) - $failed_messages;
	return $c->maketext(
		'A message with the subject line "[_1]" has been sent to [quant,_2,recipient] in the class [_3].  '
			. 'There were [_4] message(s) that could not be sent.',
		$subject, $number_of_recipients, $c->stash('courseID'), $failed_messages
		)
		. "\n\n"
		. $result_message;
}

sub email_notification ($c, $result_message) {
	my $ce = $c->ce;

	my $email = Email::Stuffer->to($c->{defaultFrom})->from($c->{defaultFrom})->subject('WeBWorK email sent')
		->text_body($result_message)->header('X-Remote-Host' => $c->{remote_host});

	try {
		$email->send_or_die({
			# createEmailSenderTransportSMTP is defined in ContentGenerator
			transport => $c->createEmailSenderTransportSMTP(),
			$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : ()
		});
	} catch {
		$c->log->error("Error sending email: $_");
	};

	$c->log->info("\nWW::Instructor::SendMail:: instructor message sent from $c->{defaultFrom}\n");

	return;
}

sub getRecord ($c, $line, $delimiter = ',') {
	#       Takes a delimited line as a parameter and returns an
	#       array.  Note that all white space is removed.  If the
	#       last field is empty, the last element of the returned
	#       array is also empty (unlike what the perl split command
	#       would return).  E.G. @lineArray=&getRecord(\$delimitedLine).

	my (@lineArray);
	$line .= "${delimiter}___";                         # add final field which must be non-empty
	@lineArray = split(/\s*${delimiter}\s*/, $line);    # split line into fields
	$lineArray[0] =~ s/^\s*//;                          # remove white space from first element
	pop @lineArray;                                     # remove the last artificial field
	return @lineArray;
}

sub process_message ($c, $ur, $rh_merge_data, $for_preview) {
	my $text       = defined($c->{r_text})       ? ${ $c->{r_text} } : 'FIXME no text was produced by initialization!!';
	my $merge_file = (defined($c->{merge_file})) ? $c->{merge_file}  : 'None';

	my $status_name = $c->ce->status_abbrev_to_name($ur->status);
	$status_name = $ur->status unless defined $status_name;

	#user macros that can be used in the email message
	my $SID        = $ur->student_id;
	my $FN         = $ur->first_name;
	my $LN         = $ur->last_name;
	my $SECTION    = $ur->section;
	my $RECITATION = $ur->recitation;
	my $STATUS     = $status_name;
	my $EMAIL      = $ur->email_address;
	my $LOGIN      = $ur->user_id;

	# get record from merge file
	# FIXME this is inefficient.  The info should be cached
	my @COL = defined($rh_merge_data->{$SID}) ? @{ $rh_merge_data->{$SID} } : ();
	if ($merge_file ne 'None' and not defined($rh_merge_data->{$SID}) and $for_preview) {
		$c->addbadmessage("No merge data for student id: $SID, name: $FN $LN, login: $LOGIN");
	}
	unshift(@COL, "");    ## this makes COL[1] the first column
	my $endCol = @COL;
	# for safety, only evaluate special variables
	my $msg = $text;
	$msg =~ s/\$SID/$SID/g;
	$msg =~ s/\$LN/$LN/g;
	$msg =~ s/\$FN/$FN/g;
	$msg =~ s/\$STATUS/$STATUS/g;
	$msg =~ s/\$SECTION/$SECTION/g;
	$msg =~ s/\$RECITATION/$RECITATION/g;
	$msg =~ s/\$EMAIL/$EMAIL/g;
	$msg =~ s/\$LOGIN/$LOGIN/g;

	if (defined($COL[1])) {    # prevents extraneous error messages.
		$msg =~ s/\$COL\[(\-?\d+)\]/$COL[$1]/g;
	} else {                   # prevents extraneous $COL's in email message
		$msg =~ s/\$COL\[(\-?\d+)\]//g;
	}

	$msg =~ s/\r//g;

	if ($for_preview) {
		my @preview_COL = @COL;
		shift @preview_COL;    # shift back for preview
		return $msg, $c->c('', $c->data_format(1 .. ($#COL)), '<br>', $c->data_format2(@preview_COL))->join(' ');
	} else {
		return $msg;
	}
}

sub data_format ($c, @data) {
	return map { "COL[$_]" . '&nbsp;' x (3 - length($_)) } @data;    # problems if $_ has length bigger than 4
}

sub data_format2 ($c, @data) {
	return map { $_ =~ s/\s/&nbsp;/gr } map { sprintf('%-8.8s', $_) } @data;
}

1;
