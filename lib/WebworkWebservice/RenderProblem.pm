package WebworkWebservice::RenderProblem;

use strict;
use warnings;

use Future::AsyncAwait;
use Benchmark;
use Mojo::Util qw(url_unescape);

use WeBWorK::Debug;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::DB::Utils        qw(global2user fake_set fake_problem);
use WeBWorK::Utils            qw(decode_utf8_base64);
use WeBWorK::Utils::Files     qw(readFile);
use WeBWorK::Utils::Rendering qw(renderPG);

our $UNIT_TESTS_ON = 0;

async sub renderProblem {
	my ($invocant, $ws) = @_;

	my $rh = $ws->{inputs_ref};

	# $WeBWorK::Debug::Enabled needs to be checked, otherwise pretty_print_rh($rh) is called regardless of if debgging
	# is enabled.  That is an expensive method to always call here.
	debug(pretty_print_rh($rh)) if $WeBWorK::Debug::Enabled;

	my $problemSeed = $rh->{problemSeed} // '1234';

	my $beginTime = Benchmark->new;

	my $ce = $ws->ce;
	my $db = $ws->db;

	# Determine an effective user for this interaction or create one if it is not given.
	# Use effectiveUser if given, and $rh->{user} otherwise.
	my $effectiveUserName;
	if (defined $rh->{effectiveUser} && $rh->{effectiveUser} =~ /\S/) {
		$effectiveUserName = $rh->{effectiveUser};
	} else {
		$effectiveUserName = $rh->{user};
	}

	if ($UNIT_TESTS_ON) {
		print STDERR "RenderProblem.pm:  user = $rh->{user}\n";
		print STDERR "RenderProblem.pm:  courseName = $rh->{courseID}\n";
		print STDERR "RenderProblem.pm:  effectiveUserName = $effectiveUserName\n";
		print STDERR 'environment fileName', $rh->{fileName}, "\n";
	}

	# The effectiveUser is the student this problem version was written for
	# The user might also be the effective user but it could be
	# an instructor checking out how well the problem is working.

	my $effectiveUser = $db->getUser($effectiveUserName);
	my $effectiveUserPermissionLevel;
	my $effectiveUserPassword;
	unless (defined $effectiveUser) {
		$effectiveUser                = $db->newUser;
		$effectiveUserPermissionLevel = $db->newPermissionLevel;
		$effectiveUserPassword        = $db->newPassword;
		$effectiveUser->user_id($effectiveUserName);
		$effectiveUserPermissionLevel->user_id($effectiveUserName);
		$effectiveUserPassword->user_id($effectiveUserName);
		$effectiveUserPassword->password('');
		$effectiveUser->last_name($rh->{studentName} || 'foobar');
		$effectiveUser->first_name('');
		$effectiveUser->student_id($rh->{studentID}  || 'foobar');
		$effectiveUser->email_address($rh->{email}   || '');
		$effectiveUser->section($rh->{section}       || '');
		$effectiveUser->recitation($rh->{recitation} || '');
		$effectiveUser->comment('');
		$effectiveUser->status('C');
		$effectiveUserPermissionLevel->permission(0);
	}

	# Insure that set and problem are defined.  Define the set and problem information from data in the environment if
	# necessary.
	my $setName = $rh->{set_id} // $rh->{setNumber} // '';

	my $setVersionId = $rh->{version_id} || 0;

	my $problemNumber = $rh->{probNum}      // 0;
	my $psvn          = $rh->{psvn}         // 1234;
	my $problemValue  = $rh->{problemValue} // 1;
	my $lastAnswer    = '';

	debug('effectiveUserName: ' . $effectiveUserName);
	debug('setName: ' . $setName);
	debug('setVersionId: ' . $setVersionId);
	debug('problemNumber: ' . $problemNumber);
	debug('problemSeed:' . $problemSeed);
	debug('psvn: ' . $psvn);
	debug('problemValue: ' . $problemValue);

	my $setRecord =
		$setVersionId
		? $db->getMergedSetVersion($effectiveUserName, $setName, $setVersionId)
		: $db->getMergedSet($effectiveUserName, $setName);

	if (defined $setRecord && ref $setRecord) {
		# If an actual set from the database is used, the passed in psvn is ignored.
		# So save the actual psvn used and pass that on to the renderer.
		$psvn = $setRecord->psvn;
	} else {
		# if a User Set does not exist for this user and this set
		# then we check the Global Set
		# if that does not exist we create a fake set
		# if it does, we add fake user data
		my $userSetClass = $db->{set_user}{record};
		my $globalSet    = $db->getGlobalSet($setName);

		if (!defined $globalSet) {
			$setRecord = fake_set($db);
		} else {
			$setRecord = global2user($userSetClass, $globalSet);
		}

		# Initializations
		$setRecord->set_id($setName);
		$setRecord->set_header('');
		$setRecord->hardcopy_header('defaultHeader');
		$setRecord->open_date(time - 60 * 60 * 24 * 7);          #  one week ago
		$setRecord->due_date(time + 60 * 60 * 24 * 7 * 2);       # in two weeks
		$setRecord->answer_date(time + 60 * 60 * 24 * 7 * 3);    # in three weeks
		$setRecord->psvn($rh->{psvn} // 1234);
	}

	# obtain the merged problem for $effectiveUser
	my $problemRecord =
		!$problemNumber ? undef
		: $setVersionId ? $db->getMergedProblemVersion($effectiveUserName, $setName, $setVersionId, $problemNumber)
		:                 $db->getMergedProblem($effectiveUserName, $setName, $problemNumber);

	if (defined $problemRecord) {
		# If a problem from the database is used, the passed in problem seed is ignored.
		# So save the actual seed used and pass that on to the renderer.
		$problemSeed = $problemRecord->problem_seed;
	} else {
		# If that is not yet defined obtain the global problem,
		# convert it to a user problem, and add fake user data
		my $userProblemClass = $db->{problem_user}{record};
		my $globalProblem    = $db->getGlobalProblem($setName, $problemNumber);
		# if the global problem doesn't exist either, bail!
		if (not defined $globalProblem) {
			$problemRecord = fake_problem($db);
		} else {
			$problemRecord = global2user($userProblemClass, $globalProblem);
		}
		# initializations
		$problemRecord->user_id($effectiveUserName);
		$problemRecord->problem_id($problemNumber);
		$problemRecord->set_id($setName);
		$problemRecord->problem_seed($problemSeed);
		$problemRecord->status(0);
		$problemRecord->value($problemValue);
		# We are faking it
		$problemRecord->attempted(2000);
		$problemRecord->num_correct(1000);
		$problemRecord->num_incorrect(1000);
		$problemRecord->last_answer($lastAnswer);
	}

	if ($UNIT_TESTS_ON) {
		print STDERR 'setRecord is ',                     pretty_print_rh($setRecord);
		print STDERR 'template directory path ',          $ce->{courseDirs}{templates}, "\n";
		print STDERR 'RenderProblem.pm: source file is ', $rh->{sourceFilePath},        "\n";
		print STDERR "RenderProblem.pm: problem source is included in the request \n"
			if defined($rh->{problemSource}) && $rh->{problemSource};
	}

	# Initialize problem source
	my $r_problem_source;
	if ($rh->{problemSource}) {
		$r_problem_source = \(decode_utf8_base64($rh->{problemSource}) =~ tr/\r/\n/r);
		$problemRecord->source_file($rh->{fileName} ? $rh->{fileName} : $rh->{sourceFilePath});
	} elsif ($rh->{rawProblemSource}) {
		$r_problem_source = \$rh->{rawProblemSource};
		$problemRecord->source_file($rh->{fileName} ? $rh->{fileName} : $rh->{sourceFilePath});
	} elsif ($rh->{uriEncodedProblemSource}) {
		$r_problem_source = \(url_unescape($rh->{uriEncodedProblemSource}));
		$problemRecord->source_file($rh->{fileName} ? $rh->{fileName} : $rh->{sourceFilePath});
	} elsif (defined $rh->{sourceFilePath} && $rh->{sourceFilePath} =~ /\S/) {
		$problemRecord->source_file($rh->{sourceFilePath});
		$r_problem_source = \(readFile($ce->{courseDirs}{templates} . '/' . $rh->{sourceFilePath}));
	}

	if ($UNIT_TESTS_ON) {
		print STDERR 'template directory path ',          $ce->{courseDirs}{templates}, "\n";
		print STDERR 'RenderProblem.pm: source file is ', $problemRecord->source_file,  "\n";
		print STDERR "RenderProblem.pm: problem source is included in the request \n" if defined($rh->{problemSource});
	}
	# now we're sure we have valid UserSet and UserProblem objects

	# Other initializations
	my $translationOptions = {
		displayMode              => $rh->{displayMode} // 'MathJax',
		showHints                => $rh->{showHints},
		showSolutions            => $rh->{showSolutions},
		refreshMath2img          => $rh->{showHints} || $rh->{showSolutions},
		processAnswers           => $rh->{processAnswers} // 1,
		catchWarnings            => 1,
		r_source                 => $r_problem_source,
		problemUUID              => $rh->{problemUUID} // 0,
		permissionLevel          => $rh->{permissionLevel} || 0,
		effectivePermissionLevel => $rh->{effectivePermissionLevel} || $rh->{permissionLevel} || 0,
		useMathQuill             => $ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathQuill',
		useMathView              => $ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathView',
		isInstructor             => $rh->{isInstructor} // 0,
		forceScaffoldsOpen       => $rh->{WWcorrectAnsOnly} ? 1 : ($rh->{forceScaffoldsOpen} // 0),
		QUIZ_PREFIX              => $rh->{answerPrefix},
		showFeedback             => $rh->{previewAnswers} || $rh->{WWsubmit} || $rh->{WWcorrectAns},
		showAttemptAnswers       => $rh->{WWcorrectAnsOnly} ? 0
		: ($rh->{showAttemptAnswers} // $ce->{pg}{options}{showEvaluatedAnswers}),
		showAttemptPreviews => (
			$rh->{WWcorrectAnsOnly} ? 0
			: ($rh->{showAttemptPreviews} // ($rh->{previewAnswers} || $rh->{WWsubmit} || $rh->{WWcorrectAns}))
		),
		showAttemptResults      => $rh->{showAttemptResults} // ($rh->{WWsubmit} || $rh->{WWcorrectAns}),
		forceShowAttemptResults => (
			$rh->{WWcorrectAnsOnly} ? 1
			: (
				$rh->{forceShowAttemptResults}
					|| ($rh->{isInstructor}
						&& ($rh->{showAttemptResults} // ($rh->{WWsubmit} || $rh->{WWcorrectAns})))
			)
		),
		showMessages => (
			$rh->{WWcorrectAnsOnly} ? 0
			: ($rh->{showMessages} // ($rh->{previewAsnwers} || $rh->{WWsubmit} || $rh->{WWcorrectAns}))
		),
		showCorrectAnswers =>
			($rh->{WWcorrectAnsOnly} ? 1 : ($rh->{showCorrectAnswers} // ($rh->{WWcorrectAns} ? 2 : 0))),
		debuggingOptions => {
			show_resource_info          => $rh->{show_resource_info}          // 0,
			view_problem_debugging_info => $rh->{view_problem_debugging_info} // 0,
			show_pg_info                => $rh->{show_pg_info}                // 0,
			show_answer_hash_info       => $rh->{show_answer_hash_info}       // 0,
			show_answer_group_info      => $rh->{show_answer_group_info}      // 0
		},
		defined $rh->{problem_data} && $rh->{problem_data} ne '' ? (problemData => $rh->{problem_data}) : ()
	};

	$ce->{pg}{specialPGEnvironmentVars}{problemPreamble}  = { TeX => '', HTML => '' } if $rh->{noprepostambles};
	$ce->{pg}{specialPGEnvironmentVars}{problemPostamble} = { TeX => '', HTML => '' } if $rh->{noprepostambles};

	my $pg =
		await renderPG($ws->c, $effectiveUser, $setRecord, $problemRecord, $setRecord->psvn, $rh, $translationOptions);

	# New version of output:
	return {
		text                    => $pg->{body_text},
		header_text             => $pg->{head_text},
		post_header_text        => $pg->{post_header_text},
		answers                 => $pg->{answers},
		errors                  => $pg->{errors},
		pg_warnings             => $pg->{warnings},
		PG_ANSWERS_HASH         => $pg->{PG_ANSWERS_HASH},
		PERSISTENCE_HASH        => $pg->{PERSISTENCE_HASH},
		problem_result          => $pg->{result},
		problem_state           => $pg->{state},
		flags                   => $pg->{flags},
		psvn                    => $psvn,
		problem_seed            => $problemSeed,
		resource_list           => $pg->{resource_list},
		warning_messages        => ref $pg->{warning_messages} eq 'ARRAY'  ? $pg->{warning_messages}  : [],
		debug_messages          => ref $pg->{debug_messages} eq 'ARRAY'    ? $pg->{debug_messages}    : [],
		deprecated_macros       => ref $pg->{deprecated_macros} eq 'ARRAY' ? $pg->{deprecated_macros} : [],
		internal_debug_messages => ref $pg->{internal_debug_messages} eq 'ARRAY'
		? $pg->{internal_debug_messages}
		: [],
		compute_time => logTimingInfo($beginTime, Benchmark->new),
	};
}

sub logTimingInfo {
	my ($beginTime, $endTime) = @_;
	return Benchmark::timestr(Benchmark::timediff($endTime, $beginTime));
}

sub pretty_print_rh {
	shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
	my $rh = shift;
	return '' unless defined $rh;
	my $indent = shift || 0;

	my $out = '';
	return $out if $indent > 10;
	my $type = ref($rh);

	if (defined($type) && $type) {
		$out .= " type = $type; ";
	} elsif (not defined($rh)) {
		$out .= ' type = scalar; ';
	}
	if (ref $rh eq 'HASH' || eval { %$rh && 1 }) {
		$out .= "{\n";
		$indent++;
		foreach my $key (sort keys %{$rh}) {
			$out .= '  ' x $indent . "$key => " . pretty_print_rh($rh->{$key}, $indent) . "\n";
		}
		$indent--;
		$out .= "\n" . '  ' x $indent . "}\n";

	} elsif (ref($rh) =~ /ARRAY/ || "$rh" =~ /ARRAY/) {
		$out .= ' ( ';
		foreach my $elem (@{$rh}) {
			$out .= pretty_print_rh($elem, $indent);

		}
		$out .= " ) \n";
	} elsif (ref($rh) =~ /SCALAR/) {
		$out .= 'scalar reference ' . ${$rh};
	} elsif (ref($rh) =~ /Base64/) {
		$out .= 'base64 reference ' . $$rh;
	} else {
		$out .= $rh;
	}

	return $out . ' ';
}

1;
