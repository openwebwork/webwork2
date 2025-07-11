package WeBWorK::ContentGenerator::SampleProblemViewer;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

use File::Basename qw(basename);
use Mojo::File;
use Mojo::JSON qw(decode_json encode_json);
use File::Find;
use Pod::Simple::Search;
use Pod::Simple::SimpleTree;

use WeBWorK::Utils::Files qw(path_is_subdir);
use SampleProblemParser   qw(parseSampleProblem generateMetadata getSampleProblemCode);

=head1 NAME

WeBWorK::ContentGenerator::SampleProblemViewer - display locally sample problems.

=head2 C<sampleProblemIndex>

Generates an index file to browse the sample problems.

=cut

sub sampleProblemIndex ($c) {
	return $c->render('ContentGenerator/SampleProblemViewer');
}

=head2 C<renderSampleProblem>

Render the requestedSampleProblem or one of the indexes.

=cut

sub renderSampleProblem ($c) {
	my $pg_root = $c->ce->{pg_dir};

	if ($c->stash->{filePath} =~ /\.pg$/) {
		my $sampleProblemFile = "$pg_root/tutorial/sample-problems/" . $c->stash->{filePath};
		return $c->render(data => $c->maketext('File not found.'))
			unless path_is_subdir($sampleProblemFile, $c->ce->{pg_dir} . '/tutorial/sample-problems')
			&& -r $sampleProblemFile;

		# Render the .pg file as a downloadable file.
		return $c->render_file(data => getSampleProblemCode($sampleProblemFile));
	}

	my $metadata = generateMetadata("$pg_root/tutorial/sample-problems");

	if (grep { $c->stash->{filePath} eq $_ } qw(categories techniques subjects macros)) {
		my %labels = (
			categories => $c->maketext('Categories'),
			subjects   => $c->maketext('Subject Areas'),
			macros     => $c->maketext('Problems by Macro'),
			techniques => $c->maketext('Problem Techniques')
		);

		my $list = {};
		if ($c->stash->{filePath} =~ /^(categories|subjects|macros)$/) {
			for my $sample_file (keys %$metadata) {
				for my $category (@{ $metadata->{$sample_file}{ $c->stash->{filePath} } }) {
					$list->{$category}{ $metadata->{$sample_file}{name} } =
						"$metadata->{$sample_file}{dir}/" . ($sample_file =~ s/\.pg$//r);
				}
			}
		} elsif ($c->stash->{filePath} eq 'techniques') {
			for my $sample_file (keys %$metadata) {
				if (grep { $_ eq 'technique' } @{ $metadata->{$sample_file}{types} }) {
					$list->{ $metadata->{$sample_file}{name} } =
						"$metadata->{$sample_file}{dir}/" . ($sample_file =~ s/\.pg$//r);
				}
			}
		}

		# Render one of the four indexes.
		return $c->render(
			template => 'ContentGenerator/SampleProblemViewer/viewer',
			label    => $labels{ $c->stash->{filePath} },
			list     => $list
		);
	} else {
		unless ($metadata->{ basename($c->stash->{filePath}) . '.pg' }) {
			$c->render(data => $c->maketext('Sample problem not found.'));
		}

		(undef, my $macro_files) = Pod::Simple::Search->new->inc(0)->survey("$pg_root/macros");
		my %macro_locations = map { basename($_) => $_ =~ s!$pg_root/macros/!!r } keys %$macro_files;

		# Render a problem with its documentation.
		my $problemFile = "$pg_root/tutorial/sample-problems/" . $c->stash->{filePath} . '.pg';
		return $c->render(
			'ContentGenerator/SampleProblemViewer/sample_problem',
			%{
				parseSampleProblem(
					$problemFile,
					metadata        => $metadata,
					pod_root        => $c->url_for('pod_viewer', filePath => 'macros'),
					pg_doc_home     => $c->url_for('sample_problem_index'),
					macro_locations => \%macro_locations,
				)
			},
			metadata        => $metadata,
			filename        => basename($problemFile),
			macro_locations => \%macro_locations,
		);
	}
}

sub searchData ($c) {
	my $sampleProblemDir = $c->ce->{pg_dir} . '/tutorial/sample-problems';

	my $searchDataFile = Mojo::File->new($c->ce->{webworkDirs}{DATA})->child('sample-problem-search-data.json');
	my %files = map { $_->{filename} => $_ } @{ (eval { decode_json($searchDataFile->slurp('UTF-8')) } // []) };
	my @updatedFiles;

	# Process the sample problems in the sample problem directory.
	find(
		{
			wanted => sub {
				return unless $_ =~ /\.pg$/;

				my $file         = Mojo::File->new($File::Find::name);
				my $lastModified = $file->stat->mtime;

				if ($files{$_}) {
					push(@updatedFiles, $files{$_});
					return if $files{$_}{lastModified} >= $lastModified;
				}

				my @fileContents = eval { split("\n", $file->slurp('UTF-8')) };
				return if $@;

				if (!$files{$_}) {
					$files{$_} = {
						type     => 'sample problem',
						filename => $_,
						dir      => $file->dirname->basename
					};
					push(@updatedFiles, $files{$_});
				}
				$files{$_}{lastModified} = $lastModified;

				my (%words, @kw, @macros, @subjects, $description);

				while (@fileContents) {
					my $line = shift @fileContents;
					if ($line =~ /^#:%\s*(\w+)\s*=\s*(.*)\s*$/) {
						# Store the name and subjects.
						$files{$_}{name} = $2 if $1 eq 'name';
						if ($1 eq 'subject') {
							@subjects = split(',\s*', $2 =~ s/\[(.*)\]/$1/r);
						}
					} elsif ($line =~ /^#:\s*(.*)?/) {
						my @newWords = $c->processLine($1);
						@words{@newWords} = (1) x @newWords if @newWords;
					} elsif ($line =~ /loadMacros\(/) {
						my $macros = $line;
						while ($line && $line !~ /\);\s*$/) {
							$line = shift @fileContents;
							$macros .= $line;
						}
						my @usedMacros =
							map {s/['"\s]//gr} split(/\s*,\s*/, $macros =~ s/loadMacros\((.*)\)\;$/$1/r);

						# Get the macros other than PGML.pl, PGstandard.pl, and PGcourse.pl.
						for my $m (@usedMacros) {
							push(@macros, $m) unless $m =~ /^(PGML|PGstandard|PGcourse)\.pl$/;
						}
					} elsif ($line =~ /##\s*KEYWORDS\((.*)\)/) {
						@kw = map {s/^'(.*)'$/$1/r} split(/,\s*/, $1);
					} elsif ($line =~ /^##\s*DESCRIPTION/) {
						$line = shift(@fileContents);
						while ($line && $line !~ /^##\s*ENDDESCRIPTION/) {
							$description .= ($line =~ s/^##\s+//r) . ' ';
							$line = shift(@fileContents);
						}
						$description =~ s/\s+$//;
					}
				}

				$files{$_}{description} = $description;
				$files{$_}{subjects}    = \@subjects;
				$files{$_}{terms}       = [ keys %words ];
				$files{$_}{keywords}    = \@kw;
				$files{$_}{macros}      = \@macros;

				return;
			}
		},
		$sampleProblemDir
	);

	# Process the POD in macros in the macros dir.
	(undef, my $macro_files) = Pod::Simple::Search->new->inc(0)->survey($c->ce->{pg_dir} . "/macros");
	for my $macroFile (sort keys %$macro_files) {
		next if $macroFile =~ /deprecated/;

		my $file         = Mojo::File->new($macroFile);
		my $fileName     = $file->basename;
		my $lastModified = $file->stat->mtime;

		if ($files{$fileName}) {
			push(@updatedFiles, $files{$fileName});
			next if $files{$fileName}{lastModified} >= $lastModified;
		}

		if (!$files{$fileName}) {
			$files{$fileName} = {
				type     => 'macro',
				id       => scalar(keys %files) + 1,
				filename => $fileName,
				dir      => $file->dirname->to_rel($c->ce->{pg_dir})->to_string
			};
			push(@updatedFiles, $files{$fileName});
		}
		$files{$fileName}{lastModified} = $lastModified;

		my $root = Pod::Simple::SimpleTree->new->parse_file($file->to_string)->root;

		$files{$fileName}{terms} = $c->extractHeaders($root);

		if (my $nameDescription = extractHeadText($root, 'NAME')) {
			(undef, my $description) = split(/\s*-\s*/, $nameDescription, 2);
			$files{$fileName}{description} = $description if $description;
		}
	}

	# Redindex in case files were added or removed.
	my $count = 0;
	$_->{id} = ++$count for @updatedFiles;

	$searchDataFile->spew(encode_json(\@updatedFiles), 'UTF-8');

	return $c->render(json => \@updatedFiles);
}

# Get the stop words.  The stop words file is loaded the first time this method is called,
# and is stashed and returned in later calls.
sub stopWords ($c) {
	return $c->stash->{stopWords} if $c->stash->{stopWords};
	$c->stash->{stopWords} = {};

	my $contents = eval { $c->app->home->child('assets', 'stop-words-en.txt')->slurp('UTF-8') };
	return $c->stash->{stopWords} if $@;

	for my $line (split("\n", $contents)) {
		chomp $line;
		next if $line =~ /^#/ || !$line;
		$c->stash->{stopWords}{$line} = 1;
	}

	return $c->stash->{stopWords};
}

sub processLine ($c, $line) {
	my %words;

	# Extract linked macros and problems.
	my @linkedFiles = $line =~ /(?:PODLINK|PROBLINK)\('([\w.]+)'\)/g;
	$words{$_} = 1 for @linkedFiles;

	# Replace any non-word characters with spaces.
	$line =~ s/\W/ /g;

	for my $word (split(/\s+/, $line)) {
		next if $word =~ /^\d*$/;
		$word = lc($word);
		$words{$word} = 1 if !$c->stopWords->{$word};
	}
	return keys %words;
}

# Extract the text for a section from the given POD with a section header title.
sub extractHeadText ($root, $title) {
	my @index = grep { ref($root->[$_]) eq 'ARRAY' && $root->[$_][2] eq $title } 0 .. $#$root;
	return unless @index == 1;

	my $node = $root->[ $index[0] + 1 ];
	my $str  = '';
	for (2 .. $#$node) {
		$str .= ref($node->[$_]) eq 'ARRAY' ? $node->[$_][2] : $node->[$_];
	}
	return $str;
}

# Extract terms form POD headers.
sub extractHeaders ($c, $root) {
	my %terms =
		map  { $_ => 1 }
		grep { $_ && !$c->stopWords->{$_} }
		map  { split(/\s+/, $_) }
		map  { lc($_) =~ s/\W/ /gr }
		map {
			grep { !ref($_) }
			@$_[ 2 .. $#$_ ]
		}
		grep { ref($_) eq 'ARRAY' && $_->[0] =~ /^head\d+$/ } @$root;
	return [ keys %terms ];
}

1;
