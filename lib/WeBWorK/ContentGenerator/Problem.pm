package WeBWorK::ContentGenerator::Problem;
our @ISA = qw(WeBWorK::ContentGenerator);

use strict;
use warnings;
use lib '/home/malsyned/xmlrpc/daemon';
use lib '/Users/gage/webwork-modperl/lib';
use PGtranslator5;
use WeBWorK::ContentGenerator;
use Apache::Constants qw(:common);

###############################################################################
# Configuration
###############################################################################
my $USER_DIRECTORY = '/Users/gage';
my $COURSE_SCRIPTS_DIRECTORY = "$USER_DIRECTORY/webwork/system/courseScripts/";
my $MACRO_DIRECTORY 	= 	"$USER_DIRECTORY/webwork-modperl/courses/demoCourse/templates/macros/";
my $TEMPLATE_DIRECTORY 	= 	"$USER_DIRECTORY/rochester_problib/";
my $TEMP_URL   			=	"http://127.0.0.1/~gage/rochester_problibtmp/";
##my $HTML_DIRECTORY 		= 	"/Users/gage/Sites/rochester_problib/"  #already obtained from courseEnvironment
my $HTML_URL 			=	"http://127.0.0.1/~gage/rochester_problib/";
my $TEMP_DIRECTORY = ""; # has to be here... for now

###############################################################################
# End configuration
###############################################################################

sub title {
	my ($self, $problem_set, $problem) = @_;
	my $r = $self->{r};
	my $user = $r->param('user');
	return "Problem $problem of problem set $problem_set for $user";
}

###############################################################################
#
# INITIALIZATION  
#
# The following code initializes an instantiation of PGtranslator5 in the 
# parent process.  This initialized object is then share with each of the 
# children forked from this parent process by the daemon.
#
# As far as I can tell, the child processes don't share any variable values even
# though their namespaces are the same.
###############################################################################
#  First some dummy values to use for testing.
#  These should be available from the problemEnvironment(it might be ok to assume that PG and dangerousMacros
#  live in the courseScripts (system level macros) directory.

#print STDERR "Begin intitalization\n";
my $dummy_envir = {	courseScriptsDirectory 	=> 	$COURSE_SCRIPTS_DIRECTORY,
					displayMode 			=>	'HTML_tth',
					macroDirectory			=> 	$MACRO_DIRECTORY,
					cgiURL					=>	'foo_cgiURL'};


my $PG_PL 						= 	"${COURSE_SCRIPTS_DIRECTORY}PG.pl";
my $DANGEROUS_MACROS_PL			= 	"${COURSE_SCRIPTS_DIRECTORY}dangerousMacros.pl";
my @MODULE_LIST					= ( 	"Exporter", "DynaLoader", "GD", "WWPlot", "Fun", 
										"Circle", "Label", "PGrandom", "Units", "Hermite", 
										"List", "Match","Multiple", "Select", "AlgParser", 
										"AnswerHash", "Fraction", "VectorField", "Complex1", 
										"Complex", "MatrixReal1", "Matrix","Distributions",
										"Regression"
);
my @EXTRA_PACKAGES				= ( 	"AlgParserWithImplicitExpand", "Expr", 
										"ExprWithImplicitExpand", "AnswerEvaluator", 

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
				"PGcomplexmacros.pl",
				"PGstatisticsmacros.pl"
		
		);
		
		TEXT("Hello world");
		
			ENDDOCUMENT();
				
END_OF_TEXT
	
#These here documents have their drawbacks.  KEEP END_OF_TEXT left justified!!!!!!	

###############################################################################
# Now to define the body subroutine which does the hard work.
###############################################################################


#my $SOURCE1 = $INITIAL_MACRO_PACKAGES;

