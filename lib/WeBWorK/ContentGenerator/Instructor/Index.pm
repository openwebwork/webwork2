################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Instructor/Index.pm,v 1.25 2004/01/18 00:12:30 gage Exp $
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

WeBWorK::ContentGenerator::Instructor::Index - Menu interface to the Instructor pages

=cut

use strict;
use warnings;
use Apache::Constants qw(:common REDIRECT DONE);
use CGI qw();
sub pre_header_initialize {
	my ($self, $setName, $problemNumber) = @_;
	my $r                    = $self->{r};
	my $ce                   = $self->{ce};
	my $db                   = $self->{db};
	my $authz                = $self->{authz};
	my $userName             = $r->param('user');
	my $effectiveUserName    = $r->param('effectiveUser');
	my $key                  = $r->param('key');
	my $user                 = $db->getUser($userName); #checked 
	die "user $user (real user) not found."  unless $user;
	my $effectiveUser        = $db->getUser($effectiveUserName); #checked
	die "effective user $effectiveUser  not found. One 'acts as' the effective user."  unless $effectiveUser;
	my $PermissionLevelRecord      = $db->getPermissionLevel($userName); #checked
	die "permisson level for user $userName  not found."  unless $PermissionLevelRecord;
	my $permissionLevel = $PermissionLevelRecord->permission();
	
	
	
	unless ($authz->hasPermissions($userName, "modify_student_data")) {
		$self->{submitError} = "You are not authorized to modify student data";
		return;
	}
	my @submit_actions = qw(student-dates act-as-student edit-set-dates reset-password assign-passwords 
	                        set-stats drop-students edit-students-sets edit-sets student-stats edit-class-data
	                        add-students send-email score-sets);
	foreach my $act (@submit_actions) {
		$self->{current_action } .=  "The action &lt;$act&gt; &quot;". $r->param($act) . "&quot; was requested" 
		if defined($r->param($act));
	}
	$self->{selected_sets}   = "Set(s) chosen: "      . join(" ", $r->param("setList"));
	$self->{selected_users}  = "Student(s) chosen: "  .join(" ", $r->param("classList")) ;
#   Redirect actions
    defined($r->param('student-dates')) && do {
    #FIXME  will only do one student and one set at a time
    # it would be good to be able to do many sets for many student
    # this would require a separate module
     	my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};
		my @userList        = $r->param("classList");
		# can only become the first user listed.
		my $student     = shift @userList;
		my @setList        = $r->param("setList");
		# can only become the first user listed.
		my $setName         = shift @setList;
		my $uri="$root/$courseName/instructor/sets/$setName/?editForUser=$student&".$self->url_authen_args;
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
    };
	defined($r->param('act-as-student')) && do {
		# fix url and redirect
		my @userList        = $r->param("classList");
		# can only become the first user listed.
		my $effectiveUser   = shift @userList;
		my @setList         = $r->param("setList");
		my $setName         =  shift @setList;
		my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};

		my $uri="$root/$courseName/$setName/?effectiveUser=$effectiveUser&".$self->url_authen_args;
		#FIXME  does the display mode need to be defined?
		#FIXME  url_authen_args also includes an effective user, so the new one must come first.
		# even that might not work with every browser since there are two effective User assignments.
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
	};
	defined($r->param('edit-set-dates')) && do {
	#FIXME  this should be replaced by redirecting to a module where you can edit
	# dates for several sets at once
     	my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};
		my @setList        = $r->param("setList");
		# can only become the first user listed.
		my $setName         = shift @setList;
		my $uri="$root/$courseName/instructor/sets/$setName/?".$self->url_authen_args;
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
    };
    defined($r->param('reset-password')) && do {
    # FIXME this should allow me to assign studentID to a number of students
    # requires a new module
		my @userList        = $r->param("classList");
		# can only become the first user listed.
		my $effectiveUser   = shift @userList;
		my @setList         = $r->param("setList");
		my $setName         =  shift @setList;
		my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};

		my $uri="$root/$courseName/options/?effectiveUser=$effectiveUser&".$self->url_authen_args;
		#FIXME  does the display mode need to be defined?
		#FIXME  url_authen_args also includes an effective user, so the new one must come first.
		# even that might not work with every browser since there are two effective User assignments.
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
    };
    defined($r->param('assign-passwords')) && do {
  		my @userList        = $r->param("classList");
		# can only become the first user listed.
		my $effectiveUser   = shift @userList;
		my @setList         = $r->param("setList");
		my $setName         =  shift @setList;
		my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};

		my $uri="$root/$courseName/options/?effectiveUser=$effectiveUser&".$self->url_authen_args;
		#FIXME  does the display mode need to be defined?
		#FIXME  url_authen_args also includes an effective user, so the new one must come first.
		# even that might not work with every browser since there are two effective User assignments.
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
    };
    defined($r->param('set-stats')) && do {
     	my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};
		my @setList        = $r->param("setList");
		# can only become the first user listed.
		my $setName         = shift @setList;
		my $uri="$root/$courseName/instructor/stats/set/$setName?".$self->url_authen_args;
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
    };
    defined($r->param('drop-students')) && do {
    #FIXME  this operation should be made faster
    	my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};
		my @setList        = $r->param("setList");
		# can only become the first user listed.
		my $setName         = shift @setList;
		my $uri="$root/$courseName/instructor/users/?".$self->url_authen_args;
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
    };
    defined($r->param('edit-students-sets')) && do {
      	my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};
		my @userList        = $r->param("classList");
		# can only become the first user listed.
		my $student     = shift @userList;
		my @setList        = $r->param("setList");
		# can only become the first user listed.
		my $setName         = shift @setList;
		my $uri="$root/$courseName/instructor/sets/$setName/?editForUser=$student&".$self->url_authen_args;
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
    };
    defined($r->param('edit-sets')) && do {
    	my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};
		my @setList        = $r->param("setList");
		# can only become the first user listed.
		my $setName         = shift @setList;
		my $uri="$root/$courseName/instructor/sets/$setName/?".$self->url_authen_args;
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
    };
    defined($r->param('student-stats')) && do {
    	my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};
		my @userList        = $r->param("classList");
		# can only become the first user listed.
		my $studentName     = shift @userList;
		my $uri="$root/$courseName/instructor/stats/student/$studentName?".$self->url_authen_args;
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
    };
    defined($r->param('edit-class-data')) && do {
    	my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};
		#my @setList        = $r->param("setList");
		## can only become the first user listed.
		#my $setName         = shift @setList;
		# ...not sure what those are about
		# get list of users selected
		my @userIDs = $r->param("classList");
		my $uri="$root/$courseName/instructor/users/?";
		$uri .= join("&", map { "visible_users=$_" } @userIDs);
		$uri .= "&editMode=1",
		$uri .= "&" . $self->url_authen_args;
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
    };
    defined($r->param('add-students')) && do {
		my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};

		my $uri="$root/$courseName/instructor/add_users/?".$self->url_authen_args;
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
	};
	defined($r->param('send-email')) && do {
		my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};

		my $uri="$root/$courseName/instructor/send_mail/?".$self->url_authen_args;
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
	};
	defined($r->param('score-sets')) && do {
		my $root            = $ce->{webworkURLs}->{root};
		my $courseName      = $ce->{courseName};

		my $uri="$root/$courseName/instructor/scoring/?scoreSelected=Score%20Selected&".$self->url_authen_args;
		my @selectedSets    = $r->param('setList');
		$uri .= "&selectedSet=$_" foreach (@selectedSets);
		$r->header_out(Location => $uri);
		$self->{noContent} =  1;  # forces redirect
		return;
	};	

}
# override contentGenerator header routine for now
# FIXME
sub header {
	my $self = shift;
	return REDIRECT if $self->{noContent};
	my $r = $self->{r};
	$r->content_type('text/html');
	$r->send_http_header();
	return OK;
}
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

