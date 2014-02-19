################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/Stats.pm,v 1.68 2007/08/13 22:59:56 sh002i Exp $
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

package WeBWorK::ContentGenerator::Instructor::Stats;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Stats - Display statistics by user or
homework set (including svg graphs).

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::ContentGenerator::Grades;
use WeBWorK::Utils qw(readDirectory list2hash max sortByName);

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

	return "" unless $authz->hasPermissions($user, "access_instructor_tools");
	
	my $type                = $self->{type};
	my $string              = $r->maketext("Statistics for")." ".$self->{ce}->{courseName}." ";
	
	if ($type eq 'student') {
		$string             .= "student ".$self->{studentName};
	} elsif ($type eq 'set' ) {
		$string             .= "set   ".$self->{setName};
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
	
	my $stats     = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::Stats", $r,  
	                                        courseID => $courseID);
	
	print CGI::start_div({class=>"info-box", id=>"fisheye"});
	print CGI::h2("Statistics");
	#print CGI::start_ul({class=>"LinksMenu"});
	#print CGI::start_li();
	#print CGI::span({style=>"font-size:larger"}, CGI::a({href=>$self->systemLink($stats)}, 'Statistics'));
	print CGI::start_ul();
	
	foreach my $setID (@setIDs) {
		my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::Stats", $r, 
			courseID => $courseID, setID => $setID,statType => 'set',);
		print CGI::li(CGI::a({href=>$self->systemLink($problemPage)}, WeBWorK::ContentGenerator::underscore2nbsp($setID)));
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
	my $courseName = $urlpath->arg("courseID");
	my $user       = $r->param('user');
	my $type       = $self->{type};

	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to access instructor tools"))
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
			"Section: ", $studentRecord->section, CGI::br(),
			"Recitation: ", $studentRecord->recitation, CGI::br();
		
		if ($authz->hasPermissions($user, "become_student")) {
			my $act_as_student_url = $self->systemLink($courseHomePage,
				params => {effectiveUser=>$studentName});
			
			print 'Act as: ', CGI::a({-href=>$act_as_student_url},$studentRecord->user_id);
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
	
	# DBFIXME sort in database
	my @studentList   = sort $db->listUsers;
	my @setList       = sort  $db->listGlobalSets;
	
	
	my @setLinks      = ();
	my @studentLinks  = (); 
	foreach my $set (@setList) {
	    my $setStatisticsPage   = $urlpath->newFromModule($urlpath->module, $r, 
	                                                      courseID => $courseName,
	                                                      statType => 'set',
	                                                      setID    => $set
	    );
		push @setLinks, CGI::a({-href=>$self->systemLink($setStatisticsPage) }, WeBWorK::ContentGenerator::underscore2nbsp($set));
	}
	
	foreach my $student (@studentList) {
	    my $userStatisticsPage  = $urlpath->newFromModule($urlpath->module, $r, 
	                                                      courseID => $courseName,
	                                                      statType => 'student',
	                                                      userID   => $student
	    );
		push @studentLinks, CGI::a({-href=>$self->systemLink($userStatisticsPage,
		                                                     prams=>{effectiveUser => $student}
		                                                     )},"  $student" ),;	
	}
	print join("",
		CGI::start_table({-border=>2, -cellpadding=>20}),
		CGI::Tr({},
			CGI::td({-valign=>'top'}, 
				CGI::h3({-align=>'center'},$r->maketext('View statistics by set')),
				CGI::ul(  CGI::li( [@setLinks] ) ), 
			),
			CGI::td({-valign=>'top'}, 
				CGI::h3({-align=>'center'},$r->maketext('View statistics by student')),
				CGI::ul(CGI::li( [ @studentLinks ] ) ),
			),
		),
		CGI::end_table(),
	);
	
}
###################################################
# Determines the percentage of students whose score is greater than a given value
# The percentages are fixed at 75, 50, 25 and 5%
sub determine_percentiles {
	my $percent_brackets  = shift;
	my @list_of_scores    = @_;
	@list_of_scores       = sort {$a<=>$b} @list_of_scores;
	my %percentiles          = ();
	my $num_students      = $#list_of_scores;
	foreach my $percentage (@{$percent_brackets}) {
		$percentiles{$percentage} = @list_of_scores[int( (100-$percentage)*$num_students/100)];
		$percentiles{$percentage} =0 unless defined($percentiles{$percentage});  #in case no students have tried this question
	}
	# for example
	# $percentiles{75}  = @list_of_scores[int( 25*$num_students/100)]; 
	# means that 75% of the students received this score ($percentiles{75}) or higher
	%percentiles;
}
sub prevent_repeats {    # replace a string such as 0 0 0 86 86 100 100 100 by    0 - - 86 - 100 - -
	my @inarray   = @_;
	my @outarray = ();
	my $saved_item = shift @inarray;
	push @outarray, $saved_item;
	while (@inarray )   {
		my $current_item = shift @inarray;
		if ( $current_item == $saved_item ) {
			push @outarray, '&nbsp;-';
		} else {
			push @outarray, $current_item;
			$saved_item = $current_item;
		}
	}
	@outarray;
}
		
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
	
	my $setStatsPage     = $urlpath->newFromModule($urlpath->module, $r, courseID=>$courseName,statType=>'sets',setID=>$setName);
	my $sort_method_name = $r->param('sort');  
	# DBFIXME duplicate call
	my @studentList      = $db->listUsers;
    
   	my @index_list                           = ();  # list of all student index 
	my @score_list                           = ();  # list of all student total percentage scores 
    my %attempts_list_for_problem            = ();  # a list of the number of attempts for each problem
    my %number_of_attempts_for_problem       = ();  # the total number of attempst for this problem (sum of above list)
    my %number_of_students_attempting_problem = ();  # the number of students attempting this problem.
    my %correct_answers_for_problem          = ();  # the number of students correctly answering this problem (partial correctness allowed)
	my $sort_method = sub {
		my ($a,$b) = @_;
		return 0 unless defined($sort_method_name);
		return $b->{score} <=> $a->{score} if $sort_method_name eq 'score';
		return $b->{index} <=> $a->{index} if $sort_method_name eq 'index';
		return $a->{section} cmp $b->{section} if $sort_method_name eq 'section';
		if ($sort_method_name =~/p(\d+)/) {
		    my $left  =  $b->{problemData}->{$1} ||0;
		    my $right =  $a->{problemData}->{$1} ||0;
			return $left <=> $right;  # sort by number of attempts.
		}

	};

