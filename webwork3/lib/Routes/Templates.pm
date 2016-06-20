## This contains all of the html templates for the app
package Routes::Templates;

use Dancer2; 
use Dancer2::FileUtils qw/path read_file_content/;
 
use Utils::Authentication; # qw/setCourseEnvironment buildSession/; 
use Utils::Convert qw/convertObjectToHash/;
use Utils::CourseUtils qw/getCourseSettings getAllSets getAllUsers/;

use Data::Dump qw/dump/;

use Routes::Login; 

# This sets that if there is a template in the view direction a route is automatically generated. 

set auto_page => 0;




any ['get','put','post','delete'] => '/courses/*/**' => sub {
	my ($courseID) = splat;
    
    Utils::Authentication::setCourseEnvironment($courseID);
    pass;
};

get '/' => sub {

  return "Placeholder for toplevel"; 
}; 

get '/courses/:course_id/manager' =>  sub {


	# read the course manager configuration file to set up the main and side panes

	my $configFilePath = path(config->{webwork_dir},"webwork3","public","js","apps","CourseManager","config.json");
	my $fileContents = read_file_content($configFilePath);
    my $config = from_json($fileContents);

	my @main_view_paths = map {$_->{path}} @{$config->{main_views}};
	my @sidepane_paths = map {$_->{path}} @{$config->{sidebars}};

	my @view_paths = (@main_view_paths,@sidepane_paths);

	# a few situations here.  Either
	# 1) the user is logged in and info stored as a cookie
	# 2) the user is logged in and info stored on the URL
	# 3) the user passed via the URL is not a member of the course
	# 4) the user passed via the URL is not authorized for the manager. 
    # 5) the user hasn't already logged in and needs to pop open a login window.  
	# 6) the user has already logged in and its safe to send all of the requisite data
	# 



	my $userID = "";
	my $sessKey = "";
	my $ts = "";
	my $cookieValue = cookie "WeBWorK.CourseAuthen." . params->{course_id};
    
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

	if(session 'user'){
		if (session->{user} && $userID ne session->{user}) {
			my $key = vars->{db}->getKey(session 'user');
			vars->{db}->deleteKey(session 'user') if $key;
			app->destroy_session; 
		}
	} elsif ($userID ne '') {
		session 'user' => $userID;
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

	# case 5) 
	my $settings = [];
	my $sets = [];
	my $users = []; 

	# case 6) 
	if(session 'user') {

		Utils::Authentication::buildSession($userID,$sessKey);
		if(session 'logged_in'){
			$settings = getCourseSettings(vars->{ce});
			$sets = getAllSets(vars->{db},vars->{ce});
			$users = getAllUsers(vars->{db},vars->{ce});
		} else {
            
			app->destroy_session;
		}
	}

	my $theSession = convertObjectToHash(session);
	$theSession->{effectiveUser} = session->{user};
    
    debug $theSession; 

	# set the ww2 style cookie to save session info for work in both ww2 and ww3.  

	if(session && session 'user'){
		Utils::Authentication::setCookie();	
	}
	
	template 'course_manager.tt', {course_id=> params->{course_id},theSession=>to_json(convertObjectToHash(session)),
		theSettings=>to_json($settings), sets=>to_json($sets), users=>to_json($users), main_view_paths => to_json(\@view_paths),
		main_views=>to_json($config),pagename=>"Course Manager"},
		{layout=>'manager.tt'};
};


true;
