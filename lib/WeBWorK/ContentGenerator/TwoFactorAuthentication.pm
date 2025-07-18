package WeBWorK::ContentGenerator::TwoFactorAuthentication;
use Mojo::Base 'WeBWorK::ContentGenerator::Login', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::TwoFactorAuthentication - display the two factor authentication form.

=cut

use GD::Image;    # Needed since GD::Barcode::QRcode calls GD::Image->new without loading GD::Image.
use GD::Barcode::QRcode;
use Email::Stuffer;
use Mojo::Util qw(b64_encode);

use WeBWorK::Utils::TOTP;
use WeBWorK::Utils qw(createEmailSenderTransportSMTP);

sub pre_header_initialize ($c) {
	my $ce = $c->ce;

	# Preserve the form data posted to the requested URI
	my @fields_to_print =
		grep { !m/^(user|passwd|key|force_passwd_authen|otp_code|verify_otp|cancel_otp_verification)$/ } $c->param;
	push(@fields_to_print, 'user', 'key') if $ce->{session_management_via} ne 'session_cookie';
	$c->stash->{hidden_fields} = @fields_to_print ? $c->hidden_fields(@fields_to_print) : '';

	# Make sure these are defined for the template.
	$c->stash->{otp_link}   = '';
	$c->stash->{otp_qrcode} = '';
	$c->stash->{authen_error} //= '';

	my $password = $c->db->getPassword($c->authen->{user_id});

	if (!$password || !$password->otp_secret) {
		my $totp =
			WeBWorK::Utils::TOTP->new(
				$c->authen->session->{otp_secret} ? (secret => $c->authen->session->{otp_secret}) : ());
		$c->authen->session(otp_secret => $totp->secret);

		my $otp_link = $totp->generate_otp($c->authen->{user_id}, $c->url_for('set_list')->to_abs =~ s|https?://||r);

		my $img_data = do {
			local $SIG{__WARN__} = sub { };
			GD::Barcode::QRcode->new($otp_link, { Ecc => 'L', ModuleSize => 4, Version => 0 })->plot->png;
		};

		# Note that this user has already authenticated so the user record should exist.
		my $user = $c->db->getUser($c->authen->{user_id});

		if ($ce->{twoFA}{email_sender} && (my $recipient = $user->email_address)) {
			return if $c->authen->session->{otp_setup_email_sent};

			# Ideally this could include the OTP link used to generate the QR code.  Then on a mobile device that link
			# could be clicked on to add the account to an authenticator app (as is done on the template if this is
			# shown in the browser), since you can't scan the QR code if viewing this email on that device.  However,
			# gmail (and probably other email providers as well) strips any links with hrefs that don't start with
			# http[s]://.  The otpauth:// protocol of course does not.
			my $mail =
				Email::Stuffer->to($recipient)->from($ce->{twoFA}{email_sender})
				->subject($c->maketext('Setup One-Time Password Authentication'))->html_body(
					'<DOCTYPE html><html '
					. $c->output_course_lang_and_dir
					. '><body>'
					. $c->c(
						$c->tag(
							'p',
							$c->maketext(
								'To set up one-time password generation, scan the attached QR code with an '
								. 'authenticator app (such as Google Authenticator, Microsoft Authenticator, '
								. 'Twilio Authy, etc.) installed on a mobile device.'
							)
						),
						$c->tag(
							'div',
							style => 'text-align:center',
							$c->image('cid:logo_qrcode', alt => $c->maketext('One-time password setup QR code'))
						),
						$c->tag(
							'p',
							$c->maketext(
								'Once the authenticator app is set up, return to the login page in WeBWorK and '
								. 'enter the code it shows. Remember that the attached QR code is only valid as '
								. 'long as the page that you were visiting when this email was sent is still open.'
							)
						),
						$c->tag(
							'p',
							$c->maketext(
								'This email should be deleted once you have completely signed in the first time.')
						)
					)->join('')->to_string
					. '</body></html>'
			)->attach($img_data, filename => 'QRCode.png')
				->header('X-Remote-Host' => $c->tx->remote_address || 'UNKNOWN')
				->transport(createEmailSenderTransportSMTP($ce));

			# In order to show the image directly in the email, the content type needs to be multipart/related.  The
			# attached image also needs a content id.  Gmail seems to refuse to accept the email if that content id does
			# not start with "logo".
			$mail->header('Content-Type' => 'multipart/related');
			($mail->parts)[1]->header_str_set('Content-Id' => '<logo_qrcode>');

			eval { $mail->send_or_die({
					$ce->{mail}{set_return_path} ? (from => $ce->{mail}{set_return_path}) : () }); };

			if ($@) {
				$c->log->error('The following error occured while attempting to send the one-time password '
						. 'generation setup email for "'
						. $c->authen->{user_id} . '":'
						. ref($@) ? $@->message : $@);
				$c->log->error('The user will be shown the information directly in the web page.');
				$c->stash->{otp_link}   = $otp_link;
				$c->stash->{otp_qrcode} = $img_data;
			} else {
				$c->authen->session->{otp_setup_email_sent} = 1;
			}
		} else {
			$c->stash->{otp_link}   = $otp_link;
			$c->stash->{otp_qrcode} = $img_data;
		}
	}

	return;
}

1;
