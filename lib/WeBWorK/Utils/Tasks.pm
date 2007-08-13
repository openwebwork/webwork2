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

WeBWorK::Utils::Tasks - utilities for doing single tasks, like
  rendering a problem by itself.

=head1 SYNOPSIS

 use WeBWorK::Utils::Tasks qw/renderProblems/;
 

=head1 DESCRIPTION

This module provides functions for rendering html from files outside the
normal context of being for a particular user in an existing problem set.

It also provides functions which are useful for taking problems which are
not part of any set and making live versions of them, or loading them into
the editor.

=cut

# Ultimately, this may provide functions for turning problems into hardcopy
# or other tasks that can be separated out of specific content managers.

use strict;
use warnings;
use Carp;
use WeBWorK::PG; 
use WeBWorK::PG::ImageGenerator; 
use WeBWorK::DB::Utils qw(global2user); 
use WeBWorK::Form;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	renderProblems
	fake_set
	fake_problem
);

use constant fakeSetName => "Undefined_Set";

=head1 FUNCTIONS

=over

=item fake_set($db)

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
  $set->published(0); 
  $set->hardcopy_header("");
  return($set); 
} 


=item fake_problem($db)

Make a temporary problem for the given database.

=cut

sub fake_problem { 
  my $db = shift; 
  my %options = @_;
  my $problem = $db->newGlobalProblem(); 
  $problem = global2user($db->{problem_user}->{record}, $problem); 
  $problem->set_id(fakeSetName); 
  $problem->value(""); 
  $problem->max_attempts("-1"); 
 
  $problem->problem_seed(0); 
  $problem->problem_seed($options{'problem_seed'})
     if(defined($options{'problem_seed'}));

  $problem->status(0); 
  $problem->attempted(0); 
  $problem->last_answer(""); 
  $problem->num_correct(0); 
  $problem->num_incorrect(0); 
  return($problem); 
} 

=item render_problems(r => $r, user => $user, problem_list => \@problem_list)

Given an Apache request object, the current user, and a list of problem
files, return a list of pg objects which contain rendered versions of
the problems.

=cut

sub renderProblems { 
  my %args = @_;
  my $r = $args{r};
  my $user = $args{user};
  my @problem_list = @{$args{problem_list}};
	
  my $db = $r->db; 
  my $ce = $r->ce; 
  my $key = $r->param('key'); 
  my $set = $args{'this_set'} || fake_set($db); 
  my $problem_seed = $args{'problem_seed'} || $r->param('problem_seed') || 0;
  my $displayMode = $args{displayMode} ||
    $r->param("displayMode") || $ce->{pg}->{options}->{displayMode};
  my $problemNumber= $args{'problem_number'} || 1;
  $ce->{pg}->{specialPGEnvironmentVars}->{problemPreamble} = {
	TeX=>'',
	HTML=>''};
  $ce->{pg}->{specialPGEnvironmentVars}->{problemPostamble} = {
	TeX=>'',
	HTML=>''};

  my @output = (); 
  my $onefile;
  if($displayMode eq 'None') {
    for $onefile (@problem_list) {
      my $res = { body_text=>''};
      #my $res = { body_text=>'Click "Try it" to see the problem rendered'};
      push @output, $res; 
    }
  } else {
    my $problem = fake_problem($db, 'problem_seed'=>$problem_seed); 
    my $formFields = { WeBWorK::Form->new_from_paramable($r)->Vars }; 
 
    for $onefile (@problem_list) { 
      $problem->problem_id($problemNumber++); 
      $problem->source_file($onefile); 
      my $pg = WeBWorK::PG->new( 
                                $ce, 
                                $user, 
                                $key,
                                $set,
                                $problem, 
                                123, #  $set->psvn, # FIXME: this field should be\ removed 
                                $formFields, 
                                { # translation options 
                                 displayMode     => $displayMode, 
                                 showHints       => 0, 
                                 showSolutions   => 0, 
                                 refreshMath2img => 0, 
                                 processAnswers  => 0, 
                                } 
                               ); 
 
      push @output, $pg; 
    } 
  }
  return(@output); 
} 

=back

=cut

=head1 AUTHOR

Written by John Jones, jj (at) asu.edu.

=cut



1;
