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
use File::Basename qw(dirname);

use WeBWorK::Utils qw(getAssetURL jitar_id_to_seq not_blank path_is_subdir seq_to_jitar_id x format_set_name_display
	surePathToFile readDirectory readFile max);
use WeBWorK::ContentGenerator::Instructor::CodeMirrorEditor
	qw(generate_codemirror_html generate_codemirror_controls_html output_codemirror_static_files);

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

	# Determine action.  If an invalid action is sent in, assume this is an initial edit.
	$self->{action} = $r->param('action') // '';
	if ($self->{action} && grep { $_ eq $self->{action} } @{ ACTION_FORMS() }) {
		my $actionHandler = "$self->{action}_handler";
		$self->$actionHandler($self->getActionParams);
	}

	return;
}

sub initialize {
	my $self  = shift;
	my $r     = $self->r;
	my $authz = $r->authz;
	my $user  = $r->param('user');

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
		$self->addbadmessage(CGI::div(
			{ class => 'd-flex flex-column gap-1' },
			CGI::div($r->maketext('The file "[_1]" is protected!', $self->shortPath($self->{inputFilePath}))),
			CGI::div(
				$r->maketext(
					'To edit this text you must first make a copy of this file using the "New Version" action below.')
			)
		));
	}

	if ($self->{inputFilePath} =~ /$BLANKPROBLEM$/ && $file_type ne 'blank_problem') {
		$self->addbadmessage(CGI::div(
			{ class => 'd-flex flex-column gap-1' },
			CGI::div($r->maketext('The file "[_1]" is a blank problem!', $self->shortPath($self->{inputFilePath}))),
			CGI::div(
				$r->maketext(
					'To edit this text you must use the "New Version" action below to save it to another file.')
			)
		));
	}

	return;
}

