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

}

1;
