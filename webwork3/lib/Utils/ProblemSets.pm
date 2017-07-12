## This is a number of common subroutines needed when processing the routes.


package Utils::ProblemSets;
use base qw(Exporter);

use List::Util qw(first);
use List::MoreUtils qw/first_index indexes/;
use Data::Dump qw/dump/;

use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash convertBooleans/;
use WeBWorK::Utils qw/writeCourseLog encodeAnswers writeLog cryptPassword/;
use Array::Utils qw/array_minus/;

our @set_props = qw/set_id set_header hardcopy_header open_date reduced_scoring_date due_date answer_date visible
          enable_reduced_scoring assignment_type description attempts_per_version time_interval
          versions_per_interval version_time_limit version_creation_time version_last_attempt_time
          problem_randorder hide_score hide_score_by_problem hide_work time_limit_cap restrict_ip
          relax_restrict_ip restricted_login_proctor hide_hint/;

our @user_set_props = qw/user_id set_id psvn set_header hardcopy_header open_date reduced_scoring_date due_date
          answer_date visible enable_reduced_scoring assignment_type description restricted_release
          restricted_status attempts_per_version time_interval versions_per_interval version_time_limit
          version_creation_time problem_randorder version_last_attempt_time problems_per_page
          hide_score hide_score_by_problem hide_work time_limit_cap restrict_ip relax_restrict_ip
          restricted_login_proctor hide_hint/;
our @problem_props = qw/problem_id flags value max_attempts status source_file prPeriod prCount/;
our @boolean_set_props = qw/visible enable_reduced_scoring hide_hint time_limit_cap problem_randorder/;

our @user_problem_props = qw/user_id set_id problem_id source_file value max_attempts showMeAnother
        showMeAnotherCount flags problem_seed status attempted last_answer num_correct num_incorrect
        sub_status flags prPeriod prCount/;


our @EXPORT    = ();
our @EXPORT_OK = qw(reorderProblems addGlobalProblems deleteProblems addUserProblems addUserSet
        createNewUserProblem getGlobalSet record_results updateProblems shiftTime
        unshiftTime putGlobalSet putUserSet getUserSet putUserProblem
        @time_props @set_props @user_set_props @problem_props @boolean_set_props);

sub getGlobalSet {
  my ($db,$ce,$setName) = @_;
  my $set = $db->getGlobalSet($setName);
  my $problemSet = convertObjectToHash($set,\@boolean_set_props);

  my @users = $db->listSetUsers($setName);
  my @problems = $db->getAllGlobalProblems($setName);
  for my $problem (@problems){
    $problem->{_id} = $problem->{set_id} . ":" . $problem->{problem_id};  # this helps backbone on the client side
  }

  my $proctor_id = "set_id:".$set->{set_id};
  if($db->existsUser($proctor_id)){
    if($db->getPassword($proctor_id)){
      $problemSet->{pg_password}='******';
    }
  }



  $problemSet->{assigned_users} = \@users;
  $problemSet->{problems} = convertArrayOfObjectsToHash(\@problems);
  $problemSet->{_id} = $setName; # this is needed so that backbone works with the server.

  return $problemSet;
}


###
#
#  This puts/updates the global set with properties in the hash ref $set
#
###

sub putGlobalSet {
  my ($db,$ce,$set) = @_;

  my $set_from_db = $db->getGlobalSet($set->{set_id});
  $set = convertBooleans($set,\@boolean_set_props);

  for my $key (@set_props){
    $set_from_db->{$key} = $set->{$key} if defined($set->{$key});
  }

  ## if the set is a proctored gateway

  if($set->{assignment_type} eq 'proctored_gateway'){
    my $proctor_id = "set_id:".$set->{set_id};
    ## if the proctor doesn't exist as a user in the db, create it.
    if(! $db->existsUser($proctor_id)){
      my $proctor = $db->newUser();
      $proctor->user_id($proctor_id);
      $proctor->last_name("Proctor");
      $proctor->first_name("Login");
      $proctor->student_id("loginproctor");
      $proctor->status($ce->status_name_to_abbrevs('Proctor'));
      $db->addUser($proctor);

      ## add a permission level to the database.
      my $procPerm = $db->newPermissionLevel;
      $procPerm->user_id($proctor_id);
      $procPerm->permission($ce->{userRoles}->{login_proctor});
      $db->addPermissionLevel($procPerm);
      $set_from_db->restricted_login_proctor('Yes');
    }

    if($set->{pg_password} ne '******') {
      my $dbPass = $db->getPassword($proctor_id);
      if(! defined($dbPass)){
        $dbPass = $db->newPassword($proctor_id);
        $dbPass->user_id($proctor_id);
      }
      my $clearPassword = $set->{pg_password};
      $dbPass->password(cryptPassword($set->{pg_password}));
      $db->putPassword($dbPass);
      $set->{pg_password}=($clearPassword eq '')? '' : '******';
    }

  }

  return $db->putGlobalSet($set_from_db);
}

