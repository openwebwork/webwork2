################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Professor;

=head1 NAME

WeBWorK::ContentGenerator::Professor - Provide Professor tools

=cut

use strict;
use warnings;
use base qw(WeBWorK::ContentGenerator);
use Apache::Constants qw(:common);
use CGI qw();
use WeBWorK::ContentGenerator;
use WeBWorK::Utils qw(formatDateTime dequoteHere);

sub path {
	my ($self, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		"Professor" => "",
	);
}

sub title {
	my $self = shift;
	
	return "Professor Tools";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $course_env = $self->{ce};
	my $course_name = $course_env->{courseName};
	my $authen_args = $self->url_authen_args();
	my $prof_url = $course_env->{webworkURLs}->{oldProf};
	my $full_url = "$prof_url?course=$course_name&$authen_args";
	
	print CGI::p(<<EOF), "\n";
This preview release of WeBWorK 2.0 does not include Professor Tools.  
You will need to use the professor tools from WeBWorK 1.8 or earlier.
Use the links below to go to the Professor pages of your system's
WeBWorK 1.x installation.
EOF
	print CGI::ul(
		CGI::li(
			CGI::a({-href=>$full_url}, "Go to Professor pages")
		), 
		CGI::li(
			CGI::a({-href=>$full_url, -target=>"_new"}, "Open Professor pages in new window")
		)
	), "\n";
	
	return "";
}

1;
