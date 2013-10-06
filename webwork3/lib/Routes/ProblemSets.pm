### ProblemSet routes
##
#  These are the routes for related problem set functions in the RESTful webservice
#
##

package ProblemSets;

use strict;
use warnings;
use Dancer ':syntax';
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;
use Dancer::Plugin::Database;
use Dancer::Plugin::Ajax;
use List::Util qw(first max );

our @set_props = qw/set_id set_header hardcopy_header open_date due_date answer_date visible enable_reduced_scoring assignment_type attempts_per_version time_interval versions_per_interval version_time_limit version_creation_time version_last_attempt_time problem_randorder hide_score hide_score_by_problem hide_work time_limit_cap restrict_ip relax_restrict_ip restricted_login_proctor/;
our @problem_props = qw/problem_id flags value max_attempts source_file/;

###
#  return all problem sets (as objects) for course *course_id* 
#
#  User user must have at least permissions>=10
#
##

get '/courses/:course_id/sets' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    my @globalSetNames = vars->{db}->listGlobalSets;
    my @globalSets = vars->{db}->getGlobalSets(@globalSetNames);
    
    return convertArrayOfObjectsToHash(\@globalSets);
};


######### CRUD for /courses/:course_id/sets/:set_id

####
#
#  return all problem set *set_id* for course *course_id*


get '/courses/:course_id/sets/:set_id' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));


    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    my $globalSet = vars->{db}->getGlobalSet(param('set_id'));

    return convertObjectToHash($globalSet);

};

####
#  create a new problem set *set_id* for course *course_id*
#
#  any property can be set by assigning that property a value
#
#  returns the new problem set
#
#  permission > Student
##

post '/courses/:course_id/sets/:set_id' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));


    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    if (param('set_id') !~ /^[\w\_.-]+$/) {
        return {error=>"The set name must only contain A-Za-z0-9_-."};
    } 
    if (vars->{db}->existsGlobalSet(param('set_id'))){
        return {error=>"The set name: " . param('set_id'). " already exists."};  
    }

    my $set = vars->{db}->newGlobalSet;

    for my $key (@set_props) {
        $set->{$key} = param($key);
    }
            
    vars->{db}->addGlobalSet($set);

    if(param('assigned_users')){
        my $users = param('assigned_users');
        for my $user (@{$users}){
            my $userSet = vars->{db}->newUserSet;
            $userSet->set_id($set->{set_id});
            $userSet->user_id($user);
            vars->{db}->addUserSet($userSet);
        }
    }

    return convertObjectToHash($set);
};

####
#  update problem set *set_id* for course *course_id*
#
#  returns the new problem set
#
#  permission > Student
##

put '/courses/:course_id/sets/:set_id' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));


    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        return {error=>"The problem set with name: " . param('set_id'). " does not exist."};  
    }

    my $set = vars->{db}->getGlobalSet(param('set_id'));

   
    for my $key (@set_props) {
        $set->{$key} = param($key) if defined(param($key));
    }

    my $result = vars->{db}->putGlobalSet($set);

    ## test for an error? 

    return convertObjectToHash($set);
};  


####
#  delete the problem set *set_id* for course *course_id*
#
#  returns the new problem set
#
#  permission > Student
##

del '/courses/:course_id/sets/:set_id' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));


    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        return {error=>"The set " . param('set_id'). " doesn't exist for course " . param("course_id")};
    }

    my $setToDelete = vars->{db}->getGlobalSet(param('set_id'));

    if(vars->{db}->deleteGlobalSet(param('set_id'))){
        return convertObjectToHash($setToDelete);
    } else {
        return {error=>"There was an error while trying to delete set " . param('set_id')};
    }
};

###
# reorder the problems in problem set *set_id* for course *course_id*
#
# returns an array of problem_id's in the new order.
#
# Note: the parameter problems must contain an array (in the desired order) of problems
#
#  permission > Student
#
###

put '/courses/:course_id/sets/:set_id/order' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        return {error=>"The set " . param('set_id'). " doesn't exist for course " . param("course_id")};
    }

    my @problems_from_db = vars->{db}->getAllGlobalProblems(params->{set_id});

    my $problems_in_new_order = params->{problems};

    # debug @problems_in_new_order;
    # debug scalar(@problems_in_new_order);

    #for my $i (0 .. $#problems_in_new_order) {
    #     debug $i;
    #}

    for my $p (@{$problems_in_new_order}){
        #debug $problems_in_new_order[$i]->{problem_id} . " " . $problems_in_new_order[$i]->{source_file};
        my $problem = first { $_->{source_file} eq $p->{source_file} } @problems_from_db;
        debug $problem;
        if (vars->{db}->existsGlobalProblem(params->{set_id},$p->{problem_id})){
            $problem->problem_id($p->{problem_id});                 
            vars->{db}->putGlobalProblem($problem);
            #debug("updating problem $problem_paths[$i] and setting the index to $problem_indices[$i]");

        } else {
            # delete the problem with the old problem_id and create a new one
            vars->{db}->deleteGlobalProblem(params->{set_id},$problem->{problem_id});
            $problem->problem_id($p->{problem_id});
            vars->{db}->addGlobalProblem($problem);

            #debug("adding new problem $problem_paths[$i] and setting the index to $problem_indices[$i]");
        }
    }

    return "yeah! reordered!";

};



