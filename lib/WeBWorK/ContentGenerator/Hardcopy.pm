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
use CGI qw();
use File::Path qw(rmtree);
use File::Temp qw(tempdir);
use WeBWorK::DB::Classlist;
use WeBWorK::DB::WW;
use WeBWorK::Form;
use WeBWorK::Utils qw(readFile);

sub go {
	my ($self, $singleSet) = @_;
	
	my $r = $self->{r};
	my $ce = $self->{courseEnvironment};
	my @sets = $r->param("hcSet");
	my @users = $r->param("hcUser");
	
	# add singleSet to the list of sets
	if (length $singleSet > 0) {
		$singleSet =~ s/^set//;
		unshift @sets, $singleSet unless grep { $_ eq $singleSet } @sets;
	}
	
	# default user is the effectiveUser
	unless (@users) {
		unshift @users, $r->param("effectiveUser");
	}
	
	$self->{cldb}   = WeBWorK::DB::Classlist->new($ce);
	$self->{authdb} = WeBWorK::DB::Auth->new($ce);
	$self->{wwdb}   = WeBWorK::DB::WW->new($ce);
	$self->{user}            = $self->{cldb}->getUser($r->param("user"));
	$self->{permissionLevel} = $self->{authdb}->getPermissions($r->param("user"));
	$self->{effectiveUser}   = $self->{cldb}->getUser($r->param("effectiveUser"));
	$self->{sets}  = \@sets;
	$self->{users} = \@users;
	$self->{errors}   = [];
	$self->{warnings} = [];
	
	# security checks
	my $multiSet = $self->{permissionLevel} > 0;
	my $multiUser = $self->{permissionLevel} > 0;
	if (@sets > 1 and not $multiSet) {
		$self->{generationError} = ["SIMPLE", "You are not permitted to generate hardcopy for multiple sets. Please select a single set and try again."];
	}
	if (@users > 1 and not $multiUser) {
		$self->{generationError} = ["SIMPLE", "You are not permitted to generate hardcopy for multiple users. Please select a single user and try again."];
	}
	if ($users[0] ne $self->{effectiveUser}->id and not $multiUser) {
		$self->{generationError} = ["SIMPLE", "You are not permitted to generate hardcopy for other users."];
	}
	
	unless ($self->{generationError}) {
		if ($r->param("generateHardcopy")) {
			my ($tempDir, $fileName) = eval { $self->generateHardcopy() };
			if ($@) {
				$self->{generationError} = $@;
			} else {
				my $filePath = "$tempDir/$fileName";

				$r->content_type("application/x-pdf");
				# as per RFC2183:
				$r->header_out("Content-Disposition", "attachment; filename=$fileName");
				$r->send_http_header();

				local *INPUTFILE;
				open INPUTFILE, "<", $filePath
					or die "Failed to read $filePath: $!";
				my $buf;
				while (read INPUTFILE, $buf, 16384) {
					print $buf;
				}
				close INPUTFILE;

				return;
			}
		}
	}
	
	$r->content_type("text/html");
	$r->send_http_header();
	$self->template($ce->{templates}->{system}, $singleSet);
}

# -----

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
	
	if ($self->{generationError}) {
		if (ref $self->{generationError} eq "ARRAY") {
			my ($disposition, @rest) = @{$self->{generationError}};
			if ($disposition eq "PGFAIL") {
				print $self->multiErrorOutput(@{$self->{errors}});
				return "";
			} elsif ($disposition eq "FAIL") {
				print $self->errorOutput(@rest);
				return "";
			} elsif ($disposition eq "RETRY") {
				print $self->errorOutput(@rest);
			} else { # a "simple" error
				print CGI::p(CGI::font({-color=>"red"}, @rest));
			}
		} else {
			# not something we were expecting...
			die $self->{generationError};
		}
	}
	$self->displayForm();
}

sub multiErrorOutput($@) {
	my ($self, @errors) = @_;
	
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
}

# -----

