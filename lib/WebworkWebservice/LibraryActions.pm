#!/usr/local/bin/perl -w 

# Copyright (C) 2002 Michael Gage 

###############################################################################
# Web service which fetches WeBWorK problems from a library.
###############################################################################


#use lib '/home/gage/webwork/pg/lib';
#use lib '/home/gage/webwork/webwork-modperl/lib';

package WebworkWebservice::LibraryActions;

use WebworkWebservice;
use WeBWorK::Utils::ListingDB;
use base qw(WebworkWebservice); 
use WeBWorK::Debug;
use JSON;

use strict;
use sigtrap;
use Carp;
use WWSafe;
#use Apache;
use WeBWorK::Utils qw(readDirectory sortByName);
use WeBWorK::CourseEnvironment;
use WeBWorK::PG::Translator;
use WeBWorK::PG::IO;
use Benchmark;
use MIME::Base64 qw( encode_base64 decode_base64);

##############################################
#   Obtain basic information about directories, course name and host 
##############################################
our $WW_DIRECTORY = $WebworkWebservice::WW_DIRECTORY;
our $PG_DIRECTORY = $WebworkWebservice::PG_DIRECTORY;
our $COURSENAME   = $WebworkWebservice::COURSENAME;
our $HOST_NAME    = $WebworkWebservice::HOST_NAME;
our $PASSWORD     = "we-don't-need-no-stinking-passowrd";


use constant MY_PROBLEMS => '  My Problems  ';
use constant MAIN_PROBLEMS => '  Unclassified Problems  ';

my %problib;	## This is configured in defaults.config

# list of directories to ignore while search through the libraries.

my %ignoredir = (
	'.' => 1, '..' => 1, 'Library' => 1, 'CVS' => 1, 'tmpEdit' => 1,
	'headers' => 1, 'macros' => 1, 'email' => 1, '.svn' => 1,
);


#our $ce           = WeBWorK::CourseEnvironment->new($WW_DIRECTORY, "", "", $COURSENAME);
# warn "library ce \n ", WebworkWebservice::pretty_print_rh($ce);
# warn "LibraryActions is ready";

##############################################
#   Obtain basic information about local libraries
##############################################
# my %prob_libs	= %{$ce->{courseFiles}->{problibs} };

 #warn pretty_print_rh(\%prob_libs);
 # replace library names with full paths
 
# my $templateDir    = $ce->{courseDirs}->{templates};
# warn "template Directory is $templateDir";
# foreach my $key (keys %prob_libs) {
# 	$prob_libs{$key} = "$templateDir/$key";
# }
 #warn "prob libraries", WebworkWebservice::pretty_print_rh(\%prob_libs);

sub listLibraries {  # list the problem libraries that are available.
	my $self = shift;
	my $rh = shift;
	#my $my_ce = $self->{ce};
	my %libraries = %{$self->{ce}->{courseFiles}->{problibs}};
 
	my $templateDirectory = $self->{ce}->{courseDirs}{templates};

	foreach my $key (keys %libraries) {
 		$libraries{$key} = "$templateDirectory/$key";
 	}
	
	my @outListLib = sort keys %libraries;
	my $out = {};
	$out->{ra_out} = \@outListLib;
	$out->{text} = encode_base64("success");
	return $out;
}

use File::stat;
sub readFile {
    my $self = shift;
	my $rh   = shift;
	local($|)=1;
	my $out = {};
	my $filePath = $rh->{filePath};

	my %libraries = %{$self->{ce}->{courseFiles}->{problibs}};
 
	my $templateDirectory = $self->{ce}->{courseDirs}{templates};

	foreach my $key (keys %libraries) {
 		$libraries{$key} = "$templateDirectory/$key";
 	}
	

	
	if (  defined($libraries{$rh->{library_name}} )   ) {
		$filePath = $libraries{$rh->{library_name}} .'/'. $filePath;
	} else {
		$out->{error} = "Could not find library:".$rh->{library_name}.":";
		return($out);
	}
	warn "searching for file at $filePath";
	if (-r $filePath) {
		open IN, "<$filePath";
		local($/)=undef;
		my $text = <IN>;
		$out->{text}= encode_base64($text);
		my $sb=stat($filePath);
		$out->{size}=$sb->size;
		$out->{path}=$filePath;
		$out->{permissions}=$sb->mode&07777;
		$out->{modTime}=scalar localtime $sb->mtime;
		close(IN);
	} else {
	    warn "Could not read file at |$filePath|";
		$out->{error} = "Could not read file at |$filePath|";
	}
	return($out);
}

