#!/usr/bin/perl -w
use MIME::Base64 qw( encode_base64 decode_base64);


# -- SOAP::Lite -- soaplite.com -- Copyright (C) 2001 Paul Kulchenko --

# use XMLRPC::Lite;
# 
# print XMLRPC::Lite
#   -> proxy('http://devel.webwork.rochester.edu:11002/mod_xmlrpc')
#   -> call('Demo:bye', 25)
#   -> result;
print STDERR "inputs are ", join (" | ", @ARGV), "\n";
our $source;

if (@ARGV) {
    my $command = $ARGV[0];
    
    warn "executing WebworkXMLRPC.$command";
    $source = `cat $ARGV[1]`;
	xmlrpcCall($command);


} else {

	print STDERR "Useage: .xmlrpc_client4.pl command   file_name";
	
}






sub xmlrpcCall {
	my $command = shift;
	$command   = 'listLibraries' unless $command;
	use XMLRPC::Lite;
	  my $xmlrpc = XMLRPC::Lite
	   # ->uri('http://webwork-db.math.rochester.edu/Demo/')
			-> proxy('http://devel.webwork.rochester.edu:11002/mod_xmlrpc');
		
	  my $test = [3,4,5,6];     
	  my $input = setInputTable();
	  local( $result);
	  eval { $result = $xmlrpc->call("WebworkXMLRPC.$command",$input) };
	  print STDERR "There were a lot of errors" if $@;
	  print "Errors: \n $@\n End Errors\n" if $@;
	
	  
	
	  unless (ref($result) and $result->fault) {
	  	if (defined($result->result()->{text}) ) {
	  		$result->result()->{text} = decode_base64($result->result()->{text});
	  	}
		print  pretty_print_rh($result->result()),"\n";  #$result->result()
	  } else {
		print 'oops ', join ', ',
		  $result->faultcode,
		  $result->faultstring;
	  }
}
  
sub source {
	encode_base64($source);
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

sub setInputTable_for_listLib {
	$out = {
		#password    =>  'geometry',
		pw          =>   'geometry',
		set         =>   'set0',
		library_name =>  'rochesterLibrary',
		command      =>  'all',
	};

	$out;
}
sub setInputTable {
	$out = {
		#password    =>  'geometry',
		pw          =>   'geometry',
		set         =>   'set0',
		library_name =>  'rochesterLibrary',
		command      =>  'all',
		answer_form_submitted   => 1,
		course                  => 'daemon_course',
		extra_packages_to_load  => [qw( AlgParserWithImplicitExpand Expr
		                                ExprWithImplicitExpand AnswerEvaluator
		                                AnswerEvaluatorMaker 
		)],
		mode                    => undef,
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
		envir                   => environment(),
		problem_state           => {
		
			num_of_correct_ans  => 2,
			num_of_incorrect_ans => 4,
			recorded_score       => 1.0,
		},
		source                   => source(),  #base64 encoded
		
		
		
	};

	$out;
}

sub environment {
	my $envir = {
		answerDate  => '4014438528',
		CAPA_Graphics_URL=>'http://webwork-db.math.rochester.edu/capa_graphics/',
		CAPA_GraphicsDirectory =>'/ww/webwork/CAPA/CAPA_Graphics/',
		CAPA_MCTools=>'/ww/webwork/CAPA/CAPA_MCTools/',
		CAPA_Tools=>'/ww/webwork/CAPA/CAPA_Tools/',
		cgiDirectory=>'Not defined',
		cgiURL => 'Not defined',
		classDirectory=> 'Not defined',
		courseName=>'Not defined',
		courseScriptsDirectory=>'/ww/webwork/system/courseScripts/',
		displayMode=>'HTML_dpng',
		dueDate=> '4014438528',
		externalGif2EpsPath=>'not defined',
		externalPng2EpsPath=>'not defined',
		externalTTHPath=>'/usr/local/bin/tth',
		fileName=>'set0/prob1a.pg',
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
		htmlDirectory =>'/ww/webwork/courses/gage_course/html/',
		htmlURL =>'http://webwork-db.math.rochester.edu/gage_course/',
		inputs_ref => {
				 AnSwEr1 => '',
				 AnSwEr2 => '',
				 AnSwEr3 => '',
		},
		macroDirectory=>'/ww/webwork/courses/gage_course/templates/macros/',
		numAbsTolDefault=>0.0000001,
		numFormatDefault=>'%0.13g',
		numOfAttempts=> 0,
		numRelPercentTolDefault => 0.0001,
		numZeroLevelDefault =>0.000001,
		numZeroLevelTolDefault =>0.000001,
		openDate=> '3014438528',
		PRINT_FILE_NAMES_FOR => [ 'gage'],
		probFileName => 'set0/prob1a.pg',
		problemSeed  => 1234,
		problemValue =>1,
		probNum => 13,
		psvn => 54321,
		psvnNumber=> 54321,
		questionNumber => 1,
		scriptDirectory => 'Not defined',
		sectionName => 'Gage',
		sectionNumber => 1,
		sessionKey=> 'Not defined',
		setNumber =>'MAAtutorial',
		studentLogin =>'gage',
		studentName => 'Mike Gage',
		tempDirectory => '/ww/htdocs/tmp/gage_course/',
		templateDirectory=>'/ww/webwork/courses/gage_course/templates/',
		tempURL=>'http://webwork-db.math.rochester.edu/tmp/gage_course/',
		webworkDocsURL => 'http://webwork.math.rochester.edu/webwork_gage_system_html',
	};
	$envir;
};