################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::Problem;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME
 
WeBWorK::ContentGenerator::Problem - Allow a student to interact with a problem.

=cut
my $timer0_ON=1;  # times pg translation phase
use strict;
use warnings;
use CGI qw();
use File::Path qw(rmtree);
use WeBWorK::Form;
use WeBWorK::PG;
use WeBWorK::PG::ImageGenerator;
use WeBWorK::PG::IO;
use WeBWorK::Utils qw(writeLog encodeAnswers decodeAnswers ref2string makeTempDirectory);
use WeBWorK::DB::Utils qw(global2user user2global findDefaults);
use WeBWorK::Timing;

############################################################
# 
# user
# effectiveUser
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
# checkAnswers - name of the "Check Answers" button
# previewAnswers - name of the "Preview Answers" button
#
############################################################

sub pre_header_initialize {
	my ($self, $setName, $problemNumber) = @_;
	my $r                    = $self->{r};
	my $courseEnv            = $self->{ce};
	my $db                   = $self->{db};
	my $userName             = $r->param('user');
	my $effectiveUserName    = $r->param('effectiveUser');
	my $key                  = $r->param('key');
	my $user                 = $db->getUser($userName);
	my $effectiveUser        = $db->getUser($effectiveUserName);
	my $permissionLevel      = $db->getPermissionLevel($userName)->permission();
	
	# obtain the merged set for $effectiveUser
	my $set = $db->getMergedSet($effectiveUserName, $setName);
	
	# obtain the merged problem for $effectiveUser
	my $problem = $db->getMergedProblem($effectiveUserName, $setName, $problemNumber);
	
	my $editMode = $r->param("editMode");
	
	if ($permissionLevel > 0 and defined $editMode) {
		# professors are allowed to fabricate sets and problems not
		# assigned to them (or anyone). this allows them to use the
		# editor to 
		
		# if that is not yet defined obtain the global set, convert
		# it to a user set, and add fake user data
		unless (defined $set) {
			my $userSetClass = $db->{set_user}->{record};
			$set = global2user($userSetClass,
				$db->getGlobalSet($setName));
			die "Set $setName does not exist"
				unless defined $set;
			$set->psvn(0);
		}
		
		# if that is not yet defined obtain the global problem,
		# convert it to a user problem, and add fake user data
		unless (defined $problem) {
			my $userProblemClass = $db->{problem_user}->{record};
			$problem = global2user($userProblemClass,
				$db->getGlobalProblem($setName,$problemNumber));
			die "Problem $problemNumber in set $setName does not exist"
				unless defined $problem;
			$problem->user_id($effectiveUserName);
			$problem->problem_seed(0);
			$problem->status(0);
			$problem->attempted(0);
			$problem->last_answer("");
			$problem->num_correct(0);
			$problem->num_incorrect(0);
		}
		
		# now we're sure we have valid UserSet and UserProblem objects
		# yay!
		
		# now deal with possible editor overrides:
		
		# if the caller is asking to override the source file, and
		# editMode calls for a temporary file, do so
		my $sourceFilePath = $r->param("sourceFilePath");
		if (defined $sourceFilePath and $editMode eq "temporaryFile") {
			$problem->source_file($sourceFilePath);
		}
		
		# if the caller is asking to override the problem seed, do so
		my $problemSeed = $r->param("problemSeed");
		if (defined $problemSeed) {
			$problem->problem_seed($problemSeed);
		}
	} else {
		# students can't view problems not assigned to them
		die "Set $setName is not assigned to $effectiveUserName"
			unless defined $set;
		die "Problem $problemNumber in set $setName is not assigned to $effectiveUserName"
			unless defined $problem;
	}
	
	$self->{userName}          = $userName;
	$self->{effectiveUserName} = $effectiveUserName;
	$self->{user}              = $user;
	$self->{effectiveUser}     = $effectiveUser;
	$self->{permissionLevel}   = $permissionLevel;
	$self->{set}               = $set;
	$self->{problem}           = $problem;
	$self->{editMode}          = $editMode;
	
	##### form processing #####
	
	# set options from form fields (see comment at top of file for names)
	my $displayMode        = $r->param("displayMode") || $courseEnv->{pg}->{options}->{displayMode};
	my $redisplay          = $r->param("redisplay");
	my $submitAnswers      = $r->param("submitAnswers");
	my $checkAnswers       = $r->param("checkAnswers");
	my $previewAnswers     = $r->param("previewAnswers");
	
	# fields which may be defined when using Problem Editor
	#my $override_seed = ($permissionLevel>=10) ? $r->param('problemSeed') : undef;
	#my $override_problem_source = ($permissionLevel>=10) ? $r->param('sourceFilePath') : undef;
	#my $editMode = undef;
	#my $submit_button = $r->param('submit_button');
	#if ( defined($submit_button ) ) {
	#	$editMode = "temporaryFile" if $submit_button eq 'Refresh';
	#	$editMode = 'savedFile'     if $submit_button eq 'Save';
	#}
	#
	##override using the source file data from the form field
	#$problem->source_file($override_problem_source) if defined($override_problem_source);
	#$problem->problem_seed($override_seed)          if defined($override_seed);
	#
	## store path to source file for title.
	#$self->{problem_source_name}    =  $problem->source_file;
	#$self->{edit_mode}		=	$editMode;
	#$self->{current_problem_source} 	=	(defined($override_problem_source) ) ?
	
	# coerce form fields into CGI::Vars format
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	$self->{displayMode}    = $displayMode;
	$self->{redisplay}      = $redisplay;
	$self->{submitAnswers}  = $submitAnswers;
	$self->{checkAnswers}   = $checkAnswers;
	$self->{previewAnswers} = $previewAnswers;
	$self->{formFields}     = $formFields;
	
	##### permissions #####
	
	# are we allowed to view this problem?
	$self->{isOpen} = time >= $set->open_date || $permissionLevel > 0;
	return unless $self->{isOpen};
	
	# what does the user want to do?
	my %want = (
		showOldAnswers     => $r->param("showOldAnswers")     || $courseEnv->{pg}->{options}->{showOldAnswers},
		showCorrectAnswers => $r->param("showCorrectAnswers") || $courseEnv->{pg}->{options}->{showCorrectAnswers},
		showHints          => $r->param("showHints")          || $courseEnv->{pg}->{options}->{showHints},
		showSolutions      => $r->param("showSolutions")      || $courseEnv->{pg}->{options}->{showSolutions},
		recordAnswers      => $submitAnswers,
		checkAnswers       => $checkAnswers,
	);
	
	# are certain options enforced?
	my %must = (
		showOldAnswers     => 0,
		showCorrectAnswers => 0,
		showHints          => 0,
		showSolutions      => 0,
		recordAnswers      => mustRecordAnswers($permissionLevel),
		checkAnswers       => 0,
	);
	
	# does the user have permission to use certain options?
	my %can = (
		showOldAnswers     => 1,
		showCorrectAnswers => canShowCorrectAnswers($permissionLevel, $set->answer_date),
		showHints          => 1,
		showSolutions      => canShowSolutions($permissionLevel, $set->answer_date),
		recordAnswers      => canRecordAnswers($permissionLevel, $set->open_date, $set->due_date,
			$problem->max_attempts, $problem->num_correct + $problem->num_incorrect + 1),
			# attempts=num_correct+num_incorrect+1, as this happens before updating $problem
		checkAnswers       => canCheckAnswers($permissionLevel, $set->answer_date),
	);
	
	# final values for options
	my %will;
	foreach (keys %must) {
		$will{$_} = $can{$_} && ($want{$_} || $must{$_});
	}
	
	##### sticky answers #####
	
	if (not ($submitAnswers or $previewAnswers or $checkAnswers) and $will{showOldAnswers}) {
		# do this only if new answers are NOT being submitted
		my %oldAnswers = decodeAnswers($problem->last_answer);
		$formFields->{$_} = $oldAnswers{$_} foreach keys %oldAnswers;
	}
	
	##### translation #####

	$WeBWorK::timer0->continue("begin pg processing") if $timer0_ON;
	my $pg = WeBWorK::PG->new(
		$courseEnv,
		$effectiveUser,
		$key,
		$set,
		$problem,
		$set->psvn, # FIXME: this field should be removed
		$formFields,
		{ # translation options
			displayMode     => $displayMode,
			showHints       => $will{showHints},
			showSolutions   => $will{showSolutions},
			refreshMath2img => $will{showHints} || $will{showSolutions},
			processAnswers  => 1,
		},
	);
	
	$WeBWorK::timer0->continue("end pg processing") if $timer0_ON;
	##### fix hint/solution options #####
	
	$can{showHints}     &&= $pg->{flags}->{hintExists};
	$can{showSolutions} &&= $pg->{flags}->{solutionExists};
	
	##### store fields #####
	
	$self->{want} = \%want;
	$self->{must} = \%must;
	$self->{can}  = \%can;
	$self->{will} = \%will;
	
	$self->{pg} = $pg;
}

