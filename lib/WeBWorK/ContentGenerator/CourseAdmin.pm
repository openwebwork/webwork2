################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/CourseAdmin.pm,v 1.31 2004/10/10 21:04:47 sh002i Exp $
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
use CGI::Pretty qw();
use Data::Dumper;
use File::Temp qw/tempfile/;
use WeBWorK::CourseEnvironment;
use WeBWorK::Utils qw(cryptPassword writeLog);
use WeBWorK::Utils::CourseManagement qw(addCourse deleteCourse listCourses);
use WeBWorK::Utils::DBImportExport qw(dbExport dbImport);

# put the following database layouts at the top of the list, in this order
our @DB_LAYOUT_ORDER = qw/sql_single gdbm sql/;

our %DB_LAYOUT_DESCRIPTIONS = (
	gdbm => "Deprecated. Uses GDBM databases to record WeBWorK data. Use this layout if the course must be used with WeBWorK 1.x.",
	sql => "Deprecated. Uses a separate SQL database to record WeBWorK data for each course.",
	sql_single => "Uses a single SQL database to record WeBWorK data for all courses using this layout. This is the recommended layout for new courses.",
);

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
	if (defined $method_to_call and $method_to_call eq "do_export_database") {
		my $r = $self->r;
		my $courseID = $r->param("export_courseID");
		$r->content_type("application/octet-stream");
		$r->header_out("Content-Disposition" => "attachment; filename=\"${courseID}_database.xml\"");
		$r->send_http_header;
	} else {
		$self->SUPER::header;
	}
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
		$self->do_export_database;
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
	
	print CGI::p({style=>"text-align: center"},
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"add_course"})}, "Add Course"),
		" | ",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"delete_course"})}, "Delete Course"),
		" | ",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"export_database"})}, "Export Database"),
		" | ",
		CGI::a({href=>$self->systemLink($urlpath, params=>{subDisplay=>"import_database"})}, "Import Database"),
	);
	
	print CGI::hr();
	
	my @errors = @{$self->{errors}};
	my $method_to_call = $self->{method_to_call};
	
	if (@errors) {
		print CGI::div({class=>"ResultsWithError"},
			CGI::p("Please correct the following errors and try again:"),
			CGI::ul(CGI::li(\@errors)),
		);
	}
	
	if (defined $method_to_call and $method_to_call ne "") {
		$self->$method_to_call;
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
	
	my $add_courseID                     = $r->param("add_courseID") || "";
	my $add_courseTitle                  = $r->param("add_courseTitle") || "";
	my $add_courseInstitution            = $r->param("add_courseInstitution") || "";
	
	my $add_admin_users                  = $r->param("add_admin_users") || "";
	
	my $add_initial_userID               = $r->param("add_initial_userID") || "";
	my $add_initial_password             = $r->param("add_initial_password") || "";
	my $add_initial_confirmPassword      = $r->param("add_initial_confirmPassword") || "";
	my $add_initial_firstName            = $r->param("add_initial_firstName") || "";
	my $add_initial_lastName             = $r->param("add_initial_lastName") || "";
	my $add_initial_email                = $r->param("add_initial_email") || "";
	
	my $add_templates_course             = $r->param("add_templates_course") || "";
	
	my $add_dbLayout                     = $r->param("add_dbLayout") || "";
	my $add_sql_host                     = $r->param("add_sql_host") || "";
	my $add_sql_port                     = $r->param("add_sql_port") || "";
	my $add_sql_username                 = $r->param("add_sql_username") || "";
	my $add_sql_password                 = $r->param("add_sql_password") || "";
	my $add_sql_database                 = $r->param("add_sql_database") || "";
	my $add_sql_wwhost                   = $r->param("add_sql_wwhost") || "";
	my $add_gdbm_globalUserID            = $r->param("add_gdbm_globalUserID") || "";
	
	my @dbLayouts = do {
		my @ordered_layouts;
		foreach my $layout (@DB_LAYOUT_ORDER) {
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
	
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		"COURSENAME",
	);
	
	my $dbi_source = do {
		# find the most common SQL source (stolen from CourseManagement.pm)
		my %sources;
		foreach my $table (keys %{ $ce2->{dbLayouts}->{sql} }) {
			$sources{$ce2->{dbLayouts}->{sql}->{$table}->{source}}++;
		}
		my $source;
		if (keys %sources > 1) {
			foreach my $curr (keys %sources) {
				$source = $curr if not defined $source or 
					$sources{$curr} > $sources{$source};
			}
		} else {
			($source) = keys %sources;
		}
		$source;
	};
	
	my @existingCourses = listCourses($ce);
	@existingCourses = sort @existingCourses;
	
	print CGI::h2("Add Course");
	
	print CGI::start_form("POST", $r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p("Specify an ID, title, and institution for the new course. The course ID may contain only letters, numbers, hyphens, and underscores.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Course ID:"),
			CGI::td(CGI::textfield("add_courseID", $add_courseID, 25)),
		),
		CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Course Title:"),
			CGI::td(CGI::textfield("add_courseTitle", $add_courseTitle, 25)),
		),
		CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Institution:"),
			CGI::td(CGI::textfield("add_courseInstitution", $add_courseInstitution, 25)),
		),
	);
	
	print CGI::p("To add the WeBWorK administrators to the new course (as instructors) check the box below.");
	
	print CGI::p(CGI::checkbox("add_admin_users", $add_admin_users, "on", "Add WeBWorK administrators to new course"));
	
	print CGI::p("To add an additional instructor to the new course, specify user information below. The user ID may contain only numbers, letters, hyphens, and underscores.");
	
	print CGI::table({class=>"FormLayout"}, CGI::Tr(
		CGI::td(
			CGI::table({class=>"FormLayout"},
				CGI::Tr(
					CGI::th({class=>"LeftHeader"}, "User ID:"),
					CGI::td(CGI::textfield("add_initial_userID", $add_initial_userID, 25)),
				),
				CGI::Tr(
					CGI::th({class=>"LeftHeader"}, "Password:"),
					CGI::td(CGI::password_field("add_initial_password", $add_initial_password, 25)),
				),
				CGI::Tr(
					CGI::th({class=>"LeftHeader"}, "Confirm Password:"),
					CGI::td(CGI::password_field("add_initial_confirmPassword", $add_initial_confirmPassword, 25)),
				),
			),
		),
		CGI::td(
			CGI::table({class=>"FormLayout"},
				CGI::Tr(
					CGI::th({class=>"LeftHeader"}, "First Name:"),
					CGI::td(CGI::textfield("add_initial_firstName", $add_initial_firstName, 25)),
				),
				CGI::Tr(
					CGI::th({class=>"LeftHeader"}, "Last Name:"),
					CGI::td(CGI::textfield("add_initial_lastName", $add_initial_lastName, 25)),
				),
				CGI::Tr(
					CGI::th({class=>"LeftHeader"}, "Email Address:"),
					CGI::td(CGI::textfield("add_initial_email", $add_initial_email, 25)),
				),
			),
			
		),
	));
	
	print CGI::p("To copy problem templates from an existing course, select the course below.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
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
	
	foreach my $dbLayout (@dbLayouts) {
		print CGI::start_table({class=>"FormLayout"});
		
		my $dbLayoutLabel = (defined $DB_LAYOUT_DESCRIPTIONS{$dbLayout})
			? "$dbLayout - $DB_LAYOUT_DESCRIPTIONS{$dbLayout}"
			: $dbLayout;
		
		# we generate singleton radio button tags ourselves because it's too much of a pain to do it with CGI.pm
		print CGI::Tr(
			CGI::td({style=>"text-align: right"},
				'<input type="radio" name="add_dbLayout" value="' . $dbLayout . '"'
				. ($add_dbLayout eq $dbLayout ? " checked" : "") . ' />',
			),
			CGI::td($dbLayoutLabel),
		);
		
		print CGI::start_Tr();
		print CGI::td(); # for indentation :(
		print CGI::start_td();
		
		if ($dbLayout eq "sql") {
			print CGI::start_table({class=>"FormLayout"});
			print CGI::Tr(CGI::td({colspan=>2}, 
					"Enter the user ID and password for an SQL account with sufficient permissions to create a new database."
				)
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Admin Username:"),
				CGI::td(CGI::textfield("add_sql_username", $add_sql_username, 25)),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Admin Password:"),
				CGI::td(CGI::password_field("add_sql_password", $add_sql_password, 25)),
			);
			
			print CGI::Tr(CGI::td({colspan=>2},
					"The optionial SQL settings you enter below must match the settings in the DBI source"
					. " specification " . CGI::tt($dbi_source) . ". Replace " . CGI::tt("COURSENAME")
					. " with the course name you entered above."
				)
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Server Host:"),
				CGI::td(
					CGI::textfield("add_sql_host", $add_sql_host, 25),
					CGI::br(),
					CGI::small("Leave blank to use the default host."),
				),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Server Port:"),
				CGI::td(
					CGI::textfield("add_sql_port", $add_sql_port, 25),
					CGI::br(),
					CGI::small("Leave blank to use the default port."),
				),
			);
		
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Database Name:"),
				CGI::td(
					CGI::textfield("add_sql_database", $add_sql_database, 25),
					CGI::br(),
					CGI::small("Leave blank to use the name ", CGI::tt("webwork_COURSENAME"), "."),
				),
			);
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "WeBWorK Host:"),
				CGI::td(
					CGI::textfield("add_sql_wwhost", $add_sql_wwhost || "localhost", 25),
					CGI::br(),
					CGI::small("If the SQL server does not run on the same host as WeBWorK, enter the host name of the WeBWorK server as seen by the SQL server."),
				),
			);
			print CGI::end_table();
		} elsif ($dbLayout eq "gdbm") {
			print CGI::start_table({class=>"FormLayout"});
			print CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "GDBM Global User ID:"),
				CGI::td(CGI::textfield("add_gdbm_globalUserID", $add_gdbm_globalUserID || "global_user", 25)),
			);
			print CGI::end_table();
		}
		
		print CGI::end_td();
		print CGI::end_Tr();
		print CGI::end_table();
	}
	
	print CGI::p({style=>"text-align: center"}, CGI::submit("add_course", "Add Course"));
	
	print CGI::end_form();
}