sub path {
	my ($self, $args) = @_;
	my $r                   = $self->r;
	my $urlpath             = $r->urlpath;
	my $courseName          = $urlpath->arg('courseID');
	my $setName             = $urlpath->arg('setID') // '';
	my $problemNumber       = $urlpath->arg('problemID') || '';
	my $prettyProblemNumber = $problemNumber;

	if ($setName) {
		my $set = $r->db->getGlobalSet($setName);
		if ($set && $set->assignment_type eq 'jitar' && $problemNumber) {
			$prettyProblemNumber = join('.', jitar_id_to_seq($problemNumber));
		}
	}

	# We need to build a path to the problem being edited by hand, since it is not the same as the urlpath for this
	# page.  The bread crumb path leads back to the problem being edited, not to the Instructor tool.
	print $self->pathMacro(
		$args,
		'WeBWorK'              => $r->location,
		$courseName            => $r->location . "/$courseName",
		$setName               => $r->location . "/$courseName/$setName",
		$prettyProblemNumber   => $r->location . "/$courseName/$setName/$problemNumber",
		$r->maketext('Editor') => ''
	);

	return '';
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

sub body {
	my $self  = shift;
	my $r     = $self->r;
	my $db    = $r->db;
	my $ce    = $r->ce;
	my $authz = $r->authz;
	my $user  = $r->param('user');

	# Check permissions
	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		$r->maketext('You are not authorized to access the Instructor tools.'))
		unless $authz->hasPermissions($user, 'access_instructor_tools');

	return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
		$r->maketext('You are not authorized to modify problems.'))
		unless $authz->hasPermissions($user, 'modify_student_data');

	# Gather info
	my $editFilePath  = $self->{editFilePath};    # Path to the permanent file being edited.
	my $tempFilePath  = $self->{tempFilePath};    # Path to the file currently being worked with (might be a .tmp file).
	my $inputFilePath = $self->{inputFilePath};   # Path to the file for input, (might be a .tmp file).
	my $setName       = $self->{setID} // '';     # Allow the numeric set name 0.
	my $problemNumber = $self->{problemID};
	my $fullSetName   = $self->{fullSetID} // $setName;
	$problemNumber = defined $problemNumber ? $problemNumber : '';

	# Construct reference row for PGproblemEditor.
	my @PG_Editor_References;
	for my $link (
		{
			# http://webwork.maa.org/wiki/Category:Problem_Techniques
			label   => $r->maketext('Problem Techniques'),
			url     => $ce->{webworkURLs}{problemTechniquesHelpURL},
			target  => 'techniques_window',
			tooltip => $r->maketext('Snippets of PG code illustrating specific techniques'),
		},
		{
			# http://webwork.maa.org/wiki/Category:MathObjects
			label   => $r->maketext('Math Objects'),
			url     => $ce->{webworkURLs}{MathObjectsHelpURL},
			target  => 'math_objects',
			tooltip => $r->maketext('Wiki summary page for MathObjects'),
		},
		{
			# http://webwork.maa.org/pod/pg_TRUNK/
			label   => $r->maketext('POD'),
			url     => $ce->{webworkURLs}{PODHelpURL},
			target  => 'pod_docs',
			tooltip => $r->maketext(
				'Documentation from source code for PG modules and macro files. '
					. 'Often the most up-to-date information.'
			),
		},
		{
			# https://courses1.webwork.maa.org/webwork2/cervone_course/PGML/1/?login_practice_user=true
			label   => $r->maketext('PGML'),
			url     => $ce->{webworkURLs}{PGMLHelpURL},
			target  => 'PGML',
			tooltip => $r->maketext(
				'PG mark down syntax used to format WeBWorK questions. '
					. 'This interactive lab can help you to learn the techniques.'
			),
		},
		{
			# http://webwork.maa.org/wiki/Category:Authors
			label   => $r->maketext('Author Info'),
			url     => $ce->{webworkURLs}{AuthorHelpURL},
			target  => 'author_info',
			tooltip => $r->maketext('Top level of author information on the wiki.'),
		},
		# Only show the report bugs in problem button if editing an OPL or Contrib problem.
		$editFilePath =~ m|^$ce->{courseDirs}{templates}/([^/]*)/| && ($1 eq 'Library' || $1 eq 'Contrib')
		? {
			label => $r->maketext('Report Bugs in this Problem'),
			url   => "$ce->{webworkURLs}{bugReporter}?product=Problem%20libraries"
				. "&component=$1&bug_file_loc=${editFilePath}_with_problemSeed=$self->{problemSeed}",
			target  => 'bug_report',
			tooltip => $r->maketext(
				'Report bugs in a WeBWorK question/problem using this link. '
					. 'The very first time you do this you will need to register with an email address so that '
					. 'information on the bug fix can be reported back to you.'
			),
		}
		: {}
		)
	{
		next unless $link->{url};
		push(
			@PG_Editor_References,
			CGI::a(
				{
					href              => $link->{url},
					target            => $link->{target},
					title             => $link->{tooltip},
					class             => 'reference-link btn btn-sm btn-info',
					data_bs_toggle    => 'tooltip',
					data_bs_placement => 'top'
				},
				$link->{label}
			)
		);
	}

	# Find the text for the problem, either in the temporary file if it exists, in the original file in the template
	# directory, or in the problem contents gathered in the initialization phase.

	my $problemContents = ${ $self->{r_problemContents} };

	unless ($problemContents =~ /\S/) {    # non-empty contents
		if (-r $tempFilePath && !-d $tempFilePath) {
			return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
				$r->maketext('Unable to open a temporary file at the given location.'))
				unless path_is_subdir($tempFilePath, $ce->{courseDirs}{templates}, 1);

			eval { $problemContents = readFile($tempFilePath) };
			$problemContents = $@ if $@;
			$inputFilePath   = $tempFilePath;
		} elsif (-r $editFilePath && !-d $editFilePath) {
			return CGI::div({ class => 'alert alert-danger p-1 mb-0' },
				$r->maketext('The given file path is not a valid location.'))
				unless path_is_subdir($editFilePath, $ce->{courseDirs}{templates}, 1)
				|| $editFilePath eq $ce->{webworkFiles}{screenSnippets}{setHeader}
				|| $editFilePath eq $ce->{webworkFiles}{hardcopySnippets}{setHeader}
				|| $editFilePath eq $ce->{webworkFiles}{screenSnippets}{blankProblem};

			eval { $problemContents = readFile($editFilePath) };
			$problemContents = $@ if $@;
			$inputFilePath   = $editFilePath;
		} else {
			# File not existing is not an error
			$problemContents = '';
		}
	}

	my $protected_file = !-w $inputFilePath;

	my $prettyProblemNumber = $problemNumber;
	my $set                 = $self->r->db->getGlobalSet($setName);
	$prettyProblemNumber = join('.', jitar_id_to_seq($problemNumber)) if $set && $set->assignment_type eq 'jitar';

	my %titles = (
		blank_problem                => x('Editing <strong>blank problem</strong> in file "[_1]".'),
		set_header                   => x('Editing <strong>set header</strong> file "[_1]".'),
		hardcopy_header              => x('Editing <strong>hardcopy header</strong> file "[_1]".'),
		course_info                  => x('Editing <strong>course information</strong> file "[_1]".'),
		''                           => x('Editing <strong>unknown file type</strong> in file "[_1]".'),
		source_path_for_problem_file => x('Editing <strong>unassigned problem</strong> file "[_1]".')
	);
	my $header = CGI::i(
		$self->{file_type} eq 'problem'
		? $r->maketext(
			'Editing <strong>problem [_1] of set [_2]</strong> in file "[_3]".',
			$prettyProblemNumber,
			CGI::span({ dir => 'ltr' }, format_set_name_display($fullSetName)),
			CGI::span({ dir => 'ltr' }, $self->shortPath($inputFilePath))
			)
		: $r->maketext($titles{ $self->{file_type} }, $self->shortPath($inputFilePath))
	);
	$header = $self->isTempEditFilePath($inputFilePath)
		? CGI::div({ class => 'temporaryFile' }, $header)    # Use colors if this is a temporary file.
		: $header;

	# Output page contents

	print CGI::div({ class => 'mb-2' }, $header);
	print CGI::start_form({
		method  => 'POST',
		id      => 'editor',
		name    => 'editor',
		action  => $r->uri,
		enctype => 'application/x-www-form-urlencoded',
		class   => 'col-12'
	});

	print $self->hidden_authen_fields;
	print CGI::hidden({ name => 'file_type',      value => $self->{file_type} });
	print CGI::hidden({ name => 'courseID',       value => $self->{courseID} });
	print CGI::hidden({ name => 'hidden_set_id',  value => $setName }) if defined $setName;
	print CGI::hidden({ name => 'sourceFilePath', value => $self->{sourceFilePath} })
		if not_blank($self->{sourceFilePath});
	print CGI::hidden({ name => 'edit_file_path', value => $self->getRelativeSourceFilePath($self->{editFilePath}) })
		if ($self->{file_type} eq 'problem' || $self->{file_type} eq 'source_path_for_problem_file')
		&& not_blank($self->{editFilePath});
	print CGI::hidden({ name => 'temp_file_path', value => $self->{tempFilePath} }) if not_blank($self->{tempFilePath});

	print CGI::div({ class => 'mb-2' }, @PG_Editor_References);

	print CGI::div(
		{ class => 'row mb-2' },
		CGI::div(
			{ class => 'col-lg-6 col-md-12 order-last order-lg-first' },
			generate_codemirror_html($r, 'problemContents', $problemContents)
		),
		CGI::div(
			{ class => 'col-lg-6 col-md-12 mb-lg-0 mb-2 order-first order-lg-last' },
			CGI::div(
				{ class => 'p-0', id => 'pgedit-render-area', },
				CGI::div(
					{
						class => 'placeholder d-flex flex-column justify-content-center align-items-center '
							. 'bg-secondary h-100'
					},
					CGI::div({ class => 'fs-1' }, $r->maketext('Loading...')),
					CGI::i({ class => 'fa-solid fa-spinner fa-spin fa-2x' }, '')
				)
			)
		)
	);

	print generate_codemirror_controls_html($r);

	# Print action forms

	my @formsToShow      = @{ ACTION_FORMS() };
	my %actionFormTitles = %{ ACTION_FORM_TITLES() };
	my $default_choice;

	my @tabArr;
	my @contentArr;

	for my $actionID (@formsToShow) {
		my $actionForm    = "${actionID}_form";
		my $line_contents = $self->$actionForm;
		my $active        = '';

		if ($line_contents) {
			unless ($default_choice) { $active = ' active'; $default_choice = $actionID; }
			push(
				@tabArr,
				CGI::li(
					{ class => 'nav-item', role => 'presentation' },
					CGI::a(
						{
							href           => "#$actionID",
							class          => "nav-link action-link$active",
							id             => "$actionID-tab",
							data_action    => $actionID,
							data_bs_toggle => 'tab',
							data_bs_target => "#$actionID",
							role           => 'tab',
							aria_controls  => $actionID,
							aria_selected  => $active ? 'true' : 'false'
						},
						$r->maketext($actionFormTitles{$actionID})
					)
				)
			);
			push(
				@contentArr,
				CGI::div(
					{
						class           => 'tab-pane fade' . ($active ? " show$active" : ''),
						id              => $actionID,
						role            => 'tabpanel',
						aria_labelledby => "$actionID-tab"
					},
					$line_contents
				)
			);
		}
	}

	print CGI::hidden({ name => 'action', id => 'current_action', value => $default_choice });
	print CGI::div(CGI::ul({ class => 'nav nav-tabs mb-2', role => 'tablist' }, @tabArr),
		CGI::div({ class => 'tab-content' }, @contentArr));

	print CGI::div(CGI::submit({
		id    => 'submit_button_id',
		name  => 'submit',
		value => $r->maketext('Take Action!'),
		class => 'btn btn-primary'
	}));

	print CGI::end_form();

	return '';
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
			$errorMessage = $r->maketext(
				'Unable to write to "[_1]": [_2]',
				$self->shortPath($outputFilePath),
				CGI::pre($writeFileErrors)
			);
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
					$self->addbadmessage(CGI::div($r->maketext('Error copying [_1] to [_2].', $fromPath, $toPath)))
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
		my $msg = $r->maketext('Saved to file "[_1]"', $self->shortPath($outputFilePath));
		$self->addgoodmessage($msg);
	}

	return;
}

