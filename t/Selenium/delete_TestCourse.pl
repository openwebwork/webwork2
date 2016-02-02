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

use Test::WWW::Selenium;
use Getopt::Long;
use Selenium::Utilities;

my $admin_uname   = "admin";
my $admin_pwd = "admin";
my $help = 0;

GetOptions ("uname=s"  => \$admin_uname,    
	    "pwd=s"    => \$admin_pwd,      
	    "help"  => \$help,)   
    or die("Error in command line arguments\n");

if ($help) {
    print <<EOS;
    This command deletes the standard Selenium test course and can be used to
clean up after a failed run of tests.  This command takes the following 
options:
    --uname=<admin username> :  This is the username for the admin user that 
will be used to run the tests.
    --pwd=<admin pwd> : This is the password for the admin user that will be 
used to run the tests.
    --help : Print this message.
EOS
    exit;
}

my $sel = Test::WWW::Selenium->new( host => "localhost", 
			      port => 4444, 
			      browser => "*firefox", 
			      browser_url => "http://localhost/" );



delete_course($sel,uname=>$admin_uname,pwd=>$admin_pwd);
