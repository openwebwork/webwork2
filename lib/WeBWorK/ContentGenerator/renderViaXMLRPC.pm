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

##################################################
#  configuration section  -- point back to the current server to process answers
##################################################
# configure the local output file and display command !!!!!!!!

# the rest can be configured later to use a different server 

my $use_local = 0;
our ($PROTOCOL,$HOSTNAME, $HOSTPORT, $FULL_URL,$FORM_ACTION_URL, $XML_PASSWORD, $XML_COURSE);
if ($use_local) {
	# the rest can work!!
	$PROTOCOL         =  'http';
	$HOSTNAME         =  'localhost'; 
	$HOSTPORT         =  80;
	$XML_PASSWORD     =  'xmlwebwork';
	$XML_COURSE       =  'daemon_course';
} else {
	$PROTOCOL         =  'https';                         # or 'https';
	$HOSTNAME         =  "hosted2.webwork.rochester.edu"; # 'localhost'; 
	$HOSTPORT         =  443;  #( for secure https)       # 80 or 443;
	$XML_PASSWORD     = 'xmlwebwork';
	$XML_COURSE       = 'daemon_course';

}


$FULL_URL         =  "$PROTOCOL://$HOSTNAME:$HOSTPORT";


use constant DISPLAYMODE   => 'images'; #  jsMath  is another possibilities.


our @COMMANDS = qw( listLibraries    renderProblem  ); #listLib  readFile tex2pdf 


##################################################
# end configuration section
##################################################


sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
    my $db = new WeBWorK::DB($r->ce->{dbLayout});
    my $xmlrpc_client = new WebworkClient;

	$xmlrpc_client->{encodedSource} = $r->param('problemSource') ; # this source has already been encoded
	$xmlrpc_client->url($FULL_URL);
	$xmlrpc_client->{displayMode}   = DISPLAYMODE();
	$xmlrpc_client->{user}          = 'xmluser';
	$xmlrpc_client->{password}      = $XML_PASSWORD;
	$xmlrpc_client->{course}        = $XML_COURSE;
	my %inputs_ref;
	foreach my $key ( keys %{ $r->{paramcache} } ) {
		$inputs_ref{$key} = $r->param("$key");
	}
	$xmlrpc_client->{inputs_ref} = \%inputs_ref;
	# print STDERR WebworkClient::pretty_print($r->{paramcache});
	if ( $xmlrpc_client->xmlrpcCall('renderProblem') )    {
		$self->{output} = $xmlrpc_client->formatRenderedProblem;
	} else {
		$self->{output} = $xmlrpc_client->{output};  # error report
	}
 }

sub content {
	my $self = shift;
	print $self->{output};
}

##################################################
# end input/output section
##################################################


