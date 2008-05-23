################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/CourseAdmin.pm,v 1.72 2008/05/09 00:42:24 gage Exp $
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
use WeBWorK::Utils::CourseManagement qw(addCourse renameCourse deleteCourse listCourses archiveCourse 
                                        listArchivedCourses unarchiveCourse);
use WeBWorK::Utils::DBImportExport qw(dbExport dbImport);
# needed for location management
use Net::IP;

use constant IMPORT_EXPORT_WARNING => "The ability to import and export
databases is still under development. It seems to work but it is <b>VERY</b>
slow on large courses.  You may prefer to use webwork2/bin/wwdb  or the mysql
dump facility for archiving large courses. Please send bug reports if you find
errors.";

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

	## if the user is asking for the downloaded database...
	#if (defined $r->param("download_exported_database")) {
	#	my $courseID = $r->param("export_courseID");
	#	my $random_chars = $r->param("download_exported_database");
	#	
	#	die "courseID not specified" unless defined $courseID;
	#	die "invalid file specification" unless $random_chars =~ m/^\w+$/;
	#	
	#	my $tempdir = $ce->{webworkDirs}->{tmp};
	#	my $export_file = "$tempdir/db_export_$random_chars";
	#	
	#	$self->reply_with_file("application/xml", $export_file, "${courseID}_database.xml", 0);
	#	
	#	return "";
	#}
	#
	## otherwise...
	
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
					$method_to_call = "do_rename_course";
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
			if (defined $r->param("archive_course")) {
				# validate or confirm
				@errors = $self->archive_course_validate;
				if (@errors) {
					$method_to_call = "archive_course_form";
				} else {
					$method_to_call = "archive_course_confirm";
				}
			} elsif (defined $r->param("confirm_archive_course")) {
				# validate and archive
				@errors = $self->archive_course_validate;
				if (@errors) {
					$method_to_call = "archive_course_form";
				} else {
					$method_to_call = "do_archive_course";
				}
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
				$method_to_call = "unarchive_course_form";
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

sub header {
	my ($self) = @_;
	my $method_to_call = $self->{method_to_call};
# 	if (defined $method_to_call and $method_to_call eq "do_export_database") {
# 		my $r = $self->r;
# 		my $courseID = $r->param("export_courseID");
# 		$r->content_type("application/octet-stream");
# 		$r->header_out("Content-Disposition" => "attachment; filename=\"${courseID}_database.xml\"");
# 		$r->send_http_header;
# 	} else {
		$self->SUPER::header;
#	}
}

# sends:
# 
# HTTP/1.1 200 OK
# Date: Fri, 09 Jul 2004 19:05:55 GMT
# Server: Apache/1.3.27 (Unix) mod_perl/1.27
# Content-Disposition: attachment; filename="mth143_database.xml"
# Connection: close
# Content-Type: application/octet-stream

sub content {
	my ($self) = @_;
	my $method_to_call = $self->{method_to_call};
	if (defined $method_to_call and $method_to_call eq "do_export_database") {
		#$self->do_export_database;
		$self->SUPER::content;
	} else {
		$self->SUPER::content;
	}
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
		           "Add Course"
		),
		" | ",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"rename_course"})}, "Rename Course"),
		" | ",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"delete_course"})}, "Delete Course"),
		" | ",
		# CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"export_database"})}, "Export Database"),
		# " | ",
		# CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"import_database"})}, "Import Database"),
		# " | ",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"archive_course"})}, "Archive Course"),
		 "|",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"unarchive_course"})}, "Unarchive Course"),
		 "|",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"manage_locations"})}, "Manage Locations"),
		CGI::hr(),
		$methodMessage,
		
	);
	
	print( CGI::p({style=>"text-align: center"}, $self->display_registration_form() ) ) if $self->display_registration_form();
	
	
	my @errors = @{$self->{errors}};
	
	
	if (@errors) {
		print CGI::div({class=>"ResultsWithError"},
			CGI::p("Please correct the following errors and try again:"),
			CGI::ul(CGI::li(\@errors)),
		);
	}
	
	if (defined $method_to_call and $method_to_call ne "") {
		$self->$method_to_call;
	} else {
	
		print CGI::h2("Courses");
	
		print CGI::start_ol();
		
		my @courseIDs = listCourses($ce);
		foreach my $courseID (sort {lc($a) cmp lc($b) } @courseIDs) {
			next if $courseID eq "admin"; # done already above
			my $urlpath = $r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", courseID => $courseID);
			my $tempCE = new WeBWorK::CourseEnvironment({
				%WeBWorK::SeedCE,
				courseName => $courseID,
			});
			print CGI::li(CGI::a({href=>$self->systemLink($urlpath, authen => 0)}, $courseID),
				CGI::code(
					$tempCE->{dbLayoutName},
				),
				(-r $tempCE->{courseFiles}->{environment}) ? "" : CGI::i(", missing course.conf"),
			
			);
			 
		}
		
		print CGI::end_ol();
		
		print CGI::h2("Archived Courses");
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
	
	print CGI::h2("Add Course");
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p("Specify an ID, title, and institution for the new course. The course ID may contain only letters, numbers, hyphens, and underscores.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Course ID:"),
			CGI::td(CGI::textfield(-name=>"add_courseID", -value=>$add_courseID, -size=>25)),
		),
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Course Title:"),
			CGI::td(CGI::textfield(-name=>"add_courseTitle", -value=>$add_courseTitle, -size=>25)),
		),
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Institution:"),
			CGI::td(CGI::textfield(-name=>"add_courseInstitution", -value=>$add_courseInstitution, -size=>25)),
		),
	);
	
	print CGI::p("To add the WeBWorK administrators to the new course (as instructors) check the box below.");
	my @checked = ($add_admin_users) ?(checked=>1): ();  # workaround because CGI::checkbox seems to have a bug -- it won't default to checked.
	print CGI::p({},CGI::input({-type=>'checkbox', -name=>"add_admin_users", @checked }, "Add WeBWorK administrators to new course"));
	
	print CGI::p("To add an additional instructor to the new course, specify user information below. The user ID may contain only 
	numbers, letters, hyphens, periods (dots), commas,and underscores.\n");
	
	print CGI::table({class=>"FormLayout"}, CGI::Tr({},
		CGI::td({},
			CGI::table({class=>"FormLayout"},
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, "User ID:"),
					CGI::td(CGI::textfield(-name=>"add_initial_userID", -value=>$add_initial_userID, -size=>25)),
				),
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, "Password:"),
					CGI::td(CGI::password_field(-name=>"add_initial_password", -value=>$add_initial_password, -size=>25)),
				),
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, "Confirm Password:"),
					CGI::td(CGI::password_field(-name=>"add_initial_confirmPassword", -value=>$add_initial_confirmPassword, -size=>25)),
				),
			),
		),
		CGI::td({},
			CGI::table({class=>"FormLayout"},
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, "First Name:"),
					CGI::td(CGI::textfield(-name=>"add_initial_firstName", -value=>$add_initial_firstName, -size=>25)),
				),
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, "Last Name:"),
					CGI::td(CGI::textfield(-name=>"add_initial_lastName", -value=>$add_initial_lastName, -size=>25)),
				),
				CGI::Tr({},
					CGI::th({class=>"LeftHeader"}, "Email Address:"),
					CGI::td(CGI::textfield(-name=>"add_initial_email", -value=>$add_initial_email, -size=>25)),
				),
			),
			
		),
	));
	
	print CGI::p("To copy problem templates from an existing course, select the course below.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Copy templates from:"),
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
	
	
	
	print CGI::p("Select a database layout below.");
	print CGI::start_table({class=>"FormLayout"});
	
	my %dbLayout_buttons;
	my $selected_dbLayout = defined $add_dbLayout ? $add_dbLayout : $ce->{dbLayout_order}[0];
	@dbLayout_buttons{@dbLayouts} = CGI::radio_group(-name=>"add_dbLayout",-values=>\@dbLayouts,-default=>$selected_dbLayout);
	foreach my $dbLayout (@dbLayouts) {
		my $dbLayoutLabel = (defined $ce->{dbLayout_descr}{$dbLayout})
			? "$dbLayout - " . $ce->{dbLayout_descr}{$dbLayout}
			: "$dbLayout - no description provided in global.conf";
		print CGI::Tr({},
			CGI::td({width=>'20%'}, $dbLayout_buttons{$dbLayout}),
			CGI::td($dbLayoutLabel),
		);
	}
	print CGI::end_table();
	print CGI::p({style=>"text-align: left"}, CGI::submit(-name=>"add_course", -label=>"Add Course"));
	
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
		push @errors, "You must specify a course ID.";
	}
	unless ($add_courseID =~ /^[\w-]*$/) { # regex copied from CourseAdministration.pm
		push @errors, "Course ID may only contain letters, numbers, hyphens, and underscores.";
	}
	if (grep { $add_courseID eq $_ } listCourses($ce)) {
		push @errors, "A course with ID $add_courseID already exists.";
	}
	#if ($add_courseTitle eq "") {
	#	push @errors, "You must specify a course title.";
	#}
	#if ($add_courseInstitution eq "") {
	#	push @errors, "You must specify an institution for this course.";
	#}
	
	if ($add_initial_userID ne "") {
		if ($add_initial_password eq "") {
			push @errors, "You must specify a password for the initial instructor.";
		}
		if ($add_initial_confirmPassword eq "") {
			push @errors, "You must confirm the password for the initial instructor.";
		}
		if ($add_initial_password ne $add_initial_confirmPassword) {
			push @errors, "The password and password confirmation for the instructor must match.";
		}
		if ($add_initial_firstName eq "") {
			push @errors, "You must specify a first name for the initial instructor.";
		}
		if ($add_initial_lastName eq "") {
			push @errors, "You must specify a last name for the initial instructor.";
		}
		if ($add_initial_email eq "") {
			push @errors, "You must specify an email address for the initial instructor.";
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
				$self->addbadmessage( "User '$userID' will not be copied from admin course as it is the initial instructor.");
				next;
			}
			my $User            = $db->getUser($userID);
			my $Password        = $db->getPassword($userID);
			my $PermissionLevel = $db->getPermissionLevel($userID);
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
	
	my %optional_arguments;
	if ($add_templates_course ne "") {
		$optional_arguments{templatesFrom} = $add_templates_course;
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
			CGI::p("Successfully created the course $add_courseID"),
		);
		my $newCoursePath = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",
			courseID => $add_courseID);
		my $newCourseURL = $self->systemLink($newCoursePath, authen => 0);
		print CGI::div({style=>"text-align: center"},
			CGI::a({href=>$newCourseURL}, "Log into $add_courseID"),
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
	
	my $rename_oldCourseID     = $r->param("rename_oldCourseID")     || "";
	my $rename_newCourseID     = $r->param("rename_newCourseID")     || "";
	
	my @courseIDs = listCourses($ce);
	@courseIDs    = sort {lc($a) cmp lc ($b) } @courseIDs;
	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
		my $tempCE = new WeBWorK::CourseEnvironment({
			%WeBWorK::SeedCE,
			courseName => $courseID,
		});
		$courseLabels{$courseID} = "$courseID (" . $tempCE->{dbLayoutName} . ")";
	}
	
	print CGI::h2("Rename Course");
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p("Select a course to rename.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Course Name:"),
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
			CGI::th({class=>"LeftHeader"}, "New Name:"),
			CGI::td(CGI::textfield(-name=>"rename_newCourseID", -value=>$rename_newCourseID, -size=>25)),
		),
	);
	
	print CGI::end_table();
	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"rename_course", -label=>"Rename Course"));
	
	print CGI::end_form();
}

