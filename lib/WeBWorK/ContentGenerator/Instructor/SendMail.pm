package WeBWorK::ContentGenerator::Instructor::SendMail;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SendMail - Entry point for User-specific data editing

=cut

use strict;
use warnings;
use CGI qw();
use HTML::Entities;

sub initialize {
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $user = $r->param('user');

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
		$input_file = $default_msg_file;
	}
	$self->{input_file}=$input_file;

#################################################################
# Determine the file name to save message into
#################################################################
	my $output_file      = '';	
	if (defined($action) and $action eq 'Save as Default') {
		$output_file  = $default_msg_file;
	} elsif ( defined($savefilename) ){
		$output_file  = $savefilename;
	} elsif ( defined($input_file) ) {
		$output_file  = $input_file;
	}
	
	#################################################################
	# Sanity check on save file name
	#################################################################

	if ($output_file =~ /^[~.]/ || $output_file =~ /\.\./) {
		$self->submission_error("For security reasons, you cannot specify a merge file from a directory 
		higher than the email directory (you can't use ../blah/blah).  
		Please specify a different file or move the needed file to the email directory");
	}
	
	$self->{output_file} = $output_file;
    # FIXME $output_file can be blank if there was no savefilename

#############################################################################################
# Determine input source
#############################################################################################
	my $input_source =  ( defined( $r->param('body') ) and $action ne 'Open' ) ? 'form' : 'file';
#	warn "FIXME input source is $input_source from $input_file";
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


#############################################################################################
# if no form is submitted, gather data needed to produce the mail form and return
#############################################################################################

	if(not defined($action) or $action eq 'Open' or $action eq 'Resize message window' ){  
#		warn "FIXME action is |$action| no further initialization required";
		return '';
	}

	

	

#############################################################################################
# If form is submitted deal with filled out forms 
# and various actions resulting from different buttons
#############################################################################################

	
	my $to                =    $r->param('To');
	
	
		
	###################################################################################
	#Determine the appropriate script action from the buttons
	###################################################################################
	#     save actions
	#		"save" button
	#		"save as" button
	#		"save as default" button
	#     preview actions
	#		'preview' button
	#     email actions
	#		'entire class'
	#		'selected studentIDs'
	#     option actions
	#       'reset rows'
	#     error actions (various)
	
	my $script_action = '';
	# user_errors
	# save
	# save as
	# save as default
	# send mail
	# set defaults

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
			$self->submission_error("The file $emailDirectory/$output_file already exists and cannot be overwritten");
			return;	
		}
 
		#################################################################
	    # Back up existing file?
	    #################################################################
	    if ($action eq 'Save as Default') {
	    	warn "FIXME backup existing default file";
	    }
	    #################################################################
	    # Save the message
		#################################################################
		$self->saveProblem($temp_body, "${emailDirectory}/$output_file" );
		$self->{message}         = "Message saved to file ${emailDirectory}/$output_file";
#		warn "FIXME saving to ${emailDirectory}/$output_file";
	} elsif ($action eq 'preview') {
	
	
	} elsif ($action eq 'Send Email') {
	
	
	
	
	} else {
		warn "Don't recognize button $action";
	}

	#if Save button was clicked
	if (( $r->param('action') eq 'Save') && defined($r->param('body')) && defined($r->param('savefilename'))) {

# 		my $temp_body = $body;
# 		$temp_body =~ s/\r\n/\n/g;
# 		$temp_body = "From: " . $from . "\n" .
# 				   "Reply-To: " . $replyTo . "\n" .
# 				   "Subject: " . $subject . "\n" .
# 				   "Message: \n" . $temp_body;
# 
# 		saveProblem($temp_body, $savefilename);
# 		$messageFileName = $savefilename;

	#if Save As button was clicked
	} elsif (( $r->param('action') eq 'Save as:') && defined($r->param('body')) && defined($r->param('savefilename'))) {

# 		$messageFileName = $savefilename;
# 
# 		if ($messageFileName =~ /^[~.]/ || $messageFileName =~ /\.\./) {
# 			$self->submission_error("For security reasons, you cannot specify a merge file from a directory higher than the email directory (you can't use ../blah/blah).  Please specify a different file or move the needed file to the email directory");
# 		}
# 
# 
# 		my $temp_body = $body;
# 		$temp_body =~ s/\r\n/\n/g;
# 		$temp_body = join("",
# 				   "From: $from \nReply-To: $replyTo)\n" ,
# 				   "Subject: $subject\n" ,
# 				   "Message: \n    $temp_body");
# 
# 		saveNewProblem($temp_body, $messageFileName);

	#if Save As Default button was clicked
	} elsif (( $r->param('action') eq 'save_as_default') && defined($r->param('body'))) {

# 		my $temp_body;
# 		$temp_body = $r->param('body');
# 		$temp_body =~ s/\r\n/\n/g;
# 
# 		#get default.msg and back it up in default.old.msg
# 		open DEFAULT, "$emailDirectory/$default_msg_file";
# 			$temp_body = <DEFAULT>;
# 		close DEFAULT;
# 
# 		if ( -e "$emailDirectory/$old_default_msg_file") {
# #				saveProblem($temp_body, $old_default_msg_file);
# 		} else {
# #				saveNewProblem($temp_body, $old_default_msg_file);
# 		}
# 
# 		#save new default message as default.msg
# 		$temp_body = $body;
# 		$temp_body =~ s/\r\n/\n/g;
# 		$temp_body = join("",
# 				   "From: $from \nReply-To: $replyTo)\n" ,
# 				   "Subject: $subject\n" ,
# 				   "Message: \n    $temp_body");
# 
# #			saveProblem($temp_body, $default_msg_file);
# 		$messageFileName = $default_msg_file;

	#if Send Email button was clicked
	} elsif ( $r->param('action') eq 'Send Email' ) {

		my @studentID = ();

		if ($r->param('To') eq 'classList' && defined($r->param('classList')) && $r->param('classList') ne 'None') {
# 				my $classlist = $r->param('classList');
# 				my $classListFile = "$templateDirectory$classlist";
# 				my @classList = ();
# 				#FIXME checkClasslistFile($Global::noOfFieldsInClasslist,$classListFile);
# 				open(FILE, "$classListFile") || die "can't open $classListFile";
# 				@classList=<FILE>;
# 				close(FILE);
# 
# 				foreach (@classList)   {                        ## read through classlist and send e-mail
#                                                        ## message to all active students
#     				unless ($_ =~ /\S/)  {next;}                    ## skip blank lines
#     				chomp;
#     				my @classListRecord=&getRecord($_);
#     				my ($studentID, $lastName, $firstName, $status, $comment,  $section, $recitation, $email_address, $login_name)
#        				  = @classListRecord;
#     				unless (&dropStatus($status)) {
#     					push (@studentID, $studentID);
#     					$fn{$studentID} = $firstName;
# 						$ln{$studentID} = $lastName;
# 						$section{$studentID} = $section;
# 						$recitation{$studentID} = $recitation;
# 						$status{$studentID} = $status;
# 						$email{$studentID} = $email_address;
# 						$login{$studentID} = $login_name;
#     				}
# 				}
		} 	elsif ($r->param('To') eq 'studentID' && defined($r->param('studentID'))) {
			@studentID = $r->param('studentID');
			my ($studentID, $login_name);
# 
# 				foreach $studentID (@studentID) {
# 					$login_name = $studentID_LoginName_Hash{$studentID};
# 					&attachCLRecord($login_name);
# 					$fn{$studentID}			= CL_getStudentFirstName($login_name);
# 					$ln{$studentID}			= CL_getStudentLastName($login_name);
# 					$section{$studentID}	= CL_getClassSection($login_name);
# 					$recitation{$studentID}	= CL_getClassRecitation($login_name);
# 					$status{$studentID} 	= CL_getStudentStatus($login_name);
# 					$email{$studentID}		= CL_getStudentEmailAddress($login_name);
# 					$login{$studentID} 		= $login_name;
# 				}

		} elsif ($r->param('To') eq 'all_students') {
			@studentID = ();
			my ($studentID, $login_name, $status);

# 				foreach $login_name (@availableStudents) {
# 					&attachCLRecord($login_name);
# 					$status 		= CL_getStudentStatus($login_name);
# 					next if &dropStatus($status);
# 					$studentID		= CL_getStudentID($login_name);
# 					push(@studentID,$studentID);
# 
# 					$fn{$studentID}			= CL_getStudentFirstName($login_name);
# 					$ln{$studentID}			= CL_getStudentLastName($login_name);
# 					$section{$studentID}	= CL_getClassSection($login_name);
# 					$recitation{$studentID}	= CL_getClassRecitation($login_name);
# 					$status{$studentID} 	= CL_getStudentStatus($login_name);
# 					$email{$studentID}		= CL_getStudentEmailAddress($login_name);
# 					$login{$studentID} 		= $login_name;
# 				}
		} else {
			$self->submission_error('You didn\'t select any recipients.  Make sure you select either all student in the course, individual students or a whole classlist.');
		}

		my $mergeFile = '';

		#the radio button named 'merge' determines whether to take the selected mergefile
		#or one that was typed in.  A error message is given if select one and use the other
		$mergeFile = $scoringDirectory . $r->param('mergeFiles')
			if ($r->param('merge') eq 'mergeFiles' && defined($r->param('mergeFiles')) && $r->param('mergeFiles') ne 'None');

		$mergeFile = $templateDirectory . $r->param('mergeFile')
			if ($r->param('merge') eq 'mergeFile' && defined($r->param('mergeFile')) && $r->param('mergeFile') !~ m|/$|); #does not end in a /

		if ($mergeFile =~ /^[~.]/ || $mergeFile =~ /\.\./) {
			$self->submission_error("For security reasons, you cannot specify a merge file from a directory higher than the email directory.  Please specify a different file or move the needed file to the email directory");
		}
		if ($r->param('body') =~ /(\$COL\[.*?\])/ && !(-e $mergeFile)) {
			$self->submission_error("In order to use the \$COL[] you must specify a merge file. The file you specified does not exist.  Also, make sure you selected the right checkbox.");
		}


		my %mergeAArray = ();
# 			unless ($mergeFile eq '') {%mergeAArray = &delim2aa($mergeFile);}
# 			

# 			
# 			foreach  my $studentID (@studentID) {
# 				@COL =();
# 				$SID = $studentID;
# 				$LN = defined $ln{$studentID} ? $ln{$studentID} :'';
# 				$FN = defined $fn{$studentID} ? $fn{$studentID} :'';
# 				$SECTION = defined $section{$studentID} ? $section{$studentID} :'';
# 				$RECITATION = defined $recitation{$studentID} ? $recitation{$studentID} :'';
# 				$EMAIL = defined $email{$studentID} ? $email{$studentID} :'';
# 				$STATUS =defined $status{$studentID} ?  $status{$studentID} :'';
# 				$LOGIN = $login{$studentID};
# 				
# 				next if ($LOGIN =~ /^$practiceUser/); ## skip practice users
# 				
# 				if ($timeout_attempts >= $max_timeout_attempts) {  	## have attemped to connect to smtp server
# 																	## the max allowed times.  Now just collect
# 																	## data on emails not sent and exit
# 					++$emails_not_sent;
# 					&log_error(\@exceeded_max_timeout,$FN,$LN,$EMAIL);
# 					next;
# 				}				
# 					
# 				unless ((defined $mergeAArray{$studentID}) or ($mergeFile eq '')) {
# 					if ($cgi->param('no_record')) {
# 						++$emails_not_sent;
# 						&log_error(\@no_record,$FN,$LN,$EMAIL);
# 						next;
# 					}
# 				}

# 				my ($dbString, @dbArray);
# 				if (defined $mergeAArray{$SID}) {
# 					$dbString = $mergeAArray{$SID};	## get sid record from merge file
# 					@dbArray = &getRecord($dbString);
# 					unshift(@dbArray,$SID);
# 					unshift(@dbArray,"");			## note COL[1] is the first column
# 					@COL= @dbArray;				## put merge fields in COL array
# 					$endCol = @COL;				## \endCol-1 gives last field, etc
# 				}
# 				my $smtp;
# 				if ($smtp = Net::SMTP->new($Global::smtpServer, Timeout => $timeout_sec)) {} else {
# #					&internal_error("Couldn't contact SMTP server.");						
# 					++$emails_not_sent;
# 					&log_error(\@timeout_problem,$FN,$LN,$EMAIL);
# 					++$timeout_attempts;
# 					next;
# 				}
# 					
# 				$smtp->mail($smtpSender);
# 
# 				if ( $smtp->recipient($EMAIL)) {  # this one's okay, keep going
# 					if ( $smtp->data("To: $EMAIL\n" . output() ) ) {
# 						++$emails_sent;
# 					} else {	
# 						++$emails_not_sent;
# 						&log_error(\@unknown_problem,$FN,$LN,$EMAIL);
# 						next;
# 					}
# #					&internal_error("Unknown problem sending message data to SMTP server.");
# 				} else {			# we have a problem with this address
# 					$smtp->reset;
# 					#&internal_error("SMTP server doesn't like this address: <$EMAIL>.");
# 					++$emails_not_sent;
# 					&log_error(\@bad_email_addresses,$FN,$LN,$EMAIL);
# 				}
# 				$smtp->quit;
# 			}
# 			&success;
 		}




}  #end initialize

