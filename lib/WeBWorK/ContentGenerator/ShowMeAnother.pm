################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::ShowMeAnother;
use Mojo::Base 'WeBWorK::ContentGenerator::Problem', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator::ShowMeAnother - Show students alternate versions of current problems.

=cut

use WeBWorK::Debug;
use WeBWorK::Utils::JITAR qw(jitar_id_to_seq);
use WeBWorK::Utils::Rendering qw(getTranslatorDebuggingOptions renderPG);
use WeBWorK::Utils::Sets qw(format_set_name_display);

async sub pre_header_initialize ($c) {
	my $ce = $c->ce;
	my $db = $c->db;

	# Remove the showMeAnother session key if it used for another set or problem.
	delete $c->authen->session->{showMeAnother}
		if $c->authen->session->{showMeAnother}
		&& (
			(
				defined $c->authen->session->{showMeAnother}{setID}
				&& $c->authen->session->{showMeAnother}{setID} ne $c->stash('setID')
			)
			|| (defined $c->authen->session->{showMeAnother}{problemID}
				&& $c->authen->session->{showMeAnother}{problemID} ne $c->stash('problemID'))
		);

	# Run the parent package pre_header_initialize to initialize data used by this package.
	# FIXME: This is highly inefficient. At the very least it results in yet another renderPG call (generally a very
	# expensive call) that is not used. There are also many things done by the parent package in initialization that
	# shouldn't be done for this package (like processing for problem randomization).
	await $c->SUPER::pre_header_initialize;

	unless ($c->{can}{showMeAnother}) {
		delete $c->authen->session->{showMeAnother};
		return;
	}

	# Note that a hash containing the following information for showMeAnother is set by the parent package.
	#   TriesNeeded:   The number of times the student needs to attempt this problem before the button is available.
	#   MaxReps:       The maximum number of times that showMeAnother can be used for this problem.
	#   Count:         The number of times the student has used showMeAnother for this problem..
	#                  checked or previewed.

	my $initializeSMA = !$c->authen->session->{showMeAnother}
		|| ($c->authen->session->{showMeAnother} && !($c->{checkAnswers} || $c->{previewAnswers}));

	# This will be set to true if changing the seed changes the problem (assume this is NOT the case by default).
	$c->stash->{isPossible} = 0;

	# The options available when showMeAnother is active. These are set via course configuration options.
	my %SMAOptions = map { $_ => 1 } @{ $ce->{pg}{options}{showMeAnother} };
	$c->stash->{options} =
		{ map { $_ => exists($SMAOptions{"SMA$_"}) } qw(checkAnswers showSolutions showCorrect showHints) };

	$c->{want}{showMeAnother} = 1;

	# Store text of original problem for later comparison with text from problem with new seed.
	my $showMeAnotherOriginalPG = await renderPG(
		$c,
		$c->{effectiveUser},
		$c->{set},
		$c->{problem},
		$c->{set}->psvn,
		$c->{formFields},
		{
			displayMode              => 'plainText',
			showHints                => 0,
			showSolutions            => 0,
			forceScaffoldsOpen       => 1,
			refreshMath2img          => 0,
			processAnswers           => 1,
			permissionLevel          => $db->getPermissionLevel($c->{userID})->permission,
			effectivePermissionLevel => $db->getPermissionLevel($c->{effectiveUserID})->permission,
			useMathQuill             => $c->{will}{useMathQuill},
			useMathView              => $c->{will}{useMathView},
		},
	);

	my $orig_body_text = $showMeAnotherOriginalPG->{body_text};
	for (keys %{ $showMeAnotherOriginalPG->{resource_list} }) {
		$orig_body_text =~ s/$showMeAnotherOriginalPG->{resource_list}{$_}//g
			if defined $showMeAnotherOriginalPG->{resource_list}{$_};
	}

	# If showMeAnother is being initialized and the user can use showMeAnother,
	# then output a new problem in a new tab with a new seed.
	if ($initializeSMA) {
		# Change the problem seed.
		my $oldProblemSeed = $c->{problem}{problem_seed};
		my $newProblemSeed;

		# Check to see if changing the problem seed will change the problem.
		for my $i (0 .. $ce->{pg}{options}{showMeAnotherGeneratesDifferentProblem}) {
			do { $newProblemSeed = int(rand(10000)) } until ($newProblemSeed != $oldProblemSeed);
			$c->{problem}->problem_seed($newProblemSeed);
			my $showMeAnotherNewPG = await renderPG(
				$c,
				$c->{effectiveUser},
				$c->{set},
				$c->{problem},
				$c->{set}->psvn,
				$c->{formFields},
				{
					displayMode              => 'plainText',
					showHints                => 0,
					showSolutions            => 0,
					forceScaffoldsOpen       => 1,
					refreshMath2img          => 0,
					processAnswers           => 1,
					permissionLevel          => $db->getPermissionLevel($c->{userID})->permission,
					effectivePermissionLevel => $db->getPermissionLevel($c->{effectiveUserID})->permission,
					useMathQuill             => $c->{will}{useMathQuill},
					useMathView              => $c->{will}{useMathView},
				},
			);

			my $new_body_text = $showMeAnotherNewPG->{body_text};
			for (keys %{ $showMeAnotherNewPG->{resource_list} }) {
				$new_body_text =~ s/$showMeAnotherNewPG->{resource_list}{$_}//g
					if defined $showMeAnotherNewPG->{resource_list}{$_};
			}

			# Check to see a new version has been found.
			if ($new_body_text ne $orig_body_text
				|| have_different_answers($showMeAnotherNewPG, $showMeAnotherOriginalPG))
			{
				# Increment the counter detailing the number of times showMeAnother has been used,
				# and update the database.
				my $userProblem =
					$db->getUserProblem($c->{effectiveUserID}, $c->stash('setID'), $c->stash('problemID'));
				$userProblem->{showMeAnotherCount} = ++$c->{showMeAnother}{Count};
				$db->putUserProblem($userProblem);

				# Save the problem seed from ShowMeAnother so that it can be used when the page reloads.
				$c->authen->session->{showMeAnother}{problemSeed} = $newProblemSeed;
				$c->authen->session->{showMeAnother}{problemID}   = $c->stash('problemID');
				$c->authen->session->{showMeAnother}{setID}       = $c->stash('setID');

				$c->stash->{isPossible} = 1;
				last;
			} else {
				delete $c->authen->session->{showMeAnother};
			}
		}
	} elsif ($c->{checkAnswers} || $c->{previewAnswers}) {
		$c->stash->{isPossible} = 1;
		$c->{problem}->problem_seed($c->authen->session->{showMeAnother}{problemSeed});
	} else {
		delete $c->authen->session->{showMeAnother};
	}

	# Disable options that are not applicable for showMeAnother.
	$c->{can}{recordAnswers}     = 0;
	$c->{can}{checkAnswers}      = 0;    # This is turned on if the showMeAnother conditions are met below.
	$c->{can}{getSubmitButton}   = 0;
	$c->{can}{showProblemGrader} = 0;

	if ($c->stash->{isPossible}) {
		$c->{can}{showCorrectAnswers} =
			$c->stash->{options}{showCorrect} && $c->stash->{options}{checkAnswers};
		$c->{can}{checkAnswers} = $c->stash->{options}{checkAnswers};
		# If the user can see hints or solutions in the original problem, then the user is allowed to see them here
		# as well regardless of the SMA setting.
		$c->{can}{showHints}     = $c->stash->{options}{showHints}     || $c->{can}{showHints};
		$c->{can}{showSolutions} = $c->stash->{options}{showSolutions} || $c->{can}{showSolutions};
	}

	# Final values for will.
	$c->{will}{$_} = $c->{can}{$_} && $c->{want}{$_} for keys %{ $c->{can} };

	return unless $c->stash->{isPossible};

	# Final PG problem translation.
	debug('begin pg processing');
	my $pg = await renderPG(
		$c,
		$c->{effectiveUser},
		$c->{set},
		$c->{problem},
		$c->{set}->psvn,
		$c->{formFields},
		{
			displayMode              => $c->{displayMode},
			showHints                => $c->{will}{showHints},
			showSolutions            => $c->{will}{showSolutions},
			refreshMath2img          => $c->{will}{showHints} || $c->{will}{showSolutions},
			processAnswers           => 1,
			permissionLevel          => $db->getPermissionLevel($c->{userID})->permission,
			effectivePermissionLevel => $db->getPermissionLevel($c->{effectiveUserID})->permission,
			useMathQuill             => $c->{will}{useMathQuill},
			useMathView              => $c->{will}{useMathView},
			forceScaffoldsOpen       => 0,
			isInstructor             => $c->authz->hasPermissions($c->{userID}, 'view_answers'),
			showFeedback             => $c->{checkAnswers} || $c->{previewAnswers},
			showAttemptAnswers       => $ce->{pg}{options}{showEvaluatedAnswers},
			showAttemptPreviews      => 1,
			showAttemptResults       => $c->{checkAnswers},
			showMessages             => 1,
			showCorrectAnswers       => $c->{will}{checkAnswers} && $c->{will}{showCorrectAnswers} ? 1 : 0,
			debuggingOptions         => getTranslatorDebuggingOptions($c->authz, $c->{userID})
		}
	);

	# Warnings in the renderPG subprocess will not be caught by the global warning handler of this process.
	# So rewarn them and let the global warning handler take care of it.
	warn $pg->{warnings} if $pg->{warnings};

	debug('end pg processing');

	# Update and fix hint/solution options after PG processing
	$c->{can}{showHints}     &&= $pg->{flags}{hintExists};
	$c->{can}{showSolutions} &&= $pg->{flags}{solutionExists};

	# Record errors
	$c->{pgdebug}          = $pg->{debug_messages}          if ref $pg->{debug_messages} eq 'ARRAY';
	$c->{pgwarning}        = $pg->{warning_messages}        if ref $pg->{warning_messages} eq 'ARRAY';
	$c->{pginternalerrors} = $pg->{internal_debug_messages} if ref $pg->{internal_debug_messages} eq 'ARRAY';
	# $c->{pgerrors} is defined if any of the above are defined, and is nonzero if any are non-empty.
	$c->{pgerrors} = @{ $c->{pgdebug} // [] } || @{ $c->{pgwarning} // [] } || @{ $c->{pginternalerrors} // [] }
		if defined $c->{pgdebug} || defined $c->{pgwarning} || defined $c->{pginternalerrors};

	# If $c->{pgerrors} is not defined, then the PG messages arrays were not defined,
	# which means $pg->{pgcore} was not defined and the translator died.
	warn 'Processing of this PG problem was not completed.  Probably because of a syntax error. '
		. 'The translator died prematurely and no PG warning messages were transmitted.'
		unless defined $c->{pgerrors};

	$c->{pg} = $pg;

	return;
}

# Disable showOldAnswers because old answers are answers to the original question and not to this question.
sub can_showOldAnswers ($c, $user, $effectiveUser, $set, $problem) { return 0 }

sub page_title ($c) {
	my $set = $c->db->getGlobalSet($c->stash('setID'));

	my $problemID = $c->stash('problemID');
	$problemID = join('.', jitar_id_to_seq($problemID)) if $set && $set->assignment_type eq 'jitar';

	my $header = $c->maketext('[_1]: Problem [_2] Show Me Another',
		$c->tag('span', dir => 'ltr', format_set_name_display($c->stash('setID'))), $problemID);

	# Return here if requisite information is missing.
	return $header if $c->{invalidSet} || $c->{invalidProblem};

	my $ce      = $c->ce;
	my $problem = $c->{problem};

	my $subheader = '';

	# FIXME: Should the show me another show points?
	my $problemValue = $problem->value;
	if (defined $problemValue) {
		my $points = $problemValue == 1 ? $c->maketext('point') : $c->maketext('points');
		$subheader .= "($problemValue $points)";
	}

	# This uses the permission level and user id of the user assigned to the problem.
	my $problemUser = $problem->user_id;
	if ($c->db->getPermissionLevel($problemUser)->permission >=
		$ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_PERMISSION_LEVEL}
		|| grep { $_ eq $problemUser } @{ $ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} })
	{
		$subheader .= ' ' . $problem->source_file;
	}

	return $c->c($header, $c->tag('span', class => 'problem-sub-header d-block', $subheader))->join('');
}

