###
#
#  This is a script for testing the reordering of problems in a ProblemSet.
#
###


use strict;
use warnings;


my $webwork_dir = "";
my $pg_dir = "";

BEGIN {
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

subtest 'login to admin course and create a new course_zyx and add some users' => sub {
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

my $set;

subtest 'Create a new problem set' => sub {
  # Create a new Problem set that is open today at 10am, has a reduced scoring date 1 week later, a due date 2 days after that
  ## and a answer_date 3 after that.

  my $now = DateTime->today(time_zone=>"America/New_York");
  my $open_date = DateTime->new(year=>$now->year(),month=>$now->month(),day=>$now->day(),
                     hour=>10,minute=>0,second=>0,time_zone=>"America/New_York");
  my $reduced_scoring_date = $open_date->clone()->add(days=>7);
  my $due_date = $reduced_scoring_date->clone()->add(days=>2);
  my $answer_date = $due_date->clone()->add(days=>3);

  $set = { set_id => "set1", open_date => $open_date->epoch(),
                reduced_scoring_date => $reduced_scoring_date->epoch(),
                 due_date => $due_date->epoch(), answer_date => $answer_date->epoch(),
                 assigned_users => [], problems => [],hide_hint => JSON::false,
                 problems_per_page => '', versions_per_interval => '',
                 time_interval => '', hide_score => '', attempts_per_version => '',
                 restricted_login_proctor => '', version_creation_time => '', _id => "set1",
                 set_header => 'defaultHeader', hardcopy_header => 'defaultHeader',
                 restrict_ip => '', hide_score_by_problem => '', problem_randorder => JSON::false,
                 description=>'', hide_work => '', restricted_status => '',version_time_limit => '',
                 relax_restrict_ip => '', restricted_release => '', version_last_attempt_time => '',
                 visible => JSON::false, enable_reduced_scoring => JSON::false,
                 time_limit_cap => JSON::false, assignment_type => "default",
                 email_instructor => '', restrict_prob_progression => ''};

  my $req = HTTP::Request->new(
      "POST","$url/courses/new_course_xyz/sets/set1",
      HTTP::Headers->new('Content-Type' => 'application/json'),
      encode_json($set)
      );
  $jar->add_cookie_header($req);

  my $res = $test->request($req);

  my $result_hash = decode_json($res->content);

  cmp_deeply($result_hash,$set,"A set with id set1 has successfully been created.");

};

subtest 'update a problem set' => sub {
  ### change the open_date, due_date, reduced_scoring_date and answer_date and update the db

  my $updated_set = {%$set};  # make a copy of the set

  my $open_date = DateTime->from_epoch(epoch=>$set->{open_date});
  my $reduced_scoring_date = DateTime->from_epoch(epoch=>$set->{reduced_scoring_date});
  my $due_date = DateTime->from_epoch(epoch=>$set->{due_date});
  my $answer_date = DateTime->from_epoch(epoch=>$set->{answer_date});
  $updated_set->{open_date} = $open_date->clone()->subtract(days=>5)->epoch();
  $updated_set->{reduced_scoring_date} = $reduced_scoring_date->clone()->subtract(days=>3)->epoch();
  $updated_set->{due_date} = $due_date->clone()->add(days=>1)->epoch();
  $updated_set->{answer_date} = $answer_date->clone()->add(days=>3)->epoch();

  my $req = HTTP::Request->new(
      "PUT","$url/courses/new_course_xyz/sets/set1",
      HTTP::Headers->new('Content-Type' => 'application/json'),
      encode_json($updated_set)
      );
  $jar->add_cookie_header($req);

  my $res = $test->request($req);

  my $result_hash = decode_json($res->content);

  cmp_deeply($result_hash,$updated_set,"A set with id set1 has successfully been updated.");

  ###  populate the set with problems

  my @probSources = qw! Library/Utah/Quantitative_Analysis/set1_Preview/q9.pg
                          Library/Utah/Intermediate_Algebra/set3_Linear_Equations_and_Inequalities/s3p12.pg
                          Library/Utah/College_Algebra/set2_Functions_and_Their_Graphs/1050s2p32.pg
                          Library/Utah/College_Algebra/set2_Functions_and_Their_Graphs/1050s2p33.pg
                          Library/Utah/Calculus_II/set7_Infinite_Series/set7_pr18.pg!;
  my $i=1;
  my @problems = map { createProblem("set1",$i++, $_);} @probSources;

  $updated_set->{problems} = \@problems;

  $req = HTTP::Request->new(
      "PUT","$url/courses/new_course_xyz/sets/set1",
      HTTP::Headers->new('Content-Type' => 'application/json'),
      encode_json($updated_set)
      );
  $jar->add_cookie_header($req);
  $res = $test->request($req);

  $set = decode_json($res->content);

  cmp_deeply($set,$updated_set,"A set with id set1 has had problems added successfully");

};

subtest 'reorder problems' => sub {
  ### reorder problems

  ## set the problem with id=4 to id=1 and shift all others by one


  my @order = (2,3,4,1,5);
  my @probs = @{$set->{problems}};
  $set->{_reorder} = JSON::true;

  # for my $p (@probs){
  #   dd $p->{problem_id} . ":::" . $p->{source_file};
  # }

  for my $index (0..$#probs){
     $probs[$index]->{_old_problem_id} = $index+1;
     $probs[$index]->{problem_id} = $order[$index];
  }


  my @problems_in_new_order =  sort { $a->{problem_id} <=> $b->{problem_id} } @probs;
  $set->{problems} = \@problems_in_new_order;
  my $req = HTTP::Request->new(
      "PUT","$url/courses/new_course_xyz/sets/set1",
      HTTP::Headers->new('Content-Type' => 'application/json'),
      encode_json($set)
      );
  $jar->add_cookie_header($req);
  my $res = $test->request($req);

  my $result_hash = decode_json($res->content);

  # for my $p (@{$result_hash->{problems}}){
  #   dd $p->{problem_id} . ":::" . $p->{source_file};
  # }


  for my $prob (@{$set->{problems}}){
    delete $prob->{_old_problem_id};
    $prob->{_id} = $prob->{set_id} . ":" . $prob->{problem_id};
  }
  delete $set->{_reorder};

  cmp_deeply($result_hash,$set,"A set with id set1 had the problems reordered successfully");

};


### delete a problem

subtest 'delete a problem' => sub {
  my @probs = @{$set->{problems}};
  $set->{_delete_problem_id} = int(rand($#probs))+1;



  my $req = HTTP::Request->new(
      "PUT","$url/courses/new_course_xyz/sets/set1",
      HTTP::Headers->new('Content-Type' => 'application/json'),
      encode_json($set)
      );
  $jar->add_cookie_header($req);
  my $res = $test->request($req);

  my $result_hash = decode_json($res->content);

  #dd $result_hash;

  splice @probs, ($set->{_delete_problem_id} -1), 1;
  $set->{problems} =\@probs;
  delete $set->{_delete_problem_id};
  cmp_deeply($result_hash,$set,"The set set1 had a problem successfully deleted.");

};


### change parameters on a problem.



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













sub createProblem {
    my ($setID, $problemID, $sourceFile) = @_;

    return { att_to_open_children => "", counts_parent_grade => "", data => "",
      flags => "", max_attempts => 1, problem_id => $problemID, problem_seed => 1,
      set_id => $setID, _id => $setID . ":" . $problemID, showMeAnother => "",
      showMeAnotherCount => "", source_file => $sourceFile, value => 1,
      prPeriod => -1, prCount => 0};
}
