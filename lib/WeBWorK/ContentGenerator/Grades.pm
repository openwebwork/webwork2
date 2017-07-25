################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Grades.pm,v 1.35 2007/07/10 14:41:54 glarose Exp $
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

package WeBWorK::ContentGenerator::Grades;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Stats - Display statistics by user or
problem set.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Utils qw(readDirectory list2hash max jitar_id_to_seq jitar_problem_adjusted_status wwRound);
use WeBWorK::Localize;
sub initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	
 	my $userName = $r->param('user');
 	my $effectiveUserName = defined($r->param("effectiveUser") ) ? $r->param("effectiveUser") : $userName;
    $self->{userName} = $userName;
	$self->{studentName} = $effectiveUserName;
}

sub body {
	my ($self) = @_;
	
	$self->displayStudentStats($self->{studentName});
	
	print $self->scoring_info();
	
	return '';

}

############################################
# Borrowed from SendMail.pm and Instructor.pm
############################################

sub getRecord {
	my $self    = shift;
	my $line    = shift;
	my $delimiter   = shift;
	$delimiter       = ',' unless defined($delimiter);

        #       Takes a delimited line as a parameter and returns an
        #       array.  Note that all white space is removed.  If the
        #       last field is empty, the last element of the returned
        #       array is also empty (unlike what the perl split command
        #       would return).  E.G. @lineArray=&getRecord(\$delimitedLine).

        my(@lineArray);
        $line.=$delimiter;                              # add 'A' to end of line so that
                                                        # last field is never empty
        @lineArray = split(/\s*${delimiter}\s*/,$line);
        $lineArray[0] =~s/^\s*// if defined($lineArray[0]);                       # remove white space from first element
        @lineArray;
}

sub scoring_info {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	
	my $userName          = $r->param('effectiveUser') || $r->param('user');
	my $userID              = $r->param('user');
	my $ur                = $db->getUser($userName);
	my $emailDirectory    = $ce->{courseDirs}->{email};
	my $message_file = "report_grades.msg";
	my $filePath          = "$emailDirectory/$message_file";
	my $merge_file         = "report_grades_data.csv";
	my $delimiter            = ',';
	my $scoringDirectory    = $ce->{courseDirs}->{scoring};

	# get out if the files don't exist
	if (!(-e "$scoringDirectory/$merge_file" && -e "$filePath")) {
	  if ($r->authz->hasPermissions($userID, "access_instructor_tools")) {
	    return  $r->maketext('There is no additional grade information.  A message about additional grades can go in in ~[TMPL~]/email/[_1]. It is merged with the file ~[Scoring~]/[_2]. These files can be edited using the "Email" link and the "File Manager" link in the left margin.', $message_file, $merge_file);
	  } else {
	    return '';
	  }
	}
	
	my $rh_merge_data   = $self->read_scoring_file("$merge_file", "$delimiter");
	my $text;
	my $header = '';
	local(*FILE);
	if (-e "$filePath" and -r "$filePath") {
		open FILE, "$filePath" || return("Can't open $filePath"); 
		while ($header !~ s/Message:\s*$//m and not eof(FILE)) { 
			$header .= <FILE>; 
		}
	} else {
		return("There is no additional grade information. <br> The message file $filePath cannot be found.")
	}
	$text = join( '', <FILE>);
	close(FILE);
	
	my $status_name = $ce->status_abbrev_to_name($ur->status);
	$status_name = $ur->status unless defined $status_name;
	
	my $SID           = $ur->student_id;
	my $FN            = $ur->first_name;
	my $LN            = $ur->last_name;
	my $SECTION       = $ur->section;
	my $RECITATION    = $ur->recitation;
	my $STATUS        = $status_name;
	my $EMAIL         = $ur->email_address;
	my $LOGIN         = $ur->user_id;
	my @COL           = defined($rh_merge_data->{$SID}) ? @{$rh_merge_data->{$SID} } : ();
	unshift(@COL,"");			## this makes COL[1] the first column

	my $endCol        = @COL;
	# for safety, only evaluate special variables
	# FIXME /e is not required for simple variable interpolation
	my $msg = $text; 
	$msg =~ s/(\$PAR)/<p>/ge;
	$msg =~ s/(\$BR)/<br>/ge;
   
 	$msg =~ s/\$SID/$SID/ge;
 	$msg =~ s/\$LN/$LN/ge;
 	$msg =~ s/\$FN/$FN/ge;
 	$msg =~ s/\$STATUS/$STATUS/ge;
 	$msg =~ s/\$SECTION/$SECTION/ge;
 	$msg =~ s/\$RECITATION/$RECITATION/ge;
 	$msg =~ s/\$EMAIL/$EMAIL/ge;
 	$msg =~ s/\$LOGIN/$LOGIN/ge;
	if (defined($COL[1])) {		# prevents extraneous error messages.  
		$msg =~ s/\$COL\[(\-?\d+)\]/$COL[$1] if defined($COL[$1])/ge
	}
	else {						# prevents extraneous $COL's in email message 
		$msg =~ s/\$COL\[(\-?\d+)\]//g
	}
	
 	$msg =~ s/\r//g;
	$msg =~ s/\n/<br>/g;
	
	
 	$msg = CGI::div({class=>"additional-scoring-msg"}, CGI::h3($r->maketext("Scoring Message")), $msg);

	$msg .= CGI::div($r->maketext('This scoring message is generated from ~[TMPL~]/email/[_1]. It is merged with the file ~[Scoring~]/[_2]. These files can be edited using the "Email" link and the "File Manager" link in the left margin.', $message_file, $merge_file)) if ($r->authz->hasPermissions($userID, "access_instructor_tools"));
	return $msg;
}

