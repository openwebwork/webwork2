#!/usr/bin/env perl
#

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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
	node
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

my @modulesList = qw(
	Archive::Zip
	Array::Utils
	Benchmark
	Carp
	Class::Accessor
	Crypt::JWT
	Crypt::PK::RSA
	Data::Dump
	Data::Dumper
	Data::Structure::Util
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
	Email::Stuffer
	Errno
	Exception::Class
	File::Copy
	File::Fetch
	File::Find
	File::Find::Rule
	File::Path
	File::Spec
	File::stat
	File::Temp
	Future::AsyncAwait
	GD
	Getopt::Long
	Getopt::Std
	HTML::Entities
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
	Math::Random::Secure
	Minion
	Minion::Backend::SQLite
	Mojolicious
	Mojolicious::Plugin::NotYAMLConfig
	Net::IP
	Net::LDAPS
	Net::OAuth
	Net::SMTP
	Net::SSLeay
	Opcode
	PadWalker
	Path::Class
	Perl::Tidy
	PHP::Serialization
	Pod::Simple::Search
	Pod::Simple::XHTML
	Pod::Usage
	Pod::WSDL
	Safe
	Scalar::Util
	SOAP::Lite
	Socket
	Statistics::R::IO
	String::ShellQuote
	SVG
	Template
	Text::CSV
	Text::Wrap
	Tie::IxHash
	Time::HiRes
	Time::Zone
	Types::Serialiser
	URI::Escape
	UUID::Tiny
	XML::LibXML
	XML::Parser
	XML::Parser::EasyTree
	XML::Writer
	YAML::XS
);

my %moduleVersion = (
	'Future::AsyncAwait'   => 0.52,
	'IO::Socket::SSL'      => 2.007,
	'LWP::Protocol::https' => 6.06,
	'Mojolicious'          => 9.22,
	'Net::SSLeay'          => 1.46,
	'Perl::Tidy'           => 20220613
);

my ($test_programs, $test_modules, $show_help);
my $test_all = 1;

GetOptions(
	'm|modules'  => \$test_modules,
	'p|programs' => \$test_programs,
	'A|all'      => \$test_all,
	'h|help'     => \$show_help,
);
pod2usage(2) if $show_help;

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
	print join("\n", map("      $_", @PATH)), "\n\n";

	foreach my $app (@applicationsList) {
		my $found = which($app);
		if ($found) {
			print "   $app found at $found\n";
		} else {
			print "** $app not found in \$PATH\n";
		}
	}

	## Check that the node version is sufficient.
	my $node_version_str = qx/node -v/;
	my ($node_version) = $node_version_str =~ m/v(\d+)\./;

	if ($node_version != 16) {
		print "\n\n**The version of node should be 16.  You have version $node_version";
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
	print join("\n", map("     $_", @inc)), "\n\n";

	no strict 'refs';

	foreach my $module (@modulesList) {
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
		} elsif (defined($moduleVersion{$module})
			&& version->parse(${ $module . '::VERSION' }) < version->parse($moduleVersion{$module}))
		{
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
	my $sql_abstract         = not($@);
	my $sql_abstract_version = $SQL::Abstract::VERSION if $sql_abstract;

	eval "use SQL::Abstract::Classic";
	my $sql_abstract_classic = not($@);

	if ($sql_abstract_classic) {
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
