#!/usr/bin/env perl

=head1 NAME

build-search-db.pl - Build a search file for the samples problems and POD files.

=head1 SYNOPSIS

build-search-db.pl [options]

 Options:
   -p|--pg-root          Directory containing  a git clone of pg.
                         If this option is not set, then the environment
                         variable $PG_ROOT will be used if it is set.
   -f|--json-file        Location (relative to WW_ROOT) to store the resulting JSON file.
                         Default value is htdocs/DATA/search.json
   -s|--sample-prob-dir  Location (relative to $PG_ROOT) where the sample problems are located.
                         Default value is tutorial/samples-problems
   -b|--build            One of (all, macros, samples) to determine if the macros, sample
                         problems or both should be scraped for data.
   -v|--verbose          Setting this flag provides details as the script runs.

Note that --pg-root must be provided or the PG_ROOT environment variable set
if the POD for pg is desired.

=head1 DESCRIPTION

Read through all of the files in $PG_ROOT/tutorial/samples-problems and the POD in the macro files.
The result is a JSON file containing information about every file to be searched for in the sample-problems
space.

=cut

use strict;
use warnings;

use feature "say";

use Getopt::Long qw(:config bundling);
use File::Find;
use Mojo::JSON qw(encode_json);
use Mojo::File qw(path curfile);
use Pod::Simple::SimpleTree;

my $build   = "all";
my $pg_root = $ENV{PG_ROOT};
# These are the default sample problem directory and JSON file.
my $dir       = "tutorial/sample-problems";
my $json_file = "htdocs/DATA/search.json";
my $verbose   = 0;

GetOptions(
	'p|pg-root=s'         => \$pg_root,
	'f|json-file=s'       => \$json_file,
	's|sample-prob-dir=s' => \$dir,
	'b|build=s'           => \$build,
	'v|verbose+'          => \$verbose
);

die "The build options must be one of (all, macros, samples). The value $build is not valid."
	if ((grep { $_ eq $build } qw/all macros samples/) == 0);

my $ww_root = $ENV{WW_ROOT};
$ww_root = Mojo::File->new(curfile->dirname, "..", "..")->realpath unless defined($ww_root);

die "ww_root: $ww_root is not a directory" unless -d $ww_root;

$dir       = "$pg_root/$dir";
$json_file = path("$ww_root/$json_file");

my $json_dir = $json_file->dirname;
$json_dir->make_path unless -d $json_dir;

if ($verbose) {
	say "Running script build-search-data with the following options:";
	say "    pg-root: $pg_root";
	say "    ww-root: $ww_root";
	say "    build: $build";
	say "    dir: $dir";
	say "    json_file: $json_file";
}

#
my $stop_words = {};

# Load the Stop Words File
open(my $FH, '<:encoding(UTF-8)', "$ww_root/bin/dev_scripts/stop-words-en.txt") or do {
	warn qq{Could not open file "$ww_root/bin/dev_scripts/stop-words-en.txt": $!};
};
my @stop_words = <$FH>;
chomp for (@stop_words);

# Store all of search info for each file and store as an array of hashrefs.
my @search_terms;

my $index = 1;    # set an index for each file.

