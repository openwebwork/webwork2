################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
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
use base qw(Exporter);

=head1 NAME

WeBWorK::Utils::Tasks - utilities for doing single tasks, like rendering a
problem by itself.

=head1 SYNOPSIS

 use WeBWorK::Utils::Tasks qw(renderProblems);

=head1 DESCRIPTION

This module provides functions for rendering html from files outside the normal
context of being for a particular user in an existing problem set.

It also provides functions which are useful for taking problems which are not
part of any set and making live versions of them, or loading them into the
editor.

=cut

# Ultimately, this may provide functions for turning problems into hardcopy or
# other tasks that can be separated out of specific content managers.

use strict;
use warnings;
use Carp;
use WeBWorK::PG; 
use WeBWorK::PG::ImageGenerator; 
use WeBWorK::DB::Utils qw(global2user); 
use WeBWorK::Form;
use WeBWorK::Debug;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	renderProblems
	fake_set
	fake_set_version
	fake_problem
	fake_user
);

use constant fakeSetName => "Undefined_Set";
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
	return($set); 
} 

sub fake_set_version { 
	my $db = shift; 
 
	my $set = $db->newSetVersion(); 
	# $set = global2user($db->{set_user}->{record}, $set); 
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

	return($set); 
} 


=item fake_problem

 fake_problem($db);
 fake_problem($db, problem_seed=>$seed);

Make a temporary problem for the given database. If a problem seed is not
specified, 0 is used.

=cut

sub fake_problem { 
	my $db = shift; 
	my %options = @_;
	my $problem = $db->newGlobalProblem(); 

	#debug("In fake_problem");

	$problem = global2user($db->{problem_user}->{record}, $problem); 
	$problem->set_id(fakeSetName); 
	$problem->value(""); 
	$problem->max_attempts("-1"); 
 
	$problem->problem_seed(0); 
	$problem->problem_seed($options{'problem_seed'})
		 if(defined($options{'problem_seed'}));

	$problem->status(0);
	$problem->sub_status(0); 
	$problem->attempted(2000);  # Large so hints won't be blocked
	$problem->last_answer(""); 
	$problem->num_correct(1000); 
	$problem->num_incorrect(1000); 

	#for my $key (keys(%{$problem})){
	#	my $value = '####UNDEF###';
	#	if ($problem->{$key}) {
	#		$value = $problem->{$key};
	#	}
	#	debug($key . " : " . $value);
	#}



	return($problem); 
}

=item fake_user

 fake_user($db);

Make a temporary user for the given database.

=cut

sub fake_user {
	my ($db) = @_;
	return $db->newUser(
		user_id => fakeUserName,
		first_name=>'',
		last_name=>'',
		email_address=>'',
		student_id=>'',
		section=>'',
		recitation=>'',
		comment=>'',
	);
}

=item render_problems

 render_problems(r => $r, user => $User, problem_list => \@problem_list);

Given an Apache request object, the current user, and a list of problem files,
return a list of WeBWorK::PG objects which contain rendered versions of the
problems.

Options:

=over

=item r

A WeBWorK::Request object. Required.

=item problem_list

A reference to an array of items render. Required. Each item can either be a
string, which is interpreted as a path to a PG file, or a reference to a string,
which is interpreted as a complete PG program.

=item user

A User record (e.g. a WeBWorK::DB::Record::User object). Optional. If not
specified, fake_user() will be used to generate a temporary user record.

=item this_set

A Set record (e.g. a WeBWorK::DB::Record::UserSet object). Optional. If not
specified, fake_set() will be used to generate a temporary set record.

=item problem_seed

The seed to use for randomization. Optional. If not specified, the Request
object will be checked for a problem_seed parameter. If found, that value is
used. Otherwise, 0 is used.

=item displayMode

The display mode to use. Optional. If not specified, the Request object will be
checked for a displayMode parameter. If found, that value is used. Otherwise,
the default display mode is used.

If the value is 'None', then problems will not be rendered and "fake"
WeBWorK::PG objects will be returned. Each "fake" WeBWorK::PG object will look
like:

 {body_text=>''}

=item showHints

Whether to show hints in the problem. Optional. If not specified, hints are not
shown.

=item showSolutions

Whether to show solutions in the problem. Optional. If not specified, solutions
are not shown.

=item problemNumber

Each problem in @problem_list is given a problem ID starting with this value.
Optional. If not specified the problems are numbered from 1.

=back

=cut

sub renderProblems {
	my %args = @_;
	my $r = $args{r};
	my $db = $r->db;
	my $ce = $r->ce; 

	# Don't print file names as part of the problem to avoid redundant 
	# paths in Library Browser and Homework Sets editor
	$ce->{pg}->{specialPGEnvironmentVars}->{PRINT_FILE_NAMES_FOR}=[];

	my @problem_list = @{$args{problem_list}};
	my $displayMode = $args{displayMode}
    	|| $r->param('displayMode')
		|| $ce->{pg}{options}{displayMode};
	
	# special case for display mode 'None' -- we don't have to do anything
	# FIXME i think this should be handled in SetMaker.pm
	# SetMaker is not the only user of 'None'
	if ($displayMode eq 'None') {
		return map { {body_text=>''} } @problem_list;
	}
	
	my $user = $args{user} || fake_user($db);
	my $set = $args{'this_set'} || fake_set($db);
	my $problem_seed = $args{'problem_seed'} || $r->param('problem_seed') || 0;
	my $showHints = $args{showHints} || 0;
	my $showSolutions = $args{showSolutions} || 0;
	my $problemNumber = $args{'problem_number'} || 1;
	
	my $key = $r->param('key');
	
	# remove any pretty garbage around the problem
	local $ce->{pg}{specialPGEnvironmentVars}{problemPreamble} = {TeX=>'',HTML=>''};
	local $ce->{pg}{specialPGEnvironmentVars}{problemPostamble} = {TeX=>'',HTML=>''};
	my $problem = fake_problem($db, 'problem_seed'=>$problem_seed);
	$problem->{value} = -1;
	my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars };
	
	my @output;
	
	foreach my $onefile (@problem_list) {
		my $translationOptions = {
			displayMode     => $displayMode,
			showHints       => $showHints,
			showSolutions   => $showSolutions,
			refreshMath2img => 0,
			processAnswers  => 0,
		};
		
		$problem->problem_id($problemNumber++);
		if (ref $onefile) {
			$problem->source_file('');
			$translationOptions->{r_source} = $onefile;
		} else {
			$problem->source_file($onefile);
		}
		
		my $pg = new WeBWorK::PG(
			$ce,
			$user,
			$key,
			$set,
			$problem,
			123, # PSVN (practically unused in PG)
			$formFields,
			$translationOptions,
        );

		push @output, $pg;
	}
	
	return @output;
}

=back

=cut

=head1 AUTHOR

Written by John Jones, jj (at) asu.edu.

=cut

1;
