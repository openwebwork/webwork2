################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader$
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package WeBWorK::ContentGenerator::GatewayQuiz;
use base qw(WeBWorK::ContentGenerator);
use File::Path qw(rmtree);
use WeBWorK::Form;
use WeBWorK::PG;
use WeBWorK::PG::IO;
use WeBWorK::Utils qw(writeLog encodeAnswers decodeAnswers ref2string makeTempDirectory);
use WeBWorK::DB::Utils qw(global2user user2global findDefaults);

=head1 NAME

WeBWorK::ContentGenerator::GatewayQuiz - display an index of the problems in a 
problem set. (modifying this from ProblemSet.pm)

=cut

use strict;
use warnings;
use CGI qw();

sub pre_header_initialize {
	my ($self, $setName)     = @_;
	my $r                    = $self->{r};
	my $courseEnv            = $self->{ce};
	my $db                   = $self->{db};
	my $userName             = $r->param('user');
	my $effectiveUserName    = $r->param('effectiveUser');
	my $key					 = $r->param('key');
	my $user                 = $db->getUser($userName);
	my $effectiveUser        = $db->getUser($effectiveUserName);
	
	# obtain the effective user set, or if that is not yet defined obtain global set
	my $set                  = $db->getMergedSet($effectiveUserName, $setName);
	unless (defined $set) {
		my $userSetClass     = $courseEnv->{dbLayout}->{set_user}->{record};
		$set                 = global2user($userSetClass, $db->getGlobalSet($setName));
		$set->psvn('000');
	}
	
	# FIXME obtain first problem for recording number of attempts FIXME
	my $problem = $db->getMergedProblem($effectiveUser->user_id, $setName, 1);
	
	my	$psvn                = $set->psvn();
	
	$self->{set}             = $set;
	$self->{problem}         = $problem;
	
		##### get and save permission levels #####
		
	my $permissionLevel = $db->getPermissionLevel($userName)->permission();
	
	$self->{userName}        = $userName;
	$self->{user}            = $user;
	$self->{effectiveUser}   = $effectiveUser;
	$self->{permissionLevel} = $permissionLevel;
	
		##### form processing #####
	
	# set options from form fields (see comment at top of file for names)
	my $displayMode        = $r->param("displayMode") || $courseEnv->{pg}->{options}->{displayMode};
	my $redisplay          = $r->param("redisplay");
	my $submitAnswers      = $r->param("submitAnswers");
	my $checkAnswers       = $r->param("checkAnswers");
	my $previewAnswers     = $r->param("previewAnswers");
	

	# coerce form fields into CGI::Vars format
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	$self->{displayMode}    = $displayMode;
	$self->{redisplay}      = $redisplay;
	$self->{submitAnswers}  = $submitAnswers;
	$self->{checkAnswers}   = $checkAnswers;
	$self->{previewAnswers} = $previewAnswers;
	$self->{formFields}     = $formFields;

	##### permissions #####
	
	# are we allowed to view this quiz?
	$self->{isOpen} = time >= $set->open_date || $permissionLevel > 0;
	return unless $self->{isOpen};
	
	# what does the user want to do?
	my %want = (
		showOldAnswers     => $r->param("showOldAnswers")     || $courseEnv->{pg}->{options}->{showOldAnswers},
		showCorrectAnswers => $r->param("showCorrectAnswers") || $courseEnv->{pg}->{options}->{showCorrectAnswers},
		showHints          => $r->param("showHints")          || $courseEnv->{pg}->{options}->{showHints},
		showSolutions      => $r->param("showSolutions")      || $courseEnv->{pg}->{options}->{showSolutions},
		recordAnswers      => defined($submitAnswers),
	);
	
	# are certain options enforced?
	my %must = (
		showOldAnswers     => 0,
		showCorrectAnswers => 0,
		showHints          => 0,
		showSolutions      => 0,
		recordAnswers      => mustRecordAnswers($permissionLevel),
		checkAnswers       => 1,
	);
	
	# does the user have permission to use certain options?
	# QUIZ MAX ATTEMPTS should be set quiz wide FIXME
	my $QUIZ_MAX_ATTEMPTS=100;
	my %can = (
		showOldAnswers     => 1,
		showCorrectAnswers => canShowCorrectAnswers($permissionLevel, $set->answer_date),
		showHints          => 1,
		showSolutions      => canShowSolutions($permissionLevel, $set->answer_date),
		recordAnswers      => canRecordAnswers($permissionLevel, $set->open_date, $set->due_date,
			$QUIZ_MAX_ATTEMPTS, $problem->num_correct + $problem->num_incorrect + 1),
			# attempts=num_correct+num_incorrect+1, as this happens before updating $problem
		checkAnswers       => canCheckAnswers($permissionLevel, $set->answer_date),
	);
	
	# final values for options
	my %will;
	foreach (keys %must) {
		$will{$_} = $must{$_} || ($can{$_} && $want{$_}) ;
	}
# 	warn "\n want";
# 	WeBWorK::Utils::pretty_print_rh(\%want);
# 	warn "can";
# 	WeBWorK::Utils::pretty_print_rh(\%can);
# 	warn "must";
# 	WeBWorK::Utils::pretty_print_rh(\%must);
# 	warn "will";
# 	WeBWorK::Utils::pretty_print_rh(\%will);
	
		##### store fields #####
	
	$self->{want} = \%want;
	$self->{must} = \%must;
	$self->{can}  = \%can;
	$self->{will} = \%will;
	

# 	
# 	#### sticky answers #####   FIXME
# 	
# 	if (not $submitAnswers and $will{showOldAnswers}) {
# 		do this only if new answers are NOT being submitted
# 		my %oldAnswers = decodeAnswers($problem->last_answer);
# 		$formFields->{$_} = $oldAnswers{$_} foreach keys %oldAnswers;
# 	}

	 ######### translate problems ############
	my @problemNumbers = $db->listUserProblems($effectiveUserName, $setName);
    
    my @pg_results = ();
	foreach my $problemNumber (sort {$a<=> $b } @problemNumbers) {
		my $problem = $db->getMergedProblem($effectiveUserName, $setName, $problemNumber);
		my $pg = $self->getProblemHTML($self->{effectiveUser}, $setName, $problemNumber);
		push(@pg_results, $pg);
	}
	$self->{ra_pg_results}=\@pg_results;


}
sub initialize {
	my ($self, $setName) = @_;
	my $courseEnvironment = $self->{ce};
	my $r = $self->{r};
	my $db = $self->{db};
	my $userName = $r->param("user");
	my $effectiveUserName = $r->param("effectiveUser");
	
	my $user            = $db->getUser($userName);
	my $effectiveUser   = $db->getUser($effectiveUserName);
	my $set             = $db->getMergedSet($effectiveUserName, $setName);
	my $permissionLevel = $db->getPermissionLevel($userName)->permission();
	
	$self->{userName}        = $userName;
	$self->{user}            = $user;
	$self->{effectiveUser}   = $effectiveUser;
	$self->{set}             = $set;
	$self->{permissionLevel} = $permissionLevel;
	
	##### permissions #####
	
	$self->{isOpen} = time >= $set->open_date || $permissionLevel > 0;
}

