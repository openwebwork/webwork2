#!/usr/local/bin/perl -w 

# Copyright (C) 2001 Michael Gage 

###############################################################################
# The initial code simply initializes variables, defines addresses
# for directories, defines some simple subroutines responders used in debugging
# and makes sure that the appropriate CPAN library modules
# are available.  The main code begins below that with the initialization
# of the PGtranslator5 module. 
###############################################################################

# use lib '/home/gage/webwork/pg/lib';
# use lib '/home/gage/webwork/webwork-modperl/lib';

package WebworkWebservice::RenderProblem;
use WebworkWebservice;
use base qw(WebworkWebservice); 


BEGIN { 
	$main::VERSION = "2.1"; 
}



use strict;
use sigtrap;
use Carp;
use Safe;
use Apache;
use WeBWorK::CourseEnvironment;
use WeBWorK::PG::Translator;
use WeBWorK::DB;
use WeBWorK::Constants;
use WeBWorK::Utils;
use WeBWorK::PG::IO;
use WeBWorK::PG::ImageGenerator;
use Benchmark;
use MIME::Base64 qw( encode_base64 decode_base64);

print "rereading Webwork\n";


our $WW_DIRECTORY = $WebworkWebservice::WW_DIRECTORY;
our $PG_DIRECTORY = $WebworkWebservice::PG_DIRECTORY;
our $COURSENAME   = $WebworkWebservice::COURSENAME;
our $HOST_NAME    = $WebworkWebservice::HOST_NAME;
our $HOSTURL      ="$HOST_NAME:11002"; #FIXME
our $ce           =$WebworkWebservice::SeedCE;

#print "\$ce = \n", WeBWorK::Utils::pretty_print_rh($ce);

print "webwork is realy ready\n\n";
#other services
# File variables
my $WARNINGS='';


# imported constants

my $COURSE_TEMP_DIRECTORY 	= 	$ce->{courseDirs}->{html_tmp};
my $COURSE_TEMP_URL 		= 	$HOSTURL.$ce->{courseURLs}->{html_tmp};

my $pgMacrosDirectory 		= 	$ce->{pg_dir}.'/macros/';      
my $macroDirectory			=	$ce->{courseDirs}->{macros}.'/'; 
my $templateDirectory		= 	$ce->{courseDirs}->{templates}; 

my %PG_environment          =   $ce->{pg}->{specialPGEnvironmentVars};


use constant DISPLAY_MODES => {
	# display name   # mode name
	tex           => "TeX",
	plainText     => "HTML",
	formattedText => "HTML_tth",
	images        => "HTML_dpng",
	jsMath	      => "HTML_jsMath",
	asciimath     => "HTML_asciimath",
};

use constant DISPLAY_MODE_FAILOVER => {
		TeX            => [],
		HTML           => [],
		HTML_tth       => [ "HTML", ],
		HTML_dpng      => [ "HTML_tth", "HTML", ],
		HTML_jsMath    => [ "HTML_dpng", "HTML_tth", "HTML", ],
		HTML_asciimath => [ "HTML_dpng", "HTML_tth", "HTML", ],
		# legacy modes -- these are not supported, but some problems might try to
		# set the display mode to one of these values manually and some macros may
		# provide rendered versions for these modes but not the one we want.
		Latex2HTML  => [ "TeX", "HTML", ],
		HTML_img    => [ "HTML_dpng", "HTML_tth", "HTML", ],
};
	



###############################################################################
# Initialize renderProblem
###############################################################################




my $displayMode					=	'HTML_dpng';

my $PG_PL 						= 	"${pgMacrosDirectory}/PG.pl";
my $DANGEROUS_MACROS_PL			= 	"${pgMacrosDirectory}/dangerousMacros.pl";
my $IO_PL			            = 	"${pgMacrosDirectory}/IO.pl";
my @MODULE_LIST					= ( "Exporter", "DynaLoader", "GD", "WWPlot", "Fun", 
										"Circle", "Label", "PGrandom", "Units", "Hermite", 
										"List", "Match","Multiple", "Select", "AlgParser", 
										"AnswerHash", "Fraction", "VectorField", "Complex1", 
										"Complex", "MatrixReal1", "Matrix","Distributions",
										"Regression"
								);
