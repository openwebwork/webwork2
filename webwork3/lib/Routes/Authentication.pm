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


any ['get','put','post','del'] => '/**' => sub {
	
	debug "In uber route";

	checkRoutePermissions();
	authenticate();

	pass;
};



sub authenticate {
		## need to check that the session hasn't expired. 

    debug "Checking if session->{user} is defined";
    debug session->{user};

    if (! defined(session->{user})) {
    	if (defined(params->{user})){
	    	session->{user} = params->{user};
    	} else {
    		send_error("The user is not defined. You may need to authenticate again",401);	
    	}
	}

	if (! defined(session->{course})) {
		if (defined(params->{course})) {
			session->{course} = params->{course};
		} else {
			send_error("The course has not been defined.  You may need to authenticate again",401);	
		}

	}

	# debug "Checking if session->{session_key} is defined";
	# debug session->{session_key};


	if(! defined(session->{session_key})){
		if (defined(session->{course})){
			debug session->{course}.'_key';		
			my $session_key = database->quick_select(session->{course}.'_key', { user_id => session->{user} });
			if ($session_key->{key_not_a_keyword} eq param('session_key')) {
				session->{session_key} = params->{session_key};
			} 
		}
	}

	if(! defined(session->{session_key})){
		send_error("The session_key has not been defined or is not correct.  You may need to authenticate again",401);	
	}

	debug "Checking if session->{permission} is defined";
	debug session->{permission};


	if (defined(session->{course}) && ! defined(session->{permission})){
		my $permission = database->quick_select(session->{course}.'_permission', { user_id => session->{user} });
		session->{permission} = $permission->{permission};		
	}

}

sub checkRoutePermissions {

	debug "Checking Route Permissions";

	debug request->path;

}
