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

use Test::More tests => 26;
use Test::WWW::Selenium;
use Test::Exception;
use Time::HiRes qw(sleep);
use Selenium::Utilities;


my $sel = Test::WWW::Selenium->new( host => "localhost", 
                                    port => 4444, 
                                    browser => "*firefox", 
                                    browser_url => "http://localhost/" );


# Create a test course
create_course($sel);
import_set($sel);

$sel->open('/webwork2/TestCourse/instructor');
$sel->wait_for_page_to_load_ok("30000");
$sel->add_selection_ok("name=selected_users", "label=Administrator, (admin)");
$sel->add_selection_ok("name=selected_sets", "label=Demo");
$sel->click_ok("name=edit_set_for_users");
$sel->wait_for_page_to_load_ok("30000");
$sel->type_ok("id=problem.1.problem_seed_id", "100");
$sel->click_ok("id=submit_changes_2");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->click_ok("link=Homework Sets");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Demo");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->click_ok("link=Problem 1");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->type_ok("id=AnSwEr0001", "8.2462112");
$sel->type_ok("id=AnSwEr0002", "-3");
$sel->type_ok("id=AnSwEr0003", "-5");
$sel->click_ok("id=submitAnswers_id");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("//div[\@id='output_summary']/table/tbody/tr[2]/td[3]/a/span", "correct");
$sel->text_is("//div[\@id='output_summary']/table/tbody/tr[3]/td[3]/a/span", "correct");
$sel->text_is("//div[\@id='output_summary']/table/tbody/tr[4]/td[3]/a/span", "correct");

delete_course($sel);