sub body {
	my ($self, $problem_set, $problem) = @_;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');
	
	my $rh = {}; # this needs to be set to a hash containing CGI params
	
	
	my $SOURCE1 = readFile("$problem_set/$problem.pg");
	print STDERR "SOURCEFILE: \n$SOURCE1\n\n";
	
	###########################################################################
	#  The pg problem class should have a method for installing it's problemEnvironment
	###########################################################################
	
	my $problemEnvir_rh = defineProblemEnvir($self);
	

	##################################################################################
	#  Prime the PGtranslator object and set it loose
	##################################################################################
	

	###############################################################################
			
	###############################################################################
	#Create the PG translator.
	###############################################################################
	
	my $pt = new PGtranslator5;  #pt stands for problem translator;
	
	
	# All of these hard coded directories need to be drawn from courseEnvironment.
	# In addition I don't think that PGtranslator uses this stack internally yet.
	# Passing these directories through the problemEnvironment variable is what
	# is currently being done, but I don't think it is quite right, at least for most
	# of them.
	
	
	$pt ->rh_directories(	{	courseScriptsDirectory 	=> $COURSE_SCRIPTS_DIRECTORY,
								macroDirectory			=> $MACRO_DIRECTORY,
									,
								templateDirectory		=> $TEMPLATE_DIRECTORY,
								tempDirectory			=> $TEMP_DIRECTORY,
							}
	);
	
	###############################################################################
	# First we load the modules from courseScripts directory.
	# These do the "heavy lifting" in terms of formatting, creating graphs, and
	# performing other heavy duty algorithms.
	#
	###############################################################################
	
	$pt -> evaluate_modules( @MODULE_LIST);
	$pt -> load_extra_packages( @EXTRA_PACKAGES );
	
	###############################################################################
	# Load the environment constants.  Some are used by the PGtranslator object but
	# most of them are installed inside the Safe compartment where the problem
	# runs.
	###############################################################################
	#$pt -> environment($dummy_envir);
	$pt -> environment($problemEnvir_rh);
	
	
	# I've forgotten what this does exactly :-)
	$pt->initialize();
	
	###############################################################################
	# PG.pl contains the basic code which defines the problem interface, input and output.
	# dangerousMacros.pl contains subroutines which have access to the hard drive and 
	# and the directory structure.  All use of external resources by the problem is supposed
	# to go through these subroutines.  The idea is to put the potentially dangerous
	# algorithms in on place so they can be watched closely.
	# These two files are evaluated in the Safe compartment without any restrictions.
	# They have full use of the perl commands.
	###############################################################################
	 my $loadErrors    = $pt -> unrestricted_load($PG_PL );
	 print STDERR "$loadErrors\n" if ($loadErrors);
	 $loadErrors = $pt -> unrestricted_load($DANGEROUS_MACROS_PL);
	 print STDERR "$loadErrors\n" if ($loadErrors);
	
	###############################################################################
	# Now set the mask to restrict the operations which can be performed within
	# a problem or a macro file.
	###############################################################################
	 $pt-> set_mask();
	 
	#	print  "\nPG.pl: $PG_PL<br>\n";
	#	print  "DANGEROUS_MACROS_PL: $DANGEROUS_MACROS_PL<br>\n";
	#	print  "Print dummy environment<br>\n";
	#	print  pretty_print_rh($dummy_envir), "<p>\n\n";
	
	# Read in the source code for the problem
	
	 #$INITIAL_MACRO_PACKAGES =~ tr /\r/\n/;  # change everything to unix line endings.
	 $SOURCE1 =~ tr /\r/\n/;
	 #print STDERR "Source again \n $SOURCE1";
	 $pt->source_string( $SOURCE1   );
	
	###############################################################################
	# Install a safety filter for screening student answers.  The default is now the blank
	# filter since the answer evaluators do a pretty good job of recompiling and screening
	# student's answers.  Still, you could prohibit back ticks, or something of the kind.
	###############################################################################
	
	 $pt ->rf_safety_filter( \&safetyFilter);   # install blank safety filter
	
	
	print STDERR "New PGtranslator object inititialization completed.<br>\n";
	################################################################################
	## This ends the initialization of the PGtranslator object
	################################################################################
	
	
	################################################################################
	# Run the problem (output the html text) but also store it within the object.
	# The correct answers are also calculated and stored within the object
	################################################################################
	 $pt ->translate();
	
	#print problem output
	print "Problem goes here<p>\n";
	print "Problem output <br>\n";
	print "################################################################################<br><br>";
	print ${$pt->r_text()};
	print "<br><br>################################################################################<br>";
	print "<p>End of problem output<br>";
	
	
	#print source code
	print "Source code<pre>\n";
	print $SOURCE1;
	print "</pre>End source code<p>";
	################################################################################
	# The format for the output is described here.  We'll need a local variable
	# to handle the warnings.  From within the problem the warning command
	# has been slaved to the __WARNINGS__  routine which is defined in Global.
	# We'll need to provide an alternate mechanism.
	# The base64 encoding is only needed for xml transmission.
	################################################################################
	print "################################################################################<br>";
	print "Warnings output<br>";
	my $WARNINGS = "Let this be a warning:";
	
	print $WARNINGS;
	
	################################################################################
	# Install the standard problem grader.  See gage/xmlrpc/daemon.pm or processProblem8 for detailed
	# code on how to choose which problem grader to install, depending on courseEnvironment and problem data.
	# See also PG.pl which provides for problem by problem overrides.
	################################################################################
	
	$pt->rf_problem_grader($pt->rf_std_problem_grader);
	
	################################################################################
	# creates and stores a hash of answer results inside the object: $rh_answer_results
	################################################################################
	$pt -> process_answers($rh->{envir}->{inputs_ref});
	
	
	# THE UPDATE AND GRADING LOGIC COULD USE AN OVERHAUL.  IT WAS SOMEWHAT CONSTRAINED
	# BY LEGACY CONDITIONS IN THE ORIGINAL PROCESSPROBLEM8.  IT'S NOT BAD
	# BUT IT COULD PROBABLY BE MADE A LITTLE MORE STRAIGHT FORWARD.
	################################################################################
	# updates the problem state stored by the translator object from the problemEnvironment data
	################################################################################
	
	# $pt->rh_problem_state({ recorded_score 			=> $rh->{problem_state}->{recorded_score},
	# 						num_of_correct_ans		=> $rh->{problem_state}->{num_of_correct_ans} ,
	# 						num_of_incorrect_ans	=> $rh->{problem_state}->{num_of_incorrect_ans}
	# 					} );
	################################################################################
	# grade the problem (and update the problem state again.)
	################################################################################
	
	# Define an entry order -- the default is the order they are received from the browser.
	# (Which as I understand it is NOT guaranteed to be the Left->Right Up-> Down order we're
	# used to in the West.
	
	my %PG_FLAGS = $pt->h_flags;
		my $ra_answer_entry_order = ( defined($PG_FLAGS{ANSWER_ENTRY_ORDER}) ) ?
							  $PG_FLAGS{ANSWER_ENTRY_ORDER} : [ keys %{$pt->rh_evaluated_answers} ] ;
	# Decide whether any answers were submitted.
		my  $answers_submitted = 0;
			$answers_submitted = 1 if defined( $rh->{answer_form_submitted} ) and 1 == $rh->{answer_form_submitted};
	# If there are answers, grade them
		my ($rh_problem_result,$rh_problem_state) = $pt->grade_problem( answers_submitted => $answers_submitted,
																	 ANSWER_ENTRY_ORDER => $ra_answer_entry_order
																   );       # grades the problem.
	  
	# Output format expected by Webwork.pm (and I believe processProblem8, but check.)
	my $out = { 	
					text 						=> ${$pt ->r_text()}, #  encode_base64( ${$pt ->r_text()}  ),
					header_text 				=> $pt->r_header,     # encode_base64( ${ $pt->r_header } ),
					answers 					=> $pt->rh_evaluated_answers,
					errors         				=> $pt-> errors(),
					WARNINGS	   				=> $WARNINGS,          #encode_base64($WARNINGS ),
					problem_result 				=> $rh_problem_result,
					problem_state				=> $rh_problem_state,
					PG_flag						=> \%PG_FLAGS
			   };
	##########################################################################################
	# Debugging printout of environment tables
	##########################################################################################
	
	print "<P>Request item<P>\n\n";
	print "<TABLE border=\"3\">";
	print $self->print_form_data('<tr><td>','</td><td>','</td></tr>');
	print "</table>\n";
	print "path info <br>\n";
	print $r->path_info();
	print "<P>\n\ncourseEnvironment<P>\n\n";
	print pretty_print_rh($courseEnvironment);	 
	print "<P>\n\nproblemEnvironment<P>\n\n";
	print pretty_print_rh($problemEnvir_rh);

	##########################################################################################
	# End
	##########################################################################################
		"";
}
#  End the"body" routine for the Problem object.


