################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.	 See either the GNU General Public License or the
# Artistic License for more details.
################################################################################


package WeBWorK::ContentGenerator::Instructor::GetTargetSetProblems;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::GetTargetSetProblems - Get homework sets.

=cut

use strict;
use warnings;


#use CGI qw(-nosticky);
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Form;
use WeBWorK::Utils qw(readDirectory max sortByName);
use WeBWorK::Utils::Tasks qw(renderProblems);
use WeBWorK::Utils::LanguageAndDirection;
use File::Find;

require WeBWorK::Utils::ListingDB;

use constant SHOW_HINTS_DEFAULT => 0;
use constant SHOW_SOLUTIONS_DEFAULT => 0;
use constant MAX_SHOW_DEFAULT => 20;
use constant NO_LOCAL_SET_STRING => 'No sets in this course yet';
use constant SELECT_SET_STRING => 'Select a Set from this Course';
use constant SELECT_LOCAL_STRING => 'Select a Problem Collection';
use constant MY_PROBLEMS => '  My Problems  ';
use constant MAIN_PROBLEMS => '  Unclassified Problems  ';
use constant CREATE_SET_BUTTON => 'Create New Set';
use constant ALL_CHAPTERS => 'All Chapters';
use constant ALL_SUBJECTS => 'All Subjects';
use constant ALL_SECTIONS => 'All Sections';
use constant ALL_TEXTBOOKS => 'All Textbooks';

use constant LIB2_DATA => {
  'dbchapter' => {name => 'library_chapters', all => 'All Chapters'},
  'dbsection' =>  {name => 'library_sections', all =>'All Sections' },
  'dbsubject' =>  {name => 'library_subjects', all => 'All Subjects' },
  'textbook' =>  {name => 'library_textbook', all =>  'All Textbooks'},
  'textchapter' => {name => 'library_textchapter', all => 'All Chapters'},
  'textsection' => {name => 'library_textsection', all => 'All Sections'},
  'keywords' =>  {name => 'library_keywords', all => '' },
  };

##	for additional problib buttons
my %problib;	## This is configured in defaults.conf
my %ignoredir = (
	'.' => 1, '..' => 1, 'Library' => 1, 'CVS' => 1, 'tmpEdit' => 1,
	'headers' => 1, 'macros' => 1, 'graphics'=>1, 'email' => 1, '.svn' => 1,
);

sub prepare_activity_entry {
	my $self=shift;
	my $r = $self->r;
	my $user = $self->r->param('user') || 'NO_USER';
	return("In SetMaker2 as user $user");
}

sub make_myset_data_row {
	my $self = shift;
	my $sourceFileName = shift;
	my $pg = shift;
	my $cnt = shift;

	$sourceFileName =~ s|^./||; # clean up top ugliness

	my $urlpath = $self->r->urlpath;
	my $db = $self->r->db;

	## to set up edit and try links elegantly we want to know if
	##    any target set is a gateway assignment or not
	my $localSet = $self->r->param('local_sets');
	my $setRecord;
	if ( defined($localSet) && $localSet ne SELECT_SET_STRING &&
	     $localSet ne NO_LOCAL_SET_STRING ) {
		$setRecord = $db->getGlobalSet( $localSet );
	}
	my $isGatewaySet = ( defined($setRecord) && 
			     $setRecord->assignment_type =~ /gateway/ );

	my %problem_div_settings = (
		-class=>"RenderSolo",
		-dir=>"ltr",
		# Add what is needed for lang and dir settings
		get_problem_lang_and_dir($pg->{flags}, $self->r->ce->{perProblemLangAndDirSettingMode}, $self->r->ce->{language})
	);

	my $problem_output = $pg->{flags}->{error_flag} ?
		CGI::div({class=>"ResultsWithError"}, CGI::em("This problem produced an error"))
		: CGI::div( \%problem_div_settings, $pg->{body_text});
	$problem_output .= $pg->{flags}->{comment} if($pg->{flags}->{comment});


	#if($self->{r}->param('browse_which') ne 'browse_npl_library') {
	my $problem_seed = $self->{'problem_seed'} || 1234;
	my $edit_link = CGI::a({href=>$self->systemLink(
		 $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
			  courseID =>$urlpath->arg("courseID"),
			  setID=>"Undefined_Set",
			  problemID=>"1"),
			params=>{sourceFilePath => "$sourceFileName", problemSeed=> $problem_seed}
		  ), target=>"WW_Editor"}, "Edit it" );
	
	my %delete_box_data = ( -id=>"deleted$cnt".'myset' ,-name=>"deleted$cnt",-value=>1,-label=>"Delete this problem from the target set on the next update");
	
	my $displayMode = $self->r->param("mydisplayMode");
	$displayMode = $self->r->ce->{pg}->{options}->{displayMode}
		if not defined $displayMode or $displayMode eq "None";
	my $module = ( $isGatewaySet ) ? "GatewayQuiz" : "Problem";
	my %pathArgs = ( courseID =>$urlpath->arg("courseID"),
			setID=>"Undefined_Set" );
	$pathArgs{problemID} = "1" if ( ! $isGatewaySet );

	my $try_link = CGI::a({href=>$self->systemLink(
		$urlpath->newFromModule("WeBWorK::ContentGenerator::$module",
			%pathArgs ),
			params =>{
				effectiveUser => scalar($self->r->param('user')),
				editMode => "SetMaker",
				problemSeed=> $problem_seed,
				sourceFilePath => "$sourceFileName",
				displayMode => $displayMode,
			}
		), target=>"WW_View"}, "Try it");

	print CGI::div({-class=>"problem myProblem", -draggable=>"true", -href=>"#", -id=>("$cnt".'myset')},
		CGI::p({},"File name: $sourceFileName "), 
  	CGI::p({}, $edit_link, " ", $try_link),
		CGI::p(CGI::checkbox((%delete_box_data),-override=>1)),
		CGI::hidden(-id=>"filetrial$cnt".'myset', -name=>"mysetfiletrial$cnt", -default=>$sourceFileName,-override=>1),
		CGI::p($problem_output),
	);
}

