################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2018 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/CourseAdmin.pm,v 1.91 2010/06/13 02:25:51 gage Exp $
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

package WeBWorK::ContentGenerator::CourseAdmin;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::CourseAdmin - Add, rename, and delete courses.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use Data::Dumper;
use File::Temp qw/tempfile/;
use WeBWorK::CourseEnvironment;
use IO::File;
use URI::Escape;
use WeBWorK::Debug;
use WeBWorK::Utils qw(cryptPassword writeLog listFilesRecursive trim_spaces);
use WeBWorK::Utils::CourseManagement qw(addCourse renameCourse retitleCourse deleteCourse listCourses archiveCourse 
                                        listArchivedCourses unarchiveCourse initNonNativeTables);
use WeBWorK::Utils::CourseIntegrityCheck;
use WeBWorK::DB;
#use WeBWorK::Utils::DBImportExport qw(dbExport dbImport);
# needed for location management
use Net::IP;
use File::Path 'remove_tree';
use File::stat;
use Time::localtime;

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	my $user        = $r->param('user');
	
	# check permissions
	unless ($authz->hasPermissions($user, "create_and_delete_courses")) {
		$self->addmessage( CGI::div({class=>'ResultsWithError'},"$user is not authorized to create or delete courses") );
		return;
	}
	
	# get result and send to message
	my $status_message = $r->param("status_message");
	$self->addmessage(CGI::p("$status_message")) if $status_message;
    
    
    # Check that the non-native tables are present in the database
    # These are the tables which are not course specific
    
    my $table_update_result = initNonNativeTables($ce, $ce->{dbLayoutName});
    
    $self->addgoodmessage(CGI::p("$table_update_result")) if $table_update_result;
    
    
	my @errors;
	my $method_to_call;
	
	my $subDisplay = $r->param("subDisplay");
	if (defined $subDisplay) {
	
		if ($subDisplay eq "add_course") {
			if (defined $r->param("add_course")) {
				@errors = $self->add_course_validate;
				if (@errors) {
					$method_to_call = "add_course_form";
				} else {
					$method_to_call = "do_add_course";
				}
			} else {
				$method_to_call = "add_course_form";
			}
		}
		
		elsif ($subDisplay eq "rename_course") {
			if (defined $r->param("rename_course")) {
				@errors = $self->rename_course_validate;
				if (@errors) {
					$method_to_call = "rename_course_form";
				} else {
					$method_to_call = "rename_course_confirm";
				}
			} elsif (defined $r->param("confirm_rename_course")) {
				# validate and rename
				@errors = $self->rename_course_validate;
				if (@errors) {
					$method_to_call = "rename_course_form";
				} else {
					$method_to_call = "do_rename_course";
				}
			} elsif (defined $r->param("confirm_retitle_course")) {
				    $method_to_call = "do_retitle_course";
			
			} elsif (defined $r->param("upgrade_course_tables") ){
			    # upgrade and revalidate
			    @errors = $self->rename_course_validate;
				if (@errors) {
					$method_to_call = "rename_course_form";
				} else {
					$method_to_call = "rename_course_confirm";
				}

			} else {
				$method_to_call = "rename_course_form";
			}
		}
		
		elsif ($subDisplay eq "delete_course") {
			if (defined $r->param("delete_course")) {
				# validate or confirm
				@errors = $self->delete_course_validate;
				if (@errors) {
					$method_to_call = "delete_course_form";
				} else {
					$method_to_call = "delete_course_confirm";
				}
			} elsif (defined $r->param("confirm_delete_course")) {
				# validate and delete
				@errors = $self->delete_course_validate;
				if (@errors) {
					$method_to_call = "delete_course_form";
				} else {
					$method_to_call = "do_delete_course";
				}
			}	
			elsif (defined ($r->param("delete_course_refresh"))) {
				$method_to_call = "delete_course_form";
			} else {
				# form only
				$method_to_call = "delete_course_form";
			}
		}
		
		elsif ($subDisplay eq "export_database") {
			if (defined $r->param("export_database")) {
				@errors = $self->export_database_validate;
				if (@errors) {
					$method_to_call = "export_database_form";
				} else {
					# we have to do something special here, since we're sending
					# the database as we export it. $method_to_call still gets
					# set here, but it gets caught by header() and content()
					# below instead of by body().
					$method_to_call = "do_export_database";
				}
			} else {
				$method_to_call = "export_database_form";
			}
		}
		
		elsif ($subDisplay eq "import_database") {
			if (defined $r->param("import_database")) {
				@errors = $self->import_database_validate;
				if (@errors) {
					$method_to_call = "import_database_form";
				} else {
					$method_to_call = "do_import_database";
				}
			} else {
				$method_to_call = "import_database_form";
			}
		}
		
		elsif ($subDisplay eq "archive_course") {
		  if (defined $r->param("archive_course") ||
		      defined $r->param("skip_archive_course")) {

		    # validate -- if invalid, start over.
		    # if form is valid a page indicating the status of 
		    # database tables and directories is presented.
		    # If they are ok, then you can push archive button, otherwise
		    # you can quit or choose to upgrade the tables
		    @errors = $self->archive_course_validate;
		    if (@errors) {
		      $method_to_call = "archive_course_form";
		    } else {
		      $method_to_call = "archive_course_confirm"; #check tables & directories
		    }
		  } elsif (defined $r->param("confirm_archive_course")) {
		    # validate and archive
		    # the "archive it" button has been pushed and the 
		    # course will be archived
		    # a report on success or failure will be generated
		    @errors = $self->archive_course_validate;
		    if (@errors) {
		      $method_to_call = "archive_course_form";
		    } else {
		      $method_to_call = "do_archive_course";
		    }
		  } elsif (defined $r->param("upgrade_course_tables") ){
		    # upgrade and revalidate
		    # the "upgrade course" button has been pushed
		    # after the course has been upgraded you are returned
		    # to the confirm page.
		    @errors = $self->archive_course_validate;
		    if (@errors) {
		      $method_to_call = "archive_course_form";
		    } else {
		      $method_to_call = "archive_course_confirm"; # upgrade and recheck tables & directories.
		    }
		  }	
		  elsif (defined ($r->param("archive_course_refresh"))) {
		    $method_to_call = "archive_course_form";
		  } else {
		    # form only
		    $method_to_call = "archive_course_form";
		  }
		}
		elsif ($subDisplay eq "unarchive_course") {
			if (defined $r->param("unarchive_course")) {
				# validate or confirm
				@errors = $self->unarchive_course_validate;
				if (@errors) {
					$method_to_call = "unarchive_course_form";
				} else {
					$method_to_call = "unarchive_course_confirm";
				}
			} elsif (defined $r->param("confirm_unarchive_course")) {
				# validate and archive
				@errors = $self->unarchive_course_validate;
				if (@errors) {
					$method_to_call = "unarchive_course_form";
				} else {
					$method_to_call = "do_unarchive_course";
				}
			} else {
				# form only
				# start at the beginning -- get drop down list of courses to unarchive
				$method_to_call = "unarchive_course_form";
			}
		}
		elsif ($subDisplay eq "upgrade_course") {
			if (defined $r->param("upgrade_course")) {
				# validate or confirm
				# if form is valid present details of analysis of the course structure
				@errors = $self->upgrade_course_validate;
				if (@errors) {
					$method_to_call = "upgrade_course_form";
				} else {
					$method_to_call = "upgrade_course_confirm";
				}
			} elsif (defined $r->param("confirm_upgrade_course")) {
				# validate and upgrade
				# if form is valid upgrade the courses and present results
				@errors = $self->upgrade_course_validate;
				if (@errors) {
					$method_to_call = "upgrade_course_form";
				} else {
					$method_to_call = "do_upgrade_course";
				}
			} else {
				# form only
				# start at the beginning -- get list of courses and their status
				$method_to_call = "upgrade_course_form";
			}
		}
		elsif ($subDisplay eq "manage_locations") {
			if (defined ($r->param("manage_location_action"))) {
				$method_to_call = 
				    $r->param("manage_location_action");
			}
			else{
				$method_to_call = "manage_location_form";
			}
		}
		elsif ($subDisplay eq "hide_inactive_course") {
#			warn "subDisplay is $subDisplay";
			if (defined ($r->param("hide_course"))) {
				@errors = $self->hide_course_validate;
				if (@errors) {
					$method_to_call = "hide_inactive_course_form";
				} else {
				$method_to_call = "do_hide_inactive_course";
			  }
			}  
			elsif (defined ($r->param("unhide_course"))) {
				@errors = $self->unhide_course_validate;
				if (@errors) {
					$method_to_call = "hide_inactive_course_form";
				} else {
				$method_to_call = "do_unhide_inactive_course";
			  }
			} 
			elsif (defined ($r->param("hide_course_refresh"))) {
				$method_to_call = "hide_inactive_course_form";
			}
			else{
				$method_to_call = "hide_inactive_course_form";
			}
		}		
		elsif ($subDisplay eq "registration") {
			if (defined ($r->param("register_site"))) {
				$method_to_call =  "do_registration";
			}
			else{
				$method_to_call = "registration_form";
			}
		}
		else {
			@errors = "Unrecognized sub-display @{[ CGI::b($subDisplay) ]}.";
		}
	}
	
	$self->{errors} = \@errors;
	$self->{method_to_call} = $method_to_call;
}

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $user = $r->param('user');
	
	# check permissions
	unless ($authz->hasPermissions($user, "create_and_delete_courses")) {
		return "";
	}
	my $method_to_call = $self->{method_to_call};
	my $methodMessage ="";
	
	(defined($method_to_call) and $method_to_call eq "do_export_database") && do {
	    my @export_courseID = $r->param("export_courseID");
	    my $course_ids = join(", ", @export_courseID);
		$methodMessage  = CGI::p("Exporting database for course(s) $course_ids").
		CGI::p(".... please wait.... 
		If your browser times out you will
		still be able to download the exported database using the 
		file manager.").CGI::hr();
	};
	
	
	print CGI::p({style=>"text-align: center"},
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"add_course",add_admin_users=>1,
		           add_dbLayout=>'sql_single', 
		           add_templates_course => $ce->{siteDefaults}->{default_templates_course} ||""}
		           )}, 
		           $r->maketext("Add Course")
		),
		" | ",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"rename_course"})}, $r->maketext("Rename Course")),
		" | ",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"delete_course"})}, $r->maketext("Delete Course")),
		" | ",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"archive_course"})}, $r->maketext("Archive Course")),
		 "|",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"unarchive_course"})}, $r->maketext("Unarchive Course")),
		 "|",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"upgrade_course"})}, $r->maketext("Upgrade Courses")),
		 "|",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"manage_locations"})}, $r->maketext("Manage Locations")),
		 "|",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"hide_inactive_course"})}, $r->maketext("Hide Inactive Courses")),
		CGI::hr(),
		$methodMessage,
		
	);
	
	print( CGI::p({style=>"text-align: center"}, $self->display_registration_form() ) ) if $self->display_registration_form();
	
	my @errors = @{$self->{errors}};
	
	
	if (@errors) {
		print CGI::div({class=>"ResultsWithError"},
			CGI::p($r->maketext("Please correct the following errors and try again:")),
			CGI::ul(CGI::li(\@errors)),
		);
	}
	
	if (defined $method_to_call and $method_to_call ne "") {
		$self->$method_to_call;
	} else {
		    my $msg = "";
	    	$msg .= CGI::li($r->maketext("unable to write to directory [_1]", $ce->{webworkDirs}{logs}))  unless -w $ce->{webworkDirs}{logs}; 
	    	$msg .=  CGI::li($r->maketext("unable to write to directory [_1]", $ce->{webworkDirs}{tmp}))  unless -w $ce->{webworkDirs}{tmp}; 
	    	$msg .=  CGI::li($r->maketext("unable to write to directory [_1]", $ce->{webworkDirs}{DATA}))  unless -w $ce->{webworkDirs}{DATA}; 
	    	if ($msg) {
		  print CGI::h2($r->maketext("Directory permission errors ")).CGI::ul($msg).
		    CGI::p($r->maketext("The webwork server must be able to write to these directories. Please correct the permssion errors.")) ;
			}
	
		print $self->upgrade_notification();

		print CGI::h2($r->maketext("Courses"));
	
		print CGI::start_ol();
		
		my @courseIDs = listCourses($ce);
		foreach my $courseID (sort {lc($a) cmp lc($b) } @courseIDs) {
			next if $courseID eq "admin"; # done already above
			next if $courseID eq "modelCourse"; # modelCourse isn't a real course so don't create missing directories, etc
 			my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => $courseID);
			print CGI::li(CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, $courseID));
		}
		
		print CGI::end_ol();
		
		print CGI::h2($r->maketext("Archived Courses"));
		print CGI::start_ol();
		
		@courseIDs = listArchivedCourses($ce);
		foreach my $courseID (sort {lc($a) cmp lc($b) } @courseIDs) {
			print CGI::li($courseID),	 
		}
		
		print CGI::end_ol();
	}
	return "";
}

################################################################################

sub add_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
	my $add_courseID                     = trim_spaces( $r->param("add_courseID") ) || "";
	my $add_courseTitle                  = trim_spaces( $r->param("add_courseTitle") ) || "";
	my $add_courseInstitution            = trim_spaces( $r->param("add_courseInstitution") ) || "";
	
	my $add_admin_users                  = trim_spaces( $r->param("add_admin_users") ) || "";
	
	my $add_initial_userID               = trim_spaces( $r->param("add_initial_userID") ) || "";
	my $add_initial_password             = trim_spaces( $r->param("add_initial_password") ) || "";
	my $add_initial_confirmPassword      = trim_spaces( $r->param("add_initial_confirmPassword") ) || "";
	my $add_initial_firstName            = trim_spaces( $r->param("add_initial_firstName") ) || "";
	my $add_initial_lastName             = trim_spaces( $r->param("add_initial_lastName") ) || "";
	my $add_initial_email                = trim_spaces( $r->param("add_initial_email") ) || "";
	
	my $add_templates_course             = trim_spaces( $r->param("add_templates_course") ) || "";
	
	my $add_dbLayout                     = trim_spaces( $r->param("add_dbLayout") ) || "";
	



	my @dbLayouts = do {
		my @ordered_layouts;
		foreach my $layout (@{$ce->{dbLayout_order}}) {
			if (exists $ce->{dbLayouts}->{$layout}) {
				push @ordered_layouts, $layout;
			}
		}
		
		my %ordered_layouts; @ordered_layouts{@ordered_layouts} = ();
		my @other_layouts;
		foreach my $layout (keys %{ $ce->{dbLayouts} }) {
			unless (exists $ordered_layouts{$layout}) {
				push @other_layouts, $layout;
			}
		}
		
		(@ordered_layouts, @other_layouts);
	};
	
	# unused...
	#my $ce2 = new WeBWorK::CourseEnvironment({
	#	%WeBWorK::SeedCE,
	#	courseName => "COURSENAME",
	#});
	
	my @existingCourses = listCourses($ce);
	@existingCourses = sort { lc($a) cmp lc ($b) } @existingCourses; #make sort case insensitive 
	
	print CGI::h2($r->maketext("Add Course"));
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p($r->maketext("Specify an ID, title, and institution for the new course. The course ID may contain only letters, numbers, hyphens, and underscores."));
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, $r->maketext("Course ID:")),
			CGI::td(CGI::textfield(-name=>"add_courseID", -value=>$add_courseID, -size=>25, -maxlength=>$ce->{maxCourseIdLength})),
		),
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, $r->maketext("Course Title:")),
			CGI::td(CGI::textfield(-name=>"add_courseTitle", -value=>$add_courseTitle, -size=>25)),
		),
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, $r->maketext("Institution:")),
			CGI::td(CGI::textfield(-name=>"add_courseInstitution", -value=>$add_courseInstitution, -size=>25)),
		),
	);
	
	print CGI::p($r->maketext("To add the WeBWorK administrators to the new course (as administrators) check the box below."));
	my @checked = ($add_admin_users) ?(checked=>1): ();  # workaround because CGI::checkbox seems to have a bug -- it won't default to checked.
	print CGI::p({},CGI::input({-type=>'checkbox', -name=>"add_admin_users", @checked }, $r->maketext("Add WeBWorK administrators to new course")));

	print CGI::p($r->maketext("To add an additional instructor to the new course, specify user information below. The user ID may contain only numbers, letters, hyphens, periods (dots), commas,and underscores.\n"));
	
	print CGI::table({class=>"FormLayout"}, CGI::Tr({},
		CGI::td({},
			CGI::table({class=>"FormLayout"},
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, $r->maketext("User ID").":"),
					CGI::td(CGI::textfield(-name=>"add_initial_userID", -value=>$add_initial_userID, -size=>25)),
				),
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, $r->maketext("Password:")),
					CGI::td(CGI::password_field(-name=>"add_initial_password", -value=>$add_initial_password, -size=>25)),
				),
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, $r->maketext("Confirm Password:")),
					CGI::td(CGI::password_field(-name=>"add_initial_confirmPassword", -value=>$add_initial_confirmPassword, -size=>25)),
				),
			),
		),
		CGI::td({},
			CGI::table({class=>"FormLayout"},
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, $r->maketext("First Name").":"),
					CGI::td(CGI::textfield(-name=>"add_initial_firstName", -value=>$add_initial_firstName, -size=>25)),
				),
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, $r->maketext("Last Name").":"),
					CGI::td(CGI::textfield(-name=>"add_initial_lastName", -value=>$add_initial_lastName, -size=>25)),
				),
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, $r->maketext("Email Address").":"),
					CGI::td(CGI::textfield(-name=>"add_initial_email", -value=>$add_initial_email, -size=>25)),
				),
			),
			
		),
	));
	
	print CGI::p($r->maketext("To copy problem templates from an existing course, select the course below."));
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, $r->maketext("Copy templates from:")),
			CGI::td(
				CGI::popup_menu(
					-name => "add_templates_course",
					-values => [ "", @existingCourses ],
					-default => $add_templates_course,
					#-size => 10,
					#-multiple => 0,
					#-labels => \%courseLabels,
				),

			),
		),
	);
	
	#  We dont use different databases any more so I am commenting this
	# out and adding the database type as a hidden field GG

	print CGI::input({type=>"hidden", name=>"add_dbLayout", value=>"sql_single"});
	
