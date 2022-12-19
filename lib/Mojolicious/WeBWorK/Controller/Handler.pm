################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2022 The WeBWorK Project, https://github.com/openwebwork
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

package Mojolicious::WeBWorK::Controller::Handler;

=head1 NAME

Mojolicious::WeBWorK::Controller::Handler - This controller dispatches
requests to the main WeBWorK dispatcher.

=cut

use Mojo::Base 'Mojolicious::Controller', -signatures, -async_await;
use HTML::Entities;
use HTML::Scrubber;
use Date::Format;
use JSON::MaybeXS;
use UUID::Tiny ':std';

async sub handler ($c) {
	my $uri = $c->req->url->path->to_string;

	my $output = '';
	$c->stash->{warnings} = '';
	my @backtrace;

	my $log = $c->log;

	my $tx = $c->render_later->tx;

	my $result = 0;

	# These can not be defined "local" below or Future::AsyncAwait will panic.
	# Instead save them and restore them later.
	my $origWarn = $SIG{__WARN__};
	my $origDie  = $SIG{__DIE__};

	eval {
		$SIG{__WARN__} = sub {
			my ($warning) = @_;
			chomp $warning;
			$c->stash->{warnings} .= "$warning\n";
			$log->warn("[$uri] $warning");
		};

		$SIG{__DIE__} = sub {
			@backtrace = backtrace();
			die @_;
		};

		# Redirect standard output to $output.
		open my $output_handle, '>>:encoding(UTF-8)', \$output or die 'Unable to open output handle';
		my $orig_output_handle = select $output_handle;

		$result = await WeBWorK::dispatch($c);

		close $output_handle;
		select $orig_output_handle;
	};

	$SIG{__WARN__} = $origWarn;
	$SIG{__DIE__}  = $origDie;

	if ($@) {
		my $exception = $@;

		my $htmlMessage;
		my $uuid = create_uuid_as_string(UUID_SHA1, UUID_NS_URL, $uri) . "::" . create_uuid_as_string(UUID_TIME);
		my $time = time2str('%a %b %d %H:%M:%S %Y', time);

		if ($c->config('MIN_HTML_ERRORS')) {
			$htmlMessage = htmlMinMessage($c, $exception, $uuid, $time);
		} else {
			$htmlMessage = htmlMessage($c, $c->stash->{warnings}, $exception, $uuid, $time, @backtrace);
		}

		# Log the error to the Mojolicious error log
		my $logMessage = '';
		if ($c->config('JSON_ERROR_LOG')) {
			$logMessage = jsonMessage($c, $c->stash->{warnings}, $exception, $uuid, $time, @backtrace);
		} else {
			$logMessage = textMessage($c, $c->stash->{warnings}, $exception, $uuid, $time, @backtrace);
		}
		$c->log->error($logMessage);

		$c->res->headers->content_type('text/html; charset=utf-8') unless $c->res->headers->content_type;
		$output = '<!DOCTYPE html>'
			. qq{<html lang="en-US"><head><title>WeBWorK error</title></head><body>$htmlMessage</body></html>};
		$result = 403;
	}

	return if $c->res->code && $c->res->code == 200;
	$c->res->body($output) unless $c->res->code;
	return $c->rendered($c->res->is_redirect ? 302 : ($result || 200));
}

=head1 ERROR HANDLING ROUTINES

=over

=item backtrace()

Produce a stack-frame traceback for the calls up through the ones in
Mojolicious::WeBWorK.

=cut

sub backtrace {
	my $frame = 2;
	my @trace;

	while (my ($pkg, $file, $line, $subname) = caller($frame++)) {
		last if $pkg eq 'Mojolicious::WeBWorK::Controller::Handler';
		push @trace, "in $subname called at line $line of $file";
	}

	return @trace;
}

=back

=head1 ERROR OUTPUT FUNCTIONS

=over

=item htmlMessage($c, $warnings, $exception, $uuid, $time, @backtrace)

Format a message for HTML output reporting an exception, backtrace, and any
associated warnings.

=cut

