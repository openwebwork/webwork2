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

package WeBWorK::ContentGenerator::Hardcopy;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator::Hardcopy - generate printable versions of one or more
problem sets.

=cut

use File::Temp qw/tempdir/;
use Mojo::File;
use String::ShellQuote;
use Archive::Zip::SimpleZip qw($SimpleZipError);
use XML::LibXML;

use WeBWorK::DB::Utils qw/user2global/;
use WeBWorK::PG;
use WeBWorK::Utils qw/readFile decodeAnswers jitar_id_to_seq is_restricted after x/;
use WeBWorK::Utils::Rendering qw(renderPG);
use PGrandom;

=head1 CONFIGURATION VARIABLES

=over

=item $PreserveTempFiles

If true, don't delete temporary files.

=cut

our $PreserveTempFiles = $PreserveTempFiles // 0;

=back

=cut

our $HC_DEFAULT_FORMAT = "pdf";    # problems if this is not an allowed format for the user...
our %HC_FORMATS        = (
	tex => { name => x("TeX Source"), subr => "generate_hardcopy_tex", file_type => 'application/zip' },
	pdf => { name => x("Adobe PDF"),  subr => "generate_hardcopy_pdf", file_type => 'application/pdf' },
);
our @HC_FORMAT_DISPLAY_ORDER = ('tex', 'pdf');

# custom fields used in $c hash
# FOR HEAVEN'S SAKE, PLEASE KEEP THIS UP-TO-DATE!
#
# file_path
#   Contains the path of the final hardcopy file generated relative to the temporary directory parent.
#   This is set by generate_hardcopy(), and used by pre_header_initialize() and body().
#
# file_name
#   Contains the name of the final hardcopy file generated  without path.
#   This is set by generate_hardcopy(), and used by pre_header_initialize() only on successful hardcopy generation.
#
# file_type
#   Contains the type of the final hardcopy file (either pdf or zip).
#   This is set by generate_hardcopy(), and used by pre_header_initialize() only on successful hardcopy generation.
#
# temp_file_map
#   Reference to a hash mapping temporary file names to URL.
#   Set by generate_hardcopy(), and used by pre_header_initialize(), used by body()
#
# hardcopy_errors
#   reference to an array of Mojo::ByteStream objects containing HTML strings
#   describing generation errors (and warnings)
#   used by add_error(), has_errors(), get_errors()
#
# at_least_one_problem_rendered_without_error
#   set to a true value by write_problem_tex if it is able to sucessfully render
#   a problem. checked by generate_hardcopy to determine whether to continue
#   with the generation process.
#
# versioned
#   set to a true value in write_set_tex if the set_id indicates that
#   the set being rendered is a versioned set; this is used in
#   write_problem_tex to determine which problem merging routine from
#   DB.pm to use, and to indicate what problem number in a versioned
#   test we're on
#
# mergedSets
#   a reference to a hash { userID!setID => setObject }, where setID is
#   either the set id or the fake versioned set id "setName,vN" depending
#   on whether the set is a versioned set or not.  this may include the
#   sets for which the hardcopy is being generated (or may not), depending
#   on whether they were needed to determine the required permissions for
#   generating a hardcopy
#
# canShowScore
#   a reference to a hash { userID!setID => boolean }, where setID is either
#   the set id or the fake versioned set id "setName,vN" depending on whether
#   the set is a versioned set or not, and the value of the boolean is
#   determined by the corresponding userSet's value of hide_score and the
#   current time

################################################################################
# UI subroutines
################################################################################

