## This is a number of common subroutines needed when processing the routes.  


package Utils::ProblemSets;
use base qw(Exporter);
use Dancer ':syntax';
use Data::Dump qw/dump/;
use List::Util qw(first);
use List::MoreUtils qw/indexes/;
use Data::Compare; 
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;
use WeBWorK::Utils qw/writeCourseLog encodeAnswers writeLog/;
use Utils::Convert qw/convertObjectToHash/;
use Array::Utils qw(array_minus);

our @EXPORT    = ();
our @EXPORT_OK = qw(reorderProblems addGlobalProblems deleteProblems addUserProblems addUserSet 
        createNewUserProblem getGlobalSet record_results renumber_problems updateProblems);
        
## This should only be in one spot.        
our @boolean_set_props = qw/visible enable_reduced_scoring hide_hint time_limit_cap problem_randorder/;
our @problem_props = qw/set_id problem_id source_file value max_attempts showMeAnother showMeAnotherCount flags/;
our @user_problem_props = qw/user_id set_id problem_id source_file value max_attempts showMeAnother 
                showMeAnotherCount flags problem_seed status attempted last_answer num_correct num_incorrect 
                sub_status flags/;

sub getGlobalSet {
    my ($setName) = @_;
    my $set = vars->{db}->getGlobalSet($setName);
    my $problemSet = convertObjectToHash($set,\@boolean_set_props);
    my @users = vars->{db}->listSetUsers($setName);
    my @problems = vars->{db}->getAllGlobalProblems($setName);
    for my $problem (@problems){
        $problem->{_id} = $problem->{set_id} . ":" . $problem->{problem_id};  # this helps backbone on the client side
    }

    $problemSet->{assigned_users} = \@users;
    $problemSet->{problems} = convertArrayOfObjectsToHash(\@problems);
    $problemSet->{_id} = $setName; # this is needed so that backbone works with the server. 

    return $problemSet;
}

###
#
# This reorders the problems

sub reorderProblems {
    my ($db,$setID,$new_problems,$assigned_users) = @_; 
    
    my @extra_fields = ("problem_id","set_id","user_id");
    
	my @problems_from_db = $db->getAllGlobalProblems($setID);
    
    
    my $user_prob_db = {};   # this is the user information from the database
            
    for my $user_id (@$assigned_users){
        $user_prob_db->{$user_id} = [$db->getAllUserProblems($user_id,$setID)];
    }
    
    my $id_swap = {};  # this builds a hash of how the problems have switched around.  
            

    for my $i (0..(scalar(@problems_from_db)-1)){
        if (! problemEqual($problems_from_db[$i],$new_problems->[$i])){
        
            ## this is the in $new_problems that matches the current problem ($problems_from_db[$i] )
            my $problem = first { $_->{problem_id} == $problems_from_db[$i]->{problem_id} } @$new_problems;
            
            ## gets the indexes of the problems in $new_problems identical to the current problem
            my @indexes = indexes { Compare(convertObjectToHash($problems_from_db[$i]),$_,
                    {ignore_hash_keys => [qw(problem_id _id data problem_seed)]}) == 1 }
                @$new_problems;   
            ## these are the problem_ids in $new_problems from the @indexes
            my @prob_ids = map { $new_problems->[$_]->{problem_id}} @indexes;
            
            my @values = values($id_swap);
            
            ## this finds the index if there are multiple problems that matched
            ## which occurs with the same problem source.  
            my @ind = array_minus(@prob_ids,@values);
            
            my $other = first { $_->{problem_id} == $ind[0] } @$new_problems; 
            
            $id_swap->{$problem->{problem_id}} = $other->{problem_id};
            $db->deleteGlobalProblem($setID,$problems_from_db[$i]->{problem_id});
            my $new_problem = vars->{db}->newGlobalProblem();
            $new_problem->{set_id}=$setID;
            for my $prop (@problem_props){
                $new_problem->{$prop} = $problem->{$prop};
            }
            $db->addGlobalProblem($new_problem);
        } else {
            $id_swap->{$problems_from_db[$i]->{problem_id}} = $problems_from_db[$i]->{problem_id};
        }
    }

    # Next, rebuild the user_problems. 
    
    for my $user_id (@$assigned_users){
        for my $prob_id (keys($id_swap)) {
        
            my $userprob = first {$_->{problem_id} == $prob_id } @{$user_prob_db->{$user_id}};
            my $newUserProblem = createNewUserProblem($user_id,$setID,$id_swap->{$prob_id});
            for my $prop (array_minus(@user_problem_props, @extra_fields)) {
                $newUserProblem->{$prop} = $userprob->{$prop};
            }
            $db->addUserProblem($newUserProblem) unless $db->existsUserProblem($user_id,$setID,$id_swap->{$prob_id});
        }
    }
    
    return $db->getAllGlobalProblems($setID);

}

###
#
#  tests for two problems being equal
#
###