sub path {
	my ($self, $setName, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		$setName => "",
	);
}

sub nav {
	my ($self, $setName, $args) = @_;
	
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my @links = ("Problem Sets" , "$root/$courseName", "navUp");
	my $tail = "";
	
	return $self->navMacro($args, $tail, @links);
}
	

sub siblings {
	my ($self, $setName) = @_;
	return "";
}

sub title {
	my ($self, $setName) = @_;
	
	return $setName;
}



sub body {
	my $self			= shift;
	
		return CGI::p(CGI::font({-color=>"red"}, "This problem is not available because the problem set that contains it is not yet open."))
		unless $self->{isOpen};
	
	# unpack some useful variables
	
	my $r               = $self->{r};
	my $db              = $self->{db};
	my $set             = $self->{set};
	my $problem         = $self->{problem};
	my $permissionLevel = $self->{permissionLevel};
	my $submitAnswers   = $self->{submitAnswers};
	my $checkAnswers    = $self->{checkAnswers};
	my $previewAnswers  = $self->{previewAnswers};
	my %want            = %{ $self->{want} };
	my %can             = %{ $self->{can} };
	my %must            = %{ $self->{must} };
	my %will            = %{ $self->{will} };

	# coerce form fields into CGI::Vars format
	
	return CGI::p(CGI::font({-color=>"red"}, "This problem set is not available because it is not yet open."))
		unless ($self->{isOpen});

	print CGI::h3("This is an experimental gateway quiz format");
	
	print "Number of attempts is ". ($problem->num_correct + $problem->num_incorrect + 1);

	print
		CGI::startform("POST", $r->uri),
		$self->hidden_authen_fields;
	
	#my $set = $db->getMergedSet($effectiveUserName, $setName);
	#my @problemNumbers = $db->listUserProblems($effectiveUserName, $setName);
    my @pg_results = @{ $self->{ra_pg_results} };
    my $problemNumber = 0;
	foreach my $pg (@pg_results) {
		$problemNumber++;
		print CGI::p("Problem $problemNumber");
		# FIXME determine when to see correct answers etc.
		print $self->attemptResults($pg, 1,1,1, 1, 1 ) if $submitAnswers or $checkAnswers;
		print CGI::p( $pg->{body_text});
		print "\n\n", CGI::hr(),CGI::hr(),"\n\n";
	
		
	
	}
	print CGI::p( #FIXME
			($will{recordAnswers})
				? CGI::submit(-name=>"submitAnswers",
					-label=>"Submit Quiz")
				: "",
			(not $will{recordAnswers})
				? CGI::submit(-name=>"checkAnswers",
					-label=>"Check Answers")
				: "",
			CGI::submit(-name=>"previewAnswers",
				-label=>"Preview Answers"),
		);	
#	print CGI::end_table();
	
	# feedback form
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	my $feedbackURL = "$root/$courseName/feedback/";
	print
		CGI::startform("POST", $feedbackURL),
		$self->hidden_authen_fields,
		CGI::hidden("module", __PACKAGE__),
		CGI::hidden("set",    $self->{set}->set_id),
		CGI::p({-align=>"right"},
			CGI::submit(-name=>"feedbackForm", -label=>"Send Feedback")
		),
		CGI::endform();
	
	return "";
}

