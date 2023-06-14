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

package WeBWorK::Utils::Rendering;
use Mojo::Base 'Exporter', -signatures;

=head1 NAME

WeBWorK::Utils::Rendering - utilities for rendering problems.

=cut

use Mojo::IOLoop;
use Mojo::JSON qw(decode_json);
use Data::Structure::Util qw(unbless);

use WeBWorK::Utils qw(formatDateTime);

our @EXPORT_OK = qw(constructPGOptions getTranslatorDebuggingOptions renderPG);

=head1 constructPGOptions

This method requires a course environment, user, set, problem, psvn, form
fields, and translation options. It constructs the options to pass to the
WeBWorK::PG constructor in the new format.  The options are roughly in
correspondence to the PG translator environment variables.

=cut

sub constructPGOptions ($ce, $user, $set, $problem, $psvn, $formFields, $translationOptions) {
	my %options;

	# Problem information
	$options{psvn} = $psvn // $set->psvn;

	# If a problemUUID is provided in the form fields, then that is used.  Otherwise we create one that depends on
	# the course, user, set, and problem.  Note that it is not a true UUID, but will be converted into one by PG.
	$options{problemUUID} = $formFields->{problemUUID}
		|| join('-', $user->user_id, $ce->{courseName}, 'set' . $set->set_id, 'prob' . $problem->problem_id);

	$options{probNum}        = $problem->problem_id;
	$options{questionNumber} = $options{probNum};
	$options{r_source}       = $translationOptions->{r_source};
	$options{sourceFilePath} = $problem->source_file;
	$options{problemSeed}    = $problem->problem_seed;

	# Display information
	$options{displayMode}        = $translationOptions->{displayMode};
	$options{showHints}          = $translationOptions->{showHints};
	$options{showSolutions}      = $translationOptions->{showSolutions};
	$options{forceScaffoldsOpen} = $translationOptions->{forceScaffoldsOpen};
	$options{setOpen}            = time > $set->open_date;
	$options{pastDue}            = time > $set->due_date;
	$options{answersAvailable}   = time > $set->answer_date;
	$options{refreshMath2img}    = $translationOptions->{refreshMath2img};

	# Default values for evaluating answers
	$options{ansEvalDefaults} = $ce->{pg}{ansEvalDefaults};

	# Dates are passed in for set headers.
	for my $date (qw(openDate dueDate answerDate)) {
		my $db_date = $date =~ s/D/_d/r;
		$options{$date} = $set->$db_date;
		$options{ 'formatted' . ucfirst($date) } = formatDateTime($options{$date}, $ce->{siteDefaults}{timezone});
		# This is provided due to a typo in many header files.
		$options{ 'formated' . ucfirst($date) } = $options{ 'formatted' . ucfirst($date) };
		my $uc_date = ucfirst($date);
		for (
			[ 'DayOfWeek',       '%A' ],
			[ 'DayOfWeekAbbrev', '%a' ],
			[ 'Day',             '%d' ],
			[ 'MonthNumber',     '%m' ],
			[ 'MonthWord',       '%B' ],
			[ 'MonthAbbrev',     '%b' ],
			[ 'Year2Digit',      '%y' ],
			[ 'Year4Digit',      '%Y' ],
			[ 'Hour12',          '%I' ],
			[ 'Hour24',          '%H' ],
			[ 'Minute',          '%M' ],
			[ 'AMPM',            '%P' ],
			[ 'TimeZone',        '%Z' ],
			[ 'Time12',          '%I:%M%P' ],
			[ 'Time24',          '%R' ],
			)
		{
			$options{"$uc_date$_->[0]"} =
				formatDateTime($options{$date}, $ce->{siteDefaults}{timezone}, $_->[1], $ce->{siteDefaults}{locale});
		}
	}
	$options{reducedScoringDate}          = $set->reduced_scoring_date;
	$options{formattedReducedScoringDate} = formatDateTime($options{reducedScoringDate}, $ce->{siteDefaults}{timezone});

	# State Information
	$options{numOfAttempts} =
		($problem->num_correct || 0) + ($problem->num_incorrect || 0) + ($formFields->{submitAnswers} ? 1 : 0);
	$options{problemValue} = $problem->value;
	# If reduced scoring is enabled for the set and the sub_status is less than the status, then the status is the
	# reduced score.  In that case compute the unreduced score that resulted in that reduced score to submit as the
	# currently recorded score.
	$options{recorded_score} =
		($set->enable_reduced_scoring
			&& $ce->{pg}{ansEvalDefaults}{reducedScoringValue}
			&& defined $problem->sub_status
			&& $problem->sub_status < $problem->status)
		? (($problem->status - $problem->sub_status) / $ce->{pg}{ansEvalDefaults}{reducedScoringValue} +
			$problem->sub_status)
		: $problem->status;
	$options{num_of_correct_ans}   = $problem->num_correct;
	$options{num_of_incorrect_ans} = $problem->num_incorrect;

	# Persistent problem data
	$options{PERSISTENCE_HASH} = decode_json($problem->problem_data || '{}');

	# Language
	$options{language}            = $ce->{language};
	$options{language_subroutine} = WeBWorK::Localize::getLoc($options{language});

	# Student and course Information
	$options{courseName}       = $ce->{courseName};
	$options{sectionName}      = $user->section;
	$options{sectionNumber}    = $options{sectionName};
	$options{recitationName}   = $user->recitation;
	$options{recitationNumber} = $options{recitationName};
	$options{setDescription}   = $set->description;
	$options{setNumber}        = $set->set_id;
	$options{studentLogin}     = $user->user_id;
	$options{studentName}      = $user->first_name . ' ' . $user->last_name;
	$options{studentID}        = $user->student_id;

	# Permission level of actual user (deprecated)
	$options{permissionLevel} = $translationOptions->{permissionLevel};
	# permission level of user assigned to this question (deprecated)
	$options{effectivePermissionLevel} = $translationOptions->{effectivePermissionLevel};

	# Replacement for permission level.  This is really all PG needs in addition to the debugging options below.
	$options{isInstructor} = $translationOptions->{isInstructor};

	# Debugging options that determine if various pieces of PG information can be shown.
	$options{debuggingOptions} = $translationOptions->{debuggingOptions} // {};

	# Answer Information
	$options{inputs_ref}     = $formFields;
	$options{processAnswers} = $translationOptions->{processAnswers};

	# External Data
	$options{external_data} = decode_json($set->{external_data} || '{}');

	# Directories and URLs
	$options{macrosPath}        = $ce->{pg}{directories}{macrosPath};
	$options{htmlPath}          = $ce->{pg}{directories}{htmlPath};
	$options{imagesPath}        = $ce->{pg}{directories}{imagesPath};
	$options{htmlDirectory}     = "$ce->{courseDirs}{html}/";
	$options{htmlURL}           = "$ce->{courseURLs}{html}/";
	$options{templateDirectory} = "$ce->{courseDirs}{templates}/";
	$options{tempDirectory}     = "$ce->{courseDirs}{html_temp}/";
	$options{tempURL}           = "$ce->{courseURLs}{html_temp}/";
	$options{webworkDocsURL}    = "$ce->{webworkURLs}{docs}/";
	$options{localHelpURL}      = "$ce->{pg}{URLs}{localHelpURL}/";
	$options{MathJaxURL}        = $ce->{webworkURLs}{MathJax};
	$options{server_root_url}   = $ce->{server_root_url} || '';

	$options{use_site_prefix}   = $translationOptions->{use_site_prefix};
	$options{use_opaque_prefix} = $translationOptions->{use_opaque_prefix};

	$options{answerPrefix}   = $translationOptions->{QUIZ_PREFIX} // '';    # used by quizzes
	$options{grader}         = $ce->{pg}{options}{grader};
	$options{useMathQuill}   = $translationOptions->{useMathQuill};
	$options{useMathView}    = $translationOptions->{useMathView};
	$options{mathViewLocale} = $ce->{pg}{options}{mathViewLocale};

	$options{__files__} = {
		root => $ce->{webworkDirs}{root},        # used to shorten filenames
		pg   => $ce->{pg}{directories}{root},    # ditto
		tmpl => $ce->{courseDirs}{templates},    # ditto
	};

	# Variables for interpreting capa problems and other things to be seen in a pg file.
	$options{specialPGEnvironmentVars} = $ce->{pg}{specialPGEnvironmentVars};

	return %options;
}

