#!/usr/bin/env perl
#

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

=head1 NAME

check_modules.pl - check to ensure that all applications and perl modules are installed. 

=head1 SYNOPSIS
 
check_modules.pl [options]
 
 Options:
   -a|--apache-version	 Which apache version to use.  Defaults to 2. 
   -m|--modules          Lists the perl modules needed to be installed. 
   -p|--programs       	 Lists the programs/applications that are needed. 
   -A|--all         		 checks both programs and modules (Default if -m or -p is not selected)	

=head1 DESCRIPTION
 
Lists all needed applications for webwork as well as a perl modules.
 
=cut
use strict;
use warnings;
use version;
use Getopt::Long qw(:config bundling);
use Pod::Usage;

my @applicationsList = qw(
	convert
	curl
	dvisvgm
	mkdir
	mv
	mysql
	tar
	git
	gzip
	latex
	pdf2svg
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
	Apache2::ServerRec
	Apache2::ServerUtil
);



my @modulesList = qw(
	Archive::Zip
	Array::Utils
	Benchmark
	Carp
	CGI
	CGI::Cookie
	Class::Accessor
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
	Email::Address::XS
	Email::Sender::Simple
	Email::Sender::Transport::SMTP
	Email::Simple
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
	HTTP::Async
	IO::File
	IO::Socket::SSL
	Iterator
	Iterator::Util
	JSON
	JSON::MaybeXS
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
	XML::Simple
	XML::Writer
	XMLRPC::Lite
	YAML
);

my %moduleVersion = (
    'LWP::Protocol::https' => 6.06,
    'Net::SSLeay' => 1.46,
    'IO::Socket::SSL' => 2.007
);

my ($test_programs,$test_modules,$show_help);
my $test_all = 1; 
my $apache_version = "2";

GetOptions(
	'a|apache-version=s' => \$apache_version,
	'm|modules'      => \$test_modules,
	'p|programs'			 => \$test_programs,
	'A|all'   			 => \$test_all,
	'h|help'					=> \$show_help,
);
pod2usage(2) if $show_help; 

if ($apache_version eq "1") {
	push @modulesList, @apache1ModulesList;
} elsif ($apache_version eq "2") {
	push @modulesList, @apache2ModulesList;
}

my @PATH = split(/:/, $ENV{PATH});

if ($test_all or $test_programs) {
	check_apps(@applicationsList);
}

if ($test_all or $test_modules) {
	check_modules(@modulesList);
}

sub check_apps {
	my @applicationsList = @_;
	print "\nChecking your \$PATH for executables required by WeBWorK...\n";
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
	checkSQLabstract(); 
}

## this is specialized code to check for either SQL::Abstract or SQL::Abstract::Classic

sub checkSQLabstract {
	print "\n checking for SQL::Abstract\n\n";
	eval "use SQL::Abstract";
	my $sql_abstract = not($@); 
	my $sql_abstract_version = $SQL::Abstract::VERSION if $sql_abstract; 

	eval "use SQL::Abstract::Classic";
	my $sql_abstract_classic = not($@);

	if($sql_abstract_classic) {
		print qq/ You have SQL::Abstract::Classic installed. This package will be used if either
 the installed version of SQL::Abstract is version > 1.87 or if that package is not installed.\n/;
	} elsif ($sql_abstract && $sql_abstract_version <= 1.87) {
		print "You have version $sql_abstract_version of SQL::Abstract installed.  This will be used\n";
	} else {
		print qq/You need either SQL::Abstract version <= 1.87 or need to install SQL::Abstract::Classic.
 If you are using cpan or cpanm, it is recommended to install SQL::Abstract::Classic.\n/;
	}
}

1;
