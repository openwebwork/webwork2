#!/usr/bin/env perl

=head1 NAME

generate-OPL-set-def-list - find all set definition files in the OPL and Contrib

=head1 SYNOPSIS

generate-OPL-set-def-list

The variable pg_dir must be set with the location of pg in webwork2.mojolicious.yml.
Note that the webwork root location will be automatically detected.

=head1 DESCRIPTION

This script will find all set definition files in the OpenProblemLibrary and
Contrib subdirectories of the webwork-open-problem-library and list them in the
files $WEBWORK_ROOT/htdocs/DATA/library-set-defs.json and
$WEBWORK_ROOT/htdocs/DATA/contrib-set-defs.json.

=cut

use strict;
use warnings;

use File::Find;

BEGIN {
	use Mojo::File qw(curfile);
	use YAML::XS qw(LoadFile);
	use Env qw(WEBWORK_ROOT PG_ROOT);

	$WEBWORK_ROOT = curfile->dirname->dirname;

	# Load the configuration file to obtain the PG root directory.
	my $config_file = "$WEBWORK_ROOT/conf/webwork2.mojolicious.yml";
	$config_file = "$WEBWORK_ROOT/conf/webwork2.mojolicious.dist.yml" unless -e $config_file;
	my $config = LoadFile($config_file);
	$PG_ROOT = $config->{pg_dir};

	die "The pg directory must be correctly defined in conf/webwork2.mojolicious.yml" unless -e $ENV{PG_ROOT};
}

use lib "$ENV{WEBWORK_ROOT}/lib";
use lib "$ENV{PG_ROOT}/lib";
use lib "$ENV{WEBWORK_ROOT}/bin";

use OPLUtils qw/writeJSONtoFile/;
use WeBWorK::CourseEnvironment;

my $ce          = WeBWorK::CourseEnvironment->new({ webwork_dir => $ENV{WEBWORK_ROOT}, pg_dir => $ENV{PG_ROOT} });
my $libraryRoot = $ce->{problemLibrary}{root};
my $contribRoot = $ce->{contribLibrary}{root};

print "Using WeBWorK root: $ENV{WEBWORK_ROOT}\n";
print "Using PG root: $ENV{PG_ROOT}\n";
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
