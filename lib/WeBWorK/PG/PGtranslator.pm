package PGtranslator;

use strict;
use warnings;
use Opcode;
use Safe;
use Net::SMTP;
use IOGlue;

use Exporter;
use DynaLoader;

BEGIN {
	sub be_strict {   # allows the use of strict within macro packages.
		require 'strict.pm';
		strict::import();
	}
}

my @class_modules = ();

sub new {
	my $class = shift;
	my $safe_cmpt = new Safe; #('PG_priv');
	my $self = {
		envir => undef,
		PG_PROBLEM_TEXT_ARRAY_REF => [],
		PG_PROBLEM_TEXT_REF => 0,
		PG_HEADER_TEXT_REF => 0,
		PG_ANSWER_HASH_REF => {},
		PG_FLAGS_REF =>	{},
		safe =>  $safe_cmpt,
		safe_compartment_name => $safe_cmpt->root,
		errors => "",
		source => "",
		rh_correct_answers => {},
		rh_student_answers => {},
		rh_evaluated_answers => {},
		rh_problem_result => {},
		rh_problem_state => {
			recorded_score => 0, # the score recorded in the data base
			num_of_correct_ans => 0, # the number of correct attempts at doing the problem
			num_of_incorrect_ans => 0, # the number of incorrect attempts
		},
		rf_problem_grader => \&std_problem_grader,
		rf_safety_filter => \&safetyFilter,
		ra_included_modules => [
			@class_modules
		],
		rh_directories => {},
	};
	bless $self, $class;
}

sub evaluate_modules{
	my $self = shift;
	my @modules = @_;
	# temporary  -
	# We  need a method for setting the course directory without calling Global.
	
	my $courseScriptsDirectory = $self->rh_directories->{courseScriptsDirectory};
	my $save_SIG_die_trap = $SIG{__DIE__};
	local $SIG{__DIE__} = sub {CORE::die(@_) };
	while (@modules) {
		my $module_name = shift @modules;
		$module_name =~ s/\.pm$//;   # remove trailing .pm if someone forgot
		if ($module_name eq 'reset'  or $module_name eq 'erase' ) {
			@class_modules = ();
			next;
		}
		if ( -r  "${courseScriptsDirectory}${module_name}.pm"   ) {
			eval(qq! require "${courseScriptsDirectory}${module_name}.pm";  import ${module_name};! );
			warn "Errors in including the module ${courseScriptsDirectory}$module_name.pm $@" if $@;
		} else {
			eval(qq! require "${module_name}.pm";  import ${module_name};! );
			warn "Errors in including either the module $module_name.pm or ${courseScriptsDirectory}${module_name}.pm $@" if $@;
		}
		push(@class_modules, "\%${module_name}::");
		print STDERR "loading $module_name\n";
	}
	#$SIG{__DIE__} = $save_SIG_die_trap;
}

sub load_extra_packages{
	my $self = shift;
	my @package_list = @_;
	my $package_name;

    foreach $package_name (@package_list) {
        eval(qq! import ${package_name};! );
	    warn "Errors in importing the package $package_name $@" if $@;
        push(@class_modules, "\%${package_name}::");
    }
}

	##############################################################################
	        # SHARE variables and routines with safe compartment
my %shared_subroutine_hash = (
	'&read_whole_problem_file' => 'PGtranslator', #the values are dummies.
	'&convertPath'	=> 'PGtranslator',
	'&surePathToTmpFile' => 'PGtranslator',
	'&fileFromPath' => 'PGtranslator',
	'&directoryFromPath' => 'PGtranslator',
	'&createFile' => 'PGtranslator',
	'&PG_answer_eval' => 'PGtranslator',
	'&PG_restricted_eval' => 'PGtranslator',
	'&be_strict' => 'PGtranslator',
	'&send_mail_to' => 'PGtranslator',
	'&PGsort' => 'PGtranslator',
	'&dumpvar' => 'PGtranslator',
	'&includePGtext' => 'PGtranslator',
);

