################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::CourseAdmin - Add, rename, and delete courses.

=cut

use Net::IP;    # needed for location management
use File::Path 'remove_tree';
use Mojo::File;
use File::stat;
use Time::localtime;

use WeBWorK::CourseEnvironment;
use WeBWorK::Debug;
use WeBWorK::Utils qw(cryptPassword trim_spaces);
use WeBWorK::Utils::CourseIntegrityCheck;
use WeBWorK::Utils::CourseManagement qw(addCourse renameCourse retitleCourse deleteCourse listCourses archiveCourse
	unarchiveCourse initNonNativeTables);
use WeBWorK::Utils::Logs qw(writeLog);
use WeBWorK::DB;

sub pre_header_initialize ($c) {
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;
	my $user  = $c->param('user');

	return unless $authz->hasPermissions($user, 'create_and_delete_courses');

	# Check that the non-native tables are present in the database.
	# These are the tables which are not course specific.
	my @table_update_messages = initNonNativeTables($ce, $ce->{dbLayoutName});
	$c->addgoodmessage($c->c(@table_update_messages)->join($c->tag('br'))) if @table_update_messages;

	my @errors;
	my $method_to_call;

	my $subDisplay = $c->param('subDisplay');
	if (defined $subDisplay) {
		if ($subDisplay eq 'add_course') {
			if (defined $c->param('add_course')) {
				@errors = $c->add_course_validate;
				if (@errors) {
					$method_to_call = 'add_course_form';
				} else {
					$method_to_call = 'do_add_course';
				}
			} else {
				$method_to_call = 'add_course_form';
			}
		} elsif ($subDisplay eq 'rename_course') {
			if (defined $c->param('rename_course')) {
				@errors = $c->rename_course_validate;
				if (@errors) {
					$method_to_call = 'rename_course_form';
				} else {
					$method_to_call = 'rename_course_confirm';
				}
			} elsif (defined $c->param('confirm_rename_course')) {
				@errors = $c->rename_course_validate;
				if (@errors) {
					$method_to_call = 'rename_course_form';
				} else {
					$method_to_call = 'do_rename_course';
				}
			} elsif (defined $c->param('confirm_retitle_course')) {
				$method_to_call = 'do_retitle_course';
			} elsif (defined $c->param('upgrade_course_tables')) {
				@errors = $c->rename_course_validate;
				if (@errors) {
					$method_to_call = 'rename_course_form';
				} else {
					$method_to_call = 'rename_course_confirm';
				}
			} else {
				$method_to_call = 'rename_course_form';
			}
		} elsif ($subDisplay eq 'delete_course') {
			if (defined $c->param('delete_course')) {
				@errors = $c->delete_course_validate;
				if (@errors) {
					$method_to_call = 'delete_course_form';
				} else {
					$method_to_call = 'delete_course_confirm';
				}
			} elsif (defined $c->param('confirm_delete_course')) {
				@errors = $c->delete_course_validate;
				if (@errors) {
					$method_to_call = 'delete_course_form';
				} else {
					$method_to_call = 'do_delete_course';
				}
			} elsif (defined($c->param('delete_course_refresh'))) {
				$method_to_call = 'delete_course_form';
			} else {
				$method_to_call = 'delete_course_form';
			}
		} elsif ($subDisplay eq 'archive_course') {
			if (defined $c->param('archive_course') || defined $c->param('skip_archive_course')) {
				@errors = $c->archive_course_validate;
				if (@errors) {
					$method_to_call = 'archive_course_form';
				} else {
					$method_to_call = 'archive_course_confirm';
				}
			} elsif (defined $c->param('confirm_archive_course')) {
				@errors = $c->archive_course_validate;
				if (@errors) {
					$method_to_call = 'archive_course_form';
				} else {
					$method_to_call = 'do_archive_course';
				}
			} elsif (defined $c->param('upgrade_course_tables')) {
				@errors = $c->archive_course_validate;
				if (@errors) {
					$method_to_call = 'archive_course_form';
				} else {
					$method_to_call = 'archive_course_confirm';
				}
			} elsif (defined($c->param('archive_course_refresh'))) {
				$method_to_call = 'archive_course_form';
			} else {
				$method_to_call = 'archive_course_form';
			}
		} elsif ($subDisplay eq 'unarchive_course') {
			if (defined $c->param('unarchive_course')) {
				@errors = $c->unarchive_course_validate;
				if (@errors) {
					$method_to_call = 'unarchive_course_form';
				} else {
					$method_to_call = 'unarchive_course_confirm';
				}
			} elsif (defined $c->param('confirm_unarchive_course')) {
				@errors = $c->unarchive_course_validate;
				if (@errors) {
					$method_to_call = 'unarchive_course_form';
				} else {
					$method_to_call = 'do_unarchive_course';
				}
			} else {
				$method_to_call = 'unarchive_course_form';
			}
		} elsif ($subDisplay eq 'upgrade_course') {
			if (defined $c->param('upgrade_course')) {
				@errors = $c->upgrade_course_validate;
				if (@errors) {
					$method_to_call = 'upgrade_course_form';
				} else {
					$method_to_call = 'upgrade_course_confirm';
				}
			} elsif (defined $c->param('confirm_upgrade_course')) {
				@errors = $c->upgrade_course_validate;
				if (@errors) {
					$method_to_call = 'upgrade_course_form';
				} else {
					$method_to_call = 'do_upgrade_course';
				}
			} else {
				$method_to_call = 'upgrade_course_form';
			}
		} elsif ($subDisplay eq 'manage_locations') {
			if (defined($c->param('manage_location_action'))) {
				$method_to_call = $c->param('manage_location_action');
			} else {
				$method_to_call = 'manage_location_form';
			}
		} elsif ($subDisplay eq 'hide_inactive_course') {
			if (defined($c->param('hide_course'))) {
				@errors = $c->hide_course_validate;
				if (@errors) {
					$method_to_call = 'hide_inactive_course_form';
				} else {
					$method_to_call = 'do_hide_inactive_course';
				}
			} elsif (defined($c->param('unhide_course'))) {
				@errors = $c->unhide_course_validate;
				if (@errors) {
					$method_to_call = 'hide_inactive_course_form';
				} else {
					$method_to_call = 'do_unhide_inactive_course';
				}
			} elsif (defined($c->param('hide_course_refresh'))) {
				$method_to_call = 'hide_inactive_course_form';
			} else {
				$method_to_call = 'hide_inactive_course_form';
			}
		} elsif ($subDisplay eq 'manage_lti_course_map') {
			if (defined $c->param('save_lti_course_map')) {
				@errors = $c->save_lti_course_map_validate;
				if (@errors) {
					$method_to_call = 'manage_lti_course_map_form';
				} else {
					$method_to_call = 'do_save_lti_course_map';
				}
			} else {
				$method_to_call = 'manage_lti_course_map_form';
			}
		} elsif ($subDisplay eq 'manage_otp_secrets') {
			if (defined $c->param('take_action')) {
				if ($c->param('action') eq 'reset') {
					$method_to_call = 'reset_otp_secrets_confirm';
				} else {
					$method_to_call = 'copy_otp_secrets_confirm';
				}
			} else {
				$method_to_call = 'manage_otp_secrets_form';
			}
		} elsif ($subDisplay eq 'registration') {
			if (defined($c->param('register_site'))) {
				$method_to_call = 'do_registration';
			}
		} else {
			@errors = "Unrecognized sub-display @{[ $c->tag('b', $subDisplay) ]}.";
		}
	}

	$c->{errors}         = \@errors;
	$c->{method_to_call} = $method_to_call;

	return;
}

sub add_course_form ($c) {
	return $c->include('ContentGenerator/CourseAdmin/add_course_form');
}

sub add_course_validate ($c) {
	my $ce = $c->ce;

	my $add_courseID                = trim_spaces($c->param('new_courseID'))                || '';
	my $add_initial_userID          = trim_spaces($c->param('add_initial_userID'))          || '';
	my $add_initial_password        = trim_spaces($c->param('add_initial_password'))        || '';
	my $add_initial_confirmPassword = trim_spaces($c->param('add_initial_confirmPassword')) || '';
	my $add_initial_firstName       = trim_spaces($c->param('add_initial_firstName'))       || '';
	my $add_initial_lastName        = trim_spaces($c->param('add_initial_lastName'))        || '';
	my $add_initial_email           = trim_spaces($c->param('add_initial_email'))           || '';
	my $add_dbLayout                = trim_spaces($c->param('add_dbLayout'))                || '';

	my @errors;

	if ($add_courseID eq '') {
		push @errors, $c->maketext('You must specify a course ID.');
	}
	unless ($add_courseID =~ /^[\w-]*$/) {    # regex copied from CourseAdministration.pm
		push @errors, $c->maketext('Course ID may only contain letters, numbers, hyphens, and underscores.');
	}
	if (grep { $add_courseID eq $_ } listCourses($ce)) {
		push @errors, $c->maketext('A course with ID [_1] already exists.', $add_courseID);
	}
	if (length($add_courseID) > $ce->{maxCourseIdLength}) {
		push @errors, $c->maketext('Course ID cannot exceed [_1] characters.', $ce->{maxCourseIdLength});
	}

	if ($add_initial_userID ne '') {
		if ($add_initial_password eq '') {
			push @errors, $c->maketext('You must specify a password for the initial instructor.');
		}
		if ($add_initial_confirmPassword eq '') {
			push @errors, $c->maketext('You must confirm the password for the initial instructor.');
		}
		if ($add_initial_password ne $add_initial_confirmPassword) {
			push @errors, $c->maketext('The password and password confirmation for the instructor must match.');
		}
		if ($add_initial_firstName eq '') {
			push @errors, $c->maketext('You must specify a first name for the initial instructor.');
		}
		if ($add_initial_lastName eq '') {
			push @errors, $c->maketext('You must specify a last name for the initial instructor.');
		}
		if ($add_initial_email eq '') {
			push @errors, $c->maketext('You must specify an email address for the initial instructor.');
		}
	}

	if ($add_dbLayout eq '') {
		push @errors, 'You must select a database layout.';
	} else {
		if (exists $ce->{dbLayouts}{$add_dbLayout}) {
			# we used to check for layout-specific fields here, but there aren't any layouts that require them
			# anymore. (in the future, we'll probably deal with this in layout-specific modules.)
		} else {
			push @errors, "The database layout $add_dbLayout doesn't exist.";
		}
	}

	return @errors;
}

