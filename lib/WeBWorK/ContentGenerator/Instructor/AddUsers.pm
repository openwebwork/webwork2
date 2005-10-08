################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/AddUsers.pm,v 1.18 2005/07/14 13:15:25 glarose Exp $
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
use CGI qw();
use WeBWorK::Utils qw/cryptPassword/;

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
			$newUser->status($ce->status_name_to_abbrev($ce->{default_status}));
			$newPermissionLevel->permission(0);
			#FIXME  handle errors if user exists already
			eval { $db->addUser($newUser) };
			if ($@) {
				my $addError = $@;
				$self->{studentEntryReport} .= join("",
					CGI::b("Failed to enter student: "), $newUser->last_name, ", ",$newUser->first_name,
					CGI::b(", login/studentID: "), $newUser->user_id, "/",$newUser->student_id,
					CGI::b(", email: "), $newUser->email_address,
					CGI::b(", section: "), $newUser->section,
					CGI::br(), CGI::b("Error message: "), $addError,
					CGI::hr(),CGI::br(),
				);
			} else {
				$db->addPermissionLevel($newPermissionLevel);
				$db->addPassword($newPassword);
				$self->{studentEntryReport} .= join("",
					CGI::b("Entered student: "), $newUser->last_name, ", ",$newUser->first_name,
					CGI::b(", login/studentID: "), $newUser->user_id, "/",$newUser->student_id,
					CGI::b(", email: "), $newUser->email_address,
					CGI::b(", section: "), $newUser->section,CGI::hr(),CGI::br(),

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
		CGI::p("Enter information below for students you wish to add. Each student's password will initially be set to their student ID."),
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
					[ CGI::input({name=>"last_name_$i"}),
					  CGI::input({name=>"first_name_$i"}),
					  CGI::input({name=>"student_id_$i",size=>"16"}),
					  CGI::input({name=>"new_user_id_$i",size=>"10"}),
					  CGI::input({name=>"email_address_$i"}),
					  CGI::input({name=>"section_$i",size=>"10"}),
					  CGI::input({name=>"recitation_$i",size=>"10"}),
					  CGI::input({name=>"comment_$i"}),
					]
				)
			),"\n",
		);
	}

	return join("",		
		CGI::start_form({method=>"post", action=>$r->uri(),name=>"add_users"}),
		$self->hidden_authen_fields(),"\n",
		CGI::submit(-name=>"Create", -value=>"Create"),"&nbsp;&nbsp;","\n",
		CGI::input({type=>'text', name=>'number_of_students', value=>$numberOfStudents,size => 3}), " entry rows. ","\n",
		CGI::end_form(),"\n",
		CGI::hr(),
		
		CGI::start_form({method=>"post", action=>$r->uri()}),
		$self->hidden_authen_fields(),
		CGI::input({type=>'hidden', name => "number_of_students", value => $numberOfStudents}),
		CGI::start_table({border=>'1', cellpadding=>'2'}),
		CGI::Tr({},
			CGI::th({},
				['Last Name', 'First Name', 'Student ID', 'Login Name', 'Email Address', 'Section','Recitation', 'Comment']
			)
		),
		@entryLines,
		CGI::end_table(),    
		

		
		CGI::p("Select sets below to assign them to the newly-created users."),
		CGI::popup_menu(
			-name     => "assignSets",
			-values   => [ $db->listGlobalSets ],
			-size     => 10,
			-multiple => "multiple",
		),
		CGI::p(
			CGI::submit({name=>"addStudents", value=>"Add Students"}),
		),
		CGI::end_form(),		

		#qq{ <div style="color:red"> After entering new students you will still 
		#need to assign sets to them.  This is done from the "set list" page. <br> 
		#Click on the entry "xx users" in 
		#the "assigned to" column at the far right. <br> Then click either "assign to all"  
		#or check individual users and click "save" at the bottom.  </div>
		#Soon ( real soon -- honest!!! :-)  ) you will also be able to assign sets to the students as they are entered from this page. }
	);
}


## Utility function to trim whitespace off the start and end of its input
sub trim_spaces {
	my $in = shift;
	$in =~ s/^\s*(.*?)\s*$/$1/;
	return($in);
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu

=cut
