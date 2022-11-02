################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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
use WeBWorK::Utils qw(cryptPassword writeLog listFilesRecursive trim_spaces getAssetURL);
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
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $authz   = $r->authz;
	my $urlpath = $r->urlpath;
	my $user    = $r->param('user');

	# check permissions
	unless ($authz->hasPermissions($user, "create_and_delete_courses")) {
		$self->addbadmessage("$user is not authorized to create or delete courses");
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

		} elsif ($subDisplay eq "rename_course") {
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

			} elsif (defined $r->param("upgrade_course_tables")) {
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

		} elsif ($subDisplay eq "delete_course") {
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
			} elsif (defined($r->param("delete_course_refresh"))) {
				$method_to_call = "delete_course_form";
			} else {
				# form only
				$method_to_call = "delete_course_form";
			}

		} elsif ($subDisplay eq "export_database") {
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

		} elsif ($subDisplay eq "import_database") {
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

		} elsif ($subDisplay eq "archive_course") {
			if (defined $r->param("archive_course")
				|| defined $r->param("skip_archive_course"))
			{

				# validate -- if invalid, start over.
				# if form is valid a page indicating the status of
				# database tables and directories is presented.
				# If they are ok, then you can push archive button, otherwise
				# you can quit or choose to upgrade the tables
				@errors = $self->archive_course_validate;
				if (@errors) {
					$method_to_call = "archive_course_form";
				} else {
					$method_to_call = "archive_course_confirm";    #check tables & directories
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
			} elsif (defined $r->param("upgrade_course_tables")) {
				# upgrade and revalidate
				# the "upgrade course" button has been pushed
				# after the course has been upgraded you are returned
				# to the confirm page.
				@errors = $self->archive_course_validate;
				if (@errors) {
					$method_to_call = "archive_course_form";
				} else {
					$method_to_call = "archive_course_confirm";    # upgrade and recheck tables & directories.
				}
			} elsif (defined($r->param("archive_course_refresh"))) {
				$method_to_call = "archive_course_form";
			} else {
				# form only
				$method_to_call = "archive_course_form";
			}
		} elsif ($subDisplay eq "unarchive_course") {
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
		} elsif ($subDisplay eq "upgrade_course") {
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
		} elsif ($subDisplay eq "manage_locations") {
			if (defined($r->param("manage_location_action"))) {
				$method_to_call = $r->param("manage_location_action");
			} else {
				$method_to_call = "manage_location_form";
			}
		} elsif ($subDisplay eq "hide_inactive_course") {
			#			warn "subDisplay is $subDisplay";
			if (defined($r->param("hide_course"))) {
				@errors = $self->hide_course_validate;
				if (@errors) {
					$method_to_call = "hide_inactive_course_form";
				} else {
					$method_to_call = "do_hide_inactive_course";
				}
			} elsif (defined($r->param("unhide_course"))) {
				@errors = $self->unhide_course_validate;
				if (@errors) {
					$method_to_call = "hide_inactive_course_form";
				} else {
					$method_to_call = "do_unhide_inactive_course";
				}
			} elsif (defined($r->param("hide_course_refresh"))) {
				$method_to_call = "hide_inactive_course_form";
			} else {
				$method_to_call = "hide_inactive_course_form";
			}
		} elsif ($subDisplay eq "registration") {
			if (defined($r->param("register_site"))) {
				$method_to_call = "do_registration";
			} else {
				$method_to_call = "registration_form";
			}
		} else {
			@errors = "Unrecognized sub-display @{[ CGI::b($subDisplay) ]}.";
		}
	}

	$self->{errors}         = \@errors;
	$self->{method_to_call} = $method_to_call;
}

sub body {
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $authz   = $r->authz;
	my $urlpath = $r->urlpath;

	my $user = $r->param('user');

	# check permissions
	unless ($authz->hasPermissions($user, "create_and_delete_courses")) {
		return "";
	}
	my $method_to_call = $self->{method_to_call};
	my $methodMessage  = "";

	(defined($method_to_call) and $method_to_call eq "do_export_database") && do {
		my @export_courseID = $r->param("export_courseID");
		my $course_ids      = join(", ", @export_courseID);
		$methodMessage = CGI::p("Exporting database for course(s) $course_ids") . CGI::p(
			".... please wait....
		If your browser times out you will
		still be able to download the exported database using the
		file manager."
		) . CGI::hr();
	};

	print CGI::ul(
		{ class => 'nav nav-pills justify-content-center my-2' },
		map {
			CGI::li(
				{ class => 'nav-item' },
				CGI::a(
					{
						href =>
							$self->systemLink($urlpath, params => { subDisplay => $_->[0], %{ $_->[2] // {} } }),
						class => 'nav-link' . (($r->param('subDisplay') // '') eq $_->[0] ? ' active' : '')
					},
					$_->[1]
				)
			)
		} (
			[
				'add_course',
				$r->maketext('Add Course'),
				{
					add_admin_users      => 1,
					add_config_file      => 1,
					add_dbLayout         => 'sql_single',
					add_templates_course => $ce->{siteDefaults}->{default_templates_course} || ''
				}
			],
			[ 'rename_course',        $r->maketext('Rename Course') ],
			[ 'delete_course',        $r->maketext('Delete Course') ],
			[ 'archive_course',       $r->maketext('Archive Course') ],
			[ 'unarchive_course',     $r->maketext('Unarchive Course') ],
			[ 'upgrade_course',       $r->maketext('Upgrade Courses') ],
			[ 'manage_locations',     $r->maketext('Manage Locations') ],
			[ 'hide_inactive_course', $r->maketext('Hide Courses') ],
		)
	);

	print CGI::hr({ class => 'mt-0' });
	print $methodMessage;

	print $self->display_registration_form;

	my @errors = @{ $self->{errors} };

	if (@errors) {
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			CGI::div({ class => 'mb-1' }, $r->maketext("Please correct the following errors and try again:")),
			CGI::ul({ class => 'mb-1' }, CGI::li(\@errors)),
		);
	}

	if (defined $method_to_call and $method_to_call ne "") {
		$self->$method_to_call;
	} else {
		my $msg = "";
		$msg .= CGI::li($r->maketext("unable to write to directory [_1]", $ce->{webworkDirs}{logs}))
			unless -w $ce->{webworkDirs}{logs};
		$msg .= CGI::li($r->maketext("unable to write to directory [_1]", $ce->{webworkDirs}{tmp}))
			unless -w $ce->{webworkDirs}{tmp};
		$msg .= CGI::li($r->maketext("unable to write to directory [_1]", $ce->{webworkDirs}{DATA}))
			unless -w $ce->{webworkDirs}{DATA};
		if ($msg) {
			print CGI::h2($r->maketext("Directory permission errors "))
				. CGI::ul($msg)
				. CGI::p(
					$r->maketext(
					"The webwork server must be able to write to these directories. Please correct the permssion errors."
					)
				);
		}

		print $self->upgrade_notification();

		print CGI::h2($r->maketext("Courses"));

		print CGI::start_ol();

		my @courseIDs = listCourses($ce);
		foreach my $courseID (sort { lc($a) cmp lc($b) } @courseIDs) {
			next if $courseID eq "admin";    # done already above
			next
				if $courseID eq
				"modelCourse";               # modelCourse isn't a real course so don't create missing directories, etc
			my $urlpath =
				$r->urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => $courseID);
			print CGI::li(CGI::a({ href => $self->systemLink($urlpath, authen => 0) }, $courseID));
		}

		print CGI::end_ol();

		print CGI::h2($r->maketext("Archived Courses"));
		print CGI::start_ol();

		@courseIDs = listArchivedCourses($ce);
		foreach my $courseID (sort { lc($a) cmp lc($b) } @courseIDs) {
			print CGI::li($courseID),;
		}

		print CGI::end_ol();
	}
	return "";
}

################################################################################

sub add_course_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my @existingCourses = sort { lc($a) cmp lc($b) } listCourses($ce);    # make sort case insensitive
	unshift(@existingCourses, @{ $ce->{modelCoursesForCopy} });

	print CGI::h2($r->maketext('Add Course'));

	print CGI::start_form({ method => 'POST', action => $r->uri });
	print $self->hidden_authen_fields;
	print $self->hidden_fields('subDisplay');

	print CGI::p($r->maketext(
		'Specify an ID, title, and institution for the new course. The course ID may contain only letters, '
			. 'numbers, hyphens, and underscores, and may have at most [_1] characters.',
		$ce->{maxCourseIdLength}
	));

	print CGI::div(
		{ class => 'row mb-2' },
		CGI::div(
			{ class => 'col-lg-8 col-md-10' },
			CGI::div(
				{ class => 'form-floating mb-1' },
				CGI::textfield({
					name        => 'add_courseID',
					id          => 'add_courseID',
					value       => trim_spaces($r->param('add_courseID')) || '',
					placeholder => '',
					class       => 'form-control'
				}),
				CGI::label({ for => 'add_courseID' }, $r->maketext('Course ID'))
			),
			CGI::div(
				{ class => 'form-floating mb-1' },
				CGI::textfield({
					name        => 'add_courseTitle',
					id          => 'add_courseTitle',
					value       => trim_spaces($r->param('add_courseTitle')) || '',
					placeholder => '',
					class       => 'form-control'
				}),
				CGI::label({ for => 'add_courseTitle' }, $r->maketext('Course Title'))
			),
			CGI::div(
				{ class => 'form-floating mb-1' },
				CGI::textfield({
					name        => 'add_courseInstitution',
					id          => 'add_courseInstitution',
					value       => trim_spaces($r->param('add_courseInstitution')) || '',
					placeholder => '',
					class       => 'form-control'
				}),
				CGI::label({ for => 'add_courseInstitution' }, $r->maketext('Institution'))
			)
		)
	);

	print CGI::div(
		{ class => 'mb-3' },
		CGI::div(
			{ class => 'mb-1' },
			$r->maketext(
				'To add the WeBWorK administrators to the new course (as administrators) check the box below.')
		),
		CGI::div(
			{ class => 'form-check mb-2' },
			CGI::checkbox({
				name            => 'add_admin_users',
				label           => $r->maketext('Add WeBWorK administrators to new course'),
				checked         => trim_spaces($r->param('add_admin_users')) || 0,
				class           => 'form-check-input',
				labelattributes => { class => 'form-check-label' }
			})
		),
		CGI::div(
			{ class => 'form-check' },
			CGI::checkbox({
				name            => 'add_config_file',
				label           => $r->maketext('Copy simple configuration file to new course'),
				checked         => trim_spaces($r->param('add_config_file')) || 0,
				class           => 'form-check-input',
				labelattributes => { class => 'form-check-label' }
			})
		)
	);

	print CGI::div(
		{ class => 'mb-2' },
		$r->maketext(
			'To add an additional instructor to the new course, specify user information below. '
				. 'The user ID may contain only numbers, letters, hyphens, periods (dots), commas,and underscores.'
		)
	);

	print CGI::div(
		{ class => 'row mb-2' },
		CGI::div(
			{ class => 'col-lg-4 col-md-5 col-sm-6' },
			CGI::div(
				{ class => 'form-floating mb-1' },
				CGI::textfield({
					name        => 'add_initial_userID',
					id          => 'add_initial_userID',
					value       => trim_spaces($r->param('add_initial_userID')) || '',
					placeholder => '',
					class       => 'form-control'
				}),
				CGI::label({ for => 'add_initial_userID' }, $r->maketext('User ID'))
			),
			CGI::div(
				{ class => 'form-floating mb-1' },
				CGI::password_field({
					name        => 'add_initial_password',
					id          => 'add_initial_password',
					value       => trim_spaces($r->param('add_initial_password')) || '',
					placeholder => '',
					class       => 'form-control'
				}),
				CGI::label({ for => 'add_initial_password' }, $r->maketext('Password'))
			),
			CGI::div(
				{ class => 'form-floating mb-1' },
				CGI::password_field({
					name        => 'add_initial_confirmPassword',
					id          => 'add_initial_confirmPassword',
					value       => trim_spaces($r->param('add_initial_confirmPassword')) || '',
					placeholder => '',
					class       => 'form-control'
				}),
				CGI::label({ for => 'add_initial_confirmPassword' }, $r->maketext('Confirm Password'))
			)
		),
		CGI::div(
			{ class => 'col-lg-4 col-md-5 col-sm-6' },
			CGI::div(
				{ class => 'form-floating mb-1' },
				CGI::textfield({
					name        => 'add_initial_firstName',
					id          => 'add_initial_firstName',
					value       => trim_spaces($r->param('add_initial_firstName')) || '',
					placeholder => '',
					class       => 'form-control'
				}),
				CGI::label({ for => 'add_initial_firstName' }, $r->maketext('First Name'))
			),
			CGI::div(
				{ class => 'form-floating mb-1' },
				CGI::textfield({
					name        => 'add_initial_lastName',
					id          => 'add_initial_lastName',
					value       => trim_spaces($r->param('add_initial_lastName')) || '',
					placeholder => '',
					class       => 'form-control'
				}),
				CGI::label({ for => 'add_initial_lastName' }, $r->maketext('Last Name'))
			),
			CGI::div(
				{ class => 'form-floating mb-1' },
				CGI::textfield({
					name        => 'add_initial_email',
					id          => 'add_initial_email',
					value       => trim_spaces($r->param('add_initial_email')) || '',
					placeholder => '',
					class       => 'form-control'
				}),
				CGI::label({ for => 'add_initial_email' }, $r->maketext('Email Address'))
			)
		)
	);

	print CGI::div({ class => 'mb-1' },
		$r->maketext('To copy problem templates from an existing course, select the course below.'));

	print CGI::div(
		{ class => 'row mb-3' },
		CGI::label(
			{ for => 'add_templates_course', class => 'col-auto col-form-label fw-bold' },
			$r->maketext('Copy templates from:')
		),
		CGI::div(
			{ class => 'col-auto' },
			CGI::popup_menu({
				name    => 'add_templates_course',
				id      => 'add_templates_course',
				values  => [ '', @existingCourses ],
				labels  => { '' => $r->maketext('No Course'), map { $_ => $_ } @existingCourses },
				default => trim_spaces($r->param('add_templates_course')) || '',
				class   => 'form-select'
			})
		)
	);

	print CGI::input({ type => 'hidden', name => 'add_dbLayout', value => 'sql_single' });

	print CGI::submit({ name => 'add_course', label => $r->maketext('Add Course'), class => 'btn btn-primary' });

	print CGI::end_form();
}

sub add_course_validate {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;

	my $add_courseID          = trim_spaces($r->param("add_courseID"))          || "";
	my $add_courseTitle       = trim_spaces($r->param("add_courseTitle"))       || "";
	my $add_courseInstitution = trim_spaces($r->param("add_courseInstitution")) || "";

	my $add_admin_users = trim_spaces($r->param("add_admin_users")) || "";

	my $add_initial_userID          = trim_spaces($r->param("add_initial_userID"))          || "";
	my $add_initial_password        = trim_spaces($r->param("add_initial_password"))        || "";
	my $add_initial_confirmPassword = trim_spaces($r->param("add_initial_confirmPassword")) || "";
	my $add_initial_firstName       = trim_spaces($r->param("add_initial_firstName"))       || "";
	my $add_initial_lastName        = trim_spaces($r->param("add_initial_lastName"))        || "";
	my $add_initial_email           = trim_spaces($r->param("add_initial_email"))           || "";
	my $add_templates_course        = trim_spaces($r->param("add_templates_course"))        || "";
	my $add_config_file             = trim_spaces($r->param("add_config_file"))             || "";
	my $add_dbLayout                = trim_spaces($r->param("add_dbLayout"))                || "";

	######################

	my @errors;

	if ($add_courseID eq "") {
		push @errors, $r->maketext("You must specify a course ID.");
	}
	unless ($add_courseID =~ /^[\w-]*$/) {    # regex copied from CourseAdministration.pm
		push @errors, $r->maketext("Course ID may only contain letters, numbers, hyphens, and underscores.");
	}
	if (grep { $add_courseID eq $_ } listCourses($ce)) {
		push @errors, $r->maketext("A course with ID [_1] already exists.", $add_courseID);
	}
	if (length($add_courseID) > $ce->{maxCourseIdLength}) {
		push @errors, $r->maketext("Course ID cannot exceed [_1] characters.", $ce->{maxCourseIdLength});
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
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $authz   = $r->authz;
	my $urlpath = $r->urlpath;

	my $add_courseID          = trim_spaces($r->param("add_courseID"))          || "";
	my $add_courseTitle       = trim_spaces($r->param("add_courseTitle"))       || "";
	my $add_courseInstitution = trim_spaces($r->param("add_courseInstitution")) || "";

	my $add_admin_users = trim_spaces($r->param("add_admin_users")) || "";

	my $add_initial_userID          = trim_spaces($r->param("add_initial_userID"))          || "";
	my $add_initial_password        = trim_spaces($r->param("add_initial_password"))        || "";
	my $add_initial_confirmPassword = trim_spaces($r->param("add_initial_confirmPassword")) || "";
	my $add_initial_firstName       = trim_spaces($r->param("add_initial_firstName"))       || "";
	my $add_initial_lastName        = trim_spaces($r->param("add_initial_lastName"))        || "";
	my $add_initial_email           = trim_spaces($r->param("add_initial_email"))           || "";

	my $add_templates_course = trim_spaces($r->param("add_templates_course")) || "";
	my $add_config_file      = trim_spaces($r->param("add_config_file"))      || "";

	my $add_dbLayout = trim_spaces($r->param("add_dbLayout")) || "";

	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE, courseName => $add_courseID,
	});

	my %courseOptions = (dbLayoutName => $add_dbLayout);

	if ($add_initial_email ne "") {
		$courseOptions{allowedRecipients} = [$add_initial_email];
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
				$self->addbadmessage($r->maketext(
					"User '[_1]' will not be copied from admin course as it is the initial instructor.", $userID
				));
				next;
			}
			my $PermissionLevel = $db->newPermissionLevel();
			$PermissionLevel->user_id($userID);
			$PermissionLevel->permission($ce->{userRoles}->{admin});
			my $User     = $db->getUser($userID);
			my $Password = $db->getPassword($userID);

			push @users, [ $User, $Password, $PermissionLevel ]
				if $authz->hasPermissions($userID, "create_and_delete_courses");
			#only transfer the "instructors" in the admin course classlist.
		}
	}

	# add initial instructor if desired
	if ($add_initial_userID =~ /\S/) {
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

	push @{ $courseOptions{PRINT_FILE_NAMES_FOR} }, map { $_->[0]->user_id } @users;

	# include any optional arguments, including a template course and the
	# course title and course institution.
	my %optional_arguments;
	if ($add_templates_course ne "") {
		$optional_arguments{templatesFrom} = $add_templates_course;
	}
	if ($add_config_file ne "") {
		$optional_arguments{copySimpleConfig} = $add_config_file;
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
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			CGI::p("An error occured while creating the course $add_courseID:"),
			CGI::div({ class => 'font-monospace' }, CGI::escapeHTML($error)),
		);
		# get rid of any partially built courses
		# FIXME  -- this is too fragile
		unless ($error =~ /course exists/) {
			eval { deleteCourse(courseID => $add_courseID, ce => $ce2, dbOptions => \%dbOptions,); }
		}
	} else {
		#log the action
		writeLog(
			$ce,
			"hosted_courses",
			join("\t",
				"\tAdded",
				(defined $add_courseInstitution ? $add_courseInstitution : "(no institution specified)"),
				(defined $add_courseTitle       ? $add_courseTitle       : "(no title specified)"),
				$add_courseID,
				$add_initial_firstName,
				$add_initial_lastName,
				$add_initial_email,
			)
		);
		# add contact to admin course as student?
		# FIXME -- should we do this?
		if ($add_initial_userID =~ /\S/) {
			my $composite_id = "${add_initial_userID}_${add_courseID}";    # student id includes school name and contact
			my $User         = $db->newUser(
				user_id       => $composite_id,                            # student id includes school name and contact
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
			if (my $oldUser = $db->getUser($composite_id)) {
				warn "Replacing old data for $composite_id  status: " . $oldUser->status;
				$db->deleteUser($composite_id);
			}
			eval { $db->addUser($User) };
			warn $@ if $@;
			eval { $db->addPassword($Password) };
			warn $@ if $@;
			eval { $db->addPermissionLevel($PermissionLevel) };
			warn $@ if $@;
		}
		print CGI::div(
			{ class => 'alert alert-success p-1 mb-2' },
			$r->maketext("Successfully created the course [_1]", $add_courseID),
		);
		my $newCoursePath =
			$urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => $add_courseID);
		my $newCourseURL = $self->systemLink($newCoursePath, authen => 0);
		print CGI::div(
			{ class => 'text-center mb-2' },
			CGI::a({ href => $newCourseURL }, $r->maketext("Log into [_1]", $add_courseID)),
		);
	}

}

