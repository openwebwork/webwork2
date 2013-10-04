#!/local/bin/perl

use Furl;
use strict;
use Data::Dumper;
use JSON;

my $i =0; 
	open (LOG, "/Volumes/WW_test/opt/webwork/courses/Math2300_Spring2013/logs/answer_log");
	while (<LOG>) {
 		chomp;
	 	my @line = split(/\|/,$_);
	 	print $i;
	 	my $userID = $line[1];
	 	my $setID = $line[2];
	 	my $problemID = $line[3];
	 	my @tmp = split(/\t/,$line[4]); 
	 	my $scores = shift(@tmp);
	 	my $timestamp = shift(@tmp);
	 	my $answerString = join("\t",@tmp);


	 	my $problem = {user_id =>$userID, set_id=>$setID, problem_id=>$problemID, 
	 			scores=>$scores,timestamp=>$timestamp,answer_string=>$answerString};

	 	print Dumper($problem); 

	 	if ($i++ > 13) {last;}
	}
	close (LOG);

exit;



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
my $key='lxeR8m0o0zkGxM4CPq2THDHZC7PWydWE';
my $course_id='maa101';

my $params = {user=>$user, course=>$course_id,session_key=>$key};
my ($res,$url);


my $routeName = "login";

print "logging in to set the session  \n";

$url = $url_head . "$routeName";


$res = $furl->request(method=>'GET',url=>$url,content=>$params);

die $res->status_line unless $res->is_success;
print $res->content . "\n";

## test #1  

# get all settings


if ("1" ~~ @ARGV){

	my $routeName = "courses/maa101/settings";

	print "Testing GET /$routeName  \n";

	$url = $url_head . "$routeName";


	$res = $furl->request(method=>'GET',url=>$url);

	die $res->status_line unless $res->is_success;
	print $res->content;

}
