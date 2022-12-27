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

package WeBWorK::ContentGenerator::Instructor::AchievementEditor;
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::AchievementEditor - edit an achevement evaluator file

=cut

use strict;
use warnings;

use HTML::Entities;
use URI::Escape;
use File::Copy;

use WeBWorK::Utils qw(not_blank path_is_subdir x);

use constant ACTION_FORMS => [qw(save save_as)];
use constant ACTION_FORM_TITLES => {
	save    => x('Save'),
	save_as => x('Save As'),
};

use constant DEFAULT_ICON => 'defaulticon.png';

async sub pre_header_initialize {
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $urlpath = $r->urlpath;
	my $authz   = $r->authz;
	my $user    = $r->param('user');
	$self->{courseID}      = $urlpath->arg('courseID');
	$self->{achievementID} = $r->urlpath->arg('achievementID');

	# Make sure that are defined for the templates.
	$r->stash->{formsToShow}         = ACTION_FORMS();
	$r->stash->{actionFormTitles}    = ACTION_FORM_TITLES();
	$r->stash->{achievementContents} = '';

	# Check permissions
	return unless ($authz->hasPermissions($user, 'edit_achievements'));

	# Get the achievement
	my $Achievement = $r->db->getAchievement($self->{achievementID});

	if (!$Achievement) {
		$self->addbadmessage("Achievement $self->{achievementID} not found!");
		return;
	}

	$self->{achievement}    = $Achievement;
	$self->{sourceFilePath} = $ce->{courseDirs}{achievements} . '/' . $Achievement->test;

	my $actionID = $r->param('action');

	# Perform a save or save_as action
	if ($actionID) {
		unless (grep { $_ eq $actionID } @{ ACTION_FORMS() }) {
			die "Action $actionID not found";
		}

		my $actionHandler = "${actionID}_handler";
		$self->$actionHandler;
	}

	return;
}

sub initialize {
	my ($self)         = @_;
	my $r              = $self->r;
	my $authz          = $r->authz;
	my $user           = $r->param('user');
	my $sourceFilePath = $self->{sourceFilePath};

	return unless ($authz->hasPermissions($user, 'edit_achievements'));

	$self->addmessage($r->param('status_message') || '');    # Record status messages carried over from a redirect

	# Check source file path
	if (not(-e $sourceFilePath)) {
		$self->addbadmessage('The file "' . $self->shortPath($sourceFilePath) . '" cannot be found.');
		return;
	}

	# Find the text for the achievement.
	unless ($r->stash->{achievementContents} =~ /\S/) {
		unless (path_is_subdir($sourceFilePath, $r->ce->{courseDirs}{achievements}, 1)) {
			$self->addbadmessage('Path is Unsafe!');
			return;
		}

		eval { $r->stash->{achievementContents} = WeBWorK::Utils::readFile($sourceFilePath) };
		$r->stash->{achievementContents} = $@ if $@;
	}

	return;
}

sub path {
	my ($self, $args) = @_;
	my $r          = $self->r;
	my $urlpath    = $r->urlpath;
	my $courseName = $urlpath->arg('courseID');

	# Build a path to the achievement being edited by hand, since it is not the same as the urlpath.
	# For this page the breadcrumb path shows the achievement being edited.
	return $self->pathMacro(
		$args,
		'WeBWork'                         => $r->location,
		$courseName                       => $r->location . "/$courseName",
		$r->maketext('Achievement')       => $r->location . "/$courseName/instructor/achievement_list",
		$r->urlpath->arg('achievementID') => undef
	);
}

sub title {
	my $self = shift;
	my $r    = $self->r;

	return $r->maketext('Achievement Evaluator for achievement [_1]', $r->urlpath->arg('achievementID'));
}

# Convert long paths to [ACHEVDIR]
sub shortPath {
	my $self = shift;
	my $file = shift;
	my $ache = $self->r->ce->{courseDirs}{achievements};
	$file =~ s|^$ache|[ACHEVDIR]|;
	return $file;
}

