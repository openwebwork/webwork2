#!/usr/bin/perl -w

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/clients/renderProblem.pl,v 1.4 2010/05/11 15:44:05 gage Exp $
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

=head1 NAME

webwork2/clients/sendXMLRPC.pl

=head1 DESCRIPTION

This script will take a list of files or directories
and send it to a WeBWorK daemon webservice
to have it rendered.  For directories each .pg file under that 
directory is rendered. 

The results can be displayed in a browser (use -b or -B switches) as was
done with renderProblem.pl, on the command line (Use -h or -H switches) as
was done with renderProblem_rawoutput.pl or summary information about whether the 
problem was correctly rendered can be sent to a log file (use -c or C switches).

The capital letter switches, -B, -H, and -C render the question twice.  The first
time returns an answer hash which contains the correct answers. The question is
then resubmitted to the renderer with the correct answers filled in and displayed.  

IMPORTANT: Create a valid credentials file.

=cut

=head1    SYNOPSIS

	sendXMLRPC -vcCbB input.pg 

=head1   DETAILS

=head2 credentials file
    
    These locations are searched, in order,  for the credentials file.
    ("$ENV{HOME}/.ww_credentials", "$ENV{HOME}/ww_session_credentials", 'ww_credentials', 'ww_credentials.dist')
    
    Place a credential file containing the following information at one of the locations above 
    or create a file with this information and specify it with the --credentials option.
    
    	%credentials = (
    			userID                 => "my login name for the webwork course",
    			course_password        => "my password ",
    			courseID               => "the name of the webwork course",
                site_url	           => "url of rendering site
                site_password          => "site password" # preliminary access to site
                form_action_url        =>  'http://localhost:80/webwork2/html2xml'; #action url for form
                ww_display_mode        =>  'MathJax', # optional 
                                          # --  'MathJax' and 'images' are the possible values           
                html_display_command   =>  "open -a 'Google Chrome' "  # optional
                                                      # for Mac: have Chrome read html output file
                                                      # modify this for other platforms or browsers  
    	);

=cut

=head2 Options

=over 4

=item  -a  

	Displays the answer hashes returned by the question on the command line.

=item  -A  

	Same as -a but renders the question with the correct answers submitted.

=item  -b  

	Display the rendered question in a browser (specified by the DISPLAY_HTML_COMMAND variable).

=item  -B  

	Same as -b but renders the question with the correct answers submitted. 
	The evaluation of the answer submitted is displayed as well as the correct
	answer. 

=item  -h  

	Prints to STDOUT the entire object returned by 
    the webwork_client xmlrpc request.
    This includes the answer information displayed by -a and -A and much more.

=item  -H  

	Same as -h but renders the question with the correct answers submitted

=item	-c 

	"check" -- Record success or failure of rendering the question to a log file. 

=item	-C 

	Same as -c but the question is rendered with the correct answers submitted. 
    This succeeds only if the correct answers, as determined from the answer hash, all succeed.

=item	 f=s 

	Specify the format used by the browser in displaying the question. 
         Choices for s are
         standard
         sticky
         debug 
         simple
         

=item	-v 

	Verbose output. Used mostly for debugging. 
    In particular it displays explicitly the correct answers 
    which are (will be)  submitted to the question.
    
=item   -e
	Open the source file in an editor. 
	
=item   

	The single letter options can be "bundled" e.g.  -vcCbB
	
=item  --list   pg_list
	Read and process a list of .pg files contained in the file C<pg_list>.  C<pg_list>
	consists of a sequence of lines each of which contains the full path to a pg
	file that should be processed. (For example this might be the output from an
	earlier run of sendXMLRPC using the -c flag. )

=item	--pg 

	Triggers the printing of the all of the variables available to the PG question. 
    The table appears within the question content. Use in conjunction with -b or -B.

=item	--anshash 

	Prints the answer hash for each answer in the PG_debug output which appears below
    the question content. Use in conjunction with -b or -B. 
    Similar to -a or -A but the output appears in the browser and 
    not on the command line. 

=item	--ansgrp  	

	Prints the PGanswergroup for each answer evaluator. The information appears in 
    the PG_debug output which follows the question content.  Use in conjunction with -b or -B.
    This contains more information than printing the answer hash. (perhaps too much). 

=item	--credentials=s

 	Specifies a file s where the  credential information can be found.