sub do_add_course ($c) {
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;

	my $add_courseID          = trim_spaces($c->param('new_courseID')) // '';
	my $add_courseTitle       = ($c->param('add_courseTitle')       // '') =~ s/^\s*|\s*$//gr;
	my $add_courseInstitution = ($c->param('add_courseInstitution') // '') =~ s/^\s*|\s\*$//gr;

	my $add_initial_userID          = trim_spaces($c->param('add_initial_userID'))          // '';
	my $add_initial_password        = trim_spaces($c->param('add_initial_password'))        // '';
	my $add_initial_confirmPassword = trim_spaces($c->param('add_initial_confirmPassword')) // '';
	my $add_initial_firstName       = trim_spaces($c->param('add_initial_firstName'))       // '';
	my $add_initial_lastName        = trim_spaces($c->param('add_initial_lastName'))        // '';
	my $add_initial_email           = trim_spaces($c->param('add_initial_email'))           // '';

	my $copy_from_course = trim_spaces($c->param('copy_from_course')) // '';

	my $add_dbLayout = trim_spaces($c->param('add_dbLayout')) || '';

	my $ce2 = WeBWorK::CourseEnvironment->new({ courseName => $add_courseID });

	my %courseOptions = (dbLayoutName => $add_dbLayout);

	my @users;

	# copy users from current (admin) course if desired
	if ($c->param('add_admin_users')) {
		for my $userID ($db->listUsers) {
			if ($userID eq $add_initial_userID) {
				$c->addbadmessage($c->maketext(
					'User "[_1]" will not be copied from [_2] course as it is the initial instructor.', $userID,
					$ce->{admin_course_id}
				));
				next;
			}
			my $PermissionLevel = $db->newPermissionLevel();
			$PermissionLevel->user_id($userID);
			$PermissionLevel->permission($ce->{userRoles}{admin});
			my $User     = $db->getUser($userID);
			my $Password = $db->getPassword($userID);
			$User->status('O');    # Add admin user as an observer.

			push @users, [ $User, $Password, $PermissionLevel ]
				if $authz->hasPermissions($userID, 'create_and_delete_courses');
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
			status        => 'O',
		);
		my $Password = $db->newPassword(
			user_id  => $add_initial_userID,
			password => cryptPassword($add_initial_password),
		);
		my $PermissionLevel = $db->newPermissionLevel(
			user_id    => $add_initial_userID,
			permission => '10',
		);
		push @users, [ $User, $Password, $PermissionLevel ];
	}

	push @{ $courseOptions{PRINT_FILE_NAMES_FOR} }, map { $_->[0]->user_id } @users;

	# Include any optional arguments, including a template course and the course title and course institution.
	my %optional_arguments;
	if ($copy_from_course ne '') {
		%optional_arguments             = map { $_ => 1 } $c->param('copy_component');
		$optional_arguments{copyFrom}   = $copy_from_course;
		$optional_arguments{copyConfig} = $c->param('copy_config_file');
	}
	if ($add_courseTitle ne '') {
		$optional_arguments{courseTitle} = $add_courseTitle;
	}
	if ($add_courseInstitution ne '') {
		$optional_arguments{courseInstitution} = $add_courseInstitution;
	}

	my $output = $c->c;

	eval {
		addCourse(
			courseID       => $add_courseID,
			ce             => $ce2,
			courseOptions  => \%courseOptions,
			users          => \@users,
			initial_userID => $add_initial_userID,
			%optional_arguments,
		);
	};
	if ($@) {
		my $error = $@;
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->c($c->tag('p', "An error occurred while creating the course $add_courseID:"),
					$c->tag('div', class => 'font-monospace', $error))->join('')
			)
		);
		# Get rid of any partially built courses.
		# FIXME: This is too fragile.
		unless ($error =~ /course exists/) {
			eval { deleteCourse(courseID => $add_courseID, ce => $ce2); }
		}
	} else {
		#log the action
		writeLog(
			$ce,
			'hosted_courses',
			join("\t",
				"\tAdded",
				(defined $add_courseInstitution ? $add_courseInstitution : '(no institution specified)'),
				(defined $add_courseTitle       ? $add_courseTitle       : '(no title specified)'),
				$add_courseID,
				$add_initial_firstName,
				$add_initial_lastName,
				$add_initial_email,
			)
		);
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$c->maketext('Successfully created the course [_1]', $add_courseID)
			)
		);
		push(
			@$output,
			$c->tag(
				'div',
				class => 'text-center mb-2',
				$c->link_to(
					$c->maketext('Log into [_1]', $add_courseID) => 'set_list' => { courseID => $add_courseID }
				)
			)
		);
	}

	return $output->join('');
}

sub rename_course_form ($c) {
	return $c->include('ContentGenerator/CourseAdmin/rename_course_form');
}

sub rename_course_confirm ($c) {
	my $ce = $c->ce;

	my $rename_oldCourseID          = $c->param('rename_oldCourseID')          || '';
	my $rename_newCourseID          = $c->param('rename_newCourseID')          || '';
	my $rename_newCourseTitle       = $c->param('rename_newCourseTitle')       || '';
	my $rename_newCourseInstitution = $c->param('rename_newCourseInstitution') || '';

	my $ce2 = WeBWorK::CourseEnvironment->new({ courseName => $rename_oldCourseID });

	# Create strings confirming title and institution change.
	# Connect to the database to get old title and institution.
	my $dbLayoutName                = $ce->{dbLayoutName};
	my $db                          = WeBWorK::DB->new($ce->{dbLayouts}{$dbLayoutName});
	my $oldDB                       = WeBWorK::DB->new($ce2->{dbLayouts}{$dbLayoutName});
	my $rename_oldCourseTitle       = $oldDB->getSettingValue('courseTitle')       // '';
	my $rename_oldCourseInstitution = $oldDB->getSettingValue('courseInstitution') // '';

	my ($change_course_title_str, $change_course_institution_str) = ('', '');
	if ($c->param('rename_newCourseTitle_checkbox')) {
		$change_course_title_str =
			$c->maketext('Change title from [_1] to [_2]', $rename_oldCourseTitle, $rename_newCourseTitle);
	}
	if ($c->param('rename_newCourseInstitution_checkbox')) {
		$change_course_institution_str = $c->maketext('Change course institution from [_1] to [_2]',
			$rename_oldCourseInstitution, $rename_newCourseInstitution);
	}

	# If we are only changing the title or institution, and not the courseID, then we can cut this short.
	return $c->include(
		'ContentGenerator/CourseAdmin/rename_course_confirm_short',
		rename_oldCourseTitle         => $rename_oldCourseTitle,
		change_course_title_str       => $change_course_title_str,
		rename_oldCourseInstitution   => $rename_oldCourseInstitution,
		change_course_institution_str => $change_course_institution_str,
		rename_oldCourseID            => $rename_oldCourseID
	) unless $c->param('rename_newCourseID_checkbox');

	if ($ce2->{dbLayoutName}) {
		my $CIchecker = WeBWorK::Utils::CourseIntegrityCheck->new(ce => $ce2);

		# Check database
		my ($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($rename_oldCourseID);

		# Upgrade the database if requested.
		my @upgrade_report;
		if ($c->param('upgrade_course_tables')) {
			my @schema_table_names = keys %$dbStatus;
			my @tables_to_create =
				grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A } @schema_table_names;
			my @tables_to_alter =
				grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B }
				@schema_table_names;
			push(@upgrade_report, $CIchecker->updateCourseTables($rename_oldCourseID, [@tables_to_create]));
			for my $table_name (@tables_to_alter) {
				push(@upgrade_report, $CIchecker->updateTableFields($rename_oldCourseID, $table_name));
			}

			($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($rename_oldCourseID);
		}

		# Check directories
		my ($directories_ok, $directory_report) = $CIchecker->checkCourseDirectories($ce2);

		return $c->include(
			'ContentGenerator/CourseAdmin/rename_course_confirm',
			upgrade_report                => \@upgrade_report,
			tables_ok                     => $tables_ok,
			dbStatus                      => $dbStatus,
			directory_report              => $directory_report,
			directories_ok                => $directories_ok,
			rename_oldCourseTitle         => $rename_oldCourseTitle,
			change_course_title_str       => $change_course_title_str,
			rename_oldCourseInstitution   => $rename_oldCourseInstitution,
			change_course_institution_str => $change_course_institution_str,
			rename_oldCourseID            => $rename_oldCourseID,
			rename_newCourseID            => $rename_newCourseID
		);
	} else {
		return $c->tag('p', class => 'text-danger fw-bold', "Unable to find database layout for $rename_oldCourseID");
	}
}

