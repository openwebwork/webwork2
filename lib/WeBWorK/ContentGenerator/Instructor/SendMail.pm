################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/SendMail.pm,v 1.26 2004/05/07 18:49:40 sh002i Exp $
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
use CGI qw();
#use HTML::Entities;
use Mail::Sender;

my $REFRESH_RESIZE_BUTTON = "Set preview to: ";  # handle submit value idiocy
sub initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $ce     = $r->ce;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	unless ($authz->hasPermissions($user, "send_mail")) {
		$self->{submitError} = "You are not authorized to send mail to students.";
		return;
	}
#############################################################################################
#	gather directory data
#############################################################################################	
	my $emailDirectory    =    $ce->{courseDirs}->{email};
	my $scoringDirectory  =    $ce->{courseDirs}->{scoring};
	my $templateDirectory =    $ce->{courseDirs}->{templates};
	
	my $action            =    $r->param('action'); 
	my $openfilename      =	   $r->param('openfilename');
	my $savefilename      =	   $r->param('savefilename');
	
	
	#FIXME  get these values from global course environment (see subroutines as well)
	my $default_msg_file       =    'default.msg';  
	my $old_default_msg_file   =    'old_default.msg';
	

	# store data
	$self->{defaultFrom}            =   'FIXME from';
	$self->{defaultReply}           =   'FIXME reply';	
	$self->{rows}                   =   (defined($r->param('rows'))) ? $r->param('rows') : $ce->{mail}->{editor_window_rows};
	$self->{columns}                =   (defined($r->param('columns'))) ? $r->param('columns') : $ce->{mail}->{editor_window_columns};
	$self->{default_msg_file}	    =   $default_msg_file;
	$self->{old_default_msg_file}   =   $old_default_msg_file;
	$self->{merge_file}             =   (defined($r->param('merge_file'  )))    ? $r->param('merge_file')   : 'None';
	$self->{preview_user}           =   (defined($r->param('preview_user')))    ? $r->param('preview_user') : $user;
	
	
#############################################################################################
#	gather database data
#############################################################################################	
	# FIXME  this might be better done in body? We don't always need all of this data. or do we?
	my @users =  $db->listUsers;
	my @user_records = ();
	foreach my $userName (@users) {
		my $userRecord = $db->getUser($userName); # checked
		die "record for user $userName not found" unless $userRecord;
		push(@user_records, $userRecord);
	}
	###########################
	# Sort the users for presentation in the select list
	###########################
	if (defined $r->param("sort_by") ) {
		my $sort_method = $r->param("sort_by");
		if ($sort_method eq 'section') {
			@user_records = sort { (lc($a->section) cmp lc($b->section)) || (lc($a->last_name) cmp lc($b->last_name)) } @user_records;
		} elsif ($sort_method eq 'recitation') {
			@user_records = sort { (lc($a->recitation) cmp lc($b->recitation)) || (lc($a->last_name) cmp lc($b->last_name)) } @user_records;
		} elsif ($sort_method eq 'alphabetical') {
			@user_records = sort {  (lc($a->last_name) cmp lc($b->last_name)) } @user_records;
		} elsif ($sort_method eq 'id' )          {
		    @user_records = sort { $a->user_id cmp $b->user_id }  @user_records;		
		}
	} else {
		@user_records = sort { $a->user_id cmp $b->user_id }  @user_records;
	}
	

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
		foreach my $ur (@user_records) {
			push(@send_to,$ur->user_id) if $ur->status eq 'C' and not($ur->user_id =~ /practice/);
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
				warn join("",
					"The file ${emailDirectory}/$openfilename is not readable by the webserver.",CGI::br(),
					"Check that it's permissions are set correctly.",
				);
			}
		} else {
			$input_file = $default_msg_file;
			warn join("",
				  "The file ${emailDirectory}/$openfilename cannot be found.",CGI::br(),
				  "Check whether it exists and whether the directory $emailDirectory can be read by the webserver.",CGI::br(),
				  "Using contents of the default message $default_msg_file instead.",
			);
		}
	} else {
		$input_file     = $default_msg_file;
	}
	$self->{input_file} =$input_file;

