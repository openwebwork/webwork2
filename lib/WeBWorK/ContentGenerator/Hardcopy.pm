################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Hardcopy;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::Hardcopy - generate a PDF version of one or more
problem sets.

=cut

use strict;
use warnings;
use CGI qw();
use File::Path qw(rmtree);
use WeBWorK::Form;
use WeBWorK::Utils qw(readFile makeTempDirectory);

sub go {
	my ($self, $singleSet) = @_;
	
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
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
	
	$self->{user}            = $db->getUser($r->param("user"));
	$self->{permissionLevel} = $db->getPermissionLevel($r->param("user"))->permission();
	$self->{effectiveUser}   = $db->getUser($r->param("effectiveUser"));
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
	if ($users[0] ne $self->{effectiveUser}->user_id and not $multiUser) {
		$self->{generationError} = ["SIMPLE", "You are not permitted to generate hardcopy for other users."];
	}
	
	unless ($self->{generationError}) {
		if ($r->param("generateHardcopy")) {
			my ($tempDir, $fileName,$errors) = eval { $self->generateHardcopy() };
			
			if ($@) {
				$self->{generationError} = $@;
				# In this case no correct pdf file was generated.
				# there is not much more that can be done
				# throw the error up higher.
				# The error is reported in body.
				# the tempDir was removed in generateHardcopy
				
				
			} else {
				my $filePath = "$tempDir/$fileName";
				# FIXME this is taking up server time
				# why not move the file to the tempDir and let the browser pick it up on redirect?
				# my $hardcopyFilePath     =  $self->{hardcopyFilePath};
				# my $hardcopyFileURL      =  $self->{hardcopyFileURL};
				if ($errors eq '') {
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
	
					rmtree($tempDir);
				} else {
				
				}

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
	
	my $ce = $self->{ce};
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
				$self->multiErrorOutput(@{$self->{errors}});
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
	if (@{$self->{warnings}}) {
		# FIXME: this code will only be reached if there was also a
		# generation error, because otherwise the module will send
		# the PDF instead. DAMN!
		$self->multiWarningOutput(@{$self->{warnings}});
	}
	$self->displayForm();
}

sub multiErrorOutput($@) {
	my ($self, @errors) = @_;
	
	print CGI::h2("Software Errors");
	print CGI::p(<<EOF);
WeBWorK has encountered one or more software errors while attempting to process
these problem sets. It is likely that there are errors in the problems
themselves. If you are a student, contact your professor to have the errors
corrected. If you are a professor, please consut the error output below for
more informaiton.
EOF
	foreach my $error (@errors) {
		print CGI::h3("Set: ", $error->{set}, ", Problem: ", $error->{problem});
		print CGI::h4("Error messages"), CGI::blockquote(CGI::pre($error->{message}));
		print CGI::h4("Error context"), CGI::blockquote(CGI::pre($error->{context}));
	}
}

sub multiWarningOutput($@) {
	my ($self, @warnings) = @_;
	
	print CGI::h2("Software Warnings");
	print CGI::p(<<EOF);
WeBWorK has encountered one or more warnings while attempting to process these
problem sets. It is likely that this indicates errors or ambiguitiees in the
problems themselves. If you are a student, contact your professor to have the
problems corrected. If you are a professor, please consut the warning output
below for more informaiton.
EOF
	foreach my $warning (@warnings) {
		print CGI::h3("Set: ", $warning->{set}, ", Problem: ", $warning->{problem});
		print CGI::h4("Error messages"), CGI::blockquote(CGI::pre($warning->{message}));
	}
}

# -----

sub displayForm($) {
	my $self = shift;
	my $r = $self->{r};
	my $db = $self->{db};
	
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
		push @sets, $db->getMergedSet($self->{effectiveUser}->user_id, $_)
			foreach ($db->listUserSets($self->{effectiveUser}->user_id));
		@sets = sort { $a->set_id cmp $b->set_id } @sets;
		foreach my $set (@sets) {
			my $checked = grep { $_ eq $set->set_id } @{$self->{sets}};
			my $control;
			if (time < $set->open_date and not $preOpenSets) {
				$control = "";
			} else {
				if ($multiSet) {
					$control = CGI::checkbox(
						-name=>"hcSet",
						-value=>$set->set_id,
						-label=>"",
						-checked=>$checked
					);
				} else {
					$control = CGI::radio_group(
						-name=>"hcSet",
						-values=>[$set->set_id],
						-default=>($checked ? $set->set_id : "-"),
						-labels=>{$set->set_id => ""}
					);
				}
			}
			print CGI::Tr(CGI::td([
				$control,
				$set->set_id,
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
		push @users, $self->{db}->getUser($_)
			foreach ($self->{db}->listUsers());
		@users = sort { $a->last_name cmp $b->last_name } @users;
		foreach my $user (@users) {
			my $checked = grep { $_ eq $user->user_id } @{$self->{users}};
			print CGI::Tr(CGI::td([
				CGI::checkbox(-name=>"hcUser", -value=>$user->user_id, -label=>"", -checked=>$checked),
				$user->user_id,
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
	my $ce = $self->{ce};
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
	my $tempDir = makeTempDirectory($ce->{webworkDirs}->{tmp}, "webwork-hardcopy");
	
	# determine name of PDF file  #FIXME it might be best to have the effective user in here somewhere
	my $courseName = $self->{ce}->{courseName};
	my $fileNameSet = (@sets > 1 ? "multiset" : $sets[0]);
	my $fileNameUser = (@users > 1 ? "multiuser" : $users[0]);
	my $fileName = "$courseName.$fileNameUser.$fileNameSet.pdf";
	
	# for each user ... generate TeX for each set
	my $tex;
	#
	# the document tex preamble
	$tex .= $self->texInclude($self->{ce}->{webworkFiles}->{hardcopySnippets}->{preamble});
	# separate users by page break, or something
	foreach my $user (@users) {
		$tex .=  $self->getMultiSetTeX($user, @sets);
	    if (@users) {
			# separate users, but not after the last set
			$tex .= $self->texInclude($self->{ce}->{webworkFiles}->{hardcopySnippets}->{userDivider});
		}
		
	}
	# the document postamble
	$tex .= $self->texInclude($self->{ce}->{webworkFiles}->{hardcopySnippets}->{postamble});
	
	# deal with PG errors
	if (@{$self->{errors}}) {
		die ["PGFAIL"];
	}
	
	# FIXME: add something like:
	#if (@{$self->{warnings}}) {
	#	$self->{generationWarnings} = 1;
	#}
	# ???????
	
	# "try" to generate pdf
	my $errors = '';
	eval { $self->latex2pdf($tex, $tempDir, $fileName) };
	if ($@) {
	    $errors = $@;
	    #$errors =~ s/\n/<br>/g;  # make this readable on HTML FIXME make this a Utils. filter (Error2HTML)
	    # clean up temp directory
	    rmtree($tempDir);
		die ["FAIL", "Failed to generate PDF from tex", $errors]; #throw error to subroutine body	
	}
	
	return $tempDir, $fileName;
}

# -----

sub latex2pdf {
	# this is a little ad-hoc function which I will replace with a LaTeX
	# module at some point (or put it in Utils).
	my ($self, $tex, $tempDir, $fileName) = @_;
	my $finalFile = "$tempDir/$fileName";
	my $ce = $self->{ce};
	
	# Location for hardcopy file to be downloaded
	# FIXME  this should use surePathToTmpFile
	my $hardcopyTempDirectory = $ce->{courseDirs}->{html_temp}."/hardcopy";
	mkdir ($hardcopyTempDirectory)  or die "Unable to make $hardcopyTempDirectory" unless -e $hardcopyTempDirectory;
	my $hardcopyFilePath        =  "$hardcopyTempDirectory/$fileName";
	my $hardcopyFileURL         =  $ce->{courseURLs}->{html_temp}."/hardcopy/$fileName";
	$self->{hardcopyFilePath}   =  $hardcopyFilePath;
	$self->{hardcopyFileURL}    =  $hardcopyFileURL;
	## create a temporary directory for tex to shit in
	#my $wd = tempdir("webwork-hardcopy-XXXXXXXX", TMPDIR => 1);
	# - we're using the existing temp dir. now
	
	my $wd = $tempDir;
	my $texFile = "$wd/hardcopy.tex";
	my $pdfFile = "$wd/hardcopy.pdf";
	my $logFile = "$wd/hardcopy.log";
	
	# write the tex file
	local *TEX;
	open TEX, ">", $texFile or die "Failed to open $texFile: $!\n".CGI::br();
	print TEX $tex;
	close TEX;
	
	# call pdflatex - we don't want to chdir in the mod_perl process, as
	# that might step on the feet of other things (esp. in Apache 2.0)
	my $pdflatex = $ce->{externalPrograms}->{pdflatex};
	my $pdflatexResult = system "cd $wd && $pdflatex $texFile";	
	
	# Even with errors there may be a valid pdfFile.  Move it to where we can get it.
	if (-e $pdfFile) {
		# move resulting PDF file to appropriate location
		# FIXME don't fix everything at once :-)
		system "/bin/mv", $pdfFile, $finalFile
			and die "Failed to mv: $pdfFile to $finalFile<br>\n  Quite likely this means that there ".
			        "is not sufficient write permission for some directory.<br>$!<br>\n";
       # moving to course tmp/hardcopy directory
# 	    system "/bin/mv", $pdfFile, $hardcopyFilePath  
# 			and die "Failed to mv: $pdfFile to  $hardcopyFilePath<br> Quite likely this means that there ".
# 			        "is not sufficient write permission for some directory.<br>$!\n".CGI::br(); 
	}
	# Alert the world that the tex file did not process perfectly.
	if ($pdflatexResult) {
		# something bad happened
		my $textErrorMessage = "Call to $pdflatex failed: $!\n".CGI::br();
		
		# move what output there is to someplace where it can be read
		system "/bin/mv", $finalFile, $hardcopyFilePath  
			    and die "Failed to mv: $pdfFile to  $hardcopyFilePath<br> Quite likely this means that there ".
			            "is not sufficient write permission for some directory.<br>$!\n".CGI::br(); 
		if (-e $hardcopyFilePath ) {
			 # FIXME  Misuse of html tags!!!
			$textErrorMessage.= "<h4>Some pdf output was produced and is available ". CGI::a({-href=>$hardcopyFileURL},"here.</h4>").CGI::hr();
		}
		# report logfile
		if (-e $logFile) {
			$textErrorMessage .= "pdflatex ran, but did not succeed. This suggests an error in the TeX\n".CGI::br();
			$textErrorMessage .= "version of one of the problems, or a problem with the pdflatex system.\n".CGI::br();
			my $logFileContents = eval { readTexErrorLog($logFile) };
			$logFileContents    .=  CGI::hr().CGI::hr();
			$logFileContents    .= eval { formatTexFile($texFile)     };
			if ($@) {
				$textErrorMessage .= "Additionally, the pdflatex log file could not be read, though it exists.\n".CGI::br();
			} else {
				$textErrorMessage .= "The essential contents of the TeX log are as follows:\n".CGI::hr().CGI::br();
				$textErrorMessage .= "$logFileContents\n".CGI::br().CGI::br();
			}
		} else {
			$textErrorMessage .= "No log file was created, suggesting that pdflatex never ran. Check the WeBWorK\n".CGI::br();
			$textErrorMessage .= "configuration to ensure that the path to pdflatex is correct.\n".CGI::br();
		}
		die $textErrorMessage;
	}
	

	
	## remove temporary directory
	##FIXME  rmtree is commented out only for debugging purposes.
	##print STDERR "tex temp directory at $wd";
	#rmtree($wd, 0, 0);
	# - not creating the temp dir here anymore
	
	-e $finalFile or die "Failed to create $finalFile for no apparent reason.\n";
}

# -----
# FIXME move to Utils? probably not

sub readTexErrorLog {
	my $filePath = shift;
	my $print_error_switch = 0;
	my $line='';
	my @message=();
	#local($/ ) = "\n";
    open(LOGFILE,"<$filePath") or die "Can't read $filePath";
    while (<LOGFILE>) {
	    $line = $_;
	    $print_error_switch = 1  if $line =~ /^!/;  # after a fatal error start printing messages
		push(@message, protect_HTML($line)) if $print_error_switch;
    }
    close(LOGFILE);
    join("<br>\n",@message);
}

sub formatTexFile {
	my $texFilePath   = shift;
    open (TEXFILE, "$texFilePath")
	               or die "Can't open tex source file: path= $texFilePath: $!";
	
	my @message       = ();
    push @message, '<BR>\n<h3>TeX Source File:</h3><BR>\n',     ;
 
    my $lineNumber    = 1;
    while (<TEXFILE>) {
		push @message, protect_HTML("$lineNumber $_")."\n";
        $lineNumber++;
    }
    close(TEXFILE);
    #push @message, '</pre>';
    join("<br>\n",@message);
}
sub protect_HTML {
	my $line = shift;
	chomp($line);
	$line =~s/\&/&amp;/g;
	$line =~s/</&lt;/g;
	$line =~s/>/&gt;/g;
	$line;
}
sub texBlockComment(@) { return "\n".("%"x80)."\n%% ".join("", @_)."\n".("%"x80)."\n\n"; }

sub getMultiSetTeX {
	my ($self, $effectiveUserName,@sets) = @_;
	my $ce = $self->{ce};
	my $tex = "";
	
	
	
	while (defined (my $setName = shift @sets)) {
		$tex .= $self->getSetTeX($effectiveUserName, $setName);
		if (@sets) {
			# divide sets, but not after the last set
			$tex .= $self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{setDivider});
		}
	}
	

	
	return $tex;
}

sub getSetTeX {
	my ($self, $effectiveUserName,$setName) = @_;
	my $ce = $self->{ce};
	my $db = $self->{db};
	
	# FIXME (debug code line next)
	# print STDERR "Creating set $setName for $effectiveUserName \n";
	
	# FIXME We could define a default for the effective user if no correct name is passed in.
	# I'm not sure that it is wise.
	my $effectiveUser = $db->getUser($effectiveUserName);
	
	my @problemNumbers = sort { $a <=> $b }
		$db->listUserProblems($effectiveUserName, $setName);
	
	# get header and footer
	my $setHeader = $db->getMergedSet($effectiveUserName, $setName)->set_header
		|| $ce->{webworkFiles}->{hardcopySnippets}->{setHeader};
	# database doesn't support the following yet :(
	#my $setFooter = $wwdb->getMergedSet($effectiveUserName, $setName)->set_footer
	#	|| $ce->{webworkFiles}->{hardcopySnippets}->{setFooter};
	# so we don't allow per-set customization, which is probably okay :)
	my $setFooter = $ce->{webworkFiles}->{hardcopySnippets}->{setFooter};
	
	my $tex = "";
	
	# render header
	$tex .= texBlockComment("BEGIN $setName : $setHeader");
	$tex .= $self->getProblemTeX($effectiveUser,$setName, 0, $setHeader);
	
	# render each problem
	while (my $problemNumber = shift @problemNumbers) {
		$tex .= texBlockComment("BEGIN $setName : $problemNumber");
		$tex .= $self->getProblemTeX($effectiveUser,$setName, $problemNumber);
		if (@problemNumbers) {
			# divide problems, but not after the last problem
			$tex .= $self->texInclude($ce->{webworkFiles}->{hardcopySnippets}->{problemDivider});
		}
	}
	
	# render footer
	$tex .= texBlockComment("BEGIN $setName : $setFooter");
	$tex .= $self->getProblemTeX($effectiveUser,$setName, 0, $setFooter);
	
	return $tex;
}

sub getProblemTeX {
	my ($self, $effectiveUser, $setName, $problemNumber, $pgFile) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	
	# Should we provide a default user ? I think not FIXME
	
	# $effectiveUser = $self->{effectiveUser} unless defined($effectiveUser);
	my $permissionLevel = $self->{permissionLevel};
	my $set  = $db->getMergedSet($effectiveUser->user_id, $setName);
	my $psvn = $set->psvn();
	
	# decide what to do about problem number
	my $problem;
	if ($problemNumber) {
		$problem = $db->getMergedProblem($effectiveUser->user_id, $setName, $problemNumber);
	} elsif ($pgFile) {
		$problem = WeBWorK::DB::Record::UserProblem->new(
			set_id => $set->set_id,
			problem_id => 0,
			login_id => $effectiveUser->user_id,
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
