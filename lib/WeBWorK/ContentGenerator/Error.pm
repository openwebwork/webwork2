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
#	my $self = shift;
	my ($self, $setID, $problemID, $error, $msg) = @_;

}

sub path {
	my ($self, $setID, $problemID, $error, $msg) = @_;

#	my $self = shift;
	my $args = $_[-1];
	return $self->pathMacro($args, Home => "../", Error => "");
}

sub siblings {
	my ($self, $setID, $problemID, $error, $msg) = @_;

#	my $self = shift;
	return "";
}

sub nav {
	my ($self, $setID, $problemID, $error, $msg) = @_;

#	my $self = shift;
	return "";
}

sub title {
	my ($self, $setID, $problemID, $error, $msg) = @_;
#	my $self = shift;
#	my $error = shift;
	(!defined $error or $error eq "") ? return "An Error Occurred" : return $error;
}

sub body {
	my ($self, $setID, $problemID, $error, $msg) = @_;

#	my $self = shift;
#	my $error = shift;
#	my $msg = shift;
	my $formFields = WeBWorK::Form->new_from_paramable($self->{r});
	my $courseEnvironment = $self->{ce};
	( defined $msg and $msg eq "") ? return $self->errorOutput() : return $msg;
}

1;