################################################################################

sub rename_course_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	print CGI::h2($r->maketext('Rename Course'));

	my @courseIDs = sort { lc($a) cmp lc($b) } listCourses($ce);

	unless (@courseIDs) {
		print CGI::p($r->maketext('No courses found'));
		return;
	}

	my %courseLabels;
	for my $courseID (@courseIDs) {
		$courseLabels{$courseID} = $courseID;
	}

	print CGI::start_form(-method => 'POST', -action => $r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields('subDisplay');

	print CGI::p($r->maketext(
		'Select a course to rename.  The courseID is used in the url and can only contain alphanumeric characters '
			. 'and underscores. The course title appears on the course home page and can be any string.'
	));

	print CGI::div(
		{ class => 'col-lg-7 col-md-8' },
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'rename_oldCourseID', class => 'col-sm-6 col-form-label fw-bold' },
				$r->maketext('Course ID:')
			),
			CGI::div(
				{ class => 'col-sm-6' },
				CGI::scrolling_list({
					name     => 'rename_oldCourseID',
					id       => 'rename_oldCourseID',
					values   => \@courseIDs,
					default  => $r->param('rename_oldCourseID') || '',
					size     => 10,
					multiple => 0,
					labels   => \%courseLabels,
					class    => 'form-select',
				})
			)
		),
		CGI::div(
			{ class => 'row mb-2 align-items-center' },
			CGI::div(
				{ class => 'col-sm-6' },
				CGI::div(
					{ class => 'form-check' },
					CGI::checkbox({
						name            => 'rename_newCourseID_checkbox',
						label           => $r->maketext('Change CourseID to:'),
						checked         => $r->param('rename_newCourseID_checkbox') || '',
						value           => 'on',
						class           => 'form-check-input',
						labelattributes => { class => 'form-check-label', id => 'rename_newCourseID_label' }
					})
				)
			),
			CGI::div(
				{ class => 'col-sm-6' },
				CGI::textfield({
					name            => 'rename_newCourseID',
					value           => $r->param('rename_newCourseID') || '',
					class           => 'form-control',
					aria_labelledby => 'rename_newCourseID_label'
				}),
			)
		),
		CGI::div(
			{ class => 'row mb-2 align-items-center' },
			CGI::div(
				{ class => 'col-sm-6' },
				CGI::div(
					{ class => 'form-check' },
					CGI::checkbox({
						name            => 'rename_newCourseTitle_checkbox',
						label           => $r->maketext('Change Course Title to:'),
						selected        => $r->param('rename_newCourseTitle_checkbox') || '',
						value           => 'on',
						class           => 'form-check-input',
						labelattributes => { class => 'form-check-label', id => 'rename_newCourseTitle_label' }
					})
				)
			),
			CGI::div(
				{ class => 'col-sm-6' },
				CGI::textfield({
					name            => 'rename_newCourseTitle',
					value           => $r->param('rename_newCourseTitle') || '',
					class           => 'form-control',
					aria_labelledby => 'rename_newCourseTitle_label'
				})
			),
		),
		CGI::div(
			{ class => 'row mb-2 align-items-center' },
			CGI::div(
				{ class => 'col-sm-6' },
				CGI::div(
					{ class => 'form-check' },
					CGI::checkbox({
						name            => 'rename_newCourseInstitution_checkbox',
						label           => $r->maketext('Change Institution to:'),
						checked         => $r->param('rename_newCourseInstitution_checkbox') || '',
						value           => 'on',
						class           => 'form-check-input',
						labelattributes =>
							{ class => 'form-check-label', id => 'rename_newCourseInstitution_label' }
					})
				)
			),
			CGI::div(
				{ class => 'col-sm-6' },
				CGI::textfield({
					name            => 'rename_newCourseInstitution',
					value           => $r->param('rename_newCourseInstitution') || '',
					class           => 'form-control',
					aria_labelledby => 'rename_newCourseInstitution_label'
				})
			)
		)
	);

	print CGI::submit({ name => 'rename_course', label => $r->maketext('Rename Course'), class => 'btn btn-primary' });

	print CGI::end_form();
}

sub rename_course_confirm {

	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my $rename_oldCourseID          = $r->param("rename_oldCourseID")          || "";
	my $rename_newCourseID          = $r->param("rename_newCourseID")          || "";
	my $rename_newCourseID_checkbox = $r->param("rename_newCourseID_checkbox") || "";

	my $rename_newCourseTitle                = $r->param("rename_newCourseTitle")                || "";
	my $rename_newCourseTitle_checkbox       = $r->param("rename_newCourseTitle_checkbox")       || "";
	my $rename_newCourseInstitution          = $r->param("rename_newCourseInstitution")          || "";
	my $rename_newCourseInstitution_checkbox = $r->param("rename_newCourseInstitution_checkbox") || "";

	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE, courseName => $rename_oldCourseID,
	});
######################################################
## Create strings confirming title and institution change
######################################################
	# connect to database to get old title and institution
	my $dbLayoutName                = $ce->{dbLayoutName};
	my $db                          = new WeBWorK::DB($ce->{dbLayouts}->{$dbLayoutName});
	my $oldDB                       = new WeBWorK::DB($ce2->{dbLayouts}->{$dbLayoutName});
	my $rename_oldCourseTitle       = $oldDB->getSettingValue('courseTitle')       // '""';
	my $rename_oldCourseInstitution = $oldDB->getSettingValue('courseInstitution') // '""';

	my ($change_course_title_str, $change_course_institution_str) = ("");
	if ($rename_newCourseTitle_checkbox) {
		$change_course_title_str =
			$r->maketext("Change title from [_1] to [_2]", $rename_oldCourseTitle, $rename_newCourseTitle);
	}
	if ($rename_newCourseInstitution_checkbox) {
		$change_course_institution_str = $r->maketext("Change course institution from [_1] to [_2]",
			$rename_oldCourseInstitution, $rename_newCourseInstitution);
	}

#############################################################################
	# If we are only changing the title or institution we can cut this short
