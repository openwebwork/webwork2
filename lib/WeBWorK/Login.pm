package WeBWorK::Login;

sub new($$$) {
	my $class = shift;
	my $self = {};
	($self->{r}, $self->{courseEnvironment}) = @_;
	bless $self, $class;
	return $self;
}

sub go($) {
	my $self = shift;
	my $r = $self->{r};
	my $course_env = $self->{courseEnvironment};
	# get some stuff together
	my $user = $r->param("user");
	my $key = $r->param("key");
	my $passwd = $r->param("passwd");
	my $course = $course_env->{"courseName"};
	
	
	$r->content_type("text/html");
	$r->send_http_header;
    	print '<html><head><title>WeBWorK Login Page</title></head><body>',
	  '<h1>WeBWorK Login Page</h1>',
	  "Please enter your username and password for <b>",
	  $course,
	  "</b> below: <p>",
	  '<form method="POST" action="',$r->uri,'">';
	
	# write out the form data posted to the requested URI
	my @previous_data = $r->param;
	foreach my $name (@previous_data) {
		next if ($name =~ /^(user|passwd|key)$/);
		my @values = $r->param($name);
		foreach my $value (@values) {
			print "\n<input type=\"hidden\" name=\"$name\" value=\"$value\">\n";
		}
	}
	
	print '<input type="textfield" name="user" value="',$user,'"><br>',
	  '<input type="password" name="passwd" value="',$passwd,'"><br>',
	  '<input type="submit" value="Continue">',
	  '</form></body></html>';

	return OK;
}

1;
