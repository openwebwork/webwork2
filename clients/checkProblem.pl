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

# Find webwork2 library
BEGIN {
        die "WEBWORK_ROOT not found in environment. \n
             WEBWORK_ROOT can be defined in your .cshrc or .bashrc file\n
             It should be set to the webwork2 directory (e.g. /opt/webwork/webwork2)"
                unless exists $ENV{WEBWORK_ROOT};
	# Unused variable, but define it twice to avoid an error message.
	$WeBWorK::Constants::WEBWORK_DIRECTORY = '';
	$WeBWorK::Constants::WEBWORK_DIRECTORY = '';
}
use lib "$ENV{WEBWORK_ROOT}/lib";
use Crypt::SSLeay;  # needed for https
use WebworkClient;
use MIME::Base64 qw( encode_base64 decode_base64);

#############################################
# Configure
#############################################


 # verbose output when UNIT_TESTS_ON =1;
 our $UNIT_TESTS_ON             = 0;

 # Command line for displaying the temporary file in a browser.
 #use constant  DISPLAY_COMMAND  => 'open -a firefox ';   #browser opens tempoutputfile above
 # use constant  DISPLAY_COMMAND  => "open -a 'Google Chrome' ";
   use constant DISPLAY_COMMAND => " less ";   # display tempoutputfile with less



my $use_site;
# select a rendering site  
 #$use_site = 'test_webwork';    # select a rendering site 
 #$use_site = 'local';           # select a rendering site 
 $use_site = 'hosted2';        # select a rendering site 

# credentials file location -- search for one of these files 
my $credential_path;
my @path_list = ('.ww_credentials', "$ENV{HOME}/.ww_credentials", "$ENV{HOME}/ww_session_credentials");
# Place a credential file containing the following information at one of the locations above.
# 	%credentials = (
# 			userID          => "my login name for the webwork course",
# 			password        => "my password ",
# 			courseID        => "the name of the webwork course",
# 	);


 ############################################################
 # End configure
 ############################################################

 # Path to a temporary file for storing the output of renderProblem.pl
use constant LOG_FILE => "$ENV{WEBWORK_ROOT}/DATA/bad_problems.txt";

use constant DISPLAYMODE   => 'images'; #  jsMath  is another possibilities.

die "You must first create an output file at ".LOG_FILE()." with permissions 777 " unless
-w LOG_FILE();

 ############################################################
 
# To configure a new target webwork server
# two URLs are required
# 1. $XML_URL   http://test.webwork.maa.org/mod_xmlrpc
#    points to the Webservice.pm and Webservice/RenderProblem modules
#    Is used by the client to send the original XML request to the webservice
#
# 2. $FORM_ACTION_URL      http:http://test.webwork.maa.org/webwork2/html2xml
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


our ( $XML_URL,$FORM_ACTION_URL, $XML_PASSWORD, $XML_COURSE, %credentials);
if ($use_site eq 'local') {
	# the rest can work!!
	$XML_URL          =  'http://localhost:80';
	$FORM_ACTION_URL  =  'http://localhost:80/webwork2/html2xml';
	$XML_PASSWORD     =  'xmlwebwork';    #matches password in renderViaXMLRPC.pm
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

}

##################################################
#  END configuration section for client
##################################################


####################################################
# get credentials
####################################################


foreach my $path (@path_list) {
	if (-r "$path" ) {
		$credential_path = $path;
		last;
	}
}
unless ( $credential_path ) {
	die <<EOF;
Can't find path for credentials. Looked in @path_list.
Place a credential file containing the following information at one of the locations above.
%credentials = (
        userID          => "my login name for the webwork course",
        password        => "my password ",
        courseID        => "the name of the webwork course",
);
1;
---------------------------------------------------------
EOF
}

eval{require $credential_path};
if ($@  or not  %credentials) {

print STDERR <<EOF;

The credentials file should contain this:
%credentials = (
        userID          => "my login name for the webwork course",
        password        => "my password ",
        courseID        => "the name of the webwork course",
);
1;
EOF
die;
}



our @COMMANDS = qw( listLibraries    renderProblem  ); #listLib  readFile tex2pdf 


##################################################
# end configuration section
##################################################


##################################################
# input/output section
##################################################


our $source;
our $rh_result;

our $filePath = '';

our $output;
our $return_string;


# set fileName path to path for current file (this is a best guess -- may not always be correct)
my $fileName = $ARGV[0]; # should this be ARGV[0]?

############################################
# Build client
############################################
our $xmlrpc_client = new WebworkClient (
	url                    => $XML_URL,
	form_action_url        => $FORM_ACTION_URL,
	displayMode            => DISPLAYMODE(),
	site_password          =>  $XML_PASSWORD//'',
	courseID               =>  $credentials{courseID},
	userID                 =>  $credentials{userID},
	session_key            =>  $credentials{session_key}//'',
);
 
 
 my $input = { 
		userID      	=> $credentials{userID}//'',
		session_key	 	=> $credentials{session_key}//'',
		courseID   		=> $credentials{courseID}//'',
		courseName   	=> $credentials{courseID}//'',
		password     	=> $credentials{password}//'',	
		site_password   => $XML_PASSWORD//'',
		envir           => $xmlrpc_client->environment(),
		                 
 };


if (@ARGV) {
	local(*FH);
	
	open(FH, ">>".LOG_FILE()) || die "Can't open log file ". LOG_FILE();

	{
		local($/);
		$filePath = $ARGV[0];
		$source   = <>; #slurp standard input
		# print FH $source;  # return input to BBedit
	}
    $xmlrpc_client->encodeSource($source);
    
	if ( $xmlrpc_client->xmlrpcCall('renderProblem', $input) )    {
	        $output = $xmlrpc_client->{output};
	    if (not defined $output) {  #FIXME make sure this is the right error message if site is unavailable
	    	$return_string = "Could not connect to rendering site";
	    } elsif (defined($output->{flags}->{error_flag}) and $output->{flags}->{error_flag} ) {
			$return_string = "0\t $filePath has errors\n";
		} elsif (defined($output->{errors}) and $output->{errors} ){
			$return_string = "0\t $filePath has syntax errors\n";
		} else {
			# 
			if (defined($output->{flags}->{DEBUG_messages}) ) {
				my @debug_messages = @{$output->{flags}->{DEBUG_messages}};
				$return_string .= (pop @debug_messages ) ||'' ; #avoid error if array was empty
				if (@debug_messages) {
					$return_string .= join(" ", @debug_messages);
				} else {
							$return_string = "";
				}
			}
			if (defined($output->{flags}->{WARNING_messages}) ) {
				my @warning_messages = @{$output->{flags}->{WARNING_messages}};
				$return_string .= (pop @warning_messages)||''; #avoid error if array was empty
					$@=undef;
				if (@warning_messages) {
					$return_string .= join(" ", @warning_messages);
				} else {
					$return_string = "";
				}
			}
			$return_string = "0\t ".$return_string."\n" if $return_string;   # add a 0 if there was an warning or debug message.
		}
		unless ($return_string) {
			$return_string = "1\t $filePath is ok\n";
		}
	} else {
		
		$return_string = "0\t $filePath has undetermined errors -- could not be read perhaps?\n";
	}
	print FH $return_string;
	close(FH);
} else {
    print "0 $filePath  something went wrong -- could not render file\n";
	print STDERR "Useage: ./checkProblem.pl    [file_name]\n";
	print STDERR "For example: ./checkProblem.pl    input.txt\n";
	print STDERR "Output is sent to the log file: ",LOG_FILE();
	
}


1;
