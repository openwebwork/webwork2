#!/usr/bin/env perl
use Dancer;
use Dancer::Plugin::Database;
use WeBWorK::DB;
use WeBWorK::CourseEnvironment;
use Routes::Course;
use Routes::Library;
use Routes::ProblemSets;
use Routes::User;
use Routes::ProblemRender;


set serializer => 'JSON';

hook 'before' => sub {

    for my $key (keys(%{request->params})){
    	my $value = defined(params->{$key}) ? params->{$key} : ''; 
    	debug($key . " : " . $value);
    }


	my @session_key = database->quick_select(params->{course}.'_key', { user_id => params->{user} });

	if ($session_key[0]->{key_not_a_keyword} eq param('session_key')) {
		session 'logged_in' => true;
	} else {
		debug "Wrong session_key";
	}

	## need to check that the session hasn't expired. 

	my @permission = database->quick_select(params->{course}.'_permission', { user_id => params->{user} });

	debug \@permission;

	session 'permission' => $permission[0]->{permission};

	var ce => getCourseEnvironment(params->{course});
	var db => new WeBWorK::DB(vars->{ce}->{dbLayout});
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