###
#
#  The gets a userSet (mergedSet) with given $user_id and $set_id
#
###

sub getUserSet{
  my ($db,$user_id,$set_id) = @_;

  my $mergedSet = $db->getMergedSet($user_id,$set_id);

  $mergedSet->{_id} = $mergedSet->{set_id} . ":" . $mergedSet->{user_id};

  return convertObjectToHash($mergedSet,\@boolean_set_props);

}

###
#
#  This puts/updates the user set with properties in the hash ref $set  Update only the values that
# differ from the global set properties
#
###


sub putUserSet {
  my ($db,$set) = @_;

  # get the global problem set to determine if the value has changed
  my $globalSet = $db->getGlobalSet($set->{set_id});
  my $userSet = $db->getUserSet($set->{user_id},$set->{set_id});

  $set = convertBooleans($set,\@boolean_set_props);
  for my $key (@user_set_props) {
    my $globalValue = $globalSet->{$key} || "";
    # check to see if the value differs from the global value.  If so, set it else delete it.
    $userSet->{$key} = $set->{$key} if defined($set->{$key});
    delete $userSet->{$key} if $globalValue eq $userSet->{$key} && $key ne "set_id";

  }
  $db->putUserSet($userSet);

  return getUserSet($db,$set->{user_id},$set->{set_id});
}

####
#
#  This puts/updates the problem properties for the given problem. Only properties that differ from the global problem
# are updated.
#
####

sub putUserProblem {
  my ($db,$problem) = @_;

  # get the global problem to determine if the value has changed
  my $globalProblem = $db->getGlobalProblem($problem->{set_id},$problem->{problem_id});
  my $userProblem = $db->getUserProblem($problem->{user_id},$problem->{set_id},$problem->{problem_id});

  for my $key (@user_problem_props){
    my $globalValue = $globalProblem->{$key} || "";
    $userProblem->{$key} = $problem->{$key} if defined($problem->{$key});
    delete $userProblem->{$key} if $globalValue eq $userProblem->{$key}
    && $key ne "problem_id" && $key ne "set_id" && $key ne 'user_id';
  }

  $db->putUserProblem($userProblem);
  return $userProblem;
}


#####
#
#  This reorders the problems in a set. They come in as an array reference $new_problems
#  with given new problem ids.  The result is new problem ids in the order of the array
#  of problems.
#
###

sub reorderProblems {
  my ($db,$set_id,$new_problems,$assigned_users) = @_;

  warn "in reorderProblems\n";

  ###
  #
  # 1) each reordered problem is given a problem_id starting at 1001
  # 2) then each user problem is also assign the same.
  # 3) the old problems are then deleted.
  # 4) then the problems ordered 1001,1002, ... are rebuilt with the ordering 1,2,...
  #
  ###

  for my $i (0..scalar(@$new_problems)-1){
    warn dump $new_problems->[$i];
    my $prob = $db->getGlobalProblem($set_id,$new_problems->[$i]->{_old_problem_id});
    warn dump $prob; 
    $prob->{problem_id} = $i+1001; # assume there is no problem greater than 1000.
    $db->addGlobalProblem($prob);

    for my $user_id (@$assigned_users){
      my $userProblem = $db->getUserProblem($user_id,$set_id,$new_problems->[$i]->{_old_problem_id});
      $userProblem->{problem_id} = $i+1001;
      $db->addUserProblem($userProblem);
    }
    $db->deleteGlobalProblem($set_id,$new_problems->[$i]->{_old_problem_id});
  }

  for my $prob_id ($db->listGlobalProblems($set_id)){
    my $prob = $db->getGlobalProblem($set_id,$prob_id);
    $prob->{problem_id} = $prob_id-1000;
    $db->addGlobalProblem($prob);
    for my $user_id (@$assigned_users){
      my $userProblem = $db->getUserProblem($user_id,$set_id,$prob_id);
      $userProblem->{problem_id} = $prob_id-1000;
      $db->addUserProblem($userProblem);
    }
    $db->deleteGlobalProblem($set_id,$prob_id);
  }
}


####
#
#  This takes the problems in the array ref $problems and updates the global problems for course $setID
#
###

sub updateProblems {
  my ($db,$setID,$problems) = @_;
  for my $prob_to_update (@$problems){
    my $prob = $db->getGlobalProblem($setID,$prob_to_update->{problem_id});
    for my $attr (@problem_props){
      $prob->{$attr} = $prob_to_update->{$attr} if $prob_to_update->{$attr};
    }
    $db->putGlobalProblem($prob);
  }
}

