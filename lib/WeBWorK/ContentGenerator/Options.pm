################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Options.pm,v 1.15 2004/01/17 16:38:40 gage Exp $
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
use CGI qw();
use WeBWorK::Utils qw(cryptPassword dequote);

sub body {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	
	my $effectiveUserID = $r->param('effectiveUser');
	my $effectiveUser = $db->getUser($effectiveUserID); # checked
	die "record not found for user $effectiveUserID (effective user)."
		unless defined $effectiveUser;
	
	my $changeOptions = $r->param("changeOptions");
	my $newP = $r->param("newPassword");
	my $confirmP = $r->param("confirmPassword");
	my $newA = $r->param("newAddress");
		
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print CGI::h2("Change Password");
	if ($changeOptions) {
		if ($newP or $confirmP) {
			if ($newP eq $confirmP) {
				my $passwordRecord = eval {$db->getPassword($effectiveUser->user_id)}; # checked
				warn "Can't get password for user |$effectiveUser| $@" if $@ or not defined($passwordRecord);
				my $cryptedPassword = cryptPassword($newP);
				$passwordRecord->password($cryptedPassword);
				
				# possibly do some format checking?
				eval { $db->putPassword($passwordRecord) };
				if ($@) {
					print CGI::div({class=>"ResultsWithError"},
						CGI::p("Couldn't change your password: $@"),
					);
				} else {
					print CGI::div({class=>"ResultsWithoutError"},
						CGI::p("Your password has been changed."),
					);
				}
			} else {
				print CGI::div({class=>"ResultsWithError"},
					CGI::p(dequote <<"					EOT"),
						The passwords you entered in the New Password and
						Confirm Password fields don't match. Please retype your
						new password and try again.
					EOT
				);
			}
		}
	}
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::td("New Password"),
			CGI::td(CGI::password_field("newPassword")),
		),
		CGI::Tr(
			CGI::td("Confirm Password"),
			CGI::td(CGI::password_field("confirmPassword")),
		),
	);
	print CGI::h2("Change Email Address");
	if ($changeOptions) {
		if ($newA) {
			# possibly do some format checking?
			my $oldA = $effectiveUser->email_address;
			$effectiveUser->email_address($newA);
			eval { $db->putUser($effectiveUser) };
			if ($@) {
				$effectiveUser->email_address($oldA);
				print CGI::div({class=>"ResultsWithError"},
					CGI::p("Couldn't change your email address: $@"),
				);
			} else {
				print CGI::div({class=>"ResultsWithoutError"},
					CGI::p("Your email address has been changed."),
				);
			}
		}
	}
	print CGI::table({class=>"FormLayout"},
		CGI::Tr(
			CGI::td("Current Address"),
			CGI::td($effectiveUser->email_address),
		),
		CGI::Tr(
			CGI::td("New Address"),
			CGI::td(CGI::textfield("newAddress", $newA)),
		),
	);
	print CGI::br();
	print CGI::submit("changeOptions", "Change User Options");
	print CGI::end_form();
	
	return "";
}

1;