sub getActionParams {
	my ($self) = @_;
	my $r = $self->r;

	my %actionParams;
	for ($r->param) {
		next unless $_ =~ m/^action\.$self->{action}\./;
		$actionParams{$_} = [ $r->param($_) ];
	}
	return %actionParams;
}

# Fix line endings in the problem contents.
# Make sure that all of the line endings are of unix type and convert \r\n to \n.
sub fixProblemContents {
	my $problemContents = shift;
	return $problemContents =~ s/(\r\n)|(\r)/\n/gr;
}

sub view_form {
	my $self = shift;
	my $r    = $self->r;

	# Hardcopy headers are previewed from the hardcopy generation tab.
	return '' if $self->{file_type} eq 'hardcopy_header';

	return CGI::div(
		CGI::div(
			{ class => 'row align-items-center' },
			CGI::label(
				{ for => 'action_view_seed_id', class => 'col-form-label col-auto mb-2' },
				$r->maketext('Using what seed?')
			),
			CGI::div(
				{ class => 'col-auto mb-2' },
				CGI::textfield({
					id    => 'action_view_seed_id',
					name  => 'action.view.seed',
					value => $self->{problemSeed},
					class => 'form-control form-control-sm'
				})
			),
			CGI::div(
				{ class => 'col-auto mb-2' },
				CGI::button({
					id    => 'randomize_view_seed_id',
					name  => 'action.randomize.view.seed',
					value => $r->maketext('Randomize Seed'),
					class => 'btn btn-info btn-sm'
				})
			)
		),
		CGI::div(
			{ class => 'row align-items-center mb-2' },
			CGI::label(
				{ for => 'action_view_displayMode_id', class => 'col-form-label col-auto' },
				$r->maketext('Using what display mode?')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'action_view_displayMode_id',
					name    => 'action.view.displayMode',
					values  => $self->r->ce->{pg}{displayModes},
					class   => 'form-select form-select-sm d-inline w-auto',
					default => $self->{displayMode}
				})
			)
		),
		CGI::div(
			{ class => 'row g-0 mb-2' },
			CGI::div(
				{ class => 'form-check mb-2' },
				CGI::input({
					type  => 'checkbox',
					id    => 'newWindowView',
					class => 'form-check-input'
				}),
				CGI::label(
					{ for => 'newWindowView', class => 'form-check-label' },
					$r->maketext('Open in new window')
				)
			)
		)
	);
}

