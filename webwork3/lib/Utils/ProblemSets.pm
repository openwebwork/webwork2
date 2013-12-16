## This is a number of common subroutines needed when processing the routes.  


package Utils::ProblemSets;
use base qw(Exporter);
use Dancer ':syntax';
use Data::Dumper;
use List::Util qw(first);

our @EXPORT    = ();
our @EXPORT_OK = qw(reorderProblems addGlobalProblems deleteProblems addUserProblems addUserSet createNewUserProblem);

###
#
# This reorders the problems

sub reorderProblems {

	my @oldProblems = vars->{db}->getAllGlobalProblems(params->{set_id});

    for my $p (@{params->{problems}}){
        my $problem = first { $_->{source_file} eq $p->{source_file} } @oldProblems;

        if (vars->{db}->existsGlobalProblem(params->{set_id},$p->{problem_id})){
            $problem->problem_id($p->{problem_id});                 
            vars->{db}->putGlobalProblem($problem);
        } else {
            # delete the problem with the old problem_id and create a new one
            vars->{db}->deleteGlobalProblem(params->{set_id},$problem->{problem_id});
            $problem->problem_id($p->{problem_id});
            vars->{db}->addGlobalProblem($problem);

            for my $user (@{params->{assigned_users}}){
                my $userProblem = vars->{db}->newUserProblem;
                $userProblem->set_id(params->{set_id});
                $userProblem->user_id($user);
                $userProblem->problem_id($p->{problem_id});
                debug $userProblem;
                vars->{db}->addUserProblem($userProblem);
            }
        }
    }

    ## take care of the userProblems now




    return vars->{db}->getAllGlobalProblems(params->{set_id});
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
        my $problem = first { $_->{source_file} eq $p->{source_file} } @oldProblems;

        debug $problem;
        if(! vars->{db}->existsGlobalProblem($setID,$p->{problem_id})){
        	my $prob = vars->{db}->newGlobalProblem();
        	$prob->{problem_id} = $p->{problem_id};
        	$prob->{source_file} = $p->{source_file};
            $prob->{value} = $p->{value};
            $prob->{max_attempts} = $p->{max_attempts};
        	$prob->{set_id} = $setID;
        	vars->{db}->addGlobalProblem($prob) unless vars->{db}->existsGlobalProblem($setID,$prob->{problem_id})
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
##

###  @oldProblems  = [1,2,3,4,5];
### $problems = [1,2,4,5];

sub deleteProblems {
	my ($setID,$problems)=@_;

	my @oldProblems = vars->{db}->getAllGlobalProblems($setID);
	for my $p (@oldProblems){
        my $problem = first { $_->{problem_id} eq $p->{problem_id} } @{$problems};
        if(! defined($problem)){
        	vars->{db}->deleteGlobalProblem($setID,$p->{problem_id});
        }
    }

    return vars->{db}->getAllGlobalProblems($setID);
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


###
#
# this adds userProblems for a given user and an array of problems
#
###

sub addUserProblems {
	my ($userID) = @_;
	for my $p (@{params->{problems}}){
        debug $p;
		my $userProblem = vars->{db}->newUserProblem();
		$userProblem->user_id($userID);
		$userProblem->set_id(params->{set_id});
		$userProblem->problem_id($p->{problem_id});
		vars->{db}->addUserProblem($userProblem);
	}
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

            debug "here!";
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

