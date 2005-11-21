#!/usr/bin/perl -w

use strict;

## run this script in a directory that does not contain
## any files whose names end in ".tar.gz" since this 
## produces one such file for each module below and then
## at the end

## list the repository name and then the module name
my @repository_module = qw(
rochester  rochester_problib
rochester rochester_grade8problems
rochester rochester_physics_problib
asu asu_problib
asu database_problems
dartmouth dartmouth_problib
dcds dcds_problib
indiana indiana_problib
nau nau_problib
ohio-state  osu_problib
sunysb  sunysb_problib 
tcnj tcnj_problib
unh unh_highschool_problib
unh unh_problib
union union_problib
);

my ($repository, $module, @command_args);
my @tar_file_list = ();

while (@repository_module ) {
	$repository = shift @repository_module;
	$module = shift @repository_module;
	mkdir $module;
	@command_args = qq(cvs -q -d :ext:apizer\@devel.webwork.rochester.edu:/webwork/cvs/$repository export -D now -d $module $module);
	system (@command_args);
	push @tar_file_list, "${module}.tar.gz";
	@command_args = qq(tar -czf ${module}.tar.gz $module);
	system (@command_args);
	@command_args = qq(rm -r $module);
	system (@command_args);
}

@command_args = qq(tar -czf all_problem_libraries.tar.gz @tar_file_list);
system (@command_args);