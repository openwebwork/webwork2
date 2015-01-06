################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Instructor/SetMaker.pm,v 1.85 2008/07/01 13:18:52 glarose Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.	 See either the GNU General Public License or the
# Artistic License for more details.
################################################################################


package WeBWorK::ContentGenerator::Instructor::SetMaker2;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::SetMaker2 - Make homework sets.

=cut

use strict;
use warnings;


#use CGI qw(-nosticky);
use WeBWorK::CGI;
use WeBWorK::Debug;
use WeBWorK::Form;
use WeBWorK::Utils qw(readDirectory max sortByName);
use WeBWorK::Utils::Tasks qw(renderProblems);
use File::Find;

require WeBWorK::Utils::ListingDB;

use constant SHOW_HINTS_DEFAULT => 0;
use constant SHOW_SOLUTIONS_DEFAULT => 0;
use constant MAX_SHOW_DEFAULT => 20;
use constant NO_LOCAL_SET_STRING => 'No sets in this course yet';
use constant SELECT_SET_STRING => 'Select a Set from this Course';
use constant SELECT_LOCAL_STRING => 'Select a Problem Collection';
use constant MY_PROBLEMS => '  My Problems  ';
use constant MAIN_PROBLEMS => '  Unclassified Problems  ';
use constant CREATE_SET_BUTTON => 'Create New Set';
use constant ALL_CHAPTERS => 'All Chapters';
use constant ALL_SUBJECTS => 'All Subjects';
use constant ALL_SECTIONS => 'All Sections';
use constant ALL_TEXTBOOKS => 'All Textbooks';

use constant LIB2_DATA => {
  'dbchapter' => {name => 'library_chapters', all => 'All Chapters'},
  'dbsection' =>  {name => 'library_sections', all =>'All Sections' },
  'dbsubject' =>  {name => 'library_subjects', all => 'All Subjects' },
  'textbook' =>  {name => 'library_textbook', all =>  'All Textbooks'},
  'textchapter' => {name => 'library_textchapter', all => 'All Chapters'},
  'textsection' => {name => 'library_textsection', all => 'All Sections'},
  'keywords' =>  {name => 'library_keywords', all => '' },
  };

## Flags for operations on files

use constant ADDED => 1;
use constant HIDDEN => (1 << 1);
use constant SUCCESS => (1 << 2);
use constant DELETED => (1 << 3);
use constant MOVED => (1 << 4);

##	for additional problib buttons
my %problib;	## this is configured in defaults.config
my %ignoredir = (
	'.' => 1, '..' => 1, 'Library' => 1, 'CVS' => 1, 'tmpEdit' => 1,
	'headers' => 1, 'macros' => 1, 'email' => 1, '.svn' => 1,
);

sub prepare_activity_entry {
	my $self=shift;
	my $r = $self->r;
	my $user = $self->r->param('user') || 'NO_USER';
	return("In SetMaker2 as user $user");
}

## This is for searching the disk for directories containing pg files.
## to make the recursion work, this returns an array where the first 
## item is the number of pg files in the directory.  The second is a
## list of directories which contain pg files.
##
## If a directory contains only one pg file and the directory name
## is the same as the file name, then the directory is considered
## to be part of the parent directory (it is probably in a separate
## directory only because it has auxiliary files that want to be
## kept together with the pg file).
##
## If a directory has a file named "=library-ignore", it is never
## included in the directory menu.  If a directory contains a file
## called "=library-combine-up", then its pg are included with those
## in the parent directory (and the directory does not appear in the
## menu).  If it has a file called "=library-no-combine" then it is
## always listed as a separate directory even if it contains only one
## pg file.

sub get_library_sets {
	my $top = shift; my $dir = shift;
	# ignore directories that give us an error
	my @lis = eval { readDirectory($dir) };
	if ($@) {
		warn $@;
		return (0);
	}
	return (0) if grep /^=library-ignore$/, @lis;

	my @pgfiles = grep { m/\.pg$/ and (not m/(Header|-text)\.pg$/) and -f "$dir/$_"} @lis;
	my $pgcount = scalar(@pgfiles);
	my $pgname = $dir; $pgname =~ s!.*/!!; $pgname .= '.pg';
	my $combineUp = ($pgcount == 1 && $pgname eq $pgfiles[0] && !(grep /^=library-no-combine$/, @lis));

	my @pgdirs;
	my @dirs = grep {!$ignoredir{$_} and -d "$dir/$_"} @lis;
	if ($top == 1) {@dirs = grep {!$problib{$_}} @dirs}
	foreach my $subdir (@dirs) {
		my @results = get_library_sets(0, "$dir/$subdir");
		$pgcount += shift @results; push(@pgdirs,@results);
	}

	return ($pgcount, @pgdirs) if $top || $combineUp || grep /^=library-combine-up$/, @lis;
	return (0,@pgdirs,$dir);
}

sub get_library_pgs {
	my $top = shift; my $base = shift; my $dir = shift;
	my @lis = readDirectory("$base/$dir");
	return () if grep /^=library-ignore$/, @lis;
	return () if !$top && grep /^=library-no-combine$/, @lis;

	my @pgs = grep { m/\.pg$/ and (not m/(Header|-text)\.pg$/) and -f "$base/$dir/$_"} @lis;
	my $others = scalar(grep { (!m/\.pg$/ || m/(Header|-text)\.pg$/) &&
	                            !m/(\.(tmp|bak)|~)$/ && -f "$base/$dir/$_" } @lis);

	my @dirs = grep {!$ignoredir{$_} and -d "$base/$dir/$_"} @lis;
	if ($top == 1) {@dirs = grep {!$problib{$_}} @dirs}
	foreach my $subdir (@dirs) {push(@pgs, get_library_pgs(0,"$base/$dir",$subdir))}

	return () unless $top || (scalar(@pgs) == 1 && $others) || grep /^=library-combine-up$/, @lis;
	return (map {"$dir/$_"} @pgs);
}

sub list_pg_files {
	my ($templates,$dir) = @_;
	my $top = ($dir eq '.')? 1 : 2;
	my @pgs = get_library_pgs($top,$templates,$dir);
	return sortByName(undef,@pgs);
}

## Search for set definition files

sub get_set_defs {
	my $topdir = shift;
	my @found_set_defs;
	# get_set_defs_wanted is a closure over @found_set_defs
	my $get_set_defs_wanted = sub {
		#my $fn = $_;
		#my $fdir = $File::Find::dir;
		#return() if($fn !~ /^set.*\.def$/);
		##return() if(not -T $fn);
		#push @found_set_defs, "$fdir/$fn";
		push @found_set_defs, $_ if m|/set[^/]*\.def$|;
	};
	find({ wanted => $get_set_defs_wanted, follow_fast=>1, no_chdir=>1}, $topdir);
	map { $_ =~ s|^$topdir/?|| } @found_set_defs;
	return @found_set_defs;
}

## Try to make reading of set defs more flexible.  Additional strategies
## for fixing a path can be added here.

sub munge_pg_file_path {
	my $self = shift;
	my $pg_path = shift;
	my $path_to_set_def = shift;
	my $end_path = $pg_path;
	# if the path is ok, don't fix it
	return($pg_path) if(-e $self->r->ce->{courseDirs}{templates}."/$pg_path");
	# if we have followed a link into a self contained course to get
	# to the set.def file, we need to insert the start of the path to
	# the set.def file
	$end_path = "$path_to_set_def/$pg_path";
	return($end_path) if(-e $self->r->ce->{courseDirs}{templates}."/$end_path");
	# if we got this far, this path is bad, but we let it produce
	# an error so the user knows there is a troublesome path in the
	# set.def file.
	return($pg_path);
}

## Read a set definition file.  This could be abstracted since it happens
## elsewhere.  Here we don't have to process so much of the file.

