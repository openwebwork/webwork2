## This contains all of the html templates for the app
package Routes::Templates;

use Dancer2;
use Dancer2::FileUtils qw/read_file_content/;
use Dancer2::Plugin::Auth::Extensible;  ## this handles the users and roles.  See the configuration file for setup.

use Utils::Convert qw/convertObjectToHash/;
use Utils::CourseUtils qw/getCourseSettings getAllSets getAllUsers/;
use WeBWorK::Utils::CourseManagement qw/listCourses/;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use Array::Utils qw/array_minus/;
#use Routes::User qw/@boolean_user_props/;

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
  debug session;
  my $url = query_parameters->{return_url};
  $url = request->uri unless defined($url);
  if (! defined($course_id) && $url && $url =~ /\/courses\/(\w+)\/(\w+)/){
    $course_id = $1;
  }


  my $params = {
    top_dir=>config->{top_dir},
    course_id => $course_id
  };

  $params->{msg} = "login_failed" if defined session 'login_failed';
  session->delete('login_failed');

  template 'login.tt', $params, {layout=> 'main'};
}

###
#
# this is called when the user cannot access a given page
#
###

sub permission_denied_page_handler {
  	debug "oops";

  	debug session;
    template 'index';
}

get '/login/denied' => sub {
  debug "in /login/denied";

  debug session;

  template 'index';
};

###
#
# Route that is used to get username/password and redirect to appropriate
# page
#
###

post '/courses/:course_id/login' => sub {

  debug "in post /login";

  ## delete any fields from other users

  session->delete("logged_in_user");
  session->delete("logged_in_user_realm");
  session->delete("logged_in");

  my $username = query_parameters->{username} || body_parameters->{username};
  my $password = query_parameters->{password} || body_parameters->{password};

  debug $username;
  debug $password;
  debug session;


  my ($success, $realm) = authenticate_user($username,$password);

  debug "trying to authenticate";
  debug $success;
  debug session;


  if($success){
    my $key = vars->{db}->getKey($username)->{key};
    session key => $key;
		session logged_in_user => $username;
		session logged_in_user_realm => $realm;
		session logged_in => true;

    if (route_parameters->{course_id} eq 'admin'){
      redirect '/admin';
    }
    if (user_has_role("professor")){
        redirect '/courses/' . route_parameters->{course_id} . '/manager';
    }

    redirect '/courses/' . route_parameters->{course_id};



  } else {
    session login_failed => true;
    redirect '/courses/'. route_parameters->{course_id} . '/login';
  }

};

any ['post','get'] => '/courses/:course_id/logout' => sub {
  app->destroy_session;

  my $params = {
    top_dir => config->{top_dir},
    course_id => route_parameters->{course_id}
  };

  template 'logout.tt', $params , {layout => "main.tt"};
};

get '/courses' => sub {
  my $ce = WeBWorK::CourseEnvironment->new({webwork_dir => config->{webwork_dir},
                                                courseName=> "admin"});
  my @all_courses = listCourses($ce);

  ## remove the "modelCourse" course.

  my @to_remove = qw/modelCourse/;
  my @courses = array_minus(@all_courses,@to_remove);

  template 'course_list.tt', {top_dir => config->{top_dir},courses => \@courses}, {layout=>'main.tt'};
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

  # get information on the logged in user:

  # hack: not sure why this isn't loading from Routes::User;

  my @boolean_user_props = qw/showOldAnswers useMathView/;

  my $user_info = convertObjectToHash(get_user_details(session 'logged_in_user'),
                                      \@boolean_user_props);
  $user_info->{_id} = $user_info->{user_id};
  my $permission = vars->{db}->getPermissionLevel($user_info->{user_id});
  $user_info->{permission} = $permission->{permission};

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
    user_info => to_json($user_info),
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




###
#
# return the main course page (generally a student view).
#
###


get '/courses/:course_id' => sub {

 template 'course_home.tt', {
      course_id=> route_parameters->{course_id},
      user_id=> (session 'logged_in_user'),
      pagename=>"Course Home for " . route_parameters->{course_id},
      theSession=>to_json(convertObjectToHash(session)),
      top_dir => config->{top_dir}
    },
        {layout=>"main.tt"};


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