###############################################################
#  Print tables
###############################################################
	
	my $max_num_problems  = 0;
	# get user records
	debug("Begin obtaining problem records for  set $setName");
	# DBFIXME use an iterator
	my @userRecords  = $db->getUsers(@studentList);
	debug("End obtaining user records for set $setName");
    debug("begin main loop");
 	my @augmentedUserRecords    = ();
 	my $number_of_active_students;
    
    ########################################
    # Notes for factoring this calculation
    #
    # Inputs include:
    # $user
    # $setName
    # @userRecords
    #               @problemRecords  these are fetched for each student in @userRecords
    #
    ###################################
   
	foreach my $studentRecord (@userRecords)   {
		next unless ref($studentRecord);
		my $student = $studentRecord->user_id;
		next if $studentRecord->last_name =~/^practice/i;  # don't show practice users
		next unless $ce->status_abbrev_has_behavior($studentRecord->status, "include_in_stats");
		$number_of_active_students++;
	    my $string          = '';
	    my $twoString       = '';
	    my $totalRight      = 0;
	    my $total           = 0;
		my $total_num_of_attempts_for_set = 0;
		my %h_problemData   = ();
		my $probNum         = 0;
		
		debug("Begin obtaining problem records for user $student set $setName");
		
		# DBFIXME use an iterator
		my @problemRecords;
		if ( $setRecord->assignment_type =~ /gateway/ ) {
			my @setVersions = $db->listSetVersions($student, $setName);
			foreach my $ver ( @setVersions ) {
				push( @problemRecords,
				      $db->getAllProblemVersions($student,
								 $setName, $ver) );
			}
		} else {
			@problemRecords = sort {$a->problem_id <=> $b->problem_id } $db->getAllUserProblems( $student, $setName );
		}
		debug("End obtaining problem records for user $student set $setName");

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
		
	        
			my $probValue          = $problemRecord->value;
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
				$longStatus     = ($longStatus == 100) ? 'C' : $longStatus;
			} else	{
				$longStatus 	= 'X';
			}
			
			$string          .=  threeSpaceFill($longStatus);
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
			
		}
		
		
		my $act_as_student_url = $self->systemLink($urlpath->new(type=>'set_list',args=>{courseID=>$courseName}),
		                                           params=>{effectiveUser => $studentRecord->user_id}
		);
		my $email              = $studentRecord->email_address;
		# FIXME  this needs formatting
		
		my $avg_num_attempts = ($num_of_problems) ? $total_num_of_attempts_for_set/$num_of_problems : 0;
		my $successIndicator = ($avg_num_attempts) ? ($totalRight/$total)**2/$avg_num_attempts : 0 ;
		
		my $temp_hash         = {         user_id        => $studentRecord->user_id,
		                                  last_name      => $studentRecord->last_name,
		                                  first_name     => $studentRecord->first_name,
		                                  score          => $totalRight,
		                                  total          => $total,
		                                  index          => $successIndicator,
		                                  section        => $studentRecord->section,
		                                  recitation     => $studentRecord->recitation,
		                                  problemString  => "<pre>$string\n$twoString</pre>",
		                                  act_as_student => $act_as_student_url,
		                                  email_address  => $studentRecord->email_address,
		                                  problemData    => {%h_problemData},
		}; 
		# add this data to the list of total scores (out of 100)
		# add this data to the list of success indices.
		push( @index_list, $temp_hash->{index});
		push( @score_list, ($temp_hash->{total}) ?$temp_hash->{score}/$temp_hash->{total} : 0 ) ;
		push( @augmentedUserRecords, $temp_hash );
		                                
	}	
	debug("end mainloop");
	
	@augmentedUserRecords = sort {           &$sort_method($a,$b)
												||
							lc($a->{last_name}) cmp lc($b->{last_name} ) } @augmentedUserRecords;
	
	# sort the problem IDs
	my @problemIDs         = sort {$a<=>$b} keys %correct_answers_for_problem;
	# determine index quartiles
    my @brackets1          = (90,80,70,60,50,40,30,20,10);  #% students having scores or indices above this cutoff value
    my @brackets2          = (95, 75,50,25,5,1);       # % students having this many incorrect attempts or more  
	my %index_percentiles = determine_percentiles(\@brackets1, @index_list);
    my %score_percentiles = determine_percentiles(\@brackets1, @score_list);
    my %attempts_percentiles_for_problem = ();
    my %problemPage                      = (); # link to the problem page
    foreach my $probID (@problemIDs) {
    	$attempts_percentiles_for_problem{$probID} =   {
    		determine_percentiles([@brackets2], @{$attempts_list_for_problem{$probID}})

    	}; 
    	$problemPage{$probID} = $urlpath->newFromModule("WeBWorK::ContentGenerator::Problem", $r, 
			courseID => $courseName, setID => $setName, problemID => $probID);

    }

