################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/UsersAssignedToSet.pm,v 1.4 2004/03/04 21:05:58 sh002i Exp $
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
use CGI qw();
use WeBWorK::Utils qw(formatDateTime);

sub initialize {
	my ($self)     = @_;
	my $r          = $self->r;
    my $urlpath    = $r->urlpath;
	my $authz      = $r->authz;
	my $db         = $r->db;	
	my $setID      = $urlpath->arg("setID");
	my $user       = $r->param('user');
	
	unless ($authz->hasPermissions($user, "assign_problem_sets")) {
		$self->{submitError} = "You are not authorized to assign problem sets";
		return;
	}
	
	my @users = $db->listUsers;
	my %selectedUsers = map {$_ => 1} $r->param('selected');
	
	my $doAssignToSelected = 0;
	
	# get the global user, if there is one
	my $globalUserID = "";
	$globalUserID = $db->{set}->{params}->{globalUserID}
		if ref $db->{set} eq "WeBWorK::DB::Schema::GlobalTableEmulator";

	if (defined $r->param('assignToAll')) {
		$WeBWorK::timer->continue("assignSetToAllUsers($setID)") if defined $WeBWorK::timer;
		$self->assignSetToAllUsers($setID);
		$WeBWorK::timer->continue("done assignSetToAllUsers($setID)") if defined $WeBWorK::timer;
	} elsif (defined $r->param('unassignFromAll')) {
		%selectedUsers = ( $globalUserID => 1 );
		$doAssignToSelected = 1;
	} elsif (defined $r->param('assignToSelected')) {
		$doAssignToSelected = 1;
	}
	
	if ($doAssignToSelected) {
		my $setRecord = $db->getGlobalSet($setID); #checked
		die "Unable to get global set record for $setID " unless $setRecord;
		
		foreach my $selectedUser (@users) {
			if (exists $selectedUsers{$selectedUser}) {
				$WeBWorK::timer->continue("assignSetToUser($selectedUser, ...)") if defined $WeBWorK::timer;
				$self->assignSetToUser($selectedUser, $setRecord);
				$WeBWorK::timer->continue("done assignSetToUser($selectedUser, ...)") if defined $WeBWorK::timer;
			} else {
				next if $selectedUser eq $globalUserID;
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
	
	return CGI::em("You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	my @users = $db->listUsers;
	print CGI::start_form({method=>"post", action=>$r->uri});
	 
	print CGI::p(
		    CGI::submit({name=>"assignToAll", value=>"Assign to All Users"})
		  ),
		  CGI::div({-style=>"color:red"}, "Do not uncheck students, unless you know what you are doing.",CGI::br(),
	           "There is NO undo for unassigning students. "),
	      CGI::p("When you unassign
				        by unchecking a student's name, you destroy all
				        of the data for problem set $setID for this student. You will then need to
				        reassign the set to these students and they will receive new versions of the problems.
				        Make sure this is what you want to do before unchecking students."
	);
				        
	print CGI::start_table({});
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

	foreach my $userRecord (@userRecords) {
		my $user = $userRecord->user_id;
		my $userSetRecord = $db->getUserSet($user, $setID); #checked
		# don't need to check here, undefined values are handled below
		#die "Unable to find record for user $user and set $setID " unless $userSetRecord;
		my $prettyName = $userRecord->last_name
			. ", "
			. $userRecord->first_name;
		my $dueDate    = $userSetRecord->due_date if ref($userSetRecord);
		my $prettyDate = ($dueDate)?  '(' . formatDateTime($dueDate) . ') ' : '';
		print CGI::Tr({}, 
			CGI::td({}, [
				($user eq $globalUserID
					? "" # no checkbox for global user!
					: CGI::checkbox({
						type=>"checkbox",
						name=>"selected",
						checked=>(
							defined $userSetRecord
							? "on"
							: ""
						),
						value=>$user,
						label=>"",
					})
				),
				$user,
				"($prettyName)", " ", $userRecord->section, " ",
				(
					defined $userSetRecord
					? $prettyDate . CGI::a(
						{href=>$ce->{webworkURLs}->{root}."/$courseName/instructor/sets/$setID/?editForUser=$user&".$self->url_authen_args()},
						"Edit data for $user"
					)
					: ()
				),
			])
		);
	}
	print CGI::end_table();
	print $self->hidden_authen_fields;
	print CGI::submit({name=>"assignToSelected", value=>"Save"});
	print CGI::p( CGI::hr(),
				  CGI::div({ style=>"background-color:red"}, "There is NO undo for this function.  
				        Do not use it unless you know what you are doing!  When you unassign
				        a student using this button, or by unchecking their name, you destroy all
				        of the data for problem set $setID for this student.",
				        CGI::submit({name=>"unassignFromAll", value=>"Unassign from All Users"}),
				  ),
				  
				  CGI::hr(),
	);
	print CGI::end_form();
	
	return "";
}

1;
