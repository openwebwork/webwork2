################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/StudentProgress.pm,v 1.36 2008/06/19 19:34:31 glarose Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ContentGenerator::Instructor::StudentProgress;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::StudentProgress - Display Student Progress.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::ContentGenerator::Grades;
use WeBWorK::Utils qw(jitar_id_to_seq jitar_problem_adjusted_status wwRound);
#use WeBWorK::Utils qw(readDirectory list2hash max sortByName);
use WeBWorK::Utils::SortRecords qw/sortRecords/;
use WeBWorK::Utils::Grades qw/list_set_versions/;
use WeBWorK::DB::Record::UserSet;  #FIXME -- this is only used in one spot.

# The table format has been borrowed from the Grades.pm module
sub initialize {
	my $self     = shift; 
	# FIXME  are there args here?
	my @components = @_;
	my $r          = $self->{r};
	my $urlpath    = $r->urlpath;
	my $type       = $urlpath->arg("statType") || '';
	my $db         = $self->{db};
	my $ce         = $self->{ce};
	my $authz      = $self->{authz};
	my $courseName = $urlpath->arg('courseID');
 	my $user       = $r->param('user');
 	
 	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	
 	$self->{type}  = $type;
 	if ($type eq 'student') {
 		my $studentName = $r->urlpath->arg("userID") || $user;
 		$self->{studentName } = $studentName;
 		
 	} elsif ($type eq 'set') {
 		my $setName = $r->urlpath->arg("setID") || 0;
 		$self->{setName}     = $setName;
 		my $setRecord  = $db->getGlobalSet($setName); # checked
		die "global set $setName  not found." unless $setRecord;
		$self->{set_due_date} = $setRecord->due_date;
		$self->{setRecord}   = $setRecord;
 	}
}


