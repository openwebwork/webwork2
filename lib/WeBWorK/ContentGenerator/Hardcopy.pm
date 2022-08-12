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

package WeBWorK::ContentGenerator::Hardcopy;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Hardcopy - generate printable versions of one or more
problem sets.

=cut

use strict;
use warnings;

#use Apache::Constants qw/:common REDIRECT/;
#use CGI qw(-nosticky );
use WeBWorK::CGI;

use File::Path;
use File::Temp qw/tempdir/;
use String::ShellQuote;
use Archive::Zip qw(:ERROR_CODES);
use WeBWorK::DB::Utils qw/user2global/;
use WeBWorK::Debug;
use WeBWorK::Form;
use WeBWorK::HTML::ScrollingRecordList qw/scrollingRecordList/;
use WeBWorK::PG;
use WeBWorK::Utils qw/readFile decodeAnswers jitar_id_to_seq is_restricted after x format_set_name_display/;
use PGrandom;

=head1 CONFIGURATION VARIABLES

=over

=item $PreserveTempFiles

If true, don't delete temporary files.

=cut

our $PreserveTempFiles = 0 unless defined $PreserveTempFiles;

=back

=cut

our $HC_DEFAULT_FORMAT = "pdf"; # problems if this is not an allowed format for the user...
our %HC_FORMATS = (
	tex => { name => x("TeX Source"), subr => "generate_hardcopy_tex", file_type => 'application/zip' },
	pdf => { name => x("Adobe PDF"),  subr => "generate_hardcopy_pdf", file_type => 'application/pdf' },
);
our @HC_FORMAT_DISPLAY_ORDER = ('tex', 'pdf');

# custom fields used in $self hash
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
#   reference to array containing HTML strings describing generation errors (and warnings)
#   used by add_errors(), get_errors(), get_errors_ref()
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

