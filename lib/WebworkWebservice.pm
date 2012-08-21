#!/user/bin/perl -w

# initialize SOAP interface as well
use WebworkSOAP;
use WebworkSOAP::WSDL;

BEGIN {
    $main::VERSION = "2.4.9";
    use Cwd;
	use WeBWorK::PG::Local;

	use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

###############################################################################
# Configuration -- set to top webwork directory (webwork2) (set in webwork.apache2-config)
# Configuration -- set server name
###############################################################################

    our $webwork_directory = $WeBWorK::Constants::WEBWORK_DIRECTORY; #'/opt/webwork/webwork2';
	print "WebworkWebservice: webwork_directory set to ", $WeBWorK::Constants::WEBWORK_DIRECTORY,
	      " via \$WeBWorK::Constants::WEBWORK_DIRECTORY set in webwork.apache2-config\n";

	$WebworkWebservice::HOST_NAME     = 'localhost'; # Apache->server->server_hostname;
	$WebworkWebservice::HOST_PORT     = '80';        # Apache->server->port;

###############################################################################

	eval "use lib '$webwork_directory/lib'"; die $@ if $@;
	eval "use WeBWorK::CourseEnvironment"; die $@ if $@;
 	my $seed_ce = new WeBWorK::CourseEnvironment({ webwork_dir => $webwork_directory });
 	die "Can't create seed course environment for webwork in $webwork_directory" unless ref($seed_ce);
 	my $webwork_url = $seed_ce->{webwork_url};
 	my $pg_dir = $seed_ce->{pg_dir};
 	eval "use lib '$pg_dir/lib'"; die $@ if $@;
    
	$WebworkWebservice::WW_DIRECTORY = $webwork_directory;
	$WebworkWebservice::PG_DIRECTORY = $pg_dir;
	$WebworkWebservice::SeedCE       = $seed_ce;
	
###############################################################################

	$WebworkWebservice::SITE_PASSWORD      = 'xmluser';     # default password
	$WebworkWebservice::COURSENAME    = 'the-course-should-be-determined-at-run-time';       # default course
	
	

}


use strict;
use warnings;
use WeBWorK::Localize;

our  $UNIT_TESTS_ON    = 0;

# error formatting


###############################################################################
###############################################################################

package WebworkWebservice;



sub pretty_print_rh { 
    shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
	my $rh = shift;
	my $indent = shift || 0;

	my $out = "";
	return $out if $indent>10;
	my $type = ref($rh);

	if (defined($type) and $type) {
		$out .= " type = $type; ";
	} elsif ($rh == undef) {
		$out .= " type = scalar; ";
	}
	if ( ref($rh) =~/HASH/ or "$rh" =~/HASH/ ) {
	    $out .= "{\n";
	    $indent++;
 		foreach my $key (sort keys %{$rh})  {
 			$out .= "  "x$indent."$key => " . pretty_print_rh( $rh->{$key}, $indent ) . "\n";
 		}
 		$indent--;
 		$out .= "\n"."  "x$indent."}\n";

 	} elsif (ref($rh)  =~  /ARRAY/ or "$rh" =~/ARRAY/) {
 	    $out .= " ( ";
 		foreach my $elem ( @{$rh} )  {
 		 	$out .= pretty_print_rh($elem, $indent);
 		
 		}
 		$out .=  " ) \n";
	} elsif ( ref($rh) =~ /SCALAR/ ) {
		$out .= "scalar reference ". ${$rh};
	} elsif ( ref($rh) =~/Base64/ ) {
		$out .= "base64 reference " .$$rh;
	} else {
		$out .=  $rh;
	}
	
	return $out." ";
}


use WebworkWebservice::RenderProblem;
use WebworkWebservice::LibraryActions;
use WebworkWebservice::MathTranslators;
use WebworkWebservice::SetActions;
use WebworkWebservice::CourseActions;

