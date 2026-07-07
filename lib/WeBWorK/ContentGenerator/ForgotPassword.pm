package WeBWorK::ContentGenerator::ForgotPassword;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::ForgotPassword - render the forgot password form

=cut

use Email::Stuffer;
use Email::Sender::Transport::SMTP;
use Digest::SHA          qw(sha256_hex);
use Math::Random::Secure qw(irand);

use WeBWorK::Debug       qw(debug);
use WeBWorK::Utils       qw(createEmailSenderTransportSMTP);
use WeBWorK::Utils::Logs qw(writeCourseLog);

# Override the can method to disable links for the forgot password page.
sub can ($c, $arg) {
	return $arg eq 'links' ? 0 : $c->SUPER::can($arg);
}

sub initialize ($c) {
	my $ce = $c->ce;

	$c->stash->{footerWidthClass} = 'col-xl-5 col-lg-6 col-md-7 col-sm-8';

	return unless $c->param('request_password_reset') && $ce->{password_reset_sender_email};

	my $user = $c->db->getUser($c->param('user'));

	# Send a password reset email to the user if the user exists, the user has an email address set, the user has the
	# permission to change their password, and the user already has a password (the user cannot create a password via
	# the password reset flow).
	return
		unless $user
		&& $user->email_address =~ /\S/
		&& $c->authz->hasPermissions($user->user_id, 'change_password');

	my $password = $c->db->getPassword($user->user_id);
	return unless $password && $password->password;

	my $resetToken = join('', map { [ 0 .. 9, 'a' .. 'z' ]->[ irand(36) ] } 1 .. 64);
	$password->reset_token(sha256_hex($resetToken));
	$password->reset_token_expiration(time + 900);
	eval { $c->db->putPassword($password) };
	if ($@) {
		$c->log->error('Unable to save password reset token to database for user ' . $user->user_id . ": $@");
		return;
	}

	my $resetURL = $c->url_for('reset_password')->to_abs->query(user => $user->user_id, token => $resetToken);

	my $email =
		Email::Stuffer->to($user->rfc822_mailbox)
		->from($ce->{password_reset_sender_email})
		->subject($c->maketext('Reset Password'))
		->text_body($c->maketext(
			"Use the following link to reset your password: [_1]\n\n"
			. "That link will only be valid for 15 minus (until [_2]).",
			$resetURL,
			$c->formatDateTime($password->reset_token_expiration, 'datetime_format_long')
		))
		->html_body($c->tag(
			'html',
			$c->tag(
				'body',
				$c->c(
					$c->tag('div', $c->link_to($c->maketext('Reset password') => $resetURL)),
					$c->tag(
						'div',
						$c->maketext(
							'That link will only be valid for 15 minutes (until [_1]).',
							$c->formatDateTime($password->reset_token_expiration, 'datetime_format_long')
						)
					)
				)->join('')
			)
		))->header('X-Remote-Host' => $c->tx->remote_address || 'UNKNOWN');

	eval {
		$email->send_or_die({
			transport => createEmailSenderTransportSMTP($ce),
			$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : ()
		});
		debug 'Successfully sent password reset email to ' . $user->email_address;
	};
	if ($@) {
		my $exception_message = ref($@) ? $@->message : $@;
		$c->log->error('Error sending password reset email to ' . $user->email_address . ": $exception_message");
	}

	writeCourseLog($ce, 'login_log', 'PASSWORD RESET REQUEST user_id=' . $user->user_id);

	return;
}

1;
