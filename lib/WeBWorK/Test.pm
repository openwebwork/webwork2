package WeBWorK::Test;

sub new($$$$$) {
	my $class = shift;
	my ($r, $courseEnvironment, $user, $key) = @_;
	
	my $self = {
		r			=> $r,
		courseEnvironment	=> $courseEnvironment,
		user			=> $user,
		key			=> $key,
	};
	bless $self, $class;
	return $self;
}

sub go {
	my $self = shift;
	$self->{r}->content_type("text/html");
	$self->{r}->send_http_header;

	# get some stuff together
	my $user = $self->{user};
	my $key = $self->{key};

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
}

1;
