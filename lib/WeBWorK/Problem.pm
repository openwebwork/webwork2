package WeBWorK::Problem;
our @ISA = qw(WeBWorK::ContentGenerator);

use WeBWorK::ContentGenerator;
use Apache::Constants qw(:common);

sub go() {
	my ($self, $problem_set, $problem) = @_;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');
	
	$self->header; return OK if $r->header_only;
	$self->top("Problem $problem of problem set $problem_set for $user");
	$self->bottom;
	
	return OK;
}

1;
