package Routes::Login {
use Dancer2 appname => "webwork3";
#use WeBWorK; 

use Routes::Templates;

#set serializer => 'JSON';

use Utils::Authentication qw/setCourseEnvironment setCookie/; 
use WeBWorK3::Authen; 
use Data::Dump qw/dump/;

### Note:  all routes in this file are prefixed with /api as stated in the bin/app.psgi file

## the following routes is matched for any URL starting with /courses. It is used to load the 
#  CourseEnvironment
#
#  Note: for this to match before others, make sure this package is loaded before others.
#

#hook after => sub {
#  my $info = shift; 
#  
#  debug "in after hook"; 
#  debug $info; 
#  
#
#};


any ['get','put','post','delete'] => '/api/courses/*/**' => sub {
	my ($courseID) = splat;
	Utils::Authentication::setCourseEnvironment($courseID);
	pass;
};

any ['get','post'] => '/renderer/courses/*/**' => sub {
	my ($courseID) = splat;
	Utils::Authentication::setCourseEnvironment($courseID);
	pass;
}; 



post '/api/courses/:course_id/login' => sub {

    debug "in post /courses/:course_id/login"; 
    
    debug dump config;
    
    debug request->headers;
    debug request->body;

    debug body_parameters;
    debug query_parameters; 
    debug route_parameters;
    
	my $authen = new WeBWorK3::Authen(vars->{ce});
    
    
	$authen->set_params({
			user => params->{user},
			password => params->{password},
			key => params->{session_key}
		});
        
    debug "verifying results"; 
	my $result = $authen->verify();
    
    debug $result; 
	if($result){
		my $key = $authen->create_session(params->{user});
		
		session user => params->{user};
		session key => $key;

		my $permission = vars->{db}->getPermissionLevel(session("user"));
		session permission => $permission->{permission};
		session timestamp => time();

        debug "calling setCookie"; 

		Utils::Authentication::setCookie();

		return to_json {session_key=>$key, user=>params->{user},logged_in=>1};

	} else {
		return to_json {logged_in=>0};
	} 
};


post '/courses/:course_id/logout' => sub {

	my $deleteKey = vars->{db}->deleteKey(session 'user');
	my $sessionDestroy = session->destroy;

	my $hostname = vars->{ce}->{server_root_url};
	$hostname =~ s/https?:\/\///;

	if ($hostname ne "localhost" && $hostname ne "127.0.0.1") {
		cookie "WeBWorKCourseAuthen." . params->{course_id} => "", domain=>$hostname, expires => "-1 hour";
	} else {
		cookie "WeBWorKCourseAuthen." . params->{course_id} => "", expires => "-1 hour";
	}

	return {logged_in=>0};
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

	setCourseEnvironment(params->{course_id});

	return {
		course_id => params->{course_id},
		webwork_dir => vars->{ce}->{webwork_dir},
		webworkURLs => vars->{ce}->{webworkURLs},
		webworkDirs => vars->{ce}->{webworkDirs}
	};

};


sub checkCourse {
	if (! defined(session->{course})) {
		if (defined(params->{course_id})) {
			session->{course} = params->{course_id};
		} else {
			send_error("The course has not been defined.  You may need to authenticate again",401);	
		}

	}

	var ce => WeBWorK::CourseEnvironment->new({webwork_dir => config->{webwork_dir}, courseName=> session->{course}});

}
}
true