package WebworkSOAP::WSDL;

use lib '/opt/webwork/webwork2/lib';
use Pod::WSDL;
use WebworkSOAP;

use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );
use constant RPC_URL => 'https://devel.webwork.rochester.edu:8002/webwork2_rpc';

sub handler($) {
    my ($r) = @_;
    my $pod = new Pod::WSDL(
        source => 'WebworkSOAP',
        location => RPC_URL,
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
