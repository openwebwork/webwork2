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

package WeBWorK;
use Mojo::Base -signatures, -async_await;

=head1 NAME

WeBWorK - Check authentication and initialize the course environment for a
content generator controller action.

=head1 SYNOPSIS

 my $result = eval { await WeBWorK::dispatch($c) };
 die "something bad happened: $@" if $@;

=head1 DESCRIPTION

C<WeBWorK> is the content generator initializer for the WeBWorK system. It
performs authentication and initializes the course environment.  If
authentication is needed, then it renders the WeBWorK::ContentGenerator::Login
module.  If proctor authentication is needed, then it renders the
WeBWorK::ContentGenerator::LoginProctor module.  Otherwise it returns control to
the action of the content generator module for the designated route.

=cut

use Time::HiRes qw/time/;

use WeBWorK::Localize;
use WeBWorK::Authen;
use WeBWorK::Authz;
use WeBWorK::CourseEnvironment;
use WeBWorK::DB;
use WeBWorK::Debug;
use WeBWorK::Upload;
use WeBWorK::Utils qw(runtime_use);
use WeBWorK::ContentGenerator::Login;
use WeBWorK::ContentGenerator::TwoFactorAuthentication;
use WeBWorK::ContentGenerator::LoginProctor;

our %SeedCE;