sub rename_course_validate ($c) {
	my $ce = $c->ce;

	my $rename_oldCourseID          = $c->param('rename_oldCourseID')          || '';
	my $rename_newCourseID          = $c->param('rename_newCourseID')          || '';
	my $rename_newCourseID_checkbox = $c->param('rename_newCourseID_checkbox') || '';

	my $rename_newCourseTitle                = $c->param('rename_newCourseTitle')                || '';
	my $rename_newCourseTitle_checkbox       = $c->param('rename_newCourseTitle_checkbox')       || '';
	my $rename_newCourseInstitution          = $c->param('rename_newCourseInstitution')          || '';
	my $rename_newCourseInstitution_checkbox = $c->param('rename_newCourseInstitution_checkbox') || '';

	my @errors;

	if ($rename_oldCourseID eq '') {
		push @errors, $c->maketext('You must select a course to rename.');
	}
	if ($rename_newCourseID eq '' and $rename_newCourseID_checkbox eq 'on') {
		push @errors, $c->maketext('You must specify a new name for the course.');
	}
	if ($rename_oldCourseID eq $rename_newCourseID and $rename_newCourseID_checkbox eq 'on') {
		push @errors, $c->maketext(q{Can't rename to the same name.});
	}
	if ($rename_newCourseID_checkbox eq 'on' && length($rename_newCourseID) > $ce->{maxCourseIdLength}) {
		push @errors, $c->maketext('Course ID cannot exceed [_1] characters.', $ce->{maxCourseIdLength});
	}
	unless ($rename_newCourseID =~ /^[\w-]*$/) {    # regex copied from CourseAdministration.pm
		push @errors, $c->maketext('Course ID may only contain letters, numbers, hyphens, and underscores.');
	}
	if (grep { $rename_newCourseID eq $_ } listCourses($ce)) {
		push @errors, $c->maketext('A course with ID [_1] already exists.', $rename_newCourseID);
	}
	if ($rename_newCourseTitle eq '' and $rename_newCourseTitle_checkbox eq 'on') {
		push @errors, $c->maketext('You must specify a new title for the course.');
	}
	if ($rename_newCourseInstitution eq '' and $rename_newCourseInstitution_checkbox eq 'on') {
		push @errors, $c->maketext('You must specify a new institution for the course.');
	}
	unless ($rename_newCourseID
		or $rename_newCourseID_checkbox
		or $rename_newCourseTitle_checkbox
		or $rename_newCourseInstitution_checkbox)
	{
		push @errors,
			$c->maketext(
			'No changes specified.  You must mark the checkbox of the item(s) to be changed and enter the change data.'
			);
	}

	return @errors;
}

sub do_retitle_course ($c) {
	my $ce = $c->ce;
	my $db = $c->db;

	my $rename_oldCourseID = $c->param('rename_oldCourseID') || '';

	#   There is no new course, but there are new titles and institutions
	my $rename_newCourseTitle       = $c->param('rename_newCourseTitle')                || '';
	my $rename_newCourseInstitution = $c->param('rename_newCourseInstitution')          || '';
	my $rename_oldCourseTitle       = $c->param('rename_oldCourseTitle')                || '';
	my $rename_oldCourseInstitution = $c->param('rename_oldCourseInstitution')          || '';
	my $title_checkbox              = $c->param('rename_newCourseTitle_checkbox')       || '';
	my $institution_checkbox        = $c->param('rename_newCourseInstitution_checkbox') || '';

	#	$rename_newCourseID = $rename_oldCourseID ;  #since they are the same FIXME
	# define new courseTitle and new courseInstitution
	my %optional_arguments = ();
	$optional_arguments{courseTitle}       = $rename_newCourseTitle       if $title_checkbox;
	$optional_arguments{courseInstitution} = $rename_newCourseInstitution if $institution_checkbox;

	my $ce2;
	eval { $ce2 = WeBWorK::CourseEnvironment->new({ courseName => $rename_oldCourseID }); };
	warn "failed to create environment in do_retitle_course $@" if $@;

	eval { retitleCourse(courseID => $rename_oldCourseID, ce => $ce2, %optional_arguments); };
	if ($@) {
		my $error = $@;
		return $c->tag(
			'div',
			class => 'alert alert-danger p-1 mb-2',
			$c->c(
				$c->tag(
					'p',
					$c->maketext(
						'An error occurred while changing the title of the course [_1].',
						$rename_oldCourseID
					)
				),
				$c->tag('div', class => 'font-monospace', $error)
			)->join('')
		);
	} else {
		writeLog(
			$ce,
			'hosted_courses',
			join(
				"\t", "\t",
				$c->maketext('Retitled'),
				'', '',
				$c->maketext(
					'[_1] title and institution changed from [_2] to [_3] and from [_4] to [_5]',
					$rename_oldCourseID,          $rename_oldCourseTitle, $rename_newCourseTitle,
					$rename_oldCourseInstitution, $rename_newCourseInstitution
				)
			)
		);

		return $c->c(
			$c->tag(
				'div',
				class => 'alert alert-success p-1 my-2',
				$c->c(
					($title_checkbox) ? $c->tag(
						'div',
						$c->maketext(
							'The title of the course [_1] has been changed from [_2] to [_3]',
							$rename_oldCourseID, $rename_oldCourseTitle, $rename_newCourseTitle
						)
					) : '',
					($institution_checkbox) ? $c->tag(
						'div',
						$c->maketext(
							'The institution associated with the course [_1] has been changed from [_2] to [_3]',
							$rename_oldCourseID, $rename_oldCourseInstitution, $rename_newCourseInstitution
						)
					) : ''
				)->join('')
			),
			$c->tag(
				'div',
				class => 'text-center',
				$c->link_to(
					$c->maketext('Log into [_1]', $rename_oldCourseID) => 'set_list' =>
						{ courseID => $rename_oldCourseID }
				)
			)
		)->join('');
	}
}

sub do_rename_course ($c) {
	my $rename_oldCourseID = $c->param('rename_oldCourseID') || '';
	my $rename_newCourseID = $c->param('rename_newCourseID') || '';

	# define new courseTitle and new courseInstitution
	my %optional_arguments = ();
	my ($title_message, $institution_message);
	if ($c->param('rename_newCourseTitle_checkbox')) {
		$optional_arguments{courseTitle} = $c->param('rename_newCourseTitle') || '';
		$title_message = $c->maketext('The title of the course [_1] is now [_2]',
			$rename_newCourseID, $optional_arguments{courseTitle});

	}

	if ($c->param('rename_newCourseInstitution_checkbox')) {
		$optional_arguments{courseInstitution} = $c->param('rename_newCourseInstitution') || '';
		$institution_message = $c->maketext('The institution associated with the course [_1] is now [_2]',
			$rename_newCourseID, $optional_arguments{courseInstitution});
	}

	eval {
		renameCourse(
			courseID    => $rename_oldCourseID,
			ce          => WeBWorK::CourseEnvironment->new({ courseName => $rename_oldCourseID }),
			newCourseID => $rename_newCourseID,
			%optional_arguments
		);
	};
	if ($@) {
		my $error = $@;
		return $c->tag(
			'div',
			class => 'alert alert-danger p-1 mb-2',
			$c->c(
				$c->tag(
					'p',
					$c->maketext(
						'An error occurred while renaming the course [_1] to [_2]:', $rename_oldCourseID,
						$rename_newCourseID
					)
				),
				$c->tag('div', class => 'font-monospace', $error)
			)->join('')
		);
	} else {
		writeLog($c->ce, 'hosted_courses',
			join("\t", "\tRenamed", '', '', "$rename_oldCourseID to $rename_newCourseID"));
		return $c->c(
			$c->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$c->c(
					$title_message       ? $c->tag('p', $title_message)       : '',
					$institution_message ? $c->tag('p', $institution_message) : '',
					$c->tag(
						'p',
						class => 'mb-0',
						$c->maketext(
							'Successfully renamed the course [_1] to [_2]', $rename_oldCourseID,
							$rename_newCourseID
						)
					)
				)->join('')
			),
			$c->tag(
				'div',
				style => 'text-align: center',
				$c->link_to(
					$c->maketext('Log into [_1]', $rename_newCourseID) => 'set_list' =>
						{ courseID => $rename_newCourseID }
				)
			)
		)->join('');
	}
}

sub delete_course_form ($c) {
	my $ce = $c->ce;

	my @courseIDs = grep { $_ ne $c->stash('courseID') } listCourses($ce);
	my %courseLabels;

	if (@courseIDs) {
		my $coursesDir            = $ce->{webworkDirs}{courses};
		my $delete_listing_format = $c->param('delete_listing_format');
		unless (defined $delete_listing_format) { $delete_listing_format = 'alphabetically'; }    # Use the default

		# Get and store last modify time for login.log for all courses. Also get visibility status.
		my @noLoginLogIDs;
		my @loginLogIDs;

		my %coursesData;
		for my $courseID (@courseIDs) {
			my $loginLogFile = "$coursesDir/$courseID/logs/login.log";
			if (-e $loginLogFile) {
				# The login log file should always exist except for the model course.
				my $epoch_modify_time = stat($loginLogFile)->mtime;
				$coursesData{$courseID}{epoch_modify_time} = $epoch_modify_time;
				$coursesData{$courseID}{local_modify_time} = ctime($epoch_modify_time);
				push(@loginLogIDs, $courseID);
			} else {
				# This is for the model course.
				$coursesData{$courseID}{local_modify_time} = 'no login.log';
				push(@noLoginLogIDs, $courseID);
			}
			if (-f "$coursesDir/$courseID/hide_directory") {
				$coursesData{$courseID}{status} = $c->maketext('hidden');
			} else {
				$coursesData{$courseID}{status} = $c->maketext('visible');
			}
			$courseLabels{$courseID} =
				"$courseID  ($coursesData{$courseID}{status} :: $coursesData{$courseID}{local_modify_time}) ";
		}

		if ($delete_listing_format eq 'last_login') {
			# This should be an empty array except for the model course.
			@noLoginLogIDs = sort { lc($a) cmp lc($b) } @noLoginLogIDs;
			@loginLogIDs   = sort { $coursesData{$a}{epoch_modify_time} <=> $coursesData{$b}{epoch_modify_time} }
				@loginLogIDs;    # oldest first
			@courseIDs = (@noLoginLogIDs, @loginLogIDs);
		} else {
			# In this case we sort alphabetically
			@courseIDs = sort { lc($a) cmp lc($b) } @courseIDs;
		}
	}

	return $c->include(
		'ContentGenerator/CourseAdmin/delete_course_form',
		courseIDs    => \@courseIDs,
		courseLabels => \%courseLabels
	);
}

sub delete_course_validate ($c) {
	my @errors;
	if (!$c->param('delete_courseID')) {
		push @errors, $c->maketext('You must specify a course name.');
	} elsif ($c->param('delete_courseID') eq $c->stash('courseID')) {
		push @errors, $c->maketext('You cannot delete the course you are currently using.');
	}

	return @errors;
}

sub delete_course_confirm ($c) {
	return $c->include('ContentGenerator/CourseAdmin/delete_course_confirm');
}

sub do_delete_course ($c) {
	my $ce = $c->ce;
	my $db = $c->db;

	my $delete_courseID = $c->param('delete_courseID') || '';

	eval {
		deleteCourse(
			courseID => $delete_courseID,
			ce       => WeBWorK::CourseEnvironment->new({ courseName => $delete_courseID }),
		);
	};

	if ($@) {
		my $error = $@;
		return $c->tag(
			'div',
			class => 'alert alert-danger p-1 my-2',
			$c->c($c->tag('p', $c->maketext('An error occurred while deleting the course [_1]:', $delete_courseID)),
				$c->tag('div', class => 'font-monospace', $error))->join('')
		);
	} else {
		writeLog($ce, 'hosted_courses', join("\t", "\tDeleted", '', '', $delete_courseID));

		return $c->c(
			$c->tag(
				'div',
				class => 'alert alert-success p-1 my-2',
				$c->maketext('Successfully deleted the course [_1].', $delete_courseID),
			),
			$c->form_for(
				$c->current_route,
				method => 'POST',
				$c->c(
					$c->hidden_authen_fields,
					$c->hidden_fields('subDisplay'),
					$c->tag(
						'div',
						class => 'text-center',
						$c->submit_button(
							$c->maketext('OK'),
							name  => 'decline_delete_course',
							class => 'btn btn-primary'
						)
					)
				)->join('')
			)
		)->join('');
	}
}

sub archive_course_form ($c) {
	my $ce = $c->ce;

	my @courseIDs = grep { $_ ne $c->stash('courseID') } listCourses($ce);
	my %courseLabels;

	if (@courseIDs) {
		# Get and store last modify time for login.log for all courses. Also get visibility status.
		my @noLoginLogIDs;
		my @loginLogIDs;

		my ($loginLogFile, $epoch_modify_time, $courseDir, %coursesData);
		for my $courseID (@courseIDs) {
			$loginLogFile = "$ce->{webworkDirs}{courses}/$courseID/logs/login.log";
			if (-e $loginLogFile) {
				# The login log file should always exist except for the model course.
				$epoch_modify_time                         = stat($loginLogFile)->mtime;
				$coursesData{$courseID}{epoch_modify_time} = $epoch_modify_time;
				$coursesData{$courseID}{local_modify_time} = ctime($epoch_modify_time);
				push(@loginLogIDs, $courseID);
			} else {
				# This is for the model course.
				$coursesData{$courseID}{local_modify_time} = 'no login.log';
				push(@noLoginLogIDs, $courseID);
			}
			if (-f "$ce->{webworkDirs}{courses}/$courseID/hide_directory") {
				$coursesData{$courseID}{status} = $c->maketext('hidden');
			} else {
				$coursesData{$courseID}{status} = $c->maketext('visible');
			}
			$courseLabels{$courseID} =
				"$courseID  ($coursesData{$courseID}{status} :: $coursesData{$courseID}{local_modify_time}) ";
		}
		if (($c->param('archive_listing_format') // 'alphabetically') eq 'last_login') {
			# This should be an empty array except for the model course
			@noLoginLogIDs = sort { lc($a) cmp lc($b) } @noLoginLogIDs;
			@loginLogIDs   = sort { $coursesData{$a}{epoch_modify_time} <=> $coursesData{$b}{epoch_modify_time} }
				@loginLogIDs;    # Oldest first
			@courseIDs = (@noLoginLogIDs, @loginLogIDs);
		} else {
			# in this case we sort alphabetically
			@courseIDs = sort { lc($a) cmp lc($b) } @courseIDs;
		}
	}

	return $c->include(
		'ContentGenerator/CourseAdmin/archive_course_form',
		courseIDs    => \@courseIDs,
		courseLabels => \%courseLabels
	);
}

sub archive_course_validate ($c) {
	my @archive_courseIDs = $c->param('archive_courseIDs');
	my @errors;

	push(@errors, $c->maketext('You must select a course to archive')) unless @archive_courseIDs;

	for my $archive_courseID (@archive_courseIDs) {
		if ($archive_courseID eq '') {
			push @errors, $c->maketext('You must specify a course name.');
		} elsif ($archive_courseID eq $c->stash('courseID')) {
			push @errors, $c->maketext('You cannot archive the course you are currently using.');
		}
	}

	return @errors;
}

sub archive_course_confirm ($c) {
	my $ce = $c->ce;

	my @archive_courseIDs = $c->param('archive_courseIDs');

	# If we are skipping a course remove one from the list of courses
	shift @archive_courseIDs if defined $c->param('skip_archive_course');

	my $archive_courseID = $archive_courseIDs[0];

	my $ce2 = WeBWorK::CourseEnvironment->new({ courseName => $archive_courseID });

	if ($ce2->{dbLayoutName}) {
		my $CIchecker = WeBWorK::Utils::CourseIntegrityCheck->new(ce => $ce2);

		# Check database
		my ($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($archive_courseID);

		# Upgrade the database if requested.
		my @upgrade_report;
		if ($c->param('upgrade_course_tables')) {
			my @schema_table_names = keys %$dbStatus;
			my @tables_to_create =
				grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A } @schema_table_names;
			my @tables_to_alter =
				grep { $dbStatus->{$_}->[0] == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B }
				@schema_table_names;
			push(@upgrade_report, $CIchecker->updateCourseTables($archive_courseID, [@tables_to_create]));
			for my $table_name (@tables_to_alter) {
				push(@upgrade_report, $CIchecker->updateTableFields($archive_courseID, $table_name));
			}

			($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($archive_courseID);
		}

		# Update and check directories.
		my $dir_update_messages = $c->param('upgrade_course_tables') ? $CIchecker->updateCourseDirectories : [];
		my ($directories_ok, $directory_report) = $CIchecker->checkCourseDirectories($ce2);

		return $c->include(
			'ContentGenerator/CourseAdmin/archive_course_confirm',
			ce2                 => $ce2,
			upgrade_report      => \@upgrade_report,
			tables_ok           => $tables_ok,
			dbStatus            => $dbStatus,
			dir_update_messages => $dir_update_messages,
			directory_report    => $directory_report,
			directories_ok      => $directories_ok,
			archive_courseID    => $archive_courseID,
			archive_courseIDs   => \@archive_courseIDs
		);
	} else {
		return $c->tag('p', class => 'text-danger fw-bold', "Unable to find database layout for $archive_courseID");
	}
}

sub do_archive_course ($c) {
	my $ce = $c->ce;
	my $db = $c->db;

	my @archive_courseIDs = $c->param('archive_courseIDs');
	my $archive_courseID  = $archive_courseIDs[0];

	my $ce2 = WeBWorK::CourseEnvironment->new({ courseName => $archive_courseID });

	# Remove course specific temp files before archiving, but don't delete the temp directory itself.
	remove_tree($ce2->{courseDirs}{html_temp}, { keep_root => 1 });

	# Remove the original default tmp directory if it exists
	my $orgDefaultCourseTempDir = "$ce2->{courseDirs}{html}/tmp";
	if (-d $orgDefaultCourseTempDir) {
		remove_tree($orgDefaultCourseTempDir);
	}

	my $message = eval { archiveCourse(courseID => $archive_courseID, ce => $ce2); };

	if ($@) {
		my $error = $@;
		return $c->tag(
			'div',
			class => 'alert alert-danger p-1 mb-2',
			$c->c(
				$c->tag('p',   $c->maketext('An error occurred while archiving the course [_1]:', $archive_courseID)),
				$c->tag('div', class => 'font-monospace', $error)
			)->join('')
		);
	} else {
		my $output = $c->c;
		push(@$output, $c->tag('div', class => 'alert alert-danger p-1 mb-2', $message)) if $message;
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$c->maketext('Successfully archived the course [_1].', $archive_courseID)
			)
		);
		writeLog($ce, 'hosted_courses', join("\t", "\tarchived", '', '', $archive_courseID,));

		if ($c->param('delete_course')) {
			eval { deleteCourse(courseID => $archive_courseID, ce => $ce2); };

			if ($@) {
				my $error = $@;
				push(
					@$output,
					$c->tag(
						'div',
						class => 'alert alert-danger p-1 mb-2',
						$c->c(
							$c->tag(
								'p',
								$c->maketext(
									'An error occurred while deleting the course [_1]:', $archive_courseID
								)
							),
							$c->tag('div', class => 'font-monospace', $error)
						)->join('')
					)
				);
			} else {
				push(
					@$output,
					$c->tag(
						'div',
						class => 'alert alert-success p-1 mb-2',
						$c->maketext('Successfully deleted the course [_1].', $archive_courseID),
					)
				);
			}

		}
		shift @archive_courseIDs;    # Remove the course which has just been archived.
		if (@archive_courseIDs) {
			push(
				@$output,
				$c->form_for(
					$c->current_route,
					method => 'POST',
					$c->c(
						$c->hidden_authen_fields,
						$c->hidden_fields(qw(subDisplay delete_course)),
						(map { $c->hidden_field(archive_courseIDs => $_) } @archive_courseIDs),
						$c->tag(
							'div',
							class => 'd-flex justify-content-center gap-2',
							$c->c(
								$c->submit_button(
									$c->maketext('Stop archiving courses'),
									name  => 'decline_archive_course',
									class => 'btn btn-primary'
								),
								$c->submit_button(
									$c->maketext('Archive next course'),
									name  => 'archive_course',
									class => 'btn btn-primary'
								)
							)->join('')
						)
					)->join('')
				)
			);
		} else {
			push(
				@$output,
				$c->form_for(
					$c->current_route,
					method => 'POST',
					$c->c(
						$c->hidden_authen_fields,
						$c->hidden_fields('subDisplay'),
						$c->hidden_field(archive_courseIDs => $archive_courseID),
						$c->tag(
							'div',
							class => 'd-flex justify-content-center gap-2',
							$c->submit_button(
								$c->maketext('OK'),
								name  => 'decline_archive_course',
								class => 'btn btn-primary'
							)
						)
					)->join('')
				)
			);
		}

		return $output->join('');
	}
}

sub unarchive_course_form ($c) {
	return $c->include('ContentGenerator/CourseAdmin/unarchive_course_form');
}

sub unarchive_course_validate ($c) {
	my $ce = $c->ce;

	my $unarchive_courseID = $c->param('unarchive_courseID') || '';
	my $new_courseID       = $c->param('new_courseID')       || '';

	# Use the archive name for the course unless a course id was provided.
	my $courseID = ($new_courseID =~ /\S/ ? $new_courseID : $unarchive_courseID) =~ s/\.tar\.gz$//r;

	debug(" unarchive_courseID $unarchive_courseID new_courseID $new_courseID ");

	my @errors;

	if ($courseID eq '') {
		push @errors, $c->maketext('You must specify a course name.');
	} elsif (-d "$ce->{webworkDirs}->{courses}/$courseID") {
		# Check that a directory for this course doesn't already exist.
		push @errors,
			$c->maketext(
				'A directory already exists with the name [_1]. '
				. 'You must first delete this existing course before you can unarchive.',
				$courseID
			);
	} elsif (length($courseID) > $ce->{maxCourseIdLength}) {
		push @errors, $c->maketext('Course ID cannot exceed [_1] characters.', $ce->{maxCourseIdLength});
	}

	unless ($courseID =~ /^[\w-]*$/) {    # regex copied from CourseAdministration.pm
		push @errors, $c->maketext('Course ID may only contain letters, numbers, hyphens, and underscores.');
	}

	return @errors;
}

sub unarchive_course_confirm ($c) {
	my $ce = $c->ce;

	my $unarchive_courseID = $c->param('unarchive_courseID') || '';
	my $new_courseID       = $c->param('new_courseID')       || '';

	my $courseID = ($new_courseID =~ /\S/ ? $new_courseID : $unarchive_courseID) =~ s/\.tar\.gz//r;

	debug(" unarchive_courseID $unarchive_courseID new_courseID $new_courseID ");

	return $c->include(
		'ContentGenerator/CourseAdmin/unarchive_course_confirm',
		unarchive_courseID => $unarchive_courseID,
		courseID           => $courseID
	);
}

sub do_unarchive_course ($c) {
	my $ce = $c->ce;

	my $new_courseID = $c->param('new_courseID');

	return $c->tag('div', class => 'alert alert-danger p-1 mb-2', $c->maketext('You must specify a course name.'))
		unless $new_courseID;

	my $unarchive_courseID = $c->param('unarchive_courseID') || '';

	unarchiveCourse(
		newCourseID => $new_courseID,
		oldCourseID => $unarchive_courseID =~ s/\.tar\.gz$//r,
		archivePath => "$ce->{webworkDirs}{courses}/$ce->{admin_course_id}/archives/$unarchive_courseID",
		ce          => $ce,
	);

	if ($@) {
		my $error = $@;
		return $c->tag(
			'div',
			class => 'alert alert-danger p-1 mb-2',
			$c->c(
				$c->tag(
					'p', $c->maketext('An error occurred while unarchiving the course [_1]:', $unarchive_courseID)
				),
				$c->tag('div', class => 'font-monospace', $error)
			)->join('')
		);
	} else {
		writeLog($ce, 'hosted_courses', join("\t", "\tunarchived", '', '', "$unarchive_courseID to $new_courseID",));

		if ($c->param('clean_up_course')) {
			my $ce_new = WeBWorK::CourseEnvironment->new({ courseName => $new_courseID });
			my $db_new = WeBWorK::DB->new($ce_new->{dbLayout});

			for my $student_id ($db_new->listPermissionLevelsWhere({ permission => $ce->{userRoles}{student} })) {
				$db_new->deleteUser($student_id->[0]);
			}

			for my $file (values %{ $ce_new->{courseFiles}{logs} }) {
				eval { Mojo::File->new($file)->remove };
				$c->addbadmessage($c->maketext('Failed to remove file [_1]: [_2]', $file, $@)) if $@;
			}

			if (-d $ce_new->{courseDirs}{scoring}) {
				eval { Mojo::File->new($ce_new->{courseDirs}{scoring})->remove_tree({ keep_root => 1 }) };
				$c->addbadmessage($c->maketext('Failed to remove scoring files: [_1]', $@)) if $@;
			}

			if (-d $ce_new->{courseDirs}{tmpEditFileDir}) {
				eval { Mojo::File->new($ce_new->{courseDirs}{tmpEditFileDir})->remove_tree({ keep_root => 1 }) };
				$c->addbadmessage($c->maketext('Failed to remove temporary edited files: [_1]', $@)) if $@;
			}
		}

		return $c->c(
			$c->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$c->maketext('Successfully unarchived [_1] to the course [_2]', $unarchive_courseID, $new_courseID),
			),
			$c->tag(
				'div',
				class => 'd-flex justify-content-between',
				$c->c(
					$c->form_for(
						$c->current_route,
						method => 'POST',
						$c->c(
							$c->hidden_authen_fields('upgrade_course_'),
							$c->hidden_field(subDisplay        => 'upgrade_course'),
							$c->hidden_field(upgrade_course    => 1),
							$c->hidden_field(upgrade_courseIDs => $new_courseID),
							$c->submit_button(
								$c->maketext('Upgrade Course'),
								name  => 'upgrade_course_confirm',
								class => 'btn btn-primary'
							)
						)->join('')
					),
					$c->link_to(
						$c->maketext('Log into Course') => 'set_list' => { courseID => $new_courseID },
						class                           => 'btn btn-primary'
					),
					$c->form_for(
						$c->current_route,
						method => 'POST',
						$c->c(
							$c->hidden_authen_fields('unarchive_more_'),
							$c->hidden_fields('subDisplay'),
							$c->hidden_field(unarchive_courseID => $unarchive_courseID),
							$c->submit_button(
								$c->maketext('Unarchive More'),
								name  => 'unarchive_more',
								class => 'btn btn-primary'
							)
						)->join('')
					)
				)->join('')
			)
		)->join('');
	}
}

