################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::Instructor::AchievementNotificationEditor;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::AchievementNotificationEditor - edit the achievement notification template

=cut

use WeBWorK::Utils qw(fix_newlines not_blank path_is_subdir x);

use constant ACTION_FORMS => [qw(save save_as existing disable)];
use constant ACTION_FORM_TITLES => {
	save     => x('Save'),
	save_as  => x('Save As'),
	existing => x('Use Existing Template'),
	disable  => x('Disable Notifications'),
};

sub pre_header_initialize ($c) {
	my $courseID      = $c->stash('courseID');
	my $achievementID = $c->stash('achievementID');

	# Make sure that are defined for the templates.
	$c->stash->{formsToShow}             = ACTION_FORMS();
	$c->stash->{actionFormTitles}        = ACTION_FORM_TITLES();
	$c->stash->{achievementNotification} = '';

	# Check permissions
	return unless ($c->authz->hasPermissions($c->param('user'), 'edit_achievements'));

	# Get the achievement
	$c->{achievement} = $c->db->getAchievement($achievementID);

	if (!$c->{achievement}) {
		$c->addbadmessage($c->maketext('Achievement [_1] not found!', $achievementID));
		return;
	}

	$c->{sourceFilePath} =
		$c->ce->{courseDirs}{achievement_notifications} . '/'
		. ($c->{achievement}->email_template || 'default.html.ep');

	my $actionID = $c->param('action');

	# Perform a save or save_as action
	if ($actionID) {
		die "Action $actionID not found" unless (grep { $_ eq $actionID } @{ ACTION_FORMS() });

		my $actionHandler = "${actionID}_handler";
		$c->$actionHandler;
	}

	return;
}

sub initialize ($c) {
	my $authz          = $c->authz;
	my $user           = $c->param('user');
	my $sourceFilePath = $c->{sourceFilePath};

	return unless ($authz->hasPermissions($user, 'edit_achievements'));

	$c->addmessage($c->authen->flash('status_message') || '');    # Record status messages carried over from a redirect

	# Check source file path
	if (!-e $sourceFilePath) {
		$c->addbadmessage($c->maketext('The file [_1] cannot be found.', $sourceFilePath));
		return;
	}

	# Find the text for the achievement.
	unless ($c->stash('achievementNotification') =~ /\S/) {
		unless (path_is_subdir($sourceFilePath, $c->ce->{courseDirs}{achievement_notifications}, 1)) {
			$c->addbadmessage('Path is Unsafe!');
			return;
		}

		eval { $c->stash->{achievementNotification} = WeBWorK::Utils::readFile($sourceFilePath); };
		$c->stash->{achievementNotification} = $@ if $@;
	}

	return;
}

# Convert long paths to [ACHEVNOTIFYDIR]
sub shortPath ($c, $file) {
	my $achievementsDir = $c->ce->{courseDirs}{achievement_notifications};
	return $file =~ s|^$achievementsDir|[ACHEVNOTIFYDIR]|r;
}

