package WeBWork::PG;

# hide PG::* from the not-yet-insane.

use strict;
use warnings;
use WeBWorK::Utils qw(readFile formatDateTime);
use WeBWorK::DB::Classlist;
use WeBWorK::DB::WW;
use WeBWorK::PG::Translator;

sub new($$$$$$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	
	my $courseEnv = shift;
	my $userName = shift;
	my $setName = shift;
	my $problemNumber = shift;
	my $formData = shift;
	
	# get database information
	my $classlist = WeBWorK::DB::Classlist->new($courseEnv);
	my $wwdb = WeBWorK::DB::WW->new($courseEnv);
	my $user = $classlist->getUser($userName);
	my $set = $wwdb->getSet($userName, $setName);
	my $problem = $wwdb->getProblem($userName, $setName, $problemNumber);
	my $psvn = $wwdb->getPSVN($userName, $setName);
	
	# create a Translator
	my $translator = WeBWorK::PG::Translator->new;
	
	# give it a directory hash
	$translator->rh_directories({
		courseScriptsDirectory => $courseEnv->{webworkDirs}->{macros},
		macroDirectory         => $courseEnv->{courseDirs}->{macros},
		templateDirectory      => $courseEnv->{courseDirs}->{templates},
		tempDirectory          => $courseEnv->{courseDirs}->{html_temp},
	});
	
	# give it modules to evaluate
	# give it "extra packages" to load
	my $modules = $courseEnv->{pg}->{modules};
	foreach $module (keys %$modules) {
		my $main_package_loaded = 0;
		foreach $package (@{$modules->{$module}}) {
			if ($package eq $module) {
				# this is the main package
				$translator->evaluate_modules($package);
				$main_package_loaded = 1;
			} else {
				# this is an "extra" package
				if ($main_package_loaded) {
					$translator->load_extra_packages($package);
				} else {
				warn "Can't load extra package $package: module $module hasn't been evaluated.";
				}

			}
		}
	}
	
	# give it an environment (from defineProblemEnvir)
	$translator->environment(
		defineProblemEnvir($courseEnv, $user, $set, $problem, $psvn, $formData)
	);
	
	# initialize it
	$translator->initialize();
	
	# have it "unrestricted load" PG.pl and dangerousMacros.pl
	my $pg_pl = $courseEnv->{webworkDirs}->{macros} . "/PG.pl";
	my $dangerousMacros_pl = $courseEnv->{webworkDirs}->{macros} . "/dangerousMacros.pl"
	my $err = $translator->unrestricted_load($pg_pl);
	warn "Error while loading $pg_pl: $err" if $err;
	$err = $translator->unrestricted_load($dangerousMacros_pl);
	warn "Error while loading $dangerousMacros_pl: $err" if $err;
	
	# give it an opcode mask (using default values)
	$translator->set_mask();
	
	# give it the problem source
	my $sourceFile = $courseEnv->{courseDirs}->{templates}."/".$problem->source_file;
	$translator->source_string(readFile($sourceFile));
	
	# install a safety filter (&safetyFilter)
	$translator->rf_safety_filter(\&safetyFilter);
	
	# translate the PG source into text
	$translator->translate();
	
	# install a grader
	my $grader = $courseEnv->{pg}->{grader};
	$translator->rf_problem_grader(\&FIXME); # *** need a coderef!
	
	# process student answers (if any)
	$translator->process_answers($formData);
	
	# a PG object is a REFERENCE to a Translator object
	return bless \$translator, $class;
}

# -----

sub defineProblemEnvir($$$$$$) {
	my $courseEnv = shift;
	my $user = shift;
	my $set = shift;
	my $problem = shift;
	my $psvn = shift;
	my $form = shift;
	
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
	$envir{displayMode}       = $form->param('Mode');
	$envir{languageMode}      = $envir{displayMode};	 
	$envir{outputMode}        = $envir{displayMode};	 
	$envir{displayHintsQ}     = $form->param('ShowHint');	 
	$envir{displaySolutionsQ} = $form->param('ShowSol');
	$envir{externalTTHPath}   = $courseEnv->{externalPrograms}->{tth};
	
	# Problem Information
	# ADDED: courseName
	
	$envir{openDate}            = $set->open_date;
	$envir{formattedOpenDate}   = formatDateTime $envir{openDate};
	$envir{dueDate}             = $set->due_date;
	$envir{formattedDueDate}    = formatDateTime $envir{dueDate};
	$envir{answerDate}          = $set->answer_date;
	$envir{formattedAnswerDate} = formatDateTime $envir{answerDate};
	$envir{numOfAttempts}       = $problem->num_correct + $problem->num_incorrect;
	$envir{problemValue}        = $problem->value;
	$envir{sessionKey}          = $form->param('key');
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
	$envir{studentID}        = $user->student_id
	
	# Answer Information
	
	$envir{inputs_ref}          = {}; # *** keys like "Answer1"
	$envir{refSubmittedAnswers} = {}; # *** keys like "AnSwEr1"
	
	# Default values for evaluating answers
	
	my $ansEvalDefaults = $courseEnv->{pg}->{ansEvalDefaults};
	$envir{$_} = $ansEvalDefaults->{$_} foreach (keys %$ansEvalDefaults);
	
	# Directories and URLs
	# REMOVED: courseName
	
	$envir{cgiDirectory}           = undef;
	$envir{cgiURL}                 = undef;
	$envir{classDirectory}         = undef;
	$envir{courseScriptsDirectory} = $courseEnv->{webworkDirs}->{macros};
	$envir{htmlDirectory}          = $courseEnv->{courseDirs}->{html};
	$envir{htmlURL}                = $courseEnv->{courseURLs}->{html};
	$envir{macroDirectory}         = $courseEnv->{courseDirs}->{macros};
	$envir{templateDirectory}      = $courseEnv->{courseDirs}->{templates};
	$envir{tempDirectory}          = $courseEnv->{courseDirs}->{html_temp};
	$envir{tempURL}                = $courseEnv->{courseURLs}->{html_temp};
	$envir{scriptDirectory}        = undef;
	$envir{webworkDocsURL}         = $courseEnv->{webworkURLs}->{docs};
	
	return \%envir;
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
