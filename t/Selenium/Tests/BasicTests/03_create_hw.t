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

use Test::More tests => 31;
use Test::WWW::Selenium;
use Test::Exception;
use Time::HiRes qw(sleep);
use Selenium::Utilities;


my $sel = Test::WWW::Selenium->new( host => "localhost", 
                                    port => 4444, 
                                    browser => "*firefox", 
                                    browser_url => "http://localhost/" );


create_course($sel);

$sel->open_ok("/webwork2/TestCourse/");
$sel->click_ok("link=Hmwk Sets Editor");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Import");
$sel->text_is("css=option[value=\"set0.def\"]", "set0.def");
$sel->text_is("css=option[value=\"setDemo.def\"]", "setDemo.def");
$sel->text_is("css=option[value=\"setOrientation.def\"]", "setOrientation.def");
$sel->select_ok("id=import_source_select", "label=setDemo.def");
$sel->type_ok("id=import_text", "Demoxyz");
$sel->type_ok("id=import_date_shift", "01/13/2016 at 12:05am");
$sel->click_ok("id=take_action");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("css=div.ResultsWithoutError", "1 sets added, 0 sets skipped. Skipped sets: ()");
$sel->text_is("link=Demoxyz", "Demoxyz");
$sel->text_is("//table[\@id='set_table_id']/tbody/tr[2]/td[6]/font", "01/13/2016 at 12:05am");
$sel->text_is("link=8", "8");
$sel->click_ok("link=Homework Sets");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("link=Demoxyz", "Demoxyz");
$sel->text_is("css=span.font-visible", "open, due 01/03/2024 at 08:05pm EST");
$sel->click_ok("link=Demoxyz");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("id=page-title", "Demoxyz - Due 01/03/2024 at 08:05pm EST");
$sel->text_is("link=Problem 1", "Problem 1");
$sel->click_ok("link=Problem 2");
ok(not $sel->is_element_present("css=#warnings"));
$sel->wait_for_page_to_load_ok("30000");
$sel->is_element_present_ok("//div[\@id='problem_body']/div/p[3]/a/img");

delete_course($sel);
