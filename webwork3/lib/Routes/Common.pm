use base qw(Exporter);
use v5.10;

our @EXPORT    = ();
our @EXPORT_OK = qw/setCourseEnvironment setCookie checkPermissions/;

our $PERMISSION_ERROR = "You don't have the necessary permissions.";

use WeBWorK::CourseEnvironment;
use WeBWorK::DB;

sub setCourseEnvironment {

	#debug "in setCourseEnvironment";
	my $course = shift;
	$course = session 'course' unless defined($course);

	send_error("The course has not been defined.  You may need to authenticate again",401)
		unless defined($course);
	session course => $course;

	$WeBWorK::Constants::WEBWORK_DIRECTORY = config->{webwork_dir};
	$WeBWorK::Debug::Logfile = config->{webwork_dir} . "/logs/debug.log";

  var ce => WeBWorK::CourseEnvironment->new({webwork_dir => config->{webwork_dir},
                                                courseName=> session 'course'});
  var db => new WeBWorK::DB(vars->{ce}->{dbLayout});
}

###
#
# This sets the cookie in the WW2 style to allow for seamless transfer back and forth.

sub setCookie {
	my $session = shift;
  my $cookie_value = $session->read('user') . "\t". $session->read('key') . "\t" . $session->read('timestamp');

  my $hostname = vars->{ce}->{server_root_url};
  $hostname =~ s/https?:\/\///;
  my $cookie_name = "WeBWorK.CourseAuthen." . $session->read("course");
	my $cookie = Dancer2::Core::Cookie->new(name => $cookie_name, value => $cookie_value);

	if ($hostname eq "localhost" || $hostname eq "127.0.0.1"){
		$cookie->domain($hostname);
	}

}

sub checkPermissions {
	my ($session,$permissionLevel) = shift;

	#buildSession($session->read('user'),$session->read('key'));
	if (! defined($session->read('logged_in')) && ! $session->read('logged_in')){
		send_error('You are no longer logged in.  You may need to reauthenticate.',419);
	}

	if($session->read('permission') < $permissionLevel){send_error($PERMISSION_ERROR,403)}

}

1;