sub rename_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $rename_oldCourseID     = $r->param("rename_oldCourseID")     || "";
	my $rename_newCourseID     = $r->param("rename_newCourseID")     || "";
	
	my @errors;
	
	if ($rename_oldCourseID eq "") {
		push @errors, "You must select a course to rename.";
	}
	if ($rename_newCourseID eq "") {
		push @errors, "You must specify a new name for the course.";
	}
	if ($rename_oldCourseID eq $rename_newCourseID) {
		push @errors, "Can't rename to the same name.";
	}
	unless ($rename_newCourseID =~ /^[\w-]*$/) { # regex copied from CourseAdministration.pm
		push @errors, "Course ID may only contain letters, numbers, hyphens, and underscores.";
	}
	if (grep { $rename_newCourseID eq $_ } listCourses($ce)) {
		push @errors, "A course with ID $rename_newCourseID already exists.";
	}
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $rename_oldCourseID,
	});
	
	return @errors;
}

sub do_rename_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $rename_oldCourseID     = $r->param("rename_oldCourseID")     || "";
	my $rename_newCourseID     = $r->param("rename_newCourseID")     || "";
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $rename_oldCourseID,
	});
	
	my $dbLayoutName = $ce->{dbLayoutName};
	
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
		);
	};
	if ($@) {
		my $error = $@;
		print CGI::div({class=>"ResultsWithError"},
			CGI::p("An error occured while renaming the course $rename_oldCourseID to $rename_newCourseID:"),
			CGI::tt(CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div({class=>"ResultsWithoutError"},
			CGI::p("Successfully renamed the course $rename_oldCourseID to $rename_newCourseID"),
		);
		my $newCoursePath = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",
			courseID => $rename_newCourseID);
		my $newCourseURL = $self->systemLink($newCoursePath, authen => 0);
		print CGI::div({style=>"text-align: center"},
			CGI::a({href=>$newCourseURL}, "Log into $rename_newCourseID"),
		);
	}
}

