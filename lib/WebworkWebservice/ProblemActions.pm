#!/usr/local/bin/perl -w

################################################################################
# WeBWorK Online Homework Delivery System
# Copyright &copy; 2000-2020 The WeBWorK Project, http://openwebwork.sf.net/
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


###############################################################################
# Web service which manipulates problems and user problems.
###############################################################################

package WebworkWebservice::ProblemActions;
use WebworkWebservice;
use base qw(WebworkWebservice);

use strict;
use warnings;
use sigtrap;

use WeBWorK::Utils qw(encode_utf8_base64);
use WeBWorK::Debug qw(debug);
use WeBWorK::CourseEnvironment;

###############################################################################
# Obtain basic information about directories, course name and host
###############################################################################
our $WW_DIRECTORY = $WebworkWebservice::WW_DIRECTORY;
our $PG_DIRECTORY = $WebworkWebservice::PG_DIRECTORY;
our $COURSENAME   = $WebworkWebservice::COURSENAME;
our $HOST_NAME    = $WebworkWebservice::HOST_NAME;
our $PASSWORD     = $WebworkWebservice::PASSWORD;
our $ce = WeBWorK::CourseEnvironment->new({ webwork_dir => $WW_DIRECTORY, courseName => $COURSENAME });

our $UNIT_TESTS_ON = 0;

sub getUserProblem {
	debug("in getUserProblem");
	my ($self, $params) = @_;
	my $db = $self->db;

	my $userID = $params->{id};
	my $setID = $params->{set_id};
	my $problemID = $params->{problem_id};

	my $userProblem = $db->getUserProblem($userID, $setID, $problemID);

	return {
		ra_out => $userProblem,
		text => encode_utf8_base64(
			"Loaded problem $problemID of set $setID for user $userID in course $self->{courseName}.")
	};
}

sub putUserProblem {
	debug("in putUserProblem");
	my ($self, $params) = @_;
	my $db = $self->db;

	my $userID = $params->{id};
	my $setID = $params->{set_id};
	my $problemID = $params->{problem_id};

	my $userProblem;
	$userProblem = $db->getUserProblem($userID, $setID, $problemID);
	if (!$userProblem) { return { text => encode_utf8_base64("User problem not found.") }; }

	for ('source_file', 'value', 'max_attempts', 'showMeAnother', 'showMeAnotherCount', 'prPeriod',
		'prCount', 'problem_seed', 'status', 'attempted', 'last_answer', 'num_correct', 'num_incorrect',
		'att_to_open_children', 'counts_parent_grade', 'sub_status', 'flags') {
		$userProblem->{$_} = $params->{$_} if defined($params->{$_});
	}

	eval { $db->putUserProblem($userProblem) };
	if ($@) { return { text => encode_utf8_base64("putUserProblem: " . $@) }; }

	return {
		ra_out => $userProblem,
		text => encode_utf8_base64(
			"Updated problem $problemID of $setID for user $userID in course $self->{courseName}.")
	};
}

sub putProblemVersion {
	debug("in putProblemVersion");
	my ($self, $params) = @_;
	my $db = $self->db;

	my $userID = $params->{id};
	my $setID = $params->{set_id};
	my $versionID = $params->{version_id};
	my $problemID = $params->{problem_id};

	my $problemVersion = $db->getProblemVersion($userID, $setID, $versionID, $problemID);
	if (!$problemVersion) { return { text => encode_utf8_base64("Problem version not found.") }; }

	for ('source_file', 'value', 'max_attempts', 'showMeAnother', 'showMeAnotherCount', 'prPeriod',
		'prCount', 'problem_seed', 'status', 'attempted', 'last_answer', 'num_correct', 'num_incorrect',
		'att_to_open_children', 'counts_parent_grade', 'sub_status', 'flags') {
		$problemVersion->{$_} = $params->{$_} if defined($params->{$_});
	}

	eval { $db->putProblemVersion($problemVersion) };
	if ($@) { return { text => encode_utf8_base64("putProblemVersion: " . $@) }; }

	return {
		ra_out => $problemVersion,
		text => encode_utf8_base64(
			"Updated problem $problemID of $setID,v$versionID for user $userID in course $self->{courseName}.")
	};
}

sub putPastAnswer {
	debug("in putPastAnswer");
	my ($self, $params) = @_;
	my $db = $self->db;

	my $answerID = $params->{answer_id};

	my $pastAnswer = $db->getPastAnswer($answerID);
	if (!$pastAnswer) { return { text => encode_utf8_base64("Past answer not found.") }; }

	$pastAnswer->{user_id} = $params->{id} if $params->{id};

	for ('set_id', 'problem_id', 'source_file', 'timestamp', 'scores', 'answer_string', 'comment_string') {
		$pastAnswer->{$_} = $params->{$_} if defined($params->{$_});
	}

	eval { $db->putPastAnswer($pastAnswer) };
	if ($@) { return { text => encode_utf8_base64("putPastAnswer " . $@) }; }

	return {
		ra_out => $pastAnswer,
		text => encode_utf8_base64(
			"Updated answer $answerID for problem $pastAnswer->{problem_id} of $pastAnswer->{set_id} " .
			"for user $pastAnswer->{user_id} in course $self->{courseName}.")
	};
}

1;
