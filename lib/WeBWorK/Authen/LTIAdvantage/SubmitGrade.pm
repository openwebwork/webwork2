###############################################################################
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

package WeBWorK::Authen::LTIAdvantage::SubmitGrade;

=head1 NAME

WeBWorK::Authen::LTIAdvanced::SubmitGrade - pass back grades to an enabled LMS via LTI 1.3

=cut

use Mojo::Base -signatures, -async_await;

use Carp;
use Net::OAuth;
use HTML::Entities;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::File;
use Mojo::Date;
use Mojo::IOLoop;
use Crypt::JWT qw(encode_jwt);
use Crypt::PK::RSA;
use Math::Random::Secure qw(irand);
use Digest::SHA qw(sha256_hex);
use Time::HiRes;

use WeBWorK::Debug;
use WeBWorK::Utils qw(wwRound);
use WeBWorK::Utils::Sets qw(grade_all_sets);
use WeBWorK::Authen::LTI::GradePassback qw(getSetPassbackScore);

# This package contains utilities for submitting grades to the LMS via LTI 1.3.
sub new ($invocant, $c, $post_processing_mode = 0) {
	return bless { c => $c, post_processing_mode => $post_processing_mode }, ref($invocant) || $invocant;
}

# Use the app log for warnings in post processing mode as perl warnings are not caught in the job queue.  Otherwise just
# use warn as those are caught by the global webwork2 warn handler.  Warnings are only sent if debug_lti_grade_passback
# is set, but these warnings are always sent to the debug log if debugging is enabled.
sub warning ($self, $warning) {
	debug($warning);
	return unless $self->{c}{ce}{debug_lti_grade_passback} || $self->{post_processing_mode};

	if ($self->{post_processing_mode}) {
		$self->{c}{app}->log->info($warning);
	} else {
		warn $warning . "\n";
	}

	return;
}

# This updates the data needed for grade passback for the user and set.  The LMS lineitem for the set is saved in the
# the course settings table for course grade mode or in the lis_source_did column of the global set table for homework
# grade mode.
sub update_passback_data ($self, $userID) {
	my $c  = $self->{c};
	my $ce = $c->{ce};
	my $db = $c->{db};

	# The lti_lms_user_id is what identifies the user to the LMS.
	# It was the 'sub' user claim in the JWT received from the lms.
	# FIXME:  This just uses the old user lis_source_did column for now.
	# It should have its own appropriately named column.
	if ($c->stash->{lti_lms_user_id}) {
		my $user = $db->getUser($userID);
		if (!defined $user->lis_source_did || $user->lis_source_did ne $c->stash->{lti_lms_user_id}) {
			$user->lis_source_did($c->stash->{lti_lms_user_id});
			$db->putUser($user);
		}
	} else {
		$self->warning('Missing LMS user id (sub) in JWT.');
	}

	# The lti_lms_lineitem is the url to post grades to.  It was the 'lineitem' key of the
	# 'https://purl.imsglobal.org/spec/lti-ags/claim/endpoint' object in the JWT received from the LMS.
	if ($ce->{LTIGradeMode} eq 'course') {
		$db->setSettingValue('LTIAdvantageCourseLineitem', $c->stash->{lti_lms_lineitem});
	} elsif ($ce->{LTIGradeMode} eq 'homework') {
		# FIXME:  This uses the global set lis_source_did column.  That column is named such so that a new corresponding
		# column is not needed in the set_user table (even though this is not an lis_source_did).  An appropriately
		# named column is needed.  Also, why is the set_user lis_source_did column of type BLOB?  This lineitem also has
		# much more potential.  You can pass grades back for any student as long as you have the LMS user id above.
		# That user id will be the same for all sets for this user.
		if (defined $c->stash->{setID} && $c->stash->{lti_lms_lineitem}) {
			my $set = $db->getGlobalSet($c->stash->{setID});
			if (defined $set
				&& (!defined $set->lis_source_did || $set->lis_source_did ne $c->stash->{lti_lms_lineitem}))
			{
				$set->lis_source_did($c->stash->{lti_lms_lineitem});
				$db->putGlobalSet($set);
			}
		}
	}

	# Update the access token if neccessary.  No need to wait for it to finish here since the token is not needed yet.
	# This just obtains it if needed for later.
	$self->get_access_token;

	return;
}

