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
use Getopt::Long;

use constant TESTING_DIRECTORY => "$ENV{WEBWORK_ROOT}/t/Selenium/Tests";

my $admin_uname   = "admin";
my $admin_pwd = "admin";
my $help = 0;
my $alltests = 0;

GetOptions ("uname=s"  => \$admin_uname,    
	    "pwd=s"    => \$admin_pwd,      
	    "help"  => \$help,
            "all-tests" => \$alltests)   
    or die("Error in command line arguments\n");

if ($help || 
    (scalar(@ARGV) == 0 && !$alltests)) {
    print <<EOS;
    This command is used to run Selenium based testing scripts for WeBWorK.  
In order to use it you will need to have a Selenium Standalone Server running. 
The jar file for this server can be downloaded from www.seleniumhq.org.  You 
will also need a copy of Firefox and can optionally set up Xvfb to run the 
tests "headlessly".  This command takes the following options:
    --uname=<admin username> :  This is the username for the admin user that 
will be used to run the tests.
    --pwd=<admin pwd> : This is the password for the admin user that will be 
used to run the tests.
    --all-tests : This runs all of the tests in the Tests directory.  
Alternatively individual tests files can be provided on the command line.
    --help : Print this message.

Example:

run_tests.pl --uname=admin -pwd=12345 Tests/BasicTests/*    

Note:  You can also perminantly set the username and password used for
Selenium tests by setting the WW_TEST_UNAME and WW_TEST_PWD environment
variables.  
EOS
exit;
}

if ($admin_uname) {
    $ENV{WW_TEST_UNAME} = $admin_uname;
}

if ($admin_pwd) {
    $ENV{WW_TEST_PWD} = $admin_pwd;
}

my @files;
    
if (scalar(@ARGV)) {
  @files = @ARGV;
} elsif ($alltests) {
    find(sub {/\.t$/ && push @files, $File::Find::name;}, TESTING_DIRECTORY);
}

if (scalar(@files)) {
    @files = sort @files;
    runtests( @files);
}