sub view_handler {
	my ($self, %actionParams) = @_;
	my $r = $self->r;

	my $problemSeed = $actionParams{'action.view.seed'} ? $actionParams{'action.view.seed'}[0] : DEFAULT_SEED();
	my $displayMode =
		$actionParams{'action.view.displayMode'}
		? $actionParams{'action.view.displayMode'}[0]
		: $self->r->ce->{pg}{options}{displayMode};

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
				status_message => uri_escape_utf8($self->{status_message})
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
				status_message => uri_escape_utf8($self->{status_message})
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
				status_message => uri_escape_utf8($self->{status_message})
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
				status_message => uri_escape_utf8($self->{status_message})
			}
		));
	} else {
		die "I don't know how to redirect this file type $self->{file_type}.";
	}

	return;
}

sub hardcopy_form {
	my $self = shift;
	my $r    = $self->r;
	my $ce   = $r->ce;

	return '' if $self->{file_type} eq 'course_info';

	return CGI::div(
		CGI::div(
			{ class => 'row align-items-center' },
			CGI::label(
				{ for => 'action_hardcopy_seed_id', class => 'col-form-label col-auto mb-2' },
				$r->maketext('Using what seed?')
			),
			CGI::div(
				{ class => 'col-auto mb-2' },
				CGI::textfield({
					id    => 'action_hardcopy_seed_id',
					name  => 'action.hardcopy.seed',
					value => $self->{problemSeed},
					class => 'form-control form-control-sm'
				})
			),
			CGI::div(
				{ class => 'col-auto mb-2' },
				CGI::button({
					id    => 'randomize_hardcopy_seed_id',
					name  => 'action.randomize.hardcopy.seed',
					value => $r->maketext('Randomize Seed'),
					class => 'btn btn-info btn-sm'
				})
			)
		),
		CGI::div(
			{ class => 'row align-items-center mb-2' },
			CGI::label(
				{ for => 'action_hardcopy_format_id', class => 'col-form-label col-auto' },
				$r->maketext('Using which hardcopy format?'),
				CGI::a(
					{
						class           => 'help-popup',
						data_bs_content => $r->maketext(
							'If "PDF" is selected, then a PDF file will be generated for download, unless there are '
								. 'errors.  If errors occur generating a PDF file or "TeX Source" is selected then a '
								. 'zip file will be generated for download that contains the TeX source file and '
								. 'resources needed for generating the PDF file using pdflatex.'
						),
						data_bs_placement => 'top',
						data_bs_toggle    => 'popover',
						role              => 'button',
						tabindex          => 0
					},
					CGI::i(
						{
							class       => 'icon fas fa-question-circle',
							data_alt    => $r->maketext('Help Icon'),
							aria_hidden => 'true'
						},
						''
					)
				)
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'action_hardcopy_format_id',
					name    => 'action.hardcopy.format',
					values  => [ 'pdf', 'tex' ],
					labels  => { pdf => $r->maketext('PDF'), tex => $r->maketext('TeX Source') },
					default => $r->param('action.hardcopy.format') // 'pdf',
					class   => 'form-select form-select-sm d-inline w-auto',
				})
			)
		),
		CGI::div(
			{ class => 'row align-items-center mb-2' },
			CGI::label(
				{ for => 'action_hardcopy_theme_id', class => 'col-form-label col-auto' },
				$r->maketext('Using which hardcopy theme?')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'action_hardcopy_theme_id',
					name    => 'action.hardcopy.theme',
					values  => $ce->{hardcopyThemes},
					default => $r->param('action.hardcopy.theme') // $ce->{hardcopyTheme},
					labels  => { map { $_ => $ce->{hardcopyThemeNames}{$_} } @{ $ce->{hardcopyThemes} } },
					class   => 'form-select form-select-sm d-inline w-auto'
				})
			)
		)
	);
}

