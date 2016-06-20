#!/usr/bin/env perl

BEGIN {$ENV{MOD_PERL_API_VERSION}=2}

use strict;
use warnings;
use FindBin; 
use Plack::Builder;



my $webwork_dir = $ENV{WEBWORK_ROOT} || die "The environment variable WEBWORK_ROOT.";
my $pg_dir = $ENV{PG_ROOT};

if (not defined $pg_dir) {
  $pg_dir = "$webwork_dir/../pg"; 
}

die "The directory $webwork_dir does not exist" if (not -d $webwork_dir); 
die "The directory $pg_dir does not exist" if (not -d $pg_dir); 

print "$webwork_dir/lib\n";
print "$pg_dir/lib\n";

use lib "$FindBin::Bin/../lib";

## can't get the variable to work in this. 
#use lib "$webwork_dir/lib";
#use lib "$pg_dir/lib";

use lib "$FindBin::Bin/../../lib";
use lib "$FindBin::Bin/../../../pg/lib";

#use WeBWorK3;

#$print "@INC\n";

use Routes::Templates;
use Routes::Login;

builder {
    mount '/'    => Routes::Templates->to_app;
    mount '/api' => Routes::Login->to_app;
};


#WeBWorK3->to_app; 

