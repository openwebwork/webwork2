package WeBWorK::ContentGenerator::ProblemSet;
our @ISA = qw(WeBWorK::ContentGenerator);

use strict;
use warnings;
use WeBWorK::ContentGenerator;
use Apache::Constants qw(:common);
use CGI qw();

sub title {
	my ($self, $problem_set) = @_;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');

	return "Problem set $problem_set for $user";
}

sub body {
	my ($self, $problem_set) = @_;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');
	
	print CGI->startform({-method=>"POST", -action=>$r->uri."prob2/"});
	print $self->hidden_authen_fields;
	print CGI->input({-type=>"submit", -value=>"Do Problem 2"});
	print CGI->endform();
	"";
}

1;
