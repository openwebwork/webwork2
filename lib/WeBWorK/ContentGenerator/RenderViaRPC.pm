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

package WeBWorK::ContentGenerator::RenderViaRPC;
use parent qw(WeBWorK::ContentGenerator);

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

use strict;
use warnings;

use Future::AsyncAwait;

use WebworkWebservice;

async sub pre_header_initialize {
	my $self = shift;
	my $r    = $self->r;

	$self->{wantsjson} = ($r->param('outputformat') // '') eq 'json' || ($r->param('send_pg_flags') // 0);

	unless ($r->authen->was_verified) {
		$self->{output} =
			$self->{wantsjson}
			? { error => 'render_rpc: authentication failed.' }
			: 'render_rpc: authentication failed.';
		return;
	}

	$r->param('displayMode', 'tex') if ($r->param('outputformat') eq 'pdf' || $r->param('outputformat') eq 'tex');

	# Call the WebworkWebservice to render the problem and store the result in $self->return_object.
	my $rpc_service = WebworkWebservice->new($r);
	await $rpc_service->rpc_execute('renderProblem');
	if ($rpc_service->error_string) {
		$self->{output} = $self->{wantsjson} ? { error => $rpc_service->error_string } : $rpc_service->error_string;
		return;
	}

	# Format the return in the requested format.  A response is rendered unless there is an error.
	$self->{output} = $rpc_service->formatRenderedProblem;

	return;
}

sub content {
	my $self = shift;

	# If there were no errors a response will have been rendered.  Return in that case.
	return if $self->r->res->code;

	# Handle rendering of errors.
	return $self->r->render(json => $self->{output}) if $self->{wantsjson};
	return $self->r->render(text => $self->{output});
}

1;