sub clear_default {
	my $r = shift;
	my $param = shift;
	my $default = shift;
	my $newvalue = $r->param($param) || '';
	$newvalue = '' if($newvalue eq $default);
	$r->param($param, $newvalue);
}

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	## For all cases, lets set some things
	$self->{error}=0;
	my $ce = $r->ce;
	my $db = $r->db;
	
    $self->{current_myset_set} = $r->param('myset_sets');
    if (not defined($self->{current_myset_set}) 
		or $self->{current_myset_set} eq "Select a Homework Set"
		or $self->{current_myset_set} eq NO_LOCAL_SET_STRING) {
      my @all_db_sets = $db->listGlobalSets;
	    @all_db_sets = sortByName(undef, @all_db_sets);
	    $self->{current_myset_set} = shift(@all_db_sets);
	  }
	
	my $userName = $r->param('user');
	my $user = $db->getUser($userName); # checked 
	die "record for user $userName (real user) does not exist." 
		unless defined $user;
	my $authz = $r->authz;
	unless ($authz->hasPermissions($userName, "modify_problem_sets")) {
		return(""); # Error message already produced in the body
	}

	my @myset_files=();

  #I'm worried this will break something
  my $default_set = $self->{current_myset_set};
	  #debug("set_to_display is $default_set");
	  if (not defined($default_set) 
  		or $default_set eq "Select a Homework Set"
  		or $default_set eq NO_LOCAL_SET_STRING) {
  		$self->addbadmessage("You need to select a set from this course to view.");
  	} else {
  		# DBFIXME don't use ID list, use an iterator
  		my @problemList = $db->listGlobalProblems($default_set);
  		my $problem;
  		@myset_files=();
  		for $problem (@problemList) {
  			my $problemRecord = $db->getGlobalProblem($default_set, $problem); # checked
  			die "global $problem for set $default_set not found." unless
  				$problemRecord;
  			push @myset_files, $problemRecord->source_file;
  
  		}
  	  #@myset_files = sortByName(undef,@myset_files);
  	}
	############# Now store data in self for retreival by body

	$self->{myset_files} = \@myset_files;
}


sub title {
	return "Library Browser v2";
}

# hide view options panel since it distracts from SetMaker's built-in view options
sub options {
	return "";
}

sub head {

  return "";
}

sub body {
	my ($self) = @_;

	my $r = $self->r;
	my $ce = $r->ce;		# course environment
	my $db = $r->db;		# database
	my $j;			# garden variety counter

	my $userName = $r->param('user');

	my $user = $db->getUser($userName); # checked
	die "record for user $userName (real user) does not exist."
		unless defined $user;

	### Check that this is a professor
	my $authz = $r->authz;
	unless ($authz->hasPermissions($userName, "modify_problem_sets")) {
		print "User $userName returned " . 
			$authz->hasPermissions($user, "modify_problem_sets") . 
	" for permission";
		return(CGI::div({class=>'ResultsWithError'},
		CGI::em("You are not authorized to access the Instructor tools.")));
	}

	my $showHints = $r->param('showHints');
	my $showSolutions = $r->param('showSolutions');
	
	##########	Extract information computed in pre_header_initialize


	my @myset_files =@{$self->{myset_files}};

  my $displayModePlaceholder;
	if (not defined($r->param('mydisplayMode'))){
	  $displayModePlaceholder = "images";
	}
	else{
	  $displayModePlaceholder = $r->param('mydisplayMode');
	}

	my @myset_html;

  @myset_html = renderProblems(
	  r=> $r,
	  user => $user,
		problem_list => [@myset_files],
		displayMode => $displayModePlaceholder,
		showHints => $showHints,
		showSolutions => $showSolutions,
  );
  
  my $jj;
	print '<div id="mysets_problems" class="problemList">';
	  for ($jj=0; $jj<scalar(@myset_html); $jj++) { 
	    $myset_files[$jj] =~ s|^$ce->{courseDirs}->{templates}/?||;
	    $self->make_myset_data_row($myset_files[$jj], $myset_html[$jj], $jj+1); 
	  }
	print '</div>';
	

	return "";	
}

=head1 AUTHOR

Written by John Jones, jj (at) asu.edu.
Edited by David Gage

=cut

1;