################################################################################

sub delete_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	
	my @courseIDs = listCourses($ce);
	@courseIDs    = sort {lc($a) cmp lc ($b) } @courseIDs; #make sort case insensitive 
	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
		my $tempCE = new WeBWorK::CourseEnvironment({
			%WeBWorK::SeedCE,
			courseName => $courseID,
		});
		$courseLabels{$courseID} = "$courseID (" . $tempCE->{dbLayoutName} . ")";
	}
	
	print CGI::h2("Delete Course");
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p("Select a course to delete.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Course Name:"),
			CGI::td(
				CGI::scrolling_list(
					-name => "delete_courseID",
					-values => \@courseIDs,
					-default => $delete_courseID,
					-size => 10,
					-multiple => 0,
					-labels => \%courseLabels,
				),
			),
		),
	);
	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"delete_course", -value=>"Delete Course"));
	
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
		push @errors, "You must specify a course name.";
	} elsif ($delete_courseID eq $urlpath->arg("courseID")) {
		push @errors, "You cannot delete the course you are currently using.";
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
	
	print CGI::h2("Delete Course");
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $delete_courseID,
	});
	
	print CGI::p("Are you sure you want to delete the course " . CGI::b($delete_courseID)
		. "? All course files and data will be destroyed. There is no undo available.");
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	print $self->hidden_fields(qw/delete_courseID/);
	
	print CGI::p({style=>"text-align: center"},
		CGI::submit(-name=>"decline_delete_course", -label=>"Don't delete"),
		"&nbsp;",
		CGI::submit(-name=>"confirm_delete_course", -label=>"Delete"),
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
			CGI::p("An error occured while deleting the course $delete_courseID:"),
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
			CGI::p("Successfully deleted the course $delete_courseID."),
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
		
		print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"decline_delete_course", -value=>"OK"),);
		
		print CGI::end_form();
	}
}

################################################################################

sub export_database_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my @tables = keys %{$ce->{dbLayout}};
	
	my $export_courseID = $r->param("export_courseID") || "";
	my @export_tables   = $r->param("export_tables");

	@export_tables = @tables unless @export_tables;
	
	my @courseIDs = listCourses($ce);
	@courseIDs    = sort {lc($a) cmp lc ($b) } @courseIDs; #make sort case insensitive 
	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
		my $tempCE = new WeBWorK::CourseEnvironment({
			%WeBWorK::SeedCE,
			courseName => $courseID,
		});
		$courseLabels{$courseID} = "$courseID (" . $tempCE->{dbLayoutName} . ")";
	}
	
	print CGI::h2("Export Database");
	
	print CGI::p(IMPORT_EXPORT_WARNING);
	
	print CGI::start_form(-method=>"GET", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p({},"Select a course to export the course's database. Please note
	that exporting can take a very long time for a large course. If you have
	shell access to the WeBWorK server, you may use the ", CGI::code("wwdb"), "
	utility instead.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Course Name:"),
			CGI::td(
				CGI::scrolling_list(
					-name => "export_courseID",
					-values => \@courseIDs,
					-default => $export_courseID,
					-size => 10,
					-multiple => 1,
					-labels => \%courseLabels,
				),
			),
		),
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Tables to Export:"),
			CGI::td({},
				CGI::checkbox_group(
					-name => "export_tables",
					-values => \@tables,
					-default => \@export_tables,
					-linebreak => 1,
				),
			),
		),
	);
	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"export_database", -value=>"Export Database"));
	
	print CGI::end_form();
}

