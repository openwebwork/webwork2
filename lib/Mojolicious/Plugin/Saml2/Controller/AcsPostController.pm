package Mojolicious::Plugin::Saml2::Controller::AcsPostController;

use Mojo::Base 'WeBWorK::Controller', -signatures, -async_await;

use Mojo::JSON qw(decode_json);
use Net::SAML2::Binding::POST;
use Net::SAML2::Protocol::Assertion;

use WeBWorK::Authen::Saml2;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Debug qw(debug);

async sub post ($c) {
	debug('SAML2 is on!');
	# check required params
	my $samlResp = $c->param('SAMLResponse');
	if (!$samlResp) {
		return $c->reply->exception('Unauthorized - Missing SAMLResponse')->rendered(401);
	}
	my $relayState = $c->param('RelayState');
	if (!$relayState) {
		return $c->reply->exception('Unauthorized - Missing RelayState')->rendered(401);
	}
	$relayState = decode_json($relayState);

	my $idp  = $c->saml2->getIdp();
	my $conf = $c->saml2->getConf();

	# verify response is signed by the IdP and decode it
	my $postBinding = Net::SAML2::Binding::POST->new(cacert => $c->saml2->getIdpCertFile());
	my $decodedXml  = $postBinding->handle_response($samlResp);
	my $assertion   = Net::SAML2::Protocol::Assertion->new_from_xml(
		xml      => $decodedXml,
		key_file => $c->saml2->getSpSigningKeyFile()
	);

	$c->_actAsWebworkController($relayState->{course});
	# get the authReqId we generated when we sent the user to the IdP
	my $authReqId = $c->session->{authReqId};
	delete $c->session->{authReqId};    # delete from session to avoid replay

	# verify the response has the same authReqId which means it's responding to
	# the auth request we generated, also checks that timestamps are valid
	my $valid = $assertion->valid($conf->{sp}{entity_id}, $authReqId);
	if (!$valid) {
		return $c->reply->exception('Unauthorized - Bad timestamp or issuer')->rendered(401);
	}

	debug('Got valid response and looking for username');
	my $userId = $c->_getUserId($conf->{sp}{attributes}, $assertion, $relayState);
	if ($userId) {
		debug("Got username $userId");
		$c->authen->setSaml2UserId($userId);
		if (!$c->authen->verify()) {
			debug("Saml2 User Verify Failed");
			debug("Rendering WeBWorK::ContentGenerator::Login");
			return await WeBWorK::ContentGenerator::Login->new($c)->go();
		}
		return $c->redirect_to($relayState->{url});
	}
	return $c->reply->exception('Unauthorized - User not found in ' . $relayState->{course})->rendered(401);
}

sub _actAsWebworkController ($c, $courseName) {
	# we need to call Webwork authen module to create the auth session, so our
	# controller need to have the things that the authen module needs to use
	$c->stash('courseID', $courseName);
	$c->ce(WeBWorK::CourseEnvironment->new({ courseName => $courseName }));
	$c->db(WeBWorK::DB->new($c->ce->{dbLayout}));
	my $authz = WeBWorK::Authz->new($c);
	$c->authz($authz);
	my $authen = WeBWorK::Authen::Saml2->new($c);
	$c->authen($authen);
}

sub _getUserId ($c, $attributeKeys, $assertion, $relayState) {
	my $ce = $c->{ce};
	my $db = $c->{db};
	my $user;
	if ($attributeKeys) {
		foreach my $key (@$attributeKeys) {
			debug("Trying attribute $key for username");
			my $possibleUserId = $assertion->attributes->{$key}->[0];
			if (!$possibleUserId) { next; }
			if ($db->getUser($possibleUserId)) {
				debug("Using attribute value for username: $possibleUserId");
				return $possibleUserId;
			}
		}
	}
	debug("No username match in attributes, trying NameID fallback");
	if ($db->getUser($assertion->nameid)) {
		debug("Using NameID for username: " . $assertion->nameid);
		return $assertion->nameid;
	}
	debug("NameID fallback failed, no username possible");
	return '';
}

1;
