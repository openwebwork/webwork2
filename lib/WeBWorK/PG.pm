################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/PG.pm,v 1.76 2009/07/18 02:52:51 gage Exp $
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

package WeBWorK::PG;

=head1 NAME

WeBWorK::PG - Invoke one of several PG rendering methods using an easy-to-use
API.

=cut

use strict;
use warnings;
use WeBWorK::PG::ImageGenerator;
use WeBWorK::Utils qw(runtime_use formatDateTime makeTempDirectory);
use WeBWorK::Utils::RestrictedClosureClass;

use constant DISPLAY_MODES => {
	# display name   # mode name
	tex           => "TeX",
	plainText     => "HTML",
	formattedText => "HTML_tth",
	images        => "HTML_dpng",
	jsMath	      => "HTML_jsMath",
	MathJax	      => "HTML_MathJax",
	asciimath     => "HTML_asciimath",
	LaTeXMathML   => "HTML_LaTeXMathML",
};

sub new {
	shift; # throw away invocant -- we don't need it
	my ($ce, $user, $key, $set, $problem, $psvn, $formFields,
		$translationOptions) = @_;
	
	my $renderer = $ce->{pg}->{renderer};
	
	runtime_use $renderer;
	
	return $renderer->new(@_);
}

sub free {
	my $self = shift;
	#
	#  If certain MathObjects (e.g. LimitedPolynomials) are left in the PG structure, then
	#  freeing them later can cause "Can't locate package ..." errors in the log during
	#  perl garbage collection.  So free them here.
	#
	$self->{pgcore}{OUTPUT_ARRAY} = [];
	$self->{answers} = {};
	undef $self->{translator};
	foreach (keys %{$self->{pgcore}{PG_ANSWERS_HASH}}) {undef $self->{pgcore}{PG_ANSWERS_HASH}{$_}}
}

