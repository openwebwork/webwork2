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

package WebworkWebservice;

=head1 NAME

WebworkWebservice

=head1 SYNPOSIS

    my $rpc_service = WebworkWebservice->new(inputs_ref => $input);
    await $rpc_service->rpc_execute('command_to_execute');

For example to render a problem with the renderProblem:

    my $rpc_service = WebworkWebservice->new(
        inputs_ref      => $inputs_ref
        encoded_source  => $encodedSource,
        site_url        => $site_url,
        form_action_url => $form_action_url,
        userID          => $userID,
        course_password => $course_password,
        session_key     => $session_key,
        courseID        => $courseID,
        outputformat    => $outputformat,
        sourceFilePath  => $sourceFilePath,
    );

    await $rpc_service->rpc_execute('renderProblem')
    my $renderedProblem = $rpc_service->formatRenderedProblem;

=head1 DESCRIPTION

The WebworkWebservice object receives a webservice request.  With the help of
FakeRequest it authenticates and authorizes the request and then dispatches it
to the appropriate WebworkWebservice subroutine to respond.

The webservice request methods are available are in the following modules:

    WebworkWebservice::RenderProblem;
    WebworkWebservice::LibraryActions;
    WebworkWebservice::SetActions;
    WebworkWebservice::CourseActions;
    WebworkWebservice::ProblemActions

Note that WebworkWebservice contains the formatRenderedProblem method for
formatting the reply returned by the renderProblem command.

Also note that the WeBWorK::ContentGenerator::RenderViaRPC module implements the
renderProblem command, and the WeBWorK::ContentGenerator::InstructorPRCHandler
module has implements all other commands.

=cut

use strict;
use warnings;

use Future::AsyncAwait;
use JSON;

use WeBWorK::FakeRequest;
use WeBWorK::Localize;
use WeBWorK::CourseEnvironment;
use WebworkWebservice::RenderProblem;
use WebworkWebservice::LibraryActions;
use WebworkWebservice::SetActions;
use WebworkWebservice::CourseActions;
use WebworkWebservice::ProblemActions;
use FormatRenderedProblem;

=head2 new (constructor)

=cut

sub new {
	my ($invocant, %options) = @_;
	my $class = ref $invocant || $invocant;
	return bless {
		return_object  => {},
		request_object => {},
		error_string   => '',
		inputs_ref     => {},
		%options,
	}, $class;
}

=head2 Accessor methods

    encoded_source
    request_object
    return_object
    error_string
    site_url
    form_data

=cut

sub encoded_source {
	my $self   = shift;
	my $source = shift;
	$self->{encoded_source} = $source if defined $source and $source =~ /\S/;
	return $self->{encoded_source};
}

sub request_object {
	my $self   = shift;
	my $object = shift;
	$self->{request_object} = $object if defined $object and ref($object);
	return $self->{request_object};
}

sub return_object {
	my $self   = shift;
	my $object = shift;
	$self->{return_object} = $object if defined $object and ref($object);
	return $self->{return_object};
}

sub error_string {
	my $self   = shift;
	my $string = shift;
	$self->{error_string} = $string if defined $string and $string =~ /\S/;
	return $self->{error_string};
}

sub site_url {
	my $self    = shift;
	my $new_url = shift;
	$self->{site_url} = $new_url if defined($new_url) and $new_url =~ /\S/;
	return $self->{site_url};
}

=head2 default_inputs

initialize default values

=cut

sub default_inputs {
	my $self = shift;

	my $webwork_dir = $WeBWorK::Constants::WEBWORK_DIRECTORY;
	my $seed_ce     = WeBWorK::CourseEnvironment->new({ webwork_dir => $webwork_dir });
	die "Can't create seed course environment for webwork in $webwork_dir" unless ref $seed_ce;

	$self->{seed_ce} = $seed_ce;

	return {
		command               => 'renderProblem',
		answer_form_submitted => 1,
		course                => $self->{course},
		mode                  => $self->{displayMode},
		displayMode           => $self->{displayMode},
		source                => $self->encoded_source,    #base64 encoded
		envir                 => {
			inputs_ref         => $self->{inputs_ref},
			displayMode        => $self->{inputs_ref}{displayMode}        // 'MathJax',
			permissionLevel    => $self->{inputs_ref}{permissionLevel}    // 0,
			isInstructor       => $self->{inputs_ref}{isInstructor}       // 0,
			problemSeed        => $self->{inputs_ref}{problemSeed}        // 1234,
			problemUUID        => $self->{inputs_ref}{problemUUID}        // 0,
			probNum            => $self->{inputs_ref}{probNum}            // 1,
			psvn               => $self->{inputs_ref}{psvn}               // 54321,
			setNumber          => $self->{inputs_ref}{setNumber}          // 1,
			showHints          => $self->{inputs_ref}{showHints}          // 0,
			showSolutions      => $self->{inputs_ref}{showSolutions}      // 0,
			forceScaffoldsOpen => $self->{inputs_ref}{forceScaffoldsOpen} // 0,
		},
		problem_state => {
			num_of_correct_ans   => 0,
			num_of_incorrect_ans => 0,
			recorded_score       => 1,
		},
	};
}

