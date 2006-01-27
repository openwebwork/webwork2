#!/usr/bin/perl

use strict;
use warnings;

my @modulesList = qw(
	Apache
	Apache::Constants
	Apache::Cookie
	Apache::Log
	Apache::Request
	Benchmark
	Carp
	CGI
	Data::Dumper
	Data::UUID
	Date::Format
	Date::Parse
	DateTime
	DBI
	Digest::MD5
	Errno
	Fcntl
	File::Copy
	File::Find
	File::Path
	File::Spec
	File::stat
	File::Temp
	Getopt::Long
	Getopt::Std
	HTML::Entities
	IO::File
	Mail::Sender
	MIME::Base64
	Opcode
	Pod::Usage
	Safe
	Socket
	String::ShellQuote
	Text::Wrap
	Time::HiRes
	Time::Zone
	URI::Escape
	XML::Parser
	XML::Parser::EasyTree
	XML::Writer
	WheeWhaa
);

# modules used by disabled code
#	Class::Data::Inheritable (DBv3)
#	Class::DBI::Plugin::AbstractCount (DBv3)
#	DateTime::Format::DBI (DBv3)
#	GDBM_File (Driver::GDBM)
#	RQP::Render (RQP)
#	SOAP::Lite (PG::Remote)

my @applicationsList = qw(
	mkdir
	mv
	mysql
	tar
	latex
	pdflatex
	dvipng
	tth
	giftopnm
	ppmtopgm
	pnmtops
	pnmtopng
	pngtopnm
);

print "\nChecking your \$PATH for executables required by WeBWorK...\n";
my @path = split(/:/, $ENV{PATH});
print "\$PATH=", shift @path, "\n";
print join ("\n", map("      $_", @path)), "\n\n";

foreach my $app (@applicationsList)  {
	my $result = `which $app`;
	chomp($result);
	if ($result) {
		print "   $app found at $result\n";
	} else {
		print "** $app not found in \$PATH\n";
	}
}

print "\nLoading Perl modules required by WeBWorK...\n";
my @inc = @INC;
print "\@INC=", shift @inc, "\n";
print join ("\n", map("     $_", @inc)), "\n\n";

foreach my $module (@modulesList)  {
	eval "use $module";
	if ($@) {
		my $file = $module;
		$file =~ s|::|/|g;
		$file .= ".pm";
		if ($@ =~ /Can't locate $file in \@INC/) {
			print "** $module not found in \@INC\n";
		} else {
			print "** $module found, but failed to load: $@";
		}
	} else {
		print "   $module found and loaded\n";
	}
}
