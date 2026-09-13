package WeBWorK::ContentGenerator::Instructor::AchievementNotificationEditor;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::AchievementNotificationEditor - edit the achievement notification template

=cut

use WeBWorK::Utils        qw(fix_newlines not_blank x);
use WeBWorK::Utils::Files qw(readFile);

use constant ACTION_FORMS => [qw(save save_as existing disable)];
use constant ACTION_FORM_TITLES => {
	save     => x('Save'),
	save_as  => x('Save As'),
	existing => x('Use Existing Template'),
	disable  => x('Disable Notifications'),
};

sub pre_header_initialize ($c) {
	my $ce    = $c->ce;
	my $authz = $c->authz;
	my $user  = $c->param('user');

	# Make sure that are defined for the templates.
	$c->stash->{formsToShow}             = ACTION_FORMS();
	$c->stash->{actionFormTitles}        = ACTION_FORM_TITLES();
	$c->stash->{achievementNotification} = '';

	return unless $authz->hasPermissions($user, 'edit_achievements');

	my $achievement = $c->db->getAchievement($c->stash('achievementID'));
	unless ($achievement) {
		$c->addbadmessage($c->maketext('Achievement "[_1]" not found!', $c->stash('achievementID')));
		return;
	}

	my $sourceFile = $achievement->email_template || 'default.txt.epl';
	if ($sourceFile =~ /\//) {
		$c->addbadmessage($c->maketext(
			'Achievement notification template "[_1]" filename contains a slash, "/", and cannot be edited.',
			$sourceFile
		));
		return;
	}

	$c->{achievement}    = $achievement;
	$c->{sourceFile}     = $sourceFile;
	$c->{sourceFilePath} = "$ce->{courseDirs}{achievement_notifications}/$sourceFile";

	my $actionID = $c->param('action');
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

	return unless $authz->hasPermissions($user, 'edit_achievements') && $c->{achievement} && $sourceFilePath;

	# Check source file path.
	unless (-f $sourceFilePath) {
		$c->addbadmessage($c->maketext(
			'The achievement notification template file "[_1]" cannot be found.',
			$c->shortPath($c->{sourceFile})
		));
		return;
	}

	# Find the text for the achievement.
	unless (not_blank($c->stash->{achievementNotification})) {
		eval { $c->stash->{achievementNotification} = readFile($sourceFilePath) };
		$c->stash->{achievementNotification} = $@ if $@;
	}

	return;
}

# Append [ACHEVNOTIFYDIR] to filename.
sub shortPath ($c, $file) {
	return "[ACHEVNOTIFYDIR]/$file";
}

# saveFileChanges does the work of saving the file for both the save_handler
# and the save_as_handler. Be sure that $outputFile is validated before calling
# this method (defined, not blank, and does not contain a slash).
sub saveFileChanges ($c, $outputFile) {
	my $ce = $c->ce;

	# This shouldn't be needed, but one last check for safety.
	return 0 if !$outputFile || $outputFile =~ /\//;

	my $outputFilePath = "$ce->{courseDirs}{achievement_notifications}/$outputFile";
	eval {
		open my $OUTPUTFILE, '>', $outputFilePath or die "Failed to open $outputFilePath";
		print $OUTPUTFILE $c->stash->{achievementNotification};
		close $OUTPUTFILE;
	};

	my $writeFileErrors = $@;
	if ($writeFileErrors) {
		my $errorMessage;
		# Check why we failed to give better error messages.
		if (not -d $ce->{courseDirs}{achievement_notifications}) {
			$errorMessage = $c->maketext('Course achievement notifications directory does not exist.  File not saved.');
		} elsif (not -w $ce->{courseDirs}{achievement_notifications}) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled in the templates directory.  No changes can be made.');
		} elsif (-f $outputFilePath and not -w $outputFilePath) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled for "[_1]".  '
					. 'Changes must be saved to another file for viewing.',
				$c->shortPath($outputFile)
			);
		} else {
			$errorMessage =
				$c->maketext('Unable to write to "[_1]": [_2]', $c->shortPath($outputFile), $writeFileErrors);
		}
		$c->addbadmessage($errorMessage);
	} else {
		$c->addgoodmessage($c->maketext('Saved to file "[_1]".', $c->shortPath($outputFile)));
	}

	return $writeFileErrors ? 0 : 1;
}

