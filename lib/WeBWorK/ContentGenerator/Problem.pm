package WeBWorK::ContentGenerator::Problem;
use base qw(WeBWorK::ContentGenerator);

use strict;
use warnings;
use CGI qw(:html :form);
use WeBWorK::Utils qw(ref2string encodeAnswers decodeAnswers);
use WeBWorK::PG;
use WeBWorK::Form;

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

sub title {
	my ($self, $setName, $problemNumber) = @_;
	my $userName = $self->{r}->param('user');
	return "Problem $problemNumber of problem set $setName for $userName";
}

# TODO:
# :) enforce permissions for showCorrectAnswers and showSolutions
#    (use $PRIV = $mustPRIV || ($canPRIV && $wantPRIV) -- cool syntax!)
# :) if answers were not submitted and there are student answers in the DB,
#    decode them and put them into $formFields for the translator
# 3. Latex2HTML massaging code
# :) store submitted answers hash in database for sticky answers
# :) deal with the results of answer evaluation and grading :p
# :) introduce a recordAnswers option, which works on the same principle as
#    the other permission-based options
# 7. make warnings work

sub body {
	my ($self, $setName, $problemNumber) = @_;
	my $courseEnv = $self->{courseEnvironment};
	my $r = $self->{r};
	my $userName = $r->param('user');
	
	# fix format of setName and problem
	$setName =~ s/^set//;
	$problemNumber =~ s/^prob//;
	
	##### database setup #####
	# this should probably go in initialize() or whatever it's called
	
	my $classlist = WeBWorK::DB::Classlist->new($courseEnv);
	my $wwdb      = WeBWorK::DB::WW->new($courseEnv);
	my $authdb    = WeBWorK::DB::Auth->new($courseEnv);
	
	my $user = $classlist->getUser($userName);
	my $set = $wwdb->getSet($userName, $setName);
	my $problem = $wwdb->getProblem($userName, $setName, $problemNumber);
	my $permissionLevel = $authdb->getPermissions($userName);
	
	##### form processing #####
	
	# set options from form fields (see comment at top of file for names)
	my $displayMode        = $r->param("displayMode")        || $courseEnv->{pg}->{options}->{displayMode};
	my $redisplay          = $r->param("redisplay");
	my $submitAnswers      = $r->param("submitAnswers");
	
	my %want = (
		showOldAnswers     => $r->param("showOldAnswers")     || $courseEnv->{pg}->{options}->{showOldAnswers},
		showCorrectAnswers => $r->param("showCorrectAnswers") || $courseEnv->{pg}->{options}->{showCorrectAnswers},
		showHints          => $r->param("showHints")          || $courseEnv->{pg}->{options}->{showHints},
		showSolutions      => $r->param("showSolutions")      || $courseEnv->{pg}->{options}->{showSolutions},
		recordAnswers      => $r->param("recordAnswers")      || 1,
	);
	
	# coerce form fields into CGI::Vars format
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	##### permissions #####
	
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
		$r->param('user'),
		$r->param('key'),
		$setName,
		$problemNumber,
		{ # translation options
			displayMode    => $displayMode,
			showHints      => $will{showHints},
			showSolutions  => $will{showSolutions},
			# try leaving processAnswers on all the time?
			processAnswers => 1, #$submitAnswers ? 1 : 0,
		},
		$formFields
	);
	
	# handle any errors in translation
	if ($pg->{flags}->{error_flag}) {
		# there was an error in translation
		print
			h2("Software Error"),
			translationError($pg->{errors}, $pg->{body_text});
		
		return "";
	}
	
	# massage LaTeX2HTML [TODO #3]
	
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
		
		# store score in DB if it makes sense
		if ($will{recordAnswers}) {
			# the grader makes a lot of decisions for us...
			# all we have to do is update information from
			# the 'state' hash in the $pg hash.
			$problem->attempted(1);
			$problem->status($pg->{state}->{recorded_score});
			$problem->num_correct($pg->{state}->{num_of_correct_ans});
			$problem->num_incorrect($pg->{state}->{num_of_incorrect_ans});
			#warn "Would have stored the following:\n",
			#	$problem->toString, "\n";
			$wwdb->setProblem($problem);
		} else {
			print p("Your score was not recorded for some reason. ;)");
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
	print p(
		"You have attempted this problem $attempts $attemptsNoun.", br(),
		$problem->attempted
			? "Your recorded score is $lastScore." . br()
			: "",
		"You have $attemptsLeft $attemptsLeftNoun remaining."
	);
	
	# BY THE WAY..........
	# we have to figure out some way to tell the student if their NEW answer,
	# on THIS attempt, has been recorded. however, this is decided in part by
	# the grader, so is there any way for us to know? we can rule out several
	# cases where the answer is NOT being recorded, because of things decided
	# in &canRecordAnswers...
	
	print hr();
	
	# main form
	print
		startform("POST", $r->uri),
		$self->hidden_authen_fields,
		p(i($pg->{result}->{msg})),
		p($pg->{body_text}),
		p(submit(-name=>"submitAnswers", -label=>"Submit Answers")),
		viewOptions($displayMode, \%must, \%can, \%will),
		endform(),
		hr();
	
	# debugging stuff
	print
		h2("debugging information"),
		h3("form fields"),
		ref2string($formFields),
		h3("user object"),
		ref2string($user),
		h3("set object"),
		ref2string($set),
		h3("problem object"),
		ref2string($problem),
		h3("PG object"),
		ref2string($pg, {'WeBWorK::PG::Translator' => 1});
	
	return "";
}