# Course upgrade methods

sub upgrade_course_form ($c) {
	return $c->include('ContentGenerator/CourseAdmin/upgrade_course_form');
}

sub upgrade_course_validate ($c) {
	my @errors;
	for ($c->param('upgrade_courseIDs')) {
		push @errors, $c->maketext('You must specify a course name.') if ($_ eq '');
	}

	return @errors;
}

sub upgrade_course_confirm ($c) {
	my $ce = $c->ce;
	my $db = $c->db;

	my @upgrade_courseIDs = $c->param('upgrade_courseIDs');

	my ($extra_database_tables_exist, $extra_database_fields_exist) = (0, 0);

	my $status_output = $c->c;

	for my $upgrade_courseID (@upgrade_courseIDs) {
		next unless $upgrade_courseID =~ /\S/;    # skip empty values

		# Analyze one course
		my $ce2 = WeBWorK::CourseEnvironment->new({ courseName => $upgrade_courseID });

		# Create integrity checker
		my $CIchecker = WeBWorK::Utils::CourseIntegrityCheck->new(ce => $ce2);

		# Report on database status
		my ($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);
		my ($all_tables_ok, $extra_database_tables, $extra_database_fields, $rebuild_table_indexes, $db_report) =
			$c->formatReportOnDatabaseTables($dbStatus, $upgrade_courseID);

		my $course_output = $c->c;

		# Add the report on course database to the output.
		push(
			@$course_output,
			$c->tag(
				'div',
				class => 'form-check mb-2',
				$c->tag(
					'label',
					class => 'form-check-label',
					$c->c(
						$c->check_box(
							upgrade_courseIDs => $upgrade_courseID,
							checked           => undef,
							class             => 'form-check-input',
						),
						$c->maketext('Upgrade [_1]', $upgrade_courseID)
					)->join('')
				)
			)
		);
		push(@$course_output, $c->tag('h2',  $c->maketext('Report for course [_1]:', $upgrade_courseID)));
		push(@$course_output, $c->tag('div', class => 'mb-2', $c->maketext('Database:')));
		push(@$course_output, $db_report);

		if ($extra_database_tables) {
			$extra_database_tables_exist = 1;
			push(
				@$course_output,
				$c->tag(
					'p',
					class => 'text-danger fw-bold',
					$c->maketext('There are extra database tables which are not defined in the schema. ')
						. 'Check the checkbox by the table to delete it when upgrading the course. '
						. 'Warning: Deletion destroys all data contained in the table and is not undoable!'
				)
			);
		}

		if ($extra_database_fields) {
			$extra_database_fields_exist = 1;
			push(
				@$course_output,
				$c->tag(
					'p',
					class => 'text-danger fw-bold',
					$c->maketext(
						'There are extra database fields which are not defined in the schema for at least one table. '
							. 'Check the checkbox by the field to delete it when upgrading the course. '
							. 'Warning: Deletion destroys all data contained in the field and is not undoable!'
					)
				)
			);
		}

		if ($rebuild_table_indexes) {
			push(
				@$course_output,
				$c->tag(
					'p',
					class => 'text-danger fw-bold',
					$c->maketext(
						'There are extra database fields which are not defined in the schema and were part of the key '
							. 'for at least one table. These fields must be deleted and the table indexes rebuilt. '
							. 'Warning: This will destroy all data contained in the field and is not undoable!'
					)
				)
			);
		}

		# Report on directory status
		my ($directories_ok, $directory_report) = $CIchecker->checkCourseDirectories;
		push(@$course_output, $c->tag('div', class => 'mb-2', $c->maketext('Directory structure:')));
		push(
			@$course_output,
			$c->tag(
				'ul',
				$c->c(
					map {
						$c->tag(
							'li',
							$c->c("$_->[0]: ",
								$c->tag('span', class => $_->[2] ? 'text-success' : 'text-danger', $_->[1]))
								->join('')
						)
					} @$directory_report
				)->join('')
			)
		);
		push(
			@$course_output,
			$directories_ok
			? $c->tag('p', class => 'text-success mb-0', $c->maketext('Directory structure is ok'))
			: $c->tag(
				'p',
				class => 'text-danger mb-0',
				$c->maketext(
					'Directory structure is missing directories or the webserver lacks sufficient privileges.')
			)
		);

		push(@$status_output, $c->tag('div', class => 'border border-dark rounded p-2 mb-2', $course_output->join('')));
	}

	return $c->include(
		'ContentGenerator/CourseAdmin/upgrade_course_confirm',
		upgrade_courseIDs           => \@upgrade_courseIDs,
		extra_database_tables_exist => $extra_database_tables_exist,
		extra_database_fields_exist => $extra_database_fields_exist,
		status_output               => $status_output->join('')
	);
}

