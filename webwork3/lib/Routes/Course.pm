### Course routes
##
#  These are the routes for all course related URLs in the RESTful webservice
#
##

package Routes::Course;

use strict;
use warnings;
use Dancer ':syntax';
use Dancer::Plugin::Ajax; 
use Dancer::FileUtils qw /read_file_content path/;
use Utils::Convert qw/convertObjectToHash convertArrayOfObjectsToHash/;
use WeBWorK::Utils::CourseManagement qw(listCourses listArchivedCourses addCourse deleteCourse renameCourse);
use WeBWorK::Utils::CourseIntegrityCheck qw(checkCourseTables);
use Utils::CourseUtils qw/getAllUsers getCourseSettings getAllSets/;
# use Utils::CourseUtils qw/getCourseSettings/;
use Routes::Authentication qw/buildSession checkPermissions/;
use Data::Dumper;


our $PERMISSION_ERROR = "You don't have the necessary permissions.";


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

	# template 'course_home.tt', {course_id=>params->{course_id}};
	if(request->is_ajax){
			

		my $ce2 = new WeBWorK::CourseEnvironment({
		 	webwork_dir         => vars->{ce}->{webwork_dir},
			courseName => params->{course_id},
		});

		my $coursePath = vars->{ce}->{webworkDirs}->{courses} . "/" . params->{course_id};

		if (! -e $coursePath) {
			return {};
		}


		my ($tables_ok,$dbStatus);
	    my $CIchecker = new WeBWorK::Utils::CourseIntegrityCheck(ce=>$ce2);
	    if (params->{checkCourseTables}){
			($tables_ok,$dbStatus) = $CIchecker->checkCourseTables(params->{course_id});
		}
		
		return {
			coursePath => $coursePath,
			tables_ok => $tables_ok,
			dbStatus => $dbStatus

		};
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

	if(session->{permission} < 15){send_error($PERMISSION_ERROR,403)}


    my $coursesDir = vars->{ce}->{webworkDirs}->{courses};
	my $courseDir = "$coursesDir/" . params->{new_course_id};

	##  This is a hack to get a new CourseEnviromnet.  Use of %WeBWorK::SeedCE doesn't work. 

	my $ce2 = new WeBWorK::CourseEnvironment({
	 	webwork_dir         => vars->{ce}->{webwork_dir},
		courseName => params->{course_id},
	});


	# return an error if the course already exists

	if (-e $courseDir) {
		return {error=>"The course " . params->{new_course_id} . " directory already exists."};
	}

	# check if the databases exist

	my $dbLayoutName = $ce2->{dbLayoutName};
	my $db2 = new WeBWorK::DB($ce2->{dbLayouts}->{$dbLayoutName});

	# for my $table (keys %$db2)
	# {
	# 	my $tableName = $db2->{$table};
	# 	my $database_table_exists = ($db2->{$table}->tableExists) ? 1:0;
	# 	debug "$table : $database_table_exists \n";
	# } 

	## what's a good way to tell if the database already exists?

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


	my $addCourse = addCourse(%{$options});

	return $addCourse;

};

### update the course course_id
###
### currently just renames the course

put '/courses/:course_id' => sub {

	if(session->{permission} < 15){send_error($PERMISSION_ERROR,403)}

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

	if(session->{permission} < 15){send_error($PERMISSION_ERROR,403)}

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
 

get '/courses/:course_id/manager' =>  sub {

	# read the course manager configuration file

	my $configFilePath = path(config->{webwork_dir},"webwork3","public","js","apps","CourseManager","config.json");
	my $fileContents = read_file_content($configFilePath);
	my $config = from_json($fileContents);

	my @main_view_paths = map {$_->{path}} @{$config->{main_views}};
	my @sidepane_paths = map {$_->{path}} @{$config->{sidepanes}};

	my @view_paths = (@main_view_paths,@sidepane_paths);

	my $userID = "";
	my $sessKey = "";
	my $ts = "";
	my $cookies = Dancer::Cookies->cookies;
	my $cookieName = "WeBWorKCourseAuthen." . params->{course_id};
	my $courseCookie = $cookies->{$cookieName};
	my $cookieValue = $courseCookie->value;

	($userID,$sessKey,$ts) = split(/\t/,$cookieValue) if defined($cookieValue);

	$userID = params->{user} if defined(params->{user});
	$sessKey = params->{key} if defined(params->{key});

	## check if the user passed in via the URL is the same as the session user.

	if(session 'user'){
		if (session->{user} && $userID ne session->{user}) {
			my $key = vars->{db}->getKey(session 'user');
			vars->{db}->deleteKey(session 'user') if $key;
			session->destroy; 
		}
	} else {
		session 'user' => $userID;
	}

	# a few situations here.  Either
	# 1) no userID exists 
	# 2) the user passed via the URL is not a member of the course
	# 3) the user passed via the URL is not authorized for the manager. 
	# 4) the user has already logged in and its safe to send all of the requisite data
	# 5) the user hasn't already logged in and needs to pop open a login window.  

	
	#case 1)

	if(! defined($userID)){
		redirect  vars->{ce}->{server_root_url} .'/webwork2/';
		return;
	}

	# case 2) 
	if(! vars->{db}->existsUser($userID)){
		redirect  vars->{ce}->{server_root_url} .'/webwork2/';
		return "user not enrolled in the course";
	}
	
	# case 3)
	
	my $permission = vars->{db}->getPermissionLevel($userID);

    if ($permission->{permission} < 10){
    	redirect  vars->{ce}->{server_root_url} .'/webwork2/';
		return;	
    }

	# case 5) 
	my $settings = [];
	my $sets = [];
	my $users = [];


	# case 4) 
	if(defined session->{user}){
		buildSession($userID,$sessKey);
		if(session 'logged_in'){
			$settings = getCourseSettings();
			$sets = getAllSets();
			$users = getAllUsers();
		}
	} 

	my $theSession = convertObjectToHash(session);
	$theSession->{effectiveUser} = session->{user};

	# set the ww2 style cookie to save session info for work in both ww2 and ww3.  

	cookie $cookieName => "$userID\t". (session 'key') . "\t" . (session 'timestamp');

	template 'course_manager.tt', {course_id=> params->{course_id},theSession=>to_json(convertObjectToHash(session)),
		theSettings=>to_json($settings), sets=>to_json($sets), users=>to_json($users), main_view_paths => to_json(\@view_paths),
		main_views=>to_json($config),pagename=>"Course Manager"},
		{layout=>'manager.tt'};
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