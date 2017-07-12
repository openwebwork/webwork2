### ProblemSet routes
##
#  These are the routes for related problem set functions in the RESTful webservice
#
##

package Routes::ProblemSets;

use Dancer2 appname => "Routes::Login";

use Dancer2::Plugin::Auth::Extensible;
use Dancer2::FileUtils qw/read_file_content dirname/;
use File::Slurp qw/write_file/;
use WeBWorK::Utils::Tasks qw(fake_set fake_problem);
use Utils::LibraryUtils qw/render/;
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash convertBooleans/;
use Utils::ProblemSets qw/reorderProblems addGlobalProblems addUserSet addUserProblems deleteProblems createNewUserProblem
                            updateProblems getGlobalSet putGlobalSet putUserSet getUserSet
                            putUserProblem
                            @time_props @set_props @boolean_set_props @user_set_props @problem_props/;
use WeBWorK::Utils qw/parseDateTime decodeAnswers/;
use Array::Utils qw/array_minus/;
use List::MoreUtils qw/first_value first_index/;

use Utils::CourseUtils qw/getCourseSettings/;
use List::Util qw/first max/;

use Data::Dump qw/dump/;



###
#  return all problem sets (as objects) for course *course_id*
#
#  User user must have at least permissions>=10
#
##

get '/courses/:course_id/sets' => sub {

    # checkPermissions(session,10);
    my @globalSetNames = vars->{db}->listGlobalSets;
    my @allGlobalSets = map { getGlobalSet(vars->{db},vars->{ce},$_)} @globalSetNames;

    return convertArrayOfObjectsToHash(\@allGlobalSets,\@boolean_set_props);
};


######### CRUD for /courses/:course_id/sets/:set_id

####
#
#  return all problem set *set_id* for course *course_id*


get '/courses/:course_id/sets/:set_id' => sub {

    # checkPermissions(10,session->{user});

    my $globalSet = getGlobalSet(vars->{db},vars->{ce},route_parameters->{set_id});

    return convertObjectToHash($globalSet,\@boolean_set_props);
};

####
#  create a new problem set or update an existing problem set *set_id* for course *course_id*
#
#  any property can be set by assigning that property a value
#
#  returns the new problem set
#
#  permission > Student
##



any ['post', 'put'] => '/courses/:course_id/sets/:set_id' => sub {

  debug 'in put or post /courses/:course_id/sets/:set_id';

  my $set_id = route_parameters->{set_id};
  # set all of the new parameters sent from the client
  my $all_params = body_parameters->mixed;
  if (defined($all_params->{problems})) {
    $all_params->{problems} = [$all_params->{problems}] unless ref($all_params->{problems}) eq "ARRAY";
  } else {
    $all_params->{problems} = []
  }
  if (defined($all_params->{assigned_users})) {
    $all_params->{assigned_users} = [$all_params->{assigned_users}] unless ref($all_params->{assigned_users}) eq "ARRAY";
  } else {
    $all_params->{assigned_users} = []
  }

  my $problems_from_client = $all_params->{problems};

  # debug dump $problems_from_client;

  # for my $p (@$problems_from_client){
  #   debug $p->{problem_id} . ":" . $p->{source_file};
  # }

  if(request->is_post()){  ## the set is new
    send_error("The set name must only contain A-Za-z0-9_-.",403)
      unless ($set_id =~ /^[\w\_.-]+$/);

    send_error("The set name: $set_id already exists.",404)
      if (vars->{db}->existsGlobalSet($set_id));

    my $set = vars->{db}->newGlobalSet();
    $set->{set_id} = $set_id;
    vars->{db}->addGlobalSet($set);
  } else {
    send_error("The set name: $set_id does not exist.",404)
    unless vars->{db}->existsGlobalSet(params->{set_id});
  }

  putGlobalSet(vars->{db},vars->{ce},$all_params);

  #  Take care of the assigned users

  my @userNamesFromDB = vars->{db}->listSetUsers($set_id);
  my @usersToAdd = array_minus(@{$all_params->{assigned_users}},@userNamesFromDB);
  my @usersToDelete = array_minus(@userNamesFromDB,@{$all_params->{assigned_users}});

  for my $user(@usersToAdd){
    addUserSet(vars->{db},$user,$set_id);
  }
  for my $user (@usersToDelete){
    vars->{db}->deleteUserSet($user,$set_id);
  }

  # handle the global and user problems.

  my @problemsFromDB = vars->{db}->getAllGlobalProblems($set_id);

  if($all_params->{_reorder}){  # reorder the problems
    debug "the problems are being reordered";
    reorderProblems(vars->{db},$set_id,$all_params->{problems},$all_params->{assigned_users});
  } elsif (scalar(@problemsFromDB) < scalar(@{$all_params->{problems}})) { # problems have been added
    addGlobalProblems(vars->{db},$set_id,$all_params->{problems});
    addUserProblems(vars->{db},$set_id,$all_params->{problems},$all_params->{assigned_users});
  } else { # problem may have been updated
    updateProblems(vars->{db},$set_id,$all_params->{problems});
  }

  my $returnSet = getGlobalSet(vars->{db},vars->{ce},$set_id);
  $returnSet->{_delete_problem_id} = $all_params->{_delete_problem_id}
    if defined ($all_params->{_delete_problem_id});  # this help the synching using Backbone.js

  for my $prob1 (@{$returnSet->{problems}}){
    ## return the rendered data that was sent from the client.
    my $prob2 = first_value { $prob1->{source_file} eq $_->{source_file}} @$problems_from_client;
    $prob1->{data} = $prob2->{data} if defined($prob2->{data});
    $prob1->{problem_seed} = $prob2->{problem_seed} if defined($prob2->{problem_seed});
  }

  # debug dump $returnSet;

  ## proctored gateway quiz password

  $returnSet->{pg_password} = $all_params->{pg_password} if defined($all_params->{pg_password});

  return convertObjectToHash($returnSet,\@boolean_set_props);

};