sub getRelativeSourceFilePath {
	my ($self, $sourceFilePath) = @_;

	my $achievementsDir = $self->r->ce->{courseDirs}->{achievements};
	$sourceFilePath =~ s|^${achievementsDir}/*||;    # remove templates path and any slashes that follow

	return $sourceFilePath;
}

# saveFileChanges does most of the work. It is a separate method so that it can
# be called from either pre_header_initialize or initilize, depending on
# whether a redirect is needed or not.
sub saveFileChanges {
	my ($self, $outputFilePath, $achievementContents) = @_;

	my $r  = $self->r;
	my $ce = $r->ce;

	if (defined($achievementContents) and ref($achievementContents)) {
		$achievementContents = ${$achievementContents};
	} elsif (!not_blank($achievementContents)) {    # if the AchievementContents is undefined or empty
		$achievementContents = $self->r->stash->{achievementContents};
	}

	unless (not_blank($outputFilePath)) {
		$self->addbadmessage($r->maketext('You must specify an file name in order to save a new file.'));
		return '';
	}
	my $do_not_save = 0;                            # flag to prevent saving of file
	my $editErrors  = '';

	# write changes to the approriate files
	# FIXME  make sure that the permissions are set correctly!!!
	# Make sure that the warning is being transmitted properly.

	my $writeFileErrors;
	if (not_blank($outputFilePath)) {    # save file

		# make sure any missing directories are created
		WeBWorK::Utils::surePathToFile($ce->{courseDirs}->{achievements}, $outputFilePath);
		die 'outputFilePath is unsafe!'
			unless path_is_subdir($outputFilePath, $ce->{courseDirs}->{achievements}, 1);

		eval {
			open my $OUTPUTFILE, '>', $outputFilePath or die "Failed to open $outputFilePath";
			print $OUTPUTFILE $achievementContents;
			close $OUTPUTFILE;
		};

		$writeFileErrors = $@ if $@;
	}

	# Catch errors in saving files,
	$self->{saveError} = $do_not_save;    # Don't do redirects if the file was not saved.
										  # Don't unlink files or send success messages

	if ($writeFileErrors) {
		# Get the current directory from the outputFilePath
		$outputFilePath =~ m|^(/.*?/)[^/]+$|;
		my $currentDirectory = $1;

		my $errorMessage;
		# Check why we failed to give better error messages
		if (not -w $ce->{courseDirs}->{achievements}) {
			$errorMessage = $r->maketext(
				'Write permissions have not been enabled in the templates directory.  No changes can be made.');
		} elsif (not -w $currentDirectory) {
			$errorMessage = $r->maketext(
				'Write permissions have not been enabled in "[_1]".  '
					. 'Changes must be saved to a different directory for viewing.',
				$self->shortPath($currentDirectory)
			);
		} elsif (-e $outputFilePath and not -w $outputFilePath) {
			$errorMessage = $r->maketext(
				'Write permissions have not been enabled for "[_1]".  '
					. 'Changes must be saved to another file for viewing.',
				$self->shortPath($outputFilePath)
			);
		} else {
			$errorMessage =
				$r->maketext('Unable to write to "[_1]": [_2]', $self->shortPath($outputFilePath), $writeFileErrors);
		}

		$self->{failure} = 1;
		$self->addbadmessage($errorMessage);
	}

	if (!$writeFileErrors && !$do_not_save && defined $outputFilePath && !$self->{failure}) {
		$self->addgoodmessage($r->maketext('Saved to file "[_1]"', $self->shortPath($outputFilePath)));
	}
}

sub fixAchievementContents {
	my $AchievementContents = shift;
	# Handle the problem of line endings.
	# Make sure that all of the line endings are of unix type.
	# Convert \r\n to \n
	$AchievementContents =~ s/\r\n/\n/g;
	$AchievementContents =~ s/\r/\n/g;
	return $AchievementContents;
}

sub save_handler {
	my ($self)          = @_;
	my $r               = $self->r;
	my $courseName      = $self->{courseID};
	my $achievementName = $self->{achievementID};

	# Grab the achievementContents from the form in order to save it to the source path
	$self->r->stash->{achievementContents} = fixAchievementContents($self->r->param('achievementContents'));

	# Construct the output file path
	$self->saveFileChanges($self->{sourceFilePath});

	return;
}

sub save_as_handler {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	$self->{status_message} = $r->c;    ## DPVC -- remove bogus old messages
	my $courseName        = $self->{courseID};
	my $achievementName   = $self->{achievementID};
	my $effectiveUserName = $self->r->param('effectiveUser');

	my $do_not_save         = 0;
	my $saveMode            = $r->param('action.save_as.saveMode')    || 'no_save_mode_selected';
	my $new_file_name       = $r->param('action.save_as.target_file') || '';
	my $sourceFilePath      = $r->param('action.save_as.source_file') || '';
	my $targetAchievementID = $r->param('action.save_as.id')          || '';

	$self->{sourceFilePath} = $sourceFilePath;    # store for use in saveFileChanges
	$new_file_name =~ s/^\s*//;                   #remove initial and final white space
	$new_file_name =~ s/\s*$//;
	if ($new_file_name !~ /\S/) {                 # need a non-blank file name
												  # setting $self->{failure} stops saving and any redirects
		$do_not_save = 1;
		$self->addbadmessage($r->maketext('Please specify a file to save to.'));
	}

	# Grab the achievementContents from the form in order to save it to a new permanent file
	$self->r->stash->{achievementContents} = fixAchievementContents($self->r->param('achievementContents'));
	warn 'achievement contents is empty' unless $self->r->stash->{achievementContents};

	# Rescue the user in case they forgot to end the file name with .at
	$new_file_name =~ s/\.at$//;    # remove it if it is there
	$new_file_name .= '.at';        # put it there

	# Construct the output file path
	my $outputFilePath = $self->r->ce->{courseDirs}->{achievements} . '/' . $new_file_name;
	if (defined $outputFilePath and -e $outputFilePath) {
		# setting $do_not_save stops saving and any redirects
		$do_not_save = 1;
		$self->addbadmessage($r->maketext(
			'File "[_1]" exists.  File not saved.  No changes have been made.',
			$self->shortPath($outputFilePath)
		));
	} elsif ($saveMode eq 'use_in_new' && !$targetAchievementID) {
		$self->addbadmessage(
			$r->maketext('No new Achievement ID specified.  No new achievement created.  File not saved.'));
		$do_not_save = 1;

	} elsif ($saveMode eq 'use_in_new' && $db->existsAchievement($targetAchievementID)) {
		$self->addbadmessage($r->maketext('Achievement ID exists!  No new achievement created.  File not saved.'));
		$do_not_save = 1;
	} else {
		$self->{editFilePath}  = $outputFilePath;
		$self->{inputFilePath} = '';
	}

	return '' if $do_not_save;

	#Save changes
	$self->saveFileChanges($outputFilePath);

	if ($saveMode eq 'use_in_current' and -r $outputFilePath) {
		# Modify evaluator path in current achievement
		my $achievement = $self->r->db->getAchievement($achievementName);
		$achievement->test($new_file_name);
		if ($self->r->db->putAchievement($achievement)) {
			$self->addgoodmessage($r->maketext(
				'The evaluator for [_1] has been renamed to "[_2]".', $achievementName,
				$self->shortPath($outputFilePath)
			));
		} else {
			$self->addbadmessage(
				$r->maketext('Unable to change the evaluator for set [_1]. Unknown error.', $achievementName));
		}

	} elsif ($saveMode eq 'use_in_new') {
		# Create a new achievement to use the evaluator in
		my $achievement = $self->r->db->newAchievement();
		$achievement->achievement_id($targetAchievementID);
		$achievement->test($new_file_name);
		$achievement->icon(DEFAULT_ICON());

		$self->r->db->addAchievement($achievement);
		$self->addgoodmessage($r->maketext(
			'Achievement [_1] created with evaluator "[_2]".', $targetAchievementID,
			$self->shortPath($outputFilePath)
		));

	} elsif ($saveMode eq 'dont_use') {
		# Don't change any achievements - just report
		$self->addgoodmessage($r->maketext('A new file has been created at "[_1]"', $self->shortPath($outputFilePath)));
	} else {
		$self->addbadmessage($r->maketext(q{Don't recognize saveMode: |[_1]|. Unknown error.}, $saveMode));
	}

	# Set up redirect
	# The redirect gives the server time to detect that the new file exists.
	my $problemPage;

	if ($saveMode eq 'dont_use') {
		$problemPage = $self->r->urlpath->newFromModule(
			'WeBWorK::ContentGenerator::Instructor::AchievementEditor', $r,
			courseID      => $courseName,
			achievementID => $achievementName
		);
	} elsif ($saveMode eq 'use_in_current') {
		$problemPage = $self->r->urlpath->newFromModule(
			'WeBWorK::ContentGenerator::Instructor::AchievementEditor', $r,
			courseID      => $courseName,
			achievementID => $achievementName
		);
	} elsif ($saveMode eq 'use_in_new') {
		$problemPage = $self->r->urlpath->newFromModule(
			'WeBWorK::ContentGenerator::Instructor::AchievementEditor', $r,
			courseID      => $courseName,
			achievementID => $targetAchievementID
		);
	} else {
		$self->addbadmessage('Please use radio buttons to choose the method for saving this file. '
				. "Can't recognize saveMode: |$saveMode|.");
		# Can't continue since paths have not been properly defined.
		return '';
	}

	my $relativeOutputFilePath = $self->getRelativeSourceFilePath($outputFilePath);

	my $viewURL = $self->systemLink(
		$problemPage,
		params => {
			sourceFilePath => $relativeOutputFilePath,
			status_message => uri_escape_utf8($self->{status_message}->join(''))
		}

	);

	$self->reply_with_redirect($viewURL);
	return;
}

1;
