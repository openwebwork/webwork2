################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Problem;

=head1 NAME

WeBWorK::ContentGenerator::Problem - Allow a student to interact with a problem.

=cut

use strict;
use warnings;
use base qw(WeBWorK::ContentGenerator);
use CGI qw();
use WeBWorK::Form;
use WeBWorK::PG;
use WeBWorK::Utils qw(ref2string encodeAnswers decodeAnswers);

############################################################
# 
# user
# key
# 
# displayMode
# showOldAnswers
# showCorrectAnswers
# showHints
# showSolutions
# 
# AnSwEr# - answer blanks in problem
# 
# redisplay - name of the "Redisplay Problem" button
# submitAnswers - name of "Submit Answers" button
#
############################################################

sub pre_header_initialize {
	my ($self, $setName, $problemNumber) = @_;
	my $courseEnv = $self->{courseEnvironment};
	my $r = $self->{r};
	my $userName = $r->param('user');
	
	##### database setup #####
	
	my $cldb   = WeBWorK::DB::Classlist->new($courseEnv);
	my $wwdb   = WeBWorK::DB::WW->new($courseEnv);
	my $authdb = WeBWorK::DB::Auth->new($courseEnv);
	
	my $user            = $cldb->getUser($userName);
	my $set             = $wwdb->getSet($userName, $setName);
	my $problem         = $wwdb->getProblem($userName, $setName, $problemNumber);
	my $psvn            = $wwdb->getPSVN($userName, $setName);
	my $permissionLevel = $authdb->getPermissions($userName);
	
	##### form processing #####
	
	# set options from form fields (see comment at top of file for names)
	my $displayMode        = $r->param("displayMode")        || $courseEnv->{pg}->{options}->{displayMode};
	my $redisplay          = $r->param("redisplay");
	my $submitAnswers      = $r->param("submitAnswers");
	
	# coerce form fields into CGI::Vars format
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	##### permissions #####
	
	# what does the user want to do?
	my %want = (
		showOldAnswers     => $r->param("showOldAnswers")     || $courseEnv->{pg}->{options}->{showOldAnswers},
		showCorrectAnswers => $r->param("showCorrectAnswers") || $courseEnv->{pg}->{options}->{showCorrectAnswers},
		showHints          => $r->param("showHints")          || $courseEnv->{pg}->{options}->{showHints},
		showSolutions      => $r->param("showSolutions")      || $courseEnv->{pg}->{options}->{showSolutions},
		recordAnswers      => $r->param("recordAnswers")      || 1,
	);
	
	# are certain options enforced?
	my %must = (
		showOldAnswers     => 0,
		showCorrectAnswers => 0,
		showHints          => 0,
		showSolutions      => 0,
		recordAnswers      => mustRecordAnswers($permissionLevel),
	);
	
	# does the user have permission to use certain options?
	my %can = (
		showOldAnswers     => 1,
		showCorrectAnswers => canShowCorrectAnswers($permissionLevel, $set->answer_date),
		showHints          => 1,
		showSolutions      => canShowSolutions($permissionLevel, $set->answer_date),
		recordAnswers      => canRecordAnswers($permissionLevel, $set->open_date, $set->due_date,
			$problem->max_attempts, $problem->num_correct + $problem->num_incorrect + 1),
			# num_correct+num_incorrect+1 -- as this happens before updating $problem
	);
	
	# final values for options
	my %will;
	foreach(keys %must) {
		$will{$_} = $can{$_} && ($want{$_} || $must{$_});
	}
	
	##### sticky answers #####
	
	if (not $submitAnswers and $will{showOldAnswers}) {
		# do this only if new answers are NOT being submitted
		my %oldAnswers = decodeAnswers($problem->last_answer);
		$formFields->{$_} = $oldAnswers{$_} foreach keys %oldAnswers;
	}
	
	##### translation #####
	
	my $pg = WeBWorK::PG->new(
		$courseEnv,
		$user,
		$r->param('key'),
		$set,
		$problem,
		$psvn,
		$formFields,
		{ # translation options
			displayMode     => $displayMode,
			showHints       => $will{showHints},
			showSolutions   => $will{showSolutions},
			refreshMath2img => $will{showHints} || $will{showSolutions},
			# try leaving processAnswers on all the time?
			processAnswers  => 1, #$submitAnswers ? 1 : 0,
		},
	);
	
	##### store fields #####
	
	$self->{cldb}            = $cldb;
	$self->{wwdb}            = $wwdb;
	$self->{authdb}          = $authdb;
	
	$self->{user}            = $user;
	$self->{set}             = $set;
	$self->{problem}         = $problem;
	$self->{permissionLevel} = $permissionLevel;
	
	$self->{displayMode}   = $displayMode;
	$self->{redisplay}     = $redisplay;
	$self->{submitAnswers} = $submitAnswers;
	$self->{formFields}    = $formFields;
	
	$self->{want} = \%want;
	$self->{must} = \%must;
	$self->{can}  = \%can;
	$self->{will} = \%will;
	
	$self->{pg} = $pg;
}

