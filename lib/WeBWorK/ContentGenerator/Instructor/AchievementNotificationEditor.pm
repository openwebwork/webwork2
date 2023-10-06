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
	my $achievement = $c->db->getAchievement($achievementID);

	if (!$achievement) {
		$c->addbadmessage($c->maketext("Achievement [_1] not found!", $achievementID));
		return;
	}

	$c->{achievement} = $achievement;
	my $template_filename = $achievement->email_template || "default.html.ep";
	$c->{sourceFilePath} = $c->ce->{courseDirs}{achievements} . "/$template_filename";

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

	$c->addmessage($c->param('status_message') || '');    # Record status messages carried over from a redirect

	# Check source file path
	if (not(-e $sourceFilePath)) {
		$c->addbadmessage($c->maketext('The file [_1] cannot be found.', $sourceFilePath));
		return;
	}

	# Find the text for the achievement.
	unless ($c->stash('achievementNotification') =~ /\S/) {
		unless (path_is_subdir($sourceFilePath, $c->ce->{courseDirs}{achievements}, 1)) {
			$c->addbadmessage('Path is Unsafe!');
			return;
		}

		eval { $c->stash->{achievementNotification} = WeBWorK::Utils::readFile($sourceFilePath); };
		$c->stash->{achievementNotification} = $@ if $@;
	}

	return;
}

# Convert long paths to [ACHEVDIR]
sub shortPath ($c, $file) {
	my $ache = $c->ce->{courseDirs}{achievements};
	$file =~ s|^$ache|[ACHEVDIR]|;
	return $file;
}

