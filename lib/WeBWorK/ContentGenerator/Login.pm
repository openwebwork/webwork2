################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Login;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Login - display a login form.

=cut

use strict;
use warnings;
use CGI qw();

sub title {
	return "Login";
}

sub links {
	return "";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $course_env = $self->{ce};
	# get some stuff together
	my $user = $r->param("user") || "";
	my $key = $r->param("key");
	my $passwd = $r->param("passwd") || "";
	my $course = $course_env->{"courseName"};
	
	# WeBWorK::Authen::verify will set the note "authen_error" 
	# if invalid authentication is found.  If this is done, it's a signal to
	# us to yell at the user for doing that, since Authen isn't a content-
	# generating module.
	if ($r->notes("authen_error")) {
		print CGI::font({-color => 'red'}, CGI::b($r->notes("authen_error"))),CGI::br();
	}
	
	print CGI::p("Please enter your username and password for ",CGI::b($course)," below:");
	print CGI::startform({-method=>"POST", -action=>$r->uri});

	# write out the form data posted to the requested URI
	print $self->print_form_data('<input type="hidden" name="','" value="',"\"/>\n",qr/^(user|passwd|key|force_passwd_authen)$/);
	
	print
		CGI::table({-border => 0}, 
		  CGI::Tr([
		    CGI::td([
		      "Username:",
		      CGI::input({-type=>"textfield", -name=>"user", -value=>"$user"}),CGI::br(),
		    ]),
		    CGI::td([
		      "Password:",
		      CGI::input({-type=>"password", -name=>"passwd", -value=>"$passwd"}) . CGI::i("(Will not be echoed)"),
		    ]),
		 ])
		)
	;
	
	print CGI::input({-type=>"submit", -value=>"Continue"});
	print CGI::p(), "Many courses allow guest logins.", CGI::p(),
	  "Use practice1, practice2, practice3, etc.",CGI::br(),
	  "No password is required";
	print CGI::endform();
	
	return "";
}

sub info {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{ce};

	if (defined $courseEnvironment->{courseFiles}->{login_info}
		and $courseEnvironment->{courseFiles}->{login_info}) {
		my $login_info = eval { WeBWorK::Utils::readFile($courseEnvironment->{courseFiles}->{login_info}) };
		$@ or print $login_info;

	}
	'';
}
# This content generator is NOT logged in.
sub if_loggedin($$) {
	my ($self, $arg) = (@_);
	
	return !$arg;
}

1;