sub defineProblemEnvir {
	my (
		$self,
		$ce,
		$user,
		$key,
		$set,
		$problem,
		$psvn,  #FIXME  -- not used
		$formFields,
		$options,
		$extras,
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
	$envir{psvnNumber}          = "psvnNumber-is-deprecated-Please-use-psvn-Instead"; #FIXME
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
	# ADDED: courseName, formatedDueDate, enable_reduced_scoring
	
	$envir{openDate}            = $set->open_date;
	$envir{formattedOpenDate}   = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone});
	$envir{OpenDateDayOfWeek}   = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%A", $ce->{siteDefaults}{locale});
	$envir{OpenDateDayOfWeekAbbrev} = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%a", $ce->{siteDefaults}{locale});
	$envir{OpenDateDay}         = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%d", $ce->{siteDefaults}{locale});
	$envir{OpenDateMonthNumber} = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%m", $ce->{siteDefaults}{locale});
	$envir{OpenDateMonthWord}   = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%B", $ce->{siteDefaults}{locale});
	$envir{OpenDateMonthAbbrev} = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%b", $ce->{siteDefaults}{locale});
	$envir{OpenDateYear2Digit}  = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%y", $ce->{siteDefaults}{locale});
	$envir{OpenDateYear4Digit}  = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%Y", $ce->{siteDefaults}{locale});
	$envir{OpenDateHour12}      = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%I", $ce->{siteDefaults}{locale});
	$envir{OpenDateHour24}      = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%H", $ce->{siteDefaults}{locale});
	$envir{OpenDateMinute}      = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%M", $ce->{siteDefaults}{locale});
	$envir{OpenDateAMPM}        = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%P", $ce->{siteDefaults}{locale});
	$envir{OpenDateTimeZone}    = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%Z", $ce->{siteDefaults}{locale});
	$envir{OpenDateTime12}      = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%I:%M%P", $ce->{siteDefaults}{locale});
	$envir{OpenDateTime24}      = formatDateTime($envir{openDate}, $ce->{siteDefaults}{timezone}, "%R", $ce->{siteDefaults}{locale});
	$envir{dueDate}             = $set->due_date;
	$envir{formattedDueDate}    = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone});
	$envir{formatedDueDate}     = $envir{formattedDueDate}; # typo in many header files
	$envir{DueDateDayOfWeek}    = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%A", $ce->{siteDefaults}{locale});
	$envir{DueDateDayOfWeekAbbrev} = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%a", $ce->{siteDefaults}{locale});
	$envir{DueDateDay}          = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%d", $ce->{siteDefaults}{locale});
	$envir{DueDateMonthNumber}  = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%m", $ce->{siteDefaults}{locale});
	$envir{DueDateMonthWord}    = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%B", $ce->{siteDefaults}{locale});
	$envir{DueDateMonthAbbrev}  = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%b", $ce->{siteDefaults}{locale});
	$envir{DueDateYear2Digit}   = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%y", $ce->{siteDefaults}{locale});
	$envir{DueDateYear4Digit}   = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%Y", $ce->{siteDefaults}{locale});
	$envir{DueDateHour12}       = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%I", $ce->{siteDefaults}{locale});
	$envir{DueDateHour24}       = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%H", $ce->{siteDefaults}{locale});
	$envir{DueDateMinute}       = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%M", $ce->{siteDefaults}{locale});
	$envir{DueDateAMPM}         = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%P", $ce->{siteDefaults}{locale});
	$envir{DueDateTimeZone}     = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%Z", $ce->{siteDefaults}{locale});
	$envir{DueDateTime12}       = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%I:%M%P", $ce->{siteDefaults}{locale});
	$envir{DueDateTime24}       = formatDateTime($envir{dueDate}, $ce->{siteDefaults}{timezone}, "%R", $ce->{siteDefaults}{locale});
	$envir{answerDate}          = $set->answer_date;
	$envir{formattedAnswerDate} = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone});
	$envir{AnsDateDayOfWeek}    = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%A", $ce->{siteDefaults}{locale});
	$envir{AnsDateDayOfWeekAbbrev} = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%a", $ce->{siteDefaults}{locale});
	$envir{AnsDateDay}          = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%d", $ce->{siteDefaults}{locale});
	$envir{AnsDateMonthNumber}  = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%m", $ce->{siteDefaults}{locale});
	$envir{AnsDateMonthWord}    = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%B", $ce->{siteDefaults}{locale});
	$envir{AnsDateMonthAbbrev}  = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%b", $ce->{siteDefaults}{locale});
	$envir{AnsDateYear2Digit}   = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%y", $ce->{siteDefaults}{locale});
	$envir{AnsDateYear4Digit}   = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%Y", $ce->{siteDefaults}{locale});
	$envir{AnsDateHour12}       = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%I", $ce->{siteDefaults}{locale});
	$envir{AnsDateHour24}       = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%H", $ce->{siteDefaults}{locale});
	$envir{AnsDateMinute}       = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%M", $ce->{siteDefaults}{locale});
	$envir{AnsDateAMPM}         = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%P", $ce->{siteDefaults}{locale});
	$envir{AnsDateTimeZone}     = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%Z", $ce->{siteDefaults}{locale});
	$envir{AnsDateTime12}       = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%I:%M%P", $ce->{siteDefaults}{locale});
	$envir{AnsDateTime24}       = formatDateTime($envir{answerDate}, $ce->{siteDefaults}{timezone}, "%R", $ce->{siteDefaults}{locale});
	$envir{numOfAttempts}       = ($problem->num_correct || 0) + ($problem->num_incorrect || 0);
	$envir{problemValue}        = $problem->value;
	$envir{sessionKey}          = $key;
	$envir{courseName}          = $ce->{courseName};
	$envir{enable_reduced_scoring} = $set->enable_reduced_scoring;
	
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
	$envir{permissionLevel}  = $options->{permissionLevel};  # permission level of actual user
	$envir{effectivePermissionLevel}  = $options->{effectivePermissionLevel}; # permission level of user assigned to this question
	
	
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
	$envir{externalCheckUrl}     = $ce->{externalPrograms}->{checkurl};
	# Directories and URLs
	# REMOVED: courseName
	# ADDED: dvipngTempDir
	# ADDED: jsMathURL
	# ADDED: MathJaxURL
	# ADDED: asciimathURL
	# ADDED: macrosPath
	# REMOVED: macrosDirectory, courseScriptsDirectory
	# ADDED: LaTeXMathML
	
	$envir{cgiDirectory}           = undef;
	$envir{cgiURL}                 = undef;
	$envir{classDirectory}         = undef;
    $envir{macrosPath}             = $ce->{pg}->{directories}{macrosPath};
    $envir{appletPath}             = $ce->{pg}->{directories}{appletPath};
    $envir{pgDirectories}          = $ce->{pg}->{directories};
	$envir{webworkHtmlDirectory}   = $ce->{webworkDirs}->{htdocs}."/";
	$envir{webworkHtmlURL}         = $ce->{webworkURLs}->{htdocs}."/";
	$envir{htmlDirectory}          = $ce->{courseDirs}->{html}."/";
	$envir{htmlURL}                = $ce->{courseURLs}->{html}."/";
	$envir{templateDirectory}      = $ce->{courseDirs}->{templates}."/";
	$envir{tempDirectory}          = $ce->{courseDirs}->{html_temp}."/";
	$envir{tempURL}                = $ce->{courseURLs}->{html_temp}."/";
	$envir{scriptDirectory}        = undef;
	$envir{webworkDocsURL}         = $ce->{webworkURLs}->{docs}."/";
	$envir{localHelpURL}           = $ce->{webworkURLs}->{local_help}."/";
	$envir{jsMathURL}              = $ce->{webworkURLs}->{jsMath};
	$envir{MathJaxURL}             = $ce->{webworkURLs}->{MathJax};
	$envir{asciimathURL}	         = $ce->{webworkURLs}->{asciimath};
	$envir{LaTeXMathMLURL}	       = $ce->{webworkURLs}->{LaTeXMathML};
	$envir{server_root_url}        = $ce->{apache_root_url}|| '';
	
	# Information for sending mail
	
	$envir{mailSmtpServer} = $ce->{mail}->{smtpServer};
	$envir{mailSmtpSender} = $ce->{mail}->{smtpSender};
	$envir{ALLOW_MAIL_TO}  = $ce->{mail}->{allowedRecipients};
	
	# Default values for evaluating answers
	
	my $ansEvalDefaults = $ce->{pg}->{ansEvalDefaults};
	$envir{$_} = $ansEvalDefaults->{$_} foreach (keys %$ansEvalDefaults);
	
	# ----------------------------------------------------------------------
	
	# ADDED: ImageGenerator for images mode
	if (defined $extras->{image_generator}) {
		#$envir{imagegen} = $extras->{image_generator};
		# only allow access to the add() method
		$envir{imagegen} = new WeBWorK::Utils::RestrictedClosureClass($extras->{image_generator}, 'add','addToTeXPreamble', 'refresh');
	}
	
	if (defined $extras->{mailer}) {
		#my $rmailer = new WeBWorK::Utils::RestrictedClosureClass($extras->{mailer},
		#	qw/Open SendEnc Close Cancel skipped_recipients error error_msg/);
		#my $safe_hole = new Safe::Hole {};
		#$envir{mailer} = $safe_hole->wrap($rmailer);
		$envir{mailer} = new WeBWorK::Utils::RestrictedClosureClass($extras->{mailer}, "add_message");
	}
	
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

