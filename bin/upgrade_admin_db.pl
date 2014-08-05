#!/usr/bin/perl

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/bin/wwdb,v 1.13 2006/01/25 23:13:45 sh002i Exp $
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

use lib "$ENV{WEBWORK_ROOT}/lib";
use WeBWorK::DB;
use WeBWorK::Utils::CourseIntegrityCheck;
use WeBWorK::CourseEnvironment;

package CGI;

sub br { print '';}

##########################
# update one course
##########################
my $upgrade_courseID = 'admin';

my $ce2 = new WeBWorK::CourseEnvironment({
    webwork_dir => $ENV{WEBWORK_ROOT},
    courseName => $upgrade_courseID,
					 });
#warn "do_upgrade_course: updating |$upgrade_courseID| from" , join("|",@upgrade_courseIDs); 
#############################################################################
# Create integrity checker
#############################################################################

my $update_error_msg = '';
my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce=>$ce2);

#############################################################################
# Add missing tables and missing fields to existing tables
#############################################################################

my ($tables_ok,$dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);
my @schema_table_names = keys %$dbStatus;  # update tables missing from database;
my @tables_to_create = grep {$dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A} @schema_table_names;	
my @tables_to_alter  = grep {$dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B} @schema_table_names;
$update_error_msg = $CIchecker->updateCourseTables($upgrade_courseID, [@tables_to_create]);
foreach my $table_name (@tables_to_alter) {	#warn "do_upgrade_course: adding new fields to table $table_name in course $upgrade_courseID";
    $update_error_msg .= $CIchecker->updateTableFields($upgrade_courseID, $table_name);
}

if ($update_error_msg) {
    print $pudate_error_msg.'\n';
} else {
    print 'Admin Course Updated Sucessfully';
}
