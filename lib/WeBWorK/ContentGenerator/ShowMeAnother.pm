################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
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
use WeBWorK::Utils qw(wwRound before after); 

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
	
	my $user = $db->getUser($userName); # checked
	die "record for user $userName (real user) does not exist."
		unless defined $user;
	
	my $effectiveUser = $db->getUser($effectiveUserName); # checked
	die "record for user $effectiveUserName (effective user) does not exist."
		unless defined $effectiveUser;
		
	# obtain the merged set for $effectiveUser
	my $set = $db->getMergedSet($effectiveUserName, $setName); 
	
	# check that the set is valid;
	# $self->{invalidSet} is set by ContentGenerator.pm
	die($self->{invalidSet}) if $self->{invalidSet};

	$self->{isOpen} = $authz->hasPermissions($userName, "view_unopened_sets") || 
	    ($setName eq "Undefined_Set" || 
	     (time >= $set->open_date && !(
		  $ce->{options}{enableConditionalRelease} && 
		  is_restricted($db, $set, $effectiveUserName))));
	
	die("You do not have permission to view unopened sets") unless $self->{isOpen};	

	# Database fix (in case of undefined visiblity state values)
	# this is only necessary because some people keep holding to ww1.9 which did not have a visible field
	# make sure visible is set to 0 or 1
	if ( $set and $set->visible ne "0" and $set->visible ne "1") {
		my $globalSet = $db->getGlobalSet($set->set_id);
		$globalSet->visible("1");	# defaults to visible
		$db->putGlobalSet($globalSet);
		$set = $db->getMergedSet($effectiveUserName, $setName);
	} else {
		# don't do anything just yet, maybe we're a professor and we're
		# fabricating a set or haven't assigned it to ourselves just yet
	}
		# When a set is created enable_reduced_scoring is null, so we have to set it 
	if ( $set and $set->enable_reduced_scoring ne "0" and $set->enable_reduced_scoring ne "1") {
		my $globalSet = $db->getGlobalSet($set->set_id);
		$globalSet->enable_reduced_scoring("0");	# defaults to disabled
		$db->putGlobalSet($globalSet);
		$set = $db->getMergedSet($effectiveUserName, $setName);
	}
	
	
	# obtain the merged problem for $effectiveUser
	my $problem = $db->getMergedProblem($effectiveUserName, $setName, $problemNumber); # checked
	
	# A very hacky and temporary solution to the max_attempts problem
	# if($problem->max_attempts == ""){
		# $problem->max_attempts = -1;
	# }
	
	if ($authz->hasPermissions($userName, "modify_problem_sets")) {
		# professors are allowed to fabricate sets and problems not
		# assigned to them (or anyone). this allows them to use the
		# editor to 

		# if a User Set does not exist for this user and this set
		# then we check the Global Set
		# if that does not exist we create a fake set
		# if it does, we add fake user data
		unless (defined $set) {
			my $userSetClass = $db->{set_user}->{record};
			my $globalSet = $db->getGlobalSet($setName); # checked

			if (not defined $globalSet) {
				$set = fake_set($db);
			} else {
				$set = global2user($userSetClass, $globalSet);
				$set->psvn(0);
			}
		}
		
		# if that is not yet defined obtain the global problem,
		# convert it to a user problem, and add fake user data
		unless (defined $problem) {
			my $userProblemClass = $db->{problem_user}->{record};
			my $globalProblem = $db->getGlobalProblem($setName, $problemNumber); # checked
			# if the global problem doesn't exist either, bail!
			if(not defined $globalProblem) {
				my $sourceFilePath = $r->param("sourceFilePath");
				die "sourceFilePath is unsafe!" unless path_is_subdir($sourceFilePath, $ce->{courseDirs}->{templates}, 1); # 1==path can be relative to dir
				# These are problems from setmaker.  If declared invalid, they won't come up
				$self->{invalidProblem} = $self->{invalidSet} = 1 unless defined $sourceFilePath;
#				die "Problem $problemNumber in set $setName does not exist" unless defined $sourceFilePath;
				$problem = fake_problem($db);
				$problem->problem_id(1);
				$problem->source_file($sourceFilePath);
				$problem->user_id($effectiveUserName);
			} else {
				$problem = global2user($userProblemClass, $globalProblem);
				$problem->user_id($effectiveUserName);
				$problem->problem_seed(0);
				$problem->status(0);
				$problem->attempted(0);
				$problem->last_answer("");
				$problem->num_correct(0);
				$problem->num_incorrect(0);
			}
		}
		
		# now we're sure we have valid UserSet and UserProblem objects
		# yay!
		
		# now deal with possible editor overrides:
		
		# if the caller is asking to override the source file, and
		# editMode calls for a temporary file, do so
		my $sourceFilePath = $r->param("sourceFilePath");
		if (defined $editMode and $editMode eq "temporaryFile" and defined $sourceFilePath) {
			die "sourceFilePath is unsafe!" unless path_is_subdir($sourceFilePath, $ce->{courseDirs}->{templates}, 1); # 1==path can be relative to dir
			$problem->source_file($sourceFilePath);
		}
		
		# if the problem does not have a source file or no source file has been passed in 
		# then this is really an invalid problem (probably from a bad URL)
		$self->{invalidProblem} = not (defined $sourceFilePath or $problem->source_file);
		
        # if the caller is asking to override the problem seed, do so
		my $problemSeed = $r->param("problemSeed");
		if (defined $problemSeed) {
			$problem->problem_seed($problemSeed);
        }	

		my $visiblityStateClass = ($set->visible) ? $r->maketext("font-visible") : $r->maketext("font-hidden");
		my $visiblityStateText = ($set->visible) ? $r->maketext("visible to students")."." : $r->maketext("hidden from students").".";
		$self->addmessage(CGI::span($r->maketext("This set is [_1]", CGI::span({class=>$visiblityStateClass}, $visiblityStateText))));

  # test for additional problem validity if it's not already invalid
        } else {
		$self->{invalidProblem} = !(defined $problem and ($set->visible || $authz->hasPermissions($userName, "view_hidden_sets")));
		
		$self->addbadmessage(CGI::p($r->maketext("This problem will not count towards your grade."))) if $problem and not $problem->value and not $self->{invalidProblem};
	}

	$self->{userName}          = $userName;
	$self->{effectiveUserName} = $effectiveUserName;
	$self->{user}              = $user;
	$self->{effectiveUser}     = $effectiveUser;
	$self->{set}               = $set;
	$self->{problem}           = $problem;
	$self->{editMode}          = $editMode;
	
	##### form processing #####
	
	# set options from form fields (see comment at top of file for names)
	my $displayMode               = $r->param("displayMode") || $user->displayMode || $ce->{pg}->{options}->{displayMode};
	my $redisplay                 = $r->param("redisplay");
	my $submitAnswers             = $r->param("submitAnswers");
	my $checkAnswers              = $r->param("checkAnswers");
	my $previewAnswers            = $r->param("previewAnswers");

	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	$self->{displayMode}    = $displayMode;
	$self->{redisplay}      = $redisplay;
	$self->{submitAnswers}  = $submitAnswers;
	$self->{checkAnswers}   = $checkAnswers;
	$self->{previewAnswers} = $previewAnswers;
	$self->{formFields}     = $formFields;

	# get result and send to message
	my $status_message = $r->param("status_message");
	$self->addmessage(CGI::p("$status_message")) if $status_message;

	# now that we've set all the necessary variables quit out if the set or problem is invalid
	return if $self->{invalidSet} || $self->{invalidProblem};

	
	
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
	    active       => (!($checkAnswers or $previewAnswers) and $ce->{pg}->{options}->{enableShowMeAnother} and ($problem->{showMeAnother}>-1)),
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

	if($showMeAnother{CheckAnswers}){
        # check the new seed against the old seed - provided that 
        # they are not the same, and that showMeAnother is enabled, together with 
        # checkAnswers enabled then the student is entitled to check answers to a new version
        # of the problem
        #
        # this is essentially the first part of an integrity check to make sure that the user
        # hasn't simply put &showMeAnotherCheckAnswers=1 into the URL
        my $newProblemSeed = $r->param("problemSeed");
        my $oldProblemSeed = $problem->{problem_seed};

	    if (defined $newProblemSeed) {
	    	$problem->problem_seed($newProblemSeed);
	    }

        # showMeAnother{CheckAnswers} is only appropriate if a problemSeed is passed
        # and if showMeAnother is enabled and if the problemSeed is not the original problemSeed
        $showMeAnother{CheckAnswers} = (defined($r->param("problemSeed"))) ?                          
                                        ($r->param("showMeAnotherCheckAnswers")                    
                                        and $ce->{pg}->{options}->{enableShowMeAnother}            
                                        and (($newProblemSeed != $oldProblemSeed) or ($authz->hasPermissions($userName, "modify_problem_sets"))) 
                                        and ($showMeAnother{options}->{checkAnswers})):0;      
    }


    # store the showMeAnother hash for the check to see if the button can be used
    # (this hash is updated and re-stored after the can, must, will hashes)
	$self->{showMeAnother} = \%showMeAnother;

	# Now die if we aren't allowed to show me another here
	die('You are not allowed to use Show Me Another for this problem.')
	    unless $self->can_showMeAnother($user, $effectiveUser, $set, $problem,0);
	
	##### permissions #####

	# what does the user want to do?
	#FIXME  There is a problem with checkboxes -- if they are not checked they are invisible.  Hence if the default mode in $ce is 1
	# there is no way to override this.  Probably this is ok for the last three options, but it was definitely not ok for showing
	# saved answers which is normally on, but you want to be able to turn it off!  This section should be moved to ContentGenerator
	# so that you can set these options anywhere.  We also need mechanisms for making them sticky.
	# Note: ProblemSet and ProblemSets might set showOldAnswers to '', which
	#       needs to be treated as if it is not set.
	my %want = (
		showOldAnswers     => $user->showOldAnswers ne '' ? $user->showOldAnswers  : $ce->{pg}->{options}->{showOldAnswers},
		showCorrectAnswers => $r->param('showCorrectAnswers') || $ce->{pg}->{options}->{showCorrectAnswers},
		showHints          => $r->param("showHints")          || $ce->{pg}->{options}{use_knowls_for_hints} 
		                      || $ce->{pg}->{options}->{showHints},     #set to 0 in defaults.config
		showSolutions      => $r->param("showSolutions") || $ce->{pg}->{options}{use_knowls_for_solutions}      
							  || $ce->{pg}->{options}->{showSolutions}, #set to 0 in defaults.config
        useMathView        => $user->useMathView ne '' ? $user->useMathView : $ce->{pg}->{options}->{useMathView},
		recordAnswers      => $submitAnswers,
		checkAnswers       => $checkAnswers,
		showMeAnother      => 1,
		getSubmitButton    => 1,
	);

	# are certain options enforced?
	my %must = (
		showOldAnswers     => 0,
		showCorrectAnswers => 0,
		showHints          => 0,
		showSolutions      => 0,
		recordAnswers      => ! $authz->hasPermissions($userName, "avoid_recording_answers"),
		checkAnswers       => 0,
		showMeAnother      => 0,
		getSubmitButton    => 0,
	    useMathView        => 0,
	);
	 
	# does the user have permission to use certain options?
	my @args = ($user, $effectiveUser, $set, $problem);

	my %can = (
		showOldAnswers           => $self->can_showOldAnswers(@args),
		showCorrectAnswers       => $self->can_showCorrectAnswers(@args),
		showHints                => $self->can_showHints(@args),
		showSolutions            => $self->can_showSolutions(@args),
		recordAnswers            => 0,
		checkAnswers             => $self->can_checkAnswers(@args, $submitAnswers),
		showMeAnother            => $self->can_showMeAnother(@args, $submitAnswers),
		getSubmitButton          => 0,
        useMathView              => $self->can_useMathView(@args)
	);

    # if showMeAnother is active, then output a new problem in a new tab with a new seed
    if ($showMeAnother{active} and $can{showMeAnother}) {
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
                        displayMode     => $displayMode,
                        showHints       => 0,
                        showSolutions   => 0,
                        refreshMath2img => 0,
                        processAnswers  => 0,
                        permissionLevel => $db->getPermissionLevel($userName)->permission,
                        effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
                },
          );

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
                            displayMode     => $displayMode,
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
                      $showMeAnother{Count}++ unless($showMeAnother{CheckAnswers});

                      # update the database (make sure to put the old problem seed back in)
	                  $problem->{showMeAnotherCount}=$showMeAnother{Count};
                      $problem->{problem_seed} = $oldProblemSeed;
                      $db->putUserProblem($problem);

                      # put the new problem seed back in
                      $problem->{problem_seed} = $newProblemSeed;

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

    }

    # if showMeAnother is active, then disable all other options
    if ( ( $showMeAnother{active} or $showMeAnother{CheckAnswers} or $showMeAnother{Preview}) and $can{showMeAnother} ) {
	        $can{showOldAnswers} = 0;
	        $can{recordAnswers}  = 0;
	        $can{checkAnswers}   = 0; # turned on if showMeAnother conditions met below
	        $can{getSubmitButton}= 0;

            # only show solution if showMeAnother has been clicked (or refreshed)
            # less than the maximum amount allowed specified in Course Configuration, 
            # and also make sure that showMeAnother is possible
            if(($showMeAnother{Count}<=($showMeAnother{MaxReps}) or ($showMeAnother{MaxReps}==-1))
                and $showMeAnother{IsPossible} )
            {
	          $can{showCorrectAnswers} = ($showMeAnother{options}->{showCorrect} and $showMeAnother{options}->{checkAnswers});
	          $can{showHints}          = $showMeAnother{options}->{showHints};
	          $can{showSolutions}      = $showMeAnother{options}->{showSolutions};
	          $must{showSolutions}     = $showMeAnother{options}->{showSolutions};
	          $can{checkAnswers}       = $showMeAnother{options}->{checkAnswers};
		  # rig the nubmer of attempts to show hints if showing hitns
		  if ($can{showHints}) {
		      $problem->num_incorrect(1000);
		  }
            }
      }
	
	# final values for options
	my %will;
	foreach (keys %must) {
		$will{$_} = $can{$_} && ($want{$_} || $must{$_});
		#warn "final values for options $_ is can $can{$_}, want $want{$_}, must $must{$_}, will $will{$_}";
	}
	
	##### sticky answers #####
	
	if (not ($submitAnswers or $previewAnswers or $checkAnswers or $showMeAnother{active}) and $will{showOldAnswers}) {
		# do this only if new answers are NOT being submitted
		my %oldAnswers = decodeAnswers($problem->last_answer);
		$formFields->{$_} = $oldAnswers{$_} foreach keys %oldAnswers;
	}
	
	##### translation #####

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
			showHints       => $will{showHints},
			showSolutions   => $will{showSolutions},
			refreshMath2img => $will{showHints} || $will{showSolutions},
			processAnswers  => 1,
			permissionLevel => $db->getPermissionLevel($userName)->permission,
			effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
		},
	);

	debug("end pg processing");
	
	##### update and fix hint/solution options after PG processing #####
	
	$can{showHints}     &&= $pg->{flags}->{hintExists}  
	                    &&= $pg->{flags}->{showHintLimit}<=$pg->{state}->{num_of_incorrect_ans};
	$can{showSolutions} &&= $pg->{flags}->{solutionExists};
	
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

	##### store fields #####
	
	$self->{want} = \%want;
	$self->{must} = \%must;
	$self->{can}  = \%can;
	$self->{will} = \%will;
	$self->{showMeAnother} = \%showMeAnother;
	$self->{pg} = $pg;
}


