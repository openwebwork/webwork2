################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2021 The WeBWorK Project, https://github.com/openwebwork
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
use WeBWorK::Utils qw( sortAchievements thaw_base64 );

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

	#Checks to see if user items are enabled and if the user has
	# achievement data

	if ($ce->{achievementItemsEnabled} && defined $globalUserAchievement) {

	    my $itemsWithCounts = WeBWorK::AchievementItems::UserItems($effectiveUserName, $db, $ce);
            $self->{achievementItems} = $itemsWithCounts;

	    my $usedItem = $r->param('useditem');

	    # if the useditem parameter is defined then the student wanted to
	    # use an item so lets do that by calling the appropriate item's
	    # use method and printing results

	    if (defined $usedItem) {
		my $error = $itemsWithCounts->[$usedItem]->[0]->use_item($effectiveUserName, $r);
		if ($error) {
		    $self->addbadmessage($error);
		} else {
                    if ($itemsWithCounts->[$usedItem]->[1] != 1)    {$itemsWithCounts->[$usedItem]->[1]--}
                    else {splice(@$itemsWithCounts, $usedItem, 1)};
		    $self->addgoodmessage($r->maketext('Reward used successfully!'));
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
	print CGI::submit({ class => 'btn btn-sm btn-secondary' }, 'changeFacebooking', $globalUserAchievement->facebooker
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
	    print CGI::p($r->maketext("You don't have any Achievement data associated to you!"));
	    return "";
	}

	print CGI::br();
	print CGI::start_div({ class => 'cheevobigbox' });

	#Print their "level achievement" if there is one and print the progress bar if there is one
	my $achievement;

	if ($globalUserAchievements->level_achievement_id) {
	    $achievement = $db->getAchievement($globalUserAchievements->level_achievement_id);
	}

	if ($achievement) {
		print CGI::start_div({ class => 'd-flex align-items-center gap-3' });
		my $imgSrc;
		if ($achievement->{icon}) {
			$imgSrc = $ce->{courseURLs}->{achievements} . "/" . $achievement->{icon};
		} else {
			$imgSrc = $ce->{webworkURLs}->{htdocs} . "/images/defaulticon.png";
		}

		print CGI::img({ src => $imgSrc, alt => 'Level Icon' });
		print CGI::start_div();
		print CGI::h1($achievement->name);

		if ($globalUserAchievements->next_level_points) {

			# get prev_level_points from globalData frozen_hash in database
			my $globalData = {};
			if ($globalUserAchievements->frozen_hash) {
				$globalData = thaw_base64($globalUserAchievements->frozen_hash);
			}
			my $prev_level = ($globalData->{prev_level_points}) ? $globalData->{prev_level_points} : 0;
			my $level_goal = $globalUserAchievements->next_level_points - $prev_level;
			my $level_prog = $globalUserAchievements->achievement_points - $prev_level;
			$level_prog = $level_prog >= 0 ? $level_prog : 0;
			$level_prog = $level_prog <= $level_goal ? $level_prog : $level_goal;
			my $levelpercentage = int(100*$level_prog/$level_goal);

			print CGI::start_div({
				class      => 'levelouterbar',
				title      => $r->maketext("[_1]% Complete", $levelpercentage),
				aria_label => $r->maketext("[_1]% Complete", $levelpercentage),
				role       => 'figure'
			});
			print CGI::div({ class => 'levelinnerbar', style => "width:$levelpercentage\%" }, '');
			print CGI::end_div();
			print CGI::div(CGI::strong($r->maketext('Level Progress:')) . " $level_prog/$level_goal");
		}
		print CGI::div(CGI::strong($r->maketext('Total Points:')) . ' ' . $globalUserAchievements->achievement_points);
		print CGI::end_div();
		print CGI::end_div();
	}
	print CGI::end_div();

	#print any items they have if they have items
	if ($ce->{achievementItemsEnabled} && $self->{achievementItems}) {
		my @itemsWithCounts = @{$self->{achievementItems}};
		# remove count data so @items is structured as originally designed
		my @items = ();
		my %itemCounts = ();
		for my $item (@itemsWithCounts) {
			push (@items, $item->[0]);
			$itemCounts{$item->[0]->id()} = $item->[1];
		};
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

		print CGI::h2($r->maketext('Rewards'));

		if (@items) {
			my $itemnumber = 0;
			foreach my $item (@items) {
				# Print each item's name, count, and description
				print CGI::start_div({ class => 'achievement-item' });
				if ($itemCounts{$item->id()} > 1) {
					print CGI::h3($r->maketext($item->name())
						. ' (' . $r->maketext('[_1] remaining', $itemCounts{$item->id()}) . ')')
				} elsif ($itemCounts{$item->id()} < 0) {
					print CGI::h3($r->maketext($item->name()) . ' (' . $r->maketext('unlimited reusability') . ')')
				}
				else {print CGI::h3($r->maketext($item->name()))};

				print CGI::p($r->maketext($item->description()));
				# Print a modal popup for each item which contains the form necessary to get the data to use the item.
				# Print the form in the modal body.
				print CGI::a({
						href           => '#modal_' . $item->id(),
						role           => 'button',
						data_bs_toggle => 'modal',
						class          => 'btn btn-secondary',
						id             => 'popup_' . $item->id()
					}, $r->maketext('Use Reward'));
				print CGI::start_div({ id => 'modal_' . $item->id(), class => 'modal hide fade', tabindex => '-1' });
				print CGI::start_div({ class => 'modal-dialog modal-dialog-centered' });
				print CGI::start_div({ class => 'modal-content' });
				print CGI::start_div({ class => 'modal-header' });
				print CGI::h5({ class => 'modal-title' }, $r->maketext($item->name()));
				print qq{<button type="button" class="btn-close" data-bs-dismiss="modal"
					aria-label="@{[$r->maketext('close')]}"></button>};
				print CGI::end_div();
				print CGI::start_form({
						method => 'post',
						action => $self->systemLink($urlpath, authen => 0),
						name   => "itemform_$itemnumber",
						class  => 'achievementitemform'
					});
				print CGI::start_div({ class => 'modal-body' });
				# Note: we provide the item with some information about the current sets to help set up the form fields.
				print $item->print_form(\@sets, \@setProblemCount, $r);
				print CGI::hidden({ name => "useditem", value => $itemnumber });
				print $self->hidden_authen_fields =~ s/id=\"hidden_/id=\"achievement_${itemnumber}_hidden_/gr;
				print CGI::end_div();
				print CGI::start_div({ class => 'modal-footer' });
				print CGI::submit({ value => $r->maketext('Submit'), class => 'btn btn-primary' });
				print CGI::end_div();
				print CGI::end_form();
				print CGI::end_div();
				print CGI::end_div();
				print CGI::end_div();
				print CGI::end_div();

				$itemnumber++;
			}
		} else {
			print CGI::p($r->maketext('You don\'t have any rewards!'));
		}
		print CGI::br();
	}

	#Get all the achievements

	my @allAchievementIDs = $db->listAchievements;
	if ( @allAchievementIDs ) { # bail if there are no achievements
		my @achievements = $db->getAchievements(@allAchievementIDs);

		@achievements = sortAchievements(@achievements);
		my $previousCategory = $achievements[0]->category;
		my $previousNumber = $achievements[0]->number;
		my $chainName = $achievements[0]->achievement_id =~ s/^([^_]*_).*$/$1/r;
		my $chainCount = 0;
		my $chainStart = 0;

		print CGI::h2($r->maketext('Badges'));

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

			#setup up chain achievements
			my $isChain = 1;
			if (! $achievement->max_counter ||
				$achievement->max_counter == 0 ||
				$previousCategory ne $achievement->category ||
				$previousNumber + 1 != $achievement->number ||
				$achievement->achievement_id !~ /^$chainName/ )
			{
				$isChain = 0;
				$chainCount = 0;
				$chainName = $achievement->achievement_id =~ s/^([^_]*_).*$/$1/r;
			}
			$previousNumber = $achievement->number;
			$previousCategory = $achievement->category;

			my $userAchievement = $db->getUserAchievement($userID,$achievement->achievement_id);

			#dont show unearned secret achievements
			next if ($achievement->category eq 'secret' and not $userAchievement->earned);

			#dont show chain achievements (beyond first)
			$chainCount++ if ($isChain && !$userAchievement->earned);
			if ($chainCount == 0) {
				$chainStart = $userAchievement->earned ? 1 : 0;
			}
			next if ($isChain && ($chainCount > 1 || ($chainCount == '1' && $chainStart == '0')));

			#print achievement and associated progress bar (if there is one)
			print CGI::start_div(
				{
					class => 'cheevoouterbox d-flex justify-content-start align-items-center mb-3 '
						. ($userAchievement->earned ? 'unlocked' : 'locked')
				}
			);

			my $imgSrc;
			if ($achievement->{icon}) {
			$imgSrc = $ce->{courseURLs}->{achievements}."/".$achievement->{icon};
			} else {
			$imgSrc = $ce->{webworkURLs}->{htdocs}."/images/defaulticon.png";
			}

			print CGI::div(CGI::img({src=>$imgSrc, alt=>$userAchievement->earned ? 'Achievement Earned' : 'Achievement Unearned'}));
			print CGI::start_div({ class => 'ms-3' });
			print CGI::h3({ class => 'fs-5 mb-1 fw-bold' }, $achievement->name);
			print CGI::div(CGI::i($r->maketext("[_1] Points:", $achievement->{points})).' '.$achievement->{description});

			if ($achievement->max_counter and not $userAchievement->earned) {
			my $userCounter = $userAchievement->counter;
			$userCounter = 0 unless ($userAchievement->counter);
			my $percentage = int(100*$userCounter/$achievement->max_counter);
			$percentage = $percentage <= 100 ? $percentage : 100;
			print CGI::start_div({
				class      => 'cheevoouterbar mt-1',
				title      => $r->maketext("[_1]% Complete", $percentage),
				aria_label => $r->maketext("[_1]% Complete", $percentage),
				role       => 'figure'
			});
			print CGI::div({ class => 'cheevoinnerbar', style => sprintf("width:%i%%;", $percentage) }, '');
			print CGI::end_div();
			}
			print CGI::end_div();
			print CGI::end_div();

			}
		} else { # no achievements
		print CGI::p($r->maketext('No achievement badges have been assigned yet.'));
		}

	return "";

}

1;