#############################################################################################
#	gather database data
#############################################################################################	
	# FIXME  this might be better done in body? We don't always need all of this data. or do we?
# Obtaining the list of users
    $WeBWorK::timer->continue("Begin listing users") if defined $WeBWorK::timer;
	my @userNames =  $db->listUsers; # checked
	$WeBWorK::timer->continue("End listing users") if defined $WeBWorK::timer;
	$WeBWorK::timer->continue("Begin obtaining users") if defined $WeBWorK::timer;
	my @user_records = $db->getUsers(@userNames); # checked
	$WeBWorK::timer->continue("End obtaining users: ".@user_records) if defined $WeBWorK::timer;

	# store data
	$self->{ra_users}              =   \@userNames;
	$self->{ra_user_records}       =   \@user_records;

# Obtaining list of sets:
	$WeBWorK::timer->continue("Begin listing sets") if defined $WeBWorK::timer;
	my @setNames =  $db->listGlobalSets();
	$WeBWorK::timer->continue("End listing sets") if defined $WeBWorK::timer;
	my @set_records = ();
	$WeBWorK::timer->continue("Begin obtaining sets") if defined $WeBWorK::timer;
	@set_records = $db->getGlobalSets( @setNames);
	$WeBWorK::timer->continue("End obtaining sets: ".@set_records) if defined $WeBWorK::timer;

	

	# store data
	$self->{ra_sets}              =   \@setNames;
	$self->{ra_set_records}       =   \@set_records;

}
sub path {
	my $self          = shift;
	my $args          = $_[-1];
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home"             => "$root",
		$courseName        => "$root/$courseName",
		"Instructor Tools" => "",
	);
}

