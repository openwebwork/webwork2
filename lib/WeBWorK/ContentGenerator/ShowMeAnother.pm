################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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
use parent qw(WeBWorK::ContentGenerator::Problem);

=head1 NAME

WeBWorK::ContentGenerator::ShowMeAnother - Show students alternate versions of current problems.

=cut

use strict;
use warnings;

use Future::AsyncAwait;

use WeBWorK::Debug;
use WeBWorK::Utils qw(wwRound before after jitar_id_to_seq format_set_name_display);
use WeBWorK::Utils::Rendering qw(getTranslatorDebuggingOptions renderPG);

async sub pre_header_initialize {
	my ($self)  = @_;
	my $r       = $self->r;
	my $ce      = $r->ce;
	my $db      = $r->db;
	my $authz   = $r->authz;
	my $urlpath = $r->urlpath;

	my $setName           = $urlpath->arg('setID');
	my $problemNumber     = $r->urlpath->arg('problemID');
	my $userName          = $r->param('user');
	my $effectiveUserName = $r->param('effectiveUser');
	my $key               = $r->param('key');
	my $editMode          = $r->param('editMode');

	# We want to run the existing pre_header_initialize with
	# the database seed to get a pure copy of the original problem
	# to test against.

	my $problemSeed = $r->param('problemSeed');
	$r->param('problemSeed', '');

	# Run existsing initialization
	await $self->SUPER::pre_header_initialize();

	# This has to be set back because of sticky params.
	$r->param('problemSeed', $problemSeed);

	my $user           = $self->{user};
	my $effectiveUser  = $self->{effectiveUser};
	my $set            = $self->{set};
	my $problem        = $self->{problem};
	my $displayMode    = $self->{displayMode};
	my $redisplay      = $self->{redisplay};
	my $submitAnswers  = $self->{submitAnswers};
	my $checkAnswers   = $self->{checkAnswers};
	my $previewAnswers = $self->{previewAnswers};
	my $formFields     = $self->{formFields};

	# a hash containing information for showMeAnother
	#   active:        has the button been pushed?
	#   CheckAnswers:  has the user clicked Check Answers while SMA is active
	#   IsPossible:    checks to see if generating a new seed changes the problem (assume it is possible by default)
	#   TriesNeeded:   the number of times the student needs to attempt the problem before the button is available
	#   MaxReps:       the Maximum Number of times that showMeAnother can be clicked (specified in course configuration)
	#   options:       the options available when showMeAnother has been pushed (check answers, see solution (when
	#                  available), see correct answer) these are set via check boxes from the configuration screen
	#   Count:         the number of times the student has clicked SMA (or clicked refresh on the page)
	#   Preview:       has the preview button been clicked while SMA is active?

	my %SMAoptions    = map { $_ => 1 } @{ $ce->{pg}{options}{showMeAnother} };
	my %showMeAnother = (
		active => !($checkAnswers or $previewAnswers)
			&& $ce->{pg}{options}{enableShowMeAnother}
			&& ($problem->{showMeAnother} > -1 || $problem->{showMeAnother} == -2),
		CheckAnswers => $checkAnswers
			&& $r->param('showMeAnotherCheckAnswers')
			&& $ce->{pg}{options}{enableShowMeAnother},
		IsPossible  => 1,
		TriesNeeded => $problem->{showMeAnother},
		MaxReps     => $ce->{pg}{options}{showMeAnotherMaxReps},
		options     => {
			checkAnswers  => exists($SMAoptions{'SMAcheckAnswers'}),
			showSolutions => exists($SMAoptions{'SMAshowSolutions'}),
			showCorrect   => exists($SMAoptions{'SMAshowCorrect'}),
			showHints     => exists($SMAoptions{'SMAshowHints'}),
		},
		Count   => $problem->{showMeAnotherCount},
		Preview => $previewAnswers
			&& $r->param('showMeAnotherCheckAnswers')
			&& $ce->{pg}{options}{enableShowMeAnother}
	);

	# if $showMeAnother{Count} is somehow not an integer, make it one
	$showMeAnother{Count} = 0 unless $showMeAnother{Count} =~ /^[+-]?\d+$/;

	# if $showMeAnother{TriesNeeded} is somehow not an integer or if its -2, use the default value
	$showMeAnother{TriesNeeded} = $ce->{pg}{options}{showMeAnotherDefault}
		if ($showMeAnother{TriesNeeded} !~ /^[+-]?\d+$/ || $showMeAnother{TriesNeeded} == -2);

	# store the showMeAnother hash for the check to see if the button can be used
	# (this hash is updated and re-stored after the can, must, will hashes)
	$self->{showMeAnother} = \%showMeAnother;

	# Show a message if we aren't allowed to show me another here.
	unless ($self->can_showMeAnother($user, $effectiveUser, $set, $problem, 0)) {
		$self->addbadmessage('You are not allowed to use Show Me Another for this problem.');
		return;
	}

	my $want = $self->{want};
	$want->{showMeAnother} = 1;

	my $must = $self->{must};
	$must->{showMeAnother} = 0;

	# does the user have permission to use certain options?
	my @args = ($user, $effectiveUser, $set, $problem);

	my $can = $self->{can};
	$can->{showMeAnother} = $self->can_showMeAnother(@args, $submitAnswers);

	# store text of original problem for later comparison with text from problem with new seed
	my $showMeAnotherOriginalPG = await renderPG(
		$r,
		$effectiveUser,
		$set, $problem,
		$set->psvn,
		$formFields,
		{    # translation options
			displayMode              => 'plainText',
			showHints                => 0,
			showSolutions            => 0,
			refreshMath2img          => 0,
			processAnswers           => 0,
			permissionLevel          => $db->getPermissionLevel($userName)->permission,
			effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
			useMathQuill             => $self->{will}{useMathQuill},
			useMathView              => $self->{will}{useMathView},
			useWirisEditor           => $self->{will}{useWirisEditor},
		},
	);

	my $orig_body_text = $showMeAnotherOriginalPG->{body_text};
	for (keys %{ $showMeAnotherOriginalPG->{resource_list} }) {
		$orig_body_text =~ s/$showMeAnotherOriginalPG->{resource_list}{$_}//g
			if defined $showMeAnotherOriginalPG->{resource_list}{$_};
	}

	# if showMeAnother is active, then output a new problem in a new tab with a new seed
	if ($showMeAnother{active} and $can->{showMeAnother}) {

		# change the problem seed
		my $oldProblemSeed = $problem->{problem_seed};
		my $newProblemSeed;

		# check to see if changing the problem seed will change the problem
		for my $i (0 .. $ce->{pg}{options}{showMeAnotherGeneratesDifferentProblem}) {
			do { $newProblemSeed = int(rand(10000)) } until ($newProblemSeed != $oldProblemSeed);
			$problem->{problem_seed} = $newProblemSeed;
			my $showMeAnotherNewPG = await renderPG(
				$r,
				$effectiveUser,
				$set, $problem,
				$set->psvn,
				$formFields,
				{    # translation options
					displayMode              => 'plainText',
					showHints                => 0,
					showSolutions            => 0,
					refreshMath2img          => 0,
					processAnswers           => 0,
					permissionLevel          => $db->getPermissionLevel($userName)->permission,
					effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
					useMathQuill             => $self->{will}{useMathQuill},
					useMathView              => $self->{will}{useMathView},
					useWirisEditor           => $self->{will}{useWirisEditor},
				},
			);

			my $new_body_text = $showMeAnotherNewPG->{body_text};
			for (keys %{ $showMeAnotherNewPG->{resource_list} }) {
				$new_body_text =~ s/$showMeAnotherNewPG->{resource_list}{$_}//g
					if defined $showMeAnotherNewPG->{resource_list}{$_};
			}

			# check to see if we've found a new version
			if ($new_body_text ne $orig_body_text) {
				# if we've found a new version, then
				# increment the counter detailing the number of times showMeAnother has been used
				# unless we're trying to check answers from the showMeAnother screen
				unless ($showMeAnother{CheckAnswers}) {

					$showMeAnother{Count}++ unless ($showMeAnother{CheckAnswers});
					# update the database (make sure to put the old problem seed back in)
					my $userProblem = $db->getUserProblem($effectiveUserName, $setName, $problemNumber);
					$userProblem->{showMeAnotherCount} = $showMeAnother{Count};
					$db->putUserProblem($userProblem);
				}

				# make sure to switch on the possibility
				$showMeAnother{IsPossible} = 1;

				# exit the loop
				last;
			} else {
				# otherwise a new version was *not* found, and
				# showMeAnother is not possible
				$showMeAnother{IsPossible} = 0;
			}
		}

	} elsif (($showMeAnother{CheckAnswers} or $showMeAnother{Preview})
		&& defined($problemSeed)
		&& $problemSeed != $problem->problem_seed)
	{
		$showMeAnother{IsPossible} = 1;
		$problem->problem_seed($problemSeed);
		#### One last check to see if students  have hard coded in a key
		#### which matches the original problem
		my $showMeAnotherNewPG = await renderPG(
			$r,
			$effectiveUser,
			$set, $problem,
			$set->psvn,
			$formFields,
			{    # translation options
				displayMode              => 'plainText',
				showHints                => 0,
				showSolutions            => 0,
				refreshMath2img          => 0,
				processAnswers           => 0,
				permissionLevel          => $db->getPermissionLevel($userName)->permission,
				effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
				useMathQuill             => $self->{will}{useMathQuill},
				useMathView              => $self->{will}{useMathView},
				useWirisEditor           => $self->{will}{useWirisEditor},
			},
		);

		if ($showMeAnotherNewPG->{body_text} eq $showMeAnotherOriginalPG->{body_text}) {
			$showMeAnother{IsPossible}   = 0;
			$showMeAnother{CheckAnswers} = 0;
			$showMeAnother{Preview}      = 0;
		}

	} else {
		$showMeAnother{IsPossible}   = 0;
		$showMeAnother{CheckAnswers} = 0;
		$showMeAnother{Preview}      = 0;
	}

	# if showMeAnother is active, then disable all other options
	if (($showMeAnother{active} || $showMeAnother{CheckAnswers} || $showMeAnother{Preview}) && $can->{showMeAnother}) {
		$can->{recordAnswers}   = 0;
		$can->{checkAnswers}    = 0;    # turned on if showMeAnother conditions met below
		$can->{getSubmitButton} = 0;

		# only show solution if showMeAnother has been clicked (or refreshed)
		# less than the maximum amount allowed specified in Course Configuration,
		# and also make sure that showMeAnother is possible
		if (($showMeAnother{Count} <= $showMeAnother{MaxReps} || $showMeAnother{MaxReps} == -1)
			&& $showMeAnother{IsPossible})
		{
			$can->{showCorrectAnswers} = $showMeAnother{options}{showCorrect} && $showMeAnother{options}{checkAnswers};
			$can->{checkAnswers}       = $showMeAnother{options}{checkAnswers};
			# If the user can see hints or solutions in the original problem, then the user is allowed to see them here
			# as well regardless of the SMA setting.
			$can->{showHints}     = $showMeAnother{options}{showHints}     || $self->{can}{showHints};
			$can->{showSolutions} = $showMeAnother{options}{showSolutions} || $self->{can}{showSolutions};
		}
	}

	# final values for options
	my $will = $self->{will};
	foreach (keys %$must) {
		$will->{$_} = $can->{$_} && ($want->{$_} || $must->{$_});
	}

	# PG problem translation
	# Unfortunately we have to do this over because we potentially picked a new problem seed.

	debug('begin pg processing');
	my $pg = await renderPG(
		$r,
		$effectiveUser,
		$set, $problem,
		$set->psvn,
		$formFields,
		{    # translation options
			displayMode              => $displayMode,
			showHints                => $will->{showHints},
			showSolutions            => $will->{showSolutions},
			refreshMath2img          => $will->{showHints} || $will->{showSolutions},
			processAnswers           => 1,
			permissionLevel          => $db->getPermissionLevel($userName)->permission,
			effectivePermissionLevel => $db->getPermissionLevel($effectiveUserName)->permission,
			useMathQuill             => $self->{will}{useMathQuill},
			useMathView              => $self->{will}{useMathView},
			useWirisEditor           => $self->{will}{useWirisEditor},
			forceScaffoldsOpen       => 0,
			isInstructor             => $authz->hasPermissions($userName, 'view_answers'),
			debuggingOptions         => getTranslatorDebuggingOptions($authz, $userName)
		},
	);

	# Warnings in the renderPG subprocess will not be caught by the global warning handler of this process.
	# So rewarn them and let the global warning handler take care of it.
	warn $pg->{warnings} if $pg->{warnings};

	debug('end pg processing');

	# Update and fix hint/solution options after PG processing
	$can->{showHints}     &&= $pg->{flags}{hintExists};
	$can->{showSolutions} &&= $pg->{flags}{solutionExists};

	# Record errors
	$self->{pgdebug}          = $pg->{debug_messages}          if ref $pg->{debug_messages} eq 'ARRAY';
	$self->{pgwarning}        = $pg->{warning_messages}        if ref $pg->{warning_messages} eq 'ARRAY';
	$self->{pginternalerrors} = $pg->{internal_debug_messages} if ref $pg->{internal_debug_messages} eq 'ARRAY';
	# $self->{pgerrors} is defined if any of the above are defined, and is nonzero if any are non-empty.
	$self->{pgerrors} =
		@{ $self->{pgdebug} // [] } || @{ $self->{pgwarning} // [] } || @{ $self->{pginternalerrors} // [] }
		if defined $self->{pgdebug} || defined $self->{pgwarning} || defined $self->{pginternalerrors};

	# If $self->{pgerrors} is not defined, then the PG messages arrays were not defined,
	# which means $pg->{pgcore} was not defined and the translator died.
	warn 'Processing of this PG problem was not completed.  Probably because of a syntax error. '
		. 'The translator died prematurely and no PG warning messages were transmitted.'
		unless defined $self->{pgerrors};

	$self->{showMeAnother} = \%showMeAnother;
	$self->{pg}            = $pg;

	return;
}

# We disable showOldAnswers because old answers are answers to the original
# question and not to this question.

sub can_showOldAnswers {

	return 0;
}

sub title {
	my ($self) = @_;
	my $r      = $self->r;
	my $db     = $r->db;

	# Using the url arguments won't break if the set/problem are invalid
	my $setID     = $self->r->urlpath->arg('setID');
	my $problemID = $self->r->urlpath->arg('problemID');

	my $set = $db->getGlobalSet($setID);
	if ($set && $set->assignment_type eq 'jitar') {
		$problemID = join('.', jitar_id_to_seq($problemID));
	}
	my $header = $r->maketext('[_1]: Problem [_2] Show Me Another',
		$r->tag('span', dir => 'ltr', format_set_name_display($setID)), $problemID);

	# Return here if we don't have the requisite information.
	return $header if ($self->{invalidSet} || $self->{invalidProblem});

	my $ce      = $r->ce;
	my $problem = $self->{problem};

	my $subheader = '';

	# FIXME: Should the show me another show points?
	my $problemValue = $problem->value;
	if (defined $problemValue) {
		my $points = $problemValue == 1 ? $r->maketext('point') : $r->maketext('points');
		$subheader .= "($problemValue $points)";
	}

	# This uses the permission level and user id of the user assigned to the problem.
	my $problemUser = $problem->user_id;
	if ($db->getPermissionLevel($problemUser)->permission >=
		$ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_PERMISSION_LEVEL}
		|| grep { $_ eq $problemUser } @{ $ce->{pg}{specialPGEnvironmentVars}{PRINT_FILE_NAMES_FOR} })
	{
		$subheader .= ' ' . $problem->source_file;
	}

	return $r->c($header, $r->tag('span', class => 'problem-sub-header d-block', $subheader))->join('');
}

