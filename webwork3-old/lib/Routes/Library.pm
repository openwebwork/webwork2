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
use Routes qw/convertObjectToHash convertArrayOfObjectsToHash/;
use WeBWorK::DB::Utils qw(global2user);
use WeBWorK::Utils::Tasks qw(fake_user fake_set fake_problem);

use constant MY_PROBLEMS => '  My Problems  ';
use constant MAIN_PROBLEMS => '  Unclassified Problems  ';
use constant fakeSetName => "Undefined_Set";
use constant fakeUserName => "Undefined_User";



get '/library/subjects' => sub {

	my $webwork_htdocs = vars->{ce}->{webwork_dir}."/htdocs";
	my $file = "$webwork_htdocs/library-subject-tree.json";

	my $json_text = do {
   		open(my $json_fh, "<:encoding(UTF-8)", $file)  or return {error=>"The file $file does not exist."};
	    local $/;
	    <$json_fh>
	};

	return $json_text;

};

get '/library/directories' => sub {

	my $webwork_htdocs = vars->{ce}->{webwork_dir}."/htdocs";
	my $file = "$webwork_htdocs/library-directory-tree.json";

	my $json_text = do {
   		open(my $json_fh, "<:encoding(UTF-8)", $file)  or return {error=>"The file $file does not exist."};
	    local $/;
	    <$json_fh>
	};

	

	return $json_text;

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

	# if( ! session 'logged_in'){
 #        return { error=>"You need to login in again."};
 #    }

    if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
        return {error=>"You don't have the necessary permission"};
    }

    my $displayMode = param('displayMode') || vars->{ce}->{pg}{options}{displayMode};
	my $user =  vars->{db}->getUser(param('user'));
    my ($set, $showHints, $showSolutions,$showAnswers,$problem);
	

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

	# determine where the problem is coming from
	# the problem comes from a set

	if (defined(params->{set_id})) {  
		if (!vars->{db}->existsUserSet(params->{user_id},params->{set_id})){
			return {error=>"The user " . params->{user_id} . " has not been assigned to set " . params->{set_id}};
		}
		if (!vars->{db}->existsUserProblem(params->{user_id},params->{set_id},params->{problem_id})){
			return {error=>"The problem with id " . params->{problem_id} . " does not exist in set " . params->{set_id} . " for user " . params->{user_id}};
		}

		$problem =  vars->{db}->getMergedProblem(params->{user_id},params->{set_id},params->{problem_id});

		$set = vars->{db}->getUserSet(params->{user_id},params->{set_id});		

	}  else {
    	$set =  fake_set(vars->{db});
		$problem = fake_problem(vars->{db});
		$problem->{problem_seed} = params->{problem_seed} || 0;
		$problem->{problem_id} = params->{problem_id} || 1;
		$problem->{value} = 1; 

		# check to see if the problem_path is defined

		if (defined(params->{problem_path})){
			$problem->{source_file} = "Library/" . params->{problem_path};
		} else {  # try to look up the problem_id in the global database;

			my $problem_info = database->quick_select('OPL_pgfile', {pgfile_id => param('problem_id')});
			my $path_id = $problem_info->{path_id};
			my $path_header = database->quick_select('OPL_path',{path_id=>$path_id})->{path};
			$problem->{source_file} = "Library/" . $path_header . "/" . $problem_info->{filename};
		}
	}

	debug $problem->{source_file};
	debug md5_hex($problem->{source_file});

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




1;

