package WebworkSOAP::SOAP;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Pod::WSDL;
use SOAP::Lite;

use WebworkSOAP;

sub wsdl ($c) {
	my $pod = Pod::WSDL->new(
		source            => 'WebworkSOAP',
		location          => $c->server_root_url . '/webwork2_rpc',
		withDocumentation => 0
	);

	return $c->render(data => $pod->WSDL);
}

sub dispatch ($c) {
	my $som = SOAP::Deserializer->deserialize($c->req->body);

	my $som_body = $som->body;
	my $method   = (keys %$som_body)[0];
	my @params   = $som->paramsin;

	my $serializer = SOAP::Serializer->new;

	my $result = eval { WebworkSOAP->$method(@params); };

	# This is rather minimal error handling.
	if ($@) {
		if (ref $@ eq 'SOAP::Fault') {
			return $c->render(
				data   => $serializer->envelope(fault => $@->faultcode),
				status => $@->faultcode == 8 ? 401 : 500
			);
		}
		return $c->render(data => $serializer->envelope(fault => 1), status => 500);
	}

	return $c->render(data => $serializer->envelope(freeform => \$result));
}

1;
