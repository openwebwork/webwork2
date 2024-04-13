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

package WebworkWebservice;

=head1 NAME

WebworkWebservice

=head1 SYNPOSIS

    my $rpc_service = WebworkWebservice->new($c);
    await $rpc_service->rpc_execute('command_to_execute');

After that, if the command is 'renderProblem', use

	my $result = $rpc_service->formatRenderedProblem;

to obtain the result in the requested 'outputformat'.

=head1 DESCRIPTION

The WebworkWebservice executes a requested command and returns with the result.
The webservice command methods are available are in the following modules:

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

use WeBWorK::Localize;
use WeBWorK::CourseEnvironment;
use WebworkWebservice::RenderProblem;
use WebworkWebservice::LibraryActions;
use WebworkWebservice::SetActions;
use WebworkWebservice::CourseActions;
use WebworkWebservice::ProblemActions;
use FormatRenderedProblem;
use HardcopyRenderedProblem;

=head2 new (constructor)

=cut

sub new {
	my ($invocant, $c, %options) = @_;
	my $class = ref $invocant || $invocant;
	return bless {
		c             => $c,
		inputs_ref    => $c->req->params->to_hash,
		return_object => {},
		error_string  => '',
		%options
	}, $class;
}

=head2 Accessor methods

    return_object
    error_string

=cut

sub return_object {
	my ($self, $object) = @_;
	$self->{return_object} = $object if defined $object && ref $object;
	return $self->{return_object};
}

sub error_string {
	my ($self, $string) = @_;
	$self->{error_string} = $string if defined $string && $string =~ /\S/;
	return $self->{error_string};
}

=head2 rpc_execute

This method executes a WebworkWebservice command, and makes sure that
credentials are returned in the result on success.  The result will be stored in
the result_object of the instance.  An error_string will be set on failure.

=cut

async sub rpc_execute {
	my ($self, $command) = @_;
	my $c       = $self->c;
	my $user_id = $c->param('user');

	$command //= 'renderProblem';

	my $permission = command_permission($command);

	return $self->error_string(__PACKAGE__ . ": Invalid command $command") if $permission eq 'invalid';

	# Check that the user has permission to perform this command.
	return $self->error_string(__PACKAGE__ . ": User $user_id does not have permission for the command $command")
		unless $c->authz->hasPermissions($user_id, $permission);

	# Determine the package that contains the method for this command.
	my $command_package = '';
	for my $package (
		'WebworkWebservice::RenderProblem', 'WebworkWebservice::LibraryActions',
		'WebworkWebservice::SetActions',    'WebworkWebservice::CourseActions',
		'WebworkWebservice::ProblemActions'
		)
	{
		if ($package->can($command)) {
			$command_package = $package;
			last;
		}
	}

	return $self->error_string(
		__PACKAGE__ . ": Unable to find a method for $command.  This shouldn't happen.  Report this error.")
		unless $command_package;

	my $result = eval {
		my $out = $command_package->$command($self, $self->{inputs_ref});
		return await $out if ref $out eq 'Future' || ref $out eq 'Mojo::Promise';
		return $out;
	};

	if ($@) {
		my $error = $@;
		chomp $error;
		return $self->error_string(__PACKAGE__ . " call to $command resulted in the following errors: $error");
	}
	return $self->error_string(__PACKAGE__ . " call to $command returned no result") if !ref $result;

	return $self->return_object($result);
}

=over

=item formatRenderedProblem

This is called by WeBWorK::ContentGenerator::RenderViaRPC::pre_header_initialize
to format the return result of the WebworkWebservice::renderProblem method.
This method calls HardcopyRenderedProblem::hardcopyRenderedProblem if the
outputformat is tex or pdf, and calls FormatRenderedProblem::formatRenderedProblem
otherwise.

=back

=cut

sub formatRenderedProblem {
	my $self = shift;
	return HardcopyRenderedProblem::hardcopyRenderedProblem($self)
		if $self->{inputs_ref}{outputformat}
		&& ($self->{inputs_ref}{outputformat} eq 'tex' || $self->{inputs_ref}{outputformat} eq 'pdf');
	return FormatRenderedProblem::formatRenderedProblem($self);
}

=head2 c

Returns the WeBWorK::Controller object contained in $webworkRPC.

=cut

sub c {
	my $self = shift;
	return $self->{c};
}

=head2 Pass through methods which access the data in the WeBWorK::Controller object

    ce
    db
    params
    authz
    authen
    maketext

=cut

sub ce {
	my $self = shift;
	return $self->{c}->ce;
}

sub db {
	my $self = shift;
	return $self->{c}->db;
}

sub param {
	my ($self, $param) = @_;
	return $self->{c}->param($param);
}

sub authz {
	my $self = shift;
	return $self->{c}->authz;
}

sub authen {
	my $self = shift;
	return $self->{c}->authen;
}

sub maketext {
	my $self = shift;
	return $self->{c}->language_handle->(@_);
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
		saveFile           => 'modify_problem_sets',

		# WebworkWebservice::LibraryActions
		listLib        => 'access_instructor_tools',
		searchLib      => 'access_instructor_tools',
		getProblemTags => 'access_instructor_tools',
		setProblemTags => 'modify_tags',

		# WebworkWebservice::ProblemActions
		getUserProblem    => 'access_instructor_tools',
		putUserProblem    => 'modify_student_data',
		putProblemVersion => 'modify_student_data',
		putPastAnswer     => 'modify_student_data',
		tidyPGCode        => 'access_instructor_tools',
		convertCodeToPGML => 'access_instructor_tools',

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
