package WeBWorK::ProblemSets;
our @ISA = qw(WeBWorK::ContentGenerator);

use WeBWorK::ContentGenerator;
use Apache::Constants qw(:common);
use CGI qw(-compile :html :form);

sub go() {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');
	
	$self->header; return OK if $r->header_only;
	$self->top("Problem Sets for $user");
	
	print startform({-method=>"POST", -action=>$r->uri."/set4"});
	print $self->hidden_authen_fields;
	print input({-type=>"submit", -value=>"Do Set 4"});
	print endform;
	
	$self->bottom;
	
	return OK;
}

1;
