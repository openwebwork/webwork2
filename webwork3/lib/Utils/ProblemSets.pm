## This is a number of common subroutines needed when processing the routes.  


package Utils::ProblemSets;
use base qw(Exporter);
use Dancer ':syntax';
use Data::Dumper;
use List::Util qw(first);

our @EXPORT    = ();
our @EXPORT_OK = qw(reorderProblems addProblems deleteProblems addUserProblems addUserSet);

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
# This adds a problem.  The variable $problems is a reference to an array of problems and 
# the subroutine checks if any of the given problems are not in the database
#
##

sub addProblems {
	my ($db,$setID,$problems,$users)=@_;

	my @oldProblems = $db->getAllGlobalProblems($setID);
	for my $p (@{$problems}){
        my $problem = first { $_->{source_file} eq $p->{source_file} } @oldProblems;

        if(! $db->existsGlobalProblem($setID,$p->{problem_id})){
        	my $prob = $db->newGlobalProblem();
        	$prob->{problem_id} = $p->{problem_id};
        	$prob->{source_file} = $p->{source_file};
            $prob->{value} = $p->{value};
            $prob->{max_attempts} = $p->{max_attempts};
        	$prob->{set_id} = $setID;
        	$db->addGlobalProblem($prob);

        	for my $u (@{$users}){
        		my $userProblem = $db->newUserProblem();
				$userProblem->{user_id}=$u;
				$userProblem->{set_id}=$setID;
				$userProblem->{problem_id}=$p->{problem_id};
				$db->addUserProblem($userProblem);
        	}
        }
	}

    return $db->getAllGlobalProblems($setID);
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
	my ($db,$setID,$problems)=@_;

	my @oldProblems = $db->getAllGlobalProblems($setID);
	for my $p (@oldProblems){
        my $problem = first { $_->{problem_id} eq $p->{problem_id} } @{$problems};
        if(! defined($problem)){
        	$db->deleteGlobalProblem($setID,$p->{problem_id});
        }
    }

    return $db->getAllGlobalProblems($setID);
}


###
#
#  this adds a user Set
#
###

sub addUserSet {
    my ($user_id) = @_;
	my $userSet = vars->{db}->newUserSet;
    $userSet->set_id(params->{set_id});
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