use File::Find;	
#idea from http://www.perlmonks.org/index.pl?node=How%20to%20map%20a%20directory%20tree%20to%20a%20perl%20hash%20tree
sub build_tree {
    warn "entering build_tree with ",join(" ", @_);
    my $node = $_[0] = {};
    my @s;
    find({wanted=>sub {
      # fixed 'if' => 'while' -- thanks Rudif
      unless ($File::Find::dir =~/.svn/ || $File::Find::name =~/.svn/) {
      	$node = (pop @s)->[1] while @s and $File::Find::dir ne $s[-1][0];
     	return $node->{$_} = -s if -f;
      	push @s, [ $File::Find::name, $node ];
      	$node = $node->{$_} = {};
      }
    }, follow_fast=>1}, $_[1]);
    $_[0]{$_[1]} = delete $_[0]{'.'};
}

sub listLib {
	my $self = shift;
	my $rh = shift;
	my $out = {};
	if ($rh->{library_name}=~ m|^/|) {
		warn "double slash in library_name ", $rh->{library_name};
		$rh->{library_name} =~ s|^/||;
	}
	my $dirPath = $self->{ce}->{courseDirs}{templates}."/".$rh->{library_name};	
	my $maxdepth= $rh->{maxdepth};
	my $dirPath2 = $dirPath . ( ($rh->{dirPath}) ?  '/'.$rh->{dirPath}  : '' ) ;


	my @tare = $dirPath2=~m|/|g; 
	my $tare = @tare;     # counts number of "/" in dirPath prefix
	my @outListLib;
	my %libDirectoryList;
	my $depthfinder = sub {   # counts depth below the current directory
		my $path = shift;
		my @count = $path=~m|/|g;
		my $depth = @count;
		return $depth - $tare;
	};
	my $wanted = sub {  # find .pg files
		unless ($File::Find::dir =~/.svn/ ) {
			my $name = $File::Find::name;
			if ($name =~/\S/ ) {
				#$name =~ s|^$dirPath2/*||;  # cut the first directory
				push(@outListLib, "$name") if $name =~/\.pg/;
	
			}
		}
	};
	
	my $wanted_directory = sub {
	    $File::Find::prune =1 if &$depthfinder($File::Find::dir) > $maxdepth;
		unless ($File::Find::dir =~/.svn/ ) {
			my $dir = $File::Find::dir;
			if ($dir =~/\S/ ) {
				$dir =~ s|^$dirPath2/*||;  # cut the first directory
	
				$libDirectoryList{$dir} = {};
			}
		}
	};
	 
	my $command = $rh->{command};

	#warn "the command being executed is ' $command '";
	$command = 'all' unless defined($command);
	
		$command eq 'all' &&    do {
									$out->{command}="all -- list all pg files in $dirPath";
									find({wanted=>$wanted,follow_fast=>1 }, $dirPath);
									@outListLib = sort @outListLib;
									$out->{ra_out} = \@outListLib;
									$out->{text} = encode_base64( join("\n", @outListLib) );
									return($out);
		};
		$command eq 'dirOnly' &&   do {
									if ( -e $dirPath2 and $dirPath2 !~ m|//|) {
									    # it turns out that when // occur in path -e will work
									    # but find will not :-( 
									    warn "begin find for $dirPath2";
										find({wanted=>$wanted_directory,follow_fast=>1 }, $dirPath2);
										#@outListLib = grep {/\S/} sort keys %libDirectoryList; #omit blanks
										#foreach my $key (grep {/\S/} sort keys %libDirectoryList) {
										#	push @outListLib, "$key"; # number of subnodes
										#}
										warn "find completed ";
										warn "result: ", join(" ", %libDirectoryList);
										delete $libDirectoryList{""};
										$out->{ra_out} = \%libDirectoryList;
										$out->{text} = encode_base64("Loaded libraries");
										return($out);
									} else {
									   warn "Can't open directory  $dirPath2";
									   $out->{error} = "Can't open directory  $dirPath2";
									}
		};
#			 use File::Find::Rule;
  			# find all the subdirectories of a given directory
#   			my @subdirs = File::Find::Rule->directory->in( $dirPath );
# 			$command eq 'dirOnly' && do {
# 				my @subdirs = File::Find::Rule->directory->in( ($dirPath) );
# 				$out->{ra_out} = \@subdirs;
# 				$out->{text} = encode_base64("Loaded libraries".$dirPath);
# 				return($out);			
# 			};
		$command eq 'buildtree' &&   do {
									#find({wanted=>$wanted_directory,follow_fast=>1 }, $dirPath);
									warn "using build_tree with dirPath $dirPath";
									build_tree(my $tree, $dirPath);
									#@outListLib = sort keys %libDirectoryList;
									$out->{ra_out} = $tree;
									warn "output of build_tree is ", %$tree;
									$out->{text} = encode_base64("Loaded libraries");
									return($out);
		};
		
		$command eq 'files' && do {  @outListLib=();
									 #my $separator = ($dirPath =~m|/$|) ?'' : '/';
									 #my $dirPath2 = $dirPath . $separator . $rh->{dirPath};

									 warn( "dirPath2 in files is: ", $dirPath2);
									 if ( -e $dirPath2 and $dirPath2 !~ m|//| ) {
										 find($wanted, $dirPath2);
										 @outListLib = sort @outListLib;
										 #$out ->{text} = encode_base64( join("", @outListLib ) );
										 $out ->{text} = encode_base64( "Problems loaded" );
										 $out->{ra_out} = \@outListLib;
									 } else {
									   warn "Can't open directory  $dirPath2 in listLib files";
									   $out->{error} = "Can't open directory  $dirPath2";
									 }
									 return($out);
		
		};
		# else
	$out->{error}="Unrecognized command $command";
	return( $out );
}

sub searchLib {    #API for searching the NPL database

	my $self = shift;
	my $rh = shift;
	my $out = {};
	my $ce = $self->{ce};
	my $subcommand = $rh->{command};
	if($rh->{library_levels}) {
		$self->{level} = [split(//, $rh->{library_levels})];
	}
	
	'getDBTextbooks' eq $subcommand && do {
		$self->{library_subjects} = $rh->{library_subjects};
		$self->{library_chapters} = $rh->{library_chapters};
		$self->{library_sections} = $rh->{library_sections};
		$self->{library_textchapter} = $rh->{library_textchapter};
		my @textbooks = WeBWorK::Utils::ListingDB::getDBTextbooks($self);
		$out->{ra_out} = \@textbooks;
		return($out);		
	};
	'getAllDBsubjects' eq $subcommand && do {
		my @subjects = WeBWorK::Utils::ListingDB::getAllDBsubjects($self);
		$out->{ra_out} = \@subjects;
		$out->{text} = encode_base64("Subjects loaded.");
		return($out);		
	};
	'getAllDBchapters' eq $subcommand && do {
		$self->{library_subjects} = $rh->{library_subjects};
		my @chaps = WeBWorK::Utils::ListingDB::getAllDBchapters($self);
		$out->{ra_out} = \@chaps;
        $out->{text} = encode_base64("Chapters loaded.");

		return($out);		
	};
	'getDBListings' eq $subcommand && do {

		my $templateDir = $self->{ce}->{courseDirs}->{templates};
		$self->{library_subjects} = $rh->{library_subjects};
		$self->{library_chapters} = $rh->{library_chapters};
		$self->{library_sections} = $rh->{library_sections};
		$self->{library_keywords} = $rh->{library_keywords};
		$self->{library_textbook} = $rh->{library_textbook};
		$self->{library_textchapter} = $rh->{library_textchapter};
		$self->{library_textsection} = $rh->{library_textsection};
		debug(to_json($rh));
		my @listings = WeBWorK::Utils::ListingDB::getDBListings($self);
		my @output = map {$templateDir."/Library/".$_->{path}."/".$_->{filename}} @listings;
		#change the hard coding!!!....just saying
		$out->{ra_out} = \@output;
		return($out);
	};
	'getSectionListings' eq $subcommand && do {
		$self->{library_subjects} = $rh->{library_subjects};
		$self->{library_chapters} = $rh->{library_chapters};
		$self->{library_sections} = $rh->{library_sections};

		my @section_listings = WeBWorK::Utils::ListingDB::getAllDBsections($self);
		$out->{ra_out} = \@section_listings;
        $out->{text} = encode_base64("Sections loaded.");

		return($out);
	};

	'countDBListings' eq $subcommand && do {
		$self->{library_subjects} = $rh->{library_subjects};
		$self->{library_chapters} = $rh->{library_chapters};
		$self->{library_sections} = $rh->{library_sections};
		$self->{library_keywords} = $rh->{library_keywords};
		$self->{library_textbook} = $rh->{library_textbook};
		$self->{library_textchapter} = $rh->{library_textchapter};
		$self->{library_textsection} = $rh->{library_textsection};
		my $count = WeBWorK::Utils::ListingDB::countDBListings($self);
					$out->{text} = encode_base64("Count done.");
		$out->{ra_out} = [$count];
		return($out);
	};
	
	#else (no match )
	$out->{error}="Unrecognized command $subcommand";
	return( $out );
}

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


sub getProblemDirectories {

	my $self = shift;
	my $rh = shift;
	my $out = {};
	my $ce = $self->{ce};

	my %libraries = %{$self->{ce}->{courseFiles}->{problibs}};

	my $lib = "Library";
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

	$out->{ra_out} = \@all_problem_directories;
    $out->{text} = encode_base64("Problem Directories loaded.");

	return($out);
}

##
#  This subroutines outputs the entire library based on Subjects, chapters and sections. 
#
#  The output is an array in the form "Subject/Chapter/Section"
##  

sub buildBrowseTree {
	my $self = shift;
	my $rh = shift;
	my $out = {};
	my $ce = $self->{ce};
	my @tree = ();
	my @subjects = WeBWorK::Utils::ListingDB::getAllDBsubjects($self);
	foreach my $sub (@subjects) {
		$self->{library_subjects} = $sub;
		push(@tree,"Subjects/" . $sub);
		my @chapters = WeBWorK::Utils::ListingDB::getAllDBchapters($self);
		foreach my $chap (@chapters){
			$self->{library_chapters} = $chap; 
			push(@tree, "Subjects/" .$sub . "/" . $chap);
			my @sections = WeBWorK::Utils::ListingDB::getAllDBsections($self);
			foreach my $sect (@sections){
				push(@tree, "Subjects/" .$sub . "/" . $chap . "/" . $sect);
			}
		}
	}
	$out->{ra_out} = \@tree;
	$out->{text} = encode_base64("Subjects, Chapters and Sections loaded.");
	return($out);
}

sub getProblemTags {
	my $self = shift;
	my $rh = shift;
	my $out = {};
	my $path = $rh->{command};
        # Get a pointer to a hash of DBchapter, ..., DBsection
	my $tags = WeBWorK::Utils::ListingDB::getProblemTags($path);
	$out->{ra_out} = $tags;
	$out->{text} = encode_base64("Tags loaded.");
	
	return($out);
}

sub setProblemTags {
	my $self = shift;
	my $rh = shift;
	my $path = $rh->{command};
	my $dbsubj = $rh->{library_subjects};
	my $dbchap = $rh->{library_chapters};
	my $dbsect = $rh->{library_sections};
	my $level = $rh->{library_levels};
	# result is [success, message] with success = 0 or 1
	my $result = WeBWorK::Utils::ListingDB::setProblemTags($path, $dbsubj, $dbchap, $dbsect, $level);
	my $out = {};
	$out->{text} = encode_base64($result->[1]);
	return($out);
}


sub pretty_print_rh {
	my $rh = shift;
	my $out = "";
	my $type = ref($rh);
	if ( ref($rh) =~/HASH/ ) {
 		foreach my $key (sort keys %{$rh})  {
 			$out .= "  $key => " . pretty_print_rh( $rh->{$key} ) . "\n";
 		}
	} elsif ( ref($rh) =~ /SCALAR/ ) {
		$out = "scalar reference ". ${$rh};
	} elsif ( ref($rh) =~/Base64/ ) {
		$out .= "base64 reference " .$$rh;
	} else {
		$out =  $rh;
	}
	if (defined($type) ) {
		$out .= "type = $type \n";
	}
	return $out;
}


1;
