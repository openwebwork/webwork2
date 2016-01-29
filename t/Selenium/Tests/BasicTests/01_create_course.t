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

use Test::More tests => 29;
use Test::WWW::Selenium;
use Test::Exception;
use Time::HiRes qw(sleep);
use Selenium::Utilities;


my $sel = Test::WWW::Selenium->new( host => "localhost", 
                                    port => 4444, 
                                    browser => "*firefox", 
                                    browser_url => "http://localhost/" );


$sel->open_ok("/webwork2/admin");
$sel->title_is("WeBWorK : Course Administration");
ok(not $sel->is_element_present("css=#warnings"));
$sel->type_ok("id=uname", "admin");
$sel->type_ok("id=pswd", "admin");
$sel->click_ok("id=none");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Add Course");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("name=add_courseID", "TestCourse");
$sel->type_ok("name=add_courseTitle", "Test Course");
$sel->type_ok("name=add_courseInstitution", "Test University");
$sel->click_ok("name=add_course");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
ok(not $sel->is_element_present("css=div.ResultsWithError"));
$sel->open_ok("/webwork2");
$sel->text_is("link=TestCourse","TestCourse");
$sel->click_ok("link=TestCourse");
$sel->wait_for_page_to_load_ok("30000");
$sel->text_is("id=page-title", "TestCourse");
ok(not $sel->is_element_present("css=#warnings"));
$sel->type_ok("id=uname", "admin");
$sel->type_ok("id=pswd", "admin");
$sel->click_ok("id=none");
$sel->wait_for_page_to_load_ok("30000");
$sel->text_isnt("css=p", "Your authentication failed. Please try again. Please speak with your instructor if you need help.");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("id=page-title", "Test Course");

delete_course($sel);
