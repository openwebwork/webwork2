################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Hardcopy;

=head1 NAME

WeBWorK::ContentGenerator::Hardcopy - generate a PDF version of one or more
problem sets.

=cut

use strict;
use warnings;
use base qw(WeBWorK::ContentGenerator);
#use Apache::Constants qw(:common);
use CGI qw();
use File::Path qw(rmtree);
use File::Temp qw(tempdir);
use WeBWorK::DB::Classlist;
use WeBWorK::DB::WW;
use WeBWorK::Form;
use WeBWorK::Utils qw(readFile);

sub texBlockComment(@) { return "\n".("%"x80)."\n%% ".join("", @_)."\n".("%"x80)."\n\n"; }

sub initialize {
	my ($self, $singleSet, undef) = @_;
	
	my $r = $self->{r};
	my $ce = $self->{courseEnvironment};
	my @sets = $r->param("set");
	
	if (length $singleSet > 0) {
		$singleSet =~ s/^set//;
		unshift @sets, $singleSet;
	}
	
	$self->{cldb} = WeBWorK::DB::Classlist->new($ce);
	$self->{wwdb} = WeBWorK::DB::WW->new($ce);
	$self->{sets} = \@sets;
	$self->{errors} = [];
	$self->{warnings} = [];
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
	my $self = shift;
	
	STUFF: {
		my $courseName = $self->{courseEnvironment}->{courseName};
		my $userName = $self->{r}->param("effectiveUser");
		my @sets = @{$self->{sets}};

		unless (@sets) {
			print CGI::p("No problem sets were specified.");
			last STUFF;
		}

		# determine where hardcopy is going to go
		my $tempDir = $self->{courseEnvironment}->{courseDirs}->{html_temp}
			. "/hardcopy";
		my $tempURL = $self->{courseEnvironment}->{courseURLs}->{html_temp}
			. "/hardcopy";

		# make sure tempDir exists
		unless (-e $tempDir) {
			if (system "mkdir", "-p", $tempDir) {
				print CGI::p("An error occured while trying to generate your PDF hardcopy:");
				print CGI::blockquote(CGI::pre("Failed to mkdir $tempDir: $!\n"));
			}
		}

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

		# determine full URL
		my $fullURL = "$tempURL/$fileName";

		# generate TeX from sets
		my $tex = $self->getMultiSetTeX(@sets);
		#print CGI::pre($tex);

		# check for PG errors (fatal)
		if (@{$self->{errors}}) {
			my @errors = @{$self->{errors}};
			print CGI::h2("Software Errors");
			print CGI::p(<<EOF);
WeBWorK has encountered one or more software errors while attempting to process these sets.
It is likely that there are error(s) in the problem itself.
If you are a student, contact your professor to have the error(s) corrected.
If you are a professor, please consut the error output below for more informaiton.
EOF
			foreach my $error (@errors) {
				print CGI::h3("Set: ", $error->{set}, ", Problem: ", $error->{problem});
				print CGI::h4("Error messages"), CGI::blockquote(CGI::pre($error->{message}));
				print CGI::h4("Error context"), CGI::blockquote(CGI::pre($error->{context}));
			}

			last STUFF;
		}

		# "try" to generate hardcopy
		eval { $self->latex2pdf($tex, $tempDir, $fileName) };
		if ($@) {
			print CGI::p("An error occured while trying to generate your PDF hardcopy:");
			print CGI::blockquote(CGI::pre($@));
			last STUFF;
		} else {
			print CGI::p({-align=>"center"},
				CGI::big(CGI::a({-href=>$fullURL}, "Download PDF Hardcopy"))
			);
		}

		# check for PG warnings (non-fatal)
		if (@{$self->{warnings}}) {
			my @warnings = @{$self->{warnings}};
			print CGI::h2("Software Warnings");
			print CGI::p(<<EOF);
WeBWorK has encountered warnings while attempting to process these sets.
It is likely that this indicates an error or ambiguity in the problem(s) themselves.
If you are a student, contact your professor to have the problem(s) corrected.
If you are a professor, please consut the error output below for more informaiton.
EOF
			foreach my $warning (@warnings) {
				print CGI::h3("Set: ", $warning->{set}, ", Problem: ", $warning->{problem});
				print CGI::h4("Warning messages"), CGI::blockquote(CGI::pre($warning->{message}));
			}
		}
	}
	
	# feedback form
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $feedbackURL = "$root/$courseName/feedback/";
	print
		CGI::startform("POST", $feedbackURL),
		$self->hidden_authen_fields,
		CGI::hidden("module", __PACKAGE__),
		CGI::p({-align=>"right"},
			CGI::submit(-name=>"feedbackForm", -label=>"Send Feedback")
		),
		CGI::endform();
	
	return "";
}

# -----

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
	open TEX, ">", $texFile or die "Failed to open $texFile: $!\n";
	print TEX $tex;
	close TEX;
	
	# call pdflatex - we don't want to chdir in the mod_perl process, as
	# that might step on the feet of other things (esp. in Apache 2.0)
	my $pdflatex = $ce->{externalPrograms}->{pdflatex};
	system "cd $wd && $pdflatex $texFile" and die "Failed to call pdflatex: $!\n";
	
	if (-e $pdfFile) {
		# move resulting PDF file to appropriate location
		system "/bin/mv", $pdfFile, $finalFile and die "Failed to mv: $!\n";
	}
	
	# remove temporary directory
	rmtree($wd, 0, 1);
	
	-e $finalFile or die "Failed to create $finalFile for no apparent reason.\n";
}

# -----

sub getMultiSetTeX {
	my ($self, @sets) = @_;
	my $ce = $self->{courseEnvironment};
	my $tex = "";
	
	# the document preamble
	$tex .= $self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{preamble});
	
	while (defined (my $setName = shift @sets)) {
		$tex .= $self->getSetTeX($setName);
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
	my $user = $cldb->getUser($r->param("effectiveUser"));
	my $set  = $wwdb->getSet($user->id, $setName);
	my $psvn = $wwdb->getPSVN($user->id, $setName);
	
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
	
	if ($pg->{warnings} ne "") {
		push @{$self->{warnings}}, {
			set     => $setName,
			problem => $problemNumber,
			message => $pg->{warnings},
		};
	}
	
	if ($pg->{flags}->{error_flag}) {
		push @{$self->{errors}}, {
			set     => $setName,
			problem => $problemNumber,
			message => $pg->{errors},
			context => $pg->{body_text},
		};
		# if there was an error, body_text contains
		# the error context, not TeX code
		$pg->{body_text} = undef;
	}
	
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