####
#
# Delete the problem :problem_id in set :set_id in course :course_id
#
###

del '/courses/:course_id/sets/:set_id/problems/:problem_id' => require_role professor => sub {
  my $set_id = route_parameters->{set_id};
  my $problem_id = route_parameters->{problem_id};
  send_error("The set: $set_id does not exist.",404) unless (vars->{db}->existsGlobalSet($set_id));

  send_error("The problem: $problem_id does not exist in set: $set_id", 404)
    unless vars->{db}->existsGlobalProblem($set_id,$problem_id);

  my $prob = vars->{db}->getGlobalProblem($set_id,$problem_id);
  vars->{db}->deleteGlobalProblem($set_id,$problem_id);
  return convertObjectToHash($prob); 
};


####
#  delete the problem set *set_id* for course *course_id*
#
#  returns the new problem set
#
#  permission > Student
##

del '/courses/:course_id/sets/:set_id' => require_role professor => sub {

    # checkPermissions(10,session->{user});

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        send_error("The set " . param('set_id'). " doesn't exist for course " . param("course_id"),404);
    }

    my $setToDelete = vars->{db}->getGlobalSet(param('set_id'));

    if(vars->{db}->deleteGlobalSet(param('set_id'))){
        return convertObjectToHash($setToDelete,\@boolean_set_props);
    } else {
        send_error("There was an error while trying to delete set " . param('set_id'),424);
    }

};





######## CRUD for /courses/:course_id/sets/:set_id/users

##
#
#  Get an array of user sets for all users in course :course_id for set :set_id
#
#  return:  array of properties.
##


get '/courses/:course_id/sets/:set_id/users' => require_role professor => sub {

    # checkPermissions(10,session->{user});

    my @userIDs = vars->{db}->listSetUsers(params->{set_id});

    my @sets = map { getUserSet(vars->{db},$_,params->{set_id});} @userIDs;

    return \@sets;
};




###
#
#  Assign users to problem set *set_id* in course *course_id*
#
#  permission > Student
#
#  The users are assigned by setting the assigned_users parameter to a comma delimited list of user_id's.
#
#####

post '/courses/:course_id/sets/:set_id/users' => require_role professor => sub {

    # checkPermissions(10,session->{user});
    send_error("The parameter: assigned_users has not been declared",404) unless param('assigned_users');

    my @usersAdded = ();

    for my $userID (split(",",param('assigned_users'))){

        # check to make sure that the user is assigned to the course
        send_error("The user " . $userID . " is not enrolled in the course " . param("course_id"),404)
            unless vars->{db}->getUser($userID);

        # check to see if the user has already been assigned and skip the addition if exists already.
        if (!vars->{db}->existsUserSet($userID,param('set_id'))) {
            my $userSet = vars->{db}->newUserSet;

            $userSet->{user_id}=$userID;
            $userSet->{set_id}=param('set_id');
            vars->{db}->addUserSet($userSet);
            push(@usersAdded,$userID);
        }

        ### Should we also check to see if there are other parameters to set as well?
        ##
        ## perhaps the better way to do this is to then call PUT
    }

    return \@usersAdded;
};


###
#
#  Remove users to problem set *set_id* in course *course_id*
#
#  The users are removed by setting the assigned_users parameter to a comma delimited list of user_id's.
#
#####