sub do_upgrade_course ($c) {
	my $output = $c->c;

	for my $upgrade_courseID ($c->param('upgrade_courseIDs')) {
		next unless $upgrade_courseID =~ /\S/;    # Omit blank course IDs

		# Update one course
		my $ce2 = WeBWorK::CourseEnvironment->new({ courseName => $upgrade_courseID });

		# Create integrity checker
		my $CIchecker = WeBWorK::Utils::CourseIntegrityCheck->new(ce => $ce2);

		# Add missing tables and missing fields to existing tables
		my ($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);
		my @schema_table_names = keys %$dbStatus;
		my @tables_to_create =
			grep { $dbStatus->{$_}[0] == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A } @schema_table_names;
		my @tables_to_alter =
			grep { $dbStatus->{$_}[0] == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B } @schema_table_names;

		my @upgrade_report;
		push(
			@upgrade_report,
			$CIchecker->updateCourseTables(
				$upgrade_courseID, [@tables_to_create], [ ($c->param("$upgrade_courseID.delete_tableIDs")) ]
			)
		);
		for my $table_name (@tables_to_alter) {
			push(
				@upgrade_report,
				$CIchecker->updateTableFields(
					$upgrade_courseID, $table_name,
					[ ($c->param("$upgrade_courseID.$table_name.delete_fieldIDs")) ]
				)
			);
		}

		# Analyze database status and prepare status report
		($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);

		my ($all_tables_ok, $extra_database_tables, $extra_database_fields, $rebuild_table_indexes, $db_report) =
			$c->formatReportOnDatabaseTables($dbStatus);

		# Prepend course name
		$db_report = $c->c($c->tag('div', class => 'mb-2', $c->maketext('Database:')), $db_report);

		# Report on databases and report summary
		if ($extra_database_tables) {
			push(
				@$db_report,
				$c->tag(
					'p',
					class => 'text-danger fw-bold',
					$c->maketext('There are extra database tables which are not defined in the schema.')
				)
			);
		}
		if ($extra_database_fields) {
			push(
				@$db_report,
				$c->tag(
					'p',
					class => 'text-danger fw-bold',
					$c->maketext(
						'There are extra database fields which are not defined in the schema for at least one table.')
				)
			);
		}

		# Add missing directories and prepare report on directory status
		my $dir_update_messages = $CIchecker->updateCourseDirectories;    # Needs more error messages
		my ($directories_ok, $directory_report) = $CIchecker->checkCourseDirectories;

		# Show status
		my $course_report = $c->c;
		push(@$course_report, $c->tag('h2', $c->maketext('Report for course [_1]:', $upgrade_courseID)));
		push(@$course_report,
			map { $c->tag('p', class => ($_->[1] ? 'text-success' : 'text-danger my-0') . ' fw-bold', $_->[0]) }
				@upgrade_report);

		push(@$course_report, @$db_report);

		# Show report on directory status
		push(
			@$course_report,
			$c->tag('div', class => 'mb-2', $c->maketext('Directory structure:')),
			$c->tag(
				'ul',
				$c->c(
					map {
						$c->tag(
							'li',
							$c->c("$_->[0]: ",
								$c->tag('span', class => $_->[2] ? 'text-success' : 'text-danger', $_->[1]))
								->join('')
						)
					} @$directory_report
				)->join('')
			),
			$c->tag(
				'ul',
				$c->c(
					map {
						$c->tag(
							'li',
							$c->tag(
								'span',
								class => $_->[1] ? 'text-success' : 'text-danger',
								$_->[0]
							)
						)
					} @$dir_update_messages
				)->join('')
			),
			$directories_ok
			? $c->tag('p', class => 'text-success mb-0', $c->maketext('Directory structure is ok'))
			: $c->tag(
				'p',
				class => 'text-danger mb-0',
				$c->maketext(
					'Directory structure is missing directories or the webserver lacks sufficient privileges.')
			)
		);
		push(@$output, $c->tag('div', class => 'border border-dark rounded p-2 mb-2', $course_report->join('')));
	}

	# Submit buttons -- return to beginning
	push(@$output, $c->tag('h2', $c->maketext('Upgrade process completed')));
	push(
		@$output,
		$c->form_for(
			$c->current_route,
			method => 'POST',
			$c->c(
				$c->hidden_authen_fields,
				$c->tag(
					'p',
					class => 'text-center',
					$c->submit_button(
						$c->maketext('Done'),
						name  => 'decline_upgrade_course',
						class => 'btn btn-primary'
					)
				)
			)->join('')
		)
	);

	return $output->join('');
}

# Location management routines

sub manage_location_form ($c) {
	my $db = $c->db;

	# Get a list of all existing locations
	my @locations = sort { lc($a->location_id) cmp lc($b->location_id) } $db->getAllLocations();

	return $c->include(
		'ContentGenerator/CourseAdmin/manage_location_form',
		locations => \@locations,
		locAddr   => { map { $_->location_id => [ $db->listLocationAddresses($_->location_id) ] } @locations }
	);
}

