use Test::More tests => 3;
use strict;
use warnings;

use Data::Dump qw/dd/;

BEGIN {
        die "WEBWORK_ROOT not found in environment.\n" unless exists $ENV{WEBWORK_ROOT};
        die "PG_ROOT not found in environment.\n" unless exists $ENV{PG_ROOT};
                
        use lib "$ENV{WEBWORK_ROOT}/lib";
        use lib "$ENV{WEBWORK_ROOT}/webwork3/lib";
        use lib "$ENV{PG_ROOT}/lib";
}


BEGIN {$ENV{MOD_PERL_API_VERSION}=2}

use WeBWorK3;
Dancer::set logger => 'console';
use Dancer qw/:tests/;
use Dancer::Test;

## login to the admin course
my $new_course_name = "newcourseXYZ"; 
my $resp = dancer_response(POST=>'/courses/admin/login',{params=>{user=>'admin',password=>'admin'}});
my $obj = from_json $resp->{content};
is($obj->{logged_in},1,"You successfully logged in to the admin course");

## see if the course $new_course_name already exists. 
route_exists [GET => "/courses/$new_course_name "], "GET /webwork3/courses/$new_course_name is handled";


$resp = dancer_response(GET => "/courses/$new_course_name", {headers=>HTTP::Headers->new( 'X-Requested-With' => 'XMLHttpRequest')}); 


## check that that course create URL exists. 

## check if the course $new_course_name exists.
#$resp = dancer_response(DELETE=>'/courses/'. $new_course_name, {headers=>HTTP::Headers->new( 'X-Requested-With' => 'XMLHttpRequest')});
$obj = from_json $resp->{content};

if($obj->{course_exists}) {


    $resp = dancer_response(DELETE=>"/courses/$new_course_name", {params=>{user=>'admin',password=>'admin'}});
    $obj = from_json $resp->{content};

    is($obj->{message},"Course deleted.","The course " . $new_course_name . " was deleted sucessfully.");
} else {
    fail("The delete course test cannot be checked because the course $new_course_name does not exist."); 

}