package WeBWorK::ContentGenerator::Instructor::ProblemSetEditor;
use base qw(WeBWorK::ContentGenerator::Instructor);
use WeBWorK::Utils qw(readFile formatDateTime parseDateTime);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetEditor - Edit a set definition list

=cut

use strict;
use warnings;
use CGI qw();

our $rowheight = 20;  #controls the length of the popup menus.  
our $libraryName;  #library directory name

use constant SET_FIELDS => [qw(open_date due_date answer_date set_header problem_header)];

sub getSetName {
	my ($self, $pathSetName) = @_;
	if (ref $pathSetName eq "HASH") {
		$pathSetName = undef;
	}
	return $pathSetName;
}

sub title {
	my ($self, @components) = @_;
	return "Problem Set Editor - ".$self->{ce}->{courseName}." : ".$self->getSetName(@components);
}

sub initialize {
	my ($self, @components) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $setName = $self->getSetName(@components);
	my $setRecord = $db->getGlobalSet($setName);

	if (defined($r->param('submit_set_changes'))) {
		my $changed = 0;
		foreach (@{SET_FIELDS()}) {
			if (defined($r->param($_))) {
				if (m/_date$/) {
					$setRecord->$_(parseDateTime($r->param($_)));
				} else {
					$setRecord->$_($r->param($_));
				}
				$changed = 1;
			}
		}
		$db->putGlobalSet($setRecord) if $changed;
	} 
	elsif (defined($r->param('submit_problem_changes'))) {
		my @problemList = $db->listGlobalProblems($setName);
		foreach my $problem (@problemList) {
			my $changed = 0;
			my $problemRecord = $db->getGlobalProblem($setName, $problem);
			foreach (qw(source_file value max_attempts)) {
				my $paramName = "problem_${problem}_$_";
				if (defined($r->param($paramName))) {
					$problemRecord->$_($r->param($paramName));
					$changed = 1;
				}
			}
			$db->putGlobalProblem($problemRecord)
		}
	}
}

# One wrinkle here: if $override is undefined, do the global thing, otherwise, it's truth value determines the checkbox.
sub setRowHTML {
	my ($description, $fieldName, $fieldValue, $size, $override, $overrideValue) = @_;
	
	my $attributeHash = {type=>"text", name=>$fieldName, value=>$fieldValue};
	$attributeHash->{size} = $size if defined $size;
	
	my $html = CGI::td({}, [$description, CGI::input($attributeHash)]);
	
	if (defined $override) {
		$attributeHash->{name}="${fieldName}_override";
		$attributeHash->{value}=($override ? $overrideValue : "" );
	
		$html .= CGI::td({}, [
			CGI::checkbox({
				type=>"checkbox", 
				name=>"override", 
				label=>"",
				value=>$fieldName,
				checked=>($override ? 1 : 0)
			}),
			"override with:",
			CGI::input($attributeHash)
		]);
	}
	
	return $html;
			
}

sub problemElementHTML {
	my ($fieldName, $fieldValue, $size) = @_;
	my $attributeHash = {type=>"text",name=>$fieldName,value=>$fieldValue};
	$attributeHash->{size} = $size if defined $size;
	
	
	return CGI::input($attributeHash);
}