sub htmlMessage ($c, $warnings, $exception, $uuid, $time, @backtrace) {
	# Warnings and exceptions have html and look better scrubbed.
	my $scrubber = HTML::Scrubber->new(default => 1, script => 0, comment => 0);
	$scrubber->default(undef, { '*' => 1 });

	$warnings  = $scrubber->scrub($warnings);
	$exception = $scrubber->scrub($exception);

	my @warnings = defined $warnings ? split m|<br />|, $warnings : ();    # fragile
	$warnings = htmlWarningsList(@warnings);
	my $backtrace = htmlBacktrace(@backtrace);

	# $ENV{WEBWORK_SERVER_ADMIN} is set from $webwork_server_admin_email in site.conf.
	$ENV{WEBWORK_SERVER_ADMIN} = $ENV{WEBWORK_SERVER_ADMIN} // '';

	my $admin =
		$ENV{WEBWORK_SERVER_ADMIN}
		? qq{(<a href="mailto:$ENV{WEBWORK_SERVER_ADMIN}">$ENV{WEBWORK_SERVER_ADMIN}</a>)}
		: '';
	my $method  = htmlEscape($c->req->method);
	my $uri     = htmlEscape($c->req->url->to_abs->to_string);
	my $headers = do {
		my %headers = %{ $c->req->headers->to_hash };
		if (defined($headers{'sec-ch-ua'})) {
			# Was getting warnings about the value of 'sec-ch-ua' in my testing...
			$headers{'sec-ch-ua'} = join('', $headers{'sec-ch-ua'});
			$headers{'sec-ch-ua'} =~ s/\"//g;
		}

		join(
			'',
			qq{<tr><th id="header_key"><small>Key</small></th><th id="header_value"><small>Value</small></th></tr>},
			map {
				qq{<tr><td headers="header_key"><small>}
					. htmlEscape($_)
					. qq{</small></td><td headers="header_value"><small>}
					. htmlEscape($headers{$_})
					. '</small></td></tr>'
			} keys %headers
		);
	};

	return <<EOF;
<main>
	<div style="text-align:left">
		<h1>WeBWorK error</h1>
		<p>An error occured while processing your request.</p>
		<p>
			For help, please send mail to this site's webmaster $admin, including all of the following
			information as well as what what you were doing when the error occured.
		</p>
		<h2>Error record identifier</h2>
		<p style="margin-left: 2em; color: #dc2a2a"><code>$uuid</code></p>
		<h2>Warning messages</h2>
		<ul>$warnings</ul>
		<h2>Error messages</h2>
		<p style="margin-left: 2em; color: #dc2a2a"><code>$exception</code></p>
		<h2>Call stack</h2>
			<p>The following information can help locate the source of the problem.</p>
			<ul>$backtrace</ul>
		<h2>Request information</h2>
		<div>
			<p>The HTTP request information is included in the following table.</p>
			<div class="table-responsive">
				<table class="table table-bordered caption-top" border="1" aria-labelledby="req_info_summary1">
					<caption id="req_info_summary1">HTTP request information</caption>
					<tr><th id="outer_item">Item</th><th id="outer_data">Data</th></tr>
					<tr><td headers="outer_item">Method</td><td headers="outer_data">$method</td></tr>
					<tr><td headers="outer_item">URI</td><td headers="outer_data">$uri</td></tr>
					<tr>
						<td headers="outer_item">HTTP Headers</td>
						<td headers="outer_data">
							<table class="table table-bordered caption-top" aria-labelledby="req_header_summary">
								<caption id="req_header_summary">HTTP request headers</caption>
								$headers
							</table>
						</td>
					</tr>
				</table>
			</div>
		</div>
		<h2>Time generated:</h2>
		<p style="margin-left: 2em;">$time</p>
	</div>
</main>
EOF
}

=item htmlMinMessage($c, $exception, $uuid, $time)

Format a minimal message for HTML output reporting an error ID number, and NOT providing much
additional data, which will instead be in the log files.

=cut

sub htmlMinMessage ($c, $exception, $uuid, $time) {
	# Exceptions have html and look better scrubbed.
	my $scrubber = HTML::Scrubber->new(default => 1, script => 0, comment => 0);
	$scrubber->default(undef, { '*' => 1 });

	$exception = $scrubber->scrub($exception);

	# Drop any code reference from the error message
	$exception =~ s/ at \/.*//;

	# $ENV{WEBWORK_SERVER_ADMIN} is set from $webwork_server_admin_email in site.conf.
	$ENV{WEBWORK_SERVER_ADMIN} = $ENV{WEBWORK_SERVER_ADMIN} // '';

	my $admin =
		$ENV{WEBWORK_SERVER_ADMIN}
		? qq{(<a href="mailto:$ENV{WEBWORK_SERVER_ADMIN}">$ENV{WEBWORK_SERVER_ADMIN}</a>)}
		: '';

	return <<EOF;
<main>
	<div style="text-align:left">
		<h1>WeBWorK error</h1>
		<p>An error occured while processing your request.</p>
		<p>
			For help, please send mail to this site's webmaster $admin, including all of the following
			information as well as what what you were doing when the error occured.
		</p>
		<h2>Error record identifier</h2>
		<p style="margin-left: 5em; color: #dc2a2a"><code>$uuid</code></p>
		<h2>Error messages</h2>
		<p style="margin-left: 5em; color: #dc2a2a"><code>$exception</code></p>
		<h2>Time generated:</h2>
		<p style="margin-left: 5em;">$time</p>
	</div>
</main>
EOF
}

