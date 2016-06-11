################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/GradeBook.pm,v 1.36 2008/06/19 19:34:31 glarose Exp $
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

package WeBWorK::ContentGenerator::Instructor::GradeBook;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::GradeBook - Display Student Progress.

=cut

#TODO:  replace user=admin with user=...
use strict;
use warnings;
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::ContentGenerator::Grades;
use WeBWorK::ContentGenerator::Instructor::StudentProgress;
use WeBWorK::Utils::SortRecords qw/sortRecords/;
use WeBWorK::Utils::Grades qw/list_set_versions/;
use WeBWorK::DB; 


sub initialize {
	my $self     = shift; 
	my $r          = $self->{r};
	my $urlpath    = $r->urlpath;	
	my $db         = $self->{db};
	my $ce         = $self->{ce};
	my $authz      = $self->{authz};
	my $courseName = $urlpath->arg('courseID');
 	my $user       = $r->param('user'); 	
	my $deleteUserID = $r->param('deleteUser') || "";	
	my $deleteSetID = $r->param('deleteSet') || ""; 	

#Add modal to confirm delete in both cases.
	if($deleteUserID){
		$db->deleteUser($deleteUserID);
	} elsif ($deleteSetID) {
		$db->deleteGlobalSet($deleteSetID);
	}
 	
 	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
}


sub title { 
	my ($self) = @_;
	my $r = $self->r;
	my $authz = $r->authz;
	my $user = $r->param('user');
	
	# Check permissions
	return "" unless $authz->hasPermissions($user, "access_instructor_tools");

	my $string              = $r->maketext("GradeBook for")." ".$self->{ce}->{courseName}." ";
	return $string;
}

sub output_JS{
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/GradeBook/GradeBook.js"}), CGI::end_script();
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
		
	$self->index;
	

	return '';

}

