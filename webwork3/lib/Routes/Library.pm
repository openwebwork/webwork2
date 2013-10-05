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
use Digest::MD5 qw(md5_hex);
use Utils qw/convertObjectToHash convertArrayOfObjectsToHash/;
use WeBWorK::DB::Utils qw(global2user);
use WeBWorK::Utils::Tasks qw(fake_user fake_set fake_problem);
use WeBWorK::PG::Local;

# use constant MY_PROBLEMS => '  My Problems  ';
# use constant MAIN_PROBLEMS => '  Unclassified Problems  ';
# use constant fakeSetName => "Undefined_Set";
# use constant fakeUserName => "Undefined_User";


get '/Library/subjects' => sub {

	my $webwork_htdocs = vars->{ce}->{webwork_dir}."/htdocs";
	my $file = "$webwork_htdocs/library-subject-tree.json";

	my $json_text = do {
   		open(my $json_fh, "<:encoding(UTF-8)", $file)  or return {error=>"The file $file does not exist."};
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


get '/Library/subjects/:subject_id/problems' => sub {
	my $subject = database->quick_select('OPL_DBsubject', {name => param('subject_id')});

	if(!defined($subject)){
		send_error("The subject name " . params->{subject_id} . " is not in the database.");
	}

	my @chapters = database->quick_select('OPL_DBchapter',{DBsubject_id => $subject->{DBsubject_id}});

	my $chapter_id =  join " , " ,  (map {$_->{DBchapter_id}} @chapters); 

	my $sth = database->prepare("select * from OPL_DBsection where DBchapter_id in (" . $chapter_id . ");");
	$sth->execute;
	my $sections = $sth->fetchall_arrayref({DBsection_id=>1}); 

	my $section_id = join " , " , map { $_->{DBsection_id} } @$sections;  # array of sections_id with the given subject_id;

	$sth = database->prepare("select pgfile_id from OPL_pgfile where DBsection_id in (" . $section_id . ")");
	$sth->execute;
	my $files = $sth->fetchall_arrayref({});

	my @allfiles = map { {path_id=>$_->{path_id}, filename=>$_->{filename}} } @$files;

	return getFilePaths(\@allfiles);  # return an array of filepaths.  
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


get '/Library/subjects/:subject_id/chapters/:chapter_id/problems' => sub {
	my $subject = database->quick_select('OPL_DBsubject', {name => params->{subject_id}});

	if(!defined($subject)){
		send_error("The subject name " . params->{subject_id} . " is not in the OPL database.");
	}


	my $chapter = database->quick_select('OPL_DBchapter',{name => params->{chapter_id}});

	if(!defined($chapter)){
		send_error("The chapter name " . params->{chapter_id} . " is not in the OPL database");
	}

	if($chapter->{DBsubject_id} ne $subject->{DBsubject_id}){
		send_error("The chapter with name " . params->{chapter_id} . " is not a subset of the subject with name " 
						. params->{subject_id} . " in the OPL database.");
	}

	my @sections = database->quick_select('OPL_DBsection',{DBchapter_id=>$chapter->{DBchapter_id}});

	my $section_id = join " , " , map { $_->{DBsection_id} } @sections;  # array of sections_id with the given subject_id;

	my $sth = database->prepare("select path_id, filename from OPL_pgfile where DBsection_id in (" . $section_id . ")");
	$sth->execute;
	my $files = $sth->fetchall_arrayref({});

	my @allfiles = map { {path_id=>$_->{path_id}, filename=>$_->{filename}} } @$files;

	return getFilePaths(\@allfiles);
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


get '/Library/subjects/:subject_id/chapters/:chapter_id/sections/:section_id/problems' => sub {

	return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

	my $subject = database->quick_select('OPL_DBsubject', {name => params->{subject_id}});

	if(!defined($subject)){
		send_error("The subject name " . params->{subject_id} . " is not in the OPL database.");
	}


	my $chapter = database->quick_select('OPL_DBchapter',{name => params->{chapter_id}});

	if(!defined($chapter)){
		send_error("The chapter name " . params->{chapter_id} . " is not in the OPL database");
	}

	if($chapter->{DBsubject_id} ne $subject->{DBsubject_id}){
		send_error("The chapter with name " . params->{chapter_id} . " is not a subset of the subject with name " 
						. params->{subject_id} . " in the OPL database.");
	} 

	my $section = database->quick_select('OPL_DBsection',{name=> params->{section_id}});

	if(!defined($section)){
		send_error("The section name " . params->{section_id} . " is not in the OPL database");
	}	

	if($section->{DBchapter_id} ne $chapter->{DBchapter_id}){
		send_error("The section with name " . params->{section_id} . " is not a subset of the chapter with name " 
						. params->{chapter_id} . " in the OPL database.");
	} 


	my @files = database->quick_select('OPL_pgfile',{DBsection_id=>$section->{DBsection_id}});
	
	my @allfiles = map { {path_id=>$_->{path_id}, filename=>$_->{filename}} } @files;

	return getFilePaths(\@allfiles);
};

#######
#
#  get '/library/directories'
#
#  return the directory tree of the library
#
####

get '/Library/directories' => sub {

	my $webwork_htdocs = vars->{ce}->{webwork_dir}."/htdocs";
	my $file = "$webwork_htdocs/library-directory-tree.json";

	my $json_text = do {
   		open(my $json_fh, "<:encoding(UTF-8)", $file)  or return {error=>"The file $file does not exist."};
	    local $/;
	    <$json_fh>
	};

	

	return $json_text;

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

	## first check if the keyword is set.

	my $keywordID = database->quick_select('OPL_keyword', {keyword => params->{keyword}});
	my @problemIDs = database->quick_select('OPL_pgfile_keyword',{keyword_id => $keywordID->{keyword_id}});

	my @problems = ();
	for my $probID (@problemIDs){
		my $problem_info = database->quick_select('OPL_pgfile',{pgfile_id => $probID->{pgfile_id}});
		my $path_id = $problem_info->{path_id};
		my $path_header = database->quick_select('OPL_path',{path_id=>$path_id})->{path};
		push(@problems, {source_file => "Library/" . $path_header . "/" . $problem_info->{filename}});

	}
	return \@problems;

};

###
#
# Problem render.  Given information about the problem (problem_id, set_id, course_id, or path) return the
# HTML for the problem. 
#
#  The displayMode parameter will determine the exact HTML code that is returned (images, MathJax, plain, PDF) 
#
###

get '/renderer/problems/:problem_id' => sub {

	return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10 && session->{user} ne session->{user_id}) {
        return {error=>"You don't have the necessary permission"};
    }

    my $displayMode = param('displayMode') || vars->{ce}->{pg}{options}{displayMode};
	my $user =  vars->{db}->getUser(session->{user});
    my ($set, $showHints, $showSolutions,$showAnswers,$problem);
	
	my $problemSeed = defined(params->{problemSeed}) ? params->{problemSeed} : 1; 

    ### The user is not a professor

    if(0+(session 'permission') < 10) {  ### check that the user belongs to the course and set. 

    	if (! (vars->{db}->existsUser(session->{user_id}) &&  vars->{db}->existsUserSet(session->{user_id}, params->{set_id})))  { 
    		return {error=>"You are a student and must be assigned to the set " . params->{set_id}};
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

	# determine where the problem is coming from
	# the problem comes from a set

	if (defined(params->{set_id})) {  
		if (!vars->{db}->existsUserSet($user->{user_id},params->{set_id})){
			return {error=>"The user " . $user->{user_id} . " has not been assigned to set " . params->{set_id}};
		}
		if (!vars->{db}->existsUserProblem($user->{user_id},params->{set_id},params->{problem_id})){
			return {error=>"The problem with id " . params->{problem_id} . " does not exist in set " . params->{set_id} . " for user " . $user->{user_id}};
		}

		$problem =  vars->{db}->getMergedProblem($user->{user_id},params->{set_id},params->{problem_id});

		$set = vars->{db}->getUserSet($user->{user_id},params->{set_id});		

	}  else {
    	$set =  fake_set(vars->{db});
		$problem = fake_problem(vars->{db});
		$problem->{problem_seed} = params->{problem_seed} || 0;
		$problem->{problem_id} = params->{problem_id} || 1;
		$problem->{value} = 1; 

		debug $problem;

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
	}


	# debug $problem->{source_file};
	# debug md5_hex($problem->{source_file});

	# for my $key (keys(%{$problem})){
	# 	my $value = '####UNDEF###';
	# 	$value = $problem->{$key} if(defined($problem->{$key}));
	#  	debug($key . " : " . $value);
	# }

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

    return {
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

	return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
        return {error=>"You don't have the necessary permission"};
    }

    my $displayMode = param('displayMode') || vars->{ce}->{pg}{options}{displayMode};
    my ($showHints, $showSolutions,$showAnswers);
	

    ### The user is not a professor

    if(0+(session 'permission') < 10) {  ### check that the user belongs to the course and set. 

    	if (! (vars->{db}->existsUser(param('user_id')) &&  vars->{db}->existsUserSet(param('user_id'), params->{set_id})))  { 
    		return {error=>"You are a student and must be assigned to the set " . params->{set_id}};
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
		return {error=>"The set " . params->{set_id} . " does not exist."};
	}
	if (!vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id})){
		return {error=>"The problem with id " . params->{problem_id} . " does not exist in set " . params->{set_id}};
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

    return {
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

