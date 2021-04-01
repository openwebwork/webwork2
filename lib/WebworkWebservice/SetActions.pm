#!/usr/local/bin/perl -w 

# Copyright (C) 2002 Michael Gage 

###############################################################################
# Web service which fetches, adds, removes and moves WeBWorK problems when working with a Set.
###############################################################################


#use lib '/home/gage/webwork/pg/lib';
#use lib '/home/gage/webwork/webwork-modperl/lib';

package WebworkWebservice::SetActions;
use WebworkWebservice;
use base qw(WebworkWebservice); 
use WeBWorK::Utils qw(readDirectory max sortByName formatDateTime jitar_id_to_seq seq_to_jitar_id);
use WeBWorK::Utils::Tasks qw(renderProblems);

use strict;
use sigtrap;
use Carp;
use WWSafe;
#use Apache;
use WeBWorK::Utils qw( encode_utf8_base64 decode_utf8_base64 );
use WeBWorK::Debug qw(debug);
use JSON;
use WeBWorK::CourseEnvironment;
use WeBWorK::PG::Translator;
use WeBWorK::DB::Utils qw(initializeUserProblem);
use WeBWorK::PG::IO;
use Benchmark;

##############################################
#   Some of this may have to be moved, to allow for flexability
#   Obtain basic information about directories, course name and host 
##############################################
our $WW_DIRECTORY = $WebworkWebservice::WW_DIRECTORY;
our $PG_DIRECTORY = $WebworkWebservice::PG_DIRECTORY;
our $COURSENAME   = $WebworkWebservice::COURSENAME;
our $HOST_NAME    = $WebworkWebservice::HOST_NAME;
our $PASSWORD     = $WebworkWebservice::PASSWORD;
our $ce           = WeBWorK::CourseEnvironment->new({webwork_dir=>$WW_DIRECTORY, courseName=> $COURSENAME});

our $UNIT_TESTS_ON =0;

sub listLocalSets{
  debug("in listLocalSets");
  my $self = shift;
  my $db = $self->db;
  my @found_sets;
  @found_sets = $db->listGlobalSets;
  my $out = {};
  $out->{ra_out} = \@found_sets;
  $out->{text} = encode_utf8_base64("Loaded sets for course: ".$self->{courseName});
  return $out;
}

###
#
#  This returns an array of problems (path,value,problem_id, which is weight)


sub listLocalSetProblems{
	my ($self, $params) = @_;

  	my $db = $self->db;
  	my @found_problems;

  	my $setName = $params->{set_id};

  	debug("Loading problems for " . $setName);

  	my $templateDir = $self->ce->{courseDirs}->{templates}."/";

        # If a command is passed, then we want relative paths rather than
        # absolute paths.  Do that by setting templateDir to the empty
        # string.

 	my $relativePaths = $params->{command};
 	$templateDir = '' if $relativePaths;

  	@found_problems = $db->listGlobalProblems($setName);

  	my @problems=();
  	for my $problem (@found_problems) {
		my $problemRecord = $db->getGlobalProblem($setName, $problem); # checked
		die "global $problem for set $setName not found." unless $problemRecord;
		my $problem = {};
		$problem->{path} = $templateDir.$problemRecord->source_file;
		$problem->{problem_id} = $problemRecord->{problem_id};
		$problem->{value} = $problemRecord->{value};
		push @problems, $problem;

	}
	
  	my $out = {};
  	$out->{ra_out} = \@problems;
  	$out->{text} = encode_utf8_base64("Loaded Problems for set: " . $setName);
  	return $out;
}

# This returns all problem sets of a course.

sub getSets{
  my ($self,$params) = @_;
  my $db = $self->db;
  my @found_sets = $db->listGlobalSets;
  
  my @all_sets = $db->getGlobalSets(@found_sets);
  
  # fix the timeDate  
 foreach my $set (@all_sets){
	#$set->{due_date} = formatDateTime($set->{due_date},'local');
	#$set->{open_date} = formatDateTime($set->{open_date},'local');
	#$set->{answer_date} = formatDateTime($set->{answer_date},'local');

	my @users = $db->listSetUsers($set->{set_id});
	$set->{assigned_users} = \@users;
  }
  
  my $out = {};
  $out->{ra_out} = \@all_sets;
  $out->{text} = encode_utf8_base64("Sets for course: ".$self->{courseName});
  return $out;
}

