#!/usr/bin/env perl

BEGIN {
	use Mojo::File qw(curfile);
	use Env        qw(WEBWORK_ROOT);

	$WEBWORK_ROOT = curfile->dirname->dirname;
}

use lib "$ENV{WEBWORK_ROOT}/lib";

use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Utils::CourseDBIntegrityCheck;

# Update admin course
my $ce               = WeBWorK::CourseEnvironment->new({ webwork_dir => $ENV{WEBWORK_ROOT} });
my $upgrade_courseID = $ce->{admin_course_id};
$ce = WeBWorK::CourseEnvironment->new({
	webwork_dir => $ENV{WEBWORK_ROOT},
	courseName  => $upgrade_courseID,
});

# Create integrity checker
my @update_report;
my $CIchecker = new WeBWorK::Utils::CourseDBIntegrityCheck($ce);

# Add missing tables and missing fields to existing tables
my ($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);
my @schema_table_names = keys %$dbStatus;    # update tables missing from database;
my @tables_to_create =
	grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseDBIntegrityCheck::ONLY_IN_A() } @schema_table_names;
my @tables_to_alter =
	grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseDBIntegrityCheck::DIFFER_IN_A_AND_B() } @schema_table_names;
push(@update_report, $CIchecker->updateCourseTables($upgrade_courseID, [@tables_to_create]));

for my $table_name (@tables_to_alter) {
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
