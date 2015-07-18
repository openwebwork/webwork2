use strict;
use warnings;
use Test::More tests => 3;
use Data::Dump qw/dd/; 
use JSON qw/from_json/;
use WeBWorK3;


Dancer::set environment => 'testing';
Dancer::Config->load;



use Dancer::Test;

response_status_is [GET => '/app-info'], 200, "GET /webwork3/app-info is found";
route_exists [GET => '/app-info'], "GET /webwork3/app-info is handled";

my $resp = dancer_response GET => '/app-info';
my $obj = from_json $resp->{content};
is( $obj->{appname}, "webwork3",          "The webapp returned as 'webwork3'" );