##### output utilities #####

sub translationError($$) {
	my ($error, $details) = @_;
	return
		p(<<EOF),
WeBWorK has encountered a software error while attempting to process this problem.
It is likely that there is an error in the problem itself.
If you are a student, contact your professor to have the error corrected.
If you are a professor, please consut the error output below for more informaiton.
EOF
		h3("Error messages"), blockquote(pre($error)),
		h3("Error context"), blockquote(pre($details));
}

sub attemptResults($$$) {
	my $pg = shift;
	my $showAttemptAnswers = shift;
	my $showCorrectAnswers = shift;
	my $showAttemptResults = $showAttemptAnswers && shift;
	my $problemResult = $pg->{result}; # the overall result of the problem
	my @answerNames = @{ $pg->{flags}->{ANSWER_ENTRY_ORDER} };
	
	my $header = th("answer");
	$header .= $showAttemptAnswers ? th("attempt")  : "";
	$header .= $showCorrectAnswers ? th("correct")  : "";
	$header .= $showAttemptResults ? th("result")   : "";
	$header .= $showAttemptAnswers ? th("messages") : "";
	my @tableRows = ( $header );
	my $numCorrect;
	foreach my $name (@answerNames) {
		my $answerResult  = $pg->{answers}->{$name};
		my $studentAnswer = $answerResult->{student_ans}; # original_student_ans
		my $correctAnswer = $answerResult->{correct_ans};
		my $answerScore   = $answerResult->{score};
		my $answerMessage = $showAttemptAnswers ? $answerResult->{ans_message} : "";
		
		$numCorrect += $answerScore > 0;
		my $resultString = $answerScore ? "correct :^)" : "incorrect >:(";
		
		my $row = td($name);
		$row .= $showAttemptAnswers ? td($studentAnswer) : "";
		$row .= $showCorrectAnswers ? td($correctAnswer) : "";
		$row .= $showAttemptResults ? td($resultString)  : "";
		$row .= $answerMessage      ? td($answerMessage) : "";
		push @tableRows, $row;
	}
	
	my $numCorrectNoun = $numCorrect == 1 ? "question" : "questions";
	my $scorePercent = int ($problemResult->{score} * 100) . "\%";
	#my $message = i($problemResult->{msg});
	my $summary = "On this attempt, you answered $numCorrect $numCorrectNoun out of "
		. scalar @answerNames . " correct, for a score of $scorePercent.";
	#return table({-border=>1}, Tr(\@tableRows)) . p($message, br(), $summary);
	return table({-border=>1}, Tr(\@tableRows)) . p($summary);
}

sub viewOptions($\%\%\%) {
	my $displayMode = shift;
	my %must = %{ shift() };
	my %can  = %{ shift() };
	my %will = %{ shift() };
	
	my $optionLine;
	$can{showOldAnswers} and $optionLine .= join "",
		"Show: &nbsp;",
		checkbox(
			-name    => "showOldAnswers",
			-checked => $will{showOldAnswers},
			-label   => "Saved answers",
		), "&nbsp;&nbsp;";
	$can{showCorrectAnswers} and $optionLine .= join "",
		checkbox(
			-name    => "showCorrectAnswers",
			-checked => $will{showCorrectAnswers},
			-label   => "Correct answers",
		), "&nbsp;&nbsp;";
	$can{showHints} and $optionLine .= join "",
		checkbox(
			-name    => "showHints",
			-checked => $will{showHints},
			-label   => "Hints",
		), "&nbsp;&nbsp;";
	$can{showSolutions} and $optionLine .= join "",
		checkbox(
			-name    => "showSolutions",
			-checked => $will{showSolutions},
			-label   => "Solutions",
		), "&nbsp;&nbsp;";
	$optionLine and $optionLine .= join "", br();
	
	return div({-style=>"border: thin groove; padding: 1ex; margin: 2ex"},
			"View equations as: &nbsp;",
		radio_group(
			-name    => "displayMode",
			-values  => ['plainText', 'formattedText', 'images'],
			-default => $displayMode,
			-labels  => {
				plainText     => "plain text",
				formattedText => "formatted text",
				images        => "images",
			}
		), br(),
		$optionLine,
		submit(-name=>"redisplay", -label=>"Redisplay Problem"),
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