#	print CGI::p($r->maketext("Select a database layout below."));
#	print CGI::start_table({class=>"FormLayout"});
	
#	my %dbLayout_buttons;
#	my $selected_dbLayout = defined $add_dbLayout ? $add_dbLayout : $ce->{dbLayout_order}[0];
#	@dbLayout_buttons{@dbLayouts} = CGI::radio_group(-name=>"add_dbLayout",-values=>\@dbLayouts,-default=>$selected_dbLayout);
#	foreach my $dbLayout (@dbLayouts) {
#		my $dbLayoutLabel = (defined $ce->{dbLayout_descr}{$dbLayout})
#			? "$dbLayout - " . $ce->{dbLayout_descr}{$dbLayout}
#			: "$dbLayout - no description provided in global.conf";
#		print CGI::Tr({},
#			CGI::td({width=>'20%'}, $dbLayout_buttons{$dbLayout}),
#			CGI::td($dbLayoutLabel),
#		);
#	}
#	print CGI::end_table();


	
	print CGI::p({style=>"text-align: left"}, CGI::submit(-name=>"add_course", -label=>$r->maketext("Add Course")));
	
	print CGI::end_form();
}

sub add_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	

	my $add_courseID                     = trim_spaces( $r->param("add_courseID") ) || "";
	my $add_courseTitle                  = trim_spaces( $r->param("add_courseTitle") ) || "";
	my $add_courseInstitution            = trim_spaces( $r->param("add_courseInstitution") ) || "";
	
	my $add_admin_users                  = trim_spaces( $r->param("add_admin_users") ) || "";
	
	my $add_initial_userID               = trim_spaces( $r->param("add_initial_userID") ) || "";
	my $add_initial_password             = trim_spaces( $r->param("add_initial_password") ) || "";
	my $add_initial_confirmPassword      = trim_spaces( $r->param("add_initial_confirmPassword") ) || "";
	my $add_initial_firstName            = trim_spaces( $r->param("add_initial_firstName") ) || "";
	my $add_initial_lastName             = trim_spaces( $r->param("add_initial_lastName") ) || "";
	my $add_initial_email                = trim_spaces( $r->param("add_initial_email") ) || "";
	my $add_templates_course             = trim_spaces( $r->param("add_templates_course") ) || "";
	my $add_dbLayout                     = trim_spaces( $r->param("add_dbLayout") ) || "";
	
	

	
	######################
	
	my @errors;
	
	if ($add_courseID eq "") {
		push @errors, $r->maketext("You must specify a course ID.");
	}
	unless ($add_courseID =~ /^[\w-]*$/) { # regex copied from CourseAdministration.pm
		push @errors, $r->maketext("Course ID may only contain letters, numbers, hyphens, and underscores.");
	}
	if (grep { $add_courseID eq $_ } listCourses($ce)) {
		push @errors, $r->maketext("A course with ID [_1] already exists.", $add_courseID);
	}
	
	if ($add_initial_userID ne "") {
		if ($add_initial_password eq "") {
			push @errors, $r->maketext("You must specify a password for the initial instructor.");
		}
		if ($add_initial_confirmPassword eq "") {
			push @errors, $r->maketext("You must confirm the password for the initial instructor.");
		}
		if ($add_initial_password ne $add_initial_confirmPassword) {
			push @errors, $r->maketext("The password and password confirmation for the instructor must match.");
		}
		if ($add_initial_firstName eq "") {
			push @errors, $r->maketext("You must specify a first name for the initial instructor.");
		}
		if ($add_initial_lastName eq "") {
			push @errors, $r->maketext("You must specify a last name for the initial instructor.");
		}
		if ($add_initial_email eq "") {
			push @errors, $r->maketext("You must specify an email address for the initial instructor.");
		}
	}
	
	if ($add_dbLayout eq "") {
		push @errors, "You must select a database layout.";
	} else {
		if (exists $ce->{dbLayouts}->{$add_dbLayout}) {
			# we used to check for layout-specific fields here, but there aren't any layouts that require them
			# anymore. (in the future, we'll probably deal with this in layout-specific modules.)
		} else {
			push @errors, "The database layout $add_dbLayout doesn't exist.";
		}
	}
	
	return @errors;
}

sub do_add_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $add_courseID                     = trim_spaces( $r->param("add_courseID") ) || "";
	my $add_courseTitle                  = trim_spaces( $r->param("add_courseTitle") ) || "";
	my $add_courseInstitution            = trim_spaces( $r->param("add_courseInstitution") ) || "";
	
	my $add_admin_users                  = trim_spaces( $r->param("add_admin_users") ) || "";
	
	my $add_initial_userID               = trim_spaces( $r->param("add_initial_userID") ) || "";
	my $add_initial_password             = trim_spaces( $r->param("add_initial_password") ) || "";
	my $add_initial_confirmPassword      = trim_spaces( $r->param("add_initial_confirmPassword") ) || "";
	my $add_initial_firstName            = trim_spaces( $r->param("add_initial_firstName") ) || "";
	my $add_initial_lastName             = trim_spaces( $r->param("add_initial_lastName") ) || "";
	my $add_initial_email                = trim_spaces( $r->param("add_initial_email") ) || "";
	
	my $add_templates_course             = trim_spaces( $r->param("add_templates_course") ) || "";
	
	my $add_dbLayout                     = trim_spaces( $r->param("add_dbLayout") ) || "";
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $add_courseID,
	});
	
	my %courseOptions = ( dbLayoutName => $add_dbLayout );
	
	if ($add_initial_email ne "") {
		$courseOptions{allowedRecipients} = [ $add_initial_email ];
		# don't set feedbackRecipients -- this just gets in the way of the more
		# intelligent "receive_recipients" method.
		#$courseOptions{feedbackRecipients} = [ $add_initial_email ];
	}
	
	# this is kinda left over from when we had 'gdbm' and 'sql' database layouts
	# below this line, we would grab values from getopt and put them in this hash
	# but for now the hash can remain empty
	my %dbOptions;
	
	my @users;
	
	# copy users from current (admin) course if desired
	if ($add_admin_users ne "") {

	    foreach my $userID ($db->listUsers) {
		if ($userID eq $add_initial_userID) {
		    $self->addbadmessage($r->maketext("User '[_1]' will not be copied from admin course as it is the initial instructor.",$userID));
		    next;
		}
		my $PermissionLevel = $db->newPermissionLevel();
		$PermissionLevel->user_id($userID);
		$PermissionLevel->permission($ce->{userRoles}->{admin});
		my $User            = $db->getUser($userID);
		my $Password        = $db->getPassword($userID);
		
		push @users, [ $User, $Password, $PermissionLevel ] 
		    if $authz->hasPermissions($userID,"create_and_delete_courses");  
		#only transfer the "instructors" in the admin course classlist.
	    }
	}
	
	# add initial instructor if desired
	if ($add_initial_userID ne "") {
		my $User = $db->newUser(
			user_id       => $add_initial_userID,
			first_name    => $add_initial_firstName,
			last_name     => $add_initial_lastName,
			student_id    => $add_initial_userID,
			email_address => $add_initial_email,
			status        => "C",
		);
		my $Password = $db->newPassword(
			user_id  => $add_initial_userID,
			password => cryptPassword($add_initial_password),
		);
		my $PermissionLevel = $db->newPermissionLevel(
			user_id    => $add_initial_userID,
			permission => "10",
		);
		push @users, [ $User, $Password, $PermissionLevel ];
	}
	
	push @{$courseOptions{PRINT_FILE_NAMES_FOR}}, map { $_->[0]->user_id } @users;

	# include any optional arguments, including a template course and the 
	# course title and course institution. 
	my %optional_arguments;
	if ($add_templates_course ne "") {
		$optional_arguments{templatesFrom} = $add_templates_course;
	}
	if ($add_courseTitle ne "") {
		$optional_arguments{courseTitle} = $add_courseTitle;
	}
	if ($add_courseInstitution ne "") {
		$optional_arguments{courseInstitution} = $add_courseInstitution;
	}

	eval {
		addCourse(
			courseID      => $add_courseID,
			ce            => $ce2,
			courseOptions => \%courseOptions,
			dbOptions     => \%dbOptions,
			users         => \@users,
			%optional_arguments,
		);
	};
	if ($@) {
		my $error = $@;
		print CGI::div({class=>"ResultsWithError"},
			CGI::p("An error occured while creating the course $add_courseID:"),
			CGI::tt(CGI::escapeHTML($error)),
		);
		# get rid of any partially built courses
		# FIXME  -- this is too fragile
		unless ($error =~ /course exists/) {
			eval {
				deleteCourse(
					courseID   => $add_courseID,
					ce         => $ce2,
					dbOptions  => \%dbOptions,
				);
			}
		}
	} else {
	    #log the action
	    writeLog($ce, "hosted_courses", join("\t",
	    	"\tAdded",
	    	( defined $add_courseInstitution ? $add_courseInstitution : "(no institution specified)" ),
	    	( defined $add_courseTitle ? $add_courseTitle : "(no title specified)" ),
	    	$add_courseID,
	    	$add_initial_firstName,
	    	$add_initial_lastName,
	  		$add_initial_email,
	    ));
	    # add contact to admin course as student?
	    # FIXME -- should we do this?
	    if ($add_initial_userID ne "") {
	        my $composite_id = "${add_initial_userID}_${add_courseID}"; # student id includes school name and contact
			my $User = $db->newUser(
			user_id       => $composite_id,          # student id includes school name and contact
			first_name    => $add_initial_firstName,
			last_name     => $add_initial_lastName,
			student_id    => $add_initial_userID,
			email_address => $add_initial_email,
			status        => "C",
			);
			my $Password = $db->newPassword(
				user_id  => $composite_id,
				password => cryptPassword($add_initial_password),
			);
			my $PermissionLevel = $db->newPermissionLevel(
				user_id    => $composite_id,
				permission => "0",
			);
			# add contact to admin course as student
			# or if this contact and course already exist in a dropped status
			# change the student's status to enrolled
			if (my $oldUser = $db->getUser($composite_id) ) {
				warn "Replacing old data for $composite_id  status: ". $oldUser->status;
				$db->deleteUser($composite_id);
			}
			eval { $db->addUser($User)                       }; warn $@ if $@;
			eval { $db->addPassword($Password)               }; warn $@ if $@;
			eval { $db->addPermissionLevel($PermissionLevel) }; warn $@ if $@;
		}
		print CGI::div({class=>"ResultsWithoutError"},
			CGI::p($r->maketext("Successfully created the course [_1]", $add_courseID)),
		);
		my $newCoursePath = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r,
			courseID => $add_courseID);
		my $newCourseURL = $self->systemLink($newCoursePath, authen => 0);
		print CGI::div({style=>"text-align: center"},
			CGI::a({href=>$newCourseURL}, $r->maketext("Log into [_1]",$add_courseID)),
		);
	}

	
}

################################################################################

sub rename_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
#	my $rename_oldCourseID     = $r->param("rename_oldCourseID")     || "";
#	my $rename_newCourseID     = $r->param("rename_newCourseID")     || "";

	my $rename_oldCourseID           = $r->param("rename_oldCourseID")     || "";
	my $rename_newCourseID           = $r->param("rename_newCourseID")     || "";
	my $rename_newCourseID_checked   = $r->param("rename_newCourseID_checked")     || "";
	my $rename_newCourseID_checkbox     = $r->param("rename_newCourseID_checkbox")     || "";

	my $rename_newCourseTitle           = $r->param("rename_newCourseTitle")     || "";
	my $rename_newCourseTitle_checked   = $r->param("rename_newCourseTitle_checked")     || "";
	my $rename_newCourseTitle_checkbox     = $r->param("rename_newCourseTitle_checkbox")     || "";

	my $rename_newCourseInstitution           = $r->param("rename_newCourseInstitution")     || "";
	my $rename_newCourseInstitution_checked   = $r->param("rename_newCourseInstitution_checked")     || "";
	my $rename_newCourseInstitution_checkbox     = $r->param("rename_newCourseInstitution_checkbox")     || "";



	
	my @courseIDs = listCourses($ce);
	@courseIDs    = sort {lc($a) cmp lc ($b) } @courseIDs;
	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
		$courseLabels{$courseID} = "$courseID";
	}
	
	print CGI::h2($r->maketext("Rename Course"));
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p($r->maketext("Select a course to rename.  The courseID is used in the url and can only contain alphanumeric characters and underscores. The course title appears on the course home page and can be any string."));
	
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, $r->maketext("Course ID:")),
			CGI::td(
				CGI::scrolling_list(
					-name => "rename_oldCourseID",
					-values => \@courseIDs,
					-default => $rename_oldCourseID,
					-size => 10,
					-multiple => 0,
					-labels => \%courseLabels,
				),
			),
		),
		CGI::Tr({},
			CGI::td( CGI::checkbox(
				{name=>"rename_newCourseID_checkbox", 
				 label=>$r->maketext('Change CourseID to:'), 
				 checked=>$rename_newCourseID_checkbox,
				 value=>'on',
				 }) ),
			#CGI::th({class=>"LeftHeader"}, "New CourseID:"),
			CGI::td(CGI::textfield(-name=>"rename_newCourseID",
			     -value=>$rename_newCourseID, -size=>25, -maxlength=>$ce->{maxCourseIdLength})),
		),
		CGI::Tr({},
			CGI::td( CGI::checkbox(
				{name=>"rename_newCourseTitle_checkbox", 
				 -label=>$r->maketext('Change Course Title to:'), 
				 -selected=>$rename_newCourseTitle_checkbox,
				 -value=>'on'
				 }) ),
			#CGI::th({class=>"LeftHeader"}, "Change Course Title to:"),
			CGI::td(CGI::textfield(-name=>"rename_newCourseTitle",
					 -value=>$rename_newCourseTitle, -size=>25)),
		),
		CGI::Tr({},
			CGI::td( CGI::checkbox(
				{name=>"rename_newCourseInstitution_checkbox", 
				 label=>$r->maketext('Change Institution to:'), 
				 checked=>$rename_newCourseInstitution_checkbox,
				 value=>'on'
				 }) ),
			#CGI::th({class=>"LeftHeader"}, "Change institution to:"),
			CGI::td(CGI::textfield(-name=>"rename_newCourseInstitution", 
			      -value=>$rename_newCourseInstitution, -size=>25)),
		),
	);
	
	print CGI::end_table();
	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"rename_course", -label=>$r->maketext("Rename Course")));
	
	print CGI::end_form();
}
sub rename_course_confirm {

    my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

	my $rename_oldCourseID           = $r->param("rename_oldCourseID")     || "";
	my $rename_newCourseID           = $r->param("rename_newCourseID")     || "";
	my $rename_newCourseID_checkbox     = $r->param("rename_newCourseID_checkbox")  || "";    ;

	my $rename_newCourseTitle           = $r->param("rename_newCourseTitle")     || "";
	my $rename_newCourseTitle_checkbox  = $r->param("rename_newCourseTitle_checkbox")    || ""; ;
 	my $rename_newCourseInstitution           = $r->param("rename_newCourseInstitution")     || "";
	my $rename_newCourseInstitution_checkbox     = $r->param("rename_newCourseInstitution_checkbox") || ""   ;


	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $rename_oldCourseID,
	});
