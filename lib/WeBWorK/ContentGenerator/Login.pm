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

package WeBWorK::ContentGenerator::Login;
use base qw(WeBWorK);
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Login - display a login form.

=cut

use strict;
use warnings;
#use CGI qw(-nosticky );
use WeBWorK::CGI;
use WeBWorK::Utils qw(readFile dequote jitar_id_to_seq format_set_name_display);

# This content generator is NOT logged in.
# BUT one must return a 1 so that error messages can be displayed.
sub if_loggedin {
	my ($self, $arg) = @_;
	#	return !$arg;
	return 1;
}

sub title {
	my ($self) = @_;
	my $r = $self->r;
	# using the url arguments won't break if the set/problem are invalid
	my $setID     = $self->r->urlpath->arg('setID');
	my $problemID = $self->r->urlpath->arg('problemID');

	# If the url is for a problem page, then the title is the set and problem id.
	if ($problemID) {
		# Print the pretty version of the problem id for a jitar set.
		my $set = $r->db->getGlobalSet($setID);
		if ($set && $set->assignment_type eq 'jitar') {
			$problemID = join('.', jitar_id_to_seq($problemID));
		}

		return $r->maketext('[_1]: Problem [_2]', CGI::span({ dir => 'ltr' }, format_set_name_display($setID)),
			$problemID);
	}

	my $ref = $self->SUPER::title();
	return $ref;
}

sub info {

	######### NOTES ON TRANSLATION
# -translation of the content found in the info panel.  Since most of this content is in fact read from files, a simple use of maketext would be too limited to translate these types of content efficiently.

	my ($self) = @_;
	my $r      = $self->r;
	my $ce     = $r->ce;

	my $result;
	# This section should be kept in sync with the Home.pm version
	# list the login info first.

	# FIXME this is basically the same code as below... TIME TO REFACTOR!
	my $login_info = $ce->{courseFiles}->{login_info};

	if (defined $login_info and $login_info) {
		# login info is relative to the templates directory, apparently
		$login_info = $ce->{courseDirs}->{templates} . "/$login_info";

		if (-f $login_info) {
			my $text = eval { readFile($login_info) };
			if ($@) {
				$result .= CGI::h2($r->maketext("Login Info"));
				$result .= CGI::div({ class => 'alert alert-danger p-1 mb-2' }, $@);
			} elsif ($text =~ /\S/) {
				$result .= CGI::h2($r->maketext("Login Info"));
				$result .= $text;
			}
		}
	}

	my $site_info = $ce->{webworkFiles}->{site_info};
	if (defined $site_info and $site_info) {
		if (-f $site_info) {
			my $text = eval { readFile($site_info) };
			if ($@) {
				$result .= CGI::h2($r->maketext("Site Information"));
				$result .= CGI::div({ class => 'alert alert-danger p-1 mb-2' }, $@);
			} elsif ($text =~ /\S/) {
				$result .= CGI::h2($r->maketext("Site Information"));
				$result .= $text;
			}
		}
	}

	if (defined $result and $result ne "") {
		return $result;
	} else {
		return "";
	}
}

# Override the if_can method to disable links for the login page.
sub if_can {
	my ($self, $arg) = @_;
	return $arg eq 'links' ? 0 : $self->SUPER::if_can($arg);
}

async sub pre_header_initialize {
	my ($self) = @_;
	my $authen = $self->r->authen;

	if (defined($authen->{redirect}) && $authen->{redirect}) {
		$self->reply_with_redirect($authen->{redirect});
	}
}

sub head {
	my ($self)   = @_;
	my $ce       = $self->r->ce;
	my $contents = $ce->{options}{metaRobotsContent} // 'none';
	print '<meta name="robots" content="' . $contents . '" />';
	return "";
}