###################################################################################################
#  Begin SVG bar graph showing the percentage of students with correct answers for each problem

my $numberofproblems = scalar(@problemIDs); 
my ($barwidth,$barsep) = (22, 4); # = total width (in pixels) used for each bar is $barwidth+2*$barsep
my $totalbarwidth = $barwidth + 2*$barsep;
my ($topmargin,$rightmargin,$bottommargin,$leftmargin) = (30, 20, 35, 40); # pixels
my ($plotwindowwidth,$plotwindowheight) = ($numberofproblems*($barwidth+2*$barsep), 200); # pixels
# since $plotwindowheight = 200, the height of each bar is 2*(percentagescore)
if ( $plotwindowwidth < 450 ) { $plotwindowwidth = 450; }
my $ylabelsep = 4; # pixels
my ($imagewidth,$imageheight) = ($leftmargin+$plotwindowwidth+$rightmargin, $topmargin+$plotwindowheight+$bottommargin); # pixels
my ($titlexpixel,$titleypixel) = ($leftmargin + sprintf("%d",$plotwindowwidth/2), $topmargin-10); # pixels
my ($xaxislabelxpixel,$xaxislabelypixel) = ($titlexpixel,$imageheight-5); # pixels
my $yaxislabelxpixel = $leftmargin-4; # pixel


####################################
# Create a string for the svg image

my $svg = '';
$svg = $svg . "<svg id=\"bargraph\" xmlns=\"http://www.w3.org/2000/svg\" xlink=\"http://www.w3.org/1999/xlink\" width=\"" . $imagewidth . "\" height=\"" . $imageheight ."\">\n";

