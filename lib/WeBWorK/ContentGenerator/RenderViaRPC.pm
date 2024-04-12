################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2023 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::RenderViaRPC;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator::RenderViaRPC - This is a content generator that
processes requests for problem rendering via remote procedure calls to the
webwork webservice.

=head1 Description

Receives WeBWorK requests presented as HTML forms, containing the requisite
information for rendering a problem.  This package checks that authentication
succeeded, calls WebworkWebservice::RenderProblem::renderProblem, and then
passes its return value to FormatRenderedProblem::formatRenderedProblem.  The
result is returned in the JSON or HTML format as determined by the request type.

=cut

use WebworkWebservice;

sub initializeRoute ($c, $routeCaptures) {
	$c->{rpc} = 1;

	$c->stash(disable_cookies => 1)
		if $c->current_route eq 'render_rpc' && $c->param('disableCookies') && $c->config('allow_unsecured_rpc');

	# This provides compatibility for legacy html2xml parameters.
	# This should be deleted when the html2xml endpoint is removed.
	if ($c->current_route eq 'html2xml') {
		$c->stash(disable_cookies => 1) if $c->config('allow_unsecured_rpc');
		for ([ 'userID', 'user' ], [ 'course_password', 'passwd' ], [ 'session_key', 'key' ]) {
			$c->param($_->[1], $c->param($_->[0])) if defined $c->param($_->[0]) && !defined $c->param($_->[1]);
		}
	}

	# Get the courseID from the parameters.
	$routeCaptures->{courseID} = $c->stash->{courseID} = $c->param('courseID') if $c->param('courseID');

	return;
}

async sub pre_header_initialize ($c) {
	$c->{wantsjson} = ($c->param('outputformat') // '') eq 'json' || ($c->param('send_pg_flags') // 0);

	unless ($c->authen->was_verified) {
		$c->{output} =
			$c->{wantsjson}
			? { error => $c->maketext('Authentication failed. Log in again to continue.') }
			: $c->maketext('Authentication failed. Log in again to continue.');
		return;
	}

	$c->param('displayMode', 'tex')
		if $c->param('outputformat') && ($c->param('outputformat') eq 'pdf' || $c->param('outputformat') eq 'tex');

	# Call the WebworkWebservice to render the problem and store the result in $c->return_object.
	my $rpc_service = WebworkWebservice->new($c);
	await $rpc_service->rpc_execute('renderProblem');
	if ($rpc_service->error_string) {
		$c->{output} = $c->{wantsjson} ? { error => $rpc_service->error_string } : $rpc_service->error_string;
		return;
	}

	# Format the return in the requested format.  A response is rendered unless there is an error.
	$c->{output} = $rpc_service->formatRenderedProblem;

	return;
}

sub content ($c) {
	# If there were no errors a response will have been rendered.  Return in that case.
	return if $c->res->code;

	# Handle rendering of errors.
	return $c->render(json => $c->{output}) if $c->{wantsjson};
	return $c->render(text => $c->{output});
}

1;
