################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/PGProblemEditor.pm,v 1.99 2010/05/18 18:39:40 apizer Exp $
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

package WeBWorK::ContentGenerator::Instructor::PGProblemEditor2;
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator::Instructor);
use base qw(WeBWorK::ContentGenerator::renderViaXMLRPC);

use constant DEFAULT_SEED => 123456;  

=head1 NAME

WeBWorK::ContentGenerator::Instructor::PGProblemEditor2 - Edit a pg file#

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Utils qw(readFile surePathToFile path_is_subdir jitar_id_to_seq seq_to_jitar_id);
use HTML::Entities;
use URI::Escape;
use WeBWorK::Utils qw(has_aux_files not_blank);
use File::Copy;
use WeBWorK::Utils::Tasks qw(fake_user fake_set renderProblems);
use Data::Dumper;
use Fcntl;



###########################################################
# This editor will edit problem files or set header files or files, such as course_info
# whose name is defined in the defaults.config file
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
#  file_type  eq 'source_path_for_problem_file'
#                 This is the same as the 'problem' file type except that the source for the problem is found in
#                 the parameter $r->param('sourceFilePath').  This path is relative to the templates directory
#
#  file_type  eq 'set_header'
#                 This is a special case of editing the problem.  The set header is often listed as problem 0 in the set's list of problems.
#
#  file_type  eq 'hardcopy_header'
#                  This is a special case of editing the problem.  The hardcopy_header is often listed as problem 0 in the set's list of problems.
#                  But it is used instead of set_header when producing a hardcopy of the problem set in the TeX format, instead of producing HTML
#                  formatted version for use on the computer screen.
#
#  file_type eq 'course_info'
#                 This allows editing of the course_info.txt file which gives general information about the course.  It is called from the
#                 ProblemSets.pm module.
#
#  file_type eq 'options_info'
#                 This allows editing of the options_info.txt file which gives general information about the course.  It is called from the
#                 Options.pm module.
#
#  file_type  eq 'blank_problem'
#                 This is a special call which allows one to create and edit a new PG problem.  The "stationery" source for this problem is
#                 stored in the conf/snippets directory and defined in defaults.config by $webworkFiles{screenSnippets}{blankProblem}
#############################################################
# Requested actions  -- these and the file_type determine the state of the module
#      Save                       ---- action = save
#      Save as                    ---- action = save_as
#      View Problem               ---- action = view
#      Add this problem to:       ---- action = add_problem 
#      Make this set header for:  ---- action = add_problem
#      Revert                     ---- action = revert
#      no submit button defined   ---- action = fresh_edit
###################################################
# 
# Determining which is the correct path to the file is a mess!!! FIXME
# The path to the file to be edited is eventually put in tempFilePath
#
#  (tempFilePath)(editFilePath)(forcedSourceFile)
#input parameter is:  sourceFilePath
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

use constant ACTION_FORMS => [qw(view  save save_as add_problem revert)]; 
use constant ACTION_FORM_TITLES => {   # for use with tabber it is important that the titles have no spaces
view        => "View",
add_problem => "Append",
save        => "Update",
save_as     => "NewVersion",
revert      => "Revert",
};
#[qw(view save save_as revert add_problem add_header make_local_copy)];

# permissions needed to perform a given action
use constant FORM_PERMS => {
		view => "modify_student_data",
		add_problem => "modify_student_data",
		make_local_copy => "modify_student_data",
		save => "modify_student_data",
		save_as => "modify_student_data",
#		rename  => "modify_student_data",
		revert => "modify_student_data",
};

our $BLANKPROBLEM = 'blankProblem.pg';
# use constant BLANKPROBLEM => 'blankProblem.pg';  # doesn't work because this constant needs to be used inside a match.
sub pre_header_initialize {
	my ($self)         = @_;
	my $r              = $self->r;
	my $ce             = $r->ce;
	my $urlpath        = $r->urlpath;
	my $authz          = $r->authz;
	my $user           = $r->param('user');
	$self->{courseID}   = $urlpath->arg("courseID");
	$self->{setID}      = $r->urlpath->arg("setID") ;  # using $r->urlpath->arg("setID")  ||'' causes trouble with set 0!!!
	$self->{problemID}  = $r->urlpath->arg("problemID");

	# parse setID, which may come in with version data
	
	my $fullSetID = $self->{setID};
	if (defined($fullSetID) ) {
		
		if ( $fullSetID =~ /,v(\d+)$/ ) {
			$self->{versionID} = $1;
			$self->{setID} =~ s/,v\d+$//;
		}
		$self->{fullSetID} = $fullSetID;
	}
	my $submit_button   = $r->param('submit');  # obtain submit command from form
	my $actionID        = $r->param('action');
	my $file_type       = $r->param("file_type") || '';
	my $setName         = $self->{setID};
	my $versionedSetName = $self->{fullSetID};
	my $problemNumber   = $self->{problemID};

	# Check permissions
	return unless ($authz->hasPermissions($user, "access_instructor_tools"));
	return unless ($authz->hasPermissions($user, "modify_problem_sets"));

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
	$self->{problemSeed} = DEFAULT_SEED() unless not_blank($self->{problemSeed});
	
	##############################################################################
    #############################################################################
	# Save file to permanent or temporary file, then redirect for viewing
	#############################################################################
	#
	#  Any file "saved as" should be assigned to "Undefined_Set" and redirectoed to be viewed again in the editor
	#
	#  Problems "saved" or 'refreshed' are to be redirected to the Problem.pm module
	#  Set headers which are "saved" are to be redirected to the ProblemSet.pm page
	#  Hardcopy headers which are "saved" are also to be redirected to the ProblemSet.pm page
	#  Course_info files are redirected to the ProblemSets.pm page
	#  Options_info files are redirected to the Options.pm page
	##############################################################################
	


	######################################
    # Insure that file_type is defined
	######################################
	# We have already read in the file_type parameter from the form
	#
	# If this has not been defined we are  dealing with a set header
	# or regular problem
	if ( not_blank($file_type) ) { #file_type is defined and is not blank
		# file type is already defined -- do nothing
		#warn "file type already defined as $file_type"  #FIXME debug
	} else {
	    # if "sourceFilePath" is defined in the form, then we are getting the path directly.
		# if the problem number is defined and is 0
		# then we are dealing with some kind of 
		# header file.  The default is 'set_header' which prints properly
		# to the screen.
		# If the problem number is not zero, we are dealing with a real problem
		######################################
		if ( not_blank($r->param('sourceFilePath') )  ) {
			$file_type ='source_path_for_problem_file';
			$file_type = 'set_header' if $r->param('sourceFilePath') =~ m!/headers/|Header\.pg$!; #FIXME this need to be cleaned up
		} elsif ( defined($problemNumber) ) {
			 if ( $problemNumber =~/^\d+$/ and $problemNumber == 0 ) {  # if problem number is numeric and zero
                $file_type = 'set_header' unless  $file_type eq 'set_header' 
                                               or $file_type eq 'hardcopy_header';                                    
             } else {
             	$file_type = 'problem';    
             	#warn "setting file type to 'problem'\n";  #FIXME debug
             }
			           
		}
	}
	die "The file_type variable |$file_type| has not been defined or is blank." unless not_blank($file_type);
	# clean up sourceFilePath, just in case
	# double check that sourceFilePath is relative to the templates file
	if ($file_type eq 'source_path_for_problem_file' ) {	
		my $templatesDirectory = $ce->{courseDirs}->{templates};
		my $sourceFilePath = $r->param('sourceFilePath');
		$sourceFilePath =~ s/$templatesDirectory//;
		$sourceFilePath =~ s|^/||;  # remove intial /
		$self->{sourceFilePath} = $sourceFilePath;	
	}
	$self->{file_type} = $file_type;
	# $self->addgoodmessage("file type is $file_type");  #FIXME debug
	# warn "file type is $file_type\n parameter is ".$self->r->param("file_type");
	##########################################
	# File type is one of:     blank_problem course_info options_info problem set_header hardcopy_header source_path_for_problem_file  
    ##########################################
    #
    # Determine the path to the file
    #
    ###########################################
    	$self->getFilePaths($versionedSetName, $problemNumber, $file_type);
    	#defines $self->{editFilePath}   # path to the permanent file to be edited
    	#        $self->{tempFilePath}   # path to the permanent file to be edited  has .tmp suffix
    	#        $self->{inputFilePath}  # path to the file for input, (might be a .tmp file)
    	
    	
    	
    ##########################################
    # Default problem contents
    ##########################################
    $self->{r_problemContents}= undef;
    
    ##########################################
    #
    # Determine action
    #
    ###########################################

 	if ($actionID) {
 		unless (grep { $_ eq $actionID } @{ ACTION_FORMS() } ) {
 			die "Action $actionID not found";
 		}
 		# Check permissions
 		if (not FORM_PERMS()->{$actionID} or $authz->hasPermissions($user, FORM_PERMS()->{$actionID})) {
 			my $actionHandler = "${actionID}_handler";
 			my %genericParams =();
# 			foreach my $param (qw(selected_users)) {
# 				$genericParams{$param} = [ $r->param($param) ];
#			}
 			my %actionParams = $self->getActionParams($actionID);
 			my %tableParams = (); # $self->getTableParams();
 			$self->{action}= $actionID;
 			$self->$actionHandler(\%genericParams, \%actionParams, \%tableParams);
 		} else {
 			$self->addbadmessage( "You are not authorized to perform this action.");
 		}
 	} else {
 		$self->{action}='fresh_edit';
 		my $actionHandler = "fresh_edit_handler";
 		my %genericParams;
 		my %actionParams = (); #$self->getActionParams($actionID);
 		my %tableParams = (); # $self->getTableParams();
		my $problemContents = '';
		$self->{r_problemContents}=\$problemContents;
 		$self->$actionHandler(\%genericParams, \%actionParams, \%tableParams);
 	}
 
	
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
	$self->{problemSeed} = DEFAULT_SEED() unless not_blank( $self->{problemSeed});
	
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
    return ;

}


