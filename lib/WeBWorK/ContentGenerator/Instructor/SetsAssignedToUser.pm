################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/SetsAssignedToUser.pm,v 1.14 2004/05/11 20:51:42 toenail Exp $
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
use CGI qw();
use WeBWorK::Utils qw(formatDateTime);

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
	} elsif (defined $r->param("unassignFromAll")) {
		if ($userID ne $globalUserID) {
			$self->unassignAllSetsFromUser($userID);
		}
	} elsif (defined $r->param('assignToSelected')) {
		# get list of all sets and a hash for checking selectedness
		my @setIDs = $db->listGlobalSets;
		my %selectedSets = map { $_ => 1 } $r->param("selected");
		
		# get current user
		my $User = $db->getUser($userID); # checked
		die "record not found for $userID.\n" unless $User;
		
		unless ($User->user_id eq $globalUserID) {
			# go through each possible set
			foreach my $setID (@setIDs) {
				# does the user want it to be assigned to the selected user
				if (exists $selectedSets{$setID}) {
					# user asked to have the set assigned to the selected user
					my $Set = $db->getGlobalSet($setID); #checked
					if ($Set) {
						$self->assignSetToUser($userID, $Set);
					} else {
						warn "global set $setID appeared in listGlobalSets() but does not exist.\n"
					}
				} else {
					# user asked to NOT have the set assigned to the selected user
					# this will unassign it if it is assigned
					$db->deleteUserSet($userID, $setID);
				}
			}
		}
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
	my $setsAssignedToUserPage    = $urlpath->newFromModule($urlpath->module,
	                                                        courseID =>  $courseName,
	                                                        userID=>$userID
	);
	my $setsAssignedToUserURL     = $self->systemLink($setsAssignedToUserPage,authen=>0);

	# check authorization
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to access the Instructor tools."))
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to assign problem sets."))
		unless $authz->hasPermissions($user, "assign_problem_sets");
	
	# get list of sets
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
	
	
	print CGI::start_form({method=>"post", action=>$setsAssignedToUserURL});
	print $self->hidden_authen_fields;
	
	# get the global user, if there is one
	my $globalUserID = "";
	$globalUserID = $db->{set}->{params}->{globalUserID}
		if ref $db->{set} eq "WeBWorK::DB::Schema::GlobalTableEmulator";
	
	if ($userID ne $globalUserID) {
		print CGI::p(
			CGI::submit({name=>"assignToAll", value=>"Assign all sets"}),
			CGI::submit({name=>"unassignFromAll", value=>"Unassign all sets"}),
		);
	}
	
	print CGI::start_table({});
	
	foreach my $Set (@Sets) {
		my $setID = $Set->set_id;
		
		# this is true if $Set is assigned to the selected user
		my $UserSet = $db->getUserSet($userID, $setID); # checked
		my $currentlyAssigned = defined $UserSet;
		
		my $prettyDate = formatDateTime($Set->due_date);
		if ($currentlyAssigned and $UserSet->due_date) {
			$prettyDate = formatDateTime($UserSet->due_date);
		}
		
		# URL to edit user-specific set data
# 		my $url = $ce->{webworkURLs}->{root}
# 			. "/$courseName/instructor/sets/$setID/?editForUser=$userID&"
# 			. $self->url_authen_args();
        my $setListPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::ProblemSetEditor",
                                                   courseID => $courseName,
                                                   setID    => $setID
        );
		my $url = $self->systemLink($setListPage,params =>{editForUser => $userID});
		print CGI::Tr({}, 
			CGI::td({}, [
				($userID eq $globalUserID
					? "" # no checkboxes for global user!
					: CGI::checkbox({
						type=>"checkbox",
						name=>"selected",
						checked=>$currentlyAssigned,
						value=>$setID,
						label=>"",
					})
				),
				$setID,
				"($prettyDate)",
				" ",
				$currentlyAssigned
					? CGI::a({href=>$url}, "Edit user-specific set data")
					: (),
			])
		);
	}
	print CGI::end_table();
	print CGI::submit({name=>"assignToSelected", value=>"Save"});
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