sub initialize {
    my $self = shift;
    my $safe_cmpt = $self->{safe};
    #print "initializing safeCompartment",$safe_cmpt -> root(), "\n";

    $safe_cmpt -> share(keys %shared_subroutine_hash);
    no strict;
    local(%envir) = %{ $self ->{envir} };
	$safe_cmpt -> share('%envir');
#   local($rf_answer_eval) = sub { $self->PG_answer_eval(@_); };
#   local($rf_restricted_eval) = sub { $self->PG_restricted_eval(@_); };
#   $safe_cmpt -> share('$rf_answer_eval');
#   $safe_cmpt -> share('$rf_restricted_eval');

	use strict;

    # end experiment
    $self->{ra_included_modules} = [@class_modules];
    $safe_cmpt -> share_from('main', $self->{ra_included_modules} ); #$self ->{ra_included_modules}

}

sub environment{
	my $self = shift;
	my $envirref = shift;
	if ( defined($envirref) )  {
		if (ref($envirref) eq 'HASH') {
			%{ $self -> {envir} } = %$envirref;
		} else {
			$self ->{errors} .= "ERROR: The environment method for PG_translate objects requires a reference to a hash";
		}
	}
	$self->{envir} ; #reference to current environment
}

sub mask {
	my $self = shift;
	my $mask = shift;
	my $safe_compartment = $self->{safe};
	$safe_compartment->mask($mask);
}
sub permit {
	my $self = shift;
	my @array = shift;
	my $safe_compartment = $self->{safe};
	$safe_compartment->permit(@array);
}
sub deny {

	my $self = shift;
	my @array = shift;
	my $safe_compartment = $self->{safe};
	$safe_compartment->deny(@array);
}
sub share_from {
	my $self = shift;
	my $pckg_name = shift;
	my $array_ref =shift;
	my $safe_compartment = $self->{safe};
	$safe_compartment->share_from($pckg_name,$array_ref);
}

sub source_string {
	my $self = shift;
	my $temp = shift;
	my $out;
	if ( ref($temp) eq 'SCALAR') {
		$self->{source} = $$temp;
		$out = $self->{source};
	} elsif ($temp) {
		$self->{source} = $temp;
		$out = $self->{source};
	}
	$self -> {source};
}

sub source_file {
	my $self = shift;
	my $filePath = shift;
 	local(*SOURCEFILE);
 	local($/);
 	$/ = undef;   # allows us to treat the file as a single line
 	my $err = "";
 	if ( open(SOURCEFILE, "<$filePath") ) {
 		$self -> {source} = <SOURCEFILE>;
 		close(SOURCEFILE);
 	} else {
 		$self->{errors} .= "Can't open file: $filePath";
 		croak( "Can't open file: $filePath\n" );
 	}



 	$err;
}



sub unrestricted_load {
	my $self = shift;
	my $filePath = shift;
	my $safe_cmpt = $self ->{safe};
	my $store_mask = $safe_cmpt->mask();
	$safe_cmpt->mask(Opcode::empty_opset());
	my $safe_cmpt_package_name = $safe_cmpt->root();
	
	my $macro_file_name = fileFromPath($filePath);
	$macro_file_name =~s/\.pl//;  # trim off the extenstion
	my $export_subroutine_name = "_${macro_file_name}_export";
    my $init_subroutine_name = "_${macro_file_name}_init";
    my $macro_file_loaded;
    my $local_errors = "";
    no strict;
    $macro_file_loaded	= defined(&{"${safe_cmpt_package_name}::$init_subroutine_name"} );
    print STDERR "$macro_file_name   has not yet been loaded\n" unless $macro_file_loaded;	
	unless ($macro_file_loaded) {
		# print "loading $filePath\n";
		## load the $filePath file
		## Using rdo insures that the $filePath file is loaded for every problem, allowing initializations to occur.
		## Ordinary mortals should not be fooling with the fundamental macros in these files.  
		my $local_errors = "";
		if (-r $filePath ) {
			$safe_cmpt -> rdo( "$filePath" ) ; 
			#warn "There were problems compiling the file: $filePath: <BR>--$@" if $@;
			$local_errors ="\nThere were problems compiling the file:\n $filePath\n $@\n" if $@;
			$self ->{errors} .= $local_errors if $local_errors;
			use strict;
		} else {
			$local_errors = "Can't open file $filePath for reading\n";
			$self ->{errors} .= $local_errors if $local_errors;
		}
		$safe_cmpt -> mask($store_mask);
		
	}
	$macro_file_loaded	= defined(&{"${safe_cmpt_package_name}::$init_subroutine_name"} );
	$local_errors .= "\nUnknown error.  Unable to load $filePath\n" if ($local_errors eq '' and not $macro_file_loaded);
	print STDERR "$filePath is properly loaded\n\n" if $macro_file_loaded;
    $local_errors;
}