sub safetyFilter {
	    my $answer = shift;  # accepts one answer and checks it
	    my $submittedAnswer = $answer;
		$answer = '' unless defined $answer;
		my ($errorno);
		$answer =~ tr/\000-\037/ /;
   #### Return if answer field is empty ########
		unless ($answer =~ /\S/) {
#			$errorno = "<BR>No answer was submitted.";
            $errorno = 0;  ## don't report blank answer as error

			return ($answer,$errorno);
			}
   ######### replace ^ with **    (for exponentiation)
   # 	$answer =~ s/\^/**/g;
   ######### Return if  forbidden characters are found
		unless ($answer =~ /^[a-zA-Z0-9_\-\+ \t\/@%\*\.\n^\(\)]+$/ )  {
			$answer =~ tr/a-zA-Z0-9_\-\+ \t\/@%\*\.\n^\(\)/#/c;
			$errorno = "<BR>There are forbidden characters in your answer: $submittedAnswer<BR>";

			return ($answer,$errorno);
			}

		$errorno = 0;
		return($answer, $errorno);
}




########################################################################################
# This is the problemEnvironment structure that needs to be filled out in order to  provide
# information to PGtranslator which in turn supports the problem environment
########################################################################################

sub defineProblemEnvir {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
    my %envir=();
#    $envir{'refSubmittedAnswers'}  =   $refSubmittedAnswers if defined($refSubmittedAnswers);
     $envir{'psvnNumber'}	   		=   123456789;
  	$envir{'psvn'}		   			=	123456789;
 	 $envir{'studentName'}	   		=   'Jane Doe';
	$envir{'studentLogin'}	    	=	'jd001m';
	$envir{'studentID'}	    		=	'xxx-xx-4321';
	$envir{'sectionName'}	    	=	'gage';
	$envir{'sectionNumber'}	    	=	'111foobar';
	$envir{'recitationName'}	    =	'gage_recitation';
	$envir{'recitationNumber'}	    =	'11_foobar recitation';
	$envir{'setNumber'}	    		=	'setAlgebraicGeometry';
	$envir{'questionNumber'}      	=	43;
	$envir{'probNum'} 	    		=	43;
	$envir{'openDate'}	    		=	3014438528;
	$envir{'formattedOpenDate'}    	=	'3/4/02';
	$envir{'dueDate'} 	    		=	4014438528;
	$envir{'formattedDueDate'}     	=	'10/4/04';
	$envir{'answerDate'}	    	=	4014438528;
	$envir{'formattedAnswerDate'}  	=	'10/4/04';
	$envir{'problemValue'}	    	=	1;
	$envir{'fileName'}	    		=	'problem1';
	$envir{'probFileName'}	    	=	'problem1';
	$envir{'languageMode'}	    	=	'HTML_tth';
	$envir{'displayMode'}	    	=	'HTML_tth';
	$envir{'outputMode'}	    	=	'HTML_tth';
 	$envir{'courseName'}	    	=	$courseEnvironment ->{courseName};
	$envir{'sessionKey'}	    	=	'asdf';

#	initialize constants for PGanswermacros.pl
	$envir{'numRelPercentTolDefault'} 	=     .1;
	$envir{'numZeroLevelDefault'}		=     1E-14;
	$envir{'numZeroLevelTolDefault'} 	=     1E-12;
	$envir{'numAbsTolDefault'} 			=     .001;
	$envir{'numFormatDefault'}			=     '';
	$envir{'functRelPercentTolDefault'} =     .1;
	$envir{'functZeroLevelDefault'} 	=     1E-14;
	$envir{'functZeroLevelTolDefault'} 	=     1E-12;
	$envir{'functAbsTolDefault'} 		=     .001;
	$envir{'functNumOfPoints'} 			=     3;
	$envir{'functVarDefault'} 			=     'x';
	$envir{'functLLimitDefault'} 		=     .0000001;
	$envir{'functULimitDefault'} 		=     .9999999;
	$envir{'functMaxConstantOfIntegration'} = 1E8;
#	kludge check definition of number of attempts again. The +1 is because this is used before the current answer is evaluated.
	$envir{'numOfAttempts'}             =    2; #&getProblemNumOfCorrectAns($probNum,$psvn)
	                                            # &getProblemNumOfIncorrectAns($probNum,$psvn)+1;

# 
# 
# 	defining directorys and URLs
 	$envir{'templateDirectory'}   		=	$courseEnvironment ->{courseDirs}->{templates};
############	$envir{'classDirectory'}   			=	$Global::classDirectory;
#	$envir{'cgiDirectory'}   			=	$Global::cgiDirectory;
#	$envir{'cgiURL'}                    =   getWebworkCgiURL();

# 	$envir{'scriptDirectory'}   		=	$Global::scriptDirectory;##omit
	$envir{'webworkDocsURL'}   			=	'http://webwork.math.rochester.edu';
	$envir{'externalTTHPath'}   		=	'/usr/local/bin/tth';
	

# 
	$envir{'inputs_ref'}                =   $r->param;
 	$envir{'problemSeed'}	   			=   3245;
 	$envir{'displaySolutionsQ'}			= 	1;
 	$envir{'displayHintsQ'}				= 	1;

# Directory values -- do we really need them here? 	
 	$envir{courseScriptsDirectory} 	= $COURSE_SCRIPTS_DIRECTORY;
	$envir{macroDirectory}			= $MACRO_DIRECTORY;
	$envir{templateDirectory}		= $TEMPLATE_DIRECTORY;
	$envir{tempDirectory}			= $TEMP_DIRECTORY;
	$envir{tempURL}					= $TEMP_URL;
	$envir{htmlURL}					= $HTML_URL;
	$envir{'htmlDirectory'}             =   $courseEnvironment ->{courseDirectory}->{html};
	# here is a way to pass environment variables defined in webworkCourse.ph
#	my $k;
#	foreach $k (keys %Global::PG_environment ) {
#		$envir{$k} = $Global::PG_environment{$k};
#	}
	\%envir;
}

