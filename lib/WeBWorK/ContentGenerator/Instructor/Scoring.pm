################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader$
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

package WeBWorK::ContentGenerator::Instructor::Scoring;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME
 
WeBWorK::ContentGenerator::Instructor::Scoring - Generate scoring data files

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readFile formatDateTime);
use WeBWorK::DB::Utils qw(initializeUserProblem);
use WeBWorK::Timing;

sub initialize {
	my ($self)     = @_;
	my $r          = $self->{r};
	my $ce         = $self->{ce};
	my $db         = $self->{db};
	my $authz      = $self->{authz};
	my $scoringDir = $ce->{courseDirs}->{scoring};
	my $courseName = $ce->{courseName};
	my $user       = $r->param('user');

	unless ($authz->hasPermissions($user, "score_sets")) {
		$self->{submitError} = "You aren't authorized to score problem sets";
		return;
	}

	

	
	
	if (defined $r->param('scoreSelected')) {
		my @selected               = $r->param('selectedSet');
		my @totals                 = ();
		my $recordSingleSetScores  = $r->param('recordSingleSetScores');
		
		my $scoringType            = ($recordSingleSetScores) ?'everything':'totals';
		my (@everything, @normal,@full,@info,@totalsColumn);
		@info                      = $self->scoreSet($selected[0], "info");
		@totals                    =@info;
		my $showIndex              = defined($r->param('includeIndex')) ? defined($r->param('includeIndex')) : 0;  
     
		foreach my $setID (@selected) {
			if ($scoringType eq 'everything') {
				@everything = $self->scoreSet($setID, "everything",$showIndex);
				@normal = $self->everything2normal(@everything);
				@full = $self->everything2full(@everything);
				@info = $self->everything2info(@everything);
				@totalsColumn = $self->everything2totals(@everything);
				$self->appendColumns(\@totals, \@totalsColumn);
				$self->writeCSV("$scoringDir/s${setID}scr.csv", @normal);
				$self->writeCSV("$scoringDir/s${setID}ful.csv", @full);				
			} else {
				@totalsColumn  = $self->scoreSet($setID, "totals",$showIndex);
				$self->appendColumns(\@totals, \@totalsColumn);
			}	
		}
		$self->writeCSV("$scoringDir/${courseName}_totals.csv", @totals);
	}   
	
	# Obtaining list of sets:
	$WeBWorK::timer->continue("Begin listing sets") if defined $WeBWorK::timer;
	my @setNames =  $db->listGlobalSets();
	$WeBWorK::timer->continue("End listing sets") if defined $WeBWorK::timer;
	my @set_records = ();
	$WeBWorK::timer->continue("Begin obtaining sets") if defined $WeBWorK::timer;
	@set_records = $db->getGlobalSets( @setNames);
	$WeBWorK::timer->continue("End obtaining sets: ".@set_records) if defined $WeBWorK::timer;
	
	
	# store data
	$self->{ra_sets}              =   \@setNames;
	$self->{ra_set_records}       =   \@set_records;
	
	
	
}

sub title {
	"Scoring data for ".(shift)->{ce}->{courseName};
}

sub body {
	my ($self) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $scoringDir = $ce->{courseDirs}->{scoring};
	my $courseName = $ce->{courseName};
	my $user = $r->param('user');
	my $actionURL= $r->uri;
	
	
	print join("",
			CGI::start_form(-method=>"POST", -action=>$actionURL),"\n",
			$self->hidden_authen_fields,"\n",
			CGI::hidden({-name=>'scoreSelected', -value=>1}),
			$self->popup_set_form,
			CGI::br(),
			CGI::checkbox({ -name=>'includeIndex',
							-value=>1,
							-label=>'IncludeIndex',
							-checked=>1,
						   },
						   'Include Index'
			),
			CGI::br(),
			CGI::checkbox({ -name=>'recordSingleSetScores',
							-value=>1,
							-label=>'Record Scores for Single Sets',
							-checked=>0,
						  },
						 'Record Scores for Single Sets'
			),
			CGI::br(),
			CGI::input({type=>'submit',value=>'Score selected set(s)...',name=>'score-sets'}),
			
	);

	
	if ($authz->hasPermissions($user, "score_sets")) {
		my @selected = $r->param('selectedSet');
		print CGI::p("All of these files will also be made available for mail merge");
		foreach my $setID (@selected) {
			print CGI::h2("$setID");
			foreach my $type ("scr", "ful") {
				my $filename = "s$setID$type.csv";
				my $path = "$scoringDir/$filename";
				if (-f $path) {
					print CGI::a({href=>"../scoringDownload/?getFile=${filename}&".$self->url_authen_args}, $filename);
					print CGI::br();
				}
			}
			print CGI::hr();
		}
		print CGI::h2("Totals");
		print CGI::a({href=>"../scoringDownload/?getFile=${courseName}_totals.csv&".$self->url_authen_args}, "${courseName}_totals.csv");
		print CGI::hr();
		print CGI::pre(WeBWorK::Utils::readFile("$scoringDir/${courseName}_totals.csv"));
	}
	
	return "";
}

