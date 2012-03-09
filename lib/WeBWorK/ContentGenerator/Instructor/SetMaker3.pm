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
my %problib;	## filled in in global.conf
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
  print '<script src="/webwork2_files/js/jquery-1.7.min.js"></script>';
  print '<script src="/webwork2_files/js/jquery-ui-1.8.16.custom.min.js"></script>';
  print '<script src="/webwork2_files/js/ui.tabs.closable.min.js"></script>';
  
  print '<script src="/webwork2_files/js/dnd.js"></script>';
  #print '<script src="/webwork2_files/js/problem_grid.js"></script>';
  #print '<script src="/webwork2_files/js/form_builder.js"></script>';
  print '<script src="/webwork2_files/js/library_browser.js"></script>';
  print '<script src="/webwork2_files/js/modernizr-2.0.6.js"></script>';
  #my ($self) = @_;
  #my $r = $self->r;
  #start a timer to save people's stuff idk if people want this
  #print "<script> setInterval('saveChanges(\"mainform\", \"".$r->uri."\")', 680000); </script>";
  #print '<link rel="stylesheet" type="text/css" href="/webwork2_files/css/setmaker3.css" />';
  print '<link href="/webwork2_files/css/ui-lightness/jquery-ui-1.8.16.custom.css" rel="stylesheet" type="text/css"/>';
  print '<link rel="stylesheet" type="text/css" href="/webwork2_files/css/library_browser.css" />';
  #print '<script>window.addEventListener("load", setup, false);</script>';
  return "";
}

sub body {
	my ($self) = @_;

	my $r = $self->r;
	my $urlpath =$r->urlpath;
	my $courseID = $urlpath->arg("courseID");

  ##########  Loading Screen
  #print '<div id="loading"></div>';
  
  ##########  toolbar
  print '<div id="toolbar">';
    print '<span id="messages"></span>';
  	print '<span class="actions">
	             <button class="button" type="button" id="undo_button">Undo</button>
	             <button class="button" type="button" id="redo_button">Redo</button>
	             <button class="button" type="button" id="delete_problem">Remove Selected</button>
	             <a class="button" href="http://bugs.webwork.maa.org/">BUGS!</a>
	       </span>';
  print '</div>';
  
  #big wrapper div that will hopefully fix theme issues
  print '<div id="app_box">';
    
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
	
	  	print '<div class="break"></div>';
	  	print '<table>';
		print '<tr><td><b>Library directories:</b></td><td><span id="library_list_box"></span><button class="button" id="load_problems" type="button">Load Problems</button></td>';
		print '<tr><td><b>Library search:</b></td><td><span id="library_search_box"><select id="subjectBox"></select><select id="chaptersBox"></select><select id="sectionsBox"></select><select  style="display:none;"  id="textbooksBox"></select><select style="display:none;" id="textChaptersBox"></select><select style="display:none;" id="textSectionsBox"></select><input type="text" id="keywordsBox"  style="display:none;"  placeholder="keywords"></input><button class="button" id="run_search" type="button">Search</button><span></td>';
		print '</table>';
		###########################################
			      # Library repository controls
    	###########################################
	  		#print '<span class="js_action_span" onclick="selectAll();">all</span>',
             #    '<span style="margin-left:10px;" class="js_action_span" onclick="selectNone();">none</span>';
	  		    ###########################################

	    print '<div id="problem_container">';
	      print '<div id="dialog">',
	      			'<input type="text" id="dialog_text"></input>',
	      			'<button type="button" id="create_set">Create Set</button>',
	      		'</div>';
	      print '<div id="problem_sets_container">';
	    	print '<b>Target Sets</b>';
			print '<ul id="my_sets_list">';
				print '<li id="new_problem_set">New Problem Set</li>';
		    print '</ul>';
		  print '</div>';
		  #print '<div id="size_slider"><p>||</p></div>';
		  print '<div id="problems_container">';
		    #List of tabs
		  	print '<ul>',
        			'<li id="library_link"><a href="#library_tab"><span>Library</span></a></li>',
    			  '</ul>';
    	    print '<div id="library_tab">';
		    	print '<h1>Problems</h1>';
	        	########## Now print problems
	        	print '<ul id="library_list">';
	          
	        	print '</ul>';
#<button type="button" onclick="increaseLibAcross();">+</button><span id="libAcross">4</span><button type="button" onclick="decreaseLibAcross();">-</button><span> problems across</span>
            	print '<p><select id="prob_per_page"><option value=10>10</option><option value=20>20</option><option value=30>30</option><option value=40>40</option><option value=50>50</option></select><button type="button" disabled=true id="prevList">Previous</button><button disabled=true type="button" id="nextList">Next</button></p>';#might be a better way to do the perpage
	      	print '</div>';
	      print '</div>';
	        ########## Finish things off
	   	print '</div>';
	print '<div style="clear:both;"></div>';
  print '</div>';
  print $self->hidden_authen_fields;
  print CGI::hidden({id=>'hidden_courseID',name=>'courseID',default=>$courseID });
	return "";	
}

=head1 AUTHOR

Written by John Jones, jj (at) asu.edu.
Edited by David Gage

=cut

1;
