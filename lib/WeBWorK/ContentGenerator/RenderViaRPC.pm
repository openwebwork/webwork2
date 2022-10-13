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
use base qw(WeBWorK::ContentGenerator);

=head1 NAME

WeBWorK::ContentGenerator::RenderViaRPC - This is a content generator that
processes requests for problem rendering via remote procedure calls to the
webwork webservice.

=head1 Description

Receives WeBWorK requests presented as HTML forms, containing the requisite
information for rendering a problem.  This package does some munging of the
parameters and calls WebworkWebservice::RenderProblem::renderProblem and then
passes its return value to FormatRenderedProblem::formatRenderedProblem.  The
result is returned in the JSON or HTML format as determined by the request type.

=cut

use strict;
use warnings;

use Future::AsyncAwait;
use JSON;

use WebworkWebservice;

async sub pre_header_initialize {
	my $self = shift;
	my $r    = $self->r;

	# Note: Vars helps handle things like checkbox 'packed' data;
	my %inputs_ref = WeBWorK::Form->new_from_paramable($r)->Vars;

	# When passing parameters via an LMS you get "custom_" put in front of them. So try to clean that up.
	$inputs_ref{userID}           = $inputs_ref{custom_userid}           if $inputs_ref{custom_userid};
	$inputs_ref{courseID}         = $inputs_ref{custom_courseid}         if $inputs_ref{custom_courseid};
	$inputs_ref{displayMode}      = $inputs_ref{custom_displaymode}      if $inputs_ref{custom_displaymode};
	$inputs_ref{course_password}  = $inputs_ref{custom_course_password}  if $inputs_ref{custom_course_password};
	$inputs_ref{answersSubmitted} = $inputs_ref{custom_answerssubmitted} if $inputs_ref{custom_answerssubmitted};
	$inputs_ref{problemSeed}      = $inputs_ref{custom_problemseed}      if $inputs_ref{custom_problemseed};
	$inputs_ref{sourceFilePath}   = $inputs_ref{custom_sourcefilepath}   if $inputs_ref{custom_sourcefilepath};
	$inputs_ref{outputformat}     = $inputs_ref{custom_outputformat}     if $inputs_ref{custom_outputformat};

	$self->{wantsjson} = $inputs_ref{outputformat} eq 'json' || ($inputs_ref{send_pg_flags} // 0);

	# A course and user are required.
	unless ($inputs_ref{userID} && $inputs_ref{courseID}) {
		$self->{output} =
			$self->{wantsjson}
			? JSON->new->utf8->encode({ error => 'Missing essential data in web dataform' })
			: 'render_rpc: Missing essential data in web dataform';
		return;
	}

	# Set defaults for these if not defined.
	$inputs_ref{displayMode} //= 'MathJax';
	$inputs_ref{problemSeed} //= '1234';

	my $site_url = $r->server_root_url;

	# Setup the rpc client
	my $rpc_service = WebworkWebservice->new(
		site_url        => $site_url,
		form_action_url => $site_url . $r->webwork_url . '/render_rpc',
		inputs_ref      => \%inputs_ref,
		userID          => $inputs_ref{userID},
		course_password => $inputs_ref{course_password},
		session_key     => $inputs_ref{session_key},
		courseID        => $inputs_ref{courseID},
		outputformat    => $inputs_ref{outputformat},
		sourceFilePath  => $inputs_ref{sourceFilePath},
		encoded_source  => $r->param('problemSource') // undef,
	);

	# Call the WebworkWebservice to render the problem and store the result in $self->return_object.
	await $rpc_service->rpc_execute('renderProblem');
	if ($rpc_service->error_string) {
		warn $rpc_service->error_string;
		$self->{output} =
			$self->{wantsjson}
			? JSON->new->utf8->encode({ error => $rpc_service->error_string })
			: $rpc_service->error_string;
		return;
	}

	# Format the return in the requested format.
	$self->{output} = $rpc_service->formatRenderedProblem;
	return;
}

async sub content {
	my $self = shift;
	$self->r->res->headers->content_type(($self->{wantsjson} ? 'application/json;' : 'text/html;') . ' charset=utf-8');
	print $self->{output};
	return 0;
}

1;
