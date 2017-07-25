################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: 
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

package WeBWorK::ContentGenerator::Instructor::AchievementList;
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemAchievementList - Entry point for achievement specific
data editing/viewing

=cut

=for comment

What do we want to be able to do here?

-select achievements to edit and then edit their "basic data".  We should also be presented with 
links to edit the evaluator and the individual user data.  

-assign users to achievements "en masse"

-import achievements from a file

-export achievements form a file

-collect achievement "scores" and output to a file

-create and copy achievements

-delete achievements

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Utils qw(timeToSec readFile listFilesRecursive cryptPassword sortAchievements);
use DateTime;
use Text::CSV;

#constants for forms and the various handlers
use constant BLANK_ACHIEVEMENT => "blankachievement.at";
use constant DEFAULT_ENABLED_STATE => 0;

use constant EDIT_FORMS => [qw(saveEdit cancelEdit)];
use constant VIEW_FORMS => [qw(edit assign import export score create delete)];
use constant EXPORT_FORMS => [qw(saveExport cancelExport)];

use constant VIEW_FIELD_ORDER => [ qw( enabled achievement_id name number category ) ];
use constant EDIT_FIELD_ORDER => [ qw( icon achievement_id name number assignment_type category enabled points max_counter description icon_file test_file) ];
use constant EXPORT_FIELD_ORDER => [ qw( select achievement_id name) ];

use constant STATE_PARAMS => [qw(user effectiveUser key editMode exportMode)];

use constant ASSIGNMENT_TYPES => [qw(default gateway jitar)];

use constant ASSIGNMENT_NAMES => {
    default => 'homework',
    gateway => 'gateways',
    jitar => 'just-in-time',
};

#properites for the fields shown in the tables
use constant  FIELD_PROPERTIES => {
	achievement_id => {
		type => "text",
		size => 8,
		access => "readonly",
	},
	name => {
		type => "text",
		size => 30,
		access => "readwrite",
	},
	assignment_type => {
		type => "assignment_type",
		size => 30,
		access => "readwrite",
	},
	category => {
		type => "text",
		size => 30,
		access => "readwrite",
	},
	number => {
		type => "text",
		size => 8,
		access => "readwrite",
	},
	icon => {
		type => "text",
		size => 85,
		access => "readwrite",
	},
	test => {
		type => "text",
		size => 85,
		access => "readwrite",
	},

	description => {
		type => "text",
		size => 85,
		access => "readwrite",
	},

	enabled => {
		type => "checked",
		size => 8,
		access => "readwrite",
	},	

	points => {
		type => "text",
		size => 8,
		access => "readwrite",
	},	

	max_counter => {
	        type => "text",
		size => 8,
		access => "readwrite",
	},
};

sub initialize {

	my ($self)       = @_;
	my $r            = $self->r;
	my $urlpath      = $r->urlpath;
	my $db           = $r->db;
	my $ce           = $r->ce;
	my $authz        = $r->authz;	
	my $courseName   = $urlpath->arg("courseID");
	my $achievementID= $urlpath->arg("achievementID");       
	my $user         = $r->param('user');
	

	my $root = $ce->{webworkURLs}->{root};

	#check permissions
	return CGI::div({class => "ResultsWithError"}, "You are not authorized to edit achievements.")
		unless $authz->hasPermissions($user, "edit_achievements");
	
	########## set initial values for state fields
	my @allAchievementIDs = $db->listAchievements;

	#### Temporary Transition Code ####
	# If an achievement doesn't have either a number or an assignment_type
	# then its probably an old achievement in which case we should
	# update its assignment_type to include 'default'.
	# This whole block of code can be removed once people have had time
	# to transition over.  (I.E. around 2017)
	
	foreach my $achievementID (@allAchievementIDs) {
	    my $achievement = $db->getAchievement($achievementID);
	    unless ($achievement->assignment_type || $achievement->number) {
		$achievement->assignment_type('default');
		$db->putAchievement($achievement);
	    }
	}
	### End Transition Code.  ###
	
	
	my @users = $db->listUsers;
	$self->{allAchievementIDs} = \@allAchievementIDs;
	$self->{totalUsers} = scalar @users;

	
	if (defined $r->param("selected_achievements")) {
		$self->{selectedAchievementIDs} = [ $r->param("selected_achievements") ];
	} else {
		$self->{selectedAchievementIDs} = [];
	}
	
	$self->{editMode} = $r->param("editMode") || 0;
	
	#########################################
	#  call action handler  
	#########################################
	
	my $actionID = $r->param("action");
	$self->{actionID} = $actionID;
	if ($actionID) {
		unless (grep { $_ eq $actionID } @{ VIEW_FORMS() }, @{ EDIT_FORMS() }, @{ EXPORT_FORMS() }) {
			die "Action $actionID not found";
		}

		my $actionHandler = "${actionID}_handler";
		my %genericParams;
		foreach my $param (qw(selected_achievements)) {
		    $genericParams{$param} = [ $r->param($param) ];
		}
		my %actionParams = $self->getActionParams($actionID);
		my %tableParams = $self->getTableParams();
		$self->addmessage( CGI::div($r->maketext("Results of last action performed: ")));
		$self->addmessage(
		       $self->$actionHandler(\%genericParams, \%actionParams, \%tableParams), 
			       CGI::hr()
		    );
		
	} else {
	    
	    $self->addgoodmessage($r->maketext("Please select action to be performed."));
	}
		
	
}

