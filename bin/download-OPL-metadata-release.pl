#!/usr/bin/env perl

# This script downloads the latest OPL metadata release, and restores the database dump file in that release.

use feature say;
use strict;
use warnings;

use File::Fetch;
use File::Copy;
use File::Path;
use Archive::Tar;
use Mojo::File;
use JSON;

BEGIN {
	use Mojo::File qw(curfile);
	use Env qw(WEBWORK_ROOT);

	$WEBWORK_ROOT = curfile->dirname->dirname;
}

use lib "$ENV{WEBWORK_ROOT}/lib";
use lib "$ENV{WEBWORK_ROOT}/bin";

use WeBWorK::CourseEnvironment;
use Helper 'runScript';

my $ce = WeBWorK::CourseEnvironment->new({ webwork_dir => $ENV{WEBWORK_ROOT} });

# Make sure the webwork temporary directory exists and is writable before proceeding.
die "The WeBWorK temporary directory $ce->{webworkDirs}{tmp} does not exist or is not writable."
	if (!-d $ce->{webworkDirs}{tmp} || !-w $ce->{webworkDirs}{tmp});

my $releaseDataFF =
	File::Fetch->new(uri => 'https://api.github.com/repos/openwebwork/webwork-open-problem-library/releases/latest');
my $file        = $releaseDataFF->fetch(to => $ce->{webworkDirs}{tmp}) or die $releaseDataFF->error;
my $path        = Mojo::File->new($file);
my $releaseData = JSON->new->utf8->decode($path->slurp);
$path->remove;

my $releaseTag = $releaseData->{tag_name};
say "Found OPL METADATA release $releaseTag.";

my $downloadURL = '';
for (@{ $releaseData->{assets} }) {
	$downloadURL = $_->{browser_download_url} if ($_->{name} =~ /tar\.gz$/);
}

die 'Unable to determine download url for OPL metadata release.' if !$downloadURL;

# Download and extract the OPL metadata release.
my $releaseDownloadFF = File::Fetch->new(uri => $downloadURL);
my $releaseFile       = $releaseDownloadFF->fetch(to => $ce->{webworkDirs}{tmp}) or die $releaseDownloadFF->error;
say 'Downloaded release archive, now extracting.';

my $arch = Archive::Tar->new($releaseFile);
die "An error occurred while creating the tar file: $releaseFile" unless $arch;
$arch->setcwd($path);
$arch->extract();
die "There was an error extracting the metadata release: $arch->error" if $arch->error;

# Copy the json files into htdocs.
for (glob("$ce->{webworkDirs}{tmp}/webwork-open-problem-library/JSON-SAVED/*.json")) {
	copy($_, "$ce->{webworkDirs}{htdocs}/DATA/") or die "Copy $_ to $ce->{webworkDirs}{htdocs}/DATA/ failed: $!";
}

# Check to see if there appears to be a clone of the OPL in the location set
die "The directory $ce->{problemLibrary}{root} does not exist or is not writable.\n"
	. "Make sure that you have cloned the OPL before executing this script,\n"
	. "and that location is writable for this user."
	if (!-d $ce->{problemLibrary}{root} || !-w $ce->{problemLibrary}{root});

my $libraryDirectory = $ce->{problemLibrary}{root} =~ s/OpenProblemLibrary$//r;

# Make sure the library directory exists and is writable before proceeding.
die "The directory $libraryDirectory does not exist or is not writable."
	if (!-d $libraryDirectory || !-w $libraryDirectory);

# Checkout the release tag in the library clone if it hasn't already been done.
`$ce->{externalPrograms}{git} -C $libraryDirectory fetch --tags origin`;
`$ce->{externalPrograms}{git} -C $libraryDirectory show-ref refs/heads/$releaseTag -q`;
if ($?) {
	say "Switching OPL clone in $libraryDirectory to new branch of release tag $releaseTag.";
	`$ce->{externalPrograms}{git} -C $libraryDirectory checkout -b $releaseTag $releaseTag`;
}

# Copy the sql database dump file in the metadata release into the library location, and restore it.
mkdir "$libraryDirectory/TABLE-DUMP" if !-d "$libraryDirectory/TABLE-DUMP";

copy("$ce->{webworkDirs}{tmp}/webwork-open-problem-library/TABLE-DUMP/OPL-tables.sql", "$libraryDirectory/TABLE-DUMP");

say 'Restoring OPL tables from release database dump.';
runScript("$ENV{WEBWORK_ROOT}/bin/restore-OPL-tables.pl");

# Remove temporary files.
say "Removing temporary files.";
unlink($releaseFile);
rmtree("$ce->{webworkDirs}{tmp}/webwork-open-problem-library");

say 'Done!';

1;
