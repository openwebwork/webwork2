################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2024 The WeBWorK Project, https://github.com/openwebwork
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

package WeBWorK::ContentGenerator::InstructorRPCHandler;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures, -async_await;

=head1 NAME

WeBWorK::ContentGenerator::InstructorRPCHandler is a front end for instructor
calls to the rpc WebworkWebservice

=head1 Description

Receives requests containing WebworkWebservice remote procedure call commands,
executes them, and returns the resutls.

Note that the WebworkWebservice renderProblem command is not supported by this
endpoint.  The render_rpc endpoint defined in the
WeBWorK::ContentGenerator::RenderViaRPC module handles that command.

Note that there will always be a valid JSON response to this endpoint.  If an
error occurs, then the response will contain an "error" key.

=cut

use JSON;

use WebworkWebservice;

sub initializeRoute ($c, $routeCaptures) {
	$c->{rpc} = 1;

	# Get the courseID from the parameters.
	$routeCaptures->{courseID} = $c->stash->{courseID} = $c->param('courseID') if $c->param('courseID');

	return;
}

async sub pre_header_initialize ($c) {
	unless ($c->authen->was_verified) {
		$c->{output} = $c->maketext('Authentication failed. Log in again to continue.');
		return;
	}

	my $rpc_command = $c->param('rpc_command');

	unless ($rpc_command) {
		$c->{output} = 'instructor_rpc: rpc_command not provided.';
		return;
	}

	# The renderProblem command is not supported by this method.
	# The render_rpc endpoint should be used for that instead.
	if ($rpc_command eq 'renderProblem') {
		$c->{output} =
			'instructor_rpc: The renderProblem command is not supported by this endpoint. Use render_rpc instead';
		return;
	}

	# Call the WebworkWebservice to execute the requested command.
	my $rpc_service = WebworkWebservice->new($c);
	await $rpc_service->rpc_execute($rpc_command);
	$c->{output} = $rpc_service;

	return;
}

sub content ($c) {
	# This endpoint always responds with a valid JSON response.

	return $c->render(json => { error => $c->{output} }) if (ref($c->{output}) !~ /WebworkWebservice/);

	my $rpc_service = $c->{output};
	if ($rpc_service->error_string) {
		return $c->render(json => { error => $rpc_service->error_string });
	} else {
		return $c->render(
			json => {
				server_response => $rpc_service->return_object->{text},
				result_data     => $rpc_service->return_object->{ra_out} // ''
			}
		);
	}
}

1;
