package WeBWorK::Test;

sub new($$$$$) {
	my $class = shift;
	my ($r, $courseEnvironment, $user, $key) = @_;
	
	my $self = {
		request			=> $r,
		courseEnvironment	=> $courseEnvironment,
		user			=> $user,
		key			=> $key,
	};
	bless $self, $class;
	return $self;
}

sub go {
	my $self = shift;
	$self{request}->content_type("text/html");
	$self{request}->send_http_header;
print<<EOT;
<html>
<head><title>Welcome to Hell.</title></head>
<body>
<h1>There you go.</h1>
<pre>
user = $self{user}
key = $self{key}
</pre>
</body>
</html>
EOT
}

1;