# our $result;
# 
# ##################################################
# # Utilities -- 
# #    this code is identical between renderProblem.pl and renderViaXMLRPC.pm
# ##################################################
# 
# sub xmlrpcCall {
# 	my $self        = shift;
# 	my $command     = shift;
# 	$command        = 'listLibraries' unless $command;
# 
# 	  my $requestResult = TRANSPORT_METHOD
# 	        #->uri('http://'.HOSTNAME.':'.HOSTPORT.'/'.REQUEST_CLASS)
# 			-> proxy($FULL_URL.'/'.REQUEST_URI);
#      
# 	  my $input = $self->setInputTable();
# 	  local( $result);
# 	  # use eval to catch errors
# 	  eval { $result = $requestResult->call(REQUEST_CLASS.'.'.$command,$input) };
# 	  print STDERR "There were a lot of errors\n" if $@;
# 	  print STDERR "Errors: \n $@\n End Errors\n" if $@;
# 	  
# 	  	
# 
# 	  
# 	  unless (ref($result) and $result->fault) {    	
# 	  	my $rh_result = $result->result();
# 	    #print STDERR pretty_print($rh_result);
# 		$self->{output} = $self->formatRenderedProblem($rh_result);
# 
# 	  } else {
# 		$self->{output} = 'Error from server: ', join( ",\n ",
# 		  $result->faultcode,
# 		  $result->faultstring);
# 	  }
# }
#   
# sub encodeSource {
# 	my $source = shift;
# 	encode_base64($source);
# }
# 
# 
# sub pretty_print_rh { 
#     shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
# 	my $rh = shift;
# 	my $indent = shift || 0;
# 	my $out = "";
# 	my $type = ref($rh);
# 
# 	if (defined($type) and $type) {
# 		$out .= " type = $type; ";
# 	} elsif (! defined($rh )) {
# 		$out .= " type = UNDEFINED; ";
# 	}
# 	return $out." " unless defined($rh);
# 	
# 	if ( ref($rh) =~/HASH/ or "$rh" =~/HASH/ ) {
# 	    $out .= "{\n";
# 	    $indent++;
#  		foreach my $key (sort keys %{$rh})  {
#  			$out .= "  "x$indent."$key => " . pretty_print_rh( $rh->{$key}, $indent ) . "\n";
#  		}
#  		$indent--;
#  		$out .= "\n"."  "x$indent."}\n";
# 
#  	} elsif (ref($rh)  =~  /ARRAY/ or "$rh" =~/ARRAY/) {
#  	    $out .= " ( ";
#  		foreach my $elem ( @{$rh} )  {
#  		 	$out .= pretty_print_rh($elem, $indent);
#  		
#  		}
#  		$out .=  " ) \n";
# 	} elsif ( ref($rh) =~ /SCALAR/ ) {
# 		$out .= "scalar reference ". ${$rh};
# 	} elsif ( ref($rh) =~/Base64/ ) {
# 		$out .= "base64 reference " .$$rh;
# 	} else {
# 		$out .=  $rh;
# 	}
# 	
# 	return $out." ";
# }
# 
# sub setInputTable_for_listLib {
# 	my $self = shift;
# 	my $out = {
# 		pw          =>   XML_PASSWORD,
# 		set         =>   'set0',
# 		library_name =>  'Library',
# 		command      =>  'all',
# 	};
# 
# 	$out;
# }
# sub setInputTable {
# 	my $self = shift;
# 	my $out = {
# 		pw          =>   XML_PASSWORD,
# 		library_name =>  'Library',
# 		command      =>  'renderProblem',
# 		answer_form_submitted   => 1,
# 		course                  => XML_COURSE(),
# 		extra_packages_to_load  => [qw( AlgParserWithImplicitExpand Expr
# 		                                ExprWithImplicitExpand AnswerEvaluator
# 		                                AnswerEvaluatorMaker 
# 		)],
# 		mode                    => DISPLAYMODE(),
# 		modules_to_evaluate     => [ qw( 
# Exporter
# DynaLoader								
# GD
# WWPlot
# Fun
# Circle
# Label								
# PGrandom
# Units
# Hermite
# List								
# Match
# Multiple
# Select							
# AlgParser
# AnswerHash							
# Fraction
# VectorField							
# Complex1
# Complex							
# MatrixReal1 Matrix							
# Distributions
# Regression
# 
# 		)], 
# 		envir                   => $self->environment(),
# 		problem_state           => {
# 		
# 			num_of_correct_ans  => 2,
# 			num_of_incorrect_ans => 4,
# 			recorded_score       => 1.0,
# 		},
# 		source                   => $self->{encodedSource},  #base64 encoded
# 		
# 		
# 		
# 	};
# 
# 	$out;
# }
# 
# sub environment {
# 	my $self = shift;
# 	my $envir = {
# 		answerDate  => '4014438528',
# 		CAPA_Graphics_URL=>"not defined",
# 		CAPA_GraphicsDirectory =>"not defined",
# 		CAPA_MCTools=>"not defined",
# 		CAPA_Tools=>'not defined',
# 		cgiDirectory=>'Not defined',
# 		cgiURL => 'Not defined',
# 		classDirectory=> 'Not defined',
# 		courseName=>'Not defined',
# 		courseScriptsDirectory=>'not defined',
# 		displayMode=>DISPLAYMODE,
# 		dueDate=> '4014438528',
# 		externalGif2EpsPath=>'not defined',
# 		externalPng2EpsPath=>'not defined',
# 		externalTTHPath=>'/usr/local/bin/tth',
# 		fileName=>'set0/prob1a.pg',
# 		formattedAnswerDate=>'6/19/00',
# 		formattedDueDate=>'6/19/00',
# 		formattedOpenDate=>'6/19/00',
# 		functAbsTolDefault=> 0.0000001,
# 		functLLimitDefault=>0,
# 		functMaxConstantOfIntegration=> 1000000000000.0,
# 		functNumOfPoints=> 5,
# 		functRelPercentTolDefault=> 0.000001,
# 		functULimitDefault=>1,
# 		functVarDefault=> 'x',
# 		functZeroLevelDefault=> 0.000001,
# 		functZeroLevelTolDefault=>0.000001,
# 		htmlDirectory =>'not defined',
# 		htmlURL =>'not defined',
# 		inputs_ref => $self->{inputs_ref},
# 		macroDirectory=>'not defined',
# 		numAbsTolDefault=>0.0000001,
# 		numFormatDefault=>'%0.13g',
# 		numOfAttempts=> 0,
# 		numRelPercentTolDefault => 0.0001,
# 		numZeroLevelDefault =>0.000001,
# 		numZeroLevelTolDefault =>0.000001,
# 		openDate=> '3014438528',
# 		PRINT_FILE_NAMES_FOR => [ 'gage'],
# 		probFileName => 'set0/prob1a.pg',
# 		problemSeed  => 1234,
# 		problemValue =>1,
# 		probNum => 13,
# 		psvn => 54321,
# 		psvnNumber=> 54321,
# 		questionNumber => 1,
# 		scriptDirectory => 'Not defined',
# 		sectionName => 'Gage',
# 		sectionNumber => 1,
# 		sessionKey=> 'Not defined',
# 		setNumber =>'not defined',
# 		studentLogin =>'gage',
# 		studentName => 'Mike Gage',
# 		tempDirectory => 'not defined',
# 		templateDirectory=>'not defined',
# 		tempURL=>'not defined',
# 		webworkDocsURL => 'not defined',
# 	};
# 	$envir;
# };
# 
# sub formatAnswerRow {
# 	my $self = shift;
# 	my $rh_answer = shift;
# 	my $problemNumber = shift;
# 	my $answerString  = $rh_answer->{original_student_ans}||'&nbsp;';
# 	my $correctAnswer = $rh_answer->{correct_ans}||'';
# 	my $ans_message   = $rh_answer->{ans_message};
# 	my $score         = ($rh_answer->{score}) ? 'Correct' : 'Incorrect';
# 	my $row = qq{
# 		<tr>
# 		    <td>
# 				Prob: $problemNumber
# 			</td>
# 			<td>
# 				$answerString
# 			</td>
# 			<td>
# 			    $score
# 			</td>
# 			<td>
# 				Correct answer is $correctAnswer
# 			</td>
# 			<td>
# 				<i>$ans_message</i>
# 			</td>
# 		</tr>\n
# 	};
# 	$row;
# }
# 	
# sub formatRenderedProblem {
# 	my $self 			  = shift;
# 	my $rh_result         = shift;  # wrap problem in formats
# 	my $problemText       = decode_base64($rh_result->{text});
# 	my $rh_answers        = $rh_result->{answers};
# 	my $encodedSource     = $self->{encodedSource}||'foobar';
# 	my $warnings          = '';
# 	if ( defined ($rh_result->{WARNINGS}) and $rh_result->{WARNINGS} ){
# 		$warnings = "<div style=\"background-color:pink\">
# 		             <p >WARNINGS</p><p>".decode_base64($rh_result->{WARNINGS})."</p></div>";
# 	}
# 	
# 	         ;
# 	# collect answers
# 	my $answerTemplate    = q{<hr>ANSWERS <table border="3" align="center">};
# 	my $problemNumber     = 1;
#     foreach my $key (sort  keys %{$rh_answers}) {
#     	$answerTemplate  .= $self->formatAnswerRow($rh_answers->{$key}, $problemNumber++);
#     }
# 	$answerTemplate      .= q{</table> <hr>};
# 
# 	
# 
# 	my $problemTemplate = <<ENDPROBLEMTEMPLATE;
# <html>
# <head>
# <title>WeBWorK Editor</title>
# </head>
# <body>
# 		    $answerTemplate
# 		    $warnings
# 		    <form action="$FORM_ACTION_URL" method="post">
# 			$problemText
# 	       <input type="hidden" name="answersSubmitted" value="1"> 
# 	       <input type="hidden" name="problemAddress" value="probSource"> 
# 	       <input type="hidden" name="problemSource" value="$encodedSource"> 
# 	       <input type="hidden" name="problemSeed" value="1234"> 
# 	       <input type="hidden" name="pathToProblemFile" value="foobar">
# 	       <p><input type="submit" name="submit" value="submit answers"></p>
# 	     </form>
# </body>
# </html>
# 
# ENDPROBLEMTEMPLATE
# 
# 
# 
# 	$problemTemplate;
# }
# 

1;
