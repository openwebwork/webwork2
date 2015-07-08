## This is a number of common subroutines needed when processing the routes.  


package Utils::ProblemSets;
use base qw(Exporter);
use Dancer ':syntax';
use Data::Dump qw/dump/;
use List::Util qw(first);
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;
use WeBWorK::Utils qw/writeCourseLog encodeAnswers writeLog/;
use Array::Utils qw(array_minus);

our @EXPORT    = ();
our @EXPORT_OK = qw(reorderProblems addGlobalProblems deleteProblems addUserProblems addUserSet 
        createNewUserProblem getGlobalSet record_results renumber_problems);
        
## This should only be in one spot.        
our @boolean_set_props = qw/visible enable_reduced_scoring hide_hint time_limit_cap problem_randorder/;

our @problem_props = qw/set_id problem_id source_file value max_attempts showMeAnother showMeAnotherCount flags/;

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

    debug "in reorderProblems";
	my @problems_from_db = $db->getAllGlobalProblems($setID);
    
    my $user_prob_db = {};   # this is the user information from the database
            
    for my $user_id (@$assigned_users){
        $user_prob_db->{$user_id} = [$db->getAllUserProblems($user_id,$setID)];
    }
            

    for my $i (0..(scalar(@problems_from_db)-1)){
        debug problemEqual($problems_from_db[$i],$new_problems->[$i]);
        if (! problemEqual($problems_from_db[$i],$new_problems->[$i])){
        
            my $problem = first { $_->{problem_id} == $problems_from_db[$i]->{problem_id} } @{$new_problems};
            
            debug $problems_from_db[$i]->{problem_id};
            debug $problem->{problem_id};
        
            $db->deleteGlobalProblem($setID,$problems_from_db[$i]->{problem_id});
            my $new_problem = vars->{db}->newGlobalProblem();
            $new_problem->{set_id}=$setID;
            for my $prop (@problem_props){
                #debug "$prop: " . $problem->{$prop} if defined($problem->{$prop});
                $new_problem->{$prop} = $problem->{$prop};
            }
            $db->addGlobalProblem($new_problem);

            for my $user_id (@$assigned_users){
                my $userprob = first {$_->{problem_id} == $problems_from_db[$i]->{problem_id} } @{$user_prob_db->{$user_id}};
                $userprob->{problem_id} = $new_problem->{problem_id};
                $db->addUserProblem($userprob);
            }
        }
    }

    return $db->getAllGlobalProblems($setID);


