package Mojolicious::Plugin::Saml2::Saml2Plugin;
use Mojo::Base 'Mojolicious::Plugin', -strict, -signatures;
# external libs
use Data::Dumper;
use File::Temp qw/ tempfile /;
use JSON;
use Mojolicious;
use Mojolicious::Plugin::NotYAMLConfig;
use Net::SAML2::IdP;
use Net::SAML2::SP;
use URN::OASIS::SAML2 qw(BINDING_HTTP_POST BINDING_HTTP_REDIRECT);
# external libs for NotYAMLConfig
use CPAN::Meta::YAML;
use Mojo::Util qw(decode encode);
# webwork modules
use WeBWorK::Debug;
# plugin's own modules
use Mojolicious::Plugin::Saml2::Exception;
use Mojolicious::Plugin::Saml2::Router;

use constant Exception => 'Mojolicious::Plugin::Saml2::Exception';

our $VERSION = '0.0.1';

sub register ($self, $app, $conf = {}) {
	# yml config can be overridden with config passed in during plugin init
	$conf = $self->_loadConf($conf, $app);
	$self->checkConf($conf);
	# note this will grab the IdP metadata on every server reboot
	my $idp              = Net::SAML2::IdP->new_from_url(url => $conf->{idp}{metadata_url});
	my $spCertFile       = $self->_getTmpFileWithContent($conf->{sp}{cert});
	my $spSigningKeyFile = $self->_getTmpFileWithContent($conf->{sp}{signing_key});
	my $idpCertFile      = $self->_getTmpFileWithContent($idp->cert('signing')->[0]);
	# setup routes for metadata and samlresponse handling
	Mojolicious::Plugin::Saml2::Router::setup($app, $conf);
	# cached values we need later
	$app->helper('saml2.getConf'             => sub { return $conf; });
	$app->helper('saml2.getIdp'              => sub { return $idp; });
	$app->helper('saml2.getSpCertFile'       => sub { return $spCertFile; });
	$app->helper('saml2.getSpSigningKeyFile' => sub { return $spSigningKeyFile; });
	$app->helper('saml2.getIdpCertFile'      => sub { return $idpCertFile; });
	$app->helper('saml2.getSp'               => \&getSp);
	# called by the Webwork Saml2 authen module to redirect users to the IdP
	$app->helper('saml2.sendLoginRequest' => \&sendLoginRequest);
}

sub checkConf ($self, $conf) {
	if (!$conf->{idp}) {
		Exception->throw("Config missing 'idp' section");
	}
	if (!$conf->{idp}{metadata_url}) {
		Exception->throw("Config in 'idp' missing 'metadata_url'");
	}
	if (!$conf->{sp}) {
		Exception->throw("Config missing 'sp' section");
	}
	if (!$conf->{sp}{entity_id}) {
		Exception->throw("Config in 'sp' missing 'entity_id'");
	}
	if (!$conf->{sp}{cert}) {
		Exception->throw("Config in 'sp' missing 'cert'");
	}
	if (!$conf->{sp}{signing_key}) {
		Exception->throw("Config in 'sp' missing 'signing_key'");
	}
	if (!$conf->{sp}{route}) {
		Exception->throw("Config missing 'sp.route' section");
	}
	if (!$conf->{sp}{route}{base}) {
		Exception->throw("Config in 'sp.route' missing 'base'");
	}
	if (!$conf->{sp}{route}{metadata}) {
		Exception->throw("Config in 'sp.route' missing 'metadata'");
	}
	if (!$conf->{sp}{route}{acs}) {
		Exception->throw("Config missing 'sp.route.acs' section");
	}
	if (!$conf->{sp}{route}{acs}{post}) {
		Exception->throw("Config in 'sp.route.acs' missing 'post'");
	}
}

# we need an SP instance in order to generate the xml metadata and specify our
# SP endpoints. We have to do this in a helper cause we need to use the
# controller's url_for()
sub getSp ($c) {
	state $sp;
	if ($sp) { return $sp; }
	my $conf = $c->saml2->getConf();
	$sp = Net::SAML2::SP->new(
		issuer => $conf->{sp}->{entity_id},
		# base url for SP services
		url                        => $ENV{WEBWORK_ROOT_URL} . $c->url_for('saml2.base'),
		error_url                  => $ENV{WEBWORK_ROOT_URL} . $c->url_for('saml2.error'),
		cert                       => $c->saml2->getSpCertFile(),
		key                        => $c->saml2->getSpSigningKeyFile(),
		org_contact                => $conf->{sp}->{org}->{contact},
		org_name                   => $conf->{sp}->{org}->{name},
		org_url                    => $conf->{sp}->{org}->{url},
		org_display_name           => $conf->{sp}->{org}->{display_name},
		assertion_consumer_service => [ {
			Binding   => BINDING_HTTP_POST,
			Location  => $ENV{WEBWORK_ROOT_URL} . $c->url_for('saml2.acsPost'),
			isDefault => 'true',
		} ]
	);
	return $sp;
}

# $returnUrl is the course URL that the user should be directed into after they
# sucessfully authed at the IdP
sub sendLoginRequest ($c, $returnUrl, $courseName) {
	debug('Creating Login Request');
	my $conf    = $c->saml2->getConf();
	my $idp     = $c->saml2->getIdp();
	my $sp      = $c->saml2->getSp();
	my $authReq = $sp->authn_request($idp->sso_url(BINDING_HTTP_REDIRECT));
	$c->session->{authReqId} = $authReq->id;
	my $redirect = $sp->sso_redirect_binding($idp, 'SAMLRequest');
	# info the IdP relays back to help us put the user in the right place after
	# login
	my $relayState = {
		'course' => $courseName,
		'url'    => $returnUrl
	};
	my $url = $redirect->sign($authReq->as_xml, encode_json($relayState));
	debug('Redirecting user to the IdP');
	$c->redirect_to($url);
}

# Write $content into a temporary file and return the full path to that file.
# Net:SAML2 strangely won't take keys and certs as strings, it only wants
# filepaths, this helper is meant to get around that.
sub _getTmpFileWithContent ($self, $content) {
	my ($fh, $filename) = tempfile();
	print $fh $content;
	close($fh);
	return $filename;
}

sub _loadConf ($self, $pluginConf, $app) {
	my $confFile = "$ENV{WEBWORK_ROOT}/conf/authen_saml2.yml";
	if (!-e $confFile) {
		Exception->throw("Missing conf file: $confFile");
	}
	$app->config->{config_override} = 1;
	my $yamlPlugin = Mojolicious::Plugin::NotYAMLConfig->new;
	# we just want to use the plugin's load() method and don't want to merge
	# with the app config, so we have to manually do the setup done in
	# NotYAMLConfig's register()
	$yamlPlugin->{yaml} = sub { CPAN::Meta::YAML::Load(decode 'UTF-8', shift) };
	my $yamlConf = $yamlPlugin->load($confFile, {}, $app);
	return { %$yamlConf, %$pluginConf };
}

1;