sub title {
	my $self = shift;
	return "Instructor Tools";
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
	my $statsURL = "stats/?" . $self->url_args;
	my $emailURL = "send_mail/?" . $self->url_args;
	my $scoringURL = "scoring/?" . $self->url_args;
	my $filexferURL = "files/?" . $self->url_args;
	my $actionURL = $r->uri;
	
	return CGI::em('You are not authorized to access the Instructor tools.') unless $authz->hasPermissions($user, 'access_instructor_tools');
	
		print join("",
		CGI::start_table({-border=>2,-cellpadding=>20}),
		CGI::Tr({-align=>'center'},
			CGI::td([
				CGI::a({href=>$userEditorURL}, "User List"),
				CGI::a({href=>$problemSetEditorURL}, "Set List"),
				CGI::a({-href=>$emailURL}, "Mail Merge"), 
				CGI::a({-href=>$scoringURL}, "Scoring"),
				CGI::a({-href=>$statsURL}, "Statistics"),
				CGI::a({-href=>$filexferURL}, "File Transfer"),
			]),
			"\n",
		),
		
		CGI::Tr({ -align=>'left'},
			CGI::td({-colspan=>6},
				CGI::a({-href=>$full_url}, 'WeBWorK 1.x Instructor Tools'),
				" (" . CGI::a({-href=>$full_url, -target=>'_new'}, 'open in a new window') . ")",
			),
			"\n",
			),
			CGI::end_table(),
		);
	
	print join("",
		CGI::p('Quick access to common instructor tools.'),
		CGI::start_form(-method=>"POST", -action=>$actionURL),"\n",
		$self->hidden_authen_fields,"\n",
		CGI::start_table({-border=>2,-cellpadding=>5}),	
		CGI::Tr({ -align=>'center'},
			CGI::td({colspan=>2},[
					CGI::input({type=>'submit',value=>'Add students...',name=>'add-students'}),
					CGI::input({type=>'submit',value=>'Send email...',name=>'send-email'}),
				]
			),

		
		),
		CGI::Tr({ -align=>'center'},
			CGI::td({colspan=>1},[
					
					CGI::input({type=>'submit',value=>'Reset password',name=>'reset-password'}),
					CGI::input({type=>'submit',value=>'Assign passwords...',name=>'assign-passwords'}), 
					CGI::input({type=>'submit',value=>'View set statistics...',name=>'set-stats'}),
					CGI::input({type=>'submit',value=>'Edit set(s) dates...',name=>'edit-set-dates'})
				]
			)
		
		),
		CGI::Tr({ -align=>'center'},
			CGI::td({colspan=>1},[
					CGI::input({type=>'submit',value=>'View student statistics...',name=>'student-stats'}),
					CGI::input({type=>'submit',value=>'Edit class data for students...',name=>'edit-class-data'}),
					CGI::input({type=>'submit',value=>'Edit set(s) data...',name=>'edit-sets'}),
					CGI::input({type=>'submit',value=>'Score selected set(s)...',name=>'score-sets'}),
				]
			),
		),

		
		CGI::Tr({ -align=>'center'},
			CGI::td({colspan=>2},[
					$self->popup_user_form,
					$self->popup_set_form,
				]
			)
		
		),
		CGI::Tr({ -align=>'center'},
			CGI::td({colspan=>1},[
					
					CGI::input({type=>'submit',value=>'Edit student(s)/set(s) dates',name=>'student-dates'}),
					CGI::input({type=>'submit',value=>'Act as student in set...',name=>'act-as-student'}),
				]
			),
			CGI::td({colspan=>2}, 
				CGI::input({type=>'submit',value=>'Edit student(s) data for selected set(s)...',name=>'edit-students-sets'}),
				
				
			)
		
		),

		CGI::Tr({ -align=>'center'},
			CGI::td({colspan=>2},[
					CGI::input({type=>'submit',value=>'Drop student(s)',name=>'drop-students'}),
					'&nbsp;'
					]
			),
			
		
		),

		CGI::end_table(),
		CGI::end_form(),
	);
	return "";

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
sub popup_user_form {
	my $self  = shift;
	my $r     = $self->{r};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};

 #     return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");
	
	# This code will require changing if the permission and user tables ever have different keys.
    my @users                 = ();
	my $ra_user_records       = $self->{ra_user_records};
	my %classlistLabels       = ();#  %$hr_classlistLabels;
	my @user_records   = sort { ( lc($a->section) cmp lc($b->section) ) || 
	                     ( lc($a->last_name) cmp lc($b->last_name ))  } @{$ra_user_records};
	foreach my $ur (@{user_records}) {
		$classlistLabels{$ur->user_id} = $ur->last_name. ', '. $ur->first_name.'   -   '.$ur->section.' '.$ur->user_id;
		push(@users, $ur->user_id);
	}
	return 			CGI::popup_menu(-name=>'classList',
							   -values=>\@users,
							   -labels=>\%classlistLabels,
							   -size  => 10,
							   -multiple => 1,
							   #-default=>$user
					),


}
sub popup_set_form {
	my $self  = shift;
	my $r     = $self->{r};
	my $authz = $self->{authz};
	my $user = $r->param('user');
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};

 #     return CGI::em("You are not authorized to access the Instructor tools.") unless $authz->hasPermissions($user, "access_instructor_tools");

	# This code will require changing if the permission and user tables ever have different keys.
    my @setNames              = ();
	my $ra_set_records        = $self->{ra_set_records};
	my %setLabels             = ();#  %$hr_classlistLabels;
	my @set_records           =  sort {$a->set_id cmp $b->set_id } @{$ra_set_records};
	foreach my $sr (@set_records) {
 		$setLabels{$sr->set_id} = $sr->set_id;
 		push(@setNames, $sr->set_id);  # reorder sets
	}
 	return 			CGI::popup_menu(-name=>'setList',
 							   -values=>\@setNames,
 							   -labels=>\%setLabels,
 							   -size  => 10,
 							   -multiple => 1,
 							   #-default=>$user
 					),


}
1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu

=cut
