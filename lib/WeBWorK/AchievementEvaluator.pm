################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/PG.pm,v 1.76 2009/07/18 02:52:51 gage Exp $
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

package WeBWorK::AchievementEvaluator;
use base qw(WeBWorK);

=head1 NAME

  WeBWorK::AchievementEvaluator  -  Runs achievement evaluators for problems.

=cut

use strict;
use warnings;
use WeBWorK::CGI;
use WeBWorK::Utils qw(before after readFile sortAchievements nfreeze_base64 thaw_base64);
use WeBWorK::Utils::Tags;
use DateTime;

use WWSafe;

sub checkForAchievements {

    our $problem = shift;
    my $pg = shift;
    my $r = shift;
    my %options = @_;
    my $db = $r->db;
    my $ce = $r->ce;

    my $course_display_tz = $ce->{siteDefaults}{timezone};
    # the following line from Utils.pm
    $course_display_tz ||= "local";    # do our best to provide default vaules

    # Date and time for course timezone (may differ from the server timezone)
    # Saved into separate array
    # https://metacpan.org/pod/DateTime
    my $dtCourseTime = DateTime->from_epoch( epoch => time(), time_zone  => $course_display_tz);

    #set up variables and get achievements
    my $cheevoMessage = '';
    my $user_id = $problem->user_id;
    my $set_id = $problem->set_id;
    # exit early if the set is to be ignored by achievements
    foreach my $excludedSet (@{ $ce->{achievementExcludeSet} }) {
	return '' if $set_id eq $excludedSet;
    }
    our $set = $db->getMergedSet($user_id,$problem->set_id);
    my @allAchievementIDs = $db->listAchievements; 
    my @achievements = $db->getAchievements(@allAchievementIDs);
    @achievements = sortAchievements(@achievements);
    my $globalUserAchievement = $db->getGlobalUserAchievement($user_id);

    my $isGatewaySet = ( $set->assignment_type =~ /gateway/ ) ? 1 : 0;
    my $isJitarSet = ( $set->assignment_type eq 'jitar' ) ? 1 : 0;

    #### Temporary Transition Code ####
    # If an achievement doesn't have either a number or an assignment_type
    # then its probably an old achievement in which case we should
    # update its assignment_type to include 'default'.
    # This whole block of code can be removed once people have had time
    # to transition over.  (I.E. around 2017)
    
    foreach my $achievement (@achievements) {
      unless ($achievement->assignment_type || $achievement->number) {
	$achievement->assignment_type('default');
	$db->putAchievement($achievement);
      }
    }
    
    ### End Transition Code.  ###
    
    
    # If its a gateway set get the current version
    if ($isGatewaySet) {
	$set = $db->getSetVersion($user_id, $set_id, $options{setVersion});
    } 
    
    # If no global data then initialize
    if (not $globalUserAchievement) {
	$globalUserAchievement = $db->newGlobalUserAchievement();
	$globalUserAchievement->user_id($user_id);
	$globalUserAchievement->achievement_points(0);
	$db->addGlobalUserAchievement($globalUserAchievement);
    }

    #update the problem with stuff from the pg. 
    # this is kind of a hack.  The achievement checking happens *before* the system has
    # updated $problem with the new results from $pg.  So we cheat and update the 
    # important bits here.  The only thing that gets left behind is last_answer, which is
    # still the previous last answer. 
    
    # $pg->{result} reflects the current submission, $pg->{state} holds the best result 
    # close the unlimited achievement points loophole by only using the current result!
    $problem->status($pg->{result}->{score});
    $problem->sub_status($pg->{state}->{sub_recorded_score});
    $problem->attempted(1);
    $problem->num_correct($pg->{state}->{num_of_correct_ans});
    $problem->num_incorrect($pg->{state}->{num_of_incorrect_ans});
    
    #These need to be "our" so that they can share to the safe container
    our $counter;
    our $maxCounter;
    our $achievementPoints = $globalUserAchievement->achievement_points;
    our $nextLevelPoints = $globalUserAchievement->next_level_points;
    our $localData = {};
    our $globalData = {};
    our $tags;
    our @setProblems = ();
    our @courseDateTime = ($dtCourseTime->sec,$dtCourseTime->min,$dtCourseTime->hour,$dtCourseTime->day,$dtCourseTime->month,$dtCourseTime->year,$dtCourseTime->day_of_week);

    my $compartment = new WWSafe;

    #initialize things that are ""
    if (not $achievementPoints) {
		$achievementPoints = 0;
		$globalUserAchievement->achievement_points(0);
    }

    #Methods alowed in the safe container
    $compartment->permit(qw(time localtime));

    #Thaw_Base64 globalData hash
    if ($globalUserAchievement->frozen_hash) {

		$globalData = thaw_base64($globalUserAchievement->frozen_hash);
    }

    #Update a couple of "standard" variables in globalData hash.
    my $allcorrect = 0;

    if ($isGatewaySet) {
	@setProblems = $db->getAllMergedProblemVersions($user_id, $set_id, $options{setVersion});
    } else {
	@setProblems = $db->getAllUserProblems( $user_id, $set_id);
    }

    # for gateway sets we have to do check all of the problems to see
    # if we need to reward points since we submit all at once
    # otherwise we only do the main problem. 
    my @problemsToCheck = ($problem);

    if ($isGatewaySet) {
	@problemsToCheck = @setProblems;
    }

    foreach my $thisProblem (@problemsToCheck) {

	if ($thisProblem->status == 1 && $thisProblem->num_correct == 1) {
	    $globalUserAchievement->achievement_points(
		$globalUserAchievement->achievement_points + 
		$ce->{achievementPointsPerProblem});
	    #this variable is shared and should be considered iffy
	    $achievementPoints += $ce->{achievementPointsPerProblem};
	    $globalData->{'completeProblems'} += 1;
	    $allcorrect = 1;
	}
    }

    #check and see of all problems are correct.  (also update the current
    # problem in setProblems, since the database might be out of date)
    my $index = 0;
    foreach my $thisProblem (@setProblems) {
	if ($thisProblem->problem_id eq $problem->problem_id) {
	    $setProblems[$index] = $problem;
	} elsif ($thisProblem->status != 1) {
	    $allcorrect = 0;
	}
	$index++;
    }
    
    if ($allcorrect) {
	$globalData->{'completeSets'}++;
    }

    # get the problem tags if its not a gatway
    # if it is a gateway get rid of $problem since it doensn't make sense
    if ($isGatewaySet) {
	$problem = undef;
    } else {
	my $templateDir = $ce->{courseDirs}->{templates};
	$tags = WeBWorK::Utils::Tags->new($templateDir.'/'.$problem->source_file());
    }

    #These variables are shared with the safe compartment.  The achievement evaulators
    # have access too 
    # $problem - the problem data;
    # @setProblems - the problem data for everything from this set;
    # $localData - the hash that is used only for this achievement
    # $globalData - the hash that is shared between all achievements
    # $maxCounter - the "max counter" associated with this achievement (if there is one);
    # $counter - the "counter" associated with this achievement (used in level bars)
    # $nextLevelPoints - only should be used by 'level' achievements
    # $set - the set data
    # $achievementPoints - the number of achievmeent points
    # $tags -this is the tag data associated to the problem from the problem library
    # @courseDateTime - array of time information in course timezone (sec,min,hour,day,month,year,day_of_week)

    $compartment->share(qw( $problem @setProblems $localData $maxCounter 
             $globalData $counter $nextLevelPoints $set $achievementPoints $tags @courseDateTime));

    #load any preamble code
    # this line causes the whole file to be read into one string
    local $/;
    my $preamble = '';
    my $source;
    if (-e 
	"$ce->{courseDirs}->{achievements}/$ce->{achievementPreambleFile}") {
	open(PREAMB, '<', "$ce->{courseDirs}->{achievements}/$ce->{achievementPreambleFile}");
	$preamble = <PREAMB>;
	close(PREAMB);
    }
    #loop through the various achievements, see if they have been obtained, 
    foreach my $achievement (@achievements) {
	#skip achievements not assigned, not enabled, and that are already earned, or if it doesn't match the set type
	next unless $achievement->enabled;
	my $achievement_id = $achievement->achievement_id;
	next unless ($db->existsUserAchievement($user_id,$achievement_id));
	my $userAchievement = $db->getUserAchievement($user_id,$achievement_id);
	next if ($userAchievement->earned);
	my $setType = $set->assignment_type;
	next unless $achievement->assignment_type =~ /$setType/;

	#thaw_base64 localData hash
	if ($userAchievement->frozen_hash) {
	    $localData = thaw_base64($userAchievement->frozen_hash);
	}

	#recover counter information (for progress bar achievements)
	$counter = $userAchievement->counter;
	$maxCounter = $achievement->max_counter;

	#check the achievement using Safe
	my $sourceFilePath = $ce->{courseDirs}->{achievements}.'/'.$achievement->test;
	if (-e $sourceFilePath) {
	    open(SOURCE,'<',$sourceFilePath);
	    $source = <SOURCE>;
	    close(SOURCE);
	} else {
	    warn('Couldnt find achievement evaluator $sourceFilePath');
	    next;
	};

	my $earned = $compartment->reval($preamble."\n".$source);
	warn "There were errors in achievement $achievement_id\n".$@ if $@;

	#if we have a new achievement then update achievement points
	if ($earned) {
	    $userAchievement->earned(1);
	
	    if ($achievement->category eq 'level') {
			$globalUserAchievement->level_achievement_id($achievement_id);
			$globalUserAchievement->next_level_points($nextLevelPoints);
	    }

	    #build the cheevo message. New level messages are slightly different
	    my $imgSrc = $ce->{server_root_url};
	    if ($achievement->{icon}) {
			$imgSrc .= $ce->{courseURLs}->{achievements}."/".$achievement->{icon};
	    } else {           
			$imgSrc .= $ce->{webworkURLs}->{htdocs}."/images/defaulticon.png";
	    }

	    $cheevoMessage .=  CGI::start_div({id=>"test", class=>'cheevopopupouter modal-body'});
	    $cheevoMessage .=  CGI::img({src=>$imgSrc, alt=>'Achievement Icon'});
	    $cheevoMessage .= CGI::start_div({class=>'cheevopopuptext'});  
	    if ($achievement->category eq 'level') {
		
			$cheevoMessage = $cheevoMessage . CGI::h2("$achievement->{name}");
			#print out description as part of message if we are using items
			
			$cheevoMessage .= CGI::div($ce->{achievementItemsEnabled} ?  $achievement->{description} : $r->maketext("Congratulations, you earned a new level!"));
			$cheevoMessage .= CGI::end_div();

	    } else {
		
			$cheevoMessage .=  CGI::h2("$achievement->{name}");
			$cheevoMessage .=  CGI::div("<i>$achievement->{points} Points</i>: $achievement->{description}");
			$cheevoMessage .= CGI::end_div();
	    }
	    
	    # this feature doesn't really work anymore because
	    # of a change in facebooks api
	    #if facebook integration is enables then create a facebook popup
	    if ($ce->{allowFacebooking}&& $globalUserAchievement->facebooker) {
			$cheevoMessage .= CGI::div({id=>'fb-root'},'');
			$cheevoMessage .= CGI::script({src=>'http://connect.facebook.net/en_US/all.js'},'');
			$cheevoMessage .= CGI::start_script();
			
			$cheevoMessage .= "FB.init({appId:'".$ce->{facebookAppId}."', cookie:true,status:true, xfbml:true });\n";
	
			my $facebookmessage;
			if ($achievement->category eq 'level') {
				$facebookmessage = sprintf("I leveled up and am now a %s",$achievement->{name});
			} else {
				$facebookmessage = sprintf("%s: %s",$achievement->{name},$achievement->{description});
			}
		
			$cheevoMessage .= "FB.ui({ method: 'feed', display: 'popup', picture: '$imgSrc', description: '$facebookmessage'});\n";
			$cheevoMessage .= CGI::end_script();

	    }
	        
	    $cheevoMessage .= CGI::end_div();
	    
	        
	    my $points = $achievement->points;
	    #just in case points is an ininitialzied variable
	    $points = 0 unless $points;

	    $globalUserAchievement->achievement_points(
		$globalUserAchievement->achievement_points + $points);
	    #this variable is shared and should be considered iffy
	    $achievementPoints += $points;
	}    
	
	#update counter, nfreeze_base64 localData and store
	$userAchievement->counter($counter);
	$userAchievement->frozen_hash(nfreeze_base64($localData));	
	$db->putUserAchievement($userAchievement);
	
    }  #end for loop
    
    #nfreeze_base64 globalData and store
    $globalUserAchievement->frozen_hash(nfreeze_base64($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    if ($cheevoMessage) {
	$cheevoMessage = CGI::div({id=>"achievementModal", class=>"modal hide fade"},$cheevoMessage);
    }

    return $cheevoMessage;
}

#Perl magic
1;