del '/courses/:course_id/sets/:set_id/users' => require_role professor => sub {

    send_error("The parameter: assigned_users has not been declared",404) unless param('assigned_users');

    my @usersDeleted = ();

    for my $userID (split(",",param('assigned_users'))){

        # check to make sure that the user is assigned to the course
        send_error("The user " . $userID . " is not enrolled in the course " . param("course_id"),404)
            unless vars->{db}->getUser($userID);

        # check to see if the user has already been assigned and skip the addition if exists already.
        if (vars->{db}->existsUserSet($userID,param('set_id'))) {
            vars->{db}->deleteUserSet($userID,param('set_id'));
            push(@usersDeleted,$userID);
        }
    }

    return \@usersDeleted;
};


###
#
#  Update properties of set *set_id* of course *course_id* for a subset of users  (updates the userSets)
#
#  permission > Student
#
#  The users are assigned by setting the users_assigned parameter an array ref of user_id's.
#
#####

put '/courses/:course_id/sets/:set_id/users' => require_role professor => sub {

    send_error("The parameter: assigned_users has not been declared",404) unless param('assigned_users');

    ## remember which users were assigned

    my @usersForTheSetBefore = vars->{db}->listSetUsers(params->{set_id});

    ## thenfor all users that were passed in, update or create a new userSet

    for my $userID (@{params->{assigned_users}}) {

        # check to make sure that the user is assigned to the course
        send_error("The user " . $userID . " is not enrolled in the course " . param("course_id"),404)
            unless vars->{db}->getUser($userID);

        if (vars->{db}->existsUserSet($userID,params->{set_id})) {
            my $set = vars->{db}->getUserSet($userID,params->{set_id});
            for my $key (@user_set_props) {
                $set->{$key} = params->{$key} if defined(params->{$key});
            }
            vars->{db}->putUserSet($set);
        } else {
            my $set = vars->{db}->newUserSet($userID,params->{set_id});
            $set->{user_id} = $userID;
            for my $key (@user_set_props) {
                $set->{$key} = params->{$key} if defined(params->{$key});
            }
            vars->{db}->addUserSet($set);
        }
    }

    ## then delete all users that were in the set originally, but aren't now.

    for my $userID (@usersForTheSetBefore){
        if (! grep(/^$userID$/,@{params->{assigned_users}})){
            vars->{db}->deleteUserSet($userID, params->{set_id});
        }
    }


    # return all passed in parameters and the current list of assigned users.

    my $out = {};
    for my $key (@set_props){
        if (param($key)){
            $out->{$key} = param($key);
        }
    }
    $out->{assigned_users} = param('assigned_users');

    return $out;

};

###
#
# We have two types of UserSets.  To clarify the next sets of CRUD calls, time to clarify
#
#  1. For a given problem set (set_id) a list of user specifiy properties.  Call this type "users"
#  2. For a given user (user_id) a list of problem sets associated with this.  Call this type "sets"
#
#  Below we have two sets of CRUD Calls


######## CRUD for /courses/:course_id/users/:user_id/sets/:set_id
#
#  This is of type "sets"
#
###


##
#
#  Get the (user) properties for *set_id* for user *user_id* in course *course_id*
#
#  return:  UserSet properties
##


get '/courses/:course_id/users/:user_id/sets/:set_id' => require_role professor => sub {

    my $userSet = convertObjectToHash(vars->{db}->getUserSet(param('user_id'),param('set_id')),\@boolean_set_props);
    $userSet->{_id} = params->{set_id}; # tells Backbone on the client that the data has been sent from the server.

    return $userSet;

};

##
#
#  Add (assign) user *user_id* to set *set_id* for course *course_id*
#
#  return:  UserSet properties
##


post '/courses/:course_id/users/:user_id/sets/:set_id' => require_role professor => sub {

    # check to make sure that the user is assigned to the course
    send_error("The user " . params->{user_id} . " is not enrolled in the course " . param("course_id"),404)
            unless vars->{db}->getUser(params->{user_id});

    # check to see if the userSet already exists.

    send_error("The set " . params->{set_id} . " already exists for " . params->{user_id} . ".  Perhaps you"
            . " meant to make a PUT call. ",403) if vars->{db}->existsUserSet(params->{user_id},params->{set_id});

    my $userSet = vars->{db}->newUserSet;

    $userSet->{user_id} = params->{user_id};
    $userSet->{set_id} = params->{set_id};
    vars->{db}->addUserSet($userSet);

    my $set = convertObjectToHash($userSet,\@boolean_set_props);
    $set->{_id} = params->{set_id};  # tells Backbone on the client that the data has been sent from the server.
    return $set;
};

##
#
#  Update user *user_id* to set *set_id* for course *course_id*
#
#  return:  UserSet properties
##


put '/courses/:course_id/users/:user_id/sets/:set_id' => require_role professor => sub {

    # check to make sure that the user is assigned to the course
    send_error("The user " . params->{user_id} . " is not enrolled in the course " . param("course_id"),404)
            unless vars->{db}->getUser(params->{user_id});

    # check to see if the user has already been assigned and skip the addition if exists already.

    my %allparams = request->params;
    return putUserSet(vars->{db},\%allparams);
};



