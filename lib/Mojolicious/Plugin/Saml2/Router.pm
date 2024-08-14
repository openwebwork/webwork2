package Mojolicious::Plugin::Saml2::Router;

use Mojo::Base -signatures;

sub setup ($app, $conf) {
	my $subRouter =
		$app->routes->any($conf->{sp}{route}{base})->to(namespace => 'Mojolicious::Plugin::Saml2::Controller')
		->name('saml2.base');
	$subRouter->get($conf->{sp}{route}{metadata})->to(controller => 'MetadataController', action => 'get')
		->name('saml2.metadata');
	$subRouter->get($conf->{sp}{route}{error})->to(controller => 'ErrorController', action => 'get')
		->name('saml2.error');
	$subRouter->post($conf->{sp}{route}{acs}{post})->to(controller => 'AcsPostController', action => 'post')
		->name('saml2.acsPost');
}

1;
