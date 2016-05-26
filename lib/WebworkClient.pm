#!/usr/bin/perl -w

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WebworkClient.pm,v 1.1 2010/06/08 11:46:38 gage Exp $
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

WebworkClient.pm


=head1 SYNPOSIS
	our $xmlrpc_client = new WebworkClient (
		url                    => $XML_URL,
		form_action_url        => $FORM_ACTION_URL,
		site_password          =>  $XML_PASSWORD//'',
		courseID               =>  $credentials{courseID},
		userID                 =>  $credentials{userID},
		session_key            =>  $credentials{session_key}//'',
		sourceFilePath         =>  $fileName,
	);

Remember to configure the local output file and display command !!!!!!!!



=head1 DESCRIPTION

This script will take a file and send it to a WeBWorK daemon webservice
to have it rendered.  

The result returned is split into the basic HTML rendering
and evaluation of answers and then passed to a browser for printing.

The formatting allows the browser presentation to be interactive with the 
daemon running the script webwork2/lib/renderViaXMLRPC.pm  
and with instructorXMLRPChandler.

See WebworkWebservice.pm  for related modules which operate on the server side

	WebworkXMLRPC (contained in WebworkWebservice.pm)
	renderViaXMLRPC
	instructorXMLRPChandler

=cut

use strict;
use warnings;


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


our @COMMANDS = qw( listLibraries    renderProblem  ); #listLib  readFile tex2pdf 



##################################################
# XMLRPC client -- 
# this code is identical between renderProblem.pl and renderViaXMLRPC.pm????
##################################################

package WebworkClient;

use Crypt::SSLeay;  # needed for https
use lib "$WeBWorK::Constants::WEBWORK_DIRECTORY/lib";
use lib "$WeBWorK::Constants::PG_DIRECTORY/lib";
use XMLRPC::Lite;
use MIME::Base64 qw( encode_base64 decode_base64);
use WeBWorK::Utils qw( wwRound);
use WeBWorK::Utils::AttemptsTable;
use WeBWorK::CourseEnvironment;

use WeBWorK::PG::ImageGenerator;
use HTML::Entities;
use WeBWorK::Localize;
use HTML::Entities;
use WeBWorK::PG::ImageGenerator;
use IO::Socket::SSL;
use Digest::SHA qw(sha1_base64);

use constant  TRANSPORT_METHOD => 'XMLRPC::Lite';
use constant  REQUEST_CLASS    => 'WebworkXMLRPC';  # WebworkXMLRPC is used for soap also!!
use constant  REQUEST_URI      => 'mod_xmlrpc';

our $UNIT_TESTS_ON             = 0;

##################
# static variables

# create seed_ce
# then create imgGen
our $seed_ce;

eval {
	$seed_ce = WeBWorK::CourseEnvironment->new( 
				{webwork_dir		=>		$WeBWorK::Constants::WEBWORK_DIRECTORY, 
				 courseName         =>      '',
				 webworkURL         =>      '',
				 pg_dir             =>      $WeBWorK::Constants::PG_DIRECTORY,
				 });
};
	if ($@ or not ref($seed_ce)){
		warn "Unable to find environment for WebworkClient: 
			 webwork_dir => $WeBWorK::Constants::WEBWORK_DIRECTORY 
			 pg_dir      => $WeBWorK::Constants::PG_DIRECTORY";
	}



our %imagesModeOptions = %{$seed_ce->{pg}->{displayModeOptions}->{images}};
our $site_url = $seed_ce->{server_root_url};	
our $imgGen = WeBWorK::PG::ImageGenerator->new(
		tempDir         => $seed_ce->{webworkDirs}->{tmp},
		latex	        => $seed_ce->{externalPrograms}->{latex},
		dvipng          => $seed_ce->{externalPrograms}->{dvipng},
		useCache        => 1,
		cacheDir        => $seed_ce->{webworkDirs}->{equationCache},
		cacheURL        => $site_url . $seed_ce->{webworkURLs}->{equationCache},
		cacheDB         => $seed_ce->{webworkFiles}->{equationCacheDB},
		dvipng_align    => $imagesModeOptions{dvipng_align},
		dvipng_depth_db => $imagesModeOptions{dvipng_depth_db},
);
#####################
# error formatting
sub format_hash_ref {
	my $hash = shift;
	warn "Use a hash reference" unless ref($hash) =~/HASH/;
	return join(" ", map {$_="--" unless defined($_);$_ } %$hash),"\n";
}

