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

use Test::More qw(no_plan);
use Test::WWW::Selenium;
use Test::Exception;
use Time::HiRes qw(sleep);
use Selenium::Utilities;


my $sel = Test::WWW::Selenium->new( host => "localhost", 
                                    port => 80, 
                                    browser => "*chrome", 
                                    browser_url => "http://localhost/" );

$sel->open_ok("/webwork2/");
$sel->click_ok("link=Course Administration");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("id=uname", "admin");
$sel->type_ok("id=pswd", "admin");
$sel->click_ok("id=none");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Add Course");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("name=add_courseID", "MyTestCourse");
$sel->type_ok("name=add_courseTitle", "Test Course");
$sel->type_ok("name=add_courseInstitution", "Test University");
$sel->type_ok("name=add_initial_userID", "testprof");
$sel->type_ok("name=add_initial_password", "proof");
$sel->type_ok("name=add_initial_confirmPassword", "proof");
$sel->type_ok("name=add_initial_firstName", "Test");
$sel->type_ok("name=add_initial_lastName", "Prof");
$sel->type_ok("name=add_initial_email", "prof\@prof.univ");
$sel->click_ok("name=add_course");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=div.Warnings"));
$sel->text_is("css=div.ResultsWithoutError > p", "Successfully created the course MyTestCourse");
$sel->click_ok("link=Log into MyTestCourse");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("id=uname", "admin");
$sel->type_ok("id=pswd", "admin");
$sel->click_ok("id=none");
$sel->wait_for_page_to_load_ok("30000");
$sel->title_is("WeBWorK : MyTestCourse");
ok(not $sel->is_element_present("css=div.Warnings"));
$sel->text_is("css=h1.page-title", "Test Course");
$sel->click_ok("link=Classlist Editor");
$sel->wait_for_page_to_load_ok("30000");
$sel->text_is("link=testprof", "testprof");
$sel->text_is("link=admin", "admin");
$sel->click_ok("css=#loginstatus>a");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=webwork");
$sel->wait_for_page_to_load_ok("30000");
$sel->text_is("link=MyTestCourse", "MyTestCourse");
