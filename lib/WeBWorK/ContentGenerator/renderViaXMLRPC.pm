################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
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


#use XMLRPC::Lite;
#use MIME::Base64 qw( encode_base64 decode_base64);

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

use strict;
use warnings;
use WebworkClient;
use WeBWorK::Debug;
use CGI;
use Digest::SHA qw(sha256_hex);
use Encode qw(encode);


BEGIN {
	if (MP2) {
		require Apache2::Const;
		Apache2::Const->import(-compile => qw/OK NOT_FOUND FORBIDDEN SERVER_ERROR REDIRECT/);
	} else {
		require Apache::Constants;
		Apache::Constants->import(qw/OK NOT_FOUND FORBIDDEN SERVER_ERROR REDIRECT/);
	}
}


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
# 1.  The url  http://test.webwork.maa.org/mod_xmlrpc
#    points to the Webservice.pm and Webservice/RenderProblem modules
#    Is used by the client to send the original XML request to the webservice.
#    It is constructed in WebworkClient::xmlrpcCall() from the value of $webworkClient->site_url which does 
#    NOT have the mod_xmlrpc segment (it should be   http://test.webwork.maa.org) 
#    and the constant  REQUEST_URI defined in WebworkClient.pm to be mod_xmlrpc.  
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

our ($SITE_URL,$FORM_ACTION_URL, $XML_PASSWORD, $XML_COURSE);

	$XML_PASSWORD     	 =  'xmlwebwork';
	$XML_COURSE          =  'daemon_course';



	$SITE_URL             =  "$server_root_url"; 
	$FORM_ACTION_URL     =  "$server_root_url/webwork2/html2xml";


our @COMMANDS = qw( listLibraries    renderProblem  ); #listLib  readFile tex2pdf 


##################################################
# end configuration section
##################################################

sub create_hash_from_string {
	my $to_digest = shift; # String we will feed in
	my $digest = sha256_hex( encode("UTF-8", $to_digest ) );
	return $digest;
}

