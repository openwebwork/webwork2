package WeBWorK::Test;

use Apache::Request;
use Apache::Constants qw(:common);

sub new($$$) {
	my $class = shift;
	my $self = {};
	($self->{r}, $self->{courseEnvironment}) = @_;
	bless $self, $class;
	return $self;
}

sub go($) {
	my $self = shift;
	$self->{r}->content_type("text/html");
	$self->{r}->send_http_header;

	# get some stuff together
	my $user = $self->{r}->param("user");
	my $key = $self->{r}->param("key");

print<<EOT;
<html>
<head><title>Welcome to Hell.</title></head>
<body>
<h1>There you go.</h1>
<pre>
user = $user
key = $key
</pre>
</body>
</html>
EOT

	return OK;
}

1;
