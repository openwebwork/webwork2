 ###############################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/Index.pm,v 1.59 2007/08/13 22:59:55 sh002i Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.	 See either the GNU General Public License or the
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
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;
#use WeBWorK::Utils::FilterRecords qw/getFiltersForClass/;

use constant E_NO_USERS     => "Please do not select any users.";
use constant E_NO_SETS      => "Please do not select any sets.";
use constant E_MAX_ONE_USER => "Please select at most one user.";
use constant E_MAX_ONE_SET  => "Please select at most one set.";
use constant E_ONE_USER     => "Please select exactly one user.";
use constant E_ONE_SET      => "Please select exactly one set.";
use constant E_MIN_ONE_USER => "Please select at least one user.";
use constant E_MIN_ONE_SET  => "Please select at least one set.";
use constant E_SET_NAME     => "Please specify a homework set name.";
use constant E_BAD_NAME     => "Please use only letter, digits, -, _ and . in your set name.";

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	my $courseID = $urlpath->arg("courseID");
	my $userID = $r->param("user");
	my $eUserID = $r->param("effectiveUser");
	$self->{courseName} = $courseID;
	# Check permissions
	return unless ($authz->hasPermissions($userID, "access_instructor_tools"));
	
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
			$module = "${ipfx}::UserDetail";
			$args{userID} = $firstUserID;
			$params{fromTools} = 1;
		} else {
			push @error, E_ONE_USER;
		}
	};
	
	defined param $r "users_assigned_to_set" and do {
		if ($nsets == 1) {
			$module = "${ipfx}::UsersAssignedToSet";
			$args{setID} = $firstSetID;
			$params{fromTools} = 1;
		} else {
			push @error, E_ONE_SET;
		}
	};
	
	defined param $r "edit_users" and do {
		if ($nusers >= 1) {
			$module = "${ipfx}::UserList2";
			$params{visible_users} = \@selectedUserIDs;
			$params{editMode} = 1;
		} else {
			push @error, E_MIN_ONE_USER;
		}
	};
	
	defined param $r "edit_sets" and do {
		if ($nsets == 1) {
			$module = "${ipfx}::ProblemSetDetail2";
			$args{setID} = $firstSetID;
		} else {
			push @error, E_ONE_SET;
			
		}
	};
	
	defined param $r "prob_lib" and do {
		if ($nsets == 1) {
					$module = "${ipfx}::SetMaker";
			$params{local_sets} = $firstSetID;
		} elsif ($nsets == 0) {
				$module = "${ipfx}::SetMaker";
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
	
	defined param $r "user_progress" and do {
		if ($nusers == 1) {
			$module = "${ipfx}::StudentProgress";
			$args{statType} = "student"; # FIXME: fix URLPath -- i shouldn't have to type this!
			$args{userID} = $firstUserID;
		} else {
			push @error, E_ONE_USER;
		}
	};
	
	defined param $r "set_progress" and do {
		if ($nsets == 1) {
			$module = "${ipfx}::StudentProgress";
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
	
	defined param $r "assign_users" and do {
		if ($nusers >= 1 and $nsets >= 1) {
			$module = "${ipfx}::Assigner";
			$params{selected_users} = \@selectedUserIDs;
			$params{selected_sets} = \@selectedSetIDs;
			$params{assign} = "Assign selected sets to selected users";
		} else {
			push @error, E_MIN_ONE_USER unless $nusers >= 1;
			push @error, E_MIN_ONE_SET unless $nsets >= 1;
		}
	};
	
	defined param $r "act_as_user" and do {
		if ($nusers == 1 and $nsets <= 1) {
			if ($nsets) {
				# unfortunately, we need to know what
				#    type of set it is to figure out
				#    the correct module
				my $set = $db->getGlobalSet( $firstSetID );
				if ( defined( $set ) &&
				     $set->assignment_type =~ /gateway/ ) {
					$module = "${pfx}::GatewayQuiz";
				} else {
					$module = "${pfx}::ProblemSet";
				}
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
	
	defined param $r "edit_set_for_users" and do {
		if ($nusers >= 1 and $nsets == 1) {
			$module = "${ipfx}::ProblemSetDetail2";
			$args{setID} = $firstSetID;
			$params{editForUser} = \@selectedUserIDs;
		} else {
			push @error, E_MIN_ONE_USER unless $nusers >= 1;
			push @error, E_ONE_SET unless $nsets == 1;
			
		}
	};
	
	defined param $r "create_set" and do {
	  my $setname = $r->param("new_set_name");
	  if ($setname && $setname ne 'Name for new set here') {
		if ($setname =~ /^[\w.-]*$/) {
		$module = "${ipfx}::SetMaker";
		$params{new_local_set} = "Create a New Set in this Course";
		$params{new_set_name} = $setname;
		$params{selfassign} = 1;
		  } else {
		push @error, E_BAD_NAME;
		  }
	  } else {
		push @error, E_SET_NAME;
	  }
	};

	defined param $r "add_users" and do {
		$module = "${ipfx}::AddUsers";
	};

	defined param $r "email_users" and do {
		$module = "${ipfx}::SendMail";
	};

	defined param $r "transfer_files" and do {
		$module = "${ipfx}::FileManager";
	};

	push @error, "You are not allowed to act as a student." 
		if (defined param $r "act_as_user" and not $authz->hasPermissions($userID, "become_student"));
	push @error, "You are not allowed to modify homework sets." 
		if ((defined param $r "edit_sets" or defined param $r "edit_set_for_users") and not $authz->hasPermissions($userID, "modify_problem_sets"));
	push @error, "You are not allowed to assign homework sets."
		if ((defined param $r "sets_assigned_to_user" or defined param $r "users_assigned_to_set") and not $authz->hasPermissions($userID, "assign_problem_sets"));
	push @error, "You are not allowed to modify student data."
		if ((defined param $r "edit_users" or defined param $r "user_options" or defined param $r "user_options") and not $authz->hasPermissions($userID, "modify_student_data"));
	push @error, "You are not allowed to score sets."
		if (defined param $r "score_sets" and not $authz->hasPermissions($userID, "score_sets"));
	
	# handle errors, redirect to target page
	if (@error) {
		$self->addbadmessage(CGI::p(join(CGI::br(),@error)));

	} elsif ($module) {
		my $page = $urlpath->newFromModule($module, $r, %args);
		my $url = $self->systemLink($page, params => \%params);
		$self->reply_with_redirect($url);
	}
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $courseName = $self->{courseName};
	my $user = $r->param("user");
	
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	print CGI::p({},$r->maketext("Use the interface below to quickly access commonly-used instructor tools, or select a tool from the list to the left."), CGI::br(),
	$r->maketext("Select user(s) and/or set(s) below and click the action button of your choice."));
	
	# DBFIXME shouldn't need to use list of IDs, use iterator for results, marks edits in WHERE clause
	# the grep here prevents set-level proctors from being displayed here
	my @userIDs = grep {$_ !~ /^set_id:/} $db->listUsers;
	my @Users = $db->getUsers(@userIDs);

## Mark's Edits for filtering
	my @myUsers;
	
	my (@viewable_sections,@viewable_recitations);
	
	if (defined $ce->{viewable_sections}->{$user})
		{@viewable_sections = @{$ce->{viewable_sections}->{$user}};}
	if (defined $ce->{viewable_recitations}->{$user})
		{@viewable_recitations = @{$ce->{viewable_recitations}->{$user}};}

	if (@viewable_sections or @viewable_recitations){
		foreach my $student (@Users){
			my $keep = 0;
			foreach my $sec (@viewable_sections){
				if ($student->section() eq $sec){$keep = 1;}
			}
			foreach my $rec (@viewable_recitations){
				if ($student->recitation() eq $rec){$keep = 1;}
			}
			if ($keep) {push @myUsers, $student;}
		}
		@Users = @myUsers;
	}
## End Mark's Edits

	# DBFIXME shouldn't need to use list of IDs, use iterator for results
	my @globalSetIDs = $db->listGlobalSets;
	my @GlobalSets = $db->getGlobalSets(@globalSetIDs);
	
	my @selected_users = $r->param("selected_users");
	my @selected_sets = $r->param("selected_sets");
	
	my $scrolling_user_list = scrollingRecordList({
			name => "selected_users",
			request => $r,
			default_sort => "lnfn",
			default_format => "lnfn_uid",
			default_filters => ["all"],
			size => 10,
			multiple => 1,
		}, @Users);
	
	my $scrolling_set_list = scrollingRecordList({
		name => "selected_sets",
		request => $r,
		default_sort => "set_id",
		default_format => "sid",
		default_filters => ["all"],
		size => 10,
		multiple => 1,
	}, @GlobalSets);
	
	print CGI::start_form({method=>"get", id=>"instructor-tools-form", action=>$r->uri()});
	print $self->hidden_authen_fields();
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th($r->maketext("Users")),
			CGI::th($r->maketext("Sets")),
		),
		CGI::Tr({},
			CGI::td({style=>"width:50%"}, $scrolling_user_list),
			CGI::td({style=>"width:50%"}, $scrolling_set_list),
		),
		CGI::Tr({class=>"ButtonRow"}, [
			CGI::td([
				CGI::submit(-name=>"sets_assigned_to_user", -label=>$r->maketext("View/Edit"))." ".$r->maketext("all set dates for one <b>user</b>"),
				CGI::submit(-name=>"users_assigned_to_set", -label=>$r->maketext("View/Edit"))." ".$r->maketext("all users for one <b>set</b>"),
			]),
			CGI::td([
				CGI::submit(-name=>"edit_users", -label=>$r->maketext("Edit")). " ".$r->maketext("class list data for selected <b>users</b>"),
				CGI::submit(-name=>"edit_sets", -label=>$r->maketext("Edit")). " ".$r->maketext("one <b>set</b>") . "&nbsp; &nbsp; ".
				$r->maketext("or")." ".CGI::submit(-name=>"prob_lib",-label=>$r->maketext("add problems"))." ".$r->maketext("to one <b>set</b>"),
			]),
			CGI::td([
				CGI::submit(-name=>"user_stats", -label=>$r->maketext("Statistics"))." ".$r->maketext("or")." ".
				CGI::submit(-name=>"user_progress", -label=>$r->maketext("progress"))." ".$r->maketext("for one <b>user</b>"),
				CGI::submit(-name=>"set_stats", -label=>$r->maketext("Statistics"))." ".$r->maketext("or")." ".
				CGI::submit(-name=>"set_progress", -label=>$r->maketext("progress"))." ".$r->maketext("for one <b>set</b>"),
			]),
			CGI::td([
				CGI::submit(-name=>"user_options", -label=>$r->maketext("Change Password"))." ".$r->maketext("for one <b>user</b>"),
				CGI::submit(-name=>"score_sets", -label=>$r->maketext("Score"))." ".$r->maketext("selected <b>sets</b>"),
			]),
			CGI::td([
				CGI::submit(-name=>"add_users", -label=>$r->maketext("Add"))." ".$r->maketext("new users"),
				CGI::submit(-name=>"create_set", -label=>$r->maketext("Create")). " ".$r->maketext("new set:")." ".
				   CGI::textfield(-name=>"new_set_name", 
					   -default=>$r->maketext("Name for new set here"),
					   -override=>1, -size=>20),
				]),
		]),
		CGI::Tr({class=>"ButtonRowCenter"},
			CGI::td({-colspan=>2, align=>"center"},
				CGI::table({-border=>0, align=>"center"},
					CGI::Tr({-align=>"left"}, [
						CGI::td({-height=>2}),
						CGI::td(CGI::submit(-name=>"assign_users", -label=>$r->maketext("Assign"))." ".$r->maketext("selected <b>users</b> to selected <b>sets</b>")),
						CGI::td(CGI::submit(-name=>"act_as_user", -label=>$r->maketext("Act as"))." ".$r->maketext("one <b>user</b> (on one <b>set</b>)")),
						CGI::td(CGI::submit(-name=>"edit_set_for_users", -label=>$r->maketext("Edit")). " ".$r->maketext("one <b>set</b> for  <b>users</b>")),
						CGI::td({-height=>4}),
						CGI::td(CGI::submit(-name=>"email_users", -label=>"Email"). " ".$r->maketext("your students")),
						($authz->hasPermissions($user, "manage_course_files")
							? CGI::td(CGI::submit(-name=>"transfer_files", -label=>$r->maketext("Transfer")). " ".$r->maketext("course files"))
							: ()
						),
					])
				)
			)
		),
	);
	
	print CGI::end_form();
	
	return "";
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu.

=cut