=item	--help

       Prints help information. 
       
=item  --log 
       Sets path to log file

=back
=cut

use strict;
use warnings;


#######################################################
# Find the webwork2 root directory
#######################################################
BEGIN {
        die "WEBWORK_ROOT not found in environment. \n
             WEBWORK_ROOT can be defined in your .cshrc or .bashrc file\n
             It should be set to the webwork2 directory (e.g. /opt/webwork/webwork2)"
                unless exists $ENV{WEBWORK_ROOT};
	# Unused variable, but define it twice to avoid an error message.
	$WeBWorK::Constants::WEBWORK_DIRECTORY = $ENV{WEBWORK_ROOT};
	$WeBWorK::Constants::PG_DIRECTORY      = "$ENV{WEBWORK_ROOT}/../pg/";
	unless (-r $WeBWorK::Constants::WEBWORK_DIRECTORY ) {
		die "Cannot read webwork root directory at $WeBWorK::Constants::WEBWORK_DIRECTORY";
	}
	unless (-r $WeBWorK::Constants::PG_DIRECTORY ) {
		die "Cannot read webwork pg directory at $WeBWorK::Constants::PG_DIRECTORY";
	}
}

use lib "$WeBWorK::Constants::WEBWORK_DIRECTORY/lib";
use lib "$WeBWorK::Constants::PG_DIRECTORY/lib";
use Crypt::SSLeay;  # needed for https
use WebworkClient;
use Time::HiRes qw/time/;
use MIME::Base64 qw( encode_base64 decode_base64);
use Getopt::Long qw[:config no_ignore_case bundling];
use File::Find;
use FileHandle;
use Cwd 'abs_path';

#############################################
# Configure displays for local operating system
#############################################

### verbose output when UNIT_TESTS_ON =1;
 our $UNIT_TESTS_ON             = 0;
  
#Default display commands.
use constant  HTML_DISPLAY_COMMAND  => "open -a 'Google Chrome' "; # (MacOS command)
#use constant  HASH_DISPLAY_COMMAND => "";   # display tempoutputfile to STDOUT

### Path to a temporary file for storing the output of renderProblem.pl
 use constant  TEMPOUTPUTDIR   => "$ENV{WEBWORK_ROOT}/DATA/"; 
 die "You must make the directory ".TEMPOUTPUTDIR().
     " writeable " unless -w TEMPOUTPUTDIR();
 use constant TEMPOUTPUTFILE  => TEMPOUTPUTDIR()."temporary_output.html";
    
### Default path to a temporary file for storing the output of sendXMLRPC.pl
use constant LOG_FILE => "$ENV{WEBWORK_ROOT}/DATA/xmlrpc_results.log";

### set display mode
use constant DISPLAYMODE   => 'MathJax'; 
use constant PROBLEMSEED   => '987654321'; 

############################################################
# End configure
############################################################
 
############################################################
# Read command line options
############################################################

my $display_ans_output1 = '';
my $display_hash_output1 = '';
my $display_html_output1 = '';
my $record_ok1 = '';  # subroutine needs to be constructed
my $display_ans_output2 = '';
my $display_hash_output2 = '';
my $display_html_output2 = '';
my $record_ok2 = '';
my $verbose = '';
my $credentials_path;
my $format = 'standard';
my $edit_source_file = '';
my $print_answer_hash;
my $print_answer_group;
my $print_pg_hash;
my $print_help_message;
my $read_list_from_this_file;
my $path_to_log_file;
GetOptions(
	'a' => \$display_ans_output1,
	'A' => \$display_ans_output2,
	'b' => \$display_html_output1,
	'B' => \$display_html_output2,
	'h' => \$display_hash_output1,
	'H' => \$display_hash_output2,
	'c' => \$record_ok1, # record_problem_ok1 needs to be written
	'C' => \$record_ok2,
	'v' => \$verbose,
	'e' => \$edit_source_file, 
	'list=s' =>\$read_list_from_this_file,   # read file containing list of full file paths
	'pg' 			=> \$print_pg_hash,
	'anshash' 		=> \$print_answer_hash,
	'ansgrp'  		=> \$print_answer_group,
	'f=s' 			=> \$format,
	'credentials=s' => \$credentials_path,
	'help'          => \$print_help_message,
	'log=s'         => \$path_to_log_file,
);


print_help_message() if $print_help_message;


