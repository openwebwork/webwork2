################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/Stats.pm,v 1.21 2004/03/04 21:05:58 sh002i Exp $
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
problem set.

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readDirectory list2hash max);
use WeBWorK::DB::Record::Set;


sub initialize {
	my $self     = shift; 
	# FIXME  are there args here?
	my @components = @_;
	my $r = $self->{r};
	my $type       = $r->urlpath->arg("statType") || '';
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
 	my $user = $r->param('user');
 	#my $setName = $_[0];
 	
 	
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

sub path {
	my $self       = shift;
	my $args       = $_[-1];
	my $ce         = $self->{ce};
	my $root       = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
	return $self->pathMacro($args,
		"Home"             => "$root",
		$courseName        => "$root/$courseName",
		'Instructor Tools' => "$root/$courseName/instructor",
		'Statistics'       =>
			($self->{type}
				? "$root/$courseName/instructor/stats/"
				: ""
			),
		($self->{type} eq 'set'
			? ("set ".$self->{setName}  => '')
			: ()
		),
		($self->{type} eq 'student'
			? ("user ".$self->{studentName} => '')
			: ()
		),
	);
}

sub title { 
	my ($self) = @_;
	my $type                = $self->{type};
	my $string              = "Statistics for ".$self->{ce}->{courseName}." ";
	if ($type eq 'student') {
		$string             .= "student ".$self->{studentName};
	} elsif ($type eq 'set' ) {
		$string             .= "set   ".$self->{setName};
		$string             .= ".&nbsp;&nbsp;&nbsp; Due ". WeBWorK::Utils::formatDateTime($self->{set_due_date});
	}
	return $string;
}
sub body {
	my $self       = shift;
	my $args       = pop(@_);
	my $type       = $self->{type};
	if ($type eq 'student') {
		$self->displayStudentStats($self->{studentName});
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
	my $ce            = $self->{ce};
	my $r             = $self->{r};
	my $courseName    = $ce->{courseName};
	my $db            = $self->{db};
	my @studentList   = sort $db->listUsers;
	my @setList       = sort  $db->listGlobalSets;
	my $uri           = $r->uri;
	my @setLinks      = ();
	my @studentLinks  = (); 
	foreach my $set (@setList) {
		push @setLinks, CGI::a({-href=>"${uri}set/$set/?".$self->url_authen_args },"set $set" );	
	}
	
	foreach my $student (@studentList) {
		push @studentLinks, CGI::a({-href=>"${uri}student/$student/?".$self->url_authen_args},"  $student" ),;	
	}
	print join("",
		CGI::start_table({-border=>2, -cellpadding=>20}),
		CGI::Tr(
			CGI::td({-valign=>'top'}, 
				CGI::h3({-align=>'center'},'View statistics by set'),
				CGI::ul(  CGI::li( [@setLinks] ) ), 
			),
			CGI::td({-valign=>'top'}, 
				CGI::h3({-align=>'center'},'View statistics by student'),
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
	}
	# for example
	# $percentiles{75}  = @list_of_scores[int( 25*$num_students/100)]; 
	# means that 75% of the students received this score ($percentiles{75}) or higher
	%percentiles;
}
sub displaySets {
	my $self       = shift;
	my $setName    = shift;
	my $r          = $self->{r};
	my $db         = $self->{db};
	my $ce         = $self->{ce};
	my $authz      = $self->{authz};
	my $user       = $r->param('user');
	my $courseName = $ce->{courseName};
	my $setRecord  = $self->{setRecord};
	my $root       = $ce->{webworkURLs}->{root};
	my $url        = $r->uri; 
	my $sort_method_name = $r->param('sort');  
	my @studentList   = $db->listUsers;

   	my @index_list                           = ();  # list of all student index 
	my @score_list                           = ();  # list of all student total percentage scores 
    my %attempts_list_for_problem            = ();  # a list of the number of attempts for each problem
    my %number_ofstudents_attempting_problem = ();  # the number of students attempting this problem.
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
	$WeBWorK::timer->continue("Begin obtaining user records for set $setName") if defined($WeBWorK::timer);
	my @userRecords  = $db->getUsers(@studentList);
	$WeBWorK::timer->continue("End obtaining user records for set $setName") if defined($WeBWorK::timer);
    $WeBWorK::timer->continue("begin main loop") if defined($WeBWorK::timer);
 	my @augmentedUserRecords    = ();
 	my $number_of_active_students;
    
	foreach my $studentRecord (@userRecords)   {
		next unless ref($studentRecord);
		my $student = $studentRecord->user_id;
		next if $studentRecord->last_name =~/^practice/i;  # don't show practice users
		next if $studentRecord->status !~/C/;              # don't show dropped students FIXME
		$number_of_active_students++;
	    my $status          = 0;
	    my $attempted       = 0;
	    my $longStatus      = '';
	    my $string          = '';
	    my $twoString       = '';
	    my $totalRight      = 0;
	    my $total           = 0;
		my $num_of_attempts = 0;
		my %h_problemData   = ();
		my $probNum         = 0;
		
		$WeBWorK::timer->continue("Begin obtaining problem records for user $student set $setName") if defined($WeBWorK::timer);
		
		my @problemRecords = sort {$a->problem_id <=> $b->problem_id } $db->getAllUserProblems( $student, $setName );
		$WeBWorK::timer->continue("End obtaining problem records for user $student set $setName") if defined($WeBWorK::timer);
		my $num_of_problems = @problemRecords;
		my $max_num_problems = ($max_num_problems>= $num_of_problems) ? $max_num_problems : $num_of_problems;

		foreach my $problemRecord (@problemRecords) {
			next unless ref($problemRecord);
			my $probID = $problemRecord->problem_id;
			
			my $valid_status    = 0;
			unless (defined($problemRecord) ){
				# warn "Can't find record for problem $prob in set $setName for $student";
				# FIXME check the legitimate reasons why a student record might not be defined
				next;
			}
	    	$status             = $problemRecord->status || 0;
	        $attempted          = $problemRecord->attempted;
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

			my $incorrect     = $problemRecord->num_incorrect || 0; 
			# It's possible that $incorrect is an empty or blank string instead of 0  the || clause fixes this and prevents 
			# warning messages in the comparison below.
			$string          .=  $longStatus;
			$twoString       .= threeSpaceFill($incorrect);
			my $probValue     = $problemRecord->value;
			$probValue        = 1 unless defined($probValue);  # FIXME?? set defaults here?
			$total           += $probValue;
			$totalRight      += round_score($status*$probValue) if $valid_status;
			my $num_correct   = $problemRecord->num_incorrect || 0;
			my $num_incorrect = $problemRecord->num_correct   || 0;
			$num_of_attempts += $num_correct + $num_incorrect;
			
			$correct_answers_for_problem{$probID}  = 0 unless defined($correct_answers_for_problem{$probID});
			 # add on the scores for this problem
			if (defined($attempted) and $attempted) {
				$number_ofstudents_attempting_problem{$probID}++;
				push( @{ $attempts_list_for_problem{$probID} } ,     $num_correct + $num_incorrect);
				$correct_answers_for_problem{$probID} += $status;
			}
				
		}
		
		
		my $act_as_student_url = "$root/$courseName/$setName?user=".$r->param("user").
			"&effectiveUser=".$studentRecord->user_id()."&key=".$r->param("key");
		my $email    = $studentRecord->email_address;
		# FIXME  this needs formatting
		
		my $avg_num_attempts = ($num_of_problems) ? $num_of_attempts/$num_of_problems : 0;
		my $successIndicator = ($avg_num_attempts) ? ($totalRight/$total)**2/$avg_num_attempts : 0 ;
		my $temp_hash         = {    user_id     => $studentRecord->user_id,
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
	$WeBWorK::timer->continue("end mainloop") if defined($WeBWorK::timer);
	
	@augmentedUserRecords = sort {           &$sort_method($a,$b)
												||
							lc($a->{last_name}) cmp lc($b->{last_name} ) } @augmentedUserRecords;
	
	# sort the problem IDs
	my @problemIDs   = sort {$a<=>$b} keys %correct_answers_for_problem;
	# determine index quartiles
    my @brackets          = (75, 50,25,5);
	my %index_percentiles = determine_percentiles(\@brackets, @index_list);
    my %score_percentiles = determine_percentiles(\@brackets, @score_list);
    my %attempts_percentiles_for_problem = ();
    foreach my $probID (@problemIDs) {
    	$attempts_percentiles_for_problem{$probID} =   {
    		determine_percentiles([@brackets, 0], @{$attempts_list_for_problem{$probID}})
    	};    
    }
    
#####################################################################################
# Table showing the percentage of students with correct answers for each problems
#####################################################################################
print  

	   CGI::p('The percentage of active students with correct answers for each problem'),
		CGI::start_table({-border=>1}),
		CGI::Tr(CGI::td(
			['Problem #', @problemIDs]
		)),
		CGI::Tr(CGI::td(
			[ '% correct',map { sprintf("%0.0f",100*$correct_answers_for_problem{$_}/$number_ofstudents_attempting_problem{$_}) }
			                       @problemIDs 
			]
		)),
		CGI::end_table();

#####################################################################################
# table showing percentile statistics for scores and success indices
#####################################################################################
	print  

	    	CGI::p('The percentage of active students whose percentage scores and success indices are greater than the given values.'),
			CGI::start_table({-border=>1}),
				CGI::Tr(
					CGI::td( ['% students',
					          (map {  "&nbsp;$_"  } @brackets) ,
					          'top score ', 
					         ]
					)
				),
				CGI::Tr(
					CGI::td( [
						'Score',
						(map { '&ge; '.sprintf("%0.0f",100*$score_percentiles{$_})   } @brackets),
						sprintf("%0.0f",100),
						]
					)
				),
				CGI::Tr(
					CGI::td( [
						'Success Index',
						(map { '&ge; '.sprintf("%0.0f",100*$index_percentiles{$_})   } @brackets),
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

	    	CGI::p('The percentage of active students with no more than the indicated number of total attempts'),
			CGI::start_table({-border=>1}),
				CGI::Tr(
					CGI::td( ['% students',
					          (map {  "&nbsp;".(100-$_)  } @brackets, 0) ,
					        
					         ]
					)
				);


	foreach my $probID (@problemIDs) {
		print	CGI::Tr(
					CGI::td( [
						"Prob $probID",
						(map { '&le; '.sprintf("%0.0f",$attempts_percentiles_for_problem{$probID}->{$_})   } @brackets, 0),

						]
					)
				);
	
	}
	print CGI::end_table();
#####################################################################################
	# construct header
	my $problem_header = '';
	
	foreach my $i (1..$max_num_problems) {
		$problem_header .= CGI::a({"href"=>$url."?".$self->url_authen_args."&sort=p$i"},threeSpaceFill($i) );
	}
	print
		CGI::p("Details"),
	    defined($sort_method_name) ?"sort method is $sort_method_name":"",
		CGI::start_table({-border=>5,style=>'font-size:smaller'}),
		CGI::Tr(CGI::th(  {-align=>'center'},
			[CGI::a({"href"=>$url."?".$self->url_authen_args."&sort=name"},'Name'),
			 CGI::a({"href"=>$url."?".$self->url_authen_args."&sort=score"},'Score'),
			 'Out'.CGI::br().'Of',
			 CGI::a({"href"=>$url."?".$self->url_authen_args."&sort=index"},'Ind'),
			 '<pre>Problems'.CGI::br().$problem_header.'</pre>',
			 CGI::a({"href"=>$url."?".$self->url_authen_args."&sort=section"},'Section'),
			 'Recitation',
			 'login_name',
			 ])

		);
								
	foreach my $rec (@augmentedUserRecords) {
		my $fullName = join("", $rec->{first_name}," ", $rec->{last_name});
		my $email    = $rec->{email_address}; 
		my $twoString  = $rec->{twoString};                             
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
	}

	print CGI::end_table();
			
			

			
	return "";
}
sub displayStudentStats {
	my $self     = shift;
	my $studentName  = shift;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $courseName = $ce->{courseName};
	my $studentRecord = $db->getUser($studentName); # checked
	die "record for user $studentName not found" unless $studentRecord;
	my $root = $ce->{webworkURLs}->{root};
	
	my @setIDs    = sort $db->listUserSets($studentName);
	my $fullName = join("", $studentRecord->first_name," ", $studentRecord->last_name);
	my $act_as_student_url = "$root/$courseName/?user=".$r->param("user").
			"&effectiveUser=".$studentRecord->user_id()."&key=".$r->param("key");

	my $email    = $studentRecord->email_address;
	print CGI::h3($fullName ), 
	CGI::a({-href=>"mailto:$email"},$email),CGI::br(),
	"Section: ", $studentRecord->section, CGI::br(),
	"Recitation: ", $studentRecord->recitation,CGI::br(),
	CGI::a({-href=>$act_as_student_url},$studentRecord->user_id);	
	
	###############################################################
	#  Print table
	###############################################################

	# FIXME I'm assuming the problems are all the same
	# FIXME what does this mean?
	
	my @rows;
	my $max_problems=0;
	
	foreach my $setName (@setIDs)   {
	    my $status = 0;
	    my $attempted = 0;
	    my $longStatus = '';
	    my $string     = '';
	    my $twoString  = '';
	    my $totalRight = 0;
	    my $total      = 0;
		my $num_of_attempts = 0;
	
		$WeBWorK::timer->continue("Begin collecting problems for set $setName") if defined($WeBWorK::timer);
		my @problemRecords = $db->getAllUserProblems( $studentName, $setName );
		$WeBWorK::timer->continue("End collecting problems for set $setName") if defined($WeBWorK::timer);
		
		# FIXME the following line doesn't sort the problemRecords
		#my @problems = sort {$a <=> $b } map { $_->problem_id } @problemRecords;
		$WeBWorK::timer->continue("Begin sorting problems for set $setName") if defined($WeBWorK::timer);
		@problemRecords = sort {$a->problem_id <=> $b->problem_id }  @problemRecords;
		$WeBWorK::timer->continue("End sorting problems for set $setName") if defined($WeBWorK::timer);
		my $num_of_problems  = @problemRecords;
		my $max_problems     = defined($num_of_problems) ? $num_of_problems : 0; 
		
		# construct header
		
		foreach my $problemRecord (@problemRecords) {
			my $prob = $problemRecord->problem_id;
			
			my $valid_status    = 0;
			unless (defined($problemRecord) ){
				# warn "Can't find record for problem $prob in set $setName for $student";
				# FIXME check the legitimate reasons why a student record might not be defined
				next;
			}
	    	$status             = $problemRecord->status || 0;
	        $attempted          = $problemRecord->attempted;
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

			my $incorrect     = $problemRecord->num_incorrect;
			$string          .=  $longStatus;
			$twoString       .= threeSpaceFill($incorrect);
			my $probValue     = $problemRecord->value;
			$probValue        = 1 unless defined($probValue);  # FIXME?? set defaults here?
			$total           += $probValue;
			$totalRight      += round_score($status*$probValue) if $valid_status;
			my $num_correct   = $problemRecord->num_incorrect || 0;
			my $num_incorrect = $problemRecord->num_correct   || 0;
			$num_of_attempts += $num_correct + $num_incorrect;
		}
		
		
		my $avg_num_attempts = ($num_of_problems) ? $num_of_attempts/$num_of_problems : 0;
		my $successIndicator = ($avg_num_attempts) ? ($totalRight/$total)**2/$avg_num_attempts : 0 ;
	
		push @rows, CGI::Tr(
			CGI::td($setName),
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
		CGI::start_table({-border=>5}),
		CGI::Tr(
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
    else {return "###";}
}
sub round_score{
	return shift;
}
1;
