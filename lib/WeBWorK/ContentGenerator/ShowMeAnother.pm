################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Problem.pm,v 1.225 2010/05/28 21:29:48 gage Exp $
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

package WeBWorK::ContentGenerator::ShowMeAnother;
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator::Problem);  # not needed?

=head1 NAME
 
WeBWorK::ContentGenerator::ShowMeAnother - Show students alternate versions of current problems. 

=cut

use strict;
use warnings;
use WeBWorK::CGI;
use WeBWorK::PG;
use WeBWorK::Debug;
use WeBWorK::Utils qw(wwRound before after jitar_id_to_seq); 

################################################################################
# output utilities
################################################################################

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

	# We want to run the existing pre_header_initialize with
	# the database seed to get a pure copy of the original problem
	# to test against.

	my $problemSeed = $r->param("problemSeed");
	$r->param("problemSeed",'');

	# Run existsing initialization
	$self->SUPER::pre_header_initialize();

	# this has to be set back because of CGI and sticky params. 
	$r->param("problemSeed",$problemSeed);

	my $user = $self->{user};
	my $effectiveUser = $self->{effectiveUser};
	my $set = $self->{set};
	my $problem = $self->{problem};
	my $displayMode = $self->{displayMode};
	my $redisplay = $self->{redisplay};
	my $submitAnswers = $self->{submitAnswers};
	my $checkAnswers = $self->{checkAnswers};
	my $previewAnswers = $self->{previewAnswers};
	my $formFields = $self->{formFields};
	
	# a hash containing information for showMeAnother
	#       active:        has the button been pushed?
	#       CheckAnswers:  has the user clicked Check Answers while SMA is active
	#       IsPossible:    checks to see if generating a new seed changes the problem (assume it is possible by default)
	#       TriesNeeded:   the number of times the student needs to attempt the problem before the button is available
	#       MaxReps:       the Maximum Number of times that showMeAnother can be clicked (specified in course configuration
	#       options:       the options available when showMeAnother has been pushed (check answers, see solution (when available), see correct answer)
	#                      these are set via check boxes from the configuration screen
	#       Count:         the number of times the student has clicked SMA (or clicked refresh on the page)
	#       Preview:       has the preview button been clicked while SMA is active?
	#       DisplayChange: has a display change been made while SMA is active?

	my %SMAoptions = map {$_ => 1} @{$ce->{pg}->{options}->{showMeAnother}};
	my %showMeAnother = (
	    active       => (!($checkAnswers or $previewAnswers) and $ce->{pg}->{options}->{enableShowMeAnother} and ($problem->{showMeAnother}>-1 or $problem->{showMeAnother}==-2)),
            CheckAnswers => ($checkAnswers and $r->param("showMeAnotherCheckAnswers") and $ce->{pg}->{options}->{enableShowMeAnother}),
            IsPossible => 1,
            TriesNeeded => $problem->{showMeAnother},
            MaxReps => $ce->{pg}->{options}->{showMeAnotherMaxReps},
            options => {
		checkAnswers  => exists($SMAoptions{'SMAcheckAnswers'}),
		showSolutions => exists($SMAoptions{'SMAshowSolutions'}),
		showCorrect   => exists($SMAoptions{'SMAshowCorrect'}),
		showHints     => exists($SMAoptions{'SMAshowHints'}),
	    },
            Count => $problem->{showMeAnotherCount},
            Preview => ($previewAnswers and $r->param("showMeAnotherCheckAnswers") and $ce->{pg}->{options}->{enableShowMeAnother}), 
            DisplayChange => ( $r->param("SMAdisplayChange") and $ce->{pg}->{options}->{enableShowMeAnother}), 
	    );
	
	# if $showMeAnother{Count} is somehow not an integer, make it one
	$showMeAnother{Count} = 0 unless ($showMeAnother{Count} =~ /^[+-]?\d+$/);

	# if $showMeAnother{TriesNeeded} is somehow not an integer or if its -2, use the default value 
        $showMeAnother{TriesNeeded} = $ce->{pg}->{options}->{showMeAnotherDefault} if ($showMeAnother{TriesNeeded} !~ /^[+-]?\d+$/ || $showMeAnother{TriesNeeded} == -2);
	
	# store the showMeAnother hash for the check to see if the button can be used
	# (this hash is updated and re-stored after the can, must, will hashes)
	$self->{showMeAnother} = \%showMeAnother;
	
	# Now die if we aren't allowed to show me another here
	die('You are not allowed to use Show Me Another for this problem.')
	    unless $self->can_showMeAnother($user, $effectiveUser, $set, $problem,0);

	my $want = $self->{want};
	$want->{showMeAnother} = 1;
	
	my $must = $self->{must};
	$must->{showMeAnother} = 0;
	 
	# does the user have permission to use certain options?
	my @args = ($user, $effectiveUser, $set, $problem);

	my $can = $self->{can};
	$can->{showMeAnother} = $self->can_showMeAnother(@args, $submitAnswers);

	# store text of original problem for later comparison with text from problem with new seed
	my $showMeAnotherOriginalPG = WeBWorK::PG->new(
	    $ce,
	    $effectiveUser,
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
		processAnswers  => 0,
		permissionLevel => $db->getPermissionLevel($userName)->permission,
		effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
	    },
	    );
	
	# if showMeAnother is active, then output a new problem in a new tab with a new seed
	if ($showMeAnother{active} and $can->{showMeAnother}) {
	    
	    # change the problem seed
	    my $oldProblemSeed = $problem->{problem_seed};
	    my $newProblemSeed;
	    
	    # check to see if changing the problem seed will change the problem 
	    for my $i (0..$ce->{pg}->{options}->{showMeAnotherGeneratesDifferentProblem}) {
                do {$newProblemSeed = int(rand(10000))} until ($newProblemSeed != $oldProblemSeed ); 
                $problem->{problem_seed} = $newProblemSeed;
                my $showMeAnotherNewPG = WeBWorK::PG->new(
                    $ce,
                    $effectiveUser,
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
			processAnswers  => 0,
			permissionLevel => $db->getPermissionLevel($userName)->permission,
			effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
                    },
		    );
		
                # check to see if we've found a new version
                if ($showMeAnotherNewPG->{body_text} ne $showMeAnotherOriginalPG->{body_text}) {
		  # if we've found a new version, then 
		  # increment the counter detailing the number of times showMeAnother has been used 
		  # unless we're trying to check answers from the showMeAnother screen
		  unless ($showMeAnother{CheckAnswers}) {
		  
		    $showMeAnother{Count}++ unless($showMeAnother{CheckAnswers});
		    # update the database (make sure to put the old problem seed back in)
		    my $userProblem = $db->getUserProblem($effectiveUserName,$setName,$problemNumber);
		    $userProblem->{showMeAnotherCount}=$showMeAnother{Count};
		    $db->putUserProblem($userProblem);
		  }
		    
		    # make sure to switch on the possibility
		    $showMeAnother{IsPossible} = 1;
		    
		    # exit the loop
		    last;
		} else {
		    # otherwise a new version was *not* found, and 
		    # showMeAnother is not possible
		    $showMeAnother{IsPossible} = 0;
		}
	    }
	    
	} elsif (($showMeAnother{CheckAnswers} or $showMeAnother{Preview}) &&
		 defined($problemSeed) && 
		 $problemSeed != $problem->problem_seed) {
	    $showMeAnother{IsPossible} = 1;
	    $problem->problem_seed($problemSeed);
	    #### One last check to see if students  have hard coded in a key
	    #### which matches the original problem
	    my $showMeAnotherNewPG = WeBWorK::PG->new(
		$ce,
		$effectiveUser,
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
		    processAnswers  => 0,
		    permissionLevel => $db->getPermissionLevel($userName)->permission,
		    effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
		},
		);
	
	    if ($showMeAnotherNewPG->{body_text} eq $showMeAnotherOriginalPG->{body_text})	{
		$showMeAnother{IsPossible} = 0;
		$showMeAnother{CheckAnswers} = 0;
		$showMeAnother{Preview} = 0;
	    }
  			    
	} else {
	    $showMeAnother{IsPossible} = 0;
	    $showMeAnother{CheckAnswers} = 0;
	    $showMeAnother{Preview} = 0;
	}
	
	# if showMeAnother is active, then disable all other options
	if ( ( $showMeAnother{active} or $showMeAnother{CheckAnswers} or $showMeAnother{Preview}) and $can->{showMeAnother} ) {
	    $can->{recordAnswers}  = 0;
	    $can->{checkAnswers}   = 0; # turned on if showMeAnother conditions met below
	    $can->{getSubmitButton}= 0;

            # only show solution if showMeAnother has been clicked (or refreshed)
            # less than the maximum amount allowed specified in Course Configuration, 
            # and also make sure that showMeAnother is possible
            if(($showMeAnother{Count}<=($showMeAnother{MaxReps}) or ($showMeAnother{MaxReps}==-1))
	       and $showMeAnother{IsPossible} )
            {
		$can->{showCorrectAnswers} = ($showMeAnother{options}->{showCorrect} and $showMeAnother{options}->{checkAnswers});
		$can->{showHints}          = $showMeAnother{options}->{showHints};
		$can->{showSolutions}      = $showMeAnother{options}->{showSolutions};
		$must->{showSolutions}     = $showMeAnother{options}->{showSolutions};
		$can->{checkAnswers}       = $showMeAnother{options}->{checkAnswers};
		# rig the nubmer of attempts to show hints if showing hitns
		if ($can->{showHints}) {
		    $problem->num_incorrect(1000);
		}
            }
	}
	
	# final values for options
	my $will = $self->{will};
	foreach (keys %$must) {
		$will->{$_} = $can->{$_} && ($want->{$_} || $must->{$_});
	}



	
	##### translation #####

	### Unfortunately we have to do this over because we potentially
	### picked a new problem seed.  
	
	debug("begin pg processing");
	my $pg = WeBWorK::PG->new(
		$ce,
		$effectiveUser,
		$key,
		$set,
		$problem,
		$set->psvn, # FIXME: this field should be removed
		$formFields,
		{ # translation options
			displayMode     => $displayMode,
			showHints       => $will->{showHints},
			showSolutions   => $will->{showSolutions},
			refreshMath2img => $will->{showHints} || $will->{showSolutions},
			processAnswers  => 1,
			permissionLevel => $db->getPermissionLevel($userName)->permission,
			effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
		},
	);

	debug("end pg processing");
	
	##### update and fix hint/solution options after PG processing #####
	
	$can->{showHints}     &&= $pg->{flags}->{hintExists}  
	                    &&= $pg->{flags}->{showHintLimit}<=$pg->{state}->{num_of_incorrect_ans};
	$can->{showSolutions} &&= $pg->{flags}->{solutionExists};
	
	##### record errors #########
	if (ref ($pg->{pgcore}) )  {
		my @debug_messages     = @{$pg->{pgcore}->get_debug_messages};
		my @warning_messages   = @{$pg->{pgcore}->get_warning_messages};
		my @internal_errors    = @{$pg->{pgcore}->get_internal_debug_messages};
		$self->{pgerrors}      = @debug_messages||@warning_messages||@internal_errors;  # is 1 if any of these are non-empty
		$self->{pgdebug}       =    \@debug_messages;
		$self->{pgwarning}     =    \@warning_messages;
		$self->{pginternalerrors} = \@internal_errors ;
	} else {
		warn "Processing of this PG problem was not completed.  Probably because of a syntax error.
		      The translator died prematurely and no PG warning messages were transmitted.";
	}

	$self->{showMeAnother} = \%showMeAnother;
	$self->{pg} = $pg;
}

