package WeBWorK::Authen;

sub new($$$) {
	my $class = shift;
	my $self = {};
	($self->{r}, $self->{courseEnvironment}) = @_;
	bless $self, $class;
	return $self;
}

sub verify($) {
	my $self = shift;
	my $r = $self->{r};
	if (!$r->param('user')) {
		return 0;
	}
	
	if ($r->param('key')) {
		$r->param('passwd','');
		return 1;
	}
	if ($r->param('passwd')) {
		$r->param('passwd','');
		$r->param('key','tH1siS@pH0n3Yk3y');
		return 1;
	}
	return 0;
}

1;