########################################################################################
# This recursive pretty_print function will print a hash and its sub hashes.
########################################################################################
sub pretty_print_rh {
    my $r_input = shift;
    my $out = '';
    if ( not ref($r_input) ) {
    	$out = $r_input;    # not a reference
    } elsif (is_hash_ref($r_input)) {
	    local($^W) = 0;
		$out .= "<TABLE border = \"2\" cellpadding = \"3\" BGCOLOR = \"#FFFFFF\">";
		foreach my $key (sort keys %$r_input ) {
			$out .= "<tr><TD> $key</TD><TD>=&gt;</td><td>&nbsp;".pretty_print_rh($r_input->{$key}) . "</td></tr>";
		}
		$out .="</table>";
	} elsif (is_array_ref($r_input) ) {
		my @array = @$r_input;
		$out .= "( " ;
		while (@array) {
			$out .= pretty_print_rh(shift @array) . " , ";
		}
		$out .= " )"; 
	} elsif (ref($r_input) eq 'CODE') {
		$out = "$r_input";
	} else {
		$out = $r_input;
	}
		$out;
}

sub is_hash_ref {
	my $in =shift;
	my $save_SIG_die_trap = $SIG{__DIE__};
    $SIG{__DIE__} = sub {CORE::die(@_) };
	my $out = eval{  %{   $in  }  };
	$out = ($@ eq '') ? 1 : 0;
	$@='';
	$SIG{__DIE__} = $save_SIG_die_trap;
	$out;
}
sub is_array_ref {
	my $in =shift;
	my $save_SIG_die_trap = $SIG{__DIE__};
    $SIG{__DIE__} = sub {CORE::die(@_) };
	my $out = eval{  @{   $in  }  };
	$out = ($@ eq '') ? 1 : 0;
	$@='';
	$SIG{__DIE__} = $save_SIG_die_trap;
	$out;
}

