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
use Data::Dumper;

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

    if (!defined(session 'user')) {
    	if (defined(params->{user})){
	    	session user => params->{user};
    	} else {
    		send_error("The user is not defined. You may need to authenticate again",401);	
    	}
	}

	my $key = vars->{db}->getKey(session 'user');
	my $timeLastLoggedIn = $key->{timestamp} || 0; 

	if(! defined(session 'key')){
		if(! defined($key)){
			my $newKey = create_session(session 'user');
			$key = vars->{db}->newKey(user_id=>(session 'user'), key=>$newKey);
		}
		session 'key' => $key->{key}; 
	}
	

	$key = vars->{db}->getKey(session 'user');

	# check to see if the user has timed out
	if(time() - $timeLastLoggedIn > vars->{ce}->{sessionKeyTimeout}){
		send_error("You're session has expired.",419);
	}

	# update the timestamp in the database so the user isn't logged out prematurely.
	$key->{timestamp} = time();
	vars->{db}->putKey($key);

	if (! defined(session 'permission')){
		my $permission = vars->{db}->getPermissionLevel(session 'user');
		session 'permission' => $permission->{permission};		
	}

	debug session;
}


sub checkPermissions {
	my $permissionLevel = shift;
	authenticate();

	if(session('permission') < $permissionLevel){send_error($PERMISSION_ERROR,403)}

}

### Note: this was copied from WeBWorK::Authen.pm

# clobbers any existing session for this $userID
# if $newKey is not specified, a random key is generated
# the key is returned
sub create_session {
	my ($userID, $newKey) = @_;
	my $timestamp = time;
	unless ($newKey) {
		my @chars = @{ vars->{ce}->{sessionKeyChars} };
		my $length = vars->{ce}->{sessionKeyLength};
		
		srand;
		$newKey = join ("", @chars[map rand(@chars), 1 .. $length]);
	}
	
	my $Key = vars->{db}->newKey(user_id=>$userID, key=>$newKey, timestamp=>$timestamp);
	# DBFIXME this should be a REPLACE
	eval { vars->{db}->deleteKey($userID) };
	vars->{db}->addKey($Key);

	#if ($ce -> {session_management_via} eq "session_cookie"),
	#    then the subroutine maybe_send_cookie should send a cookie.

	return $newKey;
}
