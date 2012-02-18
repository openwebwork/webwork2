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



##################################################
#  configuration section for client
##################################################

# Use address to WeBWorK code library where WebworkClient.pm is located.
use lib '/opt/webwork/webwork2/lib';
#use Crypt::SSLeay;  # needed for https
use WebworkClient;
use MIME::Base64 qw( encode_base64 decode_base64);


#############################################
# Configure
#############################################

 ############################################################
 # configure the local output file and display command !!!!!!!!
 ############################################################

 # Path to a temporary file for storing the output of renderProblem.pl
 use constant  TEMPOUTPUTFILE   => '/Users/gage/Desktop/renderProblemOutput.html'; 
 
 # Command line for displaying the temporary file in a browser.
 #use constant  DISPLAY_COMMAND  => 'open -a firefox ';   #browser opens tempoutputfile above
  use constant  DISPLAY_COMMAND  => "open -a 'Google Chrome' ";

 ############################################################
 
 my $use_site;
 #$use_site = 'test_webwork';    # select a rendering site 
 $use_site = 'local';           # select a rendering site 
 #$use_site = 'rochester_test';  # select a rendering site 
 
 
 ############################################################
 
# To configure the target webwork server
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
	$XML_URL      =  'http://localhost:80';
	$FORM_ACTION_URL  =  'http://localhost:80/webwork2/html2xml';
	$XML_PASSWORD     =  'xmlwebwork';
	$XML_COURSE       =  'daemon_course';
} elsif ($use_site eq 'rochester_test') {  
	
	$XML_URL      =  'https://hosted2.webwork.rochester.edu';
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

our $UNIT_TESTS_ON             = 0;

####################################################
# get credentials
####################################################

my $credential_path = ".ww_credentials";
eval{require $credential_path};
if ($@ ) {
print STDERR <<EOF;
Can't find file $credential_path:
Place a file with that name and containing this information in the current directory
%credentials = (
        userID          => "my login name for the webwork course",
        password        => "my password ",
        courseID        => "the name of the webwork course",
)
---------------------------------------------------------
EOF
die;
}

#print STDERR  "credentials: ", join(" | ", %credentials), "\n";



use constant DISPLAYMODE   => 'images'; #  jsMath  is another possibilities.


our @COMMANDS = qw( listLibraries    renderProblem  ); #listLib  readFile tex2pdf 


##################################################
# end configuration section
##################################################


##################################################
# input/output section
##################################################


our $source;
our $rh_result;
# filter mode  main code

{
	local($/);
	$source   = <>; #slurp standard input
<<<<<<< HEAD
	#print $source;  # return input to BBedit
=======
	print $source;  # return input to BBedit
>>>>>>> turn_off_warnings_on_webservice

}
############################################
# Build client
############################################
our $xmlrpc_client = new WebworkClient (
	url                    => $XML_URL,
	form_action_url        => $FORM_ACTION_URL,
	displayMode            => DISPLAYMODE(),
	site_password          =>  $credentials{site_password},
	courseID               =>  $credentials{courseID},
	userID                 =>  $credentials{userID},
	session_key            =>  $credentials{session_key},
);
 
 $xmlrpc_client->encodeSource($source);
 
 my $input = { 
		userID      	=> $credentials{userID}||'',
		session_key	 	=> $credentials{session_key}||'',
		courseID   		=> $credentials{courseID}||'',
		courseName   	=> $credentials{courseID}||'',
		password     	=> $credentials{password}||'',	
		site_password   => $credentials{site_password}||'',
 };

#xmlrpcCall('renderProblem');
our $output;
our $result;
if ( $result = $xmlrpc_client->xmlrpcCall('renderProblem', $input) )    {
    print "\n\n Result of renderProblem \n\n" if $UNIT_TESTS_ON;
	$output = $xmlrpc_client->formatRenderedProblem;
	###HACK fixme
    print pretty_print_rh($result) if $UNIT_TESTS_ON;

} else {
    print "\n\n ERRORS in renderProblem \n\n";
	$output = $xmlrpc_client->{output};  # error report
}

local(*FH);
open(FH, '>'.TEMPOUTPUTFILE) or die "Can't open file ".TEMPOUTPUTFILE()." for writing";
print FH $output;
close(FH);

system(DISPLAY_COMMAND().TEMPOUTPUTFILE());

##################################################
# end input/output section
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
	
	if ( ref($rh) =~/HASH/ or "$rh" =~/HASH/ ) {
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
	
	if ( ref($rh) =~/HASH/ or "$rh" =~/HASH/ ) {
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

<<<<<<< HEAD

=======
>>>>>>> turn_off_warnings_on_webservice
1;