sub body {
	my ($self, @components) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $setName = $self->getSetName(@components);
	my $setRecord = $db->getGlobalSet($setName);
	my @editForUser = $r->param('editForUser');
	# some useful booleans
	my $forUser = scalar(@editForUser);
	my $forOneUser = $forUser == 1;
	
	my $userSetRecord;
	my %overrideArgs;
	if ($forOneUser) {
		$userSetRecord = $db->getUserSet($editForUser[0], $setName);
		foreach my $field (@{SET_FIELDS()}) {
			$overrideArgs{$field} = [defined $userSetRecord->$field, $userSetRecord->$field];
		}
	} else {
		foreach my $field (@{SET_FIELDS()}) {
			$overrideArgs{$field} = [undef, undef];
		}
	}
	
	print CGI::h2({}, "Set Data");	
	print CGI::start_form({method=>"post", action=>$r->uri});
	print CGI::table({},
		CGI::Tr({}, [
			setRowHTML("Open Date:", "open_date", formatDateTime($setRecord->open_date), undef, @{$overrideArgs{open_date}}),
			setRowHTML("Due Date:", "due_date", formatDateTime($setRecord->due_date), undef, @{$overrideArgs{due_date}}),
			setRowHTML("Answer Date:", "answer_date", formatDateTime($setRecord->answer_date), undef, @{$overrideArgs{answer_date}}),
			setRowHTML("Set Header:", "set_header", $setRecord->set_header, undef, @{$overrideArgs{set_header}}),
			setRowHTML("Problem Header:", "problem_header", $setRecord->problem_header, undef, @{$overrideArgs{problem_header}})
		])
	);
	
	print $self->hidden_authen_fields;
	print CGI::input({type=>"submit", name=>"submit_set_changes", value=>"Save Set"});
	print CGI::end_form();
	
	print CGI::h2({}, "Problems");
	
	my @problemList = $db->listGlobalProblems($setName);
	
	print CGI::start_form({method=>"POST", action=>$r->uri});
	print CGI::start_table({});
	print CGI::Tr({}, CGI::th({}, ["Problem", "Max. Attempts", "Weight", "Source File"]));
	foreach my $problem (sort {$a <=> $b} @problemList) {
		my $problemRecord = $db->getGlobalProblem($setName, $problem);
		my $problemID = $problemRecord->problem_id;
		
		print CGI::Tr({}, 
			CGI::td({}, [
				$problemID,
				problemElementHTML("problem_${problemID}_max_attempts",$problemRecord->max_attempts,"7"),
				problemElementHTML("problem_${problemID}_value",$problemRecord->value,"7"),
				problemElementHTML("problem_${problemID}_source_file", $problemRecord->source_file, "40")
			])

		)
	}
	print CGI::end_table();
	print $self->hidden_authen_fields;
	print CGI::input({type=>"submit", name=>"submit_problem_changes", value=>"Save Problems"});
	print CGI::end_form();
	
	return "";
}

