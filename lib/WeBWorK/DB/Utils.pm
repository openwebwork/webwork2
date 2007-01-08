################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Utils.pm,v 1.20 2006/10/23 17:32:01 sh002i Exp $
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

our @EXPORT    = ();
our @EXPORT_OK = qw(
	global2user
	user2global
	initializeUserProblem
	make_vsetID
	grok_vsetID
	grok_setID_from_vsetID_sql
	grok_versionID_from_vsetID_sql
);
	
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

	return $userProblem;
}

################################################################################
# versioning utilities
################################################################################

sub make_vsetID($$) {
	my ($setID, $versionID) = @_;
	return "$setID,v$versionID";
}

sub grok_vsetID($) {
	my ($vsetID) = @_;
	my ($setID, $versionID) = $vsetID =~ /([^,]+)(?:,v(.*))?/;
	return $setID, $versionID;
}

sub grok_setID_from_vsetID_sql($) {
	my ($field) = @_;
	return "SUBSTRING(`$field`,1,INSTR(`$field`,',v'))";
}

sub grok_versionID_from_vsetID_sql($) {
	my ($field) = @_;
	# the "+0" casts the resulting value as a number
	return "(SUBSTRING(`$field`,INSTR(`$field`,',v')+2)+0)";
}

1;
