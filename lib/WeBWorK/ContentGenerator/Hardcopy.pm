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

sub texBlockComment { return "\n".("%"x80)."\n%% ".join("", @_)."\n".("%"x80)."\n\n"; }

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
	$self->writePDF($singleSet);
	#$self->{texFH} = \*STDOUT;
	#$self->writeMultiSetTeX($singleSet);
	
	return OK;
}

sub writePDF {
	my ($self, @sets) = @_;
	my $ce = $self->{courseEnvironment};
	my $pdflatex = $ce->{externalPrograms}->{pdflatex};
	
	open $self->{texFH}, "|-", "$pdflatex -v2" or die "Failed to call $pdflatex: $!\n";
	$self->writeMultiSetTeX(@sets);
	close $self->{texFH};
}

sub writeMultiSetTeX {
	my ($self, @sets) = @_;
	my $texFH = $self->{texFH};
	my $ce = $self->{courseEnvironment};
	
	# print the document preamble
	$self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{preamble});
	
	while (my $set = shift @sets) {
		$self->getSetTeX($set);
		if (@sets) {
			# divide sets, but not after the last set
			$self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{setDivider});
		}
	}
	
	# print the document postamble
	$self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{postamble});
}

sub getSetTeX {
	my ($self, $setName) = @_;
	my $texFH = $self->{texFH};
	my $ce = $self->{courseEnvironment};
	my $wwdb = $self->{wwdb};
	my $user = $self->{r}->param("user");
	my @problemNumbers = sort { $a <=> $b } $wwdb->getProblems($user, $setName);
	
	# get header and footer
	my $setHeader = $wwdb->getSet($user, $setName)->set_header
		|| $ce->{webworkFiles}->{hardcopySnippets}->{setHeader};
	my $setFooter = $ce->{webworkFiles}->{hardcopySnippets}->{setFooter};
	# database doesn't support the following yet :(
	#my $setFooter = $wwdb->getSet($user, $setName)->set_footer
	#	|| $ce->{webworkFiles}->{hardcopySnippets}->{setFooter};
	
	# render header
	print $texFH texBlockComment("BEGIN $setName : $setHeader");
	#print $texFH $self->getProblemTeX($setName, $setHeader);
	
	# render each problem
	while (my $problemNumber = shift @problemNumbers) {
		print $texFH texBlockComment("BEGIN $setName : $problemNumber");
		print $texFH $self->getProblemTeX($setName, $problemNumber);
		if (@problemNumbers) {
			# divide problems, but not after the last problem
			$self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{problemDivider});
		}
	}
	
	# render footer
	print $texFH texBlockComment("BEGIN $setName : $setFooter");
	print $texFH $self->getProblemTeX($setName, $setFooter);
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
		$problemNumber, # this may be non-numeric, for headers and the like
		{ # translation options
			displayMode     => "tex",
			showHints       => 0,
			showSolutions   => 0,
			processAnswers  => 0,
		},
		WeBWorK::Form->new->Vars # this is silly, i should say {} instead
	);
	
	# *** # handle errors/warnings here!
	return $pg->{body_text};
}

sub texInclude {
	my ($self, $texFile) = @_;
	my $texFH = $self->{texFH};
	
	print $texFH texBlockComment("BEGIN: $texFile");
	eval {
		print $texFH readFile($texFile)
	};
	if ($@) {
		print $texFH texBlockComment($@);
	}
}

1;
