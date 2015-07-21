use Test::More tests => 4;
use Test::Deep qw/cmp_deeply/;
use strict;
use warnings;
use JSON qw/from_json/;
use Data::Dump qw/dd/;
use DateTime; 
use Utils::Convert qw/convertBooleans/;
use Utils::ProblemSets qw/@boolean_set_props/;

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

## check if the course $new_course_name exists.
$resp = dancer_response(GET=>'/courses/'. $new_course_name, {headers=>HTTP::Headers->new( 'X-Requested-With' => 'XMLHttpRequest')});
$obj = from_json $resp->{content};

my $course_exists = ($obj->{message} ||"") eq "Course exists."; 

if($course_exists) {
    is($obj->{message}, "Course exists.", "The course " .$new_course_name . " exists."); 
} else {
    ## create a new course called $new_course_name 
    $resp = dancer_response(POST=>'/courses/'. $new_course_name, 
            {params=>{user=>'admin',password=>'admin',new_userID => 'profa'}});
    $obj = from_json $resp->{content};

    is($obj->{message},"Course created successfully.","The course " . $new_course_name . " was created sucessfully.");
}

## login to the course $new_course_name as profa

$resp = dancer_response(POST=>"/courses/$new_course_name/login",{params=>{user=>'profa',password=>'profa'}});
$obj = from_json $resp->{content};
is($obj->{logged_in},1,"You successfully logged in to the $new_course_name course");

## Create a new Problem set that is open today at 10am, has a reduced scoring date 1 week later, a due date 2 days after that 
## and a answer_date 3 after that. 

my $now = DateTime->today(time_zone=>"America/New_York");
my $open_date = DateTime->new(year=>$now->year(),month=>$now->month(),day=>$now->day(),
                    hour=>10,minute=>0,second=>0,time_zone=>"America/New_York");
my $reduced_scoring_date = $open_date->clone()->add(days=>7);
my $due_date = $reduced_scoring_date->clone()->add(days=>2);
my $answer_date = $due_date->clone()->add(days=>3); 

my $set = { set_id => "set1", open_date => $open_date->epoch(), reduced_scoring_date => $reduced_scoring_date->epoch(),
                due_date => $due_date->epoch(), answer_date => $answer_date->epoch(), assigned_users => [], problems => [],
                hide_hint => 0, problems_per_page => '', versions_per_interval => '', time_interval => '', hide_score => '',
                attempts_per_version => '',restricted_login_proctor => '', version_creation_time => '', _id => "set1",
                set_header => 'defaultHeader', hardcopy_header => 'defaultHeader', restrict_ip => '', hide_score_by_problem => '',
                problem_randorder => 0, description=>'', hide_work => '', restricted_status => '',
                version_time_limit => '', relax_restrict_ip => '', restricted_release => '', version_last_attempt_time => '',
                visible => 0, enable_reduced_scoring => 0, time_limit_cap => 0, assignment_type => "default"}; 


$resp = dancer_response(POST=>"/courses/$new_course_name/sets/set1",{params=>$set});
$obj = from_json $resp->{content}; 
my $obj2 = convertBooleans($obj,\@boolean_set_props);

cmp_deeply $obj2, $set, "yippee!";


sub toString {
    my $obj = shift; 
    for my $key (keys(%$obj)){
        $obj->{$key} = '' . $obj->{$key};
    }
    return $obj;
}