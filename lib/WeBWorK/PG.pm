################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::PG;

=head1 NAME

WeBWorK::PG - Wrap the action of the PG Translator in an easy-to-use API.

=cut

use strict;
use warnings;
use File::Path qw(rmtree);
use File::Temp qw(tempdir);
use WeBWorK::DB::Classlist;
use WeBWorK::DB::WW;
use WeBWorK::PG::Translator;
use WeBWorK::Problem;
use WeBWorK::Utils qw(readFile formatDateTime writeTimingLogEntry);

sub new($$$$$$$$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my (
		$courseEnv,
		$user,
		$key,
		$set,
		$problem,
		$psvn,
		$formFields, # in CGI::Vars format
		$translationOptions, # hashref containing options for the
		                     # translator, such as whether to show
				     # hints and the display mode to use
	) = @_;
	
	# write timing log entry
	writeTimingLogEntry($courseEnv, "WeBWorK::PG::new",
		"user=".$user->id.",problem=".$courseEnv->{courseName}."/".$set->id."/".$problem->id.",mode=".$translationOptions->{displayMode},
		"begin");
	
	# install a local warn handler to collect warnings
	my $warnings = "";
	if ($courseEnv->{pg}->{options}->{catchWarnings}) {
		local $SIG{__WARN__} = sub { $warnings .= shift };
	}
	
	# create a Translator
	#warn "PG: creating a Translator\n";
	my $translator = WeBWorK::PG::Translator->new;
	
	# set the directory hash
	#warn "PG: setting the directory hash\n";
	$translator->rh_directories({
		courseScriptsDirectory => $courseEnv->{webworkDirs}->{macros},
		macroDirectory         => $courseEnv->{courseDirs}->{macros},
		templateDirectory      => $courseEnv->{courseDirs}->{templates},
		tempDirectory          => $courseEnv->{courseDirs}->{html_temp},
	});
	
	# evaluate modules and "extra packages"
	#warn "PG: evaluating modules and \"extra packages\"\n";
	my @modules = @{ $courseEnv->{pg}->{modules} };
	foreach my $module_packages_ref (@modules) {
		my ($module, @extra_packages) = @$module_packages_ref;
		# the first item is the main package
		$translator->evaluate_modules($module);
		# the remaining items are "extra" packages
		$translator->load_extra_packages(@extra_packages);
	}
	
	# set the environment (from defineProblemEnvir)
	#warn "PG: setting the environment (from defineProblemEnvir)\n";
	my $envir = defineProblemEnvir(
		$courseEnv,
		$user,
		$key,
		$set,
		$problem,
		$psvn,
		$formFields,
		$translationOptions,
	);
	$translator->environment($envir);
	
	# initialize the Translator
	#warn "PG: initializing the Translator\n";
	$translator->initialize();
	
	# load IO.pl, PG.pl, and dangerousMacros.pl using unrestricted_load
	# i'd like to change this at some point to have the same sort of interface to global.conf
	# that the module loading does -- have a list of macros to load unrestrictedly.
	#warn "PG: loading IO.pl, PG.pl, and dangerousMacros.pl using unrestricted_load\n";
	foreach (qw(IO.pl PG.pl dangerousMacros.pl)) {
		my $macroPath = $courseEnv->{webworkDirs}->{macros} . "/$_";
		my $err = $translator->unrestricted_load($macroPath);
		warn "Error while loading $macroPath: $err" if $err;
	}
	#my $pg_pl              = $courseEnv->{webworkDirs}->{macros} . "/PG.pl";
	#my $dangerousMacros_pl = $courseEnv->{webworkDirs}->{macros} . "/dangerousMacros.pl";
	#my $io_pl              = $courseEnv->{webworkDirs}->{macros} . "/IO.pl";
	#my $err = $translator->unrestricted_load($pg_pl);
	#warn "Error while loading $pg_pl: $err" if $err;
	#$err = $translator->unrestricted_load($dangerousMacros_pl);
	#warn "Error while loading $dangerousMacros_pl: $err" if $err;
	#$err = $translator->unrestricted_load($io_pl);
	#warn "Error while loading $io_pl: $err" if $err;
	
	# set the opcode mask (using default values)
	#warn "PG: setting the opcode mask (using default values)\n";
	$translator->set_mask();
	
	# store the problem source
	#warn "PG: storing the problem source\n";
	my $sourceFile = $problem->source_file;
	$sourceFile = $courseEnv->{courseDirs}->{templates}."/".$sourceFile
		unless ($sourceFile =~ /^\//);
	eval { $translator->source_string(readFile($sourceFile)) };
	if ($@) {
		# well, we couldn't get the problem source, for some reason.
		return bless {
			translator => $translator,
			head_text  => "",
			body_text  => <<EOF,
WeBWorK::Utils::readFile($sourceFile) says:
$@
EOF
			answers    => {},
			result     => {},
			state      => {},
			errors     => "Failed to read the problem source file.",
			warnings   => $warnings,
			flags      => {error_flag => 1},
		}, $class;
	}
	
	# install a safety filter (&safetyFilter)
	#warn "PG: installing a safety filter\n";
	$translator->rf_safety_filter(\&safetyFilter);
	
	# translate the PG source into text
	#warn "PG: translating the PG source into text\n";
	$translator->translate();
	
	# after we're done translating, we may have to clean up after the translator.
	# for example, 'images' mode uses a tempdir for dvipng's temp files. We have
	# to remove it.
	if ($translationOptions->{displayMode} eq 'images' && $envir->{dvipngTempDir}) {
		rmtree($envir->{dvipngTempDir}, 0, 0);
	}
	
	my ($result, $state); # we'll need these on the other side of the if block!
	if ($translationOptions->{processAnswers}) {
		
		# process student answers
		#warn "PG: processing student answers\n";
		$translator->process_answers($formFields);

		# retrieve the problem state and give it to the translator
		#warn "PG: retrieving the problem state and giving it to the translator\n";
		$translator->rh_problem_state({
			recorded_score =>       $problem->status,
			num_of_correct_ans =>   $problem->num_correct,
			num_of_incorrect_ans => $problem->num_incorrect,
		});

		# determine an entry order -- the ANSWER_ENTRY_ORDER flag is built by
		# the PG macro package (PG.pl)
		#warn "PG: determining an entry order\n";
		my @answerOrder =
			$translator->rh_flags->{ANSWER_ENTRY_ORDER}
				? @{ $translator->rh_flags->{ANSWER_ENTRY_ORDER} }
				: keys %{ $translator->rh_evaluated_answers };

		# install a grader -- use the one specified in the problem,
		# or fall back on the default from the course environment.
		# (two magic strings are accepted, to avoid having to
		# reference code when it would be difficult.)
		#warn "PG: installing a grader\n";
		my $grader = $translator->rh_flags->{PROBLEM_GRADER_TO_USE}
			|| $courseEnv->{pg}->{options}->{grader};
		$grader = $translator->rf_std_problem_grader
			if $grader eq "std_problem_grader";
		$grader = $translator->rf_avg_problem_grader
			if $grader eq "avg_problem_grader";
		die "Problem grader $grader is not a CODE reference."
			unless ref $grader eq "CODE";
		$translator->rf_problem_grader($grader);

		# grade the problem
		#warn "PG: grading the problem\n";
		($result, $state) = $translator->grade_problem(
			answers_submitted  => $translationOptions->{processAnswers},
			ANSWER_ENTRY_ORDER => \@answerOrder,
		);
		
	}
	
	# write timing log entry
	writeTimingLogEntry($courseEnv, "WeBWorK::PG::new", "", "end");
	
	# return an object which contains the translator and the results of
	# the translation process. this is DIFFERENT from the "format expected
	# by Webwork.pm (and I believe processProblem8, but check.)"
	return bless {
		translator => $translator,
		head_text  => ${ $translator->r_header },
		body_text  => ${ $translator->r_text   },
		answers    => $translator->rh_evaluated_answers,
		result     => $result,
		state      => $state,
		errors     => $translator->errors,
		warnings   => $warnings,
		flags      => $translator->rh_flags,
	}, $class;
}

# -----

sub defineProblemEnvir($$$$$$$) {
	my (
		$courseEnv,
		$user,
		$key,
		$set,
		$problem,
		$psvn,
		$formFields,
		$options,
	) = @_;
	
	my %envir;
	
	# PG environment variables
	# from docs/pglanguage/pgreference/environmentvariables as of 06/25/2002
	# any changes are noted by "ADDED:" or "REMOVED:"
	
	# Vital state information
	# ADDED: displayHintsQ, displaySolutionsQ, refreshMath2img,
	#        texDisposition
	
	$envir{psvn}              = $psvn;			 
	$envir{psvnNumber}        = $envir{psvn};		 
	$envir{probNum}           = $problem->id;		 
	$envir{questionNumber}    = $envir{probNum};		 
	$envir{fileName}          = $problem->source_file;	 
	$envir{probFileName}      = $envir{fileName};		 
	$envir{problemSeed}       = $problem->problem_seed;	 
	$envir{displayMode}       = translateDisplayModeNames($options->{displayMode});
	$envir{languageMode}      = $envir{displayMode};	 
	$envir{outputMode}        = $envir{displayMode};	 
	$envir{displayHintsQ}     = $options->{hints};	 
	$envir{displaySolutionsQ} = $options->{solutions};
	$envir{refreshMath2img}   = $options->{refreshMath2img};
	$envir{texDisposition}    = "pdf"; # in webwork-modperl, we use pdflatex
	
	# Problem Information
	# ADDED: courseName
	
	$envir{openDate}            = $set->open_date;
	$envir{formattedOpenDate}   = formatDateTime($envir{openDate});
	$envir{dueDate}             = $set->due_date;
	$envir{formattedDueDate}    = formatDateTime($envir{dueDate});
	$envir{answerDate}          = $set->answer_date;
	$envir{formattedAnswerDate} = formatDateTime($envir{answerDate});
	$envir{numOfAttempts}       = ($problem->num_correct || 0) + ($problem->num_incorrect || 0);
	$envir{problemValue}        = $problem->value;
	$envir{sessionKey}          = $key;
	$envir{courseName}          = $courseEnv->{courseName};
	
	# Student Information
	# ADDED: studentID
	
	$envir{sectionName}      = $user->section;
	$envir{sectionNumber}    = $envir{sectionName};
	$envir{recitationName}   = $user->recitation;
	$envir{recitationNumber} = $envir{recitationName};
	$envir{setNumber}        = $set->id;
	$envir{studentLogin}     = $user->id;
	$envir{studentName}      = $user->first_name . " " . $user->last_name;
	$envir{studentID}        = $user->student_id;
	
	# Answer Information
	# REMOVED: refSubmittedAnswers
	
	$envir{inputs_ref} = $formFields;
	
	# External Programs
	# ADDED: externalLaTeXPath, externalDvipngPath,
	#        externalGif2EpsPath, externalPng2EpsPath
	
	$envir{externalTTHPath}      = $courseEnv->{externalPrograms}->{tth};
	$envir{externalLaTeXPath}    = $courseEnv->{externalPrograms}->{latex};
	$envir{externalDvipngPath}   = $courseEnv->{externalPrograms}->{dvipng};
	$envir{externalGif2EpsPath}  = $courseEnv->{externalPrograms}->{gif2eps};
	$envir{externalPng2EpsPath}  = $courseEnv->{externalPrograms}->{png2eps};
	$envir{externalGif2PngPath}  = $courseEnv->{externalPrograms}->{gif2png};
	
	# Directories and URLs
	# REMOVED: courseName
	# ADDED: dvipngTempDir
	
	$envir{cgiDirectory}           = undef;
	$envir{cgiURL}                 = undef;
	$envir{classDirectory}         = undef;
	$envir{courseScriptsDirectory} = $courseEnv->{webworkDirs}->{macros}."/";
	$envir{htmlDirectory}          = $courseEnv->{courseDirs}->{html}."/";
	$envir{htmlURL}                = $courseEnv->{courseURLs}->{html}."/";
	$envir{macroDirectory}         = $courseEnv->{courseDirs}->{macros}."/";
	$envir{templateDirectory}      = $courseEnv->{courseDirs}->{templates}."/";
	$envir{tempDirectory}          = $courseEnv->{courseDirs}->{html_temp}."/";
	$envir{tempURL}                = $courseEnv->{courseURLs}->{html_temp}."/";
	$envir{scriptDirectory}        = undef;
	$envir{webworkDocsURL}         = $courseEnv->{webworkURLs}->{docs}."/";
	$envir{dvipngTempDir}          = $options->{displayMode} eq 'images'
		? tempdir("webwork-dvipng-XXXXXXXX", DIR => $envir{tempDirectory})
		: undef;
	
	# Information for sending mail
	
	$envir{mailSmtpServer} = $courseEnv->{mail}->{smtpServer};
	$envir{mailSmtpSender} = $courseEnv->{mail}->{smtpSender};
	
	# Default values for evaluating answers
	
	my $ansEvalDefaults = $courseEnv->{pg}->{ansEvalDefaults};
	$envir{$_} = $ansEvalDefaults->{$_} foreach (keys %$ansEvalDefaults);
	
	# Other things...
	
	$envir{PROBLEM_GRADER_TO_USE} = $courseEnv->{pg}->{options}->{grader};
	
	return \%envir;
}

sub translateDisplayModeNames($) {
	my $name = shift;
	return {
		tex           => "TeX",
		plainText     => "HTML",
		formattedText => "HTML_tth",
		images        => "HTML_img"
	}->{$name};
}

sub safetyFilter {
	my $answer = shift; # accepts one answer and checks it
	my $submittedAnswer = $answer;
	$answer = '' unless defined $answer;
	my ($errorno);
	$answer =~ tr/\000-\037/ /;
	# Return if answer field is empty
	unless ($answer =~ /\S/) {
		#$errorno = "<BR>No answer was submitted.";
		$errorno = 0;  ## don't report blank answer as error
		return ($answer,$errorno);
	}
	# replace ^ with **    (for exponentiation)
	# $answer =~ s/\^/**/g;
	# Return if forbidden characters are found
	unless ($answer =~ /^[a-zA-Z0-9_\-\+ \t\/@%\*\.\n^\(\)]+$/ )  {
		$answer =~ tr/a-zA-Z0-9_\-\+ \t\/@%\*\.\n^\(\)/#/c;
		$errorno = "<BR>There are forbidden characters in your answer: $submittedAnswer<BR>";
		return ($answer,$errorno);
	}
	$errorno = 0;
	return($answer, $errorno);
}

1;

__END__

=head1 SYNOPSIS

 $pg = WeBWorK::PG->new(
	 $courseEnv,  # a WeBWorK::CourseEnvironment object
	 $user,       # a WeBWorK::User object
	 $sessionKey,
	 $set,        # a WeBWorK::Set object
	 $problem,    # a WeBWorK::Problem object
	 $psvn,
	 $formFields  # in &WeBWorK::Form::Vars format
	 { # translation options
		 displayMode     => "images", # (plainText|formattedText|images)
		 showHints       => 1,        # (0|1)
		 showSolutions   => 0,        # (0|1)
		 refreshMath2img => 0,        # (0|1)
		 processAnswers  => 1,        # (0|1)
	 },
 );

 $translator = $pg->{translator}; # WeBWorK::PG::Translator
 $body       = $pg->{body_text};  # text string
 $header     = $pg->{head_text};  # text string
 $answerHash = $pg->{answers};    # WeBWorK::PG::AnswerHash
 $result     = $pg->{result};     # hash reference
 $state      = $pg->{state};      # hash reference
 $errors     = $pg->{errors};     # text string
 $warnings   = $pg->{warnings};   # text string
 $flags      = $pg->{flags};      # hash reference

=head1 DESCRIPTION

WeBWorK::PG encapsulates the PG translation process, making multiple calls to
WeBWorK::PG::Translator. Much of the flexibility of the Translator is hidden,
instead making choices that are appropriate for the webwork-modperl system.

=head1 CONSTRUCTION

=over

=item new (ENVIRONMENT, USER, KEY, SET, PROBLEM, PSVN, FIELDS, OPTIONS)

The C<new> method creates a translator, initializes it using the parameters
specified, translates a PG file, and processes answers. It returns a reference
to a blessed hash containing the results of the translation process.

=back

=head2 Parameters

=over

=item ENVIRONMENT

a WeBWorK::CourseEnvironment object

=item USER

a WeBWorK::User object

=item KEY

the session key of the current session

=item SET

a WeBWorK::Set object

=item PROBLEM

a WeBWorK::Problem object. The contents of the source_file field can specify a
PG file either by absolute path or path relative to the "templates" directory.
I<The caller should remove taint from this value before passing!>

=item PSVN

the problem set version number

=item FIELDS

a reference to a hash (as returned by &WeBWorK::Form::Vars) containing form
fields submitted by a problem processor. The translator will look for fields
like "AnSwEr[0-9]" containing submitted student answers.

=item OPTIONS

a reference to a hash containing the following data:

=over

=item displayMode 

one of "plainText", "formattedText", or "images"

=item showHints

boolean, render hints

=item showSolutions

boolean, render solutions

=item refreshMath2img

boolean, force images created by math2img (in "images" mode) to be recreated,
even if the PG source has not been updated.

=item processAnswers

boolean, call answer evaluators and graders

=back

=back

=head2 RETURN VALUE

The C<new> method returns a blessed hash reference containing the following
fields. More information can be found in the documentation for
WeBWorK::PG::Translator.

=over

=item translator

The WeBWorK::PG::Translator object used to render the problem.

=item head_text

HTML code for the E<lt>headE<gt> block of an resulting web page. Used for
JavaScript features.

=item body_text

HTML code for the E<lt>bodyE<gt> block of an resulting web page.

=item answers

An C<AnswerHash> object containing submitted answers, and results of answer
evaluation.

=item result

A hash containing the results of grading the problem.

=item state

A hash containing the new problem state.

=item errors

A string containing any errors encountered while rendering the problem.

=item warnings

A string containing any warnings encountered while rendering the problem.

=item flags

A hash containing PG_flags (see the Translator docs).

=back

=head1 OPERATION

WeBWorK::PG goes through the following operations when constructed:

=over

=item Get database information

Retrieve information about the current user, set, and problem from the
database.

=item Create a translator

Instantiate a WeBWorK::PG::Translator object.

=item Set the directory hash

Set the translator's directory hash (courseScripts, macros, templates, and temp
directories) from the course environment.

