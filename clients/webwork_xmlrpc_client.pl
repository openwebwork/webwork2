#!/usr/bin/perl -w

=pod

This script will take a command and an input 
file.

It will list available libraries, list the contents of libraries
or render the input file.

All of this is done by contacting the webservice.



=cut

use feature ":5.10";
use lib "/opt/webwork/webwork2/lib";
use WebworkClient;
use XMLRPC::Lite;
use MIME::Base64 qw( encode_base64 decode_base64);

#  configuration section
use constant  PROTOCOL         =>  'http';   # or 'http';
use constant  HOSTURL          =>  'localhost'; 
use constant  HOSTPORT         =>  '80';  # or 80
use constant  TRANSPORT_METHOD =>  'XMLRPC::Lite';
use constant  REQUEST_CLASS    =>  'WebworkXMLRPC';  # WebworkXMLRPC is used for soap also!!
use constant  REQUEST_URI      =>  'mod_xmlrpc';
use constant  TEMPOUTPUTFILE   =>  '/Users/gage/Desktop/renderProblemOutput.html';

our	$XML_URL      =  'http://localhost:80';
our	$FORM_ACTION_URL  =  'http://localhost:80/webwork2/html2xml';
our	$XML_PASSWORD     =  'xmlwebwork';
our	$XML_COURSE       =  'gage_course';

our $UNIT_TESTS_ON             = 0;

