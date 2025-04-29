package WeBWorK::Authen::Shibboleth;
use Mojo::Base 'WeBWorK::Authen', -signatures;

=head1 NAME

WeBWorK::Authen::Shibboleth - Authentication plug in for Shibboleth.

=head1 SYNOPSIS

To use this module copy C<conf/authen_shibboleth.conf.dist> to
C<conf/authen_shibboleth.dist>, and uncomment the line in C<conf/localOverrides.conf>
that reads C<include("conf/authen_shibboleth.conf");>.

Refer to the L<external Shibboleth authentication|http://webwork.maa.org/wiki/External_(Shibboleth)_Authentication>
documentation on the WeBWorK wiki and the instructions in the comments of the
C<conf/authen_shibboleth.conf.dist> file.

=cut

use Digest;

use WeBWorK::Debug qw(debug);

sub request_has_data_for_this_verification_module ($self) {
	my $c = $self->{c};

	# Skip if shiboff is set in the course environment or the bypassShib param is set.
	if ($c->ce->{shiboff} || ($c->ce->{shibboleth}{bypass_query} && $c->param($c->ce->{shibboleth}{bypass_query}))) {
		debug('Shibboleth authen module bypass detected. Going to next authentication module.');
		return 0;
	}

	return 1;
}

sub get_credentials ($self) {
	my $c  = $self->{c};
	my $ce = $c->ce;
	my $db = $c->db;

	$c->stash(disable_cookies => 1);
	$self->{external_auth} = 1;

	debug('Checking for shibboleth authentication headers.');

	my $user_id;
	$user_id = $c->req->headers->header($ce->{shibboleth}{mapping}{user_id}) if $ce->{shibboleth}{mapping}{user_id};

	if (defined $user_id && $user_id ne '') {
		debug("Got shibboleth header ($ce->{shibboleth}{mapping}{user_id}) and user_id ($user_id)");

		if (defined($ce->{shibboleth}{hash_user_id_method})
			&& $ce->{shibboleth}{hash_user_id_method} ne 'none'
			&& $ce->{shibboleth}{hash_user_id_method} ne '')
		{
			my $digest = Digest->new($ce->{shibboleth}{hash_user_id_method});
			$digest->add(uc($user_id) . ($ce->{shibboleth}{hash_user_id_salt} // ''));
			$user_id = $digest->hexdigest;
		}

		$self->{user_id} = $user_id;
		$c->param('user', $user_id);
		$self->{login_type}        = 'normal';
		$self->{credential_source} = 'params';

		return 1;
	}

	debug('Unable to obtain user id from Shibboleth header.');
	$self->{redirect} = $ce->{shibboleth}{login_script} . '?target=' . $c->url_for->to_abs;
	$c->redirect_to($self->{redirect});
	return 0;
}

sub authenticate ($self) {
	# The Shibboleth identity provider handles authentication, so just return 1.
	return 1;
}

sub logout_user ($self) {
	$self->{redirect} = $self->{c}->ce->{shibboleth}{logout_script};
	return;
}

sub check_session ($self, $userID, $possibleKey, $updateTimestamp) {
	my $ce = $self->{c}->ce;
	my $db = $self->{c}->db;

	my $Key = $db->getKey($userID);
	return 0 unless defined $Key;

	# This is filled in just in case it is needed somewhere, but is not used in the Shibboleth authentication process.
	$self->{session_key} = $Key->{key};

	my $currentTime = time;
	my $timestampValid =
		$ce->{shibboleth}{manage_session_timeout} ? 1 : time <= $Key->timestamp + $ce->{sessionTimeout};

	if ($timestampValid && $updateTimestamp) {
		$Key->timestamp($currentTime);
		$self->{c}->stash->{'webwork2.database_session'} = { $Key->toHash };
		$self->{c}->stash->{'webwork2.database_session'}{session}{flash} =
			delete $self->{c}->stash->{'webwork2.database_session'}{session}{new_flash}
			if $self->{c}->stash->{'webwork2.database_session'}{session}{new_flash};
	}

	return (1, 1, $timestampValid);
}

1;
