#!/usr/bin/perl

#####
#
#  This script allows to rerun a few scripts related to the OPL but doesn't require
#  the entire OPLupdate script to be run.
#
####


use strict;
use warnings;
use Moo;
use MooX::Options;
use DBI;

option verbose => (
  is => 'ro',
  short => 'v',
  doc => 'turn on verbosity'
);
option textbooks  => (
  is => 'ro',
  short => 't',
  doc => 'run the script to update the OPL textbooks and write to a JSON file'
);
option directories => (
  is => 'ro',
  short => 'd',
  doc => 'run the script to update the OPL directories and write to a JSON file'
);
option subjects => (
  is => 'ro',
  short => 's',
  doc => 'run the script to update the OPL subjects and write to a JSON file'
);
option all => (
  is => 'ro',
  short => 'a',
  doc => 'run all the scripts'
);

BEGIN {
  die "WEBWORK_ROOT not found in environment.\n" unless exists $ENV{WEBWORK_ROOT};
}

use lib "$ENV{WEBWORK_ROOT}/bin";
use lib "$ENV{WEBWORK_ROOT}/lib";
use WeBWorK::CourseEnvironment;
use OPLUtils qw/build_library_directory_tree build_library_subject_tree build_library_textbook_tree/;

sub run {
  my ($self) = @_;

  my $ce = new WeBWorK::CourseEnvironment({webwork_dir=>$ENV{WEBWORK_ROOT}});

  my $dbh = DBI->connect(
          $ce->{problemLibrary_db}->{dbsource},
          $ce->{problemLibrary_db}->{user},
          $ce->{problemLibrary_db}->{passwd},
          {
              PrintError => 0,
              RaiseError => 1,
              ($ce->{ENABLE_UTF8MB4})?(mysql_enable_utf8mb4 =>1):(mysql_enable_utf8 => 1),
          },
  );

  build_library_textbook_tree($ce,$dbh,$self->verbose) if ($self->all || $self->textbooks);
  build_library_directory_tree($ce,$self->verbose) if ($self->all || $self->directories);
  build_library_subject_tree($ce,$dbh,$self->verbose) if ($self->all || $self->subjects);
}

main->new_with_options->run;

1;