sub problemEqual {
    my ($prob1,$prob2) = @_;
    for my $prop (@problem_props){
        if(defined($prob1->{$prop}) && defined($prob2->{$prop}) &&  $prob1->{$prop} ne $prob2->{$prop}){
             return "";
         }
    }
    
    return 1;


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
    my ($userID,$setID,$problemID) = @_;

    my $userProblem = vars->{db}->newUserProblem();
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
	my ($setID,$problems)=@_;

    debug "in addGlobalProblems";

	my @oldProblems = vars->{db}->getAllGlobalProblems($setID);
	for my $p (@{$problems}){
        if(! vars->{db}->existsGlobalProblem($setID,$p->{problem_id})){
            debug "making a new problem with id: " . $p->{problem_id};
        	my $prob = vars->{db}->newGlobalProblem();
            
        	$prob->{problem_id} = $p->{problem_id};
        	$prob->{source_file} = $p->{source_file};
            $prob->{value} = $p->{value};
            $prob->{max_attempts} = $p->{max_attempts};
        	$prob->{set_id} = $setID;
            $prob->{_id} = $prob->{set_id} . ":" . $prob->{problem_id};  # this helps backbone on the client side 
            vars->{db}->addGlobalProblem($prob) unless vars->{db}->existsGlobalProblem($setID,$prob->{problem_id});
        }
    }
    

    return vars->{db}->getAllGlobalProblems($setID);
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
    my ($setID, $problems,$users) = @_;

    for my $p (@{$problems}){
        for my $userID (@{$users}){
            vars->{db}->addUserProblem(createNewUserProblem($userID,$setID,$p->{problem_id}))
                unless vars->{db}->existsUserProblem($userID,$setID,$p->{problem_id});
        }
    }
}


###
#
# This deletes a problem.  The variable $problems is a reference to an array of problems and 
# the subroutine checks if any of the given problems are not in the database
#
#  Note:  the calls to $db->deleteGlobalProblem also deletes any user problem associated with it. 
#
##

sub deleteProblems {
	my ($db,$setID,$problems)=@_;

	my @old_ids = map { $_->{problem_id} } $db->getAllGlobalProblems($setID);
    my @new_ids = map { $_->{problem_id} } @$problems;
    my @ids_to_delete = array_minus(@old_ids,@new_ids);
    
    for my $id (@ids_to_delete){
        $db->deleteGlobalProblem($setID,$id);
    }

    return $db->getAllGlobalProblems($setID);
}


###
#
#  this adds a user Set
#
###

sub addUserSet {
    my ($user_id,$set_id) = @_;
	my $userSet = vars->{db}->newUserSet;
    $userSet->set_id($set_id);
    $userSet->user_id($user_id);
    my $result =  vars->{db}->addUserSet($userSet);

    return $result;
}



## the following is mostly copied from webwork2/lib/ContentGenerator/Utils/ProblemUtils.pm

# process_and_log_answer subroutine.

# performs functions of processing and recording the answer given in the page. Also returns the appropriate scoreRecordedMessage.

sub record_results {

    my ($renderParams,$results) = @_;

    my $scoreRecordedMessage = "";
    my $pureProblem  = vars->{db}->getUserProblem($renderParams->{problem}->user_id, $renderParams->{problem}->set_id,
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
            my $pastAnswer = vars->{db}->newPastAnswer();
            $pastAnswer->course_id(session->{course});
            $pastAnswer->user_id($renderParams->{problem}->{user_id});
            $pastAnswer->set_id($renderParams->{problem}->{set_id});
            $pastAnswer->problem_id($renderParams->{problem}->{problem_id});
            $pastAnswer->timestamp($timestamp);
            $pastAnswer->scores($scores);
            $pastAnswer->answer_string($answerString);
            $pastAnswer->source_file($renderParams->{problem}->{source_file});

            vars->{db}->addPastAnswer($pastAnswer);

            
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
        vars->{db}->putUserProblem($pureProblem);
        

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

            if (vars->{db}->putUserProblem($pureProblem)) {
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

###
#
# The following renumbers problems.  If they come in as 2,4,9,11,13 they leave as 1,2,3,4,5
#
#  pstaab: It appears that there is a lot of overlap between this and reorder_problems at the top 
#  of this file.  They should be combined or clarified how. 
###

sub renumber_problems {
    my ($db,$setID,$assigned_users) = @_;
    my %newProblemNumbers = ();
	my $maxProblemNumber = -1;
    my $force = 1;
    my $val;
    my @sortme;
    my $j =1;
    
    debug "in renumber_problems";
	for my $jj (sort { $a <=> $b } $db->listGlobalProblems($setID)) {
		$newProblemNumbers{$j} = $jj;
		$maxProblemNumber = $jj if $jj > $maxProblemNumber;
        $j++;
	}
    
    
    
    my @probs = $db->getAllGlobalProblems($setID);
    my @prob_ids = ();
    my %userprobs = ();
    $j=1;
    for my $prob (@probs) {
        push(@prob_ids, $prob->{problem_id});
        $prob->{problem_id} = $j++;
    }
    
    for my $user_id (@{$assigned_users}){
        $j=1;
        my $userproblems = [$db->getAllUserProblems($user_id,$setID)];
        for my $prob (@$userproblems) {
            $prob->{problem_id} = $j++;
        }
        $userprobs{$user_id} = $userproblems;
    }
    
    ## delete all old problems;
    
    for my $prob_id (@prob_ids){
        $db->deleteGlobalProblem($setID,$prob_id);
    }
    
    ## add in all of the global and user problems:
    for my $prob (@probs) {
        $db->addGlobalProblem($prob);
    }
    
    for my $user_id (@{$assigned_users}){
        for my $user_problem (@{$userprobs{$user_id}}){
            $db->addUserProblem($user_problem);   
        }
    }
    
    return;
}

1;