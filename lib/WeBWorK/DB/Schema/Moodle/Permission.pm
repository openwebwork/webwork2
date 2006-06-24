################################################################################
# WeBWorK Online Homework Delivery System - Moodle Integration
# Copyright (c) 2005 Peter Snoblin <pas@truman.edu>
# $Id$
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

package WeBWorK::DB::Schema::Moodle::Permission;
use base qw(WeBWorK::DB::Schema);

=head1 NAME

WeBWorK::DB::Schema::Moodle::Permission - support determining permission levels based upon Moodle's data.

=cut

use strict;
use warnings;
use Carp qw(croak);

use constant TABLES => qw(permission);
use constant STYLE  => "dbi";

=head1 SUPPORTED PARAMS

This schema pays attention to the following items in the C<params> entry.

=over

=item tablePrefix

The prefix on all moodle tables.

=item courseID

The ID of this course. This is needed to allow Permission to map to a moodle course.
In turn this allows us to see if the given user is an instructor for said course.
The easy way to have this always be right is to set the value to ${courseName}.

=back

=cut

################################################################################
# constructor for Moodle::Permission-specific behavior
################################################################################

sub new {
	my ($proto, $db, $driver, $table, $record, $params) = @_;
	my $self = $proto->SUPER::new($db, $driver, $table, $record, $params);
	return $self;
}

################################################################################
# table access functions
################################################################################

sub count {
	my ($self, @keyparts) = @_;
	my @keynames = $self->{record}->KEYFIELDS();
	
	croak "Too many keyparts for table permission. Need at most @keynames"
		if @keyparts > @keynames;

	my $table = $self->prefixTable("user");
	# we want to know for a specific user_id
	my $qry = "SELECT COUNT(*) FROM `$table`";
	my @qryArgs = ();
	if( defined $keyparts[0] ) {
		$qry = $qry . " WHERE username=?";
		$qryArgs[0] = $keyparts[0];
	}
	$self->debug("SQL-count: $qry\n");
	
	$self->{driver}->connect("ro");
	my $sth = $self->{driver}->dbi()->prepare($qry);
	$sth->execute(@qryArgs);
	my ($result) = $sth->fetchrow_array;
	
	$self->{driver}->disconnect();
	
	return $result;
}

sub list($@) {
	my ($self, @keyparts) = @_;
	my @keynames = $self->{record}->KEYFIELDS();
	
	croak "Too many keyparts for table permission. Need at most @keynames"
		if @keyparts > @keynames;
	
	my $table = $self->prefixTable("user");
	my $qry = "SELECT username FROM `$table`";
	my @qryArgs = ();
	if( defined $keyparts[0] ) {
		$qry = $qry . " WHERE username=?";
		$qryArgs[0] = $keyparts[0];
	}
	$self->debug("SQL-list: $qry\n");
	
	$self->{driver}->connect("ro");
	my $sth = $self->{driver}->dbi()->prepare($qry);
	$sth->execute(@qryArgs);
	my $result = $sth->fetchall_arrayref;
	
	$self->{driver}->disconnect();
	
	croak "failed to SELECT: $DBI::errstr" unless defined $result;
	return @$result;
}

sub exists($@) {
	my ($self, @keyparts) = @_;
	my @keynames = $self->{record}->KEYFIELDS();
	
	croak "Too many keyparts for table permission. Need at most @keynames"
		if @keyparts > @keynames;
	
	my $table = $self->prefixTable("user");
	my $qry = "SELECT COUNT(*) FROM `$table`";
	my @qryArgs = ();
	if( defined $keyparts[0] ) {
		$qry = $qry . " WHERE username=?";
		$qryArgs[0] = $keyparts[0];
	}
	$self->debug("SQL-exists: $qry\n");
	
	$self->{driver}->connect("ro");
	my $sth = $self->{driver}->dbi()->prepare($qry);
	$sth->execute(@qryArgs);
	my ($result) = $sth->fetchrow_array;
	$self->{driver}->disconnect();
	
	croak "failed to SELECT : $DBI::errstr" unless defined $result;
	return $result > 0;
}

sub add($$) {
	# password modification is not supported for webwork. Use Moodle.
	croak "Modifications to user information is not supported from WeBWorK. Please use Moodle to make any changes.";
}

sub get($@) {
	my ($self, @keyparts) = @_;
	
	return ($self->gets(\@keyparts))[0];
}

