#!/usr/bin/perl
##############################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, http://openwebwork.sf.net/
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See either the GNU General Public License or the
# Artistic License for more details.
##############################################################################

=head1 NAME

upgrade-database-to-utf8mb4.pl -- Upgrade webwork course database tables from
latin1 to utf8mb4.

=head1 SYNOPSIS
 
  upgrade-database-to-utf8mb4.pl [options]
 
  Options:
    -c|--course-id [course]   Course id to upgrade the database for.
                              (This option may be given multiple times.)
    -a|--all                  Upgrade the database for all existing courses
                              including the admin course.
                              (Preempts the previous option.)
    -2|--run-second-pass      Run a second pass to change column text types to
                              be the defaults for webwork.  This pass is not run
                              by default.
    -n|--upgrade-non-native   Upgrade the non-native tables
                              (locations, location_addresses, depths)
    --no-backup               Do not backup the database before making changes
                              to the database. (Not recommended)
    -b|--backup-file [file]   Filename for the database backup file.
                              Default: ./webwork.sql
    -v|--verbose              Show progress output.
    -h|--help                 Show full help for this script.

=head1 DESCRIPTION
 
Upgrade webwork course database tables from latin1 to utf8mb4.

This script assumes that you have already properly configured the database to
work with the utf8mb4 character set.  See L<https://webwork.maa.org/wiki/Converting_the_webwork_database_from_the_latin1_to_the_utf8mb4_character_set#Check_what_the_default_character_set_is_for_MySQL_on_your_new_or_upgraded_server>.

Also, make sure to upgrade the course via webwork2/admin "Upgrade Courses"
before running this script for the course.

If you are upgrading a WeBWorK installation from a version prior to version 2.15
use

    upgrade-database-to-utf8mb4.pl -na

If you are upgrading a single course that was created with a version of WeBWorK
prior to version 2.15, use

    upgrade-database-to-utf8mb4.pl -c courseId

If there are errors when running this script, then restore the database using
the backup created by the script (unless you used --no-backup) by running

    mysql -u webworkWrite -p webwork < webwork.sql

This is where C<webworkWrite> is the C<$database_username> set in site.conf.
You may need to change C<webwork.sql> if you used a different name for the
database backup file.  You will be prompted to enter the password, which should
be the value of C<$database_password> in site.conf.

=head1 OPTIONS

=over

=item -c|--course-id [course]

Course id or list of course ids to upgrade the database tables for.  Use this
option multiple times to upgrade the database tables for multiple courses at one
time.

=item -a|--all

Ignore the previous option and upgrade the database tables for all existing
courses, including the admin course.

=item -2|--run-second-pass

On the first pass this script will change the datatypes of all columns that are
different from the datatype defined in the webwork database schema to that in
the schema.  Then it will convert the table to use the utf8mb4 charset.  When
this conversion is done the database automatically enlarges text datatypes.  If
this option is enabled then the second pass will change those back to the
smaller text datatypes as defined in the webwork database schema.

This second pass is not strictly neccessary.  The larger text datatypes should
still work with WeBWorK.

This pass is not run by default.  Note that running this script again will also
perform this second pass, if desired.

=item --no-backup

Do not dump the entire webwork database to a backup sql file before performing
changes.  It is recommended that you make a backup before any of the other
changes that this script makes.  If you have already created a database backup,
then you can use this option to prevent the creation of another backup file.

=item -b|--backup-file [filename]

Filename for the database backup file.  By default the database is dumped to the
file C<./webwork.sql> in the directory the script is run from.

=item -v|--verbose

Make this script show output for the things that it is doing.

=back

=cut

use strict;
use warnings;

BEGIN {
	die "WEBWORK_ROOT not found in environment.\n" unless $ENV{WEBWORK_ROOT};
	die "PG_ROOT not found in environment.\n" unless $ENV{PG_ROOT};
}

