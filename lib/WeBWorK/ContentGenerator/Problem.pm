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
# 2. if answers were not submitted and there are student answers in the DB,
#    decode them and put them into $formFields for the translator
# 3. Latex2HTML massaging code
# 4. store submitted answers hash in database for sticky answers
# 5. deal with the results of answer evaluation and grading :p
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
	
	my $classlist = WeBWorK::DB::Classlist->new($courseEnv);
	my $wwdb      = WeBWorK::DB::WW->new($courseEnv);
	my $authdb    = WeBWorK::DB::Auth->new($courseEnv);
	
	my $user = $classlist->getUser($userName);
	my $set = $wwdb->getSet($userName, $setName);
	my $problem = $wwdb->getProblem($userName, $setName, $problemNumber);
	my $psvn = $wwdb->getPSVN($userName, $setName);
	my $permissionLevel = $authdb->getPermissions($userName);
	
	##### form processing #####
	
	# set options from form fields (see comment at top of file for names)
	my $displayMode        = $r->param("displayMode")        || $courseEnv->{pg}->{options}->{displayMode};
	my $redisplay          = $r->param("redisplay");
	my $submitAnswers      = $r->param("submitAnswers");
	
	my $wantShowOldAnswers     = $r->param("showOldAnswers")     || $courseEnv->{pg}->{options}->{showOldAnswers};
	my $wantShowCorrectAnswers = $r->param("showCorrectAnswers") || $courseEnv->{pg}->{options}->{showCorrectAnswers};
	my $wantShowHints          = $r->param("showHints")          || $courseEnv->{pg}->{options}->{showHints};
	my $wantShowSolutions      = $r->param("showSolutions")      || $courseEnv->{pg}->{options}->{showSolutions};
	my $wantRecordAnswers      = $r->param("recordAnswers")      || 1;
	
	# coerce form fields into CGI::Vars format
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	##### permissions #####
	
	# does the user have permission to use certain options?
	my $canShowOldAnswers     = 1;
	my $canShowCorrectAnswers = canShowCorrectAnswers($permissionLevel, $set->answer_date);
	my $canShowHints	  = 1;
	my $canShowSolutions      = canShowSolutions($permissionLevel, $set->answer_date);
	my $canRecordAnswers      = canRecordAnswers($permissionLevel, $set->open_date, $set->due_date);
	
	# are certain options enforced?
	my $mustShowOldAnswers     = 0;
	my $mustShowCorrectAnswers = 0;
	my $mustShowHints          = 0;
	my $mustShowSolutions      = 0;
	my $mustRecordAnswers      = mustRecordAnswers($permissionLevel);
	
	# final values for options
	my $showOldAnswers     = $mustShowOldAnswers     || ($canShowOldAnswers     && $wantShowOldAnswers    );
	my $showCorrectAnswers = $mustShowCorrectAnswers || ($canShowCorrectAnswers && $wantShowCorrectAnswers);
	my $showHints          = $mustShowHints          || ($canShowHints          && $wantShowHints         );
	my $showSolutions      = $mustShowSolutions      || ($canShowSolutions      && $wantShowSolutions     );
	my $recordAnswers      = $mustRecordAnswers      || ($canRecordAnswers      && $wantRecordAnswers     );
	
	##### sticky answers #####
	
	# [TODO #2]
	
	if (not $submitAnswers and $showOldAnswers) {
		# only do this if new answers are NOT being submitted
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
			showHints      => $showHints,
			showSolutions  => $showSolutions,
			# try leaving processAnswers on all the time:
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
		# store answers in DB for sticky answers [TODO #4]
		my %answersToStore;
		my %answerHash = %{ $pg->{answers} };
		$answersToStore{$_} = $answerHash{$_}->{original_student_ans}
			foreach (keys %answerHash);
		my $answerString = encodeAnswers(%answersToStore,
			@{ $pg->{flags}->{ANSWER_ENTRY_ORDER} });
		$problem->last_answer($answerString);
		$wwdb->setProblem($problem);
		
		# store score in DB if it makes sense [TODO #5]
		
		# print the answer summary table
		print
			h3("Results of your latest attempt"),
			attemptResults($pg, $showCorrectAnswers,
				$pg->{flags}->{showPartialCorrectAnswers}),
			hr();
	}
	
	##### output #####
	
	# view options
	# what i'd really like to do here is:
	#	- preserve the answers currently in the form fields
	#	- display the answer summary box
	#	- NOT record answers UNDER ANY CIRCUMSTANCES!
	
	# main form
	print
		startform("POST", $r->uri),
		$self->hidden_authen_fields,
		p($pg->{body_text}),
		p(submit(-name=>"submitAnswers", -label=>"Submit Answers")),
		viewOptions($displayMode, $showOldAnswers, $showCorrectAnswers,
			$showHints, $showSolutions),
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

