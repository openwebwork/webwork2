package WeBWorK::Authen::Cosign;
use base qw/WeBWorK::Authen/;

=head1 NAME

WeBWorK::Authen::Cosign - Authentication plug in for cosign

to use: include in localOverrides.conf or course.conf
  $authen{user_module} = "WeBWorK::Authen::Cosign";
and add /webwork2 or /webwork2/courseName as a CosignProtected
Location

if $c->ce->{cosignoff} is set for a course, authentication reverts
to standard WeBWorK authentication.

=cut

use strict;
use warnings;
use WeBWorK::Debug;

# this is similar to the method in the base class, except that cosign
# ensures that we don't get to the address without a login.  this means
# that we can't allow guest logins, but don't have to do any password
# checking or cookie management.

sub get_credentials {
	my ($self) = @_;
	my $c      = $self->{c};
	my $ce     = $c->ce;
	my $db     = $c->db;

	if ($ce->{cosignoff}) {
		return $self->SUPER::get_credentials();
	} else {
		$c->stash(disable_cookies => 1);

		if (defined($ENV{'REMOTE_USER'})) {
			$self->{'user_id'} = $ENV{'REMOTE_USER'};
			$self->{c}->param("user", $ENV{'REMOTE_USER'});
		} else {
			return 0;
		}
		# set external auth parameter so that Login.pm knows
		#    not to rely on internal logins if there's a check_user
		#    failure.
		$self->{external_auth} = 1;

		# the session key isn't used (cosign is managing this
		#    for us), and we want to force checking against the
		#    site_checkPassword
		$self->{'session_key'}       = undef;
		$self->{'password'}          = 1;
		$self->{'credential_source'} = "params";
		$self->{login_type}          = "cosign";

		return 1;
	}
}

sub site_checkPassword {
	my ($self, $userID, $clearTextPassword) = @_;

	if ($self->{c}->ce->{cosignoff}) {
		return 0;
	} else {
		# this is easy; if we're here at all, we've authenticated
		# through cosign
		return 1;
	}
}

# this is a bit of a cheat, because it does the redirect away from the
#   logout script or what have you, but I don't see a way around that.
sub forget_verification {
	my ($self, @args) = @_;
	my $c = $self->{c};

	if ($c->ce->{cosignoff}) {
		return $self->SUPER::forget_verification(@args);
	} else {
		$self->{was_verified} = 0;
		#		$c->headers_out->{"Location"} = $c->ce->{cosign_logout_script};
		#		$c->send_http_header;
		#		return;
		$self->{redirect} = $c->ce->{cosign_logout_script};
	}
}

1;
