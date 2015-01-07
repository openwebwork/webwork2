package WebworkSOAP::WSDL;

use lib '/opt/webwork/webwork2/lib';
use Pod::WSDL;
use WebworkSOAP;

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

BEGIN {
###############################################################################
# Configuration -- set to top webwork directory (webwork2) (set in webwork.apache2-config)
# Configuration -- set server url automatically for this file
###############################################################################

    our $webwork_directory = $WeBWorK::Constants::WEBWORK_DIRECTORY; #'/opt/webwork/webwork2';
	print "WebworkSOAP::WSDL: webwork_directory set to ", $WeBWorK::Constants::WEBWORK_DIRECTORY,
	      " via \$WeBWorK::Constants::WEBWORK_DIRECTORY set in webwork.apache2-config\n";
 	my $seed_ce = new WeBWorK::CourseEnvironment({ webwork_dir => $webwork_directory });
 	die "Can't create seed course environment for webwork in $webwork_directory" unless ref($seed_ce);
	my $server_root_url   = $seed_ce->{server_root_url}; #"http://localhost"; 
	our $RPC_URL          = "$server_root_url/webwork2_rpc";
	print "WebworkSOAP::WSDL: rpc_url set to $RPC_URL \n";
	
}



sub handler($) {
    my ($r) = @_;
    my $pod = new Pod::WSDL(
        source => 'WebworkSOAP',
        location => $RPC_URL,
        pretty => 1,
        withDocumentation => 0
        );
    #$r->content_type('application/wsdl+xml');
    if (MP2) {
        #$r->send_http_header;
    } else {
        $r->send_http_header;
    }
    print($pod->WSDL);
    return 0;
}

1;
