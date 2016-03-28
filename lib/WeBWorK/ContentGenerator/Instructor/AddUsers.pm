################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/AddUsers.pm,v 1.24 2007/08/13 22:59:55 sh002i Exp $
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

package WeBWorK::ContentGenerator::Instructor::AddUsers;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::AddUsers - Menu interface for adding users


=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Utils qw/cryptPassword trim_spaces/;

sub initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	
	my $user = $r->param('user');
	
	# Check permissions
	return unless ($authz->hasPermissions($user, "access_instructor_tools"));
	return unless ($authz->hasPermissions($user, "modify_student_data"));
	
	if (defined($r->param('addStudents'))) {
		my @userIDs;
		my $numberOfStudents    = $r->param('number_of_students');
		warn "Internal error -- the number of students to be added has not been included" unless defined $numberOfStudents;
		foreach my $i (1..$numberOfStudents) {
		    my $new_user_id  = trim_spaces($r->param("new_user_id_$i"));
		    my $new_password = cryptPassword($r->param("student_id_$i"));
		    next unless defined($new_user_id) and $new_user_id;
			push @userIDs, $new_user_id;
		    
			my $newUser            = $db->newUser;
			my $newPermissionLevel = $db->newPermissionLevel;
			my $newPassword        = $db->newPassword;
			$newUser->user_id($new_user_id);
			$newPermissionLevel->user_id($new_user_id);
			$newPassword->user_id($new_user_id);
			$newPassword->password($new_password);
			$newUser->last_name(trim_spaces($r->param("last_name_$i")));
			$newUser->first_name(trim_spaces($r->param("first_name_$i")));
			$newUser->student_id(trim_spaces($r->param("student_id_$i")));
			$newUser->email_address(trim_spaces($r->param("email_address_$i")));
			$newUser->section(trim_spaces($r->param("section_$i")));
			$newUser->recitation(trim_spaces($r->param("recitation_$i")));
			$newUser->comment(trim_spaces($r->param("comment_$i")));
			$newUser->status($ce->status_name_to_abbrevs($ce->{default_status}));
			$newPermissionLevel->permission(0);
			#FIXME  handle errors if user exists already
			eval { $db->addUser($newUser) };
			if ($@) {
				my $addError = $@;
				$self->{studentEntryReport} .= join("",
					CGI::b($r->maketext("Failed to enter student:")), ' ', $newUser->last_name, ", ",$newUser->first_name,
					CGI::b(", ".$r->maketext("login/studentID:")),' ', $newUser->user_id, "/",$newUser->student_id,
					CGI::b(", ".$r->maketext("email:")),' ', $newUser->email_address,
					CGI::b(", ".$r->maketext("section:")),' ', $newUser->section,
					CGI::br(), CGI::b($r->maketext("Error message:")), ' ', $addError,
					CGI::hr(),CGI::br(),
				);
			} else {
				$db->addPermissionLevel($newPermissionLevel);
				$db->addPassword($newPassword);
				$self->{studentEntryReport} .= join("",
					CGI::b($r->maketext("Entered student:")), ' ', $newUser->last_name, ", ",$newUser->first_name,
					CGI::b(", ",$r->maketext("login/studentID:")),' ', $newUser->user_id, "/",$newUser->student_id,
					CGI::b(", ",$r->maketext("email:")),' ', $newUser->email_address,
					CGI::b(", ",$r->maketext("section:")),' ', $newUser->section,CGI::hr(),CGI::br(),

				);
			}
		}
		if (defined $r->param("assignSets")) {
			my @setIDs = $r->param("assignSets");
			if (@setIDs) {
				$self->assignSetsToUsers(\@setIDs, \@userIDs);
			}
		}
	}
}

sub body {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;
	my $authz  = $r->authz;
	
	my $courseName = $r->urlpath->arg("courseID");
	my $authen_args = $self->url_authen_args();
	my $user = $r->param('user');
	
	# Check permissions
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to access the Instructor tools.")
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	return CGI::div({class=>"ResultsWithError"}, "You are not authorized to modify student data.")
		unless $authz->hasPermissions($user, "modify_student_data");

	
	return join("", 
	
		CGI::hr(),
		CGI::p(
			defined($self->{studentEntryReport})
				? $self->{studentEntryReport}
				: ''
		),
		CGI::p($r->maketext("Enter information below for students you wish to add. Each student's password will initially be set to their student ID.")),
		$self->addStudentForm,
	);
}

sub addStudentForm {
	my $self                  = shift;
	my $r                     = $self->r;
	my $db                    = $r->db;
	my $ce                    = $r->ce;
	my $numberOfStudents      = $r->param("number_of_students") || 5;
	

	
	# Add a student form
	
	my @entryLines = ();
	foreach my $i (1..$numberOfStudents) {
		push( @entryLines, 		
			CGI::Tr({},
				CGI::td({},
					[ CGI::input({type=>'text', class=>"last-name-input", name=>"last_name_$i"}),
					  CGI::input({type=>'text', class=>"first-name-input", name=>"first_name_$i"}),
					  CGI::input({type=>'text', class=>"student-id-input", name=>"student_id_$i",size=>"16",'aria-required'=>'true'}),
					  CGI::input({type=>'text', class=>"user-id-input", name=>"new_user_id_$i",size=>"10",'aria-required'=>'true'}),
					  CGI::input({type=>'text', class=>"email-input", name=>"email_address_$i"}),
					  CGI::input({type=>'text', class=>"section-input", name=>"section_$i",size=>"10"}),
					  CGI::input({type=>'text', class=>"recitation-input", name=>"recitation_$i",size=>"10"}),
					  CGI::input({type=>'text', class=>"comment-input", name=>"comment_$i"}),
					]
				)
			),"\n",
		);
	}

	return join("",		
		CGI::start_form({method=>"post", action=>$r->uri(),name=>"add_users"}),
		$self->hidden_authen_fields(),"\n",
		CGI::submit(-name=>"Create", -value=>$r->maketext("Create")),"&nbsp;&nbsp;","\n",
		CGI::input({type=>'text', name=>'number_of_students', value=>$numberOfStudents,size => 3}), " ".$r->maketext("entry rows."),"\n",
		CGI::end_form(),"\n",
		CGI::hr(),
		
		CGI::start_form({method=>"post", action=>$r->uri(), name =>"new-users-form", id=>"new-users-form"}),
		$self->hidden_authen_fields(),
		CGI::input({type=>'hidden', name => "number_of_students", value => $numberOfStudents}),
		CGI::start_table({border=>'1', cellpadding=>'2'}),
		CGI::Tr({},
			CGI::th({},
				[$r->maketext('Last Name'), $r->maketext('First Name'), $r->maketext('Student ID').CGI::span({class=>"required-field"},'*'), $r->maketext('Login Name').CGI::span({class=>"required-field"},'*'), $r->maketext('Email Address'), $r->maketext('Section'),$r->maketext('Recitation'), $r->maketext('Comment')]
			)
		),
		@entryLines,
		CGI::end_table(),    
		

		
		CGI::p($r->maketext("Select sets below to assign them to the newly-created users.")),
		CGI::scrolling_list(
			-name     => "assignSets",
			-values   => [ $db->listGlobalSets ],
			-size     => 10,
			-multiple => "1",
		),
		CGI::p(
			CGI::submit({name=>"addStudents", value=>$r->maketext("Add Students")}),
		),
		CGI::end_form(),		

	);
}




1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu

=cut
