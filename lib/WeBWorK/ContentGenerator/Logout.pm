################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Logout;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Logout - invalidate key and display logout message.

=cut

use strict;
use warnings;
use CGI qw();

sub title {
	return "Logout";
}

sub links {
	return "";
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $userName = $r->param("user");
	
	eval { $db->deleteKey($userName) };
	if ($@) {
		print CGI::p("Something went wrong while logging out of WeBWorK: $@");
	}
	
	print CGI::p("You have been logged out of WeBWorK.");
	print CGI::start_form(-method=>"POST", -action=>"$root/$courseName/");
	print CGI::hidden("user", $userName);
	print CGI::p({-align=>"center"}, CGI::submit("submit", "Log In Again"));
	print CGI::end_form();
	
	return "";
}

# This content generator is NOT logged in.
sub if_loggedin($$) {
	my ($self, $arg) = (@_);
	
	return !$arg;
}

1;