sub title { 
	my ($self) = @_;
	my $r = $self->r;
	my $authz = $r->authz;
	my $user = $r->param('user');
	
	# Check permissions
	return "" unless $authz->hasPermissions($user, "access_instructor_tools");
	
	my $type                = $self->{type};
	my $string              = $r->maketext("Student Progress for")." ".$self->{ce}->{courseName}." ";
	if ($type eq 'student') {
		$string             .= $r->maketext("student")." ".$self->{studentName};
	} elsif ($type eq 'set' ) {
		$string             .= $r->maketext("set")." ".$self->{setName};
		$string             .= ".&nbsp;&nbsp;&nbsp; ".$r->maketext("Due")." ". $self->formatDateTime($self->{set_due_date});
	}
	return $string;
}
sub siblings {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $authz = $r->authz;
	my $user = $r->param('user');
	my $urlpath = $r->urlpath;
	
	# Check permissions
	return "" unless $authz->hasPermissions($user, "access_instructor_tools");
	
	my $courseID = $urlpath->arg("courseID");
	my $eUserID  = $r->param("effectiveUser");
	my @setIDs   = sort  $db->listGlobalSets;
	
	my $progress     = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::StudentProgress",  $r, 
	                                        courseID => $courseID);
	
	print CGI::start_div({class=>"info-box", id=>"fisheye"});
	print CGI::h2("Student Progress");
	#print CGI::start_ul({class=>"LinksMenu"});
	#print CGI::start_li();
	#print CGI::span({style=>"font-size:larger"}, CGI::a({href=>$self->systemLink($stats)}, 'Statistics'));
	print CGI::start_ul();
	foreach my $setID (@setIDs) {
		my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::StudentProgress", $r, 
			courseID => $courseID, setID => $setID,statType => 'set',);
		my $prettySetID = $setID;
		$prettySetID =~ s/_/ /g;
		print CGI::li({},CGI::a({href=>$self->systemLink($problemPage)}, $prettySetID));
	}
	
	print CGI::end_ul();
	#print CGI::end_li();
	#print CGI::end_ul();
	print CGI::end_div();
	
	return "";
}
sub body {
	my $self       = shift;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $authz      = $r->authz;
	my $user       = $r->param('user');
	my $courseName = $urlpath->arg("courseID");
	my $type       = $self->{type};

	# Check permissions	
	return CGI::div({class=>"ResultsWithError"}. CGI::p("You are not authorized to access instructor tools"))
		unless $authz->hasPermissions($user, "access_instructor_tools");
		
	if ($type eq 'student') {
		my $studentName = $self->{studentName};
		my $studentRecord = $db->getUser($studentName) # checked
			or die "record for user $studentName not found";
		my $fullName = $studentRecord->full_name;
        my $courseHomePage = $urlpath->new(type  => 'set_list',
        	args => {courseID=>$courseName});
		my $email = $studentRecord->email_address;
		
		print CGI::a({-href=>"mailto:$email"}, $email), CGI::br(),
			$r->maketext("Section").": ", $studentRecord->section, CGI::br(),
			$r->maketext("Recitation").": ", $studentRecord->recitation, CGI::br();
		
		if ($authz->hasPermissions($user, "become_student")) {
			my $act_as_student_url = $self->systemLink($courseHomePage,
				params => {effectiveUser=>$studentName});
			
			print $r->maketext("Act as:")." ".CGI::a({-href=>$act_as_student_url},$studentRecord->user_id);
		}
		
		print WeBWorK::ContentGenerator::Grades::displayStudentStats($self,$studentName);
	} elsif( $type eq 'set') {
		$self->displaySets($self->{setName});
	} elsif ($type eq '') {
		
		$self->index;
	} else {
		warn "Don't recognize statistics display type: |$type|";

	}
	

	return '';

}
sub index {
	my $self          = shift;
	my $r             = $self->r;
	my $urlpath       = $r->urlpath;
	my $ce            = $r->ce;
	my $db            = $r->db;
	my $courseName    = $urlpath->arg("courseID");
	my @studentList   = sort $db->listUsers;
	my @setList       = sort  $db->listGlobalSets;

## Edit to filter out students you aren't allowed to see
#
	# DBFIXME do filtering in database
	my @myUsers;
#	my @studentRecords = $db->getUsers;  #this is never used
	my $user = $r->param("user");
	
	my (@viewable_sections, @viewable_recitations);
	if (defined $ce->{viewable_sections}->{$user})
		{@viewable_sections = @{$ce->{viewable_sections}->{$user}};}
	if (defined $ce->{viewable_recitations}->{$user})
		{@viewable_recitations = @{$ce->{viewable_recitations}->{$user}};}
	if (@viewable_sections or @viewable_recitations){
		foreach my $studentL (@studentList){
			my $keep = 0;
			my $student = $db->getUser($studentL);
			foreach my $sec (@viewable_sections){
				if ($student->section() eq $sec){$keep = 1; last;}
			}
			foreach my $rec (@viewable_recitations){
				if ($student->recitation() eq $rec){$keep = 1; last;}
			}
			if ($keep) {push @myUsers, $studentL;}		
		}
#	@studentList = @myUsers;
	}
	else {@myUsers = @studentList;}
	
	# DBFIXME sort in database
	my @studentRecords = $db->getUsers(@myUsers);
	my @sortedStudentRecords = sortRecords({fields=>[qw/last_name first_name user_id/]}, @studentRecords);
		
	my @setLinks      = ();
	my @studentLinks  = (); 
	foreach my $set (@setList) {
	    my $setStatisticsPage   = $urlpath->newFromModule($urlpath->module, $r, 
	                                                      courseID => $courseName,
	                                                      statType => 'set',
	                                                      setID    => $set
	    );
	    my $prettySetID = $set;
	    $prettySetID =~ s/_/ /g;
		push @setLinks, CGI::a({-href=>$self->systemLink($setStatisticsPage) }, $prettySetID);
	}
	
	foreach my $studentRecord (@sortedStudentRecords) {
		my $first_name = $studentRecord->first_name;
		my $last_name = $studentRecord->last_name;
		my $user_id = $studentRecord->user_id;
		my $userStatisticsPage  = $urlpath->newFromModule($urlpath->module, $r, 
	                                                      courseID => $courseName,
	                                                      statType => 'student',
	                                                      userID   => $user_id
	    );

		push @studentLinks, CGI::a({-href=>$self->systemLink($userStatisticsPage,
		                                                     prams=>{effectiveUser => $studentRecord->user_id}
		                                                     )},"  $last_name, $first_name  ($user_id)" ),;	
	}
	print join("",
		CGI::start_table({-border=>2, -cellpadding=>20}),
		CGI::Tr({},
			CGI::td({-valign=>'top'}, 
				CGI::h3({-align=>'center'},$r->maketext('View student progress by set')),
				CGI::ul(  CGI::li( [@setLinks] ) ), 
			),
			CGI::td({-valign=>'top'}, 
				CGI::h3({-align=>'center'},$r->maketext('View student progress by student')),
				CGI::ul(CGI::li( [ @studentLinks ] ) ),
			),
		),
		CGI::end_table(),
	);
	
}
###################################################
sub displaySets {
	my $self             = shift;	
	my $r                = $self->r;
	my $urlpath          = $r->urlpath;
	my $db               = $r->db;
	my $ce               = $r->ce;
	my $authz            = $r->authz;
	my $courseName       = $urlpath->arg("courseID");
	my $setName          = $urlpath->arg("setID");
	my $user             = $r->param('user');
	my $GlobalSet        = $self->{setRecord};
	my $root             = $ce->{webworkURLs}->{root};
	
	my $setStatsPage     = $urlpath->newFromModule($urlpath->module, $r, courseID=>$courseName,statType=>'sets',setID=>$setName);
	my $primary_sort_method_name = $r->param('primary_sort');
	my $secondary_sort_method_name = $r->param('secondary_sort'); 
	my $ternary_sort_method_name = $r->param('ternary_sort');  

	# DBFIXME duplicate call!
	my @studentList      = $db->listUsers;
    
# another versioning/gateway change.  in many cases we don't want or need
# all of the columns that are put in here by default, so we add a set of
# flags for which columns to show.  for versioned sets we may also want to
# only see the best score, so we include that as an option also.
# these are ignored for non-versioned sets
	my %showColumns = ( 'name' => 1, 'score' => 1, 'outof' => 1, 
			    'date' => 0, 'testtime' => 0, 'index' => 1, 
			    'problems' => 1, 'section' => 1, 'recit' => 1, 
			    'login' => 1 );
	my $showBestOnly = 0;

   	my @index_list                           = ();  # list of all student index 
	my @score_list                           = ();  # list of all student total percentage scores 
	my %attempts_list_for_problem            = ();  # a list of the number of attempts for each problem
	my %number_of_attempts_for_problem       = ();  # the total number of attempst for this problem (sum of above list)
	my %number_of_students_attempting_problem = ();  # the number of students attempting this problem.
	my %correct_answers_for_problem          = ();  # the number of students correctly answering this problem (partial correctness allowed)
	my $sort_method = sub {
		my ($a,$b,$sort_method_name) = @_;
		return 0 unless defined($sort_method_name);
		return lc($a->{last_name}) cmp lc($b->{last_name}) if $sort_method_name eq 'last_name';
		return lc($a->{first_name}) cmp lc($b->{first_name}) if $sort_method_name eq 'first_name';
		return 	lc($a->{email_address}) cmp lc($b->{email_address}) if $sort_method_name eq 'email_address';
		return $b->{score} <=> $a->{score} if $sort_method_name eq 'score';
		return $b->{index} <=> $a->{index} if $sort_method_name eq 'index';
		return lc($a->{section}) cmp lc($b->{section}) if $sort_method_name eq 'section';
		return lc($a->{recitation}) cmp lc($b->{recitation}) if $sort_method_name eq 'recitation';
		return lc($a->{user_id}) cmp lc($b->{user_id}) if $sort_method_name eq 'user_id';
		if ($sort_method_name =~/p(\d+)/) {
			my $left  =  $b->{problemData}->{$1} ||0;
			my $right =  $a->{problemData}->{$1} ||0;
			return $left <=> $right;  # sort by number of attempts.
		}

	};
	my %display_sort_method_name = (
		last_name => 'last name',
		first_name => 'first name',
		email_address => 'email address',
		score => 'score',
		index => 'success indicator',
		section => 'section',
		recitation => 'recitation',
		user_id => 'login name',
	);				

# get versioning information
	my $setIsVersioned = 
	    ( defined($GlobalSet->assignment_type()) && 
	      $GlobalSet->assignment_type() =~ /gateway/ ) ? 1 : 0;

# reset column view options based on whether the set is versioned and, if so,
# the input parameters
	if ( $setIsVersioned ) {
  # the returning parameter lets us set defaults for versioned sets
		my $ret = defined($r->param('returning')) ? 
			$r->param('returning') : 0;
		$showColumns{'date'} = ($ret && !defined($r->param('show_date'))) ? $r->param('show_date') : 1;
		$showColumns{'testtime'} = ($ret && !defined($r->param('show_testtime'))) ? $r->param('show_testtime'):1;
		$showColumns{'index'} = ($ret && defined($r->param('show_index'))) ? $r->param('show_index') : 0;
		$showColumns{'problems'} = ($ret && defined($r->param('show_problems'))) ? $r->param('show_problems'):0;
		$showColumns{'section'} = ($ret && defined($r->param('show_section'))) ? $r->param('show_section') : 0;
		$showColumns{'recit'} = ($ret && defined($r->param('show_recitation'))) ? $r->param('show_recitation') : 0;
		$showColumns{'login'} = ($ret && defined($r->param('show_login'))) ? $r->param('show_login') : 0;
		$showBestOnly = ($ret && defined($r->param('show_best_only'))) ? $r->param('show_best_only') : 0;
	}

###############################################################
#  Print tables
###############################################################
	
	my $max_num_problems  = 0;
	# get user records
	debug("Begin obtaining user records for set $setName");
	my @userRecords  = $db->getUsers(@studentList);
	debug("End obtaining user records for set $setName");
    debug("begin main loop");
 	my @augmentedUserRecords    = ();
 	my $number_of_active_students;

## Edit to filter out students
#
	my @myUsers;
	my $ActiveUser = $r->param("user");
	my (@viewable_sections, @viewable_recitations);
	if (defined $ce->{viewable_sections}->{$user})
		{@viewable_sections = @{$ce->{viewable_sections}->{$user}};}
	if (defined $ce->{viewable_recitations}->{$user})
		{@viewable_recitations = @{$ce->{viewable_recitations}->{$user}};}
	if (@viewable_sections or @viewable_recitations){
		foreach my $student (@userRecords){
			my $keep = 0;
			foreach my $sec (@viewable_sections){
				if ($student->section() eq $sec){$keep = 1; last;}
			}
			foreach my $rec (@viewable_recitations){
				if ($student->recitation() eq $rec){$keep = 1; last;}
			}
			if ($keep) {push @myUsers, $student;}		
		}
	}
	else {@myUsers = @userRecords;}
	foreach my $studentRecord (@myUsers)   {
		next unless ref($studentRecord);
		my $studentName = $studentRecord->user_id;
		next if $studentRecord->last_name =~/^practice/i;  # don't show practice users
		next unless $ce->status_abbrev_has_behavior($studentRecord->status, "include_in_stats");
		$number_of_active_students++;

# build list of versioned sets for this student user
# 		my @allSetNames = ();
# 		my $notAssignedSet = 0;
# 		if ( $setIsVersioned ) {
# 			my @setVersions = $db->listSetVersions($studentName, $setName);
# 			@allSetNames = map { "$setName,v$_" } @setVersions;
# 			# if there aren't any set versions, is it because
# 			#    the user isn't assigned the set (e.g., is a 
# 			#    proctor), or because the user hasn't completed
# 			#    any versions?
# 			if ( ! @setVersions ) {
# 				$notAssignedSet = 1 if (! $db->existsUserSet($studentName,$setName));
# 			}
# 
# 		} else {
# 			@allSetNames = ( "$setName" );
# 		}
        my( $ra_allSetVersionNames, $notAssignedSet) = list_set_versions($db, $studentName, $setName, $setIsVersioned);
        my @allSetVersionNames = @{$ra_allSetVersionNames};
        
		# for versioned sets, we might be keeping only the high score
		my $maxScore = -1;
		my $max_hash = {};

		foreach my $setName ( @allSetVersionNames ) {

			my $status          = 0;
			my $longStatus      = '';
			my $string          = '';
			my $twoString       = '';
			my $totalRight      = 0;
			my $total           = 0;
			my $total_num_of_attempts_for_set = 0;
			my %h_problemData   = ();
			my $num_of_attempts;
			my $num_of_problems;
			
			my $set;
			my $userSet;
            if ( $setIsVersioned ) {
				my ($setN,$vNum) = ($setName =~ /(.+),v(\d+)$/);
				# we'll also need information from the set
				#    as we set up the display below, so get
				#    the merged userset as well
				$set = $db->getMergedSetVersion($studentRecord->user_id, $setN, $vNum);
				$userSet = $set;
				$setName = $setN;
			} else {
			    $set = $db->getMergedSet( $studentName, $setName );
			
			}
		     #FIXME -- this seems like over kill -- perhaps we only need to pass in the set_id.
		     # that is the only aspect of $set that is used in grade set.
		     # the problem_random order sequence is used in the corresponding routine in Grades.pm
		     
		    unless ( ref($set) ) {
		    	$set = new WeBWorK::DB::Record::UserSet;
		    	$set->set_id($setName);
		    }
		    
           ( $status, 
             $longStatus, 
             $string,
             $twoString, 
             $totalRight,
             $total, 
             $num_of_attempts, 
             $num_of_problems) = grade_set( $db, $set, $setName, $studentName, $setIsVersioned,
									    \%number_of_students_attempting_problem,
									    \%attempts_list_for_problem,
										\%number_of_attempts_for_problem,
										\%h_problemData,
										\$total_num_of_attempts_for_set,
										\%correct_answers_for_problem,
						       );
			my $probNum         = 0;
			my $act_as_student_url = '';


# 		
# 			# add on the scores for this problem
# 			if (defined($attempted) and $attempted) {
# 				$number_of_students_attempting_problem{$probID}++;
# 				push( @{ $attempts_list_for_problem{$probID} } ,     $num_of_attempts);
# 				$number_of_attempts_for_problem{$probID}             += $num_of_attempts;
# 				$h_problemData{$probID}                               = $num_incorrect;
# 				$total_num_of_attempts_for_set                       += $num_of_attempts;
# 				$correct_answers_for_problem{$probID}                += $status;
# 			}

# 
# 			# DBFIXME: to collect the problem records, we have 
# 			#    to know which merge routines to call.  Should 
# 			#    this really be an issue here?  That is, 
# 			#    shouldn't the database deal with it invisibly 
# 			#    by detecting what the problem types are?
# 			# DBFIXME sort in database
# 			my $userSet;
# 			my @problemRecords = ();
# 			if ( $setIsVersioned ) {
# 				my ($setN,$vNum) = ($sN =~ /(.+),v(\d+)$/);
# 				@problemRecords = sort {$a->problem_id <=> $b->problem_id } $db->getAllMergedProblemVersions( $student, $setN, $vNum );
# 				# we'll also need information from the set
# 				#    as we set up the display below, so get
# 				#    the merged userset as well
# 				$userSet = $db->getMergedSetVersion($studentRecord->user_id, $setN, $vNum);
# 
# 			} else {
# 				@problemRecords = sort {$a->problem_id <=> $b->problem_id} $db->getAllMergedUserProblems( $student, $sN );
# 			}
# 			debug("End obtaining problem records for user $student set $sN");
# 			my $num_of_problems = @problemRecords;
# 			$max_num_problems = ($max_num_problems>= $num_of_problems) ? $max_num_problems : $num_of_problems;
# 			########################################
# 			# Notes for factoring the calculation in this loop.
# 			#
# 			# Inputs include:
# 			#   @problemRecords  
# 			# returns
# 			#   $num_of_attempts
# 			#   $status
# 			# updates
# 			#   $number_of_students_attempting_problem{$probID}++;
# 			#   @{ $attempts_list_for_problem{$probID} }   
# 			#   $number_of_attempts_for_problem{$probID}
# 			#   $total_num_of_attempts_for_set
# 			#   $correct_answers_for_problem{$probID}   
# 			#    
# 			#   $string (formatting output)
# 			#   $twoString (more formatted output)
# 			#   $longtwo (a combination of $string and $twostring)
# 			#   $total
# 			#   $totalRight
# 			###################################
#    
# 			foreach my $problemRecord (@problemRecords) {
# 				next unless ref($problemRecord);
# 				# warn "Can't find record for problem $prob in set $setName for $student";
# 				# FIXME check the legitimate reasons why a student record might not be defined
# 				###########################################
# 				# Grab data from the database
# 				###########################################
# 				# It's possible that 
# 				# $problemRecord->num_correct or 
# 				# $problemRecord->num_correct
# 				# or $problemRecord->status is an empty 
# 				# or blank string instead of 0.  
# 				# The || clause fixes this and prevents 
# 				# warning messages in the comparisons below.
# 			
# 				my $probID          = $problemRecord->problem_id;
# 				my $attempted       = $problemRecord->attempted;
# 				my $num_correct     = $problemRecord->num_correct     || 0;
# 				my $num_incorrect   = $problemRecord->num_incorrect   || 0;
# 				my $num_of_attempts = $num_correct + $num_incorrect;
# 				# initialize the number of correct answers 
# 				# for this problem if the value has not been 
# 				# defined.
# 				$correct_answers_for_problem{$probID} = 0 
# 					unless defined($correct_answers_for_problem{$probID});
# 
# 				## This doesn't work - Fix it
# 				my $probValue = $problemRecord->value;
# 				# set default problem value here
# 				# FIXME?? set defaults here?
# 				$probValue = 1 unless defined($probValue) and 
# 					$probValue ne "";  
# 			
# 				my $status  = $problemRecord->status || 0;
# 
# 				# sanity check that the status (score) is 
# 				# between 0 and 1
# 				my $valid_status = ($status>=0 && $status<=1)?1:0;
# 
# 				###########################################
# 				# Determine the string $longStatus which 
# 				# will display the student's current score
# 				###########################################
# 				my $longStatus = '';
# 				if (!$attempted){
# 					$longStatus     = '.';
# 				} elsif   ($valid_status) {
# 					$longStatus     = int(100*$status+.5);
# 					$longStatus='C' if ($longStatus==100);
# 				} else	{
# 					$longStatus 	= 'X';
# 				}
# 			
# 				$string     .= threeSpaceFill($longStatus);
# 				$twoString  .= threeSpaceFill($num_incorrect);
# 
# 				$total      += $probValue;
# 				$totalRight += round_score($status*$probValue) 
# 					if $valid_status;
# 			
# 				# add on the scores for this problem
# 				if (defined($attempted) and $attempted) {
# 					$number_of_students_attempting_problem{$probID}++;
# 					push( @{ $attempts_list_for_problem{$probID} } ,     $num_of_attempts);
# 					$number_of_attempts_for_problem{$probID}             += $num_of_attempts;
# 					$h_problemData{$probID}                               = $num_incorrect;
# 					$total_num_of_attempts_for_set                       += $num_of_attempts;
# 					$correct_answers_for_problem{$probID}                += $status;
# 				}
# 			
# 			}  # end of problem record loop
            
            
			# for versioned tests we might be displaying the 
			# test date and test time
			my $dateOfTest = '';
			my $testTime = '';
			if ( $setIsVersioned ) {
				# if this isn't defined, something's wrong
				if ( defined($userSet) ) {  
					$dateOfTest = localtime($userSet->version_creation_time());
					if ( defined($userSet->version_last_attempt_time()) && $userSet->version_last_attempt_time() ) {
						$testTime = ($userSet->version_last_attempt_time() - $userSet->open_date() ) / 60; 
						my $timeLimit = $userSet->version_time_limit()/60;
						$testTime = $timeLimit if ( $testTime > $timeLimit );
						$testTime = sprintf("%3.1f min", $testTime);
					} elsif ( time() - $userSet->open_date() < $userSet->version_time_limit() ) {
						$testTime = 'still open';
					} else {
						$testTime = 'time limit ' .
							'exceeded';
					}
				} else {
					$dateOfTest = '???';
					$testTime = '???';
				}
			}
		
		
			$act_as_student_url = $self->systemLink($urlpath->new(type=>'set_list',args=>{courseID=>$courseName}), params=>{effectiveUser => $studentRecord->user_id});
			my $email              = $studentRecord->email_address;
			# FIXME  this needs formatting

			# change to give better output for gateways with; 
			# only one attempt per version: just reports the 
			# result for each problem, not the number of attempts.
			my $longtwo = ($setIsVersioned && 
				       $userSet->attempts_per_version == 1) ? 
				       $string : "$string\n$twoString";
		
			my $avg_num_attempts = ($num_of_problems) ? $total_num_of_attempts_for_set/$num_of_problems : 0;
			my $successIndicator = ($avg_num_attempts && $total) ? ($totalRight/$total)**2/$avg_num_attempts : 0 ;
		
			my $temp_hash         = { user_id        => $studentRecord->user_id,
		                                  last_name      => $studentRecord->last_name,
		                                  first_name     => $studentRecord->first_name,
		                                  score          => $totalRight,
		                                  total          => $total,
		                                  index          => $successIndicator,
		                                  section        => $studentRecord->section,
		                                  recitation     => $studentRecord->recitation,
		                                  problemString  => "<pre>$longtwo</pre>",
		                                  act_as_student => $act_as_student_url,
		                                  email_address  => $studentRecord->email_address,
		                                  problemData    => {%h_problemData},
						  date           => $dateOfTest,
						  testtime       => $testTime,
					      }; 
			
			# keep track of best score
			if ( $totalRight > $maxScore ) {
				$maxScore = $totalRight;
				$max_hash = { %$temp_hash };
			}

			# if we're showing all records, add it in to the list
			if ( ! $showBestOnly ) {
				# add this data to the list of total scores (out of 100)
				# add this data to the list of success indices.
				push( @index_list, $temp_hash->{index});
				push( @score_list, ($temp_hash->{total}) ?$temp_hash->{score}/$temp_hash->{total} : 0 ) ;
				push( @augmentedUserRecords, $temp_hash );
			}

		} # this closes the loop through all set versions

		# if we're showing only the best score, add the best score now
		if ( $showBestOnly ) {
			# if there's no %$max_hash, then we had no results
			#    this occurs for proctors, for example
			if ( $notAssignedSet ) {
				next;
			} elsif ( ! %$max_hash ) {
				$max_hash = { 
					user_id => $studentRecord->user_id(),
					last_name=>$studentRecord->last_name(),
					first_name=>$studentRecord->first_name(),
					score => 0,
					total => 'n/a',
					index => 0,
					section => $studentRecord->section(),
					recitation=>$studentRecord->recitation(),
					problemString => 'no attempt recorded',
					act_as_student => $self->systemLink($urlpath->new(type=>'set_list',args=>{courseID=>$courseName}), params=>{effectiveUser => $studentRecord->user_id}),
					email_address => $studentRecord->email_address(),
					problemData => {},
					date => 'none',
					testtime => 'none',
				};
			}

			push( @index_list, $max_hash->{index} );
			push( @score_list, 
			      ($max_hash->{total} && $max_hash->{total} ne 'n/a') ? 
			      $max_hash->{score}/$max_hash->{total} : 0 );
			push( @augmentedUserRecords, $max_hash );
		# if there were no set versions and the set was assigned
		#    to the user, also keep the data
		} elsif ( ! @allSetVersionNames && ! $notAssignedSet ) {
			my $dataH = { user_id => $studentRecord->user_id(),
				      last_name=>$studentRecord->last_name(),
				      first_name=>$studentRecord->first_name(),
				      score => 0,
				      total => 'n/a',
				      index => 0,
				      section => $studentRecord->section(),
				      recitation=>$studentRecord->recitation(),
				      problemString => 'no attempt recorded',
				      act_as_student => $self->systemLink($urlpath->new(type=>'set_list',args=>{courseID=>$courseName}), params=>{effectiveUser => $studentRecord->user_id}),
				      email_address => $studentRecord->email_address(),
				      problemData => {},
				      date => 'none',
				      testtime => 'none',
				  };
			push( @index_list, 0 );
			push( @score_list, 0 );
			push( @augmentedUserRecords, $dataH );

		}

        } # this closes the loop through all student records
	
	debug("end mainloop");
	
	@augmentedUserRecords = sort {
		&$sort_method($a,$b,$primary_sort_method_name)
			||
		&$sort_method($a,$b,$secondary_sort_method_name)
			||
		&$sort_method($a,$b,$ternary_sort_method_name)
			||			
		lc($a->{last_name}) cmp lc($b->{last_name})
			||
		lc($a->{first_name}) cmp lc($b->{first_name})
			||
		lc($a->{user_id}) cmp lc($b->{user_id})	
		} 
		@augmentedUserRecords;
	

	# construct header
	my $problem_header = '';
	# DBFIXME sort in database
	my @list_problems = sort {$a<=> $b } $db->listGlobalProblems($setName );

	# for a jitar set we only get the top level problems
	if($GlobalSet->assignment_type eq 'jitar') {
	    my @topLevelProblems; 
	    
	    foreach my $id (@list_problems) {
		my @seq = jitar_id_to_seq($id);
		push @topLevelProblems, $seq[0] if ($#seq == 0);
	    }
	    
	    @list_problems = @topLevelProblems;
	}	    


	$problem_header = '<pre>'.join("", map {&threeSpaceFill($_)}  @list_problems  ).'</pre>';

# changes for gateways/versioned sets here.  in this case we allow instructors
# to modify the appearance of output, which we do with a form.  so paste in the
# form header here, and make appropriate modifications
        my $verSelectors = '';
	if ( $setIsVersioned ) {
	    print CGI::start_div({'id'=>'screen-options-wrap'});
		print CGI::start_form({'method' => 'post', 'id'=>'sp-gateway-form',
				       'action' => $self->systemLink($urlpath,authen=>0),'name' => 'StudentProgress'});
		print $self->hidden_authen_fields();
		   print CGI::start_div();		   
			print	  CGI::h4("Display options: Show ");	
			print   CGI::start_div({'class'=>'metabox-prefs'});	   
			print     CGI::hidden(-name=>'returning', -value=>'1'),
			     CGI::checkbox(-name=>'show_best_only', -value=>'1', 
					   -checked=>$showBestOnly, 
					   -label=>'only best scores'),
#			     CGI::checkbox(-name=>'show_index', -value=>'1', 
#					   -checked=>$showColumns{'index'},
#					   -label=>' success indicator; '),
			     CGI::checkbox(-name=>'show_date', -value=>'1', 
					   -checked=>$showColumns{'date'},
					   -label=>'test date'),
			     CGI::checkbox(-name=>'show_testtime', -value=>'1', 
					   -checked=>$showColumns{'testtime'},
					   -label=>'test time'),
			     CGI::checkbox(-name=>'show_problems', -value=>'1', 
					   -checked=>$showColumns{'problems'},
					   -label=>'problems'),
			     CGI::checkbox(-name=>'show_section', -value=>'1', 
					   -checked=>$showColumns{'section'}, 
					   -label=>'section #'),
			     CGI::checkbox(-name=>'show_recitation', -value=>'1', 
					   -checked=>$showColumns{'recit'},
					   -label=>'recitation #'),
			     CGI::checkbox(-name=>'show_login', -value=>'1', 
					   -checked=>$showColumns{'login'}, 
					   -label=>'login'), CGI::br();
			print CGI::end_div();		    
			print CGI::submit(-value=>'Update Display');	
		print CGI::end_div();
		print CGI::end_form();
	  print CGI::end_div();
	}

#####################################################################################
	print
#		CGI::br(),
		CGI::br(),
		CGI::p({},$r->maketext('A period (.) indicates a problem has not been attempted, a &quot;C&quot; indicates a problem has been answered 100% correctly, and a number from 0 to 99 indicates the percentage of partial credit earned. The number on the second line gives the number of incorrect attempts.'),
#		'The success indicator,' ,CGI::i('Ind'),', for each student is calculated as',
#		CGI::br(),
#		'100*(totalNumberOfCorrectProblems / totalNumberOfProblems)^2 / (AvgNumberOfAttemptsPerProblem)',CGI::br(),
#		'or 0 if there are no attempts.'
		),
		CGI::br(),
		$r->maketext("Click on a student's name to see the student's version of the homework set. Click heading to sort table."),
		CGI::br(),
		CGI::br(),
		defined($primary_sort_method_name) ?" Entries are sorted by $display_sort_method_name{$primary_sort_method_name}":'',
		defined($secondary_sort_method_name) ?", then by $display_sort_method_name{$secondary_sort_method_name}":'',
		defined($ternary_sort_method_name) ?", then by $display_sort_method_name{$ternary_sort_method_name}":'',
		defined($primary_sort_method_name) ?'.':'',
	;
	# calculate secondary and ternary sort methods parameters if appropriate
	my %past_sort_methods = ();		
	%past_sort_methods = (secondary_sort => "$primary_sort_method_name",) if defined($primary_sort_method_name);
	%past_sort_methods = (%past_sort_methods, ternary_sort => "$secondary_sort_method_name",) if defined($secondary_sort_method_name);

	# continue with table output
	if ( ! $setIsVersioned ) {
	    print
		CGI::start_table({-class=>"progress-table", -border=>5,style=>'font-size:smaller'}),
		CGI::Tr(CGI::td(  {-align=>'left'},
			['Name'.CGI::br().CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'first_name', %past_sort_methods})},$r->maketext('First')).
			   '&nbsp;&nbsp;&nbsp;'.CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'last_name', %past_sort_methods })},$r->maketext('Last')).CGI::br().
			   CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'email_address', %past_sort_methods })},'Email'),
			CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'score', %past_sort_methods})},$r->maketext("Score")),
			$r->maketext("Out Of"),
