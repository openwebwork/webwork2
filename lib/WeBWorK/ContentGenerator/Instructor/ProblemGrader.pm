################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Skeleton.pm,v 1.5 2006/07/08 14:07:34 gage Exp $
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

#This is a page for manually grading webwork problems.  

package WeBWorK::ContentGenerator::Instructor::ProblemGrader;
use base qw(WeBWorK::ContentGenerator);
use WeBWorK::Utils qw(sortByName ); 
use WeBWorK::PG;
use HTML::Entities;
=head1 NAME

=cut

use strict;
use warnings;


sub pre_header_initialize {

	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $setName = $urlpath->arg("setID");
	my $problemNumber = $r->urlpath->arg("problemID");
	my $userName = $r->param('user');
	my $effectiveUserName = $r->param('effectiveUser');
	my $key = $r->param('key');
	my $editMode = $r->param("editMode");
	
	# Check permissions
	return unless $authz->hasPermissions($userName, "access_instructor_tools");	
	return unless $authz->hasPermissions($userName, "score_sets");

	my $user = $db->getUser($userName);
	die "Couldn't find user $user" unless $user;

	my $displayMode  = $user->displayMode ? $user->displayMode : $ce->{pg}->{options}->{displayMode};
	$self->{displayMode}    = $displayMode;
}

sub head {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};

#	print "<link rel=\"stylesheet\" type=\"text/css\" href=\"$site_url/js/vendor/bootstrap/css/bootstrap.popover.css\">";

	my $MathJax = $ce->{webworkURLs}->{MathJax};
	
	print CGI::start_script({type=>"text/javascript", src=>$MathJax}), CGI::end_script();

	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/ProblemGrader/problemgrader.js"}), CGI::end_script();
	
	return "";

}


sub initialize {
	my ($self)     = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $authz      = $r->authz;
	my $db         = $r->db;	
	my $courseName     = $urlpath->arg("courseID");
	my $setID      = $urlpath->arg("setID");
	my $problemID  = $urlpath->arg("problemID");
	my $user       = $r->param('user');

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");	
	return unless $authz->hasPermissions($user, "score_sets");	


	# if we need to gothrough and update grades
	if ($r->param('assignGrades')) {
	    $self->addmessage(CGI::div({class=>'ResultsWithoutError'}, "Grades have been saved for all current users."));

	    my @users = $db->listUsers;
	
	    foreach my $userID (@users) {
		my $userProblem = $db->getUserProblem($userID,$setID,$problemID);
		next unless $userProblem && defined($r->param("$userID.score"));
		#update grades and set flags
		$userProblem->{flags} =~ s/needs_grading/graded/;
		if  ($r->param("$userID.mark_correct")) {
		    $userProblem->status(1);
		} else {
		    my $newscore = $r->param("$userID.score")/100;
		    if ($newscore != $userProblem->status) {
			$userProblem->status($newscore);
		    }
		}

		$db->putUserProblem($userProblem);

		#if the instructor added a comment we should save that to the latest answer
		if ($r->param("$userID.comment")) {
		    my $comment = $r->param("$userID.comment");
		    my $userPastAnswerID = $db->latestProblemPastAnswer($courseName, $userID, $setID, $problemID); 
		    
		    if ($userPastAnswerID) {
			my $userPastAnswer = $db->getPastAnswer($userPastAnswerID);
			$userPastAnswer->comment_string($comment);
			warn "Couldn't save comment" unless $db->putPastAnswer($userPastAnswer);
		    }
		}
	    }
	}
}


