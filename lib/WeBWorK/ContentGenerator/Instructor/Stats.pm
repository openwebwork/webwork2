################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Instructor::Stats;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemList - List and edit problems in a set

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readDirectory list2hash max);
use WeBWorK::DB::Record::Set;


sub initialize {
	my $self     = shift; 
	# FIXME  are there args here?
	my $type       = shift || '';
	my @components = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
 	my $user = $r->param('user');
 	my $setName = $_[0];
 	$setName = 0 unless defined($setName);  #FIXME relay to index page for statistics
 	my $setRecord = $db->getGlobalSet($setName);
 	$self->{set}   = $setRecord;
 	$self->{type}  = $type;
 	if ($type eq 'student') {
 		$self->{studentName } = $components[0] || $user;
 		
 	} elsif ($type eq 'set') {
 		$self->{setName}     = $components[0]  || 0 ;
 	}
 	
 	
}

sub path {
	my $self       = shift;
	my $args       = $_[-1];
	my $ce         = $self->{ce};
	my $root       = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
	return $self->pathMacro($args,
		"Home"          => "$root",
		$courseName     => "$root/$courseName",
		'instructor'    => "$root/$courseName/instructor",
		'stats'         => "$root/$courseName/instructor/stats/",
		( $self->{type} eq 'set')     ? ("set/".$self->{setName}  => '')        : ''   ,
		( $self->{type} eq 'student') ? ("student/".$self->{studentName} => '') : ''   ,
	);
}

