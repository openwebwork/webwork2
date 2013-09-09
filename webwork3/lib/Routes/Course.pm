### Course routes
##
#  These are the routes for all course related URLs in the RESTful webservice
#
##

package Routes::Course;

use strict;
use warnings;
use Dancer ':syntax';
use Routes qw/convertObjectToHash/;
use WeBWorK::Utils::CourseManagement qw(listCourses listArchivedCourses addCourse deleteCourse renameCourse);
use WeBWorK::Utils::CourseIntegrityCheck qw(checkCourseTables);
###
#
#  list the names of all courses.  
#
#  returns an array of course names.
#
###
 

get '/courses' => sub {

	my @courses = listCourses(vars->{ce});

	return \@courses;

};

###
#
#  Get the properties of the course *course_id*
#
#  Permission >= Instructor
#
#  set checkCourseTables to 1 to check the course database and directory status
#
#  Returns properties of the course including the status of the course directory and databases.
#
###


get '/courses/:course_id' => sub {



	my $ce2 = new WeBWorK::CourseEnvironment({
		webwork_url         => vars->{ce}->{webwork_url},
	 	webwork_dir         => vars->{ce}->{webwork_dir},
	 	pg_dir              => vars->{ce}->{pg_dir},
	 	webwork_htdocs_url  => vars->{ce}->{webwork_htdocs_url},
	 	webwork_htdocs_dir  => vars->{ce}->{webwork_htdocs_dir},
	 	webwork_courses_url => vars->{ce}->{webwork_courses_url},
	 	webwork_courses_dir => vars->{ce}->{webwork_courses_dir},
		courseName => params->{course_id},
	});


	my ($tables_ok,$dbStatus);
    my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce=>$ce2);
    if (params->{checkCourseTables}){
		($tables_ok,$dbStatus) = $CIchecker->checkCourseTables(params->{course_id});
	}
	
	debug 'after checker';
	debug $tables_ok;
	debug $dbStatus;
	

	return {
		coursePath => vars->{ce}->{webworkDirs}->{courses} . "/" . params->{course_id},
		tables_ok => $tables_ok,
		dbStatus => $dbStatus

	};


};

###
#
#  create a new course
#
#  returns the properties of the course
#
###

post '/courses/:new_course_id' => sub {


    if (0+(session 'permission') <10) {
        return {error=>"You don't have the necessary permission"};
    }

    my $coursesDir = vars->{ce}->{webworkDirs}->{courses};
	my $courseDir = "$coursesDir/" . params->{new_course_id};

	##  This is a hack to get a new CourseEnviromnet.  Use of %WeBWorK::SeedCE doesn't work. 

	my $ce2 = new WeBWorK::CourseEnvironment({
		webwork_url         => vars->{ce}->{webwork_url},
	 	webwork_dir         => vars->{ce}->{webwork_dir},
	 	pg_dir              => vars->{ce}->{pg_dir},
	 	webwork_htdocs_url  => vars->{ce}->{webwork_htdocs_url},
	 	webwork_htdocs_dir  => vars->{ce}->{webwork_htdocs_dir},
	 	webwork_courses_url => vars->{ce}->{webwork_courses_url},
	 	webwork_courses_dir => vars->{ce}->{webwork_courses_dir},
		courseName => params->{new_course_id},
	});


	# return an error if the course already exists

	if (-e $courseDir) {
		return {error=>"The course " . params->{new_course_id} . " already exists."};
	}

	# fail if the course ID contains invalid characters

	return {error=> "Invalid characters in course ID: " . params->{new_course_id} . " (valid characters are [-A-Za-z0-9_])"}
		unless params->{new_course_id} =~ m/^[-A-Za-z0-9_]*$/;

	# create a new user to be added as an instructor

	return {error=>"The parameter new_userID must be defined as an instructor ID for the course"} 
		unless params->{new_userID};

	my $instrFirstName = params->{new_user_firstName} ? params->{new_user_firstName} : "First";
	my $instrLastName = params->{new_user_lastName} ? params->{new_user_lastName} : "Last";
	my $instrEmail = params->{new_user_email} ? params->{new_user_email} : "email\@localhost";
	my $add_initial_password = params->{initial_password} ? params->{initial_password} : params->{new_userID};

	my @users = ();

	my $User = vars->{db}->newUser(
		user_id       => params->{new_userID},
		first_name    => $instrFirstName,
		last_name     => $instrLastName,
		student_id    => params->{new_userID},
		email_address => $instrEmail,
		status        => "C",
	);
	my $Password = vars->{db}->newPassword(
		user_id  => params->{new_userID},
		password => cryptPassword($add_initial_password),
	);
	my $PermissionLevel = vars->{db}->newPermissionLevel(
		user_id    => params->{new_userID},
		permission => "10",
	);
	push @users, [ $User, $Password, $PermissionLevel ];

	my %courseOptions = ( dbLayoutName => "sql_single" );

	my $options = { courseID => params->{new_course_id}, ce=>$ce2, courseOptions=>\%courseOptions,
					dbOptions=> params->{db_options}, users=>\@users};


	my $addCourse = addCourse(%{$options});

	return $addCourse;

};