sub create_seed_from_string {
	my $to_digest = shift; # String we will feed in

	my $digest = create_hash_from_string( $to_digest );

	# Ideas taken from pg/lib/PGrandom.pm
	my $multiplier = 69069;
	my $modulus = 2**30; # Keep to 2^32

	# The result was a 256 bits number, given as 64 hex digits
	# and we need a 32 bit integer.
	my @pieces = unpack("(a6)*", $digest); # We'll handle 6 hex digits at a time

	my $seed = 0;
	my $piece;

	foreach $piece ( @pieces ) {
	    $seed += $multiplier * hex($piece);
	    $seed %= $modulus;
	}

	return $seed;
}

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	# Note: Vars helps handle things like checkbox 'packed' data;
	my %inputs_ref =  WeBWorK::Form->new_from_paramable($r)->Vars ;

	# When passing parameters via an LMS you get "custom_" put in front of them. So lets
	# try to clean that up. In order to handle possible alternate options for the
	# parameter names - we provide a conversion table as a hash. Some special
	# cases are handled separately.
	my %fix_custom = (
		"custom_userid"                  => "userID",
		"custom_userID"                  => "userID",
		"custom_language"                => "language",
		"custom_outputformat"            => "outputformat",
		"custom_answerssubmitted"        => "answersSubmitted",
		"custom_answersSubmitted"        => "answersSubmitted",
		"custom_problemseed"             => "problemSeed",
		"custom_problemSeed"             => "problemSeed",
		"custom_psvn"                    => "psvn",
		"custom_displaymode"             => "displayMode",
		"custom_displayMode"             => "displayMode",
		"custom_courseid"                => "courseID",
		"custom_courseID"                => "courseID",
		"custom_sourcefilepath"          => "sourceFilePath",
		"custom_sourceFilePath"          => "sourceFilePath",
		"custom_course_password"         => "course_password", # used by the non-LTI html2xml
		"custom_problemuuid"             => "problemUUID",
		"custom_problemUUID"             => "problemUUID",
		"custom_resetseedandpsvnfromuid" => "resetSeedandPsvnFromUID",
		"custom_resetSeedandPsvnFromUID" => "resetSeedandPsvnFromUID",
		"custom_forcePortNumber"         => "forcePortNumber",
		"custom_forceportnumber"         => "forcePortNumber",
		"custom_internal_WW2_secret"     => "internal_WW2_secret",
	);
	my $key;
	foreach $key ( keys( %fix_custom ) ) {
		if ( defined($inputs_ref{$key}) ) {
			$inputs_ref{$fix_custom{$key}} = $inputs_ref{$key};
		}
	}
	if (  defined( $inputs_ref{custom_problemIdentifierPrefix} ) &&
	     !defined( $inputs_ref{custom_problemUUID} ) ) {
		$inputs_ref{problemUUID} = $inputs_ref{custom_problemIdentifierPrefix}; # earlier version of problemUUID
	}

	# Fixme - should we be using lis_person_whatever values???

	if (  defined( $inputs_ref{user_id} ) &&
	     !defined( $inputs_ref{custom_userid} ) &&
	     !defined( $inputs_ref{custom_userID} )
	   ) {
		# Fall back to LTI "user_id" if we did not receive a "custom_" field to set it
		$inputs_ref{userID} = $inputs_ref{user_id};
	}

	if (  defined( $inputs_ref{resetSeedandPsvnFromUID} ) &&
	      $inputs_ref{resetSeedandPsvnFromUID} == 1 ) {
		# LTI requested using the selected "userID" to generate psuedo-random
		# values for the following

		my @items_to_use;
		my $to_digest;

		# 1. psvn
		# usually would be for a user's entire problem set, in this
		# context, we do not have problem sets, so it needs to be depend
		# ONLY on the user information and NOT on any problem data.

		# From https://perldoc.perl.org/Digest/SHA.html
		# The Digest::SHA routines do not handle wide Unicode characters.
		# From https://perldoc.perl.org/Digest/SHA.html
		# "Since a wide character does not fit into a byte, the Digest::SHA routines croak if they encounter one."
		# Thus we must encode into UTF-8 before calling the Digest::SHA function.

		push ( @items_to_use, $inputs_ref{courseID} );
		push ( @items_to_use, $inputs_ref{user_id} );

		$to_digest = join( "", @items_to_use );

		if ( defined( $inputs_ref{psvn} ) ) {
			warn "pre-LTI override had psvn = $inputs_ref{psvn}";
		}

		$inputs_ref{psvn} = create_seed_from_string( $to_digest );

		warn "LTI set psvn to $inputs_ref{psvn}";

		# 2. problemSeed
		# should depend on user and on problem specific values.

		# sourceFilePath          = html2xml setting - path the PG file
		# pathToProblemFile       = html2xml setting
		# context_id              = LTI identified of context from which launch occurred (recommended)
		#    See: http://www.imsglobal.org/specs/ltiv1p0/implementation-guide
		# resource_link_id        = LTI parameter should be unique per launch item (required)
		#    See: http://www.imsglobal.org/specs/ltiv1p0/implementation-guide

		# lis_outcome_service_url = URL used for LTI grade passback - fixed for a given item
		#    Is NOT currently included, in case some systems used multiple URLs which are
		#    all valid.

		# Do NOT include:
		# lis_result_sourcedid    = LTI identifier used for LTI grade passback
		# in Moodle this is NOT constant for 2 launches of the same item. Cannot be used.

		# Do NOT include:
		# problemSource - would change if the PG code was edited on the provider side

		my $item1;
		my @more_items = qw(
			sourceFilePath
			pathToProblemFile
			context_id
			resource_link_id
			);
		foreach $item1 ( @more_items ) {
			if ( defined( $inputs_ref{$item1} ) ) {
				push ( @items_to_use, $inputs_ref{$item1} );
			}
		}

		$to_digest = join( "", @items_to_use );

		if ( defined( $inputs_ref{problemSeed} ) ) {
			warn "pre-LTI override had problemSeed = $inputs_ref{problemSeed}";
		}

		$inputs_ref{problemSeed} = create_seed_from_string( $to_digest );

		warn "LTI set problemSeed to $inputs_ref{problemSeed}";

		# If we do not already have a value for problemUUID, set on based on the LTI data
		# but without dependence on the student.

		if ( !defined( $inputs_ref{problemUUID} ) ) {

		    @items_to_use = (); # Clear it
		    push ( @items_to_use, $inputs_ref{courseID} );

		    foreach $item1 ( @more_items ) {
				if ( defined( $inputs_ref{$item1} ) ) {
					push ( @items_to_use, $inputs_ref{$item1} );
				}
		    }

		    $to_digest = join( "", @items_to_use );

		    # Here we can use a sting hash value and not an integer, as it is
		    # really used in pg/lib/PGalias.pm where a string value is allowed.
		    $inputs_ref{problemUUID} = create_hash_from_string( $to_digest );

		    warn "LTI set problemUUID to $inputs_ref{problemUUID}";
		}

	}

	if ( !defined( $inputs_ref{problemUUID} ) || ( $inputs_ref{problemUUID} eq "" ) ) {
		$inputs_ref{problemUUID} = 0; # This default would be set later on
		# and the change would be "late" for the "sessionDataToHash"
		# so force the fallback value here.
	}

	my $user_id      = $inputs_ref{userID};
	my $courseName   = $inputs_ref{courseID};
	my $displayMode  = $inputs_ref{displayMode};
	my $problemSeed  = $inputs_ref{problemSeed};

	# FIXME -- it might be better to send this error if the input is not all correct
	# rather than trying to set defaults such as displaymode
	unless ( $user_id && $courseName && $displayMode && $problemSeed) {
		my @tmp;
		my $k1;
		foreach $k1 ( keys( %inputs_ref ) ) {
		  if ( $k1 =~ /password/i || $k1 =~ /secret/i) {
		    push( @tmp, "${k1}: redacted" );
		  } else {
		    push( @tmp, "${k1}: |$inputs_ref{$k1}|" );
		  }
		}
		CGI::h1("Missing essential data in web dataform:");
		print CGI::ul( CGI::li(CGI::escapeHTML([
			"userID: |$user_id|",
			"courseID: |$courseName|",
			"displayMode: |$displayMode|",
			"problemSeed: |$problemSeed|",
			@tmp
		      ])));
		return;
	}
    #######################
    #  setup xmlrpc client
    #######################
    my $xmlrpc_client = new WebworkClient;

	$xmlrpc_client->encoded_source($r->param('problemSource')) ; # this source has already been encoded
	$xmlrpc_client->site_url($SITE_URL);
	$xmlrpc_client->{form_action_url} = $FORM_ACTION_URL;
	$xmlrpc_client->{userID}          = $inputs_ref{userID};
	$xmlrpc_client->{course_password} = $inputs_ref{course_password};
	$xmlrpc_client->{site_password}   = $XML_PASSWORD;
	$xmlrpc_client->{session_key}     = $inputs_ref{session_key};
	$xmlrpc_client->{courseID}        = $inputs_ref{courseID};
	$xmlrpc_client->{outputformat}    = $inputs_ref{outputformat};
	$xmlrpc_client->{sourceFilePath}  = $inputs_ref{sourceFilePath};
	$xmlrpc_client->{inputs_ref} = \%inputs_ref;  # contains form data
	# print STDERR WebworkClient::pretty_print($r->{paramcache});

	##############################
	# xmlrpc_client calls webservice to have problem rendered
	#
	# and stores the resulting HTML output in $self->return_object
	# from which it will eventually be returned to the browser
	#
	##############################
	if ( $xmlrpc_client->xmlrpcCall('renderProblem', $xmlrpc_client->{inputs_ref}) )    {
			$self->{output} = $xmlrpc_client->formatRenderedProblem ;
	} else {
		$self->{output}= $xmlrpc_client->return_object;  # error report
	}

	################################
 }

sub header {
	my $self = shift;
	my $r = $self->r;
	$r->content_type("text/html; charset=utf-8");
	$r->headers_out->add("Access-Control-Allow-Origin" => '*');
	$r->send_http_header unless MP2;
	return MP2 ? Apache2::Const::OK : Apache::Constants::OK;
}

sub content {
   ###########################
   # Return content of rendered problem to the browser that requested it
   ###########################
	my $self = shift;
	print $self->{output};
}




1;
