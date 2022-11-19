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
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::CourseAdmin - Add, rename, and delete courses.

=cut

use strict;
use warnings;

use Net::IP;    # needed for location management
use File::Path 'remove_tree';
use File::stat;
use Time::localtime;

use WeBWorK::CourseEnvironment;
use WeBWorK::Debug;
use WeBWorK::Utils qw(cryptPassword writeLog trim_spaces);
use WeBWorK::Utils::CourseManagement qw(addCourse renameCourse retitleCourse deleteCourse listCourses archiveCourse
	unarchiveCourse initNonNativeTables);
use WeBWorK::Utils::CourseIntegrityCheck;
use WeBWorK::DB;

async sub pre_header_initialize {
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $authz   = $r->authz;
	my $urlpath = $r->urlpath;
	my $user    = $r->param('user');

	return unless $authz->hasPermissions($user, 'create_and_delete_courses');

	# Get result and send to message
	my $status_message = $r->param('status_message');
	$self->addmessage($r->tag('p', class => 'my-2', $r->b($status_message))) if $status_message;

	# Check that the non-native tables are present in the database.
	# These are the tables which are not course specific.
	my @table_update_messages = initNonNativeTables($ce, $ce->{dbLayoutName});
	$self->addgoodmessage($r->c(@table_update_messages)->join($r->tag('br'))) if @table_update_messages;

	my @errors;
	my $method_to_call;

	my $subDisplay = $r->param('subDisplay');
	if (defined $subDisplay) {
		if ($subDisplay eq 'add_course') {
			if (defined $r->param('add_course')) {
				@errors = $self->add_course_validate;
				if (@errors) {
					$method_to_call = 'add_course_form';
				} else {
					$method_to_call = 'do_add_course';
				}
			} else {
				$method_to_call = 'add_course_form';
			}
		} elsif ($subDisplay eq 'rename_course') {
			if (defined $r->param('rename_course')) {
				@errors = $self->rename_course_validate;
				if (@errors) {
					$method_to_call = 'rename_course_form';
				} else {
					$method_to_call = 'rename_course_confirm';
				}
			} elsif (defined $r->param('confirm_rename_course')) {
				@errors = $self->rename_course_validate;
				if (@errors) {
					$method_to_call = 'rename_course_form';
				} else {
					$method_to_call = 'do_rename_course';
				}
			} elsif (defined $r->param('confirm_retitle_course')) {
				$method_to_call = 'do_retitle_course';

			} elsif (defined $r->param('upgrade_course_tables')) {
				@errors = $self->rename_course_validate;
				if (@errors) {
					$method_to_call = 'rename_course_form';
				} else {
					$method_to_call = 'rename_course_confirm';
				}
			} else {
				$method_to_call = 'rename_course_form';
			}
		} elsif ($subDisplay eq 'delete_course') {
			if (defined $r->param('delete_course')) {
				@errors = $self->delete_course_validate;
				if (@errors) {
					$method_to_call = 'delete_course_form';
				} else {
					$method_to_call = 'delete_course_confirm';
				}
			} elsif (defined $r->param('confirm_delete_course')) {
				@errors = $self->delete_course_validate;
				if (@errors) {
					$method_to_call = 'delete_course_form';
				} else {
					$method_to_call = 'do_delete_course';
				}
			} elsif (defined($r->param('delete_course_refresh'))) {
				$method_to_call = 'delete_course_form';
			} else {
				$method_to_call = 'delete_course_form';
			}
		} elsif ($subDisplay eq 'archive_course') {
			if (defined $r->param('archive_course') || defined $r->param('skip_archive_course')) {
				@errors = $self->archive_course_validate;
				if (@errors) {
					$method_to_call = 'archive_course_form';
				} else {
					$method_to_call = 'archive_course_confirm';
				}
			} elsif (defined $r->param('confirm_archive_course')) {
				@errors = $self->archive_course_validate;
				if (@errors) {
					$method_to_call = 'archive_course_form';
				} else {
					$method_to_call = 'do_archive_course';
				}
			} elsif (defined $r->param('upgrade_course_tables')) {
				@errors = $self->archive_course_validate;
				if (@errors) {
					$method_to_call = 'archive_course_form';
				} else {
					$method_to_call = 'archive_course_confirm';
				}
			} elsif (defined($r->param('archive_course_refresh'))) {
				$method_to_call = 'archive_course_form';
			} else {
				$method_to_call = 'archive_course_form';
			}
		} elsif ($subDisplay eq 'unarchive_course') {
			if (defined $r->param('unarchive_course')) {
				@errors = $self->unarchive_course_validate;
				if (@errors) {
					$method_to_call = 'unarchive_course_form';
				} else {
					$method_to_call = 'unarchive_course_confirm';
				}
			} elsif (defined $r->param('confirm_unarchive_course')) {
				@errors = $self->unarchive_course_validate;
				if (@errors) {
					$method_to_call = 'unarchive_course_form';
				} else {
					$method_to_call = 'do_unarchive_course';
				}
			} else {
				$method_to_call = 'unarchive_course_form';
			}
		} elsif ($subDisplay eq 'upgrade_course') {
			if (defined $r->param('upgrade_course')) {
				@errors = $self->upgrade_course_validate;
				if (@errors) {
					$method_to_call = 'upgrade_course_form';
				} else {
					$method_to_call = 'upgrade_course_confirm';
				}
			} elsif (defined $r->param('confirm_upgrade_course')) {
				@errors = $self->upgrade_course_validate;
				if (@errors) {
					$method_to_call = 'upgrade_course_form';
				} else {
					$method_to_call = 'do_upgrade_course';
				}
			} else {
				$method_to_call = 'upgrade_course_form';
			}
		} elsif ($subDisplay eq 'manage_locations') {
			if (defined($r->param('manage_location_action'))) {
				$method_to_call = $r->param('manage_location_action');
			} else {
				$method_to_call = 'manage_location_form';
			}
		} elsif ($subDisplay eq 'hide_inactive_course') {
			if (defined($r->param('hide_course'))) {
				@errors = $self->hide_course_validate;
				if (@errors) {
					$method_to_call = 'hide_inactive_course_form';
				} else {
					$method_to_call = 'do_hide_inactive_course';
				}
			} elsif (defined($r->param('unhide_course'))) {
				@errors = $self->unhide_course_validate;
				if (@errors) {
					$method_to_call = 'hide_inactive_course_form';
				} else {
					$method_to_call = 'do_unhide_inactive_course';
				}
			} elsif (defined($r->param('hide_course_refresh'))) {
				$method_to_call = 'hide_inactive_course_form';
			} else {
				$method_to_call = 'hide_inactive_course_form';
			}
		} elsif ($subDisplay eq 'registration') {
			if (defined($r->param('register_site'))) {
				$method_to_call = 'do_registration';
			}
		} else {
			@errors = "Unrecognized sub-display @{[ $r->tag('b', $subDisplay) ]}.";
		}
	}

	$self->{errors}         = \@errors;
	$self->{method_to_call} = $method_to_call;

	return;
}

sub add_course_form {
	my ($self) = @_;
	return $self->r->include('ContentGenerator/CourseAdmin/add_course_form');
}

