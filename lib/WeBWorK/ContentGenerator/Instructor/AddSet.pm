package WeBWorK::ContentGenerator::Instructor::AddSet;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::AddSet - Add a set to a course

=cut

use strict;
use warnings;
use CGI qw();

sub title {
	my ($self, @components) = @_;
	return "Instructor Tools - Add a set to ".$self->{ce}->{courseName};
}

sub body {
	my ($self, @components) = @_;
	my $r = $self->{r};
	my $db = $self->{db};
	my $ce = $self->{ce};
	my $courseName = $ce->{courseName};

	print CGI::start_form({method=>"post", action=>"/webwork/$courseName/instructor/problemSetList/"});
	print CGI::p(
		"New Set Name: ", 
		CGI::input({type=>"text", name=>"newSetName", value=>""}),
		CGI::input({type=>"submit", name=>"makeNewSet", value=>"Create Set"})
	);
	print $self->hidden_authen_fields;
	print CGI::end_form();
	
	return "";
}

1;
