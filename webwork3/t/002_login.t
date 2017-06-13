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

use Routes::Login;

use Test::More;
use Test::Deep;
use Plack::Test;
use JSON;
use HTTP::Request::Common;
use HTTP::Cookies;

use Data::Dump qw/dd dump/;

my $app = Routes::Login->to_app;
my $url  = 'http://localhost';
my $test = Plack::Test->create($app);
my $jar  = HTTP::Cookies->new();


## test if it is actually an app

subtest 'Check for app' => sub {
  is( ref $app, 'CODE', 'Got app' );

};
my $req =  GET "$url/courses/test/info";

my $res  = $test->request($req);
ok( $res->is_success, '[GET /courses/test/info] successful' );

## store the cookies from the first request
$jar->extract_cookies($res);

## Check if the login works with query parameters

subtest 'Check login using query parameters' => sub {
  $req =  POST "$url/courses/test/login?username=dave&password=dave";
  $jar->add_cookie_header($req);
  $res = $test->request($req);
  my $res_as_obj =  decode_json($res->content);

  ok($res_as_obj->{logged_in}, '[POST /courses/test/login] using query params successful');

  ### check if still logged in


  $req = GET "$url/courses/test/logged-in";
  $jar->add_cookie_header($req);

  $res = $test->request($req);
  $res_as_obj = decode_json($res->content);
  ok($res_as_obj->{logged_in}, "[GET /courses/test/logged-in]");

};

subtest 'Check logout ' => sub {

  my $req =  POST "$url/courses/test/logout";
  $jar->add_cookie_header($req);
  my $res = $test->request($req);
  my $res_as_obj =  decode_json($res->content);

  ok($res->is_success, '[POST /courses/test/logout] route exists');
  ok(! $res_as_obj->{logged_in}, '[POST /courses/test/logout] logged out successfully');

};

## Check if the login works with body parameters

subtest 'Check login with body parameters' => sub {

  my $params = {username => "dave",  password=> "dave"};
  my $res = $test->request(POST "$url/courses/test/login",'Content-Type' => 'application/json', Content => encode_json($params));
  my $res_as_obj =  decode_json($res->content);

  ok($res_as_obj->{logged_in}, '[POST] /courses/test/login] using body params successful');

  $jar->extract_cookies($res);

  ### check if still logged in

  $req = GET "$url/courses/test/logged-in";
  $jar->add_cookie_header($req);

  $res = $test->request($req);

  $res_as_obj = decode_json($res->content);
  ok($res_as_obj->{logged_in}, "[GET /courses/test/logged-in]");

};

subtest 'Check the user roles' => sub {


  ## test the user_roles
  my $req = GET "$url/courses/test/users/dave/roles";
  $jar->add_cookie_header($req);
  $res = $test->request($req);
  my $res_as_obj =  decode_json($res->content);

  ok($res->is_success, '[GET /courses/test/users/:user_id/roles]');

  cmp_deeply($res_as_obj,["student"],"The user roles returned correctly. ");
};

subtest 'Check the require_login' => sub {

  my $req = GET "$url/courses/test/test-login";
  $jar->add_cookie_header($req);
  my $res = $test->request($req);

  ok($res->is_success,'require_login is working');

  $req = GET "$url/courses/test/test-for-student";
  $jar->add_cookie_header($req);
  $res = $test->request($req);

  ok($res->is_success,'require_role student is working');

  $res = $test->request(POST "$url/courses/test/login?username=peter&password=peter");
  my $jar2  = HTTP::Cookies->new();
  $jar2->extract_cookies($res);

  $req = GET "$url/courses/test/test-for-professor";
  $jar2->add_cookie_header($req);
  $res = $test->request($req);

  ok($res->is_success, 'require_role professor is working');

};



done_testing();
