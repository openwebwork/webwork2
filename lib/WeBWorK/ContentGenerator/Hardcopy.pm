################################################################################
# WeBWorK mod_perl (c) 1995-2002 WeBWorK Team, Univeristy of Rochester
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Hardcopy;

=head1 NAME

WeBWorK::ContentGenerator::Test - generate a PDF version of one or more
problem sets.

=cut

use strict;
use warnings;
use base qw(WeBWorK::ContentGenerator);
use Apache::Constants qw(:common);
use CGI qw();
use WeBWorK::Form;
use WeBWorK::Utils qw(readFile);

sub go {
	my ($self, $singleSet) = @_;
	$singleSet =~ s/^set//;
	my $r = $self->{r};
	my $ce = $self->{courseEnvironment};
	$self->{wwdb} = WeBWorK::DB::WW->new($ce);
	
	my @sets = $r->param("set");
	unshift @sets, $singleSet;
	return DECLINED unless @sets;
	
	$r->content_type("text/plain");
	$r->send_http_header();
	print $self->getSetTeX($singleSet);
	
	return OK;
}

sub getMultiSetTeX {
	
}

sub getSetTeX {
	my ($self, $setName) = @_;
	my $ce = $self->{courseEnvironment};
	my $wwdb = $self->{wwdb};
	my $user = $self->{r}->param("user");
	my @problemNumbers = $wwdb->getProblems($user, $setName);
	
	my $tex;
	
	# include the set preamble
	$tex .= texBlockComment("BEGIN Set: $setName Preamble");
	eval { $tex .= readFile($ce->{webworkFiles}->{paperSetPreamble}) };
	$@ and warn $@;
	
	# render the set header (problem 0 is the set header, see PG.pm)
	#$tex .= texBlockComment("BEGIN Set: $setName Header");
	#$tex .= $self->getProblemTeX($setName, 0);
	
	# render each problem
	foreach my $problemNumber (sort { $a <=> $b } @problemNumbers) {
		$tex .= texBlockComment("BEGIN Set: $setName Problem: $problemNumber");
		$tex .= $self->getProblemTeX($setName, $problemNumber);
	}
	
	# include the set postamble
	$tex .= texBlockComment("BEGIN Set: $setName Postamble");
	eval { $tex .= readFile($ce->{webworkFiles}->{paperSetPostamble}) };
	$@ and warn $@;
	
	return $tex;
}

sub getProblemTeX {
	my ($self, $setName, $problemNumber) = @_;
	my $r = $self->{r};
	my $ce = $self->{courseEnvironment};
	
	my $pg = WeBWorK::PG->new(
		$ce,
		$r->param('user'),
		$r->param('key'),
		$setName,
		$problemNumber,
		{ # translation options
			displayMode     => "tex",
			showHints       => 0,
			showSolutions   => 0,
			processAnswers  => 0,
		},
		WeBWorK::Form->new->Vars
	);
	
	return $pg->{body_text};
}

sub texBlockComment {
	return "%% \n%% " . join("", @_) . "\n%% \n";
}

1;
