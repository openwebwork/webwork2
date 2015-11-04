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

webwork2/clients/renderProblem.pl

This script will take a file and send it to a WeBWorK daemon webservice
to have it rendered.  The result is split into the basic HTML rendering
and evaluation of answers and then passed to a browser for printing.

The formatting allows the browser presentation to be interactive with the 
daemon running the script webwork2/lib/renderViaXMLRPC.pm

Rembember to configure the local output file and display command !!!!!!!!

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

#############################################
# Configure
#############################################


### verbose output when UNIT_TESTS_ON =1;
 our $UNIT_TESTS_ON             = 0;

### Command line for displaying the temporary file in a browser.
 #use constant  DISPLAY_COMMAND  => 'open -a firefox ';   #browser opens tempoutputfile above
  use constant  DISPLAY_COMMAND  => "open -a 'Google Chrome' ";
 #use constant DISPLAY_COMMAND => " less ";   # display tempoutputfile with less
 
### Path to a temporary file for storing the output of renderProblem.pl
 use constant  TEMPOUTPUTFILE   => "$ENV{WEBWORK_ROOT}/DATA/renderProblemOutput.html"; 
 die "You must first create an output file at ".TEMPOUTPUTFILE().
     " with permissions 777 " unless -w TEMPOUTPUTFILE();

### set display mode
use constant DISPLAYMODE   => 'MathJax'; 
use constant PROBLEMSEED   => '32145'; 


### select a rendering site
my $use_site;  
 #$use_site = 'test_webwork';    # select a rendering site 
 #$use_site = 'local';           # select a rendering site 
 #$use_site = 'hosted2';        # select a rendering site 
 $use_site ="credentials";
 
# credentials file location -- search for one of these files 
my $credential_path;
my @path_list = ( "$ENV{HOME}/.ww_credentials", "$ENV{HOME}/ww_session_credentials", 'ww_credentials',);

=head2 credentials file
    
    # Place a credential file containing the following information at one of the locations above.
    # 	%credentials = (
    # 			userID                 => "my login name for the webwork course",
    # 			course_password        => "my password ",
    # 			courseID               => "the name of the webwork course",
    #           XML_URL	               => "url of rendering site
    #           XML_PASSWORD          => "site password" # preliminary access to site
    #           $FORM_ACTION_URL      =  'http://localhost:80/webwork2/html2xml'; #action url for form
    # 	);

=cut

 ############################################################
 # End configure
 ############################################################


 ############################################################
 
=head2  URLs
 
    # To configure a new target webwork server
    # two URLs are required
    # 1. $XML_URL   http://test.webwork.maa.org/mod_xmlrpc
    #    points to the Webservice.pm and Webservice/RenderProblem modules
    #    Is used by the client to send the original XML request to the webservice
    #
    # 2. $FORM_ACTION_URL      http://test.webwork.maa.org/webwork2/html2xml
    #    points to the renderViaXMLRPC.pm module.
    #
    #     This url is placed as form action url when the rendered HTML from the original
    #     request is returned to the client from Webservice/RenderProblem. The client
    #     reorganizes the XML it receives into an HTML page (with a WeBWorK form) and 
    #     pipes it through a local browser.
    #
    #     The browser uses this url to resubmit the problem (with answers) via the standard
    #     HTML webform used by WeBWorK to the renderViaXMLRPC.pm handler.  
    #
    #     This renderViaXMLRPC.pm handler acts as an intermediary between the browser 
    #     and the webservice.  It interprets the HTML form sent by the browser, 
    #     rewrites the form data in XML format, submits it to the WebworkWebservice.pm 
    #     which processes it and sends the the resulting HTML back to renderViaXMLRPC.pm
    #     which in turn passes it back to the browser.
    # 3.  The second time a problem is submitted renderViaXMLRPC.pm receives the WeBWorK form 
    #     submitted directly by the browser.  
    #     The renderViaXMLRPC.pm translates the WeBWorK form, has it processes by the webservice
    #     and returns the result to the browser. 
    #     The The client renderProblem.pl script is no longer involved.
    # 4.  Summary: renderProblem.pl is only involved in the first round trip
    #     of the submitted problem.  After that the communication is  between the browser and
    #     renderViaXMLRPC using HTML forms and between renderViaXMLRPC and the WebworkWebservice.pm
    #     module using XML_RPC.
    # 5.  The XML_PASSWORD is defined on the site.  In future versions a more secure password method
    #     may be implemented.  This is sufficient to keep out robots.
    # 6.  The course "daemon_course" must be a course that has been created on the server or an error will
    #     result. A different name can be used but the course must exist on the server.
    # 7.  More secure authentication is achieved using courseID, userID and course_password.  
    #     The course_password must be the password for userID in the course courseID and that
    #     user must have sufficient permissions in the course.
    #     The permission level is set in the WebworkWebservice code. 
          

=cut


####################################################
# get credentials
####################################################
my $credentials_string = <<EOF;
The credentials file should contain this:
	%credentials = (
			userID              => "my login name for the webwork course",
			course_password     => "my password ",
			courseID            => "the name of the webwork course",
            XML_URL	            => "url of rendering site",
            XML_PASSWORD        => "site password", # preliminary access to site
            FORM_ACTION_URL     =>  'http://localhost:80/webwork2/html2xml', #action url for form
	);
1;
EOF

foreach my $path (@path_list) {
	if (-r "$path" ) {
		$credential_path = $path;
		last;
	}
}
if  ( $credential_path ) { 
	print "Credentials taken from file $credential_path\n" if $UNIT_TESTS_ON;
} else {
	die <<EOF;
Can't find path for credentials. Looked in @path_list.
$credentials_string
---------------------------------------------------------
EOF
}  

