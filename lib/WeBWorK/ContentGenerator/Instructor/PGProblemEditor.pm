################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/PGProblemEditor.pm,v 1.24 2004/01/25 18:20:14 gage Exp $
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

package WeBWorK::ContentGenerator::Instructor::PGProblemEditor;
use base qw(WeBWorK::ContentGenerator::Instructor);


=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetEditor - Edit a set definition list

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readFile);
use Apache::Constants qw(:common REDIRECT);


our $libraryName;
our $rowheight;

sub title {
	my $self = shift;
	#FIXME  don't need the entire path  ??
	return "Instructor Tools - PG Problem Editor ";
}

sub header {  #FIXME  this should be moved up to ContentGenerator
	my $self = shift;
	return REDIRECT if $self->{noContent};
	my $r = $self->{r};
	$r->content_type('text/html');
	$r->send_http_header();
	return OK;
}

	###########################################################
	# This editor will edit problem files or set header files or files, such as course_info
	# whose name is defined in the global.conf database
	#
	# Only files under the template directory ( or linked to this location) can be edited.
	#
	# The course information and problems are located in the course templates directory.
	# Course information has the name  defined by courseFiles->{course_info}
	# 
	# Only files under the template directory ( or linked to this location) can be edited.
	#
	# editMode = temporaryFile    (view the temp file defined by course_info.txt.user_name.tmp
	#                              instead of the file course_info.txt)
	# The editFileSuffix is "user_name.tmp" by default.  It's definition should be moved to Instructor.pm #FIXME                              
	###########################################################

sub pre_header_initialize {
	my $self 			= shift;
	#my ($setName, $problemNumber) = @_;
	my $r 				= 	$self->{r};
	my $setName = $r->urlpath->arg("setID");
	my $problemNumber = $r->urlpath->arg("problemID");
	my $ce				=	$self->{ce};
	my $submit_button 	= $r->param('submit');  # obtain submit command from form

    #####################################################
	# Save problem to permanent or temporary file
	# Then redirect for viewing
	#####################################################
	if (     defined($submit_button) and ($submit_button eq 'Save' or $submit_button eq 'Refresh')    ) {
	
		$self->saveFileChanges($setName,$problemNumber);  # write the necessary files
													 # return file path for viewing problem
													 # in $self->{currentSourceFilePath}
													 # obtain the appropriate seed.
		#redirect to view the problem
		
		my $hostname 		    = 	$r->hostname();
		my $port     		    = 	$r->get_server_port();
		my $uri		 		    = 	$r->uri;
		my $courseName		    =	$self->{ce}->{courseName};
		my $problemSeed		    = 	($r->param('problemSeed')) ? $r->param('problemSeed') : '';
		my $displayMode		    =	($r->param('displayMode')) ? $r->param('displayMode') : '';
        my $viewURL             =   '';
        if ($self->{file_type} eq 'problem') {
        	# redirect to have problem read by Problem.pm
			$viewURL  		    = 	"http://$hostname:$port";
			$viewURL		   .= 	$ce->{webworkURLs}->{root}."/$courseName/$setName/$problemNumber/?";
			$viewURL		   .=	$self->url_authen_args;
			$viewURL		   .=   "&displayMode=$displayMode&problemSeed=$problemSeed";   # optional displayMode and problemSeed overrides
			if ($submit_button eq 'Save') {
				$viewURL	   .=	"&editMode=savedFile";
			} else {		
				$viewURL	   .=	"&editMode=temporaryFile";
			}
			$viewURL		   .=	'&sourceFilePath='. $self->{currentSourceFilePath}; # path to pg text for viewing
			                                                                            # allows Problem.pg to recognize state
	                                                                                    # of problem being viewed.
	    } elsif ($self->{file_type} eq 'set_header') {
	    	# redirect set headers to ProblemList page
	    	$viewURL  		= 	"http://$hostname:$port";
			$viewURL		   .= 	$ce->{webworkURLs}->{root}."/$courseName/$setName/?";
			$viewURL		   .=	$self->url_authen_args;
			$viewURL		   .=   "&displayMode=$displayMode&problemSeed=$problemSeed";   # optional displayMode and problemSeed overrides
			if ($submit_button eq 'Save') {
				$viewURL	   .=	"&editMode=savedFile";
			} else {		
				$viewURL       .=	"&editMode=temporaryFile";
			}
		} elsif ($self->{file_type} eq 'course_info' ) {
			$viewURL  		    = 	"http://$hostname:$port";
			$viewURL		   .= 	$ce->{webworkURLs}->{root}."/$courseName/?";
		    $viewURL           .=	$self->url_authen_args;
			if ($submit_button eq 'Save') {
				$viewURL	   .=	"&editMode=savedFile";
			} else {		
				$viewURL	   .=	"&editMode=temporaryFile";
			}
		} else {
			warn "PGProblemEditor does not have facilities for editing files with file_type ".$self->{file_type};
		}

		$r->header_out(Location => $viewURL );
		$self->{noContent}      =  1;  # forces redirect
		return;
	}

}

