### ProblemSet routes
##
#  These are the routes for related problem set functions in the RESTful webservice
#
##

package Routes::ProblemSets;

use strict;
use warnings;
use Dancer ':syntax';
use Routes qw/convertObjectToHash convertArrayOfObjectsToHash/;

our @set_props = qw/set_id set_header hardcopy_header open_date due_date answer_date visible enable_reduced_scoring assignment_type attempts_per_version time_interval versions_per_interval version_time_limit version_creation_time version_last_attempt_time problem_randorder hide_score hide_score_by_problem hide_work time_limit_cap restrict_ip relax_restrict_ip restricted_login_proctor/;

###
#  return all problem sets (as objects) for course *course_id* 
#
#  User user must have at least permissions>=10
#
##

get '/courses/:course_id/sets' => sub {

    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    my @globalSetNames = vars->{db}->listGlobalSets;
    my @globalSets = vars->{db}->getGlobalSets(@globalSetNames);
    
    return Routes::convertArrayOfObjectsToHash(\@globalSets);
};


######### CRUD for /courses/:course_id/sets/:set_id

####
#
#  return all problem set *set_id* for course *course_id*


get '/courses/:course_id/sets/:set_id' => sub {

    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    my $userSet = vars->{db}->getGlobalSet(param('set_id'));

    return Routes::convertObjectToHash($userSet);

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

    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    if (param('set_id') !~ /^[\w .-]*$/) {
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

    if(param('users_assigned')){
        my @users = split(',',param('users_assigned'));
        for my $user (@users){
            my $userSet = vars->{db}->newUserSet;
            $userSet->set_id($set->{set_id});
            $userSet->user_id($user);
            vars->{db}->addUserSet($userSet);
        }
    }

    return Routes::convertObjectToHash($set);
};

####
#  update problem set *set_id* for course *course_id*
#
#  returns the new problem set
#
#  permission > Student
##

put '/courses/:course_id/sets/:set_id' => sub {

    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        return {error=>"The problem set with name: " . param('set_id'). " does not exist."};  
    }

    my $set = vars->{db}->getGlobalSet(param('set_id'));

   
    for my $key (@set_props) {
        if (param($key)){
            $set->{$key} = param($key);
        }
    }

    vars->{db}->putGlobalSet($set);

    return Routes::convertObjectToHash($set);
};  


####
#  delete the problem set *set_id* for course *course_id*
#
#  returns the new problem set
#
#  permission > Student
##

del '/courses/:course_id/sets/:set_id' => sub {

    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        return {error=>"The set " . param('set_id'). " doesn't exist for course " . param("course_id")};
    }

    my $setToDelete = vars->{db}->getGlobalSet(param('set_id'));

    if(vars->{db}->deleteGlobalSet(param('set_id'))){
        return Routes::convertObjectToHash($setToDelete);
    } else {
        return {error=>"There was an error while trying to delete set " . param('set_id')};
    }
};

###
# reorder the problems in problem set *set_id* for course *course_id*
#
# returns an array of problem_id's in the new order.
#
#  permission > Student
#
###

put '/courses/:course_id/sets/:set_id/order' => sub {

    #if( ! session 'logged_in'){
    #    return { error=>"You need to login in again."};
    #}

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    if (!vars->{db}->existsGlobalSet(param('set_id'))){
        return {error=>"The set " . param('set_id'). " doesn't exist for course " . param("course_id")};
    }

    my $set = vars->{db}->getGlobalSet(params->{set_id});

    my @problems = vars->{db}->getAllGlobalProblems(params->{set_id});

    debug \@problems;

    return {};

};



######## CRUD for /courses/:course_id/sets/:set_id/users

##
#
#  Get a list of all user_id's assigned to set *set_id* in course *course_id* 
#
#  return:  array of user_id's.
##


get '/courses/:course_id/sets/:set_id/users' => sub {
    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }

    my @sets = vars->{db}->listSetUsers(param('set_id'));
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

post '/courses/:course_id/sets/:set_id/users' => sub {
    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

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
    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

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
#  Update properties of set *set_id* of course *course_id* for a subset of users
#
#  permission > Student
#
#  The users are assigned by setting the users_assigned parameter to a comma delimited list of user_id's.
#
#####

put '/courses/:course_id/sets/:set_id/users' => sub {
    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

    if (0+(session 'permission') < 10) {
        return {error=>"You don't have the necessary permission"};
    }



    return {error=>"The parameter: assigned_user has not been declared"} unless param('assigned_users');

    for my $userID (split(",",param('assigned_users'))){

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
        }
    }

    my $out = {};
    for my $key (@set_props){
        if (param($key)){
            $out->{$key} = param($key);
        }
    }
    $out->{assigned_users} = param('assigned_users');

    return $out; 


    return split(",",param('assigned_users'));
};


######## CRUD for /courses/:course_id/users/:user_id/sets/:set_id

##
#
#  Get the (user) properties for *set_id* for user *user_id* in course *course_id*
#
#  return:  UserSet properties
##


get '/courses/:course_id/users/:user_id/sets/:set_id' => sub {

    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

    if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
        return {error=>"You don't have the necessary permission"};
    }

    my $userSet = vars->{db}->getUserSet(param('user_id'),param('set_id'));

    return Routes::convertObjectToHash($userSet);

};

##
#
#  Add (assign) user *user_id* to set *set_id* for course *course_id*
#
#  return:  UserSet properties
##


post '/courses/:course_id/users/:user_id/sets/:set_id' => sub {

    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

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

    return Routes::convertObjectToHash(vars->{db}->getUserSet($userID,param('set_id')));
};

##
#
#  Delete (unassign) user *user_id* to set *set_id* for course *course_id*
#
#  return:  the removed UserSet properties
##


del '/courses/:course_id/users/:user_id/sets/:set_id' => sub {

    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

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
        return Routes::convertObjectToHash($userSet);
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

    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

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

        return Routes::convertObjectToHash($set);
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

    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

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

    if( ! session 'logged_in'){
        return { error=>"You need to login in again."};
    }

    if (0+(session 'permission') < 10 && param('user') ne param('user_id')) {
        return {error=>"You don't have the necessary permission"};
    }

    my @userSetNames = vars->{db}->listUserSets(param('user'));
    my @userSets = vars->{db}->getGlobalSets(@userSetNames);
    
    return \@userSetNames;
};




return 1;