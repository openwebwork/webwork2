package WeBWorK::ContentGenerator::Instructor::ProblemSetEditor;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetEditor - Edit a set definition list

=cut

use strict;
use warnings;
use CGI qw();

sub title {
	my $self = shift;
	return "Instructor Tools - Problem Set Editor for ".$self->{ce}->{courseName};
}

sub body {
	my $self = shift;
	
	# test area
	my $r = $self->{r};
	my $db = $self->{db};
	my $setDirectory = $r->param('setDirectory');
	my $user = $r->param('user');
	my $key = $db->getKey($user)->key();
	
	# Determine the set number, if there is one. Otherwise make setName = "new set".
	# fix me
	my ($path_info,@components) = $self->gatherInfo();
	my $setName = $components[0];  # get GET  address for set name

	# Override the setName if it is defined in a form.
	$setName = $r->param('setName') if defined($r->param('setName'));
	$path_info =~s|problemSetEditor.*$|problemSetEditor/|;   # remove the setName, if any, from the path
	my $formPath = "/webwork$path_info";   # . $setName$self->url_authen_args();
	
	
	
	# Determine  values for strings
	
	#Enter data in the text area region
	my $problem_list = ($r->param('problem_list'))?$r->param('problem_list'): "# Enter problem set definition here\r\n";
	$problem_list .= $setDirectory.'/'.$r->param('pgProblem').", 1 \r\n" if defined($r->param('pgProblem'));  
	my $textAreaString = qq!<textarea name="problem_list", cols="40", rows="20">$problem_list</textarea>!;
	
	
	#Determine the headline for the page   
	#fix me   Debugging code
	my $header = "Choose problems from " . $self->{ce}->{courseDirs}->{templates} . " directory" .
		"<p>This form is not yet operational. 
		<p>SetDirectory is $setDirectory.  
		<p>formPath is $formPath 
		<p>path_info  is $path_info";

	
		
	# Define the popup strings used.
	my $popUpSetDirectoryString = $self->fetchSetDirectories($setDirectory);  #pass default choice as current directory
	my $popUpPGProblemString = $self->fetchPGproblems($setDirectory);
	
	return CGI::p($header),
		#CGI::start_form(-action=>"/webwork/mth143/instructor/problemSetEditor/"),
		CGI::start_form(-action=>$formPath),
		CGI::table( {-border=>2},
			CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
				CGI::th('Editing set : '),
				CGI::td(CGI::textfield(  -name=>'definitionName',-size=>'20',-value=>$setName,-override=>1)), 
				CGI::td(CGI::submit(-name=>'Save',-value=>'save'))
			),
			CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
				CGI::td($textAreaString),
				CGI::td($popUpSetDirectoryString), 
				CGI::td($popUpPGProblemString)
             	
            ),
            CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
            	CGI::th(["Open date","Due date", "Answer date"]),
            
            ),
            CGI::Tr({-align=>'CENTER',-valign=>'TOP'},
  		 		CGI::td(CGI::textfield(-name=>'open_date', -size=>'20') ),
            	CGI::td(CGI::textfield(-name=>'due_date', -size=>'20') ),
            	CGI::td(CGI::textfield(-name=>'answer_date', -size=>'20') ),             
            )
        ),
        CGI::hidden(-name=>'user', -value=>$user),
        CGI::hidden(-name=>'key',-value=>$key),
#        CGI::textfield(-name=>'setName',-value=>'bar'),
#         CGI::hidden(-name=>'gage',-value=>'mike'),
#         CGI::submit(),
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
# 	my %labels;
# 	for $ind (@sortedNames) {
# 		$fileName = "${templateDirectory}$ind";
# 			if (-e $fileName) {
# 				@stat = stat($fileName);
# 				$date = $stat[9];
# 				$date = formatDateAndTime($date);
# 				$date =~ s|\s*at.*||;
# 				$label = "  Last Changed $date";
# 			}
# 		$labels{$ind} = "$ind"; # $label";
# 	}

return CGI::popup_menu(-name=>'setDirectory', -size=>20,
	 -values=>\@sortedNames, -default=>$defaultChoice ) .CGI::br() .
	  CGI::submit(-name=>'select_set'  , -value =>'Select set')  ;
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
	for $ind (@sortedNames) {
		$fileName = "${templateDirectory}$ind";
			if (-e $fileName) {
				@stat = stat($fileName);
				$date = $stat[9];
				$date = formatDateAndTime($date);
				$date =~ s|\s*at.*||;
				$label = "  Last Changed $date";
			}
		$labels{$ind} = "$ind"; # $label";
	}

return "$setDirectory <br> ".  
	CGI::popup_menu(-name=>'pgProblem', -size=>20, -multiple=>undef, -values=>\@sortedNames, -labels=>\%labels ) . 
	CGI::br() . 
	CGI::submit(-name=>'view_problem'  , -value =>'View problem') . CGI::br() .
	CGI::submit(-name=>'choose_problem'  , -value =>'Choose problem')  ;
}
1;
