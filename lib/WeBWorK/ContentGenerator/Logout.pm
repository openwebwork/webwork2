package WeBWorK::ContentGenerator::Logout;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Logout - invalidate key and display logout message.

=cut

use WeBWorK::Localize;

sub pre_header_initialize ($c) {
	my $ce     = $c->ce;
	my $db     = $c->db;
	my $authen = $c->authen;

	# Do any special processing needed by external authentication. This is done before
	# the session is killed in case the authentication module needs access to it.
	$authen->logout_user if $authen->can('logout_user');

	$authen->killSession;
	$authen->write_log_entry('LOGGED OUT');

	if ($authen->{redirect}) {
		$c->reply_with_redirect($authen->{redirect});
	} elsif ($c->param('show_login')) {
		# Allow a caller (e.g. the forced password reset page) to skip the logout confirmation page and go directly
		# to the course's login page, so the user can immediately log in as someone else.
		$c->reply_with_redirect($c->systemLink($c->url_for('set_list')));
	}

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