#			CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'index', %past_sort_methods})},'Ind'),
			$r->maketext("Problems").CGI::br().$problem_header,
			CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'section', %past_sort_methods})},$r->maketext('Section')),
			CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'recitation', %past_sort_methods})},$r->maketext('Recitation')),
			CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'user_id', %past_sort_methods})},'Login Name'),
			])

		),
		;
	} else {
		# we need to preserve display options when the sort headers are clicked
		my %display_options = (
			returning       => 1,
			show_best_only  => $showBestOnly,
#			show_index      => $showColumns{index},
			show_date       => $showColumns{date},
			show_testtime   => $showColumns{testtime},
			show_problems   => $showColumns{problems},
			show_section    => $showColumns{section},
			show_recitation => $showColumns{recit},
			show_login      => $showColumns{login},
		);
		my %params = (%past_sort_methods, %display_options);
	    my @columnHdrs = ();
	    push( @columnHdrs, 'Name'.CGI::br().CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'first_name', %params})},$r->maketext('First')).
		  '&nbsp;&nbsp;&nbsp;'.CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'last_name', %params })},$r->maketext('Last')) );
	    push( @columnHdrs, CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'score', %params})},'Score') );
	    push( @columnHdrs, $r->maketext('Out Of') );
	    push( @columnHdrs, 'Date' ) if ( $showColumns{ 'date' } );
	    push( @columnHdrs, 'TestTime' ) if ( $showColumns{ 'testtime' } );