###############################################################################
package WebworkXMLRPC;
use base qw(WebworkWebservice); 
use WeBWorK::Utils qw(runtime_use writeTimingLogEntry);

sub format_hash_ref {
	my $hash = shift;
	my $out_str="";
	my $count =4;
	foreach my $key ( sort keys %$hash) {
		my $value = defined($hash->{$key})? $hash->{$key}:"--";
		$out_str.= " $key=>$value ";
		$count--;
		unless($count) { $out_str.="\n  ";$count =4;}
	}
	$out_str;
}

###########################################################################
#  authentication and authorization
###########################################################################

sub initiate_session {
	my ($invocant, @args) = @_;
	my $class = ref $invocant || $invocant;
	######### trace commands ######
 	    my @caller = caller(1);  # caller data
 	    my $calling_function = $caller[3];
 	    #print STDERR  "\n\nWebworkWebservice.pm ".__LINE__." initiate_session called from $calling_function\n";
    ###############################
	
	my $rh_input     = $args[0];
	# print STDERR "input from the form is ", format_hash_ref($rh_input), "\n";
	
	# obtain input from the hidden fields on the HTML page
	my $user_id      = $rh_input ->{userID};
	my $session_key	 = $rh_input ->{session_key};
	my $courseName   = $rh_input ->{courseID};
	my $password     = $rh_input ->{password};
	my $ce           = $class->create_course_environment($courseName);
	my $db           = new WeBWorK::DB($ce->{dbLayout});
	
	my $language= $ce->{language} || "en";
	my $language_handle = WeBWorK::Localize::getLoc($language) ;

	my $user_authen_module = WeBWorK::Authen::class($ce, "user_module");
    runtime_use $user_authen_module;
    
if ($UNIT_TESTS_ON) {
	print STDERR  "WebworkWebservice.pl ".__LINE__." site_password  is " , $rh_input->{site_password},"\n";
	print STDERR  "WebworkWebservice.pl ".__LINE__." courseID  is " , $rh_input->{courseID},"\n";
	print STDERR  "WebworkWebservice.pl ".__LINE__." userID  is " , $rh_input->{userID},"\n";
	print STDERR  "WebworkWebservice.pl ".__LINE__." session_key  is " , $rh_input->{session_key},"\n";
}    

#   This structure needs to mimic the structure expected by Authen
	my $self = {
		courseName	=>  $courseName,
		user_id		=>  $user_id,
		password    =>  $password,
		session_key =>  $session_key,
		ce          =>  $ce,
		db          =>  $db,
		language_handle => $language_handle,
	};	
	$self = bless $self, $class;
	# need to bless self before it can be used as an argument for the authentication module
	# The authentication module is expecting a WeBWorK::Request object
	# But its only actual requirement is that the method maketext() is defined.
	
	my $authen = $user_authen_module->new($self);
	my $authz  =  WeBWorK::Authz->new($self);
	
	$self->{authen}             = $authen;
	$self->{authz}              = $authz;
	
	 
	if ($UNIT_TESTS_ON) {
 	   print STDERR  "WebworkWebservice.pm ".__LINE__." initiate data:\n  "; 
 	   print STDERR  "class type is ", $class, "\n";
 	   print STDERR  "Self has type ", ref($self), "\n";
 	   print STDERR   "self has data: \n", format_hash_ref($self), "\n";
	}
#   we need to trick some of the methods within the webwork framework 
#   since we are not coming in with a standard apache request
#   FIXME:  can/should we change this????
#
#   We are borrowing tricks from the AuthenWeBWorK.pm module
#
# 	

	# now, here's the problem... WeBWorK::Authen looks at $r->params directly, whereas we
	# need to look at $user and $sent_pw. this is a perfect opportunity for a mixin, i think.
	my $authenOK;
	eval {
		no warnings 'redefine';
		local *WeBWorK::Authen::get_credentials   = \&WebworkXMLRPC::get_credentials;
		local *WeBWorK::Authen::maybe_send_cookie = \&WebworkXMLRPC::noop;
		local *WeBWorK::Authen::maybe_kill_cookie = \&WebworkXMLRPC::noop;
		local *WeBWorK::Authen::set_params        = \&WebworkXMLRPC::noop;
		local *WeBWorK::Authen::write_log_entry   = \&WebworkXMLRPC::noop; # maybe fix this to log interactions FIXME
		$authenOK = $authen->verify;
	} or do {
		if (Exception::Class->caught('WeBWorK::DB::Ex::TableMissing')) {
			# was asked to authenticate into a non-existent course
			die SOAP::Fault
				->faultcode('404')
				->faultstring('Course not found.')
		}
		die "Unknown exception when trying to verify authentication.";
	};
	
	$self->{authenOK}  = $authenOK;
	$self->{authzOK}   = $authz->hasPermissions($user_id, "access_instructor_tools");
	
# Update the credentials -- in particular the session_key may have changed.
 	$self->{session_key} = $authen->{session_key};

 	if ($UNIT_TESTS_ON) {
 		print STDERR  "WebworkWebservice.pm ".__LINE__." authentication for ",$self->{user_id}, " in course ", $self->{courseName}, " is = ", $self->{authenOK},"\n";
     	print STDERR  "WebworkWebservice.pm ".__LINE__."authorization as instructor for ", $self->{user_id}, " is ", $self->{authzOK},"\n"; 
 		print STDERR  "WebworkWebservice.pm ".__LINE__." authentication contains ", format_hash_ref($authen),"\n";
 		print STDERR   "self has new data \n", format_hash_ref($self), "\n";
 	} 
 # Is there a way to transmit a number as well as a message?
 # Could be useful for nandling errors.
 	die "Could not authenticate user $user_id with key $session_key " unless $self->{authenOK};
 	die "User $user_id does not have professor privileges in this course $courseName " unless $self->{authzOK};
 	return $self;
}





