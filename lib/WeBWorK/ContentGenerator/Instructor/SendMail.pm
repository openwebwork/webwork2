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

package WeBWorK::ContentGenerator::Instructor::SendMail;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SendMail - Entry point for User-specific data editing

=cut

use Email::Address::XS;
use Mojo::File;
use Text::Wrap qw(wrap);

use WeBWorK::Utils qw(processEmailMessage);

sub initialize ($c) {
	my $db    = $c->db;
	my $ce    = $c->ce;
	my $authz = $c->authz;
	my $user  = $c->param('user');

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	return unless $authz->hasPermissions($user, "send_mail");

	# Gather directory data
	my $emailDirectory    = $ce->{courseDirs}{email};
	my $scoringDirectory  = $ce->{courseDirs}{scoring};
	my $templateDirectory = $ce->{courseDirs}{templates};

	my $openfilename = $c->param('openfilename');
	my $savefilename = $c->param('savefilename');
	my $mergefile    = $c->param('merge_file');

	#if mergefile or openfilename haven't been defined via parameter
	# check the database to see if there is a file we should use.
	# if they have been defined via parameter then we should update the db

	if ($openfilename) {
		$db->setSettingValue("${user}_openfile", $openfilename);
	} elsif (defined $openfilename) {
		$db->deleteSetting("${user}_openfile");
	} elsif ($db->settingExists("${user}_openfile")) {
		$openfilename = $db->getSettingValue("${user}_openfile");
	}

	if ($mergefile) {
		$db->setSettingValue("${user}_mergefile", $mergefile);
	} elsif (defined $mergefile) {
		$db->deleteSetting("${user}_mergefile");
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
	} elsif ($c->param('openMessage')) {
		$action = 'openMessage';
	} elsif ($c->param('previewMessage')) {
		$action = 'previewMessage';
	}

	# Get user record
	my $ur = $db->getUser($user);

	# Store data
	$c->{defaultPreviewUser} = $ur;
	$c->{from}               = $ur->rfc822_mailbox;
	$c->{from_name}          = $ur->full_name;
	$c->{defaultSubject}     = $c->stash('courseID') . ' notice';
	$c->{merge_file}         = $mergefile // '';

	my @classList = $c->param('selected_users') // ($user);
	$c->{preview_user} = $c->db->getUser($classList[0] || $user);

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
		@send_to = $c->param('selected_users');
	}

	$c->{ra_send_to} = \@send_to;

	# Check the validity of the input file name
	my $input_file = '';
	# Make sure an input message file was submitted and exists.
	if ($openfilename) {
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
			$c->addbadmessage($c->maketext(
				'The file [_1] cannot be found. '
					. 'Check whether it exists and whether the directory [_2] can be read by the webserver. ',
				"$emailDirectory/$openfilename",
				$emailDirectory
			));
		}
	}
	$c->{input_file} = $input_file;

	# Determine the file name to save message into
	my $output_file = '';
	$savefilename = $input_file if $action eq 'saveMessage';
	if ($action eq 'saveMessage' or $action eq 'saveAs') {
		if ($savefilename) {
			$output_file = $savefilename;
		} else {
			$c->addbadmessage($c->maketext('No filename was specified for saving!  The message was not saved.'));
		}
	} else {
		$output_file = $input_file // '';
	}

	# Sanity check on save file name
	if ($output_file =~ /^[~.]/ || $output_file =~ /\.\./) {
		$c->addbadmessage($c->maketext(
			'For security reasons, you cannot specify a message file from a directory higher than the '
				. q{email directory (you can't use ../blah/blah for example). }
				. 'Please specify a different file or move the needed file to the email directory.'
		));
	}
	if ($output_file && $output_file !~ m|\.msg$|) {
		$c->addbadmessage($c->maketext(
			'Invalid file name "[_1]". All email file names must end with the ".msg" extension.  '
				. 'Choose a file name with the ".msg" extension. The message was not saved.',
			$output_file
		));
	}

	$c->{output_file} = $output_file;
	$c->param('savefilename', $output_file) if ($c->param('savefilename') && $output_file);

	# Determine input source
	my $input_source;
	if ($action) {
		$input_source = (defined($c->param('body')) and $action ne 'openMessage') ? 'form' : 'file';
	} else {
		$input_source = (defined($c->param('body'))) ? 'form' : 'file';
	}

	# Get inputs
	my ($r_text, $subject);
	if ($input_source eq 'file') {
		if ($input_file) {
			($subject, $r_text) = $c->read_input_file("$emailDirectory/$input_file");
		} else {
			$subject = $c->{defaultSubject};

			# If action is openMessage and no file was found, then 'None' was selected.
			# In this case empty the message body and set the saved file name to default.msg.
			if ($action eq 'openMessage') {
				$c->param('body',         '')            if $c->param('body');
				$c->param('savefilename', 'default.msg') if $c->param('savefilename');
			}
		}
		$c->param('subject', $subject) if $subject;
		$c->param('body',    $$r_text) if $r_text;
	} elsif ($input_source eq 'form') {
		# read info from the form
		# bail if there is no message body

		$subject = $c->param('subject');
		my $body = $c->param('body');
		# Sanity check: body must contain non-white space when previewing message.
		$c->addbadmessage($c->maketext('You didn\'t enter any message.'))
			unless ($action ne 'previewMessage' || $c->param('body') =~ /\S/);
		$r_text = \$body;
	}

	my $remote_host = $c->tx->remote_address || "UNKNOWN";

	# Store data
	$c->{subject}     = $subject;
	$c->{remote_host} = $remote_host;
	$c->{r_text}      = $r_text;

	#Determine the appropriate script action from the buttons
	#     first time actions
	#          open new file
	#     save actions
	#       "save" button
	#       "save as" button
	#     preview actions
	#       'preview' button
	#     email actions
	#       'entire class'
	#       'selected studentIDs'
	#     error actions (various)

	# if no form is submitted, gather data needed to produce the mail form and return
	my $to = $c->param('To');

	return '' if (not $action or $action eq 'openMessage');

	# If form is submitted deal with filled out forms
	# and various actions resulting from different buttons

	if ($action eq 'saveMessage' or $action eq 'saveAs') {
		# Check that an output file was specified and protect against overwriting an existing file.
		if ($action eq 'saveAs') {
			if (!$output_file) {
				# A message has been already set if no output filename was specified.  So just return here in that case.
				return;
			} elsif (-e "$emailDirectory/$output_file") {
				$c->addbadmessage($c->maketext(
					'The file [_1] already exists and cannot be overwritten. The message was not saved.',
					"$emailDirectory/$output_file"
				));
				return;
			}
		}

		# construct message body
		my $temp_body = ${$r_text};
		$temp_body =~ s/\r\n/\n/g;
		$temp_body = join(
			"\n",
			"From: $c->{from}",
			"Subject: $subject",
			"Content-Type: text/plain; charset=UTF-8",
			"Message:",
			# Do NOT encode to UTF-8 here.
			$temp_body
		);

		# Save the message
		$c->saveMessageFile($temp_body, "${emailDirectory}/$output_file")
			unless ($output_file =~ /^[~.]/ || $output_file =~ /\.\./ || $output_file !~ m|\.msg$|);
		if (-w "${emailDirectory}/$output_file") {    # if there are no errors report success
			$c->addgoodmessage($c->maketext('Message saved to file [_1].', "$emailDirectory/$output_file"));
			$c->{input_file} = $output_file;
			$db->setSettingValue("${user}_openfile", $output_file);
		}

	} elsif ($action eq 'previewMessage') {
		$c->{response} = 'preview';

	} elsif ($action eq 'sendEmail') {
		# Don't try to send an empty message.
		unless (${ $c->{r_text} } =~ /\S/) {
			$c->addbadmessage($c->maketext('Email body is empty. No message sent. '));
			return;
		}

		# verify format of From address (one valid rfc2822/rfc5322 address)
		my @parsed_from_addrs = Email::Address::XS->parse($c->{from});
		unless (@parsed_from_addrs == 1) {
			$c->addbadmessage($c->maketext("From field must contain one valid email address."));
			return;
		}

		# Check that recipients have been selected.
		unless (@{ $c->{ra_send_to} }) {
			$c->addbadmessage(
				$c->maketext('No recipients selected. Please select one or more recipients from the list below.'));
			return;
		}

		#  get merge file
		my $merge_file    = $c->{merge_file};
		my $rh_merge_data = $c->read_scoring_file($merge_file);
		unless (ref($rh_merge_data)) {
			$c->addbadmessage($c->maketext("No merge data file"));
			$c->addbadmessage($c->maketext("Can't read merge file [_1]. No message sent", $merge_file));
			return;
		}
		$c->{rh_merge_data} = $rh_merge_data;

		# we don't set the response until we're sure that email can be sent
		$c->{response} = 'send_email';

		# The emails are actually sent in the job queue, since it could take a long time.
		# Note that the instructor can check the job manager page to see the status of the job.
		$c->minion->enqueue(
			send_instructor_email => [ {
				recipients  => $c->{ra_send_to},
				subject     => $c->{subject},
				text        => ${ $c->{r_text} // \'' },
				merge_data  => $c->{rh_merge_data},
				from        => $c->{from},
				from_name   => $c->{from_name},
				remote_host => $c->{remote_host},
			} ],
			{ notes => { courseID => $c->stash('courseID') } }
		);
	} else {
		$c->addbadmessage($c->maketext(q{Didn't recognize action}));
	}

	return;
}

sub print_preview ($c) {
	die "record for preview user " . $c->{preview_user} . " not found." unless $c->{preview_user};

	# Get merge file
	my $merge_file    = $c->{merge_file};
	my $rh_merge_data = $c->read_scoring_file($merge_file);

	if ($merge_file && !defined $rh_merge_data->{ $c->{preview_user}->student_id }) {
		$c->addbadmessage('No merge data for student id: '
				. $c->{preview_user}->student_id
				. '; name: '
				. $c->{preview_user}->first_name . ' '
				. $c->{preview_user}->last_name
				. '; login: '
				. $c->{preview_user}->user_id);
	}

	my ($msg, $preview_header) = processEmailMessage(
		${ $c->{r_text} // \'' },
		$c->{preview_user}, $c->ce->status_abbrev_to_name($c->{preview_user}->status),
		$rh_merge_data,     1
	);

	# The content in message is going to be displayed in HTML.
	# It needs to have html entities escaped to avoid problems with things like <user@domain.com>.
	# Note that this escaping is done in the Mojolicious template automatically.
	$msg = join(
		"",
		"To: ",      $c->{preview_user}->email_address, "\n",
		"From: ",    $c->{from},                        "\n",
		"Subject: ", $c->{subject},                     "\n",
		# In a real mails we would UTF-8 encode the message and give the Content-Type header. For the preview which is
		# displayed as html, just add the header, but do NOT use Encode::encode("UTF-8",$msg).
		"Content-Type: text/plain; charset=UTF-8\n\n",
		wrap('', '', $msg),
		"\n"
	);

	# Associate usernames to student ids to test if merge data is found.
	my %student_ids = map { $_->user_id => $_->student_id } @{ $c->{ra_user_records} };

	return $c->include(
		'ContentGenerator/Instructor/SendMail/preview',
		preview_header => $preview_header,
		ur             => $c->{preview_user},
		msg            => $msg,
		merge_data     => $rh_merge_data,
		student_ids    => \%student_ids,
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
	my $subject;

	open my $FILE, "<:encoding(UTF-8)", $filePath
		or do { $c->addbadmessage($c->maketext(q{Can't open [_1]}, $filePath)); return };
	while ($header !~ s/Message:\s*$//m and not eof($FILE)) {
		$header .= <$FILE>;
	}
	$text = join('', <$FILE>);
	close $FILE;

	$text =~ s/^\s*//;    # remove initial white space if any.

	$header =~ /^Subject:\s(.*)$/m;
	$subject = $1 || $c->{defaultSubject};

	return ($subject, \$text);
}

sub get_message_file_names ($c) {
	return @{ Mojo::File->new($c->ce->{courseDirs}{email})->list->grep(qr/\.msg$/)->map('basename') };
}

sub get_merge_file_names ($c) {
	return @{ Mojo::File->new($c->ce->{courseDirs}{scoring})->list->grep(qr/\.csv$/)->map('basename') };
}

sub getRecord ($c, $line, $delimiter = ',') {
	# Takes a delimited line as a parameter and returns an
	# array.  Note that all white space is removed.  If the
	# last field is empty, the last element of the returned
	# array is also empty (unlike what the perl split command
	# would return).  E.G. @lineArray=&getRecord(\$delimitedLine).

	my (@lineArray);
	$line .= "${delimiter}___";                         # add final field which must be non-empty
	@lineArray = split(/\s*${delimiter}\s*/, $line);    # split line into fields
	$lineArray[0] =~ s/^\s*//;                          # remove white space from first element
	pop @lineArray;                                     # remove the last artificial field
	return @lineArray;
}

sub data_format ($c, @data) {
	return map { "COL[$_]" . '&nbsp;' x (3 - length($_)) } @data;    # problems if $_ has length bigger than 4
}

sub data_format2 ($c, @data) {
	return map { $_ =~ s/\s/&nbsp;/gr } map { sprintf('%-8.7s', $_) } @data;
}

1;
