package WeBWorK::ContentGenerator::API;
use Mojo::Base 'WeBWorK::ContentGenerator', -signatures;

=head1 NAME

WeBWorK::ContentGenerator::API is the base class for API requests.

=head1 Description

This is the base class for API requests.  All controller modules that handle API
requests should derive from this package.

A controller module that derives from this package must also define a C<apiCall>
method that takes a C<$command> parameter and returns the code for that command
if it is available in the module.

Note that it is expected that any API command render a valid JSON response.  If
an error occurs, then the C<errorMessage> method should be called and its result
returned.

The current packages that derive from this module and that contain API calls
executed by this module are:

    WeBWorK::ContentGenerator::API::LibraryActions;
    WeBWorK::ContentGenerator::API::SetActions;
    WeBWorK::ContentGenerator::API::CourseActions;
    WeBWorK::ContentGenerator::API::ProblemActions;

=cut

use WeBWorK::Utils::Logs qw(writeCourseLog);

use WeBWorK::ContentGenerator::API::LibraryActions;
use WeBWorK::ContentGenerator::API::SetActions;
use WeBWorK::ContentGenerator::API::CourseActions;
use WeBWorK::ContentGenerator::API::ProblemActions;

sub initializeRoute ($c, $routeCaptures) {
	$c->{rpc} = 1;

	# Get the courseID from the request parameters.
	$routeCaptures->{courseID} = $c->stash->{courseID} = $c->req->param('courseID') if $c->req->param('courseID');

	return;
}

sub go ($c) {
	return $c->renderError($c->maketext('Authentication failed. Log in again to continue.'))
		unless $c->authen->was_verified;

	writeCourseLog($c->ce, 'activity_log', $c->prepare_activity_entry)
		if $c->stash('courseID') && $c->ce->{courseFiles}{logs}{activity_log};

	my $command = $c->stash->{command};

	for my $package (
		'WeBWorK::ContentGenerator::API::LibraryActions', 'WeBWorK::ContentGenerator::API::SetActions',
		'WeBWorK::ContentGenerator::API::CourseActions',  'WeBWorK::ContentGenerator::API::ProblemActions'
		)
	{
		if (my $apiCall = $package->apiCall($command)) { return $package->new($c)->$apiCall; }
	}

	return $c->renderError("Invalid api command $command.");
}

sub renderError ($c, $errorMessage) {
	return $c->render(json => { error => $errorMessage });
}

1;
