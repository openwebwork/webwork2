################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/Apache/WeBWorK.pm,v 1.71 2004/10/07 23:08:13 gage Exp $
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

=head1 NAME

Apache::WeBWorK - mod_perl handler for WeBWorK 2.

=head1 CONFIGURATION

This module should be installed as a Handler for the location selected for
WeBWorK on your webserver. Refer to the file F<conf/webwork.apache-config> for
details.

=cut

use strict;
use warnings;
use Apache::Log;
use HTML::Entities;
use Date::Format;
use WeBWorK;

################################################################################

=head1 APACHE REQUEST HANDLER

=over

=item handler($r)

=cut

sub handler($) {
	my ($r) = @_;
	my $log = $r->log;
	
	# *** FIXME: ContentGenerator is still checking $r->notes("warnings").
	# how can we give it access to this warning list?
	
	# the warning handler accumulates warnings in $r->notes("warnings") for
	# later cumulative reporting
	#my @warnings;
	my $warning_handler = sub {
		my ($warning) = @_;
		my $warnings = $r->notes("warnings");
		$warnings .= "$warning\n";
		$r->notes("warnings", $warnings);
		warn $warning;
	};
	
	# the exception handler generates a backtrace when catching an exception
	my @backtrace;
	my $exception_handler = sub {
		@backtrace = backtrace();
		die @_;
	};
	
	my $result = do {
		local $SIG{__WARN__} = $warning_handler;
		local $SIG{__DIE__} = $exception_handler;
		
		eval { WeBWorK::dispatch($r) };
	};
	
	if ($@) {
		my $exception = $@;
		
		my $warnings = $r->notes("warnings");
		my $message = message($r, $warnings, $exception, @backtrace);
		unless ($r->bytes_sent) {
			$r->content_type("text/html");
			$r->send_http_header;
			$message = "<html><body>$message</body></html>";
		}
		$r->print($message);
		
		# log the error to the apache error log
		my $time = time2str("%a %b %d %H:%M:%S %Y", time);
		my $uri = $r->uri;
		$log->error("[$uri] $exception");
	}
	
	return $result;
}

=back

=cut

################################################################################

=head1 ERROR HANDLING ROUTINES

=over

=item backtrace()

Produce a stack-frame traceback for the calls up through the ones in
Apache::WeBWorK.

=cut

sub backtrace {
	my $frame = 2;
	my @trace;
	
	while (my ($pkg, $file, $line, $subname) = caller($frame++)) {
		last if $pkg eq "Apache::WeBWorK";
		push @trace, "in $subname called at line $line of $file";
	}
	
	return @trace;
}

=back

=cut

################################################################################

=head1 ERROR OUTPUT FUNCTIONS

=over

=item message($r, $warnings, $exception, @backtrace)

Format a message reporting an exception, backtrace, and any associated warnings.

=cut

sub message($$$@) {
	my ($r, $warnings, $exception, @backtrace) = @_;
	
	my @warnings = split m/\n+/, $warnings;
	$warnings = htmlWarningsList(@warnings);
	$exception = htmlEscape($exception);
	my $backtrace = htmlBacktrace(@backtrace);
	
	my $admin = ($ENV{SERVER_ADMIN}
		? " (<a href=\"mailto:$ENV{SERVER_ADMIN}\">$ENV{SERVER_ADMIN}</a>)"
		: "");
	my $time = time2str("%a %b %d %H:%M:%S %Y", time);
	my $method = $r->method;
	my $uri = $r->uri;
	my $headers = do {
		my %headers = $r->headers_in;
		join("", map { "<tr><td><small>$_</small></td><td><small>$headers{$_}</small></td></tr>" } keys %headers);
	};
	
	return <<EOF;
<div style="text-align:left">
 <h2>WeBWorK error</h2>
 <p>An error occured while processing your request. For help, please send mail
 to this site's webmaster$admin, including all of the following information as
 well as what what you were doing when the error occured.</p>
 <p>$time</p>
 <h3>Warning messages</h3>
 <ul>$warnings</ul>
 <h3>Error messages</h3>
 <blockquote style="color:red"><code>$exception</code></blockquote>
 <h3>Call stack</h3>
   <p>The information below can help locate the source of the problem.</p>
   <ul>$backtrace</ul>
 <h3>Request information</h3>
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

=item htmlBacktrace(@frames)

Formats a list of stack frames in a backtrace as list items for HTML output.

=cut

sub htmlBacktrace(@) {
	my (@frames) = @_;
	foreach my $frame (@frames) {
		$frame = htmlEscape($frame);
		$frame = "<li><code>$frame</code></li>";
	}
	return join "\n", @frames;
}

=item htmlWarningsList(@warnings)

Formats a list of warning strings as list items for HTML output.

=cut

sub htmlWarningsList(@) {
	my (@warnings) = @_;
	foreach my $warning (@warnings) {
		$warning = htmlEscape($warning);
		$warning = "<li><code>$warning</code></li>";
	}
	return join "\n", @warnings;
}

=item htmlEscape($string)

Protect characters that would be interpreted as HTML entities using the CGI.pm
escapeHTML() routine. Then, replace line breaks with HTML "<br />" tags.

=cut

sub htmlEscape($) {
	my ($string) = @_;
	$string = encode_entities($string);
	$string =~ s|\n|<br />|g;
	return $string;
}

=back

=cut

1;

__END__

		local $SIG{__DIE__} = sub {
			my ($error) = @_;
			print STDERR "\n***** \$SIG{__DIE__} called with error: >>>>>$error<<<<<\n\n";
			
			# NEW STACK TRACE HOOK ADDED BY DPVC
			# Add traceback unless it already has been added. It looks like
			# traps are in effect from 5 or 6 places, and all of them end up here,
			# with the additional error messages already appended.
			#die $error if ref($error); # return if it's not a string
			#unless ($error =~ m/-------------\n/) {
			#	$error .= "\nCall Stack: The information below can help experts locate the source of an error which is due to WeBWorK.\n"
			#		. traceback() . "--------------------------------------\n";
			#}
			my @backtrace = backtrace();
			$r->notes(lastCallStack => \@backtrace);
			
			print STDERR "\n***** \$SIG{__DIE__} about to rethrow: >>>>>$error<<<<<\n\n";
			
			die $error;
		};
		