# If, some day, it becomes possible to assign a different number of problems to each student, this code
# will have to be rewritten some.
# $format can be any of "normal", "full", "everything", "info", or "totals".  An undefined value defaults to "normal"
#   normal: student info, the status of each problem in the set, and a "totals" column
#   full: student info, the status of each problem, and the number of correct and incorrect attempts
#   everything: "full" plus a totals column
#   info: student info columns only
#   totals: total column only
sub scoreSet {
	my ($self, $setID, $format, $showIndex) = @_;
	my $db = $self->{db};
	my @scoringData;
	my $scoringItems   = {    info             => 0,
		                      successIndex     => 0,
		                      setTotals        => 0,
		                      problemScores    => 0,
		                      problemAttempts  => 0, 
		                      header           => 0,
	};
	$format = "normal" unless defined $format;
	$format = "normal" unless $format eq "full" or $format eq "everything" or $format eq "totals" or $format eq "info";
	my $columnsPerProblem = ($format eq "full" or $format eq "everything") ? 3 : 1;
	my $setRecord = $db->getGlobalSet($setID);
	my %users;
	my %userStudentID=();
	$WeBWorK::timer->continue("Begin getting users for set $setID") if defined($WeBWorK::timer);
	foreach my $userID ($db->listUsers()) {
		my $userRecord = $db->getUser($userID);
		# The key is what we'd like to sort by.
		$users{$userRecord->student_id} = $userRecord;
		$userStudentID{$userID} = $userRecord->student_id;
	}
	$WeBWorK::timer->continue("End getting users for set $setID") if defined($WeBWorK::timer);
	
	my @problemIDs = $db->listGlobalProblems($setID);

	# determine what information will be returned
	if ($format eq 'normal') {
		$scoringItems  = {    info             => 1,
		                      successIndex     => $showIndex,
		                      setTotals        => 1,
		                      problemScores    => 1,
		                      problemAttempts  => 0, 
		                      header           => 1,
		};
	} elsif ($format eq 'full') {
		$scoringItems  = {    info             => 1,
		                      successIndex     => $showIndex,
		                      setTotals        => 0,
		                      problemScores    => 1,
		                      problemAttempts  => 1, 
		                      header           => 1,
		};
	} elsif ($format eq 'everything') {
		$scoringItems  = {    info             => 1,
		                      successIndex     => $showIndex,
		                      setTotals        => 1,
		                      problemScores    => 1,
		                      problemAttempts  => 1, 
		                      header           => 1,
		};
	} elsif ($format eq 'totals') {
		$scoringItems  = {    info             => 0,
		                      successIndex     => $showIndex,
		                      setTotals        => 1,
		                      problemScores    => 0,
		                      problemAttempts  => 0, 
		                      header           => 0,
		};
	} elsif ($format eq 'info') {
		$scoringItems  = {    info             => 0,
		                      successIndex     => 0,
		                      setTotals        => 0,
		                      problemScores    => 0,
		                      problemAttempts  => 0, 
		                      header           => 1,
		};
	} else {
		warn "unrecognized format";
	}
	
	# Initialize a two-dimensional array of the proper size
	for (my $i = 0; $i < keys(%users) + 7; $i++) { # 7 is how many descriptive fields there are in each column
		push @scoringData, [];
	}
	
	my @userInfoColumnHeadings = ("STUDENT ID", "LAST NAME", "FIRST NAME", "SECTION", "RECITATION");
	my @userInfoFields = ("student_id", "last_name", "first_name", "section", "recitation");
	my @userKeys = sort keys %users;
	
	if ($scoringItems->{header}) {
		$scoringData[0][0] = "NO OF FIELDS";
		$scoringData[1][0] = "SET NAME";
		$scoringData[2][0] = "PROB NUMBER";
		$scoringData[3][0] = "DUE DATE";
		$scoringData[4][0] = "DUE TIME";
		$scoringData[5][0] = "PROB VALUE";

	
	
	# Write identifying information about the users

		for (my $field=0; $field < @userInfoFields; $field++) {
			if ($field > 0) {
				for (my $i = 0; $i < 6; $i++) {
					$scoringData[$i][$field] = "";
				}
			}
			$scoringData[6][$field] = $userInfoColumnHeadings[$field];
			for (my $user = 0; $user < @userKeys; $user++) {
				my $fieldName = $userInfoFields[$field];
				$scoringData[7 + $user][$field] = $users{$userKeys[$user]}->$fieldName;
			}
		}
	}
	return @scoringData if $format eq "info";
	
	# Write the problem data
	my $dueDateString = formatDateTime($setRecord->due_date);
	my ($dueDate, $dueTime) = $dueDateString =~ m/^([^\s]*)\s*([^\s]*)$/;
	my $valueTotal = 0;
	my %userStatusTotals = ();
	my %userSuccessIndex = ();
	my %numberOfAttempts = ();
	my $num_of_problems  = @problemIDs;
	for (my $problem = 0; $problem < @problemIDs; $problem++) {
		my $globalProblem = $db->getGlobalProblem($setID, $problemIDs[$problem]);
		my $column = 5 + $problem * $columnsPerProblem;
		if ($scoringItems->{header}) {
			$scoringData[0][$column] = "";
			$scoringData[1][$column] = $setRecord->set_id;
			$scoringData[2][$column] = $globalProblem->problem_id;
			$scoringData[3][$column] = $dueDate;
			$scoringData[4][$column] = $dueTime;
			$scoringData[5][$column] = $globalProblem->value;
			$scoringData[6][$column] = "STATUS";
			if ($scoringItems->{header} and $scoringItems->{problemAttempts}) { # Fill in with blanks, or maybe the problem number
				for (my $row = 0; $row < 6; $row++) {
					for (my $col = $column+1; $col <= $column + 2; $col++) {
						if ($row == 2) {
							$scoringData[$row][$col] = $globalProblem->problem_id;
						} else {
							$scoringData[$row][$col] = "";
						}
					}
				}
				$scoringData[6][$column + 1] = "#corr";
				$scoringData[6][$column + 2] = "#incorr";
			}
		}
		$valueTotal += $globalProblem->value;
		
 		my @userLoginIDs = $db->listUsers();
 		$WeBWorK::timer->continue("Begin getting user problems for set $setID, problem $problemIDs[$problem]") if defined($WeBWorK::timer);
 		#my @userProblems = $db->getMergedProblems( map { [ $_, $setID, $problemIDs[$problem] ] } @userLoginIDs );
 		my @userProblems = $db->getUserProblems( map { [ $_, $setID, $problemIDs[$problem] ] }    @userLoginIDs );
 		my %userProblems;
 		foreach my $item (@userProblems) {
 			$userProblems{$item->user_id} = $item if ref $item;
 		}
 		$WeBWorK::timer->continue("End getting user problems for set $setID, problem $problemIDs[$problem]") if defined($WeBWorK::timer);
		for (my $user = 0; $user < @userKeys; $user++) {
			my $userProblem = $userProblems{    $users{$userKeys[$user]}->user_id   };
			unless (defined $userProblem) { # assume an empty problem record if the problem isn't assigned to this user
				$userProblem = $db->newUserProblem;
				$userProblem->status(0);
				$userProblem->value(0);
				$userProblem->num_correct(0);
				$userProblem->num_incorrect(0);
			}
			$userStatusTotals{$user} = 0 unless exists $userStatusTotals{$user};
			#$userStatusTotals{$user} += $userProblem->status * $userProblem->value;
			$userStatusTotals{$user} += $userProblem->status * $globalProblem->value;	
			if ($scoringItems->{successIndex})   {
				$numberOfAttempts{$user}  = 0 unless defined($numberOfAttempts{$user});
				my $num_correct     = $userProblem->num_correct;
				my $num_incorrect   = $userProblem->num_incorrect;
				$num_correct        = ( defined($num_correct) and $num_correct) ? $num_correct : 0;
				$num_incorrect      = ( defined($num_incorrect) and $num_incorrect) ? $num_incorrect : 0;
				$numberOfAttempts{$user} += $num_correct + $num_incorrect;	 
			}
			if ($scoringItems->{problemScores}) {
				$scoringData[7 + $user][$column] = $userProblem->status;
				if ($scoringItems->{problemAttempts}) {
					$scoringData[7 + $user][$column + 1] = $userProblem->num_correct;
					$scoringData[7 + $user][$column + 2] = $userProblem->num_incorrect;
				}
			}
		}
	}
	if ($scoringItems->{successIndex}) {
		for (my $user = 0; $user < @userKeys; $user++) {
			my $avg_num_attempts = ($num_of_problems) ? $numberOfAttempts{$user}/$num_of_problems : 0;
			$userSuccessIndex{$user} = ($avg_num_attempts) ? ($userStatusTotals{$user}/$valueTotal)**2/$avg_num_attempts : 0;						
		}
	}
	# write the status totals
	if ($scoringItems->{setTotals}) { # Ironic, isn't it?
		my $totalsColumn = $format eq "totals" ? 0 : 5 + @problemIDs * $columnsPerProblem;
		$scoringData[0][$totalsColumn]    = "";
		$scoringData[1][$totalsColumn]    = $setRecord->set_id;
		$scoringData[1][$totalsColumn+1]  = $setRecord->set_id if $scoringItems->{successIndex};
		$scoringData[2][$totalsColumn]    = "";
		$scoringData[3][$totalsColumn]    = "";
		$scoringData[4][$totalsColumn]    = "";
		$scoringData[5][$totalsColumn]    = $valueTotal;
		$scoringData[6][$totalsColumn]    = "total";
		$scoringData[6][$totalsColumn+1]  = "index" if $scoringItems->{successIndex};
		for (my $user = 0; $user < @userKeys; $user++) {
			$scoringData[7+$user][$totalsColumn] = $userStatusTotals{$user};
			$scoringData[7+$user][$totalsColumn+1] = $userSuccessIndex{$user} if $scoringItems->{successIndex};
		}
	}
	$WeBWorK::timer->continue("End  set $setID") if defined($WeBWorK::timer);
	return @scoringData;
}

