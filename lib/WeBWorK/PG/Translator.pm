################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################


package WeBWorK::PG::Translator;


use strict;
use warnings;
use Opcode;
use Safe;
use Net::SMTP;
use WeBWorK::Utils qw(runtime_use);
use WeBWorK::PG::IO;

# loading GD within the Safe compartment has occasionally caused infinite recursion
# Putting these use statements here seems to avoid this problem
# It is not clear that this is essential once things are working properly.
#use Exporter;
#use DynaLoader;


=head1 NAME

WeBWorK::PG::Translator - Evaluate PG code and evaluate answers safely

=head1 SYNPOSIS

    my $pt = new WeBWorK::PG::Translator;      # create a translator;
    $pt->environment(\%envir);      # provide the environment variable for the problem
    $pt->initialize();              # initialize the translator
    $pt-> set_mask();               # set the operation mask for the translator safe compartment
    $pt->source_string($source);    # provide the source string for the problem

    $pt -> unrestricted_load("${courseScriptsDirectory}PG.pl");
    $pt -> unrestricted_load("${courseScriptsDirectory}dangerousMacros.pl");
                                    # load the unprotected macro files
                                    # these files are evaluated with the Safe compartment wide open
                                    # other macros are loaded from within the problem using loadMacros

    $pt ->translate();              # translate the problem (the out following 4 pieces of information are created)
    
    $PG_PROBLEM_TEXT_ARRAY_REF = $pt->ra_text();              # output text for the body of the HTML file (in array form)
    $PG_PROBLEM_TEXT_REF = $pt->r_text();                     # output text for the body of the HTML file
    $PG_HEADER_TEXT_REF = $pt->r_header;#\$PG_HEADER_TEXT;    # text for the header of the HTML file
    $PG_ANSWER_HASH_REF = $pt->rh_correct_answers;            # a hash of answer evaluators
    $PG_FLAGS_REF = $pt ->rh_flags;                           # misc. status flags.

    $pt -> process_answers(\%inputs);    # evaluates all of the answers using submitted answers from %input
    
    my $rh_answer_results = $pt->rh_evaluated_answers;  # provides a hash of the results of evaluating the answers.
    my $rh_problem_result = $pt->grade_problem;         # grades the problem using the default problem grading method.

=head1 DESCRIPTION

This module defines an object which will translate a problem written in the Problem Generating (PG) language

=cut

=head2 be_strict

This creates a substitute for C<use strict;> which cannot be used in PG problem
sets or PG macro files.  Use this way to imitate the behavior of C<use strict;>

	BEGIN {
		be_strict(); # an alias for use strict.
		             # This means that all global variable
		             # must contain main:: as a prefix.
	}

=cut

BEGIN {
	# allows the use of strict within macro packages.
	sub be_strict {
		require 'strict.pm';
		strict::import();
	}
	
	# also define in Main::, for PG modules.
	sub Main::be_strict { &be_strict }
}

=head2 evaluate_modules

	Usage:  $obj -> evaluate_modules('WWPlot', 'Fun', 'Circle');
	        $obj -> evaluate_modules('reset');

Adds the modules WWPlot.pm, Fun.pm and Circle.pm in the courseScripts directory to the list of modules
which can be used by the PG problems.  The keyword 'reset' or 'erase' erases the list of modules already loaded

=cut

#my @class_modules = ();
#sub evaluate_modules{
#	my $self = shift;
#	my @modules = @_;
#	# temporary  -
#	# We  need a method for setting the course directory without calling Global.
#	
#	my $courseScriptsDirectory = $self->rh_directories->{courseScriptsDirectory};
#	my $save_SIG_die_trap = $SIG{__DIE__};
#	$SIG{__DIE__} = sub {CORE::die(@_) };
#	while (@modules) {
#		my $module_name = shift @modules;
#		print STDERR "evaluate_modules: about to evaluate $module_name\n";
#		$module_name =~ s/\.pm$//;   # remove trailing .pm if someone forgot
#		if ($module_name eq 'reset'  or $module_name eq 'erase' ) {
#			@class_modules = ();
#			next;
#		}
#		if ( -r  "${courseScriptsDirectory}${module_name}.pm"   ) {
#			eval(qq! require "${courseScriptsDirectory}${module_name}.pm";  import ${module_name};! );
#			warn "Errors in including the module ${courseScriptsDirectory}$module_name.pm $@" if $@;
#		} else {
#			eval(qq! require "${module_name}.pm";  import ${module_name};! );
#			warn "Errors in including either the module $module_name.pm or ${courseScriptsDirectory}${module_name}.pm $@" if $@;
#		}
#		push(@class_modules, "\%${module_name}::");
#		print STDERR "loading $module_name\n";
#	}
#	$SIG{__DIE__} = $save_SIG_die_trap;
#}

