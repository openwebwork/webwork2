################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2012 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/UserList3.pm,v 1.96 2010/05/14 00:52:48 gage Exp $
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

package WeBWorK::ContentGenerator::Instructor::UserList3;
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator);
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UserList3 - Entry point for User-specific
data editing (pstaab editing)

=cut

=for comment

What do we want to be able to do here?

Show a table with students (and other users).  The table can be be filtered by any name and role and should show when only some of the
users are being shown.

Edit user data by clicking on the editable fields in the table.

Import Users manually and from a general CSV file (and hopefully in the future other formats)

Export Users to a CSV file (or other format or elsewhere in Webwork)

Change a Password for a student

Email a student (or students)

Set the "Act as User" flag

Go to the Student Progress Page.
=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use HTML::Template;
use WeBWorK::CGI;
#use WeBWorK::File::Classlist;
use WeBWorK::Debug;
use WeBWorK::DB qw(check_user_id);
use WeBWorK::Utils qw(readFile readDirectory cryptPassword);
use constant HIDE_USERS_THRESHHOLD => 200;

# permissions needed to view a given field
use constant FIELD_PERMS => {
		act_as => "become_student",
		sets	=> "assign_problem_sets",
};

use constant STATE_PARAMS => [qw(user effectiveUser key visible_users no_visible_users prev_visible_users no_prev_visible_users editMode passwordMode primarySortField secondarySortField ternarySortField labelSortMethod)];



# template method
sub templateName {
	return "lbtwo";
}

sub pre_header_initialize {
	my $self          = shift;
	my $r             = $self->r;
	my $urlpath       = $r->urlpath;
	my $authz         = $r->authz;
	my $ce            = $r->ce;
	my $courseName    = $urlpath->arg("courseID");
	my $user          = $r->param('user');
	# Handle redirects, if any.
	##############################
	# Redirect to the addUser page
	##################################

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	
	defined($r->param('action')) && $r->param('action') eq 'add' && do {
		# fix url and redirect
		my $root              = $ce->{webworkURLs}->{root};
		
		my $numberOfStudents  = $r->param('number_of_students');
		warn $r->maketext("number of students not defined") unless defined $numberOfStudents;

		my $uri=$self->systemLink( $urlpath->newFromModule('WeBWorK::ContentGenerator::Instructor::AddUsers', $r, courseID=>$courseName),
		                           params=>{
		                          			number_of_students=>$numberOfStudents,
		                                   }
		);
		#FIXME  does the display mode need to be defined?
		#FIXME  url_authen_args also includes an effective user, so the new one must come first.
		# even that might not work with every browser since there are two effective User assignments.
		$self->reply_with_redirect($uri);
		return;
	};
}

sub initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $ce     = $r->ce;
	my $authz  = $r->authz;
	my $user   = $r->param('user');

	# Check permissions
	return unless $authz->hasPermissions($user, "access_instructor_tools");
	
}