######################################################
## Create strings confirming title and institution change
######################################################
	# connect to database to get old title and institution
	my $dbLayoutName = $ce->{dbLayoutName};
	my $db = new WeBWorK::DB($ce->{dbLayouts}->{$dbLayoutName});
	my $oldDB =new WeBWorK::DB($ce2->{dbLayouts}->{$dbLayoutName});
	my $rename_oldCourseTitle = $oldDB->getSettingValue('courseTitle')//'""';
	my $rename_oldCourseInstitution = $oldDB->getSettingValue('courseInstitution')//'""';
	
	my ($change_course_title_str, $change_course_institution_str)=("");
	if ( $rename_newCourseTitle_checkbox) {
		$change_course_title_str =$r->maketext("Change title from [_1] to [_2]", $rename_oldCourseTitle, $rename_newCourseTitle);
	}
	if ( $rename_newCourseInstitution_checkbox) {
		$change_course_institution_str=$r->maketext("Change course institution from [_1] to [_2]", $rename_oldCourseInstitution, $rename_newCourseInstitution);
	}

#############################################################################
# If we are only changing the title or institution we can cut this short
#############################################################################
	unless ($rename_newCourseID_checkbox) {  # in this case do not change course ID
		print CGI::start_form(-method=>"POST", -action=>$r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		print $self->hidden_fields(qw/rename_oldCourseID rename_newCourseID
		  rename_newCourseTitle rename_newCourseInstitution
		  rename_newCourseID_checkbox rename_newCourseInstitution_checkbox
		  rename_newCourseTitle_checkbox /);
		print CGI::hidden(-name=>"rename_oldCourseTitle", 
					  -default=>$rename_oldCourseTitle, 
		              -id=>"hidden_rename_oldCourseTitle");
		print CGI::hidden(-name=>"rename_oldCourseInstitution", 
		              -default=>$rename_oldCourseInstitution, 
		              -id=>"hidden_rename_oldCourseInstitution");

		print CGI::div({style=>"text-align: left"},
			    CGI::hr(),			    
			    CGI::h4($r->maketext("Make these changes in  course:")." $rename_oldCourseID"),
			    CGI::p($change_course_title_str),
			    CGI::p($change_course_institution_str),
				CGI::submit(-name=>"decline_retitle_course", -value=>$r->maketext("Don't make changes")),
				"&nbsp;",
				CGI::submit(-name=>"confirm_retitle_course", -value=>$r->maketext("Make changes")) ,
			    CGI::hr(),
			);
		 print CGI::end_form();
         return;
	}

#############################################################################
# Check database
#############################################################################
	
	my ($tables_ok,$dbStatus);
	if ($ce2->{dbLayoutName} ) {
	     my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce=>$ce2);
	    ($tables_ok,$dbStatus) = $CIchecker->checkCourseTables($rename_oldCourseID);
		if ($r->param("upgrade_course_tables")) {
			my @schema_table_names = keys %$dbStatus;  # update tables missing from database;
			my @tables_to_create = grep {$dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A} @schema_table_names;
			my @tables_to_alter  = grep {$dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B} @schema_table_names;
			my $msg = $CIchecker->updateCourseTables($rename_oldCourseID, [@tables_to_create]);
			foreach my $table_name (@tables_to_alter) {
				$msg .= $CIchecker->updateTableFields($rename_oldCourseID, $table_name);
			}
			print CGI::p({-style=>'color:green; font-weight:bold'}, $msg);
			
		}
 		($tables_ok,$dbStatus) = $CIchecker->checkCourseTables($rename_oldCourseID);
 

		# print db status

		my %msg =(    WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A         => CGI::span({style=>"color:red"},$r->maketext("Table defined in schema but missing in database")),
		              WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B         => CGI::span({style=>"color:red"},$r->maketext("Table defined in database but missing in schema")),
		              WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B   => CGI::span({style=>"color:green"},$r->maketext("Table is ok")),
		              WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => CGI::span({style=>"color:red"},$r->maketext("Schema and database table definitions do not agree")),
		);
		my %msg2 =(    WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A        => CGI::span({style=>"color:red"},$r->maketext("Field missing in database")),
		              WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B         => CGI::span({style=>"color:red"},$r->maketext("Field missing in schema")),
		              WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B   => CGI::span({style=>"color:green"},$r->maketext("Field is ok")),
		              WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => CGI::span({style=>"color:red"},$r->maketext("Schema and database field definitions do not agree")),
		);
		my $all_tables_ok=1;
		my $extra_database_tables=0;
		my $extra_database_fields=0;
		my $str=CGI::h4($r->maketext("Report on database structure for course [_1]:",  $rename_oldCourseID)).CGI::br();
		foreach my $table (sort keys %$dbStatus) {
		    my $table_status = $dbStatus->{$table}->[0];
			$str .= CGI::b($table).': '. $msg{ $table_status } . CGI::br();
			
			CASE: {
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B 
					&& do{ last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A
					&& do{
						   $all_tables_ok = 0; last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B
					&& do{
						   $extra_database_tables = 1; last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B
					&& do{ 
					    my %fieldInfo = %{ $dbStatus->{$table}->[1] };
						foreach my $key (keys %fieldInfo) {
						    my $field_status = $fieldInfo{$key}->[0];
						    CASE2: {
						    	$field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B 
						    		&& do{ 
						    		   $extra_database_fields = 1; last CASE2;
						    		};
						    	$field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A 
						    		&& do{ 
						    		   $all_tables_ok=0; last CASE2;
						    		};						    
						    }
							$str .= CGI::br()."\n&nbsp;&nbsp; $key => ". $msg2{$field_status };
						}							
					};
			}
			$str.=CGI::br();
			
		}
#############################################################################
# Report on databases
#############################################################################

		print CGI::p($str);
		if ($extra_database_tables) {
				print CGI::p({-style=>'color:red; font-weight:bold'},$r->maketext("There are extra database tables which are not defined in the schema.  They can only be removed manually from the database. They will not be renamed."));
		} 
		if ($extra_database_fields) {
				print CGI::p({-style=>'color:red; font-weight:bold'},$r->maketext("There are extra database fields  which are not defined in the schema for at least one table.  They can only be removed manually from the database."));
		} 		
		if ($all_tables_ok) {
			print CGI::p({-style=>'color:green; font-weight:bold'},$r->maketext("Course [_1] database is in order",$rename_oldCourseID));
		} else {
			print CGI::p({-style=>'color:red; font-weight:bold'}, $r->maketext("Course [_1] databases must be updated before renaming this course.",$rename_oldCourseID));
		}	
		
#############################################################################
# Check directories
#############################################################################


      my ($directories_ok, $str2) = $CIchecker->checkCourseDirectories($ce2);
      my $style = ($directories_ok)?"color:green" : "color:red";
      print CGI::h2("Directory structure"), CGI::p($str2),
      ($directories_ok)? CGI::p({style=>$style},$r->maketext("Directory structure is ok")) :
              CGI::p({style=>$style},$r->maketext("Directory structure is missing directories or the webserver lacks sufficient privileges."));
    
#############################################################################
# Print form for choosing next action.
#############################################################################



		print CGI::start_form(-method=>"POST", -action=>$r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		print $self->hidden_fields(qw/rename_oldCourseID rename_newCourseID
		  rename_newCourseTitle rename_newCourseInstitution
		  rename_newCourseID_checkbox rename_newCourseInstitution_checkbox
		  rename_newCourseTitle_checkbox /);
		print CGI::hidden(-name=>"rename_oldCourseTitle", 
					  -default=>$rename_oldCourseTitle, 
		              -id=>"hidden_rename_oldCourseTitle");
		print CGI::hidden(-name=>"rename_oldCourseInstitution", 
		              -default=>$rename_oldCourseInstitution, 
		              -id=>"hidden_rename_oldCourseInstitution");


			# grab some values we'll need
            # fail if the source course does not exist

		
		
		if ($all_tables_ok && $directories_ok ) { # no missing tables or missing fields or directories
			print CGI::p({style=>"text-align: center"},
			    CGI::hr(),
			    CGI::h4($r->maketext("Rename [_1] to [_2]", $rename_oldCourseID, $rename_newCourseID)),
			    CGI::div($change_course_title_str),
			    CGI::div($change_course_institution_str),
				CGI::submit(-name=>"decline_rename_course", -value=>$r->maketext("Don't rename")),
				"&nbsp;",
				CGI::submit(-name=>"confirm_rename_course", -value=>$r->maketext("Rename")) ,
			);
		} elsif(  $directories_ok  ) {
			print CGI::p({style=>"text-align: center"},
				CGI::submit(-name => "decline_rename_course", -value => $r->maketext("Don't rename")),
				"&nbsp;",
				CGI::submit(-name=>"upgrade_course_tables", -value=>$r->maketext("Upgrade Course Tables")),
			);
		} else  {
			print CGI::p({style=>"text-align: center"},
				CGI::submit(-name => "decline_rename_course", -value => $r->maketext("Don't rename")),
				CGI::br(),$r->maketext("Directory structure needs to be repaired manually before renaming.")
			);
		} 
		print CGI::end_form();
	}
}
sub rename_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	
	my $rename_oldCourseID              = $r->param("rename_oldCourseID")     || "";
	my $rename_newCourseID              = $r->param("rename_newCourseID")     || "";
	my $rename_newCourseID_checkbox     = $r->param("rename_newCourseID_checkbox")   || "";  ;

	my $rename_newCourseTitle           = $r->param("rename_newCourseTitle")     || "";
	my $rename_newCourseTitle_checkbox  = $r->param("rename_newCourseTitle_checkbox")  || ""   ;
 	my $rename_newCourseInstitution           = $r->param("rename_newCourseInstitution")     || "";
	my $rename_newCourseInstitution_checkbox     = $r->param("rename_newCourseInstitution_checkbox")  || ""  ;
	
	my @errors;
	
	if ($rename_oldCourseID eq "") {
		push @errors, $r->maketext("You must select a course to rename.");
	}
	if ($rename_newCourseID eq "" and $rename_newCourseID_checkbox eq 'on' ) {
		push @errors, $r->maketext("You must specify a new name for the course.");
	}
	if ($rename_oldCourseID eq $rename_newCourseID and $rename_newCourseID_checkbox eq 'on') {
		push @errors, $r->maketext("Can't rename to the same name.");
	}
	unless ($rename_newCourseID =~ /^[\w-]*$/) { # regex copied from CourseAdministration.pm
		push @errors, $r->maketext("Course ID may only contain letters, numbers, hyphens, and underscores.");
	}
	if (grep { $rename_newCourseID eq $_ } listCourses($ce)) {
		push @errors, $r->maketext("A course with ID [_1] already exists.",$rename_newCourseID);
	}
	if ($rename_newCourseTitle eq "" and $rename_newCourseTitle_checkbox eq 'on')  {
		push @errors, $r->maketext("You must specify a new title for the course.");
	}
	if ($rename_newCourseInstitution eq "" and $rename_newCourseInstitution_checkbox eq 'on')  {
		push @errors, $r->maketext("You must specify a new institution for the course.");
	}
	unless ($rename_newCourseID or $rename_newCourseID_checkbox or $rename_newCourseTitle_checkbox or $rename_newCourseInstitution_checkbox) {
		push @errors, $r->maketext("No changes specified.  You must mark the checkbox of the item(s) to be changed and enter the change data.");
	}
	
	return @errors;
}

sub do_retitle_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $rename_oldCourseID           = $r->param("rename_oldCourseID")     || "";
#	my $rename_newCourseID           = $r->param("rename_newCourseID")     || "";
#   There is no new course, but there are new titles and institutions
	my $rename_newCourseTitle         = $r->param("rename_newCourseTitle")     || "";
	my $rename_newCourseInstitution   = $r->param("rename_newCourseInstitution")     || "";
	my $rename_oldCourseTitle         = $r->param("rename_oldCourseTitle")     || "";
	my $rename_oldCourseInstitution   = $r->param("rename_oldCourseInstitution")     || "";
	my $title_checkbox                = $r->param("rename_newCourseTitle_checkbox")  || ""   ;
	my $institution_checkbox          = $r->param("rename_newCourseInstitution_checkbox")  || ""  ;
	
#	$rename_newCourseID = $rename_oldCourseID ;  #since they are the same FIXME
	# define new courseTitle and new courseInstitution
	my %optional_arguments = ();
	$optional_arguments{courseTitle}       = $rename_newCourseTitle if $title_checkbox;
	$optional_arguments{courseInstitution} = $rename_newCourseInstitution if $institution_checkbox;

	my $ce2;
	my %dbOptions =();
	eval {
		$ce2 = new WeBWorK::CourseEnvironment({
			%WeBWorK::SeedCE,
			courseName => $rename_oldCourseID,
		});
	};
	warn "failed to create environment in do_retitle_course $@" if $@;

	eval {  
		retitleCourse(
			courseID      => $rename_oldCourseID,
			ce            => $ce2,
			dbOptions     => \%dbOptions,
			%optional_arguments,
		);
	};
	if ($@) {
		my $error = $@;
		print CGI::div({class=>"ResultsWithError"},
			CGI::p( $r->maketext("An error occured while changing the title of the course [_1].", $rename_oldCourseID)),
			CGI::tt(CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div({class=>"ResultsWithoutError"},
			($title_checkbox) ? CGI::div($r->maketext("The title of the course [_1] has been changed from [_2] to [_3]",$rename_oldCourseID, $rename_oldCourseTitle, $rename_newCourseTitle))
			:'', 
			($institution_checkbox) ? CGI::div($r->maketext("The institution associated with the course [_1] has been changed from [_2] to [_3]",$rename_oldCourseID, $rename_oldCourseInstitution, $rename_newCourseInstitution))
			:'', 
		);
		 writeLog($ce, "hosted_courses", join("\t",
	    	"\t",$r->maketext("Retitled"),
	    	"",
	    	"",
		$r->maketext("[_1] title and institution changed from [_2] to [_3] and from [_4] to [_5]",$rename_oldCourseID, $rename_oldCourseTitle, $rename_newCourseTitle, $rename_oldCourseInstitution, $rename_newCourseInstitution)
	    ));		
		my $oldCoursePath = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r,
			courseID => $rename_oldCourseID);
		my $oldCourseURL = $self->systemLink($oldCoursePath, authen => 0);
		print CGI::div({style=>"text-align: center"},
			CGI::a({href=>$oldCourseURL}, $r->maketext("Log into [_1]", $rename_oldCourseID)),
		);
	}
}

sub do_rename_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $rename_oldCourseID            = $r->param("rename_oldCourseID")     || "";
	my $rename_newCourseID            = $r->param("rename_newCourseID")     || "";
	my $rename_newCourseTitle         = $r->param("rename_newCourseTitle")     || "";
	my $rename_newCourseInstitution   = $r->param("rename_newCourseInstitution")     || "";
	my $title_checkbox                = $r->param("rename_newCourseTitle_checkbox")  || ""   ;
	my $institution_checkbox          = $r->param("rename_newCourseInstitution_checkbox")  || ""  ;
	

	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $rename_oldCourseID,
	});

	my $dbLayoutName = $ce->{dbLayoutName};

	# define new courseTitle and new courseInstitution
	my %optional_arguments = ();
	my ($title_message, $institution_message);
	if ($title_checkbox) {
		$optional_arguments{courseTitle}       = $rename_newCourseTitle;
		$title_message = $r->maketext("The title of the course [_1] is now [_2]", $rename_newCourseID, $rename_newCourseTitle) , 
	
	} else {
		
	}
	if ($institution_checkbox) {
		$optional_arguments{courseInstitution} = $rename_newCourseInstitution;
		$institution_message = $r->maketext("The institution associated with the course [_1] is now [_2]", $rename_newCourseID, $rename_newCourseInstitution), 

	}

		
	# this is kinda left over from when we had 'gdbm' and 'sql' database layouts
	# below this line, we would grab values from getopt and put them in this hash
	# but for now the hash can remain empty
	my %dbOptions;

	eval {
		renameCourse(
			courseID      => $rename_oldCourseID,
			ce            => $ce2,
			dbOptions     => \%dbOptions,
			newCourseID   => $rename_newCourseID,
			%optional_arguments,
		);
	};
	if ($@) {
		my $error = $@;
		print CGI::div({class=>"ResultsWithError"},
			CGI::p( $r->maketext("An error occured while renaming the course [_1] to [_2]:", $rename_oldCourseID, $rename_newCourseID)),
			CGI::tt(CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div({class=>"ResultsWithoutError"},
			CGI::p($title_message),
			CGI::p($institution_message),
			CGI::p($r->maketext("Successfully renamed the course [_1] to [_2]", $rename_oldCourseID, $rename_newCourseID)),
		);
		 writeLog($ce, "hosted_courses", join("\t",
	    	"\tRenamed",
	    	"",
	    	"",
	    	"$rename_oldCourseID to $rename_newCourseID",
	    ));		
		my $newCoursePath = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r,
			courseID => $rename_newCourseID);
		my $newCourseURL = $self->systemLink($newCoursePath, authen => 0);
		print CGI::div({style=>"text-align: center"},
			CGI::a({href=>$newCourseURL}, $r->maketext("Log into [_1]", $rename_newCourseID)),
		);
	}
}

################################################################################