#    for my $p (@{params->{problems}}){
#        my $problem = first { $_->{source_file} eq $p->{source_file} } @oldProblems;
#
#        if (vars->{db}->existsGlobalProblem(params->{set_id},$p->{problem_id})){
#            $problem->problem_id($p->{problem_id});                 
#            vars->{db}->putGlobalProblem($problem);
#        } else {
#            # delete the problem with the old problem_id and create a new one
#            vars->{db}->deleteGlobalProblem(params->{set_id},$problem->{problem_id});
#            my $problem = vars->{db}->newGlobalProblem();
#            $problem->{set_id}=$setID;
#            for $prop (@problem_props){
#                $problem->{$prop} = $new_problems[$i]->{$prop};
#            }
#            $db->addGlobalProblem($problem);
#
#
#            ## this may discard all of the other info about the user problem
#            for my $user_id (@$assigned_users){
#                $db->addUserProblem(createNewUserProblem($user_id,$setID,$problem->{problem_id}));
#            }
#        }
#    }
#
#    return $db->getAllGlobalProblems($setID);
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
# The following renumbers problems.  Taken from ProblemSetDetail.pm
#
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
    
    

    
    my $maxNum = $maxProblemNumber;
    # keys are current problem numbers, values are target problem numbers
    
	foreach $j (keys %newProblemNumbers) {
		# we don't want to act unless all problems have been assigned a new problem number, so if any have not, return
		return "" if (not defined $newProblemNumbers{"$j"});
		# if the problem has been given a new number, we reduce the "score" of the problem by the original number of the problem
		# when multiple problems are assigned the same number, this results in the last one ending up first -- FIXME?
		if ($newProblemNumbers{"$j"} != $j) {
			# force always gets set if reordering is done, so don't expect to be able to delete a problem,
			# reorder some other problems, and end up with a hole -- FIXME
			$force = 1;
			$val = 1000 * $newProblemNumbers{$j} - $j;
		} else {
			$val = 1000 * $newProblemNumbers{$j};
		}
		# store a mapping between current problem number and score (based on currnet and new problem number)
		push @sortme, [$j, $val];
		# replace new problem numbers in hash with the (global) problems themselves
		$newProblemNumbers{$j} = $db->getGlobalProblem($setID, $j);
		send_error("global $j for set $setID not found.",403) unless $newProblemNumbers{$j};
	}

	# we don't have to do anything if we're not getting rid of holes
	return "" unless $force;

	# sort the curr. prob. num./score pairs by score
	@sortme = sort {$a->[1] <=> $b->[1]} @sortme;
	# now, for global and each user with this set, loop through problem list
	#   get all of the problem records
	# assign new problem numbers
	# loop - if number is new, put the problem record
	# print "Sorted to get ". join(', ', map {$_->[0] } @sortme) ."<p>\n";

	# Now, three stages.  First global values
    
	for ($j = 0; $j < scalar @sortme; $j++) {
		if($sortme[$j][0] == $j + 1) {
			# if the jth problem (according to the new ordering) is in the right place (problem IDs are numbered from 1, hence $j+1)
			# do nothing
		} elsif (not defined $newProblemNumbers{$j + 1}) {
			# otherwise, if there's a hole for it, add it there
			$newProblemNumbers{$sortme[$j][0]}->problem_id($j + 1);
			$db->addGlobalProblem($newProblemNumbers{$sortme[$j][0]});
		} else {
			# otherwise, overwrite the data for the problem that's already there with the jth problem's data (with a changed problemID)
			$newProblemNumbers{$sortme[$j][0]}->problem_id($j + 1);
			$db->putGlobalProblem($newProblemNumbers{$sortme[$j][0]});
		}
	}

	my @setUsers = $db->listSetUsers($setID);
	my (@problist, $user);

	foreach $user (@setUsers) {
		# grab a copy of each UserProblem for this user. @problist can be sparse (if problems were deleted)
		for $j (keys %newProblemNumbers) {
			$problist[$j] = $db->getUserProblem($user, $setID, $j);
		}
        
		for($j = 0; $j < scalar @sortme; $j++) { 
			if ($sortme[$j][0] == $j + 1) {
				# same as above -- the jth problem is in the right place, so don't worry about it
				# do nothing
			} elsif ($problist[$sortme[$j][0]]) {
				# we've made sure the user's problem actually exists HERE, since we want to be able to fail gracefullly if it doesn't
				# the problem with the original conditional below is that %newProblemNumbers maps oldids => global problem record
				# we need to check if the target USER PROBLEM exists, which is what @problist knows
				#if (not defined $newProblemNumbers{$j + 1}) {
				if (not defined $problist[$j+1]) {
					# same as above -- there's a hole for that problem to go into, so add it in its new place
					$problist[$sortme[$j][0]]->problem_id($j + 1); 
					$db->addUserProblem($problist[$sortme[$j][0]]); 
				} else { 
					# same as above -- there's a problem already there, so overwrite its data with the data from the jth problem
					$problist[$sortme[$j][0]]->problem_id($j + 1); 
					$db->putUserProblem($problist[$sortme[$j][0]]); 
				} 
			} else {
				warn "UserProblem missing for user=$user set=$setID problem=" . $sortme[$j][0] . " This may indicate database corruption.";
				# when a problem doesn't exist in the target slot, a new problem gets added there, but the original problem
				# never gets overwritten (because there wan't a problem it would have to get exchanged with)
				# i think this can get pretty complex. consider 1=>2, 2=>3, 3=>4, 4=>1 where problem 1 doesn't exist for some user:
				# @sortme[$j][0] will contain: 4, 1, 2, 3
				# - problem 1 will get **added** with the data from problem 4 (because problem 1 doesn't exist for this user)
				# - problem 2 will get overwritten with the data from problem 1
				# - problem 3 will get overwritten with the data from problem 2
				# - nothing will happend to problem 4, since problem 1 doesn't exit
				# so the solution is to delete problem 4 altogether!
				# here's the fix:
				
				# the data from problem $j+1 was/will be moved to another problem slot,
				# but there's no problem $sortme[$j][0] to replace it. thus, we delete it now.
				$db->deleteUserProblem($user, $setID, $j+1);
			}
		} 
	}


	# any problems with IDs above $maxNum get deleted -- presumably their data has been copied into problems with lower IDs
	foreach ($j = scalar @sortme; $j < $maxNum; $j++) {
		if (defined $newProblemNumbers{$j + 1}) {
			$db->deleteGlobalProblem($setID, $j+1);
		}
	}
    
    @probs = map {$_->{problem_id} } $db->getAllGlobalProblems($setID);

}

1;