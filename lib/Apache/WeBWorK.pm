################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/Apache/WeBWorK.pm,v 1.61 2003/12/09 01:12:29 sh002i Exp $
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

package Apache::WeBWorK;
#use base qw(DB);

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
 	
 		PerlSetVar webwork_root /path/to/webwork2
 		PerlSetVar pg_root /path/to/pg
 		
 		<Perl>
 			use lib '/path/to/webwork2/lib';
 			use lib '/path/to/pg/lib';
 		</Perl>
 	</Location>
 </IfModule>

=cut

use strict;
use warnings;
use WeBWorK;

sub handler($) {
	my ($r) = @_;
	
	my $result;
	{ # limit the scope of signal localization
		# the __WARN__ handler stores warnings for later retrieval
		local $SIG{__WARN__} = sub {
			my ($warning) = @_;
			my $warnings = $r->notes("warnings");
			$warnings .= "$warning\n";
			$r->notes("warnings" => $warnings);
			warn $warning; # send it to the log
		};
		
		# the __DIE__ handler stores the call stack at the time of an error
		local $SIG{__DIE__} = sub {
			my ($error) = @_;
			# Traces are still causing problems
			#my $trace = join "\n", Apache::WeBWorK->backtrace();
			#$r->notes("lastCallStack" => $trace);
			die $error;
		};
		
		$result = eval { WeBWorK::dispatch($r) };
	}
	
	if ($@) {
		print STDERR "uncaught exception in Apache::WeBWorK::handler: $@";
		my $message = message($r, $@);
		unless ($r->bytes_sent) {
			$r->content_type("text/html");
			$r->send_http_header;
			$message = "<html><body>$message</body></html>";
		}
		$r->print($message);
		$r->exit;
	}
	
	return $result;
}

sub htmlBacktrace(@) {
	foreach (@_) {
		s/\</&lt;/g;
		s/\>/&gt;/g;
		$_ = "<li><tt>$_</tt></li>";
	}
	return join "\n", @_;
}

sub htmlWarningsList(@) {
	foreach (@_) {
		next unless m/\S/;
		s/\</&lt;/g;
		s/\>/&gt;/g;
		$_ = "<li><tt>$_</tt></li>";
	}
	return join "\n", @_;
}

sub htmlEscape($) {
	$_[0] =~ s/\</&lt;/g;
	$_[0] =~ s/\>/&gt;/g;
	return $_[0];
}

sub message($$) {
	my ($r, $exception) = @_;
	
	$exception = htmlEscape($exception);
	my $admin = ($ENV{SERVER_ADMIN}
		? "(<a href=\"mailto:$ENV{SERVER_ADMIN}\">$ENV{SERVER_ADMIN}</a>)"
		: "");
	my $context = $r->notes("lastCallStack")
		? htmlBacktrace(split m/\n/, $r->notes("lastCallStack"))
		: "";
	my $warnings = $r->notes("warnings")
		? htmlWarningsList(split m/\n/, $r->notes("warnings"))
		: "";
	my $method = $r->method;
	my $uri = $r->uri;
	my $headers = do {
		my %headers = $r->headers_in;
		join("", map { "<tr><td><small>$_</small></td><td><small>$headers{$_}</small></td></tr>" } keys %headers);
	};
	
	return <<EOF;
<div align="left">
 <h1>Software Error</h1>
 <p>An error has occured while trying to process your request. For help, please
 send mail to this site's webmaster $admin giving the following information
 about the error and the date and time that the error occured. Some hints:</p>
 <ul>
  <li>An error about an <tt>undefined value</tt> often means that you asked for
  an object (like a user, problem set, or problem) that does not exist, and the
  we (the programmers) were negligent in checking for that.</li>
  <li>An error about <tt>permission denied</tt> might suggest that the web
  server does not have permission to read or write a file or directory.</li>
 </ul>
 <h2>Error message</h2>
 <p><tt>$exception</tt></p>
 <h2>Call stack</h2>
 <ul>$context</ul>
 <h2>Warnings</h2>
 <ul>$warnings</ul>
 <h2>Request information</h2>
 <table border="1">
  <tr><td>Method</td><td>$method</td></tr>
  <tr><td>URI</td><td>$uri</td></tr>
  <tr><td>HTTP Headers</td><td>
   <table width="90%">
    $headers
   </table>
  </td></tr>
 </table>
</div>
EOF
}

1;
