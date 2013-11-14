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
use Utils::ProblemSets qw/reorderProblems addProblems addUserSet addUserProblems deleteProblems/;
use WeBWorK::Utils qw/parseDateTime/;
use Array::Utils qw(array_minus); 
use Routes::Authentication qw/checkPermissions setCourseEnvironment/;
use Utils::CourseUtils qw/getCourseSettings/;
use Dancer::Plugin::Database;
use Dancer::Plugin::Ajax;
use List::Util qw(first max );

our @set_props = qw/set_id set_header hardcopy_header open_date due_date answer_date visible enable_reduced_scoring assignment_type attempts_per_version time_interval versions_per_interval version_time_limit version_creation_time version_last_attempt_time problem_randorder hide_score hide_score_by_problem hide_work time_limit_cap restrict_ip relax_restrict_ip restricted_login_proctor/;
our @user_set_props = qw/user_id set_id psvn set_header hardcopy_header open_date due_date answer_date visible enable_reduced_scoring assignment_type description restricted_release restricted_status attempts_per_version time_interval versions_per_interval version_time_limit version_creation_time problem_randorder version_last_attempt_time problems_per_page hide_score hide_score_by_problem hide_work time_limit_cap restrict_ip relax_restrict_ip restricted_login_proctor hide_hint/;
our @problem_props = qw/problem_id flags value max_attempts source_file/;

###
#  return all problem sets (as objects) for course *course_id* 
#
#  User user must have at least permissions>=10
#
##

get '/courses/:course_id/sets' => sub {

    checkPermissions(10,session->{user});


    my @globalSetNames = vars->{db}->listGlobalSets;
    my @globalSets = vars->{db}->getGlobalSets(@globalSetNames);
    
    return convertArrayOfObjectsToHash(\@globalSets);
};


######### CRUD for /courses/:course_id/sets/:set_id

####
#
#  return all problem set *set_id* for course *course_id*


get '/courses/:course_id/sets/:set_id' => sub {

    checkPermissions(10,session->{user});

    my $globalSet = vars->{db}->getGlobalSet(param('set_id'));

    my @userNamesFromDB = vars->{db}->listSetUsers(params->{set_id});

    my @problemsFromDB = vars->{db}->getAllGlobalProblems(params->{set_id});


    my $setResults = convertObjectToHash($globalSet);

    $setResults->{assigned_users} = \@userNamesFromDB;

    $setResults->{problems} = convertArrayOfObjectsToHash(\@problemsFromDB);




    return $setResults;
};

####
#  create a new (update an old) problem set *set_id* for course *course_id*
#
#  any property can be set by assigning that property a value
#
#  returns the new problem set
#
#  permission > Student
##

any ['put', 'post'] => '/courses/:course_id/sets/:set_id' => sub {

    debug 'in /courses/:course_id/sets/:set_id';

    checkPermissions(10);

    # call validator directly instead

    if (param('set_id') !~ /^[\w\_.-]+$/) {
        send_error("The set name must only contain A-Za-z0-9_-.",403);
    } 

    if (request->is_post() && vars->{db}->existsGlobalSet(param('set_id'))){
        send_error("The set name: " . param('set_id'). " already exists.",404);
    } elsif (request->is_put() && ! vars->{db}->existsGlobalSet(params->{set_id})){
        send_error("The set name: " . param('set_id'). " does not exist.",404);  
    }

    ####
    #
    # Set up the global set for either a add (if new) or put (if old)
    #
    ##

    my $set = (request->is_post()) ? vars->{db}->newGlobalSet : vars->{db}->getGlobalSet(params->{set_id}); 

    for my $key (@set_props) {
        $set->{$key} = param($key);
    }
    if(request->is_post()){     
        vars->{db}->addGlobalSet($set);
    } else {
        vars->{db}->putGlobalSet($set);
    }

    ##
    #
    #  Take care of the assigned users
    #
    ###

    my $userNames = params->{assigned_users};

    my @userNamesFromDB = vars->{db}->listSetUsers(params->{set_id});

    my @usersToAdd = array_minus(@{$userNames},@userNamesFromDB);

    my @usersToDelete = array_minus(@userNamesFromDB,@{$userNames});

    for my $user (@usersToAdd){
        addUserSet($user);
        addUserProblems($user);
    }

    if(request->is_put){
        for my $user (@usersToDelete){
            vars->{db}->deleteUserSet($user,params->{set_id});
        }
    }

    # handle the global problems. 

    my @problemsFromDB = vars->{db}->getAllGlobalProblems(params->{set_id});

    if(scalar(@problemsFromDB) == scalar(@{params->{problems}})){  # then perhaps the problems need to be reordered.
        debug "reordering or reassigning problems";
        debug $userNames;
        reorderProblems($userNames);
    } elsif (scalar(@problemsFromDB) < scalar(@{params->{problems}})) { # problems have been added
        debug "adding problems";
        addProblems(vars->{db},params->{set_id},params->{problems},params->{assigned_users});
    } else { # problems have been deleted.  
        debug "deleting problems";
        deleteProblems(vars->{db},params->{set_id},params->{problems});
    }

    ## handle the user Problems

    # for my $user (@usersToAdd){
    #     addUserProblems(vars->{db},params->{set_id},$user,params->{problems});
    # }

    
    my @globalProblems = vars->{db}->getAllGlobalProblems(params->{set_id});

    my $returnSet = convertObjectToHash($set);


    $returnSet->{assigned_users} = $userNames;
    $returnSet->{problems} = convertArrayOfObjectsToHash(\@globalProblems);

    return $returnSet;

};