sub export_database_validate {
	my ($self) = @_;
	my $r = $self->r;
	#my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my @export_courseID = $r->param("export_courseID") || ();
	my @export_tables   = $r->param("export_tables");

	my @errors;

	unless ( @export_courseID) {
		push @errors, "You must specify at least one course name.";
	}
	
	unless (@export_tables) {
		push @errors, "You must specify at least one table to export.";
	}
	
	return @errors;
}

sub do_export_database {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my @export_courseID = $r->param("export_courseID");
	my @export_tables   = $r->param("export_tables");
	
	foreach my $export_courseID (@export_courseID) {

		my $ce2 = new WeBWorK::CourseEnvironment({
			%WeBWorK::SeedCE,
			courseName => $export_courseID,
		});
		
		my $db2 = new WeBWorK::DB($ce2->{dbLayout});
		
		#my ($fh, $export_file) = tempfile("db_export_XXXXXX", DIR => $ce->{webworkDirs}->{tmp});
		#my ($random_chars) = $export_file =~ m/db_export_(\w+)$/;
		# export to the admin/templates directory
		my $exportFileName = "$export_courseID.exported.xml";
		my $exportFilePath = $ce->{courseDirs}->{templates}."/$exportFileName";
		# get a unique name
		my $number =1;
		while (-e "$exportFilePath.$number.gz") {
			$number++;
			last if $number>9;
		}
		if ($number<=9 ) {
			$exportFilePath = "$exportFilePath.$number";
			$exportFileName = "$exportFileName.$number";
		} else {
			$self->addbadmessage(CGI::p("There are more than 9 exported files for this course! Please
			remove some of these files."));
			$exportFilePath = "$exportFilePath.999";
			$exportFileName = "$exportFileName.999";
		}
	
		my $outputFileHandle = new IO::File(">$exportFilePath") or warn "Unable to create $exportFilePath";
	
		my @errors;
		eval {
			@errors = dbExport(
				db => $db2,
				#xml => $fh,
				xml => $outputFileHandle,
				tables => \@export_tables,
			);
		};
		
		$outputFileHandle->close();
	
		my $gzipMessage = system($ce->{externalPrograms}{gzip}, $exportFilePath);
		if ( !$gzipMessage ) {
			$self->addgoodmessage(CGI::p( "Database saved to templates/$exportFileName.gz.  
			You may download it with the file manager."));
		} else {
			$self->addbadmessage(CGI::p( "Failed to gzip file $exportFilePath"));
		}
		unlink $exportFilePath;
	} # end export of one course
	#push @errors, "Fatal exception: $@" if $@;
	#
	#if (@errors) {
	#	print CGI::div({class=>"ResultsWithError"},
	#		CGI::p("An error occured while exporting the database of course $export_courseID:"),
	#		CGI::ul(CGI::li(\@errors)),
	#	);
	#} else {
	#	print CGI::div({class=>"ResultsWithoutError"},
	#		CGI::p("Export succeeded."),
	#	);
	#	
	#	print CGI::div({style=>"text-align: center"},
	#		CGI::a({href=>$self->systemLink($urlpath, params=>{download_exported_database=>$random_chars, export_courseID=>undef})}, "Download Exported Database"),
	#	);
	#}
}

################################################################################

sub import_database_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my @tables = keys %{$ce->{dbLayout}};
	
	my $import_file     = $r->param("import_file")     || "";
	my $import_courseID = $r->param("import_courseID") || "";
	my @import_tables   = $r->param("import_tables");
	my $import_conflict = $r->param("import_conflict") || "skip";
	
	@import_tables = @tables unless @import_tables;
	
	my @courseIDs = listCourses($ce);
	@courseIDs    = sort {lc($a) cmp lc ($b) } @courseIDs; #make sort case insensitive 

	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
		my $tempCE = new WeBWorK::CourseEnvironment({
			%WeBWorK::SeedCE,
			courseName => $courseID,
		});
		$courseLabels{$courseID} = "$courseID (" . $tempCE->{dbLayoutName} . ")";
	}
	
	# find databases:
	my $templatesDir = $ce->{courseDirs}->{templates};
	my $exempt_dirs = join("|", keys %{ $r->ce->{courseFiles}->{problibs} });

	my @databaseFiles = listFilesRecursive(
		$templatesDir,
		qr/.\.exported\.xml\.\d*\.gz$/, # match these files  #FIXME this is too restricive!!
		qr/^(?:$exempt_dirs|CVS)$/, # prune these directories
		0, # match against file name only
		1, # prune against path relative to $templatesDir
	);

	my %databaseLabels = map { ($_ => $_) } @databaseFiles;
	
	#######
	
	print CGI::h2("Import Database");
	
	print CGI::p(IMPORT_EXPORT_WARNING);
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri, -enctype=>&CGI::MULTIPART);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Database XML File:"),
			CGI::td(
				CGI::scrolling_list(
					-name => "import_file",
					-values => \@databaseFiles,
					-default => undef,
					-size => 10,
					-multiple => 0,
					-labels => \%databaseLabels,
				),
			
			)
		),
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Tables to Import:"),
			CGI::td(
				CGI::checkbox_group(
					-name => "import_tables",
					-values => \@tables,
					-default => \@import_tables,
					-linebreak => 1,
				),
			),
		),
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Import into Course:"),
			CGI::td(
				CGI::scrolling_list(
					-name => "import_courseID",
					-values => \@courseIDs,
					-default => $import_courseID,
					-size => 10,
					-multiple => 0,
					-labels => \%courseLabels,
				),
			),
		),
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Conflicts:"),
			CGI::td(
				CGI::radio_group(
					-name => "import_conflict",
					-values => [qw/skip replace/],
					-default => $import_conflict,
					-linebreak=>'true',
					-labels => {
						skip => "Skip duplicate records",
						replace => "Replace duplicate records",
					},
				),
			),
		),
	);
	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"import_database", -value=>"Import Database"));
	
	print CGI::end_form();
}

