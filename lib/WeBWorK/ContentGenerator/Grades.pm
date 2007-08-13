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
use WeBWorK::Utils qw(readDirectory list2hash max);

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
	my $filePath          = "$emailDirectory/report_grades.msg";
	my $merge_file         = "report_grades_data.csv";
	my $delimiter            = ',';
	my $scoringDirectory    = $ce->{courseDirs}->{scoring};
	return "There is no additional grade information. The spreadsheet file $filePath cannot be found." unless -e "$scoringDirectory/$merge_file";
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
	
# 	old version 
#  	$msg =~ s/(\$SID)/eval($1)/ge;
#  	$msg =~ s/(\$LN)/eval($1)/ge;
#  	$msg =~ s/(\$FN)/eval($1)/ge;
#  	$msg =~ s/(\$STATUS)/eval($1)/ge;
#  	$msg =~ s/(\$SECTION)/eval($1)/ge;
#  	$msg =~ s/(\$RECITATION)/eval($1)/ge;
#  	$msg =~ s/(\$EMAIL)/eval($1)/ge;
#  	$msg =~ s/(\$LOGIN)/eval($1)/ge;
#  	$msg =~ s/\$COL\[ *-/\$COL\[$endCol-/g;
#  	$msg =~ s/(\$COL\[.*?\])/eval($1)/ge;
 	
 	$msg =~ s/\r//g;
 	$msg = "<pre>$msg</pre>";
 	$msg = qq!More scoring information goes here in [TMPL]/email/report_grades.msg. It
		is merged with the file [Scoring]/report_grades_data.csv. <br>These files can be edited 
		using the "Email" link and the "Scoring Tools" link in the left margin.<p>!.$msg if ($r->authz->hasPermissions($userID, "access_instructor_tools"));
	return CGI::div(
		{style =>"background-color:#DDDDDD"}, $msg
	);
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
	
	# first get all non-set-versions; listUserSets will return all 
	#    homework assignments, plus the template gateway sets.
	# DBFIXME use iterator instead of setIDs
	my @setIDs    = sort( $db->listUserSets($studentName) );
	# to figure out which of these are gateways (that is, versioned),
	#    we need to also have the actual (merged) set objects
	my @sets = $db->getMergedSets( map {[$studentName, $_]} @setIDs );
	# to be able to find the set objects later, make a handy hash
	my %setsByID = ( map {$_->set_id => $_} @sets );

	my $fullName = join("", $studentRecord->first_name," ", $studentRecord->last_name);
	my $effectiveUser = $studentRecord->user_id();
	my $act_as_student_url = "$root/$courseName/?user=".$r->param("user").
			"&effectiveUser=$effectiveUser&key=".$r->param("key");

	# before going through the table generating loop, find all the 
	#    set versions for the sets in our list
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

	
	# FIXME: why is the following not "print CGI::h3($fullName);"?  Hmm.
	print CGI::h3($fullName ), 

	###############################################################
	#  Print table
	###############################################################

	# FIXME I'm assuming the problems are all the same
	# FIXME what does this mean?
	
	my @rows;
	my $max_problems=0;
	
	foreach my $setName (@allSetIDs)   {
		my $act_as_student_set_url = "$root/$courseName/$setName/?user=".$r->param("user").
			"&effectiveUser=$effectiveUser&key=".$r->param("key");
		my $set = $setsByID{ $setName };
		my $setID = $set->set_id();

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

		my $status = 0;
		my $attempted = 0;
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
		my @problemRecords = ();
		if ( $setIsVersioned ) {
			@problemRecords = $db->getAllMergedProblemVersions( $studentName, $setID, $set->version_id );
		} else {
			@problemRecords = $db->getAllMergedUserProblems( $studentName, $setID );
		}
		debug("End collecting problems for set $setName");
		
		# FIXME the following line doesn't sort the problemRecords
		#my @problems = sort {$a <=> $b } map { $_->problem_id } @problemRecords;
		debug("Begin sorting problems for set $setName");
		@problemRecords = sort {$a->problem_id <=> $b->problem_id }  @problemRecords;
		debug("End sorting problems for set $setName");
		my $num_of_problems  = @problemRecords;
		my $max_problems     = defined($num_of_problems) ? $num_of_problems : 0; 
		
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

		# construct header
		
		foreach my $problemRecord (@problemRecords) {
			my $prob = $problemRecord->problem_id;
			
			my $valid_status    = 0;
			unless (defined($problemRecord) ){
				# warn "Can't find record for problem $prob in set $setName for $student";
				# FIXME check the legitimate reasons why a student record might not be defined
				next;
			}
		    	$status           = $problemRecord->status || 0;
		        $attempted        = $problemRecord->attempted;
			my $num_correct   = $problemRecord->num_incorrect || 0;
			my $num_incorrect = $problemRecord->num_correct   || 0;
			$num_of_attempts += $num_correct + $num_incorrect;

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
			
			if (!$attempted){
				$longStatus     = '.  ';
			}
			elsif   ($status >= 0 and $status <=1 ) {
				$valid_status   = 1;
				$longStatus     = int(100*$status+.5);
				if ($longStatus == 100) {
					$longStatus = 'C  ';
				}
				else {
					$longStatus = &threeSpaceFill($longStatus);
				}
			}
			else	{
				$longStatus 	= 'X  ';
			}

			$string          .=  $longStatus;
			$twoString       .= threeSpaceFill($num_correct);
			my $probValue     = $problemRecord->value;
			$probValue        = 1 unless defined($probValue) and $probValue ne "";  # FIXME?? set defaults here?
			$total           += $probValue;
			$totalRight      += round_score($status*$probValue) if $valid_status;
		}
		

		my $avg_num_attempts = ($num_of_problems) ? $num_of_attempts/$num_of_problems : 0;
		my $successIndicator = ($avg_num_attempts && $total) ? ($totalRight/$total)**2/$avg_num_attempts : 0 ;

		# prettify versioned set display
		$setName =~ s/(.+),v(\d+)$/${1}_(test_$2)/;
	
		push @rows, CGI::Tr({},
			CGI::td(CGI::a({-href=>$act_as_student_set_url}, WeBWorK::ContentGenerator::underscore2nbsp($setName))),
			CGI::td(sprintf("%0.2f",$totalRight)), # score
			CGI::td($total), # out of 
			CGI::td(sprintf("%0.0f",100*$successIndicator)),   # indicator
			CGI::td("<pre>$string\n$twoString</pre>"), # problems
			#CGI::td($studentRecord->section),
			#CGI::td($studentRecord->recitation),
			#CGI::td($studentRecord->user_id),			
			
		);
	
	}
	
	my $problem_header = "";
	foreach (1 .. $max_problems) {
		$problem_header .= &threeSpaceFill($_);
	}
	
	my $table_header = join("\n",
		CGI::start_table({-border=>5,style=>'font-size:smaller'}),
		CGI::Tr({},
			CGI::th({ -align=>'center',},'Set'),
			CGI::th({ -align=>'center', },'Score'),
			CGI::th({ -align=>'center', },'Out'.CGI::br().'Of'),
			CGI::th({ -align=>'center', },'Ind'),
			CGI::th({ -align=>'center', },'Problems'.CGI::br().CGI::pre($problem_header)),
			#CGI::th({ -align=>'center', },'Section'),
			#CGI::th({ -align=>'center', },'Recitation'),
			#CGI::th({ -align=>'center', },'login_name'),
			#CGI::th({ -align=>'center', },'ID'),
		)
	);
	
	print $table_header;
	print @rows;
	print CGI::end_table();
			
	return "";
}

#################################
# Utility function NOT a method
#################################
sub threeSpaceFill {
	my $num = shift @_ || 0;

	if (length($num)<=1) {return "$num".'  ';}
	elsif (length($num)==2) {return "$num".' ';}
	else {return "## ";}
}
sub round_score{
	return shift;
}

1;
