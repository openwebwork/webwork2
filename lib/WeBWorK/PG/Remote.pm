################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::PG::Remote;

=head1 NAME

WeBWorK::PG::Remote - Use the WeBWorK::PG API to invoke a remote problem
renderer via XML-RPC.

=cut

use strict;
use warnings;
use XMLRPC::Lite;
use WeBWorK::Utils qw(readFile formatDateTime writeTimingLogEntry);

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
	
	# READ SOURCE FILE
	
	my $sourceFile = $problem->source_file;
	$sourceFile = $ce->{courseDirs}->{templates}."/".$sourceFile
		unless ($sourceFile =~ /^\//);
	my $source = eval { readFile($sourceFile) };
	if ($@) {
		# well, we couldn't get the problem source, for some reason.
		return bless {
			translator => undef,
			head_text  => "",
			body_text  => <<EOF,
WeBWorK::Utils::readFile($sourceFile) says:
$@
EOF
			answers    => {},
			result     => {},
			state      => {},
			errors     => "Failed to read the problem source file.",
			warnings   => "",
			flags      => {error_flag => 1},
		}, $class;
	}
	
	# DEFINE REQUEST
	
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
	
	my (@modules_to_load, @extra_packages_to_load);
	my @modules = @{ $ce->{pg}->{modules} };
	foreach my $module_packages_ref (@modules) {
		my ($module, @extra_packages) = @$module_packages_ref;
		# the first item is the main package
		push @modules_to_load, $module;
		# the remaining items are "extra" packages
		push @extra_packages_to_load, @extra_packages;
	}
	
	my $request = {
		course                 => $ce->{courseName},
		source                 => $source,
		modules_to_evaluate    => [ @modules_to_load ],
		extra_packages_to_load => [ @extra_packages_to_load ],
		envir                  => $envir,
		problem_state          => [
			recorded_score       => $problem->status,
			num_of_correct_ans   => $problem->num_correct,
			num_of_incorrect_ans => $problem->num_incorrect,
		],
	};
	
	# CALL REMOTE RENDERER
	
	my $package = __PACKAGE__;
	my $uri = $ce->{pg}->{renderers}->{$package}->{uri};
	warn "uri=$uri\n";
	my $rpc = XMLRPC::Lite->proxy($uri);
	my $result = $rpc->call("renderProblem", $request);
	
	# HANDLE ERRORS
	
	if ($result->fault) {
		return bless {
			translator => undef,
			head_text  => "",
			body_text  => $result->faultstring,
			answers    => {},
			result     => {},
			state      => {},
			errors     => "Failed to call the remote renderer."
				. " (error" . $result->faultcode . ")",
			warnings   => "",
			flags      => {error_flag => 1},
		}, $class;
	}
	
	# GATHER RESULTS
	
	return bless {
		translator => undef,
		head_text  => "",
		body_text  => $result->result,
		answers    => {},
		result     => {},
		state      => {},
		errors     => "Here is the result:",
		warnings   => "",
		flags      => {error_flag => 1},
	}, $class;
	
	# return an object which contains the translator and the results of
	# the translation process. this is DIFFERENT from the "format expected
	# by Webwork.pm (and I believe processProblem8, but check.)"
	#return bless {
	#	translator => $translator,
	#	head_text  => ${ $translator->r_header },
	#	body_text  => ${ $translator->r_text   },
	#	answers    => $translator->rh_evaluated_answers,
	#	result     => $result,
	#	state      => $state,
	#	errors     => $translator->errors,
	#	warnings   => $warnings,
	#	flags      => $translator->rh_flags,
	#}, $class;
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

=head1 SYNOPSIS

 $pg = WeBWorK::PG->new(
	 $ce,  # a WeBWorK::CourseEnvironment object
	 $user,       # a WeBWorK::DB::Record::User object
	 $sessionKey,
	 $set,        # a WeBWorK::DB::Record::UserSet object
	 $problem,    # a WeBWorK::DB::Record::UserProblem object
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

a WeBWorK::DB::Record::UserProblem object. The contents of the source_file
field can specify a PG file either by absolute path or path relative to the
"templates" directory. I<The caller should remove taint from this value before
passing!>

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
even if the PG source has not been updated. FIXME: change the name of this
option to "refreshEquations" and update the docs accordingly.

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
