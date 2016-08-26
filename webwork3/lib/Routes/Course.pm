### Course routes
##
#  These are the routes for all course related URLs in the RESTful webservice
#
##

package Routes::Course;
use Dancer2;

use Dancer::FileUtils qw /read_file_content path/;
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;
use WeBWorK::Utils::CourseManagement qw(listCourses listArchivedCourses addCourse deleteCourse renameCourse);
use WeBWorK::Utils::CourseIntegrityCheck qw(checkCourseTables);
use Utils::CourseUtils qw/getAllUsers getCourseSettings getAllSets/;
use Utils::Authentication qw/buildSession checkPermissions setCookie setCourseEnvironment/;



our $PERMISSION_ERROR = "You don't have the necessary permissions.";

###
#
#  list the names of all courses.
#
#  returns an array of course names.
#
###

any ['get','put','post','delete'] => '/courses/*/**' => sub {
	my ($courseID) = splat;

  session 'course' => $courseID;
  session 'webwork_dir' => config->{webwork_dir};
  setCourseEnvironment(session);
  pass;
};


get '/courses' => sub {

  setCourseEnvironment(session);
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

	# template 'course_home.tt', {course_id=>params->{course_id}};
	if(request->is_ajax){

        setCourseEnvironment(params->{course_id});

        my $coursePath = path(vars->{ce}->{webworkDirs}->{courses},params->{course_id});

		if (! -e $coursePath) {
			return {course_id => params->{course_id}, message=> "Course doesn't exist", course_exists=> JSON::false};
		}



		my $ce2 = new WeBWorK::CourseEnvironment({
		 	webwork_dir         => vars->{ce}->{webwork_dir},
			courseName => params->{course_id},
		});





		my ($tables_ok,$dbStatus);
	    my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce=>$ce2);
	    if (params->{checkCourseTables}){
			($tables_ok,$dbStatus) = $CIchecker->checkCourseTables(params->{course_id});
            return { coursePath => $coursePath, tables_ok => $tables_ok, dbStatus => $dbStatus,
                        message => "Course exists."};
		} else {
            return {course_id => params->{course_id}, message=> "Course exists.", course_exists=> JSON::true};
        }

	} else {

		my $session = {};
		for my $key (qw/course key permission user/){
			$session->{$key} = session->{$key} if defined(session->{$key});
		}
		$session->{logged_in} = 1 if ($session->{user} && $session->{key});

	    template 'course_home.tt', {course_id=> params->{course_id}, user=> session->{user_id},
	        pagename=>"Course Home for " . params->{course_id},theSession=>to_json($session)},
	        {layout=>"student.tt"};
	}


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

post '/courses/:new_course_id' => sub {

    setCourseEnvironment("admin");  # this will make sure that the user is associated with the admin course.
    checkPermissions(10,session->{user});  ## maybe this should be at 15?  But is admin=15?



    my $coursesDir = vars->{ce}->{webworkDirs}->{courses};
	my $courseDir = "$coursesDir/" . params->{new_course_id};

	##  This is a hack to get a new CourseEnviromnet.  Use of %WeBWorK::SeedCE doesn't work.

	my $ce2 = new WeBWorK::CourseEnvironment({
	 	webwork_dir => vars->{ce}->{webwork_dir},
		courseName => params->{new_course_id},
	});



	# return an error if the course already exists

	if (-e $courseDir) {
		return {error=>"The course " . params->{new_course_id} . " directory already exists."};
	}

	# check if the databases exist

	my $dbLayoutName = $ce2->{dbLayoutName};
	my $db2 = new WeBWorK::DB($ce2->{dbLayouts}->{$dbLayoutName});

	my $userTableExists = ($db2->{user}->tableExists) ? 1: 0;

	if ($userTableExists){
	  	return {error=>"The databases for " . params->{new_course_id} . " already exists"};
	}


	# fail if the course ID contains invalid characters

	send_error("Invalid characters in course ID: " . params->{new_course_id} . " (valid characters are [-A-Za-z0-9_])",424)
		unless params->{new_course_id} =~ m/^[-A-Za-z0-9_]*$/;

	# create a new user to be added as an instructor

	send_error("The parameter new_userID must be defined as an instructor ID for the course",424)
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


	addCourse(%{$options});

	return {courseID => params->{new_course_id}, message => "Course created successfully."};

};

### update the course course_id
###
### currently just renames the course

put '/courses/:course_id' => sub {

setCourseEnvironment("admin");
	checkPermissions(10,session->{user});

	##  This is a hack to get a new CourseEnviromnet.  Use of %WeBWorK::SeedCE doesn't work.

    my $ce2 = new WeBWorK::CourseEnvironment({
	 	webwork_dir => vars->{ce}->{webwork_dir},
		courseName => params->{course_id},
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

	setCourseEnvironment("admin");
	checkPermissions(10,session->{user});

	##  This is a hack to get a new CourseEnviromnet.  Use of %WeBWorK::SeedCE doesn't work.

    my $ce2 = new WeBWorK::CourseEnvironment({
	 	webwork_dir => vars->{ce}->{webwork_dir},
		courseName => params->{course_id},
	});


	my %courseOptions = ( dbLayoutName => "sql_single" );

	my $options = { courseID => params->{course_id}, ce=>$ce2, courseOptions=>\%courseOptions,
					dbOptions=> params->{db_options}};

	deleteCourse(%{$options});

	return {course_id => params->{course_id}, message => "Course deleted."};

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
