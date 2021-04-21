#!/usr/bin/perl

=head1 NAME
 
updateOPLextras - re-build library trees
 
=head1 SYNOPSIS
 
updateOPLextras [options]
 
 Options:
   -t --textbooks        (rebuild textbook tree)
   -s --subjects         (rebuild subject tree)
   -d --directories      (rebuild directory tree)
   -a --all              (rebuild all trees)
   -h --help             (display this text)
   -v --verbose          (turn on verbosity mode) 

=head1 OPTIONS
 
=over 8
 
=item B<-t> I<--textbooks>
 
Rebuild the textbook tree and write to a JSON file.

=item B<-s> I<--subjects>

Rebuild the subject tree and write to a JSON file.

=item B<-d> I<--directories>

Rebuild the directory tree and write to a JSON file.

=item B<-v> I<--verbosity>

Turn on verbosity mode.

=back
 
=head1 DESCRIPTION
 
B<This program> will rebuild the specified library trees
from the existing library contents in the database.
 
=cut

use strict;
use warnings;
use DBI;
use Getopt::Long;
use Pod::Usage;
Getopt::Long::Configure ("bundling");

my ($textbooks, $directories, $subjects, $verbose, $all);
GetOptions (
  't|textbooks'   => \$textbooks,
  'd|directories' => \$directories,
  's|subjects'    => \$subjects,
  'a|all'         => \$all,
	'v|verbose'     => \$verbose
);
pod2usage(2) unless ($textbooks || $directories || $subjects || $all);

#####
#
#  This script allows to rerun a few scripts related to the OPL but doesn't require
#  the entire OPLupdate script to be run.
#
####


BEGIN {
	die "WEBWORK_ROOT not found in environment.\n" unless exists $ENV{WEBWORK_ROOT};
}

use lib "$ENV{WEBWORK_ROOT}/bin";
use lib "$ENV{WEBWORK_ROOT}/lib";
use WeBWorK::CourseEnvironment;
use OPLUtils qw/build_library_directory_tree build_library_subject_tree build_library_textbook_tree/;

my $ce = new WeBWorK::CourseEnvironment({webwork_dir=>$ENV{WEBWORK_ROOT}});

# decide whether the mysql installation can handle 
# utf8mb4 and that should be used for the OPL

my $ENABLE_UTF8MB4 = ($ce->{ENABLE_UTF8MB4})?1:0;
print  "using utf8mb4 \n\n" if $ENABLE_UTF8MB4;

# The DBD::MariaDB driver should not get the
#    mysql_enable_utf8mb4 or mysql_enable_utf8 settings,
# but DBD::mysql should.
my %utf8_parameters = ();

if ( $ce->{database_driver} =~ /^mysql$/i ) {
	# Only needed for older DBI:mysql driver
	if ( $ENABLE_UTF8MB4 ) {
		$utf8_parameters{mysql_enable_utf8mb4} = 1;
	} else {
		$utf8_parameters{mysql_enable_utf8} = 1;
	}
}

my $dbh = DBI->connect(
	$ce->{problemLibrary_db}->{dbsource},
	$ce->{problemLibrary_db}->{user},
	$ce->{problemLibrary_db}->{passwd},
	{
		PrintError => 0,
		RaiseError => 1,
		%utf8_parameters,
	},
);

build_library_textbook_tree($ce,$dbh,$verbose) if ($all || $textbooks);
build_library_directory_tree($ce,$verbose) if ($all || $directories);
build_library_subject_tree($ce,$dbh,$verbose) if ($all || $subjects);

1;