sub body {
	my ($self)       = @_;
	my $r            = $self->r;
	my $urlpath      = $r->urlpath;
	my $db           = $r->db;
	my $ce           = $r->ce;
	my $authz        = $r->authz;	
	my $courseName   = $urlpath->arg("courseID");
	my $achievementID= $urlpath->arg("achievementID");       
	my $user         = $r->param('user');
	
	my $root = $ce->{webworkURLs}->{root};

	return CGI::div({class => "ResultsWithError"}, "You are not authorized to edit achievements.")
		unless $authz->hasPermissions($user, "edit_achievements");
	
	my $actionID = $self->{actionID};
	
	########## retrieve possibly changed values for member fields
	
	my @allAchievementIDs = @{ $self->{allAchievementIDs} }; # do we need this one? YES, deleting or importing a achievement will change this.
	my @selectedAchievementIDs = @{ $self->{selectedAchievementIDs} };
	my $editMode = $self->{editMode};
	my $exportMode = $self->{exportMode};
	
	########## get achievements
	
	# DBFIXME use an iterator
	my @Achievements = $db->getAchievements(@allAchievementIDs);
	
	# sort Achievments.  Achievements are always sorted by in the order they are evaluated
	if (@Achievements) {
	    @Achievements = sortAchievements(@Achievements);
	}

	########## print site identifying information
	
	print WeBWorK::CGI_labeled_input(-type=>"button", -id=>"show_hide", -input_attr=>{-value=>$r->maketext("Show/Hide Site Description"), -class=>"button_input"});
	print CGI::p({-id=>"site_description", -style=>"display:none"}, CGI::em($r->maketext("_ACHIEVEMENTS_EDITOR_DESCRIPTION")));
	
	########## print beginning of form

	print CGI::start_form({method=>"post", action=>$self->systemLink($urlpath,authen=>0), id=>"achievement-list", name=>"achievementlist"});
	print $self->hidden_authen_fields();
	
	########## print state data
	
	print "\n<!-- state data here -->\n";
	
	print CGI::hidden(-name=>"editMode", -value=>$editMode);
	print CGI::hidden(-name=>"exportMode", -value=>$exportMode);
	
	print "\n<!-- state data here -->\n";
	
	########## print action forms
	
	print CGI::p(CGI::b($r->maketext("Any changes made below will be reflected in the achievement for ALL students."))) if $editMode;

	print CGI::p($r->maketext("Select an action to perform").":");

	my @formsToShow;
	if ($editMode) {
		@formsToShow = @{ EDIT_FORMS() };
	} else {
		@formsToShow = @{ VIEW_FORMS() };
	}
	
	if ($exportMode) {
		@formsToShow = @{ EXPORT_FORMS() };
	}
	
	print CGI::start_div({-class=>"tabber"});

	my $i = 0;
	foreach my $actionID (@formsToShow) {

		my $actionForm = "${actionID}_form";
		my $onChange = "document.achievementlist.action[$i].checked=true";
		my %actionParams = $self->getActionParams($actionID);
		
		print CGI::div({-class=>"tabbertab"},
			   CGI::h3($r->maketext(ucfirst(WeBWorK::split_cap($actionID)))),
			   CGI::span({-class=>"radio_span"},  WeBWorK::CGI_labeled_input(-type=>"radio", 
			   -id=>$actionID."_id", -label_text=>$r->maketext(ucfirst(WeBWorK::split_cap($actionID))), 
                           -input_attr=>{-name=>"action", -value=>$actionID}, -label_attr=>{-class=>"radio_label"})),			       
			       $self->$actionForm($onChange, %actionParams)
		    );
		
		$i++;
	}
	
	print WeBWorK::CGI_labeled_input(-type=>"submit", -id=>"take_action", -input_attr=>{-value=>$r->maketext("Take Action!"), -class=>"button_input"}).CGI::br().CGI::br();

	print CGI::end_div();
	
	########## print table

	$self->printTableHTML(\@Achievements,
		editMode => $editMode,
		exportMode => $exportMode,
		selectedAchievementIDs => \@selectedAchievementIDs,
	);
	
	
	########## print end of form
	
 	print CGI::end_form();

	return "";
}

################################################################################
# extract particular params and put them in a hash (values are ARRAYREFs!)
################################################################################

sub getActionParams {
	my ($self, $actionID) = @_;
	my $r = $self->{r};
	
	my %actionParams;
	foreach my $param ($r->param) {
		next unless $param =~ m/^action\.$actionID\./;
		$actionParams{$param} = [ $r->param($param) ];
	}
	return %actionParams;
}

sub getTableParams {
	my ($self) = @_;
	my $r = $self->{r};
	
	my %tableParams;
	foreach my $param ($r->param) {
		next unless $param =~ m/^(?:achievement)\./;
		$tableParams{$param} = [ $r->param($param) ];
	}
	return %tableParams;
}

################################################################################
# actions and action triggers
################################################################################

# edit, cancelEdit, and saveEdit should stay with the display module and
# not be real "actions". that way, all actions are shown in view mode and no
# actions are shown in edit mode.


#form for edition achievements
sub edit_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	return join("",
		$r->maketext("Edit")." ",
		CGI::popup_menu(
			-name => "action.edit.scope",
			-values => [qw(all selected)],
			-default => $actionParams{"action.edit.scope"}->[0] || "selected",
			-labels => {
				all => $r->maketext("all achievements"),
				selected => $r->maketext("selected achievements"),
			},
			-onchange => $onChange,
		),
	);
}

#handler for editing achievements.  Just changes the view mode
sub edit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;
	my $result;
	
	my $scope = $actionParams->{"action.edit.scope"}->[0];
	if ($scope eq "all") {
	        $self->{selectedAchievementIDs} = $self->{allAchievementIDs};
		$result = $r->maketext("editing all achievements");
	} elsif ($scope eq "selected") {
		$result = $r->maketext("editing selected achievements");
	}
	$self->{editMode} = 1;
	
	return $result;
}

