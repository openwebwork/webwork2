################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/Scoring.pm,v 1.62 2007/03/07 17:34:42 glarose Exp $
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
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Utils qw(readFile seq_to_jitar_id jitar_id_to_seq jitar_problem_adjusted_status wwRound x);
use WeBWorK::ContentGenerator::Instructor::FileManager;

our @userInfoColumnHeadings = (x("STUDENT ID"), x("login ID"), x("LAST NAME"), x("FIRST NAME"), x("SECTION"), x("RECITATION"));
our @userInfoFields = ("student_id", "user_id","last_name", "first_name", "section", "recitation");

sub initialize {
	my ($self)     = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $ce         = $r->ce;
	my $db         = $r->db;
	my $authz      = $r->authz;
	my $scoringDir = $ce->{courseDirs}->{scoring};
	my $courseName = $urlpath->arg("courseID");
	my $user       = $r->param('user');
    
	# Check permission
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	return unless $authz->hasPermissions($user, "score_sets");
	
	my @selected = $r->param('selectedSet');
	my $scoreSelected = $r->param('scoreSelected');
	my $scoringFileName = $r->param('scoringFileName') || "${courseName}_totals";
	$scoringFileName =~ s/\.csv\s*$//; $scoringFileName .='.csv';  # must end in .csv
	my $scoringFileNameOK = (
		$scoringFileName eq  WeBWorK::ContentGenerator::Instructor::FileManager::checkName($scoringFileName)
	);
	$self->{scoringFileName}=$scoringFileName;
	
	$self->{padFields}  = defined($r->param('padFields') ) ? 1 : 0; 
	
	if (defined $scoreSelected && @selected && $scoringFileNameOK) {

		my @totals                 = ();
		my $recordSingleSetScores  = $r->param('recordSingleSetScores');
		
		# pre-fetch users
		debug("pre-fetching users");
		# DBFIXME shouldn't need ID list
		my @Users = $db->getUsers($db->listUsers);
		my %Users;
		foreach my $User (@Users) {
			next unless $User;
			next unless $ce->status_abbrev_has_behavior($User->status, "include_in_scoring");
			$Users{$User->user_id} = $User;
		}
		# DBFIXME use an ORDER BY clause in the database
		my @sortedUserIDs = sort { 
			lc($Users{$a}->last_name) cmp lc($Users{$b}->last_name) 
				||
			lc($Users{$a}->first_name) cmp lc($Users{$b}->first_name)
				||
			lc($Users{$a}->user_id) cmp lc($Users{$b}->user_id)
			}

			keys %Users;
		#my @userInfo = (\%Users, \@sortedUserIDs);
		debug("done pre-fetching users");
		
		my $scoringType            = ($recordSingleSetScores) ?'everything':'totals';
		my (@everything, @normal,@full,@info,@totalsColumn);
		@info             = $self->scoreSet($selected[0], "info", undef, \%Users, \@sortedUserIDs) if defined($selected[0]);
		@totals           = @info;
		my $showIndex     = defined($r->param('includeIndex')) ? defined($r->param('includeIndex')) : 0; 
		
     
		foreach my $setID (@selected) {
		    next unless defined $setID;
			if ($scoringType eq 'everything') {
				@everything = $self->scoreSet($setID, "everything", $showIndex, \%Users, \@sortedUserIDs);
				@normal = $self->everything2normal(@everything);
				@full = $self->everything2full(@everything);
				@info = $self->everything2info(@everything);
				@totalsColumn = $self->everything2totals(@everything);
				$self->appendColumns(\@totals, \@totalsColumn);
				$self->writeCSV("$scoringDir/s${setID}scr.csv", @normal);
				$self->writeCSV("$scoringDir/s${setID}ful.csv", @full);				
			} else {
				@totalsColumn  = $self->scoreSet($setID, "totals", $showIndex, \%Users, \@sortedUserIDs);
				$self->appendColumns(\@totals, \@totalsColumn);
			}	
		}
		my @sum_scores  = $self->sumScores(\@totals, $showIndex, \%Users, \@sortedUserIDs);
		$self->appendColumns( \@totals,\@sum_scores);
		$self->writeCSV("$scoringDir/$scoringFileName", @totals);

	} else {
		if (!@selected) {  # nothing selected for scoring
			$self->addbadmessage($r->maketext("You must select one or more sets for scoring!"));
		}
		if (!$scoringFileNameOK) { # fileName is not properly formed
			$self->addbadmessage($r->maketext("Your file name is not valid! "));
		    $self->addbadmessage($r->maketext("A file name cannot begin with a dot, it cannot be empty, it cannot contain a " .
				 "directory path component and only the characters -_.a-zA-Z0-9 and space  are allowed.")
			); 
		}
	}
	
	# Obtaining list of sets:
	my @setNames =  $db->listGlobalSets();
	my @set_records = ();
	# DBFIXME shouldn't need ID list
	@set_records = $db->getGlobalSets( @setNames); 
	
	
	# store data
	$self->{ra_sets}              =   \@setNames; # ra_sets IS NEVER USED AGAIN!!!!!
	$self->{ra_set_records}       =   \@set_records;
}