sub header {
	my $self = shift;
	
	return $self->{pg}->{head_text} if $self->{pg}->{head_text};
}

sub path {
	my $self = shift;
	my $args = $_[-1];
	my $setName = $self->{set}->id;
	my $problemNumber = $self->{problem}->id;
	
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	return $self->pathMacro($args,
		"Home" => "$root",
		$courseName => "$root/$courseName",
		$setName => "$root/$courseName/$setName",
		"Problem $problemNumber" => "",
	);
}

sub siblings {
	my $self = shift;
	my $setName = $self->{set}->id;
	my $problemNumber = $self->{problem}->id;
	
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
	print CGI::strong("Problems"), CGI::br();
	
	my $wwdb = $self->{wwdb};
	my $user = $self->{r}->param("user");
	my @problems;
	push @problems, $wwdb->getProblem($user, $setName, $_)
		foreach ($wwdb->getProblems($user, $setName));
	foreach my $problem (sort { $a->id <=> $b->id } @problems) {
		print CGI::a({-href=>"$root/$courseName/$setName/".$problem->id."/?"
			. $self->url_authen_args}, "Problem ".$problem->id), CGI::br();
	}
}

sub nav {
	my $self = shift;
	my $args = $_[-1];
	my $setName = $self->{set}->id;
	my $problemNumber = $self->{problem}->id;
	
	my $ce = $self->{courseEnvironment};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
	my $wwdb = $self->{wwdb};
	my $user = $self->{r}->param("user");
	
	my @links = ("Problem List" => "$root/$courseName/$setName");
	
	my $prevProblem = $wwdb->getProblem($user, $setName, $problemNumber-1);
	my $nextProblem = $wwdb->getProblem($user, $setName, $problemNumber+1);
	unshift @links, "Previous Problem" => $prevProblem
		? "$root/$courseName/$setName/".$prevProblem->id
		: "";
	push @links, "Next Problem" => $nextProblem
		? "$root/$courseName/$setName/".$nextProblem->id
		: "";
	
	return $self->navMacro($args, @links);
}

sub title {
	my $self = shift;
	my $setName = $self->{set}->id;
	my $problemNumber = $self->{problem}->id;
	
	return "$setName : Problem $problemNumber";
}

