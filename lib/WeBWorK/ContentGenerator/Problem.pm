################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/ContentGenerator/Problem.pm,v 1.135 2004/05/24 02:01:25 dpvc Exp $
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

package WeBWorK::ContentGenerator::Problem;
use base qw(WeBWorK::ContentGenerator);

=head1 NAME
 
WeBWorK::ContentGenerator::Problem - Allow a student to interact with a problem.

=cut

use strict;
use warnings;
use CGI qw();
use File::Path qw(rmtree);
use WeBWorK::Form;
use WeBWorK::PG;
use WeBWorK::PG::ImageGenerator;
use WeBWorK::PG::IO;
use WeBWorK::Utils qw(writeLog writeCourseLog encodeAnswers decodeAnswers ref2string makeTempDirectory);
use WeBWorK::DB::Utils qw(global2user user2global findDefaults);
use WeBWorK::Timing;

use WeBWorK::Utils::Tasks qw(fake_set fake_problem);

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
# FIXME: this table is heinously out of date
#
############################################################

# FIXME: what is this?
sub templateName {
	"problem";
}

sub pre_header_initialize {
	my ($self) = @_;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	my $setName = $urlpath->arg("setID");
	my $problemNumber = $r->urlpath->arg("problemID");
	my $userName = $r->param('user');
	my $effectiveUserName = $r->param('effectiveUser');
	my $key = $r->param('key');
	
	my $user = $db->getUser($userName); # checked
	die "record for user $userName (real user) does not exist."
		unless defined $user;
	
	my $effectiveUser = $db->getUser($effectiveUserName); # checked
	die "record for user $effectiveUserName (effective user) does not exist."
		unless defined $effectiveUser;
	
	my $PermissionLevel = $db->getPermissionLevel($userName); # checked
	die "permission level record for user $userName does not exist (but the user does? odd...)"
		unless defined $PermissionLevel;
	my $permissionLevel = $PermissionLevel->permission;
	
	# obtain the merged set for $effectiveUser
	my $set = $db->getMergedSet($effectiveUserName, $setName); # checked
	
	# obtain the merged problem for $effectiveUser
	my $problem = $db->getMergedProblem($effectiveUserName, $setName, $problemNumber); # checked

	my $editMode = $r->param("editMode");
	
	if ($permissionLevel > 0) {
		# professors are allowed to fabricate sets and problems not
		# assigned to them (or anyone). this allows them to use the
		# editor to 
		
		# if that is not yet defined obtain the global set, convert
		# it to a user set, and add fake user data
		unless (defined $set) {
			my $userSetClass = $db->{set_user}->{record};
			my $globalSet = $db->getGlobalSet($setName); # checked
			# if the global set doesn't exist either, bail!
			if(not defined $globalSet) {
				$set = fake_set($db);
			} else {
				$set = global2user($userSetClass, $globalSet);
				$set->psvn(0);

				# FIXME: This is a temporary fix to fill in the database
				#	 We want the published field to contain either 1 or 0 so if it has not been set to 0, default to 1
				#	this will fill in all the empty fields but not change anything that has been specifically set to 1 or 0
				$globalSet->published("1") unless $globalSet->published eq "0";
				$db->putGlobalSet($globalSet);
			}
		}
		
		# if that is not yet defined obtain the global problem,
		# convert it to a user problem, and add fake user data
		unless (defined $problem) {
			my $userProblemClass = $db->{problem_user}->{record};
			my $globalProblem = $db->getGlobalProblem($setName, $problemNumber); # checked
			# if the global problem doesn't exist either, bail!
			if(not defined $globalProblem) {
				my $sourceFilePath = $r->param("sourceFilePath");
				die "Problem $problemNumber in set $setName does not exist"
					unless defined $sourceFilePath;
				$problem = fake_problem($db);
				$problem->problem_id(1);
				$problem->source_file($sourceFilePath);
				$problem->user_id($effectiveUserName);
			} else {
				$problem = global2user($userProblemClass, $globalProblem);
				$problem->user_id($effectiveUserName);
				$problem->problem_seed(0);
				$problem->status(0);
				$problem->attempted(0);
				$problem->last_answer("");
				$problem->num_correct(0);
				$problem->num_incorrect(0);
			}
		}
		
		# now we're sure we have valid UserSet and UserProblem objects
		# yay!
		
		# now deal with possible editor overrides:
		
		# if the caller is asking to override the source file, and
		# editMode calls for a temporary file, do so
		my $sourceFilePath = $r->param("sourceFilePath");
		if (defined $sourceFilePath and 
		    (not defined $editMode or $editMode eq "temporaryFile")) {
			$problem->source_file($sourceFilePath);
		}
		
		# if the caller is asking to override the problem seed, do so
		my $problemSeed = $r->param("problemSeed");
		if (defined $problemSeed) {
			$problem->problem_seed($problemSeed);
		}

		my $published = ($set->published) ? "Published" : "Unpublished";
		$self->addmessage(CGI::p("This set is " . CGI::font({class=>$published}, $published)));
	} else {
	
		$self->addmessage(CGI::div({class=>"ResultsWithError"}, CGI::p("This problem will not count towards your grade."))) unless $problem->value;;
		# students can't view problems not assigned to them

		# A set is valid if it exists and if it is either published or the user is privileged.
		$self->{invalidSet} = (grep /$setName/, $db->listUserSets($effectiveUserName)) == 0 || !($set->published || $permissionLevel->permission > 0); # this is redundant because of the above if
		$self->{invalidProblem} = (grep /$problemNumber/, $db->listUserProblems($effectiveUserName, $setName)) == 0 || !($set->published || $permissionLevel->permission > 0);;

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
	my $displayMode        = $r->param("displayMode") || $ce->{pg}->{options}->{displayMode};
	my $redisplay          = $r->param("redisplay");
	my $submitAnswers      = $r->param("submitAnswers");
	my $checkAnswers       = $r->param("checkAnswers");
	my $previewAnswers     = $r->param("previewAnswers");
	
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	$self->{displayMode}    = $displayMode;
	$self->{redisplay}      = $redisplay;
	$self->{submitAnswers}  = $submitAnswers;
	$self->{checkAnswers}   = $checkAnswers;
	$self->{previewAnswers} = $previewAnswers;
	$self->{formFields}     = $formFields;

	# get result and send to message
	my $success	       = $r->param("sucess");
	my $failure	       = $r->param("failure");
	$self->addmessage(CGI::div({class=>"ResultsWithError"}, CGI::p($failure))) if $failure;
	$self->addmessage(CGI::div({class=>"ResultsWithoutError"}, CGI::p($success))) if $success;

	# now that we've set all the necessary variables quit out if the set or problem is invalid
	return if $self->{invalidSet} || $self->{invalidProblem};
	
	##### permissions #####
	
	# are we allowed to view this problem?
	$self->{isOpen} = time >= $set->open_date || $permissionLevel > 0;
	return unless $self->{isOpen};
	
	# what does the user want to do?
	my %want = (
		showOldAnswers     => $r->param("showOldAnswers")     || $ce->{pg}->{options}->{showOldAnswers},
		showCorrectAnswers => $r->param("showCorrectAnswers") || $ce->{pg}->{options}->{showCorrectAnswers},
		showHints          => $r->param("showHints")          || $ce->{pg}->{options}->{showHints},
		showSolutions      => $r->param("showSolutions")      || $ce->{pg}->{options}->{showSolutions},
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
	
	# more complicated logic for showing check answer button:
	# checkAnswers button shows up after due date -- once a student can't record anymore
	# checkAnswers button always shows up when an instructor or TA is acting
	# as someone else (the $user and $effectiveUserName aren't the same).
	$can{checkAnswers} = (
		# $can{recordAnswers} will be false if the due date has passed OR the
		# student has used up all of her attempts
		($can{checkAnswers} and not $can{recordAnswers})
			or
		(
			# FIXME: this is not the right way to check for this.
			# also, canCheckAnswers() will show this button if the permission
			# level is positive,  which is always true when an instructor is
			# acting as a student
			defined($userName)
				and
			defined($effectiveUserName)
				and
			($userName ne $effectiveUserName)
		)
	);
	
	# more complicated logif for showing "submit answer" button:
	# We hide the submit answer button if someone is acting as a student
	# This prevents errors where you accidently submit the answer for a student
	# Not sure whether this a feature or a bug
	$can{recordAnswers} = (
		$can{recordAnswers}
			and not
		(
			# FIXME: this is not the right way to check for this.
			defined($userName)
				and
			defined($effectiveUserName)
				and
			($userName ne $effectiveUserName)
		)
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

	$WeBWorK::timer->continue("begin pg processing") if defined($WeBWorK::timer);
	my $pg = WeBWorK::PG->new(
		$ce,
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
	
	$WeBWorK::timer->continue("end pg processing") if defined($WeBWorK::timer);
	##### fix hint/solution options #####
	
	$can{showHints}     &&= $pg->{flags}->{hintExists}  
	                    &&= $pg->{flags}->{showHintLimit}<=$pg->{state}->{num_of_incorrect_ans};
	$can{showSolutions} &&= $pg->{flags}->{solutionExists};
	
	##### store fields #####
	
	$self->{want} = \%want;
	$self->{must} = \%must;
	$self->{can}  = \%can;
	$self->{will} = \%will;
	$self->{pg} = $pg;
}

sub if_errors($$) {
	my ($self, $arg) = @_;
	
	if ($self->{isOpen}) {
		return $self->{pg}->{flags}->{error_flag} ? $arg : !$arg;
	} else {
		return !$arg;
	}
}

sub head {
	my ($self) = @_;
	
	return "" unless $self->{isOpen};
	return $self->{pg}->{head_text} if $self->{pg}->{head_text};
}

sub options {
	my ($self) = @_;
	
	return "" if $self->{invalidProblem};
	
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

#sub path {
#	my $self = shift;
#	my $args = $_[-1];
#	my $setName = $self->{set}->set_id;
#	my $problemNumber = $self->{problem}->problem_id;
#	
#	my $ce = $self->{ce};
#	my $root = $ce->{webworkURLs}->{root};
#	my $courseName = $ce->{courseName};
#	return $self->pathMacro($args,
#		"Home" => "$root",
#		$courseName => "$root/$courseName",
#		$setName => "$root/$courseName/$setName",
#		"Problem $problemNumber" => "",
#	);
#}

sub siblings {
	my ($self) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	# can't show sibling problems if the set is invalid
	return "" if $self->{invalidSet};
	
	my $courseID = $urlpath->arg("courseID");
	my $setID = $self->{set}->set_id;
	my $eUserID = $r->param("effectiveUser");
	my @problemIDs = sort { $a <=> $b } $db->listUserProblems($eUserID, $setID);
	
	print CGI::start_ul({class=>"LinksMenu"});
	print CGI::start_li();
	print CGI::span({style=>"font-size:larger"}, "Problems");
	print CGI::start_ul();

	foreach my $problemID (@problemIDs) {
		my $problemPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Problem",
			courseID => $courseID, setID => $setID, problemID => $problemID);
		print CGI::li(CGI::a({href=>$self->systemLink($problemPage, params=>{displayMode => $self->{displayMode}})}, "Problem $problemID"));
	}
	
	print CGI::end_ul();
	print CGI::end_li();
	print CGI::end_ul();
	
	return "";
}

sub nav {
	my ($self, $args) = @_;
	my $r = $self->r;
	my $db = $r->db;
	my $urlpath = $r->urlpath;
	
	my $courseID = $urlpath->arg("courseID");
	my $setID = $self->{set}->set_id if !($self->{invalidSet});
	my $problemID = $self->{problem}->problem_id if !($self->{invalidProblem});
	my $eUserID = $r->param("effectiveUser");
	
	my ($prevID, $nextID);

	if (!$self->{invalidProblem}) {	
		my @problemIDs = $db->listUserProblems($eUserID, $setID);
		foreach my $id (@problemIDs) {
			$prevID = $id if $id < $problemID
				and (not defined $prevID or $id > $prevID);
			$nextID = $id if $id > $problemID
				and (not defined $nextID or $id < $nextID);
		}
	}
	
	my @links;
	
	if ($prevID) {
		my $prevPage = $urlpath->newFromModule(__PACKAGE__,
			courseID => $courseID, setID => $setID, problemID => $prevID);
		push @links, "Previous Problem", $r->location . $prevPage->path, "navPrev";
	} else {
		push @links, "Previous Problem", "", "navPrev";
	}
	
	push @links, "Problem List", $r->location . $urlpath->parent->path, "navProbList";
	
	if ($nextID) {
		my $nextPage = $urlpath->newFromModule(__PACKAGE__,
			courseID => $courseID, setID => $setID, problemID => $nextID);
		push @links, "Next Problem", $r->location . $nextPage->path, "navNext";
	} else {
		push @links, "Next Problem", "", "navNext";
	}
	
	my $tail = "&displayMode=".$self->{displayMode};
	return $self->navMacro($args, $tail, @links);
}

sub title {
	my ($self) = @_;

	# using the url arguments won't break if the set/problem are invalid
	my $setID = $self->r->urlpath->arg("setID");
	my $problemID = $self->r->urlpath->arg("problemID");
	
	#my $setID = $self->{set}->set_id;
	#my $problemID = $self->{problem}->problem_id;
	
	return "$setID : $problemID";
}

sub body {
	my $self = shift;
	my $r = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;
	my $urlpath = $r->urlpath;

	if ($self->{invalidSet}) {
		return CGI::div({class=>"ResultsWithError"},
			CGI::p("The selected problem set (" . $urlpath->arg("setID") . ") is not a valid set for " . $r->param("effectiveUser") . "."));
	}	
	
	if ($self->{invalidProblem}) {
		return CGI::div({class=>"ResultsWithError"},
			CGI::p("The selected problem (" . $urlpath->arg("problemID") . ") is not a valid problem for set " . $self->{set}->set_id . "."));
	}	

	unless ($self->{isOpen}) {
		return CGI::div({class=>"ResultsWithError"},
			CGI::p("This problem is not available because the problem set that contains it is not yet open."));
	}
	# unpack some useful variables
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
	
	#my $root = $ce->{webworkURLs}->{root};
	my $courseName = $urlpath->arg("courseID");
	
	#####create Editor link   #####
	## print editor link if the user is an instructor AND the file is not in temporary editing mode
	#my $editorLinkMessage   =   '';
	## and ( (not defined($self->{editMode}))  or $self->{editMode} eq 'savedFile')  # FIXME is this needed?
	#if ($self->{permissionLevel}>=10  ) {
	#	$editorLinkMessage = CGI::a({-href=>$ce->{webworkURLs}->{root}."/$courseName/instructor/pgProblemEditor/".
	#	$set->set_id.'/'.$problem->problem_id.'?'.$self->url_authen_args},'Edit this problem');
	#}
	
	my $editorLink = "";
	# if we are here without a real problem set, carry that through
	my $forced_field = [];
	$forced_field = ['sourceFilePath' =>  $r->param("sourceFilePath")] if
		($set->set_id eq 'Undefined_Set');
	if ($self->{permissionLevel}>=10) {
		my $editorPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::PGProblemEditor",
			courseID => $courseName, setID => $set->set_id, problemID => $problem->problem_id);
		my $editorURL = $self->systemLink($editorPage, params=>$forced_field);
		$editorLink = CGI::a({href=>$editorURL}, "Edit this problem");
	}
	
	##### translation errors? #####
	
	if ($pg->{flags}->{error_flag}) {
		print $self->errorOutput($pg->{errors}, $pg->{body_text});
		print $editorLink;
		return "";
	}
	
	##### answer processing #####
	$WeBWorK::timer->continue("begin answer processing") if defined($WeBWorK::timer);
	# if answers were submitted:
	my $scoreRecordedMessage;
	my $pureProblem;
	if ($submitAnswers) {
		# get a "pure" (unmerged) UserProblem to modify
		# this will be undefined if the problem has not been assigned to this user
		$pureProblem = $db->getUserProblem($problem->user_id, $problem->set_id, $problem->problem_id); # checked
		if (defined $pureProblem) {
			# store answers in DB for sticky answers
			my %answersToStore;
			my %answerHash = %{ $pg->{answers} };
			$answersToStore{$_} = $self->{formFields}->{$_}  #$answerHash{$_}->{original_student_ans} -- this may have been modified for fields with multiple values.  Don't use it!!
				foreach (keys %answerHash);
			
			# There may be some more answers to store -- one which are auxiliary entries to a primary answer.  Evaluating
			# matrices works in this way, only the first answer triggers an answer evaluator, the rest are just inputs
			# however we need to store them.  Fortunately they are still in the input form.
			my @extra_answer_names  = @{ $pg->{flags}->{KEPT_EXTRA_ANSWERS}};
			$answersToStore{$_} = $self->{formFields}->{$_} foreach  (@extra_answer_names);
			
			# Now let's encode these answers to store them -- append the extra answers to the end of answer entry order
			my @answer_order = (@{$pg->{flags}->{ANSWER_ENTRY_ORDER}}, @extra_answer_names);
			my $answerString = encodeAnswers(%answersToStore,
				 @answer_order);
			
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

	my $answer_log    = $self->{ce}->{courseFiles}->{logs}->{'answer_log'};
	if ( defined($answer_log ) and defined($pureProblem)) {
		if ($submitAnswers ) {
			my $answerString = "";
			my %answerHash = %{ $pg->{answers} };
			# FIXME  this is the line 552 error.  make sure original student ans is defined.
			# The fact that it is not defined is probably due to an error in some answer evaluator.
			# But I think it is useful to suppress this error message in the log.
			foreach (sort keys %answerHash) {
				my $student_ans = $answerHash{$_}->{original_student_ans} ||'';
				$answerString  .= $student_ans."\t"	 
			}
			$answerString = '' unless defined($answerString); # insure string is defined.
			writeCourseLog($self->{ce}, "answer_log",
			        join("",
						'|', $problem->user_id,
						'|', $problem->set_id,
						'|', $problem->problem_id,
						'|',"\t",
						time(),"\t",
						$answerString,
					),
			);
			
		}
	}
	
	$WeBWorK::timer->continue("end answer processing") if defined($WeBWorK::timer);
	
	##### output #####
	
	print CGI::start_div({class=>"problemHeader"});
	
	# custom message for editor
	if ($permissionLevel >= 10 and defined $editMode) {
		if ($editMode eq "temporaryFile") {
			print CGI::p(CGI::i("Editing temporary file: ", $problem->source_file));
		} elsif ($editMode eq "savedFile") {
			# FIXME: this is all done automatically if submitError exists.
			#if ( defined($r->param('submiterror')) and $r->param('submiterror') ) {
			    # FIXME  The following line doesn't work because the submiterror hook has already been called.
			    # The actions below should take place during the initialization phase.
			#	$self->{submiterror} .= $r->param('submiterror');
			#	print CGI::p(CGI::div({class=>'ResultsWithError'},$self->{submiterror}));
			#} else {
			#	print CGI::p(CGI::div({ class=>'ResultsWithoutError'}, "Problem saved to: ", $problem->source_file));
			#}
		}
	}
	#FIXME  we need error messages here if the problem was really not saved.
	# attempt summary
	#FIXME -- the following is a kludge:  if showPartialCorrectAnswers is negative don't show anything.
	# until after the due date
	# do I need to check $wills{howCorrectAnswers} to make preflight work??
	if (($pg->{flags}->{showPartialCorrectAnswers}>= 0 and $submitAnswers) ) {
		# print this if user submitted answers OR requested correct answers
		
		print $self->attemptResults($pg, 1,
			$will{showCorrectAnswers},
			$pg->{flags}->{showPartialCorrectAnswers}, 1, 1);
	} elsif ($checkAnswers) {
		# print this if user previewed answers
		print CGI::div({class=>'ResultsWithError'},"ANSWERS ONLY CHECKED  -- ",CGI::br(),"ANSWERS NOT RECORDED", CGI::br() );
		print $self->attemptResults($pg, 1, $will{showCorrectAnswers}, 1, 1, 1);
			# show attempt answers
			# show correct answers if asked
			# show attempt results (correctness)
			# show attempt previews
	} elsif ($previewAnswers) {
		# print this if user previewed answers
		print CGI::div({class=>'ResultsWithError'},"PREVIEW ONLY -- NOT RECORDED"),CGI::br(),$self->attemptResults($pg, 1, 0, 0, 0, 1);
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
			($can{showCorrectAnswers} 
				? CGI::checkbox(
						-name    => "showCorrectAnswers",
						-checked => $will{showCorrectAnswers},
						-label   => "Show correct answers",
					) ." "
				: "" ), 
			($can{showHints} 
				? '<div style="color:red">'. CGI::checkbox(
					-name    => "showHints",
					-checked => $will{showHints},
					-label   => "Show Hints",
					) . "</div> "
				: " " ),
			($can{showSolutions} 
				? CGI::checkbox(
					-name    => "showSolutions",
					-checked => $will{showSolutions},
					-label   => "Show Solutions",
					) . " "
				: " " ),CGI::br(),
			CGI::submit(-name=>"previewAnswers",
				-label=>"Preview Answers"),
			($can{recordAnswers}
				? CGI::submit(-name=>"submitAnswers",
					-label=>"Submit Answers")
				: ""),
			( $can{checkAnswers}
				? CGI::submit(-name=>"checkAnswers",
					-label=>"Check Answers")
				: ""),
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
	
	my $notCountedMessage = ($problem->value) ? "" : "(This problem will not count towards your grade.)";
	print CGI::p(
		$submitAnswers ? $scoreRecordedMessage . CGI::br() : "",
		"You have attempted this problem $attempts $attemptsNoun.", CGI::br(),
		$problem->attempted
			? "Your recorded score is $lastScore.  $notCountedMessage" . CGI::br()
			: "",
		$setClosed ? $setClosedMessage : "You have $attemptsLeft $attemptsLeftNoun remaining."
	);
	print CGI::end_div();
		
	# save state for viewOptions
	print  CGI::hidden(
			   -name  => "showOldAnswers",
			   -value => $will{showOldAnswers}
		   ),

		   CGI::hidden(
			   -name  => "displayMode",
			   -value => $self->{displayMode}
		   );
	print( CGI::hidden(
			   -name    => 'editMode',
			   -value   => $self->{editMode},
		   )
	) if defined($self->{editMode}) and $self->{editMode} eq 'temporaryFile';
	print( CGI::hidden(
		   		-name   => 'sourceFilePath',
		   		-value  =>  $self->{problem}->{source_file}
	))  if defined($self->{problem}->{source_file});
			
	# end of main form
	print CGI::endform();
	
	print  CGI::start_div({class=>"problemFooter"});
	
	## arguments for answer inspection button
	#my $prof_url = $ce->{webworkURLs}->{oldProf};
	#my $webworkURL = $ce->{webworkURLs}->{root};
	#my $cgi_url = $prof_url;
	#$cgi_url=~ s|/[^/]*$||;  # clip profLogin.pl
	#my $authen_args = $self->url_authen_args();
	#my $showPastAnswersURL = "$webworkURL/$courseName/instructor/show_answers/";
	
	my $pastAnswersPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Instructor::ShowAnswers",
		courseID => $courseName);
	my $showPastAnswersURL = $self->systemLink($pastAnswersPage, authen => 0); # no authen info for form action
		
	# print answer inspection button
	if ($self->{permissionLevel} > 0) {
		print "\n",
			CGI::start_form(-method=>"POST",-action=>$showPastAnswersURL,-target=>"information"),"\n",
			$self->hidden_authen_fields,"\n",
			CGI::hidden(-name => 'courseID',  -value=>$courseName), "\n",
			CGI::hidden(-name => 'problemID', -value=>$problem->problem_id), "\n",
			CGI::hidden(-name => 'setID',  -value=>$problem->set_id), "\n",
			CGI::hidden(-name => 'studentUser',    -value=>$problem->user_id), "\n",
			CGI::p( {-align=>"left"},
				CGI::submit(-name => 'action',  -value=>'Show Past Answers')
			), "\n",
			CGI::endform();
	}
	
	## arguments for feedback form
	#my $feedbackURL = "$root/$courseName/feedback/";
	#
	##print feedback form
	#print
	#	CGI::start_form(-method=>"POST", -action=>$feedbackURL),"\n",
	#	$self->hidden_authen_fields,"\n",
	#	CGI::hidden("module",             __PACKAGE__),"\n",
	#	CGI::hidden("set",                $set->set_id),"\n",
	#	CGI::hidden("problem",            $problem->problem_id),"\n",
	#	CGI::hidden("displayMode",        $self->{displayMode}),"\n",
	#	CGI::hidden("showOldAnswers",     $will{showOldAnswers}),"\n",
	#	CGI::hidden("showCorrectAnswers", $will{showCorrectAnswers}),"\n",
	#	CGI::hidden("showHints",          $will{showHints}),"\n",
	#	CGI::hidden("showSolutions",      $will{showSolutions}),"\n",
	#	CGI::p({-align=>"left"},
	#		CGI::submit(-name=>"feedbackForm", -label=>"Email instructor")
	#	),
	#	CGI::endform(),"\n";
		
	# feedback form url
	my $feedbackPage = $urlpath->newFromModule("WeBWorK::ContentGenerator::Feedback",
		courseID => $courseName);
	my $feedbackURL = $self->systemLink($feedbackPage, authen => 0); # no authen info for form action
	
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
			CGI::submit(-name=>"feedbackForm", -label=>"Email instructor")
		),
		CGI::endform(),"\n";
	
	# FIXME print editor link
	print $editorLink;   #empty unless it is appropriate to have an editor link.
	
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

sub attemptResults {
	my $self = shift;
	my $pg = shift;
	my $showAttemptAnswers = shift;
	my $showCorrectAnswers = shift;
	my $showAttemptResults = $showAttemptAnswers && shift;
	my $showSummary = shift;
	my $showAttemptPreview = shift || 0;
	
	my $ce = $self->r->ce;
	
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
	#$header .= CGI::th("Part");
	$header .= $showAttemptAnswers ? CGI::th("Entered")  : "";
	$header .= $showAttemptPreview ? CGI::th("Answer Preview")  : "";
	$header .= $showCorrectAnswers ? CGI::th("Correct")  : "";
	$header .= $showAttemptResults ? CGI::th("Result")   : "";
	$header .= $showMessages       ? CGI::th("Messages") : "";
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
		#FIXME  --Can we be sure that $answerScore is an integer-- could the problem give partial credit?
		$numCorrect += $answerScore > 0;
		my $resultString = $answerScore == 1 ? "correct" : "incorrect";
		
		# get rid of the goofy prefix on the answer names (supposedly, the format
		# of the answer names is changeable. this only fixes it for "AnSwEr"
		#$name =~ s/^AnSwEr//;
		
		my $row;
		#$row .= CGI::td($name);
		$row .= $showAttemptAnswers ? CGI::td($self->nbsp($studentAnswer)) : "";
		$row .= $showAttemptPreview ? CGI::td($self->nbsp($preview))       : "";
		$row .= $showCorrectAnswers ? CGI::td($self->nbsp($correctAnswer)) : "";
		$row .= $showAttemptResults ? CGI::td($self->nbsp($resultString))  : "";
		$row .= $showMessages       ? CGI::td($self->nbsp($answerMessage)) : "";
		push @tableRows, $row;
	}
	
	# render equation images
	$imgGen->render(refresh => 1);
	
#	my $numIncorrectNoun = scalar @answerNames == 1 ? "question" : "questions";
	my $scorePercent = sprintf("%.0f%%", $problemResult->{score} * 100);
#   FIXME  -- I left the old code in in case we have to back out.
#	my $summary = "On this attempt, you answered $numCorrect out of "
#		. scalar @answerNames . " $numIncorrectNoun correct, for a score of $scorePercent.";
	my $summary = ""; 
	if (scalar @answerNames == 1) {
			if ($numCorrect == scalar @answerNames) {
				$summary .= CGI::div({class=>"ResultsWithoutError"},"The above answer is correct.");
			 } else {
			 	 $summary .= CGI::div({class=>"ResultsWithError"},"The above answer is NOT correct.");
			 }
	} else {
			if ($numCorrect == scalar @answerNames) {
				$summary .= CGI::div({class=>"ResultsWithoutError"},"All of the above answers are correct.");
			 } else {
			 	 $summary .= CGI::div({class=>"ResultsWithError"},"At least one of the above answers is NOT correct.");
			 }
	}
	
	return
		CGI::table({-class=>"attemptResults"}, CGI::Tr(\@tableRows))
		. ($showSummary ? CGI::p({class=>'emphasis'},$summary) : "");
}

#sub nbsp {
#	my $str = shift;
#	($str =~/\S/) ? $str : '&nbsp;'  ;  # returns non-breaking space for empty strings
#	                                    # tricky cases:   $str =0;
#	                                    #  $str is a complex number
#}

sub viewOptions {
	my ($self) = @_;
	my $ce = $self->r->ce;
	
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

	$optionLine and $optionLine .= join "", CGI::br();
	
	my %display_modes = %{WeBWorK::PG::DISPLAY_MODES()};
	my @active_modes = grep { exists $display_modes{$_} }
			@{$ce->{pg}->{displayModes}};
	
	return CGI::div({-style=>"border: thin groove; padding: 1ex; margin: 2ex align: left"},
			"View&nbsp;equations&nbsp;as:&nbsp;&nbsp;&nbsp;&nbsp;".CGI::br(),
		CGI::radio_group(
			-name    => "displayMode",
			-values  => \@active_modes,
			-default => $displayMode,
			-linebreak=>'true',
			-labels  => {
				plainText     => "plain",
				formattedText => "formatted",
				images        => "images",
				jsMath	      => "jsMath",
				asciimath     => "asciimath",
			},
		), CGI::br(),CGI::hr(),
		$optionLine,
		CGI::submit(-name=>"redisplay", -label=>"Save Options"),
	);
}

sub previewAnswer {
	my ($self, $answerResult, $imgGen) = @_;
	my $ce            = $self->r->ce;
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
		$imgGen->add($tex);
 	} elsif ($displayMode eq "jsMath") {
 	
 	  return '<DIV CLASS="math">'.$tex.'</DIV>' ;
 	
 	
 	
 	
 	}
}

##### permission queries #####

# this stuff should be abstracted out into the permissions system
# however, the permission system only knows about things in the
# course environment and the username. hmmm...

# also, i should fix these so that they have a consistent calling
# format -- perhaps:
# 	canPERM($ce, $user, $set, $problem, $permissionLevel)

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


# FIXME: does this even get used?
sub submiterror  {
	my $self = shift;
	my $submiterror = (defined($self->{submiterror}) ) ? $self->{submiterror} : '';
	$submiterror;
}
1;
