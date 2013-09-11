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

my $params = {user=>$user, course=>$course_id,session_key=>$key};
my ($res,$url);

## test #1  

# get all sets for the course


if ("1" ~~ @ARGV){

	print "Testing GET /courses  \n";

	$url = $url_head . 'courses';

	$res = $furl->request(method=>'GET',url=>$url,content=>$params);

	die $res->status_line unless $res->is_success;
	print $res->content;

}

## test #2

if ("2" ~~ @ARGV){

	print "Testing GET /courses/:course_id without checking the course database\n";

	$url = $url_head . 'courses/maa101';

	$res = $furl->request(method=>'GET',url=>$url,content=>$params);

	die $res->status_line unless $res->is_success;
	print $res->content;

}

## test #3

if ("3" ~~ @ARGV) {
	print "Testing GET /courses/:course_id with checking the course database\n";

	$url = $url_head . 'courses/maa101';
	my $params2 = {%$params};
	$params2->{checkCourseTables}=1;

	$res = $furl->request(method=>'GET',url=>$url,content=>$params2);

	die $res->status_line unless $res->is_success;
	print $res->content;
}


## test #4

## check if the course test exists

if ("4" ~~ @ARGV) {

	my $routeName = 'courses/test'
	my $params3 = {%$params};
	$url = $url_head . "$routeName";

	# for my $key (keys(%{$params3})){
	# 	my $value = $params3->{$key} if defined($params3->{$key});
	# 	print "$key : $value \n";
	# }

	print "Creating the course \"test\" \n";
	my $params4 = {%$params};
	$params4->{new_userID} = "profa";
	$url = $url_head . 'courses/test';
	$res = $furl->request(method=>'POST',url=>$url,content=>$params4);
	die $res->status_line unless $res->is_success;
	print $res->content;


}

## test #5

## delete the course "test"

if ("5" ~~ @ARGV){
	print "Deleting the course \"test\" \n";

	my $params5 = {%$params};
	$url = $url_head . 'courses/test';

	$res = $furl->request(method=>'DELETE',url=>$url,content=>$params5);
	die $res->status_line unless $res->is_success;
	print $res->content;

}
