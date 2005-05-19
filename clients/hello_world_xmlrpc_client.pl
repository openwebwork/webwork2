#!/usr/bin/perl -w

#
use XMLRPC::Lite;
  my $soap = XMLRPC::Lite
   # ->uri('http://webwork-db.math.rochester.edu/Demo/')
	-> proxy('http://devel.webwork.rochester.edu:8002/mod_xmlrpc/');
    
	
  my $result = $soap->call("WebworkXMLRPC.hi");
  

  unless ($result->fault) {
    print $result->result(),"\n";
  } else {
    print join ', ',
      $result->faultcode,
      $result->faultstring;
  }
