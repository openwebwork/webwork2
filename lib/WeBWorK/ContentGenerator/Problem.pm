package WeBWorK::ContentGenerator::Problem;
our @ISA = qw(WeBWorK::ContentGenerator);

use WeBWorK::ContentGenerator;
use Apache::Constants qw(:common);

sub title {
	my ($self, $problem_set, $problem) = @_;
	my $r = $self->{r};
	my $user = $r->param('user');
	return "Problem $problem of problem set $problem_set for $user";
}

sub body {
	my ($self, $problem_set, $problem) = @_;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');
	
	print "Problem goes here";
		
	"";
}

1;
