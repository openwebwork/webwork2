################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/PGProblemEditor.pm,v 1.56 2005/07/30 17:26:45 gage Exp $
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

WeBWorK::ContentGenerator::Instructor::PGProblemEditor - Edit a pg file

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readFile surePathToFile);
use Apache::Constants qw(:common REDIRECT);
use HTML::Entities;
use URI::Escape;
use WeBWorK::Utils;
use WeBWorK::Utils::Tasks qw(fake_set fake_problem);

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
#            this flag is read by Problem.pm and ProblemSet.pm, perhaps others
# The TEMPFILESUFFIX is "user_name.tmp" by default.  It's definition should be moved to Instructor.pm #FIXME                              
###########################################################

###########################################################
# The behavior of this module is essentially defined 
# by the values of $file_type and the submit button which is placed in $action
#############################################################
#  File types which can be edited
#
#  file_type  eq 'problem'
#                 this is the most common type -- this editor can be called by an instructor when viewing any problem.
#                 the information for retrieving the source file is found using the problemID in order to look
#                 look up the source file path.
#
#  file_type  eq 'problem_with_source'
#                 This is the same as the 'problem' file type except that the source for the problem is found in
#                 the parameter $r->param('sourceFilePath').
#
#  file_type  eq 'set_header'
#                 This is a special case of editing the problem.  The set header is often listed as problem 0 in the set's list of problems.
#
#  file_type  eq 'hardcopy_header'
#                  This is a special case of editing the problem.  The hardcopy_header is often listed as problem 0 in the set's list of problems.
#                  But it is used instead of set_header when producing a hardcopy of the problem set in the TeX format, instead of producing HTML
#                  formatted version for use on the computer screen.
#
#  filte_type eq 'course_info
#                 This allows editing of the course_info.txt file which gives general information about the course.  It is called from the
#                 ProblemSets.pm module.
#
#  file_type  eq 'blank_problem'
#                 This is a special call which allows one to create and edit a new PG problem.  The "stationery" source for this problem is
#                 stored in the conf/snippets directory and defined in global.conf by $webworkFiles{screenSnippets}{blankProblem}
#############################################################
# submit button actions  -- these and the file_type determine the state of the module
#      Save                       ---- action = save
#      Save as                    ---- action = save_as
#      View Problem               ---- action = refresh
#      Add this problem to:       ---- action = add_problem_to_set 
#      Make this set header for:  ---- action = add_set_header_to_set
#      Revert                     ---- action = revert
#      no submit button defined   ---- action = fresh_edit
###################################################
# 
# Determining which is the correct path to the file is a mess!!! FIXME
# The path to the file to be edited is eventually put in tempFilePath
#
# $problemPath is also used as is editFilePath.  let's try to regularize these.
#(sourceFile) (problemPath)(tempFilePath)(editFilePath)(forcedSourceFile)(problemPath)
#input parameter can be:  sourceFilePath
#################################################################
# params read
# user
# effectiveUser
# submit
# file_type
# problemSeed
# displayMode
# edit_level
# make_local_copy
# sourceFilePath
# problemContents
# save_to_new_file
# 

#our $libraryName;
#our $rowheight;
our $TEMPFILESUFFIX; 

