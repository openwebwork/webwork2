### Course routes
##
#  These are the routes for all /course URLs in the RESTful webservice
#
##

package Routes::User;

use strict;
use warnings;
use Dancer ':syntax';
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;
use WeBWorK::Utils qw/cryptPassword/;
use Data::Dumper;

our @user_props = qw/first_name last_name student_id user_id email_address permission status section recitation comment/;
our $PERMISSION_ERROR = "You don't have the necessary permissions.";


###
#  return all users for course :course
#
#  User user_id must have at least permissions>=10
#
##

get '/courses/:course/users' => sub {

	if(session->{permission} < 10){send_error($PERMISSION_ERROR,403)}

    my @allUsers = vars->{db}->getUsers(vars->{db}->listUsers);
    my %permissionsHash =  reverse %{vars->{ce}->{userRoles}};
    foreach my $u (@allUsers)
    {
        my $PermissionLevel = vars->{ce}->getPermissionLevel($u->{'user_id'});
        $u->{'permission'} = $PermissionLevel->{'permission'};

		my $studid= $u->{'student_id'};
		$u->{'student_id'} = "$studid";  # make sure that the student_id is returned as a string. 
		
    }
    return Routes::convertArrayOfObjectsToHash(\@allUsers);
};



###
#
#  create a new user user_id in course *course_id*
#
###


any ['put','post'] => '/courses/:course_id/users/:user_id' => sub {

	if(session->{permission} < 10){send_error($PERMISSION_ERROR,403)}

	my $user; 
	my $enrolled = vars->{ce}->{statuses}->{Enrolled}->{abbrevs}->[0];

	if (request->is_post() {  # it's a new user
		$user = vars->{db}->getUser(param('user_id'));
		send_error("The user with login " . param('user_id') . " already exists",404) if $user;
		$user = vars->{db}->newUser();
	} else { #existing user, update the user
		$user = vars->{db}->getUser(param('user_id'));	
		send_error("The user with login " . param('user_id') . " does not exist",404) unless $user;
	}

	# update the standard user properties
	
	for my $key (@user_props) {
        $user->{$key} = params->{$key} if (defined(params->{$key}));
    }
	
	# password record

	my $password = vars->{db}->getPassword(params->{user_id});
	if(! defined($password)){ # new user
		$password = vars->{db}->newPassword(params->{user_id});
		my $cryptedpassword = "";
		if (defined(params->{password})) {
			$cryptedpassword = cryptPassword(param('password'));
		}
		elsif (defined($new_student->{student_id})) {
			$cryptedpassword = cryptPassword($new_student->{student_id});
		}
		$password->password($cryptedpassword);

	} elsif (defined(params->{new_password})){ #update existing user
    	$password->{password} = cryptPassword(params->{new_password});
    	vars->{db}->putPassword($password);
    }
	
	# permission record
	my $permission = vars->{db}->getPermissionLevel(params->{user_id});
	if(defined($permission)){ # existing user
		if(params->{permission} != $permission->{permission}){
    		$permission->{permission} = params->{permission};
    		vars->{db}->putPermissionLevel($permission);
    	}
	} else {
		$permission = vars->{ce}->newPermissionLevel(params->{user_id},params->{permission});
	}

	my @messages = ();
	eval{ 
		if(request->is_post){
			vars->{db}->addUser($user); 
		} else {
			vars->{db}->putUser($user);
		}
	};

	if ($@) {
		push(@messages,"Add user for " . param('user_id') . " failed!");
	}
	
	eval { vars->{db}->addPassword($password); };
	if ($@) {
		push(@messages,"Add password for " . param('user_id') . " failed!");
	}
	
	eval { vars->{db}->addPermissionLevel($permission); };
	if ($@) {
		push(@messages,"Add permission for " . param('user_id') . " failed!");
	}

	if (scalar(@messages)>0) {
		send_error("Attempt to add user failed.  MESSAGE: " . join(", ",@messages), 400);
	} else {
		return convertObjectToHash($user);
	}
};


###
#
#  create a new user user_id in course *course_id*
#
###


del '/courses/:course_id/users/:user_id' => sub {

	if(session->{permission} < 10){send_error($PERMISSION_ERROR,403)}
	
	# check to see if the user exists

	debug Dumper(vars->{db}->listUsers);

	my $user = vars->{db}->getUser(param('user_id')); # checked
	send_error("Record for visible user " . param('user_id') . ' not found.',404) unless $user;

	if (param('user_id') eq session('user') )
	{
		send_error("You can't delete yourself from the course.",404);
	} 

	my $del = vars->{db}->deleteUser(param('user_id'));
		
	if($del) {
		return convertObjectToHash($user);
	} else {
		send_error("User with login " . param('user_id') . ' could not be deleted.',400);
	}

};

####
#
#  Get problems in set set_id for user user_id for course course_id
#
#  returns a UserSet
#
####

get '/courses/:course_id/sets/:set_id/users/:user_id/problems' => sub {

	if(session->{permission} < 10){send_error($PERMISSION_ERROR,403)}

	debug 'in /courses/sets/users/problems';

    if (! vars->{db}->existsGlobalSet(params->{set_id})){
    	send_error("The set " . params->{set_id} . " does not exist in course " . params->{course_id},404);
    }

    if (! vars->{db}->existsUserSet(params->{user_id}, params->{set_id})){
    	send_error("The user " . params->{user_id} . " has not been assigned to the set " . params->{set_id} 
    				. " in course " . params->{course_id},404);
    }

    my $userSet = vars->{db}->getUserSet(params->{user_id},params->{set_id});

    my @problems = vars->{db}->getAllMergedUserProblems(params->{user_id},params->{set_id});

    if(request->is_ajax){
        return convertArrayOfObjectsToHash(\@problems);
    } else {  # a webpage has requested this
        template 'problem.tt', {course_id=> params->{course_id}, set_id=>params->{set_id}, user=>params->{user_id},
                                    problem_id=>params->{problem_id}, pagename=>"Problem Viewer",
                                    problems => to_json(convertArrayOfObjectsToHash(\@problems)),
                                 	user_set => to_json(convertObjectToHash($userSet))}; 
    }
};


####
#
#  Get/update problem problem_id in set set_id for user user_id for course course_id
#
####

get '/users/:user_id/courses/:course_id/sets/:set_id/problems/:problem_id' => sub {

	if(session->{permission} < 10){send_error($PERMISSION_ERROR,403)}

  	my $problem = vars->{db}->getUserProblem(param('user_id'),param('set_id'),param('problem_id'));

    return convertObjectToHash($problem);
};

put '/users/:user_id/courses/:course_id/sets/:set_id/problems/:problem_id' => sub {

	if(session->{permission} < 10){send_error($PERMISSION_ERROR,403)}

	my $problem = vars->{db}->getUserProblem(param('user_id'),param('set_id'),param('problem_id'));

    for my $key (keys (%{$problem})){
    	if(param($key)){
			    $problem->{$key} = param($key);    		
    	}
    }

    vars->{db}->putUserProblem($problem);

    return convertObjectToHash($problem);
};


return 1;