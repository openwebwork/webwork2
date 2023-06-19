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

package WeBWorK::ContentGenerator::Instructor::PGProblemEditor;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Instructor::PGProblemEditor - Edit a pg file

This editor will edit problem files, set header files, or files such as
course_info whose name is defined in the defaults.config file.

Only files under the template directory (or linked to this location) can be
edited.

The course information and problems are located in the course templates
directory.  Course information has the name defined by
$ce->{courseFiles}{course_info}

editMode = temporaryFile | savedFile

This flag is read by Problem.pm and ProblemSet.pm (perhaps others).

The value of temporaryFile means view the temp file defined by
fname.user_name.tmp instead of the file fname.

The value of savedFile means to use fname directly.

The suffix for a temporary file is "user_name.tmp" by default.

=head2 File types (file_type) which can be edited.

=over

=item problem

This is the most common type. This editor can be called by an instructor when
viewing any problem.  the information for retrieving the source file is found
using the problemID in order to look look up the source file path.

=item source_path_for_problem_file

This is the same as the 'problem' file type except that the source for the
problem is found in the parameter $r->param('sourceFilePath').  This path is
relative to the templates directory

=item set_header

This is a special case of editing the problem.  The set header is often listed
as problem 0 in the set's list of problems.

=item hardcopy_header

This is a special case of editing the problem.  The hardcopy_header is often
listed as problem 0 in the set's list of problems.  But it is used instead of
set_header when producing a hardcopy of the problem set in the TeX format,
instead of producing HTML formatted version for use on the computer screen.

=item course_info

This allows editing of the course_info.txt file which gives general information
about the course.  It is called from the ProblemSets.pm module.

=item blank_problem

This is a special case which allows one to create and edit a new PG problem.
The "stationary" source for this problem is stored in the conf/snippets
directory and defined in defaults.config as
$webworkFiles{screenSnippets}{blankProblem}

=back

=head2 Action

The behavior on submit is defined by the value of $file_type and the value of
the submit button pressed (the action).

    Requested actions and aliases
        Save:                      action = save
        Save as:                   action = save_as
        View Problem:              action = view
        Add this problem to:       action = add_problem
        Make this set header for:  action = add_problem
        Revert:                    action = revert
		Generate Hardcopy:         actoin = hardcopy

An undefined or invalid action is interpreted as an initial edit of the file.

=head2 Notes

The editFilePath and tempFilePath should always be set.  The tempFilePath may
not exist.  The path to the actual file being edited is stored in inputFilePath.

=cut

use File::Copy;

use WeBWorK::Utils qw(jitar_id_to_seq not_blank path_is_subdir seq_to_jitar_id x
	surePathToFile readDirectory readFile max);
use WeBWorK::Utils::Instructor qw(assignProblemToAllSetUsers addProblemToSet);

use constant DEFAULT_SEED => 123456;

# Editor tabs
use constant ACTION_FORMS => [qw(view hardcopy save save_as add_problem revert)];
use constant ACTION_FORM_TITLES => {
	view        => x('View/Reload'),
	hardcopy    => x('Generate Hardcopy'),
	add_problem => x('Append'),
	save        => x('Save'),
	save_as     => x('Save As'),
	revert      => x('Revert'),
};

my $BLANKPROBLEM = 'blankProblem.pg';

