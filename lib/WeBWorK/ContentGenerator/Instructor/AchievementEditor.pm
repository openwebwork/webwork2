package WeBWorK::ContentGenerator::Instructor::AchievementEditor;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::AchievementEditor - edit an achievement evaluator file

=cut

use HTML::Entities;
use File::Copy;

use WeBWorK::Utils               qw(fix_newlines not_blank x);
use WeBWorK::Utils::Files        qw(surePathToFile readFile);
use WeBWorK::Utils::Achievements qw(getAchievementAssetPaths isAchievementAssetSafe);

use constant ACTION_FORMS => [qw(save save_as revert)];
use constant ACTION_FORM_TITLES => {
	save    => x('Save'),
	save_as => x('Save As'),
	revert  => x('Revert')
};

use constant DEFAULT_ICON => 'defaulticon.png';

sub pre_header_initialize ($c) {
	my $ce    = $c->ce;
	my $authz = $c->authz;
	my $user  = $c->param('user');

	# Make sure that are defined for the templates.
	$c->stash->{formsToShow}         = ACTION_FORMS();
	$c->stash->{actionFormTitles}    = ACTION_FORM_TITLES();
	$c->stash->{achievementContents} = '';

	return unless $authz->hasPermissions($user, 'edit_achievements');

	my $Achievement = $c->db->getAchievement($c->stash('achievementID'));
	unless ($Achievement) {
		$c->addbadmessage($c->maketext('Achievement "[_1]" not found!', $c->stash('achievementID')));
		return;
	}

	my $sourceFile = $Achievement->test;
	my ($courseFilePath, $systemFilePath) = getAchievementAssetPaths($ce, 'test', $sourceFile);
	if ($courseFilePath) {
		$c->{sourceFilePath} = $courseFilePath;
	} elsif ($systemFilePath) {
		$c->{sourceFilePath}        = $systemFilePath;
		$c->{sourceFileIsProtected} = 1;
	} else {
		$c->addbadmessage($c->maketext('The achievement evaluator "[_1]" cannot be found.', $sourceFile));
		return;
	}

	$c->{achievement} = $Achievement;
	$c->{sourceFile}  = $sourceFile;

	my $actionID = $c->param('action');
	if ($actionID) {
		unless (grep { $_ eq $actionID } @{ ACTION_FORMS() }) {
			die "Action $actionID not found";
		}

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

	# Find the text for the achievement.
	unless (not_blank($c->stash->{achievementContents})) {
		eval { $c->stash->{achievementContents} = readFile($sourceFilePath) };
		$c->stash->{achievementContents} = $@ if $@;
	}

	return;
}

# Prepend [ACHEVDIR] to filename.
sub addBasePath ($c, $file) {
	return "[ACHEVDIR]/$file";
}

# saveFileChanges does the work of saving the file for both the save_handler and the save_as_handler.
# Validate $outputFile before calling this method to produce error messages.
sub saveFileChanges ($c, $outputFile) {
	my $ce = $c->ce;

	# One last validation check for safety.
	return 0 unless $outputFile && isAchievementAssetSafe($outputFile);

	my $outputFilePath = "$ce->{courseDirs}{achievements}/$outputFile";
	surePathToFile($ce->{courseDirs}{achievements}, $outputFilePath);
	eval {
		open my $OUTPUTFILE, '>', $outputFilePath or die "Failed to open $outputFilePath";
		print $OUTPUTFILE $c->stash->{achievementContents};
		close $OUTPUTFILE;
	};

	my $writeFileErrors = $@;
	if ($writeFileErrors) {
		my $errorMessage;
		# Check why we failed to give better error messages.
		if (not -d $ce->{courseDirs}{achievements}) {
			$errorMessage = $c->maketext('Course achievements directory does not exist.  File not saved.');
		} elsif (not -w $ce->{courseDirs}{achievements}) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled in the templates directory.  No changes can be made.');
		} elsif (-f $outputFilePath and not -w $outputFilePath) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled for "[_1]".  '
					. 'Changes must be saved to another file for viewing.',
				$c->addBasePath($outputFile)
			);
		} else {
			$errorMessage =
				$c->maketext('Unable to write to "[_1]": [_2]', $c->addBasePath($outputFile), $writeFileErrors);
		}
		$c->addbadmessage($errorMessage);
	} else {
		$c->addgoodmessage($c->maketext('Saved to file "[_1]".', $c->addBasePath($outputFile)));
	}

	return $writeFileErrors ? 0 : 1;
}

# This is only called after $c->{sourceFile} has been validated and no additional validation is needed.
sub save_handler ($c) {
	my $ce = $c->ce;

	$c->stash->{achievementContents} = fix_newlines($c->param('achievementContents'));
	# Update source file if file is successfully saved.
	if ($c->saveFileChanges($c->{sourceFile})) {
		$c->{sourceFilePath}        = "$ce->{courseDirs}{achievements}/$c->{sourceFile}";
		$c->{sourceFileIsProtected} = 0;
	}
	return;
}