#################################################################
# Determine the file name to save message into
#################################################################
	my $output_file      = 'FIXME no output file specified';	
	if (defined($action) and $action eq 'Save as Default') {
		$output_file  = $default_msg_file;
	} elsif ( defined($action) and ($action =~/save/i) and defined($savefilename) and $savefilename ){
		$output_file  = $savefilename;
	} elsif ( defined($input_file) ) {
		$output_file  = $input_file;
	}

	#################################################################
	# Sanity check on save file name
	#################################################################

	if ($output_file =~ /^[~.]/ || $output_file =~ /\.\./) {
		$self->submission_error("For security reasons, you cannot specify a message file from a directory", 
								"higher than the email directory (you can't use ../blah/blah for example). ", 
								"Please specify a different file or move the needed file to the email directory",
		);
	}
	unless ($output_file =~ m|\.msg$| ) {
		$self->submission_error("Invalid file name.", 
		                        "The file name \"$output_file\" does not have a \".msg\" extension",
								"All email file names must end in the extension \".msg\"",
								"choose a file name with a \".msg\" extension.",
								"The message was not saved.",
		);
	}
	$self->{output_file} = $output_file;  # this is ok.  It will be put back in the text input box for re-editing.
    # FIXME $output_file can be blank if there was no savefilename

#############################################################################################
# Determine input source
#############################################################################################
	my $input_source =  ( defined( $r->param('body') ) and $action ne 'Open' ) ? 'form' : 'file';

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
		my $body              =    $r->param('body');
		# Sanity check: body must contain non-white space
		$self->submission_error('You didn\'t enter any message.') unless ($r->param('body') =~ /\S/);
		$r_text               =    \$body;

	}
	# store data
	$self->{from}                   =    $from;
	$self->{replyTo}                =    $replyTo;
	$self->{subject}                =    $subject;
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
	
	
	if(not defined($action) or $action eq 'Open' or $action eq $REFRESH_RESIZE_BUTTON or $action eq 'Sort by'
	   or $action eq 'Set merge file to:' ){  

		return '';
	}

	

	

#############################################################################################
# If form is submitted deal with filled out forms 
# and various actions resulting from different buttons
#############################################################################################


	if ($action eq 'Save' or $action eq 'Save as:' or $action eq 'Save as Default') {
	
#		warn "FIXME Saving files  action = $action  outputFileName=$output_file";
		
		#################################################################
		# construct message body
		#################################################################
		my $temp_body = ${ $r_text };
		$temp_body =~ s/\r\n/\n/g;
		$temp_body = join("",
				   "From: $from \nReply-To: $replyTo\n" ,
				   "Subject: $subject\n" ,
				   "Message: \n    $temp_body");
#		warn "FIXME from $from | subject $subject |reply $replyTo|msg $temp_body";
		#################################################################
		# overwrite protection
		#################################################################
		if ($action eq 'Save as:' and -e "$emailDirectory/$output_file") {
			$self->submission_error("The file $emailDirectory/$output_file already exists and cannot be overwritten",
			                         "The message was not saved");
			return;	
		}
 
		#################################################################
	    # Back up existing file?
	    #################################################################
	    if ($action eq 'Save as Default' and -e "$emailDirectory/$default_msg_file") {
	    	rename("$emailDirectory/$default_msg_file","$emailDirectory/$old_default_msg_file") or 
	    	       die "Can't rename $emailDirectory/$default_msg_file to $emailDirectory/$old_default_msg_file ",
	    	           "Check permissions for webserver on directory $emailDirectory. $!";
	    	$self->{message} .= "Backup file <code>$emailDirectory/$old_default_msg_file</code> created.".CGI::br();
	    }
	    #################################################################
	    # Save the message
		#################################################################
		$self->saveProblem($temp_body, "${emailDirectory}/$output_file" );
		unless ( $self->{submitError} or not -w "${emailDirectory}/$output_file" )  {  # if there are no errors report success
			$self->{message}         .= "Message saved to file <code>${emailDirectory}/$output_file</code>.";
		}    

	} elsif ($action eq 'Preview message') {
		$self->{response}         = 'preview';
	
	} elsif ($action eq 'Send Email') {
		$self->{response}         = 'send_email';

		my @recipients            = @{$self->{ra_send_to}};
		$self->addmessage(CGI::div({class=>'ResultsWithError'},
			"No recipients selected")) unless @recipients;
		#  get merge file
		my $merge_file      = ( defined($self->{merge_file}) ) ? $self->{merge_file} : 'None';
		my $delimiter       = ',';
		my $rh_merge_data   = $self->read_scoring_file("$merge_file", "$delimiter");
		unless (ref($rh_merge_data) ) {
			warn "no merge data file";
			$self->submission_error("Can't read merge file $merge_file. No message sent");
			return;
		} ;
		
		
		foreach my $recipient (@recipients) {
			#warn "FIXME sending email to $recipient";
			my $ur      = $self->{db}->getUser($recipient); #checked
			die "record for user $recipient not found" unless $ur;
			unless ($ur->email_address) {
				$self->addmessage(CGI::div({class=>'ResultsWithError'},
					"user $recipient does not have an email address -- skipping"));
				next;
			}
			my ($msg, $preview_header);
			eval{ ($msg,$preview_header) = $self->process_message($ur,$rh_merge_data); };
			warn "There were errors in processing user $ur, merge file $merge_file. $@" if $@;
			my $mailer = Mail::Sender->new({
				from    =>   $from,
				to      =>   $ur->email_address,
				smtp    =>   $ce->{mail}->{smtpServer},
				subject =>   $subject,
				headers =>   "X-Remote-Host: ".$r->get_remote_host(),
			});
			unless (ref $mailer) {
				warn "Failed to create a mailer for user $recipient: $Mail::Sender::Error";
				next;
			}
			unless (ref $mailer->Open()) {
				warn "Failed to open the mailer for user $recipient: $Mail::Sender::Error";
				next;
			}
			my $MAIL = $mailer->GetHandle() or warn "Couldn't get handle";
			print $MAIL  $msg || warn "Couldn't print to $MAIL";
			close $MAIL || warn "Couldn't close $MAIL";
		    #warn "FIXME mailed to ", $ur->email_address, "from $from subject $subject";
			 
		} 
			
	} else {
		warn "Didn't recognize button $action";
	}



}  #end initialize





