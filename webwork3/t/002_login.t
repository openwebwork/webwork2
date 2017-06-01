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
use Plack::Test;
use JSON;
use HTTP::Request::Common;
use HTTP::Cookies;

use Data::Dump qw/dd dump/;

my $app = Routes::Login->to_app;
is( ref $app, 'CODE', 'Got app' );

my $url  = 'http://localhost';
my $test = Plack::Test->create($app);

my $jar  = HTTP::Cookies->new();

my $res  = $test->request( GET '/courses/test/info' );
ok( $res->is_success, '[GET /courses/test/info] successful' );

#dd decode_json($res->content);


## test login as student

$res = $test->request(POST "$url/courses/test/login?username=dave&password=dave");
my $res_as_obj =  decode_json($res->content);
#dd $res_as_obj;
ok($res_as_obj->{logged_in}, '[POST /courses/test/login] using query params successful');
$jar->extract_cookies($res);

my $params = {username => "dave",  password=> "dave"};
$res = $test->request(POST "$url/courses/test/login",'Content-Type' => 'application/html', Content => encode_json($params));
$res_as_obj =  decode_json($res->content);
#dd $res;
#dd $res_as_obj;
ok($res_as_obj->{logged_in}, '[POST] /courses/test/login] using body params successful');

#dd $jar->as_string;

my $req = GET "$url/courses/test/test-login";



# add cookies to the request
$jar->add_cookie_header($req);

#dd $req;
#
$res = $test->request($req);
#dd $res;
ok($res->is_success,'Session is working');

done_testing();
