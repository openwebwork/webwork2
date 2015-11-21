################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/renderViaXMLRPC.pm,v 1.1 2010/05/11 15:27:08 gage Exp $
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

WeBWorK::ContentGenerator::ProblemRenderer - renderViaXMLRPC is an HTML 
front end for calls to the xmlrpc webservice

=cut

use strict;
use warnings;

package WeBWorK::ContentGenerator::renderViaXMLRPC;
use base qw(WeBWorK::ContentGenerator);

#use Crypt::SSLeay;
#use XMLRPC::Lite;
#use MIME::Base64 qw( encode_base64 decode_base64);


use strict;
use warnings;
use WebworkClient;


=head1 Description


#################################################
  renderViaXMLRPC -- a front end for the Webservice that accepts HTML forms

  receives WeBWorK problems presented as HTML forms,
  packages the form variables into an XML_RPC request
 suitable for the Webservice/RenderProblem.pm
 takes the answer returned by the webservice (which has HTML format) and 
 returns it to the browser.
#################################################

=cut
 
# To configure the target webwork server two URLs are required
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


# Determine the root directory for webwork on this machine (e.g. /opt/webwork/webwork2 )
# this is set in webwork.apache2-config
# it specifies the address of the webwork root directory

#my $webwork_dir  = $ENV{WEBWORK_ROOT};
my $webwork_dir  = $WeBWorK::Constants::WEBWORK_DIRECTORY;
unless ($webwork_dir) {
	die "renderViaXMLRPC.pm requires that the top WeBWorK directory be set in ".
	"\$WeBWorK::Constants::WEBWORK_DIRECTORY by webwork.apache-config or webwork.apache2-config\n";
}

# read the webwork2/conf/defaults.config file to determine other parameters
#
my $seed_ce = new WeBWorK::CourseEnvironment({ webwork_dir => $webwork_dir });
my $server_root_url = $seed_ce->{server_root_url};
unless ($server_root_url) {
	die "unable to determine apache server url using course environment |$seed_ce|.".
	    "check that the variable \$server_root_url has been properly set in conf/site.conf\n";
}

############################
# These variables are set when the child process is started
# and remain constant through all of the calls handled by the 
# child
############################

our ($XML_URL,$FORM_ACTION_URL, $XML_PASSWORD, $XML_COURSE);

	$XML_PASSWORD     	 =  'xmlwebwork';
	$XML_COURSE          =  'daemon_course';



	$XML_URL             =  "$server_root_url/mod_xmlrpc";
	$FORM_ACTION_URL     =  "$server_root_url/webwork2/html2xml";

use constant DISPLAYMODE   => 'images'; #  Mathjax  is another possibilities.


our @COMMANDS = qw( listLibraries    renderProblem  ); #listLib  readFile tex2pdf 


##################################################
# end configuration section
##################################################


sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
 
 	my %inputs_ref;
	my @keys = $r->mutable_param;  # $r->param;
	foreach my $key ( @keys ) {
		$inputs_ref{$key} = $r->param("$key");
	}
	my $user_id      = $inputs_ref{userID};
	my $session_key	 = $inputs_ref{session_key};
	my $courseName   = $inputs_ref{courseID};

    #######################
    #  setup xmlrpc client
    #######################
    my $xmlrpc_client = new WebworkClient;

	$xmlrpc_client->{encodedSource}   = $r->param('problemSource') ; # this source has already been encoded
	$xmlrpc_client->url($XML_URL);
	$xmlrpc_client->{form_action_url} = $FORM_ACTION_URL;
	$xmlrpc_client->{displayMode}     = $inputs_ref{displayMode} // DISPLAYMODE();
	$xmlrpc_client->{userID}          = $inputs_ref{userID};
	$xmlrpc_client->{password}        = $inputs_ref{password};
	$xmlrpc_client->{site_password}   = $XML_PASSWORD;
	$xmlrpc_client->{session_key}     = $inputs_ref{session_key};
	$xmlrpc_client->{courseID}        = $inputs_ref{courseID};
	$xmlrpc_client->{outputformat}    = $inputs_ref{outputformat};
	$xmlrpc_client->{sourceFilePath}  = $inputs_ref{sourceFilePath};
	

	$xmlrpc_client->{inputs_ref} = \%inputs_ref;
	# print STDERR WebworkClient::pretty_print($r->{paramcache});
	
	##############################
	# xmlrpc_client calls webservice to have problem rendered
	#
	# and stores the resulting HTML output in $self->{output}
	# from which it will eventually be returned to the browser
	#
	##############################
	if ( $xmlrpc_client->xmlrpcCall('renderProblem', $xmlrpc_client->{inputs_ref}) )    {
			$self->{output} = $xmlrpc_client->formatRenderedProblem;
	} else {
		$self->{output} = $xmlrpc_client->{output};  # error report
	}
	
	################################
 }

sub content {
   ###########################
   # Return content of rendered problem to the browser that requested it
   ###########################
	my $self = shift;
	print $self->{output};
}




1;
