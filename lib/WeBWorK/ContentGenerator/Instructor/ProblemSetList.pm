package WeBWorK::ContentGenerator::Instructor::ProblemSetList;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::ProblemSetList - Entry point for Problem and Set editing

=cut

use strict;
use warnings;
use CGI qw();

sub title {
	my $self = shift;
	return "Instructor Tools - Problem Set List for ".$self->{ce}->{courseName};
}

sub body {
	my $self = shift;
	my $ce = $self->{ce};
	my $r = $self->{r};
	my $courseName = $ce->{courseName};
	my $user = $r->param('user');
	my $key  = $r->param('key');
	my $effectiveUserName = $r->param('effectiveUser');
	
	return <<EOF;

Problem sets listed here <br>

Here is an example of a problem set definition file 
<a href="/webwork/$courseName/instructor/problemSetEditor/?user=$user&amp;effectiveUser=$effectiveUserName&amp;key=$key">editor</a>


EOF

}
1;