sub mike_body {
	my $self = shift;
	
	# test area
	my $r = $self->{r};
	my $db = $self->{db};
	
	my $user = $r->param('user');
	my $key = $db->getKey($user)->key();
	
	
	################
	# Gathering info
	# What is needed
	#     $setName  -- formerly the name of the set definition file
	#     $formURL -- the action URL for the form 
	#     $libraryName  -- the name of the available library 
	#     $setDirectory  -- the current library directory 
	#     $oldSetDirectory -- the previous library directory
	# $problemName    -- the name of the library problem (in the previous library directory)
	#     $problemList    -- the contents of the textarea form
	#     answer dates
	my ($setName,$formURL,
		$libraryName,$setDirectory,$oldSetDirectory,
		$problemName,$problemList,
		$openDate,$dueDate,$answerDate) = $self->gatherInfo();
	
	#########################################################################
	# Determine a name for this set
	#########################################################################
	# Determine the set number, if there is one. Otherwise make setName = "new set".
	# FIXME:
#	my ($path_info,@components) = $self->gatherInfo();
#	my $setName = $components[0];  # get GET  address for set name

	# Override the setName if it is defined in a form.
#	$setName = $r->param('setName') if defined($r->param('setName'));
	
	
	#########################################################################
	# determine the library set directory 
	#########################################################################
# 	$libraryName = $self->{ce}->{courseDirs}->{templates};
# 	my $setDirectory = $r->param('setDirectory');
#	my $oldSetDirectory = $r->param('oldSetDirectory');
	
	#FIXME:
	# A user can select a new set AND a problem (in the old set) but the problem won't be in the new set!
	# In other words we must prevent the user from changing the problem and the set simultaneously.
	# We solve this by defining a hidden variable oldSetDirectory which matches the currently displayed problem list
	# the problem entry for the textarea element and the viewProblem url are
	# formed using this old version of setDefinition
	
	
	
	# Determine  values for strings
	#########################################################################
	#text area region, adding problems to the list
	#########################################################################
	
	my $textAreaString;
	#FIXME:  -- this does not handle multiple problem selections correctly.
# 	my $problemName = $r->param('pgProblem');
# 	my $problemList = $r->param('problemList');
	
	# Initialize the textarea string if it is empty or hasn't been defined.
	$problemList = $self->gatherProblemList($setName) unless defined($problemList) and $problemList =~/\S/;
	
	my $problemEntry = $oldSetDirectory.'/'.$problemName.", 1, -1 \r\n";
	# add the new problem entry if the address is complete. (still buggy -- how do insure that oldSetDirectory is not empty?
	$problemList .= $problemEntry unless $problemEntry =~ m|^/|;  # don't print if oldSetDirectory name is empy (FIXME: -- more checks are needed?)  
	# format the complete textArea string
	$textAreaString = CGI::textarea({"name"=>"problemList", "cols"=>"40", "rows"=>$rowheight, "default"=>$problemList});
	
	#Determine the headline for the page 
 
	
	#FIXME:   Debugging code
# 	my $header = "Choose problems from $libraryName directory" .
# 		"<p>This form is not yet operational. 
# 		<p>SetDirectory is $setDirectory.  
# 		<p>formURL is $formURL 
# 		<p>path_info  is $path_info";
	my $header = '';

	
	#########################################################################	
	# Define the popup strings used for selecting the library set directory, and the problem from that directory
	#FIXME:
	# he problem of multiple selections needs to be handled properly.
	#########################################################################
	my $popUpSetDirectoryString = $self->fetchSetDirectories($setDirectory);  #pass default choice as current directory
	my $popUpPGProblemString = $self->fetchPGproblems($setDirectory);
	
	
	#########################################################################
	# Define a link to view the problem
	#FIXME:
	# Currently this link used the webwork problem library, which might be out of 
	# sync with the local library
	#########################################################################

	
	my $viewProblemLink;
	if ( (defined($oldSetDirectory) and defined($problemName)) ) {
		$viewProblemLink = "View: "
			. CGI::a({
					"href"=>"http://webhost.math.rochester.edu/webworkdocs/ww/pgView/$oldSetDirectory/$problemName", 
					"target"=>"_probwindow"
				}, "$oldSetDirectory/$problemName");
	} else {
		$viewProblemLink = '';
	
	}
	#########################################################################
	# Format the page
	#########################################################################

	return CGI::p($header)
		#CGI::start_form(-action=>"/webwork/mth143/instructor/problemSetEditor/"),
		. CGI::start_form(-action=>$formURL)
		. CGI::table( {-border=>2},
			CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
				CGI::th('Editing set : ')
				. CGI::td(CGI::textfield(  -name=>'setName',-size=>'20',-value=>$setName,-override=>1))
				. CGI::td(CGI::submit(-name=>'submitButton',-value=>'Save'))
			)
			. CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
				CGI::td($textAreaString)
				. CGI::td($popUpSetDirectoryString)
				. CGI::td($popUpPGProblemString)
			 	
			)
			 #(defined($viewProblemLink)) ? 
			 #	CGI::Tr({"align"=>"center","valign"=>"top"}, CGI::th({"colspan"="3"}, $viewProblemLink)) 
			 #	: '',
			. CGI::Tr( {-align=>'CENTER',-valign=>'TOP'},
				CGI::th([$viewProblemLink,
					CGI::submit(-name=>'submitButton'  , -value =>'Select set'),
					CGI::submit(-name=>'submitButton'  , -value =>'Choose problem')
				])
			)			
			. CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
				CGI::th(["Open date","Due date", "Answer date"])
			)
			. CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
  		 		CGI::td(CGI::textfield(  -name=>'open_date',   -size=>'20', -value=>$openDate))
				. CGI::td(CGI::textfield(-name=>'due_date',    -size=>'20', -value=>$dueDate))
				. CGI::td(CGI::textfield(-name=>'answer_date', -size=>'20', -value=>$answerDate))		 
			)
			. CGI::Tr({"align"=>"center", "valign"=>"top"}, 
				CGI::td({"colspan"=>"3"}, "View entire set (pdf format) -- not yet implemented")
			)
		)
		. $self->hidden_authen_fields
		. CGI::hidden(-name=>'oldSetDirectory', -value=>$setDirectory)
		. CGI::end_form()