# We disable showOldAnswers because old answers are answers to the original
# question and not to this question. 

sub can_showOldAnswers {

        return 0;
}

sub title {
	my ($self) = @_;
	my $r = $self->r;
	# using the url arguments won't break if the set/problem are invalid
	my $setID =  $self->r->urlpath->arg("setID");
	my $problemID = $self->r->urlpath->arg("problemID");

	my $set = $r->db->getGlobalSet($setID);

	$setID = WeBWorK::ContentGenerator::underscore2nbsp($setID);
	if ($set && $set->assignment_type eq 'jitar') {
	    $problemID = join('.',jitar_id_to_seq($problemID));
	}


	return $r->maketext("[_1]: Problem [_2] Show Me Another",$setID, $problemID);
}

sub nav {
	my ($self, $args) = @_;
	my $r = $self->r;
	my %can = %{ $self->{can} };

	# if showMeAnother or check answers from showMeAnother
	# is active, then don't show the navigation bar
	return "";
}
	
# prints out the body of the current problem

sub output_problem_body{
	my $self = shift;
	my $pg = $self->{pg};
	my %will = %{ $self->{will} };
	my %showMeAnother = %{ $self->{showMeAnother} };

	$self->SUPER::output_problem_body()
		#ignore body if SMA was pushed and no new problem will be shown;
		if ($will{showMeAnother} and $showMeAnother{IsPossible});
	return "";
}

