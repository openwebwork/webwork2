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

use File::Basename;
use YAML::XS qw(LoadFile);

use SampleProblemParser qw(buildIndex parseSampleProblem);

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

	my $metadata = LoadFile("$pg_root/doc/sample-problems/sample_prob_meta.yaml");

	# Render one of the four indexes.
	if (grep { $c->stash->{filePath} eq "$_.html" } (qw/categories techniques subjects macros/)) {
		my $type = $c->stash->{filePath} =~ s/.html$//r;
		warn 'here';
		my $params = buildIndex($type, metadata => $metadata);
		$c->app->log->debug($c->dumper($params));
		return $c->render(
			template => 'ContentGenerator/SampleProblemViewer/index_main',
			layout   => 'SampleProblemIndexLayout',
			sidebar  => $c->render_to_string('ContentGenerator/SampleProblemViewer/index_sidebar', %$params),
			%$params
		);
	} elsif ($c->stash->{filePath} =~ /\.html$/) {
		# Render a problem (as linked as a html file). This will generate the help documentation.
		my $macro_locations = LoadFile("$pg_root/doc/sample-problems/macro_pod.yaml");
		my $probFile        = "$pg_root/doc/sample-problems/" . $c->stash->{filePath} =~ s/\.html/.pg/r;
		my ($filename)      = fileparse($probFile);
		my $sample_problem  = parseSampleProblem($probFile, metadata => $metadata);
		return $c->render(
			'ContentGenerator/SampleProblemViewer/problem',
			%$sample_problem,
			metadata        => $metadata,
			filename        => $filename,
			macro_locations => $macro_locations,
			pod_root        => '/webwork2/pod/macros',
			pg_doc_home     => '/webwork2/sampleproblems'
		);
	} elsif ($c->stash->{filePath} =~ /\.pg$/) {
		# Render the .pg file as downloadable file.
		my $probFile = "$pg_root/doc/sample-problems/" . $c->stash->{filePath};
		$c->app->log->debug($probFile);
		my $sample_problem = parseSampleProblem($probFile, metadata => $metadata);
		return $c->render_file(data => $sample_problem->{code});
	}
}

1;
