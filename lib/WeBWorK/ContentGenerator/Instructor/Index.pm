################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Instructor::Index;
use base qw(WeBWorK::ContentGenerator::Instructor);

=head1 NAME

WeBWorK::ContentGenerator::Instructor::Index - Menu interface to the Instructor pages

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
	my $userEditorURL = "userList/?" . $self->url_args;
	my $problemSetEditorURL = "problemSetList/?" . $self->url_args;
	my $courseName = $self->{ce}->{courseName};

	return CGI::p("\n".
		CGI::a({href=>$userEditorURL}, "Users"). " - View and edit data and settings for users of $courseName" . CGI::br(). "\n".
		CGI::a({href=>$problemSetEditorURL}, "Problem Sets"). " - View and edit settings for problem sets in $courseName".CGI::br()."\n"
	)
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu

=cut