#form for assigning achievemetns to users
sub assign_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;

	return $r->maketext("Assign [_1] to all users, create global data, and [_2].",
		CGI::popup_menu(
			-name => "action.assign.scope",
			-values => [qw(all selected)],
			-default => $actionParams{"action.assign.scope"}->[0] || "selected",
			-labels => {
				all => $r->maketext("all achievements"),
				selected => $r->maketext("selected achievements"),
			},
			-onchange => $onChange,
		),
   		CGI::popup_menu(
			-name => "action.assign.overwrite",
			-values => [qw(everything new_only)],
			-default => $actionParams{"action.assign.overwrite"}->[0] || "new_only",
			-labels => {
				everything => $r->maketext("overwrite all data"),
				new_only => $r->maketext("preserve existing data"),
			},
			-onchange => $onChange,
		)
	);
}

#handler for assigning achievements to users
sub assign_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r      = $self->r;
	my $db     = $r->db;
	my $ce     = $r->ce;

	my $scope = $actionParams->{"action.assign.scope"}->[0];
	my $overwrite = (($actionParams->{"action.assign.overwrite"}->[0] eq 'everything') ? 1 : 0);
	
	my @achievementIDs;
	my @users = $db->listUsers;


	if ($scope eq "all") {
	        @achievementIDs = @{$self->{allAchievementIDs}};
	} else {
	    	@achievementIDs = @{$self->{selectedAchievementIDs}};
	}
	
	#Enable all achievements
	my @achievements = $db->getAchievements(@achievementIDs);
	
	foreach my $achievement (@achievements) {
	    $achievement->enabled(1);
	    $db->putAchievement($achievement);
	}

	#Assign globalUserAchievement data, overwriting if necc

	foreach my $user (@users) {
	    if (not $db->existsGlobalUserAchievement($user)) {
		my $globalUserAchievement = $db->newGlobalUserAchievement();
		$globalUserAchievement->user_id($user);
		$db->addGlobalUserAchievement($globalUserAchievement);
	    } elsif ($overwrite) {
		my $globalUserAchievement = $db->newGlobalUserAchievement();
		$globalUserAchievement->user_id($user);
		$db->putGlobalUserAchievement($globalUserAchievement);
	    }
	}
		

	#Assign userAchievement data, overwriting if necc

	foreach my $achievementID (@achievementIDs) {
	    foreach my $user (@users) {
		if (not $db->existsUserAchievement($user,$achievementID)) {
		    my $userAchievement = $db->newUserAchievement();
		    $userAchievement->user_id($user);
		    $userAchievement->achievement_id($achievementID);
		    $db->addUserAchievement($userAchievement);
		} elsif ($overwrite) {
		    my $userAchievement = $db->newUserAchievement();
		    $userAchievement->user_id($user);
		    $userAchievement->achievement_id($achievementID);
		    $db->putUserAchievement($userAchievement);
		}
	    }
	}
     

	return $r->maketext("Assigned achievements to users");
}

#form for scoring
sub score_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;

	return join ("",
		$r->maketext("Score")." ",
		CGI::popup_menu(
			-name => "action.score.scope",
			-values => [qw(none all selected)],
			-default => $actionParams{"action.score.scope"}->[0] || "none",
			-labels => {
				none => $r->maketext("no achievements"),
				all => $r->maketext("all achievements"),
				selected => $r->maketext("selected achievements"),
			},
			-onchange => $onChange,
		),
	);


}

#handler for scoring
sub score_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r      = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	my $courseName = $urlpath->arg("courseID");

	my $scope = $actionParams->{"action.score.scope"}->[0];	
	my @achievementsToScore;
	
	if ($scope eq "none") { 
		@achievementsToScore = ();
	} elsif ($scope eq "all") {
		@achievementsToScore = @{ $self->{allAchievementIDs} };
	} elsif ($scope eq "selected") {
		@achievementsToScore = @{ $genericParams->{selected_achievements} };
	}

	#define file name
	my $scoreFileName = $courseName."_achievement_scores.csv";
	my $scoreFilePath = $ce->{courseDirs}->{scoring}.'/'.$scoreFileName;
	
	# back up existing file
	if(-e $scoreFilePath) {
	    rename($scoreFilePath, "$scoreFilePath.bak") or 
		warn "Existing file $scoreFilePath could not be backed up and was lost.";
	}

	# check path and open the file
	$scoreFilePath = WeBWorK::Utils::surePathToFile($ce->{courseDirs}->{scoring}, $scoreFilePath);

	local *SCORE;
	open SCORE, ">$scoreFilePath" or return CGI::div({class=>"ResultsWithError"}, $r->maketext("Failed to open [_1]", $scoreFilePath));

	#print out header info
	print SCORE $r->maketext("username, last name, first name, section, achievement level, achievement score,");
	
	my @achievements = $db->getAchievements(@achievementsToScore);
	@achievements = sortAchievements(@achievements);

	foreach my $achievement (@achievements) {
	    print SCORE $achievement->achievement_id.", ";
	}
	print SCORE "\n";

	my @users = $db->listUsers;
	
	# get user records
	my @userRecords  = ();
	foreach my $currentUser ( @users) {
		my $userObj = $db->getUser($currentUser); #checked
		die "Unable to find user object for $currentUser. " unless $userObj;
		push (@userRecords, $userObj );
	}
	
	@userRecords = sort { ( lc($a->section) cmp lc($b->section) ) || 
	                     ( lc($a->last_name) cmp lc($b->last_name )) } @userRecords;

	
	#print out achievement information for each user
	foreach my $userRecord (@userRecords) {
	    my $user_id = $userRecord->user_id;
	    next unless $db->existsGlobalUserAchievement($user_id);
	    next if ($userRecord->{status} eq 'D' || $userRecord->{status} eq 'A');
	    print SCORE "$user_id, $userRecord->{last_name}, $userRecord->{first_name}, $userRecord->{section}, ";
	    my $globalUserAchievement = $db->getGlobalUserAchievement($user_id);
	    my $level_id = $globalUserAchievement->level_achievement_id;
	    $level_id = ' ' unless $level_id;
	    my $points = $globalUserAchievement->achievement_points;
	    $points = 0 unless $points;
	    print SCORE "$level_id, $points, ";

	    foreach my $achievement (@achievements) {
		my $achievement_id = $achievement->achievement_id;
		if ($db->existsUserAchievement($user_id,$achievement_id)) {
		    my $userAchievement = $db->getUserAchievement($user_id,$achievement_id);
		    print SCORE $userAchievement->earned ? "1, ": "0, ";
		} else {
		    print SCORE ", ";
		}
	    }

	    print SCORE "\n";
	}
	
	close SCORE;

	# Include a download link
	#
	my $fileManagerPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::FileManager", $r, courseID => $courseName);
	my $fileManagerURL  = $self->systemLink($fileManagerPage, params => {action=>"View", files => "${courseName}_achievement_scores.csv", pwd=>"scoring"});
	
	
	return CGI::div({class=>"ResultsWithoutError"},  $r->maketext("Achievement scores saved to [_1]",CGI::a({href=>$fileManagerURL},$scoreFileName)));
}


