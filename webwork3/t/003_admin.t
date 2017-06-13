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

my $app = Routes::Admin->to_app;
is( ref $app, 'CODE', 'Got app' );

my $url  = 'http://localhost';
my $test = Plack::Test->create($app);

my $jar  = HTTP::Cookies->new();

subtest 'GET /courses' => sub {
  my $res  = $test->request( GET '/courses' );
  $jar->extract_cookies($res);
  ok( $res->is_success, '[GET /courses] successful' );
  my $courses = decode_json($res->content);

  ok(ref $courses eq 'ARRAY', '[GET /courses] returns an array');
};

subtest 'login to admin course' => sub {
  my $req =  POST "$url/courses/admin/login?username=admin&password=admin";

  my $res = $test->request($req);
  $jar->extract_cookies($res);
  my $res_as_obj =  decode_json($res->content);

  ok($res_as_obj->{logged_in}, '[POST /courses/admin/login] using query params successful');

  # check that is logged in as an admin.

  ## test the user_roles
  $req = GET "$url/courses/admin/users/admin/roles";
  $jar->add_cookie_header($req);
  $res = $test->request($req);

  $res_as_obj =  decode_json($res->content);

  ok($res->is_success, '[GET /courses/admin/users/:user_id/roles]');

  cmp_deeply($res_as_obj,["admin"],"The user roles returned correctly. ");

  ## check that a restricted route is accesible.

  $req = GET "$url/courses/admin/test-for-admin";
  $jar->add_cookie_header($req);
  $res = $test->request($req);
  ok($res->is_success, '[GET /admin/courses/admin/test-for-admin] is successful');
};

subtest 'create a course' => sub {
  my $params = {
    new_user_id=>"profa",
    new_user_first_name =>"Professor",
    new_user_last_name =>"A",
    initial_password =>"profa"
  };
  # my $req = POST "$url/courses/new_course_xyz";
  # $req->header('Content-Type' => 'application/json');
  # $req->content(encode_json($params));
  my $req = HTTP::Request->new(
    "POST","$url/admin/courses/new_course_xyz",
    HTTP::Headers->new('Content-Type' => 'application/json'),
    encode_json($params)
  );
  $jar->add_cookie_header($req);

  my $res = $test->request($req);
  ok($res->is_success, '[POST /admin/courses/new_course_id] successfully created a new course');
};

subtest 'rename a course' => sub {
  my $params = {
    new_course_id=>"course_zyx",
  };
  # my $req = POST "$url/admin/courses/new_course_xyz";
  # $req->header('Content-Type' => 'application/json');
  # $req->content(encode_json($params));
  my $req = HTTP::Request->new(
    "PUT","$url/admin/courses/new_course_xyz",
    HTTP::Headers->new('Content-Type' => 'application/json'),
    encode_json($params)
  );
  $jar->add_cookie_header($req);
  #dd $req;
  my $res = $test->request($req);
  ok($res->is_success, '[PUT /admin/courses/new_course_id] successfully renamed the course');
};


subtest 'delete a course' => sub {
  my $req =  HTTP::Request->new("DELETE","$url/admin/courses/course_zyx");
  $jar->add_cookie_header($req);
  my $res = $test->request($req);
  ok($res->is_success, '[DELETE /admin/courses/new_course_id] successfully deleted the course');
};

done_testing();