my @EXTRA_PACKAGES				= ( 	"AlgParserWithImplicitExpand", "Expr", 
										"ExprWithImplicitExpand", "AnswerEvaluator", 
#										"AnswerEvaluatorMaker"  
								);
my $INITIAL_MACRO_PACKAGES 		=  <<END_OF_TEXT;
	DOCUMENT();
	loadMacros(
		"PGbasicmacros.pl",
		"PGchoicemacros.pl",
		"PGanswermacros.pl",
		"PGnumericalmacros.pl",
		"PGgraphmacros.pl",
		"PGauxiliaryFunctions.pl",
		"PGmatrixmacros.pl",
		"PGstatisticsmacros.pl",
		"PGcomplexmacros.pl",
		);
	
	ENDDOCUMENT();

END_OF_TEXT

###############################################################################
#
###############################################################################

###############################################################################
###############################################################################

#print STDERR "ok so far reading file /u/gage/xmlrpc/daemon/Webwork.pm\n";

		

###############################################################################
# The following code initializes an instantiation of the translator in the 
# parent process.  This initialized object is then shared with each of the 
# children forked from this parent process by the daemon.
#
# As far as I can tell, the child processes don't share any variable values even
# though their namespaces are the same.
###############################################################################


my $dummy_envir = {	courseScriptsDirectory 	=> 	$pgMacrosDirectory,
					displayMode 			=>	$displayMode,
					macroDirectory			=> 	$macroDirectory,
					displayModeFailover     =>  DISPLAY_MODE_FAILOVER(),
					externalTTHPath			=>	$ce->{externalPrograms}->{tth},
};
my $pt = new WeBWorK::PG::Translator;  #pt stands for problem translator;
$pt ->rh_directories(	{	courseScriptsDirectory 	=> $pgMacrosDirectory,
                      		macroDirectory			=> $macroDirectory,
                      		scriptDirectory			=> ''	,
                      		templateDirectory		=> $templateDirectory,
                      		tempDirectory			=> $COURSE_TEMP_DIRECTORY,
                      	}
);
$pt -> evaluate_modules( @MODULE_LIST);
#print STDERR "Completed loading of modules, now loading extra packages\n";
$pt -> load_extra_packages( @EXTRA_PACKAGES );
#print STDERR "Completed loading of packages, now loading environment\n";
$pt -> environment($dummy_envir);
#print STDERR "Completed loading environment, next initialize\n";
$pt->initialize();
#print STDERR "Initialized.  \n";
$pt -> unrestricted_load($PG_PL );
$pt -> unrestricted_load($DANGEROUS_MACROS_PL);
$pt -> unrestricted_load($IO_PL);
$pt-> set_mask();
#
#print STDERR "Unrestricted loads completed.\n";

$INITIAL_MACRO_PACKAGES =~ tr /\r/\n/;
$pt->source_string( $INITIAL_MACRO_PACKAGES   );
#print STDERR "source strings read in\n";
$pt ->rf_safety_filter( \&safetyFilter);   # install blank safety filter
$pt ->translate();

print STDERR "New PGtranslator object inititialization completed.\n";
################################################################################
## This ends the initialization of the PGtranslator object
################################################################################



###############################################################################
# This subroutine is called by the child process.  It reinitializes its copy of the 
# PGtranslator5 object.  The unrestricted_load and loadMacros subroutines of PGtranslator5
# have been modified so that if &_PG_init is already defined then nothing
# is read in but the initialization subroutine is run instead.
###############################################################################

