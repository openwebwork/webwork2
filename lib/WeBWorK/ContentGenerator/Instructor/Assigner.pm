################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/Assigner.pm,v 1.7 2003/12/09 01:12:31 sh002i Exp $
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

package WeBWorK::ContentGenerator::Instructor::Assigner;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Assigner - Assign problem sets to users

=cut

use strict;
use warnings;
use CGI qw();

sub initialize {
	my ($self, $setID) = @_;
	my $r = $self->{r};
	my $authz = $self->{authz};
	my $db = $self->{db};
	my $user = $r->param('user');
	
	unless ($authz->hasPermissions($user, "assign_problem_sets")) {
		$self->{submitError} = "You are not authorized to assign problem sets";
		return;
	}
	
	my @users = $db->listUsers;
	my %selectedUsers = map {$_ => 1} $r->param('selected');
	
	if (defined $r->param('assignToAll')) {
		$self->assignSetToAllUsers($setID);
	} elsif (defined $r->param('assignToSelected')) {
		my $setRecord = $db->getGlobalSet($setID); #checked
		die "Unable to get global set record for $setID " unless $setRecord;
		foreach my $selectedUser (@users) {
			if (exists $selectedUsers{$selectedUser}) {
				$self->assignSetToUser($selectedUser, $setRecord)
			} else {
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

sub path {
	my $self          = shift;
    my @components    = @_;
	my $args          = $_[-1];
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $set_id    = $self->getSetName($components[0]);
	return $self->pathMacro($args,
		"Home"          => "$root",
		$courseName     => "$root/$courseName",
		'instructor'    => "$root/$courseName/instructor",
		'sets'          => "$root/$courseName/instructor/sets/",
		"$set_id"   => "$root/$courseName/instructor/sets/$set_id",
		"assign"      => ''
	);
}

sub title {
	my ($self, @components) = @_;
	return "Assign problems to students - ".$self->{ce}->{courseName}." : ".$self->getSetName(@components);
}

sub body {
	my ($self, $setID) = @_;
	my $r = $self->{r};
	my $authz = $self->{authz};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $webworkRoot = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $user = $r->param('user');
	
        return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");

	my @users = $db->listUsers;
	print CGI::start_form({method=>"post", action=>$r->uri});
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

	foreach my $userRecord (@userRecords) {
		my $user = $userRecord->user_id;
		my $userSetRecord = $db->getUserSet($user, $setID); #checked
		die "Unable to find record for user $user and set $setID " unless $userSetRecord;
		my $prettyName = $userRecord->last_name
			. ", "
			. $userRecord->first_name;
		print CGI::Tr({}, 
			CGI::td({}, [
				CGI::checkbox({
					type=>"checkbox",
					name=>"selected",
					checked=>(
						defined $userSetRecord
						? "on"
						: ""
					),
					value=>$user,
					label=>"",
				}),
				$user,
				"($prettyName)", " ", $userRecord->section, " ",
				(
					defined $userSetRecord
					? CGI::a(
						{href=>$ce->{webworkURLs}->{root}."/$courseName/instructor/sets/$setID/?editForUser=$user&".$self->url_authen_args()},
						"Edit user-specific set data for $user"
					)
					: ()
				),
			])
		);
	}
	print CGI::end_table();
	print $self->hidden_authen_fields;
	print CGI::submit({name=>"assignToSelected", value=>"Save"});
	print CGI::br();
	print CGI::br();
	print CGI::submit({name=>"assignToAll", value=>"Assign to All Users"});
	print CGI::end_form();
	
	return "";
}

1;
