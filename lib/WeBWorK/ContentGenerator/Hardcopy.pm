################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
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
use File::Path qw(rmtree);
use File::Temp qw(tempdir);
use WeBWorK::DB::Classlist;
use WeBWorK::DB::WW;
use WeBWorK::Form;
use WeBWorK::Utils qw(readFile);

sub texBlockComment { return "\n".("%"x80)."\n%% ".join("", @_)."\n".("%"x80)."\n\n"; }

sub initialize {
	my $self = shift;
	my $ce = $self->{courseEnvironment};
	$self->{cldb} = WeBWorK::DB::Classlist->new($ce);
	$self->{wwdb} = WeBWorK::DB::WW->new($ce);
}

sub path {
	my ($self, undef, $args) = @_;
	
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		"Hardcopy Generator" => "",
	);
}

sub title {
	return "Hardcopy Generator";
}

sub body {
	my ($self, $singleSet) = @_;
	$singleSet =~ s/^set//;
	my $r = $self->{r};
	my $ce = $self->{courseEnvironment};
	$self->{wwdb} = WeBWorK::DB::WW->new($ce);
	
	my @sets = $r->param("set");
	unshift @sets, $singleSet;
	unless (@sets) {
		print CGI::p("No problem sets were specified.");
		return OK;
	}
	
	#print CGI::pre($self->getMultiSetTeX(@sets));
	#return "";
	
	print CGI::p("Generating your hardcopy...");
	my $url = $self->makeHardcopy(@sets);
	if ($url) {
		print CGI::p("Ok, your hardcopy is ready. Click the following link to download it.");
		print CGI::p({-align=>"center"}, 
			CGI::big(CGI::a({-href=>$url}, "Download PDF Hardcopy"))
		);
	} else {
		print CGI::p("Hmm, looks like I was unable to generate the hardcopy you requested. I'm really sorry... :(");
	}
	
	return "";
}

# -----

sub makeHardcopy {
	my ($self, @sets) = @_;
	my $courseName = $self->{courseEnvironment}->{courseName};
	my $userName = $self->{r}->param("user");
	my $tempDir = $self->{courseEnvironment}->{courseDirs}->{html_temp}
		. "/hardcopy";
	my $tempURL = $self->{courseEnvironment}->{courseURLs}->{html_temp}
		. "/hardcopy";
	
	# determine name of PDF file
	my $fileName;
	if (@sets > 1) {
		# multiset output
		$fileName = "$courseName.$userName.multiset.pdf"
	} elsif (@sets == 1) {
		# only one set
		my $setName = $sets[0];
		$fileName = "$courseName.$userName.$setName.pdf";
	} else {
		$fileName = "$courseName.$userName.pdf";
	}
	my $tex = $self->getMultiSetTeX(@sets);
	$self->latex2pdf($tex, $tempDir, $fileName) or return;
	
	return "$tempURL/$fileName";
}

sub latex2pdf {
	# this is a little ad-hoc function which I will replace with a LaTeX
	# module at some point (or put it in Utils).
	my ($self, $tex, $fileBase, $fileName) = @_;
	my $finalFile = "$fileBase/$fileName";
	my $ce = $self->{courseEnvironment};
	
	# create a temporary directory for tex to shit in
	my $wd = tempdir("webwork-hardcopy-XXXXXXXX", TMPDIR => 1);
	my $texFile = "$wd/hardcopy.tex";
	my $pdfFile = "$wd/hardcopy.pdf";
	my $logFile = "$wd/hardcopy.log";
	
	# write the tex file
	local *TEX;
	open TEX, ">", $texFile;
	print TEX $tex;
	close TEX;
	
	# call pdflatex - we don't want to chdir in the mod_perl process, as
	# that might step on the feet of other things (esp. in Apache 2.0)
	my $pdflatex = $ce->{externalPrograms}->{pdflatex};
	system "cd $wd && $pdflatex $texFile";
	
	if (-e $pdfFile) {
		# move resulting PDF file to appropriate location
		my $mv = $ce->{externalPrograms}->{mv};
		system $mv, $pdfFile, $finalFile and die "Failed to mv: $!\n";
	}
	
	# remove temporary directory
	rmtree($wd, 0, 1);
	
	return -e $finalFile;
}

