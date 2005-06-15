package MySOAP;

use constant DEBUG =>0;

  use Apache::Request;
  use Apache::Constants qw(:common);
  use Apache::File ();
  use SOAP::Transport::HTTP;

  my $server = SOAP::Transport::HTTP::Apache
    -> dispatch_to('RQP');

  sub handler { 
    my $save = $_[0];
    my $r = Apache::Request->instance($_[0]);
    
    my $header = $r->as_string;
    my $args = $r->args;
    my $content = $r->content;
    my $body="";
    # this will read everything, but then it won't be available for SOAP
    my $r2 = Apache::Request->instance($save) if DEBUG;
    $r2->read($body, $r2->header_in('Content-length')) if DEBUG;
    #
    local(*DEBUGLOG);
    open DEBUGLOG, ">>/home/gage/debug_info.txt" || die "can't open debug file";
    
    
    
    
    ################
    # Handle a wsdl rquest
    ################
    my %args_hash = $r->args;
   if (exists $args_hash{wsdl}) {
    	$r->print( $wsdl);
    	print DEBUGLOG "----------start-------------\n";
    	print DEBUGLOG "handle wsdl request\n";
    	print DEBUGLOG "\n-header =\n $header\n" ;
    	
    	
    	my $wsdl = `cat /home/gage/rqp.wsdl`;
    	$r->content_type('application/wsdl+xml');
    	$r->send_http_header;
    	$r->print( $wsdl);
 
    	
    	print DEBUGLOG "---end--- \n";
    	close(DEBUGLOG);
    	return OK;
    ###############
    # Handle SOAP request
    ###############  	
    } else {
		print DEBUGLOG "----------start-------------\n";
		print DEBUGLOG "handle soap request\n";
		print DEBUGLOG "\n-header =\n $header\n" ; #if DEBUG;
		print DEBUGLOG "args=  $args\n";
		print DEBUGLOG "\nbody= $body\n" if DEBUG;
		
		$server->handler(@_);
		
		print DEBUGLOG "---end--- \n";
		close(DEBUGLOG);

    }
    
    


  };

1;