# Often it's more efficient to just get everything out of the database
# and then pick out what you want later.  Hence, these "everything2*" functions
sub everything2info {
	my ($self, @everything) = @_;
	my @result = ();
	foreach my $row (@everything) {
		push @result, [@{$row}[0..4]];
	}
	return @result;
}

sub everything2normal {
	my ($self, @everything) = @_;
	my @result = ();
	foreach my $row (@everything) {
		my @row = @$row;
		my @newRow = ();
		push @newRow, @row[0..4];
		for (my $i = 5; $i < @row; $i+=3) {
			push @newRow, $row[$i];
		}
		#push @newRow, $row[$#row];
		push @result, [@newRow];
	}
	return @result;
}

sub everything2full {
	my ($self, @everything) = @_;
	my @result = ();
	foreach my $row (@everything) {
		push @result, [@{$row}[0..($#{$row}-1)]];
	}
	return @result;
}

sub everything2totals {
	my ($self, @everything) = @_;
	my @result = ();
	foreach my $row (@everything) {
		push @result, [${$row}[$#{$row}]];
	}
	return @result;
}

sub appendColumns {
	my ($self, $a1, $a2) = @_;
	my @a1 = @$a1;
	my @a2 = @$a2;
	for (my $i = 0; $i < @a1; $i++) {
		push @{$a1[$i]}, @{$a2[$i]};
	}
}

# Reads a CSV file and returns an array of arrayrefs, each containing a
# row of data:
# (["c1r1", "c1r2", "c1r3"], ["c2r1", "c2r2", "c2r3"])
sub readCSV {
	my ($self, $fileName) = @_;
	my @result = ();
	my @rows = split m/\n/, readFile($fileName);
	foreach my $row (@rows) {
		push @result, [split m/\s*,\s*/, $row];
	}
	return @result;
}

# Write a CSV file from an array in the same format that readCSV produces
sub writeCSV {
	my ($self, $filename, @csv) = @_;
	
	my @lengths = ();
	for (my $row = 0; $row < @csv; $row++) {
		for (my $column = 0; $column < @{$csv[$row]}; $column++) {
			$lengths[$column] = 0 unless defined $lengths[$column];
			$lengths[$column] = length $csv[$row][$column] if defined($csv[$row][$column]) and length $csv[$row][$column] > $lengths[$column];
		}
	}
	
	open my $fh, ">", $filename or warn "Unable to open $filename for writing";
	foreach my $row (@csv) {
		my @rowPadded = ();
		foreach (my $column = 0; $column < @$row; $column++) {
			push @rowPadded, $self->pad($row->[$column], $lengths[$column] + 1);
		}
		print $fh join(",", @rowPadded);
		print $fh "\n";
	}
	close $fh;
}

# As soon as backwards compatability is no longer a concern and we don't expect to have
# to use old ww1.x code to read the output anymore, I recommend switching to using
# these routines, which are more versatile and compatable with other programs which
# deal with CSV files.
sub readStandardCSV {
	my ($self, $fileName) = @_;
	my @result = ();
	my @rows = split m/\n/, readFile($fileName);
	foreach my $row (@rows) {
		push @result, [$self->splitQuoted($row)];
	}
	return @result;
}

sub writeStandardCSV {
	my ($self, $filename, @csv) = @_;
	open my $fh, ">", $filename;
	foreach my $row (@csv) {
		print $fh (join ",", map {$self->quote($_)} @$row);
		print $fh "\n";
	}
	close $fh;
}

###

# This particular unquote method unquotes (optionally) quoted strings in the
# traditional CSV style (double-quote for literal quote, etc.)
sub unquote {
	my ($self, $string) = @_;
	if ($string =~ m/^"(.*)"$/) {
		$string = $1;
		$string =~ s/""/"/;
	}
	return $string;
}

# Should you wish to treat whitespace differently, this routine has been designed
# to make it easy to do so.
sub splitQuoted {
	my ($self, $string) = @_;
	my ($leadingSpace, $preText, $quoted, $postText, $trailingSpace, $result);
	my @result = ();
	my $continue = 1;
	while ($continue) {
		$string =~ m/\G(\s*)/gc;
		$leadingSpace = $1;
		$string =~ m/\G([^",]*)/gc;
		$preText = $1;
		if ($string =~ m/\G"((?:[^"]|"")*)"/gc) {
			$quoted = $1;
		}
		$string =~ m/\G([^,]*?)(\s*)(,?)/gc;
		($postText, $trailingSpace, $continue) = ($1, $2, $3);

		$preText = "" unless defined $preText;
		$postText = "" unless defined $postText;
		$quoted = "" unless defined $quoted;

		if ($quoted and (not $preText and not $postText)) {
				$quoted =~ s/""/"/;
				$result = $quoted;
		} else {
			$result = "$preText$quoted$postText";
		}
		push @result, $result;
	}
	return @result;
}

# This particular quoting method does CSV-style (double a quote to escape it) quoting when necessary.
sub quote {
	my ($self, $string) = @_;
	if ($string =~ m/[", ]/) {
		$string =~ s/"/""/;
		$string = "\"$string\"";
	}
	return $string;
}

sub pad {
	my ($self, $string, $padTo) = @_;
	$string = '' unless defined $string;
	my $spaces = $padTo - length $string;
	return $string . " "x$spaces;
}

sub maxLength {
	my ($self, $arrayRef) = @_;
	my $max = 0;
	foreach my $cell (@$arrayRef) {
		$max = length $cell unless length $cell < $max;
	}
	return $max;
}

sub popup_set_form {
	my $self  = shift;
	my $r     = $self->{r};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};

 #     return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");

	# This code will require changing if the permission and user tables ever have different keys.
    my @setNames              = ();
	my $ra_set_records        = $self->{ra_set_records};
	my %setLabels             = ();#  %$hr_classlistLabels;
	my @set_records           =  sort {$a->set_id cmp $b->set_id } @{$ra_set_records};
	foreach my $sr (@set_records) {
 		$setLabels{$sr->set_id} = $sr->set_id;
 		push(@setNames, $sr->set_id);  # reorder sets
	}
 	return 			CGI::popup_menu(-name=>'selectedSet',
 							   -values=>\@setNames,
 							   -labels=>\%setLabels,
 							   -size  => 10,
 							   -multiple => 1,
 							   #-default=>$user
 					),


}
1;
