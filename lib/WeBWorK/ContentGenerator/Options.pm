################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/ContentGenerator/Options.pm,v 1.24 2006/07/24 23:28:41 gage Exp $
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
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Utils qw(cryptPassword dequote);
use WeBWorK::Localize;



sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $authz = $r->authz;
	
	my $userID = $r->param("user");
	my $User = $db->getUser($userID);
	die "record not found for user '$userID'." unless defined $User;
	
	my $eUserID = $r->param('effectiveUser');
	my $EUser = $db->getUser($eUserID); # checked
	die "record not found for effective user '$eUserID'." unless defined $EUser;
	
	my $user_name = $User->first_name . " " . $User->last_name;
	my $e_user_name = $EUser->first_name . " " . $EUser->last_name;
	
	my $changeOptions = $r->param("changeOptions");
	my $currP = $r->param("currPassword");
	my $newP = $r->param("newPassword");
	my $confirmP = $r->param("confirmPassword");
	my $newA = $r->param("newAddress");
		
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	
	print CGI::h2($r->maketext("Change Password"));
	
	if ($changeOptions and ($currP or $newP or $confirmP)) {
		
		if ($authz->hasPermissions($userID, "change_password")) {
			
			my $Password = eval {$db->getPassword($User->user_id)}; # checked
			warn $r->maketext("Can't get password record for user '[_1]': [_2]",$userID,$@) if $@ or not defined $Password;
			
			my $EPassword = eval {$db->getPassword($EUser->user_id)}; # checked
			warn $r->maketext("Can't get password record for effective user '[_1]': [_2]",$eUserID,$@) if $@ or not defined $EPassword;
			
			if (crypt($currP, $Password->password) eq $Password->password) {
				if ($newP or $confirmP) {
					if ($newP eq $confirmP) {
						$EPassword->password(cryptPassword($newP));
						eval { $db->putPassword($EPassword) };
						if ($@) {
							print CGI::div({class=>"ResultsWithError"},
								CGI::p($r->maketext("Couldn't change [_1]'s password: [_2]",$e_user_name,$@)),
							);
						} else {
							print CGI::div({class=>"ResultsWithoutError"},
								CGI::p($r->maketext("[_1]'s password has been changed.",$e_user_name)),
							);
						}
					} else {
						print CGI::div({class=>"ResultsWithError"},
							CGI::p(
								$r->maketext("The passwords you entered in the 
								[_1] and [_2]
								fields don't match. Please retype your new password and try
								again.",
								CGI::b($r->maketext("[_1]'s New Password",$e_user_name)), 
								CGI::b($r->maketext("Confirm [_1]'s New Password",$e_user_name))) 
							),
						);
					}
				} else {
					print CGI::div({class=>"ResultsWithError"},
						CGI::p($r->maketext("[_1]'s new password cannot be blank.",$e_user_name)),
					);
				}
			} else {
				print CGI::div({class=>"ResultsWithError"},
					CGI::p($r->maketext("The password you entered in the [_1] 
						field does not match your current
						password. Please retype your current password and try
						again.",
						CGI::b($r->maketext("[_1]'s Current Password",$user_name)))
					),
				);
			}
			
		} else {
			print CGI::div({class=>"ResultsWithError"},
				CGI::p($r->maketext("You do not have permission to change your password.")))
					unless $changeOptions and ($currP or $newP or $confirmP); # avoid double message
		}
		
	}
	
	if ($authz->hasPermissions($userID, "change_password")) {
		print CGI::table({class=>"FormLayout"},
			CGI::Tr({},
				CGI::td($r->maketext("[_1]'s Current Password",$user_name)),
				CGI::td(CGI::password_field(-name=>"currPassword")),
			),
			CGI::Tr({},
				CGI::td($r->maketext("[_1]'s New Password",$e_user_name)),
				CGI::td(CGI::password_field(-name=>"newPassword")),
			),
			CGI::Tr({},
				CGI::td($r->maketext("Confirm [_1]'s New Password",$e_user_name)),
				CGI::td(CGI::password_field(-name=>"confirmPassword")),
			),
		);
	} else {
		print CGI::p($r->maketext("You do not have permission to change your password."));
	}
	
	print CGI::h2($r->maketext("Change Email Address"));
	
	if ($changeOptions and $newA) {
		if ($authz->hasPermissions($userID, "change_email_address")) {
			
			my $oldA = $EUser->email_address;
			$EUser->email_address($newA);
			eval { $db->putUser($EUser) };
			if ($@) {
				$EUser->email_address($oldA);
				print CGI::div({class=>"ResultsWithError"},
					CGI::p($r->maketext("Couldn't change your email address: [_1]",$@)),
				);
			} else {
				print CGI::div({class=>"ResultsWithoutError"},
					CGI::p($r->maketext("Your email address has been changed.")),
				);
			}
			
		} else {
			print CGI::div({class=>"ResultsWithError"},
				CGI::p($r->maketext("You do not have permission to change email addresses.")),
			);
		}
	}
	
	if ($authz->hasPermissions($userID, "change_email_address")) {
		print CGI::table({class=>"FormLayout"},
			CGI::Tr({},
				CGI::td($r->maketext("[_1]'s Current Address",$e_user_name)),
				CGI::td($EUser->email_address),
			),
			CGI::Tr({},
				CGI::td($r->maketext("[_1]'s New Address",$e_user_name)),
				CGI::td(CGI::textfield(-name=>"newAddress", -text=>$newA)),
			),
		);
	} else {
		print CGI::p($r->maketext("You do not have permission to change email addresses."))
			unless $changeOptions and $newA; # avoid double message
	}
	
	print CGI::br();
	print CGI::submit("changeOptions", "Change User Options");
	print CGI::end_form();
	
	return "";
}

1;
