################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::PG::Local;

=head1 NAME

WeBWorK::PG::Local - Use the WeBWorK::PG API to invoke a local
WeBWorK::PG::Translator object.

=head1 DESCRIPTION

WeBWorK::PG::Local encapsulates the PG translation process, making multiple
calls to WeBWorK::PG::Translator. Much of the flexibility of the Translator is
hidden, instead making choices that are appropriate for the webwork-modperl
system

It implements the WeBWorK::PG interface and uses a local
WeBWorK::PG::Translator to perform problem rendering. See the documentation for
the WeBWorK::PG module for information about the API.

=cut

use strict;
use warnings;
use File::Path qw(rmtree);
use WeBWorK::PG::ImageGenerator;
use WeBWorK::PG::Translator;
use WeBWorK::Utils qw(readFile formatDateTime writeTimingLogEntry makeTempDirectory);

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my (
		$ce,
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
	writeTimingLogEntry($ce, "WeBWorK::PG::new",
		"user=".$user->user_id.",problem=".$ce->{courseName}."/".$set->set_id."/".$problem->problem_id.",mode=".$translationOptions->{displayMode},
		"begin");
	
	# install a local warn handler to collect warnings
	my $warnings = "";
	local $SIG{__WARN__} = sub { $warnings .= shift }
		if $ce->{pg}->{options}->{catchWarnings};
	
	# create a Translator
	#warn "PG: creating a Translator\n";
	my $translator = WeBWorK::PG::Translator->new;
	
	# set the directory hash
	#warn "PG: setting the directory hash\n";
	$translator->rh_directories({
		courseScriptsDirectory => $ce->{pg}->{directories}->{macros},
		macroDirectory         => $ce->{courseDirs}->{macros},
		templateDirectory      => $ce->{courseDirs}->{templates},
		tempDirectory          => $ce->{courseDirs}->{html_temp},
	});
	
	# evaluate modules and "extra packages"
	#warn "PG: evaluating modules and \"extra packages\"\n";
	my @modules = @{ $ce->{pg}->{modules} };
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
		$ce,
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
		my $macroPath = $ce->{pg}->{directories}->{macros} . "/$_";
		my $err = $translator->unrestricted_load($macroPath);
		warn "Error while loading $macroPath: $err" if $err;
	}
	
	# set the opcode mask (using default values)
	#warn "PG: setting the opcode mask (using default values)\n";
	$translator->set_mask();
	
	# store the problem source
	#warn "PG: storing the problem source\n";
	my $sourceFile = $problem->source_file;
	$sourceFile = $ce->{courseDirs}->{templates}."/".$sourceFile
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
	
	# write timing log entry -- the translator is now all set up
	writeTimingLogEntry($ce, "WeBWorK::PG::new",
		"initialized",
		"intermediate");
	
	# translate the PG source into text
	#warn "PG: translating the PG source into text\n";
	$translator->translate();
	
	# after we're done translating, we may have to clean up after the
	# translator:
	
	# for example, HTML_img mode uses a tempdir for dvipng's temp files.\
	# We have to remove it.
	if ($envir->{dvipngTempDir}) {
		rmtree($envir->{dvipngTempDir}, 0, 0);
	}
	
	# HTML_dpng, on the other hand, uses an ImageGenerator. We have to
	# render the queued equations.
	if ($envir->{imagegen}) {
		my $sourceFile = $ce->{courseDirs}->{templates} . "/" . $problem->source_file;
		my %mtimeOption = -e $sourceFile
			? (mtime => (stat $sourceFile)[9])
			: ();
		
		$envir->{imagegen}->render(
			refresh => $translationOptions->{refreshMath2img},
			%mtimeOption,
		);
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
			|| $ce->{pg}->{options}->{grader};
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
	writeTimingLogEntry($ce, "WeBWorK::PG::new", "", "end");
	
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

sub defineProblemEnvir {
	my (
		$ce,
		$user,
		$key,
		$set,
		$problem,
		$psvn,
		$formFields,
		$options,
	) = @_;
	
	my %envir;
	
	# ----------------------------------------------------------------------
	
	# PG environment variables
	# from docs/pglanguage/pgreference/environmentvariables as of 06/25/2002
	# any changes are noted by "ADDED:" or "REMOVED:"
	
	# Vital state information
	# ADDED: displayHintsQ, displaySolutionsQ, refreshMath2img,
	#        texDisposition
	
	$envir{psvn}              = $set->psvn;
	$envir{psvnNumber}        = $envir{psvn};
	$envir{probNum}           = $problem->problem_id;
	$envir{questionNumber}    = $envir{probNum};
	$envir{fileName}          = $problem->source_file;	 
	$envir{probFileName}      = $envir{fileName};		 
	$envir{problemSeed}       = $problem->problem_seed;
	$envir{displayMode}       = translateDisplayModeNames($options->{displayMode});
	$envir{languageMode}      = $envir{displayMode};	 
	$envir{outputMode}        = $envir{displayMode};	 
	$envir{displayHintsQ}     = $options->{showHints};	 
	$envir{displaySolutionsQ} = $options->{showSolutions};
	# FIXME: this is HTML_img specific
	#$envir{refreshMath2img}   = $options->{refreshMath2img};
	$envir{texDisposition}    = "pdf"; # in webwork-modperl, we use pdflatex
	
	# Problem Information
	# ADDED: courseName, formatedDueDate
	
	$envir{openDate}            = $set->open_date;
	$envir{formattedOpenDate}   = formatDateTime($envir{openDate});
	$envir{dueDate}             = $set->due_date;
	$envir{formattedDueDate}    = formatDateTime($envir{dueDate});
	$envir{formatedDueDate}     = $envir{formattedDueDate}; # typo in many header files
	$envir{answerDate}          = $set->answer_date;
	$envir{formattedAnswerDate} = formatDateTime($envir{answerDate});
	$envir{numOfAttempts}       = ($problem->num_correct || 0) + ($problem->num_incorrect || 0);
	$envir{problemValue}        = $problem->value;
	$envir{sessionKey}          = $key;
	$envir{courseName}          = $ce->{courseName};
	
	# Student Information
	# ADDED: studentID
	
	$envir{sectionName}      = $user->section;
	$envir{sectionNumber}    = $envir{sectionName};
	$envir{recitationName}   = $user->recitation;
	$envir{recitationNumber} = $envir{recitationName};
	$envir{setNumber}        = $set->set_id;
	$envir{studentLogin}     = $user->user_id;
	$envir{studentName}      = $user->first_name . " " . $user->last_name;
	$envir{studentID}        = $user->student_id;
	
	# Answer Information
	# REMOVED: refSubmittedAnswers
	
	$envir{inputs_ref} = $formFields;
	
	# External Programs
	# ADDED: externalLaTeXPath, externalDvipngPath,
	#        externalGif2EpsPath, externalPng2EpsPath
	
	$envir{externalTTHPath}      = $ce->{externalPrograms}->{tth};
	$envir{externalLaTeXPath}    = $ce->{externalPrograms}->{latex};
	$envir{externalDvipngPath}   = $ce->{externalPrograms}->{dvipng};
	$envir{externalGif2EpsPath}  = $ce->{externalPrograms}->{gif2eps};
	$envir{externalPng2EpsPath}  = $ce->{externalPrograms}->{png2eps};
	$envir{externalGif2PngPath}  = $ce->{externalPrograms}->{gif2png};
	
	# Directories and URLs
	# REMOVED: courseName
	# ADDED: dvipngTempDir
	
	$envir{cgiDirectory}           = undef;
	$envir{cgiURL}                 = undef;
	$envir{classDirectory}         = undef;
	$envir{courseScriptsDirectory} = $ce->{pg}->{directories}->{macros}."/";
	$envir{htmlDirectory}          = $ce->{courseDirs}->{html}."/";
	$envir{htmlURL}                = $ce->{courseURLs}->{html}."/";
	$envir{macroDirectory}         = $ce->{courseDirs}->{macros}."/";
	$envir{templateDirectory}      = $ce->{courseDirs}->{templates}."/";
	$envir{tempDirectory}          = $ce->{courseDirs}->{html_temp}."/";
	$envir{tempURL}                = $ce->{courseURLs}->{html_temp}."/";
	$envir{scriptDirectory}        = undef;
	$envir{webworkDocsURL}         = $ce->{webworkURLs}->{docs}."/";
	# FIXME: this is HTML_img mode-specific
	#$envir{dvipngTempDir}          = $options->{displayMode} eq 'images'
	#	? makeTempDirectory($envir{tempDirectory}, "webwork-dvipng")
	#	: undef;
	
	# Information for sending mail
	
	$envir{mailSmtpServer} = $ce->{mail}->{smtpServer};
	$envir{mailSmtpSender} = $ce->{mail}->{smtpSender};
	$envir{ALLOW_MAIL_TO}  = $ce->{mail}->{allowedRecipients};
	
	# Default values for evaluating answers
	
	my $ansEvalDefaults = $ce->{pg}->{ansEvalDefaults};
	$envir{$_} = $ansEvalDefaults->{$_} foreach (keys %$ansEvalDefaults);
	
	# ----------------------------------------------------------------------
	
	my $basename = "equation-$envir{psvn}.$envir{probNum}";
	$basename .= ".$envir{problemSeed}" if $envir{problemSeed};
		
	# Object for generating equation images
	$envir{imagegen} = WeBWorK::PG::ImageGenerator->new(
		tempDir  => $ce->{webworkDirs}->{tmp}, # global temp dir
		dir	 => $envir{tempDirectory},
		url	 => $envir{tempURL},
		basename => $basename,
		latex	 => $envir{externalLaTeXPath},
		dvipng   => $envir{externalDvipngPath},
	);
	
	# Other things...
	$envir{QUIZ_PREFIX}              = $options->{QUIZ_PREFIX}; # used by quizzes
	$envir{PROBLEM_GRADER_TO_USE}    = $ce->{pg}->{options}->{grader};
	$envir{PRINT_FILE_NAMES_FOR}     = $ce->{pg}->{specialPGEnvironmentVars}->{PRINT_FILE_NAMES_FOR};
	
	# variables for interpreting capa problems.
	$envir{CAPA_Tools}               = $ce->{pg}->{specialPGEnvironmentVars}->{CAPA_Tools};
	$envir{CAPA_MCTools}             = $ce->{pg}->{specialPGEnvironmentVars}->{CAPA_MCTools};
	$envir{CAPA_Graphics_URL}        = $ce->{pg}->{specialPGEnvironmentVars}->{CAPA_Graphics_URL};
	$envir{CAPA_GraphicsDirectory}   = $ce->{pg}->{specialPGEnvironmentVars}->{CAPA_GraphicsDirectory};
	
	return \%envir;
}

sub translateDisplayModeNames($) {
	my $name = shift;
	return {
		tex           => "TeX",
		plainText     => "HTML",
		formattedText => "HTML_tth",
		images        => "HTML_dpng", # "HTML_img",
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
	unless ($answer =~ /^[a-zA-Z0-9_\-\+ \t\/@%\*\.\n^\[\]\(\)\,\|]+$/ )  {
		$answer =~ tr/a-zA-Z0-9_\-\+ \t\/@%\*\.\n^\(\)/#/c;
		$errorno = "<BR>There are forbidden characters in your answer: $submittedAnswer<BR>";
		return ($answer,$errorno);
	}
	$errorno = 0;
	return($answer, $errorno);
}

1;

__END__

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
