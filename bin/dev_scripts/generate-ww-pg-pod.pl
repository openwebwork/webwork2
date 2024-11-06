#!/usr/bin/env perl
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

=head1 NAME

generate-ww-pg-pod.pl - Convert WeBWorK and PG POD into HTML form.

=head1 SYNOPSIS

generate-ww-pg-pod.pl [options]

 Options:
   -p|--pg-root          Directory containing  a git clone of pg.
                         If this option is not set, then the environment
                         variable $PG_ROOT will be used if it is set.
   -o|--output-dir       Directory to save the output files to. (required)
   -b|--base-url         Base url location used on server. (default: /)
                         This is needed for internal POD links to work correctly.
   -v|--verbose          Increase the verbosity of the output.
                         (Use multiple times for more verbosity.)

Note that --pg-root must be provided or the PG_ROOT environment variable set
if the POD for pg is desired.

=head1 DESCRIPTION

Convert WeBWorK and PG POD into HTML form.

=cut

use strict;
use warnings;

use Getopt::Long qw(:config bundling);
use Pod::Usage;

my ($pg_root, $output_dir, $base_url);
my $verbose = 0;
GetOptions(
	'p|pg-root=s'    => \$pg_root,
	'o|output-dir=s' => \$output_dir,
	'b|base-url=s'   => \$base_url,
	'v|verbose+'     => \$verbose
);

$pg_root = $ENV{PG_ROOT} if !$pg_root;

pod2usage(2) unless $output_dir;

$base_url = "/" if !$base_url;

use Mojo::Template;
use IO::File;
use File::Copy;
use File::Path     qw(make_path remove_tree);
use File::Basename qw(dirname);
use Cwd            qw(abs_path);

use lib dirname(dirname(dirname(__FILE__))) . '/lib';
use lib dirname(__FILE__);

use PODtoHTML;

my $webwork_root = abs_path(dirname(dirname(dirname(__FILE__))));

for my $dir ($webwork_root, $pg_root) {
	next unless $dir && -d $dir;
	print "Reading: $dir\n" if $verbose;
	process_dir($dir);
}

my $index_fh = IO::File->new("$output_dir/index.html", '>')
	or die "failed to open '$output_dir/index.html' for writing: $!\n";
write_index($index_fh);

make_path("$output_dir/assets");
copy("$webwork_root/htdocs/js/PODViewer/podviewer.css", "$output_dir/assets/podviewer.css");
print "copying $webwork_root/htdocs/js/PODViewer/podviewer.css to $output_dir/assets/podviewer.css\n" if $verbose;
copy("$webwork_root/htdocs/js/PODViewer/podviewer.js", "$output_dir/assets/podviewer.js");
print "copying $webwork_root/htdocs/js/PODViewer/podviewer.css to $output_dir/assets/podviewer.js\n" if $verbose;

sub process_dir {
	my $source_dir = shift;
	return unless $source_dir =~ /\/webwork2$/ || $source_dir =~ /\/pg$/;

	my $is_pg    = $source_dir =~ /\/pg$/;
	my $dest_dir = $source_dir;
	$dest_dir =~ s/^$webwork_root/$output_dir\/webwork2/ unless $is_pg;
	$dest_dir =~ s/^$pg_root/$output_dir\/pg/ if $is_pg;

	remove_tree($dest_dir);
	make_path($dest_dir);

	my $sections =
		$is_pg
		? [ doc => 'Documentation', macros => 'Macros',        lib => 'Libraries' ]
		: [ bin => 'Scripts',       doc    => 'Documentation', lib => 'Libraries' ];
	my $macros = $is_pg
		? [
			core       => 'Core',
			contexts   => 'Contexts',
			parsers    => 'Parsers',
			answers    => 'Answers',
			graph      => 'Graph',
			math       => 'Math',
			ui         => 'User Interface',
			misc       => 'Miscellaneous',
			deprecated => 'Deprecated'
		]
		: [];

	my $htmldocs = PODtoHTML->new(
		source_root  => $source_dir,
		dest_root    => $dest_dir,
		template_dir => "$webwork_root/bin/dev_scripts/pod-templates",
		dest_url     => $base_url,
		sections     => $sections,
		macros       => $macros,
		verbose      => $verbose
	);
	$htmldocs->convert_pods;

	return;
}

sub write_index {
	my $fh = shift;

	print $fh Mojo::Template->new(vars => 1)->render_file("$webwork_root/bin/dev_scripts/pod-templates/main-index.mt",
		{ base_url => $base_url, webwork_root => $webwork_root, pg_root => $pg_root });

	return;
}

1;
