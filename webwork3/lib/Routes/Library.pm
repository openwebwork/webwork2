### Library routes
##
#  These are the routes for all library functions in the RESTful webservice
#
##

package Routes::Library;

use strict;
use warnings;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Path::Class;
use File::Find::Rule;
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;
use Utils::LibraryUtils qw/list_pg_files get_section_problems get_chapter_problems get_subject_problems 
	searchLibrary getProblemTags/;
use Routes::Authentication qw/checkPermissions authenticate setCourseEnvironment/;
use WeBWorK::DB::Utils qw(global2user);
use WeBWorK::Utils::Tasks qw(fake_user fake_set fake_problem);
use WeBWorK::PG::Local;

# use constant MY_PROBLEMS => '  My Problems  ';
# use constant MAIN_PROBLEMS => '  Unclassified Problems  ';
# use constant fakeSetName => "Undefined_Set";
# use constant fakeUserName => "Undefined_User";


get '/Library/subjects' => sub {

	my $webwork_dir = config->{webwork_dir};
	my $file = "$webwork_dir/htdocs/DATA/library-subject-tree.json";
	my $json_text = do {
   		open(my $json_fh, "<:encoding(UTF-8)", $file)  or send_error("The file $file does not exist.",404);
	    local $/;
	    <$json_fh>
	};

	return $json_text;

};

####
#
#  get all problems with subject *subject_id* 
#
#   returns a array of problem paths? (global problem_id's)?
#
#  should pass in an limit on number of problems to return (100 for default?)
#
####


get '/Library/subjects/:subject/problems' => sub {

	return get_subject_problems(params->{subject});

};


####
#
#  get all problems with subject *subject_id* and chapter *chapter_id*
#
#   returns a array of problem paths? (global problem_id's)?
#
#  should pass in an limit on number of problems to return (100 for default?)
#
####


get '/Library/subjects/:subject/chapters/:chapter/problems' => sub {

	return get_chapter_problems(params->{subject},params->{chapter});
};

####
#
#  get all problems with subject *subject_id* and chapter *chapter_id* and section *section_id*
#
#   returns a array of problem paths? (global problem_id's)?
#
#  should pass in an limit on number of problems to return (100 for default?)
#
####


get '/Library/subjects/:subject/chapters/:chapter/sections/:section/problems' => sub {

	return get_section_problems(params->{subject},params->{chapter},params->{section});
};

#######
#
#  get '/library/directories'
#
#  return the directory tree of the library
#
####

get '/Library/directories' => sub {

	my $webwork_dir = config->{webwork_dir};
	my $file = "$webwork_dir/htdocs/DATA/library-directory-tree.json";

	my $json_text = do {
   		open(my $json_fh, "<:encoding(UTF-8)", $file)  or send_error("The file $file does not exist.",404);
	    local $/;
	    <$json_fh>
	};

	

	return $json_text;

}; 

#######
#
#  get '/library/directories'
#
#  return all the problems for a given directory in the library.
#
####

get '/Library/directories/**' => sub {

	## pstaab: trying to figure out the best way to pass the course_id.  It needs to be passed in as a parameter for this
	##         to work.

	setCourseEnvironment(params->{course_id});
	my ($dirs) = splat;
	my @dirs = @{$dirs};
	splice(@dirs,1,1); # strip the "OpenProblemLibrary" from the path

	my $path = vars->{ce}->{courseDirs}{templates} ."/". join("/",@dirs);
	my @files = File::Find::Rule->file()->name('*.pg')->in($path);

	my @allFiles =  map { {source_file=>$_} }@files;
	return \@allFiles;
};


#######
#
#  get '/library/local'
#
#  return all the problems in the course/templates directory
#
####