# Get an access token.  If there is a current token in the database, then use that.
# Otherwise get a new one from the LMS.
async sub get_access_token ($self) {
	my $c  = $self->{c};
	my $ce = $c->{ce};
	my $db = $c->{db};
	$c = $c->{app} if $self->{post_processing_mode};

	my $current_token = decode_json($db->getSettingValue('LTIAdvantageAccessToken') // '{}');

	# If the token has not expired and is not about to expire, then it can still be used.
	if (%$current_token && $current_token->{timestamp} + $current_token->{expires_in} > time + 60) {
		$self->warning('Using current access token from database.');
		return $current_token;
	}

	# The token is expired or about to, so get a new one.

	my ($private_key, $err) = get_site_key($ce, 1);
	if (!$private_key) {
		$self->warning("Error loading or generating site keys: $err");
		return;
	}

	my $jwt = eval {
		encode_jwt(
			payload => {
				aud => $ce->{LTI}{v1p3}{AccessTokenAUD},
				iss => $ce->{LTI}{v1p3}{ClientID},
				sub => $ce->{LTI}{v1p3}{ClientID},
				jti => $private_key->{kid}
			},
			key           => $private_key,
			extra_headers => { kid => $private_key->{kid} },
			alg           => 'RS256',
			auto_iat      => 1,
			relative_exp  => 3600,
		);
	};
	if ($@) {
		$self->warning("Error encoding JWT: $@");
		return;
	}

	my $request = await Mojo::UserAgent->new->post_p(
		$ce->{LTI}{v1p3}{AccessTokenURL},
		{ 'Content-Type' => 'application/x-www-form-urlencoded' },
		form => {
			grant_type            => 'client_credentials',
			client_assertion_type => 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
			scope                 => join(' ',
				'https://purl.imsglobal.org/spec/lti-ags/scope/lineitem',
				'https://purl.imsglobal.org/spec/lti-ags/scope/lineitem.readonly',
				'https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly',
				'https://purl.imsglobal.org/spec/lti-ags/scope/score'),
			client_assertion => $jwt
		}
	)->catch(sub ($err) {
			$self->warning("Error communicating with LMS key server: $err\n");
			return;
	});

	return unless $request;

	my $response = $request->result;

	if ($response->is_success) {
		# Decode the JSON response so that a timestamp can be added, then reencode it and save it.
		$current_token = decode_json($response->body);
		$current_token->{timestamp} = time;
		$db->setSettingValue('LTIAdvantageAccessToken', encode_json($current_token));
		$self->warning('Successfully obtained new access token from LMS.');
		return $current_token;
	}

	$self->warning(join("\n", 'Failed to obtain access token from LMS:', $response->message));
	return;
}

# Computes and submits the course grade for userID to the LMS.
# The course grade is the sum of all (weighted) problems assigned to the user.
async sub submit_course_grade ($self, $userID, $submittedSet = undef) {
	my $c  = $self->{c};
	my $ce = $c->{ce};
	my $db = $c->{db};

	my $user = $db->getUser($userID);
	return 0 unless $user;

	$self->warning("Preparing to submit overall course grade to LMS for user $userID.");

	my $lineitem = $db->getSettingValue('LTIAdvantageCourseLineitem');
	unless ($lineitem) {
		$self->warning('LMS lineitem is not available for the course.');
		return 0;
	}

	unless ($user->lis_source_did) {
		$self->warning('LMS user id is not available for this user.');
		return 0;
	}

	if ($submittedSet && !getSetPassbackScore($db, $ce, $userID, $submittedSet, 1)) {
		$self->warning("Set's critical date has not yet passed, and user has not yet met the threshold to send set's "
				. 'score early. Not submitting grade.');
		return -1;
	}

	my ($courseTotalRight, $courseTotal, $includedSets) = grade_all_sets($db, $ce, $userID, \&getSetPassbackScore);
	if (@$includedSets) {
		$self->warning("Submitting overall score for user $userID for sets: "
				. join(', ', map { $_->set_id } (@$includedSets)));
		return await $self->submit_grade($user->lis_source_did, $lineitem, $courseTotalRight, $courseTotal);
	} else {
		$self->warning("No sets for user $userID meet criteria to be included in course grade calculation.");
		return -1;
	}
}

# Computes and submits the set grade for $userID and $setID to the LMS.  For gateways the best score is used.
async sub submit_set_grade ($self, $userID, $setID, $submittedSet = undef) {
	my $c  = $self->{c};
	my $ce = $c->{ce};
	my $db = $c->{db};

	my $user = $db->getUser($userID);
	return 0 unless $user;

	$self->warning("Preparing to submit grade to LMS for user $userID and set $setID.");

	unless ($user->lis_source_did) {
		$self->warning('LMS user id is not available for this user.');
		return 0;
	}

	my $userSet = $submittedSet // $db->getMergedSet($userID, $setID);
	unless ($userSet->lis_source_did) {
		$self->warning('LMS lineitem is not available for this set.');
		return 0;
	}

	my $score = getSetPassbackScore($db, $ce, $userID, $userSet, !$self->{post_processing_mode});
	unless ($score) {
		$self->warning("Set's critical date has not yet passed, and user has not yet met the threshold to send set's "
				. 'score early. Not submitting grade.');
		return -1;
	}

	return await $self->submit_grade($user->lis_source_did, $userSet->lis_source_did, $score->{totalRight},
		$score->{total});
}

# Submits scoreGiven and scoreMaximum to the lms with $sourcedid as the identifier.
async sub submit_grade ($self, $LMSuserID, $lineitem, $scoreGiven, $scoreMaximum) {
	my $c  = $self->{c};
	my $ce = $c->{ce};

	return 0 unless (my $access_token = await $self->get_access_token);

	$self->warning('Found data required for submitting grades to LMS.');

	# In post processing mode $c is not a real Mojolicious::Controller.  The app is passed in though.
	# So change $c to be the app instead to get access to the url_for helper.
	$c = $c->{app} if $self->{post_processing_mode};

	my $ua = Mojo::UserAgent->new;

	if ($ce->{LTICheckPrior}) {
		$self->warning('Retrieving prior grade.');

		my $results_url = $c->url_for($lineitem);
		push(@{ $results_url->path }, 'results');

		my $request = await $ua->get_p(
			$results_url->query(user_id => $LMSuserID),
			{
				Authorization => "$access_token->{token_type} $access_token->{access_token}"
			}
		)->catch(sub ($err) {
				$self->warning("There was an error retrieving prior grade from the LMS: $err");
				return 0;
		});

		return 0 unless $request;
		my $response = $request->result;

		if (!$response->is_success) {
			$self->warning(join("\n", 'Failed to retrieve prior grade from LMS:', $response->message));
			return 0;
		}

		my $priorData = decode_json($response->body);
		my $priorScore =
			(@$priorData && $priorData->[0]{resultMaximum} && defined $priorData->[0]{resultScore})
			? $priorData->[0]{resultScore} / $priorData->[0]{resultMaximum}
			: 0;

		my $score = $scoreMaximum ? $scoreGiven / $scoreMaximum : 0;

		# Do not update the score if there is no significant change. Note that the cases where the webwork score
		# is exactly 1 and the LMS score is not exactly 1, and the case where the webwork score is 0 and the LMS
		# score is not set are considered significant changes.
		if (abs($score - $priorScore) < 0.001
			&& ($score != 1 || $priorScore == 1)
			&& ($score != 0 || (@$priorData && defined $priorData->[0]{resultScore})))
		{
			$self->warning('LMS grade will NOT be updated as the grade has not significantly changed. '
					. "Old score: $priorScore, New score: $score.");
			return 1;
		}

		$self->warning("LMS grade will be updated as the grade has changed. Old score: $priorScore, New score: $score");
	}

	my $scores_url = $c->url_for($lineitem);
	push(@{ $scores_url->path }, 'scores');

	my $request = await $ua->post_p(
		$scores_url,
		{
			Authorization  => "$access_token->{token_type} $access_token->{access_token}",
			'Content-Type' => 'application/vnd.ims.lis.v1.score+json'
		},
		json => {
			# This must be in ISO 8601 format with sub-second precision.  That is why the Time::HiRes::time is used.
			timestamp        => Mojo::Date->new(Time::HiRes::time())->to_datetime,
			scoreGiven       => $scoreGiven,
			scoreMaximum     => $scoreMaximum,
			activityProgress => 'Submitted',
			gradingProgress  => 'FullyGraded',
			userId           => $LMSuserID
		}
	)->catch(sub ($err) {
			$self->warning("There was an error sending the grade to the LMS: $err");
			return 0;
	});

	return 0 unless $request;
	my $response = $request->result;

	if ($response->is_success) {
		$self->warning('Successfully updated LMS grade.');
		return 1;
	}

	$self->warning(join("\n", 'Failed to send grade:', $response->message));
	return 0;
}

# Load and possibly generate private/public keys for the site.  This is only generates new keys if the files do not
# already exist.  If $private is true then the JSON decoded private key is returned, otherwise the JSON decoded public
# key is returned as a keyset. If an error occurs in this process then the returned key will be undefined, and the error
# that was thrown will also be returned. Note that this is not a class method and the only required parameter is $ce
# which should be a minimal course environment.  The course environment is only needed to determine the site DATA
# directory.
sub get_site_key ($ce, $private = 0) {
	my $key;

	my $public_key_file  = Mojo::File->new($ce->{webworkDirs}{DATA})->child('lti_public_key.json');
	my $private_key_file = Mojo::File->new($ce->{webworkDirs}{DATA})->child('lti_private_key.json');

	eval {
		if (!-r $public_key_file || !-r $private_key_file) {
			my $pk = Crypt::PK::RSA->new;
			$pk->generate_key(256, 65537);

			my $private_key = decode_json($pk->export_key_jwk('private'));
			$private_key->{kid} = sha256_hex(join('', map { [ 0 .. 9, 'a' .. 'z' ]->[ irand(36) ] } 1 .. 20));
			$private_key->{use} = 'sig';
			$private_key_file->spurt(encode_json($private_key));

			my $public_keyset = {
				keys => [ {
					kid => $private_key->{kid},
					use => 'sig',
					alg => 'RS256',
					%{ decode_json($pk->export_key_jwk('public')) }
				} ]
			};
			$public_key_file->spurt(encode_json($public_keyset));

			$key = $private ? $private_key : $public_keyset;
		} else {
			$key = $private ? decode_json($private_key_file->slurp) : decode_json($public_key_file->slurp);
		}
	};

	return ($key, $@);
}

1;