sub add_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $add_courseID                     = $r->param("add_courseID") || "";
	my $add_courseTitle                  = $r->param("add_courseTitle") || "";
	my $add_courseInstitution            = $r->param("add_courseInstitution") || "";
	
	my $add_admin_users                  = $r->param("add_admin_users") || "";
	
	my $add_initial_userID               = $r->param("add_initial_userID") || "";
	my $add_initial_password             = $r->param("add_initial_password") || "";
	my $add_initial_confirmPassword      = $r->param("add_initial_confirmPassword") || "";
	my $add_initial_firstName            = $r->param("add_initial_firstName") || "";
	my $add_initial_lastName             = $r->param("add_initial_lastName") || "";
	my $add_initial_email                = $r->param("add_initial_email") || "";
	
	my $add_templates_course             = $r->param("add_templates_course") || "";
	
	my $add_dbLayout                     = $r->param("add_dbLayout") || "";
	my $add_sql_host                     = $r->param("add_sql_host") || "";
	my $add_sql_port                     = $r->param("add_sql_port") || "";
	my $add_sql_username                 = $r->param("add_sql_username") || "";
	my $add_sql_password                 = $r->param("add_sql_password") || "";
	my $add_sql_database                 = $r->param("add_sql_database") || "";
	my $add_sql_wwhost                   = $r->param("add_sql_wwhost") || "";
	my $add_gdbm_globalUserID            = $r->param("add_gdbm_globalUserID") || "";
	
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
	if ($add_courseTitle eq "") {
		push @errors, "You must specify a course title.";
	}
	if ($add_courseInstitution eq "") {
		push @errors, "You must specify an institution for this course.";
	}
	
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
			if ($add_dbLayout eq "sql") {
				push @errors, "You must specify the SQL admin username." if $add_sql_username eq "";
				push @errors, "You must specify the WeBWorK host." if $add_sql_wwhost eq "";
			} elsif ($add_dbLayout eq "gdbm") {
				push @errors, "You must specify the GDBM global user ID." if $add_gdbm_globalUserID eq "";
			}
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
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;
	
	my $add_courseID                     = $r->param("add_courseID") || "";
	my $add_courseTitle                  = $r->param("add_courseTitle") || "";
	my $add_courseInstitution            = $r->param("add_courseInstitution") || "";
	
	my $add_admin_users                  = $r->param("add_admin_users") || "";
	
	my $add_initial_userID               = $r->param("add_initial_userID") || "";
	my $add_initial_password             = $r->param("add_initial_password") || "";
	my $add_initial_confirmPassword      = $r->param("add_initial_confirmPassword") || "";
	my $add_initial_firstName            = $r->param("add_initial_firstName") || "";
	my $add_initial_lastName             = $r->param("add_initial_lastName") || "";
	my $add_initial_email                = $r->param("add_initial_email") || "";
	
	my $add_templates_course             = $r->param("add_templates_course") || "";
	
	my $add_dbLayout                     = $r->param("add_dbLayout") || "";
	my $add_sql_host                     = $r->param("add_sql_host") || "";
	my $add_sql_port                     = $r->param("add_sql_port") || "";
	my $add_sql_username                 = $r->param("add_sql_username") || "";
	my $add_sql_password                 = $r->param("add_sql_password") || "";
	my $add_sql_database                 = $r->param("add_sql_database") || "";
	my $add_sql_wwhost                   = $r->param("add_sql_wwhost") || "";
	my $add_gdbm_globalUserID            = $r->param("add_gdbm_globalUserID") || "";

	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		$add_courseID,
	);
	
	my %courseOptions = ( dbLayoutName => $add_dbLayout );
	
	if ($add_initial_email ne "") {
		$courseOptions{allowedRecipients} = [ $add_initial_email ];
		# don't set feedbackRecipients -- this just gets in the way of the more
		# intelligent "receive_recipients" method.
		#$courseOptions{feedbackRecipients} = [ $add_initial_email ];
	}
	
	if ($add_dbLayout eq "gdbm") {
		$courseOptions{globalUserID} = $add_gdbm_globalUserID if $add_gdbm_globalUserID ne "";
	}
	
	my %dbOptions;
	if ($add_dbLayout eq "sql") {
		$dbOptions{host}     = $add_sql_host if $add_sql_host ne "";
		$dbOptions{port}     = $add_sql_port if $add_sql_port ne "";
		$dbOptions{username} = $add_sql_username;
		$dbOptions{password} = $add_sql_password;
		$dbOptions{database} = $add_sql_database || "webwork_$add_courseID";
		$dbOptions{wwhost}   = $add_sql_wwhost;
	}
	
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
			push @users, [ $User, $Password, $PermissionLevel ];
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
	    	$add_courseInstitution,
	    	$add_courseTitle,
	    	$add_courseID,
	    	$add_initial_firstName,
	    	$add_initial_lastName,
	  		$add_initial_email,
	    ));
	    # add contact to admin course as student?
	    # FIXME -- should we do this?
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

