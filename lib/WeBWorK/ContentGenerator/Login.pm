################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Login;

=head1 NAME

WeBWorK::ContentGenerator::Login - display a login form.

=cut

use strict;
use warnings;
use base qw(WeBWorK::ContentGenerator);
use Apache::Constants qw(:common);
use CGI qw();
use WeBWorK::ContentGenerator;

# TODO: The HTML code here has two failings:
# - It is hard-coded into the script, which is against policy

# Other than that, this file is done for the forseeable future,
# and should serve us nicely unless the interface to WeBWorK::Authen
# changes.

sub title {
	return "Login";
}

sub links {
	return "";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $course_env = $self->{courseEnvironment};
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
	print $self->print_form_data('<input type="hidden" name="','" value="',"\"/>\n",qr/^(user|passwd|key)$/);
	
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
	print CGI::endform();
	
	return "";
}

1;