#############################################################################
	unless ($rename_newCourseID_checkbox) {    # in this case do not change course ID
		print CGI::start_form(-method => "POST", -action => $r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		print $self->hidden_fields(
			qw/rename_oldCourseID rename_newCourseID
				rename_newCourseTitle rename_newCourseInstitution
				rename_newCourseID_checkbox rename_newCourseInstitution_checkbox
				rename_newCourseTitle_checkbox /
		);
		print CGI::hidden(
			-name    => "rename_oldCourseTitle",
			-default => $rename_oldCourseTitle,
			-id      => "hidden_rename_oldCourseTitle"
		);
		print CGI::hidden(
			-name    => "rename_oldCourseInstitution",
			-default => $rename_oldCourseInstitution,
			-id      => "hidden_rename_oldCourseInstitution"
		);

		print CGI::div(
			{ style => "text-align: left" },
			CGI::hr(),
			CGI::h4($r->maketext("Make these changes in  course:") . " $rename_oldCourseID"),
			CGI::p($change_course_title_str),
			CGI::p($change_course_institution_str),
			CGI::submit({
				name  => "decline_retitle_course",
				value => $r->maketext("Don't make changes"),
				class => 'btn btn-primary'
			}),
			"&nbsp;",
			CGI::submit({
				name  => "confirm_retitle_course",
				value => $r->maketext("Make changes"),
				class => 'btn btn-primary'
			}),
			CGI::hr(),
		);
		print CGI::end_form();
		return;
	}

#############################################################################
	# Check database
#############################################################################

	my ($tables_ok, $dbStatus);
	if ($ce2->{dbLayoutName}) {
		my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce => $ce2);
		($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($rename_oldCourseID);
		if ($r->param("upgrade_course_tables")) {
			my @schema_table_names = keys %$dbStatus;    # update tables missing from database;
			my @tables_to_create =
				grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A } @schema_table_names;
			my @tables_to_alter =
				grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B }
				@schema_table_names;
			my $msg = $CIchecker->updateCourseTables($rename_oldCourseID, [@tables_to_create]);
			foreach my $table_name (@tables_to_alter) {
				$msg .= $CIchecker->updateTableFields($rename_oldCourseID, $table_name);
			}
			print CGI::p({ class => 'text-success fw-bold' }, $msg);

		}
		($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($rename_oldCourseID);

		# print db status

		my %msg = (
			WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A =>
				CGI::span({ class => 'text-danger' }, $r->maketext("Table defined in schema but missing in database")),
			WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B =>
				CGI::span({ class => 'text-danger' }, $r->maketext("Table defined in database but missing in schema")),
			WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B =>
				CGI::span({ class => 'text-success' }, $r->maketext("Table is ok")),
			WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => CGI::span(
				{ class => 'text-danger' },
				$r->maketext("Schema and database table definitions do not agree")
			),
		);
		my %msg2 = (
			WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A =>
				CGI::span({ class => 'text-danger' }, $r->maketext("Field missing in database")),
			WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B =>
				CGI::span({ class => 'text-danger' }, $r->maketext("Field missing in schema")),
			WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B =>
				CGI::span({ class => 'text-success' }, $r->maketext("Field is ok")),
			WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => CGI::span(
				{ class => 'text-danger' },
				$r->maketext("Schema and database field definitions do not agree")
			),
		);
		my $all_tables_ok         = 1;
		my $extra_database_tables = 0;
		my $extra_database_fields = 0;
		my $str =
			CGI::h4($r->maketext("Report on database structure for course [_1]:", $rename_oldCourseID)) . CGI::br();
		foreach my $table (sort keys %$dbStatus) {
			my $table_status = $dbStatus->{$table}->[0];
			$str .= CGI::b($table) . ': ' . $msg{$table_status} . CGI::br();

		CASE: {
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B
					&& do {
						last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A
					&& do {
						$all_tables_ok = 0;
						last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B
					&& do {
						$extra_database_tables = 1;
						last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B
					&& do {
						my %fieldInfo = %{ $dbStatus->{$table}->[1] };
						foreach my $key (keys %fieldInfo) {
							my $field_status = $fieldInfo{$key}->[0];
						CASE2: {
								$field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B
								&& do {
									$extra_database_fields = 1;
									last CASE2;
								};
								$field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A
								&& do {
									$all_tables_ok = 0;
									last CASE2;
								};
							}
							$str .= CGI::br() . "\n&nbsp;&nbsp; $key => " . $msg2{$field_status};
						}
					};
			}
			$str .= CGI::br();

		}
#############################################################################
		# Report on databases
#############################################################################

		print CGI::p($str);
		if ($extra_database_tables) {
			print CGI::p(
				{ class => 'text-danger fw-bold' },
				$r->maketext(
					'There are extra database tables which are not defined in the schema.  '
						. 'These can be deleted when upgrading the course.'
				)
			);
		}
		if ($extra_database_fields) {
			print CGI::p(
				{ class => 'text-danger fw-bold' },
				$r->maketext(
					'There are extra database fields which are not defined in the schema for at least one table.  '
						. 'They can only be removed when upgrading the course.'
				)
			);
		}
		if ($all_tables_ok) {
			print CGI::p({ class => 'text-success fw-bold' },
				$r->maketext("Course [_1] database is in order", $rename_oldCourseID));
		} else {
			print CGI::p(
				{ class => 'text-danger fw-bold' },
				$r->maketext(
					"Course [_1] databases must be updated before renaming this course.",
					$rename_oldCourseID
				)
			);
		}

#############################################################################
		# Check directories
#############################################################################

		my ($directories_ok, $str2) = $CIchecker->checkCourseDirectories($ce2);
		print CGI::h2('Directory structure'), CGI::p($str2),
			$directories_ok ? CGI::p({ class => 'text-success' }, $r->maketext('Directory structure is ok')) : CGI::p(
				{ class => 'text-danger' },
				$r->maketext(
					'Directory structure is missing directories or the webserver lacks sufficient privileges.')
			);

#############################################################################
		# Print form for choosing next action.
#############################################################################

		print CGI::start_form(-method => "POST", -action => $r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		print $self->hidden_fields(
			qw/rename_oldCourseID rename_newCourseID
				rename_newCourseTitle rename_newCourseInstitution
				rename_newCourseID_checkbox rename_newCourseInstitution_checkbox
				rename_newCourseTitle_checkbox /
		);
		print CGI::hidden(
			-name    => "rename_oldCourseTitle",
			-default => $rename_oldCourseTitle,
			-id      => "hidden_rename_oldCourseTitle"
		);
		print CGI::hidden(
			-name    => "rename_oldCourseInstitution",
			-default => $rename_oldCourseInstitution,
			-id      => "hidden_rename_oldCourseInstitution"
		);

		# grab some values we'll need
		# fail if the source course does not exist

		if ($all_tables_ok && $directories_ok) {    # no missing tables or missing fields or directories
			print CGI::p(
				{ style => "text-align: center" },
				CGI::hr(),
				CGI::h4($r->maketext("Rename [_1] to [_2]", $rename_oldCourseID, $rename_newCourseID)),
				CGI::div($change_course_title_str),
				CGI::div($change_course_institution_str),
				CGI::submit({
					name  => "decline_rename_course",
					value => $r->maketext("Don't rename"),
					class => 'btn btn-primary'
				}),
				"&nbsp;",
				CGI::submit({
					name  => "confirm_rename_course",
					value => $r->maketext("Rename"),
					class => 'btn btn-primary'
				}),
			);
		} elsif ($directories_ok) {
			print CGI::p(
				{ style => "text-align: center" },
				CGI::submit({
					name   => "decline_rename_course",
					-value => $r->maketext("Don't rename"),
					class  => 'btn btn-primary'
				}),
				"&nbsp;",
				CGI::submit({
					name  => "upgrade_course_tables",
					value => $r->maketext("Upgrade Course Tables"),
					class => 'btn btn-primary'
				}),
			);
		} else {
			print CGI::p(
				{ style => "text-align: center" },
				CGI::submit({
					name   => "decline_rename_course",
					-value => $r->maketext("Don't rename"),
					class  => 'btn btn-primary'
				}),
				CGI::br(),
				$r->maketext("Directory structure needs to be repaired manually before renaming.")
			);
		}
		print CGI::end_form();
	}
}

sub rename_course_validate {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my $rename_oldCourseID          = $r->param("rename_oldCourseID")          || "";
	my $rename_newCourseID          = $r->param("rename_newCourseID")          || "";
	my $rename_newCourseID_checkbox = $r->param("rename_newCourseID_checkbox") || "";

	my $rename_newCourseTitle                = $r->param("rename_newCourseTitle")                || "";
	my $rename_newCourseTitle_checkbox       = $r->param("rename_newCourseTitle_checkbox")       || "";
	my $rename_newCourseInstitution          = $r->param("rename_newCourseInstitution")          || "";
	my $rename_newCourseInstitution_checkbox = $r->param("rename_newCourseInstitution_checkbox") || "";

	my @errors;

	if ($rename_oldCourseID eq "") {
		push @errors, $r->maketext("You must select a course to rename.");
	}
	if ($rename_newCourseID eq "" and $rename_newCourseID_checkbox eq 'on') {
		push @errors, $r->maketext("You must specify a new name for the course.");
	}
	if ($rename_oldCourseID eq $rename_newCourseID and $rename_newCourseID_checkbox eq 'on') {
		push @errors, $r->maketext("Can't rename to the same name.");
	}
	if ($rename_newCourseID_checkbox eq 'on' && length($rename_newCourseID) > $ce->{maxCourseIdLength}) {
		push @errors, $r->maketext("Course ID cannot exceed [_1] characters.", $ce->{maxCourseIdLength});
	}
	unless ($rename_newCourseID =~ /^[\w-]*$/) {    # regex copied from CourseAdministration.pm
		push @errors, $r->maketext("Course ID may only contain letters, numbers, hyphens, and underscores.");
	}
	if (grep { $rename_newCourseID eq $_ } listCourses($ce)) {
		push @errors, $r->maketext("A course with ID [_1] already exists.", $rename_newCourseID);
	}
	if ($rename_newCourseTitle eq "" and $rename_newCourseTitle_checkbox eq 'on') {
		push @errors, $r->maketext("You must specify a new title for the course.");
	}
	if ($rename_newCourseInstitution eq "" and $rename_newCourseInstitution_checkbox eq 'on') {
		push @errors, $r->maketext("You must specify a new institution for the course.");
	}
	unless ($rename_newCourseID
		or $rename_newCourseID_checkbox
		or $rename_newCourseTitle_checkbox
		or $rename_newCourseInstitution_checkbox)
	{
		push @errors,
			$r->maketext(
			"No changes specified.  You must mark the checkbox of the item(s) to be changed and enter the change data."
			);
	}

	return @errors;
}

sub do_retitle_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	my $rename_oldCourseID = $r->param("rename_oldCourseID") || "";
	#	my $rename_newCourseID           = $r->param("rename_newCourseID")     || "";
	#   There is no new course, but there are new titles and institutions
	my $rename_newCourseTitle       = $r->param("rename_newCourseTitle")                || "";
	my $rename_newCourseInstitution = $r->param("rename_newCourseInstitution")          || "";
	my $rename_oldCourseTitle       = $r->param("rename_oldCourseTitle")                || "";
	my $rename_oldCourseInstitution = $r->param("rename_oldCourseInstitution")          || "";
	my $title_checkbox              = $r->param("rename_newCourseTitle_checkbox")       || "";
	my $institution_checkbox        = $r->param("rename_newCourseInstitution_checkbox") || "";

	#	$rename_newCourseID = $rename_oldCourseID ;  #since they are the same FIXME
	# define new courseTitle and new courseInstitution
	my %optional_arguments = ();
	$optional_arguments{courseTitle}       = $rename_newCourseTitle       if $title_checkbox;
	$optional_arguments{courseInstitution} = $rename_newCourseInstitution if $institution_checkbox;

	my $ce2;
	my %dbOptions = ();
	eval { $ce2 = new WeBWorK::CourseEnvironment({ %WeBWorK::SeedCE, courseName => $rename_oldCourseID, }); };
	warn "failed to create environment in do_retitle_course $@" if $@;

	eval { retitleCourse(courseID => $rename_oldCourseID, ce => $ce2, dbOptions => \%dbOptions,
			%optional_arguments,); };
	if ($@) {
		my $error = $@;
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			CGI::p($r->maketext(
				"An error occured while changing the title of the course [_1].", $rename_oldCourseID)),
			CGI::div({ class => 'font-monospace' }, CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div(
			{ class => 'alert alert-success p-1 mb-2' },
			($title_checkbox) ? CGI::div($r->maketext(
				"The title of the course [_1] has been changed from [_2] to [_3]",
				$rename_oldCourseID, $rename_oldCourseTitle, $rename_newCourseTitle
			)) : '',
			($institution_checkbox) ? CGI::div($r->maketext(
				"The institution associated with the course [_1] has been changed from [_2] to [_3]",
				$rename_oldCourseID, $rename_oldCourseInstitution, $rename_newCourseInstitution
			)) : '',
		);
		writeLog(
			$ce,
			"hosted_courses",
			join(
				"\t", "\t",
				$r->maketext("Retitled"),
				"", "",
				$r->maketext(
					"[_1] title and institution changed from [_2] to [_3] and from [_4] to [_5]",
					$rename_oldCourseID,          $rename_oldCourseTitle, $rename_newCourseTitle,
					$rename_oldCourseInstitution, $rename_newCourseInstitution
				)
			)
		);
		my $oldCoursePath =
			$urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => $rename_oldCourseID);
		my $oldCourseURL = $self->systemLink($oldCoursePath, authen => 0);
		print CGI::div(
			{ style => "text-align: center" },
			CGI::a({ href => $oldCourseURL }, $r->maketext("Log into [_1]", $rename_oldCourseID)),
		);
	}
}

sub do_rename_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	my $rename_oldCourseID          = $r->param("rename_oldCourseID")                   || "";
	my $rename_newCourseID          = $r->param("rename_newCourseID")                   || "";
	my $rename_newCourseTitle       = $r->param("rename_newCourseTitle")                || "";
	my $rename_newCourseInstitution = $r->param("rename_newCourseInstitution")          || "";
	my $title_checkbox              = $r->param("rename_newCourseTitle_checkbox")       || "";
	my $institution_checkbox        = $r->param("rename_newCourseInstitution_checkbox") || "";

	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE, courseName => $rename_oldCourseID,
	});

	my $dbLayoutName = $ce->{dbLayoutName};

	# define new courseTitle and new courseInstitution
	my %optional_arguments = ();
	my ($title_message, $institution_message);
	if ($title_checkbox) {
		$optional_arguments{courseTitle} = $rename_newCourseTitle;
		$title_message =
			$r->maketext("The title of the course [_1] is now [_2]", $rename_newCourseID, $rename_newCourseTitle),;

	} else {

	}
	if ($institution_checkbox) {
		$optional_arguments{courseInstitution} = $rename_newCourseInstitution;
		$institution_message = $r->maketext("The institution associated with the course [_1] is now [_2]",
			$rename_newCourseID, $rename_newCourseInstitution),
			;

	}

	# this is kinda left over from when we had 'gdbm' and 'sql' database layouts
	# below this line, we would grab values from getopt and put them in this hash
	# but for now the hash can remain empty
	my %dbOptions;

	eval {
		renameCourse(
			courseID    => $rename_oldCourseID,
			ce          => $ce2,
			dbOptions   => \%dbOptions,
			newCourseID => $rename_newCourseID,
			%optional_arguments,
		);
	};
	if ($@) {
		my $error = $@;
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			CGI::p($r->maketext(
				"An error occured while renaming the course [_1] to [_2]:", $rename_oldCourseID,
				$rename_newCourseID
			)),
			CGI::div({ class => 'font-monospace' }, CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div(
			{ class => 'alert alert-success p-1 mb-2' },
			CGI::p($title_message),
			CGI::p($institution_message),
			CGI::p($r->maketext(
				"Successfully renamed the course [_1] to [_2]",
				$rename_oldCourseID, $rename_newCourseID
			)),
		);
		writeLog($ce, "hosted_courses", join("\t", "\tRenamed", "", "", "$rename_oldCourseID to $rename_newCourseID",));
		my $newCoursePath =
			$urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => $rename_newCourseID);
		my $newCourseURL = $self->systemLink($newCoursePath, authen => 0);
		print CGI::div(
			{ style => "text-align: center" },
			CGI::a({ href => $newCourseURL }, $r->maketext("Log into [_1]", $rename_newCourseID)),
		);
	}
}

################################################################################

my %coursesData;
sub byLoginActivity { $coursesData{$a}{'epoch_modify_time'} <=> $coursesData{$b}{'epoch_modify_time'} }

sub delete_course_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	print CGI::h2($r->maketext('Delete Course'));

	my @courseIDs = listCourses($ce);

	unless (@courseIDs) {
		print CGI::p($r->maketext('No courses found'));
		return;
	}

	my $coursesDir            = $ce->{webworkDirs}{courses};
	my $delete_listing_format = $r->param('delete_listing_format');
	unless (defined $delete_listing_format) { $delete_listing_format = 'alphabetically'; }    #use the default

	# Get and store last modify time for login.log for all courses. Also get visibility status.
	my %courseLabels;
	my @noLoginLogIDs = ();
	my @loginLogIDs   = ();

	my ($loginLogFile, $epoch_modify_time, $courseDir);
	for my $courseID (@courseIDs) {
		$loginLogFile = "$coursesDir/$courseID/logs/login.log";
		if (-e $loginLogFile) {
			# The login log file should always exist except for the model course.
			$epoch_modify_time                           = stat($loginLogFile)->mtime;
			$coursesData{$courseID}{'epoch_modify_time'} = $epoch_modify_time;
			$coursesData{$courseID}{'local_modify_time'} = ctime($epoch_modify_time);
			push(@loginLogIDs, $courseID);
		} else {
			# This is for the model course.
			$coursesData{$courseID}{'local_modify_time'} = 'no login.log';
			push(@noLoginLogIDs, $courseID);
		}
		if (-f "$coursesDir/$courseID/hide_directory") {
			$coursesData{$courseID}{'status'} = $r->maketext('hidden');
		} else {
			$coursesData{$courseID}{'status'} = $r->maketext('visible');
		}
		$courseLabels{$courseID} =
			"$courseID  ($coursesData{$courseID}{'status'} :: $coursesData{$courseID}{'local_modify_time'}) ";
	}
	if ($delete_listing_format eq 'last_login') {
		# This should be an empty array except for the model course.
		@noLoginLogIDs = sort { lc($a) cmp lc($b) } @noLoginLogIDs;
		@loginLogIDs   = sort byLoginActivity @loginLogIDs;           # oldest first
		@courseIDs     = (@noLoginLogIDs, @loginLogIDs);
	} else {
		# In this case we sort alphabetically
		@courseIDs = sort { lc($a) cmp lc($b) } @courseIDs;
	}

	print CGI::start_form(-method => 'POST', -action => $r->uri);

	print CGI::p($r->maketext(
		'Courses are listed either alphabetically or in order by the time of most recent login activity, '
			. 'oldest first. To change the listing order check the mode you want and click "Refresh Listing".  '
			. 'The listing format is: Course_Name (status :: date/time of most recent login) where status is "hidden" '
			. 'or "visible".'
	));

	print CGI::div(
		{ class => 'mb-3' },
		CGI::div({ class => 'mb-2' }, $r->maketext('Select a listing format:')),
		map {
			CGI::div(
				{ class => 'form-check' },
				CGI::input({
					type  => 'radio',
					name  => 'delete_listing_format',
					id    => "delete_listing_format_$_->[0]",
					value => $_->[0],
					class => 'form-check-input',
					$_->[0] eq ($r->param('delete_listing_format') // 'alphabetically') ? (checked => undef) : ()
				}),
				CGI::label(
					{
						for   => "delete_listing_format_$_->[0]",
						class => 'form-check-label'
					},
					$_->[1]
				)
			)
		} (
			[ alphabetically => $r->maketext('alphabetically') ],
			[ last_login     => $r->maketext('by last login date') ]
		),
	);

	print CGI::div(
		{ class => 'mb-2' },
		CGI::submit({
			name  => 'delete_course_refresh',
			value => $r->maketext('Refresh Listing'),
			class => 'btn btn-primary'
		}),
		CGI::submit({
			name  => 'delete_course',
			value => $r->maketext('Delete Course'),
			class => 'btn btn-primary'
		})
	);

	print $self->hidden_authen_fields;
	print $self->hidden_fields('subDisplay');

	print CGI::div({ class => 'mb-2' }, $r->maketext('Select a course to delete.'));
	print CGI::div(
		{ class => 'row mb-2' },
		CGI::label(
			{ for => 'delete_courseID', class => 'col-auto col-form-label fw-bold' },
			$r->maketext('Course Name:')
		),
		CGI::div(
			{ class => 'col-auto' },
			CGI::scrolling_list({
				name     => 'delete_courseID',
				id       => 'delete_courseID',
				values   => \@courseIDs,
				default  => $r->param('delete_courseID') || '',
				size     => 15,
				multiple => 0,
				labels   => \%courseLabels,
				class    => 'form-select'
			})
		)
	);

	print CGI::div(
		CGI::submit({
			name  => 'delete_course_refresh',
			value => $r->maketext('Refresh Listing'),
			class => 'btn btn-primary'
		}),
		CGI::submit({
			name  => 'delete_course',
			value => $r->maketext('Delete Course'),
			class => 'btn btn-primary'
		})
	);

	print CGI::end_form();
}

sub delete_course_validate {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	my $delete_courseID = $r->param("delete_courseID") || "";

	my @errors;

	if ($delete_courseID eq "") {
		push @errors, $r->maketext("You must specify a course name.");
	} elsif ($delete_courseID eq $urlpath->arg("courseID")) {
		push @errors, $r->maketext("You cannot delete the course you are currently using.");
	}

	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE, courseName => $delete_courseID,
	});

	return @errors;
}

sub delete_course_confirm {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	print CGI::h2($r->maketext('Delete Course'));

	my $delete_courseID = $r->param('delete_courseID') || '';

	my $ce2 = new WeBWorK::CourseEnvironment({ %WeBWorK::SeedCE, courseName => $delete_courseID });

	print CGI::p($r->maketext(
		'Are you sure you want to delete the course [_1]? All course files and data will be destroyed. '
			. 'There is no undo available.',
		CGI::b($delete_courseID)
	));

	print CGI::start_form({ method => 'POST', action => $r->uri });
	print $self->hidden_authen_fields;
	print $self->hidden_fields('subDisplay');
	print $self->hidden_fields('delete_courseID');

	print CGI::p(
		{ style => 'text-align: center' },
		CGI::submit({
			name  => 'decline_delete_course',
			label => $r->maketext("Don't delete"),
			class => 'btn btn-primary'
		}),
		'&nbsp;',
		CGI::submit({
			name  => 'confirm_delete_course',
			label => $r->maketext('Delete'),
			class => 'btn btn-primary'
		}),
	);

	print CGI::end_form();
}

