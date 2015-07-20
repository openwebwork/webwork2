use Test::More tests => 4;
use strict;
use warnings;

use Data::Dump qw/dd/; 
use JSON qw/from_json/;

BEGIN {$ENV{MOD_PERL_API_VERSION}=2}

#Dancer::set appdir => '/Library/WebServer/Documents/webwork/webwork2/webwork3';




use WeBWorK3;
use Dancer::Test;
#Dancer::import({appdir => '/Library/WebServer/Documents/webwork/webwork2/webwork3'});
#Dancer::set appdir => '/Library/WebServer/Documents/webwork/webwork2/webwork3';
#Dancer::set log => "debug";
#Dancer::Config->load;

my $settings = Dancer::Config::settings();

dd $settings;




response_status_is [GET => '/app-info'], 200, "GET /webwork3/app-info is found";
route_exists [GET => '/app-info'], "GET /webwork3/app-info is handled";

my $resp = dancer_response GET => '/app-info';
my $obj = from_json $resp->{content};
is( $obj->{appname}, "webwork3",          "The webapp returned as 'webwork3'" );

#route_exists [GET=> '/webwork3/courses'] , "GET /webwork/courses is handled.";

#route_exists [GET => '/webwork3/courses/test' ], "GET /webwork3/courses/test is handled.";

$resp = dancer_response(GET=>'/webwork3/courses');
dd $resp;

my $new_course_name = "newcourseXYZ"; 
#$resp = dancer_response(POST=>'/courses/'. $new_course_name . '/login',{params=>{user=>'admin',password=>'admin'}});
#$obj = from_json $resp->{content};
#is($obj->{logged_in},1,"You successfully logged in");

#route_exists [POST => '/webwork3/courses'. $new_course_name ], "POST /webwork3/courses " . $new_course_name . " is handled";
#
#$resp = dancer_response(POST=>'/webwork3/courses/'. $new_course_name);
#
#dd $resp;
#$obj = from_json $resp->{content};
#
#dd $obj;