#form for delete action
sub delete_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	return join("",
		CGI::div({class=>"ResultsWithError"}, 
			$r->maketext("Delete")," ",
			CGI::popup_menu(
				-name => "action.delete.scope",
				-values => [qw(none selected)],
				-default => "none", #  don't make it easy to delete # $actionParams{"action.delete.scope"}->[0] || "none",
				-labels => {
					none => $r->maketext("no achievements."),
					selected => $r->maketext("selected achievements."),
				},
				-onchange => $onChange,
			),' ',
			CGI::em($r->maketext("Deletion destroys all achievement-related data and is not undoable!")),
		)
	);
}

#handler for delete action
sub delete_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;

	my $r      = $self->r;
	my $db     = $r->db;

	my $scope = $actionParams->{"action.delete.scope"}->[0];

	
	my @achievementIDsToDelete = ();

	if ($scope eq "selected") {
		@achievementIDsToDelete = @{ $self->{selectedAchievementIDs} };
	}
	
	my %allAchievementIDs = map { $_ => 1 } @{ $self->{allAchievementIDs} };
	my %selectedAchievementIDs = map { $_ => 1 } @{ $self->{selectedAchievementIDs} };
	
	#run through selected achievements and delete
	foreach my $achievementID (@achievementIDsToDelete) {
		delete $allAchievementIDs{$achievementID};
		delete $selectedAchievementIDs{$achievementID};
		
		$db->deleteAchievement($achievementID);
	}
	
	#update local fields
	$self->{allAchievementIDs} = [ keys %allAchievementIDs ];
	$self->{selectedAchievementIDs} = [ keys %selectedAchievementIDs ];
	
	my $num = @achievementIDsToDelete;
	return CGI::div({class=>"ResultsWithoutError"},  $r->maketext("Deleted [quant,_1,achievement]", $num));
}

#form for creating achievement
sub create_form {
	my ($self, $onChange, %actionParams) = @_;

	my $r      = $self->r;
	
	return $r->maketext("Create a new achievement with ID").CGI::span({class=>"required-field"},'*').': '.
		CGI::textfield(
			-name => "action.create.id",
			-value => $actionParams{"action.create.name"}->[0] || "",
			-width => "60",
			-onchange => $onChange,
		),
		" ".$r->maketext("as")." ",
		CGI::popup_menu(
			-name => "action.create.type",
			-values => [qw(empty copy)],
			-default => $actionParams{"action.create.type"}->[0] || "empty",
			-labels => {
				empty => $r->maketext("a new empty achievement."),
				copy => $r->maketext("a duplicate of the first selected achievement."),
			},
			-onchange => $onChange,
		);
			
}

#handler for creating an ahcievement
sub create_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
     
	my $r      = $self->r;
	my $db     = $r->db;
	my $ce     = $r->ce;
	my $user         = $r->param('user');

	#create achievement
	my $newAchievementID = $actionParams->{"action.create.id"}->[0];
	return CGI::div({class => "ResultsWithError"}, $r->maketext("Failed to create new achievement: no achievement ID specified!")) unless $newAchievementID =~ /\S/;
	return CGI::div({class => "ResultsWithError"}, $r->maketext("Achievement [_1] exists.  No achievement created",$newAchievementID)) if $db->existsAchievement($newAchievementID);
	my $newAchievementRecord = $db->newAchievement;
	my $oldAchievementID = $self->{selectedAchievementIDs}->[0];

	my $type = $actionParams->{"action.create.type"}->[0];

	#either assign empty data or copy over existing data
	if ($type eq "empty") {
		$newAchievementRecord->achievement_id($newAchievementID);
		$newAchievementRecord->enabled(0);
		$newAchievementRecord->assignment_type('default');
		$newAchievementRecord->test(BLANK_ACHIEVEMENT());
		$db->addAchievement($newAchievementRecord);
	} elsif ($type eq "copy") {
		return CGI::div({class => "ResultsWithError"}, $r->maketext("Failed to duplicate achievement: no achievement selected for duplication!")) unless $oldAchievementID =~ /\S/;
		$newAchievementRecord = $db->getAchievement($oldAchievementID);
		$newAchievementRecord->achievement_id($newAchievementID);
		$db->addAchievement($newAchievementRecord);

	}

	# assign achievement to current user
	my $userAchievement = $db->newUserAchievement();
	$userAchievement->user_id($user);
	$userAchievement->achievement_id($newAchievementID);
	$db->addUserAchievement($userAchievement);

	#add to local list of achievements
	push @{ $self->{allAchievementIDs} }, $newAchievementID;
	
	return CGI::div({class => "ResultsWithError"}, $r->maketext("Failed to create new achievement: [_1]",$@)) if $@;
	
	return CGI::div({class=>"ResultsWithoutError"},$r->maketext("Successfully created new achievement [_1]", $newAchievementID) );
	
}