sub add_location_handler ($c) {
	my $db = $c->db;

	# Get the new location data.
	my $locationID    = $c->param('new_location_name');
	my $locationDescr = $c->param('new_location_description');
	my $locationAddr  = $c->param('new_location_addresses');

	# Break the addresses up
	$locationAddr =~ s/\s*-\s*/-/g;
	$locationAddr =~ s/\s*\/\s*/\//g;
	my @addresses = split(/\s+/, $locationAddr);

	# Sanity checks
	my $badAddr = '';
	for my $addr (@addresses) {
		unless (Net::IP->new($addr)) {
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
			for my $addr (@addresses) {
				$badLocAddr .= "$addr, "
					if (grep {/^$addr$/} @allLocAddr);
			}
			$badLocAddr =~ s/, $//;
		}
	}

	my $output = $c->c;

	if (!@addresses || !$locationID || !$locationDescr) {
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->maketext(
					'Missing required input data. Please check that you have '
						. 'filled in all of the create location fields and resubmit.'
				)
			)
		);
	} elsif ($badAddr) {
		$c->param('new_location_addresses', $locationAddr);
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->maketext(
					'Address(es) [_1] is(are) not in a recognized form.  Please check your data entry and resubmit.',
					$badAddr
				)
			)
		);
	} elsif ($db->existsLocation($locationID)) {
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->maketext(
					'A location with the name [_1] already exists in the database.  '
						. 'Did you mean to edit that location instead?',
					$locationID
				)
			)
		);
	} elsif ($badLocAddr) {
		push(
			@$output,
			$c->tag(
				'div',
				{ class => 'alert alert-danger p-1 mb-2' },
				$c->maketext(
					'Address(es) [_1] already exist in the database.  THIS SHOULD NOT HAPPEN!  '
						. 'Please double check the integrity of the WeBWorK database before continuing.',
					$badLocAddr
				)
			)
		);
	} else {
		# add the location
		my $locationObj = $db->newLocation;
		$locationObj->location_id($locationID);
		$locationObj->description($locationDescr);
		$db->addLocation($locationObj);

		# and add the addresses
		for my $addr (@addresses) {
			my $locationAddress = $db->newLocationAddress;
			$locationAddress->location_id($locationID);
			$locationAddress->ip_mask($addr);

			$db->addLocationAddress($locationAddress);
		}

		# we've added the location, so clear those param
		#    entries
		$c->param('manage_location_action',   'none');
		$c->param('new_location_name',        '');
		$c->param('new_location_description', '');
		$c->param('new_location_addresses',   '');

		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$c->maketext(
					'Location [_1] has been created, with addresses [_2].',
					$locationID, join(', ', @addresses)
				)
			)
		);
	}

	push(@$output, $c->manage_location_form);

	return $output->join('');
}

sub delete_location_handler ($c) {
	my $db = $c->db;

	# Determine which location was requested to be deleted.
	my $locationID = $c->param('delete_location');

	# Check for selected deletions if appropriate.
	my @delLocations = ($locationID);
	if ($locationID eq 'selected_locations') {
		@delLocations = $c->param('delete_selected');
		$locationID   = @delLocations;
	}

	# Has the confirmation been checked?
	my $confirm = $c->param('delete_confirm');

	my $output = $c->c;

	my $badID;
	if (!$locationID) {
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->maketext('Please provide a location name to delete.')
			)
		);

	} elsif ($badID = $c->existsLocations_helper(@delLocations)) {
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->maketext('No location with name [_1] exists in the database', $badID)
			)
		);

	} elsif (!$confirm || $confirm ne 'true') {
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->maketext('Location deletion requires confirmation.')
			)
		);
	} else {
		for (@delLocations) {
			$db->deleteLocation($_);
		}
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$c->maketext('Deleted Location(s): [_1]', join(', ', @delLocations))
			)
		);
		$c->param('manage_location_action', 'none');
		$c->param('delete_location',        '');
	}
	push(@$output, $c->manage_location_form);

	return $output->join('');
}

sub existsLocations_helper ($c, @locations) {
	my $db = $c->db;
	for (@locations) {
		return $_ if !$db->existsLocation($_);
	}
	return 0;
}

sub edit_location_form ($c) {
	my $db = $c->db;

	my $locationID = $c->param('edit_location');
	if ($db->existsLocation($locationID)) {
		my $location = $db->getLocation($locationID);
		# This doesn't give that nice a sort for IP addresses, because there is the problem with 192.168.1.168 sorting
		# ahead of 192.168.1.2.  we could do better if we either invoked Net::IP in the sort routine, or if we insisted
		# on dealing only with IPv4.  Rather than deal with either of those, we'll leave this for now.
		my @locAddresses = sort { $a cmp $b } $db->listLocationAddresses($locationID);

		return $c->include(
			'ContentGenerator/CourseAdmin/edit_location_form',
			location     => $location,
			locationID   => $locationID,
			locAddresses => \@locAddresses
		);
	} else {
		return $c->c(
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->maketext(
					'Location [_1] does not exist in the WeBWorK database.  Please check your input '
						. '(perhaps you need to reload the location management page?).',
					$locationID
				)
			),
			$c->manage_location_form
		)->join('');
	}
}

sub edit_location_handler ($c) {
	my $db = $c->db;

	my $locationID   = $c->param('edit_location');
	my $locationDesc = $c->param('location_description');
	my $addAddresses = $c->param('new_location_addresses');
	my @delAddresses = $c->param('delete_location_addresses');
	my $deleteAll    = $c->param('delete_all_addresses');

	# Gut check
	if (!$locationID) {
		return $c->c(
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->maketext('No location specified to edit. Please check your input data.')
			),
			$c->manage_location_form
		)->join('');

	} elsif (!$db->existsLocation($locationID)) {
		return $c->c(
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->maketext(
					'Location [_1] does not exist in the WeBWorK database.  '
						. 'Please check your input (perhaps you need to reload the location management page?).',
					$locationID
				)
			),
			$c->manage_location_form
		)->join('');
	} else {
		my $location = $db->getLocation($locationID);

		# Get the current location addresses.  If we're deleting all of the existing addresses, we don't use this list
		# to determine which addresses to add, however.
		my @currentAddr = $db->listLocationAddresses($locationID);
		my @compareAddr = (!$deleteAll || $deleteAll ne 'true') ? @currentAddr : ();

		my $doneMsg = '';

		if ($locationDesc && $location->description ne $locationDesc) {
			$location->description($locationDesc);
			$db->putLocation($location);
			$doneMsg = $c->tag('p', class => 'my-0', $c->maketext('Updated location description.'));
		}

		# Get the addresses to add out of the text field.
		$addAddresses =~ s/\s*-\s*/-/g;
		$addAddresses =~ s/\s*\/\s*/\//g;
		my @addAddresses = split(/\s+/, $addAddresses);

		# Make sure that we're adding and deleting only those addresses
		# that are not yet/currently in the location addresses.
		my (@toAdd, @noAdd, @toDel, @noDel);

		my $badAddr = '';
		for my $addr (@addAddresses) {
			if (grep {/^$addr$/} @compareAddr) {
				push(@noAdd, $addr);
			} else {
				# Make sure the address is in a sensible form.
				if (Net::IP->new($addr)) {
					push(@toAdd, $addr);
				} else {
					$badAddr .= "$addr, " unless Net::IP->new($addr);
				}
			}
		}
		$badAddr =~ s/, $//;

		if ($deleteAll && $deleteAll eq 'true') {
			@toDel = @currentAddr;
		} else {
			for my $addr (@delAddresses) {
				if (grep {/^$addr$/} @currentAddr) {
					push(@toDel, $addr);
				} else {
					push(@noDel, $addr);
				}
			}
		}

		# Delete addresses first, because we allow deletion of all existing addresses, then addition of addresses.  note
		# that we don't allow deletion and then addition of the same address normally, however; in that case we'll end
		# up just deleting the address.
		for (@toDel) {
			$db->deleteLocationAddress($locationID, $_);
		}
		for (@toAdd) {
			my $locAddr = $db->newLocationAddress;
			$locAddr->location_id($locationID);
			$locAddr->ip_mask($_);
			$db->addLocationAddress($locAddr);
		}

		my $addrMsg = $c->c;
		push(
			@$addrMsg,
			$c->tag(
				'p',
				class => 'my-0',
				$c->maketext('Deleted addresses [_1] from location.', join(', ', @toDel))
			)
		) if @toDel;
		push(
			@$addrMsg,
			$c->tag(
				'p',
				class => 'my-0',
				$c->maketext('Added addresses [_1] to location [_2].', join(', ', @toAdd), $locationID)
			)
		) if @toAdd;

		my $badMsg = $c->c;
		push(
			@$badMsg,
			$c->tag(
				'p',
				class => 'my-0',
				$c->maketext(
					'Address(es) [_1] in the add list is(are) already in the location [_2], and so were skipped.',
					join(', ', @noAdd), $locationID
				)
			)
		) if @noAdd;
		push(
			@$badMsg,
			$c->tag(
				'p',
				class => 'my-0',
				$c->maketext(
					'Address(es) [_1] is(are) not in a recognized form.  Please check your data entry and try again.',
					$badAddr
				)
			)
		) if $badAddr;
		push(
			@$badMsg,
			$c->tag(
				'p',
				class => 'my-0',
				$c->maketext(
					'Address(es) [_1] in the delete list is(are) not in the location [_2], and so were skipped.',
					join(', ', @noDel), $locationID
				)
			)
		) if @noDel;

		my $output = $c->c;
		push(@$output, $c->tag('div', class => 'alert alert-danger p-1 mb-2', $badMsg->join('')))
			if @$badMsg;
		if ($doneMsg || @$addrMsg) {
			push(
				@$output,
				$c->tag(
					'div',
					class => 'alert alert-success p-1 mb-2',
					$c->c($doneMsg, @$addrMsg)->join('')
				)
			);
		} else {
			push(
				@$output,
				$c->tag(
					'div',
					class => 'alert alert-danger p-1 mb-2',
					$c->maketext('No valid changes submitted for location [_1].', $locationID)
				)
			);
		}
		push(@$output, $c->edit_location_form);
		return $output->join('');
	}
}