sub import_database_validate {
	my ($self) = @_;
	my $r = $self->r;
	#my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $import_file     = $r->param("import_file")     || "";
	my $import_courseID = $r->param("import_courseID") || "";
	my @import_tables   = $r->param("import_tables");
	#my $import_conflict = $r->param("import_conflict") || "skip"; # not checked
	
	my @errors;
	
	if ($import_file eq "") {
		push @errors, "You must specify a database file to import.";
	}
	
	if ($import_courseID eq "") {
		push @errors, "You must specify a course name.";
	}
	
	unless (@import_tables) {
		push @errors, "You must specify at least one table to import.";
	}
	
	return @errors;
}

sub do_import_database {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $import_file     = $r->param("import_file");
	my $import_courseID = $r->param("import_courseID");
	my @import_tables   = $r->param("import_tables");
	my $import_conflict = $r->param("import_conflict") || "skip"; # need default -- not checked above
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $import_courseID,
	});
	
	my $db2 = new WeBWorK::DB($ce2->{dbLayout});
	
	# locate file
	my $templateDir = $ce->{courseDirs}->{templates};
	my $filePath = "$templateDir/$import_file";
	
	my $gunzipMessage = system( 'gunzip', $filePath);
	#FIXME
	#warn "gunzip ", $gunzipMessage;
	$filePath =~ s/\.gz$//;
	#warn "new file path is $filePath";
	my $fileHandle = new IO::File("<$filePath");
	# retrieve upload from upload cache
# 	my ($id, $hash) = split /\s+/, $import_file;
# 	my $upload = WeBWorK::Upload->retrieve($id, $hash,
# 		dir => $ce->{webworkDirs}->{uploadCache}
# 	);
	
	my @errors;
	
	eval {
		@errors = dbImport(
			db => $db2,
			# xml => $upload->fileHandle,
			xml => $fileHandle,
			tables => \@import_tables,
			conflict => $import_conflict,
		);
	};
	
	push @errors, "Fatal exception: $@" if $@;
	push @errors, $gunzipMessage if $gunzipMessage;
	
	if (@errors) {
		print CGI::div({class=>"ResultsWithError"},
			CGI::p("An error occured while importing the database of course $import_courseID:"),
			CGI::ul(CGI::li(\@errors)),
		);
	} else {
		print CGI::div({class=>"ResultsWithoutError"},
			CGI::p("Import succeeded."),
		);
	}
}
################################################################################

sub archive_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $archive_courseID     = $r->param("archive_courseID")     || "";
	
	my @courseIDs = listCourses($ce);
	@courseIDs    = sort {lc($a) cmp lc ($b) } @courseIDs; #make sort case insensitive 
	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
		my $tempCE = new WeBWorK::CourseEnvironment({
			%WeBWorK::SeedCE,
			courseName => $courseID,
		});
		$courseLabels{$courseID} = "$courseID (" . $tempCE->{dbLayoutName} . ")";
	}
	
	print CGI::h2("archive Course");
	
	print CGI::p(
		"Creates a gzipped tar archive (.tar.gz) of a course in the WeBWorK
		courses directory. Before archiving, the course database is dumped into
		a subdirectory of the course's DATA directory. Currently the archive
		facility is only available for mysql databases. It depends on the
		mysqldump application."
	);
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p("Select a course to archive.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Course Name:"),
			CGI::td(
				CGI::scrolling_list(
					-name => "archive_courseID",
					-values => \@courseIDs,
					-default => $archive_courseID,
					-size => 10,
					-multiple => 0,
					-labels => \%courseLabels,
				),
			),
			
		),
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Delete course:"),
			CGI::td({-style=>'color:red'}, CGI::checkbox({ 
			                    -name=>'delete_course', 
			                    -checked=>0,
			                    -value => 1,
			                    -label =>'Delete course after archiving. Caution there is no undo!',
			                   },
			       ),
			),
		)
	);
	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"archive_course", -value=>"archive Course"));
	
	print CGI::end_form();
}

sub archive_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $archive_courseID     = $r->param("archive_courseID")     || "";
	
	my @errors;
	
	if ($archive_courseID eq "") {
		push @errors, "You must specify a course name.";
	} elsif ($archive_courseID eq $urlpath->arg("courseID")) {
		push @errors, "You cannot archive the course you are currently using.";
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
	
	print CGI::h2("archive Course");
	
	my $archive_courseID     = $r->param("archive_courseID")     || "";
	my $delete_course_flag   = $r->param("delete_course")        || "";
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $archive_courseID,
	});
	
	if ($ce2->{dbLayoutName} ) {
		print CGI::p("Are you sure you want to archive the course " . CGI::b($archive_courseID)
		. "? ");
		print(CGI::p({-style=>'color:red; font-weight:bold'}, "Are you sure that you want to delete the course ".
		CGI::b($archive_courseID). " after archiving?  This cannot be undone!")) if $delete_course_flag;
		
	
	}
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	print $self->hidden_fields(qw/archive_courseID delete_course/);
	
	print CGI::p({style=>"text-align: center"},
		CGI::submit(-name=>"decline_archive_course", -value=>"Don't archive"),
		"&nbsp;",
		CGI::submit(-name=>"confirm_archive_course", -value=>"archive"),
	);
	
	print CGI::end_form();
}