###
#
#  This creates and initialized a new user problem for user userID and set setID
#
###

sub createNewUserProblem {
  my ($db,$userID,$setID,$problemID) = @_;

  my $userProblem = $db->newUserProblem();
  $userProblem->{user_id}=$userID;
  $userProblem->{set_id}=$setID;
  $userProblem->{problem_id}=$problemID;
  $userProblem->{problem_seed} = int rand 5000;
  $userProblem->{status}=0.0;
  $userProblem->{attempted}=0;
  $userProblem->{num_correct}=0;
  $userProblem->{num_incorrect}=0;
  $userProblem->{sub_status}=0.0;

  return $userProblem;
}


###
#
# This adds global problems.  The variable $problems is a reference to an array of problems and
# the subroutine checks if any of the given problems are not in the database
#
##

sub addGlobalProblems {
  my ($db,$setID,$problems)=@_;

  my @oldProblems = $db->getAllGlobalProblems($setID);
  for my $p (@{$problems}){
    unless($db->existsGlobalProblem($setID,$p->{problem_id})){
      my $prob = $db->newGlobalProblem();
      for my $key (@problem_props){
        $prob->{$key} = $p->{$key};
      }
      $prob->{set_id} = $setID;
      $prob->{_id} = $prob->{set_id} . ":" . $prob->{problem_id};  # this helps backbone on the client side
      $db->addGlobalProblem($prob) unless $db->existsGlobalProblem($setID,$prob->{problem_id});
    }
  }

  return $db->getAllGlobalProblems($setID);
}

####
#
#  This subroutine adds the User Problems to the database
#
#  parameters:
#       $SetID: name of the set
#       $problems: reference to an array of problems (global)
#       $users: reference to an array of user IDs
#
#####

sub addUserProblems {
  my ($db,$setID, $problems,$users) = @_;

  for my $p (@{$problems}){
    for my $userID (@{$users}){
      $db->addUserProblem(createNewUserProblem($db,$userID,$setID,$p->{problem_id}))
      unless $db->existsUserProblem($userID,$setID,$p->{problem_id});
    }
  }
}


###
#
#  this adds a user Set
#
###

sub addUserSet {
  my ($db,$user_id,$set_id) = @_;

  my $userSet = $db->newUserSet;
  $userSet->set_id($set_id);
  $userSet->user_id($user_id);

  $db->addUserSet($userSet);

  ## create the user problems now
  my @users = ("$user_id");
  my @globalProblems = $db->getAllGlobalProblems($set_id);
  addUserProblems($db,$set_id,\@globalProblems,\@users);

}



## the following is mostly copied from webwork2/lib/ContentGenerator/Utils/ProblemUtils.pm

# process_and_log_answer subroutine.

# performs functions of processing and recording the answer given in the page. Also returns the appropriate scoreRecordedMessage.

