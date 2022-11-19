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

package WeBWorK::ContentGenerator::Instructor::PGProblemEditor;
use parent qw(WeBWorK::ContentGenerator::Instructor);

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

use strict;
use warnings;

use HTML::Entities;
use URI::Escape;
use File::Copy;

use WeBWorK::Utils qw(jitar_id_to_seq not_blank path_is_subdir seq_to_jitar_id x
	surePathToFile readDirectory readFile max);

use constant DEFAULT_SEED => 123456;

# Editor tabs
use constant ACTION_FORMS => [qw(view hardcopy save save_as add_problem revert)];
use constant ACTION_FORM_TITLES => {
	view        => x('View/Reload'),
	hardcopy    => x('Generate Hardcopy'),
	add_problem => x('Append'),
	save        => x('Update'),
	save_as     => x('New Version'),
	revert      => x('Revert'),
};

my $BLANKPROBLEM = 'blankProblem.pg';

async sub pre_header_initialize {
	my $self    = shift;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $urlpath = $r->urlpath;
	my $authz   = $r->authz;
	my $user    = $r->param('user');

	# Check permissions
	return
		unless $authz->hasPermissions($user, 'access_instructor_tools')
		&& $authz->hasPermissions($user, 'modify_problem_sets');

	$self->{courseID}  = $urlpath->arg('courseID');
	$self->{setID}     = $urlpath->arg('setID');
	$self->{problemID} = $urlpath->arg('problemID');

	# Parse setID which may come in with version data
	$self->{fullSetID} = $self->{setID};
	if (defined $self->{fullSetID} && $self->{fullSetID} =~ /^([^,]*),v(\d+)$/) {
		$self->{setID}     = $1;
		$self->{versionID} = $2;
	}

	# Determine displayMode and problemSeed that are needed for viewing the problem.
	# They are also two of the parameters which can be set by the editor.
	# Note that the problem seed may be overridden by the value obtained from the problem record later.
	$self->{displayMode} = $r->param('displayMode') // $ce->{pg}{options}{displayMode};
	$self->{problemSeed} = (($r->param('problemSeed') // '') =~ s/^\s*|\s*$//gr) || DEFAULT_SEED();

	# Save file to permanent or temporary file, then redirect for viewing if it was requested to view in a new window.
	# Any file "saved as" should be assigned to "Undefined_Set" and redirected to be viewed again in the editor.
	# Problems "saved" or 'refreshed' are to be redirected to the Problem.pm module
	# Set headers which are "saved" are to be redirected to the ProblemSet.pm page
	# Hardcopy headers which are "saved" are also to be redirected to the ProblemSet.pm page
	# Course info files are redirected to the ProblemSets.pm page

	# Insure that file_type is defined
	$self->{file_type} = ($r->param('file_type') // '') =~ s/^\s*|\s*$//gr;

	# If file_type has not been defined we are dealing with a set header or regular problem.
	if (!$self->{file_type}) {
		# If sourceFilePath is defined in the form, then the path will be obtained from that.
		# If the problem number is defined and is 0 then a header file is being edited.
		# If the problem number is not zero, a problem is being edited.
		if (not_blank($r->param('sourceFilePath'))) {
			$self->{file_type} =
				$r->param('sourceFilePath') =~ m!/headers/|Header\.pg$! ? 'set_header' : 'source_path_for_problem_file';
		} elsif (defined $self->{problemID}) {
			if ($self->{problemID} =~ /^\d+$/ && $self->{problemID} == 0) {
				$self->{file_type} = 'set_header' unless $self->{file_type} eq 'hardcopy_header';
			} else {
				$self->{file_type} = 'problem';
			}
		} else {
			$self->{file_type} = 'blank_problem';
		}
	}

	# Clean up sourceFilePath and check that sourceFilePath is relative to the templates file
	if ($self->{file_type} eq 'source_path_for_problem_file') {
		my $sourceFilePath = $r->param('sourceFilePath');
		$sourceFilePath =~ s/$ce->{courseDirs}{templates}//;
		$sourceFilePath =~ s|^/||;
		$self->{sourceFilePath} = $sourceFilePath;
	}

	# Initialize these values in case of failure in the getFilePaths method.
	$self->{editFilePath}  = '';
	$self->{tempFilePath}  = '';
	$self->{inputFilePath} = '';

	# Determine the paths for the file.
	# getFilePath defines:
	#   $self->{editFilePath}:  path to the permanent file to be edited
	#   $self->{tempFilePath}:  path to the temporary file to be edited with .tmp suffix
	#   $self->{inputFilePath}: path to the file for input, (this is either the editFilePath or the tempFilePath)
	$self->getFilePaths;

	# Default problem contents
	$self->{r_problemContents} = \'';

	$self->{status_message} //= $r->c;

	# Determine action.  If an invalid action is sent in, assume this is an initial edit.
	$self->{action} = $r->param('action') // '';
	if ($self->{action} && grep { $_ eq $self->{action} } @{ ACTION_FORMS() }) {
		my $actionHandler = "$self->{action}_handler";
		$self->$actionHandler;
	}

	return;
}

sub initialize {
	my $self  = shift;
	my $r     = $self->r;
	my $ce    = $r->ce;
	my $db    = $r->db;
	my $authz = $r->authz;
	my $user  = $r->param('user');

	# Make sure these are defined for the templates.
	$r->stash->{problemContents}  = '';
	$r->stash->{formsToShow}      = ACTION_FORMS();
	$r->stash->{actionFormTitles} = ACTION_FORM_TITLES();

	# Check permissions
	return
		unless $authz->hasPermissions($user, 'access_instructor_tools')
		&& $authz->hasPermissions($user, 'modify_problem_sets');

	my $file_type = $r->param('file_type') || '';

	# Record status messages carried over if this is a redirect
	$self->addmessage($r->param('status_message') || '');

	$self->addbadmessage($r->maketext('Changes in this file have not yet been permanently saved.'))
		if $self->{inputFilePath} eq $self->{tempFilePath} && -r $self->{tempFilePath};

	if (!-e $self->{inputFilePath}) {
		$self->addbadmessage(
			$r->maketext('The file "[_1]" cannot be found.', $self->shortPath($self->{inputFilePath})));
	} elsif (!-w $self->{inputFilePath} && $file_type ne 'blank_problem') {
		$self->addbadmessage($r->maketext(
			'The file "[_1]" is protected! '
				. 'To edit this text you must first make a copy of this file using the "New Version" action below.',
			$self->shortPath($self->{inputFilePath})
		));
	}

	if ($self->{inputFilePath} =~ /$BLANKPROBLEM$/ && $file_type ne 'blank_problem') {
		$self->addbadmessage($r->maketext(
			'The file "[_1]" is a blank problem!'
				. 'To edit this text you must use the "New Version" action below to save it to another file.',
			$self->shortPath($self->{inputFilePath})
		));
	}

	# Find the text for the problem, either in the temporary file if it exists, in the original file in the template
	# directory, or in the problem contents gathered in the initialization phase.

	my $problemContents = ${ $self->{r_problemContents} };

	unless ($problemContents =~ /\S/) {    # non-empty contents
		if (-r $self->{tempFilePath} && !-d $self->{tempFilePath}) {
			if (path_is_subdir($self->{tempFilePath}, $ce->{courseDirs}{templates}, 1)) {
				eval { $problemContents = readFile($self->{tempFilePath}) };
				$problemContents = $@ if $@;
				$self->{inputFilePath} = $self->{tempFilePath};
			} else {
				$r->stash->{file_error} = $r->maketext('Unable to open a temporary file at the given location.');
			}
		} elsif (-r $self->{editFilePath} && !-d $self->{editFilePath}) {
			if (path_is_subdir($self->{editFilePath}, $ce->{courseDirs}{templates}, 1)
				|| $self->{editFilePath} eq $ce->{webworkFiles}{screenSnippets}{setHeader}
				|| $self->{editFilePath} eq $ce->{webworkFiles}{hardcopySnippets}{setHeader}
				|| $self->{editFilePath} eq $ce->{webworkFiles}{screenSnippets}{blankProblem})
			{
				eval { $problemContents = readFile($self->{editFilePath}) };
				$problemContents = $@ if $@;
				$self->{inputFilePath} = $self->{editFilePath};

			} else {
				$r->stash->{file_error} = $r->maketext('The given file path is not a valid location.');
			}
		} else {
			# File not existing is not an error
			$problemContents = '';
		}
	}

	$r->stash->{problemContents} = $problemContents;

	$self->{prettyProblemNumber} = $self->{problemID} // '';
	$self->{set}                 = $self->r->db->getGlobalSet($self->{setID}) if $self->{setID};
	$self->{prettyProblemNumber} = join('.', jitar_id_to_seq($self->{prettyProblemNumber}))
		if $self->{set} && $self->{set}->assignment_type eq 'jitar';

	return;
}

sub path {
	my ($self, $args) = @_;
	my $r             = $self->r;
	my $urlpath       = $r->urlpath;
	my $courseName    = $urlpath->arg('courseID');
	my $setName       = $urlpath->arg('setID') // '';
	my $problemNumber = $urlpath->arg('problemID') || '';

	# We need to build a path to the problem being edited by hand, since it is not the same as the urlpath for this
	# page.  The bread crumb path leads back to the problem being edited, not to the Instructor tool.
	return $self->pathMacro(
		$args,
		'WeBWorK'                    => $r->location,
		$courseName                  => $r->location . "/$courseName",
		$setName                     => $r->location . "/$courseName/$setName",
		$self->{prettyProblemNumber} => $r->location . "/$courseName/$setName/$problemNumber",
		$r->maketext('Editor')       => ''
	);
}

sub title {
	my $self          = shift;
	my $r             = $self->r;
	my $courseName    = $r->urlpath->arg('courseID');
	my $setID         = $r->urlpath->arg('setID');
	my $problemNumber = $r->urlpath->arg('problemID');

	return $r->maketext('Set Header for set [_1]',            $setID)      if $self->{file_type} eq 'set_header';
	return $r->maketext('Hardcopy Header for set [_1]',       $setID)      if $self->{file_type} eq 'hardcopy_header';
	return $r->maketext('Course Information for course [_1]', $courseName) if $self->{file_type} eq 'course_info';

	if ($setID) {
		my $set = $r->db->getGlobalSet($setID);
		if ($set && $set->assignment_type eq 'jitar') {
			$problemNumber = join('.', jitar_id_to_seq($problemNumber));
		}
	}

	return $r->maketext('Problem [_1]', $problemNumber);
}

#  Convert initial path component to [TMPL], [COURSE], or [WW].
sub shortPath {
	my ($self, $file) = @_;

	my $tmpl = $self->r->ce->{courseDirs}{templates};
	my $root = $self->r->ce->{courseDirs}{root};
	my $ww   = $self->r->ce->{webworkDirs}{root};
	$file =~ s|^$tmpl|[TMPL]|;
	$file =~ s|^$root|[COURSE]|;
	$file =~ s|^$ww|[WW]|;

	return $file;
}

# Utilities

sub getRelativeSourceFilePath {
	my ($self, $sourceFilePath) = @_;

	my $templatesDir = $self->r->ce->{courseDirs}{templates};
	$sourceFilePath =~ s|^$templatesDir/*||;    # remove templates path and any slashes that follow

	return $sourceFilePath;
}

# determineLocalFilePath constructs a local file path parallel to a library file path
sub determineLocalFilePath {
	my ($self, $path) = @_;

	my $default_screen_header_path   = $self->r->ce->{webworkFiles}{hardcopySnippets}{setHeader};
	my $default_hardcopy_header_path = $self->r->ce->{webworkFiles}{screenSnippets}{setHeader};
	my $setID                        = $self->{setID} // int(rand(1000));

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
sub determineTempEditFilePath {
	my ($self, $path) = @_;
	my $r     = $self->r;
	my $user  = $r->param('user');
	my $setID = $self->{setID};

	my $templatesDirectory   = $r->ce->{courseDirs}{templates};
	my $tmpEditFileDirectory = $self->getTempEditFileDirectory();

	$self->addbadmessage($r->maketext('The path to the original file should be absolute.'))
		unless $path =~ m|^/|;

	if ($path =~ /^$tmpEditFileDirectory/) {
		$self->addbadmessage($r->maketext('The path can not be the temporary edit directory.'));
	} else {
		if ($path =~ /^$templatesDirectory/) {
			$path =~ s|^$templatesDirectory||;
			$path =~ s|^/||;                     # remove the initial slash if any
			$path = "$tmpEditFileDirectory/$path.$user.tmp";
		} elsif ($path eq $self->r->ce->{webworkFiles}{screenSnippets}{blankProblem}) {
			# Handle the case of the blank problem in snippets.
			$path = "$tmpEditFileDirectory/blank.$setID.$user.tmp";
		} elsif ($path eq $self->r->ce->{webworkFiles}{hardcopySnippets}{setHeader}) {
			# Handle the case of the screen header in snippets.
			$path = "$tmpEditFileDirectory/screenHeader.$setID.$user.tmp";
		} elsif ($path eq $self->r->ce->{webworkFiles}{screenSnippets}{setHeader}) {
			# Handle the case of the hardcopy header in snippets.
			$path = "$tmpEditFileDirectory/hardcopyHeader.$setID.$user.tmp";
		} else {
			# If all else fails, just use a failsafe filename.  This is reused in all of these cases.
			# This shouldn't be possible in any case.
			$path = "$tmpEditFileDirectory/failsafe.$setID.$user.tmp";
			$self->addbadmessage(
				$r->maketext('The original path is not in a valid location. Using failsafe [_1]', $path));
		}
	}

	return $path;
}

# Determine the original path to a file corresponding to a temporary edit file.
# Returns a path that is relative to the template directory.
sub determineOriginalEditFilePath {
	my ($self, $path) = @_;
	my $r  = $self->r;
	my $ce = $r->ce;

	# Unless path is absolute, assume that it is relative to the template directory.
	my $newpath = $path =~ m|^/| ? $path : "$ce->{courseDirs}{templates}/$path";

	if ($self->isTempEditFilePath($newpath)) {
		my $tmpEditFileDirectory = $self->getTempEditFileDirectory();
		$newpath =~ s|^$tmpEditFileDirectory/||;

		if ($newpath =~ m|blank\.[^/]*$|) {
			$newpath = $ce->{webworkFiles}{screenSnippets}{blankProblem};
		} elsif (($newpath =~ m|hardcopyHeader\.[^/]*$|)) {
			$newpath = $ce->{webworkFiles}{hardcopySnippets}{setHeader};
		} elsif (($newpath =~ m|screenHeader\.[^/]*$|)) {
			$newpath = $ce->{webworkFiles}{screenSnippets}{setHeader};
		} else {
			my $user = $r->param('user');
			$newpath =~ s|\.$user\.tmp$||;
		}
	} else {
		$self->addbadmessage("This path |$newpath| is not the path to a temporary edit file.");
		# Returns the original path.
	}

	return $newpath;
}

sub getTempEditFileDirectory {
	my $self              = shift;
	my $courseDirectories = $self->r->ce->{courseDirs};
	return $courseDirectories->{tmpEditFileDir} // "$courseDirectories->{templates}/tmpEdit";
}

sub isTempEditFilePath {
	my ($self, $path) = @_;

	# Unless path is absolute, assume that it is relative to the template directory.
	$path = $self->r->ce->{courseDirs}{templates} . "/$path" unless $path =~ m|^/|;

	my $tmpEditFileDirectory = $self->getTempEditFileDirectory();

	return $path =~ /^$tmpEditFileDirectory/ ? 1 : 0;
}

# Determine file paths. This defines the following variables:
#   $self->{editFilePath}  -- path to permanent file
#   $self->{tempFilePath}  -- temporary file name to use (may not exist)
#   $self->{inputFilePath} -- actual file to read and edit (will be one of the above)
sub getFilePaths {
	my $self = shift;
	my $r    = $self->r;
	my $ce   = $r->ce;
	my $db   = $r->db;

	my $editFilePath;

	if ($self->{file_type} eq 'course_info') {
		$editFilePath = "$ce->{courseDirs}{templates}/$ce->{courseFiles}{course_info}";
	} elsif ($self->{file_type} eq 'blank_problem') {
		$editFilePath = $ce->{webworkFiles}{screenSnippets}{blankProblem};
		$self->addbadmessage($r->maketext(
			'This is a blank problem template file and can not be edited directly. Use the "New Version" '
				. 'action below to create a local copy of the file and add it to the current problem set.'
		));
	} elsif ($self->{file_type} eq 'set_header' || $self->{file_type} eq 'hardcopy_header') {
		my $set_record = $db->getGlobalSet($self->{setID});

		if (defined $set_record) {
			my $header_file = $set_record->{ $self->{file_type} };
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
					if $self->{file_type} eq 'set_header';
				$editFilePath = $ce->{webworkFiles}{hardcopySnippets}{setHeader}
					if $self->{file_type} eq 'hardcopy_header';
			}
		} else {
			$self->addbadmessage("Cannot find a set record for set $self->{setID}");
			return;
		}
	} elsif ($self->{file_type} eq 'problem') {
		# First try getting the merged problem for the effective user.
		my $effectiveUserName = $r->param('effectiveUser');
		my $problem_record =
			$self->{versionID}
			? $db->getMergedProblemVersion($effectiveUserName, $self->{setID}, $self->{versionID}, $self->{problemID})
			: $db->getMergedProblem($effectiveUserName, $self->{setID}, $self->{problemID});

		# If that doesn't work, then the problem is not yet assigned. So get the global record.
		$problem_record = $db->getGlobalProblem($self->{setID}, $self->{problemID}) unless defined $problem_record;

		if (defined $problem_record) {
			$editFilePath = "$ce->{courseDirs}{templates}/" . $problem_record->source_file;
			# Define the problem seed for later use.
			$self->{problemSeed} = $problem_record->problem_seed if $problem_record->can('problem_seed');
		} else {
			$self->addbadmessage(
				$r->maketext("Cannot find a problem record for set $self->{setID} / problem $self->{problemID}"));
			return;
		}
	} elsif ($self->{file_type} eq 'source_path_for_problem_file') {
		my $forcedSourceFile = $self->{sourceFilePath};
		# If the source file is in the temporary edit directory find the original source file.
		# The source file is relative to the templates directory.
		if ($self->isTempEditFilePath($forcedSourceFile)) {
			$forcedSourceFile = $self->determineOriginalEditFilePath($forcedSourceFile);    # Original file path
			$self->addgoodmessage($r->maketext('The original path to the file is [_1].', $forcedSourceFile));
		}
		if (not_blank($forcedSourceFile)) {
			$self->{problemSeed} = DEFAULT_SEED();
			$editFilePath = "$ce->{courseDirs}{templates}/$forcedSourceFile";
		} else {
			$self->addbadmessage($r->maketext('Cannot find a file path to save to.'));
			return;
		}
	}

	if (-d $editFilePath) {
		$self->addbadmessage($r->maketext('The file "[_1]" is a directory!', $self->shortPath($editFilePath)));
	}
	if (-e $editFilePath && !-r $editFilePath) {
		# It's ok if the file doesn't exist.  Perhaps we're going to create it with save as.
		$self->addbadmessage($r->maketext('The file "[_1]" cannot be read!', $self->shortPath($editFilePath)));
	}

	# The path to the permanent file is now verified and stored in $editFilePath
	$self->{editFilePath} = $editFilePath;
	$self->{tempFilePath} = $self->determineTempEditFilePath($editFilePath);

	# $self->{inputFilePath} is $self->{tempFilePath} if it is exists and is readable.
	# Otherwise it is the original $self->{editFilePath}.
	$self->{inputFilePath} = -r $self->{tempFilePath} ? $self->{tempFilePath} : $self->{editFilePath};

	return;
}

sub saveFileChanges {
	my ($self, $outputFilePath, $problemContents) = @_;
	my $r  = $self->r;
	my $ce = $r->ce;

	$problemContents = $$problemContents if defined $problemContents && ref $problemContents;
	$problemContents = ${ $self->{r_problemContents} } unless not_blank($problemContents);

	# Read and update the targetFile and targetFile.tmp files in the directory.
	# If a .tmp file already exists use that, unless the revert button has been pressed.
	# The .tmp files are removed when the file is or when the revert occurs.

	unless (not_blank($outputFilePath)) {
		$self->addbadmessage($r->maketext('You must specify a file name in order to save a new file.'));
		return;
	}

	unless (path_is_subdir($outputFilePath, $ce->{courseDirs}{templates}, 1)) {
		$self->addbadmessage($r->maktext(
			'The file [_1] is not contained in the course templates directory and can not be modified.',
			$outputFilePath
		));
		return;
	}

	# Make sure any missing directories are created.
	surePathToFile($ce->{courseDirs}{templates}, $outputFilePath);

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
			$errorMessage = $r->maketext(
				'Write permissions have not been enabled in the templates directory. No changes can be made.');
		} elsif (!-w $currentDirectory) {
			$errorMessage = $r->maketext(
				'Write permissions have not been enabled in "[_1]".'
					. 'Changes must be saved to a different directory for viewing.',
				$self->shortPath($currentDirectory)
			);
		} elsif (-e $outputFilePath && !-w $outputFilePath) {
			$errorMessage = $r->maketext(
				'Write permissions have not been enabled for "[_1]". '
					. 'Changes must be saved to another file for viewing.',
				$self->shortPath($outputFilePath)
			);
		} else {
			$errorMessage = $r->b($r->maketext(
				'Unable to write to "[_1]": [_2]',
				$self->shortPath($outputFilePath),
				$r->tag('pre', $writeFileErrors)
			));
		}

		$self->addbadmessage($errorMessage);
		return;
	}

	# If the file is being saved as a new file in a new location, and the file is accompanied by auxiliary files
	# transfer them as well.  If the file is a pg file, then assume there are auxiliary files.  Copy all files not
	# ending in .pg from the original directory to the new one.
	if ($self->{action} eq 'save_as' && $outputFilePath =~ /\.pg/) {
		my $sourceDirectory = $self->{sourceFilePath} || '';
		my $outputDirectory = $outputFilePath;
		$sourceDirectory =~ s|/[^/]+\.pg$||;
		$outputDirectory =~ s|/[^/]+\.pg$||;

		# Only perform the copy if the output directory is an actual new location.
		if ($sourceDirectory ne $outputDirectory) {
			for my $file (-d $sourceDirectory ? readDirectory($sourceDirectory) : ()) {
				# The .pg file being edited has already been transferred. Ignore any others in the directory.
				next if $file =~ /\.pg$/;
				my $fromPath = "$sourceDirectory/$file";
				my $toPath   = "$outputDirectory/$file";
				# Don't copy directories and don't copy files that have already been copied.
				if (-f $fromPath && -r $fromPath && !-e $toPath) {
					# Need to use binary transfer for image files.  File::Copy does this.
					$self->addbadmessage($r->maketext('Error copying [_1] to [_2].', $fromPath, $toPath))
						unless copy($fromPath, $toPath);
				}
			}
			$self->addgoodmessage($r->maketext(
				'Copied auxiliary files from [_1] to new location at [_2].',
				$sourceDirectory, $outputDirectory
			));
		}
	}

	# Clean up temp files on save or save_as.
	# Unlink the temporary file if there are no errors and the save or save_as button has been pushed.
	if (($self->{action} eq 'save' || $self->{action} eq 'save_as') && -w $self->{tempFilePath}) {
		if (path_is_subdir($self->{tempFilePath}, $ce->{courseDirs}{templates}, 1)) {
			$self->addgoodmessage($r->maketext('Deleted temp file at [_1]', $self->shortPath($self->{tempFilePath})));
			unlink($self->{tempFilePath});

			# Update the file paths.
			$self->{tempFilePath}  = $self->determineTempEditFilePath($self->{editFilePath});
			$self->{inputFilePath} = $self->{editFilePath};
		} else {
			$self->addbadmessage($r->maketext(
				'The temporary file [_1] is not in the course templates directory and can not be deleted!',
				$self->{tempFilePath}
			));
		}
	}

	# Announce that the file was saved unless it was a temporary file.
	unless ($self->isTempEditFilePath($outputFilePath)) {
		$self->addgoodmessage($r->maketext('Saved to file "[_1]"', $self->shortPath($outputFilePath)));
	}

	return;
}

# Fix line endings in the problem contents.
# Make sure that all of the line endings are of unix type and convert \r\n to \n.
sub fixProblemContents {
	my $problemContents = shift;
	return $problemContents =~ s/(\r\n)|(\r)/\n/gr;
}

sub view_handler {
	my ($self) = @_;
	my $r = $self->r;

	my $problemSeed = $r->param('action.view.seed')        // DEFAULT_SEED();
	my $displayMode = $r->param('action.view.displayMode') // $self->r->ce->{pg}{options}{displayMode};

	# Grab the problemContents from the form in order to save it to the tmp file.
	$self->{r_problemContents} = \(fixProblemContents($self->r->param('problemContents')));

	$self->saveFileChanges($self->{tempFilePath});

	my $relativeTempFilePath = $self->getRelativeSourceFilePath($self->{tempFilePath});

	# Construct redirect URL and redirect to it.
	if ($self->{file_type} eq 'problem' || $self->{file_type} eq 'source_path_for_problem_file') {
		# Redirect to Problem.pm or GatewayQuiz.pm.
		# We need to know if the set is a gateway set to determine the redirect.
		my $globalSet = $self->r->db->getGlobalSet($self->{setID});

		$self->reply_with_redirect($self->systemLink(
			defined $globalSet && $globalSet->assignment_type =~ /gateway/
			? $self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::GatewayQuiz', $r,
				courseID => $self->{courseID},
				setID    => 'Undefined_Set'
				)
			: $self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::Problem', $r,
				courseID  => $self->{courseID},
				setID     => $self->{setID},
				problemID => $self->{problemID}
			),
			params => {
				displayMode    => $displayMode,
				problemSeed    => $problemSeed,
				editMode       => 'temporaryFile',
				sourceFilePath => $relativeTempFilePath,
				status_message => uri_escape_utf8($self->{status_message}->join(''))
			}
		));
	} elsif ($self->{file_type} eq 'set_header') {
		# Redirect to ProblemSet
		$self->reply_with_redirect($self->systemLink(
			$self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::ProblemSet', $r,
				courseID => $self->{courseID},
				setID    => $self->{setID},
			),
			params => {
				set_header     => $self->{tempFilePath},
				displayMode    => $displayMode,
				problemSeed    => $problemSeed,
				editMode       => 'temporaryFile',
				sourceFilePath => $relativeTempFilePath,
				status_message => uri_escape_utf8($self->{status_message}->join(''))
			}
		));
	} elsif ($self->{file_type} eq 'hardcopy_header') {
		# Redirect to ProblemSet?? It's difficult to view temporary changes for hardcopy headers.
		$self->reply_with_redirect($self->systemLink(
			$self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::ProblemSet', $r,
				courseID => $self->{courseID},
				setID    => $self->{setID},
			),
			params => {
				set_header     => $self->{tempFilePath},
				displayMode    => $displayMode,
				problemSeed    => $problemSeed,
				editMode       => 'temporaryFile',
				sourceFilePath => $relativeTempFilePath,
				status_message => uri_escape_utf8($self->{status_message}->join(''))
			}
		));
	} elsif ($self->{file_type} eq 'course_info') {
		# Redirect to ProblemSets.pm.
		$self->reply_with_redirect($self->systemLink(
			$self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::ProblemSets',
				$r, courseID => $self->{courseID}
			),
			params => {
				course_info    => $self->{tempFilePath},
				editMode       => 'temporaryFile',
				sourceFilePath => $relativeTempFilePath,
				status_message => uri_escape_utf8($self->{status_message}->join(''))
			}
		));
	} else {
		die "I don't know how to redirect this file type $self->{file_type}.";
	}

	return;
}

# The hardcopy action is handled by javascript.  This is provided just in case
# something goes wrong and the action gets called.
sub hardcopy_action { }

sub add_problem_handler {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;

	my $templatesPath  = $self->r->ce->{courseDirs}{templates};
	my $sourceFilePath = $self->{editFilePath} =~ s|^$templatesPath/||r;

	my $targetSetName  = $r->param('action.add_problem.target_set');
	my $targetFileType = $r->param('action.add_problem.file_type');

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
		my $problemRecord = $self->addProblemToSet(
			setName    => $targetSetName,
			sourceFile => $sourceFilePath,
			problemID  => $targetProblemNumber,
		);

		$self->assignProblemToAllSetUsers($problemRecord);

		$self->addgoodmessage($r->maketext(
			'Added [_1] to [_2] as problem [_3]',
			$sourceFilePath,
			$targetSetName,
			(
				$set->assignment_type eq 'jitar'
				? join('.', jitar_id_to_seq($targetProblemNumber))
				: $targetProblemNumber
			)
		));
		$self->{file_type} = 'problem';    # Change file type to problem if it is not already that.

		# Redirect to problem editor page.
		$self->reply_with_redirect($self->systemLink(
			$self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::Instructor::PGProblemEditor', $r,
				courseID  => $self->{courseID},
				setID     => $targetSetName,
				problemID => $targetProblemNumber,
			),
			params => {
				displayMode    => $self->{displayMode},
				problemSeed    => $self->{problemSeed},
				editMode       => 'savedFile',
				sourceFilePath => $self->getRelativeSourceFilePath($sourceFilePath),
				status_message => uri_escape_utf8($self->{status_message}->join('')),
				file_type      => 'problem',
			}
		));
	} elsif ($targetFileType eq 'set_header') {
		# Update set record
		my $setRecord = $self->r->db->getGlobalSet($targetSetName);
		$setRecord->set_header($sourceFilePath);
		if ($self->r->db->putGlobalSet($setRecord)) {
			$self->addgoodmessage($r->maketext(
				'Added "[_1]" to [_2] as new set header',
				$self->shortPath($sourceFilePath),
				$targetSetName
			));
		} else {
			$self->addbadmessage($r->maketext(
				'Unable to make "[_1]" the set header for [_2].', $self->shortPath($sourceFilePath),
				$targetSetName
			));
		}

		$self->{file_type} = 'set_header';    # Change file type to set_header if not already so.

		# Redirect
		$self->reply_with_redirect($self->systemLink(
			$self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::ProblemSet', $r,
				courseID => $self->{courseID},
				setID    => $targetSetName
			),
			params => {
				displayMode    => $self->{displayMode},
				editMode       => 'savedFile',
				status_message => uri_escape_utf8($self->{status_message}->join('')),
			}
		));
	} elsif ($targetFileType eq 'hardcopy_header') {
		# Update set record
		my $setRecord = $self->r->db->getGlobalSet($targetSetName);
		$setRecord->hardcopy_header($sourceFilePath);
		if ($self->r->db->putGlobalSet($setRecord)) {
			$self->addgoodmessage($r->maketext(
				'Added "[_1]" to [_2] as new hardcopy header',
				$self->shortPath($sourceFilePath),
				$targetSetName
			));
		} else {
			$self->addbadmessage(
				$r->maketext('Unable to make "[_1]" the hardcopy header for [_2].'),
				$self->shortPath($sourceFilePath),
				$targetSetName
			);
		}

		$self->{file_type} = 'hardcopy_header';    # Change file type to set_header if not already so.

		# Redirect
		$self->reply_with_redirect($self->systemLink(
			$self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::Hardcopy', $r,
				courseID => $self->{courseID},
				setID    => $targetSetName
			),
			params => {
				displayMode    => $self->{displayMode},
				editMode       => 'savedFile',
				status_message => uri_escape_utf8($self->{status_message}->join('')),
			}
		));
	} else {
		die "Unsupported target file type $targetFileType";
	}

	return;
}

sub save_handler {
	my $self = shift;
	my $r    = $self->r;

	# Grab the problemContents from the form in order to save it to a new permanent file.
	# Later we will unlink (delete) the current temporary file.
	$self->{r_problemContents} = \(fixProblemContents($self->r->param('problemContents')));

	# Sanity check in case the user has edited the problem set while editing a problem.
	# This can cause the current editor contents to overwrite the new file that is saved for the problem.
	if ($self->{editFilePath} ne $r->param('action.save.source_file')) {
		$self->addbadmessage($r->maketext(
			'File not saved. The file name for this problem does not match the file name the editor was opened with. '
				. 'The problem set may have changed. Please reopen this file from the homework sets editor.'
		));
	} else {
		$self->saveFileChanges($self->{editFilePath});
	}

	# Don't redirect unless it was requested to open in a new window.
	return unless $r->param('newWindowSave');

	if ($self->{file_type} eq 'problem' || $self->{file_type} eq 'source_path_for_problem_file') {
		# Redirect to Problem.pm or GatewayQuiz.pm.
		# We need to know if the set is a gateway set to determine the redirect.
		my $globalSet = $self->r->db->getGlobalSet($self->{setID});

		$self->reply_with_redirect($self->systemLink(
			defined $globalSet && $globalSet->assignment_type =~ /gateway/
			? $self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::GatewayQuiz', $r,
				courseID => $self->{courseID},
				setID    => 'Undefined_Set'
				)
			: $self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::Problem', $r,
				courseID  => $self->{courseID},
				setID     => $self->{setID},
				problemID => $self->{problemID}
			),
			params => {
				displayMode    => $self->{displayMode},
				problemSeed    => $self->{problemSeed},
				editMode       => 'savedFile',
				sourceFilePath => $self->getRelativeSourceFilePath($self->{editFilePath}),
				status_message => uri_escape_utf8($self->{status_message}->join(''))
			}
		));
	} elsif ($self->{file_type} eq 'set_header') {
		# Redirect to ProblemSet
		$self->reply_with_redirect($self->systemLink(
			$self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::ProblemSet', $r,
				courseID => $self->{courseID},
				setID    => $self->{setID},
			),
			params => {
				displayMode    => $self->{displayMode},
				problemSeed    => $self->{problemSeed},
				editMode       => 'savedFile',
				status_message => uri_escape_utf8($self->{status_message}->join(''))
			}
		));
	} elsif ($self->{file_type} eq 'hardcopy_header') {
		# Redirect to ProblemSet
		$self->reply_with_redirect($self->systemLink(
			$self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::Hardcopy', $r,
				courseID => $self->{courseID},
				setID    => $self->{setID},
			),
			params => {
				displayMode    => $self->{displayMode},
				problemSeed    => $self->{problemSeed},
				editMode       => 'savedFile',
				status_message => uri_escape_utf8($self->{status_message}->join(''))
			}
		));
	} elsif ($self->{file_type} eq 'course_info') {
		# Redirect to ProblemSets.pm
		$self->reply_with_redirect($self->systemLink(
			$self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::ProblemSets',
				$r, courseID => $self->{courseID}
			),
			params => {
				editMode       => 'savedFile',
				status_message => uri_escape_utf8($self->{status_message}->join(''))
			}
		));
	} elsif ($self->{file_type} eq 'source_path_for_problem_file') {
		# Redirect to ProblemSets.pm
		$self->reply_with_redirect($self->systemLink(
			$self->r->urlpath->newFromModule(
				'WeBWorK::ContentGenerator::Instructor::PGProblemEditor', $r,
				courseID  => $self->{courseID},
				setID     => $self->{setID},
				problemID => $self->{problemID}
			),
			params => {
				displayMode => $self->{displayMode},
				problemSeed => $self->{problemSeed},
				editMode    => 'savedFile',
				# The path relative to the templates directory is required.
				sourceFilePath => $self->{editFilePath},
				file_type      => 'source_path_for_problem_file',
				status_message => uri_escape_utf8($self->{status_message}->join(''))
			}
		));
	} else {
		die "Unsupported save file type $self->{file_type}.";
	}

	return;
}

sub save_as_handler {
	my ($self) = @_;
	my $r = $self->r;

	$self->{status_message} = $r->c;

	my $do_not_save = 0;

	my $saveMode      = $r->param('action.save_as.saveMode') || 'no_save_mode_selected';
	my $new_file_name = ($r->param('action.save_as.target_file') || '') =~ s/^\s*|\s*$//gr;
	$self->{sourceFilePath} = $r->param('action.save_as.source_file') || '';    # Store for use in saveFileChanges.
	my $file_type = $r->param('action.save_as.file_type') || '';

	# Need a non-blank file name.
	if (!$new_file_name) {
		$do_not_save = 1;
		$self->addbadmessage($r->maketext('Please specify a file to save to.'));
	}

	# Rescue the user in case they forgot to end the file name with the pg extension.
	if (($file_type eq 'problem' || $file_type eq 'blank_problem' || $file_type eq 'set_header')
		&& $new_file_name !~ /\.pg$/)
	{
		$new_file_name .= '.pg';
	}

	# Grab the problemContents from the form in order to save it to a new permanent file.
	# Later we will unlink (delete) the current temporary file.
	$self->{r_problemContents} = \(fixProblemContents($self->r->param('problemContents')));

	# Construct the output file path
	my $outputFilePath = $self->r->ce->{courseDirs}{templates} . "/$new_file_name";
	if (defined $outputFilePath && -e $outputFilePath) {
		$do_not_save = 1;
		$self->addbadmessage($r->maketext(
			'File "[_1]" exists. File not saved. No changes have been made.  '
				. 'You can change the file path for this problem manually from the "Hmwk Sets Editor" page',
			$self->shortPath($outputFilePath)
		));
		$self->addgoodmessage($r->maketext(
			'The text box now contains the source of the original problem. '
				. 'You can recover lost edits by using the Back button on your browser.'
		));
	} else {
		$self->{editFilePath} = $outputFilePath;
		# saveFileChanges will update the tempFilePath and inputFilePath as needed.  Don't do that here.
	}

	unless ($do_not_save) {
		$self->saveFileChanges($outputFilePath);
		my $targetProblemNumber;

		if ($file_type eq 'course_info') {
			# The saveMode is not set for course_info files as there are no such options presented in the form.
			# So set that here so that the correct redirect is chosen below.
			$saveMode = 'new_course_info';
		} elsif ($saveMode eq 'rename' && -r $outputFilePath) {
			# Modify source file path in problem.
			if ($file_type eq 'set_header') {
				my $setRecord = $self->r->db->getGlobalSet($self->{setID});
				$setRecord->set_header($new_file_name);
				if ($self->r->db->putGlobalSet($setRecord)) {
					$self->addgoodmessage($r->maketext(
						'The set header for set [_1] has been renamed to "[_2]".', $self->{setID},
						$self->shortPath($outputFilePath)
					));
				} else {
					$self->addbadmessage($r->maketext(
						'Unable to change the set header for set [_1]. Unknown error.',
						$self->{setID}
					));
				}
			} elsif ($file_type eq 'hardcopy_header') {
				my $setRecord = $self->r->db->getGlobalSet($self->{setID});
				$setRecord->hardcopy_header($new_file_name);
				if ($self->r->db->putGlobalSet($setRecord)) {
					$self->addgoodmessage($r->maketext(
						'The hardcopy header for set [_1] has been renamed to "[_2]".', $self->{setID},
						$self->shortPath($outputFilePath)
					));
				} else {
					$self->addbadmessage($r->maketext(
						'Unable to change the hardcopy header for set [_1]. Unknown error.',
						$self->{setID}
					));
				}
			} else {
				my $problemRecord;
				if ($self->{versionID}) {
					$problemRecord = $self->r->db->getMergedProblemVersion($r->param('effectiveUser'),
						$self->{setID}, $1, $self->{problemID});
				} else {
					$problemRecord = $self->r->db->getGlobalProblem($self->{setID}, $self->{problemID});
				}
				$problemRecord->source_file($new_file_name);
				my $result =
					$self->{versionID}
					? $self->r->db->putProblemVersion($problemRecord)
					: $self->r->db->putGlobalProblem($problemRecord);

				if ($result) {
					$self->addgoodmessage($r->maketext(
						'The source file for "set [_1] / problem [_2] has been changed from "[_3]" to "[_4]".',
						$self->{fullSetID},
						$self->{prettyProblemNumber},
						$self->shortPath($self->{sourceFilePath}),
						$self->shortPath($outputFilePath)
					));
				} else {
					$self->addbadmessage($r->maketext(
						'Unable to change the source file path for set [_1], problem [_2]. Unknown error.',
						$self->{fullSetID}, $self->{prettyProblemNumber}
					));
				}
			}
		} elsif ($saveMode eq 'add_to_set_as_new_problem') {
			my $set = $self->r->db->getGlobalSet($self->{setID});

			# For jitar sets new problems are put as top level problems at the end.
			if ($set->assignment_type eq 'jitar') {
				my @problemIDs = $self->r->db->listGlobalProblems($self->{setID});
				@problemIDs = sort { $a <=> $b } @problemIDs;
				my @seq = jitar_id_to_seq($problemIDs[-1]);
				$targetProblemNumber = seq_to_jitar_id($seq[0] + 1);
			} else {
				$targetProblemNumber = 1 + max($self->r->db->listGlobalProblems($self->{setID}));
			}

			my $problemRecord = $self->addProblemToSet(
				setName    => $self->{setID},
				sourceFile => $new_file_name,
				problemID  => $targetProblemNumber,    # Added to end of set
			);
			$self->assignProblemToAllSetUsers($problemRecord);
			$self->addgoodmessage($r->maketext(
				'Added [_1] to [_2] as problem [_3].',
				$new_file_name,
				$self->{setID},
				(
					$set->assignment_type eq 'jitar'
					? join('.', jitar_id_to_seq($targetProblemNumber))
					: $targetProblemNumber
				)
			));
		} elsif ($saveMode eq 'new_independent_problem') {
			$self->addgoodmessage($r->maketext(
				'A new file has been created at "[_1]" with the contents below.',
				$self->shortPath($outputFilePath)
			));
			$self->addgoodmessage($r->maketext(' No changes have been made to set [_1]', $self->{setID}))
				if ($self->{setID} ne 'Undefined_Set');
		} else {
			$self->addbadmessage($r->maketext('Unkown saveMode: [_1].', $saveMode));
			return;
		}
	}

	# Set up redirect.
	my $problemPage;
	my $new_file_type;

	if ($saveMode eq 'new_course_info') {
		$problemPage = $self->r->urlpath->newFromModule('WeBWorK::ContentGenerator::Instructor::PGProblemEditor',
			$r, courseID => $self->{courseID});
		$new_file_type = 'course_info';
	} elsif ($saveMode eq 'new_independent_problem') {
		$problemPage = $self->r->urlpath->newFromModule(
			'WeBWorK::ContentGenerator::Instructor::PGProblemEditor', $r,
			courseID  => $self->{courseID},
			setID     => 'Undefined_Set',
			problemID => 1
		);
		$new_file_type = 'source_path_for_problem_file';
	} elsif ($saveMode eq 'rename') {
		$problemPage = $self->r->urlpath->newFromModule(
			'WeBWorK::ContentGenerator::Instructor::PGProblemEditor', $r,
			courseID  => $self->{courseID},
			setID     => $self->{setID},
			problemID => $self->{problemID}
		);
		$new_file_type = $file_type;
	} elsif ($saveMode eq 'add_to_set_as_new_problem') {
		$problemPage = $self->r->urlpath->newFromModule(
			'WeBWorK::ContentGenerator::Instructor::PGProblemEditor', $r,
			courseID  => $self->{courseID},
			setID     => $self->{setID},
			problemID => $do_not_save ? $self->{problemID} : max($self->r->db->listGlobalProblems($self->{setID}))
		);
		$new_file_type = $file_type;
	} else {
		$self->addbadmessage($r->maketext(
			'Please use radio buttons to choose the method for saving this file. Uknown saveMode: [_1].', $saveMode
		));
		return;
	}

	$self->reply_with_redirect($self->systemLink(
		$problemPage,
		params => {
			# The path relative to the templates directory is required.
			sourceFilePath => $self->getRelativeSourceFilePath($outputFilePath),
			problemSeed    => $self->{problemSeed},
			file_type      => $new_file_type,
			status_message => uri_escape_utf8($self->{status_message}->join(''))
		}
	));
	return;
}

sub revert_handler {
	my $self = shift;
	my $r    = $self->r;
	my $ce   = $r->ce;

	$self->{inputFilePath} = $self->{editFilePath};

	unless (path_is_subdir($self->{tempFilePath}, $ce->{courseDirs}{templates}, 1)) {
		$self->addbadmessage($r->maketext(
			'The temporary file [_1] is not contained in the course templates directory and can not be deleted.',
			$self->{tempFilePath}
		));
		return;
	}

	# Unlink the temp files;
	unlink($self->{tempFilePath});
	$self->addgoodmessage($r->maketext('Deleted temporary file [_1].', $self->shortPath($self->{tempFilePath})));

	$self->{r_problemContents} = \'';
	$r->param('problemContents', undef);

	$self->addgoodmessage($r->maketext('Reverted to original file "[_1]".', $self->shortPath($self->{editFilePath})));

	return;
}

1;
