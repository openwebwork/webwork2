#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use Plack::Builder;
use Data::Dump qw/dump/;
my $webwork_dir = "";
my $pg_dir = "";

BEGIN {
  $ENV{MOD_PERL_API_VERSION}=2;  # ensure that mod_perl2 is used.
  $webwork_dir = $ENV{WEBWORK_ROOT};

  die "The WEBWORK_ROOT env variable or webwork_dir in the webwork3 config file must be set" unless defined $webwork_dir;
  $WeBWorK::Constants::WEBWORK_DIRECTORY = $webwork_dir;

  $pg_dir = $ENV{PG_ROOT} || "$webwork_dir/../pg";

  die "The directory $webwork_dir does not exist" if (not -d $webwork_dir);
  die "The directory $pg_dir does not exist" if (not -d $pg_dir);
}

use lib "$webwork_dir/lib";
use lib "$webwork_dir/webwork3/lib";
use lib "$pg_dir/lib";



use Routes::Templates;
use Routes::Login;
# use Routes::ProblemSets;

builder {
    mount '/'    => Routes::Templates->to_app;
    mount '/api' => Routes::Login->to_app;
};