my %coursesData;	
sub byLoginActivity {$coursesData{$a}{'epoch_modify_time'} <=> $coursesData{$b}{'epoch_modify_time'}}

sub delete_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	
	my $coursesDir = $ce->{webworkDirs}->{courses};
	my @courseIDs = listCourses($ce);
#	@courseIDs    = sort {lc($a) cmp lc ($b) } @courseIDs; #make sort case insensitive 
	my $delete_listing_format   = $r->param("delete_listing_format"); 
	unless (defined $delete_listing_format) {$delete_listing_format = 'alphabetically';}  #use the default
	
	# Get and store last modify time for login.log for all courses. Also get visibility status.
	my %courseLabels;
	my @noLoginLogIDs = ();
	my @loginLogIDs = ();

	my ($loginLogFile, $epoch_modify_time, $courseDir);
	foreach my $courseID (@courseIDs) {
		$loginLogFile = "$coursesDir/$courseID/logs/login.log";
		if (-e $loginLogFile) {                 #this should always exist except for the model course
			$epoch_modify_time = stat($loginLogFile)->mtime;
			$coursesData{$courseID}{'epoch_modify_time'} = $epoch_modify_time;
			$coursesData{$courseID}{'local_modify_time'} = ctime($epoch_modify_time);
			push(@loginLogIDs,$courseID);
		} else {
			$coursesData{$courseID}{'local_modify_time'} = 'no login.log';  #this should never be the case except for the model course
			push(@noLoginLogIDs,$courseID);
		}
		if (-f "$coursesDir/$courseID/hide_directory") {
			$coursesData{$courseID}{'status'} = $r->maketext('hidden');
		} else {	
			$coursesData{$courseID}{'status'} = $r->maketext('visible');	
		}
		$courseLabels{$courseID} = "$courseID  ($coursesData{$courseID}{'status'} :: $coursesData{$courseID}{'local_modify_time'}) ";
	}
	if ($delete_listing_format eq 'last_login') {
		@noLoginLogIDs = sort {lc($a) cmp lc ($b) } @noLoginLogIDs; #this should be an empty arrey except for the model course
		@loginLogIDs = sort byLoginActivity @loginLogIDs;  # oldest first
		@courseIDs = (@noLoginLogIDs,@loginLogIDs);
	} else { # in this case we sort alphabetically
		@courseIDs = sort {lc($a) cmp lc ($b) } @courseIDs;
	}
		
	print CGI::h2( $r->maketext("Delete Course"));
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	my %list_labels = (
			   alphabetically => $r->maketext('alphabetically'), 
			   last_login => $r->maketext('by last login date'),
			  );
	print CGI::p(
		     $r->maketext('Courses are listed either alphabetically or in order by the time of most recent login activity, oldest first. To change the listing order check the mode you want and click "Refresh Listing".  The listing format is: Course_Name (status :: date/time of most recent login) where status is "hidden" or "visible".'));

	print CGI::table(
			CGI::Tr({},
			CGI::p($r->maketext("Select a listing format:")),
			CGI::radio_group(-name=>'delete_listing_format',
											-values=>['alphabetically', 'last_login'],
											-default=>'alphabetically',
											-labels=>\%list_labels,
											),
			),
		);	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"delete_course_refresh", -value=>$r->maketext("Refresh Listing")), 
	  CGI::submit(-name=>"delete_course", -value=>$r->maketext("Delete Course")));	
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	

	print CGI::p($r->maketext("Select a course to delete."));
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, $r->maketext("Course Name:")),
			CGI::td(
				CGI::scrolling_list(
					-name => "delete_courseID",
					-values => \@courseIDs,
					-default => $delete_courseID,
					-size => 15,
					-multiple => 0,
					-labels => \%courseLabels,
				),
			),
		),
	);
	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"delete_course_refresh", -value=>$r->maketext("Refresh Listing")), 
	  CGI::submit(-name=>"delete_course", -value=>$r->maketext("Delete Course")));	
	
	print CGI::end_form();
}

sub delete_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	
	my @errors;
	
	if ($delete_courseID eq "") {
		push @errors,  $r->maketext("You must specify a course name.");
	} elsif ($delete_courseID eq $urlpath->arg("courseID")) {
		push @errors,  $r->maketext("You cannot delete the course you are currently using.");
	}
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $delete_courseID,
	});
	
	return @errors;
}

sub delete_course_confirm {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	print CGI::h2( $r->maketext("Delete Course"));
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $delete_courseID,
	});
	
	print CGI::p($r->maketext("Are you sure you want to delete the course [_1]? All course files and data will be destroyed. There is no undo available.",CGI::b($delete_courseID)));
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	print $self->hidden_fields(qw/delete_courseID/);
	
	print CGI::p({style=>"text-align: center"},
		CGI::submit(-name=>"decline_delete_course", -label=>$r->maketext("Don't delete")),
		"&nbsp;",
		CGI::submit(-name=>"confirm_delete_course", -label=>$r->maketext("Delete")),
	);
	
	print CGI::end_form();
}

sub do_delete_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $delete_courseID,
	});
	
	# this is kinda left over from when we had 'gdbm' and 'sql' database layouts
	# below this line, we would grab values from getopt and put them in this hash
	# but for now the hash can remain empty
	my %dbOptions;
	
	eval {
		deleteCourse(
			courseID => $delete_courseID,
			ce => $ce2,
			dbOptions => \%dbOptions,
		);
	};
	
	if ($@) {
		my $error = $@;
		print CGI::div({class=>"ResultsWithError"},
			CGI::p( $r->maketext("An error occured while deleting the course [_1]:", $delete_courseID)),
			CGI::tt(CGI::escapeHTML($error)),
		);
	} else {
	    # mark the contact person in the admin course as dropped.
	    # find the contact person for the course by searching the admin classlist.
	    my @contacts = grep /_$delete_courseID$/,  $db->listUsers;
	    if (@contacts) {
			die "Incorrect number of contacts for the course $delete_courseID". join(" ", @contacts) if @contacts !=1;
			#warn "contacts", join(" ", @contacts);
			#my $composite_id = "${add_initial_userID}_${add_courseID}";
			my $composite_id  = $contacts[0];
			
			# mark the contact person as dropped.
			my $User = $db->getUser($composite_id);
			my $status_name = 'Drop';
			my $status_value = ($ce->status_name_to_abbrevs($status_name))[0];
			$User->status($status_value);
			$db->putUser($User);
		}
        
		print CGI::div({class=>"ResultsWithoutError"},
			       CGI::p($r->maketext("Successfully deleted the course [_1].",$delete_courseID)),
		);
		 writeLog($ce, "hosted_courses", join("\t",
	    	"\tDeleted",
	    	"",
	    	"",
	    	$delete_courseID,
	    ));
		print CGI::start_form(-method=>"POST", -action=>$r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		
		print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"decline_delete_course", -value=>$r->maketext("OK")),);
		
		print CGI::end_form();
	}
}

sub archive_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $archive_courseID     = $r->param("archive_courseID")     || "";
	
	my $coursesDir = $ce->{webworkDirs}->{courses};
	my @courseIDs = listCourses($ce);
#	@courseIDs    = sort {lc($a) cmp lc ($b) } @courseIDs; #make sort case insensitive
	my $archive_listing_format   = $r->param("archive_listing_format"); 
	unless (defined $archive_listing_format) {$archive_listing_format = 'alphabetically';}  #use the default
	
	# Get and store last modify time for login.log for all courses. Also get visibility status.
	my %courseLabels;
	my @noLoginLogIDs = ();
	my @loginLogIDs = ();

	my ($loginLogFile, $epoch_modify_time, $courseDir);
	foreach my $courseID (@courseIDs) {
		$loginLogFile = "$coursesDir/$courseID/logs/login.log";
		if (-e $loginLogFile) {                 #this should always exist except for the model course
			$epoch_modify_time = stat($loginLogFile)->mtime;
			$coursesData{$courseID}{'epoch_modify_time'} = $epoch_modify_time;
			$coursesData{$courseID}{'local_modify_time'} = ctime($epoch_modify_time);
			push(@loginLogIDs,$courseID);
		} else {
			$coursesData{$courseID}{'local_modify_time'} = 'no login.log';  #this should never be the case except for the model course
			push(@noLoginLogIDs,$courseID);
		}
		if (-f "$coursesDir/$courseID/hide_directory") {
			$coursesData{$courseID}{'status'} = $r->maketext('hidden');
		} else {	
			$coursesData{$courseID}{'status'} = $r->maketext('visible');	
		}
		$courseLabels{$courseID} = "$courseID  ($coursesData{$courseID}{'status'} :: $coursesData{$courseID}{'local_modify_time'}) ";
	}
	if ($archive_listing_format eq 'last_login') {
		@noLoginLogIDs = sort {lc($a) cmp lc ($b) } @noLoginLogIDs; #this should be an empty arrey except for the model course
		@loginLogIDs = sort byLoginActivity @loginLogIDs;  # oldest first
		@courseIDs = (@noLoginLogIDs,@loginLogIDs);
	} else { # in this case we sort alphabetically
		@courseIDs = sort {lc($a) cmp lc ($b) } @courseIDs;
	}
	
	print CGI::h2($r->maketext("Archive Course"));
	
	print CGI::p(
		     $r->maketext('Creates a gzipped tar archive (.tar.gz) of a course in the WeBWorK courses directory. Before archiving, the course database is dumped into a subdirectory of the course\'s DATA directory. Currently the archive facility is only available for mysql databases. It depends on the mysqldump application.')
	);
		print CGI::p(
		$r->maketext('Courses are listed either alphabetically or in order by the time of most recent login activity, oldest first. To change the listing order check the mode you want and click "Refresh Listing".  The listing format is: Course_Name (status :: date/time of most recent login) where status is "hidden" or "visible".'));

	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	my %list_labels = (
			   alphabetically => $r->maketext('alphabetically'), 
			   last_login => $r->maketext('by last login date'), 
								);
											
	print CGI::table(
			CGI::Tr({},
			CGI::p($r->maketext("Select a listing format:")),
			CGI::radio_group(-name=>'archive_listing_format',
											-values=>['alphabetically', 'last_login'],
											-default=>'alphabetically',
											-labels=>\%list_labels,
											),
			),
		);	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"archive_course_refresh", -value=>$r->maketext("Refresh Listing")), 
	  CGI::submit(-name=>"archive_course", -value=>$r->maketext("Archive Courses")));	
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p($r->maketext("Select course(s) to archive."));
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, $r->maketext("Course Name:")),
			CGI::td(
				CGI::scrolling_list(
					-name => "archive_courseIDs",
					-values => \@courseIDs,
					-default => $archive_courseID,
					-size => 15,
					-multiple => 1,
					-labels => \%courseLabels,
				),
			),
			
		),
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, $r->maketext("Delete course:")),
			CGI::td(CGI::div({-class=>'ResultsWithError'}, CGI::checkbox({ 
			                    -name=>'delete_course', 
			                    -checked=>0,
			                    -value => 1,
			                    -label =>$r->maketext('Delete course after archiving. Caution there is no undo!'),
			                   },
			       ),
			)),
		)
	);
	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"archive_course_refresh", -value=>$r->maketext("Refresh Listing")), 
	CGI::submit(-name=>"archive_course", -value=>$r->maketext("Archive Courses")));
	
	print CGI::end_form();
}

sub archive_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my @archive_courseIDs     = $r->param("archive_courseIDs");
	@archive_courseIDs        = () unless @archive_courseIDs;
	my @errors;
	foreach my $archive_courseID (@archive_courseIDs) {
		if ($archive_courseID eq "") {
			push @errors,  $r->maketext("You must specify a course name.");
		} elsif ($archive_courseID eq $urlpath->arg("courseID")) {
			push @errors,  $r->maketext("You cannot archive the course you are currently using.");
		}
	}
	
	#my $ce2 = new WeBWorK::CourseEnvironment({
	#	%WeBWorK::SeedCE,
	#	courseName => $archive_courseID,
	#});
	
	return @errors;
}

sub archive_course_confirm {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	print CGI::h2( $r->maketext("Archive Course"));
	
	my $delete_course_flag   = $r->param("delete_course")        || "";
	
	my @archive_courseIDs     = $r->param("archive_courseIDs");
	@archive_courseIDs        = () unless @archive_courseIDs;
	# if we are skipping a course remove one from
	# the list of courses
	if (defined $r->param("skip_archive_course")) {
	  shift @archive_courseIDs;
	}

	my $archive_courseID  = $archive_courseIDs[0];
    
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $archive_courseID,
	});

	
	my ($tables_ok,$dbStatus);
