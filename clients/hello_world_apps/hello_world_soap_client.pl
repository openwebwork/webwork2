#!/usr/bin/perl -w


use SOAP::Lite;
my $soap = SOAP::Lite
#-> uri('http://math.webwork.rochester.edu/WebworkXMLRPC')
#-> proxy('https://math.webwork.rochester.edu/mod_soap/WebworkWebservice');
-> uri('http://localhost/WebworkXMLRPC')
-> proxy('http://localhost/mod_soap/WebworkWebservice');

#-> uri('https://devel.webwork.rochester.edu:8002/WebworkXMLRPC')
#-> proxy('https://devel.webwork.rochester.edu:8002/mod_soap/WebworkWebservice');


my $result = $soap->hi();

unless ($result->fault) {
	print $result->result();
} else {
	print join ', ',
  	$result->faultcode,
  	$result->faultstring;
}


