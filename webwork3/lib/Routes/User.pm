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

our @user_props = qw/first_name last_name student_id user_id email_address permission status section recitation comment/;



###
#  return all users for course :course
#
#  User user_id must have at least permissions>=10
#
##

get '/courses/:course/users' => sub {

    my $ce = vars->{ce};
    my $db = vars->{db};


    my @allUsers = $db->getUsers($db->listUsers);
    my %permissionsHash =  reverse %{$ce->{userRoles}};
    foreach my $u (@allUsers)
    {
        my $PermissionLevel = $db->getPermissionLevel($u->{'user_id'});
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


post '/courses/:course_id/users/:user_id' => sub {
	
	my $user = vars->{db}->getUser(param('user_id'));
	send_error("The user with login " . param('user_id') . " already exists",404) if $user;
	
	my $new_student = vars->{db}->{user}->{record}->new();
	my $enrolled = vars->{ce}->{statuses}->{Enrolled}->{abbrevs}->[0];
	for my $key (@user_props) {
        $new_student->{$key} = param($key);
    }
	
	# password record
	my $cryptedpassword = "";
	if (param('password')) {
		$cryptedpassword = cryptPassword(param('password'));
	}
	elsif ($new_student->student_id()) {
		$cryptedpassword = cryptPassword($new_student->student_id());
	}
	my $password = vars->{db}->newPassword(user_id => param('user_id'));
	$password->password($cryptedpassword);
	
	# permission record
	my $permission = param('permission') || "";
	if (defined(vars->{ce}->{userRoles}{$permission})) {
		$permission = vars->{ce}->newPermissionLevel(
			user_id => param('user_id'), 
			permission => vars->{ce}->{userRoles}{$permission});
	}
	else {
		$permission = vars->{db}->newPermissionLevel(user_id => param('user_id'), 
			permission => vars->{ce}->{userRoles}{student});
	}

	my @messages = ();
	eval{ vars->{db}->addUser($new_student); };
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
		return convertObjectToHash($new_student);
	}
};


###
#
#  update a new user *user_id* in course *course_id*
#
###


put '/courses/:course_id/users/:user_id' => sub {
	
	debug "in /courses/:course_id/users/:user_id";

	debug session->{course};
	debug session->{user};

	debug vars->{db}->getUser(params->{user_id});

	my $user = vars->{db}->getUser(param('user_id'));
	
	send_error("The user with login " . param('user_id') . " does not exist",404) unless $user;

	for my $key (@user_props) {
        $user->{$key} = param($key);
    }

    debug $user;

    if (defined(params->{new_password})){
    	my $password = vars->{db}->getPassword(params->{user_id});
    	$password->{password} = cryptPassword(params->{new_password});
    	vars->{db}->putPassword($password);
    }

    my $result = vars->{db}->putUser($user);

	return convertObjectToHash($user);

};





###
#
#  create a new user user_id in course *course_id*
#
###


del '/courses/:course_id/users/:user_id' => sub {
	
	# check to see if the user exists

	my $user = vars->{db}->getUser(param('user_id')); # checked
	send_error("Record for visible user " . param('user_id') . ' not found.',404) unless $user;

	if (param('user_id') eq param('user') )
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

  	my $problem = vars->{db}->getUserProblem(param('user_id'),param('set_id'),param('problem_id'));

    return convertObjectToHash($problem);
};

put '/users/:user_id/courses/:course_id/sets/:set_id/problems/:problem_id' => sub {

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