sub body {
	my ($self)          = @_;
	my $r               = $self->r;
	my $urlpath         = $r->urlpath;
	my $setID           = $urlpath->arg("setID");    
	my $response        = (defined($self->{response}))? $self->{response} : '';
	if ($response eq 'preview') {
		$self->print_preview($setID);
	} elsif (($response eq 'send_email')){
		$self->{message} .= CGI::h3("Email sent to "). join(" ", @{$self->{ra_send_to}});
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

	my ($msg, $preview_header) = $self->process_message($ur,$rh_merge_data);
	
	my $recipients  = join(" ",@{$self->{ra_send_to} });
	my $errorMessage =  defined($self->{submitError}) ?  CGI::h3($self->{submitError} ) : '' ; 
	$msg = join("",
	   $errorMessage,
	   $preview_header,
	   "To: "             , $ur->email_address,"\n",
       "From: "           , $self->{from} , "\n" ,
       "Reply-To: "       , $self->{replyTo} , "\n" ,
       "Subject:  "       , $self->{subject} , "\n" ,"\n" , 
	   $msg , "\n"
	);

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
	my $sendMailPage    = $urlpath->newFromModule($urlpath->module,courseID=>$courseName);
	my $sendMailURL     = $self->systemLink($sendMailPage, authen => 0);

    	return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");

	my $userTemplate = $db->newUser;
	my $permissionLevelTemplate = $db->newPermissionLevel;
	
	# This code will require changing if the permission and user tables ever have different keys.
	my @users                 = @{ $self->{ra_users} };
	my $ra_user_records       = $self->{ra_user_records};
	my %classlistLabels       = ();#  %$hr_classlistLabels;
	foreach my $ur (@{ $ra_user_records }) {
		$classlistLabels{$ur->user_id} = $ur->user_id.': '.$ur->last_name. ', '. $ur->first_name.' -- '.$ur->section." / ".$ur->recitation;
	}


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

	print CGI::start_form({method=>"post", action=>$sendMailURL});
	print $self->hidden_authen_fields();
#############################################################################################
#	begin upper table
#############################################################################################	

    print CGI::start_table({-border=>'2', -cellpadding=>'4'});
	print CGI::Tr({-align=>'left',-valign=>'top'},
#############################################################################################
#	first column
#############################################################################################	

			 CGI::td(CGI::strong("Message file: $input_file"),"\n",CGI::br(),
				 CGI::submit(-name=>'action', -value=>'Open'), '&nbsp;&nbsp;&nbsp;&nbsp;',"\n",
				 CGI::popup_menu(-name=>'openfilename', 
				                 -values=>\@sorted_messages, 
				                 -default=>$input_file
				 ), "\n",CGI::br(),

				 "Save file to: $output_file","\n",CGI::br(),
				 "\n", 'From:','&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',  CGI::textfield(-name=>"from", -size=>30, -value=>$from, -override=>1),    
				 "\n", CGI::br(),'Reply-To: ', CGI::textfield(-name=>"replyTo", -size=>30, -value=>$replyTo, -override=>1), 
				 "\n", CGI::br(),'Subject:  ', CGI::br(), CGI::textarea(-name=>'subject', -default=>$subject, -rows=>3,-columns=>30, -override=>1),  
			),
#############################################################################################
#	second column
#############################################################################################	
			CGI::td({-align=>'left',style=>'font-size:smaller'},
			   
			    		    CGI::strong("Send to:"),
							CGI::radio_group(-name=>'radio', -values=>['all_students','studentID'],
								-labels=>{all_students=>'All',studentID => 'Selected'},
								-default=>'studentID',
								-linebreak=>0
							), CGI::br(),CGI::br(),
						
						    CGI::input({type=>'submit',value=>'Sort by',name=>'action'}),, 
							CGI::radio_group(-name=>'sort_by', -values=>['id','alphabetical','section','recitation'],
								-labels=>{id=>'Login',alphabetical=>'Alph.',section => 'Sec.',recitation=>'Rec.'},
								-default=>defined($r->param("sort_by")) ? $r->param("sort_by") : 'id',
								-linebreak=>0
							),

						CGI::br(),CGI::br(),
				CGI::popup_menu(-name=>'classList',
						   -values=>\@users,
						   -labels=>\%classlistLabels,
						   -size  => 10,
						   -multiple => 1,
						   -default=>$user
				),
			),	
				

#############################################################################################
#	third column
#############################################################################################	
			CGI::td({align=>'left'},
			     "<b>Merge file:</b> $merge_file", CGI::br(),
				 CGI::submit(-name=>'action', -value=>'Set merge file to:'),CGI::br(),
				 CGI::popup_menu(-name=>'merge_file', 
				                 -values=>\@sorted_merge_files, 
				                 -default=>$merge_file,
				 ), "\n",CGI::hr(),
				CGI::b("Viewing email for: "), "$preview_user",CGI::br(),
				CGI::submit(-name=>'action', -value=>'resize', -label=>$REFRESH_RESIZE_BUTTON),'&nbsp;',
				CGI::popup_menu(-name=>'preview_user',
							   -values=>\@users,
							   #-labels=>\%classlistLabels,
							   -default=>$preview_user,
				),
				CGI::br(),
				CGI::submit(-name=>'action', -value=>'preview',-label=>'Preview message'),'&nbsp;&nbsp;',
				
				CGI::br(),
				
				CGI::hr(),
				" Rows: ", CGI::textfield(-name=>'rows', -size=>3, -value=>$rows),
				" Columns: ", CGI::textfield(-name=>'columns', -size=>3, -value=>$columns),
				CGI::br(),CGI::i('Press any action button to update display'),CGI::br(),
			#show available macros
				CGI::popup_menu(
						-name=>'dummyName',
						-values=>['', '$SID', '$FN', '$LN', '$SECTION', '$RECITATION','$STATUS', '$EMAIL', '$LOGIN', '$COL[3]', '$COL[-1]'],
						-labels=>{''=>'list of insertable macros',
							'$SID'=>'$SID - Student ID',
							'$FN'=>'$FN - First name',
							'$LN'=>'$LN - Last name',
							'$SECTION'=>'$SECTION',
							'$RECITATION'=>'$RECITATION',
							'$STATUS'=>'$STATUS - C, Audit, Drop, etc.',
							'$EMAIL'=>'$EMAIL - Email address',
							'$LOGIN'=>'$LOGIN - Login',
							'$COL[3]'=>'$COL[3] - 3rd col',
							'$COL[-1]'=>'$COL[-1] - Last column'
							}
				), "\n",
			),

	); # end Tr
	print CGI::end_table();	
#############################################################################################
#	end upper table
#############################################################################################	
 
# show merge file
#         print  "<pre>",(map {$_ =~s/\s/\./g;$_}     map {sprintf('%-8.8s',$_);}  0..8),"</pre>";
# 		print  CGI::popup_menu(
# 						-name=>'dummyName2',
# 						-values=>\@merge_keys,
# 						-labels=>$rh_merge_data,
# 						-multiple=>1,
# 						-size    =>2,
# 						
# 				), "\n",CGI::br();
#       warn "merge keys ", join( " ",@merge_keys);
#############################################################################################
#	merge file fragment and message text area field
#############################################################################################	
		my @tmp2;
        eval{  @tmp2= @{$rh_merge_data->{ $db->getUser($preview_user)->student_id  }  };}; # checked
        if ($@ and $merge_file ne 'None') {
			print "No merge data for $preview_user in merge file: &lt;$merge_file&gt;",CGI::br();
        } else {
			print CGI::pre("",data_format(0..($#tmp2)),"<br>", data_format2(@tmp2));
		}
#create a textbox with the subject and a textarea with the message
#print actual body of message

	print  "\n", CGI::p( $self->{message}) if defined($self->{message});  
    print  "\n", CGI::p( CGI::textarea(-name=>'body', -default=>$text, -rows=>$rows, -columns=>$columns, -override=>1));

#############################################################################################
#	action button table
#############################################################################################	
	print    CGI::table( { -border=>2,-cellpadding=>4},
				 CGI::Tr( 
					 CGI::td( CGI::submit(-name=>'action', -value=>'Send Email') ), "\n",
					 CGI::td(CGI::submit(-name=>'action', -value=>'Save')," to $output_file"), " \n",
					 CGI::td(CGI::submit(-name=>'action', -value=>'Save as:'),
					         CGI::textfield(-name=>'savefilename', -size => 20, -value=> "$output_file", -override=>1)
					 ), "\n",
					 CGI::td(CGI::submit(-name=>'action', -value=>'Save as Default')),
				) 
	);
			   
##############################################################################################################

	print CGI::end_form();	
	return "";
}

##############################################################################
# Utility methods
##############################################################################
sub submission_error {
	my $self = shift;
    my $msg = join( " ", @_);
	$self->{submitError} .= CGI::br().$msg; 
    return;
}

sub saveProblem {     
    my $self      = shift;
	my ($body, $probFileName)= @_;
	local(*PROBLEM);
	open (PROBLEM, ">$probFileName") ||
		$self->submission_error("Could not open $probFileName for writing.
		Check that the  permissions for this problem are 660 (-rw-rw----)");
	print PROBLEM $body;
	close PROBLEM;
	chmod 0660, "$probFileName" ||
	             $self->submission_error("
	                    CAN'T CHANGE PERMISSIONS ON FILE $probFileName");
}

sub read_input_file {
	my $self         = shift;
	my $filePath     = shift;
	my ($text, @text);
	my $header = '';
	my ($subject, $from, $replyTo);
	local(*FILE);
	if (-e "$filePath" and -r "$filePath") {
		open FILE, "$filePath" || do { $self->submission_error("Can't open $filePath"); return};
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
		$subject        = "FIXME default subject";
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
	my $text          = defined($self->{r_text}) ? ${ $self->{r_text} }:
	                        'FIXME no text was produced by initialization!!';	
	my $merge_file      = ( defined($self->{merge_file}) ) ? $self->{merge_file} : 'None';  
	#user macros that can be used in the email message
	my $SID           = $ur->student_id;
	my $FN            = $ur->first_name;
	my $LN            = $ur->last_name;
	my $SECTION       = $ur->section;
	my $RECITATION    = $ur->recitation;
	my $STATUS        = $ur->status;
	my $EMAIL         = $ur->email_address;
	my $LOGIN         = $ur->user_id;
	
	# get record from merge file
	# FIXME this is inefficient.  The info should be cached
	my @COL            = defined($rh_merge_data->{$SID}) ? @{$rh_merge_data->{$SID} } : ();
	if ($merge_file ne 'None' && not defined($rh_merge_data->{$SID})  ) {
		$self->submission_error( "No merge data for $SID $FN $LN $LOGIN");
	}
	
	my $endCol = @COL;
	# for safety, only evaluate special variables
 	my $msg = $text;    
 	$msg =~ s/(\$SID)/eval($1)/ge;
 	$msg =~ s/(\$LN)/eval($1)/ge;
 	$msg =~ s/(\$FN)/eval($1)/ge;
 	$msg =~ s/(\$STATUS)/eval($1)/ge;
 	$msg =~ s/(\$SECTION)/eval($1)/ge;
 	$msg =~ s/(\$RECITATION)/eval($1)/ge;
 	$msg =~ s/(\$EMAIL)/eval($1)/ge;
 	$msg =~ s/(\$LOGIN)/eval($1)/ge;
 	$msg =~ s/\$COL\[ *-/\$COL\[$endCol-/g;
 	$msg =~ s/(\$COL\[.*?\])/eval($1)/ge if defined($COL[0]);  # prevents extraneous error messages.   
 	
 	
 	$msg =~ s/\r//g;

	my $preview_header = 	CGI::pre("",data_format(0..($#COL)),"<br>", data_format2(@COL)).
		                    CGI::h3( "This sample mail would be sent to $EMAIL");


	return $msg, $preview_header;
}


# Ê sub data_format {
# 
# Ê Ê Ê Ê Êmap {$_ =~s/\s/\./g;$_} Ê Ê map {sprintf('%-8.8s',$_);} Ê@_;
 sub data_format {
 	    map {"COL[$_]".'&nbsp;'x(3-length($_));}  @_;  # problems if $_ has length bigger than 4
 }
  sub data_format2 {
    map {$_ =~s/\s/&nbsp;/g;$_}  map {sprintf('%-8.8s',$_);} @_;
 }
1;
