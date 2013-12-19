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
use WeBWorK::Utils qw(readDirectory max sortByName formatDateTime parseDateTime);
use WeBWorK::Utils::Tasks qw(renderProblems);

use strict;
use sigtrap;
use Carp;
use WWSafe;
#use Apache;
use WeBWorK::Utils;
use WeBWorK::Debug;
use JSON;
use WeBWorK::CourseEnvironment;
use WeBWorK::PG::Translator;
use WeBWorK::DB::Utils qw(initializeUserProblem);
use WeBWorK::PG::IO;
use Benchmark;
use MIME::Base64 qw( encode_base64 decode_base64);

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

our $UNIT_TESTS_ON =1;

sub listLocalSets{
  debug("in listLocalSets");
  my $self = shift;
  my $db = $self->{db};
  my @found_sets;
  @found_sets = $db->listGlobalSets;
  my $out = {};
  $out->{ra_out} = \@found_sets;
  $out->{text} = encode_base64("Loaded sets for course: ".$self->{courseName});
  return $out;
}

sub listLocalSetProblems{
	my ($self, $params) = @_;

  	my $db = $self->{db};
  	my @found_problems;

  	my $setName = $params->{set_id};

  	debug("Loading problems for " . $setName);

  	my $templateDir = $self->{ce}->{courseDirs}->{templates}."/";

        # If a command is passed, then we want relative paths rather than
        # absolute paths.  Do that by setting templateDir to the empty
        # string.

 	my $relativePaths = $params->{command};
 	$templateDir = '' if $relativePaths;

  	@found_problems = $db->listGlobalProblems($setName);

  	my @pg_files=();
  	for my $problem (@found_problems) {
		my $problemRecord = $db->getGlobalProblem($setName, $problem); # checked
		die "global $problem for set $setName not found." unless
		$problemRecord;
		push @pg_files, $templateDir.$problemRecord->source_file;

	}
	
  	my $out = {};
  	$out->{ra_out} = \@pg_files;
  	$out->{text} = encode_base64("Loaded Problems for set: " . $setName);
  	return $out;
}

# This returns all problem sets of a course.

sub getSets{
  my $self = shift;
  my $db = $self->{db};
  my @found_sets = $db->listGlobalSets;
  
  my @all_sets = $db->getGlobalSets(@found_sets);
  
  # fix the timeDate  
 foreach my $set (@all_sets){
	$set->{due_date} = formatDateTime($set->{due_date},'local');
	$set->{open_date} = formatDateTime($set->{open_date},'local');
	$set->{answer_date} = formatDateTime($set->{answer_date},'local');
  }
  
  
  my $out = {};
  $out->{ra_out} = \@all_sets;
  $out->{text} = encode_base64("Sets for course: ".$self->{courseName});
  return $out;
}

# This returns all problem sets of a course for a given user.
# the set is stored in the set_id and the user in user_id


sub getUserSets{
  my ($self,$params) = @_;
  my $db = $self->{db};
  
  my @userSetNames = $db->listUserSets($params->{user});
  debug(@userSetNames);
  my @userSets = $db->getGlobalSets(@userSetNames);
  
  # fix the timeDate  
 foreach my $set (@userSets){
	$set->{due_date} = formatDateTime($set->{due_date},'local');
	$set->{open_date} = formatDateTime($set->{open_date},'local');
	$set->{answer_date} = formatDateTime($set->{answer_date},'local');
  }
  
  
  
  my $out = {};
  $out->{ra_out} = \@userSets;
  $out->{text} = encode_base64("Sets for course: ".$self->{courseName});
  return $out;
}



# This returns a single problem set with name stored in set_id

