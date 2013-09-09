#!/local/bin/perl

use Furl;
use strict;


    my $furl = Furl->new(
        agent   => 'MyGreatUA/2.0',
        timeout => 10,
    );


# This is a test of the Webwork RESTful webservice
#
# This document tests the User routes. 
#
# First, make sure that you have a user with instructor priviledges and a valid session key for a course


  
my $url_head = 'http://localhost/test/';

  # my $content = $lwpcurl->post($post_url, $hash_form, $referer);

my $user='profa';
my $key='xJuvxYyETp5y8K1YxHsZX5lMFAfJYFad';
my $course_id='maa101';

# get all sets for the course




print "Testing GET /courses  \n";

my $url = $url_head . 'courses';

my $params = {user=>$user, course=>$course_id,session_key=>$key};
my $res = $furl->request(method=>'GET',url=>$url,content=>$params);

die $res->status_line unless $res->is_success;
print $res->content;


print "Testing GET /courses/:course_id without checking the course database\n";

$url = $url_head . 'courses/maa101';

$res = $furl->request(method=>'GET',url=>$url,content=>$params);

die $res->status_line unless $res->is_success;
print $res->content;


print "Testing GET /courses/:course_id with checking the course database\n";

$url = $url_head . 'courses/maa101';
my $params2 = {%$params};
$params2->{checkCourseTables}=1;

$res = $furl->request(method=>'GET',url=>$url,content=>$params2);

die $res->status_line unless $res->is_success;
print $res->content;


## check if the course test exists

my $params3 = {%$params};
$url = $url_head . 'courses/test';

# for my $key (keys(%{$params3})){
# 	my $value = $params3->{$key} if defined($params3->{$key});
# 	print "$key : $value \n";
# }

$res = $furl->request(method=>'GET',url=>$url,content=>$params3);

die $res->status_line unless $res->is_success;
print $res->content;

if (!{$res->content}) {  # delete the test course
	$url = $url_head . 'courses/test';	
	$res = $furl->request(method=>'DELETE',url=>$url,content=>$params3);

}



# Create a new problem set called xyz123 with some standard values

# SET=xyz123

# echo "Testing POST /courses/$COURSE/sets/$SET"

#OPEN_DATE='date -j -f "%a %b %d %T %Z %Y" "`date`" "+%s"'  # set it to right now
# OPEN_DATE=1375075134

# echo $OPEN_DATE

# curl -X POST -d "user=$INSTR&course=$COURSE&session_key=$KEY&open_date=$OPEN_DATE" http://localhost/test/courses/$COURSE/sets/$SET
