################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Options;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Options - Change user options.

=cut

use strict;
use warnings;
use CGI qw();

sub initialize {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	
	$self->{effectiveUser} = $db->getUser($r->param('effectiveUser'));
}

sub path {
	my ($self, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		"User Options" => "",
	);
}

sub title {
	my $self = shift;
	
	return "User Options for " . $self->{effectiveUser}->first_name
		. " " . $self->{effectiveUser}->last_name;
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $db = $self->{db};
	my $effectiveUser = $self->{effectiveUser};
	
	my $changeOptions = $r->param("changeOptions");
	my $newP = $r->param("newPassword");
	my $confirmP = $r->param("confirmPassword");
	my $newA = $r->param("newAddress");
	my $confirmA = $r->param("confirmAddress");
		
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields;
	print CGI::h2("Change Password");
	if ($changeOptions) {
		if ($newP or $confirmP) {
			if ($newP eq $confirmP) {
				# possibly do some format checking?
				eval { $self->{authdb}->setPassword($effectiveUser->user_id, $newP) };
				if ($@) {
					print CGI::p("Couldn't change your
					password: $@");
				} else {
					print CGI::p("Your password has been
					changed.");
				}
			} else {
				print CGI::p("The passwords you entered in the
				New Password and Confirm Password fields don't
				match. Please retype your new password and try
				again.");
			}
		}
	}
	print CGI::table(
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
		if ($newA or $confirmA) {
			if ($newA eq $confirmA) {
				# possibly do some format checking?
				my $oldA = $effectiveUser->email_address;
				$effectiveUser->email_address($newA);
				eval { $db->putUser($effectiveUser) };
				if ($@) {
					$effectiveUser->email_address($oldA);
					print CGI::p("Couldn't change your
					email address: $@");
				} else {
					print CGI::p("Your email address has
					been changed.");
					$newA = $confirmA = "";
				}
			} else {
				print CGI::p("The addresses you entered in the
				New Address and Confirm Address fields don't
				match. Please retype your new address and try
				again.");
			}
		}
	}
	print CGI::table(
		CGI::Tr(
			CGI::td("Current Address"),
			CGI::td($effectiveUser->email_address),
		),
		CGI::Tr(
			CGI::td("New Address"),
			CGI::td(CGI::textfield("newAddress", $newA)),
		),
		CGI::Tr(
			CGI::td("Confirm Address"),
			CGI::td(CGI::textfield("confirmAddress", $confirmA)),
		),
	);
	print CGI::br();
	print CGI::submit("changeOptions", "Change User Options");
	print CGI::end_form();
	
	return "";
}

1;
