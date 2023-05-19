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

BEGIN {
	use Mojo::File qw(curfile);
	use YAML::XS qw(LoadFile);
	use Env qw(WEBWORK_ROOT PG_ROOT);

	$WEBWORK_ROOT = curfile->dirname->dirname;

	# Load the configuration file to obtain the PG root directory.
	my $config_file = "$WEBWORK_ROOT/conf/webwork2.mojolicious.yml";
	$config_file = "$WEBWORK_ROOT/conf/webwork2.mojolicious.dist.yml" unless -e $config_file;
	my $config = LoadFile($config_file);
	$PG_ROOT = $config->{pg_dir};

	die "The pg directory must be correctly defined in conf/webwork2.mojolicious.yml" unless -e $ENV{PG_ROOT};
}

use lib "$ENV{WEBWORK_ROOT}/lib";
use lib "$ENV{PG_ROOT}/lib";
use WeBWorK::CourseEnvironment;

use WeBWorK::DB;
use WeBWorK::Utils::CourseIntegrityCheck;

##########################
# update admin course
##########################
my $upgrade_courseID = 'admin';

my $ce = WeBWorK::CourseEnvironment->new({
	webwork_dir => $ENV{WEBWORK_ROOT},
	pg_dir      => $ENV{PG_ROOT},
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