# Output the body of the current problem
sub output_problem_body ($c) {
	# Ignore body if SMA was pushed and no new problem will be shown.
	return $c->SUPER::output_problem_body if $c->stash->{isPossible};
	return '';
}

# Output messages about the problem
sub output_message ($c) {
	return $c->include('ContentGenerator/ShowMeAnother/messages');
}

# Prints out the checkbox input elements that are available for the current problem
sub output_checkboxes ($c) {
	# Skip check boxes if SMA was pushed and no new problem will be shown
	return $c->SUPER::output_checkboxes if $c->stash->{isPossible};
	return '';
}

# Prints out the submit button input elements that are available for the current problem
sub output_submit_buttons ($c) {
	# Skip buttons if SMA button has been pushed but there is no new problem shown
	return $c->SUPER::output_submit_buttons if $c->stash->{isPossible};
	return '';
}

# Skip the score summary, instructor comments, instructor problem grader, and navigation bar.
sub output_score_summary ($c)        { return '' }
sub output_comments      ($c)        { return '' }
sub output_grader        ($c)        { return '' }
sub nav                  ($c, $args) { return '' }

# Outputs the summary of the questions that the student has answered for the
# current problem, along with available information about correctness.
sub output_summary ($c) {
	my $ce = $c->ce;
	my $db = $c->db;

	my $output = $c->c;

	if (!$c->{can}{showMeAnother}) {
		# Nothing more needs to be said in the case that showMeAnother is not enabled for the course or problem.
		if (!$ce->{pg}{options}{enableShowMeAnother} || $c->{showMeAnother}{TriesNeeded} < 0) {
			push(
				@$output,
				$c->tag(
					'div',
					class => 'alert alert-danger mb-2 p-1',
					$c->maketext('You are not allowed to use Show Me Another for this problem.')
				)
			);
		} elsif ($c->{showMeAnother}{Count} >= $c->{showMeAnother}{MaxReps}) {
			push(
				@$output,
				$c->tag(
					'div',
					class => 'alert alert-warning mb-2 p-1',
					$c->maketext(
						'You are only allowed to click on Show Me Another [quant,_1,time,times] per problem. '
							. 'Close this tab, and return to the original problem.',
						$c->{showMeAnother}{MaxReps},
					)
				)
			);
		} elsif ($c->{showMeAnother}{Count} < $c->{showMeAnother}{TriesNeeded}) {
			push(
				@$output,
				$c->tag(
					'div',
					class => 'alert alert-warning mb-2 p-1',
					$c->maketext(
						'You must attempt this problem [quant,_1,time,times] before Show Me Another is available.',
						$c->{showMeAnother}{TriesNeeded}
					)
				)
			);
		}
	} elsif (!$c->stash->{isPossible}) {
		# It was not possible to find a new version of the problem.
		push(
			@$output,
			$c->tag(
				'div',
				class => 'alert alert-warning mb-2 p-1',
				$c->maketext(
					'WeBWorK was unable to generate a different version of this problem. '
						. 'Close this tab, and return to the original problem.'
				)
			)
		);
	} elsif ($c->{checkAnswers}) {
		push(
			@$output,
			$c->tag(
				'div',
				class => 'showMeAnotherBox',
				$c->maketext(
					'You are currently checking answers to a different version of your problem.  These answers '
						. 'will not be recorded, and you should remember to return to your original problem '
						. 'once you are done here.'
				)
			)
		);
	} elsif ($c->{previewAnswers}) {
		push(
			@$output,
			$c->tag(
				'div',
				class => 'showMeAnotherBox',
				$c->maketext(
					'You are currently previewing answers to a different version of your problem - these '
						. 'will not be recorded, and you should remember to return to your original problem '
						. 'once you are done here.'
				)
			)
		);
	} else {
		my $solutionShown = '';
		if ($c->{showMeAnother}{Count} <= $c->{showMeAnother}{MaxReps} || ($c->{showMeAnother}{MaxReps} == -1)) {
			# check to see if a solution exists for this problem, and vary the feedback accordingly
			if ($c->{pg}{flags}{solutionExists} && $c->stash->{options}{showSolutions}) {
				$solutionShown = $c->maketext('There is a solution available.');
			} elsif ($c->stash->{options}{showSolutions}
				&& $c->stash->{options}{showCorrect}
				&& $c->stash->{options}{checkAnswers})
			{
				$solutionShown = $c->maketext('There is no written solution available for this problem, '
						. 'but you can still view the correct answers.');
			} elsif ($c->stash->{options}{showSolutions}) {
				$solutionShown = $c->maketext('There is no solution available for this problem.');
			}
		}
		push(
			@$output,
			$c->tag(
				'div',
				class => 'showMeAnotherBox',
				$c->c(
					$c->maketext('Here is a new version of your problem.'),
					$solutionShown,
					$c->stash->{options}{checkAnswers}
					? $c->maketext(
						'You may check your answers to this problem without affecting '
							. 'the maximum number of tries to your original problem.'
						)
					: ''
				)->join(' ')
			),
			$c->tag(
				'div',
				class => 'alert alert-warning mb-2 p-1',
				$c->maketext(q{Remember to return to your original problem when you're finished here!})
			)
		);
	}

	push(@$output, $c->SUPER::output_summary) if $c->stash->{isPossible} && $c->{can}{showMeAnother};

	return $output->join('');
}

# Checks the PG object for two different seeds of the same pg file
sub have_different_answers ($pg1, $pg2) {
	for (keys %{ $pg1->{answers} }) {
		return 1 if $pg1->{answers}{$_}{correct_ans} ne $pg2->{answers}{$_}{correct_ans};
	}
	return 0;
}

1;