sub getRelativeSourceFilePath ($c, $sourceFilePath) {
	my $achievementsDir = $c->ce->{courseDirs}{achievement_notifications};
	return $sourceFilePath =~ s|^$achievementsDir/*||r;    # remove templates path and any slashes that follow
}

# saveFileChanges does most of the work. It is a separate method so that it can
# be called from either pre_header_initialize or initilize, depending on
# whether a redirect is needed or not.
sub saveFileChanges ($c, $outputFilePath) {
	my $ce = $c->ce;

	unless (not_blank($outputFilePath)) {
		$c->addbadmessage($c->maketext('You must specify an file name in order to save a new file.'));
		return;
	}

	# make sure any missing directories are created
	WeBWorK::Utils::surePathToFile($ce->{courseDirs}{achievement_notifications}, $outputFilePath);
	die 'outputFilePath is unsafe!'
		unless path_is_subdir($outputFilePath, $ce->{courseDirs}{achievement_notifications}, 1);
	eval {
		# Write changes to the file.
		open my $OUTPUTFILE, '>', $outputFilePath
			or die "Failed to open $outputFilePath";
		print $OUTPUTFILE $c->stash('achievementNotification');
		close $OUTPUTFILE;
	};
	my $writeFileErrors = $@;

	# Catch errors in saving files,
	if ($writeFileErrors) {
		# Get the current directory from the outputFilePath
		$outputFilePath =~ m|^(/.*?/)[^/]+$|;
		my $currentDirectory = $1;

		my $errorMessage;

		# Check why we failed to give better error messages
		if (!-w $ce->{courseDirs}{achievement_notifications}) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled in the templates directory.  No changes can be made.');
		} elsif (!-w $currentDirectory) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled in "[_1]".  '
					. 'Changes must be saved to a different directory for viewing.',
				$c->shortPath($currentDirectory)
			);
		} elsif (-e $outputFilePath && !-w $outputFilePath) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled for "[_1]".  '
					. 'Changes must be saved to another file for viewing.',
				$c->shortPath($outputFilePath)
			);
		} else {
			$errorMessage =
				$c->maketext('Unable to write to "[_1]": [_2]', $c->shortPath($outputFilePath), $writeFileErrors);
		}

		$c->addbadmessage($errorMessage);
	} else {
		$c->addgoodmessage($c->maketext('Saved to file "[_1]"', $c->shortPath($outputFilePath)));
	}

	return;
}

sub save_handler ($c) {
	# Grab the achievementNotification from the form in order to save it to the source path
	$c->stash->{achievementNotification} = fix_newlines($c->param('achievementNotification'));

	# Construct the output file path
	$c->saveFileChanges($c->{sourceFilePath});
	return;
}

sub save_as_handler ($c) {
	$c->{status_message} = $c->c;
	my $courseName        = $c->stash('courseID');
	my $achievementName   = $c->stash('achievementID');
	my $effectiveUserName = $c->param('effectiveUser');

	my $new_file_name       = $c->param('action.save_as.target_file') || '';
	my $targetAchievementID = $c->param('action.save_as.id')          || '';

	$new_file_name =~ s/^\s*|\s*$//g;    # remove initial and final white space
	if ($new_file_name !~ /\S/) {        # need a non-blank file name
		$c->addbadmessage($c->maketext('Please specify a file to save to.'));
		return;
	}

	# Grab the achievementNotification from the form in order to save it to a new permanent file
	$c->stash->{achievementNotification} = fix_newlines($c->param('achievementNotification'));
	$c->addbadmessage($c->maketext('Achievement notification contents is empty.'))
		unless $c->stash->{achievementNotification};

	# Rescue the user in case they forgot to end the file name with .html.ep
	$new_file_name =~ s/(\.html)?(\.ep)?$/.html.ep/;

	# Construct the output file path.
	my $outputFilePath = $c->ce->{courseDirs}{achievement_notifications} . '/' . $new_file_name;
	if (defined $outputFilePath && -e $outputFilePath) {
		$c->addbadmessage($c->maketext(
			'File "[_1]" exists.  File not saved.  No changes have been made.',
			$c->shortPath($outputFilePath)
		));
		return;
	} else {
		$c->{editFilePath}  = $outputFilePath;
		$c->{inputFilePath} = '';
	}

	$c->saveFileChanges($outputFilePath);

	# Modify achievement notification template path for the current achievement
	$c->{achievement}->email_template($new_file_name);
	if ($c->db->putAchievement($c->{achievement})) {
		$c->addgoodmessage($c->maketext(
			'The achievement notification template for [_1] has been renamed to "[_2]".', $achievementName,
			$c->shortPath($outputFilePath)
		));
	} else {
		$c->addbadmessage($c->maketext(
			'Unable to change the achievement notification template for achivement [_1]. Unknown error.',
			$achievementName
		));
	}

	# A redirect is needed to ensure that all data and parameters for page display are updated correctly.
	# FIXME: This could be done without a redirect if the data and parameters were updated here instead.
	$c->authen->flash(status_message => $c->{status_message}->join(''));
	$c->reply_with_redirect($c->systemLink(
		$c->url_for('instructor_achievement_notification', achievementID => $achievementName)));
	return;
}

# use an existing template file
sub existing_handler ($c) {
	my $achievementID = $c->stash('achievementID');

	# Get the desired file name from form data.
	my $sourceFile = $c->param('action.existing.target_file') || '';

	if (-e $c->ce->{courseDirs}{achievement_notifications} . "/$sourceFile") {
		# If it exists, update the achievement to use the existing email template.
		$c->{achievement}->email_template($sourceFile);
		if ($c->db->putAchievement($c->{achievement})) {
			$c->addgoodmessage($c->maketext(
				'The notification for [_1] has been changed to "[_2]".', $achievementID, $sourceFile));
		} else {
			$c->addbadmessage($c->maketext(
				'Unable to change the notification for [_1]. Unknown error.', $achievementID));
		}
	} else {
		$c->addbadmessage($c->maketext('The file "[_1]" cannot be found.', $sourceFile));
	}

	# A redirect is needed to ensure that all data and parameters for page display are updated correctly.
	# FIXME: This could be done without a redirect if the data and parameters were updated here instead.
	$c->authen->flash(status_message => $c->{status_message}->join(''));
	$c->reply_with_redirect($c->systemLink(
		$c->url_for('instructor_achievement_notification', achievementID => $achievementID)));
	return;
}

sub disable_handler ($c) {
	$c->{achievement}->email_template('');

	if ($c->db->putAchievement($c->{achievement})) {
		$c->addgoodmessage($c->maketext(
			'The achievement notification template for achievement [_1] has been disabled.',
			$c->stash('achievementID')
		));

		# Redirect to the instructor_achievement_list.
		$c->authen->flash(status_message => $c->{status_message}->join(''));
		$c->reply_with_redirect($c->systemLink($c->url_for('instructor_achievement_list')));
	} else {
		$c->addbadmessage($c->maketext(
			'Unable to disable the achievement notification template for achievement [_1]. Unknown error.',
			$c->stash('achievementID')
		));
	}

	return;
}

1;