use Getopt::Long qw(:config bundling);
use Pod::Usage;
use DBI;
use String::ShellQuote;

my (@courses, $all, $second_pass, $upgrade_non_native, $no_backup, $dump_file,
	$verbose, $show_help);
GetOptions(
	'c|course-id=s@'       => \@courses,
	'a|all'                => \$all,
	'2|run-second-pass'    => \$second_pass,
	'n|upgrade-non-native' => \$upgrade_non_native,
	'no-backup'            => \$no_backup,
	'b|backup-file=s'      => \$dump_file,
	'v|verbose'            => \$verbose,
	'h|help'               => \$show_help
);
pod2usage(-verbose => $show_help ? 2 : 0) if $show_help || !(@courses || $all || $upgrade_non_native);

use lib "$ENV{WEBWORK_ROOT}/lib";
use lib "$ENV{PG_ROOT}/lib";
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Utils::CourseManagement qw{listCourses};

# Load a minimal course environment.
my $ce = new WeBWorK::CourseEnvironment({ webwork_dir => $ENV{WEBWORK_ROOT} });

# Get DB connection settings.
my $dbname = $ce->{database_name};
my $host   = $ce->{database_host};
my $port   = $ce->{database_port};
my $dbuser = shell_quote($ce->{database_username});
my $dbpass = $ce->{database_password};

$ENV{'MYSQL_PWD'} = $dbpass;

if (!$no_backup) {
	# Backup the database
	$dump_file = "./webwork.sql" if !$dump_file || $dump_file eq "";

	my $replace = 'Y';
	if (-e $dump_file) {
		$replace = 'n';
		print "The file '$dump_file' already exists.  Do you want to overwrite it? [Yn] ";
		$replace = <>;
		chomp($replace);
		print "Overwriting '$dump_file' with new database dump.\n" if $replace eq 'Y';
		print "Not creating new database dump.\n" if $replace ne 'Y';

		if ($replace ne 'Y') {
			my $proceed = 'n';
			print "Do you want to proceed with the script anyway? [Yn] ";
			$proceed = <>;
			chomp($proceed);
			exit if $proceed ne 'Y';
		}
	}

	if ($replace eq 'Y') {
		print "Backing up database to '$dump_file'.\n" if $verbose;
		`$ce->{externalPrograms}{mysqldump} --host=$host --port=$port --user=$dbuser $dbname > $dump_file`;
		die("There was an error creating a database backup.\n" .
			"Please make a manual backup if needed before proceeding.") if $?;
	}
}

# Get a list of courses.
my @server_courses = listCourses($ce);
@courses = @server_courses if $all;

my $dbh = DBI->connect(
	$ce->{database_dsn},
	$ce->{database_username},
	$ce->{database_password},
	{
		PrintError => 0,
		RaiseError => 1,
	},
);

my $db = new WeBWorK::DB($ce->{dbLayouts}{$ce->{dbLayoutName}});
my @table_types = sort(grep { !$db->{$_}{params}{non_native} } keys %$db);

