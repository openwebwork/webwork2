###
#  This test course is a basic test that the templating of the Webwork 3 app is working.  
##

use strict;
use warnings;

BEGIN {
        die "WEBWORK_ROOT not found in environment.\n" unless exists $ENV{WEBWORK_ROOT};
        die "PG_ROOT not found in environment.\n" unless exists $ENV{PG_ROOT};
                
        use lib "$ENV{WEBWORK_ROOT}/lib";
        use lib "$ENV{WEBWORK_ROOT}/webwork3/lib";
        use lib "$ENV{PG_ROOT}/lib";
        $ENV{MOD_PERL_API_VERSION}=2;
}




use Routes::Templates;
use Routes::Login; 
use Test::More tests => 3;
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



#my $params = {user => "profa", password => "profa"}; 
#dd encode_json($params); 
$res = $test_login_app->request(POST '/courses/test/login?user=profa&password=profa'); 

dd $res->content;

#response_status_is [GET => '/app-info'], 200, "GET /webwork3/app-info is found";
#route_exists [GET => '/app-info'], "GET /webwork3/app-info is handled";




#use strict;
#use warnings;
#
#use problemdb;
#use Test::More tests => 2;
#use Plack::Test;
#use HTTP::Request::Common;
#
#my $app = problemdb->to_app;
#is( ref $app, 'CODE', 'Got app' );
#
#my $test = Plack::Test->create($app);
#my $res  = $test->request( GET '/' );
#
#ok( $res->is_success, '[GET /] successful' );
#
#
#
#use Test::More tests => 5;
#use strict;
#use warnings;
#
#BEGIN {
#        die "WEBWORK_ROOT not found in environment.\n" unless exists $ENV{WEBWORK_ROOT};
#        die "PG_ROOT not found in environment.\n" unless exists $ENV{PG_ROOT};
#                
#        use lib "$ENV{WEBWORK_ROOT}/lib";
#        use lib "$ENV{WEBWORK_ROOT}/webwork3/lib";
#        use lib "$ENV{PG_ROOT}/lib";
#}
#
#
#BEGIN {$ENV{MOD_PERL_API_VERSION}=2}
#
#use WeBWorK3;
#Dancer::set logger => 'console';
#use Dancer qw/:tests/;
#use Dancer::Test;
#
#response_status_is [GET => '/app-info'], 200, "GET /webwork3/app-info is found";
#route_exists [GET => '/app-info'], "GET /webwork3/app-info is handled";
#
#my $resp = dancer_response GET => '/app-info';
#my $obj = from_json $resp->{content};
#is( $obj->{appname}, "webwork3",          "The webapp returned as 'webwork3'" );
#
#route_exists [GET=> '/courses'] , "GET /webwork3/courses is handled.";
#
##route_exists [GET => '/webwork3/courses/test' ], "GET /webwork3/courses/test is handled.";
#
#$resp = dancer_response(GET=>'/courses');
#my @courses = from_json($resp->{content});
#my $type; 
#for my $item (@courses){
#$type = ref($item);
#}
#
#is($type,"ARRAY", "The method GET /webwork3/courses returns an array");
#
#
