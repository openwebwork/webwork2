################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/Index.pm,v 1.31 2004/03/23 01:55:14 sh002i Exp $
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

package WeBWorK::ContentGenerator::Instructor::Index;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Index - Menu interface to the Instructor
pages

=cut

use strict;
use warnings;
use Apache::Constants qw(:response);
use CGI qw();
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;

use constant E_NO_USERS     => "Please do not select any users.";
use constant E_NO_SETS      => "Please do not select any sets.";
use constant E_MAX_ONE_USER => "Please select at most one user.";
use constant E_MAX_ONE_SET  => "Please select at most one set.";
use constant E_ONE_USER     => "Please select exactly one user.";
use constant E_ONE_SET      => "Please select exactly one set.";
use constant E_MIN_ONE_USER => "Please select at least one user.";
use constant E_MIN_ONE_SET  => "Please select at least one set.";

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	unless ($authz->hasPermissions($r->param("user"), "modify_student_data")) {
		$self->{submitError} = "You are not authorized to modify student data";
		return;
	}
	
	my $courseID = $urlpath->arg("courseID");
	my $userID = $r->param("user");
	my $eUserID = $r->param("effectiveUser");
	
	my @selectedUserIDs = $r->param("selected_users");
	my @selectedSetIDs = $r->param("selected_sets");
	
	my $nusers = @selectedUserIDs;
	my $nsets = @selectedSetIDs;
	
	my $firstUserID = $nusers ? $selectedUserIDs[0] : "";
	my $firstSetID = $nsets ? $selectedSetIDs[0] : "";
	
	# these will be used to construct a new URL
	my $module;
	my %args = ( courseID => $courseID );
	my %params;
	
	my $pfx = "WeBWorK::ContentGenerator";
	my $ipfx = "WeBWorK::ContentGenerator::Instructor";
	
	my @error;
	
	# depending on which button was pushed, fill values in for URL construction
	
	defined param $r "sets_assigned_to_user" and do {
		if ($nusers == 1) {
			$module = "${ipfx}::SetsAssignedToUser";
			$args{userID} = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	};
	
	defined param $r "users_assigned_to_set" and do {
		if ($nsets == 1) {
			$module = "${ipfx}::UsersAssignedToSet";
			$args{setID} = $firstSetID;
		} else {
			push @error, E_ONE_SET;
		}
	};
	
	defined param $r "edit_users" and do {
		if ($nusers >= 1) {
			$module = "${ipfx}::UserList";
			$params{visible_users} = \@selectedUserIDs;
			$params{editMode} = 1;
		} else {
			push @error, E_MIN_ONE_USER;
		}
	};
	
	defined param $r "edit_sets" and do {
		if ($nsets == 1) {
			$module = "${ipfx}::ProblemSetEditor";
			$args{setID} = $firstSetID;
		} else {
			push @error, E_ONE_SET;
			
		}
	};
	
	defined param $r "user_stats" and do {
		if ($nusers == 1) {
			$module = "${ipfx}::Stats";
			$args{statType} = "student"; # FIXME: fix URLPath -- i shouldn't have to type this!
			$args{userID} = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	};
	
	defined param $r "set_stats" and do {
		if ($nsets == 1) {
			$module = "${ipfx}::Stats";
			$args{statType} = "set"; # FIXME: fix URLPath -- i shouldn't have to type this!
			$args{setID} = $firstSetID;
		} else {
			push @error, E_ONE_SET;
		}
	};
	
	defined param $r "user_options" and do {
		if ($nusers == 1) {
			$module = "${pfx}::Options";
			$params{effectiveUser} = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	};
	
	defined param $r "score_sets" and do {
		if ($nsets >= 1) {
			$module = "${ipfx}::Scoring";
			$params{selectedSet} = \@selectedSetIDs;
			$params{scoreSelected} = 1;
		} else {
			push @error, E_MIN_ONE_SET;
		}
	};
	
	defined param $r "act_as_user" and do {
		if ($nusers == 1 and $nsets <= 1) {
			if ($nsets) {
				$module = "${pfx}::ProblemSet";
				$args{setID} = $firstSetID;
			} else {
				$module = "${pfx}::ProblemSets";
			}
			$params{effectiveUser} = $firstUserID;
		} else {
			push @error, E_ONE_USER unless $nusers == 1;
			push @error, E_MAX_ONE_SET unless $nsets <= 1;
		}
	};
	
	defined param $r "edit_set_for_user" and do {
		if ($nusers == 1 and $nsets == 1) {
			$module = "${ipfx}::ProblemSetEditor";
			$args{setID} = $firstSetID;
			$params{editForUser} = $firstUserID;
		} else {
			push @error, E_ONE_USER unless $nusers == 1;
			push @error, E_ONE_SET unless $nsets == 1;
			
		}
	};
	
	# handle errors, redirect to target page
	
	if (@error) {
		$self->{error} = \@error;
	} elsif ($module) {
		my $page = $urlpath->newFromModule($module, %args);
		my $url = $self->systemLink($page, params => \%params);
		$self->reply_with_redirect($url);
	}
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $authz = $r->authz;
	
	return CGI::em("You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($r->param("user"), "access_instructor_tools");
	
	print CGI::p("Use the interface below to quickly access commonly-used
	instructor tools, or select a tool from the list to the left.");
	
	print CGI::p("Select user(s) and/or set(s) below and click the action button
	of your choice.");
	
	if ($self->{error}) {
		my @errors = @{ $self->{error} };
		print CGI::div({class=>"ResultsWithError"},
			CGI::p("Your request could not be fulfilled. Please correct the following errors and try again:"),
			CGI::ul(CGI::li(\@errors)),
		);
	}
	
	my @userIDs = $db->listUsers;
	my @Users = $db->getUsers(@userIDs);
	
	my @globalSetIDs = $db->listGlobalSets;
	my @GlobalSets = $db->getGlobalSets(@globalSetIDs);
	
	my @selected_users = $r->param("selected_users");
	my @selected_sets = $r->param("selected_sets");
	
	my $scrolling_user_list = scrollingRecordList({
			name => "selected_users",
			request => $r,
			default_sort => "lnfn",
			default_format => "lnfn_uid",
			size => 10,
			multiple => 1,
		}, @Users);
	
	my $scrolling_set_list = scrollingRecordList({
		name => "selected_sets",
		request => $r,
		default_sort => "set_id",
		default_format => "set_id",
		size => 10,
		multiple => 1,
	}, @GlobalSets);
	
	print CGI::start_form({method=>"get", action=>$r->uri()});
	print $self->hidden_authen_fields();
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::th("Users"),
			CGI::th("Sets"),
		),
		CGI::Tr(
			CGI::td({style=>"width:50%"}, $scrolling_user_list),
			CGI::td({style=>"width:50%"}, $scrolling_set_list),
		),
		CGI::Tr({class=>"ButtonRow"}, [
			CGI::td([
				CGI::submit("sets_assigned_to_user", "View/edit")." all sets for one <b>user</b>",
				CGI::submit("users_assigned_to_set", "View/edit")." all users for one <b>set</b>",
			]),
			CGI::td([
				CGI::submit("edit_users", "Edit"). " selected <b>users</b>",
				CGI::submit("edit_sets", "Edit"). " one <b>set</b>",
			]),
			CGI::td([
				CGI::submit("user_stats", "View stats"). " for one <b>user</b>",
				CGI::submit("set_stats", "View stats"). " for one <b>set</b>",
			]),
			CGI::td([
				CGI::submit("user_options", "Change password")." for one <b>user</b>",
				CGI::submit("score_sets", "Score"). " selected <b>sets</b>",
			]),
		]),
		CGI::Tr({class=>"ButtonRowCenter"}, [
			CGI::td({colspan=>2,style=>'text-align:center'},
				CGI::submit("act_as_user", "Act as")." one <b>user</b> (on one <b>set</b>)",
			),
			CGI::td({colspan=>2,style=>'text-align:center'},
				CGI::submit("edit_set_for_user", "Edit"). " one <b>set</b> for one <b>user</b>",
			),
		]),
	);
	
	print CGI::end_form();
	
	return "";
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu.

=cut
