################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/PGProblemEditor.pm,v 1.25 2004/03/04 21:05:58 sh002i Exp $
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

#our $libraryName;
#our $rowheight;

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $urlpath = $r->urlpath;
	
	my $submit_button = $r->param('submit');  # obtain submit command from form

	# Save problem to permanent or temporary file, then redirect for viewing
	if (defined($submit_button) and ($submit_button eq 'Save' or $submit_button eq 'Refresh')) {
		my $setName = $r->urlpath->arg("setID");
		my $problemNumber = $r->urlpath->arg("problemID");
		
		# write the necessary files
		# return file path for viewing problem in $self->{currentSourceFilePath}
		# obtain the appropriate seed
		$self->saveFileChanges($setName, $problemNumber);
		
		##### calculate redirect URL based on file type #####
		
		# get some information
		#my $hostname = $r->hostname();
		#my $port = $r->get_server_port();
		#my $uri = $r->uri;
		my $courseName = $urlpath->arg("courseID");
		my $problemSeed = ($r->param('problemSeed')) ? $r->param('problemSeed') : '';
		my $displayMode = ($r->param('displayMode')) ? $r->param('displayMode') : '';
		
		my $viewURL = '';
		
		# problems redirect to Problem.pm
		$self->{file_type} eq 'problem' and do {
			my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",
				courseID => $courseName, setID => $setName, problemID => $problemNumber);
			$viewURL = $self->systemLink($problemPage,
				params => {
					displayMode => $displayMode,
					problemSeed => $problemSeed,
					editMode => ($submit_button eq "Save" ? "savedFile" : "temporaryFile"),
					sourceFilePath => $self->{currentSourceFilePath},
				}
			);
		};
		
		# set headers redirect to ProblemSet.pm
		$self->{file_type} eq 'set_header' and do {
			my $problemSetPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
				courseID => $courseName, setID => $setName);
			$viewURL = $self->systemLink($problemSetPage,
				params => {
					displayMode => $displayMode,
					problemSeed => $problemSeed,
					editMode => ($submit_button eq "Save" ? "savedFile" : "temporaryFile"),
				}
			);
		};
		
		# course info redirects to ProblemSets.pm
		$self->{file_type} eq 'course_info' and do {
			my $problemSetsPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",
				courseID => $courseName);
			$viewURL = $self->systemLink($problemSetsPage,
				params => {
					editMode => ($submit_button eq "Save" ? "savedFile" : "temporaryFile"),
				}
			);
		};
		
		if ($viewURL) {
			$self->reply_with_redirect($viewURL);
		} else {
			die "Invalid file_type ", $self->{file_type}, " specified by saveFileChanges";
		}
	}
}