sub displayStudentStats {
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
	print CGI::h3($fullName ), 

	###############################################################
	#  Print table
	###############################################################

	# FIXME I'm assuming the problems are all the same
	# FIXME what does this mean?
	
	my @rows;
	my $max_problems=0;
	my $courseTotal=0;
	my $courseTotalRight=0;
	
	foreach my $setName (@allSetIDs) {
	    my $set = $db->getGlobalSet($setName);
	    my $num_of_problems;
	    # For jitar sets we only display grades for top level problems
	    # so we need to count how many there are
	    if ($set && $set->assignment_type() eq 'jitar') {
		my @problemIDs = $db->listGlobalProblems($setName);
		foreach my $problemID (@problemIDs) {
		    my @seq = jitar_id_to_seq($problemID);
		    $num_of_problems++ if ($#seq == 0);
		}
	    } else {
		# for other sets we just count the number of problems. 
		$num_of_problems = $db->countGlobalProblems($setName);
	    }
	    $max_problems = ($max_problems<$num_of_problems)? $num_of_problems:$max_problems;
	}

	# variables to help compute gateway scores
	my $numGatewayVersions = 0;
	my $bestGatewayScore = 0;
	
	foreach my $setName (@allSetIDs)   {
		my $act_as_student_set_url = "$root/$courseName/$setName/?user=".$r->param("user").
			"&effectiveUser=$effectiveUser&key=".$r->param("key");
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
				push( @rows, CGI::Tr({}, CGI::td(WeBWorK::ContentGenerator::underscore2sp($setID)), 
						     CGI::td({colspan=>($max_problems+2)}, CGI::em("No versions of this assignment have been taken."))) );
				next;
			}
		}
		# if the set has hide_score set, then we need to skip printing
		#    the score as well
		if ( defined( $set->hide_score ) &&
		     ( ! $authz->hasPermissions($r->param("user"), "view_hidden_work") &&
		       ( $set->hide_score eq 'Y' || 
			 ($set->hide_score eq 'BeforeAnswerDate' && time < $set->answer_date) ) ) ) {
			push( @rows, CGI::Tr({}, CGI::td(WeBWorK::ContentGenerator::underscore2sp("${setID}_(test_" . $set->version_id . ")")), 
					     CGI::td({colspan=>($max_problems+2)}, CGI::em("Display of scores for this set is not allowed."))) );
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

		$string =~ s/&nbsp;/ /g;
		$twoString =~ s/&nbsp;/ /g;
		my @prob_scores = $string =~ /.{4}/g;
		my @prob_att = $twoString =~ /.{4}/g;

		my @cgi_prob_scores = ();

		my $show_problem_scores = 1;

		if ( defined( $set->hide_score_by_problem ) &&
		     ! $authz->hasPermissions($r->param("user"), "view_hidden_work")
		     && $set->hide_score_by_problem eq 'Y' )  {
		  $show_problem_scores = 0;
		}
		
		for (my $i = 0; $i < $max_problems; $i++) {
		  my $score = (defined($prob_scores[$i]) &&
		    $show_problem_scores) ? 
		      $prob_scores[$i] :  '&nbsp;';
		    my $class = '';
		    if ($score =~ /100\s*/) {
			$score = '100&nbsp;';
			$class = "correct";
		    } elsif ($score =~ /\.\s*/) {
			$score = '&nbsp;.&nbsp;&nbsp;';
			$class = "unattempted";
		    }
		    my $att = defined($prob_att[$i]) && $show_problem_scores ?
			$prob_att[$i] : '&nbsp;';

		    $cgi_prob_scores[$i] = CGI::td(
                              CGI::span({class=>$class},$score).
					CGI::br().
					$att);
		}

# 		warn "status $status  longStatus $longStatus string $string twoString 
# 		      $twoString totalRight $totalRight, total $total num_of_attempts $num_of_attempts 
# 		      num_of_problems $num_of_problems setName $setName";

		my $avg_num_attempts = ($num_of_problems) ? $num_of_attempts/$num_of_problems : 0;
		my $successIndicator = ($avg_num_attempts && $total) ? ($totalRight/$total)**2/$avg_num_attempts : 0 ;
		
		# get percentage correct
		my $totalRightPercent = 100*wwRound(2,$total ? $totalRight/$total : 0);
		my $class = '';
		if ($totalRightPercent == 0) {
		  $class = 'unattempted';
		} elsif ($totalRightPercent == 100) {
		  $class = 'correct';
		}

		# If its a gateway set then in order to mimic the scoring done
		# in Scoring Tools we need to use the best score a student had.
		# Otherwise we just add the set to the running course total
		if ($setIsVersioned) {
		  # prettify versioned set display
		  $setName =~ s/(.+),v(\d+)$/${1}_(test_$2)/;
		  my $gatewayName = $1;
		  my $currentVersion = $2;

		  # If we are just starting a new gateway then set variables
		  # to look for the max.  
		  if ($currentVersion == 1) {
		    $numGatewayVersions = $db->countSetVersions($studentName,$gatewayName);
		  }

		  if ($totalRight > $bestGatewayScore) {
		    $bestGatewayScore = $totalRight;
		  }
		  
		    # If its the last version then add the max to the course
		    # totals and reset variables;
		  if ($currentVersion == $numGatewayVersions) {
		    $courseTotal += $total;
		    $courseTotalRight += $bestGatewayScore;
		    $bestGatewayScore = 0;
		  }
		} else {		
		  $courseTotal += $total;
		  $courseTotalRight += $totalRight;
		}
		
		push @rows, CGI::Tr({},
			CGI::th({scope=>"row"},CGI::a({-href=>$act_as_student_set_url}, WeBWorK::ContentGenerator::underscore2sp($setName))),
			CGI::td(CGI::span({-class=>$class},$totalRightPercent.'%')),
			CGI::td(sprintf("%0.2f",$totalRight)), # score
			CGI::td($total), # out of 
			@cgi_prob_scores     # problems
			
		);
	
	}

	my $problem_header = "";
	foreach (1 .. $max_problems) {
		$problem_header .= CGI::th({scope=>'col'},
					   &fourSpaceFill($_));
	}
	
	my $table_header = join("\n",
#		CGI::start_table({-border=>5,style=>'font-size:smaller',-id=>"grades_table"}),
		CGI::start_table({style=>'font-size:smaller',-id=>"grades_table"}),
		CGI::Tr({},
			CGI::th({rowspan=>2,scope=>'col'},$r->maketext('Set')),
			CGI::th({rowspan=>2,scope=>'col'},$r->maketext('Percent')),
			CGI::th({rowspan=>2,scope=>'col'},$r->maketext('Score')),
			CGI::th({rowspan=>2,scope=>'col'},$r->maketext('Out Of')),
			CGI::th({colspan=>$max_problems,scope=>'col'},$r->maketext('Problems')
			)),
		CGI::Tr({}, $problem_header)
	);
		
	print $table_header;
	print @rows;

	#Print out a row giving course totals

	# get percentage correct
	my $totalRightPercent = 100*wwRound(2,$courseTotal ? $courseTotalRight/$courseTotal : 0);
	my $class = '';
	if ($totalRightPercent == 0) {
	  $class = 'unattempted';
	} elsif ($totalRightPercent == 100) {
	  $class = 'correct';
	}

	if ($ce->{showCourseHomeworkTotals}) {
	  print CGI::Tr({class=>"grades-course-total"}, CGI::th({scope=>'row'},$r->maketext("Homework Totals")),
			CGI::td(CGI::span({class=>"$class"},$totalRightPercent.'%')),
			CGI::td($courseTotalRight),
			CGI::td($courseTotal),
			CGI::td({colspan=>$max_problems},'&nbsp;'));
	}
	
	print CGI::end_table();
			
	return "";
}
################
# TASKS
###################