sub do_delete_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;

	my $delete_courseID = $r->param("delete_courseID") || "";

	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE, courseName => $delete_courseID,
	});

	# this is kinda left over from when we had 'gdbm' and 'sql' database layouts
	# below this line, we would grab values from getopt and put them in this hash
	# but for now the hash can remain empty
	my %dbOptions;

	eval { deleteCourse(courseID => $delete_courseID, ce => $ce2, dbOptions => \%dbOptions,); };

	if ($@) {
		my $error = $@;
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			CGI::p($r->maketext("An error occured while deleting the course [_1]:", $delete_courseID)),
			CGI::div({ class => 'font-monospace' }, CGI::escapeHTML($error)),
		);
	} else {
		# mark the contact person in the admin course as dropped.
		# find the contact person for the course by searching the admin classlist.
		my @contacts = grep /_$delete_courseID$/, $db->listUsers;
		if (@contacts) {
			die "Incorrect number of contacts for the course $delete_courseID" . join(" ", @contacts) if @contacts != 1;
			#warn "contacts", join(" ", @contacts);
			#my $composite_id = "${add_initial_userID}_${add_courseID}";
			my $composite_id = $contacts[0];

			# mark the contact person as dropped.
			my $User         = $db->getUser($composite_id);
			my $status_name  = 'Drop';
			my $status_value = ($ce->status_name_to_abbrevs($status_name))[0];
			$User->status($status_value);
			$db->putUser($User);
		}

		print CGI::div(
			{ class => 'alert alert-success p-1 mb-2' },
			$r->maketext("Successfully deleted the course [_1].", $delete_courseID),
		);
		writeLog($ce, "hosted_courses", join("\t", "\tDeleted", "", "", $delete_courseID,));
		print CGI::start_form(-method => "POST", -action => $r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");

		print CGI::p(
			{ style => "text-align: center" },
			CGI::submit({
				name  => "decline_delete_course",
				value => $r->maketext("OK"),
				class => 'btn btn-primary'
			})
		);

		print CGI::end_form();
	}
}

sub archive_course_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	print CGI::h2($r->maketext('Archive Course'));

	print CGI::p($r->maketext(
		'Creates a gzipped tar archive (.tar.gz) of a course in the WeBWorK courses directory. '
			. 'Before archiving, the course database is dumped into a subdirectory of the course\'s DATA directory. '
			. 'Currently the archive facility is only available for mysql databases. It depends on the mysqldump '
			. 'application.'
	));

	my @courseIDs = listCourses($ce);

	unless (@courseIDs) {
		print CGI::p($r->maketext('No courses found'));
		return;
	}

	my $archive_listing_format = $r->param('archive_listing_format') // 'alphabetically';

	my $coursesDir = $ce->{webworkDirs}{courses};

	# Get and store last modify time for login.log for all courses. Also get visibility status.
	my %courseLabels;
	my @noLoginLogIDs;
	my @loginLogIDs;

	my ($loginLogFile, $epoch_modify_time, $courseDir);
	for my $courseID (@courseIDs) {
		$loginLogFile = "$coursesDir/$courseID/logs/login.log";
		if (-e $loginLogFile) {
			# The login log file should always exist except for the model course.
			$epoch_modify_time                           = stat($loginLogFile)->mtime;
			$coursesData{$courseID}{'epoch_modify_time'} = $epoch_modify_time;
			$coursesData{$courseID}{'local_modify_time'} = ctime($epoch_modify_time);
			push(@loginLogIDs, $courseID);
		} else {
			# This is for the model course.
			$coursesData{$courseID}{'local_modify_time'} = 'no login.log';
			push(@noLoginLogIDs, $courseID);
		}
		if (-f "$coursesDir/$courseID/hide_directory") {
			$coursesData{$courseID}{'status'} = $r->maketext('hidden');
		} else {
			$coursesData{$courseID}{'status'} = $r->maketext('visible');
		}
		$courseLabels{$courseID} =
			"$courseID  ($coursesData{$courseID}{'status'} :: $coursesData{$courseID}{'local_modify_time'}) ";
	}
	if ($archive_listing_format eq 'last_login') {
		# This should be an empty array except for the model course
		@noLoginLogIDs = sort { lc($a) cmp lc($b) } @noLoginLogIDs;
		@loginLogIDs   = sort byLoginActivity @loginLogIDs;           # oldest first
		@courseIDs     = (@noLoginLogIDs, @loginLogIDs);
	} else {
		# in this case we sort alphabetically
		@courseIDs = sort { lc($a) cmp lc($b) } @courseIDs;
	}

	print CGI::p($r->maketext(
		'Courses are listed either alphabetically or in order by the time of most recent login activity, oldest first. '
			. 'To change the listing order check the mode you want and click "Refresh Listing".  '
			. 'The listing format is: Course_Name (status :: date/time of most recent login) where status is "hidden" '
			. 'or "visible".'
	));

	print CGI::start_form(-method => 'POST', -action => $r->uri);

	print CGI::div(
		{ class => 'mb-3' },
		CGI::div({ class => 'mb-2' }, $r->maketext('Select a listing format:')),
		map {
			CGI::div(
				{ class => 'form-check' },
				CGI::input({
					type  => 'radio',
					name  => 'archive_listing_format',
					id    => "archive_listing_format_$_->[0]",
					value => $_->[0],
					class => 'form-check-input',
					$_->[0] eq ($r->param('archive_listing_format') // 'alphabetically') ? (checked => undef) : ()
				}),
				CGI::label(
					{
						for   => "archive_listing_format_$_->[0]",
						class => 'form-check-label'
					},
					$_->[1]
				)
			)
		} (
			[ alphabetically => $r->maketext('alphabetically') ],
			[ last_login     => $r->maketext('by last login date') ]
		),
	);

	print CGI::div(
		{ class => 'mb-2' },
		CGI::submit({
			name  => 'archive_course_refresh',
			value => $r->maketext('Refresh Listing'),
			class => 'btn btn-primary'
		}),
		CGI::submit({
			name  => 'archive_course',
			value => $r->maketext('Archive Courses'),
			class => 'btn btn-primary'
		})
	);

	print $self->hidden_authen_fields;
	print $self->hidden_fields('subDisplay');

	print CGI::div({ class => 'mb-2' }, $r->maketext('Select course(s) to archive.'));
	print CGI::div(
		{ class => 'row mb-2' },
		CGI::label(
			{ for => 'archive_courseIDs', class => 'col-auto col-form-label fw-bold' },
			$r->maketext('Course Name:')
		),
		CGI::div(
			{ class => 'col-auto' },
			CGI::scrolling_list({
				name     => 'archive_courseIDs',
				id       => 'archive_courseIDs',
				values   => \@courseIDs,
				default  => $r->param('archive_courseID') || '',
				size     => 15,
				multiple => 1,
				labels   => \%courseLabels,
				class    => 'form-select'
			})
		)
	);

	print CGI::div(
		{ class => 'row align-items-center mb-2' },
		CGI::div({ class => 'col-auto fw-bold' }, $r->maketext('Delete course:')),
		CGI::div(
			{ class => 'col-auto' },
			CGI::div(
				{ class => 'form-check mb-0' },
				CGI::checkbox({
					name            => 'delete_course',
					checked         => 0,
					value           => 1,
					label           => $r->maketext('Delete course after archiving. Caution there is no undo!'),
					class           => 'form-check-input',
					labelattributes => { class => 'form-check-label alert alert-danger py-0 px-1 mb-0' }
				})
			)
		)
	);

	print CGI::div(
		CGI::submit({
			name  => 'archive_course_refresh',
			value => $r->maketext('Refresh Listing'),
			class => 'btn btn-primary'
		}),
		CGI::submit({
			name  => 'archive_course',
			value => $r->maketext('Archive Courses'),
			class => 'btn btn-primary'
		})
	);

	print CGI::end_form();
}

sub archive_course_validate {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	my @archive_courseIDs = $r->param("archive_courseIDs");
	@archive_courseIDs = () unless @archive_courseIDs;
	my @errors;
	foreach my $archive_courseID (@archive_courseIDs) {
		if ($archive_courseID eq "") {
			push @errors, $r->maketext("You must specify a course name.");
		} elsif ($archive_courseID eq $urlpath->arg("courseID")) {
			push @errors, $r->maketext("You cannot archive the course you are currently using.");
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
	my $r      = $self->r;
	my $ce     = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;

	print CGI::h2($r->maketext("Archive Course"));

	my $delete_course_flag = $r->param("delete_course") || "";

	my @archive_courseIDs = $r->param("archive_courseIDs");
	@archive_courseIDs = () unless @archive_courseIDs;
	# if we are skipping a course remove one from
	# the list of courses
	if (defined $r->param("skip_archive_course")) {
		shift @archive_courseIDs;
	}

	my $archive_courseID = $archive_courseIDs[0];

	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE, courseName => $archive_courseID,
	});

	my ($tables_ok, $dbStatus);
#############################################################################
	# Check database
#############################################################################
	my %missing_fields;
	if ($ce2->{dbLayoutName}) {
		my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce => $ce2);
		($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($archive_courseID);
		if ($r->param("upgrade_course_tables")) {
			my @schema_table_names = keys %$dbStatus;    # update tables missing from database;
			my @tables_to_create =
				grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A } @schema_table_names;
			my @tables_to_alter =
				grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B }
				@schema_table_names;
			my $msg = $CIchecker->updateCourseTables($archive_courseID, [@tables_to_create]);
			foreach my $table_name (@tables_to_alter) {
				$msg .= $CIchecker->updateTableFields($archive_courseID, $table_name);
			}
			print CGI::p({ class => 'text-success fw-bold' }, $msg);
		}
		if ($r->param("upgrade_course_tables")) {

			$CIchecker->updateCourseDirectories();    # needs more error messages
		}
		($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($archive_courseID);

		# print db status

		my %msg = (
			WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A =>
				CGI::span({ class => 'text-danger' }, $r->maketext("Table defined in schema but missing in database")),
			WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B =>
				CGI::span({ class => 'text-danger' }, $r->maketext("Table defined in database but missing in schema")),
			WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B =>
				CGI::span({ class => 'text-success' }, $r->maketext("Table is ok")),
			WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => CGI::span(
				{ class => 'text-danger' },
				$r->maketext("Schema and database table definitions do not agree")
			),
		);
		my %msg2 = (
			WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A =>
				CGI::span({ class => 'text-danger' }, $r->maketext("Field missing in database")),
			WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B =>
				CGI::span({ class => 'text-danger' }, $r->maketext("Field missing in schema")),
			WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B =>
				CGI::span({ class => 'text-success' }, $r->maketext("Field is ok")),
			WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => CGI::span(
				{ class => 'text-danger' },
				$r->maketext("Schema and database field definitions do not agree")
			),
		);
		my $all_tables_ok         = 1;
		my $extra_database_tables = 0;
		my $extra_database_fields = 0;
		my $str = CGI::h4($r->maketext("Report on database structure for course [_1]:", $archive_courseID)) . CGI::br();
		foreach my $table (sort keys %$dbStatus) {
			my $table_status = $dbStatus->{$table}->[0];
			$str .= CGI::b($table) . ": " . $msg{$table_status} . CGI::br();

		CASE: {
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B
					&& do {
						last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A
					&& do {
						$all_tables_ok = 0;
						last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B
					&& do {
						$extra_database_tables = 1;
						last CASE;
					};
				$table_status == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B
					&& do {
						my %fieldInfo = %{ $dbStatus->{$table}->[1] };
						foreach my $key (keys %fieldInfo) {
							my $field_status = $fieldInfo{$key}->[0];
						CASE2: {
								$field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B
								&& do {
									$extra_database_fields = 1;
									last CASE2;
								};
								$field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A
								&& do {
									$all_tables_ok = 0;
									last CASE2;
								};
							}
							$str .= CGI::br() . "\n&nbsp;&nbsp;$key => " . $msg2{$field_status};
						}
					};
			}
			$str .= CGI::br();

		}
#############################################################################
		# Report on databases
#############################################################################

		print CGI::p($str);
		if ($extra_database_tables) {
			print CGI::p(
				{ class => 'text-danger fw-bold' },
				$r->maketext(
					'There are extra database tables which are not defined in the schema.  '
						. 'These can be deleted when upgrading the course.'
				)
			);
		}
		if ($extra_database_fields) {
			print CGI::p(
				{ class => 'text-danger fw-bold' },
				$r->maketext(
					'There are extra database fields which are not defined in the schema for at least one table.  '
						. 'They can only be removed when upgrading the course.'
				)
			);
		}
		if ($all_tables_ok) {
			print CGI::p({ class => 'text-success fw-bold' },
				$r->maketext("Course [_1] database is in order", $archive_courseID));
			print(CGI::p(
				{ class => 'text-danger fw-bold' },
				$r->maketext(
					"Are you sure that you want to delete the course [_1] after archiving? This cannot be undone!",
					CGI::b($archive_courseID)
				)
			))
				if $delete_course_flag;
		} else {
			print CGI::p(
				{ class => 'text-danger fw-bold' },
				$r->maketext(
					'There are tables or fields missing from the database.  '
						. 'The database must be upgraded before archiving this course.'
				)
			);
		}
#############################################################################
		# Check directories and report
#############################################################################

		my ($directories_ok, $str2) = $CIchecker->checkCourseDirectories($ce2);
		print CGI::h2('Directory structure'), CGI::p($str2),
			$directories_ok ? CGI::p({ class => 'text-success' }, $r->maketext('Directory structure is ok')) : CGI::p(
				{ class => 'text-danger' },
				$r->maketext(
					'Directory structure is missing directories or the webserver lacks sufficient privileges.')
			);

#############################################################################
		# Print form for choosing next action.
#############################################################################

		print CGI::start_form(-method => "POST", -action => $r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		print $self->hidden_fields(qw/delete_course/);
		print CGI::hidden('archive_courseID',  $archive_courseID);
		print CGI::hidden('archive_courseIDs', @archive_courseIDs);
		# grab some values we'll need
		my $course_dir   = $ce2->{courseDirs}{root};
		my $archive_path = $ce2->{webworkDirs}{courses} . "/$archive_courseID.tar.gz";
		# fail if the source course does not exist
		unless (-e $course_dir) {
			print CGI::p($r->maketext("[_1]: The directory for the course not found.", $archive_courseID));
		}

		if ($all_tables_ok && $directories_ok) {    # no missing fields
													# Warn about overwriting an existing archive
			if (-e $archive_path and -w $archive_path) {
				print CGI::p(
					{ class => 'text-danger fw-bold' },
					$r->maketext(
						"The course '[_1]' has already been archived at '[_2]'. "
							. "This earlier archive will be erased.  This cannot be undone.",
						$archive_courseID,
						$archive_path
					)
				);
			}
			# archive execute button
			print CGI::p(
				{ style => "text-align: center" },
				CGI::submit({
					name  => "decline_archive_course",
					value => $r->maketext("Stop Archiving"),
					class => 'btn btn-primary'
				}),
				"&nbsp;",
				scalar(@archive_courseIDs) > 1
				? CGI::submit({
					name  => "skip_archive_course",
					value => $r->maketext("Skip archiving this course"),
					class => 'btn btn-primary'
				})
					. "&nbsp;"
				: '',
				CGI::submit({
					name  => "confirm_archive_course",
					value => $r->maketext("Archive"),
					class => 'btn btn-primary'
				}),
			);
		} elsif ($directories_ok) {
			print CGI::p(
				{ style => "text-align: center" },
				CGI::submit({
					name   => "decline_archive_course",
					-value => $r->maketext("Don't Archive"),
					class  => 'btn btn-primary'
				}),
				"&nbsp;",
				CGI::submit({
					name  => "upgrade_course_tables",
					value => $r->maketext("Upgrade Course Tables"),
					class => 'btn btn-primary'
				})
			);
		} else {
			print CGI::p(
				{ style => "text-align: center" },
				CGI::br(),
				$r->maketext("Directory structure needs to be repaired manually before archiving."),
				CGI::br(),
				CGI::submit({
					name  => "decline_archive_course",
					value => $r->maketext("Don't Archive"),
					class => 'btn btn-primary'
				}),
				CGI::submit({
					name  => "upgrade_course_tables",
					value => $r->maketext("Attempt to upgrade directories"),
					class => 'btn btn-primary'
				}),
			);

		}
		print CGI::end_form();
	} else {
		print CGI::p({ class => 'text-danger fw-bold' }, "Unable to find database layout for $archive_courseID");
	}
}

sub do_archive_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;

	my $delete_course_flag = $r->param("delete_course") || "";
	my @archive_courseIDs  = $r->param("archive_courseIDs");
	@archive_courseIDs = () unless @archive_courseIDs;
	my $archive_courseID = $archive_courseIDs[0];

	my $ce2 = new WeBWorK::CourseEnvironment({
		%WeBWorK::SeedCE, courseName => $archive_courseID,
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

	eval { archiveCourse(courseID => $archive_courseID, ce => $ce2, dbOptions => \%dbOptions,); };

	if ($@) {
		my $error = $@;
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			CGI::p($r->maketext("An error occured while archiving the course [_1]:", $archive_courseID)),
			CGI::div({ class => 'font-monospace' }, CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div({ class => 'alert alert-success p-1 mb-2' },
			$r->maketext("Successfully archived the course [_1].", $archive_courseID));
		writeLog($ce, "hosted_courses", join("\t", "\tarchived", "", "", $archive_courseID,));

		if ($delete_course_flag) {
			eval { deleteCourse(courseID => $archive_courseID, ce => $ce2, dbOptions => \%dbOptions,); };

			if ($@) {
				my $error = $@;
				print CGI::div(
					{ class => 'alert alert-danger p-1 mb-2' },
					CGI::p($r->maketext("An error occured while deleting the course [_1]:", $archive_courseID)),
					CGI::div({ class => 'font-monospace' }, CGI::escapeHTML($error)),
				);
			} else {
				# mark the contact person in the admin course as dropped.
				# find the contact person for the course by searching the admin classlist.
				my @contacts = grep /_$archive_courseID$/, $db->listUsers;
				if (@contacts) {
					die "Incorrect number of contacts for the course $archive_courseID" . join(" ", @contacts)
						if @contacts != 1;
					#warn "contacts", join(" ", @contacts);
					#my $composite_id = "${add_initial_userID}_${add_courseID}";
					my $composite_id = $contacts[0];

					# mark the contact person as dropped.
					my $User         = $db->getUser($composite_id);
					my $status_name  = 'Drop';
					my $status_value = ($ce->status_name_to_abbrevs($status_name))[0];
					$User->status($status_value);
					$db->putUser($User);
				}

				print CGI::div(
					{ class => 'alert alert-success p-1 mb-2' },
					$r->maketext("Successfully deleted the course [_1].", $archive_courseID),
				);
			}

		}
		shift @archive_courseIDs;    # remove the course which has just been archived.
		if (@archive_courseIDs) {
			print CGI::start_form(-method => "POST", -action => $r->uri);
			print $self->hidden_authen_fields;
			print $self->hidden_fields("subDisplay");
			print $self->hidden_fields(qw/delete_course/);

			print CGI::hidden('archive_courseIDs', @archive_courseIDs);
			print CGI::p(
				{ style => "text-align: center" },
				CGI::submit({
					name  => "decline_archive_course",
					value => $r->maketext("Stop archiving courses"),
					class => 'btn btn-primary'
				}),
				CGI::submit({
					name  => "archive_course",
					value => $r->maketext("Archive next course"),
					class => 'btn btn-primary'
				})
			);
			print CGI::end_form();
		} else {
			print CGI::start_form(-method => "POST", -action => $r->uri);
			print $self->hidden_authen_fields;
			print $self->hidden_fields("subDisplay");
			print CGI::hidden('archive_courseIDs', $archive_courseID);
			print CGI::p(CGI::submit({
				name  => "decline_archive_course",
				value => $r->maketext("OK"),
				class => 'btn btn-primary'
			}));
			print CGI::end_form();
		}
	}
}

##########################################################################

sub unarchive_course_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	print CGI::h2($r->maketext('Unarchive Course'));

	print CGI::p($r->maketext(
		'Restores a course from a gzipped tar archive (.tar.gz). After unarchiving, the course database is '
			. "restored from a subdirectory of the course's DATA directory. Currently the archive facility is only "
			. 'available for mysql databases. It depends on the mysqldump application.'
	));

	# First find courses which have been archived.
	my @courseIDs = sort { lc($a) cmp lc($b) } listArchivedCourses($ce);    # Make sort case insensitive

	unless (@courseIDs) {
		print CGI::p($r->maketext('No course archives found.'));
		return;
	}

	my %courseLabels;
	for my $courseID (@courseIDs) {
		$courseLabels{$courseID} = $courseID;
	}

	print CGI::start_form({ method => 'POST', action => $r->uri });
	print $self->hidden_authen_fields;
	print $self->hidden_fields('subDisplay');

	print CGI::div({ class => 'mb-2' }, $r->maketext('Select a course to unarchive.'));

	print CGI::div(
		{ class => 'col-lg-7 col-md-8' },
		CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'unarchive_courseID', class => 'col-sm-4 col-form-label' },
				$r->maketext('Course Name:')
			),
			CGI::div(
				{ class => 'col-sm-8' },
				CGI::scrolling_list({
					name     => 'unarchive_courseID',
					id       => 'unarchive_courseID',
					values   => \@courseIDs,
					default  => $r->param('unarchive_courseID') || '',
					size     => 10,
					multiple => 0,
					labels   => \%courseLabels,
					class    => 'form-select'
				})
			)
		),
		CGI::div(
			{ class => 'row mb-2 align-items-center' },
			CGI::div(
				{ class => 'col-sm-4' },
				CGI::div(
					{ class => 'form-check' },
					CGI::checkbox({
						name            => 'create_newCourseID',
						value           => 1,
						label           => $r->maketext('New Name:'),
						class           => 'form-check-input',
						labelattributes => { class => 'form-check-label', id => 'create_newCourseID_label' }
					})
				)
			),
			CGI::div(
				{ class => 'col-sm-8' },
				CGI::textfield({
					name            => 'new_courseID',
					value           => '',
					size            => 25,
					maxlength       => $ce->{maxCourseIdLength},
					class           => 'form-control',
					aria_labelledby => 'create_newCourseID_label'
				})
			)
		)
	);

	print CGI::div(CGI::submit({
		name  => 'unarchive_course',
		value => $r->maketext('Unarchive Course'),
		class => 'btn btn-primary'
	}));

	print CGI::end_form();
}