# -----

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
	my $showCorrectAnswers = shift;
	my $showAttemptResults = shift;
	my $problemResult = $pg->{result}; # the overall result of the problem
	my @answerNames = @{ $pg->{flags}->{ANSWER_ENTRY_ORDER} };
	
	my $header = th("answer") . th("attempt");
	$header .= $showCorrectAnswers ? th("correct") : "";
	$header .= $showAttemptResults ? th("result")  : "";
	$header .= th("messages");
	my @tableRows = ( $header );
	my $numCorrect;
	foreach my $name (@answerNames) {
		my $answerResult  = $pg->{answers}->{$name};
		my $studentAnswer = $answerResult->{student_ans}; # original_student_ans
		my $correctAnswer = $answerResult->{correct_ans};
		my $answerScore   = $answerResult->{score};
		my $answerMessage = $answerResult->{ans_message};
		
		$numCorrect += $answerScore > 0;
		my $resultString = $answerScore ? "correct :^)" : "incorrect >:(";
		
		my $row = td($name) . td($studentAnswer);
		$row .= $showCorrectAnswers ? td($correctAnswer) : "";
		$row .= $showAttemptResults ? td($resultString)  : "";
		$row .= $answerMessage      ? td($answerMessage) : "";
		push @tableRows, $row;
	}
	
	my $scorePercent = int ($problemResult->{score} * 100) . "\%";
	my $message = i($problemResult->{msg});
	my $summary = "You answered $numCorrect questions out of "
		. scalar @answerNames . " correct, for a score of $scorePercent.";
	return table({-border=>1}, Tr(\@tableRows)) . p($message, br(), $summary);
}

sub viewOptions($$$$$) {
	my ($displayMode, $showOldAnswers, $showCorrectAnswers,
		$showHints, $showSolutions) = @_;
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
		"Show: &nbsp;",
		checkbox(
			-name    => "showOldAnswers",
			-checked => $showOldAnswers,
			-label   => "Old answers",
		), "&nbsp;&nbsp;",
		checkbox(
			-name    => "showCorrectAnswers",
			-checked => $showCorrectAnswers,
			-label   => "Correct answers",
		), "&nbsp;&nbsp;",
		checkbox(
			-name    => "showHints",
			-checked => $showHints,
			-label   => "Hints",
		), "&nbsp;&nbsp;",
		checkbox(
			-name    => "showSolutions",
			-checked => $showSolutions,
			-label   => "Solutions",
		), br(),
		submit(-name=>"redisplay", -label=>"Redisplay Problem"),
	);
}

# -----

# this stuff should be abstracted out into the permissions system
# however, the permission system only knows about things in the
# course environment and the username. hmmm...

sub canShowCorrectAnswers($$) {
	my ($permissionLevel, $answerDate) = @_;
	return $permissionLevel > 0 || time > $answerDate;
}

sub canShowSolutions($$) {
	my ($permissionLevel, $answerDate) = @_;
	return canShowCorrectAnswers($permissionLevel, $answerDate);
}

sub canRecordAnswers($$$) {
	my ($permissionLevel, $openDate, $dueDate) = @_;
	return $permissionLevel > 0 || (time >= $openDate && time <= $dueDate);
}

sub mustRecordAnswers($) {
	my ($permissionLevel) = @_;
	return $permissionLevel == 0;
}

1;
