#!/usr/bin/env perl

=head1 NAME

update-ww.pl -- run all needed scripts when webwork is updated.

=head1 SYNOPSIS

update-ww.pl [options]

 Options:
   -a|--all                  Run both OPL-update and build-search-json.pl

   -b|--build-sample-probs   Run the build-search-json.pl script with the 'all' flag.
                             The other options are 'samples' and 'macros' if not all
                             are desired.
   -o|--opl-update           Run the OPL-update script.  By default the upload-opl-statistics
                             part of the script is not run.  See the upload-opl-stats flags
                             to change this.
   -s|--sample-probs         Run the sample-probs part of the script.

   -v|--verbose              Setting this flag provides details as the script runs.

=cut

use strict;
use warnings;
use feature 'say';

use Mojo::File;
use Getopt::Long qw(:config bundling);

# BEGIN {
# 	use Env        qw(WEBWORK_ROOT);
# }

my $ww_root = Mojo::File->curfile->dirname->dirname->realpath;

my $build    = 'all';
my $git_repo = 'origin';
my $all      = 1;
my ($verbose, $opl_update, $sample_probs, $upload_opl_stats) = (0, 0, 0, 0);

GetOptions(
	'a|all'                  => \$all,
	'b|build-sample-probs=s' => \$build,
	'o|opl-update'           => \$opl_update,
	'g|git-opl-repository=s' => \$git_repo,
	's|sample-probs'         => \$sample_probs,
	'u|upload-opl-stats'     => \$upload_opl_stats,
	'v|verbose+'             => \$verbose
);

$all = 0 if ($opl_update || $sample_probs);

my $v = $verbose ? '-v' : '';
if ($all || $sample_probs) {
	say 'Rebuilding the sample problem and macro POD file.';
	my $search_output = `perl $ww_root/bin/build-search-json.pl $v -b $build`;
	say $search_output if $verbose;
}

if ($all || $opl_update) {
	say 'Running the OPL-update script.';
	$ENV{SKIP_UPLOAD_OPL_STATISTICS} = 1 unless $upload_opl_stats;
	$ENV{OPL_GIT_REPOSITORY}         = $git_repo;
	say "Running the OPL upate script" if $verbose;
	my $opl_output = `perl $ww_root/bin/OPL-update`;
	say $opl_output if $verbose;
}

1;