sub initialize  {
	my ($self) = @_;
	my $r = $self->r;
	
	my $setName = $r->urlpath->arg("setID");
	my $problemNumber = $r->urlpath->arg("problemID");
	
	# if we got to initialize(), then saveFileChanges was not called in pre_header_initialize().
	# therefore we call it here:
	$self->saveFileChanges($setName, $problemNumber);
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	
	# Gathering info
	my $editFilePath = $self->{problemPath}; # path to the permanent file to be edited
	my $inputFilePath = $self->{inputFilePath}; # path to the file currently being worked with (might be a .tmp file)
	
	my $header = CGI::i("Editing problem:  $inputFilePath");
	
	#########################################################################
	# Find the text for the problem, either in the tmp file, if it exists
	# or in the original file in the template directory
	#########################################################################
	
	my $problemContents = ${$self->{r_problemContents}};
	
	#########################################################################
	# Format the page
	#########################################################################
	
	# Define parameters for textarea
	# FIXME 
	# Should the seed be set from some particular user instance??
	# The mode list should be obtained from global.conf ultimately
	my $rows = 20;
	my $columns = 80;
	my $mode_list = ['plainText','formattedText','images'];
	my $displayMode = $self->{displayMode};
	my $problemSeed = $self->{problemSeed};	
	my $uri = $r->uri;
	
	return CGI::p($header),
		#CGI::start_form("POST",$r->uri,-target=>'_problem'),  doesn't pass on the target parameter???
		# THIS IS BECAUSE TARGET IS NOT A PARAMETER OF <FORM>!!!!!!!!
		qq!<form method="POST" action="$uri" enctype="application/x-www-form-urlencoded", target="_problem">!, 
		$self->hidden_authen_fields,
		CGI::hidden(-name=>'file_type',-default=>$self->{file_type}),
		CGI::div(
			'Seed: ',
			CGI::textfield(-name=>'problemSeed',-value=>$problemSeed),
			'Mode: ',
			CGI::popup_menu(-name=>'displayMode', -values=>$mode_list, -default=>$displayMode),
			CGI::a({-href=>'http://webwork.math.rochester.edu/docs/docs/pglanguage/manpages/',-target=>"manpage_window"},
				'Manpages',
			)
		),
		CGI::p(
			CGI::textarea(
				-name => 'problemContents', -default => $problemContents,
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

################################################################################
# Utilities
################################################################################

# saveFileChanges does most of the work. it is a separate method so that it can
# be called from either pre_header_initialize() or initilize(), depending on
# whether a redirect is needed or not.
# 
# it actually does a lot more than save changes to the file being edited, and
# sometimes less.

sub saveFileChanges {
	my ($self, $setName, $problemNumber) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	my $courseName = $urlpath->arg("courseID");
	my $user = $r->param('user');
	my $effectiveUserName = $r->param('effectiveUser');

	$setName = '' unless defined $setName;
	$problemNumber = '' unless defined $problemNumber;
	
	##### Determine path to the file to be edited. #####
	
	my $editFilePath = $ce->{courseDirs}->{templates};
	my $problem_record = undef;
	
	my $file_type = $r->param("file_type") || '';
	
	if ($file_type eq 'course_info') {
		# we are editing the course_info file
		$self->{file_type}       = 'course_info';
		
		# value of courseFiles::course_info is relative to templates directory
		$editFilePath           .= '/' . $ce->{courseFiles}->{course_info};
	} else {
		# we are editing a problem file or a set header file
		
		# FIXME  there is a discrepancy in the way that the problems are found.
		# FIXME  more error checking is needed in case the problem doesn't exist.
		# (i wonder what the above comments mean... -sam)
		
		if (defined $problemNumber) {
			if ($problemNumber == 0) {
				# we are editing a header file
				$self->{file_type} = 'set_header';
				
				# first try getting the merged set for the effective user
				my $set_record = $db->getMergedSet($effectiveUserName, $setName); # checked
				
				# if that doesn't work (the set is not yet assigned), get the global record
				$set_record = $db->getGlobalSet($setName); # checked
				
				# bail if no set is found
				die "Cannot find a set record for set $setName" unless defined($set_record);
				
				$editFilePath .= '/' . $set_record->set_header;
			} else {
				# we are editing a "real" problem
				$self->{file_type} = 'problem';
				
				# first try getting the merged problem for the effective user
				$problem_record = $db->getMergedProblem($effectiveUserName, $setName, $problemNumber); # checked
				
				# if that doesn't work (the problem is not yet assigned), get the global record
				$problem_record = $db->getGlobalProblem($setName, $problemNumber) unless defined($problem_record); # checked
				
				# bail if no problem is found
				die "Cannot find a problem record for set $setName / problem $problemNumber" 
					unless defined($problem_record);
				
				$editFilePath .= '/' . $problem_record->source_file;
			}
		}
	}
	
	my $editFileSuffix = $user.'.tmp';
	my $submit_button = $r->param('submit');
	
	##############################################################################
	# Determine the display mode
	# try to get problem seed from the input parameter, or from the problem record
	# This will be needed for viewing the problem via redirect.
	# They are also two of the parameters which can be set by the editor
	##############################################################################
	
	my $displayMode;
	if (defined $r->param('displayMode')) {
		$displayMode = $r->param('displayMode');
	} else {
		$displayMode = $ce->{pg}->{options}->{displayMode};
	}
	
	my $problemSeed;
	if (defined $r->param('problemSeed')) {
		$problemSeed = $r->param('problemSeed');	
	} elsif (defined($problem_record) and  $problem_record->can('problem_seed')) {
		$problemSeed = $problem_record->problem_seed;
	}
	
	# make absolutely sure that the problem seed is defined, if it hasn't been.
	$problemSeed = '123456' unless defined $problemSeed and $problemSeed =~/\S/;
	
	##############################################################################
	# read and update the targetFile and targetFile.tmp files in the directory
	# if a .tmp file already exists use that, unless the revert button has been pressed.
	# These .tmp files are
	# removed when the file is finally saved.
	##############################################################################
	
	my $problemContents = '';
	my $currentSourceFilePath = '';
	my $editErrors = '';	
	
	my $inputFilePath;
	if (-r "$editFilePath.$editFileSuffix") {
		$inputFilePath = "$editFilePath.$editFileSuffix";
	} else {
		$inputFilePath = $editFilePath;
	}
	
	$inputFilePath = $editFilePath  if defined($submit_button) and $submit_button eq 'Revert';
	
	##### handle button clicks #####
	
	if (not defined $submit_button or $submit_button eq 'Revert' ) {
		# this is a fresh editing job
		# copy the pg file to a new file with the same name with .tmp added
		# store this name in the $self->currentSourceFilePath for use in body 
		
		# try to read file
		eval { $problemContents = WeBWorK::Utils::readFile($inputFilePath) };
		$problemContents = $@ if $@;
		
		$currentSourceFilePath = "$editFilePath.$editFileSuffix"; 
		$self->{currentSourceFilePath} = $currentSourceFilePath; 
		$self->{problemPath} = $editFilePath;
	} elsif ($submit_button	eq 'Refresh') {
		# grab the problemContents from the form in order to save it to the tmp file
		# store tmp file name in the $self->currentSourceFilePath for use in body 
		$problemContents = $r->param('problemContents');
		
		$currentSourceFilePath = "$editFilePath.$editFileSuffix";	
		$self->{currentSourceFilePath} = $currentSourceFilePath;
		$self->{problemPath} = $editFilePath;
	} elsif ($submit_button eq 'Save') {
		# grab the problemContents from the form in order to save it to the permanent file
		# later we will unlink (delete) the temporary file
	 	# store permanent file name in the $self->currentSourceFilePath for use in body 
		$problemContents = $r->param('problemContents');
		
		$currentSourceFilePath = "$editFilePath"; 		
		$self->{currentSourceFilePath} = $currentSourceFilePath;	
		$self->{problemPath} = $editFilePath;
	} elsif ($submit_button eq 'Save as') {
		# grab the problemContents from the form in order to save it to a new permanent file
		# later we will unlink (delete) the current temporary file
	 	# store new permanent file name in the $self->currentSourceFilePath for use in body 
		$problemContents = $r->param('problemContents');
		$currentSourceFilePath = $ce->{courseDirs}->{templates} . '/' .$r->param('save_to_new_file'); 		
		$self->{currentSourceFilePath} = $currentSourceFilePath;	
		$self->{problemPath} = $currentSourceFilePath;
	} else {
		die "Unrecognized submit command: $submit_button";
	}
	
	# Handle the problem of line endings.  Make sure that all of the line endings.  Convert \r\n to \n
	$problemContents =~ s/\r\n/\n/g;
	$problemContents =~ s/\r/\n/g;
	
	# FIXME  convert all double returns to paragraphs for .txt files
	# instead of doing this here, it should be done n the PLACE WHERE THE FILE IS DISPLAYED!!!
	#if ($self->{file_type} eq 'course_info' ) {
	#	$problemContents =~ s/\n\n/\n<p>\n/g;
	#}
	
	##############################################################################
	# write changes to the approriate files
	# FIXME  make sure that the permissions are set correctly!!!
	# Make sure that the warning is being transmitted properly.
	##############################################################################
	
	# FIXME  set a local state rather continue to call on the submit button.
	if (defined $submit_button and $submit_button eq 'Save as' and defined $currentSourceFilePath and -e $currentSourceFilePath) {
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
		# FIXME: why is this in an eval{} ?!?!?!
	}
	
	# record an error string for later use if there was a difficulty in writing to the file
	# FIXME is this string ever inspected?
	
	my $openTempFileErrors = $@ if $@;
	
	if ($openTempFileErrors) {
		$self->{openTempFileErrors}	= "Unable to write to $currentSourceFilePath: $openTempFileErrors";
		#diagnose errors:
		warn "Editing errors: $openTempFileErrors\n";
		warn "The file $currentSourceFilePath exists. \n " if -e $currentSourceFilePath; #FIXME 
		warn "The file $currentSourceFilePath cannot be found. \n " unless -e $currentSourceFilePath;
		warn "The file $currentSourceFilePath does not have write permissions. \n"
		                 if -e $currentSourceFilePath and not -w $currentSourceFilePath;
	} else {	
		# unlink the temporary file if there are no errors and the save button has been pushed
		$self->{openTempFileErrors}	= '';
		unlink("$editFilePath.$editFileSuffix")
			if defined $submit_button and ($submit_button eq 'Save' or $submit_button eq 'Save as');
	}
		
	# return values for use in the body subroutine
	$self->{inputFilePath}            =   $inputFilePath;
	$self->{displayMode}              =   $displayMode;
	$self->{problemSeed}              =   $problemSeed;
	$self->{r_problemContents}        =   \$problemContents;
	$self->{editFileSuffix}           =   $editFileSuffix;
}

1;
