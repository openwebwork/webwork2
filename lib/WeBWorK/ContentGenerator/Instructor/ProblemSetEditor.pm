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
	my $initialData = "Enter problem set definition here";
	my $textAreaString = qq!<textarea cols="40", rows="20">$initialData</textarea>!;
	my $header = "Choose problems from " . $self->{ce}->{courseDirs}->{templates} . " directory" .
		"<p>This form is not yet operational";
	my $popUpSetDirectoryString = $self->fetchSetDirectories();
	my $popUpPGProblemString = $self->fetchPGproblems();
	return CGI::p($header),
		CGI::start_form(),
		CGI::table( {-border=>2},
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
        CGI::p( "Save set definition file ".CGI::submit(-name=>'Save',-value=>'save') ),
		CGI::end_form()
	;

}


sub fetchSetDirectories {

	my $self = shift;
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
	 -values=>\@sortedNames,  ) .CGI::br() .
	  CGI::submit(-name=>'select_set'  , -value =>'Select set')  ;
}

sub fetchPGproblems {

	my $self = shift;
	my $templateDirectory = $self->{ce}->{courseDirs}->{templates};
	
	## fix me.  We need to get the current set Directory.
	my $setDirectory = 'setAlgebra10Intervals';
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

return "$setDirectory <br> ".  CGI::popup_menu(-name=>'pgProblems', -size=>20, -multiple=>undef,
	 -values=>\@sortedNames, -labels=>\%labels ) . CGI::br() . 
	    CGI::submit(-name=>'view_problem'  , -value =>'View problem') . CGI::br() .
	    CGI::submit(-name=>'choose_problem'  , -value =>'Choose problem')  ;
}
1;
