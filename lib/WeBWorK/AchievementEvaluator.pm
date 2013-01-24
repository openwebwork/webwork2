################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
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

    WeBWorK::Cheevos - Cheevo code

=cut

use strict;
use warnings;
use WeBWorK::CGI;
use WeBWorK::Utils qw(before after readFile sortAchievements);

use Safe;
use Storable qw(nfreeze thaw);

sub checkForAchievements {

    our $problem = shift;
    my $pg = shift;
    my $db = shift;
    my $ce = shift;

    #set up variables and get achievements
    my $cheevoMessage = '';
    my $user_id = $problem->user_id;
    my $set_id = $problem->set_id;
    our $set = $db->getGlobalSet($problem->set_id);
    my @allAchievementIDs = $db->listAchievements; 
    my @achievements = $db->getAchievements(@allAchievementIDs);
    @achievements = sortAchievements(@achievements);
    my $globalUserAchievement = $db->getGlobalUserAchievement($user_id);

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
    # 
    $problem->status($pg->{state}->{recorded_score});
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

    my $compartment = new Safe;

    #initialize things that are ""
    if (not $achievementPoints) {
		$achievementPoints = 0;
		$globalUserAchievement->achievement_points(0);
    }

    #Methods alowed in the safe container
    $compartment->permit(qw(time localtime));

    #Thaw globalData hash
    if ($globalUserAchievement->frozen_hash) {       
		$globalData = thaw($globalUserAchievement->frozen_hash);
    }

    #Update a couple of "standard" variables in globalData hash.
    my $allcorrect = 0;
    if ($problem->status == 1 && $problem->num_correct == 1) {
		$globalUserAchievement->achievement_points(
	    $globalUserAchievement->achievement_points + 
	    $ce->{achievementPointsPerProblem});
	#this variable is shared and should be considered iffy
		$achievementPoints += $ce->{achievementPointsPerProblem};
		$globalData->{'completeProblems'} += 1;
		$allcorrect = 1;
    }

    our @setProblems = $db->getAllUserProblems( $user_id, $problem->set_id);
    
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

    $compartment->share(qw($problem @setProblems $localData $maxCounter 
             $globalData $counter $nextLevelPoints $set $achievementPoints));

    #loop through the various achievements, see if they have been obtained, 
    foreach my $achievement (@achievements) {
	#skip achievements not assigned, not enabled, and that are already earned
	next unless $achievement->enabled;
	my $achievement_id = $achievement->achievement_id;
	next unless ($db->existsUserAchievement($user_id,$achievement_id));
	my $userAchievement = $db->getUserAchievement($user_id,$achievement_id);
	next if ($userAchievement->earned);
	
	#thaw localData hash
	if ($userAchievement->frozen_hash) {
	    $localData = thaw($userAchievement->frozen_hash);
	}

	#recover counter information (for progress bar achievements)
	$counter = $userAchievement->counter;
	$maxCounter = $achievement->max_counter;

	#check the achievement using Safe
	my $sourceFilePath = $ce->{courseDirs}->{achievements}.'/'.$achievement->test;
	my $earned = $compartment->rdo($sourceFilePath);
	warn "There were errors in achievement $achievement_id\n".$@ if $@;

	#if we have a new achievement then update achievement points
	if ($earned) {
	    $userAchievement->earned(1);
	
	    if ($achievement->category eq 'level') {
			$globalUserAchievement->level_achievement_id($achievement_id);
			$globalUserAchievement->next_level_points($nextLevelPoints);
	    }

	    #build the cheevo message. New level messages are slightly different
	    my $imgSrc;
	    if ($achievement->{icon}) {

			$imgSrc = $ce->{server_root_url}.$ce->{courseURLs}->{achievements}."/".$achievement->{icon};
	    } else {           
			$imgSrc = $ce->{server_root_url}.$ce->{webworkURLs}->{htdocs}."/images/defaulticon.png";
	    }

	    $cheevoMessage .=  CGI::start_div({class=>'cheevopopupouter'});
	    $cheevoMessage .=  CGI::img({src=>$imgSrc, alt=>'Achievement Icon'});
	    $cheevoMessage .= CGI::start_div({class=>'cheevopopuptext'});  
	    if ($achievement->category eq 'level') {
		
			$cheevoMessage = $cheevoMessage . CGI::h1("Level Up: $achievement->{name}");
			$cheevoMessage = $cheevoMessage . CGI::div("Congratulations, you earned a new level!");
			$cheevoMessage = $cheevoMessage . CGI::end_div();

	    } else {
		
			$cheevoMessage .=  CGI::h1("Mathchievment Unlocked: $achievement->{name}");
			$cheevoMessage .=  CGI::div("<i>$achievement->{points} Points</i>: $achievement->{description}");
			$cheevoMessage .= CGI::end_div();
	    }
	    
	    #if facebook integration is enables then create a facebook popup
	    if ($globalUserAchievement->facebooker) {
			$cheevoMessage .= CGI::div({id=>'fb-root'},'');
			$cheevoMessage .= CGI::script({src=>'http://connect.facebook.net/en_US/all.js'},'');
			$cheevoMessage .= CGI::start_script();
			#WCU specific appID
			$cheevoMessage .= "FB.init({appId:'193051384078348', cookie:true,status:true, xfbml:true });\n";
	
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
	
	#update counter, nfreeze localData and store
	$userAchievement->counter($counter);
	$userAchievement->frozen_hash(nfreeze($localData));	
	$db->putUserAchievement($userAchievement);
	
    }  #end for loop
    
    #nfreeze globalData and store
    $globalUserAchievement->frozen_hash(nfreeze($globalData));
    $db->putGlobalUserAchievement($globalUserAchievement);

    return $cheevoMessage;
}

#Perl magic
1;