##
#
#  Delete (unassign) user *user_id* to set *set_id* for course *course_id*
#
#  return:  the removed UserSet properties
##


del '/courses/:course_id/users/:user_id/sets/:set_id' => require_role professor => sub {

    # check to make sure that the user is assigned to the course
    send_error("The user " . params->{user_id} . " is not enrolled in the course " . param("course_id"),404)
            unless vars->{db}->getUser(params->{user_id});

    send_error("The set " . params->{set_id} . " does not exist for user " . params->{user_id}.
            " so the set cannot be deleted. ",403) unless vars->{db}->existsUserSet(params->{user_id},params->{set_id});

    my $userSet = vars->{db}->getUserSet(params->{user_id},param('set_id'));
    if ($userSet){
        vars->{db}->deleteUserSet(params->{user_id},param('set_id'));
    } else {
        send_error("An unknown error occurred removing user " . params->{user_id} . " from set "
                . params->{set_id}. " in course " . params->{course_id},466);
    }

    return convertObjectToHash($userSet,\@boolean_set_props);
};




####
#
#  Get/update problem problem_id in set set_id for user user_id for course course_id
#
####

get '/users/:user_id/courses/:course_id/sets/:set_id/problems/:problem_id' => require_role professor => sub {

  my $problem = vars->{db}->getUserProblem(param('user_id'),param('set_id'),param('problem_id'));
  return convertObjectToHash($problem);
};

put '/users/:user_id/courses/:course_id/sets/:set_id/problems/:problem_id' => require_role professor => sub {

	my $problem = vars->{db}->getUserProblem(param('user_id'),param('set_id'),param('problem_id'));

  for my $key (keys (%{$problem})){
  	if(param($key)){
		    $problem->{$key} = param($key);
  	}
  }

    vars->{db}->putUserProblem($problem);

    return convertObjectToHash($problem);
};



######## CRUD for /courses/:course_id/sets/:set_id/users/:user_id
#
#  This is of type "users".  See above for an explain of the UserSets.
#
#  Note: each of these passes to the above routes
###


##
#
#  Get the (user) properties for *set_id* for user *user_id* in course *course_id*
#
#  return:  UserSet properties
##

any '/courses/:course_id/sets/:set_id/users/:user_id' => sub {
    forward '/courses/' . route_parameters->{course_id} . '/users/' .
      route_parameters->{user_id} . '/sets/' . route_parameters->{set_id};
};




###
#  return all (user) sets for user *user_id* in course *course_id*
#
#  permission: > Student || if user_id == user;
#
##




get '/courses/:course_id/users/:user_id/sets' => require_role professor => sub {
    my @setIDs = vars->{db}->listUserSets(param('user_id'));
    my @userSets = map { getUserSet(vars->{db},vars->{ce},params->{user_id},$_) } @setIDs;

    return convertArrayOfObjectsToHash(\@userSets);
};

####
#
##   gets the problems (global) in set *set_id* for course *course_id*
#
#   returns [problems]
#
####

get '/courses/:course_id/sets/:set_id/problems' => require_role professor => sub {

    my @problems = vars->{db}->getAllGlobalProblems(params->{set_id});

    return convertArrayOfObjectsToHash(\@problems);

};


###
#
# put '/courses/:course_id/sets/:set_id/problems'
#
# reorder the problems in problem set *set_id* for course *course_id*
#
# returns an array of problem_id's in the new order.
#
# Note: the parameter problems must contain an array (in the desired order) of problems
#
#  permission > Student
#
###

put '/courses/:course_id/sets/:set_id/problems' => require_role professor => sub {

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        send_error("The set " . param('set_id'). " doesn't exist for course " . param("course_id"),404);
    }

    my @problems_from_db = vars->{db}->getAllGlobalProblems(params->{set_id});

    my @newProblems = reorderProblems(vars->{db},params->{set_id},params->{problems});

    return convertArrayOfObjectsToHash(\@newProblems);
};


###
#
#  get /courses/:course_id/sets/:set_id/users/all/problems
#
#  return all user sets with all problem information.
#
####

get '/courses/:course_id/sets/:set_id/users/all/problems' => require_role professor => sub {

    send_error("The set " . param('set_id'). " doesn't exist for course " . param("course_id"),404)
        unless vars->{db}->existsGlobalSet(params->{set_id});

    my @allUserIDs = vars->{db}->listSetUsers(params->{set_id});
    my @userSets = map {
        my $userSet = getUserSet(vars->{db},vars->{ce},$_,params->{set_id});
        my @problems = vars->{db}->getAllMergedUserProblems($_,params->{set_id});
        my @userProblems = ();
        for my $problem (@problems){
            my @lastAnswers = decodeAnswers($problem->{last_answer});
            $problem->{last_answer} = \@lastAnswers;
            my $prob = convertObjectToHash($problem);
            push(@userProblems,$prob);
        }
        $userSet->{problems} = \@userProblems;
    } @allUserIDs;

    return \@userSets;
};

