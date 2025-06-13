#!/usr/bin/env perl

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

check_modules.pl - Check to ensure that applications and perl modules needed by
webwork2 are installed.

=head1 SYNOPSIS

check_modules.pl [options]

 Options:
   -m|--modules          Check that the perl modules needed by webwork2 can be loaded.
   -p|--programs         Check that the programs needed by webwork2 exist.

Both programs and modules are checked if no options are given.

=head1 DESCRIPTION

Checks that modules needed by webwork2 can be loaded and are at the sufficient
version, and that applications needed by webwork2 exist.

=cut

use strict;
use warnings;
use version;
use feature 'say';

use Getopt::Long qw(:config bundling);
use Pod::Usage;

my @modulesList = qw(
	Archive::Tar
	Archive::Zip
	Archive::Zip::SimpleZip
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
	DBI
	Digest::MD5
	Digest::SHA
	Email::Address::XS
	Email::Sender::Transport::SMTP
	Email::Stuffer
	Errno
	Exception::Class
	File::Copy
	File::Copy::Recursive
	File::Fetch
	File::Find
	File::Find::Rule
	File::Path
	File::Spec
	File::stat
	File::Temp
	Future::AsyncAwait
	GD
	GD::Barcode::QRcode
	Getopt::Long
	Getopt::Std
	HTML::Entities
	HTTP::Async
	IO::File
	Iterator
	Iterator::Util
	Locale::Maketext::Lexicon
	Locale::Maketext::Simple
	LWP::Protocol::https
	MIME::Base32
	MIME::Base64
	Math::Random::Secure
	Minion
	Minion::Backend::SQLite
	Mojolicious
	Mojolicious::Plugin::NotYAMLConfig
	Mojolicious::Plugin::RenderFile
	Net::IP
	Net::OAuth
	Opcode
	Pandoc
	Perl::Tidy
	PHP::Serialization
	Pod::Simple::Search
	Pod::Simple::XHTML
	Pod::Usage
	Pod::WSDL
	Scalar::Util
	SOAP::Lite
	Socket
	SQL::Abstract
	String::ShellQuote
	SVG
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
	'Mojolicious'          => 9.34,
	'SQL::Abstract'        => 2.000000
);

my @programList = qw(
	convert
	curl
	mkdir
	mv
	mysql
	mysqldump
	node
	npm
	tar
	git
	gzip
	latex
	latex2pdf
	pandoc
	dvipng
);

my ($test_modules, $test_programs, $show_help);

GetOptions(
	'm|modules'  => \$test_modules,
	'p|programs' => \$test_programs,
	'h|help'     => \$show_help,
);
pod2usage(2) if $show_help;

$test_modules = $test_programs = 1 unless $test_programs || $test_modules;

my @PATH = split(/:/, $ENV{PATH});

check_modules() if $test_modules;
say ''          if $test_modules && $test_programs;
check_apps()    if $test_programs;

sub which {
	my $program = shift;
	for my $path (@PATH) {
		return "$path/$program" if -e "$path/$program";
	}
	return;
}

sub check_modules {
	say "Checking for modules required by WeBWorK...";

	my $moduleNotFound = 0;

	my $checkModule = sub {
		my $module = shift;

		no strict 'refs';
		eval "use $module";
		if ($@) {
			$moduleNotFound = 1;
			my $file = ($module =~ s|::|/|gr) . '.pm';
			if ($@ =~ /Can't locate $file in \@INC/) {
				say "** $module not found in \@INC";
			} else {
				say "** $module found, but failed to load: $@";
			}
		} elsif (defined($moduleVersion{$module})
			&& version->parse(${ $module . '::VERSION' }) < version->parse($moduleVersion{$module}))
		{
			$moduleNotFound = 1;
			say "** $module found, but not version $moduleVersion{$module} or better";
		} else {
			say "   $module found and loaded";
		}
		use strict 'refs';
	};

	for my $module (@modulesList) {
		$checkModule->($module);
	}

	if ($moduleNotFound) {
		say '';
		say 'Some requred modules were not found, could not be loaded, or were not at the sufficient version.';
		say 'Exiting as this is required to check the database driver and programs.';
		exit 0;
	}

	say '';
	say 'Checking for the database driver required by WeBWorK...';
	my $ce     = loadCourseEnvironment();
	my $driver = $ce->{database_driver} =~ /^mysql$/i ? 'DBD::mysql' : 'DBD::MariaDB';
	say "Configured to use $driver in site.conf";
	$checkModule->($driver);

	return;
}

sub check_apps {
	my $ce = loadCourseEnvironment();

	say 'Checking external programs required by WeBWorK...';

	push(@programList, $ce->{pg}{specialPGEnvironmentVars}{latexImageSVGMethod});

	for my $program (@programList) {
		if ($ce->{externalPrograms}{$program}) {
			# Remove command line arguments (for latex and latex2pdf).
			my $executable = $ce->{externalPrograms}{$program} =~ s/ .*$//gr;
			if (-e $executable) {
				say "   $executable found for $program";
			} else {
				say "** $executable not found for $program";
			}
		} else {
			my $found = which($program);
			if ($found) {
				say "   $found found for $program";
			} else {
				say "** $program not found in \$PATH";
			}
		}
	}

	# Check that the node version is sufficient.
	my $node_version_str = qx/node -v/;
	my ($node_version) = $node_version_str =~ m/v(\d+)\./;

	say "\n**The version of node should be at least 18.  You have version $node_version."
		if $node_version < 18;

	return;
}

sub loadCourseEnvironment {
	eval 'require Mojo::File';
	die "Unable to load Mojo::File: $@" if $@;
	my $webworkRoot = Mojo::File->curfile->dirname->dirname;
	push @INC, "$webworkRoot/lib";
	eval 'require WeBWorK::CourseEnvironment';
	die "Unable to load WeBWorK::CourseEnvironment: $@" if $@;
	return WeBWorK::CourseEnvironment->new({ webwork_dir => $webworkRoot });
}

1;