#############################################################################
# Check database
#############################################################################
	my %missing_fields;
	if ($ce2->{dbLayoutName} ) {
	    my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce=>$ce2);
	    ($tables_ok,$dbStatus) = $CIchecker->checkCourseTables($archive_courseID);
		if ($r->param("upgrade_course_tables")) {
			my @schema_table_names = keys %$dbStatus;  # update tables missing from database;
			my @tables_to_create = grep {$dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A} @schema_table_names;
			my @tables_to_alter  = grep {$dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B} @schema_table_names;
			my $msg = $CIchecker->updateCourseTables($archive_courseID, [@tables_to_create]);
			foreach my $table_name (@tables_to_alter) {
				$msg .= $CIchecker->updateTableFields($archive_courseID, $table_name);
			}
			print CGI::p({-style=>'color:green; font-weight:bold'}, $msg);
		}
		if ($r->param("upgrade_course_tables") ) {
			
			$CIchecker -> updateCourseDirectories();   # needs more error messages
		}
 		($tables_ok,$dbStatus) = $CIchecker->checkCourseTables($archive_courseID);
 

		# print db status

		my %msg =(    WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A         => CGI::span({style=>"color:red"}, $r->maketext("Table defined in schema but missing in database")),
		              WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B         => CGI::span({style=>"color:red"}, $r->maketext("Table defined in database but missing in schema")),
		              WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B   => CGI::span({style=>"color:green"}, $r->maketext("Table is ok")),
		              WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => CGI::span({style=>"color:red"}, $r->maketext("Schema and database table definitions do not agree")),
		);
		my %msg2 =(    WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A        => CGI::span({style=>"color:red"}, $r->maketext("Field missing in database")),
		              WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B         => CGI::span({style=>"color:red"}, $r->maketext("Field missing in schema")),
		              WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B   => CGI::span({style=>"color:green"}, $r->maketext("Field is ok")),
		              WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => CGI::span({style=>"color:red"}, $r->maketext("Schema and database field definitions do not agree")),
		);
		my $all_tables_ok=1;
		my $extra_database_tables=0;
		my $extra_database_fields=0;
		my $str=CGI::h4($r->maketext("Report on database structure for course [_1]:", $archive_courseID)).CGI::br();
		foreach my $table (sort keys %$dbStatus) {
		    my $table_status = $dbStatus->{$table}->[0];
			$str .= CGI::b($table) .": ".  $msg{ $table_status } . CGI::br();
			
			CASE: {
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B 
					&& do{ last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A
					&& do{
						   $all_tables_ok = 0; last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B
					&& do{
						   $extra_database_tables = 1; last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B
					&& do{ 
					    my %fieldInfo = %{ $dbStatus->{$table}->[1] };
						foreach my $key (keys %fieldInfo) {
						    my $field_status = $fieldInfo{$key}->[0];
						    CASE2: {
						    	$field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B 
						    		&& do{ 
						    		   $extra_database_fields = 1; last CASE2;
						    		};
						    	$field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A 
						    		&& do{ 
						    		   $all_tables_ok=0; last CASE2;
						    		};						    
						    }
							$str .= CGI::br()."\n&nbsp;&nbsp;$key => ". $msg2{$field_status };
						}							
					};
			}
			$str.=CGI::br();
			
		}
#############################################################################
# Report on databases
#############################################################################

		print CGI::p($str);
		if ($extra_database_tables) {
				print CGI::p({-style=>'color:red; font-weight:bold'}, $r->maketext("There are extra database tables which are not defined in the schema.  They can only be removed manually from the database."));
		} 
		if ($extra_database_fields) {
				print CGI::p({-style=>'color:red; font-weight:bold'}, $r->maketext("There are extra database fields  which are not defined in the schema for at least one table.  They can only be removed manually from the database."));
		} 
		if ($all_tables_ok) {
			print CGI::p({-style=>'color:green; font-weight:bold'}, $r->maketext("Course [_1] database is in order", $archive_courseID));
			print(CGI::p({-style=>'color:red; font-weight:bold'},  $r->maketext("Are you sure that you want to delete the course [_1] after archiving? This cannot be undone!", CGI::b($archive_courseID)))) if $delete_course_flag;
		} else {
			print CGI::p({-style=>'color:red; font-weight:bold'},  $r->maketext("There are tables or fields missing from the database.  The database must be upgraded before archiving this course.")
			);
		}
#############################################################################
# Check directories and report
#############################################################################


      my ($directories_ok, $str2) = $CIchecker->checkCourseDirectories();
      my $style = ($directories_ok)?"color:green" : "color:red";
      print CGI::h2( $r->maketext("Directory structure")), CGI::p($str2),
      ($directories_ok)? CGI::p({style=>$style}, $r->maketext("Directory structure is ok")) :
              CGI::p({style=>$style}, $r->maketext("Directory structure is missing directories or the webserver lacks sufficient privileges."));
    



#############################################################################
# Print form for choosing next action.
#############################################################################

		print CGI::start_form(-method=>"POST", -action=>$r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		print $self->hidden_fields(qw/delete_course/);
		print CGI::hidden('archive_courseID', $archive_courseID);
		print CGI::hidden('archive_courseIDs',@archive_courseIDs);
			# grab some values we'll need
		my $course_dir   = $ce2->{courseDirs}{root};
		my $archive_path = $ce2->{webworkDirs}{courses} . "/$archive_courseID.tar.gz";
        # fail if the source course does not exist
		unless (-e $course_dir) {
			print CGI::p(  $r->maketext("[_1]: The directory for the course not found.",$archive_courseID));
		}

		if ($all_tables_ok && $directories_ok ) { # no missing fields
			# Warn about overwriting an existing archive
			if (-e $archive_path and -w $archive_path) {
				print CGI::p({-style=>'color:red; font-weight:bold'},$r->maketext("The course '[_1]' has already been archived at '[_2]'. This earlier archive will be erased.  This cannot be undone.", $archive_courseID, $archive_path));
			}
			# archive execute button
			print CGI::p({style=>"text-align: center"},
				CGI::submit(-name=>"decline_archive_course", -value=>$r->maketext("Stop Archiving")),
				"&nbsp;",
				(scalar(@archive_courseIDs) > 1)? CGI::submit(-name=>"skip_archive_course", -value=>$r->maketext("Skip archiving this course"))."&nbsp;":'',
				CGI::submit(-name=>"confirm_archive_course", -value=>$r->maketext("Archive")) ,
			);
		} elsif( $directories_ok)  {
			print CGI::p({style=>"text-align: center"},
			CGI::submit(-name => "decline_archive_course", -value => $r->maketext("Don't Archive")),
				"&nbsp;",
				CGI::submit(-name=>"upgrade_course_tables", -value=>$r->maketext("Upgrade Course Tables")),
			);
		} else {
			print CGI::p({style=>"text-align: center"},
			CGI::br(),
			$r->maketext("Directory structure needs to be repaired manually before archiving."),CGI::br(),
			CGI::submit(-name => "decline_archive_course", -value => $r->maketext("Don't Archive")),
			CGI::submit(-name => "upgrade_course_tables", -value => $r->maketext("Attempt to upgrade directories")),
			);
		
		}
		print CGI::end_form();
	} else {
		print CGI::p({-style=>'color:red; font-weight:bold'},"Unable to find database layout for $archive_courseID");
	}
}

sub do_archive_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
    
	my $delete_course_flag   = $r->param("delete_course")        || "";
	my @archive_courseIDs     = $r->param("archive_courseIDs");
	@archive_courseIDs        = () unless @archive_courseIDs;
	my $archive_courseID = $archive_courseIDs[0];
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $archive_courseID,
	});
	
	# Remove course specific temp files before archiving
	my $courseTempDir = $ce2->{courseDirs}{html_temp};
	remove_tree("$courseTempDir");
	# Remove the original default tmp directory if it exists 
	my $orgDefaultCourseTempDir = "$ce2->{courseDirs}{html}/tmp";	
	if (-d "$orgDefaultCourseTempDir") {
		remove_tree("$orgDefaultCourseTempDir");
	}

	# this is kinda left over from when we had 'gdbm' and 'sql' database layouts
	# below this line, we would grab values from getopt and put them in this hash
	# but for now the hash can remain empty
	my %dbOptions;
	
	eval {
		archiveCourse(
			courseID => $archive_courseID,
			ce => $ce2,
			dbOptions => \%dbOptions,
		);
	};
	
	if ($@) {
		my $error = $@;
		print CGI::div({class=>"ResultsWithError"},
			CGI::p( $r->maketext("An error occured while archiving the course [_1]:", $archive_courseID)),
			CGI::tt(CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div({class=>"ResultsWithoutError"},
			CGI::p($r->maketext("Successfully archived the course [_1].", $archive_courseID)),
		);
		 writeLog($ce, "hosted_courses", join("\t",
	    	"\tarchived",
	    	"",
	    	"",
	    	$archive_courseID,
	    ));
	    
		if ($delete_course_flag) {
			eval {
				deleteCourse(
					courseID => $archive_courseID,
					ce => $ce2,
					dbOptions => \%dbOptions,
				);
			};
			
			if ($@) {
				my $error = $@;
				print CGI::div({class=>"ResultsWithError"},
					CGI::p($r->maketext("An error occured while deleting the course [_1]:", $archive_courseID)),
					CGI::tt(CGI::escapeHTML($error)),
				);
			} else {
				# mark the contact person in the admin course as dropped.
				# find the contact person for the course by searching the admin classlist.
				my @contacts = grep /_$archive_courseID$/,  $db->listUsers;
				if (@contacts) {
					die "Incorrect number of contacts for the course $archive_courseID". join(" ", @contacts) if @contacts !=1;
					#warn "contacts", join(" ", @contacts);
					#my $composite_id = "${add_initial_userID}_${add_courseID}";
					my $composite_id  = $contacts[0];
					
					# mark the contact person as dropped.
					my $User = $db->getUser($composite_id);
					my $status_name = 'Drop';
					my $status_value = ($ce->status_name_to_abbrevs($status_name))[0];
					$User->status($status_value);
					$db->putUser($User);
				}
				
				print CGI::div({class=>"ResultsWithoutError"},
					CGI::p($r->maketext("Successfully deleted the course [_1].", $archive_courseID)),
				);
			}
		
		
		}
		shift @archive_courseIDs;  # remove the course which has just been archived.
		if (@archive_courseIDs) {	    
			print CGI::start_form(-method=>"POST", -action=>$r->uri);
			print $self->hidden_authen_fields;
			print $self->hidden_fields("subDisplay");
			print $self->hidden_fields(qw/delete_course/);

			print CGI::hidden('archive_courseIDs',@archive_courseIDs);		
			print CGI::p({style=>"text-align: center"}, CGI::submit("decline_archive_course", $r->maketext("Stop archiving courses")),
				CGI::submit("archive_course", $r->maketext("Archive next course"))
			);
 			print CGI::end_form();
 		} else {
			print CGI::start_form(-method=>"POST", -action=>$r->uri);
			print $self->hidden_authen_fields;
			print $self->hidden_fields("subDisplay");
			print CGI::hidden('archive_courseIDs',$archive_courseID);		
			print CGI::p( CGI::submit("decline_archive_course", $r->maketext("OK"))  );
			print CGI::end_form();
		}
	}
}

##########################################################################

sub unarchive_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $unarchive_courseID     = $r->param("unarchive_courseID")     || "";
	
	# First find courses which have been archived.
	my @courseIDs = listArchivedCourses($ce);
	@courseIDs    = sort {lc($a) cmp lc ($b) } @courseIDs; #make sort case insensitive 
	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
        $courseLabels{$courseID} = $courseID;
	}
	
	print CGI::h2($r->maketext("Unarchive Course"));
	
	print CGI::p($r->maketext("Restores a course from a gzipped tar archive (.tar.gz). After unarchiving, the course database is restored from a subdirectory of the course's DATA directory. Currently the archive facility is only available for mysql databases. It depends on the mysqldump application.")
	);
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p($r->maketext("Select a course to unarchive."));
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, $r->maketext("Course Name:")),
			CGI::td(
				CGI::scrolling_list(
					-name => "unarchive_courseID",
					-values => \@courseIDs,
					-default => $unarchive_courseID,
					-size => 10,
					-multiple => 0,
					-labels => \%courseLabels,
				),
			),
		),
	
		CGI::Tr({},
				CGI::th({class=>"LeftHeader"}, CGI::checkbox(-name => "create_newCourseID",-default=>'',-value=>1, -label=>$r->maketext('New Name:'))),
				CGI::td(CGI::textfield(-name=>"new_courseID", -value=>'', -size=>25, -maxlength=>$ce->{maxCourseIdLength})),
			),
	);

	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"unarchive_course", -value=>$r->maketext("Unarchive Course")));
	
	print CGI::end_form();
}

sub unarchive_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $unarchive_courseID                   = $r->param("unarchive_courseID")             || "";
	my $create_newCourseID                   = $r->param("create_newCourseID")      || "";
	my $new_courseID                         = $r->param("new_courseID")    || "";
	my @errors;
	#by default we use the archive name for the course
	my $courseID = $unarchive_courseID; 
	$courseID =~ s/\.tar\.gz$//;
	
	if ( $create_newCourseID) {
		$courseID = $new_courseID;
	}
	debug(" unarchive_courseID $unarchive_courseID new_courseID $new_courseID ");

	if ($courseID eq "") {
		push @errors, $r->maketext("You must specify a course name.");
	} elsif ( -d $ce->{webworkDirs}->{courses}."/$courseID" ) {
	    #Check that a directory for this course doesn't already exist
		push @errors, $r->maketext("A directory already exists with the name [_1]. You must first delete this existing course before you can unarchive.",$courseID);
	}

	
	return @errors;
}

sub unarchive_course_confirm {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	print CGI::h2($r->maketext("Unarchive Course"));
	
	my $unarchive_courseID                    = $r->param("unarchive_courseID")     || "";
	my $create_newCourseID                    = $r->param("create_newCourseID")     || "";
	my $new_courseID                          = $r->param("new_courseID")           || "";

	my $courseID = $unarchive_courseID; $courseID =~ s/\.tar\.gz$//;
	
	if ( $create_newCourseID) {
		$courseID = $new_courseID;
	}	

    debug(" unarchive_courseID $unarchive_courseID new_courseID $new_courseID ");

	print CGI::start_form(-method=>"POST", -action=>$r->uri);
		print CGI::p($r->maketext("Unarchive [_1] to course:", $unarchive_courseID), 
	             CGI::input({-name=>'new_courseID', -value=>$courseID})
	);

	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	print $self->hidden_fields(qw/unarchive_courseID create_newCourseID/);
	
	print CGI::p({style=>"text-align: center"},
		CGI::submit(-name=>"decline_unarchive_course", -value=>$r->maketext("Don't Unarchive")),
		"&nbsp;",
		CGI::submit(-name=>"confirm_unarchive_course", -value=>$r->maketext("Unarchive")),
	);
	
	print CGI::end_form();
}

sub do_unarchive_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	my $new_courseID           = $r->param("new_courseID")           || "";
	my $unarchive_courseID     = $r->param("unarchive_courseID")     || "";
	
	my $old_courseID   = $unarchive_courseID; 
	$old_courseID =~ s/.tar.gz//;

	#eval {
		unarchiveCourse(
			newCourseID => $new_courseID,
			oldCourseID => $old_courseID,
			archivePath =>$ce->{webworkDirs}->{courses}."/$unarchive_courseID",
			ce => $ce,
		);
	#};
	
	if ($@) {
		my $error = $@;
		print CGI::div({class=>"ResultsWithError"},
			CGI::p($r->maketext("An error occured while archiving the course [_1]:", $unarchive_courseID)),
			CGI::tt(CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div({class=>"ResultsWithoutError"},
			CGI::p($r->maketext("Successfully unarchived [_1] to the course [_2]", $unarchive_courseID, $new_courseID)),
		);
		 writeLog($ce, "hosted_courses", join("\t",
	    	"\tunarchived",
	    	"",
	    	"",
	    	"$unarchive_courseID to $new_courseID",
	    ));

		my $newCoursePath = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r,
			courseID => $new_courseID);
		my $newCourseURL = $self->systemLink($newCoursePath, authen => 0);
		print CGI::div({style=>"text-align: center"},
			CGI::a({href=>$newCourseURL}, $r->maketext("Log into [_1]", $new_courseID)),
		);
		
		print CGI::start_form(-method=>"POST", -action=>$r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		print CGI::hidden("unarchive_courseID",$unarchive_courseID);
		print CGI::p( CGI::submit("decline_unarchive_course", $r->maketext("Unarchive Next Course"))  );
 		print CGI::end_form();
 
	}
}

##########################################################################

sub upgrade_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	
	my $selectAll =CGI::input({-type=>'button', -name=>'check_all', -value=>$r->maketext('Select all eligible courses'),
	       onClick => "for (i in document.courselist.elements)  { 
	                       if (document.courselist.elements[i].name =='upgrade_courseIDs') { 
	                           document.courselist.elements[i].checked = true
	                       }
	                    }" });
   	my $selectNone =CGI::input({-type=>'button', -name=>'check_none', -value=>$r->maketext('Unselect all courses'),
	       onClick => "for (i in document.courselist.elements)  { 
	                       if (document.courselist.elements[i].name =='upgrade_courseIDs') { 
	                          document.courselist.elements[i].checked = false
	                       }
	                    }" });

	my @courseIDs = listCourses($ce);
	@courseIDs    = sort {lc($a) cmp lc ($b) } @courseIDs; #make sort case insensitive 
	
	print CGI::h2($r->maketext("Upgrade Courses"));
	
	print CGI::p($r->maketext("Update the checked directories?"));
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri, -id=>"courselist", -name=>"courselist"),
	      CGI::p($selectAll, $selectNone);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
		foreach my $courseID ( @courseIDs) {
			#next if $courseID eq "admin"; # done already above  # on second thought even admin courses have to upgrade.
			next if $courseID eq "modelCourse"; # modelCourse isn't a real course so don't create missing directories, etc
			next unless $courseID =~/\S/;  # skip empty courseIDs (there shouldn't be any
			my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => $courseID);
			my $tempCE;
			eval{ $tempCE = new WeBWorK::CourseEnvironment({
				%WeBWorK::SeedCE,
				courseName => $courseID,
			})};
		    print $r->maketext("Can't create course environment for [_1] because [_2]", $courseID,  $@) if $@;
			my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce=>$tempCE);
			$CIchecker->updateCourseDirectories();  #creates missing html_temp, mailmerge tmpEditFileDir directories;
			my ($tables_ok,$dbStatus)   = $CIchecker->checkCourseTables($courseID);
			my ($directories_ok, $str2) = $CIchecker->checkCourseDirectories();
			my $checked = ($tables_ok && $directories_ok)?0:1;   # don't check if everything is ok
			my $checkbox_spot = "";
			if ($checked) {  # only show checkbox if the course is not up-to-date
	        	$checkbox_spot = CGI::checkbox({name=>"upgrade_courseIDs", label=>$r->maketext('Upgrade'), selected=>$checked,value=>$courseID});
	        }
			print CGI::li(
			    $checkbox_spot,"&nbsp;",
			    CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, $courseID),
				CGI::code(
					$tempCE->{dbLayoutName},
				),
				$directories_ok ? "" : CGI::span({style=>"color:red"},$r->maketext("Directory structure or permissions need to be repaired. ")),
				$tables_ok ? CGI::span({style=>"color:green"},$r->maketext("Database tables ok")) : CGI::span({style=>"color:red"},$r->maketext("Database tables need updating.")),
			
			);
			 
		}
		

	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"upgrade_course", -value=>$r->maketext("Upgrade Courses")));
	
	print CGI::end_form();
}

sub upgrade_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my @upgrade_courseIDs     = $r->param("upgrade_courseIDs") ; 
	@upgrade_courseIDs        = () unless  @upgrade_courseIDs;
	#warn "validate: upgrade ids ", join("|",@upgrade_courseIDs);
	my @errors;
	foreach my $upgrade_courseID (@upgrade_courseIDs) {
		if ($upgrade_courseID eq "") {
			push @errors, $r->maketext("You must specify a course name.");
		} 
	}
	
	
	return @errors;
}