#	    push( @columnHdrs, CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'index', %params})},'Ind') )
#		if ( $showColumns{ 'index' } );
	    push( @columnHdrs, $r->maketext("Problems").CGI::br().$problem_header )
		if ( $showColumns{ 'problems' } );
	    push( @columnHdrs, CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'section', %params})},'Section') )
		if ( $showColumns{ 'section' } );
	    push( @columnHdrs, CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'recitation', %params})},'Recitation') )
		if ( $showColumns{ 'recit' } );
	    push( @columnHdrs, CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'user_id', %params})},'Login Name') )
		if ( $showColumns{ 'login' } );

	    print CGI::start_table({-class=>"progress-table", -border=>5,style=>'font-size:smaller'}),
	        CGI::Tr(CGI::td(  {-align=>'left'},
		    [ @columnHdrs ] ) ),
	    ;
	}

    # variables to keep track of versioned sets
	my $prevFullName = '';
	my $vNum = 1;
    # and to make formatting nice for students who haven't taken any tests
    #    (the total number of columns is two more than this; we want the 
    #    number that missing record information should span)

	my $numCol = 1;
	$numCol++ if $showColumns{'date'};
	$numCol++ if $showColumns{'testtime'};
	$numCol++ if $showColumns{'problems'};

	foreach my $rec (@augmentedUserRecords) {
		my $fullName = join("", $rec->{first_name}," ", $rec->{last_name});
		my $email    = $rec->{email_address}; 
		my $twoString  = $rec->{twoString};
		if ( ! $setIsVersioned ) {
		    print CGI::Tr({},
			CGI::td({},CGI::a({-href=>$rec->{act_as_student}},$fullName), CGI::br(), CGI::a({-href=>"mailto:$email"},$email)),
			CGI::td(wwRound(2,$rec->{score}) ), # score
			CGI::td($rec->{total}), # out of 
#			CGI::td(sprintf("%0.0f",100*($rec->{index}) )),   # indicator
			CGI::td($rec->{problemString}), # problems
			CGI::td($self->nbsp($rec->{section})),
			CGI::td($self->nbsp($rec->{recitation})),
			CGI::td($rec->{user_id}),			
		    );
		} else {
            # we separate versioned sets so that we can restrict what columns
            # we show
		    # if total is 'n/a', then it's a user who hasn't taken
		    #    any tests, which we treat separately
			if ( $rec->{total} ne 'n/a' ) {
				my @cols = ();
				# make make versioned sets' name format nicer
				my $nameEntry = '';
				if ( $fullName eq $prevFullName ) {
					$vNum++;
					$nameEntry = "(v$vNum)";
				} else {
					$nameEntry = CGI::a({-href=>$rec->{act_as_student}},$fullName) . 
						($setIsVersioned && ! $showBestOnly ? ' (v1)':' ') .
						CGI::br() . CGI::a({-href=>"mailto:$email"},$email);
					$vNum = 1;
					$prevFullName = $fullName;
				}
		    
				# build columns to show
				push(@cols, $nameEntry, 
				     wwRound(2,$rec->{score}),
				     $rec->{total});
				push(@cols, $self->nbsp($rec->{date})) 
				    if ($showColumns{'date'});
				push(@cols, $self->nbsp($rec->{testtime})) 
				    if ($showColumns{'testtime'});
#				push(@cols, sprintf("%0.0f",$rec->{index})) 
#				    if ($showColumns{'index'});
				push(@cols, $self->nbsp($rec->{problemString}))
				    if ($showColumns{'problems'});
				push(@cols, $self->nbsp($rec->{section})) 
				    if ($showColumns{'section'});
				push(@cols, $self->nbsp($rec->{recitation})) 
				    if ($showColumns{'recit'});
				push(@cols, $rec->{user_id}) if ($showColumns{'login'});
				print CGI::Tr( CGI::td( [ @cols ] ) );
			} else {
				my @cols = ( CGI::td( $fullName ),
					     CGI::td( $rec->{score} ),
					     CGI::td({colspan=>$numCol},
						     CGI::em($self->nbsp("No tests taken."))) );
				push(@cols, 
				     CGI::td($self->nbsp($rec->{section})))
					if ( $showColumns{'section'} );
				push(@cols, 
				     CGI::td($self->nbsp($rec->{recitation})))
					if ( $showColumns{'recit'} );
				push(@cols, 
				     CGI::td($self->nbsp($rec->{user_id})))
					if ( $showColumns{'login'} );
				print CGI::Tr(@cols);
			}
		}
	}

	print CGI::end_table();

	return "";
}

