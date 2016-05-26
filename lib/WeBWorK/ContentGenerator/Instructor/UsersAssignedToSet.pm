################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/UsersAssignedToSet.pm,v 1.23 2006/09/25 22:14:53 sh002i Exp $
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

package WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UsersAssignedToSet - List and edit the
users to which sets are assigned.

=cut

use strict;
use warnings;
use CGI qw(-nosticky );
use WeBWorK::Debug;

sub initialize {
	my ($self)     = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $authz      = $r->authz;
	my $db         = $r->db;	
	my $setID      = $urlpath->arg("setID");
	my $user       = $r->param('user');
	
	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");	
	return unless $authz->hasPermissions($user, "assign_problem_sets");
	
	my @users = $db->listUsers;
	my %selectedUsers = map {$_ => 1} $r->param('selected');
	
	my $doAssignToSelected = 0;
	
	# get the global user, if there is one
	my $globalUserID = "";
	$globalUserID = $db->{set}->{params}->{globalUserID}
		if ref $db->{set} eq "WeBWorK::DB::Schema::GlobalTableEmulator";

	if (defined $r->param('assignToAll')) {
		debug("assignSetToAllUsers($setID)");
		$self->addmessage(CGI::div({class=>'ResultsWithoutError'}, $r->maketext("Problems have been assigned to all current users.")));
		$self->assignSetToAllUsers($setID);
		debug("done assignSetToAllUsers($setID)");
	} elsif (defined $r->param('unassignFromAll') and defined($r->param('unassignFromAllSafety')) and $r->param('unassignFromAllSafety')==1) {
		%selectedUsers = ( $globalUserID => 1 );
		$self->addmessage(CGI::div({class=>'ResultsWithoutError'}, $r->maketext("Problems for all students have been unassigned.")));
		$doAssignToSelected = 1;
	} elsif (defined $r->param('assignToSelected')) {
	   	$self->addmessage(CGI::div({class=>'ResultsWithoutError'}, $r->maketext("Problems for selected students have been reassigned.")));
		$doAssignToSelected = 1;
	} elsif (defined $r->param("unassignFromAll")) {
	   # no action taken
	   $self->addmessage(CGI::div({class=>'ResultsWithError'}, $r->maketext("No action taken")));
	}
	
	if ($doAssignToSelected) {
		my $setRecord = $db->getGlobalSet($setID); #checked
		die "Unable to get global set record for $setID " unless $setRecord;
		
		my %setUsers = map { $_ => 1 } $db->listSetUsers($setID);
		foreach my $selectedUser (@users) {
			if (exists $selectedUsers{$selectedUser}) {
				unless ($setUsers{$selectedUser}) {	# skip users already in the set
					debug("assignSetToUser($selectedUser, ...)");
					$self->assignSetToUser($selectedUser, $setRecord);
					debug("done assignSetToUser($selectedUser, ...)");
				}
			} else {
				next if $selectedUser eq $globalUserID;
				next unless $setUsers{$selectedUser};	# skip users not in the set
				$db->deleteUserSet($selectedUser, $setID);
			}
		}
	}
}

