package WeBWorK::ContentGenerator::LTIAdvantage;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures, -async_await;

use Mojo::UserAgent;
use Mojo::JSON           qw(decode_json);
use Crypt::JWT           qw(decode_jwt encode_jwt);
use Math::Random::Secure qw(irand);
use Digest::SHA          qw(sha256_hex);
use Mojo::File           qw(tempfile);

use WeBWorK::Debug qw(debug);
use WeBWorK::Authen::LTIAdvantage::SubmitGrade;
use WeBWorK::Utils::CourseManagement qw(listCourses);
use WeBWorK::Utils::Sets             qw(format_set_name_display);

sub initializeRoute ($c, $routeCaptures) {
	# If this is the login phase of an LTI 1.3 login, then extract the courseID from the target_link_uri.  If this is a
	# deep linking request, then attempt to find a course with the correct LTI 1.3 configuration as specified in the
	# request.
	if ($c->current_route eq 'ltiadvantage_login') {
		my $target   = $c->param('target_link_uri') ? $c->url_for($c->param('target_link_uri'))->path : '';
		my $location = $c->location;

		if ($target eq "$location/ltiadvantage/content_selection") {
			# Find the first course that has the matching LTI 1.3 configuration.  All courses with the matching LTI 1.3
			# configuration must be using the same external tool of the same LMS.  Note that this may be the incorrect
			# course for the actual request, but the correct course will be determined later in the launch request after
			# the JWT is decoded.
			for (listCourses(WeBWorK::CourseEnvironment->new)) {
				my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $_ }) };
				if ($@) { $c->log->error("Failed to initialize course environment for $_: $@"); next; }
				# Moodle uses lti_deployment_id for the parameter name. Canvas uses deployment_id. The LTI 1.3
				# specification says that Moodle is correct.
				if (
					($ce->{LTIVersion} // '') eq 'v1p3'
					&& $ce->{LTI}{v1p3}{PlatformID} eq $c->param('iss')
					&& $ce->{LTI}{v1p3}{ClientID} eq $c->param('client_id')
					&& ($ce->{LTI}{v1p3}{DeploymentID} eq
						($c->param('lti_deployment_id') // $c->param('deployment_id')))
					)
				{
					$c->stash->{courseID} = $_;
					last;
				}
			}
		} else {
			$c->stash->{courseID} = $1 if $target =~ m|$location/([^/]*)|;
		}

		$routeCaptures->{courseID} = $c->stash->{courseID} if $c->stash->{courseID};
	}

	# If this is the launch phase of an LTI 1.3 login, then extract the claims from the JWT and stash them.
	# The state will be verified now, but the other claims will be verified during authentication later.
	if ($c->current_route eq 'ltiadvantage_launch') {
		$c->stash->{lti_jwt_claims} = $c->extract_jwt_claims;
		if ($c->stash->{lti_jwt_claims}) {
			if ($c->stash->{lti_jwt_claims}{'https://purl.imsglobal.org/spec/lti/claim/message_type'} eq
				'LtiDeepLinkingRequest')
			{
				$c->stash->{isContentSelection} = 1;

				# The database object used here is not associated to any course,
				# and so the only has access to non-native tables.
				my @matchingCourses = WeBWorK::DB->new(WeBWorK::CourseEnvironment->new)->getLTICourseMapsWhere({
					lms_context_id =>
						$c->stash->{lti_jwt_claims}{'https://purl.imsglobal.org/spec/lti/claim/context'}{id}
				});

				if (@matchingCourses == 1) {
					$c->stash->{courseID} = $matchingCourses[0]->course_id;
				} else {
					for (@matchingCourses) {
						my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $_->course_id }) };
						if ($@) { warn "Failed to initialize course environment for $_: $@\n"; next; }
						if (($ce->{LTIVersion} // '') eq 'v1p3'
							&& $ce->{LTI}{v1p3}{PlatformID}
							&& $ce->{LTI}{v1p3}{PlatformID} eq $c->stash->{LTILaunchData}->data->{PlatformID}
							&& $ce->{LTI}{v1p3}{ClientID}
							&& $ce->{LTI}{v1p3}{ClientID} eq $c->stash->{LTILaunchData}->data->{ClientID}
							&& $ce->{LTI}{v1p3}{DeploymentID}
							&& $ce->{LTI}{v1p3}{DeploymentID} eq $c->stash->{LTILaunchData}->data->{DeploymentID})
						{
							$c->stash->{courseID} = $_->course_id;
							last;
						}
					}
				}
			} else {
				$c->stash->{courseID} = $c->stash->{LTILaunchData}->data->{courseID}
					if $c->stash->{LTILaunchData} && $c->stash->{LTILaunchData}->data->{courseID};
			}
		}
		$routeCaptures->{courseID} = $c->stash->{courseID} if $c->stash->{courseID};
	}

	if ($c->param('courseID') && $c->current_route eq 'ltiadvantage_content_selection') {
		$routeCaptures->{courseID} = $c->stash->{courseID} = $c->param('courseID');
		$c->stash->{isContentSelection} = 1;
	}

	return;
}

