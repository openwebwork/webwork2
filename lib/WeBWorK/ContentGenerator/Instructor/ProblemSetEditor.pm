package WeBWorK::ContentGenerator::Instructor::ProblemSetEditor;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetEditor - Edit a set definition list

=cut

use strict;
use warnings;
use CGI qw();


our $rowheight = 20;  #controls the length of the popup menus.  
our $libraryDirectory;
sub title {
	my $self = shift;
	return "Instructor Tools - Problem Set Editor for ".$self->{ce}->{courseName};
}

sub body {
	my $self = shift;
	
	# test area
	my $r = $self->{r};
	my $db = $self->{db};
	
	my $user = $r->param('user');
	my $key = $db->getKey($user)->key();
	
	# Determine a name for this set
	# Determine the set number, if there is one. Otherwise make setName = "new set".
	# fix me
	my ($path_info,@components) = $self->gatherInfo();
	my $setName = $components[0];  # get GET  address for set name

	# Override the setName if it is defined in a form.
	$setName = $r->param('setName') if defined($r->param('setName'));
	$path_info =~s|problemSetEditor.*$|problemSetEditor/|;   # remove the setName, if any, from the path
	my $formPath = "/webwork$path_info";   # . $setName$self->url_authen_args();
	
	
	# determine the set directory
	my $setDirectory = $r->param('setDirectory');
	my $oldSetDirectory = $r->param('oldSetDirectory');
	
	#fix me
	# A user can select a new set AND a problem (in the old set) but the problem won't be in the new set!
	# In other words we must prevent the user from changing the problem and the set simultaneously.
	# We solve this by defining a hidden variable oldSetDirectory which matches the currently displayed problem list
	# the problem entry for the textarea element and the viewProblem url are
	# formed using this old version of setDefinition
	
	
	
	# Determine  values for strings
	
	#text area region, initialize the text area region if it does not exist.
	my $textAreaString;
	#fix me  -- this does not handle multiple problem selections correctly.
	my $problem_name = $r->param('pgProblem');
	my $problem_list = $r->param('problem_list');
	$problem_list = "# List problems to be included in the set here\r\n\r\n" unless defined($problem_list);

	$problem_list .= $oldSetDirectory.'/'.$r->param('pgProblem').", 1 \r\n" if defined($r->param('pgProblem'));  
	$textAreaString = qq!<textarea name="problem_list", cols="40", rows="$rowheight">$problem_list</textarea>!;
	
	
	#Determine the headline for the page   
	$libraryDirectory = $self->{ce}->{courseDirs}->{templates};
	#fix me   Debugging code
# 	my $header = "Choose problems from $libraryDirectory directory" .
# 		"<p>This form is not yet operational. 
# 		<p>SetDirectory is $setDirectory.  
# 		<p>formPath is $formPath 
# 		<p>path_info  is $path_info";
	my $header = '';

	
		
	# Define the popup strings used.
	#fix me
	# he problem of multiple selections needs to be handled properly.
	
	my $popUpSetDirectoryString = $self->fetchSetDirectories($setDirectory);  #pass default choice as current directory
	my $popUpPGProblemString = $self->fetchPGproblems($setDirectory);
	
	
	
	# Define a link to view the problem
	#fix me:
	# Currently this link used the webwork problem library, which might be out of 
	# sync with the local library
	

	
	my $viewProblemLink;
	if ( (defined($oldSetDirectory) and defined($problem_name)) ) {
		$viewProblemLink = qq!View : <a href=! .
	           qq!"http://webhost.math.rochester.edu/webworkdocs/ww/pgView/$oldSetDirectory/$problem_name"! .
	           qq! target = "_probwindow">! .
	           qq!$oldSetDirectory/$problem_name</a>!;
	} else {
		$viewProblemLink = '';
	
	}
	           
	return CGI::p($header),
		#CGI::start_form(-action=>"/webwork/mth143/instructor/problemSetEditor/"),
		CGI::start_form(-action=>$formPath),
		CGI::table( {-border=>2},
			CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
				CGI::th('Editing set : '),
				CGI::td(CGI::textfield(  -name=>'setName',-size=>'20',-value=>$setName,-override=>1)), 
				CGI::td(CGI::submit(-name=>'submitButton',-value=>'Save'))
			),
			CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
				CGI::td($textAreaString),
				CGI::td($popUpSetDirectoryString), 
				CGI::td($popUpPGProblemString)
             	
            ),
             #(defined($viewProblemLink)) ? 
             #	qq!<tr align="CENTER" valign="TOP"><th colspan="3">$viewProblemLink</th></tr>! 
             #	: '',
            CGI::Tr( {-align=>'CENTER',-valign=>'TOP'},
            	CGI::th([	$viewProblemLink,
            				CGI::submit(-name=>'submitButton'  , -value =>'Select set'),
            				CGI::submit(-name=>'submitButton'  , -value =>'Choose problem')
            			])
            ),
            	            
            CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
            	CGI::th(["Open date","Due date", "Answer date"]),
            
            ),
          
            CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
  		 		CGI::td(CGI::textfield(-name=>'open_date', -size=>'20') ),
            	CGI::td(CGI::textfield(-name=>'due_date', -size=>'20') ),
            	CGI::td(CGI::textfield(-name=>'answer_date', -size=>'20') ),             
            ),
            qq!<tr align="center" valign="top"><td colspan="3">View entire set (pdf format) -- not yet implemented</td></tr>!,
        ),
        CGI::hidden(-name=>'user', -value=>$user),
        CGI::hidden(-name=>'key',-value=>$key),
        CGI::hidden(-name=>'oldSetDirectory', -value=>$setDirectory),

		CGI::end_form(),
		"<p> the parameters passed are "  #fix me -- debugging code
		. join("<BR>", %{$r->param()})  
	;

}

