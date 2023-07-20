###############################################################################
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

package WeBWorK::ContentGenerator::LTIAdvantage;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

use WeBWorK::Authen::LTIAdvantage::SubmitGrade;
use WeBWorK::Debug;

sub login ($c) {
	return $c->render('ContentGenerator/LTIAdvantage/login_repost');
}

sub launch ($c) {
	return $c->redirect_to($c->systemLink($c->url_for($c->stash->{LTILauncRedirect})));
}

sub keys ($c) {
	my ($public_keyset, $err) = WeBWorK::Authen::LTIAdvantage::SubmitGrade::get_site_key($c->ce);
	return $c->render(json => $public_keyset) if $public_keyset;

	debug("Error loading or generating site keys: $err");
	return $c->render(data => 'Internal site configuration error', status => 500);
}

1;