sub delete_course_form {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	my $delete_sql_host     = $r->param("delete_sql_host")     || "";
	my $delete_sql_port     = $r->param("delete_sql_port")     || "";
	my $delete_sql_username = $r->param("delete_sql_username") || "";
	my $delete_sql_password = $r->param("delete_sql_password") || "";
	my $delete_sql_database = $r->param("delete_sql_database")    || "";
	
	my @courseIDs = listCourses($ce);
	@courseIDs    = sort @courseIDs;
	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
		my $tempCE = WeBWorK::CourseEnvironment->new(
			$ce->{webworkDirs}->{root},
			$ce->{webworkURLs}->{root},
			$ce->{pg}->{directories}->{root},
			$courseID,
		);
		$courseLabels{$courseID} = "$courseID (" . $tempCE->{dbLayoutName} . ")";
	}
	
	print CGI::h2("Delete Course");
	
	print CGI::start_form("POST", $r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p("Select a course to delete.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
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
	
	print CGI::p(
		"If the course's database layout (indicated in parentheses above) is "
		. CGI::b("sql") . ", supply the SQL connections information requested below."
	);
	
	print CGI::start_table({class=>"FormLayout"});
	print CGI::Tr(CGI::td({colspan=>2}, 
			"Enter the user ID and password for an SQL account with sufficient permissions to delete an existing database."
		)
	);
	print CGI::Tr(
		CGI::th({class=>"LeftHeader"}, "SQL Admin Username:"),
		CGI::td(CGI::textfield("delete_sql_username", $delete_sql_username, 25)),
	);
	print CGI::Tr(
		CGI::th({class=>"LeftHeader"}, "SQL Admin Password:"),
		CGI::td(CGI::password_field("delete_sql_password", $delete_sql_password, 25)),
	);
	
	#print CGI::Tr(CGI::td({colspan=>2},
	#		"The optionial SQL settings you enter below must match the settings in the DBI source"
	#		. " specification " . CGI::tt($dbi_source) . ". Replace " . CGI::tt("COURSENAME")
	#		. " with the course name you entered above."
	#	)
	#);
	print CGI::Tr(
		CGI::th({class=>"LeftHeader"}, "SQL Server Host:"),
		CGI::td(
			CGI::textfield("delete_sql_host", $delete_sql_host, 25),
			CGI::br(),
			CGI::small("Leave blank to use the default host."),
		),
	);
	print CGI::Tr(
		CGI::th({class=>"LeftHeader"}, "SQL Server Port:"),
		CGI::td(
			CGI::textfield("delete_sql_port", $delete_sql_port, 25),
			CGI::br(),
			CGI::small("Leave blank to use the default port."),
		),
	);

	print CGI::Tr(
		CGI::th({class=>"LeftHeader"}, "SQL Database Name:"),
		CGI::td(
			CGI::textfield("delete_sql_database", $delete_sql_database, 25),
			CGI::br(),
			CGI::small("Leave blank to use the name ", CGI::tt("webwork_COURSENAME"), "."),
		),
	);
	print CGI::end_table();
	
	print CGI::p({style=>"text-align: center"}, CGI::submit("delete_course", "Delete Course"));
	
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
	my $delete_sql_host     = $r->param("delete_sql_host")     || "";
	my $delete_sql_port     = $r->param("delete_sql_port")     || "";
	my $delete_sql_username = $r->param("delete_sql_username") || "";
	my $delete_sql_password = $r->param("delete_sql_password") || "";
	my $delete_sql_database = $r->param("delete_sql_database") || "";
	
	my @errors;
	
	if ($delete_courseID eq "") {
		push @errors, "You must specify a course name.";
	} elsif ($delete_courseID eq $urlpath->arg("courseID")) {
		push @errors, "You cannot delete the course you are currently using.";
	}
	
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		$delete_courseID,
	);
	
	if ($ce2->{dbLayoutName} eq "sql") {
		push @errors, "You must specify the SQL admin username." if $delete_sql_username eq "";
		#push @errors, "You must specify the SQL admin password." if $delete_sql_password eq "";
		#push @errors, "You must specify the SQL database name." if $delete_sql_database eq "";
	}
	
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
	my $delete_sql_host     = $r->param("delete_sql_host")     || "";
	my $delete_sql_port     = $r->param("delete_sql_port")     || "";
	my $delete_sql_database = $r->param("delete_sql_database") || "";
	
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		$delete_courseID,
	);
	
	if ($ce2->{dbLayoutName} eq "sql") {
		print CGI::p("Are you sure you want to delete the course " . CGI::b($delete_courseID)
		. "? All course files and data and the following database will be destroyed."
		. " There is no undo available.");
		
		print CGI::table({class=>"FormLayout"},
			CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Server Host:"),
				CGI::td($delete_sql_host || "system default"),
			),
			CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Server Port:"),
				CGI::td($delete_sql_port || "system default"),
			),
			CGI::Tr(
				CGI::th({class=>"LeftHeader"}, "SQL Database Name:"),
				CGI::td($delete_sql_database || "webwork_$delete_courseID"),
			),
		);
	} else {
		print CGI::p("Are you sure you want to delete the course " . CGI::b($delete_courseID)
			. "? All course files and data will be destroyed. There is no undo available.");
	}
	
	print CGI::start_form("POST", $r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	print $self->hidden_fields(qw/delete_courseID delete_sql_host delete_sql_port delete_sql_username delete_sql_password delete_sql_database/);
	
	print CGI::p({style=>"text-align: center"},
		CGI::submit("decline_delete_course", "Don't delete"),
		"&nbsp;",
		CGI::submit("confirm_delete_course", "Delete"),
	);
	
	print CGI::end_form();
}

