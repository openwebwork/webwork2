package WeBWorK::ContentGenerator::Instructor::PGProblemEditor;
use base qw(WeBWorK::ContentGenerator::Instructor);


=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetEditor - Edit a set definition list

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Utils qw(readFile);

our $libraryName;
our $rowheight;

sub title {
	my $self = shift;
	return "Instructor Tools - PG Problem Editor for ?????";
}

sub body {
	my $self = shift;
	
	# test area
	my $r = $self->{r};
	my $db = $self->{db};
	
	my $user = $r->param('user');
	my $key = $db->getKey($user)->key();
	
	
	################
	# Gathering info
	# What is needed
	#     $problemPath  -- 
	#     $formURL -- the action URL for the form 
	#     $tmpProblemPath 
	my ($problemPath,$formURL,$tmpProblemPath) = $self->initialize();
	

	
	

	my $header = 'Problem Editor';

	
	#########################################################################	
	# Define the popup strings used for selecting the library set directory, and the problem from that directory
	#fix me
	# he problem of multiple selections needs to be handled properly.
	#########################################################################
#	my $popUpSetDirectoryString = $self->fetchSetDirectories($setDirectory);  #pass default choice as current directory
#	my $popUpPGProblemString = $self->fetchPGproblems($setDirectory);
	
	
	#########################################################################
	# Define a link to view the problem
	#fix me:
	# Currently this link used the webwork problem library, which might be out of 
	# sync with the local library
	#########################################################################

	

	#########################################################################
	# Format the page
	#########################################################################
	           
	return CGI::p($header),
		
		"<p> the parameters passed are "  #fix me -- debugging code
		. join("<BR>", %{$r->param()}) . 
		"</p> and the gatheredInfo is ",
		join("<br>",$self->initialize() ), 
	;

}

sub initialize {
	#fix me.  This is very much hacked together.  In particular can we pass the key inside the post?
	my ($self, @path_components) = @_;
	my $ce 				= 	$self->{ce};
	my $r				=	$self->{r};
	my $path_info 		= $r->path_info || "";
	
	## Determine the set name
	my $remaining_path 	= $path_info;
	$remaining_path =~ s/^.*pgProblemEditor//;
	my($junk,  @components) = split "/", $remaining_path;
	my $problemPath = $remaining_path;	
	# Find the URL for the form
	$path_info =~s|pgProblemEditor.*$|pgProblemEditor/|;   # remove trailing info, if any, from the path
	my $formURL = "/webwork$path_info";   
	
	my $tmpProblemPath = "unknown";
	
	($problemPath,$formURL,$tmpProblemPath);
}

# sub gatherProblemList {   #workaround for obtaining the definition of a problem set (awaiting implementation of db function)
# 	my $self = shift;
# 	my $setName = shift;
# 	my $output = "";
# 	if ( defined($setName) and $setName ne "" ) {
# 		my $templateDirectory = $self->{ce}->{courseDirs}->{templates};
# 		my $fileName = "$templateDirectory/$setName.def";
# 		my @output =  split("\n",WeBWorK::Utils::readFile($fileName) );
# 		@output = grep  /\.pg/,   @output;     # only get the .pg files
# 		@output = grep  !/Header/, @output;   # eliminate header files
# 		$output = join("\n",@output);
# 	} else {
# 		$output = "No set name |$setName| is defined";
# 	}
# 	
# 	
# 	return  $output
# 
# 
# 
# 
# }
# sub fetchSetDirectories {
# 
# 	my $self = shift;
# 	my $defaultChoice = shift;
# 	my $templateDirectory = $self->{ce}->{courseDirs}->{templates};
# 	opendir SETDEFDIR, $templateDirectory 
# 		or return "Can't open directory $templateDirectory";
# 	
# 	my @allFiles = grep !/^\./, readdir SETDEFDIR;
# 	closedir  SETDEFDIR;
# 
# 	## filter to find only the set directories 
# 	## -- it is assumed that these directories don't contain a period in their names
# 	## and that all other files do.  Directories names must also begin with "set".
# 	## A better plan would be to read only the names of directories, not files.
# 	
# 	## sort the directories
# 	my @setDefFiles = grep /^set[^\.]*$/, @allFiles;
# 	my @sortedNames = sort @setDefFiles;
# 
# 	return "$libraryName/" . CGI::br(). CGI::popup_menu(-name=>'setDirectory', -size=>$rowheight,
# 	 -values=>\@sortedNames, -default=>$defaultChoice ) .CGI::br() ;
# }
# 
# sub fetchPGproblems {
# 
# 	my $self = shift;
# 	my $setDirectory = shift;
# 	
# 	# Handle default for setDirectory  
# 	# fix me -- this is not bullet proof
# 	$setDirectory = "set0" unless defined($setDirectory);
# 	my $templateDirectory = $self->{ce}->{courseDirs}->{templates};
# 	
# 	## 
# 	opendir SETDEFDIR, "$templateDirectory/$setDirectory" 
# 		or return "Can't open directory $templateDirectory/$setDirectory";
# 	
# 	my @allFiles = grep !/^\./, readdir SETDEFDIR;
# 	closedir  SETDEFDIR;
# 
# 	## filter to find only pg problems 
# 	## Some problems are themselves in directories (if they have auxiliary
# 	## .png's for example.  This eventuallity needs to be handled.
# 	
# 	## sort the directories
# 	my @pgFiles = grep /\.pg$/, @allFiles;
# 	my @sortedNames = sort @pgFiles;
# 
# 	return "$setDirectory ". CGI::br() . 
# 	CGI::popup_menu(-name=>'pgProblem', -size=>$rowheight, -multiple=>undef, -values=>\@sortedNames,  ) . 
# 	CGI::br() ;
# }

1;