####################################################
# get credentials
####################################################

# credentials file location -- search for one of these files 

our @path_list = ("$ENV{HOME}/.ww_credentials", "$ENV{HOME}/ww_session_credentials", 'ww_credentials', 'ww_credentials.dist');

my $credentials_string = <<EOF;
The credentials file should contain this:
	%credentials = (
			userID              => "my login name for the webwork course",
			course_password     => "my password ",
			courseID            => "the name of the webwork course",
            site_url	        => "url of rendering site",
            site_password       => "site password", # preliminary access to site
            form_action_url     =>  'http://localhost:80/webwork2/html2xml', #action url for form
            ww_display_mode       =>  'MathJax', # optional 
                                               # --  'MathJax' and 'images' are the possible values
            html_display_command  =>  "open -a 'Google Chrome' "  # optional
                                                      # for Mac: have Chrome read html output file
                                                      # modify this for other platforms or browsers
	);
1;
EOF

foreach my $path ($credentials_path, @path_list) { # look in specified credentials first
	next unless defined $path;
	if (-r $path ) {
		$credentials_path = $path;
		last;
	}
}
if  ( $credentials_path ) { 
	print "Credentials taken from file $credentials_path\n" if $verbose;
} else {
	die <<EOF;
Can't find path for credentials. Looked in @path_list.
$credentials_string
---------------------------------------------------------
EOF
}  

our %credentials;
eval{require $credentials_path};
if ($@  or not  %credentials) {
	foreach my $key (qw(userID courseID course_password XML_URL XML_PASSWORD FORM_ACTION_URL)) {
		print STDERR "$key is missing from ".
		             "\%credentials at $credentials_path\n" unless $credentials{$key};
	}
	print STDERR $credentials_string;
	die;
}

if ($verbose) {
	foreach (keys %credentials){print "$_ =>$credentials{$_} \n";} 
}

#allow credentials to overrride the default displayMode and the browser display
our $HTML_DISPLAY_COMMAND = $credentials{html_display_command}//HTML_DISPLAY_COMMAND();
#our $HASH_DISPLAY_COMMAND = $credentials{hashdisplayCommand}//HASH_DISPLAY_COMMAND();

our $DISPLAYMODE          = $credentials{ww_display_mode}//DISPLAYMODE();
$path_to_log_file         = $path_to_log_file //$credentials{path_to_log_file}//LOG_FILE();  #set log file path.

eval { # attempt to create log file
	local(*FH);
	open(FH, '>>',$path_to_log_file) or die "Can't open file $path_to_log_file for writing";
	close(FH);	
};
die "You must first create an output file at $path_to_log_file
     with permissions 777 " unless -w $path_to_log_file;

##################################################
#  END gathering credentials for client
##################################################

############################################
# Build  client defaults
############################################
 
my $default_input = { 
		userID      			=> $credentials{userID}//'',
		session_key	 			=> $credentials{session_key}//'',
		courseID   				=> $credentials{courseID}//'',
		courseName   			=> $credentials{courseID}//'',
		course_password     	=> $credentials{course_password}//'',
 };

my $default_form_data = { 
		displayMode				=> $DISPLAYMODE,
		outputformat 			=> $format,
};

##################################################
#  end build client
##################################################

##################################################
#  MAIN SECTION gather and process problem template files
##################################################

our @files_and_directories = @ARGV;
# print "files ", join("|", @files_and_directories), "\n";
if ($read_list_from_this_file) { 
    # read a datafile containing list of files to be processed
	my $FH = FileHandle->new(" < $read_list_from_this_file");
	while (<$FH>) {
		my $item = $_;
		chomp($item);
		my $file_path = abs_path($item);
		unless (defined $file_path and -f $file_path) {
			warn "skipping $item\n" unless defined $file_path;
			warn "skipping $file_path\n" if defined $file_path;
			next;
		}
		next if $file_path =~ /^\s*#/;   # comment lines
		next unless $file_path =~ /\.pg$/;
		next if $file_path =~ /\-text\.pg$/;
		next if $file_path =~ /header/i;
		process_pg_file($file_path);
	}
	FileHandle::close($FH);

} else { 
	foreach my $item (@files_and_directories) {
		if (-d $item) {  # if the item is a directory traverse the tree
			my $dir = abs_path($item);
			find(\&wanted, ($dir));
		} elsif (-f $item) { # if the item is a file process it.
			my $file_path = abs_path($item);
			next unless $file_path =~ /\.pg$/;
			next if $file_path =~ /\-text\.pg$/;
			next if $file_path =~ /header/i;
			process_pg_file($file_path);
		} else {
			print "$item cannot be found or read\n";
		}
	}
}
sub wanted {
	return '' unless $File::Find::name =~ /\.pg$/;
	return '' if $File::Find::name =~ /\-text\.pg$/;
	return '' if $File::Find::name =~ /header/i;
	eval{
		process_pg_file($File::Find::name) if -f $File::Find::name;
	};
	warn "Error in processing $File::Find::name: $@" if $@;
}