sub pre_header_initialize {
	my $self  = shift;
	my $r     = $self->r;
	my $ce    = $r->ce;
	my $db    = $r->db;
	my $authz = $r->authz;

	my $userID            = $r->param('user');
	my $eUserID           = $r->param('effectiveUser');
	my @setIDs            = $r->param('selected_sets');
	my @userIDs           = $r->param('selected_users');
	my $hardcopy_format   = $r->param('hardcopy_format');
	my $generate_hardcopy = $r->param('generate_hardcopy');

	# This should never happen, but apparently it did once (see bug #714), so we check for it.
	die 'Parameter "user" not defined -- this should never happen' unless defined $userID;

	# Check to see if the user is authorized to view source file paths.
	$self->{can_show_source_file} =
		($db->getPermissionLevel($userID)->permission >=
			$ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_PERMISSION_LEVEL})
		|| grep($_ eq $userID, @{ $ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} });

	if ($generate_hardcopy) {
		my $validation_failed = 0;

		# Set the default format.
		$hardcopy_format = $HC_DEFAULT_FORMAT unless defined $hardcopy_format;

		# Make sure the format is valid.
		unless (grep { $_ eq $hardcopy_format } keys %HC_FORMATS) {
			$self->addbadmessage("'$hardcopy_format' is not a valid hardcopy format.");
			$validation_failed = 1;
		}

		# Make sure we are allowed to generate hardcopy in this format.
		unless ($authz->hasPermissions($userID, "download_hardcopy_format_$hardcopy_format")) {
			$self->addbadmessage(
				$r->maketext('You do not have permission to generate hardcopy in [_1] format.', $hardcopy_format));
			$validation_failed = 1;
		}

		# Make sure we are allowed to use this hardcopy theme.
		unless ($authz->hasPermissions($userID, 'download_hardcopy_change_theme')
			|| !defined($r->param('hardcopy_theme')))
		{
			$self->addbadmessage($r->maketext('You do not have permission to change the hardcopy theme.'));
			$validation_failed = 1;
		}

		# Is there at least one user selected?
		unless (@userIDs) {
			$self->addbadmessage($r->maketext('Please select at least one user and try again.'));
			$validation_failed = 1;
		}

		# Is there at least one set selected?
		# When students don't select any sets the size of @setIDs is 1 with a null character in $setIDs[0].
		# When professors don't select any sets the size of @setIDs is 0.
		# The following test catches both cases and prevents warning messages in the case of a professor's empty array.
		unless (@setIDs && $setIDs[0] =~ /\S+/) {
			$self->addbadmessage($r->maketext('Please select at least one set and try again.'));
			$validation_failed = 1;
		}

		# Is the user allowed to request multiple sets/users at a time?
		my $perm_multiset  = $authz->hasPermissions($userID, 'download_hardcopy_multiset');
		my $perm_multiuser = $authz->hasPermissions($userID, 'download_hardcopy_multiuser');

		my $perm_viewhidden = $authz->hasPermissions($userID, 'view_hidden_work');
		my $perm_viewfromip = $authz->hasPermissions($userID, 'view_ip_restricted_sets');

		my $perm_viewunopened = $authz->hasPermissions($userID, 'view_unopened_sets');

		if (@setIDs > 1 and not $perm_multiset) {
			$self->addbadmessage('You are not permitted to generate hardcopy for multiple sets. '
					. 'Please select a single set and try again.');
			$validation_failed = 1;
		}
		if (@userIDs > 1 and not $perm_multiuser) {
			$self->addbadmessage('You are not permitted to generate hardcopy for multiple users. '
					. 'Please select a single user and try again.');
			$validation_failed = 1;
		}
		if (@userIDs and $userIDs[0] ne $eUserID and not $perm_multiuser) {
			$self->addbadmessage('You are not permitted to generate hardcopy for other users.');
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
							$self->addbadmessage(
								$r->maketext('You are not permitted to generate a hardcopy for an unopened set.'));
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
							$self->addbadmessage(
								$r->maketext(
									'You are not permitted to generate a hardcopy for a set with hidden work.')
							);
							last;
						}

						if ($authz->invalidIPAddress($userSet)) {
							$validation_failed = 1;
							$self->addbadmessage($r->maketext(
								'You are not allowed to generate a hardcopy for [_1] from your IP address, [_2].',
								$userSet->set_id, $r->connection->remote_ip
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
			$self->{canShowScore} = \%canShowScore;
			$self->{mergedSets}   = \%mergedSets;
			my $result = $self->generate_hardcopy($hardcopy_format, \@userIDs, \@setIDs);
			if ($self->get_errors) {
				# Store the result data in self hash so that body() can make a link to it.
				$self->{file_path}     = $result->{file_path};
				$self->{temp_file_map} = $result->{temp_file_map};
			} else {
				# Send the file only (it is deleted from the server after it is sent).
				$self->reply_with_file($result->{file_type}, $result->{file_path}, $result->{file_name}, 1);
			}
		}

		return;
	}

	my $tempFile = $r->param('tempFilePath');
	if ($tempFile) {
		my $courseID = $r->urlpath->arg('courseID');
		my $baseName = $tempFile =~ s/.*\/([^\/]*)$/$1/r;
		my $fullFilePath = "$ce->{webworkDirs}{tmp}/$courseID/hardcopy/$userID/$tempFile";

		unless (-e $fullFilePath) {
			$self->addbadmessage($r->maketext('The requested file "[_1]" does not exist on the server.', $tempFile));
			return;
		}

		unless ($baseName =~ /\.$userID\./ || $authz->hasPermissions($userID, 'download_hardcopy_multiuser')) {
			$self->addbadmessage($r->maketext('You do not have permission to access the requested file "[_1]".'),
				$tempFile);
			return;
		}

		# All of the files that could be served here are text files except for the pdf or zip file
		# (and the zip file won't actually be served in this way either technically -- but just in case).
		my $type = 'text/plain';
		$type = 'application/pdf' if $baseName =~ m/\.pdf/;
		$type = 'application/zip' if $baseName =~ m/\.zip/;

		$self->reply_with_file($type, $fullFilePath, $baseName);
	}

	return;
}

sub body {
	my ($self)           = @_;
	my $r                = $self->r;
	my $userID           = $self->r->param('user');
	my $perm_view_errors = $self->r->authz->hasPermissions($userID, 'download_hardcopy_view_errors');
	$perm_view_errors = defined $perm_view_errors ? $perm_view_errors : 0;

	if (my $num = $self->get_errors) {
		my $file_path = $self->{file_path};
		my %temp_file_map  = %{ $self->{temp_file_map} // {} };
		if ($perm_view_errors) {
			print CGI::p($r->maketext('[quant,_1,error] occured while generating hardcopy:', $num));

			print CGI::ul(CGI::li($self->get_errors_ref));
		}

		if ($file_path) {
			print CGI::p(
				$r->maketext(
					'A hardcopy file was generated, but it may not be complete or correct. Please check that no '
						. 'problems are missing and that they are all legible. If not, please inform your instructor.'
				),
				'<br>',
				CGI::a(
					{
						href => $self->systemLink(
							$r->urlpath->newFromModule(
								$r->urlpath->module, $r, courseID => $r->urlpath->arg('courseID')
							),
							params => { tempFilePath => $file_path }
						)
					},
					$r->maketext('Download Hardcopy')
				),
			);
		} else {
			print CGI::p(
				$r->maketext(
					'WeBWorK was unable to generate a paper copy of this homework set.  Please inform your instructor.')
			);
		}

		if ($perm_view_errors) {
			if (%temp_file_map) {
				print CGI::start_p();
				print $r->maketext('You can also examine the following temporary files: ');
				my $first = 1;
				while (my ($temp_file_name, $temp_file_url) = each %temp_file_map) {
					if ($first) {
						$first = 0;
					} else {
						print ', ';
					}
					print CGI::a(
						{
							href => $self->systemLink(
								$r->urlpath->newFromModule(
									$r->urlpath->module, $r, courseID => $r->urlpath->arg('courseID')
								),
								params => { tempFilePath => $temp_file_url }
							)
						},
						$temp_file_name
					);
				}
				print CGI::end_p();
			}
		}

		print CGI::hr();
	}

	# don't display the retry form if there are errors and the user doesn't have permission to view the errors.
	unless ($self->get_errors and not $perm_view_errors) {
		$self->display_form();
	}
	'';    # return a blank
}

sub display_form {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $ce = $r->ce;
	my $authz = $r->authz;
	my $userID = $r->param("user");
	my $eUserID = $r->param("effectiveUser");

	# first time we show up here, fill in some values
	unless ($r->param("in_hc_form")) {
		# if a set was passed in via the path_info, add that to the list of sets.
		my $singleSet = $r->urlpath->arg("setID");
		if (defined $singleSet and $singleSet ne "") {
			my @selected_sets = $r->param("selected_sets");
			$r->param("selected_sets" => [ @selected_sets, $singleSet]) unless grep { $_ eq $singleSet } @selected_sets;
		}

		# if no users are selected, select the effective user
		my @selected_users = $r->param("selected_users");
		unless (@selected_users) {
			$r->param("selected_users" => $eUserID);
		}
	}

	my $perm_multiset = $authz->hasPermissions($userID, "download_hardcopy_multiset");
	my $perm_multiuser = $authz->hasPermissions($userID, "download_hardcopy_multiuser");
	my $perm_texformat = $authz->hasPermissions($userID, "download_hardcopy_format_tex");
	my $perm_change_theme = $authz->hasPermissions($userID, "download_hardcopy_change_theme");
	my $perm_unopened = $authz->hasPermissions($userID, "view_unopened_sets");
	my $perm_view_hidden = $authz->hasPermissions($userID, "view_hidden_sets");
	my $perm_view_answers = $authz->hasPermissions($userID, "show_correct_answers_before_answer_date");
	my $perm_view_solutions = $authz->hasPermissions($userID, "show_solutions_before_answer_date");

	# get formats
	my @formats;
	foreach my $format (@HC_FORMAT_DISPLAY_ORDER) {
		push @formats, $format if $authz->hasPermissions($userID, "download_hardcopy_format_$format");
	}

	# get format names hash for radio buttons
	my %format_labels = map { $_ => $r->maketext($HC_FORMATS{$_}{name}) || $_ } @formats;

	print CGI::start_form(-name=>"hardcopy-form", -id=>"hardcopy-form", -method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields();
	print CGI::hidden("in_hc_form", 1);

	my $canShowCorrectAnswers = 0;
	my $canShowSolutions = 0;

	if ($perm_multiuser and $perm_multiset) {
		# Get all users for selection.
		my @Users = $db->getUsersWhere({ user_id => { not_like => 'set_id:%' } });

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
		my @SetVersions = ();
		for my $v (grep { $_->assignment_type =~ /gateway/ } @GlobalSets) {
			# FIXME: The set_id change here is a hideous, horrible hack.  The identifying key for a global set is the
			# set_id.  Those for a set version are the set_id and version_id.  But this means that we have trouble
			# displaying them both together in HTML::scrollingRecordList.  So we brutally play tricks with the set_id
			# here, which probably is not very robust, and certainly is aesthetically displeasing.  Yuck.
			push(@SetVersions,
				map { $_->set_id($_->set_id . ",v" . $_->version_id); $_ }
					$db->getSetVersionsWhere({ user_id => $eUserID, set_id => { like => $v->set_id . ',v%' } }));
		}

		# Filter out global gateway sets.  Only the versioned sets may be printed.
		my @WantedGlobalSets = grep { $_->assignment_type !~ /gateway/ } @GlobalSets;

		print CGI::p($r->maketext(
			"Select the homework sets for which to generate hardcopy versions. You may"
				. " also select multiple users from the users list. You will receive hardcopy"
				. " for each (set, user) pair."
		));

		print CGI::div(
			{ class => 'row gx-3' },
			CGI::div(
				{ class => 'col-xl-5 col-md-6 mb-2' },
				CGI::div(
					{ class => 'fw-bold text-center' },
					CGI::label({ for => 'selected_users' }, $r->maketext('Users'))
				),
				scrollingRecordList(
					{
						name            => 'selected_users',
						id              => 'selected_users',
						request         => $r,
						default_sort    => 'lnfn',
						default_format  => 'lnfn_uid',
						default_filters => ['all'],
						attrs => {
							size     => 20,
							multiple => $perm_multiuser
						}
					},
					@Users
				)
			),
			CGI::div(
				{ class => 'col-xl-5 col-md-6 mb-2' },
				CGI::div(
					{ class => 'fw-bold text-center' },
					CGI::label({ for => 'selected_sets' }, $r->maketext('Sets'))
				),
				scrollingRecordList(
					{
						name            => 'selected_sets',
						id              => 'selected_sets',
						request         => $r,
						default_sort    => 'set_id',
						default_format  => 'sid',
						default_filters => ['all'],
						attrs => {
							size     => 20,
							multiple => $perm_multiset,
							dir      => 'ltr'
						}
					},
					@WantedGlobalSets,
					@SetVersions
				)
			)
		);

		$canShowCorrectAnswers = 1;
		$canShowSolutions      = 1;

	} else {    # single user mode
		my $user = $db->getUser($eUserID);

		my $selected_set_id = $r->param("selected_sets");
		$selected_set_id = '' unless defined $selected_set_id;

		my $selected_user_id = $user->user_id;
		print CGI::hidden("selected_sets", $selected_set_id), CGI::hidden("selected_users", $selected_user_id);

		my $mergedSet;
		if ($selected_set_id =~ /(.*),v(\d+)$/) {
			# Determining if answers can be shown is more complicated for gateway tests.
			my $the_set_id      = $1;
			my $the_set_version = $2;
			$mergedSet = $db->getMergedSetVersion($selected_user_id, $the_set_id, $the_set_version);
			my $mergedProblem = $db->getMergedProblemVersion($selected_user_id, $the_set_id, $the_set_version, 1);

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
			$mergedSet = $db->getMergedSet($selected_user_id, $selected_set_id);

			$canShowCorrectAnswers = $perm_view_answers
				|| (defined($mergedSet) && after($mergedSet->answer_date));
		}
		# Make display for versioned sets a bit nicer
		$selected_set_id =~ s/,v(\d+)$/ (version $1)/;

		print CGI::p($r->maketext(
			"Download hardcopy of set [_1] for [_2]?",
			CGI::span({ dir => 'ltr' }, format_set_name_display($selected_set_id)),
			$user->first_name . " " . $user->last_name
		));

		$canShowSolutions = $canShowCorrectAnswers;
	}

	# Using maketext on the next line would trigger errors when a local hardcopyTheme is installed.
	# my %hardcopyThemeNames = map {$_ => $r->maketext($ce->{hardcopyThemeNames}->{$_})} @{$ce->{hardcopyThemes}};
	my %hardcopyThemeNames = map {$_ => $ce->{hardcopyThemeNames}->{$_}} @{$ce->{hardcopyThemes}};

	print CGI::div(
		{ class => 'row' },
		CGI::div(
			{ class => 'col-md-8 font-sm mb-2' },
			$r->maketext(
				'You may choose to show any of the following data. Correct answers, hints, and solutions '
					. 'are only available [_1] after the answer date of the homework set.',
				$perm_multiuser ? "to privileged users or" : ""
			)
		),
		CGI::div(
			{ class => 'row' },
			CGI::div(
				{ class => 'col-md-8' },
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::span({ class => 'input-group-text' }, CGI::b($r->maketext("Show:"))),
					CGI::div(
						{ class => 'input-group-text' },
						CGI::checkbox({
							name            => "printStudentAnswers",
							checked         => $r->param("printStudentAnswers") // 1,    # Checked by default
							label           => $r->maketext("Student answers"),
							class           => 'form-check-input me-2',
							labelattributes => { class => 'form-check-label' }
						})
					),
					CGI::div(
						{ class => 'input-group-text' },
						CGI::checkbox({
							name            => "showComments",
							checked         => scalar($r->param("showComments")) || 0,
							label           => $r->maketext("Comments"),
							class           => 'form-check-input me-2',
							labelattributes => { class => 'form-check-label' }
						})
					),
					$canShowCorrectAnswers ? CGI::div(
						{ class => 'input-group-text' },
						CGI::checkbox({
							name            => "showCorrectAnswers",
							checked         => scalar($r->param("showCorrectAnswers")) || 0,
							label           => $r->maketext("Correct answers"),
							class           => 'form-check-input me-2',
							labelattributes => { class => 'form-check-label' }
						})
					) : '',
					$canShowSolutions ? CGI::div(
						{ class => 'input-group-text' },
						CGI::checkbox({
							name            => "showHints",
							checked         => scalar($r->param("showHints")) || 0,
							label           => $r->maketext("Hints"),
							class           => 'form-check-input me-2',
							labelattributes => { class => 'form-check-label' }
						})
					) : '',
					$canShowSolutions ? CGI::div(
						{ class => 'input-group-text' },
						CGI::checkbox({
							name            => "showSolutions",
							checked         => scalar($r->param("showSolutions")) || 0,
							label           => $r->maketext("Solutions"),
							class           => 'form-check-input me-2',
							labelattributes => { class => 'form-check-label' }
						})
					) : ''
				)
			)
		),
		CGI::div(
			{ class => 'row' },
			CGI::div(
				{ class => 'col-md-8' },
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::span({ class => 'input-group-text' }, CGI::b($r->maketext("Hardcopy Format:"))),
					CGI::div(
						{ class => 'input-group-text' },
						CGI::radio_group({
							name            => "hardcopy_format",
							values          => \@formats,
							default         => scalar($r->param("hardcopy_format")) || $HC_DEFAULT_FORMAT,
							labels          => \%format_labels,
							class           => 'form-check-input me-2',
							labelattributes => { class => 'form-check-label me-3' }
						})
					)
				)
			)
		),
		$self->{can_show_source_file} ? CGI::div(
			{ class => 'row' },
			CGI::div(
				{ class => 'col-md-8' },
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::span({ class => 'input-group-text' }, CGI::b($r->maketext("Show Problem Source File:"))),
					CGI::div(
						{ class => 'input-group-text' },
						CGI::radio_group({
							name            => "show_source_file",
							values          => [ "Yes", "No" ],
							default         => "Yes",
							labels          => { Yes => $r->maketext("Yes"), No => $r->maketext("No") },
							class           => 'form-check-input me-2',
							labelattributes => { class => 'form-check-label me-3' }
						})
					)
				)
			)
		) : '',
		$perm_change_theme ? CGI::div(
			{ class => 'row' },
			CGI::div(
				{ class => 'col-md-8' },
				CGI::div(
					{ class => 'input-group input-group-sm mb-2' },
					CGI::span({ class => 'input-group-text' }, CGI::b($r->maketext("Hardcopy Theme"))),
					CGI::div(
						{ class => 'input-group-text' },
						CGI::radio_group({
							name            => "hardcopy_theme",
							values          => $ce->{hardcopyThemes},
							default         => scalar($r->param("hardcopyTheme")) || $ce->{hardcopyTheme},
							labels          => \%hardcopyThemeNames,
							class           => 'form-check-input me-2',
							labelattributes => { class => 'form-check-label me-3' }
						})
					)
				)
			)
		) : '',
		CGI::div(
			{ class => '' },
			CGI::submit({
				name  => "generate_hardcopy",
				value => $perm_multiuser
					? $r->maketext("Generate hardcopy for selected sets and selected users")
					: $r->maketext("Generate Hardcopy"),
				class => 'btn btn-primary'
			})
		)
	);

	print CGI::end_form();

	return "";
}