sub unarchive_course_validate {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	my $unarchive_courseID = $r->param("unarchive_courseID") || "";
	my $create_newCourseID = $r->param("create_newCourseID") || "";
	my $new_courseID       = $r->param("new_courseID")       || "";
	my @errors;
	#by default we use the archive name for the course
	my $courseID = $unarchive_courseID;
	$courseID =~ s/\.tar\.gz$//;

	if ($create_newCourseID) {
		$courseID = $new_courseID;
	}
	debug(" unarchive_courseID $unarchive_courseID new_courseID $new_courseID ");

	if ($courseID eq "") {
		push @errors, $r->maketext("You must specify a course name.");
	} elsif (-d $ce->{webworkDirs}->{courses} . "/$courseID") {
		#Check that a directory for this course doesn't already exist
		push @errors,
			$r->maketext(
				"A directory already exists with the name [_1]. You must first delete this existing course before you can unarchive.",
				$courseID
			);
	} elsif (length($courseID) > $ce->{maxCourseIdLength}) {
		push @errors, $r->maketext("Course ID cannot exceed [_1] characters.", $ce->{maxCourseIdLength});
	}

	return @errors;
}

sub unarchive_course_confirm {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	#my $urlpath = $r->urlpath;

	print CGI::h2($r->maketext("Unarchive Course"));

	my $unarchive_courseID = $r->param("unarchive_courseID") || "";
	my $create_newCourseID = $r->param("create_newCourseID") || "";
	my $new_courseID       = $r->param("new_courseID")       || "";

	my $courseID = $unarchive_courseID;
	$courseID =~ s/\.tar\.gz$//;

	if ($create_newCourseID) {
		$courseID = $new_courseID;
	}

	debug(" unarchive_courseID $unarchive_courseID new_courseID $new_courseID ");

	print CGI::start_form(-method => "POST", -action => $r->uri);
	print CGI::p(
		$r->maketext("Unarchive [_1] to course:", $unarchive_courseID),
		CGI::input({ -name => 'new_courseID', -value => $courseID })
	);

	print $self->hidden_authen_fields;
	print $self->hidden_fields("subDisplay");
	print $self->hidden_fields(qw/unarchive_courseID create_newCourseID/);

	print CGI::p(
		{ style => "text-align: center" },
		CGI::submit({
			name  => "decline_unarchive_course",
			value => $r->maketext("Don't Unarchive"),
			class => 'btn btn-primary'
		}),
		"&nbsp;",
		CGI::submit({
			name  => "confirm_unarchive_course",
			value => $r->maketext("Unarchive"),
			class => 'btn btn-primary'
		}),
	);

	print CGI::end_form();
}

sub do_unarchive_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath            = $r->urlpath;
	my $new_courseID       = $r->param("new_courseID")       || "";
	my $unarchive_courseID = $r->param("unarchive_courseID") || "";

	my $old_courseID = $unarchive_courseID;
	$old_courseID =~ s/.tar.gz//;

	#eval {
	unarchiveCourse(
		newCourseID => $new_courseID,
		oldCourseID => $old_courseID,
		archivePath => $ce->{webworkDirs}->{courses} . "/$unarchive_courseID",
		ce          => $ce,
	);
	#};

	if ($@) {
		my $error = $@;
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			CGI::p($r->maketext("An error occured while archiving the course [_1]:", $unarchive_courseID)),
			CGI::div({ class => 'font-monospace' }, CGI::escapeHTML($error)),
		);
	} else {
		print CGI::div(
			{ class => 'alert alert-success p-1 mb-2' },
			$r->maketext("Successfully unarchived [_1] to the course [_2]", $unarchive_courseID, $new_courseID),
		);
		writeLog($ce, "hosted_courses", join("\t", "\tunarchived", "", "", "$unarchive_courseID to $new_courseID",));

		my $newCoursePath =
			$urlpath->newFromModule("WeBWorK::ContentGenerator::ProblemSets", $r, courseID => $new_courseID);
		my $newCourseURL = $self->systemLink($newCoursePath, authen => 0);
		print CGI::div(
			{ style => "text-align: center" },
			CGI::a({ href => $newCourseURL }, $r->maketext("Log into [_1]", $new_courseID)),
		);

		print CGI::start_form(-method => "POST", -action => $r->uri);
		print $self->hidden_authen_fields;
		print $self->hidden_fields("subDisplay");
		print CGI::hidden("unarchive_courseID", $unarchive_courseID);
		print CGI::p(CGI::submit({
			name  => "decline_unarchive_course",
			value => $r->maketext("Unarchive Next Course"),
			class => 'btn btn-primary'
		}));
		print CGI::end_form();
	}
}

##########################################################################
# Course upgrade methods

sub upgrade_course_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my @courseIDs = listCourses($ce);
	@courseIDs = sort { lc($a) cmp lc($b) } @courseIDs;    # make sort case insensitive

	print CGI::h2($r->maketext('Upgrade Courses'));

	print CGI::div({ class => 'mb-2' }, $r->maketext('Update the checked directories?'));

	print CGI::start_form({ method => 'POST', action => $r->uri, id => 'courselist', name => 'courselist' });

	print CGI::div(
		{ class => 'mb-2' },
		CGI::input({
			type              => 'button',
			value             => $r->maketext('Select all eligible courses'),
			class             => 'select-all btn btn-sm btn-secondary',
			data_select_group => 'upgrade_courseIDs'
		}),
		CGI::input({
			type              => 'button',
			value             => $r->maketext('Unselect all courses'),
			class             => 'select-none btn btn-sm btn-secondary',
			data_select_group => 'upgrade_courseIDs'
		})
	);

	print $self->hidden_authen_fields;
	print $self->hidden_fields('subDisplay');

	print CGI::start_ul();
	foreach my $courseID (@courseIDs) {
		next if $courseID eq 'modelCourse';   # modelCourse isn't a real course so don't create missing directories, etc
		next unless $courseID =~ /\S/;        # skip empty courseIDs (there shouldn't be any)
		my $urlpath = $r->urlpath->newFromModule('WeBWorK::ContentGenerator::ProblemSets', $r, courseID => $courseID);
		my $tempCE;
		eval { $tempCE = new WeBWorK::CourseEnvironment({ %WeBWorK::SeedCE, courseName => $courseID, }) };
		print $r->maketext("Can't create course environment for [_1] because [_2]", $courseID, $@) if $@;
		my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce => $tempCE);
		$CIchecker->updateCourseDirectories();    #creates missing html_temp, mailmerge tmpEditFileDir directories;
		my ($tables_ok,      $dbStatus) = $CIchecker->checkCourseTables($courseID);
		my ($directories_ok, $str2)     = $CIchecker->checkCourseDirectories();
		my $checked = ($tables_ok && $directories_ok) ? 0 : 1;    # don't check if everything is ok

		print CGI::li(
			{ class => 'align-items-center' },
			# Only show the checkbox if the course is not up to date.
			$checked ? CGI::div(
				{ class => 'form-check form-check-inline me-1' },
				CGI::checkbox({
					name            => 'upgrade_courseIDs',
					label           => $r->maketext('Upgrade'),
					selected        => $checked,
					value           => $courseID,
					class           => 'form-check-input',
					labelattributes => { class => 'form-check-label' }
				})
			) : '',
			CGI::a({ href => $self->systemLink($urlpath, authen => 0) }, $courseID),
			CGI::code($tempCE->{dbLayoutName},),
			$directories_ok ? '' : CGI::span(
				{ class => 'alert alert-danger p-1 mb-0' },
				$r->maketext('Directory structure or permissions need to be repaired. ')
			),
			$tables_ok
			? CGI::span({ class => 'text-success' }, $r->maketext('Database tables ok'))
			: CGI::span({ class => 'text-danger' },  $r->maketext('Database tables need updating.')),
		);
	}
	print CGI::end_ul();

	print CGI::div(CGI::submit({
		name  => 'upgrade_course',
		value => $r->maketext('Upgrade Courses'),
		class => 'btn btn-primary'
	}));

	print CGI::end_form();
}

sub upgrade_course_validate {
	my $self = shift;
	my $r    = $self->r;

	my @upgrade_courseIDs = ($r->param("upgrade_courseIDs"));

	my @errors;
	for my $upgrade_courseID (@upgrade_courseIDs) {
		if ($upgrade_courseID eq '') {
			push @errors, $r->maketext('You must specify a course name.');
		}
	}

	return @errors;
}

