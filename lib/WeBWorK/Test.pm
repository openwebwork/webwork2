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
	my $r = $self->{r};
	$r->content_type("text/html");
	$r->send_http_header;

	# get some stuff together
	my $user = $r->param("user");
	my $key = $r->param("key");

print<<EOT;
<html>
<head><title>Welcome to Hell.</title></head>
<body>
<h1>There you go.</h1>
EOT
	my @previous_data = $r->param;
	foreach my $name (@previous_data) {
		my @values = $r->param($name);
		foreach my $value (@values) {
			print "$name = $value<br>\n";
		}
	}

	print '<br><form method="POST" action="',$r->uri,'">';
	foreach my $name (@previous_data) {
		my @values = $r->param($name);
		foreach my $value (@values) {
			print "\n<input type=\"hidden\" name=\"$name\" value=\"$value\">\n";
		}
	}
	print '<input type="submit" value="repost"></form>';
	
	print '<form method="POST" action="',$r->uri,'">';
	foreach my $name (@previous_data) {
		next if ($name eq "key");
		my @values = $r->param($name);
		foreach my $value (@values) {
			print "\n<input type=\"hidden\" name=\"$name\" value=\"$value\">\n";
		}
	}
	print '<input type="submit" value="repost without key"></form>';


print<<EOT;
</body>
</html>
EOT

	return OK;
}

1;
