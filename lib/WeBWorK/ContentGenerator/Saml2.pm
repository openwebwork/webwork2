package WeBWorK::ContentGenerator::Saml2;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

use Mojo::JSON qw(decode_json);

use WeBWorK::Debug qw(debug);

sub initializeRoute ($c, $routeCaptures) {
	if ($c->current_route eq 'saml2_acs') {
		return unless $c->param('SAMLResponse') && $c->param('RelayState');
		$c->stash->{saml2}{relayState} = decode_json($c->param('RelayState'));
		$c->stash->{saml2}{samlResp}   = $c->param('SAMLResponse');
		$routeCaptures->{courseID}     = $c->stash->{courseID} = $c->stash->{saml2}{relayState}{course};
	}

	$routeCaptures->{courseID} = $c->stash->{courseID} = $c->param('courseID')
		if $c->current_route eq 'saml2_metadata' && $c->param('courseID');

	return;
}

sub assertionConsumerService ($c) {
	debug('Authentication succeeded.  Redirecting to ' . $c->stash->{saml2_redirect});
	return $c->redirect_to($c->stash->{saml2_redirect});
}

sub metadata ($c) {
	return $c->render(data => 'Internal site configuration error', status => 500) unless $c->authen->can('sp');
	return $c->render(data => $c->authen->sp->metadata,            format => 'xml');
}

sub errorResponse ($c) {
	return $c->reply->exception('SAML2 Login Error')->rendered(400);
}

# When this request comes in the user is actually already signed out of webwork, so this just attempts to redirect back
# to webwork's logout page for the course. This doesn't verify anything in the response from the identity provider, but
# hopefully the courseID is found in the relay state so that the user can be redirected to the logout page for the
# course.
sub logout ($c) {
	return $c->render('SAML2 Logout Error', status => 500) unless $c->param('RelayState');
	return $c->redirect_to($c->url_for('logout', courseID => decode_json($c->param('RelayState'))->{course}));
}

1;