sub do_delete_course {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $delete_courseID     = $r->param("delete_courseID")     || "";
	my $delete_sql_host     = $r->param("delete_sql_host")     || "";
	my $delete_sql_port     = $r->param("delete_sql_port")     || "";
	my $delete_sql_username = $r->param("delete_sql_username") || "";
	my $delete_sql_password = $r->param("delete_sql_password") || "";
	my $delete_sql_database = $r->param("delete_sql_database") || "";
	
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		$delete_courseID,
	);
	
	my %dbOptions;
	if ($ce2->{dbLayoutName} eq "sql") {
		$dbOptions{host}     = $delete_sql_host if $delete_sql_host ne "";
		$dbOptions{port}     = $delete_sql_port if $delete_sql_port ne "";
		$dbOptions{username} = $delete_sql_username;
		$dbOptions{password} = $delete_sql_password;
		$dbOptions{database} = $delete_sql_database || "webwork_$delete_courseID";
	}
	
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
		print CGI::div({class=>"ResultsWithoutError"},
			CGI::p("Successfully deleted the course $delete_courseID."),
		);
		 writeLog($ce, "hosted_courses", join("\t",
	    	"\tDeleted",
	    	"",
	    	"",
	    	$delete_courseID,
	    ));
		print CGI::start_form("POST", $r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		
		print CGI::p({style=>"text-align: center"}, CGI::submit("decline_delete_course", "OK"),);
		
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
	@courseIDs    = sort @courseIDs;
	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
		my $tempCE = WeBWorK::CourseEnvironment->new(
			$ce->{webworkDirs}->{root},
			$ce->{webworkURLs}->{root},
			$ce->{pg}->{directories}->{root},
			$courseID,
		);
		$courseLabels{$courseID} = "$courseID (" . $tempCE->{dbLayoutName} . ")";
	}
	
	print CGI::h2("Export Database");
	
	print CGI::start_form("GET", $r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::p("Select a course to export the course's database. Please note
	that exporting can take a very long time for a large course. If you have
	shell access to the WeBWorK server, you may use the ", CGI::code("wwdb"), "
	utility instead.");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Course Name:"),
			CGI::td(
				CGI::scrolling_list(
					-name => "export_courseID",
					-values => \@courseIDs,
					-default => $export_courseID,
					-size => 10,
					-multiple => 0,
					-labels => \%courseLabels,
				),
			),
		),
		CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Tables to Export:"),
			CGI::td(
				CGI::checkbox_group(
					-name => "export_tables",
					-values => \@tables,
					-default => \@export_tables,
					-linebreak => 1,
				),
			),
		),
	);
	
	print CGI::p({style=>"text-align: center"}, CGI::submit("export_database", "Export Database"));
	
	print CGI::end_form();
}