# The hardcopy action is handled by javascript.  This is provided just in case
# something goes wrong and the action gets called.
sub hardcopy_action { }

sub add_problem_form {
	my $self = shift;
	my $r    = $self->r;

	return '' if $self->{file_type} eq 'course_info';

	my $allSetNames = [ map { $_->[0] =~ s/^set|\.def$//gr } $r->db->listGlobalSetsWhere({}, 'set_id') ];

	return CGI::div(
		CGI::div(
			{ class => 'row align-items-center mb-2' },
			CGI::label(
				{ for => 'action_add_problem_target_set_id', class => 'col-form-label col-auto' },
				$r->maketext('Add to what set?')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id      => 'action_add_problem_target_set_id',
					name    => 'action.add_problem.target_set',
					values  => $allSetNames,
					labels  => { map { $_ => format_set_name_display($_) } @$allSetNames },
					class   => 'form-select form-select-sm d-inline w-auto',
					dir     => 'ltr',
					default => $self->{setID} // ''
				})
			)
		),
		CGI::div(
			{ class => 'row align-items-center mb-2' },
			CGI::label(
				{ for => 'action_add_problem_file_type_id', class => 'col-form-label col-auto' },
				$r->maketext('Add as what filetype?')
			),
			CGI::div(
				{ class => 'col-auto' },
				CGI::popup_menu({
					id     => 'action_add_problem_file_type_id',
					name   => 'action.add_problem.file_type',
					values => [ 'problem', 'set_header', 'hardcopy_header' ],
					labels => {
						problem         => 'problem',
						set_header      => 'set header',
						hardcopy_header => 'hardcopy header',
					},
					class   => 'form-select form-select-sm d-inline w-auto',
					default => $self->{file_type}
				})
			)
		)
	);
}

