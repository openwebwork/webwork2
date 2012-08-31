#!/usr/bin/perl

use strict;
use warnings;

my @applicationsList = qw(
	mkdir
	mv
	mysql
	tar
	gzip
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
	Email::Address
	Errno
	Exception::Class
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
	HTML::Template
	IO::File
	Iterator
	Iterator::Util
	JSON
	Locale::Maketext::Lexicon
	Locale::Maketext::Simple
	Mail::Sender
	MIME::Base64
	Net::IP
	Net::LDAPS
	Net::SMTP
	Opcode
	PadWalker
	PHP::Serialization
	Pod::Usage
	Pod::WSDL
	Safe
	Scalar::Util
	SOAP::Lite 
	Socket
	SQL::Abstract
	String::ShellQuote
	Text::Wrap
	Tie::IxHash
	Time::HiRes
	Time::Zone
	URI::Escape
	UUID::Tiny
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
	warn "invalid apache version specified -- assuming apache2\n";
	warn "usage: $0 { apache1 | apache2 }\n";
	sleep 1;
	$apache_version = "apache2";
}

if ($apache_version eq "apache1") {
	push @modulesList, @apache1ModulesList;
} elsif ($apache_version eq "apache2") {
	push @modulesList, @apache2ModulesList;
}

my @PATH = split(/:/, $ENV{PATH});
check_apps(@applicationsList);

check_modules(@modulesList);

sub check_apps {
	my @applicationsList = @_;
	print "\nChecking your \$PATH for executables required by WeBWorK...\n";
#	print "\$PATH=", shift @PATH, "\n";    # this throws away the first item -- usually /bin
        print "\$PATH=";
	print join ("\n", map("      $_", @PATH)), "\n\n";
	
	foreach my $app (@applicationsList)  {
		my $found = which($app);
		if ($found) {
			print "   $app found at $found\n";
		} else {
			print "** $app not found in \$PATH\n";
		}
	}
}

sub which {
	my $app = shift;
	foreach my $path (@PATH) {
		return "$path/$app" if -e "$path/$app";
	}
}

sub check_modules {
	my @modulesList = @_;
	
	print "\nChecking your \@INC for modules required by WeBWorK...\n";
	my @inc = @INC;
	print "\@INC=";
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
}
