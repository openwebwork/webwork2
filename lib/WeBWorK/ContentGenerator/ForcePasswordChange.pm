package WeBWorK::ContentGenerator::ForcePasswordChange;
use Mojo::Base 'WeBWorK::ContentGenerator::Login', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::ForcePasswordChange - display a form requiring the user to change their password before
they can access the course.

=cut

sub pre_header_initialize ($c) {
	# Preserve the form data posted to the requested URI.
	my @fields_to_print =
		grep { !m/^(user|passwd|key|force_passwd_authen|newPassword|confirmPassword)$/ } $c->param;
	push(@fields_to_print, 'user', 'key') if $c->ce->{session_management_via} ne 'session_cookie';
	$c->stash->{hidden_fields} = @fields_to_print ? $c->hidden_fields(@fields_to_print) : '';

	$c->stash->{authen_error} //= '';

	return;
}

1;
