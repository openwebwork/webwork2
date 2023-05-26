#!/usr/bin/perl

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

use strict;

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
use String::ShellQuote;

use DBI;
use WeBWorK::Utils::CourseIntegrityCheck;
use WeBWorK::Utils::CourseManagement qw/listCourses/;

my $time = time();

# get course environment and open up database
my $ce = WeBWorK::CourseEnvironment->new({
	webwork_dir => $ENV{WEBWORK_ROOT},
	pg_dir      => $ENV{PG_ROOT}
});

# decide whether the mysql installation can handle
# utf8mb4 and that should be used for the OPL

my $ENABLE_UTF8MB4 = $ce->{ENABLE_UTF8MB4} ? 1 : 0;

my $dbh = DBI->connect(
	$ce->{problemLibrary_db}->{dbsource},
	$ce->{problemLibrary_db}->{user},
	$ce->{problemLibrary_db}->{passwd},
	{
		AutoCommit => 0,
		PrintError => 0,
		RaiseError => 1,
	},
);

# get course list
my @courses = listCourses($ce);

# create tables.  We always redo the statistics table.

my $character_set = ($ENABLE_UTF8MB4) ? "utf8mb4" : "utf8";

$dbh->do(<<EOS);
CREATE TABLE IF NOT EXISTS `OPL_problem_user` (
  `course_id` tinyblob NOT NULL,
  `user_id` tinyblob NOT NULL,
  `set_id` tinyblob NOT NULL,
  `due_date` int(11) NOT NULL,
  `problem_id` int(11) NOT NULL,
  `source_file` text,
  `status` float DEFAULT NULL,
  `attempted` int(11) DEFAULT NULL,
  `num_correct` int(11) DEFAULT NULL,
  `num_incorrect` int(11) DEFAULT NULL,
  UNIQUE KEY `unique_key_idx` (`course_id`(80),`user_id`(80),`set_id`(80),`due_date`,`problem_id`),
  KEY `source_file_idx` (`source_file`(245))
)
  ENGINE=MyISAM
  CHARACTER SET $character_set
EOS

$dbh->do(<<EOS);
DROP TABLE IF EXISTS `OPL_local_statistics`
EOS

$dbh->do(<<EOS);
CREATE TABLE `OPL_local_statistics` (
  `source_file` varchar(245) NOT NULL,
  `students_attempted` int(11) DEFAULT NULL,
  `average_attempts` float DEFAULT NULL,
  `average_status` float DEFAULT NULL,
  PRIMARY KEY (`source_file`(245))
)  ENGINE=MyISAM
   CHARACTER SET $character_set
EOS

$dbh->commit();

# for each course get the data from the user problem table into the
# opl user problem table.

print "Importing statistics for " . scalar(@courses) . " courses.\n";

my $counter = 0;

foreach my $courseID (@courses) {
	$counter++;
	print sprintf("%*d", 4, $counter);
	if ($counter % 10 == 0) {
		print "\n";
	}

	next if $courseID eq 'admin' || $courseID eq 'modelCourse';

	# we extract the identifying information of the problem,
	# the status, attempted flag, number of attempts.
	# and the source_file
	# we strip of the local in front of the source file
	# (assuming that these are mostly the same as their library counterparts
	$dbh->do(<<EOS);
INSERT IGNORE INTO OPL_problem_user
  (course_id,
  user_id,
  set_id,
  due_date,
  problem_id,
  source_file,
  status,
  attempted,
  num_correct,
  num_incorrect)
SELECT
  '$courseID' AS `course_id`,
  `${courseID}_problem_user`.user_id,
  `${courseID}_problem`.set_id,
  `${courseID}_set`.due_date,
  `${courseID}_problem`.problem_id,
  REPLACE(`${courseID}_problem`.source_file,'local/',''),
  `${courseID}_problem_user`.status,
  `${courseID}_problem_user`.attempted,
  `${courseID}_problem_user`.num_correct,
  `${courseID}_problem_user`.num_incorrect
FROM `${courseID}_problem_user`
  JOIN `${courseID}_problem`
  ON `${courseID}_problem_user`.set_id = `${courseID}_problem`.set_id
  AND `${courseID}_problem_user`.problem_id = `${courseID}_problem`.problem_id
  JOIN `${courseID}_set`
  ON `${courseID}_problem_user`.set_id = `${courseID}_set`.set_id
WHERE (`${courseID}_problem`.source_file LIKE 'Library/%'
  OR `${courseID}_problem`.source_file LIKE 'local/Library/%'
  OR `${courseID}_problem`.source_file LIKE 'Contrib/%'
  OR `${courseID}_problem`.source_file LIKE 'local/Contrib/%')
  AND `${courseID}_set`.due_date < $time;
EOS

}

print "\n\n";

$dbh->commit();

# compile desired statistics from opl problem user table.
$dbh->do(<<EOS);
INSERT INTO OPL_local_statistics
  (source_file,
  students_attempted,
  average_attempts,
  average_status)
SELECT
  source_file,
  COUNT(*),
  AVG(num_correct+num_incorrect),
  AVG(status)
FROM OPL_problem_user
WHERE attempted=1
GROUP BY source_file
EOS

$dbh->commit();

# We no longer automatically load the global statistics data here.
print("You may want to run load-OPL-global-statistics.pl to update the global statistics data.\n",
	"If this is being run by OPL-update, that will be done automatically.\n");

1;
