################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/AddUsers.pm,v 1.3 2003/12/12 02:24:30 gage Exp $
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

sub initialize {
	my ($self) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $authz = $self->{authz};
	my $user = $r->param('user');

	unless ($authz->hasPermissions($user, "modify_student_data")) {
		$self->{submitError} = "You are not authorized to modify student data";
		return;
	}

	if (defined($r->param('addStudents'))) {
		my $numberOfStudents    = $r->param('number_of_students');
		warn "Internal error -- the number of students to be added has not been included" unless defined $numberOfStudents;
		foreach my $i (1..$numberOfStudents) {
		    my $new_user_id        =   $r->param("new_user_id_$i");
		    next unless defined($new_user_id) and $new_user_id;
		    
			my $newUser            = $db->newUser;
			my $newPermissionLevel = $db->newPermissionLevel;
			my $newPassword        = $db->newPassword;
			$newUser->user_id($new_user_id);
			$newPermissionLevel->user_id($new_user_id);
			$newPassword->user_id($new_user_id);
			$newUser->last_name($r->param("last_name_$i"));
			$newUser->first_name($r->param("first_name_$i"));
			$newUser->student_id($r->param("student_id_$i"));
			$newUser->email_address($r->param("email_address_$i"));
			$newUser->section($r->param("section_$i"));
			$newUser->recitation($r->param("recitation_$i"));
			$newUser->comment($r->param("comment_$i"));
			$newUser->status('C');
			$newPermissionLevel->permission(0);
			#FIXME  handle errors if user exists already
			$db->addUser($newUser);
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
}

sub path {
	my $self = shift;
	my $args = $_[-1];
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
	return $self->pathMacro($args,
		"Home"             => "$root",
		$courseName        => "$root/$courseName",
		'Instructor Tools' => '',
	);
}

sub title {
	my $self = shift;
	return "Add students";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $authz = $self->{authz};
	my $courseName = $ce->{courseName};
	my $authen_args = $self->url_authen_args();
	my $user = $r->param('user');
	my $prof_url = $ce->{webworkURLs}->{oldProf};
	my $full_url = "$prof_url?course=$courseName&$authen_args";
	my $userEditorURL = "users/?" . $self->url_args;
	my $problemSetEditorURL = "sets/?" . $self->url_args;
	my $statsURL       = "stats/?" . $self->url_args;
	my $emailURL       = "send_mail/?" . $self->url_args;
	
	################### debug code
	#my $permissonLevel =  $self->{db}->getPermissionLevel($user)->permission(); #checked
	#my $courseEnvironmentLevels = $self->{ce}->{permissionLevels};
	#return CGI::em(" user $permissonLevel permlevels ".join("<>",%$courseEnvironmentLevels));
    ################### debug code
    
	return CGI::em('You are not authorized to access the Instructor tools.')
		unless $authz->hasPermissions($user, 'access_instructor_tools');

	return join("", 
	
		CGI::hr(),
		CGI::p(
			defined($self->{studentEntryReport})
				? $self->{studentEntryReport}
				: ''
		),
		$self->addStudentForm,
	);
}

sub addStudentForm {
	my $self            = shift;
	my $r               = $self->{r};
	my $numberOfStudents   = $r->param("number_of_students") || 5;
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
		CGI::submit({name=>"addStudents", value=>"Add Students"}),
		CGI::end_form(),
		qq! <div style="color:red"> After entering new students you will still need to assign sets to them.  This is done from the "set list" page. <br> 
		Click on the entry "xx users" in 
		the "assigned to" column at the far right. <br> Then click either "assign to all"  or check individual users and click "save" at the bottom.  </div>!
	);
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu

=cut
