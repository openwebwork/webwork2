package WeBWorK::Localize;


use Locale::Maketext::Simple;  
use base ("Locale::Maketext::Simple");

print STDERR "Localize.pm: Full path for the localization directory set to |$WeBWorK::Constants::WEBWORK_DIRECTORY/lib/WeBWorK/Localize|\n";
Locale::Maketext::Simple->import(Path => "$WeBWorK::Constants::WEBWORK_DIRECTORY/lib/WeBWorK/Localize");
# use Locale::Maketext;
# use base ('Locale::Maketext');

sub getLoc {
	my $lang = shift;
	loc_lang($lang);
	
	return \&loc;
}

# this is like [quant] but it doesn't write the number
#  usage: [quant,_1,<singular>,<plural>,<optional zero>]

sub plural {
    my($handle, $num, @forms) = @_;

    return "" if @forms == 0;  
    return $forms[2] if @forms > 2 and $num == 0; 

    # Normal case:
    return(  $handle->numerate($num, @forms) );
}

# this is like [quant] but it also has -1 case 
#  usage: [negquant,_1,<neg case>,<singular>,<plural>,<optional zero>]

sub negquant {
    my($handle, $num, @forms) = @_;

    return $num if @forms == 0;

    my $negcase = shift @forms;
    return $negcase if $num < 0;

    return $forms[2] if @forms > 2 and $num == 0; 
    return( $handle->numf($num) . ' ' . $handle->numerate($num, @forms) );
}



%Lexicon = (
	'_AUTO' => 1,
	'_REQUEST_ERROR' => q{
WeBWorK has encountered a software error while attempting to process this
problem. It is likely that there is an error in the problem itself. If you are a
student, report this error message to your professor to have it corrected. If
you are a professor, please consult the error output below for more information.
},
	'_LOGIN_MESSAGE' => q{
If you check [_1] your 
login information will be remembered by the browser 
you are using, allowing you to visit WeBWorK pages 
without typing your user name and password (until your 
session expires). This feature is not safe for public 
workstations, untrusted machines, and machines over 
which you do not have direct control.
},
'_HMWKSETS_EDITOR_DESCRIPTION' => q{ 
This is the homework sets editor page where you can view and edit the homework sets that exist in
this course and the problems that they contain. The top of the page contains forms which allow you
to filter which sets to display in the table, sort the sets in a chosen order, edit homework sets,
publish homework sets, import/export sets from/to an external file, score sets, or create/delete
sets.  To use, please select the action you would like to perform, enter in the relevant information
in the fields below, and hit the \"Take Action!\" button at the bottom of the form.  The bottom of
the page contains a table displaying the sets and several pieces of relevant information.",
},
"_CLASSLIST_EDITOR_DESCRIPTION" => q{
tr: This is the classlist editor page, where you can view and edit the records of all the students
currently enrolled in this course.  The top of the page contains forms which allow you to filter
which students to view, sort your students in a chosen order, edit student records, give new
passwords to students, import/export student records from/to external files, or add/delete students.
 To use, please select the action you would like to perform, enter in the relevant information in
the fields below, and hit the \"Take Action!\" button at the bottom of the form.  The bottom of the
page contains a table containing the student usernames and their information.
},
"_REDUCED_CREDIT_MESSAGE_1" => q{
tr: This assignment has a Reduced Credit Period that begins [_1] and
ends on the due date, [_2].  During this period all additional work done counts [_3]\% of the
original.
},

"_REDUCED_CREDIT_MESSAGE_2" => q{
tr: This assignment had a Reduced Credit Period that began [_1] and
ended on the due date, [_2].  During that period all additional work done counted [_3]\% of the
original.
},
"_GUEST_LOGIN_MESSAGE" => q{tr: This course supports guest logins. Click [_1] to log into this course as a guest.},

"_EXTERNAL_AUTH_MESSAGE" => q{[_1] uses an external authentication system.  You've authenticated through that system, but aren't allowed to log in to this course.},

	);

1;