sub upgrade_course_confirm {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	
    
	my @upgrade_courseIDs     = $r->param("upgrade_courseIDs");
	@upgrade_courseIDs        = () unless @upgrade_courseIDs;
    #my $upgrade_courseID      = $upgrade_courseIDs[0];
    my %update_error_msg 	  = ();
    print CGI::start_form(-method=>"POST", -action=>$r->uri);
    foreach my $upgrade_courseID (@upgrade_courseIDs) {
        next unless $upgrade_courseID =~/\S/;   # skip empty values
    	##########################
		# analyze one course
		##########################
		my $ce2 = new WeBWorK::CourseEnvironment({
			%WeBWorK::SeedCE,
			courseName => $upgrade_courseID,
		});
		#warn "upgrade_course_confirm: updating |$upgrade_courseID| from course list: " , join("|",@upgrade_courseIDs); 
	
		#############################################################################
		# Create integrity checker
		#############################################################################
	
		my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce=>$ce2);
	
		#############################################################################
		# Report on database status
		#############################################################################
	
		my ($tables_ok,$dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);
 		my ($all_tables_ok, $extra_database_tables, $extra_database_fields, $str) = $self->formatReportOnDatabaseTables($tables_ok, $dbStatus);
 		# prepend course name
		$str = CGI::checkbox({name=>"upgrade_courseIDs", label=>$r->maketext('Upgrade'), selected=>1,value=>$upgrade_courseID}).
		         $r->maketext("Report for course [_1]:", $upgrade_courseID).CGI::br().$r->maketext("Database:").CGI::br(). $str;
		 
		#############################################################################
		# Report on databases
		#############################################################################
	
		print CGI::p($str);
		if ($extra_database_tables) {
				print CGI::p({-style=>'color:red; font-weight:bold'},$r->maketext("There are extra database tables which are not defined in the schema.  They can only be removed manually from the database."));
		} 
		if ($extra_database_fields) {
				print CGI::p({-style=>'color:red; font-weight:bold'},$r->maketext("There are extra database fields  which are not defined in the schema for at least one table.  They can only be removed manually from the database."));
		} 
	
	   
		#############################################################################
		# Report on directory status
		#############################################################################
		my ($directories_ok, $str2) = $CIchecker->checkCourseDirectories();
		my $style = ($directories_ok)?"color:green" : "color:red";
		print $r->maketext("Directory structure").CGI::br(), CGI::p($str2),
		($directories_ok)? CGI::p({style=>$style},$r->maketext("Directory structure is ok")) :
			  CGI::p({style=>$style},$r->maketext("Directory structure is missing directories or the webserver lacks sufficient privileges."));
	}
	#warn "upgrade_course_confirm:  now print form";
	#############################################################################
	# Print form for choosing next action.
	#############################################################################
    print CGI::h3($r->maketext("No course id defined")) unless @upgrade_courseIDs;


	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	#print CGI::hidden('upgrade_courseIDs',@upgrade_courseIDs);

	####################################################################
	# Submit buttons
	# After presenting a detailed summary of status of selected courses the choice is made to
	# upgrade the selected courses (confirm_upgrade_course is set
	# or return to the beginning (decline_upgrade_course   is set           
	
	####################################################################
	print CGI::p({style=>"text-align: center"},
	    CGI::submit(-name =>"decline_upgrade_course", -value => $r->maketext("Don't Upgrade")),
		CGI::submit(-name=>"confirm_upgrade_course", -value=>$r->maketext("Upgrade")) );
		
	print CGI::end_form();

}

sub do_upgrade_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	
    
	my @upgrade_courseIDs     = $r->param("upgrade_courseIDs");
	@upgrade_courseIDs        = () unless @upgrade_courseIDs;
    my %update_error_msg 				  = ();
    #warn "do_upgrade_course:  upgrade_courseIDs = ", join(" ", @upgrade_courseIDs);
    foreach my $upgrade_courseID (@upgrade_courseIDs) {
    	next unless $upgrade_courseID =~ /\S/; # omit blank course IDs
 
		##########################
		# update one course
		##########################
		my $ce2 = new WeBWorK::CourseEnvironment({
			%WeBWorK::SeedCE,
			courseName => $upgrade_courseID,
		});
		#warn "do_upgrade_course: updating |$upgrade_courseID| from" , join("|",@upgrade_courseIDs); 
		#############################################################################
		# Create integrity checker
		#############################################################################
	
		my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce=>$ce2);
		
		#############################################################################
		# Add missing tables and missing fields to existing tables
		#############################################################################
	
		my ($tables_ok,$dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);
		my @schema_table_names = keys %$dbStatus;  # update tables missing from database;
		my @tables_to_create = grep {$dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A} @schema_table_names;	
		my @tables_to_alter  = grep {$dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B} @schema_table_names;
		$update_error_msg{$upgrade_courseID} = $CIchecker->updateCourseTables($upgrade_courseID, [@tables_to_create]);
		foreach my $table_name (@tables_to_alter) {	#warn "do_upgrade_course: adding new fields to table $table_name in course $upgrade_courseID";
			$update_error_msg{$upgrade_courseID} .= $CIchecker->updateTableFields($upgrade_courseID, $table_name);
		}
		### $update_error_msg{$upgrade_courseID} is printed below
		#############################################################################
		# Add missing directories when it can be done safely
		#############################################################################	#warn "do_upgrade_course: updating course directories for $upgrade_courseID";
		$CIchecker -> updateCourseDirectories();   # needs more error messages
	
		
		#############################################################################
		# Analyze database status and prepare status report
		#############################################################################
	
		($tables_ok,$dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);
		  
		my ($all_tables_ok, $extra_database_tables, $extra_database_fields, $str) 
		      = $self->formatReportOnDatabaseTables($tables_ok, $dbStatus);
 		# prepend course name
		$str = CGI::br().$r->maketext("Database:").CGI::br(). $str;

		#############################################################################
		# Report on databases and report summary
		#############################################################################
	
			
			if ($extra_database_tables) {
					$str .= CGI::p({-style=>'color:red; font-weight:bold'},$r->maketext("There are extra database tables which are not defined in the schema.  They can only be removed manually from the database."));
			} 
			if ($extra_database_fields) {
					$str .= CGI::p({-style=>'color:red; font-weight:bold'},$r->maketext("There are extra database fields  which are not defined in the schema for at least one table.  They can only be removed manually from the database."));
			} 
	   
		#############################################################################
		# Prepare report on directory status
		#############################################################################
		  my ($directories_ok, $str2) = $CIchecker->checkCourseDirectories();
		  my $style = ($directories_ok)?"color:green" : "color:red";
		  my $dir_msg  = join ('', 
		  	$r->maketext("Directory structure"),CGI::br(), 
		  	CGI::p($str2),
		  	($directories_ok)? CGI::p({style=>$style},$r->maketext("Directory structure is ok")) :
				  CGI::p({style=>$style},$r->maketext("Directory structure is missing directories or the webserver lacks sufficient privileges."))
		  );
	
		#############################################################################
		# Print status
		#############################################################################
		print $r->maketext("Report for course [_1]:", $upgrade_courseID).CGI::br();
		print CGI::p({-style=>'color:green; font-weight:bold'}, $update_error_msg{$upgrade_courseID});

		print CGI::p($str);     # print message about tables
		print CGI::p($dir_msg); # message about directories

	}
	#############################################################################
	# Submit buttons -- return to beginning
	#############################################################################
	print CGI::h3($r->maketext("Upgrade process completed"));
	print CGI::start_form(-method=>"POST", -action=>$r->uri);  #send back to this script
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"decline_upgrade_course", -value=>$r->maketext("Done")) );
	print CGI::end_form();
}
	
	

################################################################################
## location management routines; added by DG [Danny Ginn] 20070215
## revised by glarose

sub manage_location_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	# get a list of all existing locations
	my @locations = sort {lc($a->location_id) cmp lc($b->location_id)}
		$db->getAllLocations();
	my %locAddr = map {$_->location_id => [ $db->listLocationAddresses($_->location_id) ]} @locations;

	my @locationIDs = map { $_->location_id } @locations;
	
	print CGI::h2($r->maketext("Manage Locations"));

	print CGI::p({},CGI::strong($r->maketext("Currently defined locations are listed below.")));

	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");

	# get a list of radio buttons to select an action
	my @actionRadios = 
		CGI::radio_group(-name => "manage_location_action",
				 -values => ["edit_location_form",
					     "add_location_handler",
					     "delete_location_handler"],
				 -labels => { edit_location_form => "",
					      add_location_handler => "",
					      delete_location_handler => "", },
				 -default => $r->param("manage_location_action") ? $r->param("manage_location_action") : 'none');

	print CGI::start_table({});
	print CGI::Tr({}, CGI::th({-colspan=>4,-align=>"left"}, 
				  $r->maketext("Select an action to perform:")));

	# edit action
	print CGI::Tr({}, 
		CGI::td({},[ $actionRadios[0], $r->maketext("Edit Location:") ]),
		CGI::td({-colspan=>2, -align=>"left"}, 
			CGI::div({-style=>"width:25%;"},
				  CGI::popup_menu(-name=>"edit_location",
					-values=>[@locationIDs]))) );
	# create action
	print CGI::Tr({},
		CGI::td({-align=>"left"},[ $actionRadios[1], 
			$r->maketext("Create Location:") ]),
		CGI::td({-colspan=>2},
			$r->maketext("Location name:").' ' .
			CGI::textfield(-name=>"new_location_name",
				       -size=>"10",
				       -default=>$r->param("new_location_name")?$r->param("new_location_name"):'')));
	print CGI::Tr({valign=>'top'},
		CGI::td({}, ["&nbsp;", $r->maketext("Location description:")]),
		CGI::td({-colspan=>2}, 
			CGI::textfield(-name=>"new_location_description",
				       -size=>"50",
				       -default=>$r->param("new_location_description")?$r->param("new_location_description"):'')) );
	print CGI::Tr({}, CGI::td({},"&nbsp;"),
		CGI::td({-colspan=>3}, $r->maketext("Addresses for new location.  Enter one per line, as single IP addresses e.g., 192.168.1.101), address masks (e.g., 192.168.1.0/24), or IP ranges (e.g., 192.168.1.101-192.168.1.150)):")));
	print CGI::Tr({}, CGI::td({}, "&nbsp;"),
		CGI::td({-colspan=>3},
			CGI::textarea({-name=>"new_location_addresses",
				       -rows=>5, -columns=>28,
				       -default=>$r->param("new_location_addresses")?$r->param("new_location_addresses"):''})));

	# delete action
	print CGI::Tr({}, 
		CGI::td({-colspan=>4}, 
			CGI::div({-class=>"ResultsWithError"},
				 CGI::em({}, $r->maketext("Deletion deletes all location data and related addresses, and is not undoable!")))));
	print CGI::Tr({}, 
		CGI::td({}, 
			[ $actionRadios[2],
			  CGI::div({-class=>"ResultsWithError"},
				   $r->maketext("Delete location:")) ]),
		CGI::td({-colspan=>2}, 
			CGI::popup_menu(-name=>"delete_location",
					-values=>["",
						  "selected_locations",
						  @locationIDs],
					-labels=>{selected_locations => $r->maketext("locations selected below"),
						  "" => $r->maketext("no location")}) .
			CGI::br() .
			CGI::start_span({-class=>"ResultsWithError"}).
			CGI::checkbox({-name=>"delete_confirm",
				       -value=>"true",
				       -label=>$r->maketext("Confirm")}).
			CGI::end_span()));
	print CGI::end_table();

	print CGI::p({}, CGI::submit(-name=>"manage_locations", -value=>$r->maketext("Take Action!")));

	# existing location table
	# FIXME: the styles for this table should be off in a stylesheet 
	#    somewhere
	print CGI::start_div({align=>"center"}),
		CGI::start_table({border=>1, cellpadding=>2});
	print CGI::Tr({style=>"background-color:#e0e0e0;font-size:92%", align=>"left"}, 
		      CGI::th({}, [$r->maketext("Select"), $r->maketext("Location"), $r->maketext("Description"), $r->maketext("Addresses")]));
	foreach my $loc ( @locations ) {
		my $editAddr = $self->systemLink($urlpath, params=>{subDisplay=>"manage_locations", manage_location_action=>"edit_location_form", edit_location=>$loc->location_id});
		print CGI::Tr({valign=>'top',style=>"background-color:#eeeeee;"}, 
			      CGI::td({style=>'font-size:85%;'},
				      [ CGI::checkbox(-name=>"delete_selected",
						      -value=>$loc->location_id,
						      -label=>''),
					CGI::a({href=>$editAddr}, $loc->location_id),
					$loc->description,
					join(', ', @{$locAddr{$loc->location_id}}) ]));
	}
	print CGI::end_table(), CGI::end_div();
	print CGI::end_form();


}

sub add_location_handler {
	my $self = shift();
	my $r = $self->r;
	my $db = $r->db;

	# the location data we're to add
	my $locationID = $r->param("new_location_name");
	my $locationDescr = $r->param("new_location_description");
	my $locationAddr = $r->param("new_location_addresses");
	# break the addresses up
	$locationAddr =~ s/\s*-\s*/-/g;
	$locationAddr =~ s/\s*\/\s*/\//g;
	my @addresses = split(/\s+/, $locationAddr);

	# sanity checks
	my $badAddr = '';
	foreach my $addr ( @addresses ) {
		unless ( new Net::IP($addr) ) {
			$badAddr .= "$addr, ";
			$locationAddr =~ s/$addr\n//s;
		}
	}
	$badAddr =~ s/, $//;

	# a check to be sure that the location addresses don't already
	#    exist
	my $badLocAddr = '';
	if ( ! $badAddr && $locationID ) {
		if ( $db->countLocationAddresses( $locationID ) ) {
			my @allLocAddr = $db->listLocationAddresses($locationID);
			foreach my $addr ( @addresses ) {
				$badLocAddr .= "$addr, " 
					if ( grep {/^$addr$/} @allLocAddr );
			}
			$badLocAddr =~ s/, $//;
		}
	}

	if ( ! @addresses || ! $locationID || ! $locationDescr ) {
		print CGI::div({-class=>"ResultsWithError"}, 
			       $r->maketext("Missing required input data. Please check that you have filled in all of the create location fields and resubmit."));
	} elsif ( $badAddr ) {
		$r->param("new_location_addresses", $locationAddr);
		print CGI::div({-class=>"ResultsWithError"}, 
			       $r->maketext("Address(es) [_1] is(are) not in a recognized form.  Please check your data entry and resubmit.",$badAddr));
	} elsif ( $db->existsLocation( $locationID ) ) {
		print CGI::div({-class=>"ResultsWithError"}, 
			       $r->maketext("A location with the name [_1] already exists in the database.  Did you mean to edit that location instead?",$locationID));
	} elsif ( $badLocAddr ) {
		print CGI::div({-class=>"ResultsWithError"}, 
			       $r->maketext("Address(es) [_1] already exist in the database.  THIS SHOULD NOT HAPPEN!  Please double check the integrity of the WeBWorK database before continuing.", $badLocAddr));
	} else {
		# add the location
		my $locationObj = $db->newLocation;
		$locationObj->location_id( $locationID );
		$locationObj->description( $locationDescr );
		$db->addLocation( $locationObj );

		# and add the addresses
		foreach my $addr ( @addresses ) {
			my $locationAddress = $db->newLocationAddress;
			$locationAddress->location_id($locationID);
			$locationAddress->ip_mask($addr);

			$db->addLocationAddress( $locationAddress );
		}
		
		# we've added the location, so clear those param 
		#    entries
		$r->param('manage_location_action','none');
		$r->param('new_location_name','');
		$r->param('new_location_description','');
		$r->param('new_location_addresses','');

		print CGI::div({-class=>"ResultsWithoutError"}, 
			       $r->maketext("Location [_1] has been created, with addresses [_2].", $locationID, join(', ', @addresses)));
	}

	$self->manage_location_form;
}

sub delete_location_handler {
	my $self = shift;
	my $r = $self->r;
	my $db = $r->db;

	# what location are we deleting?
	my $locationID = $r->param("delete_location");
	# check for selected deletions if appropriate
	my @delLocations = ( $locationID );
	if ( $locationID eq 'selected_locations' ) {
		@delLocations = $r->param("delete_selected");
		$locationID = @delLocations;
	}
	# are we sure?
	my $confirm = $r->param("delete_confirm");

	my $badID;
	if ( ! $locationID ) {
		print CGI::div({-class=>"ResultsWithError"}, 
			       $r->maketext("Please provide a location name to delete."));

	} elsif ( $badID = $self->existsLocations_helper( @delLocations ) ) {
		print CGI::div({-class=>"ResultsWithError"}, 
			       $r->maketext("No location with name [_1] exists in the database", $badID));

	} elsif ( ! $confirm || $confirm ne 'true' ) {
		print CGI::div({-class=>"ResultsWithError"}, 
			       $r->maketext("Location deletion requires confirmation."));
	} else {
		foreach ( @delLocations ) {
			$db->deleteLocation( $_ );
		}
		print CGI::div({-class=>"ResultsWithoutError"},
			       $r->maketext("Deleted Location(s): [_1]", join(', ', @delLocations)));
		$r->param('manage_location_action','none');
		$r->param('delete_location','');
	}
	$self->manage_location_form;
}
sub existsLocations_helper {
	my ($self, @locations) = @_;
	my $db = $self->r->db;
	foreach ( @locations ) {
		return $_ if ( ! $db->existsLocation($_) );
	}
	return 0;
}