sub title { 
	my ($self, @components) = @_;
	my $type                = $self->{type};
	my $string              = "Statistics for ".$self->{ce}->{courseName}." ";
	if ($type eq 'student') {
		$string             .= "student ".$self->{studentName};
	} elsif ($type eq 'set' ) {
		$string             .= "set   ".$self->{setName};
	}
	return $string;
}
sub body {
	my $self       = shift;
	my $args       = pop(@_);
	my $type       = $self->{type};
	if ($type eq 'student') {
		$self->displayStudents($self->{studentName});
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
	print CGI::h3('View statistics by set');
	foreach my $set (@setList) {
		print CGI::a({-href=>"${uri}set/$set/?".$self->url_authen_args },"set $set" ),'&nbsp;&nbsp;';	
	}
	print CGI::h3('View statistics by student');
	foreach my $student (@studentList) {
		print CGI::a({-href=>"${uri}student/$student/?".$self->url_authen_args},"  $student" ),'&nbsp;&nbsp;';	
	}
	return '';
	
}
sub displaySets {
	my $self    = shift;
	#FIXME
	my $setName = shift;
	
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $courseName = $ce->{courseName};
	my $setRecord = $db->getGlobalSet($setName);
	my @studentList   = $db->listUsers;


###############################################################
#  Print table
###############################################################
	my @problems = sort {$a <=> $b } $db->listUserProblems($user, $setName);
	# construct header
	my $problem_header = '';
	my $i=1;
	foreach (@problems) {
		$problem_header .= &threeSpaceFill($i++);
	}
	print
		CGI::start_table({-border=>5}),
		CGI::Tr(
			CGI::th({ -align=>'center',},'Name'),
			CGI::th({ -align=>'center', },'Score'),
			CGI::th({ -align=>'center', },'Out'.CGI::br().'Of'),
			CGI::th({ -align=>'center', },'Ind'),
			CGI::th({ -align=>'center', },'<pre>Problems',CGI::br(),$problem_header,'</pre>'),
			CGI::th({ -align=>'center', },'Section'),
			CGI::th({ -align=>'center', },'Recitation'),
			CGI::th({ -align=>'center', },'login_name'),
			#CGI::th({ -align=>'center', },'ID'),
		);
	# FIXME I'm assuming the problems are all the same

	my $num_of_problems  = @problems;
	foreach my $student (@studentList)   {
		my $studentRecord = $db->getUser($student);
		next if $studentRecord->last_name =~/^practice/i;  # don't show practice users
		next if $studentRecord->status !~/C/;              # don't show dropped students FIXME
	    my $status = 0;
	    my $attempted = 0;
	    my $longStatus = '';
	    my $string     = '';
	    my $twoString  = '';
	    my $totalRight = 0;
	    my $total      = 0;
		my $num_of_attempts = 0;
		foreach my $prob (@problems) {
			my $problemRecord      = $db->getUserProblem($student, $setName, $prob);
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
			$incorrect        = ($incorrect < 99) ? $incorrect: 99;  # take min
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
		# FIXME   we can do this more effficiently  get the list first
		
		my $fullName = join("", $studentRecord->first_name," ", $studentRecord->last_name);
		my $email    = $studentRecord->email_address;
		# FIXME  this needs formatting
		
		my $avg_num_attempts = ($num_of_problems) ? $num_of_attempts/$num_of_problems : 0;
		my $successIndicator = ($avg_num_attempts) ? ($totalRight/$total)**2/$avg_num_attempts : 0 ;
	
		print CGI::Tr(
			CGI::td($fullName, CGI::br(), CGI::a({-href=>"mailto:$email"},$email)),
			CGI::td($totalRight), # score
			CGI::td($total), # out of 
			CGI::td(sprintf("%0.0f",100*$successIndicator)),   # indicator
			CGI::td("<pre>$string\n$twoString</pre>"), # problems
			CGI::td($studentRecord->section),
			CGI::td($studentRecord->recitation),
			CGI::td($studentRecord->user_id),			
			
		);
	
	}
	print CGI::end_table();
			
			

			
	return "";
}
sub displayStudents {
	my $self     = shift;
	my $studentName  = shift;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $courseName = $ce->{courseName};
	my $studentRecord = $db->getUser($studentName);
	
	
	my @setIDs    = sort $db->listUserSets($studentName);
	my $fullName = join("", $studentRecord->first_name," ", $studentRecord->last_name);
	my $email    = $studentRecord->email_address;
	print CGI::h3($fullName), CGI::a({-href=>"mailto:$email"},$email);
###############################################################
#  Print table
###############################################################

	print
		CGI::start_table({-border=>5}),
		CGI::Tr(
			CGI::th({ -align=>'center',},'Set'),
			CGI::th({ -align=>'center', },'Score'),
			CGI::th({ -align=>'center', },'Out'.CGI::br().'Of'),
			CGI::th({ -align=>'center', },'Ind'),
			CGI::th({ -align=>'center', },'Problems'),
			#CGI::th({ -align=>'center', },'Section'),
			#CGI::th({ -align=>'center', },'Recitation'),
			#CGI::th({ -align=>'center', },'login_name'),
			#CGI::th({ -align=>'center', },'ID'),
		);
	# FIXME I'm assuming the problems are all the same

	
	foreach my $setName (@setIDs)   {
	    my $status = 0;
	    my $attempted = 0;
	    my $longStatus = '';
	    my $string     = '';
	    my $twoString  = '';
	    my $totalRight = 0;
	    my $total      = 0;
		my $num_of_attempts = 0;
		my @problems = sort {$a <=> $b } $db->listUserProblems($studentName, $setName);
		my $num_of_problems  = @problems;
		# construct header
		my $problem_header = '';
		my $i=1;
		foreach (@problems) {
			$problem_header .= &threeSpaceFill($i++);
		}
		foreach my $prob (@problems) {
			my $problemRecord      = $db->getUserProblem($studentName, $setName, $prob);
			
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
			$incorrect        = ($incorrect < 99) ? $incorrect: 99;  # take min
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
		# FIXME   we can do this more effficiently  get the list first
		

		# FIXME  this needs formatting
		
		my $avg_num_attempts = ($num_of_problems) ? $num_of_attempts/$num_of_problems : 0;
		my $successIndicator = ($avg_num_attempts) ? ($totalRight/$total)**2/$avg_num_attempts : 0 ;
	
		print CGI::Tr(
			CGI::td($setName),
			CGI::td($totalRight), # score
			CGI::td($total), # out of 
			CGI::td(sprintf("%0.0f",100*$successIndicator)),   # indicator
			CGI::td("<pre>$string\n$twoString</pre>"), # problems
			#CGI::td($studentRecord->section),
			#CGI::td($studentRecord->recitation),
			#CGI::td($studentRecord->user_id),			
			
		);
	
	}
	print CGI::end_table();
			
			

			
	return "";
}

#################################
# Utility function NOT a method
#################################
sub threeSpaceFill {
    my $num = shift @_;
    if ($num < 10) {return "$num".'  ';}
    elsif ($num < 100) {return "$num".' ';}
    else {return "$num";}
}
sub round_score{
	return shift;
}
1;
