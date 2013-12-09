################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
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

package WeBWorK::ContentGenerator::instructorXMLHandler;
use base qw(WeBWorK::ContentGenerator);
use MIME::Base64 qw( encode_base64 decode_base64);
use WeBWorK::Debug;

our $UNIT_TESTS_ON      = 0;  # should be called DEBUG??  FIXME

#use Crypt::SSLeay;
#use XMLRPC::Lite;
#use MIME::Base64 qw( encode_base64 decode_base64);


use strict;
use warnings;
use WebworkClient;
use JSON;


=head1 Description


#################################################
  instructorXMLHandler -- a front end for the Webservice that accepts HTML forms

  receives WeBWorK problems presented as HTML forms, usually created with js xmlhttprequests,
  packages the form variables into an XML_RPC request
 suitable for all of the webservices in WebworkWebservices
 returns xml resutls
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

	$XML_PASSWORD     	 =  'xmluser';
	$XML_COURSE          =  'daemon_course';



	$XML_URL             =  "$server_root_url/mod_xmlrpc";
	$FORM_ACTION_URL     =  "$server_root_url/webwork2/instructorXMLHandler";

use constant DISPLAYMODE   => 'images'; #  Mathjax  is another possibilities.



our @COMMANDS = qw( listLibraries    renderProblem  ); #listLib  readFile tex2pdf 


# error formatting
sub format_hash_ref {
	my $hash = shift;
	warn "Use a hash reference".caller() unless ref($hash) =~/HASH/;
	my $out_str="";
	my $count =4;
	foreach my $key ( sort keys %$hash) {
		my $value = defined($hash->{$key})? $hash->{$key}:"--";
		$out_str.= " $key=>$value ";
		$count--;
		unless($count) { $out_str.="\n  ";$count =4;}
	}
	$out_str;
}
# template method
sub templateName {
	return "";
}
##################################################
# end configuration section
##################################################


sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
 
 	# debug($r->param("visible"));	
 
 
 
    #######################
    #  setup xmlrpc client
    #######################
    my $xmlrpc_client = new WebworkClient;

	$xmlrpc_client->url($XML_URL);
	$xmlrpc_client->{form_action_url}= $FORM_ACTION_URL;
	$xmlrpc_client->{displayMode}   = DISPLAYMODE();
	$xmlrpc_client->{user}          = 'xmluser';
	$xmlrpc_client->{password}      = $XML_PASSWORD;
	$xmlrpc_client->{course}        = $r->param('courseID');
	# print STDERR WebworkClient::pretty_print($r->{paramcache});
	
	my $input = {#can I just use $->param? it looks like a hash

		    pw                      => $r->param('pw') ||undef,
		    session_key             => $r->param("session_key") ||undef,
		    userID                  => $r->param("user") ||undef,
		    library_name            => $r->param("library_name") ||undef,
		    user        	        => $r->param("user") ||undef,
		    set                     => $r->param("set") ||undef,
		    fileName                => $r->param("file_name") ||undef,
		    new_set_name	        => $r->param("new_set_name") ||undef,
		    probList		        => $r->param("probList") ||undef,
		    command     	        => $r->param("command") ||undef,
		    subcommand		        => $r->param("subcommand") ||undef,
		    maxdepth		        => $r->param("maxdepth") || 0,
		    problemSeed	            => $r->param("problemSeed") || 0,
		    displayMode	            => $r->param("displayMode") || undef,
		    noprepostambles	        => $r->param("noprepostambles") || undef,
		    library_subjects	    => $r->param("library_subjects") ||undef,
		    library_chapters	    => $r->param("library_chapters") ||undef,
		    library_sections	    => $r->param("library_sections") ||undef,
		    library_levels		    => $r->param("library_levels") ||undef,
		    library_textbook	    => $r->param("library_textbook") ||undef,
		    library_keywords	    => $r->param("library_keywords") ||undef,
		    library_textchapter     => $r->param("library_textchapter") ||undef,
		    library_textsection     => $r->param("library_textsection") ||undef,
		    source			        =>  '',

		     #course stuff
		    first_name       		=> $r->param('first_name') || undef,
            last_name       		=> $r->param('last_name') || undef,
            student_id     			=> $r->param('student_id') || undef,
            id             			=> $r->param('user_id') || undef,
            email_address  			=> $r->param('email_address') || undef,
            permission     			=> $r->param('permission') || 0,	# valid values from %userRoles in defaults.config
            status         			=> $r->param('status') || undef,#'Enrolled, audit, proctor, drop
            section        			=> $r->param('section') || undef,
            recitation     			=> $r->param('recitation') || undef,
            comment        			=> $r->param('comment') || undef,
            new_password   			=> $r->param('new_password') || undef,
            userpassword   			=> $r->param('userpassword') || undef,	# defaults to studentid if empty
	     	set_props	    		=> $r->param('set_props') || undef,
	     	set_id	    			=> $r->param('set_id') || undef,
	     	due_date	    		=> $r->param('due_date') || undef,
	     	set_header     		   	=> $r->param('set_header') || undef,
	        hardcopy_header 	   	=> $r->param('hardcopy_header') || undef,
	     	open_date       	   	=> $r->param('open_date') || undef,
            due_date        	   	=> $r->param('due_date') || undef,
            answer_date     	   	=> $r->param('answer_date') || undef,
            visible         	   	=> $r->param('visible') || 0,
            enable_reduced_scoring 	=> $r->param('enable_reduced_scoring') || 0,
            assignment_type        	=> $r->param('assignment_type') || undef,
            attempts_per_version   	=> $r->param('attempts_per_version') || undef,
            time_interval         	=> $r->param('time_interval') || undef,
            versions_per_interval  	=> $r->param('versions_per_interval') || undef,
            version_time_limit     	=> $r->param('version_time_limit') || undef,
            version_creation_time  	=> $r->param('version_creation_time') || undef,
            problem_randorder      	=> $r->param('problem_randorder') || undef,
            version_last_attempt_time => $r->param('version_last_attempt_time') || undef,
            problems_per_page      	=> $r->param('problems_per_page') || undef,
            hide_score             	=> $r->param('hide_score') || undef,
            hide_score_by_problem  	=> $r->param('hide_score_by_problem') || undef,
            hide_work              	=> $r->param('hide_work') || undef,
            time_limit_cap         	=> $r->param('time_limit_cap') || undef,
            restrict_ip            	=> $r->param('restrict_ip') || undef,
            relax_restrict_ip      	=> $r->param('relax_restrict_ip') || undef,
            restricted_login_proctor => $r->param('restricted_login_proctor') || undef,
            var 					=> $r->param('var') || undef,
            value   				=> $r->param('value') || undef,
            users 					=> $r->param('users') || undef,
            place 					=> $r->param('place') || undef,
            path 					=> $r->param('path') || undef, 
            selfassign 			    => $r->param('selfassign') || undef, 
            pgCode					=> $r->param('pgCode') || undef,
            sendViaJSON				=> $r->param('sendViaJSON') || undef,
            assigned_users	        => $r->param('assigned_users') || undef,
            overrides				=> $r->param('overrides') || undef,
			showHints				=> $r->param('showHints') || 0,
			showSolutions			=> $r->param('showSolutions') || 0,
	};
	if ($UNIT_TESTS_ON) {
		print STDERR "instructorXMLHandler.pm ".__LINE__." values obtained from form parameters\n\t",
		   format_hash_ref($input);
	}
	my $source = "";
	#print $r->param('problemSource');
	my $problem = $r->param('problemSource');
	if (defined($problem) and $problem and -r $problem ) {
    	$source = `cat $problem`;
    	#print "SOURCE\n".$source;
    	$input->{source} = encode_base64($source);
	}
	
	my $std_input = standard_input();
	$input = {%$std_input, %$input};
	# Fix the environment display mode
	$input->{envir}->{displayMode} = $input->{displayMode} if($input->{displayMode});
	# Set environment variables for hints/solutions
	$input->{envir}->{showHints} = $r->param('showHints') if($r->param('showHints'));
	$input->{envir}->{showSolutions} = $r->param('showSolutions') if($r->param('showSolutions'));
	
	## getting an error below (pstaab on 6/10/2013)  I don't this this is used anymore.  


	##########################################
	# FIXME hack to get fileName or filePath   param("set") contains the path
	# my $problemPath = $input->{set};   # FIXME should rename this ????
	# $problemPath =~ m|templates/(.*)|;
	# $problemPath = $1;    # get everything in the path after templates
	# $input->{envir}->{fileName}= $problemPath;
	##################################################
	$input->{courseID} = $r->param('courseID');

	##############################
	# xmlrpc_client calls webservice with the requested command
	#
	# and stores the resulting XML output in $self->{output}
	# from which it will eventually be returned to the browser
	#
	##############################
	#if ( $xmlrpc_client->jsXmlrpcCall($r->param("xml_command"), $input) ) {
	#	print "tried to render a problem";
		#$self->{output} = $xmlrpc_client->formatRenderedProblem;#not sure what to do here just yet.
	#} else {
	#	$self->{output} = $xmlrpc_client->{output};  # error report
	#	print $xmlrpc_client->{output};
	#}
	if($r->param('xml_command') eq "addProblem" || $r->param('xml_command') eq "deleteProblem"){
		$input->{path} = $r->param('problemPath');
	}
	
	if($r->param('xml_command') eq "renderProblem"){
	    if (my $problemPath = $r->param('problemPath')) {
	        $problemPath =~ m|templates/(.*)|;
	        $problemPath = $1;    # get everything in the path after templates
	    	$input->{envir}->{fileName}=$problemPath;
	    }
		$self->{output}->{problem_out} = $xmlrpc_client->xmlrpcCall('renderProblem', $input);
		my @params = join(" ", $r->param() ); # this seems to be necessary to get things read.?
		# FIXME  -- figure out why commmenting out the line above means that $envir->{fileName} is not defined. 
		#$self->{output}->{text} = "Rendered problem";
	} else {	
		$self->{output} = $xmlrpc_client->xmlrpcCall($r->param("xml_command"), $input);
	}
	################################
 }
 