get '/courses/:course_id/Library/local' => sub {

	debug "in /Library/local";

	## still need to search for directory with single files and others with ignoreDirectives.

	setCourseEnvironment(params->{course_id});
	my $path = dir(vars->{ce}->{courseDirs}{templates});
	my $probLibs = vars->{ce}->{courseFiles}{problibs};

	my $libPath = $path . "/" . "Library";  # hack to get this to work.  Need to make this more robust.
	#my $parentPath =  $path->parent;

	my @files = ();

	$path->recurse( preorder=>1,callback=>sub {
		my ($dir) = @_;
		if ($dir =~ /^$libPath/){
			return Path::Class::Entity::PRUNE(); # don't follow into the Library directory
		} else {
			my $relDir = $dir;
			$relDir =~ s/^$path\/(.*)/$1/;
			if(($dir =~ /.*\.pg$/) && not($dir =~ /Header/)){  ## ignore any file with Header in it. 
				push(@files,$relDir);	
			}
		}
	});
	my @allFiles =  map { {source_file=>$_} }@files;
	return \@allFiles;

};


#######
#
#  get '/courses/:course_id/library/setDefinition'
#
#  return all the problems in any setDefinition file in the local library.
#
####

get '/courses/:course_id/Library/setDefinition' => sub {

	debug "in /Library/setDefinition";

	## still need to search for directory with single files and others with ignoreDirectives.

	setCourseEnvironment(params->{course_id});
	my $path = dir(vars->{ce}->{courseDirs}{templates});
	my $probLibs = vars->{ce}->{courseFiles}{problibs};

	my $libPath = $path . "/" . "Library";  # hack to get this to work.  Need to make this more robust.
	#my $parentPath =  $path->parent;

	my @setDefnFiles = ();

	$path->recurse( preorder=>1,callback=>sub {
		my ($dir) = @_;
		if ($dir =~ /^$libPath/){
			return Path::Class::Entity::PRUNE(); # don't follow into the Library directory
		} else {
			my $relDir = $dir;
			$relDir =~ s/^$path\/(.*)/$1/;
			if($dir =~ m|/set[^/]*\.def$|) {  
				push(@setDefnFiles,$relDir);	
			}
		}
	});

	## read the set definition files for pg files

	my @pg_files = ();

	for my $filePath (@setDefnFiles){
		my ($line, $got_to_pgs, $name, @rest) = ("", 0, "");
		debug "$path/$filePath";
		if ( open (SETFILENAME, "$path/$filePath") )    {
			while($line = <SETFILENAME>) {
				chomp($line);
				$line =~ s|(#.*)||; # don't read past comments
				if($got_to_pgs) {
					unless ($line =~ /\S/) {next;} # skip blank lines
					($name,@rest) = split (/\s*,\s*/,$line);
					$name =~ s/\s*//g;
					push @pg_files, $name;
				} else {
					$got_to_pgs = 1 if ($line =~ /problemList\s*=/);
				}
			}
		} else {
			debug("oops");
		}
	}

	my @allFiles =  map { {source_file=>$_} } @pg_files;
	return \@allFiles;

};


####
#
#   get '/Library/textbooks'
#
#   returns a JSON file that contains all of the textbook information
#
####

get '/Library/textbooks' => sub {

	my $webwork_dir = config->{webwork_dir};
	my $file = "$webwork_dir/htdocs/DATA/textbook-tree.json";
	my $json_text = do {
   		open(my $json_fh, "<:encoding(UTF-8)", $file)  or send_error("The file $file does not exist.",404);
	    local $/;
	    <$json_fh>
	};

	return $json_text;

};

####
#
#  get '/Library/textbooks/:textbook_id/chapters/:chapter_id/sections/:section_id'
#
#  returns all problems in the given textbook/chapter/section
#
##

get '/Library/textbooks/:textbook_id/chapters/:chapter_id/sections/:section_id/problems' => sub {

	return searchLibrary({section_id=>params->{section_id},textbook_id=>params->{textbook_id},chapter_id=>params->{chapter_id}});

};



####
#
##  get '/library/problems'
#
#  search the library.  Any of the problem metadata can be called as a parameter to this
#
#  return an array of problems that fit the criteria
#  
# ###

get '/library/problems' => sub {

	my $searchParams = {};
	for my $key (qw/keyword level author institution subject chapter section section_id textbook_id chapter_id/){
		$searchParams->{$key} = params->{$key} if defined(params->{$key});
	}

	return searchLibrary($searchParams);

};

###
#
#  get '/Library/problems/:problem_id/tags'
#
#  This returns all of the tags from the DB for a problem
#
## 

get '/Library/problems/:problem_id/tags' => sub {

	return getProblemTags(params->{problem_id});
};

###
#
# Problem render.  Given information about the problem (problem_id, set_id, course_id, or path) return the
# HTML for the problem. 
#
#  The displayMode parameter will determine the exact HTML code that is returned (images, MathJax, plain, PDF) 
#
#  The intention of this route is for rendering a particular problem (i.e. for the library browser)
#
###

get '/renderer/problems/:problem_id' => sub {

	##  need to change this later.  Why do we need a course_id for a general renderer? 
	setCourseEnvironment("_fake_course");
	
    my $displayMode = param('displayMode') || vars->{ce}->{pg}{options}{displayMode};
	my $problemSeed = defined(params->{problemSeed}) ? params->{problemSeed} : 1; 
	my $showHints = 0;
	my $showSolutions = 0;
	my $showAnswers = 0;


	# remove any pretty garbage around the problem
	local vars->{ce}->{pg}{specialPGEnvironmentVars}{problemPreamble} = {TeX=>'',HTML=>''};
	local vars->{ce}->{pg}{specialPGEnvironmentVars}{problemPostamble} = {TeX=>'',HTML=>''};

	my $user = fake_user(vars->{db});
	my $set =  fake_set(vars->{db});
	my $problem = fake_problem(vars->{db});
	$problem->{problem_seed} = params->{problem_seed} || 0;
	$problem->{problem_id} = params->{problem_id} || 1;

	# check to see if the problem_path is defined

	if (defined(params->{problem_path})){
		$problem->{source_file} = "Library/" . params->{problem_path};
	} elsif (defined(params->{source_file})){
		$problem->{source_file} = params->{source_file};
	} else {  # try to look up the problem_id in the global database;

		my $problem_info = database->quick_select('OPL_pgfile', {pgfile_id => param('problem_id')});
		my $path_id = $problem_info->{path_id};
		my $path_header = database->quick_select('OPL_path',{path_id=>$path_id})->{path};
		$problem->{source_file} = "Library/" . $path_header . "/" . $problem_info->{filename};
	}


	# get all parameters in the form AnSwErXXXX 

	my @anskeys = grep /AnSwEr\d{4}/, request->params;

	my $formFields = {};
	for my $key (@anskeys){
		$formFields->{$key} = params->{$key};
	}

	# for my $key (keys(%{$formFields})){
	# 	my $value = '####UNDEF###';
	# 	$value = $formFields->{$key} if(defined($formFields->{$key}));
	#  	debug($key . " : " . $value);
	# }


	my $translationOptions = {
		displayMode     => $displayMode,
		showHints       => $showHints,
		showSolutions   => $showSolutions,
		refreshMath2img => defined(param("refreshMath2img")) ? param("refreshMath2img") : 0 ,
		processAnswers  => defined(param("processAnswers")) ? param("processAnswers") : 1
	};


	my $pg = new WeBWorK::PG(
		vars->{ce},
		$user,
		params->{session_key},
		$set,
		$problem,
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

    for my $key (@anskeys){
    	for my $field (qw(correct_ans score student_ans)) {
    		if ($field ne 'correct_ans' || $showAnswers){
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

	# this was used to get the problem rendering in a ifram
	#

	#template 'library_problem', $problem_hash, { layout => 0 };

		 # for my $key (keys(%{$out2})){
		 #  	my $value = '####UNDEF###';
		 #  	$value = $out2->{$key} if (defined($out2->{$key}));
		 #  	debug("$key  : $value");
		 #  }
};

###
#
# Problem render.  Given information about the problem (problem_id, set_id, course_id, or path) return the
# HTML for the problem. 
#
#  The displayMode parameter will determine the exact HTML code that is returned (images, MathJax, plain, PDF) 
#
###

get '/renderer/courses/:course_id/sets/:set_id/problems/:problem_id' => sub {

    my $displayMode = param('displayMode') || vars->{ce}->{pg}{options}{displayMode};
    my ($showHints, $showSolutions,$showAnswers);
	

    ### The user is not a professor

    if(session->{permission} < 10){  ### check that the user belongs to the course and set. 

    	if (! (vars->{db}->existsUser(param('user_id')) &&  vars->{db}->existsUserSet(param('user_id'), params->{set_id})))  { 
    		send_error("You are a student and must be assigned to the set " . params->{set_id},404);
    	}

    	# these should vary depending on number of attempts or due_date or ???
    	$showHints = 0;
    	$showSolutions = 0;
    	$showAnswers = 0; 

    } else {
		$showHints = defined(param('show_hints'))? param('show_hints') : 0;
		$showSolutions = defined(param('show_solutions'))? param('show_solutions') : 0;
		$showAnswers = defined(param('show_answers'))? param('show_answers') : 0;
    }

	# remove any pretty garbage around the problem
	local vars->{ce}->{pg}{specialPGEnvironmentVars}{problemPreamble} = {TeX=>'',HTML=>''};
	local vars->{ce}->{pg}{specialPGEnvironmentVars}{problemPostamble} = {TeX=>'',HTML=>''};

	if (!vars->{db}->existsGlobalSet(params->{set_id})){
		send_error("The set " . params->{set_id} . " does not exist.",404);
	}
	if (!vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id})){
		send_error("The problem with id " . params->{problem_id} . " does not exist in set " . params->{set_id},404);
	}

	my $globalProblem =  vars->{db}->getGlobalProblem(params->{set_id},params->{problem_id});

	# the problem fed to PG needs to be a UserProblem.  Pass all the parameters of the global problem to the user problem. 

	my $problem = WeBWorK::DB::Record::UserProblem->new;

	for my $key (keys(%{$globalProblem})){
		$problem->{$key}=$globalProblem->{$key} if (defined($globalProblem->{$key}));
	}

	my $user = fake_user(vars->{db});

	$problem->{problem_seed}= defined(params->{problem_seed})? params->{problem_seed} : 1;

	debug $problem;

	my $set = vars->{db}->getGlobalSet(params->{set_id});		

	# get all parameters in the form AnSwErXXXX 

	my @anskeys = grep /AnSwEr\d{4}/, request->params;

	my $formFields = {};
	for my $key (@anskeys){
		$formFields->{$key} = params->{$key};
	}

	for my $key (keys(%{$problem})){
		my $value = '####UNDEF###';
		$value = $problem->{$key} if(defined($problem->{$key}));
	 	debug(" $key :  $value");
	}


	my $translationOptions = {
		displayMode     => $displayMode,
		showHints       => $showHints,
		showSolutions   => $showSolutions,
		refreshMath2img => defined(param("refreshMath2img")) ? param("refreshMath2img") : 0 ,
		processAnswers  => defined(param("processAnswers")) ? param("processAnswers") : 1
	};


	my $pg = new WeBWorK::PG(
		vars->{ce},
		$user,
		params->{session_key},
		$set,
		$problem,
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

    for my $key (@anskeys){
    	for my $field (qw(correct_ans score student_ans)) {
    		if ($field ne 'correct_ans' || $showAnswers){
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

	# this was used to get the problem rendering in a ifram
	#
	# template 'library_problem', $problem_hash, { layout => 0 }; 

		 # for my $key (keys(%{$out2})){
		 #  	my $value = '####UNDEF###';
		 #  	$value = $out2->{$key} if (defined($out2->{$key}));
		 #  	debug("$key  : $value");
		 #  }
};

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



1;