#form for importing achievements
sub import_form {
	my ($self, $onChange, %actionParams) = @_;
	
	my $r = $self->r;
	my $authz = $r->authz;
	my $user = $r->param('user');

	return $r->maketext("Import achievements from [_1] assigning the achievements to [_2].",
		CGI::popup_menu(
			-name => "action.import.source",
			-values => [ "", $self->getAxpList() ],
			-labels => { "" => $r->maketext("the following file") },
			-default => $actionParams{"action.import.source"}->[0] || "",
		        -onchange => $onChange,
		),
		    CGI::popup_menu(
			-name => "action.import.assign",
			-value => [qw(none all)],
			-default => $actionParams{"action.import.assign"}->[0] || "none",
			-labels => {
			    all => $r->maketext("all current users"),
			    none => $r->maketext("no users"),
			},
			-onchange => $onChange,
		   )
	);
}

# handler for importing achievements
sub import_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r           = $self->r;
	my $ce          = $r->ce;
	my $db          = $r->db;

	my $fileName = $actionParams->{"action.import.source"}->[0];
	my $assign = $actionParams->{"action.import.assign"}->[0];
	my @users = $db->listUsers;
	my %allAchievementIDs = map { $_ => 1 } @{ $self->{allAchievementIDs} };
	my $filePath = $ce->{courseDirs}->{achievements}.'/'.$fileName;
	
	#open file name
	my $fh;
	open $fh, "$filePath" or return CGI::div({class=>"ResultsWithError"}, $r->maketext("Failed to open [_1]",$filePath));

	#read in lines from file
	my $count = 0;
	my $csv = Text::CSV->new();
	while (my $data = $csv->getline($fh)) {

	    my $achievement_id = $$data[0];
	    #skip achievements that already exist
	    next if $db->existsAchievement($achievement_id);

	    #write achievement data.  The "format" for this isn't written down anywhere (!)
	    my $achievement = $db->newAchievement();

	    $achievement->achievement_id($achievement_id);

	    # fall back for importing an old list without the number
	    # or assignment_type fields
	    if (scalar(@$data) == 9) {
		# old lists tend to have an extraneous space at the front. 
		for (my $i=1; $i<=7; $i++) {
		    $$data[$i] =~ s/^\s+//;
		}

		$$data[1] =~ s/\;/,/;
		$achievement->name($$data[1]);
		$achievement->category($$data[2]);
		$$data[3] =~ s/\;/,/;
		$achievement->description($$data[3]);
		$achievement->points($$data[4]);
		$achievement->max_counter($$data[5]);
		$achievement->test($$data[6]);
		$achievement->icon($$data[7]);
		$achievement->assignment_type('default');
		$achievement->number($count+1);
	    } else {
		$achievement->name($$data[1]);
		$achievement->number($$data[2]);
		$achievement->category($$data[3]);
		$achievement->assignment_type($$data[4]);
		$achievement->description($$data[5]);
		$achievement->points($$data[6]);
		$achievement->max_counter($$data[7]);
		$achievement->test($$data[8]);
		$achievement->icon($$data[9]);
	    }

	    $achievement->enabled($assign eq "all"?1:0);
	    
	    #add achievement
	    $db->addAchievement($achievement);
	    $count++;
	    $allAchievementIDs{$achievement_id} = 1;
	    
	    #assign to usesrs if necc
	    if ($assign eq "all") {
		foreach my $user (@users) {
		    if (not $db->existsGlobalUserAchievement($user)) {
			my $globalUserAchievement = $db->newGlobalUserAchievement();
			$globalUserAchievement->user_id($user);
			$db->addGlobalUserAchievement($globalUserAchievement);
		    }
		    my $userAchievement = $db->newUserAchievement();
		    $userAchievement->user_id($user);
		    $userAchievement->achievement_id($achievement_id);
		    $db->addUserAchievement($userAchievement);
		}
	    }
	}

	$self->{allAchievementIDs} = [ keys %allAchievementIDs ];
		    
	return CGI::div(
	    {class=>"ResultsWithoutError"}, $r->maketext("Imported [quant,_1,achievement]", $count));
}

#form for exporting 
sub export_form {
	my ($self, $onChange, %actionParams) = @_;
	my $r = $self->r;
	return join("",
		$r->maketext("Export").' ',
		CGI::popup_menu(
			-name => "action.export.scope",
			-values => [qw(all selected)],
			-default => $actionParams{"action.export.scope"}->[0] || "selected",
			-labels => {
			    all => $r->maketext("all achievements"),
			    selected => $r->maketext("selected achievements"),
			},
			-onchange => $onChange,
		),
	);
}

# export handler
# this does not actually export any files, rather it sends us to a new page in order to export the files
sub export_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r = $self->r;
	my $result;
	
	my $scope = $actionParams->{"action.export.scope"}->[0];
	if ($scope eq "all") {
		$result = $r->maketext("exporting all achievements");
		$self->{selectedAchievementIDs} = $self->{allAchievementIDs};
	} elsif ($scope eq "selected") {
		$result = $r->maketext("exporting selected achievements");
		$self->{selectedAchievementIDs} = $genericParams->{selected_achievements}; # an arrayref
	}
	$self->{exportMode} = 1;
	
	return   CGI::div({class=>"ResultsWithoutError"},  $result);
}


