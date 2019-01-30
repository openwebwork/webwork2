#!/usr/bin/env perl
#
use strict;
use warnings;
use version;

my @applicationsList = qw(
        curl
	mkdir
	mv
	mysql
	tar
        git
	gzip
	latex
	pdflatex
	dvipng
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
	Array::Utils
	Benchmark
	Carp
	CGI
	Class::Accessor
	#Crypt::SSLeay
	Dancer
	Dancer::Plugin::Database
	Data::Dump
	Data::Dumper
	Data::UUID
	Date::Format
	Date::Parse
	DateTime
	DBD::mysql
	DBI
	Digest::MD5
	Digest::SHA
	Email::Address
	Email::Simple
	Email::Sender::Simple
	Email::Sender::Transport::SMTP
	Errno
	Exception::Class
	File::Copy
	File::Find
	File::Find::Rule
	File::Path
	File::Spec
	File::stat
	File::Temp
	GD
	Getopt::Long
	Getopt::Std
	HTML::Entities
	HTML::Scrubber
	HTML::Tagset
	HTML::Template
	IO::File
	IO::Socket::SSL
	Iterator
	Iterator::Util
	JSON
	Locale::Maketext::Lexicon
	Locale::Maketext::Simple
	LWP::Protocol::https
	MIME::Base64
	Net::IP
	Net::LDAPS
	Net::OAuth
	Net::SMTP
	Net::SSLeay
	Opcode
	PadWalker
	Path::Class
	PHP::Serialization
	Pod::Usage
	Pod::WSDL
	Safe
	Scalar::Util
	SOAP::Lite
	Socket
	SQL::Abstract
	Statistics::R::IO
	String::ShellQuote
	Template
	Text::CSV
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
	YAML
);

my %moduleVersion = (
    'LWP::Protocol::https' => 6.06,
    'Net::SSLeay' => 1.46,
    'IO::Socket::SSL' => 2.007
);

# modules used by disabled code
#	RQP::Render (RQP)

#main

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

	no strict 'refs';

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
		} elsif (defined($moduleVersion{$module}) &&
			 version->parse(${$module.'::VERSION'}) <
			 version->parse($moduleVersion{$module})) {
		    print "** $module found, but not version $moduleVersion{$module} or better\n";
		} else {
			print "   $module found and loaded\n";
		}
	}
}