$svg = $svg . "<rect id=\"bargraphwindow\" x=\"0\" y=\"0\" width=\"". $imagewidth ."\" height=\"". $imageheight ."\" rx=\"20\" ry=\"20\" style=\"fill:white;stroke:888888;stroke-width:2;fill-opacity:0;stroke-opacity:1\" />\n";

$svg = $svg . "<text id=\"bargraphtitle\" x=\"". $titlexpixel ."\" y=\"". $titleypixel ."\" font-family=\"sans-serif\" font-size=\"16\" fill=\"black\" text-anchor=\"middle\" font-weight=\"bold\">Percentage of Active Students with Correct Answers</text>\n";

$svg = $svg . "<text id=\"bargraphxaxislabel\" x=\"". $xaxislabelxpixel ."\" y=\"". $xaxislabelypixel ."\" font-family=\"sans-serif\" font-size=\"14\" fill=\"black\" text-anchor=\"middle\" font-weight=\"normal\">Problem Number</text>\n";

$svg = $svg . "<rect id=\"bargraphplotwindow\" x=\"". $leftmargin ."\" y=\"". $topmargin ."\" width=\"". $plotwindowwidth ."\" height=\"". $plotwindowheight ."\" style=\"fill:white;stroke:bbbbbb;stroke-width:1;fill-opacity:0;stroke-opacity:1\" />\n";

my $yaxislabelypixel = 0;
my $yaxislabel = "";
foreach my $i (0..5) {
    $yaxislabelypixel = $topmargin + 5 + ($i * sprintf("%d",$plotwindowheight/5));
    $yaxislabel = 20*(5 - $i);
    $svg = $svg . "<text id=\"bargraphylabel". $yaxislabel ."\" x=\"". $yaxislabelxpixel ."\" y=\"". $yaxislabelypixel ."\"  font-family=\"sans-serif\" font-size=\"12\" fill=\"black\" text-anchor=\"end\" font-weight=\"normal\">". $yaxislabel ."%</text>\n";
}

my $yaxisruleypixel = 0;
my $yaxisrulerightxpixel = $leftmargin + $plotwindowwidth;
foreach my $i (1..9) {
    $yaxisruleypixel = $topmargin + ($i * sprintf("%d",$plotwindowheight/10));
    $svg = $svg . "<line id=\"yline90\"  x1=\"". $leftmargin ."\" y1=\"". $yaxisruleypixel ."\"  x2=\"". $yaxisrulerightxpixel ."\" y2=\"". $yaxisruleypixel ."\"  style=\"stroke:bbbbbb;stroke-width:1;stroke-opacity:1\" />\n";
}

my $linkstring = "";
my $percentcorrect = 0;
my $problemnumber = 1;
my $barheight = 0;
my $barxpixel = 0;
my $barypixel = 0;
my $problabelxpixel = 0;
#my $problabelypixel = 0;
my $problabelypixel = $topmargin + $plotwindowheight - $barheight + 15;

foreach my $probID (@problemIDs) {
    $linkstring = $self->systemLink($problemPage{$probID});
    
    $percentcorrect = ($number_of_students_attempting_problem{$probID})?
    	sprintf("%0.0f",100*$correct_answers_for_problem{$probID}/$number_of_students_attempting_problem{$probID})
    	: 0;  #avoid division by zero
    $barheight = sprintf("%d", $percentcorrect * $plotwindowheight / 100 );
    $barxpixel = $leftmargin + ($probID-1) * ($barwidth + 2*$barsep) + $barsep;
    $barypixel = $topmargin + $plotwindowheight - $barheight;
    $problabelxpixel = $leftmargin + ($probID-1) * $totalbarwidth + $barsep + sprintf("%d",$totalbarwidth/2);
    # $problabelypixel = $topmargin + $plotwindowheight - $barheight;
    $svg = $svg . "<a xlink:href=\"". $linkstring ."\" target=\"_blank\"><rect id=\"bar". $probID ."\" x=\"". $barxpixel ."\" y=\"". $barypixel ."\" width=\"". $barwidth ."\" height=\"". $barheight ."\" fill=\"rgb(0,153,198)\" /><text id=\"problem". $probID ."\" x=\"". $problabelxpixel ."\" y=\"". $problabelypixel ."\" font-family=\"sans-serif\" font-size=\"12\" fill=\"black\" text-anchor=\"middle\">". $probID ."</text></a>\n";
}