sub pre_header_initialize {
	my ($self)         = @_;
	my $r              = $self->r;
	my $ce             = $r->ce;
	my $urlpath        = $r->urlpath;
	my $authz          = $r->authz;
	my $user           = $r->param('user');
	$TEMPFILESUFFIX    = $user.'.tmp';

	my $submit_button   = $r->param('submit');  # obtain submit command from form
	my $file_type       = $r->param("file_type") || '';
	my $setName         = $r->urlpath->arg("setID") ;  # using $r->urlpath->arg("setID")  ||'' causes trouble with set 0!!!
	my $problemNumber   = $r->urlpath->arg("problemID");
   
	# Check permissions
	return unless ($authz->hasPermissions($user, "access_instructor_tools"));
	return unless ($authz->hasPermissions($user, "modify_problem_sets"));
   
    #############################################################################
	# Save file to permanent or temporary file, then redirect for viewing
	#############################################################################
	#
	#  Any file "saved as" should be assigned to "Undefined_Set" and redirectoed to be viewed again in the editor
	#
	#  Problems "saved" or 'refreshed' are to be redirected to the Problem.pm module
	#  Set headers which are "saved" are to be redirected to the ProblemSet.pm page
	#  Hardcopy headers which are "saved" are aso to be redirected to the ProblemSet.pm page
	#  Course_info files are redirected to the ProblemSets.pm page
	##############################################################################
	


	######################################
    # Insure that file_type is defined
	######################################
	# We have already read in the file_type parameter from the form
	#
	# If this has not been defined we are  dealing with a set header
	# or regular problem
	if (defined($file_type) and ($file_type =~/\S/)) { #file_type is defined and is not blank
		# file type is already defined -- do nothing
	} else {
	    # if "sourcFilePath" is defined in the form, then we are getting the path directly.
		# if the problem number is defined and is 0
		# then we are dealing with some kind of 
		# header file.  The default is 'set_header' which prints properly
		# to the screen.
		# If the problem number is not zero, we are dealing with a real problem
		######################################
		if ( defined($r->param('sourceFilePath') and $r->param('sourceFilePath') =~/\S/) ) {
			$file_type ='source_path_for_problem_file';
		} elsif ( defined($problemNumber) ) {
			 if ( $problemNumber =~/^\d+$/ and $problemNumber == 0 ) {  # if problem number is numeric and zero
                $file_type = 'set_header' unless $file_type eq 'set_header' 
                                               or $file_type eq 'hardcopy_header';                                    
             } else {
             	$file_type = 'problem';      	
             }
			           
		}
	}
	die "The file_type variable has not been defined or is blank." unless defined($file_type) and $file_type =~/\S/;
	$self->{file_type} = $file_type;
	
	##########################################
	# File type is one of:     blank_problem course_info  problem set_header hardcopy_header problem_with_source  
    ##########################################
    #
    # Determine the path to the file
    #
    ###########################################
    	$self->getFilePaths($setName, $problemNumber, $file_type,$TEMPFILESUFFIX);
    	# result stored in $self->{editFilePath}, and $self->{tempFilePath}
    ##########################################
    #
    # Determine action
    #
    ###########################################
    # Submit button is one of: "add this problem to" , "add this set header to ", "Refresh"  "Revert" "Save" "Save As" 
    $submit_button = $r->param('submit');
    SUBMIT_CASE: {
    	(! defined($submit_button) ) and do {   # fresh problem to edit
    		$self->{action} = 'fresh_edit';
    		last SUBMIT_CASE;
    	};
    	
    	($submit_button eq 'Add this problem to: ') and do {
    		$self->{action} = 'add_problem_to_set';
    		last SUBMIT_CASE;
    	};
    	
    	($submit_button eq 'Make this the set header for: ') and do {
    		$self->{action} = 'add_set_header_to_set';
    		last SUBMIT_CASE;
    	};
    	
    	($submit_button eq 'View  problem') and  do {
    		$self->{action} ='refresh';
    		last SUBMIT_CASE;
    	};
    	
    	($submit_button eq 'Revert') and do {
    		$self->{action} = 'revert';
    		last SUBMIT_CASE;
    	};
    	
    	($submit_button eq 'Save') and do {
    		$self->{action} = 'save';
    		last SUBMIT_CASE;
    	};
    	
    	($submit_button eq 'Save as') and do {
    		$self->{action} = 'save_as';
    		last SUBMIT_CASE;
    	};
    	
    	($submit_button eq 'Add problem to: ') and do {
    		$self->{action} = 'add_problem_to_set';
    		last SUBMIT_CASE;
    	};
    	($submit_button eq 'Make local copy at: ') and do {
    		$self->{action} = 'make_local_copy';
    		last SUBMIT_CASE;
    	};
    	# else
    	die "Unrecognized submit command: |$submit_button|";
    	
    } # END SUBMIT_CASE
    

    ###########################################
    # Save file
    ######################################
		
		# The subroutine below writes the necessary files and obtains the appropriate seed.
		# and returns
		#         $self->{problemPath}   --- file path for viewing problem in $self->{problemPath}
		#         $self->{failure}

		
		$self->saveFileChanges($setName, $problemNumber, $file_type,$TEMPFILESUFFIX);
	
	##############################################################################
	# displayMode   and problemSeed
	#
	# Determine the display mode
	# If $self->{problemSeed} was obtained within saveFileChanges from the problem_record
	# then it can be overridden by the value obtained from the form.
	# Insure that $self->{problemSeed} has some non-empty value
	# displayMode and problemSeed 
	# will be needed for viewing the problem via redirect.
	# They are also two of the parameters which can be set by the editor
	##############################################################################
	
	if (defined $r->param('displayMode')) {
		$self->{displayMode} = $r->param('displayMode');
	} else {
		$self->{displayMode} = $ce->{pg}->{options}->{displayMode};
	}
	
	# form version of problemSeed overrides version obtained from the the problem_record
	# inside saveFileChanges
	$self->{problemSeed} = $r->param('problemSeed') if (defined $r->param('problemSeed'));	
	# Make sure that the problem seed has some value
	$self->{problemSeed} = '123456' unless defined $self->{problemSeed} and $self->{problemSeed} =~/\S/;
	
	##############################################################################
	# Return 
	#   If  file saving fails or 
	#   if no redirects are required. No further processing takes place in this subroutine.
	#   Redirects are required only for the following submit values
	#        'Save'
	#        'Save as'
	#        'Refresh'
	#        add problem to set
	#        add set header to set
	# 
    #########################################
    
    return if $self->{failure};
    # FIXME: even with an error we still open a new page because of the target specified in the form
	

	# Some cases do not need a redirect: save, refresh, save_as, add_problem_to_set, add_header_to_set,make_local_copy
	my $action = $self->{action};

    return unless $action eq 'save' 
	           or $action eq 'refresh'
	           or $action eq 'save_as'
	           or $action eq 'add_problem_to_set'
	           or $action eq 'make_local_copy'
	           or $action eq 'add_set_header_to_set';
	

	######################################
	# calculate redirect URL based on file type 
	######################################	
	my $courseName  = $urlpath->arg("courseID");
	my $problemSeed = ($r->param('problemSeed')) ? $r->param('problemSeed') : '';
	my $displayMode = ($r->param('displayMode')) ? $r->param('displayMode') : '';
	
	my $viewURL = '';
	
	######################################
	# problem file_type
	#     redirect to Problem.pm with setID = "Undefined_Set if "Save As" option is chosen
	#     redirect to Problem.pm with setID = current $setID if "Save" or "Revert" or "Refresh is chosen"
	######################################
	REDIRECT_CASES: {
		($file_type eq 'problem' or $file_type eq 'source_path_for_problem_file' or $file_type eq 'blank_problem') and do {
			my $sourceFilePath = $self->{problemPath};
			# strip off template directory prefix
			$sourceFilePath =~ s|^$ce->{courseDirs}->{templates}/||;
			if ($action eq 'save_as') { # redirect to myself
				my $edit_level = $r->param("edit_level") || 0;
				$edit_level++;
				
				my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
					courseID => $courseName, setID => 'Undefined_Set', problemID => 'Undefined_Problem'
				);
				$viewURL = $self->systemLink($problemPage, 
				                             params=>{
				                                 sourceFilePath     => $sourceFilePath, 
				                                 edit_level         => $edit_level,
				                                 file_type          => 'source_path_for_problem_file',
												 status_message     => uri_escape($self->{status_message})

				                             }
				);

			
			} elsif ( $action eq 'add_problem_to_set') {
			    
				my $targetSetName = $r->param('target_set');
				my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",
					courseID => $courseName, setID => $targetSetName, 
					problemID => WeBWorK::Utils::max( $r->db->listGlobalProblems($targetSetName)) 
				);
				$viewURL = $self->systemLink($problemPage,
						params => {
							displayMode     => $displayMode,
							problemSeed     => $problemSeed,
							editMode        => "savedFile",
							sourceFilePath  => $sourceFilePath,
							status_message     => uri_escape($self->{status_message})

						}
				);
			} elsif ($action eq 'make_local_copy') { # redirect to myself
				my $edit_level = $r->param("edit_level") || 0;
				$edit_level++;
				
				my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
					courseID => $courseName, setID => $setName, problemID => $problemNumber
				);
				$viewURL = $self->systemLink($problemPage, 
				                             params=>{
				                                 sourceFilePath     => $sourceFilePath, 
				                                 edit_level         => $edit_level,
				                                 file_type          => 'source_path_for_problem_file',
												 status_message     => uri_escape($self->{status_message})

				                             }
				);

			
			} elsif ( $action eq 'add_set_header_to_set') {
				my $targetSetName = $r->param('target_set');
				my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
					courseID => $courseName, setID => $targetSetName
				);
				$viewURL = $self->systemLink($problemPage,
						params => {
							displayMode     => $displayMode,
							editMode        => "savedFile",
							status_message     => uri_escape($self->{status_message})
						}
				);
			} else { # saved problems and refreshed  problems redirect to Problem.pm
				my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",
					courseID => $courseName, setID => $setName, problemID => $problemNumber
				);
				$viewURL = $self->systemLink($problemPage,
					params => {
						displayMode     => $displayMode,
						problemSeed     => $problemSeed,
						editMode        => ($action eq "save" ? "savedFile" : "temporaryFile"),
						sourceFilePath  => $sourceFilePath,
						status_message     => uri_escape($self->{status_message})

					}
				);
			} 
			last REDIRECT_CASES;
		};
		######################################
		# blank_problem file_type
		#          redirect to Problem.pm
		######################################
		
		$file_type eq 'blank_problem' and do {
			return;  # no redirect is needed
		};
		
		######################################
		# set headers file_type
		#          redirect to ProblemSet.pm
		######################################
		
		($file_type eq 'set_header' or $file_type eq 'hardcopy_header' ) and do {
			if ($action eq 'save_as') { # redirect to myself
			    my $sourceFilePath = $self->{problemPath};
				# strip off template directory prefix
				$sourceFilePath =~ s|^$ce->{courseDirs}->{templates}/||;

				my $edit_level = $r->param("edit_level") || 0;
				$edit_level++;
				
				my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
					courseID => $courseName, setID => 'Undefined_Set', problemID => 'Undefined_Problem'
				);
				$viewURL = $self->systemLink($problemPage, 
				                             params=>{
				                                 sourceFilePath  => $sourceFilePath, 
				                                 edit_level      => $edit_level,
				                                 file_type       => 'source_path_for_problem_file',
												 status_message     => uri_escape($self->{status_message})
				                             }
				);
			} elsif ( $action eq 'add_set_header_to_set') {
				my $targetSetName = $r->param('target_set');
				my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
					courseID => $courseName, setID => $targetSetName
				);
				$viewURL = $self->systemLink($problemPage,
						params => {
							displayMode     => $displayMode,
							editMode        => "savedFile",
							status_message     => uri_escape($self->{status_message})
						}
				);
			} else {
				my $problemSetPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
					courseID => $courseName, setID => $setName);
				$viewURL = $self->systemLink($problemSetPage,
					params => {
						displayMode        => $displayMode,
						problemSeed        => $problemSeed,
						editMode           => ($action eq "save" ? "savedFile" : "temporaryFile"),
						status_message     => uri_escape($self->{status_message})
					}
				);
			}
			last REDIRECT_CASES;
		};
		######################################
		# course_info file type
		#            redirect to ProblemSets.pm
		######################################
		$file_type eq 'course_info' and do {
			my $problemSetsPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",
				courseID => $courseName);
			$viewURL = $self->systemLink($problemSetsPage,
				params => {
					editMode => ($action eq "save" ? "savedFile" : "temporaryFile"),
					status_message     => uri_escape($self->{status_message})
				}
			);
			last REDIRECT_CASES;
		};
		# else if no redirect needed -- there must be an error.
		die "The file_type $file_type does not have a defined redirect procedure.";
	} # End REDIRECT_CASES
			
	if ($viewURL) {
		$self->reply_with_redirect($viewURL);
	} else {
		die "Invalid file_type $file_type specified by saveFileChanges";
	}
}


