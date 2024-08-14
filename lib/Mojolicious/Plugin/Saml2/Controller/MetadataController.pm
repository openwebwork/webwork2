package Mojolicious::Plugin::Saml2::Controller::MetadataController;

use Mojo::Base 'Mojolicious::Controller', -signatures, -async_await;

async sub get ($c) {
	my $sp = $c->saml2->getSp();
	return $c->render(data => $sp->metadata(), format => 'xml');
}

1;