sub displayForm($) {
	my $self = shift;
	my $r = $self->{r};
	
	print CGI::start_p(), "Select the problem sets for which to generate hardcopy versions.";
	if ($self->{permissionLevel} > 0) {
		print "You may also select multiple users from the users list. You will receive hardcopy for each (set, user) pair.";
	}
	print CGI::end_p();
	
	print CGI::start_form(-method=>"POST", -action=>$r->uri);
	print $self->hidden_authen_fields();
	print CGI::h3("Options");
	print CGI::p("You may choose to show any of the following data. Correct answers and solutions are only available to privileged users or after the answer date of the problem set.");
	print CGI::p(
		CGI::checkbox(
			-name    => "showCorrectAnswers",
			-checked => $r->param("showCorrectAnswers") || 0,
			-label   => "Correct answers",
		), CGI::br(),
		CGI::checkbox(
			-name    => "showHints",
			-checked => $r->param("showHints") || 0,
			-label   => "Hints",
		), CGI::br(),
		CGI::checkbox(
			-name    => "showSolutions",
			-checked => $r->param("showSolutions") || 0,
			-label   => "Solutions",
		),
	);
	print CGI::start_table({-width=>"100%"}), CGI::start_Tr({-valign=>"top"});
	
	my $multiSet = $self->{permissionLevel} > 0;
	my $multiUser = $self->{permissionLevel} > 0;
	my $preOpenSets = $self->{permissionLevel} > 0;
	
	# set selection menu
	{
		print CGI::start_td();
		print CGI::h3("Sets");
		print CGI::start_table();
		my @sets;
		push @sets, $self->{wwdb}->getSet($self->{effectiveUser}->id, $_)
			foreach ($self->{wwdb}->getSets($self->{effectiveUser}->id));
		@sets = sort { $a->id cmp $b->id } @sets;
		foreach my $set (@sets) {
			my $checked = grep { $_ eq $set->id } @{$self->{sets}};
			my $control;
			if (time < $set->open_date and not $preOpenSets) {
				$control = "";
			} else {
				if ($multiSet) {
					$control = CGI::checkbox(
						-name=>"hcSet",
						-value=>$set->id,
						-label=>"",
						-checked=>$checked
					);
				} else {
					$control = CGI::radio_group(
						-name=>"hcSet",
						-values=>[$set->id],
						-default=>($checked ? $set->id : "-"),
						-labels=>{$set->id => ""}
					);
				}
			}
			print CGI::Tr(CGI::td([
				$control,
				$set->id,
			]));
		}
		print CGI::end_table();
		print CGI::end_td();
	}
	
	# user selection menu
	if ($multiUser) {
		print CGI::start_td();
		print CGI::h3("Users");
		print CGI::start_table();
		#print CGI::Tr(
		#	CGI::td(CGI::checkbox(-name=>"hcAllUsers", -value=>"1", -label=>"")),
		#	CGI::td({-colspan=>"2"}, "All Users"),
		#);
		#print CGI::Tr(CGI::td({-colspan=>"3"}, "&nbsp;"));
		my @users;
		push @users, $self->{cldb}->getUser($_)
			foreach ($self->{cldb}->getUsers());
		@users = sort { $a->last_name cmp $b->last_name } @users;
		foreach my $user (@users) {
			my $checked = grep { $_ eq $user->id } @{$self->{users}};
			print CGI::Tr(CGI::td([
				CGI::checkbox(-name=>"hcUser", -value=>$user->id, -label=>"", -checked=>$checked),
				$user->id,
				$user->last_name.", ".$user->first_name,
			]));
		}
		print CGI::end_table();
		print CGI::end_td();
	}
	
	print CGI::end_Tr(), CGI::end_table();
	print CGI::p({-align=>"center"},
		CGI::submit(-name=>"generateHardcopy", -label=>"Generate Hardcopy"));
	print CGI::end_form();
	
	return "";
}

