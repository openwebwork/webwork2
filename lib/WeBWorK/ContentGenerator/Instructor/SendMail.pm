################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/SendMail.pm,v 1.64 2007/08/13 22:59:55 sh002i Exp $
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
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use Email::Address;
use HTML::Entities;
use Mail::Sender;
use Socket qw/unpack_sockaddr_in inet_ntoa/; # for remote host/port info
use Text::Wrap qw(wrap);
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;
use WeBWorK::Utils qw/readFile readDirectory/;
use WeBWorK::Utils::FilterRecords qw/filterRecords/;

use mod_perl;
use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );


sub initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $ce     = $r->ce;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	my @selected_filters;
	if (defined ($r->param('classList!filter'))){ @selected_filters = $r->param('classList!filter');}
	else {@selected_filters = ("all");}


	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	return unless $authz->hasPermissions($user, "send_mail");

	#############################################################################################
	#	gather directory data
	#############################################################################################	
	my $emailDirectory    =    $ce->{courseDirs}->{email};
	my $scoringDirectory  =    $ce->{courseDirs}->{scoring};
	my $templateDirectory =    $ce->{courseDirs}->{templates};
	
	my $openfilename      =	   $r->param('openfilename');
	my $savefilename      =	   $r->param('savefilename');
	
	#FIXME  get these values from global course environment (see subroutines as well)
	my $default_msg_file       =    'default.msg';  
	my $old_default_msg_file   =    'old_default.msg';
	
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
	my $ur = $self->{db}->getUser($user);

	# store data
	$self->{defaultFrom}            =   $ur->rfc822_mailbox;
	$self->{defaultReply}           =   $ur->rfc822_mailbox;
	$self->{defaultSubject}         =   $self->r->urlpath->arg("courseID") . " notice";

	$self->{rows}                   =   (defined($r->param('rows'))) ? $r->param('rows') : $ce->{mail}->{editor_window_rows};
	$self->{columns}                =   (defined($r->param('columns'))) ? $r->param('columns') : $ce->{mail}->{editor_window_columns};
	$self->{default_msg_file}	    =   $default_msg_file;
	$self->{old_default_msg_file}   =   $old_default_msg_file;
	$self->{merge_file}             =   (defined($r->param('merge_file'  )))    ? $r->param('merge_file')   : 'None';
	#$self->{preview_user}           =   (defined($r->param('preview_user')))    ? $r->param('preview_user') : $user;
	# an expermiment -- share the scrolling list for preivew and sendTo actions.
	my @classList                   =   (defined($r->param('classList')))    ? $r->param('classList') : ($user);
	$self->{preview_user}           =   $classList[0] || $user;
	
	#############################################################################################
	#	gather database data
	#############################################################################################	
	# FIXME  this might be better done in body? We don't always need all of this data. or do we?
	# DBFIXME shouldn't need ID list
	# DBFIXME do filtering in database
	my @users =  $db->listUsers;
	my @Users = $db->getUsers(@users);
	# filter out users who don't get included in email (fixes bug #938)
	@Users = grep { $ce->status_abbrev_has_behavior($_->status, "include_in_email") } @Users;
	my @user_records = ();

	## Mark's code to prefilter userlist
	# DBFIXME more filtering that we can do in the database

	
	my (@viewable_sections,@viewable_recitations);
	
	if (defined $ce->{viewable_sections}->{$user})
		{@viewable_sections = @{$ce->{viewable_sections}->{$user}};}
	if (defined $ce->{viewable_recitations}->{$user})
		{@viewable_recitations = @{$ce->{viewable_recitations}->{$user}};}

	if (@viewable_sections or @viewable_recitations){
		foreach my $student (@Users){
			my $keep = 0;
			foreach my $sec (@viewable_sections){
				if ($student->section() eq $sec){$keep = 1;}
			}
			foreach my $rec (@viewable_recitations){
				if ($student->recitation() eq $rec){$keep = 1;}
			}
			if ($keep) {push @user_records, $student;}
		}
	}
	else {@user_records = @Users;}

	## End Mark's code
	

	# replace the user names by a sorted version.
	@users                         =  map {$_->user_id} @user_records;
	# store data
	$self->{ra_users}              =   \@users;
	$self->{ra_user_records}       =   \@user_records;

	#############################################################################################
	#	gather list of recipients
	#############################################################################################	
	my @send_to                    =   ();	
	#FIXME  this (radio) is a lousy name
	my $recipients                 = $r->param('radio');
	if (defined($recipients) and $recipients eq 'all_students') {  #only active students #FIXME status check??
		
		## Add code so that only people who pass the current filters are added to our list of recipients.		
		#	@user_records = filterRecords({filter=\@selected_filters},@user_records);
		#  I wasn't able to make this work
		#  I edited the selection button to make that clear.
		#

		foreach my $ur (@user_records) {
			push(@send_to,$ur->user_id)
				if $ce->status_abbrev_has_behavior($ur->status, "include_in_email")
					and not $ur->user_id =~ /practice/;
		}
	} elsif (defined($recipients) and $recipients eq 'studentID' ) {
		@send_to                   = $r->param('classList');
	} else {
		# no recipients have been defined -- probably the first time on the page
	}	
	$self->{ra_send_to}               = \@send_to;
	#################################################################
	# Check the validity of the input file name
	#################################################################
	my $input_file = '';
	#make sure an input message file was submitted and exists
	#else use the default message		
	if ( defined($openfilename) ) {
		if ( -e "${emailDirectory}/$openfilename") {
			if ( -R "${emailDirectory}/$openfilename") {
				$input_file = $openfilename;
			} else {
				$self->addbadmessage(CGI::p(join("",
					"The file ${emailDirectory}/$openfilename is not readable by the webserver.",CGI::br(),
					"Check that it's permissions are set correctly.",
				)));
			}
		} else {
			$input_file = $default_msg_file;
			$self->addbadmessage(CGI::p(join("",
				  "The file ${emailDirectory}/$openfilename cannot be found.",CGI::br(),
				  "Check whether it exists and whether the directory $emailDirectory can be read by the webserver.",CGI::br(),
				  "Using contents of the default message $default_msg_file instead.",
			)));
		}
	} else {
		$input_file     = $default_msg_file;
	}
	$self->{input_file} =$input_file;

	#################################################################
	# Determine the file name to save message into
	#################################################################
	my $output_file      = 'FIXME no output file specified';	
	if ($action eq 'saveDefault') {
		$output_file  = $default_msg_file;
	} elsif ($action eq 'saveMessage' or $action eq 'saveAs') {
		if (defined($savefilename) and $savefilename ) {
			$output_file  = $savefilename;
		} else {
			$self->addbadmessage(CGI::p("No filename was specified for saving!  The message was not saved."));
		}
	} elsif ( defined($input_file) ) {
		$output_file  = $input_file;
	}

	#################################################################
	# Sanity check on save file name
	#################################################################

	if ($output_file =~ /^[~.]/ || $output_file =~ /\.\./) {
		$self->addbadmessage(CGI::p("For security reasons, you cannot specify a message file from a directory", 
						"higher than the email directory (you can't use ../blah/blah for example). ", 
						"Please specify a different file or move the needed file to the email directory",));
	} 
	unless ($output_file =~ m|\.msg$| ) {
		$self->addbadmessage(CGI::p("Invalid file name.", 
		                        "The file name \"$output_file\" does not have a \".msg\" extension",
								"All email file names must end in the extension \".msg\"",
								"choose a file name with a \".msg\" extension.",
								"The message was not saved.",));
	}

	$self->{output_file} = $output_file;  # this is ok.  It will be put back in the text input box for re-editing.


	#############################################################################################
	# Determine input source
	#############################################################################################
	#warn "Action = $action";
	my $input_source;
	if ($action){	
		$input_source =  ( defined( $r->param('body') ) and $action ne 'openMessage' ) ? 'form' : 'file';}
	else { $input_source = ( defined($r->param('body')) ) ? 'form' : 'file';}

	#############################################################################################
	# Get inputs
	#############################################################################################
	my($from, $replyTo, $r_text, $subject);
	if ($input_source eq 'file') {

		($from, $replyTo,$subject,$r_text) = $self->read_input_file("$emailDirectory/$input_file");


	} elsif ($input_source eq 'form') {
		# read info from the form
		# bail if there is no message body
		
		$from              =    $r->param('from');
		$replyTo           =    $r->param('replyTo');
		$subject           =    $r->param('subject');
		my $body           =    $r->param('body');
		# Sanity check: body must contain non-white space
		$self->addbadmessage(CGI::p('You didn\'t enter any message.')) unless ($r->param('body') =~ /\S/);
		$r_text               =    \$body;
		
	}
	
	my $remote_host;
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
		$APACHE24 = version->parse($version) >= version->parse('2.4');
	    }
	}
	# If its apache 2.4 then the API has changed
	if ($APACHE24) {
	    $remote_host = $r->connection->client_addr->ip_get || "UNKNOWN";
	} elsif (MP2) {
	    $remote_host = $r->connection->remote_addr->ip_get || "UNKNOWN";
	} else {
		(undef, $remote_host) = unpack_sockaddr_in($r->connection->remote_addr);
		$remote_host = defined $remote_host ? inet_ntoa($remote_host) : "UNKNOWN";
	}

	# store data
	$self->{from}                   =    $from;
	$self->{replyTo}                =    $replyTo;
	$self->{subject}                =    $subject;
	$self->{remote_host}            =    $remote_host;
	$self->{r_text}                 =    $r_text;



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
	my $to                =    $r->param('To');
	my $script_action     = '';
	
	
	if(not $action or $action eq 'openMessage'  
	   or $action eq 'updateSettings'){  

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
		my $temp_body = ${ $r_text };
		$temp_body =~ s/\r\n/\n/g;
		$temp_body = join("",
				   "From: $from \nReply-To: $replyTo\n" ,
				   "Subject: $subject\n" ,
				   "Message: \n    $temp_body");
		#warn "FIXME from $from | subject $subject |reply $replyTo|msg $temp_body";
		#################################################################
		# overwrite protection
		#################################################################
		if ($action eq 'saveAs' and -e "$emailDirectory/$output_file") {
			$self->addbadmessage(CGI::p("The file $emailDirectory/$output_file already exists and cannot be overwritten",
			                         "The message was not saved"));
			return;
		}
 
		#################################################################
	    # Back up existing file?
	    #################################################################
	    if ($action eq 'saveDefault' and -e "$emailDirectory/$default_msg_file") {
	    	rename("$emailDirectory/$default_msg_file","$emailDirectory/$old_default_msg_file") or 
	    	       die "Can't rename $emailDirectory/$default_msg_file to $emailDirectory/$old_default_msg_file ",
	    	           "Check permissions for webserver on directory $emailDirectory. $!";
	    	$self->addgoodmessage(CGI::p("Backup file <code>$emailDirectory/$old_default_msg_file</code> created." . CGI::br()));
	    }
	    #################################################################
	    # Save the message
		#################################################################
		$self->saveProblem($temp_body, "${emailDirectory}/$output_file" ) unless ($output_file =~ /^[~.]/ || $output_file =~ /\.\./ || not $output_file =~ m|\.msg$|);
		unless ( $self->{submit_message} or not -w "${emailDirectory}/$output_file" )  {  # if there are no errors report success
			$self->addgoodmessage(CGI::p("Message saved to file <code>${emailDirectory}/$output_file</code>."));
		}    

	} elsif ($action eq 'previewMessage') {
		$self->{response}         = 'preview';
	
	} elsif ($action eq 'sendEmail') {
		# verify format of From address (one valid rfc2822 address)
		my @parsed_from_addrs = Email::Address->parse($self->{from});
		unless (@parsed_from_addrs == 1) {
			$self->addbadmessage("From field must contain one valid email address.");
			return;
		}
		
		# verify format of Reply-to address (zero or more valid rfc2822 addresses)
		if (defined $self->{replyTo} and $self->{replyTo} ne "") {
			my @parsed_replyto_addrs = Email::Address->parse($self->{replyTo});
			unless (@parsed_replyto_addrs > 0) {
				$self->addbadmessage("Invalid Reply-to address.");
				return;
			}
		}
		
	    # check that recipients have been selected.
		my @recipients            = @{$self->{ra_send_to}};
		unless (@recipients) {
			$self->addbadmessage(CGI::p("No recipients selected. Please select one or more recipients from the list below."));
			return;
		}
		
		#  get merge file
		my $merge_file      = ( defined($self->{merge_file}) ) ? $self->{merge_file} : 'None';
		my $delimiter       = ',';
		my $rh_merge_data   = $self->read_scoring_file("$merge_file", "$delimiter");
		unless (ref($rh_merge_data) ) {
			$self->addbadmessage(CGI::p("No merge data file"));
			$self->addbadmessage(CGI::p("Can't read merge file $merge_file. No message sent"));
			return;
		} ;
		$self->{rh_merge_data} = $rh_merge_data;
		
		# we don't set the response until we're sure that email can be sent
		$self->{response}         = 'send_email';
		
		# FIXME i'm not sure why we're pulling this out here -- mail_message_to_recipients does have
		# access to the course environment and should just grab it directly
		$self->{smtpServer}    = $ce->{mail}->{smtpServer};
		
		# do actual mailing in the cleanup phase, since it could take a long time
		# FIXME we need to do a better job providing status notifications for long-running email jobs
		my $post_connection_action = sub {
			my $r = shift; 
			# catch exceptions generated during the sending process
			my $result_message = eval { $self->mail_message_to_recipients() };
			if ($@) {
				# add the die message to the result message
				$result_message .= "An error occurred while trying to send email.\n"
					. "The error message is:\n\n$@\n\n";
				# and also write it to the apache log
				$r->log->error("An error occurred while trying to send email: $@\n");
			}
			# this could fail too...
			eval { $self->email_notification($result_message) };
			if ($@) {
				$r->log->error("An error occured while trying to send the email notification: $@\n");
			}
		};
		if (MP2) {
			$r->connection->pool->cleanup_register($post_connection_action, $r);
		} else {
			$r->post_connection($post_connection_action, $r);
		}
	} else {
		$self->addbadmessage(CGI::p("Didn't recognize action"));
	}



}  #end initialize