###
#
#  get /courses/:course_id/sets/:set_id/users/all/problems
#
#  return all user sets with all problem information.
#
####

get '/courses/:course_id/users/:user_id/sets/all/problems' => require_role professor => sub {

    send_error("The user " . params->{user_id} . " isn't enrolled the the course " . param("course_id"),404)
        unless vars->{db}->existsUser(params->{user_id});

    my @userSetNames = vars->{db}->listUserSets(params->{user_id});
    my @userSets = ();
    for my $setID (@userSetNames){
         my $userSet = getUserSet(vars->{db},vars->{ce}, params->{user_id},$setID);
        my @problems = vars->{db}->getAllMergedUserProblems(params->{user_id},$setID);
        my @userProblems = ();
        for my $problem (@problems){
            my @lastAnswers = decodeAnswers($problem->{last_answer});
            $problem->{last_answer} = \@lastAnswers;
            my $prob = convertObjectToHash($problem);
            push(@userProblems,$prob);
        }
        $userSet->{problems} = \@userProblems;
        push(@userSets,$userSet);
    }

    return \@userSets;
};



###
#
#  get /courses/:course_id/sets/:set_id/users/:user_id/problems
#
#  return all user (merged) problems for course :course_id, user :user_id
#
####

get '/courses/:course_id/sets/:set_id/users/:user_id/problems' => sub {

    send_error("The set " . param('set_id'). " doesn't exist for course " . param("course_id"),404)
        if !vars->{db}->existsGlobalSet(params->{set_id});

    send_error("The user " . params->{user_id} . " isn't assigned to set ". param('set_id'). ".",404)
        if !vars->{db}->existsUserSet(params->{user_id},params->{set_id});

    my @problems = vars->{db}->getAllMergedUserProblems(params->{user_id},params->{set_id});

    for my $problem (@problems){
        my @lastAnswers = decodeAnswers($problem->{last_answer});
        $problem->{last_answer} = \@lastAnswers;
        $problem->{_id} = params->{set_id} . ":" . params->{user_id} . ":" . $problem->{problem_id};
    }

    return convertArrayOfObjectsToHash(\@problems);
};







####
#
##   CREATE, READ, UPDATE, DELETE a problem in set *set_id* for course *course_id*
#
#
####

###
#
#  get /courses/:course_id/sets/:set_id/problems/:problem_id
#
#  return a problem properties
#
####

get '/courses/:course_id/sets/:set_id/problems/:problem_id' => sub {

    # checkPermissions(10,session->{user});

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        send_error("The problem set with name: " . param('set_id'). " does not exist.",404);
    }

    if (!vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id})) {
        send_error("The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id},404);
    }

    my $problem = vars->{db}->getGlobalProblem(params->{set_id},params->{problem_id});
    return convertObjectToHash($problem);

};

###
#
#  PUT /courses/:course_id/sets/:set_id/problems/:problem_id
#
#  update the properties for problem *problem_id* in set *set_id* in course *course_id*
#
#  return the new problem properties
#
####

put '/courses/:course_id/sets/:set_id/problems/:problem_id' => require_role professor => sub {

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        send_error("The problem set with name: " . param('set_id'). " does not exist.",404);
    }

    if (!vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id})) {
        send_error("The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id},404);
    }

    my $problem = vars->{db}->getGlobalProblem(params->{set_id},params->{problem_id});

    for my $key (@problem_props) {
        if (param($key)){
            $problem->{$key} = param($key);
        }
    }

    vars->{db}->putGlobalProblem($problem);

    return convertObjectToHash($problem);
};

###
#
#  post /courses/:course_id/sets/:set_id/problems/:problem_id
#
#  add a problem with global problem_id to set *set_id* in course *course_id*.
#
#  Note: we probably need to have a flag that if the problem_id is 0 that the path is passed in as a parameter.
#
#  return the problem properties
#
####

