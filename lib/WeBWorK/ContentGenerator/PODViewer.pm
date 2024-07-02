################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::PODViewer;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::PODViewer - display POD for PG macros.

=cut

use Pod::Simple::Search;
use Mojo::DOM;

use WeBWorK::Utils::PODParser;

sub PODindex ($c) {
	my $pgRoot = $c->ce->{pg_dir};

	my $podFiles = Pod::Simple::Search->new->inc(0)->limit_re(qr/^doc|^lib|^macros/)->survey($pgRoot);

	my $sections = {};
	for (sort keys %$podFiles) {
		my $section = $_ =~ s/::.*$//r;
		push(@{ $sections->{$section} }, $podFiles->{$_} =~ s!^$pgRoot/$section/!!r);
	}

	return $c->render('ContentGenerator/PODViewer', sections => $sections, sidebar_title => $c->maketext('Categories'));
}

sub renderPOD ($c) {
	my $macroFile = $c->ce->{pg_dir} . '/' . $c->stash->{filePath};

	if (-e $macroFile) {
		my $parser = WeBWorK::Utils::PODParser->new(
			Pod::Simple::Search->new->inc(0)->limit_re(qr/^doc|^lib|^macros/)->survey($c->ce->{pg_dir}));
		$parser->{verbose}     = 0;
		$parser->{source_root} = $c->ce->{pg_dir};
		$parser->{base_url}    = $c->url_for('pod_index')->to_string;
		$parser->html_header('');
		$parser->html_footer('');
		$parser->output_string(\my $html);

		eval { $parser->parse_file($macroFile) };
		if ($@) {
			$c->stash->{podError} = $@;
		} else {
			my $dom      = Mojo::DOM->new($html);
			my $podIndex = $dom->at('ul[id="index"]');
			$c->stash->{podIndex} = $podIndex ? $podIndex->find('ul[id="index"] > li') : $c->c;
			for (@{ $c->stash->{podIndex} }) {
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
			$c->stash->{podHTML} = $podIndex ? $podIndex->remove : $html;
		}
	}

	return $c->render('ContentGenerator/PODViewer/POD', sidebar_title => $c->maketext('Index'));
}

1;
