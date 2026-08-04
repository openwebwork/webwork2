#!/usr/bin/env perl

=head1 NAME

generate-ww-pg-pod.pl - Convert WeBWorK and PG POD into HTML form.

=head1 SYNOPSIS

generate-ww-pg-pod.pl [options]

 Options:
   -o|--output-dir       Directory to save the output files to. (required)
   -b|--base-url         Base url location used on server. (default: /)
                         This is needed for internal POD links to work correctly.
   -v|--verbose          Increase the verbosity of the output.
                         (Use multiple times for more verbosity.)

Note that C<pg_dir> must be set in the C<conf/webwork2.mojolicious.yml> file, or
if that file does not exist then the clone of the PG repository must be located
at C</opt/webwork/pg> as defined in the C<conf/webwork2.mojolicious.dist.yml>
file.

=head1 DESCRIPTION

Convert WeBWorK and PG POD into HTML form.

=cut

use strict;
use warnings;

my ($webwork_root, $pg_root);

BEGIN {
	use File::Basename qw(dirname);
	use Cwd            qw(abs_path);
	use YAML::XS       qw(LoadFile);

	$webwork_root = abs_path(dirname(dirname(dirname(__FILE__))));

	# Load the configuration file to obtain the PG root directory.
	my $config_file = "$webwork_root/conf/webwork2.mojolicious.yml";
	$config_file = "$webwork_root/conf/webwork2.mojolicious.dist.yml" unless -e $config_file;
	my $config = LoadFile($config_file);

	$pg_root = $config->{pg_dir};
}

use Getopt::Long qw(:config bundling);
use Pod::Usage;

my ($output_dir, $base_url);
my $verbose = 0;
GetOptions(
	'o|output-dir=s' => \$output_dir,
	'b|base-url=s'   => \$base_url,
	'v|verbose+'     => \$verbose
);

pod2usage(2) unless $output_dir && $pg_root && -d $pg_root;

$base_url = "/" if !$base_url;

use Mojo::Template;
use IO::File;
use File::Copy;
use File::Path qw(make_path remove_tree);

use lib "$webwork_root/lib";
use lib "$pg_root/lib";

use WeBWorK::Utils::PODtoHTML;

for my $dir ($webwork_root, $pg_root) {
	next unless $dir && -d $dir;
	print "Reading: $dir\n" if $verbose;
	process_dir($dir);
}

my $index_fh = IO::File->new("$output_dir/index.html", '>')
	or die "failed to open '$output_dir/index.html' for writing: $!\n";
write_index($index_fh);

make_path("$output_dir/assets");
copy("$pg_root/htdocs/js/PODViewer/podviewer.css", "$output_dir/assets/podviewer.css");
print "copying $pg_root/htdocs/js/PODViewer/podviewer.css to $output_dir/assets/podviewer.css\n" if $verbose;
copy("$pg_root/htdocs/js/PODViewer/podviewer.js", "$output_dir/assets/podviewer.js");
print "copying $pg_root/htdocs/js/PODViewer/podviewer.css to $output_dir/assets/podviewer.js\n" if $verbose;

sub process_dir {
	my $source_dir = shift;
	return unless $source_dir =~ /\/webwork2$/ || $source_dir =~ /\/pg$/;

	my $dest_dir = $source_dir;
	$dest_dir =~ s/^$webwork_root/$output_dir\/webwork2/ if ($source_dir =~ /\/webwork2$/);
	$dest_dir =~ s/^$pg_root/$output_dir\/pg/            if ($source_dir =~ /\/pg$/);

	remove_tree($dest_dir);
	make_path($dest_dir);

	my $htmldocs = WeBWorK::Utils::PODtoHTML->new(
		source_root        => $source_dir,
		dest_root          => $dest_dir,
		template_dir       => "$pg_root/assets/pod-templates",
		dest_url           => $base_url,
		home_url           => $base_url,
		home_url_link_name => 'WeBWorK POD Home',
		page_url           => $base_url . ($source_dir =~ s|^.*/||r),
		verbose            => $verbose
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