sub new {   #WebworkClient constructor
    my $invocant = shift;
    my $class = ref $invocant || $invocant;
	my $self = {
		return_object   => {},
		request_object  => {},
		error_string    => '',
		encoded_source 	=> '',
		url             => '',
		course_password => '',
		site_password   => '',
		courseID        => '',
		userID          => '',
		inputs_ref      => {		 AnSwEr0001 => '',
				 					 AnSwEr0002 => '',
				 					 AnSwEr0003 => '',
				 					 displayMode     => 'no displayMode defined',
		},
		@_,               # options and overloads
	};

	bless $self, $class;
}


our $result;

##################################################
# Utilities -- 
#    this code is identical between renderProblem.pl and renderViaXMLRPC.pm
##################################################

=head2 xmlrpcCall


	
    $xmlrpc_client->encodeSource($source);
    $xmlrpc_client->{sourceFilePath}  = $fileName;
    
 my $input = { 
        userID                  => $credentials{userID}//'',
        session_key             => $credentials{session_key}//'',
        courseID                => $credentials{courseID}//'',
        courseName              => $credentials{courseID}//'',
        course_password         => $credentials{course_password}//'',   
        site_password           => $XML_PASSWORD//'',
        envir                   => $xmlrpc_client->environment(
                                       fileName       => $fileName,
                                       sourceFilePath => $fileName
                                    ),
 };                          
    our($output, $return_string, $result);    
    

    if ( $result = $xmlrpc_client->xmlrpcCall('renderProblem', $input) )    {
        $output = $xmlrpc_client->formatRenderedProblem;
    } else {
    	$output = $xmlrpc_client->return_object;  # error report
    }

	Keys in $result or in  $xmlrpc_client->return_object for the command "renderProblem"
	 session_key
	 flags
	 errors
	 internal_debug_messages
	 WARNINGS
	 problem_state
	 debug_messages
	 userID
	 compute_time
	 warning_messages
	 courseID
	 text
	 problem_result
	 header_text
	 answers


=cut





