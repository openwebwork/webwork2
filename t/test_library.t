use strict;
use warnings;


use HTTP::Request::Common;
use LWP::UserAgent;
use HTTP::Cookies;
use Test::More;
use JSON;

use Data::Dump qw/dd/;

my $ua = LWP::UserAgent->new;
my $jar  = HTTP::Cookies->new();
my $key;

##
#
# the following needs an existing course (often for testing) with a user
#
###

subtest 'Login to an existing course' => sub {
  my $req = POST 'http://localhost/webwork2/test',
  Content_Type => 'form-data',
  Content      => [
    user => 'peter',
    passwd => 'peter'
  ];
  my $res = $ua->request($req);
  ok($res->content !~ /Your authentication failed./,
      'Successfully logged into course');

  if($res->content =~ /key=(\w*)/){
    $key = $1;
  }
};

subtest 'Test some library subroutines via instructorXMLHandler' => sub {
  my $content = [
   xml_command => 'searchLib',
   session_key => $key,
   user => 'peter',
   library_name => 'Library',
   courseID => 'test',
   command => 'countDBListings',
   library_subjects => 'Calculus - single variable'
];



  my $req = POST 'http://localhost/webwork2/instructorXMLHandler',
       Content_Type => 'form-data',
       Content      => $content;
  my $res = $ua->request($req);

  my $result = decode_json($res->content);
  ok(($result->{server_response} eq 'Count done.') && ($result->{result_data}[0] > 0),
    'returned a nonzero number of problems in the library.');

  pop(@{$content});
  push(@{$content},'Trigonometry" and dbsj.name="Geometry"');

  $req = POST 'http://localhost/webwork2/instructorXMLHandler',
       Content_Type => 'form-data',
       Content      => $content;

  $res = $ua->request($req);

  $result = decode_json($res->content);
  ok(($result->{server_response} eq 'Count done.') && ($result->{result_data}[0] == 0),
    'Successfully checked a simple SQL injection.');

};

done_testing();
