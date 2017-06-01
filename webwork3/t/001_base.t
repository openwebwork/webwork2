###
#  This test course is a basic test that the templating of the Webwork 3 app is working.
##

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


use Routes::Templates;
use Routes::Login;
use Test::More tests => 4;
use Plack::Test;
use JSON;
use Data::Dump qw/dd dump/;
use HTTP::Request::Common;

my $app = Routes::Templates->to_app;
is( ref $app, 'CODE', 'Got app' );

my $test = Plack::Test->create($app);
my $res  = $test->request( GET '/' );

ok( $res->is_success, '[GET /] successful' );

$res = $test->request(GET '/courses/test/manager');
ok($res->is_success, ' [GET /courses/test/manager ] successful');


### check the login route
my $test_login_app = Plack::Test->create(Routes::Login->to_app);

$res = $test_login_app->request(POST '/courses/test/login');
ok($res->is_success, '[POST /courses/test/login] successful');



my $params = {user => "profa", password => "profa"};
#dd encode_json($params);
$res = $test->request(POST '/courses/test/login',
            'Content-Type' => 'application/json',
            Content => encode_json($params));

dd $res->content;