# output_checkboxes subroutine

# prints out the checkbox input elements that are available for the current problem

sub output_checkboxes{
	my $self = shift;
	my %can = %{ $self->{can} };
	my %will = %{ $self->{will} };
	my %showMeAnother = %{ $self->{showMeAnother} };

	#skip check boxes if SMA was pushed and no new problem will be shown
	if ($showMeAnother{IsPossible} and $will{showMeAnother}) 
	{
	    $self->SUPER::output_checkboxes();
	    
	}
	return "";
}

# output_submit_buttons

# prints out the submit button input elements that are available for the current problem

sub output_submit_buttons{
	my $self = shift;
	my %will = %{ $self->{will} };
	my %showMeAnother = %{ $self->{showMeAnother} };

	# skip buttons if SMA button has been pushed but there is no new problem shown
	if ($showMeAnother{IsPossible} and $will{showMeAnother}){
	    $self->SUPER::output_submit_buttons();
	}
	    
	return "";
}

# output_score_summary subroutine

# prints out a summary of the student's current progress and status on the current problem

sub output_score_summary{
	my $self = shift;

	# skip score summary
	
	return "";
}

# output_summary subroutine

# prints out the summary of the questions that the student has answered 
# for the current problem, along with available information about correctness

sub output_summary{
	
	my $self = shift;
	my $pg = $self->{pg};
	my %will = %{ $self->{will} };
	my %can = %{ $self->{can} };
	my %showMeAnother = %{ $self->{showMeAnother} };
	my $checkAnswers = $self->{checkAnswers};
	my $previewAnswers = $self->{previewAnswers};
	my $showPartialCorrectAnswers = $self->{pg}{flags}{showPartialCorrectAnswers};

	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;

	# if $showMeAnother{Count} is somehow not an integer, make it one
	$showMeAnother{Count} = 0 unless ($showMeAnother{Count} =~ /^[+-]?\d+$/);

	if ($will{checkAnswers}) {
	    if ($showMeAnother{CheckAnswers} and $can{showMeAnother}){
		# if the student is checking answers to a new problem, give them a reminder that they are doing so
		print CGI::div({class=>'showMeAnotherBox'},$r->maketext("You are currently checking answers to a different version of your problem - these will not be recorded, and you should remember to return to your original problem once you are done here.")),CGI::br();
	    }
	} elsif ($previewAnswers) {
	    # if the student is previewing answers to a new problem, give them a reminder that they are doing so
        if($showMeAnother{Preview} and $can{showMeAnother}){
          print CGI::div({class=>'showMeAnotherBox'},$r->maketext("You are currently previewing answers to a different version of your problem - these will not be recorded, and you should remember to return to your original problem once you are done here.")),CGI::br();
        }
	} elsif ( $showMeAnother{IsPossible} and $will{showMeAnother}){
	    # the feedback varies a little bit if Check Answers is available or not
	    my $checkAnswersAvailable = ($showMeAnother{options}->{checkAnswers}) ?
	      $r->maketext("You may check your answers to this problem without affecting the maximum number of tries to your original problem.") :"";
	    my $solutionShown;
	    # if showMeAnother has been clicked and a new version has been found,
	    # give some details of what the student is seeing
	    if($showMeAnother{Count}<=$showMeAnother{MaxReps} or ($showMeAnother{MaxReps}==-1)){
		# check to see if a solution exists for this problem, and vary the feedback accordingly
		if($pg->{flags}->{solutionExists} && $showMeAnother{options}->{showSolutions}){
		    $solutionShown = $r->maketext("There is a written solution available");
		} elsif ($showMeAnother{options}->{showSolutions} and $showMeAnother{options}->{showCorrect} and $showMeAnother{options}->{checkAnswers}) {
		    $solutionShown = $r->maketext("There is no written solution available for this problem, but you can still view the correct answers");
		  } elsif ($showMeAnother{options}->{showSolutions}) {
		    $solutionShown = $r->maketext("There is no written solution available for this problem.");
		  }
	    }
	    print CGI::div({class=>'showMeAnotherBox'},$r->maketext("Here is a new version of your problem."), $solutionShown,$checkAnswersAvailable),CGI::br();
	    print CGI::div({class=>'ResultsAlert'},$r->maketext("Remember to return to your original problem when you're finished here!")),CGI::br();
	} elsif($showMeAnother{active} and $showMeAnother{IsPossible} and !$can{showMeAnother}) {
	    if($showMeAnother{Count}>=$showMeAnother{MaxReps}){
		my $solutionShown = ($showMeAnother{options}->{showSolutions} and $pg->{flags}->{solutionExists}) ? $r->maketext("The solution has been removed.") : "";
		print CGI::div({class=>'ResultsAlert'},$r->maketext("You are only allowed to click on Show Me Another [quant,_1,time,times] per problem. [_2] Close this tab, and return to the original problem.",$showMeAnother{MaxReps},$solutionShown  )),CGI::br();
	    } elsif ($showMeAnother{Count}<$showMeAnother{TriesNeeded}) {
		print CGI::div({class=>'ResultsAlert'},$r->maketext("You must attempt this problem [quant,_1,time,times] before Show Me Another is available.",$showMeAnother{TriesNeeded})),CGI::br();
	    }
	} elsif ($can{showMeAnother} && !$showMeAnother{IsPossible}){
	    # print this if showMeAnother has been clicked, but it is not possible to
	    # find a new version of the problem
	    print CGI::div({class=>'ResultsAlert'},$r->maketext("WeBWorK was unable to generate a different version of this problem; close this tab, and return to the original problem.")),CGI::br();
	}

	if ($showMeAnother{IsPossible} and $will{showMeAnother}) {
	    $self->SUPER::output_summary();
	}

	return "";
}


# outputs the hidden fields required for the form

sub output_hidden_info {
    my $self = shift;
    my %showMeAnother = %{ $self->{showMeAnother} };
    my $problemSeed = $self->{problem}->problem_seed;
    
    # hidden field for clicking Preview Answers and Check Answers from a Show Me Another screen
    # it needs to send the seed from showMeAnother back to the screen
    if($showMeAnother{active} or $showMeAnother{CheckAnswers} or $showMeAnother{Preview}){
	print CGI::hidden({name => "showMeAnotherCheckAnswers", id=>"showMeAnotherCheckAnswers_id", value => 1});
        # output the problem seed from ShowMeAnother so that it can be used in Check Answers
        print( CGI::hidden({name => "problemSeed", value  =>  $problemSeed}));
    }

    $self->SUPER::output_hidden_info();
    
    return "";
}


1;