sub nameSpace {
	my $self = shift;
	$self->{safe}->root;
}

sub a_text {
	my $self  = shift;
    @{$self->{PG_PROBLEM_TEXT_ARRAY_REF}};
}

sub header {
	my $self = shift;
	${$self->{PG_HEADER_TEXT_REF}};
}

sub h_flags {
	my $self = shift;
	%{$self->{PG_FLAGS_REF}};
}

sub rh_flags {
	my $self = shift;
	$self->{PG_FLAGS_REF};
}
sub h_answers{
	my $self = shift;
	%{$self->{PG_ANSWER_HASH_REF}};
}

sub ra_text {
	my $self  = shift;
    $self->{PG_PROBLEM_TEXT_ARRAY_REF};

}

sub r_text {
	my $self  = shift;
    $self->{PG_PROBLEM_TEXT_REF};
}

sub r_header {
	my $self = shift;
	$self->{PG_HEADER_TEXT_REF};
}

sub rh_directories {
	my $self = shift;
	my $rh_directories = shift;
	$self->{rh_directories}=$rh_directories if ref($rh_directories) eq 'HASH';
	$self->{rh_directories};
}

sub rh_correct_answers {
	my $self = shift;
	my @in = @_;
	return $self->{rh_correct_answers} if @in == 0;

	if ( ref($in[0]) eq 'HASH' ) {
		$self->{rh_correct_answers} = { %{ $in[0] } }; # store a copy of the hash
	} else {
		$self->{rh_correct_answers} = { @in }; # store a copy of the hash
	}
	$self->{rh_correct_answers}
}

sub rf_problem_grader {
	my $self = shift;
	my $in = shift;
	return $self->{rf_problem_grader} unless defined($in);
	if (ref($in) =~/CODE/ ) {
		$self->{rf_problem_grader} = $in;
	} else {
		die "ERROR: Attempted to install a problem grader which was not a reference to a subroutine.";
	}
	$self->{rf_problem_grader}
}


sub errors{
	my $self = shift;
	$self->{errors};
}

##############################################################################

	        ## restrict the operations allowed within the safe compartment

sub set_mask {
	my $self = shift;
	my $safe_cmpt = $self ->{safe};
    $safe_cmpt->mask(Opcode::full_opset());  # allow no operations
    $safe_cmpt->permit(qw(   :default ));
    $safe_cmpt->permit(qw(time));  # used to determine whether solutions are visible.
	$safe_cmpt->permit(qw( atan2 sin cos exp log sqrt ));

	# just to make sure we'll deny some things specifically
	$safe_cmpt->deny(qw(entereval));
	$safe_cmpt->deny(qw (  unlink symlink system exec ));
	$safe_cmpt->deny(qw(print require));
}

############################################################################