################################################################################
# harddcopy generating subroutines
################################################################################

sub generate_hardcopy {
	my ($self, $format, $userIDsRef, $setIDsRef) = @_;
	my $r     = $self->r;
	my $ce    = $r->ce;
	my $db    = $r->db;
	my $authz = $r->authz;

	my $courseID = $r->urlpath->arg('courseID');
	my $userID = $r->param('user');

	# Create the temporary directory.  Use mkpath to ensure it exists (mkpath is pretty much `mkdir -p`).
	my $temp_dir_parent_path = "$ce->{webworkDirs}{tmp}/$courseID/hardcopy/$userID";
	eval { mkpath($temp_dir_parent_path) };
	if ($@) {
		$self->add_errors(
			"Couldn't create hardcopy directory $temp_dir_parent_path: " . CGI::code(CGI::escapeHTML($@)));
		return;
	}

	# Create a randomly named working directory in the hardcopy directory.
	my $temp_dir_path = eval { tempdir('work.XXXXXXXX', DIR => $temp_dir_parent_path) };
	if ($@) {
		$self->add_errors("Couldn't create temporary working directory: " . CGI::code(CGI::escapeHTML($@)));
		return;
	}

	# Do some error checking.
	unless (-e $temp_dir_path) {
		$self->add_errors("Temporary directory '"
				. CGI::code(CGI::escapeHTML($temp_dir_path))
				. "' does not exist, but creation didn't fail. This shouldn't happen.");
		return;
	}
	unless (-w $temp_dir_path) {
		$self->add_errors("Temporary directory '" . CGI::code(CGI::escapeHTML($temp_dir_path)) . "' is not writeable.");
		$self->delete_temp_dir($temp_dir_path);
		return;
	}

	my $tex_file_name = 'hardcopy.tex';
	my $tex_file_path = "$temp_dir_path/$tex_file_name";

	# Create TeX file.

	my $open_result = open my $FH, '>:encoding(UTF-8)', $tex_file_path;
	unless ($open_result) {
		$self->add_errors("Failed to open file '"
				. CGI::code(CGI::escapeHTML($tex_file_path))
				. "' for writing: "
				. CGI::code(CGI::escapeHTML($!)));
		$self->delete_temp_dir($temp_dir_path);
		return;
	}
	$self->write_multiuser_tex($FH, $userIDsRef, $setIDsRef);
	close $FH;

	# If no problems were successfully rendered, we can't continue.
	unless ($self->{at_least_one_problem_rendered_without_error}) {
		$self->add_errors("No problems rendered. Can't continue.");
		$self->delete_temp_dir($temp_dir_path);
		return;
	}

	# If the hardcopy.tex file was not generated, fail now.
	unless (-e "$temp_dir_path/hardcopy.tex") {
		$self->add_errors("'"
				. CGI::code("hardcopy.tex")
				. "' not written to temporary directory '"
				. CGI::code(CGI::escapeHTML($temp_dir_path))
				. "'. Can't continue.");
		$self->delete_temp_dir($temp_dir_path);
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
	my ($final_file_name, @temp_files) = $self->$format_subr($temp_dir_path, $final_file_basename);
	my $final_file_path = "$temp_dir_path/$final_file_name";

	# Calculate paths for each temp file of interest.  These paths are relative to the $temp_dir_parent_path.
	# makeTempDirectory's interface forces us to reverse-engineer the relative temp dir path from the absolute path.
	my $temp_dir_rel_path = $temp_dir_path =~ s/^$temp_dir_parent_path\///r;
	my %temp_file_map = map { $_ => "$temp_dir_rel_path/$_" } @temp_files;

	# Make sure the final file exists.
	unless (-e $final_file_path) {
		$self->add_errors("Final hardcopy file '"
				. CGI::code(CGI::escapeHTML($final_file_path))
				. "' not found after calling '"
				. CGI::code(CGI::escapeHTML($format_subr)) . "': "
				. CGI::code(CGI::escapeHTML($!)));
		return { temp_file_map => \%temp_file_map };
	}

	# Try to move the hardcopy file out of the temp directory.
	my $final_file_final_path = "$temp_dir_parent_path/$final_file_name";
	my $mv_cmd = '2>&1 ' . $ce->{externalPrograms}{mv} . ' ' . shell_quote($final_file_path, $final_file_final_path);
	my $mv_out = readpipe $mv_cmd;
	if ($?) {
		$self->add_errors("Failed to move hardcopy file '"
				. CGI::code(CGI::escapeHTML($final_file_name))
				. "' from '"
				. CGI::code(CGI::escapeHTML($temp_dir_path))
				. "' to '"
				. CGI::code(CGI::escapeHTML($temp_dir_parent_path)) . "':"
				. CGI::br()
				. CGI::pre(CGI::escapeHTML($mv_out)));
		$final_file_final_path = "$temp_dir_rel_path/$final_file_name";
	}

	# If there were any errors, then the final file will not be served directly, but will be served via reply_with_file
	# and the full file path will be built at that time.  So the path needs to be relative to the temporary directory
	# parent path.
	$final_file_final_path =~ s/^$temp_dir_parent_path\/// if ($self->get_errors);

	# remove the temp directory if there are no errors
	$self->delete_temp_dir($temp_dir_path) unless ($self->get_errors || $PreserveTempFiles);

	warn "Preserved temporary files in directory '$temp_dir_path'.\n" if $PreserveTempFiles;

	return {
		file_name     => $final_file_name,
		file_path     => $final_file_final_path,
		file_type     => $HC_FORMATS{$format}{file_type} // 'application/pdf',
		temp_file_map => \%temp_file_map
	};
}

# helper function to remove temp dirs
sub delete_temp_dir {
	my ($self, $temp_dir_path) = @_;

	my $rm_cmd = '2>&1 ' . $self->r->ce->{externalPrograms}{rm} . ' -rf ' . shell_quote($temp_dir_path);
	my $rm_out = readpipe $rm_cmd;
	if ($?) {
		$self->add_errors("Failed to remove temporary directory '"
				. CGI::code(CGI::escapeHTML($temp_dir_path)) . "':"
				. CGI::br()
				. CGI::pre($rm_out));
	}

	return;
}

# Hardcopy generation subroutines
#
# These subroutines assume that the TeX source file is located at $temp_dir_path/hardcopy.tex The
# subroutines return a list whose first entry is the generated file name in $temp_dir_path, and
# whose remaining elements are names of temporary files that may be of interest in the case of an
# error (also located in $temp_dir_path).  These are returned whether or not an error actually
# occured.

sub generate_hardcopy_tex {
	my ($self, $temp_dir_path, $final_file_basename) = @_;

	my $src_name = "hardcopy.tex";
	my $bundle_path = "$temp_dir_path/$final_file_basename";

	# Create directory for the tex bundle
	if (!mkdir $bundle_path) {
		$self->add_errors("Failed to create directory '" . CGI::code(CGI::escapeHTML($bundle_path)) . "': " .
			CGI::br() . CGI::pre(CGI::escapeHTML($!)));
		return $src_name;
	}

	# Move the tex file into the bundle directory
	my $mv_cmd = "2>&1 " . $self->r->ce->{externalPrograms}{mv} . " " .
		shell_quote("$temp_dir_path/$src_name", $bundle_path);
	my $mv_out = readpipe $mv_cmd;

	if ($?) {
		$self->add_errors("Failed to move '" . CGI::code(CGI::escapeHTML($src_name)) . "' into directory '"
			. CGI::code(CGI::escapeHTML($bundle_path)) . "':" . CGI::br()
			. CGI::pre(CGI::escapeHTML($mv_out)));
		return $src_name;
	}

	# Copy the common tex files into the bundle directory
	my $ce = $self->r->ce;
	for (qw{packages.tex CAPA.tex PGML.tex}) {
		my $cp_cmd = "2>&1 $ce->{externalPrograms}{cp} " . shell_quote("$ce->{webworkDirs}{texinputs_common}/$_", $bundle_path);
		my $cp_out = readpipe $cp_cmd;
		if ($?) {
			$self->add_errors("Failed to copy '" . CGI::code(CGI::escapeHTML("$ce->{webworkDirs}{texinputs_common}/$_")) .
				"' into directory '" . CGI::code(CGI::escapeHTML($bundle_path)) . "':" . CGI::br()
				. CGI::pre(CGI::escapeHTML($cp_out)));
		}
	}

	# Attempt to copy image files used into the bundle directory
	# For security reasons only files in the $ce->{courseDirs}{html_temp}/images are included.
	# The file names of the images are only allowed to contain alphanumeric characters, underscores, dashes, and
	# periods.  No spaces or slashes, etc.  This will usually be all of the included images.
	if (open(my $in_fh,  "<", "$bundle_path/$src_name")) {
		local $/;
		my $data = <$in_fh>;
		close($in_fh);

		# Extract the included image file names and strip the absolute path in the tex file.
		my @image_files;
		my $image_tmp_dir = $ce->{courseDirs}{html_temp} . "/images/";
		$data =~ s{\\includegraphics\[([^]]*)\]\{$image_tmp_dir([^\}]*)\}}
			{push @image_files, $2; "\\includegraphics[$1]{$2}"}ge;

		# Rewrite the tex file with the image paths stripped.
		open(my $out_fh, ">", "$bundle_path/$src_name")
			or warn "Can't open $bundle_path/$src_name for writing.";
		print $out_fh $data;
		close $out_fh;

		for (@image_files) {
			# This is a little protection in case a student enters an answer like
			# \includegraphics[]{$ce->{courseDirs}{html_temp}/images/malicious code or absolute system file name}
			$self->add_errors("Unable to safely copy image '" . CGI::code(CGI::escapeHTML("$image_tmp_dir$_")) .
				"' into directory '" . CGI::code(CGI::escapeHTML($bundle_path)) . "'."),
			warn "Invalid image file name '$_' detected.  Possible malicious activity?",
		   	next unless $_ =~ /^[\w._-]*$/ && -f "$image_tmp_dir$_";

			# Copy the image file into the bundle directory.
			my $cp_cmd = "2>&1 $ce->{externalPrograms}{cp} " . shell_quote("$image_tmp_dir$_", $bundle_path);
			my $cp_out = readpipe $cp_cmd;
			if ($?) {
				$self->add_errors("Failed to copy image '" . CGI::code(CGI::escapeHTML("$image_tmp_dir$_")) .
					"' into directory '" . CGI::code(CGI::escapeHTML($bundle_path)) . "':" . CGI::br()
					. CGI::pre(CGI::escapeHTML($cp_out)));
			}
	   	}
	} else {
		$self->add_errors("Failed to open '" . CGI::code(CGI::escapeHTML("$bundle_path/$src_name")) . "' for reading.");
	}

	# Create a zip archive of the bundle directory
	my $zip = Archive::Zip->new();
	$zip->addTree($temp_dir_path);

	my $zip_file = "$final_file_basename.zip";
	unless ($zip->writeToFileNamed("$temp_dir_path/$zip_file") == AZ_OK) {
		$self->add_errors("Failed to create zip archive of directory '" .
			CGI::code(CGI::escapeHTML($bundle_path)) . "'");
		return "$bundle_path/$src_name";
	}

	return $zip_file;
}