sub getSet {
  my ($self, $params) = @_;
  my $db = $self->{db};
  my $setName = $params->{set_id};
  my $set = $db->getGlobalSet($setName);
  
  # change the date/times to user readable strings.  
  
  $set->{due_date} = formatDateTime($set->{due_date},'local');
  $set->{open_date} = formatDateTime($set->{open_date},'local');
  $set->{answer_date} = formatDateTime($set->{answer_date},'local');
  
  my $out = {};
  $out->{ra_out} = $set;
  $out->{text} = encode_base64("Sets for course: ".$self->{courseName});
  return $out;
  }

sub updateSetProperties {
  my ($self, $params) = @_;
  my $db = $self->{db};
    
  #note some of the parameters are coming in as yes or no and need to be converted to 1 or 0.  

  my $set = $db->getGlobalSet($params->{set_id});
  $set->set_header($params->{set_header});
  $set->hardcopy_header($params->{hardcopy_header});
  $set->open_date(parseDateTime($params->{open_date},"local"));
  $set->due_date(parseDateTime($params->{due_date},"local"));
  $set->answer_date(parseDateTime($params->{answer_date},"local"));
  $set->visible(($params->{visible} eq "yes")?1:0);
  $set->enable_reduced_scoring(($params->{enable_reduced_scoring} eq "yes")?1:0);
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
  
  my $out = {};
  $out->{ra_out} = $set;
  $out->{text} = encode_base64("Successfully updated set " . $params->{set_id});
  return $out;
}

sub listSetUsers {
	my ($self,$params) = @_;
	my $db = $self->{db};
    
    my $out = {};
    my @users = $db->listSetUsers($params->{set_id});
    $out->{ra_out} = \@users;
    $out->{text} = encode_base64("Successfully returned the users for set " . $params->{set_id});
    return $out;

}

sub createNewSet{
	my $self = shift;
	my $in = shift;
	my $db = $self->{db};
	my $out;


	if ($in->{new_set_name} !~ /^[\w .-]*$/) {
		$out->{text} = "need a different name";#not sure the best way to handle and error
	} else {
		my $newSetName = $in->{new_set_name};
		# if we want to munge the input set name, do it here
		$newSetName =~ s/\s/_/g;
		#debug("local_sets was ", $r->param('local_sets'));
		#$r->param('local_sets',$newSetName);  ## use of two parameter param
		#debug("new value of local_sets is ", $r->param('local_sets'));
		my $newSetRecord = $db->getGlobalSet($newSetName);
		if (defined($newSetRecord)) {
            $out->{out}=encode_base64("Failed to create set, you may need to try another name."),
            $out->{ra_out} = {'success' => 'false'};
		} else {			# Do it!
			# DBFIXME use $db->newGlobalSet
			$newSetRecord = $db->{set}->{record}->new();
			$newSetRecord->set_id($newSetName);
			$newSetRecord->set_header("defaultHeader");
			$newSetRecord->hardcopy_header("defaultHeader");
			$newSetRecord->open_date(time()+60*60*24*7); # in one week
			$newSetRecord->due_date(time()+60*60*24*7*2); # in two weeks
			$newSetRecord->answer_date(time()+60*60*24*7*3); # in three weeks
			eval {$db->addGlobalSet($newSetRecord)};
			if ($@) {
				$out->{text} = encode_base64("Failed to create set, you may need to try another name.");
				#$self->addbadmessage("Problem creating set $newSetName<br> $@");
			} else {
				my $selfassign = $in->{selfassign};
				debug($selfassign);
				$selfassign = "" if($selfassign =~ /false/i); # deal with javascript false
				if($selfassign) {
					debug("Assigning to user: " . $in->{user});
					my $userSet = $db->newUserSet;
					$userSet->user_id($in->{user});
					$userSet->set_id($newSetName);
					$db->addUserSet($userSet);
				}
			}
		}
	}
}

sub assignSetToUsers {
	my ($self,$params) = @_;
	my $db = $self->{db};
    
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
	$out->{text} = encode_base64("Successfully assigned users to set " . $params->{set_id});
	return $out;
}

