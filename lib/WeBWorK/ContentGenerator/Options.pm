################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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
use parent qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Options - Change user options.

=cut

use strict;
use warnings;

use WeBWorK::Utils qw(cryptPassword);
use WeBWorK::Localize;

sub initialize {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;
	my $authz  = $r->authz;

	my $userID = $r->param('user');
	$self->{user} = $db->getUser($userID);
	return unless defined $self->{user};

	my $effectiveUserID = $r->param('effectiveUser');
	$self->{effectiveUser} = $db->getUser($effectiveUserID);
	return unless defined $self->{effectiveUser};

	my $changeOptions = $r->param('changeOptions');

	if ($authz->hasPermissions($userID, 'change_password')) {
		my $currP    = $r->param('currPassword');
		my $newP     = $r->param('newPassword');
		my $confirmP = $r->param('confirmPassword');

		# Note that it is ok if the password doesn't exist because students might be setting it for the first time.
		my $password = eval { $db->getPassword($self->{user}->user_id) };

		if ($changeOptions && ($newP || $confirmP)) {
			my $effectiveUserPassword =
				$userID ne $effectiveUserID ? eval { $db->getPassword($self->{effectiveUser}->user_id) } : $password;

			# Check that either password is not defined or if it is defined then we have the right one.
			if (!defined $password || crypt($currP // '', $password->password) eq $password->password) {
				my $e_user_name = $self->{effectiveUser}->first_name . ' ' . $self->{effectiveUser}->last_name;
				if ($newP eq $confirmP) {
					if (!defined $effectiveUserPassword) {
						$effectiveUserPassword = $db->newPassword();
						$effectiveUserPassword->user_id($self->{effectiveUser}->user_id);
						$effectiveUserPassword->password(cryptPassword($newP));
						eval { $db->addPassword($effectiveUserPassword) };
						$password = $password // $effectiveUserPassword;
						if ($@) {
							$self->addbadmessage(
								$r->maketext("Couldn't change [_1]'s password: [_2]", $e_user_name, $@));
						} else {
							$self->addgoodmessage($r->maketext("[_1]'s password has been changed.", $e_user_name));
						}
					} else {
						$effectiveUserPassword->password(cryptPassword($newP));
						eval { $db->putPassword($effectiveUserPassword) };
						$password = $password // $effectiveUserPassword;
						if ($@) {
							$self->addbadmessage(
								$r->maketext("Couldn't change [_1]'s password: [_2]", $e_user_name, $@));
						} else {
							$self->addgoodmessage($r->maketext("[_1]'s password has been changed.", $e_user_name));
						}
					}
				} else {
					$self->addbadmessage($r->maketext(
						"The passwords you entered in the [_1] and [_2] fields don't match. "
							. 'Please retype your new password and try again.',
						$r->tag('b', $r->maketext("[_1]'s New Password",         $e_user_name)),
						$r->tag('b', $r->maketext("Confirm [_1]'s New Password", $e_user_name))
					));
				}
			} else {
				$self->addbadmessage($r->maketext(
					'The password you entered in the [_1] field does not match your current password. '
						. 'Please retype your current password and try again.',
					$r->tag(
						'b',
						$r->maketext(
							"[_1]'s Current Password",
							$self->{user}->first_name . ' ' . $self->{user}->last_name
						)
					)
				));
			}
		}
		$self->{has_password} = defined $password;
	}

	my $newA = $r->param('newAddress');
	if ($changeOptions && $authz->hasPermissions($userID, 'change_email_address') && $newA) {
		my $oldA = $self->{effectiveUser}->email_address;
		$self->{effectiveUser}->email_address($newA);
		eval { $db->putUser($self->{effectiveUser}) };
		if ($@) {
			$self->{effectiveUser}->email_address($oldA);
			$self->addbadmessage($r->maketext("Couldn't change your email address: [_1]", $@));
		} else {
			$self->addgoodmessage($r->maketext('Your email address has been changed.'));
		}
	}

	if ($changeOptions && $authz->hasPermissions($userID, 'change_pg_display_settings')) {
		if (
			(defined($r->param('displayMode')) && $self->{effectiveUser}->displayMode() ne $r->param('displayMode'))
			|| (defined($r->param('showOldAnswers'))
				&& $self->{effectiveUser}->showOldAnswers() ne $r->param('showOldAnswers'))
			|| (defined($r->param('useWirisEditor'))
				&& $self->{effectiveUser}->useWirisEditor() ne $r->param('useWirisEditor'))
			|| (defined($r->param('useMathQuill'))
				&& $self->{effectiveUser}->useMathQuill() ne $r->param('useMathQuill'))
			)
		{
			$self->{effectiveUser}->displayMode($r->param('displayMode'));
			$self->{effectiveUser}->showOldAnswers($r->param('showOldAnswers'));
			$self->{effectiveUser}->useWirisEditor($r->param('useWirisEditor'));
			$self->{effectiveUser}->useMathQuill($r->param('useMathQuill'));

			eval { $db->putUser($self->{effectiveUser}) };
			if ($@) {
				$self->addbadmessage($r->maketext("Couldn't save your display options: [_1]", $@));
			} else {
				$self->addgoodmessage($r->maketext('Your display options have been saved.'));
			}
		}
	}

	return;
}

1;