#######################################################################
# Process the pg file
#######################################################################

sub process_pg_file {
	my $file_path = shift;
	my $NO_ERRORS = "";
	my $ALL_CORRECT = "";
	my $problemSeed1 = 1112;
	my $form_data1 = { %$default_form_data,
					  problemSeed => $problemSeed1};

	my ($error_flag, $xmlrpc_client, $error_string) = 
	    process_problem($file_path, $default_input, $form_data1);
	# extract and display result
		#print "display $file_path\n";
		edit_source_file($file_path) if $edit_source_file;
		display_html_output($file_path, $xmlrpc_client->formatRenderedProblem) if $display_html_output1;
		display_hash_output($file_path, $xmlrpc_client->return_object) if $display_hash_output1;
		display_ans_output($file_path, $xmlrpc_client->return_object) if $display_ans_output1;
		$NO_ERRORS = record_problem_ok1($error_flag, $xmlrpc_client, $file_path) if $record_ok1;      
		
		unless ($display_html_output2 or $display_hash_output2 or $display_ans_output2 or $record_ok2) {
			print "DONE -- $NO_ERRORS -- \n"if $verbose;
			return;
		}
	#################################################################
	# Extract correct answers
	#################################################################

	my %correct_answers = (); 
	my $some_correct_answers_not_specified = 0;
	foreach my $ans_id (keys %{$xmlrpc_client->return_object->{answers}} ) {
		my $ans_obj = $xmlrpc_client->return_object->{answers}->{$ans_id};
		my $answergroup = $xmlrpc_client->return_object->{PG_ANSWERS_HASH}->{$ans_id};
		my @response_order = @{$answergroup->{response}->{response_order}};
		#print scalar(@response_order), " first response $response_order[0] $ans_id\n";
		$ans_obj->{type} = $ans_obj->{type}//'';
		if ($ans_obj->{type} eq 'MultiAnswer') { 
		    # singleResponse multianswer type
		    # an outrageous hack
			print "handling MultiAnswer singleResponse type\n" if $verbose;
			my $ans_str1 = $ans_obj->{correct_ans};
			my @ans_array1 = split(/\s*;\s*/, $ans_str1);
			$correct_answers{$ans_id} = shift @ans_array1;
			my $num_extra_elements = scalar(@ans_array1);
			foreach my $i (1..$num_extra_elements) { # pick up the remaining blanks
				my $response_id = "MuLtIaNsWeR_${ans_id}_${i}"; #MuLtIaNsWeR_AnSwEr0003_1
				$correct_answers{$response_id} = shift @ans_array1;
				#print "\t\t $response_id => $correct_answers{$response_id}\n";
			}
		} elsif ($ans_obj->{type} =~ /checkbox/i) { #type is probably checkbox_cmp 
			my $ans_str = $ans_obj->{correct_ans};  #an unseparated answer string
			$ans_str =~ s/^\s*//;
			$ans_str =~ s/\s*$//;     #trim white space off ends (probably unnecessary)
			my @temp = split("",$ans_str); #split into array of characters
			my $new_ans_str = join("\0", @temp);   # join them in "packed" form separated with nulls
			$correct_answers{$ans_id}=$new_ans_str;
		} elsif (1==@response_order and $ans_id eq $response_order[0] ) { 
		    # only one response -- not MultiAnswer singleResponse
		    # most answers are of this type
		    # should we use correct answer or correct value?  -- this seems to vary
		    #warn "just one answer blank for this answer evaluator";
			$correct_answers{$ans_id}=($ans_obj->{correct_ans})//($ans_obj->{correct_value});
		} else { # more than one response 
			if ($ans_obj->{type} =~ /Matrix/) {  
			    #FIXME -- another outrageous hackkkk but it works
				#print "responding to matrix answer with several ans_blanks\n";
				#print "responses", join(" ", %{$answergroup->{response}->{responses}}),"\n";
				#print "correct answer ", $ans_obj->{correct_value}, "\n";
				my $ans_str = ($ans_obj->{correct_ans})//($ans_obj->{correct_value});
				$ans_str =~ s/\[//g;
				$ans_str =~ s/\]//g;
				my @ans_array = split(/\s*,\s*/, $ans_str);
				foreach my $response_id (@response_order) {
					$correct_answers{$response_id} = shift @ans_array;
				}
			} else {
				warn "responding to an answer evaluator of type |".$ans_obj->{type}. "|  with ".scalar(@response_order)." ans_blanks: ", join(" ",@response_order),"\n";
				$correct_answers{$ans_id}=($ans_obj->{correct_ans})//($ans_obj->{correct_value})//'';
			}
		}
		#FIXME  hack to get rid of html protection of < and > for vectors
		$correct_answers{$ans_id}=~s/&gt;/>/g;
		$correct_answers{$ans_id}=~s/&lt;/</g;
		$correct_answers{$ans_id}=~ s|<br\s*/>||g;  # some answers have breaks in them for clarity
		if ($correct_answers{$ans_id} eq "No correct answer specified" ) {
			warn "this question has an answer blank with no correct answer specified";
			$some_correct_answers_not_specified ++;
		}

	} #end loop collecting correct answers. 
	# adjust input and reinitialize form_data
	my $form_data2 = { %$default_form_data,
				   problemSeed => $problemSeed1,
				   answersSubmitted => 1,
				   WWsubmit         => 1, # grade answers
				   WWcorrectAns          => 1, # show correct answers
				   %correct_answers
				};
	($error_flag, $xmlrpc_client, $error_string)=();
	($error_flag, $xmlrpc_client, $error_string) = 
			process_problem($file_path, $default_input, $form_data2);
	display_html_output($file_path, $xmlrpc_client->formatRenderedProblem) if $display_html_output2;
	display_hash_output($file_path, $xmlrpc_client->return_object) if $display_hash_output2;
	display_ans_output($file_path, $xmlrpc_client->return_object) if $display_ans_output2;
	$ALL_CORRECT = record_problem_ok2($error_flag, $xmlrpc_client, $file_path, $some_correct_answers_not_specified) if $record_ok2;      
	display_inputs(%correct_answers) if $verbose;  # choice of correct answers submitted 
	# should this information on what answers are being submitted have an option switch?

	print "DONE -- $NO_ERRORS -- $ALL_CORRECT\n"if $verbose;
}

