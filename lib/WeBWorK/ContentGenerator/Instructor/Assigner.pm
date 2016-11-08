################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/Assigner.pm,v 1.37 2006/09/25 22:14:53 sh002i Exp $
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

WeBWorK::ContentGenerator::Instructor::Assigner - Assign homework sets to users.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $authz = $r->authz;
	my $ce = $r->ce;
	my $user = $r->param('user');
	
	# Permissions dealt with in the body
	return "" unless $authz->hasPermissions($user, "access_instructor_tools");
	return "" unless $authz->hasPermissions($user, "assign_problem_sets");

	my @selected_users = $r->param("selected_users");
	my @selected_sets = $r->param("selected_sets");
	
	if (defined $r->param("assign") || defined $r->param("unassign")) {
		if  (@selected_users && @selected_sets) {
			my @results;  # This is not used?
			if(defined $r->param("assign")) {
				$self->assignSetsToUsers(\@selected_sets, \@selected_users);
				$self->addgoodmessage($r->maketext('All assignments were made successfully.'));
			}
			if (defined $r->param("unassign")) {
				if(defined $r->param('unassignFromAllSafety') and $r->param('unassignFromAllSafety')==1) {
					$self->unassignSetsFromUsers(\@selected_sets, \@selected_users) if(defined $r->param("unassign"));
					$self->addgoodmessage($r->maketext('All unassignments were made successfully.'));
				} else { # asked for unassign, but no safety radio toggle
					$self->addbadmessage($r->maketext('Unassignments were not done.  You need to both click to "Allow unassign" and click on the Unassign button.'));
				}
			}
			
			if (@results) { # Can't get here?
				$self->addbadmessage(
					"The following error(s) occured while assigning:".
					CGI::ul(CGI::li(\@results))
				);
			}
		} else {
			$self->addbadmessage("You must select one or more users below.")
				unless @selected_users;
			$self->addbadmessage("You must select one or more sets below.")
				unless @selected_sets;
		}
	}
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $authz = $r->authz;
	my $ce = $r->ce;
	
	my $user = $r->param('user');
	
	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to assign homework sets.")
		unless $authz->hasPermissions($user, "assign_problem_sets");

	
	print CGI::p($r->maketext("Select one or more sets and one or more users below to assign/unassign each selected set to/from all selected users."));
	
	# DBFIXME shouldn't have to get the user id list
	# DBFIXME mark's filtering should happen in a WHERE clause
	my @userIDs = $db->listUsers;
	my @Users = $db->getUsers(@userIDs);
## Mark's Edits for filtering
	my @myUsers;

	
	my (@viewable_sections, @viewable_recitations);
	
	if (defined($ce->{viewable_sections}->{$user}))
		{@viewable_sections = @{$ce->{viewable_sections}->{$user}};}
	if (defined($ce->{viewable_recitations}->{$user}))
		{@viewable_recitations = @{$ce->{viewable_recitations}->{$user}};}
	if (@viewable_sections or @viewable_recitations){
		foreach my $student (@Users){
			my $keep = 0;
			foreach my $sec (@viewable_sections){
				if ($student->section() eq $sec){$keep = 1;}
			}
			foreach my $rec (@viewable_recitations){
				if ($student->section() eq $rec){$keep = 1;}
			}
			if ($keep) {push @myUsers, $student;}
		}
		@Users = @myUsers;
	}
## End Mark's Edits

	
	# DBFIXME shouldn't have to get the set ID list
	my @globalSetIDs = $db->listGlobalSets;
	my @GlobalSets = $db->getGlobalSets(@globalSetIDs);
	
	my $scrolling_user_list = scrollingRecordList({
		name => "selected_users",
		request => $r,
		default_sort => "lnfn",
		default_format => "lnfn_uid",
		default_filters => ["all"],
		size => 20,
		multiple => 1,
	}, @Users);
	
	my $scrolling_set_list = scrollingRecordList({
		name => "selected_sets",
		request => $r,
		default_sort => "set_id",
		default_format => "set_id",
		default_filters => ["all"],
		size => 20,
		multiple => 1,
	}, @GlobalSets);
	
	print CGI::start_form({method=>"post", action=>$r->uri()});
	print $self->hidden_authen_fields();
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::th("Users"),
			CGI::th("Sets"),
		),
		CGI::Tr(
			CGI::td($scrolling_user_list),
			CGI::td($scrolling_set_list),
		),
		CGI::Tr(
			CGI::td({colspan=>2, class=>"ButtonRow"},
				CGI::submit(
					-name => "assign",
					-value => $r->maketext("Assign selected sets to selected users"),
					-style => "width: 45ex",
				),
			),
		),
		CGI::Tr(
			CGI::td({colspan=>2},
				CGI::div({class=>'ResultsWithError', style=>'color:red'},
					 $r->maketext("Do not unassign students unless you know what you are doing."),
					CGI::br(),
					 $r->maketext("There is NO undo for unassigning students."),
					CGI::br(),
					CGI::submit(
						-name => "unassign",
						 -value => $r->maketext("Unassign selected sets from selected users"),
						-style => "width: 45ex",
					),
					CGI::radio_group(-name=>"unassignFromAllSafety", -values=>[0,1], -default=>0, -labels=>{0=>$r->maketext('Assignments only'), 1=>$r->maketext('Allow unassign')}),
				),
			),
		),
	);

	

	print CGI::p("When you unassign a student's name, you destroy all
			of the data for that homework set for that student. You will then need to
			reassign the set(s) to these students and they will receive new versions of the problems.
			Make sure this is what you want to do before unassigning students."
	);
	
	print CGI::end_form();
	
	return "";
}

1;