=item textMessage($c, $warnings, $exception, $uuid, $time, @backtrace)

Format a message for HTML output reporting an exception, backtrace, and any
associated warnings.

=cut

sub textMessage ($c, $warnings, $exception, $uuid, $time, @backtrace) {
	chomp $exception;
	my $backtrace = textBacktrace(@backtrace);
	my $uri       = $c->req->url->to_abs->to_string;

	my @warnings = defined $warnings ? split m/\n+/, $warnings : ();

	my %headers = %{ $c->req->headers->to_hash };
	# Was getting JSON errors for the value of 'sec-ch-ua' in my testing, so remove it
	if (defined($headers{'sec-ch-ua'})) {
		$headers{'sec-ch-ua'} = join('', $headers{'sec-ch-ua'});
		$headers{'sec-ch-ua'} =~ s/\"//g;
	}

	my $additional_json = encode_json({
		'Error record identifier' => $uuid,
		Time                      => $time,
		Method                    => $c->req->method,
		URI                       => $uri,
		'HTTP Headers'            => {%headers},
		Warnings                  => [@warnings],
	});

	return "[$uuid] [$uri] $additional_json $exception\n$backtrace";
}

=item jsonMessage($c, $warnings, $exception, $uuid, $time, @backtrace)

Format a JSON message for log output reporting an exception, backtrace, and any
associated warnings.

=cut

sub jsonMessage ($c, $warnings, $exception, $uuid, $time, @backtrace) {
	chomp $exception;
	my @warnings = defined $warnings ? split m/\n+/, $warnings : ();

	my %headers = %{ $c->req->headers->to_hash };
	# Was getting JSON errors for the value of 'sec-ch-ua' in my testing, so remove it
	if (defined($headers{'sec-ch-ua'})) {
		$headers{'sec-ch-ua'} = join('', $headers{'sec-ch-ua'});
		$headers{'sec-ch-ua'} =~ s/\"//g;
	}

	return encode_json({
		'Error record identifier' => $uuid,
		Time                      => $time,
		Method                    => $c->req->method,
		URI                       => $c->req->url->to_abs->to_string,
		'HTTP Headers'            => {%headers},
		Warnings                  => [@warnings],
		Exception                 => $exception,
		Backtrace                 => [@backtrace],
	});
}

=item htmlBacktrace(@frames)

Formats a list of stack frames in a backtrace as list items for HTML output.

=cut

sub htmlBacktrace (@frames) {
	for my $frame (@frames) {
		$frame = htmlEscape($frame);
		$frame = "<li><code>$frame</code></li>";
	}
	return join '', @frames;
}

=item textBacktrace(@frames)

Formats a list of stack frames in a backtrace as list items for text output.

=cut

sub textBacktrace (@frames) {
	for my $frame (@frames) {
		$frame = " * $frame";
	}
	return join "\n", @frames;
}

=item htmlWarningsList(@warnings)

Formats a list of warning strings as list items for HTML output.

=cut

sub htmlWarningsList (@warnings) {
	for my $warning (@warnings) {
		$warning = "<li><code>$warning</code></li>";
	}
	return join '', @warnings;
}

=item textWarningsList(@warnings)

Formats a list of warning strings as list items for text output.

=cut

sub textWarningsList (@warnings) {
	for my $warning (@warnings) {
		$warning = " * $warning";
	}
	return join "\n", @warnings;
}

=item htmlEscape($string)

Protect characters that would be interpreted as HTML entities. Then, replace
line breaks with HTML "<br />" tags.

=cut

sub htmlEscape ($string) {
	return encode_entities($string // '') =~ s|\n|<br />|gr;
}

=back

=cut

1;
