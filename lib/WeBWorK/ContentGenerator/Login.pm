#TODO: The HTML code here has two failings:
# - It is hard-coded into the script, which is against policy

# Other than that, this file is done for the forseeable future,
# and should serve us nicely unless the interface to WeBWorK::Authen
# changes.

package WeBWorK::ContentGenerator::Login;

use WeBWorK::ContentGenerator;
use Apache::Constants qw(:common);
use CGI qw(-comple :html :form);

our @ISA = qw(WeBWorK::ContentGenerator);

sub title {
	return "Login";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $course_env = $self->{courseEnvironment};
	# get some stuff together
	my $user = $r->param("user");
	my $key = $r->param("key");
	my $passwd = $r->param("passwd");
	my $course = $course_env->{"courseName"};
	
	# WeBWorK::Authen::verify will set the note "authen_error" 
	# if invalid authentication is found.  If this is done, it's a signal to
	# us to yell at the user for doing that, since Authen isn't a content-
	# generating module.
	if ($r->notes("authen_error")) {
		print font({-color=>red}, b($r->notes("authen_error"))),br;
	}
	
	print p("Please enter your username and password for ",b($course)," below:");
	print startform({-method=>"POST", -action=>$r->uri});

	# write out the form data posted to the requested URI
	print $self->print_form_data('<input type="hidden" name="','" value="',"\"/>\n",qr/^(user|passwd|key)$/);
	
	print
		table({-border => 0}, 
		  Tr([
		    td([
		      "Username:",
		      input({-type=>"textfield", -name=>"user", -value=>"$user"}),br,
		    ]),
		    td([
		      "Password:",
		      input({-type=>"password", -name=>"passwd", -value=>"$passwd"}) . i("(Will not be echoed)"),
		    ]),
		 ])
		)
	;
	
	print input({-type=>"submit", -value=>"Continue"});
	print endform;
	
	return "";
}

1;
