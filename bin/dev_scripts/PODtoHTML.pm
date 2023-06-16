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

package PODtoHTML;

use strict;
use warnings;

use Pod::Simple::Search;
use File::Path qw(make_path);
use IO::File;
use POSIX qw(strftime);

use WeBWorK::Utils::PODParser;

our @sections = (
	bin    => "Scripts",
	conf   => "Config Files",
	doc    => "Documentation",
	lib    => "Libraries",
	macros => "Macros"
);

sub new {
	my ($invocant, %o) = @_;
	my $class = ref $invocant || $invocant;

	my @section_list  = ref($o{sections}) eq 'ARRAY' ? @{ $o{sections} } : @sections;
	my $section_hash  = {@section_list};
	my $section_order = [ map { $section_list[ 2 * $_ ] } 0 .. $#section_list / 2 ];
	delete $o{sections};

	my $self = {
		%o,
		idx           => {},
		section_hash  => $section_hash,
		section_order => $section_order,
	};
	return bless $self, $class;
}

sub convert_pods {
	my $self        = shift;
	my $source_root = $self->{source_root};
	my $dest_root   = $self->{dest_root};

	my $regex = join('|', map {"^$_"} @{ $self->{section_order} });

	(undef, my $podFiles) = Pod::Simple::Search->new->inc(0)->limit_re(qr!$regex!)->survey($self->{source_root});
	for (keys %$podFiles) {
		print "Processing file: $_\n" if $self->{verbose} > 1;
		$self->process_pod($_);
	}

	$self->write_index("$dest_root/index.html");

	return;
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

	my $html_dir      = $self->{dest_root} . (defined $subdir ? "/$subdir" : "");
	my $html_path     = "$html_dir/$filename";
	my $html_rel_path = defined $subdir ? "$subdir/$filename" : $filename;

	$self->update_index($subdir, $html_rel_path, $pod_name);
	make_path($html_dir);
	my $html = $self->do_pod2html(
		pod_path => $pod_path,
		pod_name => $pod_name
	);
	my $fh = IO::File->new($html_path, '>')
		or die "Failed to open file '$html_path' for writing: $!\n";
	print $fh $html;

	return;
}

sub update_index {
	my ($self, $subdir, $html_rel_path, $pod_name) = @_;

	$subdir =~ s|/.*$||;
	my $idx      = $self->{idx};
	my $sections = $self->{section_hash};
	if (exists $sections->{$subdir}) {
		push @{ $idx->{$subdir} }, [ $html_rel_path, $pod_name ];
	} else {
		warn "no section for subdir '$subdir'\n";
	}

	return;
}

sub write_index {
	my ($self, $out_path) = @_;

	my $source_root = $self->{source_root} =~ s|^.*/||r;
	my $title       = "Index for $source_root";

	my $content_start = '<ul>';
	my $content       = '';

	for my $section (@{ $self->{section_order} }) {
		next unless defined $self->{idx}{$section};
		$content_start .= qq{<li><a href="#$section">$self->{section_hash}{$section}</a></li>};
		$content       .= qq{<h2><a href="#_podtop_" id="$section">$self->{section_hash}{$section}</a></h2><ul>};
		for my $file (sort { $a->[1] cmp $b->[1] } @{ $self->{idx}{$section} }) {
			$content .= qq{<li><a href="$file->[0]">$file->[1]</a></li>};
		}
		$content .= '</ul>';
	}

	$content_start .= '</ul>';
	my $date = strftime '%a %b %e %H:%M:%S %Z %Y', localtime;

	my $fh = IO::File->new($out_path, '>') or die "Failed to open index '$out_path' for writing: $!\n";
	print $fh (get_header($title, $self->{dest_url}), $content_start, $content, "<p>Generated $date</p>", get_footer());

	return;
}

sub do_pod2html {
	my ($self, %o) = @_;
	my $psx = WeBWorK::Utils::PODParser->new;
	$psx->{source_root}     = $self->{source_root};
	$psx->{verbose}         = $self->{verbose};
	$psx->{assert_html_ext} = 1;
	$psx->{base_url}        = ($self->{dest_url} // "") . "/" . (($self->{source_root} // "") =~ s|^.*/||r);
	$psx->output_string(\my $html);
	$psx->html_header(get_header($o{pod_name}, "$psx->{base_url}/.."));
	$psx->html_footer(get_footer());
	$psx->parse_file($o{pod_path});
	return $html;
}

sub get_header {
	my ($title, $base_url) = @_;
	return << "EOF";
<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
<meta charset='UTF-8'>
<link rel="icon" href="/favicon.ico">
<title>$title</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.2.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="$base_url/css/pod.css" rel="stylesheet">
</head>
<body>
<div class="container mt-3">
<h1>$title</h1>
<hr>
<div>Jump to: <a href="#column-one">Site Navigation</a></div>
<hr>
<div id="_podtop_">
EOF
}

sub get_footer {
	return << 'EOF';
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
</div>
</body>
</html>
EOF
}

1;