sub translate {
	my $self = shift;
	my @PROBLEM_TEXT_OUTPUT = ();
	my $safe_cmpt = $self ->{safe};
	my $evalString = $self -> {source};
	$self ->{errors} .= qq{ERROR:  This problem file was empty!\n} unless ($evalString) ;
	$self ->{errors} .= qq{ERROR:  You must define the environment before translating.}
	     unless defined( $self->{envir} );
    # reset the error detection
    my $save_SIG_die_trap = $SIG{__DIE__};
    $SIG{__DIE__} = sub {CORE::die(@_) };

############################################################################


		    ##########################################
		    ###### PG preprocessing code #############
		    ##########################################
		        # BEGIN_TEXT and END_TEXT must occur on a line by themselves.
		        $evalString =~ s/\n\s*END_TEXT[\s;]*\n/\nEND_TEXT\n/g;
		    	$evalString =~ s/\n\s*BEGIN_TEXT[\s;]*\n/\nTEXT\(EV3\(<<'END_TEXT'\)\);\n/g;
		    	$evalString =~ s/ENDDOCUMENT.*/ENDDOCUMENT();/s; # remove text after ENDDOCUMENT

				$evalString =~ s/\\/\\\\/g;    # \ can't be used for escapes because of TeX conflict
		        $evalString =~ s/~~/\\/g;      # use ~~ as escape instead, use # for comments

				my ($PG_PROBLEM_TEXT_REF, $PG_HEADER_TEXT_REF, $PG_ANSWER_HASH_REF, $PG_FLAGS_REF)
				      =$safe_cmpt->reval("   $evalString");

# This section could use some more error messages.  In particular if a problem doesn't produce the right output, the user needs
# information about which problem was at fault.
#
#

				$self->{errors} .= $@;
#		    	push(@PROBLEM_TEXT_OUTPUT   ,   split(/(\n)/,$$PG_PROBLEM_TEXT_REF)  ) if  defined($$PG_PROBLEM_TEXT_REF  );
		    	push(@PROBLEM_TEXT_OUTPUT   ,   split(/^/,$$PG_PROBLEM_TEXT_REF)  ) if  ref($PG_PROBLEM_TEXT_REF  ) eq 'SCALAR';
		    	                                                                 ## This is better than using defined($$PG_PROBLEM_TEXT_REF)
		    	                                                                 ## Because more pleasant feedback is given
		    	                                                                 ## when the problem doesn't render.
		    	 # try to get the \n to appear at the end of the line

        use strict;
        #############################################################################
        ##########  end  EVALUATION code                                  ###########
        #############################################################################

        ##########################################
		###### PG error processing code ##########
		##########################################
        my (@input,$lineNumber,$line);
        if ($self -> {errors}) {
                #($self -> {errors}) =~ s/</&lt/g;
                #($self -> {errors}) =~ s/>/&gt/g;
           #try to clean up errors so they will look ok
                $self ->{errors} =~ s/\[.+?\.pl://gm;   #erase [Fri Dec 31 12:58:30 1999] processProblem7.pl:
                #$self -> {errors} =~ s/eval\s+'(.|[\n|r])*$//;
            #end trying to clean up errors so they will look ok


                push(@PROBLEM_TEXT_OUTPUT   ,  qq!\n<A NAME="problem! .
                    $self->{envir} ->{'probNum'} .
                    qq!"><PRE>        Problem!.
                    $self->{envir} ->{'probNum'}.
                    qq!\nERROR caught by PGtranslator while processing problem file:! .
                	$self->{envir}->{'probFileName'}.
                	"\n****************\r\n" .
                	$self -> {errors}."\r\n" .
                	"****************<BR>\n");

                push(@PROBLEM_TEXT_OUTPUT   , "------Input Read\r\n");
               $self->{source} =~ s/</&lt;/g;
               @input=split("\n", $self->{source});
               $lineNumber = 1;
                foreach $line (@input) {
                    chomp($line);
                    push(@PROBLEM_TEXT_OUTPUT, "$lineNumber\t\t$line\r\n");
                    $lineNumber ++;
                }
                push(@PROBLEM_TEXT_OUTPUT  ,"\n-----<BR></PRE>\r\n");



        }


        ## we need to make sure that the other output variables are defined

                ## If the eval failed with errors, one or more of these variables won't be defined.
                $PG_ANSWER_HASH_REF = {}      unless defined($PG_ANSWER_HASH_REF);
                $PG_HEADER_TEXT_REF = \( "" ) unless defined($PG_HEADER_TEXT_REF);
                $PG_FLAGS_REF = {}            unless defined($PG_FLAGS_REF);

         		$PG_FLAGS_REF->{'error_flag'} = 1 	  if $self -> {errors};
        my $PG_PROBLEM_TEXT                     = join("",@PROBLEM_TEXT_OUTPUT);

        $self ->{ PG_PROBLEM_TEXT_REF	} 		= \$PG_PROBLEM_TEXT;
        $self ->{ PG_PROBLEM_TEXT_ARRAY_REF	} 	= \@PROBLEM_TEXT_OUTPUT;
	    $self ->{ PG_HEADER_TEXT_REF 	}		= $PG_HEADER_TEXT_REF;
	    $self ->{ rh_correct_answers	}		= $PG_ANSWER_HASH_REF;
	    $self ->{ PG_FLAGS_REF			}		= $PG_FLAGS_REF;
	    $SIG{__DIE__} = $save_SIG_die_trap;
	    $self ->{errors};
}  # end translate


sub rh_evaluated_answers {
	my $self = shift;
	my @in = @_;
	return $self->{rh_evaluated_answers} if @in == 0;

	if ( ref($in[0]) eq 'HASH' ) {
		$self->{rh_evaluated_answers} = { %{ $in[0] } }; # store a copy of the hash
	} else {
		$self->{rh_evaluated_answers} = { @in }; # store a copy of the hash
	}
	$self->{rh_evaluated_answers};
}
sub rh_problem_result {
	my $self = shift;
	my @in = @_;
	return $self->{rh_problem_result} if @in == 0;

	if ( ref($in[0]) eq 'HASH' ) {
		$self->{rh_problem_result} = { %{ $in[0] } }; # store a copy of the hash
	} else {
		$self->{rh_problem_result} = { @in }; # store a copy of the hash
	}
	$self->{rh_problem_result};
}
sub rh_problem_state {
	my $self = shift;
	my @in = @_;
	return $self->{rh_problem_state} if @in == 0;

	if ( ref($in[0]) eq 'HASH' ) {
		$self->{rh_problem_state} = { %{ $in[0] } }; # store a copy of the hash
	} else {
		$self->{rh_problem_state} = { @in }; # store a copy of the hash
	}
	$self->{rh_problem_state};
}


sub process_answers{
	my $self = shift;
	my @in = @_;
	my %h_student_answers;
	if (ref($in[0]) eq 'HASH' ) {
		%h_student_answers = %{ $in[0] };  #receiving a reference to a hash of answers
	} else {
		%h_student_answers = @in;          # receiving a hash of answers
	}
	my $rh_correct_answers = $self->rh_correct_answers();
	my @answer_entry_order = ( defined($self->{PG_FLAGS_REF}->{ANSWER_ENTRY_ORDER}) ) ?
	                      @{$self->{PG_FLAGS_REF}->{ANSWER_ENTRY_ORDER}} : keys %{$rh_correct_answers};

 	# apply each instructors answer to the corresponding student answer

 	foreach my $ans_name ( @answer_entry_order ) {
 	    my ($ans, $errors) = $self->filter_answer( $h_student_answers{$ans_name} );
 	    no strict;
 	    # evaluate the answers inside the safe compartment.
 	    local($rf_fun,$temp_ans) = (undef,undef);
 	    if ( defined($rh_correct_answers ->{$ans_name} ) ) {
 	    	$rf_fun  = $rh_correct_answers->{$ans_name};
 	    } else {
 	    	warn "There is no answer evaluator for the question labeled $ans_name";
 	    }
 	    $temp_ans  = $ans;
 	    $temp_ans = '' unless defined($temp_ans);  #make sure that answer is always defined
 	                                              # in case the answer evaluator forgets to check
 	    $self->{safe}->share('$rf_fun','$temp_ans');
 	    
        # reset the error detection
    	my $save_SIG_die_trap = $SIG{__DIE__};
    	$SIG{__DIE__} = sub {CORE::die(@_) };
    	my $rh_ans_evaluation_result;
        if (ref($rf_fun) eq 'CODE' ) {
  	    	$rh_ans_evaluation_result = $self->{safe} ->reval( '&{ $rf_fun }($temp_ans)' ) ;
  	    	warn "Error in PGtranslator.pm::process_answers: Answer $ans_name:<BR>\n $@\n" if $@;
  	    } elsif (ref($rf_fun) eq 'AnswerEvaluator')   {
  	    	$rh_ans_evaluation_result = $self->{safe} ->reval('$rf_fun->evaluate($temp_ans)');
  	    	warn "Error in PGtranslator.pm::process_answers: Answer $ans_name:<BR>\n $@\n" if $@;
  	    	warn "Evaluation error: Answer $ans_name:<BR>\n", $rh_ans_evaluation_result->error_flag(), " :: ",$rh_ans_evaluation_result->error_message(),"<BR>\n" 
  	    	             if defined($rh_ans_evaluation_result)  and defined($rh_ans_evaluation_result->error_flag());
  	    } else {
  	    	warn "Error in PGtranslator5.pm::process_answers: Answer $ans_name:<BR>\n Unrecognized evaluator type |", ref($rf_fun), "|";
  	    }	
  	    
        $SIG{__DIE__} = $save_SIG_die_trap;
        
        
  	    use strict;
  	    unless ( ( ref($rh_ans_evaluation_result) eq 'HASH') or ( ref($rh_ans_evaluation_result) eq 'AnswerHash') ) {
  	    	warn "Error in PGtranslator5.pm::process_answers: Answer $ans_name:<BR>\n
  	    	      Answer evaluators must return a hash or an AnswerHash type, not type |", 
  	    	      ref($rh_ans_evaluation_result), "|";
  	    }
  	    $rh_ans_evaluation_result ->{ans_message} .= "$errors \n" if $errors;
  	    $rh_ans_evaluation_result ->{ans_name} = $ans_name;
  		$self->{rh_evaluated_answers}->{$ans_name} = $rh_ans_evaluation_result;

 	}
 	$self->rh_evaluated_answers;

}

sub grade_problem {
	my $self = shift;
    my %form_options = @_;
	my $rf_grader = $self->{rf_problem_grader};
	($self->{rh_problem_result},$self->{rh_problem_state} )  =
	                  &{$rf_grader}(	$self -> {rh_evaluated_answers},
	                                	$self -> {rh_problem_state},
	                                	%form_options
	                                );

	($self->{rh_problem_result}, $self->{rh_problem_state} ) ;
}

sub rf_std_problem_grader {
    my $self = shift;
	return \&std_problem_grader;
}
sub old_std_problem_grader{
	my $rh_evaluated_answers = shift;
	my %flags = @_;  # not doing anything with these yet
	my %evaluated_answers = %{$rh_evaluated_answers};
	my	$allAnswersCorrectQ=1;
	foreach my $ans_name (keys %evaluated_answers) {
	# I'm not sure if this check is really useful.
	    if (ref($evaluated_answers{$ans_name} ) eq 'HASH' ) {
	   		$allAnswersCorrectQ = 0 unless( 1 == $evaluated_answers{$ans_name}->{score} );
	   	} else {
	   		warn "Error: Answer $ans_name is not a hash";
	   		warn "$evaluated_answers{$ans_name}";
	   	}
	}
	# Notice that "all answers are correct" if there are no questions.
	{ score 			=> $allAnswersCorrectQ,
	  prev_tries 		=> 0,
	  partial_credit 	=> $allAnswersCorrectQ,
	  errors			=>	"",
	  type              => 'old_std_problem_grader',
	  flags				=> {}, # not doing anything with these yet
	};  # hash output

}

#####################################
# This is a model for plug-in problem graders
#####################################

sub std_problem_grader{
	my $rh_evaluated_answers = shift;
	my $rh_problem_state = shift;
	my %form_options = @_;
	my %evaluated_answers = %{$rh_evaluated_answers};
	#  The hash $rh_evaluated_answers typically contains:
	#      'answer1' => 34, 'answer2'=> 'Mozart', etc.

	# By default the  old problem state is simply passed back out again.
	my %problem_state = %$rh_problem_state;


 	# %form_options might include
 	# The user login name
 	# The permission level of the user
 	# The studentLogin name for this psvn.
 	# Whether the form is asking for a refresh or is submitting a new answer.

 	# initial setup of the answer
 	my %problem_result = ( score 				=> 0,
 						   errors 				=> '',
 						   type   				=> 'std_problem_grader',
 						   msg					=> '',
 						 );
 	# Checks

 	my $ansCount = keys %evaluated_answers;  # get the number of answers
 	unless ($ansCount > 0 ) {
 		$problem_result{msg} = "This problem did not ask any questions.";
 		return(\%problem_result,\%problem_state);
 	}

 	if ($ansCount > 1 ) {
 		$problem_result{msg} = 'In order to get credit for this problem all answers must be correct.' ;
 	}

 	unless (defined( $form_options{answers_submitted}) and $form_options{answers_submitted} == 1) {
 		return(\%problem_result,\%problem_state);
 	}

	my	$allAnswersCorrectQ=1;
	foreach my $ans_name (keys %evaluated_answers) {
	# I'm not sure if this check is really useful.
	    if ( ( ref($evaluated_answers{$ans_name} ) eq 'HASH' ) or ( ref($evaluated_answers{$ans_name}) eq 'AnswerHash' ) ) {
	   		$allAnswersCorrectQ = 0 unless( 1 == $evaluated_answers{$ans_name}->{score} );
	   	} else {
	   		warn "Error: Answer $ans_name is not a hash";
	   		warn "$evaluated_answers{$ans_name}";
	   		warn "This probably means that the answer evaluator is for this answer is not working correctly.";
	   		$problem_result{error} = "Error: Answer $ans_name is not a hash: $evaluated_answers{$ans_name}";
	   	}
	}
	# report the results
	$problem_result{score} = $allAnswersCorrectQ;

	# I don't like to put in this bit of code.
	# It makes it hard to construct error free problem graders
	# I would prefer to know that the problem score was numeric.
    unless ($problem_state{recorded_score} =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/ ) {
    	$problem_state{recorded_score} = 0;  # This gets rid of non-numeric scores
    }
    #
	if ($allAnswersCorrectQ == 1 or $problem_state{recorded_score} == 1) {
		$problem_state{recorded_score} = 1;
	} else {
		$problem_state{recorded_score} = 0;
	}

	$problem_state{num_of_correct_ans}++ if $allAnswersCorrectQ == 1;
	$problem_state{num_of_incorrect_ans}++ if $allAnswersCorrectQ == 0;
	(\%problem_result, \%problem_state);
}
sub rf_avg_problem_grader {
    my $self = shift;
	return \&avg_problem_grader;
}
sub avg_problem_grader{
		my $rh_evaluated_answers = shift;
	my $rh_problem_state = shift;
	my %form_options = @_;
	my %evaluated_answers = %{$rh_evaluated_answers};
	#  The hash $rh_evaluated_answers typically contains:
	#      'answer1' => 34, 'answer2'=> 'Mozart', etc.

	# By default the  old problem state is simply passed back out again.
	my %problem_state = %$rh_problem_state;


 	# %form_options might include
 	# The user login name
 	# The permission level of the user
 	# The studentLogin name for this psvn.
 	# Whether the form is asking for a refresh or is submitting a new answer.

 	# initial setup of the answer
 	my	$total=0;
 	my %problem_result = ( score 				=> 0,
 						   errors 				=> '',
 						   type   				=> 'avg_problem_grader',
 						   msg					=> '',
 						 );
    my $count = keys %evaluated_answers;
    $problem_result{msg} = 'You can earn partial credit on this problem.' if $count >1;
    # Return unless answers have been submitted
    unless ($form_options{answers_submitted} == 1) {
 		return(\%problem_result,\%problem_state);
 	}
 	# Answers have been submitted -- process them.
	foreach my $ans_name (keys %evaluated_answers) {
		$total += $evaluated_answers{$ans_name}->{score};
	}
	# Calculate score rounded to three places to avoid roundoff problems
	$problem_result{score} = $total/$count if $count;
	# increase recorded score if the current score is greater.
	$problem_state{recorded_score} = $problem_result{score} if $problem_result{score} > $problem_state{recorded_score};


    $problem_state{num_of_correct_ans}++ if $total == $count;
	$problem_state{num_of_incorrect_ans}++ if $total < $count ;
	warn "Error in grading this problem the total $total is larger than $count" if $total > $count;
	(\%problem_result, \%problem_state);

}
=head3 safetyFilter

	($filtered_ans, $errors) = $obj ->filter_ans($ans)
                               $obj ->rf_safety_filter()

=cut

sub filter_answer {
	my $self = shift;
	my $ans = shift;
	my @filtered_answers;
	my $errors='';
	if (ref($ans) eq 'ARRAY') {   #handle the case where the answer comes from several inputs with the same name
								  # In many cases this will be passed as a reference to an array
								  # if it is passed as a single string (separated by \0 characters) as 
								  # some early versions of CGI behave, then 
								  # it is unclear what will happen when the answer is filtered.
		foreach my $item (@{$ans}) {
			my ($filtered_ans, $error) = &{ $self->{rf_safety_filter} } ($item);
			push(@filtered_answers, $filtered_ans);
			$errors .= " ". $error if $error;  # add error message if error is non-zero.
		}
		(\@filtered_answers,$errors);
	
	} else {
		&{ $self->{rf_safety_filter} } ($ans);
	}
	
}
sub rf_safety_filter {
	my $self = shift;
	my $rf_filter = shift;
	$self->{rf_safety_filter} = $rf_filter if $rf_filter and ref($rf_filter) eq 'CODE';
	warn "The safety_filter must be a reference to a subroutine" unless ref($rf_filter) eq 'CODE' ;
	$self->{rf_safety_filter}
}
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

sub PGsort {
	my $sort_order = shift;
	die "Must supply an ordering function with PGsort: PGsort sub {\$a cmp \$b }, \@list\n" unless ref($sort_order) eq 'CODE';
	sort {&$sort_order($a,$b)} @_;
}

no strict;   # this is important -- I guess because eval operates on code which is not written with strict in mind.

sub PG_restricted_eval {
    my $string = shift;
    my ($pck,$file,$line) = caller;
    my $save_SIG_warn_trap = $SIG{__WARN__};
    $SIG{__WARN__} = sub { CORE::die @_};
    my $save_SIG_die_trap = $SIG{__DIE__};
    $SIG{__DIE__}= sub {CORE::die @_};
    no strict;
    my $out = eval  ("package main; " . $string );
    my $errors =$@;
    my $full_error_report = "PG_restricted_eval detected error at line $line of file $file \n"
                . $errors .
                "The calling package is $pck\n" if defined($errors) && $errors =~/\S/;
    use strict;
    $SIG{__DIE__} = $save_SIG_die_trap;
    $SIG{__WARN__} = $save_SIG_warn_trap;
    return (wantarray) ?  ($out, $errors,$full_error_report) : $out;
}

sub PG_answer_eval {
   local($string) = shift;   # I made this local just in case -- see PG_estricted_eval
   my $errors = '';
   my $full_error_report = '';
   my ($pck,$file,$line) = caller; 
    # Because of the global variable $PG::compartment_name and $PG::safe_cmpt
    # only one problem safe compartment can be active at a time.
    # This might cause problems at some point.  In that case a cleverer way
    # of insuring that the package stays in scope until the answer is evaluated
    # will be required.
    
    # This is pretty tricky and doesn't always work right.
    # We seem to need PG_priv instead of main when PG_answer_eval is called within a completion
    # 'package PG_priv; '
    my $save_SIG_warn_trap = $SIG{__WARN__};
    $SIG{__WARN__} = sub { CORE::die @_};
    my $save_SIG_die_trap = $SIG{__DIE__};
    $SIG{__DIE__}= sub {CORE::die @_};
    my $save_SIG_FPE_trap= $SIG{'FPE'};
    #$SIG{'FPE'} = \&main::PG_floating_point_exception_handler;
    #$SIG{'FPE'} = sub {exit(0)};
    no strict;
    my $out = eval('package main;'.$string);
    $out = '' unless defined($out);
    $errors .=$@;

    $full_error_report = "ERROR: at line $line of file $file
                $errors
                The calling package is $pck\n" if defined($errors) && $errors =~/\S/;
    use strict;
    $SIG{__DIE__} = $save_SIG_die_trap;
    $SIG{__WARN__} = $save_SIG_warn_trap;
    $SIG{'FPE'} = $save_SIG_FPE_trap;
    return (wantarray) ?  ($out, $errors,$full_error_report) : $out;


}

sub dumpvar {
    my ($packageName) = @_;

    local(*alias);
    
    sub emit {
    	print @_;
    }
    
    *stash = *{"${packageName}::"};
    $, = "  ";
    
    emit "Content-type: text/html\n\n<PRE>\n";
    
    
    while ( ($varName, $globValue) = each %stash) {
        emit "$varName\n";
        
	*alias = $globValue;
	next if $varName=~/main/;
	
	if (defined($alias) ) {
	    emit "  \$$varName $alias \n";
	}
	
	if ( defined(@alias) ) {
	    emit "  \@$varName @alias \n";
	}
	if (defined(%alias) ) {
	    emit "  %$varName \n";
	    foreach $key (keys %alias) {
	        emit "    $key => $alias{$key}\n";
	    }



	}
    }
    emit "</PRE></PRE>";


}
use strict;

#### for error checking and debugging purposes
sub pretty_print_rh {
	my $rh = shift;
	foreach my $key (sort keys %{$rh})  {
		warn "  $key => ",$rh->{$key},"\n";
	}
}
# end evaluation subroutines
1;