# *** attention! Right now, packages DO NOT have the WeBWorK::PG prefix
# before release, we HAVE to figure out how to make them behave WITH the
# prefix -- this may involve changing the actual package names.

sub evaluate_modules {
	my $self = shift;
	local $SIG{__DIE__} = "DEFAULT"; # we're going to be eval()ing code
	foreach (@_) {
		#warn "attempting to load $_\n";
		# ensure that the name is in fact a base name
		s/\.pm$// and warn "fixing your broken package name: $_.pm => $_";
#		# generate a full package name from the base name
#		unless (/::/) {
#			$_ = "WeBWorK::PG::$_";
#		}
		# call runtime_use on the package name
		# don't worry -- runtime_use won't load a package twice!
		eval { runtime_use $_ };
		warn "Failed to evaluate module $_: $@" if $@;
		# record this in the appropriate place
		push @{$self->{ra_included_modules}}, "\%${_}::";
	}
}

=head2 load_extra_packages

	Usage:  $obj -> load_extra_packages('AlgParserWithImplicitExpand',
	                                    'Expr','ExprWithImplicitExpand');

Loads extra packages for modules that contain more than one package.  Works in conjunction with
evaluate_modules.  It is assumed that the file containing the extra packages (along with the base
pachage name which is the same as the name of the file minus the .pm extension) has already been
loaded using evaluate_modules
=cut

sub load_extra_packages{
	my $self = shift;
	my @package_list = @_;
	my $package_name;
	
	foreach (@package_list) {
		# ensure that the name is in fact a base name
		s/\.pm$// and warn "fixing your broken package name: $_.pm => $_";
#		# generate a full package name from the base name
#		unless (/::/) {
#			$_ = "WeBWorK::PG::$_";
#		}
		# import symbols from the extra package
		import $_;
		warn "Failed to evaluate module $_: $@" if $@;
		# record this in the appropriate place
		push @{$self->{ra_included_modules}}, "\%${_}::";
	}
}

=head2  new
	Creates the translator object.

=cut


sub new {
	my $class = shift;
	my $safe_cmpt = new Safe; #('PG_priv');
	my $self = {
		envir                     => undef,
		PG_PROBLEM_TEXT_ARRAY_REF => [],
		PG_PROBLEM_TEXT_REF       => 0,
		PG_HEADER_TEXT_REF        => 0,
		PG_ANSWER_HASH_REF        => {},
		PG_FLAGS_REF              => {},
		safe                      => $safe_cmpt,
		safe_compartment_name     => $safe_cmpt->root,
		errors                    => "",
		source                    => "",
		rh_correct_answers        => {},
		rh_student_answers        => {},
		rh_evaluated_answers      => {},
		rh_problem_result         => {},
		rh_problem_state          => {
			recorded_score       => 0, # the score recorded in the data base
			num_of_correct_ans   => 0, # the number of correct attempts at doing the problem
			num_of_incorrect_ans => 0, # the number of incorrect attempts
		},
		rf_problem_grader         => \&std_problem_grader,
		rf_safety_filter          => \&safetyFilter,
		# ra_included_modules is now populated independantly of @class_modules:
		ra_included_modules       => [], # [ @class_modules ],
		rh_directories            => {},
	};
	bless $self, $class;
}

=pod

(b) The following routines defined within the PG module are shared:

	&be_strict
	&read_whole_problem_file
	&convertPath
	&surePathToTmpFile
	&fileFromPath
	&directoryFromPath
	&createFile

	&includePGtext

	&PG_answer_eval
	&PG_restricted_eval

	&send_mail_to
	&PGsort

In addition the environment hash C<%envir> is shared.  This variable is unpacked
when PG.pl is run and provides most of the environment variables for each problem
template.

=for html

	<A href =
	"${Global::webworkDocsURL}techdescription/pglanguage/PGenvironment.html"> environment variables</A>

