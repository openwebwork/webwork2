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

# This runs all of the test files passed via the command line.  If nothing is
# passed via the command line it runs all of the files in
# webwork2/t/Selenium/Tests

# All tests in this test suite should be run on a fresh webwork install
# with no courses (besides the admin course) and an admin course user with
# user name admin and password admin.  (Basically the setup you get from
# running the webwork installer).


use strict; 
use warnings;

BEGIN{ die('You need to set the WEBWORK_ROOT environment variable.\n')
	   unless($ENV{WEBWORK_ROOT});}
use lib "$ENV{WEBWORK_ROOT}/t";

use File::Find;
use Test::Harness;

use constant TESTING_DIRECTORY => "$ENV{WEBWORK_ROOT}/t/Selenium/Tests";

my @files;

if (length(@ARGV)) {
  
  @files = @ARGV;
  
} else {
  
  @files = find(sub {/*.t/;}, TESTING_DIRECTORY);
}

runtests( @test_Files);
  
