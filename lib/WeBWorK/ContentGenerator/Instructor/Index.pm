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
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $courseName = $ce->{courseName};
	my $authen_args = $self->url_authen_args();

	my $prof_url = $ce->{webworkURLs}->{oldProf};
	my $full_url = "$prof_url?course=$courseName&$authen_args";
	my $userEditorURL = "userList/?" . $self->url_args;
	my $problemSetEditorURL = "problemSetList/?" . $self->url_args;

	return 
		CGI::p("\n".
			CGI::a({href=>$userEditorURL}, "Users"). " - View and edit data and settings for users of $courseName" . CGI::br(). "\n".
			CGI::a({href=>$problemSetEditorURL}, "Problem Sets"). " - View and edit settings for problem sets in $courseName".CGI::br()."\n"
		)."\n".CGI::hr()."\n".
		CGI::p(
			CGI::b("NOTE: ") . 
			"The Instructor Tools in this preview release of WeBWorK
			2.0 are not stable or complete.  If you reliable and
			stable course editing features, than at this time you
			will need to use the Professor tools from WeBWorK 1.8
			or earlier.  Use the links below to go to the Professor
			pages of your system's WeBWorK 1.x installation."
		)."\n".
		CGI::ul(
			CGI::li(
				CGI::a({-href=>$full_url}, "Go to Professor pages")
			). 
			CGI::li(
				CGI::a({-href=>$full_url, -target=>"_new"}, "Open Professor pages in new window")
			)
		);
}

1;

__END__

=head1 AUTHOR

Written by Dennis Lambe Jr., malsyned (at) math.rochester.edu

=cut
