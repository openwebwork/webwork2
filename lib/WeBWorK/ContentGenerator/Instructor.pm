################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Instructor;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Instructor - Menu interface to the Instructor pages

=cut

use strict;
use warnings;
use CGI qw();

sub title {
	my $self = shift;
	return "Instructor tools for ".$self->{ce}->{courseName};
}

sub body {
	my $self = shift;
	my $userEditorURL = "userEditor/?" . $self->url_args;
	my $problemSetEditorURL = "problemSetEditor/?" . $self->url_args;

	return CGI::p("\n".
		CGI::a({href=>$userEditorURL}, "User Editor"). CGI::br(). "\n".
		CGI::a({href=>$problemSetEditorURL}, "Problem Set Editor").CGI::br()."\n"
	)
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu

=cut
