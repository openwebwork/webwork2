#!/usr/bin/env perl

package WeBWorK3;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Data::Dump qw/dd/; 
use Path::Class;
use File::Find::Rule;

set serializer => 'JSON';


# link to WeBWorK code libraries
use lib config->{webwork_dir}.'/lib';
use lib config->{pg_dir}.'/lib';

use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK3::Authen;
#
### note: Routes::Authenication must be passed first
use Utils::Authentication qw/buildSession setCourseEnvironment setCookie/; 
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;
use Utils::LibraryUtils qw//;
use Utils::ProblemSets qw/record_results/;
use WeBWorK::DB::Utils qw(global2user);
use WeBWorK::Utils::Tasks qw(fake_user fake_set fake_problem);
use WeBWorK::PG::Local;
use WeBWorK::Constants;

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



load 'Routes/Course.pm';
load 'Routes/Library.pm';
load 'Routes/ProblemSets.pm';
load 'Routes/User.pm';
load 'Routes/Settings.pm';
load 'Routes/PastAnswers.pm';






#
#hook 'before' => sub {
#
#     for my $key (keys(%{request->params})){
#     	my $value = defined(params->{$key}) ? params->{$key} : ''; 
#     	debug($key . " : " . to_dumper($value));
#     } 
#
#};


post '/courses/:course_id/login' => sub {

	my $authen = new WeBWorK3::Authen(vars->{ce});
    
	$authen->set_params({
			user => params->{user},
			password => params->{password},
			key => params->{session_key}
		});
        
	my $result = $authen->verify();
	if($result){
		my $key = $authen->create_session(params->{user});
		
		session user => params->{user};
		session key => $key;

		my $permission = vars->{db}->getPermissionLevel(session->{user});
		session permission => $permission->{permission};
		session timestamp => time();

		setCookie();

		return {session_key=>$key, user=>params->{user},logged_in=>1};

	} else {
		return {logged_in=>0};
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
