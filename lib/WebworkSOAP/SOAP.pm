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