sub fieldEditHTML {
	my ($self, $fieldName, $value, $properties) = @_;
	my $size = $properties->{size};
	my $type = $properties->{type};
	my $access = $properties->{access};
	my $items = $properties->{items};
	my $synonyms = $properties->{synonyms};
	
	
	if ($access eq "readonly") {
		return $value;
	}
	if ($type eq "number" or $type eq "text") {
		return CGI::input({type=>"text", name=>$fieldName, value=>$value, size=>$size});
	}
	if ($type eq "enumerable") {
		my $matched = undef; # Whether a synonym match has occurred

		# Process synonyms for enumerable objects
		foreach my $synonym (keys %$synonyms) {
			if ($synonym ne "*" and $value =~ m/$synonym/) {
				$value = $synonyms->{$synonym};
				$matched = 1;
			}
		}
		if (!$matched and exists $synonyms->{"*"}) {
			$value = $synonyms->{"*"};
		}
		return CGI::popup_menu({
			name => $fieldName, 
			values => [keys %$items],
			default => $value,
			labels => $items,
		});
	}
}

sub title {
	my $self = shift;
	return 'Send mail to ' .$self->{ce}->{courseName};
}

sub path {
	my $self          = shift;
	my $args          = $_[-1];
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home"          => "$root",
		$courseName     => "$root/$courseName",
		'instructor'    => "$root/$courseName/instructor",
		"Send Mail to: $courseName"      => '',
	);
}

