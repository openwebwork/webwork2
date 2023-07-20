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

package WeBWorK::Utils::Tasks;
use parent qw(Exporter);

=head1 NAME

WeBWorK::Utils::Tasks - This is an inappropriately named package.  It used to
render problems which is not really a task.  Now the only this it provides are
utilities for creating fake database records.

=head1 SYNOPSIS

    use WeBWorK::Utils::Tasks qw(
        fake_set
        fake_set_version
        fake_problem
        fake_user
    );

=head1 DESCRIPTION

This module provides functions which are useful for taking problems which are
not part of any set and making live versions of them, or loading them into the
editor.

=cut

use strict;
use warnings;

use Carp;

use WeBWorK::DB::Utils qw(global2user);

our @EXPORT_OK = qw(
	fake_set
	fake_set_version
	fake_problem
	fake_user
);

use constant fakeSetName  => "Undefined_Set";
use constant fakeUserName => "Undefined_User";

=head1 FUNCTIONS

=over

=item fake_set

 fake_set($db);

Given a database, make a temporary problem set for that database.

=cut

sub fake_set {
	my $db = shift;

	my $set = $db->newGlobalSet();
	$set = global2user($db->{set_user}->{record}, $set);
	$set->psvn(123);
	$set->set_id(fakeSetName);
	$set->open_date(time());
	$set->due_date(time());
	$set->answer_date(time());
	$set->visible(0);
	$set->enable_reduced_scoring(0);
	$set->hardcopy_header("defaultHeader");
	return ($set);
}

sub fake_set_version {
	my $db = shift;

	my $set = $db->newSetVersion();
	$set->psvn(123);
	$set->set_id(fakeSetName);
	$set->open_date(time());
	$set->due_date(time());
	$set->answer_date(time());
	$set->visible(0);
	$set->enable_reduced_scoring();
	$set->hardcopy_header("defaultHeader");
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

=item fake_problem

 fake_problem($db);
 fake_problem($db, problem_seed=>$seed);

Make a temporary problem for the given database. If a problem seed is not
specified, 0 is used.

=cut

sub fake_problem {
	my ($db, %options) = @_;
	my $problem = $db->newGlobalProblem();

	$problem = global2user($db->{problem_user}->{record}, $problem);
	$problem->set_id(fakeSetName);
	$problem->value("");
	$problem->max_attempts("-1");
	$problem->showMeAnother("-1");
	$problem->showMeAnotherCount("0");
	$problem->showHintsAfter(2);

	$problem->problem_seed(0);
	$problem->problem_seed($options{'problem_seed'})
		if (defined($options{'problem_seed'}));

	$problem->status(0);
	$problem->sub_status(0);
	$problem->attempted(2000);    # Large so hints won't be blocked
	$problem->last_answer("");
	$problem->num_correct(1000);
	$problem->num_incorrect(1000);
	$problem->prCount(-10);       # Negative to detect fake problems and disable problem randomization.

	return ($problem);
}

=item fake_user

 fake_user($db);

Make a temporary user for the given database.

=cut

sub fake_user {
	my ($db) = @_;
	return $db->newUser(
		user_id       => fakeUserName,
		first_name    => '',
		last_name     => '',
		email_address => '',
		student_id    => '',
		section       => '',
		recitation    => '',
		comment       => '',
	);
}

=back

=cut

1;