sub head {
	my ($self) = @_;
	my $ce = $self->r->ce;
	my $webwork_htdocs_url = $ce->{webwork_htdocs_url};
	return "" if ( $self->{invalidSet} );

	# Keys dont really work well anymore.  So I'm removing this for now GG
#	print qq{
#		<link rel="stylesheet" href="$webwork_htdocs_url/js/legacy/vendor/keys/keys.css">
#		<script src="$webwork_htdocs_url/js/legacy/vendor/keys/keys.js"></script>
#	};

	return $self->{pg}->{head_text} if $self->{pg}->{head_text};

}

sub post_header_text {
	my ($self) = @_;
	return "" if ( $self->{invalidSet} );
    return $self->{pg}->{post_header_text} if $self->{pg}->{post_header_text};
}

sub nav {
	my ($self, $args) = @_;
	my $r = $self->r;
	my %can = %{ $self->{can} };

	# if showMeAnother or check answers from showMeAnother
	# is active, then don't show the navigation bar
	return "";
}
	
# now altered to outsource most output operations to the template, main functions now are simply error checking and answer processing - ghe3
sub body {
	my $self = shift;
	my $set = $self->{set};
	my $problem = $self->{problem};
	my $pg = $self->{pg};

	print CGI::p("Entering Problem::body subroutine.  
	         This indicates an old style system.template file -- consider upgrading. ",
	         caller(1), );

	my $valid = WeBWorK::ContentGenerator::ProblemUtil::ProblemUtil::check_invalid($self);
	unless($valid eq "valid"){
		return $valid;
	}
		
	
	##### answer processing #####
	debug("begin answer processing");
	# if answers were submitted:
	#my $scoreRecordedMessage = WeBWorK::ContentGenerator::ProblemUtil::ProblemUtil::process_and_log_answer($self);
	debug("end answer processing");
	# output for templates that only use body instead of calling the body parts individually
	$self ->output_JS;
	$self ->output_tag_info;
	$self ->output_custom_edit_message;
	$self ->output_summary;
	$self ->output_hidden_info;
	$self ->output_form_start();
	$self ->output_problem_body;
	$self ->output_message;
	$self ->output_editorLink;
	$self ->output_checkboxes;
	$self ->output_submit_buttons;
	$self ->output_score_summary;
	$self ->output_comments;
	$self ->output_misc;
	print "</form>";
	# debugging stuff
	if (0) {
		print
			CGI::hr(),
			CGI::h2("debugging information"),
			CGI::h3("form fields"),
			ref2string($self->{formFields}),
			CGI::h3("user object"),
			ref2string($self->{user}),
			CGI::h3("set object"),
			ref2string($set),
			CGI::h3("problem object"),
			ref2string($problem),
			CGI::h3("PG object"),
			ref2string($pg, {'WeBWorK::PG::Translator' => 1});
	}
	debug("leaving body of Problem.pm");
	return "";
}

