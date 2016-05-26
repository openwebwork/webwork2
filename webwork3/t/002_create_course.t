use Test::More tests => 4;
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
route_exists [GET => '/courses/'. $new_course_name ], "GET /webwork3/courses/" . $new_course_name . " is handled";


## check that that course create URL exists. 
route_exists [POST => '/courses/'. $new_course_name ], "POST /webwork3/courses/" . $new_course_name . " is handled";

## check if the course $new_course_name exists.
$resp = dancer_response(GET=>'/courses/'. $new_course_name, {headers=>HTTP::Headers->new( 'X-Requested-With' => 'XMLHttpRequest')});
$obj = from_json $resp->{content};

my $course_exists = ($obj->{message} ||"") eq "Course exists."; 

if($course_exists) {
    is($obj->{message}, "Course exists.", "The course $new_course_name exists.  We can't test that the course is created.  Delete the course $new_course_name first. "); 
} else {
    ## create a new course called $new_course_name 
    $resp = dancer_response(POST=>'/courses/'. $new_course_name, 
            {params=>{user=>'admin',password=>'admin',new_userID => 'profa'}});
    $obj = from_json $resp->{content};

    is($obj->{message},"Course created successfully.","The course " . $new_course_name . " was created sucessfully.");
}