### update the course course_id
###
### currently just renames the course

put '/courses/:course_id' => sub {

    if (0+(session 'permission') <10) {
        return {error=>"You don't have the necessary permission"};
    }

	##  This is a hack to get a new CourseEnviromnet.  Use of %WeBWorK::SeedCE doesn't work. 

	my $ce2 = new WeBWorK::CourseEnvironment({
		webwork_url         => vars->{ce}->{webwork_url},
	 	webwork_dir         => vars->{ce}->{webwork_dir},
	 	pg_dir              => vars->{ce}->{pg_dir},
	 	webwork_htdocs_url  => vars->{ce}->{webwork_htdocs_url},
	 	webwork_htdocs_dir  => vars->{ce}->{webwork_htdocs_dir},
	 	webwork_courses_url => vars->{ce}->{webwork_courses_url},
	 	webwork_courses_dir => vars->{ce}->{webwork_courses_dir},
		courseName => params->{new_course_id},
	});

	my %courseOptions = ( dbLayoutName => "sql_single" );


	my $options = { courseID => params->{course_id}, newCourseID => params->{new_course_id},
					ce=>$ce2, courseOptions=>\%courseOptions, skipDBRename=> params->{skipDBRename},
					dbOptions=> params->{db_options}};


	my $renameCourse = renameCourse(%{$options});

	return $renameCourse;
};


### delete the course course_id

del '/courses/:course_id' => sub {

    if (0+(session 'permission') <10) {
        return {error=>"You don't have the necessary permission"};
    }

 #    my $coursesDir = vars->{ce}->{webworkDirs}->{courses};
	# my $courseDir = "$coursesDir/" . params->{course_id};

	##  This is a hack to get a new CourseEnviromnet.  Use of %WeBWorK::SeedCE doesn't work. 

	my $ce2 = new WeBWorK::CourseEnvironment({
		webwork_url         => vars->{ce}->{webwork_url},
	 	webwork_dir         => vars->{ce}->{webwork_dir},
	 	pg_dir              => vars->{ce}->{pg_dir},
	 	webwork_htdocs_url  => vars->{ce}->{webwork_htdocs_url},
	 	webwork_htdocs_dir  => vars->{ce}->{webwork_htdocs_dir},
	 	webwork_courses_url => vars->{ce}->{webwork_courses_url},
	 	webwork_courses_dir => vars->{ce}->{webwork_courses_dir},
		courseName => params->{course_id},
	});

	my %courseOptions = ( dbLayoutName => "sql_single" );

	my $options = { courseID => params->{course_id}, ce=>$ce2, courseOptions=>\%courseOptions,
					dbOptions=> params->{db_options}};

	my $delCourse = deleteCourse(%{$options});

	return $delCourse;

};
 


###
#
#  list the names of all archived courses.  
#
#  returns an array of course names.
#
###
 

get '/courses/archives' => sub {

	my @courses = listArchivedCourses(vars->{ce});

	return \@courses;
};



sub cryptPassword($) {
	my ($clearPassword) = @_;
	my $salt = join("", ('.','/','0'..'9','A'..'Z','a'..'z')[rand 64, rand 64]);
	my $cryptPassword = crypt($clearPassword, $salt);
	return $cryptPassword;
}



return 1;