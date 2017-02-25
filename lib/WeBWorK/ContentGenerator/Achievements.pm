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

# This module prints out the list of achievements that a student has earned
package WeBWorK::ContentGenerator::Achievements;
use base qw(WeBWorK::ContentGenerator);
use WeBWorK::AchievementItems;

=head1 NAME

WeBWorK::ContentGenerator::Achievements - Content Generator for achievements list
This produces a list of earned achievements for each student.  

=cut

use strict;
use warnings;

use CGI;
use WeBWorK::Utils qw( sortAchievements );

sub head {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

	return "";
}

sub output_achievement_CSS {
    return "";
}

sub initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;

	# Get user Data
 	my $userName = $r->param('user');
 	my $effectiveUserName = defined($r->param('effectiveUser') ) ? $r->param('effectiveUser') : $userName;
	$self->{userName} = $userName;
	$self->{studentName} = $effectiveUserName;

	my $globalUserAchievement = $db->getGlobalUserAchievement($effectiveUserName);

	$self->{globalData} = $globalUserAchievement;

	#Checks to see if user items are enavbled and if the user has
	# achievement data

	if ($ce->{achievementItemsEnabled} && defined $globalUserAchievement) {
	    
	    my $items = WeBWorK::AchievementItems::UserItems($effectiveUserName, $db, $ce);

	    $self->{achievementItems} = $items;
	    
	    my $usedItem = $r->param('useditem');
	    
	    # if the useditem parameter is defined then the student wanted to
	    # use an item so lets do that by calling the appropriate item's 
	    # use method and printing results

	    if (defined $usedItem) {
		my $error = $$items[$usedItem]->use_item($effectiveUserName, $r);
		if ($error) {
		    $self->addmessage(CGI::div({class=>"ResultsWithError"}, $error ));
		} else {
		    splice(@$items, $usedItem, 1);
		    $self->addmessage(CGI::div({class=>"ResultsWithoutError"}, "Item Used Successfully!" ));
		}	
	    }
	}
	
}

 sub if_can {
	my ($self, $arg) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $globalUserAchievement = $self->{globalData};

	if ($arg eq 'options' && (not $ce->{allowFacebooking} || not defined($globalUserAchievement))) {
	    return 0;
 	} else {
	    return $self->SUPER::if_can($arg);
 	}
 }

