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

package WeBWorK::ContentGenerator::InstructorRPCHandler;
use base qw(WeBWorK::ContentGenerator);

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

use strict;
use warnings;

use Future::AsyncAwait;
use JSON;

use WebworkWebservice;

async sub pre_header_initialize {
	my $self = shift;
	my $r    = $self->r;

	my $input = { map { $_ => $r->param($_) } $r->param };
	delete $input->{user};
	$input->{userID} = $r->param('user') || undef;

	my $rpc_command = $r->param('rpc_command');

	if (!$rpc_command) {
		$self->{output} = 'instructor_rpc: rpc_command not provided.';
		return;
	}

	# Call the WebworkWebservice to execute the requested command and store the result in $self->{return_object}.
	# The renderProblem command is not supported by this method.  The render_rpc endpoint should be used for that
	# instead.
	if ($rpc_command eq 'renderProblem') {
		$self->{output} =
			'instructor_rpc: The renderProblem command is not supported by this endpoint. Use render_rpc instead';
		return;
	}

	$input->{path} = $r->param('problemPath') if ($rpc_command eq "addProblem" || $rpc_command eq "deleteProblem");

	# Setup the rpc client and execute the requested command.
	my $rpc_service = WebworkWebservice->new(courseID => $r->param('courseID'), inputs_ref => $input);
	await $rpc_service->rpc_execute($rpc_command);
	$self->{output} = $rpc_service;

	return;
}

async sub content {
	my $self = shift;

	# This endpoint always responds with a valid JSON response.
	$self->r->res->headers->content_type('application/json; charset=utf-8');

	if (ref($self->{output}) !~ /WebworkWebservice/) {
		print JSON->new->utf8->encode({ error => $self->{output} });
		return;
	}

	my $rpc_service = $self->{output};
	if ($rpc_service->error_string) {
		print JSON->new->utf8->encode({ error => $rpc_service->error_string });
	} else {
		print JSON->new->utf8->encode({
			server_response => $rpc_service->return_object->{text},
			result_data     => $rpc_service->return_object->{ra_out} // ''
		});
	}
	return;
}

1;