sub body {
	my ($self)          = @_;
	my $r               = $self->r;
	my $urlpath         = $r->urlpath;
	my $authz           = $r->authz;
	my $setID           = $urlpath->arg("setID");    
	my $response        = (defined($self->{response}))? $self->{response} : '';
	my $user            = $r->param('user');

	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to access instructor tools"))
		unless $authz->hasPermissions($user, "access_instructor_tools");

	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to send mail to students"))
		unless $authz->hasPermissions($user, "send_mail");

	if ($response eq 'preview') {
		$self->print_preview($setID);
	} elsif ($response eq 'send_email' and $self->{ra_send_to} and @{$self->{ra_send_to}}){
		my $message = CGI::i("Email is being sent to ".  scalar(@{$self->{ra_send_to}})." recipient(s). You will be notified"
		             ." by email when the task is completed.  This may take several minutes if the class is large."
		);
		$self->addgoodmessage($message);
		$self->{message} .= $message;
		
		$self->print_form($setID);
	} else {
		$self->print_form($setID);
	}

}

sub print_preview {
	my ($self)          = @_;
	my $r               = $self->r;
	my $urlpath         = $r->urlpath;
	my $setID           = $urlpath->arg("setID");    

	#  get preview user
	my $ur      = $r->db->getUser($self->{preview_user}); #checked
	die "record for preview user ".$self->{preview_user}. " not found." unless $ur;
	
	#  get merge file
	my $merge_file      = ( defined($self->{merge_file}) ) ? $self->{merge_file} : 'None';
	my $delimiter       = ',';
	my $rh_merge_data   = $self->read_scoring_file("$merge_file", "$delimiter");

	my ($msg, $preview_header) = $self->process_message($ur,$rh_merge_data,1); # 1 == for preview
	
	my $recipients  = join(" ",@{$self->{ra_send_to} });
	my $errorMessage =  defined($self->{submit_message}) ?  CGI::i($self->{submit_message} ) : '' ; 
	
	# Format message keeping the preview_header lined up
	$errorMessage = wrap("","",$errorMessage);
	$msg = wrap("","",$msg);
	
	$msg = join("",
	   $errorMessage,
	   $preview_header,
	   "To: "             , $ur->email_address,"\n",
       "From: "           , $self->{from} , "\n" ,
       "Reply-To: "       , $self->{replyTo} , "\n" ,
       "Subject:  "       , $self->{subject} , "\n" ,"\n" , 
	   $msg , "\n"
	);

#	return join("", '<pre>',wrap("","",$msg),"\n","\n",
	return join("", '<pre>',$msg,"\n","\n",
				   '</pre>', 
				   CGI::p('Use browser back button to return from preview mode'),
				   CGI::h3('Emails to be sent to the following:'), 
				   $recipients, "\n",
	               
	);

}
sub print_form {
	my ($self)          = @_;
	my $r               = $self->r;
	my $urlpath         = $r->urlpath;
	my $authz           = $r->authz;	
	my $db              = $r->db;
	my $ce              = $r->ce;
	my $courseName      = $urlpath->arg("courseID");
	my $setID           = $urlpath->arg("setID");    
	my $user            = $r->param('user');

	my $root            = $ce->{webworkURLs}->{root};
	my $sendMailPage    = $urlpath->newFromModule($urlpath->module, $r, courseID=>$courseName);
	my $sendMailURL     = $self->systemLink($sendMailPage, authen => 0);

        return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");

	my $userTemplate = $db->newUser;
	my $permissionLevelTemplate = $db->newPermissionLevel;
	
	# This code will require changing if the permission and user tables ever have different keys.
	my @users                 = sort @{ $self->{ra_users} };
	my $ra_user_records       = $self->{ra_user_records};
	my %classlistLabels       = ();#  %$hr_classlistLabels;
	foreach my $ur (@{ $ra_user_records }) {
		$classlistLabels{$ur->user_id} = $ur->user_id.': '.$ur->last_name. ', '. $ur->first_name.' -- '.$ur->section." / ".$ur->recitation;
	}

	## Mark edit define scrolling list
	my $scrolling_user_list = scrollingRecordList({
		name => "classList", 			## changed from classList to action
		request => $r,
		default_sort => "lnfn",
		default_format => "lnfn_uid",
		default_filters => ["all"],
		size => 5,
		multiple => 1,
		refresh_button_name =>$r->maketext('Update settings and refresh page'),
	}, @{$ra_user_records});

	##############################################################################################################
	

	my $from            = $self->{from};
	my $subject         = $self->{subject};
	my $replyTo         = $self->{replyTo};
	my $columns         = $self->{columns};
	my $rows            = $self->{rows};
	my $text            = defined($self->{r_text}) ? ${ $self->{r_text} }: 'FIXME no text was produced by initialization!!';
	my $input_file      = $self->{input_file};
	my $output_file     = $self->{output_file};
	my @sorted_messages = $self->get_message_file_names;
	my @sorted_merge_files = $self->get_merge_file_names;
	my $merge_file      = ( defined($self->{merge_file}) ) ? $self->{merge_file} : 'None';
	my $delimiter       = ',';
	my $rh_merge_data   = $self->read_scoring_file("$merge_file", "$delimiter");
	my @merge_keys      = keys %$rh_merge_data;
	my $preview_user    = $self->{preview_user};
	my $preview_record   = $db->getUser($preview_user); # checked
	die "record for preview user ".$self->{preview_user}. " not found." unless $preview_record;


	#############################################################################################		

	print CGI::start_form({id=>"send-mail-form", name=>"send-mail-form", method=>"post", action=>$sendMailURL});
	print $self->hidden_authen_fields();
	#############################################################################################
	#	begin upper table
	#############################################################################################	

    print CGI::start_table({-border=>'2', -cellpadding=>'4'});
	print CGI::Tr({-align=>'left',-valign=>'top'},
	#############################################################################################
	#	first column
	#############################################################################################	

			 CGI::td({},
			     CGI::strong($r->maketext("Message file: ")), $input_file,"\n",CGI::br(),
				 CGI::submit(-name=>'openMessage', -value=>$r->maketext('Open')), '&nbsp;&nbsp;&nbsp;&nbsp;',"\n",
				 CGI::popup_menu(-name=>'openfilename', 
				                 -values=>\@sorted_messages, 
				                 -default=>$input_file
				 ), 
				 "\n",CGI::br(),
				 CGI::strong($r->maketext("Save file to: ")), $output_file,
				 "\n",CGI::br(),
				 CGI::strong($r->maketext('Merge file: ')), $merge_file, 
				 CGI::br(),
				 CGI::popup_menu(-name=>'merge_file', 
				                 -values=>\@sorted_merge_files, 
				                 -default=>$merge_file,
				 ), "\n",
				 "\n",
				 #CGI::hr(),
				 CGI::div(
					 "\n", $r->maketext('From:'),'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',  CGI::textfield(-name=>"from", -size=>30, -value=>$from, -override=>1),    
					 "\n", CGI::br(),$r->maketext('Reply-To: '), CGI::textfield(-name=>"replyTo", -size=>30, -value=>$replyTo, -override=>1), 
					 "\n", CGI::br(),$r->maketext('Subject:  '), CGI::br(), CGI::textarea(-name=>'subject', -default=>$subject, -rows=>3,-cols=>30, -override=>1),  
				),
				#CGI::hr(),
				$r->maketext("Editor rows: "), CGI::textfield(-name=>'rows', -size=>3, -value=>$rows),
				$r->maketext(" columns: "), CGI::textfield(-name=>'columns', -size=>3, -value=>$columns),
				CGI::br(),
				CGI::submit(-name=>'updateSettings', -value=>$r->maketext("Update settings and refresh page")),
				 
			),
	#############################################################################################
	#	second column
	#############################################################################################	

	## Edit by Mark to insert scrolling list
					CGI::td({-style=>"width:33%"},
					     CGI::strong($r->maketext("Send to:")),
		                  CGI::radio_group(-name=>'radio', 
		                                   -values=>['all_students','studentID'],
		                                   -labels=>{all_students=>$r->maketext('All students in course'),studentID => $r->maketext('Selected students')},
		                                   -default=>'studentID', -linebreak=>0), 
							CGI::br(),$scrolling_user_list,
							CGI::i($r->maketext("Preview set to: ")), $preview_record->last_name,'(', $preview_record->user_id,')',
							CGI::submit(-name=>'previewMessage', -value=>'preview',-label=>$r->maketext('Preview message')),'&nbsp;&nbsp;',
					),
	); # end Tr
	
	# second row, for reference popup menu
	print CGI::Tr(
			CGI::td({align=>'center',colspan=>2},

				
				#CGI::i('Press any action button to update display'),CGI::br(),
			#show available macros
				CGI::popup_menu(
						-name=>'dummyName',
						-values=>['', '$SID', '$FN', '$LN', '$SECTION', '$RECITATION','$STATUS', '$EMAIL', '$LOGIN', '$COL[n]', '$COL[-1]'],
						-labels=>{''=>'list of insertable macros',
							'$SID'=>'$SID - Student ID',
							'$FN'=>'$FN - First name',
							'$LN'=>'$LN - Last name',
							'$SECTION'=>'$SECTION',
							'$RECITATION'=>'$RECITATION',
							'$STATUS'=>'$STATUS - Enrolled, Drop, etc.',
							'$EMAIL'=>'$EMAIL - Email address',
							'$LOGIN'=>'$LOGIN - Login',
							'$COL[n]'=>'$COL[n] - nth colum of merge file',
							'$COL[-1]'=>'$COL[-1] - Last column of merge file'
							}
				), "\n",
			),
	);
	
	print CGI::end_table();	
	#############################################################################################
	#	end upper table
	#############################################################################################	
 
	#############################################################################################
	#	merge file fragment and message text area field
	#############################################################################################	
	my @tmp2;
	eval{  @tmp2= @{$rh_merge_data->{ $db->getUser($preview_user)->student_id  }  };}; # checked
	if ($@ and $merge_file ne 'None') {
		print "No merge data for $preview_user in merge file: &lt;$merge_file&gt;",CGI::br();
	} else {
		print CGI::pre("",data_format(1..($#tmp2+1)),"<br>", data_format2(@tmp2));
	}
	#create a textbox with the subject and a textarea with the message
	#print actual body of message

	print  "\n", CGI::p( $self->{message}) if defined($self->{message});  
	print "\n", CGI::label({'for'=>"email-body"},$r->maketext("Email Body:")),CGI::span({class=>"required-field"},'*');
	print  "\n", CGI::p( CGI::textarea(-id=>"email-body", -name=>'body', -default=>$text, -rows=>$rows, -cols=>$columns, -override=>1));

	#############################################################################################
	#	action button table
	#############################################################################################	
	print    CGI::table( { -border=>2,-cellpadding=>4},
				 CGI::Tr( {},
					 CGI::td({}, CGI::submit(-name=>'sendEmail', -id=>"sendEmail_id", -value=>$r->maketext('Send Email')) ), "\n",
					 CGI::td({}, CGI::submit(-name=>'saveMessage', -value=>$r->maketext('Save'))," to $output_file"), " \n",
					 CGI::td({}, CGI::submit(-name=>'saveAs', -value=>$r->maketext('Save as:')),
					         CGI::textfield(-name=>'savefilename', -size => 20, -value=> "$output_file", -override=>1)
					 ), "\n",
					 CGI::td(CGI::submit(-name=>'saveDefault', -value=>$r->maketext('Save as Default'))),
				) 
	);
			   
	##############################################################################################################

	print CGI::end_form();	
	return "";
}

##############################################################################
# Utility methods
##############################################################################

sub saveProblem {     
    my $self      = shift;
	my ($body, $probFileName)= @_;
	local(*PROBLEM);
	open (PROBLEM, ">$probFileName") ||
		$self->addbadmessage(CGI::p("Could not open $probFileName for writing.
						Check that the  permissions for this problem are 660 (-rw-rw----)"));
	print PROBLEM $body if -w $probFileName;
	close PROBLEM;
	chmod 0660, "$probFileName" ||
	             $self->addbadmessage(CGI::p("CAN'T CHANGE PERMISSIONS ON FILE $probFileName"));
}

sub read_input_file {
	my $self         = shift;
	my $filePath     = shift;
	my ($text, @text);
	my $header = '';
	my ($subject, $from, $replyTo);
	local(*FILE);
	if (-e "$filePath" and -r "$filePath") {
		open FILE, "$filePath" || do { $self->addbadmessage(CGI::p("Can't open $filePath")); return};
		while ($header !~ s/Message:\s*$//m and not eof(FILE)) { 
			$header .= <FILE>; 
		}
		$text = join( '', <FILE>);
		$text =~ s/^\s*//; # remove initial white space if any.
		$header         =~ /^From:\s(.*)$/m;
		$from           = $1 or $from = $self->{defaultFrom}; 
		
		$header         =~ /^Reply-To:\s(.*)$/m;
		$replyTo        = $1 or $replyTo = $self->{defaultReply};
		
		$header         =~ /^Subject:\s(.*)$/m;
		$subject        = $1;

	} else {
		$from           = $self->{defaultFrom};
		$replyTo        = $self->{defaultReply};
		$text           =  (-e "$filePath") ? "FIXME file $filePath can't be read" :"FIXME file $filePath doesn't exist";
		$subject        = $self->{defaultSubject};
	}
	return ($from, $replyTo, $subject, \$text);
}


sub get_message_file_names {
	my $self         = shift;
	return $self->read_dir($self->{ce}->{courseDirs}->{email}, '\\.msg$');
}
sub get_merge_file_names   {
	my $self         = shift;
	return 'None', $self->read_dir($self->{ce}->{courseDirs}->{scoring}, '\\.csv$'); #FIXME ? check that only readable files are listed.
}

sub mail_message_to_recipients {
	my $self                  = shift;
	my $r                     = $self->r;
	my $ce                    = $r->ce;
	my $subject               = $self->{subject};
	my $from                  = $self->{from};
	my @recipients            = @{$self->{ra_send_to}};
	my $rh_merge_data         = $self->{rh_merge_data};
	my $merge_file            = $self->{merge_file};  
	my $result_message        = '';
	my $failed_messages        = 0;
	my $error_messages         = '';
	foreach my $recipient (@recipients) {
			$error_messages = '';

			my $ur      = $self->{db}->getUser($recipient); #checked
			unless ($ur) {
				$error_messages .= "Record for user $recipient not found\n";		 
				next;
			}
			unless ($ur->email_address=~/\S/) { #unless address contains a non-blank charachter
				$error_messages .="User $recipient does not have an email address -- skipping\n";		 
				next;
			}
           	#warn "\nDEBUG: sending email to $recipient with email address ",$ur->email_address,"\n";

			my $msg = eval { $self->process_message($ur,$rh_merge_data) };
			$error_messages .= "There were errors in processing user $recipient, merge file $merge_file. \n$@\n" if $@;
			#warn "message is ok";
			my $mailer = eval{ Mail::Sender->new({
					tls_allowed => $ce->{tls_allowed}//1, # the default for this for  Mail::Sender is 1
					from      => $ce->{mail}{smtpSender},
					fake_from => $from,
					to        => $ur->email_address,
					smtp      => $self->{smtpServer},
					subject   => $subject,
					headers   => "X-Remote-Host: ".$self->{remote_host},
				})
			};
			if ($@) {
				$error_messages .= "Failed to create a mailer for user $recipient: $Mail::Sender::Error\n$@\n";		 
				next;
			}
			#warn "DEBUG: mailer created as $mailer\n";
			unless (ref($mailer) and $mailer->Open()) {
				$error_messages .= "Failed to open the mailer for user $recipient: $@\n $Mail::Sender::Error\n";
				next;
			}
			#warn "DEBUG: mailer opened\n";
			my $MAIL         = $mailer->GetHandle() || ($error_messages .= "$recipient: Couldn't get mailer handle \n");
			print $MAIL        $msg                 || ($error_messages .= "$recipient: Couldn't print to mail $MAIL\n");
			close $MAIL                             || ($error_messages .= "$recipient: Couldn't close mail $MAIL -- possibly a badly formed address: ".$ur->email_address."\n");
		    #warn "DEBUG: mailed to $recipient: ", $ur->email_address, " from $from subject $subject. Errors:\n $error_messages\n\n";
		    #FIXME -- allow this list to be turned off with a "verbose" flag
		    $result_message .= "Msg sent to $recipient at ".$ur->email_address."\n" unless $error_messages;
		} continue { #update failed messages before continuing loop
			if ($error_messages) {
				$failed_messages++;
		    	$result_message .= $error_messages;	
		    } 	 		
		}
		my $courseName = $self->r->urlpath->arg("courseID");
		my $number_of_recipients = scalar(@recipients) - $failed_messages;
		$result_message = <<EndText.$result_message;
		
			A message with the subject line 
			             $subject 
			has been sent to 
			$number_of_recipients recipient(s) in the class $courseName. 
			There were $failed_messages message(s) that could not be sent.\n 
		
EndText

}
sub email_notification {
	my $self = shift;
	my $result_message = shift;
	# find info on mailer and sender
	# use the defaultFrom address.

	# find info on instructor recipient and message
	my $subject="WeBWorK email sent";
	
	my $mailing_errors = "";
	# open MAIL handle
	my $mailer = Mail::Sender->new({
		tls_allowed => $self->r->ce->{tls_allowed}//1, # the default for this for  Mail::Sender is 1
		from => $self->{defaultFrom},
		to   => $self->{defaultFrom},
		smtp    => $self->{smtpServer},
		subject => $subject,
		headers => "X-Remote-Host: ".$self->{remote_host},
	});
	unless (ref $mailer) {
		$mailing_errors .= "Failed to create a mailer: $Mail::Sender::Error";
		return "";
	}
	unless (ref $mailer->Open()) {
		$mailing_errors .= "Failed to open the mailer: $Mail::Sender::Error";
		return "";
	}
	my $MAIL = $mailer->GetHandle();
	# print message
	print $MAIL $result_message;
	# clean up
	close $MAIL;
	
    warn "\ninstructor message \"". $self->{subject}."\" sent to ", $self->{defaultFrom},"\n";

}
sub getRecord {
	my $self    = shift;
	my $line    = shift;
	my $delimiter   = shift;
	$delimiter       = ',' unless defined($delimiter);

        #       Takes a delimited line as a parameter and returns an
        #       array.  Note that all white space is removed.  If the
        #       last field is empty, the last element of the returned
        #       array is also empty (unlike what the perl split command
        #       would return).  E.G. @lineArray=&getRecord(\$delimitedLine).

        my(@lineArray);
        $line.="${delimiter}___";                       # add final field which must be non-empty
        @lineArray = split(/\s*${delimiter}\s*/,$line); # split line into fields
        $lineArray[0] =~s/^\s*//;                       # remove white space from first element
        pop @lineArray;                                 # remove the last artificial field
        @lineArray;
}

sub process_message {
	my $self          = shift;
	my $ur            = shift;
	my $rh_merge_data = shift;
	my $for_preview   = shift;
	my $text          = defined($self->{r_text}) ? ${ $self->{r_text} }:
	                        'FIXME no text was produced by initialization!!';	
	my $merge_file      = ( defined($self->{merge_file}) ) ? $self->{merge_file} : 'None';  
	
	my $status_name = $self->r->ce->status_abbrev_to_name($ur->status);
	$status_name = $ur->status unless defined $status_name;
	
	#user macros that can be used in the email message
	my $SID           = $ur->student_id;
	my $FN            = $ur->first_name;
	my $LN            = $ur->last_name;
	my $SECTION       = $ur->section;
	my $RECITATION    = $ur->recitation;
	my $STATUS        = $status_name;
	my $EMAIL         = $ur->email_address;
	my $LOGIN         = $ur->user_id;
	
	# get record from merge file
	# FIXME this is inefficient.  The info should be cached
	my @COL            = defined($rh_merge_data->{$SID}) ? @{$rh_merge_data->{$SID} } : ();
	if ($merge_file ne 'None' and not defined($rh_merge_data->{$SID}) and $for_preview) {
		$self->addbadmessage(CGI::p("No merge data for student id:$SID; name:$FN $LN; login:$LOGIN"));
	}
	unshift(@COL,"");			## this makes COL[1] the first column
	my $endCol = @COL;
	# for safety, only evaluate special variables
 	my $msg = $text;    
 	$msg =~ s/\$SID/$SID/ge;
 	$msg =~ s/\$LN/$LN/ge;
 	$msg =~ s/\$FN/$FN/ge;
 	$msg =~ s/\$STATUS/$STATUS/ge;
 	$msg =~ s/\$SECTION/$SECTION/ge;
 	$msg =~ s/\$RECITATION/$RECITATION/ge;
 	$msg =~ s/\$EMAIL/$EMAIL/ge;
 	$msg =~ s/\$LOGIN/$LOGIN/ge;
	if (defined($COL[1])) {		# prevents extraneous error messages.  
		$msg =~ s/\$COL\[(\-?\d+)\]/$COL[$1]/ge
	}
	else {						# prevents extraneous $COL's in email message 
		$msg =~ s/\$COL\[(\-?\d+)\]//g
	}			
			 
 	$msg =~ s/\r//g;
	
	if ($for_preview) {
		my @preview_COL = @COL;
		shift @preview_COL; ## shift back for preview
		my $preview_header = 	CGI::p('',data_format(1..($#COL)),"<br>", data_format2(@preview_COL)).
			                    CGI::h3( "This sample mail would be sent to $EMAIL");
		return $msg, $preview_header;
	} else {
		return $msg;
	}
}


# Ý sub data_format {
# 
# Ý Ý Ý Ý Ýmap {$_ =~s/\s/\./g;$_} Ý Ý map {sprintf('%-8.8s',$_);} Ý@_;
 sub data_format {
 	    map {"COL[$_]".'&nbsp;'x(3-length($_));}  @_;  # problems if $_ has length bigger than 4
 }
  sub data_format2 {
    map {$_ =~s/\s/&nbsp;/g;$_}  map {sprintf('%-8.8s',$_);} @_;
 }
1;
