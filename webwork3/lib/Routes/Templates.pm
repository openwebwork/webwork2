## This contains all of the html templates for the app
package Routes::Templates;

use Dancer2;
use Dancer2::FileUtils qw/read_file_content/;
use Dancer2::Plugin::Auth::Extensible;  ## this handles the users and roles.  See the configuration file for setup.


#use Utils::Authentication qw/buildSession/;
use Utils::Convert qw/convertObjectToHash/;
use Utils::CourseUtils qw/getCourseSettings getAllSets getAllUsers/;
use Routes::Login qw/setCourseEnvironment setCookie/;

use Data::Dump qw/dump/;

any ['get','put','post','delete'] => '/courses/*/**' => sub {

  my ($courseID) = splat;
  setCourseEnvironment($courseID);
	pass;
};


get '/' => sub {
  return "Placeholder for toplevel";
};

get '/courses/:course_id/login' => sub {
    login_page(route_parameters->{course_id});
};



sub login_page {
  my ($self,$course_id) = @_;

  debug 'in Routes::Templates::login_page';
  my $url = query_parameters->{return_url};
  $url = request->uri unless defined($url);
  debug $url;
  if (! defined($course_id) && $url && $url =~ /\/courses\/(\w+)\/(\w+)/){
    $course_id = $1;
  }
  debug $course_id;



  my $params = {
    top_dir=>config->{top_dir},
    course_id => $course_id
  };

  $params->{msg} = params->{msg} if defined params->{msg};

  template 'login.tt', $params, {layout=> 'main'};
}

post '/courses/:course_id/login' => sub {

  debug "in post /login";
  my $username = query_parameters->{username} || body_parameters->{username};
  my $password = query_parameters->{password} || body_parameters->{password};

  debug $username;
  debug $password;
  debug session;

  #set_course_environment("hi");
  my ($success, $realm) = authenticate_user($username,$password);

  debug "trying to authenticate";
  debug $success;

  if($success){
    var db =>
    my $key = vars->{db}->getKey($username)->{key};
    session key => $key;
		session logged_in_user => $username;
		session logged_in_user_realm => $realm;
		session logged_in => true;

    debug session;

    if (route_parameters->{course_id} eq 'admin'){
      redirect '/admin';
    }


    redirect '/courses/' . route_parameters->{course_id} . '/manager';

  } else {
    redirect '/courses/'. route_parameters->{course_id} . '/login';
    #redirect '/courses/' . route_parameters->{course_id} . '/login',
       {msg => 'login_failed'}, {method => 'GET'};
  }

};

post '/courses/:course_id/logout' => sub {
  app->destroy_session;

  ## what to return or to move to other route?
};

get '/courses/:course_id/hi' => require_login sub {
    #my $user = logged_in_user;
    debug session;
    return "Hi there, Fred"; # $user->{username}";
};


get '/courses/:course_id/manager' =>  require_role professor => sub {

  debug 'in /courses/:course_id/manager';
  debug session;

  #verify_login(route_parameters->{course_id});

	# read the course manager configuration file to set up the main and side panes

	my $configFilePath = path(config->{webwork_dir},"webwork3","public","js","apps","CourseManager","config.json");
	my $fileContents = read_file_content($configFilePath);
  my $config = from_json($fileContents);

	my @main_view_paths = map {$_->{path}} @{$config->{main_views}};
	my @sidepane_paths = map {$_->{path}} @{$config->{sidebars}};

	my @view_paths = (@main_view_paths,@sidepane_paths);

	my $settings = getCourseSettings(vars->{ce});
	my $sets = getAllSets(vars->{db},vars->{ce});
	my $users = getAllUsers(vars->{db},vars->{ce});


	my $session = convertObjectToHash(session->{data});
	$session->{effectiveUser} = session 'logged_in_user';
  $session->{user_id} = session 'logged_in_user';

  my $params = {
    top_dir => config->{top_dir},
    course_id=> params->{course_id},
    theSession=>to_json($session),
  	theSettings=>to_json($settings),
    sets=>to_json($sets),
    users=>to_json($users),
    main_view_paths => to_json(\@view_paths),
  	main_views=>to_json($config),
    pagename=>"Course Manager"
  };


	template 'course_manager.tt', $params,{layout=>'manager.tt'};
};

##
#
#  The main administration page for webwork.
#
#   todo: add a require role of Admin to this
##

get '/admin' => sub {

  my $params = {
    top_dir => config->{top_dir},
    user_id => session 'user_id',
    course_id => 'admin'
  };

  template 'admin.tt', $params, {layout => 'main.tt'};

};