post '/courses/:course_id/sets/:set_id/problems/:problem_id' => require_role professor => sub {

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        send_error("The problem set with name: " . param('set_id'). " does not exist.",404);
    }

    ## check if max_attempts or value was passed.  If not give them default values.

    my $maxAttempts = defined(params->{max_attempts}) ? params->{max_attempts} : -1;
    my $value = defined(params->{value}) ? params->{value} : 1;

    my $globalSet = vars->{db}->getGlobalSet(param('set_id'));

    my $problem = vars->{db}->newGlobalProblem;

    $problem->{source_file} = params->{source_file};
    $problem->{max_attempts} = $maxAttempts;
    $problem->{value} = $value;

    my @allProblems = vars->{db}->getAllGlobalProblems(params->{set_id});

    my @problem_ids = ();

    for my $prob (@allProblems){
        push(@problem_ids,$prob->{problem_id});
    }
    my $max = max(@problem_ids) || 0 ;

    $problem->{problem_id} = $max + 1;
    $problem->{set_id} = params->{set_id};

    vars->{db}->addGlobalProblem($problem);


    return convertObjectToHash($problem);

};

###
#
#  delete /courses/:course_id/sets/:set_id/problems/:problem_id
#
#  Delete the problem in course *course_id*, in set *set_id* and problem *problem_id*.
#
#  return the problem properties
#
####

del '/courses/:course_id/sets/:set_id/problems/:problem_id' => require_role professor => sub {

    send_error("The problem set with name: " . param('set_id'). " does not exist.",404)
        unless vars->{db}->existsGlobalSet(param('set_id'));

    send_error("The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id},404)
        unless !vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id});

    my $problem_to_delete = vars->{db}->getGlobalProblem(params->{set_id},params->{problem_id});

    my $result = vars->{db}->deleteGlobalProblem(params->{set_id},params->{problem_id});

    if ($result) {
        return convertObjectToHash($problem_to_delete);
    } else {
        send_error("There was an error deleting the problem.",446);
    }

};

###
#
# get '/courses/:course_id/status/usersets'
#
# This returns the status of each problem set in the course course_id.  If the userProblems match
# the global problems then a 1 is returned for the problem_status for each set or a 0 if not.
#
# This is mainly used for troubleshooting where there are inconsistencies in the problem set databases
#
###

get '/courses/:course_id/status/usersets' => require_role professor => sub {

    my @setNames = vars->{db}->listGlobalSets;

    my @sets = map { {set_id=>$_} } @setNames;

    for my $set (@sets){

        my @globalProblems = vars->{db}->getAllGlobalProblems($set->{set_id});
        my @problems = map { $_->{problem_id} } @globalProblems;
        #$set->{problems} = \@problems;

        my @setOkay = ();

        my @userNames = vars->{db}->listSetUsers($set->{set_id});
        my @userSets = map { {user_id=>$_}} @userNames;

        for my $userSet (@userSets){
            my @userProblems = vars->{db}->listUserProblems($userSet->{user_id},$set->{set_id});
            $userSet->{problems} = \@userProblems;
            push(@setOkay,(join("|",@userProblems) eq join("|",@problems))?1:0);
        }

        my @okays = grep { $_ == 0 } @setOkay;
        $set->{problem_status} = scalar(@setOkay)==0?0:1;
        $set->{problem_length} = scalar(@problems);

    }



    return \@sets;
};


###
#
# get '/courses/:course_id/fix/userstatus'
#
# This returns the status of the problem sets in the course course_id
#
# This is mainly used for troubleshooting where there are inconsistencies in the problem set databases
#
###

post '/courses/:course_id/fix/usersets' => require_role professor => sub {

    my $p = vars->{db}->getUserProblem("profa","HW5.2",6);

    my @setNames = vars->{db}->listGlobalSets;
    my @sets = map { {set_id=>$_} } @setNames;

    for my $set (@sets){
        my @globalProblems = vars->{db}->getAllGlobalProblems($set->{set_id});
        my @problems = map { $_->{problem_id} } @globalProblems;
        #$set->{problems} = \@problems;

        my @userNames = vars->{db}->listSetUsers($set->{set_id});
        my @userSets = map { {user_id=>$_}} @userNames;

        for my $userSet (@userSets){
            my @userProblems = vars->{db}->listUserProblems($userSet->{user_id},$set->{set_id});
            $userSet->{problems} = \@userProblems;
#            if(!(@userProblems ~~ @problems &&  @problems ~~ @userProblems)){
                for my $probID (@problems){
                    my $prob = vars->{db}->getUserProblem($userSet->{user_id},$set->{set_id},$probID);
                    if (! $prob){
                        vars->{db}->addUserProblem(createNewUserProblem($set->{set_id},$userSet->{user_id},$probID));
                        debug "Creating User problem for " . $userSet->{user_id} . " for set " . $set->{set_id}
                            . " and problem _id". $probID;
                    } else {
                        #debug "Checking problem " . $probID . " of set " . $set->{set_id} . " for user " . $userSet->{user_id} . ".";
                        $prob->{status}=0.0 unless $prob->{status};
                        $prob->{attempted}=0 unless $prob->{attempted};
                        $prob->{num_correct}=0 unless $prob->{num_correct};
                        $prob->{num_incorrect}=0 unless $prob->{num_incorrect};
                        $prob->{sub_status}=0.0 unless $prob->{sub_status};
                        $prob->{problem_seed} = int rand 5000 unless $prob->{problem_seed};
                        #debug defined($prob->{problem_seed});
                        vars->{db}->putUserProblem($prob);
                    }
                }
            #}
        }
    }



    return \@sets;
};

