package WeBWorK::ContentGenerator::Options;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Options - Change user options.

=cut

use Mojo::Util qw(trim);

use WeBWorK::Utils qw(cryptPassword utf8Crypt isValidEmailAddress);
use WeBWorK::Localize;

sub page_title ($c) {
	return $c->maketext('Account settings');
}

sub initialize ($c) {
	my $db    = $c->db;
	my $authz = $c->authz;

	my $userID = $c->authen->{user_id};
	my $user   = $c->authen->{user};

	my $changeOptions = $c->param('changeOptions');

	if ($authz->hasPermissions($userID, 'change_password')) {
		my $currP    = $c->param('currPassword');
		my $newP     = $c->param('newPassword');
		my $confirmP = $c->param('confirmPassword');

		# Note that it is ok if the password doesn't exist because students might be setting it for the first time.
		my $password = eval { $db->getPassword($userID) };

		if ($changeOptions && ($newP || $confirmP)) {
			# Check that either password is not defined or if it is defined then we have the right one.
			if (!defined $password || utf8Crypt($currP // '', $password->password) eq $password->password) {
				if ($newP eq $confirmP) {
					my $newPassword = $password // $db->newPassword(user_id => $userID);
					$newPassword->password(cryptPassword($newP));
					eval { defined $password ? $db->putPassword($newPassword) : $db->addPassword($newPassword) };
					if ($@) {
						$c->log->error("Error changing password for $userID: $@");
						$c->addbadmessage($c->maketext('Your password was not changed due to an internal error.'));
					} else {
						$password = $newPassword;
						$c->addgoodmessage($c->maketext('Your password has been changed.'));
					}
				} else {
					$c->addbadmessage($c->maketext(
						q{The passwords you entered in the "[_1]" and "[_2]" fields don't match. }
							. 'Please retype your new password and try again.',
						$c->tag('b', $c->maketext('New Password')),
						$c->tag('b', $c->maketext('Confirm New Password'))
					));
				}
			} else {
				$c->addbadmessage($c->maketext(
					'The password you entered in the "[_1]" field does not match your current password. '
						. 'Please retype your current password and try again.',
					$c->tag('b', $c->maketext('Current Password'))
				));
			}
		}
		$c->{has_password} = defined $password;
	}

	my $newFN = trim($c->param('newFirstName') // '');
	if ($newFN && $changeOptions && $authz->hasPermissions($userID, 'change_name')) {
		my $oldFN = $user->first_name;
		$user->first_name($newFN);
		eval { $db->putUser($user) };
		if ($@) {
			$user->first_name($oldFN);
			$c->log->error("Unable to save new first name for $userID: $@");
			$c->addbadmessage($c->maketext('Your first name has not been changed due to an internal error.'));
		} else {
			$c->param('currFirstName', $newFN);
			$c->param('newFirstName',  undef);
			$c->addgoodmessage($c->maketext('Your first name has been changed.'));
		}
	}

	my $newLN = trim($c->param('newLastName') // '');
	if ($newLN && $changeOptions && $authz->hasPermissions($userID, 'change_name')) {
		my $oldLN = $user->last_name;
		$user->last_name($newLN);
		eval { $db->putUser($user) };
		if ($@) {
			$user->last_name($oldLN);
			$c->log->error("Unable to save new last name for $userID: $@");
			$c->addbadmessage($c->maketext('Your last name has not been changed due to an internal error.'));
		} else {
			$c->param('currLastName', $newLN);
			$c->param('newLastName',  undef);
			$c->addgoodmessage($c->maketext('Your last name has been changed.'));
		}
	}

	my $newA = trim($c->param('newAddress') // '');
	if ($newA && $changeOptions && $authz->hasPermissions($userID, 'change_email_address')) {
		if (!isValidEmailAddress($newA)) {
			$c->addbadmessage(
				$c->maketext(
					'Your email address has not been changed. The new email address you entered is not valid.')
			);
		} else {
			my $oldA = $user->email_address;
			$user->email_address($newA);
			eval { $db->putUser($user) };
			if ($@) {
				$user->email_address($oldA);
				$c->log->error("Unable to save new email address for $userID: $@");
				$c->addbadmessage($c->maketext('Your email address has not been changed due to an internal error.'));
			} else {
				$c->param('currAddress', $newA);
				$c->param('newAddress',  undef);
				$c->addgoodmessage($c->maketext('Your email address has been changed.'));
			}
		}
	}

	if ($changeOptions && $authz->hasPermissions($userID, 'change_pg_display_settings')) {
		if (
			(defined($c->param('showOldAnswers')) && $user->showOldAnswers() ne $c->param('showOldAnswers'))
			|| (defined($c->param('useMathQuill'))
				&& $user->useMathQuill() ne $c->param('useMathQuill'))
			|| (defined($c->param('useMathView'))
				&& $user->useMathView() ne $c->param('useMathView'))
			)
		{
			$user->showOldAnswers($c->param('showOldAnswers'));
			$user->useMathQuill($c->param('useMathQuill'));
			$user->useMathView($c->param('useMathView'));

			eval { $db->putUser($user) };
			if ($@) {
				$c->log->error("Unable to save display options for $userID: $@");
				$c->addbadmessage($c->maketext('Your display options were not saved due to an internal error.'));
			} else {
				$c->addgoodmessage($c->maketext('Your display options have been saved.'));
			}
		}
	}

	return;
}

1;