sub getRelativeSourceFilePath ($c, $sourceFilePath) {
	my $achievementsDir = $c->ce->{courseDirs}{achievements};
	$sourceFilePath =~ s|^${achievementsDir}/*||;    # remove templates path and any slashes that follow
	return $sourceFilePath;
}

# saveFileChanges does most of the work. It is a separate method so that it can
# be called from either pre_header_initialize or initilize, depending on
# whether a redirect is needed or not.
sub saveFileChanges ($c, $outputFilePath, $achievementNotification = undef) {
	my $ce = $c->ce;

	if (ref($achievementNotification)) {
		$achievementNotification = ${$achievementNotification};
	} elsif (!not_blank($achievementNotification)) {    # if the achievementNotification is undefined or empty
		$achievementNotification = $c->stash('achievementNotification');
	}

	unless (not_blank($outputFilePath)) {
		$c->addbadmessage($c->maketext('You must specify an file name in order to save a new file.'));
		return;
	}

	# write changes to the approriate files
	# FIXME  make sure that the permissions are set correctly!!!
	# Make sure that the warning is being transmitted properly.

	# make sure any missing directories are created
	WeBWorK::Utils::surePathToFile($ce->{courseDirs}{achievements}, $outputFilePath);
	die 'outputFilePath is unsafe!'
		unless path_is_subdir($outputFilePath, $ce->{courseDirs}{achievements}, 1);

	eval {
		open my $OUTPUTFILE, '>', $outputFilePath
			or die "Failed to open $outputFilePath";
		print $OUTPUTFILE $achievementNotification;
		close $OUTPUTFILE;
	};
	my $writeFileErrors = $@ if $@;

	# Catch errors in saving files,
	if ($writeFileErrors) {
		# Get the current directory from the outputFilePath
		$outputFilePath =~ m|^(/.*?/)[^/]+$|;
		my $currentDirectory = $1;

		my $errorMessage;

		# Check why we failed to give better error messages
		if (not -w $ce->{courseDirs}{achievements}) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled in the templates directory.  No changes can be made.');
		} elsif (not -w $currentDirectory) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled in "[_1]".  '
					. 'Changes must be saved to a different directory for viewing.',
				$c->shortPath($currentDirectory)
			);
		} elsif (-e $outputFilePath and not -w $outputFilePath) {
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
	$c->stash->{achievementNotification} =
		fix_newlines($c->param('achievementNotification'));

	# Construct the output file path
	$c->saveFileChanges($c->{sourceFilePath});
	return;
}

sub save_as_handler ($c) {
	my $db = $c->db;
	$c->{status_message} = $c->c;    ## DPVC -- remove bogus old messages
	my $courseName        = $c->stash('courseID');
	my $achievementName   = $c->stash('achievementID');
	my $effectiveUserName = $c->param('effectiveUser');

	my $do_not_save         = 0;
	my $saveMode            = $c->param('action.save_as.saveMode')    || 'no_save_mode_selected';
	my $new_file_name       = $c->param('action.save_as.target_file') || '';
	my $sourceFilePath      = $c->param('action.save_as.source_file') || '';
	my $targetAchievementID = $c->param('action.save_as.id')          || '';

	$c->{sourceFilePath} = $sourceFilePath;    # store for use in saveFileChanges
	$new_file_name =~ s/^\s*//;                #remove initial and final white space
	$new_file_name =~ s/\s*$//;
	if ($new_file_name !~ /\S/) {              # need a non-blank file name
											   # setting $c->{failure} stops saving and any redirects
		$do_not_save = 1;
		$c->addbadmessage($c->maketext('Please specify a file to save to.'));
	}

	# Grab the achievementNotification from the form in order to save it to a new permanent file
	$c->stash->{achievementNotification} =
		fix_newlines($c->param('achievementNotification'));
	warn 'achievement contents is empty'
		unless $c->stash->{achievementNotification};

	# Rescue the user in case they forgot to end the file name with .ep
	$new_file_name =~ s/\.ep$//;    # remove it if it is there
	$new_file_name .= '.ep';        # put it there

	# Construct the output file path
	my $outputFilePath = $c->ce->{courseDirs}{achievements} . '/' . $new_file_name;
	if (defined $outputFilePath and -e $outputFilePath) {

		# setting $do_not_save stops saving and any redirects
		$do_not_save = 1;
		$c->addbadmessage($c->maketext(
			'File "[_1]" exists.  File not saved.  No changes have been made.',
			$c->shortPath($outputFilePath)
		));
	} elsif ($saveMode eq 'use_in_new' && !$targetAchievementID) {
		$c->addbadmessage(
			$c->maketext('No new Achievement ID specified.  No new achievement created.  File not saved.'));
		$do_not_save = 1;

	} elsif ($saveMode eq 'use_in_new'
		&& $db->existsAchievement($targetAchievementID))
	{
		$c->addbadmessage($c->maketext('Achievement ID exists!  No new achievement created.  File not saved.'));
		$do_not_save = 1;
	} else {
		$c->{editFilePath}  = $outputFilePath;
		$c->{inputFilePath} = '';
	}

	return '' if $do_not_save;

	#Save changes
	$c->saveFileChanges($outputFilePath);

	if ($saveMode eq 'use_in_current' and -r $outputFilePath) {

		# Modify evaluator path in current achievement
		my $achievement = $c->db->getAchievement($achievementName);
		$achievement->email_template($new_file_name);
		if ($c->db->putAchievement($achievement)) {
			$c->addgoodmessage($c->maketext(
				'The evaluator for [_1] has been renamed to "[_2]".', $achievementName,
				$c->shortPath($outputFilePath)
			));
		} else {
			$c->addbadmessage($c->maketext(
				'Unable to change the evaluator for set [_1]. Unknown error.', $achievementName));
		}

	} elsif ($saveMode eq 'dont_use') {
		# Don't change any achievements - just report
		$c->addgoodmessage($c->maketext('A new file has been created at "[_1]"', $c->shortPath($outputFilePath)));
	} else {
		$c->addbadmessage($c->maketext(q{Don't recognize saveMode: |[_1]|. Unknown error.}, $saveMode));
	}

	# Set up redirect
	# The redirect gives the server time to detect that the new file exists.
	$c->reply_with_redirect($c->systemLink(
		$c->url_for(
			'instructor_achievement_notification', achievementID => $achievementName
		),
		params => {
			sourceFilePath => $c->getRelativeSourceFilePath($outputFilePath),
			status_message => $c->{status_message}->join('')
		}
	));
	return;
}

# use an existing template file
sub existing_handler ($c) {
	my $db            = $c->db;
	my $ce            = $c->ce;
	my $achievementID = $c->stash('achievementID');

	# get the desired file name from formdata
	my $sourceFile = $c->param('action.existing.target_file') || '';

	if (-e $ce->{courseDirs}{achievements} . "/$sourceFile") {

		# if it exists, update the achievement to use the existing email template
		my $achievement = $db->getAchievement($achievementID);
		$achievement->email_template($sourceFile);
		if ($db->putAchievement($achievement)) {
			$c->addgoodmessage($c->maketext(
				'The notification for [_1] has been changed to "[_2]".', $achievementID, $sourceFile));
		} else {
			$c->addbadmessage($c->maketext(
				'Unable to change the notification for [_1]. Unknown error.', $achievementID));
		}
	} else {
		$c->addbadmessage($c->maketext('The file "[_1]" cannot be found.', $sourceFile));
		return;
	}

	# is this necessary? the achievement DID update...
	$c->reply_with_redirect($c->systemLink(
		$c->url_for(
			'instructor_achievement_notification', achievementID => $achievementID
		),
		params => {
			status_message => $c->{status_message}->join(''),
		}
	));
	return;
}

sub disable_handler ($c) {
	my $db            = $c->db;
	my $ce            = $c->ce;
	my $achievementID = $c->stash('achievementID');

	my $achievement = $c->db->getAchievement($achievementID);
	$achievement->email_template('');

	if ($c->db->putAchievement($achievement)) {
		$c->addgoodmessage($c->maketext('The evaluator for [_1] has been disabled.', $achievementID));

		# redirect to the instructor_achievement_list
		$c->reply_with_redirect($c->systemLink(
			$c->url_for('instructor_achievement_list'),
			params => {
				status_message => $c->{status_message}->join('')
			}
		));
	} else {
		$c->addbadmessage($c->maketext('Unable to disable the evaluator for [_1]. Unknown error.', $achievementID));
	}

}

1;
