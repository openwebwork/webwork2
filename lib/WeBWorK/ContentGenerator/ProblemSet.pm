################################################################################
# WeBWorK mod_perl (c) 1995-2002 WeBWorK Team, Univeristy of Rochester
# $Id$
################################################################################

package WeBWorK::ContentGenerator::ProblemSet;

=head1 NAME

WeBWorK::ContentGenerator::ProblemSet - display an index of the problems in a 
problem set.

=cut

use strict;
use warnings;
use base qw(WeBWorK::ContentGenerator);
use Apache::Constants qw(:common);
use CGI qw();
use WeBWorK::ContentGenerator;

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
