package WeBWorK::ContentGenerator

# new(Apache::Request, WeBWorK::CourseEnvironment)
sub new($$$) {
	my $class = shift;
	my $self = {};
	($self->{r}, $self->{courseEnvironment}) = @_;
	bless $self, $class;
	return $self;
}

# standard_header(Apache::Request, Content-type, header => "value" ...)
#sub headers($$%) {
#	($r, $ct, %headers) = @_;
#	$r->content_type($ct);
#	foreach my $key (keys %headers) {
#		$r->header_out($key, $headers{$key}
#	}
#	$r->send_http_header;
#	
#	return 1 if $r->header_only;
#	return 0;
#}

sub go($) {
	my $self = shift;
	($r, $ct, %headers) = @_;
	$r->content_type($ct);
	foreach $key (keys %headers) {
		$r->header_out($key, $headers{$key}
	}
	$r->send_http_header;
	
	return OK if $r->header_only;
	
	
