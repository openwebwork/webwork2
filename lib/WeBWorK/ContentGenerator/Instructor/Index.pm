################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Instructor::Index;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Index - Menu interface to the Instructor pages

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

	if (defined($r->param('addStudent'))) {
		my $newUser = $db->newUser;
		my $newPermissionLevel = $db->newPermissionLevel;
		my $newPassword = $db->newPassword;
		$newUser->user_id($r->param('new_user_id'));
		$newPermissionLevel->user_id($r->param('new_user_id'));
		$newPassword->user_id($r->param('new_user_id'));
		$newUser->last_name($r->param('last_name'));
		$newUser->first_name($r->param('first_name'));
		$newUser->student_id($r->param('student_id'));
		$newUser->email_address($r->param('email_address'));
		$newUser->section($r->param('section'));
		$newUser->recitation($r->param('recitation'));
		$newUser->comment($r->param('comment'));
		$newUser->status('C');
		$newPermissionLevel->permission(0);
		#FIXME  handle errors if user exists already
		$db->addUser($newUser);
		$db->addPermissionLevel($newPermissionLevel);
		$db->addPassword($newPassword);
	 	$self->{studentEntryReport} = join("",
	 		"Entered student", CGI::br(), 
	        "Name: ", $newUser->last_name, ", ",$newUser->first_name,CGI::br(),
	        " login/studentID: ", $newUser->user_id, "/",$newUser->student_id,CGI::br(),
	        " email: ", $newUser->email_address,CGI::br(),
	        " section: ", $newUser->section,CGI::br(),
	       
	    );
	}








}
sub path {
	my $self          = shift;
	my $args          = $_[-1];
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home"          => "$root",
		$courseName     => "$root/$courseName",
		'instructor'    => '',
	);
}

sub title {
	my $self = shift;
	return "Instructor tools for ".$self->{ce}->{courseName};
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
#     my $permissonLevel =  $self->{db}->getPermissionLevel($user)->permission();
#     
#     my $courseEnvironmentLevels = $self->{ce}->{permissionLevels};
#     return CGI::em(" user $permissonLevel permlevels ".join("<>",%$courseEnvironmentLevels));
    ################### debug code
	return CGI::em('You are not authorized to access the Instructor tools.') unless $authz->hasPermissions($user, 'access_instructor_tools');

	return join("", 
		CGI::start_table({-border=>2,-cellpadding=>20}),
		CGI::Tr({-align=>'center'},
			CGI::td(
				CGI::a({href=>$userEditorURL}, "Edit $courseName class list")  ,
			),
			CGI::td(
				CGI::a({href=>$problemSetEditorURL}, "Edit $courseName problem sets"),
					
			),"\n",
		),
		CGI::Tr({ -align=>'center'},
			CGI::td([
				CGI::a({-href=>$emailURL}, "Send e-mail to $courseName"),
				CGI::a({-href=>$statsURL}, "Statistics for $courseName"),
			]),
			"\n",
		),
		CGI::Tr({ -align=>'center'},
			CGI::td([
				'WeBWorK 1.9 Instructor '.CGI::a({-href=>$full_url}, 'Tools'),
				'Open WeBWorK 1.9 Instructor '.CGI::a({-href=>$full_url, -target=>'_new'}, 'Tools').' in new window',
			]),
			"\n",
		),
		
		CGI::end_table(),
		CGI::hr(),
		CGI::p( defined($self->{studentEntryReport}) ? $self->{studentEntryReport}:''
		),
		$self->addStudentForm,
	);
}
sub addStudentForm {
	my $self = shift;
	my $r = $self->{r};
	
	# Add a student form
	join( "",
		CGI::p("Add new students"),	
		CGI::start_form({method=>"post", action=>$r->uri()}),
		$self->hidden_authen_fields(),
		CGI::start_table({border=>'1', cellpadding=>'2'}),
		CGI::Tr({},
			CGI::th({},
				['Last Name', 'First Name', 'Student ID', 'Login Name', 'Email Address', 'Section','Recitation', 'Comment']
			)
		),
		CGI::Tr({},
			CGI::td({},
				[ CGI::input({name=>'last_name'}),
				  CGI::input({name=>'first_name'}),
				  CGI::input({name=>'student_id',size=>'16'}),
				  CGI::input({name=>'new_user_id',size=>'10'}),
				  CGI::input({name=>'email_address'}),
				  CGI::input({name=>'section',size=>'10'}),
				  CGI::input({name=>'recitation',size=>'10'}),
				  CGI::input({name=>'comment'}),
				
				
				]
			)
		),
		CGI::end_table(),
		CGI::submit({name=>"addStudent", value=>"Add Student"}),
		CGI::end_form(),
	);






}
1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu

=cut
