################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/StudentProgress.pm,v 1.15 2005/06/02 18:22:58 apizer Exp $
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
use CGI qw();
use WeBWorK::Utils qw(readDirectory list2hash max sortByName);
use WeBWorK::DB::Record::Set;
use WeBWorK::ContentGenerator::Grades;
use WeBWorK::Utils::SortRecords qw/sortRecords/;


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
	my $string              = "Student Progress for ".$self->{ce}->{courseName}." ";
	if ($type eq 'student') {
		$string             .= "student ".$self->{studentName};
	} elsif ($type eq 'set' ) {
		$string             .= "set   ".$self->{setName};
		$string             .= ".&nbsp;&nbsp;&nbsp; Due ". $self->formatDateTime($self->{set_due_date});
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
	
	my $progress     = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::StudentProgress", 
	                                        courseID => $courseID);
	
	print CGI::start_ul({class=>"LinksMenu"});
	print CGI::start_li();
	print CGI::span({style=>"font-size:larger"}, CGI::a({href=>$self->systemLink($progress)}, 'Student&nbsp;Progress'));
	print CGI::start_ul();
	
	foreach my $setID (@setIDs) {
		my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::StudentProgress",
			courseID => $courseID, setID => $setID,statType => 'set',);
		print CGI::li(CGI::a({href=>$self->systemLink($problemPage)}, underscore2nbsp($setID)));
	}
	
	print CGI::end_ul();
	print CGI::end_li();
	print CGI::end_ul();
	
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
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to access instructor tools"))
		unless $authz->hasPermissions($user, "access_instructor_tools");
		
	if ($type eq 'student') {
		my $studentName  = $self->{studentName};
		
		my $studentRecord = $db->getUser($studentName); # checked
			die "record for user $studentName not found" unless $studentRecord;
		
		my $fullName = join("", $studentRecord->first_name," ", $studentRecord->last_name);
 
        my $courseHomePage     = $urlpath->new(type  => 'set_list',
												args => {courseID   => $courseName}
		);
		my $act_as_student_url = $self->systemLink($courseHomePage,
												   params => { effectiveUser => $studentName }
		);

		my $email    = $studentRecord->email_address;
		print  
			CGI::a({-href=>"mailto:$email"},$email),CGI::br(),
			"Section: ", $studentRecord->section, CGI::br(),
			"Recitation: ", $studentRecord->recitation,CGI::br(),
			'Act as: ',
			CGI::a({-href=>$act_as_student_url},$studentRecord->user_id);	
		    WeBWorK::ContentGenerator::Grades::displayStudentStats($self,$studentName);
		
		# The table format has been borrowed from the Grades.pm module
	} elsif( $type eq 'set') {
		my $setName = $self->{setName};
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
	my @myUsers;
#	my @studentRecords = $db->getUsers;  #this is never used
	my $user = $r->param("user");
	
	my (@viewable_sections, @viewable_recitations);
	if (defined @{$ce->{viewable_sections}->{$user}})
		{@viewable_sections = @{$ce->{viewable_sections}->{$user}};}
	if (defined @{$ce->{viewable_recitations}->{$user}})
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
	
	my @studentRecords = $db->getUsers(@myUsers);
	my @sortedStudentRecords = sortRecords({fields=>[qw/last_name first_name user_id/]}, @studentRecords);
		
	my @setLinks      = ();
	my @studentLinks  = (); 
	foreach my $set (@setList) {
	    my $setStatisticsPage   = $urlpath->newFromModule($urlpath->module,
	                                                      courseID => $courseName,
	                                                      statType => 'set',
	                                                      setID    => $set
	    );
		push @setLinks, CGI::a({-href=>$self->systemLink($setStatisticsPage) }, underscore2nbsp($set));
	}
	
	foreach my $studentRecord (@sortedStudentRecords) {
		my $first_name = $studentRecord->first_name;
		my $last_name = $studentRecord->last_name;
		my $user_id = $studentRecord->user_id;
		my $userStatisticsPage  = $urlpath->newFromModule($urlpath->module,
	                                                      courseID => $courseName,
	                                                      statType => 'student',
	                                                      userID   => $user_id
	    );

		push @studentLinks, CGI::a({-href=>$self->systemLink($userStatisticsPage,
		                                                     prams=>{effectiveUser => $studentRecord->user_id}
		                                                     )},"  $first_name $last_name ($user_id)" ),;	
	}
	print join("",
		CGI::start_table({-border=>2, -cellpadding=>20}),
		CGI::Tr(
			CGI::td({-valign=>'top'}, 
				CGI::h3({-align=>'center'},'View student progress by set'),
				CGI::ul(  CGI::li( [@setLinks] ) ), 
			),
			CGI::td({-valign=>'top'}, 
				CGI::h3({-align=>'center'},'View student progress by student'),
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
	my $setRecord        = $self->{setRecord};
	my $root             = $ce->{webworkURLs}->{root};
	
	my $setStatsPage     = $urlpath->newFromModule($urlpath->module,courseID=>$courseName,statType=>'sets',setID=>$setName);
	my $primary_sort_method_name = $r->param('primary_sort');
	my $secondary_sort_method_name = $r->param('secondary_sort'); 
	my $ternary_sort_method_name = $r->param('ternary_sort');  

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
		return 	lc($a->{last_name}) cmp lc($b->{last_name}) if $sort_method_name eq 'last_name';
		return 	lc($a->{first_name}) cmp lc($b->{first_name}) if $sort_method_name eq 'first_name';
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
    my $GlobalSet = $db->getGlobalSet($setName);
    my $setIsVersioned = 
	( defined($GlobalSet->assignment_type()) && 
	  $GlobalSet->assignment_type() =~ /gateway/ ) ? 1 : 0;

# reset column view options based on whether the set is versioned and, if so,
# the input parameters
    if ( $setIsVersioned ) {
  # the returning parameter lets us set defaults for versioned sets
	my $ret = $r->param('returning');
	$showColumns{'date'} = $ret ? $r->param('show_date') : 1;
	$showColumns{'testtime'} = $ret ? $r->param('show_testtime') : 1;
	$showColumns{'index'} = $ret ? $r->param('show_index') : 0;
	$showColumns{'problems'} = $ret ? $r->param('show_problems') : 0;
	$showColumns{'section'} = $ret? $r->param('show_section') : 0;
	$showColumns{'recit'} = $ret ? $r->param('show_recitation') : 0;
	$showColumns{'login'} = $ret ? $r->param('show_login') : 0;
	$showBestOnly = $ret ? $r->param('show_best_only') : 0;
    }

###############################################################
#  Print tables
###############################################################
	
	my $max_num_problems  = 0;
	# get user records
	$WeBWorK::timer->continue("Begin obtaining user records for set $setName") if defined($WeBWorK::timer);
	my @userRecords  = $db->getUsers(@studentList);
	$WeBWorK::timer->continue("End obtaining user records for set $setName") if defined($WeBWorK::timer);
    $WeBWorK::timer->continue("begin main loop") if defined($WeBWorK::timer);
 	my @augmentedUserRecords    = ();
 	my $number_of_active_students;

## Edit to filter out students
#
	my @myUsers;
	my $ActiveUser = $r->param("user");
	my (@viewable_sections, @viewable_recitations);
	if (defined @{$ce->{viewable_sections}->{$user}})
		{@viewable_sections = @{$ce->{viewable_sections}->{$user}};}
	if (defined @{$ce->{viewable_recitations}->{$user}})
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
		my $student = $studentRecord->user_id;
		next if $studentRecord->last_name =~/^practice/i;  # don't show practice users
		next if $studentRecord->status !~/C/;              # don't show dropped students FIXME
		$number_of_active_students++;

# build list of versioned sets for this student user
	    my @allSetNames = ();
	    if ( $setIsVersioned ) {
		my $numVersions = $db->getUserSetVersionNumber($student,$setName);
		for ( my $i=1; $i<=$numVersions; $i++ ) { 
		    $allSetNames[$i-1] = "$setName,v$i";
		}
	    } else {
		@allSetNames = ( "$setName" );
	    }

  # for versioned sets, we might be keeping only the high score
		my $maxScore = -1;
		my $max_hash = {};
  # make this global to the student loop (there was a reason for this for
  # versioned sets, at least, though I'm not seeing it now -glr)
		my $act_as_student_url = '';

	  foreach my $sN ( @allSetNames ) {

	    my $status          = 0;
	    my $attempted       = 0;
	    my $longStatus      = '';
	    my $string          = '';
	    my $twoString       = '';
	    my $totalRight      = 0;
	    my $total           = 0;
		my $total_num_of_attempts_for_set = 0;
		my %h_problemData   = ();
		my $probNum         = 0;
		
		$WeBWorK::timer->continue("Begin obtaining problem records for user $student set $setName") if defined($WeBWorK::timer);
		
		my @problemRecords = sort {$a->problem_id <=> $b->problem_id } $db->getAllUserProblems( $student, $sN );
		$WeBWorK::timer->continue("End obtaining problem records for user $student set $setName") if defined($WeBWorK::timer);
		my $num_of_problems = @problemRecords;
		$max_num_problems = ($max_num_problems>= $num_of_problems) ? $max_num_problems : $num_of_problems;
	   ########################################
		# Notes for factoring the calculation in this loop.
		#
		# Inputs include:
		# 
		#
		# @problemRecords  
		# returns
		#       $num_of_attempts
		#       $status
		# updates
		#     	$number_of_students_attempting_problem{$probID}++;
		# 		@{ $attempts_list_for_problem{$probID} }   
		# 		$number_of_attempts_for_problem{$probID}          
		# 		$total_num_of_attempts_for_set                    
		# 		$correct_answers_for_problem{$probID}   
		#    
		#       $string (formatting output)
		#       $twoString (more formatted output)
                #       $longtwo (a combination of $string and $twostring)
		#       $total
		#       $totalRight
		###################################
   
		foreach my $problemRecord (@problemRecords) {
			next unless ref($problemRecord);
				# warn "Can't find record for problem $prob in set $setName for $student";
				# FIXME check the legitimate reasons why a student record might not be defined
			####################################################################
			# Grab data from the database
			####################################################################
			# It's possible that $problemRecord->num_correct or $problemRecord->num_correct
			# or $problemRecord->status is an empty 
			# or blank string instead of 0.  The || clause fixes this and prevents 
			# warning messages in the comparisons below.
			
			my $probID             = $problemRecord->problem_id;
			my $attempted          = $problemRecord->attempted;
			my $num_correct        = $problemRecord->num_correct     || 0;
			my $num_incorrect      = $problemRecord->num_incorrect   || 0;
			my $num_of_attempts    = $num_correct + $num_incorrect;
			
		    # initialize the number of correct answers for this problem 
		    # if the value has not been defined.
	        $correct_answers_for_problem{$probID}  = 0 unless defined($correct_answers_for_problem{$probID});
		
	        
			my $probValue          = $problemRecord->value;   ## This doesn't work - Fix it
			# set default problem value here
			$probValue             = 1 unless defined($probValue) and $probValue ne "";  # FIXME?? set defaults here?
			
			my $status             = $problemRecord->status          || 0;

			# sanity check that the status (score) is between 0 and 1
	        my $valid_status       = ($status >= 0 and $status <=1 ) ? 1 : 0;
	        
	        ###################################################################
	        # Determine the string $longStatus which will display the student's current score
	        ###################################################################
	        my $longStatus = '';
			if (!$attempted){
				$longStatus     = '.';
			} elsif   ($valid_status) {
				$longStatus     = int(100*$status+.5);
                 # we change $longStatus to give more reasonable output for
                 #   gateways (actually all versioned sets; this might get us
                 #   into trouble at some later date).
				if ( $longStatus == 100 ) {
				    $longStatus = 'C';
				} elsif ( $setIsVersioned ) {
				    $longStatus = ( $longStatus == 0 ) ? 
					'X' : $longStatus; 
				}
			} else	{
				$longStatus 	= 'X';
			}
			
			$string          .= threeSpaceFill($longStatus);
			$twoString       .= threeSpaceFill($num_incorrect);

			$total           += $probValue;
			$totalRight      += round_score($status*$probValue) if $valid_status;
			
			 # add on the scores for this problem
			if (defined($attempted) and $attempted) {
				$number_of_students_attempting_problem{$probID}++;
				push( @{ $attempts_list_for_problem{$probID} } ,     $num_of_attempts);
				$number_of_attempts_for_problem{$probID}             += $num_of_attempts;
				$h_problemData{$probID}                               = $num_incorrect;
				$total_num_of_attempts_for_set                       += $num_of_attempts;
				$correct_answers_for_problem{$probID}                += $status;
			}
			
		    }  # end of problem record loop

    # for versioned tests we might be displaying the test date and test time
	    my $dateOfTest = '';
	    my $testTime = '';
        # annoyingly, this is a set property, so get the set
	    if ( $setIsVersioned && 
		 ( $showColumns{'date'} || $showColumns{'testtime'} ) ) {
		my @userSet = 
		    $db->getMergedVersionedSets( [ $studentRecord->user_id, $setName, $sN ] );
		if ( defined( $userSet[0] ) ) {  # if this isn't defined, something's wrong
		    $dateOfTest = 
			localtime( $userSet[0]->version_creation_time() );
		    my $gradeTime = '';
		    if ( defined( $userSet[0]->version_last_attempt_time() ) &&
			 $userSet[0]->version_last_attempt_time() ) {
			$testTime = ( $userSet[0]->version_last_attempt_time() -
				      $userSet[0]->version_creation_time() ) / 
				      60; 
			$testTime = sprintf("%3.1f min", $testTime);
		    } else {
			$testTime = 'time limit exceeded';
		    }
		} else {
		    $dateOfTest = '???';
		    $testTime = '???';
		}
	    }
		
		
		$act_as_student_url = $self->systemLink($urlpath->new(type=>'set_list',args=>{courseID=>$courseName}),
		                                           params=>{effectiveUser => $studentRecord->user_id}
		);
		my $email              = $studentRecord->email_address;
		# FIXME  this needs formatting

    # change to give better output for gateways; this just reports the result
    # for each problem, not the number of attempts.  if versioned sets are 
    # used where multiple attempts are allowed per version this may not be 
    # as desirable
 	        my $longtwo = ( $setIsVersioned ) ? $string : 
		    "$string\n$twoString";
		
		my $avg_num_attempts = ($num_of_problems) ? $total_num_of_attempts_for_set/$num_of_problems : 0;
		my $successIndicator = ($avg_num_attempts && $total) ? ($totalRight/$total)**2/$avg_num_attempts : 0 ;
		
		my $temp_hash         = {         user_id        => $studentRecord->user_id,
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
	    if ( ! %$max_hash ) {  # then we have no tests---e.g., for proctors
		next;              
        # if we could exclude proctors and instructors, we might want to keep 
        # these, e.g., with something like the following
	#	$max_hash = { user_id => $studentRecord->user_id(),
	#		      last_name => $studentRecord->last_name(),
	#		      first_name => $studentRecord->first_name(),
	#		      score => 0,
	#		      total => 'n/a',
	#		      index => 0,
	#		      section => $studentRecord->section(),
	#		      recitation => $studentRecord->recitation(),
	#		      problemString => 'no attempt recorded',
	#		      act_as_student => $act_as_student_url,
	#		      email_address => $studentRecord->email_address(),
	#		      problemData => {},
	#		      date => 'none',
	#		      testtime => 'none',
	#		  }
	    }

	    push( @index_list, $max_hash->{index} );
	    push( @score_list, 
		  ($max_hash->{total} && $max_hash->{total} ne 'n/a') ? 
		  $max_hash->{score}/$max_hash->{total} : 0 );
	    push( @augmentedUserRecords, $max_hash );
		                                
	}

        } # this closes the loop through all student records
	
	$WeBWorK::timer->continue("end mainloop") if defined($WeBWorK::timer);
	
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
	my @list_problems = sort {$a<=> $b } $db->listGlobalProblems($setName );
	$problem_header = '<pre>'.join("", map {&threeSpaceFill($_)}  @list_problems  ).'</pre>';

# changes for gateways/versioned sets here.  in this case we allow instructors
# to modify the appearance of output, which we do with a form.  so paste in the
# form header here, and make appropriate modifications
        my $verSelectors = '';
	if ( $setIsVersioned ) {
	    print CGI::start_form({'method' => 'post', 
				   'action' => $self->systemLink($urlpath,
								 authen=>0),
				   'name' => 'StudentProgress'});
	    print $self->hidden_authen_fields();

#	    $verSelectors = CGI::p({'style'=>'background-color:#eeeeee;color:black;'},
	    print CGI::p({'style'=>'background-color:#eeeeee;color:black;'},
	        "Display options: Show ",
		CGI::hidden(-name=>'returning', -value=>'1'),
		CGI::checkbox(-name=>'show_best_only', -value=>'1', 
			      -checked=>$showBestOnly, 
			      -label=>' only best scores; '),
		CGI::checkbox(-name=>'show_index', -value=>'1', 
			      -checked=>$showColumns{'index'},
			      -label=>' success indicator; '),
		CGI::checkbox(-name=>'show_date', -value=>'1', 
			      -checked=>$showColumns{'date'},
			      -label=>' test date; '),
		CGI::checkbox(-name=>'show_testtime', -value=>'1', 
			      -checked=>$showColumns{'testtime'},
			      -label=>' test time; '),
		CGI::checkbox(-name=>'show_problems', -value=>'1', 
			      -checked=>$showColumns{'problems'},
			      -label=>'problems;'), "\n", CGI::br(), "\n",
		CGI::checkbox(-name=>'show_section', -value=>'1', 
			      -checked=>$showColumns{'section'}, 
			      -label=>' section #; '),
		CGI::checkbox(-name=>'show_recitation', -value=>'1', 
			      -checked=>$showColumns{'recit'},
			      -label=>' recitation #; '),
		CGI::checkbox(-name=>'show_login', -value=>'1', 
			      -checked=>$showColumns{'login'}, 
			      -label=>'login'), "\n", CGI::br(), "\n",
		CGI::submit(-value=>'Update Display'),
	    );
	    print CGI::end_form();
	}

#####################################################################################
	print
#		CGI::br(),
		CGI::br(),
		CGI::p('A period (.) indicates a problem has not been attempted, a &quot;C&quot; indicates 
		a problem has been answered 100% correctly, and a number from 0 to 99 
		indicates the percentage of partial credit earned. The number on the 
		second line gives the number of incorrect attempts.  The success indicator,'
		,CGI::i('Ind'),', for each student is calculated as',
		CGI::br(),
		'100*(totalNumberOfCorrectProblems / totalNumberOfProblems)^2 / (AvgNumberOfAttemptsPerProblem)',CGI::br(),
		'or 0 if there are no attempts.'
		),
		CGI::br(),
		"Click on student's name to see the student's version of the homework set. &nbsp; &nbsp;&nbsp;
		Click heading to sort table. ",
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

	# continue with outputing of table
	if ( ! $setIsVersioned ) {
	    print
		CGI::start_table({-border=>5,style=>'font-size:smaller'}),
		CGI::Tr(CGI::td(  {-align=>'left'},
			['Name'.CGI::br().CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'first_name', %past_sort_methods})},'First').
			   '&nbsp;&nbsp;&nbsp;'.CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'last_name', %past_sort_methods })},'Last').CGI::br().
			   CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'email_address', %past_sort_methods })},'Email'),
			CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'score', %past_sort_methods})},'Score'),
			'Out'.CGI::br().'Of',
			CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'index', %past_sort_methods})},'Ind'),
			'Problems'.CGI::br().$problem_header,
			CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'section', %past_sort_methods})},'Section'),
			CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'recitation', %past_sort_methods})},'Recitation'),
			CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'user_id', %past_sort_methods})},'Login Name'),
			])

		),
		;
	} else {
	    my @columnHdrs = ();
	    push( @columnHdrs, 'Name'.CGI::br().CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'first_name', %past_sort_methods})},'First').
		  '&nbsp;&nbsp;&nbsp;'.CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'last_name', %past_sort_methods })},'Last') );
	    push( @columnHdrs, CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'score', %past_sort_methods})},'Score') );
	    push( @columnHdrs, 'Out'.CGI::br().'Of' );
	    push( @columnHdrs, 'Date' ) if ( $showColumns{ 'date' } );
	    push( @columnHdrs, 'TestTime' ) if ( $showColumns{ 'testtime' } );
	    push( @columnHdrs, CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'index', %past_sort_methods})},'Ind') )
		if ( $showColumns{ 'index' } );
	    push( @columnHdrs, 'Problems'.CGI::br().$problem_header )
		if ( $showColumns{ 'problems' } );
	    push( @columnHdrs, CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'section', %past_sort_methods})},'Section') )
		if ( $showColumns{ 'section' } );
	    push( @columnHdrs, CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'recitation', %past_sort_methods})},'Recitation') )
		if ( $showColumns{ 'recit' } );
	    push( @columnHdrs, CGI::a({"href"=>$self->systemLink($setStatsPage,params=>{primary_sort=>'user_id', %past_sort_methods})},'Login Name') )
		if ( $showColumns{ 'login' } );

	    print CGI::start_table({-border=>5,style=>'font-size:smaller'}),
	        CGI::Tr(CGI::td(  {-align=>'left'},
		    [ @columnHdrs ] ) ),
	    ;
	}

    # variables to keep track of versioned sets
	my $prevFullName = '';
	my $vNum = 1;

	foreach my $rec (@augmentedUserRecords) {
		my $fullName = join("", $rec->{first_name}," ", $rec->{last_name});
		my $email    = $rec->{email_address}; 
		my $twoString  = $rec->{twoString};
		if ( ! $setIsVersioned ) {
		    print CGI::Tr(
			CGI::td(CGI::a({-href=>$rec->{act_as_student}},$fullName), CGI::br(), CGI::a({-href=>"mailto:$email"},$email)),
			CGI::td( sprintf("%0.2f",$rec->{score}) ), # score
			CGI::td($rec->{total}), # out of 
			CGI::td(sprintf("%0.0f",100*($rec->{index}) )),   # indicator
			CGI::td($rec->{problemString}), # problems
			CGI::td($self->nbsp($rec->{section})),
			CGI::td($self->nbsp($rec->{recitation})),
			CGI::td($rec->{user_id}),			
		    );
		} else {
            # separate versioned sets so that we can restrict what columns
            # we show
		    my @cols = ();
            # revise names to make versioned sets' format nicer
		    my $nameEntry = '';
		    if ( $fullName eq $prevFullName ) {
			$vNum++;
			$nameEntry = CGI::span({-style=>"text-align:right;"}, 
					       "(v$vNum)");
		    } else {
			$nameEntry = 
			    CGI::a({-href=>$rec->{act_as_student}},$fullName) . 
			    ($setIsVersioned && ! $showBestOnly ? ' (v1)':' ') .
			    CGI::br() . CGI::a({-href=>"mailto:$email"},$email);
			$vNum = 1;
			$prevFullName = $fullName;
		    }
		    
	    # build columns to show
		    push(@cols, $nameEntry, sprintf("%0.2f",$rec->{score}),
			 $rec->{total});
		    push(@cols, $self->nbsp($rec->{date})) 
			if ($showColumns{'date'});
		    push(@cols, $self->nbsp($rec->{testtime})) 
			if ($showColumns{'testtime'});
		    push(@cols, sprintf("%0.0f",$rec->{index})) 
			if ($showColumns{'index'});
		    push(@cols, $self->nbsp($rec->{problemString}))
			if ($showColumns{'problems'});
		    push(@cols, $self->nbsp($rec->{section})) 
			if ($showColumns{'section'});
		    push(@cols, $self->nbsp($rec->{recitation})) 
			if ($showColumns{'recit'});
		    push(@cols, $rec->{user_id}) if ($showColumns{'login'});
		    
		    print CGI::Tr( CGI::td( [ @cols ] ) );
		}
	}

	print CGI::end_table();

	return "";
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
sub round_score{
	return shift;
}

sub underscore2nbsp {
	my $str = shift;
	$str =~ s/_/&nbsp;/g;
	return($str);
}

1;