sub upgrade_course_confirm {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;

	my @upgrade_courseIDs = ($r->param("upgrade_courseIDs"));

	my ($extra_database_tables_exist, $extra_database_fields_exist) = (0, 0);

	print CGI::start_form({ method => 'POST', action => $r->uri });

	my $output = '';
	for my $upgrade_courseID (@upgrade_courseIDs) {
		next unless $upgrade_courseID =~ /\S/;    # skip empty values

		# Analyze one course
		my $ce2 = new WeBWorK::CourseEnvironment({ %WeBWorK::SeedCE, courseName => $upgrade_courseID });

		# Create integrity checker
		my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce => $ce2);

		# Report on database status
		my ($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);
		my ($all_tables_ok, $extra_database_tables, $extra_database_fields, $str) =
			$self->formatReportOnDatabaseTables($tables_ok, $dbStatus, $upgrade_courseID);

		$output .= CGI::start_div({ class => 'border border-dark rounded p-2 mb-2' });

		# Add the report on databases to the output.
		$output .= CGI::div(
			{ class => 'form-check mb-2' },
			CGI::checkbox({
				name            => 'upgrade_courseIDs',
				label           => $r->maketext('Upgrade [_1]', $upgrade_courseID),
				selected        => 1,
				value           => $upgrade_courseID,
				class           => 'form-check-input',
				labelattributes => { class => 'form-check-label' }
			})
		);
		$output .= CGI::h2($r->maketext('Report for course [_1]:', $upgrade_courseID));
		$output .= CGI::div({ class => 'mb-2' }, $r->maketext('Database:'));
		$output .= $str;

		if ($extra_database_tables) {
			$extra_database_tables_exist = 1;
			$output .= CGI::p(
				{ class => 'text-danger fw-bold' },
				$r->maketext('There are extra database tables which are not defined in the schema. ')
					. 'Check the checkbox by the table to delete it when upgrading the course. '
					. 'Warning: Deletion destroys all data contained in the table and is not undoable!'
			);
		}

		if ($extra_database_fields) {
			$extra_database_fields_exist = 1;
			$output .= CGI::p(
				{ class => 'text-danger fw-bold' },
				$r->maketext(
					'There are extra database fields which are not defined in the schema for at least one table. '
						. 'Check the checkbox by the field to delete it when upgrading the course. '
						. 'Warning: Deletion destroys all data contained in the field and is not undoable!'
				)
			);
		}

		# Report on directory status
		my ($directories_ok, $str2) = $CIchecker->checkCourseDirectories();
		$output .= CGI::div({ class => 'mb-2' }, $r->maketext('Directory structure:'));
		$output .= $str2;
		$output .=
			$directories_ok
			? CGI::p({ class => 'text-success mb-0' }, $r->maketext('Directory structure is ok'))
			: CGI::p(
				{ class => 'text-danger mb-0' },
				$r->maketext(
					'Directory structure is missing directories or the webserver lacks sufficient privileges.')
			);

		$output .= CGI::end_div();
	}

	my $checkAlls = '';

	if ($extra_database_tables_exist) {
		$checkAlls .= CGI::div(
			{ class => 'form-check' },
			CGI::checkbox({
				label             => $r->maketext('Select/unselect all tables missing in schema for deletion.'),
				class             => 'select-all form-check-input',
				labelattributes   => { class => 'form-check-label' },
				data_select_group => 'delete_tableIDs',
			})
		);
	}

	if ($extra_database_fields_exist) {
		$checkAlls .= CGI::div(
			{ class => 'form-check' },
			CGI::checkbox({
				label             => $r->maketext('Select/unselect all fields missing in schema for deletion.'),
				class             => 'select-all form-check-input',
				labelattributes   => { class => 'form-check-label' },
				data_select_group => 'delete_fieldIDs'
			})
		);
	}

	print CGI::div({ class => 'mb-3' }, $checkAlls);

	print $output;

	# Print form for choosing next action.
	print CGI::h3($r->maketext('No course id defined')) unless @upgrade_courseIDs;

	print $self->hidden_authen_fields;
	print $self->hidden_fields('subDisplay');

	print CGI::div({ class => 'mb-3' }, $checkAlls);

	# Submit buttons
	# After presenting a detailed summary of status of selected courses the choice is made to upgrade the selected
	# courses (confirm_upgrade_course is set or return to the beginning (decline_upgrade_course is set)
	print CGI::div(
		{ class => 'submit-buttons-container' },
		CGI::submit({
			name  => 'decline_upgrade_course',
			value => $r->maketext("Don't Upgrade"),
			class => 'btn btn-primary'
		}),
		CGI::submit({
			name  => 'confirm_upgrade_course',
			value => $r->maketext('Upgrade'),
			class => 'btn btn-primary'
		})
	);

	print CGI::end_form();
}

sub do_upgrade_course {
	my $self = shift;
	my $r    = $self->r;
	my $ce   = $r->ce;
	my $db   = $r->db;

	my @upgrade_courseIDs = ($r->param("upgrade_courseIDs"));

	my %update_error_msg;

	for my $upgrade_courseID (@upgrade_courseIDs) {
		next unless $upgrade_courseID =~ /\S/;    # Omit blank course IDs

		# Update one course
		my $ce2 = new WeBWorK::CourseEnvironment({ %WeBWorK::SeedCE, courseName => $upgrade_courseID });

		# Create integrity checker
		my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce => $ce2);

		# Add missing tables and missing fields to existing tables
		my ($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);
		my @schema_table_names = keys %$dbStatus;
		my @tables_to_create =
			grep { $dbStatus->{$_}[0] == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A } @schema_table_names;
		my @tables_to_alter =
			grep { $dbStatus->{$_}[0] == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B } @schema_table_names;
		$update_error_msg{$upgrade_courseID} = $CIchecker->updateCourseTables($upgrade_courseID, [@tables_to_create],
			[ ($r->param("$upgrade_courseID.delete_tableIDs")) ]);
		for my $table_name (@tables_to_alter) {
			$update_error_msg{$upgrade_courseID} .= $CIchecker->updateTableFields($upgrade_courseID, $table_name,
				[ ($r->param("$upgrade_courseID.$table_name.delete_fieldIDs")) ]);
		}

		# Add missing directories when it can be done safely
		$CIchecker->updateCourseDirectories();    # Needs more error messages

		# Analyze database status and prepare status report
		($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);

		my ($all_tables_ok, $extra_database_tables, $extra_database_fields, $str) =
			$self->formatReportOnDatabaseTables($tables_ok, $dbStatus);

		# Prepend course name
		$str = CGI::div({ class => 'mb-2' }, $r->maketext('Database:')) . $str;

		# Report on databases and report summary
		if ($extra_database_tables) {
			$str .= CGI::p({ class => 'text-danger fw-bold' },
				$r->maketext('There are extra database tables which are not defined in the schema.'));
		}
		if ($extra_database_fields) {
			$str .= CGI::p(
				{ class => 'text-danger fw-bold' },
				$r->maketext(
					'There are extra database fields which are not defined in the schema for at least one table.')
			);
		}

		# Prepare report on directory status
		my ($directories_ok, $str2) = $CIchecker->checkCourseDirectories();
		my $dir_msg = join(
			'',
			CGI::div({ class => 'mb-2' }, $r->maketext('Directory structure:')),
			$str2,
			$directories_ok
			? CGI::p({ class => 'text-success mb-0' }, $r->maketext('Directory structure is ok'))
			: CGI::p(
				{ class => 'text-danger mb-0' },
				$r->maketext(
					'Directory structure is missing directories or the webserver lacks sufficient privileges.')
			)
		);

		# Print status
		print CGI::start_div({ class => 'border border-dark rounded p-2 mb-2' });
		print CGI::h2($r->maketext('Report for course [_1]:', $upgrade_courseID));
		print CGI::p({ class => 'text-success fw-bold' }, $update_error_msg{$upgrade_courseID})
			if $update_error_msg{$upgrade_courseID};

		print $str;        # Print message about tables
		print $dir_msg;    # Print message about directories
		print CGI::end_div();
	}

	# Submit buttons -- return to beginning
	print CGI::h2($r->maketext('Upgrade process completed'));
	print CGI::start_form({ method => 'POST', action => $r->uri });    # send back to this script
	print $self->hidden_authen_fields;
	print $self->hidden_fields('subDisplay');
	print CGI::p(
		{ class => 'text-center' },
		CGI::submit({
			name  => 'decline_upgrade_course',
			value => $r->maketext('Done'),
			class => 'btn btn-primary'
		})
	);
	print CGI::end_form();
}

################################################################################
## location management routines; added by DG [Danny Ginn] 20070215
## revised by glarose

sub manage_location_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;

	# Get a list of all existing locations
	my @locations = sort { lc($a->location_id) cmp lc($b->location_id) } $db->getAllLocations();
	my %locAddr   = map  { $_->location_id => [ $db->listLocationAddresses($_->location_id) ] } @locations;

	my @locationIDs = map { $_->location_id } @locations;

	print CGI::h2($r->maketext('Manage Locations'));

	print CGI::p(CGI::strong($r->maketext('Currently defined locations are listed below.')));

	print CGI::start_form(-method => 'POST', -action => $r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields('subDisplay');

	# Get a list of radio buttons to select an action
	my @actionRadios = CGI::radio_group({
		name   => 'manage_location_action',
		values => [ 'edit_location_form', 'add_location_handler', 'delete_location_handler' ],
		labels => {
			edit_location_form      => $r->maketext('Edit Location:'),
			add_location_handler    => $r->maketext('Create Location:'),
			delete_location_handler => $r->maketext('Delete location:'),
		},
		default         => $r->param('manage_location_action') ? $r->param('manage_location_action') : 'none',
		class           => 'form-check-input',
		labelattributes => { class => 'form-check-label' }
	});

	print CGI::start_div({ class => 'col-lg-8 col-md-9' });
	print CGI::div({ class => 'mb-2 fw-bold' }, $r->maketext('Select an action to perform:'));

	# Edit action
	print CGI::div(
		{ class => 'row align-items-center mb-2' },
		CGI::div({ class => 'col-sm-4' }, CGI::div({ class => 'form-check' }, $actionRadios[0])),
		CGI::div(
			{ class => 'col-sm-8' },
			CGI::popup_menu({
				name   => 'edit_location',
				values => [@locationIDs],
				class  => 'form-select'
			})
		)
	);

	# Create action
	print CGI::div(
		{ class => 'row align-items-center mb-2' },
		CGI::div({ class => 'col-auto' }, CGI::div({ class => 'form-check' }, $actionRadios[1])),
	);

	print CGI::div(
		{ class => 'row ms-sm-3 mb-2' },
		CGI::label(
			{ for => 'new_location_name', class => 'col-sm-4 col-form-label' },
			$r->maketext('Location name:')
		),
		CGI::div(
			{ class => 'col-sm-8' },
			CGI::textfield({
				name  => 'new_location_name',
				id    => 'new_location_name',
				value => $r->param('new_location_name') // '',
				class => 'form-control'
			})
		)
	);

	print CGI::div(
		{ class => 'row ms-sm-3 mb-2' },
		CGI::label(
			{ for => 'new_location_description', class => 'col-sm-4 col-form-label' },
			$r->maketext('Location description:')
		),
		CGI::div(
			{ class => 'col-sm-8' },
			CGI::textfield({
				name  => 'new_location_description',
				id    => 'new_location_description',
				value => $r->param('new_location_description') // '',
				class => 'form-control'
			})
		)
	);

	print CGI::div(
		{ class => 'row ms-sm-3 mb-2' },
		CGI::div(
			{ class => 'col' },
			CGI::label(
				{ for => 'new_location_addresses' },
				$r->maketext(
					'Addresses for new location.  Enter one per line, as single IP addresses (e.g., 192.168.1.101), '
						. 'address masks (e.g., 192.168.1.0/24), or IP ranges (e.g., 192.168.1.101-192.168.1.150):'
				)
			)
		)
	);

	print CGI::div(
		{ class => 'row ms-sm-3 mb-2' },
		CGI::div(
			{ class => 'col-auto' },
			CGI::textarea({
				name    => 'new_location_addresses',
				id      => 'new_location_addresses',
				columns => 28,
				value   => $r->param('new_location_addresses') ? $r->param('new_location_addresses') : '',
				class   => 'form-control'
			})
		)
	);

	# Delete action
	print CGI::div(
		{ class => 'row mb-2' },
		CGI::div(
			{ class => 'text-danger' },
			CGI::em($r->maketext('Deletion deletes all location data and related addresses, and is not undoable!'))
		)
	);

	print CGI::div(
		{ class => 'row align-items-center mb-2' },
		CGI::div({ class => 'col-sm-4' }, CGI::div({ class => 'form-check' }, $actionRadios[2])),
		CGI::div(
			{ class => 'col-sm-8' },
			CGI::div(
				{ class => 'row mb-1' },
				CGI::div(
					{ class => 'col-auto' },
					CGI::popup_menu({
						name   => 'delete_location',
						values => [ '', 'selected_locations', @locationIDs ],
						labels => {
							selected_locations => $r->maketext('locations selected below'),
							''                 => $r->maketext('no location')
						},
						class => 'form-select'
					})
				)
			),
			CGI::div(
				{ class => 'row' },
				CGI::div(
					{ class => 'col-auto' },
					CGI::div(
						{ class => 'form-check' },
						CGI::checkbox({
							name            => 'delete_confirm',
							value           => 'true',
							label           => $r->maketext('Confirm'),
							class           => 'form-check-input',
							labelattributes => { class => 'form-check-label' }

						})
					)
				)
			)
		)
	);

	print CGI::end_div();

	print CGI::p(CGI::submit({
		name  => 'manage_locations',
		value => $r->maketext('Take Action!'),
		class => 'btn btn-primary'
	}));

	unless (@locations) {
		print CGI::div(
			{ class => 'row mt-3' },
			CGI::div({ class => 'col-lg-8 col-md-9 fw-bold' }, $r->maketext('No locations are currently defined.'))
		);
		return;
	}

	# Existing location table
	print CGI::start_div({ class => 'table-responsive mt-3' }),
		CGI::start_table({ class => 'table table-sm font-sm table-bordered table-striped' });
	print CGI::thead(CGI::Tr(CGI::th([ $r->maketext('Select'), $r->maketext('Location'), $r->maketext('Description'),
		$r->maketext('Addresses') ])));
	print CGI::start_tbody();
	for my $loc (@locations) {
		my $editAddr = $self->systemLink(
			$r->urlpath,
			params => {
				subDisplay             => 'manage_locations',
				manage_location_action => 'edit_location_form',
				edit_location          => $loc->location_id
			}
		);
		print CGI::Tr(CGI::td([
			CGI::checkbox({
				name  => 'delete_selected',
				id    => $loc->location_id . '_id',
				value => $loc->location_id,
				label => '',
				class => 'form-check-input'
			}),
			CGI::label({ for => $loc->location_id . '_id' }, CGI::a({ href => $editAddr }, $loc->location_id)),
			$loc->description,
			join(', ', @{ $locAddr{ $loc->location_id } })
		]));
	}
	print CGI::end_tbody();
	print CGI::end_table(), CGI::end_div();

	print CGI::end_form();
}

sub add_location_handler {
	my $self = shift();
	my $r    = $self->r;
	my $db   = $r->db;

	# the location data we're to add
	my $locationID    = $r->param("new_location_name");
	my $locationDescr = $r->param("new_location_description");
	my $locationAddr  = $r->param("new_location_addresses");
	# break the addresses up
	$locationAddr =~ s/\s*-\s*/-/g;
	$locationAddr =~ s/\s*\/\s*/\//g;
	my @addresses = split(/\s+/, $locationAddr);

	# sanity checks
	my $badAddr = '';
	foreach my $addr (@addresses) {
		unless (new Net::IP($addr)) {
			$badAddr .= "$addr, ";
			$locationAddr =~ s/$addr\n//s;
		}
	}
	$badAddr =~ s/, $//;

	# a check to be sure that the location addresses don't already
	#    exist
	my $badLocAddr = '';
	if (!$badAddr && $locationID) {
		if ($db->countLocationAddresses($locationID)) {
			my @allLocAddr = $db->listLocationAddresses($locationID);
			foreach my $addr (@addresses) {
				$badLocAddr .= "$addr, "
					if (grep {/^$addr$/} @allLocAddr);
			}
			$badLocAddr =~ s/, $//;
		}
	}

	if (!@addresses || !$locationID || !$locationDescr) {
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			$r->maketext(
				"Missing required input data. Please check that you have filled in all of the create location fields and resubmit."
			)
		);
	} elsif ($badAddr) {
		$r->param("new_location_addresses", $locationAddr);
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			$r->maketext(
				"Address(es) [_1] is(are) not in a recognized form.  Please check your data entry and resubmit.",
				$badAddr
			)
		);
	} elsif ($db->existsLocation($locationID)) {
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			$r->maketext(
				"A location with the name [_1] already exists in the database.  Did you mean to edit that location instead?",
				$locationID
			)
		);
	} elsif ($badLocAddr) {
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			$r->maketext(
				"Address(es) [_1] already exist in the database.  THIS SHOULD NOT HAPPEN!  Please double check the integrity of the WeBWorK database before continuing.",
				$badLocAddr
			)
		);
	} else {
		# add the location
		my $locationObj = $db->newLocation;
		$locationObj->location_id($locationID);
		$locationObj->description($locationDescr);
		$db->addLocation($locationObj);

		# and add the addresses
		foreach my $addr (@addresses) {
			my $locationAddress = $db->newLocationAddress;
			$locationAddress->location_id($locationID);
			$locationAddress->ip_mask($addr);

			$db->addLocationAddress($locationAddress);
		}

		# we've added the location, so clear those param
		#    entries
		$r->param('manage_location_action',   'none');
		$r->param('new_location_name',        '');
		$r->param('new_location_description', '');
		$r->param('new_location_addresses',   '');

		print CGI::div(
			{ class => 'alert alert-success p-1 mb-2' },
			$r->maketext(
				"Location [_1] has been created, with addresses [_2].",
				$locationID, join(', ', @addresses)
			)
		);
	}

	$self->manage_location_form;
}