async sub pre_header_initialize ($c) {
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;

	my $userID            = $c->param('user');
	my $eUserID           = $c->param('effectiveUser');
	my @setIDs            = $c->param('selected_sets');
	my @userIDs           = $c->param('selected_users');
	my $hardcopy_format   = $c->param('hardcopy_format');
	my $generate_hardcopy = $c->param('generate_hardcopy');

	# This should never happen, but apparently it did once (see bug #714), so we check for it.
	die 'Parameter "user" not defined -- this should never happen' unless defined $userID;

	# Check to see if the user is authorized to view source file paths.
	$c->{can_show_source_file} =
		($db->getPermissionLevel($userID)->permission >=
			$ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_PERMISSION_LEVEL})
		|| (grep { $_ eq $userID } @{ $ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} });

	if ($generate_hardcopy) {
		my $validation_failed = 0;

		# Set the default format.
		$hardcopy_format = $HC_DEFAULT_FORMAT unless defined $hardcopy_format;

		# Make sure the format is valid.
		unless (grep { $_ eq $hardcopy_format } keys %HC_FORMATS) {
			$c->addbadmessage(qq{"$hardcopy_format" is not a valid hardcopy format.});
			$validation_failed = 1;
		}

		# Make sure we are allowed to generate hardcopy in this format.
		unless ($authz->hasPermissions($userID, "download_hardcopy_format_$hardcopy_format")) {
			$c->addbadmessage(
				$c->maketext('You do not have permission to generate hardcopy in [_1] format.', $hardcopy_format));
			$validation_failed = 1;
		}

		# Make sure we are allowed to use this hardcopy theme.
		unless ($authz->hasPermissions($userID, 'download_hardcopy_change_theme')
			|| !defined($c->param('hardcopy_theme')))
		{
			$c->addbadmessage($c->maketext('You do not have permission to change the hardcopy theme.'));
			$validation_failed = 1;
		}

		# Is there at least one user selected?
		unless (@userIDs) {
			$c->addbadmessage($c->maketext('Please select at least one user and try again.'));
			$validation_failed = 1;
		}

		# Is there at least one set selected?
		# When students don't select any sets the size of @setIDs is 1 with a null character in $setIDs[0].
		# When professors don't select any sets the size of @setIDs is 0.
		# The following test catches both cases and prevents warning messages in the case of a professor's empty array.
		unless (@setIDs && $setIDs[0] =~ /\S+/) {
			$c->addbadmessage($c->maketext('Please select at least one set and try again.'));
			$validation_failed = 1;
		}

		# Is the user allowed to request multiple sets/users at a time?
		my $perm_multiset  = $authz->hasPermissions($userID, 'download_hardcopy_multiset');
		my $perm_multiuser = $authz->hasPermissions($userID, 'download_hardcopy_multiuser');

		my $perm_viewhidden = $authz->hasPermissions($userID, 'view_hidden_work');
		my $perm_viewfromip = $authz->hasPermissions($userID, 'view_ip_restricted_sets');

		my $perm_viewunopened = $authz->hasPermissions($userID, 'view_unopened_sets');

		if (@setIDs > 1 && !$perm_multiset) {
			$c->addbadmessage('You are not permitted to generate hardcopy for multiple sets. '
					. 'Please select a single set and try again.');
			$validation_failed = 1;
		}
		if (@userIDs > 1 && !$perm_multiuser) {
			$c->addbadmessage('You are not permitted to generate hardcopy for multiple users. '
					. 'Please select a single user and try again.');
			$validation_failed = 1;
		}
		if (@userIDs && $userIDs[0] ne $eUserID && !$perm_multiuser) {
			$c->addbadmessage('You are not permitted to generate hardcopy for other users.');
			$validation_failed = 1;
			# FIXME: Download_hardcopy_multiuser controls both whether a user can generate hardcopy
			# that contains sets for multiple users AND whether the user can generate hardcopy that contains
			# sets for users other than herself. Should these be separate permission levels?
		}

		# To check if the set has a "hide_work" flag, or if we aren't allowed to view the set from the user's IP
		# address, we need the userset objects. If we've not failed validation yet, get those to check on this.
		my %canShowScore = ();
		my %mergedSets   = ();
		unless ($validation_failed) {
			foreach my $sid (@setIDs) {
				my ($s, undef, $v) = ($sid =~ /([^,]+)(,v(\d+))?$/);
				foreach my $uid (@userIDs) {
					if ($perm_viewhidden && $perm_viewfromip) {
						$canShowScore{"$uid!$sid"} = 1;
					} else {
						my $userSet;
						if (defined($v)) {
							$userSet = $db->getMergedSetVersion($uid, $s, $v);
						} else {
							$userSet = $db->getMergedSet($uid, $s);
						}
						$mergedSets{"$uid!$sid"} = $userSet;

						if (
							!$perm_viewunopened
							&& !(
								time >= $userSet->open_date && !(
									$ce->{options}{enableConditionalRelease}
									&& is_restricted($db, $userSet, $userID)
								)
							)
							)
						{
							$validation_failed = 1;
							$c->addbadmessage(
								$c->maketext('You are not permitted to generate a hardcopy for an unopened set.'));
							last;

						}

						if (
							!$perm_viewhidden
							&& defined($userSet->hide_work)
							&& ($userSet->hide_work eq 'Y'
								|| ($userSet->hide_work eq 'BeforeAnswerDate' && time < $userSet->answer_date))
							)
						{
							$validation_failed = 1;
							$c->addbadmessage(
								$c->maketext(
									'You are not permitted to generate a hardcopy for a set with hidden work.')
							);
							last;
						}

						if ($authz->invalidIPAddress($userSet)) {
							$validation_failed = 1;
							$c->addbadmessage($c->maketext(
								'You are not allowed to generate a hardcopy for [_1] from your IP address, [_2].',
								$userSet->set_id, $c->tx->remote_address
							));
							last;
						}

						$canShowScore{"$uid!$sid"} = (!defined($userSet->hide_score) || $userSet->hide_score eq '')
							|| ($userSet->hide_score eq 'N'
								|| ($userSet->hide_score eq 'BeforeAnswerDate' && time >= $userSet->answer_date));
					}
					last if $validation_failed;
				}
			}
		}

		unless ($validation_failed) {
			$c->{canShowScore} = \%canShowScore;
			$c->{mergedSets}   = \%mergedSets;
			my $result = await $c->generate_hardcopy($hardcopy_format, \@userIDs, \@setIDs);
			if ($c->has_errors) {
				# Store the result data in self hash so that body() can make a link to it.
				$c->{file_path}     = $result->{file_path};
				$c->{temp_file_map} = $result->{temp_file_map};
			} else {
				# Send the file only (it is deleted from the server after it is sent).
				$c->reply_with_file($result->{file_type}, $result->{file_path}, $result->{file_name}, 1);
			}
		}

		return;
	}

	my $tempFile = $c->param('tempFilePath');
	if ($tempFile) {
		my $courseID     = $c->stash('courseID');
		my $baseName     = $tempFile =~ s/.*\/([^\/]*)$/$1/r;
		my $fullFilePath = "$ce->{webworkDirs}{tmp}/$courseID/hardcopy/$userID/$tempFile";

		unless (-e $fullFilePath) {
			$c->addbadmessage($c->maketext('The requested file "[_1]" does not exist on the server.', $tempFile));
			return;
		}

		unless ($baseName =~ /\.$userID\./ || $authz->hasPermissions($userID, 'download_hardcopy_multiuser')) {
			$c->addbadmessage($c->maketext('You do not have permission to access the requested file "[_1]".'),
				$tempFile);
			return;
		}

		# All of the files that could be served here are text files except for the pdf or zip file
		# (and the zip file won't actually be served in this way either technically -- but just in case).
		my $type = 'text/plain';
		$type = 'application/pdf' if $baseName =~ m/\.pdf/;
		$type = 'application/zip' if $baseName =~ m/\.zip/;

		$c->reply_with_file($type, $fullFilePath, $baseName);
	}

	return;
}