# prints out the body of the current problem

sub output_problem_body{
	my $self = shift;
	my $pg = $self->{pg};
	my %will = %{ $self->{will} };
	my %showMeAnother = %{ $self->{showMeAnother} };

	print "\n";
	print CGI::div($pg->{body_text})
		#ignore body if SMA was pushed and no new problem will be shown; otherwise original problem will be shown
		unless ($showMeAnother{active} and (!$will{showMeAnother} or !$showMeAnother{IsPossible}));
	return "";
}

# output_checkboxes subroutine

# prints out the checkbox input elements that are available for the current problem

sub output_checkboxes{
	my $self = shift;
	my $r = $self->r;
	my %can = %{ $self->{can} };
	my %will = %{ $self->{will} };
	my $ce = $r->ce;
	my %showMeAnother = %{ $self->{showMeAnother} };
    my $showHintCheckbox      = $ce->{pg}->{options}->{show_hint_checkbox};
    my $showSolutionCheckbox  = $ce->{pg}->{options}->{show_solution_checkbox};
    my $useKnowlsForHints     = $ce->{pg}->{options}->{use_knowls_for_hints};
    my $useKnowlsForSolutions = $ce->{pg}->{options}->{use_knowls_for_solutions};
    #  warn "showHintCheckbox $showHintCheckbox  showSolutionCheckbox $showSolutionCheckbox";
    #skip check boxes if SMA was pushed and no new problem will be shown
    if (!$showMeAnother{active} or ($will{showMeAnother} and $showMeAnother{IsPossible})) 
    {

	if ($can{showCorrectAnswers}) {
		print WeBWorK::CGI_labeled_input(
			-type	 => "checkbox",
			-id		 => "showCorrectAnswers_id",
			-label_text => $r->maketext("Show correct answer column"),
			-input_attr => $will{showCorrectAnswers} ?
			{
				-name    => "showCorrectAnswers",
				-checked => "checked",
				-value   => 1,
			}
			:
			{
				-name    => "showCorrectAnswers",
				-value   => 1,
			}
		),"&nbsp;";
	}
	#  warn "can showHints $can{showHints} can show solutions $can{showSolutions}";
	if ($can{showHints} ) {
	  # warn "can showHints is ", $can{showHints};
	  if ($showHintCheckbox or not $useKnowlsForHints) { # always allow checkbox to display if knowls are not used.
		print WeBWorK::CGI_labeled_input(
				-type	 => "checkbox",
				-id		 => "showHints_id",
				-label_text => $r->maketext("Show Hints"),
				-input_attr => $will{showHints} ?
				{
					-name    => "showHints",
					-checked => "checked",
					-value   => 1,
				}
				:
				{
					-name    => "showHints",
					-value   => 1,
				}
		),"&nbsp;";
	  } else {
	  	print CGI::hidden({name => "showHints", id=>"showHints_id", value => 1})
	  
	  }
	}
	
	if ($can{showSolutions} ) {
	  if (  $showSolutionCheckbox or not $useKnowlsForSolutions ) { # always allow checkbox to display if knowls are not used.
		print WeBWorK::CGI_labeled_input(
			-type	 => "checkbox",
			-id		 => "showSolutions_id",
			-label_text => $r->maketext("Show Solutions"),
			-input_attr => $will{showSolutions} ?
			{
				-name    => "showSolutions",
				-checked => "checked",
				-value   => 1,
			}
			:
			{
				-name    => "showSolutions",
				-value   => 1,
			}
		),"&nbsp;";
	  } else {
	    print CGI::hidden({id=>"showSolutions_id", name => "showSolutions", value=>1})
	  }
	}
	
	if ($can{showCorrectAnswers} or $can{showHints} or $can{showSolutions}) {
		print CGI::br();
	}
       
    }
	return "";
}