sub getSetName {
	my ($self, $pathSetName) = @_;
	if (ref $pathSetName eq "HASH") {
		$pathSetName = undef;
	}
	return $pathSetName;
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
	my $user           = $r->param('user');

	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to acces the Instructor tools."))
		unless $authz->hasPermissions($user, "access_instructor_tools");
		
	return CGI::div({class=>"ResultsWithError"}, CGI::p("You are not authorized to assign homework sets."))
		unless $authz->hasPermissions($user, "assign_problem_sets");	
	
	# DBFIXME duplicate call
	my @users = $db->listUsers;
	print CGI::start_form({id=>"user-set-form", name=>"user-set-form", method=>"post", action => $self->systemLink( $urlpath, authen=>0) });
	 
	print CGI::p(
		    CGI::submit({name=>"assignToAll", value => $r->maketext("Assign to All Current Users")}), CGI::i($r->maketext("This action can take a long time if there are many students."))
		  ),
		  CGI::div({-class=>"ResultsWithError"}, $r->maketext("Do not uncheck students, unless you know what you are doing."),CGI::br(),
	           $r->maketext("There is NO undo for unassigning students.")),
	      CGI::p($r->maketext("When you unassign by unchecking a student's name, you destroy all of the data for homework set [_1] for this student. You will then need to reassign the set to these students and they will receive new versions of the problems. Make sure this is what you want to do before unchecking students.", CGI::b($setID))
	);
				        
	print CGI::start_table({});
	print CGI::Tr({-valign=>"top"}, CGI::th([$r->maketext("Assigned"),$r->maketext("Login Name"),"&nbsp;",$r->maketext("Student Name"),"&nbsp;",$r->maketext("Section"),"&nbsp;",$r->maketext("Close Date")]));
	print CGI::Tr(CGI::td([CGI::hr(),CGI::hr(),"",CGI::hr(),"",CGI::hr(),"",CGI::hr(),"&nbsp;"]));

	# get user records
	my @userRecords  = ();
	foreach my $currentUser ( @users) {
		my $userObj = $db->getUser($currentUser); #checked
		die "Unable to find user object for $currentUser. " unless $userObj;
		push (@userRecords, $userObj );
	}
	@userRecords = sort { ( lc($a->section) cmp lc($b->section) ) || 
	                     ( lc($a->last_name) cmp lc($b->last_name )) } @userRecords;
	
	# get the global user, if there is one
	my $globalUserID = "";
	$globalUserID = $db->{set}->{params}->{globalUserID}
		if ref $db->{set} eq "WeBWorK::DB::Schema::GlobalTableEmulator";

	# there are two set detail pages.  If we were sent here from the second one
	# there will be a parameter we can use to get back to that one from these links
	my $detailPageType = 'instructor_set_detail2';
       	$detailPageType = $r->param('pageVersion') if ($r->param('pageVersion'));

	foreach my $userRecord (@userRecords) {

		my $statusClass = $ce->status_abbrev_to_name($userRecord->status) || "";

		my $user = $userRecord->user_id;
		my $userSetRecord = $db->getUserSet($user, $setID); #checked
		# don't need to check here, undefined values are handled below
		#die "Unable to find record for user $user and set $setID " unless $userSetRecord;
		my $prettyName = $userRecord->last_name
			. ", "
			. $userRecord->first_name;
		my $dueDate    = $userSetRecord->due_date if ref($userSetRecord);
		my $prettyDate = ($dueDate)?  '(' . $self->formatDateTime($dueDate) . ') ' : '';
		print CGI::Tr({}, 
			CGI::td({-align=>"center"},
				($user eq $globalUserID
					? "" # no checkbox for global user!
					: CGI::checkbox({
						type=>"checkbox",
						name=>"selected",
						checked=>(
							defined($userSetRecord) # && $statusClass ne "Drop"
							? "on"
							: ""
						),
						value=>$user,
						label=>"",
					})
				)
			),CGI::td({},[
				CGI::div({class=>$statusClass}, $user),
				"",
				"($prettyName)", " ", $userRecord->section, " ",
				(
					defined $userSetRecord
###					? $prettyDate . CGI::a(
					? ($prettyDate, "", CGI::a(
						{href=>$self->systemLink($urlpath->new(type =>$detailPageType,
						                                       args =>{courseID => $courseName,
						                                               setID    => $setID
						                                       }),
						                         params =>{editForUser=> $user}
						)},
						"",
						$r->maketext("Edit data for [_1]",$user)
					))
					: ()
				),
			])
		);
	}
	print CGI::Tr(CGI::td([CGI::hr(),CGI::hr(),"",CGI::hr(),"",CGI::hr(),"",CGI::hr()]));
	print CGI::end_table();
	print $self->hidden_authen_fields;
	print CGI::submit({name=>"assignToSelected", value=>$r->maketext("Save")});
	print CGI::p( CGI::hr(),
				  CGI::div( {class=>'ResultsWithError'},
					   $r->maketext("There is NO undo for this function.  Do not use it unless you know what you are doing!  When you unassign a student using this button, or by unchecking their name, you destroy all of the data for homework set $setID for this student."),
						CGI::br(),
						CGI::submit({name=>"unassignFromAll", value=>$r->maketext("Unassign from All Users")}),
						CGI::radio_group(-name=>"unassignFromAllSafety", -values=>[0,1], -default=>0, -labels=>{0=>$r->maketext('Read only'), 1=>$r->maketext('Allow unassign')}),
				  ),
				  CGI::hr(),
	);
	print CGI::end_form();
	
	return "";
}

1;
