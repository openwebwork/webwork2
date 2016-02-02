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

use Test::More tests => 56;
use Test::WWW::Selenium;
use Test::Exception;
use Time::HiRes qw(sleep);
use Selenium::Utilities;


my $sel = Test::WWW::Selenium->new( host => "localhost", 
                                    port => 4444, 
                                    browser => "*firefox", 
                                    browser_url => "http://localhost/" );


create_course($sel);
import_set($sel);
create_student($sel);

$sel->open_ok("/webwork2/TestCourseX/");
$sel->click_ok("link=Instructor Tools");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->add_selection_ok("name=selected_users", "label=Student, Test (teststud)");
$sel->add_selection_ok("name=selected_sets", "label=Demo");
$sel->click_ok("name=assign_users");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("css=div.ResultsWithoutError", "All assignments were made successfully.");
$sel->click_ok("link=Hmwk Sets Editor");
$sel->wait_for_page_to_load_ok("30000");
$sel->text_is("//table[\@id='set_table_id']/tbody/tr[2]/td[4]/a", "2/2");
$sel->text_is("//table[\@id='set_table_id']/tbody/tr[2]/td[3]/a", "8");
$sel->click_ok("link=8");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->click_ok("css=button.ui-datepicker-trigger.btn");
$sel->click_ok("link=8");
$sel->click_ok("xpath=(//button[\@type='button'])[5]");
$sel->type_ok("id=set.Demo.due_date_id", "01/01/2020 at 02:00am");
$sel->type_ok("id=set.Demo.answer_date_id", "01/01/2021 at 02:00am");
$sel->value_is("id=problem.1.value_id", "1");
$sel->value_is("id=problem.1.max_attempts_id", "unlimited");
$sel->value_is("id=problem.1.source_file_id", "setDemo/srw1_9_4.pg");
$sel->value_is("id=problem.8.value_id", "1");
$sel->value_is("id=problem.8.max_attempts_id", "unlimited");
$sel->value_is("id=problem.8.source_file_id", "setDemo/sample_myown_ans.pg");
$sel->click_ok("css=i.icon-picture");
sleep(2);
$sel->text_is("css=#psr_render_area_1 > p > b", "setDemo/srw1_9_4.pg");
$sel->click_ok("css=#pdr_render_2 > i.icon-picture");
sleep(2);
$sel->is_element_present_ok("//div[\@id='psr_render_area_2']/p[3]/a/img");
$sel->click_ok("name=add_blank_problem");
$sel->click_ok("id=submit_changes_2");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("css=div.ResultsWithoutError", "Added setDemo/blankProblem.pg to Demo as problem 9");
$sel->value_is("id=set.Demo.due_date_id", "01/01/2020 at 02:00am");
$sel->value_is("id=set.Demo.answer_date_id", "01/01/2021 at 02:00am");
$sel->value_is("id=problem.9.source_file_id", "setDemo/blankProblem.pg");
ok(not $sel->is_element_present("css=div.ResultsWithError"));
$sel->click_ok("link=individual versions");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Edit data for teststud");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("id=set.Demo.due_date_id", "01/01/2019 at 02:00pm");
$sel->click_ok("id=submit_changes_1");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->value_is("id=set.Demo.due_date_id", "01/01/2019 at 02:00pm");
$sel->value_is("id=set.Demo.due_date.override_id", "on");
$sel->click_ok("link=Classlist Editor");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=teststud");
$sel->wait_for_page_to_load_ok("30000");
$sel->text_is("css=span.font-visible", "open, due 01/01/2019 at 02:00pm EST");

delete_course($sel);