# This returns all problem sets of a course for a given user.
# the set is stored in the set_id and the user in user_id


sub getUserSets{
  my ($self,$params) = @_;
  my $db = $self->db;
  
  my @userSetNames = $db->listUserSets($params->{user});
  debug(@userSetNames);
  my @userSets = $db->getGlobalSets(@userSetNames);
  
  # fix the timeDate  
 # foreach my $set (@userSets){
	# $set->{due_date} = formatDateTime($set->{due_date},'local');
	# $set->{open_date} = formatDateTime($set->{open_date},'local');
	# $set->{answer_date} = formatDateTime($set->{answer_date},'local');
 #  }
  
  
  
  my $out = {};
  $out->{ra_out} = \@userSets;
  $out->{text} = encode_utf8_base64("Sets for course: ".$self->{courseName});
  return $out;
}



# This returns a single problem set with name stored in set_id

sub getSet {
  my ($self, $params) = @_;
  my $db = $self->db;
  my $setName = $params->{set_id};
  my $set = $db->getGlobalSet($setName);
  
  # change the date/times to user readable strings.  
  
  $set->{due_date} = formatDateTime($set->{due_date},'local');
  $set->{open_date} = formatDateTime($set->{open_date},'local');
  $set->{answer_date} = formatDateTime($set->{answer_date},'local');
  
  my $out = {};
  $out->{ra_out} = $set;
  $out->{text} = encode_utf8_base64("Sets for course: ".$self->{courseName});
  return $out;
  }

sub updateSetProperties {
	my ($self, $params) = @_;
	my $db = $self->db;

	my $set = $db->getGlobalSet($params->{set_id});
	$set->set_header($params->{set_header});
	$set->hardcopy_header($params->{hardcopy_header});
	$set->open_date($params->{open_date});
	$set->due_date($params->{due_date});
	$set->answer_date($params->{answer_date});
	$set->visible($params->{visible});
	$set->enable_reduced_scoring($params->{enable_reduced_scoring});
	$set->assignment_type($params->{assignment_type});
	$set->attempts_per_version($params->{attempts_per_version});
	$set->time_interval($params->{time_interval});
	$set->versions_per_interval($params->{versions_per_interval});
	$set->version_time_limit($params->{version_time_limit});
	$set->version_creation_time($params->{version_creation_time});
	$set->problem_randorder($params->{problem_randorder});
	$set->version_last_attempt_time($params->{version_last_attempt_time});
	$set->problems_per_page($params->{problems_per_page});
	$set->hide_score($params->{hide_score});
	$set->hide_score_by_problem($params->{hide_score_by_problem});
	$set->hide_work($params->{hide_work});
	$set->time_limit_cap($params->{time_limit_cap});
	$set->restrict_ip($params->{restrict_ip});
	$set->relax_restrict_ip($params->{relax_restrict_ip});
	$set->restricted_login_proctor($params->{restricted_login_proctor});

	$db->putGlobalSet($set);

	# Next update the assigned_users list

	# first, get the current list of users. 

	my @usersForTheSetBefore = $db->listSetUsers($params->{set_id});

	debug(to_json(\@usersForTheSetBefore));

	# then determine those currently in the list.

	my @usersForTheSetNow = split(/,/,$params->{assigned_users});


	# The following seems to work if there are only additions or subtractions from the assigned_users field.
	# Perhaps a better way to do this is to check users that are new or missing and add or delete them. 

	# if the number of users have grown, then add them.  

	debug(to_json(\@usersForTheSetNow));

	# determine users to be added

	foreach my $user (@usersForTheSetNow) {
		if (! grep( /^$user$/, @usersForTheSetBefore)) {
			my $userSet = $db->newUserSet;
			$userSet->user_id($user);
			$userSet->set_id($params->{set_id});
			$db->addUserSet($userSet);
		}
	}

	# delete users that are in the set before but not now. 

	foreach my $user (@usersForTheSetBefore){
		if (! grep(/^$user$/,@usersForTheSetNow)){
			$db->deleteUserSet($user, $params->{set_id});
		}
	}
 

	my $out = {};
	$out->{ra_out} = $set;
	$out->{text} = encode_utf8_base64("Successfully updated set " . $params->{set_id});
	return $out;
}

