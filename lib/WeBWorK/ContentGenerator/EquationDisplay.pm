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

package WeBWorK::ContentGenerator::EquationDisplay;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::EquationDisplay -- create .png version of TeX equations.

=cut

use WeBWorK::PG::ImageGenerator;

sub display_equation ($c, $str) {
	my $ce = $c->ce;

	my $image_gen = WeBWorK::PG::ImageGenerator->new(
		tempDir         => $ce->{webworkDirs}{tmp},
		latex           => $c->externalPrograms->{latex},
		dvipng          => $c->externalPrograms->{dvipng},
		useCache        => 1,
		cacheDir        => $ce->{webworkDirs}{equationCache},
		cacheURL        => $ce->{webworkURLs}{equationCache},
		cacheDB         => $ce->{webworkFiles}{equationCacheDB},
		useMarkers      => 1,
		dvipng_align    => 'baseline',
		dvipng_depth_db => { dbsource => '' },
	);

	my $imageTag = $image_gen->add($str, 'inline');
	$image_gen->render;
	return $imageTag;
}

sub initialize ($c) {
	my $equationStr = $c->param('eq') // '';

	# Prepare to display the typeset image and the HTML code that links to the source image.  The HTML code is linked
	# also to the image address This requires digging out the link from the string returned by display_equation and
	# ImageGenerator.  The server name and port are included in the new url.
	$c->stash->{typesetStr} = $equationStr ? $c->display_equation($equationStr) : '';

	# Add the host name to the string.
	my $hostName = $c->req->url->to_abs->host_port;
	$c->stash->{typesetStr} =~ s|src="|src="http://$hostName|;

	return;
}

1;
