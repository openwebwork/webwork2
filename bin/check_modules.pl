#!/usr/bin/perl -w

my @modulesList = qw(
	Apache::Constants
	Apache::Cookie
	Apache::Request
	Carp
	CGI
	CGI::Pretty
	Data::Dumper
	Data::UUID
	Date::Format
	Date::Parse
	DateTime
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
);

my @applicationsList = qw(
	dvipng 
	giftopnm
	latex
	pdflatex
	pngtopnm
	pnmtopng
	pnmtops
	ppmtopgm
	tth
);

print "\nSearching for executables\n\n";

foreach my $app (@applicationsList)  {
	my $result = `which $app`;
	chomp($result);
	if ($result)  {
		print "$app found at $result\n";
	} else {
		print "***** Can't find $app\n";
	}
}

print "\nSearching for modules needed for WeBWorK\n\n";

foreach my $module (@modulesList)  {
	eval "use $module";
	if ($@) {
		print "***** Can't find $module\n";
	} else {
		print "$module found. \n";
	}
}