sub body {
	my ($self, $setID) = @_;
	my $r = $self->{r};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};

        return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");

	my $userTemplate = $db->newUser;
	my $permissionLevelTemplate = $db->newPermissionLevel;
	
	# This code will require changing if the permission and user tables ever have different keys.
	my @users = $db->listUsers;

	# This table can be consulted when display-ready forms of field names are needed.
# 	my %prettyFieldNames = map {$_ => $_} ($userTemplate->FIELDS(), $permissionLevelTemplate->FIELDS());
# 	@prettyFieldNames{qw(
# 		user_id 
# 		first_name 
# 		last_name 
# 		email_address 
# 		student_id 
# 		status 
# 		section 
# 		recitation 
# 		comment 
# 		permission
# 	)} = (
# 		"User ID", 
# 		"First Name", 
# 		"Last Name", 
# 		"E-mail", 
# 		"Student ID", 
# 		"Status", 
# 		"Section", 
# 		"Recitation", 
# 		"Comment", 
# 		"Perm. Level"
# 	);

# 	my %fieldProperties = (
# 		user_id => {
# 			type => "text",
# 			size => 8,
# 			access => "readonly",
# 		},
# 		first_name => {
# 			type => "text",
# 			size => 10,
# 			access => "readwrite",
# 		},
# 		last_name => {
# 			type => "text",
# 			size => 10,
# 			access => "readwrite",
# 		},
# 		email_address => {
# 			type => "text",
# 			size => 20,
# 			access => "readwrite",
# 		},
# 		student_id => {
# 			type => "text",
# 			size => 11,
# 			access => "readwrite",
# 		},
# 		status => {
# 			type => "enumerable",
# 			size => 4,
# 			access => "readwrite",
# 			items => {
# 				"C" => "Enrolled",
# 				"D" => "Drop",
# 				"A" => "Audit",
# 			},
# 			synonyms => {
# 				qr/^[ce]/i => "C",
# 				qr/^[dw]/i => "D",
# 				qr/^a/i => "A",
# 				"*" => "C",
# 			}
# 		},
# 		section => {
# 			type => "text",
# 			size => 4,
# 			access => "readwrite",
# 		},
# 		recitation => {
# 			type => "text",
# 			size => 4,
# 			access => "readwrite",
# 		},
# 		comment => {
# 			type => "text",
# 			size => 20,
# 			access => "readwrite",
# 		},
# 		permission => {
# 			type => "number",
# 			size => 2,
# 			access => "readwrite",
# 		}
# 	);
	
	
	