sub body {
	my ($self)         = @_;
	my $r              = $self->r;
	my $urlpath        = $r->urlpath;
	my $db             = $r->db;
	my $ce             = $r->ce;
	my $authz          = $r->authz;
	my $webworkRoot    = $ce->{webworkURLs}->{root};
	my $courseName     = $urlpath->arg("courseID");
	my $setID          = $urlpath->arg("setID");
	my $problemID      = $urlpath->arg("problemID");
	my $userID           = $r->param('user');
	my $key = $r->param('key');
	my $displayMode   = $self->{displayMode};
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	# to make grabbing these options easier, we'll pull them out now...
	my %imagesModeOptions = %{$ce->{pg}->{displayModeOptions}->{images}};
	
	# set up some display stuff
	my $imgGen = WeBWorK::PG::ImageGenerator->new(
		tempDir         => $ce->{webworkDirs}->{tmp},
		latex	        => $ce->{externalPrograms}->{latex},
		dvipng          => $ce->{externalPrograms}->{dvipng},
		useCache        => 1,
		cacheDir        => $ce->{webworkDirs}->{equationCache},
		cacheURL        => $ce->{webworkURLs}->{equationCache},
		cacheDB         => $ce->{webworkFiles}->{equationCacheDB},
		dvipng_align    => $imagesModeOptions{dvipng_align},
		dvipng_depth_db => $imagesModeOptions{dvipng_depth_db},
	);
	

	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to acces the Instructor tools."))
		unless $authz->hasPermissions($userID, "access_instructor_tools");
		
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to grade homework sets."))
		unless $authz->hasPermissions($userID, "score_sets");	
	
	# DBFIXME duplicate call
	my @users = $db->listUsers;
	my $set = $db->getMergedSet($userID, $setID); # checked
	my $problem = $db->getMergedProblem($userID, $setID, $problemID); # checked
	my $user = $db->getUser($userID);

	return CGI::div({class=>"ResultsWithError"}, CGI::p("This set needs to be assigned to you before you can grade it."))	unless $set && $problem;	

	#set up a silly problem to render the problem text
	my $pg = WeBWorK::PG->new(
	    $ce,
	    $user,
	    $key,
	    $set,
	    $problem,
	    $set->psvn, # FIXME: this field should be removed
	    $formFields,
	    { # translation options
		displayMode     => $displayMode,
		showHints       => 0,
		showSolutions   => 0,
		refreshMath2img => 0,
		processAnswers  => 1,
		permissionLevel => $db->getPermissionLevel($userID)->permission,
		effectivePermissionLevel => $db->getPermissionLevel($userID)->permission,
	    },
	    );
	
	
	# check to see what type the answers are.  right now it only checks for essay but could do more
	my %answerHash = %{ $pg->{answers} };
	my @answerTypes;

	foreach (sortByName(undef, keys %answerHash)) {
	    push(@answerTypes,$answerHash{$_}->{type});
	}

	print CGI::p($pg->{body_text});

	print CGI::start_form({method=>"post", action => $self->systemLink( $urlpath, authen=>0), id=>"problem-grader-form", name=>"problem-grader-form" });
	 
	my $selectAll =CGI::input({-type=>'button', -name=>'check_all', -value=>'Mark All',
				   onClick => "\$('.mark_correct').each(function () { if (\$(this).attr('checked')) {\$(this).attr('checked',false);} else {\$(this).attr('checked',true);}});" });

	print CGI::start_table({width=>"1020px"});
	print CGI::Tr({-valign=>"top"}, CGI::th(["Section", "Name","&nbsp;","Latest Answer","&nbsp;","Mark Correct<br>".$selectAll, "&nbsp;", "Score (%)", "&nbsp;", "Comment"]));
	print CGI::Tr(CGI::td([CGI::hr(), CGI::hr(),"",CGI::hr(),"",CGI::hr(),"",CGI::hr(),"",CGI::hr(),"&nbsp;"]));

	my $viewProblemPage = $urlpath->new(type => 'problem_detail', args => { courseID => $courseName, setID => $setID, problemID => $problemID });

	my %dropDown;
	my $delta = $ce->{options}{problemGraderScoreDelta};
	#construct the drop down.  
	for (my $i=int(100/$delta); $i>=0; $i--) {
	  $dropDown{$i*$delta}=$i*$delta;
	}
	
	my @scores = sort {$b <=> $a} keys %dropDown;
	
	my @myUsers = ();
	my (@viewable_sections, @viewable_recitations);
	if (defined $ce->{viewable_sections}->{$userID})
		{@viewable_sections = @{$ce->{viewable_sections}->{$userID}};}
	if (defined $ce->{viewable_recitations}->{$userID})
		{@viewable_recitations = @{$ce->{viewable_recitations}->{$userID}};}
	if (@viewable_sections or @viewable_recitations){
		foreach my $studentL (@users){
			my $keep = 0;
			my $student = $db->getUser($studentL);
			foreach my $sec (@viewable_sections){
				if ($student->section() eq $sec){$keep = 1; last;}
			}
			foreach my $rec (@viewable_recitations){
				if ($student->recitation() eq $rec){$keep = 1; last;}
			}
			if ($keep) {push @myUsers, $studentL;}		
		}
	}
	else {@myUsers = @users;}

	
	# get user records
	my @userRecords  = ();
	foreach my $currentUser ( @myUsers) {
		my $userObj = $db->getUser($currentUser); #checked
		die "Unable to find user object for $currentUser. " unless $userObj;
		push (@userRecords, $userObj );
	}

	@userRecords = sort { ( lc($a->section) cmp lc($b->section) ) || 
	                     ( lc($a->last_name) cmp lc($b->last_name )) } @userRecords;
	

	#for each user get their latest answer from the past answer db
	foreach my $userRecord (@userRecords) {

	    my $statusClass = $ce->status_abbrev_to_name($userRecord->status) || "";
	    
	    my $userID = $userRecord->user_id;
	    my $viewProblemLink = $self->systemLink($viewProblemPage, params => { effectiveUser => $userID });
	    my $userPastAnswerID = $db->latestProblemPastAnswer($courseName, $userID, $setID, $problemID); 
	    my $userAnswerString;
	    my $comment = "";
	    my $userProblem = $db->getUserProblem($userID,$setID,$problemID);
	    my $noCommentField=0;

	    next unless $userProblem;

	    if ($userPastAnswerID && $userProblem) {

		my $userPastAnswer = $db->getPastAnswer($userPastAnswerID);
		my @scores = split(//,$userPastAnswer->scores);
		my @answers = split(/\t/,$userPastAnswer->answer_string);
		$comment = $userPastAnswer->comment_string;
		
		#Skip this answer if the pg file doesn't match the current pg file
		if (defined($userPastAnswer->source_file) &&
		    $userPastAnswer->source_file ne $problem->source_file) {
		    next;
		}



		for (my $i = 0; $i<= $#answers; $i++) {
		    
		    my $answer = $answers[$i];

		    #generate answer text.  Need to process it if its an essay answer
		    # if the answwer Type is undefined then just print the result and hope for the best. 

		    if (!defined($answerTypes[$i])) {
			$userAnswerString .= CGI::p(HTML::Entities::encode_entities($answer));
		    
		    } elsif ($answerTypes[$i] eq 'essay') {
			
			$answer = HTML::Entities::encode_entities($answer);
			$answer =~ s/\n/<br>/g;
			$userAnswerString .= CGI::p({class=>'essay-answer'},
						    $answer);
			
		    } elsif ($answerTypes[$i] eq 'Value (Formula)') {
			#if its a formula then render it and color it
				$userAnswerString .= CGI::p(CGI::div({class => 'graded-answer', style => $scores[$i] ? 
				       "color:#006600": "color:#660000" }, 
				'`'.HTML::Entities::encode_entities($answer).'`'));

		    }else {
			# if it isnt an essay then don't render it but color it 
			$userAnswerString .= CGI::p(CGI::div({class => 'graded-answer', style => $scores[$i] ? 
				       "color:#006600": "color:#660000" }, 
							     HTML::Entities::encode_entities($answer)));
		    }
		}
		
	    } else {
		$noCommentField = 1;
		$userAnswerString = "There are no answers for this student.";
	    }
	    
	    my $score = int(100*$userProblem->status);
	    
	    my $prettyName = $userRecord->last_name
		. ", "
		. $userRecord->first_name;

	    #create form for scoring

	    my $commentBox = '';
	    $commentBox= CGI::textarea({name=>"$userID.comment",
				      value=>"$comment",
				      rows=>3,
					cols=>30,}).CGI::br().CGI::input({-class=>'preview', -type=>'button', -name=>"$userID.preview", -value=>"Preview" }) unless $noCommentField;
	    

	    # this selects the score available in the drop down that is just above the student score
	    my $selectedScore = 0;
	    foreach my $item (@scores) {
	      if ($score <= $item) {
		$selectedScore = $item;
	      }
	    }
	    
	    print CGI::Tr({-valign=>"top"}, 
			  CGI::td({},[
				      $userRecord->section,
				      CGI::div({class=>
			$userProblem->flags =~ /needs_grading/ 
				   ? "NeedsGrading $statusClass" :
				     $statusClass}, CGI::a({href => $viewProblemLink, target=>"WW_View"}, $prettyName)), " ", 
				      
				      $userAnswerString, " ",
				      CGI::checkbox({
					  type=>"checkbox",
					  class=>"mark_correct",
					  name=>"$userID.mark_correct",
					  value=>"1",
					  label=>"",
		
						    }), " ",
				      CGI::popup_menu(-name=>"$userID.score",
						      -class=> "score-selector",
						      -values => \@scores,
						      -default => $selectedScore,
				                      -labels => \%dropDown)
				      ," ", $commentBox
				  ])	  
		);
	    print CGI::Tr(CGI::td([CGI::hr(), CGI::hr(),"",CGI::hr(),"",CGI::hr(),"",CGI::hr(),"",CGI::hr(),"&nbsp;"]));


#  Text field for grade
#				      CGI::input({type=>"text",
#						  name=>"$userID.score",
#						  value=>"$score",
#						  size=>4,})
#				      
#				  
#				  ])
#		);


	}

	print CGI::end_table();
	print $self->hidden_authen_fields;
	print CGI::submit({name=>"assignGrades", value=>"Save"});

	print CGI::end_form();
	
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
	
	MathJax.Hub.Queue([ "Typeset", MathJax.Hub,'graded-answer']);
	MathJax.Hub.Queue([ "Typeset", MathJax.Hub,'essay-answer']);
	</script>
EOS
	

	return "";
}


1;