sub do_archive_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $archive_courseID     = $r->param("archive_courseID")     || "";
	my $delete_course_flag   = $r->param("delete_course")        || "";
	
	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE,
		courseName => $archive_courseID,
	});
	
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
			CGI::p("An error occured while archiving the course $archive_courseID:"),
			CGI::tt(CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div({class=>"ResultsWithoutError"},
			CGI::p("Successfully archived the course $archive_courseID"),
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
					CGI::p("An error occured while deleting the course $archive_courseID:"),
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
					CGI::p("Successfully deleted the course $archive_courseID."),
				);
			}
		
		
		}
	   
# 		print CGI::start_form(-method=>"POST", -action=>$r->uri);
# 		print $self->hidden_authen_fields;
# 		print $self->hidden_fields("subDisplay");
# 		
# 		print CGI::p({style=>"text-align: center"}, CGI::submit("decline_archive_course", "OK"),);
# 		
# 		print CGI::end_form();
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
	
	print CGI::h2("Unarchive Course");
	
	print CGI::p(
		"Restores a course from a gzipped tar archive (.tar.gz). After
		unarchiving, the course database is restored from a subdirectory of the
		course's DATA directory. Currently the archive facility is only
		available for mysql databases. It depends on the mysqldump application."
	);
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p("Select a course to unarchive.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr({},
			CGI::th({class=>"LeftHeader"}, "Course Name:"),
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
				CGI::th({class=>"LeftHeader"}, CGI::checkbox(-name => "create_newCourseID",-default=>'',-value=>1, -label=>'New Name:')),
				CGI::td(CGI::textfield(-name=>"new_courseID", -value=>'', -size=>25)),
			),
	);
	
	print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"unarchive_course", -value=>"Unarchive Course"));
	
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
	my $courseID = $unarchive_courseID; $courseID =~ s/\.tar\.gz$//;
	
	if ( $create_newCourseID) {
		$courseID = $new_courseID;
	}
	debug(" unarchive_courseID $unarchive_courseID new_courseID $new_courseID ");

	if ($courseID eq "") {
		push @errors, "You must specify a course name.";
	} elsif ( -d $ce->{webworkDirs}->{courses}."/$courseID" ) {
	    #Check that a directory for this course doesn't already exist
		push @errors, "A directory already exists with the name $courseID. 
		 You must first delete this existing course before you can unarchive.";
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
	
	print CGI::h2("Unarchive Course");
	
	my $unarchive_courseID                    = $r->param("unarchive_courseID")     || "";
	my $create_newCourseID                    = $r->param("create_newCourseID")      || "";
	my $new_courseID                          = $r->param("new_courseID")           || "";

	my $courseID = $unarchive_courseID; $courseID =~ s/\.tar\.gz$//;
	
	if ( $create_newCourseID) {
		$courseID = $new_courseID;
	}	

    debug(" unarchive_courseID $unarchive_courseID new_courseID $new_courseID ");

	print CGI::start_form(-method=>"POST", -action=>$r->uri);
		print CGI::p($unarchive_courseID," to course ", 
	             CGI::input({-name=>'new_courseID', -value=>$courseID})
	);

	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	print $self->hidden_fields(qw/unarchive_courseID create_newCourseID/);
	
	print CGI::p({style=>"text-align: center"},
		CGI::submit(-name=>"decline_unarchive_course", -value=>"Don't unarchive"),
		"&nbsp;",
		CGI::submit(-name=>"confirm_unarchive_course", -value=>"unarchive"),
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
	
	my $old_courseID   = $unarchive_courseID; $old_courseID =~ s/.tar.gz//;

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
			CGI::p("An error occured while archiving the course $unarchive_courseID:"),
			CGI::tt(CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div({class=>"ResultsWithoutError"},
			CGI::p("Successfully unarchived  $unarchive_courseID to the course $new_courseID"),
		);
		 writeLog($ce, "hosted_courses", join("\t",
	    	"\tunarchived",
	    	"",
	    	"",
	    	"$unarchive_courseID to $new_courseID",
	    ));

		my $newCoursePath = $urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets",
			courseID => $new_courseID);
		my $newCourseURL = $self->systemLink($newCoursePath, authen => 0);
		print CGI::div({style=>"text-align: center"},
			CGI::a({href=>$newCourseURL}, "Log into $new_courseID"),
		);
	}
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
	
	print CGI::h2("Manage Locations");

	print CGI::p({},CGI::strong("Currently defined locations are listed below."));

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
				  "Select an action to perform:"));

	# edit action
	print CGI::Tr({}, 
		CGI::td({},[ $actionRadios[0], "Edit Location:" ]),
		CGI::td({-colspan=>2, -align=>"left"}, 
			CGI::div({-style=>"width:25%;"},
				  CGI::popup_menu(-name=>"edit_location",
					-values=>[@locationIDs]))) );
	# create action
	print CGI::Tr({},
		CGI::td({-align=>"left"},[ $actionRadios[1], 
			"Create Location:" ]),
		CGI::td({-colspan=>2},
			"Location name: " .
			CGI::textfield(-name=>"new_location_name",
				       -size=>"10",
				       -default=>$r->param("new_location_name")?$r->param("new_location_name"):'')));
	print CGI::Tr({valign=>'top'},
		CGI::td({}, ["&nbsp;", "Location description:"]),
		CGI::td({-colspan=>2}, 
			CGI::textfield(-name=>"new_location_description",
				       -size=>"50",
				       -default=>$r->param("new_location_description")?$r->param("new_location_description"):'')) );
	print CGI::Tr({}, CGI::td({},"&nbsp;"),
		CGI::td({-colspan=>3}, "Addresses for new location " .
			"(enter one per line, as single IP addresses " .
			"(e.g., 192.168.1.101), address masks (e.g., " .
			"192.168.1.0/24), or IP ranges (e.g., " .
			"192.168.1.101-192.168.1.150)):"));
	print CGI::Tr({}, CGI::td({}, "&nbsp;"),
		CGI::td({-colspan=>3},
			CGI::textarea({-name=>"new_location_addresses",
				       -rows=>5, -columns=>28,
				       -default=>$r->param("new_location_addresses")?$r->param("new_location_addresses"):''})));

	# delete action
	print CGI::Tr({}, 
		CGI::td({-colspan=>4}, 
			CGI::div({-class=>"ResultsWithError"},
				 CGI::em({}, "Deletion deletes all location " .
					 "data and related addresses, and is" .

 					 " not undoable!"))));
	print CGI::Tr({}, 
		CGI::td({}, 
			[ $actionRadios[2],
			  CGI::div({-class=>"ResultsWithError"},
				   "Delete location:") ]),
		CGI::td({-colspan=>2}, 
			CGI::popup_menu(-name=>"delete_location",
					-values=>["",
						  "selected_locations",
						  @locationIDs],
					-labels=>{selected_locations => "locations selected below",
						  "" => "no location"}) .
			CGI::span({-style=>"color:#C33;"}, "  Confirm: ") . 
			CGI::checkbox({-name=>"delete_confirm",
				       -value=>"true",
				       -label=>""}) ) );
	print CGI::end_table();

	print CGI::p({}, CGI::submit(-name=>"manage_locations", -value=>"Take Action!"));

	# existing location table
	# FIXME: the styles for this table should be off in a stylesheet 
	#    somewhere
	print CGI::start_div({align=>"center"}),
		CGI::start_table({border=>1, cellpadding=>2});
	print CGI::Tr({style=>"background-color:#e0e0e0;font-size:92%", align=>"left"}, 
		      CGI::th({}, ["Select", "Location", "Description", 
				   "Addresses"]));
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
	my $badLocAddr;
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
			       "Missing required input data. Please check " .
			       "that you have filled in all of the create " .
			       "location fields and resubmit.");
	} elsif ( $badAddr ) {
		$r->param("new_location_addresses", $locationAddr);
		print CGI::div({-class=>"ResultsWithError"}, 
			       "Address(es) $badAddr is(are) not in a " .
			       "recognized form.  Please check your " .
			       "data entry and resubmit.");
	} elsif ( $db->existsLocation( $locationID ) ) {
		print CGI::div({-class=>"ResultsWithError"}, 
			       "A location with the name $locationID " .
			       "already exists in the database.  Did " .
			       "you mean to edit that location instead?");
	} elsif ( $badLocAddr ) {
		print CGI::div({-class=>"ResultsWithError"}, 
			       "Address(es) $badLocAddr already exist " .
			       "in the database.  THIS SHOULD NOT HAPPEN!  " .
			       "Please double check the integrity of " .
			       "the WeBWorK database before continuing.");
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
			       "Location $locationID has been created, " .
			       "with addresses " . join(', ', @addresses) .
			       ".");
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
			       "Please provide a location name " . 
			       "to delete.");

	} elsif ( $badID = $self->existsLocations_helper( @delLocations ) ) {
		print CGI::div({-class=>"ResultsWithError"}, 
			       "No location with name $badID " . 
			       "exists in the database.");

	} elsif ( ! $confirm || $confirm ne 'true' ) {
		print CGI::div({-class=>"ResultsWithError"}, 
			       "Location deletion requires confirmation.");
	} else {
		foreach ( @delLocations ) {
			$db->deleteLocation( $_ );
		}
		print CGI::div({-class=>"ResultsWithoutError"},
			       "Location" . (@delLocations > 1 ? 's ' : ' ') .
			       join(', ', @delLocations) . 
			       (@delLocations > 1 ? ' have ' : ' has ' ) . 
			       'been deleted.');
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

		print CGI::h2("Editing location ", $locationID);

		print CGI::p({},"Edit the current value of the location ",
			     "description, if desired, then add and select ",
			     "addresses to delete, and then click the ", 
			     "\"Take Action\" button to make all of your ",
			     "changes.  Or, click \"Manage Locations\" ",
			     "above to make no changes and return to the ",
			     "Manage Locations page.");

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
				"Location description: ", CGI::br(),
				CGI::textfield(-name=>"location_description",
					       -size=>"50",
					       -default=>$location->description)));
		print CGI::Tr({-valign=>'top'},
			CGI::td({-width=>"50%"},
				"Addresses to add to the location " .
				"(enter one per line, as single IP addresses " .
				"(e.g., 192.168.1.101), address masks " .
				"(e.g., 192.168.1.0/24), or IP ranges " .
				"(e.g., 192.168.1.101-192.168.1.150)):" . 
				CGI::br() .
				CGI::textarea({-name=>"new_location_addresses",
					       -rows=>5, -columns=>28})),
			CGI::td({}, "&nbsp;"),
			CGI::td({-width=>"50%"},
				"Existing addresses for the location are " .
				"given in the scrolling list below.  Select " .
				"addresses from the list to delete them:" . 
				CGI::br() .
				CGI::scrolling_list(-name=>'delete_location_addresses',
						    -values=>[@locAddresses],
						    -size=>8,
						    -multiple=>'multiple') .
				CGI::br() . "or: " .
				CGI::checkbox(-name=>'delete_all_addresses',
					      -value=>'true',
					      -label=>'Delete all existing addresses')
				 ));

		print CGI::end_table();

		print CGI::p({},CGI::submit(-value=>'Take Action!'));

	} else {
		print CGI::div({-class=>"ResultsWithError"},
			       "Location $locationID does not exist " .
			       "in the WeBWorK database.  Please check " .
			       "your input (perhaps you need to reload " .
			       "the location management page?).");

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
			       "No location specified to edit?! " .
			       "Please check your input data.");
		$self->manage_location_form;

	} elsif ( ! $db->existsLocation( $locationID ) ) {
		print CGI::div({-class=>"ResultsWithError"},
			       "Location $locationID does not exist " .
			       "in the WeBWorK database.  Please check " .
			       "your input (perhaps you need to reload " .
			       "the location management page?).");
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
			$doneMsg .= CGI::p({},"Updated location description.");
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
		$addrMsg .= "Deleted addresses " . join(', ', @toDel) .
			" from location." . CGI::br() if ( @toDel );
		$addrMsg .= "Added addresses " . join(', ', @toAdd) . 
			" to location $locationID.  " if ( @toAdd );

		my $badMsg = '';
		$badMsg .= 'Address(es) ' . join(', ', @noAdd) .
			" in the add list is(are) already in the " .
			"location $locationID, and so were " .
			"skipped." . CGI::br() if ( @noAdd );
		$badMsg .= "Address(es) $badAddr is(are) not in a " .
			"recognized form.  Please check your data " .
			"entry and try again." . CGI::br() if ( $badAddr );
		$badMsg .= 'Address(es) ' . join(', ', @noDel) . 
			" in the delete list is(are) not in the " .
			"location $locationID, and so were " .
			"skipped." if ( @noDel );

		print CGI::div({-class=>"ResultsWithError"}, $badMsg)
			if ( $badMsg );
		if ( $doneMsg || $addrMsg ) {
			print CGI::div({-class=>"ResultsWithoutError"},
				       CGI::p({}, $doneMsg, $addrMsg));
		} else {
			print CGI::div({-class=>"ResultsWithError"},
				       "No valid changes submitted for ",
				       "location $locationID.");
		}

		$self->edit_location_form;
	}
}

