################################################################################
# WeBWorK mod_perl (c) 2000-2002 WeBWorK Project
# $Id$
################################################################################

package Apache::WeBWorK;

=head1 NAME

Apache::WeBWorK - mod_perl handler for WeBWorK.

=head1 CONFIGURATION

This module should be installed as a Handler for the location selected for
WeBWorK on your webserver. Here is an example of a stanza that can be added to
your httpd.conf file to achieve this:

 <IfModule mod_perl.c>
 	PerlFreshRestart On
 	<Location /webwork2>
 		SetHandler perl-script
 		PerlHandler Apache::WeBWorK
 		PerlSetVar webwork_root /path/to/webwork-modperl
 		<Perl>
 			use lib '/path/to/webwork-modperl/lib';
 			use lib '/path/to/webwork-modperl/pglib';
 		</Perl>
 	</Location>
 </IfModule>

=cut

use strict;
use warnings;
use WeBWorK; # leave compile-time errors alone.

sub handler($) {
	my ($r) = @_;
	my $result = eval {
		WeBWorK::dispatch($r)
	};
	if ($@) {
		my $message = message($r, $@);
		unless ($r->bytes_sent) {
			$message = "<html><body>$message</body></html>";
			$r->content_type("text/html");
			$r->send_http_header;
		}
		$r->print($message);
		die $@;
	}
	return $result;
}

sub message($$) {
	my ($r, $exception) = @_;
	
	my $admin = ($ENV{SERVER_ADMIN}
		? "(<a href=\"mailto:$ENV{SERVER_ADMIN}\">$ENV{SERVER_ADMIN}</a>)"
		: "");
	# Error context doesn't work yet -- calling longmess() from here is stupid
	#my $context = Carp::longmess();
	my $method = $r->method;
	my $uri = $r->uri;
	my $headers = do {
		my %headers = $r->headers_in;
		join("", map { "<tr><td>$_</td><td>$headers{$_}</td></tr>" } keys %headers);
	};
	
	return <<EOF;
<div align="left">
 <h1>Software Error</h1>
 <p>An error has occured while trying to process you request. For help, please send mail to this site's webmaster $admin giving the following information about the error and the date and time that the error occured.</p>
 <h2>Error message</h2>
 <pre>$exception</pre>
 <h2>Request information</h2>
 <dl>
  <dt>Method</dt>
  <dd>$method</dd>
  <dt>URI</dt>
  <dd>$uri</dd>
 </dl>
 <h2>Headers received</h2>
 <table>$headers</table>
</div>
EOF
	# <h2>Error context</h2>
	# <blockquote>
	#  <pre>$context</pre>
	# </blockquote>
}

1;