#######################################################################
# Auxiliary subroutines
#######################################################################


sub display_inputs {
	my %correct_answers = @_;
	foreach my $key (sort keys %correct_answers) {
		print "$key => $correct_answers{$key}\n";
	}
}
sub edit_source_file {
	my $file_path = shift;
	system("bbedit $file_path");
}
sub record_problem_ok1 {
	my $error_flag = shift//'';
	my $xmlrpc_client = shift;
	my $file_path = shift;
	my $return_string = shift;
	my $result = $xmlrpc_client->return_object;
	if (defined($result->{flags}->{DEBUG_messages}) ) {
		my @debug_messages = @{$result->{flags}->{DEBUG_messages}};
		$return_string .= (pop @debug_messages ) ||'' ; #avoid error if array was empty
		if (@debug_messages) {
			$return_string .= join(" ", @debug_messages);
		} else {
					$return_string = "";
		}
	}
	if (defined($result->{errors}) ) {
		$return_string= $result->{errors};
	}
	if (defined($result->{flags}->{WARNING_messages}) ) {
		my @warning_messages = @{$result->{flags}->{WARNING_messages}};
		$return_string .= (pop @warning_messages)||''; #avoid error if array was empty
			$@=undef;
		if (@warning_messages) {
			$return_string .= join(" ", @warning_messages);
		} else {
			$return_string = "";
		}
	}
	my $SHORT_RETURN_STRING = ($return_string)?"has errors":"ok";
	unless ($return_string) {
		$return_string = "1\t $file_path is ok\n";
	} else {
		$return_string = "0\t $file_path has errors\n";
	}
	 
	local(*FH);
	open(FH, '>>',$path_to_log_file) or die "Can't open file $path_to_log_file for writing";
	print FH $return_string;
	close(FH);
	return $SHORT_RETURN_STRING;
}
sub record_problem_ok2 {
	my $error_flag = shift//'';
	my $xmlrpc_client = shift;
	my $file_path = shift;
	my $some_correct_answers_not_specified = shift;
	my %scores = ();
	my $ALL_CORRECT= 0;
	my $all_correct = ($error_flag)?0:1;
		foreach my $ans (keys %{$xmlrpc_client->return_object->{answers}} ) {
			$scores{$ans} = 
			      $xmlrpc_client->return_object->{answers}->{$ans}->{score};
			$all_correct =$all_correct && $scores{$ans};
		}
	$all_correct = ".5" if $some_correct_answers_not_specified;
	$ALL_CORRECT = ($all_correct == 1)?'All answers are correct':'Some answers are incorrect';
	local(*FH);
	open(FH, '>>',$path_to_log_file) or die "Can't open file $path_to_log_file for writing";
	print FH "$all_correct $file_path\n"; #  do we need this? compile_errors=$error_flag\n";
	close(FH);
	return $ALL_CORRECT;
}
sub process_problem {
	my $file_path = shift;
	my $input    = shift;
	my $form_data  = shift;
	# %credentials is global
	my $problemSeed = $form_data->{problemSeed};
	die "problem seed not defined in sendXMLRPC::process_problem" unless $problemSeed;
	
	### get source and correct file_path name so that it is relative to templates directory
	my ($adj_file_path, $source) = get_source($file_path);
	#print "find file at $adj_file_path ", length($source), "\n";
	### build client
	my $xmlrpc_client = new WebworkClient (
		url                    => $credentials{site_url},
		form_action_url        => $credentials{form_action_url},
		site_password          =>  $credentials{site_password}//'',
		courseID               =>  $credentials{courseID},
		userID                 =>  $credentials{userID},
		session_key            =>  $credentials{session_key}//'',
		sourceFilePath         => $adj_file_path,
	);
	
	### update client
	$xmlrpc_client->encodeSource($source);
	$form_data->{showAnsGroupInfo} 		= $print_answer_group;
	$form_data->{showAnsHashInfo}       = $print_answer_hash;
	$form_data->{showPGInfo}	        = $print_pg_hash;
	$xmlrpc_client->form_data( $form_data	);
	
	### update inputs
	my $updated_input = {%$input, 
					  envir => $xmlrpc_client->environment(
							   fileName       => $adj_file_path,
							   sourceFilePath => $adj_file_path,
							   problemSeed    => $problemSeed,),
	};
	
	##################################################
	# input section
	##################################################
	### store the time before we invoke the content generator
	my $cg_start = time; # this is Time::HiRes's time, which gives floating point values


	############################################
	# Call server via xmlrpc_client
	############################################
	our($output, $return_string, $result, $error_flag, $error_string);
	$error_flag=0; $error_string='';    
	$result = $xmlrpc_client->xmlrpcCall('renderProblem', $updated_input);
	unless ( $xmlrpc_client->fault  )    {
		print "\n\n Result of renderProblem \n\n" if $UNIT_TESTS_ON;
		print pretty_print_rh($result) if $UNIT_TESTS_ON;
	    if (not defined $result) {  #FIXME make sure this is the right error message if site is unavailable
	    	$error_string = "0\t Could not connect to rendering site ". $xmlrpc_client->{url}."\n";
	    } elsif (defined($result->{flags}->{error_flag}) and $output->{flags}->{error_flag} ) {
			$error_string = "0\t $file_path has errors\n";
		} elsif (defined($result->{errors}) and $output->{errors} ){
			$error_string = "0\t $file_path has syntax errors\n";
		}
		$error_flag=1 if $result->{errors};
	} else {
		$error_flag=1;
		$error_string = $xmlrpc_client->return_object;  # error report		
	}	
	##################################################
	# log elapsed time
	##################################################
	my $scriptName = 'sendXMLRPC';
	my $cg_end = time;
	my $cg_duration = $cg_end - $cg_start;
	WebworkClient::writeRenderLogEntry("", "{script:$scriptName; file:$file_path; ". sprintf("duration: %.3f sec;", $cg_duration)." url: $credentials{site_url}; }",'');
	return $error_flag, $xmlrpc_client, $error_string;
}

