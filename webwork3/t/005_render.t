##
#  The tests in here are to check if the renderer is working correctly. 
#
##

use Test::More tests => 2;
use strict;
use warnings;

use Data::Dump qw/dd dump/; 
#use JSON qw/from_json/;

BEGIN {
        die "WEBWORK_ROOT not found in environment.\n" unless exists $ENV{WEBWORK_ROOT};
        die "PG_ROOT not found in environment.\n" unless exists $ENV{PG_ROOT};
                
        use lib "$ENV{WEBWORK_ROOT}/lib";
        use lib "$ENV{WEBWORK_ROOT}/webwork3/lib";
        use lib "$ENV{PG_ROOT}/lib";
}

my $webwork_dir = $ENV{WEBWORK_ROOT};

BEGIN {$ENV{MOD_PERL_API_VERSION}=2}

use WeBWorK3;
Dancer::set logger => 'console';
use Dancer qw/:tests/;

use Dancer::Test;
use Dancer::FileUtils qw/read_file_content/;


### 
#  For this, we need to have a default login:
###

my $new_course_name = "newcourseXYZ";

my $resp = dancer_response(POST=>"/courses/$new_course_name/login",{params=>{user=>'profa',password=>'profa'}});
my $obj = from_json $resp->{content};
is($obj->{logged_in},1,"You successfully logged in to the $new_course_name course");

route_exists [POST => '/renderer'], "POST /webwork3/rendered is handled";

#
#my $settings = Dancer::Config::settings();

my $path_to_pg_problem = path($webwork_dir,"..","libraries","webwork-open-problem-library","OpenProblemLibrary","Rochester","set0","prob1.pg");

my $problem_source = read_file_content($path_to_pg_problem); 


my $params = {course_id=>$new_course_name, user=>'profa',password=>'profa', source=>$problem_source};

$resp = dancer_response(POST=>'/renderer', {params=>$params});

#$params = {course_id=>$new_course_name, user=>'profa',password=>'profa', source_file=>"Library/Rochester/set0/prob1.pg"};



#$resp = dancer_response(POST=>'/renderer', {params=>$params});

$obj = from_json($resp->{content});

debug $obj->{text}; 


