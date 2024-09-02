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

# Web service which manipulates problems and user problems.
package WebworkWebservice::ProblemActions;

use strict;
use warnings;

use Data::Structure::Util qw(unbless);

use WeBWorK::PG::Tidy qw(pgtidy);
use WeBWorK::PG::ConvertToPGML qw(convertToPGML);

sub getUserProblem {
	my ($invocant, $self, $params) = @_;

	my $db = $self->db;

	my $userProblem = $db->getUserProblem($params->{user_id}, $params->{set_id}, $params->{problem_id});

	return {
		ra_out => unbless($userProblem),
		text   => "Loaded problem $params->{problem_id} of set $params->{set_id} for "
			. "user $params->{user_id} in course "
			. $self->ce->{courseName} . '.'
	};
}

sub putUserProblem {
	my ($invocant, $self, $params) = @_;

	my $db = $self->db;

	my $userProblem = $db->getUserProblem($params->{user_id}, $params->{set_id}, $params->{problem_id});
	if (!$userProblem) { return { text => 'User problem not found.' }; }

	if ($self->c->authz->hasPermissions($self->authen->{user_id}, 'modify_student_data')) {
		for (
			'source_file',          'value',               'max_attempts', 'showMeAnother',
			'showMeAnotherCount',   'prPeriod',            'prCount',      'problem_seed',
			'attempted',            'last_answer',         'num_correct',  'num_incorrect',
			'att_to_open_children', 'counts_parent_grade', 'sub_status',   'flags'
			)
		{
			$userProblem->{$_} = $params->{$_} if defined $params->{$_};
		}
	}

	# The status is the only thing that users with the problem_grader permission can change.
	# This method cannot be called without the problem_grader permission.
	$userProblem->{status} = $params->{status} if defined $params->{status};

	# Remove the needs_grading flag if the mark_graded parameter is set.
	$userProblem->{flags} =~ s/:needs_grading$// if $params->{mark_graded};

	eval { $db->putUserProblem($userProblem) };
	if ($@) { return { text => "putUserProblem: $@" }; }

	return {
		ra_out => unbless($userProblem),
		text   => "Updated problem $params->{problem_id} of $params->{set_id} for "
			. "user $params->{user_id} in course "
			. $self->ce->{courseName} . '.'
	};
}

sub putProblemVersion {
	my ($invocant, $self, $params) = @_;

	my $db = $self->db;

	my $problemVersion =
		$db->getProblemVersion($params->{user_id}, $params->{set_id}, $params->{version_id}, $params->{problem_id});
	if (!$problemVersion) { return { text => 'Problem version not found.' }; }

	if ($self->c->authz->hasPermissions($self->authen->{user_id}, 'modify_student_data')) {
		for (
			'source_file',          'value',               'max_attempts', 'showMeAnother',
			'showMeAnotherCount',   'prPeriod',            'prCount',      'problem_seed',
			'attempted',            'last_answer',         'num_correct',  'num_incorrect',
			'att_to_open_children', 'counts_parent_grade', 'sub_status',   'flags'
			)
		{
			$problemVersion->{$_} = $params->{$_} if defined($params->{$_});
		}
	}

	# The status is the only thing that users with the problem_grader permission can change.
	# This method cannot be called without the problem_grader permission.
	$problemVersion->{status} = $params->{status} if defined $params->{status};

	# Remove the needs_grading flag if the mark_graded parameter is set.
	$problemVersion->{flags} =~ s/:needs_grading$// if $params->{mark_graded};

	eval { $db->putProblemVersion($problemVersion) };
	if ($@) { return { text => "putProblemVersion: $@" }; }

	return {
		ra_out => unbless($problemVersion),
		text   => "Updated problem $params->{problem_id} of $params->{set_id},v$params->{version_id} "
			. "for user $params->{user_id} in course "
			. $self->ce->{courseName} . '.'
	};
}

sub putPastAnswer {
	my ($invocant, $self, $params) = @_;

	my $db = $self->db;

	my $pastAnswer = $db->getPastAnswer($params->{answer_id});
	if (!$pastAnswer) { return { text => 'Past answer not found.' }; }

	$pastAnswer->{user_id} = $params->{user_id} if $params->{user_id};

	if ($self->c->authz->hasPermissions($self->authen->{user_id}, 'modify_student_data')) {
		for (
			'set_id', 'problem_id',    'source_file',    'timestamp',
			'scores', 'answer_string', 'comment_string', 'problem_seed'
			)
		{
			$pastAnswer->{$_} = $params->{$_} if defined($params->{$_});
		}
	}

	# The comment_string is the only thing that users with the problem_grader permission can change.
	# This method cannot be called without the problem_grader permission.
	$pastAnswer->{comment_string} = $params->{comment_string} if defined $params->{comment_string};

	eval { $db->putPastAnswer($pastAnswer) };
	if ($@) { return { text => "putPastAnswer $@" }; }

	return {
		ra_out => unbless($pastAnswer),
		text   =>
			"Updated answer $params->{answer_id} for problem $pastAnswer->{problem_id} of $pastAnswer->{set_id} "
			. "for user $pastAnswer->{user_id} in course "
			. $self->ce->{courseName} . '.'
	};
}

sub tidyPGCode {
	my ($invocant, $self, $params) = @_;

	local @ARGV = ();

	my $code = $params->{pgCode};
	my $tidiedPGCode;
	my $errors;

	my $result = pgtidy(source => \$code, destination => \$tidiedPGCode, errorfile => \$errors);

	return {
		ra_out => { tidiedPGCode => $tidiedPGCode, status => $result, errors => $errors },
		text   => 'Tidied code'
	};
}

sub convertCodeToPGML {
	my ($invocant, $self, $params) = @_;
	my $code = $params->{pgCode};

	return {
		ra_out => { pgmlCode => convertToPGML($code) },
		text   => 'Converted to PGML'
	};

}

1;
