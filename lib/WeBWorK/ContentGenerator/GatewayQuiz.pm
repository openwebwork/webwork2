################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package WeBWorK::ContentGenerator::GatewayQuiz;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::GatewayQuiz - display an index of the problems in a 
problem set. (modifying this from ProblemSet.pm)

=cut

use strict;
use warnings;
use CGI qw();

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
	
# 	my $ce = $self->{ce};
# 	my $db = $self->{db};
# 	my $root = $ce->{webworkURLs}->{root};
# 	my $courseName = $ce->{courseName};
# 	
# 	print CGI::strong("Problem Sets"), CGI::br();
# 	
# 	my $effectiveUser = $self->{r}->param("effectiveUser");
# 	my @sets;
# 	push @sets, $db->getMergedSet($effectiveUser, $_)
# 		foreach ($db->listUserSets($effectiveUser));
# #	foreach my $set (sort { $a->open_date <=> $b->open_date } @sets) {
# #   FIXME only experience will tell us the best sorting procedure
# #   due_date seems right for students, but alphabetically is more useful for professors?;
# 
# 	# sort by set name
# 	#@sets = sort { $a->set_id cmp $b->set_id } @sets;
# 	
# 	# sort by set due date
# 	my @sorted_sets = sort { $a->due_date <=> $b->due_date } @sets;
# 	# put closed sets last;
# 	my $now = time();
# 	my @open_sets = grep {$_->due_date>$now} @sets;
# 	my @closed_sets = grep {$_->due_date<=$now} @sets;
# 	@sorted_sets = (@open_sets,@closed_sets);
# 	
# 	foreach my $set (@sorted_sets) { 
# #	    print STDERR "set ".$set->set_id." due date ",$set->due_date,"\n"; 
# 		if (time >= $set->open_date) {
# 			print CGI::a({-href=>"$root/$courseName/".$set->set_id."/?"
# 				. $self->url_authen_args}, $set->set_id), CGI::br();
# 		} else {
# 			print $set->set_id, CGI::br();
# 		}
# 	}
	return "";
}

sub title {
	my ($self, $setName) = @_;
	
	return $setName;
}

# sub info {
# 	my ($self, $setName) = @_;
# 	
# 	my $r = $self->{r};
# 	my $ce = $self->{ce};
# 	my $db = $self->{db};
# 	
# 	return "" unless $self->{isOpen};
# 	
# 	my $effectiveUser = $db->getUser($r->param("effectiveUser"));
# 	my $set  = $db->getMergedSet($effectiveUser->user_id, $setName);
# 	my $psvn = $set->psvn();
# 	
# 	my $screenSetHeader = $set->problem_header || $ce->{webworkFiles}->{screenSnippets}->{setHeader};
# 	my $displayMode     = $ce->{pg}->{options}->{displayMode};
# 	
# 	return "" unless defined $screenSetHeader and $screenSetHeader;
# 	
# 	# decide what to do about problem number
# 	my $problem = WeBWorK::DB::Record::UserProblem->new(
# 		problem_id => 0,
# 		set_id => $set->set_id,
# 		login_id => $effectiveUser->user_id,
# 		source_file => $screenSetHeader,
# 		# the rest of Problem's fields are not needed, i think
# 	);
# 	
# 	my $pg = WeBWorK::PG->new(
# 		$ce,
# 		$effectiveUser,
# 		$r->param('key'),
# 		$set,
# 		$problem,
# 		$psvn,
# 		{}, # no form fields!
# 		{ # translation options
# 			displayMode     => $displayMode,
# 			showHints       => 0,
# 			showSolutions   => 0,
# 			processAnswers  => 0,
# 		},
# 	);
# 	
# 	# handle translation errors
# 	if ($pg->{flags}->{error_flag}) {
# 		return $self->errorOutput($pg->{errors}, $pg->{body_text});
# 	} else {
# 		return $pg->{body_text};
# 	}
# }