#problem utils from Instructor.pm
sub assignProblemToUser {
	my ($self,$userID,$GlobalProblem,$seed) = @_;
	my $db = $self->{db};
	
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
	my $db = $self->{db};
	my $setID = $params->{set_id};
	my $result = $db->deleteGlobalSet($setID);

		# check the result 
	debug("in deleteProblemSet");
	debug("deleted set:  $setID");
	debug($result);

	my $out->{text} = encode_base64("Deleted Problem Set " . $setID);



	return $out; 

}


sub reorderProblems {
	my ($self,$params) =  @_; 

	my $db = $self->{db};
	my $setID = $params->{set_id};
	my @problemList = split(/,/, $params->{probList});
	my $topdir = $self->{ce}->{courseDirs}{templates};


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

	# Not sure if the userProblem also need to be reordered.  

	# set the userProblems as well

	# foreach my $user ($db->listSetUsers($setID)) {
	# 	@allUserProblems = $db->getAllUserProblems($user,$setID);

	# 	for (my $i = 0; $i < scalar(@allUserProblems); $i++){	
	# 		foreach my $path (@problemList) {
	# 			$path =~ s|^$topdir/*||;

	# 			if($allUserProblems[$i]->{source_file} eq $path){

	# 				if ($db->existsUserProblem($user,$setID,$i+1)){
	# 					my $prob = $db->getUserProblem($user, $setID, $i+1);
	# 		  	  		die " problem $index for set $setID and effective user $user not found"	unless $prob;
	# 					$prob->problem_id($i+1);
	# 				    $db->putUserProblem($prob);
	# 			    } else {
	# 			    	$db->deleteUserProblem($user,$setID,$problem->{problem_id});
	# 			    	$problem->problem_id($i+1);
	# 			    	$db->addUserProblem($problem);
	# 			    }
	# 			}
	# 		}
	# 	}
	# }
	my $out;

	$out->{text} = encode_base64("Successfully reordered problems");
	return $out;
}

