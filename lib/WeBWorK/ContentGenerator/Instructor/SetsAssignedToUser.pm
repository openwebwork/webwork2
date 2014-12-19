################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/SetsAssignedToUser.pm,v 1.26 2006/09/25 22:14:53 sh002i Exp $
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

package WeBWorK::ContentGenerator::Instructor::SetsAssignedToUser;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SetsAssignedToUsers - List and edit which
sets are assigned to a given user.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Debug;

sub initialize {
	my ($self)     = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;	
	my $db         = $r->db;
	my $authz      = $r->authz;

	my $userID     = $urlpath->arg("userID");
	my $user       = $r->param("user");
	
	# check authorization
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	return unless $authz->hasPermissions($user, "assign_problem_sets");
	
	# get the global user, if there is one
	my $globalUserID = "";
	$globalUserID = $db->{set}->{params}->{globalUserID}
		if ref $db->{set} eq "WeBWorK::DB::Schema::GlobalTableEmulator";
	
	if (defined $r->param("assignToAll")) {
		$self->assignAllSetsToUser($userID);
		debug("assignAllSetsToUser($userID)");
		$self->addmessage(CGI::div({class=>'ResultsWithoutError'}, "User has been assigned to all current sets."));
		debug("done assignAllSetsToUsers($userID)");
	} elsif (defined $r->param('unassignFromAll') and defined($r->param('unassignFromAllSafety')) and $r->param('unassignFromAllSafety')==1) {
		if ($userID ne $globalUserID) {
		  $self->addmessage(CGI::div({class=>'ResultsWithoutError'}, "User has been unassigned from all sets."));
			$self->unassignAllSetsFromUser($userID);
		}
	} elsif (defined $r->param('assignToSelected')) {
		# get list of all sets and a hash for checking selectedness
		# DBFIXME shouldn't need to get set list, should use iterator
		my @setIDs = $db->listGlobalSets;
		my @setRecords = grep { defined $_ } $db->getGlobalSets(@setIDs);
		my %selectedSets = map { $_ => 1 } $r->param("selected");
		
		# get current user
		my $User = $db->getUser($userID); # checked
		die "record not found for $userID.\n" unless $User;
		
		$self->addmessage(CGI::div({class=>'ResultsWithoutError'}, "User's sets have been reassigned."));
		
		unless ($User->user_id eq $globalUserID) {
		
			my %userSets = map { $_ => 1 } $db->listUserSets($userID);
			
			# go through each possible set
			foreach my $setRecord (@setRecords) {
				my $setID = $setRecord->set_id;
				# does the user want it to be assigned to the selected user
				if (exists $selectedSets{$setID}) {
					unless ($userSets{$setID}) {	# skip users already in the set
						debug("assignSetToUser($userID, $setID)");
						$self->assignSetToUser($userID, $setRecord);
						debug("done assignSetToUser($userID, $setID)");
					}
				} else {
					# user asked to NOT have the set assigned to the selected user
					next unless $userSets{$setID};	# skip users not in the set
					$db->deleteUserSet($userID, $setID);
				}
			}
		}
	} elsif (defined $r->param("unassignFromAll")) {
	   # no action taken
	   $self->addmessage(CGI::div({class=>'ResultsWithError'}, "No action taken"));
	}
}

sub getUserName {
	my ($self, $pathUserName) = @_;
	
	if (ref $pathUserName eq "HASH") {
		$pathUserName = undef;
	}
	
	return $pathUserName;
}