##################################################
# print the output (or the error message)  and display
#FIXME -- possibly refactor these two into display_output()??
##################################################

sub	display_html_output {  #display the problem in a browser
	my $file_path = shift;
	my $output_text = shift;
	$file_path =~s|/$||;   # remove final /
	$file_path =~ m|/?([^/]+)$|;
	my $file_name = $1;
	$file_name =~ s/\.\w+$/\.html/;    # replace extension with html
	my $output_file = TEMPOUTPUTDIR().$file_name;
	local(*FH);
	open(FH, '>', $output_file) or die "Can't open file $output_file for writing";
	print FH $output_text;
	close(FH);

	system($HTML_DISPLAY_COMMAND." ".$output_file);
	sleep 1;   #wait 1 seconds
	unlink($output_file);
}

sub display_hash_output {   # print the entire hash output to the command line
	my $file_path = shift;
	my $output_text = shift;	
	$file_path =~s|/$||;   # remove final /
	$file_path =~ m|/?([^/]+)$|;
	my $file_name = $1;
	$file_name =~ s/\.\w+$/\.txt/;    # replace extension with html
	my $output_file = TEMPOUTPUTDIR().$file_name;
	my $output_text2 = pretty_print_rh($output_text);
	print STDOUT $output_text2;
# 	local(*FH);
# 	open(FH, '>', $output_file) or die "Can't open file $output_file writing";
# 	print FH $output_text2;
# 	close(FH);
# 
# 	system(HASH_DISPLAY_COMMAND().$output_file."; rm $output_file;");
	#sleep 1; #wait 1 seconds
	#unlink($output_file);
}

