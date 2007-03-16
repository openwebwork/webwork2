#!/usr/bin/perl

use strict;
use warnings;

my @apache1ModulesList = qw(
	Apache
	Apache::Constants 
	Apache::Cookie
	Apache::Log
	Apache::Request
);

my @apache2ModulesList = qw(
	Apache2::Request
	Apache2::Cookie
	Apache2::ServerRec
	Apache2::ServerUtil
);

my @modulesList = qw(
	Benchmark
	Carp
	CGI
	Data::Dumper
	Data::UUID 
	Date::Format
	Date::Parse
	DateTime
	DBD::mysql
	DBI
	Digest::MD5
	Errno
	File::Copy
	File::Find
	File::Path
	File::Spec
	File::stat
	File::Temp
	GD
	Getopt::Long
	Getopt::Std
	HTML::Entities
	HTML::Tagset
	IO::File
	Iterator
	Iterator::Util
	Mail::Sender
	MIME::Parser
	MIME::Base64
	Net::LDAPS
	Net::SMTP
	Opcode
	PHP::Serialization
	Pod::Usage
	Safe
	SOAP::Lite 
	Socket
	SQL::Abstract
	String::ShellQuote
	Text::Wrap
	Time::HiRes
	Time::Zone
	URI::Escape
	XML::Parser
	XML::Parser::EasyTree
	XML::Writer
	XMLRPC::Lite
);

# modules used by disabled code
#	RQP::Render (RQP)
#	SOAP::Lite (PG::Remote)

my $apache_version = shift @ARGV;
unless (defined $apache_version and $apache_version =~ /^apache[12]$/) {
	warn "invalid apache version specified -- assuming apache1\n";
	warn "usage: $0 { apache1 | apache2 }\n";
	sleep 1;
	$apache_version = "apache1";
}

if ($apache_version eq "apache1") {
	push @modulesList, @apache1ModulesList;
} elsif ($apache_version eq "apache2") {
	push @modulesList, @apache2ModulesList;
}

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

check_apps(@applicationsList);
check_modules(@modulesList);
sub check_apps {
	my @applicationsList = @_;
	print "\nChecking your \$PATH for executables required by WeBWorK...\n";
	my @path = split(/:/, $ENV{PATH});
	print "\$PATH=", shift @path, "\n";
	print join ("\n", map("      $_", @path)), "\n\n";
	
	foreach my $app (@applicationsList)  {
		my $result = `which $app`;
		chomp($result);
		unless ($result =~ /\s*no/) {
			print "   $app found at $result\n";
		} else {
			$result =~ s/\s*no//;
			print "** $app not found in \$result\n";
		}
	}
	
	print "\nLoading Perl modules required by WeBWorK...\n";
	my @inc = @INC;
	print "\@INC=", shift @inc, "\n";
	print join ("\n", map("     $_", @inc)), "\n\n";
}

sub check_modules {
	my @modulesList = @_;
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
}