=over

=head2 rpc_execute

This method executes a WebworkWebservice command, and makes sure that
credentials are returned in the result on success.  The result will be stored in
the result_object of the instance.  An error_string will be set on failure.

=cut

async sub rpc_execute {
	my ($self, $command) = @_;
	$command //= 'renderProblem';

	my $permission = command_permission($command);

	return $self->error_string(__PACKAGE__ . ": Invalid command $command") if $permission eq 'invalid';

	# Determine the package that contains this command.
	my $service_package = '';
	for my $package (
		'WebworkWebservice::RenderProblem', 'WebworkWebservice::LibraryActions',
		'WebworkWebservice::SetActions',    'WebworkWebservice::CourseActions',
		'WebworkWebservice::ProblemActions'
		)
	{
		$service_package = $package if $package->can($command);
	}

	return $self->error_string(
		__PACKAGE__ . ": Unable to find a method for $command.  This shouldn't happen.  Report this error.")
		unless $service_package;

	my $input = $self->{inputs_ref} // {};

	# Store the request object for later use.  Input values can override default inputs.
	$self->request_object({ %{ $self->default_inputs }, %$input });

	my $result = eval {
		$self->initiate_session($permission);
		my $out = $service_package->$command($self, $self->request_object);
		return await $out if ref $out eq 'Future' || ref $out eq 'Mojo::Promise';
		return $out;
	};

	if ($@) {
		my $error = $@;
		chomp $error;
		return $self->error_string(__PACKAGE__ . " call to $command resulted in the following errors: $error");
	}
	return $self->error_string(__PACKAGE__ . " call to $command returned no result") if !ref $result;

	$result->{session_key} = $self->{session_key};
	$result->{userID}      = $self->{user_id};
	$result->{courseID}    = $self->{courseName};

	return $self->return_object($result);
}

=item formatRenderedProblem

This is called by WeBWorK::ContentGenerator::RenderViaRPC::pre_header_initialize
to format the return result of the WebworkWebservice::renderProblem method.
This method just calls FormatRenderedProblem::formatRenderedProblem.

=back

=cut

sub formatRenderedProblem {
	my $self = shift;
	return FormatRenderedProblem::formatRenderedProblem($self);
}

=head2 initiate_session

 	$self = WebworkWebservice->initiate_session($request_input, $permission_level);

The $request_input hash should include a command and all parameters needed for that command.

The $permisson_level argument is an optional string that defaults to 'proctor_quiz_login'.  Methods
that require higher permission levels should set this appropriately.  This permission level will be
checked against the user's permission level in the course.

=cut

sub initiate_session {
	my ($self, $permission) = @_;
	$permission //= 'proctor_quiz_login';

	my $rh_input = $self->request_object;

	# FIXME: Pass in the WeBWorK::Request, and use it for authentication instead of a FakeRequest object or handle
	# authentication at an earlier stage.  Also, the parameters should be switched to using the usual athentication
	# parameters (user, passwd, etc) instead of the alternates used here.  Perhaps with some munging of parameters for
	# backwards compatibility.

	# Create fake request object.  The $fake_r value returned contains subroutines that some of the WebworkWebservice
	# packages need to operate.
	my $fake_r = WeBWorK::FakeRequest->new($rh_input, 'rpc_module');
	my $authen = $fake_r->authen;
	my $authz  = $fake_r->authz;

	# Copy credentials from the alternate keys in the input.
	$self->{courseName}  = $rh_input->{courseID};
	$self->{user_id}     = $rh_input->{userID};
	$self->{password}    = $rh_input->{course_password};
	$self->{session_key} = $rh_input->{session_key};
	$self->{fake_r}      = $fake_r;

	die "Please use 'course_password' instead of 'password' as the key for submitting passwords to this webservice\n"
		if exists($rh_input->{password}) && !exists($rh_input->{course_password});

	die "Could not authenticate. A userID was not given.\n" unless $rh_input->{userID};

	my $authenOK;
	eval { $authenOK = $authen->verify; } or do {
		my $e;
		if (Exception::Class->caught('WeBWorK::DB::Ex::TableMissing')) {
			# Asked to authenticate into a non-existent course.
			die "Course |$self->{courseName}| not found.\n";
		}
		die "Could not authenticate user $self->{user_id}\n";
	};

	# Check that the user is at least a proctor in the course and has permission for the command.
	$self->{authenOK} = $authenOK;
	$self->{authzOK}  = $authz->hasPermissions($self->{user_id}, $permission);

	# Update the session_key in case it changed.
	$self->{session_key} = $authen->{session_key} if defined $authen->{session_key};

	die "Could not authenticate user $self->{user_id}\n" unless $self->{authenOK};
	die "User $self->{user_id} does not have sufficient privileges in the course $self->{courseName}\n"
		unless $self->{authzOK};

	return $self;
}