sub gets($@) {
	my ($self, @keypartsRefList) = @_;
	my @keynames = $self->{record}->KEYFIELDS();
	
	# redfine permission levels here
	my $guest     = -1;
	my $student   = 0;
	my $ta        = 5;
	my $professor = 10;
	my $nobody    = undef;
	
	my @records;
	foreach my $keypartsRef(@keypartsRefList) {
		my @keyparts = @$keypartsRef;
		if( not defined $keyparts[0] ) {
			croak "wrong number of keyparts for table permission";
		}
		
		# determine user level:
		if( $self->exists(@keyparts) ) {
			my $userLevel = $nobody;
			if( $self->isAdmin($keyparts[0]) ) {
				$userLevel = $professor;
			}
			elsif( $self->isTeacher($keyparts[0], $self->{params}->{courseName}) ) {
				$userLevel = $professor;
			}
			elsif( $self->isStudent($keyparts[0], $self->{params}->{courseName}) ) {
				$userLevel = $student;
			}
			my $Record = $self->{record}->new();
			my @realFieldNames = $self->{record}->FIELDS();
			my @values = ($keyparts[0], $userLevel);
			foreach( @realFieldNames ) {
				my $value = shift @values;
				$value = "" unless defined $value;
				$Record->$_($value);
			}
			push @records, $Record;
		}
		else {
			push @records, undef;
		}
	}
	return @records;
}

sub put($$) {
	croak "Modifications to user information is not supported from WeBWorK. Please use Moodle to make any changes.";
}

sub delete($@) {
	croak "Modifications to user information is not supported from WeBWorK. Please use Moodle to make any changes.";
}

################################################################################
# utility functions
################################################################################

sub debug($@) {
	my ($self, @string) = @_;
	
	if ($self->{params}->{debug}) {
		warn @string;
	}
}

sub prefixTable($$) {
	my ($self, $table) = @_;
	my $prefix = $self->{params}->{tablePrefix};
	return $prefix.$table;
}

# Determine if a given userID is a teacher.
sub isTeacher($$$) {
	my ($self, $id, $courseName) = @_;
	my $table = $self->prefixTable("user_teachers");
	my $userTable = $self->prefixTable("user");
	my $courseTable = $self->prefixTable("wwmoodle");
	# TODO: do this in a way that works from mysql < 4.1
	my $qry = "SELECT COUNT(*) FROM `$table` JOIN `$userTable` ON $table.userid=$userTable.id JOIN `$courseTable` ON $courseTable.course=$table.course WHERE username=? AND $courseTable.coursename=?";
	my @qryArgs = ($id, $courseName);
	
	$self->debug("SQL-isTeacher: $qry");
	
	$self->{driver}->connect("ro");
	my $sth = $self->{driver}->dbi()->prepare($qry);
	$sth->execute(@qryArgs);
	my ($result) = $sth->fetchrow_array;
	$self->{driver}->disconnect();
	
	croak "failed to SELECT : $DBI::errstr" unless defined $result;
	return $result > 0;
}
# Determine if the given userID is a student
sub isStudent($$$) {
	my ($self, $id, $courseName) = @_;
	my $table = $self->prefixTable("user_students");
	my $userTable = $self->prefixTable("user");
	my $courseTable = $self->prefixTable("wwmoodle");
	# TODO: ensure this new syntax works properly
	my $qry = "SELECT COUNT(*) FROM `$table` JOIN `$userTable` ON $table.userid=$userTable.id JOIN `$courseTable` ON $courseTable.course=$table.course WHERE username=? AND $courseTable.coursename=?";
	
	my @qryArgs = ($id, $courseName);
	
	$self->debug("SQL-isStudent: $qry");
	
	$self->{driver}->connect("ro");
	my $sth = $self->{driver}->dbi()->prepare($qry);
	$sth->execute(@qryArgs);
	my ($result) = $sth->fetchrow_array;
	$self->{driver}->disconnect();
	
	croak "failed to SELECT : $DBI::errstr" unless defined $result;
	return $result > 0;
}
# Determine if the given userID is an admin.
sub isAdmin($$) {
	my ($self, $id) = @_;
	my $table = $self->prefixTable("user_admins");
	my $userTable = $self->prefixTable("user");
	my $qry = "SELECT COUNT(*) FROM `$table` JOIN `$userTable` ON $table.userid=$userTable.id WHERE username=?";
	my @qryArgs = ($id);
	
	$self->debug("SQL-isAdmin: $qry");
	
	$self->{driver}->connect("ro");
	my $sth = $self->{driver}->dbi()->prepare($qry);
	$sth->execute(@qryArgs);
	my ($result) = $sth->fetchrow_array;
	$self->{driver}->disconnect();
	
	croak "failed to SELECT : $DBI::errstr" unless defined $result;
	return $result > 0;
}

1;
