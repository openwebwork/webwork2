use Test::More tests => 3;
use strict;
use warnings;
use JSON qw/from_json/;
use Data::Dump qw/dd/;

BEGIN {$ENV{MOD_PERL_API_VERSION}=2}

# the order is important
use WeBWorK3;
Dancer::set logger => 'console';
#Dancer::set log => 'core';
use Dancer::Test;


## login to the admin course
my $new_course_name = "newcourseXYZ"; 
my $resp = dancer_response(POST=>'/courses/admin/login',{params=>{user=>'admin',password=>'admin'}});
my $obj = from_json $resp->{content};
is($obj->{logged_in},1,"You successfully logged in to the admin course");

## see if the course $new_course_name already exists. 
route_exists [GET => '/courses/'. $new_course_name ], "GET /webwork3/courses/" . $new_course_name . " is handled";


## check that that course create URL exists. 
#route_exists [DELETE => '/courses/'. $new_course_name ], "DELETE /webwork3/courses/" . $new_course_name . " is handled";

## check if the course $new_course_name exists.
$resp = dancer_response(DELETE=>'/courses/'. $new_course_name, {headers=>HTTP::Headers->new( 'X-Requested-With' => 'XMLHttpRequest')});
$obj = from_json $resp->{content};

my $course_exists = $obj->{message} eq "Course exists."; 
dd $course_exists;
if($course_exists) {

## create a new course called $new_course_name 
    $resp = dancer_response(DEL=>'/courses/'. $new_course_name, 
            {params=>{user=>'admin',password=>'admin'}});
    $obj = from_json $resp->{content};

    is($obj->{message},"Course deleted.","The course " . $new_course_name . " was created sucessfully.");
}