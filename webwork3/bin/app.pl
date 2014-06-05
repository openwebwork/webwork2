#!/usr/bin/env perl
use Dancer;
use Dancer::Plugin::Database;

# link to WeBWorK code libraries
use lib config->{webwork_dir}.'/lib';
use lib config->{pg_dir}.'/lib';

use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Authen;

## note: Routes::Authenication must be passed first
use Routes::Authentication qw/authenticate setCourseEnvironment/; 
use Routes::Course;
use Routes::Library;
use Routes::ProblemSets;
use Routes::User;
use Routes::Settings;
use Routes::PastAnswers;

set serializer => 'JSON';

hook 'before' => sub {

    # for my $key (keys(%{request->params})){
    # 	my $value = defined(params->{$key}) ? params->{$key} : ''; 
    # 	debug($key . " : " . $value);
    # } 

};

## right now, this is to help handshaking between the original webservice and dancer.  
## it does nothing except sets the session using the hook 'before' above. 

post '/handshake' => sub {


	debug "in /handshake";

	setCourseEnvironment(params->{course_id});

	debug session; 
	authenticate();



	return {msg => "If you get this message the handshaking between Dancer and WW2 worked."};
};


post '/courses/:course_id/login' => sub {

	# setCourseEnvironment(params->{course_id});

	my $authen = new WeBWorK::Authen(vars->{ce});
	$authen->set_params({
		user => params->{user},
		password => params->{password},
		key => params->{session_key}
		});

	my $result = $authen->verify();

	my $out = {};

	if($result){
		my $key = $authen->create_session(params->{user});
		
		session user => params->{user};
		session key => $key;

		my $permission = vars->{db}->getPermissionLevel(session->{user});
		session permission => $permission->{permission};		

		return {session_key=>$key, user=>params->{user},logged_in=>1};

	} else {
		return {logged_in=>0};
	} 
};


post '/courses/:course_id/logout' => sub {
	my $deleteKey = vars->{db}->deleteKey(session 'user');
	my $sessionDestroy = session->destroy;
	return {logged_in=>0};
};


get '/app-info' => sub {
	return {
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

#sub getCourseEnvironment {
#	my $courseID = shift;
#
#	  return WeBWorK::CourseEnvironment->new({
#	 	webwork_url         => "/Volumes/WW_test/opt/webwork/webwork2",
#	 	webwork_dir         => "/Volumes/WW_test/opt/webwork/webwork2",
#	 	pg_dir              => "/Volumes/WW_test/opt/webwork/pg",
#	 	webwork_htdocs_url  => "/Volumes/WW_test/opt/webwork/webwork2_files",
#	 	webwork_htdocs_dir  => "/Volumes/WW_test/opt/webwork/webwork2/htdocs",
#	 	webwork_courses_url => "/Volumes/WW_test/opt/webwork/webwork2_course_files",
#	 	webwork_courses_dir => "/Volumes/WW_test/opt/webwork/webwork2/courses",
#	 	courseName          => $courseID,
#	 });
#}


Dancer->dance;
