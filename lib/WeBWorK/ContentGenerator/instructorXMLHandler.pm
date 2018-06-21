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
use WeBWorK::Utils qw(readFile);
use PGUtil qw(not_null);

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
#	$xmlrpc_client->{displayMode}   = DISPLAYMODE();
	$xmlrpc_client->{user}          = 'xmluser';
#	$xmlrpc_client->{password}      = $XML_PASSWORD;
	$xmlrpc_client->{site_password} = $XML_PASSWORD;
#	$xmlrpc_client->{course}        = $r->param('courseID');
	$xmlrpc_client->{courseID}      = $r->param('courseID');

	# print STDERR WebworkClient::pretty_print($r->{paramcache});

	my $input = {#can I just use $->param? it looks like a hash

#		    pw                      => $r->param('pw') ||undef,
		    session_key             => $r->param("session_key") ||undef,
		    userID                  => $r->param("user") ||undef,
		    courseID                => $r->param('courseID'),
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
		    library_status		    => $r->param("library_status") ||undef,
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
            permission     			=> $r->param('permission') // 0,	# valid values from %userRoles in defaults.config
            status         			=> $r->param('status') || undef,#'Enrolled, audit, proctor, drop
            section        			=> $r->param('section') || undef,
            recitation     			=> $r->param('recitation') || undef,
            comment        			=> $r->param('comment') || undef,
            new_password   			=> $r->param('new_password') || undef,
            userpassword   			=> $r->param('userpassword') || undef,	# defaults to studentid if empty
	     	set_props	    		=> $r->param('set_props') || undef,
	     	set_id	    			=> not_null($r->param('set_id')) ? $r->param('set_id') : undef,
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
		    processAnswers => defined($r->param('processAnswers')) ? $r->param('processAnswers') : 1,
	};



	if ($UNIT_TESTS_ON) {
		print STDERR "instructorXMLHandler.pm ".__LINE__." values obtained from form parameters\n\t",
		   format_hash_ref($input);
	}
	my $source = "";
	#print $r->param('problemPath');
	my $problemPath = $r->param('problemPath');
	if (defined($problemPath) and $problemPath) {
            $input->{path} = $problemPath;
	} elsif ($r->param('problemSource')) {
            $input->{source} = $r->param('problemSource');
        }

	my $std_input = standard_input();
	$input = {%$std_input, %$input};
	# Fix the environment display mode and problemSeed
	# Set environment variables for hints/solutions
	# Set the permission level and probNum
	$input->{envir} = {
		%{$input->{envir}},		# this may have undefined entries
		showHints 		=> ($r->param('showHints')) ? $r->param('showHints'):0,
		showSolutions 	=> ($r->param('showSolutions')) ? $r->param('showSolutions'):0,
		probNum  		=> $r->param("probNum") ||undef, 
		permissionLevel => ($r->{ce}->{userRoles}->{$r->param('permissionLevel')//0})// 0,
		displayMode     => $r->param("displayMode") || undef,
		problemSeed	    => $r->param("problemSeed") || 0,
		
 	};
 	$input->{envir}->{inputs_ref} ={
 		%{ $input->{envir}->{inputs_ref}},
		displayMode => $r->param("displayMode") || 0,
		problemSeed => $r->param("problemSeed") || 0,
	};


	

	##############################
	# xmlrpc_client calls webservice with the requested command
	#
	# and stores the resulting XML output in $self->{return_object}
	# from which it will eventually be returned to the browser
	#
	##############################
	#if ( $xmlrpc_client->jsXmlrpcCall($r->param("xml_command"), $input) ) {
	#	print "tried to render a problem";
		#$self->{output} = ($xmlrpc_client->formatRenderedProblem); #not sure what to do here just yet.
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
		$xmlrpc_client->xmlrpcCall('renderProblem', $input);
		# original method of signaling $xmlrpc_client->{renderProblem} = 1; #flag to indicate the renderProblem command was executed.
		$self->{xml_command} = 'renderProblem';
		$self->{output} = $xmlrpc_client;
		my @params = join(" ", $r->param() ); # this seems to be necessary to get things read.?
		# FIXME  -- figure out why commmenting out the line above means that $envir->{fileName} is not defined. 
		#$self->{output}->{text} = "Rendered problem";
	} else {	
		$xmlrpc_client->xmlrpcCall($r->param("xml_command"), $input);
		$self->{xml_command} = $r->param("xml_command");
		$self->{output} = $xmlrpc_client
	}
 }
 

sub standard_input {
	my $out = {
		course_password         =>   '',   # not needed  use site_password??
		session_key             =>   '',
		userID          		=>   '',   # not needed
		set               		=>   '',
		library_name 			=>  'Library',
		command      			=>  'all',
		answer_form_submitted   =>   1,
		mode                    => 'images',
		envir                   => { 
		                inputs_ref => {displayMode => DISPLAYMODE()},
					    problemValue => -1, 
					    fileName => ''},
		problem_state           => {
		
			num_of_correct_ans  => 200, # we are picking phoney values so that solutions are available
			num_of_incorrect_ans => 400,
			recorded_score       => 1.0,
		},
		source                   => '',  #base64 encoded
		
		
		
	};

	$out;
}


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
	my $xmlrpc_client;
	if ( ref($self->{output})=~/WebworkClient/) {
		$xmlrpc_client = $self->{output};
	} else {
		Croak("No content was returned by the xmlrpc call");
	}
	if ( ($xmlrpc_client->fault) ) {  # error -- print error string
	    my $err_string = $xmlrpc_client->error_string;	    
	    die($err_string);
	} elsif($self->{xml_command} eq 'renderProblem'){
		# FIXME hack
		# we need to regularize the way that text is returned.
		# it behaves differently when re-randomization in the library takes place
		# then during the initial rendering. 
		# print only the text field (not the ra_out field)
		# and print the text directly without formatting.
		if ($xmlrpc_client->return_object->{problem_out}->{text}) {
			print $xmlrpc_client->return_object->{problem_out}->{text};
		} else {
				print $xmlrpc_client->return_object->{text}; 
		}
	} else {  #returned something other than a rendered problem.
	    	  # in this case format a json string and print it. 
	    	  # the contents of "{text}" needs to be labeled server response;
		print '{"server_response":"'.$xmlrpc_client->return_object->{text}.'",';
		if($xmlrpc_client->return_object->{ra_out}){
			# print '"result_data":'.pretty_print_json($xmlrpc->return_object->{ra_out}).'}';
			if (ref($xmlrpc_client->return_object->{ra_out})) {
				print '"result_data": ' . to_json($xmlrpc_client->return_object->{ra_out}) .'}';
			} else {
				print '"result_data": "' . $xmlrpc_client->return_object->{ra_out} . '"}';
			}
		} else {
			print '"result_data":""}';
		}
	}
	#print "".pretty_print_json($self->{output}->{ra_out});
}




1;
