package WeBWorK::ContentGenerator::ProblemSets;
our @ISA = qw(WeBWorK::ContentGenerator);

use WeBWorK::ContentGenerator;
use Apache::Constants qw(:common);
use CGI qw(-compile :html :form);

sub title {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');

	return "Problem Sets for $user";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');
	
	print startform({-method=>"POST", -action=>$r->uri."set0/"});
	print $self->hidden_authen_fields;
	print input({-type=>"submit", -value=>"Do Set 0"});
	print endform;
	"";
}

1;