sub translateDisplayModeNames($) {
	my $name = shift;
	return DISPLAY_MODES()->{$name};
}

sub oldSafetyFilter {
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

sub nullSafetyFilter {
	return shift, 0; # no errors
}

1;

__END__

=head1 SYNOPSIS

 $pg = WeBWorK::PG->new(
	 $ce,         # a WeBWorK::CourseEnvironment object
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
 $post_header_text = $pg->{post_header_text};  # text string
 $answerHash = $pg->{answers};    # WeBWorK::PG::AnswerHash
 $result     = $pg->{result};     # hash reference
 $state      = $pg->{state};      # hash reference
 $errors     = $pg->{errors};     # text string
 $warnings   = $pg->{warnings};   # text string
 $flags      = $pg->{flags};      # hash reference

=head1 DESCRIPTION

WeBWorK::PG is a factory for modules which use the WeBWorK::PG API. Notable
modules which use this API (and exist) are WeBWorK::PG::Local and
WeBWorK::PG::Remote. The course environment key $pg{renderer} is consulted to
determine which render to use.

=head1 THE WEBWORK::PG API

Modules which support this API must implement the following method:

=over

=item new ENVIRONMENT, USER, KEY, SET, PROBLEM, PSVN, FIELDS, OPTIONS

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

the problem set version number: use variable $psvn

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
even if the PG source has not been updated. FIXME: remove this option.

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

=head1 METHODS PROVIDED BY THE BASE CLASS

The following methods are provided for use by subclasses of WeBWorK::PG.

=over

=item defineProblemEnvir ENVIRONMENT, USER, KEY, SET, PROBLEM, PSVN, FIELDS, OPTIONS

Generate a problem environment hash to pass to the renderer.

=item translateDisplayModeNames NAME

NAME contains 

=back

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

=cut
