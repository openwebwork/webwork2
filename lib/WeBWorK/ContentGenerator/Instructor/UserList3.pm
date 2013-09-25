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
use JSON;
use constant HIDE_USERS_THRESHHOLD => 200;



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
	#@allUserIDs = grep {$_ !~ /^set_id:/} $db->listUsers; # recompute value in case some were added

	#my @visibleUserIDs = @{ $self->{visibleUserIDs} };
	#my @prevVisibleUserIDs = @{ $self->{prevVisibleUserIDs} };
	#my @selectedUserIDs = @{ $self->{selectedUserIDs} };
	#my $editMode = $self->{editMode};
	#my $passwordMode = $self->{passwordMode};	

	my $template = HTML::Template->new(filename => $WeBWorK::Constants::WEBWORK_DIRECTORY . '/htdocs/html-templates/classlist-manager.html');  
	print $template->output(); 


	########## print end of form
	
 	#print CGI::end_form();

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

    print "<link rel='stylesheet' href='$site_url/js/components/editablegrid/editablegrid-2.0.1.css' type='text/css' media='screen'>";
    print "<link rel='stylesheet' type='text/css' href='$site_url/css/userlist.css' > </style>";
	print "<link rel='stylesheet' href='$site_url/themes/jquery-ui-themes/smoothness/jquery-ui.css' type='text/css' media='screen'>";
	return "";
}

## get all of the user information to send to the client via a script tag in the output_JS subroutine below

sub getAllSets {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;

	my @found_sets = $db->listGlobalSets;
  
  	my @all_sets = $db->getGlobalSets(@found_sets);

  	my @sets = ();
  
  
	foreach my $set (@all_sets){
		my @users = $db->listSetUsers($set->{set_id});
		$set->{assigned_users} = \@users;

		# convert the set $set to a hash
		my $s = {};
		for my $key (keys %{$set}) {
			$s->{$key} = $set->{$key}
		}

		push(@sets,$s);
	}

	#debug(to_json(\@all_sets));

	return \@sets;
}

# get the course settings

sub getCourseSettings {

	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my $ConfigValues = $ce->{ConfigValues};

	foreach my $oneConfig (@$ConfigValues) {
		foreach my $hash (@$oneConfig) {
			if (ref($hash) eq "HASH"){
				my $str = '$ce->' . $hash->{hashVar};
				$hash->{value} = eval($str);
			} else {
				debug($hash);
			}
		}
	}

	# get the list of theme folders in the theme directory and remove . and ..
	my $themeDir = $ce->{webworkDirs}{themes};
	opendir(my $dh, $themeDir) || die "can't opendir $themeDir: $!";
	my $themes =[grep {!/^\.{1,2}$/} sort readdir($dh)];
	
	# insert the anonymous array of theme folder names into ConfigValues
	my $modifyThemes = sub { my $item=shift; if (ref($item)=~/HASH/ and $item->{var} eq 'defaultTheme' ) { $item->{values} =$themes } };

	foreach my $oneConfig (@$ConfigValues) {
		foreach my $hash (@$oneConfig) {
			&$modifyThemes($hash);
		}
	}

	my $tz = DateTime::TimeZone->new( name => $ce->{siteDefaults}->{timezone}); 
	my $dt = DateTime->now();

	my @tzabbr = ("tz_abbr", $tz->short_name_for_datetime( $dt ));


	#debug($tz->short_name_for_datetime($dt));

	push(@$ConfigValues, \@tzabbr);

	return $ConfigValues;
}


# get all users for the course

sub getAllUsers {


	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;

    my @tempArray = $db->listUsers;
    my @userInfo = $db->getUsers(@tempArray);
    my $numGlobalSets = $db->countGlobalSets;
    
    my @allUsers = ();

    my %permissionsHash = reverse %{$ce->{userRoles}};
    foreach my $u (@userInfo)
    {
        my $PermissionLevel = $db->getPermissionLevel($u->{'user_id'});
        $u->{'permission'} = $PermissionLevel->{'permission'};

		my $studid= $u->{'student_id'};
		$u->{'student_id'} = "$studid";  # make sure that the student_id is returned as a string. 
        $u->{'num_user_sets'} = $db->listUserSets($studid) . "/" . $numGlobalSets;
	
		my $Key = $db->getKey($u->{'user_id'});
		$u->{'login_status'} =  ($Key and time <= $Key->timestamp()+$ce->{sessionKeyTimeout}); # cribbed from check_session
		

		# convert the user $u to a hash
		my $s = {};
		for my $key (keys %{$u}) {
			$s->{$key} = $u->{$key}
		}

		push(@allUsers,$s);
    }

    return \@allUsers;
}


# output_JS subroutine

# prints out the necessary JS for this page

sub output_JS{
	my $self = shift;
	# my $r = $self->r;
	# my $ce = $r->ce;

	my $site_url = $self->r->ce->{webworkURLs}->{htdocs};
	print qq!<script src="$site_url/js/apps/require-config.js"></script>!;
	print qq!<script type="text/javascript" src="$site_url/mathjax/MathJax.js?config=TeX-AMS-MML_HTMLorMML"></script>!;
	print qq!<script type='text/javascript'>!;
    print qq! require.config = { 'ClasslistManager': {!;
    print qq! users: ! . to_json(getAllUsers($self)) . ",";
    print qq! settings: ! . to_json(getCourseSettings($self)) . ",";
    print qq! sets: ! . to_json(getAllSets($self)) ;
    print qq!    }};!;
    print qq!</script>!;
	print qq!<script data-main="$site_url/js/apps/ClasslistManager/ClasslistManager" src="$site_url/js/components/requirejs/require.js"></script>\n!;

	return "";
}

1;

