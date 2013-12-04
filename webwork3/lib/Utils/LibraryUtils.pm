## This is a number of common subroutines needed when processing the routes.  


package Utils::LibraryUtils;
use base qw(Exporter);
use Path::Class qw/file dir/;
use Dancer;
use Dancer::Plugin::Database;
use Data::Dumper;
use WeBWorK::Utils qw(readDirectory sortByName);
our @EXPORT    = ();
our @EXPORT_OK = qw(list_pg_files searchLibrary getProblemTags render);

my %ignoredir = (
	'.' => 1, '..' => 1, 'CVS' => 1, 'tmpEdit' => 1,
	'headers' => 1, 'macros' => 1, 'email' => 1, '.svn' => 1, 'achievements' => 1,
);

###
#
#  Common functionality for the renderer
#
###

sub render {
	my $renderParams = shift;

	# get all parameters in the form AnSwErXXXX 

	my @anskeys = grep /AnSwEr\d{4}/, request->params;

	my $formFields = {};
	for my $key (@anskeys){
		$formFields->{$key} = params->{$key};
	}

	# remove any pretty garbage around the problem
	local vars->{ce}->{pg}{specialPGEnvironmentVars}{problemPreamble} = {TeX=>'',HTML=>''};
	local vars->{ce}->{pg}{specialPGEnvironmentVars}{problemPostamble} = {TeX=>'',HTML=>''};


	my $translationOptions = {
		displayMode     => $renderParams->{displayMode},
		showHints       => $renderParams->{showHints},
		showSolutions   => $renderParams->{showSolutions},
		refreshMath2img => defined(param("refreshMath2img")) ? param("refreshMath2img") : 0 ,
		processAnswers  => defined(param("processAnswers")) ? param("processAnswers") : 1
	};


	my $pg = new WeBWorK::PG(
		vars->{ce},
		$renderParams->{user},
		params->{session_key},
		$renderParams->{set},
		$renderParams->{problem},
		123, # PSVN (practically unused in PG)
		$formFields,
		$translationOptions,
    );
	my $warning_messages="";
    my (@internal_debug_messages, @pgwarning_messages, @pgdebug_messages);
    if (ref ($pg->{pgcore}) ) {
    	@internal_debug_messages = $pg->{pgcore}->get_internal_debug_messages;
    	@pgwarning_messages        = $pg ->{pgcore}->get_warning_messages();
    	@pgdebug_messages          = $pg ->{pgcore}->get_debug_messages();
    } else {
    	@internal_debug_messages = ('Error in obtaining debug messages from PGcore');
    }
    my $answers = {};


    # extract the important parts of the answer, but don't send the correct_ans if not requested. 

    debug $renderParams;

    for my $key (@anskeys){
    	for my $field (qw(correct_ans score student_ans)) {
    		if ($field ne 'correct_ans' || $renderParams->{showAnswers}){
	    		$answers->{$key}->{$field} = $pg->{answers}->{$key}->{$field};
	    	}
	    }
    }
    
    my $flags = {};

    ## skip the CODE reference which appears in the PROBLEM_GRADER_TO_USE.  I don't think this is useful for 
    ## passing out to the client since it is a perl code snippet.

    for my $key (keys(%{$pg->{flags}})){
     	if (ref($pg->{flags}->{$key}) ne "CODE"){
     	$flags->{$key}=$pg->{flags}->{$key};}
     }

    my $problem_hash = {
		text 						=> $pg->{body_text},
		header_text 				=> $pg->{head_text},
		answers 					=> $answers,
		errors         				=> $pg->{errors},
		warnings	   				=> $pg->{warnings}, 
		problem_result 				=> $pg->{result},
		problem_state				=> $pg->{state},
		flags						=> $flags,
		warning_messages            => \@pgwarning_messages,
		debug_messages              => \@pgdebug_messages,
		internal_debug_messages     => \@internal_debug_messages,
	};

	return $problem_hash;

}



sub getFilePaths {
	my $allfiles = shift;

	my @problems = ();

	## this seems like a very inefficient way to look up the path header.  Can we build a hash to do this? 

	for my $file (@$allfiles){
		my $path_header = database->quick_select('OPL_path',{path_id=>$file->{path_id}});
		push(@problems,{source_file=>"Library/" . $path_header->{path} . "/" . $file->{filename}});
	}

	return \@problems;
}




## this returns all problems in the library that matches the given subject

