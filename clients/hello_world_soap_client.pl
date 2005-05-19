#!/usr/bin/perl -w


use SOAP::Lite;
my $soap = SOAP::Lite
-> uri('http://devel.webwork.rochester.edu:8002/WebworkXMLRPC')
-> proxy('http://devel.webwork.rochester.edu:8002/mod_soap/WebworkWebservice')
;


my $result = $soap->hi();

unless ($result->fault) {
	print $result->result();
} else {
	print join ', ',
  	$result->faultcode,
  	$result->faultstring;
}


