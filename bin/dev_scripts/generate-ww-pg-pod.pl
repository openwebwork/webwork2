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

use IO::File;
use File::Copy;
use File::Path qw(make_path remove_tree);
use File::Basename qw(dirname);
use Cwd qw(abs_path);

use lib dirname(__FILE__);
use PODtoHTML;

my $webwork_root = abs_path(dirname(dirname(dirname(__FILE__))));

for my $dir ($webwork_root, $pg_root) {
	next unless $dir && -d $dir;
	print "Reading: $dir\n" if $verbose;
	process_dir($dir);
}

make_path("$output_dir/css");
copy("$webwork_root/bin/dev_scripts/pod.css", "$output_dir/css/pod.css");
print "copying $webwork_root/bin/dev_scripts/pod.css to $output_dir/css/pod.css\n" if $verbose;

my $index_fh = new IO::File("$output_dir/index.html", '>')
	or die "failed to open '$output_dir/index.html' for writing: $!\n";
write_index($index_fh, $base_url);

sub process_dir {
	my $source_dir = shift;
	return unless $source_dir =~ /\/webwork2$/ || $source_dir =~ /\/pg$/;

	my $dest_dir = $source_dir;
	$dest_dir =~ s/^$webwork_root/$output_dir\/webwork2/ if ($source_dir =~ /\/webwork2$/);
	$dest_dir =~ s/^$pg_root/$output_dir\/pg/            if ($source_dir =~ /\/pg$/);

	remove_tree($dest_dir);
	make_path($dest_dir);

	my $htmldocs = PODtoHTML->new(
		source_root => $source_dir,
		dest_root   => $dest_dir,
		dest_url    => $base_url,
		verbose     => $verbose
	);
	$htmldocs->convert_pods;
}

sub write_index {
	my ($fh, $base_url) = @_;
	print $fh <<EOF;
<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
<meta charset='UTF-8'>
<link rel="shortcut icon" href="/favicon.ico">
<link href="$base_url/css/pod.css" rel="stylesheet">
<title>WeBWorK/PG POD</title>
</head>
<body>
<h1>WeBWorK/PG POD</h1>
<h2>(Plain Old Documentation)</h2>
<div>
<ul>
EOF

	print $fh q{<li><a href="pg">PG</a></li>}            if $pg_root;
	print $fh q{<li><a href="webwork2">WeBWorK</a></li>} if $webwork_root;

	print $fh "</ul></div></body></html>";
}

1;