=item Evaluate PG modules

Using the module list from the course environment (pg->modules), perform a
"use"-like operation to evaluate modules at runtime.

=item Set the problem environment

Use data from the user, set, and problem, as well as the course environemnt and
translation options, to set the problem environment.

=item Initialize the translator

Call &WeBWorK::PG::Translator::initialize. What more do you want?

=item Load PG.pl and dangerousMacros.pl

These macros must be loaded without opcode masking, so they are loaded here.

=item Set the opcode mask

Set the opcode mask to the default specified by WeBWorK::PG::Translator.

=item Load the problem source

Give the problem source to the translator.

=item Install a safety filter

The safety filter is used to preprocess student input before evaluation. The
default safety filter, &WeBWorK::PG::safetyFilter, is used.

=item Translate the problem source

Call &WeBWorK::PG::Translator::translate to render the problem source into the
format given by the display mode.

=item Process student answers

Use form field inputs to evaluate student answers.

=item Load the problem state

Use values from the database to initialize the problem state, so that the
grader will have a point of reference.

=item Determine an entry order

Use the ANSWER_ENTRY_ORDER flag to determine the order of answers in the
problem. This is important for problems with dependancies among parts.

=item Install a grader

Use the PROBLEM_GRADER_TO_USE flag, or a default from the course environment,
to install a grader.

=item Grade the problem

Use the selected grader to grade the problem.

=back

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

=cut