sub login ($c) {
	# Create a state and nonce and save them.  These are generated
	# so that they are cryptographically secure values.
	my $LTIState = sha256_hex(join('_',
		$c->param('login_hint'), $c->param('lti_message_hint'),
		join('', map { [ 0 .. 9, 'a' .. 'z' ]->[ irand(36) ] } 1 .. 20)));
	my $LTINonce = sha256_hex(join('', map { [ 0 .. 9, 'a' .. 'z' ]->[ irand(36) ] } 1 .. 20));

	# Delete an LTI launch data item with this state if one happens to exist.
	$c->db->deleteLTILaunchData($LTIState);

	$c->db->addLTILaunchData($c->db->newLTILaunchData(
		state     => $LTIState,
		nonce     => $LTINonce,
		timestamp => time,
		data      => {
			# Note that for a content item selection request this may not be the correct courseID.
			courseID        => $c->stash->{courseID},
			PlatformID      => $c->ce->{LTI}{v1p3}{PlatformID},
			ClientID        => $c->ce->{LTI}{v1p3}{ClientID},
			DeploymentID    => $c->ce->{LTI}{v1p3}{DeploymentID},
			PublicKeysetURL => $c->ce->{LTI}{v1p3}{PublicKeysetURL},
			AccessTokenURL  => $c->ce->{LTI}{v1p3}{AccessTokenURL},
			AuthReqURL      => $c->ce->{LTI}{v1p3}{AuthReqURL}
		}
	));

	return $c->render(
		'ContentGenerator/LTI/self_posting_form',
		form_target => $c->ce->{LTI}{v1p3}{AuthReqURL},
		form_params => {
			repost           => 1,
			response_type    => 'id_token',
			response_mode    => 'form_post',
			scope            => 'openid',
			login_hint       => $c->param('login_hint'),
			lti_message_hint => $c->param('lti_message_hint'),
			state            => $LTIState,
			nonce            => $LTINonce,
			redirect_uri     => $c->url_for('ltiadvantage_launch')->to_abs,
			client_id        => $c->param('client_id'),
			prompt           => 'none'
		}
	);
}

sub launch ($c) {
	unless ($c->authen->{was_verified}) {
		if ($c->stash->{isContentSelection}) {
			$c->stash->{contextData} = [
				[ $c->maketext('LTI Version'), '1.3' ],
				[
					$c->maketext('Context Title'),
					$c->stash->{lti_jwt_claims}{'https://purl.imsglobal.org/spec/lti/claim/context'}{title}
				],
				[
					$c->maketext('Context ID'),
					$c->stash->{lti_jwt_claims}{'https://purl.imsglobal.org/spec/lti/claim/context'}{id}
				]
			];
		} elsif ($c->stash->{LTIAuthenError}) {
			debug($c->stash->{LTIAuthenError});
		}
		return $c->render(
			'ContentGenerator/LTI/content_item_selection_error',
			errorMessage => $c->maketext(
				'No WeBWorK course was found associated to this LMS course. '
					. 'If this is an error, please contact the WeBWorK system administrator.'
			)
		);
	}

	return $c->redirect_to($c->systemLink(
		$c->url_for($c->stash->{LTILaunchRedirect}),
		$c->stash->{isContentSelection}
		? (
			params => {
				courseID        => $c->stash->{courseID},
				initial_request => 1,
				accept_multiple =>
					$c->stash->{lti_jwt_claims}{'https://purl.imsglobal.org/spec/lti-dl/claim/deep_linking_settings'}
					{accept_multiple},
				deep_link_return_url =>
					$c->stash->{lti_jwt_claims}{'https://purl.imsglobal.org/spec/lti-dl/claim/deep_linking_settings'}
					{deep_link_return_url},
				$c->stash->{lti_jwt_claims}{'https://purl.imsglobal.org/spec/lti-dl/claim/deep_linking_settings'}
					{data}
				? (data => $c->stash->{lti_jwt_claims}
						{'https://purl.imsglobal.org/spec/lti-dl/claim/deep_linking_settings'}{data})
				: ()
			}
			)
		: ()
	));
}