sub edit_location_form {
	my $self = shift;
	my $r = $self->r;
	my $db = $r->db;

	my $locationID = $r->param("edit_location");
	if ( $db->existsLocation( $locationID ) ) {
		my $location = $db->getLocation($locationID);
		# this doesn't give that nice a sort for IP addresses,
		#    b/c there's the problem with 192.168.1.168 sorting 
		#    ahead of 192.168.1.2.  we could do better if we 
		#    either invoked Net::IP in the sort routine, or if
		#    we insisted on dealing only with IPv4.  rather than
		#    deal with either of those, we'll leave this for now
		my @locAddresses = sort { $a cmp $b }
			$db->listLocationAddresses($locationID);

		print CGI::h2($r->maketext("Editing location [_1]", $locationID));

		print CGI::p({},$r->maketext("Edit the current value of the location description, if desired, then add and select addresses to delete, and then click the \"Take Action\" button to make all of your changes.  Or, click \"Manage Locations\" above to make no changes and return to the Manage Locations page."));

		print CGI::start_form(-method=>"POST",
				      -action=>$r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		print CGI::hidden(-name=>'edit_location',
				  -default=>$locationID);
		print CGI::hidden(-name=>'manage_location_action',
				  -default=>'edit_location_handler');

		print CGI::start_table();
		print CGI::Tr({-valign=>'top'},
			CGI::td({-colspan=>3},
				$r->maketext("Location description:"), CGI::br(),
				CGI::textfield(-name=>"location_description",
					       -size=>"50",
					       -default=>$location->description)));
		print CGI::Tr({-valign=>'top'},
			CGI::td({-width=>"50%"},
				$r->maketext("Addresses to add to the location.  Enter one per line, as single IP addresses (e.g., 192.168.1.101), address masks (e.g., 192.168.1.0/24), or IP ranges (e.g., 192.168.1.101-192.168.1.150)):") . 
				CGI::br() .
				CGI::textarea({-name=>"new_location_addresses",
					       -rows=>5, -columns=>28})),
			CGI::td({}, "&nbsp;"),
			CGI::td({-width=>"50%"},
				$r->maketext("Existing addresses for the location are given in the scrolling list below.  Select addresses from the list to delete them:") . 
				CGI::br() .
				CGI::scrolling_list(-name=>'delete_location_addresses',
						    -values=>[@locAddresses],
						    -size=>8,
						    -multiple=>'multiple') .
				CGI::br() . $r->maketext("or").": " .
				CGI::checkbox(-name=>'delete_all_addresses',
					      -value=>'true',
					      -label=>$r->maketext('Delete all existing addresses'))
				 ));

		print CGI::end_table();

		print CGI::p({},CGI::submit(-value=>$r->maketext('Take Action!')));

	} else {
		print CGI::div({-class=>"ResultsWithError"},
			       $r->maketext("Location [_1] does not exist in the WeBWorK database.  Please check your input (perhaps you need to reload the location management page?).",$locationID));

		$self->manage_location_form;
	}
}

sub edit_location_handler { 
	my $self = shift;
	my $r = $self->r;
	my $db = $r->db;

	my $locationID = $r->param("edit_location");
	my $locationDesc = $r->param("location_description");
	my $addAddresses = $r->param("new_location_addresses");
	my @delAddresses = $r->param("delete_location_addresses");
	my $deleteAll = $r->param("delete_all_addresses");

	# gut check
	if ( ! $locationID ) {
		print CGI::div({-class=>"ResultsWithError"},
			       $r->maketext("No location specified to edit?! Please check your input data."));
		$self->manage_location_form;

	} elsif ( ! $db->existsLocation( $locationID ) ) {
		print CGI::div({-class=>"ResultsWithError"},
			       $r->maketext("Location [_1] does not exist in the WeBWorK database.  Please check your input (perhaps you need to reload the location management page?).", $locationID));
		$self->manage_location_form;
	} else {
		my $location = $db->getLocation($locationID);

		# get the current location addresses.  if we're deleting
		#   all of the existing addresses, we don't use this list 
		#   to determine which addresses to add, however.
		my @currentAddr = $db->listLocationAddresses($locationID);
		my @compareAddr = ( ! $deleteAll || $deleteAll ne 'true' )
			? @currentAddr : ();

		my $doneMsg = '';

		if ($locationDesc && $location->description ne $locationDesc) {
			$location->description($locationDesc);
			$db->putLocation($location);
			$doneMsg .= CGI::p({},$r->maketext("Updated location description."));
		}
		# get the actual addresses to add out of the text field
		$addAddresses =~ s/\s*-\s*/-/g;
		$addAddresses =~ s/\s*\/\s*/\//g;
		my @addAddresses = split(/\s+/, $addAddresses);

		# make sure that we're adding and deleting only those 
		#    addresses that are not yet/currently in the location
		#    addresses
		my @toAdd = ();  my @noAdd = ();
		my @toDel = ();  my @noDel = ();
		foreach my $addr ( @addAddresses ) {
			if (grep {/^$addr$/} @compareAddr) {push(@noAdd,$addr);}
			else { push(@toAdd, $addr); }
		}
		if ( $deleteAll && $deleteAll eq 'true' ) {
			@toDel = @currentAddr;
		} else {
			foreach my $addr ( @delAddresses ) { 
				if (grep {/^$addr$/} @currentAddr) {
					push(@toDel,$addr);
				} else { push(@noDel, $addr); }
			}
		}

		# and make sure that all of the addresses we're adding are 
		#    a sensible form
		my $badAddr = '';
		foreach my $addr ( @toAdd ) {
			unless ( new Net::IP($addr) ) {
				$badAddr .= "$addr, ";
			}
		}
		$badAddr =~ s/, $//;

		# delete addresses first, because we allow deletion of 
		#    all existing addresses, then addition of addresses.
		#    note that we don't allow deletion and then addition 
		#    of the same address normally, however; in that case
		#    we'll end up just deleting the address.
		foreach ( @toDel ) {
			$db->deleteLocationAddress($locationID, $_);
		}
		foreach ( @toAdd ) {
			my $locAddr = $db->newLocationAddress;
			$locAddr->location_id($locationID);
			$locAddr->ip_mask($_);

			$db->addLocationAddress($locAddr);
		}

		my $addrMsg = '';
		$addrMsg .= $r->maketext("Deleted addresses [_1] from location.", join(', ', @toDel)) . CGI::br() if ( @toDel );
		$addrMsg .= $r->maketext("Added addresses [_1] to location [_2].", join(', ', @toAdd), $locationID) if ( @toAdd );

		my $badMsg = '';
		$badMsg .= $r->maketext('Address(es) [_1] in the add list is(are) already in the location [_2], and so were skipped.', join(', ', @noAdd), $locationID) . CGI::br() if ( @noAdd );
		$badMsg .= $r->maketext("Address(es) [_1] is(are) not in a recognized form.  Please check your data entry and try again.",$badAddr) . CGI::br() if ( $badAddr );
		$badMsg .= $r->maketext('Address(es) [_1] in the delete list is(are) not in the location [_2], and so were skipped.',join(', ', @noDel),$locationID) if ( @noDel );

		print CGI::div({-class=>"ResultsWithError"}, $badMsg)
			if ( $badMsg );
		if ( $doneMsg || $addrMsg ) {
			print CGI::div({-class=>"ResultsWithoutError"},
				       CGI::p({}, $doneMsg, $addrMsg));
		} else {
			print CGI::div({-class=>"ResultsWithError"},
				       $r->maketext("No valid changes submitted for location [_1].", $locationID));
		}

		$self->edit_location_form;
	}
}

sub hide_inactive_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

	my $coursesDir = $ce->{webworkDirs}->{courses};
	my @courseIDs = listCourses($ce);
	my $hide_listing_format   = $r->param("hide_listing_format");
	unless (defined $hide_listing_format) {$hide_listing_format = 'last_login';}  #use the default
#	warn "hide_listing_format is $hide_listing_format";
	
	# Get and store last modify time for login.log for all courses. Also get visibility status.
	my %courseLabels;
	my @noLoginLogIDs = ();
	my @loginLogIDs = ();
	my @hideCourseIDs = ();
	my ($loginLogFile, $epoch_modify_time, $courseDir);
	foreach my $courseID (@courseIDs) {
		$loginLogFile = "$coursesDir/$courseID/logs/login.log";
		if (-e $loginLogFile) {                 #this should always exist except for the model course
			$epoch_modify_time = stat($loginLogFile)->mtime;
			$coursesData{$courseID}{'epoch_modify_time'} = $epoch_modify_time;
			$coursesData{$courseID}{'local_modify_time'} = ctime($epoch_modify_time);
			push(@loginLogIDs,$courseID);
		} else {
			$coursesData{$courseID}{'local_modify_time'} = 'no login.log';  #this should never be the case except for the model course
			push(@noLoginLogIDs,$courseID);
		}
		if (-f "$coursesDir/$courseID/hide_directory") {
			$coursesData{$courseID}{'status'} = $r->maketext('hidden');
		} else {	
			$coursesData{$courseID}{'status'} = $r->maketext('visible');	
		}
		$courseLabels{$courseID} = "$courseID  ($coursesData{$courseID}{'status'} :: $coursesData{$courseID}{'local_modify_time'}) ";
	}
	if ($hide_listing_format eq 'last_login') {
		@noLoginLogIDs = sort {lc($a) cmp lc ($b) } @noLoginLogIDs; #this should be an empty arrey except for the model course
		@loginLogIDs = sort byLoginActivity @loginLogIDs;  # oldest first
		@hideCourseIDs = (@noLoginLogIDs,@loginLogIDs);
	} else { # in this case we sort alphabetically
		@hideCourseIDs = sort {lc($a) cmp lc ($b) } @courseIDs;
	}
	
	print CGI::h2($r->maketext("Hide Inactive Courses"));
	
		print CGI::p($r->maketext('Select the course(s) you want to hide (or unhide) and then click "Hide Courses" (or "Unhide Courses"). Hiding a course that is already hidden does no harm (the action is skipped). Likewise unhiding a course that is already visible does no harm (the action is skipped).  Hidden courses are still active but are not listed in the list of WeBWorK courses on the opening page.  To access the course, an instructor or student must know the full URL address for the course.')
	);
	
	print CGI::p($r->maketext('Courses are listed either alphabetically or in order by the time of most recent login activity, oldest first. To change the listing order check the mode you want and click "Refresh Listing".  The listing format is: Course_Name (status :: date/time of most recent login) where status is "hidden" or "visible".'));
		
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);

	my %list_labels = (
								alphabetically => $r->maketext('alphabetically'), 
								last_login => $r->maketext('by last login date'), 
								);
											
	print CGI::table(
			CGI::Tr({},
			CGI::p($r->maketext("Select a listing format:")),
			CGI::radio_group(-name=>'hide_listing_format',
											-values=>['alphabetically', 'last_login'],
											-default=>'last_login',
											-labels=>\%list_labels,
											),
			),
		);							
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"hide_course_refresh", -value=>$r->maketext("Refresh Listing")), CGI::submit(-name=>"hide_course", -value=>$r->maketext("Hide Courses")),
	CGI::submit(-name=>"unhide_course", -value=>$r->maketext("Unhide Courses")));
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p($r->maketext("Select course(s) to hide or unhide."));
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::td(
				CGI::scrolling_list(
					-name => "hide_courseIDs",
					-values => \@hideCourseIDs,
					-size => 15,
					-multiple => 1,
					-labels => \%courseLabels,
				),
			),
			
		),
	);
	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"hide_course_refresh", -value=>$r->maketext("Refresh Listing")), CGI::submit(-name=>"hide_course", -value=>$r->maketext("Hide Courses")),
	CGI::submit(-name=>"unhide_course", -value=>$r->maketext("Unhide Courses")));
	
	print CGI::end_form();
}

sub hide_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my @hide_courseIDs     = $r->param("hide_courseIDs");
	@hide_courseIDs        = () unless @hide_courseIDs;
	
	my @errors;
	
	unless (@hide_courseIDs) {
		push @errors, $r->maketext("You must specify a course name.");
	} 
	return @errors;
}


sub do_hide_inactive_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
    
  my $coursesDir = $ce->{webworkDirs}->{courses};
  
	my $hide_courseID;
	my @hide_courseIDs     = $r->param("hide_courseIDs");
	@hide_courseIDs        = () unless @hide_courseIDs;

	my $hideDirFileContent = $r->maketext('Place a file named "hide_directory" in a course or other directory and it will not show up in the courses list on the WeBWorK home page. It will still appear in the Course Administration listing.');
	
	my @succeeded_courses = ();
	my $succeeded_count = 0;
	my @failed_courses = ();
	my $already_hidden_count = 0;
	
  foreach $hide_courseID (@hide_courseIDs) {
  	my $hideDirFile = "$coursesDir/$hide_courseID/hide_directory";
  	if (-f $hideDirFile) {
  		$already_hidden_count++;
  		next;
  	} else {
  		local *HIDEFILE;
  		if (open (HIDEFILE, ">", $hideDirFile)) {  
  			print HIDEFILE "$hideDirFileContent";
  			close HIDEFILE;
  			push @succeeded_courses,$hide_courseID;
  			$succeeded_count++;
  		} else {	
  			push @failed_courses,$hide_courseID;
  		}	
  	}
  }

	if (@failed_courses) {
		print CGI::div({class=>"ResultsWithError"},
			       CGI::p($r->maketext("Errors occured while hiding the courses listed below when attempting to create the file hide_directory in the course's directory. Check the ownership and permissions of the course's directory, e.g [_1]", "$coursesDir/$failed_courses[0]/")),
			CGI::p("@failed_courses"),
		);
	} 
	my $succeeded_message = '';
	
	if ($succeeded_count < 1 and $already_hidden_count > 0) {
		$succeeded_message = $r->maketext("Except for possible errors listed above, all selected courses are already hidden.");
	}	
	
	if ($succeeded_count) {
		if ($succeeded_count < 6) {
			$succeeded_message = $r->maketext("The following courses were successfully hidden: [_1]", @succeeded_courses);
		} else {
			$succeeded_message = $r->maketext("[quant_1, course was, courses were] successfully hidden.", $succeeded_count);
		}
	}
	if ($succeeded_count or $already_hidden_count) {
			print CGI::div({class=>"ResultsWithoutError"},
			CGI::p("$succeeded_message"),
		);
	}
}

sub unhide_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my @unhide_courseIDs     = $r->param("hide_courseIDs");
	@unhide_courseIDs        = () unless @unhide_courseIDs;
	
	my @errors;
	
	unless (@unhide_courseIDs) {
		push @errors, $r->maketext("You must specify a course name.");
	} 
	return @errors;
}


sub do_unhide_inactive_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
    
  my $coursesDir = $ce->{webworkDirs}->{courses};
  
	my $unhide_courseID;
	my @unhide_courseIDs     = $r->param("hide_courseIDs");
	@unhide_courseIDs        = () unless @unhide_courseIDs;
	
	my @succeeded_courses = ();
	my $succeeded_count = 0;
	my @failed_courses = ();
	my $already_visible_count = 0;

  foreach $unhide_courseID (@unhide_courseIDs) {
  	my $hideDirFile = "$coursesDir/$unhide_courseID/hide_directory";
  	unless (-f $hideDirFile) {
  		$already_visible_count++;
  		next;
  	} 
  	remove_tree("$hideDirFile", {error => \my $err});
  	if (@$err) {
  		push @failed_courses,$unhide_courseID;
    } else {
  	push @succeeded_courses,$unhide_courseID;
		$succeeded_count++;
  	}
  }
  my $succeeded_message = '';
  
  if ($succeeded_count < 1 and $already_visible_count > 0) {
		$succeeded_message = $r->maketext("Except for possible errors listed above, all selected courses are already unhidden.");
	}	
	
	if ($succeeded_count) {
		if ($succeeded_count < 6) {
			$succeeded_message = $r->maketext("The following courses were successfully unhidden: [_1]", @succeeded_courses);
		} else {
			$succeeded_message = $r->maketext("[quant,_1,course was, courses were] successfully unhidden.", $succeeded_count);
		}
	}
	if ($succeeded_count or $already_visible_count) {
		print CGI::div({class=>"ResultsWithoutError"},
		CGI::p("$succeeded_message"),
		);
	}	
	if (@failed_courses) {
		print CGI::div({class=>"ResultsWithError"},
			CGI::p($r->maketext("Errors occured while unhiding the courses listed below when attempting delete the file hide_directory in the course's directory. Check the ownership and permissions of the course's directory, e.g [_1]", "$coursesDir/$failed_courses[0]/")),
			CGI::p("@failed_courses"),
		);
	} 	
}


