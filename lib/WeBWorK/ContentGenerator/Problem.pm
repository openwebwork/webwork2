package WeBWorK::ContentGenerator::Problem;
use base qw(WeBWorK::ContentGenerator);

use strict;
use warnings;
use CGI qw(:html :form);
use WeBWorK::Utils qw(ref2string);
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
# redisplay - name of the "Redisplay" button
# processAnswers - name of "Submit Answers" button

sub title {
	my ($self, $setName, $problemNumber) = @_;
	my $userName = $self->{r}->param('user');
	return "Problem $problemNumber of problem set $setName for $userName";
}

sub body {
	my ($self, $setName, $problemNumber) = @_;
	my $courseEnv = $self->{courseEnvironment};
	my $r = $self->{r};
	my $userName = $r->param('user');
	
	# fix format of setName and problem
	# (i want dennis to cut "set" and "prob" off before calling me)
	$setName =~ s/^set//;
	$problemNumber =~ s/^prob//;
	
	# get database information
	my $classlist = WeBWorK::DB::Classlist->new($courseEnv);
	my $wwdb = WeBWorK::DB::WW->new($courseEnv);
	my $user = $classlist->getUser($userName);
	my $set = $wwdb->getSet($userName, $setName);
	my $problem = $wwdb->getProblem($userName, $setName, $problemNumber);
	my $psvn = $wwdb->getPSVN($userName, $setName);
	
	# set options from form fields (see comment at top of file for names)
	my $displayMode        = $r->param("displayMode")        || $courseEnv->{pg}->{options}->{displayMode};
	my $showOldAnswers     = $r->param("showOldAnswers")     || $courseEnv->{pg}->{options}->{showOldAnswers};
	my $showCorrectAnswers = $r->param("showCorrectAnswers") || $courseEnv->{pg}->{options}->{showCorrectAnswers};
	my $showHints          = $r->param("showHints")          || $courseEnv->{pg}->{options}->{showHints};
	my $showSolutions      = $r->param("showSolutions")      || $courseEnv->{pg}->{options}->{showSolutions};
	my $redisplay          = $r->param("redisplay");
	my $processAnswers     = $r->param("submitAnswers");
	
	# coerce form fields into CGI::Vars format
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	# TODO:
	# 1. enforce privs for showCorrectAnswers and showSolutions
	#    (use $PRIV = $canPRIV && $wantPRIV -- cool syntax!)
	# 2. if answers were not submitted and there are student answers in the DB,
	#    decode them and put them into $formFields for the translator
	# 3. Latex2HTML massaging code
	# 4. store submitted answers hash in database for sticky answers
	# 5. deal with the results of answer evaluation and grading :p
	# 6. introduce a recordAnswers option, which works on the same principle as
	#    the other priv-based options
	# 7. make warnings work
	
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
			processAnswers => $processAnswers ? 1 : 0,
		},
		$formFields
	);
	
	if ($pg->{flags}->{error_flag}) {
		# there was an error in translation
		print h2("Software Error");
		print p(<<EOF);
WeBWorK has encountered a software error while attempting to process this problem.
It is likely that there is an error in the problem itself.
If you are a student, contact your professor to have the error corrected.
If you are a professor, please consut the error output below for more informaiton.
EOF
		print h3("Error messages"), blockquote(pre($pg->{errors}));
		print h3("Error context"), blockquote(pre($pg->{body_text}));
		return "";
	}
	
	# Previous answer results
	if ($processAnswers) {
		print h3("Results of your latest attempt");
		print attemptResults($pg, $showCorrectAnswers, $pg->{flags}->{showPartialCorrectAnswers});
		print hr();
	}
	
	# main form
	print startform("POST", $r->uri);
	print $self->hidden_authen_fields;
	print $self->hidden_fields(qw(displayMode showOldAnswers showCorrectAnswers showHints showSolutions));
	print p($pg->{body_text});
	print p(submit(-name=>"submitAnswers", -label=>"Submit Answers"));
	print endform();
	print hr();
	
	# view options
	# what i'd really like to do here is:
	#	- preserve the answers currently in the form fields
	#	- display the answer summary box
	#	- NOT record answers UNDER ANY CIRCUMSTANCES!
	print startform("POST", $r->uri);
	#print $self->hidden_fields();
	print p("View equations as: ",
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
		checkbox(
			-name    => "showOldAnswers",
			-checked => $showOldAnswers,
			-label   => "Show old answers",
		), br(),
		checkbox(
			-name    => "showCorrectAnswers",
			-checked => $showCorrectAnswers,
			-label   => "Show correct answers",
		), br(),
		checkbox(
			-name    => "showHints",
			-checked => $showHints,
			-label   => "Show hints",
		), br(),
		checkbox(
			-name    => "showSolutions",
			-checked => $showSolutions,
			-label   => "Show solutions",
		), br(),
	);
	print p(submit(-name=>"redisplay", -label=>"Redisplay Problem"));
	print endform();
	print hr();
	
	# debugging stuff
	print h2("debugging information");
	print h3("form fields");
	print ref2string($formFields);
	print h3("PG object");
	print ref2string($pg, {'WeBWorK::PG::Translator' => 1});
	
	return "";
}

sub attemptResults {
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
		my $studentAnswer = $answerResult->{student_ans};
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

1;