sub content_selection ($c) {
	return $c->render('ContentGenerator/LTI/content_item_selection_error',
		errorMessage => $c->maketext('You are not authorized to access instructor tools.'))
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'access_instructor_tools');

	return $c->render('ContentGenerator/LTI/content_item_selection_error',
		errorMessage => $c->maketext('You are not authorized to modify sets.'))
		unless $c->authz->hasPermissions($c->authen->{user_id}, 'modify_problem_sets');

	if ($c->param('initial_request')) {
		return $c->render(
			'ContentGenerator/LTI/content_item_selection',
			visibleSets    => [ $c->db->getGlobalSetsWhere({ visible => 1 }, [qw(due_date set_id)]) ],
			acceptMultiple => $c->param('accept_multiple'),
			forwardParams  => {
				accept_multiple      => $c->param('accept_multiple'),
				deep_link_return_url => $c->param('deep_link_return_url'),
				$c->param('data') ? (data => $c->param('data')) : ()
			}
		);
	}

	my ($private_key, $err) = WeBWorK::Authen::LTIAdvantage::SubmitGrade::get_site_key($c->ce, 1);
	return $c->render(text => $c->maketext('Error loading or generating site keys: [_1]', $err))
		unless $private_key;

	my @selectedSets =
		$c->db->getGlobalSetsWhere({ set_id => [ $c->param('selected_sets') ] }, [qw(due_date set_id)]);

	my @problems =
		$c->db->getGlobalProblemsWhere({ set_id => [ $c->param('selected_sets') ] }, [qw(set_id problem_id)]);
	my %setMaxScores = map {
		my $setId = $_->set_id;
		my $max   = 0;
		$max += $_->value for (grep { $_->set_id eq $setId } @problems);
		$setId => $max;
	} @selectedSets;

	my $jwt = eval {
		encode_jwt(
			payload => {
				aud   => $c->ce->{LTI}{v1p3}{PlatformID},
				iss   => $c->ce->{LTI}{v1p3}{ClientID},
				jti   => $private_key->{kid},
				nonce => sha256_hex(join('', map { [ 0 .. 9, 'a' .. 'z' ]->[ irand(36) ] } 1 .. 20)),
				'https://purl.imsglobal.org/spec/lti/claim/message_type'  => 'LtiDeepLinkingResponse',
				'https://purl.imsglobal.org/spec/lti/claim/version'       => '1.3.0',
				'https://purl.imsglobal.org/spec/lti/claim/deployment_id' => $c->ce->{LTI}{v1p3}{DeploymentID},
				$c->param('data') ? ('https://purl.imsglobal.org/spec/lti-dl/claim/data' => $c->param('data')) : (),
				@selectedSets || $c->param('course_home_link')
				? (
					'https://purl.imsglobal.org/spec/lti-dl/claim/content_items' => [
						$c->param('course_home_link')
						? {
							type  => 'ltiResourceLink',
							title => $c->maketext('WeBWorK Assignments'),
							url   => $c->url_for('set_list', courseID => $c->stash->{courseID})->to_abs->to_string,
							$c->ce->{LTIGradeMode} eq 'course' ? (lineItem => { scoreMaximum => 100 }) : ()
							}
						: (),
						map { {
							type  => 'ltiResourceLink',
							title => format_set_name_display($_->set_id),
							$_->description ? (text => $_->description) : (),
							url =>
								$c->url_for('problem_list', courseID => $c->stash->{courseID}, setID => $_->set_id)
								->to_abs->to_string,
							$c->ce->{LTIGradeMode} eq 'homework'
							? (lineItem => { scoreMaximum => $setMaxScores{ $_->set_id } })
							: ()
						} } @selectedSets
					]
					)
				: ('https://purl.imsglobal.org/spec/lti-dl/claim/errormsg' =>
						$c->maketext('No content was selected.'))
			},
			key           => $private_key,
			extra_headers => { kid => $private_key->{kid} },
			alg           => 'RS256',
			auto_iat      => 1,
			relative_exp  => 3600,
		);
	};
	return $c->render(text => $c->maketext('Error encoding JWT: [_1]', $@)) if $@;

	return $c->render(
		'ContentGenerator/LTI/self_posting_form',
		form_target => $c->param('deep_link_return_url'),
		form_params => { JWT => $jwt }
	);
}

