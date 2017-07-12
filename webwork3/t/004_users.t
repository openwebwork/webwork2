###
#
#  This script tests routes associated with users
#
###

use strict;
use warnings;


my $webwork_dir = "";
my $pg_dir = "";

BEGIN {
  $ENV{PLACK_ENV}='testing';

  $ENV{MOD_PERL_API_VERSION}=2;  # ensure that mod_perl2 is used.
  $webwork_dir = $ENV{WEBWORK_ROOT} || die "The environment variable WEBWORK_ROOT needs to be defined.";
  $pg_dir = $ENV{PG_ROOT};

  if (not defined $pg_dir) {
    $pg_dir = "$webwork_dir/../pg";
  }

  die "The directory $webwork_dir does not exist" if (not -d $webwork_dir);
  die "The directory $pg_dir does not exist" if (not -d $pg_dir);

}

use lib "$webwork_dir/lib";
use lib "$webwork_dir/webwork3/lib";
use lib "$pg_dir/lib";

use Routes::Login;

use Test::More;
use Test::Deep;
use Plack::Test;
use JSON;
use HTTP::Request::Common;
use HTTP::Cookies;
use List::Util qw/first/;

use Data::Dump qw/dd dump/;

my $app = Routes::ProblemSets->to_app;
my $url  = 'http://localhost';
my $test = Plack::Test->create($app);

my $jar  = HTTP::Cookies->new();

subtest 'login to admin course and create a new course_zyx' => sub {
  my $req =  POST "$url/courses/admin/login?username=admin&password=admin";

  my $res = $test->request($req);
  $jar->extract_cookies($res);
  my $result_hash =  decode_json($res->content);

  ok($result_hash->{logged_in}, '[POST /courses/admin/login] using query params successful');

  ## check if new_course_xyz exists.

  $req = GET "$url/admin/courses/new_course_xyz";
  $jar->add_cookie_header($req);
  $res = $test->request($req);

  $result_hash = decode_json($res->content);
    ok($res->is_success, '[GET /admin/courses/new_course_xyz] checked if course exists');
  ok(! $result_hash->{course_exists}, 'The course new_course_xyz does not exist');

  my $params = {
    new_user_id=>"profa",
    new_user_first_name =>"Professor",
    new_user_last_name =>"A",
    initial_password =>"profa"
  };

  $req = HTTP::Request->new(
    "POST","$url/admin/courses/new_course_xyz",
    HTTP::Headers->new('Content-Type' => 'application/json'),
    encode_json($params)
  );
  $jar->add_cookie_header($req);

  $res = $test->request($req);
  ok($res->is_success, '[POST /admin/courses/new_course_id] successfully created a new course');
};

subtest 'Login to new course as profa' => sub {
  my $req =  POST "$url/courses/new_course_xyz/login?username=profa&password=profa";
  my $res = $test->request($req);
  $jar->extract_cookies($res);
  my $result_hash =  decode_json($res->content);

  ok($result_hash->{logged_in}, '[POST /courses/new_course_xyz/login] successfully logged in');

};

subtest 'get users' => sub {
  my $req = GET "$url/courses/new_course_xyz/users";
  $jar->add_cookie_header($req);
  my $res = $test->request($req);
  ok($res->is_success,'[GET /courses/new_course_xyz/users] successful.');
  my $users =  decode_json($res->content);
  is(ref($users),'ARRAY','This route returns an array ref');
  is(scalar(@$users),1,'The course contains a single user.');

  $req = GET "$url/courses/new_course_xyz/users/profa";
  $jar->add_cookie_header($req);
  $res = $test->request($req);
  ok($res->is_success,'[GET /courses/new_course_xyz/users/profa] successful.');
  my $user =  decode_json($res->content);

  is($user->{user_id},'profa','The profa user was returned successfully.');


};

subtest 'Add a single student to the course' => sub {

  my $user_props = get_one_user();

  my $req = HTTP::Request->new(
      "POST","$url/courses/new_course_xyz/users/homer",
      HTTP::Headers->new('Content-Type' => 'application/json'),
      encode_json($user_props)
      );
  $jar->add_cookie_header($req);
  my $res = $test->request($req);
  ok($res->is_success,'[POST /courses/new_course_xyz/users/homer] successful.');
  my $user =  decode_json($res->content);

  $user_props->{_id} = $user_props->{user_id};
  cmp_deeply($user,$user_props,"A user with id home has successfully been created.");

};