################################################################################
#   registration forms added by Mike Gage 5-5-2008
################################################################################

our $registered_file_name = "registered_$main::VERSION";
sub display_registration_form {
my $self = shift;
my $ce   = $self->r->ce;
my $registeredQ = (-e ($ce->{courseDirs}->{root})."/$registered_file_name")?1:0;
my $registration_subDisplay = ( $self->{method_to_call} eq "registration_form") ?  1: 0;
return 0  if $registeredQ or $self->r->param("register_site");     #otherwise return registration form
return  q! 
<center>
<table class="messagebox" style="background-color:#FFFFCC;width:60%">
<tr><td>
!,
CGI::p("If you are using your WeBWorK server for courses please help us out by registering your server."),
CGI::p("We are often asked how many institutions are using WeBWorK and how many students are using
WeBWorK  Since WeBWorK is open source and can be freely downloaded from http://www.openwebwork.org
and http://webwork.maa.org  it is frequently difficult for us to give a reasonable answer to this 
question."),
CGI::p("You can help by registering your current version of WeBWorK -- click the button, answer a few
questions (the ones you can answer easily) and send the email.  It takes less than two minutes.  Thank you!. -- The WeBWorK Team"),
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
print  "\n",CGI::p({style=>"text-align: left; width:60%"},
"\nPlease ",
CGI::a({href=>'mailto:gage@math.rochester.edu?'
.'subject=WeBWorK%20Server%20Registration'
.'&body='
.uri_escape("Thanks for registering your WeBWorK server.  We'd appreciate if you would answer
as many of these questions as you can conveniently.  We need this data so we can better 
answer questions such as 'How many institutions have webwork servers?' and 'How many students
use WeBWorK?'.  Your email and contact information  will be kept private.  We will 
list your institution as one that uses WeBWorK unless you tell us to keep that private as well.
\n\nThank you. \n\n--Mike Gage \n\n
")
.uri_escape("Server URL: ".$ce->{apache_root_url}." \n\n")
.uri_escape("WeBWorK version: $main::VERSION \n\n")
.uri_escape("Institution name (e.g. University of Rochester): \n\n")
.uri_escape("Contact person name: \n\n")
.uri_escape("Contact email: \n\n")
.uri_escape("Approximate number of courses run each term: \n\n")
.uri_escape("Approximate number of students using this server each term: \n\n")
.uri_escape("Other institutions who use WeBWorK courses hosted on this server: \n\n")
.uri_escape("Other comments: \n\n")
},
'click here'),
q! to open your email application.  There are a few questions, some of which have already
been filled in for your installation.  Fill in the other questions which you can answer easily and send
the email to gage\@math.rochester.edu
!
);



print  "\n",CGI::p({style=>"text-align: left; width:60%"},q!Once you have emailed your registration information you can hide the "registration" banner 
for successive visits by clicking
the button below.!)
;

print "</center>";
print CGI::start_form(-method=>"POST", -action=>$self->r->uri);
print $self->hidden_authen_fields;
print $self->hidden_fields("subDisplay");
print CGI::p({style=>"text-align: center"}, CGI::submit(-name=>"register_site", -label=>"Site has been registered"));
print CGI::end_form();
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
1;