sub keys ($c) {
	my ($public_keyset, $err) = WeBWorK::Authen::LTIAdvantage::SubmitGrade::get_site_key($c->ce);
	return $c->render(json => $public_keyset) if $public_keyset;

	debug("Error loading or generating site keys: $err");
	return $c->render(data => 'Internal site configuration error', status => 500);
}

# Get the public keyset from the LMS and cache it in the database or just return what is already cached in the database.
# FIXME: This really needs another non-native table, and all courses that use a given LTI 1.3 configuration should share
# the public key that is retrieved here.
sub get_lms_public_keyset ($c, $ce, $db, $renew = 0) {
	my $keyset_str;

	if (!$renew) {
		$keyset_str = $db->getSettingValue('LTIAdvantageLMSPublicKey');
		return decode_json($keyset_str) if $keyset_str;
	}

	# Get public keyset from the LMS.
	my $response = eval { Mojo::UserAgent->new->get($ce->{LTI}{v1p3}{PublicKeysetURL})->result };
	if ($@) {
		$c->stash->{LTIAuthenError} = "Failed to obtain public key from LMS due to a network error: $@";
		return;
	}
	unless ($response->is_success) {
		$c->stash->{LTIAuthenError} = 'Failed to obtain public key from LMS: ' . $response->message;
		return;
	}

	$keyset_str = $response->body;
	my $keyset = eval { decode_json($keyset_str) };
	if ($@ || ref($keyset) ne 'HASH' || !defined $keyset->{keys}) {
		$c->stash->{LTIAuthenError} = 'Received an invalid response from the LMS public keyset URL.';
		return;
	}
	$db->setSettingValue('LTIAdvantageLMSPublicKey', $keyset_str);

	return $keyset;
}