sub display_form ($c) {
	my $db      = $c->db;
	my $ce      = $c->ce;
	my $authz   = $c->authz;
	my $userID  = $c->param("user");
	my $eUserID = $c->param("effectiveUser");

	# first time we show up here, fill in some values
	unless ($c->param("in_hc_form")) {
		# if a set was passed in via the path_info, add that to the list of sets.
		my $singleSet = $c->stash('setID');
		if (defined $singleSet && $singleSet ne '') {
			my @selected_sets = $c->param("selected_sets");
			$c->param("selected_sets" => [ @selected_sets, $singleSet ])
				unless grep { $_ eq $singleSet } @selected_sets;
		}

		# if no users are selected, select the effective user
		my @selected_users = $c->param("selected_users");
		unless (@selected_users) {
			$c->param("selected_users" => $eUserID);
		}
	}

	my $perm_multiset       = $authz->hasPermissions($userID, "download_hardcopy_multiset");
	my $perm_multiuser      = $authz->hasPermissions($userID, "download_hardcopy_multiuser");
	my $perm_texformat      = $authz->hasPermissions($userID, "download_hardcopy_format_tex");
	my $perm_change_theme   = $authz->hasPermissions($userID, "download_hardcopy_change_theme");
	my $perm_unopened       = $authz->hasPermissions($userID, "view_unopened_sets");
	my $perm_view_hidden    = $authz->hasPermissions($userID, "view_hidden_sets");
	my $perm_view_answers   = $authz->hasPermissions($userID, "show_correct_answers_before_answer_date");
	my $perm_view_solutions = $authz->hasPermissions($userID, "show_solutions_before_answer_date");

	# get formats
	my @formats;
	foreach my $format (@HC_FORMAT_DISPLAY_ORDER) {
		push @formats, $format if $authz->hasPermissions($userID, "download_hardcopy_format_$format");
	}

	# get format names hash for radio buttons
	my %format_labels = map { $_ => $c->maketext($HC_FORMATS{$_}{name}) || $_ } @formats;

	my $canShowCorrectAnswers = 0;

	my (@users, @wantedSets, @setVersions);
	my ($user,  $user_id,    $selected_set_id);

	if ($perm_multiuser && $perm_multiset) {
		# Get all users for selection.
		@users = $db->getUsersWhere({ user_id => { not_like => 'set_id:%' } });

		# Get sets for selection.
		# Note that we are getting GlobalSets instead of using the list of UserSets assigned to the
		# user.  This is because if we pass UserSets to ScrollingRecordList it will
		# give us composite IDs back, which is a pain in the ass to deal with.
		my @GlobalSets = $db->getGlobalSetsWhere(
			{ $perm_unopened ? () : (open_date => { '<=' => time }), $perm_view_hidden ? () : (visible => 1) });

		# We also want to get the versioned sets for this user.
		# FIXME: This is another place where we assume that there is a one-to-one correspondence between
		# assignment_type =~ gateway and versioned sets.  I think we really should have a "is_versioned" flag on set
		# objects instead.
		for my $v (grep { $_->assignment_type =~ /gateway/ } @GlobalSets) {
			# FIXME: The set_id change here is a hideous, horrible hack.  The identifying key for a global set is the
			# set_id.  Those for a set version are the set_id and version_id.  But this means that we have trouble
			# displaying them both together in HTML::scrollingRecordList.  So we brutally play tricks with the set_id
			# here, which probably is not very robust, and certainly is aesthetically displeasing.  Yuck.
			push(@setVersions,
				map { $_->set_id($_->set_id . ",v" . $_->version_id); $_ }
					$db->getSetVersionsWhere({ user_id => $eUserID, set_id => { like => $v->set_id . ',v%' } }));
		}

		# Filter out global gateway sets.  Only the versioned sets may be printed.
		@wantedSets = grep { $_->assignment_type !~ /gateway/ } @GlobalSets;

		$canShowCorrectAnswers = 1;
	} else {    # single user mode
		$user = $db->getUser($eUserID);

		$selected_set_id = $c->param("selected_sets") // '';

		$user_id = $user->user_id;

		my $mergedSet;
		if ($selected_set_id =~ /(.*),v(\d+)$/) {
			# Determining if answers can be shown is more complicated for gateway tests.
			my $the_set_id      = $1;
			my $the_set_version = $2;
			$mergedSet = $db->getMergedSetVersion($user_id, $the_set_id, $the_set_version);
			my $mergedProblem = $db->getMergedProblemVersion($user_id, $the_set_id, $the_set_version,
				($db->listProblemVersions($user_id, $the_set_id, $the_set_version))[0]);

			# Get the parameters needed to determine if correct answers may be shown.
			my $maxAttempts  = $mergedSet->attempts_per_version()                          || 0;
			my $attemptsUsed = $mergedProblem->num_correct + $mergedProblem->num_incorrect || 0;

			$canShowCorrectAnswers = $perm_view_answers
				|| (
					defined($mergedSet)
					&& defined($mergedProblem)
					&& (
						(
							after($mergedSet->answer_date) || (($attemptsUsed >= $maxAttempts && $maxAttempts != 0)
								|| after($mergedSet->due_date + ($mergedSet->answer_date - $mergedSet->due_date)))
						)
						&& (
							($mergedSet->hide_score eq 'N' && $mergedSet->hide_score_by_problem ne 'Y')
							|| ($mergedSet->hide_score eq 'BeforeAnswerDate'
								&& after($mergedSet->answer_date))
						)
					)
				);

		} else {
			$mergedSet = $db->getMergedSet($user_id, $selected_set_id);

			$canShowCorrectAnswers = $perm_view_answers
				|| (defined($mergedSet) && after($mergedSet->answer_date));
		}
	}

	# Get labels for the hardcopy themes, which are attributes in the theme xml file
	my %hardcopyLabels;
	opendir(my $dhS, $ce->{webworkDirs}{hardcopyThemes}) || die "can't opendir $ce->{webworkDirs}{hardcopyThemes}: $!";
	for my $hardcopyTheme (grep {/\.xml$/} sort readdir($dhS)) {
		my $themeTree = XML::LibXML->load_xml(location => "$ce->{webworkDirs}{hardcopyThemes}/$hardcopyTheme");
		$hardcopyLabels{$hardcopyTheme} = $themeTree->findvalue('/theme/@label');
	}
	my @files;
	if (opendir(my $dhC, $ce->{courseDirs}{hardcopyThemes})) {
		@files = grep { /\.xml$/ && !/^\./ } sort readdir($dhC);
	}
	my @hardcopyThemesCourse;
	for my $hardcopyTheme (@files) {
		eval {
			my $themeTree = XML::LibXML->load_xml(location => "$ce->{courseDirs}{hardcopyThemes}/$hardcopyTheme");
			$hardcopyLabels{$hardcopyTheme} = $themeTree->findvalue('/theme/@label') || $hardcopyTheme;
			push(@hardcopyThemesCourse, $hardcopyTheme);
		};
	}
	my $hardcopyThemesAvailable = [
		sort(do {
			my %seen;
			grep { !$seen{$_}++ } (@{ $ce->{hardcopyThemes} }, @hardcopyThemesCourse);
		})
	];

	return $c->include(
		'ContentGenerator/Hardcopy/form',
		canShowCorrectAnswers   => $canShowCorrectAnswers,
		multiuser               => $perm_multiuser && $perm_multiset,
		can_change_theme        => $perm_change_theme,
		users                   => \@users,
		wantedSets              => \@wantedSets,
		setVersions             => \@setVersions,
		user                    => $user,
		user_id                 => $user_id,
		selected_set_id         => $selected_set_id,
		formats                 => \@formats,
		default_format          => $HC_DEFAULT_FORMAT,
		format_labels           => \%format_labels,
		hardcopyLabels          => \%hardcopyLabels,
		hardcopyThemesAvailable => $hardcopyThemesAvailable,
		can_change_theme        => $perm_change_theme,
	);
}