######
# Utility for slurping souce files
#######

sub readFile {
	my $input = shift;    # The set and problem:  'set0/prob1.pg'
	my $filePath =$TEMPLATE_DIRECTORY .$input;
	print STDERR "Reading problem from file  $filePath \n";
	print STDERR "<br>Reading problem from file  $filePath <br>\n";
	my $out;
	print "The file is readable = ", -r $filePath, "\n";
	if (-r $filePath) {
		open IN, "<$filePath" or print STDERR "Hey, this file was supposed to be readable\n";
		local($/)=undef;
		$out = <IN>;
		close(IN);
	} else {
		print "Could not read file at |$filePath|";
		print STDERR "Could not read file at |$filePath|";
	}
	return($out);
}

my $foo =0;

# The warning mechanism.  This needs to be turned into an object of its own
###############
## Error message routines cribbed from CGI
###############

BEGIN {    #error message routines cribbed from CGI

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
}
###############
### Our error messages for giving maximum feedback to the user for errors within problems.
###############
BEGIN {
	sub PG_floating_point_exception_handler {       # 1st argument is signal name
		my($sig) = @_;
		print "Content-type: text/html\n\n<H4>There was a floating point arithmetic error (exception SIG$sig )</H4>--perhaps
		you divided by zero or took the square root of a negative number?
		<BR>\n Use the back button to return to the previous page and recheck your entries.<BR>\n";
		exit(0);
	}
	
	$SIG{'FPE'}  = \&PG_floating_point_exception_handler;
#!/usr/bin/perl  -w
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
		
		if ($input[$#input]=~/line \d*\.\s*$/) {   
			$out_string .= "##More details: <BR>\n----"; 
			foreach my $line (@msg_array) {
				chomp($line);
				next unless $line =~/\w+\:\:/;
				$out_string .= "----" .$line . "<BR>\n";
			}
		}

		$Global::WARNINGS .="*  " . join("<BR>",@input) . "<BR>\n" . $out_string .
		                    "<BR>\n--------------------------------------<BR>\n<BR>\n";
		$Global::background_plain_url = $Global::background_warn_url;
		$Global::bg_color = '#FF99CC';  #for warnings -- this change may come too late
	}

	$SIG{__WARN__}=\&PG_warnings_handler;
	
	$SIG{__DIE__} = sub {
	    my $message = longmess(@_);
	    $message =~ s/\n/<BR>\n/;
	    my ($package, $filename, $line) = caller();
	    # use standard die for errors eminating from XML::Parser::Expat
	    # it uses a trapped eval which sometimes fails -- apparently on purpose
	    # and the error is handled by Expat itself.  We don't want
	    # to interfer with that.
	    
	    if ($package eq 'XML::Parser::Expat') {
	    	die @_;
	    }
	    #print  "$package $filename $line \n";
		print  
		"Content-type: text/html\r\n\r\n <h4>Software error</h4> <p>\n\n$message\n<p>\n
		Please inform the webwork meister.<p>\n
		In addition to the error message above the following warnings were detected:
		<HR>
		$Global::WARNINGS;
		<HR>
		It's sometimes hard to tell exactly what has gone wrong since the
		full error message may have been sent to
		standard error instead of to standard out.
		<p> To debug  you can
		<ul>
		<li> guess what went wrong and try to fix it.
		<li> call the offending script directly from the command line
		of unix
		<li> enable the debugging features by redefining
		\$cgiURL in Global.pm and checking the redirection scripts in
		system/cgi. This will force the standard error to be placed
		in the standard out pipe as well.
		<li> Run tail -f error_log <br>
		from the unix command line to see error messages from the webserver.
		The standard error output is being placed in the error_log file for the apache
		web server.  To run this command you have to be in the directory containing the
		error_log or enter the full path name of the error_log. <p>
		In a standard apache installation, this file is at /usr/local/apache/logs/error_log<p>
		In a RedHat Linux installation, this file is at /var/log/httpd/error_log<p>
		At Rochester this file is at /ww/logs/error_log.
		</ul>
		Good luck.<p>\n" ;
	};



}

1;
