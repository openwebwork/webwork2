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
	my $user = $r->param('user');
	
	my $setName = $urlpath->arg("setID");
	my $problemNumber = $r->urlpath->arg("problemID");
	my $userName = $r->param('user');
	my $effectiveUserName = $r->param('effectiveUser');
	my $key = $r->param('key');
	my $editMode = $r->param("editMode");
	
	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");	
	return unless $authz->hasPermissions($user, "score_sets");

	my $displayMode        = $r->param("displayMode") || $ce->{pg}->{options}->{displayMode};
	$self->{displayMode}    = $displayMode;
}

sub options {
	my ($self) = @_;
	
	my $displayMode = $self->{displayMode};
	
	my @options_to_show = "displayMode";
	
	return $self->optionsMacro(
		options_to_show => \@options_to_show,

	);
}


sub initialize {
	my ($self)     = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $authz      = $r->authz;
	my $db         = $r->db;	
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
	

	my $tthPreambleCache;

	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to acces the Instructor tools."))
		unless $authz->hasPermissions($userID, "access_instructor_tools");
		
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to grade homework sets."))
		unless $authz->hasPermissions($userID, "score_sets");	
	
	# DBFIXME duplicate call
	my @users = $db->listUsers;
	my $set = $db->getMergedSet($userID, $setID); # checked
	my $problem = $db->getMergedProblem($userID, $setID, $problemID); # checked
	my $user = $db->getUser($userID);

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

	print CGI::start_form({method=>"post", action => $self->systemLink( $urlpath, authen=>0), name=>"classlist" });
	 
	my $selectAll =CGI::input({-type=>'button', -name=>'check_all', -value=>'Mark All Correct',
				   onClick => "for (i in document.classlist.elements)  { 
	                       if (document.classlist.elements[i].className == 'mark_correct') { 
	                           document.classlist.elements[i].checked = true
	                       }
	                    }" });

	print CGI::start_table({});
	print CGI::Tr({-valign=>"top"}, CGI::th(["Section", "Student Name","&nbsp;","Latest Answer","&nbsp;","Mark Correct<br>".$selectAll, "&nbsp;", "Score (%)"]));
	print CGI::Tr(CGI::td([CGI::hr(), CGI::hr(),"",CGI::hr(),"",CGI::hr(),"",CGI::hr(),"&nbsp;"]));

	# get user records
	my @userRecords  = ();
	foreach my $currentUser ( @users) {
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
	    my $userPastAnswerID = $db->latestProblemPastAnswer($courseName, $userID, $setID, $problemID); 
	    my $userAnswerString;

	    if ($userPastAnswerID) {
		my $userPastAnswer = $db->getPastAnswer($userPastAnswerID);
		my @scores = split(//,$userPastAnswer->scores);
		my @answers = split(/\t/,$userPastAnswer->answer_string);

		for (my $i = 0; $i<= $#answers; $i++) {
		    
		    my $answer = $answers[$i];

		    #generate answer text.  Need to process it if its an essay answer

		    if ($answerTypes[$i] eq 'essay') {
			
			#if its an essay type answer then set up a silly problem to render the text 
			# provided by the student.  There *has* to be a better way to do this.  

			#### WARNING #####
			### $answer needs to be sanitized.  It could currently contain badness written 
			### into the answer by the student
			# Ad Hoc Sanitization :( 
						
			$answer =~ s/script/ohnoyoudiint/g;
			
			$problem->value(0);
			local $ce->{pg}->{specialPGEnvironmentVars}->{problemPreamble}{HTML} = ''; 
			local $ce->{pg}->{specialPGEnvironmentVars}->{problemPostamble}{HTML} = '';
			my $source = "DOCUMENT();\n loadMacros(\"PG.pl\",\"PGbasicmacros.pl\");\n TEXT(\&beginproblem);\n BEGIN_TEXT\n";
			$source .= $answer . "\nEND_TEXT\n ENDDOCUMENT();";
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
				refreshMath2img => 1,
				processAnswers  => 0,
				permissionLevel => 0,
				effectivePermissionLevel => 0,
				r_source => \$source,
			    },
			    );
			

			my $htmlout = $pg->{body_text};

			$htmlout =~ s/^\(0.*\<BR\>//;

			$userAnswerString .= CGI::p($htmlout);
			
		    } else {
			# if itsn ot an essay then don't render it but color it based off if 
			# webwork thinks its right or not
			$userAnswerString .= CGI::p(CGI::div({style => $scores[$i] ? 
				       "color:#006600": "color:#660000" }, $answer));
		    }
		}
		
	    } else {
		$userAnswerString = "There are no answers for this student.";
	    }
	    
	    my $userProblem = $db->getUserProblem($userID,$setID,$problemID);
	    my $score = int(100*$userProblem->status);
	    
	    my $prettyName = $userRecord->last_name
		. ", "
		. $userRecord->first_name;

	    #create form for scoring

	    my %dropDown;
	    #construct the drop down.  Right now it does all numbers from 
	    # 1 to 100, but this could be changed by config
	    for (my $i=100; $i>=0; $i--) {
		    $dropDown{$i}=$i;
	    }

	    print CGI::Tr({-valign=>"top"}, 
			  CGI::td({},[
				      $userRecord->section,
				      CGI::div({class=>
			$userProblem->flags =~ /needs_grading/ 
				   ? "NeedsGrading $statusClass" :
				     $statusClass}, $prettyName), " ", 
				      
				      $userAnswerString, " ",
				      CGI::checkbox({
					  type=>"checkbox",
					  class=>"mark_correct",
					  name=>"$userID.mark_correct",
					  value=>"1",
					  label=>"",
		
						    }), " ",
				      CGI::popup_menu(-name=>"$userID.score",
						      -values => [sort {$b <=> $a} keys %dropDown],
						      -default => $score,
				                      -labels => \%dropDown)
				      ])
		);

#  Text field for gradex
#				      CGI::input({type=>"text",
#						  name=>"$userID.score",
#						  value=>"$score",
#						  size=>4,})
#				      
#				  
#				  ])
#		);

	    print CGI::Tr(CGI::td([CGI::hr(),CGI::hr(),"",CGI::hr(),"",CGI::hr(),"",CGI::hr()]));
	}

	print CGI::end_table();
	print $self->hidden_authen_fields;
	print CGI::submit({name=>"assignGrades", value=>"Save"});

	print CGI::end_form();
	
	return "";
}


1;