sub initialize  {
	my ($self) = @_;
	my $r = $self->r;
	my $authz = $r->authz;
	my $user = $r->param('user');
	
	# Check permissions
	return unless ($authz->hasPermissions($user, "access_instructor_tools"));
	return unless ($authz->hasPermissions($user, "modify_problem_sets"));
	
	my $tempFilePath    = $self->{tempFilePath}; # path to the file currently being worked with (might be a .tmp file)
	my $inputFilePath   = $self->{inputFilePath};   # path to the file for input, (might be a .tmp file)
	my $protected_file = (not -w $inputFilePath ) and -e $inputFilePath;  #FIXME -- let's try to insure that the input file always exists, even for revert.
	
	$self->addmessage($r->param('status_message') ||'');  # record status messages carried over if this is a redirect
	$self->addbadmessage("Changes in this file have not yet been permanently saved.") if -r $tempFilePath;
	
    $self->addbadmessage("This file '$inputFilePath' is protected! ".CGI::br()."To edit this text you must either 'Make a local copy' of this problem, or 
                           use 'Save As' to save it to another file.") if $protected_file;
	
}

sub path {
	my ($self, $args) = @_;
	my $r = $self->r;
	my $urlpath = $r->urlpath;
	my $courseName  = $urlpath->arg("courseID");
	my $setName = $r->urlpath->arg("setID") || '';
	my $problemNumber = $r->urlpath->arg("problemID") || '';

	# we need to build a path to the problem being edited by hand, since it is not the same as the urlpath
	# For this page the bread crum path leads back to the problem being edited, not to the Instructor tool.
	my @path = ( 'WeBWork', $r->location,
	          "$courseName", $r->location."/$courseName",
	          "$setName",    $r->location."/$courseName/$setName",
	          "$problemNumber", $r->location."/$courseName/$setName/$problemNumber",
	          "Editor", ""
	);
	
	#print "\n<!-- BEGIN " . __PACKAGE__ . "::path -->\n";
	print $self->pathMacro($args, @path);
	#print "<!-- END " . __PACKAGE__ . "::path -->\n";
	
	return "";
}
sub title {
	my $self = shift;
	my $r = $self->r;
	my $problemNumber = $r->urlpath->arg("problemID");
	my $file_type = $self->{'file_type'} || '';
	return "Set Header" if ($file_type eq 'set_header');
	return "Hardcopy Header" if ($file_type eq 'hardcopy_header');
	return "Course Information" if($file_type eq 'course_info');
	return 'Problem ' . $r->{urlpath}->name;
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $user = $r->param('user');
	my $make_local_copy = $r->param('make_local_copy');
 
	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to modify problems.")
		unless $authz->hasPermissions($user, "modify_student_data");

	
	# Gathering info
	my $editFilePath    = $self->{editFilePath}; # path to the permanent file to be edited
	my $tempFilePath    = $self->{tempFilePath}; # path to the file currently being worked with (might be a .tmp file)
	my $inputFilePath   = $self->{inputFilePath};   # path to the file for input, (might be a .tmp file)
	my $setName         = $r->urlpath->arg("setID") ;
	my $problemNumber   = $r->urlpath->arg("problemID") ;
    $setName            = defined($setName) ? $setName : '';  # we need this instead of using the || construction 
                                                              # to keep set 0 from being set to the 
                                                              # empty string.
    $problemNumber      = defined($problemNumber) ? $problemNumber : '';
    

	#########################################################################
	# Find the text for the problem, either in the tmp file, if it exists
	# or in the original file in the template directory
	# or in the problem contents gathered in the initialization phase.
	#########################################################################
	
	my $problemContents = ${$self->{r_problemContents}};
	
	unless ( $problemContents =~/\S/)   { # non-empty contents
		if (-r $tempFilePath and not -d $tempFilePath) {
			eval { $problemContents = WeBWorK::Utils::readFile($tempFilePath) };
			$problemContents = $@ if $@;
			$inputFilePath = $tempFilePath;
		} elsif  (-r $editFilePath and not -d $editFilePath) {
			eval { $problemContents = WeBWorK::Utils::readFile($editFilePath) };
			$problemContents = $@ if $@;
			$inputFilePath = $editFilePath;
		} else { # file not existing is not an error
		    #warn "No file exists";
			$problemContents = '';
		}
	} else {
		#warn "obtaining input from r_problemContents";
	}

	my $protected_file = not -w $inputFilePath;
	my $header = CGI::i("Editing problem".CGI::b("set $setName/ problem $problemNumber</emphasis>").CGI::br()." in file $inputFilePath");
	$header = ($inputFilePath =~ /$TEMPFILESUFFIX/) ? CGI::div({class=>'temporaryFile'},$header) : $header;  # use colors if temporary file
	
	#########################################################################
	# Format the page
	#########################################################################
	
	# Define parameters for textarea
	# FIXME 
	# Should the seed be set from some particular user instance??
	my $rows            = 20;
	my $columns         = 80;
	my $mode_list       = $ce->{pg}->{displayModes};
	my $displayMode     = $self->{displayMode};
	my $problemSeed     = $self->{problemSeed};	
	my $uri             = $r->uri;
	my $edit_level      = $r->param('edit_level') || 0;
	my $file_type        = $self->{file_type};
	
	my $force_field = defined($r->param('sourceFilePath')) ?
		CGI::hidden(-name=>'sourceFilePath',
		            -default=>$r->param('sourceFilePath')) : '';

	my @allSetNames = sort $db->listGlobalSets;
	for (my $j=0; $j<scalar(@allSetNames); $j++) {
		$allSetNames[$j] =~ s|^set||;
		$allSetNames[$j] =~ s|\.def||;
	}
	my $target = "problem$edit_level"; 
	# Prepare Preview button
    my $view_problem_form = CGI::start_form({method=>"POST", name=>"editor", action=>"$uri", target=>$target, enctype=>"application/x-www-form-urlencoded"}).
		$self->hidden_authen_fields.
		$force_field.
 		CGI::hidden(-name=>'file_type',-default=>$self->{file_type}).
 		CGI::hidden(-name=>'problemSeed',-default=>$problemSeed).
 		CGI::hidden(-name=>'displayMode',-default=>$displayMode).
 		CGI::hidden(-name=>'problemContents',-default=>$problemContents).
		CGI::submit(-value=>'View  problem',-name=>'submit').
		CGI::end_form();
	# Prepare add to set  buttons
    my $add_files_to_set_buttons = '';
	if ($file_type eq 'problem' or $file_type eq 'source_path_for_problem_file' or $file_type eq 'blank_problem' ) {
		$add_files_to_set_buttons .= CGI::submit(-value=>'Add problem to: ',-name=>'submit' ) ;
	} 
	if ($file_type eq 'set_header'      # set header or the problem number is not a regular positive number
			  or ( $file_type =~ /problem/ and ($problemNumber =~ /\D|^0$|^$/ )) ){
		$add_files_to_set_buttons .=CGI::submit(-value=>'Make this the set header for: ',-name=>'submit' );
	}
	# Add pop-up menu for the target set if either of these buttons has been revealed.
	$add_files_to_set_buttons .= CGI::popup_menu(-name=>'target_set',-values=>\@allSetNames, -default=>$setName) if $add_files_to_set_buttons;
			
 
	return CGI::p($header),
		CGI::start_form({method=>"POST", name=>"editor", action=>"$uri", target=>$target, enctype=>"application/x-www-form-urlencoded"}),
		$self->hidden_authen_fields,
		$force_field,
		CGI::hidden(-name=>'file_type',-default=>$self->{file_type}),
		CGI::div(
			'Seed: ',
			CGI::textfield(-name=>'problemSeed',-value=>$problemSeed),
			'Mode: ',
			CGI::popup_menu(-name=>'displayMode', -values=>$mode_list, -default=>$displayMode),
			CGI::a({-href=>'http://webwork.math.rochester.edu/docs/docs/pglanguage/manpages/',-target=>"manpage_window"},
				'&nbsp;Manpages&nbsp;',
			),
			CGI::a({-href=>'http://devel.webwork.rochester.edu/twiki/bin/view/Webwork/PGmacrosByFile',-target=>"manpage_window"},
				'&nbsp;macro list&nbsp;',
			),
			CGI::a({-href=>'http://devel.webwork.rochester.edu/doc/cvs/pg_HEAD/',-target=>"manpage_window"},
				'&nbsp;pod docs&nbsp;',
			),
		),
		CGI::p(
			CGI::textarea(
				-name => 'problemContents', -default => $problemContents,
				-rows => $rows, -columns => $columns, -override => 1,
			),
		),
		CGI::p(
            $add_files_to_set_buttons,
			CGI::br(),
			CGI::submit(-value=>'View  problem',-name=>'submit'),
			$protected_file ? CGI::submit(-value=>'Save',-name=>'submit', -disabled=>1) : CGI::submit(-value=>'Save',-name=>'submit'),
			CGI::submit(-value=>'Revert', -name=>'submit'),
			CGI::submit(-value=>'Save as',-name=>'submit'),
			CGI::textfield(-name=>'save_to_new_file', -size=>40, -value=>""),
			
		),
		# allow one to make a local copy if the viewed file can't be edited.  #FIXME the method for determining the localfilePath needs work
		(-w $editFilePath) ? "" : CGI::p(CGI::hr(),
            CGI::submit(-value=>'Make local copy at: ',-name=>'submit'), "[TMPL]/".determineLocalFilePath($editFilePath),
            CGI::hidden(-name=>'local_copy_file_path', -value=>determineLocalFilePath($editFilePath) )
		),
		CGI::end_form();
		

}

################################################################################
# Utilities
################################################################################

# determineLocalFilePath   constructs a local file path parallel to a library file path
# This is a subroutine, not a method
# 
sub determineLocalFilePath {
	my $path = shift;
	if ($path =~ /Library/) {
		$path =~ s|^.*?Library/||;  # truncate the url up to a segment such as ...rochesterLibrary/.......
	} else { # if its not in a library we'll just save it locally
		$path = "new_problem_".rand(40);	#l hope there aren't any collisions.
	}
    $path;

}
sub getFilePaths {
	my ($self, $setName, $problemNumber, $file_type, $TEMPFILESUFFIX) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	my $courseName = $urlpath->arg("courseID");
	my $user = $r->param('user');
	my $effectiveUserName = $r->param('effectiveUser');
    
	$setName = '' unless defined $setName;
	$problemNumber = '' unless defined $problemNumber;
	die 'Internal error to PGProblemEditor -- file type is not defined'  unless defined $file_type;

	##########################################################
	# Determine path to the input file to be edited. 
	# set EditFilePath to this value
	#
	# There are potentially four files in play
	#   The permanent path of the input file  == $editFilePath == $self->{problemPath}
	#   A temporary path to the input file    == $tempFilePath== "$editFilePath.$TEMPFILESUFFIX"== $self->{problemPath}
	##########################################################
	# Relevant parameters
	#     $r->param("displayMode")
	#     $r->param('problemSeed')
	#     $r->param('submit')
	#     $r->param('make_local_copy')
	#     $r->param('sourceFilePath')
	#     $r->param('problemContents')
	#     $r->param('save_to_new_file')
	##########################################################################
	# Define the following  variables
	#		path to regular file -- $self->{problemPath} = $editFilePath;
	#	    path to file being read (temporary or permanent) 
	#               --- $self->{problemPath} = $problemPath;	
	#       contents of the file being read  --- $problemContents  	
	#       	$self->{r_problemContents}        =   \$problemContents;
	#       $self->{TEMPFILESUFFIX}           =   $TEMPFILESUFFIX;
    ###########################################################################

	my $editFilePath = $ce->{courseDirs}->{templates};
	
    ##########################################################################
    # Determine path to regular file, place it in $editFilePath
    # problemSeed is defined for the file_type = 'problem' and 'source_path_to_problem'
    ##########################################################################
	CASE: 
	{
		($file_type eq 'course_info') and do {
			# we are editing the course_info file
			# value of courseFiles::course_info is relative to templates directory
			$editFilePath           .= '/' . $ce->{courseFiles}->{course_info};
			last CASE;
		};
		
		($file_type eq 'blank_problem') and do {
			$editFilePath = $ce->{webworkFiles}->{screenSnippets}->{blankProblem};
			$self->addbadmessage("$editFilePath is blank problem template file and should not be edited directly. "
			                     ."First use 'Save as' to make a local copy, then add the file to the current problem set, then edit the file."
			);
			last CASE;
		};
		
		($file_type eq 'set_header' or $file_type eq 'hardcopy_header') and do {
			# first try getting the merged set for the effective user
			my $set_record = $db->getMergedSet($effectiveUserName, $setName); # checked
			# if that doesn't work (the set is not yet assigned), get the global record
			$set_record = $db->getGlobalSet($setName); # checked
			# bail if no set is found
			die "Cannot find a set record for set $setName" unless defined($set_record);
 				
			my $header_file = "";
			$header_file = $set_record->{$file_type};
			if ($header_file && $header_file ne "") {
					$editFilePath .= '/' . $header_file;
			} else {
					# if the set record doesn't specify the filename
					# then the set uses the default from snippets
					# so we'll load that file, but change where it will be saved
					# to and grey out the "Save" button
					# FIXME why does the make_local_copy variable need to be checked?
					# Isn't it automatic that a local copy has to be made?
					#if ($r->param('make_local_copy')) {
						$editFilePath = $ce->{webworkFiles}->{screenSnippets}->{setHeader} if $file_type eq 'set_header';
						$editFilePath = $ce->{webworkFiles}->{hardcopySnippets}->{setHeader} if $file_type eq 'hardcopy_header';
						$self->addbadmessage("$editFilePath is the default header file and cannot be edited directly.");
						$self->addbadmessage("Any changes you make will have to be saved as another file.");
					#}
			}
			last CASE;
		}; #end 'set_header, hardcopy_header' case
		
		($file_type eq 'problem') and do {			
		
			# first try getting the merged problem for the effective user
			my $problem_record = $db->getMergedProblem($effectiveUserName, $setName, $problemNumber); # checked
			
			# if that doesn't work (the problem is not yet assigned), get the global record
			$problem_record = $db->getGlobalProblem($setName, $problemNumber) unless defined($problem_record); # checked
			# bail if no source path for the problem is found ;
		    die "Cannot find a problem record for set $setName / problem $problemNumber" unless defined($problem_record);
			$editFilePath .= '/' . $problem_record->source_file;
			# define the problem seed for later use
			$self->{problemSeed}= $problem_record->problem_seed if  defined($problem_record) and  $problem_record->can('problem_seed') ;  
			last CASE;
		};  # end 'problem' case
		
		($file_type eq 'source_path_for_problem_file') and do {
		  my $forcedSourceFile = $r->param('sourceFilePath');
			# bail if no source path for the problem is found ;
		  die "Cannot find a file path to save to" unless( defined($forcedSourceFile) and ($forcedSourceFile =~ /\S/)  );
		  $self->{problemSeed} = 1234;
		  $editFilePath .= '/' . $forcedSourceFile;
		  last CASE;
		}; # end 'source_path_for_problem_file' case
	}  # end CASE: statement

	
	# if a set record or problem record contains an empty blank for a header or problem source_file
	# we could find ourselves trying to edit /blah/templates/.toenail.tmp or something similar
	# which is almost undoubtedly NOT desirable

	if (-d $editFilePath) {
		my $msg = "The file $editFilePath is a directory!";
		$self->{failure} = 1;
		$self->addbadmessage($msg);
	}
	if (-e $editFilePath and not -r $editFilePath) {   #it's ok if the file doesn't exist, perhaps we're going to create it
	                                                  # with save as
		my $msg = "The file $editFilePath cannot be read!";
		$self->{failure} = 1;
		$self->addbadmessage($msg);	
	}
    #################################################
	# The path to the permanent file is now verified and stored in $editFilePath
	# Whew!!!
	#################################################
	
	my $tempFilePath = "$editFilePath.$TEMPFILESUFFIX";
	$self->{editFilePath}   = $editFilePath;
	$self->{tempFilePath}   = $tempFilePath;
	$self->{inputFilePath}  = (-r "$editFilePath.$TEMPFILESUFFIX") ? $tempFilePath : $editFilePath;

}

################################################################################
# saveFileChanges does most of the work. it is a separate method so that it can
# be called from either pre_header_initialize() or initilize(), depending on
# whether a redirect is needed or not.
# 
# it actually does a lot more than save changes to the file being edited, and
# sometimes less.
################################################################################
sub saveFileChanges {
	my ($self, $setName, $problemNumber, $file_type, $TEMPFILESUFFIX) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	my $courseName = $urlpath->arg("courseID");
	my $user = $r->param('user');
	my $effectiveUserName = $r->param('effectiveUser');

	$setName       = '' unless defined $setName;
	$problemNumber = '' unless defined $problemNumber;
	$file_type     = '' unless defined $file_type;

	my $action        = $self->{action};
	my $editFilePath  = $self->{editFilePath};
	my $tempFilePath  = $self->{tempFilePath}; 	
	##############################################################################
	# read and update the targetFile and targetFile.tmp files in the directory
	# if a .tmp file already exists use that, unless the revert button has been pressed.
	# These .tmp files are
	# removed when the file is finally saved.
	# Place the path of the file to be read in $problemPath.
	##############################################################################
	

	my $problemContents = '';
	my $outputFilePath = undef;   # this is actually the output file for this subroutine
	                              # it is then read in as source in the body of this module
	my $do_not_save    = 0;       # flag to prevent saving of file
	my $editErrors = '';	

	##########################################################################
	# For each of the actions define the following  variables:
	#
	#		path to permanent file -- $self->{problemPath} = $editFilePath;
	#	    path to file being read (temporary or permanent) 
	#               --- $self->{problemPath} = $problemPath;	
	#       contents of the file being read  --- $problemContents  	
	#       	$self->{r_problemContents}        =   \$problemContents;
	#
	#################################
	# handle button clicks #####
	# Read contents of file
	#################################
	ACTION_CASES: {
		($action eq 'fresh_edit') and do {
			# this is a fresh editing job
            # the original file will be read in the body
			last ACTION_CASES;
		};
	    
	    ($action eq 'revert') and do {
			# this is also fresh editing job
			$outputFilePath = undef; 
			$self->addgoodmessage("Reverting to original file $editFilePath");
			$self->{problemPath} = $editFilePath;
			$self->{inputFilePath}=$editFilePath;
			last ACTION_CASES;
		};
		
		($action eq 'refresh') and do {
			# grab the problemContents from the form in order to save it to the tmp file
			# store tmp file name in the $self->problemPath for use in body 

			$problemContents = $r->param('problemContents');	
			$outputFilePath = "$editFilePath.$TEMPFILESUFFIX";
			$self->{problemPath} = $outputFilePath;
			last ACTION_CASES;
		};
	
		($action eq 'save') and do {
			# grab the problemContents from the form in order to save it to the permanent file
			# later we will unlink (delete) the temporary file
			# store permanent file name in the $self->problemPath for use in body 
			$problemContents = $r->param('problemContents');		
			$outputFilePath = "$editFilePath";	
			$self->{problemPath} = $outputFilePath;
			#$self->addgoodmessage("Saving to file $outputFilePath");
			last ACTION_CASES;
		};
		
		($action eq 'save_as') and do {
			my $new_file_name =$r->param('save_to_new_file') || '';
			#################################################
			#bail unless this new file name has been defined
			#################################################
			if ( $new_file_name !~ /\S/) { # need a non-blank file name
					# setting $self->{failure} stops saving and any redirects
					$do_not_save = 1;
					warn "new file name is $new_file_name";
					$self->addbadmessage(CGI::p("Please specify a file to save to."));
					last ACTION_CASES;  #stop processing
			}
			#################################################
			# grab the problemContents from the form in order to save it to a new permanent file
			# later we will unlink (delete) the current temporary file
			# store new permanent file name in the $self->problemPath for use in body 
			#################################################
			$problemContents = $r->param('problemContents');
			
			#################################################
			# Rescue the user in case they forgot to end the file name with .pg
			#################################################
			if($self->{file_type} eq 'problem' 
			  or $self->{file_type} eq 'blank_problem'
			  or $self->{file_type} eq 'set_header') {
					$new_file_name =~ s/\.pg$//; # remove it if it is there
					$new_file_name .= '.pg'; # put it there
					
			}	
		
			#################################################
			# check to prevent overwrites:
			#################################################			
			$outputFilePath = $ce->{courseDirs}->{templates} . '/' . 
										 $new_file_name; 		

			if (defined $outputFilePath and -e $outputFilePath) {
				# setting $do_not_save stops saving and any redirects
				$do_not_save = 1;
				$self->addbadmessage(CGI::p("File $outputFilePath exists.  File not saved."));
			} else {
				#$self->addgoodmessage("Saving to file $outputFilePath.");
			}
			$self->{problemPath} = $outputFilePath;
			last ACTION_CASES;
		};
		($action eq 'make_local_copy') and do {
			my $new_file_name =$r->param('local_copy_file_path') || '';
			#################################################
			#bail unless this new file name has been defined
			#################################################
			if ( $new_file_name !~ /\S/) { # need a non-blank file name
					# setting $self->{failure} stops saving and any redirects
					$do_not_save = 1;
					warn "new file name is $new_file_name";
					$self->addbadmessage(CGI::p("Please specify a file to save to."));
					last ACTION_CASES;  #stop processing
			}
			#################################################
			# grab the problemContents from the form in order to save it to a new permanent file
			# later we will unlink (delete) the current temporary file
			# store new permanent file name in the $self->problemPath for use in body 
			#################################################
			$problemContents = $r->param('problemContents');
			
			#################################################
			# Rescue the user in case they forgot to end the file name with .pg
			#################################################
			if($self->{file_type} eq 'problem' 
			  or $self->{file_type} eq 'blank_problem'
			  or $self->{file_type} eq 'set_header') {
					$new_file_name =~ s/\.pg$//; # remove it if it is there
					$new_file_name .= '.pg'; # put it there
					
			}	
		
			#################################################
			# check to prevent overwrites:
			#################################################			
			$outputFilePath = $ce->{courseDirs}->{templates} . '/' . 
										 $new_file_name; 		

			if (defined $outputFilePath and -e $outputFilePath) {
				# setting $do_not_save stops saving and any redirects
				$do_not_save = 1;
				$self->addbadmessage(CGI::p("There is already a file at [TMPL]/$new_file_name.  File not saved."));
			} else {
				$self->addgoodmessage("A local copy of $editFilePath is being made...") ;
			}
			$self->{problemPath} = $outputFilePath;
			#################################################
			# if new file has been successfully saved change the file path name for the problem
			#################################################	
			unless ($do_not_save) {
				my $problemRecord = $db->getGlobalProblem($setName,$problemNumber);
				$problemRecord->source_file($new_file_name);
				if  ( $db->putGlobalProblem($problemRecord)  ) {
					$self->addgoodmessage("A local, editable, copy of $new_file_name has been made for problem $problemNumber.") ;
					$self->{problemPath} = $outputFilePath;   # define the file path for redirect
				} else {
					$self->addbadmessage("Unable to change the source file path for set $setName, problem $problemNumber. Unknown error.");
				}
			}
			
			
			
			last ACTION_CASES;
		};
		($action eq 'add_problem_to_set') and do {
				my $sourceFile = $editFilePath;
				my $targetSetName  = $r->param('target_set');
				my $freeProblemID  = WeBWorK::Utils::max($db->listGlobalProblems($targetSetName)) + 1;	
				$sourceFile    =~ s|^$ce->{courseDirs}->{templates}/||;
				my $problemRecord  = $self->addProblemToSet(
									   setName        => $targetSetName,
									   sourceFile     => $sourceFile, 
									   problemID      => $freeProblemID
				);
				$self->assignProblemToAllSetUsers($problemRecord);
				$self->addgoodmessage("Added $sourceFile to ". $targetSetName. " as problem $freeProblemID") ;
				$outputFilePath = undef;	 # don't save any files
				$self->{problemPath} = $editFilePath;
			
		};
		($action eq 'add_set_header_to_set') and do {
				my $sourceFile = $editFilePath;
				my $targetSetName  = $r->param('target_set');	
				$sourceFile    =~ s|^$ce->{courseDirs}->{templates}/||;
				my $setRecord  = $db->getGlobalSet($targetSetName);
				$setRecord->set_header($sourceFile);
				if(  $db->putGlobalSet($setRecord) ) {
					$self->addgoodmessage("Added $sourceFile to ". $targetSetName. " as new set header ") ;
				} else {
					$do_not_save = 1 ;
					$self->addbadmessage("Unable to make $sourceFile the set header for $targetSetName");
				}
				# change file type to set_header if it not already so
				$self->{file_type} = 'set_header';
				$outputFilePath = undef;	 # don't save any files
				$self->{problemPath} = $editFilePath;
			
		};
			last ACTION_CASES;

		die "Unrecognized action command: $action";
	}; # end ACTION_CASES

	

	##############################################################################
	# write changes to the approriate files
	# FIXME  make sure that the permissions are set correctly!!!
	# Make sure that the warning is being transmitted properly.
	##############################################################################

	my $writeFileErrors;
	if ( defined($outputFilePath) and $outputFilePath =~/\S/ and ! $do_not_save ) {   # save file
	    # Handle the problem of line endings.  
		# Make sure that all of the line endings are of unix type.  
		# Convert \r\n to \n
		$problemContents =~ s/\r\n/\n/g;
		$problemContents =~ s/\r/\n/g;

		# make sure any missing directories are created
		$outputFilePath = WeBWorK::Utils::surePathToFile($ce->{courseDirs}->{templates},
		                                                        $outputFilePath);

		eval {
			local *OUTPUTFILE;
			open OUTPUTFILE, ">", $outputFilePath
					or die "Failed to open $outputFilePath";
			print OUTPUTFILE $problemContents;
			close OUTPUTFILE;
		};  # any errors are caught in the next block
		
		$writeFileErrors = $@ if $@;
	} 

	###########################################################
	# Catch errors in saving files,  clean up temp files
	###########################################################
	
	$self->{failure} = $do_not_save;    # don't do redirects if the file was not saved.
	                                    # don't unlink files or send success messages

	if ($writeFileErrors) {
	    # get the current directory from the outputFilePath
		$outputFilePath =~ m|^(/.*?/)[^/]+$|;
		my $currentDirectory = $1;
	
		my $errorMessage;
		# check why we failed to give better error messages
		if ( not -w $ce->{courseDirs}->{templates} ) {
			$errorMessage = "Write permissions have not been enabled in the templates directory.  No changes can be made.";
		} elsif ( not -w $currentDirectory ) {
			$errorMessage = "Write permissions have not been enabled in $currentDirectory.  Changes must be saved to a different directory for viewing.";
		} elsif ( -e $outputFilePath and not -w $outputFilePath ) {
			$errorMessage = "Write permissions have not been enabled for $outputFilePath.  Changes must be saved to another file for viewing.";
		} else {
			$errorMessage = "Unable to write to $outputFilePath: $writeFileErrors";
		}

		$self->{failure} = 1;
		$self->addbadmessage(CGI::p($errorMessage));
		
	} 
	unless( $writeFileErrors or $do_not_save) {  # everything worked!  unlink and announce success!
		# unlink the temporary file if there are no errors and the save button has been pushed
		if ($action eq 'save' or $action eq 'save_as' or $action eq 'revert') {
		             unlink($self->{tempFilePath}) ;
		}
		if ( defined($outputFilePath) and ! $self->{failure} )  {
			my $msg = "Saved to file: $outputFilePath";
			$self->addgoodmessage($msg);
		}

	}
		
	# return values for use in the body subroutine
	#  The path to the current permanent file being edited:
	#           $self->{problemPath} = $editFilePath;
	#  The path to the current temporary file (if any). If no temporary file this the same
	#  as the permanent file path:
	#		    $self->{outputFilePath} = $outputFilePath;	
	#		
	
	$self->{r_problemContents}        =   \$problemContents;
}  # end saveFileChanges

1;