=head1 getTranslatorDebuggingOptions

This method requires an $authz and a $userName, and converts permissions into
the corresponding PG debugging environment variable.

=cut

# Set translator debugging options for the user.
sub getTranslatorDebuggingOptions ($authz, $userName) {
	return {
		map { $_ => $authz->hasPermissions($userName, $_) }
			qw(
			show_resource_info
			view_problem_debugging_info
			show_pg_info
			show_answer_hash_info
			show_answer_group_info
			)
	};
}

=head1 renderPG

This method requires a course environment, user, set, problem, psvn, form
fields, and translation options.  These are passed to the WeBWorK::PG
constructor inside of a subprocess.  The created object is then parsed into a
hash that containing all of the data webwork2 needs for rendering and processing
the problem.  Note that this hash can not contain any blessed references.  Those
will all be lost in the return value from the process.

The return value of the method is a Mojo::Promise that will resolve to the above
hash when awaited.

=cut

sub renderPG ($c, $effectiveUser, $set, $problem, $psvn, $formFields, $translationOptions) {
	# Set the inactivity timeout to be 5 seconds more than the PG timeout.
	$c->inactivity_timeout($WeBWorK::PG::TIMEOUT + 5);

	return Mojo::IOLoop->subprocess->run_p(sub {
		my $pg = WeBWorK::PG->new(constructPGOptions(
			$c->ce, $effectiveUser, $set, $problem, $psvn, $formFields, $translationOptions));

		my $ret = {
			body_text        => $pg->{body_text},
			head_text        => $pg->{head_text},
			post_header_text => $pg->{post_header_text},
			answers          => unbless($pg->{answers}),
			errors           => $pg->{errors},
			warnings         => $pg->{warnings},
			result           => $pg->{result},
			state            => $pg->{state},
			flags            => $pg->{flags},
		};

		if (ref $pg->{pgcore}) {
			$ret->{internal_debug_messages} = $pg->{pgcore}->get_internal_debug_messages;
			$ret->{warning_messages}        = $pg->{pgcore}->get_warning_messages();
			$ret->{debug_messages}          = $pg->{pgcore}->get_debug_messages();
			$ret->{PG_ANSWERS_HASH}         = {
				map {
					$_ => {
						response_obj => unbless($pg->{pgcore}{PG_ANSWERS_HASH}{$_}->response_obj),
						rh_ans       => $pg->{pgcore}{PG_ANSWERS_HASH}{$_}{ans_eval}{rh_ans}
					}
				}
					keys %{ $pg->{pgcore}{PG_ANSWERS_HASH} }
			};
			$ret->{resource_list} = {
				map { $_ => $pg->{pgcore}{PG_alias}{resource_list}{$_}{uri}{content} }
					keys %{ $pg->{pgcore}{PG_alias}{resource_list} }
			};
			$ret->{PERSISTENCE_HASH_UPDATED} = $pg->{pgcore}{PERSISTENCE_HASH_UPDATED};
			$ret->{PERSISTENCE_HASH}         = $pg->{pgcore}{PERSISTENCE_HASH};
		}

		# Save the problem source. This is used by Caliper::Entity. Why?
		$ret->{problem_source_code} = $pg->{translator}{source} if ref $pg->{translator};

		$pg->free;
		return $ret;
	})->catch(sub ($err) {
		return { body_text => '', answers => {}, flags => { error_flag => 1 }, errors => $err };
	});
}

1;