sub body {
	my ($self)       = @_;
	my $r            = $self->r;
	my $urlpath      = $r->urlpath;
	my $db           = $r->db;
	my $ce           = $r->ce;
	my $authz        = $r->authz;	
	my $courseName   = $urlpath->arg("courseID");
	my $setID        = $urlpath->arg("setID");       
	my $user         = $r->param('user');
	
	my $root = $ce->{webworkURLs}->{root};

	# templates for getting field names
	my $userTemplate            = $self->{userTemplate}            = $db->newUser;
	my $permissionLevelTemplate = $self->{permissionLevelTemplate} = $db->newPermissionLevel;
	
	return CGI::div({class=>"ResultsWithError"}, CGI::p($r->maketext("You are not authorized to access the instructor tools.")))
		unless $authz->hasPermissions($user, "access_instructor_tools");
	
	
	# exclude set-level proctors
	my @allUserIDs = grep {$_ !~ /^set_id:/} $db->listUsers;
	# DBFIXME count would work
	$self->{totalSets} = $db->listGlobalSets; # save for use in "assigned sets" links
	$self->{allUserIDs} = \@allUserIDs;
	
	# DBFIXME filter in the database
	if (defined $r->param("visable_user_string")) {
		my @visableUserIDs = split /:/, $r->param("visable_user_string");
		$self->{visibleUserIDs} = [ @visableUserIDs ];
	} elsif (defined $r->param("visible_users")) {
		$self->{visibleUserIDs} = [ $r->param("visible_users") ];
	} elsif (defined $r->param("no_visible_users")) {
		$self->{visibleUserIDs} = [];
	} else {
		if ((@allUserIDs > HIDE_USERS_THRESHHOLD) and (not defined $r->param("show_all_users") )) {
			$self->{visibleUserIDs} = [];
		} else {
			$self->{visibleUserIDs} = [ @allUserIDs ];
		}
	}
	
	$self->{prevVisibleUserIDs} = $self->{visibleUserIDs};
	
	if (defined $r->param("selected_users")) {
		$self->{selectedUserIDs} = [ $r->param("selected_users") ];
	} else {
		$self->{selectedUserIDs} = [];
	}
	
	$self->{editMode} = $r->param("editMode") || 0;

	return CGI::div({class=>"ResultsWithError"}, CGI::p($r->maketext("You are not authorized to modify student data")))
		if $self->{editMode} and not $authz->hasPermissions($user, "modify_student_data");


	$self->{passwordMode} = $r->param("passwordMode") || 0;

	return CGI::div({class=>"ResultsWithError"}, CGI::p($r->maketext("You are not authorized to modify student data")))
		if $self->{passwordMode} and not $authz->hasPermissions($user, "modify_student_data");
	########## retrieve possibly changed values for member fields
	
	#@allUserIDs = @{ $self->{allUserIDs} }; # do we need this one?
	# DBFIXME instead of re-listing, why not add added users to $self->{allUserIDs} ?
	# exclude set-level proctors
	@allUserIDs = grep {$_ !~ /^set_id:/} $db->listUsers; # recompute value in case some were added

	my @visibleUserIDs = @{ $self->{visibleUserIDs} };
	my @prevVisibleUserIDs = @{ $self->{prevVisibleUserIDs} };
	my @selectedUserIDs = @{ $self->{selectedUserIDs} };
	my $editMode = $self->{editMode};
	my $passwordMode = $self->{passwordMode};	

	my $template = HTML::Template->new(filename => $WeBWorK::Constants::WEBWORK_DIRECTORY . '/htdocs/html-templates/classlist3.html');  
	print $template->output(); 


	########## print end of form
	
 	print CGI::end_form();

 	print $self->hidden_authen_fields;
    print CGI::hidden({id=>'hidden_courseID',name=>'courseID',default=>$courseName });

    
    
	return "";
}

################################################################################
# extract particular params and put them in a hash (values are ARRAYREFs!)
################################################################################



sub head{
	my $self = shift;
	my $r = $self->r;
    	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};
    	print "<link rel='stylesheet' href='$site_url/js/lib/vendor/editablegrid-2.0.1/editablegrid-2.0.1.css' type='text/css' media='screen'>";
        print "<link rel='stylesheet' type='text/css' href='$site_url/css/userlist.css' > </style>";
	print "<link rel='stylesheet' type='text/css' href='$site_url/js/lib/vendor/jquery-ui-for-classlist3/css/ui-lightness/jquery-ui-1.8.21.custom.css' > </style>";
	"";
}

# output_JS subroutine

# prints out the necessary JS for this page

sub output_JS{
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $site_url = $ce->{webworkURLs}->{htdocs};
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/addOnLoadEvent.js"}), CGI::end_script();
	#print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/show_hide.js"}), CGI::end_script();

	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/lib/vendor/editablegrid-2.0.1/editablegrid-2.0.1.js"}), CGI::end_script();

	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/lib/vendor/jquery-1.7.2.min.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/lib/vendor/json2.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/lib/vendor/underscore.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/lib/vendor/backbone.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/lib/vendor/jquery-ui-for-classlist3/js/jquery-ui-1.8.21.custom.min.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/lib/webwork/WeBWorK.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/lib/webwork/WeBWorK-ui.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/lib/webwork/teacher/teacher.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/lib/webwork/teacher/User.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/lib/webwork/util.js"}), CGI::end_script();
	print CGI::start_script({type=>"text/javascript", src=>"$site_url/js/apps/UserList/userlist.js"}), CGI::end_script();
	
	return "";
}

1;