=cut


=pod

(c) Sharing macros:

The macros shared with the safe compartment are

	'&read_whole_problem_file'
	'&convertPath'
	'&surePathToTmpFile'
	'&fileFromPath'
	'&directoryFromPath'
	'&createFile'
	'&PG_answer_eval'
	'&PG_restricted_eval'
	'&be_strict'
	'&send_mail_to'
	'&PGsort'
	'&dumpvar'
	'&includePGtext'

=cut

# SHARE variables and routines with safe compartment
my %shared_subroutine_hash = (
#IO#	'&read_whole_problem_file' => 'PGtranslator', #the values are dummies.
#IO#	'&convertPath'             => 'PGtranslator', # if they're dummies, why set them to
#IO#	'&surePathToTmpFile'       => 'PGtranslator', # something that seems meaningful,
#IO#	'&fileFromPath'            => 'PGtranslator', # instead of '1' or something?
#IO#	'&directoryFromPath'       => 'PGtranslator',
#IO#	'&createFile'              => 'PGtranslator',
	'&PG_answer_eval'          => 'PGtranslator',
	'&PG_restricted_eval'      => 'PGtranslator',
	'&be_strict'               => 'PGtranslator',
#IO#	'&send_mail_to'            => 'PGtranslator',
	'&PGsort'                  => 'PGtranslator',
	'&dumpvar'                 => 'PGtranslator',
#IO#	'&includePGtext'           => 'PGtranslator',
);