sub read_set_def {
	my $self = shift;
	my $r = $self->r;
	my $filePathOrig = shift;
	my $filePath = $r->ce->{courseDirs}{templates}."/$filePathOrig";
	$filePathOrig =~ s/set.*\.def$//;
	$filePathOrig =~ s|/$||;
	$filePathOrig = "." if ($filePathOrig !~ /\S/);
	my @pg_files = ();
	my ($line, $got_to_pgs, $name, @rest) = ("", 0, "");
	if ( open (SETFILENAME, "$filePath") )    {
		while($line = <SETFILENAME>) {
		    chomp($line);
		    $line =~ s|(#.*)||; # don't read past comments
		    if($got_to_pgs == 1) {
			unless ($line =~ /\S/) {next;} # skip blank lines
			($name,@rest) = split (/\s*,\s*/,$line);
			$name =~ s/\s*//g;
			push @pg_files, $name;
		    } elsif ($got_to_pgs == 2) {
			# skip lines which dont identify source files
			unless ($line =~ /source_file\s*=\s*(\S+)/) {
			    next;
			}
			# otherwise we got the name from the regexp
			push @pg_files, $1;
		    } else {
			$got_to_pgs = 1 if ($line =~ /problemList\s*=/);
			$got_to_pgs = 2 if ($line =~ /problemListV2/);
		    }
		}
	} else {
		$self->addbadmessage("Cannot open $filePath");
	}
	# This is where we would potentially munge the pg file paths
	# One possibility
	@pg_files = map { $self->munge_pg_file_path($_, $filePathOrig) } @pg_files;
	return(@pg_files);
}

## go through past page getting a list of identifiers for the problems
## and whether or not they are selected, and whether or not they should
## be hidden

sub get_past_problem_files {
	my $r = shift;
	my @found=();
	my $count =1;
	while (defined($r->param("filetrial$count"))) {
		my $val = 0;
		$val |= ADDED if($r->param("trial$count"));
		$val |= HIDDEN if($r->param("hideme$count"));
		$val |= MOVED if($r->param("moved$count"));
		push @found, [$r->param("filetrial$count"), $val];			
		$count++;
	}
	$count = 1;
	while (defined($r->param("mysetfiletrial$count"))) {
	  my $val = 0;
	  $val |= DELETED if($r->param("deleted$count"));
	  push @found, [$r->param("mysetfiletrial$count"), $val];
	  $count++;
	}
	return(\@found);
}

#### For adding new problems

sub add_selected {
	my $self = shift;
	my $db = shift;
	my $setName = shift;
	my @past_problems = @{$self->{past_problems}};
	my @selected = @past_problems;
	my (@path, $file, $selected, $freeProblemID);
	# DBFIXME count would work just as well
	$freeProblemID = max($db->listGlobalProblems($setName)) + 1;
	my $addedcount=0;

	for $selected (@selected) {
		if($selected->[1] & ADDED || $selected->[1] & MOVED) {
			$file = $selected->[0];
			#print "$file";
			my $problemRecord = $self->addProblemToSet(setName => $setName,
				sourceFile => $file, problemID => $freeProblemID);
			$freeProblemID++;
			$self->assignProblemToAllSetUsers($problemRecord);
			if(!($selected->[1] & MOVED)){
			  $selected->[1] |= SUCCESS;
			}
			$addedcount++;
		}
	}
	return($addedcount);
}

sub delete_selected {
	my $self = shift;
	my $db = shift;
	my $setName = shift;
	my @past_problems = @{$self->{past_problems}};
	my @selected = @past_problems;
	my (@path, $file, $selected);
	# DBFIXME count would work just as well
	my $deletedcount=0;

	for $selected (@selected) {
		if($selected->[1] & DELETED || $selected->[1] & MOVED) {
		  foreach my $problem ($db->listGlobalProblems($setName)) {
			  my $problemRecord = $db->getGlobalProblem($setName, $problem);
			  if($problemRecord->source_file eq $selected->[0]){
			    $db->deleteGlobalProblem($setName, $problemRecord->problem_id);
			  }
		  }
		  if(!($selected->[1] & MOVED)){
			  $selected->[1] |= SUCCESS;
			}
			$deletedcount++;
		}
	}
	return($deletedcount);
}

##order the problems as they are after user reorder
sub reorderProblems {
  my $self = shift;
	my $db = shift;
	my $setID = shift;
	my $r = shift;
	#my (@problemIDList) = @_;
	#my ($prob1, $prob2, $prob);
	my $index = 1;
	#get all the problems
	my @problems = ();
	while (defined($r->param("reorder$index"))) {
	  #this will work if i can get problems by name
		my $problemRecord; # checked
		foreach my $problem ($db->listGlobalProblems($setID)) {
			my $tempProblem = $db->getGlobalProblem($setID, $problem);
		  if($tempProblem->source_file eq $r->param("reorder$index")){
		    $problemRecord = $tempProblem;
		  }
		}
		die "global " .$r->param("reorder$index") ." for set $setID not found." unless $problemRecord;
		#print "found this problem to be reordered: ".$problemRecord."\n";
		push @problems, $problemRecord;
	  $index = $index + 1;
	}
	#then change their info
	my @setUsers = $db->listSetUsers($setID);
	my $user;
	$index = 1;
	foreach my $problem (@problems) {
	  $problem->problem_id($index);
	  die "global $problem not found." unless $problem;
	  #print "problem to be reordered: ".$problem."\n";
	  $db->putGlobalProblem($problem);
	  
	  #need to deal with users?
	  foreach $user (@setUsers) {
  		my $prob1 = $db->getUserProblem($user, $setID, $index); #checked
		  die " problem $index for set $setID and effective user $user not found"	unless $prob1;
      $prob1->problem_id($index);
  		$db->putUserProblem($prob1);
	  }
	  $index = $index + 1;
	}
}

############# List of sets of problems in templates directory

sub get_problem_directories {
	my $ce = shift;
	my $lib = shift;
	my $source = $ce->{courseDirs}{templates};
	my $main = MY_PROBLEMS; my $isTop = 1;
	if ($lib) {$source .= "/$lib"; $main = MAIN_PROBLEMS; $isTop = 2}
	my @all_problem_directories = get_library_sets($isTop, $source);
	my $includetop = shift @all_problem_directories;
	my $j;
	for ($j=0; $j<scalar(@all_problem_directories); $j++) {
		$all_problem_directories[$j] =~ s|^$ce->{courseDirs}->{templates}/?||;
	}
	@all_problem_directories = sortByName(undef, @all_problem_directories);
	unshift @all_problem_directories, $main if($includetop);
	return (\@all_problem_directories);
}

############# Everyone has a view problems line.	Abstract it
sub view_problems_line {
	my $internal_name = shift;
	my $label = shift;
	my $r = shift; # so we can get parameter values
	my $self = shift;
	my $urlpath = $r->urlpath;
  my $getProblemPath = $self->systemLink($urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::GetLibrarySetProblems", $r, courseID =>$urlpath->arg("courseID")));
	my $result = "<span><button type='button' onclick='viewProblems(\"$internal_name\" ,\"mainform\", \"".$r->uri."\", \"view_problems_spinner\");'>$label</button><img id='view_problems_spinner' style='display:none;' src='/webwork2_files/images/ajax-loader-small.gif'></img></span>";
	#$result .= CGI::hidden(-name=>"$internal_name");
	my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
	my @active_modes = grep { exists $display_modes{$_} }
		@{$r->ce->{pg}->{displayModes}};
	push @active_modes, 'None';
	# We have our own displayMode since its value may be None, which is illegal
	# in other modules.
	my $mydisplayMode = $r->param('mydisplayMode') || $r->ce->{pg}->{options}->{displayMode};
	$result .= '&nbsp;Display&nbsp;Mode:&nbsp;'.CGI::popup_menu(-name=> 'mydisplayMode',
	                                                            -values=>\@active_modes,
	                                                            -default=> $mydisplayMode);
	# Now we give a choice of the number of problems to show
	my $defaultMax = $r->param('max_shown') || MAX_SHOW_DEFAULT;
	$result .= '&nbsp;Max. Shown:&nbsp'.
		CGI::popup_menu(-name=> 'max_shown',
		                -values=>[5,10,15,20,25,30,50,'All'],
		                -default=> $defaultMax);
	# Option of whether to show hints and solutions
	my $defaultHints = $r->param('showHints') || SHOW_HINTS_DEFAULT;
	$result .= "&nbsp;".CGI::checkbox(-name=>"showHints",-checked=>$defaultHints,-label=>"Hints");
	my $defaultSolutions = $r->param('showSolutions') || SHOW_SOLUTIONS_DEFAULT;
	$result .= "&nbsp;".CGI::checkbox(-name=>"showSolutions",-checked=>$defaultSolutions,-label=>"Solutions");
	
	return($result);
}


### The browsing panel has three versions
#####	 Version 1 is local problems
sub browse_local_panel {
	my $self = shift;
	my $library_selected = shift;
	my $lib = shift || ''; $lib =~ s/^browse_//;
	my $name = ($lib eq '')? 'Local' : $problib{$lib};
    
	my $list_of_prob_dirs= get_problem_directories($self->r->ce,$lib);
	if(scalar(@$list_of_prob_dirs) == 0) {
		$library_selected = "Found no directories containing problems";
		unshift @{$list_of_prob_dirs}, $library_selected;
	} else {
		my $default_value = SELECT_LOCAL_STRING;
		if (not $library_selected or $library_selected eq $default_value) {
			unshift @{$list_of_prob_dirs},	$default_value;
			$library_selected = $default_value;
		}
	}
	debug("library is $lib and sets are $library_selected");
	my $view_problem_line = view_problems_line('view_local_set', 'View Problems', $self->r, $self);
	my @popup_menu_args = (
	  -size => 4,
		-name => 'library_sets',
		-values => $list_of_prob_dirs,
		-default => $library_selected,
	);
	# make labels without the $lib prefix -- reduces the width of the popup menu
	if (length($lib)) {
		my %labels = map { my($l)=$_=~/^$lib\/(.*)$/;$_=>$l } @$list_of_prob_dirs;
		push @popup_menu_args, -labels => \%labels;
	}
	print CGI::div({-class=>"InfoPanel", -align=>"left"}, "<p style='margin-bottom:0'>$name Problems: </p>",
		              CGI::popup_menu(@popup_menu_args),
		              CGI::br(), 
		              $view_problem_line,
	);
}

#####	 Version 2 is local homework sets
sub browse_mysets_panel {
	my $self = shift;
	my $library_selected = shift;
	my $list_of_local_sets = shift;
	my $remember_local_set = shift;
	my $default_value = "Select a Homework Set";

	if(scalar(@$list_of_local_sets) == 0) {
		$list_of_local_sets = [NO_LOCAL_SET_STRING];
	} elsif (not $library_selected or $library_selected eq $default_value) { 
		unshift @{$list_of_local_sets},	 $default_value; 
		$library_selected = $default_value; 
	} 
  
	my $view_problem_line = view_problems_line('view_mysets_set', 'View Problems', $self->r, $self);
	
	my $urlpath = $self->r->urlpath;
  my $getProblemPath = $self->r->uri;#$self->systemLink($urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::GetTargetSetProblems", $r, courseID =>$urlpath->arg("courseID")));
	print CGI::div({-class=>"InfoPanel", -align=>"left"},
	  #CGI::submit(-name=>"update", -style=>"width: 25ex; font-weight:bold;", -value=>"Update Set"),
	  '<span>',
		CGI::popup_menu(-id=> 'myset_sets',
		                -name=> 'myset_sets', 
		                -size=>6,
		                -onchange=>"viewSet(\'mainform\', \'$getProblemPath\', \'view_set_spinner\');",
		                -values=>$list_of_local_sets, 
		                -default=> $library_selected),
		"<img id='view_set_spinner' style='display:none;' src='/webwork2_files/images/ajax-loader-small.gif'></img></span>",
	  "<button type='button' onclick='document.getElementById(\"create_new_set\").style.display = \"block\";'>+</button>",
		CGI::hidden(-name=> 'local_sets', -value=>$remember_local_set),
		CGI::br(), 
		"<span>",
		#'<button type="button" onclick="viewSet(\'mainform\', \'/webwork2/myTestCourse/instructor/setmaker2/\');">View Set</button>',
		#CGI::submit(-name=>"view_mysets_set", -value=>"View Set"),
		"<span id='problem_counter' style='float:right;'>0</span>",
		"</span>"
	);
}

#####	 Version 2.1 is local homework sets
sub edit_mysets_panel {
	my $self = shift;
	my $library_selected = shift;
	my $list_of_local_sets = shift;
	my $default_value = "Select a Homework Set";

	if(scalar(@$list_of_local_sets) == 0) {
		$list_of_local_sets = [NO_LOCAL_SET_STRING];
	} elsif (not $library_selected or $library_selected eq $default_value) { 
		unshift @{$list_of_local_sets},	 $default_value; 
		$library_selected = $default_value; 
	} 

	my $view_problem_line = view_problems_line('edit_mysets_set', 'View Problems', $self->r, $self);
	print CGI::Tr({},
		CGI::td({-class=>"InfoPanel", -align=>"left"}, "<p style='margin-bottom:0;'>Browse from:</p>",
		CGI::popup_menu(-name=> 'library_sets', 
		                -size=> 4,
		                -values=>$list_of_local_sets, 
		                -default=> $library_selected),
		CGI::br(), 
		$view_problem_line
	));
}

#####	 Version 3 is the problem library
# 
# This comes in 3 forms, problem library version 1, and for version 2 there
# is the basic, and the advanced interfaces.  This function checks what we are
# supposed to do, or aborts if the problem library has not been installed.

sub browse_library_panel {
	my $self=shift;
	my $r = $self->r;
	my $ce = $r->ce;

	# See if the problem library is installed
	my $libraryRoot = $r->{ce}->{problemLibrary}->{root};

	unless($libraryRoot) {
		print CGI::div({class=>'ResultsWithError', align=>"center"}, 
			"The problem library has not been installed.");
		return;
	}
	# Test if the Library directory link exists.  If not, try to make it
	unless(-d "$ce->{courseDirs}->{templates}/Library") {
		unless(symlink($libraryRoot, "$ce->{courseDirs}->{templates}/Library")) {
			my $msg =	 <<"HERE";
You are missing the directory <code>templates/Library</code>, which is needed
for the Problem Library to function.	It should be a link pointing to
<code>$libraryRoot</code>, which you set in <code>conf/site.conf</code>.
I tried to make the link for you, but that failed.	Check the permissions
in your <code>templates</code> directory.
HERE
			$self->addbadmessage($msg);
		}
	}

	# Now check what version we are supposed to use
	my $libraryVersion = $r->{ce}->{problemLibrary}->{version} || 1;
	if($libraryVersion == 1) {
		return $self->browse_library_panel1;
	} elsif($libraryVersion >= 2) {
		return $self->browse_library_panel2	if($self->{library_basic}==1);
		return $self->browse_library_panel2adv;
	} else {
		print CGI::div({class=>'ResultsWithError', align=>"center"}, 
			"The problem library version is set to an illegal value.");
		return;
	}
}

sub browse_library_panel1 {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	
	my @chaps = WeBWorK::Utils::ListingDB::getAllChapters($r->{ce});
	unshift @chaps, LIB2_DATA->{dbchapter}{all};
	my $chapter_selected = $r->param('library_chapters') || LIB2_DATA->{dbchapter}->{all};

	my @sects=();
	if ($chapter_selected ne LIB2_DATA->{dbchapter}{all}) {
		@sects = WeBWorK::Utils::ListingDB::getAllSections($r->{ce}, $chapter_selected);
	}

	unshift @sects, ALL_SECTIONS;
	my $section_selected =	$r->param('library_sections') || LIB2_DATA->{dbsection}{all};

	my $view_problem_line = view_problems_line('lib_view', 'View Problems', $self->r, $self);

	print CGI::div({-class=>"InfoPanel", -align=>"left"},
				CGI::div(["Chapter:",
					CGI::popup_menu(-name=> 'library_chapters', 
					                -size=>4,
					                -values=>\@chaps,
					                -default=> $chapter_selected,
					                -onchange=>"updateLibCategories(\'mainform\', \'".$r->uri."\', \'null\',\'view_problems_spinner\')"
					),
					CGI::submit(-name=>"lib_select_chapter", -value=>"Update Section List")]),
				CGI::div("Section:", 
					CGI::popup_menu(-name=> 'library_sections', 
					                -values=>\@sects,
					                -default=> $section_selected
			)),
			CGI::div($view_problem_line)
		);
}

sub browse_library_panel2 {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;

	my @subjs = WeBWorK::Utils::ListingDB::getAllDBsubjects($r);
	unshift @subjs, LIB2_DATA->{dbsubject}{all};

	my @chaps = WeBWorK::Utils::ListingDB::getAllDBchapters($r);
	unshift @chaps, LIB2_DATA->{dbchapter}{all};

	my @sects=();
	@sects = WeBWorK::Utils::ListingDB::getAllDBsections($r);
	unshift @sects, LIB2_DATA->{dbsection}{all};

	my $subject_selected = $r->param('library_subjects') || LIB2_DATA->{dbsubject}{all};
	my $chapter_selected = $r->param('library_chapters') || LIB2_DATA->{dbchapter}{all};
	my $section_selected =	$r->param('library_sections') || LIB2_DATA->{dbsection}{all};

	my $view_problem_line = view_problems_line('lib_view', 'View Problems', $self->r, $self);

	my $count_line = WeBWorK::Utils::ListingDB::countDBListings($r);
	if($count_line==0) {
		$count_line = "There are no matching pg files";
	} else {
		$count_line = "There are $count_line matching WeBWorK problem files";
	}

	print CGI::div({-class=>"InfoPanel", -align=>"left"}, 
		CGI::hidden(-name=>"library_is_basic", -default=>1,-override=>1),
		CGI::div({-style=>"float:left;"},"<p style='margin-bottom:0'>Subject:</p>",
				CGI::popup_menu(-name=> 'library_subjects', 
				              -size=>4,
					            -values=>\@subjs,
					            -default=> $subject_selected,
					             -onchange=>"updateLibCategories(\'mainform\', \'".$r->uri."\', \'null\',\'view_problems_spinner\')"
		)),
		CGI::div({-style=>"float:left;"},"<p style='margin-bottom:0'>Chapter:</p>",
		  CGI::popup_menu(-name=> 'library_chapters', 
		                  -size=>4,
					            -values=>\@chaps,
					            -default=> $chapter_selected,
					             -onchange=>"updateLibCategories(\'mainform\', \'".$r->uri."\', \'null\',\'view_problems_spinner\')"
		)),
	  CGI::div({-style=>"float:left;"},"<p style='margin-bottom:0'>Section:</p>",
			CGI::popup_menu(-name=> 'library_sections', 
			            -size=>4,
					        -values=>\@sects,
					        -default=> $section_selected,
							-onchange=>"updateLibCategories(\'mainform\', \'".$r->uri."\', \'null\',\'view_problems_spinner\')"
		)),
		'<div colspan=2 align="right">',
		  '<button type="button" onclick="updateLibCategories(\'mainform\', \''.$r->uri.'\', \'library_advanced\', \'view_problems_spinner\')">Advanced Search</button>',
		'</div>',
		'<div colspan=2 align="right">',
		  '<button type="button" onclick="updateLibCategories(\'mainform\', \''.$r->uri.'\', \'lib_select_subject\', \'view_problems_spinner\')">Update Chapter/Section Lists</button>',
		'</div>',
		#CGI::div({-colspan=>2, -align=>"right"},
		#  CGI::submit(-name=>"library_advanced", -value=>"Advanced Search")),
		#CGI::div({-colspan=>2, -align=>"right"},
		#  CGI::submit(-name=>"lib_select_subject", -value=>"Update Chapter/Section Lists")),
		'<div style="clear:both;"></div>',
		CGI::div({-colspan=>3}, $view_problem_line),
		CGI::div({-colspan=>3, -align=>"center"}, $count_line)
	 );
	
}

sub browse_library_panel2adv {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $right_button_style = "width: 18ex";

	my @subjs = WeBWorK::Utils::ListingDB::getAllDBsubjects($r);
	if(! grep { $_ eq $r->param('library_subjects') } @subjs) {
		$r->param('library_subjects', '');
	}
	unshift @subjs, LIB2_DATA->{dbsubject}{all};

	my @chaps = WeBWorK::Utils::ListingDB::getAllDBchapters($r);
	if(! grep { $_ eq $r->param('library_chapters') } @chaps) {
		$r->param('library_chapters', '');
	}
	unshift @chaps, LIB2_DATA->{dbchapter}{all};

	my @sects = WeBWorK::Utils::ListingDB::getAllDBsections($r);
	if(! grep { $_ eq $r->param('library_sections') } @sects) {
		$r->param('library_sections', '');
	}
	unshift @sects, LIB2_DATA->{dbsection}{all};

	my $texts = WeBWorK::Utils::ListingDB::getDBTextbooks($r);
	my @textarray = map { $_->[0] }  @{$texts};
	my %textlabels = ();
	for my $ta (@{$texts}) {
		$textlabels{$ta->[0]} = $ta->[1]." by ".$ta->[2]." (edition ".$ta->[3].")";
	}
	if(! grep { $_ eq $r->param('library_textbook') } @textarray) {
		$r->param('library_textbook', '');
	}
	unshift @textarray, LIB2_DATA->{textbook}{all};
	my $atb = LIB2_DATA->{textbook}{all}; $textlabels{$atb} = LIB2_DATA->{textbook}{all};

	my $textchap_ref = WeBWorK::Utils::ListingDB::getDBTextbooks($r, 'textchapter');
	my @textchaps = map { $_->[0] } @{$textchap_ref};
	if(! grep { $_ eq $r->param('library_textchapter') } @textchaps) {
		$r->param('library_textchapter', '');
	}
	unshift @textchaps, LIB2_DATA->{textchapter}{all};

	my $textsec_ref = WeBWorK::Utils::ListingDB::getDBTextbooks($r, 'textsection');
	my @textsecs = map { $_->[0] } @{$textsec_ref};
	if(! grep { $_ eq $r->param('library_textsection') } @textsecs) {
		$r->param('library_textsection', '');
	}
	unshift @textsecs, LIB2_DATA->{textsection}{all};

	my %selected = ();
	for my $j (qw( dbsection dbchapter dbsubject textbook textchapter textsection )) {
		$selected{$j} = $r->param(LIB2_DATA->{$j}{name}) || LIB2_DATA->{$j}{all};
	}

	my $text_popup = CGI::popup_menu(-name => 'library_textbook',
	                 -size => 4,
									 -values =>\@textarray,
									 -labels => \%textlabels,
									 -default=>$selected{textbook},
									 -onchange=>"updateLibCategories(\'mainform\', \'".$r->uri."\', \'null\',\'view_problems_spinner\')");

	
	my $library_keywords = $r->param('library_keywords') || '';

	my $view_problem_line = view_problems_line('lib_view', 'View Problems', $self->r, $self);

	my $count_line = WeBWorK::Utils::ListingDB::countDBListings($r);
	if($count_line==0) {
		$count_line = "There are no matching pg files";
	} else {
		$count_line = "There are $count_line matching WeBWorK problem files";
	}

	print CGI::div({-class=>"InfoPanel", -align=>"left"},
		CGI::hidden(-name=>"library_is_basic", -default=>2,-override=>1),
		# Html done by hand since it is temporary
		CGI::div({-colspan=>4, -align=>"center"}, 'All Selected Constraints Joined by "And"'),
			CGI::div(["Subject:",
				CGI::popup_menu(-name=> 'library_subjects', 
				              -size => 4,
					            -values=>\@subjs,
					            -default=> $selected{dbsubject},
					             -onchange=>"updateLibCategories(\'mainform\', \'".$r->uri."\',\'view_problems_spinner\')"
				)]),
			CGI::div({-colspan=>2, -align=>"right"},
				'<button type="button" style="'.$right_button_style.'" onclick="updateLibCategories(\'mainform\', \''.$r->uri.'\', \'lib_select_subject\', \'null\',\'view_problems_spinner\')">Update Menus</button>'),
			CGI::div(["Chapter:",
				CGI::popup_menu(-name=> 'library_chapters', 
				              -size => 4,
					            -values=>\@chaps,
					            -default=> $selected{dbchapter},
					             -onchange=>"updateLibCategories(\'mainform\', \'".$r->uri."\',\'view_problems_spinner\')"
		    )]),
			CGI::div({-colspan=>2, -align=>"right"},
					'<button type="button" style="'.$right_button_style.'" onclick="updateLibCategories(\'mainform\', \''.$r->uri.'\', \'library_reset\', \'null\',\'view_problems_spinner\')">Reset</button>'),
			CGI::div(["Section:",
			CGI::popup_menu(-name=> 'library_sections', 
			            -size => 4,
					        -values=>\@sects,
					        -default=> $selected{dbsection},
							-onchange=>"updateLibCategories(\'mainform\', \'".$r->uri."\',\'null\',\'view_problems_spinner\')"
		    )]),
			CGI::div({-colspan=>2, -align=>"right"},
					'<button type="button" style="'.$right_button_style.'" onclick="updateLibCategories(\'mainform\', \''.$r->uri.'\', \'library_basic\', \'null\',\'view_problems_spinner\')">Basic Search</button>'),
			CGI::div(["Textbook:", $text_popup]),
			CGI::div(["Text chapter:",
			CGI::popup_menu(-name=> 'library_textchapter', 
			            -size => 4,
					        -values=>\@textchaps,
					        -default=> $selected{textchapter},
							-onchange=>"updateLibCategories(\'mainform\', \'".$r->uri."\',\'null\',\'view_problems_spinner\')"
		    )]),
			CGI::div(["Text section:",
			CGI::popup_menu(-name=> 'library_textsection', 
			            -size => 4,
					        -values=>\@textsecs,
					        -default=> $selected{textsection},
							-onchange=>"updateLibCategories(\'mainform\', \'".$r->uri."\',\'null\',\'view_problems_spinner\')"
		    )]),
		     CGI::div("Keywords:"),CGI::div({-colspan=>2},
			 CGI::textfield(-name=>"library_keywords",
							-default=>$library_keywords,
							-override=>1,
							-size=>40)),
      CGI::div({-colspan=>3}, $view_problem_line),
      CGI::div({-colspan=>3, -align=>"center"}, $count_line)
	 );
	
}


#####	 Version 4 is the set definition file panel

sub browse_setdef_panel {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $library_selected = shift;
	my $default_value = "Select a Set Definition File";
	# in the following line, the parens after sort are important. if they are
	# omitted, sort will interpret get_set_defs as the name of the comparison
	# function, and ($ce->{courseDirs}{templates}) as a single element list to
	# be sorted. *barf*
	my @list_of_set_defs = sort(get_set_defs($ce->{courseDirs}{templates}));
	if(scalar(@list_of_set_defs) == 0) {
		@list_of_set_defs = (NO_LOCAL_SET_STRING);
	} elsif (not $library_selected or $library_selected eq $default_value) { 
		unshift @list_of_set_defs, $default_value; 
		$library_selected = $default_value; 
	}
	my $view_problem_line = view_problems_line('view_setdef_set', 'View Problems', $self->r, $self);
	my $popupetc = CGI::popup_menu(-size=> 4,
	                              -name=> 'library_sets',
                                -values=>\@list_of_set_defs,
                                -default=> $library_selected).
		CGI::br().  $view_problem_line;
	if($list_of_set_defs[0] eq NO_LOCAL_SET_STRING) {
		$popupetc = "there are no set definition files in this course to look at."
	}
	print CGI::div({-class=>"InfoPanel", -align=>"left"}, "<p style='margin-bottom:0;'>Browse from:</p>",
		$popupetc
	);
}

sub make_mysets_row {
  my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my %data = @_;

	my $list_of_local_sets = $data{all_db_sets};
	my $have_local_sets = scalar(@$list_of_local_sets);
	my $browse_which = 'browse_mysets';
	my $library_selected = $self->{current_myset_set};
	my $set_selected = $r->param('myset_sets');
	my $remember_local_set = $r->param('local_sets');

	##	Make buttons for additional problem libraries
	#my $libs = '';
	#foreach my $lib (sort(keys(%problib))) {
	#	$libs .= ' '. CGI::submit(-name=>"browse_$lib", -value=>$problib{$lib},
	#															 ($browse_which eq "browse_$lib")? (-disabled=>1): ())
	#		if (-d "$ce->{courseDirs}{templates}/$lib");
	#}
	#$libs = CGI::br()."or Problems from".$libs if $libs ne '';

	my $these_widths = "width: 25ex";


	#if($have_local_sets ==0) {
	#	$list_of_local_sets = [NO_LOCAL_SET_STRING];
	#} elsif (not defined($set_selected) or $set_selected eq ""
	#  or $set_selected eq SELECT_SET_STRING) {
	#	unshift @{$list_of_local_sets}, SELECT_SET_STRING;
	#	$set_selected = SELECT_SET_STRING;
	#}
	my $myjs = 'document.getElementById(\"create_new_set\").style.display = \"none\";document.mainform.selfassign.value=confirm("Should I assign the new set to you now?\nUse OK for yes and Cancel for no.");true;';
	## edited this, as a demo for the current set problem list
	print CGI::div({-id=>"create_new_set", -class=>"InfoPanel shadowed"},
	    CGI::hidden(-name=>"selfassign", -default=>0,-override=>1).
		CGI::submit(-name=>"new_local_set", -value=>"Create a New Set in This Course:",
		-onclick=>"document.mainform.selfassign.value=1"   #just assign it!!   # $myjs
		),
		"  ",
		CGI::textfield(-name=>"new_set_name", 
					   -default=>"Name for new set here",
					   -override=>1, -size=>30),
	  '<button type="button" onclick="document.getElementById(\'create_new_set\').style.display = \'none\';">Cancel</button>',
	);
	# Tidy this list up since it is used in two different places
	#if ($list_of_local_sets->[0] eq SELECT_SET_STRING) {
	#	shift @{$list_of_local_sets};
	#}

	#print CGI::div(CGI::div({-bgcolor=>"black"}));
	#print CGI::hr();

	#$self->browse_mysets_panel($library_selected, $list_of_local_sets, $remember_local_set);
}

sub make_top_row {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my %data = @_;

	my $list_of_local_sets = $data{all_db_sets};
	my $have_local_sets = scalar(@$list_of_local_sets);
	my $browse_which = $data{browse_which};
	my $library_selected = $self->{current_library_set};
	my $set_selected = $r->param('local_sets');
	my (@dis1, @dis2, @dis3, @dis4) = ();
	@dis1 =	 (-disabled=>1) if($browse_which eq 'browse_npl_library');	 
	@dis2 =	 (-disabled=>1) if($browse_which eq 'browse_local');
	@dis3 =	 (-disabled=>1) if($browse_which eq 'edit_mysets');
	@dis4 =	 (-disabled=>1) if($browse_which eq 'browse_setdefs');

	##	Make buttons for additional problem libraries
	#my $libs = '';
	#foreach my $lib (sort(keys(%problib))) {
	#	$libs .= ' '. CGI::submit(-name=>"browse_$lib", -value=>$problib{$lib},
	#															 ($browse_which eq "browse_$lib")? (-disabled=>1): ())
	#		if (-d "$ce->{courseDirs}{templates}/$lib");
	#}
	#$libs = CGI::br()."or Problems from".$libs if $libs ne '';

	my $these_widths = "width: 25ex";

	if($have_local_sets ==0) {
		$list_of_local_sets = [NO_LOCAL_SET_STRING];
	} elsif (not defined($set_selected) or $set_selected eq ""
	  or $set_selected eq SELECT_SET_STRING) {
		unshift @{$list_of_local_sets}, SELECT_SET_STRING;
		$set_selected = SELECT_SET_STRING;
	}

	# Tidy this list up since it is used in two different places
	if ($list_of_local_sets->[0] eq SELECT_SET_STRING) {
		shift @{$list_of_local_sets};
	}

	#print CGI::div({-class=>"InfoPanel"},
	#	"Browse ",
	#	CGI::submit(-name=>"browse_npl_library", -value=>"National Problem Library", -style=>$these_widths, @dis1),
	#	CGI::submit(-name=>"browse_local", -value=>"Local Problems", -style=>$these_widths, @dis2),
	#	CGI::submit(-name=>"edit_mysets", -value=>"From This Course", -style=>$these_widths, @dis3),
	#	CGI::submit(-name=>"browse_setdefs", -value=>"Set Definition Files", -style=>$these_widths, @dis4),
	#	$libs,
	#);
  
	#if ($browse_which eq 'browse_local') {
	#	$self->browse_local_panel($library_selected);
	#} elsif ($browse_which eq 'edit_mysets') {
	#	$self->edit_mysets_panel($library_selected, $list_of_local_sets);
	#} elsif ($browse_which eq 'browse_npl_library') {
	#	$self->browse_library_panel();
	#} elsif ($browse_which eq 'browse_setdefs') {
	#	$self->browse_setdef_panel($library_selected);
	#} else { ## handle other problem libraries
	#	$self->browse_local_panel($library_selected,$browse_which);
	#}
	
	#, 
		#CGI::div({},
		#    CGI::submit(-name=>"rerandomize", 
		#                -style=>$these_widths,
		#                -value=>"Rerandomize"),
		#    CGI::submit(-name=>"cleardisplay", 
		#            -style=>$these_widths,
		#            -value=>"Clear Problem Display"),
	  #);
	  
	print "<div class='inforPanel' style='float:left;'>
	<p style='margin-bottom:0'>Browse:</p>
	<select id='library_selector' size=4 onchange='changeLibrary(\"mainform\", \"".$r->uri."\", this, \"view_problems_spinner\")'>"
	;
	print "<option value=\'browse_npl_library\'>National Problem Library</option>
			<option value=\'browse_local\'>".$r->maketext("Local Problems")."</option>
			<option value=\'edit_mysets\'>From this Course</option>
			<option value=\'browse_setdefs\'>Set Definition Files</option>"
	;
	foreach my $lib (sort(keys(%problib))) {
	  print "<option value=\'browse_$lib\'>".$problib{$lib}."</option>"
	}
	
	print "</select>
	  </div>"
	;
	  
}

sub make_data_row {
	my $self = shift;
	my $r = $self->r;
	my $sourceFileName = shift;
	my $pg = shift;
	my $cnt = shift;
	my $mark = shift || 0;

	$sourceFileName =~ s|^./||; # clean up top ugliness

	my $urlpath = $self->r->urlpath;
	my $db = $self->r->db;

	## to set up edit and try links elegantly we want to know if
	##    any target set is a gateway assignment or not
	my $localSet = $self->r->param('local_sets');
	my $setRecord;
	if ( defined($localSet) && $localSet ne SELECT_SET_STRING &&
	     $localSet ne NO_LOCAL_SET_STRING ) {
		$setRecord = $db->getGlobalSet( $localSet );
	}
	my $isGatewaySet = ( defined($setRecord) && 
			     $setRecord->assignment_type =~ /gateway/ );

	my $problem_output = $pg->{flags}->{error_flag} ?
		CGI::div({class=>"ResultsWithError"}, CGI::em("This problem produced an error"))
		: CGI::div({class=>"RenderSolo"}, $pg->{body_text});
	$problem_output .= $pg->{flags}->{comment} if($pg->{flags}->{comment});


	#if($self->{r}->param('browse_which') ne 'browse_npl_library') {
	my $problem_seed = $self->{'problem_seed'} || 1234;
	my $edit_link = CGI::a({href=>$self->systemLink(
		 $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor2", $r,
			  courseID =>$urlpath->arg("courseID"),
			  setID=>"Undefined_Set",
			  problemID=>"1"),
			params=>{sourceFilePath => "$sourceFileName", problemSeed=> $problem_seed}
		  ), target=>"WW_Editor"}, "Edit it" );
	
	my $displayMode = $self->r->param("mydisplayMode");
	$displayMode = $self->r->ce->{pg}->{options}->{displayMode}
		if not defined $displayMode or $displayMode eq "None";
	my $module = ( $isGatewaySet ) ? "GatewayQuiz" : "Problem";
	my %pathArgs = ( courseID =>$urlpath->arg("courseID"),
			setID=>"Undefined_Set" );
	$pathArgs{problemID} = "1" if ( ! $isGatewaySet );

	my $try_link = CGI::a({href=>$self->systemLink(
		$urlpath->newFromModule("WeBWorK::ContentGenerator::$module", $r,
			%pathArgs ),
			params =>{
				effectiveUser => scalar($self->r->param('user')),
				editMode => "SetMaker",
				problemSeed=> $problem_seed,
				sourceFilePath => "$sourceFileName",
				displayMode => $displayMode,
			}
		), target=>"WW_View"}, "Try it");

	my %add_box_data = ( -id=>"trial$cnt", -class=>"add_problem_checkbox" ,-name=>"trial$cnt",-value=>1,-label=>"Add this problem to the target set on the next update");
	#allow for a move command from one problem set to anoter
	my $move_box_data;
	if($self->r->param('edit_mysets_set')){
	  $move_box_data = CGI::checkbox( -id=>"moved$cnt" ,-name=>"moved$cnt",-value=>1,,-override=>1,-label=>"Move this problem from this set to the target set on the next update");
	}
	else{
	  $move_box_data = "";
	}
	if($mark & SUCCESS) {
		$add_box_data{ -label } .= " (just added this problem)";
	} elsif($mark & ADDED) {
		$add_box_data{ -checked } = 1;
	}

	if(!($self->{isInSet}{$sourceFileName})){

  	print CGI::div({-class=>"problem libraryProblem", -align=>"left", -draggable=>"true", -href=>"#", -id=>"$cnt"},
  		CGI::p(CGI::span({style=> 'float:left'},"File name: $sourceFileName "), 
  		       CGI::span({style=>'float:right'}, $edit_link, "&nbsp;&nbsp;", $try_link,"&nbsp;")
  		),CGI::br(),
  		CGI::checkbox(-id=>"hideme$cnt", -name=>"hideme$cnt",-value=>1,-label=>"Don't show this problem on the next update",-override=>1),
  		CGI::br(),CGI::checkbox((%add_box_data),-override=>1),
  		CGI::p($move_box_data),
  		CGI::hidden(-id=>"filetrial$cnt", -name=>"filetrial$cnt", -default=>$sourceFileName,-override=>1).
  		CGI::p($problem_output)
	  );
	}
	else{
	  print CGI::div({-class=>"problem libraryProblem used", -align=>"left", -draggable=>"true", -href=>"#", -id=>"$cnt"},
  		CGI::p({},"File name: $sourceFileName "), 
  		CGI::p({}, $edit_link, " ", $try_link),
  		CGI::p(CGI::checkbox(-id=>"hideme$cnt", -name=>"hideme$cnt",-value=>1,-label=>"Don't show this problem on the next update",-override=>1)),
  		CGI::p(CGI::checkbox((%add_box_data),-override=>1)),
  		CGI::p($move_box_data),
  		CGI::hidden(-id=>"filetrial$cnt", -name=>"filetrial$cnt", -default=>$sourceFileName,-override=>1).
  		CGI::p($problem_output),
  		CGI::b("(This problem is in the target set)")
	  );
	}
}

sub make_myset_data_row {
	my $self = shift;
	my $r = $self->r;
	my $sourceFileName = shift;
	my $pg = shift;
	my $cnt = shift;
	my $mark = shift || 0;

	$sourceFileName =~ s|^./||; # clean up top ugliness

	my $urlpath = $self->r->urlpath;
	my $db = $self->r->db;

	## to set up edit and try links elegantly we want to know if
	##    any target set is a gateway assignment or not
	my $localSet = $self->r->param('local_sets');
	my $setRecord;
	if ( defined($localSet) && $localSet ne SELECT_SET_STRING &&
	     $localSet ne NO_LOCAL_SET_STRING ) {
		$setRecord = $db->getGlobalSet( $localSet );
	}
	my $isGatewaySet = ( defined($setRecord) && 
			     $setRecord->assignment_type =~ /gateway/ );

	my $problem_output = $pg->{flags}->{error_flag} ?
		CGI::div({class=>"ResultsWithError"}, CGI::em("This problem produced an error"))
		: CGI::div({class=>"RenderSolo"}, $pg->{body_text});
	$problem_output .= $pg->{flags}->{comment} if($pg->{flags}->{comment});


	#if($self->{r}->param('browse_which') ne 'browse_npl_library') {
	my $problem_seed = $self->{'problem_seed'} || 1234;
	my $edit_link = CGI::a({href=>$self->systemLink(
		 $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor", $r,
			  courseID =>$urlpath->arg("courseID"),
			  setID=>"Undefined_Set",
			  problemID=>"1"),
			params=>{sourceFilePath => "$sourceFileName", problemSeed=> $problem_seed}
		  ), target=>"WW_Editor"}, "Edit it" );
	
	my %delete_box_data = ( -id=>"deleted$cnt".'myset' ,-name=>"deleted$cnt",-value=>1,-label=>"Delete this problem from the target set on the next update");
	
	my $displayMode = $self->r->param("mydisplayMode");
	$displayMode = $self->r->ce->{pg}->{options}->{displayMode}
		if not defined $displayMode or $displayMode eq "None";
	my $module = ( $isGatewaySet ) ? "GatewayQuiz" : "Problem";
	my %pathArgs = ( courseID =>$urlpath->arg("courseID"),
			setID=>"Undefined_Set" );
	$pathArgs{problemID} = "1" if ( ! $isGatewaySet );

	my $try_link = CGI::a({href=>$self->systemLink(
		$urlpath->newFromModule("WeBWorK::ContentGenerator::$module", $r,
			%pathArgs ),
			params =>{
				effectiveUser => scalar($self->r->param('user')),
				editMode => "SetMaker",
				problemSeed=> $problem_seed,
				sourceFilePath => "$sourceFileName",
				displayMode => $displayMode,
			}
		), target=>"WW_View"}, "Try it");

	print CGI::div({-class=>"problem myProblem", -draggable=>"true", -href=>"#", -id=>("$cnt".'myset')},
		CGI::p({},"File name: $sourceFileName "), 
  	CGI::p({}, $edit_link, " ", $try_link),
		CGI::p(CGI::checkbox((%delete_box_data),-override=>1)),
		CGI::hidden(-id=>"filetrial$cnt".'myset', -name=>"mysetfiletrial$cnt", -default=>$sourceFileName,-override=>1),
		CGI::p($problem_output),
	);
}

