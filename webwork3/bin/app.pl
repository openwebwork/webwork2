#!/usr/bin/env perl
use Dancer;
use Dancer::Plugin::Database;
use webwork3;
use WeBWorK::DB;
use WeBWorK::CourseEnvironment;
use Routes::Course;
use Routes::User;

set serializer => 'JSON';

hook 'before' => sub {

	my @session_key = database->quick_select(param('course').'_key', { user_id => param('user') });

	if ($session_key[0]->{key_not_a_keyword} eq param('session_key')) {
		session 'logged_in' => true;
	} else {
		debug "Wrong session_key";
	}

	debug localtime;

	## need to check that the session hasn't expired. 

	my @permission = database->quick_select(param('course').'_permission', {user_id => param('user')});

	session 'permission' => $permission[0]->{permission};

	var ce => getCourseEnvironment(params->{course});
	var db => new WeBWorK::DB(vars->{ce}->{dbLayout});


};



post '/hello/:name' => sub {
    # do something
 
    debug "in /hello/:name";
    debug session 'logged_in';
    debug session 'permission';

 	my $out = {
 		text =>    "Hello ".param('name'),
 		other => param('user')
 	};

    return $out;

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
