#!/local/bin/perl

use Furl;
use strict;
use JSON;



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

# get a list of all problem sets 


if ("1" ~~ @ARGV){

	my $routeName = "courses/maa101/sets";

	print "Testing GET /$routeName  \n";

	$url = $url_head . "$routeName";


	$res = $furl->request(method=>'GET',url=>$url,content=>$params);

	die $res->status_line unless $res->is_success;
	print $res->content;

}

## test #2 

# get problem set xyz123


if ("2" ~~ @ARGV){

	my $routeName = "courses/maa101/sets/xyz123";

	print "Testing GET /$routeName  \n";

	$url = $url_head . "$routeName";


	$res = $furl->request(method=>'GET',url=>$url,content=>$params);

	die $res->status_line unless $res->is_success;
	print $res->content;

}

## test #3

# delete problem set xyz123


if ("3" ~~ @ARGV){

	my $routeName = "courses/maa101/sets/xyz123";

	print "Testing DELETE /$routeName  \n";

	$url = $url_head . "$routeName";


	$res = $furl->request(method=>'DELETE',url=>$url,content=>$params);

	die $res->status_line unless $res->is_success;
	print $res->content;

}

## test #4

# create problem set xyz123


if ("4" ~~ @ARGV){

	my $routeName = "courses/maa101/sets/xyz123";

	print "Testing POST /$routeName  \n";

	$url = $url_head . "$routeName";

	my $params4 = {%$params};

	$params4->{open_date} = time;


	$res = $furl->request(method=>'POST',url=>$url,content=>$params4);

	die $res->status_line unless $res->is_success;
	print $res->content;

}

## test #5

# update problem set xyz123


if ("5" ~~ @ARGV){

	my $routeName = "courses/maa101/sets/xyz123";

	print "Testing PUT /$routeName  \n";

	$url = $url_head . "$routeName";

	my $params4 = {%$params};

	$params4->{open_date} = time+24*60*60;


	$res = $furl->request(method=>'PUT',url=>$url,content=>$params4);

	die $res->status_line unless $res->is_success;
	print $res->content;

}

## test #6

# add a new problem to set xyz123

if ("6" ~~ @ARGV){

	my $routeName = "courses/maa101/sets/xyz123/problems/1234";

	print "Testing POST /$routeName  \n";

	$url = $url_head . "$routeName";

	
	$res = $furl->request(method=>'POST',url=>$url,content=>$params);

	die $res->status_line unless $res->is_success;
	print $res->content;	
}

## test #7

# get all problems for set xyz123

if ("7" ~~ @ARGV){

	my $routeName = "courses/maa101/sets/xyz123/problems";

	print "Testing GET /$routeName  \n";

	$url = $url_head . "$routeName";

	
	$res = $furl->request(method=>'GET',url=>$url,content=>$params);

	die $res->status_line unless $res->is_success;
	print $res->content;	
}

## test #8

# change the order of the problems

if ("8" ~~ @ARGV) {
	my $routeName = "courses/maa101/sets/xyz123/problems";

	print "First we get all of the problems \n";
	print "Testing GET /$routeName  \n";

	$url = $url_head . "$routeName";
	$res = $furl->request(method=>'GET',url=>$url,content=>$params);
	die $res->status_line unless $res->is_success;

	print $res->content;
	my $problems = decode_json($res->content);

	my @problemPaths = ();
	my @problemIndices = ();



	$problems->[0]->{problem_id} = 6;
	$problems->[1]->{problem_id} = 4;

	for my $prob (@$problems) {
		print $prob->{source_file} . "\n";
		push(@problemPaths,$prob->{source_file});
		push(@problemIndices,$prob->{problem_id});
	}

	$routeName = "courses/maa101/sets/xyz123/order"; 
	print "Then we send the problems back with a different order \n";
	print "Testing PUT /$routeName  \n";

	my $params8 = {%$params};

	$params8->{problem_paths} = join(",",@problemPaths);
	$params8->{problem_indices} = join(",",@problemIndices);

	$url = $url_head . "$routeName";
	$res = $furl->request(method=>'PUT',url=>$url,content=>$params8);
	die $res->status_line unless $res->is_success;

	print $res->content;


}