sub body {
	my ($self)      = @_;
	my $r           = $self->r;
	my $urlpath     = $r->urlpath;
	my $db          = $r->db;
	my $ce          = $r->ce;
	my $authz       = $r->authz;
	my $courseName  = $urlpath->arg("courseID");
	my $webworkRoot = $ce->{webworkURLs}->{root};
	my $userID      = $urlpath->arg("userID");
	
	my $user        = $r->param('user');
	my $setsAssignedToUserPage    = $urlpath->newFromModule($urlpath->module, $r, 
	                                                        courseID =>  $courseName,
	                                                        userID=>$userID
	);
	my $setsAssignedToUserURL     = $self->systemLink($setsAssignedToUserPage,authen=>0);

	# check authorization
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to access the Instructor tools."))
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to assign homework sets."))
		unless $authz->hasPermissions($user, "assign_problem_sets");
	
	# get list of sets
	# DBFIXME this is a duplicate call! :P :P :P
	my @setIDs = $db->listGlobalSets;
	my @Sets = $db->getGlobalSets(@setIDs);
	
#	# sort first by due date and then by name (this should be replaced with a
#	# call to a standard sorting routine!)
# 	@Sets = sort {
# 		$a->due_date <=> $b->due_date
# 		|| lc($a->set_id) cmp lc($b->set_id)
# 	} @Sets;

	# Sort by set name only  -- I find this most useful for the instructor pages
	@Sets = sort {
		lc($a->set_id) cmp lc($b->set_id)
	} @Sets;
	
	
	print CGI::start_form({id=>"set-user-form", name=>"set-user-form", method=>"post", action=>$setsAssignedToUserURL});
	print $self->hidden_authen_fields;
	
	# get the global user, if there is one
	my $globalUserID = "";
	$globalUserID = $db->{set}->{params}->{globalUserID}
		if ref $db->{set} eq "WeBWorK::DB::Schema::GlobalTableEmulator";
	
	if ($userID ne $globalUserID) {
		print CGI::p(CGI::submit({name=>"assignToAll", value=>"Assign All Sets"}));
	}
	
	print CGI::div({-style=>"color:red"},
		       "Do not uncheck a set unless you know what you are doing.", CGI::br(),
		       "There is NO undo for unassigning a set.");

	print CGI::p("When you uncheck a homework set (and save the changes), you destroy all
		      of the data for that set for this student.   If You then need to
		      reassign the set and the student will receive new versions of the problems.
		      Make sure this is what you want to do before unchecking sets."
	);
				        
	print CGI::start_table({});
        print CGI::Tr(CGI::th(["Assigned","&nbsp;&nbsp;","Set Name","&nbsp;&nbsp;","Due Date", "&nbsp;"]));
        print CGI::Tr(CGI::td([CGI::hr(),"",CGI::hr(),"",CGI::hr()]));
	
	foreach my $Set (@Sets) {
		my $setID = $Set->set_id;
		
		# this is true if $Set is assigned to the selected user
		# DBFIXME testing for existence -- don't need to fetch record
		my $UserSet = $db->getUserSet($userID, $setID); # checked
		my $currentlyAssigned = defined $UserSet;
		
		my $prettyDate;
		if ($currentlyAssigned and $UserSet->due_date) {
			$prettyDate = $self->formatDateTime($UserSet->due_date);
		} else {
			$prettyDate = $self->formatDateTime($Set->due_date);
		}
		
		# URL to edit user-specific set data
# 		my $url = $ce->{webworkURLs}->{root}
# 			. "/$courseName/instructor/sets/$setID/?editForUser=$userID&"
# 			. $self->url_authen_args();
        my $setListPage = $urlpath->new(type =>'instructor_set_detail',
					args =>{
						courseID => $courseName,
						setID    => $setID
	});
		my $url = $self->systemLink($setListPage,params =>{editForUser => $userID});
		print CGI::Tr({}, 
			      CGI::td({-align=>"center"},
				($userID eq $globalUserID
					? "" # no checkboxes for global user!
					: CGI::checkbox({
						type=>"checkbox",
						name=>"selected",
						checked=>$currentlyAssigned,
						value=>$setID,
						label=>"",
					})
				)),
			      CGI::td({}, [ "",
				$setID, "",
				"($prettyDate)", "",
				$currentlyAssigned
					? CGI::a({href=>$url}, "Edit user-specific set data")
					: (),
			])
		);
	}
        print CGI::Tr(CGI::td([CGI::hr(),"",CGI::hr(),"",CGI::hr()]));
	print CGI::end_table();
	print CGI::submit({name=>"assignToSelected", value=>"Save"});

	print CGI::p( CGI::hr(),
		      CGI::div( {class=>'ResultsWithError'},
				"There is NO undo for this function.  
				 Do not use it unless you know what you are doing!  When you unassign
				 sets using this button, or by unchecking their set names, you destroy all
				 of the data for those sets for this student.",
				CGI::br(),
				CGI::submit({name=>"unassignFromAll", value=>"Unassign All Sets"}),
				CGI::radio_group(-name=>"unassignFromAllSafety", -values=>[0,1], -default=>0, -labels=>{0=>'Read only', 1=>'Allow unassign'}),
				  ),
				  CGI::hr(),
	);

	print CGI::end_form();
	
	return "";
}

sub title {  
        my ($self) = @_;  
        my $r = $self->{r};  
        my $userID = $r->urlpath->arg("userID");  
  
        return "Assigned Sets for user $userID";  
}

1;
