#!/usr/bin/env perl
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/bin/wwdb_upgrade,v 1.17 2007/08/13 22:59:50 sh002i Exp $
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
use Getopt::Std;
use Data::Dumper;

BEGIN {
	die "WEBWORK_ROOT not found in environment.\n"
		unless exists $ENV{WEBWORK_ROOT};
}

use lib "$ENV{WEBWORK_ROOT}/lib";
use WeBWorK::CourseEnvironment;
use WeBWorK::Utils::CourseIntegrityCheck;
use WeBWorK;

our ($opt_v);
getopts("v");

if ($opt_v) {
	$WeBWorK::Debug::Enabled = 1;
} else {
	$WeBWorK::Debug::Enabled = 0;
}


my $courseName = "tmp_course";

my $ce = new WeBWorK::CourseEnvironment(
               {webwork_dir=>$ENV{WEBWORK_ROOT},
                courseName=> $courseName               
               });


print "ce ready $ce";

my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck($ce);

my $return = $CIchecker->checkCourseDirectories();

print "result $return";
1;