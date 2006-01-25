################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2006 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader: webwork2/lib/WeBWorK/DB/Schema/GlobalTableEmulator.pm,v 1.17 2003/12/12 20:23:27 sh002i Exp $
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

package WeBWorK::DB::Schema::GlobalTableEmulator;
use base qw(WeBWorK::DB::Schema);

=head1 NAME

WeBWorK::DB::Schema::GlobalTableEmulator - emulate the global 'set' and
'problem' tables using access to the 'set_user' and 'problem_user' tables.

=cut

use strict;
use warnings;
use Carp;
use Data::Dumper;
use WeBWorK::DB::Utils qw(global2user user2global initializeUserProblem findDefaults);

use constant TABLES => qw(set problem);
use constant STYLE  => "null";

################################################################################
# constructor
################################################################################

sub new {
	my ($proto, $db, $driver, $table, $record, $params) = @_;
	
	die "parameter globalUserID not found"
		unless exists $params->{globalUserID};
	
	my $self = $proto->SUPER::new($db, $driver, $table, $record, $params);
	
	return $self;
}

################################################################################
# table access functions
################################################################################

sub count {
	my ($self, @keyparts) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	return $userSchema->count($globalUserID, @keyparts);
}

sub list {
	my ($self, @keyparts) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	my @userRecordIDs = $userSchema->list($globalUserID, @keyparts);
	my @recordIDs;
	foreach my $userRecordID (@userRecordIDs) {
		shift @$userRecordID; # take off the userID
		push @recordIDs, $userRecordID;
	}
	
	return @recordIDs;
}

sub exists {
	my ($self, @keyparts) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	return $userSchema->exists($globalUserID, @keyparts);
}

sub add {
	my ($self, $Record) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	# make sure record doesn't already exist
	my $setID = $Record->set_id();
	if ($self->{table} eq "set") {
		die "($setID): Set exists.\n"
			if $self->exists($setID);
	} elsif ($self->{table} eq "problem") {
		my $problemID = $Record->problem_id();
		die "($setID, $problemID): Problem exists.\n"
			if $self->exists($setID, $problemID);
	}
	
	# convert global record to a user record for user $globalUserID
	my $UserRecord = global2user($userSchema->{record}, $Record);
	$UserRecord->user_id($globalUserID);
	
	# if this is the problem table, set the user-specific fields of the user
	# problem to sane defaults (and generate a problem seed). this allows
	# the user $globalUserID to use this problem as a user problem.
	if ($table eq "problem") {
		initializeUserProblem($UserRecord);
	}
	
	# add the record to the database
	return $userSchema->add($UserRecord);
}

sub get {
	my ($self, @keyparts) = @_;
	
	return ($self->gets(\@keyparts))[0];
}

sub gets {
	my ($self, @keypartsRefList) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	
	$userSchema->{driver}->connect("ro");
	my @records;
	foreach my $keypartsRef (@keypartsRefList) {
		my @keyparts = @$keypartsRef;
		push @records, $self->get1(@keyparts);
	}
	$userSchema->{driver}->disconnect;
	
	return @records;
}

# helper used by gets
sub get1 {
	my ($self, @keyparts) = @_;
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	my $UserRecord = $userSchema->get1NoFilter($globalUserID, @keyparts);
	return unless $UserRecord; # maybe it didn't exist?
	return user2global($self->{record}, $UserRecord);
}

sub getAll {
	my ($self, @keyparts) = @_;
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	croak "getAll: only supported for the problem table"
		unless $table eq "problem";
	
	my @UserProblems = $userSchema->getAllNoFilter($globalUserID, @keyparts);
	
	foreach my $UserProblem (@UserProblems) {
		next unless $UserProblem; # maybe it didn't exist?
		$UserProblem = user2global($self->{record}, $UserProblem);
	}
	
	return @UserProblems;
}

sub put {
	my ($self, $Record) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $classlistSchema = $db->{"user"}; # oh god.
	my $globalUserID = $self->{params}->{globalUserID};
	
	my @keyparts = map { $Record->$_() } $Record->KEYFIELDS();
	
	# retrieve the current global values for this record
	$userSchema->{driver}->connect("ro");
	my $CurrentUserRecord = $userSchema->get1NoFilter($globalUserID, @keyparts);
	$userSchema->{driver}->disconnect;
	my $CurrentGlobalRecord = user2global($self->{record}, $CurrentUserRecord);
	
	# convert new global record to a user record for user $globalUserID
	my $NewUserRecord = global2user($userSchema->{record}, $Record);
	$NewUserRecord->user_id($globalUserID);
	
	# if this is the problem table, copy the user-specific fields of the
	# user problem from the old global record. this allows the user
	# $globalUserID to use this problem as a user problem.
	if ($table eq "problem") {
		foreach my $field (qw(status attempted num_correct num_incorrect problem_seed)) {
			my $currentValue = $CurrentUserRecord->$field;
			$NewUserRecord->$field($currentValue);
		}
	}
	# *** WARNING: here is a place where field names are referenced directly
	
	# store user record containing new global values
	my $result = $userSchema->put($NewUserRecord);
	
	# distribute new global values to each user
	# don't overwrite the user record that's storing global values
	my @userIDs = grep { $_ ne $globalUserID } map {$_->[0]} $classlistSchema->list(undef);
	$self->distGlobalValues($CurrentGlobalRecord, $Record, @userIDs);
	
	return $result;
}

sub delete {
	my ($self, @keyparts) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	my $globalUserID = $self->{params}->{globalUserID};
	
	# we can assume that DB has already deleted all the user-specific
	# records it could find. we can just go ahead and delete the one
	# that's being used as a global record (if it exists).
	
	return $userSchema->delete($globalUserID, @keyparts);
}

################################################################################
# function to distribute new global values to each user-specific record
################################################################################

sub distGlobalValues {
	my ($self, $OldGlobalRecord, $NewGlobalRecord, @userIDs) = @_;
	
	my $db = $self->{db};
	my $table = $self->{table};
	my $userSchema = $db->{"${table}_user"};
	
	my @keyparts = map { $NewGlobalRecord->$_() } $NewGlobalRecord->KEYFIELDS();
	
	# figure out which fields (if any) were changed
	my @changedFields;
	foreach my $field ($OldGlobalRecord->FIELDS()) {
		#FIXME  these warnings may not be needed in production
	    warn "Undefined field |$field| in old Global record" unless defined($OldGlobalRecord->$field());
	    warn "Undefined field |$field| in new Global record" unless defined($NewGlobalRecord->$field());
	    if (defined($OldGlobalRecord->$field()) and defined($NewGlobalRecord->$field()) and $OldGlobalRecord->$field() ne $NewGlobalRecord->$field()) {
			push @changedFields, $field;
		}
	}
	
	# if no fields were changed, we're done
	return 0 unless @changedFields;
	
	# impose the new values for each user
	my $anyChanged = 0;
	foreach my $userID (@userIDs) {
		$userSchema->{driver}->connect("ro");
		my $UserRecord = $userSchema->get1NoFilter($userID, @keyparts);
		$userSchema->{driver}->disconnect;
		next unless defined $UserRecord;
		my $changed = 0;
		foreach my $field (@changedFields) {
			if ($UserRecord->$field() eq $OldGlobalRecord->$field()) {
				$changed = 1;
				$UserRecord->$field($NewGlobalRecord->$field());
			}
		}
		if ($changed) {
			$anyChanged = 1;
			$userSchema->put($UserRecord);
		}
	}
	
	return $anyChanged;
}

1;
