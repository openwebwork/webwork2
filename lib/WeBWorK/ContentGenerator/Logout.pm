package WeBWorK::ContentGenerator::Logout;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Logout - invalidate key and display logout message.

=cut

use WeBWorK::Localize;
use WeBWorK::Authen qw(write_log_entry);

sub pre_header_initialize ($c) {
	my $ce     = $c->ce;
	my $db     = $c->db;
	my $authen = $c->authen;

	# Do any special processing needed by external authentication. This is done before
	# the session is killed in case the authentication module needs access to it.
	$authen->logout_user if $authen->can('logout_user');

	$authen->killSession;
	$authen->WeBWorK::Authen::write_log_entry('LOGGED OUT');

	# Check to see if there is a proctor key associated with this login.  If there is a proctor user, then there must be
	# a proctored test.  So try and delete the key.
	my $proctorID = $c->param('proctor_user');
	if ($proctorID) {
		my $userID = $c->param('user_id');

		eval { $db->deleteKey("$userID,$proctorID"); };
		if ($@) {
			$c->addbadmessage("Error when clearing proctor key: $@");
		}
		# There may also be a proctor key from grading the test.
		eval { $db->deleteKey("$userID,$proctorID,g"); };
		if ($@) {
			$c->addbadmessage("Error when clearing proctor grading key: $@");
		}
	}

	$c->reply_with_redirect($authen->{redirect}) if $authen->{redirect};

	return;
}

# Override the can method to disable links for the logout page.
sub can ($c, $arg) {
	return $arg eq 'links' ? 0 : $c->SUPER::can($arg);
}

sub path ($c, $args) {
	return $c->stash('courseID')
		if (($c->ce->{external_auth} || $c->authen->{external_auth}) && defined $c->stash('courseID'));
	return $c->SUPER::path($args);
}

1;