sub extract_jwt_claims ($c) {
	return unless $c->param('state');

	# The following database object is not associated to any course, and so the only has access to non-native tables.
	my $db = WeBWorK::DB->new(WeBWorK::CourseEnvironment->new);

	# Retrieve the launch data saved in the login phase, and then delete it from the database.  Note that this verifies
	# the state in the request.  If there is no launch data saved in the database for the state in the request, then the
	# state in the request is invalid. This may indicate a possible CSFR.
	$c->stash->{LTILaunchData} = $db->getLTILaunchData($c->param('state'));
	unless ($c->stash->{LTILaunchData}) {
		$c->stash->{LTIAuthenError} = 'Invalid state in response from LMS.  Possible CSFR.';
		return;
	}

	$db->deleteLTILaunchData($c->stash->{LTILaunchData}->state);

	# This occurs before the proper course environment for this request is set.  So get a course environment using the
	# courseID in the data. Remember that this may not be the correct courseID if this is a deep linking request, but it
	# will work at this point since this course has the same LTI 1.3 parameters as the correct course.
	my $ce =
		eval { WeBWorK::CourseEnvironment->new({ courseName => $c->stash->{LTILaunchData}->data->{courseID} }) };
	unless ($ce) {
		$c->stash->{LTIAuthenError} =
			'Failed to initialize course environment for ' . $c->stash->{LTILaunchData}->data->{courseID} . ": $@\n";
		return;
	}
	$db = WeBWorK::DB->new($ce);

	$c->purge_expired_lti_data($ce, $db);

	my %jwt_params = (
		token      => $c->param('id_token'),
		verify_iss => $ce->{LTI}{v1p3}{PlatformID},
		verify_aud => $ce->{LTI}{v1p3}{ClientID},
		verify_iat => 1,
		verify_exp => 1,
		leeway     => $ce->{LTI}{v1p3}{JWTLeeway} // 0,
		# This just checks that this claim is present.
		verify_sub => sub ($value) { return $value =~ /\S/ }
	);

	$jwt_params{kid_keys} = $c->get_lms_public_keyset($ce, $db);
	return unless $jwt_params{kid_keys};

	my $claims = eval { decode_jwt(%jwt_params); };

	# If decoding of the JWT failed, then try to get a new LMS public keyset and try again.  It could be that the
	# keyset that was previously saved in the database has expired.
	unless ($claims) {
		$jwt_params{kid_keys} = get_lms_public_keyset($c, $ce, $db, 1);
		$claims = eval { $claims = decode_jwt(%jwt_params) };
	}
	if ($@) {
		$c->stash->{LTIAuthenError} = "Failed to decode token received from LMS: $@";
		return;
	}

	if ($ce->{debug_lti_parameters}) {
		$c->log->info("====== JWT PARAMETERS RECEIVED ======");
		$c->log->info($c->dumper($claims));
	}

	# Verify the nonce.
	if (!defined $claims->{nonce} || $claims->{nonce} ne $c->stash->{LTILaunchData}->nonce) {
		$c->stash->{LTIAuthenError} = 'Incorrect nonce received in response.';
		return;
	}

	# Verify the deployment id.
	if (!defined $claims->{'https://purl.imsglobal.org/spec/lti/claim/deployment_id'}
		|| $claims->{'https://purl.imsglobal.org/spec/lti/claim/deployment_id'} ne $ce->{LTI}{v1p3}{DeploymentID})
	{
		$c->stash->{LTIAuthenError} = "Incorrect deployment id received in response.";
		return;
	}

	return $claims;
}

# Delete any LTI data that is older than $ce->{LTI}{v1p3}{StateKeyLifetime}.
sub purge_expired_lti_data ($c, $ce, $db) {
	my $time = time;

	my @dataToDelete;

	for my $data ($db->getLTILaunchDataWhere) {
		push(@dataToDelete, $data->state) if $time - $data->timestamp > $ce->{LTI}{v1p3}{StateKeyLifetime};
	}

	$db->deleteLTILaunchDataWhere({ state => [@dataToDelete] }) if @dataToDelete;

	return;
}