sub body {
	my $self = shift;
	
	#$self->prepare(@_);
	
	# unpack some useful variables
	my $r               = $self->{r};
	my $wwdb            = $self->{wwdb};
	my $set             = $self->{set};
	my $problem         = $self->{problem};
	my $permissionLevel = $self->{permissionLevel};
	my $submitAnswers   = $self->{submitAnswers};
	my %will            = %{ $self->{will} };
	my $pg              = $self->{pg};
	
	##### translation errors? #####
	
	if ($pg->{flags}->{error_flag}) {
		return translationError($pg->{errors}, $pg->{body_text});
	}
	
	##### answer processing #####
	
	# if answers were submitted:
	if ($submitAnswers) {
		# store answers in DB for sticky answers
		my %answersToStore;
		my %answerHash = %{ $pg->{answers} };
		$answersToStore{$_} = $answerHash{$_}->{original_student_ans}
			foreach (keys %answerHash);
		my $answerString = encodeAnswers(%answersToStore,
			@{ $pg->{flags}->{ANSWER_ENTRY_ORDER} });
		$problem->last_answer($answerString);
		$wwdb->setProblem($problem);
		
		# store state in DB if it makes sense
		if ($will{recordAnswers}) {
			$problem->attempted(1);
			$problem->status($pg->{state}->{recorded_score});
			$problem->num_correct($pg->{state}->{num_of_correct_ans});
			$problem->num_incorrect($pg->{state}->{num_of_incorrect_ans});
			$wwdb->setProblem($problem);
		}
	}
	
	##### output #####
	
	# attempt summary
	if ($submitAnswers or $will{showCorrectAnswers}) {
		# print this if user submitted answers OR requested correct answers
		print attemptResults($pg, $submitAnswers, $will{showCorrectAnswers},
			$pg->{flags}->{showPartialCorrectAnswers});
	}
	
	# score summary
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	my $attemptsNoun = $attempts != 1 ? "times" : "time";
	my $lastScore = int ($problem->status * 100) . "%";
	my ($attemptsLeft, $attemptsLeftNoun);
	if ($problem->max_attempts == -1) {
		# unlimited attempts
		$attemptsLeft = "unlimited";
		$attemptsLeftNoun = "attempts";
	} else {
		$attemptsLeft = $problem->max_attempts - $attempts;
		$attemptsLeftNoun = $attemptsLeft == 1 ? "attempt" : "attempts";
	}
	my $setClosedMessage;
	if (time < $set->open_date or time > $set->due_date) {
		$setClosedMessage = "This problem set is closed.";
		if ($permissionLevel > 0) {
			$setClosedMessage .= " Since you are a privileged user, additional attempts will be recorded.";
		} else {
			$setClosedMessage .= " Additional attempts will not be recorded.";
		}
	}
	print CGI::p(
		"You have attempted this problem $attempts $attemptsNoun.", CGI::br(),
		$problem->attempted
			? "Your recorded score is $lastScore." . CGI::br()
			: "",
		"You have $attemptsLeft $attemptsLeftNoun remaining.", CGI::br(),
		$setClosedMessage,
	);
	
	# BY THE WAY..........
	# we have to figure out some way to tell the student if their NEW answer,
	# on THIS attempt, has been recorded. however, this is decided in part by
	# the grader, so is there any way for us to know? we can rule out several
	# cases where the answer is NOT being recorded, because of things decided
	# in &canRecordAnswers...
	
	print CGI::hr();
	
	# main form
	print
		CGI::startform("POST", $r->uri),
		$self->hidden_authen_fields,
		$self->viewOptions,
		CGI::p(CGI::i($pg->{result}->{msg})),
		CGI::p($pg->{body_text}),
		CGI::p(CGI::submit(-name=>"submitAnswers", -label=>"Submit Answers")),
		CGI::endform();
	
	# debugging stuff
	#print
	#	hr(),
	#	h2("debugging information"),
	#	h3("form fields"),
	#	ref2string($formFields),
	#	h3("user object"),
	#	ref2string($user),
	#	h3("set object"),
	#	ref2string($set),
	#	h3("problem object"),
	#	ref2string($problem),
	#	h3("PG object"),
	#	ref2string($pg, {'WeBWorK::PG::Translator' => 1});
	
	return "";
}

##### output utilities #####

# this is used by ProblemSet.pm too, so don't fuck it up
sub translationError($$) {
	my ($error, $details) = @_;
	return
		CGI::h2("Software Error"),
		CGI::p(<<EOF),
WeBWorK has encountered a software error while attempting to process this problem.
It is likely that there is an error in the problem itself.
If you are a student, contact your professor to have the error corrected.
If you are a professor, please consut the error output below for more informaiton.
EOF
		CGI::h3("Error messages"), CGI::blockquote(CGI::pre($error)),
		CGI::h3("Error context"), CGI::blockquote(CGI::pre($details));
}