subtest 'Add a number of users' => sub {
  my $users = get_multiple_users();

  my $req = HTTP::Request->new(
      "POST","$url/courses/new_course_xyz/users",
      HTTP::Headers->new('Content-Type' => 'application/json'),
      encode_json({ users => $users})
      );
  $jar->add_cookie_header($req);

  my $res = $test->request($req);
  ok($res->is_success,'[POST /courses/new_course_xyz/users] successful.');
  my $returned_users =  decode_json($res->content);

  for my $i (0..$#{$users}){
     $users->[$i]->{_id} = $users->[$i]->{user_id};
  }

  cmp_deeply($users,$returned_users,'Creating multiple users was successful.');
};

### update a user's information:

subtest 'Update a user' => sub {
  my $req = GET "$url/courses/new_course_xyz/users/homer";
  $jar->add_cookie_header($req);
  my $res = $test->request($req);
  ok($res->is_success,'[GET /courses/new_course_xyz/users/homer] successful.');

  my $user = decode_json($res->content);

  $user->{email_address} = "homer\@msn.com";
  $user->{useMathView} = JSON::true;

  $req = HTTP::Request->new(
      "PUT","$url/courses/new_course_xyz/users/homer",
      HTTP::Headers->new('Content-Type' => 'application/json'),
      encode_json($user)
      );
  $jar->add_cookie_header($req);
  $res = $test->request($req);

  my $updated_user = decode_json $res->content;

  cmp_deeply($user,$updated_user,'The user homer was updated successfully');

};

subtest 'check the login status' => sub {
  my $req = GET "$url/courses/new_course_xyz/users/status/login";
  $jar->add_cookie_header($req);
  my $res = $test->request($req);
  ok($res->is_success,'[GET /courses/new_course_xyz/users/status/login] successful.');
  my $result_hash = decode_json $res->content;
  is(ref($result_hash),'ARRAY','The result of the login status is an array ref.');

  my $user_status = first { $_->{user_id} eq 'profa'} @$result_hash;
  ok($user_status->{logged_in},'The user profa is logged in');
  $user_status = first { $_->{user_id} eq 'homer'} @$result_hash;
  ok(!$user_status->{logged_in},'The user homer is not logged in.');
};


### delete users:

subtest 'delete a user' => sub {
  my $req = HTTP::Request->new("DELETE","$url/courses/new_course_xyz/users/homer");
  $jar->add_cookie_header($req);
  my $res = $test->request($req);
  ok($res->is_success,'[DELETE /courses/new_course_xyz/users/homer] successful.');

};

subtest 'delete a non-existent user' => sub {
  my $req = HTTP::Request->new("DELETE","$url/courses/new_course_xyz/users/user_xyz");
  $jar->add_cookie_header($req);
  my $res = $test->request($req);
  ok(! $res->is_success,'[DELETE /courses/new_course_xyz/users/user_xyz] failed successfully.');

};




### delete the course courseXYz


subtest 'delete a course' => sub {
  my $req =  POST "$url/courses/admin/login?username=admin&password=admin";

  my $res = $test->request($req);
  $jar->extract_cookies($res);

  $req =  HTTP::Request->new("DELETE","$url/admin/courses/new_course_xyz");
  $jar->add_cookie_header($req);
  $res = $test->request($req);
  ok($res->is_success, '[DELETE /admin/courses/new_course_xyz] successfully deleted the course');
};

done_testing();


sub get_one_user {
  return {
    first_name => "Homer",
    last_name => "Simpson",
    student_id => "1234",
    user_id => "homer",
    email_address => "homer\@localhost",
    comment        => "",
    permission     => 0,
    displayMode    => "",
    lis_source_did => "",
    recitation     => "",
    section        => "",
    showOldAnswers => JSON::false,
    status         => "",
    useMathView    => JSON::false
  };
}

sub get_multiple_users {
  my $user_names = [
    {first_name => "Aaron", last_name => "Judge", student_id => 1730, user_id => "ajudge"},
    {first_name => "George", last_name => "Springer", student_id => 1729, user_id => "gspringer"},
    {first_name => "Joey", last_name => "Votto", student_id => 1728, user_id => "jvotto"},
    {first_name => "Giancarlo", last_name => "Stanton", student_id => 1727, user_id => "gstanton"},
    {first_name => "Mike", last_name => "Moustakas", student_id => 1726, user_id => "mmoustakas"},
    {first_name => "Cody", last_name => "Bellinger", student_id => 1725, user_id => "cbellinger"},
  ];

  my @users;
  for my $user (@$user_names){
    $user->{email_address} = $user->{user_id} . "\@localhost";
    $user->{comment} = "";
    $user->{permission} = 0;
    $user->{displayMode} = "";
    $user->{lis_source_did} = "";
    $user->{recitation} = "";
    $user->{section} = "";
    $user->{showOldAnswers} = JSON::false;
    $user->{status} = "";
    $user->{useMathView} = JSON::false;

    push(@users,$user);
  }
  return \@users;
}

1;