sub display_ans_output {  # print the collection of answer hashes to the command line
	my $file_path = shift;
	my $return_object = shift;	
	$file_path =~s|/$||;   # remove final /
	$file_path =~ m|/?([^/]+)$|;
	my $file_name = $1;
	$file_name =~ s/\.\w+$/\.txt/;    # replace extension with html
	my $output_file = TEMPOUTPUTDIR().$file_name;
	my $output_text = pretty_print_rh($return_object->{answers});
	print STDOUT $output_text;
# 	local(*FH);
# 	open(FH, '>', $output_file) or die "Can't open file $output_file writing";
# 	print FH $output_text;
# 	close(FH);
# 
# 	system(HASH_DISPLAY_COMMAND().$output_file."; rm $output_file;");
# 	sleep 1; #wait 1 seconds
# 	unlink($output_file);
}

##################################################
# Get problem template source and adjust file_path name
##################################################

sub get_source {
	my $file_path = shift;
	my $source;	
	die "Unable to read file $file_path \n" unless -r $file_path;
	eval {  #File::Slurp would be faster (see perl monks)
		 local $/=undef;
  		open(FH, '<',$file_path) or die "Couldn't open file $file_path: $!";
		$source   = <FH>; #slurp  input
  		close FH;
	};
	die "Something is wrong with the contents of $file_path\n" if $@;
	### adjust file_path so that it is relative to the rendering course directory
	#$file_path =~ s|/opt/webwork/libraries/NationalProblemLibrary|Library|;
	$file_path =~ s|^.*?/webwork-open-problem-library/OpenProblemLibrary|Library|;
	print "file_path changed to $file_path\n" if $UNIT_TESTS_ON;
	print $source  if  $UNIT_TESTS_ON;  
	return $file_path, $source;
}


##################################################
# utilities
##################################################

sub pretty_print_rh { 
    shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
	my $rh = shift;
	my $indent = shift || 0;
	my $out = "";
	my $type = ref($rh);

	if (defined($type) and $type) {
		$out .= " type = $type; ";
	} elsif (! defined($rh )) {
		$out .= " type = UNDEFINED; ";
	}
	return $out." " unless defined($rh);
	
	if ( ref($rh) =~/HASH/  ) {
	    $out .= "{\n";
	    $indent++;
 		foreach my $key (sort keys %{$rh})  {
 			$out .= "  "x$indent."$key => " . pretty_print_rh( $rh->{$key}, $indent ) . "\n";
 		}
 		$indent--;
 		$out .= "\n"."  "x$indent."}\n";

 	} elsif (ref($rh)  =~  /ARRAY/ or "$rh" =~/ARRAY/) {
 	    $out .= " ( ";
 		foreach my $elem ( @{$rh} )  {
 		 	$out .= pretty_print_rh($elem, $indent);
 		
 		}
 		$out .=  " ) \n";
	} elsif ( ref($rh) =~ /SCALAR/ ) {
		$out .= "scalar reference ". ${$rh};
	} elsif ( ref($rh) =~/Base64/ ) {
		$out .= "base64 reference " .$$rh;
	} else {
		$out .=  $rh;
	}
	
	return $out." ";
}