sub hide_inactive_course_form ($c) {
	my $ce = $c->ce;

	my @courseIDs = listCourses($ce);

	# Get and store last modify time for login.log for all courses. Also get visibility status.
	my ($epoch_modify_time, %coursesData, %courseLabels, @noLoginLogIDs, @loginLogIDs, @hideCourseIDs);
	for my $courseID (@courseIDs) {
		my $loginLogFile = "$ce->{webworkDirs}{courses}/$courseID/logs/login.log";
		if (-e $loginLogFile) {    # This should always exist except for the model course.
			$epoch_modify_time                         = stat($loginLogFile)->mtime;
			$coursesData{$courseID}{epoch_modify_time} = $epoch_modify_time;
			$coursesData{$courseID}{local_modify_time} = ctime($epoch_modify_time);
			push(@loginLogIDs, $courseID);
		} else {
			$coursesData{$courseID}{local_modify_time} =
				'no login.log';    # This should never be the case except for the model course
			push(@noLoginLogIDs, $courseID);
		}
		if (-f "$ce->{webworkDirs}{courses}/$courseID/hide_directory") {
			$coursesData{$courseID}{status} = $c->maketext('hidden');
		} else {
			$coursesData{$courseID}{status} = $c->maketext('visible');
		}
		$courseLabels{$courseID} =
			"$courseID  ($coursesData{$courseID}{status} :: $coursesData{$courseID}{local_modify_time})";
	}
	if (($c->param('hide_listing_format') // 'alphabetically') eq 'last_login') {
		# This should be an empty array except for the model course.
		@noLoginLogIDs = sort { lc($a) cmp lc($b) } @noLoginLogIDs;
		@loginLogIDs   = sort { $coursesData{$a}{epoch_modify_time} <=> $coursesData{$b}{epoch_modify_time} }
			@loginLogIDs;    # oldest first
		@hideCourseIDs = (@noLoginLogIDs, @loginLogIDs);
	} else {
		# In this case we sort alphabetically
		@hideCourseIDs = sort { lc($a) cmp lc($b) } @courseIDs;
	}

	return $c->include(
		'ContentGenerator/CourseAdmin/hide_inactive_course_form',
		hideCourseIDs => \@hideCourseIDs,
		courseLabels  => \%courseLabels
	);
}

sub hide_course_validate ($c) {
	return $c->maketext('You must specify a course name.') unless $c->param('hide_courseIDs');
	return;
}

sub do_hide_inactive_course ($c) {
	my $ce = $c->ce;

	my (@succeeded_courses, @failed_courses);
	my $already_hidden_count = 0;

	for my $hide_courseID ($c->param('hide_courseIDs')) {
		my $hideDirFile = "$ce->{webworkDirs}{courses}/$hide_courseID/hide_directory";
		if (-f $hideDirFile) {
			++$already_hidden_count;
			next;
		}
		if (open(my $HIDEFILE, '>', $hideDirFile)) {
			print $HIDEFILE $c->maketext(
				'Place a file named "hide_directory" in a course or other directory and it will not show up '
					. 'in the courses list on the WeBWorK home page. It will still appear in the '
					. 'Course Administration listing.');
			close $HIDEFILE;
			push @succeeded_courses, $hide_courseID;
		} else {
			push @failed_courses, $hide_courseID;
		}
	}

	my $output = $c->c;

	if (@failed_courses) {
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->c(
					$c->tag(
						'p',
						$c->maketext(
							'Errors occurred while hiding the courses listed below when attempting to create the '
								. q{file hide_directory in the course's directory. Check the ownership and permissions }
								. q{of the course's directory, e.g "[_1]".},
							"$ce->{webworkDirs}{courses}/$failed_courses[0]/"
						)
					),
					$c->tag('ul', $c->c(map { $c->tag('li', $_) } @failed_courses)->join(''))
				)->join('')
			)
		);
	}

	my $succeeded_message = '';

	if (!@succeeded_courses && $already_hidden_count) {
		if (@failed_courses) {
			$succeeded_message =
				$c->maketext('Except for the errors listed above, all selected courses are already hidden.');
		} else {
			$succeeded_message = $c->maketext('All selected courses are already hidden.');
		}
	} elsif (@succeeded_courses) {
		$succeeded_message = $c->c(
			$c->tag('p',  $c->maketext('The following courses were successfully hidden:')),
			$c->tag('ul', $c->c(map { $c->tag('li', $_) } @succeeded_courses)->join(''))
		)->join('');
	}

	push(@$output, $c->tag('div', class => 'alert alert-success p-1 mb-2', $succeeded_message)) if ($succeeded_message);

	return $output->join('');
}

sub unhide_course_validate ($c) {
	return $c->maketext('You must specify a course name.') unless $c->param('hide_courseIDs');
	return;
}

sub do_unhide_inactive_course ($c) {
	my $ce = $c->ce;

	my (@succeeded_courses, @failed_courses);
	my $already_visible_count = 0;

	for my $unhide_courseID ($c->param('hide_courseIDs')) {
		my $hideDirFile = "$ce->{webworkDirs}{courses}/$unhide_courseID/hide_directory";
		unless (-f $hideDirFile) {
			++$already_visible_count;
			next;
		}
		if (unlink $hideDirFile) {
			push @succeeded_courses, $unhide_courseID;
		} else {
			push @failed_courses, $unhide_courseID;
		}
	}

	my $output = $c->c;

	if (@failed_courses) {
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$c->c(
					$c->tag(
						'p',
						$c->maketext(
							'Errors occurred while unhiding the courses listed below when attempting delete the file '
								. q{hide_directory in the course's directory. Check the ownership and permissions of }
								. q{the course's directory, e.g "[_1]".},
							"$ce->{webworkDirs}{courses}/$failed_courses[0]/"
						)
					),
					$c->tag('ul', $c->c(map { $c->tag('li', $_) } @failed_courses)->join(''))
				)->join('')
			)
		);
	}

	my $succeeded_message = '';

	if (!@succeeded_courses && $already_visible_count) {
		if (@failed_courses) {
			$succeeded_message =
				$c->maketext('Except for the errors listed above, all selected courses are already unhidden.');
		} else {
			$succeeded_message = $c->maketext('All selected courses are already unhidden.');
		}
	} elsif (@succeeded_courses) {
		$succeeded_message = $c->c(
			$c->tag('p',  $c->maketext('The following courses were successfully unhidden:')),
			$c->tag('ul', $c->c(map { $c->tag('li', $_) } @succeeded_courses)->join(''))
		)->join('');
	}

	if ($succeeded_message) {
		push(@$output, $c->tag('div', class => 'alert alert-success p-1 mb-2', $succeeded_message));
	}

	return $output->join('');
}

# LTI Course Map Management

sub manage_lti_course_map_form ($c) {
	my $ce = $c->ce;

	my @courseIDs = listCourses($ce);
	my %courseMap = map { $_->course_id => $_->lms_context_id } $c->db->getLTICourseMapsWhere;
	for (@courseIDs) { $courseMap{$_} = '' unless defined $courseMap{$_} }

	my %ltiConfigs = map {
		my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $_ }) };
		$_ => $@
			? undef
			: {
				LTIVersion => $ce->{LTIVersion},
				$ce->{LTIVersion}
				? (
					$ce->{LTIVersion} eq 'v1p1'
					? (ConsumerKey => $ce->{LTI}{v1p1}{ConsumerKey})
					: $ce->{LTIVersion} eq 'v1p3' ? (
						PlatformID   => $ce->{LTI}{v1p3}{PlatformID},
						ClientID     => $ce->{LTI}{v1p3}{ClientID},
						DeploymentID => $ce->{LTI}{v1p3}{DeploymentID}
					)
					: ()
				)
				: ()
			}
	} @courseIDs;

	return $c->include(
		'ContentGenerator/CourseAdmin/manage_lti_course_map_form',
		courseMap  => \%courseMap,
		ltiConfigs => \%ltiConfigs
	);
}

sub save_lti_course_map_validate ($c) {
	my @errors;

	my @courseIDs = listCourses($c->ce);
	my %courseMap = map { $_->course_id => $_->lms_context_id } $c->db->getLTICourseMapsWhere;

	# If a mapping is going to be removed, then delete it from the mapping so it is not considered below.
	for (@courseIDs) {
		delete $courseMap{$_} unless defined $c->param("$_-context-id") && $c->param("$_-context-id") ne '';
	}

	# Course environments are loaded as needed. Keep a cache to avoid needing to load any multiple times.
	my %ces;

COURSE:
	for my $courseID (@courseIDs) {
		my $lms_context_id = $c->param("$courseID-context-id");
		next unless defined $lms_context_id && $lms_context_id ne '';

		$ces{$courseID} = WeBWorK::CourseEnvironment->new({ courseName => $courseID })
			unless defined $ces{$courseID};

		if (!defined $courseMap{$courseID} && !$ces{$courseID}{LTIVersion}) {
			push(
				@errors,
				$c->maketext(
					'An LMS context id is requested to be assigned to [_1], '
						. 'but that course is not configured to use LTI.',
					$courseID
				)
			);
			next;
		}

		if (
			$ces{$courseID}{LTIVersion} eq 'v1p3'
			&& !(
				$ces{$courseID}{LTI}{v1p3}{PlatformID}
				&& $ces{$courseID}{LTI}{v1p3}{ClientID}
				&& $ces{$courseID}{LTI}{v1p3}{DeploymentID}
			)
			)
		{
			push(
				@errors,
				$c->maketext(
					'An LMS context id is requested to be assigned to [_1] which is set to use LTI 1.3, '
						. 'but that course is missing LTI 1.3 authentication parameters.',
					$courseID
				),
			);
			next;
		}

		for (grep { $_ ne $courseID && $courseMap{$_} eq $lms_context_id } keys %courseMap) {
			$ces{$_} = WeBWorK::CourseEnvironment->new({ courseName => $_ }) unless defined $ces{$_};
			if ($ces{$courseID}{LTIVersion} eq $ces{$_}{LTIVersion}) {
				if (
					$ces{$courseID}{LTIVersion} eq 'v1p1'
					&& (!$ces{$courseID}{LTI}{v1p1}{ConsumerKey}
						|| !$ces{$_}{LTI}{v1p1}{ConsumerKey}
						|| $ces{$courseID}{LTI}{v1p1}{ConsumerKey} eq $ces{$_}{LTI}{v1p1}{ConsumerKey})
					)
				{
					push(
						@errors,
						$c->maketext(
							'The context id for [_1] is requested to be set to be the same as that of '
								. '[_2], and both courses are configured to use LTI 1.1, but the consumer keys for '
								. 'the two courses are either not both set or are the same.',
							$courseID,
							$_
						)
					);
					next COURSE;
				}

				if ($ces{$courseID}{LTIVersion} eq 'v1p3'
					&& $ces{$courseID}{LTI}{v1p3}{PlatformID} eq $ces{$_}{LTI}{v1p3}{PlatformID}
					&& $ces{$courseID}{LTI}{v1p3}{ClientID} eq $ces{$_}{LTI}{v1p3}{ClientID}
					&& $ces{$courseID}{LTI}{v1p3}{DeploymentID} eq $ces{$_}{LTI}{v1p3}{DeploymentID})
				{
					push(
						@errors,
						$c->maketext(
							'The context id for [_1] is requested to be set to be the same as that of '
								. '[_2], but the two courses are configured to use LTI 1.3 with the same LTI 1.3 '
								. 'authentication parameters.',
							$courseID,
							$_,
						)
					);
					next COURSE;
				}
			}
		}

		$courseMap{$courseID} = $lms_context_id;
	}

	return @errors;
}

sub do_save_lti_course_map ($c) {
	my $db = $c->db;

	for (listCourses($c->ce)) {
		if (defined $c->param("$_-context-id") && $c->param("$_-context-id") ne '') {
			eval { $db->setLTICourseMap($_, $c->param("$_-context-id")) };
			$c->addbadmessage($c->maketext('An error occurred saving mapping for [_1]: [_2]', $_, $@)) if $@;
		} else {
			eval { $db->deleteLTICourseMapWhere({ course_id => $_ }) };
			$c->addbadmessage($c->maketext('An error occurred deleting mapping for [_1]: [_2]', $_, $@)) if $@;
		}
	}

	$c->addgoodmessage($c->maketext('Saved course map.'));
	return $c->manage_lti_course_map_form;
}

