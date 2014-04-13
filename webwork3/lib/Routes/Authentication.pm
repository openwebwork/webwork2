### Library routes
##
#  These are the routes for all library functions in the RESTful webservice
#
##

package Routes::Authentication;

use strict;
use warnings;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use WeBWorK::Constants;

use base qw(Exporter);
our @EXPORT    = ();
our @EXPORT_OK = qw(checkPermissions authenticate setCourseEnvironment buildSession);


our $PERMISSION_ERROR = "You don't have the necessary permissions.";

## the following routes is matched for any URL starting with /courses. It is used to load the 
#  CourseEnvironment
#
#  Note: for this to match before others, make sure this package is loaded before others.
#

any ['get','put','post','delete'] => '/courses/*/**' => sub {

	my ($courseID) = splat;
	debug "In the uber /courses/:course_id route";

	setCourseEnvironment($courseID);

	pass;

};

any ['get','post'] => '/renderer/courses/*/**' => sub {
	my ($courseID) = splat;
	setCourseEnvironment($courseID);
	pass;
};

sub setCourseEnvironment {

	my $courseID = shift;

	if (defined($courseID)) {
		session course => $courseID;
	} else {
		send_error("The course has not been defined.  You may need to authenticate again",401);	
	}

	var ce => WeBWorK::CourseEnvironment->new({webwork_dir => config->{webwork_dir}, courseName=> session->{course}});

	var db => new WeBWorK::DB(vars->{ce}->{dbLayout});

	$WeBWorK::Constants::WEBWORK_DIRECTORY = config->{webwork_dir};
	$WeBWorK::Debug::Logfile = config->{webwork_dir} . "/logs/debug.log";
}

sub authenticate {

	if(! vars->{db}){ 
		send_error("The database object DB is not defined.  Make sure that you call setCourseEnvironment first.",404);
	}


	## need to check that the session hasn't expired. 

	
	#debug "Checking to see if the user is defined.";
	#debug session->{user};

    if (!defined(session 'user')) {
    	if (defined(params->{user})){
	    	session user => params->{user};
    	} else {
    		send_error("The user is not defined. You may need to authenticate again",401);	
    	}
	}

	if(! defined(session 'key')){
		my $key = vars->{db}->getKey(session 'user');

		if ($key->{key} eq params->{session_key}) {
			session 'key'  => params->{session_key};
		} 


	}

	if(! defined(session 'key')){
		send_error("The session key has not been defined or is not correct.  You may need to authenticate again",401);	
	}

	# update the timestamp in the database so the user isn't logged out prematurely.

	my $key = vars->{db}->getKey(session 'user');
	$key->{timestamp} = time();
	vars->{db}->putKey($key);

	if (! defined(session 'permission')){
		my $permission = vars->{db}->getPermissionLevel(session 'user');
		session 'permission' => $permission->{permission};		
	}

	debug session;
}

# this will build up the dancer session based on the ww2 session. 

sub buildSession {
	if (!defined(session 'user')) {
    	if (defined(params->{user})){
	    	session user => params->{user};
    	}
	}

	if(! defined(session 'key') && defined(session 'user')){
		my $key = vars ->{db}->getKey(session 'user');
		session 'key' => $key->{key}; 
		$key->{timestamp} = time();
		vars->{db}->putKey($key);

	}

	if (! defined(session 'permission') && defined(session 'user')){
		my $permission = vars->{db}->getPermissionLevel(session 'user');
		session 'permission' => $permission->{permission};		
	}
}

sub checkPermissions {

	authenticate();

	## include an override here as well

	my $permissionLevel = shift;

	if(session('permission') < $permissionLevel){send_error($PERMISSION_ERROR,403)}

}