sub delete_location_handler {
	my $self = shift;
	my $r    = $self->r;
	my $db   = $r->db;

	# what location are we deleting?
	my $locationID = $r->param("delete_location");
	# check for selected deletions if appropriate
	my @delLocations = ($locationID);
	if ($locationID eq 'selected_locations') {
		@delLocations = $r->param("delete_selected");
		$locationID   = @delLocations;
	}
	# are we sure?
	my $confirm = $r->param("delete_confirm");

	my $badID;
	if (!$locationID) {
		print CGI::div({ class => 'alert alert-danger p-1 mb-2' },
			$r->maketext("Please provide a location name to delete."));

	} elsif ($badID = $self->existsLocations_helper(@delLocations)) {
		print CGI::div({ class => 'alert alert-danger p-1 mb-2' },
			$r->maketext("No location with name [_1] exists in the database", $badID));

	} elsif (!$confirm || $confirm ne 'true') {
		print CGI::div({ class => 'alert alert-danger p-1 mb-2' },
			$r->maketext("Location deletion requires confirmation."));
	} else {
		foreach (@delLocations) {
			$db->deleteLocation($_);
		}
		print CGI::div({ class => 'alert alert-success p-1 mb-2' },
			$r->maketext("Deleted Location(s): [_1]", join(', ', @delLocations)));
		$r->param('manage_location_action', 'none');
		$r->param('delete_location',        '');
	}
	$self->manage_location_form;
}

sub existsLocations_helper {
	my ($self, @locations) = @_;
	my $db = $self->r->db;
	foreach (@locations) {
		return $_ if (!$db->existsLocation($_));
	}
	return 0;
}

sub edit_location_form {
	my $self = shift;
	my $r    = $self->r;
	my $db   = $r->db;

	my $locationID = $r->param('edit_location');
	if ($db->existsLocation($locationID)) {
		my $location = $db->getLocation($locationID);
		# This doesn't give that nice a sort for IP addresses,
		# b/c there's the problem with 192.168.1.168 sorting
		# ahead of 192.168.1.2.  we could do better if we
		# either invoked Net::IP in the sort routine, or if
		# we insisted on dealing only with IPv4.  rather than
		# deal with either of those, we'll leave this for now
		my @locAddresses = sort { $a cmp $b } $db->listLocationAddresses($locationID);

		print CGI::h2($r->maketext('Editing location [_1]', $locationID));

		print CGI::p($r->maketext(
			'Edit the current value of the location description, if desired, then add and select addresses to delete, '
				. q{and then click the "Take Action" button to make all of your changes.  Or, click }
				. q{"Manage Locations" above to make no changes and return to the Manage Locations page.}
		));

		print CGI::start_form({ method => 'POST', action => $r->uri });

		print $self->hidden_authen_fields;
		print $self->hidden_fields('subDisplay');
		print CGI::hidden({ name => 'edit_location',          default => $locationID });
		print CGI::hidden({ name => 'manage_location_action', default => 'edit_location_handler' });

		print CGI::div(
			{ class => 'row mb-2' },
			CGI::label(
				{ for => 'location_description', class => 'col-auto col-form-label' },
				$r->maketext('Location description:')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::textfield({
					name    => 'location_description',
					id      => 'location_description',
					size    => '50',
					default => $location->description,
					class   => 'form-control'
				})
			)
		);

		print CGI::div(
			{ class => 'row' },
			CGI::div(
				{ class => 'col-md-6' },
				CGI::div(
					{ class => 'mb-2' },
					CGI::label(
						{ for => 'new_location_addresses' },
						$r->maketext(
							'Addresses to add to the location.  Enter one per line, as single IP addresses '
								. '(e.g., 192.168.1.101), address masks (e.g., 192.168.1.0/24), or IP ranges '
								. '(e.g., 192.168.1.101-192.168.1.150):'
						)
					)
				),
				CGI::div(
					{ class => 'mb-2' },
					CGI::textarea({
						name    => 'new_location_addresses',
						id      => 'new_location_addresses',
						rows    => 5,
						columns => 28,
						class   => 'form-control'
					})
				)
			),
			CGI::div(
				{ class => 'col-md-6' },
				CGI::div(
					{ class => 'mb-2' },
					CGI::label(
						{ for => 'delete_location_addresses' },
						$r->maketext(
							'Existing addresses for the location are given in the scrolling list below.  '
								. 'Select addresses from the list to delete them:'
						)
					)
				),
				CGI::div(
					{ class => 'mb-2' },
					CGI::scrolling_list({
						name     => 'delete_location_addresses',
						id       => 'delete_location_addresses',
						values   => [@locAddresses],
						size     => 8,
						multiple => 'multiple',
						class    => 'form-select'
					})
				),
				CGI::div({ class => 'mb-2' }, $r->maketext('or')),
				CGI::div(
					{ class => 'mb-2' },
					CGI::div(
						{ class => 'form-check' },
						CGI::checkbox({
							name            => 'delete_all_addresses',
							value           => 'true',
							label           => $r->maketext('Delete all existing addresses'),
							class           => 'form-check-input',
							labelattributes => { class => 'form-check-label' }
						})
					)
				)
			)
		);

		print CGI::div(CGI::submit({
			value => $r->maketext('Take Action!'),
			class => 'btn btn-primary'
		}));

		print CGI::end_form();
	} else {
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			$r->maketext(
				'Location [_1] does not exist in the WeBWorK database.  Please check your input '
					. '(perhaps you need to reload the location management page?).',
				$locationID
			)
		);
		$self->manage_location_form;
	}
}

sub edit_location_handler {
	my $self = shift;
	my $r    = $self->r;
	my $db   = $r->db;

	my $locationID   = $r->param("edit_location");
	my $locationDesc = $r->param("location_description");
	my $addAddresses = $r->param("new_location_addresses");
	my @delAddresses = $r->param("delete_location_addresses");
	my $deleteAll    = $r->param("delete_all_addresses");

	# gut check
	if (!$locationID) {
		print CGI::div({ class => 'alert alert-danger p-1 mb-2' },
			$r->maketext("No location specified to edit. Please check your input data."));
		$self->manage_location_form;

	} elsif (!$db->existsLocation($locationID)) {
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			$r->maketext(
				"Location [_1] does not exist in the WeBWorK database.  Please check your input (perhaps you need to reload the location management page?).",
				$locationID
			)
		);
		$self->manage_location_form;
	} else {
		my $location = $db->getLocation($locationID);

		# get the current location addresses.  if we're deleting
		#   all of the existing addresses, we don't use this list
		#   to determine which addresses to add, however.
		my @currentAddr = $db->listLocationAddresses($locationID);
		my @compareAddr = (!$deleteAll || $deleteAll ne 'true') ? @currentAddr : ();

		my $doneMsg = '';

		if ($locationDesc && $location->description ne $locationDesc) {
			$location->description($locationDesc);
			$db->putLocation($location);
			$doneMsg .= CGI::p({}, $r->maketext("Updated location description."));
		}
		# get the actual addresses to add out of the text field
		$addAddresses =~ s/\s*-\s*/-/g;
		$addAddresses =~ s/\s*\/\s*/\//g;
		my @addAddresses = split(/\s+/, $addAddresses);

		# make sure that we're adding and deleting only those
		#    addresses that are not yet/currently in the location
		#    addresses
		my @toAdd = ();
		my @noAdd = ();
		my @toDel = ();
		my @noDel = ();
		foreach my $addr (@addAddresses) {
			if (grep {/^$addr$/} @compareAddr) {
				push(@noAdd, $addr);
			} else {
				push(@toAdd, $addr);
			}
		}
		if ($deleteAll && $deleteAll eq 'true') {
			@toDel = @currentAddr;
		} else {
			foreach my $addr (@delAddresses) {
				if (grep {/^$addr$/} @currentAddr) {
					push(@toDel, $addr);
				} else {
					push(@noDel, $addr);
				}
			}
		}

		# and make sure that all of the addresses we're adding are
		#    a sensible form
		my $badAddr = '';
		foreach my $addr (@toAdd) {
			unless (new Net::IP($addr)) {
				$badAddr .= "$addr, ";
			}
		}
		$badAddr =~ s/, $//;

		# delete addresses first, because we allow deletion of
		#    all existing addresses, then addition of addresses.
		#    note that we don't allow deletion and then addition
		#    of the same address normally, however; in that case
		#    we'll end up just deleting the address.
		foreach (@toDel) {
			$db->deleteLocationAddress($locationID, $_);
		}
		foreach (@toAdd) {
			my $locAddr = $db->newLocationAddress;
			$locAddr->location_id($locationID);
			$locAddr->ip_mask($_);

			$db->addLocationAddress($locAddr);
		}

		my $addrMsg = '';
		$addrMsg .= $r->maketext("Deleted addresses [_1] from location.", join(', ', @toDel)) . CGI::br() if (@toDel);
		$addrMsg .= $r->maketext("Added addresses [_1] to location [_2].", join(', ', @toAdd), $locationID) if (@toAdd);

		my $badMsg = '';
		$badMsg .=
			$r->maketext('Address(es) [_1] in the add list is(are) already in the location [_2], and so were skipped.',
				join(', ', @noAdd), $locationID)
			. CGI::br()
			if (@noAdd);
		$badMsg .= $r->maketext(
			"Address(es) [_1] is(are) not in a recognized form.  Please check your data entry and try again.",
			$badAddr)
			. CGI::br()
			if ($badAddr);
		$badMsg .=
			$r->maketext('Address(es) [_1] in the delete list is(are) not in the location [_2], and so were skipped.',
				join(', ', @noDel), $locationID)
			if (@noDel);

		print CGI::div({ class => 'alert alert-danger p-1 mb-2' }, $badMsg)
			if ($badMsg);
		if ($doneMsg || $addrMsg) {
			print CGI::div({ -class => 'alert alert-danger p-1 mb-2' }, CGI::p({}, $doneMsg, $addrMsg));
		} else {
			print CGI::div({ -class => 'alert alert-danger p-1 mb-2' },
				$r->maketext("No valid changes submitted for location [_1].", $locationID));
		}

		$self->edit_location_form;
	}
}

sub hide_inactive_course_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my $coursesDir          = $ce->{webworkDirs}->{courses};
	my @courseIDs           = listCourses($ce);
	my $hide_listing_format = $r->param('hide_listing_format') // 'last_login';

	# Get and store last modify time for login.log for all courses. Also get visibility status.
	my %courseLabels;
	my @noLoginLogIDs;
	my @loginLogIDs;
	my @hideCourseIDs;
	my ($loginLogFile, $epoch_modify_time, $courseDir);
	for my $courseID (@courseIDs) {
		$loginLogFile = "$coursesDir/$courseID/logs/login.log";
		if (-e $loginLogFile) {    #this should always exist except for the model course
			$epoch_modify_time                           = stat($loginLogFile)->mtime;
			$coursesData{$courseID}{'epoch_modify_time'} = $epoch_modify_time;
			$coursesData{$courseID}{'local_modify_time'} = ctime($epoch_modify_time);
			push(@loginLogIDs, $courseID);
		} else {
			$coursesData{$courseID}{'local_modify_time'} =
				'no login.log';    #this should never be the case except for the model course
			push(@noLoginLogIDs, $courseID);
		}
		if (-f "$coursesDir/$courseID/hide_directory") {
			$coursesData{$courseID}{'status'} = $r->maketext('hidden');
		} else {
			$coursesData{$courseID}{'status'} = $r->maketext('visible');
		}
		$courseLabels{$courseID} =
			"$courseID  ($coursesData{$courseID}{'status'} :: $coursesData{$courseID}{'local_modify_time'})";
	}
	if ($hide_listing_format eq 'last_login') {
		# This should be an empty arrey except for the model course.
		@noLoginLogIDs = sort { lc($a) cmp lc($b) } @noLoginLogIDs;
		@loginLogIDs   = sort byLoginActivity @loginLogIDs;           # oldest first
		@hideCourseIDs = (@noLoginLogIDs, @loginLogIDs);
	} else {
		# In this case we sort alphabetically
		@hideCourseIDs = sort { lc($a) cmp lc($b) } @courseIDs;
	}

	print CGI::h2($r->maketext('Hide Courses'));

	print CGI::p($r->maketext(
		'Select the course(s) you want to hide (or unhide) and then click "Hide Courses" (or "Unhide Courses"). '
			. 'Hiding a course that is already hidden does no harm (the action is skipped). Likewise unhiding a '
			. 'course that is already visible does no harm (the action is skipped).  Hidden courses are still active '
			. 'but are not listed in the list of WeBWorK courses on the opening page.  To access the course, an '
			. 'instructor or student must know the full URL address for the course.'
	));

	print CGI::p($r->maketext(
		'Courses are listed either alphabetically or in order by the time of most recent login activity, '
			. 'oldest first. To change the listing order check the mode you want and click "Refresh Listing".  '
			. 'The listing format is: Course_Name (status :: date/time of most recent login) where status is "hidden" '
			. 'or "visible".'
	));

	print CGI::start_form(-method => 'POST', -action => $r->uri);

	print CGI::div(
		{ class => 'mb-3' },
		CGI::div({ class => 'mb-2' }, $r->maketext('Select a listing format:')),
		map {
			CGI::div(
				{ class => 'form-check' },
				CGI::input({
					type  => 'radio',
					name  => 'hide_listing_format',
					id    => "hide_listing_format_$_->[0]",
					value => $_->[0],
					class => 'form-check-input',
					$_->[0] eq ($r->param('hide_listing_format') // 'alphabetically') ? (checked => undef) : ()
				}),
				CGI::label(
					{
						for   => "hide_listing_format_$_->[0]",
						class => 'form-check-label'
					},
					$_->[1]
				)
			)
		} (
			[ alphabetically => $r->maketext('alphabetically') ],
			[ last_login     => $r->maketext('by last login date') ]
		),
	);

	print CGI::div(
		{ class => 'mb-2' },
		CGI::submit({
			name  => 'hide_course_refresh',
			value => $r->maketext('Refresh Listing'),
			class => 'btn btn-primary'
		}),
		CGI::submit({
			name  => 'hide_course',
			value => $r->maketext('Hide Courses'),
			class => 'btn btn-primary'
		}),
		CGI::submit({
			name  => 'unhide_course',
			value => $r->maketext('Unhide Courses'),
			class => 'btn btn-primary'
		})
	);

	print $self->hidden_authen_fields;
	print $self->hidden_fields('subDisplay');

	print CGI::div({ class => 'mb-2' }, $r->maketext('Select course(s) to hide or unhide.'));
	print CGI::div(
		{ class => 'row mb-2' },
		CGI::label(
			{ for => 'hide_courseIDs', class => 'col-auto col-form-label fw-bold' },
			$r->maketext('Course Name:')
		),
		CGI::div(
			{ class => 'col-auto' },
			CGI::scrolling_list({
				name     => 'hide_courseIDs',
				id       => 'hide_courseIDs',
				values   => \@hideCourseIDs,
				size     => 15,
				multiple => 1,
				labels   => \%courseLabels,
				class    => 'form-select'
			})
		)
	);

	print CGI::div(
		CGI::submit({
			name  => 'hide_course_refresh',
			value => $r->maketext('Refresh Listing'),
			class => 'btn btn-primary'
		}),
		CGI::submit({
			name  => 'hide_course',
			value => $r->maketext('Hide Courses'),
			class => 'btn btn-primary'
		}),
		CGI::submit({
			name  => 'unhide_course',
			value => $r->maketext('Unhide Courses'),
			class => 'btn btn-primary'
		})
	);

	print CGI::end_form();
}

sub hide_course_validate {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	my @hide_courseIDs = $r->param("hide_courseIDs");
	@hide_courseIDs = () unless @hide_courseIDs;

	my @errors;

	unless (@hide_courseIDs) {
		push @errors, $r->maketext("You must specify a course name.");
	}
	return @errors;
}