###
#
#  get '/courses/:course_id/users/:user_id/sets/:set_id/problems/:problem_id'
#
#  return the user problem for course course_id, set set_id and problem problem_id
#
###

get '/courses/:course_id/users/:user_id/sets/:set_id/problems/:problem_id' => require_role professor => sub {

    send_error("The problem set with name: " . params->{set_id} . " does not exist.",404)
        unless vars->{db}->existsGlobalSet(params->{set_id});

    send_error("The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id},404)
        unless vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id});

    send_error("The user " . params->{user_id} . " is not assigned to set " . params->{set_id})
        unless vars->{db}->existsUserSet(params->{user_id},params->{set_id});

    my $problem = convertObjectToHash(vars->{db}->getMergedProblem(params->{user_id},params->{set_id},params->{problem_id}));
    my @answers = decodeAnswers($problem->{last_answer});
    $problem->{last_answer} = \@answers;
    return $problem;


};

###
#
#  update the problem :problem_id for user :user_id for set :set_id in course :course_id
#
###

put '/courses/:course_id/users/:user_id/sets/:set_id/problems/:problem_id' => require_role professor => sub {

    send_error("The problem set with name: " . params->{set_id} . " does not exist.",404)
        unless vars->{db}->existsGlobalSet(params->{set_id});

    send_error("The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id},404)
        unless vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id});

    send_error("The user " . params->{user_id} . " is not assigned to set " . params->{set_id})
        unless vars->{db}->existsUserSet(params->{user_id},params->{set_id});

    my $problem = vars->{db}->getMergedProblem(params->{user_id},params->{set_id},params->{problem_id});
    for my $key (@problem_props){
        $problem->{$key} = params->{$key}
    }

    putUserProblem(vars->{db}, $problem);

    return convertObjectToHash(vars->{db}->getMergedProblem(params->{user_id},params->{set_id}
                                ,params->{problem_id}));
};

### redirect to the above put if the parameters are out of order:

put '/courses/:course_id/sets/:set_id/users/:user_id/problems/:problem_id' => sub {
    redirect '/courses/' . params->{course_id} . '/users/' . params->{user_id} .'/sets/' . params->{set_id} .
            '/problems/ ' . params->{problem_id};


};

###
#
#  get '/courses/:course_id/users/:user_id/sets/:set_id/problems/:problem_id/pastanswers'
#
#  return all past answers for the given problem
#
###

get '/courses/:course_id/users/:user_id/sets/:set_id/problems/:problem_id/pastanswers' => require_role professor => sub {

    send_error("The problem set with name: " . params->{set_id} . " does not exist.",404)
        unless vars->{db}->existsGlobalSet(params->{set_id});

    send_error("The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id},404)
        unless vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id});

    send_error("The user " . params->{user_id} . " is not assigned to set " . params->{set_id})
        unless vars->{db}->existsUserSet(params->{user_id},params->{set_id});

    my @pastAnswerIDs = vars->{db}->listProblemPastAnswers(params->{course_id},params->{user_id},
                                                        params->{set_id},params->{problem_id});
    my @pastAnswers = vars->{db}->getPastAnswers(\@pastAnswerIDs);

    return convertArrayOfObjectsToHash(\@pastAnswers);
};

###
#
#  get '/courses/:course_id/users/:user_id/sets/:set_id/problems/:problem_id/pastanswers/latest'
#
#  return all past answers for the given problem
#
###

get '/courses/:course_id/users/:user_id/sets/:set_id/problems/:problem_id/pastanswers/latest' => require_role professor => sub {

    send_error("The problem set with name: " . params->{set_id} . " does not exist.",404)
        unless vars->{db}->existsGlobalSet(params->{set_id});

    send_error("The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id},404)
        unless vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id});

    send_error("The user " . params->{user_id} . " is not assigned to set " . params->{set_id})
        unless vars->{db}->existsUserSet(params->{user_id},params->{set_id});

    return  convertObjectToHash(vars->{db}->latestProblemPastAnswer(params->{course_id},params->{user_id},
                                                        params->{set_id},params->{problem_id}));
};

###
#
# post /utils/dates
#
#  A utility route to convert WW date-times to unix epochs.
#
#  The only needed parameter is dates, an object of webwork date-times
#
###

post '/utils/dates' => sub {

    ##  need to change this later.  Why do we need a course_id for a general renderer?
    setCourseEnvironment("_fake_course");

    my $unixDates = {};
    for my $key (qw/open_date answer_date due_date/){
        $unixDates->{$key} = parseDateTime(params->{$key},params->{timeZone});
    }

    return $unixDates;
};


