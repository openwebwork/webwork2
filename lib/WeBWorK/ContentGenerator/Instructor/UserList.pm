package WeBWorK::ContentGenerator::Instructor::UserList;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::UserList - Entry point for User-specific data editing

=cut

use strict;
use warnings;
use CGI qw();

sub body {
	my ($self) = @_;
	my $r = $self->{r};
	print CGI::start_form({method=>"post", action=>$r->uri});
	print CGI::submit({name=>"assignToAll", value=>"Assign to All Users"});
	print CGI::end_form();
	
	return "";
}

1;
