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

sub title {
	my $self = shift;
	my $r = $self->{r};
	
	my $error = $r->param("error");
	
	if (!defined $error  or $error eq "") {
		return "An Error Occurred";
	} else {
		return $error;
	}
}

sub body {
	my $self = shift;
	my $r = $self->r;
	
	my $msg = $r->param("msg");
	
	if (!defined $msg or $msg eq "") {
		return $self->errorOutput();
	} else {
		return $msg;
	}
}

sub errorOutput() {
	return "An error has occured while processing the requested action.  
		If you typed a URL, check that it is correct.  
		If you submitted a form, you may not have entered all the necessary information.  
		If you believe there is a bug, please report it to your professor.";
}

1;
