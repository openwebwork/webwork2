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

package WeBWorK::DB::Utils;
use base qw(Exporter);

=head1 NAME

WeBWorK::DB::Utils - useful utilities for the database modules.

=cut

use strict;
use warnings;

our @EXPORT_OK = qw(
	global2user
	user2global
	initializeUserProblem
	fake_set
	fake_set_version
	fake_problem
	make_vsetID
	make_vsetID_sql
	grok_vsetID
	grok_setID_from_vsetID_sql
	grok_versionID_from_vsetID_sql
	parse_dsn
);

use constant fakeSetName => 'Undefined_Set';

sub global2user($$) {
	my ($userRecordClass, $GlobalRecord) = @_;
	my $UserRecord = $userRecordClass->new();
	foreach my $field ($GlobalRecord->FIELDS()) {
		$UserRecord->$field($GlobalRecord->$field());
	}
	return $UserRecord;
}

sub user2global($$) {
	my ($globalRecordClass, $UserRecord) = @_;
	my $GlobalRecord = $globalRecordClass->new();
	foreach my $field ($GlobalRecord->FIELDS()) {
		$GlobalRecord->$field($UserRecord->$field());
	}
	return $GlobalRecord;
}

# Populate a user record with sane defaults and a random seed
# This function edits the record in place, so you can discard
# the return value.
sub initializeUserProblem {
	my ($userProblem, $seed) = @_;
	$seed = int rand 5000 unless defined $seed;
	$userProblem->status(0.0);
	$userProblem->attempted(0);
	$userProblem->num_correct(0);
	$userProblem->num_incorrect(0);
	$userProblem->problem_seed($seed);
	$userProblem->sub_status(0.0);

	return $userProblem;
}

# Methods to create initialized database set and problem objects.
# They are poorly named methods.  The database objects are not "fake".
# The are valid database objects with initialized values.

sub fake_set {
	my $db = shift;

	my $set = $db->newGlobalSet();
	$set = global2user($db->{set_user}{record}, $set);
	$set->psvn(123);
	$set->set_id(fakeSetName);
	$set->open_date(time);
	$set->due_date(time);
	$set->answer_date(time);
	$set->visible(0);
	$set->enable_reduced_scoring(0);
	$set->hardcopy_header('defaultHeader');

	return ($set);
}

sub fake_set_version {
	my $db = shift;

	my $set = $db->newSetVersion();
	$set->psvn(123);
	$set->set_id(fakeSetName);
	$set->open_date(time);
	$set->due_date(time);
	$set->answer_date(time);
	$set->visible(0);
	$set->enable_reduced_scoring();
	$set->hardcopy_header('defaultHeader');
	$set->version_id(1);
	$set->attempts_per_version(0);
	$set->problem_randorder(0);
	$set->problems_per_page(0);
	$set->hide_score('N');
	$set->hide_score_by_problem('N');
	$set->hide_work('N');
	$set->restrict_ip('No');

	return ($set);
}

sub fake_problem {
	my ($db, %options) = @_;

	my $problem = $db->newGlobalProblem();
	$problem = global2user($db->{problem_user}{record}, $problem);
	$problem->set_id(fakeSetName);
	$problem->value('');
	$problem->max_attempts(-1);
	$problem->showMeAnother(-1);
	$problem->showMeAnotherCount(0);
	$problem->showHintsAfter(2);
	$problem->problem_seed($options{problem_seed} // 0);
	$problem->status(0);
	$problem->sub_status(0);
	$problem->attempted(2000);    # Large so hints won't be blocked
	$problem->last_answer('');
	$problem->num_correct(1000);
	$problem->num_incorrect(1000);
	$problem->prCount(-10);       # Negative to detect fake problems and disable problem randomization.

	return ($problem);
}

################################################################################
# versioning utilities
################################################################################

sub make_vsetID($$) {
	my ($setID, $versionID) = @_;
	return "$setID,v$versionID";
}

# does not quote $setID and $versionID, because they could be strings, qualified
# or unqualified field names, or complex expression
sub make_vsetID_sql {
	my ($setID, $versionID) = @_;
	return "CONCAT($setID,',v',$versionID)";
}

sub grok_vsetID($) {
	my ($vsetID) = @_;
	my ($setID, $versionID) = $vsetID =~ /([^,]+)(?:,v(.*))?/;
	return $setID, $versionID;
}

# does not quote $field, because it could be a string, a qualified or
# unqualified field name, or a complex expression
sub grok_setID_from_vsetID_sql($) {
	my ($field) = @_;
	return "SUBSTRING($field,1,INSTR($field,',v')-1)";
}

# does not quote $field, because it could be a string, a qualified or
# unqualified field name, or a complex expression
sub grok_versionID_from_vsetID_sql($) {
	my ($field) = @_;
	# the "+0" casts the resulting value as a number
	return "(SUBSTRING($field,INSTR($field,',v')+2)+0)";
}

sub parse_dsn {
	my $dsn = shift;

	my %dsn;
	if ($dsn =~ m/^dbi:mariadb:/i || $dsn =~ m/^dbi:mysql:/i) {
		# Expect DBI:MariaDB:database=webwork;host=db;port=3306
		# or DBI:mysql:database=webwork;host=db;port=3306
		# The host and port are optional.
		my ($dbi, $dbtype, $dsn_opts) = split(':', $dsn);
		while (length($dsn_opts)) {
			if ($dsn_opts =~ /^([^=]*)=([^;]*);(.*)$/) {
				$dsn{$1} = $2;
				$dsn_opts = $3;
			} else {
				my ($var, $val) = $dsn_opts =~ /^([^=]*)=([^;]*)$/;
				$dsn{$var} = $val;
				$dsn_opts = '';
			}
		}
	} else {
		die 'Unable to parse database dsn into parts. Unsupported database controller driver.';
	}

	return %dsn;
}

1;