sub listSetUsers {
	my ($self,$params) = @_;
	my $db = $self->db;
    
    my $out = {};
    my @users = $db->listSetUsers($params->{set_id});
    $out->{ra_out} = \@users;
    $out->{text} = encode_utf8_base64("Successfully returned the users for set " . $params->{set_id});
    return $out;

}

sub createNewSet{
	my ($self,$params) = @_;
  	my $db = $self->db;
  	my $out;

  	debug("in createNewSet");
  	#debug(to_json($params));


	if ($params->{new_set_name} !~ /^[\w .-]*$/) {
		$out->{text} = "need a different name";#not sure the best way to handle and error
	} else {
		my $newSetName = $params->{set_id};
		# if we want to munge the input set name, do it here
		$newSetName =~ s/\s/_/g;


		my $newSetRecord = $db->getGlobalSet($newSetName);
		if (defined($newSetRecord)) {
            $out->{out}=encode_utf8_base64("Failed to create set, you may need to try another name."),
            $out->{ra_out} = {'success' => 'false'};
		} else {			# Do it!
			# DBFIXME use $db->newGlobalSet
			# $newSetRecord = $db->{set}->{record}->new();

			$newSetRecord = $db->newGlobalSet;
			$newSetRecord->set_id($newSetName);
			$newSetRecord->set_header("defaultHeader");
			$newSetRecord->hardcopy_header("defaultHeader");
			$newSetRecord->open_date($params->{open_date});
			$newSetRecord->due_date($params->{due_date});
			$newSetRecord->answer_date($params->{answer_date});
			$newSetRecord->reduced_scoring_date($params->{reduced_scoring_date});
			$newSetRecord->visible($params->{visible});
			$newSetRecord->enable_reduced_scoring($params->{enable_reduced_scoring});
			$newSetRecord->assignment_type($params->{assignment_type});
			$newSetRecord->description($params->{description});
			$newSetRecord->restricted_release($params->{restricted_release});
			$newSetRecord->restricted_status($params->{restricted_status});
			$newSetRecord->attempts_per_version($params->{attempts_per_version});
			$newSetRecord->time_interval($params->{time_interval});
			$newSetRecord->versions_per_interval($params->{versions_per_interval});
			$newSetRecord->version_time_limit($params->{version_time_limit});
			$newSetRecord->version_creation_time($params->{version_creation_time});
			$newSetRecord->problem_randorder($params->{problem_randorder});
			$newSetRecord->version_last_attempt_time($params->{version_last_attempt_time});
			$newSetRecord->problems_per_page($params->{problems_per_page});
			$newSetRecord->hide_score($params->{hide_score});
			$newSetRecord->hide_score_by_problem($params->{hide_score_by_problem});
			$newSetRecord->hide_work($params->{hide_work});
			$newSetRecord->time_limit_cap($params->{time_limit_cap});
			$newSetRecord->restrict_ip($params->{restrict_ip});
			$newSetRecord->relax_restrict_ip($params->{relax_restrict_ip});
			$newSetRecord->hide_hint($params->{hide_hint});
			$newSetRecord->restrict_prob_progression($params->{restrict_prob_progression});
			$newSetRecord->email_instructor($params->{email_instructor});
			
			$db->addGlobalSet($newSetRecord);
			if ($@) {
				$out->{text} = encode_utf8_base64("Failed to create set, you may need to try another name.");
				#$self->addbadmessage("Problem creating set $newSetName<br> $@");
			} else {
				my $selfassign = $params->{selfassign};
				debug("selfassign: " . $selfassign);
				$selfassign = "" if($selfassign =~ /false/i); # deal with javascript false
				if($selfassign) {
					debug("Assigning to user: " . $params->{user});
					my $userSet = $db->newUserSet;
					$userSet->user_id($params->{user});
					$userSet->set_id($newSetName);
					$db->addUserSet($userSet);
				}
			}
		}
	}
}

