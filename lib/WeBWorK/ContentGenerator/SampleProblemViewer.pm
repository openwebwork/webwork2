################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::SampleProblemViewer;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

use File::Basename qw(basename);
use Pod::Simple::Search;

use SampleProblemParser qw(parseSampleProblem generateMetadata);

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

	(undef, my $macro_files) = Pod::Simple::Search->new->inc(0)->survey("$pg_root/macros");
	my %macro_locations = map { basename($_) => $_ =~ s!$pg_root/macros/!!r } keys %$macro_files;
	my $metadata        = generateMetadata("$pg_root/tutorial/sample-problems", macro_locations => \%macro_locations);

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
	} elsif ($c->stash->{filePath} =~ /\.pg$/) {
		unless ($metadata->{ basename($c->stash->{filePath}) }) {
			return $c->render(data => $c->maketext('File not found.'));
		}

		# Render the .pg file as a downloadable file.
		return $c->render_file(
			data => parseSampleProblem(
				"$pg_root/tutorial/sample-problems/" . $c->stash->{filePath},
				metadata    => $metadata,
				pod_root    => $c->url_for('pod_index'),
				pg_doc_home => $c->url_for('sample_problem_index')
			)->{code}
		);
	} else {
		unless ($metadata->{ basename($c->stash->{filePath}) . '.pg' }) {
			$c->render(data => $c->maketext('Sample problem not found.'));
		}

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