# output_submit_buttons

# prints out the submit button input elements that are available for the current problem

sub output_submit_buttons{
	my $self = shift;
	my $r = $self->r;
	my $ce = $self->r->ce;
	my %can = %{ $self->{can} };
	my %will = %{ $self->{will} };
	my %showMeAnother = %{ $self->{showMeAnother} };
	
	my $user = $r->param('user');
	my $effectiveUser = $r->param('effectiveUser');

	# skip buttons if SMA button has been pushed but there is no new problem shown

    if ($will{showMeAnother} and $showMeAnother{IsPossible}){
        print WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"previewAnswers_id", -input_attr=>{-onclick=>"this.form.target='_self'",-name=>"previewAnswers", -value=>$r->maketext("Preview My Answers")});
        if ($can{checkAnswers}) {
        	print WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"checkAnswers_id", -input_attr=>{-onclick=>"this.form.target='_self'",-name=>"checkAnswers", -value=>$r->maketext("Check Answers")});
        }
        if ($can{getSubmitButton}) {
        	if ($user ne $effectiveUser) {
        		# if acting as a student, make it clear that answer submissions will
        		# apply to the student's records, not the professor's.
        		print WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"submitAnswers_id", -input_attr=>{-name=>$r->maketext("submitAnswers"), -value=>$r->maketext("Submit Answers for [_1]", $effectiveUser)});
        	} else {
        		#print CGI::submit(-name=>"submitAnswers", -label=>"Submit Answers", -onclick=>"alert('submit button clicked')");
        		print WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"submitAnswers_id", -input_attr=>{-name=>"submitAnswers", -value=>$r->maketext("Submit Answers"), -onclick=>"this.form.target='_self'"});
        		# FIXME  for unknown reasons the -onclick label seems to have to be there in order to allow the forms onsubmit to trigger
        		# WTF???
        	}
        }
    }
	return "";
}

