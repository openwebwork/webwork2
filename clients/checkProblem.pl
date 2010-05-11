#!/usr/bin/perl -w

=pod

This script will take a command and an input 
file.

It will render the input file.

All of this is done by contacting the webservice.



=cut

use constant LOG_FILE => '/Volumes/Riemann/webwork/problemLibraries/bad_problems.txt';
use XMLRPC::Lite;
use MIME::Base64 qw( encode_base64 decode_base64);
require "webwork_xmlrpc_inc.pl"; # must be in the same directory

our $source = '';

if (@ARGV) {
    $source = (defined $ARGV[0]) ? `cat $ARGV[0]` : '' ;
    my $command = 'renderProblem';
	my $rh_result = xmlrpcCall($command, $source);
	if ($rh_result) {
		if (defined($rh_result->{WARNINGS}) and $rh_result->{WARNINGS} ) {
		    local(*FH);
			open(FH, ">>".LOG_FILE()) || die "Can't open log file ". LOG_FILE();
			print FH "$ARGV[0]\n";
			close(FH);
			print "$ARGV[0] has warnings\n";
		} else {
			print "$ARGV[0] is ok\n"; #problem is ok
		}
	} else {
		print 0;
	}


} else {
    print "0\n";
	print STDERR "Useage: ./checkProblem.pl    [file_name]\n";
	print STDERR "For example: ./checkProblem.pl    input.txt\n";
	
}