# Generate a hardcopy for a given user(s) and set(s).
async sub generate_hardcopy ($c, $format, $userIDsRef, $setIDsRef) {
	my $ce    = $c->ce;
	my $db    = $c->db;
	my $authz = $c->authz;

	my $courseID = $c->stash('courseID');
	my $userID   = $c->param('user');

	# Create the temporary directory.
	my $temp_dir_parent_path = Mojo::File->new("$ce->{webworkDirs}{tmp}/$courseID/hardcopy/$userID");
	eval { $temp_dir_parent_path->make_path };
	if ($@) {
		$c->add_error("Couldn't create hardcopy directory $temp_dir_parent_path: ", $c->tag('code', $@));
		return;
	}

	# Create a randomly named working directory in the hardcopy directory.
	my $temp_dir_path = eval { tempdir('work.XXXXXXXX', DIR => $temp_dir_parent_path) };
	if ($@) {
		$c->add_error(q{Couldn't create temporary working directory: }, $c->tag('code', $@));
		return;
	}

	# Do some error checking.
	unless (-e $temp_dir_path) {
		$c->add_error(
			'Temporary directory "',
			$c->tag('code', $temp_dir_path),
			q{" does not exist, but creation didn't fail. This shouldn't happen.}
		);
		return;
	}
	unless (-w $temp_dir_path) {
		$c->add_error('Temporary directory "', $c->tag('code', $temp_dir_path), '" is not writeable.');
		$c->delete_temp_dir($temp_dir_path);
		return;
	}

	my $tex_file_name = 'hardcopy.tex';
	my $tex_file_path = "$temp_dir_path/$tex_file_name";

	# Create TeX file.

	if (open my $FH, '>:encoding(UTF-8)', $tex_file_path) {
		await $c->write_multiuser_tex($FH, $userIDsRef, $setIDsRef);
		close $FH;
	} else {
		$c->add_error('Failed to open file "', $c->tag('code', $tex_file_path), '" for writing: ', $c->tag('code', $!));
		$c->delete_temp_dir($temp_dir_path);
		return;
	}

	# If no problems were successfully rendered, we can't continue.
	unless ($c->{at_least_one_problem_rendered_without_error}) {
		$c->add_error(q{No problems rendered. Can't continue.});
		$c->delete_temp_dir($temp_dir_path);
		return;
	}

	# If the hardcopy.tex file was not generated, fail now.
	unless (-e "$temp_dir_path/hardcopy.tex") {
		$c->add_error(
			'"',
			$c->tag('code', 'hardcopy.tex'),
			'" not written to temporary directory "',
			$c->tag('code', $temp_dir_path),
			q{". Can't continue.}
		);
		$c->delete_temp_dir($temp_dir_path);
		return;
	}

	# End creation of TeX file.

	# Determine base name of final file.
	my $final_file_user     = @$userIDsRef > 1 ? 'multiuser' : $userIDsRef->[0];
	my $final_file_set      = @$setIDsRef > 1  ? 'multiset'  : $setIDsRef->[0];
	my $final_file_basename = "$courseID.$final_file_user.$final_file_set";

	# Call the format subroutine.
	# $final_file_name is the name of final hardcopy file that is generated.
	# @temp_files is a list of temporary files of interest used by the subroutine.
	# (all are relative to $temp_dir_path)
	my $format_subr = $HC_FORMATS{$format}{subr};
	my ($final_file_name, @temp_files) = $c->$format_subr($temp_dir_path, $final_file_basename);
	my $final_file_path = "$temp_dir_path/$final_file_name";

	# Calculate paths for each temp file of interest.  These paths are relative to the $temp_dir_parent_path.
	# makeTempDirectory's interface forces us to reverse-engineer the relative temp dir path from the absolute path.
	my $temp_dir_rel_path = $temp_dir_path =~ s/^$temp_dir_parent_path\///r;
	my %temp_file_map     = map { $_ => "$temp_dir_rel_path/$_" } @temp_files;

	# Make sure the final file exists.
	unless (-e $final_file_path) {
		$c->add_error(
			'Final hardcopy file "',
			$c->tag('code', $final_file_path),
			"' not found after calling '",
			$c->tag('code', $format_subr),
			"': ", $c->tag('code', $!)
		);
		return { temp_file_map => \%temp_file_map };
	}

	# Try to move the hardcopy file out of the temp directory.
	my $final_file_final_path = "$temp_dir_parent_path/$final_file_name";
	eval { Mojo::File->new($final_file_path)->move_to($final_file_final_path) };
	if ($@) {
		$c->add_error(
			'Failed to move hardcopy file "',
			$c->tag('code', $final_file_name),
			'" from "', $c->tag('code', $temp_dir_path),
			'" to "',   $c->tag('code', $temp_dir_parent_path),
			'":',       $c->tag('br'), $c->tag('pre', $@)
		);
		$final_file_final_path = "$temp_dir_rel_path/$final_file_name";
	}

	# If there were any errors, then the final file will not be served directly, but will be served via reply_with_file
	# and the full file path will be built at that time.  So the path needs to be relative to the temporary directory
	# parent path.
	$final_file_final_path =~ s/^$temp_dir_parent_path\/// if ($c->has_errors);

	# remove the temp directory if there are no errors
	$c->delete_temp_dir($temp_dir_path) unless ($c->has_errors || $PreserveTempFiles);

	warn "Preserved temporary files in directory '$temp_dir_path'.\n" if $PreserveTempFiles;

	return {
		file_name     => $final_file_name,
		file_path     => $final_file_final_path,
		file_type     => $HC_FORMATS{$format}{file_type} // 'application/pdf',
		temp_file_map => \%temp_file_map
	};
}

# helper function to remove temp dirs
sub delete_temp_dir ($c, $temp_dir_path) {
	eval { Mojo::File->new($temp_dir_path)->remove_tree };
	if ($@) {
		$c->add_error('Failed to remove temporary directory "',
			$c->tag('code', $temp_dir_path, '":', $c->tag('br'), $c->tag('pre', $@)));
	}
	return;
}

# Hardcopy generation subroutines
#
# These subroutines assume that the TeX source file is located at $temp_dir_path/hardcopy.tex The
# subroutines return a list whose first entry is the generated file name in $temp_dir_path, and
# whose remaining elements are names of temporary files that may be of interest in the case of an
# error (also located in $temp_dir_path).  These are returned whether or not an error actually
# occurred.

sub generate_hardcopy_tex ($c, $temp_dir_path, $final_file_basename) {
	my $src_name    = "hardcopy.tex";
	my $bundle_path = Mojo::File->new("$temp_dir_path/$final_file_basename");

	# Create directory for the tex bundle
	eval { $bundle_path->make_path };
	if ($@) {
		$c->add_error(
			'Failed to create directory "',
			$c->tag('code', $bundle_path),
			'": ', $c->tag('br'), $c->tag('pre', $@)
		);
		return $src_name;
	}

	# Move the tex file into the bundle directory
	eval { Mojo::File->new("$temp_dir_path/$src_name")->move_to($bundle_path) };
	if ($@) {
		$c->add_error(
			'Failed to move "',
			$c->tag('code', $src_name),
			'" into directory "',
			$c->tag('code', $bundle_path),
			'":', $c->tag('br'), $c->tag('pre', $@)
		);
		return $src_name;
	}

	# Copy the common tex files into the bundle directory
	my $ce = $c->ce;
	for (qw{webwork2.sty webwork_logo.png}) {
		eval { Mojo::File->new("$ce->{webworkDirs}{assetsTex}/$_")->copy_to($bundle_path) };
		if ($@) {
			$c->add_error(
				'Failed to copy "',
				$c->tag('code', "$ce->{webworkDirs}{assetsTex}/$_"),
				'" into directory "',
				$c->tag('code', $bundle_path),
				'":', $c->tag('br'), $c->tag('pre', $@)
			);
		}
	}
	for (qw{pg.sty PGML.tex CAPA.tex}) {
		eval { Mojo::File->new("$ce->{pg}{directories}{assetsTex}/$_")->copy_to($bundle_path) };
		if ($@) {
			$c->add_error(
				'Failed to copy "',
				$c->tag('code', "$ce->{pg}{directories}{assetsTex}/$_"),
				'" into directory "',
				$c->tag('code', $bundle_path),
				'":', $c->tag('br'), $c->tag('pre', $@)
			);
		}
	}

	# Attempt to copy image files used into the working directory.
	my $resource_list = $c->{resource_list};
	if (ref $resource_list eq 'ARRAY' && @$resource_list) {
		if (open(my $in_fh, "<", "$bundle_path/$src_name")) {
			local $/;
			my $data = <$in_fh>;
			close($in_fh);

			for my $resource (@$resource_list) {
				my $basename = $resource =~ s/.*\///r;
				$data =~ s{$resource}{$basename}g;

				# Copy the image file into the bundle directory.
				eval { Mojo::File->new($resource)->copy_to($bundle_path) };

				if ($@) {
					$c->add_error(
						'Failed to copy image "',
						$c->tag('code', $resource),
						'" into directory "',
						$c->tag('code', $bundle_path),
						'":', $c->tag('br'), $c->tag('pre', $@)
					);
				}
			}

			# Rewrite the tex file with the image paths stripped.
			open(my $out_fh, ">", "$bundle_path/$src_name") or warn "Can't open $bundle_path/$src_name for writing.";
			print $out_fh $data;
			close $out_fh;
		} else {
			$c->add_error('Failed to open "', $c->tag('code', "$bundle_path/$src_name"), '" for reading.');
		}
	}

	# Create a zip archive of the bundle directory
	my $zip_file_name = "$final_file_basename.zip";
	my $zip           = Archive::Zip::SimpleZip->new("$temp_dir_path/$zip_file_name");
	unless ($zip) {
		$c->add_error(
			'Failed to create zip archive of directory "',
			$c->tag('code', $bundle_path),
			'": $SimpleZipError"'
		);
		return;
	}

	Mojo::File->new("$temp_dir_path/$final_file_basename")->list->each(sub {
		$zip->add($_, Name => "$final_file_basename/" . $_->basename);
	});
	my $ok = $zip->close();

	unless ($ok) {
		$c->add_error(
			'Failed to create zip archive of directory "',
			$c->tag('code', $bundle_path),
			'": $SimpleZipError"'
		);
		return;
	}
	return $zip_file_name;
}

sub find_log_first_error ($log) {
	my ($line, $first_error);
	while ($line = <$log>) {
		if ($first_error) {
			last if $line =~ /^!\s+/;
			$first_error .= $line;
		} elsif ($line =~ /^!\s+/) {
			$first_error = $line;
		}
	}

	return $first_error;
}

sub generate_hardcopy_pdf ($c, $temp_dir_path, $final_file_basename) {
	# call pdflatex - we don't want to chdir in the mod_perl process, as
	# that might step on the feet of other things (esp. in Apache 2.0)
	my $pdflatex_cmd = "cd "
		. shell_quote($temp_dir_path) . " && "
		. "TEXINPUTS=.:"
		. shell_quote($c->ce->{webworkDirs}{assetsTex}) . ':'
		. shell_quote($c->ce->{pg}{directories}{assetsTex}) . ': '
		. $c->ce->{externalPrograms}{pdflatex}
		. " >pdflatex.stdout 2>pdflatex.stderr hardcopy";
	if (my $rawexit = system $pdflatex_cmd) {
		my $exit   = $rawexit >> 8;
		my $signal = $rawexit & 127;
		my $core   = $rawexit & 128;
		$c->add_error(
			'Failed to convert TeX to PDF with command "',
			$c->tag('code', $pdflatex_cmd),
			qq{" (exit=$exit signal=$signal core=$core).}
		);

		# read hardcopy.log and report first error
		my $hardcopy_log = "$temp_dir_path/hardcopy.log";
		if (-e $hardcopy_log) {
			if (open my $LOG, "<:encoding(UTF-8)", $hardcopy_log) {
				my $first_error = find_log_first_error($LOG);
				close $LOG;
				if (defined $first_error) {
					$c->add_error('First error in TeX log is:', $c->tag('br'), $c->tag('pre', $first_error));
				} else {
					$c->add_error('No errors encoundered in TeX log.');
				}
			} else {
				$c->add_error('Could not read TeX log: ', $c->tag('code', $!));
			}
		} else {
			$c->add_error('No TeX log was found.');
		}
	}

	my $final_file_name;

	# try rename the pdf file
	my $src_name  = "hardcopy.pdf";
	my $dest_name = "$final_file_basename.pdf";

	eval { Mojo::File->new("$temp_dir_path/$src_name")->move_to("$temp_dir_path/$dest_name") };
	if ($@) {
		$c->add_error(
			'Failed to rename "',
			$c->tag('code', $src_name),
			'" to "',
			$c->tag('code', $dest_name),
			'" in directory "',
			$c->tag('code', $temp_dir_path),
			'":',
			$c->tag('br'),
			$c->tag('pre', $@)
		);
		$final_file_name = $src_name;
	} else {
		$final_file_name = $dest_name;
	}

	return $final_file_name, qw/hardcopy.tex hardcopy.log hardcopy.aux pdflatex.stdout pdflatex.stderr/;
}

################################################################################
# TeX aggregating subroutines
################################################################################

async sub write_multiuser_tex ($c, $FH, $userIDsRef, $setIDsRef) {
	my $ce = $c->ce;

	my @userIDs = @$userIDsRef;
	my @setIDs  = @$setIDsRef;

	# get theme
	my $theme = $c->param('hardcopy_theme') // $ce->{hardcopyTheme};
	my $themeFile;
	if (-e "$ce->{courseDirs}{hardcopyThemes}/$theme") {
		$themeFile = "$ce->{courseDirs}{hardcopyThemes}/$theme";
	} elsif (-e "$ce->{webworkDirs}{hardcopyThemes}/$theme") {
		$themeFile = "$ce->{webworkDirs}{hardcopyThemes}/$theme";
	} else {
		$c->add_error("Couldn't locate file for theme $theme.");
		return;
	}
	my $themeTree = XML::LibXML->load_xml(location => $themeFile);

	# write preamble
	print $FH "\\batchmode\n";
	print $FH $themeTree->findvalue('/theme/preamble');
	print $FH '\\def\\webworkCourseName{' . handle_underbar($ce->{courseName}) . "}%\n";
	print $FH '\\def\\webworkCourseTitle{' . handle_underbar($c->db->getSettingValue('courseTitle')) . "}%\n";
	print $FH '\\def\\webworkCourseURL{'
		. handle_underbar($ce->{server_root_url} . $ce->{webwork_url} . '/' . $ce->{courseName}) . "}%\n";

	# write section for each user
	while (defined(my $userID = shift @userIDs)) {
		await $c->write_multiset_tex($FH, $userID, $themeTree, @setIDs);
		print $FH $themeTree->findvalue('/theme/userdivider') if @userIDs;   # divide users, but not after the last user
	}

	# write postamble
	print $FH $themeTree->findvalue('/theme/postamble');

	return;
}

async sub write_multiset_tex ($c, $FH, $targetUserID, $themeTree, @setIDs) {
	my $ce = $c->ce;
	my $db = $c->db;

	# get user record
	my $TargetUser = $db->getUser($targetUserID);
	unless ($TargetUser) {
		$c->add_error(
			q{Can't generate hardcopy for user "},
			$c->tag('code', $targetUserID),
			qq{" -- no such user exists.\n}
		);
		return;
	}

	# write each set
	while (defined(my $setID = shift @setIDs)) {
		await $c->write_set_tex($FH, $TargetUser, $themeTree, $setID);
		print $FH $themeTree->findvalue('/theme/setdivider') if @setIDs;    # divide sets, but not after the last set
	}

	return;
}

async sub write_set_tex ($c, $FH, $TargetUser, $themeTree, $setID) {
	my $ce     = $c->ce;
	my $db     = $c->db;
	my $authz  = $c->authz;
	my $userID = $c->param("user");

	# we may already have the MergedSet from checking hide_work and
	#    hide_score in pre_header_initialize; check to see if that's true,
	#    and otherwise, get the set.
	my %mergedSets = %{ $c->{mergedSets} };
	my $uid        = $TargetUser->user_id;
	my $MergedSet;
	my $versioned = 0;
	if (defined($mergedSets{"$uid!$setID"})) {
		$MergedSet = $mergedSets{"$uid!$setID"};
		$versioned = ($setID =~ /,v(\d+)$/) ? $1 : 0;
	} else {
		if ($setID =~ /(.+),v(\d+)$/) {
			$setID     = $1;
			$versioned = $2;
		}
		if ($versioned) {
			$MergedSet = $db->getMergedSetVersion($TargetUser->user_id, $setID, $versioned);
		} else {
			$MergedSet = $db->getMergedSet($TargetUser->user_id, $setID);    # checked
		}
	}
	# save versioned info for use in write_problem_tex
	$c->{versioned} = $versioned;

	unless ($MergedSet) {
		$c->add_error(
			q{Can't generate hardcopy for set "},
			$c->tag('code', $setID),
			'" for user "',
			$c->tag('code', $TargetUser->user_id),
			'" -- set is not assigned to that user.'
		);
		return;
	}

	# see if the *real* user is allowed to access this problem set
	if ($MergedSet->open_date > time && !$authz->hasPermissions($userID, "view_unopened_sets")) {
		$c->add_error(
			q{Can't generate hardcopy for set "},
			$c->tag('code', $setID),
			'" for user "',
			$c->tag('code', $TargetUser->user_id),
			'" -- set is not yet open.'
		);
		return;
	}
	if (!$MergedSet->visible && !$authz->hasPermissions($userID, "view_hidden_sets")) {
		$c->addbadmessage($c->maketext(
			q{Can't generate hardcopy for set "[_1]" for user "[_2]". The set is not visible to students.},
			$setID, $TargetUser->user_id,
		));
		return;
	}

	# get PG header
	my $header =
		$MergedSet->hardcopy_header ? $MergedSet->hardcopy_header : $ce->{webworkFiles}{hardcopySnippets}{setHeader};
	if ($header eq 'defaultHeader') { $header = $ce->{webworkFiles}{hardcopySnippets}{setHeader}; }

	# get list of problem IDs
	my @problemIDs = map { $_->[2] }
		$db->listUserProblemsWhere({ user_id => $MergedSet->user_id, set_id => $MergedSet->set_id }, 'problem_id');

	# for versioned sets (gateways), we might have problems in a random
	# order; reset the order of the problemIDs if this is the case
	if (defined($MergedSet->problem_randorder)
		&& $MergedSet->problem_randorder)
	{
		my @newOrder = ();

		# to set the same order each time we set the random seed to the psvn,
		# and to avoid messing with the system random number generator we use
		# our own PGrandom object
		my $pgrand = PGrandom->new();
		$pgrand->srand($MergedSet->psvn);
		while (@problemIDs) {
			my $i = int($pgrand->rand(scalar(@problemIDs)));
			push(@newOrder, $problemIDs[$i]);
			splice(@problemIDs, $i, 1);
		}
		@problemIDs = @newOrder;
	}

	# write environment variables as LaTeX macros
	for (qw(user_id student_id first_name last_name email_address section recitation)) {
		print $FH '\\def\\webwork' . underscore_to_camel($_) . '{' . handle_underbar($TargetUser->{$_}) . "}%\n"
			if $TargetUser->{$_};
	}
	for (qw(set_id description)) {
		print $FH '\\def\\webwork' . underscore_to_camel($_) . '{' . handle_underbar($MergedSet->{$_}) . "}%\n"
			if $MergedSet->{$_};
	}
	print $FH '\\def\\webworkPrettySetId{' . handle_underbar($MergedSet->{set_id}, 1) . "}%\n";
	for (qw(open_date due_date answer_date)) {
		if ($MergedSet->{$_}) {
			print $FH '\\def\\webwork'
				. underscore_to_camel($_) . '{'
				. $c->formatDateTime($MergedSet->{$_}, $ce->{studentDateDisplayFormat}) . "}%\n";
		}
	}
	# Leave reduced scoring date blank if it is disabled, or enabled but on (or somehow later) than the close date
	if ($MergedSet->{reduced_scoring_date}
		&& $ce->{pg}{ansEvalDefaults}{enableReducedScoring}
		&& $MergedSet->{enable_reduced_scoring}
		&& $MergedSet->{reduced_scoring_date} < $MergedSet->{due_date})
	{
		print $FH '\\def\\webworkReducedScoringDate{'
			. $c->formatDateTime($MergedSet->{reduced_scoring_date}, $ce->{studentDateDisplayFormat}) . "}%\n";
	}

	# write set header (theme presetheader, then PG header, then theme postsetheader)
	print $FH $themeTree->findvalue('/theme/presetheader');
	await $c->write_problem_tex($FH, $TargetUser, $MergedSet, $themeTree, 0, $header); # 0 => pg file specified directly
	print $FH $themeTree->findvalue('/theme/postsetheader');

	# write each problem
	# for versioned problem sets (gateway tests) we like to include
	#   problem numbers
	my $i = 1;
	while (my $problemID = shift @problemIDs) {
		$c->{versioned} = $i                                     if $versioned;
		print $FH $themeTree->findvalue('/theme/problemdivider') if $i > 1;
		await $c->write_problem_tex($FH, $TargetUser, $MergedSet, $themeTree, $problemID);
		$i++;
	}

	# attempt to claim copyright
	print $FH '\\webworkSetCopyrightFooter';

	# write footer
	print $FH $themeTree->findvalue('/theme/setfooter');

	return;
}

sub underscore_to_camel {
	my $key = shift;
	$key = ucfirst($key);
	$key =~ s/_(\w)/uc($1)/ge;
	return $key;
}

sub handle_underbar {
	my $string     = shift;
	my $make_space = shift // 0;
	if ($make_space) {
		$string =~ s/_/~/g;
	} else {
		$string =~ s/_/\\_/g;
	}
	return $string;
}

async sub write_problem_tex ($c, $FH, $TargetUser, $MergedSet, $themeTree, $problemID = 0, $pgFile = undef) {
	my $ce           = $c->ce;
	my $db           = $c->db;
	my $authz        = $c->authz;
	my $userID       = $c->param("user");
	my $eUserID      = $c->param("effectiveUser");
	my $versioned    = $c->{versioned};
	my %canShowScore = %{ $c->{canShowScore} };

	my @errors;

	# get problem record
	my $MergedProblem;
	if ($problemID) {
		# a non-zero problem ID was given -- load that problem
		# we use $versioned to determine which merging routine to use
		if ($versioned) {
			$MergedProblem =
				$db->getMergedProblemVersion($MergedSet->user_id, $MergedSet->set_id, $MergedSet->version_id,
					$problemID);
		} else {
			$MergedProblem = $db->getMergedProblem($MergedSet->user_id, $MergedSet->set_id, $problemID);    # checked
		}

		# handle nonexistent problem
		unless ($MergedProblem) {
			$c->add_error(
				q{Can't generate hardcopy for problem "},
				$c->tag('code', $problemID),
				'" in set "',
				$c->tag('code', $MergedSet->set_id),
				'" for user "',
				$c->tag('code', $MergedSet->user_id),
				'" -- problem does not exist in that set or is not assigned to that user.'
			);
			return;
		}
	} elsif ($pgFile) {
		# otherwise, we try an explicit PG file
		$MergedProblem = $db->newUserProblem(
			user_id       => $MergedSet->user_id,
			set_id        => $MergedSet->set_id,
			problem_id    => 0,
			source_file   => $pgFile,
			num_correct   => 0,
			num_incorrect => 0,
		);
		die "newUserProblem failed -- WTF?" unless $MergedProblem;    # this should never happen
	} else {
		# this shouldn't happen -- error out for real
		die "write_problem_tex needs either a non-zero \$problemID or a \$pgFile";
	}

	# figure out if we're allowed to get correct answers, hints, and solutions
	# (eventually, we'd like to be able to use the same code as Problem)
	my $versionName = $MergedSet->set_id . (($versioned) ? ",v" . $MergedSet->version_id : '');

	my $showCorrectAnswers  = $c->param("showCorrectAnswers")  || 0;
	my $printStudentAnswers = $c->param("printStudentAnswers") || 0;
	my $showHints           = $c->param("showHints")           || 0;
	my $showSolutions       = $c->param("showSolutions")       || 0;
	my $showComments        = $c->param("showComments")        || 0;

	unless (
		(
			$authz->hasPermissions($userID, "show_correct_answers_before_answer_date")
			|| (
				time > $MergedSet->answer_date
				|| ($versioned
					&& $MergedProblem->num_correct + $MergedProblem->num_incorrect >=
					$MergedSet->attempts_per_version
					&& $MergedSet->due_date == $MergedSet->answer_date)
			)
		)
		&& ($canShowScore{ $MergedSet->user_id . "!$versionName" })
		)
	{
		$showCorrectAnswers = 0;
		$showSolutions      = 0;
	}

	# FIXME -- there can be a problem if the $siteDefaults{timezone} is not defined?  Why is this?
	# why does it only occur with hardcopy?

	# Include old answers if answers were requested.
	my $oldAnswers = {};
	if ($printStudentAnswers) {
		%{$oldAnswers} = decodeAnswers($MergedProblem->last_answer);
	}

	my $pg = await renderPG(
		$c,
		$TargetUser,
		$MergedSet,
		$MergedProblem,
		$MergedSet->psvn,
		$oldAnswers,
		{    # translation options
			displayMode              => 'tex',
			showHints                => $showHints,
			showSolutions            => $showSolutions,
			processAnswers           => $showCorrectAnswers || $printStudentAnswers,
			permissionLevel          => $db->getPermissionLevel($userID)->permission,
			effectivePermissionLevel => $db->getPermissionLevel($eUserID)->permission,
			isInstructor             => $authz->hasPermissions($userID, 'view_answers'),
			# Add the quiz prefix for versioned sets
			$versioned && $MergedProblem->problem_id != 0
			? (QUIZ_PREFIX => 'Q' . sprintf('%04d', $MergedProblem->problem_id()) . '_')
			: ()
		}
	);

	push(@{ $c->{resource_list} }, map { $pg->{resource_list}{$_} } keys %{ $pg->{resource_list} })
		if ref $pg->{resource_list} eq 'HASH';

	# only bother to generate this info if there were warnings or errors
	my $edit_url;
	my $problem_name;
	my $problem_desc;
	if ($pg->{warnings} ne '' || $pg->{flags}->{error_flag}) {
		$edit_url = $c->systemLink(
			$c->url_for(
				'instructor_problem_editor_withset_withproblem',
				setID     => $MergedProblem->set_id,
				problemID => $MergedProblem->problem_id,
			),
			$MergedProblem->problem_id == 0
				# link for a fake problem (like a header file)
			? (params =>
					{ sourceFilePath => $MergedProblem->source_file, problemSeed => $MergedProblem->problem_seed })
				# link for a real problem
			: (),
		);

		if ($MergedProblem->problem_id == 0) {
			$problem_name = "snippet";
			$problem_desc =
				$problem_name . " '"
				. $MergedProblem->source_file
				. "' for set '"
				. $MergedProblem->set_id
				. "' and user '"
				. $MergedProblem->user_id . "'";
		} else {
			$problem_name = "problem";
			$problem_desc =
				$problem_name . " '"
				. $MergedProblem->problem_id
				. "' in set '"
				. $MergedProblem->set_id
				. "' for user '"
				. $MergedProblem->user_id . "'";
		}
	}

	# deal with PG warnings
	if ($pg->{warnings}) {
		$c->add_error(
			$c->link_to(
				$c->tag('button', type => 'button', class => 'btn btn-sm btn-secondary', $c->maketext('Edit')) =>
					$edit_url,
				target => 'WW_Editor'
			),
			' ',
			$c->b($c->maketext(
				"Warnings encountered while processing [_1]. Error text: [_2]",
				$problem_desc,
				$c->tag('br') . $c->tag('pre', $pg->{warnings})
			))
		);
	}

	# deal with PG errors
	if ($pg->{flags}{error_flag}) {
		$c->add_error(
			$c->link_to(
				$c->tag('button', type => 'button', class => 'btn btn-sm btn-secondary', $c->maketext('Edit')) =>
					$edit_url,
				target => 'WW_Editor'
			),
			' ',
			$c->b($c->maketext(
				'Errors encountered while processing [_1]. This [_2] has been omitted from the hardcopy. '
					. 'Error text: [_3]',
				$problem_desc, $problem_name, $c->tag('br') . $c->tag('pre', $pg->{errors})
			))
		);
		return;
	}

	# if we got here, there were no errors (because errors cause a return above)
	$c->{at_least_one_problem_rendered_without_error} = 1;

	my $body_text = $pg->{body_text};

	if ($problemID) {
		my $id = $MergedProblem->problem_id;
		if (defined($MergedSet) && $MergedSet->assignment_type eq 'jitar') {
			# Use the pretty problem number if its a jitar problem
			$id = join('.', jitar_id_to_seq($id));
		} elsif ($id != 0 && $versioned) {
			$id = $versioned;    # this cannot be right?
		}

		print $FH "\\def\\webworkProblemId{$id}%\n";
		print $FH "\\def\\webworkProblemNumber{" . ($versioned ? $versioned : $id) . "}%\n";

		my $problemValue = $MergedProblem->value;
		print $FH "\\def\\webworkProblemWeight{$problemValue}%\n" if defined($problemValue);

		print $FH $themeTree->findvalue('/theme/problemheader');

		if ($c->{can_show_source_file} && $c->param("show_source_file") eq "Yes") {
			print $FH "{\\footnotesize\\path|" . $MergedProblem->source_file . "|}\n";
		}
		print $FH "\\smallskip\n\n";
	}

	# Include old answers if answers were requested.
	if ($printStudentAnswers) {
		print $FH "%% decoded old answers, saved. (keys = " . join(',', keys(%{$oldAnswers})) . ")\n" if %{$oldAnswers};
	}

	print $FH $body_text;

	my @ans_entry_order = defined($pg->{flags}->{ANSWER_ENTRY_ORDER}) ? @{ $pg->{flags}->{ANSWER_ENTRY_ORDER} } : ();

	# print the list of student answers if it is requested
	if ($printStudentAnswers
		&& $MergedProblem->problem_id != 0
		&& @ans_entry_order)
	{
		my $pgScore = $pg->{state}->{recorded_score};
		my $corrMsg = ' submitted: ';
		if ($pgScore == 1) {
			$corrMsg .= $c->maketext('(correct)');
		} elsif ($pgScore == 0) {
			$corrMsg .= $c->maketext('(incorrect)');
		} else {
			$corrMsg .= $c->maketext('(score [_1])', $pgScore);
		}

		$corrMsg .= "\n \\\\ \n recorded: ";
		my $recScore = $MergedProblem->status;
		if ($recScore == 1) {
			$corrMsg .= $c->maketext('(correct)');
		} elsif ($recScore == 0) {
			$corrMsg .= $c->maketext('(incorrect)');
		} else {
			$corrMsg .= $c->maketext('(score [_1])', $recScore);
		}

		my $stuAnswers =
			"\\par{\\small{\\it "
			. $c->maketext("Answer(s) submitted:") . "}\n"
			. "\\vspace{-\\parskip}\\begin{itemize}\n";
		for my $ansName (@ans_entry_order) {
			my $stuAns;
			if (defined $pg->{answers}{$ansName}{preview_latex_string}
				&& $pg->{answers}{$ansName}{preview_latex_string} ne '')
			{
				$stuAns = $pg->{answers}{$ansName}{preview_latex_string};
			} elsif (defined $pg->{answers}{$ansName}{original_student_ans}
				&& $pg->{answers}{$ansName}{original_student_ans} ne '')
			{
				$stuAns = "\\text{" . $pg->{answers}{$ansName}{original_student_ans} . "}";
			} else {
				$stuAns = "\\text{no response}";
			}
			$stuAnswers .= "\\item\n\$\\displaystyle $stuAns\$\n";
		}
		$stuAnswers .= "\\end{itemize}}$corrMsg\\par\n";
		print $FH $stuAnswers;
	}

	if ($showComments) {
		my $userPastAnswerID =
			$db->latestProblemPastAnswer($MergedProblem->user_id, $versionName, $MergedProblem->problem_id);

		my $pastAnswer = $userPastAnswerID                          ? $db->getPastAnswer($userPastAnswerID) : 0;
		my $comment    = $pastAnswer && $pastAnswer->comment_string ? $pastAnswer->comment_string           : "";

		my $commentMsg =
			"\\par{\\small{\\it "
			. $c->maketext("Instructor Feedback:") . "}\n"
			. "\\vspace{-\\parskip}\n"
			. "\\begin{lstlisting}\n$comment\\end{lstlisting}\n"
			. "\\par\n";
		print $FH $commentMsg if $comment;
	}

	# write the list of correct answers if appropriate; ANSWER_ENTRY_ORDER
	#   isn't defined for versioned sets?  this seems odd FIXME  GWCHANGE
	if ($showCorrectAnswers && $MergedProblem->problem_id != 0 && @ans_entry_order) {
		my $correctTeX =
			"\\par{\\small{\\it " . $c->maketext("Correct Answers:") . "}\n" . "\\vspace{-\\parskip}\\begin{itemize}\n";

		foreach my $ansName (@ans_entry_order) {
			my $correctAnswer = $pg->{answers}{$ansName}{correct_ans_latex_string}
				|| "\\text{" . $pg->{answers}{$ansName}{correct_ans} . "}";
			$correctTeX .= "\\item\n\$\\displaystyle $correctAnswer\$\n";
		}

		$correctTeX .= "\\end{itemize}}\\par\n";

		print $FH $correctTeX;
	}

	if ($problemID) {
		print $FH $themeTree->findvalue('/theme/problemfooter');
	}

	return;
}

################################################################################
# utilities
################################################################################

sub add_error ($c, @error_parts) {
	push @{ $c->{hardcopy_errors} }, $c->c(@error_parts)->join('');
}

sub has_errors ($c) {
	return scalar @{ $c->{hardcopy_errors} // [] };
}

sub get_errors ($c) {
	return $c->{hardcopy_errors};
}

1;