sub generateHardcopy($) {
	my $self = shift;
	my @sets = @{$self->{sets}};
	my @users = @{$self->{users}};
	my $multiSet = $self->{permissionLevel} > 0;
	my $multiUser = $self->{permissionLevel} > 0;
	# sanity checks
	unless (@sets) {
		die ["RETRY", "No sets were specified."];
	}
	unless (@users) {
		die ["RETRY", "No users were specified."];
	}
	
	# determine where hardcopy is going to go
	#my $tempDir = $self->{courseEnvironment}->{courseDirs}->{html_temp} . "/hardcopy";
	my $tempDir = tempdir("webwork-hardcopy-XXXXXXXX", TMPDIR => 1);

	# make sure tempDir exists
	#unless (-e $tempDir) {
	#	if (system "mkdir", "-p", $tempDir) {
	#		die ["FAIL", "Failed to mkdir $tempDir", $!];
	#	}
	#}

	# determine name of PDF file
	my $courseName = $self->{courseEnvironment}->{courseName};
	my $fileNameSet = (@sets > 1 ? "multiset" : $sets[0]);
	my $fileNameUser = (@users > 1 ? "multiuser" : $users[0]);
	my $fileName = "$courseName.$fileNameUser.$fileNameSet.pdf";
	
	# for each user ... generate TeX for each set
	my $tex;
	foreach my $user (@users) {
		$tex .= $self->getMultiSetTeX(@sets);
	}
	
	# deal with PG errors
	if (@{$self->{errors}}) {
		die ["PGFAIL"];
	}
	
	# "try" to generate pdf
	eval { $self->latex2pdf($tex, $tempDir, $fileName) };
	if ($@) {
		die ["FAIL", "Failed to generate PDF from tex", $@];
	}
	
	return $tempDir, $fileName;
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
	my $pdflatexResult = system "cd $wd && $pdflatex $texFile";
	if ($pdflatexResult) {
		# something bad happened
		my $textErrorMessage = "Call to $pdflatex failed: $!\n";
		if (-e $logFile) {
			$textErrorMessage .= "pdflatex ran, but did not succeed. This suggests an error in the TeX\n";
			$textErrorMessage .= "version of one of the problems, or a problem with the pdflatex system.\n";
			my $logFileContents = eval { readFile($logFile) };
			if ($@) {
				$textErrorMessage .= "Additionally, the pdflatex log file could not be read, though it exists.\n";
			} else {
				$textErrorMessage .= "The contents of the TeX log are as follows:\n\n";
				$textErrorMessage .= "$logFileContents\n\n";
			}
		} else {
			$textErrorMessage .= "No log file was created, suggesting that pdflatex never ran. Check the WeBWorK\n";
			$textErrorMessage .= "configuration to ensure that the path to pdflatex is correct.\n";
		}
		die $textErrorMessage;
	}
	
	if (-e $pdfFile) {
		# move resulting PDF file to appropriate location
		system "/bin/mv", $pdfFile, $finalFile and die "Failed to mv: $!\n";
	}
	
	# remove temporary directory
	rmtree($wd, 0, 1);
	
	-e $finalFile or die "Failed to create $finalFile for no apparent reason.\n";
}

# -----

sub texBlockComment(@) { return "\n".("%"x80)."\n%% ".join("", @_)."\n".("%"x80)."\n\n"; }

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
	my $effectiveUserName = $self->{effectiveUser}->id;
	my @problemNumbers = sort { $a <=> $b } $wwdb->getProblems($effectiveUserName, $setName);
	
	# get header and footer
	my $setHeader = $wwdb->getSet($effectiveUserName, $setName)->set_header
		|| $ce->{webworkFiles}->{hardcopySnippets}->{setHeader};
	# database doesn't support the following yet :(
	#my $setFooter = $wwdb->getSet($effectiveUserName, $setName)->set_footer
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
	
	my $wwdb   = $self->{wwdb};
	my $cldb   = $self->{cldb};
	my $authdb = $self->{authdb};
	my $effectiveUser = $self->{effectiveUser};
	my $permissionLevel = $self->{permissionLevel};
	my $set  = $wwdb->getSet($effectiveUser->id, $setName);
	my $psvn = $wwdb->getPSVN($effectiveUser->id, $setName);
	
	# decide what to do about problem number
	my $problem;
	if ($problemNumber) {
		$problem = $wwdb->getProblem($effectiveUser->id, $setName, $problemNumber);
	} elsif ($pgFile) {
		$problem = WeBWorK::Problem->new(
			id => 0,
			set_id => $set->id,
			login_id => $effectiveUser->id,
			source_file => $pgFile,
			# the rest of Problem's fields are not needed, i think
		);
	}
	
	# figure out if we're allowed to get solutions and call PG->new accordingly.
	my $showCorrectAnswers = $r->param("showCorrectAnswers") || 0;
	my $showHints          = $r->param("showHints") || 0;
	my $showSolutions      = $r->param("showSolutions") || 0;
	unless ($permissionLevel > 0 or time > $set->answer_date) {
		$showCorrectAnswers = 0;
		$showSolutions      = 0;
	}
	
	my $pg = WeBWorK::PG->new(
		$ce,
		$effectiveUser,
		$r->param('key'),
		$set,
		$problem,
		$psvn,
		{}, # no form fields!
		{ # translation options
			displayMode     => "tex",
			showHints       => $showHints,
			showSolutions   => $showSolutions,
			processAnswers  => $showCorrectAnswers,
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
	} else {
		# append list of correct answers to body text
		if ($showCorrectAnswers && $problemNumber != 0) {
			my $correctTeX = "Correct Answers:\\par\\begin{itemize}\n";
			foreach my $ansName (@{$pg->{flags}->{ANSWER_ENTRY_ORDER}}) {
				my $correctAnswer = $pg->{answers}->{$ansName}->{correct_ans};
				$correctAnswer =~ s/\^/\\\^\{\}/g;
				$correctAnswer =~ s/\_/\\\_/g;
				$correctTeX .= "\\item $correctAnswer\n";
			}
			$correctTeX .= "\\end{itemize} \\par\n";
			$pg->{body_text} .= $correctTeX;
		}
	}
	warn "BODY TEXT=\n", $pg->{body_text}, "\n\n";
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