sub assignSetToUsers {
	my ($self,$params) = @_;
	my $db = $self->db;
    
    my $setID = $params->{set_id};
    my $GlobalSet = $db->getGlobalSet($params->{set_id});

    debug("users: " . $params->{users});
    my @users = split(',',$params->{users});
    #my @users = decode_json($params->{users});

    my @results; 
    foreach my $userID (@users) {
		my $UserSet = $db->newUserSet;
		$UserSet->user_id($userID);
		$UserSet->set_id($setID);
		
		
		
		my $set_assigned = 0;
		
		eval { $db->addUserSet($UserSet) };
		if ($@) {
			if ($@ =~ m/user set exists/) {
				push @results, "set $setID is already assigned to user $userID.";
				$set_assigned = 1;
			} else {
				die $@;
			}
		}
		
		my @GlobalProblems = grep { defined $_ } $db->getAllGlobalProblems($setID);
		foreach my $GlobalProblem (@GlobalProblems) {
			my @result = assignProblemToUser($self,$userID, $GlobalProblem);
			push @results, @result if @result and not $set_assigned;
		}   		
    }

	my $out = {};
	$out->{ra_out} = \@results;
	$out->{text} = encode_utf8_base64("Successfully assigned users to set " . $params->{set_id});
	return $out;
}

#problem utils from Instructor.pm
sub assignProblemToUser {
	my ($self,$userID,$GlobalProblem,$seed) = @_;
	my $db = $self->db;
	
	my $UserProblem = $db->newUserProblem;
	$UserProblem->user_id($userID);
	$UserProblem->set_id($GlobalProblem->set_id);
	$UserProblem->problem_id($GlobalProblem->problem_id);
	initializeUserProblem($UserProblem, $seed);
	
	eval { $db->addUserProblem($UserProblem) };
	if ($@) {
		if ($@ =~ m/user problem exists/) {
			return "problem " . $GlobalProblem->problem_id
				. " in set " . $GlobalProblem->set_id
				. " is already assigned to user $userID.";
		} else {
			die $@;
		}
	}
	
	return ();
}


sub deleteProblemSet {
	my ($self,$params) = @_;
	my $db = $self->db;
	my $setID = $params->{set_id};
	my $result = $db->deleteGlobalSet($setID);

		# check the result 
	debug("in deleteProblemSet");
	debug("deleted set:  $setID");
	debug($result);

	my $out->{text} = encode_utf8_base64("Deleted Problem Set " . $setID);



	return $out; 

}