sub initialize  {
    my $self      = shift;
	my $r 				= 	$self->{r};
	my $setName = $r->urlpath->arg("setID");
	my $problemNumber = $r->urlpath->arg("problemID");
	$self -> saveFileChanges($setName, $problemNumber);



}

sub saveFileChanges {
	
	my ($self, $setName, $problemNumber) = @_;
	my $ce 						= 	$self->{ce};
	my $r						=	$self->{r};
	my $path_info 				= 	$r->path_info || "";
	my $db						=	$self->{db};
	my $user					=	$r->param('user');
	my $effectiveUserName		=	$r->param('effectiveUser');
	my $courseName				=	$ce->{courseName};

	$setName                    =   '' unless defined $setName;
	$problemNumber              =   '' unless defined $problemNumber;
	
	##################################################
	# Determine path to the file to be edited.
	##################################################
	my $templateDirectory		=	$ce->{courseDirs}->{templates};
	my $editFilePath            =   $templateDirectory;
	my $problem_record          =   undef;
	
	my $file_type               =   $r->param("file_type") || '';
	
	if ($file_type eq 'course_info' )  {
		$editFilePath           .= '/'. $ce->{courseFiles}->{course_info};
		$self->{file_type}       = 'course_info';
	    # no problem_record is defined in this case
 
	}   else   {                    # we are editing a problem file or a set header file
	
			# FIXME  there is a discrepancy in the way that the problems are found.
			# FIXME  more error checking is needed in case the problem doesn't exist.
		if (defined($problemNumber) and $problemNumber) {
			$problem_record		    =	$db->getMergedProblem($effectiveUserName, $setName, $problemNumber); # checked
			# If there is no global_user defined problem, (i.e. the sets haven't been assigned yet), 
			# look for a global version of the problem.
			$problem_record			=	$db->getGlobalProblem($setName, $problemNumber) unless defined($problem_record); # checked
			# bail if no problem is found
			die "Cannot find a problem record for set $setName / problem $problemNumber" 
				unless defined($problem_record);
			$editFilePath           .=   '/'.$problem_record->source_file;
			$self->{file_type}      =   'problem';
		} elsif (defined($problemNumber) and $problemNumber==0) { # we are editing a header file
			my $set_record          =   $db->getMergedSet($effectiveUserName, $setName); # checked
			die "Cannot find a set record for set $setName" unless defined($set_record);	
			$editFilePath           .=   '/'.$set_record->set_header;
			$self->{file_type}      =   'set_header';
		}
	}
	
	
	
	
	my $editFileSuffix			=	$user.'.tmp';
	my $submit_button			= 	$r->param('submit');

	
	##############################################################################
	# Determine the display mode
	# try to get problem seed from the input parameter, or from the problem record
	# This will be needed for viewing the problem via redirect.
	# They are also two of the parameters which can be set by the editor
	##############################################################################
	my $displayMode	  			= 	( defined($r->param('displayMode')) 	) ? $r->param('displayMode') : $ce->{pg}->{options}->{displayMode};

	my $problemSeed;
	if ( defined($r->param('problemSeed'))	) {
		$problemSeed            =   $r->param('problemSeed');	
	} elsif (defined($problem_record) and  $problem_record->can('problem_seed')) {
		$problemSeed            =   $problem_record->problem_seed;
	}
	# make absolutely sure that the problem seed is defined, if it hasn't been.
	$problemSeed				=	'123456' unless defined($problemSeed) and $problemSeed =~/\S/;
	
	##############################################################################
	# read and update the targetFile and targetFile.tmp files in the directory
	# if a .tmp file already exists use that, unless the revert button has been pressed.
	# These .tmp files are
	# removed when the file is finally saved.
	##############################################################################
	
	my $problemContents	= '';
	my $currentSourceFilePath	=	'';
	my $editErrors = '';	

	my $inputFilePath           =  (-r "$editFilePath.$editFileSuffix")?"$editFilePath.$editFileSuffix" : $editFilePath;
	$inputFilePath              =   $editFilePath  if defined($submit_button) and $submit_button eq 'Revert';
	
	if (not defined($submit_button) or $submit_button eq 'Revert' ) {
		# this is a fresh editing job
		# copy the pg file to a new file with the same name with .tmp added
		# store this name in the $self->currentSourceFilePath for use in body 
		eval { $problemContents			=	WeBWorK::Utils::readFile($inputFilePath)    };  
		# try to read file
		$problemContents = $@ if $@;
		$editErrors .= $problemContents;
		$currentSourceFilePath			=	"$editFilePath.$editFileSuffix"; 
		$self->{currentSourceFilePath}	=	$currentSourceFilePath; 
		$self->{problemPath}            =   $editFilePath;
	} elsif ($submit_button	eq 'Refresh' ) {
		# grab the problemContents from the form in order to save it to the tmp file
		# store tmp file name in the $self->currentSourceFilePath for use in body 
		
		$problemContents				=	$r->param('problemContents');
		$currentSourceFilePath			=	"$editFilePath.$editFileSuffix";	
		$self->{currentSourceFilePath}	=	$currentSourceFilePath;
		$self->{problemPath}            =   $editFilePath;
	} elsif ($submit_button eq 'Save') {
		# grab the problemContents from the form in order to save it to the permanent file
		# later we will unlink (delete) the temporary file
	 	# store permanent file name in the $self->currentSourceFilePath for use in body 
		
		$problemContents				=	$r->param('problemContents');
		$currentSourceFilePath			=	"$editFilePath"; 		
		$self->{currentSourceFilePath}	=	$currentSourceFilePath;	
		$self->{problemPath}            =   $editFilePath;
	} elsif ($submit_button eq 'Save as') {
		# grab the problemContents from the form in order to save it to a new permanent file
		# later we will unlink (delete) the current temporary file
	 	# store new permanent file name in the $self->currentSourceFilePath for use in body 
		
		$problemContents				=	$r->param('problemContents');
		$currentSourceFilePath			=	$ce->{courseDirs}->{templates} . '/' .$r->param('save_to_new_file'); 		
		$self->{currentSourceFilePath}	=	$currentSourceFilePath;	
		$self->{problemPath}            =   $currentSourceFilePath;
	} else {
		# give a warning
		die "Unrecognized submit command $submit_button";
	}
	
	# Handle the problem of line endings.  Make sure that all of the line endings.  Convert \r\n to \n
	$problemContents    =~    s/\r\n/\n/g;
	$problemContents    =~    s/\r/\n/g;
	
	# FIXME  convert all double returns to paragraphs for .txt files
	if ($self->{file_type} eq 'course_info' ) {
		$problemContents    =~    s/\n\n/\n<p>\n/g;
	}
	##############################################################################
	#
	# write changes to the approriate files
	# FIXME  make sure that the permissions are set correctly!!!
	# Make sure that the warning is being transmitted properly.
	##############################################################################
	# FIXME  set a local state rather continue to call on the submit button.
	if (defined($submit_button) and $submit_button eq 'Save as' and defined($currentSourceFilePath) and -e $currentSourceFilePath) {
		warn "File $currentSourceFilePath exists.  File not saved.";
	} else {
		eval {
			local *OUTPUTFILE;
			open OUTPUTFILE, ">", $currentSourceFilePath
					or die "Failed to write to $currentSourceFilePath.  
					It is likely that the permissions in the template directory have not been set correctly.".
					"The web server must be able to create and write to files in the directory containing the problem. 
					$!";
			print OUTPUTFILE $problemContents;
			close OUTPUTFILE;
		};
	}
	# record an error string for later use if there was a difficulty in writing to the file
	# FIXME is this string ever inspected?
	
	my $openTempFileErrors = $@ if $@;
	
	if (  $openTempFileErrors)   {
	    
		$self->{openTempFileErrors}	= "Unable to write to $currentSourceFilePath: $openTempFileErrors";
		#diagnose errors:
		warn "Editing errors: $openTempFileErrors\n";
		warn "The file $currentSourceFilePath exists. \n " if -e $currentSourceFilePath; #FIXME 
		warn "The file $currentSourceFilePath cannot be found. \n " unless -e $currentSourceFilePath;
		warn "The file $currentSourceFilePath does not have write permissions. \n"
		                 if -e $currentSourceFilePath and not -w $currentSourceFilePath;
		
		
		
	} else {	
		# unlink the temporary file if there are no errors and the save button has been pushed
	    
		$self->{openTempFileErrors}	=	'';
		unlink("$editFilePath.$editFileSuffix") if defined($submit_button) and ($submit_button eq 'Save' or $submit_button eq 'Save as');		
	};
	
		
	# return values for use in the body subroutine
#	$self->{problemPath}              =   $editFilePath;
	$self->{inputFilePath}            =   $inputFilePath;
	$self->{displayMode}              =   $displayMode;
	$self->{problemSeed}              =   $problemSeed;
	$self->{r_problemContents}        =   \$problemContents;
	$self->{editFileSuffix}           =   $editFileSuffix;


	
	
}
sub saveFile {
	my $self     = shift;
	





}
sub path {
	my $self          = shift;
	my $r             = $self->{r};
	my $set_id        = '';
	my $problem_id    = '';
	unless (defined( $r->param("file_type") and $r->param("file_type") eq 'course_info' ) ){
		$set_id        = $r->urlpath->arg("setID");
		$problem_id    = $r->urlpath->arg("problemID");
	}
	#FIXME           this is a bad way to pass the args, since it's position changes if the set/problem info 
	# isn't there
	my $args          = $_[-1];

	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home"          => "$root",
		$courseName     => "$root/$courseName",
		'instructor'    => "$root/$courseName/instructor",
		'sets'          => "$root/$courseName/instructor/sets/",
		"$set_id"       => "$root/$courseName/instructor/sets/$set_id/",
		"problems"      => "$root/$courseName/instructor/sets/$set_id/problems",
		"$problem_id"   => ''
	);
}
sub body {
	my $self = shift;
	
	# test area
	my $r       =   $self->{r};
	my $db      =   $self->{db};
	my $ce      =   $self->{ce};
	my $user    =   $r->param('user');
	
	
	
	################
	# Gathering info
	# What is needed
	#     $editFilePath  -- 
	#     $formURL -- given by $r->uri
	#     $tmpProblemPath 
	my $editFilePath 	         =   $self->{problemPath};    # path to the permanent file to be edited
	my $inputFilePath            =   $self->{inputFilePath};  # path to the file currently being worked with (might be a .tmp file)
	
	
	
	

	my $header = CGI::i("Editing problem:  $inputFilePath");

	#########################################################################
	# Find the text for the problem, either in the tmp file, if it exists
	# or in the original file in the template directory
	#########################################################################
	my $problemContents = ${$self->{r_problemContents}};

#	eval { $problemContents	=	WeBWorK::Utils::readFile($editFilePath)  };  # try to read file
#	$problemContents = $@ if $@;
	
			
			
	#########################################################################
	# Format the page
	#########################################################################
	# Define parameters for textarea
	# FIXME 
	# Should the seed be set from some particular user instance??
	# The mode list should be obtained from global.conf ultimately
	my $rows 		= 	20;
	my $columns		= 	80;
	my $mode_list 	= 	['plainText','formattedText','images'];
	my $displayMode	= 	$self->{displayMode};
	my $problemSeed	=	$self->{problemSeed};	
	my $uri			=	$r->uri;
	########################################################################
	# Define a link to view the problem
	#FIXME
	
	#########################################################################

	
	warn "Errors in the problem ".CGI::br().$self->{editErrors} if $self->{editErrors};

	   
	return CGI::p($header),
		#CGI::start_form("POST",$r->uri,-target=>'_problem'),  doesn't pass on the target parameter???
		qq!<form method="POST" action="$uri" enctype="application/x-www-form-urlencoded", target="_problem">!, 
		$self->hidden_authen_fields,
		CGI::hidden(-name=>'file_type',-default=>$self->{file_type}),
		CGI::div(
		'Seed: ',
		CGI::textfield(-name=>'problemSeed',-value=>$problemSeed),
		'Mode: ',
		CGI::popup_menu(-name=>'displayMode', -'values'=>$mode_list,
													 -default=>$displayMode),
		CGI::a(
			{-href=>'http://webwork.math.rochester.edu/docs/docs/pglanguage/manpages/',-target=>"manpage_window"},
			'Manpages',
			)
		),
		CGI::p(
			CGI::textarea(-name => 'problemContents', -default => $problemContents,
						  -rows => $rows, -columns => $columns, -override => 1,
			),
		),
		CGI::p(
			CGI::submit(-value=>'Refresh',-name=>'submit'),
			CGI::submit(-value=>'Save',   -name=>'submit'),
			CGI::submit(-value=>'Revert', -name=>'submit'),
			CGI::submit(-value=>'Save as',-name=>'submit'),
			CGI::textfield(-name=>'save_to_new_file', -value=>""),
		),	
		CGI::end_form(),


}



1;
