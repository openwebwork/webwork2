################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Grades.pm,v 1.3 2004/03/15 21:35:12 sh002i Exp $
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
use CGI qw();
use WeBWorK::Utils qw(readDirectory list2hash max);
use WeBWorK::DB::Record::Set;


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
        $lineArray[0] =~s/^\s*//;                       # remove white space from first element
        @lineArray;
}

sub read_scoring_file    { # used in SendMail and Grades?....?
	my ($self, $fileName, $delimiter) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
	$delimiter          = ',' unless defined($delimiter);
	my $scoringDirectory= $ce->{courseDirs}->{scoring};
	my $filePath        = "$scoringDirectory/$fileName";  
        #       Takes a delimited file as a parameter and returns an
        #       associative array with the first field as the key.
        #       Blank lines are skipped. White space is removed
    my(@dbArray,$key,$dbString);
    my %assocArray = ();
    local(*FILE);
    if ($fileName eq 'None') {
    	# do nothing
    } elsif ( open(FILE, "$filePath")  )   {
		my $index=0;
		while (<FILE>){
			unless ($_ =~ /\S/)  {next;}               ## skip blank lines
			chomp;
			@{$dbArray[$index]} =$self->getRecord($_,$delimiter);
			$key    =$dbArray[$index][0];
			$assocArray{$key}=$dbArray[$index];
			$index++;
		}
		close(FILE);
     } elsif (-e $filePath) {
     	warn "Couldn't read file $filePath";
     } else {
     }
     return \%assocArray;
}

sub submission_error {
	my $self = shift;
    my $msg = join( " ", @_);
	$self->{submitError} .= CGI::br().$msg; 
    return;
}

sub scoring_info {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	
	my $userName          = $r->param('effectiveUser') || $r->param('user');
    my $ur                = $db->getUser($userName);
	my $emailDirectory    = $ce->{courseDirs}->{email};
	my $filePath          = "$emailDirectory/report_grades.msg";
	my $merge_file         = "report_grades_data.csv";
	my $delimiter            = ',';
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
	
	my $SID           = $ur->student_id;
	my $FN            = $ur->first_name;
	my $LN            = $ur->last_name;
	my $SECTION       = $ur->section;
	my $RECITATION    = $ur->recitation;
	my $STATUS        = $ur->status;
	my $EMAIL         = $ur->email_address;
	my $LOGIN         = $ur->user_id;
	my @COL           = defined($rh_merge_data->{$SID}) ? @{$rh_merge_data->{$SID} } : ();
	my $endCol        = @COL;
	# for safety, only evaluate special variables
	my $msg = $text; 
	$msg =~ s/(\$PAR)/<p>/ge;
	$msg =~ s/(\$BR)/<br>/ge;
	
 	$msg =~ s/(\$SID)/eval($1)/ge;
 	$msg =~ s/(\$LN)/eval($1)/ge;
 	$msg =~ s/(\$FN)/eval($1)/ge;
 	$msg =~ s/(\$STATUS)/eval($1)/ge;
 	$msg =~ s/(\$SECTION)/eval($1)/ge;
 	$msg =~ s/(\$RECITATION)/eval($1)/ge;
 	$msg =~ s/(\$EMAIL)/eval($1)/ge;
 	$msg =~ s/(\$LOGIN)/eval($1)/ge;
 	$msg =~ s/\$COL\[ *-/\$COL\[$endCol-/g;
 	$msg =~ s/(\$COL\[.*?\])/eval($1)/ge;
 	
 	$msg =~ s/\r//g;
	return CGI::div(
		{style =>"background-color:#DDDDDD"}, "More scoring information goes here in \$emailDirectory/report_grades.msg. It
		is merged with the file \$scoringDirectory/report_grades_data.csv. <p>
		<pre>$msg</pre>"
	);
}

sub displayStudentStats {
	my ($self, $studentName) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	
	my $courseName = $ce->{courseName};
	my $studentRecord = $db->getUser($studentName); # checked
	die "record for user $studentName not found" unless $studentRecord;
	my $root = $ce->{webworkURLs}->{root};
	
	my @setIDs    = sort $db->listUserSets($studentName);
	my $fullName = join("", $studentRecord->first_name," ", $studentRecord->last_name);
	my $act_as_student_url = "$root/$courseName/?user=".$r->param("user").
			"&effectiveUser=".$studentRecord->user_id()."&key=".$r->param("key");

	print CGI::h3($fullName ), 

	
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
		CGI::start_table({-border=>5,style=>'font-size:smaller'}),
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
    else {return "## ";}
}
sub round_score{
	return shift;
}
1;
