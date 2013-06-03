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
use WeBWorK::Utils qw(readDirectory max sortByName);
use WeBWorK::Utils::Tasks qw(renderProblems);

use strict;
use sigtrap;
use Carp;
use WWSafe;
#use Apache;
use WeBWorK::Utils;
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
  my $self = shift;
  my $db = $self->{db};
  my @found_sets;
  @found_sets = $db->listGlobalSets;
  my $out = {};
  $out->{ra_out} = \@found_sets;
  $out->{text} = encode_base64("Sets for course: ".$self->{courseName});
  return $out;
}

sub listLocalSetProblems{
	my $self = shift;
	my $in = shift;
  	my $db = $self->{db};
  	my @found_problems;
  	my $selectedSet = $in->{set};
  	warn "Finding problems for set ", $in->{set} if $UNIT_TESTS_ON;
  	my $templateDir = $self->{ce}->{courseDirs}->{templates};
  	@found_problems = $db->listGlobalProblems($selectedSet);
  	my $problem;
  	my @pg_files=();
  	for $problem (@found_problems) {
		my $problemRecord = $db->getGlobalProblem($selectedSet, $problem); # checked
		die "global $problem for set $selectedSet not found." unless
		$problemRecord;
		push @pg_files, $templateDir."/".$problemRecord->source_file;

	}
	#@pg_files = sortByName(undef,@pg_files);
	
  	my $out = {};
  	$out->{ra_out} = \@pg_files;
  	$out->{text} = encode_base64("Sets for course: ".$self->{courseName});
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
	            $out->{text} = encode_base64("Failed to create set, you may need to try another name.");
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


sub reorderProblems {
  	my $self = shift;
  	my $in = shift;
	my $db = $self->{db};
	my $setID = $in->{set};
	my $problemListString = $in->{probList};
	my @problemList = split(/,/, $problemListString);
	my $topdir = $self->{ce}->{courseDirs}{templates};
	#my (@problemIDList) = @_;
	#my ($prob1, $prob2, $prob);
	my $index = 1;
	#get all the problems
	my @problems = ();
	foreach my $path (@problemList) {
		$path =~ s|^$topdir/*||;
	  	#this will work if i can get problems by name
		my $problemRecord; # checked
		foreach my $problem ($db->listGlobalProblems($setID)) {
			my $tempProblem = $db->getGlobalProblem($setID, $problem);
		  	if($tempProblem->source_file eq $path){
		    	$problemRecord = $tempProblem;
		  	}
		}
		die "global " .$path ." for set $setID not found." unless $problemRecord;
		#print "found this problem to be reordered: ".$problemRecord."\n";
		push @problems, $problemRecord;
	  	$index = $index + 1;
	}
	#then change their info
	my @setUsers = $db->listSetUsers($setID);
	my $user;
	$index = 1;
	foreach my $problem (@problems) {
	  	$problem->problem_id($index);
	  	die "global $problem not found." unless $problem;
	  	#print "problem to be reordered: ".$problem."\n";
	  	$db->putGlobalProblem($problem);

	  	#need to deal with users?
	  	foreach $user (@setUsers) {
  			#my $prob1 = $db->getUserProblem($user, $setID, $index);
		  	#die " problem $index for set $setID and effective user $user not found"	unless $prob1;
      		#$prob1->problem_id($index);
  			#$db->putUserProblem($prob1);
	  	}
		$index = $index + 1;
	}
	my $out->{text} = encode_base64("Successfully reordered problems");
	return $out;
}


#problem utils from Instructor.pm
sub assignProblemToUser {
	my $self = shift;
	my $userID = shift;
	my $GlobalProblem = shift;
	my $seed = shift;;
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

sub assignProblemToAllSetUsers {
	my $self = shift;
	my $GlobalProblem = shift;
	my $db = $self->{db};
	my $setID = $GlobalProblem->set_id;
	my @userIDs = $db->listSetUsers($setID);
	
	my @results;
	
	foreach my $userID (@userIDs) {
		my @result = assignProblemToUser($self, $userID, $GlobalProblem);
		push @results, @result if @result;
	}
	
	return @results;
}

sub addProblemToSet {
	my $self = shift;
	my $args = shift;
	my $db = $self->{db};
	my $value_default = $self->{ce}->{problemDefaults}->{value};
	my $max_attempts_default = $self->{ce}->{problemDefaults}->{max_attempts};	
	

	die "addProblemToSet called without specifying the set name." if $args->{setName} eq "";
	my $setName = $args->{setName};

	my $sourceFile = $args->{sourceFile} or 
		die "addProblemToSet called without specifying the sourceFile.";

	# The rest of the arguments are optional
	
#	my $value = $args{value} || $value_default;
	my $value = $value_default;
	if (defined($args->{value})){$value = $args->{value};}  # 0 is a valid value for $args{value}  

	my $maxAttempts = $args->{maxAttempts} || $max_attempts_default;
	my $problemID = $args->{problemID};

	unless ($problemID) {
		$problemID = WeBWorK::Utils::max($db->listGlobalProblems($setName)) + 1;
	}

	my $problemRecord = $db->newGlobalProblem;
	$problemRecord->problem_id($problemID);
	$problemRecord->set_id($setName);
	$problemRecord->source_file($sourceFile);
	$problemRecord->value($value);
	$problemRecord->max_attempts($maxAttempts);
	$db->addGlobalProblem($problemRecord);

	return $problemRecord;
}

sub addProblem {
	my $self = shift;
	my $in = shift;
	my $db = $self->{db};
	my $setName = $in->{set};
	my $file = $in->{path};
	my $topdir = $self->{ce}->{courseDirs}{templates};
	$file =~ s|^$topdir/*||;
	my $freeProblemID;
	# DBFIXME count would work just as well
	$freeProblemID = max($db->listGlobalProblems($setName)) + 1;
	my $problemRecord = addProblemToSet($self, {setName => $setName, sourceFile => $file, problemID => $freeProblemID});
	assignProblemToAllSetUsers($self, $problemRecord);
	my $out->{text} = encode_base64("Problem added to ".$setName);
	return $out;
}

sub deleteProblem {
	my $self = shift;
	my $in = shift;
	my $db = $self->{db};
	my $setName = $in->{set};
	
	my $file = $in->{path};
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


