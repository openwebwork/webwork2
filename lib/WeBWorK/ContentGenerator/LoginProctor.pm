package WeBWorK::ContentGenerator::LoginProctor;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator::LoginProctor - display a login form for
GatewayQuiz proctored tests.

=cut

use WeBWorK::Utils::Rendering qw(renderPG);
use WeBWorK::DB::Utils        qw(grok_vsetID);

async sub initialize ($c) {
	my $ce = $c->ce;
	my $db = $c->db;

	my $userID          = $c->param('user');
	my $effectiveUserID = $c->param('effectiveUser') || '';

	$c->{effectiveUser} = $c->db->getUser($effectiveUserID);

	# The user set is needed to check for a set-restricted login proctor, and to show and possibly save the submission
	# time.  To get the user set, the set name and version number are needed.  Attempt to obtain those from the url path
	# setID.  Otherwise, use the highest version number.
	($c->stash->{setID}, my $versionNum) = grok_vsetID($c->stash('setID'));
	my $noSetVersions = 0;
	if (!$versionNum) {
		# Get a list of all available versions.
		my @setVersions = $db->listSetVersions($effectiveUserID, $c->stash->{setID});
		if (@setVersions) {
			$versionNum = $setVersions[-1];
		} else {
			# If there are no versions yet, start with the first one.
			$versionNum    = 1;
			$noSetVersions = 1;
		}
	}

	# Get the merged set. If a test is being graded or this is a new version, get the merged template set instead.
	$c->stash->{userSet} =
		$noSetVersions || !$c->param('submitAnswers')
		? $db->getMergedSet($effectiveUserID, $c->stash->{setID})
		: $db->getMergedSetVersion($effectiveUserID, $c->stash->{setID}, $versionNum);

	if (defined $c->stash->{userSet}) {
		# If the set is being submitted, then save the submission time.
		if ($c->param('submitAnswers')) {
			# This should never happen.
			die 'Request to grade a set version before any tests have been taken.' if $noSetVersions;

			# Determine if answers can be recorded, and set last_attempt_time if appropriate.
			if (WeBWorK::ContentGenerator::GatewayQuiz::can_recordAnswers(
				$c,
				$db->getUser($userID),
				$db->getPermissionLevel($userID),
				$c->{effectiveUser},
				$c->stash->{userSet},
				$db->getMergedProblemVersion(
					$effectiveUserID, $c->stash->{setID},
					$versionNum, ($db->listProblemVersions($effectiveUserID, $c->stash->{setID}, $versionNum))[0]
				)
			))
			{
				$c->stash->{userSet}->version_last_attempt_time(int($c->submitTime));
				# FIXME: This saves all of the merged set data into the set_user table.  We live with this in other
				# places for versioned sets, but it's not ideal.
				$db->putSetVersion($c->stash->{userSet});
			}
		}
	}

	# Get problem set info.
	my $set = $c->authz->{merged_set};
	return unless $set;

	# Hack to prevent errors from uninitialized set_headers.
	$set->set_header('defaultHeader') unless $set->set_header =~ /\S/;

	$c->{pg} = await renderPG(
		$c,
		$c->{effectiveUser},
		$set,
		WeBWorK::DB::Record::UserProblem->new(
			problem_id  => 0,
			set_id      => $set->set_id,
			login_id    => $c->{effectiveUser}->user_id,
			source_file => $set->set_header eq 'defaultHeader'
			? $ce->{webworkFiles}{screenSnippets}{setHeader}
			: $set->set_header
		),
		$set->psvn,
		{},
		{ displayMode => $c->param('displayMode') || $ce->{pg}{options}{displayMode} }
	);

	return;
}

sub info ($c) {
	return '' unless $c->{pg};
	return $c->c($c->tag('h2', $c->maketext('Set Info')), $c->{pg}{body_text})->join('');
}

1;