$svg = $svg . "</svg>";

print CGI::p("$svg"); # insert SVG graph inside an html paragraph

# End SVG bar graph showing the percentage of students with correct answers for each problem
###################################################################################################


#####################################################################################
# Table showing the percentage of students with correct answers for each problems
#####################################################################################

print  

	   CGI::p($r->maketext('The percentage of active students with correct answers for each problem')),
		CGI::start_table({-border=>1, -class=>"stats-table"}),
		CGI::Tr(CGI::td(
			['Problem #', 
			   map {CGI::a({ href=>$self->systemLink($problemPage{$_}) },$_)} @problemIDs
			]
		)),
		CGI::Tr(CGI::td(
			[ $r->maketext('% correct'),map {($number_of_students_attempting_problem{$_})
			                      ? sprintf("%0.0f",100*$correct_answers_for_problem{$_}/$number_of_students_attempting_problem{$_})
			                      : '-'}			                   
			                       @problemIDs 
			]
		)),
		CGI::Tr(CGI::td(
			[ $r->maketext('avg attempts'),map {($number_of_students_attempting_problem{$_})
			                      ? sprintf("%0.1f",$number_of_attempts_for_problem{$_}/$number_of_students_attempting_problem{$_})
			                      : '-'}			                   
			                       @problemIDs 
			]
			));

	#show a grading link if necc
	my $gradingLink = "";
	my @setUsers = $db->listSetUsers($setName);
	my @GradeableRows;
	my $showGradeRow = 0;
	unshift (@GradeableRows, CGI::td({}, "manual grader"));
	foreach my $problemID (@problemIDs) {
	    my $globalProblem = $db->getGlobalProblem($setName,$problemID);
	    if ($globalProblem->flags =~ /essay/) {
		$showGradeRow = 1;
		my $gradeProblemPage = $urlpath->new(type => 'instructor_problem_grader', args => { courseID => $courseName, setID => $setName, problemID => $problemID });
		push (@GradeableRows, CGI::td({}, CGI::a({href => $self->systemLink($gradeProblemPage)}, "Grade Problem")));
		
	    }  else {
		push (@GradeableRows, CGI::td());
	    }
	}
	
	if ($showGradeRow) {
	    print CGI::Tr(@GradeableRows);
	}


	print CGI::end_table();

#####################################################################################
# table showing percentile statistics for scores and success indices
#####################################################################################
	print  

	    	CGI::p(CGI::i($r->maketext('The percentage of students receiving at least these scores. The median score is in the 50% column.'))),
			CGI::start_table({-border=>1,-class=>"stats-table"}),
				CGI::Tr(
					CGI::td( [$r->maketext('% students'),
					          (map {  "&nbsp;".$_   } @brackets1) ,
					          $r->maketext('top score'), 
					         
					         ]
					)
				),
				CGI::Tr(
					CGI::td( [
						$r->maketext('Score'),
						(prevent_repeats map { sprintf("%0.0f",100*$score_percentiles{$_})   } @brackets1),
						sprintf("%0.0f",100),
						]
					)
				),
				CGI::Tr(
					CGI::td( [
						$r->maketext('Success Index'),
						(prevent_repeats  map { sprintf("%0.0f",100*$index_percentiles{$_})   } @brackets1),
						sprintf("%0.0f",100),
						]
					)
				)
			;

	print     CGI::end_table(),	

		;

#####################################################################################
# table showing percentile statistics for scores and success indices
#####################################################################################
	print  

	    	CGI::p(CGI::i($r->maketext('Percentile cutoffs for number of attempts. The 50% column shows the median number of attempts.'))),
			CGI::start_table({-border=>1,-class=>"stats-table"}),
				CGI::Tr(
					CGI::td( [$r->maketext('% students'),
					          (map {  "&nbsp;".($_)  } @brackets2) ,
					        
					         ]
					)
				);


	foreach my $probID (@problemIDs) {
		print	CGI::Tr(
					CGI::td( [
						CGI::a({ href=>$self->systemLink($problemPage{$probID}) },"Prob $probID"),
						( prevent_repeats reverse map { sprintf("%0.0f",$attempts_percentiles_for_problem{$probID}->{$_})   } @brackets2),

						]
					)
				);
	
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

1;