sub body {
	my ($self, $setName) = @_;
	my $r = $self->{r};
	my $courseEnvironment = $self->{ce};
	my $db = $self->{db};
	my $effectiveUserName = $r->param('effectiveUser');
	
	return CGI::p(CGI::font({-color=>"red"}, "This problem set is not available because it is not yet open."))
		unless ($self->{isOpen});
	
	my $hardcopyURL =
		$courseEnvironment->{webworkURLs}->{root} . "/"
		. $courseEnvironment->{courseName} . "/"
		. "hardcopy/$setName/?" . $self->url_authen_args;
	print CGI::h3("This is an experimental gateway quiz format");
	
# 	print CGI::start_table();
# 	print CGI::Tr(
# 		CGI::th("Name"),
# 		CGI::th("Attempts"),
# 		CGI::th("Remaining"),
# 		CGI::th("Status"),
# 	);
	# main form
	print
		CGI::startform("POST", $r->uri),
		$self->hidden_authen_fields;
	
	my $set = $db->getMergedSet($effectiveUserName, $setName);
	my @problemNumbers = $db->listUserProblems($effectiveUserName, $setName);
# 	foreach my $problemNumber (sort { $a <=> $b } @problemNumbers) {
# 		my $problem = $db->getMergedProblem($effectiveUserName, $setName, $problemNumber);
# 		print $self->problemListRow($set, $problem);
# 	}
	foreach my $problemNumber (sort {$a<=> $b } @problemNumbers) {
		my $problem = $db->getMergedProblem($effectiveUserName, $setName, $problemNumber);
		print CGI::p("Problem $problemNumber");
		print CGI::p( $self->getProblemHTML($self->{effectiveUser}, $setName, $problemNumber) );
		print "\n\n", CGI::hr(),"\n\n";
	
		
	
	}
	print CGI::p( #FIXME
			#($can{recordAnswers}
				(1? CGI::submit(-name=>"submitAnswers",
					-label=>"Submit Quiz")
				: ""),
			#($can{checkAnswers}
				(1? CGI::submit(-name=>"checkAnswers",
					-label=>"Check Answers")
				: ""),
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
		CGI::hidden("set",    $set->set_id),
		CGI::p({-align=>"right"},
			CGI::submit(-name=>"feedbackForm", -label=>"Send Feedback")
		),
		CGI::endform();
	
	return "";
}

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
###########################################################################
# Evaluation utilties
############################################################################
sub getProblemHTML {
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
		{}, # no form fields! FIXME add form fields
		{ # translation options
			displayMode     => "images",
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
	#return '<br>hi FIXME'."effective User $effectiveUser, setName $setName, probNum $problemNumber, file: $pgFile".
	return    $pg->{body_text};
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
	my $problemResult = $pg->{result}; # the overall result of the problem
	my @answerNames = @{ $pg->{flags}->{ANSWER_ENTRY_ORDER} };
	
	my $showMessages = $showAttemptAnswers && grep { $pg->{answers}->{$_}->{ans_message} } @answerNames;
	
	my $header = CGI::th("Part");
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
		                    	? $self->previewAnswer($answerResult)
					: "");
		my $correctAnswer = $answerResult->{correct_ans};
		my $answerScore   = $answerResult->{score};
		my $answerMessage = $showMessages ? $answerResult->{ans_message} : "";
		
		$numCorrect += $answerScore > 0;
		my $resultString = $answerScore ? "correct" : "incorrect";
		
		# get rid of the goofy prefix on the answer names (supposedly, the format
		# of the answer names is changeable. this only fixes it for "AnSwEr"
		$name =~ s/^AnSwEr//;
		
		my $row = CGI::td($name);
		$row .= $showAttemptAnswers ? CGI::td(nbsp($studentAnswer)) : "";
		$row .= $showAttemptPreview ? CGI::td(nbsp($preview))       : "";
		$row .= $showCorrectAnswers ? CGI::td(nbsp($correctAnswer)) : "";
		$row .= $showAttemptResults ? CGI::td(nbsp($resultString))  : "";
		$row .= $answerMessage      ? CGI::td(nbsp($answerMessage)) : "";
		push @tableRows, $row;
	}
	
	my $numIncorrectNoun = scalar @answerNames == 1 ? "question" : "questions";
	my $scorePercent = sprintf("%.0f%%", $problemResult->{score} * 100);
	my $summary = "On this attempt, you answered $numCorrect out of "
		. scalar @answerNames . " $numIncorrectNoun correct, for a score of $scorePercent.";
	return CGI::table({-class=>"attemptResults"}, CGI::Tr(\@tableRows)) . ($showSummary ? CGI::p($summary) : "");
}
1;