######## CRUD for /courses/:course_id/sets/:set_id/users

##
#
#  Get a list of all user_id's assigned to set *set_id* in course *course_id* 
#
#  return:  array of properties.
##


get '/courses/:course_id/sets/:set_id/users' => sub {
   
    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    my @userIDs = vars->{db}->listSetUsers(params->{set_id});

    debug @userIDs;

    my @sets = ();

    foreach my $user_id (@userIDs){
        push(@sets,vars->{db}->getMergedSet($user_id,params->{set_id}))
    }

    return convertArrayOfObjectsToHash(\@sets);
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

post '/courses/:course_id/sets/:set_id/users' => sub {
    
    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));


    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    return {error=>"The parameter: assigned_users has not been declared"} unless param('assigned_users');


    my @usersAdded = ();

    for my $userID (split(",",param('assigned_users'))){

        # check to make sure that the user is assigned to the course
        return {error=>"The user " . $userID . " is not enrolled in the course " . param("course_id")} 
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
#  permission > Student
#
#  The users are removed by setting the assigned_users parameter to a comma delimited list of user_id's.
#
#####

del '/courses/:course_id/sets/:set_id/users' => sub {
    
    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));


    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    return {error=>"The parameter: assigned_user has not been declared"};

    my @usersDeleted = ();

    for my $userID (split(",",param('assigned_users'))){

        # check to make sure that the user is assigned to the course
        return {error=>"The user " . $userID . " is not enrolled in the course " . param("course_id")} 
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
#  The users are assigned by setting the users_assigned parameter to a comma delimited list of user_id's.
#
#####

put '/courses/:course_id/sets/:set_id/users' => sub {
    
    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));


    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    return {error=>"The parameter: assigned_users has not been declared"} unless param('assigned_users');

    ## remember which users were assigned

    my @usersForTheSetBefore = vars->{db}->listSetUsers(params->{set_id});

    ## thenfor all users that were passed in, update or create a new userSet

    for my $userID (@{params->{assigned_users}}) {
        
        # check to make sure that the user is assigned to the course
        return {error=>"The user " . $userID . " is not enrolled in the course " . param("course_id")} 
            unless vars->{db}->getUser($userID);

        if (vars->{db}->existsUserSet($userID,params->{set_id})) { 
            my $set = vars->{db}->getUserSet($userID,params->{set_id});
            for my $key (@set_props) {
                $set->{$key} = params->{$key} if defined(params->{$key});
            }
            vars->{db}->putUserSet($set);
        } else {
            my $set = vars->{db}->newUserSet($userID,params->{set_id});
            $set->{user_id} = $userID;
            for my $key (@set_props) {
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


######## CRUD for /courses/:course_id/users/:user_id/sets/:set_id

##
#
#  Get the (user) properties for *set_id* for user *user_id* in course *course_id*
#
#  return:  UserSet properties
##


get '/courses/:course_id/users/:user_id/sets/:set_id' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
        return {error=>"You don't have the necessary permission"};
    }

    my $userSet = vars->{db}->getUserSet(param('user_id'),param('set_id'));

    return convertObjectToHash($userSet);

};

##
#
#  Add (assign) user *user_id* to set *set_id* for course *course_id*
#
#  return:  UserSet properties
##


post '/courses/:course_id/users/:user_id/sets/:set_id' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    my $userID = param('user_id');

    # check to make sure that the user is assigned to the course
    return {error=>"The user " . $userID . " is not enrolled in the course " . param("course_id")} 
            unless vars->{db}->getUser($userID);

    # check to see if the user has already been assigned and skip the addition if exists already.
    if (!vars->{db}->existsUserSet($userID,param('set_id'))) {
        my $userSet = vars->{db}->newUserSet;

        $userSet->{user_id}=$userID;
        $userSet->{set_id}=param('set_id');
        vars->{db}->addUserSet($userSet);
    }

    return convertObjectToHash(vars->{db}->getUserSet($userID,param('set_id')));
};

##
#
#  Delete (unassign) user *user_id* to set *set_id* for course *course_id*
#
#  return:  the removed UserSet properties
##