sub getStudentScores {
	my ($self, $studentName) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	
	my $courseName = $ce->{courseName};
	my $studentRecord = $db->getUser($studentName); # checked
	die "record for user $studentName not found" unless $studentRecord;
	my $root = $ce->{webworkURLs}->{root};

######################################################################
# Get all sets (including versions of gateway quizzes) assigned to this user
######################################################################

	# first get all non-versioned-sets; listUserSets will return all 
	#    homework assignments, plus the template gateway sets.
	# DBFIXME use iterator instead of setIDs
	my @setIDs    = sort( $db->listUserSets($studentName) );
	# to figure out which of these are gateways (that is, versioned),
	#    we need to also have the actual (merged) set objects
	my @sets = $db->getMergedSets( map {[$studentName, $_]} @setIDs );
	# to be able to find the set objects later, make a handy hash
	my %setsByID = ( map {$_->set_id => $_} @sets );

######################################################
# before going through the table generating loop, find all the 
#    set versions for the sets in our list
#
# info for refactoring:
# input:  list of regular sets (from $db->getMergedSets(studentID, setID )
# input:  $db
# input: \%setsByID
# output: \%setVersionsByID  ---  a pointer to a list of version names.
# update: \%setsByID ---  indexed by full set name, value is the set record
# output: \@allSetIDs   -- full names of sets (the gateway template and the versioned tests)
#############################################
	my %setVersionsByID = ();
	my @allSetIDs = ();
	foreach my $set ( @sets ) {
		my $setName = $set->set_id();
		#
		# FIXME: Here, as in many other locations, we assume that
		#    there is a one-to-one matching between versioned sets
		#    and gateways.  we really should have two flags, 
		#    $set->assignment_type and $set->versioned.  I'm not 
		#    adding that yet, however, so this will continue to 
		#    use assignment_type...
		#
		if ( defined($set->assignment_type) && 
		     $set->assignment_type =~ /gateway/ ) { 
			my @vList = $db->listSetVersions($studentName,$setName);
			# we have to have the merged set versions to 
			#    know what each of their assignment types 
			#    are (because proctoring can change)
			my @setVersions = $db->getMergedSetVersions( map {[$studentName, $setName, $_]} @vList );

			# add the set versions to our list of sets
			foreach ( @setVersions ) { 
				$setsByID{$_->set_id . ",v" . $_->version_id} = $_; 
			}
			# flag the existence of set versions for this set
			$setVersionsByID{$setName} = [ @vList ];
			# and save the set names for display
			push( @allSetIDs, $setName );
			push( @allSetIDs, map { "$setName,v$_" } @vList );

		} else {
			push( @allSetIDs, $setName );
			$setVersionsByID{$setName} = "None";
		}
	}
	

	#########################################################################################
	my $fullName = join("", $studentRecord->first_name," ", $studentRecord->last_name);
	my $effectiveUser = $studentRecord->user_id();
	my $act_as_student_url = "$root/$courseName/?user=".$r->param("user").
			"&effectiveUser=$effectiveUser&key=".$r->param("key");

	
	# FIXME: why is the following not "print CGI::h3($fullName);"?  Hmm.
	#print CGI::h3($fullName ), 

	###############################################################
	#  Print table
	###############################################################

	# FIXME I'm assuming the problems are all the same
	# FIXME what does this mean?
	
	my @rows;
	my $max_problems=0;
	
	my @scores = ();	
	foreach my $setName (@allSetIDs)   {
		my $act_as_student_set_url = "$root/$courseName/$setName/?user=".$r->param("user").
			"&effectiveUser=$effectiveUser&key=".$r->param("key");
		my $student_grade_cell_edit_url = "$root/$courseName/instructor/sets2/$setName/?editForUser=$effectiveUser&user=admin&key=".$r->param("key");
		my $set = $setsByID{ $setName };
		my $setID = $set->set_id();  #FIXME   setName and setID should be the same

		# now, if the set is a template gateway set and there 
		#    are no versions, we acknowledge that the set exists
		#    and the student hasn't attempted it; otherwise, we 
		#    skip it and let the versions speak for themselves
		if ( defined( $set->assignment_type() ) &&
		     $set->assignment_type() =~ /gateway/ &&
		     ref( $setVersionsByID{ $setName } ) ) {
			if ( @{$setVersionsByID{$setName}} ) {
				next;
			} else {
				push( @rows, CGI::Tr({}, CGI::td(WeBWorK::ContentGenerator::underscore2nbsp($setID)), 
						     CGI::td({colspan=>4}, CGI::em("No versions of this assignment have been taken."))) );
				next;
			}
		}
		# if the set has hide_score set, then we need to skip printing
		#    the score as well
		if ( defined( $set->hide_score ) &&
		     ( ! $authz->hasPermissions($r->param("user"), "view_hidden_work") &&
		       ( $set->hide_score eq 'Y' || 
			 ($set->hide_score eq 'BeforeAnswerDate' && time < $set->answer_date) ) ) ) {
			push( @rows, CGI::Tr({}, CGI::td(WeBWorK::ContentGenerator::underscore2nbsp("${setID}_(test_" . $set->version_id . ")")), 
					     CGI::td({colspan=>4}, CGI::em("Display of scores for this set is not allowed."))) );
			next;
		}

		# otherwise, if it's a gateway, adjust the act-as url
		my $setIsVersioned = 0;
		if ( defined( $set->assignment_type() ) && 
		     $set->assignment_type() =~ /gateway/ ) {
			$setIsVersioned = 1;
			if ( $set->assignment_type() eq 'proctored_gateway' ) {
				$act_as_student_set_url =~ s/($courseName)\//$1\/proctored_quiz_mode\//;
			} else {
				$act_as_student_set_url =~ s/($courseName)\//$1\/quiz_mode\//;
			}
		}
	   ##############################################
	   # this segment requires @problemRecords, $db, $set
	   # and $studentName, $setName, 
	   ##############################################
       my ($status, 
           $longStatus, 
           $string,
           $twoString, 
           $totalRight,
           $total, 
           $num_of_attempts, 
           $num_of_problems);
           
          ($status, 
           $longStatus, 
           $string,
           $twoString, 
           $totalRight,
           $total, 
           $num_of_attempts, 
           $num_of_problems
           )   = grade_set( $db, $set, $setName, $studentName, $setIsVersioned);

# 		warn "status $status  longStatus $longStatus string $string twoString 
# 		      $twoString totalRight $totalRight, total $total num_of_attempts $num_of_attempts 
# 		      num_of_problems $num_of_problems setName $setName";

		
		# prettify versioned set display
		$setName =~ s/(.+),v(\d+)$/${1}_(test_$2)/;
	
		push @scores, CGI::td(CGI::a({-href=>$student_grade_cell_edit_url},sprintf("%0.2f",$totalRight)));
	
	}

	
	return @scores;
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
	my $root = $ce->{webworkURLs}->{root};		

	my @myUsers = @studentList;
#TODO: effectiveUser!!!
	my @studentRecords = $db->getUsers(@myUsers);
	my @sortedStudentRecords = sortRecords({fields=>[qw/last_name first_name user_id/]}, @studentRecords);
		
	my @setLinks      = ();
	my @studentLinks  = (); 
	foreach my $set (@setList) {		
		my $setProgressUrl = "$root/$courseName/instructor/progress/set/$set/?user=admin&key=".$r->param("key");
		my $setEditUrl = "$root/$courseName/instructor/sets2/?user=admin&effectiveUser=admin&key=".$r->param("key")."&editMode=1&visible_sets=$set		";
		my $setDeleteUrl = "$root/$courseName/instructor/gradebook/?deleteSet=$set&user=admin&key=".$r->param("key");		
	    my $prettySetID = $set;
	    $prettySetID =~ s/_/ /g;
		push @setLinks, CGI::div({-class=>"dropdown"},
			CGI::div({-class=>"btn btn-default dropdown-toggle", "data-toggle"=>"dropdown"}, $prettySetID),
			CGI::ul({-class=>"dropdown-menu"},
				CGI::li(CGI::a({-href=>$setProgressUrl},"Progress")),
				CGI::li(CGI::a({-href=>$setEditUrl},"Edit")),
				CGI::li(CGI::a({-href=>$setDeleteUrl},"Delete"))
				)
			);


	}

	foreach my $studentRecord (@sortedStudentRecords) {
		my $first_name = $studentRecord->first_name;
		my $last_name = $studentRecord->last_name;
		my $user_id = $studentRecord->user_id;
		my $studentProgressUrl = "$root/$courseName/instructor/progress/student/$user_id/?user=admin&key=".$r->param("key");
		my $studentEditUrl = "$root/$courseName/instructor/users2/?".$r->param("key")."user=admin&effectiveUser=admin&editMode=1&visible_users=$user_id		";
		my $studentDeleteUrl = "$root/$courseName/instructor/gradebook/?user=admin&deleteUser=$user_id&key=".$r->param("key");			

#Add a confirm delete.
		push @studentLinks, CGI::Tr({},CGI::td(
			CGI::div({-class=>"dropdown"},
			CGI::div({-class=>"btn btn-default dropdown-toggle btn-block", "data-toggle"=>"dropdown"}, "  $last_name, $first_name  ($user_id)" ),
			CGI::ul({-class=>"dropdown-menu"},
				CGI::li(CGI::a({-href=>$studentProgressUrl},"Progress")),
				CGI::li(CGI::a({-href=>$studentEditUrl},"Edit")),
				CGI::li(CGI::a({-href=>"", -class=>"delete-student"},"Delete"))
				)
			)	
			, $self->getStudentScores($studentRecord->user_id)));	
				                                                     
	}
	print join("",
		CGI::start_table({-class=>"gradebook table-striped",-border=>2}),
		CGI::Tr({},
			CGI::td({-class=>"column-name"},'Student'),
			CGI::td({-class=>"column-set",-valign=>'top'}, [@setLinks]) 
		),
		@studentLinks,
		CGI::end_table(),
	);
	
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
				$longStatus     =  int(100*$status+.5) ;
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
			$totalRight     += round_score($status*$probValue) if $valid_status;
				
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

sub round_score{
	return shift;
}

1;