sub add_course_validate {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my $add_courseID                = trim_spaces($r->param('add_courseID'))                || '';
	my $add_initial_userID          = trim_spaces($r->param('add_initial_userID'))          || '';
	my $add_initial_password        = trim_spaces($r->param('add_initial_password'))        || '';
	my $add_initial_confirmPassword = trim_spaces($r->param('add_initial_confirmPassword')) || '';
	my $add_initial_firstName       = trim_spaces($r->param('add_initial_firstName'))       || '';
	my $add_initial_lastName        = trim_spaces($r->param('add_initial_lastName'))        || '';
	my $add_initial_email           = trim_spaces($r->param('add_initial_email'))           || '';
	my $add_dbLayout                = trim_spaces($r->param('add_dbLayout'))                || '';

	my @errors;

	if ($add_courseID eq '') {
		push @errors, $r->maketext('You must specify a course ID.');
	}
	unless ($add_courseID =~ /^[\w-]*$/) {    # regex copied from CourseAdministration.pm
		push @errors, $r->maketext('Course ID may only contain letters, numbers, hyphens, and underscores.');
	}
	if (grep { $add_courseID eq $_ } listCourses($ce)) {
		push @errors, $r->maketext('A course with ID [_1] already exists.', $add_courseID);
	}
	if (length($add_courseID) > $ce->{maxCourseIdLength}) {
		push @errors, $r->maketext('Course ID cannot exceed [_1] characters.', $ce->{maxCourseIdLength});
	}

	if ($add_initial_userID ne '') {
		if ($add_initial_password eq '') {
			push @errors, $r->maketext('You must specify a password for the initial instructor.');
		}
		if ($add_initial_confirmPassword eq '') {
			push @errors, $r->maketext('You must confirm the password for the initial instructor.');
		}
		if ($add_initial_password ne $add_initial_confirmPassword) {
			push @errors, $r->maketext('The password and password confirmation for the instructor must match.');
		}
		if ($add_initial_firstName eq '') {
			push @errors, $r->maketext('You must specify a first name for the initial instructor.');
		}
		if ($add_initial_lastName eq '') {
			push @errors, $r->maketext('You must specify a last name for the initial instructor.');
		}
		if ($add_initial_email eq '') {
			push @errors, $r->maketext('You must specify an email address for the initial instructor.');
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

sub do_add_course {
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $authz   = $r->authz;
	my $urlpath = $r->urlpath;

	my $add_courseID          = trim_spaces($r->param('add_courseID'))          || '';
	my $add_courseTitle       = trim_spaces($r->param('add_courseTitle'))       || '';
	my $add_courseInstitution = trim_spaces($r->param('add_courseInstitution')) || '';

	my $add_admin_users = trim_spaces($r->param('add_admin_users')) || '';

	my $add_initial_userID          = trim_spaces($r->param('add_initial_userID'))          || '';
	my $add_initial_password        = trim_spaces($r->param('add_initial_password'))        || '';
	my $add_initial_confirmPassword = trim_spaces($r->param('add_initial_confirmPassword')) || '';
	my $add_initial_firstName       = trim_spaces($r->param('add_initial_firstName'))       || '';
	my $add_initial_lastName        = trim_spaces($r->param('add_initial_lastName'))        || '';
	my $add_initial_email           = trim_spaces($r->param('add_initial_email'))           || '';

	my $add_templates_course = trim_spaces($r->param('add_templates_course')) || '';
	my $add_config_file      = trim_spaces($r->param('add_config_file'))      || '';

	my $add_dbLayout = trim_spaces($r->param('add_dbLayout')) || '';

	my $ce2 = WeBWorK::CourseEnvironment->new({
		%WeBWorK::SeedCE, courseName => $add_courseID,
	});

	my %courseOptions = (dbLayoutName => $add_dbLayout);

	if ($add_initial_email ne '') {
		$courseOptions{allowedRecipients} = [$add_initial_email];
	}

	my @users;

	# copy users from current (admin) course if desired
	if ($add_admin_users ne '') {
		for my $userID ($db->listUsers) {
			if ($userID eq $add_initial_userID) {
				$self->addbadmessage($r->maketext(
					'User "[_1]" will not be copied from admin course as it is the initial instructor.', $userID
				));
				next;
			}
			my $PermissionLevel = $db->newPermissionLevel();
			$PermissionLevel->user_id($userID);
			$PermissionLevel->permission($ce->{userRoles}{admin});
			my $User     = $db->getUser($userID);
			my $Password = $db->getPassword($userID);

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
			status        => 'C',
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
	if ($add_templates_course ne '') {
		$optional_arguments{templatesFrom} = $add_templates_course;
	}
	if ($add_config_file ne '') {
		$optional_arguments{copySimpleConfig} = $add_config_file;
	}
	if ($add_courseTitle ne '') {
		$optional_arguments{courseTitle} = $add_courseTitle;
	}
	if ($add_courseInstitution ne '') {
		$optional_arguments{courseInstitution} = $add_courseInstitution;
	}

	my $output = $r->c;

	eval {
		addCourse(
			courseID      => $add_courseID,
			ce            => $ce2,
			courseOptions => \%courseOptions,
			dbOptions     => {},
			users         => \@users,
			%optional_arguments,
		);
	};
	if ($@) {
		my $error = $@;
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->c($r->tag('p', "An error occured while creating the course $add_courseID:"),
					$r->tag('div', class => 'font-monospace', $error))->join('')
			)
		);
		# Get rid of any partially built courses.
		# FIXME: This is too fragile.
		unless ($error =~ /course exists/) {
			eval { deleteCourse(courseID => $add_courseID, ce => $ce2, dbOptions => {}); }
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
		# Add contact to admin course as student?
		# FIXME -- should we do this?
		if ($add_initial_userID =~ /\S/) {
			my $composite_id = "${add_initial_userID}_${add_courseID}";    # student id includes school name and contact
			my $User         = $db->newUser(
				user_id       => $composite_id,                            # student id includes school name and contact
				first_name    => $add_initial_firstName,
				last_name     => $add_initial_lastName,
				student_id    => $add_initial_userID,
				email_address => $add_initial_email,
				status        => 'C',
			);
			my $Password = $db->newPassword(
				user_id  => $composite_id,
				password => cryptPassword($add_initial_password),
			);
			my $PermissionLevel = $db->newPermissionLevel(
				user_id    => $composite_id,
				permission => '0',
			);
			# add contact to admin course as student
			# or if this contact and course already exist in a dropped status
			# change the student's status to enrolled
			if (my $oldUser = $db->getUser($composite_id)) {
				push(
					@$output,
					$r->tag(
						'div',
						class => 'alert alert-danger p-1 mb-2',
						$r->maketext('Replacing old data for [_1]: status: [_2]', $composite_id, $oldUser->status)
					)
				);
				$db->deleteUser($composite_id);
			}
			eval { $db->addUser($User) };
			warn $@ if $@;
			eval { $db->addPassword($Password) };
			warn $@ if $@;
			eval { $db->addPermissionLevel($PermissionLevel) };
			warn $@ if $@;
		}
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$r->maketext('Successfully created the course [_1]', $add_courseID)
			)
		);
		push(
			@$output,
			$r->tag(
				'div',
				class => 'text-center mb-2',
				$r->link_to(
					$r->maketext('Log into [_1]', $add_courseID) => $self->systemLink(
						$urlpath->newFromModule(
							'WeBWorK::ContentGenerator::ProblemSets',
							$r, courseID => $add_courseID
						),
						authen => 0
					)
				)
			)
		);
	}

	return $output->join('');
}

sub rename_course_form {
	my ($self) = @_;
	return $self->r->include('ContentGenerator/CourseAdmin/rename_course_form');
}

sub rename_course_confirm {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my $rename_oldCourseID          = $r->param('rename_oldCourseID')          || '';
	my $rename_newCourseID          = $r->param('rename_newCourseID')          || '';
	my $rename_newCourseTitle       = $r->param('rename_newCourseTitle')       || '';
	my $rename_newCourseInstitution = $r->param('rename_newCourseInstitution') || '';

	my $ce2 = WeBWorK::CourseEnvironment->new({ %WeBWorK::SeedCE, courseName => $rename_oldCourseID });

	# Create strings confirming title and institution change.
	# Connect to the database to get old title and institution.
	my $dbLayoutName                = $ce->{dbLayoutName};
	my $db                          = WeBWorK::DB->new($ce->{dbLayouts}{$dbLayoutName});
	my $oldDB                       = WeBWorK::DB->new($ce2->{dbLayouts}{$dbLayoutName});
	my $rename_oldCourseTitle       = $oldDB->getSettingValue('courseTitle')       // '';
	my $rename_oldCourseInstitution = $oldDB->getSettingValue('courseInstitution') // '';

	my ($change_course_title_str, $change_course_institution_str) = ('', '');
	if ($r->param('rename_newCourseTitle_checkbox')) {
		$change_course_title_str =
			$r->maketext('Change title from [_1] to [_2]', $rename_oldCourseTitle, $rename_newCourseTitle);
	}
	if ($r->param('rename_newCourseInstitution_checkbox')) {
		$change_course_institution_str = $r->maketext('Change course institution from [_1] to [_2]',
			$rename_oldCourseInstitution, $rename_newCourseInstitution);
	}

	# If we are only changing the title or institution, and not the courseID, then we can cut this short.
	return $r->include(
		'ContentGenerator/CourseAdmin/rename_course_confirm_short',
		rename_oldCourseTitle         => $rename_oldCourseTitle,
		change_course_title_str       => $change_course_title_str,
		rename_oldCourseInstitution   => $rename_oldCourseInstitution,
		change_course_institution_str => $change_course_institution_str,
		rename_oldCourseID            => $rename_oldCourseID
	) unless $r->param('rename_newCourseID_checkbox');

	if ($ce2->{dbLayoutName}) {
		my $CIchecker = WeBWorK::Utils::CourseIntegrityCheck->new(ce => $ce2);

		# Check database
		my ($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($rename_oldCourseID);

		# Upgrade the database if requested.
		my @upgrade_report;
		if ($r->param('upgrade_course_tables')) {
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

		return $r->include(
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
		return $r->tag('p', class => 'text-danger fw-bold', "Unable to find database layout for $rename_oldCourseID");
	}
}

sub rename_course_validate {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my $rename_oldCourseID          = $r->param('rename_oldCourseID')          || '';
	my $rename_newCourseID          = $r->param('rename_newCourseID')          || '';
	my $rename_newCourseID_checkbox = $r->param('rename_newCourseID_checkbox') || '';

	my $rename_newCourseTitle                = $r->param('rename_newCourseTitle')                || '';
	my $rename_newCourseTitle_checkbox       = $r->param('rename_newCourseTitle_checkbox')       || '';
	my $rename_newCourseInstitution          = $r->param('rename_newCourseInstitution')          || '';
	my $rename_newCourseInstitution_checkbox = $r->param('rename_newCourseInstitution_checkbox') || '';

	my @errors;

	if ($rename_oldCourseID eq '') {
		push @errors, $r->maketext('You must select a course to rename.');
	}
	if ($rename_newCourseID eq '' and $rename_newCourseID_checkbox eq 'on') {
		push @errors, $r->maketext('You must specify a new name for the course.');
	}
	if ($rename_oldCourseID eq $rename_newCourseID and $rename_newCourseID_checkbox eq 'on') {
		push @errors, $r->maketext(q{Can't rename to the same name.});
	}
	if ($rename_newCourseID_checkbox eq 'on' && length($rename_newCourseID) > $ce->{maxCourseIdLength}) {
		push @errors, $r->maketext('Course ID cannot exceed [_1] characters.', $ce->{maxCourseIdLength});
	}
	unless ($rename_newCourseID =~ /^[\w-]*$/) {    # regex copied from CourseAdministration.pm
		push @errors, $r->maketext('Course ID may only contain letters, numbers, hyphens, and underscores.');
	}
	if (grep { $rename_newCourseID eq $_ } listCourses($ce)) {
		push @errors, $r->maketext('A course with ID [_1] already exists.', $rename_newCourseID);
	}
	if ($rename_newCourseTitle eq '' and $rename_newCourseTitle_checkbox eq 'on') {
		push @errors, $r->maketext('You must specify a new title for the course.');
	}
	if ($rename_newCourseInstitution eq '' and $rename_newCourseInstitution_checkbox eq 'on') {
		push @errors, $r->maketext('You must specify a new institution for the course.');
	}
	unless ($rename_newCourseID
		or $rename_newCourseID_checkbox
		or $rename_newCourseTitle_checkbox
		or $rename_newCourseInstitution_checkbox)
	{
		push @errors,
			$r->maketext(
			'No changes specified.  You must mark the checkbox of the item(s) to be changed and enter the change data.'
			);
	}

	return @errors;
}

sub do_retitle_course {
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $urlpath = $r->urlpath;

	my $rename_oldCourseID = $r->param('rename_oldCourseID') || '';

	#   There is no new course, but there are new titles and institutions
	my $rename_newCourseTitle       = $r->param('rename_newCourseTitle')                || '';
	my $rename_newCourseInstitution = $r->param('rename_newCourseInstitution')          || '';
	my $rename_oldCourseTitle       = $r->param('rename_oldCourseTitle')                || '';
	my $rename_oldCourseInstitution = $r->param('rename_oldCourseInstitution')          || '';
	my $title_checkbox              = $r->param('rename_newCourseTitle_checkbox')       || '';
	my $institution_checkbox        = $r->param('rename_newCourseInstitution_checkbox') || '';

	#	$rename_newCourseID = $rename_oldCourseID ;  #since they are the same FIXME
	# define new courseTitle and new courseInstitution
	my %optional_arguments = ();
	$optional_arguments{courseTitle}       = $rename_newCourseTitle       if $title_checkbox;
	$optional_arguments{courseInstitution} = $rename_newCourseInstitution if $institution_checkbox;

	my $ce2;
	eval { $ce2 = WeBWorK::CourseEnvironment->new({ %WeBWorK::SeedCE, courseName => $rename_oldCourseID }); };
	warn "failed to create environment in do_retitle_course $@" if $@;

	eval { retitleCourse(courseID => $rename_oldCourseID, ce => $ce2, dbOptions => {}, %optional_arguments); };
	if ($@) {
		my $error = $@;
		return $r->tag(
			'div',
			class => 'alert alert-danger p-1 mb-2',
			$r->c(
				$r->tag(
					'p',
					$r->maketext(
						'An error occured while changing the title of the course [_1].',
						$rename_oldCourseID
					)
				),
				$r->tag('div', class => 'font-monospace', $error)
			)->join('')
		);
	} else {
		writeLog(
			$ce,
			'hosted_courses',
			join(
				"\t", "\t",
				$r->maketext('Retitled'),
				'', '',
				$r->maketext(
					'[_1] title and institution changed from [_2] to [_3] and from [_4] to [_5]',
					$rename_oldCourseID,          $rename_oldCourseTitle, $rename_newCourseTitle,
					$rename_oldCourseInstitution, $rename_newCourseInstitution
				)
			)
		);

		return $r->c(
			$r->tag(
				'div',
				class => 'alert alert-success p-1 my-2',
				$r->c(
					($title_checkbox) ? $r->tag(
						'div',
						$r->maketext(
							'The title of the course [_1] has been changed from [_2] to [_3]',
							$rename_oldCourseID, $rename_oldCourseTitle, $rename_newCourseTitle
						)
					) : '',
					($institution_checkbox) ? $r->tag(
						'div',
						$r->maketext(
							'The institution associated with the course [_1] has been changed from [_2] to [_3]',
							$rename_oldCourseID, $rename_oldCourseInstitution, $rename_newCourseInstitution
						)
					) : ''
				)->join('')
			),
			$r->tag(
				'div',
				class => 'text-center',
				$r->link_to(
					$r->maketext('Log into [_1]', $rename_oldCourseID) => $self->systemLink(
						$urlpath->newFromModule(
							'WeBWorK::ContentGenerator::ProblemSets',
							$r, courseID => $rename_oldCourseID
						),
						authen => 0
					)
				)
			)
		)->join('');
	}
}

sub do_rename_course {
	my ($self) = @_;
	my $r = $self->r;

	my $rename_oldCourseID = $r->param('rename_oldCourseID') || '';
	my $rename_newCourseID = $r->param('rename_newCourseID') || '';

	# define new courseTitle and new courseInstitution
	my %optional_arguments = ();
	my ($title_message, $institution_message);
	if ($r->param('rename_newCourseTitle_checkbox')) {
		$optional_arguments{courseTitle} = $r->param('rename_newCourseTitle') || '';
		$title_message = $r->maketext('The title of the course [_1] is now [_2]',
			$rename_newCourseID, $optional_arguments{courseTitle});

	}

	if ($r->param('rename_newCourseInstitution_checkbox')) {
		$optional_arguments{courseInstitution} = $r->param('rename_newCourseInstitution') || '';
		$institution_message = $r->maketext('The institution associated with the course [_1] is now [_2]',
			$rename_newCourseID, $optional_arguments{courseInstitution});
	}

	# dbOptions is left over from when we had 'gdbm' and 'sql' database layouts. For now the hash can remain empty.
	eval {
		renameCourse(
			courseID    => $rename_oldCourseID,
			ce          => WeBWorK::CourseEnvironment->new({ %WeBWorK::SeedCE, courseName => $rename_oldCourseID }),
			dbOptions   => {},
			newCourseID => $rename_newCourseID,
			%optional_arguments
		);
	};
	if ($@) {
		my $error = $@;
		return $r->tag(
			'div',
			class => 'alert alert-danger p-1 mb-2',
			$r->c(
				$r->tag(
					'p',
					$r->maketext(
						'An error occured while renaming the course [_1] to [_2]:', $rename_oldCourseID,
						$rename_newCourseID
					)
				),
				$r->tag('div', class => 'font-monospace', $error)
			)->join('')
		);
	} else {
		writeLog($r->ce, 'hosted_courses',
			join("\t", "\tRenamed", '', '', "$rename_oldCourseID to $rename_newCourseID"));
		return $r->c(
			$r->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$r->c(
					$title_message       ? $r->tag('p', $title_message)       : '',
					$institution_message ? $r->tag('p', $institution_message) : '',
					$r->tag(
						'p',
						class => 'mb-0',
						$r->maketext(
							'Successfully renamed the course [_1] to [_2]', $rename_oldCourseID,
							$rename_newCourseID
						)
					)
				)->join('')
			),
			$r->tag(
				'div',
				style => 'text-align: center',
				$r->link_to(
					$r->maketext('Log into [_1]', $rename_newCourseID) => $self->systemLink(
						$r->urlpath->newFromModule(
							'WeBWorK::ContentGenerator::ProblemSets',
							$r, courseID => $rename_newCourseID
						),
						authen => 0
					)
				)
			)
		)->join('');
	}
}

sub delete_course_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my @courseIDs = grep { $_ ne $r->urlpath->arg('courseID') } listCourses($ce);
	my %courseLabels;

	if (@courseIDs) {
		my $coursesDir            = $ce->{webworkDirs}{courses};
		my $delete_listing_format = $r->param('delete_listing_format');
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
				$coursesData{$courseID}{status} = $r->maketext('hidden');
			} else {
				$coursesData{$courseID}{status} = $r->maketext('visible');
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

	return $r->include(
		'ContentGenerator/CourseAdmin/delete_course_form',
		courseIDs    => \@courseIDs,
		courseLabels => \%courseLabels
	);
}

sub delete_course_validate {
	my ($self) = @_;
	my $r = $self->r;

	my @errors;
	if (!$r->param('delete_courseID')) {
		push @errors, $r->maketext('You must specify a course name.');
	} elsif ($r->param('delete_courseID') eq $r->urlpath->arg('courseID')) {
		push @errors, $r->maketext('You cannot delete the course you are currently using.');
	}

	return @errors;
}

sub delete_course_confirm {
	my ($self) = @_;
	return $self->r->include('ContentGenerator/CourseAdmin/delete_course_confirm');
}

sub do_delete_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;

	my $delete_courseID = $r->param('delete_courseID') || '';

	# dbOptions is left over from when we had 'gdbm' and 'sql' database layouts. For now the hash can remain empty.
	eval {
		deleteCourse(
			courseID  => $delete_courseID,
			ce        => WeBWorK::CourseEnvironment->new({ %WeBWorK::SeedCE, courseName => $delete_courseID }),
			dbOptions => {}
		);
	};

	if ($@) {
		my $error = $@;
		return $r->tag(
			'div',
			class => 'alert alert-danger p-1 my-2',
			$r->c($r->tag('p', $r->maketext('An error occured while deleting the course [_1]:', $delete_courseID)),
				$r->tag('div', class => 'font-monospace', $error))->join('')
		);
	} else {
		# Mark the contact person in the admin course as dropped.
		# Find the contact person for the course by searching the admin classlist.
		my @contacts = grep {/_$delete_courseID$/} $db->listUsers;
		if (@contacts) {
			die 'Incorrect number of contacts for the course $delete_courseID' . join(' ', @contacts) if @contacts != 1;

			# Mark the contact person as dropped.
			my $User = $db->getUser($contacts[0]);
			$User->status(($ce->status_name_to_abbrevs('Drop'))[0]);
			$db->putUser($User);
		}

		writeLog($ce, 'hosted_courses', join("\t", "\tDeleted", '', '', $delete_courseID));

		return $r->c(
			$r->tag(
				'div',
				class => 'alert alert-success p-1 my-2',
				$r->maketext('Successfully deleted the course [_1].', $delete_courseID),
			),
			$r->form_for(
				$r->uri,
				method => 'POST',
				$r->c(
					$self->hidden_authen_fields,
					$self->hidden_fields('subDisplay'),
					$r->tag(
						'div',
						class => 'text-center',
						$r->submit_button(
							$r->maketext('OK'),
							name  => 'decline_delete_course',
							class => 'btn btn-primary'
						)
					)
				)->join('')
			)
		)->join('');
	}
}

sub archive_course_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my @courseIDs = listCourses($ce);
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
				$coursesData{$courseID}{status} = $r->maketext('hidden');
			} else {
				$coursesData{$courseID}{status} = $r->maketext('visible');
			}
			$courseLabels{$courseID} =
				"$courseID  ($coursesData{$courseID}{status} :: $coursesData{$courseID}{local_modify_time}) ";
		}
		if (($r->param('archive_listing_format') // 'alphabetically') eq 'last_login') {
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

	return $r->include(
		'ContentGenerator/CourseAdmin/archive_course_form',
		courseIDs    => \@courseIDs,
		courseLabels => \%courseLabels
	);
}

sub archive_course_validate {
	my ($self) = @_;
	my $r = $self->r;

	my @archive_courseIDs = $r->param('archive_courseIDs');
	my @errors;
	for my $archive_courseID (@archive_courseIDs) {
		if ($archive_courseID eq '') {
			push @errors, $r->maketext('You must specify a course name.');
		} elsif ($archive_courseID eq $r->urlpath->arg('courseID')) {
			push @errors, $r->maketext('You cannot archive the course you are currently using.');
		}
	}

	return @errors;
}

sub archive_course_confirm {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my @archive_courseIDs = $r->param('archive_courseIDs');

	# If we are skipping a course remove one from the list of courses
	shift @archive_courseIDs if defined $r->param('skip_archive_course');

	my $archive_courseID = $archive_courseIDs[0];

	my $ce2 = WeBWorK::CourseEnvironment->new({ %WeBWorK::SeedCE, courseName => $archive_courseID });

	if ($ce2->{dbLayoutName}) {
		my $CIchecker = WeBWorK::Utils::CourseIntegrityCheck->new(ce => $ce2);

		# Check database
		my ($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($archive_courseID);

		# Upgrade the database if requested.
		my @upgrade_report;
		if ($r->param('upgrade_course_tables')) {
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
		my $dir_update_messages = $r->param('upgrade_course_tables') ? $CIchecker->updateCourseDirectories : [];
		my ($directories_ok, $directory_report) = $CIchecker->checkCourseDirectories($ce2);

		return $r->include(
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
		return $r->tag('p', class => 'text-danger fw-bold', "Unable to find database layout for $archive_courseID");
	}
}

sub do_archive_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;

	my @archive_courseIDs = $r->param('archive_courseIDs');
	my $archive_courseID  = $archive_courseIDs[0];

	my $ce2 = WeBWorK::CourseEnvironment->new({ %WeBWorK::SeedCE, courseName => $archive_courseID });

	# Remove course specific temp files before archiving, but don't delete the temp directory itself.
	remove_tree($ce2->{courseDirs}{html_temp}, { keep_root => 1 });

	# Remove the original default tmp directory if it exists
	my $orgDefaultCourseTempDir = "$ce2->{courseDirs}{html}/tmp";
	if (-d $orgDefaultCourseTempDir) {
		remove_tree($orgDefaultCourseTempDir);
	}

	# dbOptions is left over from when we had 'gdbm' and 'sql' database layouts. For now the hash can remain empty.
	my $message = eval { archiveCourse(courseID => $archive_courseID, ce => $ce2, dbOptions => {}); };

	if ($@) {
		my $error = $@;
		return $r->tag(
			'div',
			class => 'alert alert-danger p-1 mb-2',
			$r->c(
				$r->tag('p',   $r->maketext('An error occured while archiving the course [_1]:', $archive_courseID)),
				$r->tag('div', class => 'font-monospace', $error)
			)->join('')
		);
	} else {
		my $output = $r->c;
		push(@$output, $r->tag('div', class => 'alert alert-danger p-1 mb-2', $message)) if $message;
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$r->maketext('Successfully archived the course [_1].', $archive_courseID)
			)
		);
		writeLog($ce, 'hosted_courses', join("\t", "\tarchived", '', '', $archive_courseID,));

		if ($r->param('delete_course')) {
			eval { deleteCourse(courseID => $archive_courseID, ce => $ce2, dbOptions => {}); };

			if ($@) {
				my $error = $@;
				push(
					@$output,
					$r->tag(
						'div',
						class => 'alert alert-danger p-1 mb-2',
						$r->c(
							$r->tag(
								'p',
								$r->maketext('An error occured while deleting the course [_1]:', $archive_courseID)
							),
							$r->tag('div', class => 'font-monospace', $error)
						)->join('')
					)
				);
			} else {
				# Mark the contact person in the admin course as dropped.
				# Find the contact person for the course by searching the admin classlist.
				my @contacts = grep {/_$archive_courseID$/} $db->listUsers;
				if (@contacts) {
					die "Incorrect number of contacts for the course $archive_courseID" . join(' ', @contacts)
						if @contacts != 1;
					my $composite_id = $contacts[0];

					my $User         = $db->getUser($composite_id);
					my $status_name  = 'Drop';
					my $status_value = ($ce->status_name_to_abbrevs($status_name))[0];
					$User->status($status_value);
					$db->putUser($User);
				}

				push(
					@$output,
					$r->tag(
						'div',
						class => 'alert alert-success p-1 mb-2',
						$r->maketext('Successfully deleted the course [_1].', $archive_courseID),
					)
				);
			}

		}
		shift @archive_courseIDs;    # Remove the course which has just been archived.
		if (@archive_courseIDs) {
			push(
				@$output,
				$r->form_for(
					$r->uri,
					method => 'POST',
					$r->c(
						$self->hidden_authen_fields,
						$self->hidden_fields(qw(subDisplay delete_course)),
						(map { $r->hidden_field(archive_courseIDs => $_) } @archive_courseIDs),
						$r->tag(
							'div',
							class => 'd-flex justify-content-center gap-2',
							$r->c(
								$r->submit_button(
									$r->maketext('Stop archiving courses'),
									name  => 'decline_archive_course',
									class => 'btn btn-primary'
								),
								$r->submit_button(
									$r->maketext('Archive next course'),
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
				$r->form_for(
					$r->uri,
					method => 'POST',
					$r->c(
						$self->hidden_authen_fields,
						$self->hidden_fields('subDisplay'),
						$r->hidden_field(archive_courseIDs => $archive_courseID),
						$r->tag(
							'div',
							class => 'd-flex justify-content-center gap-2',
							$r->submit_button(
								$r->maketext('OK'),
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

sub unarchive_course_form {
	my ($self) = @_;
	return $self->r->include('ContentGenerator/CourseAdmin/unarchive_course_form');
}

sub unarchive_course_validate {
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $urlpath = $r->urlpath;

	my $unarchive_courseID = $r->param('unarchive_courseID') || '';
	my $new_courseID       = $r->param('new_courseID')       || '';

	# Use the archive name for the course unless a course id was provided.
	my $courseID = ($r->param('create_newCourseID') ? $new_courseID : $unarchive_courseID) =~ s/\.tar\.gz$//r;

	debug(" unarchive_courseID $unarchive_courseID new_courseID $new_courseID ");

	my @errors;

	if ($courseID eq '') {
		push @errors, $r->maketext('You must specify a course name.');
	} elsif (-d "$ce->{webworkDirs}->{courses}/$courseID") {
		# Check that a directory for this course doesn't already exist.
		push @errors,
			$r->maketext(
				'A directory already exists with the name [_1]. '
				. 'You must first delete this existing course before you can unarchive.',
				$courseID
			);
	} elsif (length($courseID) > $ce->{maxCourseIdLength}) {
		push @errors, $r->maketext('Course ID cannot exceed [_1] characters.', $ce->{maxCourseIdLength});
	}

	return @errors;
}

sub unarchive_course_confirm {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my $unarchive_courseID = $r->param('unarchive_courseID') || '';
	my $new_courseID       = $r->param('new_courseID')       || '';

	my $courseID = ($r->param('create_newCourseID') ? $new_courseID : $unarchive_courseID) =~ s/\.tar\.gz//r;

	debug(" unarchive_courseID $unarchive_courseID new_courseID $new_courseID ");

	return $self->r->include(
		'ContentGenerator/CourseAdmin/unarchive_course_confirm',
		unarchive_courseID => $unarchive_courseID,
		courseID           => $courseID
	);
}

sub do_unarchive_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my $new_courseID = $r->param('new_courseID');

	return $r->tag('div', class => 'alert alert-danger p-1 mb-2', $r->maketext('You must specify a course name.'))
		unless $new_courseID;

	my $unarchive_courseID = $r->param('unarchive_courseID') || '';

	unarchiveCourse(
		newCourseID => $new_courseID,
		oldCourseID => $unarchive_courseID =~ s/\.tar\.gz$//r,
		archivePath => "$ce->{webworkDirs}{courses}/$unarchive_courseID",
		ce          => $ce,
	);

	if ($@) {
		my $error = $@;
		return $r->tag(
			'div',
			class => 'alert alert-danger p-1 mb-2',
			$r->c(
				$r->tag(
					'p', $r->maketext('An error occured while archiving the course [_1]:', $unarchive_courseID)
				),
				$r->tag('div', class => 'font-monospace', $error)
			)->join('')
		);
	} else {
		writeLog($ce, 'hosted_courses', join("\t", "\tunarchived", '', '', "$unarchive_courseID to $new_courseID",));

		return $r->c(
			$r->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$r->maketext('Successfully unarchived [_1] to the course [_2]', $unarchive_courseID, $new_courseID),
			),
			$r->tag(
				'div',
				class => 'text-center',
				$r->link_to(
					$r->maketext('Log into [_1]', $new_courseID) => $self->systemLink(
						$r->urlpath->newFromModule(
							'WeBWorK::ContentGenerator::ProblemSets',
							$r, courseID => $new_courseID
						),
						authen => 0
					)
				),
			),
			$r->form_for(
				$r->uri,
				method => 'POST',
				$r->c(
					$self->hidden_authen_fields,
					$self->hidden_fields('subDisplay'),
					$r->hidden_field(unarchive_courseID => $unarchive_courseID),
					$r->tag(
						'div',
						class => 'd-flex justify-content-center mt-2',
						$r->submit_button(
							$r->maketext('Unarchive Next Course'),
							name  => 'decline_unarchive_course',
							class => 'btn btn-primary'
						)
					)
				)->join('')
			)
		)->join('');
	}
}

# Course upgrade methods

sub upgrade_course_form {
	my ($self) = @_;
	return $self->r->include('ContentGenerator/CourseAdmin/upgrade_course_form');
}

sub upgrade_course_validate {
	my $self = shift;
	my $r    = $self->r;

	my @errors;
	for ($r->param('upgrade_courseIDs')) {
		push @errors, $r->maketext('You must specify a course name.') if ($_ eq '');
	}

	return @errors;
}

sub upgrade_course_confirm {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;

	my @upgrade_courseIDs = $r->param('upgrade_courseIDs');

	my ($extra_database_tables_exist, $extra_database_fields_exist) = (0, 0);

	my $status_output = $r->c;

	for my $upgrade_courseID (@upgrade_courseIDs) {
		next unless $upgrade_courseID =~ /\S/;    # skip empty values

		# Analyze one course
		my $ce2 = WeBWorK::CourseEnvironment->new({ %WeBWorK::SeedCE, courseName => $upgrade_courseID });

		# Create integrity checker
		my $CIchecker = WeBWorK::Utils::CourseIntegrityCheck->new(ce => $ce2);

		# Report on database status
		my ($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);
		my ($all_tables_ok, $extra_database_tables, $extra_database_fields, $db_report) =
			$self->formatReportOnDatabaseTables($tables_ok, $dbStatus, $upgrade_courseID);

		my $course_output = $r->c;

		# Add the report on course database to the output.
		push(
			@$course_output,
			$r->tag(
				'div',
				class => 'form-check mb-2',
				$r->tag(
					'label',
					class => 'form-check-label',
					$r->c(
						$r->check_box(
							upgrade_courseIDs => $upgrade_courseID,
							checked           => undef,
							class             => 'form-check-input',
						),
						$r->maketext('Upgrade [_1]', $upgrade_courseID)
					)->join('')
				)
			)
		);
		push(@$course_output, $r->tag('h2',  $r->maketext('Report for course [_1]:', $upgrade_courseID)));
		push(@$course_output, $r->tag('div', class => 'mb-2', $r->maketext('Database:')));
		push(@$course_output, $db_report);

		if ($extra_database_tables) {
			$extra_database_tables_exist = 1;
			push(
				@$course_output,
				$r->tag(
					'p',
					class => 'text-danger fw-bold',
					$r->maketext('There are extra database tables which are not defined in the schema. ')
						. 'Check the checkbox by the table to delete it when upgrading the course. '
						. 'Warning: Deletion destroys all data contained in the table and is not undoable!'
				)
			);
		}

		if ($extra_database_fields) {
			$extra_database_fields_exist = 1;
			push(
				@$course_output,
				$r->tag(
					'p',
					class => 'text-danger fw-bold',
					$r->maketext(
						'There are extra database fields which are not defined in the schema for at least one table. '
							. 'Check the checkbox by the field to delete it when upgrading the course. '
							. 'Warning: Deletion destroys all data contained in the field and is not undoable!'
					)
				)
			);
		}

		# Report on directory status
		my ($directories_ok, $directory_report) = $CIchecker->checkCourseDirectories;
		push(@$course_output, $r->tag('div', class => 'mb-2', $r->maketext('Directory structure:')));
		push(
			@$course_output,
			$r->tag(
				'ul',
				$r->c(
					map {
						$r->tag(
							'li',
							$r->c("$_->[0]: ",
								$r->tag('span', class => $_->[2] ? 'text-success' : 'text-danger', $_->[1]))
								->join('')
						)
					} @$directory_report
				)->join('')
			)
		);
		push(
			@$course_output,
			$directories_ok
			? $r->tag('p', class => 'text-success mb-0', $r->maketext('Directory structure is ok'))
			: $r->tag(
				'p',
				class => 'text-danger mb-0',
				$r->maketext(
					'Directory structure is missing directories or the webserver lacks sufficient privileges.')
			)
		);

		push(@$status_output, $r->tag('div', class => 'border border-dark rounded p-2 mb-2', $course_output->join('')));
	}

	return $r->include(
		'ContentGenerator/CourseAdmin/upgrade_course_confirm',
		upgrade_courseIDs           => \@upgrade_courseIDs,
		extra_database_tables_exist => $extra_database_tables_exist,
		extra_database_fields_exist => $extra_database_fields_exist,
		status_output               => $status_output->join('')
	);
}

sub do_upgrade_course {
	my $self = shift;
	my $r    = $self->r;

	my $output = $r->c;

	for my $upgrade_courseID ($r->param('upgrade_courseIDs')) {
		next unless $upgrade_courseID =~ /\S/;    # Omit blank course IDs

		# Update one course
		my $ce2 = WeBWorK::CourseEnvironment->new({ %WeBWorK::SeedCE, courseName => $upgrade_courseID });

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
				$upgrade_courseID, [@tables_to_create], [ ($r->param("$upgrade_courseID.delete_tableIDs")) ]
			)
		);
		for my $table_name (@tables_to_alter) {
			push(
				@upgrade_report,
				$CIchecker->updateTableFields(
					$upgrade_courseID, $table_name,
					[ ($r->param("$upgrade_courseID.$table_name.delete_fieldIDs")) ]
				)
			);
		}

		# Analyze database status and prepare status report
		($tables_ok, $dbStatus) = $CIchecker->checkCourseTables($upgrade_courseID);

		my ($all_tables_ok, $extra_database_tables, $extra_database_fields, $db_report) =
			$self->formatReportOnDatabaseTables($tables_ok, $dbStatus);

		# Prepend course name
		$db_report = $r->c($r->tag('div', class => 'mb-2', $r->maketext('Database:')), $db_report);

		# Report on databases and report summary
		if ($extra_database_tables) {
			push(
				@$db_report,
				$r->tag(
					'p',
					class => 'text-danger fw-bold',
					$r->maketext('There are extra database tables which are not defined in the schema.')
				)
			);
		}
		if ($extra_database_fields) {
			push(
				@$db_report,
				$r->tag(
					'p',
					class => 'text-danger fw-bold',
					$r->maketext(
						'There are extra database fields which are not defined in the schema for at least one table.')
				)
			);
		}

		# Add missing directories and prepare report on directory status
		my $dir_update_messages = $CIchecker->updateCourseDirectories;    # Needs more error messages
		my ($directories_ok, $directory_report) = $CIchecker->checkCourseDirectories;

		# Show status
		my $course_report = $r->c;
		push(@$course_report, $r->tag('h2', $r->maketext('Report for course [_1]:', $upgrade_courseID)));
		push(@$course_report,
			map { $r->tag('p', class => ($_->[1] ? 'text-success' : 'text-danger my-0') . ' fw-bold', $_->[0]) }
				@upgrade_report);

		push(@$course_report, @$db_report);

		# Show report on directory status
		push(
			@$course_report,
			$r->tag('div', class => 'mb-2', $r->maketext('Directory structure:')),
			$r->tag(
				'ul',
				$r->c(
					map {
						$r->tag(
							'li',
							$r->c("$_->[0]: ",
								$r->tag('span', class => $_->[2] ? 'text-success' : 'text-danger', $_->[1]))
								->join('')
						)
					} @$directory_report
				)->join('')
			),
			$r->tag(
				'ul',
				$r->c(
					map {
						$r->tag(
							'li',
							$r->tag(
								'span',
								class => $_->[2] ? 'text-success' : 'text-danger',
								$_->[1]
							)
						)
					} @$dir_update_messages
				)->join('')
			),
			$directories_ok
			? $r->tag('p', class => 'text-success mb-0', $r->maketext('Directory structure is ok'))
			: $r->tag(
				'p',
				class => 'text-danger mb-0',
				$r->maketext(
					'Directory structure is missing directories or the webserver lacks sufficient privileges.')
			)
		);
		push(@$output, $r->tag('div', class => 'border border-dark rounded p-2 mb-2', $course_report->join('')));
	}

	# Submit buttons -- return to beginning
	push(@$output, $r->tag('h2', $r->maketext('Upgrade process completed')));
	push(
		@$output,
		$r->form_for(
			$r->uri,
			method => 'POST',
			$r->c(
				$self->hidden_authen_fields,
				$self->hidden_fields('subDisplay'),
				$r->tag(
					'p',
					class => 'text-center',
					$r->submit_button(
						$r->maketext('Done'),
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

sub manage_location_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;

	# Get a list of all existing locations
	my @locations = sort { lc($a->location_id) cmp lc($b->location_id) } $db->getAllLocations();

	return $r->include(
		'ContentGenerator/CourseAdmin/manage_location_form',
		locations => \@locations,
		locAddr   => { map { $_->location_id => [ $db->listLocationAddresses($_->location_id) ] } @locations }
	);
}

sub add_location_handler {
	my $self = shift();
	my $r    = $self->r;
	my $db   = $r->db;

	# Get the new location data.
	my $locationID    = $r->param('new_location_name');
	my $locationDescr = $r->param('new_location_description');
	my $locationAddr  = $r->param('new_location_addresses');

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

	my $output = $r->c;

	if (!@addresses || !$locationID || !$locationDescr) {
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->maketext(
					'Missing required input data. Please check that you have '
						. 'filled in all of the create location fields and resubmit.'
				)
			)
		);
	} elsif ($badAddr) {
		$r->param('new_location_addresses', $locationAddr);
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->maketext(
					'Address(es) [_1] is(are) not in a recognized form.  Please check your data entry and resubmit.',
					$badAddr
				)
			)
		);
	} elsif ($db->existsLocation($locationID)) {
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->maketext(
					'A location with the name [_1] already exists in the database.  '
						. 'Did you mean to edit that location instead?',
					$locationID
				)
			)
		);
	} elsif ($badLocAddr) {
		push(
			@$output,
			$r->tag(
				'div',
				{ class => 'alert alert-danger p-1 mb-2' },
				$r->maketext(
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
		$r->param('manage_location_action',   'none');
		$r->param('new_location_name',        '');
		$r->param('new_location_description', '');
		$r->param('new_location_addresses',   '');

		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$r->maketext(
					'Location [_1] has been created, with addresses [_2].',
					$locationID, join(', ', @addresses)
				)
			)
		);
	}

	push(@$output, $self->manage_location_form);

	return $output->join('');
}

sub delete_location_handler {
	my $self = shift;
	my $r    = $self->r;
	my $db   = $r->db;

	# Determine which location was requested to be deleted.
	my $locationID = $r->param('delete_location');

	# Check for selected deletions if appropriate.
	my @delLocations = ($locationID);
	if ($locationID eq 'selected_locations') {
		@delLocations = $r->param('delete_selected');
		$locationID   = @delLocations;
	}

	# Has the confirmation been checked?
	my $confirm = $r->param('delete_confirm');

	my $output = $r->c;

	my $badID;
	if (!$locationID) {
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->maketext('Please provide a location name to delete.')
			)
		);

	} elsif ($badID = $self->existsLocations_helper(@delLocations)) {
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->maketext('No location with name [_1] exists in the database', $badID)
			)
		);

	} elsif (!$confirm || $confirm ne 'true') {
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->maketext('Location deletion requires confirmation.')
			)
		);
	} else {
		for (@delLocations) {
			$db->deleteLocation($_);
		}
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-success p-1 mb-2',
				$r->maketext('Deleted Location(s): [_1]', join(', ', @delLocations))
			)
		);
		$r->param('manage_location_action', 'none');
		$r->param('delete_location',        '');
	}
	push(@$output, $self->manage_location_form);

	return $output->join('');
}

sub existsLocations_helper {
	my ($self, @locations) = @_;
	my $db = $self->r->db;
	for (@locations) {
		return $_ if !$db->existsLocation($_);
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
		# This doesn't give that nice a sort for IP addresses, because there is the problem with 192.168.1.168 sorting
		# ahead of 192.168.1.2.  we could do better if we either invoked Net::IP in the sort routine, or if we insisted
		# on dealing only with IPv4.  Rather than deal with either of those, we'll leave this for now.
		my @locAddresses = sort { $a cmp $b } $db->listLocationAddresses($locationID);

		return $r->include(
			'ContentGenerator/CourseAdmin/edit_location_form',
			location     => $location,
			locationID   => $locationID,
			locAddresses => \@locAddresses
		);
	} else {
		return $r->c(
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->maketext(
					'Location [_1] does not exist in the WeBWorK database.  Please check your input '
						. '(perhaps you need to reload the location management page?).',
					$locationID
				)
			),
			$self->manage_location_form
		)->join('');
	}
}

sub edit_location_handler {
	my $self = shift;
	my $r    = $self->r;
	my $db   = $r->db;

	my $locationID   = $r->param('edit_location');
	my $locationDesc = $r->param('location_description');
	my $addAddresses = $r->param('new_location_addresses');
	my @delAddresses = $r->param('delete_location_addresses');
	my $deleteAll    = $r->param('delete_all_addresses');

	# Gut check
	if (!$locationID) {
		return $r->c(
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->maketext('No location specified to edit. Please check your input data.')
			),
			$self->manage_location_form
		)->join('');

	} elsif (!$db->existsLocation($locationID)) {
		return $r->c(
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->maketext(
					'Location [_1] does not exist in the WeBWorK database.  '
						. 'Please check your input (perhaps you need to reload the location management page?).',
					$locationID
				)
			),
			$self->manage_location_form
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
			$doneMsg = $r->tag('p', class => 'my-0', $r->maketext('Updated location description.'));
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

		my $addrMsg = $r->c;
		push(
			@$addrMsg,
			$r->tag(
				'p',
				class => 'my-0',
				$r->maketext('Deleted addresses [_1] from location.', join(', ', @toDel))
			)
		) if @toDel;
		push(
			@$addrMsg,
			$r->tag(
				'p',
				class => 'my-0',
				$r->maketext('Added addresses [_1] to location [_2].', join(', ', @toAdd), $locationID)
			)
		) if @toAdd;

		my $badMsg = $r->c;
		push(
			@$badMsg,
			$r->tag(
				'p',
				class => 'my-0',
				$r->maketext(
					'Address(es) [_1] in the add list is(are) already in the location [_2], and so were skipped.',
					join(', ', @noAdd), $locationID
				)
			)
		) if @noAdd;
		push(
			@$badMsg,
			$r->tag(
				'p',
				class => 'my-0',
				$r->maketext(
					'Address(es) [_1] is(are) not in a recognized form.  Please check your data entry and try again.',
					$badAddr
				)
			)
		) if $badAddr;
		push(
			@$badMsg,
			$r->tag(
				'p',
				class => 'my-0',
				$r->maketext(
					'Address(es) [_1] in the delete list is(are) not in the location [_2], and so were skipped.',
					join(', ', @noDel), $locationID
				)
			)
		) if @noDel;

		my $output = $r->c;
		push(@$output, $r->tag('div', class => 'alert alert-danger p-1 mb-2', $badMsg->join('')))
			if @$badMsg;
		if ($doneMsg || @$addrMsg) {
			push(
				@$output,
				$r->tag(
					'div',
					class => 'alert alert-success p-1 mb-2',
					$r->c($doneMsg, @$addrMsg)->join('')
				)
			);
		} else {
			push(
				@$output,
				$r->tag(
					'div',
					class => 'alert alert-danger p-1 mb-2',
					$r->maketext('No valid changes submitted for location [_1].', $locationID)
				)
			);
		}
		push(@$output, $self->edit_location_form);
		return $output->join('');
	}
}

sub hide_inactive_course_form {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

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
			$coursesData{$courseID}{status} = $r->maketext('hidden');
		} else {
			$coursesData{$courseID}{status} = $r->maketext('visible');
		}
		$courseLabels{$courseID} =
			"$courseID  ($coursesData{$courseID}{status} :: $coursesData{$courseID}{local_modify_time})";
	}
	if (($r->param('hide_listing_format') // 'alphabetically') eq 'last_login') {
		# This should be an empty array except for the model course.
		@noLoginLogIDs = sort { lc($a) cmp lc($b) } @noLoginLogIDs;
		@loginLogIDs   = sort { $coursesData{$a}{epoch_modify_time} <=> $coursesData{$b}{epoch_modify_time} }
			@loginLogIDs;    # oldest first
		@hideCourseIDs = (@noLoginLogIDs, @loginLogIDs);
	} else {
		# In this case we sort alphabetically
		@hideCourseIDs = sort { lc($a) cmp lc($b) } @courseIDs;
	}

	return $r->include(
		'ContentGenerator/CourseAdmin/hide_inactive_course_form',
		hideCourseIDs => \@hideCourseIDs,
		courseLabels  => \%courseLabels
	);
}

sub hide_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	return $r->maketext('You must specify a course name.') unless $r->param('hide_courseIDs');
	return;
}

sub do_hide_inactive_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my (@succeeded_courses, @failed_courses);
	my $already_hidden_count = 0;

	for my $hide_courseID ($r->param('hide_courseIDs')) {
		my $hideDirFile = "$ce->{webworkDirs}{courses}/$hide_courseID/hide_directory";
		if (-f $hideDirFile) {
			++$already_hidden_count;
			next;
		}
		if (open(my $HIDEFILE, '>', $hideDirFile)) {
			print $HIDEFILE $r->maketext(
				'Place a file named "hide_directory" in a course or other directory and it will not show up '
					. 'in the courses list on the WeBWorK home page. It will still appear in the '
					. 'Course Administration listing.');
			close $HIDEFILE;
			push @succeeded_courses, $hide_courseID;
		} else {
			push @failed_courses, $hide_courseID;
		}
	}

	my $output = $r->c;

	if (@failed_courses) {
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->c(
					$r->tag(
						'p',
						$r->maketext(
							'Errors occured while hiding the courses listed below when attempting to create the '
								. q{file hide_directory in the course's directory. Check the ownership and permissions }
								. q{of the course's directory, e.g "[_1]".},
							"$ce->{webworkDirs}{courses}/$failed_courses[0]/"
						)
					),
					$r->tag('ul', $r->c(map { $r->tag('li', $_) } @failed_courses)->join(''))
				)->join('')
			)
		);
	}

	my $succeeded_message = '';

	if (!@succeeded_courses && $already_hidden_count) {
		if (@failed_courses) {
			$succeeded_message =
				$r->maketext('Except for the errors listed above, all selected courses are already hidden.');
		} else {
			$succeeded_message = $r->maketext('All selected courses are already hidden.');
		}
	} elsif (@succeeded_courses) {
		$succeeded_message = $r->c(
			$r->tag('p',  $r->maketext('The following courses were successfully hidden:')),
			$r->tag('ul', $r->c(map { $r->tag('li', $_) } @succeeded_courses)->join(''))
		)->join('');
	}

	push(@$output, $r->tag('div', class => 'alert alert-success p-1 mb-2', $succeeded_message)) if ($succeeded_message);

	return $output->join('');
}

