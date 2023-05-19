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

use strict;
use warnings;
use Getopt::Std;
use Data::Dumper;

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

my $ce = WeBWorK::CourseEnvironment->new({
	webwork_dir => $ENV{WEBWORK_ROOT},
	pg_dir      => $ENV{PG_ROOT},
	courseName  => $courseName
});

my $CIchecker = WeBWorK::Utils::CourseIntegrityCheck->new(ce => $ce);

my ($directory_status, $results) = $CIchecker->checkCourseDirectories;

if ($directory_status) {
	print "Course directory structure is okay.\n";
} else {
	print "Course directory structure needs repair.\n";
	print Dumper($results);
}

1;