sub attemptResults($$$) {
	my $pg = shift;
	my $showAttemptAnswers = shift;
	my $showCorrectAnswers = shift;
	my $showAttemptResults = $showAttemptAnswers && shift;
	my $problemResult = $pg->{result}; # the overall result of the problem
	my @answerNames = @{ $pg->{flags}->{ANSWER_ENTRY_ORDER} };
	
	my $header = CGI::th("answer");
	$header .= $showAttemptAnswers ? CGI::th("attempt")  : "";
	$header .= $showCorrectAnswers ? CGI::th("correct")  : "";
	$header .= $showAttemptResults ? CGI::th("result")   : "";
	$header .= $showAttemptAnswers ? CGI::th("messages") : "";
	my @tableRows = ( $header );
	my $numCorrect;
	foreach my $name (@answerNames) {
		my $answerResult  = $pg->{answers}->{$name};
		my $studentAnswer = $answerResult->{student_ans}; # original_student_ans
		my $correctAnswer = $answerResult->{correct_ans};
		my $answerScore   = $answerResult->{score};
		my $answerMessage = $showAttemptAnswers ? $answerResult->{ans_message} : "";
		
		$numCorrect += $answerScore > 0;
		my $resultString = $answerScore ? "correct" : "incorrect";
		
		# get rid of the goofy prefix on the answer names (supposedly, the format
		# of the answer names is changeable. this only fixes
		$name =~ s/^AnSwEr//;
		
		my $row = CGI::td($name);
		$row .= $showAttemptAnswers ? CGI::td($studentAnswer) : "";
		$row .= $showCorrectAnswers ? CGI::td($correctAnswer) : "";
		$row .= $showAttemptResults ? CGI::td($resultString)  : "";
		$row .= $answerMessage      ? CGI::td($answerMessage) : "";
		push @tableRows, $row;
	}
	
	my $numCorrectNoun = $numCorrect == 1 ? "question" : "questions";
	my $scorePercent = int ($problemResult->{score} * 100) . "\%";
	my $summary = "On this attempt, you answered $numCorrect $numCorrectNoun out of "
		. scalar @answerNames . " correct, for a score of $scorePercent.";
	return CGI::table({-border=>1}, CGI::Tr(\@tableRows)) . CGI::p($summary);
}

sub viewOptions($) {
	my $self = shift;
	my $displayMode = $self->{displayMode};
	my %must = %{ $self->{must} };
	my %can  = %{ $self->{can}  };
	my %will = %{ $self->{will} };
	
	my $optionLine;
	$can{showOldAnswers} and $optionLine .= join "",
		"Show: &nbsp;",
		CGI::checkbox(
			-name    => "showOldAnswers",
			-checked => $will{showOldAnswers},
			-label   => "Saved answers",
		), "&nbsp;&nbsp;";
	$can{showCorrectAnswers} and $optionLine .= join "",
		CGI::checkbox(
			-name    => "showCorrectAnswers",
			-checked => $will{showCorrectAnswers},
			-label   => "Correct answers",
		), "&nbsp;&nbsp;";
	$can{showHints} and $optionLine .= join "",
		CGI::checkbox(
			-name    => "showHints",
			-checked => $will{showHints},
			-label   => "Hints",
		), "&nbsp;&nbsp;";
	$can{showSolutions} and $optionLine .= join "",
		CGI::checkbox(
			-name    => "showSolutions",
			-checked => $will{showSolutions},
			-label   => "Solutions",
		), "&nbsp;&nbsp;";
	$optionLine and $optionLine .= join "", CGI::br();
	
	return CGI::div({-style=>"border: thin groove; padding: 1ex; margin: 2ex"},
			"View equations as: &nbsp;",
		CGI::radio_group(
			-name    => "displayMode",
			-values  => ['plainText', 'formattedText', 'images'],
			-default => $displayMode,
			-labels  => {
				plainText     => "plain text",
				formattedText => "formatted text",
				images        => "images",
			}
		), CGI::br(),
		$optionLine,
		CGI::submit(-name=>"redisplay", -label=>"Redisplay Problem"),
	);
}

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
	my $attemptsOK = $attempts <= $maxAttempts;
	return $permHigh || ($timeOK && $attemptsOK);
}

sub mustRecordAnswers($) {
	my ($permissionLevel) = @_;
	return $permissionLevel == 0;
}

1;