####
#  delete the problem set *set_id* for course *course_id*
#
#  returns the new problem set
#
#  permission > Student
##

del '/courses/:course_id/sets/:set_id' => sub {

    checkPermissions(10,session->{user});

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        send_error("The set " . param('set_id'). " doesn't exist for course " . param("course_id"),404);
    }

    my $setToDelete = vars->{db}->getGlobalSet(param('set_id'));

    if(vars->{db}->deleteGlobalSet(param('set_id'))){
        return convertObjectToHash($setToDelete);
    } else {
        send_error("There was an error while trying to delete set " . param('set_id'),424);
    }

};





######## CRUD for /courses/:course_id/sets/:set_id/users

##
#
#  Get a list of all user_id's assigned to set *set_id* in course *course_id* 
#
#  return:  array of properties.
##


get '/courses/:course_id/sets/:set_id/users' => sub {

    checkPermissions(10,session->{user});
   
    my @userIDs = vars->{db}->listSetUsers(params->{set_id});

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
    
    checkPermissions(10,session->{user});
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
#  permission > Student
#
#  The users are removed by setting the assigned_users parameter to a comma delimited list of user_id's.
#
#####

del '/courses/:course_id/sets/:set_id/users' => sub {

    checkPermissions(10,session->{user});
    
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
#  The users are assigned by setting the users_assigned parameter to a comma delimited list of user_id's.
#
#####

put '/courses/:course_id/sets/:set_id/users' => sub {
    
    checkPermissions(10,session->{user});

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


######## CRUD for /courses/:course_id/users/:user_id/sets/:set_id

##
#
#  Get the (user) properties for *set_id* for user *user_id* in course *course_id*
#
#  return:  UserSet properties
##


get '/courses/:course_id/users/:user_id/sets/:set_id' => sub {

    checkPermissions(10,session->{user});

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

    checkPermissions(10,session->{user});

    my $userID = param('user_id');

    # check to make sure that the user is assigned to the course
    send_error("The user " . $userID . " is not enrolled in the course " . param("course_id"),404)
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
    

    checkPermissions(10,session->{user});

    my $userID = param('user_id');

    # check to make sure that the user is assigned to the course
    send_error("The user " . $userID . " is not enrolled in the course " . param("course_id"),404)
            unless vars->{db}->getUser($userID);

    my $userSet = vars->{db}->getUserSet($userID,param('set_id'));
    if ($userSet){
        vars->{db}->deleteUserSet($userID,param('set_id'));
    } else {
        send_error("An unknown error occurred removing user " . $userID . " from set " 
                . param('set_id'). " in course " . param('course_id'),466);
    }

    return convertObjectToHash($userSet);
};

##
#
#  update the properties for set *set_id* for user  *user_id*  for course *course_id*
#
#  return:  UserSet properties
##

## I think this is superceded by code above:

# put '/courses/:course_id/users/:user_id/sets/:set_id' => sub {
    
#     checkPermissions(10,session->{user});

#     my $userID = param('user_id');

#     # check to make sure that the user is assigned to the course
#     send_error("The user " . $userID . " is not enrolled in the course " . param("course_id"),404)
#             unless vars->{db}->getUser($userID);

#     my $set = vars->{db}->getUserSet($userID,param('set_id'));

#     debug $set;

#     if ($set){
#         for my $key (@user_set_props) {
#             if (param($key)){
#                 $set->{$key} = param($key);
#             }
#         }

#         vars->{db}->putUserSet($set);

#         return convertObjectToHash($set);
#     } else {
#         send_error("The user " . $userID . " is not assigned to set " . param('set_id') . " in course " 
#                 . param('course_id'),404);
#     }

# };


###
#  return all (user) sets for user *user_id* in course *course_id*
#
#  permission: > Student || if user_id == user;
#
##




get '/courses/:course_id/users/:user_id/sets' => sub {
    
    checkPermissions(10,session->{user});

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

    checkPermissions(10,session->{user});

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

put '/courses/:course_id/sets/:set_id/problems' => sub {

    checkPermissions(10,session->{user});

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        send_error("The set " . param('set_id'). " doesn't exist for course " . param("course_id"),404);
    }

    my @problems_from_db = vars->{db}->getAllGlobalProblems(params->{set_id});

    my @newProblems = reorderProblems(vars->{db},params->{set_id},params->{problems});
    
    return convertArrayOfObjectsToHash(\@newProblems);
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

    checkPermissions(10,session->{user});
  
    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        send_error("The problem set with name: " . param('set_id'). " does not exist.",404);  
    }

    if (!vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id})) {
        send_error("The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id},404);
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

    checkPermissions(10,session->{user});

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

post '/courses/:course_id/sets/:set_id/problems/:problem_id' => sub {

    checkPermissions(10,session->{user});

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

del '/courses/:course_id/sets/:set_id/problems/:problem_id' => sub {

    checkPermissions(10,session->{user});

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        send_error("The problem set with name: " . param('set_id'). " does not exist.",404);
    }

    if (!vars->{db}->existsGlobalProblem(params->{set_id},params->{problem_id})) {
        send_error("The problem with id " . params->{problem_id} . " doesn't exist in set " . params->{set_id},404);
    }

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
    #checkPermissions(10,session->{user});  ## not needed but students shouldn't need to access this.

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

    setCourseEnvironment(params->{course_id});
    template 'simple-editor.tt', {course_id=> params->{course_id},theSetting => to_json(getCourseSettings),
        pagename=>"Simple Editor"};
};





return 1;