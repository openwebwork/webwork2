################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2003 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork-modperl/lib/WeBWorK/Utils.pm,v 1.37 2003/12/09 01:12:30 sh002i Exp $
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

package WeBWorK::Compatibility;
use base qw(Exporter);

=head1 NAME

WeBWorK::Compatibility - useful utilities for maintaining backward compatibility with 
WW1.9 and the use of GDBM databases.

=cut

use strict;
use warnings;

use Date::Format;
use Date::Parse;
use Errno;

our @EXPORT    = ();
our @EXPORT_OK = qw(
	runtime_use

);

sub update_global_user {
    # obtain the calling object ($co)
	my $co  = shift;  # call this subroutine from somewhere using update_global_user($self);
	my $ce  = $co ->{ce};
	unless ($ce->{dbLayoutName} eq 'gdbm') {
		warn "Error in calling update_global_user.  This routine should only be called when using
	      the database GDBM.  Current database type is " .$ce->{dbLayoutName}.
	    return(CGI::div({class=>"ResultsWithError"},"Problems with intitializing global user --see warning messages"));
	}
	
	# determin name of global user
	my $globalUser =  $ce->{dbLayout}->{set}->{params}->{globalUserID};
	
	unless (defined($globalUser) and $globalUser) {
		warn "No global user name is specified in the database.conf file.".  
			"See \$dbLayout{gdbm}->{set}{params}->{globalUserID}";
		return(CGI::div({class=>"ResultsWithError"},"Problems with intitializing global user --see warning messages"));
	}	
	
	# get list of users
	my $db  = $co->{db};
	my @userList = $db->listUsers;
	
	# make sure that global user has not already been defined (error if it has)
    my $flag = 0;
    foreach my $user (@userList) {
    	$flag = 1 if $user eq $globalUser;
    }
    unless ($flag == 0 ) {
    	warn "The global User $globalUser has already been defined, and presumably all sets have ".
			"been assigned to this 'user'.  If this is not the case one can delete the global user ".
			"and then visit this page again.  A new global user will be created and all existing sets ".
			"will be assigned to this global user.";
    	return(CGI::div({class=>"ResultsWithError"},"Problems with intitializing global user --see warning messages"));
    }
    
	
	
	# add (create an entry for) global _user
	my $message = "";
	my $new_user_id        = $globalUser;
	# copy and pasted from AddUsers.pm
	# not worth factoring this for a remedial script (and 640K should be enough for anyone )
	
	my $newUser            = $db->newUser;
	my $newPermissionLevel = $db->newPermissionLevel;
	my $newPassword        = $db->newPassword;
	$newUser->user_id($new_user_id);
	$newPermissionLevel->user_id($new_user_id);
	$newPassword->user_id($new_user_id);
	$newUser->last_name("User");
	$newUser->first_name("Global");
	$newUser->student_id($new_user_id);
	$newUser->email_address($new_user_id);
	$newUser->section('');
	$newUser->recitation('');
	$newUser->comment('');
	$newUser->status('C');
	$newPermissionLevel->permission(0);
	#FIXME  handle errors if user exists already
	eval { $db->addUser($newUser) };
	if ($@) {
		my $addError = $@;
		$message  .= join("",
			CGI::b("Failed to enter student: "), $newUser->last_name, ", ",$newUser->first_name,
			CGI::b(", login/studentID: "), $newUser->user_id, "/",$newUser->student_id,
			CGI::b(", email: "), $newUser->email_address,
			CGI::b(", section: "), $newUser->section,
			CGI::br(), CGI::b("Error message: "), $addError,
			CGI::hr(),CGI::br(),
		);
	} else {
		$db->addPermissionLevel($newPermissionLevel);
		$db->addPassword($newPassword);
		$message .= join("",
			CGI::b("Entered student: "), $newUser->last_name, ", ",$newUser->first_name,
			CGI::b(", login/studentID: "), $newUser->user_id, "/",$newUser->student_id,
			CGI::b(", email: "), $newUser->email_address,
			CGI::b(", section: "), $newUser->section,CGI::hr(),CGI::br(),
            CGI::div({class=>"ResultsWithOutError"},"It is necessary to add this fictional student, Global User, when converting a WW1.9 course
             to a WW2.0 course.  This action and message should only occur the first time 
             you view this page for an existing course using the WW2.0 software. 
             You can  ignore the warnings below, 
             unless they reoccur when you reload this page."
            )
		);
	}
	
	# find the sets assigned to any user
	my %assigned_sets = ();
	my %assigned_problems = ();
	foreach my $userID (@userList) {
	    # FIXME  this could cause trouble if different things have been assigned, but it's good enough for compatibility
		foreach my $setID ($db->listUserSets($userID) ) {
			unless ( ref($assigned_sets{$setID}) ){
				$assigned_sets{$setID}       = $db -> getUserSet($userID, $setID) ; 
				$assigned_problems{$setID}   = [ $db -> getAllUserProblems($userID, $setID) ]; # we need this anonymous array reference here
			}
		}
	}
	###############################
	# assign those sets to global user
	###############################
	warn "assigning to global user $globalUser sets ", join( " ", keys %assigned_sets);
	my @sets_to_assign = keys %assigned_sets;
	my @results = ();
	###############################
	# create the global records for these sets
	###############################
	foreach my $newSetName (@sets_to_assign) {
	  $WeBWorK::timer->continue("Compatibility.pm: begin adding set $newSetName") if defined $WeBWorK::timer;
	   warn "initializing set $newSetName";  # FIXME
		my $newSetRecord = $db->{set}->{record}->new();
		my $oldSetRecord = $assigned_sets{$newSetName};
		$newSetRecord->set_id($newSetName);
		$newSetRecord->set_header($oldSetRecord->set_header);
		$newSetRecord->problem_header($oldSetRecord->problem_header);
		$newSetRecord->open_date($oldSetRecord->open_date);
		$newSetRecord->due_date($oldSetRecord->due_date);
		$newSetRecord->answer_date($oldSetRecord->answer_date);
		eval {$db->addGlobalSet($newSetRecord)};
	    push( @results , "problem with $newSetName ".$@ ) if $@;
	    
	    ###############################
	    # now add problems to this set
	    ###############################
	    my @problems_to_assign = @{$assigned_problems{$newSetName}};
	    
		foreach my $oldProblemRecord (@problems_to_assign) {
			my $problemRecord = $db->newGlobalProblem;
			$problemRecord->problem_id($oldProblemRecord->problem_id);
			$problemRecord->set_id($oldProblemRecord->set_id);
			$problemRecord->source_file($oldProblemRecord->source_file);
			$problemRecord->value($oldProblemRecord->value);
			$problemRecord->max_attempts($oldProblemRecord->max_attempts);
			eval {$db->addGlobalProblem($problemRecord)};
			push( @results, "problem adding ".$oldProblemRecord->source_file." to $newSetName: ".$@) if $@;
		}
	  $WeBWorK::timer->continue("Compatibility.pm: end adding set $newSetName") if defined $WeBWorK::timer;
	}
	

	if (@results) {
		$message .= join("", CGI::div({class=>"ResultsWithError"},
			CGI::p("The following error(s) occured while assigning:"),
			CGI::ul(CGI::li(\@results)),
		));
	} else {
		$message .= join("", CGI::div({class=>"ResultsWithoutError"},
			CGI::p("All assignments were made successfully."),
		));
	}
	return($message);
}



1;
