#!/usr/bin/perl
################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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

package PODtoHTML;

use File::Find qw(find);
use File::Path qw(make_path);
use IO::File;
use Pod::Find qw(contains_pod);
use POSIX qw(strftime);
use PODParser;

our @sections = (
	'/'     => "(root)",
	bin     => "Scripts",
	conf    => "Config Files",
	doc     => "Documentation",
	lib     => "Libraries",
	macros  => "Macros",
	clients => "Clients"
);

sub new {
	my ($invocant, %o) = @_;
	my $class = ref $invocant || $invocant;

	my @section_list = ref($o{sections}) eq 'ARRAY' ? @{$o{sections}} : @sections;
	my $section_hash = {@section_list};
	my $section_order = [ map { $section_list[2 * $_] } 0 .. $#section_list / 2 ];
	delete $o{sections};

	my $self = {
		%o,
		idx => {},
		section_hash => $section_hash,
		section_order => $section_order,
	};
	return bless $self, $class;
}

sub convert_pods {
	my $self = shift;
	my $source_root = $self->{source_root};
	my $dest_root = $self->{dest_root};

	find({ wanted => $self->gen_pod_wanted, no_chdir => 1 }, $source_root);
	$self->write_index("$dest_root/index.html");
}

sub gen_pod_wanted {
	my $self = shift;
	return sub {
		my $path = $File::Find::name;
		my $dir = $File::Find::dir;
		my ($name) = $path =~ m|^$dir(?:/(.*))?$|;
		$name = '' unless defined $name;

		if ($name =~ /^\./) {
			$File::Find::prune = 1;
			return;
		}
		unless (-f $path or -d $path) {
			$File::Find::prune = 1;
			return;
		}
		if (-d _ and $name =~ /^(\.git|\.github|t|htdocs)$/) {
			$File::Find::prune = 1;
			return;
		}

		return if -d _;
		return unless contains_pod($path);

		print "Processing file: $path\n" if $self->{verbose} > 1;

		$self->process_pod($path);
	};
}

sub process_pod {
	my ($self, $pod_path) = @_;

	my $pod_name;

	my ($subdir, $filename) = $pod_path =~ m|^$self->{source_root}/(?:(.*)/)?(.*)$|;

	my ($subdir_first, $subdir_rest) = ('', '');

	if (defined $subdir) {
		if ($subdir =~ m|/|) {
			($subdir_first, $subdir_rest) = $subdir =~ m|^([^/]*)/(.*)|;
		} else {
			$subdir_first = $subdir;
		}
	}

	$pod_name = (defined $subdir_rest ? "$subdir_rest/" : "") . $filename;
	if ($filename =~ /\.pl$/) {
		$filename =~ s/\.pl$/.html/;
	} elsif ($filename =~ /\.pod$/) {
		$pod_name =~ s/\.pod$//;
		$filename =~ s/\.pod$/.html/;
	} elsif ($filename =~ /\.pm$/) {
		$pod_name =~ s/\.pm$//;
		$pod_name =~ s|/+|::|g;
		$filename =~ s/\.pm$/.html/;
	} elsif ($filename !~ /\.html$/) {
		$filename .= ".html";
	}

	$pod_name =~ s/^(\/|::)//;

	my $html_dir = $self->{dest_root} . (defined $subdir ? "/$subdir" : "");
	my $html_path = "$html_dir/$filename";
	my $html_rel_path = defined $subdir ? "$subdir/$filename" : $filename;

	$self->update_index($subdir, $html_rel_path, $pod_name);
	make_path($html_dir);
	my $html = $self->do_pod2html(
		pod_path => $pod_path,
		pod_name => $pod_name
	);
	my $fh = new IO::File($html_path, '>')
		or die "Failed to open file '$html_path' for writing: $!\n";
	print $fh $html;
}

sub update_index {
	my ($self, $subdir, $html_rel_path, $pod_name) = @_;
	$subdir =~ s|/.*$||;
	my $idx = $self->{idx};
	my $sections = $self->{section_hash};
	if (exists $sections->{$subdir}) {
		push @{$idx->{$subdir}}, [ $html_rel_path, $pod_name ];
	} else {
		warn "no section for subdir '$subdir'\n";
	}
}

sub write_index {
	my ($self, $out_path) = @_;
	my $idx = $self->{idx};
	my $sections = $self->{section_hash};
	my $section_order = $self->{section_order};
	my $source_root = $self->{source_root};
	$source_root =~ s|^.*/||;

	my $title = "Index for $source_root";
	my $content_start = "<ul>";
	my $content = "";

	for my $section (@$section_order) {
		next unless defined $idx->{$section};
		my $section_name = $sections->{$section};
		$content_start .= qq{<li><a href="#$section">$section_name</a></li>};
		my @files = sort @{$idx->{$section}};
		$content .= qq{<a name="$section"></a>};
		$content .= qq{<h2><a href="#_podtop_">$section_name</a></h2><ul>};
		for my $file (sort { $a->[1] cmp $b->[1] } @files) {
			my ($path, $name) = @$file;
			$content .= qq{<li><a href="$path">$name</a></li>};
		}
		$content .= "</ul>";
	}

	$content_start .= "</ul>";
	my $date = strftime "%a %b %e %H:%M:%S %Z %Y", localtime;

	my $fh = new IO::File($out_path, '>') or die "Failed to open index '$out_path' for writing: $!\n";
	print $fh (
		get_header($title),
		$content_start,
		$content,
		"<p>Generated $date</p>",
		get_footer()
	);
}

sub do_pod2html {
	my $self = shift;
	my %o = @_;
	my $psx = new PODParser;
	$psx->{source_root} = $self->{source_root};
	$psx->{verbose} = $self->{verbose};
	$psx->{base_url} = ($self->{dest_url} // "") . "/" . (($self->{source_root} // "") =~ s|^.*/||r);
	$psx->output_string(\my $html);
	$psx->html_header(get_header($o{pod_name}));
	$psx->html_footer(get_footer());
	$psx->parse_file($o{pod_path});
	return $html;
}

sub get_header {
	my $title = shift;
	return <<EOF
<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
<meta charset='UTF-8'>
<link rel="icon" href="/favicon.ico">
<title>$title</title>
</head>
<body>
<h1>$title</h1>
<div style="margin-left:20px">Jump to: <a href="#column-one">Site Navigation</a></div>
<hr>
<div id="_podtop_">
EOF
}

sub get_footer {
	return <<'EOF';
</div>
<hr>
<div id="column-one">
<h5>Site Navigation</h5>
<div>
<ul>
<li><a href="/pod">WeBWorK POD Home</a></li>
<li><a href="http://webwork.maa.org/wiki/WeBWorK_Main_Page">WeBWorK Wiki</a></li>
</ul>
</div>
</div>
</body>
</html>
EOF
}

1;