sub generate_hardcopy_pdf {
	my ($self, $temp_dir_path, $final_file_basename) = @_;

	# call pdflatex - we don't want to chdir in the mod_perl process, as
	# that might step on the feet of other things (esp. in Apache 2.0)
	my $pdflatex_cmd = "cd " . shell_quote($temp_dir_path) . " && "
		. "TEXINPUTS=.:" . shell_quote($self->r->ce->{webworkDirs}{texinputs_common}) . ": "
		. $self->r->ce->{externalPrograms}{pdflatex}
		. " >pdflatex.stdout 2>pdflatex.stderr hardcopy";
	if (my $rawexit = system $pdflatex_cmd) {
		my $exit = $rawexit >> 8;
		my $signal = $rawexit & 127;
		my $core = $rawexit & 128;
		$self->add_errors("Failed to convert TeX to PDF with command '"
			.CGI::code(CGI::escapeHTML($pdflatex_cmd))."' (exit=$exit signal=$signal core=$core).");

		# read hardcopy.log and report first error
		my $hardcopy_log = "$temp_dir_path/hardcopy.log";
		if (-e $hardcopy_log) {
			if (open my $LOG, "<:encoding(UTF-8)", $hardcopy_log) {
				my $line;
				while ($line = <$LOG>) {
					last if $line =~ /^!\s+/;
				}
				my $first_error = $line;
				while ($line = <$LOG>) {
					last if $line =~ /^!\s+/;
					$first_error .= $line;
				}
				close $LOG;
				if (defined $first_error) {
					$self->add_errors("First error in TeX log is:".CGI::br().
						CGI::pre(CGI::escapeHTML($first_error)));
				} else {
					$self->add_errors("No errors encoundered in TeX log.");
				}
			} else {
				$self->add_errors("Could not read TeX log: ".CGI::code(CGI::escapeHTML($!)));
			}
		} else {
			$self->add_errors("No TeX log was found.");
		}
	}

	my $final_file_name;

	# try rename the pdf file
	my $src_name = "hardcopy.pdf";
	my $dest_name = "$final_file_basename.pdf";
	my $mv_cmd = "2>&1 " . $self->r->ce->{externalPrograms}{mv} . " " . shell_quote("$temp_dir_path/$src_name", "$temp_dir_path/$dest_name");
	my $mv_out = readpipe $mv_cmd;
	if ($?) {
		$self->add_errors("Failed to rename '".CGI::code(CGI::escapeHTML($src_name))."' to '"
			.CGI::code(CGI::escapeHTML($dest_name))."' in directory '"
			.CGI::code(CGI::escapeHTML($temp_dir_path))."':".CGI::br()
			.CGI::pre(CGI::escapeHTML($mv_out)));
		$final_file_name = $src_name;
	} else {
		$final_file_name = $dest_name;
	}

	return $final_file_name, qw/hardcopy.tex hardcopy.log hardcopy.aux pdflatex.stdout pdflatex.stderr/;
}