#############################################################
# Grading utilities
#############################################################


# 			########################################
# 			# Notes for factoring the calculation in this loop.
# 			#
# 			# Inputs include:
# 			#   @problemRecords  
# 			# returns
# 			#   $num_of_attempts
# 			#   $status
# 			# updates
# 			#   $number__studofents_attempting_problem{$probID}++;
# 			#   @{ $attempts_list_for_problem{$probID} }   
# 			#   $number_of_attempts_for_problem{$probID}
# 			#   $total_num_of_attempts_for_set
# 			#   $correct_answers_for_problem{$probID}   
# 			#    
# 			#   $string (formatting output)
# 			#   $twoString (more formatted output)
# 			#   $longtwo (a combination of $string and $twostring)
# 			#   $total
# 			#   $totalRight
# 			###################################

###############################################################
# requires = grade_set( $db, $set, $setName, $studentName, $setIsVersioned);
# returns   my ($status, 
#            $longStatus, 
#            $string,
#            $twoString, 
#            $totalRight,
#            $total, 
#            $num_of_attempts, 
#            $num_of_problems) = grade_set(...);
#########################

sub grade_set {

        my ($db, $set, $setName, $studentName, $setIsVersioned,
        $rh_number_of_students_attempting_problem,
        $rh_attempts_list_for_problem,
        $rh_number_of_attempts_for_problem,
        $rh_problemData,
        $rh_total_num_of_attempts_for_set,
        $rh_correct_answers_for_problem
        ) = @_;

        my $setID = $set->set_id();  #FIXME   setName and setID should be the same

		my $status = 0;
		my $longStatus = '';
		my $class     = '';
		my $string     = '';
		my $twoString  = '';
		my $totalRight = 0;
		my $total      = 0;
		my $num_of_attempts = 0;
	
		debug("Begin collecting problems for set $setName");
		# DBFIXME: to collect the problem records, we have to know 
		#    which merge routines to call.  Should this really be an 
		#    issue here?  That is, shouldn't the database deal with 
		#    it invisibly by detecting what the problem types are?  
		#    oh well.
		
		my @problemRecords = $db->getAllMergedUserProblems( $studentName, $setID );
		my $num_of_problems  = @problemRecords || 0;
		if ( $setIsVersioned ) {
			@problemRecords =  $db->getAllMergedProblemVersions( $studentName, $setID, $set->version_id );
		}
		
		
	# for jitar sets we only use the top level problems
	if ($set->assignment_type && $set->assignment_type eq 'jitar') {
	    my @topLevelProblems;
	    foreach my $problem (@problemRecords) {
		my @seq = jitar_id_to_seq($problem->problem_id);
		push @topLevelProblems, $problem if ($#seq == 0);
	    }
	    
	    @problemRecords = @topLevelProblems;
	}
		
	debug("End collecting problems for set $setName");

	####################
	# Resort records
	#####################
		@problemRecords = sort {$a->problem_id <=> $b->problem_id } @problemRecords;

#    		
# 		# for gateway/quiz assignments we have to be careful about 
# 		#    the order in which the problems are displayed, because
# 		#    they may be in a random order
# 		if ( $set->problem_randorder ) {
# 			my @newOrder = ();
# 			my @probOrder = (0..$#problemRecords);
# 			# we reorder using a pgrand based on the set psvn
# 			my $pgrand = PGrandom->new();
# 			$pgrand->srand( $set->psvn );
# 			while ( @probOrder ) { 
# 				my $i = int($pgrand->rand(scalar(@probOrder)));
# 				push( @newOrder, $probOrder[$i] );
# 				splice(@probOrder, $i, 1);
# 			}
# 			# now $newOrder[i] = pNum-1, where pNum is the problem
# 			#    number to display in the ith position on the test
# 			#    for sorting, invert this mapping:
# 			my %pSort = map {($newOrder[$_]+1)=>$_} (0..$#newOrder);
# 
# 			@problemRecords = sort {$pSort{$a->problem_id} <=> $pSort{$b->problem_id}} @problemRecords;
# 		}
    
    #######################################################
	# construct header
    
		foreach my $problemRecord (@problemRecords) {
			my $prob = $problemRecord->problem_id;
			
			unless (defined($problemRecord) ){
				# warn "Can't find record for problem $prob in set $setName for $student";
			# FIXME check the legitimate reasons why a student record might not be defined
				next;
			}
			
			$status           = $problemRecord->status || 0;

			if ($set->assignment_type eq 'jitar') {
			    $status = jitar_problem_adjusted_status($problemRecord,$db);
			}

			my $attempted     = $problemRecord->attempted;
			my $num_correct   = $problemRecord->num_correct || 0;
			my $num_incorrect = $problemRecord->num_incorrect   || 0;
			$num_of_attempts  = $num_correct + $num_incorrect;
	
#######################################################
			# This is a fail safe mechanism that makes sure that
			# the problem is marked as attempted if the status has
			# been set or if the problem has been attempted
			# DBFIXME this should happen in the database layer, not here!
			if (!$attempted && ($status || $num_of_attempts)) {
				$attempted = 1;
				$problemRecord->attempted('1');
				# DBFIXME: this is another case where it 
				#    seems we shouldn't have to check for 
				#    which routine to use here...
				if ( $setIsVersioned ) {
					$db->putProblemVersion($problemRecord);
				} else {
					$db->putUserProblem($problemRecord );
				}
			}
######################################################			

			# sanity check that the status (score) is 
			# between 0 and 1
			my $valid_status = ($status>=0 && $status<=1)?1:0;

			###########################################
			# Determine the string $longStatus which 
			# will display the student's current score
			###########################################

			if (!$attempted){
				$longStatus     = '.';
			} elsif   ($valid_status) {
				$longStatus     = 100*wwRound(2,$status);
				$longStatus='C' if ($longStatus==100);
			} else	{
				$longStatus 	= 'X';
			}
		
                        $class = ($longStatus eq 'C')?"correct": (($longStatus eq '.')?'unattempted':'');
                        $string      .= '<span class="'.$class.'">'.threeSpaceFill($longStatus).'</span>';
			$twoString      .= threeSpaceFill($num_incorrect);
			my $probValue   =  $problemRecord->value;
			$probValue      =  1 unless defined($probValue) and $probValue ne "";  # FIXME?? set defaults here?
			$total          += $probValue;
			$totalRight     += $status*$probValue if $valid_status;
				
# 				
# 			# initialize the number of correct answers 
# 			# for this problem if the value has not been 
# 			# defined.
# 			$correct_answers_for_problem{$probID} = 0 
# 				unless defined($correct_answers_for_problem{$probID});
			
				
		# add on the scores for this problem
			if (defined($rh_correct_answers_for_problem ) ) {  #skip this if we are not updating records
			    my $probID          = $problemRecord->problem_id;
				$rh_correct_answers_for_problem->{$probID} = 0  	unless defined($rh_correct_answers_for_problem->{$probID});
				if (defined($attempted) and $attempted) {
					$rh_number_of_students_attempting_problem->{$probID}++;
					push( @{ $rh_attempts_list_for_problem->{$probID} } ,     $num_of_attempts);
					$rh_number_of_attempts_for_problem->{$probID}          += $num_of_attempts;
					$rh_problemData->{$probID}                              = $num_incorrect;
					$$rh_total_num_of_attempts_for_set                     += $num_of_attempts;
					$rh_correct_answers_for_problem->{$probID}             += $status;
				}
			}
		
		}  # end of problem record loop

		$totalRight = wwRound(2,$totalRight);  # round the final total	

		return($status,  
			   $longStatus, 
			   $string,
			   $twoString, 
			   $totalRight,
			   $total, 
			   $num_of_attempts, 
			   $num_of_problems			
		);
}
#################################
# Utility function NOT a method
#################################
sub threeSpaceFill {
	my $num = shift @_ || 0;

	if (length($num)<=1) {return "$num".'&nbsp;&nbsp;';}
	elsif (length($num)==2) {return "$num".'&nbsp;';}
	else {return "## ";}
}


1;
