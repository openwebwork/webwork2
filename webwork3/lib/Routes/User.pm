### Course routes
##
#  These are the routes for all /course URLs in the RESTful webservice
#
##

package Routes::User;
use base qw(Exporter);

use Dancer2 appname => "Routes::Login";
use Dancer2::Plugin::Auth::Extensible;
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash convertBooleans/;
use WeBWorK::Utils qw/cryptPassword/;

use Data::Dump qw/dump/;

our @user_props = qw/first_name last_name student_id user_id email_address permission status
                    section recitation comment displayMode showOldAnswers useMathView/;
our @boolean_user_props = qw/showOldAnswers useMathView/;

our @EXPORT    = ();
our @EXPORT_OK = qw(@boolean_user_props);

###
#  return all users for course :course
#
##

get '/courses/:course/users' => require_role professor => sub {

  my @user_ids = vars->{db}->listUsers;
  my @users = map { get_one_user(vars->{db},$_);} @user_ids;
  return convertArrayOfObjectsToHash(\@users);
};

###
#
# get a single user
#
###

get 'courses/:course_id/users/:user_id' => require_role professor => sub {
  return get_one_user(vars->{db},route_parameters->{user_id});
};

###
#
#  create a new user user_id in course *course_id*
#
###


post '/courses/:course_id/users/:user_id' => require_role professor => sub {

  my $user_id = route_parameters->{user_id};
	my $user = vars->{db}->getUser($user_id);
	send_error("The user with login $user_id already exists",404) if $user;


  my $properties = body_parameters->as_hashref;

  return addOneUser(vars->{db},$properties);

};

###
#
#  Add multiple users to the course using a single route_parameters
#
##

post '/courses/:course_id/users' => require_role professor => sub {

  debug "in POST /courses/:course_id/users";
  my $users = body_parameters->multi->{users};

  my @users_to_add;
  for my $user (@$users){
    push(@users_to_add,addOneUser(vars->{db},$user));
  }

  return \@users_to_add;
};




##
#
#  update an existing user
#
##

put '/courses/:course_id/users/:user_id' => require_any_role [qw/professor student/] => sub {

  ## if the user is a student, they can only change their own information.

  if (user_has_role('student') && (session 'logged_in_user') ne route_parameters->{user_id}){
    send_error("A user with the role of student can only change his/her own information", 403);
  }

	my $user = vars->{db}->getUser(route_parameters->{user_id});
	send_error("The user with login " . route_parameters->{user_id} . " does not exist",404) unless $user;

	# update the standard user properties

  my $params_to_update = convertBooleans(body_parameters->as_hashref,\@boolean_user_props);

  # if the user is a student, only allow changes to a few properties:

  if (user_has_role('professor')){
    for my $key (@user_props) {
      $user->{$key} = $params_to_update->{$key} if (defined $params_to_update->{$key});
    }
  } else {
    for my $key (qw/email_address displayMode showOldAnswers userMathView/){
      $user->{$key} = $params_to_update->{$key} if (defined $params_to_update->{$key});
    }
  }

	vars->{db}->putUser($user);

  my $permission = vars->{db}->getPermissionLevel(params->{user_id});
  if (user_has_role('professor')){
    if (defined $params_to_update->{permission}){

      $permission->{permission} = $params_to_update->{permission};
      vars->{db}->putPermissionLevel($permission);
    }
  }

	return get_one_user(vars->{db},$user->{user_id});

};



###
#
#  create a new user user_id in course *course_id*
#
###


del '/courses/:course_id/users/:user_id' => require_role professor => sub {

	# check to see if the user exists

  my $user_id = route_parameters->{user_id};
	my $user = vars->{db}->getUser($user_id); # checked
	send_error("Record for visible user $user_id not found.",404) unless $user;

	if ($user_id eq session('logged_in_user') )
	{
		send_error("You can't delete yourself from the course.",404);
	}

	my $del = vars->{db}->deleteUser($user);

	if($del) {
		return convertObjectToHash($user);
	} else {
		send_error("User with login $user_id could not be deleted.",400);
	}
};

####
#
# Gets the status (logged in or not) of all users.  Useful for the classlist manager.
#
####

get '/courses/:course_id/users/status/login' => sub { #require_role professor => sub {

  debug "in /courses/:course_id/users/status/login";

	my @users = vars->{db}->listUsers();

	my @status = map {
		my $key = vars->{db}->getKey($_);
		{ user_id=>$_,
			logged_in => ($key and time <= $key->timestamp()+vars->{ce}->{sessionKeyTimeout}) ? JSON::true : JSON::false}
	} @users;

	return \@status;

};

# set a new password for user :user_id in course :course_id

post '/courses/:course_id/users/:user_id/password' => require_any_role [qw/professor student/] => sub {

  ## if the user is a student, they can only change their own information.

  if (user_has_role('student') && (session 'logged_in_user') ne route_parameters->{user_id}){
    send_error("A user with the role of student can only change his/her own password", 403);
  }

	my $user = vars->{db}->get_one_user(route_parameters->{user_id});
	send_error("The user with login " . route_parameters->{user_id} . " does not exist",404) unless $user;


	my $password = vars->{db}->getPassword(params->{user_id});
	if(crypt(params->{old_password}, $password->password) eq $password->password){
    	$password->{password} = cryptPassword(params->{new_password});
    	vars->{db}->putPassword($password);
        return {message => "password changed", success => 1}
	} else {
        return {message => "orig password not correct", success => 0}
	}
};

###
#
#  get a single user
#
###

sub get_one_user {
  my ($db,$user_id) = @_;
  my $user = $db->getUser($user_id);
  my $permission = $db->getPermissionLevel($user_id);
  my $user_props = convertObjectToHash($user,\@boolean_user_props);
  $user_props->{permission} = $permission->{permission};
  $user_props->{_id} = $user->{user_id};

  return $user_props;
}

###
#
#  add one user to the course.
#
###

sub addOneUser {
  my ($db,$props) = @_;

  # update the standard user properties

  my $user = vars->{db}->newUser();

  for my $key (@user_props) {
    $user->{$key} = $props->{$key} if (defined($props->{$key}));
  }
  $user->{_id} = $user->{user_id}; # this will help Backbone on the client end to know if a user is new or existing.

  # password record

  my $password = $db->newPassword();
  $password->{user_id} = $user->{user_id};
  my $cryptedpassword = "";
  if (defined($props->{password})) {
    $cryptedpassword = cryptPassword($props->{password});
  }
  elsif (defined($props->{student_id})) {
    $cryptedpassword = cryptPassword($props->{student_id});
  }
  $password->password($cryptedpassword);



  # permission record

  my $permission = $db->newPermissionLevel();
  $permission->{user_id} = $props->{user_id};
  $permission->{permission} = $props->{permission} || 0;

  $db->addUser($user);
  $db->addPassword($password);
  $db->addPermissionLevel($permission);

  return get_one_user($db,$user->{user_id});

}


return 1;
