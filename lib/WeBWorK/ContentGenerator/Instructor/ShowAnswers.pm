################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
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
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;
use WeBWorK::Utils qw(sortByName jitar_id_to_seq seq_to_jitar_id); 
use PGcore;
use Text::CSV;

use constant PAST_ANSWERS_FILENAME => 'past_answers';

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

	my $selectedSets = [$r->param('selected_sets')] // [];
	my $selectedProblems = [$r->param('selected_problems')] // [];
	
	unless ($authz->hasPermissions($user, "view_answers")) {
		$self->addbadmessage("You aren't authorized to view past answers");
		return;
	}
	
	# The stop acting button doesn't perform a submit action and so
	# these extra parameters are passed so that if an instructor stops
	# acting the current studentID, setID and problemID will be maintained

	my $extraStopActingParams;
	$extraStopActingParams->{selected_users} = $r->param('selected_users');
	$extraStopActingParams->{selected_sets} = $r->param('selected_sets');
	$extraStopActingParams->{selected_problems} = $r->param('selected_problems');
	$r->{extraStopActingParams} = $extraStopActingParams;

	my $selectedUsers = [$r->param('selected_users')] // [];

	my $instructor = $authz->hasPermissions($user, "access_instructor_tools");

	# If not instructor then force table to use current user-id
	if (!$instructor) {
	  $selectedUsers = [$user];
	}

	return CGI::span({class=>'ResultsWithError'}, $r->maketext('You must provide a student ID, a set ID, and a problem number.')) unless $selectedUsers  && $selectedSets && $selectedProblems;
	
	my %records;
	my %prettyProblemNumbers;
	my %answerTypes;
	
  	foreach my $studentUser (@$selectedUsers) {
	    my @sets;

	    # search for selected sets assigned to students
	    my @allSets = $db->listUserSets($studentUser);
	    foreach my $setName (@allSets) {
	      my $set = $db->getMergedSet($studentUser,$setName);
	      if (defined($set->assignment_type) && $set->assignment_type =~ /gateway/) {
		my @versions = $db->listSetVersions($studentUser, $setName);
		foreach my $version(@versions) {
		  if (grep/^$setName,v$version$/,@$selectedSets) {
		    $set = $db->getUserSet($studentUser,"$setName,v$version");
		    push(@sets, $set);
		  }
		}
	      } elsif (grep(/^$setName$/,@$selectedSets)) {
		push (@sets, $set);
	      }
	      
	    }
	    
	    next unless @sets;

	    foreach my $setRecord (@sets) {
	        my @problemNumbers;
		my $setName = $setRecord->set_id;
		my $isJitarSet = (defined($setRecord->assignment_type) && $setRecord->assignment_type eq 'jitar' ) ? 1 : 0;

		# search for matching problems
		my @allProblems = $db->listUserProblems($studentUser, $setName);
		next unless @allProblems;
		foreach my $problemNumber (@allProblems) {
		  my $prettyProblemNumber = $problemNumber;
		  if ($isJitarSet) {
		    $prettyProblemNumber = join('.',jitar_id_to_seq($problemNumber));
		  }
		  $prettyProblemNumbers{$setName}{$problemNumber} = $prettyProblemNumber;

		  if (grep(/^$prettyProblemNumber$/,@$selectedProblems)) {
		    push (@problemNumbers, $problemNumber);
		  }
		}
				
		next unless @problemNumbers;

		foreach my $problemNumber (@problemNumbers) {
		  my @pastAnswerIDs = $db->listProblemPastAnswers($studentUser, $setName, $problemNumber);

		  if (!defined($answerTypes{$setName}{$problemNumber})) {
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

		    $answerTypes{$setName}{$problemNumber} = [@answerTypes];
		  }
		  
		  my @pastAnswers = $db->getPastAnswers(\@pastAnswerIDs);

		  foreach my $pastAnswer (@pastAnswers) {
		    my $answerID = $pastAnswer->answer_id;
		    my $answers = $pastAnswer->answer_string;
		    my $scores = $pastAnswer->scores;
		    my $time = $pastAnswer->timestamp;
		    my @scores = split(//, $scores);
		    my @answers = split(/\t/,$answers);
		    
		    
		    $records{$studentUser}{$setName}{$problemNumber}{$answerID} =  { time => $time,
										     answers => [@answers],
										     answerTypes => $answerTypes{$setName}{$problemNumber},
										     scores => [@scores],
										     comment => $pastAnswer->comment_string // '' };
		    
		  }
		  
		}
	      }
	  }
	
	$self->{records} = \%records;
	$self->{prettyProblemNumbers} = \%prettyProblemNumbers;
	
	# Prepare a csv if we are an instructor
	if ($instructor && $r->param('createCSV')) {
	    my $filename = PAST_ANSWERS_FILENAME;
	    my $scoringDir = $ce->{courseDirs}->{scoring};
	    my $fullFilename = "${scoringDir}/${filename}.csv";
	    if (-e $fullFilename) {
		my $i=1;
		while(-e "${scoringDir}/${filename}_bak$i.csv") {$i++;}      #don't overwrite existing backups
		my $bakFileName ="${scoringDir}/${filename}_bak$i.csv";
		rename $fullFilename, $bakFileName or warn "Unable to rename $filename to $bakFileName";
	    }

	    $filename .= '.csv';

	    open my $fh, ">:utf8", $fullFilename or warn "Unable to open $fullFilename for writing";

	    my $csv = Text::CSV->new({"eol"=>"\n"});
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
		    foreach my $probNum (sort {$a <=> $b} keys %{$records{$studentID}{$setID}}) {
		      $columns[2] = $prettyProblemNumbers{$setID}{$probNum};
		      foreach my $answerID (sort {$a <=> $b} keys %{$records{$studentID}{$setID}{$probNum}}) {
			my %record = %{$records{$studentID}{$setID}{$probNum}{$answerID}};
		      
			$columns[3] = $self->formatDateTime($record{time});
			$columns[4] = join(',' ,@{$record{scores}});
			$columns[5] = join("\t" ,@{$record{answers}});
			$columns[6] = $record{comment};
			
			$csv->print($fh,\@columns);
		      }
		    }
		}
	    }

	    close($fh) or warn "Couldn't Close $fullFilename";
	    
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
	my $user          = $r->param('user');
	my $key           = $r->param('key');

	my $instructor = $authz->hasPermissions($user, "access_instructor_tools");

	my $selectedSets = [$r->param('selected_sets')] // [];
	my $selectedProblems = [$r->param('selected_problems')] // [];
	
	return CGI::em("You are not authorized to view past answers") unless $authz->hasPermissions($user, "view_answers");

	
	my $showAnswersPage   = $urlpath->newFromModule($urlpath->module,  $r, courseID => $courseName);
	my $showAnswersURL    = $self->systemLink($showAnswersPage,authen => 0 );
	my $renderAnswers = 0;
	# Figure out if MathJax is available
	if ((grep(/MathJax/,@{$ce->{pg}->{displayModes}}))) {
	    print CGI::start_script({type=>"text/javascript", src=>"$ce->{webworkURLs}->{MathJax}"}), CGI::end_script();
	    $renderAnswers = 1;
	}


	my $prettyProblemNumbers = $self->{prettyProblemNumbers};

	
	#####################################################################
	# print form
	#####################################################################

	#only instructors should be able to veiw other people's answers.
	
	if ($instructor) {

	  my @userIDs = grep {$_ !~ /^set_id:/} $db->listUsers;
	  my @Users = $db->getUsers(@userIDs);
	  
	  ## Mark's Edits for filtering
	  my @myUsers;
	  
	  my (@viewable_sections,@viewable_recitations);
	  
	  if (defined $ce->{viewable_sections}->{$user})
	    {@viewable_sections = @{$ce->{viewable_sections}->{$user}};}
	  if (defined $ce->{viewable_recitations}->{$user})
	    {@viewable_recitations = @{$ce->{viewable_recitations}->{$user}};}
	  
	  if (@viewable_sections or @viewable_recitations){
	    foreach my $student (@Users){
	      my $keep = 0;
	      foreach my $sec (@viewable_sections){
		if ($student->section() eq $sec){$keep = 1;}
	      }
	      foreach my $rec (@viewable_recitations){
		if ($student->recitation() eq $rec){$keep = 1;}
	      }
	      if ($keep) {push @myUsers, $student;}
	    }
	    @Users = @myUsers;
	  }
	  ## End Mark's Edits
	  
	  # DBFIXME shouldn't need to use list of IDs, use iterator for results
	  my @globalSetIDs = $db->listGlobalSets;
	  my @GlobalSets = $db->getGlobalSets(@globalSetIDs);

	  my @expandedGlobalSetIDs;

	  # We need to go through the global sets and if its a gateway
	  # we need to actually find the max number of versions
	  # hopefully this isn't too slow.  
	  foreach my $globalSet (@GlobalSets) {
	    my $setName = $globalSet->set_id;
	    if ($globalSet->assignment_type() &&
		$globalSet->assignment_type() =~ /gateway/) {

	      my $maxVersions = 0;
	      foreach my $user (@Users) {
		my $versions = $db->countSetVersions($user->user_id, $setName);
		if ($versions > $maxVersions) {
		  $maxVersions = $versions;
		}
	      }
	      if ($maxVersions) {
		for (my $i = 1; $i <= $maxVersions; $i++) {
		  push @expandedGlobalSetIDs, "$setName,v$i";
		}
	      }
	    } else {
	      push @expandedGlobalSetIDs, $setName;
	    }
	  }
	  
	  
	  my %all_problems;
	  #Figure out what problems we need to show.
	  foreach my $globalSet (@GlobalSets) {
	    my @problems = $db->listGlobalProblems($globalSet->set_id);
	    if ($globalSet->assignment_type() &&
		$globalSet->assignment_type() eq 'jitar') {
	      @problems = map {join('.',jitar_id_to_seq($_))} @problems;
	    }
	    
	    foreach my $problem (@problems) {
	      $all_problems{$problem} = 1;
	    }
	  }

	  @expandedGlobalSetIDs = sort @expandedGlobalSetIDs;
	  my @globalProblemIDs = sort prob_id_sort keys %all_problems;
	  
	  my $scrolling_user_list = scrollingRecordList({
							 name => "selected_users",
							 request => $r,
							 default_sort => "lnfn",
							 default_format => "lnfn_uid",
							 default_filters => ["all"],
							 size => 10,
							 multiple => 1,
							}, @Users);
	  
	  my $scrolling_set_list = CGI::scrolling_list({name => "selected_sets",
							values=>\@expandedGlobalSetIDs,
							default => $selectedSets,
							size => 23,
							multiple => 1,});
	  
	  my $scrolling_problem_list = CGI::scrolling_list({name => "selected_problems",
							    values=>\@globalProblemIDs,
							    default =>$selectedProblems,
							    size => 23,
							    multiple => 1,});
	  
	  
	  ####################################################################
	  # If necessary print a link to the csv file
	  ####################################################################

	  my $filename = PAST_ANSWERS_FILENAME.'.csv';
	  my $scoringDir = $ce->{courseDirs}->{scoring};
	  my $scoringDownloadMessage = '';
	  
	  if ($r->param('createCSV') &&
	      -e "${scoringDir}/${filename}") {
	    
	    my $scoringDownloadPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::ScoringDownload", $r, courseID => $courseName
							     );
	    
	    $scoringDownloadMessage = CGI::span({class=>'past-answer-download'}, $r->maketext('Download:'),
					      CGI::a({href=>$self->systemLink($scoringDownloadPage,
									      params=>{getFile => $filename } )}, $filename));
	    
	  }
	  
	    ########## print site identifying information
	    
	    print WeBWorK::CGI_labeled_input(-type=>"button", -id=>"show_hide", -input_attr=>{-value=>$r->maketext("Show/Hide Site Description"), -class=>"button_input"});
	    print CGI::p({-id=>"site_description", -style=>"display:none"}, CGI::em($r->maketext("_ANSWER_LOG_DESCRIPTION")));
	    
	    print CGI::p(),CGI::hr();

	    print CGI::start_form({-target=>'WW_Info',-id=>'past-answer-form'},"POST", $showAnswersURL);
	    print $self->hidden_authen_fields();
	
	    print CGI::table({class=>"FormLayout"},
			     CGI::Tr({},
				     CGI::th($r->maketext("Users")),
				     CGI::th($r->maketext("Sets")),
				     CGI::th($r->maketext("Problems")),
				    ),
			     CGI::Tr({},
				     CGI::td($scrolling_user_list),
				     CGI::td($scrolling_set_list),
				     CGI::td($scrolling_problem_list),
				    ));
	    
	    print CGI::submit(-name => 'action', -value=>$r->maketext('Display Past Answers'))," &nbsp; ",
	      CGI::checkbox(-label=>$r->maketext('Create CSV'), -name => 'createCSV', -id => 'createCSV', -checked => $r->param('createCSV')//0 ),' &nbsp; ',
		$scoringDownloadMessage;
	    
	    print CGI::end_form();
	}


	#####################################################################
	# print result table of answers
	#####################################################################

	my $records = $self->{records};
	
	my $foundMatches = 0;
	
	foreach my $studentUser (sort keys %{$records}) {
	  foreach my $setName (sort keys %{$records->{$studentUser}}) {
	    foreach my $problemNumber (sort {$a <=> $b} keys %{$records->{$studentUser}{$setName}}) {
	      my @pastAnswerIDs = sort {$a <=> $b} keys %{$records->{$studentUser}{$setName}{$problemNumber}};
	      my $prettyProblemNumber = $prettyProblemNumbers->{$setName}{$problemNumber};
	      print CGI::h3($r->maketext("Past Answers for [_1], set [_2], problem [_3]" ,$studentUser, $setName, $prettyProblemNumber));
	
	      my @row;
	      my $rowOptions = {};

	      my $previousTime = -1;

	      print CGI::start_table({class=>"past-answer-table", border=>0,cellpadding=>0,cellspacing=>3,align=>"center", dir=>"ltr"}); # The answers are not well formatted in RTL mode
	      
	      foreach my $answerID (@pastAnswerIDs) {
		$foundMatches = 1 unless $foundMatches;
		
		my %record = %{$records->{$studentUser}{$setName}{$problemNumber}{$answerID}};
		my @answers = @{$record{answers}};
		my @scores = @{$record{scores}};
		my @answerTypes = @{$record{answerTypes}};
		my $time = $self->formatDateTime($record{time});
		
		if ($previousTime < 0) {
		  $previousTime = $record{time};
		}
			
		my $num_ans = $#scores;
		my $num_ans_blanks=$#answers;
		my $upper_limit = ($num_ans > $num_ans_blanks)? $num_ans: $num_ans_blanks;
		
		#FIXME -- $num_ans is no longer the value needed -- $num_ans is the number of 
		# answer evaluators (or answer groups) each of which might have several
		# answer blanks. On the other hand sometimes an answer blank has been left blank
		# and there is no answer, but the score is zero. 
		# In other words sometimes number of scores is greater than the number of answers
		# and sometimes it is less. 
		
		#warn "checking number of answers ", scalar(@answers), " vs number of scores ",scalar(@scores), " and limit is $upper_limit";
		#warn "answers are ", join(" ", @answers);
		if ($record{time} - $previousTime > $ce->{sessionKeyTimeout}) {
		  $rowOptions->{'class'} = 'table-rule';
		} else {
		  $rowOptions->{'class'} = '';
		}

		@row = (CGI::td({width=>10}),CGI::td({style=>"color:#808080"},CGI::small($time)));

		
		for (my $i = 0; $i <= $upper_limit; $i++) {
		  my $td;
		  my $answer = $answers[$i] // '';
		  my $answerType = defined($answerTypes[$i]) ? $answerTypes[$i] : '';
		  my $score = shift(@scores); 
		  #Only color answer if its an instructor
		  if ($instructor) {
		    $td->{style} = $score? "color:#006600": "color:#660000";
		  } 
		  delete($td->{style}) unless $answer ne "" && defined($score) && $answerType ne 'essay';
		  
		  my $answerstring;
		  if ($answer eq '') {		    
		    $answerstring  = CGI::small(CGI::i($r->maketext("empty"))) if ($answer eq "");
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
		  push(@row,CGI::td({width=>20}),CGI::td({class=>'comment'},$r->maketext("Comment").": ".PGcore::encode_pg_and_html($record{comment})));
		}
		
		print CGI::Tr($rowOptions,@row);
		
		$previousTime = $record{time};
		
	      }
	      print CGI::end_table();

	    }
	  }
	}
      	      
	


	
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
	
	print CGI::h2($r->maketext('No problems matched the given parameters.')) unless $foundMatches;

	return "";
      }

sub byData {
  my ($A,$B) = ($a,$b);
  $A =~ s/\|[01]*\t([^\t]+)\t.*/|$1/; # remove answers and correct/incorrect status
  $B =~ s/\|[01]*\t([^\t]+)\t.*/|$1/;
  return $A cmp $B;
}

# sorts problem ID's so that all just-in-time like ids are at the bottom
# of the list in order and other problems 
sub prob_id_sort {

  my @seqa = split(/\./,$a);
  my @seqb = split(/\./,$b);

  # go through problem number sequence
  for (my $i = 0; $i <= $#seqa; $i++) {
    # if at some point two numbers are different return the comparison. 
    # e.g. 2.1.3 vs 1.2.6
    if ($seqa[$i] != $seqb[$i]) {
      return $seqa[$i] <=> $seqb[$i];
    }

    # if all of the values are equal but b is shorter then it comes first
    # i.e. 2.1.3 vs 2.1
    if ($i == $#seqb) {
      return 1;
    }
  }

  # if all of the values are equal and a and b are the same length then equal
  # otherwise a was shorter than b so a comes first. 
  if ($#seqa == $#seqb) {
    return 0;
  } else {
    return -1;
  }
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