sub renderProblem {
    my $rh = shift;
#    warn WebworkWebservice::pretty_print_rh($rh);
    warn "Starting render Problem";
	my $beginTime = new Benchmark;
	$WARNINGS = "";
	my $saveWARN    =  $SIG{__WARN__};
	local $SIG{__WARN__} =\&PG_warnings_handler;
	
	my $envir = $rh->{envir};
 	foreach my $item (keys %PG_environment) {
 		$envir->{$item} = $PG_environment{$item};
 	}
	my $basename = 'equation-'.$envir->{psvn}. '.' .$envir->{probNum};
	$basename .= '.' . $envir->{problemSeed}  if $envir->{problemSeed};
	
	#FIXME  debug line
	#print STDERR "basename is  $basename  and psvn is ", $envir->{psvn};
	my $imagesModeOptions = $ce->{pg}->{displayModeOptions}->{images};

	# Object for generating equation images
    if (  $envir->{displayMode} eq 'HTML_dpng' ) {
            	$envir->{imagegen} = WeBWorK::PG::ImageGenerator->new(
					tempDir         => $ce->{webworkDirs}->{tmp},           # $Global::globalTmpDirectory, # global temp dir
					latex	        => $ce->{externalPrograms}->{latex},    #$envir->{externalLaTeXPath},
 					dvipng          => $ce->{externalPrograms}->{dvipng}, # $envir ->{externalDvipngPath},
					useCache        => 1,
					cacheDir        => $ce->{webworkDirs}->{equationCache},
					cacheURL        => $HOSTURL.$ce->{webworkURLs}->{equationCache},
					cacheDB         => $ce->{webworkFiles}->{equationCacheDB},
					useMarkers      => ($imagesModeOptions->{dvipng_align} && $imagesModeOptions->{dvipng_align} eq 'mysql'),
					dvipng_align    => $imagesModeOptions->{dvipng_align},
					dvipng_depth_db => $imagesModeOptions->{dvipng_depth_db},
				);
	}
   
	$pt->environment($envir);
	#$pt->{safe_cache} = $safe_cmpt_cache;
	$pt->initialize();
	$pt -> unrestricted_load($PG_PL);
	$pt -> unrestricted_load($DANGEROUS_MACROS_PL);
	$pt -> unrestricted_load($IO_PL);
	$pt-> set_mask();
	
	my $string =  decode_base64( $rh ->{source}   );
	$string =~ tr /\r/\n/;
	
	$pt->source_string( $string   );
    $pt ->rf_safety_filter( \&safetyFilter);   # install blank safety filter
    $pt ->translate();
    
    # HTML_dpng, on the other hand, uses an ImageGenerator. We have to
	# render the queued equations.
	if ($envir->{imagegen}) {
		my $sourceFile = 'foobar'; #$ce->{courseDirs}->{templates} . "/" . $problem->source_file;
		my %mtimeOption = -e $sourceFile
			? (mtime => (stat $sourceFile)[9])
			: ();
		
		$envir->{imagegen}->render(
			refresh => 1,
			%mtimeOption,
		);
	}

    # Determine which problem grader to use
	#$pt->rf_problem_grader($pt->rf_std_problem_grader);  #this is the default
    my $problem_grader_to_use = $pt->rh_flags->{PROBLEM_GRADER_TO_USE};

    if ( defined($problem_grader_to_use) and $problem_grader_to_use   ) {  # if defined and non-empty
    	if ($problem_grader_to_use eq 'std_problem_grader') {
    	  # Reset problem grader to standard problem grader.
    		$pt->rf_problem_grader($pt->rf_std_problem_grader);
    	} elsif ($problem_grader_to_use eq 'avg_problem_grader') {
    	  # Reset problem grader to average problem grader.
            $pt->rf_problem_grader($pt->rf_avg_problem_grader);
    	} elsif (ref($problem_grader_to_use) eq 'CODE') {
          # Set problem grader to instructor defined problem grader -- use cautiously.
    		$pt->rf_problem_grader($problem_grader_to_use)
    	} else {
    	    warn "Error:  Could not understand problem grader flag $problem_grader_to_use";
    		#this is the default set by the translator and used if the flag is not understood
    		#$pt->rf_problem_grader($pt->rf_std_problem_grader);
    	}

    } else {#this is the default set by the translator and used if no flag is set.
    	$pt->rf_problem_grader($pt->rf_std_problem_grader);   
    }
    
    # creates and stores a hash of answer results: $rh_answer_results
	$pt -> process_answers($rh->{envir}->{inputs_ref});


    $pt->rh_problem_state({ recorded_score 			=> $rh->{problem_state}->{recorded_score},
    						num_of_correct_ans		=> $rh->{problem_state}->{num_of_correct_ans} ,
    						num_of_incorrect_ans	=> $rh->{problem_state}->{num_of_incorrect_ans}
    					} );
	my %PG_FLAGS = $pt->h_flags;
    my $ra_answer_entry_order = ( defined($PG_FLAGS{ANSWER_ENTRY_ORDER}) ) ?
	                      $PG_FLAGS{ANSWER_ENTRY_ORDER} : [ keys %{$pt->rh_evaluated_answers} ] ;
    my  $answers_submitted = 0;
        $answers_submitted = 1 if defined( $rh->{answer_form_submitted} ) and 1 == $rh->{answer_form_submitted};

    my ($rh_problem_result,$rh_problem_state) = $pt->grade_problem( answers_submitted => $answers_submitted,
                                                                 ANSWER_ENTRY_ORDER => $ra_answer_entry_order
                                                               );       # grades the problem.
    # protect image data for delivery via XML-RPC.
    # Don't send code data.
    my %PG_flag=();
    	
    if($rh->{envir}->{displayMode} eq 'HTML_dpng') {
		my $forceRefresh=1;
#		if($inputs{'refreshCachedImages'} || $main::refreshCachedImages
#			 || $displaySolutionsQ || $displayHintsQ) {
#			$forceRefresh=1;
#		}
#		$imgen->render('refresh'=>$forceRefresh); # Can force new images
	}

	my $out = { 	
 					text 						=> encode_base64( ${$pt ->r_text()}  ),
 	                header_text 				=> encode_base64( ${ $pt->r_header } ),
 	                answers 					=> $pt->rh_evaluated_answers,
 	                errors         				=> $pt-> errors(),
 	                WARNINGS	   				=> encode_base64($WARNINGS ),
	                problem_result 				=> $rh_problem_result,
	                problem_state				=> $rh_problem_state,
	                PG_flag						=> \%PG_flag
	};
	local $SIG{__WARN__} = $saveWARN;
	my $endTime = new Benchmark;
	$out->{compute_time} = logTimingInfo($beginTime, $endTime);
	
	# Hack to filter out CODE references
	foreach my $ans (keys %{$out->{answers}}) {
		foreach my $item (keys %{$out->{answers}->{$ans}}) {
		    my $contents = $out->{answers}->{$ans}->{$item};
			if (ref($contents) =~ /CODE/ ) {
				#warn "removing code at $ans $item ";
			     $out->{answers}->{$ans}->{$item} = undef;
			}
		}
	
	}
	#warn WebworkWebservice::pretty_print_rh($pt->rh_evaluated_answers);
	$out;
	         
}