#  grading utility
# provides a formatted line for presenting grades (
###############################################################
# 17-2-motion-velocity 	0.00 	7 	0 	.  .  .  .  .  .  .  
#                                        0  0  0  0  0  0  0  
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
sub grade_set {
        
        my ($db, $set, $setName, $studentName, $setIsVersioned) = @_;

        my $setID = $set->set_id();  #FIXME   setName and setID should be the same

		my $status = 0;
		my $longStatus = '';
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
		my $max_problems     = defined($num_of_problems) ? $num_of_problems : 0; 

		if ( $setIsVersioned ) {
			@problemRecords = $db->getAllMergedProblemVersions( $studentName, $setID, $set->version_id );
		}   # use versioned problems instead (assume that each version has the same number of problems.
	
	# for jitar sets we only use the top level problems
	if ($set->assignment_type eq 'jitar') {
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
		@problemRecords = sort {$a->problem_id <=> $b->problem_id }  @problemRecords;
		
		# for gateway/quiz assignments we have to be careful about 
		#    the order in which the problems are displayed, because
		#    they may be in a random order
		if ( $set->problem_randorder ) {
			my @newOrder = ();
			my @probOrder = (0..$#problemRecords);
			# we reorder using a pgrand based on the set psvn
			my $pgrand = PGrandom->new();
			$pgrand->srand( $set->psvn );
			while ( @probOrder ) { 
				my $i = int($pgrand->rand(scalar(@probOrder)));
				push( @newOrder, $probOrder[$i] );
				splice(@probOrder, $i, 1);
			}
			# now $newOrder[i] = pNum-1, where pNum is the problem
			#    number to display in the ith position on the test
			#    for sorting, invert this mapping:
			my %pSort = map {($newOrder[$_]+1)=>$_} (0..$#newOrder);

			@problemRecords = sort {$pSort{$a->problem_id} <=> $pSort{$b->problem_id}} @problemRecords;
		}
		
		
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
			# we need to get the adjusted jitar grade for our
			# top level problems. 
			if ($set->assignment_type eq 'jitar') {
			    $status = jitar_problem_adjusted_status($problemRecord,$db);
			}
			
			my  $attempted    = $problemRecord->attempted;
			my $num_correct   = $problemRecord->num_correct || 0;
			my $num_incorrect = $problemRecord->num_incorrect   || 0;
			$num_of_attempts  += $num_correct + $num_incorrect;

#######################################################
			# This is a fail safe mechanism that makes sure that
			# the problem is marked as attempted if the status has
			# been set or if the problem has been attempted
			# DBFIXME this should happen in the database layer, not here!
			if (!$attempted && ($status || $num_correct || $num_incorrect )) {
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
			} else	{
				$longStatus 	= 'X';
			}

			$string          .= fourSpaceFill($longStatus);
			$twoString       .= fourSpaceFill($num_incorrect);
			my $probValue     = $problemRecord->value;
			$probValue        = 1 unless defined($probValue) and $probValue ne "";  # FIXME?? set defaults here?
			$total           += $probValue;
			$totalRight      += $status*$probValue if $valid_status;
			
# 				
# 			# initialize the number of correct answers 
# 			# for this problem if the value has not been 
# 			# defined.
# 			$correct_answers_for_problem{$probID} = 0 
# 				unless defined($correct_answers_for_problem{$probID});
			
# 				
# 		# add on the scores for this problem
# 			if (defined($attempted) and $attempted) {
# 				$number_of_students_attempting_problem{$probID}++;
# 				push( @{ $attempts_list_for_problem{$probID} } ,     $num_of_attempts);
# 				$number_of_attempts_for_problem{$probID}             += $num_of_attempts;
# 				$h_problemData{$probID}                               = $num_incorrect;
# 				$total_num_of_attempts_for_set                       += $num_of_attempts;
# 				$correct_answers_for_problem{$probID}                += $status;
# 			}

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
sub fourSpaceFill {
	my $num = shift @_ || 0;

	if (length($num)<=1) {return "$num".'&nbsp;&nbsp;&nbsp;';}
	elsif (length($num)==2) {return "$num".'&nbsp;&nbsp;';}
	elsif (length($num)==3) {return "$num".'&nbsp;';}
	else {return "### ";}
}

1;