sub clear_default {
	my $r = shift;
	my $param = shift;
	my $default = shift;
	my $newvalue = $r->param($param) || '';
	$newvalue = '' if($newvalue eq $default);
	$r->param($param, $newvalue);
}

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	## For all cases, lets set some things
	$self->{error}=0;
	my $ce = $r->ce;
	my $db = $r->db;
	my $maxShown = $r->param('max_shown') || MAX_SHOW_DEFAULT;
	$maxShown = 10000000 if($maxShown eq 'All'); # let's hope there aren't more
	my $library_basic = $r->param('library_is_basic') || 1;
	$self->{problem_seed} = $r->param('problem_seed') || 1234;
	## Fix some parameters
	for my $key (keys(%{ LIB2_DATA() })) {
		clear_default($r, LIB2_DATA->{$key}->{name}, LIB2_DATA->{$key}->{all} );
	}
    ##  Grab library sets to display from parameters list.  We will modify this
    ##  as we go through the if/else tree
    $self->{current_library_set} =  $r->param('library_sets');
    $self->{current_myset_set} = $r->param('myset_sets');
    if (not defined($self->{current_myset_set}) 
		or $self->{current_myset_set} eq "Select a Homework Set"
		or $self->{current_myset_set} eq NO_LOCAL_SET_STRING) {
      my @all_db_sets = $db->listGlobalSets;
	    @all_db_sets = sortByName(undef, @all_db_sets);
	    $self->{current_myset_set} = shift(@all_db_sets);
	  }
    
	##	These directories will have individual buttons
	%problib = %{$ce->{courseFiles}{problibs}} if $ce->{courseFiles}{problibs};

	my $userName = $r->param('user');
	my $user = $db->getUser($userName); # checked 
	die "record for user $userName (real user) does not exist." 
		unless defined $user;
	my $authz = $r->authz;
	unless ($authz->hasPermissions($userName, "modify_problem_sets")) {
		return(""); # Error message already produced in the body
	}

	## Now one action we have to deal with here
	if ($r->param('edit_local')) {
		my $urlpath = $r->urlpath;
		my $db = $r->db;
		my $checkset = $db->getGlobalSet($r->param('local_sets'));
		if (not defined($checkset)) {
			$self->{error} = 1;
			$self->addbadmessage('You need to select a "Target Set" before you can edit it.');
		} else {
			my $page = $urlpath->newFromModule('WeBWorK::ContentGenerator::Instructor::ProblemSetDetail', $r, setID=>$r->param('local_sets'), courseID=>$urlpath->arg("courseID"));
			my $url = $self->systemLink($page);
			$self->reply_with_redirect($url);
		}
	}

	## Next, lots of set up so that errors can be reported with message()

	############# List of problems we have already printed

	$self->{past_problems} = get_past_problem_files($r);
	# if we don't end up reusing problems, this will be wiped out
	# if we do redisplay the same problems, we must adjust this accordingly
	my @past_marks = map {$_->[1]} @{$self->{past_problems}};
	my $none_shown = scalar(@{$self->{past_problems}})==0;
	my @pg_files=();
	my @myset_files=();
	my $use_previous_problems = 1;
	my $first_shown = $r->param('first_shown') || 0;
	my $last_shown = $r->param('last_shown'); 
	if (not defined($last_shown)) {
		$last_shown = -1; 
	}
	my @all_past_list = (); # these are include requested, but not shown
	my $j = 0;
	while (defined($r->param("all_past_list$j"))) {
		push @all_past_list, $r->param("all_past_list$j");
		$j++;
	}

	############# Default of which problem selector to display

	my $browse_which = $r->param('browse_which') || 'browse_npl_library';
	my $gridded = $r->param('gridify') || 'false';

	

	## check for problem lib buttons
	my $browse_lib = '';
	foreach my $lib (keys %problib) {
		if ($r->param("browse_$lib")) {
			$browse_lib = "browse_$lib";
			last;
		}
	}


	########### Start the logic through if elsif elsif ...
    debug("browse_lib", $r->param("$browse_lib"));
    debug("browse_npl_library", $r->param("browse_npl_library"));
    debug("edit_mysets", $r->param("edit_mysets"));
    debug("browse_setdefs", $r->param("browse_setdefs"));
	##### Asked to browse certain problems
	if ($browse_lib ne '') {
		$browse_which = $browse_lib;
		$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems
	} elsif ($r->param('browse_npl_library')) {
		$browse_which = 'browse_npl_library';
		$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems
	} elsif ($r->param('browse_local')) {
		$browse_which = 'browse_local';
		#$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems
	} elsif ($r->param('edit_mysets')) {
		$browse_which = 'edit_mysets';
		$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems
	} elsif ($r->param('browse_setdefs')) {
		$browse_which = 'browse_setdefs';
		$self->{current_library_set} = "";
		$use_previous_problems = 0; @pg_files = (); ## clear old problems

		##### Change the seed value

	} elsif ($r->param('rerandomize')) {
		$self->{problem_seed}= 1+$self->{problem_seed};
		#$r->param('problem_seed', $problem_seed);
		$self->addbadmessage('Changing the problem seed for display, but there are no problems showing.') if $none_shown;

		##### Clear the display

	} elsif ($r->param('cleardisplay')) {
		@pg_files = ();
		$use_previous_problems=0;
		$self->addbadmessage('The display was already cleared.') if $none_shown;

		##### View problems selected from the local list

	} elsif ($r->param('view_local_set')) {

		my $set_to_display = $self->{current_library_set};
		if (not defined($set_to_display) or $set_to_display eq SELECT_LOCAL_STRING or $set_to_display eq "Found no directories containing problems") {
			$self->addbadmessage('You need to select a set to view.');
		} else {
			$set_to_display = '.' if $set_to_display eq MY_PROBLEMS;
			$set_to_display = substr($browse_which,7) if $set_to_display eq MAIN_PROBLEMS;
			@pg_files = list_pg_files($ce->{courseDirs}->{templates},
				"$set_to_display");
			$use_previous_problems=0;
		}

		##### View problems selected from the a set in this course
  } elsif ($r->param('edit_mysets_set')){
  
    my $set_to_display = $self->{current_library_set};
		  debug("set_to_display is $set_to_display");
		  if (not defined($set_to_display) 
		  		or $set_to_display eq "Select a Homework Set"
		  		or $set_to_display eq NO_LOCAL_SET_STRING) {
		  	$self->addbadmessage("You need to select a set from this course to view.");
		  } else {
		  	# DBFIXME don't use ID list, use an iterator
		  	my @problemList = $db->listGlobalProblems($set_to_display);
		  	my $problem;
		  	@pg_files=();
		  	for $problem (@problemList) {
		  		my $problemRecord = $db->getGlobalProblem($set_to_display, $problem); # checked
		  		die "global $problem for set $set_to_display not found." unless
		  			$problemRecord;
		  		push @pg_files, $problemRecord->source_file;
  
		  	}
		  	@pg_files = sortByName(undef,@pg_files);
		  	$use_previous_problems=0;
		  }

		##### View from the library database
 
	} elsif ($r->param('lib_view')) {
		@pg_files=();
		my @dbsearch = WeBWorK::Utils::ListingDB::getSectionListings($r);
		my ($result, $tolibpath);
		for $result (@dbsearch) {
			$tolibpath = "Library/$result->{path}/$result->{filename}";
			
			## Too clunky!!!!
			push @pg_files, $tolibpath;
		}
		$use_previous_problems=0; 

		##### View a set from a set*.def

	} elsif ($r->param('view_setdef_set')) {

		my $set_to_display = $self->{current_library_set};
		debug("set_to_display is $set_to_display");
		if (not defined($set_to_display) 
				or $set_to_display eq "Select a Set Definition File"
				or $set_to_display eq NO_LOCAL_SET_STRING) {
			$self->addbadmessage("You need to select a set definition file to view.");
		} else {
			@pg_files= $self->read_set_def($set_to_display);
		}
		$use_previous_problems=0; 

		##### Edit the current local homework set

	} elsif ($r->param('edit_local')) { ## Jump to set edit page

		; # already handled


		##### Make a new local homework set

	} elsif ($r->param('new_local_set')) {
		if ($r->param('new_set_name') !~ /^[\w .-]*$/) {
			$self->addbadmessage("The name ".$r->param('new_set_name')." is not a valid set name.  Use only letters, digits, -, _, and .");
		} else {
			my $newSetName = $r->param('new_set_name');
			# if we want to munge the input set name, do it here
			$newSetName =~ s/\s/_/g;
			debug("local_sets was ", $r->param('local_sets'));
			$r->param('local_sets',$newSetName);  ## use of two parameter param
			debug("new value of local_sets is ", $r->param('local_sets'));
			my $newSetRecord	 = $db->getGlobalSet($newSetName);
			if (defined($newSetRecord)) {
	            $self->addbadmessage("The set name $newSetName is already in use.  
	            Pick a different name if you would like to start a new set.");
			} else {			# Do it!
				# DBFIXME use $db->newGlobalSet
				$newSetRecord = $db->{set}->{record}->new();
				$newSetRecord->set_id($newSetName);
				$newSetRecord->set_header("defaultHeader");
				$newSetRecord->hardcopy_header("defaultHeader");
				$newSetRecord->open_date(time()+60*60*24*7); # in one week
				$newSetRecord->due_date(time()+60*60*24*7*2); # in two weeks
				$newSetRecord->answer_date(time()+60*60*24*7*3); # in three weeks
				eval {$db->addGlobalSet($newSetRecord)};
				if ($@) {
					$self->addbadmessage("Problem creating set $newSetName<br> $@");
				} else {
					$self->addgoodmessage("Set $newSetName has been created.");
					my $selfassign = $r->param('selfassign') || "";
					$selfassign = "" if($selfassign =~ /false/i); # deal with javascript false
					if($selfassign) {
						$self->assignSetToUser($userName, $newSetRecord);
						$self->addgoodmessage("Set $newSetName was assigned to $userName.");
					}
				}
			}
		}

		##### Add selected problems to the current local set

	} elsif ($r->param('update')) {
	  
		## first handle problems to be added before we hide them
		my($localSet, @selected);

		my @add_pg_files = grep {(($_->[1] & ADDED)) != 0 } @{$self->{past_problems}}; 
		my @add_selected = map {$_->[0]} @add_pg_files;
		
		my @delete_pg_files = grep {(($_->[1] & DELETED)) != 0} @{$self->{past_problems}};
		my @delete_selected = map {$_->[0]} @delete_pg_files;
		
		my @move_pg_files = grep {(($_->[1] & MOVED)) != 0} @{$self->{past_problems}};
		my @move_selected = map {$_->[0]} @move_pg_files;

		my @action_files = grep {$_->[1] > 0 } @{$self->{past_problems}};
		# There are now good reasons to do an update without selecting anything.
		#if(scalar(@action_files) == 0) {
		#	 $self->addbadmessage('Update requested, but no problems were marked.');
		#}
		if (scalar(@add_selected)>0) {	# if some are to be added, they need a place to go
			$localSet = $r->param('myset_sets');
			if (not defined($localSet) or 
					$localSet eq SELECT_SET_STRING or 
		            $localSet eq NO_LOCAL_SET_STRING) {
				$self->addbadmessage('You are trying to add problems to something, 
				but you did not select a "Target Set" name as a target.');
			} else {
				my $newSetRecord  = $db->getGlobalSet($localSet);
				if (not defined($newSetRecord)) {
					$self->addbadmessage("You are trying to add problems to $localSet, 
					but that set does not seem to exist!  I bet you used your \"Back\" button.");
				} else {
					my $addcount = add_selected($self, $db, $localSet);
					if($addcount > 0) {
						$self->addgoodmessage("Added $addcount problem".(($addcount>1)?'s':'').
							" to $localSet.");
					}
				}
			}
		}
		if (scalar(@delete_selected)>0) {	# if some are to be added, they need a place to go
			$localSet = $r->param('myset_sets');
			if (not defined($localSet) or 
					$localSet eq SELECT_SET_STRING or 
		            $localSet eq NO_LOCAL_SET_STRING) {
				$self->addbadmessage('You are trying to add problems to something, 
				but you did not select a "Target Set" name as a target.');
			} else {
				my $newSetRecord  = $db->getGlobalSet($localSet);
				if (not defined($newSetRecord)) {
					$self->addbadmessage("You are trying to delete problems to $localSet, 
					but that set does not seem to exist!  I bet you used your \"Back\" button.");
				} else {
					my $deletecount = delete_selected($self, $db, $localSet);
					if($deletecount > 0) {
						$self->addgoodmessage("Deleted $deletecount problem".(($deletecount>1)?'s':'').
							" to $localSet.");
					}
				}
			}
		}
		if (scalar(@move_selected)>0) {	# if some are to be added, they need a place to go
			$localSet = $r->param('myset_sets');
			my $otherSet = $self->{current_library_set};
			if (not defined($localSet) or not defined($otherSet) or
					$localSet eq SELECT_SET_STRING or 
		            $localSet eq NO_LOCAL_SET_STRING) {
				$self->addbadmessage('You are trying to add problems to something, 
				but you did not select a "Target Set" name as a target.');
			} else {
				my $newSetRecord  = $db->getGlobalSet($localSet);
				my $otherNewSetRecord = $db->getGlobalSet($otherSet);
				if (not defined($newSetRecord) or not defined($otherNewSetRecord)) {
					$self->addbadmessage("You are trying to move problems from $otherSet to $localSet, 
					but that set does not seem to exist!  I bet you used your \"Back\" button.");
				} else {
					my $addcount = add_selected($self, $db, $localSet);
					my $deletecount = delete_selected($self, $db, $otherSet);
					if($addcount > 0 && $deletecount > 0) {
						$self->addgoodmessage("Moved $addcount problem".(($addcount>1)?'s':'').
							" from $otherSet to $localSet.");
					}
				}
			}
		}
		## now handle problems to be hidden

		## only keep the ones which are not hidden
		@pg_files = grep {($_->[1] & HIDDEN) ==0 } @{$self->{past_problems}};
		@pg_files = grep {(($_->[1] & DELETED)) != 0 } @pg_files;
		@past_marks = map {$_->[1]} @pg_files;
		@pg_files = map {$_->[0]} @pg_files;
		@all_past_list = (@all_past_list[0..($first_shown-1)],
					@pg_files,
					@all_past_list[($last_shown+1)..(scalar(@all_past_list)-1)]);
		$last_shown = $first_shown+$maxShown -1; debug("last_shown 3: ", $last_shown);
		$last_shown = (scalar(@all_past_list)-1) if($last_shown>=scalar(@all_past_list)); debug("last_shown 4: ", $last_shown);
		
		#want to reorder in addition to anything else
    if ($r->param('isReordered')){
    #this might work, i'm not sure if this is the right ID
      reorderProblems($self, $db, $r->param('myset_sets'), $r);
    }

	} elsif ($r->param('next_page')) {
		$first_shown = $last_shown+1;
		$last_shown = $first_shown+$maxShown-1; debug("last_shown 5: ", $last_shown);
		$last_shown = (scalar(@all_past_list)-1) if($last_shown>=scalar(@all_past_list)); debug("last_shown 6: ", $last_shown);
		$self->addgoodmessage("It sees the next_page parameter, last shown is: $last_shown and first shown is: $first_shown");
		@past_marks = ();
	} elsif ($r->param('prev_page')) {
		$last_shown = $first_shown-1; 
		$first_shown = $last_shown - $maxShown+1;

		$first_shown = 0 if($first_shown<0);
		@past_marks = ();

	} elsif ($r->param('select_all')) {
		@past_marks = map {1} @past_marks;
	} elsif ($r->param('library_basic')) {
		$library_basic = 1;
		for my $jj (qw(textchapter textsection textbook)) {
			$r->param('library_'.$jj,'');
		}
	} elsif ($r->param('library_advanced')) {
		$library_basic = 2;
	} elsif ($r->param('library_reset')) {
		for my $jj (qw(chapters sections subjects textbook keywords)) {
			$r->param('library_'.$jj,'');
		}
	} elsif ($r->param('select_none')) {
		@past_marks = ();
	} else {
		#nothing
	}				##### end of the if elsif ...

  #I'm worried this will break something
  my $default_set = $self->{current_myset_set};
	  #debug("set_to_display is $default_set");
	  if (not defined($default_set) 
  		or $default_set eq "Select a Homework Set"
  		or $default_set eq NO_LOCAL_SET_STRING) {
  		$self->addbadmessage("You need to select a set from this course to view.");
  	} else {
  		# DBFIXME don't use ID list, use an iterator
  		my @problemList = $db->listGlobalProblems($default_set);
  		my $problem;
  		@myset_files=();
  		for $problem (@problemList) {
  			my $problemRecord = $db->getGlobalProblem($default_set, $problem); # checked
  			die "global $problem for set $default_set not found." unless
  				$problemRecord;
  			push @myset_files, $problemRecord->source_file;
  
  		}
  	  #@myset_files = sortByName(undef,@myset_files);
  	}
 
	############# List of local sets

	# DBFIXME sorting in database, please!
	my @all_db_sets = $db->listGlobalSets;
	@all_db_sets = sortByName(undef, @all_db_sets);

	if ($use_previous_problems) {
		@pg_files = @all_past_list;
	} else {
		$first_shown = 0;
		$last_shown = scalar(@pg_files)<$maxShown ? scalar(@pg_files) : $maxShown; 
		$last_shown--;		# to make it an array index
		@past_marks = ();
	}
	############# Now store data in self for retreival by body
	$self->{first_shown} = $first_shown;
	$self->{last_shown} = $last_shown;
	$self->{browse_which} = $browse_which;
	$self->{gridded} = $gridded;
	#$self->{problem_seed} = $problem_seed;
	$self->{pg_files} = \@pg_files;
	$self->{myset_files} = \@myset_files;
	$self->{past_marks} = \@past_marks;
	$self->{all_db_sets} = \@all_db_sets;
	$self->{library_basic} = $library_basic;
	debug("past_marks is ", join(" ", @{$self->{past_marks}}));
}


sub title {
	return "Library Browser v2";
}

sub head {
  print '<script src="/webwork2_files/js/legacy/dnd.js"></script>';
  print '<script src="/webwork2_files/js/legacy/problem_grid.js"></script>';
  print '<script src="/webwork2_files/js/legacy/form_builder.js"></script>';
  #my ($self) = @_;
  #my $r = $self->r;
  #start a timer to save people's stuff idk if people want this
  #print "<script> setInterval('saveChanges(\"mainform\", \"".$r->uri."\")', 680000); </script>";
  print '<link rel="stylesheet" type="text/css" href="/webwork2_files/css/setmaker2.css" />';
  print '<script>window.addEventListener("load", setup, false);</script>';
  return "";
}

sub body {
  #big wrapper div that will hopefully fix theme issues
  print '<div id="set_maker_two_box">';
  
	my ($self) = @_;

	my $r = $self->r;
	my $ce = $r->ce;		# course environment
	my $db = $r->db;		# database
	my $j;			# garden variety counter

	my $userName = $r->param('user');

	my $user = $db->getUser($userName); # checked
	die "record for user $userName (real user) does not exist."
		unless defined $user;

	### Check that this is a professor
	my $authz = $r->authz;
	unless ($authz->hasPermissions($userName, "modify_problem_sets")) {
		print "User $userName returned " . 
			$authz->hasPermissions($userName, "modify_problem_sets") . 
	" for permission";
		return(CGI::div({class=>'ResultsWithError'},
		CGI::em("You are not authorized to access the Instructor tools.")));
	}

	my $showHints = $r->param('showHints');
	my $showSolutions = $r->param('showSolutions');
	
	##########	Extract information computed in pre_header_initialize

	my $first_shown = $self->{first_shown};
	my $last_shown = $self->{last_shown}; 
	my $browse_which = $self->{browse_which};
	my $gridded = $self->{gridded};
	my $problem_seed = $self->{problem_seed}||1234;
	my @pg_files = @{$self->{pg_files}};
	my @myset_files =@{$self->{myset_files}};
	my @all_db_sets = @{$self->{all_db_sets}};

  my $displayModePlaceholder;
	if (not defined($r->param('mydisplayMode'))){
	  $displayModePlaceholder = "images";
	}
	else{
	  $displayModePlaceholder = $r->param('mydisplayMode');
	}

	my @pg_html;
	if ($last_shown >= $first_shown) {
		@pg_html = renderProblems(
			r=> $r,
			user => $user,
			problem_list => [@pg_files[$first_shown..$last_shown]],
			displayMode => $displayModePlaceholder,
			showHints => $showHints,
			showSolutions => $showSolutions,
		);
	}
	my @myset_html;

  @myset_html = renderProblems(
	  r=> $r,
	  user => $user,
		problem_list => [@myset_files],
		displayMode => $displayModePlaceholder,
		showHints => $showHints,
		showSolutions => $showSolutions,
  );

	my %isInSet;
	my $setName = $r->param("myset_sets");
	if ($setName) {
		# DBFIXME where clause, iterator
		# DBFIXME maybe instead of hashing here, query when checking source files?
		# DBFIXME definitely don't need to be making full record objects
		# DBFIXME SELECT source_file FROM whatever_problem WHERE set_id=? GROUP BY source_file ORDER BY NULL;
		# DBFIXME (and stick result directly into hash)
		foreach my $problem ($db->listGlobalProblems($setName)) {
			my $problemRecord = $db->getGlobalProblem($setName, $problem);
			$isInSet{$problemRecord->source_file} = 1;
		}
	}
	$self->{isInSet} = \%isInSet;
  my $jj;
  ##########  Loading Screen
  print '<div id="loading"></div>';
  
	##########	Top part
	print '<span><button onclick="fullWindowMode();">Full Screen</button>';
	print '<span><button id="gridifyButton" onclick="gridify();">Gridify!!</button>';
	print '<span>Hover Magnification: <button type="button" onclick="increaseMagnification();">+</button><span id="magnification">1</span><button type="button" onclick="decreaseMagnification();">-</button></span></span>';
	print '<button type="button" onclick="toggleHelp(this);" value="false">?</button>';
	print '<div id="help" style="display:none;position:absolute;z-index:1500;background:white;" class="shadowed">',
				  '<h1>What can you do?</h1>',
					'<p>Drag a problem from the library to the target set to add.</p>',
					'<p>Drag a problem set off the target set to remove.</p>',
					'<p>If you have a local problem set in the library<br/>you can shift drag to move a problem from there to the target set.<br/>This will remove the problem from one set and add it to the other</p>',
					'<h1>Legend</h1>',
					'<p><div class="problem" style="width:16px;height:16px;border:solid 1px;"></div><span>Normal problem</span></p>',
					'<p><div class="used" style="width:16px;height:16px;border:solid 1px;"></div><span>Problem already in set</span></p>',
					'<p><div class="libProblem" style="width:16px;height:16px;border:solid 1px;"></div><span>Problem will be added to target on next update</span></p>',
					'<p><div class="removedProblem" style="width:16px;height:16px;border:solid 1px;"></div><span>Problem will be deleted from target on next update</span></p>',
					'<p><div class="ResultsWithError" style="width:16px;height:16px;border:solid 1px;"></div><span>Errors</span></p>',
				'</div>';
				#'<p>In the target set you can drag problems to reorder them.<br/>The problem will be placed in front of the one you drop it on,<br/>or at the end of the list if you drop it on an empty space in the table.</p>',
	print '<span><button type="button" style="float:right;" onclick="saveChanges(\'mainform\', \''.$r->uri.'\', \'save_changes_spinner\');">save changes</button><img id="save_changes_spinner" style="display:none;float:right;" src="/webwork2_files/images/ajax-loader-small.gif"></img>
	             <button type="button" style="float:right;" onclick="updateLibCategories(\'mainform\', \''.$r->uri.'\', \'lib_select_subject\', \'null\',\'view_problems_spinner\')">Update Menus</button>
	             <button type="button" style="float:right;" onclick="updateLibCategories(\'mainform\', \''.$r->uri.'\', \'library_reset\', \'null\',\'view_problems_spinner\')">Reset</button>
	             <button type="button" style="float:right;" onclick="updateLibCategories(\'mainform\', \''.$r->uri.'\', \'library_advanced\', \'view_problems_spinner\')">Advanced Search</button>
	             <button type="button" style="float:right;" onclick="updateLibCategories(\'mainform\', \''.$r->uri.'\', \'library_basic\', \'null\',\'view_problems_spinner\')">Basic Search</button>
	      </span>';
	print '<div id="editor-form">';
	  print CGI::start_form({-id=>"mainform", -method=>"POST", -action=>$r->uri, -name=>'mainform'}),
	  	$self->hidden_authen_fields;
			
	  	#print '<div id="control_panel">';
	  	  #print '<div id="myset_control" class="mysets control">';
	  	  
	    	#some work for the moved controls
				my $list_of_local_sets = $self->{all_db_sets};
				my $have_local_sets = scalar(@$list_of_local_sets);
				my $library_selected = $self->{current_library_set};
				my $set_selected = $r->param('local_sets');
			
				if($have_local_sets ==0) {
					$list_of_local_sets = [NO_LOCAL_SET_STRING];
				} elsif (not defined($set_selected) or $set_selected eq ""
					or $set_selected eq SELECT_SET_STRING) {
					unshift @{$list_of_local_sets}, SELECT_SET_STRING;
					$set_selected = SELECT_SET_STRING;
				}
			
				# Tidy this list up since it is used in two different places
				if ($list_of_local_sets->[0] eq SELECT_SET_STRING) {
					shift @{$list_of_local_sets};
				}
	    	#print '</div>';
								
	  	#print '</div>';
	  	print '<div style="clear:both;padding:0px;margin:0px;"></div>';
	    #########  Table of mysets problems
	    print '<div id="problem_container">';
			  print '<div id="mysets_problems_box" class="mysets">';
				print '<h1>Target Set</h1>';
				print '<div class="setSelector">';
								#work for moved controlls
								$list_of_local_sets = $self->{all_db_sets};
								$have_local_sets = scalar(@$list_of_local_sets);
								$library_selected = $self->{current_myset_set};
								$set_selected = $r->param('myset_sets');
								my $remember_local_set = $r->param('local_sets');
				
								my $these_widths = "width: 25ex";
				
								if($have_local_sets ==0) {
									$list_of_local_sets = [NO_LOCAL_SET_STRING];
								} elsif (not defined($set_selected) or $set_selected eq ""
								or $set_selected eq SELECT_SET_STRING) {
									unshift @{$list_of_local_sets}, SELECT_SET_STRING;
									$set_selected = SELECT_SET_STRING;
								}
								# Tidy this list up since it is used in two different places
								if ($list_of_local_sets->[0] eq SELECT_SET_STRING) {
									shift @{$list_of_local_sets};
								}
				
								$self->browse_mysets_panel($library_selected, $list_of_local_sets, $remember_local_set);
								$self->make_mysets_row('all_db_sets'=>\@all_db_sets);
			  print '</div>';
				print '<div id="mysets_problems" class="problemList">';
	        for ($jj=0; $jj<scalar(@myset_html); $jj++) { 
	      	  $myset_files[$jj] =~ s|^$ce->{courseDirs}->{templates}/?||;
	      	  $self->make_myset_data_row($myset_files[$jj], $myset_html[$jj], $jj+1, $self->{past_marks}->[$jj]); 
	        }
	      print '</div>';
	      print '<p><button type="button" onclick="increasMysetsAcross();">+</button><span id="mysetsAcross">1</span><button type="button" onclick="decreaseMysetsAcross();">-</button><span> problems across</span></p>';
				print '</div>';
				print '<div id="horizontal_slider">=</div>';
				print '<div id="size_slider"><p>||</p></div>';
				
				#some work for the moved controls
				$list_of_local_sets = $self->{all_db_sets};
				$have_local_sets = scalar(@$list_of_local_sets);
				$library_selected = $self->{current_library_set};
				$set_selected = $r->param('local_sets');
			
				if($have_local_sets ==0) {
					$list_of_local_sets = [NO_LOCAL_SET_STRING];
				} elsif (not defined($set_selected) or $set_selected eq ""
					or $set_selected eq SELECT_SET_STRING) {
					unshift @{$list_of_local_sets}, SELECT_SET_STRING;
					$set_selected = SELECT_SET_STRING;
				}
			
				# Tidy this list up since it is used in two different places
				if ($list_of_local_sets->[0] eq SELECT_SET_STRING) {
					shift @{$list_of_local_sets};
				}
	      print '<div id="setmaker_library_box" class="setmaker_library">';
				  print '<h1>Library</h1>';
			    print '<div class="setSelector">';
			      ###########################################
			      # Library repository controls
		    	  ###########################################
	    		  print '<div id="setmaker_library" class="control">';
  						$self->make_top_row('all_db_sets'=>\@all_db_sets, 'browse_which'=> $browse_which);
	  					print '<div id="library_categories">';
	  					  #misplaced controlls
	  					  if ($browse_which eq 'browse_local') {
	  					  	$self->browse_local_panel($library_selected);
	  					  }	elsif ($browse_which eq 'edit_mysets') {
	  				  		$self->edit_mysets_panel($library_selected, $list_of_local_sets);
	  				  	} elsif ($browse_which eq 'browse_npl_library') {
	  				  		$self->browse_library_panel();
	  				  	} elsif ($browse_which eq 'browse_setdefs') {
	  				  		$self->browse_setdef_panel($library_selected);
	  				  	} else { ## handle other problem libraries
	  				  		$self->browse_local_panel($library_selected,$browse_which);
	  				  	}
	  					print '</div>';
	  					print CGI::div({-class=>"InfoPanel"},
                '<span class="js_action_span" onclick="selectAll();">all</span>
                <span style="margin-left:10px;" class="js_action_span" onclick="selectNone();">none</span>'
                #<span style="margin-left:10px;" class="js_action_span" onclick="rerandomize();">Rerandomize</span>
               # <span style="margin-left:10px;" class="js_action_span" onclick="cleardisplay();">Clear Problem Display</span>'
		          );
	  		    print '</div>';
	  		    ###########################################
  			  print '</div>';
			
			    print '<div class="setSelectorLib">';#what is this?
				  print '</div>';
					#hidden inputs for memeory
					#remember gridify
					print '<div id="setmaker_library_data">';
					print CGI::hidden(-id=>'pastGridded', -name=>'gridify', -value=>$gridded, -override=>1);
					print CGI::hidden(-id=>'isReordered', -name=>'isReordered', -vale=>0 ,-override=>0);
	        print CGI::hidden(-name=>'browse_which', -value=>$browse_which,-override=>1),
		      CGI::hidden(-name=>'problem_seed', -value=>$problem_seed, -override=>1);
	        for ($j = 0 ; $j < scalar(@pg_files) ; $j++) {
		        print CGI::hidden(-name=>"all_past_list$j", -value=>$pg_files[$j],-override=>1);
	        }
	        print CGI::hidden(-name=>'first_shown', -value=>$first_shown,-override=>1);
	        print CGI::hidden(-name=>'last_shown', -value=>$last_shown, -override=>1);
          print '<div id="setmaker_library_problems" class="problemList">';
	        ########## Now print problems
	          for ($jj=0; $jj<scalar(@pg_html); $jj++) { 
		          $pg_files[$jj] =~ s|^$ce->{courseDirs}->{templates}/?||;
		          $self->make_data_row($pg_files[$jj+$first_shown], $pg_html[$jj], $jj+1,         $self->{past_marks}->[$jj]); 
	          }
          print '</div>';
          print '<p><button type="button" onclick="increaseLibAcross();">+</button><span id="libAcross">4</span><button type="button" onclick="decreaseLibAcross();">-</button><span> problems across</span></p>';
	        ########## Finish things off
	        my ($next_button, $prev_button) = ("", "");
	        if ($first_shown > 0) {
		        #$prev_button = CGI::submit(-name=>"prev_page", -style=>"width:15ex", -value=>"Previous page");
		        my $urlpath = $r->urlpath;
            my $getProblemPath = $self->systemLink($urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::GetLibrarySetProblems", $r, courseID =>$urlpath->arg("courseID")));
	          $prev_button = "<span><button type='button' onclick='viewProblems(\"prev_page\" ,\"mainform\", \"".$r->uri."\", \"prev_spinner\");'>Previous page</button><img id='prev_spinner' style='display:none;' src='/webwork2_files/images/ajax-loader-small.gif'></img></span>";
	        }
	        if ((1+$last_shown)<scalar(@pg_files)) {
		        #$next_button = CGI::submit(-name=>"next_page", -style=>"width:15ex", -value=>"Next page");
		        my $urlpath = $r->urlpath;
            my $getProblemPath = $self->systemLink($urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::GetLibrarySetProblems", $r, courseID =>$urlpath->arg("courseID")));
	          $next_button = "<span><button type='button' onclick='viewProblems(\"next_page\" ,\"mainform\", \"".$r->uri."\", \"next_spinner\");'>Next page</button><img id='next_spinner' style='display:none;' src='/webwork2_files/images/ajax-loader-small.gif'></img></span>";
	        }
	        if (scalar(@pg_files)>0) {
		        print CGI::p(($first_shown+1)."-".($last_shown+1)." of ".scalar(@pg_files)." shown.", $prev_button, " ", $next_button,
			      '<span><button type="button" style="float:right;" onclick="saveChanges(\'mainform\', \''.$r->uri.'\', \'save_changes_spinner2\');">save changes</button><img id="save_changes_spinner2" style="display:none;float:right;" src="/webwork2_files/images/ajax-loader-small.gif"></img></span>');
	        }
	        #close setmaker_library_data
	        print '</div>';
	        #close setmaker_library
	      print '</div>';
	    #close problem_container
	    print '</div>';
	  print CGI::end_form(), "\n";
	  #close form-editor
	print '</div>';
	print '<div style="clear:both;"></div>';
	#	 if($first_shown>0 or (1+$last_shown)<scalar(@pg_files)) {
	
	#	 }
	# end big wrapper div that will hopefully fix theme issues
  print '</div>';
	return "";	
}

=head1 AUTHOR

Written by John Jones, jj (at) asu.edu.
Edited by David Gage

=cut

1;