sub options {
    	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $globalUserAchievement = $self->{globalData};

	return "" unless defined $globalUserAchievement;

	my $changeFacebooking = $r->param('changeFacebooking');
	
	if ($changeFacebooking) {
	    $globalUserAchievement->facebooker(!$globalUserAchievement->facebooker);
	    $db->putGlobalUserAchievement($globalUserAchievement);
	}
	
	print CGI::start_div({class=>'facebookbox'});
	print CGI::start_form(-method=>'POST', -action=>$r->uri);
	print $self->hidden_authen_fields;
	print CGI::submit('changeFacebooking', $globalUserAchievement->facebooker 
			  ? "Disable Facebook \n  Integration" : "Enable Facebook \n Integration");
	print CGI::end_form();
	print CGI::end_div();
	
	if ($globalUserAchievement->facebooker) {
	    #Print Facebook stuff (uses WCU specific appID)
	    print CGI::start_div({class=>'facebookbox'});
	    print CGI::div({id=>'fb-root'},'');
	    print CGI::script({src=>'http://connect.facebook.net/en_US/all.js'},"");
	    print CGI::script("FB.init({appId:'".$ce->{facebookAppId}."', cookie:true, status:true, xfbml:true });");
	    print "<fb:login-button perms=\"publish_stream\">";
	    print "Login to FB";
	    print "</fb:login-button>";
	    print CGI::end_div();
	}
	return "";
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $globalUserAchievements = $self->{globalData};
	my $userID = $self->{studentName};
	my $achievementURL = $ce->{courseURLs}->{achievements};


	#If they dont have a globalUserAchievements record then they dont have achievements
	if (not defined($globalUserAchievements)) {
	    print CGI::p("You don't have any Achievement data associated to you!");
	    return "";
	}

	print CGI::br();
	print CGI::start_div({class=>'cheevobigbox'});
	
	#Print their "level achievement" if there is one and print the progress bar if there is one
	my $achievement;

	if ($globalUserAchievements->level_achievement_id) {
	    
	    $achievement = $db->getAchievement($globalUserAchievements->level_achievement_id);

	}

	if ($achievement) {
	    
	    print CGI::start_div({class=>'levelbox'});
	    my $imgSrc;
	    if ($achievement->{icon}) {
		$imgSrc = $ce->{courseURLs}->{achievements}."/".$achievement->{icon};
	    } else {
		$imgSrc = $ce->{webworkURLs}->{htdocs}."/images/defaulticon.png";
	    }

	    print CGI::img({src=>$imgSrc, alt=>'Level Icon'});
	    print CGI::start_div({class=>'leveldatabox'});
	    print CGI::h1($achievement->name);
	    
	    if ($globalUserAchievements->next_level_points) {
		my $levelpercentage = int(100*$globalUserAchievements->achievement_points/$globalUserAchievements->next_level_points);
		$levelpercentage = $levelpercentage <= 100 ? $levelpercentage : 100;

		print CGI::start_div({class=>'levelouterbar', title=>$r->maketext("[_1]% Complete", $levelpercentage), 'aria-label'=>$r->maketext("[_1]% Complete",$levelpercentage)});
		print CGI::div({class=>'levelinnerbar', style=>"width:$levelpercentage\%"},'');
		print CGI::end_div();	
		print CGI::end_div();
	    }
	    print CGI::end_div();
	    print CGI::end_div();
	}


	#print any items they have if they have items
	if ($ce->{achievementItemsEnabled} && $self->{achievementItems}) {
	    my @items = @{$self->{achievementItems}};
	    my $urlpath = $r->urlpath;
	    my @setIDs = $db->listUserSets($userID);
	    my @setProblemCount;
	    
	    my @userSetIDs = map {[$userID, $_]} @setIDs;
	    my @unfilteredsets = $db->getMergedSets(@userSetIDs);
	    my @sets;
	    
	    # achievement items only make sense for regular homeworks
	    # so filter gateways out
	    foreach my $set (@unfilteredsets) {
		if ($set->assignment_type() eq 'default') {
		    push @sets, $set;
		}
	    }	    

	    # Generate array of problem counts
	    for (my $i=0; $i<=$#sets; $i++) {		
		$setProblemCount[$i] = WeBWorK::Utils::max($db->listUserProblems($userID,$sets[$i]->set_id));
	    }

	    print CGI::h2("Items");

	    if (@items) {
			    
		my $itemnumber = 0;
		foreach my $item (@items) {
		    # Print each items name and description 
		    print CGI::start_div({class=>"achievement-item"});
		    print CGI::h3($item->name());
		    print CGI::p($item->description());
		    # Print a modal popup for each item which contains the form
		    # necessary to get the data to use the item.  Print the 
		    # form in the modal body.  
		    print CGI::a({href=>"\#modal_".$item->id(), role=>"button", "data-toggle"=>"modal",class=>"btn",id=>"popup_".$item->id()},"Use Item");
		    print CGI::start_div({id=>"modal_".$item->id(),class=>"modal hide fade"});
		    print CGI::start_div({class=>'modal-header'});
		    print CGI::a({href=>"#",class=>"close","data-dismiss"=>"modal", "aria-hidden"=>"true"},CGI::span({class=>"icon icon-remove"}),CGI::div({class=>"sr-only"},$r->maketext("close")));
		    print CGI::h3($item->name()); 
		    print CGI::end_div();
		    print CGI::start_form({method=>"post", action=>$self->systemLink($urlpath,authen=>0), name=>"itemform_$itemnumber", class=>"achievementitemform"});
		    print CGI::start_div({class=>"modal-body"});
		    #Note: we provide the item with some information about
		    #the current sets to help set up the form fields. 
		    print $item->print_form(\@sets,\@setProblemCount,$r);
		    print CGI::hidden({name=>"useditem", value=>"$itemnumber"});
		    print $self->hidden_authen_fields;
		    print CGI::end_div();
		    print CGI::start_div({-class=>"modal-footer"});
		    print CGI::submit({value=>"Submit"});
		    print CGI::end_div();
		    print CGI::end_form();
		    print CGI::end_div();
		    print CGI::end_div();
		    
		    $itemnumber++;
		}
	    } else {
		print CGI::p("You don't have any items!");
	    }
	    print CGI::br();
	    print CGI::h2("Achievements");
	}

	#Get all the achievements

	my @allAchievementIDs = $db->listAchievements;
	if ( @allAchievementIDs ) { # bail if there are no achievements 
		my @achievements = $db->getAchievements(@allAchievementIDs);
	
		@achievements = sortAchievements(@achievements);
		my $previousCategory = $achievements[0]->category;
	
		#Loop through achievements and
		foreach my $achievement (@achievements) {
			#skip the level achievements and only show achievements assigned to user
			last if ($achievement->category eq 'level');
			next unless ($db->existsUserAchievement($userID,$achievement->achievement_id));
			next unless $achievement->enabled;
	
			#separate categories with whitespace
			if ($previousCategory ne $achievement->category) {
			print CGI::br();
			}
			$previousCategory = $achievement->category;
	
			my $userAchievement = $db->getUserAchievement($userID,$achievement->achievement_id);
			
			#dont show unearned secret achievements
			next if ($achievement->category eq 'secret' and not $userAchievement->earned);
	 
			#print achievement and associated progress bar (if there is one)
			print CGI::start_div({class=>sprintf("cheevoouterbox %s", $userAchievement->earned ? 'unlocked':'locked')});
	
			my $imgSrc;
			if ($achievement->{icon}) {
			$imgSrc = $ce->{courseURLs}->{achievements}."/".$achievement->{icon};
			} else {
			$imgSrc = $ce->{webworkURLs}->{htdocs}."/images/defaulticon.png";
			}
	
			print CGI::img({src=>$imgSrc, alt=>$userAchievement->earned ? 'Achievement Earned' : 'Achievement Unearned'});
			print CGI::start_div({class=>'cheevotextbox'});
			print CGI::h3($achievement->name);
			print CGI::div("<i>$achievement->{points} Points</i>: $achievement->{description}");
			
			if ($achievement->max_counter and not $userAchievement->earned) {
			my $userCounter = $userAchievement->counter;
			$userCounter = 0 unless ($userAchievement->counter);
			my $percentage = int(100*$userCounter/$achievement->max_counter);
			$percentage = $percentage <= 100 ? $percentage : 100;
			print CGI::start_div({class=>'cheevoouterbar', title=>$r->maketext("[_1]% Complete", $percentage), 'aria-label'=>$r->maketext("[_1]% Complete",$percentage)});
			print CGI::div({class=>'cheevoinnerbar', style=>sprintf("width:%i%%;", $percentage)},'');
			print CGI::end_div();	
			}	
			print CGI::end_div();
			print CGI::end_div();
			
			}	   
		} else { # no achievements 
		print CGI::p("No achievements have been assigned yet");
		}

	return "";
	
}

1;