#form and hanlder for leaving the export page
sub cancelExport_form {
	my ($self, $onChange, %actionParams) = @_;
	return $self->r->maketext("Abandon export");
}

sub cancelExport_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r      = $self->r;
	
	$self->{exportMode} = 0;
	
	return CGI::div({class=>"ResultsWithError"},  $r->maketext("export abandoned"));
}

#handler and form for actually exporting
sub saveExport_form {
	my ($self, $onChange, %actionParams) = @_;
	return $self->r->maketext("Export selected achievements.");
}

sub saveExport_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r           = $self->r;
	my $ce          = $r->ce;
	my $db          = $r->db;
	my $urlpath = $r->urlpath;
	my $courseName = $urlpath->arg("courseID");

	my @achievementIDsToExport = $r->param("selected_export") ;

	#get file path
	my $FileName = $courseName."_achievements.axp";
	my $FilePath = $ce->{courseDirs}->{achievements}.'/'.$FileName;
	
	# back up existing file
	if(-e $FilePath) {
	    rename($FilePath, "$FilePath.bak") or 
		warn "Existing file $FilePath could not be backed up and was lost.";
	}

	$FilePath = WeBWorK::Utils::surePathToFile($ce->{courseDirs}->{achievements}, $FilePath);
	#open file
	my $fh;
	open $fh, ">$FilePath" or return CGI::div({class=>"ResultsWithError"}, $r->maketext("Failed to open [_1]", $FilePath));

	my $csv = Text::CSV->new({eol=>"\n"});
	my @achievements = $db->getAchievements(@achievementIDsToExport);
	#run through achievements outputing data as csv list.  This format is not documented anywhere
	foreach my $achievement (@achievements) {
	    my $line = [$achievement->achievement_id,
			$achievement->name,
			$achievement->number,
			$achievement->category,
			$achievement->assignment_type,
			$achievement->description,
			$achievement->points,
			$achievement->max_counter,
			$achievement->test,
			$achievement->icon,];

	    warn("Error Exporting Achievement ".$achievement->achievement_id)
		unless $csv->print($fh, $line);
	}

	close EXPORT;
	
	$self->{exportMode} = 0;
	
	return 	CGI::div( {class=>"resultsWithoutError"}, $r->maketext("Exported achievements to [_1]", $FileName));

}

#form and handler for cancelling edits
sub cancelEdit_form {
	my ($self, $onChange, %actionParams) = @_;
	return $self->r->maketext("Abandon changes");
}

sub cancelEdit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r      = $self->r;
	
	$self->{editMode} = 0;
	
	return CGI::div({class=>"ResultsWithError"}, $r->maketext("changes abandoned"));
}

#form and handler for saving edits
sub saveEdit_form {
	my ($self, $onChange, %actionParams) = @_;
	return $self->r->maketext("Save changes");
}

sub saveEdit_handler {
	my ($self, $genericParams, $actionParams, $tableParams) = @_;
	my $r           = $self->r;
	my $db          = $r->db;
	
	my @selectedAchievementIDs = @{ $self->{selectedAchievementIDs} };
	
	#run through selected achievements
	foreach my $achievementID (@selectedAchievementIDs) {
		my $Achievement = $db->getAchievement($achievementID); # checked
		# FIXME: we may not want to die on bad sets, they're not as bad as bad users
		die "record for achievement $achievementID not found" unless $Achievement;

		#update fields
		foreach my $field ($Achievement->NONKEYFIELDS()) {
			my $param = "achievement.${achievementID}.${field}";

			if ($field eq 'assignment_type') {
			    my @types = ();
			    my $i = 0;

			    while (defined ($tableParams->{$param}->[$i])) {
				push @types,  $tableParams->{$param}->[$i];
				$i++;
			    }

			    $Achievement->assignment_type(join(',',@types));

			} else {

			    if (defined $tableParams->{$param}->[0]) {
				$Achievement->$field($tableParams->{$param}->[0]);
			    }
			}
		}
		
		$db->putAchievement($Achievement);
	}
	
	$self->{editMode} = 0;
	
	return CGI::div({class=>"ResultsWithoutError"}, $r->maketext("changes saved" ));
}

################################################################################
# "display" methods
################################################################################

#write out a particular field
sub fieldEditHTML {
	my ($self, $fieldName, $value, $properties) = @_;
	my $size = $properties->{size};
	my $type = $properties->{type};
	my $access = $properties->{access};
	my $items = $properties->{items};
	my $synonyms = $properties->{synonyms};
	my $headerFiles = $self->{headerFiles};
	
	if ($access eq "readonly") {
		return $value;
	}
	
	if ($type eq "number" or $type eq "text") {
		return CGI::input({type=>"text", name=>$fieldName, value=>$value, size=>$size});
	}
	
	if ($type eq "checked") {
		
		# FIXME: kludge (R)
		# if the checkbox is checked it returns a 1, if it is unchecked it returns nothing
		# in which case the hidden field overrides the parameter with a 0
		return CGI::checkbox(
			-name => $fieldName,
			-checked => $value,
			-label => "",
			-value => 1
		) . CGI::hidden(
			-name => $fieldName,
			-value => 0
		);
	}

	if ($type eq "assignment_type") {
	    my @allowedTypes = split(',',$value);

	    return CGI::checkbox_group(-name=> $fieldName,
				       -values=> ASSIGNMENT_TYPES,
				       -labels=> ASSIGNMENT_NAMES,
				       -default=> \@allowedTypes,
				       -linebreaks=>'false'
		);
	}
}

