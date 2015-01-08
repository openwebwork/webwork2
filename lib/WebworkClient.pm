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

webwork2/clients/WebworkClient.pm

This script will take a file and send it to a WeBWorK daemon webservice
to have it rendered.  The result is split into the basic HTML rendering
and evaluation of answers and then passed to a browser for printing.

The formatting allows the browser presentation to be interactive with the 
daemon running the script webwork2/lib/renderViaXMLRPC.pm

Rembember to configure the local output file and display command !!!!!!!!

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

#use Crypt::SSLeay;  # needed for https
use XMLRPC::Lite;
use MIME::Base64 qw( encode_base64 decode_base64);

use constant  TRANSPORT_METHOD => 'XMLRPC::Lite';
use constant  REQUEST_CLASS    => 'WebworkXMLRPC';  # WebworkXMLRPC is used for soap also!!
use constant  REQUEST_URI      => 'mod_xmlrpc';

our $UNIT_TESTS_ON             = 0;

# error formatting
sub format_hash_ref {
	my $hash = shift;
	warn "Use a hash reference" unless ref($hash) =~/HASH/;
	return join(" ", map {$_="--" unless defined($_);$_ } %$hash),"\n";
}

sub new {
    my $invocant = shift;
    my $class = ref $invocant || $invocant;
	my $self = {
		output   		=> '',
		encodedSource 	=> '',
		url             => '',
		password        => '',
		course          => '',
		displayMode     => '',
		inputs_ref      => {		 AnSwEr0001 => '',
				 					 AnSwEr0002 => '',
				 					 AnSwEr0003 => '',
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



sub xmlrpcCall {
	my $self = shift;
	my $command = shift;
	my $input   = shift||{};

	$command   = 'listLibraries' unless defined $command;
	  my $input2 = $self->setInputTable();
	  $input = {%$input2, %$input};
	
	my $requestResult; 
	my $transporter = TRANSPORT_METHOD->new;

	eval {
	    $requestResult= $transporter
	        #->uri('http://'.HOSTURL.':'.HOSTPORT.'/'.REQUEST_CLASS)
		#-> proxy(PROTOCOL.'://'.HOSTURL.':'.HOSTPORT.'/'.REQUEST_URI);
		-> proxy(($self->url).'/'.REQUEST_URI);
	};
	print STDERR "WebworkClient: Initiating xmlrpc request to url ",($self->url).'/'.REQUEST_URI, " \n Error: $@\n" if $@;
	# turn of verification of the ssl cert 
	$transporter->transport->ssl_opts(verify_hostname=>0,
	    SSL_verify_mode => 'SSL_VERIFY_NONE');
			
    if ($UNIT_TESTS_ON) {
        print STDERR  "WebworkClient.pm ".__LINE__." xmlrpcCall sent to ", $self->{url},"\n";
    	print STDERR  "WebworkClient.pm ".__LINE__." xmlrpcCall issued with command $command\n";
    	print STDERR  "WebworkClient.pm ".__LINE__." input is: ",join(" ", %$input),"\n";
    	print STDERR  "WebworkClient.pm ".__LINE__." xmlrpcCall $command initiated webwork webservice object $requestResult\n";
    }
 		
	  local( $result);
	  # use eval to catch errors
	  #print STDERR "WebworkClient: issue command ", REQUEST_CLASS.'.'.$command, " ",join(" ", %$input),"\n";
	  eval { $result = $requestResult->call(REQUEST_CLASS.'.'.$command, $input) };
	  print STDERR "There were a lot of errors\n" if $@;
	  print "Errors: \n $@\n End Errors\n" if $@;
	  	
	  unless (ref($result) and $result->fault) {
	  
	  	if (ref($result->result())=~/HASH/ and defined($result->result()->{text}) ) {
	  		$result->result()->{text} = decode_base64($result->result()->{text});
	  	}
		#print  pretty_print($result->result()),"\n";  #$result->result()
		$self->{output}= $result->result();
		return $result->result();
	  } else {
		print STDERR 'Error message for ', 
		  join( ', ',
			  "command:",
			  $command,
			  "\nfaultcode:",
			  $result->faultcode, 
			  "\nfaultstring:",
			  $result->faultstring, "\nEnd error message\n"
		  );
		  return undef;
	  }
}

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
		$self->{output} = $rh_result; #$self->formatRenderedProblem($rh_result);
		return 1; # success

	  } else {
		$self->{output} = 'Error from server: '. join( ",\n ",
		  $result->faultcode,
		  $result->faultstring);
		return 0; #failure
	  }
}
  
sub encodeSource {
	my $self = shift;
	my $source = shift;
	$self->{encodedSource} =encode_base64($source);
}
sub url {
	my $self = shift;
	my $new_url = shift;
	$self->{url} = $new_url if defined($new_url) and $new_url =~ /\S/;
	$self->{url};
}
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

sub setInputTable_for_listLib {
	my $self = shift;
	my $out = {
		pw          =>   $self->{password},
		set         =>   'set0',
		library_name =>  'Library',
		command      =>  'all',
	};

	$out;
}
sub setInputTable {
	my $self = shift;
	my $out = {
		pw          =>   $self->{password},
		library_name =>  'Library',
		command      =>  'renderProblem',
		answer_form_submitted   => 1,
		course                  => $self->{course},
		extra_packages_to_load  => [qw( AlgParserWithImplicitExpand Expr
		                                ExprWithImplicitExpand AnswerEvaluator
		                                AnswerEvaluatorMaker 
		)],
		mode                    => $self->{displayMode},
		modules_to_evaluate     => [ qw( 
Exporter
DynaLoader								
GD
WWPlot
Fun
Circle
Label								
PGrandom
Units
Hermite
List								
Match
Multiple
Select							
AlgParser
AnswerHash							
Fraction
VectorField							
Complex1
Complex							
MatrixReal1 Matrix							
Distributions
Regression

		)], 
		envir                   => $self->environment(),
		problem_state           => {
		
			num_of_correct_ans  => 0,
			num_of_incorrect_ans => 4,
			recorded_score       => 1.0,
		},
		source                   => $self->{encodedSource},  #base64 encoded
		
		
		
	};

	$out;
}

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
		displayMode=>$self->{displayMode},
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
		problemSeed  => 1234,
		problemValue =>1,
		probNum => 13,
		psvn => 54321,
		psvn=> 54321,
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
		
	};
	$envir;
};

