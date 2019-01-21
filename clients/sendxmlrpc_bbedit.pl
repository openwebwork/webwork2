#!/usr/bin/perl -w
die "BB_DOC_PATH is not present.  You must first save the document\n" unless defined $ENV{BB_DOC_PATH};
$command = "/Volumes/WW_test/opt/local/bin/perl /Volumes/WW_test/opt/webwork/webwork2/clients/sendXMLRPC.pl -bB $ENV{BB_DOC_PATH}";
system($command);