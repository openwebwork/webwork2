package WeBWorK::ProblemSet;
our @ISA = qw(WeBWorK::ContentGenerator);

use WeBWorK::ContentGenerator;
use Apache::Constants qw(:common);
use CGI qw(-compile :html :form);

sub go() {
	my ($self, $problem_set) = @_;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');
	
	$self->header; return OK if $r->header_only;
	$self->top("Problem set $problem_set for $user");

	print startform({-method=>"POST", -action=>$r->uri."prob2/"});
	print $self->hidden_authen_fields;
	print input({-type=>"submit", -value=>"Do Problem 2"});
	print endform;
	$self->bottom;
	
	return OK;
}

1;