sub print_help_message {
print <<'EOT';
NAME
    webwork2/clients/sendXMLRPC.pl

DESCRIPTION
    This script will take a list of files or directories and send it to a
    WeBWorK daemon webservice to have it rendered. For directories each .pg
    file under that directory is rendered.

    The results can be displayed in a browser (use -b or -B switches) as was
    done with renderProblem.pl, on the command line (Use -h or -H switches)
    as was done with renderProblem_rawoutput.pl or summary information about
    whether the problem was correctly rendered can be sent to a log file
    (use -c or C switches).

    The capital letter switches, -B, -H, and -C render the question twice.
    The first time returns an answer hash which contains the correct
    answers. The question is then resubmitted to the renderer with the
    correct answers filled in and displayed.

    IMPORTANT: Remember to configure the local output file and display
    command near the top of this script. !!!!!!!!

    IMPORTANT: Create a valid credentials file.

SYNOPSIS
            sendXMLRPC -vcCbB input.pg

DETAILS
  credentials file
        These locations are searched, in order,  for the credentials file.
        ("$ENV{HOME}/.ww_credentials", "$ENV{HOME}/ww_session_credentials", 'ww_credentials', 'ww_credentials.dist');

        Place a credential file containing the following information at one of the locations above 
        or create a file with this information and specify it with the --credentials option.
    
            %credentials = (
                            userID                 => "my login name for the webwork course",
                            course_password        => "my password ",
                            courseID               => "the name of the webwork course",
                  XML_URL                  => "url of rendering site
                  XML_PASSWORD          => "site password" # preliminary access to site
                  $FORM_ACTION_URL      =  'http://localhost:80/webwork2/html2xml'; #action url for form
            );

  Options
    -a
                Displays the answer hashes returned by the question on the command line.

    -A
                Same as -a but renders the question with the correct answers submitted.

    -b
                Display the rendered question in a browser (specified by the DISPLAY_HTML_COMMAND variable).

    -B
                Same as -b but renders the question with the correct answers submitted.

    -h
                Prints to STDOUT the entire object returned by 
                   the webwork_client xmlrpc request.
                   This includes the answer information displayed by -a and -A and much more.

    -H
                Same as -h but renders the question with the correct answers submitted

    -c
                "check" -- Record success or failure of rendering the question to a log file.

    -C
                Same as -c but the question is rendered with the correct answers submitted. 
                 This succeeds only if the correct answers, as determined from the answer hash, all succeed.

    f=s
                Specify the format used by the browser in displaying the question. 
                 Choices for s are
                 standard
                 sticky
                 debug 
                 simple

    -v
                Verbose output. Used mostly for debugging. 
                 In particular it displays explicitly the correct answers which are (will be)  submitted to the question.

    -e
				Open the source file in an editor. 

                The single letter options can be "bundled" e.g.  -vcCbB
                
	--list   pg_list
				Read and process a list of .pg files contained in the file C<pg_list>.  C<pg_list>
				consists of a sequence of lines each of which contains the full path to a pg
				file that should be processed. (For example this might be the output from an
				earlier run of sendXMLRPC using the -c flag. )

    --pg
                Triggers the printing of the all of the variables available to the PG question. 
                The table appears within the question content. Use in conjunction with -b or -B.

    --anshash
                Prints the answer hash for each answer in the PG_debug output which appears below
                the question content. Use in conjunction with -b or -B. 
                Similar to -a or -A but the output appears in the browser and 
                not on the command line.

    --ansgrp
                Prints the PGanswergroup for each answer evaluator. The information appears in 
                the PG_debug output which follows the question content.  Use in conjunction with -b or -B.
                This contains more information than printing the answer hash. (perhaps too much).

    --credentials=s
                Specifies a file s where the  credential information can be found.

	--help
		   Prints help information. 
	   
	--log 
		   Sets path to log file


EOT
}

1;
