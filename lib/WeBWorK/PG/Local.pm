################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/PG/Local.pm,v 1.14 2004/06/26 20:44:54 jj Exp $
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

package WeBWorK::PG::Local;
use base qw(WeBWorK::PG);

=head1 NAME

WeBWorK::PG::Local - Use the WeBWorK::PG API to invoke a local
WeBWorK::PG::Translator object.

=head1 DESCRIPTION

WeBWorK::PG::Local encapsulates the PG translation process, making multiple
calls to WeBWorK::PG::Translator. Much of the flexibility of the Translator is
hidden, instead making choices that are appropriate for the webwork2
system

It implements the WeBWorK::PG interface and uses a local
WeBWorK::PG::Translator to perform problem rendering. See the documentation for
the WeBWorK::PG module for information about the API.

=cut

use strict;
use warnings;
use File::Path qw(rmtree);
use WeBWorK::PG::Translator;
use WeBWorK::Utils qw(readFile writeTimingLogEntry);

# Problem processing will time out after this number of seconds.
use constant TIMEOUT => 5*60;

BEGIN {
	# This safe compartment is used to read the large macro files such as
	# PG.pl, PGbasicmacros.pl and PGanswermacros and cache the results so that
	# future calls have preloaded versions of these large files. This saves a
	# significant amount of time.
	$WeBWorK::PG::Local::safeCache = new Safe;
}

sub new {
	my $invocant = shift;
	local $SIG{ALRM} = sub { die "Timeout after processing this problem for ", TIMEOUT, " seconds. Check for infinite loops in problem source.\n" };
	alarm TIMEOUT;
	my $result = eval { $invocant->new_helper(@_) };
	alarm 0;
	die $@ if $@;
	return $result;
}

sub new_helper {
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
# 	writeTimingLogEntry($ce, "WeBWorK::PG::new",
# 		"user=".$user->user_id.",problem=".$ce->{courseName}."/".$set->set_id."/".$problem->problem_id.",mode=".$translationOptions->{displayMode},
# 		"begin");
	
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
	my $envir = $class->defineProblemEnvir(
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
	
	# Preload the macros files which are used routinely: PG.pl,
	# dangerousMacros.pl, IO.pl, PGbasicmacros.pl, and PGanswermacros.pl
	# (Preloading the last two files safes a significant amount of time.)
	# 
	# IO.pl, PG.pl, and dangerousMacros.pl are loaded using
	# unrestricted_load This is hard wired into the
	# Translator::pre_load_macro_files subroutine. I'd like to change this
	# at some point to have the same sort of interface to global.conf that
	# the module loading does -- have a list of macros to load
	# unrestrictedly.
	# 	
	# This has been replaced by the pre_load_macro_files subroutine.  It
	# loads AND caches the files. While PG.pl and dangerousMacros are not
	# large, they are referred to by PGbasicmacros and PGanswermacros.
	# Because these are loaded into the cached name space (e.g.
	# Safe::Root1::) all calls to, say NEW_ANSWER_NAME are actually calls
	# to Safe::Root1::NEW_ANSWER_NAME.  It is useful to have these names
	# inside the Safe::Root1: cached safe compartment.  (NEW_ANSWER_NAME
	# and all other subroutine names are also automatically exported into
	# the current safe compartment Safe::Rootx::
	# 
	# The headers of both PGbasicmacros and PGanswermacros has code that
	# insures that the constants used are imported into the current safe
	# compartment.  This involves evaluating references to, say
	# $main::displayMode, at runtime to insure that main refers to
	# Safe::Rootx:: and NOT to Safe::Root1::, which is the value of main::
	# at compile time.
	# 
	# TO ENABLE CACHEING UNCOMMENT THE FOLLOWING:
	eval{$translator->pre_load_macro_files(
		$WeBWorK::PG::Local::safeCache,
		$ce->{pg}->{directories}->{macros}, 
		'PG.pl', 'dangerousMacros.pl','IO.pl','PGbasicmacros.pl','PGanswermacros.pl'
	)};
    warn "Error while preloading macro files: $@" if $@;

	# STANDARD LOADING CODE: for cached script files, this merely
	# initializes the constants.
	foreach (qw(PG.pl dangerousMacros.pl IO.pl)) {
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
	
	# install a safety filter
	#warn "PG: installing a safety filter\n";
	#$translator->rf_safety_filter(\&oldSafetyFilter);
	$translator->rf_safety_filter(\&WeBWorK::PG::nullSafetyFilter);
	
	# write timing log entry -- the translator is now all set up
# 	writeTimingLogEntry($ce, "WeBWorK::PG::new",
# 		"initialized",
# 		"intermediate");
	
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
	my $body_text_ref  = $translator->r_text;
	if ($envir->{imagegen}) {
		my $sourceFile = $ce->{courseDirs}->{templates} . "/" . $problem->source_file;
		my %mtimeOption = -e $sourceFile
			? (mtime => (stat $sourceFile)[9])
			: ();
		
		$envir->{imagegen}->render(
			refresh => $translationOptions->{refreshMath2img},
			%mtimeOption,
			body_text => $body_text_ref,
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
# 	writeTimingLogEntry($ce, "WeBWorK::PG::new", "", "end");
	
	# return an object which contains the translator and the results of
	# the translation process. this is DIFFERENT from the "format expected
	# by Webwork.pm (and I believe processProblem8, but check.)"
	return bless {
		translator => $translator,
		head_text  => ${ $translator->r_header },
		body_text  => ${ $body_text_ref },
		answers    => $translator->rh_evaluated_answers,
		result     => $result,
		state      => $state,
		errors     => $translator->errors,
		warnings   => $warnings,
		flags      => $translator->rh_flags,
	}, $class;
}

1;

__END__

=head1 OPERATION

WeBWorK::PG::Local goes through the following operations when constructed:

=over

=item Create a translator

Instantiate a WeBWorK::PG::Translator object.

=item Set the directory hash

Set the translator's directory hash (courseScripts, macros, templates, and temp
directories) from the course environment.

=item Evaluate PG modules

Using the module list from the course environment (pg->modules), perform a
"use"-like operation to evaluate modules at runtime.

=item Set the problem environment

Use data from the user, set, and problem, as well as the course
environemnt and translation options, to set the problem environment. The
default subroutine, &WeBWorK::PG::defineProblemEnvir, is used.

=item Initialize the translator

Call &WeBWorK::PG::Translator::initialize. What more do you want?

=item Load IO.pl, PG.pl and dangerousMacros.pl

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
