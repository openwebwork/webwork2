################################################################################
# WeBWorK mod_perl (c) 1995-2002 WeBWorK Team, Univeristy of Rochester
# $Id$
################################################################################

package WeBWorK::ContentGenerator::ProblemSet;

=head1 NAME

WeBWorK::ContentGenerator::ProblemSet - display an index of the problems in a 
problem set.

=cut

use strict;
use warnings;
use base qw(WeBWorK::ContentGenerator);
use Apache::Constants qw(:common);
use CGI qw();
use WeBWorK::ContentGenerator;

sub initialize {
	my $self = shift;
	my $courseEnvironment = $self->{courseEnvironment};
	
	# Open a database connection that we can use for the rest of
	# the content generation.
	
	my $wwdb = new WeBWorK::DB::WW $courseEnvironment;
	$self->{wwdb} = $wwdb;
}

sub path {
	my ($self, $setName, $args) = @_;
	$setName =~ s/^set//;
	
	
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		$setName => "",
	);
}

sub siblings {
	my ($self, $setName) = @_;
	$setName =~ s/^set//;
	
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};

	my $wwdb = $self->{wwdb};
	my $user = $self->{r}->param("user");
	my @sets;
	push @sets, $wwdb->getSet($user, $_) foreach ($wwdb->getSets($user));
	foreach my $set (sort { $a->open_date <=> $b->open_date } @sets) {
		if (time >= $set->open_date) {
			print CGI::a({-href=>"$root/$courseName/".$set->id."/?"
				. $self->url_authen_args}, $set->id), CGI::br();
		} else {
			print $set->id, CGI::br();
		}
	}
}

sub title {
	my ($self, $setName) = @_;
	$setName =~ s/^set//;
	
	return $setName;
}

sub body {
	my ($self, $setName) = @_;
	$setName =~ s/^set//;
	my $r = $self->{r};
	my $courseEnvironment = $self->{courseEnvironment};
	my $user = $r->param('user');
	my $wwdb = $self->{wwdb};
	
	print CGI::start_table();
	print CGI::Tr(
		CGI::th("Name"),
		CGI::th("Attempts"),
		CGI::th("Remaining"),
		CGI::th("Status"),
	);
	
	my $set = $wwdb->getSet($user, $setName);
	my @problemNumbers = $wwdb->getProblems($user, $setName);
	foreach my $problemNumber (sort { $a <=> $b } @problemNumbers) {
		my $problem = $wwdb->getProblem($user, $setName, $problemNumber);
		print $self->problemListRow($set, $problem);
	}
	
	print CGI::end_table();
	
	return "";
}

sub problemListRow($$$) {
	my $self = shift;
	my $set = shift;
	my $problem = shift;
	
	my $name = $problem->id;
	my $interactiveURL = "prob$name/?" . $self->url_authen_args;
	my $interactive = CGI::a({-href=>$interactiveURL}, "Problem $name");
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	my $remaining = $problem->max_attempts < 0
		? "unlimited"
		: $problem->max_attempts - $attempts;
	my $status = $problem->status * 100 . "%";
	
	return CGI::Tr(CGI::td([
		$interactive,
		$attempts,
		$remaining,
		$status,
	]));
}

1;