sub updateProblem{
	my ($self,$params) = @_;
	my $db = $self->{db};
	my $setID = $params->{set_id};
	my $path = $params->{path};
	my $topdir = $self->{ce}->{courseDirs}{templates};
	$path =~ s|^$topdir/*||;

	my @problems = $db->getAllGlobalProblems($setID);
	foreach my $problem (@problems){
		if($problem->{source_file} eq $path ){
			debug($params->{value});
			$problem->value($params->{value});
			$db->putGlobalProblem($problem);
		}
	}

		
	my $out->{text} = encode_base64("Updated Problem Set " . $setID);



	return $out; 

}


# This updates the userSet for a problem set (just the open, due and answer dates)


sub updateUserSet {
  	my ($self, $params) = @_;
  	my $db = $self->{db};
  	my @users = split(',',$params->{users});
  	
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
  $out->{text} = encode_base64("Successfully updated set " . $params->{set_id} . " for users " . $params->{users});
  return $out;
}


=item unassignSetFromUser($userID, $setID, $problemID)

Unassigns the given set and all problems therein from the given user.

=cut

sub unassignSetFromUsers {
  	my ($self, $params) = @_;
  	my $db = $self->{db};
  	my @users = split(',',$params->{users});
    # should we check if the user is assigned before trying to unassign? 
  	foreach my $user (@users) {
		my $result = $db->deleteUserSet($user, $params->{set_id});
	}
	my $out = {};
	$out->{text} = encode_base64("Successfully unassigned users: " + $params->{users} + " from set " + $params->{set_id});
}

=item assignAllSetsToUser($userID)

Assigns all sets in the course and all problems contained therein to the
specified user. This is more efficient than repeatedly calling
assignSetToUser(). If any assignments fail, a list of failure messages is
returned.

=cut

sub assignAllSetsToUser {
	my ($self, $userID) = @_;
	my $db = $self->{db};
	
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

# sub assignProblemToAllSetUsers {
# 	my $self = shift;
# 	my $GlobalProblem = shift;
# 	my $db = $self->{db};
# 	my $setID = $GlobalProblem->set_id;
# 	my @userIDs = $db->listSetUsers($setID);
	
# 	my @results;
	
# 	foreach my $userID (@userIDs) {
# 		my @result = assignProblemToUser($self, $userID, $GlobalProblem);
# 		push @results, @result if @result;
# 	}
	
# 	return @results;
# }

# sub addProblemToSet {
# 	my ($self,$params) = @_;
# 	my $db = $self->{db};
# 	my $value_default = $self->{ce}->{problemDefaults}->{value};
# 	my $max_attempts_default = $self->{ce}->{problemDefaults}->{max_attempts};	
	


# 	die "addProblemToSet called without specifying the set name." if $params->{set_id} eq "";
# 	my $setName = $params->{set_id};

# 	my $sourceFile = $params->{sourceFile} or die "addProblemToSet called without specifying the sourceFile.";


# 	debug("In addProblemToSet");
# 	debug("setName: $setName");
# 	debug("sourceFile: $sourceFile");

# 	# The rest of the arguments are optional
	
# #	my $value = $params{value} || $value_default;
	
# 	my $out->{text} = encode_base64("Problem added to ".$setName);
# 	return $out;
# }

sub addProblem {
	my ($self,$params) = @_;
	my $db = $self->{db};
	my $setName = $params->{set_id};

	my $file = $params->{path};
	my $topdir = $self->{ce}->{courseDirs}{templates};
	$file =~ s|^$topdir/*||;
	
	# DBFIXME count would work just as well
	my $freeProblemID = max($db->listGlobalProblems($setName)) + 1;
	my $value_default = $self->{ce}->{problemDefaults}->{value};
	my $max_attempts_default = $self->{ce}->{problemDefaults}->{max_attempts};	

	my $value = $value_default;
	if (defined($params->{value}) and length($params->{value})){$value = $params->{value};}  # 0 is a valid value for $params{value} but we don't want emptystring

	my $maxAttempts = $params->{maxAttempts} || $max_attempts_default;
	my $problemID = $params->{problemID};

	unless ($problemID) {
		$problemID = WeBWorK::Utils::max($db->listGlobalProblems($setName)) + 1;
	}

	my $problemRecord = $db->newGlobalProblem;
	$problemRecord->problem_id($problemID);
	$problemRecord->set_id($setName);
	$problemRecord->source_file($file);
	$problemRecord->value($value);
	$problemRecord->max_attempts($maxAttempts);
	$db->addGlobalProblem($problemRecord);

	my @results; 
	my @userIDs = $db->listSetUsers($setName);
	foreach my $userID (@userIDs) {
		my @result = assignProblemToUser($self, $userID, $problemRecord);
		push @results, @result if @result;
	}
	

	#assignProblemToAllSetUsers($self, $problemRecord);
	my $out->{text} = encode_base64("Problem added to ".$setName);
	return $out;
}

sub deleteProblem {
	my ($self,$params) = @_;
	
	my $db = $self->{db};
	my $setName = $params->{set_id};
	
	my $file = $params->{path};
	my $topdir = $self->{ce}->{courseDirs}{templates};
	$file =~ s|^$topdir/*||;
	# DBFIXME count would work just as well
	foreach my $problem ($db->listGlobalProblems($setName)) {
		my $problemRecord = $db->getGlobalProblem($setName, $problem);
		
		if($problemRecord->source_file eq $file){
			#print "found it";
			$db->deleteGlobalProblem($setName, $problemRecord->problem_id);
		}
	}
	my $out->{text} = encode_base64("Problem removed from ".$setName);
	return $out;
}


## Search for set definition files
use File::Find;
sub get_set_defs {
	my $self = shift;
	my $topdir = $self->{ce}->{courseDirs}{templates};#shift #sort of hard coded for now;
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