sub save_as_handler ($c) {
	my $db = $c->db;
	my $ce = $c->ce;

	my $courseName        = $c->stash('courseID');
	my $achievementName   = $c->stash('achievementID');
	my $effectiveUserName = $c->param('effectiveUser');

	my $saveMode            = $c->param('action.save_as.saveMode')    || 'no_save_mode_selected';
	my $new_file_name       = $c->param('action.save_as.target_file') || '';
	my $targetAchievementID = $c->param('action.save_as.id')          || '';

	$c->stash->{achievementContents} = fix_newlines($c->param('achievementContents'));

	$new_file_name =~ s/^\s*//;    # Remove initial and final white space.
	$new_file_name =~ s/\s*$//;
	if ($new_file_name !~ /\S/) {
		$c->addbadmessage($c->maketext('Please specify a file to save to.'));
		return;
	}

	# Rescue the user in case they forgot to end the file name with .at.
	$new_file_name .= '.at' unless $new_file_name =~ /\.at$/;

	# Reject filenames that end in a slash (previous rescue means they now end in "/.at") or unsafe paths.
	if ($new_file_name =~ /\/\.at$/ || !isAchievementAssetSafe($new_file_name)) {
		$c->addbadmessage(
			$c->maketext('Achievement evaluator "[_1]" not saved because filename is unsafe.', $new_file_name));
		return;
	}

	my $outputFilePath = "$ce->{courseDirs}{achievements}/$new_file_name";
	if (-f $outputFilePath) {
		$c->addbadmessage($c->maketext(
			'File "[_1]" exists.  File not saved.  No changes have been made.',
			$c->addBasePath($new_file_name)
		));
		return;
	} elsif ($saveMode eq 'use_in_new' && !$targetAchievementID) {
		$c->addbadmessage(
			$c->maketext('No new Achievement ID specified.  No new achievement created.  File not saved.'));
		return;
	} elsif ($saveMode eq 'use_in_new' && $db->existsAchievement($targetAchievementID)) {
		$c->addbadmessage($c->maketext('Achievement ID exists!  No new achievement created.  File not saved.'));
		return;
	}
	return unless $c->saveFileChanges($new_file_name);
	unless ($saveMode eq 'dont_use') {
		$c->{sourceFile}     = $new_file_name;
		$c->{sourceFilePath} = $outputFilePath;
	}

	if ($saveMode eq 'use_in_current' and -r $outputFilePath) {
		my $achievement = $c->{achievement};
		$achievement->test($new_file_name);
		if ($c->db->putAchievement($achievement)) {
			$c->addgoodmessage($c->maketext(
				'The evaluator for [_1] has been renamed to "[_2]".', $achievementName,
				$c->addBasePath($new_file_name)
			));
		} else {
			$c->addbadmessage(
				$c->maketext('Unable to change the evaluator for set [_1]. Unknown error.', $achievementName));
		}
	} elsif ($saveMode eq 'use_in_new') {
		my $achievement = $c->db->newAchievement();
		$achievement->achievement_id($targetAchievementID);
		$achievement->test($new_file_name);
		$achievement->icon(DEFAULT_ICON());

		$c->db->addAchievement($achievement);
		$c->addgoodmessage($c->maketext(
			'Achievement [_1] created with evaluator "[_2]".', $targetAchievementID,
			$c->addBasePath($new_file_name)
		));
		$c->{achievement} = $achievement;
	} elsif ($saveMode eq 'dont_use') {
		# Don't change any achievements - just report.
		$c->addgoodmessage($c->maketext(
			'A new file has been created at "[_1]". Editing original achievement evaluator "[_2]".',
			$c->addBasePath($new_file_name),
			$c->{sourceFile}
		));
		# FIXME: Currently editor cannot edit a file not associated with an achievement.
		# Update saved data so the editor correctly shows/edits the original achievement evaluator.
		$c->stash->{achievementContents} = '';
	} else {
		$c->addbadmessage($c->maketext(q{Don't recognize saveMode: |[_1]|. Unknown error.}, $saveMode));
	}

	return;
}

sub revert_handler ($c) {
	my $ce            = $c->ce;
	my $sourceFile    = $c->{sourceFile};
	my $confirmDelete = $c->param('action.delete.confirm') // '';
	my $deletePath    = "$ce->{courseDirs}{achievements}/$sourceFile";
	my $systemPath    = "$ce->{webworkDirs}{achievementEvaluators}/$sourceFile";

	# Use form contents in case there is a validation error.
	$c->stash->{achievementContents} = fix_newlines($c->param('achievementContents'));

	unless ($confirmDelete eq 'yes') {
		$c->addbadmessage($c->maketext('Missing delete confirmation of course override. Not deleting.'));
		return;
	}
	unless ($sourceFile !~ /\// && -f $systemPath) {
		$c->addbadmessage(
			$c->maketext('Achievement evaluator "[_1]" is not a course override. Not deleting.', $sourceFile));
		return;
	}
	unless (-f $deletePath) {
		$c->addbadmessage($c->maketext(
			'Achievement evaluator course override "[_1]" does not exist. Not deleting.',
			$c->addBasePath($sourceFile)
		));
		return;
	}

	unlink($deletePath);
	$c->addgoodmessage($c->maketext(
		'Course override "[_1]" deleted. Reverted to using system achievement.',
		$c->addBasePath($sourceFile)
	));
	$c->{sourceFilePath}             = $systemPath;
	$c->{sourceFileIsProtected}      = 1;
	$c->stash->{achievementContents} = '';            # Force loading original system achievement contents.
	return;
}

1;