# If showMeAnother or check answers from showMeAnother is active, then don't show the navigation bar.
sub nav {
	return '';
}

# Output the body of the current problem
sub output_problem_body {
	my $self = shift;

	# Ignore body if SMA was pushed and no new problem will be shown.
	return $self->SUPER::output_problem_body if $self->{will}{showMeAnother} && $self->{showMeAnother}{IsPossible};

	return '';
}

# Output messages about the problem
sub output_message {
	my $self = shift;
	return $self->r->include('ContentGenerator/ShowMeAnother/messages');
}

# Prints out the checkbox input elements that are available for the current problem
sub output_checkboxes {
	my $self = shift;

	# Skip check boxes if SMA was pushed and no new problem will be shown
	return $self->SUPER::output_checkboxes if ($self->{showMeAnother}{IsPossible} && $self->{will}{showMeAnother});

	return '';
}

# Prints out the submit button input elements that are available for the current problem
sub output_submit_buttons {
	my $self = shift;

	# Skip buttons if SMA button has been pushed but there is no new problem shown
	return $self->SUPER::output_submit_buttons if ($self->{showMeAnother}{IsPossible} && $self->{will}{showMeAnother});

	return '';
}

# Outputs a summary of the student's current progress and status on the current problem
sub output_score_summary {
	# skip score summary
	return '';
}

