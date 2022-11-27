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
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SendMail - Entry point for User-specific data editing

=cut

use strict;
use warnings;

use WeBWorK::CGI;
use Email::Address::XS;
use HTML::Entities;
use Email::Stuffer;
use Try::Tiny;
use Data::Dump qw/dump/;
use WeBWorK::Debug;

use Socket qw/unpack_sockaddr_in inet_ntoa/;    # for remote host/port info
use Text::Wrap qw(wrap);
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;
use WeBWorK::Utils qw/processEmailMessage createEmailSenderTransportSMTP/;
use WeBWorK::Utils::FilterRecords qw/filterRecords/;

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

	#############################################################################################
	#	gather directory data
	#############################################################################################
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

	#  get user record
	my $ur = $db->getUser($user);

	# store data
	$self->{defaultFrom}    = $ur->rfc822_mailbox;
	$self->{defaultReply}   = $ur->rfc822_mailbox;
	$self->{defaultSubject} = $self->r->urlpath->arg("courseID") . " notice";

	$self->{rows}    = (defined($r->param('rows')))    ? $r->param('rows')    : $ce->{mail}->{editor_window_rows};
	$self->{columns} = (defined($r->param('columns'))) ? $r->param('columns') : $ce->{mail}->{editor_window_columns};
	$self->{default_msg_file}     = $default_msg_file;
	$self->{old_default_msg_file} = $old_default_msg_file;
	$self->{merge_file}           = $mergefile;
	# an expermiment -- share the scrolling list for preivew and sendTo actions.
	my @classList = (defined($r->param('classList'))) ? $r->param('classList') : ($user);
	$self->{preview_user} = $classList[0] || $user;

	#############################################################################################
	# Gather database data
	#############################################################################################
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

	#############################################################################################
	# Gather list of recipients
	#############################################################################################
	my @send_to;
	my $recipients = $r->param('send_to') // '';
	if ($recipients eq 'all_students') {
		@send_to = map { $_->user_id } @Users;
	} elsif ($recipients eq 'studentID') {
		@send_to = $r->param('classList');
	}

	$self->{ra_send_to} = \@send_to;

	#################################################################
	# Check the validity of the input file name
	#################################################################

	my $input_file = '';
	# Make sure an input message file was submitted and exists.
	# Otherwise use the default message.
	if (defined($openfilename)) {
		if (-e "${emailDirectory}/$openfilename") {
			if (-R "${emailDirectory}/$openfilename") {
				$input_file = $openfilename;
			} else {
				$self->addbadmessage(CGI::p(join(
					"",
					$r->maketext(
						"The file [_1]/[_2] is not readable by the webserver.",
						$emailDirectory, $openfilename
					),
					CGI::br(),
					$r->maketext("Check that it's permissions are set correctly."),
				)));
			}
		} else {
			$input_file = $default_msg_file;
			$self->addbadmessage(CGI::p(join(
				"",
				$r->maketext("The file [_1]/[_2] cannot be found.", $emailDirectory, $openfilename),
				CGI::br(),
				$r->maketext(
					"Check whether it exists and whether the directory [_1] can be read by the webserver.",
					$emailDirectory
				),
				CGI::br(),
				$r->maketext("Using contents of the default message [_1] instead.", $default_msg_file),
			)));
		}
	} else {
		$input_file = $default_msg_file;
	}
	$self->{input_file} = $input_file;

	#################################################################
	# Determine the file name to save message into
	#################################################################
	my $output_file = 'FIXME no output file specified';
	if ($action eq 'saveDefault') {
		$output_file = $default_msg_file;
	} elsif ($action eq 'saveMessage' or $action eq 'saveAs') {
		if (defined($savefilename) and $savefilename) {
			$output_file = $savefilename;
		} else {
			$self->addbadmessage(
				CGI::p($r->maketext("No filename was specified for saving!  The message was not saved.")));
		}
	} elsif (defined($input_file)) {
		$output_file = $input_file;
	}

	#################################################################
	# Sanity check on save file name
	#################################################################

	if ($output_file =~ /^[~.]/ || $output_file =~ /\.\./) {
		$self->addbadmessage(CGI::p(
			$r->maketext(
				"For security reasons, you cannot specify a message file from a directory higher than the email directory (you can't use ../blah/blah for example). Please specify a different file or move the needed file to the email directory"
			)
		));
	}
	unless ($output_file =~ m|\.msg$|) {
		$self->addbadmessage(CGI::p($r->maketext(
			"Invalid file name. The file name \"[_1]\" does not have a \".msg\" extension All email file names must end in the extension \".msg\" choose a file name with a \".msg\" extension. The message was not saved.",
			$output_file
		)));
	}

	$self->{output_file} = $output_file;    # this is ok.  It will be put back in the text input box for re-editing.

	#############################################################################################
	# Determine input source
	#############################################################################################
	#warn "Action = $action";
	my $input_source;
	if ($action) {
		$input_source = (defined($r->param('body')) and $action ne 'openMessage') ? 'form' : 'file';
	} else {
		$input_source = (defined($r->param('body'))) ? 'form' : 'file';
	}

	#############################################################################################
	# Get inputs
	#############################################################################################
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
		$self->addbadmessage(CGI::p($r->maketext('You didn\'t enter any message.'))) unless ($r->param('body') =~ /\S/);
		$r_text = \$body;

	}

	my $remote_host = $r->useragent_ip || "UNKNOWN";

	# store data
	$self->{from}        = $from;
	$self->{replyTo}     = $replyTo;
	$self->{subject}     = $subject;
	$self->{remote_host} = $remote_host;
	$self->{r_text}      = $r_text;

	###################################################################################
	#Determine the appropriate script action from the buttons
	###################################################################################
	#     first time actions
	#          open new file
	#          open default file
	#     choose merge file actions
	#          chose merge button
	#     option actions
	#       'reset rows'

	#     save actions
	#		"save" button
	#		"save as" button
	#		"save as default" button
	#     preview actions
	#		'preview' button
	#     email actions
	#		'entire class'
	#		'selected studentIDs'
	#     error actions (various)

	#############################################################################################
	# if no form is submitted, gather data needed to produce the mail form and return
	#############################################################################################
	my $to            = $r->param('To');
	my $script_action = '';

	if (not $action
		or $action eq 'openMessage'
		or $action eq 'updateSettings')
	{

		return '';
	}

	#############################################################################################
	# If form is submitted deal with filled out forms
	# and various actions resulting from different buttons
	#############################################################################################

	if ($action eq 'saveMessage' or $action eq 'saveAs' or $action eq 'saveDefault') {

		#warn "FIXME Saving files  action = $action  outputFileName=$output_file";

		#################################################################
		# construct message body
		#################################################################
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
		#warn "FIXME from $from | subject $subject |reply $replyTo|msg $temp_body";
		#################################################################
		# overwrite protection
		#################################################################
		if ($action eq 'saveAs' and -e "$emailDirectory/$output_file") {
			$self->addbadmessage(CGI::p($r->maketext(
				"The file [_1]/[_2] already exists and cannot be overwritten. The message was not saved",
				$emailDirectory, $openfilename
			)));
			return;
		}

		#################################################################
		# Back up existing file?
		#################################################################
		if ($action eq 'saveDefault' and -e "$emailDirectory/$default_msg_file") {
			rename("$emailDirectory/$default_msg_file", "$emailDirectory/$old_default_msg_file")
				or die "Can't rename $emailDirectory/$default_msg_file to $emailDirectory/$old_default_msg_file ",
				"Check permissions for webserver on directory $emailDirectory. $!";
			$self->addgoodmessage(CGI::p(
				$r->maketext("Backup file <code>[_1]/[_2]</code> created.", $emailDirectory, $old_default_msg_file)
					. CGI::br()
			));
		}
		#################################################################
		# Save the message
		#################################################################
		$self->saveProblem($temp_body, "${emailDirectory}/$output_file")
			unless ($output_file =~ /^[~.]/ || $output_file =~ /\.\./ || !$output_file =~ m|\.msg$|);
		unless ($self->{submit_message} or not -w "${emailDirectory}/$output_file")
		{    # if there are no errors report success
			$self->addgoodmessage(
				CGI::p($r->maketext("Message saved to file <code>[_1]/[_2]</code>.", $emailDirectory, $output_file))
			);
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
			$self->addbadmessage(CGI::p($r->maketext("No merge data file")));
			$self->addbadmessage(CGI::p($r->maketext("Can't read merge file [_1]. No message sent", $merge_file)));
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
		$r->minion->enqueue(
			send_instructor_email => [ {
				courseName  => $r->urlpath->arg("courseID"),
				recipients  => $self->{ra_send_to},
				subject     => $self->{subject},
				text        => ${ $self->{r_text} // \'' },
				merge_data  => $self->{rh_merge_data},
				from        => $self->{from},
				defaultFrom => $self->{defaultFrom},
				remote_host => $self->{remote_host},
			} ]
		);
	} else {
		$self->addbadmessage(CGI::p($r->maketext("Didn't recognize action")));
	}

	return;
}

sub body {
	my ($self)   = @_;
	my $r        = $self->r;
	my $urlpath  = $r->urlpath;
	my $authz    = $r->authz;
	my $setID    = $urlpath->arg("setID");
	my $response = (defined($self->{response})) ? $self->{response} : '';
	my $user     = $r->param('user');

	# Check permissions
	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		CGI::p("You are not authorized to access instructor tools"))
		unless $authz->hasPermissions($user, "access_instructor_tools");

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		CGI::p("You are not authorized to send mail to students"))
		unless $authz->hasPermissions($user, "send_mail");

	if ($response eq 'preview') {
		return $self->print_preview($setID);
	} elsif ($response eq 'send_email' and $self->{ra_send_to} and @{ $self->{ra_send_to} }) {
		my $message = CGI::i($r->maketext(
			"Email is being sent to [quant,_1,recipient]. You will be notified by email
				when the task is completed.  This may take several minutes if the class is
				large.", scalar(@{ $self->{ra_send_to} })
		));
		$self->addgoodmessage($message);
		$self->{message} .= $message;

		return $self->print_form($setID);
	} else {
		return $self->print_form($setID);
	}
}