sub viewOptions($) {
	my $self = shift;
	my $displayMode = $self->{displayMode};
	my %must = %{ $self->{must} };
	my %can  = %{ $self->{can}  };
	my %will = %{ $self->{will} };
	
	my $optionLine;
	$can{showOldAnswers} and $optionLine .= join "",
		"Show: &nbsp;".CGI::br(),
		CGI::checkbox(
			-name    => "showOldAnswers",
			-checked => $will{showOldAnswers},
			-label   => "Saved answers",
		), "&nbsp;&nbsp;".CGI::br();
	$can{showCorrectAnswers} and $optionLine .= join "",
		CGI::checkbox(
			-name    => "showCorrectAnswers",
			-checked => $will{showCorrectAnswers},
			-label   => "Correct answers",
		), "&nbsp;&nbsp;".CGI::br();
	$can{showHints} and $optionLine .= join "",
		CGI::checkbox(
			-name    => "showHints",
			-checked => $will{showHints},
			-label   => "Hints",
		), "&nbsp;&nbsp;".CGI::br();
	$can{showSolutions} and $optionLine .= join "",
		CGI::checkbox(
			-name    => "showSolutions",
			-checked => $will{showSolutions},
			-label   => "Solutions",
		), "&nbsp;&nbsp;".CGI::br();
	$optionLine and $optionLine .= join "", CGI::br();
	
	return CGI::div({-style=>"border: thin groove; padding: 1ex; margin: 2ex align: left"},
			"View&nbsp;equations&nbsp;as:&nbsp;&nbsp;&nbsp;&nbsp;".CGI::br(),
		CGI::radio_group(
			-name    => "displayMode",
			-values  => ['plainText', 'formattedText', 'images'],
			-default => $displayMode,
			-linebreak=>'true',
			-labels  => {
				plainText     => "plain",
				formattedText => "formatted",
				images        => "images",
			}
		), CGI::br(),CGI::hr(),
		$optionLine,
		CGI::submit(-name=>"redisplay", -label=>"Save Options"),
	);
}
sub options {
	my $self = shift;
	return join("",
		CGI::start_form("POST", $self->{r}->uri),
		$self->hidden_authen_fields,
		CGI::hr(), 
		CGI::start_div({class=>"viewOptions"}),
		$self->viewOptions(),
		CGI::end_div(),
		CGI::end_form()
	);
}