#write out a row of the table
sub recordEditHTML {
	my ($self, $Achievement, %options) = @_;
	my $r           = $self->r;
	my $urlpath     = $r->urlpath;
	my $ce          = $r->ce;
	my $db		= $r->db;
	my $authz	= $r->authz;
	my $user	= $r->param('user');
	my $root        = $ce->{webworkURLs}->{root};
	my $courseName  = $urlpath->arg("courseID");
	
	my $editMode = $options{editMode};
	my $exportMode = $options{exportMode};
	my $achievementSelected = $options{achievementSelected};

	my $users = $db->countAchievementUsers($Achievement->achievement_id);
	my $totalUsers = $self->{totalUsers};

	my @tableCells;
	my $achievement_id = $Achievement->achievement_id;
	my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::AchievementEditor",  $r, courseID => $courseName, achievementID => $achievement_id);
	my $editorURL = $self->systemLink($editorPage, params => {
	    sourceFilePath => $ce->{courseDirs}->{achievements}."/".$Achievement->test});

	my $userEditorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::AchievementUserEditor", $r, courseID=>$courseName, achievementID =>$achievement_id);
	my $userEditorURL = $self->systemLink($userEditorPage, params => {});

	# the formats are "hard coded" below.  Making them more modular would be good
	#format for export row
	if ($exportMode) {
	    # selection checkbox
	    push @tableCells, CGI::checkbox(
		-type => "checkbox",
		-name => "selected_export",
		-checked => $achievementSelected,
		-value => $achievement_id,
		-label => "",
					    );

	    my @fields = ("achievement_id", "name");
	    
	    foreach my $field (@fields) {
		
		my $fieldName = "achievement.".$achievement_id .".". $field;
		my $fieldValue = $Achievement->$field;
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = "readonly";
		$fieldValue =~ s/ /&nbsp;/g;
		push @tableCells, CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties));
	    }
	    
	    #format for edit mode
	} elsif ($editMode) {

	    return unless $achievementSelected;

	    my $tableCell;

	    if ($Achievement->{icon}) {
		$tableCell = CGI::img({-src=>$ce->{courseURLs}->{achievements}."/".$Achievement->{icon},-alt=>"Achievement Icon",-height=>60,-vspace=>10});
	    } else {
		$tableCell = CGI::img({-src=>$ce->{webworkURLs}->{htdocs}."/images/defaulticon.png"
					   ,-alt=>"Achievement Icon",-height=>60,-vspace=>10});
	    }

	    push @tableCells, $tableCell;

	    my $fieldName;
	    my $fieldValue;
	    my %properties;
	    my $field;

	    $tableCell = CGI::hidden(
		-name => "selected_achievements",
		-value => $achievement_id,
		);
	    
	    $field = "achievement_id";
	    $fieldName = "achievement.".$achievement_id.".".$field;
	    $fieldValue = $Achievement->$field;
	    %properties = %{ FIELD_PROPERTIES()->{$field} };
	    $tableCell=$tableCell.CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties)).CGI::br();

	    $field = "name";
	    $fieldName = "achievement.".$achievement_id.".".$field;
	    $fieldValue = $Achievement->$field;
	    %properties = %{ FIELD_PROPERTIES()->{$field} };
	    $tableCell=$tableCell.CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties)).CGI::br();

	    $field = "category";
	    $fieldName = "achievement.".$achievement_id.".".$field;
	    $fieldValue = $Achievement->$field;
	    %properties = %{ FIELD_PROPERTIES()->{$field} };
	    $tableCell=$tableCell.CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties));

	    push @tableCells, $tableCell;

	    $field = "number";
	    $fieldName = "achievement.".$achievement_id.".".$field;
	    $fieldValue = $Achievement->$field;
	    %properties = %{ FIELD_PROPERTIES()->{$field} };
	    $tableCell=CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties)).CGI::br();

	    $field = "enabled";
	    $fieldName = "achievement.".$achievement_id.".".$field;
	    $fieldValue = $Achievement->$field;
	    %properties = %{ FIELD_PROPERTIES()->{$field} };
	    $tableCell=$tableCell.CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties)).CGI::br();

	    $field = "points";
	    $fieldName = "achievement.".$achievement_id.".".$field;
	    $fieldValue = $Achievement->$field;
	    %properties = %{ FIELD_PROPERTIES()->{$field} };
	    $tableCell=$tableCell.CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties)).CGI::br();

	    $field = "max_counter";
	    $fieldName = "achievement.".$achievement_id.".".$field;
	    $fieldValue = $Achievement->$field;
	    %properties = %{ FIELD_PROPERTIES()->{$field} };
	    $tableCell=$tableCell.CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties));

	    push @tableCells, $tableCell;

	    $field = "description";
	    $fieldName = "achievement.".$achievement_id.".".$field;
	    $fieldValue = $Achievement->$field;
	    %properties = %{ FIELD_PROPERTIES()->{$field} };
	    $tableCell=CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties)).CGI::br();

	    $field = "test";
	    $fieldName = "achievement.".$achievement_id.".".$field;
	    $fieldValue = $Achievement->$field;
	    %properties = %{ FIELD_PROPERTIES()->{$field} };
	    $tableCell=$tableCell.CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties)).CGI::br();

	    $field = "icon";
	    $fieldName = "achievement.".$achievement_id.".".$field;
	    $fieldValue = $Achievement->$field;
	    %properties = %{ FIELD_PROPERTIES()->{$field} };
	    $tableCell=$tableCell.CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties)).CGI::br();

	    $field = "assignment_type";
	    $fieldName = "achievement.".$achievement_id.".".$field;
	    $fieldValue = $Achievement->$field;
	    %properties = %{ FIELD_PROPERTIES()->{$field} };
	    $tableCell=$tableCell.CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties));

	    push @tableCells, $tableCell;

	    #format for regular viewing mode
	} else {
	 
	    # selection checkbox
	    push @tableCells, CGI::checkbox({
		name => "selected_achievements",
		value => $achievement_id,
		checked => $achievementSelected,
		label => "",
		});
	    
	    my $AchievementEditURL = $self->systemLink($urlpath->new(type=>'instructor_achievement_list', args=>{courseID => $courseName})) . "&editMode=1&selected_achievements=" . $achievement_id;
	    my $imageURL = $ce->{webworkURLs}->{htdocs}."/images/edit.gif";
	    my $imageLink = CGI::a({href => $AchievementEditURL}, CGI::img({src=>$imageURL, border=>0}));

            my @fields = @{VIEW_FIELD_ORDER()};
	    foreach my $field (@fields) {
		my $fieldName = "achievement.".$achievement_id.".".$field;
		my $fieldValue = $Achievement->$field;
		my %properties = %{ FIELD_PROPERTIES()->{$field} };
		$properties{access} = "readonly";
		$fieldValue =~ s/ /&nbsp;/g;
		$fieldValue = ($fieldValue) ? $r->maketext("Yes") : $r->maketext("No") if $field =~ /enabled/;
		if ($field =~ /achievement_id/) {
		    $fieldValue .= $imageLink;
		    $fieldValue = CGI::div({class=>'label-with-edit-icon'},$fieldValue);
		}
		push @tableCells, CGI::font( $self->fieldEditHTML($fieldName, $fieldValue, \%properties));
	    }

	    push @tableCells, CGI::a({href=>$userEditorURL}, "$users/$totalUsers");

	    push @tableCells, CGI::a({href=>$editorURL}, $r->maketext("Edit Evaluator"));

	}

	return CGI::Tr({}, CGI::td({}, \@tableCells));
}

