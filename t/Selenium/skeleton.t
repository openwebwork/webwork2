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

# After you write your test you should add the number of tests here like
# use Test::More tests => 23

use Test::More qw(no_plan);
use Test::WWW::Selenium;
use Test::Exception;
use Time::HiRes qw(sleep);
use Selenium::Utilities;


my $sel = Test::WWW::Selenium->new( host => "localhost", 
                                    port => 80, 
                                    browser => "*chrome", 
                                    browser_url => "http://localhost/" );


# Create a test course
create_course($sel);

# Put Selenium tests here.  The easiest way to generate these tests is to
# use the Selenium IDE for Firefox with the additional plugin which
# allows you to export scripts from Selenium IDE to Perl.  The basic method is
#
# 1. Use the Selenium IDE to record your actions performing some test.
# 2. Export the test as Perl and copy the results here.
#
# Working with Selenium and making tests takes some practice.  Here are some
# links that were good at the time of writing
#
# Selenium IDE: http://www.seleniumhq.org/projects/ide/
# Selenium IDE Plugin: https://addons.mozilla.org/en-US/firefox/addon/selenium-ide/
# Selenium IDE Perl Plugin: https://addons.mozilla.org/en-US/firefox/addon/selenium-ide-perl-formatter/
# 

delete_course($sel);
