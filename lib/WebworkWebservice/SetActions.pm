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

  	my $templateDir = $self->{ce}->{courseDirs}->{templates};
  	@found_problems = $db->listGlobalProblems($setName);

  	my @pg_files=();
  	for my $problem (@found_problems) {
		my $problemRecord = $db->getGlobalProblem($setName, $problem); # checked
		die "global $problem for set $setName not found." unless
		$problemRecord;
		push @pg_files, $templateDir."/".$problemRecord->source_file;

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
  my @found_sets;
  @found_sets = $db->listGlobalSets;
  
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
    $out->{text} = encode_base64("Successfully found the number of users for " . $params->{set_id});
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
					#figure this bit out later
					#$self->addgoodmessage("Set $newSetName has been created.");
					my $selfassign = $in->{selfassign};
					$selfassign = "" if($selfassign =~ /false/i); # deal with javascript false
					if($selfassign) {
						$self->assignSetToUser($self->{user}, $newSetRecord);
						#$self->addgoodmessage("Set $newSetName was assigned to $userName.");
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
	my $self = shift;
  	my $params = shift;
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
	my @newProblems = ();
	my @allProblems = $db->getAllGlobalProblems($setID);

	foreach my $problem (@allProblems) {
		my $index =1; 
		debug($problem->{source_file});
		debug($problem->{problem_id});
		debug($problem->{set_id});
		debug($problem->{value});

		my $recordFound = 0; 
		foreach my $path (@problemList) {
			$path =~ s|^$topdir/*||;
			
		  	# this will work if i can get problems by name
				if($problem->{source_file} eq $path){
				   	$problem->problem_id($index);

				   	#debug($problem->{source_file});
				   	#debug($problem->{problem_id});
		   			$db->putGlobalProblem($problem);
		   			$recordFound = 1; 
			 	}
			$index = $index +1; 
		}
		die "global " .$problem->{source_file} ." for set $setID not found." unless $recordFound;
			
	}

	#foreach my $problem (@newProblems){
	#	debug($problem->{source_file});
	#}

	#then change their info
	# my @setUsers = $db->listSetUsers($setID);
	# my $user;
	# my $index = 1;
	# foreach my $problem (@problems) {
	#    	$problem->problem_id($index);
	#    	die "global $problem not found." unless $problem;
	# #   	#print "problem to be reordered: ".$problem."\n";
	#    	my $sourceFile = $problem->{source_file};
	#    	debug("before putGlobalProblem: $sourceFile");
	#    	my $probExists = $db->existsGlobalProblem($setID,$problem);
	#    	debug("problem Exists: $probExists");
	#    	#$db->addGlobalProblem($problem);

	# #   	#need to deal with users?
	#    	foreach $user (@setUsers) {
 #   			my $prob1 = $db->getUserProblem($user, $setID, $index);
	#  	  	die " problem $index for set $setID and effective user $user not found"	unless $prob1;
 #       		$prob1->problem_id($index);
 #   			$db->putUserProblem($prob1);
	#    	}
	#  	$index = $index + 1;
	#  }
	my $out;

	$out->{text} = encode_base64("Successfully reordered problems");
	return $out;
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
	if (defined($params->{value})){$value = $params->{value};}  # 0 is a valid value for $params{value}  

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


