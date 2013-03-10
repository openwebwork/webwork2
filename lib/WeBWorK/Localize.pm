package WeBWorK::Localize;


#use Locale::Maketext::Simple; 
 
#use base ("Locale::Maketext::Simple");
use File::Spec;

print STDERR "Localize.pm: Full path for the localization directory set to |$WeBWorK::Constants::WEBWORK_DIRECTORY/lib/WeBWorK/Localize|\n";
#Locale::Maketext::Simple->import(Path => "$WeBWorK::Constants::WEBWORK_DIRECTORY/lib/WeBWorK/Localize");
use Locale::Maketext;
use Locale::Maketext::Lexicon;

my $path = "$WeBWorK::Constants::WEBWORK_DIRECTORY/lib/WeBWorK/Localize";
my   $pattern = File::Spec->catfile($path, '*.[pm]o');
my   $decode = 0;
my   $encoding = undef;

# For some reason this next stanza needs to be evaluated 
# separately.  I'm not sure why it can't be
# directly entered into the code.

eval "
	package WeBWorK::Localize::I18N;
	use base 'Locale::Maketext';
    %WeBWorK::Localize::I18N::Lexicon = ( '_AUTO' => 1 );
	Locale::Maketext::Lexicon->import({
	    'i-default' => [ 'Auto' ],
	    '*'	=> [ Gettext => \$pattern ],
	    _decode => \$decode,
	    _encoding => \$encoding,
	});
	*tense = sub { \$_[1] . ((\$_[2] eq 'present') ? 'ing' : 'ed') };
	
" or die $@;
 
package WeBWorK::Localize; 

sub getLoc {
	my $lang = shift;
	my $lh = WeBWorK::Localize::I18N->get_handle($lang);	
	return sub {$lh->maketext(@_)};
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
"_GUEST_LOGIN_MESSAGE"   => q{tr: This course supports guest logins. Click [_1] to log into this course as a guest.},

"_EXTERNAL_AUTH_MESSAGE" => q{[_1] uses an external authentication system.  You've authenticated through that system, but aren't allowed to log in to this course.},

"_PROBLEM_SET_SUMMARY"   => q{This is a table showing the current Homework sets for this class.  The fields from left to right are: Edit Set Data, Edit Problems, Edit Assigned Users, Visibility to students, Reduced Credit Enabled, Date it was opened, Date it is due, and the Date during which the answers are posted.  The Edit Set Data field contains checkboxes for selection and a link to the set data editing page.  The cells in the Edit Problems fields contain links which take you to a page where you can edit the containing problems, and the cells in the edit assigned users field contains links which take you to a page where you can edit what students the set is assigned to.},

"_USER_TABLE_SUMMARY"    => q{A table showing all the current users along with several fields of user information. The fields from left to right are: Login Name, Login Status, Assigned Sets, First Name, Last Name, Email Address, Student ID, Enrollment Status, Section, Recitation, Comments, and Permission Level.  Clicking on the links in the column headers will sort the table by the field it corresponds to. The Login Name fields contain checkboxes for selecting the user.  Clicking the link of the name itself will allow you to act as the selected user.  There will also be an image link following the name which will take you to a page where you can edit the selected user's information.  Clicking the emails will allow you to email the corresponding user.  Clicking the links in the entries in the assigned sets columns will take you to a page where you can view and reassign the sets for the selected user.},

	);
	
package WeBWorK::Localize::I18N;
use base(WeBWorK::Localize);

1;
