package WeBWorK::ContentGenerator::ResetPassword;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::ResetPassword - reset a user's password if requested to do so

=cut

use Digest::SHA qw(sha256_hex);

use WeBWorK::Utils       qw(cryptPassword);
use WeBWorK::Utils::Logs qw(writeCourseLog);

# Override the can method to disable links for the password reset page.
sub can ($c, $arg) {
	return $arg eq 'links' ? 0 : $c->SUPER::can($arg);
}

sub initialize ($c) {
	$c->stash->{footerWidthClass}  = 'col-xl-6 col-lg-7 col-md-8 col-12';
	$c->stash->{userID}            = $c->param('user') // '';
	$c->stash->{errorMessage}      = '';
	$c->stash->{entryErrorMessage} = '';

	unless ($c->ce->{password_reset_sender_email}) {
		$c->stash->{errorMessage} = $c->maketext('Password reset is not enabled for this course.');
		return;
	}

	my $user     = $c->db->getUser($c->stash->{userID});
	my $password = $c->db->getPassword($c->stash->{userID});
	unless ($user
		&& $password
		&& $password->password
		&& $password->reset_token
		&& $password->reset_token_expiration ne ''
		&& $password->reset_token_expiration > time
		&& sha256_hex($c->param('token') // '') eq $password->reset_token)
	{
		$c->deleteResetToken($password) if $password;
		writeCourseLog($c->ce, 'login_log',
			'PASSWORD RESET FAILURE user_id=' . $c->stash->{userID} . ': Invalid user or token.')
			if $c->stash->{userID};
		$c->stash->{errorMessage} = $c->maketext('An invalid or expired password reset URL was used.');
		return;
	}

	my $twoFactorAuthenticationEnabled = $c->ce->two_factor_authentication_enabled
		&& $c->authz->hasPermissions($user->user_id, 'use_two_factor_auth');

	if ($twoFactorAuthenticationEnabled && !$password->otp_secret) {
		$c->deleteResetToken($password);
		writeCourseLog($c->ce, 'login_log',
			'PASSWORD RESET FAILURE user_id=' . $user->user_id . ': Two factor authentication not enabled.');
		$c->stash->{errorMessage} = $c->maketext('Two factor authentication has not been set up for this account. '
				. 'Password reset is not allowed until that is done.');
		return;
	}

	return unless $c->param('reset_password');

	my $newPassword = $c->param('newPassword');
	unless ($newPassword && $newPassword =~ /\S/) {
		$c->stash->{entryErrorMessage} = $c->maketext('You must enter a new password.');
		return;
	}

	if ($newPassword ne ($c->param('confirmPassword') // '')) {
		$c->stash->{entryErrorMessage} = $c->maketext(
			'The passwords you entered in the "New Password" and "Confirm New Password" fields do not match. '
				. 'Please retype your new password and try again.',);
		return;
	}

	if ($twoFactorAuthenticationEnabled) {
		my $otpCode = ($c->param('otp_code') // '') =~ s/(^\s+|\s+$)//gr;
		if (!$otpCode) {
			$c->stash->{entryErrorMessage} =
				$c->maketext('You must enter the security code from your authenticator app.');
			return;
		}
		if (!WeBWorK::Utils::TOTP->new(secret => $password->otp_secret, tolerance => 1)->validate_otp($otpCode)) {
			$c->stash->{entryErrorMessage} = $c->maketext('You have entered an invalid one-time security code.');
			return;
		}
	}

	$password->password(cryptPassword($newPassword));
	$password->reset_token(undef);
	$password->reset_token_expiration(undef);
	eval { $c->db->putPassword($password) };
	if ($@) {
		$c->log->error('Error resetting the password for ' . $user->user_id . ": $@");
		$c->stash->{errorMessage} = $c->maketext('Your password was not changed due to an internal error.');
	}

	writeCourseLog($c->ce, 'login_log', 'PASSWORD RESET SUCCESS user_id=' . $user->user_id);

	return;
}

sub deleteResetToken ($c, $password) {
	$password->reset_token(undef);
	$password->reset_token_expiration(undef);
	eval { $c->db->putPassword($password) };
	return;
}

1;