# This will either return 0 or 1.  If it returns 1, then the around_action hook will render the content generator module
# for the path.  If it returns 0, then it either must render (login or proctor login) or it must also return a message
# indicating why it didn't render.  This can also throw an exception in which case the around_action hook will render
# the exception template.
async sub dispatch ($c) {
	# Cache the initial submission time.  This can be used at any point throughout processing of this request.
	# Note that this is Time::HiRes's time, which gives floating point values.
	$c->submitTime(time);

	my $method   = $c->req->method;
	my $location = $c->location;
	my $uri      = $c->url_for;
	my $args     = $c->req->params->to_string || '';

	debug("\n\n===> Begin " . __PACKAGE__ . "::dispatch() <===\n\n");
	debug("Hi, I'm the new dispatcher!\n");
	debug(("-" x 80) . "\n");

	debug("Okay, I got some basic information:\n");
	debug("The site location is $location\n");
	debug("The request method is $method\n");
	debug("The URI is $uri\n");
	debug("The argument string is $args\n");
	debug(('-' x 80) . "\n");

	my ($path) = $uri =~ m/$location(.*)/;
	$path .= '/' if $path !~ m(/$);
	debug("The path is $path\n");

	debug("The current route is " . $c->current_route . "\n");
	debug("Here is some information about this route:\n");

	my $displayModule = ref $c;
	my %routeCaptures = %{ $c->stash->{'mojo.captures'} };

	debug("The display module for this route is $displayModule\n");
	debug("This route has the following captures:\n");
	for my $key (keys %routeCaptures) {
		debug("\t$key => $routeCaptures{$key}\n");
	}

	debug(('-' x 80) . "\n");

	debug("Now we want to look at the parameters we got.\n");

	debug("The raw params:\n");
	for my $key ($c->param) {
		# Make it so we dont debug plain text passwords
		my $vals;
		if ($key eq 'passwd'
			|| $key eq 'confirmPassword'
			|| $key eq 'currPassword'
			|| $key eq 'newPassword'
			|| $key =~ /\.new_password/)
		{
			$vals = '**********';
		} else {
			my @vals = $c->param($key);
			$vals = join(', ', map {qq{"$_"}} @vals);
		}
		debug("\t$key => $vals\n");
	}

	debug(('-' x 80) . "\n");

	# A controller can customize route captures, parameters, and stash values if it provides an initializeRoute method.
	$c->initializeRoute(\%routeCaptures) if $c->can('initializeRoute');

	# Create Course Environment
	debug("We need to get a course environment (with or without a courseID!)\n");
	my $ce = eval { WeBWorK::CourseEnvironment->new({ courseName => $routeCaptures{courseID} }) };
	$@ and die "Failed to initialize course environment: $@\n";
	debug("Here's the course environment: $ce\n");
	$c->ce($ce);

	# Localization
	my $language = $ce->{language} || 'en';
	$c->language_handle(WeBWorK::Localize::getLoc($language));

	my @uploads = @{ $c->req->uploads };

	foreach my $u (@uploads) {
		# Make sure it's a "real" upload.
		next unless $u->filename;

		# Store the upload.
		my $upload = WeBWorK::Upload->store($u, dir => $ce->{webworkDirs}{uploadCache});

		# Store the upload ID and hash in the file upload field.
		my $id   = $upload->id;
		my $hash = $upload->hash;
		$c->param($u->name => "$id $hash");
	}

	# Create these out here. They should fail if they don't have the right information.
	# This lets us not be so careful about whether these objects are defined when we use them.
	# Instead, we just create the behavior that if they don't have a valid $db they fail.
	my $authz = WeBWorK::Authz->new($c);
	$c->authz($authz);

	my $user_authen_module = WeBWorK::Authen::class($ce, 'user_module');

	runtime_use $user_authen_module;
	my $authen = $user_authen_module->new($c);
	debug("Using user_authen_module $user_authen_module: $authen\n");
	$c->authen($authen);

	if ($routeCaptures{courseID}) {
		debug("We got a courseID from the route, now we can do some stuff:\n");

		return (0, 'This course does not exist.')
			unless (-e $ce->{courseDirs}{root}
				|| -e "$ce->{webwork_courses_dir}/$ce->{admin_course_id}/archives/$routeCaptures{courseID}.tar.gz");
		return (0, 'This course has been archived and closed.') unless -e $ce->{courseDirs}{root};

		debug("...we can create a database object...\n");
		my $db = WeBWorK::DB->new($ce->{dbLayout});
		debug("(here's the DB handle: $db)\n");
		$c->db($db);

		if ($authen->verify) {
			# If this is the first phase of LTI 1.3 authentication, then return so its special content generator
			# module will render and submit the login repost form.  This does not contain the neccessary information
			# to continue here.
			return 1 if $c->current_route eq 'ltiadvantage_login';

			my $userID = $c->param('user');
			debug("Hi, $userID, glad you made it.\n");

			# Tell authorizer to cache this user's permission level
			$authz->setCachedUser($userID);

			debug("Now we deal with the effective user:\n");
			my $eUserID = $c->param('effectiveUser') || $userID;
			debug("userID=$userID eUserID=$eUserID\n");
			if ($userID ne $eUserID) {
				debug("userID and eUserID differ... seeing if userID has 'become_student' permission.\n");
				my $su_authorized = $authz->hasPermissions($userID, 'become_student');
				if ($su_authorized) {
					debug("Ok, looks like you're allowed to become $eUserID. Whoopie!\n");
				} else {
					debug("Uh oh, you're not allowed to become $eUserID. Nice try!\n");
					return (0,
						"You do not have permission to act as another user.\n"
							. 'Close down your browser (this clears temporary cookies), restart and try again.');
				}
			}

			# Set effectiveUser in case it was changed or not set to begin with.
			$c->param('effectiveUser' => $eUserID);

			# If this is a proctored test, then after the user has been authenticated
			# we need to also check on the proctor.  Note that in the gateway quiz
			# module this is double checked to be sure that someone isn't taking a
			# proctored quiz but calling the unproctored ContentGenerator.
			if ($c->current_route =~ /^(proctored_gateway_quiz|proctored_gateway_proctor_login)$/) {
				my $proctor_authen_module = WeBWorK::Authen::class($ce, 'proctor_module');
				runtime_use $proctor_authen_module;
				my $authenProctor = $proctor_authen_module->new($c);
				debug("Using proctor_authen_module $proctor_authen_module: $authenProctor\n");
				my $procAuthOK = $authenProctor->verify();

				if (!$procAuthOK) {
					await WeBWorK::ContentGenerator::LoginProctor->new($c)->go;
					return 0;
				}
			} else {
				# If any other page is opened, then revoke proctor authorization if it has been granted.
				# Otherwise the student will be able to re-enter the test without again obtaining proctor authorization.
				delete $c->authen->session->{proctor_authorization_granted};
			}
			return 1;
		} else {
			# For a remote procedure call continue on to the original display module.
			# It will give the authentication failure response.
			return 1 if $c->{rpc};

			# If the user is logging out and authentication failed, still logout.
			return 1 if $displayModule eq 'WeBWorK::ContentGenerator::Logout';

			if ($c->authen->session->{two_factor_verification_needed}) {
				debug("Login succeeded but two factor authentication is needed.\n");
				debug("Rendering WeBWorK::ContentGenerator::TwoFactorAuthentication\n");
				await WeBWorK::ContentGenerator::TwoFactorAuthentication->new($c)->go();
			} else {
				debug("Bad news: authentication failed!\n");
				debug("Rendering WeBWorK::ContentGenerator::Login\n");
				await WeBWorK::ContentGenerator::Login->new($c)->go();
			}
			return 0;
		}
	} else {
		return (0,
			'No WeBWorK course was found associated to this LMS course. '
				. 'If this is an error, please contact the WeBWorK system administrator.')
			if $c->current_route eq 'ltiadvantage_login';
	}

	return 1;
}

1;