sub xmlrpcCall {
	my $self = shift;
	my $command = shift;
	my $input   = shift||{};
	my $requestObject;
	$command   = 'listLibraries' unless defined $command;
	my $default_inputs = $self->default_inputs();
	$requestObject = {%$default_inputs, %$input};  #input values can override default inputs
	  
	$self->request_object($requestObject);   # store the request object for later
	
	my $requestResult; 
	my $transporter = TRANSPORT_METHOD->new;

	eval {
	    $requestResult= $transporter
	        #->uri('http://'.HOSTURL.':'.HOSTPORT.'/'.REQUEST_CLASS)
		#-> proxy(PROTOCOL.'://'.HOSTURL.':'.HOSTPORT.'/'.REQUEST_URI);
		-> proxy(($self->url).'/'.REQUEST_URI);
	};
	print STDERR "WebworkClient: Initiating xmlrpc request to url ",($self->url).'/'.REQUEST_URI, " \n Error: $@\n" if $@;
	# turn off verification of the ssl cert 
	$transporter->transport->ssl_opts(verify_hostname=>0,
	    SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE);
			
    if ($UNIT_TESTS_ON) {
        print STDERR  "WebworkClient.pm ".__LINE__." xmlrpcCall sent to ", $self->url,"\n";
    	print STDERR  "WebworkClient.pm ".__LINE__." xmlrpcCall issued with command $command\n";
    	print STDERR  "WebworkClient.pm ".__LINE__." input is: ",join(" ", %{$self->request_object}),"\n";
    	print STDERR  "WebworkClient.pm ".__LINE__." xmlrpcCall $command initiated webwork webservice object $requestResult\n";
    }
 		
	  local( $result);
	  # use eval to catch errors
	  #print STDERR "WebworkClient: issue command ", REQUEST_CLASS.'.'.$command, " ",join(" ", %$input),"\n";
	  eval { $result = $requestResult->call(REQUEST_CLASS.'.'.$command, $self->request_object ) };
	  # result is of type XMLRPC::SOM
	  print STDERR "There were a lot of errors\n" if $@;
	  print STDERR "Errors: \n $@\n End Errors\n" if $@;

          print CGI::h2("WebworkClient Errors") if $@;
	  print CGI::p("Errors:",CGI::br(),CGI::blockquote({style=>"color:red"},CGI::code($@)),CGI::br(),"End Errors") if $@;
	  
	  if (not ref($result) ) {
	  	my $error_string = "xmlrpcCall to $command returned no result for ". 
	  	     ($self->{sourceFilePath}//'')."\n";
	  	print STDERR $error_string;
	  	$self->error_string($error_string);
	  	$self->fault(1);
	  	return $self;
	  } elsif ( $result->fault  ) { # report errors
		my $error_string = 'Error message for '.
		  join( ' ',
			  "command:",
			  $command,
			  "\n<br/>faultcode:",
			  $result->faultcode, 
			  "\n<br/>faultstring:",
			  $result->faultstring, "\n<br/>End error message<br/>\n"
		  );

		  print STDERR $error_string;
		  $self->return_object($result->result());
		  $self->error_string($error_string);
		  $self->fault(1); # set fault flag to true
		  return $self;  
	  } else {
	  	  if (ref($result->result())=~/HASH/ and defined($result->result()->{text}) ) {
	  		$result->result()->{text} = decode_base64($result->result()->{text});
		}
	  	if (ref($result->result())=~/HASH/ and defined($result->result()->{header_text}) ) {
		    $result->result()->{header_text} = decode_base64($result->result()->{header_text});
	  	}

		$self->return_object($result->result());
		# print "\n retrieve result ",  keys %{$self->return_object};
		return $self->return_object; # $result->result();  
		# would it be better to return the entire $result?
		# probably not, there is no hash directly available from the $result object. 
	  } 

}


=head2 jsXmlrpcCall

=cut

sub jsXmlrpcCall {
	my $self = shift;
	my $command = shift;
	my $input = shift;
	$command   = 'listLibraries' unless $command;
	if ($UNIT_TESTS_ON) {
    	print STDERR  "WebworkClient.pm ".__LINE__." jsXmlrpcCall issued with command $command\n";
    }

	print "the command was $command";

	my $transporter = TRANSPORT_METHOD->new;
	
	my $requestResult = $transporter
	    -> proxy(($self->url).'/'.REQUEST_URI);
	$transporter->transport->ssl_opts(verify_hostname=>0,
	     SSL_verify_mode => 'SSL_VERIFY_NONE');
	
	  local( $result);
	  # use eval to catch errors
	  eval { $result = $requestResult->call(REQUEST_CLASS.'.'.$command,$input) };
	  if ($@) {
	  	print STDERR "There were a lot of errors for $command\n" ;
	  	print STDERR "Errors: \n $@\n End Errors\n" ;
	  	return 0 #failure
	  }
	print "hmm $result";
	  unless (ref($result) and $result->fault) {
	  	my $rh_result = $result->result();
	  	print "\n success \n";
	    print pretty_print($rh_result->{'ra_out'});
		$self->return_object( $rh_result ); 
		return 1; # success

	  } else {
		$self->return_object( 'Error from server: '. join( ",\n ",
		  $result->faultcode,
		  $result->faultstring)
		);
		return 0; #failure
	  }
}

=head2 encodeSource 


=cut 
sub encodeSource {
	my $self = shift;
	my $source = shift||'';
	$self->{encoded_source} =encode_base64($source);
}

=head2  Accessor methods
	
	encoded_source
	request_object
	return_object
	error_string
	fault
	url
	form_data
	
=cut 

sub encoded_source {
	my $self = shift;
	my $source = shift;
	$self->{encoded_source} =$source if defined $source and $source =~/\S/; # source is non-empty
	$self->{encoded_source};
}
sub request_object {   # in or input
	my $self = shift;
	my $object = shift;
	$self->{request_object} =$object if defined $object and ref($object); # source is non-empty
	$self->{request_object};
}
sub return_object {   # out
	my $self = shift;
	my $object = shift;
	$self->{return_object} =$object if defined $object and ref($object); # source is non-empty
	$self->{return_object};
}
sub error_string {   
	my $self = shift;
	my $string = shift;
	$self->{error_string} =$string if defined $string and $string =~/\S/; # source is non-empty
	$self->{error_string};
}
sub fault {   
	my $self = shift;
	my $fault_flag = shift;
	$self->{fault_flag} =$fault_flag if defined $fault_flag and $fault_flag =~/\S/; # source is non-empty
	$self->{fault_flag};
}
sub url {
	my $self = shift;
	my $new_url = shift;
	$self->{url} = $new_url if defined($new_url) and $new_url =~ /\S/;
	$self->{url};
}

sub form_data {
	my $self = shift;
	my $form_data = shift;
	$self->{inputs_ref} = $form_data if defined($form_data) and $form_data =~ /\S/;
	$self->{inputs_ref};
}

=head2 initiate default values

=cut
sub setInputTable_for_listLib {
	my $self = shift;
	my $out = {
		set         =>   'set0',
		library_name =>  'Library',
		command      =>  'all',
	};

	$out;
}

sub default_inputs {
	my $self = shift;
	my $webwork_dir = $WeBWorK::Constants::WEBWORK_DIRECTORY; #'/opt/webwork/webwork2';
	my $seed_ce = new WeBWorK::CourseEnvironment({ webwork_dir => $webwork_dir});
 	die "Can't create seed course environment for webwork in $webwork_dir" unless ref($seed_ce);

	$self->{seed_ce} = $seed_ce;
	
	my @modules_to_evaluate;
	my @extra_packages_to_load;
	my @modules = @{ $seed_ce->{pg}->{modules} };

	foreach my $module_packages_ref (@modules) {
		my ($module, @extra_packages) = @$module_packages_ref;
		# the first item is the main package
		push @modules_to_evaluate, $module;
		# the remaining items are "extra" packages
		push @extra_packages_to_load, @extra_packages;
	}

	my $out = {
		library_name =>  'Library',
		command      =>  'renderProblem',
		answer_form_submitted   => 1,
		course                  => $self->{course},
		extra_packages_to_load  => [@extra_packages_to_load],
		mode                    => $self->{displayMode},
		displayMode             => $self->{displayMode},
		modules_to_evaluate     => [@modules_to_evaluate],
		envir                   => $self->environment(),
		problem_state           => {
		
			num_of_correct_ans  => 0,
			num_of_incorrect_ans => 4,
			recorded_score       => 1.0,
		},
		source                   => $self->encoded_source,  #base64 encoded		
	};

	$out;
}

=item environment

=cut

sub environment {
	my $self = shift;
	my $envir = {
		answerDate  => '4014438528',
		CAPA_Graphics_URL=>'http://webwork-db.math.rochester.edu/capa_graphics/',
		CAPA_GraphicsDirectory =>'/ww/webwork/CAPA/CAPA_Graphics/',
		CAPA_MCTools=>'/ww/webwork/CAPA/CAPA_MCTools/',
		CAPA_Tools=>'/ww/webwork/CAPA/CAPA_Tools/',
		cgiDirectory=>'Not defined',
		cgiURL => 'foobarNot defined',
		classDirectory=> 'Not defined',
		courseName=>'Not defined',
		courseScriptsDirectory=>'not defined',
		displayMode=>$self->{inputs_ref}->{displayMode}//"no display mode defined in WebworkClient-> environment",
		dueDate=> '4014438528',
		effectivePermissionLevel => 10,
		externalGif2EpsPath=>'not defined',
		externalPng2EpsPath=>'not defined',
		externalTTHPath=>'/usr/local/bin/tth',
		fileName=>'WebworkClient.pm:: define fileName in environment',
		formattedAnswerDate=>'6/19/00',
		formattedDueDate=>'6/19/00',
		formattedOpenDate=>'6/19/00',
		functAbsTolDefault=> 0.0000001,
		functLLimitDefault=>0,
		functMaxConstantOfIntegration=> 1000000000000.0,
		functNumOfPoints=> 5,
		functRelPercentTolDefault=> 0.000001,
		functULimitDefault=>1,
		functVarDefault=> 'x',
		functZeroLevelDefault=> 0.000001,
		functZeroLevelTolDefault=>0.000001,
		htmlDirectory =>'not defined',
		htmlURL =>'not defined',
		inputs_ref => $self->{inputs_ref},
		macroDirectory=>'not defined',
		numAbsTolDefault=>0.0000001,
		numFormatDefault=>'%0.13g',
		numOfAttempts=> 0,
		numRelPercentTolDefault => 0.0001,
		numZeroLevelDefault =>0.000001,
		numZeroLevelTolDefault =>0.000001,
		openDate=> '3014438528',
		permissionLevel =>10,
		PRINT_FILE_NAMES_FOR => [ 'gage'],
		probFileName => 'WebworkClient.pm:: define probFileName in environment',
		problemSeed  => $self->{inputs_ref}->{problemSeed}//3333,
		problemValue =>1,
		probNum => 13,
		psvn => 54321,
		questionNumber => 1,
		scriptDirectory => 'Not defined',
		sectionName => 'Gage',
		sectionNumber => 1,
		server_root_url =>"foobarfoobar", 
		sessionKey=> 'Not defined',
		setNumber =>'not defined',
		studentLogin =>'gage',
		studentName => 'Mike Gage',
		tempDirectory => 'not defined',
		templateDirectory=>'not defined',
		tempURL=>'not defined',
		webworkDocsURL => 'not defined',
		showHints => 1,               # extra options -- usually passed from the input form
		showSolutions => 1,
		@_,
	};
	$envir;
};

=item formatRenderedLibraries

=cut
	
sub formatRenderedLibraries {
	my $self 			  = shift;
	#my @rh_result         = @{$self->return_object};  # wrap problem in formats
	my %rh_result         = %{$self->return_object};
	my $result = "";
	foreach my $key (sort  keys %rh_result) {
		$result .= "$key";
		$result .= $rh_result{$key};
	}
	return $result;
}

=item formatRenderedProblem

=cut

sub formatRenderedProblem {
	my $self 			  = shift;
	my $problemText       ='';
	my $rh_result         = $self->return_object() || {};  # wrap problem in formats
	$problemText       = "No output from rendered Problem" unless $rh_result ;
	#print "formatRenderedProblem text $rh_result = ",%$rh_result,"\n";
	if (ref($rh_result) and $rh_result->{text} ) {
		$problemText       =  $rh_result->{text};
	} else {
		$problemText       .= "Unable to decode problem text<br/>\n".
		$self->{error_string}."\n".
		format_hash_ref($rh_result);
	}
	my $problemHeadText = $rh_result->{header_text}//'';
	my $rh_answers        = $rh_result->{answers}//{};
	my $answerOrder       = $rh_result->{flags}->{ANSWER_ENTRY_ORDER}; #[sort keys %{ $rh_result->{answers} }];
	my $encoded_source     = $self->encoded_source//'';
	my $sourceFilePath    = $self->{sourceFilePath}//'';
	my $warnings          = '';
	
	#################################################
	# regular Perl warning messages generated with warn
	#################################################

	if ( defined ($rh_result->{WARNINGS}) and $rh_result->{WARNINGS} ){
		$warnings = "<div style=\"background-color:pink\">
		             <p >WARNINGS</p><p>".decode_base64($rh_result->{WARNINGS})."</p></div>";
	}
	#warn "keys: ", join(" | ", sort keys %{$rh_result });
	
	#################################################	
	# PG debug messages generated with DEBUG_message();
	#################################################
	
	my $debug_messages = $rh_result->{debug_messages} ||     [];
    $debug_messages = join("<br/>\n", @{  $debug_messages }    );
    
	#################################################    
	# PG warning messages generated with WARN_message();
	#################################################

    my $PG_warning_messages =  $rh_result->{warning_messages} ||     [];
    $PG_warning_messages = join("<br/>\n", @{  $PG_warning_messages }    );
    
	#################################################
	# internal debug messages generated within PG_core
	# these are sometimes needed if the PG_core warning message system
	# isn't properly set up before the bug occurs.
	# In general don't use these unless necessary.
	#################################################

    my $internal_debug_messages = $rh_result->{internal_debug_messages} || [];
    $internal_debug_messages = join("<br/>\n", @{ $internal_debug_messages  } );
    
    my $fileName = $self->{input}->{envir}->{fileName} || "";


    #################################################


	$self->{outputformats}={};
	my $XML_URL      	 =  $self->url;
	my $FORM_ACTION_URL  =  $self->{form_action_url};
	my $courseID         =  $self->{courseID};
	my $userID           =  $self->{userID};
	my $course_password  =  $self->{course_password};
	my $problemSeed      =  $self->{inputs_ref}->{problemSeed}//4444;
	my $session_key      =  $rh_result->{session_key}//'';
	my $displayMode      =  $self->{inputs_ref}->{displayMode};
	
	my $previewMode      =  defined($self->{inputs_ref}->{preview});
	my $checkMode        =  defined($self->{inputs_ref}->{WWcheck});
	my $submitMode       =  defined($self->{inputs_ref}->{WWsubmit});
	my $showCorrectMode  =  defined($self->{inputs_ref}->{WWcorrectAns});
        # problemIdentifierPrefix can be added to the request as a parameter.  
        # It adds a prefix to the 
        # identifier used by the  format so that several different problems
        # can appear on the same page.   
	my $problemIdentifierPrefix = $self->{inputs_ref}->{problemIdentifierPrefix} //'';
    my $problemResult    =  $rh_result->{problem_result}//'';
    my $problemState     =  $rh_result->{problem_state}//'';
    my $showSummary      = ($self->{inputs_ref}->{showSummary})//1; #default to show summary for the moment
	my $formLanguage     = ($self->{inputs_ref}->{language})//'en';

	my $scoreSummary     =  '';


	my $tbl = WeBWorK::Utils::AttemptsTable->new(
		$rh_answers,
		answersSubmitted       => $self->{inputs_ref}->{answersSubmitted}//0,
		answerOrder            => $answerOrder//[],
		displayMode            => $self->{inputs_ref}->{displayMode},
		imgGen                 => $imgGen,
		ce                     => '',	#used only to build the imgGen
		showAttemptPreviews    => ($previewMode or $submitMode or $showCorrectMode),
		showAttemptResults     => ($submitMode or $showCorrectMode),
		showCorrectAnswers     => ($showCorrectMode),
		showMessages           => ($previewMode or $submitMode or $showCorrectMode),
		showSummary            => ( ($showSummary and ($submitMode or $showCorrectMode) )//0 )?1:0,  
		maketext               => WeBWorK::Localize::getLoc($formLanguage//'en'),
		summary                => ($self->{problem_result}->{summary} )//'', # can be set by problem grader
	);


	my $answerTemplate = $tbl->answerTemplate;
	my $color_input_blanks_script = $tbl->color_answer_blanks;
	$tbl->imgGen->render(refresh => 1) if $tbl->displayMode eq 'images';

	# warn "imgGen is ", $tbl->imgGen;
	#warn "answerOrder ", $tbl->answerOrder;
	#warn "answersSubmitted ", $tbl->answersSubmitted;
	# render equation images



	if ($submitMode && $problemResult) {
		$scoreSummary = CGI::p('Your score on this attempt is '.wwRound(0, $problemResult->{score} * 100).'%');
		if ($problemResult->{msg}) {
			 $scoreSummary .= CGI::p($problemResult->{msg});
		}

		$scoreSummary .= CGI::p('Your score on this problem has not been recorded.');
		$scoreSummary .= CGI::hidden({id=>'problem-result-score', name=>'problem-result-score',value=>$problemResult->{score}});
	}

	##########################################################
	#  Try to save the grade to an LTI if one provided us data
	##########################################################

	my $LTIGradeMessage = '';
	if (defined($self->{inputs_ref}->{lis_outcome_service_url}) &&
	    defined($self->{inputs_ref}->{'oauth_consumer_key'}) &&
	    defined($self->{inputs_ref}->{'oauth_signature_method'}) &&
	    defined($self->{inputs_ref}->{'lis_result_sourcedid'}) &&
	    defined($self->{seed_ce}->{'LISConsumerKeyHash'}->{$self->{inputs_ref}->{'oauth_consumer_key'}}) ) {
	  
	  my $request_url = $self->{inputs_ref}->{lis_outcome_service_url};
	  my $consumer_key = $self->{inputs_ref}->{'oauth_consumer_key'}; 
	  my $signature_method = $self->{inputs_ref}->{'oauth_signature_method'};
	  my $sourcedid = $self->{inputs_ref}->{'lis_result_sourcedid'};
	  my $consumer_secret = $self->{seed_ce}->{'LISConsumerKeyHash'}->{$consumer_key};
	  my $score = $problemResult ? $problemResult->{score} : 0;
	  
	  # This is boilerplate XML used to submit the $score for $sourcedid
  my $replaceResultXML = <<EOS;
<?xml version = "1.0" encoding = "UTF-8"?>
<imsx_POXEnvelopeRequest xmlns = "http://www.imsglobal.org/services/ltiv1p1/xsd/imsoms_v1p0">
  <imsx_POXHeader>
    <imsx_POXRequestHeaderInfo>
      <imsx_version>V1.0</imsx_version>
      <imsx_messageIdentifier>999999123</imsx_messageIdentifier>
    </imsx_POXRequestHeaderInfo>
  </imsx_POXHeader>
  <imsx_POXBody>
    <replaceResultRequest>
      <resultRecord>
	<sourcedGUID>
	  <sourcedId>$sourcedid</sourcedId>
	</sourcedGUID>
	<result>
	  <resultScore>
	    <language>en</language>
	    <textString>$score</textString>
	  </resultScore>
	</result>
      </resultRecord>
    </replaceResultRequest>
  </imsx_POXBody>
</imsx_POXEnvelopeRequest>
EOS

	  my $bodyhash = sha1_base64($replaceResultXML);

	  # since sha1_base64 doesn't pad we have to do so manually 
	  while (length($bodyhash) % 4) {
	    $bodyhash .= '=';
	  }

	  my $requestGen = Net::OAuth->request("consumer");
  
	  $requestGen->add_required_message_params('body_hash');
  
	  my $gradeRequest = $requestGen->new(
		  request_url => $request_url,
		  request_method => "POST",
		  consumer_secret => $consumer_secret,
		  consumer_key => $consumer_key,
		  signature_method => $signature_method,
		  nonce => int(rand( 2**32)),
		  timestamp => time(),
		  body_hash => $bodyhash
							 );
	  $gradeRequest->sign();

	  my $HTTPRequest = HTTP::Request->new(
					       $gradeRequest->request_method,
					       $gradeRequest->request_url,
					       [
						'Authorization' => $gradeRequest->to_authorization_header,
						'Content-Type'  => 'application/xml',
					       ],
					       $replaceResultXML,
					      );
	  
	  my $response = LWP::UserAgent->new->request($HTTPRequest);
	  
	  if ($response->is_success) {
	    $response->content =~ /<imsx_codeMajor>\s*(\w+)\s*<\/imsx_codeMajor>/;
	    my $message = $1;
	    if ($message ne 'success') {
	      $LTIGradeMessage = CGI::p("Unable to update LMS grade. Error: ".$message);
	      $debug_messages .= CGI::escapeHTML($response->content);
	    } else {
	      $LTIGradeMessage = CGI::p("Grade sucessfully saved.");
	    }
	  } else {
	    $LTIGradeMessage = CGI::p("Unable to update LMS grade. Error: ".$response->message);
	    $debug_messages .= CGI::escapeHTML($response->content);
	  }

	  # save parameters for next time
	  $LTIGradeMessage .= CGI::input({type=>'hidden', name=>'lis_outcome_service_url', value=>$request_url});
	  $LTIGradeMessage .= CGI::input({type=>'hidden', name=>'oauth_consumer_key', value=>$consumer_key});
	  $LTIGradeMessage .= CGI::input({type=>'hidden', name=>'oauth_signature_method', value=>$signature_method});
	  $LTIGradeMessage .= CGI::input({type=>'hidden', name=>'lis_result_sourcedid', value=>$sourcedid});
	  
	}

	my $localStorageMessages = CGI::start_div({id=>'local-storage-messages'});
	$localStorageMessages.= CGI::p('Your overall score for this problem is'.'&nbsp;'.CGI::span({id=>'problem-overall-score'},''));
	$localStorageMessages .= CGI::end_div();
		
	my $pretty_print_self  = pretty_print($self);
######################################################
# Return interpolated problem template
######################################################

	my $format_name = $self->{inputs_ref}->{outputformat}//'standard';
	# find the appropriate template in WebworkClient folder
	my $template = do("WebworkClient/${format_name}_format.pl");
	die "Unknown format name $format_name" unless $template;
	# interpolate values into template
	$template =~ s/(\$\w+)/$1/gee;  
	return $template;
}

=back

=cut
######################################################
# Utilities
######################################################


=head2 Utility functions:

=over 4 

=item writeRenderLogEntry()

# $ce - a WeBWork::CourseEnvironment object
# $function - fully qualified function name
# $details - any information, do not use the characters '[' or ']'
# $beginEnd - the string "begin", "intermediate", or "end"
# use the intermediate step begun or completed for INTERMEDIATE
# use an empty string for $details when calling for END
# Information printed in format:
# [formatted date & time ] processID unixTime BeginEnd $function  $details

=cut 

sub writeRenderLogEntry($$$) {
	my ($function, $details, $beginEnd) = @_;
	$beginEnd = ($beginEnd eq "begin") ? ">" : ($beginEnd eq "end") ? "<" : "-";
	WeBWorK::Utils::writeLog($seed_ce, "render_timing", "$$ ".time." $beginEnd $function [$details]");
}

=item pretty_print_self

=cut


sub pretty_print {    # provides html output -- NOT a method
    my $r_input = shift;
    my $level = shift;
    $level = 4 unless defined($level);
    $level--;
    return '' unless $level > 0;  # only print three levels of hashes (safety feature)
    my $out = '';
    if ( not ref($r_input) ) {
    	$out = $r_input if defined $r_input;    # not a reference
    	$out =~ s/</&lt;/g  ;  # protect for HTML output
    } elsif ("$r_input" =~/hash/i) {  # this will pick up objects whose '$self' is hash and so works better than ref($r_iput).
	    local($^W) = 0;
	    
		$out .= "$r_input " ."<TABLE border = \"2\" cellpadding = \"3\" BGCOLOR = \"#FFFFFF\">";
		
		
		foreach my $key ( sort ( keys %$r_input )) {
			$out .= "<tr><TD> $key</TD><TD>=&gt;</td><td>&nbsp;".pretty_print($r_input->{$key}) . "</td></tr>";
		}
		$out .="</table>";
	} elsif (ref($r_input) eq 'ARRAY' ) {
		my @array = @$r_input;
		$out .= "( " ;
		while (@array) {
			$out .= pretty_print(shift @array, $level) . " , ";
		}
		$out .= " )";
	} elsif (ref($r_input) eq 'CODE') {
		$out = "$r_input";
	} else {
		$out = $r_input;
		$out =~ s/</&lt;/g; # protect for HTML output
	}
	
	return $out." ";
}

=back

=cut
1;