sub formatAnswerRow {
	my $self = shift;
	my $rh_answer = shift;
	my $problemNumber = shift;
	my $answerString  = $rh_answer->{original_student_ans}||'&nbsp;';
	my $correctAnswer = $rh_answer->{correct_ans}||'';
	my $ans_message   = $rh_answer->{ans_message}||'';
	my $score         = ($rh_answer->{score}) ? 'Correct' : 'Incorrect';
	my $row = qq{
		<tr>
		    <td>
				Prob: $problemNumber
			</td>
			<td>
				$answerString
			</td>
			<td>
			    $score
			</td>
			<td>
				Correct answer is $correctAnswer
			</td>
			<td>
				<i>$ans_message</i>
			</td>
		</tr>\n
	};
	$row;
}
	
sub formatRenderedLibraries {
	my $self 			  = shift;
	#my @rh_result         = @{$self->{output}};  # wrap problem in formats
	my %rh_result         = %{$self->{output}};
	my $result = "";
	foreach my $key (sort  keys %rh_result) {
		$result .= "$key";
		$result .= $rh_result{$key};
	}
    return $result;
}

sub formatRenderedProblem {
	my $self 			  = shift;
	my $rh_result         = $self->{output}|| {};  # wrap problem in formats
	my $problemText       = "No output from rendered Problem";
	if (ref($rh_result) and $rh_result->{text} ) {
		$problemText       =  $rh_result->{text};
	} else {
		$problemText       = "Unable to decode problem text",format_hash_ref($rh_result);
	}
	my $rh_answers        = $rh_result->{answers};
	my $encodedSource     = $self->{encodedSource}||'encodedSourceIsMissing';
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
    
    my $fileName = $self->{input}->{envir}->{fileName} || "Can't find file name";
	# collect answers
	my $answerTemplate    = q{<hr>ANSWERS <table border="3" align="center">};
	my $problemNumber     = 1;
    foreach my $key (sort  keys %{$rh_answers}) {
    	$answerTemplate  .= $self->formatAnswerRow($rh_answers->{$key}, $problemNumber++);
    }
	$answerTemplate      .= q{</table> <hr>};

	my $test = pretty_print($rh_result);
	my $XML_URL      = $self->url;
	my $FORM_ACTION_URL  =  $self->{form_action_url};
	my $courseID         =  $self->{courseID};
	my $userID           =  $self->{userID};
	my $session_key      =  $rh_result->{session_key};
	my $problemTemplate = <<ENDPROBLEMTEMPLATE;


<html>
<head>
<base href="$XML_URL">
<title>$XML_URL WeBWorK Editor using host $XML_URL</title>
</head>
<body>

<h2> WeBWorK Editor using host $XML_URL</h2>
		    $answerTemplate
		    <form action="$FORM_ACTION_URL" method="post">
			$problemText
	       <input type="hidden" name="answersSubmitted" value="1"> 
	       <input type="hidden" name="problemAddress" value="probSource"> 
	       <input type="hidden" name="problemSource" value="$encodedSource"> 
	       <input type="hidden" name="problemSeed" value="1234"> 
	       <input type="hidden" name="pathToProblemFile" value="$fileName">
	       <input type="hidden" name=courseName value="$courseID">
	       <input type="hidden" name=courseID value="$courseID">
	       <input type="hidden" name="userID" value="$userID">
	       <input type="hidden" name="session_key" value="$session_key">
	       <p><input type="submit" name="submit" value="submit answers"></p>
	     </form>
<HR>
<h3> Perl warning section </h3>
$warnings
<h3> PG Warning section </h3>
$PG_warning_messages;
<h3> Debug message section </h3>
$debug_messages
<h3> internal errors </h3>
$internal_debug_messages

</body>
</html>

ENDPROBLEMTEMPLATE



	$problemTemplate;
}


1;
