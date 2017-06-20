### Course routes
##
#  These are the routes for all course related URLs in the RESTful webservice
#
##

package Routes::Admin;
use Dancer2 appname => "Routes::Login";
use Dancer2::Plugin::Auth::Extensible;

use Dancer2::FileUtils qw /read_file_content/;
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;
use WeBWorK::Utils::CourseManagement qw(listCourses listArchivedCourses addCourse deleteCourse renameCourse);
use WeBWorK::Utils::CourseIntegrityCheck qw(checkCourseTables);
use Utils::CourseUtils qw/getAllUsers getCourseSettings getAllSets/;
use Data::Dump qw/dump/;


###
#
#  list the names of all courses.
#
#  returns an array of course names.
#
###

get '/courses' => sub {
  my $ce = WeBWorK::CourseEnvironment->new({webwork_dir => config->{webwork_dir},
																								courseName=> "admin"});
	my @courses = listCourses($ce);
	return \@courses;

};




###
#
#  create a new course
#
#  the parameter new_userID must be sent to be an instructor for the course.
#
#  returns the properties of the course
#
###

post '/admin/courses/:new_course_id' => require_role admin => sub {

  #debug 'in POST /courses/:new_course_id';

  my $coursesDir = vars->{ce}->{webworkDirs}->{courses};
	my $courseDir = "$coursesDir/" . params->{new_course_id};

  # need to make another course environment for the new course.

	my $ce2 = new WeBWorK::CourseEnvironment({
	 	webwork_dir => vars->{ce}->{webwork_dir},
		courseName => route_parameters->{new_course_id},
	});

	# return an error if the course already exists

	send_error("The course " . params->{new_course_id} . " directory already exists.",424)
    if (-e $courseDir);

	# check if the databases exist

	my $dbLayoutName = $ce2->{dbLayoutName};
	my $db2 = new WeBWorK::DB($ce2->{dbLayouts}->{$dbLayoutName});

  send_error("The databases for " . params->{new_course_id} . " already exists",424)
    if ($db2->{user}->tableExists);

	# fail if the course ID contains invalid characters

	send_error("Invalid characters in course ID: " . params->{new_course_id} . " (valid characters are [-A-Za-z0-9_])",424)
		unless params->{new_course_id} =~ m/^[-A-Za-z0-9_]*$/;

	# create a new user to be added as an instructor

	send_error("The parameter new_user_id must be defined as an instructor ID for the course",424)
		unless body_parameters->{new_user_id};

	my $instrFirstName = body_parameters->{new_user_first_name} || "First";
	my $instrLastName = body_parameters->{new_user_last_name} || "Last";
	my $instrEmail = body_parameters->{new_user_email} || "email\@localhost";
	my $add_initial_password = body_parameters->{initial_password} || params->{new_userID};

	my @users = ();

	my $User = vars->{db}->newUser(
		user_id       => body_parameters->{new_user_id},
		first_name    => $instrFirstName,
		last_name     => $instrLastName,
		student_id    => body_parameters->{new_user_id},
		email_address => $instrEmail,
		status        => "C",
	);
	my $Password = vars->{db}->newPassword(
		user_id  => body_parameters->{new_user_id},
		password => cryptPassword($add_initial_password),
	);


    # set the permission level
	my $PermissionLevel = vars->{db}->newPermissionLevel(
		user_id    => body_parameters->{new_user_id},
		permission => "10",
	);

	push @users, [ $User, $Password, $PermissionLevel ];

	my %courseOptions = ( dbLayoutName => "sql_single" );

	my $options = {
    courseID => route_parameters->{new_course_id},
    ce=>$ce2,
    courseOptions=>\%courseOptions,
		dbOptions=> body_parameters->{db_options},
    users=>\@users
  };


	addCourse(%{$options});

	return {course_id => body_parameters->{new_course_id}, message => "Course created successfully."};

};


get '/admin/courses/:course_id' => require_role admin => sub {

  debug "in /admin/courses/:course_id";
  my $coursePath = path(config->{webwork_dir},route_parameters->{course_id});
  if (! -e $coursePath){
    return {course_id => route_parameters->{course_id}, message=> "Course does not exist.",
      course_exists=> false};
  }
  my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(vars->{ce});

  if (body_parameters->{checkCourseTables}){
    my ($tables_ok,$dbStatus) = $CIchecker->checkCourseTables(params->{course_id});
    return { coursePath => $coursePath, tables_ok => $tables_ok, dbStatus => $dbStatus,
                      message => "Course exists."};
  } else {
    return {course_id => route_parameters->{course_id}, message=> "Course exists.", course_exists=> true};
  }
};

### update the course course_id
###
### currently just renames the course


put '/admin/courses/:course_id' => require_role admin => sub {

  my $ce2 = new WeBWorK::CourseEnvironment({
	 	webwork_dir => vars->{ce}->{webwork_dir},
		courseName => params->{course_id},
	});

	my %courseOptions = ( dbLayoutName => "sql_single" );

  my $options = {
      courseID => route_parameters->{course_id},
      newCourseID => body_parameters->{new_course_id},
			ce=>$ce2,
      courseOptions=>\%courseOptions,
      skipDBRename=> body_parameters->{skipDBRename} || false,
			dbOptions=> body_parameters->{db_options}
  };


	my $renameCourse = renameCourse(%{$options});

	return $renameCourse;
};


### delete the course course_id

del '/admin/courses/:course_id' => require_role admin => sub {

  my $ce2 = new WeBWorK::CourseEnvironment({
	 	webwork_dir => vars->{ce}->{webwork_dir},
		courseName => params->{course_id},
	});


	my %courseOptions = ( dbLayoutName => "sql_single" );

	my $options = {
    courseID => route_parameters->{course_id},
    ce=>$ce2,
    courseOptions=>\%courseOptions,
		dbOptions=> body_parameters->{db_options}};

	deleteCourse(%{$options});

	return {course_id => route_parameters->{course_id}, message => "Course deleted."};

};

##
#
# get the current session
#
##

get '/courses/:course_id/session' => sub {
	return convertObjectToHash(session);
};

post '/courses/:course_id/session' => sub {
	session 'effectiveUser' => params->{effectiveUser};
	return convertObjectToHash(session);
};



###
#
#  list the names of all archived courses.
#
#  returns an array of course names.
#
###


get '/admin/courses/archives' => sub {

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
