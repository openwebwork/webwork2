package WeBWorK::Authen;

sub new($$$) {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	($self->{r}, $self->{courseEnvironment}) = @_;
	bless $self, $class;
	return $self;
}

# verify will return 1 if the person is who they say the are.
# If the verification failed because of of invalid authentication data,
# a note will be written in the request explaining why it failed.
# If the request failed because no authentication data was provided, however,
# no note will be written, as this is expected to happen whenever someone
# types in a URL manually, and is not considered an error condition.
sub verify($) {
	# Definition: "magic data": passwd or key
	my $self = shift;
	my $r = $self->{r};
	
	my $user = $r->param('user');
	my $passwd = $r->param('passwd');
	my $key = $r->param('key');
	
	# Get this out of the way first thing.  We don't want anything else
	# having access to this.  It's bad enough that it goes over the wire
	# plaintext.
	$r->param('passwd',undef);
	
	my $return, $error;
	
	# The first part of this big conditional checks to make that we have
	# all of the form info that we need. It's pretty boring.  The kooky
	# authen stuff comes after that.
	if (!defined $user && !defined $passwd && !defined $key) {
		# The user hasn't even had a chance to say who he is, so we
		# can't hold it against him that we don't know.
		undef $error;
		$return = 0;
	} elsif (!$user) {
		$error = "You must specify a username";
		$return = 0;
	} elsif (!$passwd && !$key) {
		$error = "You must enter a password";
		$return = 0;
	}
	# OK, we're done with the trivia.  Now lets authenticate.
	# This is the part that will get rewritten after Sam finishes
	# his work on the database stuff.
	elsif ($user ne "dennis") {
		$error = "Unknown user";
		$return = 0;
	} elsif ($passwd) {
		if ($passwd eq "helloworld") {
			$r->param('key','tH1siS@pH0n3Yk3y');
			$return = 1;
		} else {
			$error = "Incorrect password";
			$return = 0;
		}
	} elsif ($key) {
		if ($key eq 'tH1siS@pH0n3Yk3y') {
			$return = 1;
		} else {
			$error = "Your session has expired.  You must re-login";
			$return = 0;
		}
	} else {
		$error = "Unexpected authentication error!";
		$return = 0;
	}

		
	$r->notes("authen_error",$error);
	return $return;
	
	# Whatever you do, don't delete this!
	critical($r);
}

1;