# This is only called after $c->{sourceFile} has been validated and no additional
# validation is needed.
sub save_handler ($c) {
	$c->stash->{achievementNotification} = fix_newlines($c->param('achievementNotification'));
	$c->saveFileChanges($c->{sourceFile});
	return;
}

sub save_as_handler ($c) {
	my $ce              = $c->ce;
	my $achievementName = $c->stash('achievementID');

	my $new_file_name = $c->param('action.save_as.target_file') || '';

	$c->stash->{achievementNotification} = fix_newlines($c->param('achievementNotification'));

	$new_file_name =~ s/^\s*//;    # Remove initial and final white space.
	$new_file_name =~ s/\s*$//;
	if ($new_file_name !~ /\S/) {
		$c->addbadmessage($c->maketext('Please specify a file to save to.'));
		return;
	} elsif ($new_file_name =~ /\//) {
		$c->addbadmessage($c->maketext('Achievement notification template filenames cannot contain a slash, "/".'));
		return;
	}

	# Rescue the user in case they forgot to end the filename with .txt.epl.
	$new_file_name =~ s/(\.html|\.txt)?(\.epl?)?$/.txt.epl/;

	my $outputFilePath = "$ce->{courseDirs}{achievement_notifications}/$new_file_name";
	if (-e $outputFilePath) {
		$c->addbadmessage($c->maketext(
			'File "[_1]" exists.  File not saved.  No changes have been made.',
			$c->shortPath($new_file_name)
		));
		return;
	}

	return unless $c->saveFileChanges($new_file_name);

	$c->{sourceFile}     = $new_file_name;
	$c->{sourceFilePath} = $outputFilePath;

	$c->{achievement}->email_template($new_file_name);
	if ($c->db->putAchievement($c->{achievement})) {
		$c->addgoodmessage($c->maketext(
			'The achievement notification template for "[_1]" has been renamed to "[_2]".', $achievementName,
			$c->shortPath($new_file_name)
		));
	} else {
		$c->addbadmessage($c->maketext(
			'Unable to change the achievement notification template for achievement "[_1]". Unknown error.',
			$achievementName
		));
	}

	return;
}

# use an existing template file
sub existing_handler ($c) {
	my $ce            = $c->ce;
	my $achievementID = $c->stash('achievementID');
	my $sourceFile    = $c->param('action.existing.target_file') || '';

	if ($sourceFile =~ /\//) {
		$c->addbadmessage($c->maketext('Achievement notification template filenames cannot contain a slash, "/".'));
		return;
	}

	if (-f "$ce->{courseDirs}{achievement_notifications}/$sourceFile") {
		# If it exists, update the achievement to use the existing email template.
		$c->{achievement}->email_template($sourceFile);
		if ($c->db->putAchievement($c->{achievement})) {
			$c->{sourceFile}                     = $sourceFile;
			$c->{sourceFilePath}                 = "$ce->{courseDirs}{achievement_notifications}/$sourceFile";
			$c->stash->{achievementNotification} = '';    # Force loading the newly selected template's contents.
			$c->addgoodmessage($c->maketext(
				'The notification for "[_1]" has been changed to "[_2]".',
				$achievementID, $sourceFile
			));
		} else {
			$c->addbadmessage($c->maketext(
				'Unable to change the notification for "[_1]". Unknown error.', $achievementID));
		}
	} else {
		$c->addbadmessage($c->maketext('The file "[_1]" cannot be found.', $c->shortPath($sourceFile)));
	}

	return;
}

sub disable_handler ($c) {
	$c->{achievement}->email_template('');

	if ($c->db->putAchievement($c->{achievement})) {
		$c->addgoodmessage($c->maketext(
			'The achievement notification template for "[_1]" has been disabled.',
			$c->stash('achievementID')
		));

		# Redirect to the instructor_achievement_list.
		$c->authen->flash(status_message => $c->{status_message}->join(''));
		$c->reply_with_redirect($c->systemLink($c->url_for('instructor_achievement_list')));
	} else {
		$c->addbadmessage($c->maketext(
			'Unable to disable the achievement notification template for "[_1]". Unknown error.',
			$c->stash('achievementID')
		));
	}

	return;
}

1;