our %credentials;
eval{require $credential_path};
if ($@  or not  %credentials) {
	foreach my $key (qw(userID courseID course_password XML_URL XML_PASSWORD FORM_ACTION_URL)) {
		print STDERR "$key is missing from ".
		             "\%credentials at $credential_path\n" unless $credentials{$key};
	}
	print STDERR $credentials_string;
	die;
}

###############################
# configure table
###############################
our ( $XML_URL,$FORM_ACTION_URL, $XML_PASSWORD, $XML_COURSE);

if ($use_site eq 'local') {
	# the rest can work!!
	$XML_URL          =  'http://localhost:80';
	$FORM_ACTION_URL  =  'http://localhost:80/webwork2/html2xml';
	$XML_PASSWORD     =  'xmlwebwork';    #matches site_password in renderViaXMLRPC.pm
	$XML_COURSE       =  'daemon_course';
} elsif ($use_site eq 'hosted2') {  
	
	$XML_URL          =  'https://hosted2.webwork.rochester.edu';
	$FORM_ACTION_URL  =  'https://hosted2.webwork.rochester.edu/webwork2/html2xml';
 	$XML_PASSWORD     = 'xmlwebwork';
 	$XML_COURSE       = 'daemon_course';
	
} elsif ($use_site eq 'test_webwork') {

	$XML_URL      =  'https://test.webwork.maa.org';
	$FORM_ACTION_URL  =  'https://test.webwork.maa.org/webwork2/html2xml';
	$XML_PASSWORD     = 'xmlwebwork';
	$XML_COURSE       = 'daemon_course';

} else {
    print "Obtain all data from credentials file: $credential_path\n" if $UNIT_TESTS_ON;
	$XML_URL 			= $credentials{site_url};
	$FORM_ACTION_URL  	= $credentials{form_action_url};
	$XML_PASSWORD     	= $credentials{site_password};
	$XML_COURSE       	= $credentials{courseID};
	
}

##################################################
#  END gathering credentials for client
##################################################


##################################################
# input section
##################################################
# store the time before we invoke the content generator
my $cg_start = time; # this is Time::HiRes's time, which gives floating point values


our $source;

# set fileName path to path for current file (this is a best guess -- may not always be correct)

my $fileName = $ARGV[0];

# filter mode  main code
die "Unable to read file $fileName \n" unless -r $fileName;
eval {
	local($/);
	$source   = <>; #slurp standard input
};
die "Something is wrong with the contents of $fileName\n" if $@;

### adjust fileName so that it is relative to the rendering course directory
	#$fileName =~ s|/opt/webwork/libraries/NationalProblemLibrary|Library|;
	$fileName =~ s|^.*?/webwork-open-problem-library/OpenProblemLibrary|Library|;
	print "fileName changed to $fileName\n" if $UNIT_TESTS_ON;
	#print "source $source\n" if $UNIT_TESTS_ON;
	print $source  if  $UNIT_TESTS_ON;  # return input to BBedit

############################################
# Build client
############################################


our $xmlrpc_client = new WebworkClient (
	url                    => $XML_URL,
	form_action_url        => $FORM_ACTION_URL,
#	displayMode            => DISPLAYMODE(),
	site_password          =>  $XML_PASSWORD//'',
	courseID               =>  $credentials{courseID},
	userID                 =>  $credentials{userID},
	session_key            =>  $credentials{session_key}//'',
	sourceFilePath         =>  $fileName,
	inputs_ref             =>  {displayMode => DISPLAYMODE(), problemSeed => PROBLEMSEED(),},
);

 $xmlrpc_client->encodeSource($source);
 
 my $input = { 
		userID      			=> $credentials{userID}//'',
		session_key	 			=> $credentials{session_key}//'',
		courseID   				=> $credentials{courseID}//'',
		courseName   			=> $credentials{courseID}//'',
		course_password     	=> $credentials{course_password}//'',	
		site_password   		=> $XML_PASSWORD//'',
		envir           		=> $xmlrpc_client->environment(
		                               fileName       => $fileName,
		                               sourceFilePath => $fileName
		                            ),
 };
$input->{envir}->{inputs_ref} = { displayMode => DISPLAYMODE(),	
                                  problemSeed => PROBLEMSEED(),	  
};               
								  
$xmlrpc_client->{sourceFilePath}  = $fileName;

############################################
# Call server via xmlrpc_client
# Format the returned values
############################################
our($output, $return_string, $result);    

if ( $result = $xmlrpc_client->xmlrpcCall('renderProblem', $input) )    {
    print "\n\n Result of renderProblem \n\n" if $UNIT_TESTS_ON;
    print pretty_print_rh($result) if $UNIT_TESTS_ON;
    $output = $xmlrpc_client->formatRenderedProblem;
} else {
    print "\n\n ERRORS in renderProblem \n\n";
	$output = $xmlrpc_client->return_object;  # error report
}

##################################################
# print the output and display
##################################################

local(*FH);
open(FH, '>'.TEMPOUTPUTFILE) or die "Can't open file ".TEMPOUTPUTFILE()." for writing";
print FH $output;
close(FH);

system(DISPLAY_COMMAND().TEMPOUTPUTFILE());

##################################################
# log elapsed time
##################################################
my $scriptName = 'renderProblem';
my $cg_end = time;
my $cg_duration = $cg_end - $cg_start;
WebworkClient::writeRenderLogEntry("", "{script:$scriptName; file:$fileName; ". sprintf("duration: %.3f sec;", $cg_duration)." url: $XML_URL; }",'');


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


1;
