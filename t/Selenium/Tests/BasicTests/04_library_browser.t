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

use Test::More tests => 37;
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
$sel->click_ok("link=Library Browser");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->type_ok("name=new_set_name", "Test");
$sel->click_ok("name=new_local_set");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("css=div.ResultsWithoutError", "Set Test has been created.");
$sel->select_ok("name=library_subjects", "label=Calculus - single variable");
sleep(2);
$sel->text_is("css=option[value=\"Differentiation\"]", "Differentiation");
$sel->select_ok("name=library_chapters", "label=Differentiation");
sleep(2);
$sel->text_is("css=option[value=\"Derivatives of polynomials and power functions\"]", "Derivatives of polynomials and power functions");
$sel->select_ok("name=library_sections", "label=Derivatives of polynomials and power functions");
sleep(2);
$sel->click_ok("name=lib_view");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->click_ok("id=filepath1");
my $prob1 = $sel->get_text("id=filepath1");
$prob1 =~ s/^Hide path:\s*//;
$sel->click_ok("name=add_me");
sleep(2);
$sel->text_is("css=i > b", "(in target set)");
$sel->click_ok("css=#pgrow6 > td > div.lb-problem-header > span.lb-problem-add > input[name=\"add_me\"]");
sleep(2);
$sel->text_is("css=#inset6 > i > b", "(in target set)");
$sel->click_ok("id=filepath6");
my $prob2 = $sel->get_text("id=filepath6");
$prob2 =~ s/^Hide path:\s*//;
$sel->click_ok("link=Homework Sets");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("link=Test", "Test");
$sel->click_ok("link=Test");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("link=Problem 1");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("css=b", $prob1);
$sel->click_ok("link=Next");
$sel->wait_for_page_to_load_ok("30000");
ok(not $sel->is_element_present("css=#warnings"));
$sel->text_is("css=b", $prob2);

delete_course($sel);