#this prints out the whole table
sub printTableHTML {
	my ($self, $AchievementsRef, %options) = @_;
	my $r                       = $self->r;
	my $authz                   = $r->authz;
	my $user                    = $r->param('user');
	my @Achievements                    = @$AchievementsRef;
  
	
	my $editMode                = $options{editMode};
	my $exportMode              = $options{exportMode};
	my %selectedAchievementIDs          = map { $_ => 1 } @{ $options{selectedAchievementIDs} };

	# names of headings:

	if ($editMode and not %selectedAchievementIDs) {
	    print CGI::p(
		CGI::i("No achievements shown.  Select an achievement to edit!"));
	    return;
	}
	    

	my $selectBox = CGI::input({
	    type=>'checkbox',
	    id=>'achievementlist-select-all',
	    onClick => "\$('input[name=\"selected_achievements\"]').attr('checked',\$('#achievementlist-select-all').is(':checked'));"
				   });

	my @tableHeadings; 
	    
	#hardcoded headings.  making htis more modular would be good
	if ($exportMode) {
	    @tableHeadings = ('',
			      $r->maketext("Achievement ID"),
			      $r->maketext("Name"));
	} elsif ($editMode) {
	    @tableHeadings = ($r->maketext("Icon"),
			      $r->maketext("Achievement ID").CGI::br().
			      $r->maketext("Name").CGI::br().
			      $r->maketext("Category"),
			      $r->maketext("Number").CGI::br().
			      $r->maketext("Enabled").CGI::br().
			      $r->maketext("Points").CGI::br().
			      $r->maketext("Counter"),
			      $r->maketext("Description").CGI::br().
			      $r->maketext("Evaluator File").CGI::br().
			      $r->maketext("Icon File").CGI::br().
			      $r->maketext("Type")
		);
	} else {
	    @tableHeadings = ($selectBox,
			      $r->maketext("Enabled"),
			      $r->maketext("Achievement ID"),
			      $r->maketext("Name"),
			      $r->maketext("Number"),
			      $r->maketext("Category"),
			      $r->maketext("Edit").CGI::br().$r->maketext("Users"),
			      $r->maketext("Edit").CGI::br().$r->maketext("Evaluator")
		);
	}
	
	# print the table
	if ($exportMode) {
	    print CGI::start_table({class=>"classlist-table", id=>"achievement-table"});
	} else {
	    print CGI::start_table({-border=>1, -cellpadding=>5, class=>"classlist-table", id=>"achievement-table"});
	}
	
	print CGI::Tr({}, CGI::th({}, \@tableHeadings));

	for (my $i = 0; $i < @Achievements; $i++) {
		my $Achievement = $Achievements[$i];

		print $self->recordEditHTML($Achievement,
			editMode => $editMode,
			exportMode => $exportMode,
			achievementSelected => exists $selectedAchievementIDs{
			    $Achievement->achievement_id}
		);
	}

	
	print CGI::end_table();
	#########################################
	# if there are no users shown print message
	# 
	##########################################
	
	print CGI::p(
                      CGI::i($r->maketext("No achievements shown.  Create an achievement!"))
	    ) unless @Achievements;
}

#get list of files that can be imported.  
sub getAxpList {
	my ($self) = @_;
	my $ce = $self->{ce};
	my $dir = $ce->{courseDirs}->{achievements};
	return $self->read_dir($dir, qr/.*\.axp/);
}

sub output_JS{
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/AddOnLoad/addOnLoadEvent.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/ShowHide/show_hide.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/legacy/vendor/tabber.js"}), CGI::end_script();

	return "";
}

# Just tells template to output the stylesheet for Tabber
sub output_tabber_CSS{
	return "";
}

1;

=head1 AUTHOR

Written by Robert Van Dam, toenail (at) cif.rochester.edu

=cut