sub get_subject_problems {
	my ($subject) = @_;

	my $queryString = "select CONCAT(path.path,'/',pg.filename) AS fullpath,pg.morelt_id "
					. "from OPL_DBsubject AS sub "
					. "JOIN OPL_DBchapter AS ch ON sub.DBsubject_id = ch.DBsubject_id " 
					. "JOIN OPL_DBsection AS sect ON sect.DBchapter_id = ch.DBchapter_id "
					. "JOIN OPL_pgfile AS pg ON sect.DBsection_id = pg.DBsection_id "
					. "JOIN OPL_path AS path ON pg.path_id = path.path_id "
					. "WHERE sub.name='" . $subject . "';";

	my $results = database->selectall_arrayref($queryString);

	my @problems=  map {{source_file=>"Library/" .$_->[0], morelt=>$_[1]} } @{$results};

	return \@problems;


}

## this returns all problems in the library that matches the given subject/chapter


sub get_chapter_problems {
	my ($subject,$chapter) = @_;

	my $queryString = "select CONCAT(path.path,'/',pg.filename) AS fullpath,pg.morelt_id "
					. "from OPL_DBsection AS sect "
					. "JOIN OPL_DBsubject AS sub "
					. "JOIN OPL_DBchapter AS ch ON ch.DBchapter_id = sect.DBchapter_id "
					. "JOIN OPL_pgfile AS pg ON sect.DBsection_id = pg.DBsection_id "
					. "JOIN OPL_path AS path ON pg.path_id = path.path_id "
					. "WHERE ch.name='" . $chapter . "' and sub.name='" . $subject . "';";

	my $results = database->selectall_arrayref($queryString);

	my @problems=  map {{source_file=>"Library/" .$_->[0], morelt=>$_[1]} } @{$results};

	return \@problems;

}



## this returns all problems in the library that matches the given subject/chapter/section


sub get_section_problems {
	my ($subject,$chapter,$section) = @_;

	my $queryString = "select CONCAT(path.path,'/',pg.filename) AS fullpath,pg.morelt_id "
					. "from OPL_DBsection AS sect "
					. "JOIN OPL_DBchapter AS ch JOIN OPL_DBsubject AS sub "
					. "JOIN OPL_pgfile AS pg ON sect.DBsection_id = pg.DBsection_id "
					. "JOIN OPL_path AS path ON pg.path_id = path.path_id "
					. "WHERE sect.name='" . $section . "' AND ch.name='" . $chapter . "'"
					. "and sub.name='" . $subject . "';";

	my $results = database->selectall_arrayref($queryString);

	my @problems=  map {{source_file=>"Library/" .$_->[0], morelt=>$_[1]} } @{$results};

	return \@problems;
}

## search the library
#
#  The search criteria is passed in as a hash with the following possible keys:
#
#		keywords
#		subject
#		chapter
#		section
#		textbook
#		textbook_chapter
#		textbook_section
#		level
#
#		(currently not all of these are implemented)
#
###