sub processFile {
	return unless $_ =~ /\.pg$/;
	say "Processing $_" if $verbose;

	my $filename = $_;

	open(my $FH, '<:encoding(UTF-8)', $File::Find::name) or do {
		warn qq{Could not open file "$File::Find::name": $!};
		return {};
	};
	my @file_contents = <$FH>;
	close $FH;

	my (@words, @kw, @macros, @subjects, $name, $description);

	# For each line if it is documentation, or a loadMacors or a KEYWORDS line
	while (my $line = shift @file_contents) {
		chomp($line);
		# This processes all of the documentation lines within a sample problem.
		if ($line =~ /^#:[^%]/) {
			$line =~ s/^#:\s+//;
			push(@words, processLine($line));
		} elsif ($line =~ /^#:%\s*(\w+)\s*=\s*(.*)\s*$/) {
			# Store the name of the sample problem and the subjects.
			$name = $2 if $1 eq 'name';
			if ($1 eq 'subject') {
				@subjects = split(',\s*', $2 =~ s/\[(.*)\]/$1/r);
			}
		} elsif ($line =~ /^loadMacros/) {
			# Parse the macros, which may be on multiple rows.
			my $macros = $line;
			while ($line && $line !~ /\);\s*$/) {
				$line = shift @file_contents;
				chomp($line);
				$macros .= $line;
			}
			my @all_macros = map {s/['"\s]//gr} split(/\s*,\s*/, $macros =~ s/loadMacros\((.*)\)\;$/$1/r);

			# Only store macros that are not common.
			my @macros;
			for my $m (@all_macros) {
				push(@macros, $m) unless $m =~ /(PGML|PGstandard|PGcourse)/;
			}
		} elsif ($line =~ /##\s*KEYWORDS\((.*)\)/) {
			@kw = map {s/^'(.*)'$/$1/r} split(/,\s*/, $1);
		} elsif ($line =~ /^##\s*DESCRIPTION/) {
			$line = shift(@file_contents) =~ s/^##\s+//r;
			while ($line !~ /ENDDESCRIPTION/) {
				$description .= "$line ";
				$line = shift(@file_contents) =~ s/^##\s+//r;
			}
			$description =~ s/\s+$//;
		}
	}
	push(
		@search_terms,
		{
			filename    => $filename,
			type        => 'sample problem',
			name        => $name,
			subjects    => \@subjects,
			terms       => \@words,
			keywords    => \@kw,
			description => $description,
			dir         => Mojo::File->new($File::Find::dir)->basename,
			id          => $index++
		}
	);
}

sub processLine {
	my ($line) = @_;
	my @split_line = split(/\s+/, $line);

	my @words = ();
	for my $word (@split_line) {

		# The following lines pull out some formating.
		$word =~ s/(PODLINK|PROBLINK)\('([\w.]+)'\)/$2/;
		$word =~ s/`(.*)`/$1/;
		$word =~ s/[.!,]$//;
		$word =~ s/[()\*\\\+\{\}]//g;
		$word = lc($word);
		next if $word =~ /\[|\]|\d|=/;

		my @result = grep {/^${word}$/} @stop_words;
		push(@words, $word) unless @result;

	}
	return @words;
}

# Extract the text for a section from the given POD (preparsed) with a section header title
sub extractPODNode {
	my ($root, $title) = @_;
	my @index = grep { ref($root->[$_]) eq 'ARRAY' && $root->[$_][2] =~ /$title/ } 0 .. scalar(@$root) - 1;
	if (@index == 0) {
		warn "The section named $title is not found in the POD.";
		return;
	}
	if (@index > 1) {
		warn "There were more than one section named $title in the POD.";
		return;
	}
	# start at the index 2 and extract all text
	my $node = $root->[ $index[0] + 1 ];
	my $i    = 2;
	my $str  = "";
	do {
		$str .= (ref($node->[$i]) eq 'ARRAY') ? $node->[$i][2] : $node->[$i];
		$i++;
	} while ($i < scalar(@$node));

	return $str;
}

sub processPODFile {
	my ($filename) = @_;
	my $parser     = Pod::Simple::SimpleTree->new();
	my $root       = $parser->parse_file("$filename")->root;

	return {
		type        => "macro",
		name        => extractPODNode($root, "NAME") // '',
		description => [ processLine(extractPODNode($root, "DESCRIPTION") // '') ]
	};
}

# Process the sample problems in $dir.

find({ wanted => \&processFile }, "$dir") if (grep { $build eq $_ } qw/all samples/);

# Process the POD within the macros dir.

if (grep { $build eq $_ } qw/all macros/) {
	my $macro_dir = Mojo::File->new("$pg_root/macros/math");
	my $macros    = $macro_dir->list->each(sub {
		say "processing " . $_->basename if $verbose;
		my $pod_file = processPODFile($_);
		$pod_file->{filename} = $_->basename;
		$pod_file->{id}       = $index++;
		$pod_file->{dir}      = $_->dirname->to_rel("$pg_root")->to_string;
		push(@search_terms, $pod_file);
	});
}

my $json = encode_json \@search_terms;

say "Writing document info to $json_file" if $verbose;
$json_file->spew($json);

