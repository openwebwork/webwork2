package WeBWorK::Test;

# This file will cease to be as soon as the real content generation modules
# have been written.  However, there's always reason to keep it around, as
# it showcases many things that new content generators will want to do,
# since it's generally where I dump new functionality before I put it in any
# end-user modules.

use Apache::Request;
use Apache::Constants qw(:common);
use WeBWorK::ContentGenerator;

our @ISA = qw(WeBWorK::ContentGenerator);

sub go() {
	my $self = shift;
	my $r = $self->{r};
	my $course_env = $self->{courseEnvironment};
	$r->content_type("text/html");
	$r->send_http_header;

	# get some stuff together
	my $user = $r->param("user");
	my $key = $r->param("key");
	my $uri = $r->uri;

print<<EOT;
<html>
<head><title>Welcome to Hell.</title></head>
<body>
<h1>There you go.</h1>
<p>You're now accessing $uri.</p>
EOT
	$self->print_form_data(""," = ","<br>");
	
	print "<hr><pre>";
	
	print $course_env->hash2string;

	print "</pre>";
		
	print '<br><form method="POST" action="',$r->uri,'">';
	$self->print_form_data('<input type="hidden" name="','" value = "',"\">\n");
	print '<input type="submit" value="repost"></form>';
	
	print '<form method="POST" action="',$r->uri,'">';
	$self->print_form_data('<input type="hidden" name="','" value = "',"\">\n",qr/^key$/);
	print "<input type=\"hidden\" name=\"key\" value=\"invalidkeyhahaha\">";
	print '<input type="submit" value="invalidate key"></form>';


print<<EOT;
</body>
</html>
EOT

	return OK;
}

1;