################################################################################
# TeX aggregating subroutines
################################################################################

sub write_multiuser_tex {
	my ($self, $FH, $userIDsRef, $setIDsRef) = @_;
	my $r = $self->r;
	my $ce = $r->ce;

	my @userIDs = @$userIDsRef;
	my @setIDs = @$setIDsRef;

	# get snippets
	my $theme = $r->param('hardcopy_theme') // $ce->{hardcopyTheme};
	my $themeDir = $ce->{webworkDirs}->{conf}.'/snippets/hardcopyThemes/'.$theme;
	my $preamble = $ce->{webworkFiles}->{hardcopySnippets}->{preamble} // "$themeDir/hardcopyPreamble.tex";
	my $postamble = $ce->{webworkFiles}->{hardcopySnippets}->{postamble} // "$themeDir/hardcopyPostamble.tex";
	my $divider = $ce->{webworkFiles}->{hardcopySnippets}->{userDivider} // "$themeDir/hardcopyUserDivider.tex";

	# write preamble
	$self->write_tex_file($FH, $preamble);

	# write section for each user
	while (defined (my $userID = shift @userIDs)) {
		$self->write_multiset_tex($FH, $userID, @setIDs);
		$self->write_tex_file($FH, $divider) if @userIDs; # divide users, but not after the last user
	}

	# write postamble
	$self->write_tex_file($FH, $postamble);
}