####
#
#  get /courses/:course_id/pgeditor
#
#  returns the html for the simple pg editor
#
###

get '/courses/:course_id/pgeditor' => sub {

    template 'simple-editor.tt', {course_id=> params->{course_id},theSetting => to_json(getCourseSettings),
        pagename=>"Simple Editor",user=>session->{user}};
};

####
#
#  get /courses/:course_id/headers
#
#  returns an array of possible header files for a given course.
#
####

get '/courses/:course_id/headers' => require_role professor => sub {

    my $templateDir = vars->{ce}->{courseDirs}->{templates};
    my $include = qr/header.*\.pg$/i;
    my $skipDIRS = join("|", keys %{ vars->{ce}->{courseFiles}->{problibs} });
    my $skip = qr/^(?:$skipDIRS|svn)$/;

    my $rule = File::Find::Rule->new;
    $rule->or($rule->new->directory->name($skip)->prune->discard,$rule->new);  #skip the directories that match $skip
    my @files = $rule->file()->name($include)->in($templateDir);

    # return the files relative to the templates/ directory.
    my @relativeFiles = map { my @dirs = split(params->{course_id}."/templates/",$_); $dirs[1];} @files;
    return \@relativeFiles;
};



####
#
#  get,put,post /courses/:course_id/sets/:set_id/setheader
#
#  gets, creates a new or updates the set header for the problem set :set_id
#
####

any ['get', 'put'] => '/courses/:course_id/sets/:set_id/setheader' => sub {
     #checkPermissions(10,session->{user});

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        send_error("The problem set with name: " . param('set_id'). " does not exist.",404);
    }

    my $globalSet = vars->{db}->getGlobalSet(param('set_id'));
    my $templateDir = vars->{ce}->{courseDirs}->{templates};

    my $setHeader = $globalSet->{set_header};
    my $setHeaderFile;
    if($setHeader eq 'defaultHeader' || ! defined($setHeader) || $setHeader eq ''){
        $setHeader = 'defaultHeader';
        $setHeaderFile = vars->{ce}->{webworkFiles}->{screenSnippets}->{setHeader};
    } else {
        $setHeaderFile = path(dirname($templateDir),'templates',$setHeader);
    }

    my $hardcopyHeader = $globalSet->{hardcopy_header};
    my $hardcopyHeaderFile;
    if(! defined($hardcopyHeader) || $hardcopyHeader eq ''){
        $hardcopyHeader = 'defaultHeader';
        $hardcopyHeaderFile = vars->{ce}->{webworkFiles}->{hardcopySnippets}->{setHeader};
    } else {
        $hardcopyHeaderFile = path(dirname($templateDir),'templates',$hardcopyHeader);
    }

    my $headerContent = params->{set_header_content};
    my $hardcopyHeaderContent = params->{hardcopy_header_content};

    if(request->is_put()){
        # first determine if the header files are global or local
        if($setHeader ne 'defaultHeader'){
            write_file($setHeaderFile,params->{set_header_content});
        }
        if($hardcopyHeader ne 'defaultHeader'){
            write_file($hardcopyHeaderFile,params->{hardcopy_header_content});
        }
    }

    $headerContent = read_file_content($setHeaderFile);
    $hardcopyHeaderContent = read_file_content($hardcopyHeaderFile);

    my $user_id = session 'logged_in_user';
    debug route_parameters->{set_id};
    my $mergedSet = vars->{db}->getMergedSet($user_id,route_parameters->{set_id});

    my $renderParams = {
        displayMode => param('displayMode') || vars->{ce}->{pg}{options}{displayMode},
        problemSeed => 1,
        showHints=> 0,
        showSolutions=>0,
        showAnswers=>0,
        user=>vars->{db}->getUser($user_id),
        set=>$mergedSet,
        problem=>fake_problem(vars->{db})
      };




	# check to see if the problem_path is defined
    $renderParams->{problem}->{source_file} = $setHeaderFile;

    debug dump $renderParams;

    my $ren = render(vars->{ce},vars->{db},$renderParams);
    my $setHeaderHTML = $ren->{text};
    $renderParams->{problem}->{source_file} = $hardcopyHeaderFile;
    $ren = render(vars->{ce},vars->{db},$renderParams);
    my $hardcopyHeaderHTML = $ren->{text};

    return {_id=>params->{set_id},set_header=>$setHeader,hardcopy_header=>$hardcopyHeader,
            set_header_content=>$headerContent, hardcopy_header_content=>$hardcopyHeaderContent,
            set_header_html=>$setHeaderHTML, hardcopy_header_html=>$hardcopyHeaderHTML
        };
};



return 1;
