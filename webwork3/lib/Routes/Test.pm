package Routes::Test;

use Dancer2 appname => 'Routes::Login';
use Dancer2::Plugin::Auth::Extensible;

##
#
## This package is used to do some route testing.
#
##

get '/courses/:course_id/logged-in' => sub {
	#debug session;
	return session->{data};
};

###
#
#  This is for testing if the require_login works
#
###

get '/courses/:course_id/test-login' => require_login sub {
   return {msg=>"success"};
};

###
#
# This is for testing restricting user roles
#
##

get '/courses/:course_id/test-for-student' => require_role student => sub {
	return {msg=>"success"};
};

get '/courses/:course_id/test-for-professor' => require_role professor => sub {
	return {msg=>"success"};
};

get '/courses/:course_id/test-for-admin' => require_role admin => sub {
	return {msg=>"success"};
};


###
#
#  returns a list of the user roles for the user :user_id in course :course_id
#
###

get '/courses/:course_id/users/:user_id/roles' => sub {

	my $user = get_user_details(route_parameters->{user_id});
  
	send_error("The user " . route_parameters->{user_id} . " must be a member of the course",424)
		unless defined($user) && defined($user->{user_id});
	return user_roles(route_parameters->{user_id});
};
