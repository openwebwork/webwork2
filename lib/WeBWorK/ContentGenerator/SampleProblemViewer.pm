package WeBWorK::ContentGenerator::SampleProblemViewer;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

use File::Basename qw(basename);
use Pod::Simple::Search;

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

1;
