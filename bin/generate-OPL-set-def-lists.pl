#!/usr/bin/env perl

=head1 NAME

generate-OPL-set-def-list - find all set definition files in the OPL and Contrib

=head1 SYNOPSIS

generate-OPL-set-def-list

=head1 DESCRIPTION

This script will find all set definition files in the OpenProblemLibrary and
Contrib subdirectories of the webwork-open-problem-library and list them in the
files $WEBWORK_ROOT/htdocs/DATA/library-set-defs.json and
$WEBWORK_ROOT/htdocs/DATA/contrib-set-defs.json.

Note that the webwork2 root directory is automatically detected.

=cut

use strict;
use warnings;

use File::Find;

BEGIN {
	use Mojo::File qw(curfile);
	use Env qw(WEBWORK_ROOT);

	$WEBWORK_ROOT = curfile->dirname->dirname;
}

use lib "$ENV{WEBWORK_ROOT}/lib";
use lib "$ENV{WEBWORK_ROOT}/bin";

use OPLUtils qw/writeJSONtoFile/;
use WeBWorK::CourseEnvironment;

my $ce          = WeBWorK::CourseEnvironment->new({ webwork_dir => $ENV{WEBWORK_ROOT} });
my $libraryRoot = $ce->{problemLibrary}{root};
my $contribRoot = $ce->{contribLibrary}{root};

print "Using WeBWorK root: $ENV{WEBWORK_ROOT}\n";
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
writeJSONtoFile(\@opl_set_defs, "$ce->{webworkDirs}{htdocs}/DATA/library-set-defs.json");
print "Saved OPL set definition list to $ce->{webworkDirs}{htdocs}/DATA/library-set-defs.json.\n";

writeJSONtoFile(\@contrib_set_defs, "$ce->{webworkDirs}{htdocs}/DATA/contrib-set-defs.json");
print "Saved Contrib set definition list to $ce->{webworkDirs}{htdocs}/DATA/contrib-set-defs.json.\n";