=head2 r

Returns the FakeRequest object contained in $webworkRPC.

=cut

sub r {
	my $self = shift;
	return $self->{fake_r};
}

=head2 Pass through methods which access the data in the FakeRequest object

    ce
    db
    params
    authz
    authen
    maketext

=cut

sub ce {
	my $self = shift;
	return $self->{fake_r}{ce};
}

sub db {
	my $self = shift;
	return $self->{fake_r}{db};
}

sub param {    # imitate get behavior of the request object params method
	my ($self, $param) = @_;
	my $out = $self->{fake_r}->param($param);
	return $out;
}

sub authz {
	my $self = shift;
	return $self->{fake_r}{authz};
}

sub authen {
	my $self = shift;
	return $self->{fake_r}{authen};
}

sub maketext {
	my $self = shift;
	return &{ $self->{fake_r}{language_handle} }(@_);
}

=head2 command_permission

This returns the permission required to perform the commands offered by the
WebworkWebservice.  Note that all available commands must be listed here or the
command will not be allowed.

=cut

sub command_permission {
	my ($command) = @_;
	return {
		# WebworkWebservice::CourseActions
		createCourse       => 'create_and_delete_courses',
		listUsers          => 'access_instructor_tools',
		addUser            => 'modify_student_data',
		dropUser           => 'modify_student_data',
		deleteUser         => 'modify_student_data',
		editUser           => 'modify_student_data',
		changeUserPassword => 'modify_student_data',
		getCourseSettings  => 'access_instructor_tools',
		updateSetting      => 'manage_course_files',

		# WebworkWebservice::LibraryActions
		listLibraries         => 'access_instructor_tools',
		readFile              => 'access_instructor_tools',
		listLib               => 'access_instructor_tools',
		searchLib             => 'access_instructor_tools',
		getProblemDirectories => 'access_instructor_tools',
		buildBrowseTree       => 'access_instructor_tools',
		getProblemTags        => 'access_instructor_tools',
		setProblemTags        => 'modify_tags',

		# WebworkWebservice::ProblemActions
		getUserProblem    => 'access_instructor_tools',
		putUserProblem    => 'modify_student_data',
		putProblemVersion => 'modify_student_data',
		putPastAnswer     => 'modify_student_data',

		# WebworkWebservice::RenderProblem
		renderProblem => 'proctor_quiz_login',

		# WebworkWebservice::SetActions
		listGlobalSets        => 'access_instructor_tools',
		listGlobalSetProblems => 'access_instructor_tools',
		getSets               => 'access_instructor_tools',
		getUserSets           => 'access_instructor_tools',
		getSet                => 'access_instructor_tools',
		updateSetProperties   => 'modify_problem_sets',
		listSetUsers          => 'access_instructor_tools',
		createNewSet          => 'modify_problem_sets',
		assignSetToUsers      => 'assign_problem_sets',
		deleteProblemSet      => 'modify_problem_sets',
		reorderProblems       => 'modify_problem_sets',
		updateProblem         => 'modify_problem_sets',
		updateUserSet         => 'modify_student_data',
		getSetUserSets        => 'access_instructor_tools',
		saveUserSets          => 'modify_student_data',
		unassignSetFromUsers  => 'modify_student_data',
		addProblem            => 'modify_problem_sets',
		deleteProblem         => 'modify_problem_sets',
	}->{$command} // 'invalid';
}

1;