sub body {
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $urlpath = $r->urlpath;

	# get the authen object to make sure that we should print
	#    a login form or not
	my $auth = $r->authen;

	# The following line may not work when a sequence of authentication modules
	# are used, because the preferred module might be external, e.g., LTIBasic,
	# but a non-external one, e.g., Basic_TheLastChance or
	# even just WeBWorK::Authen, might handle the ongoing session management.
	# So this should be set in the course environment when a sequence of
	# authentication modules is used..
	#my $externalAuth = (defined($auth->{external_auth}) && $auth->{external_auth} ) ? 1 : 0;
	my $externalAuth = (
		(defined($ce->{external_auth}) && $ce->{external_auth})
			or (defined($auth->{external_auth}) && $auth->{external_auth})
	) ? 1 : 0;

	# get some stuff together
	my $user               = $r->param("user") || "";
	my $key                = $r->param("key");
	my $passwd             = $r->param("passwd") || "";
	my $course             = $urlpath->arg("courseID") =~ s/_/ /gr;
	my $practiceUserPrefix = $ce->{practiceUserPrefix};

	# don't fill in the user ID for practice users
	# (they should use the "Guest Login" button)
	$user = "" if $user =~ m/^$practiceUserPrefix/;

	# WeBWorK::Authen::verify will set the note "authen_error"
	# if invalid authentication is found.  If this is done, it's a signal to
	# us to yell at the user for doing that, since Authen isn't a content-
	# generating module.
	my $authen_error = $r->stash('authen_error') // '';

	if ($authen_error) {
		print CGI::div({ class => 'alert alert-danger', tabindex => '0' }, $authen_error);
	}

	if ($externalAuth) {
		my $LMS = ($ce->{LMS_url}) ? CGI::a({ href => $ce->{LMS_url} }, $ce->{LMS_name}) : $ce->{LMS_name};
		if (!$authen_error || $r->authen() eq "WeBWorK::Authen::LTIBasic") {
			print CGI::p($r->maketext(
				'The course [_1] uses an external authentication system ([_2]). '
					. 'Please return to that system to access this course.',
				CGI::strong($course),
				$LMS
			));
		} else {
			print CGI::p($r->maketext(
				'The course [_1] uses an external authentication system ([_2]). You\'ve authenticated through that '
					. 'system, but aren\'t allowed to log in to this course.',
				CGI::strong($course),
				$LMS
			));
		}
	} else {
		print CGI::p($r->maketext("Please enter your username and password for [_1] below:", CGI::b($course)));
		if ($ce->{session_management_via} ne "session_cookie") {
			print CGI::p($r->maketext(
				'If you check [_1] your login information will be remembered by the browser you are using, allowing '
					. 'you to visit WeBWorK pages without typing your user name and password (until your session '
					. 'expires). This feature is not safe for public workstations, untrusted machines, and machines '
					. 'over which you do not have direct control.',
				CGI::b($r->maketext("Remember Me"))
			));
		}

		print CGI::start_form({ method => "POST", action => $r->uri, id => "login_form" });

		# preserve the form data posted to the requested URI
		my @fields_to_print = grep { not m/^(user|passwd|key|force_passwd_authen)$/ } $r->param;

		# Important note. If hidden_fields is passed an empty array
		# it prints ALL parameters as hidden fields.  That is not
		# what we want in this case, so we don't print at all if
		# @fields_to_print is empty.
		print $self->hidden_fields(@fields_to_print) if @fields_to_print > 0;

		print CGI::start_div({ class => 'col-xl-5 col-lg-6 col-md-7 col-sm-8 my-3' });
		print CGI::div(
			{ class => 'form-floating mb-2' },
			CGI::textfield({
				id             => 'uname',
				name           => 'user',
				value          => $user,
				aria_required  => 'true',
				class          => 'form-control',
				placeholder    => '',
				autocapitalize => 'none',
				spellcheck     => 'false'
			}),
			CGI::label({ for => 'uname' }, $r->maketext('Username'))
		);
		print CGI::div(
			{ class => 'form-floating mb-2' },
			CGI::password_field({
				id            => 'pswd',
				name          => 'passwd',
				value         => $passwd,
				aria_required => 'true',
				class         => 'form-control',
				placeholder   => ''
			}),
			CGI::label({ for => 'pswd' }, $r->maketext('Password'))
		);

		if ($ce->{session_management_via} ne 'session_cookie') {
			print CGI::start_div({ class => 'form-check form-control-lg mb-2' });
			print CGI::checkbox({
				id              => 'rememberme',
				label           => $r->maketext('Remember Me'),
				name            => 'send_cookie',
				value           => 'on',
				class           => 'form-check-input',
				labelattributes => { class => 'form-check-label' }
			});
			print CGI::end_div();
		}

		print CGI::submit({ type => "submit", value => $r->maketext("Continue"), class => 'btn btn-primary' });
		print CGI::end_div();

		# Determine if there are valid practice users.
		my @GuestUsers = $db->getUsersWhere({ user_id => { like => "$practiceUserPrefix\%" } });
		my @allowedGuestUsers;
		foreach my $GuestUser (@GuestUsers) {
			next unless defined $GuestUser->status;
			next unless $GuestUser->status ne "";
			push @allowedGuestUsers, $GuestUser
				if $ce->status_abbrev_has_behavior($GuestUser->status, "allow_course_access");
		}

		# Guest login
		if (@allowedGuestUsers) {
			# preserve the form data posted to the requested URI
			my @fields_to_print = grep { not m/^(user|passwd|key|force_passwd_authen)$/ } $r->param;
			print CGI::start_div({ class => 'my-3' });
			print CGI::p($r->maketext(
				'This course supports guest logins. Click [_1] to log into this course as a guest.',
				CGI::b($r->maketext("Guest Login"))
			));
			print CGI::input({
				type  => "submit",
				name  => "login_practice_user",
				value => $r->maketext("Guest Login"),
				class => 'btn btn-primary'
			});
			print CGI::end_div();
		}

		print CGI::end_form();
	}
	return "";
}

1;
