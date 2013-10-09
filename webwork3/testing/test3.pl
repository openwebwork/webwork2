#!/local/bin/perl

use Furl;
use strict;
use Data::Dumper;
use JSON;

use Utils::LibraryUtils qw/list_pg_files/;

my $probLib = {Library=>"OPL Library"};
#my %probLib = ("Library","OPL Library");

my @dirs = ("Library","test1","test2");

@dirs = grep {!$probLib->{$_}} @dirs;

print Dumper(@dirs);




#print list_pg_files("/Volumes/WW_test/opt/webwork/courses/maa101/templates",'.',%probLib) . "\n";



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