sub gatherInfo {
	#fix me.  This is very much hacked together.  In particular can we pass the key inside the post?
	my $self	=	shift;
	my $ce 		= 	$self->{ce};
	my $r		=	$self->{r};
	my $path_info = $r->path_info || "";
	my $remaining_path = $path_info;
	$remaining_path =~ s/^.*problemSetEditor//;
	# $remaining_path =~ s/\?.*$//;    #remove the trailing lines?? perhaps not needed.

	my($junk, @components) = split "/", $remaining_path;
	
	($path_info,@components);
}
sub fetchSetDirectories {

	my $self = shift;
	my $defaultChoice = shift;
	my $templateDirectory = $self->{ce}->{courseDirs}->{templates};
	opendir SETDEFDIR, $templateDirectory 
		or return "Can't open directory $templateDirectory";
	
	my @allFiles = grep !/^\./, readdir SETDEFDIR;
	closedir  SETDEFDIR;

	## filter to find only the set directories 
	## -- it is assumed that these directories don't contain a period in their names
	## and that all other files do.  Directories names must also begin with "set".
	## A better plan would be to read only the names of directories, not files.
	
	## sort the directories
	my @setDefFiles = grep /^set[^\.]*$/, @allFiles;
	my @sortedNames = sort @setDefFiles;

	## print list of files
	my  $fileName;

	my ($ind,$label,$date,@stat);


	return "$libraryDirectory/" . CGI::br(). CGI::popup_menu(-name=>'setDirectory', -size=>$rowheight,
	 -values=>\@sortedNames, -default=>$defaultChoice ) .CGI::br() ;
}

sub fetchPGproblems {

	my $self = shift;
	my $setDirectory = shift;
	
	# Handle default for setDirectory  
	# fix me -- this is not bullet proof
	$setDirectory = "set0" unless defined($setDirectory);
	my $templateDirectory = $self->{ce}->{courseDirs}->{templates};
	
	## 
	opendir SETDEFDIR, "$templateDirectory/$setDirectory" 
		or return "Can't open directory $templateDirectory/$setDirectory";
	
	my @allFiles = grep !/^\./, readdir SETDEFDIR;
	closedir  SETDEFDIR;

	## filter to find only pg problems 
	## Some problems are themselves in directories (if they have auxiliary
	## .png's for example.  This eventuallity needs to be handled.
	
	## sort the directories
	my @pgFiles = grep /\.pg$/, @allFiles;
	my @sortedNames = sort @pgFiles;

	## print list of files
	my  $fileName;

	my ($ind,$label,$date,@stat);
	my %labels;

	return "$setDirectory ". CGI::br() . 
	CGI::popup_menu(-name=>'pgProblem', -size=>$rowheight, -multiple=>undef, -values=>\@sortedNames, -labels=>\%labels ) . 
	CGI::br() ;
}
1;