sub add_problem_handler {
	my ($self, %actionParams) = @_;
	my $r  = $self->r;
	my $db = $r->db;

	my $templatesPath  = $self->r->ce->{courseDirs}{templates};
	my $sourceFilePath = $self->{editFilePath} =~ s|^$templatesPath/||r;

	my $targetSetName  = $actionParams{'action.add_problem.target_set'}[0];
	my $targetFileType = $actionParams{'action.add_problem.file_type'}[0];

	if ($targetFileType eq 'problem') {
		my $targetProblemNumber;

		my $set = $db->getGlobalSet($targetSetName);

		if ($set->assignment_type eq 'jitar') {
			# For jitar sets new problems are put as top level problems at the end.
			my @problemIDs = map { $_->[1] } $db->listGlobalProblemsWhere({ set_id => $targetSetName }, 'problem_id');
			my @seq        = jitar_id_to_seq($problemIDs[-1]);
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
				status_message => uri_escape_utf8($self->{status_message}),
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
				status_message => uri_escape_utf8($self->{status_message}),
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
				status_message => uri_escape_utf8($self->{status_message}),
			}
		));
	} else {
		die "Unsupported target file type $targetFileType";
	}

	return;
}

sub save_form {
	my $self = shift;
	my $r    = $self->r;

	if ($self->{editFilePath} =~ /$BLANKPROBLEM$/) {
		# Can't save blank problems without changing names.
		return '';
	} elsif (-w $self->{editFilePath}) {
		return CGI::div(
			CGI::div(
				{ class => 'mb-2' },
				$r->maketext(
					'Save to [_1] and View',
					CGI::b({ dir => 'ltr' }, $self->shortPath($self->{editFilePath}))
				)
			),
			CGI::div(
				{ class => 'form-check mb-2' },
				CGI::input({
					type  => 'checkbox',
					name  => 'newWindowSave',
					id    => 'newWindowSave',
					class => 'form-check-input',
					$self->{file_type} eq 'hardcopy_header' ? (checked => undef) : ()
				}),
				CGI::label(
					{ for => 'newWindowSave', class => 'form-check-label' },
					$r->maketext('Open in new window')
				)
			),
			CGI::hidden({ name => 'action.save.source_file', value => $self->{editFilePath} }),
		);
	} else {
		# Can't save. No write permission.
		return '';
	}
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
				status_message => uri_escape_utf8($self->{status_message})
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
				status_message => uri_escape_utf8($self->{status_message})
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
				status_message => uri_escape_utf8($self->{status_message})
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
				status_message => uri_escape_utf8($self->{status_message})
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
				status_message => uri_escape_utf8($self->{status_message})
			}
		));
	} else {
		die "Unsupported save file type $self->{file_type}.";
	}

	return;
}