####
#
#  The following subroutine checks multiple ways that the user is logged in
#
#  Either
# 1) the user is logged in and info stored as a cookie
# 2) the user is logged in and info stored on the URL
# 3) the user passed via the URL is not a member of the course
# 4) the user passed via the URL is not authorized for the manager.
# 5) the user hasn't already logged in and needs to pop open a login window.
# 6) the user has already logged in and its safe to send all of the requisite data
#


sub verify_login {

  my $course_id = shift ;


  my $userID = "";
  my $sessKey = "";
  my $ts = "";
  my $cookieValue = cookie "WeBWorK.CourseAuthen." . $course_id;

  # case 1)
  ($userID,$sessKey,$ts) = split(/\t/,$cookieValue) if defined($cookieValue);

  debug "case 1";
    # case 2)
  if(! defined($cookieValue)){
    $userID = params->{user} if defined(params->{user});
    $sessKey = params->{key} if defined(params->{key});
  }

  debug "case 2";

  # check if the cookie user/key pair matches the params user/key pair
  #
  #    if not, set params to make sure that the login screen is popped open

  if(defined($cookieValue) && defined(params->{user}) && defined(params->{key})){
    if($userID ne params->{user} || $sessKey ne params->{key}){
      app->destroy_session;
      $userID = '';
      $sessKey = '';
    }
  }

  debug "case 3";

  ## check if the user passed in via the URL is the same as the session user.

  if(session 'user_id'){
    if (session->{user} && $userID ne session->{user}) {
      my $key = vars->{db}->getKey(session 'user');
      vars->{db}->deleteKey(session 'user') if $key;
      app->destroy_session;
    }
  } elsif ($userID ne '') {
    session 'user_id' => $userID;
  } else {
    app->destroy_session;
  }

  #debug "case 4";
    # case 4)



  if($userID ne "" && ! vars->{db}->existsUser($userID)){
      app->destroy_session;
    $userID = '';
    $sessKey = '';
  }


  # case 2)

    if ($userID ne "" && vars->{db}->getPermissionLevel($userID)->{permission} < 10){


      redirect  vars->{ce}->{server_root_url} .'/webwork2/' . params->{course_id};
    return "You don't have access to this page.";
    }

}

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

####
#
#  get /courses/:course_id/pgeditor
#
#  returns the html for the simple pg editor
#
###

get '/courses/:course_id/pgeditor' => sub {

    template 'simple-editor.tt', {course_id=> params->{course_id},theSetting => to_json(getCourseSettings),
        pagename=>"Simple Editor",user=>session->{user}};
};

sub setCourseEnvironment {
	my ($course_id) = @_;

	#debug "in setCourseEnvironment";
	#debug session;
	session course_id => $course_id if defined($course_id);

	send_error("The course has not been defined.  You may need to authenticate again",401)
		unless (defined(session 'course_id'));

	$WeBWorK::Constants::WEBWORK_DIRECTORY = config->{webwork_dir};
	$WeBWorK::Debug::Logfile = config->{webwork_dir} . "/logs/debug.log";

	var ce => WeBWorK::CourseEnvironment->new({webwork_dir => config->{webwork_dir},
																								courseName=> $course_id});
	var db => new WeBWorK::DB(vars->{ce}->{dbLayout});

	if (! session 'logged_in'){
		# debug "checking ww2 cookie";

		 my $cookieValue = cookie "WeBWorK.CourseAuthen." . $course_id;

		 my ($user_id,$session_key,$timestamp) = split(/\t/,$cookieValue) if defined($cookieValue);

		 # get the key from the database;
		 if (defined $user_id){
			 my $key = vars->{db}->getKey($user_id);

			 if ($key->{key} eq $session_key && $key->{timestamp} == $timestamp){
				session key => $key->{key};
				session logged_in_user => $user_id;
				session logged_in => true;
				session logged_in_user_realm => 'webwork';  # this shouldn't be hard coded.
			 }
		 }
	 }

	 setCookie(session) if (session 'logged_in');
}

###
#
# This sets the cookie in the WW2 style to allow for seamless transfer back and forth.

sub setCookie {
  #debug "in setCookie";
	my $session = shift;
	my $user_id = $session->read("logged_in_user") || "";
	my $key = $session->read("key") || "";
	my $timestamp = $session->read("timestamp") || "";
  my $cookie_value = $user_id . "\t". $key . "\t" . $timestamp;

  my $hostname = vars->{ce}->{server_root_url};
  $hostname =~ s/https?:\/\///;
  my $cookie_name = "WeBWorK.CourseAuthen." . $session->read("course_id");
	my $cookie = Dancer2::Core::Cookie->new(name => $cookie_name, value => $cookie_value);

	if ($hostname eq "localhost" || $hostname eq "127.0.0.1"){
		$cookie->domain($hostname);
	}

}


true;
