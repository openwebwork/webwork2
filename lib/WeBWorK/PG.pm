package WeBWorK::PG;

# hide PG::* from the not-yet-insane.
# "PG Render" or something

use strict;
use warnings;
use WeBWorK::Utils qw(readFile formatDateTime);
use WeBWorK::DB::Classlist;
use WeBWorK::DB::WW;
use WeBWorK::PG::Translator;

sub new($$$$$$$$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my (
		$courseEnv,
		$userName,
		$key,
		$setName,
		$problemNumber,
		$translationOptions, # hashref containing options for the
		                     # translator, such as whether to show
				     # hints and the display mode to use
		$formFields, # in CGI::Vars format
	) = @_;
	
	# get database information
	my $classlist = WeBWorK::DB::Classlist->new($courseEnv);
	my $wwdb = WeBWorK::DB::WW->new($courseEnv);
	my $user = $classlist->getUser($userName);
	my $set = $wwdb->getSet($userName, $setName);
	my $problem = $wwdb->getProblem($userName, $setName, $problemNumber);
	my $psvn = $wwdb->getPSVN($userName, $setName);
	
	# create a Translator
	warn "PG: creating a Translator\n";
	my $translator = WeBWorK::PG::Translator->new;
	
	# set the directory hash
	warn "PG: setting the directory hash\n";
	$translator->rh_directories({
		courseScriptsDirectory => $courseEnv->{webworkDirs}->{macros},
		macroDirectory         => $courseEnv->{courseDirs}->{macros},
		templateDirectory      => $courseEnv->{courseDirs}->{templates},
		tempDirectory          => $courseEnv->{courseDirs}->{html_temp},
	});
	
	# evaluate modules and "extra packages"
	warn "PG: evaluating modules and \"extra packages\"\n";
	my @modules = @{ $courseEnv->{pg}->{modules} };
	foreach my $module_packages (@modules) {
		# the first item in $module_packages is the main package
		$translator->evaluate_modules(shift @$module_packages);
		# the remaining items are "extra" packages
		$translator->load_extra_packages(@$module_packages);
	}
	
	# set the environment (from defineProblemEnvir)
	warn "PG: setting the environment (from defineProblemEnvir)\n";
	$translator->environment(defineProblemEnvir(
		$courseEnv, $user, $key, $set, $problem, $psvn, $formFields, $translationOptions));
	
	# initialize the Translator
	warn "PG: initializing the Translator\n";
	$translator->initialize();
	
	# load PG.pl and dangerousMacros.pl using unrestricted_load
	# i'd like to change this at some point to have the same sort of interface to global.conf
	# that the module loading does -- have a list of macros to load unrestrictedly.
	warn "PG: loading PG.pl and dangerousMacros.pl using unrestricted_load\n";
	my $pg_pl = $courseEnv->{webworkDirs}->{macros} . "/PG.pl";
	my $dangerousMacros_pl = $courseEnv->{webworkDirs}->{macros} . "/dangerousMacros.pl";
	my $err = $translator->unrestricted_load($pg_pl);
	warn "Error while loading $pg_pl: $err" if $err;
	$err = $translator->unrestricted_load($dangerousMacros_pl);
	warn "Error while loading $dangerousMacros_pl: $err" if $err;
	
	# set the opcode mask (using default values)
	warn "PG: setting the opcode mask (using default values)\n";
	$translator->set_mask();
	
	# store the problem source
	warn "PG: storing the problem source\n";
	my $sourceFile = $courseEnv->{courseDirs}->{templates}."/".$problem->source_file;
	$translator->source_string(readFile($sourceFile));
	
	# install a safety filter (&safetyFilter)
	warn "PG: installing a safety filter\n";
	$translator->rf_safety_filter(\&safetyFilter);
	
	# translate the PG source into text
	warn "PG: translating the PG source into text\n";
	$translator->translate();
	
	# [in Problem.pm and processProblem8.pl, "install a grader" is here]
	
	# process student answers
	warn "PG: processing student answers\n";
	$translator->process_answers($formFields);
	
	# retrieve the problem state and give it to the translator
	warn "PG: retrieving the problem state and giving it to the translator\n";
	$translator->rh_problem_state({
		recorded_score =>       $problem->status,
		num_of_correct_ans =>   $problem->num_correct,
		num_of_incorrect_ans => $problem->num_incorrect,
	});
	
	# determine an entry order -- the ANSWER_ENTRY_ORDER flag is built by
	# the PG macro package (PG.pl)
	warn "PG: determining an entry order\n";
	my @answerOrder =
		$translator->rh_flags->{ANSWER_ENTRY_ORDER}
			? @{ $translator->rh_flags->{ANSWER_ENTRY_ORDER} }
			: keys %{ $translator->rh_evaluated_answers };
	
	# install a grader -- use the one specified in the problem,
	# or fall back on the default from the course environment.
	# (two magic strings are accepted, to avoid having to
	# reference code when it would be difficult.)
	warn "PG: installing a grader\n";
	my $grader = $translator->rh_flags->{PROBLEM_GRADER_TO_USE}
		|| $courseEnv->{pg}->{options}->{grader};
	$grader = $translator->rf_std_problem_grader
		if $grader eq "std_problem_grader";
	$grader = $translator->rf_avg_problem_grader
		if $grader eq "avg_problem_grader";
	die "Problem grader $grader is not a CODE reference."
		unless ref $grader eq "CODE";
	$translator->rf_problem_grader($grader);
	
	# grading the problem
	warn "PG: grade the problem\n";
	my ($result, $state) = $translator->grade_problem(
		answers_submitted  => $translationOptions->{processAnswers},
		ANSWER_ENTRY_ORDER => \@answerOrder,
	);
	
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
		errors     => $translator->errors, # *** what is this doing?
		warnings   => undef, # *** gotta catch warnings eventually...
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
	# ADDED: displayHintsQ, displaySolutionsQ, externalTTHPath
	
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
	
	# Problem Information
	# ADDED: courseName
	
	$envir{openDate}            = $set->open_date;
	$envir{formattedOpenDate}   = formatDateTime($envir{openDate});
	$envir{dueDate}             = $set->due_date;
	$envir{formattedDueDate}    = formatDateTime($envir{dueDate});
	$envir{answerDate}          = $set->answer_date;
	$envir{formattedAnswerDate} = formatDateTime($envir{answerDate});
	$envir{numOfAttempts}       = $problem->num_correct + $problem->num_incorrect;
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
	# REMOVED: refSubmittedAnswers (alledgedly unused, causes errors)
	
	$envir{inputs_ref}          = $formFields;
	
	# External Programs
	$envir{externalTTHPath}      = $courseEnv->{externalPrograms}->{tth};
	$envir{externalMath2imgPath} = $courseEnv->{externalPrograms}->{math2img};
	
	# Directories and URLs
	# REMOVED: courseName
	
	$envir{cgiDirectory}           = undef;
	$envir{cgiURL}                 = undef;
	$envir{classDirectory}         = undef;
	$envir{courseScriptsDirectory} = $courseEnv->{webworkDirs}->{macros}."/";
	$envir{htmlDirectory}          = $courseEnv->{courseDirs}->{html}."/";
	$envir{htmlURL}                = $courseEnv->{courseURLs}->{html};
	$envir{macroDirectory}         = $courseEnv->{courseDirs}->{macros}."/";
	$envir{templateDirectory}      = $courseEnv->{courseDirs}->{templates}."/";
	$envir{tempDirectory}          = $courseEnv->{courseDirs}->{html_temp}."/";
	$envir{tempURL}                = $courseEnv->{courseURLs}->{html_temp};
	$envir{scriptDirectory}        = undef;
	$envir{webworkDocsURL}         = $courseEnv->{webworkURLs}->{docs};
	
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
	# Return if  forbidden characters are found
	unless ($answer =~ /^[a-zA-Z0-9_\-\+ \t\/@%\*\.\n^\(\)]+$/ )  {
		$answer =~ tr/a-zA-Z0-9_\-\+ \t\/@%\*\.\n^\(\)/#/c;
		$errorno = "<BR>There are forbidden characters in your answer: $submittedAnswer<BR>";
		return ($answer,$errorno);
	}
	$errorno = 0;
	return($answer, $errorno);
}

1;