sub save_as_form {
	my $self = shift;
	my $r    = $self->r;

	my $templatesDir  = $self->r->ce->{courseDirs}{templates};
	my $shortFilePath = $self->{editFilePath} =~ s|^$templatesDir/||r;

	# Suggest that modifications be saved to the "local" subdirectory if its not in a writeable directory
	$shortFilePath = 'local/' . $shortFilePath
		if (!-w dirname($self->{editFilePath}));

	# If it is an absolute path make it relative.
	$shortFilePath =~ s|^/*|| if $shortFilePath =~ m|^/|;

	my $probNum = $self->{file_type} eq 'problem' ? $self->{problemID} : 'header';

	# Don't add or replace problems to sets if the set is the Undefined_Set or if the problem is the blank_problem.
	my $can_add_problem_to_set =
		not_blank($self->{setID}) && $self->{setID} ne 'Undefined_Set' && $self->{file_type} ne 'blank_problem';

	my $prettyProbNum = $probNum;
	if ($self->{setID}) {
		my $set = $self->r->db->getGlobalSet($self->{setID});
		$prettyProbNum = join('.', jitar_id_to_seq($probNum))
			if ($self->{file_type} eq 'problem' && $set && $set->assignment_type eq 'jitar');
	}

	return CGI::div(
		CGI::div(
			{ class => 'row align-items-center mb-2' },
			CGI::label(
				{ for => 'action_save_as_target_file_id', class => 'col-form-label col-auto' },
				$r->maketext('Save file to:')
			),
			CGI::div(
				{ class => 'col-auto d-inline-flex', dir => 'ltr' },
				CGI::div(
					{ class => 'editor-save-path input-group input-group-sm' },
					CGI::label({ for => 'action_save_as_target_file_id', class => 'input-group-text' }, '[TMPL]/'),
					CGI::textfield({
						id    => 'action_save_as_target_file_id',
						name  => 'action.save_as.target_file',
						size  => 60,
						value => $shortFilePath,
						class => 'form-control form-control-sm',
						dir   => 'ltr'
					})
				)
			),
			CGI::hidden({ name => 'action.save_as.source_file', value => $self->{editFilePath} }),
			CGI::hidden({ name => 'action.save_as.file_type',   value => $self->{file_type} })
		),
		(
			$can_add_problem_to_set ? CGI::div(
				{ class => 'form-check' },
				CGI::input({
					type    => 'radio',
					id      => 'action_save_as_saveMode_rename_id',
					name    => 'action.save_as.saveMode',
					value   => 'rename',
					checked => undef,
					class   => 'form-check-input',
				}),
				CGI::label(
					{ for => 'action_save_as_saveMode_rename_id', class => 'form-check-label' },
					$r->maketext(
						'Replace current problem: [_1]',
						CGI::strong(
							CGI::span({ dir => 'ltr' }, format_set_name_display($self->{fullSetID}))
								. "/$prettyProbNum"
						)
					)
				)
			) : ''
		),
		(
			$can_add_problem_to_set ? CGI::div(
				{ class => 'form-check' },
				CGI::input({
					type  => 'radio',
					id    => 'action_save_as_saveMode_new_problem_id',
					name  => 'action.save_as.saveMode',
					value => 'add_to_set_as_new_problem',
					class => 'form-check-input',
				}),
				CGI::label(
					{ for => 'action_save_as_saveMode_new_problem_id', class => 'form-check-label' },
					$r->maketext(
						'Append to end of [_1] set',
						CGI::strong({ dir => 'ltr' }, format_set_name_display($self->{fullSetID}))
					)
				)
			) : ''
		),
		CGI::div(
			{ class => 'form-check' },
			CGI::input({
				type  => 'radio',
				id    => 'action_save_as_saveMode_independent_problem_id',
				name  => 'action.save_as.saveMode',
				value => 'new_independent_problem',
				class => 'form-check-input',
				$can_add_problem_to_set ? () : (checked => undef)
			}),
			CGI::label(
				{ for => 'action_save_as_saveMode_independent_problem_id', class => 'form-check-label' },
				$r->maketext('Create unattached problem')
			)
		)
	);
}

sub save_as_handler {
	my ($self, %actionParams) = @_;
	my $r = $self->r;

	$self->{status_message} = '';

	my $do_not_save = 0;

	my $saveMode      = $actionParams{'action.save_as.saveMode'}[0] || 'no_save_mode_selected';
	my $new_file_name = ($actionParams{'action.save_as.target_file'}[0] || '') =~ s/^\s*|\s*$//gr;
	$self->{sourceFilePath} = $actionParams{'action.save_as.source_file'}[0] || '';  # Store for use in saveFileChanges.
	my $file_type = $actionParams{'action.save_as.file_type'}[0] || '';

	# Need a non-blank file name.
	if (!$new_file_name) {
		$do_not_save = 1;
		$self->addbadmessage(CGI::div($r->maketext('Please specify a file to save to.')));
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
		$self->addbadmessage(CGI::div($r->maketext(
			'File "[_1]" exists. File not saved. No changes have been made.  '
				. 'You can change the file path for this problem manually from the "Hmwk Sets Editor" page',
			$self->shortPath($outputFilePath)
		)));
		$self->addgoodmessage(CGI::div($r->maketext(
			'The text box now contains the source of the original problem. '
				. 'You can recover lost edits by using the Back button on your browser.'
		)));
	} else {
		$self->{editFilePath} = $outputFilePath;
		# saveFileChanges will update the tempFilePath and inputFilePath as needed.  Don't do that here.
	}

	unless ($do_not_save) {
		$self->saveFileChanges($outputFilePath);
		my $targetProblemNumber;

		if ($saveMode eq 'rename' && -r $outputFilePath) {
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
				my $prettyProblemNumber = $self->{problemID};
				my $set                 = $self->r->db->getGlobalSet($self->{setID});
				$prettyProblemNumber = join('.', jitar_id_to_seq($self->{problemID}))
					if ($set && $set->assignment_type eq 'jitar');

				if ($result) {
					$self->addgoodmessage($r->maketext(
						'The source file for "set [_1] / problem [_2] has been changed from "[_3]" to "[_4]".',
						$self->{fullSetID},
						$prettyProblemNumber,
						$self->shortPath($self->{sourceFilePath}),
						$self->shortPath($outputFilePath)
					));
				} else {
					$self->addbadmessage($r->maketext(
						'Unable to change the source file path for set [_1], problem [_2]. Unknown error.',
						$self->{fullSetID}, $prettyProblemNumber
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

	if ($saveMode eq 'new_independent_problem') {
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
			status_message => uri_escape_utf8($self->{status_message})
		}
	));
	return;
}

sub revert_form {
	my $self = shift;
	my $r    = $self->r;
	return $r->maketext('Error: The original file [_1] cannot be read.', $self->{editFilePath})
		unless -r $self->{editFilePath};
	return '' unless defined $self->{tempFilePath} && -e $self->{tempFilePath};
	return $r->maketext('Revert to [_1]', CGI::span({ dir => 'ltr' }, $self->shortPath($self->{editFilePath})));
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

	$self->addgoodmessage($r->maketext('Reverted to original file "[_1]".', $self->shortPath($self->{editFilePath})));

	return;
}

sub output_JS {
	my $self = shift;
	my $ce   = $self->r->ce;

	output_codemirror_static_files($ce);

	print CGI::script({ src => getAssetURL($ce, 'js/apps/ActionTabs/actiontabs.js'),           defer => undef }, '');
	print CGI::script({ src => getAssetURL($ce, 'js/apps/PGProblemEditor/pgproblemeditor.js'), defer => undef }, '');

	return '';
}

1;
