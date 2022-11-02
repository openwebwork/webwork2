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
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Options - Change user options.

=cut

use strict;
use warnings;
use WeBWorK::CGI;
use WeBWorK::Utils qw(cryptPassword);
use WeBWorK::Localize;

sub body {
	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;
	my $db     = $r->db;
	my $authz  = $r->authz;

	my $userID = $r->param('user');
	my $User   = $db->getUser($userID);
	die "record not found for user '$userID'." unless defined $User;

	my $eUserID = $r->param('effectiveUser');
	my $EUser   = $db->getUser($eUserID);       # checked
	die "record not found for effective user '$eUserID'." unless defined $EUser;

	my $user_name   = $User->first_name . ' ' . $User->last_name;
	my $e_user_name = $EUser->first_name . ' ' . $EUser->last_name;

	my $changeOptions = $r->param('changeOptions');
	my $currP         = $r->param('currPassword');
	my $newP          = $r->param('newPassword');
	my $confirmP      = $r->param('confirmPassword');
	my $newA          = $r->param('newAddress');

	print CGI::start_form(-method => 'POST', -action => $r->uri);
	print $self->hidden_authen_fields;

	if ($authz->hasPermissions($userID, 'change_password')) {
		print CGI::h2($r->maketext('Change Password'));

		my $Password = eval { $db->getPassword($User->user_id) };

		# Its ok if the $Password doesn't exist because students might be setting it for the first time.
		warn $r->maketext("Can't get password record for user '[_1]': [_2]", $userID, $@) if $@;

		if ($changeOptions and ($currP or $newP or $confirmP)) {

			my $EPassword = eval { $db->getPassword($EUser->user_id) };    # checked
			warn $r->maketext("Can't get password record for effective user '[_1]': [_2]", $eUserID, $@) if $@;

			# Check that either password is not defined or if it is defined then we have the right one.
			if ((not defined $Password) || (crypt($currP // '', $Password->password) eq $Password->password)) {
				if ($newP or $confirmP) {
					if ($newP eq $confirmP) {
						if (not defined $EPassword) {
							$EPassword = $db->newPassword();
							$EPassword->user_id($EUser->user_id);
							$EPassword->password(cryptPassword($newP));
							eval { $db->addPassword($EPassword) };
							$Password = $Password // $EPassword;
							if ($@) {
								print CGI::div({ class => 'alert alert-danger', tabindex => '-1' },
									$r->maketext("Couldn't change [_1]'s password: [_2]", $e_user_name, $@));
							} else {
								print CGI::div({ class => 'alert alert-success' },
									$r->maketext("[_1]'s password has been changed.", $e_user_name));
							}
						} else {
							$EPassword->password(cryptPassword($newP));
							eval { $db->putPassword($EPassword) };
							$Password = $Password // $EPassword;
							if ($@) {
								print CGI::div({ class => 'alert alert-danger', tabindex => '-1' },
									$r->maketext("Couldn't change [_1]'s password: [_2]", $e_user_name, $@));
							} else {
								print CGI::div({ class => 'alert alert-success' },
									$r->maketext("[_1]'s password has been changed.", $e_user_name));
							}
						}
					} else {
						print CGI::div(
							{ class => 'alert alert-danger', tabindex => '-1' },
							$r->maketext(
								"The passwords you entered in the [_1] and [_2] fields don't match. "
									. 'Please retype your new password and try again.',
								CGI::b($r->maketext("[_1]'s New Password",         $e_user_name)),
								CGI::b($r->maketext("Confirm [_1]'s New Password", $e_user_name))
							)
						);
					}
				} else {
					print CGI::div({ class => 'alert alert-danger', tabindex => '-1' },
						$r->maketext("[_1]'s new password cannot be blank.", $e_user_name));
				}
			} else {
				print CGI::div(
					{ class => 'alert alert-danger', tabindex => '-1' },
					$r->maketext(
						'The password you entered in the [_1] field does not match your current password. '
							. 'Please retype your current password and try again.',
						CGI::b($r->maketext("[_1]'s Current Password", $user_name))
					)
				);
			}

		}

		print CGI::div(
			{ class => 'row mb-2' },
			CGI::div(
				{ class => 'col-lg-8 col-md-10' },
				CGI::div(
					{ class => 'row mb-2' },
					CGI::label(
						{ 'for' => 'currPassword', class => 'col-form-label col-sm-6' },
						$r->maketext("[_1]'s Current Password", $user_name)
					),
					CGI::div(
						{ class => 'col-sm-6' },
						CGI::password_field({
							name => 'currPassword',
							id   => 'currPassword',
							(defined $Password) ? () : (disabled => 1),
							class => 'form-control',
							dir   => 'ltr'
						})
					),
				),
				CGI::div(
					{ class => 'row mb-2' },
					CGI::label(
						{ 'for' => 'newPassword', class => 'col-form-label col-sm-6' },
						$r->maketext("[_1]'s New Password", $e_user_name)
					),
					CGI::div(
						{ class => 'col-sm-6' },
						CGI::password_field(
							{ name => 'newPassword', id => 'newPassword', class => 'form-control', dir => 'ltr' }
						)
					)
				),
				CGI::div(
					{ class => 'row mb-2' },
					CGI::label(
						{ 'for' => 'confirmPassword', class => 'col-form-label col-sm-6' },
						$r->maketext("Confirm [_1]'s New Password", $e_user_name)
					),
					CGI::div(
						{ class => 'col-sm-6' },
						CGI::password_field({
							name  => 'confirmPassword',
							id    => 'confirmPassword',
							class => 'form-control',
							dir   => 'ltr'
						})
					)
				)
			)
		);
	}

	if ($authz->hasPermissions($userID, 'change_email_address')) {
		print CGI::h2($r->maketext('Change Email Address'));

		if ($changeOptions and $newA) {
			my $oldA = $EUser->email_address;
			$EUser->email_address($newA);
			eval { $db->putUser($EUser) };
			if ($@) {
				$EUser->email_address($oldA);
				print CGI::div(
					{ class => 'alert alert-danger', tabindex => '-1' },
					$r->maketext("Couldn't change your email address: [_1]", $@)
				);
			} else {
				print CGI::div({ class => 'alert alert-success' },
					$r->maketext('Your email address has been changed.'));
			}
		}

		print CGI::div(
			{ class => 'row mb-2' },
			CGI::div(
				{ class => 'col-lg-8 col-md-10' },
				CGI::div(
					{ class => 'row mb-2' },
					CGI::label(
						{ 'for' => 'currAddress', class => 'col-form-label col-sm-6' },
						$r->maketext("[_1]'s Current Address", $e_user_name)
					),
					CGI::div(
						{ class => 'col-sm-6' },
						CGI::textfield({
							readonly => undef,
							id       => 'currAddress',
							name     => 'currAddress',
							value    => $EUser->email_address,
							class    => 'form-control',
							dir      => 'ltr'
						})
					)
				),
				CGI::div(
					{ class => 'row mb-2' },
					CGI::label(
						{ 'for' => 'newAddress', class => 'col-form-label col-sm-6' },
						$r->maketext("[_1]'s New Address", $e_user_name)
					),
					CGI::div(
						{ class => 'col-sm-6' },
						CGI::textfield(
							{ name => 'newAddress', id => 'newAddress', class => 'form-control', dir => 'ltr' }
						)
					)
				)
			)
		);
	}

	if ($authz->hasPermissions($userID, 'change_pg_display_settings')) {
		print CGI::h2($r->maketext('Change Display Settings'));

		if ($changeOptions) {
			if (
				(defined($r->param('displayMode')) && $EUser->displayMode() ne $r->param('displayMode'))
				|| (defined($r->param('showOldAnswers')) && $EUser->showOldAnswers() ne $r->param('showOldAnswers'))
				|| (defined($r->param('useWirisEditor')) && $EUser->useWirisEditor() ne $r->param('useWirisEditor'))
				|| (defined($r->param('useMathQuill'))   && $EUser->useMathQuill() ne $r->param('useMathQuill'))
				)
			{
				$EUser->displayMode($r->param('displayMode'));
				$EUser->showOldAnswers($r->param('showOldAnswers'));
				$EUser->useWirisEditor($r->param('useWirisEditor'));
				$EUser->useMathQuill($r->param('useMathQuill'));

				eval { $db->putUser($EUser) };
				if ($@) {
					print CGI::div(
						{ class => 'alert alert-danger', tabindex => '-1' },
						$r->maketext("Couldn't save your display options: [_1]", $@)
					);
				} else {
					print CGI::div(
						{ class => 'alert alert-success p-1 mb-0' },
						$r->maketext('Your display options have been saved.')
					);
				}
			}
		}

		my $result = '';

		my $curr_displayMode = $EUser->displayMode || $ce->{pg}{options}{displayMode};
		my %display_modes    = %{ WeBWorK::PG::DISPLAY_MODES() };
		my @active_modes     = grep { exists $display_modes{$_} } @{ $ce->{pg}{displayModes} };

		if (@active_modes > 1) {
			$result .= CGI::div(
				{ class => 'mb-3' },
				CGI::p({ class => 'lead mb-2' }, $r->maketext('View equations as') . ':'),
				map {
					CGI::div(
						{ class => 'form-check form-check-inline' },
						CGI::input({
							type  => 'radio',
							name  => 'displayMode',
							id    => "displayMode-$_",
							value => $_,
							$_ eq $curr_displayMode ? (checked => undef) : (),
							class => 'form-check-input'
						}),
						CGI::label({ for => "displayMode-$_", class => 'form-check-label' }, $_)
					)
				} @active_modes
			);
		}

		if ($authz->hasPermissions($userID, 'can_show_old_answers')) {
			my $curr_showOldAnswers =
				$EUser->showOldAnswers ne '' ? $EUser->showOldAnswers : $ce->{pg}{options}{showOldAnswers};
			$result .= CGI::div(
				{ class => 'mb-3' },
				CGI::p({ class => 'lead mb-2' }, $r->maketext('Show saved answers?')),
				map {
					CGI::div(
						{ class => 'form-check form-check-inline' },
						CGI::input({
							type  => 'radio',
							name  => 'showOldAnswers',
							id    => "showOldAnswers$_",
							value => $_,
							$_ eq $curr_showOldAnswers ? (checked => undef) : (),
							class => 'form-check-input'
						}),
						CGI::label(
							{ for => "showOldAnswers$_", class => 'form-check-label' },
							$_ ? $r->maketext('Yes') : $r->maketext('No')
						)
					)
				} (1, 0)
			);
		}

		if ($ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathView') {
			# Note, 0 is a legal value, so we can't use || in setting this
			my $curr_useMathView = $EUser->useMathView ne '' ? $EUser->useMathView : $ce->{pg}{options}{useMathView};
			$result .= CGI::div(
				{ class => 'mb-3' },
				CGI::p({ class => 'lead mb-2' }, $r->maketext('Use Equation Editor?')),
				map {
					CGI::div(
						{ class => 'form-check form-check-inline' },
						CGI::input({
							type  => 'radio',
							name  => 'useMathView',
							id    => "useMathView$_",
							value => $_,
							$_ eq $curr_useMathView ? (checked => undef) : (),
							class => 'form-check-input'
						}),
						CGI::label(
							{ for => "useMathView$_", class => 'form-check-label' },
							$_ ? $r->maketext('Yes') : $r->maketext('No')
						)
					)
				} (1, 0)
			);
		}

		if ($ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'WIRIS') {
			# Note, 0 is a legal value, so we can't use || in setting this
			my $curr_useWirisEditor =
				$EUser->useWirisEditor ne '' ? $EUser->useWirisEditor : $ce->{pg}{options}{useWirisEditor};
			$result .= CGI::div(
				{ class => 'mb-3' },
				CGI::p({ class => 'lead mb-2' }, $r->maketext('Use Equation Editor?')),
				map {
					CGI::div(
						{ class => 'form-check form-check-inline' },
						CGI::input({
							type  => 'radio',
							name  => 'useWirisEditor',
							id    => "useWirisEditor$_",
							value => $_,
							$_ eq $curr_useWirisEditor ? (checked => undef) : (),
							class => 'form-check-input'
						}),
						CGI::label(
							{ for => "useWirisEditor$_", class => 'form-check-label' },
							$_ ? $r->maketext('Yes') : $r->maketext('No')
						)
					)
				} (1, 0)
			);
		}

		if ($ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathQuill') {
			# Note, 0 is a legal value, so we can't use || in setting this
			my $curr_useMathQuill =
				$EUser->useMathQuill ne '' ? $EUser->useMathQuill : $ce->{pg}{options}{useMathQuill};
			$result .= CGI::div(
				{ class => 'mb-3' },
				CGI::p({ class => 'lead mb-2' }, $r->maketext('Use live equation rendering?')),
				map {
					CGI::div(
						{ class => 'form-check form-check-inline' },
						CGI::input({
							type  => 'radio',
							name  => 'useMathQuill',
							id    => "useMathQuill$_",
							value => $_,
							$_ eq $curr_useMathQuill ? (checked => undef) : (),
							class => 'form-check-input'
						}),
						CGI::label(
							{ for => "useMathQuill$_", class => 'form-check-label' },
							$_ ? $r->maketext('Yes') : $r->maketext('No')
						)
					)
				} (1, 0)
			);
		}

		print CGI::div({ class => 'mb-3' }, $result) if $result;
	}

	print CGI::submit({
		name  => 'changeOptions',
		value => $r->maketext('Change User Settings'),
		class => 'btn btn-primary'
	});

	print CGI::end_form();

	return '';
}

1;