sub checkAndUpdateTableColumnTypes {
	my $table = shift;
	my $table_type = shift;
	my $pass = shift // 1;
	
	print "\tChecking '$table' (pass $pass)\n" if $verbose;
	my $schema_field_data = $db->{$table_type}{record}->FIELD_DATA;
	for my $field (keys %$schema_field_data) {
		my $field_name = $db->{$table_type}{params}{fieldOverride}{$field} || $field;
		my @name_type = @{$dbh->selectall_arrayref("SELECT COLUMN_TYPE FROM INFORMATION_SCHEMA.COLUMNS " .
			"WHERE TABLE_SCHEMA='$dbname' AND TABLE_NAME='$table' AND COLUMN_NAME='$field_name';")};

		print("\t\tThe '$field_name' column is missing from '$table'.\n" .
			"\t\tYou should upgrade the course via course administration to fix this.\n" .
			"\t\tYou may need to run this script again after doing that.\n"),
		next if !exists($name_type[0][0]);

		my $data_type = $name_type[0][0];
		next if !$data_type;
		$data_type =~ s/\(\d*\)$// if $data_type =~ /^(big|small)?int\(\d*\)$/;
		$data_type = lc($data_type);
		my $schema_data_type = lc($schema_field_data->{$field}{type} =~ s/ .*$//r);
		if ($data_type ne $schema_data_type) {
			print "\t\tUpdating data type for column '$field_name' in table '$table'\n" if $verbose;
			print "\t\t\t$data_type -> $schema_data_type\n" if $verbose;
			eval {
				$dbh->do("ALTER TABLE `$table` MODIFY $field_name $schema_field_data->{$field}{type};");
			};
			my $indent = $verbose ? "\t\t" : "";
			die("${indent}Failed to modify '$field_name' in '$table' from '$data_type' to '$schema_data_type.\n" .
				"${indent}It is recommended that you restore a database backup.  Make note of the\n" .
				"${indent}error output below as it may help in diagnosing the problem.  Note that\n" .
				"${indent}the most common reason for this error is the existence of a data value\n" .
				"${indent}in a column that does not fit into the smaller size data type that was\n" .
				"${indent}needed for the utf8mb4 change.\n$@")
			if $@;
		}
	}
	return 0;
}

sub checkAndChangeTableCharacterSet {
	my $table = shift;

	print "\tChecking character set for '$table'\n" if $verbose;
	my @table_data = @{$dbh->selectall_arrayref("SELECT CCSA.character_set_name FROM information_schema.TABLES T, " .
		"information_schema.COLLATION_CHARACTER_SET_APPLICABILITY CCSA " .
		"WHERE CCSA.collation_name = T.table_collation AND T.table_schema = '$dbname' AND T.table_name = '$table'")};
	for (@table_data) {
		if ($_->[0] ne 'utf8mb4') {
			print "\t\tConverting '$table' character set to utf8mb4\n" if $verbose;
			eval {
				$dbh->do("ALTER TABLE `$table` CONVERT TO CHARACTER SET utf8mb4;");
			};
			my $indent = $verbose ? "\t\t" : "";
			die("${indent}Failed to alter charset of '$table' to utf8mb4:\n" .
				"${indent}It is recommended that you restore a database backup.  Make note of the\n" .
				"${indent}error output below as it may help in diagnosing the problem.\n$@") if $@;
		}
	}
	return 0;
}

my $error = 0;

for my $course (@courses) {
	print("The course '$course' does not exist on the server\n"), next
   	if !grep($course eq $_, @server_courses);

	print "Checking tables for '$course'\n" if $verbose;
	for my $table_type (@table_types) {
		my $table = "${course}_$table_type";
		next unless @{$dbh->selectall_arrayref("SELECT * FROM INFORMATION_SCHEMA.TABLES " .
			"WHERE TABLE_SCHEMA = '$dbname' AND TABLE_NAME='$table';")};

	   	checkAndUpdateTableColumnTypes($table, $table_type);
		checkAndChangeTableCharacterSet($table);
		checkAndUpdateTableColumnTypes($table, $table_type, 2) if ($second_pass);
	}
}

if ($upgrade_non_native) {
	print "Checking native tables\n" if $verbose;

	my @native_tables = grep { $db->{$_}{params}{non_native} } keys %$db;
	for my $native_table (@native_tables) {
		# Skip the fake tables
		next unless @{$dbh->selectall_arrayref("SELECT * FROM INFORMATION_SCHEMA.TABLES " .
			"WHERE TABLE_SCHEMA = '$dbname' AND TABLE_NAME='$native_table';")};

		checkAndUpdateTableColumnTypes($native_table, $native_table);
		checkAndChangeTableCharacterSet($native_table);
		checkAndUpdateTableColumnTypes($native_table, $native_table, 2) if ($second_pass);
	}
}