sub export_database_validate {
	my ($self) = @_;
	my $r = $self->r;
	#my $ce = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;
	
	my $export_courseID = $r->param("export_courseID") || "";
	my @export_tables   = $r->param("export_tables");
	
	my @errors;
	
	if ($export_courseID eq "") {
		push @errors, "You must specify a course name.";
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
	
	my $export_courseID = $r->param("export_courseID");
	my @export_tables   = $r->param("export_tables");
	
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		$export_courseID,
	);
	
	my $db2 = new WeBWorK::DB($ce2->{dbLayout});
	
	#my ($fh, $export_file) = tempfile("db_export_XXXXXX", DIR => $ce->{webworkDirs}->{tmp});
	#my ($random_chars) = $export_file =~ m/db_export_(\w+)$/;
	
	my @errors;
	
	eval {
		@errors = dbExport(
			db => $db2,
			#xml => $fh,
			xml => *STDOUT,
			tables => \@export_tables,
		);
	};
	
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
	@courseIDs    = sort @courseIDs;

	
	my %courseLabels; # records... heh.
	foreach my $courseID (@courseIDs) {
		my $tempCE = WeBWorK::CourseEnvironment->new(
			$ce->{webworkDirs}->{root},
			$ce->{webworkURLs}->{root},
			$ce->{pg}->{directories}->{root},
			$courseID,
		);
		$courseLabels{$courseID} = "$courseID (" . $tempCE->{dbLayoutName} . ")";
	}
	
	print CGI::h2("Import Database");
	
	print CGI::start_form("POST", $r->uri, &CGI::MULTIPART);
	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::th({class=>"LeftHeader"}, "Database XML File:"),
			CGI::td(
				CGI::filefield(
					-name => "import_file",
					-size => 50,
				),
			),
		),
		CGI::Tr(
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
		CGI::Tr(
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
		CGI::Tr(
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
	
	print CGI::p({style=>"text-align: center"}, CGI::submit("import_database", "Import Database"));
	
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
		push @errors, "You must specify a database file to upload.";
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
	
	my $ce2 = WeBWorK::CourseEnvironment->new(
		$ce->{webworkDirs}->{root},
		$ce->{webworkURLs}->{root},
		$ce->{pg}->{directories}->{root},
		$import_courseID,
	);
	
	my $db2 = new WeBWorK::DB($ce2->{dbLayout});
	
	# retrieve upload from upload cache
	my ($id, $hash) = split /\s+/, $import_file;
	my $upload = WeBWorK::Upload->retrieve($id, $hash,
		dir => $ce->{webworkDirs}->{uploadCache}
	);
	
	my @errors;
	
	eval {
		@errors = dbImport(
			db => $db2,
			xml => $upload->fileHandle,
			tables => \@import_tables,
			conflict => $import_conflict,
		);
	};
	
	$upload->dispose;
	
	push @errors, "Fatal exception: $@" if $@;
	
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

1;
