################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/PGProblemEditor.pm,v 1.63 2005/11/22 01:44:55 gage Exp $
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
#  filte_type eq 'course_info
#                 This allows editing of the course_info.txt file which gives general information about the course.  It is called from the
#                 ProblemSets.pm module.
#
#  file_type  eq 'blank_problem'
#                 This is a special call which allows one to create and edit a new PG problem.  The "stationery" source for this problem is
#                 stored in the conf/snippets directory and defined in global.conf by $webworkFiles{screenSnippets}{blankProblem}
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

use constant ACTION_FORMS => [qw(view add_problem make_local_copy save save_as  revert)]; #[qw(view save save_as revert add_problem add_header make_local_copy)];

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

	my $submit_button   = $r->param('submit');  # obtain submit command from form
	my $actionID        = $r->param('action');
	my $file_type       = $r->param("file_type") || '';
	my $setName         = $self->{setID};
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
	$self->{problemSeed} = '123456' unless defined $self->{problemSeed} and $self->{problemSeed} =~/\S/;
	
	##############################################################################
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
	    # if "sourceFilePath" is defined in the form, then we are getting the path directly.
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
	
	##########################################
	# File type is one of:     blank_problem course_info  problem set_header hardcopy_header source_path_for_problem_file  
    ##########################################
    #
    # Determine the path to the file
    #
    ###########################################
    	$self->getFilePaths($setName, $problemNumber, $file_type);
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
	
	my $tempFilePath    = $self->{tempFilePath}; # path to the file currently being worked with (might be a .tmp file)
	my $inputFilePath   = $self->{inputFilePath};   # path to the file for input, (might be a .tmp file)
	
	$self->addmessage($r->param('status_message') ||'');  # record status messages carried over if this is a redirect
	$self->addbadmessage("Changes in this file have not yet been permanently saved.") if -r $tempFilePath;
	if ( not( -e $inputFilePath) ) {
		$self->addbadmessage("This file: $inputFilePath, cannot be found.");
	} elsif (not -w $inputFilePath ) {
		$self->addbadmessage("This file '$inputFilePath' is protected! ".CGI::br()."To edit this text you must either 'Make a local copy' of this problem, or 
                           use 'Save As' to save it to another file.");
	}
    if ($inputFilePath =~/$BLANKPROBLEM$/) {
    	$self->addbadmessage("This file '$inputFilePath' is a blank problem! ".CGI::br()."To edit this text you must  
                           use 'Save As' to save it to another file.");
    }
	
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
	my $setName         = $self->{setID} ;
	my $problemNumber   = $self->{problemID} ;
    $setName            = defined($setName) ? $setName : '';  # we need this instead of using the || construction 
                                                              # to keep set 0 from being set to the 
                                                              # empty string.
    $problemNumber      = defined($problemNumber) ? $problemNumber : '';
    
	#########################################################################    
    # Construct url for reporting bugs:
	#########################################################################

# 	$editFilePath =~ m|([^/]*)Library|;    #find the path to the file
# 	my $libraryName = $1;                  # find the library, if any exists in the path name (first library is picked)
# 	$libraryName ='rochester' unless defined($libraryName) and $libraryName =~/\S/; # default library
	my $libraryName = '';
	if ($editFilePath =~ m|([^/]*)Library|)   {  #find the path to the file
		# find the library, if any exists in the path name (first library is picked)
		my $tempLibraryName = $1;
		$libraryName = ( defined($tempLibraryName) and $tempLibraryName =~/\S/ ) ? 
		                $tempLibraryName : "Library"; 
		# things that start /Library/setFoo/probBar  are labeled as component "Library"
		# which refers to the SQL based problem library. (is nationalLibrary a better name?)
	} else {
		$libraryName = 'rochester';  # make sure there is some default component defined.
	}

    my $BUGZILLA = "http://bugs.webwork.rochester.edu/enter_bug.cgi?product=Problem%20libraries".
                   "&component=$libraryName&bug_file_loc=${editFilePath}_with_problemSeed=".$self->{problemSeed};
	#FIXME  # The construction of this URL is somewhat fragile.  A separate module could be devoted to intelligent reporting of bugs.
    
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
	$header = ($self->isTempFilePath($inputFilePath)  ) ? CGI::div({class=>'temporaryFile'},$header) : $header;  # use colors if temporary file
	
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
	
	my $force_field = (defined($self->{sourceFilePath}) and $self->{sourceFilePath} ne "") ?
		CGI::hidden(-name=>'sourceFilePath',
		            -default=>$self->{sourceFilePath}) : '';

	my @allSetNames = sort $db->listGlobalSets;
	for (my $j=0; $j<scalar(@allSetNames); $j++) {
		$allSetNames[$j] =~ s|^set||;
		$allSetNames[$j] =~ s|\.def||;
	}
	my $target = "problem$edit_level"; # increasing edit_level gives you a new window with each edit.

 
	print CGI::p($header),
		CGI::start_form({method=>"POST", name=>"editor", action=>"$uri", target=>$target, enctype=>"application/x-www-form-urlencoded"}),
		$self->hidden_authen_fields,
		$force_field,
		CGI::hidden(-name=>'file_type',-default=>$self->{file_type}),
		CGI::div(" | ",
			CGI::a({-href=>'http://webwork.math.rochester.edu/docs/docs/pglanguage/manpages/',-target=>"manpage_window"},
				'&nbsp;Manpages&nbsp;',
			)," | ",
			CGI::a({-href=>'http://devel.webwork.rochester.edu/twiki/bin/view/Webwork/PGmacrosByFile',-target=>"manpage_window"},
				'&nbsp;macro list&nbsp;',
			)," | ",
			CGI::a({-href=>'http://devel.webwork.rochester.edu/doc/cvs/pg_HEAD/',-target=>"manpage_window"},
				'&nbsp;pod docs&nbsp;',
			)," | ",
			CGI::a({-href=>$BUGZILLA,-target=>"bugs_window"},
				'&nbsp;report problem bugs&nbsp;',
			)," | ",
		),
		CGI::p(
			CGI::textarea(
				-name => 'problemContents', -default => $problemContents,
				-rows => $rows, -columns => $columns, -override => 1,
			)," | ",
		);


	
######### print action forms
		
			print CGI::start_table({});
			#print CGI::Tr({}, CGI::td({-colspan=>2}, "Select an action to perform:"));
			
			my @formsToShow = @{ ACTION_FORMS() };
			my $default_choice = $formsToShow[0];
			my $i = 0;
			foreach my $actionID (@formsToShow) {
				# Check permissions
				#next if FORM_PERMS()->{$actionID} and not $authz->hasPermissions($user, FORM_PERMS()->{$actionID});
				my $actionForm = "${actionID}_form";
				my $onChange = "document.userlist.action[$i].checked=true";
				my %actionParams = $self->getActionParams($actionID);
				my $line_contents = $self->$actionForm($onChange, %actionParams);
				my $radio_params = {-type=>"radio", -name=>"action", -value=>$actionID};
				$radio_params->{checked}=1 if ($actionID eq $default_choice) ;
				print CGI::Tr({-valign=>"top"},
					CGI::td({}, CGI::input($radio_params)),
					CGI::td({}, $line_contents)
				) if $line_contents;
				
				$i++;
			}
			print CGI::Tr({}, CGI::td({-align=>"right"}, "Select above then:"),
			                  CGI::td({-align=>"left"}, CGI::submit(-name=>'submit', -value=>"Take Action!")),
			);
			print CGI::end_table();	
	
	
	print  CGI::end_form();
	return "";


}

################################################################################
# Utilities
################################################################################

# determineLocalFilePath   constructs a local file path parallel to a library file path
# This is a subroutine, not a method
# 
sub determineLocalFilePath {
	my $self= shift;				die "determineLocalFilePath is a method" unless ref($self);
	my $path = shift;
# 	my $default_screen_header_path   = $self->r->ce->{webworkFiles}->{hardcopySnippets}->{setHeader}; 
# 	my $default_hardcopy_header_path = $self->r->ce->{webworkFiles}->{screenSnippets}->{setHeader};
	my $setID = $self->{setID} || int(rand(1000));
	if ($path =~ /Library/) {
		$path =~ s|^.*?Library/||;  # truncate the url up to a segment such as ...rochesterLibrary/.......
# 	} elsif ($path eq $default_screen_header_path) {
# 		$path = "set$setID/setHeader.pg";
# 	} elsif ($path eq $default_hardcopy_header_path) {
# 		$path = "set$setID/hardcopyHeader.tex";
	} else { # if its not in a library we'll just save it locally
		$path = "new_problem_".int(rand(1000)).".pg";	#l hope there aren't any collisions.
	}
    $path;

}

sub determineTempFilePath {  # this does not create the path to the file
	my $self = shift;  die "determineTempFilePath is a method" unless ref($self);
	my $path =shift;
	my $user = $self->r->param("user");
	$user    = int(rand(1000)) unless defined $user;
	my $setID = $self->{setID} || int(rand(1000));
	my $courseDirectory = $self->r->ce->{courseDirs};
	###############
	# Calculate the location of the temporary file
	###############
	my $templatesDirectory = $courseDirectory->{templates};
	my $blank_file_path              = $self->r->ce->{webworkFiles}->{screenSnippets}->{blankProblem};
	my $default_screen_header_path   = $self->r->ce->{webworkFiles}->{hardcopySnippets}->{setHeader}; 
	my $default_hardcopy_header_path = $self->r->ce->{webworkFiles}->{screenSnippets}->{setHeader};
	my $tmpEditFileDirectory = (defined ($courseDirectory->{tmpEditFileDir}) ) ? $courseDirectory->{tmpEditFileDir} : "$templatesDirectory/tmpEdit";
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
		die "determineTempFilePath should only be used on paths within the templates directory, not on $path";
	}
	$path;
}
sub isTempFilePath  {
	my $self = shift;
	my $path = shift;
	my $courseDirectory = $self->r->ce->{courseDirs};
	my $templatesDirectory = $courseDirectory->{templates};
	my $tmpEditFileDirectory = (defined ($courseDirectory->{tmpEditFileDir}) ) ? $courseDirectory->{tmpEditFileDir} : "$templatesDirectory/tmpEdit";
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
	die 'Internal error to PGProblemEditor -- file type is not defined'  unless defined $file_type;

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
		
		($file_type eq 'blank_problem') and do {
			$editFilePath = $ce->{webworkFiles}->{screenSnippets}->{blankProblem};
			$self->addbadmessage("$editFilePath is blank problem template file and can not be edited directly. "
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
		  my $forcedSourceFile = $self->{sourceFilePath};
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
	
	my $tempFilePath = $self->determineTempFilePath($editFilePath);  #"$editFilePath.$TEMPFILESUFFIX";
	$self->{editFilePath}   = $editFilePath;
	$self->{tempFilePath}   = $tempFilePath;
	$self->{inputFilePath}  = (-r $tempFilePath) ? $tempFilePath : $editFilePath;
	#warn "editfile path is $editFilePath and tempFile is $tempFilePath and inputFilePath is ". $self->{inputFilePath};
}
sub new_saveFileChanges {

################################################################################
# new_saveFileChanges does most of the work. it is a separate method so that it can
# be called from either pre_header_initialize() or initilize(), depending on
# whether a redirect is needed or not.
# 
# it actually does a lot more than save changes to the file being edited, and
# sometimes less.
################################################################################

	my ($self, $outputFilePath, $problemContents ) = @_;
 	my $r             = $self->r;
 	my $ce            = $r->ce;

	my $action        = $self->{action}||'no action';
	my $editFilePath  = $self->{editFilePath};
	my $tempFilePath  = $self->{tempFilePath}; 	
	
	if (defined($problemContents) and ref($problemContents) ) {
		$problemContents = ${$problemContents};
	} elsif( not defined($problemContents) or $problemContents =~/\S/ ) {
		$problemContents = ${$self->{r_problemContents}};
	}
	##############################################################################
	# read and update the targetFile and targetFile.tmp files in the directory
	# if a .tmp file already exists use that, unless the revert button has been pressed.
	# The .tmp files are removed when the file is or when the revert occurs.
	##############################################################################
	

    unless (defined($outputFilePath) and $outputFilePath =~/\S/ ) {
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
	if ( defined($outputFilePath) and $outputFilePath =~/\S/  ) {   # save file
	    # Handle the problem of line endings.  
		# Make sure that all of the line endings are of unix type.  
		# Convert \r\n to \n
		#$problemContents =~ s/\r\n/\n/g;
		#$problemContents =~ s/\r/\n/g;

		# make sure any missing directories are created
		WeBWorK::Utils::surePathToFile($ce->{courseDirs}->{templates},
		                                                        $outputFilePath);

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
			$errorMessage = "Write permissions have not been enabled in $currentDirectory.  Changes must be saved to a different directory for viewing.";
		} elsif ( -e $outputFilePath and not -w $outputFilePath ) {
			$errorMessage = "Write permissions have not been enabled for $outputFilePath.  Changes must be saved to another file for viewing.";
		} else {
			$errorMessage = "Unable to write to $outputFilePath: $writeFileErrors";
		}

		$self->{failure} = 1;
		$self->addbadmessage(CGI::p($errorMessage));
		
	} 
	###########################################################
	# clean up temp files on revert, save and save_as
	###########################################################	
	unless( $writeFileErrors or $do_not_save) {  # everything worked!  unlink and announce success!
		# unlink the temporary file if there are no errors and the save button has been pushed
		if ($action eq 'save' or $action eq 'save_as' or $action eq 'revert') {
		             unlink($self->{tempFilePath}) ;
		}
		if ( defined($outputFilePath) and ! $self->{failure} )  {
			my $msg = "Saved to file: |$outputFilePath|";
			$self->addgoodmessage($msg);
		}

	}


}  # end new_saveFileChanges





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
	$self->addgoodmessage("fresh_edit_handler called");
}
sub view_form {
	my ($self, $onChange, %actionParams) = @_;
	my $output_string = "View";
	unless ($self->{file_type} eq 'course_info') {
		$output_string .= join(" ",
			" problem using seed ",
			CGI::textfield(-name=>'action.view.seed',-value=>$self->{problemSeed}),
			"and display mode ",
			CGI::popup_menu(-name=>'action.view.displayMode', -values=>$self->r->ce->{pg}->{displayModes}, 
			  -default=>$self->{displayMode}
			), ".",
		);
	}

	return $output_string;  #FIXME  add -lables to the pop up menu
}

sub view_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $courseName      =  $self->{courseID};
	my $setName         =  $self->{setID};
	my $problemNumber   =  $self->{problemID};
	my $problemSeed     = ($actionParams->{'action.view.seed'}) ? 
	                                $actionParams->{'action.view.seed'}->[0] 
	                                : 1234;
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
	$self->new_saveFileChanges($tempFilePath,);

	########################################################
	# construct redirect URL and redirect
	########################################################
	my $edit_level = $self->r->param("edit_level") || 0;
	$edit_level++;
	my $viewURL;
	
	if ($file_type eq 'problem' ) { # redirect to Problem.pm
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",
			courseID => $courseName, setID => $setName, problemID => $problemNumber
		);
		
		$viewURL = $self->systemLink($problemPage,
			params => {
				displayMode        => $displayMode,
				problemSeed        => $problemSeed,
				editMode           => "temporaryFile",
				edit_level         => $edit_level,
				sourceFilePath     => $tempFilePath,
				status_message     => uri_escape($self->{status_message})
	
			}
		);
	} elsif ($file_type eq 'set_header' or $file_type eq 'hardcopy_header') { # redirect to ProblemSet
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
			courseID => $courseName, setID => $setName, 
		);
		
		$viewURL = $self->systemLink($problemPage,
			params => {
				displayMode        => $displayMode,
				problemSeed        => $problemSeed,
				editMode           => "temporaryFile",
				edit_level         => $edit_level,
				status_message     => uri_escape($self->{status_message})
	
			}
		);	
	
	
	} elsif ($file_type eq 'course_info') {  # redirecto to ProblemSets.pm
		my $problemSetsPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",
			courseID => $courseName);
		$viewURL = $self->systemLink($problemSetsPage,
			params => {
				editMode           => ("temporaryFile"),
				edit_level         => $edit_level,
				status_message     => uri_escape($self->{status_message})
			}
		);
	} elsif ($file_type eq 'source_path_for_problem_file') { # redirect to Problem.pm
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",
			courseID => $courseName, setID => $setName, problemID => $problemNumber
		);
		
		$viewURL = $self->systemLink($problemPage,
			params => {
				displayMode        => $displayMode,
				problemSeed        => $problemSeed,
				editMode           => "temporaryFile",
				edit_level         => $edit_level,
				sourceFilePath     => $tempFilePath,
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
 	$setName   =~ s|^set||;
	my @allSetNames = sort $r->db->listGlobalSets;
	for (my $j=0; $j<scalar(@allSetNames); $j++) {
		$allSetNames[$j] =~ s|^set||;
		$allSetNames[$j] =~ s|\.def||;
	}
	return "" if $self->{file_type} eq 'course_info';
	return join(" ",
		"Add problem to set " ,
		CGI::popup_menu(-name=>'action.add_problem.target_set', -values=>\@allSetNames, -default=>$setName),
		" as ",
		CGI::popup_menu(-name=>'action.add_problem.file_type', -values=>['problem','set_header'], -default=>'problem'),
		
	);  #FIXME  add -lables to the pop up menu
	return "";
}

sub add_problem_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
#	$self->addgoodmessage("add_problem_handler called");
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
		my $targetProblemNumber   =  1+ WeBWorK::Utils::max( $self->r->db->listGlobalProblems($targetSetName));
		
		#################################################
		# Update problem record
		#################################################
		my $problemRecord  = $self->addProblemToSet(
							   setName        => $targetSetName,
							   sourceFile     => $sourceFilePath, 
							   problemID      => $targetProblemNumber, #added to end of set
		);
		$self->assignProblemToAllSetUsers($problemRecord);
		$self->addgoodmessage("Added $sourceFilePath to ". $targetSetName. " as problem $targetProblemNumber") ;
		$self->{file_type}   = 'problem'; # change file type to problem -- if it's not already that

		#################################################
		# Set up redirect Problem.pm
		#################################################
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",
			courseID  => $courseName, 
			setID     => $targetSetName, 
			problemID => $targetProblemNumber, 
		);
		$viewURL = $self->systemLink($problemPage,
				params => {
					displayMode        => $displayMode,
					problemSeed        => $problemSeed,
					editMode           => "savedFile",
					edit_level         => $edit_level,
					sourceFilePath     => $sourceFilePath,
					status_message     => uri_escape($self->{status_message})
	
				}
		);
	} elsif ($targetFileType eq 'set_header')  {
		#################################################
		# Update set record
		#################################################
		my $setRecord  = $self->r->db->getGlobalSet($targetSetName);
		$setRecord->set_header($sourceFilePath);
		if(  $self->r->db->putGlobalSet($setRecord) ) {
			$self->addgoodmessage("Added $sourceFilePath to ". $targetSetName. " as new set header ") ;
		} else {
			$self->addbadmessage("Unable to make $sourceFilePath the set header for $targetSetName");
		}
		$self->{file_type} = 'set_header'; # change file type to set_header if it not already so
		#################################################
		# Set up redirect
		#################################################
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
			courseID => $courseName, setID => $targetSetName
		);
		$viewURL = $self->systemLink($problemPage,
				params => {
					displayMode        => $displayMode,
					editMode           => "savedFile",
					edit_level         => $edit_level,
					status_message     => uri_escape($self->{status_message})
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
	if ($self->{editFilePath} =~ /$BLANKPROBLEM$/ ) {
		return "";  #Can't save blank problems without changing names
	} elsif (-w $self->{editFilePath}) {
		return "Save";	
	} else {
		return ""; #"Can't save -- No write permission";
	}

}

sub save_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	$self->addgoodmessage("save_handler called");
	my $courseName      =  $self->{courseID};
	my $setName         =  $self->{setID};
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
	$self->new_saveFileChanges($outputFilePath);	
	#################################################
	# Set up redirect to Problem.pm
	#################################################
	my $viewURL;
	########################################################
	# construct redirect URL and redirect
	########################################################
	if ($file_type eq 'problem' ) { # redirect to Problem.pm
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",
			courseID => $courseName, setID => $setName, problemID => $problemNumber
		);
		
		$viewURL = $self->systemLink($problemPage,
			params => {
				displayMode        => $displayMode,
				problemSeed        => $problemSeed,
				editMode           => "savedFile",
				edit_level         => 0,
				sourceFilePath     => $editFilePath,
				status_message     => uri_escape($self->{status_message})
	
			}
		);
	} elsif ($file_type eq 'set_header' or $file_type eq 'hardcopy_header') { # redirect to ProblemSet
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSet",
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
		my $problemSetsPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",
			courseID => $courseName);
		$viewURL = $self->systemLink($problemSetsPage,
			params => {
				editMode           => ("savedFile"),
				edit_level         => 0,
				status_message     => uri_escape($self->{status_message})
			}
		);
	} elsif ($file_type eq 'source_path_for_problem_file') {  # redirect to ProblemSets.pm
		my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
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

sub save_as_form {
	my ($self, $onChange, %actionParams) = @_;
	my $sourceFilePath = $self->{editFilePath}; 
	my $templatesPath  =  $self->r->ce->{courseDirs}->{templates};
	$sourceFilePath    =~ s|^$templatesPath/||; # make sure path relative to templates directory

	return "Save ".
				CGI::popup_menu(-name=>'action.save_as.saveMode', -values=>['rename','save_a_copy'], 
			  -default=>'rename',-labels=>{rename=>' as ',save_a_copy=>'a copy to'}
			). ": [TMPL]/".CGI::textfield(-name=>'action.save_as.target_file', -size=>40, -value=>$sourceFilePath),;

}

sub save_as_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	$self->addgoodmessage("save_as_handler called");
	my $courseName      =  $self->{courseID};
	my $setName         =  $self->{setID};
	my $problemNumber   =  $self->{problemID};
	my $displayMode     =  $self->{displayMode};
	my $problemSeed     =  $self->{problemSeed};
	
	my $do_not_save = 0;
	my $saveMode      = $actionParams->{'action.save_as.saveMode'}->[0] || '';
	my $new_file_name = $actionParams->{'action.save_as.target_file'}->[0] || '';
	$new_file_name =~ s/^\s*//;  #remove initial and final white space
	$new_file_name =~ s/\s*$//;
	if ( $new_file_name !~ /\S/) { # need a non-blank file name
		# setting $self->{failure} stops saving and any redirects
		$do_not_save = 1;
		$self->addbadmessage(CGI::p("Please specify a file to save to."));
		last ACTION_CASES;  #stop processing
	}
	
	#################################################
	# grab the problemContents from the form in order to save it to a new permanent file
	# later we will unlink (delete) the current temporary file
	#################################################
	my $problemContents = fixProblemContents($self->r->param('problemContents'));
	$self->{r_problemContents} = \$problemContents;
	
	#################################################
	# Rescue the user in case they forgot to end the file name with .pg
	#################################################
	my $file_type = $self->{file_type};
	if($self->{file_type} eq 'problem' 
	  or $self->{file_type} eq 'blank_problem'
	  or $self->{file_type} eq 'set_header') {
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
		$self->addbadmessage(CGI::p("File $outputFilePath exists.  File not saved."));
	} else {
		$self->{editFilePath} = $outputFilePath;
		$self->{tempFilePath} = ''; # nothing needs to be unlinked.
		$self->{inputFilePath} = '';
	}


	unless ($do_not_save ) {
		$self->new_saveFileChanges($outputFilePath, \$problemContents);
		my $sourceFilePath = $outputFilePath; 
		my $templatesPath         =  $self->r->ce->{courseDirs}->{templates};
		$sourceFilePath    =~ s|^$templatesPath/||; # make sure path relative to templates directory

		if ($saveMode eq 'rename') { #save to new file
			my $problemRecord = $self->r->db->getGlobalProblem($setName,$problemNumber);
			$problemRecord->source_file($new_file_name);
			if  ( $self->r->db->putGlobalProblem($problemRecord)  ) {
				$self->addgoodmessage("The current source file for problem $problemNumber has been renamed to [TMPL]/$sourceFilePath.") ;
			} else {
				$self->addbadmessage("Unable to change the source file path for set $setName, problem $problemNumber. Unknown error.");
			}
		} elsif ($saveMode eq 'save_a_copy') {
			$self->addgoodmessage("A new local, editable, copy of this problem has been created at [TMPL]/$sourceFilePath.") ;	
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
	if ($saveMode eq 'save_a_copy' ) {
		$problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
			courseID => $courseName, setID => 'Undefined_Set', problemID => 'Undefined_Set'
		);
	} elsif ($saveMode eq 'rename') {
		$problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
			courseID => $courseName, setID => $setName, problemID => $problemNumber
		);
	
	} else {
		$self->addbadmessage("Don't recognize saveMode: |$saveMode|. Unknown error.");
	}
	my $viewURL = $self->systemLink($problemPage, 
								 params=>{
									 sourceFilePath     => $outputFilePath, #The path relative to the templates directory is required.
									 edit_level         => $edit_level,
									 file_type          => 'source_path_for_problem_file',
									 status_message     => uri_escape($self->{status_message})

								 }
	);
	
	$self->reply_with_redirect($viewURL);
return "";  # no redirect needed
}
sub revert_form {
	my ($self, $onChange, %actionParams) = @_;
	return "Revert" ;

}
sub revert_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	$self->addgoodmessage("revert_handler called");

	my $courseName      =  $self->{courseID};
	my $setName         =  $self->{setID};
	my $problemNumber   =  $self->{problemID};
	my $displayMode     =  $self->{displayMode};
	my $problemSeed     =  $self->{problemSeed};
	#################################################
	# Reset the problem paths
	#################################################
	
	my $editFilePath       = $self->{editFilePath};
	$self->{inputFilePath} = $editFilePath;
	$self->{tempFilePath}  = '';
	# unlink the temp files;
	unlink($self->{tempFilePath});
	my $problemContents    ='';
	$self->{r_problemContents} = \$problemContents;
	$self->addgoodmessage("Reverting to original file $editFilePath");
	# no redirect is needed
}
sub make_local_copy_form {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $editFilePath    = $self->{editFilePath}; # path to the permanent file to be edited
	return "" unless -e $editFilePath;
	return "" if -w $editFilePath;
	return "" unless $self->{file_type} eq 'problem';  
	                 # or $self->{file_type} eq 'set_header' ;    # need problem structure to make local copy -- not available for header
	                 #  or $self->{file_type} eq 'source_path_for_problem_file'; # need setID and problemID to make local copy
	return join ("",
		"Make local copy at: [TMPL]/".($self->determineLocalFilePath($editFilePath)),
		CGI::hidden(-name=>'action.make_local_copy.target_file', -value=>$self->determineLocalFilePath($editFilePath) ),
		CGI::hidden(-name=>'action.make_local_copy.source_file', -value=>$editFilePath ),
	);

}