sub searchLibrary {
	my ($param) = @_;

	debug $param;

	my $selectClause = "SELECT CONCAT(path.path,'/',pg.filename),pg.pgfile_id "
					. "FROM OPL_path AS path "
					. "JOIN OPL_pgfile AS pg ON path.path_id=pg.path_id ";

	my $groupClause = ""; 
	my $whereClause = "WHERE ";

	## keyword search.  Note: only a single keyword works right now.
	if(defined($param->{keyword})){
		my $kw = $param->{keyword};
		$kw =~ s/\s//g; #remove all spaces

		$selectClause .= "LEFT JOIN OPL_pgfile_keyword AS pgkey ON pgkey.pgfile_id=pg.pgfile_id "
						. "LEFT JOIN OPL_keyword AS kw ON kw.keyword_id=pgkey.keyword_id ";
		$whereClause .= "kw.keyword LIKE '" . $kw . "' ";
		$groupClause = "GROUP BY pg.pgfile_id";

	} 
	## level search as a range of numbers like 2-4 
	if (defined($param->{level}) && $param->{level} =~ /^[1-6]-[1-6]$/) {
		if($param->{level} =~ /^(\d)-(\d)$/){
			$whereClause .="AND " if(length($whereClause)>6); 
			$whereClause .= "pg.level BETWEEN $1 AND $2 ";
		}
	}
	## level search as a set of numbers like 1,3,5 (works as a single number too)
	if (defined($param->{level}) && $param->{level} =~ /^[1-6](,[1-6])*$/) {
		$whereClause .="AND " if(length($whereClause)>6); 
		$whereClause .="pg.level IN (" . $param->{level} . ") ";
	}
	## problem author search    note: only searches by last name right now
	if (defined($param->{author})){
		$selectClause .= "JOIN OPL_author AS author ON author.author_id = pg.author_id ";
		$whereClause .="AND " if(length($whereClause)>6); 
		$whereClause .="(author.lastname LIKE '" . $param->{author} . "' OR author.firstname LIKE '" . $param->{author} . "') ";
	}
	## institution search
	## level search as a set of numbers like 1,3,5 (works as a single number too)
	if (defined($param->{institution})) {
		$whereClause .="AND " if(length($whereClause)>6); 
		$whereClause .="pg.institution LIKE '" . $param->{institution} . "'  ";
	}
	## DBsubject/DBchapter/DBsection search
	if(defined($param->{subject}) || defined($param->{chapter}) || defined($param->{section})){
		$selectClause .= "JOIN OPL_DBsection AS DBsect ON DBsect.DBsection_id = pg.DBsection_id "
						. "JOIN OPL_DBchapter AS DBch ON DBsect.DBchapter_id = DBch.DBchapter_id " 
						. "JOIN OPL_DBsubject AS DBsubj ON DBsubj.DBsubject_id = DBch.DBsubject_id ";
	}
	##DBsubject searach
	if(defined($param->{subject})){
		$whereClause .="AND " if(length($whereClause)>6); 
		$whereClause .="DBsubj.name LIKE '" . $param->{subject} . "'  ";
	} 
	## DBchapter search
	if(defined($param->{chapter})){
		$whereClause .="AND " if(length($whereClause)>6); 
		$whereClause .="DBch.name LIKE '" . $param->{chapter} . "'  ";
	}
	## DBsection search
	if(defined($param->{section})){
		$whereClause .="AND " if(length($whereClause)>6); 
		$whereClause .="DBsect.name LIKE '" . $param->{section} . "'  ";
	}
	##Textbook search 
	if(defined($param->{section_id})||defined($param->{textbook_id})||defined($param->{chapter_id})){
		$selectClause .= "LEFT JOIN OPL_pgfile_problem AS pgprob ON pgprob.pgfile_id=pg.pgfile_id "
				. "LEFT JOIN OPL_problem AS prob ON pgprob.problem_id=prob.problem_id "
				. "LEFT JOIN OPL_section AS sect ON prob.section_id=sect.section_id "
				. "LEFT JOIN OPL_chapter AS ch ON ch.chapter_id = sect.chapter_id "
				. "LEFT JOIN OPL_textbook AS textbook ON textbook.textbook_id = ch.textbook_id ";
	}
	##Textbook textbook_id search
	if(defined($param->{textbook_id})){
		$whereClause .="AND " if(length($whereClause)>6); 
		$whereClause .="textbook.textbook_id='".$param->{textbook_id} ."' ";
	}
	##Textbook chapter_id search
	if(defined($param->{chapter_id})){
		$whereClause .="AND " if(length($whereClause)>6); 
		$whereClause .="ch.chapter_id='".$param->{chapter_id} ."' ";
	}
	##Textbook section_id search
	if(defined($param->{section_id})){
		$whereClause .="AND " if(length($whereClause)>6); 
		$whereClause .="sect.section_id='".$param->{section_id} ."' ";
	}

	debug $selectClause,$whereClause.$groupClause;

	my $results = database->selectall_arrayref($selectClause . $whereClause . $groupClause . ";");

	my @problems = map { {source_file => "Library/" . $_->[0], pgfile_id=>$_->[1] } } @{$results};
	
	return \@problems;
}