sub do_hide_inactive_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my $coursesDir = $ce->{webworkDirs}->{courses};

	my $hide_courseID;
	my @hide_courseIDs = $r->param("hide_courseIDs");
	@hide_courseIDs = () unless @hide_courseIDs;

	my $hideDirFileContent = $r->maketext(
		'Place a file named "hide_directory" in a course or other directory and it will not show up in the courses list on the WeBWorK home page. It will still appear in the Course Administration listing.'
	);

	my @succeeded_courses    = ();
	my $succeeded_count      = 0;
	my @failed_courses       = ();
	my $already_hidden_count = 0;

	foreach $hide_courseID (@hide_courseIDs) {
		my $hideDirFile = "$coursesDir/$hide_courseID/hide_directory";
		if (-f $hideDirFile) {
			$already_hidden_count++;
			next;
		} else {
			local *HIDEFILE;
			if (open(HIDEFILE, ">", $hideDirFile)) {
				print HIDEFILE "$hideDirFileContent";
				close HIDEFILE;
				push @succeeded_courses, $hide_courseID;
				$succeeded_count++;
			} else {
				push @failed_courses, $hide_courseID;
			}
		}
	}

	if (@failed_courses) {
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			CGI::p($r->maketext(
				"Errors occured while hiding the courses listed below when attempting to create the file hide_directory in the course's directory. Check the ownership and permissions of the course's directory, e.g [_1]",
				"$coursesDir/$failed_courses[0]/"
			)),
			join(CGI::br(), @failed_courses)
		);
	}
	my $succeeded_message = '';

	if ($succeeded_count < 1 and $already_hidden_count > 0) {
		$succeeded_message =
			$r->maketext("Except for possible errors listed above, all selected courses are already hidden.");
	}

	if ($succeeded_count) {
		$succeeded_message = CGI::p($r->maketext("The following courses were successfully hidden:"))
			. join(CGI::br(), @succeeded_courses);
	}
	if ($succeeded_count or $already_hidden_count) {
		print CGI::div({ class => 'alert alert-success p-1 mb-2' }, $succeeded_message);
	}
}

sub unhide_course_validate {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	#my $db = $r->db;
	#my $authz = $r->authz;
	my $urlpath = $r->urlpath;

	my @unhide_courseIDs = $r->param("hide_courseIDs");
	@unhide_courseIDs = () unless @unhide_courseIDs;

	my @errors;

	unless (@unhide_courseIDs) {
		push @errors, $r->maketext("You must specify a course name.");
	}
	return @errors;
}

sub do_unhide_inactive_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my $coursesDir = $ce->{webworkDirs}->{courses};

	my $unhide_courseID;
	my @unhide_courseIDs = $r->param("hide_courseIDs");
	@unhide_courseIDs = () unless @unhide_courseIDs;

	my @succeeded_courses     = ();
	my $succeeded_count       = 0;
	my @failed_courses        = ();
	my $already_visible_count = 0;

	foreach $unhide_courseID (@unhide_courseIDs) {
		my $hideDirFile = "$coursesDir/$unhide_courseID/hide_directory";
		unless (-f $hideDirFile) {
			$already_visible_count++;
			next;
		}
		remove_tree("$hideDirFile", { error => \my $err });
		if (@$err) {
			push @failed_courses, $unhide_courseID;
		} else {
			push @succeeded_courses, $unhide_courseID;
			$succeeded_count++;
		}
	}
	my $succeeded_message = '';

	if ($succeeded_count < 1 and $already_visible_count > 0) {
		$succeeded_message =
			$r->maketext("Except for possible errors listed above, all selected courses are already unhidden.");
	}

	if ($succeeded_count) {
		$succeeded_message = CGI::p($r->maketext("The following courses were successfully unhidden:"))
			. join(CGI::br(), @succeeded_courses);
	}
	if ($succeeded_count or $already_visible_count) {
		print CGI::div({ class => 'alert alert-success p-1 mb-2' }, $succeeded_message);
	}
	if (@failed_courses) {
		print CGI::div(
			{ class => 'alert alert-danger p-1 mb-2' },
			CGI::p($r->maketext(
				"Errors occured while unhiding the courses listed below when attempting delete the file hide_directory in the course's directory. Check the ownership and permissions of the course's directory, e.g [_1]",
				"$coursesDir/$failed_courses[0]/"
			)),
			join(CGI::br(), @failed_courses)
		);
	}
}

sub upgrade_notification {
	my $self = shift;
	my $r    = $self->r;
	my $ce   = $r->ce;
	my $db   = $r->db;

	# exit if notifications are disabled
	return unless $ce->{enableGitUpgradeNotifier};

	my $git           = $ce->{externalPrograms}->{git};
	my $WeBWorKRemote = $ce->{gitWeBWorKRemoteName};
	my $WeBWorKBranch = $ce->{gitWeBWorKBranchName};
	my $PGRemote      = $ce->{gitPGRemoteName};
	my $PGBranch      = $ce->{gitPGBranchName};
	my $LibraryRemote = $ce->{gitLibraryRemoteName};
	my $LibraryBranch = $ce->{gitLibraryBranchName};

	# we can tproceed unless we have git;
	if (!(defined($git) && -x $git)) {
		warn('External Program "git" not found.  Check your site.conf');
		return;
	}

	my $upgradeMessage    = '';
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
		@lines  = split /\n/, $output;
		$commit = -1;

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
			@lines  = split /\n/, $output;
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
				$upgradeMessage .= CGI::Tr(CGI::td($r->maketext(
					'There are upgrades available for your current branch of WeBWorK from branch [_1] in remote [_2].',
					$WeBWorKBranch,
					$WeBWorKRemote
				)));
			}
		} elsif ($commit eq '-1') {
			$upgradesAvailable = 1;
			$upgradeMessage .= CGI::Tr(CGI::td($r->maketext(
				"Couldn't find WeBWorK Branch [_1] in remote [_2]", $WeBWorKBranch, $WeBWorKRemote)));
		} else {
			$upgradeMessage .= CGI::Tr(CGI::td($r->maketext(
				'Your current branch of WeBWorK is up to date with branch [_1] in remote [_2].', $WeBWorKBranch,
				$WeBWorKRemote
			)));
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
		@lines  = split /\n/, $output;
		$commit = '-1';

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
			@lines  = split /\n/, $output;
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
				$upgradeMessage .= CGI::Tr(CGI::td($r->maketext(
					'There are upgrades available for your current branch of PG from branch [_1] in remote [_2].',
					$PGBranch, $PGRemote
				)));
			}
		} elsif ($commit eq '-1') {
			$upgradesAvailable = 1;
			$upgradeMessage .=
				CGI::Tr(CGI::td($r->maketext("Couldn't find PG Branch [_1] in remote [_2]", $PGBranch, $PGRemote)));
		} else {
			$upgradeMessage .= CGI::Tr(CGI::td($r->maketext(
				'Your current branch of PG is up to date with branch [_1] in remote [_2].',
				$PGBranch, $PGRemote
			)));

		}
	}

	die "Couldn't find "
		. $ce->{problemLibrary}{root}
		. '.  Are you sure $problemLibrary{root} is set correctly in localOverrides.conf?'
		unless chdir($ce->{problemLibrary}{root});

	if ($LibraryRemote && $LibraryBranch) {
		# Check if there is an updated version of the OPL available
		# this is done by using ls-remote to get the commit sha at the
		# head of the remote branch and looking to see if that sha is in
		# the local current branch
		my $currentBranch = `$git symbolic-ref --short HEAD`;
		$output = `$git ls-remote --heads $LibraryRemote`;
		@lines  = split /\n/, $output;
		$commit = '-1';

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
			$upgradeMessage .=
				CGI::Tr(CGI::td($r->maketext('There are upgrades available for the Open Problem Library.')));
		} elsif ($commit eq '-1') {
			$upgradesAvailable = 1;
			$upgradeMessage .= CGI::Tr(
				CGI::td($r->maketext(
					"Couldn't find OPL Branch [_1] in remote [_2]", $LibraryBranch, $LibraryRemote)));
		} else {
			$upgradeMessage .= CGI::Tr(CGI::td($r->maketext(
				'Your current branch of the Open Problem Library is up to date.',
				$LibraryBranch, $LibraryRemote
			)));
		}
	}

	chdir($ce->{webwork_dir});

	if ($upgradesAvailable) {
		$upgradeMessage =
			CGI::Tr(CGI::th($r->maketext('The following upgrades are available for your WeBWorK system:')))
			. $upgradeMessage;
		return CGI::center(CGI::table({ class => "admin-messagebox" }, $upgradeMessage));
	} else {
		return CGI::center(CGI::div(
			{ class => 'alert alert-success p-1 mb-2' }, $r->maketext('Your systems are up to date!')));
	}

}

################################################################################
#   registration forms added by Mike Gage 5-5-2008
################################################################################

our $registered_file_name = "registered_???";

sub display_registration_form {
	my $self       = shift;
	my $ce         = $self->r->ce;
	my $ww_version = $ce->{WW_VERSION};
	$registered_file_name = "registered_$ww_version";
	my $registeredQ = (-e "$ce->{courseDirs}{root}/$registered_file_name") ? 1 : 0;
	my $registration_subDisplay =
		(defined($self->r->param('subDisplay')) && $self->r->param('subDisplay') eq 'registration') ? 1 : 0;
	my $register_site = ($self->r->param('register_site')) ? 1 : 0;

	return CGI::div({ class => 'd-flex justify-content-center' }, "REGISTERED for WeBWorK $ww_version")
		if $registeredQ || $register_site || $registration_subDisplay;

	# Otherwise return registration form.
	return CGI::div(
		{ class => 'd-flex justify-content-center' },
		CGI::div(
			{ class => 'admin-messagebox' },

			CGI::p(
				CGI::strong('Please consider registering for the WW-security-announce Google group / mailing list'),
				' using the join group link on the ',
				CGI::a({ href => $ce->{webworkURLs}{wwSecurityAnnounce}, target => '_blank' }, 'group page'),
				' which appears when you are logged in to a Google account ',
				CGI::strong('or'),
				' by sending an email using ',
				CGI::a(
					{
						href => join('',
							"mailto:$ce->{webworkSecListManagers}?subject=",
							uri_escape('Joining ww-security-announce'),
							'&body=',
							uri_escape("Server URL: $ce->{apache_root_url}\n"),
							uri_escape("WeBWorK version: $ce->{WW_VERSION}\n"),
							uri_escape("Institution name: \n"))
					},
					,
					'this mailto link'
				),
				'. This list will help us keep you updated about security issues and patches, '
					. 'and important related announcements.'
			),

			CGI::hr(),

			CGI::p(
				'Please consider contributing to WeBWorK development either with a one time contribution or monthly ',
				'support. The WeBWorK Project is a registered 501(c)(3) organization and contributions are tax ',
				'deductible in the United States.'
			),
			CGI::div(
				{ class => 'text-center' },
				CGI::a(
					{
						class  => 'btn btn-secondary',
						href   => 'https://github.com/sponsors/openwebwork',
						target => '_blank'
					},
					CGI::i({ class => 'fa-regular fa-heart' }, '') . ' Sponsor',
				)
			),

			CGI::hr(),

			CGI::p("This site is not registered for WeBWorK version $ww_version."),
			CGI::p(
				'We are often asked how many institutions are using WeBWorK and how many students are using WeBWorK. ',
				'Since WeBWorK is open source and can be freely downloaded from ',
				CGI::a({ href => $ce->{webworkURLs}{GitHub}, target => '_blank' }, $ce->{webworkURLs}{GitHub}),
				', it is frequently difficult for us to give a reasonable answer to this question.'
			),
			CGI::p(
				'You can help by ',
				CGI::a(
					{ href => $ce->{webworkURLs}{serverRegForm}, target => '_blank' },
					'registering your current version of WeBWorK'
				),
				'. Please complete the Google form as best you can and submit your answers ',
				'to the WeBWorK Project team. It takes just 2-3 minutes.  Thank you! -- The WeBWorK Project'
			),
			CGI::p(
				'Eventually your site will be listed along with all of the others on the ',
				CGI::a({ href => $ce->{webworkURLs}{SiteMap}, target => '_blank' }, 'site map'),
				' on the main ',
				CGI::a({ href => $ce->{webworkURLs}{WikiMain}, target => '_blank' }, 'WeBWorK Wiki'),
				'.',
			),

			CGI::hr(),

			CGI::p('You can hide this "registration" banner for the future by clicking the button below.'),
			CGI::start_form({ method => 'POST', id => 'return_to_main_page', action => $self->r->uri }),
			$self->hidden_authen_fields,
			CGI::hidden({ name => 'subDisplay', value => 'registration' }),
			CGI::div(
				{ class => 'text-center' },
				CGI::submit({
					id    => 'register_site',
					name  => 'register_site',
					label => 'Hide the banner.',
					class => 'btn btn-primary'
				})
			),
			CGI::end_form()
		)
	);
}

sub registration_form {
}

sub do_registration {
	my $self                 = shift;
	my $ce                   = $self->r->ce;
	my $registered_file_path = $ce->{courseDirs}->{root} . "/$registered_file_name";
	# warn qq!`echo "info" >$registered_file_path`!;
	`echo "info" >$registered_file_path`;

	print "\n<center>",
		CGI::p(
			{ style => "text-align: left; width:60%" },
			q{Registration banner has been hidden. We appreciate your registering your server with the WeBWorK Project!"}
		);

	print CGI::start_form(-method => "POST", -action => $self->r->uri);
	print $self->hidden_authen_fields;
	print CGI::p(
		{ style => "text-align: center" },
		CGI::submit({
			name  => "registration_completed",
			label => "Continue",
			class => 'btn btn-primary'
		})
	);
	print CGI::end_form();
	print "</center>";

}

# Format a list of tables and fields in the database, and the status of each.
sub formatReportOnDatabaseTables {
	my ($self, $tables_ok, $dbStatus, $courseID) = @_;
	my $r = $self->r;

	my %msg = (
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A =>
			CGI::span({ class => 'text-danger' }, $r->maketext('Table defined in schema but missing in database')),
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B =>
			CGI::span({ class => 'text-danger me-2' }, $r->maketext('Table defined in database but missing in schema')),
		WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B =>
			CGI::span({ class => 'text-success' }, $r->maketext('Table is ok')),
		WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B =>
			CGI::span({ class => 'text-danger' }, $r->maketext('Schema and database table definitions do not agree')),
	);
	my %msg2 = (
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A =>
			CGI::span({ class => 'text-danger' }, $r->maketext('Field missing in database')),
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B =>
			CGI::span({ class => 'text-danger me-2' }, $r->maketext('Field missing in schema')),
		WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B =>
			CGI::span({ class => 'text-success' }, $r->maketext('Field is ok')),
		WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B =>
			CGI::span({ class => 'text-danger' }, $r->maketext('Schema and database field definitions do not agree')),
	);
	my $all_tables_ok         = 1;
	my $extra_database_tables = 0;
	my $extra_database_fields = 0;

	my $str = CGI::start_ul();
	for my $table (sort keys %$dbStatus) {
		my $table_status = $dbStatus->{$table}[0];
		$str .= CGI::start_li();
		$str .= CGI::b($table) . ': ' . $msg{$table_status};

		if ($table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A) {
			$all_tables_ok = 0;
		} elsif ($table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B) {
			$extra_database_tables = 1;
			$str .= CGI::span(
				{ class => 'form-check d-inline-block' },
				CGI::checkbox({
					name            => "$courseID.delete_tableIDs",
					value           => $table,
					label           => $r->maketext('Delete table when upgrading'),
					class           => 'form-check-input',
					labelattributes => { class => 'form-check-label' }
				})
			) if defined $courseID;
		} elsif ($table_status == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B) {
			my %fieldInfo = %{ $dbStatus->{$table}->[1] };
			$str .= CGI::start_ul();

			for my $key (keys %fieldInfo) {
				my $field_status = $fieldInfo{$key}->[0];
				$str .= CGI::start_li();
				$str .= "$key => $msg2{$field_status}";

				if ($field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B) {
					$extra_database_fields = 1;
					$str .= CGI::span(
						{ class => 'form-check d-inline-block' },
						CGI::checkbox({
							name            => "$courseID.$table.delete_fieldIDs",
							value           => $key,
							label           => $r->maketext('Delete field when upgrading'),
							class           => 'form-check-input',
							labelattributes => { class => 'form-check-label' }
						})
					) if defined $courseID;
				} elsif ($field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A) {
					$all_tables_ok = 0;
				}
				$str .= CGI::end_li();
			}
			$str .= CGI::end_ul();
		}
		$str .= CGI::end_li();
	}
	$str .= CGI::end_ul();

	$str .= $all_tables_ok ? CGI::p({ class => 'text-success' }, $r->maketext('Database tables are ok')) : '';

	return ($all_tables_ok, $extra_database_tables, $extra_database_fields, $str);
}

sub output_JS {
	my $self = shift;
	my $ce   = $self->r->ce;

	print CGI::script({ src => getAssetURL($ce, 'js/apps/SelectAll/selectall.js'), defer => undef }, '');

	return '';
}

1;
