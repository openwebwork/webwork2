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
use parent qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SendMail - Entry point for User-specific data editing

=cut

use strict;
use warnings;

use Email::Address::XS;
use Email::Stuffer;
use Try::Tiny;
use Data::Dump qw/dump/;
use Text::Wrap qw(wrap);

use WeBWorK::Debug;

sub initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $ce     = $r->ce;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	my @selected_filters;
	if   (defined($r->param('classList!filter'))) { @selected_filters = $r->param('classList!filter'); }
	else                                          { @selected_filters = ("all"); }

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	return unless $authz->hasPermissions($user, "send_mail");

	# Gather directory data
	my $emailDirectory    = $ce->{courseDirs}->{email};
	my $scoringDirectory  = $ce->{courseDirs}->{scoring};
	my $templateDirectory = $ce->{courseDirs}->{templates};

	my $openfilename = $r->param('openfilename');
	my $savefilename = $r->param('savefilename');
	my $mergefile    = $r->param('merge_file');

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
	if ($r->param('sendEmail')) {
		$action = 'sendEmail';
	} elsif ($r->param('saveMessage')) {
		$action = 'saveMessage';
	} elsif ($r->param('saveAs')) {
		$action = 'saveAs';
	} elsif ($r->param('saveDefault')) {
		$action = 'saveDefault';
	} elsif ($r->param('openMessage')) {
		$action = 'openMessage';
	} elsif ($r->param('updateSettings')) {
		$action = 'updateSettings';
	} elsif ($r->param('previewMessage')) {
		$action = 'previewMessage';
	}

	# Get user record
	my $ur = $db->getUser($user);

	# Store data
	$self->{defaultFrom}    = $ur->rfc822_mailbox;
	$self->{defaultReply}   = $ur->rfc822_mailbox;
	$self->{defaultSubject} = $self->r->urlpath->arg("courseID") . " notice";

	$self->{rows}    = (defined($r->param('rows')))    ? $r->param('rows')    : $ce->{mail}->{editor_window_rows};
	$self->{columns} = (defined($r->param('columns'))) ? $r->param('columns') : $ce->{mail}->{editor_window_columns};
	$self->{default_msg_file}     = $default_msg_file;
	$self->{old_default_msg_file} = $old_default_msg_file;
	$self->{merge_file}           = $mergefile;

	my @classList = (defined($r->param('classList'))) ? $r->param('classList') : ($user);
	$self->{preview_user} = $classList[0] || $user;

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
	$self->{ra_user_records} = \@Users;

	# Gather list of recipients
	my @send_to;
	my $recipients = $r->param('send_to') // '';
	if ($recipients eq 'all_students') {
		@send_to = map { $_->user_id } @Users;
	} elsif ($recipients eq 'studentID') {
		@send_to = $r->param('classList');
	}

	$self->{ra_send_to} = \@send_to;

	# Check the validity of the input file name
	my $input_file = '';
	# Make sure an input message file was submitted and exists.
	# Otherwise use the default message.
	if (defined($openfilename)) {
		if (-e "${emailDirectory}/$openfilename") {
			if (-R "${emailDirectory}/$openfilename") {
				$input_file = $openfilename;
			} else {
				$self->addbadmessage($r->maketext(
					'The file [_1] is not readable by the webserver. '
						. q{Check that it's permissions are set correctly.},
					"$emailDirectory/$openfilename"
				));
			}
		} else {
			$input_file = $default_msg_file;
			$self->addbadmessage($r->maketext(
				'The file [_1] cannot be found. '
					. 'Check whether it exists and whether the directory [_2] can be read by the webserver. ',
				"$emailDirectory/$openfilename",
				$emailDirectory
			));
			$self->addbadmessage(
				$r->maketext('Using contents of the default message [_1] instead.', $default_msg_file));
		}
	} else {
		$input_file = $default_msg_file;
	}
	$self->{input_file} = $input_file;

	# Determine the file name to save message into
	my $output_file = 'FIXME no output file specified';
	if ($action eq 'saveDefault') {
		$output_file = $default_msg_file;
	} elsif ($action eq 'saveMessage' or $action eq 'saveAs') {
		if (defined($savefilename) and $savefilename) {
			$output_file = $savefilename;
		} else {
			$self->addbadmessage($r->maketext('No filename was specified for saving!  The message was not saved.'));
		}
	} elsif (defined($input_file)) {
		$output_file = $input_file;
	}

	# Sanity check on save file name
	if ($output_file =~ /^[~.]/ || $output_file =~ /\.\./) {
		$self->addbadmessage($r->maketext(
			'For security reasons, you cannot specify a message file from a directory higher than the '
				. q{email directory (you can't use ../blah/blah for example). }
				. 'Please specify a different file or move the needed file to the email directory.'
		));
	}
	unless ($output_file =~ m|\.msg$|) {
		$self->addbadmessage($r->maketext(
			'Invalid file name "[_1]". All email file names must end with the ".msg" extension.  '
				. 'Choose a file name with the ".msg" extension. The message was not saved.',
			$output_file
		));
	}

	$self->{output_file} = $output_file;

	# Determine input source
	my $input_source;
	if ($action) {
		$input_source = (defined($r->param('body')) and $action ne 'openMessage') ? 'form' : 'file';
	} else {
		$input_source = (defined($r->param('body'))) ? 'form' : 'file';
	}

	# Get inputs
	my ($from, $replyTo, $r_text, $subject);
	if ($input_source eq 'file') {

		($from, $replyTo, $subject, $r_text) = $self->read_input_file("$emailDirectory/$input_file");

	} elsif ($input_source eq 'form') {
		# read info from the form
		# bail if there is no message body

		$from    = $r->param('from');
		$replyTo = $r->param('replyTo');
		$subject = $r->param('subject');
		my $body = $r->param('body');
		# Sanity check: body must contain non-white space
		$self->addbadmessage($r->maketext('You didn\'t enter any message.'))
			unless $r->param('body') =~ /\S/;
		$r_text = \$body;

	}

	my $remote_host = $r->useragent_ip || "UNKNOWN";

	# Store data
	$self->{from}        = $from;
	$self->{replyTo}     = $replyTo;
	$self->{subject}     = $subject;
	$self->{remote_host} = $remote_host;
	$self->{r_text}      = $r_text;

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
	my $to            = $r->param('To');
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
			$self->addbadmessage($r->maketext(
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
			$self->addgoodmessage($r->maketext('Backup file [_1] created.', "$emailDirectory/$old_default_msg_file"),);
		}

		# Save the message
		$self->saveMessageFile($temp_body, "${emailDirectory}/$output_file")
			unless ($output_file =~ /^[~.]/ || $output_file =~ /\.\./ || $output_file !~ m|\.msg$|);
		unless (!-w "${emailDirectory}/$output_file") {    # if there are no errors report success
			$self->addgoodmessage($r->maketext('Message saved to file [_1].', "$emailDirectory/$output_file"));
			$self->{input_file} = $output_file;
			$db->setSettingValue("${user}_openfile", $output_file);
		}

	} elsif ($action eq 'previewMessage') {
		$self->{response} = 'preview';

	} elsif ($action eq 'sendEmail') {
		# verify format of From address (one valid rfc2822/rfc5322 address)
		my @parsed_from_addrs = Email::Address::XS->parse($self->{from});
		unless (@parsed_from_addrs == 1) {
			$self->addbadmessage($r->maketext("From field must contain one valid email address."));
			return;
		}

		# verify format of Reply-to address (zero or more valid rfc2822/ref5322 addresses)
		if (defined $self->{replyTo} and $self->{replyTo} ne "") {
			my @parsed_replyto_addrs = Email::Address::XS->parse($self->{replyTo});
			unless (@parsed_replyto_addrs > 0) {
				$self->addbadmessage($r->maketext("Invalid Reply-to address."));
				return;
			}
		}

		# Check that recipients have been selected.
		unless (@{ $self->{ra_send_to} }) {
			$self->addbadmessage(
				$r->maketext('No recipients selected. Please select one or more recipients from the list below.'));
			return;
		}

		#  get merge file
		my $merge_file    = (defined($self->{merge_file})) ? $self->{merge_file} : 'None';
		my $delimiter     = ',';
		my $rh_merge_data = $self->read_scoring_file("$merge_file", "$delimiter");
		unless (ref($rh_merge_data)) {
			$self->addbadmessage($r->maketext("No merge data file"));
			$self->addbadmessage($r->maketext("Can't read merge file [_1]. No message sent", $merge_file));
			return;
		}
		$self->{rh_merge_data} = $rh_merge_data;

		# we don't set the response until we're sure that email can be sent
		$self->{response} = 'send_email';

		# FIXME i'm not sure why we're pulling this out here -- mail_message_to_recipients does have
		# access to the course environment and should just grab it directly
		$self->{smtpServer} = $ce->{mail}->{smtpServer};

		# Do actual mailing in the after the response is sent, since it could take a long time
		# FIXME we need to do a better job providing status notifications for long-running email jobs
		Mojo::IOLoop->timer(
			1 => sub {
				# catch exceptions generated during the sending process
				my $result_message = eval { $self->mail_message_to_recipients() };
				if ($@) {
					# add the die message to the result message
					$result_message .=
						"An error occurred while trying to send email.\n" . "The error message is:\n\n$@\n\n";
					# and also write it to the Mojolicious log
					$r->log->error("An error occurred while trying to send email: $@\n");
				}
				# this could fail too...
				eval { $self->email_notification($result_message) };
				if ($@) {
					$r->log->error("An error occured while trying to send the email notification: $@\n");
				}
			}
		);
	} else {
		$self->addbadmessage($r->maketext("Didn't recognize action"));
	}

	return;
}

sub print_preview {
	my ($self)  = @_;
	my $r       = $self->r;
	my $urlpath = $r->urlpath;
	my $setID   = $urlpath->arg("setID");

	# Get preview user
	my $ur = $r->db->getUser($self->{preview_user});
	die "record for preview user " . $self->{preview_user} . " not found." unless $ur;

	# Get merge file
	my $merge_file    = (defined($self->{merge_file})) ? $self->{merge_file} : 'None';
	my $delimiter     = ',';
	my $rh_merge_data = $self->read_scoring_file("$merge_file", "$delimiter");

	my ($msg, $preview_header) = $self->process_message($ur, $rh_merge_data, 1);    # 1 == for preview

	my $recipients = join(" ", @{ $self->{ra_send_to} });

	# The content in message is going to be displayed in HTML.
	# It needs to have html entities escaped to avoid problems with things like <user@domain.com>.
	# Note that this escaping is done in the Mojolicious template automatically.
	$msg = join(
		"",
		"To: ",       $ur->email_address, "\n",
		"From: ",     $self->{from},      "\n",
		"Reply-To: ", $self->{replyTo},   "\n",
		"Subject: ",  $self->{subject},   "\n",
		# In a real mails we would UTF-8 encode the message and give the Content-Type header. For the preview which is
		# displayed as html, just add the header, but do NOT use Encode::encode("UTF-8",$msg).
		"Content-Type: text/plain; charset=UTF-8\n\n",
		wrap('', '', $msg),
		"\n"
	);

	return $r->include(
		'ContentGenerator/Instructor/SendMail/preview',
		preview_header => $preview_header,
		ur             => $ur,
		msg            => $msg,
		recipients     => $recipients
	);
}

sub print_form {
	my ($self) = @_;
	return $self->r->include('ContentGenerator/Instructor/SendMail/main_form');
}

# Utility methods
sub saveMessageFile {
	my ($self, $body, $msgFileName) = @_;

	open(my $PROBLEM, ">:encoding(UTF-8)", $msgFileName)
		|| $self->addbadmessage("Could not open $msgFileName for writing. "
			. 'Check that the permissions for this file are 660 (-rw-rw----).');
	print $PROBLEM $body if -w $msgFileName;
	close $PROBLEM;

	chmod 0660, "$msgFileName"
		|| $self->addbadmessage("CAN'T CHANGE PERMISSIONS ON FILE $msgFileName");

	return;
}

sub read_input_file {
	my ($self, $filePath) = @_;
	my $r = $self->r;

	my ($text, @text);
	my $header = '';
	my ($subject, $from, $replyTo);

	if (-e "$filePath" and -r "$filePath") {
		open my $FILE, "<:encoding(UTF-8)", $filePath
			or do { $self->addbadmessage($r->maketext(q{Can't open [_1]}, $filePath)); return };
		while ($header !~ s/Message:\s*$//m and not eof($FILE)) {
			$header .= <$FILE>;
		}
		$text = join('', <$FILE>);
		close $FILE;

		$text   =~ s/^\s*//;           # remove initial white space if any.
		$header =~ /^From:\s(.*)$/m;
		$from = $1 or $from = $self->{defaultFrom};

		$header =~ /^Reply-To:\s(.*)$/m;
		$replyTo = $1 or $replyTo = $self->{defaultReply};

		$header =~ /^Subject:\s(.*)$/m;
		$subject = $1;

	} else {
		$from    = $self->{defaultFrom};
		$replyTo = $self->{defaultReply};
		$text    = (-e "$filePath") ? "FIXME file $filePath can't be read" : "FIXME file $filePath doesn't exist";
		$subject = $self->{defaultSubject};
	}

	return ($from, $replyTo, $subject, \$text);
}

sub get_message_file_names {
	my $self = shift;
	return $self->read_dir($self->{ce}->{courseDirs}->{email}, '\\.msg$');
}

sub get_merge_file_names {
	my $self = shift;
	return 'None',
		$self->read_dir($self->{ce}->{courseDirs}->{scoring}, '\\.csv$')
		;    #FIXME ? check that only readable files are listed.
}

sub mail_message_to_recipients {
	my $self            = shift;
	my $r               = $self->r;
	my $ce              = $r->ce;
	my $subject         = $self->{subject};
	my $from            = $self->{from};
	my @recipients      = @{ $self->{ra_send_to} };
	my $rh_merge_data   = $self->{rh_merge_data};
	my $merge_file      = $self->{merge_file};
	my $result_message  = '';
	my $failed_messages = 0;
	my $error_messages  = '';

	for my $recipient (@recipients) {
		$error_messages = '';

		my $ur = $self->{db}->getUser($recipient);
		unless ($ur) {
			$error_messages .= "Record for user $recipient not found\n";
			next;
		}
		unless ($ur->email_address =~ /\S/) {    #unless address contains a non-blank charachter
			$error_messages .= "User $recipient does not have an email address -- skipping\n";
			next;
		}

		my $msg = eval { $self->process_message($ur, $rh_merge_data) };
		$error_messages .= "There were errors in processing user $recipient, merge file $merge_file. \n$@\n" if $@;

		my $email = Email::Stuffer->to($ur->email_address)->from($from)->subject($subject)->text_body($msg)
			->header('X-Remote-Host' => $self->{remote_host});

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
			debug 'email sent successfully to ' . $ur->email_address;
		} catch {
			debug "Error sending email: $_";
			debug dump $@;
			$error_messages .= "Error sending email: $_";
			next;
		};

		$result_message .= $r->maketext("Message sent to [_1] at [_2].", $recipient, $ur->email_address) . "\n"
			unless $error_messages;
	} continue {    #update failed messages before continuing loop
		if ($error_messages) {
			$failed_messages++;
			$result_message .= $error_messages;
		}
	}
	my $courseName           = $self->r->urlpath->arg("courseID");
	my $number_of_recipients = scalar(@recipients) - $failed_messages;
	return $r->maketext(
		"A message with the subject line \"[_1]\" has been sent to [quant,_2,recipient] in the class [_3].  "
			. "There were [_4] message(s) that could not be sent.",
		$subject, $number_of_recipients, $courseName, $failed_messages)
		. "\n\n"
		. $result_message;
}

sub email_notification {
	my ($self, $result_message) = @_;
	my $ce = $self->r->ce;

	my $email = Email::Stuffer->to($self->{defaultFrom})->from($self->{defaultFrom})->subject('WeBWorK email sent')
		->text_body($result_message)->header('X-Remote-Host' => $self->{remote_host});

	try {
		$email->send_or_die({
			# createEmailSenderTransportSMTP is defined in ContentGenerator
			transport => $self->createEmailSenderTransportSMTP(),
			$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : ()
		});
	} catch {
		$self->r->log->error("Error sending email: $_");
	};

	$self->r->log->info("\nWW::Instructor::SendMail:: instructor message sent from $self->{defaultFrom}\n");

	return;
}

sub getRecord {
	my $self      = shift;
	my $line      = shift;
	my $delimiter = shift;
	$delimiter = ',' unless defined($delimiter);

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

sub process_message {
	my $self          = shift;
	my $ur            = shift;
	my $rh_merge_data = shift;
	my $for_preview   = shift;
	my $r             = $self->r;
	my $text       = defined($self->{r_text}) ? ${ $self->{r_text} } : 'FIXME no text was produced by initialization!!';
	my $merge_file = (defined($self->{merge_file})) ? $self->{merge_file} : 'None';

	my $status_name = $self->r->ce->status_abbrev_to_name($ur->status);
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
		$self->addbadmessage("No merge data for student id: $SID, name: $FN $LN, login: $LOGIN");
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
		return $msg, $r->c('', $self->data_format(1 .. ($#COL)), '<br>', $self->data_format2(@preview_COL))->join(' ');
	} else {
		return $msg;
	}
}

sub data_format {
	my ($self, @data) = @_;
	return map { "COL[$_]" . '&nbsp;' x (3 - length($_)) } @data;    # problems if $_ has length bigger than 4
}

sub data_format2 {
	my ($self, @data) = @_;
	return map { $_ =~ s/\s/&nbsp;/gr } map { sprintf('%-8.8s', $_) } @data;
}

1;
