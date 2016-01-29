################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK.pm,v 1.104 2010/05/15 18:44:26 gage Exp $
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

package Selenium::Utilities;

=head1 NAME

Selenium::Utilities - Contains "rollup" utilities for selenium tests.  

=over

=cut

use strict;
use warnings;

BEGIN{ die('You need to set the WEBWORK_ROOT environment variable.\n')
	   unless($ENV{WEBWORK_ROOT});}
use lib "$ENV{WEBWORK_ROOT}/t";

use Exporter 'import';
use WWW::Selenium;

use constant DEFAULT_COURSE_ID => "TestCourse";
use constant DEFAULT_SET_ID => "TestSet";


our @EXPORT= qw(
	     create_course
	     delete_course
	     log_into_course
	     create_set
	     import_set
	     delete_set
	     create_problem
	     edit_problem
	     create_student
	   );

=item create_course

This creates a course.  The id, name and institution default to
TestCourse; Test Course; and Test University but can be passed as
paramters as well. It expects the Selenium object to be passed in as the
first parameter.

create_course($sel, courseID=>"TestCourse",
                    courseTitle=>"Test Course",
                    courseInstitution=>"Test University");

=cut

sub create_course {
  my $sel = shift;
  # rest of the options are in hash form
  my %options = @_;
  
  $sel->open("/webwork2/admin");
  $sel->wait_for_page_to_load("30000");
  $sel->type("id=uname", "admin");
  $sel->type("id=pswd", "admin");
  $sel->click("id=none");
  $sel->wait_for_page_to_load("30000");
  $sel->click("link=Add Course");
  $sel->wait_for_page_to_load("30000");
  $sel->type("name=add_courseID", $options{courseID} // DEFAULT_COURSE_ID);
  $sel->type("name=add_courseTitle", $options{courseTitle} // "Test Course");
  $sel->type("name=add_courseInstitution", $options{courseInstitution} // "Test University");
  $sel->click("name=add_course");
  $sel->wait_for_page_to_load("30000");

  log_into_course($sel);
  
}

=item delete_course

This deletes a course. The ID of the course is assumed to be TestCourse
unless something else is passed in as a parameter.  It is assumed that the 
selenium object will be passed to the function 

delete_course($sel, courseID=>"TestCourse");

=cut

sub delete_course {
  my $sel = shift;
  my %options = @_;

  my $courseID = $options{courseID} // DEFAULT_COURSE_ID;
  
  $sel->open("/webwork2/admin");
  $sel->wait_for_page_to_load("30000");
  if ($sel->is_element_present("id=uname")) {
      $sel->type("id=uname", "admin");
      $sel->type("id=pswd", "admin");
      $sel->click("id=none");
      $sel->wait_for_page_to_load("30000");
  }
  $sel->click("link=Delete Course");
  $sel->wait_for_page_to_load("30000");
  $sel->select("name=delete_courseID", "label=$courseID (visible :: *)");
  $sel->click("xpath=(//input[\@name='delete_course'])[2]");
  $sel->wait_for_page_to_load("30000");
  $sel->click("name=confirm_delete_course");
  $sel->wait_for_page_to_load("30000");
 


}

=item log_into_course

This logs into a test course.  By default the course id is TestCourse and the 
username and password are admin/admin.  These can be overriden as options

log_into_course($sel, courseID=>"TestCourse",
                      userID=>"admin", 
                      password=>"admin");

=cut

sub log_into_course {
  my $sel = shift;
  my %options = @_;

  my $courseID = $options{courseID} // DEFAULT_COURSE_ID;

  $sel->open("/webwork2/$courseID");
  $sel->wait_for_page_to_load("30000");
  $sel->type("id=uname", $options{userID} // "admin");
  $sel->type("id=pswd", $options{password} // "admin");
  $sel->click("id=none");
  $sel->wait_for_page_to_load("30000");

}

=item create_set

This creates a set.  If the parameter createCourse is passed then a course
will be created with any of the appropriate parameters.  The set will
be called TestSet unless a setID is passed. If a course is not created
from scratch then the routine assumes that you are currently logged into 
a course.

create_set($sel, createCourse => 0,
                 setID => "TestCourse",
                 openDate => "12/01/2001 at 1:00pm",
                 dueDate => "12/01/2025 at 1:00pm"
                 answerDate => "12/01/2025 at 1:00pm"
                 );

=cut

sub create_set {
  my $sel = shift;
  my %options = @_;
  my $courseID = $options{courseID} // DEFAULT_COURSE_ID;
  my $setID = $options{setID} // DEFAULT_SET_ID;

  if ($options{createCourse}) {
    warn "Unable to create course" unless create_course($sel,%options);
  }

  $sel->open("/webwork2/$courseID/instructor/sets2");
  $sel->wait_for_page_to_load("30000");
  $sel->click("link=Create");
  $sel->type("id=create_text", $setID );
  $sel->click("id=take_action");
  $sel->check("id=${setID}_id");
  $sel->click("link=Edit");
  $sel->click("id=take_action");
  $sel->wait_for_page_to_load("30000");
  $sel->type("id=set.${setID}.open_date_id", $options{openDate} // "12/01/2001 at 01:00pm");
  $sel->type("id=set.${setID}.due_date_id", $options{dueDate} // "12/01/2025 at 01:00pm");
  $sel->type("id=set.${setID}.answer_date_id", $options{setDate} // "12/01/2025 at 01:00pm");
  $sel->click("id=take_action");
  $sel->wait_for_page_to_load("30000");


}

=item import_set

This will import a set.  It imports the Demo set by default, but the id of 
the set can be specified by setting importSetDef.  You can also specify 
whether or not a new course needs to be created.  If no new course is created it is assumed you are logged into a course. 

import_set($sel, importSetDef=>"setDemo.def",
                 createCourse=>0);

=cut

sub import_set {
  my $sel = shift;
  my %options = @_;
  my $courseID = $options{courseID} //  DEFAULT_COURSE_ID;
  my $setDef = $options{importSetDef} // "setDemo.def";
  my $setID = $setDef;
  $setID =~ s/^set(.*)\.def$/$1/;
  

  if ($options{createCourse}) {
    warn "Unable to create course" unless create_course($sel,%options);
  }

  $sel->open("/webwork2/$courseID/instructor/sets2");
  $sel->wait_for_page_to_load("30000");
  $sel->click("link=Import");
  $sel->select("id=import_source_select", "label=$setDef");
  $sel->click("id=take_action");
  $sel->wait_for_page_to_load("30000");
  $sel->check("id=${setID}_id");
  $sel->click("link=Edit");
  $sel->click("id=take_action");
  $sel->wait_for_page_to_load("30000");
  $sel->type("id=set.${setID}.open_date_id", $options{openDate} // "12/01/2001 at 01:00pm");
  $sel->type("id=set.${setID}.due_date_id", $options{dueDate} // "12/01/2025 at 01:00pm");
  $sel->type("id=set.${setID}.answer_date_id", $options{setDate} // "12/01/2025 at 01:00pm");
  $sel->click("id=take_action");
  $sel->wait_for_page_to_load("30000");


}

=item delete_set

This method deletes a set.  It assumes you are logged into the course and 
that the id of the set is TestSet unless otherwise specified. 

delete_set($sel, setID=>"TestSet");

=cut

sub delete_set {
  my $sel = shift;
  my %options = @_;
  my $courseID = $options{courseID} // DEFAULT_COURSE_ID;
  my $setID = $options{setID} // DEFAULT_SET_ID;

  $sel->open("/webwork2/$courseID/instructor/sets2");
  $sel->check("id=${setID}_id");
  $sel->click("link=Delete");
  $sel->select("id=delete_select", "label=selected sets");
  $sel->click("id=take_action");
  $sel->wait_for_page_to_load("30000");

}

=item create_problem

This method creates a problem in a set.  The set is alwasy blank and
the problem is always the first problem.  You can set the setID as a 
parameter as well as if a course should be created.

create_problem($sel, createCourse => 0,
                     setID => "TestSet");

=cut

sub create_problem {
  my $sel = shift;
  my %options = @_;
  my $courseID = $options{courseID} // DEFAULT_COURSE_ID;
  my $setID = $options{setID} // DEFAULT_SET_ID;

  warn "Unable to create set" unless create_set($sel,%options);
  
  $sel->open("/webwork2/$courseID/instructor/sets2/$setID");
  $sel->wait_for_page_to_load("30000");
  $sel->click("name=add_blank_problem");
  $sel->click("id=submit_changes_2");
  $sel->wait_for_page_to_load("30000");

  warn "Unable to create problem!" unless $sel->text_is("css=div.ResultsWithoutError", "Added set${setID}/blankProblem.pg to $setID *");

  $sel->open("/webwork2/$courseID/instructor/pgProblemEditor2/${setID}/1");
  $sel->wait_for_page_to_load("30000");
  $sel->click("link=NewVersion");
  $sel->type("id=action_save_as_target_file_id", "set${setID}/testProblem.pg");
  $sel->click("id=submit_button_id");
  $sel->wait_for_page_to_load("30000");


}

=item edit_problem

This edits the first problem of a set.  You can specify if the problem
needs to be created first.  You can also specify the see of the problem,
although it will default to 1234 for consistancy.  

This method will leave you on the pgProblemEditor2 page with your problem
open and open in a new window unchecked

edit_problem($sel, createProblem => 0,
                   seed => 1234);

=cut

sub edit_problem {
  my $sel = shift;
  my %options = @_;
  my $courseID = $options{courseID} // DEFAULT_COURSE_ID;
  my $setID = $options{setID} // DEFAULT_SET_ID;

  if ($options{createProblem}) {
    warn("Unable to create problem") unless create_problem($sel,%options);
  }

  $sel->open("/webwork2/$courseID/instructor/pgProblemEditor2/${setID}/1");
  $sel->wait_for_page_to_load("30000");
  $sel->type("id=action_view_seed_id", "$options{seed}" // "1234");
  $sel->uncheck("id=newWindow");

}


=item create_student
  This method creates a student user.  The username and password can be specified, as can the option to create the course first.  

create_student($sel, createCourse=>0,
                     userID=>"teststud",
                     studentID=>"teststud", #also initial passwd
                     firstName=>"Test",
                     lastName=>"Student");

=cut

sub create_student {
  my $sel = shift;
  my %options = @_;
  my $courseID = $options{courseID} //  DEFAULT_COURSE_ID;

  if ($options{createCourse}) {
    warn "Unable to create course" unless create_course($sel,%options);
  }

  $sel->open("/webwork2/$courseID/instructor/users2");
  $sel->click("link=Add");
  $sel->click("id=take_action");
  $sel->wait_for_page_to_load("30000");
  $sel->type("name=last_name_1", $options{firstName} // "Student");
  $sel->type("name=first_name_1", $options{lastName} // "Test");
  $sel->type("name=student_id_1", $options{studentID} // "teststud");
  $sel->type("name=new_user_id_1", $options{userID} // "teststud");
  $sel->click("name=addStudents");
  $sel->wait_for_page_to_load("30000");

}

=back

=cut

1;
