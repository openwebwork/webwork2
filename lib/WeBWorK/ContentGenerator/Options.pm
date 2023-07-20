################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ContentGenerator::Options;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::Options - Change user options.

=cut

use WeBWorK::Utils qw(cryptPassword);
use WeBWorK::Localize;

sub initialize ($c) {
	my $db    = $c->db;
	my $authz = $c->authz;

	my $userID = $c->param('user');
	$c->{user} = $db->getUser($userID);
	return unless defined $c->{user};

	my $effectiveUserID = $c->param('effectiveUser');
	$c->{effectiveUser} = $db->getUser($effectiveUserID);
	return unless defined $c->{effectiveUser};

	my $changeOptions = $c->param('changeOptions');

	if ($authz->hasPermissions($userID, 'change_password')) {
		my $currP    = $c->param('currPassword');
		my $newP     = $c->param('newPassword');
		my $confirmP = $c->param('confirmPassword');

		# Note that it is ok if the password doesn't exist because students might be setting it for the first time.
		my $password = eval { $db->getPassword($c->{user}->user_id) };

		if ($changeOptions && ($newP || $confirmP)) {
			my $effectiveUserPassword =
				$userID ne $effectiveUserID ? eval { $db->getPassword($c->{effectiveUser}->user_id) } : $password;

			# Check that either password is not defined or if it is defined then we have the right one.
			if (!defined $password || crypt($currP // '', $password->password) eq $password->password) {
				my $e_user_name = $c->{effectiveUser}->first_name . ' ' . $c->{effectiveUser}->last_name;
				if ($newP eq $confirmP) {
					if (!defined $effectiveUserPassword) {
						$effectiveUserPassword = $db->newPassword();
						$effectiveUserPassword->user_id($c->{effectiveUser}->user_id);
						$effectiveUserPassword->password(cryptPassword($newP));
						eval { $db->addPassword($effectiveUserPassword) };
						$password = $password // $effectiveUserPassword;
						if ($@) {
							$c->addbadmessage($c->maketext("Couldn't change [_1]'s password: [_2]", $e_user_name, $@));
						} else {
							$c->addgoodmessage($c->maketext("[_1]'s password has been changed.", $e_user_name));
						}
					} else {
						$effectiveUserPassword->password(cryptPassword($newP));
						eval { $db->putPassword($effectiveUserPassword) };
						$password = $password // $effectiveUserPassword;
						if ($@) {
							$c->addbadmessage($c->maketext("Couldn't change [_1]'s password: [_2]", $e_user_name, $@));
						} else {
							$c->addgoodmessage($c->maketext("[_1]'s password has been changed.", $e_user_name));
						}
					}
				} else {
					$c->addbadmessage($c->maketext(
						"The passwords you entered in the [_1] and [_2] fields don't match. "
							. 'Please retype your new password and try again.',
						$c->tag('b', $c->maketext("[_1]'s New Password",         $e_user_name)),
						$c->tag('b', $c->maketext("Confirm [_1]'s New Password", $e_user_name))
					));
				}
			} else {
				$c->addbadmessage($c->maketext(
					'The password you entered in the [_1] field does not match your current password. '
						. 'Please retype your current password and try again.',
					$c->tag(
						'b',
						$c->maketext(
							"[_1]'s Current Password",
							$c->{user}->first_name . ' ' . $c->{user}->last_name
						)
					)
				));
			}
		}
		$c->{has_password} = defined $password;
	}

	my $newA = $c->param('newAddress');
	if ($changeOptions && $authz->hasPermissions($userID, 'change_email_address') && $newA) {
		my $oldA = $c->{effectiveUser}->email_address;
		$c->{effectiveUser}->email_address($newA);
		eval { $db->putUser($c->{effectiveUser}) };
		if ($@) {
			$c->{effectiveUser}->email_address($oldA);
			$c->addbadmessage($c->maketext("Couldn't change your email address: [_1]", $@));
		} else {
			$c->addgoodmessage($c->maketext('Your email address has been changed.'));
		}
	}

	if ($changeOptions && $authz->hasPermissions($userID, 'change_pg_display_settings')) {
		if (
			(defined($c->param('displayMode')) && $c->{effectiveUser}->displayMode() ne $c->param('displayMode'))
			|| (defined($c->param('showOldAnswers'))
				&& $c->{effectiveUser}->showOldAnswers() ne $c->param('showOldAnswers'))
			|| (defined($c->param('useMathQuill'))
				&& $c->{effectiveUser}->useMathQuill() ne $c->param('useMathQuill'))
			)
		{
			$c->{effectiveUser}->displayMode($c->param('displayMode'));
			$c->{effectiveUser}->showOldAnswers($c->param('showOldAnswers'));
			$c->{effectiveUser}->useMathQuill($c->param('useMathQuill'));

			eval { $db->putUser($c->{effectiveUser}) };
			if ($@) {
				$c->addbadmessage($c->maketext("Couldn't save your display options: [_1]", $@));
			} else {
				$c->addgoodmessage($c->maketext('Your display options have been saved.'));
			}
		}
	}

	return;
}

1;