##############################################################################################################
	
#	my ($ar_sortedNames, $hr_classlistLabels) = getClasslistFilesAndLabels($course);
#	my @sortedNames = @$ar_sortedNames;
	my %classlistLabels = ();#  %$hr_classlistLabels;
	unshift(@users, "Yourself");
	$classlistLabels{None} = 'Yourself';
	my $from            = $self->{from};
	my $subject         = $self->{subject};
	my $replyTo         = $self->{replyTo};
	my $columns         = $self->{columns};
	my $rows            = $self->{rows};
	my $text            = defined($self->{r_text}) ? ${ $self->{r_text} }: 'FIXME no text was produced by initialization!!';
	my $input_file      = $self->{input_file};
	my $output_file     = $self->{output_file};
	
    CGI::popup_menu(-name=>'classList',
						   -values=>\@users,
						   -labels=>\%classlistLabels,
						   -size  => 10,
						   -multiple => 1,
						   -default=>'Yourself'
	);
	print CGI::start_form({method=>"post", action=>$r->uri()});
#create list of sudents
# show professors's name and email address
# show replyTo field and From field
    print CGI::start_table({-border=>'2', -cellpadding=>'4'});
	print CGI::Tr({-align=>'left',-valign=>'VCENTER'},
			 CGI::td("Input file: $input_file","\n",CGI::br(),
				 CGI::submit(-name=>'action', -value=>'open',-label=>'Open'), "\n",
				 CGI::textfield(-name=>'openfilename', -size => 20, -value=> "$input_file", -override=>1), "\n",CGI::br(),
				 "Output file: $output_file","\n",CGI::br(),
				 "\n", 'From:','&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;',  CGI::textfield(-name=>"from", -size=>30, -value=>$from, -override=>1),    
				 "\n", CGI::br(),'Reply-To: ', CGI::textfield(-name=>"replyTo", -size=>30, -value=>$replyTo, -override=>1), 
				 "\n", CGI::br(),'Subject:  ', CGI::br(), CGI::textarea(-name=>'subject', -default=>$subject, -rows=>3,-columns=>40, -override=>1),  
			),
			CGI::td({-align=>'left'},
				CGI::radio_group(-name=>'radio', -values=>['all_students','studentID'],
					-labels=>{all_students=>'All active students',studentID => 'Select recipients'},
					-default=>'studentID',
					-linebreak=>1),
					CGI::br(),
					CGI::popup_menu(-name=>'classList',
							   -values=>\@users,
							   -labels=>\%classlistLabels,
							   -size  => 10,
							   -multiple => 1,
							   -default=>'Yourself'
					),
					
				
			),
			CGI::td({align=>'left'},
				CGI::submit(-name=>'preview', -value=>'preview',-label=>'Preview')," email to ",
				CGI::popup_menu(-name=>'classList',
							   -values=>\@users,
							   -labels=>\%classlistLabels,
							   -default=>'Yourself'
				),
				CGI::br(),CGI::br(),
				CGI::submit(-name=>'action', -value=>'resize', -label=>'Resize message window'),CGI::br(),
				" Rows: ", CGI::textfield(-name=>'rows', -size=>3, -value=>$rows),
				" Columns: ", CGI::textfield(-name=>'columns', -size=>3, -value=>$columns),
				CGI::br(),CGI::br(),
			#show available macros
				CGI::popup_menu(
						-name=>'dummyName',
						-values=>['', '$SID', '$FN', '$LN', '$SECTION', '$RECITATION','$STATUS', '$EMAIL', '$LOGIN', '$COL[3]', '$COL[-1]'],
						-labels=>{''=>'list of insertable macros',
							'$SID'=>'$SID - Student ID',
							'$FN'=>'$FN - First name',
							'$LN'=>'$LN - Last name',
							'$SECTION'=>'$SECTION - Student\'s Section',
							'$RECITATION'=>'$RECITATION',
							'$STATUS'=>'$STATUS - C, Audit, Drop, etc.',
							'$EMAIL'=>'$EMAIL - Email address',
							'$LOGIN'=>'$LOGIN - Login',
							'$COL[3]'=>'$COL[3] - 3rd column in merge file',
							'$COL[-1]'=>'$COL[-1] - Last column'
							}
				), "\n",
			),

	); # end Tr
	print CGI::end_table();	 
