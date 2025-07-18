package PODtoHTML;

use strict;
use warnings;
use utf8;

use Pod::Simple::Search;
use Mojo::Template;
use Mojo::DOM;
use Mojo::Collection qw(c);
use File::Path       qw(make_path);
use File::Basename   qw(dirname);
use IO::File;
use POSIX qw(strftime);

use WeBWorK::Utils::PODParser;

our @sections = (
	doc    => 'Documentation',
	bin    => 'Scripts',
	macros => 'Macros',
	lib    => 'Libraries',
);
our %macro_names = (
	answers    => 'Answers',
	contexts   => 'Contexts',
	core       => 'Core',
	deprecated => 'Deprecated',
	graph      => 'Graph',
	math       => 'Math',
	misc       => 'Miscellaneous',
	parsers    => 'Parsers',
	ui         => 'User Interface'
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
		macros_hash   => {},
	};
	return bless $self, $class;
}

sub convert_pods {
	my $self        = shift;
	my $source_root = $self->{source_root};
	my $dest_root   = $self->{dest_root};

	my $regex = join('|', map {"^$_"} @{ $self->{section_order} });

	my ($name2path, $path2name) = Pod::Simple::Search->new->inc(0)->limit_re(qr!$regex!)->survey($self->{source_root});
	for (keys %$path2name) {
		print "Processing file: $_\n" if $self->{verbose} > 1;
		$self->process_pod($_, $name2path);
	}

	$self->write_index("$dest_root/index.html");

	return;
}

sub process_pod {
	my ($self, $pod_path, $pod_files) = @_;

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

	$pod_name = (defined $subdir_rest ? "$subdir_rest/" : '') . $filename;
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
		$filename .= '.html';
	}

	$pod_name =~ s/^(\/|::)//;

	my $html_dir      = $self->{dest_root} . (defined $subdir ? "/$subdir" : '');
	my $html_path     = "$html_dir/$filename";
	my $html_rel_path = defined $subdir ? "$subdir/$filename" : $filename;

	$self->update_index($subdir, $html_rel_path, $pod_name);
	make_path($html_dir);
	my $html = $self->do_pod2html(
		pod_path  => $pod_path,
		pod_name  => $pod_name,
		pod_files => $pod_files
	);
	my $fh = IO::File->new($html_path, '>:encoding(UTF-8)')
		or die "Failed to open file '$html_path' for writing: $!\n";
	print $fh $html;

	return;
}

sub update_index {
	my ($self, $subdir, $html_rel_path, $pod_name) = @_;

	$subdir =~ s|/.*$||;
	my $idx      = $self->{idx};
	my $sections = $self->{section_hash};
	if ($subdir eq 'macros') {
		$idx->{macros} = [];
		if ($pod_name =~ m!^(.+)/(.+)$!) {
			push @{ $self->{macros_hash}{$1} }, [ $html_rel_path, $2 ];
		} else {
			push @{ $idx->{doc} }, [ $html_rel_path, $pod_name ];
		}
	} elsif (exists $sections->{$subdir}) {
		push @{ $idx->{$subdir} }, [ $html_rel_path, $pod_name ];
	} else {
		warn "no section for subdir '$subdir'\n";
	}

	return;
}

sub write_index {
	my ($self, $out_path) = @_;

	my $fh = IO::File->new($out_path, '>:encoding(UTF-8)') or die "Failed to open index '$out_path' for writing: $!\n";
	print $fh Mojo::Template->new(vars => 1)->render_file(
		"$self->{template_dir}/category-index.mt",
		{
			title         => 'POD for ' . ($self->{source_root} =~ s|^.*/||r),
			base_url      => $self->{dest_url},
			pod_index     => $self->{idx},
			sections      => $self->{section_hash},
			section_order => $self->{section_order},
			macros        => $self->{macros_hash},
			macros_order  => [ sort keys %{ $self->{macros_hash} } ],
			macro_names   => \%macro_names,
			date          => strftime('%a %b %e %H:%M:%S %Z %Y', localtime)
		}
	);

	return;
}

sub do_pod2html {
	my ($self, %o) = @_;

	my $psx = WeBWorK::Utils::PODParser->new($o{pod_files});
	$psx->{source_root}     = $self->{source_root};
	$psx->{verbose}         = $self->{verbose};
	$psx->{assert_html_ext} = 1;
	$psx->{base_url}        = ($self->{dest_url} // '') . '/' . (($self->{source_root} // '') =~ s|^.*/||r);
	$psx->output_string(\my $html);
	$psx->html_header('');
	$psx->html_footer('');
	$psx->parse_file($o{pod_path});

	my $dom        = Mojo::DOM->new($html);
	my $podIndexUL = $dom->at('ul[id="index"]');
	my $podIndex   = $podIndexUL ? $podIndexUL->find('ul[id="index"] > li') : c();
	for (@$podIndex) {
		$_->attr({ class => 'nav-item' });
		$_->at('a')->attr({ class => 'nav-link p-0' });
		for (@{ $_->find('ul') }) {
			$_->attr({ class => 'nav flex-column w-100' });
		}
		for (@{ $_->find('li') }) {
			$_->attr({ class => 'nav-item' });
			$_->at('a')->attr({ class => 'nav-link p-0' });
		}
	}
	my $podHTML = $podIndexUL ? $podIndexUL->remove : $html;

	return Mojo::Template->new(vars => 1)->render_file("$self->{template_dir}/pod.mt",
		{ title => $o{pod_name}, base_url => dirname($psx->{base_url}), index => $podIndex, content => $podHTML });
}

1;
