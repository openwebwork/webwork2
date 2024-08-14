package Mojolicious::Plugin::Saml2::Controller::ErrorController;

use Mojo::Base 'Mojolicious::Controller', -signatures, -async_await;

async sub get ($c) {
	return $c->reply->exception('SAML2 Login Error')->rendered(400);
}

1;