sub make_local_copy_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	$self->addgoodmessage("make_local_copy_handler called");

	my $courseName      =  $self->{courseID};
	my $setName         =  $self->{setID};
	my $problemNumber   =  $self->{problemID};

	my $displayMode     =  $self->{displayMode};
	my $problemSeed     =  $self->{problemSeed};
	
	my $do_not_save     = 0;   #error flag
	#################################################
	# Save the file locally
	#################################################
	my $new_file_name = $actionParams->{'action.make_local_copy.target_file'}->[0] || '';
	my $sourceFilePath = $actionParams->{'action.make_local_copy.source_file'}->[0] || ''; 
	my $templatesPath         =  $self->r->ce->{courseDirs}->{templates};
	$sourceFilePath    =~ s|^$templatesPath/||; # make sure path relative to templates directory

	if ( $new_file_name !~ /\S/) { # need a non-blank file name
		# setting $self->{failure} stops saving and any redirects
		$do_not_save = 1;
		warn "new file name is $new_file_name";
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
	# Construct the output file path
	#################################################
	my $outputFilePath = $self->r->ce->{courseDirs}->{templates} . '/' . 
								 $new_file_name; 		
	if (defined $outputFilePath and -e $outputFilePath) {
		# setting $do_not_save stops saving and any redirects
		$do_not_save = 1;
		$self->addbadmessage(CGI::p("File $outputFilePath exists.  File not saved."));
	} else {
		#$self->addgoodmessage("Saving to file $outputFilePath.");
	}
	my $file_type = $self->{file_type};
	unless ($do_not_save ) {
		$self->new_saveFileChanges($outputFilePath);	
	}
	#################################################
	# Modify source file in problem
	#################################################
	if (-r $outputFilePath and !$do_not_save) {
		my $problemRecord = $self->r->db->getGlobalProblem($setName,$problemNumber);
		$problemRecord->source_file($new_file_name);
		if  ( $self->r->db->putGlobalProblem($problemRecord)  ) {
			$self->addgoodmessage("A local, editable, copy of [TMPL]/$sourceFilePath has been made for problem $problemNumber.") ;
		} else {
			$self->addbadmessage("Unable to change the source file path for set $setName, problem $problemNumber. Unknown error.");
		}
	}
	my $edit_level = $self->r->param("edit_level") || 0;
	$edit_level++;
	#################################################
	# Set up redirect
	#################################################

	my $problemPage = $self->r->urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
		courseID => $courseName, setID => $setName, problemID => $problemNumber
	);
	my $viewURL = $self->systemLink($problemPage, 
								 params=>{
									 sourceFilePath     => $sourceFilePath, 
									 edit_level         => $edit_level,
									 file_type          => 'problem',
									 status_message     => uri_escape($self->{status_message})

								 }
	);
	$self->reply_with_redirect($viewURL);
}

sub rename_form {
	my ($self, $onChange, %actionParams) = @_;
	my $problemPath = $self->{editFilePath};
	my $templatesDir = $self->r->ce->{courseDirs}->{templates};
	#warn "problemPath $problemPath $templatesDir";
	$problemPath   =~ s|^$templatesDir/||;
	return join("",
	       "Rename problem file to : [TMPL]/".CGI::textfield(-name=>'action.rename.target_file', -size=>40, -value=>$problemPath),
	       	CGI::hidden(-name=>'action.make_local_copy.source_file', -value=>$self->{editFilePath} ),
	);


}

sub rename_handler {
    my ($self, $genericParams, $actionParams, $tableParams) = @_;
    $actionParams->{'action.make_local_copy.target_file'}->[0] = $actionParams->{'action.rename.target_file'}->[0];
	make_local_copy_handler($self, $genericParams, $actionParams, $tableParams);
}


1;