sub record_results {

  my ($renderParams,$results) = @_;

  my $scoreRecordedMessage = "";
  my $pureProblem  = $db->getUserProblem($renderParams->{problem}->user_id, $renderParams->{problem}->set_id,
  $renderParams->{problem}->problem_id); # checked
  my $isEssay = 0;

  # logging student answers

  my $answer_log = vars->{ce}->{courseFiles}->{logs}->{'answer_log'};
  if ( defined($answer_log ) and defined($pureProblem)) {
    # if ($submitAnswers && !$authz->hasPermissions($effectiveUser, "dont_log_past_answers")) {
    my $answerString = "";
    my $scores = "";
    my %answerHash = %{ $results->{answers} };
    # FIXME  this is the line 552 error.  make sure original student ans is defined.
    # The fact that it is not defined is probably due to an error in some answer evaluator.
    # But I think it is useful to suppress this error message in the log.
    foreach (sort (keys %answerHash)) {
      my $orig_ans = $answerHash{$_}->{original_student_ans};
      my $student_ans = defined $orig_ans ? $orig_ans : '';
      $answerString  .= $student_ans."\t";
      # answer score *could* actually be a float, and this doesnt
      # allow for fractional answers :(
      $scores .= $answerHash{$_}->{score} >= 1 ? "1" : "0";
      $isEssay = 1 if ($answerHash{$_}->{type}//'') eq 'essay';

    }

    $answerString = '' unless defined($answerString); # insure string is defined.

    my $timestamp = time();
    writeCourseLog(vars->{ce}, "answer_log",
    join("",
    '|', $renderParams->{problem}->{user_id},
    '|', $renderParams->{problem}->{set_id},
    '|', $renderParams->{problem}->{problem_id},
    '|', $scores, "\t",
    $timestamp,"\t",
    $answerString,
    ),
    );

    #add to PastAnswer db
    my $pastAnswer = $db->newPastAnswer();
    $pastAnswer->course_id(session->{course});
    $pastAnswer->user_id($renderParams->{problem}->{user_id});
    $pastAnswer->set_id($renderParams->{problem}->{set_id});
    $pastAnswer->problem_id($renderParams->{problem}->{problem_id});
    $pastAnswer->timestamp($timestamp);
    $pastAnswer->scores($scores);
    $pastAnswer->answer_string($answerString);
    $pastAnswer->source_file($renderParams->{problem}->{source_file});

    $db->addPastAnswer($pastAnswer);


    #}
  }


  # get a "pure" (unmerged) UserProblem to modify
  # this will be undefined if the problem has not been assigned to this user

  if (defined $pureProblem) {
    # store answers in DB for sticky answers
    my %answersToStore;
    my %answerHash = %{ $results->{answers} };
    $answersToStore{$_} = $renderParams->{formFields}->{$_}  #$answerHash{$_}->{original_student_ans} -- this may have been modified for fields with multiple values.  Don't use it!!
    foreach (keys %answerHash);

    # There may be some more answers to store -- one which are auxiliary entries to a primary answer.  Evaluating
    # matrices works in this way, only the first answer triggers an answer evaluator, the rest are just inputs
    # however we need to store them.  Fortunately they are still in the input form.
    my @extra_answer_names  = @{ $results->{flags}->{KEPT_EXTRA_ANSWERS}};
    $answersToStore{$_} = $renderParams->{formFields}->{$_} foreach  (@extra_answer_names);

    # Now let's encode these answers to store them -- append the extra answers to the end of answer entry order
    my @answer_order = (@{$results->{flags}->{ANSWER_ENTRY_ORDER}}, @extra_answer_names);
    my $answerString = encodeAnswers(%answersToStore,
    @answer_order);

    # store last answer to database
    $renderParams->{problem}->last_answer($answerString);
    $pureProblem->last_answer($answerString);
    $db->putUserProblem($pureProblem);


    # store state in DB if it makes sense
    if(1) { # if ($will{recordAnswers}) {
      $renderParams->{problem}->status($results->{problem_state}->{recorded_score});
      $renderParams->{problem}->sub_status($results->{problem_state}->{sub_recorded_score});
      $renderParams->{problem}->attempted(1);
      $renderParams->{problem}->num_correct($results->{problem_state}->{num_of_correct_ans});
      $renderParams->{problem}->num_incorrect($results->{problem_state}->{num_of_incorrect_ans});
      $pureProblem->status($results->{problem_state}->{recorded_score});
      $pureProblem->sub_status($results->{problem_state}->{sub_recorded_score});
      $pureProblem->attempted(1);
      $pureProblem->num_correct($results->{problem_state}->{num_of_correct_ans});
      $pureProblem->num_incorrect($results->{problem_state}->{num_of_incorrect_ans});

      #add flags for an essay question.  If its an essay question and
      # we are submitting then there could be potential changes, and it should
      # be flaged as needing grading

      if ($isEssay && $pureProblem->{flags} !~ /needs_grading/) {
        $pureProblem->{flags} =~ s/graded,//;
        $pureProblem->{flags} .= "needs_grading,";
      }

      if ($db->putUserProblem($pureProblem)) {
        $scoreRecordedMessage = "Your score was recorded.";
      } else {
        $scoreRecordedMessage = "Your score was not recorded because there was a failure in storing the problem record to the database.";
      }
      # write to the transaction log, just to make sure
      writeLog(vars->{ce}, "transaction",
      $renderParams->{problem}->problem_id."\t".
      $renderParams->{problem}->set_id."\t".
      $renderParams->{problem}->user_id."\t".
      $renderParams->{problem}->source_file."\t".
      $renderParams->{problem}->value."\t".
      $renderParams->{problem}->max_attempts."\t".
      $renderParams->{problem}->problem_seed."\t".
      $pureProblem->status."\t".
      $pureProblem->attempted."\t".
      $pureProblem->last_answer."\t".
      $pureProblem->num_correct."\t".
      $pureProblem->num_incorrect
      );

    } else {
      if (before($renderParams->{set}->{open_date}) or after($renderParams->{set}->{due_date})) {
        $scoreRecordedMessage = "Your score was not recorded because this homework set is closed.";
      } else {
        $scoreRecordedMessage = "Your score was not recorded.";
      }
    }
  } else {
    $scoreRecordedMessage ="Your score was not recorded because this problem has not been assigned to you.";
  }



  vars->{scoreRecordedMessage} = $scoreRecordedMessage;
  return $scoreRecordedMessage;
}




1;
