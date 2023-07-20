#!/usr/bin/env perl
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

run-perltidy.pl -- Run perltidy on webwork2 source files.

=head1 SYNOPSIS

    run-perltidy.pl [options] file1 file2 ...

=head1 DESCRIPTION

Run perltidy on webwork2 source files.

=head1 OPTIONS

For this script to work the the .perltidyrc file in the webwork2 root directory
must be readable.  Note that the webwork2 root directory is automatically
detected.

This script accepts all of the options that are accepted by perltidy.  See the
perltidy documentation for details.

However, the C<-pro> option is not allowed.  This script will use the
.perltidyrc file in the PG root directory for this option instead.

In addition the default value of C<-bext> for this script is C<'/'>, which means
that backup files will be created with the C<.bak> extension, and will be
deleted if there are no errors.  Note that this behavior may be changed by
passing a different value for the C<-bext> option.

Note that the C<-v> flag makes this script verbose, and does not output the
perltidy version as it would usually do for perltidy.

Finally, if no files are passed on the command line, then perltidy will be
executed on all files with the extensions C<.pl>, C<.pm>, or C<.t> in the
webwork2 root directory.  If files are passed on the command line, then perltidy
will only be executed on the listed files.

=cut

use strict;
use warnings;
use feature 'say';

use Perl::Tidy;
use File::Find qw(find);
use Mojo::File qw(curfile);

my $webwork_root = curfile->dirname->dirname->dirname;

die "Version 20220613 or newer of perltidy is required for this script.\n"
	. "The installed version is $Perl::Tidy::VERSION.\n"
	unless $Perl::Tidy::VERSION >= 20220613;
die "The .perltidyrc file in the webwork root directory is not readable.\n"
	unless -r "$webwork_root/.perltidyrc";

my $verbose = 0;
my (@args, @files);
for (@ARGV) {
	if    ($_ eq '-v') { $verbose = 1 }
	elsif ($_ =~ /^-/) { push(@args, $_) }
	else               { push(@files, $_) }
}

# Validate options that were passed.
my %options;
my $err = Perl::Tidy::perltidy(argv => \@args, dump_options => \%options);
exit $err                                               if $err;
die "The -pro option is not suppored by this script.\n" if defined $options{profile};

unshift(@args, '-bext=/') unless defined $options{'backup-file-extension'};

if (@files) {
	for (@files) {
		push(@args, $_);
		say "Tidying file: $_" if $verbose;
		Perl::Tidy::perltidy(argv => \@args, perltidyrc => "$webwork_root/.perltidyrc");
		pop(@args);
	}
} else {
	find(
		{
			wanted => sub {
				my $path   = $File::Find::name;
				my $dir    = $File::Find::dir;
				my ($name) = $path =~ m|^$dir(?:/(.*))?$|;
				$name = '' unless defined $name;

				if (-d $path && $name =~ /^(\.git|\.github|htdocs|\.vscode)$/) {
					$File::Find::prune = 1;
					return;
				}

				return unless $path =~ /\.p[lm]$/ || $path =~ /\.t$/;

				say "Tidying file: $path" if $verbose;

				push(@args, $path);
				Perl::Tidy::perltidy(argv => \@args, perltidyrc => "$webwork_root/.perltidyrc");
				pop(@args);
			},
			no_chdir => 1
		},
		$webwork_root
	);
}

1;