sub body {
	my ($self)      = @_;
	my $r           = $self->r;
	my $urlpath     = $r->urlpath;
	my $ce          = $r->ce;
	my $authz       = $r->authz;
	my $scoringDir  = $ce->{courseDirs}->{scoring};
	my $courseName  = $urlpath->arg("courseID");
	my $user        = $r->param('user');
	
	my $scoringPage       = $urlpath->newFromModule($urlpath->module, $r, courseID => $courseName);
	my $scoringURL        = $self->systemLink($scoringPage, authen=>0);
	
	my $scoringDownloadPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::ScoringDownload", $r,  
	                                      courseID => $courseName
	);
	
	my $scoringFileName = $self->{scoringFileName};
	
	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to score sets.")
		unless $authz->hasPermissions($user, "score_sets");

	print join("",
			CGI::start_form(-name=>"scoring-form", -id=>"scoring-form", -method=>"POST", -action=>$scoringURL),"\n",
			$self->hidden_authen_fields,"\n",
			CGI::hidden({-name=>'scoreSelected', -value=>1}),
			CGI::start_table({border=>1,}),
				CGI::Tr({},
					CGI::td($self->popup_set_form),
					CGI::td({},
						CGI::checkbox({ -name=>'includeIndex',
										-value=>1,
										-label=>$r->maketext('Include Success Index'),
										-checked=>0,
									   },
						),
						CGI::br(),
						# These are not yet implemented
						#CGI::checkbox({ -name=>'includeTotals',
						#				-value=>1,
						#				-label=>'Include Total score column',
						#				-checked=>1,
						#			   },
						#),
						#CGI::br(),
						#CGI::checkbox({ -name=>'includePercent',
						#				-value=>1,
						#				-label=>'Include Percent correct column',
						#				-checked=>1,
						#			   },
						#),
						#CGI::br(),
						CGI::checkbox({ -name=>'recordSingleSetScores',
										-value=>1,
										-label=>$r->maketext('Record Scores for Single Sets'),
										-checked=>0,
									  },
									 'Record Scores for Single Sets'
						),
						CGI::br(),
						CGI::checkbox({ -name=>'padFields',
										-value=>1,
										-label=>$r->maketext('Pad Fields'),
										-checked=>1,
									  },
									 'Pad Fields'
						),
					),
				),
				CGI::Tr(CGI::td({colspan =>2,align=>'center'},
					CGI::input({type=>'submit',value=>$r->maketext('Score selected set(s) and save to:'),name=>'score-sets'}),
					CGI::input({type=>'text', name=>'scoringFileName', size=>'40',value=>"$scoringFileName"})
				)),
			
		   CGI::end_table(),
		   CGI::end_form(),
	);

	
	if ($authz->hasPermissions($user, "score_sets")) {
		my @selected = $r->param('selectedSet');
		if (@selected) {
			print CGI::p($r->maketext("All of these files will also be made available for mail merge."));
		} 
		foreach my $setID (@selected) {
	
			my @validFiles;
			foreach my $type ("scr", "ful") {
				my $filename = "s$setID$type.csv";
				my $path = "$scoringDir/$filename";
				push @validFiles, $filename if -f $path;
			}
			if (@validFiles) {
				print CGI::h2("$setID");
				foreach my $filename (@validFiles) {
					#print CGI::a({href=>"../scoringDownload/?getFile=${filename}&".$self->url_authen_args}, $filename);
					print CGI::a({href=>$self->systemLink($scoringDownloadPage,
					               params=>{getFile => $filename } )}, $filename);
					print CGI::br();
				}
				print CGI::hr();
			}
		}
		if (-f "$scoringDir/$scoringFileName") {
			print CGI::h2($r->maketext("Totals"));
			#print CGI::a({href=>"../scoringDownload/?getFile=${courseName}_totals.csv&".$self->url_authen_args}, "${courseName}_totals.csv");
			print CGI::a({href=>$self->systemLink($scoringDownloadPage,
					               params=>{getFile => "$scoringFileName" } )}, "$scoringFileName");
			print CGI::hr();
			print CGI::pre({style=>'font-size:smaller'},WeBWorK::Utils::readFile("$scoringDir/$scoringFileName"));
		}
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
	my ($self, $setID, $format, $showIndex, $UsersRef, $sortedUserIDsRef) = @_;
	my $r  = $self->r;
	my $db = $r->db;
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

	# DBFIXME these have already been fetched in ra_set_records
	my $setRecord = $db->getGlobalSet($setID); #checked
	die "global set $setID not found. " unless $setRecord;
	#my %users;
	#my %userStudentID=();
	#foreach my $userID ($db->listUsers()) {
	#	my $userRecord = $db->getUser($userID); # checked
	#	die "user record for $userID not found" unless $userID;
	#	# FIXME: if two users have the same student ID, the second one will
	#	# clobber the first one. this is bad!
	#	# The key is what we'd like to sort by.
	#	$users{$userRecord->student_id} = $userRecord;
	#	$userStudentID{$userID} = $userRecord->student_id;
	#}
	
	my %Users = %$UsersRef; # user objects hashed on user ID
	my @sortedUserIDs = @$sortedUserIDsRef; # user IDs sorted by student ID
	
	my @problemIDs = $db->listGlobalProblems($setID);
	
	my $isJitarSet = $setRecord->assignment_type eq 'jitar';

	if ($isJitarSet) {
	  $columnsPerProblem++
	};
	
	
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
	for (my $i = 0; $i < @sortedUserIDs + 7; $i++) { # 7 is how many descriptive fields there are in each column
		push @scoringData, [];
	}
	
	#my @userKeys = sort keys %users; # list of "student IDs" NOT user IDs
	
	if ($scoringItems->{header}) {
		$scoringData[0][0] = $r->maketext("NO OF FIELDS");
		$scoringData[1][0] = $r->maketext("SET NAME");
		$scoringData[2][0] = $r->maketext("PROB NUMBER");
		$scoringData[3][0] = $r->maketext("CLOSE DATE");
		$scoringData[4][0] = $r->maketext("CLOSE TIME");
		$scoringData[5][0] = $r->maketext("PROB VALUE");

	
	
	# Write identifying information about the users

		for (my $field=0; $field < @userInfoFields; $field++) {
			if ($field > 0) {
				for (my $i = 0; $i < 6; $i++) {
					$scoringData[$i][$field] = "";
				}
			}
			$scoringData[6][$field] = $r->maketext($userInfoColumnHeadings[$field]);
			for (my $user = 0; $user < @sortedUserIDs; $user++) {
				my $fieldName = $userInfoFields[$field];
				$scoringData[$user + 7][$field] = $Users{$sortedUserIDs[$user]}->$fieldName;
			}
		}
	}
	return @scoringData if $format eq "info";
	
	# pre-fetch global problems
	debug("pre-fetching global problems for set $setID");
	my %GlobalProblems = map { $_->problem_id => $_ }
		$db->getAllGlobalProblems($setID);
	debug("done pre-fetching global problems for set $setID");
	
	# pre-fetch user problems
	debug("pre-fetching user problems for set $setID");
	my %UserProblems; # $UserProblems{$userID}{$problemID}

  # Gateway change here: for non-gateway (non-versioned) sets, we just 
  # get each user's problems.  For gateway (versioned) sets, we get the 
  # user's best version and return that
	if ( ! defined( $setRecord->assignment_type() ) ||
	     $setRecord->assignment_type() !~ /gateway/) {
		foreach my $userID (@sortedUserIDs) {
			my %CurrUserProblems = map { $_->problem_id => $_ }
				$db->getAllMergedUserProblems($userID, $setID);
			$UserProblems{$userID} = \%CurrUserProblems;
		}
	} elsif ($setRecord->assignment_type() =~ /gateway/) {  # versioned sets; get the problems for the best version 

		foreach my $userID (@sortedUserIDs) {
			my $CurrUserProblems = {};
			my @versionNums = $db->listSetVersions($userID,$setID);

			my $bestScore = -1;

			if ( @versionNums ) {
			    for my $i ( @versionNums ) {
				my %versionUserProblems = map { $_->problem_id => $_ }
					$db->getAllMergedProblemVersions( $userID, $setID, $i );
				my $score = 0;
				foreach ( values ( %versionUserProblems ) ) {
					my $status = $_->status || 0;
					my $value = $_->value || 1;
				# some of these are coming in null; I'm not
				# why, or if this should be necessary
					$_->status($status);
					$_->value($value);
					$score += $status*$value;
				}
				if ( $score > $bestScore ) {
					$CurrUserProblems = \%versionUserProblems;
					$bestScore = $score;
				}
			    }
			} else {
			    my %cp = map { $_->problem_id => $_ }
				$db->getAllMergedUserProblems($userID, $setID);
			    $CurrUserProblems = \%cp;
			}
			$UserProblems{$userID} = { %{$CurrUserProblems} };
		}
	} 
	  

	debug("done pre-fetching user problems for set $setID");

	# Write the problem data
	my $dueDateString = $self->formatDateTime($setRecord->due_date);
	my ($dueDate, $dueTime) = $dueDateString =~ /^(.*) at (.*)$/;
	my $valueTotal = 0;
	my %userStatusTotals = ();
	my %userSuccessIndex = ();
	my %numberOfAttempts = ();
	my $num_of_problems  = @problemIDs;
	for (my $problem = 0; $problem < @problemIDs; $problem++) {
		
		#my $globalProblem = $db->getGlobalProblem($setID, $problemIDs[$problem]); #checked
		my $globalProblem = $GlobalProblems{$problemIDs[$problem]};
		die "global problem $problemIDs[$problem] not found for set $setID" unless $globalProblem;
		
		my $column = 5 + $problem * $columnsPerProblem;
		if ($scoringItems->{header}) {
		        my $prettyProblemID = $globalProblem->problem_id;
		        if ($isJitarSet && $globalProblem->problem_id) {
			  $prettyProblemID = join('.',jitar_id_to_seq($prettyProblemID));
			}

			$scoringData[0][$column] = "";
			$scoringData[1][$column] = $setRecord->set_id;
			$scoringData[2][$column] = $prettyProblemID;
			$scoringData[3][$column] = $dueDate;
			$scoringData[4][$column] = $dueTime;
			$scoringData[5][$column] = $globalProblem->value;
			$scoringData[6][$column] = $r->maketext("STATUS");
			my $extraColumns = 0;
			if ($isJitarSet) {
			  $extraColumns++;
			  $scoringData[6][$column + $extraColumns] = $r->maketext("ADJ STATUS");
			}
			
			if ($scoringItems->{header} and
			    $scoringItems->{problemAttempts}) { # Fill in with blanks, or maybe the problem number
			  $extraColumns++;
			  $scoringData[6][$column + $extraColumns] = $r->maketext("#corr");
			  $extraColumns++;
			  $scoringData[6][$column + $extraColumns] = $r->maketext("#incorr");
			}

			for (my $row = 0; $row < 6; $row++) {
			  for (my $col = $column+1; $col <= $column + $extraColumns; $col++) {
			    if ($row == 2) {
			      $scoringData[$row][$col] = $prettyProblemID;
			    } else {
			      $scoringData[$row][$col] = "";
			    }
			  }
			}

			
		}
		# if its a jitar set then we only want to add top level problems to the value total
		# otherwise we add up everything
		if ($isJitarSet && $globalProblem->problem_id) {
		    my @seq = jitar_id_to_seq($globalProblem->problem_id);
		    if ($#seq == 0) {
			$valueTotal += $globalProblem->value;
		    }
		} else {
		    $valueTotal += $globalProblem->value;
		}
		
		for (my $user = 0; $user < @sortedUserIDs; $user++) {
			#my $userProblem = $userProblems{    $users{$userKeys[$user]}->user_id   };
			#my $userProblem = $UserProblems{$sers{$userKeys[$user]}->user_id}{$problemIDs[$problem]};
			my $userProblem = $UserProblems{$sortedUserIDs[$user]}{$problemIDs[$problem]};
			unless (defined $userProblem) { # assume an empty problem record if the problem isn't assigned to this user
				$userProblem = $db->newUserProblem;
				$userProblem->status(0);
				$userProblem->value(0);
				$userProblem->num_correct(0);
				$userProblem->num_incorrect(0);
			}
			$userStatusTotals{$user} = 0 unless exists $userStatusTotals{$user};
			my $user_problem_status          = ($userProblem->status =~/^[\d\.]+$/) ? $userProblem->status : 0; # ensure it's numeric
			# the grade is the adjusted status if its a jitar set 
			# and this is an actual problem
			if ($isJitarSet && $userProblem->value) {
			    $user_problem_status = jitar_problem_adjusted_status($userProblem, $db);
			}

			# if its a jitar set then we only want to add top level problems 
			# to the student total score
			# otherwise we add up everything
			if ($isJitarSet && $userProblem->problem_id) {
			    my @seq = jitar_id_to_seq($userProblem->problem_id);
			    if ($#seq == 0) {
				$userStatusTotals{$user} += $user_problem_status * $userProblem->value;	
			    }
			} else {
			    $userStatusTotals{$user} += $user_problem_status * $userProblem->value;	
			}

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
			  my $extraColumns = 0;
			  if ($isJitarSet) {
			    $extraColumns++;
			    $scoringData[7 + $user][$column + $extraColumns] = $user_problem_status;
			  }
			  if ($scoringItems->{problemAttempts}) {
			    $extraColumns++;
			    $scoringData[7 + $user][$column + $extraColumns] = $userProblem->num_correct;
			    $extraColumns++;
			    $scoringData[7 + $user][$column + $extraColumns] = $userProblem->num_incorrect;
			  }
			}
		}
	}
	if ($scoringItems->{successIndex}) {
		for (my $user = 0; $user < @sortedUserIDs; $user++) {
			my $avg_num_attempts = ($num_of_problems) ? $numberOfAttempts{$user}/$num_of_problems : 0;
			$userSuccessIndex{$user} = ($avg_num_attempts && $valueTotal) ? ($userStatusTotals{$user}/$valueTotal)**2/$avg_num_attempts : 0;						
		}
	}
	# write the status totals
	if ($scoringItems->{setTotals}) { # Ironic, isn't it?
		my $totalsColumn = $format eq "totals" ? 0 : 5 + @problemIDs * $columnsPerProblem;
		$scoringData[0][$totalsColumn]    = "";
		$scoringData[1][$totalsColumn]    = $setRecord->set_id;
		$scoringData[2][$totalsColumn]    = "";
		$scoringData[3][$totalsColumn]    = "";
		$scoringData[4][$totalsColumn]    = "";
		$scoringData[5][$totalsColumn]    = $valueTotal;
		$scoringData[6][$totalsColumn]    = $r->maketext("total");
		if ($scoringItems->{successIndex}) {
			$scoringData[0][$totalsColumn+1]    = "";
			$scoringData[1][$totalsColumn+1]    = $setRecord->set_id;
			$scoringData[2][$totalsColumn+1]    = "";
			$scoringData[3][$totalsColumn+1]    = "";
			$scoringData[4][$totalsColumn+1]    = "";
			$scoringData[5][$totalsColumn+1]    = '100';
			$scoringData[6][$totalsColumn+1]  = $r->maketext("index");
		}
		for (my $user = 0; $user < @sortedUserIDs; $user++) {
            $userStatusTotals{$user} =$userStatusTotals{$user} ||0;
			$scoringData[7+$user][$totalsColumn] = wwRound(2,$userStatusTotals{$user}) if $scoringItems->{setTotals};
			$scoringData[7+$user][$totalsColumn+1] = sprintf("%.0f",100*$userSuccessIndex{$user}) if $scoringItems->{successIndex};

		}
	}
	debug("End  set $setID");
	return @scoringData;
}

