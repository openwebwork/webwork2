package WebworkSOAP::WSDL;

use lib '/opt/webwork/webwork2/lib';
use Pod::WSDL;
use WebworkSOAP;

BEGIN {
###############################################################################
	# Configuration -- set to top webwork directory (webwork2) (set in webwork.apache2-config)
	# Configuration -- set server url automatically for this file
###############################################################################

	our $webwork_directory = $WeBWorK::Constants::WEBWORK_DIRECTORY;    #'/opt/webwork/webwork2';
	my $seed_ce = new WeBWorK::CourseEnvironment({ webwork_dir => $webwork_directory });
	die "Can't create seed course environment for webwork in $webwork_directory" unless ref($seed_ce);
	my $server_root_url = $seed_ce->{server_root_url};                  #"http://localhost";
	our $RPC_URL = "$server_root_url/webwork2_rpc";

}

sub handler($) {
	my ($r) = @_;
	my $pod = new Pod::WSDL(
		source            => 'WebworkSOAP',
		location          => $RPC_URL,
		pretty            => 1,
		withDocumentation => 0
	);

	print($pod->WSDL);
	return 0;
}

1;
