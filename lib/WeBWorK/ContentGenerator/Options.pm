################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Options;

=head1 NAME

WeBWorK::ContentGenerator::Options - Change user options.

=cut

use strict;
use warnings;
use base qw(WeBWorK::ContentGenerator);
use Apache::Constants qw(:common);
use CGI qw();
use WeBWorK::ContentGenerator;
use WeBWorK::DB::WW;
use WeBWorK::Utils qw(formatDateTime);

sub initialize {
	my $self = shift;
	my $r = $self->{r};
	my $ce = $self->{courseEnvironment};
	
	$self->{cldb} = WeBWorK::DB::Classlist->new($ce);
	$self->{userName} = $r->param('user');
}

sub path {
	my ($self, $args) = @_;
	
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		"User Options" => "",
	);
}

sub title {
	my $self = shift;
	my $user = $self->{cldb}->getUser($self->{userName});
	
	return "User Options for " . $user->first_name
		. " " . $user->last_name;
}

sub body {
	my $self = shift;
	
	return "";
}

1;