sub reorderProblems {
	my ($self,$params) =  @_; 

	my $db = $self->db;
	my $setID = $params->{set_id};
	my @problemList = split(/,/, $params->{probList});
	my $topdir = $self->ce->{courseDirs}{templates};


	# get all the problems
	my @allProblems = $db->getAllGlobalProblems($setID);

	my @probOrder = ();

	foreach my $problem (@allProblems) {		
		my $recordFound = 0; 

		for (my $i = 0; $i < scalar(@problemList); $i++){
			$problemList[$i] =~ s|^$topdir/*||;

			if($problem->{source_file} eq $problemList[$i]){
				push(@probOrder,$i+1);
			   	if ($db->existsGlobalProblem($setID,$i+1)){
			   		$problem->problem_id($i+1);		   			
			   		$db->putGlobalProblem($problem);
			   		debug("updating problem " . $problemList[$i] . " and setting the index to " . ($i+1));

			   	} else {
			   		# delete the problem with the old problem_id and create a new one
			   		$db->deleteGlobalProblem($setID,$problem->{problem_id});
			   		$problem->problem_id($i+1);
			   		$db->addGlobalProblem($problem);

			   		debug("adding new problem " . $problemList[$i]. " and setting the index to " . ($i+1));
		   		}
		 	}
		 	$recordFound = 1; 
		}
		die "global " . $problem->{source_file} ." for set $setID not found." unless $recordFound;
		

	}

	my $out;

	$out->{text} = encode_utf8_base64("Successfully reordered problems");
	return $out;
}

sub updateProblem{
	my ($self,$params) = @_;
	my $db = $self->db;
	my $setID = $params->{set_id};
	my $path = $params->{path};
	my $topdir = $self->ce->{courseDirs}{templates};
	$path =~ s|^$topdir/*||;

	my @problems = $db->getAllGlobalProblems($setID);
	foreach my $problem (@problems){
		if($problem->{source_file} eq $path ){
			debug($params->{value});
			$problem->value($params->{value});
			$db->putGlobalProblem($problem);
		}
	}

		
	my $out->{text} = encode_utf8_base64("Updated Problem Set " . $setID);



	return $out; 

}


# This updates the userSet for a problem set (just the open, due and answer dates)


sub updateUserSet {
  	my ($self, $params) = @_;
  	my $db = $self->db;
  	my @users = split(',',$params->{users});

  	debug($params->{open_date});
  	debug($params->{due_date});
  	debug($params->{answer_date});
  	
  	foreach my $userID (@users) {
		my $set = $db->getUserSet($userID,$params->{set_id});
		if ($set){
		    $set->open_date($params->{open_date});
			$set->due_date($params->{due_date});
			$set->answer_date($params->{answer_date});
		  	$db->putUserSet($set);
		} else {
			my $newSet = $db->newUserSet;
			$newSet->user_id($userID);
			$newSet->set_id($params->{set_id});
		    $newSet->open_date($params->{open_date});
		    $newSet->due_date($params->{due_date});
		    $newSet->answer_date($params->{answer_date});
					
			$newSet = $db->addUserSet($newSet);
		} 
	}

  
  my $out = {};
  #$out->{ra_out} = $set;
  $out->{text} = encode_utf8_base64("Successfully updated set " . $params->{set_id} . " for users " . $params->{users});
  return $out;
}

=over

=item getUserSets($setID)

gets all user sets for set $setID

=cut

sub getUserSets {
	my ($self,$params) = @_;
	my $db = $self->db;

	my @setUserIDs = $db->listSetUsers($params->{set_id});

	my @userData = ();

	foreach my $user_id (@setUserIDs){
		push(@userData,$db->getUserSet($user_id,$params->{set_id}))
	}

	my $out = {};
	$out->{ra_out} = \@userData;
	$out->{text} = encode_utf8_base64("Returning all users sets for set " . $params->{set_id});

	return $out;
}


sub saveUserSets {
	my ($self,$params) = @_;
	my $db = $self->db;
	debug($params->{overrides});

	my @overrides = @{from_json($params->{overrides})};
	foreach my $override (@overrides){
		my $set = $db->getUserSet($override->{user_id},$params->{set_id});
		if ($override->{open_date}) {$set->{open_date} = $override->{open_date};}
		if ($override->{due_date}) {$set->{due_date} = $override->{due_date};}
		if ($override->{answer_date}) {$set->{answer_date} = $override->{answer_date};}
		$db->putUserSet($set);
	}

	my $out = {};
	$out->{ra_out} = "";
	$out->{text} = encode_utf8_base64("Updating the overrides for set " . $params->{set_id});

	return $out;
}

=item unassignSetFromUser($userID, $setID, $problemID)

Unassigns the given set and all problems therein from the given user.

=cut

sub unassignSetFromUsers {
  	my ($self, $params) = @_;
  	my $db = $self->db;
  	my @users = split(',',$params->{users});
    # should we check if the user is assigned before trying to unassign? 
  	foreach my $user (@users) {
		my $result = $db->deleteUserSet($user, $params->{set_id});
	}
	my $out = {};
	$out->{text} = encode_utf8_base64("Successfully unassigned users: " + $params->{users} + " from set " + $params->{set_id});
}

=item assignAllSetsToUser($userID)

Assigns all sets in the course and all problems contained therein to the
specified user. This is more efficient than repeatedly calling
assignSetToUser(). If any assignments fail, a list of failure messages is
returned.

=cut

sub assignAllSetsToUser {
	my ($self, $userID) = @_;
	my $db = $self->db;
	
	# assign only sets that are not already assigned
	#my %userSetIDs = map { $_ => 1 } $db->listUserSets($userID);
	#my @globalSetIDs = grep { not exists $userSetIDs{$_} } $db->listGlobalSets;
	#my @GlobalSets = $db->getGlobalSets(@globalSetIDs);
	# FIXME: i don't think we need to do the above, since asignSetToUser fails
	# silently if a UserSet already exists. instead we do this:
	# DBFIXME shouldn't need to get list of set IDs
	my @globalSetIDs = $db->listGlobalSets;
	my @GlobalSets = $db->getGlobalSets(@globalSetIDs);
	
	my @results;
	
	my $i = 0;
	foreach my $GlobalSet (@GlobalSets) {
		if (not defined $GlobalSet) {
			warn "record not found for global set $globalSetIDs[$i]";
		} else {
			my @result = $self->assignSetToUser($userID, $GlobalSet);
			push @results, @result if @result;
		}
		$i++;
	}
	
	return @results;
}


sub addProblem {
	my ($self,$params) = @_;
	my $db = $self->db;
	my $setName = $params->{set_id};

	my $file = $params->{path};
	my $topdir = $self->ce->{courseDirs}{templates};
	$file =~ s|^$topdir/*||;
	
	# DBFIXME count would work just as well
	my $freeProblemID;
	my $set = $db->getGlobalSet($setName);
	warn "record not found for global set $setName" unless $set;

	# for jitar sets the next problem id is the next top level problem
	if ($set->assignment_type eq 'jitar') {
	  my @problemIDs = $db->listGlobalProblems($setName);
	  my @seq = (0);
	  if ($#problemIDs != -1) {
	    @seq = jitar_id_to_seq($problemIDs[$#problemIDs]);
	  }
	    
	  $freeProblemID = seq_to_jitar_id($seq[0]+1);
	} else {
	    $freeProblemID = max($db->listGlobalProblems($setName)) + 1;
	}

	my $value_default = $self->ce->{problemDefaults}->{value};
	my $max_attempts_default = $self->ce->{problemDefaults}->{max_attempts};	
	my $showMeAnother_default = $self->ce->{problemDefaults}->{showMeAnother};	
	my $att_to_open_children_default = $self->ce->{problemDefaults}->{att_to_open_children};	
	my $counts_parent_grade_default = $self->ce->{problemDefaults}->{counts_parent_grade};	
    # showMeAnotherCount is the number of times that showMeAnother has been clicked; initially 0
	my $showMeAnotherCount = 0;	
	
	my $prPeriod_default = $self->ce->{problemDefaults}->{prPeriod};
	
	my $value = $value_default;
	if (defined($params->{value}) and length($params->{value})){$value = $params->{value};}  # 0 is a valid value for $params{value} but we don't want emptystring

	my $maxAttempts = $params->{maxAttempts} || $max_attempts_default;
	my $showMeAnother = $params->{showMeAnother} || $showMeAnother_default;
	my $problemID = $params->{problemID};
	my $countsParentGrade = $params->{counts_parent_grade} || $counts_parent_grade_default;
	my $attToOpenChildren = $params->{att_to_open_children} || $att_to_open_children_default;

	my $prPeriod = $prPeriod_default;
	if (defined($params->{prPeriod})){
		$prPeriod = $params->{prPeriod};
	}

	unless ($problemID) {
		$problemID = $freeProblemID;
	}

	my $problemRecord = $db->newGlobalProblem;
	$problemRecord->problem_id($problemID);
	$problemRecord->set_id($setName);
	$problemRecord->source_file($file);
	$problemRecord->value($value);
	$problemRecord->max_attempts($maxAttempts);
	$problemRecord->showMeAnother($showMeAnother);
	$problemRecord->{showMeAnotherCount}=$showMeAnotherCount;
	$problemRecord->{att_to_open_children} = $attToOpenChildren;
	$problemRecord->{counts_parent_grade} = $countsParentGrade;
	$problemRecord->prPeriod($prPeriod);
	$problemRecord->prCount(0);
	$db->addGlobalProblem($problemRecord);

	my @results; 
	my @userIDs = $db->listSetUsers($setName);
	foreach my $userID (@userIDs) {
		my @result = assignProblemToUser($self, $userID, $problemRecord);
		push @results, @result if @result;
	}
	

	#assignProblemToAllSetUsers($self, $problemRecord);
	my $out->{text} = encode_utf8_base64("Problem added to ".$setName);
	return $out;
}

sub deleteProblem {
	my ($self,$params) = @_;
	
	my $db = $self->db;
	my $setName = $params->{set_id};
	
	my $file = $params->{path};
	my $topdir = $self->ce->{courseDirs}{templates};
	$file =~ s|^$topdir/*||;
	# DBFIXME count would work just as well
	foreach my $problem ($db->listGlobalProblems($setName)) {
		my $problemRecord = $db->getGlobalProblem($setName, $problem);
		
		if($problemRecord->source_file eq $file){
			#print "found it";
			$db->deleteGlobalProblem($setName, $problemRecord->problem_id);
		}
	}
	my $out->{text} = encode_utf8_base64("Problem removed from ".$setName);
	return $out;
}


## Search for set definition files
use File::Find;
sub get_set_defs {
	my $self = shift;
	my $topdir = $self->ce->{courseDirs}{templates};#shift #sort of hard coded for now;
	my @found_set_defs;
	# get_set_defs_wanted is a closure over @found_set_defs
	my $get_set_defs_wanted = sub {
		#my $fn = $_;
		#my $fdir = $File::Find::dir;
		#return() if($fn !~ /^set.*\.def$/);
		##return() if(not -T $fn);
		#push @found_set_defs, "$fdir/$fn";
		push @found_set_defs, $_ if m|/set[^/]*\.def$|;
	};
	find({ wanted => $get_set_defs_wanted, follow_fast=>1, no_chdir=>1}, $topdir);
	map { $_ =~ s|^$topdir/?|| } @found_set_defs;
	my $out = {};
	$out->{ra_out} = \@found_set_defs;
	return $out;
}

## Try to make reading of set defs more flexible.  Additional strategies
## for fixing a path can be added here.

sub munge_pg_file_path {
	my $self = shift;
	my $pg_path = shift;
	my $path_to_set_def = shift;
	my $end_path = $pg_path;
	# if the path is ok, don't fix it
	return($pg_path) if(-e $self->r->ce->{courseDirs}{templates}."/$pg_path");
	# if we have followed a link into a self contained course to get
	# to the set.def file, we need to insert the start of the path to
	# the set.def file
	$end_path = "$path_to_set_def/$pg_path";
	return($end_path) if(-e $self->r->ce->{courseDirs}{templates}."/$end_path");
	# if we got this far, this path is bad, but we let it produce
	# an error so the user knows there is a troublesome path in the
	# set.def file.
	return($pg_path);
}

## Read a set definition file.  This could be abstracted since it happens
## elsewhere.  Here we don't have to process so much of the file.

sub read_set_def {
	my $self = shift;
	my $r = $self->r;
	my $filePathOrig = shift;
	my $filePath = $r->ce->{courseDirs}{templates}."/$filePathOrig";
	$filePathOrig =~ s/set.*\.def$//;
	$filePathOrig =~ s|/$||;
	$filePathOrig = "." if ($filePathOrig !~ /\S/);
	my @pg_files = ();
	my ($line, $got_to_pgs, $name, @rest) = ("", 0, "");
	if ( open (SETFILENAME, "$filePath") )    {
		while($line = <SETFILENAME>) {
			chomp($line);
			$line =~ s|(#.*)||; # don't read past comments
			if($got_to_pgs) {
				unless ($line =~ /\S/) {next;} # skip blank lines
				($name,@rest) = split (/\s*,\s*/,$line);
				$name =~ s/\s*//g;
				push @pg_files, $name;
			} else {
				$got_to_pgs = 1 if ($line =~ /problemList\s*=/);
			}
		}
	} else {
		$self->addbadmessage("Cannot open $filePath");
	}
	# This is where we would potentially munge the pg file paths
	# One possibility
	@pg_files = map { $self->munge_pg_file_path($_, $filePathOrig) } @pg_files;
	return(@pg_files);
}

=back

=cut

1;