sub print_preview {
	my ($self)  = @_;
	my $r       = $self->r;
	my $urlpath = $r->urlpath;
	my $setID   = $urlpath->arg("setID");

	#  get preview user
	my $ur = $r->db->getUser($self->{preview_user});
	die "record for preview user " . $self->{preview_user} . " not found." unless $ur;

	#  get merge file
	my $merge_file    = (defined($self->{merge_file})) ? $self->{merge_file} : 'None';
	my $delimiter     = ',';
	my $rh_merge_data = $self->read_scoring_file("$merge_file", "$delimiter");

	if (($self->{merge_file} // 'None') ne 'None' && !defined $rh_merge_data->{ $ur->student_id }) {
		$self->addbadmessage(CGI::p(
			'No merge data for student id: '
				. $ur->student_id
				. '; name: '
				. $ur->first_name . ' '
				. $ur->last_name
				. '; login: '
				. $ur->user_id
		));
	}

	my ($msg, $preview_header) = processEmailMessage(
		${ $self->{r_text} // \'' },
		$ur,            $self->r->ce->status_abbrev_to_name($ur->status),
		$rh_merge_data, 1
	);

	my $recipients   = join(" ", @{ $self->{ra_send_to} });
	my $errorMessage = defined($self->{submit_message}) ? CGI::i($self->{submit_message}) : '';

	# Format message keeping the preview_header lined up
	$errorMessage = wrap("", "", $errorMessage);
	$msg          = wrap("", "", $msg);

	$msg = join(
		"",
		"To: ",       $ur->email_address, "\n",
		"From: ",     "$self->{from}",    "\n",
		"Reply-To: ", $self->{replyTo},   "\n",
		"Subject: ",  $self->{subject},   "\n",
		# In a real mails we would UTF-8 encode the message
		# and give the Content-Type header, for the preview which
		# is displayed - just add the header, but do NOT use
		# Encode::encode("UTF-8",$msg) as it will be done late.
		"Content-Type: text/plain; charset=UTF-8\n\n",
		$msg,    # will be in HTML output, and gets encoded to UTF-8 later on
		"\n"
	);

	# The content in message is going to be put in HTML.
	# It needs to be encoded to avoid problems with things like
	# <user@domain.com>.
	$msg = encode_entities($msg);

	return CGI::div(
		{ class => 'mb-3', dir => 'ltr' },
		CGI::pre($errorMessage)
			. CGI::h2({ class => 'fs-3' }, $r->maketext("This sample mail would be sent to [_1]", $ur->email_address))
			. CGI::pre($msg)
			. CGI::h2({ class => 'fs-3' }, $r->maketext('Merge file data:'))
			. CGI::pre($errorMessage)
			. CGI::pre(CGI::p($preview_header))

		)
		. CGI::h2({ class => 'fs-3' }, $r->maketext('Emails to be sent to the following:'))
		. $recipients
		. CGI::div({ class => 'alert alert-info p-1 mt-3' },
			$r->maketext('Use browser back button to return from preview mode.'));
}

sub print_form {
	my ($self)     = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $authz      = $r->authz;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $courseName = $urlpath->arg("courseID");
	my $setID      = $urlpath->arg("setID");
	my $user       = $r->param('user');

	my $root         = $ce->{webworkURLs}->{root};
	my $sendMailPage = $urlpath->newFromModule($urlpath->module, $r, courseID => $courseName);
	my $sendMailURL  = $self->systemLink($sendMailPage, authen => 0);

	return CGI::em("You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");

	my $userTemplate            = $db->newUser;
	my $permissionLevelTemplate = $db->newPermissionLevel;

	##############################################################################################################

	my $from       = $self->{from};
	my $subject    = $self->{subject};
	my $replyTo    = $self->{replyTo};
	my $rows       = $self->{rows};
	my $text       = defined($self->{r_text}) ? ${ $self->{r_text} } : 'FIXME no text was produced by initialization!!';
	my $input_file = $self->{input_file};
	my $output_file        = $self->{output_file};
	my @sorted_messages    = $self->get_message_file_names;
	my @sorted_merge_files = $self->get_merge_file_names;
	my $merge_file         = (defined($self->{merge_file})) ? $self->{merge_file} : 'None';
	my $delimiter          = ',';
	my $rh_merge_data      = $self->read_scoring_file("$merge_file", "$delimiter");
	my @merge_keys         = keys %$rh_merge_data;
	my $preview_user       = $self->{preview_user};
	my $preview_record     = $db->getUser($preview_user);                                     # checked
	die "record for preview user " . $self->{preview_user} . " not found." unless $preview_record;

	print CGI::start_form(
		{ id => "send-mail-form", name => "send-mail-form", method => "post", action => $sendMailURL });
	print $self->hidden_authen_fields();

	# Email settings
	print CGI::div(
		{ class => 'card mb-3' },
		CGI::div(
			{ class => 'card-body p-2' },
			CGI::div(
				{ class => 'row' },
				CGI::div(
					{ class => 'col-md-6 mb-2' },
					CGI::div(
						{ class => 'input-group input-group-sm mb-2' },
						CGI::label(
							{ for => 'openfilename', class => 'input-group-text' },
							CGI::strong($r->maketext('Message file:'))
						),
						CGI::span({ class => 'input-group-text' }, $input_file)
					),
					CGI::div(
						{ class => 'input-group input-group-sm mb-2' },
						CGI::submit({
							name  => 'openMessage',
							value => $r->maketext('Open'),
							class => 'btn btn-secondary'
						}),
						CGI::popup_menu({
							name    => 'openfilename',
							id      => 'openfilename',
							values  => \@sorted_messages,
							default => $input_file,
							class   => 'form-select form-select-sm'
						})
					),
					CGI::div(
						{ class => 'input-group input-group-sm mb-2' },
						CGI::span({ class => 'input-group-text' }, CGI::strong($r->maketext('Save file to:'))),
						CGI::span({ class => 'input-group-text' }, $output_file)
					),
					CGI::div(
						{ class => 'input-group input-group-sm mb-2' },
						CGI::label(
							{ for => 'merge_file', class => 'input-group-text' },
							CGI::strong($r->maketext('Merge file:'))
						),
						CGI::span({ class => 'input-group-text' }, $merge_file)
					),
					CGI::popup_menu({
						name    => 'merge_file',
						id      => 'merge_file',
						values  => \@sorted_merge_files,
						default => $merge_file,
						class   => 'form-select form-select-sm mb-2'
					}),
					CGI::div(
						{ class => 'row mb-1' },
						CGI::label(
							{ for => 'from', class => 'col-sm-3 col-form-label col-form-label-sm' },
							$r->maketext('From:')
						),
						CGI::div(
							{ class => 'col-sm-9' },
							CGI::textfield({
								name  => 'from',
								id    => 'from',
								value => $from,
								class => 'form-control form-control-sm'
							})
						)
					),
					CGI::div(
						{ class => 'row mb-1' },
						CGI::label(
							{ for => 'replyTo', class => 'col-sm-3 col-form-label col-form-label-sm' },
							$r->maketext('Reply-To:')
						),
						CGI::div(
							{ class => 'col-sm-9' },
							CGI::textfield({
								name  => 'replyTo',
								id    => 'replyTo',
								value => $replyTo,
								class => 'form-control form-control-sm'
							})
						)
					),
					CGI::div(
						{ class => 'row mb-2' },
						CGI::label(
							{ for => 'subject', class => 'col-sm-3 col-form-label col-form-label-sm' },
							$r->maketext('Subject: ')
						),
						CGI::div(
							{ class => 'col-sm-9' },
							CGI::textfield({
								name  => 'subject',
								id    => 'subject',
								value => $subject,
								class => 'form-control form-control-sm'
							})
						),
					),
					CGI::div(
						{ class => 'row mb-2' },
						CGI::label(
							{ for => 'rows', class => 'col-3 col-form-label col-form-label-sm' },
							$r->maketext('Editor rows:')
						),
						CGI::div(
							{ class => 'col-9' },
							CGI::textfield({
								name  => 'rows',
								id    => 'rows',
								size  => 3,
								value => $rows,
								class => 'form-control form-control-sm d-inline w-auto'
							})
						),
					),
					CGI::submit({
						name  => 'updateSettings',
						value => $r->maketext('Update settings and refresh page'),
						class => 'btn btn-secondary btn-sm'
					}),
				),
				CGI::div(
					{ class => 'col-md-6 mb-2' },
					CGI::div(
						{ class => 'form-check' },
						CGI::input({
							name  => 'send_to',
							id    => 'send_to_all',
							value => 'all_students',
							type  => 'radio',
							class => 'form-check-input',
							(($r->param('send_to') // '') eq 'all_students') ? (checked => undef) : ()
						}),
						CGI::label(
							{ for => 'send_to_all', class => 'form-check-label' },
							$r->maketext('Send to all students')
						)
					),
					CGI::div(
						{ class => 'form-check' },
						CGI::input({
							name  => 'send_to',
							id    => 'send_to_selected',
							value => 'studentID',
							type  => 'radio',
							class => 'form-check-input',
							(!$r->param('send_to') || $r->param('send_to') eq 'studentID') ? (checked => undef) : ()
						}),
						CGI::label(
							{ for => 'send_to_selected', class => 'form-check-label' },
							$r->maketext('Send to the students selected below')
						)
					),
					CGI::div(
						{ class => 'mb-2' },
						scrollingRecordList(
							{
								name                => 'classList',
								request             => $r,
								default_sort        => 'lnfn',
								default_format      => 'lnfn_uid',
								default_filters     => ['all'],
								refresh_button_name => $r->maketext('Update settings and refresh page'),
								attrs               => {
									size     => 5,
									multiple => 1
								}
							},
							@{ $self->{ra_user_records} }
						)
					),
					CGI::div(
						{ class => 'input-group input-group-sm mb-2' },
						CGI::submit({
							name  => 'previewMessage',
							value => $r->maketext('Preview Message'),
							class => 'btn btn-secondary btn-sm'
						}),
						CGI::span(
							{ class => 'input-group-text', style => 'white-space:pre;' },
							CGI::strong($r->maketext('for')) . ' '
								. $preview_record->last_name . ', '
								. $preview_record->first_name . ' ('
								. $preview_record->user_id . ')'
						)
					)
				)
			),
			# Insert a toast containing a list of available macros.
			CGI::div(
				{ class => 'd-flex justify-content-center' },
				'<button id="insertable-macros-btn" class="btn btn-secondary btn-sm" type="button">'
					. $r->maketext('List of insertable macros')
					. '</button>'
			),
			CGI::div(
				{ class => 'position-fixed top-0 end-0 p-3', style => 'z-index: 11' },
				CGI::div(
					{
						id          => 'insertable-macros',
						class       => 'toast bg-white',
						role        => 'alert',
						aria_live   => 'polite',
						aria_atomic => 'true'
					},
					CGI::div(
						{ class => 'toast-header' },
						CGI::strong({ class => 'me-auto' }, $r->maketext('List of insertable macros')),
						'<button type="button" class="btn-close" data-bs-dismiss="toast" aria-label="Close"></button>'
					),
					CGI::div(
						{ class => 'toast-body' },
						CGI::table(
							{ class => 'table table-bordered table-sm align-middle w-auto mb-0 mx-auto' },
							CGI::thead(CGI::Tr(CGI::th([ $r->maketext('Macro'), $r->maketext('Value') ]))),
							CGI::tbody(
								CGI::Tr(CGI::td([ '$SID',        $r->maketext('Student ID') ])),
								CGI::Tr(CGI::td([ '$FN',         $r->maketext('First name') ])),
								CGI::Tr(CGI::td([ '$LN',         $r->maketext('Last name') ])),
								CGI::Tr(CGI::td([ '$SECTION',    $r->maketext('Section') ])),
								CGI::Tr(CGI::td([ '$RECITATION', $r->maketext('Recitation') ])),
								CGI::Tr(CGI::td([ '$STATUS',     $r->maketext('Enrolled, Drop, etc.') ])),
								CGI::Tr(CGI::td([ '$EMAIL',      $r->maketext('Email address') ])),
								CGI::Tr(CGI::td([ '$LOGIN',      $r->maketext('Login') ])),
								CGI::Tr(CGI::td([ '$COL[n]',     $r->maketext('nth colum of merge file') ])),
								CGI::Tr(CGI::td([ '$COL[-1]',    $r->maketext('Last column of merge file') ]))
							)
						)
					)
				)
			)
		)
	);

	# Merge file fragment and message text area field
	my @merge_data;
	eval { @merge_data = @{ $rh_merge_data->{ $db->getUser($preview_user)->student_id } }; };    # checked
	if ($@ and $merge_file ne 'None') {
		print CGI::div({ class => 'mb-3' }, "No merge data for $preview_user in merge file: &lt;$merge_file&gt;");
	} elsif (@merge_data) {
		print CGI::pre("", data_format(1 .. ($#merge_data + 1)), "<br>", data_format2(@merge_data));
	}

	# Create a textbox with the subject and a textarea with the message.
	# Print the actual body of message.
	print CGI::div({ class => 'alert alert-info p-1 my-2' }, $self->{message}) if defined($self->{message});
	print CGI::div(
		{ class => 'mb-2' },
		CGI::label(
			{ 'for' => "email-body", class => 'form-label' },
			$r->maketext("Email Body:") . CGI::span({ class => "required-field" }, '*')
		),
		CGI::textarea({
			id       => "email-body",
			name     => 'body',
			default  => $text,
			rows     => $rows,
			override => 1,
			class    => 'form-control'
		})
	);

	# Action buttons
	print CGI::div(
		{ class => 'card' },
		CGI::div(
			{ class => 'card-body p-1 d-md-flex flex-wrap justify-content-evenly' },
			CGI::div(
				{ class => 'input-group input-group-sm w-auto m-1' },
				CGI::submit({
					name  => 'sendEmail',
					id    => "sendEmail_id",
					value => $r->maketext('Send Email'),
					class => 'btn btn-secondary btn-sm d-inline w-auto'
				})
			),
			CGI::div(
				{ class => 'input-group input-group-sm w-auto m-1' },
				CGI::submit({
					name  => 'saveMessage',
					value => $r->maketext('Save'),
					class => 'btn btn-secondary btn-sm'
				}),
				CGI::span({ class => 'input-group-text' }, $r->maketext('to') . ' ' . $output_file)
			),
			CGI::div(
				{ class => 'input-group input-group-sm w-auto m-1' },
				CGI::submit({
					name  => 'saveAs',
					id    => 'saveAs',
					value => $r->maketext('Save as') . ":",
					class => 'btn btn-secondary btn-sm'
				}),
				CGI::textfield({
					name            => 'savefilename',
					size            => 20,
					value           => "$output_file",
					class           => 'form-control form-control-sm',
					aria_labelledby => 'saveAs'
				})
			),
			CGI::div(
				{ class => 'input-group input-group-sm w-auto m-1' },
				CGI::submit({
					name  => 'saveDefault',
					value => $r->maketext('Save as Default'),
					class => 'btn btn-secondary btn-sm'
				})
			)
		)
	);

	print CGI::end_form();
	return '';
}

##############################################################################
# Utility methods
##############################################################################

sub saveProblem {
	my ($self, $body, $probFileName) = @_;
	open(my $PROBLEM, ">:encoding(UTF-8)", $probFileName)
		|| $self->addbadmessage(
			CGI::p(
				"Could not open $probFileName for writing.
						Check that the  permissions for this problem are 660 (-rw-rw----)"
			)
		);
	print $PROBLEM $body if -w $probFileName;
	close $PROBLEM;
	chmod 0660, "$probFileName"
		|| $self->addbadmessage(CGI::p("CAN'T CHANGE PERMISSIONS ON FILE $probFileName"));
	return;
}

sub read_input_file {
	my $self     = shift;
	my $filePath = shift;
	my $r        = $self->r;
	my ($text, @text);
	my $header = '';
	my ($subject, $from, $replyTo);
	if (-e "$filePath" and -r "$filePath") {
		open my $FILE, "<:encoding(UTF-8)", $filePath
			or do { $self->addbadmessage(CGI::p($r->maketext("Can't open [_1]", $filePath))); return };
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

sub data_format {
	my @data = @_;
	return map { "COL[$_]" . '&nbsp;' x (3 - length($_)); } @data;    # problems if $_ has length bigger than 4
}

sub data_format2 {
	my @data = @_;
	return map { $_ =~ s/\s/&nbsp;/gr } map { sprintf('%-8.8s', $_); } @data;
}

1;
