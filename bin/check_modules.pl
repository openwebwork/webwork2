#!/usr/bin/perl -w

print "\n\n\nSearching for modules needed for WeBWorK\n\n";
while (<DATA>)  {
	
	next unless $_ =~/\S/;
	chomp;
	eval "use $_" ;
	if ($@) {
		print "----------Can't find $_\n";
	} else {
		print "$_ found. \n";
	}

}



__END__

Apache::Constants
Apache::Cookie
Apache::Request
Carp
CGI
Data::Dumper
Data::UUID
Date::Format
Date::Parse
DBI
Digest::MD5
Errno
File::Copy
File::Path
File::Temp
HTML::Entities
Mail::Sender
Net::SMTP
Opcode
Safe
SOAP::Lite
Text::Wrap
Time::HiRes
URI::Escape
XML::Parser
XML::Parser::EasyTree
XML::Writer