sub pre_header_initialize ($c) {
	my $ce    = $c->ce;
	my $authz = $c->authz;
	my $user  = $c->param('user');

	# Check permissions
	return
		unless $authz->hasPermissions($user, 'access_instructor_tools')
		&& $authz->hasPermissions($user, 'modify_problem_sets');

	$c->{courseID}  = $c->stash('courseID');
	$c->{setID}     = $c->stash('setID');
	$c->{problemID} = $c->stash('problemID');

	# Parse setID which may come in with version data
	$c->{fullSetID} = $c->{setID};
	if (defined $c->{fullSetID} && $c->{fullSetID} =~ /^([^,]*),v(\d+)$/) {
		$c->{setID}     = $1;
		$c->{versionID} = $2;
	}

	# Determine displayMode and problemSeed that are needed for viewing the problem.
	# They are also two of the parameters which can be set by the editor.
	# Note that the problem seed may be overridden by the value obtained from the problem record later.
	$c->{displayMode} = $c->param('displayMode') // $ce->{pg}{options}{displayMode};
	$c->{problemSeed} = (($c->param('problemSeed') // '') =~ s/^\s*|\s*$//gr) || DEFAULT_SEED();

	# Save file to permanent or temporary file, then redirect for viewing if it was requested to view in a new window.
	# Any file "saved as" should be assigned to "Undefined_Set" and redirected to be viewed again in the editor.
	# Problems "saved" or 'refreshed' are to be redirected to the Problem.pm module
	# Set headers which are "saved" are to be redirected to the ProblemSet.pm page
	# Hardcopy headers which are "saved" are also to be redirected to the ProblemSet.pm page
	# Course info files are redirected to the ProblemSets.pm page

	# Insure that file_type is defined
	$c->{file_type} = ($c->param('file_type') // '') =~ s/^\s*|\s*$//gr;

	# If file_type has not been defined we are dealing with a set header or regular problem.
	if (!$c->{file_type}) {
		# If sourceFilePath is defined in the form, then the path will be obtained from that.
		# If the problem number is defined and is 0 then a header file is being edited.
		# If the problem number is not zero, a problem is being edited.
		if (not_blank($c->param('sourceFilePath'))) {
			$c->{file_type} =
				$c->param('sourceFilePath') =~ m!/headers/|Header\.pg$! ? 'set_header' : 'source_path_for_problem_file';
		} elsif (defined $c->{problemID}) {
			if ($c->{problemID} =~ /^\d+$/ && $c->{problemID} == 0) {
				$c->{file_type} = 'set_header' unless $c->{file_type} eq 'hardcopy_header';
			} else {
				$c->{file_type} = 'problem';
			}
		} else {
			$c->{file_type} = 'blank_problem';
		}
	}

	# Clean up sourceFilePath and check that sourceFilePath is relative to the templates file
	if ($c->{file_type} eq 'source_path_for_problem_file') {
		my $sourceFilePath = $c->param('sourceFilePath');
		$sourceFilePath =~ s/$ce->{courseDirs}{templates}//;
		$sourceFilePath =~ s|^/||;
		$c->{sourceFilePath} = $sourceFilePath;
	}

	# Initialize these values in case of failure in the getFilePaths method.
	$c->{editFilePath}   = '';
	$c->{tempFilePath}   = '';
	$c->{inputFilePath}  = '';
	$c->{backupBasePath} = '';

	# Determine the paths for the file.
	# getFilePath defines:
	#   $c->{editFilePath}:    path to the permanent file to be edited
	#   $c->{tempFilePath}:    path to the temporary file to be edited with .tmp suffix
	#   $c->{inputFilePath}:   path to the file for input, (this is either the editFilePath or the tempFilePath)
	#   $c->{backupBasePath}:  base path to the backup files
	$c->getFilePaths;

	# Default problem contents
	$c->{r_problemContents} = \'';

	$c->{status_message} //= $c->c;

	# Determine action.  If an invalid action is sent in, assume this is an initial edit.
	$c->{action} = $c->param('action') // '';
	if ($c->{action} && grep { $_ eq $c->{action} } @{ ACTION_FORMS() }) {
		my $actionHandler = "$c->{action}_handler";
		$c->$actionHandler;
	}

	return;
}

sub initialize ($c) {
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;
	my $user  = $c->param('user');

	# Make sure these are defined for the templates.
	$c->stash->{problemContents}  = '';
	$c->stash->{formsToShow}      = ACTION_FORMS();
	$c->stash->{actionFormTitles} = ACTION_FORM_TITLES();

	# Check permissions
	return
		unless $authz->hasPermissions($user, 'access_instructor_tools')
		&& $authz->hasPermissions($user, 'modify_problem_sets');

	my $file_type = $c->param('file_type') || '';

	# Record status messages carried over if this is a redirect
	$c->addmessage($c->param('status_message') || '');

	$c->addbadmessage($c->maketext('Changes in this file have not yet been permanently saved.'))
		if $c->{inputFilePath} eq $c->{tempFilePath} && -r $c->{tempFilePath};

	if (!-e $c->{inputFilePath}) {
		$c->addbadmessage($c->maketext('The file "[_1]" cannot be found.', $c->shortPath($c->{inputFilePath})));
	} elsif (!-w $c->{inputFilePath} && $file_type ne 'blank_problem') {
		$c->addbadmessage($c->maketext(
			'The file "[_1]" is protected! '
				. 'To edit this text you must first make a copy of this file using the "New Version" action below.',
			$c->shortPath($c->{inputFilePath})
		));
	}

	if ($c->{inputFilePath} =~ /$BLANKPROBLEM$/ && $file_type ne 'blank_problem') {
		$c->addbadmessage($c->maketext(
			'The file "[_1]" is a blank problem!'
				. 'To edit this text you must use the "New Version" action below to save it to another file.',
			$c->shortPath($c->{inputFilePath})
		));
	}

	# Find the text for the problem, either in the temporary file if it exists, in the original file in the template
	# directory, or in the problem contents gathered in the initialization phase.

	my $problemContents = ${ $c->{r_problemContents} };

	unless ($problemContents =~ /\S/) {    # non-empty contents
		if (-r $c->{tempFilePath} && !-d $c->{tempFilePath}) {
			if (path_is_subdir($c->{tempFilePath}, $ce->{courseDirs}{templates}, 1)) {
				eval { $problemContents = readFile($c->{tempFilePath}) };
				$problemContents = $@ if $@;
				$c->{inputFilePath} = $c->{tempFilePath};
			} else {
				$c->stash->{file_error} = $c->maketext('Unable to open a temporary file at the given location.');
			}
		} elsif (-r $c->{editFilePath} && !-d $c->{editFilePath}) {
			if (path_is_subdir($c->{editFilePath}, $ce->{courseDirs}{templates}, 1)
				|| $c->{editFilePath} eq $ce->{webworkFiles}{screenSnippets}{setHeader}
				|| $c->{editFilePath} eq $ce->{webworkFiles}{hardcopySnippets}{setHeader}
				|| $c->{editFilePath} eq $ce->{webworkFiles}{screenSnippets}{blankProblem})
			{
				eval { $problemContents = readFile($c->{editFilePath}) };
				$problemContents = $@ if $@;
				$c->{inputFilePath} = $c->{editFilePath};

			} else {
				$c->stash->{file_error} = $c->maketext('The given file path is not a valid location.');
			}
		} else {
			# File not existing is not an error
			$problemContents = '';
		}
	}

	$c->stash->{problemContents} = $problemContents;

	$c->{prettyProblemNumber} = $c->{problemID} // '';
	$c->{set}                 = $c->db->getGlobalSet($c->{setID}) if $c->{setID};
	$c->{prettyProblemNumber} = join('.', jitar_id_to_seq($c->{prettyProblemNumber}))
		if $c->{set} && $c->{set}->assignment_type eq 'jitar';

	return;
}

sub path ($c, $args) {
	# We need to build a path to the problem being edited by hand, since it is not the same as the url path for this
	# page.  The bread crumb path leads back to the problem being edited, not to the Instructor tool.
	return $c->pathMacro(
		$args,
		'WeBWorK'                  => $c->url_for('root'),
		$c->stash('courseID')      => $c->url_for('set_list'),
		($c->stash('setID') // '') => $c->url_for('problem_list'),
		$c->{prettyProblemNumber}  => $c->url_for('problem_detail', problemID => $c->stash('problemID') || ''),
		$c->maketext('Editor')     => ''
	);
}

sub page_title ($c) {
	my $setID     = $c->stash('setID');
	my $problemID = $c->stash('problemID');

	return $c->maketext('Set Header for set [_1]',            $setID) if $c->{file_type} eq 'set_header';
	return $c->maketext('Hardcopy Header for set [_1]',       $setID) if $c->{file_type} eq 'hardcopy_header';
	return $c->maketext('Course Information for course [_1]', $c->stash('courseID'))
		if $c->{file_type} eq 'course_info';

	if ($setID) {
		my $set = $c->db->getGlobalSet($setID);
		if ($set && $set->assignment_type eq 'jitar') {
			$problemID = join('.', jitar_id_to_seq($problemID));
		}
	}

	return $c->maketext('Problem [_1]', $problemID);
}

#  Convert initial path component to [TMPL], [COURSE], or [WW].
sub shortPath ($c, $file) {
	my $tmpl = $c->ce->{courseDirs}{templates};
	my $root = $c->ce->{courseDirs}{root};
	my $ww   = $c->ce->{webworkDirs}{root};
	$file =~ s|^$tmpl|[TMPL]|;
	$file =~ s|^$root|[COURSE]|;
	$file =~ s|^$ww|[WW]|;

	return $file;
}

# Utilities

sub getRelativeSourceFilePath ($c, $sourceFilePath) {
	my $templatesDir = $c->ce->{courseDirs}{templates};
	$sourceFilePath =~ s|^$templatesDir/*||;    # remove templates path and any slashes that follow
	return $sourceFilePath;
}

# determineLocalFilePath constructs a local file path parallel to a library file path
sub determineLocalFilePath ($c, $path) {
	my $default_screen_header_path   = $c->ce->{webworkFiles}{hardcopySnippets}{setHeader};
	my $default_hardcopy_header_path = $c->ce->{webworkFiles}{screenSnippets}{setHeader};
	my $setID                        = $c->{setID} // int(rand(1000));

	if ($path =~ /Library/) {
		# Truncate the url up to a segment such as ...rochesterLibrary/ and prepend local.
		$path =~ s|^.*?Library/|local/|;
	} elsif ($path eq $default_screen_header_path) {
		$path = "set$setID/setHeader.pg";
	} elsif ($path eq $default_hardcopy_header_path) {
		$path = "set$setID/hardcopyHeader.tex";
	} else {
		# If its not in a library we'll just save it locally.
		# FIXME:  This should check to see if a file with the randomly generated name exists.
		$path = 'new_problem_' . int(rand(1000)) . '.pg';
	}
	return $path;
}

# Determine the location of the temporary file.
# This does not create the directories in the path to the file.
# It returns an absolute path to the file.
# $path should be an absolute path to the original file.
sub determineTempEditFilePath ($c, $path) {
	my $user  = $c->param('user');
	my $setID = $c->{setID};

	my $templatesDirectory   = $c->ce->{courseDirs}{templates};
	my $tmpEditFileDirectory = $c->getTempEditFileDirectory();

	$c->addbadmessage($c->maketext('The path to the original file should be absolute.'))
		unless $path =~ m|^/|;

	if ($path =~ /^$tmpEditFileDirectory/) {
		$c->addbadmessage($c->maketext('The path can not be the temporary edit directory.'));
	} else {
		if ($path =~ /^$templatesDirectory/) {
			$path =~ s|^$templatesDirectory||;
			$path =~ s|^/||;                     # remove the initial slash if any
			$path = "$tmpEditFileDirectory/$path.$user.tmp";
		} elsif ($path eq $c->ce->{webworkFiles}{screenSnippets}{blankProblem}) {
			# Handle the case of the blank problem in snippets.
			$path = "$tmpEditFileDirectory/blank.$setID.$user.tmp";
		} elsif ($path eq $c->ce->{webworkFiles}{hardcopySnippets}{setHeader}) {
			# Handle the case of the screen header in snippets.
			$path = "$tmpEditFileDirectory/screenHeader.$setID.$user.tmp";
		} elsif ($path eq $c->ce->{webworkFiles}{screenSnippets}{setHeader}) {
			# Handle the case of the hardcopy header in snippets.
			$path = "$tmpEditFileDirectory/hardcopyHeader.$setID.$user.tmp";
		} else {
			# If all else fails, just use a failsafe filename.  This is reused in all of these cases.
			# This shouldn't be possible in any case.
			$path = "$tmpEditFileDirectory/failsafe.$setID.$user.tmp";
			$c->addbadmessage($c->maketext('The original path is not in a valid location. Using failsafe [_1]', $path));
		}
	}

	return $path;
}

# Determine the original path to a file corresponding to a temporary edit file.
# Returns a path that is relative to the template directory.
sub determineOriginalEditFilePath ($c, $path) {
	my $ce = $c->ce;

	# Unless path is absolute, assume that it is relative to the template directory.
	my $newpath = $path =~ m|^/| ? $path : "$ce->{courseDirs}{templates}/$path";

	if ($c->isTempEditFilePath($newpath)) {
		my $tmpEditFileDirectory = $c->getTempEditFileDirectory();
		$newpath =~ s|^$tmpEditFileDirectory/||;

		if ($newpath =~ m|blank\.[^/]*$|) {
			$newpath = $ce->{webworkFiles}{screenSnippets}{blankProblem};
		} elsif (($newpath =~ m|hardcopyHeader\.[^/]*$|)) {
			$newpath = $ce->{webworkFiles}{hardcopySnippets}{setHeader};
		} elsif (($newpath =~ m|screenHeader\.[^/]*$|)) {
			$newpath = $ce->{webworkFiles}{screenSnippets}{setHeader};
		} else {
			my $user = $c->param('user');
			$newpath =~ s|\.$user\.tmp$||;
		}
	} else {
		$c->addbadmessage("This path |$newpath| is not the path to a temporary edit file.");
		# Returns the original path.
	}

	return $newpath;
}

sub getTempEditFileDirectory ($c) {
	my $courseDirectories = $c->ce->{courseDirs};
	return $courseDirectories->{tmpEditFileDir} // "$courseDirectories->{templates}/tmpEdit";
}

sub isTempEditFilePath ($c, $path) {
	# Unless path is absolute, assume that it is relative to the template directory.
	$path = $c->ce->{courseDirs}{templates} . "/$path" unless $path =~ m|^/|;

	my $tmpEditFileDirectory = $c->getTempEditFileDirectory();

	return $path =~ /^$tmpEditFileDirectory/ ? 1 : 0;
}

# Determine file paths. This defines the following variables:
#   $c->{editFilePath}    -- path to permanent file
#   $c->{tempFilePath}    -- temporary file name to use (may not exist)
#   $c->{inputFilePath}   -- actual file to read and edit (will be one of the above)
#   $c->{backupBasePath}  -- base path to backup files
sub getFilePaths ($c) {
	my $ce   = $c->ce;
	my $db   = $c->db;
	my $user = $c->param('user');

	my $editFilePath;

	if ($c->{file_type} eq 'course_info') {
		$editFilePath = "$ce->{courseDirs}{templates}/$ce->{courseFiles}{course_info}";
	} elsif ($c->{file_type} eq 'blank_problem') {
		$editFilePath = $ce->{webworkFiles}{screenSnippets}{blankProblem};
		$c->addbadmessage($c->maketext(
			'This is a blank problem template file and can not be edited directly. Use the "New Version" '
				. 'action below to create a local copy of the file and add it to the current problem set.'
		));
	} elsif ($c->{file_type} eq 'set_header' || $c->{file_type} eq 'hardcopy_header') {
		my $set_record = $db->getGlobalSet($c->{setID});

		if (defined $set_record) {
			my $header_file = $set_record->{ $c->{file_type} };
			if ($header_file && $header_file ne 'defaultHeader') {
				if ($header_file =~ m|^/|) {
					# Absolute address
					$editFilePath = $header_file;
				} else {
					$editFilePath = "$ce->{courseDirs}{templates}/$header_file";
				}
			} else {
				# If the set record doesn't specify the filename for a header or it specifies the defaultHeader,
				# then the set uses the default from snippets.
				$editFilePath = $ce->{webworkFiles}{screenSnippets}{setHeader}
					if $c->{file_type} eq 'set_header';
				$editFilePath = $ce->{webworkFiles}{hardcopySnippets}{setHeader}
					if $c->{file_type} eq 'hardcopy_header';
			}
		} else {
			$c->addbadmessage("Cannot find a set record for set $c->{setID}");
			return;
		}
	} elsif ($c->{file_type} eq 'problem') {
		# First try getting the merged problem for the effective user.
		my $effectiveUserName = $c->param('effectiveUser');
		my $problem_record =
			$c->{versionID}
			? $db->getMergedProblemVersion($effectiveUserName, $c->{setID}, $c->{versionID}, $c->{problemID})
			: $db->getMergedProblem($effectiveUserName, $c->{setID}, $c->{problemID});

		# If that doesn't work, then the problem is not yet assigned. So get the global record.
		$problem_record = $db->getGlobalProblem($c->{setID}, $c->{problemID}) unless defined $problem_record;

		if (defined $problem_record) {
			$editFilePath = "$ce->{courseDirs}{templates}/" . $problem_record->source_file;
			# Define the problem seed for later use.
			$c->{problemSeed} = $problem_record->problem_seed if $problem_record->can('problem_seed');
		} else {
			$c->addbadmessage(
				$c->maketext("Cannot find a problem record for set $c->{setID} / problem $c->{problemID}"));
			return;
		}
	} elsif ($c->{file_type} eq 'source_path_for_problem_file') {
		my $forcedSourceFile = $c->{sourceFilePath};
		# If the source file is in the temporary edit directory find the original source file.
		# The source file is relative to the templates directory.
		if ($c->isTempEditFilePath($forcedSourceFile)) {
			$forcedSourceFile = $c->determineOriginalEditFilePath($forcedSourceFile);    # Original file path
			$c->addgoodmessage($c->maketext('The original path to the file is [_1].', $forcedSourceFile));
		}
		if (not_blank($forcedSourceFile)) {
			$c->{problemSeed} = DEFAULT_SEED();
			$editFilePath = "$ce->{courseDirs}{templates}/$forcedSourceFile";
		} else {
			$c->addbadmessage($c->maketext('Cannot find a file path to save to.'));
			return;
		}
	}

	if (-d $editFilePath) {
		$c->addbadmessage($c->maketext('The file "[_1]" is a directory!', $c->shortPath($editFilePath)));
	}
	if (-e $editFilePath && !-r $editFilePath) {
		# It's ok if the file doesn't exist.  Perhaps we're going to create it with save as.
		$c->addbadmessage($c->maketext('The file "[_1]" cannot be read!', $c->shortPath($editFilePath)));
	}

	# The path to the permanent file is now verified and stored in $editFilePath
	$c->{editFilePath}   = $editFilePath;
	$c->{tempFilePath}   = $c->determineTempEditFilePath($editFilePath);
	$c->{backupBasePath} = $c->{tempFilePath} =~ s/.$user.tmp/.bak/r;

	# $c->{inputFilePath} is $c->{tempFilePath} if it is exists and is readable.
	# Otherwise it is the original $c->{editFilePath}.
	$c->{inputFilePath} = -r $c->{tempFilePath} ? $c->{tempFilePath} : $c->{editFilePath};

	return;
}

sub getBackupTimes ($c) {
	my $backupBasePath = $c->{backupBasePath};
	my @files          = glob("$backupBasePath*");
	return unless @files;
	return reverse(map { $_ =~ s/$backupBasePath//r } @files);
}

sub backupFile ($c, $outputFilePath) {
	my $ce             = $c->ce;
	my $backupTime     = time;
	my $backupFilePath = $c->{backupBasePath} . $backupTime;

	# Make sure any missing directories are created.
	surePathToFile($ce->{courseDirs}{templates}, $backupFilePath);
	copy($outputFilePath, $backupFilePath);
	$c->addgoodmessage($c->maketext(
		'Backup created on [_1]',
		$c->formatDateTime($backupTime, undef, $ce->{studentDateDisplayFormat})
	));

	# Delete oldest backup if option is present.
	if ($c->param('deleteBackup')) {
		my @backupTimes      = $c->getBackupTimes;
		my $backupTime       = $backupTimes[-1];
		my $backupFilePath   = $c->{backupBasePath} . $backupTime;
		my $formatBackupTime = $c->formatDateTime($backupTime, undef, $ce->{studentDateDisplayFormat});
		if (-e $backupFilePath) {
			unlink($backupFilePath);
			$c->addgoodmessage($c->maketext('Deleted backup from [_1].', $formatBackupTime));
		} else {
			$c->addbadmessage($c->maketext('Unable to delete backup from [_1].', $formatBackupTime));
		}
	}
	return;
}

sub saveFileChanges ($c, $outputFilePath, $backup = 0) {
	my $ce              = $c->ce;
	my $problemContents = ${ $c->{r_problemContents} };

	# Read and update the targetFile and targetFile.tmp files in the directory.
	# If a .tmp file already exists use that, unless the revert button has been pressed.
	# The .tmp files are removed when the file is or when the revert occurs.

	unless (not_blank($outputFilePath)) {
		$c->addbadmessage($c->maketext('You must specify a file name in order to save a new file.'));
		return;
	}

	unless (path_is_subdir($outputFilePath, $ce->{courseDirs}{templates}, 1)) {
		$c->addbadmessage($c->maketext(
			'The file [_1] is not contained in the course templates directory and can not be modified.',
			$outputFilePath
		));
		return;
	}

	# Make sure any missing directories are created.
	surePathToFile($ce->{courseDirs}{templates}, $outputFilePath);

	# Backup file if asked.
	$c->backupFile($outputFilePath) if $backup;

	# Actually save the file.
	if (open my $outfile, '>:encoding(UTF-8)', $outputFilePath) {
		print $outfile $problemContents;
		close $outfile;
	} else {
		# Catch file save errors.
		my $writeFileErrors = $!;

		# Get the current directory from the outputFilePath.
		$outputFilePath =~ m|^(/.*?/)[^/]+$|;
		my $currentDirectory = $1;

		my $errorMessage;

		if (!-w $ce->{courseDirs}{templates}) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled in the templates directory. No changes can be made.');
		} elsif (!-w $currentDirectory) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled in "[_1]".'
					. 'Changes must be saved to a different directory for viewing.',
				$c->shortPath($currentDirectory)
			);
		} elsif (-e $outputFilePath && !-w $outputFilePath) {
			$errorMessage = $c->maketext(
				'Write permissions have not been enabled for "[_1]". '
					. 'Changes must be saved to another file for viewing.',
				$c->shortPath($outputFilePath)
			);
		} else {
			$errorMessage = $c->b($c->maketext(
				'Unable to write to "[_1]": [_2]',
				$c->shortPath($outputFilePath),
				$c->tag('pre', $writeFileErrors)
			));
		}

		$c->addbadmessage($errorMessage);
		return;
	}

	# If the file is being saved as a new file in a new location, and the file is accompanied by auxiliary files
	# transfer them as well.  Auxiliary files are identified as any file in the same directory that doesn't end
	# in .pg and is mentioned inside the .pg file's contents.  Copy over any auxiliary files found.
	if ($c->{action} eq 'save_as' && $outputFilePath =~ /\.pg/) {
		my $sourceDirectory = $c->{sourceFilePath} || '';
		my $outputDirectory = $outputFilePath;
		$sourceDirectory =~ s|/[^/]+\.pg$||;
		$outputDirectory =~ s|/[^/]+\.pg$||;

		# Only perform the copy if the output directory is an actual new location.
		if ($sourceDirectory ne $outputDirectory) {
			my $problemContents = ${ $c->{r_problemContents} } // '';
			for my $file (-d $sourceDirectory ? readDirectory($sourceDirectory) : ()) {
				# The .pg file being edited has already been transferred. Ignore any others in the directory.
				# Only copy over files that are referenced in the .pg file.
				next unless $file !~ /\.pg$/ && $problemContents =~ /$file/;
				my $fromPath = "$sourceDirectory/$file";
				my $toPath   = "$outputDirectory/$file";
				# Don't copy directories and don't copy files that have already been copied.
				if (-f $fromPath && -r $fromPath && !-e $toPath) {
					# Need to use binary transfer for image files.  File::Copy does this.
					$c->addbadmessage($c->maketext('Error copying [_1] to [_2].', $fromPath, $toPath))
						unless copy($fromPath, $toPath);
				}
			}
			$c->addgoodmessage($c->maketext(
				'Copied auxiliary files from [_1] to new location at [_2].',
				$sourceDirectory, $outputDirectory
			));
		}
	}

	# Clean up temp files on save or save_as.
	# Unlink the temporary file if there are no errors and the save or save_as button has been pushed.
	if (($c->{action} eq 'save' || $c->{action} eq 'save_as') && -w $c->{tempFilePath}) {
		if (path_is_subdir($c->{tempFilePath}, $ce->{courseDirs}{templates}, 1)) {
			$c->addgoodmessage($c->maketext('Deleted temp file at [_1]', $c->shortPath($c->{tempFilePath})));
			unlink($c->{tempFilePath});

			# Update the file paths.
			$c->{tempFilePath}  = $c->determineTempEditFilePath($c->{editFilePath});
			$c->{inputFilePath} = $c->{editFilePath};
		} else {
			$c->addbadmessage($c->maketext(
				'The temporary file [_1] is not in the course templates directory and can not be deleted!',
				$c->{tempFilePath}
			));
		}
	}

	# Announce that the file was saved unless it was a temporary file.
	unless ($c->isTempEditFilePath($outputFilePath)) {
		$c->addgoodmessage($c->maketext('Saved to file "[_1]"', $c->shortPath($outputFilePath)));
	}

	return;
}

# Fix line endings in the problem contents.
# Make sure that all of the line endings are of unix type and convert \r\n to \n.
sub fixProblemContents {
	my $problemContents = shift;
	return $problemContents =~ s/(\r\n)|(\r)/\n/gr;
}

sub view_handler ($c) {
	my $problemSeed = $c->param('action.view.seed')        // DEFAULT_SEED();
	my $displayMode = $c->param('action.view.displayMode') // $c->ce->{pg}{options}{displayMode};

	# Grab the problemContents from the form in order to save it to the tmp file.
	$c->{r_problemContents} = \(fixProblemContents($c->param('problemContents')));

	$c->saveFileChanges($c->{tempFilePath});

	my $relativeTempFilePath = $c->getRelativeSourceFilePath($c->{tempFilePath});

	# Construct redirect URL and redirect to it.
	if ($c->{file_type} eq 'problem' || $c->{file_type} eq 'source_path_for_problem_file') {
		# Redirect to Problem.pm or GatewayQuiz.pm.
		# We need to know if the set is a gateway set to determine the redirect.
		my $globalSet = $c->db->getGlobalSet($c->{setID});

		$c->reply_with_redirect($c->systemLink(
			defined $globalSet && $globalSet->assignment_type =~ /gateway/
			? $c->url_for('gateway_quiz',   setID => 'Undefined_Set')
			: $c->url_for('problem_detail', setID => $c->{setID}, problemID => $c->{problemID}),
			params => {
				displayMode    => $displayMode,
				problemSeed    => $problemSeed,
				editMode       => 'temporaryFile',
				sourceFilePath => $relativeTempFilePath,
				status_message => $c->{status_message}->join('')
			}
		));
	} elsif ($c->{file_type} eq 'set_header') {
		# Redirect to ProblemSet
		$c->reply_with_redirect($c->systemLink(
			$c->url_for('problem_list', setID => $c->{setID}),
			params => {
				set_header     => $c->{tempFilePath},
				displayMode    => $displayMode,
				problemSeed    => $problemSeed,
				editMode       => 'temporaryFile',
				sourceFilePath => $relativeTempFilePath,
				status_message => $c->{status_message}->join('')
			}
		));
	} elsif ($c->{file_type} eq 'hardcopy_header') {
		# Redirect to ProblemSet?? It's difficult to view temporary changes for hardcopy headers.
		$c->reply_with_redirect($c->systemLink(
			$c->url_for('problem_list', setID => $c->{setID}),
			params => {
				set_header     => $c->{tempFilePath},
				displayMode    => $displayMode,
				problemSeed    => $problemSeed,
				editMode       => 'temporaryFile',
				sourceFilePath => $relativeTempFilePath,
				status_message => $c->{status_message}->join('')
			}
		));
	} elsif ($c->{file_type} eq 'course_info') {
		# Redirect to ProblemSets.pm.
		$c->reply_with_redirect($c->systemLink(
			$c->url_for('set_list'),
			params => {
				course_info    => $c->{tempFilePath},
				editMode       => 'temporaryFile',
				sourceFilePath => $relativeTempFilePath,
				status_message => $c->{status_message}->join('')
			}
		));
	} else {
		die "I don't know how to redirect this file type $c->{file_type}.";
	}

	return;
}

# The hardcopy action is handled by javascript.  This is provided just in case
# something goes wrong and the action gets called.
sub hardcopy_action { }

sub add_problem_handler ($c) {
	my $db = $c->db;

	my $templatesPath  = $c->ce->{courseDirs}{templates};
	my $sourceFilePath = $c->{editFilePath} =~ s|^$templatesPath/||r;

	my $targetSetName  = $c->param('action.add_problem.target_set');
	my $targetFileType = $c->param('action.add_problem.file_type');

	if ($targetFileType eq 'problem') {
		my $targetProblemNumber;

		my $set = $db->getGlobalSet($targetSetName);

		if ($set->assignment_type eq 'jitar') {
			# For jitar sets new problems are put as top level problems at the end.
			my @problemIDs =
				map { $_->[1] } $db->listGlobalProblemsWhere({ set_id => $targetSetName }, 'problem_id');
			my @seq = jitar_id_to_seq($problemIDs[-1]);
			$targetProblemNumber = seq_to_jitar_id($seq[0] + 1);
		} else {
			$targetProblemNumber = 1 + max($db->listGlobalProblems($targetSetName));
		}

		# Update problem record
		my $problemRecord = addProblemToSet(
			$db, $c->ce->{problemDefaults},
			setName    => $targetSetName,
			sourceFile => $sourceFilePath,
			problemID  => $targetProblemNumber,
		);

		assignProblemToAllSetUsers($db, $problemRecord);

		$c->addgoodmessage($c->maketext(
			'Added [_1] to [_2] as problem [_3]',
			$sourceFilePath,
			$targetSetName,
			(
				$set->assignment_type eq 'jitar'
				? join('.', jitar_id_to_seq($targetProblemNumber))
				: $targetProblemNumber
			)
		));
		$c->{file_type} = 'problem';    # Change file type to problem if it is not already that.

		# Redirect to problem editor page.
		$c->reply_with_redirect($c->systemLink(
			$c->url_for(
				'instructor_problem_editor_withset_withproblem',
				setID     => $targetSetName,
				problemID => $targetProblemNumber,
			),
			params => {
				displayMode    => $c->{displayMode},
				problemSeed    => $c->{problemSeed},
				editMode       => 'savedFile',
				sourceFilePath => $c->getRelativeSourceFilePath($sourceFilePath),
				status_message => $c->{status_message}->join(''),
				file_type      => 'problem',
			}
		));
	} elsif ($targetFileType eq 'set_header') {
		# Update set record
		my $setRecord = $c->db->getGlobalSet($targetSetName);
		$setRecord->set_header($sourceFilePath);
		if ($c->db->putGlobalSet($setRecord)) {
			$c->addgoodmessage($c->maketext(
				'Added "[_1]" to [_2] as new set header',
				$c->shortPath($sourceFilePath),
				$targetSetName
			));
		} else {
			$c->addbadmessage($c->maketext(
				'Unable to make "[_1]" the set header for [_2].',
				$c->shortPath($sourceFilePath),
				$targetSetName
			));
		}

		$c->{file_type} = 'set_header';    # Change file type to set_header if not already so.

		# Redirect
		$c->reply_with_redirect($c->systemLink(
			$c->url_for('problem_list', setID => $targetSetName),
			params => {
				displayMode    => $c->{displayMode},
				editMode       => 'savedFile',
				status_message => $c->{status_message}->join(''),
			}
		));
	} elsif ($targetFileType eq 'hardcopy_header') {
		# Update set record
		my $setRecord = $c->db->getGlobalSet($targetSetName);
		$setRecord->hardcopy_header($sourceFilePath);
		if ($c->db->putGlobalSet($setRecord)) {
			$c->addgoodmessage($c->maketext(
				'Added "[_1]" to [_2] as new hardcopy header',
				$c->shortPath($sourceFilePath),
				$targetSetName
			));
		} else {
			$c->addbadmessage(
				$c->maketext('Unable to make "[_1]" the hardcopy header for [_2].'),
				$c->shortPath($sourceFilePath),
				$targetSetName
			);
		}

		$c->{file_type} = 'hardcopy_header';    # Change file type to set_header if not already so.

		# Redirect
		$c->reply_with_redirect($c->systemLink(
			$c->url_for('hardcopy_preselect_set', setID => $targetSetName),
			params => {
				displayMode    => $c->{displayMode},
				editMode       => 'savedFile',
				status_message => $c->{status_message}->join(''),
			}
		));
	} else {
		die "Unsupported target file type $targetFileType";
	}

	return;
}

sub save_handler ($c) {
	# Grab the problemContents from the form in order to save it to a new permanent file.
	# Later we will unlink (delete) the current temporary file.
	$c->{r_problemContents} = \(fixProblemContents($c->param('problemContents')));

	# Sanity check in case the user has edited the problem set while editing a problem.
	# This can cause the current editor contents to overwrite the new file that is saved for the problem.
	if ($c->{editFilePath} ne $c->param('action.save.source_file')) {
		$c->addbadmessage($c->maketext(
			'File not saved. The file name for this problem does not match the file name the editor was opened with. '
				. 'The problem set may have changed. Please reopen this file from the homework sets editor.'
		));
	} else {
		$c->saveFileChanges($c->{editFilePath}, scalar($c->param('backupFile')));
	}

	# Don't redirect unless it was requested to open in a new window.
	return unless $c->param('newWindowSave');

	if ($c->{file_type} eq 'problem' || $c->{file_type} eq 'source_path_for_problem_file') {
		# Redirect to Problem.pm or GatewayQuiz.pm.
		# We need to know if the set is a gateway set to determine the redirect.
		my $globalSet = $c->db->getGlobalSet($c->{setID});

		$c->reply_with_redirect($c->systemLink(
			defined $globalSet && $globalSet->assignment_type =~ /gateway/
			? $c->url_for('gateway_quiz',   setID => 'Undefined_Set')
			: $c->url_for('problem_detail', setID => $c->{setID}, problemID => $c->{problemID}),
			params => {
				displayMode    => $c->{displayMode},
				problemSeed    => $c->{problemSeed},
				editMode       => 'savedFile',
				sourceFilePath => $c->getRelativeSourceFilePath($c->{editFilePath}),
				status_message => $c->{status_message}->join('')
			}
		));
	} elsif ($c->{file_type} eq 'set_header') {
		# Redirect to ProblemSet.pm
		$c->reply_with_redirect($c->systemLink(
			$c->url_for('problem_list', setID => $c->{setID}),
			params => {
				displayMode    => $c->{displayMode},
				problemSeed    => $c->{problemSeed},
				editMode       => 'savedFile',
				status_message => $c->{status_message}->join('')
			}
		));
	} elsif ($c->{file_type} eq 'hardcopy_header') {
		# Redirect to Hardcopy.pm
		$c->reply_with_redirect($c->systemLink(
			$c->url_for('hardcopy_preselect_set', setID => $c->{setID}),
			params => {
				displayMode    => $c->{displayMode},
				problemSeed    => $c->{problemSeed},
				editMode       => 'savedFile',
				status_message => $c->{status_message}->join('')
			}
		));
	} elsif ($c->{file_type} eq 'course_info') {
		# Redirect to ProblemSets.pm
		$c->reply_with_redirect($c->systemLink(
			$c->url_for('set_list'),
			params => { editMode => 'savedFile', status_message => $c->{status_message}->join('') }
		));
	} elsif ($c->{file_type} eq 'source_path_for_problem_file') {
		# Redirect to PGProblemEditor.pm
		$c->reply_with_redirect($c->systemLink(
			$c->url_for(
				'instructor_problem_editor_withset_withproblem',
				setID     => $c->{setID},
				problemID => $c->{problemID}
			),
			params => {
				displayMode => $c->{displayMode},
				problemSeed => $c->{problemSeed},
				editMode    => 'savedFile',
				# The path relative to the templates directory is required.
				sourceFilePath => $c->{editFilePath},
				file_type      => 'source_path_for_problem_file',
				status_message => $c->{status_message}->join('')
			}
		));
	} else {
		die "Unsupported save file type $c->{file_type}.";
	}

	return;
}

sub save_as_handler ($c) {
	my $db = $c->db;

	$c->{status_message} = $c->c;

	my $do_not_save = 0;

	my $saveMode      = $c->param('action.save_as.saveMode') || 'no_save_mode_selected';
	my $new_file_name = ($c->param('action.save_as.target_file') || '') =~ s/^\s*|\s*$//gr;
	$c->{sourceFilePath} = $c->param('action.save_as.source_file') || '';    # Store for use in saveFileChanges.
	my $file_type = $c->param('action.save_as.file_type') || '';

	# Need a non-blank file name.
	if (!$new_file_name) {
		$do_not_save = 1;
		$c->addbadmessage($c->maketext('Please specify a file to save to.'));
	}

	# Rescue the user in case they forgot to end the file name with the pg extension.
	if (($file_type eq 'problem' || $file_type eq 'blank_problem' || $file_type eq 'set_header')
		&& $new_file_name !~ /\.pg$/)
	{
		$new_file_name .= '.pg';
	}

	# Grab the problemContents from the form in order to save it to a new permanent file.
	# Later we will unlink (delete) the current temporary file.
	$c->{r_problemContents} = \(fixProblemContents($c->param('problemContents')));

	# Construct the output file path
	my $outputFilePath = $c->ce->{courseDirs}{templates} . "/$new_file_name";
	if (defined $outputFilePath && -e $outputFilePath) {
		$do_not_save = 1;
		$c->addbadmessage($c->maketext(
			'File "[_1]" exists. File not saved. No changes have been made.  '
				. 'You can change the file path for this problem manually from the "Hmwk Sets Editor" page',
			$c->shortPath($outputFilePath)
		));
		$c->addgoodmessage($c->maketext(
			'The text box now contains the source of the original problem. '
				. 'You can recover lost edits by using the Back button on your browser.'
		));
	} else {
		$c->{editFilePath} = $outputFilePath;
		# saveFileChanges will update the tempFilePath and inputFilePath as needed.  Don't do that here.
	}

	unless ($do_not_save) {
		$c->saveFileChanges($outputFilePath);
		my $targetProblemNumber;

		if ($file_type eq 'course_info') {
			# The saveMode is not set for course_info files as there are no such options presented in the form.
			# So set that here so that the correct redirect is chosen below.
			$saveMode = 'new_course_info';
		} elsif ($saveMode eq 'rename' && -r $outputFilePath) {
			# Modify source file path in problem.
			if ($file_type eq 'set_header') {
				my $setRecord = $db->getGlobalSet($c->{setID});
				$setRecord->set_header($new_file_name);
				if ($db->putGlobalSet($setRecord)) {
					$c->addgoodmessage($c->maketext(
						'The set header for set [_1] has been renamed to "[_2]".', $c->{setID},
						$c->shortPath($outputFilePath)
					));
				} else {
					$c->addbadmessage($c->maketext(
						'Unable to change the set header for set [_1]. Unknown error.', $c->{setID}));
				}
			} elsif ($file_type eq 'hardcopy_header') {
				my $setRecord = $db->getGlobalSet($c->{setID});
				$setRecord->hardcopy_header($new_file_name);
				if ($db->putGlobalSet($setRecord)) {
					$c->addgoodmessage($c->maketext(
						'The hardcopy header for set [_1] has been renamed to "[_2]".', $c->{setID},
						$c->shortPath($outputFilePath)
					));
				} else {
					$c->addbadmessage($c->maketext(
						'Unable to change the hardcopy header for set [_1]. Unknown error.',
						$c->{setID}
					));
				}
			} else {
				my $problemRecord;
				if ($c->{versionID}) {
					$problemRecord =
						$db->getMergedProblemVersion($c->param('effectiveUser'), $c->{setID}, $1, $c->{problemID});
				} else {
					$problemRecord = $db->getGlobalProblem($c->{setID}, $c->{problemID});
				}
				$problemRecord->source_file($new_file_name);
				my $result =
					$c->{versionID} ? $db->putProblemVersion($problemRecord) : $db->putGlobalProblem($problemRecord);

				if ($result) {
					$c->addgoodmessage($c->maketext(
						'The source file for "set [_1] / problem [_2]" has been changed from "[_3]" to "[_4]".',
						$c->{fullSetID},
						$c->{prettyProblemNumber},
						$c->shortPath($c->{sourceFilePath}),
						$c->shortPath($outputFilePath)
					));
				} else {
					$c->addbadmessage($c->maketext(
						'Unable to change the source file path for set [_1], problem [_2]. Unknown error.',
						$c->{fullSetID}, $c->{prettyProblemNumber}
					));
				}
			}
		} elsif ($saveMode eq 'add_to_set_as_new_problem') {
			my $set = $db->getGlobalSet($c->{setID});

			# For jitar sets new problems are put as top level problems at the end.
			if ($set->assignment_type eq 'jitar') {
				my @problemIDs = $db->listGlobalProblems($c->{setID});
				@problemIDs = sort { $a <=> $b } @problemIDs;
				my @seq = jitar_id_to_seq($problemIDs[-1]);
				$targetProblemNumber = seq_to_jitar_id($seq[0] + 1);
			} else {
				$targetProblemNumber = 1 + max($db->listGlobalProblems($c->{setID}));
			}

			my $problemRecord = addProblemToSet(
				$db, $c->ce->{problemDefaults},
				setName    => $c->{setID},
				sourceFile => $new_file_name,
				problemID  => $targetProblemNumber,    # Added to end of set
			);
			assignProblemToAllSetUsers($db, $problemRecord);
			$c->addgoodmessage($c->maketext(
				'Added [_1] to [_2] as problem [_3].',
				$new_file_name,
				$c->{setID},
				(
					$set->assignment_type eq 'jitar'
					? join('.', jitar_id_to_seq($targetProblemNumber))
					: $targetProblemNumber
				)
			));
		} elsif ($saveMode eq 'new_independent_problem') {
			$c->addgoodmessage($c->maketext(
				'A new file has been created at "[_1]" with the contents below.',
				$c->shortPath($outputFilePath)
			));
			$c->addgoodmessage($c->maketext(' No changes have been made to set [_1]', $c->{setID}))
				if ($c->{setID} ne 'Undefined_Set');
		} else {
			$c->addbadmessage($c->maketext('Unkown saveMode: [_1].', $saveMode));
			return;
		}
	}

	# Set up redirect.
	my $problemPage;
	my $new_file_type;

	if ($saveMode eq 'new_course_info') {
		$problemPage   = $c->url_for('instructor_problem_editor');
		$new_file_type = 'course_info';
	} elsif ($saveMode eq 'new_independent_problem') {
		$problemPage =
			$c->url_for('instructor_problem_editor_withset_withproblem', setID => 'Undefined_Set', problemID => 1);
		$new_file_type = 'source_path_for_problem_file';
	} elsif ($saveMode eq 'rename') {
		$problemPage = $c->url_for(
			'instructor_problem_editor_withset_withproblem',
			setID     => $c->{setID},
			problemID => $c->{problemID}
		);
		$new_file_type = $file_type;
	} elsif ($saveMode eq 'add_to_set_as_new_problem') {
		$problemPage = $c->url_for(
			'instructor_problem_editor_withset_withproblem',
			setID     => $c->{setID},
			problemID => $do_not_save ? $c->{problemID} : max($db->listGlobalProblems($c->{setID}))
		);
		$new_file_type = $file_type;
	} else {
		$c->addbadmessage($c->maketext(
			'Please use radio buttons to choose the method for saving this file. Uknown saveMode: [_1].', $saveMode
		));
		return;
	}

	$c->reply_with_redirect($c->systemLink(
		$problemPage,
		params => {
			# The path relative to the templates directory is required.
			sourceFilePath => $c->getRelativeSourceFilePath($outputFilePath),
			problemSeed    => $c->{problemSeed},
			file_type      => $new_file_type,
			status_message => $c->{status_message}->join('')
		}
	));
	return;
}

sub revert_handler ($c) {
	my $ce   = $c->ce;
	my $user = $c->param('user');

	unless (path_is_subdir($c->{tempFilePath}, $ce->{courseDirs}{templates}, 1)) {
		$c->addbadmessage($c->maketext(
			'The temporary file [_1] is not contained in the course templates directory and can not be deleted.',
			$c->{tempFilePath}
		));
		return;
	}

	# Determine revert action
	my $revertType = $c->param('action.revert.type') || 'do_not_revert';

	if ($revertType eq 'revert') {
		$c->{inputFilePath} = $c->{editFilePath};
		unlink($c->{tempFilePath});
		$c->addgoodmessage($c->maketext('Deleted temporary file "[_1]".',    $c->shortPath($c->{tempFilePath})));
		$c->addgoodmessage($c->maketext('Reverted to original file "[_1]".', $c->shortPath($c->{editFilePath})));
	} elsif ($revertType eq 'backup') {
		my $backupTime     = $c->param('action.revert.backup.time') || '';
		my $backupFilePath = $c->{backupBasePath} . $backupTime;
		$c->{inputFilePath} = $c->{tempFilePath};

		if (-r $backupFilePath) {
			copy($backupFilePath, $c->{tempFilePath});
			$c->addgoodmessage($c->maketext(
				'Restored backup from [_1].',
				$c->formatDateTime($backupTime, undef, $ce->{studentDateDisplayFormat})
			));
		} else {
			$c->addbadmessage($c->maketext('Unable to read backup file "[_1]".', $c->shortPath($backupFilePath)));
		}
	} elsif ($revertType eq 'delete') {
		my $delTime     = $c->param('action.revert.delete.time');
		my $delFilePath = $c->{backupBasePath} . $delTime;

		if (-e $delFilePath) {
			unlink($delFilePath);
			$c->addgoodmessage($c->maketext(
				'Deleted backup from [_1].',
				$c->formatDateTime($delTime, undef, $ce->{studentDateDisplayFormat})
			));
		} else {
			$c->addbadmessage($c->maketext('Unable to delete backup file "[_1]".', $c->shortPath($delFilePath)));
		}
		return;
	} else {
		return;
	}

	$c->{r_problemContents} = \'';
	$c->param('problemContents', undef);

	return;
}

1;
