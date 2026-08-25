package WeBWorK::ContentGenerator::RenderViaRPC;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator::RenderViaRPC - This is a content generator that
processes requests for problem rendering via remote procedure calls to the
webwork webservice.

=head1 Description

Receives WeBWorK requests presented as HTML forms, containing the requisite
information for rendering a problem.  This package checks that authentication
succeeded, calls renderProblem, and then passes its return value to
FormatRenderedProblem::formatRenderedProblem.  The result is returned in the
JSON or HTML format as determined by the request type.

=cut

use Benchmark;
use Mojo::Util qw(url_unescape);

use WeBWorK::Debug            qw(debug);
use WeBWorK::DB::Utils        qw(global2user fake_set fake_problem);
use WeBWorK::Utils            qw(decode_utf8_base64);
use WeBWorK::Utils::Files     qw(readFile path_is_subdir);
use WeBWorK::Utils::Logs      qw(writeCourseLog);
use WeBWorK::Utils::Rendering qw(renderPG);
use FormatRenderedProblem;
use HardcopyRenderedProblem;

sub initializeRoute ($c, $routeCaptures) {
	$c->{rpc} = 1;
	my $allow_unsecured_rpc = $c->config('allow_unsecured_rpc');
	my $disable_cookies     = 0;

	if ($allow_unsecured_rpc) {
		if (ref($allow_unsecured_rpc) eq 'HASH') {
			my $courseID = $c->param('courseID');
			if ($courseID && $allow_unsecured_rpc->{$courseID}) {
				if (ref($allow_unsecured_rpc->{$courseID}) eq 'HASH') {
					my $userID = $c->param('user');
					if ($userID && $allow_unsecured_rpc->{$courseID}{$userID}) {
						$disable_cookies = 1;
					}
				} else {
					$disable_cookies = 1;
				}
			}
		} else {
			$disable_cookies = 1;
		}
	}

	$c->stash(disable_cookies => 1)
		if $c->current_route eq 'render_rpc' && $c->param('disableCookies') && $disable_cookies;

	# Get the courseID from the parameters.
	$routeCaptures->{courseID} = $c->stash->{courseID} = $c->param('courseID') if $c->param('courseID');

	return;
}

sub renderError ($c, $message) {
	return $c->render(($c->req->param('outputformat') // '') eq 'json'
			|| ($c->req->param('send_pg_flags') // 0) ? (json => { error => $message }) : (text => $message));
}

async sub go ($c) {
	writeCourseLog($c->ce, 'activity_log', $c->prepare_activity_entry)
		if ($c->stash('courseID') && $c->ce->{courseFiles}{logs}{activity_log});

	return $c->renderError($c->maketext('Authentication failed. Log in again to continue.'))
		unless $c->authen->was_verified;

	return $c->renderError($c->maketext('User does not have permission to render problems.'))
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'webservice_render_problem');

	if ($c->req->param('problemSource')
		|| $c->req->param('rawProblemSource')
		|| $c->req->param('uriEncodedProblemSource'))
	{
		# If the problem source is provided, check that the user is allow to render problem source.
		return $c->renderError($c->maketext('User does not have permission to render problem source.'))
			unless $c->authz->hasPermissions($c->authen->{user_id}, 'webservice_render_source');
	} elsif (defined $c->req->param('sourceFilePath') && $c->req->param('sourceFilePath') =~ /\S/) {
		# If the source file path is provided, ensure it is contained in the course's templates directory.
		return $c->renderError($c->maketext('Unable to render the source file path as it is unsafe.'))
			unless path_is_subdir($c->ce->{courseDirs}{templates} . '/' . $c->req->param('sourceFilePath'),
				$c->ce->{courseDirs}{templates});
	}

	my $tx = $c->render_later->tx;

	$c->req->param('displayMode', 'tex')
		if $c->req->param('outputformat')
		&& ($c->req->param('outputformat') eq 'pdf' || $c->req->param('outputformat') eq 'tex');

	my $renderedProblem = await $c->renderProblem;

	if ($c->req->param('outputformat')
		&& ($c->req->param('outputformat') eq 'tex' || $c->req->param('outputformat') eq 'pdf'))
	{
		my $result = HardcopyRenderedProblem::hardcopyRenderedProblem($c, $renderedProblem);
		return if $c->res->code;
		return $c->renderError($result);
	}
	return FormatRenderedProblem::formatRenderedProblem($c, $renderedProblem);
}

our $UNIT_TESTS_ON = 0;

async sub renderProblem ($c) {
	my $rh = $c->req->params->to_hash;

	my $problemSeed = $rh->{problemSeed} // '1234';

	my $beginTime = Benchmark->new;

	my $ce = $c->ce;
	my $db = $c->db;

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
		print STDERR 'setRecord is ',                     $c->dumper($setRecord);
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
			: ($rh->{showMessages} // ($rh->{previewAnswers} || $rh->{WWsubmit} || $rh->{WWcorrectAns}))
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

	my $pg = await renderPG($c, $effectiveUser, $setRecord, $problemRecord, $setRecord->psvn, $rh, $translationOptions);

	# New version of output:
	return {
		text             => $pg->{body_text},
		header_text      => $pg->{head_text},
		post_header_text => $pg->{post_header_text},
		answers          => $pg->{answers},
		errors           => $pg->{errors},
		pg_warnings      => $pg->{warnings},
		PG_ANSWERS_HASH  => $pg->{PG_ANSWERS_HASH},
		PERSISTENCE_HASH => $pg->{PERSISTENCE_HASH},
		problem_result   => $pg->{result},
		problem_state    => $pg->{state},
		flags            => $pg->{flags},
		psvn             => $psvn,
		problem_seed     => $problemSeed,
		resource_list    => $pg->{resource_list},
		warning_messages => ref $pg->{warning_messages} eq 'ARRAY' ? $pg->{warning_messages} : [],
		debug_messages   => ref $pg->{debug_messages} eq 'ARRAY'   ? $pg->{debug_messages}   : [],
		compute_time     => logTimingInfo($beginTime, Benchmark->new),
	};
}

sub logTimingInfo ($beginTime, $endTime) {
	return Benchmark::timestr(Benchmark::timediff($endTime, $beginTime));
}

1;