sub upgrade_notification {
    my $self = shift;
    my $r = $self->r;
    my $ce = $r->ce;
    my $db = $r->db;

    # exit if notifications are disabled
    return unless $ce->{enableGitUpgradeNotifier};

    my $git = $ce->{externalPrograms}->{git};
    my $WeBWorKRemote = $ce->{gitWeBWorKRemoteName};
    my $WeBWorKBranch = $ce->{gitWeBWorKBranchName};
    my $PGRemote = $ce->{gitPGRemoteName};
    my $PGBranch = $ce->{gitPGBranchName};
    my $LibraryRemote = $ce->{gitLibraryRemoteName};
    my $LibraryBranch = $ce->{gitLibraryBranchName};

    # we can tproceed unless we have git; 
    if (!(defined($git) && -x $git)) {
	warn('External Program "git" not found.  Check your site.conf');
	return;
    }

    my $upgradeMessage = '';
    my $upgradesAvailable = 0;
    my $output;
    my @lines;
    my $commit;

    if ($WeBWorKRemote && $WeBWorKBranch) {
    # Check if there is an updated version of webwork available
    # this is done by using ls-remote to get the commit sha at the 
    # head of the remote branch and looking to see if that sha is in
    # the currently selected local branch
	chdir($ce->{webwork_dir});
	my $currentBranch = `$git symbolic-ref --short HEAD`;
	$output = `$git ls-remote --heads $WeBWorKRemote`;
	@lines = split /\n/, $output;
	$commit=-1;

	foreach my $line (@lines) {
	    if ($line =~ /refs\/heads\/$WeBWorKBranch$/) {
		$line =~ /^(\w+)/;
		$commit = $1;
		last;
	    }
	}
	
	$output = `$git branch --contains $commit`;

	if ($commit ne '-1' && $output !~ /\s+$currentBranch(\s+|$)/) {    
	    # There are upgrades, we need to figure out if its a 
	    # new version or not
	    # This is done by using ls-remote to get the commit sha's
	    # at the heads of the remote tags.  
	    # Tags of the form WeBWorK-x.y are release tags.  If there is
	    # an sha there which isn't in the current branch then there must
	    # be a newer version. 

	    $output = `$git ls-remote --tags $WeBWorKRemote`;
	    @lines = split /\n/, $output;
	    my $newversion = 0;
	    
	    foreach my $line (@lines) {
		next unless $line =~ /\/tags\/WeBWorK-/;
		$line =~ /^(\w+)/;
		$commit = $1;
		$output = `$git branch --contains $commit`;
	
		if ($output !~ /\s+$currentBranch(\s+|$)/) {
		    # There is a version tag which contains a commit that
		    # isn't in the current branch so there must
		    # be a new version
		    $newversion = 1;
		    last;
		}
	    }
	    
	    if ($newversion) {
		$upgradesAvailable = 1;
		$upgradeMessage .= CGI::Tr(CGI::td($r->maketext('There is a new version of WeBWorK available.')));
	    } else {
		$upgradesAvailable = 1;
		$upgradeMessage .= CGI::Tr(CGI::td($r->maketext('There are upgrades available for your current branch of WeBWorK from branch [_1] in remote [_2].', $WeBWorKBranch, $WeBWorKRemote)));
	    }
	} elsif ($commit eq '-1') {
	    $upgradesAvailable = 1;
	    $upgradeMessage .= CGI::Tr(CGI::td($r->maketext("Couldn't find WeBWorK Branch [_1] in remote [_2]", $WeBWorKBranch, $WeBWorKRemote)));
	}  else {
	    $upgradeMessage .= CGI::Tr(CGI::td($r->maketext('Your current branch of WeBWorK is up to date with branch [_1] in remote [_2].', $WeBWorKBranch, $WeBWorKRemote)));
	}
    } 

    if ($PGRemote && $PGBranch) {
	# Check if there is an updated version of pg available
	# this is done by using ls-remote to get the commit sha at the 
	# head of the remote branch and looking to see if that sha is in
	# the currently selected local branch 
	chdir($ce->{pg_dir});
	my $currentBranch = `$git symbolic-ref --short HEAD`;
	$output = `$git ls-remote --heads $PGRemote`;
	@lines = split /\n/, $output;
	$commit='-1';
	
	foreach my $line (@lines) {
	    if ($line =~ /refs\/heads\/$PGBranch$/) {
		$line =~ /^(\w+)\s+/;
		$commit = $1;
		last;
	    }
	}
	
	$output = `$git branch --contains $commit`;
	
	if ($commit ne '-1' && $output !~ /\s+$currentBranch(\s+|$)/) {    
	    # There are upgrades, we need to figure out if its a 
	    # new version or not
	    # This is done by using ls-remote to get the commit sha's
	    # at the heads of the remote tags.  
	    # Tags of the form WeBWorK-x.y are release tags.  If there is
	    # an sha there which isn't in the local branch then there must
	    # be a newer version. 
	    $output = `$git ls-remote --tags $PGRemote`;
	    @lines = split /\n/, $output;
	    my $newversion = 0;
	    
	    foreach my $line (@lines) {
		next unless $line =~ /\/tags\/PG-/;
		$line =~ /^(\w+)/;
		$commit = $1;
		$output = `$git branch --contains $commit`;
		if ($output !~ /\s+$currentBranch(\s+|$)/) {
		    # There is a version tag which contains a commit that
		    # isn't in the current branch so there must
		    # be a new version
		    $newversion = 1;
		    last;
		}
	    }
	    
	    if ($newversion) {
		$upgradesAvailable = 1;
		$upgradeMessage .= CGI::Tr(CGI::td($r->maketext('There is a new version of PG available.')));
	    } else {
		$upgradesAvailable = 1;
		$upgradeMessage .= CGI::Tr(CGI::td($r->maketext('There are upgrades available for your current branch of PG from branch [_1] in remote [_2].', $PGBranch, $PGRemote)));
	    } 		
	} elsif ($commit eq '-1') {
	    $upgradesAvailable = 1;
	    $upgradeMessage .= CGI::Tr(CGI::td($r->maketext("Couldn't find PG Branch [_1] in remote [_2]", $PGBranch, $PGRemote)));
	}  else {
	    $upgradeMessage .= CGI::Tr(CGI::td($r->maketext('Your current branch of PG is up to date with branch [_1] in remote [_2].', $PGBranch, $PGRemote)));

	} 
    } 

    die "Couldn't find ".$ce->{problemLibrary}{root}.'.  Are you sure $problemLibrary{root} is set correctly in localOverrides.conf?' unless
	chdir($ce->{problemLibrary}{root}); 
    
    if ($LibraryRemote && $LibraryBranch) {
	# Check if there is an updated version of the OPL available
	# this is done by using ls-remote to get the commit sha at the 
	# head of the remote branch and looking to see if that sha is in
	# the local current branch
	my $currentBranch = `$git symbolic-ref --short HEAD`;
	$output = `$git ls-remote --heads $LibraryRemote`;
	@lines = split /\n/, $output;
	$commit='-1';
	
	foreach my $line (@lines) {
	    if ($line =~ /refs\/heads\/$LibraryBranch$/) {
		$line =~ /^(\w+)\s+/;
		$commit = $1;
		last;
	    }
	}
	
	$output = `$git branch --contains $commit`;

	if ($commit ne '-1' && $output !~ /\s+$currentBranch(\s+|$)/) {    
	    $upgradesAvailable = 1;
	    $upgradeMessage .= CGI::Tr(CGI::td($r->maketext('There are upgrades available for the Open Problem Library.')));
	} elsif ($commit eq '-1') {
	    $upgradesAvailable = 1;
	    $upgradeMessage .= CGI::Tr(CGI::td($r->maketext("Couldn't find OPL Branch [_1] in remote [_2]", $LibraryBranch, $LibraryRemote)));
	} else {
	    $upgradeMessage .= CGI::Tr(CGI::td($r->maketext('Your current branch of the Open Problem Library is up to date.', $LibraryBranch, $LibraryRemote)));
	}
    } 

    # Check to see if the OPL_update script has been run more recently
    # than the last pull of the library. 
    # this json file is (re)-created every time OPL-update is run. 
    my $jsonfile = $ce->{webworkDirs}{htdocs}.'/DATA/'.$ce->{problemLibrary}{tree};
    # If no json file then the OPL script needs to be run
    unless (-e $jsonfile) {
	$upgradesAvailable = 1;
	$upgradeMessage .= CGI::Tr(CGI::td($r->maketext('There is no library tree file for the library, you will need to run OPL-update.')));
    # otherwise we need to check to see if the date on the tree file
    # is after the date on the last commit in the library
    } else {
	my $opldate = stat($jsonfile)->[9];
	# skip this if the system doesnt support mtime
	if ($opldate) {
	    my $lastcommit = `git log -1 --pretty=format:%at`;
	    if ($lastcommit > $opldate) {
		$upgradesAvailable = 1;
		$upgradeMessage .= CGI::Tr(CGI::td($r->maketext('The library index is older than the library, you need to run OPL-update.')));
	    }
	}
    } 

    chdir($ce->{webwork_dir});

    if ($upgradesAvailable) {
	$upgradeMessage = CGI::Tr(CGI::th($r->maketext('The following upgrades are available for your WeBWorK system:'))).$upgradeMessage;
	return CGI::center(CGI::table({class=>"admin-messagebox"},$upgradeMessage));
    } else {
	return CGI::center(CGI::div({class=>"ResultsWithoutError"},
				    $r->maketext('Your systems are up to date!')));
    }

}

################################################################################
#   registration forms added by Mike Gage 5-5-2008
################################################################################


our $registered_file_name = "registered_???";

sub display_registration_form {
	my $self = shift;
	my $ce   = $self->r->ce;
	my $ww_version = $ce->{WW_VERSION};
	$registered_file_name = "registered_$ww_version";
	my $registeredQ = (-e ($ce->{courseDirs}->{root})."/$registered_file_name")?1:0;
	my $registration_subDisplay = ( defined($self->r->param('subDisplay') ) and $self->r->param('subDisplay') eq "registration") ?  1: 0;
	my $register_site = ($self->r->param("register_site"))?1:0;
	return 0  if $registeredQ or $register_site or $registration_subDisplay;     #otherwise return registration form
	return  q! 
	<center>
	<table class="admin-messagebox"><tr><td>
	!,
	CGI::p("If you are using your WeBWorK server for courses please help us out by registering your server."),
	CGI::p("We are often asked how many institutions are using WeBWorK and how many students are using
	WeBWorK.  Since WeBWorK is open source and can be freely downloaded from ".
	CGI::a({href=>'http://webwork.maa.org'},'http://webwork.maa.org' ). " or ".
	CGI::a({href=> 'http://webwork.maa.org/wiki'},'http://webwork.maa.org/wiki'). ", it is frequently 
	 difficult for us to give a reasonable answer to this  question."),
	CGI::p("You can help by registering your current version of WeBWorK -- click the button, answer a few
	questions (the ones you can answer easily) and submit the form to the MAA.  
	It takes less than two minutes.  Thank you!. -- The WeBWorK Team"),
	q!
	</td>
	</tr>
	<tr><td align="center">
	!,
	CGI::a({href=>$self->systemLink($self->r->urlpath, params=>{subDisplay=>"registration"})}, "Register"),
	q!
	</td></tr>
	</table>
	</center>
	!;
}

sub registration_form {
	my $self = shift;
	my $ce = $self->r->ce;
	
	print "<center>";

# 	"\nPlease ",
# 	CGI::a({href=>'mailto:gage@math.rochester.edu?'
# 	.'subject=WeBWorK%20Server%20Registration'
# 	.'&body='
# 	.uri_escape("Thanks for registering your WeBWorK server.  We'd appreciate if you would answer
# 	as many of these questions as you can conveniently.  We need this data so we can better 
# 	answer questions such as 'How many institutions have webwork servers?' and 'How many students
# 	use WeBWorK?'.  Your email and contact information  will be kept private.  We will 
# 	list your institution as one that uses WeBWorK unless you tell us to keep that private as well.
# 	\n\nThank you. \n\n--Mike Gage \n\n
# 	")
# 	.uri_escape("Server URL: ".$ce->{apache_root_url}." \n\n")
# 	.uri_escape("WeBWorK version: $main::VERSION \n\n")
# 	.uri_escape("Institution name (e.g. University of Rochester): \n\n")
# 	.uri_escape("Contact person name: \n\n")
# 	.uri_escape("Contact email: \n\n")
# 	.uri_escape("Approximate number of courses run each term: \n\n")
# 	.uri_escape("Approximate number of students using this server each term: \n\n")
# 	.uri_escape("Other institutions who use WeBWorK courses hosted on this server: \n\n")
# 	.uri_escape("Other comments: \n\n")
# 	},
# 	'click here'),
# 	q! to open your email application.  There are a few questions, some of which have already
# 	been filled in for your installation.  Fill in the other questions which you can answer easily and send
# 	the email to gage@math.rochester.edu
# 	!
	print  "\n",
		CGI::iframe({src => "http://forms.maa.org/r/WebworkSoftware/add.aspx", 
		   style=>"width:100%;height:700px", id=>"maa_content"}, "Your browser cannot use iframes"),
# 		CGI::p({style=>"text-align: left; width:60%"},
# 			"Please click on ",
# 			CGI::a({ href=>"http://forms.maa.org/r/WebworkSoftware/add.aspx" }, " this link "), 
# 			"and  fill out the form.",
# 		),
		"\n",
		 CGI::p({style=>"text-align: left; width:60%"},
	 		"The form will be sent to the MAA and your site will be listed along with all of the others on the  ",
	  		CGI::a({href=>"http://webwork.maa.org/wiki/WeBWorK_Sites"}, "site map"),
			"on the main WeBWorK Wiki.",
		);
	
	
	
	print  "\n",CGI::p({style=>"text-align: left; width:60%"},q!Once you have submitted your registration information you can hide the "registration" banner 
	for successive visits by clicking
	the button below. It writes an empty file (!.CGI::code('registered_versionNumber').q!) to the directory !.CGI::code('..../courses/admin')
	);
	
	print "</center>";
	print CGI::start_form(-method=>"POST", id=>"return_to_main_page", -action=>$self->r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	print CGI::p({style=>"text-align: center"}, CGI::submit(-id => "register_site", -name=>"register_site", -label=>"Site has been registered"));
	print CGI::end_form();
#	print q!<script type="text/javascript">
# 			$("#maa_content").load( alert("loaded") );
#  	     	$("#return_to_main_page").append(
#  	     		"<center><p>hey site is registered cool</p></center>"
#  	     	);
#  	     	
#  	        </script>
#  	        !;
}



sub do_registration {
	my $self = shift;
	my $ce   = $self->r->ce;
	my $registered_file_path = $ce->{courseDirs}->{root}."/$registered_file_name";
	# warn qq!`echo "info" >$registered_file_path`!;
	`echo "info" >$registered_file_path`;
	
	print  "\n<center>",CGI::p({style=>"text-align: left; width:60%"},q{Registration action completed.  Thank you very much for registering WeBWorK!"});
	
	print CGI::start_form(-method=>"POST", -action=>$self->r->uri);
	print $self->hidden_authen_fields;
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"registration_completed", -label=>"Continue"));
	print CGI::end_form();
	print "</center>";

}
################################################################################
# Utilities
################################################################################
sub formatReportOnDatabaseTables {
	my ($self, $tables_ok,$dbStatus) =  @_;
	my $r = $self->r;
	
	# print db status
	
		my %msg =(    WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A         => CGI::span({style=>"color:red"},$r->maketext("Table defined in schema but missing in database")),
					  WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B         => CGI::span({style=>"color:red"},$r->maketext("Table defined in database but missing in schema")),
					  WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B   => CGI::span({style=>"color:green"},$r->maketext("Table is ok")),
					  WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => CGI::span({style=>"color:red"},$r->maketext("Schema and database table definitions do not agree")),
		);
		my %msg2 =(    WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A        => CGI::span({style=>"color:red"},$r->maketext("Field missing in database")),
					  WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B         => CGI::span({style=>"color:red"},$r->maketext("Field missing in schema")),
					  WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B   => CGI::span({style=>"color:green"},$r->maketext("Field is ok")),
					  WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => CGI::span({style=>"color:red"},$r->maketext("Schema and database field definitions do not agree")),
		);
		my $all_tables_ok=1;
		my $extra_database_tables=0;
		my $extra_database_fields=0;
		my $str ='';
		$str .= CGI::start_ul();
		foreach my $table (sort keys %$dbStatus) {
			my $table_status = $dbStatus->{$table}->[0];
			$str .= CGI::li( CGI::b($table) . ': ' . $msg{ $table_status } );
			
			CASE: {
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B 
					&& do{ last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A
					&& do{
						   $all_tables_ok = 0; last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B
					&& do{
						   $extra_database_tables = 1; last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B
					&& do{ 
						my %fieldInfo = %{ $dbStatus->{$table}->[1] };
						$str .=CGI::start_ul();
						foreach my $key (keys %fieldInfo) {
							my $field_status = $fieldInfo{$key}->[0];
							CASE2: {
								$field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B 
									&& do{ 
									   $extra_database_fields = 1; last CASE2;
									};
								$field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A 
									&& do{ 
									   $all_tables_ok=0; last CASE2;
									};						    
							}
							$str .= CGI::li("$key => ". $msg2{$field_status });
						}
						$str .= CGI::end_ul();
					};
			}
			
			
		}
		$str.=CGI::end_ul();
		$str .= ($all_tables_ok)?CGI::p($r->maketext("Database tables are ok")) : "";
		return ($all_tables_ok, $extra_database_tables, $extra_database_fields, $str);
}
1;
