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
  print qq!<link rel="stylesheet" href="$webwork_htdocs_url/js/lib/vendor/FontAwesome/css/font-awesome.css">!;

  print qq!<script src="$webwork_htdocs_url/js/jquery-ui-1.8.16.custom.min.js"></script>!;
  print qq!<script src="$webwork_htdocs_url/js/lib/vendor/jquery.ui.touch-punch.js"></script>!;
  print qq!<script src="$webwork_htdocs_url/js/lib/vendor/ui.tabs.closable.js"></script>!;

  print qq!<script src="$webwork_htdocs_url/js/lib/vendor/json2.js"></script>!;
  print qq!<script src="$webwork_htdocs_url/js/lib/vendor/underscore.js"></script>!;
  print qq!<script src="$webwork_htdocs_url/js/lib/vendor/backbone.js"></script>!;


  print qq!<script src="$webwork_htdocs_url/js/lib/webwork/WeBWorK.js"></script>!;
  print qq!<script src="$webwork_htdocs_url/js/lib/webwork/teacher/teacher.js"></script>!;
  print qq!<script src="$webwork_htdocs_url/js/lib/webwork/teacher/Problem.js"></script>!;
  print qq!<script src="$webwork_htdocs_url/js/lib/webwork/teacher/Set.js"></script>!;
  print qq!<script src="$webwork_htdocs_url/js/lib/webwork/teacher/Library.js"></script>!;
  print qq!<script src="$webwork_htdocs_url/js/lib/webwork/teacher/Browse.js"></script>!;
  print qq!<script src="$webwork_htdocs_url/js/apps/LibraryBrowser/library_browser.js"></script>!;
  #print qq!<script src="$webwork_htdocs_url/js/problem_grid.js"></script>!;
  #print qq!<script src="$webwork_htdocs_url/js/form_builder.js"></script>!;

  print qq!<script src="$webwork_htdocs_url/js/modernizr-2.0.6.js"></script>!;
  #my ($self) = @_;
  #my $r = $self->r;
  #start a timer to save people's stuff idk if people want this
  #print "<script> setInterval('saveChanges(\"mainform\", \"".$r->uri."\")', 680000); </script>";
  #print qq!<link rel="stylesheet" type="text/css" href="$webwork_htdocs_url/css/setmaker3.css" />!;

  print qq!<link rel="stylesheet" type="text/css" href="$webwork_htdocs_url/css/library_browser.css" />!;

  print qq!<link href="$webwork_htdocs_url/css/ui-lightness/jquery-ui-1.8.16.custom.css" rel="stylesheet" type="text/css"/>!;
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
  print '<div id="app_box" class="container-fluid">';
    ##########  toolbar
     ##print '<div class="toolbar">';
     ##

     ## print '</div>';

    print '<div class="navbar">',
      '<div class="navbar-inner">',
        '<div class="container">',
            '<ul class="nav">',
                '<li>
                    <div>
                    <span id="CardCatalog">
                        <!--Gonna put the lists of libraries and sub-libraries here-->
                        
                    </span>
                     <button class="btn btn-small" id="load_problems">Load Problems</button>                   
                    
                    <p id="Browser">
                        <!--Subject, textbook, and so on browser-->
                        
                    </p>
                    </div>
                </li>',
            '</ul>',
            '<ul class="nav pull-right">',
                '<li><button class="btn btn-small" id="undo_button">Undo</button></li>',
                '<li><button class="btn btn-small" id="redo_button">Redo</button></li>',
                '<li><a class="pull-right" href="http://github.com/whytheplatypus/webwork2/issues" target="_blank">BUGS!</a></li>',
            '</ul>',

        '</div>',
      '</div>',
    '</div>';


	##########	Top part
	#print '<button onclick="fullWindowMode();">Full Screen</button>';
	#print '<button id="gridifyButton" onclick="gridify();">Gridify!!</button>';
	#print '<span>Hover Magnification: <button type="button" onclick="increaseMagnification();">+</button><span id="magnification">1</span><button type="button" onclick="decreaseMagnification();">-</button></span></span>';
	#print '<button type="button" onclick="toggleHelp(this);" value="false">?</button>';
	#print '<div id="help" style="display:none;position:absolute;z-index:1500;background:white;" class="shadowed">',
	#			  '<h1>What can you do?</h1>',
	#				'<p>Drag a problem from the library to the target set to add.</p>',
	#				'<p>Drag a problem set off the target set to remove.</p>',
	#				'<p>If you have a local problem set in the library<br/>you can shift drag to move a problem from there to the target set.<br/>This will remove the problem from one set and add it to the other</p>',
	#				'<h1>Legend</h1>',
	#				'<p><div class="problem" style="width:16px;height:16px;border:solid 1px;"></div><span>Normal problem</span></p>',
	#				'<p><div class="used" style="width:16px;height:16px;border:solid 1px;"></div><span>Problem already in set</span></p>',
	#				'<p><div class="libProblem" style="width:16px;height:16px;border:solid 1px;"></div><span>Problem will be added to target on next update</span></p>',
	#				'<p><div class="removedProblem" style="width:16px;height:16px;border:solid 1px;"></div><span>Problem will be deleted from target on next update</span></p>',
	#				'<p><div class="ResultsWithError" style="width:16px;height:16px;border:solid 1px;"></div><span>Errors</span></p>',
	#'</div>';
				#'<p>In the target set you can drag problems to reorder them.<br/>The problem will be placed in front of the one you drop it on,<br/>or at the end of the list if you drop it on an empty space in the table.</p>',

	  	#print '<table>';
		#print '<tr><td><b>Library directories:</b></td><td></td>';
		#print '<tr><td><b>Library search:</b></td><td><span id="library_search_box"><select id="subjectBox"></select><select id="chaptersBox"></select><select id="sectionsBox"></select><select  style="display:none;"  id="textbooksBox"></select><select style="display:none;" id="textChaptersBox"></select><select style="display:none;" id="textSectionsBox"></select><input type="text" id="keywordsBox"  style="display:none;"  placeholder="keywords"></input><button class="button" id="run_search" type="button">Search</button><span></td>';
		#print '</table>';
		###########################################
			      # Library repository controls
    	###########################################
	  		#print '<span class="js_action_span" onclick="selectAll();">all</span>',
             #    '<span style="margin-left:10px;" class="js_action_span" onclick="selectNone();">none</span>';
	  		    ###########################################

	    print '<div id="problem_container" class="row-fluid">';

	      print '<div id="homework_sets_container" class="span2">';
	    	print '<b>Homework Sets</b>';
			print '<!--homework sets go here-->'; #could be a problem with multiple appends (can I use a replace instead?)
		  print '</div>';
		  #print '<div id="size_slider"><p>||</p></div>';
		  print '<div id="problems_container" class="span10">';
		    #List of tabs
		  	print '<ul>',
        			#'<li id="library_link"><a href="#library_tab"><span>Library</span></a></li>',
    			  '</ul>';
    	    #print '<div id="library_tab">',
		     #       '</div>';
	      print '</div>';
	        ########## Finish things off
	   	print '</div>';
	   	print '<div>',
            '<input type="text" id="dialog_text" placeholder="default set"></input>',
        	'<button class="btn btn-small" id="create_set">Create Set</button>',
        '</div>';
  print '</div>';
  print $self->hidden_authen_fields;
  print CGI::hidden({id=>'hidden_courseID',name=>'courseID',default=>$courseID });


  print '<script type="text/template", id="problem-template">',
        '<%if(!remove_display){ %><div class="handle"><i class="icon-resize-vertical icon-large"></i></div>',
            '<button type="button" class="remove">X</button><%}%>', #replace with twitter bootstrap icons? yeah font awesome :)
        '    <div class="problem" data-path="<%= path %>" ><%= data %></div>',
        '</script>';

  print '<script type="text/template", id="setList-template">',
            #'<li class="new_problem_set">New Problem Set</li>',

          '</script>';

  print '<script type="text/template", id="setName-template">',
              '<a data-problem_count=<%= problem_count %>><%= name %><span class="problem_count" style="float:right"><%= problem_count %></style></a>',#could do this with an :after css tag instead..it would be better
         '</script>';

  print '<script type="text/template", id="set-template">',
           '<h1>Problems</h1>',
           '<ul class="list">',
           '</ul>',
        '</script>';

  print '<script type="text/template", id="LibraryList-template">',
             '<select  class="<%= name %> list">',
             '<option value=null>Pick a Library</option>',
             '</select>',
             '<span class="<%= name %> children"></span>',
          '</script>';

  print '<script type="text/template", id="BrowseList-template">',
             '<select  id="library_subject" class="list">',
             '<option value=null>Subject</option>',
             '<% _.each(library_subjects, function(name) { %> <option value="<%= name %>" <% if(name == library_subject){ %> selected="selected" <% } %> ><%= name %></option> <% }); %>',
             '</select>',
             '<select  id="library_chapter" class="list">',
             '<option value=null>Chapter</option>',
             '<% _.each(library_chapters, function(name) { %> <option value="<%= name %>" <% if(name == library_chapter){ %> selected="selected" <% } %> ><%= name %></option> <% }); %>',
             '</select>',
             '<select  id="library_section" class="list">',
             '<option value=null>Section</option>',
             '<% _.each(library_sections, function(name) { %> <option value="<%= name %>"  <% if(name == library_section){ %> selected="selected" <% } %>  ><%= name %></option> <% }); %>',
             '</select>',
             '<button class="btn btn-small load_browse_problems">Load Problems</button>',

          '</script>';

  print '<script type="text/template", id="Library-template">',
            '<h1>Problems</h1>',
       	    ########## Now print problems
       	    '<ul class="list">',

       	    '</ul>',
            #<button type="button" onclick="increaseLibAcross();">+</button><span id="libAcross">4</span><button type="button" onclick="decreaseLibAcross();">-</button><span> problems across</span>
            '<span class="next_group" style="display:<%= enough_problems %>;">Load the next <%= group_size %> problems.</span>',
       '</script>';

	return "";	
}

=head1 AUTHOR

Written by John Jones, jj (at) asu.edu.
Edited by David Gage

=cut

1;