sub unhide_course_validate {
	my ($self) = @_;
	my $r = $self->r;
	return $r->maketext('You must specify a course name.') unless $r->param('hide_courseIDs');
	return;
}

sub do_unhide_inactive_course {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my (@succeeded_courses, @failed_courses);
	my $already_visible_count = 0;

	for my $unhide_courseID ($r->param('hide_courseIDs')) {
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

	my $output = $r->c;

	if (@failed_courses) {
		push(
			@$output,
			$r->tag(
				'div',
				class => 'alert alert-danger p-1 mb-2',
				$r->c(
					$r->tag(
						'p',
						$r->maketext(
							'Errors occured while unhiding the courses listed below when attempting delete the file '
								. q{hide_directory in the course's directory. Check the ownership and permissions of }
								. q{the course's directory, e.g "[_1]".},
							"$ce->{webworkDirs}{courses}/$failed_courses[0]/"
						)
					),
					$r->tag('ul', $r->c(map { $r->tag('li', $_) } @failed_courses)->join(''))
				)->join('')
			)
		);
	}

	my $succeeded_message = '';

	if (!@succeeded_courses && $already_visible_count) {
		if (@failed_courses) {
			$succeeded_message =
				$r->maketext('Except for the errors listed above, all selected courses are already unhidden.');
		} else {
			$succeeded_message = $r->maketext('All selected courses are already unhidden.');
		}
	} elsif (@succeeded_courses) {
		$succeeded_message = $r->c(
			$r->tag('p',  $r->maketext('The following courses were successfully unhidden:')),
			$r->tag('ul', $r->c(map { $r->tag('li', $_) } @succeeded_courses)->join(''))
		)->join('');
	}

	if ($succeeded_message) {
		push(@$output, $r->tag('div', class => 'alert alert-success p-1 mb-2', $succeeded_message));
	}

	return $output->join('');
}

sub do_registration {
	my $self = shift;
	my $r    = $self->r;
	my $ce   = $r->ce;

	`echo "info" > $ce->{courseDirs}{root}/registered_$ce->{WW_VERSION}`;

	return $r->tag(
		'div',
		class => 'mt-2 mx-auto w-50 text-center',
		$r->c(
			$r->tag(
				'p',
				'Registration banner has been hidden. '
					. 'We appreciate your registering your server with the WeBWorK Project!'
			),
			$r->form_for(
				$r->uri,
				method => 'POST',
				$r->c(
					$self->hidden_authen_fields,
					$r->submit_button(
						$r->maketext('Continue'),
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
sub formatReportOnDatabaseTables {
	my ($self, $tables_ok, $dbStatus, $courseID) = @_;
	my $r = $self->r;

	my %table_status_message = (
		WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B =>
			$r->tag('span', class => 'text-success me-2', $r->maketext('Table is ok')),
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A => $r->tag(
			'span',
			class => 'text-danger me-2',
			$r->maketext('Table defined in schema but missing in database')
		),
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B => $r->tag(
			'span',
			class => 'text-danger me-2',
			$r->maketext('Table defined in database but missing in schema')
		),
		WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => $r->tag(
			'span',
			class => 'text-danger me-2',
			$r->maketext('Schema and database table definitions do not agree')
		)
	);
	my %field_status_message = (
		WeBWorK::Utils::CourseIntegrityCheck::SAME_IN_A_AND_B =>
			$r->tag('span', class => 'text-success me-2', $r->maketext('Field is ok')),
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A =>
			$r->tag('span', class => 'text-danger me-2', $r->maketext('Field missing in database')),
		WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B =>
			$r->tag('span', class => 'text-danger me-2', $r->maketext('Field missing in schema')),
		WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B => $r->tag(
			'span',
			class => 'text-danger me-2',
			$r->maketext('Schema and database field definitions do not agree')
		)
	);

	my $all_tables_ok         = 1;
	my $extra_database_tables = 0;
	my $extra_database_fields = 0;

	my $db_report = $r->c;

	for my $table (sort keys %$dbStatus) {
		my $table_report = $r->c;

		my $table_status = $dbStatus->{$table}[0];
		push(@$table_report, $table . ': ', $table_status_message{$table_status});

		if ($table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A) {
			$all_tables_ok = 0;
		} elsif ($table_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B) {
			$extra_database_tables = 1;
			push(
				@$table_report,
				$r->tag(
					'span',
					class => 'form-check d-inline-block',
					$r->tag(
						'label',
						class => 'form-check-label',
						$r->c($r->check_box("$courseID.delete_tableIDs" => $table, class => 'form-check-input'),
							$r->maketext('Delete table when upgrading'))->join('')
					)
				)
			) if defined $courseID;
		} elsif ($table_status == WeBWorK::Utils::CourseIntegrityCheck::DIFFER_IN_A_AND_B) {
			my %fieldInfo     = %{ $dbStatus->{$table}[1] };
			my $fields_report = $r->c;

			for my $key (keys %fieldInfo) {
				my $field_status = $fieldInfo{$key}[0];
				my $field_report = $r->c("$key: $field_status_message{$field_status}");

				if ($field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_B) {
					$extra_database_fields = 1;
					push(
						@$field_report,
						$r->tag(
							'span',
							class => 'form-check d-inline-block',
							$r->tag(
								'label',
								class => 'form-check-label',
								$r->c(
									$r->check_box(
										"$courseID.$table.delete_fieldIDs" => $key,
										class                              => 'form-check-input'
									),
									$r->maketext('Delete field when upgrading')
								)->join('')
							)
						)
					) if defined $courseID;
				} elsif ($field_status == WeBWorK::Utils::CourseIntegrityCheck::ONLY_IN_A) {
					$all_tables_ok = 0;
				}
				push(@$fields_report, $r->tag('li', $field_report->join('')));
			}
			push(@$table_report, $r->tag('ul', $fields_report->join('')));
		}
		push(@$db_report, $r->tag('li', $table_report->join('')));
	}

	$db_report = $r->c($r->tag('ul', $db_report->join('')));

	push(@$db_report, $r->tag('p', class => 'text-success', $r->maketext('Database tables are ok'))) if $all_tables_ok;

	return ($all_tables_ok, $extra_database_tables, $extra_database_fields, $db_report->join(''));
}

1;
