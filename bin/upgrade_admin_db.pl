#!/usr/bin/env perl
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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

my $pg_dir;

BEGIN {
	die('You need to set the WEBWORK_ROOT environment variable.\n')
		unless ($ENV{WEBWORK_ROOT});
	$pg_dir = $ENV{PG_ROOT} // "$ENV{WEBWORK_ROOT}/../pg";
	die "The pg directory must be defined in PG_ROOT" unless (-e $pg_dir);
}

use lib "$ENV{WEBWORK_ROOT}/lib";
use lib "$pg_dir/lib";
use WeBWorK::CourseEnvironment;

use WeBWorK::DB;
use WeBWorK::Utils::CourseIntegrityCheck;

##########################
# update admin course
##########################
my $upgrade_courseID = 'admin';

my $ce = new WeBWorK::CourseEnvironment({
	webwork_dir => $ENV{WEBWORK_ROOT},
	courseName  => $upgrade_courseID,
});
#warn "do_upgrade_course: updating |$upgrade_courseID| from" , join("|",@upgrade_courseIDs);
#############################################################################
# Create integrity checker
#############################################################################

my @update_report;
my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce => $ce);

#############################################################################
# Add missing tables and missing fields to existing tables
#############################################################################

my ($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);
my @schema_table_names = keys %$dbStatus;    # update tables missing from database;
my @tables_to_create =
	grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A() } @schema_table_names;
my @tables_to_alter =
	grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B() } @schema_table_names;
push(@update_report, $CIchecker->updateCourseTables($upgrade_courseID, [@tables_to_create]));
foreach my $table_name (@tables_to_alter)
{    #warn "do_upgrade_course: adding new fields to table $table_name in course $upgrade_courseID";
	push(@update_report, $CIchecker->updateTableFields($upgrade_courseID, $table_name));
}

if (@update_report) {
	for (@update_report) {
		if ($_->[1]) {
			print "$_->[0]\n";
		} else {
			print STDERR "$_->[0]\n";
		}
	}
} else {
	print "Admin Course Up to Date\n";
}