sub initialize  {
	my ($self) = @_;
	my $r = $self->r;
	my $authz = $r->authz;
	my $user = $r->param('user');
	
	# Check permissions
	return unless ($authz->hasPermissions($user, "access_instructor_tools"));
	return unless ($authz->hasPermissions($user, "modify_problem_sets"));
	
	my $file_type       = $r->param('file_type') || "";
	my $tempFilePath    = $self->{tempFilePath}; # path to the file currently being worked with (might be a .tmp file)
	my $inputFilePath   = $self->{inputFilePath};   # path to the file for input, (might be a .tmp file)
	
	$self->addmessage($r->param('status_message') ||'');  # record status messages carried over if this is a redirect
	$self->addbadmessage("Changes in this file have not yet been permanently saved.") if -r $tempFilePath;
	if ( not( -e $inputFilePath) ) {
		$self->addbadmessage("The file '".$self->shortPath($inputFilePath)."' cannot be found.");
	} elsif ((not -w $inputFilePath) && $file_type ne 'blank_problem' ) {

		$self->addbadmessage("The file '".$self->shortPath($inputFilePath)."' is protected! ".CGI::br().
		"To edit this text you must first make a copy of this file using the 'NewVersion' action below.");

	}
    if ($inputFilePath =~/$BLANKPROBLEM$/ && $file_type ne 'blank_problem') {
#    	$self->addbadmessage("This file '$inputFilePath' is a blank problem! ".CGI::br()."To edit this text you must  
    	$self->addbadmessage("The file '".$self->shortPath($inputFilePath)."' is a blank problem! ".CGI::br()."To edit this text you must  
                           use the 'NewVersion' action below to save it to another file.");
    }
	
}

sub path {
	my ($self, $args) = @_;
	my $r = $self->r;
	my $urlpath       = $r->urlpath;
	my $courseName    = $urlpath->arg("courseID");
	my $setName       = $urlpath->arg("setID") || '';
	my $problemNumber = $urlpath->arg("problemID") || '';

	if ($setName) {
	    my $set = $r->db->getGlobalSet($setName);
	    if ($set && $set->assignment_type eq 'jitar' && $problemNumber) {
		$problemNumber = join('.',jitar_id_to_seq($problemNumber));
	    }
	}

	# we need to build a path to the problem being edited by hand, since it is not the same as the urlpath
	# For this page the bread crum path leads back to the problem being edited, not to the Instructor tool.
	my @path = ( 'WeBWorK', $r->location,
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
	my $courseName    = $r->urlpath->arg("courseID");
	my $setID         = $r->urlpath->arg("setID");
	my $problemNumber = $r->urlpath->arg("problemID");
	my $file_type = $self->{'file_type'} || '';

	return "Set Header for  set $setID" if ($file_type eq 'set_header');
	return "Hardcopy Header for set $setID" if ($file_type eq 'hardcopy_header');
	return "Course Information for course $courseName" if ($file_type eq 'course_info');
	return "Options Information" if ($file_type eq 'options_info');

	if ($setID) {
	    my $set = $r->db->getGlobalSet($setID);
	    if ($set && $set->assignment_type eq 'jitar') {
		$problemNumber = join('.',jitar_id_to_seq($problemNumber));
	    }
	}

	return 'Problem ' . $problemNumber;
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
	my $setName         = $self->{setID} ;
	my $problemNumber   = $self->{problemID} ;
    $setName            = defined($setName) ? $setName : '';  # we need this instead of using the || construction 
                                                              # to keep set 0 from being set to the 
                                                              # empty string.
	my $fullSetName = defined( $self->{fullSetID} ) ? $self->{fullSetID} : $setName;
	$problemNumber      = defined($problemNumber) ? $problemNumber : '';
    
    
    
	#########################################################################    
    # Construct url for reporting bugs:
	#########################################################################

	my $libraryName = '';
	if ($editFilePath =~ m|([^/]*)Library|)   {  #find the path to the file
		# find the library, if any exists in the path name (first library is picked)
		my $tempLibraryName = $1;
		$libraryName = ( not_blank($tempLibraryName) ) ? 
		                $tempLibraryName : "Library"; 
		# things that start /Library/setFoo/probBar  are labeled as component "Library"
		# which refers to the SQL based problem library. (is nationalLibrary a better name?)
	} else {
		$libraryName = 'Library';  # make sure there is some default component defined.
	}

    my $BUGZILLA = "$ce->{webworkURLs}{bugReporter}?product=Problem%20libraries".
                   "&component=$libraryName&bug_file_loc=${editFilePath}_with_problemSeed=".$self->{problemSeed};
	#FIXME  # The construction of this URL is somewhat fragile.  A separate module could be devoted to 
	# intelligent bug reporting.
	
	#########################################################################    
    # Construct reference row for PGproblemEditor2.
	#########################################################################
	
       my @PG_Editor_Reference_Links = (
   		{label 		=>	'Problem Techniques'	,
   		 url 		=>  'http://webwork.maa.org/wiki/Category:Problem_Techniques' 	,
   		 target     =>	'techniques_window'	,
   		 tooltip 	=>	'Snippets of PG code illustrating specific techniques'	,
   		},
   		{label 		=>	'Math Objects'	,
   		 url 		=>   'http://webwork.maa.org/wiki/Category:MathObjects'  	,
   		 target		=>	'math_objects'	,
   		 tooltip 	=>	'Wiki summary page for MathObjects'	,
   		},   		
   		{label 		=>	'POD'	,
   		 url 		=>  'http://webwork.maa.org/pod/pg_TRUNK/'  	,
   		 target		=>	'pod_docs'	,
   		 tooltip 	=>	'Documentation from source code for PG modules and macro files. Often the most up-to-date information.'	,
   		},
   		{label 		=>	'PGLab'	,
   		 url 		=>  'http://hosted2.webwork.rochester.edu/webwork2/wikiExamples/MathObjectsLabs2/2/?login_practice_user=true'  	,
   		 target		=>	'PGLab'	,
   		 tooltip 	=>	'Test snippets of PG code in interactive lab.  Good way to learn PG language.'	,
   		},
   		{label 		=>	'PGML'	,
   		 url 		=>  'https://courses.webwork.maa.org/webwork2/cervone_course/PGML/1/?login_practice_user=true',
   		 target		=>	'PGML'	,
   		 tooltip 	=>	'PG mark down syntax used to format WeBWorK questions. This interactive lab can help you to learn the techniques.'	,
   		},
   		{label 		=>	'Author Info'	,
   		 url 		=>  'http://webwork.maa.org/wiki/Category:Authors'  	,
   		 target		=>	'author_info'	,
   		 tooltip 	=>	'Top level of author information on the wiki.'	,
   		},
   		{label 		=>	'report bugs in this problem'	,
   		 url 		=>  $BUGZILLA  	,
   		 target		=>	'bug_report'	,
   		 tooltip 	=>	'Report bugs in a WeBWorK question/problem using this link. <br/> The very first time you do this you will need to register with an email address so that information on the bug fix can be reported back to you.'	,
   		},
   
   
   
   );
   my $PG_Editor_Reference_String = '';
   foreach my $link (@PG_Editor_Reference_Links) {
   		$PG_Editor_Reference_String .= ' | '. 
   	       CGI::a({-href=>$link->{url} ,-target=> $link->{target},
   	       -onmouseover=>q!Tip('! .  $link->{tooltip} . 
   	       				    q!',SHADOW, true, 
		                    DELAY, 100, FADEIN, 300, FADEOUT, 300, STICKY, 0, OFFSETX, -20,  CLICKCLOSE, true, 
		                    BGCOLOR, '#F4FF91', TITLE, 'Reference:',TITLEBGCOLOR, '#F4FF91', TITLEFONTCOLOR, '#000000')!
		        },
		'&nbsp;'.$link->{label}.'&nbsp;');   
   }
   $PG_Editor_Reference_String .=' | ';
	#########################################################################
	# Find the text for the problem, either in the tmp file, if it exists
	# or in the original file in the template directory
	# or in the problem contents gathered in the initialization phase.
	#########################################################################
	
	my $problemContents = ${$self->{r_problemContents}};

	unless ( $problemContents =~/\S/)   { # non-empty contents
		if (-r $tempFilePath and not -d $tempFilePath) {
			die "tempFilePath is unsafe!" unless path_is_subdir($tempFilePath, $ce->{courseDirs}->{templates}, 1); # 1==path can be relative to dir
			eval { $problemContents = WeBWorK::Utils::readFile($tempFilePath) };
			$problemContents = $@ if $@;
			$inputFilePath = $tempFilePath;
		} elsif  (-r $editFilePath and not -d $editFilePath) {
			die "editFilePath is unsafe!" unless path_is_subdir($editFilePath, $ce->{courseDirs}->{templates}, 1)  # 1==path can be relative to dir
				|| $editFilePath eq $ce->{webworkFiles}{screenSnippets}{setHeader}
				|| $editFilePath eq $ce->{webworkFiles}{hardcopySnippets}{setHeader}
				|| $editFilePath eq $ce->{webworkFiles}{screenSnippets}{blankProblem};
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

	my $prettyProblemNumber = $problemNumber;
	my $set = $self->r->db->getGlobalSet($setName);
	$prettyProblemNumber = join('.',jitar_id_to_seq($problemNumber))
				    if ($set && $set->assignment_type eq 'jitar');

	my $file_type = $self->{file_type};
	my %titles = (
		problem         => CGI::b("set $fullSetName/problem $prettyProblemNumber"),
		blank_problem   => "blank problem",
		set_header      => "header file",
		hardcopy_header => "hardcopy header file",
		course_info     => "course information",
		options_info    => "options information",
		''              => 'Unknown file type',
		source_path_for_problem_file => " unassigned problem file:  ".CGI::b("set $setName/problem $prettyProblemNumber"),
	);
	my $header = CGI::i("Editing $titles{$file_type} in file '".$self->shortPath($inputFilePath)."'");
	$header = ($self->isTempEditFilePath($inputFilePath)  ) ? CGI::div({class=>'temporaryFile'},$header) : $header;  # use colors if temporary file
	
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
	
	my $force_field = (not_blank( $self->{sourceFilePath}) ) ? # path is  a non-blank string
		CGI::hidden(-name=>'sourceFilePath',
		            -default=>$self->{sourceFilePath}) : '';

	# FIXME this isn't used at all! --sam
	my @allSetNames = sort $db->listGlobalSets;
	for (my $j=0; $j<scalar(@allSetNames); $j++) {
		$allSetNames[$j] =~ s|^set||;
		$allSetNames[$j] =~ s|\.def||;
	}
	my $target = 'WW_View'; #"problem$edit_level"; # increasing edit_level gives you a new window with each edit.
	my $site_url = $ce->{webworkURLs}->{htdocs};
	print qq!<script type="text/javascript" src="$site_url/js/legacy/vendor/wz_tooltip.js"></script>!;
	print CGI::script(<<EOF);
	function setTarget(inWindow) {
	    document.getElementById("newWindow").checked = inWindow;
	    updateTarget();
	}
	function updateTarget() {
	    var inWindow = document.getElementById("newWindow").checked;
	    if (inWindow) {
		if (document.getElementById("save_as_form_id") && 
		    document.getElementById("save_as_form_id").checked) {
		    document.getElementById("editor").target = "WW_New_Edit";
		} else {
		    document.getElementById("editor").target = "WW_View";
		}
	    } else {
		document.getElementById("editor").target = "";
	    }
	}
	function setRadio(i,nw) {
	    setTarget(nw);
	}
EOF
	

   
	print CGI::p($header),

		CGI::start_form({method=>"POST", id=>"editor", name=>"editor", action=>"$uri", enctype=>"application/x-www-form-urlencoded"}),

		$self->hidden_authen_fields,
		$force_field,
		CGI::hidden(-name=>'file_type',-default=>$self->{file_type}),
		CGI::div({},$PG_Editor_Reference_String),
# 			CGI::a({-href=>'http://webwork.math.rochester.edu/docs/docs/pglanguage/manpages/',-target=>"manpage_window"},
# 				'&nbsp;Manpages&nbsp;',
# 			)," | ",
# 			CGI::a({-href=>'http://devel.webwork.rochester.edu/twiki/bin/view/Webwork/PGmacrosByFile',-target=>"manpage_window"},
# 				'&nbsp;macro list&nbsp;',
# 			)," | ",
# 			CGI::a({-href=>'http://webwork.maa.org/wiki/Category:Authors',-target=>"wiki_window"},
# 				'&nbsp;authoring&nbsp;info&nbsp;&amp; help&nbsp;',
# 			)," | ",
# 			CGI::a({-href=>'http://hosted2.webwork.rochester.edu/webwork2/wikiExamples/MathObjectsLabs2/2/?login_practice_user=true',-target=>"lab_window",
# 			     },
# 				'&nbsp;testing&nbsp;lab&nbsp;'
# 			)," | ",
# 			CGI::a({-href=>'http://devel.webwork.rochester.edu/doc/cvs/pg_HEAD/',-target=>"doc_window"},
# 				'&nbsp;pod docs&nbsp;',
# 			)," | ",
# 			CGI::a({-href=>$BUGZILLA,-target=>"bugs_window"},
# 				'&nbsp;report problem bugs&nbsp;',
# 			)," | ",
# 		),
		CGI::p(
			CGI::textarea(
				-name => 'problemContents', -default => $problemContents, -class => 'latexentryfield',
				-rows => $rows, -cols => $columns, -override => 1,
			),
		);


	
######### print action forms
		
			#print CGI::Tr({}, CGI::td({-colspan=>2}, "Select an action to perform:"));
			
			my @formsToShow = @{ ACTION_FORMS() };
			my %actionFormTitles = %{ACTION_FORM_TITLES()};
			my $default_choice = $formsToShow[0];
			my $i = 0;
			
###################################################################COLUMN STYLE BEGIN###############################################################
			
			# foreach my $actionID (@formsToShow) {
				# # Check permissions
				# #next if FORM_PERMS()->{$actionID} and not $authz->hasPermissions($user, FORM_PERMS()->{$actionID});
				# my $actionForm = "${actionID}_form";
				# my $newWindow = ($actionID =~ m/^(view|add_problem|save)$/)? 1: 0;
				# my $onChange = "setRadio($i,$newWindow)";
				# my %actionParams = $self->getActionParams($actionID);
				# my $line_contents = $self->$actionForm($onChange, %actionParams);
				# my $radio_params = {-type=>"radio", -name=>"action", -value=>$actionID};
				# $radio_params->{checked}=1 if ($actionID eq $default_choice) ;
				# $radio_params->{onclick} = "setTarget($newWindow)";
				# $radio_params->{id} = "action$i";
				# # print CGI::Tr({-valign=>"top"},
					# # CGI::td({}, CGI::input($radio_params)),
					# # CGI::td({}, $line_contents)
				# # ) if $line_contents;
				# if($line_contents){
					# print CGI::start_div({-class=>"column"});
					# print CGI::div({-class=>"pg_editor_input_span"},WeBWorK::CGI_labeled_input(-type=>"radio", -id=>$actionForm."_id", -label_text=>ucfirst(WeBWorK::underscore_to_whitespace($actionForm)), -input_attr=>$radio_params),CGI::br());
					# print CGI::div({-class=>"pg_editor_input_div"},$line_contents);
					# print CGI::br();
					# print CGI::end_div();
				# }
				# $i++;
			# }
			# my $checkbox = WeBWorK::CGI_labeled_input(-type=>"checkbox", -id=>"newWindow", -label_text=>"Open in new window", -input_attr=>{-checked=>"checked", -onchange=>"updateTarget()"});
			# $checkbox =~ s/\n//; # remove unwanted linebreak
			# print CGI::div({-class=>"pd_editor_input_div", -id=>"submit_input_div"}, $checkbox, CGI::br(), WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"submit_button_id", -input_attr=>{-name=>'submit', -value=>"Take Action!"}));
			
########################################################COLUMN STYLE END###########################################################################


########################################################TABBER STYLE BEGIN#########################################################################			
			
			my @divArr = ();
			
			foreach my $actionID (@formsToShow) {
				# Check permissions
				#next if FORM_PERMS()->{$actionID} and not $authz->hasPermissions($user, FORM_PERMS()->{$actionID});
				my $actionForm = "${actionID}_form";
				my $newWindow = ($actionID =~ m/^(view|add_problem|save)$/)? 1: 0;
				my $onChange = "setRadio($i,$newWindow)";
				my %actionParams = $self->getActionParams($actionID);
				my $line_contents = $self->$actionForm($onChange, %actionParams);
				my $radio_params = {-type=>"radio", -name=>"action", -value=>$actionID};
				$radio_params->{checked}=1 if ($actionID eq $default_choice) ;
				$radio_params->{onclick} = "setTarget($newWindow)";
				$radio_params->{id} = "action$i";
				# print CGI::Tr({-valign=>"top"},
					# CGI::td({}, CGI::input($radio_params)),
					# CGI::td({}, $line_contents)
				# ) if $line_contents;
				if($line_contents){
					my $title = $actionFormTitles{$actionID};
					push @divArr, join("",
					CGI::h3($title),
					CGI::div({-class=>"pg_editor_input_span"},WeBWorK::CGI_labeled_input(-type=>"radio", -id=>$actionForm."_id", -label_text=>ucfirst(WeBWorK::underscore_to_whitespace($actionForm)), -input_attr=>$radio_params),CGI::br()),
					CGI::div({-class=>"pg_editor_input_div"},$line_contents),
					CGI::br())
				}
				$i++;
			}
			
			my $divArrRef = \@divArr;
	
			print CGI::div({-class=>"tabber"},
				CGI::div({-class=>"tabbertab"},$divArrRef)
			);
			
###################################################TABBER STYLE END##############################################################################
			
			my $checkbox = WeBWorK::CGI_labeled_input(-type=>"checkbox", -id=>"newWindow", -label_text=>"Open in new window", -input_attr=>{-checked=>"checked", -onchange=>"updateTarget()"});
			$checkbox =~ s/\n//; # remove unwanted linebreak
			print CGI::div({-class=>"pd_editor_input_div", -id=>"submit_input_div"}, $checkbox, CGI::br(), WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"submit_button_id", -input_attr=>{-name=>'submit', -value=>"Take Action!"}));
	
	
	print  CGI::end_form();

	print CGI::script("updateTarget()");
	return "";


}

#
#  Convert long paths to [TMPL], etc.
#
sub shortPath {
  my $self = shift; my $file = shift;
  my $tmpl = $self->r->ce->{courseDirs}{templates};
  my $root = $self->r->ce->{courseDirs}{root};
  my $ww = $self->r->ce->{webworkDirs}{root};
  $file =~ s|^$tmpl|[TMPL]|; $file =~ s|^$root|[COURSE]|; $file =~ s|^$ww|[WW]|;
  return $file;
}

################################################################################
# Utilities
################################################################################

sub getRelativeSourceFilePath {
	my ($self, $sourceFilePath) = @_;
	
	my $templatesDir = $self->r->ce->{courseDirs}->{templates};
	$sourceFilePath =~ s|^$templatesDir/*||; # remove templates path and any slashes that follow
	
	return $sourceFilePath;
}

# determineLocalFilePath   constructs a local file path parallel to a library file path

# 
sub determineLocalFilePath {
	my $self= shift;				die "determineLocalFilePath is a method" unless ref($self);
	my $path = shift;
 	my $default_screen_header_path   = $self->r->ce->{webworkFiles}->{hardcopySnippets}->{setHeader}; 
 	my $default_hardcopy_header_path = $self->r->ce->{webworkFiles}->{screenSnippets}->{setHeader};
	my $setID = $self->{setID};
	$setID = int(rand(1000)) unless $setID =~/\S/;  # setID can be 0
	if ($path =~ /Library/) {
		#$path =~ s|^.*?Library/||;  # truncate the url up to a segment such as ...rochesterLibrary/.......
		$path  =~ s|^.*?Library/|local/|;  # truncate the url up to a segment such as ...rochesterLibrary/....... and prepend local
 	} elsif ($path eq $default_screen_header_path) {
 		$path = "set$setID/setHeader.pg";
 	} elsif ($path eq $default_hardcopy_header_path) {
 		$path = "set$setID/hardcopyHeader.tex";
	} else { # if its not in a library we'll just save it locally
		$path = "new_problem_".int(rand(1000)).".pg";	#l hope there aren't any collisions.
	}
    $path;

}

sub determineTempEditFilePath {  # this does not create the directories in the path to the file
                                 # it  returns an absolute path to the file
	my $self = shift;  die "determineTempEditFilePath is a method" unless ref($self);
	my $path =shift;    # this should be an absolute path to the file
	my $user = $self->r->param("user");
	$user    = int(rand(1000)) unless defined $user;
	my $setID = $self->{setID} || int(rand(1000));
	my $courseDirectory = $self->r->ce->{courseDirs};
	###############
	# Calculate the location of the temporary file
	###############
	my $templatesDirectory           = $courseDirectory->{templates};
	my $blank_file_path              = $self->r->ce->{webworkFiles}->{screenSnippets}->{blankProblem};
	my $default_screen_header_path   = $self->r->ce->{webworkFiles}->{hardcopySnippets}->{setHeader}; 
	my $default_hardcopy_header_path = $self->r->ce->{webworkFiles}->{screenSnippets}->{setHeader};
	my $tmpEditFileDirectory = $self->getTempEditFileDirectory();
	$self->addbadmessage("The path to the original file should be absolute") unless $path =~m|^/|;  # debug
	if ($path =~/^$tmpEditFileDirectory/) {
		$self->addbadmessage("Error: This path is already in the temporary edit directory -- no new temporary file is created. path = $path");
	
	} else {
		if ($path =~ /^$templatesDirectory/ ) {
			$path =~ s|^$templatesDirectory||;
			$path =~ s|^/||;   # remove the initial slash if any
			$path = "$tmpEditFileDirectory/$path.$user.tmp";
		} elsif ($path eq $blank_file_path) {
			$path = "$tmpEditFileDirectory/blank.$setID.$user.tmp";  # handle the case of the blank problem
		} elsif ($path eq $default_screen_header_path) {
			$path = "$tmpEditFileDirectory/screenHeader.$setID.$user.tmp";  # handle the case of the screen header in snippets 
		} elsif ($path eq $default_hardcopy_header_path) {
			$path = "$tmpEditFileDirectory/hardcopyHeader.$setID.$user.tmp";  # handle the case of the hardcopy header in snippets 
		} else {
			die "determineTempEditFilePath should only be used on paths within the templates directory, not on $path";
		}
	}
	$path;
}

sub determineOriginalEditFilePath {  # determine the original path to a file corresponding to a temporary edit file
                                     # returns path relative to the template directory
	my $self = shift;
	my $path = shift;
	my $user = $self->r->param("user");
	$self->addbadmessage("Can't determine user of temporary edit file $path.") unless defined($user);
	my $templatesDirectory = $self->r->ce->{courseDirs} ->{templates};
	my $tmpEditFileDirectory = $self->getTempEditFileDirectory();
	# unless path is absolute assume that it is relative to the template directory
	my $newpath = $path;
	unless ($path =~ m|^/| ) {
		$newpath = "$templatesDirectory/$path";
	}
	if ($self->isTempEditFilePath($newpath) ) {
		$newpath =~ s|^$tmpEditFileDirectory/||; # delete temp edit directory 
		if ($newpath =~m|blank\.[^/]*$|) {                     # handle the case of the blank problem 
			$newpath = $self->r->ce->{webworkFiles}->{screenSnippets}->{blankProblem};
		} elsif (($newpath =~m|hardcopyHeader\.[^/]*$|)) {     # handle the case of the hardcopy header in snippets 
			$newpath = $self->r->ce->{webworkFiles}->{hardcopySnippets}->{setHeader};
		} elsif (($newpath =~m|screenHeader\.[^/]*$|)) {       # handle the case of the screen header in snippets
			$newpath = $self->r->ce->{webworkFiles}->{screenSnippets}->{setHeader};
		} else {
			$newpath =~ s|\.$user\.tmp$||;           # delete suffix
			
		}
		#$self->addgoodmessage("Original file path is $newpath"); #FIXME debug
	} else {
		$self->addbadmessage("This path |$newpath| is not the path to a temporary edit file.");
		# returns original path
	}
	$newpath;
}
	
sub getTempEditFileDirectory {
	my $self = shift;
	my $courseDirectory       = $self->r->ce->{courseDirs};
	my $templatesDirectory    = $courseDirectory->{templates};
	my $tmpEditFileDirectory  = (defined ($courseDirectory->{tmpEditFileDir}) ) ? $courseDirectory->{tmpEditFileDir} : "$templatesDirectory/tmpEdit";
	$tmpEditFileDirectory;
}
sub isTempEditFilePath  {
	my $self = shift;
	my $path = shift;
	my $templatesDirectory = $self->r->ce->{courseDirs} ->{templates};
	# unless path is absolute assume that it is relative to the template directory
	unless ($path =~ m|^/| ) {
		$path = "$templatesDirectory/$path";
	}
	my $tmpEditFileDirectory = $self->getTempEditFileDirectory();

	($path =~/^$tmpEditFileDirectory/) ? 1: 0;
}
sub getFilePaths {
	my ($self, $setName, $problemNumber, $file_type) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	my $courseName = $urlpath->arg("courseID");
	my $user = $r->param('user');
	my $effectiveUserName = $r->param('effectiveUser');
    
	$setName = '' unless defined $setName;
	$problemNumber = '' unless defined $problemNumber;

	# parse possibly versioned set names
	my $fullSetName = $setName;
	my $editSetVersion = 0;
	if ( $setName =~ /,v(\d)+$/ ) {
		$editSetVersion = $1;
		$setName =~ s/,v\d+$//;
	}

	die 'Internal error to PGProblemEditor2 -- file type is not defined'  unless defined $file_type;
	#$self->addgoodmessage("file type is $file_type");  #FIXME remove
	##########################################################
	# Determine path to the input file to be edited. 
	#   The permanent path of the input file  == $editFilePath 
	#   A temporary path to the input file    == $tempFilePath
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
	#		path to regular file -- $editFilePath;
	#	    path to file being read (temporary or permanent) 	
	#       contents of the file being read  --- $problemContents  	
	#       $self->{r_problemContents}        =   \$problemContents;
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
		
		($file_type eq 'options_info') and do {
			# we are editing the options_info file
			# value of courseFiles::options_info is relative to templates directory
			$editFilePath           .= '/' . $ce->{courseFiles}->{options_info};
			last CASE;
		};
		
		($file_type eq 'blank_problem') and do {
			$editFilePath = $ce->{webworkFiles}->{screenSnippets}->{blankProblem};
			$self->addbadmessage("This is a blank problem template file and can not be edited directly. "
			                     ."Use the 'NewVersion' action below to create a local copy of the file and add it to the current problem set."
			);
			last CASE;
		};
		
		($file_type eq 'set_header' or $file_type eq 'hardcopy_header') and do {
			# first try getting the merged set for the effective user
			# FIXME merged set is overwritten immediately with global value... WTF? --sam
			my $set_record = $db->getMergedSet($effectiveUserName, $setName); # checked
			# if that doesn't work (the set is not yet assigned), get the global record
			$set_record = $db->getGlobalSet($setName); # checked
			# bail if no set is found
			die "Cannot find a set record for set $setName" unless defined($set_record);
 				
			my $header_file = "";
			$header_file = $set_record->{$file_type};
			if ($header_file && $header_file ne "" && $header_file ne "defaultHeader") {
					if ( $header_file =~ m|^/| ) { # if absolute address
						$editFilePath  = $header_file;
					} else {
						$editFilePath .= '/' . $header_file;
					}
			} else {
					# if the set record doesn't specify the filename for a header
					# then the set uses the default from snippets
		
						$editFilePath = $ce->{webworkFiles}->{screenSnippets}->{setHeader} if $file_type eq 'set_header';
						$editFilePath = $ce->{webworkFiles}->{hardcopySnippets}->{setHeader} if $file_type eq 'hardcopy_header';

#						$self->addbadmessage("'".$self->shortPath($editFilePath)."' is the default header file and cannot be edited directly.".CGI::br()."Any changes you make will have to be saved as another file.");
					#}

			}
			last CASE;
		}; #end 'set_header, hardcopy_header' case
		
		($file_type eq 'problem') and do {			
		
			# first try getting the merged problem for the effective user
			my $problem_record;
			if ( $editSetVersion ) {
				$problem_record = $db->getMergedProblemVersion($effectiveUserName, $setName, $editSetVersion, $problemNumber); # checked
			} else {
				$problem_record = $db->getMergedProblem($effectiveUserName, $setName, $problemNumber); # checked
			}
			
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
		  my $forcedSourceFile = $self->{sourceFilePath};
		  # if the source file is in the temporary edit directory find the original source file
		  # the source file is relative to the templates directory.
		  if ($self->isTempEditFilePath($forcedSourceFile) ) {
		      $forcedSourceFile   = $self->determineOriginalEditFilePath($forcedSourceFile);     # original file path
		      $self->addgoodmessage("the original path to the file is $forcedSourceFile");  #FIXME debug
		  }
		  # bail if no source path for the problem is found ;
		  die "Cannot find a file path to save to" unless( not_blank($forcedSourceFile)   );
		  $self->{problemSeed} = DEFAULT_SEED();
		  $editFilePath .= '/' . $forcedSourceFile;
		  last CASE;
		}; # end 'source_path_for_problem_file' case
	}  # end CASE: statement

	
	# if a set record or problem record contains an empty blank for a header or problem source_file
	# we could find ourselves trying to edit /blah/templates/.toenail.tmp or something similar
	# which is almost undoubtedly NOT desirable

	if (-d $editFilePath) {
		my $msg = "The file '".$self->shortPath($editFilePath)."' is a directory!";
		$self->{failure} = 1;
		$self->addbadmessage($msg);
	}
	if (-e $editFilePath and not -r $editFilePath) {   #it's ok if the file doesn't exist, perhaps we're going to create it
	                                                  # with save as
		my $msg = "The file '".$self->shortPath($editFilePath)."' cannot be read!";
		$self->{failure} = 1;
		$self->addbadmessage($msg);	
	}
    #################################################
	# The path to the permanent file is now verified and stored in $editFilePath
	# Whew!!!
	#################################################
	
	my $tempFilePath = $self->determineTempEditFilePath($editFilePath);  #"$editFilePath.$TEMPFILESUFFIX";
	$self->{editFilePath}   = $editFilePath;
	$self->{tempFilePath}   = $tempFilePath;
	$self->{inputFilePath}  = (-r $tempFilePath) ? $tempFilePath : $editFilePath;
	#warn "editfile path is $editFilePath and tempFile is $tempFilePath and inputFilePath is ". $self->{inputFilePath};
}
sub saveFileChanges {

################################################################################
# saveFileChanges does most of the work. it is a separate method so that it can
# be called from either pre_header_initialize() or initilize(), depending on
# whether a redirect is needed or not.
# 
# it actually does a lot more than save changes to the file being edited, and
# sometimes less.
################################################################################

	my ($self, $outputFilePath, $problemContents ) = @_;
 	my $r             = $self->r;
 	my $ce            = $r->ce;

	my $action          = $self->{action}||'no action';
	# my $editFilePath  = $self->{editFilePath}; # not used??
	my $sourceFilePath  = $self->{sourceFilePath};
	my $tempFilePath    = $self->{tempFilePath}; 	
	
	if (defined($problemContents) and ref($problemContents) ) {
		$problemContents = ${$problemContents};
	} elsif( ! not_blank($problemContents)  ) {      # if the problemContents is undefined or empty
		$problemContents = ${$self->{r_problemContents}};
	}
	##############################################################################
	# read and update the targetFile and targetFile.tmp files in the directory
	# if a .tmp file already exists use that, unless the revert button has been pressed.
	# The .tmp files are removed when the file is or when the revert occurs.
	##############################################################################
	

    unless (not_blank($outputFilePath) ) {
    	$self->addbadmessage("You must specify an file name in order to save a new file.");
    	return "";
    }
	my $do_not_save    = 0 ;       # flag to prevent saving of file
	my $editErrors = '';	

	##############################################################################
	# write changes to the approriate files
	# FIXME  make sure that the permissions are set correctly!!!
	# Make sure that the warning is being transmitted properly.
	##############################################################################
   
	my $writeFileErrors;
	if ( not_blank($outputFilePath)  ) {   # save file
	    # Handle the problem of line endings.  
		# Make sure that all of the line endings are of unix type.  
		# Convert \r\n to \n
		#$problemContents =~ s/\r\n/\n/g;
		#$problemContents =~ s/\r/\n/g;

		# make sure any missing directories are created
		WeBWorK::Utils::surePathToFile($ce->{courseDirs}->{templates},
		                                                        $outputFilePath);
		die "outputFilePath is unsafe!" unless path_is_subdir($outputFilePath, $ce->{courseDirs}->{templates}, 1); # 1==path can be relative to dir

		eval {
			local *OUTPUTFILE;
			open OUTPUTFILE,  ">$outputFilePath"
					or die "Failed to open $outputFilePath";
			print OUTPUTFILE $problemContents;
			close OUTPUTFILE;		
		  # any errors are caught in the next block
		};

		$writeFileErrors = $@ if $@;
	} 
 
	###########################################################
	# Catch errors in saving files,  clean up temp files
	###########################################################
	
	$self->{saveError} = $do_not_save;    # don't do redirects if the file was not saved.
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
			$errorMessage = "Write permissions have not been enabled in '".$self->shortPath($currentDirectory)."'.  Changes must be saved to a different directory for viewing.";
		} elsif ( -e $outputFilePath and not -w $outputFilePath ) {
			$errorMessage = "Write permissions have not been enabled for '".$self->shortPath($outputFilePath)."'.  Changes must be saved to another file for viewing.";
		} else {
			$errorMessage = "Unable to write to '".$self->shortPath($outputFilePath)."': $writeFileErrors";
		}

		$self->{failure} = 1;
		$self->addbadmessage(CGI::p($errorMessage));
		
	} 
	###########################################################
	# FIXME if the file is accompanied by auxiliary files transfer them as well
	# if the filepath ends in   foobar/foobar.pg  then we assume there are auxiliary files
	# copy the contents of the original foobar directory to the new one
	#
	###########################################################
    # If things have worked so far determine if the file might be accompanied by auxiliary files
    # a path ending in    foo/foo.pg  is assumed to contain auxilliary files
    #
    my $auxiliaryFilesExist = has_aux_files($outputFilePath);

    if ($auxiliaryFilesExist and not $do_not_save ) {
        my $sourceDirectory = $sourceFilePath;
    	my $outputDirectory = $outputFilePath;
        $sourceDirectory =~ s|/[^/]+\.pg$||;
        $outputDirectory =~ s|/[^/]+\.pg$||;
##############
# Transfer this to Utils::copyAuxiliaryFiles($sourceDirectory, $destinationDirectory)
##############
    	my @filesToCopy;
        @filesToCopy = WeBWorK::Utils::readDirectory($sourceDirectory) if -d $sourceDirectory;
        foreach my $file (@filesToCopy) {
            next if $file =~ /\.pg$/;   # .pg file should already be transferred
        	my $fromPath = "$sourceDirectory/$file";
        	my $toPath   = "$outputDirectory/$file";
        	if (-f $fromPath and -r $fromPath and not -e $toPath) { # don't copy directories, don't copy files that have already been copied
				copy($fromPath, $toPath) or $writeFileErrors.= "<br> Error copying $fromPath to $toPath";
				# need to use binary transfer for gif files.  File::Copy does this.
				#warn "copied from $fromPath to $toPath";
				#warn "files are different ",system("diff $fromPath $toPath");
        	}
        	$self->addbadmessage($writeFileErrors) if not_blank($writeFileErrors);
        	

        }
        $self->addgoodmessage("Copied auxiliary files from $sourceDirectory to  new location at $outputDirectory");
 
    }
 ##############
 ##############
     
	###########################################################
	# clean up temp files on revert, save and save_as
	###########################################################	
	unless( $writeFileErrors or $do_not_save) {  # everything worked!  unlink and announce success!
		# unlink the temporary file if there are no errors and the save button has been pushed
		if (($action eq 'save' or $action eq 'save_as') and (-w $self->{tempFilePath})  ) {
		             
		             $self->addgoodmessage("Deleting temp file at " . $self->shortPath($self->{tempFilePath}));
		             die "tempFilePath is unsafe!" unless path_is_subdir($self->{tempFilePath}, $ce->{courseDirs}->{templates}, 1); # 1==path can be relative to dir
		             unlink($self->{tempFilePath}) ;
		}

		if ( defined($outputFilePath) and ! $self->{failure} and not $self->isTempEditFilePath($outputFilePath) ) {  
		            # don't announce saving of temporary editing files
			my $msg = "Saved to file '".$self->shortPath($outputFilePath)."'.";

			$self->addgoodmessage($msg);
			#$self->{inputFilePath} = $outputFilePath; ## DPVC -- avoid file-not-found message
		}

	}


}  # end saveFileChanges





sub getActionParams {
	my ($self, $actionID) = @_;
	my $r = $self->{r};
	
	my %actionParams=();
	foreach my $param ($r->param) {
		next unless $param =~ m/^action\.$actionID\./;
		$actionParams{$param} = [ $r->param($param) ];
	}
	return %actionParams;
}

sub fixProblemContents {
		#NOT a method
		my $problemContents = shift;
		
		# Handle the problem of line endings.  
		# Make sure that all of the line endings are of unix type.  
		# Convert \r\n to \n
		$problemContents =~ s/\r\n/\n/g;
		$problemContents =~ s/\r/\n/g;
		$problemContents;
}

sub fresh_edit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	#$self->addgoodmessage("fresh_edit_handler called");
}
sub view_form {
	my ($self, $onChange, %actionParams) = @_;
	my $file_type     = $self->{file_type};
	return "" if    $file_type eq 'hardcopy_header';  # these can't yet be edited from temporary files #FIXME
	my $output_string = "";
	unless ($file_type eq 'course_info' || $file_type eq 'options_info') {

		$output_string .= join(" ",
			# "Use what seed?: ",
			# CGI::textfield(-name=>'action.view.seed',-value=>$self->{problemSeed},-onfocus=>$onChange),
			WeBWorK::CGI_labeled_input(-type=>"text", -id=>"action_view_seed_id", -label_text=>"Using what seed?: ", -input_attr=>{-name=>'action.view.seed',-value=>$self->{problemSeed},-onfocus=>$onChange}),CGI::br(),
			# "and display mode ",
			# CGI::popup_menu(-name=>'action.view.displayMode', -values=>$self->r->ce->{pg}->{displayModes}, 
			  # -default=>$self->{displayMode}, -onmousedown=>$onChange)
			WeBWorK::CGI_labeled_input(-type=>"select", -id=>"action_view_displayMode_id", -label_text=>"Using what display mode?: ", -input_attr=>{-name=>'action.view.displayMode', -values=>$self->r->ce->{pg}->{displayModes}, -default=>$self->{displayMode}, -onmousedown=>$onChange}),CGI::br(),
		);
	}

	return $output_string;  #FIXME  add -labels to the pop up menu
}

sub view_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;
	my $courseName      =  $self->{courseID};
	my $setName         =  $self->{setID};
	my $fullSetName     =  $self->{fullSetID};
	my $problemNumber   =  $self->{problemID};
	my $problemSeed     = ($actionParams->{'action.view.seed'}) ? 
	                                $actionParams->{'action.view.seed'}->[0] 
	                                : DEFAULT_SEED();
	my $displayMode     = ($actionParams->{'action.view.displayMode'}) ? 
	                                $actionParams->{'action.view.displayMode'}->[0]  
	                                : $self->r->ce->{pg}->{options}->{displayMode};
	                                
	my $editFilePath        = $self->{editFilePath};
	my $tempFilePath        = $self->{tempFilePath};
	########################################################                               
	# grab the problemContents from the form in order to save it to the tmp file
	######################################################## 
	my $problemContents     = fixProblemContents($self->r->param('problemContents'));
	$self->{r_problemContents}    = \$problemContents;
	

	my $do_not_save = 0;
	my $file_type = $self->{file_type};                               
	$self->saveFileChanges($tempFilePath,);

	########################################################
	# construct redirect URL and redirect
	########################################################
	my $edit_level = $self->r->param("edit_level") || 0;
	$edit_level++;
	my $viewURL;
	
	my $relativeTempFilePath = $self->getRelativeSourceFilePath($tempFilePath);
	
	if ($file_type eq 'problem' or $file_type eq 'source_path_for_problem_file') { # redirect to Problem.pm or GatewayQuiz.pm

		# we need to know if the set is a gateway set to determine the redirect
		my $globalSet = $self->r->db->getGlobalSet( $setName );

		my $problemPage;
		if ( defined($globalSet) && $globalSet->assignment_type =~ /gateway/ ) {
			$problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::GatewayQuiz",$r,
			courseID => $courseName, setID => "Undefined_Set");
		}  else {
			$problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",$r,
									courseID => $courseName, setID => $setName, problemID => $problemNumber
			);
		}

		$viewURL = $self->systemLink($problemPage,
			params => {
				displayMode        => $displayMode,
				problemSeed        => $problemSeed,
				editMode           => "temporaryFile",
				edit_level         => $edit_level,
				sourceFilePath     => $relativeTempFilePath,
				status_message     => uri_escape($self->{status_message})
	
			}
		);
	} elsif ($file_type eq 'set_header' ) { # redirect to ProblemSet
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",$r,
			courseID => $courseName, setID => $setName, 
		);
		
		$viewURL = $self->systemLink($problemPage,
			params => {
				set_header         => $tempFilePath,
				displayMode        => $displayMode,
				problemSeed        => $problemSeed,
				editMode           => "temporaryFile",
				edit_level         => $edit_level,
				sourceFilePath     => $relativeTempFilePath,
				status_message     => uri_escape($self->{status_message})
	
			}
		);	
	} elsif ($file_type eq 'hardcopy_header') { # redirect to ProblemSet?? # it's difficult to view temporary changes for hardcopy headers
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",$r,
			courseID => $courseName, setID => $setName, 
		);
		
		$viewURL = $self->systemLink($problemPage,
			params => {
				set_header         => $tempFilePath,
				displayMode        => $displayMode,
				problemSeed        => $problemSeed,
				editMode           => "temporaryFile",
				edit_level         => $edit_level,
				sourceFilePath     => $relativeTempFilePath,
				status_message     => uri_escape($self->{status_message})
	
			}
		);	
	
	} elsif ($file_type eq 'course_info') {  # redirec to ProblemSets.pm
		my $problemSetsPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",$r,
			courseID => $courseName);
		$viewURL = $self->systemLink($problemSetsPage,
			params => {

				course_info        => $tempFilePath,
				editMode           => "temporaryFile",
				edit_level         => $edit_level,
				sourceFilePath     => $relativeTempFilePath,
				status_message     => uri_escape($self->{status_message})
			}
		);
	} elsif ($file_type eq 'options_info') {  # redirec to Options.pm
		my $optionsPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Options",$r,
			courseID => $courseName);
		$viewURL = $self->systemLink($optionsPage,
			params => {
				options_info       => $tempFilePath,
				editMode           => "temporaryFile",
				edit_level         => $edit_level,
				sourceFilePath     => $relativeTempFilePath,
				status_message     => uri_escape($self->{status_message})
			}
		);
	} else {
		die "I don't know how to redirect this file type $file_type ";
	}

	$self->reply_with_redirect($viewURL);
} 

sub add_problem_form {
   my $self            = shift;
 	my ($onChange, %actionParams) = @_;
	my $r               = $self->r;
	my $setName         = $self->{setID} ;
	my $problemNumber   = $self->{problemID} ;
    $setName            = defined($setName) ? $setName : '';  # we need this instead of using the || construction 
                                                              # to keep set 0 from being set to the 
                                                              # empty string.
    my $filePath        = $self->{inputFilePath};
 	$setName   =~ s|^set||;
	my @allSetNames = sort $r->db->listGlobalSets;
	for (my $j=0; $j<scalar(@allSetNames); $j++) {
		$allSetNames[$j] =~ s|^set||;
		$allSetNames[$j] =~ s|\.def||;
	}
	my $labels = {
		problem         => 'problem',
		set_header      => 'set header',
		hardcopy_header => 'hardcopy header',
	};
	return "" if $self->{file_type} eq 'course_info' || $self->{file_type} eq 'options_info';
	return join(" ",
		WeBWorK::CGI_labeled_input(-type=>"select", -id=>"action_add_problem_target_set_id", -label_text=>"Add to what set?: ", -input_attr=>{name=>'action.add_problem.target_set', values=>\@allSetNames, default=>$setName, onmousedown=>$onChange}),CGI::br(),
		WeBWorK::CGI_labeled_input(-type=>"select", -id=>"action_add_problem_file_type_id", -label_text=>"Add as what filetype?: ", -input_attr=>{name=>'action.add_problem.file_type', values=>['problem','set_header', 'hardcopy_header'], labels=>$labels, default=>$self->{file_type}, onmousedown=>$onChange}),
		CGI::br()
	);  #FIXME  add -lables to the pop up menu
	return "";
}

sub add_problem_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r= $self->r;
	my $db = $r->db;
	#$self->addgoodmessage("add_problem_handler called");
	my $courseName      =  $self->{courseID};
	my $setName         =  $self->{setID};
	my $problemNumber   =  $self->{problemID};
	my $sourceFilePath  =  $self->{editFilePath};
	my $displayMode     =  $self->{displayMode};
	my $problemSeed     =  $self->{problemSeed};
		    
	my $targetSetName         =  $actionParams->{'action.add_problem.target_set'}->[0];
	my $targetFileType        =  $actionParams->{'action.add_problem.file_type'}->[0];
	my $templatesPath         =  $self->r->ce->{courseDirs}->{templates};
	$sourceFilePath    =~ s|^$templatesPath/||;
	
	my $edit_level = $self->r->param("edit_level") || 0;
	$edit_level++;

	my $viewURL ='';
	if ($targetFileType eq 'problem') {
	    my $targetProblemNumber;
	    
	    my $set = $db->getGlobalSet($targetSetName);
	    
	    # for jitar sets new problems are put as top level
	    # problems at the end
	    if ($set->assignment_type eq 'jitar') {
		my @problemIDs = $db->listGlobalProblems($targetSetName);
		@problemIDs = sort { $a <=> $b } @problemIDs;
		my @seq = jitar_id_to_seq($problemIDs[$#problemIDs]);
		$targetProblemNumber = seq_to_jitar_id($seq[0]+1);
	    } else {
		$targetProblemNumber = 1+ WeBWorK::Utils::max( $db->listGlobalProblems($targetSetName));
	    }


	
		#################################################
		# Update problem record
		#################################################
		my $problemRecord  = $self->addProblemToSet(
							   setName        => $targetSetName,
							   sourceFile     => $sourceFilePath, 
							   problemID      => $targetProblemNumber, #added to end of set
		);
		$self->assignProblemToAllSetUsers($problemRecord);
		$self->addgoodmessage("Added $sourceFilePath to ". $targetSetName. " as problem ".($set->assignment_type eq 'jitar' ? join('.',jitar_id_to_seq($targetProblemNumber)) : $targetProblemNumber));
		$self->{file_type}   = 'problem'; # change file type to problem -- if it's not already that

		#################################################
		# Set up redirect Problem.pm
		#################################################
				my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor2",$r,
			courseID  => $courseName, 
			setID     => $targetSetName, 
			problemID => $targetProblemNumber, 
		);
		my $relativeSourceFilePath = $self->getRelativeSourceFilePath($sourceFilePath);
		$viewURL = $self->systemLink($problemPage,
				params => {
					displayMode        => $displayMode,
					problemSeed        => $problemSeed,
					editMode           => "savedFile",
					edit_level         => $edit_level,
					sourceFilePath     => $relativeSourceFilePath,
					status_message     => uri_escape($self->{status_message}),
					file_type          => 'problem',
	
				}
		);

	} elsif ($targetFileType eq 'set_header')  {
		#################################################
		# Update set record
		#################################################
		my $setRecord  = $self->r->db->getGlobalSet($targetSetName);
		$setRecord->set_header($sourceFilePath);
		if(  $self->r->db->putGlobalSet($setRecord) ) {
			$self->addgoodmessage("Added '".$self->shortPath($sourceFilePath)."' to ". $targetSetName. " as new set header ") ;
		} else {
			$self->addbadmessage("Unable to make '".$self->shortPath($sourceFilePath)."' the set header for $targetSetName");
		}
		$self->{file_type} = 'set_header'; # change file type to set_header if it not already so
		#################################################
		# Set up redirect
		#################################################
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",$r,
			courseID => $courseName, setID => $targetSetName
		);
		$viewURL = $self->systemLink($problemPage,
				params => {
					displayMode        => $displayMode,
					editMode           => "savedFile",
					edit_level         => $edit_level,
					status_message     => uri_escape($self->{status_message}),
						}
		);
	} elsif ($targetFileType eq 'hardcopy_header')  {
		#################################################
		# Update set record
		#################################################
		my $setRecord  = $self->r->db->getGlobalSet($targetSetName);
		$setRecord->hardcopy_header($sourceFilePath);
		if(  $self->r->db->putGlobalSet($setRecord) ) {
			$self->addgoodmessage("Added '".$self->shortPath($sourceFilePath)."' to ". $targetSetName. " as new hardcopy header ") ;
		} else {
			$self->addbadmessage("Unable to make '".$self->shortPath($sourceFilePath)."' the hardcopy header for $targetSetName");
		}
		$self->{file_type} = 'hardcopy_header'; # change file type to set_header if it not already so
		#################################################
		# Set up redirect
		#################################################
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Hardcopy",$r,
			courseID => $courseName, setID => $targetSetName
		);
		$viewURL = $self->systemLink($problemPage,
				params => {
					displayMode        => $displayMode,
					editMode           => "savedFile",
					edit_level         => $edit_level,
					status_message     => uri_escape($self->{status_message}),
						}
		);
	} else {
		die "Don't know what to do with target file type $targetFileType";
	}
	
	$self->reply_with_redirect($viewURL);
}


sub save_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r => $self->r;
	#return "" unless defined($self->{tempFilePath}) and -e $self->{tempFilePath};
	if ($self->{editFilePath} =~ /$BLANKPROBLEM$/ ) {
		return "";  #Can't save blank problems without changing names
	} elsif (-w $self->{editFilePath}) {

		return "Save to ".CGI::b($self->shortPath($self->{editFilePath}))." and View";	

	} else {
		return ""; #"Can't save -- No write permission";
	}

}

sub save_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r= $self->r;
	#$self->addgoodmessage("save_handler called");
	my $courseName      =  $self->{courseID};
	my $setName         =  $self->{setID};
	my $fullSetName     =  $self->{fullSetID};
	my $problemNumber   =  $self->{problemID};
	my $displayMode     =  $self->{displayMode};
	my $problemSeed     =  $self->{problemSeed};
	
	#################################################
	# grab the problemContents from the form in order to save it to a new permanent file
	# later we will unlink (delete) the current temporary file
	#################################################
	my $problemContents = fixProblemContents($self->r->param('problemContents'));
	$self->{r_problemContents} = \$problemContents;
	
	#################################################
	# Construct the output file path
	#################################################
	my $editFilePath        = $self->{editFilePath};
	my $outputFilePath      = $editFilePath;

	my $do_not_save = 0;
	my $file_type = $self->{file_type};
	$self->saveFileChanges($outputFilePath);	
	#################################################
	# Set up redirect to Problem.pm
	#################################################
	my $viewURL;
	########################################################
	# construct redirect URL and redirect
	########################################################
	if ($file_type eq 'problem' || $file_type eq 'source_path_for_problem_file') { # redirect to Problem.pm

		# we need to know if the set is a gateway set to determine the redirect
		my $globalSet = $self->r->db->getGlobalSet( $setName );
		my $problemPage;
		if ( defined( $globalSet) && $globalSet->assignment_type =~ /gateway/ ) {
			$problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::GatewayQuiz",$r,
			courseID => $courseName, setID => "Undefined_Set");
			# courseID => $courseName, setID => $fullSetName);
		} else {
			$problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",$r,
									courseID => $courseName, setID => $setName, problemID => $problemNumber	);
		}
		
		my $relativeEditFilePath = $self->getRelativeSourceFilePath($editFilePath);
		
		$viewURL = $self->systemLink($problemPage,
			params => {
				displayMode        => $displayMode,
				problemSeed        => $problemSeed,
				editMode           => "savedFile",
				edit_level         => 0,
				sourceFilePath     => $relativeEditFilePath,
				status_message     => uri_escape($self->{status_message})
	
			}
		);
	} elsif ($file_type eq 'set_header' ) { # redirect to ProblemSet
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",$r,
			courseID => $courseName, setID => $setName, 
		);
		
		$viewURL = $self->systemLink($problemPage,
			params => {
				displayMode        => $displayMode,
				problemSeed        => $problemSeed,
				editMode           => "savedFile",
				edit_level         => 0,
				status_message     => uri_escape($self->{status_message})
	
			}
		);	
	} elsif ( $file_type eq 'hardcopy_header') { # redirect to ProblemSet
		my $problemPage = $self->r->urlpath->newFromModule('WeBWorK::ContentGenerator::Hardcopy',$r,
			courseID => $courseName, setID => $setName, 
		);
		
		$viewURL = $self->systemLink($problemPage,
			params => {
				displayMode        => $displayMode,
				problemSeed        => $problemSeed,
				editMode           => "savedFile",
				edit_level         => 0,
				status_message     => uri_escape($self->{status_message})
	
			}
		);	
	
	} elsif ($file_type eq 'course_info') {  # redirect to ProblemSets.pm
		my $problemSetsPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",$r,
			courseID => $courseName);
		$viewURL = $self->systemLink($problemSetsPage,
			params => {
				editMode           => ("savedFile"),
				edit_level         => 0,
				status_message     => uri_escape($self->{status_message})
			}
		);
	} elsif ($file_type eq 'options_info') {  # redirect to Options.pm
		my $optionsPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Options",$r,
			courseID => $courseName);
		$viewURL = $self->systemLink($optionsPage,
			params => {
				editMode           => ("savedFile"),
				edit_level         => 0,
				status_message     => uri_escape($self->{status_message})
			}
		);
	} elsif ($file_type eq 'source_path_for_problem_file') {  # redirect to ProblemSets.pm
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor2",$r,
		courseID => $courseName, setID => $setName, problemID => $problemNumber
		);
		my $viewURL = $self->systemLink($problemPage, 
			 params=>{
			    displayMode        => $displayMode,
				problemSeed        => $problemSeed,
				editMode           => "savedFile",
				edit_level         => 0,
				sourceFilePath     => $outputFilePath, #The path relative to the templates directory is required.
				file_type          => 'source_path_for_problem_file',
				status_message     => uri_escape($self->{status_message})

			 }
	);

	} else {
		die "I don't know how to redirect this file type $file_type ";
	}
	
	$self->reply_with_redirect($viewURL);
}



# sub make_local_copy_form {
# 	my ($self, $genericParams, $actionParams, $tableParams) = @_;
# 	my $editFilePath    = $self->{editFilePath}; # path to the permanent file to be edited
# 	#warn "editFilePath $editFilePath inputFilePath",$self->{inputFilePath};
# 	return "" unless -e $editFilePath;
# 	return "" if -w $editFilePath;
# 	return "" unless    $self->{file_type} eq 'problem'           # need problem structure to make local copy in most cases
# 			 or $self->{file_type} eq 'blank_problem'   # $editFilePath eq  $self->r->cr->{webworkFiles}{screenSnippets}{blankProblem}
# 	                 or $self->{file_type} eq 'set_header'      # $editFilePath eq  $self->r->ce->{webworkFiles}->{hardcopySnippets}->{setHeader}   # special case to make copy of screen header
# 	                 or $self->{file_type} eq 'hardcopy_header';  #  $editFilePath eq  $self->r->ce->{webworkFiles}->{screenSnippets}->{setHeader}   ;  # special case to make copy of hardcopy header
# 	                 #  or $self->{file_type} eq 'source_path_for_problem_file'; # need setID and problemID to make local copy -- can't be done in this case.
# 	# make sure setID is well defined before allowing local copy
# 	my $setID         = $self->{setID};
# 	my $probNum       = ($self->{file_type} eq 'problem')? "/problem $self->{problemID}" : "";
# 	return "" unless not_blank($setID) && $setID ne 'Undefined_Set';
# 	
# 	return join ("",
# 		"Save local editable copy as: [TMPL]/".($self->determineLocalFilePath($editFilePath)).CGI::br()." and use in ".CGI::b("set $setID$probNum"),
# 		CGI::hidden(-name=>'action.make_local_copy.target_file', -value=>$self->determineLocalFilePath($editFilePath) ),
# 		CGI::hidden(-name=>'action.make_local_copy.source_file', -value=>$editFilePath ),
# 		CGI::hidden(-name=>'action.make_local_copy.file_type',-value=>$self->{file_type}),
# 		CGI::hidden(-name=>'action.make_local_copy.saveMode',-value=>'rename')
# 	);
# }
# 
# 
# sub make_local_copy_handler {
# 	my ($self, $genericParams, $actionParams, $tableParams) = @_;
# 	foreach my $key (qw(target_file file_type saveMode source_file)) {
# 		$actionParams->{"action.save_as.$key"}->[0] = $actionParams->{"action.make_local_copy.$key"}->[0];
# 		#warn "action.make_local_copy.$key", @{$actionParams->{"action.make_local_copy.$key"}}
# 	}
#   	save_as_handler($self, $genericParams, $actionParams, $tableParams);
# 
# 
# }
sub save_as_form {  # calls the save_as_handler 
	my ($self, $onChange, %actionParams) = @_;
	my $editFilePath  = $self->{editFilePath};
#	return "" unless -w $editFilePath;  ##  DPVC -- we don't need to be able to write the original in order to make a copy
	
	
	my $templatesDir  =  $self->r->ce->{courseDirs}->{templates};
	my $setID         = $self->{setID};
	my $fullSetID     = $self->{fullSetID};
	
	
	my $shortFilePath =  $editFilePath;
	$shortFilePath   =~ s|^$templatesDir/||;
	$shortFilePath   =  'local/'.$shortFilePath
	  unless( $shortFilePath =~m|^local/| ||
		  (defined $setID and $shortFilePath =~m|^set$setID|));  # suggest that modifications be saved to the "local" subdirectory
	$shortFilePath =~ s|^.*/|| if $shortFilePath =~ m|^/|;  # if it is still an absolute path don't suggest a file path to save to.
   

	my $probNum = ($self->{file_type} eq 'problem')? "$self->{problemID}" : "header";
	my $andRelink = '';
# 	$andRelink = CGI::br().' and '.CGI::checkbox(
# 				-name => "action.save_as.saveMode",
# 				-value => "rename",
# 				-label => "",
# 				-checked => 1,
# 				-onclick=>$onChange
# 				).
# 		     " use in ".CGI::b("set $fullSetID$probNum")
# 		         if not_blank($setID)  && $setID ne 'Undefined_Set' &&
# 			    $self->{file_type} ne 'blank_problem';

    my $can_add_problem_to_set = not_blank($setID)  && $setID ne 'Undefined_Set' && $self->{file_type} ne 'blank_problem';
    # don't addor replace problems to sets if the set is the Undefined_Set or if the problem is the blank_problem.
    
	my $prettyProbNum = $probNum;

	if ($setID) {
	    my $set = $self->r->db->getGlobalSet($setID);
	    
	    $prettyProbNum = join('.',jitar_id_to_seq($probNum)) 
		if ($self->{file_type} eq 'problem' && $set && $set->assignment_type eq 'jitar');
	}

    my $replace_problem_in_set  = ($can_add_problem_to_set)?
			 # CGI::input({
    			 # -type      => 'radio',
    			 # -name      => "action.save_as.saveMode",
    			 # -value     => "rename",
    			 # -label     => '',
			 # },"and replace ".CGI::b("set $fullSetID$probNum").',') 
			 WeBWorK::CGI_labeled_input(-type=>'radio', -id=>'action_save_as_saveMode_rename_id', -label_text=>"Replace current problem: ".CGI::strong("$fullSetID/$prettyProbNum"), -input_attr=>{
			 	name      => "action.save_as.saveMode",
    		 	value     => "rename",
    		 	checked    =>1,
			 }).CGI::br() : ''
    ;
    my $add_problem_to_set      = ($can_add_problem_to_set)?
             # CGI::input({
    			 # -type      => 'radio',
    			 # -name      => "action.save_as.saveMode",
    			 # -value     => 'add_to_set_as_new_problem',
    			 # -label     => '',
    			 # -onfocus   => $onChange,
    		 # },"and append to end of set $fullSetID",) : ''
			 WeBWorK::CGI_labeled_input(-type=>'radio', -id=>"action_save_as_saveMode_new_problem_id", -label_text=>"Append to end of ". CGI::strong("$fullSetID")." set", -input_attr=>{
				 -name      => "action.save_as.saveMode",
    			 -value     => 'add_to_set_as_new_problem',
				 -onfocus   => $onChange,
			 }).CGI::br() : ''
    ;  
    my $rh_new_problem_options = {
    			# -type      => 'radio',
    			 -name      => "action.save_as.saveMode",
    			 -value     => "new_independent_problem",
    			 -onfocus   => $onChange,
    			 };
    $rh_new_problem_options->{checked}=1 unless $can_add_problem_to_set;
    my $create_new_problem       =  WeBWorK::CGI_labeled_input(-type=>'radio', -id=>"action_save_as_saveMode_independent_problem_id", -label_text=>"Create unattached problem", -input_attr=>$rh_new_problem_options).CGI::br(); #CGI::input($rh_new_problem_options,"as a new independent problem");
    
    $andRelink = CGI::br(). $replace_problem_in_set . $add_problem_to_set . $create_new_problem;
    			 
	return #'Save AS [TMPL]/'.
	        # CGI::textfield(
			       # -name=>'action.save_as.target_file', -size=>60, -value=>"$shortFilePath",  
			       # -onfocus=>$onChange
			      # ).",".
			WeBWorK::CGI_labeled_input(-type=>"text", -id=>"action_save_as_target_file_id", -label_text=>"Save file to: [TMPL]/", -input_attr=>{
				-name=>'action.save_as.target_file', -size=>60, -value=>"$shortFilePath",  
			    -onfocus=>$onChange
			}).
			CGI::hidden(-name=>'action.save_as.source_file', -value=>$editFilePath ).
			CGI::hidden(-name=>'action.save_as.file_type',-value=>$self->{file_type}).
			$andRelink;
}
# suggestions for improvement
# save as ......
# ¥replacing foobar (rename) ¥ and add to set (add_new_problem) ¥ as an independent file (new_independent_problem)
 
sub save_as_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;
	#$self->addgoodmessage("save_as_handler called");
	$self->{status_message} = ''; ## DPVC -- remove bogus old messages
	my $courseName      =  $self->{courseID};
	my $setName         =  $self->{setID};
	my $fullSetName     =  $self->{fullSetID};
	my $problemNumber   =  $self->{problemID};
	my $displayMode     =  $self->{displayMode};
	my $problemSeed     =  $self->{problemSeed};
	my $effectiveUserName = $self->r->param('effectiveUser');
	
	my $do_not_save = 0;
	my $saveMode       = $actionParams->{'action.save_as.saveMode'}->[0] || 'no_save_mode_selected';
	my $new_file_name  = $actionParams->{'action.save_as.target_file'}->[0] || '';
	my $sourceFilePath = $actionParams->{'action.save_as.source_file'}->[0] || '';
	my $file_type      = $actionParams->{'action.save_as.file_type'}->[0] || '';
	$self ->{sourceFilePath} = $sourceFilePath;  # store for use in saveFileChanges
	$new_file_name =~ s/^\s*//;  #remove initial and final white space
	$new_file_name =~ s/\s*$//;
	if ( $new_file_name !~ /\S/) { # need a non-blank file name
		# setting $self->{failure} stops saving and any redirects
		$do_not_save = 1;
		$self->addbadmessage(CGI::p("Please specify a file to save to."));
	}
	
	#################################################
	# grab the problemContents from the form in order to save it to a new permanent file
	# later we will unlink (delete) the current temporary file
	#################################################
	my $problemContents = fixProblemContents($self->r->param('problemContents'));
	$self->{r_problemContents} = \$problemContents;
	warn "problem contents is empty" unless $problemContents;
	#################################################
	# Rescue the user in case they forgot to end the file name with .pg
	#################################################
	
	if($file_type eq 'problem' 
	  or $file_type eq 'blank_problem'
	  or $file_type eq 'set_header') {
			$new_file_name =~ s/\.pg$//; # remove it if it is there
			$new_file_name .= '.pg'; # put it there
			
	}	
	#################################################
	# Construct the output file path
	#################################################
	my $outputFilePath = $self->r->ce->{courseDirs}->{templates} . '/' . 
								 $new_file_name; 		
	if (defined $outputFilePath and -e $outputFilePath) {
		# setting $do_not_save stops saving and any redirects
		$do_not_save = 1;
		$self->addbadmessage(CGI::p("File '".$self->shortPath($outputFilePath)."' exists.  
		File not saved. No changes have been made.
		You can change the file path for this problem manually from the 'Hmwk Sets Editor' page"));
		$self->addgoodmessage(CGI::p("The text box now contains the source of the original problem.".
		" You can recover lost edits by using the Back button on your browser."));
	} else {
		$self->{editFilePath} = $outputFilePath;
		$self->{tempFilePath} = ''; # nothing needs to be unlinked.
		$self->{inputFilePath} = '';
	}


	unless ($do_not_save ) {
		$self->saveFileChanges($outputFilePath);
		my $targetProblemNumber;

		if ($saveMode eq 'rename' and -r $outputFilePath) { 
		#################################################
		# Modify source file path in problem
		#################################################
			if ($file_type eq 'set_header' ) {
				my $setRecord = $self->r->db->getGlobalSet($setName);
				$setRecord->set_header($new_file_name);
				if ($self->r->db->putGlobalSet($setRecord)) {
				  $self->addgoodmessage("The set header for set $setName has been renamed to '".$self->shortPath($outputFilePath)."'.") ;
				} else {
				  $self->addbadmessage("Unable to change the set header for set $setName. Unknown error.");
				}
			} elsif ($file_type eq 'hardcopy_header' ) {
				my $setRecord = $self->r->db->getGlobalSet($setName);
				$setRecord->hardcopy_header($new_file_name);
				if ($self->r->db->putGlobalSet($setRecord)) {
				  $self->addgoodmessage("The hardcopy header for set $setName has been renamed to '".$self->shortPath($outputFilePath)."'.") ;
				} else {
				  $self->addbadmessage("Unable to change the hardcopy header for set $setName. Unknown error.");
				}
			} else {
				my $problemRecord;
				if ( $fullSetName =~ /,v(\d+)$/ ) {
					$problemRecord = $self->r->db->getMergedProblemVersion($effectiveUserName, $setName, $1, $problemNumber);
				} else {
					$problemRecord = $self->r->db->getGlobalProblem($setName,$problemNumber);
				}
				$problemRecord->source_file($new_file_name);
				my $result = ( $fullSetName =~ /,v(\d+)$/ ) ?
					$self->r->db->putProblemVersion($problemRecord) :
					$self->r->db->putGlobalProblem($problemRecord);
				my $prettyProblemNumber = $problemNumber;
				my $set = $self->r->db->getGlobalSet($setName);
				$prettyProblemNumber = join('.',jitar_id_to_seq($problemNumber)) if ($set && $set->assignment_type eq 'jitar');
				
				if  ( $result  ) {
					$self->addgoodmessage("The source file for 'set $fullSetName / problem $prettyProblemNumber' has been changed from ".
					$self->shortPath($sourceFilePath)." to '".$self->shortPath($outputFilePath)."'.") ;
				} else {
					$self->addbadmessage("Unable to change the source file path for set $fullSetName, problem $prettyProblemNumber. Unknown error.");
				}
			}
		} elsif ($saveMode eq 'add_to_set_as_new_problem') {
				    
		    my $set = $self->r->db->getGlobalSet($setName);
		    
		    # for jitar sets new problems are put as top level
		    # problems at the end
		    if ($set->assignment_type eq 'jitar') {
			my @problemIDs = $self->r->db->listGlobalProblems($setName);
			@problemIDs = sort { $a <=> $b } @problemIDs;
			my @seq = jitar_id_to_seq($problemIDs[$#problemIDs]);
			$targetProblemNumber = seq_to_jitar_id($seq[0]+1);
		    } else {
			$targetProblemNumber = 1+ WeBWorK::Utils::max( $self->r->db->listGlobalProblems($setName));
		    }
		    my $problemRecord  = $self->addProblemToSet(
					   setName        => $setName,
					   sourceFile     => $new_file_name, 
					   problemID      => $targetProblemNumber, #added to end of set
			);
			$self->assignProblemToAllSetUsers($problemRecord);
			$self->addgoodmessage("Added $new_file_name to ". $setName. " as problem ".($set->assignment_type eq 'jitar' ? join('.',jitar_id_to_seq($targetProblemNumber)) : $targetProblemNumber)) ;
		} elsif ($saveMode eq 'new_independent_problem') {
		#################################################
		# Don't modify source file path in problem -- just report 
		#################################################

			#$self->{status_message} = '';  ## DPVC remove old messages
			$self->addgoodmessage("A new file has been created at '".$self->shortPath($outputFilePath). 
			"' with the contents below. No changes have been made to set $setName.");
		} else {
			$self->addbadmessage("Don't recognize saveMode: |$saveMode|. Unknown error.");
		}
	  
	}
	my $edit_level = $self->r->param("edit_level") || 0;
	$edit_level++;
	
	#################################################
	# Set up redirect
	# The redirect gives the server time to detect that the new file exists.
	#################################################
	my $problemPage;
	my $new_file_type;

	if ($saveMode eq 'new_independent_problem' ) {
		$problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor2",$r,
			courseID => $courseName, setID => 'Undefined_Set', problemID => 1
		);
		$new_file_type = 'source_path_for_problem_file';
	} elsif ($saveMode eq 'rename') {
		$problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor2",$r,
			courseID => $courseName, setID => $setName, problemID => $problemNumber
		);
		$new_file_type = $file_type;
	} elsif ($saveMode eq 'add_to_set_as_new_problem') {
	    my $targetProblemNumber   =  WeBWorK::Utils::max( $self->r->db->listGlobalProblems($setName));
	    $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor2",$r,
			courseID => $courseName, setID => $setName, problemID => $targetProblemNumber
		);
		$new_file_type = $file_type;
	} else {
		$self->addbadmessage(" Please use radio buttons to choose the method for saving this file. Can't recognize saveMode: |$saveMode|.");
		# can't continue since paths have not been properly defined.
		return "";
	}

	#warn "save mode is $saveMode";

	my $relativeOutputFilePath = $self->getRelativeSourceFilePath($outputFilePath);
	
	my $viewURL = $self->systemLink($problemPage, 
								 params=>{
									 sourceFilePath     => $relativeOutputFilePath, #The path relative to the templates directory is required.
									 problemSeed        => $problemSeed,
									 edit_level         => $edit_level,
									 file_type          => $new_file_type,
									 status_message     => uri_escape($self->{status_message})

								 }
	);
	
	$self->reply_with_redirect($viewURL);
    return "";  # no redirect needed
}
sub revert_form {
	my ($self, $onChange, %actionParams) = @_;
	my $editFilePath    = $self->{editFilePath};
	return "Error: The original file $editFilePath cannot be read." unless -r $editFilePath;
	return "" unless defined($self->{tempFilePath}) and -e $self->{tempFilePath} ;
	return "Revert to ".$self->shortPath($editFilePath) ;

}
sub revert_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $ce = $self->r->ce;
	#$self->addgoodmessage("revert_handler called");	
	my $editFilePath       = $self->{editFilePath};
	$self->{inputFilePath} = $editFilePath;
	# unlink the temp files;
	die "tempFilePath is unsafe!" unless path_is_subdir($self->{tempFilePath}, $ce->{courseDirs}->{templates}, 1); # 1==path can be relative to dir
	unlink($self->{tempFilePath});
	$self->addgoodmessage("Deleting temp file at " . $self->shortPath($self->{tempFilePath}));
	$self->{tempFilePath}  = '';
	my $problemContents    ='';
	$self->{r_problemContents} = \$problemContents;
	$self->addgoodmessage("Reverting to original file '".$self->shortPath($editFilePath)."'");
	# no redirect is needed
}

sub output_JS{
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/AddOnLoad/addOnLoadEvent.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/legacy/vendor/tabber.js"}), CGI::end_script();

	if ($ce->{options}->{PGMathView}) {
	    print CGI::start_script({type=>"text/javascript", src=>"$ce->{webworkURLs}->{MathJax}"}), CGI::end_script();
	    print "<link href=\"$site_url/js/apps/MathView/mathview.css\" rel=\"stylesheet\" />";
	    print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/MathView/$ce->{pg}->{options}->{mathViewLocale}"}), CGI::end_script();
	    print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/MathView/mathview.js"}), CGI::end_script();
	}

	return "";
}

#Tells template to output stylesheet and js for Jquery-UI
sub output_jquery_ui{
	return "";
}

sub output_tabber_CSS{
	return "";
}


1;