###############################################################################
# This ends the main subroutine executed by the child process in responding to 
# a request.  The other subroutines are auxiliary.
###############################################################################


sub safetyFilter {
	    my $answer = shift;  # accepts one answer and checks it
	    my $submittedAnswer = $answer;
		$answer = '' unless defined $answer;
		my ($errorno, $answerIsCorrectQ);
		$answer =~ tr/\000-\037/ /;
   #### Return if answer field is empty ########
		unless ($answer =~ /\S/) {
#			$errorno = "<BR>No answer was submitted.";
            $errorno = 0;  ## don't report blank answer as error
			
			return ($answer,$errorno);
			}
  
   ######### Return if  forbidden characters are found 
		unless ($answer =~ /^[a-zA-Z0-9_\-\+ \t\/@%\*\.\n^\[\]\(\)\,\|]+$/ )  {
			$answer =~ tr/a-zA-Z0-9_\-\+ \t\/@%\*\.\n^\(\)/#/c;
			$errorno = "<BR>There are forbidden characters in your answer: $submittedAnswer<BR>";
			
			return ($answer,$errorno);
			}
		
		$errorno = 0;
		return($answer, $errorno);
}


sub logTimingInfo{
    my ($beginTime,$endTime,) = @_;
    my $out = "";
    $out .= Benchmark::timestr( Benchmark::timediff($endTime , $beginTime) );
    $out;
}
######################################################################
sub PG_warnings_handler {
	my @input = @_;
	my $msg_string = longmess(@_);
	my @msg_array = split("\n",$msg_string);
	my $out_string = '';

	# Extra stack information is provided in this next block
	# If the warning message does NOT end in \n then a line
	# number is appended (see Perl manual about warn function)
	# The presence of the line number is detected below and extra
	# stack information is added.
	# To suppress the line number and the extra stack information
	# add \n to the end of a warn message (in .pl files.  In .pg
	# files add ~~n instead

	
	if (@msg_array) {   # if there are more details
		$out_string .= "##More details.  The calling sequence is: <BR>\n";
		foreach my $line (@msg_array) {
			chomp($line);
			next unless $line =~/\w+\:\:/;
			$out_string .= "----" .$line . "<BR>\n";
		}
	}

	$WARNINGS .="*  " . join("<BR>",@input) . "<BR>\n" . $out_string .
						"<BR>\n--------------------------------------<BR>\n<BR>\n";
}