del '/courses/:course_id/users/:user_id/sets/:set_id' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    my $userID = param('user_id');

    # check to make sure that the user is assigned to the course
    return {error=>"The user " . $userID . " is not enrolled in the course " . param("course_id")} 
            unless vars->{db}->getUser($userID);

    my $userSet = vars->{db}->getUserSet($userID,param('set_id'));
    if ($userSet){
        vars->{db}->deleteUserSet($userID,param('set_id'));
        return convertObjectToHash($userSet);
    } else {
        return {error=>"An unknown error occurred removing user " . $userID . " from set " . param('set_id'). " in course " . param('course_id')};
    }

};

##
#
#  update the properties for set *set_id* for user  *user_id*  for course *course_id*
#
#  return:  UserSet properties
##


put '/courses/:course_id/users/:user_id/sets/:set_id' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    my $userID = param('user_id');

    # check to make sure that the user is assigned to the course
    return {error=>"The user " . $userID . " is not enrolled in the course " . param("course_id")} 
            unless vars->{db}->getUser($userID);

    my $set = vars->{db}->getUserSet($userID,param('set_id'));

    if ($set){
        for my $key (@set_props) {
            if (param($key)){
                $set->{$key} = param($key);
            }
        }

        vars->{db}->putUserSet($set);

        return convertObjectToHash($set);
    } else {
        return {error=>"The user " . $userID . " is not assigned to set " . param('set_id') . " in course " . param('course_id')};
    }

};


###
#  return all (user) sets for user *user_id* in course *course_id*
#
#  permission: > Student || if user_id == user;
#
##

get '/users/:user_id/courses/:course_id/sets' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
        return {error=>"You don't have the necessary permission"};
    }

    my @userSetNames = vars->{db}->listUserSets(param('user'));
    my @userSets = vars->{db}->getGlobalSets(@userSetNames);
    
    return \@userSetNames;
};

###
#  return all (user) sets for user *user_id* in course *course_id*
#
#  permission: > Student || if user_id == user;
#
##




get '/courses/:course_id/users/:user_id/sets' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
        return {error=>"You don't have the necessary permission"};
    }

    my @userSetNames = vars->{db}->listUserSets(param('user'));
    my @userSets = vars->{db}->getGlobalSets(@userSetNames);
    
    return \@userSetNames;
};

####
#
##   gets the problems (global) in set *set_id* for course *course_id*
#
#   returns [problems]
#
####

get '/courses/:course_id/sets/:set_id/problems' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
        return {error=>"You don't have the necessary permission"};
    }

    my @problems = vars->{db}->getAllGlobalProblems(params->{set_id});

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

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
        return {error=>"You don't have the necessary permission"};
    }

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        return {error=>"The problem set with name: " . param('set_id'). " does not exist."};  
    }

    if (!vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id})) {
        return {error=>"The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id}};
    }

    my $problem = vars->{db}->getGlobalProblem(params->{set_id},params->{problem_id});
    if(request->is_ajax){
        return convertObjectToHash($problem);
    } else {  # a webpage has requested this
        my $theProblem = convertObjectToHash($problem);
        template 'problem.tt', { problem => to_json($theProblem) }; 
    }
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

put '/courses/:course_id/sets/:set_id/problems/:problem_id' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
        return {error=>"You don't have the necessary permission"};
    }

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        return {error=>"The problem set with name: " . param('set_id'). " does not exist."};  
    }

    if (!vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id})) {
        return {error=>"The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id}};
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

post '/courses/:course_id/sets/:set_id/problems/:problem_id' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10 && session->{user} ne session->{user_id}) {
        return {error=>"You don't have the necessary permission"};
    }

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        return {error=>"The problem set with name: " . param('set_id'). " does not exist."};  
    }

    ## check if max_attempts or value was passed.  If not give them default values.

    my $maxAttempts = defined(params->{max_attempts}) ? params->{max_attempts} : -1;
    my $value = defined(params->{value}) ? params->{value} : 1; 

    my $globalSet = vars->{db}->getGlobalSet(param('set_id'));

    my $problem = vars->{db}->newGlobalProblem;

    # my $problem_info = database->quick_select('OPL_pgfile', {pgfile_id => param('problem_id')});
    # my $path_id = $problem_info->{path_id};
    # my $path_header = database->quick_select('OPL_path',{path_id=>$path_id})->{path};
    # $problem->{source_file} = "Library/" . $path_header . "/" . $problem_info->{filename};
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

del '/courses/:course_id/sets/:set_id/problems/:problem_id' => sub {

    return {error=>session->{error}, type=>"login"} if (defined(session->{error}));

    if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
        return {error=>"You don't have the necessary permission"};
    }

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        return {error=>"The problem set with name: " . param('set_id'). " does not exist."};  
    }

    if (!vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id})) {
        return {error=>"The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id}};
    }

    my $problem_to_delete = vars->{db}->getGlobalProblem(params->{set_id},params->{problem_id});

    my $result = vars->{db}->deleteGlobalProblem(params->{set_id},params->{problem_id});

    debug $result;

    if ($result) {
        return convertObjectToHash($problem_to_delete);
    } else {
        return $result;
    }

};





return 1;