# -----

sub getMultiSetTeX {
	my ($self, @sets) = @_;
	my $ce = $self->{courseEnvironment};
	my $tex = "";
	
	# the document preamble
	$tex .= $self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{preamble});
	
	while (my $set = shift @sets) {
		$tex .= $self->getSetTeX($set);
		if (@sets) {
			# divide sets, but not after the last set
			$tex .= $self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{setDivider});
		}
	}
	
	# the document postamble
	$tex .= $self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{postamble});
	
	return $tex;
}

sub getSetTeX {
	my ($self, $setName) = @_;
	my $ce = $self->{courseEnvironment};
	my $wwdb = $self->{wwdb};
	my $user = $self->{r}->param("user");
	my @problemNumbers = sort { $a <=> $b } $wwdb->getProblems($user, $setName);
	
	# get header and footer
	my $setHeader = $wwdb->getSet($user, $setName)->set_header
		|| $ce->{webworkFiles}->{hardcopySnippets}->{setHeader};
	# database doesn't support the following yet :(
	#my $setFooter = $wwdb->getSet($user, $setName)->set_footer
	#	|| $ce->{webworkFiles}->{hardcopySnippets}->{setFooter};
	# so we don't allow per-set customization, which is probably okay :)
	my $setFooter = $ce->{webworkFiles}->{hardcopySnippets}->{setFooter};
	
	my $tex = "";
	
	# render header
	$tex .= texBlockComment("BEGIN $setName : $setHeader");
	$tex .= $self->getProblemTeX($setName, 0, $setHeader);
	
	# render each problem
	while (my $problemNumber = shift @problemNumbers) {
		$tex .= texBlockComment("BEGIN $setName : $problemNumber");
		$tex .= $self->getProblemTeX($setName, $problemNumber);
		if (@problemNumbers) {
			# divide problems, but not after the last problem
			$tex .= $self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{problemDivider});
		}
	}
	
	# render footer
	$tex .= texBlockComment("BEGIN $setName : $setFooter");
	$tex .= $self->getProblemTeX($setName, 0, $setFooter);
	
	return $tex;
}

sub getProblemTeX {
	my ($self, $setName, $problemNumber, $pgFile) = @_;
	my $r = $self->{r};
	my $ce = $self->{courseEnvironment};
	
	my $wwdb = $self->{wwdb};
	my $cldb = $self->{cldb};
	my $user            = $cldb->getUser($r->param("user"));
	my $set             = $wwdb->getSet($user->id, $setName);
	my $psvn            = $wwdb->getPSVN($user->id, $setName);
	
	# decide what to do about problem number
	my $problem;
	if ($problemNumber) {
		$problem = $wwdb->getProblem($user->id, $setName, $problemNumber);
	} elsif ($pgFile) {
		$problem = WeBWorK::Problem->new(
			id => 0,
			set_id => $set->id,
			login_id => $user->id,
			source_file => $pgFile,
			# the rest of Problem's fields are not needed, i think
		);
	}
	
	my $pg = WeBWorK::PG->new(
		$ce,
		$user,
		$r->param('key'),
		$set,
		$problem,
		$psvn,
		{}, # no form fields!
		{ # translation options
			displayMode     => "tex",
			showHints       => 0,
			showSolutions   => 0,
			processAnswers  => 0,
		},
	);
	
	warn "***GET READY FOR PG WARNINGS!!!!!\n***SET=$setName PROBLEM=$problemNumber\n",
		$pg->{warnings}, "***OK NO MORE PG WARNINGS!!!!\n" if $pg->{warnings};
	
	return $pg->{body_text};
}

sub texInclude {
	my ($self, $texFile) = @_;
	my $tex = "";
	
	$tex .= texBlockComment("BEGIN: $texFile");
	eval {
		$tex .= readFile($texFile)
	};
	if ($@) {
		$tex .= texBlockComment($@);
	}
	
	return $tex;
}

1;