my $CarpLevel = 0;  # How many extra package levels to skip on carp.
my $MaxEvalLen = 0; # How much eval '...text...' to show. 0 = all.
sub longmess {
		my $error = shift;
		my $mess = "";
		my $i = 1 + $CarpLevel;
		my ($pack,$file,$line,$sub,$eval,$require);

		while (($pack,$file,$line,$sub,undef,undef,$eval,$require) = caller($i++)) {
			if ($error =~ m/\n$/) {
				$mess .= $error;
			}
			else {
				if (defined $eval) {
					if ($require) {
						$sub = "require $eval";
					}
					else {
						$eval =~ s/[\\\']/\\$&/g;
						if ($MaxEvalLen && length($eval) > $MaxEvalLen) {
							substr($eval,$MaxEvalLen) = '...';
						}
						$sub = "eval '$eval'";
					}
				}
				elsif ($sub eq '(eval)') {
					$sub = 'eval {...}';
				}

				$mess .= "\t$sub " if $error eq "called";
				$mess .= "$error at $file line $line\n";
			}

			$error = "called";
		}

		$mess || $error;
}

######################################################################


sub pretty_print_rh {
	my $rh = shift;
	my $out = "";
	my $type = ref($rh);
	if ( ref($rh) =~/HASH/ ) {
 		foreach my $key (sort keys %{$rh})  {
 			$out .= "  $key => " . pretty_print_rh( $rh->{$key} ) . "\n";
 		}
	} elsif ( ref($rh) =~ /SCALAR/ ) {
		$out = "scalar reference ". ${$rh};
	} elsif ( ref($rh) =~/Base64/ ) {
		$out .= "base64 reference " .$$rh;
	} else {
		$out =  $rh;
	}
	if (defined($type) ) {
		$out .= "type = $type \n";
	}
	return $out;
}

######################################################################

sub defineProblemEnvir {
	my (
		$self,
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
	# ADDED: displayModeFailover, displayHintsQ, displaySolutionsQ,
	#        refreshMath2img, texDisposition
	
	$envir{psvn}                = $set->psvn;
	$envir{psvnNumber}          = $envir{psvn};
	$envir{probNum}             = $problem->problem_id;
	$envir{questionNumber}      = $envir{probNum};
	$envir{fileName}            = $problem->source_file;	 
	$envir{probFileName}        = $envir{fileName};		 
	$envir{problemSeed}         = $problem->problem_seed;
	$envir{displayMode}         = translateDisplayModeNames($options->{displayMode});
	$envir{languageMode}        = $envir{displayMode};	 
	$envir{outputMode}          = $envir{displayMode};	 
	$envir{displayHintsQ}       = $options->{showHints};	 
	$envir{displaySolutionsQ}   = $options->{showSolutions};
	$envir{texDisposition}      = "pdf"; # in webwork2, we use pdflatex
	
	# Problem Information
	# ADDED: courseName, formatedDueDate
	
	$envir{openDate}            = $set->open_date;
	$envir{formattedOpenDate}   = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone});
	$envir{dueDate}             = $set->due_date;
	$envir{formattedDueDate}    = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone});
	$envir{formatedDueDate}     = $envir{formattedDueDate}; # typo in many header files
	$envir{answerDate}          = $set->answer_date;
	$envir{formattedAnswerDate} = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone});
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
	# ADDED: jsMathURL
	# ADDED: asciimathURL
	
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
	$envir{localHelpURL}           = $ce->{webworkURLs}->{local_help}."/";
	$envir{jsMathURL}	           = $ce->{webworkURLs}->{jsMath};
	$envir{asciimathURL}	       = $ce->{webworkURLs}->{asciimath};
	
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
	
	# to make grabbing these options easier, we'll pull them out now...
	my %imagesModeOptions = %{$ce->{pg}->{displayModeOptions}->{images}};
	
	# Object for generating equation images
	$envir{imagegen} = WeBWorK::PG::ImageGenerator->new(
		tempDir  => $ce->{webworkDirs}->{tmp}, # global temp dir
		latex	 => $envir{externalLaTeXPath},
		dvipng   => $envir{externalDvipngPath},
		useCache => 1,
		cacheDir => $ce->{webworkDirs}->{equationCache},
		cacheURL => $ce->{webworkURLs}->{equationCache},
		cacheDB  => $ce->{webworkFiles}->{equationCacheDB},
		useMarkers      => ($imagesModeOptions{dvipng_align} && $imagesModeOptions{dvipng_align} eq 'mysql'),
		dvipng_align    => $imagesModeOptions{dvipng_align},
		dvipng_depth_db => $imagesModeOptions{dvipng_depth_db},
	);

	#  ADDED: jsMath options
	$envir{jsMath} = {%{$ce->{pg}{displayModeOptions}{jsMath}}};
	
	# Other things...
	$envir{QUIZ_PREFIX}              = $options->{QUIZ_PREFIX}; # used by quizzes
	$envir{PROBLEM_GRADER_TO_USE}    = $ce->{pg}->{options}->{grader};
	$envir{PRINT_FILE_NAMES_FOR}     = $ce->{pg}->{specialPGEnvironmentVars}->{PRINT_FILE_NAMES_FOR};

        #  ADDED: __files__
        #    an array for mapping (eval nnn) to filenames in error messages
	$envir{__files__} = {
	  root => $ce->{webworkDirs}{root},     # used to shorten filenames
	  pg   => $ce->{pg}{directories}{root}, # ditto
	  tmpl => $ce->{courseDirs}{templates}, # ditto
	};
	
	# variables for interpreting capa problems and other things to be
        # seen in a pg file
	my $specialPGEnvironmentVarHash = $ce->{pg}->{specialPGEnvironmentVars};
	for my $SPGEV (keys %{$specialPGEnvironmentVarHash}) {
		$envir{$SPGEV} = $specialPGEnvironmentVarHash->{$SPGEV};
	}
	
	return \%envir;
}





1;
