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
 	<Location /webwork>
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

# CGI::Carp makes pretty log and browser error messages. It should be loaded as
# early as is possible.
BEGIN {
	use CGI::Carp qw(fatalsToBrowser set_message);
	# CGI::Carp needs a little patch to make it work with the "vanilla"
	# mod_perl API (as opposed to Apache::Registry). _longmess is supposed
	# to filter out evals that are always there, as a result of being run
	# under mod_perl. Under the "vanilla" API, the first stack frame is
	# "eval {...} called at /dev/null line 0". This needs to be removed.
	# 
	# [later:]
	# 
	# Ok, so apparently, when a die happens during compilation, the first
	# stack frame is the following:
	# 
	# 	eval 'require Apache::WeBWorK
	# 	;' called at /path/to/lib/Apache/WeBWorK.pm line 0
	# 
	# So I'll try to handle that too.
	sub CGI::Carp::_longmess {
		my $message = Carp::longmess();
		if (exists $ENV{MOD_PERL}) {
			$message =~ s,eval[^\n]+Apache/Registry\.pm.*,,s;
			$message =~ s,eval[^\n]+/dev/null line 0.*,,s;
			my $pkg = __PACKAGE__;
			$message =~ s/eval 'require $pkg\n.*//s;
		}
		
		return $message;
	}
	# Much of this is stolen from &CGI::Carp::fatalsToBrowser;
	my $customErrorMessage = sub {
		my ($message) = @_;
		my $stack = Carp::longmess();
		my $wm = ($ENV{SERVER_ADMIN} 
			? qq[the webmaster (<a href="mailto:$ENV{SERVER_ADMIN}">$ENV{SERVER_ADMIN}</a>)]
			: "this site's webmaster");
		my $mess = <<EOF;
<html><head><title>WeBWorK - Software Error</title></head><body> <h2>WeBWorK -
Software Error</h2><h3>Error message</h3><blockquote><pre>$message</pre>
</blockquote><h3>Error context</h3><blockquote><pre>$stack</pre></blockquote>
<p>For help, please send mail to $wm, giving this error message and the time
and date of the error.</p></body></html>
EOF
		if (exists $ENV{MOD_PERL} && (my $r = Apache->request)) {
			# If bytes have already been sent, then we print the
			# message out directly. Otherwise we make a custom
			# error handler to produce the doc for us.
			if ($r->bytes_sent) {
				$r->print($mess);
				$r->exit;
			} else {
				$r->status(500);
				$r->custom_response(500,$mess);
			}
		} else {
			print STDOUT $mess;
		}
	};
	set_message($customErrorMessage);
}

use WeBWorK;

sub handler($) {
	my ($apache) = @_;
	
	return WeBWorK::dispatch($apache);
}

1;
