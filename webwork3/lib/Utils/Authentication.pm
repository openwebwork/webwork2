package Utils::Authentication;
use base qw(Exporter);
use v5.10;

use WeBWorK::CourseEnvironment;
use WeBWork::DB;
use Data::Dump qw/dump/;

our @EXPORT    = ();
our @EXPORT_OK = qw/setCourseEnvironment buildSession checkPermissions setCookie isSessionCurrent/;

our $PERMISSION_ERROR = "You don't have the necessary permissions.";

###
#
# Note: this doesn't seem to work with use Dancer2, so the session needs
# to be passed in.


sub buildSession {
	my ($session,$ce,$db) = @_;


	if(! defined($db)){
		return {error => "The database object DB is not defined.  Make sure that you call setCourseEnvironment first." };
	}

	## need to check that the session hasn't expired.

    if (!defined($session->read('user'))) {
    	if (defined($userID)){
				$session->write('user',$userID);
    	} else {
    		return {error =>"The user is not defined. You may need to authenticate again"};
    	}
	}

	my $key = $db->getKey($session->read('user'));
	my $timeLastLoggedIn = 0;

	if(defined($key)){
		$timeLastLoggedIn = $key->{timestamp};
	} else {
		my $newKey = create_session($session->read('user'),$key,$ce,$db);
		$key = $db->newKey(user_id=>session->read('user'), key=>$newKey);
	}
	$session->write('key',$key->{key});

	if(($session->read('key')) ne $sessKey){
		$session->write('logged_in',0);
		$session->write('timestamp',0);
		return;
	}

	# check to see if the user has timed out
	if(time() - $timeLastLoggedIn > vars->{ce}->{sessionKeyTimeout}){
		$session->write('logged_in',0);
		$session->write('timestamp',0);
		return;
	}

	# update the timestamp in the database so the user isn't logged out prematurely.
	$key->{timestamp} = time();
	$session->write('timestamp',$key->{timestamp});

	$db->putKey($key);

	if (! defined(session->read('permission'))){
		my $permission = vars->{db}->getPermissionLevel($session->('user'));
		$session->write('permission',$permission->{permission});
	}

	$session->write('logged_in',1);

	setCookie();
}

# this checks if the session is current by seeing if course_id, user_id, key is set and the timestamp is within a standard time.

sub isSessionCurrent {
	my ($session,$ce,$db) = @_;
	return "" unless defined($session->read('course'));
	return "" unless defined($session->read('user'));
	return "" unless defined($session->read('key'));
	my $key = vars->{db}->getKey($session->read('user'));
	if(time() - $key->{timestamp} > $ce->{sessionKeyTimeout}){
		$session->write('logged_in',0);
		$session->write('timestamp',0);
		return "";
	} else {
		# update the timestamp in the database so the user isn't logged out prematurely.
		$key->{timestamp} = time();
		$session->write('timestamp',$key->{timestamp});
		$db->putKey($key);
	}
	return 1;
}


sub checkPermissions {
	my ($session,$permissionLevel) = shift;

	buildSession($session->read('user'),$session->read('key'));
	if (! defined($session->read('logged_in')) && ! $session->read('logged_in')){
		send_error('You are no longer logged in.  You may need to reauthenticate.',419);
	}

	if($session->read('permission') < $permissionLevel){send_error($PERMISSION_ERROR,403)}

}

### Note: this was copied from WeBWorK::Authen.pm

# clobbers any existing session for this $userID
# if $newKey is not specified, a random key is generated
# the key is returned
sub create_session {
	my ($userID, $newKey, $ce, $db) = @_;
	my $timestamp = time;
	unless ($newKey) {
		my @chars = @{ $ce->{sessionKeyChars} };
		my $length = $ce->{sessionKeyLength};

		srand;
		$newKey = join ("", @chars[map rand(@chars), 1 .. $length]);
	}

	my $Key = $db->newKey(user_id=>$userID, key=>$newKey, timestamp=>$timestamp);
	# DBFIXME this should be a REPLACE
	eval { $db->deleteKey($userID) };
	$db->addKey($Key);

	#if ($ce -> {session_management_via} eq "session_cookie"),
	#    then the subroutine maybe_send_cookie should send a cookie.

	return $newKey;
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


1;
