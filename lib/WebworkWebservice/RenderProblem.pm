#!/usr/local/bin/perl -w 

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WebworkWebservice/RenderProblem.pm,v 1.11 2010/06/08 11:22:43 gage Exp $
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

package WebworkWebservice::RenderProblem;
use WebworkWebservice;
use base qw(WebworkWebservice); 

my $debugXmlCode=0;  # turns on the filter for debugging XMLRPC and SOAP code
local(*DEBUGCODE);

use strict;
use sigtrap;
use Carp;
use WWSafe;
use WeBWorK::Debug;
use WeBWorK::CourseEnvironment;
use WeBWorK::PG::Translator;
use WeBWorK::PG::Local;
use WeBWorK::DB;
use WeBWorK::Constants;
use WeBWorK::Utils qw(runtime_use formatDateTime makeTempDirectory);
use WeBWorK::DB::Utils qw(global2user user2global);
use WeBWorK::Utils::Tasks qw(fake_set fake_problem);
use WeBWorK::PG::IO;
use WeBWorK::PG::ImageGenerator;
use Benchmark;
use MIME::Base64 qw( encode_base64 decode_base64);

#print "rereading Webwork\n";


our $WW_DIRECTORY = $WebworkWebservice::WW_DIRECTORY;
our $PG_DIRECTORY = $WebworkWebservice::PG_DIRECTORY;
our $COURSENAME   = $WebworkWebservice::COURSENAME;
our $PROTOCOL     = $WebworkWebservice::PROTOCOL;
our $HOST_NAME    = $WebworkWebservice::HOST_NAME;
our $PORT         = $WebworkWebservice::HOST_PORT;
our $HOSTURL      = "$PROTOCOL://$HOST_NAME:$PORT"; 


our $UNIT_TESTS_ON =0;
# 
# #our $ce           = $WebworkWebservice::SeedCE;
# # create a local course environment for some course
# our $ce           = WeBWorK::CourseEnvironment->new(
#                 {webwork_dir=> $WW_DIRECTORY,  courseName=>$COURSENAME} 
#     );
#     $ce->{apache_root_url} = $HOSTURL;
# #print "\$ce = \n", WeBWorK::Utils::pretty_print_rh($ce);
# 
# 
# #other services
# # File variables
# #our $WARNINGS='';
# 
# 
# # imported constants
# 
# my $COURSE_TEMP_DIRECTORY 	= 	$ce->{courseDirs}->{html_tmp};
# my $COURSE_TEMP_URL 		= 	$HOSTURL.$ce->{courseURLs}->{html_tmp};
# 
# my $pgMacrosDirectory 		= 	$ce->{pg_dir}.'/macros/';      
# my $macroDirectory			=	$ce->{courseDirs}->{macros}.'/'; 
# my $templateDirectory		= 	$ce->{courseDirs}->{templates}; 
# 
# my %PG_environment          =   $ce->{pg}->{specialPGEnvironmentVars};
# 

use constant DISPLAY_MODES => {
	# display name   # mode name
	tex           => "TeX",
	plainText     => "HTML",
	images        => "HTML_dpng",
	MathJax	      => "HTML_MathJax",
};

use constant DISPLAY_MODE_FAILOVER => {
		TeX            => [],
		HTML           => [],
		HTML_dpng      => [ "HTML", ],
		HTML_MathJax    => [ "HTML_dpng", "HTML", ],
		# legacy modes -- these are not supported, but some problems might try to
		# set the display mode to one of these values manually and some macros may
		# provide rendered versions for these modes but not the one we want.
		HTML_img    => [ "HTML_dpng", "HTML", ],
};
	






