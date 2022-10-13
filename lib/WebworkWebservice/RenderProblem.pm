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

package WebworkWebservice::RenderProblem;

use strict;
use warnings;

use Future::AsyncAwait;
use Benchmark;

use WeBWorK::Debug;
use WeBWorK::CourseEnvironment;
use WeBWorK::PG;
use WeBWorK::DB;
use WeBWorK::Constants;
use WeBWorK::Utils qw(decode_utf8_base64);
use WeBWorK::Utils::Rendering qw(renderPG);
use WeBWorK::DB::Utils qw(global2user);
use WeBWorK::Utils::Tasks qw(fake_set fake_problem);

our $UNIT_TESTS_ON = 0;

async sub renderProblem {
	my ($invocant, $self, $rh) = @_;

	# Sanity check
	my $user        = $self->{user_id};
	my $courseName  = $self->{courseName};
	my $displayMode = $rh->{envir}{displayMode};
	my $problemSeed = $rh->{envir}{problemSeed};
	debug(pretty_print_rh($rh));

	unless ($user && $user =~ /\S/ && $courseName && $displayMode && defined($problemSeed)) {
		die "Missing essential data entering WebworkWebservice::RenderProblem::renderProblem:\n";
	}

	my $beginTime = Benchmark->new;

	# Grab the course name, if this request is going to depend on some course other than the default course
	my $ce;
	my $db;

	eval {
		$ce = WeBWorK::CourseEnvironment->new(
			{ webwork_dir => $WeBWorK::Constants::WEBWORK_DIRECTORY, courseName => $courseName });
		# Create database object for this course
		$db = WeBWorK::DB->new($ce->{dbLayout});
	};

	die "Unable to create course environment for $courseName. Error: $@\n" if $@;

	# Authentication of this request and permission level determination is done by initiate_session in
	# WebworkWebservice.

	# Determine an effective user for this interaction or create one if it is not given.
	# Use effectiveUser if given, and user otherwise.  Note that $user will always work.
	my $effectiveUserName;
	if (defined $rh->{effectiveUser} && $rh->{effectiveUser} =~ /\S/) {
		$effectiveUserName = $rh->{effectiveUser};
	} else {
		$effectiveUserName = $user;
	}

	if ($UNIT_TESTS_ON) {
		print STDERR "RenderProblem.pm:  user = $user\n";
		print STDERR "RenderProblem.pm:  courseName = $courseName\n";
		print STDERR "RenderProblem.pm:  effectiveUserName = $effectiveUserName\n";
		print STDERR 'environment fileName', $rh->{envir}{fileName}, "\n";
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
		$effectiveUser->last_name($rh->{envir}{studentName} || 'foobar');
		$effectiveUser->first_name('');
		$effectiveUser->student_id($rh->{envir}{studentID}  || 'foobar');
		$effectiveUser->email_address($rh->{envir}{email}   || '');
		$effectiveUser->section($rh->{envir}{section}       || '');
		$effectiveUser->recitation($rh->{envir}{recitation} || '');
		$effectiveUser->comment('');
		$effectiveUser->status('C');
		$effectiveUserPermissionLevel->permission(0);
	}

	# Insure that set and problem are defined.  Define the set and problem information from data in the environment if
	# necessary.
	my $setName = $rh->{set_id} // $rh->{envir}{setNumber} // '';

	my $setVersionId = $rh->{version_id} || 0;

	my $problemNumber    = $rh->{envir}{probNum} // 1;
	my $psvn             = $rh->{envir}{psvn}    // 1234;
	my $problemStatus    = $rh->{problem_state}{recorded_score} || 0;
	my $problemValue     = $rh->{envir}{problemValue} // 1;
	my $num_correct      = $rh->{problem_state}{num_correct}   || 0;
	my $num_incorrect    = $rh->{problem_state}{num_incorrect} || 0;
	my $problemAttempted = $num_correct                        || $num_incorrect;
	my $lastAnswer       = '';

	debug('effectiveUserName: ' . $effectiveUserName);
	debug('setName: ' . $setName);
	debug('setVersionId: ' . $setVersionId);
	debug('problemNumber: ' . $problemNumber);
	debug('problemSeed:' . $problemSeed);
	debug('psvn: ' . $psvn);
	debug('problemStatus:' . $problemStatus);
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
		$setRecord->psvn($rh->{envir}{psvn} || 0);
	}

	# obtain the merged problem for $effectiveUser
	my $problemRecord =
		$setVersionId
		? $db->getMergedProblemVersion($effectiveUserName, $setName, $setVersionId, $problemNumber)
		: $db->getMergedProblem($effectiveUserName, $setName, $problemNumber);

	if (defined $problemRecord) {
		# If a problem from the database is used, the passed in problem seed is ignored.
		# So save the actual seed used and pass that on to the renderer.
		$problemSeed = $problemRecord->problem_seed;
	} else {
		# If that is not yet defined obtain the global problem,
		# convert it to a user problem, and add fake user data
		my $userProblemClass = $db->{problem_user}{record};
		my $globalProblem    = $db->getGlobalProblem($setName, $problemNumber);    # checked
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
		$problemRecord->status($problemStatus);
		$problemRecord->value($problemValue);
		# We are faking it
		$problemRecord->attempted(2000);
		$problemRecord->num_correct(1000);
		$problemRecord->num_incorrect(1000);
		$problemRecord->last_answer($lastAnswer);
	}

	# initialize problem source
	$rh->{sourceFilePath} = $rh->{path} unless defined $rh->{sourceFilePath};

	if ($UNIT_TESTS_ON) {
		print STDERR 'setRecord is ',                     pretty_print_rh($setRecord);
		print STDERR 'template directory path ',          $ce->{courseDirs}{templates}, "\n";
		print STDERR 'RenderProblem.pm: source file is ', $rh->{sourceFilePath},        "\n";
		print STDERR "RenderProblem.pm: problem source is included in the request \n"
			if defined($rh->{source}) && $rh->{source};
	}

	my $r_problem_source;
	if ($rh->{source}) {
		my $problem_source = decode_utf8_base64($rh->{source}) =~ tr/\r/\n/r;
		$r_problem_source = \$problem_source;
		if (defined $rh->{envir}{fileName}) {
			$problemRecord->source_file($rh->{envir}{fileName});
		} else {
			$problemRecord->source_file($rh->{sourceFilePath});
		}
	} elsif (defined $rh->{sourceFilePath} && $rh->{sourceFilePath} =~ /\S/) {
		$problemRecord->source_file($rh->{sourceFilePath});
		warn 'reading source from ', $rh->{sourceFilePath} if $UNIT_TESTS_ON;
		$r_problem_source =
			\(WeBWorK::PG::IO::read_whole_file($ce->{courseDirs}{templates} . '/' . $rh->{sourceFilePath}));
		$problemRecord->source_file('RenderProblemFooBar') unless defined($problemRecord->source_file);
	}
	if ($UNIT_TESTS_ON) {
		print STDERR 'template directory path ',          $ce->{courseDirs}{templates}, "\n";
		print STDERR 'RenderProblem.pm: source file is ', $problemRecord->source_file,  "\n";
		print STDERR "RenderProblem.pm: problem source is included in the request \n" if defined($rh->{source});
	}
	# now we're sure we have valid UserSet and UserProblem objects

	# Other initializations
	my $translationOptions = {
		displayMode              => $rh->{envir}{displayMode} // 'MathJax',
		showHints                => $rh->{envir}{showHints},
		showSolutions            => $rh->{envir}{showSolutions},
		refreshMath2img          => $rh->{envir}{showHints} || $rh->{envir}{showSolutions},
		processAnswers           => $rh->{processAnswers} // 1,
		catchWarnings            => 1,
		r_source                 => $r_problem_source,
		problemUUID              => $rh->{envir}{inputs_ref}{problemUUID} // 0,
		permissionLevel          => $rh->{envir}{permissionLevel} || 0,
		effectivePermissionLevel => $rh->{envir}{effectivePermissionLevel} || $rh->{envir}{permissionLevel} || 0,
		useMathQuill             => $ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathQuill',
		useMathView              => $ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'MathView',
		useWiris                 => $ce->{pg}{specialPGEnvironmentVars}{entryAssist} eq 'WIRIS',
		isInstructor             => $rh->{envir}{isInstructor}       // 0,
		forceScaffoldsOpen       => $rh->{envir}{forceScaffoldsOpen} // 0,
		debuggingOptions         => $rh->{envir}{debuggingOptions}   // {}
	};

	my $formFields = $rh->{envir}{inputs_ref};

	$ce->{pg}{specialPGEnvironmentVars}{problemPreamble}  = { TeX => '', HTML => '' } if ($rh->{noprepostambles});
	$ce->{pg}{specialPGEnvironmentVars}{problemPostamble} = { TeX => '', HTML => '' } if ($rh->{noprepostambles});

	my $pg = await renderPG($ce, $effectiveUser, $setRecord, $problemRecord, $setRecord->psvn, $formFields,
		$translationOptions);

	$self->{formFields} = $formFields;

	my ($internal_debug_messages, $pgwarning_messages, $pgdebug_messages);
	if (ref $pg->{debug_messages} eq 'ARRAY'
		|| ref $pg->{warning_messages} eq 'ARRAY'
		|| ref $pg->{internal_debug_messages} eq 'ARRAY')
	{
		$internal_debug_messages = $pg->{internal_debug_messages} // [];
		$pgwarning_messages      = $pg->{warning_messages}        // [];
		$pgdebug_messages        = $pg->{debug_messages}          // [];
	} else {
		$internal_debug_messages = ['Error in obtaining debug messages from PGcore'];
	}

	# new version of output:
	my $out2 = {
		text                    => $pg->{body_text},
		header_text             => $pg->{head_text},
		post_header_text        => $pg->{post_header_text},
		answers                 => $pg->{answers},
		errors                  => $pg->{errors},
		pg_warnings             => $pg->{warnings},
		PG_ANSWERS_HASH         => $pg->{PG_ANSWERS_HASH},
		problem_result          => $pg->{result},
		problem_state           => $pg->{state},
		flags                   => $pg->{flags},
		psvn                    => $psvn,
		problem_seed            => $problemSeed,
		warning_messages        => $pgwarning_messages,
		debug_messages          => $pgdebug_messages,
		internal_debug_messages => $internal_debug_messages,
	};

	$out2->{compute_time} = logTimingInfo($beginTime, Benchmark->new);

	return $out2;
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

	if (defined($type) and $type) {
		$out .= " type = $type; ";
	} elsif (not defined($rh)) {
		$out .= ' type = scalar; ';
	}
	if (ref($rh) =~ /HASH/ or "$rh" =~ /HASH/) {
		$out .= "{\n";
		$indent++;
		foreach my $key (sort keys %{$rh}) {
			$out .= '  ' x $indent . "$key => " . pretty_print_rh($rh->{$key}, $indent) . "\n";
		}
		$indent--;
		$out .= "\n" . '  ' x $indent . "}\n";

	} elsif (ref($rh) =~ /ARRAY/ or "$rh" =~ /ARRAY/) {
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