#sub if_warnings($$) {
#	my ($self, $arg) = @_;
#	return 0 unless $self->{isOpen};
#	return $self->{pg}->{warnings} ne "";
#}

sub if_errors($$) {
	my ($self, $arg) = @_;
	return 0 unless $self->{isOpen};
	return $self->{pg}->{flags}->{error_flag};
}

sub head {
	my $self = shift;
	return "" unless $self->{isOpen};
	return $self->{pg}->{head_text} if $self->{pg}->{head_text};
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

sub path {
	my $self = shift;
	my $args = $_[-1];
	my $setName = $self->{set}->set_id;
	my $problemNumber = $self->{problem}->problem_id;
	
	my $ce = $self->{ce};
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
	my $setName = $self->{set}->set_id;
	my $problemNumber = $self->{problem}->problem_id;
	
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	print CGI::strong("Problems"), CGI::br();
	
	my $effectiveUser = $self->{r}->param("effectiveUser");
	my @problemIDs = $db->listUserProblems($effectiveUser, $setName);
	foreach my $problem (sort { $a <=> $b } @problemIDs) {
		print CGI::a({-href=>"$root/$courseName/$setName/".$problem."/?"
			. $self->url_authen_args . "&displayMode=" . $self->{displayMode}},
			"Problem ".$problem), CGI::br();
	}

	return "";
}

sub nav {
	$WeBWorK::timer0->continue("begin nav subroutine") if $timer0_ON;
	my $self = shift;
	my $args = $_[-1];
	my $setName = $self->{set}->set_id;
	my $problemNumber = $self->{problem}->problem_id;
	
	my $ce = $self->{ce};
	my $db = $self->{db};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
	my $wwdb          = $self->{wwdb};
	my $effectiveUser = $self->{r}->param("effectiveUser");
	my $tail = "&displayMode=".$self->{displayMode};
	
	my @links = ("Problem List" , "$root/$courseName/$setName", "navProbList");
	
	my @problemIDs = $db->listUserProblems($effectiveUser, $setName);
	my ($prevID, $nextID);
	foreach my $id (@problemIDs) {
		$prevID = $id if $id < $problemNumber
			and (not defined $prevID or $id > $prevID);
		$nextID = $id if $id > $problemNumber
			and (not defined $nextID or $id < $nextID);
	}
	unshift @links, "Previous Problem" , ($prevID
		? "$root/$courseName/$setName/".$prevID
		: "") , "navPrev";
	push @links, "Next Problem" , ($nextID
		? "$root/$courseName/$setName/".$nextID
		: "") , "navNext";
	
	my $result = $self->navMacro($args, $tail, @links);
	$WeBWorK::timer0->continue("end nav subroutine") if $timer0_ON;
	return $result;
}

sub title {
	my $self = shift;
	my $setName = $self->{set}->set_id;
	my $problemNumber = $self->{problem}->problem_id;
	
	return "$setName : Problem $problemNumber";
}

sub body {
	my $self = shift;
	
	return CGI::p(CGI::font({-color=>"red"}, "This problem is not available because the problem set that contains it is not yet open."))
		unless $self->{isOpen};
	
	# unpack some useful variables
	my $r               = $self->{r};
	my $db              = $self->{db};
	my $set             = $self->{set};
	my $problem         = $self->{problem};
	my $editMode        = $self->{editMode};
	my $permissionLevel = $self->{permissionLevel};
	my $submitAnswers   = $self->{submitAnswers};
	my $checkAnswers    = $self->{checkAnswers};
	my $previewAnswers  = $self->{previewAnswers};
	my %want            = %{ $self->{want} };
	my %can             = %{ $self->{can}  };
	my %must            = %{ $self->{must} };
	my %will            = %{ $self->{will} };
	my $pg              = $self->{pg};
	
	##### translation errors? #####
	
	if ($pg->{flags}->{error_flag}) {
		return $self->errorOutput($pg->{errors}, $pg->{body_text});
	}
	
	##### answer processing #####
	$WeBWorK::timer0->continue("begin answer processing") if $timer0_ON;
	# if answers were submitted:
	my $scoreRecordedMessage;
	if ($submitAnswers) {
		# get a "pure" (unmerged) UserProblem to modify
		# this will be undefined if the problem has not been assigned to this user
		my $pureProblem = $db->getUserProblem($problem->user_id, $problem->set_id, $problem->problem_id);
		if (defined $pureProblem) {
			# store answers in DB for sticky answers
			my %answersToStore;
			my %answerHash = %{ $pg->{answers} };
			$answersToStore{$_} = $answerHash{$_}->{original_student_ans}
				foreach (keys %answerHash);
			my $answerString = encodeAnswers(%answersToStore,
				@{ $pg->{flags}->{ANSWER_ENTRY_ORDER} });
			
			# store last answer to database
			$problem->last_answer($answerString);
			$pureProblem->last_answer($answerString);
			$db->putUserProblem($pureProblem);
			
			# store state in DB if it makes sense
			if ($will{recordAnswers}) {
				$problem->status($pg->{state}->{recorded_score});
				$problem->attempted(1);
				$problem->num_correct($pg->{state}->{num_of_correct_ans});
				$problem->num_incorrect($pg->{state}->{num_of_incorrect_ans});
				$pureProblem->status($pg->{state}->{recorded_score});
				$pureProblem->attempted(1);
				$pureProblem->num_correct($pg->{state}->{num_of_correct_ans});
				$pureProblem->num_incorrect($pg->{state}->{num_of_incorrect_ans});
				if ($db->putUserProblem($pureProblem)) {
					$scoreRecordedMessage = "Your score was recorded.";
				} else {
					$scoreRecordedMessage = "Your score was not recorded because there was a failure in storing the problem record to the database.";
				}
				# write to the transaction log, just to make sure
				writeLog($self->{ce}, "transaction",
					$problem->problem_id."\t".
					$problem->set_id."\t".
					$problem->user_id."\t".
					$problem->source_file."\t".
					$problem->value."\t".
					$problem->max_attempts."\t".
					$problem->problem_seed."\t".
					$pureProblem->status."\t".
					$pureProblem->attempted."\t".
					$pureProblem->last_answer."\t".
					$pureProblem->num_correct."\t".
					$pureProblem->num_incorrect
				);
			} else {
				if (time < $set->open_date or time > $set->due_date) {
					$scoreRecordedMessage = "Your score was not recorded because this problem set is closed.";
				} else {
					$scoreRecordedMessage = "Your score was not recorded.";
				}
			}
		} else {
			$scoreRecordedMessage = "Your score was not recorded because this problem has not been built for you.";
		}
	}
	
	# logging student answers
	my $pastAnswerLog = undef;
	if (defined( $self->{ce}->{webworkFiles}->{logs}->{'pastAnswerList'} )) {
		$pastAnswerLog = $self->{ce}->{webworkFiles}->{logs}->{'pastAnswerList'};
		if ($submitAnswers and defined $pastAnswerLog) {
			my $answerString = "";
			my %answerHash = %{ $pg->{answers} };
			$answerString = $answerString . $answerHash{$_}->{original_student_ans}."\t"
				foreach (sort keys  %answerHash);
			$answerString = '' unless defined($answerString); # insure string is defined. 
			writeLog($self->{ce}, "pastAnswerList",
					'|'.$problem->user_id.
					'|'.$problem->set_id.
					'|'.$problem->problem_id.'|'."\t".
					time()."\t".
					$answerString,
				);
		}
	}
	
	$WeBWorK::timer0->continue("end answer processing") if $timer0_ON;
	
	##### output #####
	
	print CGI::start_div({class=>"problemHeader"});
	
	# custom message for editor
	if ($permissionLevel >= 10 and defined $editMode) {
		if ($editMode eq "temporaryFile") {
			print CGI::p(CGI::i("Editing temporary file: ", $problem->source_file));
		} elsif ($editMode eq "savedFile") {
			print CGI::p(CGI::i("Problem saved to: ", $problem->source_file));
		}
	}
	
	# attempt summary
	if ($submitAnswers or $will{showCorrectAnswers}) {
		# print this if user submitted answers OR requested correct answers
		print $self->attemptResults($pg, $submitAnswers,
			$will{showCorrectAnswers},
			$pg->{flags}->{showPartialCorrectAnswers}, 1, 1);
	} elsif ($checkAnswers) {
		# print this if user previewed answers
		print $self->attemptResults($pg, 1, 0, 1, 1, 1);
			# show attempt answers
			# don't show correct answers
			# show attempt results (correctness)
			# don't show attempt previews
	} elsif ($previewAnswers) {
		# print this if user previewed answers
		print $self->attemptResults($pg, 1, 0, 0, 0, 1);
			# show attempt answers
			# don't show correct answers
			# don't show attempt results (correctness)
			# show attempt previews
	}
	
	print CGI::end_div();
	
	print CGI::start_div({class=>"problem"});
	
	# main form
	print
		CGI::startform("POST", $r->uri),
		$self->hidden_authen_fields,
		CGI::p($pg->{body_text}),
		CGI::p($pg->{result}->{msg} ? CGI::b("Note: ") : "", CGI::i($pg->{result}->{msg})),
		CGI::p(
			($can{recordAnswers}
				? CGI::submit(-name=>"submitAnswers",
					-label=>"Submit Answers")
				: ""),
			($can{checkAnswers}
				? CGI::submit(-name=>"checkAnswers",
					-label=>"Check Answers")
				: ""),
			CGI::submit(-name=>"previewAnswers",
				-label=>"Preview Answers"),
		);
	print CGI::end_div();
	
	print CGI::start_div({class=>"scoreSummary"});
	
	# score summary
	my $attempts = $problem->num_correct + $problem->num_incorrect;
	my $attemptsNoun = $attempts != 1 ? "times" : "time";
	my $lastScore = sprintf("%.0f%%", $problem->status * 100); # Round to whole number
	my ($attemptsLeft, $attemptsLeftNoun);
	if ($problem->max_attempts == -1) {
		# unlimited attempts
		$attemptsLeft = "unlimited";
		$attemptsLeftNoun = "attempts";
	} else {
		$attemptsLeft = $problem->max_attempts - $attempts;
		$attemptsLeftNoun = $attemptsLeft == 1 ? "attempt" : "attempts";
	}
	
	my $setClosed = 0;
	my $setClosedMessage;
	if (time < $set->open_date or time > $set->due_date) {
		$setClosed = 1;
		$setClosedMessage = "This problem set is closed.";
		if ($permissionLevel > 0) {
			$setClosedMessage .= " However, since you are a privileged user, additional attempts will be recorded.";
		} else {
			$setClosedMessage .= " Additional attempts will not be recorded.";
		}
	}
	print CGI::p(
		$submitAnswers ? $scoreRecordedMessage . CGI::br() : "",
		"You have attempted this problem $attempts $attemptsNoun.", CGI::br(),
		$problem->attempted
			? "Your recorded score is $lastScore." . CGI::br()
			: "",
		$setClosed ? $setClosedMessage : "You have $attemptsLeft $attemptsLeftNoun remaining."
	);
	print CGI::end_div();
		
	# save state for viewOptions
	print CGI::hidden(
			-name  => "showOldAnswers",
			-value => $will{showOldAnswers}
		),
		CGI::hidden(
			-name  => "showCorrectAnswers",
			-value => $will{showCorrectAnswers}
		),
		CGI::hidden(
			-name  => "showHints",
			-value => $will{showHints}),
		CGI::hidden(
			-name  => "showSolutions",
			-value => $will{showSolutions},
		),
		CGI::hidden(
			-name  => "displayMode",
			-value => $self->{displayMode}
		);
	
	# end of main form
	print CGI::endform();
	
	# stuff we need below (pull these out at the beginning?)
	my $ce = $self->{ce};
	my $root = $ce->{webworkURLs}->{root};
	my $courseName = $ce->{courseName};
	
	print  CGI::start_div({class=>"problemFooter"});
	
	# arguments for answer inspection button
	my $prof_url = $ce->{webworkURLs}->{oldProf};
	my $cgi_url = $prof_url;
	$cgi_url=~ s|/[^/]*$||;  # clip profLogin.pl
	my $authen_args = $self->url_authen_args();
	my $showPastAnswersURL = "$cgi_url/showPastAnswers.pl";
	
	# print answer inspection button
	if ($self->{permissionLevel} > 0) {
		print "\n",
			CGI::start_form(-method=>"POST",-action=>$showPastAnswersURL,-target=>"information"),"\n",
			$self->hidden_authen_fields,"\n",
			CGI::hidden(-name => 'course',  -value=>$courseName), "\n",
			CGI::hidden(-name => 'probNum', -value=>$problem->problem_id), "\n",
			CGI::hidden(-name => 'setNum',  -value=>$problem->set_id), "\n",
			CGI::hidden(-name => 'User',    -value=>$problem->user_id), "\n",
			CGI::p( {-align=>"left"},
				CGI::submit(-name => 'action',  -value=>'Show Past Answers')
			), "\n",
			CGI::endform();
	}
	
	#print CGI::end_div();
	#
	#print CGI::start_div();
	
	# arguments for feedback form
	my $feedbackURL = "$root/$courseName/feedback/";
	
	#print feedback form
	print
		CGI::start_form(-method=>"POST", -action=>$feedbackURL),"\n",
		$self->hidden_authen_fields,"\n",
		CGI::hidden("module",             __PACKAGE__),"\n",
		CGI::hidden("set",                $set->set_id),"\n",
		CGI::hidden("problem",            $problem->problem_id),"\n",
		CGI::hidden("displayMode",        $self->{displayMode}),"\n",
		CGI::hidden("showOldAnswers",     $will{showOldAnswers}),"\n",
		CGI::hidden("showCorrectAnswers", $will{showCorrectAnswers}),"\n",
		CGI::hidden("showHints",          $will{showHints}),"\n",
		CGI::hidden("showSolutions",      $will{showSolutions}),"\n",
		CGI::p({-align=>"left"},
			CGI::submit(-name=>"feedbackForm", -label=>"Contact instructor")
		),
		CGI::endform(),"\n";
		
	# FIXME print editor link
	# print editor link if the user is an instructor AND the file is not in temporary editing mode
	if ($self->{permissionLevel}>=10 and ( (not defined($self->{edit_mode}))  or $self->{edit_mode} eq 'savedFile') ) {
		print CGI::a({-href=>$ce->{webworkURLs}->{root}."/$courseName/instructor/pgProblemEditor/".$set->set_id.
		'/'.$problem->problem_id.'?'.$self->url_authen_args},'Edit this problem');
	}
	
	print CGI::end_div();
	
	# warning output
	#if ($pg->{warnings} ne "") {
	#	print CGI::hr(), $self->warningOutput($pg->{warnings});
	#}
	
	# debugging stuff
	if (0) {
		print
			CGI::hr(),
			CGI::h2("debugging information"),
			CGI::h3("form fields"),
			ref2string($self->{formFields}),
			CGI::h3("user object"),
			ref2string($self->{user}),
			CGI::h3("set object"),
			ref2string($set),
			CGI::h3("problem object"),
			ref2string($problem),
			CGI::h3("PG object"),
			ref2string($pg, {'WeBWorK::PG::Translator' => 1});
	}
	
	return "";
}

##### output utilities #####

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
		dir	 => $ce->{courseDirs}->{html_temp},
		url	 => $ce->{courseURLs}->{html_temp},
		basename => $basename,
		latex	 => $ce->{externalPrograms}->{latex},
		dvipng   => $ce->{externalPrograms}->{dvipng},
	);
	
	my $header;
	#$header .= CGI::th("Part");
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
		                    	? $self->previewAnswer($answerResult, $imgGen)
		                    	: "");
		my $correctAnswer = $answerResult->{correct_ans};
		my $answerScore   = $answerResult->{score};
		my $answerMessage = $showMessages ? $answerResult->{ans_message} : "";
		
		$numCorrect += $answerScore > 0;
		my $resultString = $answerScore ? "correct" : "incorrect";
		
		# get rid of the goofy prefix on the answer names (supposedly, the format
		# of the answer names is changeable. this only fixes it for "AnSwEr"
		$name =~ s/^AnSwEr//;
		
		my $row;
		#$row .= CGI::td($name);
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
	return CGI::table({-class=>"attemptResults"}, CGI::Tr(\@tableRows)) . ($showSummary ? CGI::p({class=>'emphasis'},$summary) : "");
}
sub nbsp {
	my $str = shift;
	($str) ? $str : '&nbsp;';  # returns non-breaking space for empty strings
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
