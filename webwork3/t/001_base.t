use Test::More tests => 5;
use strict;
use warnings;

use Data::Dump qw/dd/; 
use JSON qw/from_json/;

BEGIN {$ENV{MOD_PERL_API_VERSION}=2}

use WeBWorK3;
Dancer::set logger => 'console';
use Dancer::Test;


#
#my $settings = Dancer::Config::settings();
#dd $settings; 

response_status_is [GET => '/app-info'], 200, "GET /webwork3/app-info is found";
route_exists [GET => '/app-info'], "GET /webwork3/app-info is handled";

my $resp = dancer_response GET => '/app-info';
my $obj = from_json $resp->{content};
is( $obj->{appname}, "webwork3",          "The webapp returned as 'webwork3'" );

route_exists [GET=> '/courses'] , "GET /webwork3/courses is handled.";

#route_exists [GET => '/webwork3/courses/test' ], "GET /webwork3/courses/test is handled.";

$resp = dancer_response(GET=>'/courses');
my @courses = from_json($resp->{content});
my $type; 
for my $item (@courses){
$type = ref($item);
}

is($type,"ARRAY", "The method GET /webwork3/courses returns an array");