###########################################################################
# identify course 
###########################################################################

sub create_course_environment {
	my $self = shift;
	my $courseName = shift;
	my $ce = WeBWorK::CourseEnvironment->new( 
				{webwork_dir		=>		$WebworkWebservice::WW_DIRECTORY, 
				 courseName         =>      $courseName
				 });
	#warn "Unable to find environment for course: |$courseName|" unless ref($ce);
	return ($ce);
}

###########################################################################
# security check -- check that the user is in fact a professor in the course
###########################################################################
sub ce {
	my $self = shift;
	$self->{ce};
}
sub db {
	my $self = shift;
	$self->{db};
}
sub param {    # imitate get behavior of the request object params method
	my $self =shift;
	my $param = shift;
	$self->{$param};
}
sub authz {
	my $self = shift;
	$self->{authz};
}
sub maketext {
	my $self = shift;
	#$self->{language_handle}->maketext(@_);
	&{ $self->{language_handle} }(@_);
}


sub get_credentials {
		my $self = shift;
		# self is an Authen object it contains an object r which is the WebworkXMLRPC object
		# confusing isn't it?
		$self->{user_id}     = $self->{r}->{user_id};
		$self->{session_key} = $self->{r}->{session_key};
		$self->{password}    = $self->{r}->{password}; #"the-pass-word-can-be-provided-via-a-pop-up--call-back";
		$self->{login_type}  = "normal";
		$self->{credential_source} = "params";
		return 1;
}

sub noop {

}
sub check_authorization {
		


}
sub do {   # process and return result
           # make sure that credentials are returned
           # for every call
           # $result -> xmlrpcCall(command, in);
           # $result->{output}->{foo} is defined for foo = courseID userID and session_key
	my $self = shift;
	my $result = shift;
    $result->{session_key}  = $self->{session_key};
    $result->{userID}       = $self->{user_id};
    $result->{courseID}     = $self->{courseName};
	return($result);
}
#  respond to xmlrpc requests
#  Add routines for handling errors if the authentication fails or if the authorization is not appropriate.