my $credential_path = ".ww_credentials";
eval{require $credential_path};
if ($@ ) {
print STDERR <<EOF;
Can't find file .ww_credentials:
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


# print "credentials: ", join(" | ", %credentials), "\n";

my @COMMANDS = qw( listLibraries    renderProblem   listLib  readFile tex2pdf );

use constant DISPLAYMODE   => 'images';


# end configuration section

our $courseName = $credentials{courseID};

print STDERR "inputs are ", join (" | ", @ARGV), "\n";
our $source;

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
# initialize client with source
# $xmlrpc_client->encodeSource($source);

# prepare additional input values



if (@ARGV) {
    my $command = $ARGV[0];
    my $result;
    print  "executing WebworkXMLRPC.$command \n\n-----------------------\n\n";
    given($command) {
    	when ('renderProblem') { 
			if ( defined $ARGV[1])  {
				if (-r $ARGV[1] ) {
					 $source = `cat $ARGV[1]`;
					 $xmlrpc_client->encodeSource($source);
					 my $input = { password    	 =>   $credentials{password},};
					 $result = $xmlrpc_client->xmlrpcCall($command, $input);
					 print pretty_print_rh($result);
				} else {
					print STDERR  "Can't read source file $ARGV[1]\n";
				}
			  } else {
				  print STDERR "Useage: ./webwork_xmlrpc_client.pl command   <file_name>\n";
			  }
    	} when ('listLibraries') {
			my $input = { password    	 =>   $credentials{password},};
			$result = $xmlrpc_client->xmlrpcCall($command, $input);
			if (defined($result) ) {
				my @lib_array = @ { $result->{ra_out} };
				print STDOUT "The  libraries available in course $courseName are:\n\t ", join("\n\t ", @lib_array ), "\n";
			} else {
				print STDOUT "No libraries available for course $courseName\n";
			}
    	} when ('listLib')       {
			 $result = listLib( @ARGV );
			 my $command = $ARGV[1];
			 
			 print pretty_print_rh($result);
    							 	
    	} when ('listSets')      {
	 		$input = {		site_password    =>   'xmluser',
							password    	 =>   $credentials{password},
        					user        	 =>   $credentials{userID},
        					courseID    	 =>   $credentials{courseID},
        			 };
	  		my $result   =   $xmlrpc_client->xmlrpcCall($command, $input);
	  		print pretty_print_rh($result);
	  	} when ('readFile') {
	  		print STDERR "Command $command not yet implemented\n"
    	} when ('tex2pdf') {
    		print STDERR "Command $command not yet implemented\n"
    	}
    }


	} else {

	print STDERR "Useage: ./webwork_xmlrpc_client.pl command   [file_name]\n";
	print STDERR "For example: ./webwork_xmlrpc_client.pl renderProblem   <source file: e.g.  input.txt, bad_input.txt \n";
	print STDERR "For example: ./webwork_xmlrpc_client.pl  listLibraries   \n";
	print STDERR "For example: ./webwork_xmlrpc_client.pl listLib all \n";
	print STDERR "For example: ./webwork_xmlrpc_client.pl listLib setsOnly \n";
	print STDERR "For example: ./webwork_xmlrpc_client.pl listLib listSet <setID: e.g. set0> \n";
	print STDERR "Commands are: ", join(" ", @COMMANDS), "\n";
	
}



# sub xmlrpcCall {
# 	my $command = shift;
# 	my $input   = shift||{};
# 	$command   = 'listLibraries' unless defined $command;
#     my $std_input = standard_input();
#    
#     $input = {%$std_input, %$input};  # concatenate and override standard_input 
#     
# 	my $requestResult = TRANSPORT_METHOD
# 		#->uri('http://'.HOSTURL.':'.HOSTPORT.'/'.REQUEST_CLASS)
# 		-> proxy(PROTOCOL.'://'.HOSTURL.':'.HOSTPORT.'/'.REQUEST_URI);
# 		
# 	if ($UNIT_TESTS_ON) {
# 		print STDERR  "WebworkClient.pm ".__LINE__." xmlrpcCall issued with command $command\n";
# 		print STDERR  "WebworkClient.pm ".__LINE__." input is: ",join(" ", %$input);
# 		print STDERR  "WebworkClient.pm ".__LINE__." xmlrpcCall $command returned $requestResult\n";
# 	}
# 	local( $result);
# 	# use eval to catch errors
# 	eval { $result = $requestResult->call(REQUEST_CLASS.'.'.$command,$input) };
# 	print STDERR "There were a lot of errors\n" if $@;
# 	print "Errors: \n $@\n End Errors\n" if $@;
# 	
# 	
# 	unless (ref($result) and $result->fault) {
# 	
# 		if (ref($result->result())=~/HASH/ and defined($result->result()->{text}) ) {
# 			$result->result()->{text} = decode_base64($result->result()->{text});
# 		}
# 		print  pretty_print_rh($result->result()),"\n"if $UNIT_TESTS_ON;
# 		$self->{output} = $result->result();
# 		$self->{session_key}=$self->{output}->{session_key}; # update session key
# 		return $result->result();
# 
# 	} else {
# 		print STDERR 'oops ', join ', ',
# 		  "command:",
# 		  $command,
# 		  "\nfaultcode:",
# 		  $result->faultcode, 
# 		  "\nfaultstring:",
# 		  $result->faultstring;
# 		return undef;
# 
# 	}
# }
  
sub source {
	return "" unless $source;
	return encode_base64($source);
}
sub listLib {
	my @ARGS = @_;
	#print "args for listLib are ", join(" ", @ARGS), "\n";
	my $result;
	given($ARGS[1]) { 
		when ("all") { 
			$input = {		site_password    =>   'xmluser',
										password    	 =>   $credentials{password},
        								user        	 =>   $credentials{userID},
        								courseID    	 =>   $credentials{courseID},
        								command     	 =>   'all',
        						};
        	$result = $xmlrpc_client->xmlrpcCall("listLib", $input);
        } 
        when ('dirOnly') { 
            my %options = @ARGS[2..$#ARGS];
            my $path = $options{-path} || '';
            my $maxdepth = defined($options{-depth}) ? $options{-depth}: 10000;
        	$input = {	site_password    =>   'xmluser',
										password    	 =>   $credentials{password},
        								user        	 =>   $credentials{userID},
        								courseID    	 =>   $credentials{courseID},
        								command     	 =>   'dirOnly',
        								dirPath          =>   $path,
        								maxdepth         =>   $maxdepth,
        						};
        	$result = $xmlrpc_client->xmlrpcCall("listLib", $input);
        } 
        when('files') { 
			if ($ARGS[2]  ) { 
				my %options = @ARGS[2..$#ARGS];
            	my $path    = $options{-path} || ''; 
				$input = {		site_password    =>   'xmluser',
								password    	 =>   $credentials{password},
								user        	 =>   $credentials{userID},
								courseID    	 =>   $credentials{courseID},
								command     	 =>   'files',
								dirPath          =>   $path,
							};
				$result = $xmlrpc_client->xmlrpcCall("listLib", $input);
			} else {
				print STDERR "Usage:  webwork_xmlrpc_client listLib files  <path to directory >\n";
				$result = "";							
       		}
       	} 
       	default {print "The possible arguments for listLib are:".  
		                "\n\t all -- print all paths". 
		                "\n\t dirOnly [options]-- print only directories below Library/path".
		                "\n\t\t options:  -depth depth  -path directoryPath".
		                "\n\t\t\t depth counts the number of slashes in the relative path".
		                "\n\t files <path_to_directory> -- print .pg files in the given directory \n".
		                "\n\t\t options:    -path directoryPath";
		          $result = "";
		}
	}
	return $result;
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

sub pretty_print_json { 
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
 			$out .= "  "x$indent."$key => " . pretty_print_json( $rh->{$key}, $indent ) . "\n";
 		}
 		$indent--;
 		$out .= "\n"."  "x$indent."}\n";

 	} elsif (ref($rh)  =~  /ARRAY/ or "$rh" =~/ARRAY/) {
 	    $out .= " ( ";
 		foreach my $elem ( @{$rh} )  {
 		 	$out .= pretty_print_json($elem, $indent);
 		
 		}
 		$out .=  " ) \n";
	} elsif ( ref($rh) =~ /SCALAR/ ) {
		$out .= "scalar reference ". ${$rh};
	} elsif ( ref($rh) =~/Base64/ ) {
		$out .= "base64 reference " .$$rh;
	} else {
		my $jsonString = $rh;
		$jsonString =~ s/(\\|\/)/\./g;
		$out .=  "Library.".$jsonString.";";
	}
	
	return $out." ";
}


sub standard_input {
	$out = {
		site_password           =>   'xmluser',
		password      			=>   $credentials{password},
		userID          		=>   $credentials{userID},
		set               		=>   'set0',
		library_name 			=>  'Library',
		command      			=>  'all',
		answer_form_submitted   => 1,
		courseID                 => $credentials{courseID},,
		extra_packages_to_load  => [qw( AlgParserWithImplicitExpand Expr
		                                ExprWithImplicitExpand AnswerEvaluator
		                                AnswerEvaluatorMaker 
		)],
		mode                    => DISPLAYMODE(),
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
		displayMode=>DISPLAYMODE,
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
		psvn=> 54321,
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
