#!/usr/bin/env perl
use Dancer;
use Dancer::Plugin::Database;
use WeBWorK::DB;
use WeBWorK::CourseEnvironment;

use Routes::Authentication; ## note: must be passed first
use Routes::Course;
use Routes::Library;
use Routes::ProblemSets;
use Routes::User;
use Routes::Settings;
use Routes::PastAnswers;




set serializer => 'JSON';

hook 'before' => sub {

    for my $key (keys(%{request->params})){
    	my $value = defined(params->{$key}) ? params->{$key} : ''; 
    	debug($key . " : " . $value);
    }

	var ce => WeBWorK::CourseEnvironment->new({webwork_dir => config->{webwork_dir}, courseName=> session->{course}});
	var db => new WeBWorK::DB(vars->{ce}->{dbLayout});

};

## right now, this is to help handshaking between the original webservice and dancer.  
## it does nothing except sets the session using the hook 'before' above. 

get '/login' => sub {
	
	return {msg => "If you get this message the handshaking between Dancer and WW2 worked."};
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

sub getCourseEnvironment {
	my $courseID = shift;

	  return WeBWorK::CourseEnvironment->new({
	 	webwork_url         => "/Volumes/WW_test/opt/webwork/webwork2",
	 	webwork_dir         => "/Volumes/WW_test/opt/webwork/webwork2",
	 	pg_dir              => "/Volumes/WW_test/opt/webwork/pg",
	 	webwork_htdocs_url  => "/Volumes/WW_test/opt/webwork/webwork2_files",
	 	webwork_htdocs_dir  => "/Volumes/WW_test/opt/webwork/webwork2/htdocs",
	 	webwork_courses_url => "/Volumes/WW_test/opt/webwork/webwork2_course_files",
	 	webwork_courses_dir => "/Volumes/WW_test/opt/webwork/webwork2/courses",
	 	courseName          => $courseID,
	 });
}


Dancer->dance;