###########################################################################
# Evaluation utilties
############################################################################
sub getProblemHTML {
	my ($self, $effectiveUser, $setName, $problemNumber, $pgFile) = @_;
	my $r = $self->{r};
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $key =  $r->param('key');
	# Should we provide a default user ? I think not FIXME
	# $effectiveUser = $self->{effectiveUser} unless defined($effectiveUser);
	
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };

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
	my $showCorrectAnswers = $self->{will}->{showCorrectAnswers};
	my $showHints          = $self->{will}->{showHints};
	my $showSolutions      = $self->{will}->{showSolutions};
	my $processAnswers     = $self->{will}->{checkAnswers};

	unless ($permissionLevel > 0 or time > $set->answer_date) {
		$showCorrectAnswers = 0;
		$showSolutions      = 0;
	}

	# FIXME WeBWorK::Utils::pretty_print_rh($formFields);
	my $pg = WeBWorK::PG->new(
		$ce,
		$effectiveUser,
		$key,
		$set,
		$problem,
		$psvn,
		$formFields, 
		{ # translation options
			displayMode     => "images",
			showHints       => $showHints,
			showSolutions   => $showSolutions,
			refreshMath2img => $showHints || $showSolutions,
			processAnswers  => 1,
			QUIZ_PREFIX     => 'Q'.sprintf("%04d",$problemNumber).'_',
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
	
	#return '<br>hi FIXME'."effective User $effectiveUser, setName $setName, probNum $problemNumber, file: $pgFile".
	return    $pg;
}
##### output utilities #####
sub problemListRow($$$) {
	my $self = shift;
	my $set = shift;
	my $problem = shift;
	
	my $name = $problem->problem_id;
	my $interactiveURL = "$name/?" . $self->url_authen_args;
	my $interactive = CGI::a({-href=>$interactiveURL}, "Problem $name");
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	my $remaining = $problem->max_attempts < 0
		? "unlimited"
		: $problem->max_attempts - $attempts;
	my $status = sprintf("%.0f%%", $problem->status * 100); # round to whole number
	
	return CGI::Tr(CGI::td({-nowrap=>1}, [
		$interactive,
		$attempts,
		$remaining,
		$status,
	]));
}
sub nbsp {
	my $str = shift;
	($str) ? $str : '&nbsp;';  # returns non-breaking space for empty strings
}
sub previewAnswer($$) {
	my ($self, $answerResult, $imgGen) = @_;
	my $ce            = $self->{ce};
	my $effectiveUser = $self->{effectiveUser};
	my $set           = $self->{set};
	my $problem       = $self->{problem};
	my $displayMode   = $self->{displayMode};
	
	# note: right now, we have to do things completely differently when we are
	# rendering math from INSIDE the translator and from OUTSIDE the translator.
	# so we'll just deal with each case explicitly here. there's some code
	# duplication that can be dealt with later by abstracting out tth/dvipng/etc.
	
	my $tex = $answerResult->{preview_latex_string};
	
	return "" unless defined $tex and $tex ne "";
	
	if ($displayMode eq "plainText") {
		return $tex;
	} elsif ($displayMode eq "formattedText") {
		my $tthCommand = $ce->{externalPrograms}->{tth}
			. " -L -f5 -r 2> /dev/null <<END_OF_INPUT; echo > /dev/null\n"
			. "\\(".$tex."\\)\n"
			. "END_OF_INPUT\n";
		
		# call tth
		my $result = `$tthCommand`;
		if ($?) {
			return "<b>[tth failed: $? $@]</b>";
		}
		return $result;
	} elsif ($displayMode eq "images") {
		## how are we going to name this?
		#my $targetPathCommon = "/m2i/"
		#	. $effectiveUser->user_id . "."
		#	. $set->set_id . "."
		#	. $problem->problem_id . "."
		#	. $answerResult->{ans_name} . ".png";
		#
		## figure out where to put things
		#my $wd = makeTempDirectory($ce->{courseDirs}->{html_temp}, "webwork-dvipng");
		#my $latex = $ce->{externalPrograms}->{latex};
		#my $dvipng = $ce->{externalPrograms}->{dvipng};
		#my $targetPath = $ce->{courseDirs}->{html_temp} . $targetPathCommon;
		#		# should use surePathToTmpFile, but we have to
		#		# isolate it from the problem enivronment first
		#my $targetURL = $ce->{courseURLs}->{html_temp} . $targetPathCommon;
		#
		## call dvipng to generate a preview
		#dvipng($wd, $latex, $dvipng, $tex, $targetPath);
		#rmtree($wd, 0, 0);
		#if (-e $targetPath) {
		#	return "<img src=\"$targetURL\" alt=\"$tex\" />";
		#} else {
		#	return "<b>[math2img failed]</b>";
		#}
		$imgGen->add($answerResult->{preview_latex_string});
		
	}
}


sub attemptResults($$$$$$) {
	my $self = shift;
	my $pg = shift;
	my $showAttemptAnswers = shift;
	my $showCorrectAnswers = shift;
	my $showAttemptResults = $showAttemptAnswers && shift;
	my $showSummary = shift;
	my $showAttemptPreview = shift || 0;
	my $ce = $self->{ce};
	my $problemResult = $pg->{result}; # the overall result of the problem
	my @answerNames = @{ $pg->{flags}->{ANSWER_ENTRY_ORDER} };
	
	my $showMessages = $showAttemptAnswers && grep { $pg->{answers}->{$_}->{ans_message} } @answerNames;
	
	my $basename = "equation-" . $self->{set}->psvn. "." . $self->{problem}->problem_id . "-preview";
	my $imgGen = WeBWorK::PG::ImageGenerator->new(
		tempDir  => $ce->{webworkDirs}->{tmp},
		latex	 => $ce->{externalPrograms}->{latex},
		dvipng   => $ce->{externalPrograms}->{dvipng},
		useCache => 1,
		cacheDir => $ce->{webworkDirs}->{equationCache},
		cacheURL => $ce->{webworkURLs}->{equationCache},
		cacheDB  => $ce->{webworkFiles}->{equationCacheDB},
	);
	
	my $header;
	$header .= $showAttemptAnswers ? CGI::th("Entered")  : "";
	$header .= $showAttemptPreview ? CGI::th("Answer Preview")  : "";
	$header .= $showCorrectAnswers ? CGI::th("Correct")  : "";
	$header .= $showAttemptResults ? CGI::th("Result")   : "";
	$header .= $showMessages       ? CGI::th("messages") : "";
	my @tableRows = ( $header );
	my $numCorrect;
	foreach my $name (@answerNames) {
		my $answerResult  = $pg->{answers}->{$name};
		
		my $studentAnswer = $answerResult->{student_ans}; # original_student_ans
		
		my $preview       = ($showAttemptPreview
		                    	? $self->previewAnswer($answerResult,$imgGen)
					: "");
		my $correctAnswer = $answerResult->{correct_ans};
		my $answerScore   = $answerResult->{score};
		my $answerMessage = $showMessages ? $answerResult->{ans_message} : "";
		
		$numCorrect += $answerScore > 0;
		my $resultString = $answerScore ? "correct" : "incorrect";
		
	
		my $row = ''; 
		$row .= $showAttemptAnswers ? CGI::td(nbsp($studentAnswer)) : "";
		$row .= $showAttemptPreview ? CGI::td(nbsp($preview))       : "";
		$row .= $showCorrectAnswers ? CGI::td(nbsp($correctAnswer)) : "";
		$row .= $showAttemptResults ? CGI::td(nbsp($resultString))  : "";
		$row .= $answerMessage      ? CGI::td(nbsp($answerMessage)) : "";
		push @tableRows, $row;
	}
	
	# render equation images
	$imgGen->render(refresh => 1);

	my $numIncorrectNoun = scalar @answerNames == 1 ? "question" : "questions";
	my $scorePercent = sprintf("%.0f%%", $problemResult->{score} * 100);
	my $summary = "On this attempt, you answered $numCorrect out of "
		. scalar @answerNames . " $numIncorrectNoun correct, for a score of $scorePercent.";
	return CGI::table({-class=>"attemptResults"}, CGI::Tr(\@tableRows)) . ($showSummary ? CGI::p($summary) : "");
}

##### logging subroutine ####



##### permission queries #####

# this stuff should be abstracted out into the permissions system
# however, the permission system only knows about things in the
# course environment and the username. hmmm...

# also, i should fix these so that they have a consistent calling
# format -- perhaps:
# 	canPERM($courseEnv, $user, $set, $problem, $permissionLevel)

sub canShowCorrectAnswers($$) {
	my ($permissionLevel, $answerDate) = @_;
	return $permissionLevel > 0 || time > $answerDate;
}

sub canShowSolutions($$) {
	my ($permissionLevel, $answerDate) = @_;
	return canShowCorrectAnswers($permissionLevel, $answerDate);
}

sub canRecordAnswers($$$$$) {
	my ($permissionLevel, $openDate, $dueDate, $maxAttempts, $attempts) = @_;
	my $permHigh = $permissionLevel > 0;
	my $timeOK = time >= $openDate && time <= $dueDate;
	my $attemptsOK = $maxAttempts == -1 || $attempts <= $maxAttempts;
	my $recordAnswers = $permHigh || ($timeOK && $attemptsOK);
	return $recordAnswers;
}

sub canCheckAnswers($$) {
	my ($permissionLevel, $answerDate) = @_;
	my $permHigh = $permissionLevel > 0;
	my $timeOK = time >= $answerDate;
	my $recordAnswers = $permHigh || $timeOK;
	return $recordAnswers;
}

sub mustRecordAnswers($) {
	my ($permissionLevel) = @_;
	return $permissionLevel == 0;
}

1;