sub sumScores {    # Create a totals column for each student
	my $self        = shift;
	my $r_totals    = shift;
	my $showIndex   = shift;
	my $r_users     = shift;
	my $r_sorted_user_ids =shift;
	my $r           = $self->r;
	my $db          = $r->db;
	my @scoringData = ();
	my $index_increment  = ($showIndex) ? 2 : 1;
	# This whole thing is a hack, but here goes.  We're going to sum the appropriate columns of the totals file:
	# I believe we have $r_totals->[rows]->[cols]  -- the way it's printed out.
	my $start_column  = 6;  #The problem column 
	my $last_column   = $#{$r_totals->[1]};  # try to figure out the number of the last column in the array.
	my $row_count     = $#{$r_totals};
	
	# Calculate total number of problems for the course.
	my $totalPoints      = 0;
	my $problemValueRow  = 5;
	for( my $j = $start_column;$j<=$last_column;$j+= $index_increment) {
		my $score = $r_totals->[$problemValueRow]->[$j];
		$totalPoints += ($score =~/^\s*[\d\.]+\s*$/)? $score : 0;
	}
    foreach my $i (0..$row_count) {
    	my $studentTotal = 0;
		for( my $j = $start_column;$j<=$last_column;$j+= $index_increment) {
			my $score = $r_totals->[$i]->[$j];
			$studentTotal += ($score =~/^\s*[\d\.]+\s*$/)? $score : 0;
			
		}
		$scoringData[$i][0] = wwRound(2,$studentTotal);
		$scoringData[$i][1] = ($totalPoints) ?wwRound(2,100*$studentTotal/$totalPoints) : 0;
    }
    $scoringData[0]      = ['',''];
    $scoringData[1]      = [$r->maketext('summary'), $r->maketext('%score')];
	$scoringData[2]      = ['',''];
	$scoringData[3]      = ['',''];
	$scoringData[4]      = ['',''];
	$scoringData[6]      = ['',''];


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
	my $adjstatus = 0;

	# if its has adjusted status columns we need to include
	# those as well
	my $str = $self->r->maketext('ADJ STATUS');
	if (grep(grep(/$str/, @{$_}),@everything)) {
	    $adjstatus = 1;
	}
		
	foreach my $row (@everything) {
		my @row = @$row;
		my @newRow = ();
		push @newRow, @row[0..4];
		if ($adjstatus) {
		  for (my $i = 5; $i < @row; $i+=4) {
		    push @newRow, $row[$i];
		    push @newRow, $row[$i+1];
		  }
		} else {
		  for (my $i = 5; $i < @row; $i+=3) {
		    push @newRow, $row[$i];
		  }
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
	
	# Before writing a new totals file, we back up an existing totals file keeping any previous backups.
	# We do not backup any other type of scoring files (e.g. ful or scr).
	
	if (($filename =~ m|(.*)/(.*_totals)\.csv$|) and (-e $filename)) {
		my $scoringDir = $1;
		my $short_filename = $2;
		my $i=1;
		while(-e "${scoringDir}/${short_filename}_bak$i.csv") {$i++;}      #don't overwrite existing backups
		my $bakFileName ="${scoringDir}/${short_filename}_bak$i.csv";
		rename $filename, $bakFileName or warn "Unable to rename $filename to $bakFileName";
	}

	open my $fh, ">:encoding(UTF-8)", $filename or warn "Unable to open $filename for writing";
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
	open my $fh, ">:encoding(UTF-8)", $filename;
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
	return $string unless $self->{padFields}==1;
	my $spaces = $padTo - length $string;

#	return " "x$spaces.$string;
	return $string." "x$spaces;
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
	my $r     = $self->r;	
	my $db    = $r->db;
	my $ce    = $r->ce;
	my $authz = $r->authz;
	my $user  = $r->param('user');

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
 	return 			CGI::scrolling_list(-name=>'selectedSet',
 							   -values=>\@setNames,
 							   -labels=>\%setLabels,
 							   -size  => 10,
 							   -multiple => 1,
 							   #-default=>$user
 					),


}
1;

__END__

Here's pretty much everything I can think of that we can get out of the database
or calculate:

for each set, we have a few rows of non-user-specific data above the student rows
(we could just have additional columns for these values, but they'd have the same value in every row)
	set_id
	optional other set data (dates, etc)
	per-problem data (usually not shown, but available if needed)
		problem_id
		problem value
	for all problems in the set
		total value
for each student (one row) we need columns for:
	user_id and/or student_id
	optional other user data (first_name/last_name, section, recitation, etc)
	per-set data
		per-problem data (usually not shown, but available if needed)
			status
			score = value*status
			number of attempts
			number of correct attempts
			number of incorrect attempts
		for all problems in the set
			total status
			total score
			total number of attempts
			average number of attempts
			total number of correct attempts
			average number of correct attempts
			total number of incorrect attempts
			average number of incorrect attempts
			index = ( total_status / total_value )**2 / average_number_of_attempts

"value" is the weight of the problem, in the range [0,inf), usually 1.
"status" is the correctness of a problem, in the range [0,1].