sub standard_input {
	my $out = {
		pw            			=>   '',   # not needed
		password      			=>   '',   # not needed
		session_key             =>   '',
		userID          		=>   '',   # not needed
		set               		=>   '',
		library_name 			=>  'Library',
		command      			=>  'all',
		answer_form_submitted   =>   1,
		extra_packages_to_load  => [qw( AlgParserWithImplicitExpand Expr
		                                ExprWithImplicitExpand AnswerEvaluator
		                                AnswerEvaluatorMaker 
		)],
		mode                    => 'images',
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
		
			num_of_correct_ans  => 200, # we are picking phoney values so
			num_of_incorrect_ans => 400,
			recorded_score       => 1.0,
		},
		source                   => '',  #base64 encoded
		
		
		
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
		fileName=>'the XMLHandler environment->{fileName} should be set',
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
		PRINT_FILE_NAMES_FOR => [ ],
		probFileName => 'probFileName should not be used --use fileName instead',
		problemSeed  => 1234,
		problemValue => -1,
		probNum => 13,
		psvn => 54321,
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

sub pretty_print_json { 
    shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
	my $rh = shift;
	my $indent = shift || 0;
	
	my $out = "";
	my $type = ref($rh);

	if (defined($type) and $type) {
		#$out .= " type = $type; ";
	} elsif (! defined($rh )) {
		#$out .= " type = UNDEFINED; ";
	}
	return $out."" unless defined($rh);
	
	if ( ref($rh) =~/HASH/ or "$rh" =~/HASH/ ) {
	    $indent++;
 		foreach my $key (sort keys %{$rh})  {
 			$out .= "  ".'"'.$key.'" : '. pretty_print_json( $rh->{$key}) . ",";
 		}
 		$indent--;
 		#get rid of the last comma
 		chop $out;
 		$out = "{\n$out\n"."}\n";

 	} elsif (ref($rh)  =~  /ARRAY/ or "$rh" =~/ARRAY/) {
 		foreach my $elem ( @{$rh} )  {
 		 	$out .= pretty_print_json($elem).",";
 		
 		}
 		#get rid of the last comma
 		chop $out;
 		$out = "[\n$out\n"."]\n";
 		#$out =  '"'.$out.'"';
	} elsif ( ref($rh) =~ /SCALAR/ ) {
		$out .= "scalar reference ". ${$rh};
	} elsif ( ref($rh) =~/Base64/ ) {
		$out .= "base64 reference " .$$rh;

    } elsif ($rh  =~ /^[+-]?\d+$/){
        $out .=  $rh;
	} else {
		$out .=  '"'.$rh.'"';
	}
	
	return $out."";
}

sub content {
   ###########################
   # Return content of rendered problem to the browser that requested it
   ###########################
   	my $self = shift;
	
	#for handling errors...i'm to lazy to make it work right now
	if($self->{output}->{problem_out}){
		print $self->{output}->{problem_out}->{text};
	} else {
		print '{"server_response":"'.$self->{output}->{text}.'",';
		if($self->{output}->{ra_out}){
			# print '"result_data":'.pretty_print_json($self->{output}->{ra_out}).'}';
			if (ref($self->{output}->{ra_out})) {
				print '"result_data": ' . to_json($self->{output}->{ra_out}) .'}';
			} else {
				print '"result_data": "' . $self->{output}->{ra_out} . '"}';
			}
		} else {
			print '"result_data":""}';
		}
	}
	#print "".pretty_print_json($self->{output}->{ra_out});
}




1;
