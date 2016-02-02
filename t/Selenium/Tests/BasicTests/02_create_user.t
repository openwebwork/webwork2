#!/usr/bin/perl

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

use strict;
use warnings;

BEGIN{ die('You need to set the WEBWORK_ROOT environment variable.\n')
	   unless($ENV{WEBWORK_ROOT});}
use lib "$ENV{WEBWORK_ROOT}/t";

use Test::More tests => 39;
use Test::WWW::Selenium;
use Test::Exception;
use Time::HiRes qw(sleep);
use Selenium::Utilities;


my $sel = Test::WWW::Selenium->new( host => "localhost", 
                                    port => 4444, 
                                    browser => "*firefox", 
                                    browser_url => "http://localhost/" );


create_course($sel);

$sel->open_ok("/webwork2/TestCourseX");
$sel->click_ok("link=Classlist Editor");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->click_ok("link=Add");
$sel->click_ok("id=take_action");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("name=last_name_1", "Test");
$sel->type_ok("name=first_name_1", "Student");
$sel->type_ok("name=student_id_1", "student");
$sel->type_ok("name=new_user_id_1", "teststud");
$sel->type_ok("name=email_address_1", "test\@email.com");
$sel->type_ok("name=section_1", "2");
$sel->type_ok("name=recitation_1", "3");
$sel->click_ok("name=addStudents");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
ok($sel->get_text("id=page_body") =~ /Entered student: Test, Student, login\/studentID: teststud\/student, email: test\@email\.com, section: 2/);
$sel->click_ok("link=Classlist Editor");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("//table[\@id='classlist-table']/tbody/tr[3]/td[2]/div/a", "teststud");
$sel->text_is("//table[\@id='classlist-table']/tbody/tr[3]/td[5]/div", "Student");
$sel->text_is("//table[\@id='classlist-table']/tbody/tr[3]/td[6]/div", "Test");
$sel->text_is("//table[\@id='classlist-table']/tbody/tr[3]/td[9]/div", "Enrolled");
$sel->text_is("//table[\@id='classlist-table']/tbody/tr[3]/td[10]/div", "2");
$sel->text_is("//table[\@id='classlist-table']/tbody/tr[3]/td[13]/div", "student");
$sel->text_is("//table[\@id='classlist-table']/tbody/tr[2]/td[13]/div", "admin");
$sel->click_ok("link=Log Out signout");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("name=submit");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("id=uname", "teststud");
$sel->type_ok("id=pswd", "student");
$sel->click_ok("id=none");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("id=page-title", "Test Course");
$sel->text_is("id=loginstatus", "Logged in as teststud. Log Out signout");


delete_course($sel);
