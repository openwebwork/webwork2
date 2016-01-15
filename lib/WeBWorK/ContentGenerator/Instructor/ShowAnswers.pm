################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/ShowAnswers.pm,v 1.20 2006/10/10 10:58:54 dpvc Exp $
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

package WeBWorK::ContentGenerator::Instructor::ShowAnswers;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ShowAnswers.pm  -- display past answers of students

=cut

use strict;
use warnings;
#use CGI;
use WeBWorK::CGI;
use WeBWorK::Utils qw(sortByName jitar_id_to_seq seq_to_jitar_id); 
use PGcore;

use Text::CSV;

sub initialize {
	my $self       = shift;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $db         = $r->db;
	my $ce         = $r->ce;
	my $authz      = $r->authz;
	my $courseName = $urlpath->arg("courseID");
	my $user       = $r->param('user');
	my $root          = $ce->{webworkURLs}->{root};
	my $key           = $r->param('key');
	my $setNameRegExp       = $r->param('setID') || '*';     # these are passed in the search args in this case
	my $problemNumberRegExp = $r->param('problemID') || '*'; # blank entries count as *'s 


	$self->{setNameRegExp} = $setNameRegExp;
	$self->{problemNumberRegExp} = $problemNumberRegExp;
	
	unless ($authz->hasPermissions($user, "view_answers")) {
		$self->addbadmessage("You aren't authorized to view past answers");
		return;
	}
	
	# The stop acting button doesn't perform a submit action and so
	# these extra parameters are passed so that if an instructor stops
	# acting the current studentID, setID and problemID will be maintained

	my $extraStopActingParams;
	$extraStopActingParams->{studentUser} = $r->param('studentUser');
	$extraStopActingParams->{setID} = $r->param('setID');
	$extraStopActingParams->{problemID} = $r->param('problemID');
	$r->{extraStopActingParams} = $extraStopActingParams;


	my $studentUserRegExp;
	if ( defined($r->param('studentUser'))) {
	    $studentUserRegExp   = $r->param('studentUser') || '*';
	} else {
	    $studentUserRegExp = '*';
	}
	my $instructor = $authz->hasPermissions($user, "access_instructor_tools");

	# If not instructor then force table to use current user-id
	if (!$instructor) {
	    $studentUserRegExp = $user;
	}

	$self->{studentUserRegExp} = $studentUserRegExp;
	
	return CGI::span({class=>'ResultsWithError'}, $r->maketext('You must provide
			    a student ID, a set ID, and a problem number.'))
	    unless defined($studentUserRegExp)  && defined($setNameRegExp) 
	    && defined($problemNumberRegExp);

	#our student name, set name and problem name might actually have wildcards
	# so go through all of the possible things and trying to figure out which 
	# we should display
	
	my %records;
	my @studentUsers;

	# Set up * as a wildcard for the student user regexp
	$studentUserRegExp = generateRegExp($studentUserRegExp);
	$setNameRegExp = generateRegExp($setNameRegExp);
	my @numberRanges = split(/,/,$problemNumberRegExp);

	# search for matching students
	my @allUsers = $db->listUsers();
	foreach my $user (@allUsers) {
	    if ($user =~ /^${studentUserRegExp}$/) {
		push (@studentUsers, $user);
	    }
	}

	return CGI::span({class=>'ResultsWithError'}, $r->maketext('No students matched the given student id.'))
	    unless @studentUsers;

  	foreach my $studentUser (@studentUsers) {

	    my @setNames;

	    # search for matching sets
	    my @allSets = $db->listUserSets($studentUser);
	    foreach my $set (@allSets) {
		if ($db->countSetVersions($studentUser, $set)) {
		    my @versions = $db->listSetVersions($studentUser, $set);
		    my $versionedSetRegExp = $setNameRegExp;
		    $versionedSetRegExp = $versionedSetRegExp.',v[0-9]*' unless
			$versionedSetRegExp =~ /,v[0-9]*/;
		    foreach my $version (@versions) {
			my $versionedSet = "$set,v$version";
			if ($versionedSet =~ /^${versionedSetRegExp}$/) {
			    push(@setNames, $versionedSet);
			}
		    }
		} elsif ($set =~ /^${setNameRegExp}$/) {
		    push (@setNames, $set);
		}
		
	    }

	    next unless @setNames;
	  
	    foreach my $setName (@setNames) {
	
		my @problemNumbers;

		my $setRecord = $db->getGlobalSet($setName);
		my $isJitarSet = ($setRecord && $setRecord->assignment_type eq 'jitar' ) ? 1 : 0;

		# search for matching problems
		my @allProblems = $db->listUserProblems($studentUser, $setName);
		next unless @allProblems;
		foreach my $problem (@allProblems) {

		    foreach my $numberRange (@numberRanges) {
	
			if ($numberRange =~ /-/) {
			    (my $low, my $high) = split(/-/,$numberRange);
			    
			    # if its a jitar set we need to turn the number into a jitar id
			    if ($isJitarSet) {
				$low = seq_to_jitar_id(split(/\./,$low));
				$high = seq_to_jitar_id(split(/\./,$high));
				# if its not then we ignore problem numbers that look like jitar numbers
			    } elsif ($low =~ /\./ || $high =~ /\./) {
				next;
			    }

			    if ($low <= $problem && $problem <= $high) {
				push (@problemNumbers, $problem);
			    }

			} elsif ($numberRange eq '*') {
			    push (@problemNumbers, $problem);
			    # in this case its a singleton
			} else {
			    # if its a jitar set we need to turn the number into a jitar id
			    my $number = $numberRange;

			    if ($isJitarSet) {
				$number = seq_to_jitar_id(split(/\./,$number));
				# if its not then we ignore problem numbers that look like jitar numbers
			    } elsif ($number =~ /\./) {
				next;
			    }
			    
			    if ($number == $problem) {
				push (@problemNumbers, $problem);
			    }
			}
		    }
		}
		
		next unless @problemNumbers;
		
		foreach my $problemNumber (@problemNumbers) {

		  my @pastAnswerIDs = $db->listProblemPastAnswers($studentUser, $setName, $problemNumber);
		    
		    
		    # changed this to use the db for the past answers.  
		    
		    #set up a silly problem to figure out what type the answers are
		    #(why isn't this stored somewhere)
		    my $unversionedSetName = $setName;
		    $unversionedSetName =~ s/,v[0-9]*$//;
		    my $displayMode   = $self->{displayMode};
		    my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars }; 
		    my $set = $db->getMergedSet($studentUser, $unversionedSetName);
		    my $problem = $db->getMergedProblem($studentUser, $unversionedSetName, $problemNumber);
		    my $userobj = $db->getUser($studentUser);
		    #if these things dont exist then the problem doesnt exist and past answers dont make sense
		    next unless defined($set) && defined($problem) && defined($userobj); 
		    
		    my $pg = WeBWorK::PG->new(
			$ce,
			$userobj,
			$key,
			$set,
			$problem,
			$set->psvn, # FIXME: this field should be removed
			$formFields,
			{ # translation options
			    displayMode     => 'plainText',
			    showHints       => 0,
			    showSolutions   => 0,
			    refreshMath2img => 0,
			    processAnswers  => 1,
			    permissionLevel => $db->getPermissionLevel($studentUser)->permission,
			    effectivePermissionLevel => $db->getPermissionLevel($studentUser)->permission,
			},
			);
		    
		    # check to see what type the answers are.  right now it only checks for essay but could do more
		    my %answerHash = %{ $pg->{answers} };
		    my @answerTypes;

		    foreach (sortByName(undef, keys %answerHash)) {
			push(@answerTypes,defined($answerHash{$_}->{type})?$answerHash{$_}->{type}:'undefined');
		    }
		    
		    foreach my $answerID (@pastAnswerIDs) {
			my $pastAnswer = $db->getPastAnswer($answerID);
			my $answers = $pastAnswer->answer_string;
			my $scores = $pastAnswer->scores;
			my $time = $self->formatDateTime($pastAnswer->timestamp);
			my @scores = split(//, $scores);
			my @answers = split(/\t/,$answers);
			
			
			$records{$studentUser}{$setName}{$problemNumber}{$answerID} =  { time => $time, answers => @answers, answerTypes => @answerTypes, scores => @scores, comment => $pastAnswer->comment_string // '' };
			
		    }
		    
		}
	    }
	}

	$self->{records} = \%records;

	# Prepare a csv if we are an instructor
	if ($instructor && $r->param('createCSV')) {
	    my $filename = 'past_answers';
	    my $scoringDir = $ce->{courseDirs}->{scoring};
	    if (-e "${scoringDir}/${filename}.csv") {
		my $i=1;
		while(-e "${scoringDir}/${filename}_bak$i.csv") {$i++;}      #don't overwrite existing backups
		my $bakFileName ="${scoringDir}/${filename}_bak$i.csv";
		rename $filename, $bakFileName or warn "Unable to rename $filename to $bakFileName";
	    }

	    $filename .= '.csv';

	    open my $fh, ">", $filename or warn "Unable to open $filename for writing";

	    my $csv = Text::CSV->new();
	    my @columns;

	    $columns[0] = $r->maketext('User ID');
	    $columns[1] = $r->maketext('Set ID');
	    $columns[2] = $r->maketext('Problem Number');
	    $columns[3] = $r->maketext('Timestamp');
	    $columns[4] = $r->maketext('Scores');
	    $columns[5] = $r->maketext('Answers');
	    $columns[6] = $r->maketext('Comment');
	    
	    $csv->print($fh, \@columns); 

	    foreach my $studentID (sort keys %records) {
		$columns[0] = $studentID;
		foreach my $setID (sort keys %{$records{$studentID}}) {
		    $columns[1] = $setID;
		    foreach my $probNum (sort keys %{$records{$studentID}{$setID}}) {
		      $columns[2] = $probNum;
		      foreach my $answerID (sort keys %{$records{$studentID}{$setID}{$probNum}}) {
			my $record = %{$records{$studentID}{$setID}{$probNum}{$answerID}};
		      
			$columns[3] = $record->{time};
			$columns[4] = join(';' ,$record->{scores});
			$columns[5] = join(';' ,$record->{answers});
			$columns[6] = join(';' ,$record->{comment});
			
			$csv->print($fh,\@columns);
		      }
		    }
		}
	    }

	    close($fh) or warn "Couldn't Close $filename";
	    
	    }

}


sub body {
	my $self          = shift;
	my $r             = $self->r;
	my $urlpath       = $r->urlpath;
	my $db            = $r->db;
	my $ce            = $r->ce;
	my $authz         = $r->authz;
	my $root          = $ce->{webworkURLs}->{root};
	my $courseName    = $urlpath->arg('courseID');  
	my $setNameRegExp       = $r->param('setID') || '*';     # these are passed in the search args in this case
	my $problemNumberRegExp = $r->param('problemID') || '*'; # blank entries count as *'s 
	my $user          = $r->param('user');
	my $key           = $r->param('key');

	my $instructor = $authz->hasPermissions($user, "access_instructor_tools");

	return CGI::em("You are not authorized to view past answers") unless $authz->hasPermissions($user, "view_answers");

	
	my $showAnswersPage   = $urlpath->newFromModule($urlpath->module,  $r, courseID => $courseName);
	my $showAnswersURL    = $self->systemLink($showAnswersPage,authen => 0 );
	my $renderAnswers = 0;
	# Figure out if MathJax is available
	if ((grep(/MathJax/,@{$ce->{pg}->{displayModes}}))) {
	    print CGI::start_script({type=>"text/javascript", src=>"$ce->{webworkURLs}->{MathJax}"}), CGI::end_script();
	    $renderAnswers = 1;
	}


	#####################################################################
	# print form
	#####################################################################

	#only instructors should be able to veiw other people's answers.
	
	if ($instructor) {
	    ########## print site identifying information
	    
	    print WeBWorK::CGI_labeled_input(-type=>"button", -id=>"show_hide", -input_attr=>{-value=>$r->maketext("Show/Hide Site Description"), -class=>"button_input"});
	    print CGI::p({-id=>"site_description", -style=>"display:none"}, CGI::em($r->maketext("_ANSWER_LOG_DESCRIPTION")));
	    
	    print CGI::p(),CGI::hr();
	    
	    print CGI::start_form({-target=>'WW_Info',-id=>'past-answer-form'},"POST", $showAnswersURL),
	    $self->hidden_authen_fields;
	    print CGI::submit(-name => 'action', -value=>$r->maketext('Past Answers for'))," &nbsp; ",
	    " &nbsp;".CGI::label($r->maketext('User:')." &nbsp;",
	    CGI::textfield(-name => 'studentUser', -value => $self->{studentUserRegExp}, -size =>10 )),
	    " &nbsp;".CGI::label($r->maketext('Set:')." &nbsp;",
	    CGI::textfield( -name => 'setID', -value => $self->{setNameRegExp}, -size =>10  )), 
	    " &nbsp;".CGI::label($r->maketext('Problem:')."&nbsp;",
	    CGI::textfield(-name => 'problemID', -value => $self->{problemNumberRegExp}, -size =>10  )),  
	    CGI::br(),
	    " &nbsp;".CGI::label($r->maketext('Create CSV:')."&nbsp;",
				 CGI::checkbox(-name => 'createCSV', -value => $r->param('Create CSV')//0 ));

	    print CGI::end_form();
	}

	####################################################################
	# If necessary print a link to the csv file
	####################################################################

	my $filename = 'past_answers.csv';
	my $scoringDir = $ce->{courseDirs}->{scoring};

	if ($instructor && $r->param('Create CSV') &&
	    -e "${scoringDir}/${filename}") {

	    my $scoringDownloadPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::ScoringDownload", $r, courseID => $courseName
		);
	    
	    print CGI::span($r->maketext('Download:'),
			    CGI::a({href=>$self->systemLink($scoringDownloadPage,
							    params=>{getFile => $filename } )}, $filename));
			    
		}
	    

	#####################################################################
	# print result table of answers
	#####################################################################

	my $records = $self->{records};
	
	print CGI::start_table({class=>"past-answer-table", border=>0,cellpadding=>0,cellspacing=>3,align=>"center"});

	my $foundMatches = 0;
	
	foreach my $studentUser (sort keys %{$records}) {
	  foreach my $setName (sort keys %{$records->{$studentUser}}) {
	    foreach my $problemNumber (sort keys %{$records->{$studentUser}{$setName}}) {

	      my @pastAnswerIDs = sort keys %{$records->{$studentUser}{$setName}{$problemNumber}};
	      print CGI::h3($r->maketext("Past Answers for [_1], set [_2], problem [_3]" ,$studentUser, $setName, $problemNumber));
	      print $r->maketext("No entries for [_1], set [_2], problem [_3]", $studentUser, $setName, $problemNumber) unless @pastAnswerIDs;
	
	      my @row;
	      my $rowOptions = {};

	      my $previousTime = -1;
	      
	      foreach my $answerID (@pastAnswerIDs) {
		$foundMatches = 1 unless $foundMatches;
		
		my %record = $records->{$studentUser}{$setName}{$problemNumber}{$answerID};
		my @answers = $record{answers};
		my @scores = $record{scores};
		my @answerTypes = $record{answerTypes};
		my $time = $self->formatDateTime($record{time});
		
		if ($previousTime < 0) {
		  $previousTime = $record{time};
		}
		
			
		my $num_ans = $#answers;
			
		if ($record{time} - $previousTime > $ce->{sessionKeyTimeout}) {
		  $rowOptions->{'class'} = 'table-rule';
		}

		@row = (CGI::td({width=>10}),CGI::td({style=>"color:#808080"},CGI::small($time)));

		
		for (my $i = 0; $i <= $num_ans; $i++) {
		  my $td;
		  my $answer = $answers[$i];
		  my $answerType = defined($answerTypes[$i]) ? $answerTypes[$i] : '';
		  my $score = shift(@scores); 
		  #Only color answer if its an instructor
		  if ($instructor) {
		    $td->{style} = $score? "color:#006600": "color:#660000";
		  } 
		  delete($td->{style}) unless $answer ne "" && defined($score) && $answerType ne 'essay';
		  
		  my $answerstring;
		  if ($answer eq '') {		    
		    $answerstring  = CGI::small(CGI::i("empty")) if ($answer eq "");
		  } elsif (!$renderAnswers) {
		    $answerstring = PGcore::encode_pg_and_html($answer);
		  } elsif ($answerType eq 'essay') {
		    $answerstring = PGcore::encode_pg_and_html($answer);
		    $td->{class} = 'essay';
		  } else {
		    $answerstring = PGcore::encode_pg_and_html($answer);
		  }
		  
		  push(@row,CGI::td({width=>20}),CGI::td($td,$answerstring));
		}
		
		if ($record{comment}) {
		  push(@row,CGI::td({width=>20}),CGI::td({class=>'comment'},"Comment: ".PGcore::encode_pg_and_html($record{comment})));
		}
		
		print CGI::Tr($rowOptions,@row);
		
		$previousTime = $record{time};
		
	      }
	    }
	  }
	}
      	      
	print CGI::end_table();
	


	
	if ($renderAnswers) {
	  print <<EOS;
	    <script type="text/javascript">
		MathJax.Hub.Register.StartupHook('AsciiMath Jax Config', function () {
		    var AM = MathJax.InputJax.AsciiMath.AM;
		    for (var i=0; i< AM.symbols.length; i++) {
			if (AM.symbols[i].input == '**') {
			    AM.symbols[i] = {input:"**", tag:"msup", output:"^", tex:null, ttype: AM.TOKEN.INFIX};
			}
		    }
						 });
	    MathJax.Hub.Config(["input/Tex","input/AsciiMath","output/HTML-CSS"]);
	    
	    MathJax.Hub.Queue([ "Typeset", MathJax.Hub, "past-answer-table"]);
	    </script>
EOS
	}
	
	print $r->maketext('No problems matched the given parameters.') unless $foundMatches;

	return "";
      }

sub generateRegExp {
    my $regExp = shift;

    $regExp =~ s/([\\\[\]\{\}\(\)\+\.\$\^])/\\$1/g;
    $regExp =~ s/\*/\.\*/g;
    $regExp =~ s/\?/\./g;

    return $regExp;

}

sub byData {
  my ($A,$B) = ($a,$b);
  $A =~ s/\|[01]*\t([^\t]+)\t.*/|$1/; # remove answers and correct/incorrect status
  $B =~ s/\|[01]*\t([^\t]+)\t.*/|$1/;
  return $A cmp $B;
}

sub output_JS {
    my $self = shift;
    my $r = $self->r;
    my $ce = $r->ce;

    my $site_url = $ce->{webworkURLs}->{htdocs};
    
    print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/AddOnLoad/addOnLoadEvent.js"}), CGI::end_script();
    print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/ShowHide/show_hide.js"}), CGI::end_script();

    return "";
}

1;
