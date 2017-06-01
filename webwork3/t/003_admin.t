use strict;
use warnings;


my $webwork_dir = "";
my $pg_dir = "";

BEGIN {
  $ENV{MOD_PERL_API_VERSION}=2;  # ensure that mod_perl2 is used.
  $webwork_dir = $ENV{WEBWORK_ROOT} || die "The environment variable WEBWORK_ROOT needs to be defined.";
  $pg_dir = $ENV{PG_ROOT};

  if (not defined $pg_dir) {
    $pg_dir = "$webwork_dir/../pg";
  }

  die "The directory $webwork_dir does not exist" if (not -d $webwork_dir);
  die "The directory $pg_dir does not exist" if (not -d $pg_dir);

}

use lib "$webwork_dir/lib";
use lib "$webwork_dir/webwork3/lib";
use lib "$pg_dir/lib";

use Routes::Admin;

use Test::More;
use Plack::Test;
use JSON;
use HTTP::Request::Common;
use HTTP::Cookies;

use Data::Dump qw/dd dump/;

my $app = Routes::Course->to_app;
is( ref $app, 'CODE', 'Got app' );

my $url  = 'http://localhost';
my $test = Plack::Test->create($app);

my $jar  = HTTP::Cookies->new();

my $res  = $test->request( GET '/courses' );
ok( $res->is_success, '[GET /courses] successful' );

dd decode_json($res->content);

done_testing();