sub write_multiset_tex {
	my ($self, $FH, $targetUserID, @setIDs) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;

	# get user record
	my $TargetUser = $db->getUser($targetUserID); # checked
	unless ($TargetUser) {
		$self->add_errors("Can't generate hardcopy for user '".CGI::code(CGI::escapeHTML($targetUserID))."' -- no such user exists.\n");
		return;
	}

	# get set divider
	my $theme = $r->param('hardcopy_theme') // $ce->{hardcopyTheme};
	my $themeDir = $ce->{webworkDirs}->{conf}.'/snippets/hardcopyThemes/'.$theme;
	my $divider = $ce->{webworkFiles}->{hardcopySnippets}->{setDivider} // "$themeDir/hardcopySetDivider.tex";

	# write each set
	while (defined (my $setID = shift @setIDs)) {
		$self->write_set_tex($FH, $TargetUser, $setID);
		$self->write_tex_file($FH, $divider) if @setIDs; # divide sets, but not after the last set
	}
}

sub write_set_tex {
	my ($self, $FH, $TargetUser, $setID) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz  = $r->authz;
	my $userID = $r->param("user");

	# we may already have the MergedSet from checking hide_work and
	#    hide_score in pre_header_initialize; check to see if that's true,
	#    and otherwise, get the set.
	my %mergedSets = %{$self->{mergedSets}};
	my $uid = $TargetUser->user_id;
	my $MergedSet;
	my $versioned = 0;
	if ( defined( $mergedSets{"$uid!$setID"} ) ) {
		$MergedSet = $mergedSets{"$uid!$setID"};
		$versioned = ($setID =~ /,v(\d+)$/) ? $1 : 0;
	} else {
		if ( $setID =~ /(.+),v(\d+)$/ ) {
			$setID = $1;
			$versioned = $2;
		}
		if ( $versioned ) {
			$MergedSet = $db->getMergedSetVersion($TargetUser->user_id, $setID, $versioned);
		} else {
			$MergedSet = $db->getMergedSet($TargetUser->user_id, $setID); # checked
		}
	}
	# save versioned info for use in write_problem_tex
	$self->{versioned} = $versioned;

	unless ($MergedSet) {
		$self->add_errors("Can't generate hardcopy for set ''".CGI::code(CGI::escapeHTML($setID))
			."' for user '".CGI::code(CGI::escapeHTML($TargetUser->user_id))
			."' -- set is not assigned to that user.");
		return;
	}

	# see if the *real* user is allowed to access this problem set
	if ($MergedSet->open_date > time and not $authz->hasPermissions($userID, "view_unopened_sets")) {
		$self->add_errors("Can't generate hardcopy for set '".CGI::code(CGI::escapeHTML($setID))
			."' for user '".CGI::code(CGI::escapeHTML($TargetUser->user_id))
			."' -- set is not yet open.");
		return;
	}
	if (not $MergedSet->visible and not $authz->hasPermissions($userID, "view_hidden_sets")) {
		$self->addbadmessage("Can't generate hardcopy for set '".CGI::code(CGI::escapeHTML($setID))
			."' for user '".CGI::code(CGI::escapeHTML($TargetUser->user_id))
			."' -- set is not visible to students.");
		return;
	}

	# get snippets
	my $theme = $r->param('hardcopy_theme') // $ce->{hardcopyTheme};
	my $themeDir = $ce->{webworkDirs}->{conf}.'/snippets/hardcopyThemes/'.$theme;
	my $header = $MergedSet->hardcopy_header
		? $MergedSet->hardcopy_header
		: $ce->{webworkFiles}->{hardcopySnippets}->{setHeader};
  if ($header eq 'defaultHeader') {$header = $ce->{webworkFiles}->{hardcopySnippets}->{setHeader};}
	my $footer = $ce->{webworkFiles}->{hardcopySnippets}->{setFooter} //
	  "$themeDir/hardcopySetFooter.pg";
	my $divider = $ce->{webworkFiles}->{hardcopySnippets}->{problemDivider} // "$themeDir/hardcopyProblemDivider.tex";

	# get list of problem IDs
	my @problemIDs = map { $_->[2] }
		$db->listUserProblemsWhere({ user_id => $MergedSet->user_id, set_id => $MergedSet->set_id }, 'problem_id');

	# for versioned sets (gateways), we might have problems in a random
	# order; reset the order of the problemIDs if this is the case
	if ( defined( $MergedSet->problem_randorder ) &&
	     $MergedSet->problem_randorder ) {
		my @newOrder = ();

		# to set the same order each time we set the random seed to the psvn,
		# and to avoid messing with the system random number generator we use
		# our own PGrandom object
		my $pgrand = PGrandom->new();
		$pgrand->srand( $MergedSet->psvn );
		while ( @problemIDs ) {
			my $i = int($pgrand->rand(scalar(@problemIDs)));
			push( @newOrder, $problemIDs[$i] );
			splice(@problemIDs, $i, 1);
		}
		@problemIDs = @newOrder;
	}

	# write set header
	$self->write_problem_tex($FH, $TargetUser, $MergedSet, 0, $header); # 0 => pg file specified directly

	print $FH "\\medskip\\hrule\\nobreak\\smallskip";

	# write each problem
	# for versioned problem sets (gateway tests) we like to include
	#   problem numbers
	my $i = 1;
	while (my $problemID = shift @problemIDs) {
		$self->write_tex_file($FH, $divider) if $i > 1;
		$self->{versioned} = $i if $versioned;
		$self->write_problem_tex($FH, $TargetUser, $MergedSet, $problemID);
		$i++;
	}

	# write footer
	$self->write_problem_tex($FH, $TargetUser, $MergedSet, 0, $footer); # 0 => pg file specified directly
}