sub getProblemTags {
	my $fileID = shift;
	if ($fileID < 0){  ## then the pgfile_id is not defined.  Use the source_file to look up the information. 

		my $file = file(params->{source_file});
		my @fileDirs = $file->parent->components; 
		@fileDirs = @fileDirs[1..$#fileDirs];

		my $path = dir(@fileDirs);
		my $filename = $file->basename;
		my $queryString = "SELECT pg.pgfile_id FROM OPL_path AS path "
							." JOIN OPL_pgfile AS pg ON path.path_id = pg.path_id "
							." WHERE path.path='" . $path->stringify .  "' and pg.filename='" . $filename . "';";
       my $pathID = database->selectrow_arrayref($queryString);							
       $fileID = $pathID->[0];

	}


	my	$selectClause = "SELECT CONCAT(author.firstname,' ',author.lastname), group_concat(DISTINCT kw.keyword), "
						. "pg.level, pg.institution, DBsubj.name, DBch.name, DBsect.name, mlt.name, "
						. "textbook.title,ch.name,sect.name "
						. "FROM OPL_path AS path JOIN OPL_pgfile AS pg ON path.path_id=pg.path_id "
						. "LEFT JOIN OPL_pgfile_keyword AS pgkey ON pgkey.pgfile_id=pg.pgfile_id "
						. "LEFT JOIN OPL_keyword AS kw ON kw.keyword_id=pgkey.keyword_id "
						. "LEFT JOIN OPL_author AS author ON author.author_id = pg.author_id "
						. "LEFT JOIN OPL_DBsection AS DBsect ON DBsect.DBsection_id = pg.DBsection_id "
						. "LEFT JOIN OPL_DBchapter AS DBch ON DBsect.DBchapter_id = DBch.DBchapter_id " 
						. "LEFT JOIN OPL_DBsubject AS DBsubj ON DBsubj.DBsubject_id = DBch.DBsubject_id "
						. "LEFT JOIN OPL_morelt AS mlt ON mlt.morelt_id = pg.morelt_id "
						. "LEFT JOIN OPL_pgfile_problem AS pgprob ON pgprob.pgfile_id=pg.pgfile_id "
						. "LEFT JOIN OPL_problem AS prob ON pgprob.problem_id=prob.problem_id "
						. "LEFT JOIN OPL_section AS sect ON prob.section_id=sect.section_id "
						. "LEFT JOIN OPL_chapter AS ch ON ch.chapter_id = sect.chapter_id "
						. "LEFT JOIN OPL_textbook AS textbook ON textbook.textbook_id = ch.textbook_id ";
	my $whereClause ="WHERE pg.pgfile_id='". $fileID ."'";
	
	debug $selectClause. $whereClause;

	my $results = database->selectrow_arrayref($selectClause . $whereClause . ";");

	return { author => $results->[0], keyword => $results->[1] , level=>$results->[2], institution=>$results->[3],
				  subject=> $results->[4], chapter=>$results->[5], section=>$results->[6], morelt=>$results->[7],
				  textbook_title=> $results->[8], textbook_chapter=>$results->[9], textbook_section=>$results->[10]};

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

# sub get_library_sets {
	
# 	my ($top,$base,$dir,$probLib) = @_;
# 	# ignore directories that give us an error
# 	my @lis = eval { readDirectory($dir) };
# 	if ($@) {
# 		warn $@;
# 		return (0);
# 	}
# 	return (0) if grep /^=library-ignore$/, @lis;

# 	my @pgfiles = grep { m/\.pg$/ and (not m/(Header|-text)(File)?\.pg$/) and -f "$dir/$_"} @lis;
# 	my $pgcount = scalar(@pgfiles);
# 	my $pgname = $dir; $pgname =~ s!.*/!!; $pgname .= '.pg';
# 	my $combineUp = ($pgcount == 1 && $pgname eq $pgfiles[0] && !(grep /^=library-no-combine$/, @lis));

# 	my @pgdirs;
# 	my @dirs = grep {!$ignoredir{$_} and -d "$dir/$_"} @lis;
# 	if ($top == 1) {@dirs = grep {!$problib{$_}} @dirs}
# 	# Never include Library at the top level
# 	if ($top == 1) {@dirs = grep {$_ ne 'Library'} @dirs} 
# 	foreach my $subdir (@dirs) {
# 		my @results = get_library_sets(0, "$dir/$subdir");
# 		$pgcount += shift @results; push(@pgdirs,@results);
# 	}

# 	return ($pgcount, @pgdirs) if $top || $combineUp || grep /^=library-combine-up$/, @lis;
# 	return (0,@pgdirs,$dir);
# }


# sub get_library_pgs {

# 	#print join(",",@_) . "\n";

# 	my ($top,$base,$dir,$probLib) = @_;

# 	debug "top: $top  base: $base dir:  $dir probLib: $probLib \n";
# 	debug Dumper($probLib);
# 	my @lis = readDirectory("$base/$dir");
# 	return () if grep /^=library-ignore$/, @lis;
# 	return () if !$top && grep /^=library-no-combine$/, @lis;

# 	my @pgs = grep { m/\.pg$/ and (not m/(Header|-text)\.pg$/) and -f "$base/$dir/$_"} @lis;
# 	my $others = scalar(grep { (!m/\.pg$/ || m/(Header|-text)\.pg$/) &&
# 	                            !m/(\.(tmp|bak)|~)$/ && -f "$base/$dir/$_" } @lis);

# 	my @dirs = grep {!$ignoredir{$_} and -d "$base/$dir/$_"} @lis;
# 	if ($top == 1) {@dirs = grep {!$problib->{$_}} @dirs}

# 	debug Dumper(@dirs);

# 	foreach my $subdir (@dirs) {push(@pgs, get_library_pgs(0,"$base/$dir",$subdir,$probLib))}

# 	return () unless $top || (scalar(@pgs) == 1 && $others) || grep /^=library-combine-up$/, @lis;
# 	return (map {"$dir/$_"} @pgs);
# } 

sub list_pg_files {
	my ($templates,$dir,$probLib) = @_;
	#print "templates: $templates    dir: $dir   problib: $probLib \n";
	my $top = ($dir eq '.')? 1 : 2;
	my @pgs = get_library_pgs($top,$templates,$dir,$probLib);
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