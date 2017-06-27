package Routes::Login;

use Dancer2;
set serializer => 'JSON';



use Dancer2::Plugin::Auth::Extensible;
use Data::Dump qw/dump/;

use WeBWorK::CourseEnvironment;
use WeBWorK::DB;

## the remaining routes are in the following packages

use Routes::Admin;
use Routes::ProblemSets;
use Routes::Test; # this should be not accessible except when running tests
use Routes::Library;
use Routes::Settings;
use Routes::User;

###
#
# This is the main login route.  It validates the login and sets
# the session variable.
#
##

## the following routes is called before any other /api route.   It is used to load the
#  CourseEnvironment
#

hook before => sub {
  #debug "in before";
	if (! defined(session 'course_id')){
		if (request->request_uri =~ /courses\/(\w+)/ ){
			session course_id => $1;
		}
	}
	setCourseEnvironment(session 'course_id') if defined (session 'course_id');
};





post '/courses/:course_id/login' => sub {

	#debug "in POST /courses/:course_id/login";
  my $username = query_parameters->{username} || body_parameters->{username};
	my $password = query_parameters->{password} || body_parameters->{password};

	my ($success, $realm) = authenticate_user($username,$password);

	if($success){
		my $key = vars->{db}->getKey($username)->{key};
		session key => $key;
		session logged_in_user => $username;
		session logged_in_user_realm => $realm;
		session logged_in => true;

		return {session_key=>$key, user_id=>$username,logged_in=>1};

	} else {
		app->destroy_session;
		return {logged_in=>false};
	}
};


post '/courses/:course_id/logout' => sub {

	debug "in POST /courses/:course_id/logout";
	my $deleteKey = vars->{db}->deleteKey(session 'logged_in_user');
	app->destroy_session;

	my $hostname = vars->{ce}->{server_root_url};
	$hostname =~ s/https?:\/\///;

	if ($hostname ne "localhost" || $hostname ne "127.0.0.1") {
		cookie "WeBWorKCourseAuthen." . params->{course_id} => "", domain=>$hostname, expires => "-1 hour";
	} else {
		cookie "WeBWorKCourseAuthen." . params->{course_id} => "", expires => "-1 hour";
	}

	return {logged_in=>false};
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

	return {
		course_id => params->{course_id},
		webwork_dir => vars->{ce}->{webwork_dir},
		webworkURLs => vars->{ce}->{webworkURLs},
		webworkDirs => vars->{ce}->{webworkDirs}
	};

};

sub setCourseEnvironment {
	my ($course_id) = @_;

	#debug "in setCourseEnvironment";
	# debug session;
	# debug $course_id;
	session course_id => $course_id if defined($course_id);

	send_error("The course has not been defined.  You may need to authenticate again",401)
		unless (defined(session 'course_id'));

	$WeBWorK::Constants::WEBWORK_DIRECTORY = config->{webwork_dir};
	$WeBWorK::Debug::Logfile = config->{webwork_dir} . "/logs/debug.log";

	var ce => WeBWorK::CourseEnvironment->new({webwork_dir => config->{webwork_dir},
																								courseName=> $course_id});
	var db => new WeBWorK::DB(vars->{ce}->{dbLayout});

	if (! session 'logged_in'){
		# debug "checking ww2 cookie";

		 my $cookieValue = cookie "WeBWorK.CourseAuthen." . $course_id;

		 my ($user_id,$session_key,$timestamp) = split(/\t/,$cookieValue) if defined($cookieValue);

		 # get the key from the database;
		 if (defined $user_id){
			 my $key = vars->{db}->getKey($user_id);

			 if ($key->{key} eq $session_key && $key->{timestamp} == $timestamp){
				session key => $key->{key};
				session logged_in_user => $user_id;
				session logged_in => true;
				session logged_in_user_realm => 'webwork';  # this shouldn't be hard coded.
			 }
		 }
	 }

	 setCookie(session) if (session 'logged_in');
}

###
#
# This sets the cookie in the WW2 style to allow for seamless transfer back and forth.

sub setCookie {
  #debug "in setCookie";
	my $session = shift;
	my $user_id = $session->read("logged_in_user") || "";
	my $key = $session->read("key") || "";
	my $timestamp = $session->read("timestamp") || "";
  my $cookie_value = $user_id . "\t". $key . "\t" . $timestamp;

  my $hostname = vars->{ce}->{server_root_url};
  $hostname =~ s/https?:\/\///;
  my $cookie_name = "WeBWorK.CourseAuthen." . $session->read("course_id");
	my $cookie = Dancer2::Core::Cookie->new(name => $cookie_name, value => $cookie_value);

	if ($hostname eq "localhost" || $hostname eq "127.0.0.1"){
		$cookie->domain($hostname);
	}

}


true
