################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Error;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Error - display debugging information.

=cut

use strict;
use warnings;
use CGI qw();
use WeBWorK::Form;
use WeBWorK::Utils qw(ref2string);

sub initialize {
	my $self = shift;
}

sub path {
	my $self = shift;
	my $r = $self->{r};
	my $problemID = $r->param("problem");
	my $args = $_[-1];

	#make sure the Home link will point to the right place
	my $home = (defined $problemID && $problemID ne "") ? "../../" : "../";

	return $self->pathMacro($args, Home => $home, Error => "");
}

sub siblings {
	my $self = shift;

	return "";	
}

sub nav {
	my $self = shift;

	return "";
}

sub title {
	my $self = shift;
	my $r = $self->{r};
	my $error = $r->param("error");

	(!defined $error  or $error eq "") ? return "An Error Occurred" : return $error;
}

sub body {
	my $self = shift;
	my $r = $self->{r};
	my $error = $r->param("error");
	my $msg = $r->param("msg");

	my $formFields = WeBWorK::Form->new_from_paramable($self->{r});
	my $courseEnvironment = $self->{ce};
	( !defined $msg or $msg eq "") ? return $self->errorOutput() : return $msg;
}

sub errorOutput() {
	return "An error has occured while processing the requested action.  
		If you typed a URL, check that it is correct.  
		If you submitted a form, you may not have entered all the necessary information.  
		If you believe there is a bug, please report it to your professor.";
}
1;
