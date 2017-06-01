package Routes::Login;



use Dancer2;

#use Routes::Templates;

set serializer => 'JSON';

use Dancer2::Plugin::Auth::Extensible;
use Routes::Common qw/setCourseEnvironment setCookie/;
use WeBWorK3::Authen;
use Data::Dump qw/dump/;

### Note:  all routes in this file are prefixed with /api as stated in the bin/app.psgi file

## the following routes is matched for any URL starting with /courses. It is used to load the
#  CourseEnvironment
#
#  Note: for this to match before others, make sure this package is loaded before others.
#

any ['get','put','post','delete'] => '/courses/*/**' => sub {
	my ($courseID) = splat;

	#debug "in uber route";
  setCourseEnvironment($courseID);
  session 'webwork_dir' => config->{webwork_dir};
	pass;
};

any ['get','post'] => '/renderer/courses/*/**' => sub {
	my ($courseID) = splat;
	setCourseEnvironment($courseID);
	session 'webwork_dir' => config->{webwork_dir};
	pass;
};

###
#
# This is the main login route.  It validates the login and sets
# the session variable.
#
##

post '/courses/:course_id/login' => sub {

	#debug "in post /login";
  my $username = query_parameters->{username} || body_parameters->{username};
	my $password = query_parameters->{password} || body_parameters->{password};

	#set_course_environment("hi");
	my ($success, $realm) = authenticate_user($username,$password);

	if($success){
		my $key = vars->{db}->getKey($username)->{key};
		session key => $key;
		session user_id => $username; 

		return {session_key=>$key, user_id=>$username,logged_in=>1};

	} else {
		return {logged_in=>0};
	}
};


post '/courses/:course_id/logout' => sub {

	my $deleteKey = vars->{db}->deleteKey(session 'user');
	my $sessionDestroy = session->destroy;

	my $hostname = vars->{ce}->{server_root_url};
	$hostname =~ s/https?:\/\///;

	if ($hostname ne "localhost" || $hostname ne "127.0.0.1") {
		cookie "WeBWorKCourseAuthen." . params->{course_id} => "", domain=>$hostname, expires => "-1 hour";
	} else {
		cookie "WeBWorKCourseAuthen." . params->{course_id} => "", expires => "-1 hour";
	}

	return {logged_in=>0};
};

##
#
## This is for testing to see if the require_login works.
#
##

get '/courses/:course_id/test-login' => requires_login sub {
		return {success => 1};
};



get '/app-info' => sub {
	return {
        appname => config->{appname},
		environment=>config->{environment},
		port=>config->{port},
		content_type=>config->{content_type},
		startup_info=>config->{startup_info},
		server=>config->{server},
		appdir=>config->{appdir},
		template=>config->{template},
		logger=>config->{logger},
		session=>config->{session},
		session_expires=>config->{session_expires},
		session_name=>config->{session_name},
		session_secure=>config->{session_secure},
		session_is_http_only=>config->{session_is_http_only},
	};
};

get '/courses/:course_id/info' => sub {

	#debug "in /courses/" . route_parameters->{course_id} . "/info";

	setCourseEnvironment(route_parameters->{course_id});

	return {
		course_id => params->{course_id},
		webwork_dir => vars->{ce}->{webwork_dir},
		webworkURLs => vars->{ce}->{webworkURLs},
		webworkDirs => vars->{ce}->{webworkDirs}
	};

};



true
