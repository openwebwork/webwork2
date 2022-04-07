#!/usr/bin/env perl

=head1 NAME

generate-OPL-set-def-list - find all set definition files in the OPL and Contrib

=head1 SYNOPSIS

generate-OPL-set-def-list

The environment variable $WEBWORK_ROOT must be set with the location of
webwork2, and either the environment variable $PG_ROOT must be set with the
location of pg, or pg must be located in the parent directory of the webwork2
location.

=head1 DESCRIPTION

This script will find all set definition files in the OpenProblemLibrary and
Contrib subdirectories of the webwork-open-problem-library and list them in the
files $WEBWORK_ROOT/htdocs/DATA/library-set-defs.json and
$WEBWORK_ROOT/htdocs/DATA/contrib-set-defs.json.

=cut

use strict;
use warnings;

use Pod::Usage;
use File::Find;

my $pg_root;

BEGIN {
	pod2usage(2) unless exists $ENV{WEBWORK_ROOT};
	$pg_root = $ENV{PG_ROOT} // "$ENV{WEBWORK_ROOT}/../pg";
	pod2usage(2) unless (-e $pg_root);
}

use lib "$ENV{WEBWORK_ROOT}/lib";
use lib "$pg_root/lib";
use lib "$ENV{WEBWORK_ROOT}/bin";

use OPLUtils qw/writeJSONtoFile/;
use WeBWorK::CourseEnvironment;

my $ce = new WeBWorK::CourseEnvironment({ webwork_dir => $ENV{WEBWORK_ROOT} });
my $libraryRoot = $ce->{problemLibrary}{root};
my $contribRoot = $ce->{contribLibrary}{root};

print "Using WeBWorK root: $ENV{WEBWORK_ROOT}\n";
print "Using PG root: $pg_root\n";
print "Using library root: $libraryRoot\n";
print "Using contrib root: $contribRoot\n";

# Search the OPL directory for set definition files.
my @opl_set_defs;
find(
	{
		wanted => sub {
			push @opl_set_defs, $_ =~ s|^$libraryRoot/?|Library/|r if m|/set[^/]*\.def$|;
		},
		follow_fast => 1,
		no_chdir    => 1
	},
	$libraryRoot
);

# Search the Contrib directory for set definition files.
my @contrib_set_defs;
find(
	{
		wanted => sub {
			push @contrib_set_defs, $_ =~ s|^$contribRoot/?|Contrib/|r if m|/set[^/]*\.def$|;
		},
		follow_fast => 1,
		no_chdir    => 1
	},
	$contribRoot
);

sub depth_then_iname_sort {
	my $file_list = shift;
	my @file_depths;
	my @uc_file_names;
	for (@$file_list) {
		push @file_depths,   scalar(@{ [ $_ =~ /\//g ] });
		push @uc_file_names, uc($_);
	}
	@$file_list =
		@$file_list[ sort { $file_depths[$a] <=> $file_depths[$b] || $uc_file_names[$a] cmp $uc_file_names[$b] }
		0 .. $#$file_list ];
}

# Sort the files first by depth then by path.
depth_then_iname_sort(\@opl_set_defs);
depth_then_iname_sort(\@contrib_set_defs);

# Write the lists to the files in htdocs/DATA.
if ($ce->{options}{useOPLdefFiles}) {
	writeJSONtoFile(\@opl_set_defs, "$ce->{webworkDirs}{htdocs}/DATA/library-set-defs.json");
	print "Saved OPL set definition list to $ce->{webworkDirs}{htdocs}/DATA/library-set-defs.json.\n";
}

if ($ce->{options}{useContribDefFiles}) {
	writeJSONtoFile(\@contrib_set_defs, "$ce->{webworkDirs}{htdocs}/DATA/contrib-set-defs.json");
	print "Saved Contrib set definition list to $ce->{webworkDirs}{htdocs}/DATA/contrib-set-defs.json.\n";
}