sub initialize {
    my $self = shift;
    my $safe_cmpt = $self->{safe};
    #print "initializing safeCompartment",$safe_cmpt -> root(), "\n";

    $safe_cmpt -> share(keys %shared_subroutine_hash);
    no strict;
    local(%envir) = %{ $self ->{envir} };
	$safe_cmpt -> share('%envir');
	#local($rf_answer_eval) = sub { $self->PG_answer_eval(@_); };
	#local($rf_restricted_eval) = sub { $self->PG_restricted_eval(@_); };
	#$safe_cmpt -> share('$rf_answer_eval');
	#$safe_cmpt -> share('$rf_restricted_eval');
	use strict;
    
	# ra_included_modules is now populated independantly of @class_modules:
	#$self->{ra_included_modules} = [@class_modules];
	
	$safe_cmpt -> share_from('main', $self->{ra_included_modules} );
		# the above line will get changed when we fix the PG modules thing. heh heh.
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

=head2   Safe compartment pass through macros



=cut

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
	#print STDERR "$macro_file_name   has not yet been loaded\n" unless $macro_file_loaded;	
	unless ($macro_file_loaded) {
		## load the $filePath file
		## Using rdo insures that the $filePath file is loaded for every problem, allowing initializations to occur.
		## Ordinary mortals should not be fooling with the fundamental macros in these files.  
		my $local_errors = "";
		if (-r $filePath ) {
			my $rdoResult = $safe_cmpt->rdo($filePath);
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
	#print STDERR "$filePath is properly loaded\n\n" if $macro_file_loaded;
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

# sub DESTROY {
#     my $self = shift;
#     my $nameSpace = $self->nameSpace;
#  	no strict 'refs';
#    	my $nm = "${nameSpace}::";
#      my $nsp = \%{"$nm"};
#       my @list = keys %$nsp;
#       while (@list) {
#    	 	my $name = pop(@list);
#   	 	if  ( defined(&{$nsp->{$name}})  )  {
#   	 	   #print "checking \&$name\n";
#   	 	   unless (exists( $shared_subroutine_hash{"\&$name"} ) ) {
#   	 	 		undef( &{$nsp->{$name}} );
#   	 	 		#print "destroying \&$name\n";
#   	 	   } else {
#   	 	   		#delete( $nsp->{$name} );
#   	 	   		#print "what is left",join(" ",%$nsp) ,"\n\n";
#   	 	   }
#   	 	   
#   	 	}
#   	 	if  ( defined(${$nsp->{$name}})  )  {
#   	 	   #undef( ${$nsp->{$name}} );         ## unless commented out download hardcopy bombs with Perl 5.6
#            #print "destroying \$$name\n";
#   	 	} 
#   	 	if  ( defined(@{$nsp->{$name}})  )  {
#   	 	   undef( @{$nsp->{$name}} );  
#   	 	   #print "destroying \@$name\n";
#   	 	} 
#    	 	if  ( defined(%{$nsp->{$name}})  )  {
#    	 	   undef( %{$nsp->{$name}} ) unless $name =~ /::/ ;  
#    	 	   #print "destroying \%$name\n";
#    	 	}
#    	 	# changed for Perl 5.6
# 	 	delete ( $nsp->{$name} ) if defined($nsp->{$name});  # this must be uncommented in Perl 5.6 to reinitialize variables
# 	 	# changed for Perl 5.6
# 	 #print "deleting $name\n";	
# 		#undef( @{$nsp->{$name}} ) if defined(@{$nsp->{$name}});
# 		#undef( %{$nsp->{$name}} ) if defined(%{$nsp->{$name}}) and $name ne "main::"; 	
#  	 }
# 
# 	use strict;
#     #print "\nObject going bye-bye\n";
#     
# }

=head2  set_mask






(e) Now we close the safe compartment.  Only the certain operations can be used
within PG problems and the PG macro files.  These include the subroutines
shared with the safe compartment as defined above and most Perl commands which
do not involve file access, access to the system or evaluation.

Specifically the following are allowed

	time()
		# gives the current Unix time
		# used to determine whether solutions are visible.
	atan, sin cos exp log sqrt
		# arithemetic commands -- more are defined in PGauxiliaryFunctions.pl

The following are specifically not allowed:

	eval()
	unlink, symlink, system, exec
	print require



=cut

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


=head2  Translate


=cut

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



=pod

(3) B<Preprocess the problem text>

The input text is subjected to two global replacements.
First every incidence of

	BEGIN_TEXT
	problem text
	END_TEXT

is replaced by

   	TEXT( EV3( <<'END_TEXT' ) );
	problem text
	END_TEXT

The first construction is syntactic sugar for the second. This is explained
in C<PGbasicmacros.pl>.

Second every incidence
of \ (backslash) is replaced by \\ (double backslash).  Third each incidence of
~~ is replaced by a single backslash.

This is done to alleviate a basic
incompatibility between TeX and Perl. TeX uses backslashes constantly to denote
a command word (as opposed to text which is to be entered literally).  Perl
uses backslash to escape the following symbol.  This escape
mechanism takes place immediately when a Perl script is compiled and takes
place throughout the code and within every quoted string (both double and single
quoted strings) with the single exception of single quoted "here" documents.
That is backlashes which appear in

    TEXT(<<'EOF');
    ... text including \{   \} for example
    EOF

are the only ones not immediately evaluated.  This behavior makes it very difficult
to use TeX notation for defining mathematics within text.

The initial global
replacement, before compiling a PG problem, allows one to use backslashes within
text without doubling them. (The anomolous behavior inside single quoted "here"
documents is compensated for by the behavior of the evaluation macro EV3.) This
makes typing TeX easy, but introduces one difficulty in entering normal Perl code.

The second global replacement provides a work around for this -- use ~~ when you
would ordinarily use a backslash in Perl code.
In order to define a carriage return use ~~n rather than \n; in order to define
a reference to a variable you must use ~~@array rather than \@array. This is
annoying and a source of simple compiler errors, but must be lived with.

The problems are not evaluated in strict mode, so global variables can be used
without warnings.



=cut

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

=pod

(4) B<Evaluate the problem text>

Evaluate the text within the safe compartment.  Save the errors. The safe
compartment is a new one unless the $safeCompartment was set to zero in which
case the previously defined safe compartment is used. (See item 1.)

=cut


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

=pod

(5) B<Process errors>

The error provided by Perl
is truncated slightly and returned. In the text
string which would normally contain the rendered problem.

The original text string is given line numbers and concatenated to
the errors.

=cut



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

=pod

(6) B<Prepare return values>

	Returns:
			$PG_PROBLEM_TEXT_ARRAY_REF -- Reference to a string containing the rendered text.
			$PG_HEADER_TEXT_REF -- Reference to a string containing material to placed in the header (for use by JavaScript)
			$PG_ANSWER_HASH_REF -- Reference to an array containing the answer evaluators.
			$PG_FLAGS_REF -- Reference to a hash containing flags and other references:
				'error_flag' is set to 1 if there were errors in rendering

=cut

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


=head2   Answer evaluation methods

=cut

=head3  access methods

	$obj->rh_student_answers

=cut



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


=head3 process_answers


	$obj->process_answers()


=cut


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
		$temp_ans = '' unless defined($temp_ans); #make sure that answer is always defined
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
			warn "Evaluation error: Answer $ans_name:<BR>\n", 
				$rh_ans_evaluation_result->error_flag(), " :: ",
				$rh_ans_evaluation_result->error_message(),"<BR>\n" 
					if defined($rh_ans_evaluation_result)  
						and defined($rh_ans_evaluation_result->error_flag());
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



=head3 grade_problem

	$obj->rh_problem_state(%problem_state);  # sets the current problem state
	$obj->grade_problem(%form_options);


=cut


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
 	my %problem_result = (
		score => 0,
		errors => '',
		type => 'avg_problem_grader',
		msg => '',
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

##   Check submittedAnswer for forbidden characters, etc.
#     ($submittedAnswer,$errorno) = safetyFilter($submittedAnswer);
#     	$errors .= "No answer was submitted.<BR>" if $errorno == 1;
#     	$errors .= "There are forbidden characters in your answer: $submittedAnswer<BR>" if $errorno ==2;
#
##   Check correctAnswer for forbidden characters, etc.
#     unless (ref($correctAnswer) ) {  #skip check if $correctAnswer is a function
#     	($correctAnswer,$errorno) = safetyFilter($correctAnswer);
#     	$errors .= "No correct answer is given in the statement of the problem.
#     	            Please report this to your instructor.<BR>" if $errorno == 1;
#     	$errors .= "There are forbidden characters in the problems answer.
#     	            Please report this to your instructor.<BR>" if $errorno == 2;
#     }



=head2 PGsort

Because of the way sort is optimized in Perl, the symbols $a and $b
have special significance.

C<sort {$a<=>$b} @list>
C<sort {$a cmp $b} @list>

sorts the list numerically and lexically respectively. 

If C<my $a;> is used in a problem, before the sort routine is defined in a macro, then
things get badly confused.  To correct this, the following macros are defined in
dangerougMacros.pl which is evaluated before the problem template is read.

	PGsort sub { $_[0] <=> $_[1] }, @list;
	PGsort sub { $_[0] cmp $_[1] }, @list;

provide slightly slower, but safer, routines for the PG language. (The subroutines
for ordering are B<required>. Note the commas!)

=cut
# This sort can cause troubles because of its special use of $a and $b
# Putting it in dangerousMacros.pl worked frequently, but not always.
# In particular ANS( ans_eva1 ans_eval2) caused trouble.
# One answer at a time did not --- very strange.

sub PGsort {
	my $sort_order = shift;
	die "Must supply an ordering function with PGsort: PGsort sub {\$a cmp \$b }, \@list\n" unless ref($sort_order) eq 'CODE';
	sort {&$sort_order($a,$b)} @_;
}

=head2 includePGtext

	includePGtext($string_ref, $envir_ref)

Calls C<createPGtext> recursively with the $safeCompartment variable set to 0
so that the rendering continues in the current safe compartment.  The output
is the same as the output from createPGtext. This is used in processing
some of the sample CAPA files.

=cut

#this is a method for importing additional PG files from within one PG file.
# sub includePGtext {
#     my $self = shift;
#     my $string_ref =shift;
#     my $envir_ref = shift;
#     $self->environment($envir_ref);
# 	$self->createPGtext($string_ref);
# }
# evaluation macros



no strict;   # this is important -- I guess because eval operates on code which is not written with strict in mind.



=head2 PG_restricted_eval

	PG_restricted_eval($string)

Evaluated in package 'main'. Result of last statement is returned.
When called from within a safe compartment the safe compartment package
is 'main'.


=cut

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

=head2 PG_answer_eval


	PG_answer_eval($string)

Evaluated in package defined by the current safe compartment.
Result of last statement is returned.
When called from within a safe compartment the safe compartment package
is 'main'.

There is still some confusion about how these two evaluation subroutines work
and how best to define them.  It is useful to have two evaluation procedures
since at some point one might like to make the answer evaluations more stringent.

=cut


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
    $SIG{'FPE'} = $save_SIG_FPE_trap if defined $save_SIG_FPE_trap;
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