sub renderProblem {
	my $self = shift;
    my $rh = shift;
 
 # sanity check   
	my $user_id      = $self->{user_id};
	my $courseName   = $self->{courseName};
	my $displayMode  = $rh->{envir}->{displayMode};
	my $problemSeed  = $rh->{envir}->{problemSeed};
	debug(WebworkWebservice::pretty_print_rh($rh));

	unless ( $user_id && $courseName && $displayMode && defined($problemSeed)) {
		die( "\n\n\nMissing essential data entering WebworkWebservice::RenderProblem::renderProblem: 
		      userID: |$user_id|, courseName: |$courseName|,	
		      displayMode: |$displayMode|, problemSeed: |$problemSeed|");
		return;
	}
 
###########################################
# Grab the course name, if this request is going to depend on 
# some course other than the default course
###########################################
	my $courseName;
	my $ce;
	my $db;
	my $user;
	my $beginTime = new Benchmark;

# 	if (defined($self->{courseName}) and $self->{courseName} ) {
# 		$courseName = $self->{courseName};
# 	} elsif (defined($rh->{course}) and $rh->{course}=~/\S/ ) {
# 		$courseName = $rh->{course};
# 	} else {
# 		$courseName = $COURSENAME;
# 		# use the default $ce
# 	}
    if (defined($self->{courseName}) and $self->{courseName} ) {
 		$courseName = $self->{courseName};
 	} 
 	
    # It's better not to get the course in too many places. :-)
    # High level information about the course should come from $self
    # Lower level information should come from $rh (i.e. passed by $in at WebworkWebservice)
    
	#FIXME  put in check to make sure the course exists.
	eval {
		$ce = WeBWorK::CourseEnvironment->new({webwork_dir=>$WW_DIRECTORY, courseName=> $courseName});
		$ce->{apache_root_url}= $HOSTURL;
	# Create database object for this course
		$db = WeBWorK::DB->new($ce->{dbLayout});
	};
	# $ce->{pg}->{options}->{catchWarnings}=1;  #FIXME warnings aren't automatically caught 
	# when using xmlrpc -- turn this on in the daemon2_course.
	#^FIXME  need better way of determining whether the course actually exists.
	
	# The UNIT_TEST_ON snippets are the closest thing we have to a real unit test.
	#
	warn "Unable to create course $courseName. Error: $@" if $@;
	# my $user = $rh->{user};
	# 	$user    = 'practice1' unless defined $user and $user =~/\S/;
	my $user;
	if (defined $self->{user_id}) {
		$user = $self->{user_id};
	} else {
		warn "RenderProblem.pm:  user_id is not defined userID is = ", $self->{userID};
	}
	
###########################################
# Authenticate this request -- done by initiate  in WebworkWebservice 
###########################################



###########################################
# Determine the authorization level (permissions)  -- done by initiate  in WebworkWebservice 
###########################################

###############################################################################
# set up warning handler
###############################################################################
	my $warning_messages="";

	my  $warning_handler = sub {
			my ($warning) = @_;
			CORE::warn $warning;
			chomp $warning;
			$warning_messages .="$warning\n";			
		};

    local $SIG{__WARN__} = $warning_handler;


###########################################
# Determine the method for accessing data   ???? what was this
# these are not used -- but something like this was probably
# meant to determine whether the problem source was being supplied
# directly (as a kind of HERE document) or whether only the path to 
# the problem source was being supplied
###########################################
	# my $problem_source_access    =   $rh->{problem_source_access};
	# One of
	#	source_from_course_set_problem
	#   source_from_source_file_path
	#   source_from_request
	
	# my $data_access              =   $rh->{data_access};
	# One of 
	#   data_from_course
	#   data_from_request
###########################################
# Determine an effective user for this interaction
# or create one if it is not given
# In order:  use effectiveUserName, studentLogin, or user  or 'foobar'
###########################################
	my $effectiveUserName;
	if (defined($rh->{effectiveUser}) and $rh->{effectiveUser}=~/\S/ ) {
		$effectiveUserName = $rh->{effectiveUser};
	} elsif (defined($rh->{envir}->{studentLogin}) and $rh->{envir}->{studentLogin}=~/\S/ ) {
		$effectiveUserName = $rh->{envir}->{studentLogin};
	} elsif (defined($user) and $user =~ /\S/ ) {
		$effectiveUserName = $user;
	} else {
		$effectiveUserName = 'foobar';
	}
	##################################################
	if ($UNIT_TESTS_ON) {
		print STDERR "RenderProblem.pm:  user = $user\n";
		print STDERR "RenderProblem.pm:  courseName = $courseName\n";
		print STDERR "RenderProblem.pm:  effectiveUserName = $effectiveUserName\n";
		print STDERR "environment fileName", $rh->{envir}->{fileName},"\n";
	}
	
	#################################################################
	# The effectiveUser is the student the this problem version was written for
	# The user might also be the effective user but it could be 
	# an instructor checking out how well the problem is working.
	#################################################################
	
	my $effectiveUser = $db->getUser($effectiveUserName); # checked
	my $effectiveUserPermissionLevel;
	my $effectiveUserPassword;
	unless (defined $effectiveUser ) {
		$effectiveUser                = $db->newUser;
		$effectiveUserPermissionLevel = $db->newPermissionLevel;
		$effectiveUserPassword        = $db->newPassword;
		$effectiveUser->user_id($effectiveUserName);
		$effectiveUserPermissionLevel->user_id($effectiveUserName);
		$effectiveUserPassword->user_id($effectiveUserName);
		$effectiveUserPassword->password('');
		$effectiveUser->last_name($rh->{envir}->{studentName}|| 'foobar');
		$effectiveUser->first_name('');
		$effectiveUser->student_id($rh->{envir}->{studentID}|| 'foobar');
		$effectiveUser->email_address($rh->{envir}->{email}|| '');
		$effectiveUser->section($rh->{envir}->{section} ||'');
		$effectiveUser->recitation($rh->{envir}->{recitation} ||'');
		$effectiveUser->comment('');
		$effectiveUser->status('C');
		#$effectiveUser->password($rh->{envir}->{studentID}|| 'foobar'); dunno what's going on here
		$effectiveUserPermissionLevel->permission(0);
	}		
   #FIXME  these will fail if the keys are not defined within the environment.

###########################################
# Insure that set and problem are defined
# Define the set and problem information from
# data in the environment if necessary
###########################################
	# determine the set name and the set problem number
	my $setName       =  (defined($rh->{set_id}) ) ? $rh->{set_id} : 
	    (defined($rh->{envir}->{setNumber}) ? $rh->{envir}->{setNumber}  : '');
	
	my $problemNumber =  (defined($rh->{envir}->{probNum})   )    ? $rh->{envir}->{probNum}      : 1 ;
	my $problemSeed   =  (defined($rh->{envir}->{problemSeed}))   ? $rh->{envir}->{problemSeed}  : 1 ;
#	$problemSeed = $rh->{problemSeed} || $problemSeed;
	my $psvn          =  (defined($rh->{envir}->{psvn})      )    ? $rh->{envir}->{psvn}         : 1234 ;
	my $problemStatus =  $rh->{problem_state}->{recorded_score}|| 0 ;
	my $problemValue  =  (defined($rh->{envir}->{problemValue}))   ? $rh->{envir}->{problemValue}  : 1 ;
	my $num_correct   =  $rh->{problem_state}->{num_correct}   || 0 ;
	my $num_incorrect =  $rh->{problem_state}->{num_incorrect} || 0 ;
	my $problemAttempted = ($num_correct || $num_incorrect);
	my $lastAnswer    = '';
	
	debug("setName: " . $setName);
	debug("problemNumber: ". $problemNumber);
	debug("problemSeed:" . $problemSeed);
	debug("psvn: " . $psvn);
	debug("problemStatus:" . $problemStatus);
	debug("problemValue: " . $problemValue);



	my $setRecord = $db->getMergedSet($effectiveUserName, $setName);
 	unless (defined($setRecord) and ref($setRecord) ) {
		# if a User Set does not exist for this user and this set
		# then we check the Global Set
		# if that does not exist we create a fake set
		# if it does, we add fake user data
		my $userSetClass = $db->{set_user}->{record};
		my $globalSet = $db->getGlobalSet($setName); # checked

		if (not defined $globalSet) {
			$setRecord = fake_set($db);
		} else {
			$setRecord = global2user($userSetClass, $globalSet);
		}
		# initializations
		$setRecord->set_id($setName);
		$setRecord->set_header("");
		$setRecord->hardcopy_header("defaultHeader");
		$setRecord->open_date(time()-60*60*24*7); #  one week ago
		$setRecord->due_date(time()+60*60*24*7*2); # in two weeks
		$setRecord->answer_date(time()+60*60*24*7*3); # in three weeks
		$setRecord->psvn($rh->{envir}->{psvn}||0);
	}
	#warn "set Record is $setRecord";
	# obtain the merged problem for $effectiveUser
	my $problemRecord = $db->getMergedProblem($effectiveUserName, $setName, $problemNumber); 
	
	# if that is not yet defined obtain the global problem,
	# convert it to a user problem, and add fake user data
	unless (defined $problemRecord) {
		my $userProblemClass = $db->{problem_user}->{record};
		my $globalProblem = $db->getGlobalProblem($setName, $problemNumber); # checked
		# if the global problem doesn't exist either, bail!
		if(not defined $globalProblem) {
			$problemRecord = fake_problem($db);
		} else {
			$problemRecord = global2user($userProblemClass, $globalProblem);
		}
		# initializations
		$problemRecord->user_id($effectiveUserName);
		$problemRecord->problem_id($problemNumber);
		$problemRecord->set_id($setName);
		$problemRecord->problem_seed($problemSeed);
		$problemRecord->status($problemStatus);
		$problemRecord->value($problemValue);
		# We are faking it
		#$problemRecord->attempted($problemAttempted);
		#$problemRecord->num_correct($num_correct);
		#$problemRecord->num_incorrect($num_incorrect);
		$problemRecord->attempted(2000);
		$problemRecord->num_correct(1000);
		$problemRecord->num_incorrect(1000);
		$problemRecord->last_answer($lastAnswer);
	}
	# initialize problem source
	# handle alias "path";
	$rh->{sourceFilePath} = $rh->{path} unless defined $rh->{sourceFilePath};
	if ($UNIT_TESTS_ON){
			print STDERR "template directory path ", $ce->{courseDirs}->{templates},"\n";
			print STDERR "RenderProblem.pm: source file is ", $rh->{sourceFilePath},"\n";
			print STDERR "RenderProblem.pm: problem source is included in the request \n" if defined($rh->{source}) and $rh->{source};
	}	


	my $problem_source;
	my $r_problem_source =undef;
 	if (defined($rh->{source}) and $rh->{source}) {
  		$problem_source = decode_base64($rh->{source});
  		$problem_source =~ tr /\r/\n/;
		$r_problem_source =\$problem_source;
		# warn "source included in request";
		if (defined $rh->{envir}->{fileName} and not $rh->{envir}->{fileName}=~/WebworkClient.pm/)  {
			$problemRecord->source_file($rh->{envir}->{fileName});
		} else {
			$problemRecord->source_file($rh->{sourceFilePath});
		} 
  	} elsif (defined($rh->{sourceFilePath}) and $rh->{sourceFilePath} =~/\S/)  {
  	    $problemRecord->source_file($rh->{sourceFilePath});
  	    warn "reading source from ", $rh->{sourceFilePath} if $UNIT_TESTS_ON;
  	    $problem_source = WeBWorK::PG::IO::read_whole_file($ce->{courseDirs}->{templates}.'/'.$rh->{sourceFilePath});
  	    #warn "source is ", $problem_source;
  	    $r_problem_source = \$problem_source;
		$problemRecord->source_file('RenderProblemFooBar') unless defined($problemRecord->source_file);
	}
	if ($UNIT_TESTS_ON){
			print STDERR "template directory path ", $ce->{courseDirs}->{templates},"\n";
			print STDERR "RenderProblem.pm: source file is ", $problemRecord->source_file,"\n";
			print STDERR "RenderProblem.pm: problem source is included in the request \n" if defined($rh->{source});
	}
    # warn "problem Record is $problemRecord";
	# now we're sure we have valid UserSet and UserProblem objects
	# yay!

##################################################
# Other initializations
##################################################
	#debug( "envir->displayMode", WebworkWebservice::pretty_print_rh($rh->{envir}));
	my $translationOptions = {
		displayMode     => $rh->{envir}->{displayMode}//"display mode not defined at RenderProblem.pm 388",
		showHints	    => $rh->{envir}->{showHints},
		showSolutions   => $rh->{envir}->{showSolutions},
 		refreshMath2img => $rh->{envir}->{showHints} || $rh->{envir}->{showSolutions},
 		processAnswers  => defined($rh->{processAnswers}) ? $rh->{processAnswers} : 1,
 		catchWarnings   => 1,
        # methods for supplying the source, 
        r_source        => $r_problem_source, # reference to a source file string.
        # if reference is not defined then the path is obtained 
        # from the problem object.
        permissionLevel => $rh->{envir}->{permissionLevel} || 0,
		effectivePermissionLevel => $rh->{envir}->{effectivePermissionlevel} 
		                            || $rh->{envir}->{permissionLevel} || 0,
	};
	
	my $formFields = $rh->{envir}->{inputs_ref};
	my $key        = $rh->{envir}->{key} || '';

	local $ce->{pg}{specialPGEnvironmentVars}{problemPreamble} = {TeX=>'',HTML=>''} if($rh->{noprepostambles});
    local $ce->{pg}{specialPGEnvironmentVars}{problemPostamble} = {TeX=>'',HTML=>''} if($rh->{noprepostambles});
	
	#check definitions
	#warn "setRecord is ", WebworkWebservice::pretty_print_rh($setRecord);
	#warn "problemRecord is",WebworkWebservice::pretty_print_rh($problemRecord);
# 	warn "envir is\n ",WebworkWebservice::pretty_print_rh(__PACKAGE__->defineProblemEnvir(
# 		$ce,
# 		$effectiveUser,
# 		$key,
# 		$setRecord,
# 		$problemRecord,
# 		$psvn,  #FIXME -- not used
# 		$formFields,
# 		$translationOptions,
# 	));
#################################################

# Other options can be over ridden by modifying 
# $ce->{pg}



# We'll try to use this code instead so that Local does all of the work.
# Most of the configuration will take place in the fake course associated
# with XMLRPC responses
#   problem needs to be loaded with the following:
#   	source_file
#       status
#       num_correct
#       num_incorrect
#   it doesn't seem that $effectiveUser, $set or $key is used in the subroutine
#   except that it is passed on to defineProblemEnvironment
	my $pg;

	$pg = WebworkWebservice::RenderProblem->new(
		$ce,
		$effectiveUser,
		$key,
		$setRecord,
		$problemRecord,
		$setRecord->psvn, # FIXME: this field should be removed
		$formFields,
		# translation options
		$translationOptions,
# 		{ # extras
# 				overrides       => $rh->{overrides}},
#         }
		
	);

    my ($internal_debug_messages, $pgwarning_messages, $pgdebug_messages);
    if (ref ($pg->{pgcore}) ) {
    	$internal_debug_messages   = $pg->{pgcore}->get_internal_debug_messages;
    	$pgwarning_messages        = $pg ->{pgcore}->get_warning_messages();
    	$pgdebug_messages          = $pg ->{pgcore}->get_debug_messages();
    } else {
    	$internal_debug_messages = ['Error in obtaining debug messages from PGcore'];
    }
	# new version of output:
	my $out2   = {
		text 						=> encode_base64( $pg->{body_text}  ),
		header_text 				=> encode_base64( $pg->{head_text} ),
		answers 					=> $pg->{answers},
		errors         				=> $pg->{errors},
		WARNINGS	   				=> encode_base64( 
		                                 "WARNINGS\n".$warning_messages."\n<br/>More<br/>\n".$pg->{warnings} 
		                               ),
		PG_ANSWERS_HASH             => $pg->{pgcore}->{PG_ANSWERS_HASH},
		problem_result 				=> $pg->{result},
		problem_state				=> $pg->{state},
		flags						=> $pg->{flags},
		warning_messages            => $pgwarning_messages,
		debug_messages              => $pgdebug_messages,
		internal_debug_messages     => $internal_debug_messages,
	};
	
	# Filter out bad reference types
	###################
	# DEBUGGING CODE
	###################
	if ($debugXmlCode) {
		my $logDirectory =$ce->{courseDirs}->{logs};
		my $xmlDebugLog  = "$logDirectory/xml_debug.txt";
		warn "RenderProblem.pm: Opening debug log $xmlDebugLog\n" ;
		open (DEBUGCODE, ">>$xmlDebugLog") || die "Can't open debug log $xmlDebugLog";
		print DEBUGCODE "\n\nStart xml encoding\n";
	}
	$out2 = xml_filter($out2); # check this -- it might not be working correctly
	##################
	close(DEBUGCODE) if $debugXmlCode;
	###################
	
	$out2->{flags}->{PROBLEM_GRADER_TO_USE} = undef;
	my $endTime = new Benchmark;
	$out2->{compute_time} = logTimingInfo($beginTime, $endTime);
	# warn "flags are" , WebworkWebservice::pretty_print_rh($pg->{flags});
	
	return $out2;
	         
}

#  insures proper conversion to xml structure.
sub xml_filter {
	my $input = shift;
	my $level = shift || 0;
	my $space="  ";
	# protect against modules defined in Safe which can't find their stringify procedure.
	my $dummy = eval { "$input"  };
	if ($@ ) {
		print DEBUGCODE "Unable to determine stringify for this item\n";
		print DEBUGCODE $@, "\n";
		return;
	}
	my $type = ref($input);
	
	# Hack to filter out CODE references??
	if (!defined($type) or !$type ) {
		print DEBUGCODE $space x $level." : scalar -- not converted\n" if $debugXmlCode;
	} elsif( $type =~/HASH/i or "$input"=~/HASH/i) {
		print DEBUGCODE "HASH reference ($input) with ".%{$input}." elements will be investigated\n" if $debugXmlCode;
		$level++;
		foreach my $item (keys %{$input}) {
			print DEBUGCODE "  "x$level."$item is " if $debugXmlCode;
		    $input->{$item} = xml_filter($input->{$item},$level);   
		}
		$level--;
		print DEBUGCODE "  "x$level."HASH reference completed \n" if $debugXmlCode;
	} elsif( $type=~/ARRAY/i or "$input"=~/ARRAY/i) {
		print DEBUGCODE "  "x$level."ARRAY reference with ".@{$input}." elements will be investigated\n" if $debugXmlCode;
		$level++;
		my $tmp = [];
		foreach my $item (@{$input}) {
			$item = xml_filter($item,$level);
			push @$tmp, $item;
		}
		$input = $tmp;
		$level--;
		print DEBUGCODE "  "x$level."ARRAY reference completed: ",join(" ",@$input),"\n" if $debugXmlCode;
	} elsif($type =~ /CODE/i or "$input" =~/CODE/i) {
		$input = "CODE reference";
		print DEBUGCODE "  "x$level."CODE reference, converted $input\n" if $debugXmlCode;
	} else {
		print DEBUGCODE  "  "x$level." type |$type| and was  converted to string\n" if $debugXmlCode;
		$input = "$type reference";
	}
	$input;
	
}

sub logTimingInfo{
    my ($beginTime,$endTime,) = @_;
    my $out = "";
    $out .= Benchmark::timestr( Benchmark::timediff($endTime , $beginTime) );
    $out;
}


######################################################################
sub new {
	shift; # throw away invocant -- we don't need it
	my ($ce, $user, $key, $set, $problem, $psvn, $formFields,
		$translationOptions) = @_;
	
	#my $renderer = 'WeBWorK::PG::Local';
	my $renderer = $ce->{pg}->{renderer};
	
	runtime_use $renderer;
	# the idea is to have Local call back to the defineProblemEnvir below.
	#return WeBWorK::PG::Local::new($renderer,@_);
	return $renderer->new(@_);
}



1;
