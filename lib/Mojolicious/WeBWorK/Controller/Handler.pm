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

use Mojo::Base 'WeBWorK::Request', -signatures, -async_await;
use JSON::MaybeXS;

async sub handler ($c) {
	my $uri = $c->req->url->path->to_string;

	$c->stash->{warnings} = '';

	my $tx = $c->render_later->tx;

	# This can not be defined "local" below or Future::AsyncAwait will panic.
	# Instead save the warning handler and restore it later.
	my $origWarn = $SIG{__WARN__};

	$SIG{__WARN__} = sub {
		my ($warning) = @_;
		chomp $warning;
		$c->stash->{warnings} .= "$warning\n";
		$c->log->warn("[$uri] $warning");
	};

	await WeBWorK::dispatch($c);

	$SIG{__WARN__} = $origWarn;

	return;
}

=head1 ERROR OUTPUT FUNCTIONS

=over

=item textMessage($c, $exception, $uuid, $time)

Format a message for HTML output reporting an exception and any
associated warnings.

=cut

sub textMessage ($c, $uuid, $time) {
	my $uri = $c->req->url->to_abs->to_string;

	my $exception = $c->stash->{exception} // '';

	my %headers = %{ $c->req->headers->to_hash };
	# Avoid JSON errors for the value of 'sec-ch-ua'.
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
		Warnings                  => [ defined $c->stash->{warnings} ? split m/\n+/, $c->stash->{warnings} : () ],
	});

	return "[$uuid] [$uri] $additional_json $exception";
}

=item jsonMessage($c, $uuid, $time)

Format a JSON message for log output reporting an exception and any
associated warnings.

=cut

sub jsonMessage ($c, $uuid, $time) {
	my %headers = %{ $c->req->headers->to_hash };
	# Avoid JSON errors for the value of 'sec-ch-ua'.
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
		Warnings                  => [ defined $c->stash->{warnings} ? split m/\n+/, $c->stash->{warnings} : () ],
		Exception                 => $c->stash->{exception} ? $c->stash->{exception}->to_string : ''
	});
}

=back

=cut

1;