# output_score_summary subroutine

# prints out a summary of the student's current progress and status on the current problem

sub output_score_summary{
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $problem = $self->{problem};
	my $set = $self->{set};
	my $pg = $self->{pg};
	my $scoreRecordedMessage = WeBWorK::ContentGenerator::ProblemUtil::ProblemUtil::process_and_log_answer($self) || "";
	my $submitAnswers = $self->{submitAnswers};
	my %will = %{ $self->{will} };
	my %showMeAnother = %{ $self->{showMeAnother} };

    # skip score summary if SMA has been pushed but there is no new problem to show
    if (!$showMeAnother{active} or ($will{showMeAnother} and $showMeAnother{IsPossible}))
    { 
	# score summary
	warn "num_correct =", $problem->num_correct,"num_incorrect=",$problem->num_incorrect 
	        unless defined($problem->num_correct) and defined($problem->num_incorrect) ;
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	#my $attemptsNoun = $attempts != 1 ? $r->maketext("times") : $r->maketext("time");
	my $problem_status    = $problem->status || 0;
	my $lastScore = wwRound(0, $problem_status * 100).'%'; # Round to whole number
	my $attemptsLeft = $problem->max_attempts - $attempts;
	
	my $setClosed = 0;
	my $setClosedMessage;
	if (before($set->open_date) or after($set->due_date)) {
		$setClosed = 1;
		if (before($set->open_date)) {
			$setClosedMessage = $r->maketext("This homework set is not yet open.");
		} elsif (after($set->due_date)) {
			$setClosedMessage = $r->maketext("This homework set is closed.");
		}
	}
	#if (before($set->open_date) or after($set->due_date)) {
	#	$setClosed = 1;
	#	$setClosedMessage = "This homework set is closed.";
	#	if ($authz->hasPermissions($user, "view_answers")) {
	#		$setClosedMessage .= " However, since you are a privileged user, additional attempts will be recorded.";
	#	} else {
	#		$setClosedMessage .= " Additional attempts will not be recorded.";
	#	}
	#}

	unless (defined( $pg->{state}->{state_summary_msg}) and $pg->{state}->{state_summary_msg}=~/\S/) {
		my $notCountedMessage = ($problem->value) ? "" : $r->maketext("(This problem will not count towards your grade.)");
		print CGI::p(join("",
			$submitAnswers ? $scoreRecordedMessage . CGI::br() : "",
			$r->maketext("You have attempted this problem [quant,_1,time,times].",$attempts), CGI::br(),
			$submitAnswers ? $r->maketext("You received a score of [_1] for this attempt.",wwRound(0, $pg->{result}->{score} * 100).'%') . CGI::br():'',
			$problem->attempted
				? $r->maketext("Your overall recorded score is [_1].  [_2]",$lastScore,$notCountedMessage) . CGI::br()
				: "",
			$setClosed ? $setClosedMessage : $r->maketext("You have [negquant,_1,unlimited attempts,attempt,attempts] remaining.",$attemptsLeft) 
		));
	}else {
		print CGI::p($pg->{state}->{state_summary_msg});
	}

    } 
	return "";
}