#		"<p> the parameters passed are "  #FIXME: -- debugging code
#		. join("<BR>", %{$r->param()}) . $self->gatherProblemList($setName)."setName is $setName"; 
	;

}

sub gatherInfo {
	#FIXME: This is very much hacked together.  In particular can we pass the key inside the post?
	my $self			=	shift;
	my $ce 				= 	$self->{ce};
	my $r				=	$self->{r};
	my $path_info 		= $r->path_info || "";
	
	## Determine the set name
	my $remaining_path 	= $path_info;
	$remaining_path =~ s/^.*problemSetEditor//;
	my($junk, $setName, @components) = split "/", $remaining_path;
	# Override the setName if it is defined in a form.
	$setName = $r->param('setName') if defined($r->param('setName'));
	# FIXME:?? -- this insures backward compatibility with the old file naming convention.
	$setName = "set$setName" unless $setName =~/^set/;
	
	# Find the URL for the form
	$path_info =~s|problemSetEditor.*$|problemSetEditor/|;   # remove the setName, if any, from the path
	my $formURL = "/webwork$path_info";   # . $setName$self->url_authen_args();
	
	#########################################################################
	# determine the library name and set directory 
	#########################################################################
	$libraryName = $ce->{courseDirs}->{templates};
	my $setDirectory = $r->param('setDirectory');
	my $oldSetDirectory = $r->param('oldSetDirectory');
	
	# Determine the problem name
	#FIXME  -- this does not handle multiple problem selections correctly.
	my $problemName = $r->param('pgProblem');
	# Determine the text area string (contents of set definition "file")
	my $problemList = $r->param('problemList');
	
	# get answer dates
	
	my $openDate 	= $r->param('open_date');
	$openDate		= "" unless defined($openDate);	
	my $dueDate 	= $r->param('due_date');
	$dueDate		= "" unless defined($dueDate);	
	my $answerDate 	= $r->param('answer_date');
	$answerDate		= "" unless defined($answerDate);	
	
	($setName,$formURL,$libraryName,$setDirectory,$oldSetDirectory,$problemName,$problemList,$openDate,$dueDate,$answerDate);
}

sub gatherProblemList {   #workaround for obtaining the definition of a problem set (awaiting implementation of db function)
	my $self = shift;
	my $setName = shift;
	my $output = "";
	if ( defined($setName) and $setName ne "" ) {
		my $templateDirectory = $self->{ce}->{courseDirs}->{templates};
		my $fileName = "$templateDirectory/$setName.def";
		my @output =  split("\n",WeBWorK::Utils::readFile($fileName) );
		@output = grep  /\.pg/,   @output;     # only get the .pg files
		@output = grep  !/Header/, @output;   # eliminate header files
		$output = join("\n",@output);
	} else {
		$output = "No set name |$setName| is defined";
	}
	
	
	return  $output




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

	return "$libraryName/" . CGI::br(). CGI::popup_menu(-name=>'setDirectory', -size=>$rowheight,
	 -values=>\@sortedNames, -default=>$defaultChoice ) .CGI::br() ;
}

sub fetchPGproblems {

	my $self = shift;
	my $setDirectory = shift;
	
	# Handle default for setDirectory  
	# FIXME -- this is not bullet proof
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

	return "$setDirectory ". CGI::br() . 
	CGI::popup_menu(-name=>'pgProblem', -size=>$rowheight, -multiple=>undef, -values=>\@sortedNames,  ) . 
	CGI::br() ;
}
1;
