################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::Authen;

=head1 NAME

WeBWorK::Authen - Check user identity, manage session keys.

=cut

use strict;
use warnings;
use WeBWorK::DB::Auth;

sub new($$$) {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $self = {};
	($self->{r}, $self->{courseEnvironment}) = @_;
	bless $self, $class;
	return $self;
}

sub generate_key {
	# Package constants.  These should never be changed in other places ever
	my $key_length = 40;			# number of chars in each key
	my @key_chars = ('A'..'Z', 'a'..'z', '0'..'9', '.', '^', '/', '!', '*');

	my $i = $key_length;
	my $key = '';
	srand;
	while($i) {
		$key .= $key_chars[rand(@key_chars)];
		$i--;
	}
	return $key;
}

# verify will return 1 if the person is who they say the are.
# If the verification failed because of of invalid authentication data,
# a note will be written in the request explaining why it failed.
# If the request failed because no authentication data was provided, however,
# no note will be written, as this is expected to happen whenever someone
# types in a URL manually, and is not considered an error condition.
sub verify($) {
	my $self = shift;
	my $r = $self->{r};
	my $course_env = $self->{courseEnvironment};
	
	my $user = $r->param('user');
	my $passwd = $r->param('passwd');
	my $key = $r->param('key');
	my $time = time;
	
	# I wanted to get rid of that passwd up here for security reasons,
	# but usability dictates that we not clear out invalid passwords.
	#$r->param('passwd',undef);
	
	my $error;
	my $return;
	
	my $auth = WeBWorK::DB::Auth->new($course_env);
	
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
	elsif ($passwd) {
		# A bit of extra logic for practice users
		# Practice users are different because:
		# - They aren't allowed to log in if an active key exists
		#   (except for $debugPracticeUser)
		# - They are allowed to log in with any password
		my $practiceUserPrefix = $course_env->{"practiceUserPrefix"};
		my $debugPracticeUser = $course_env->{"debugPracticeUser"};
		if ($practiceUserPrefix and $user =~ /^$practiceUserPrefix/) {
			if (!$auth->getPassword($user)) { # the only way DB::Auth provides for checking the existence of a user
				$error = "That practice account does not exist";
				$return = 0;
			} elsif ($auth->getKey($user) and $user ne $debugPracticeUser) {
				$error = "That practice account is in use";
				$return = 0;
			} else {
				$key = generate_key;
				$auth->setKey($user, $key);
				$r->param('key',$key);
				$return = 1;
			}
		}
		# Not a practice user.  Do normal authentication.
		elsif ($auth->verifyPassword($user, $passwd)) {
			# Remove the passwd field from subsequent requests.
			$r->param('passwd',"");
			$key = $auth->getKey($user) || generate_key;
			$auth->setKey($user, $key);
			$r->param('key',$key);
			$return = 1;
		} else {
			$error = "Incorrect username or password";
			$return = 0;
		}
	} elsif ($key) {
		# The timestamp gets updated by verifyKey
		if ($auth->verifyKey($user, $key)) {
			$return = 1;
		} else {
			$error = "Your session has expired.  You must login again";
			$return = 0;
		}
	} else {
		$error = "Unexpected authentication error!";
		$return = 0;
	}

	$r->notes("authen_error",$error) if defined($error);
	return $return;
	
	# Whatever you do, don't delete this!
	critical($r);
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu

=cut