# Outputs the summary of the questions that the student has answered
# for the current problem, along with available information about correctness
sub output_summary {
	my $self                      = shift;
	my $pg                        = $self->{pg};
	my %will                      = %{ $self->{will} };
	my %can                       = %{ $self->{can} };
	my %showMeAnother             = %{ $self->{showMeAnother} };
	my $checkAnswers              = $self->{checkAnswers};
	my $previewAnswers            = $self->{previewAnswers};
	my $showPartialCorrectAnswers = $self->{pg}{flags}{showPartialCorrectAnswers};

	my $r  = $self->r;
	my $ce = $r->ce;
	my $db = $r->db;

	# if $showMeAnother{Count} is somehow not an integer, make it one
	$showMeAnother{Count} = 0 unless ($showMeAnother{Count} =~ /^[+-]?\d+$/);

	my $output = $r->c;

	if ($will{checkAnswers}) {
		if ($showMeAnother{CheckAnswers} && $can{showMeAnother}) {
			# if the student is checking answers to a new problem, give them a reminder that they are doing so
			push(
				@$output,
				$r->tag(
					'div',
					class => 'showMeAnotherBox',
					$r->maketext(
						'You are currently checking answers to a different version of your problem - these '
							. 'will not be recorded, and you should remember to return to your original problem '
							. 'once you are done here.'
					)
				)
			);
		}
	} elsif ($previewAnswers) {
		# if the student is previewing answers to a new problem, give them a reminder that they are doing so
		if ($showMeAnother{Preview} && $can{showMeAnother}) {
			push(
				@$output,
				$r->tag(
					'div',
					class => 'showMeAnotherBox',
					$r->maketext(
						'You are currently previewing answers to a different version of your problem - these '
							. 'will not be recorded, and you should remember to return to your original problem '
							. 'once you are done here.'
					)
				)
			);
		}
	} elsif ($showMeAnother{IsPossible} && $will{showMeAnother}) {
		# the feedback varies a little bit if Check Answers is available or not
		my $checkAnswersAvailable =
			($showMeAnother{options}->{checkAnswers})
			? $r->maketext('You may check your answers to this problem without affecting '
				. 'the maximum number of tries to your original problem.')
			: '';
		my $solutionShown = '';
		# if showMeAnother has been clicked and a new version has been found,
		# give some details of what the student is seeing
		if ($showMeAnother{Count} <= $showMeAnother{MaxReps} || ($showMeAnother{MaxReps} == -1)) {
			# check to see if a solution exists for this problem, and vary the feedback accordingly
			if ($pg->{flags}{solutionExists} && $showMeAnother{options}->{showSolutions}) {
				$solutionShown = $r->maketext('There is a written solution available.');
			} elsif ($showMeAnother{options}->{showSolutions}
				and $showMeAnother{options}->{showCorrect}
				and $showMeAnother{options}->{checkAnswers})
			{
				$solutionShown = $r->maketext('There is no written solution available for this problem, '
						. 'but you can still view the correct answers.');
			} elsif ($showMeAnother{options}->{showSolutions}) {
				$solutionShown = $r->maketext('There is no written solution available for this problem.');
			}
		}
		push(
			@$output,
			$r->tag(
				'div',
				class => 'showMeAnotherBox',
				$r->c(
					$r->maketext('Here is a new version of your problem.'), $solutionShown,
					$checkAnswersAvailable
				)->join(' ')
			),
			$r->tag(
				'div',
				class => 'ResultsAlert',
				$r->maketext(q{Remember to return to your original problem when you're finished here!})
			)
		);
	} elsif ($showMeAnother{active} && $showMeAnother{IsPossible} && !$can{showMeAnother}) {
		if ($showMeAnother{Count} >= $showMeAnother{MaxReps}) {
			my $solutionShown =
				($showMeAnother{options}->{showSolutions} && $pg->{flags}{solutionExists})
				? $r->maketext('The solution has been removed.')
				: '';
			push(
				@$output,
				$r->tag(
					'div',
					class => 'ResultsAlert',
					$r->maketext(
						'You are only allowed to click on Show Me Another [quant,_1,time,times] per problem. '
							. '[_2] Close this tab, and return to the original problem.',
						$showMeAnother{MaxReps},
						$solutionShown
					)
				)
			);
		} elsif ($showMeAnother{Count} < $showMeAnother{TriesNeeded}) {
			push(
				@$output,
				$r->tag(
					'div',
					class => 'ResultsAlert',
					$r->maketext(
						'You must attempt this problem [quant,_1,time,times] before Show Me Another is available.',
						$showMeAnother{TriesNeeded}
					)
				)
			);
		}
	} elsif ($can{showMeAnother} && !$showMeAnother{IsPossible}) {
		# print this if showMeAnother has been clicked, but it is not possible to
		# find a new version of the problem
		push(
			@$output,
			$r->tag(
				'div',
				class => 'ResultsAlert',
				$r->maketext(
					'WeBWorK was unable to generate a different version of this problem.  '
						. 'Close this tab, and return to the original problem.'
				)
			)
		);
	}

	if ($showMeAnother{IsPossible} && $will{showMeAnother}) {
		push(@$output, $self->SUPER::output_summary);
	}

	return $output->join('');
}

sub output_comments {
	# skip instructor comments.
	return '';
}

sub output_grader {
	# skip instructor grader.
	return '';
}

# Outputs the hidden fields required for the form
sub output_hidden_info {
	my $self = shift;
	my $r    = $self->r;

	# Hidden field for clicking Preview Answers and Check Answers from a Show Me Another screen.
	# It needs to send the seed from showMeAnother back to the screen.
	if ($self->{showMeAnother}{active} || $self->{showMeAnother}{CheckAnswers} || $self->{showMeAnother}{Preview}) {
		return $r->c(
			$r->hidden_field(showMeAnotherCheckAnswers => 1, id => 'showMeAnotherCheckAnswers_id'),
			# Output the problem seed from ShowMeAnother so that it can be used in Check Answers.
			$r->hidden_field(problemSeed => $self->{problem}->problem_seed)
		)->join('');
	}

	return '';
}

1;