# Form to copy or reset OTP secrets.
sub manage_otp_secrets_form ($c) {
	my $courses          = {};
	my $dbs              = {};
	my $skipped_courses  = [];
	my $show_all_courses = $c->param('show_all_courses') || 0;

	# Create course data first, since it is used in all cases and initializes course db references.
	for my $courseID (listCourses($c->ce)) {
		my $ce = WeBWorK::CourseEnvironment->new({ courseName => $courseID });
		$dbs->{$courseID} = WeBWorK::DB->new($ce->{dbLayouts}{ $ce->{dbLayoutName} });

		# By default ignore courses larger than 200 users, as this can cause a large load building menus.
		my @users = $dbs->{$courseID}->listUsers;
		if ($show_all_courses || scalar @users < 200) {
			$courses->{$courseID} = \@users;
		} else {
			push(@$skipped_courses, $courseID);
		}
	}

	# Process the confirmed rest or copy actions here.
	if ($c->param('otp_confirm_reset')) {
		my $total    = 0;
		my $courseID = $c->param('sourceResetCourseID');
		for my $user ($c->param('otp_reset_row')) {
			my $password = $dbs->{$courseID}->getPassword($user);
			if ($password && $password->otp_secret) {
				$password->otp_secret('');
				$dbs->{$courseID}->putPassword($password);
				$total++;
			}
		}
		if ($total) {
			$c->addgoodmessage($c->maketext('[_1] OTP secrets reset.', $total));
		} else {
			$c->addbadmessage($c->maketext('No OTP secrets reset.'));
		}
	} elsif ($c->param('otp_confirm_copy')) {
		my $total = 0;
		for my $row ($c->param('otp_copy_row')) {
			my ($s_course, $s_user, $d_course, $d_user) = split(':', $row);
			my $s_password = $dbs->{$s_course}->getPassword($s_user);
			if ($s_password && $s_password->otp_secret) {
				# Password may not be defined if using external auth, so create new password record if not.
				# Should we check $d_user is actually valid again (was checked on previous page)?
				my $d_password = $dbs->{$d_course}->getPassword($d_user)
					// $dbs->{$d_course}->newPassword(user_id => $d_user);
				$d_password->otp_secret($s_password->otp_secret);
				$dbs->{$d_course}->putPassword($d_password);
				$total++;
			}
		}
		if ($total) {
			$c->addgoodmessage($c->maketext('[_1] OTP secrets copied.', $total));
		} else {
			$c->addbadmessage($c->maketext('No OTP secrets copied.'));
		}
	}

	return $c->include(
		'ContentGenerator/CourseAdmin/manage_otp_secrets_form',
		courses         => $courses,
		skipped_courses => $skipped_courses
	);
}

# Deals with both single and multiple copy confirmation.
sub copy_otp_secrets_confirm ($c) {
	my $action = $c->param('action');
	my $source_course;
	my @source_users;
	my @dest_courses;
	my $dest_user;

	if ($action eq 'single') {
		$source_course = $c->param('sourceSingleCourseID');
		@source_users  = ($c->param('sourceSingleUserID'));
		@dest_courses  = ($c->param('destSingleCourseID'));
		$dest_user     = $c->param('destSingleUserID');
	} elsif ($action eq 'multiple') {
		$source_course = $c->param('sourceMultipleCourseID');
		@source_users  = ($c->param('sourceMultipleUserID'));
		@dest_courses  = ($c->param('destMultipleCourseID'));
	} else {
		$c->addbadmessage($c->maketext('Invalid action [_1].', $action));
		return $c->manage_otp_secrets_form;
	}

	my @errors;
	push(@errors, $c->maketext('Source course ID missing.')) unless (defined $source_course && $source_course ne '');
	push(@errors, $c->maketext('Source user ID missing.'))   unless (@source_users          && $source_users[0] ne '');
	push(@errors, $c->maketext('Destination course ID missing.')) unless (@dest_courses && $dest_courses[0] ne '');
	push(@errors, $c->maketext('Destination user ID missing.'))
		unless (
			$action eq 'multiple'
			|| (defined $dest_user
				&& $dest_user ne '')
		);
	if (@errors) {
		for (@errors) {
			$c->addbadmessage($_);
		}
		return $c->manage_otp_secrets_form;
	}
	if ($action eq 'single' && $source_course eq $dest_courses[0] && $source_users[0] eq $dest_user) {
		$c->addbadmessage(
			$c->maketext('Destination user must be different than source user when copying from same course'));
		return $c->manage_otp_secrets_form;
	}
	if ($action eq 'multiple' && @dest_courses == 1 && $source_course eq $dest_courses[0]) {
		$c->addbadmessage($c->maketext('Destination course must be different than source course.'));
		return $c->manage_otp_secrets_form;
	}

	my @rows;
	my %dbs;
	my $source_ce = WeBWorK::CourseEnvironment->new({ courseName => $source_course });
	$dbs{$source_course} = WeBWorK::DB->new($source_ce->{dbLayouts}{ $source_ce->{dbLayoutName} });

	for my $s_user (@source_users) {
		my $s_user_password = $dbs{$source_course}->getPassword($s_user);
		unless ($s_user_password && $s_user_password->otp_secret) {
			push(
				@rows,
				{
					source_course  => $source_course,
					source_user    => $s_user,
					source_message => $c->maketext('OTP secret is empty - Skipping'),
					error          => 'warning',
					skip           => 1,
				}
			);
			next;
		}

		for my $d_course (@dest_courses) {
			next if $action eq 'multiple' && $d_course eq $source_course;

			my $d_user = $action eq 'single' ? $dest_user : $s_user;
			my $skip   = 0;
			my $error_message;
			my $dest_error;

			unless ($dbs{$d_course}) {
				my $dest_ce = WeBWorK::CourseEnvironment->new({ courseName => $d_course });
				$dbs{$d_course} = WeBWorK::DB->new($dest_ce->{dbLayouts}{ $dest_ce->{dbLayoutName} });
			}

			my $d_user_password = $dbs{$d_course}->getPassword($d_user);
			if (!defined $d_user_password) {
				# Just because there is no password record, the user could still exist when using external auth.
				unless ($dbs{$d_course}->existsUser($d_user)) {
					$dest_error    = 'warning';
					$error_message = $c->maketext('User does not exist - Skipping');
					$skip          = 1;
				}
			} elsif ($d_user_password->otp_secret) {
				$dest_error    = 'danger';
				$error_message = $c->maketext('OTP Secret is not empty - Overwritting');
			}

			push(
				@rows,
				{
					source_course => $source_course,
					source_user   => $s_user,
					dest_course   => $d_course,
					dest_user     => $d_user,
					dest_message  => $error_message,
					error         => $dest_error,
					skip          => $skip
				}
			);
		}
	}

	return $c->include('ContentGenerator/CourseAdmin/copy_otp_secrets_confirm', action_rows => \@rows);
}

sub reset_otp_secrets_confirm ($c) {
	my $source_course = $c->param('sourceResetCourseID');
	my @dest_users    = ($c->param('destResetUserID'));

	my @errors;
	push(@errors, $c->maketext('Source course ID missing.'))    unless (defined $source_course && $source_course ne '');
	push(@errors, $c->maketext('Destination user ID missing.')) unless (@dest_users            && $dest_users[0] ne '');
	if (@errors) {
		for (@errors) {
			$c->addbadmessage($_);
		}
		return $c->manage_otp_secrets_form;
	}

	my $ce = WeBWorK::CourseEnvironment->new({ courseName => $source_course });
	my $db = WeBWorK::DB->new($ce->{dbLayouts}{ $ce->{dbLayoutName} });
	my @rows;
	for my $user (@dest_users) {
		my $password = $db->getPassword($user);
		my $error    = $password && $password->otp_secret ? '' : $c->maketext('OTP Secret is empty - Skipping');

		push(
			@rows,
			{
				user    => $user,
				message => $error,
				error   => $error ? 'warning' : '',
				skip    => $error ? 1         : 0,
			}
		);
	}

	return $c->include('ContentGenerator/CourseAdmin/reset_otp_secrets_confirm', action_rows => \@rows);
}

sub do_registration ($c) {
	my $ce = $c->ce;

	`echo "info" > $ce->{courseDirs}{root}/registered_$ce->{WW_VERSION}`;

	return $c->tag(
		'div',
		class => 'mt-2 mx-auto w-50 text-center',
		$c->c(
			$c->tag(
				'p',
				'Registration banner has been hidden. '
					. 'We appreciate your registering your server with the WeBWorK Project!'
			),
			$c->form_for(
				$c->current_route,
				method => 'POST',
				$c->c(
					$c->hidden_authen_fields,
					$c->submit_button(
						$c->maketext('Continue'),
						name  => 'registration_completed',
						label => 'Continue',
						class => 'btn btn-primary'
					)
				)->join('')
			)
		)->join('')
	);
}

# Format a list of tables and fields in the database, and the status of each.
sub formatReportOnDatabaseTables ($c, $dbStatus, $courseID = undef) {
	my %table_status_message = (
		WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B =>
			$c->tag('span', class => 'text-success me-2', $c->maketext('Table is ok')),
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A => $c->tag(
			'span',
			class => 'text-danger me-2',
			$c->maketext('Table defined in schema but missing in database')
		),
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B => $c->tag(
			'span',
			class => 'text-danger me-2',
			$c->maketext('Table defined in database but missing in schema')
		),
		WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => $c->tag(
			'span',
			class => 'text-danger me-2',
			$c->maketext('Schema and database table definitions do not agree')
		)
	);
	my %field_status_message = (
		WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B =>
			$c->tag('span', class => 'text-success me-2', $c->maketext('Field is ok')),
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A =>
			$c->tag('span', class => 'text-danger me-2', $c->maketext('Field missing in database')),
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B =>
			$c->tag('span', class => 'text-danger me-2', $c->maketext('Field missing in schema')),
		WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => $c->tag(
			'span',
			class => 'text-danger me-2',
			$c->maketext('Schema and database field definitions do not agree')
		)
	);

	my $all_tables_ok         = 1;
	my $extra_database_tables = 0;
	my $extra_database_fields = 0;
	my $rebuild_table_indexes = 0;

	my $db_report = $c->c;

	for my $table (sort keys %$dbStatus) {
		my $table_report = $c->c;

		my $table_status = $dbStatus->{$table}[0];
		push(@$table_report, $table . ': ', $table_status_message{$table_status});

		if ($table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A) {
			$all_tables_ok = 0;
		} elsif ($table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B) {
			$extra_database_tables = 1;
			push(
				@$table_report,
				$c->tag(
					'span',
					class => 'form-check d-inline-block',
					$c->tag(
						'label',
						class => 'form-check-label',
						$c->c($c->check_box("$courseID.delete_tableIDs" => $table, class => 'form-check-input'),
							$c->maketext('Delete table when upgrading'))->join('')
					)
				)
			) if defined $courseID;
		} elsif ($table_status == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B) {
			my %fieldInfo     = %{ $dbStatus->{$table}[1] };
			my $fields_report = $c->c;

			for my $key (keys %fieldInfo) {
				my $field_status = $fieldInfo{$key}[0];
				my $field_report = $c->c("$key: $field_status_message{$field_status}");

				if ($field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B) {
					if ($fieldInfo{$key}[1]) {
						$rebuild_table_indexes = 1;
					} else {
						$extra_database_fields = 1;
					}
					if (defined $courseID) {
						if ($fieldInfo{$key}[1]) {
							push(@$field_report, $c->hidden_field("$courseID.$table.delete_fieldIDs" => $key));
						} else {
							push(
								@$field_report,
								$c->tag(
									'span',
									class => 'form-check d-inline-block',
									$c->tag(
										'label',
										class => 'form-check-label',
										$c->c(
											$c->check_box(
												"$courseID.$table.delete_fieldIDs" => $key,
												class                              => 'form-check-input'
											),
											$c->maketext('Delete field when upgrading')
										)->join('')
									)
								)
							);
						}
					}
				} elsif ($field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A) {
					$all_tables_ok = 0;
				}
				push(@$fields_report, $c->tag('li', $field_report->join('')));
			}
			push(@$table_report, $c->tag('ul', $fields_report->join('')));
		}
		push(@$db_report, $c->tag('li', $table_report->join('')));
	}

	$db_report = $c->c($c->tag('ul', $db_report->join('')));

	push(@$db_report, $c->tag('p', class => 'text-success', $c->maketext('Database tables are ok'))) if $all_tables_ok;

	return (
		$all_tables_ok,         $extra_database_tables, $extra_database_fields,
		$rebuild_table_indexes, $db_report->join('')
	);
}

1;