#create a textbox with the subject and a textarea with the message

#print actual body of message

	print  "\n", CGI::p( $self->{message}) if defined($self->{message});  
    print  "\n", CGI::p( CGI::textarea(-name=>'body', -default=>$text, -rows=>$rows, -columns=>$columns, -override=>1));
    
#create all necessary action buttons
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

	print $self->hidden_authen_fields();
#	print CGI::submit({name=>"save_classlist", value=>"Save Changes to Users"});
	print CGI::end_form();	
	return "";
}

##############################################################################
# Utility methods
##############################################################################
sub submission_error {
	my $self = shift;
    my $msg = join " ", @_;
# 	$cgi->start_html('-title' => 'User error'),
# 	$cgi->h1('User error'),
# 	$cgi->p,
# 	$cgi->b(HTML::Entities::encode($msg)),
# 	$cgi->p,
#         "Please hit the &quot;<B>Back</B>&quot; button on your browser to ",
# 	"try again, or notify ", $cgi->br,
# 	"&lt;", $cgi->a({href=>"mailto:$Global::webmaster"}, $Global::webmaster), "&gt; ",
# 	"if you believe this message is in error.",
# 	$cgi->end_html;
	$self->{submitError}= CGI::b(HTML::Entities::encode($msg)).CGI::br().
		qq{Please hit the &quot;<B>Back</B>&quot; button on your browser to 
		try again, or notify your web master
		if you believe this message is in error.
		};
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
	if (-e "$filePath") {
		open FILE, "$filePath" || $self->submission_error("Can't open $filePath");
		while ($header !~ s/Message:\s*$//m) { 
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
		$text           =  "FIXME file $filePath doesn't exist";
		$subject        = "FIXME default subject";
	}
	return ($from, $replyTo, $subject, \$text);
}
1;