sub write_problem_tex {
	my ($self, $FH, $TargetUser, $MergedSet, $problemID, $pgFile) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $authz  = $r->authz;
	my $userID = $r->param("user");
	my $eUserID = $r->param("effectiveUser");
	my $versioned = $self->{versioned};
	my %canShowScore = %{$self->{canShowScore}};

	my @errors;

	# get problem record
	my $MergedProblem;
	if ($problemID) {
		# a non-zero problem ID was given -- load that problem
	    # we use $versioned to determine which merging routine to use
		if ( $versioned ) {
			$MergedProblem = $db->getMergedProblemVersion($MergedSet->user_id, $MergedSet->set_id, $MergedSet->version_id, $problemID);
		} else {
			$MergedProblem = $db->getMergedProblem($MergedSet->user_id, $MergedSet->set_id, $problemID); # checked
		}

		# handle nonexistent problem
		unless ($MergedProblem) {
			$self->add_errors("Can't generate hardcopy for problem '"
				.CGI::code(CGI::escapeHTML($problemID))."' in set '"
				.CGI::code(CGI::escapeHTML($MergedSet->set_id))
				."' for user '".CGI::code(CGI::escapeHTML($MergedSet->user_id))
				."' -- problem does not exist in that set or is not assigned to that user.");
			return;
		}
	} elsif ($pgFile) {
		# otherwise, we try an explicit PG file
		$MergedProblem = $db->newUserProblem(
			user_id => $MergedSet->user_id,
			set_id => $MergedSet->set_id,
			problem_id => 0,
			source_file => $pgFile,
			num_correct   => 0,
			num_incorrect => 0,
		);
		die "newUserProblem failed -- WTF?" unless $MergedProblem; # this should never happen
	} else {
		# this shouldn't happen -- error out for real
		die "write_problem_tex needs either a non-zero \$problemID or a \$pgFile";
	}

	# figure out if we're allowed to get correct answers, hints, and solutions
	# (eventually, we'd like to be able to use the same code as Problem)
	my $versionName = $MergedSet->set_id .
		(( $versioned ) ?  ",v" . $MergedSet->version_id : '');

	my $showCorrectAnswers  = $r->param("showCorrectAnswers")  || 0;
	my $printStudentAnswers = $r->param("printStudentAnswers") || 0;
	my $showHints           = $r->param("showHints")           || 0;
	my $showSolutions       = $r->param("showSolutions")       || 0;
	my $showComments        = $r->param("showComments")        || 0;

	unless( ( $authz->hasPermissions($userID, "show_correct_answers_before_answer_date") or
		  ( time > $MergedSet->answer_date or
		    ( $versioned &&
		      $MergedProblem->num_correct +
		      $MergedProblem->num_incorrect >=
		      $MergedSet->attempts_per_version &&
		      $MergedSet->due_date == $MergedSet->answer_date ) ) ) &&
		( $canShowScore{$MergedSet->user_id . "!$versionName"} ) ) {
		$showCorrectAnswers = 0;
		$showSolutions      = 0;
	}

	# FIXME -- there can be a problem if the $siteDefaults{timezone} is not defined?  Why is this?
	# why does it only occur with hardcopy?

	# we need an additional translation option for versioned sets; also,
	#   for versioned sets include old answers in the set if we're also
	#   asking for the answers
	my $transOpts = {
		displayMode              => "tex",
		showHints                => $showHints,
		showSolutions            => $showSolutions,
		processAnswers           => $showCorrectAnswers || $printStudentAnswers,
		permissionLevel          => $db->getPermissionLevel($userID)->permission,
		effectivePermissionLevel => $db->getPermissionLevel($eUserID)->permission,
	};

	if ( $versioned && $MergedProblem->problem_id != 0 ) {

		$transOpts->{QUIZ_PREFIX} = 'Q' . sprintf("%04d",$MergedProblem->problem_id()) . '_';

	}
	my $formFields = { };
	if ( $showCorrectAnswers ||$printStudentAnswers ) {
			my %oldAnswers = decodeAnswers($MergedProblem->last_answer);
			$formFields->{$_} = $oldAnswers{$_} foreach (keys %oldAnswers);
			print $FH "%% decoded old answers, saved. (keys = " . join(',', keys(%oldAnswers)) . "\n";
		}

#	warn("problem ", $MergedProblem->problem_id, ": source = ", $MergedProblem->source_file, "\n");

	my $pg = WeBWorK::PG->new(
		$ce,
		$TargetUser,
		scalar($r->param('key')), # avoid multiple-values problem
		$MergedSet,
		$MergedProblem,
		$MergedSet->psvn,
		$formFields, # no form fields!
		$transOpts,
	);

	# only bother to generate this info if there were warnings or errors
	my $edit_url;
	my $problem_name;
	my $problem_desc;
	if ($pg->{warnings} ne "" or $pg->{flags}->{error_flag}) {
		my $edit_urlpath = $r->urlpath->newFromModule(
			"WeBWorK::ContentGenerator::Instructor::PGProblemEditor", $r,
			courseID  => $r->urlpath->arg("courseID"),
			setID     => $MergedProblem->set_id,
			problemID => $MergedProblem->problem_id,
		);

		if ($MergedProblem->problem_id == 0) {
			# link for an fake problem (like a header file)
			$edit_url = $self->systemLink($edit_urlpath,
				params => {
					sourceFilePath => $MergedProblem->source_file,
					problemSeed    => $MergedProblem->problem_seed,
				},
			);
		} else {
			# link for a real problem
			$edit_url = $self->systemLink($edit_urlpath);
		}

		if ($MergedProblem->problem_id == 0) {
			$problem_name = "snippet";
			$problem_desc = $problem_name." '".$MergedProblem->source_file
				."' for set '".$MergedProblem->set_id."' and user '"
				.$MergedProblem->user_id."'";
		} else {
			$problem_name = "problem";
			$problem_desc = $problem_name." '".$MergedProblem->problem_id
				."' in set '".$MergedProblem->set_id."' for user '"
				.$MergedProblem->user_id."'";
		}
	}

	# deal with PG warnings
	if ($pg->{warnings} ne "") {
		$self->add_errors(CGI::a({href=>$edit_url, target=>"WW_Editor"}, $r->maketext("~[Edit~]"))
			.' '.$r->maketext("Warnings encountered while processing [_1]. Error text: [_2]", $problem_desc , CGI::br().CGI::pre(CGI::escapeHTML($pg->{warnings})))
		);
	}

	# deal with PG errors
	if ($pg->{flags}->{error_flag}) {
		$self->add_errors(CGI::a({href=>$edit_url, target=>"WW_Editor"}, $r->maketext("~[Edit~]")).' '
			.$r->maketext("Errors encountered while processing [_1]. This [_2] has been omitted from the hardcopy. Error text: [_3]", $problem_desc, $problem_name, CGI::br().CGI::pre(CGI::escapeHTML($pg->{errors})))
		);
		return;
	}

	# if we got here, there were no errors (because errors cause a return above)
	$self->{at_least_one_problem_rendered_without_error} = 1;

	my $body_text = $pg->{body_text};

	if ($problemID) {
		if (defined($MergedSet) && $MergedSet->assignment_type eq 'jitar') {
			# Use the pretty problem number if its a jitar problem
			my $id = $MergedProblem->problem_id;
			my $prettyID = join('.',jitar_id_to_seq($id));
			print $FH "{\\bf " . $r->maketext("Problem [_1].", $prettyID) . "}";
		} elsif ($MergedProblem->problem_id != 0) {
			print $FH "{\\bf " . $r->maketext("Problem [_1].", $versioned ? $versioned : $MergedProblem->problem_id) . "}";
		}

		my $problemValue = $MergedProblem->value;
		if (defined($problemValue)) {
			my $points = $problemValue == 1 ? $r->maketext('point') : $r->maketext('points');
			print $FH " {\\bf\\footnotesize($problemValue $points)}";
		}

		if ($self->{can_show_source_file} && $r->param("show_source_file") eq "Yes") {
			print $FH " {\\footnotesize\\path|" . $MergedProblem->source_file . "|}";
		}

		print $FH "\\smallskip\n\n";
	}

	print $FH $body_text;

	my @ans_entry_order = defined($pg->{flags}->{ANSWER_ENTRY_ORDER}) ? @{$pg->{flags}->{ANSWER_ENTRY_ORDER}} : ( );

	# print the list of student answers if it is requested
	if (  $printStudentAnswers &&
	     $MergedProblem->problem_id != 0 && @ans_entry_order ) {
			my $pgScore = $pg->{state}->{recorded_score};
			my $corrMsg = ' submitted: ';
			if ( $pgScore == 1 ) {
				$corrMsg .= $r->maketext('(correct)');
			} elsif ( $pgScore == 0 ) {
				$corrMsg .= $r->maketext('(incorrect)');
			} else {
				$corrMsg .= $r->maketext('(score [_1])',$pgScore);
			}

			$corrMsg .= "\n \\\\ \n recorded: ";
			my $recScore = $MergedProblem->status;
			if ( $recScore == 1 ) {
				$corrMsg .= $r->maketext('(correct)');
			} elsif ( $recScore == 0 ) {
				$corrMsg .= $r->maketext('(incorrect)');
			} else {
				$corrMsg .= $r->maketext('(score [_1])',$recScore);
			}

			my $stuAnswers = "\\par{\\small{\\it ".
			  $r->maketext("Answer(s) submitted:").
			  "}\n" .
			"\\vspace{-\\parskip}\\begin{itemize}\n";
		for my $ansName ( @ans_entry_order ) {
			my $stuAns;
			if (defined $pg->{answers}{$ansName}{preview_latex_string} && $pg->{answers}{$ansName}{preview_latex_string} ne '') {
				$stuAns = $pg->{answers}{$ansName}{preview_latex_string};
			} elsif (defined $pg->{answers}{$ansName}{original_student_ans} && $pg->{answers}{$ansName}{original_student_ans} ne '') {
				$stuAns = "\\text{".$pg->{answers}{$ansName}{original_student_ans}."}";
			} else {
				$stuAns = "\\text{no response}";
			}
			$stuAnswers .= "\\item\n\$\\displaystyle $stuAns\$\n";
		}
		$stuAnswers .= "\\end{itemize}}$corrMsg\\par\n";
		print $FH $stuAnswers;
	}

	if ($showComments) {
		my $userPastAnswerID = $db->latestProblemPastAnswer(
			$r->urlpath->arg("courseID"),
			$MergedProblem->user_id,
			$versionName,
			$MergedProblem->problem_id);

		my $pastAnswer = $userPastAnswerID ? $db->getPastAnswer($userPastAnswerID) : 0;
		my $comment = $pastAnswer && $pastAnswer->comment_string ? $pastAnswer->comment_string : "";

		my $commentMsg = "\\par{\\small{\\it ".
			$r->maketext("Instructor Feedback:").
			"}\n".
			"\\vspace{-\\parskip}\n".
			"\\begin{lstlisting}\n$comment\\end{lstlisting}\n".
			"\\par\n";
		print $FH $commentMsg if $comment;
	}

	# write the list of correct answers is appropriate; ANSWER_ENTRY_ORDER
	#   isn't defined for versioned sets?  this seems odd FIXME  GWCHANGE
	if ($showCorrectAnswers && $MergedProblem->problem_id != 0 && @ans_entry_order) {
	  my $correctTeX = "\\par{\\small{\\it ".
	    $r->maketext("Correct Answers:").
	    "}\n".
	    "\\vspace{-\\parskip}\\begin{itemize}\n";

		foreach my $ansName (@ans_entry_order) {
			my $correctAnswer = $pg->{answers}{$ansName}{correct_ans_latex_string} || "\\text{".$pg->{answers}{$ansName}{correct_ans}."}";
			$correctTeX .= "\\item\n\$\\displaystyle $correctAnswer\$\n";
		}

		$correctTeX .= "\\end{itemize}}\\par\n";

		print $FH $correctTeX;
	}
}

sub write_tex_file {
	my ($self, $FH, $file) = @_;

	my $tex = eval { readFile($file) };
	if ($@) {
		$self->add_errors("Failed to include TeX file '".CGI::code(CGI::escapeHTML($file))."': "
			.CGI::escapeHTML($@));
	} else {
		print $FH $tex;
	}
}

################################################################################
# utilities
################################################################################

sub add_errors {
	my ($self, @errors) = @_;
	push @{$self->{hardcopy_errors}}, @errors;
}

sub get_errors {
	my ($self) = @_;
	return $self->{hardcopy_errors} ? @{$self->{hardcopy_errors}} : ();
}

sub get_errors_ref {
	my ($self) = @_;
	return $self->{hardcopy_errors};
}

1;
