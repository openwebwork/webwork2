package WeBWorK::ContentGenerator::Test;

# This file will cease to be as soon as the real content generation modules
# have been written.  However, there's always reason to keep it around, as
# it showcases many things that new content generators will want to do,
# since it's generally where I dump new functionality before I put it in any
# end-user modules.

use Apache::Request;
use Apache::Constants qw(:common);
use WeBWorK::ContentGenerator;

use CGI::Carp qw(fatalsToBrowser);

our @ISA = qw(WeBWorK::ContentGenerator);

sub title {
	return "Welcome to Hell.";
}

sub body() {
	my $self = shift;
	my $r = $self->{r};
	my $course_env = $self->{courseEnvironment};
	# get some stuff together
	my $user = $r->param("user");
	my $key = $r->param("key");
	my $uri = $r->uri;

	print "<h1>There you go.</h1>","<p>You're now accessing $uri.</p>";

	print $self->print_form_data(""," = ","<br>\n");

	print '<br><form method="POST" action="',$r->uri,'">';
	print $self->print_form_data('<input type="hidden" name="','" value = "',"\">\n");
	print '<input type="file" name="filefield">';
	print '<input type="submit" value="file upload test"></form>';
	
	print '<br><form method="POST" action="',$r->uri,'">';
	print $self->print_form_data('<input type="hidden" name="','" value = "',"\">\n");
	print '<input type="submit" value="repost"></form>';
	
	print '<form method="POST" action="',$r->uri,'">';
	print $self->print_form_data('<input type="hidden" name="','" value = "',"\">\n",qr/^key$/);
	print "<input type=\"hidden\" name=\"key\" value=\"invalidkeyhahaha\">";
	print '<input type="submit" value="invalidate key"></form>';

	print "<hr><pre>";
	
	print $course_env->hash2string;

	print "</pre>";

	"";
}

1;
