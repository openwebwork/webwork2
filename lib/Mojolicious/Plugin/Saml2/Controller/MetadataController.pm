package Mojolicious::Plugin::Saml2::Controller::MetadataController;

use Mojo::Base 'Mojolicious::Controller', -strict, -signatures, -async_await;

use WeBWorK::Debug;

async sub get ($c) {
	my $sp = $c->saml2->getSp();
	return $c->render(data => $sp->metadata(), format => 'xml');
}

1;