sub searchLib {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    #warn "\n incoming request to listLib:  class is ",ref($self) if $UNIT_TESTS_ON ;
  	return $self->do( WebworkWebservice::LibraryActions::searchLib($self, $in) );
}

sub listLib {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    #warn "\n incoming request to listLib:  class is ",ref($self) if $UNIT_TESTS_ON ;
  	return $self->do( WebworkWebservice::LibraryActions::listLib($self, $in) );
}
sub listLibraries {     # returns a list of libraries for the default course
	my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    #warn "incoming request to listLibraries:  class is ",ref($self) if $UNIT_TESTS_ON ;
  	return $self->do( WebworkWebservice::LibraryActions::listLibraries($self, $in) );
}
sub listSets {
  my $class = shift;
  my $in = shift;
  my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::listLocalSets($self));
}
sub listSetProblems {
	my $class = shift;
  	my $in = shift;
  	my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::listLocalSetProblems($self, $in));
}

sub createNewSet{
	my $class = shift;
  	my $in = shift;
  	my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::createNewSet($self, $in));
}

sub reorderProblems{
	my $class = shift;
  	my $in = shift;
  	my $self = $class->initiate_session($in);
   	return $self->do(WebworkWebservice::SetActions::reorderProblems($self, $in));
}

sub addProblem {
	my $class = shift;
  	my $in = shift;
  	my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::addProblem($self, $in));
}

sub deleteProblem{
	my $class = shift;
  	my $in = shift;
  	my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::deleteProblem($self, $in));
}
sub renderProblem {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do( WebworkWebservice::RenderProblem::renderProblem($self,$in) ); 
}
sub readFile {
    my $class = shift;
    my $in   = shift;
    my $self = $class->initiate_session($in);
  	return $self->do( WebworkWebservice::LibraryActions::readFile($self,$in) );
}
sub tex2pdf {
    my $class = shift;
    my $in    = shift;
    my $self  = $class->initiate_session($in);
  	return $self->do( WebworkWebservice::MathTranslators::tex2pdf($self,$in) );
}

# Expecting a hash $in composed of the usual auth credentials
# plus the params specific to this function
#{
#	'userID' => 'admin',	# these are the usual 
#	'password' => 'admin',	# auth credentials
#	'courseID' => 'admin',	# used to initiate a
#	'session_key' => 'key',	# session.
#	"name": "TEST100-100",  # This will be the new course's id
#}
# Note that we log into the admin course to create courses.
sub createCourse {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::create($self, $in));
}

sub listUsers{
    my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::listUsers($self, $in));

}

# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual 
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"firstname": "John", 
#	"lastname": "Smith", 
#	"id": "The Doctor",			# required
#	"email": "doctor@tardis",
#	"studentid": 87492466, 
#	"userpassword": "password",	# defaults to studentid if empty
#								# if studentid also empty, then no password
#	"permission": "professor",	# valid values from %userRoles in defaults.config
#								# defaults to student if empty
#}
# This user will be added to courseID
sub addUser {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::addUser($self, $in));
}

# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual 
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"id": "BFYM942", 
#}
sub dropUser {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::dropUser($self, $in));
}

# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual 
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"id": "BFYM942", 
#}
sub deleteUser {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::deleteUser($self, $in));
}


# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"studentid": 87492466,
#	"firstname": "John",
#	"lastname": "Smith",
#	"id": "The Doctor",			# required
#	"email": "doctor@tardis",
#
#	"permission": "professor",	# valid values from %userRoles in defaults.config
#								# defaults to student if empty
#   status: 'Enrolled, audit, proctor, drop
#   section
#   recitation
#   comment
#}
sub editUser {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do(WebworkWebservice::CourseActions::editUser($self, $in));
}

# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"studentid": 87492466,
#	"new_password": "password"
#}
sub changeUserPassword{
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do(WebworkWebservice::CourseActions::changeUserPassword($self, $in));
}

# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"studentid": 87492466,
#	"effectiveUser": "eUser"
#}



