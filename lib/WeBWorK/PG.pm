################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::PG;

=head1 NAME

WeBWorK::PG - Invoke one of several PG rendering methods using an easy-to-use
API.

=cut

use strict;
use warnings;
use WeBWorK::Utils qw(runtime_use);

sub new {
	shift; # throw away invocant -- we don't need it
	my ($ce, $user, $key, $set, $problem, $psvn, $formFields,
		$translationOptions) = @_;
	
	my $renderer = $ce->{pg}->{renderer};
	
	runtime_use $renderer;
	
	return $renderer->new(@_);
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

=head1 AUTHOR

Written by Sam Hathaway, sh002i (at) math.rochester.edu.

=cut
