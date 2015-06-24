use Test::More tests => 2;
use strict;
use warnings;

# the order is important
use Dancer::Test;

response_status_is [GET => '/app-info'], 200, "GET / is found";
route_exists [GET => 'http://localhost/webwork3/app-info'], 'a route handler is defined for /app-info';
#response_status_is ['GET' => '/'], 200, 'response status is 200 for /';
