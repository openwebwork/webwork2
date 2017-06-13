package Routes::Common;

use base qw(Exporter);
use v5.10;

our @EXPORT    = ();
our @EXPORT_OK = qw/setCookie setCourseEnvironment/;

our $PERMISSION_ERROR = "You don't have the necessary permissions.";

use WeBWorK::CourseEnvironment;
use WeBWorK::DB;

sub setCourseEnvironment {
  my $params = shift;

  my $session = $params->{session};
  my $vars = $params->{vars};
  my $config = $params->{config};
  my $course_id = $params->{course_id};
  #debug "in setCourseEnvironment";
  # debug session;
  # debug $course_id;
  $session->write('course_id',$course_id) if defined($course_id);
  #session course_id => $course_id if defined($course_id);

  ## this will no longer work in a common file.  Put in other file?
  # send_error("The course has not been defined.  You may need to authenticate again",401)
  # 	unless (defined(session 'course_id'));

  $WeBWorK::Constants::WEBWORK_DIRECTORY = $config->{webwork_dir};
  $WeBWorK::Debug::Logfile = $config->{webwork_dir} . "/logs/debug.log";

  $vars->{ce}=WeBWorK::CourseEnvironment->new({webwork_dir => $config->{webwork_dir},
  courseName=> $course_id});
  $vars->{db}=new WeBWorK::DB(vars->{ce}->{dbLayout});

  if (! $session->read('logged_in')){
    # debug "checking ww2 cookie";

    my $cookie = Dancer2::Core::Cookie->new(name => "WeBWorK.CourseAuthen." . $session->read("course_id"));
    my $cookieValue = $cookie->value;

    my ($user_id,$session_key,$timestamp) = split(/\t/,$cookieValue) if defined($cookieValue);

    # get the key from the database;
    if (defined $user_id){
      my $key = vars->{db}->getKey($user_id);

      if ($key->{key} eq $session_key && $key->{timestamp} == $timestamp){
        $session->write("key",$key->{key});
        $session->write("logged_in_user",$user_id);
        $session->write("logged_in",1);
        $session->write("logged_in_user_realm",'webwork');  # this shouldn't be hard coded.
      }
    }
  }

  setCookie($session) if ($session->read('logged_in'));
}
###
#
# This sets the cookie in the WW2 style to allow for seamless transfer back and forth.

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



true
