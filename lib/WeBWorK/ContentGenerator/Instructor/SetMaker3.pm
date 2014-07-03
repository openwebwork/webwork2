################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/SetMaker.pm,v 1.85 2008/07/01 13:18:52 glarose Exp $
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


package WeBWorK::ContentGenerator::Instructor::SetMaker3;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SetMaker3 - Make homework sets.

=cut

use strict;
use warnings;


#use CGI qw(-nosticky);
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Form;
use WeBWorK::Utils qw(readDirectory max sortByName);
use WeBWorK::Utils::Tasks qw(renderProblems);
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
my %problib;	## This is configured in defaults.config
my %ignoredir = (
	'.' => 1, '..' => 1, 'Library' => 1, 'CVS' => 1, 'tmpEdit' => 1,
	'headers' => 1, 'macros' => 1, 'email' => 1, '.svn' => 1,
);

# template method
sub templateName {
	return "lbtwo";
}

sub prepare_activity_entry {
	my $self=shift;
	my $r = $self->r;
	my $user = $self->r->param('user') || 'NO_USER';
	return("In SetMaker3 as user $user");
}



sub title {
	return "Library Browser v3";
}

# hide view options panel since it distracts from SetMaker's built-in view options
sub options {
	return "";
}

sub head {
	my ($self) = @_;
	my $ce = $self->r->ce;
  my $webwork_htdocs_url = $ce->{webwork_htdocs_url};
  print qq!<link rel="stylesheet" href="$webwork_htdocs_url/js/components/font-awesome/css/font-awesome.css"/>!;
  #print qq!<script src="$webwork_htdocs_url/js/components/jquery/jquery.js"></script>!;
  # print qq!<script src="$webwork_htdocs_url/js/components/underscore/underscore.js"></script>!;
  # print qq!<script src="$webwork_htdocs_url/js/components/backbone/backbone.js"></script>!;
  # print qq!<script src="$webwork_htdocs_url/js/components/jquery-ui/ui/jquery-ui.js"></script>!;
  # print qq!<script src="$webwork_htdocs_url/js/legacy/vendor/ui.tabs.closable.js"></script>!;
  # print qq!<script src="$webwork_htdocs_url/js/apps/LibraryBrowser/webwork.js"></script>!;
  # print qq!<script src="$webwork_htdocs_url/js/apps/LibraryBrowser/library_browser.js"></script>!;
  # print qq!<script src="$webwork_htdocs_url/js/legacy/vendor/modernizr-2.0.6.js"></script>!;
    print qq!<script data-main="$webwork_htdocs_url/js/apps/LibraryBrowser/library_browser" src="$webwork_htdocs_url/js/vendor/requirejs/require.js"></script>!;

  print qq!<link rel="stylesheet" type="text/css" href="$webwork_htdocs_url/css/library_browser.css" />!;
  print qq!<link href="$webwork_htdocs_url/css/vendor/jquery-ui-themes-1.10.3/themes/smoothness/jquery-ui.css" rel="stylesheet" type="text/css"/>!;
  #print qq!<script>window.addEventListener("load", setup, false);</script>!;
  return "";
}

sub body {
	my ($self) = @_;

	my $r = $self->r;
	my $urlpath =$r->urlpath;
	my $courseID = $urlpath->arg("courseID");

  ##########  Loading Screen
  #print '<div id="loading"></div>';
  
  #big wrapper div that will hopefully fix theme issues
  
  my $template = HTML::Template->new(filename => $WeBWorK::Constants::WEBWORK_DIRECTORY . '/htdocs/html-templates/library-browser.html');  
  print $template->output(); 

  print $self->hidden_authen_fields;
  print CGI::hidden({id=>'hidden_courseID',name=>'courseID',default=>$courseID });



	return "";	
}

=head1 AUTHOR

Written by John Jones, jj (at) asu.edu.
Edited by David Gage

=cut

1;