sub sendEmail{
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do(WebworkWebservice::CourseActions::sendEmail($self, $in));
}



# -- SOAP::Lite -- guide.soaplite.com -- Copyright (C) 2001 Paul Kulchenko --
# test responses

sub hi {   shift if UNIVERSAL::isa($_[0] => __PACKAGE__); # grabs class reference                 
  return "hello, world";     
}
sub hello2 { shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
	#print "Receiving request for hello world\n";
	return "Hello world2";
}
sub bye {shift if UNIVERSAL::isa($_[0] => __PACKAGE__);  
	return "goodbye, sad cruel world";
}

sub languages {shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
	return ["Perl", "C", "sh"];   
}                               

sub echo_self {
	my $self = shift;
}

sub echo { 
    return join("|",("begin ", WebworkWebservice::pretty_print_rh(\@_), " end") );
}

sub pretty_print_rh {
	WebworkWebservice::pretty_print_rh(@_);
}


sub tth {shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
	my $in = shift;
	my $tthpath = "/usr/local/bin/tth";
    # $tthpath -L -f5 -r 2>/dev/null " . $inputString;
    return $in;

}




package WWd;

#use lib '/home/gage/webwork/xmlrpc/daemon';
#use WebworkXMLRPC;




############utilities

sub echo { 
    return "WWd package ".join("|",("begin ", WebworkWebservice::pretty_print_rh(\@_), " end") );
}

sub listLib {
    shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
    my $in = shift;
  	return( Webwork::listLib($in) );
}
sub renderProblem {
    shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
    my $in = shift;
  	return( Filter::filterObject( Webwork::renderProblem($in) ) );
}
sub readFile {
    shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
    my $in = shift;
  	return( Webwork::readFile($in) );
}
# sub hello {
# 	shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
# 	print "Receiving request for hello world\n";
# 	return "Hello world?";
# }



package Filter;


sub is_hash_ref {
	my $in =shift;
	my $save_SIG_die_trap = $SIG{__DIE__};
    $SIG{__DIE__} = sub {CORE::die(@_) };
	my $out = eval{  %{   $in  }  };
	$out = ($@ eq '') ? 1 : 0;
	$@='';
	$SIG{__DIE__} = $save_SIG_die_trap;
	$out;
}
sub is_array_ref {
	my $in =shift;
	my $save_SIG_die_trap = $SIG{__DIE__};
    $SIG{__DIE__} = sub {CORE::die(@_) };
	my $out = eval{  @{   $in  }  };
	$out = ($@ eq '') ? 1 : 0;
	$@='';
	$SIG{__DIE__} = $save_SIG_die_trap;
	$out;
}
sub filterObject {

    my $is_hash = 0;
    my $is_array =0;
	my $obj = shift;
	#print "Enter filterObject ", ref($obj), "\n";
	my $type = ref($obj);
	unless ($type) {
		#print "leave filterObject with nothing\n";
		return($obj);
	}


	if ( is_hash_ref($obj)  ) {
	    #print "enter hash ", %{$obj},"\n";
	    my %obj_container= %{$obj};
		foreach my $key (keys %obj_container) {
			$obj_container{$key} = filterObject( $obj_container{$key} );
			#print $key, "  ",  ref($obj_container{$key}),"   ", $obj_container{$key}, "\n";
		}
		#print "leave filterObject with HASH\n";
		return( bless(\%obj_container,'HASH'));
	};



	if ( is_array_ref($obj)  ) {
		#print "enter array ( ", @{$obj}," )\n";
		my @obj_container= @{$obj};
		foreach my $i (0..$#obj_container) {
			$obj_container[$i] = filterObject( $obj_container[$i] );
			#print "\[$i\]  ",  ref($obj_container[$i]),"   ", $obj_container[$i], "\n";
		}
		#print "leave filterObject with ARRAY\n";
		return( bless(\@obj_container,'ARRAY'));
	};
    
}


1;