# output_summary subroutine

# prints out the summary of the questions that the student has answered 
# for the current problem, along with available information about correctness

sub output_summary{
	
	my $self = shift;
	
	my $editMode = $self->{editMode};
	my $problem = $self->{problem};
	my $pg = $self->{pg};
	my $submitAnswers = $self->{submitAnswers};
	my %will = %{ $self->{will} };
	my %can = %{ $self->{can} };
	my %showMeAnother = %{ $self->{showMeAnother} };
	my $checkAnswers = $self->{checkAnswers};
	my $previewAnswers = $self->{previewAnswers};
	my $showPartialCorrectAnswers = $self->{pg}{flags}{showPartialCorrectAnswers};

	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;

	my $authz = $r->authz;
	my $user = $r->param('user');
	
    # if $showMeAnother{Count} is somehow not an integer, make it one
    $showMeAnother{Count} = 0 unless ($showMeAnother{Count} =~ /^[+-]?\d+$/);
	
        # attempt summary
	#FIXME -- the following is a kludge:  if showPartialCorrectAnswers is negative don't show anything.
	# until after the due date
	# do I need to check $will{showCorrectAnswers} to make preflight work??

	if (defined($pg->{flags}->{showPartialCorrectAnswers}) and ($pg->{flags}->{showPartialCorrectAnswers} >= 0 and $submitAnswers) ) {

	    # print this if user submitted answers OR requested correct answers	    
	    my $results = $self->attemptResults($pg, 1,
						$will{showCorrectAnswers},
			$pg->{flags}->{showPartialCorrectAnswers}, 1, 1);	    
	    print $results;
	    
	} elsif ($will{checkAnswers}) {
	    if ($showMeAnother{CheckAnswers} and $can{showMeAnother}){
		# if the student is checking answers to a new problem, give them a reminder that they are doing so
		print CGI::div({class=>'showMeAnotherBox'},$r->maketext("You are currently checking answers to a different version of your problem - these 
                                                                     will not be recorded, and you should remember to return to your original 
                                                                     problem once you are done here.")),CGI::br();
	    }
	    # print this if user previewed answers
	    print CGI::div({class=>'ResultsWithError'},$r->maketext("ANSWERS ONLY CHECKED -- ANSWERS NOT RECORDED")), CGI::br();
	    print $self->attemptResults($pg, 1, $will{showCorrectAnswers}, 1, 1, 1);
	    # show attempt answers
	    # show correct answers if asked
	    # show attempt results (correctness)
	    # show attempt previews
	} elsif ($previewAnswers) {
        # if the student is previewing answers to a new problem, give them a reminder that they are doing so
        if($showMeAnother{Preview} and $can{showMeAnother}){
          print CGI::div({class=>'showMeAnotherBox'},$r->maketext("You are currently previewing answers to a different version of your problem - these 
                                                                 will not be recorded, and you should remember to return to your original 
                                                                 problem once you are done here.")),CGI::br();
        }
		# print this if user previewed answers
		print CGI::div({class=>'ResultsWithError'},$r->maketext("PREVIEW ONLY -- ANSWERS NOT RECORDED")),CGI::br(),$self->attemptResults($pg, 1, 0, 0, 0, 1);
			# show attempt answers
			# don't show correct answers
			# don't show attempt results (correctness)
			# show attempt previews
    } elsif ( (($showMeAnother{active} and $showMeAnother{IsPossible}) or $showMeAnother{DisplayChange}) 
                    and $can{showMeAnother}){
        # the feedback varies a little bit if Check Answers is available or not
        my $checkAnswersAvailable = ($showMeAnother{options}->{checkAnswers}) ?
                       "You may check your answers to this problem without affecting the maximum number of tries to your original problem." :"";
        my $solutionShown;
		# if showMeAnother has been clicked and a new version has been found,
        # give some details of what the student is seeing
        if($showMeAnother{Count}<=$showMeAnother{MaxReps} or ($showMeAnother{MaxReps}==-1)){
            # check to see if a solution exists for this problem, and vary the feedback accordingly
            if($pg->{flags}->{solutionExists}){
                $solutionShown = ($showMeAnother{options}->{showSolutions}) ? ", complete with solution" : "";
            } else {
                my $viewCorrect = (($showMeAnother{options}->{showCorrect}) and ($showMeAnother{options}->{checkAnswers})) ?
                      ", but you can still view the correct answer":"";
                $solutionShown = ($showMeAnother{options}->{showSolutions}) ?
                      ". There is no walk-through solution available for this problem$viewCorrect" : "";
            }
         }
		 print CGI::div({class=>'showMeAnotherBox'},$r->maketext("Here is a new version of your problem[_1]. [_2] ",$solutionShown,$checkAnswersAvailable)),CGI::br();
		 print CGI::div({class=>'ResultsAlert'},$r->maketext("Remember to return to your original problem when you're finished here!")),CGI::br();
     } elsif($showMeAnother{active} and $showMeAnother{IsPossible} and !$can{showMeAnother}) {
        if($showMeAnother{Count}>=$showMeAnother{MaxReps}){
            my $solutionShown = ($showMeAnother{options}->{showSolutions} and $pg->{flags}->{solutionExists}) ? "The solution has been removed." : "";
		    print CGI::div({class=>'ResultsAlert'},$r->maketext("You are only allowed to click on Show Me Another [quant,_1,time,times] per problem.
                                                                         [_2] Close this tab, and return to the original problem.",$showMeAnother{MaxReps},$solutionShown  )),CGI::br();
        } elsif ($showMeAnother{Count}<$showMeAnother{TriesNeeded}) {
		    print CGI::div({class=>'ResultsAlert'},$r->maketext("You must attempt this problem [quant,_1,time,times] before Show Me Another is available.",$showMeAnother{TriesNeeded})),CGI::br();
        }
     } elsif ($showMeAnother{active} and $can{showMeAnother} and !$showMeAnother{IsPossible}){
		# print this if showMeAnother has been clicked, but it is not possible to
        # find a new version of the problem
		print CGI::div({class=>'ResultsAlert'},$r->maketext("WeBWorK was unable to generate a different version of this problem;
                       close this tab, and return to the original problem.")),CGI::br();
    }


    if (!$previewAnswers) {    # only color answers if not previewing
        if ($checkAnswers or $showPartialCorrectAnswers) { # color answers when partialCorrectAnswers is set
                                                           # or when checkAnswers is submitted
	    print CGI::start_script({type=>"text/javascript"}),
	            "addOnLoadEvent(function () {color_inputs([\n  ",
		      join(",\n  ",map {"'$_'"} @{$self->{correct_ids}||[]}),
	            "\n],[\n  ",
		      join(",\n  ",map {"'$_'"} @{$self->{incorrect_ids}||[]}),
	            "]\n)});",
	          CGI::end_script();
	}
    }
    return "";
}


# output_hidden_info subroutine

# outputs the hidden fields required for the form

sub output_hidden_info {
    my $self = shift;
    my %showMeAnother = %{ $self->{showMeAnother} };
    my $problemSeed = $self->{problem}->{problem_seed};

    # hidden field for clicking Preview Answers and Check Answers from a Show Me Another screen
    # it needs to send the seed from showMeAnother back to the screen
    if($showMeAnother{active} or $showMeAnother{CheckAnswers} or $showMeAnother{Preview}){
	print CGI::hidden({name => "showMeAnotherCheckAnswers", id=>"showMeAnotherCheckAnswers_id", value => 1});
        # output the problem seed from ShowMeAnother so that it can be used in Check Answers
        print( CGI::hidden({name => "problemSeed", value  =>  $problemSeed}));
    }
    return "";
}


1;