async sub registration ($c) {
	return $c->render(json => { error => 'invalid configuration request' }, status => 400)
		unless defined $c->req->param('openid_configuration') && defined $c->req->param('registration_token');

	# If we want to allow options in the configuration such as whether grade passback is enabled or to allow the LMS
	# administrator to choose a tool name, then this should render a form that the LMS will be presented in an iframe
	# allowing the LMS administrator to select the options. When that form is submitted, then the code below should be
	# executed taking those options into consideration.  However, at this point this is a simplistic approach that will
	# work in most cases.

	$c->render_later;

	my $configurationResult = (await Mojo::UserAgent->new->get_p($c->req->param('openid_configuration')))->result;
	return $c->render(json => { error => 'unabled to obtain openid configuration' }, status => 400)
		unless $configurationResult->is_success;
	my $lmsConfiguration = $configurationResult->json;

	return $c->render(json => { error => 'invalid openid configuration received' }, status => 400)
		unless defined $lmsConfiguration->{registration_endpoint}
		&& defined $lmsConfiguration->{issuer}
		&& defined $lmsConfiguration->{jwks_uri}
		&& defined $lmsConfiguration->{token_endpoint}
		&& defined $lmsConfiguration->{authorization_endpoint}
		&& defined $lmsConfiguration->{'https://purl.imsglobal.org/spec/lti-platform-configuration'}
		{product_family_code};

	# FIXME: This should also probably check that the token_endpoint_auth_method is private_key_jwt, the
	# id_token_signing_alg_values_supported is RS256, and that the scopes_supported is an array and contains all of the
	# scopes listed below. There are perhaps some other configuration values that should be checked as well.  However,
	# most of the time these are all going to be fine.

	my $rootURL = $c->url_for('root')->to_abs;

	my $registrationResult = (await Mojo::UserAgent->new->post_p(
		$lmsConfiguration->{registration_endpoint},
		{
			Authorization  => 'Bearer ' . $c->req->param('registration_token'),
			'Content-Type' => 'application/json'
		},
		json => {
			application_type           => 'web',
			response_types             => ['id_token'],
			grant_types                => [ 'implicit', 'client_credentials' ],
			client_name                => 'WeBWorK at ' . $rootURL->host_port,
			client_uri                 => $rootURL->to_string,
			initiate_login_uri         => $c->url_for('ltiadvantage_login')->to_abs->to_string,
			redirect_uris              => [ $c->url_for('ltiadvantage_launch')->to_abs->to_string ],
			jwks_uri                   => $c->url_for('ltiadvantage_keys')->to_abs->to_string,
			token_endpoint_auth_method => 'private_key_jwt',
			scope                      => join(' ',
				'https://purl.imsglobal.org/spec/lti-ags/scope/lineitem',
				'https://purl.imsglobal.org/spec/lti-ags/scope/lineitem.readonly',
				'https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly',
				'https://purl.imsglobal.org/spec/lti-ags/scope/score'),
			'https://purl.imsglobal.org/spec/lti-tool-configuration' => {
				domain          => $rootURL->host_port,
				target_link_uri => $rootURL->to_string,
				claims          => [ 'iss', 'sub', 'name', 'given_name', 'family_name', 'email' ],
				messages        => [ {
					type            => 'LtiDeepLinkingRequest',
					target_link_uri => $c->url_for('ltiadvantage_content_selection')->to_abs->to_string,
					# Placements are specific to the LMS.  The following placements are needed for Canavas, and Moodle
					# completely ignores this parameter. Does D2L need any? What about Blackboard?
					placements => [ 'assignment_selection', 'course_assignments_menu' ]
				} ]
			}
		}
	))->result;
	unless ($registrationResult->is_success) {
		$c->log->error('Invalid regististration response: ' . $registrationResult->message);
		return $c->render(json => { error => 'invalid registration response' }, status => 400);
	}
	return $c->render(json => { error => 'invalid registration received' }, status => 400)
		unless defined $registrationResult->json->{client_id};

	my $configuration = <<~ "END_CONFIG";
	\$LTI{v1p3}{PlatformID}      = '$lmsConfiguration->{issuer}';
	\$LTI{v1p3}{ClientID}        = '${\($registrationResult->json->{client_id})}';
	\$LTI{v1p3}{DeploymentID}    = '${
		\($registrationResult->json->{'https://purl.imsglobal.org/spec/lti-tool-configuration'}{deployment_id}
		// 'obtain from LMS administrator')
	}';
	\$LTI{v1p3}{PublicKeysetURL} = '$lmsConfiguration->{jwks_uri}';
	\$LTI{v1p3}{AccessTokenURL}  = '$lmsConfiguration->{token_endpoint}';
	\$LTI{v1p3}{AccessTokenAUD}  = '${
		\($lmsConfiguration->{authorization_server}
		// $lmsConfiguration->{token_endpoint})
	}';
	\$LTI{v1p3}{AuthReqURL}      = '$lmsConfiguration->{authorization_endpoint}';
	END_CONFIG

	my $registrationDir = Mojo::File->new($c->ce->{webworkDirs}{DATA})->child('LTIRegistrationRequests');
	if (!-d $registrationDir) {
		eval { $registrationDir->make_path };
		if ($@) {
			$c->log->error("Failed to create directory for saving LTI registrations: $@");
			return $c->render(json => { error => 'internal server error' }, status => 400);
		}
	}

	my $registrationFile = tempfile(
		TEMPLATE =>
			$lmsConfiguration->{'https://purl.imsglobal.org/spec/lti-platform-configuration'}{product_family_code}
			. '-XXXX',
		DIR    => $registrationDir,
		SUFFIX => '.conf',
		UNLINK => 0
	);
	$registrationFile->spew($configuration, 'UTF-8');

	# This tells the LMS that registration is complete and it can close its dialog.
	return $c->render(data => '<script>'
			. q!(window.opener || window.parent).postMessage({ subject: 'org.imsglobal.lti.close' }, '*');!
			. '</script>');
}

1;
